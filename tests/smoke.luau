--!nocheck
-- Test de fumée hors Roblox (avec Lune) : charge le .rbxl construit par Rojo, exécute les
-- modules de construction (persos, reliques, carte, décors, bases) et vérifie les formules.
-- Usage :  rojo build default.project.json -o build/AnimeTycoon.rbxl && lune run tests/smoke.luau

local Harness = require("./harness")

local game = Harness.game
local requireModule = Harness.require
local find = Harness.find
local test = Harness.test
local countParts = Harness.countParts
local Enum = Harness.roblox.Enum
local fakeSignal = Harness.newSignal()
local CollectionService = Harness.CollectionService

local Shared = find("ReplicatedStorage.Shared")
local Characters = requireModule(Shared.Config.Characters)
local Universes = requireModule(Shared.Config.Universes)
local Formulas = requireModule(Shared.Modules.Formulas)
local Economy = requireModule(Shared.Config.Economy)
local CharacterBuilder = requireModule(Shared.Modules.CharacterBuilder)
local RelicBuilder = requireModule(Shared.Modules.RelicBuilder)

test("Formules : formatNumber", function()
	local cases = { [0] = "0", [999] = "999", [1000] = "1 k", [1500] = "1,5 k", [12345] = "12,3 k", [100000] = "100 k", [2500000] = "2,5 M", [1e9] = "1 B" }
	for n, expected in cases do
		local got = Formulas.formatNumber(n)
		assert(got == expected, "formatNumber(" .. n .. ") = " .. got .. " (attendu " .. expected .. ")")
	end
	assert(Formulas.formatTime(754) == "12:34", Formulas.formatTime(754))
end)

test("Univers : persos, ennemis, reliques cohérents", function()
	for _, universe in Universes.List do
		assert(#universe.characters >= 6, universe.id .. " : pas assez de persos")
		for _, id in universe.characters do
			local def = Characters.get(id)
			assert(def, "perso manquant " .. id)
			assert(def.universe == universe.id, id .. " n'est pas dans " .. universe.id)
		end
		for _, id in universe.enemies do
			assert(Characters.Enemies[id], "ennemi manquant " .. id)
		end
		assert(Characters.Enemies[universe.boss], "boss manquant " .. universe.boss)
		for _, relic in universe.relics do
			local total = 0
			for rarity, weight in relic.odds do
				local found = false
				for _, id in universe.characters do
					if Characters.get(id).rarity == rarity then
						found = true
					end
				end
				assert(found, relic.id .. " : aucune rareté " .. rarity .. " dans " .. universe.id)
				total += weight
			end
			assert(math.abs(total - 100) < 0.01, relic.id .. " : probabilités = " .. total)
		end
	end
end)

test("Formules : puissance, évolution, fusion", function()
	local entry = { id = "ninja_maruto", level = 30, xp = 0, stars = 1 }
	assert(Formulas.power(entry) > 0)
	local cost = Formulas.evolutionCost(entry)
	assert(cost and cost.stars == 2 and cost.materials.chakra, "coût d'évolution")
	local fusion = { id = "fusion", fusion = { a = "ninja_maruto", b = "occ_goju" }, level = 1, xp = 0, stars = 1 }
	local desc = Formulas.describe(fusion)
	assert(desc.name == "Renard de l'Infini", desc.name)
	local fcost = Formulas.evolutionCost(fusion)
	assert(fcost.materials.chakra and fcost.materials.maudite, "coût fusion")
	local stats = Formulas.upgradeStats({ autel2 = true, equipe4 = true })
	assert(stats.incubators == 2 and stats.team == 4, "upgradeStats")
end)

test("Objets d'évolution : chaque perso a son objet, stock et coins du marchand", function()
	local EvolutionItems = requireModule(Shared.Config.EvolutionItems)
	local Layout = requireModule(Shared.Config.Layout)
	-- Chaque perso jouable demande un objet existant pour ★★ et ★★★, rien au-delà.
	for id in Characters.List do
		for stars = 1, 2 do
			local need = EvolutionItems.requirement({ id = id, stars = stars })
			assert(need and EvolutionItems.get(need.item) and need.amount >= 1, "objet manquant : " .. id .. " ★" .. (stars + 1))
		end
		assert(EvolutionItems.requirement({ id = id, stars = 3 }) == nil, "évolution au-delà de ★★★ : " .. id)
	end
	assert(EvolutionItems.requirement({ id = "sai_goko", stars = 1 }).item == "sai_dragon", "Goko → Boule du Dragon")
	-- Majuscules françaises (string.upper laisse « LéGENDAIRE »).
	assert(EvolutionItems.upper("Légendaire") == "LÉGENDAIRE", "majuscules accentuées")
	assert(EvolutionItems.upper("Planète des Guerriers · Forêt") == "PLANÈTE DES GUERRIERS · FORÊT", "majuscules accentuées (2)")
	for _, tier in EvolutionItems.Tiers do
		assert(tier.label == EvolutionItems.upper(tier.name), "libellé de palier : " .. tier.name)
	end
	local users = EvolutionItems.usedByIds("sai_dragon")
	assert(#users >= 1 and users[1].stars >= 2, "persos qui demandent la Boule du Dragon")
	assert(EvolutionItems.requirement({ id = "ninja_maruto", stars = 1 }).item == "ninja_ermite", "Maruto → Parchemin d'Ermite")
	local fusion = EvolutionItems.requirement({ id = "fusion", fusion = { a = "ninja_maruto", b = "occ_goju" }, stars = 1 })
	assert(fusion and fusion.item == "ninja_secret", "objet d'une fusion")
	assert(EvolutionItems.requirement({ id = "perso_inconnu", stars = 1 }) == nil, "perso inconnu")
	-- Modèles 3D de tous les objets.
	for _, item in EvolutionItems.List do
		local model = EvolutionItems.build(item.id, 1)
		assert(model.PrimaryPart and countParts(model) >= 3, "modèle d'objet vide : " .. item.id)
		assert(item.price > 0 and EvolutionItems.Tiers[item.tier], "prix ou palier : " .. item.id)
	end
	-- Stock : déterministe, sans doublon, objets de base de l'univers garantis.
	for window = 100, 140 do
		for _, universe in Universes.List do
			local a = EvolutionItems.stock(window, universe.id)
			local b = EvolutionItems.stock(window, universe.id)
			assert(#a == EvolutionItems.Merchant.Slots and #a == #b, "taille du stock")
			local seen = {}
			for i, entry in a do
				assert(entry.id == b[i].id, "stock non déterministe")
				assert(not seen[entry.id], "doublon dans le stock")
				seen[entry.id] = true
			end
			assert(seen[EvolutionItems.Universe[universe.id][1]] and seen[EvolutionItems.Universe[universe.id][2]], "objets de base absents")
		end
		-- Le marchand change toujours de coin, et ses coins sont réservés.
		local spots = #Layout.MerchantSpots
		assert(EvolutionItems.spotIndex(window, spots) ~= EvolutionItems.spotIndex(window + 1, spots), "même coin deux fois de suite")
	end
	-- Objets signature garantis : chaque univers en vend toujours un, et ils tournent. En Guerriers,
	-- la Boule du Dragon (Goko → Super Guerrier) sort au moins une fois sur 4 passages de suite.
	for _, universe in Universes.List do
		local signatures = EvolutionItems.signatures(universe.id)
		for window = 200, 230 do
			local found = false
			for _, entry in EvolutionItems.stock(window, universe.id) do
				if table.find(signatures, entry.id) then
					found = true
				end
			end
			assert(#signatures == 0 or found, "aucun objet signature en vente : " .. universe.id)
		end
	end
	for start = 300, 340 do
		local dragon = 0
		for window = start, start + 3 do
			for _, entry in EvolutionItems.stock(window, "saiyan") do
				if entry.id == "sai_dragon" then
					dragon += 1
				end
			end
		end
		assert(dragon >= 1, "Boule du Dragon absente 4 passages de suite")
	end
	for _, spot in Layout.MerchantSpots do
		assert(Layout.isReserved(spot), "coin du marchand non réservé")
	end
end)

test("Arbre de compétences : 40-60 nœuds hexagonaux cohérents", function()
	local SkillTree = requireModule(Shared.Config.SkillTree)
	assert(#SkillTree.Nodes >= 40 and #SkillTree.Nodes <= 60, "nombre de nœuds : " .. #SkillTree.Nodes)
	local cells = {}
	for _, n in SkillTree.Nodes do
		local key = n.q .. "," .. n.r
		assert(not cells[key], "deux nœuds sur la même case : " .. key)
		cells[key] = n.id
		assert(n.cost >= 0 and n.currency == "Coins", "coût invalide : " .. n.id)
		assert(n.effect and n.effect.stat and SkillTree.Base[n.effect.stat] ~= nil, "effet invalide : " .. n.id)
		assert(SkillTree.Branches[n.branch], "branche inconnue : " .. n.id)
		for _, req in n.requires do
			local r = SkillTree.get(req)
			assert(r, n.id .. " : prérequis inconnu " .. req)
			assert(SkillTree.distance(n.q, n.r, r.q, r.r) == 1, n.id .. " n'est pas voisin de " .. req)
			assert(r.order < n.order, n.id .. " défini avant son prérequis " .. req)
		end
	end
	local all = {}
	for _, n in SkillTree.Nodes do
		all[n.id] = true
	end
	local max = SkillTree.stats(all)
	-- v3.2 : rouler 2-3 persos à la fois et l'auto-roulage sont des passes Robux, plus des nœuds.
	assert(max.rollsPerPull == 1, "l'arbre ne doit plus donner de multi-tirage : " .. max.rollsPerPull)
	assert(max.autoRoll == false, "l'arbre ne doit plus donner l'auto-roulage")
	for _, n in SkillTree.Nodes do
		assert(n.effect.stat ~= "rollsPerPull" and n.effect.stat ~= "autoRoll" and n.effect.stat ~= "x10Every", "nœud de l'ancien roulage : " .. n.id)
	end
	assert(max.luck > 3 and max.rollCooldown >= SkillTree.Limits.rollCooldown, "statistiques maximales")
	assert(max.rollDiscount > 0 and max.rollDiscount <= SkillTree.Limits.rollDiscount, "Marchandage sans effet")
	local none = SkillTree.stats({})
	assert(none.rollsPerPull == 1 and none.luck == 1 and none.autoRoll == false and none.rollDiscount == 0, "statistiques de départ")
	-- Coûts croissants le long de chaque branche.
	for _, n in SkillTree.Nodes do
		for _, req in n.requires do
			assert(SkillTree.get(req).cost <= n.cost, n.id .. " coûte moins que son prérequis")
		end
	end
end)

test("Machine ROULER : probabilités, prix, pitié", function()
	for _, luck in { 1, 2.5, 10, 35 } do
		local odds = Formulas.rollOdds(luck)
		local total = 0
		for _, id in Economy.RollOrder do
			assert(odds[id] and odds[id] >= 0, "probabilité manquante : " .. id)
			total += odds[id]
		end
		assert(math.abs(total - 1) < 1e-6, "total des probabilités ≠ 1 (chance " .. luck .. ")")
		assert(odds.common >= 0.05 - 1e-9, "le Commun doit garder 5 %")
	end
	assert(Formulas.rollOdds(2).legendary > Formulas.rollOdds(1).legendary, "la chance n'augmente pas les Légendaires")
	-- Raretés facultatives (Peu commun, Secret) : seulement si l'univers a des persos de ce rang.
	local base = Formulas.rollOdds(1)
	assert(base.uncommon == 0 and base.secret == 0, "Peu commun / Secret tirables sans perso")
	local pools = Formulas.rollPools("ninja")
	local poolOdds = Formulas.rollOdds(1, pools)
	for id, p in poolOdds do
		if p > 0 then
			assert(pools[id] and #pools[id] > 0, "rareté tirable sans perso dans l'univers : " .. id)
		end
	end
	assert(math.abs(base.common - 0.7) < 1e-6 and math.abs(base.mythic - 0.002) < 1e-6, "chances de base inattendues")
	local last = 0
	for _, id in Economy.RollOrder do
		local price = Formulas.rollPrice(id)
		assert(price > last, "prix non croissants : " .. id)
		last = price
	end
	assert(Formulas.rollPrice("rare", "or") > Formulas.rollPrice("rare"), "la mutation n'augmente pas le prix")
	assert(Formulas.rollPrice("rare", "dore") == Formulas.rollPrice("rare", "or"), "l'ancienne aura Doré n'est pas l'Or")
	assert(Formulas.rollPrice("epic", nil, nil, 0.25) < Formulas.rollPrice("epic"), "Marchandage sans effet sur le prix")
	-- Première collecte offerte : seulement jusqu'au Rare.
	assert(Formulas.rollCollectFree({ FirstCollectDone = false }, "rare"), "Rare non offert")
	assert(not Formulas.rollCollectFree({ FirstCollectDone = false }, "legendary"), "Légendaire offert")
	assert(not Formulas.rollCollectFree({ FirstCollectDone = true }, "common"), "2e collecte offerte")
	-- Pitié : UNIQUEMENT le Mythique.
	assert(#Economy.Roll.PityOrder == 1 and Economy.Roll.PityOrder[1] == "mythic", "pitié hors Mythique")
	assert(Formulas.pityThreshold("mythic", 0.7) < Formulas.pityThreshold("mythic", 1), "pitié de l'arbre sans effet")
	assert(Formulas.pityThreshold("legendary") == 1 and Economy.Roll.Pity.legendary == nil, "pitié du Légendaire encore là")
	-- Persos par roulage : passes Robux (Pass_Roll2 / Pass_Roll3), 1 sinon.
	local fake = { attrs = {} }
	function fake:GetAttribute(name)
		return self.attrs[name]
	end
	assert(Formulas.rollsPerRoll(nil) == 1 and Formulas.rollsPerRoll(fake :: any) == 1, "1 perso par roulage par défaut")
	fake.attrs.Pass_Roll2 = true
	assert(Formulas.rollsPerRoll(fake :: any) == 2 and Formulas.rollsPerRoll(fake :: any, 3) == 2, "passe x2")
	fake.attrs.Pass_Roll3 = true
	assert(Formulas.rollsPerRoll(fake :: any) == 3 and Formulas.rollsPerRoll(fake :: any, 1) == 1, "passe x3 / retour à 1")
	-- Chance : passe x2 et potion.
	assert(Formulas.rollLuck({ luck = 1.5 }, fake :: any, 100) == 1.5, "chance sans bonus")
	fake.attrs.Pass_Luck2 = true
	fake.attrs.Boost_Luck = 200
	assert(Formulas.rollLuck({ luck = 1.5 }, fake :: any, 100) == 6, "passe x2 Chance + potion")
	assert(Formulas.rollLuck({ luck = 1.5 }, fake :: any, 300) == 3, "potion terminée encore active")
	-- VIP : +10 % dans le même calcul (serveur et barre ROULER du client).
	fake.attrs.Pass_VIP = true
	assert(math.abs(Formulas.rollLuck({ luck = 1.5 }, fake :: any, 300) - 3.3) < 1e-6, "VIP absent de la chance affichée")
	fake.attrs.Pass_VIP = nil
	-- Cibles de l'achat automatique.
	local item = { id = "ninja_maruto", rarity = "epic", aura = "or" }
	assert(not Formulas.rollMatches(item, { characters = {}, rarities = {}, mutations = {} }), "aucune cible = rien")
	assert(Formulas.rollMatches(item, { characters = { ninja_maruto = true }, rarities = {}, mutations = {} }), "cible perso")
	assert(Formulas.rollMatches(item, { characters = {}, rarities = { epic = true }, mutations = { ["or"] = true } }), "cible rareté + mutation")
	assert(not Formulas.rollMatches(item, { characters = {}, rarities = { epic = true }, mutations = { diamant = true } }), "mauvaise mutation acceptée")
	assert(Formulas.rollMatches({ id = "x", rarity = "rare" }, { characters = {}, rarities = {}, mutations = { aucune = true } }), "« Pas de mutation »")
	assert(#Economy.Upgrades >= 25 and #Economy.Upgrades <= 30, "25 à 30 améliorations attendues")
end)

test("Mutations (variétés) : liste, tirage, apparence", function()
	local Mutations = requireModule(Shared.Config.Mutations)
	local Auras = requireModule(Shared.Config.Auras)
	local MutationsFx = requireModule(Shared.Modules.Mutations)
	for _, id in { "or", "diamant", "sakura", "angelique", "ombre", "galaxie", "arcenciel", "foudre", "givre", "flamme", "neant" } do
		local m = Mutations.get(id)
		assert(m and m.id == id and m.multiplier > 1 and m.chance > 0 and m.chance < 0.1, "mutation invalide : " .. id)
		assert(type(m.gradient) == "table" and #m.gradient >= 2, "dégradé manquant : " .. id)
		assert(Auras.get(id) == m, "Auras et Mutations divergent : " .. id)
	end
	assert(Mutations.get("dore") == Mutations.get("or"), "ancienne aura Doré non reconnue")
	assert(Mutations.get(Mutations.None) == nil and Mutations.get("inconnue") == nil, "mutation fantôme")
	local total = Mutations.totalChance(1)
	assert(total > 0.05 and total < 0.3, "chance totale de mutation : " .. total)
	assert(Mutations.totalChance(2) > total, "la chance de mutation n'augmente pas")
	local rng = Harness.Random.new(42)
	local counts, n = {}, 20000
	for _ = 1, n do
		local id = Mutations.roll(rng, 1) or "aucune"
		counts[id] = (counts[id] or 0) + 1
	end
	assert(counts.aucune / n > 0.7, "trop de mutations")
	assert((counts["or"] or 0) > (counts.arcenciel or 0), "l'Arc-en-ciel sort plus que l'Or")
	-- Apparence : voile sur les habits peints, particules, rien en double.
	local entry = { id = "ninja_maruto", level = 1, stars = 1 }
	for _, id in { "or", "sakura", "angelique", "arcenciel", "diamant", "ombre", "galaxie", "flamme" } do
		local model = CharacterBuilder.build(Formulas.describe(entry).look, { name = "Test" })
		assert(MutationsFx.apply(model, id), "mutation non posée : " .. id)
		local veils, particles = 0, 0
		for _, d in model:GetDescendants() do
			-- (voile / particules du repli ici, ou de CharacterBuilder.applyVariety quand il existe)
			if d.Name == "MutationVoile" or d.Name == "VarietyTint" then
				veils += 1
			elseif d.Name == "MutationParticules" or d.Name == "VarietyFx" then
				particles += 1
			end
		end
		assert(veils > 0, "aucun voile coloré : " .. id)
		assert(model:GetAttribute("Mutation") == id, "attribut Mutation absent : " .. id)
		MutationsFx.apply(model, id)
		local again = 0
		for _, d in model:GetDescendants() do
			if d.Name == "MutationVoile" or d.Name == "VarietyTint" then
				again += 1
			end
		end
		assert(again == veils, "mutation posée deux fois : " .. id)
		if Mutations.get(id).look.particles then
			assert(particles == 1, "particules absentes ou en double : " .. id)
		end
		-- Le visage reste net (pas de voile sur la tête) ; contour lumineux pour x3 et plus.
		local head = model:FindFirstChild("Head")
		assert(not (head and head:FindFirstChild("MutationVoile", true)), "voile sur le visage : " .. id)
		-- Contour lumineux : marqué pour le client (x3 et plus), jamais posé par le serveur.
		local glow = table.find(CollectionService:GetTagged("MutationGlow"), model) ~= nil
		assert(glow == (Mutations.get(id).multiplier >= 3), "contour lumineux incohérent : " .. id)
		assert(model:FindFirstChildOfClass("Highlight") == nil, "Highlight posé par le serveur : " .. id)
		model:Destroy()
	end
	-- Chaque mutation a SON signe (en repli, sans CharacterBuilder.applyVariety) : on les
	-- reconnaît sans légende.
	if type((CharacterBuilder :: any).applyVariety) ~= "function" then
		local signs = {
			["or"] = "MutationEtincelle",
			foudre = "MutationEclair",
			givre = "MutationCristal",
			angelique = "MutationAile",
			ombre = "MutationFumee",
			neant = "MutationVide",
		}
		for id, name in signs do
			local model = CharacterBuilder.build(Formulas.describe(entry).look, { name = "Signe" })
			MutationsFx.apply(model, id)
			assert(model:FindFirstChild(name, true), "signe " .. name .. " absent : " .. id)
			for other, otherName in signs do
				if other ~= id then
					assert(not model:FindFirstChild(otherName, true), "signe de " .. other .. " sur " .. id)
				end
			end
			model:Destroy()
		end
		local angel = CharacterBuilder.build(Formulas.describe(entry).look, { name = "Ange" })
		MutationsFx.apply(angel, "angelique")
		assert(angel:FindFirstChild("MutationAureole", true), "auréole absente")
		angel:Destroy()
		local function motifs(id)
			local model = CharacterBuilder.build(Formulas.describe(entry).look, { name = "Motif" })
			MutationsFx.apply(model, id)
			local n = 0
			for _, d in model:GetDescendants() do
				if d.Name == "MutationMotif" then
					n += 1
				end
			end
			model:Destroy()
			return n
		end
		assert(motifs("diamant") > motifs("galaxie"), "facettes du Diamant absentes des bras et jambes")
		assert(motifs("flamme") > 0 and motifs("neant") > 0, "flammes / fissures absentes")
	end
	-- Côté client : contours seulement sur les persos proches, 8 au plus.
	local roblox = Harness.roblox
	local models = {}
	for i = 1, 20 do
		local m = roblox.Instance.new("Model")
		local root = roblox.Instance.new("Part")
		root.CFrame = roblox.CFrame.new(i * 3, 0, 0)
		root.Parent = m
		m.PrimaryPart = root
		table.insert(models, m)
	end
	local picked = MutationsFx.pickGlows(models, roblox.Vector3.new(0, 0, 0))
	assert(#picked == MutationsFx.GlowMax, "trop ou pas assez de contours : " .. #picked)
	assert(picked[1] == models[1], "le plus proche n'a pas son contour")
	assert(not MutationsFx.apply(CharacterBuilder.build(Formulas.describe(entry).look, { name = "T" }), "inconnue"), "mutation inconnue posée")
end)

test("Construction de tous les persos (★1 à ★3)", function()
	local total, maxParts = 0, 0
	for id in Characters.List do
		for stars = 1, 3 do
			local entry = { id = id, level = 50, stars = stars }
			local model = CharacterBuilder.build(Formulas.describe(entry).look, { scale = Formulas.visualScale(entry), humanoid = true, collisionGroup = "Followers" })
			assert(model.PrimaryPart, id .. " sans PrimaryPart")
			local n = countParts(model)
			maxParts = math.max(maxParts, n)
			total += 1
		end
	end
	print(string.format("   %d modèles, max %d pièces par perso", total, maxParts))
end)

test("Persos R6 classiques : proportions, tête, visage, budgets", function()
	local function check(label, look)
		-- proportions à l'échelle 1 (sans la carrure propre des Secrets, `bodyScale`)
		look = table.clone(look)
		look.bodyScale = nil
		look.minScale = nil
		local model = CharacterBuilder.build(look, { scale = 1 })
		local head = model:FindFirstChild("Head")
		assert(head and head.Size.X == 2 and head.Size.Y == 1 and head.Size.Z == 1, label .. " : tête classique 2x1x1 attendue")
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		assert(
			mesh
				and mesh.MeshType.Name == "Head"
				and math.abs(mesh.Scale.Y - 1.25 * (look.headScale and (typeof(look.headScale) == "Vector3" and look.headScale.Y or look.headScale) or 1)) < 1e-4,
			label .. " : maillage Head 1.25 (x headScale)"
		)
		local torso = model:FindFirstChild("Torso")
		assert(torso.Size.X == 2 and torso.Size.Y == 2 and torso.Size.Z == 1, label .. " : torse 2x2x1")
		for _, limb in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local part = model:FindFirstChild(limb)
			assert(part and part.Size.X == 1 and part.Size.Y == 2 and part.Size.Z == 1, label .. " : " .. limb .. " 1x2x1")
		end
		for _, joint in CharacterBuilder.JointNames do
			assert(model:FindFirstChild(joint, true), label .. " : articulation " .. joint)
		end
		local plates, frames, parts, lodFrames, lods = 0, 0, 0, 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				if d.Name == "FacePlate" then
					plates += 1
					assert(d.Transparency == 1 and d:FindFirstChildOfClass("SurfaceGui"), label .. " : plaque du visage")
				end
			elseif d:IsA("Frame") then
				local gui = d:FindFirstAncestorOfClass("SurfaceGui")
				if gui and gui:GetAttribute("LodNear") then
					lodFrames += 1
				else
					frames += 1
				end
			elseif d:IsA("SurfaceGui") and d:GetAttribute("LodNear") then
				lods += 1
				assert(d.MaxDistance > d:GetAttribute("LodNear") and d.ZOffset < 1, label .. " : LOD affiché plus loin et sous la peinture complète")
			end
		end
		assert(lods >= 6, label .. " : niveau de détail intermédiaire attendu (" .. lods .. ")")
		assert(lodFrames <= 160, label .. " : LOD trop lourd (" .. lodFrames .. ")")
		local boar = look.accessories and table.find(look.accessories, "boar_head")
		assert(boar or plates == 6, label .. " : 6 plaques de visage attendues (" .. plates .. ")")
		assert(parts <= 180, label .. " : trop de pièces (" .. parts .. ")")
		assert(frames <= 520, label .. " : trop de Frames (" .. frames .. ")")
		local preview = CharacterBuilder.buildPreview(look)
		local previewParts = 0
		for _, d in preview:GetDescendants() do
			if d:IsA("BasePart") then
				previewParts += 1
			end
			assert(not d:IsA("SurfaceGui"), label .. " : SurfaceGui dans l'aperçu")
		end
		assert(previewParts <= 400, label .. " : aperçu trop lourd (" .. previewParts .. ")")
		return parts, frames, previewParts
	end
	local maxParts, maxFrames, maxPreview = 0, 0, 0
	for id in Characters.List do
		for stars = 1, 3 do
			local p, f, v = check(id .. " ★" .. stars, Formulas.describe({ id = id, level = 1, stars = stars }).look)
			maxParts, maxFrames, maxPreview = math.max(maxParts, p), math.max(maxFrames, f), math.max(maxPreview, v)
		end
	end
	for id, def in Characters.Enemies do
		check(id, def.look)
	end
	print(string.format("   max %d pièces, %d Frames, aperçu %d pièces", maxParts, maxFrames, maxPreview))
end)

test("Construction des ennemis et boss", function()
	for id, def in Characters.Enemies do
		local model = CharacterBuilder.build(def.look, { scale = 4.2, humanoid = true })
		assert(model.PrimaryPart, id)
	end
end)

test("Boss lisibles (liseré, lumières, aura) et variétés des persos", function()
	for id, def in Characters.Enemies do
		if def.look.boss then
			local model = CharacterBuilder.build(def.look, { scale = 4.2, humanoid = true })
			assert(model:FindFirstChildOfClass("Highlight"), id .. " : liseré lumineux (Highlight) attendu")
			local lights, guis = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("PointLight") then
					lights += 1
				elseif d:IsA("SurfaceGui") then
					guis += 1
					assert(d.LightInfluence < 1, id .. " : peinture lisible dans la pénombre")
					assert(d.Name ~= "ShirtFront" or d.PixelsPerStud < 70, id .. " : résolution des peintures adaptée à la taille")
				end
			end
			assert(lights >= 2, id .. " : lumières sur le boss")
			assert(guis > 10, id .. " : tenue peinte")
		end
	end
	-- Les ennemis ordinaires n'ont pas de Highlight (limite de 31 par client)
	local minion = CharacterBuilder.build(Characters.Enemies.sai_saibamon.look, { scale = 1 })
	assert(not minion:FindFirstChildOfClass("Highlight"), "pas de Highlight hors boss")
	local look = Formulas.describe({ id = "sai_goko", level = 1, stars = 1 }).look
	for _, v in { "Or", "Diamant", "Sakura", "Angélique", "Ombre", "Galaxie", "Arc-en-ciel", "dore", "neant" } do
		local model = CharacterBuilder.build(look, { scale = 1 })
		assert(CharacterBuilder.applyVariety(model, v), "variété inconnue : " .. v)
		assert(model:GetAttribute("Variety"), v .. " : attribut Variety")
	end
	local plain = CharacterBuilder.build(look, { scale = 1 })
	assert(not CharacterBuilder.applyVariety(plain, "inconnue"), "variété inconnue refusée")
	-- La fabrique applique la variété tirée de l'unité (options.variety) au modèle et à l'aperçu
	local CharacterFactory = requireModule(Shared.Modules.CharacterFactory)
	local fromUnit = CharacterFactory.build("sai_goko", 1, look, { scale = 1, variety = "Diamant" })
	assert(fromUnit:GetAttribute("Variety") == "diamond", "fabrique : variété de l'unité appliquée")
	local previewV = CharacterFactory.buildPreview("sai_goko", 1, look, "Sakura")
	assert(previewV:GetAttribute("Variety") == "sakura", "fabrique : variété appliquée à l'aperçu")
	local noVariety = CharacterFactory.build("sai_goko", 1, look, { scale = 1 })
	assert(noVariety:GetAttribute("Variety") == nil, "fabrique : pas de variété par défaut")
	-- Reliefs 3D génériques : col fourré de Maruto, ceinture du gi, semelles
	local function named(model, name)
		local n = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				n += 1
			end
		end
		return n
	end
	local maruto = CharacterBuilder.build(Formulas.describe({ id = "ninja_maruto", level = 1, stars = 1 }).look, { scale = 1 })
	assert(named(maruto, "ReliefCollarBack") == 1 and named(maruto, "ReliefCollarFront") == 2, "Maruto : col fourré en relief")
	assert(named(maruto, "ReliefSole") == 2, "Maruto : semelles en relief")
	local reliefs = 0
	for id in Characters.List do
		local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = 1 }).look, { scale = 1 })
		if named(m, "ReliefBelt") > 0 then
			reliefs += 1
		end
		m:Destroy()
	end
	assert(reliefs >= 8, "ceintures en relief sur les persos en gi/uniforme (" .. reliefs .. ")")
	-- Or : peinture re-teintée (pas de voile qui noie les plis), cheveux en or poli, LOD refait
	local goldLook = table.clone(look)
	goldLook.variety = "Or"
	local gold = CharacterBuilder.build(goldLook, { scale = 1 })
	assert(gold:GetAttribute("Variety") == "gold", "une unité Or a l'attribut Variety = gold")
	assert(not gold:FindFirstChild("VarietyTint", true), "Or : plus de voile par-dessus la peinture")
	local foil, lodAfter = false, 0
	for _, d in gold:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Hair" and d.Material == Enum.Material.Foil then
			foil = true
		elseif d:IsA("SurfaceGui") and d:GetAttribute("LodNear") then
			lodAfter += 1
		end
	end
	assert(foil and lodAfter >= 6, "Or : cheveux Foil et LOD présents")
	local shadow = CharacterBuilder.build(look, { scale = 1 })
	CharacterBuilder.applyVariety(shadow, "Ombre")
	-- Le liseré est noté sur le modèle (contour posé côté client sur les persos proches).
	assert(typeof(shadow:GetAttribute("VarietyRim")) == "Color3", "Ombre : couleur du liseré violet notée")
	assert(shadow:FindFirstChildOfClass("Highlight") == nil, "Ombre : pas de Highlight posé par le serveur")
	-- Boss : contour seul, lumière de face blanc chaud
	local ken = CharacterBuilder.build(Characters.Enemies.occ_kenjakou.look, { scale = 4.2 })
	local bossRim = ken:FindFirstChild("BossRim")
	assert(bossRim and bossRim.FillTransparency == 1, "BossRim sans remplissage")
	local key = ken:FindFirstChild("BossKey", true)
	assert(key and key.Color.R > key.Color.B, "lumière de face blanc chaud")
	assert(ken:FindFirstChild("BossFaceLight", true), "lumière douce sous le visage")
	-- Auras d'évolution : particules depuis la surface d'une enveloppe + rayons, plus de plaques
	local ssj = CharacterBuilder.build(Formulas.describe({ id = "sai_brolo", level = 1, stars = 2 }).look, { scale = 1 })
	local beams, surface = 0, false
	for _, d in ssj:GetDescendants() do
		assert(d.Name ~= "AuraFlame", "plus de plaques d'aura")
		if d:IsA("Beam") then
			beams += 1
		elseif d:IsA("ParticleEmitter") and d.ShapeStyle == Enum.ParticleEmitterShapeStyle.Surface then
			surface = true
		end
	end
	assert(beams >= 2 and surface, "aura : 2 rayons et des particules autour de la silhouette")
	-- CHAQUE perso change à CHAQUE étoile (★1 -> ★2 -> ★3) : coiffure, yeux ou pièce de tenue
	-- (une aura seule ne suffit pas), et la silhouette construite change (pièces/effets en plus)
	local STRONG = {
		"hair",
		"hairColor",
		"hairLength",
		"eyes",
		"pupil",
		"eyeGlow",
		"eyeMarks",
		"eyeStyle",
		"top",
		"bottom",
		"outfit",
		"skin",
		"markLarge",
		"curseSpread",
		"nails",
		"armVeins",
	}
	local AURAS = { energy_aura = true, ssj_aura = true, steam = true }
	local ids = {}
	for id in Characters.List do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		for st = 1, 2 do
			local la = Formulas.describe({ id = id, level = 1, stars = st }).look
			local lb = Formulas.describe({ id = id, level = 1, stars = st + 1 }).look
			-- Objets sur mesure (look.props) différents : pièces visibles en plus ou en moins
			local function sig(props)
				local out = {}
				for _, p in props or {} do
					table.insert(out, tostring(p.shape) .. tostring(p.limb) .. tostring(p.at) .. tostring(p.size))
				end
				return table.concat(out, ";")
			end
			local strong = sig(la.props) ~= sig(lb.props)
			for _, k in STRONG do
				if la[k] ~= lb[k] then
					strong = true
				end
			end
			local accA, accB = {}, {}
			for _, a in la.accessories or {} do
				accA[a] = true
			end
			for _, a in lb.accessories or {} do
				accB[a] = true
			end
			for a in accB do
				if not accA[a] and not AURAS[a] then
					strong = true
				end
			end
			for a in accA do
				if not accB[a] and not AURAS[a] then
					strong = true
				end
			end
			assert(strong, id .. " ★" .. st .. " -> ★" .. (st + 1) .. " : coiffure, yeux ou tenue doivent changer")
		end
	end
	for _, id in ids do
		local function names(stars)
			local set = {}
			local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = stars }).look, { scale = 1 })
			-- Signature : noms des pièces et effets + nombre de pièces + boîte englobante arrondie
			local n, top, wide = 0, 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("ParticleEmitter") then
					set[d.Name] = true
				end
				if d:IsA("BasePart") then
					n += 1
					local p = d.CFrame.Position
					top = math.max(top, p.Y + d.Size.Y / 2)
					wide = math.max(wide, math.abs(p.X) + d.Size.X / 2)
				end
			end
			set["#" .. n .. "/" .. math.floor(top * 10) .. "/" .. math.floor(wide * 10)] = true
			return set
		end
		local sets = { names(1), names(2), names(3) }
		for st = 1, 2 do
			local a, b = sets[st], sets[st + 1]
			local changed = false
			for n in b do
				if not a[n] then
					changed = true
				end
			end
			for n in a do
				if not b[n] then
					changed = true
				end
			end
			assert(changed, id .. " ★" .. st .. " -> ★" .. (st + 1) .. " : la silhouette doit changer")
		end
	end
	local withVariety = table.clone(look)
	withVariety.variety = "Angélique"
	local angel = CharacterBuilder.build(withVariety, { scale = 1 })
	assert(angel:FindFirstChild("VarietyHalo"), "auréole de la variété Angélique")
	assert(angel:GetAttribute("Variety") == "angelic", "look.variety appliqué à la construction")
end)

test("Nouveaux persos v3.2, uniformes personnalisés, boss Akaino/Freezo", function()
	local NEW = {
		ninja = { "ninja_hinato", "ninja_jiriya" },
		occulte = { "occ_nanamo", "occ_chosu" },
		saiyan = { "sai_trunk", "sai_brolo" },
		ocean = { "oce_robine", "oce_ase" },
		pourfendeur = { "pou_shinobo", "pou_giyo" },
	}
	local rarities = { common = true, rare = true, epic = true, legendary = true, mythic = true, secret = true }
	for _, universe in Universes.List do
		assert(#universe.characters >= 10, universe.id .. " : au moins 10 persos attendus (" .. #universe.characters .. ")")
		for _, id in NEW[universe.id] or {} do
			assert(table.find(universe.characters, id), id .. " absent des tables de tirage de " .. universe.id)
			local def = Characters.get(id)
			assert(def and def.universe == universe.id and rarities[def.rarity], id .. " : univers ou rareté de base invalide")
		end
	end
	local function partNamed(look, name)
		local model = CharacterBuilder.build(look, { scale = 1 })
		local count = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				count += 1
			end
		end
		return count
	end
	local function look(id)
		return Formulas.describe({ id = id, level = 1, stars = 1 }).look
	end
	assert(partNamed(look("pou_giyo"), "HaoriBack") == 2, "Giyo : haori coupé en deux moitiés")
	assert(partNamed(look("ninja_jiriya"), "OilPlate") == 1, "Jiriya : plaque du bandeau à cornes")
	assert(partNamed(look("oce_ase"), "HatCrown") == 1, "Ase : chapeau de cow-boy")
	assert(partNamed(look("occ_nobora"), "Skirt") == 1, "Nobora : jupe plissée")
	assert(partNamed(look("occ_yuzi"), "HoodCord") == 2, "Yuzi : capuche à cordons")
	local akaino = Characters.Enemies.oce_akaino.look
	assert(partNamed(akaino, "CoatSleeveShell") == 0 and partNamed(akaino, "CoatShoulder") == 0, "Akaino : plus de blocs aux épaules ni de coques de manches")
	assert(partNamed(akaino, "CoatDrape") == 2 and partNamed(akaino, "CoatDrapeFall") == 2, "Akaino : manteau posé sur les épaules (pans fins + retombée)")
	assert(partNamed(akaino, "EpauletteFringe") == 12, "Akaino : épaulettes fines à 6 franges")
	assert(partNamed(akaino, "CoatPan") == 0, "Akaino : plus de panneaux latéraux")
	assert(
		partNamed(akaino, "MagmaSleeve") == 0 and partNamed(akaino, "MagmaFist") == 1 and partNamed(akaino, "MagmaRock") == 5,
		"Akaino : poing de lave ajusté et croûtes de basalte"
	)
	do
		local m = CharacterBuilder.build(akaino, { scale = 1 })
		local fist = m:FindFirstChild("MagmaFist") :: BasePart
		assert(fist.Size.X <= 1.21 and fist.Size.Z <= 1.21, "Akaino : poing pas plus gros que le bras + 0,2")
		local lava = 0
		for _, d in m:FindFirstChild("Right Arm"):GetChildren() do
			if d:IsA("SurfaceGui") and d:GetAttribute("ZTop") then
				lava += 1
				assert(d.ZOffset == 1.5 and d.LightInfluence == 0, "Akaino : lave peinte par-dessus la manche, lumineuse")
			end
		end
		assert(lava == 4, "Akaino : lave peinte sur les 4 faces de l'avant-bras")
		local mesh = m.Head:FindFirstChild("Mesh") :: SpecialMesh
		assert(mesh.Scale.X > 1.25 * 1.1, "Akaino : tête agrandie (headScale)")
		assert(math.abs(m.Head.CFrame.Position.Y - m.Torso.CFrame.Position.Y - 1.5 - 0.6 * 0.13) < 0.01, "Akaino : la tête agrandie monte (le cou reste en place)")
	end
	local freezo = Characters.Enemies.sai_freezo.look
	assert(partNamed(freezo, "GemShoulder") == 2 and partNamed(freezo, "GemShoulderBevel") == 0, "Freezo : épaulières bombées")
	assert(partNamed(freezo, "Chin") == 2 and partNamed(freezo, "BrowRidge") == 2 and partNamed(freezo, "TailTip") == 1, "Freezo : menton, front en V, queue")
	local kenjakou = Characters.Enemies.occ_kenjakou.look
	assert(
		partNamed(kenjakou, "KesaRing") == 0 and partNamed(kenjakou, "KesaKnot") == 1 and partNamed(kenjakou, "KesaTrim") == 0,
		"Kenjakou : nœud de cordon, kesa sans planches en relief"
	)
	do
		local m = CharacterBuilder.build(kenjakou, { scale = 1 })
		assert((m:FindFirstChild("Kesa") :: BasePart).Size.X <= 0.55, "Kenjakou : kesa fin")
	end
	assert(look("occ_megumo").uniformStyle == "spiral", "Megumo : col à bouton spirale")
	-- Coiffures à silhouette propre (cheveux noirs à pointes)
	local hairs = {}
	for _, id in { "sai_goko", "sai_vejeta", "occ_megumo", "sai_brolo", "sai_gohon" } do
		local h = look(id).hair
		assert(not hairs[h], id .. " : même coiffure que " .. tostring(hairs[h]))
		hairs[h] = id
	end
	-- Chaque perso tirable figure dans une table de tirage
	for id in Characters.List do
		local found = false
		for _, universe in Universes.List do
			if table.find(universe.characters, id) then
				found = true
			end
		end
		assert(found, id .. " absent de toutes les tables de tirage")
	end
end)

test("Roster v3.2 : 16 persos de plus, raretés de base, signatures, noms d'origine", function()
	local Rarities = requireModule(Shared.Config.Rarities)
	local AttackFx = requireModule(Shared.Config.AttackFx)
	local Noms = requireModule(Shared.Config.NomsOriginaux)
	local EFFECTS = { energy_aura = true, ssj_aura = true, steam = true, energy_fists = true, chidori = true, hollow_purple = true, sun_flames = true }
	local function propSig(props)
		local parts = {}
		for _, p in props or {} do
			table.insert(parts, tostring(p.shape) .. tostring(p.limb) .. tostring(p.at) .. tostring(p.size) .. tostring(p.color))
		end
		return table.concat(parts, ";")
	end
	local ROSTER = {
		ninja = { ninja_gaaro = "epic", ninja_minatu = "mythic", ninja_radama = "secret" },
		occulte = { occ_hakaro = "epic", occ_toja = "mythic", occ_yuuto = "legendary", occ_ijichu = "common" },
		saiyan = { sai_cel = "legendary", sai_jirene = "legendary", sai_gojita = "secret" },
		ocean = { oce_inel = "mythic", oce_lao = "legendary", oce_kaydo = "secret" },
		pourfendeur = { pou_tengan = "legendary", pou_doma = "mythic", pou_muzon = "secret" },
	}
	-- La rareté Secret existe et se place entre Mythique et Crossover
	local secret = Rarities.get("secret")
	assert(secret.id == "secret" and table.find(Rarities.Order, "secret"), "rareté Secret manquante")
	assert(secret.basePower > Rarities.get("mythic").basePower and secret.basePower < Rarities.get("crossover").basePower, "puissance Secret mal placée")
	assert(secret.order > Rarities.get("mythic").order and secret.order < Rarities.get("crossover").order, "ordre Secret mal placé")
	-- Raretés de base cohérentes (Maruto Épique, Sukana Secret, Goju Mythique)
	assert(Characters.get("ninja_maruto").rarity == "epic", "Maruto doit être Épique")
	assert(Characters.get("occ_sukana").rarity == "secret", "Sukana doit être Secret")
	assert(Characters.get("occ_goju").rarity == "mythic", "Goju doit être Mythique")
	-- Persos très populaires/puissants pas en Commun (Toudo Épique, Inumako Rare)
	assert(Characters.get("occ_toudo").rarity == "epic", "Toudo doit être Épique")
	assert(Characters.get("occ_inumako").rarity == "rare", "Inumako doit être Rare")
	-- Héros vedettes alignés : Goko et Itochi Mythiques comme Goju
	assert(Characters.get("sai_goko").rarity == "mythic", "Goko doit être Mythique")
	assert(Characters.get("ninja_itochi").rarity == "mythic", "Itochi doit être Mythique")
	-- La couleur unie du Secret est claire (texte lisible sur fond sombre) et il s'affiche en arc-en-ciel
	local sc = Rarities.get("secret").color
	assert(Rarities.get("secret").rainbow and sc.R + sc.G + sc.B > 2.4, "Secret : couleur claire + arc-en-ciel")
	-- Les persos Secrets du jeu : exactement un par univers, ceux attendus
	local SECRETS = { ninja_radama = true, occ_sukana = true, sai_gojita = true, oce_kaydo = true, pou_muzon = true }
	local named = {}
	for _, entry in Noms.List do
		named[entry.id] = true
	end
	local total = 0
	for _, universe in Universes.List do
		local count = {}
		for _, id in universe.characters do
			local r = Characters.get(id).rarity
			count[r] = (count[r] or 0) + 1
		end
		assert(#universe.characters >= 13 and #universe.characters <= 14, universe.id .. " : 13 ou 14 persos attendus (" .. #universe.characters .. ")")
		assert((count.common or 0) >= 2, universe.id .. " : au moins 2 Communs (persos secondaires)")
		assert(count.secret == 1 and (count.mythic or 0) >= 1 and (count.mythic or 0) <= 2, universe.id .. " : un Secret et 1 ou 2 Mythiques")
		for _, id in universe.characters do
			if Characters.get(id).rarity == "secret" then
				assert(SECRETS[id], id .. " : Secret inattendu")
			end
		end
		for id, rarity in ROSTER[universe.id] do
			total += 1
			local def = Characters.get(id)
			assert(def and def.universe == universe.id, id .. " : univers")
			assert(table.find(universe.characters, id), id .. " absent de la table de tirage")
			assert(def.rarity == rarity, id .. " : rareté de base " .. tostring(def.rarity) .. " (attendu " .. rarity .. ")")
			assert(def.evolve and def.evolve[2] and def.evolve[3], id .. " : évolutions ★2/★3")
			assert(def.fusion and def.fusion.prefix and def.fusion.suffix, id .. " : préfixe/suffixe de fusion")
			assert(def.attack and def.attack.name and def.attack.kind, id .. " : attaque")
			assert(named[id], id .. " : nom d'origine manquant")
			-- Chaque étoile change la tenue, la coiffure ou les objets (hors auras et effets)
			for st = 1, 2 do
				local la = Formulas.describe({ id = id, level = 1, stars = st }).look
				local lb = Formulas.describe({ id = id, level = 1, stars = st + 1 }).look
				local visible = propSig(la.props) ~= propSig(lb.props)
				for _, k in { "top", "outfit", "hair", "hairColor", "bottom", "skin" } do
					if la[k] ~= lb[k] then
						visible = true
					end
				end
				local accA, accB = {}, {}
				for _, a in la.accessories or {} do
					accA[a] = true
				end
				for _, a in lb.accessories or {} do
					accB[a] = true
				end
				for a in accB do
					if not accA[a] and not EFFECTS[a] then
						visible = true
					end
				end
				for a in accA do
					if not accB[a] and not EFFECTS[a] then
						visible = true
					end
				end
				assert(visible, id .. " ★" .. st .. " -> ★" .. (st + 1) .. " : tenue, coiffure ou objets doivent changer (pas seulement l'aura)")
			end
			-- Budget de pièces respecté à chaque étoile, objets sur mesure bien construits
			for st = 1, 3 do
				local look = Formulas.describe({ id = id, level = 1, stars = st }).look
				local m = CharacterBuilder.build(look, { scale = 1 })
				local n, props = 0, 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						n += 1
						if d.Name == "Prop" then
							props += 1
						end
					end
				end
				assert(n <= 178, id .. " ★" .. st .. " : trop de pièces (" .. n .. ")")
				-- Seuil d'alerte : garder de la marge sous le plafond (les objets passent après les
				-- accessoires et seraient les premiers sacrifiés si la coiffure ou la tenue s'alourdit)
				assert(n <= 165, id .. " ★" .. st .. " : " .. n .. " pièces, au-delà du seuil d'alerte (165)")
				if look.props then
					assert(props > 0 or #look.props > 0, id .. " : objets sur mesure absents")
				end
				m:Destroy()
			end
		end
	end
	assert(total == 16, "16 nouveaux persos attendus")
	-- Nuque « soignée » : de la couleur des cheveux, remontée dans la coiffure (plus de pavé sombre)
	for _, id in { "occ_toja", "occ_yuuto", "oce_inel", "sai_gojita", "pou_muzon" } do
		local look = Formulas.describe({ id = id, level = 1, stars = 1 }).look
		assert(look.napeTidy, id .. " : nuque soignée attendue")
		local m = CharacterBuilder.build(look, { scale = 1 })
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "HairNape" then
				assert(d.Color == look.hairColor, id .. " : nuque d'une autre couleur que les cheveux")
			end
		end
		m:Destroy()
	end
	-- Objets peints (armure lamellaire de Radama, kanji de Gaaro) : la peinture est bien posée
	local function painted(id, stars, name)
		local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = stars }).look, { scale = 1 })
		local found = false
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name and #d:GetChildren() > 0 then
				for _, c in d:GetDescendants() do
					if c:IsA("SurfaceGui") then
						found = true
					end
				end
			end
		end
		m:Destroy()
		return found
	end
	assert(painted("ninja_gaaro", 1, "Kanji"), "Gaaro : kanji du front non peint")
	assert(painted("ninja_radama", 1, "Prop"), "Radama : armure lamellaire non peinte")
	-- Aperçus des menus (mode « parts » : fiche, inventaire, révélation) : Radama garde son armure
	-- (bandes sombres des lamelles) et tous les nouveaux persos restent sous 390 pièces (marge)
	for _, id in { "ninja_radama", "ninja_minatu", "oce_kaydo", "sai_cel", "pou_muzon", "occ_yuuto" } do
		for st = 1, 3 do
			local m = CharacterBuilder.buildPreview(Formulas.describe({ id = id, level = 1, stars = st }).look)
			local n, bands = 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
					if d.Name == "PropBand" then
						bands += 1
					end
				end
			end
			assert(n <= 390, id .. " ★" .. st .. " (menus) : " .. n .. " pièces (> 390)")
			if id == "ninja_radama" and st <= 2 then
				assert(bands >= 4, "Radama ★" .. st .. " (menus) : armure lamellaire non dessinée")
			end
			m:Destroy()
		end
	end
	-- Objets signature des Secrets (lisibles de loin)
	local function hasProp(id, stars, name)
		local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = stars }).look, { scale = 1 })
		local found = false
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				found = true
			end
		end
		m:Destroy()
		return found
	end
	for _, id in { "ninja_radama", "sai_gojita", "oce_kaydo", "pou_muzon" } do
		assert(#Characters.get(id).look.props >= 5 and hasProp(id, 1, "Prop"), id .. " : objet signature")
	end
	-- Carrure : plus de sphères « bulk » (épaules en ballons) sur les persos du roster ; deltoïdes
	-- intégrés à la place pour les colosses
	for _, list in ROSTER do
		for id in list do
			for st = 1, 3 do
				local look = Formulas.describe({ id = id, level = 1, stars = st }).look
				for _, a in look.accessories or {} do
					assert(a ~= "bulk", id .. " ★" .. st .. " : accessoire « bulk » interdit (épaules en ballons)")
				end
				-- plaques d'avant-bras peintes (pastille ronde en surbrillance = « ballon » dans les menus)
				assert(look.armPlates == nil, id .. " ★" .. st .. " : armPlates interdit (pastilles rondes sur les bras)")
			end
		end
	end
	for _, id in { "oce_kaydo", "sai_jirene" } do
		assert(hasProp(id, 1, "Deltoid") and hasProp(id, 1, "Trapezius"), id .. " : deltoïdes intégrés attendus")
	end
	-- Kaydo ★2/★3 (forme hybride) : écailles plates en coins le long des avant-bras, pas de boule
	for st = 2, 3 do
		local m = CharacterBuilder.build(Formulas.describe({ id = "oce_kaydo", level = 1, stars = st }).look, { scale = 1 })
		local n = 0
		for _, d in m:GetDescendants() do
			if d.Name == "KaydoScale" then
				assert(d:IsA("WedgePart") and math.min(d.Size.X, d.Size.Y, d.Size.Z) <= 0.1 * m:GetAttribute("BaseScale"), "Kaydo : écaille non plate")
				n += 1
			end
		end
		assert(n >= 6, "Kaydo ★" .. st .. " : écailles des avant-bras attendues (" .. n .. ")")
		m:Destroy()
	end
	-- Secrets : plus grands que les autres (Kaydo le géant encore plus) et éclat arc-en-ciel au
	-- sol dès le ★1 ; ni l'un ni l'autre dans les aperçus des menus (cadrés à la même taille)
	for id in SECRETS do
		local look = Formulas.describe({ id = id, level = 1, stars = 1 }).look
		assert((look.bodyScale or 1) >= 1.12, id .. " : Secret à peine plus grand attendu")
		local m = CharacterBuilder.build(look, { scale = 1 })
		local expected = math.max(look.bodyScale, look.minScale or 0)
		assert(math.abs((m:GetAttribute("BaseScale") or 1) - expected) < 1e-6, id .. " : BaseScale = carrure du Secret")
		m:Destroy()
		-- au niveau 1 (taille de niveau 0.85) : jamais plus petit que l'avatar joueur (plancher)
		m = CharacterBuilder.build(look, { scale = Formulas.visualScale({ id = id, level = 1, stars = 1 }) })
		assert((m:GetAttribute("BaseScale") or 1) >= 1.05 - 1e-6, id .. " : Secret plus petit que l'avatar au niveau 1")
		local glint = m:FindFirstChild("SecretGlint", true)
		assert(glint and glint:FindFirstChildOfClass("ParticleEmitter"), id .. " : éclat arc-en-ciel du Secret absent")
		m:Destroy()
		local preview = CharacterBuilder.buildPreview(look)
		assert(preview:FindFirstChild("SecretGlint", true) == nil, id .. " : éclat dans l'aperçu des menus")
		assert((preview:GetAttribute("BaseScale") or 1) == 1, id .. " : aperçu des menus à l'échelle 1")
		preview:Destroy()
	end
	assert(Formulas.describe({ id = "oce_kaydo", level = 1, stars = 1 }).look.bodyScale >= 1.25, "Kaydo : géant attendu")
	do
		-- Kaydo le géant : ~30 % de plus que l'avatar joueur (échelle 1) dès le niveau 1
		local entry = { id = "oce_kaydo", level = 1, stars = 1 }
		local m = CharacterBuilder.build(Formulas.describe(entry).look, { scale = Formulas.visualScale(entry) })
		assert(m:GetAttribute("BaseScale") >= 1.3, "Kaydo : pas un géant en jeu (" .. m:GetAttribute("BaseScale") .. ")")
		m:Destroy()
		-- les aperçus des menus restent cadrés à l'échelle 1
		local preview = CharacterBuilder.buildPreview(Formulas.describe(entry).look)
		assert((preview:GetAttribute("BaseScale") or 1) == 1, "Kaydo : aperçu des menus à l'échelle 1")
		preview:Destroy()
	end
	-- Susanoo de Radama ★2 : squelette en blocs et coins (aucune sphère, en jeu comme dans les
	-- menus), colonne centrée, côtes symétriques qui contournent les bras, crâne centré derrière
	-- la tête, colonne en flammèches bleues (en jeu seulement)
	for _, mode in { "game", "parts" } do
		local look = Formulas.describe({ id = "ninja_radama", level = 1, stars = 2 }).look
		local m = mode == "parts" and CharacterBuilder.buildPreview(look) or CharacterBuilder.build(look, { scale = 1 })
		local k = m:GetAttribute("BaseScale") or 1
		local tag = "Susanoo (" .. mode .. ") : "
		local spine = m:FindFirstChild("SusanooSpine", true)
		assert(spine, tag .. "colonne absente")
		if mode == "game" then
			assert(spine:FindFirstChild("PropFlames"), tag .. "flammèches de la colonne absentes")
		end
		assert(m:FindFirstChild("SusanooSkull", true) and m:FindFirstChild("SusanooOrbit", true) and m:FindFirstChild("SusanooJaw", true), tag .. "crâne incomplet")
		local torso = m:FindFirstChild("Torso")
		local head = m:FindFirstChild("Head")
		local left, right = {}, {}
		local skullX, skullN = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 7) == "Susanoo" then
				assert(not d:FindFirstChildOfClass("SpecialMesh"), tag .. d.Name .. " en sphère")
				assert(not (d:IsA("Part") and d.Shape == Enum.PartType.Ball), tag .. d.Name .. " en boule")
				local rel = torso.CFrame:PointToObjectSpace(d.CFrame.Position) / k
				if d.Name == "SusanooRib" then
					-- devant le plan du dos : seulement à l'extérieur des bras (jamais devant l'armure)
					if rel.Z < 0.5 then
						assert(math.abs(rel.X) >= 1.95, tag .. "côte devant le torse (x = " .. rel.X .. ", z = " .. rel.Z .. ")")
					end
					table.insert(rel.X < 0 and left or right, rel)
				elseif d.Name == "SusanooSpine" or d.Name == "SusanooVertebra" then
					assert(math.abs(rel.X) < 0.05 and rel.Z > 0.5 and rel.Z < 1.0, tag .. "colonne décentrée")
				elseif d.Name == "SusanooSkull" then
					local h = head.CFrame:PointToObjectSpace(d.CFrame.Position) / k
					skullX += h.X
					skullN += 1
					assert(h.Z > 0.5 and h.Y < 2.2, tag .. "crâne mal placé")
				end
			end
		end
		-- côtes symétriques : même nombre de chaque côté, positions en miroir
		assert(#left == #right and #left >= 16, tag .. "côtes asymétriques (" .. #left .. " / " .. #right .. ")")
		local widest = 0
		for _, r in right do
			widest = math.max(widest, r.X)
			local mirrored = false
			for _, l in left do
				if math.abs(l.X + r.X) + math.abs(l.Y - r.Y) + math.abs(l.Z - r.Z) < 0.03 then
					mirrored = true
					break
				end
			end
			assert(mirrored, tag .. "côte sans pendant en miroir")
		end
		assert(widest >= 2.4, tag .. "cage trop étroite (" .. widest .. ")")
		assert(skullN >= 3 and math.abs(skullX / skullN) < 0.05, tag .. "crâne décentré")
		m:Destroy()
	end
	-- Kaydo : la massue n'est jamais devant ni derrière le visage (tenue verticale sur le flanc
	-- droit) ; mèches latérales derrière les oreilles
	for st = 1, 3 do
		local look = Formulas.describe({ id = "oce_kaydo", level = 1, stars = st }).look
		assert((look.hairSweep or 108) <= 95, "Kaydo : mèches latérales sur le visage")
		for _, mode in { "game", "parts" } do
			local m = mode == "parts" and CharacterBuilder.buildPreview(look) or CharacterBuilder.build(look, { scale = 1 })
			local k = m:GetAttribute("BaseScale") or 1
			local head = m:FindFirstChild("Head")
			local n = 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Kanabo" then
					n += 1
					local rel = head.CFrame:PointToObjectSpace(d.CFrame.Position) / k
					assert(math.abs(rel.X) > 1.3, "Kaydo ★" .. st .. " : massue dans l'axe de la tête (x = " .. rel.X .. ")")
					assert(rel.Y < 0, "Kaydo ★" .. st .. " : massue à hauteur du visage")
				end
			end
			assert(n >= 5, "Kaydo ★" .. st .. " : massue absente")
			m:Destroy()
		end
	end
	-- Kaydo ★2 (forme dragon) : se distingue du ★1 au premier coup d'œil
	do
		local l1 = Formulas.describe({ id = "oce_kaydo", level = 1, stars = 1 }).look
		local l2 = Formulas.describe({ id = "oce_kaydo", level = 1, stars = 2 }).look
		assert(l2.eyeGlow and not l1.eyeGlow, "Kaydo ★2 : yeux luisants attendus")
		assert(l2.capeColor ~= l1.capeColor, "Kaydo ★2 : cape d'une autre teinte attendue")
		local m = CharacterBuilder.build(l2, { scale = 1 })
		local k = m:GetAttribute("BaseScale")
		local torso = m:FindFirstChild("Torso")
		local limbs, scales, horns, tailX = {}, 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "KaydoScale" then
					scales += 1
					limbs[d.Parent and d.Parent.Name or "?"] = true
				elseif d.Name == "KaydoHorn" then
					horns += 1
				elseif d.Name == "KaydoTail" then
					tailX = math.min(tailX, torso.CFrame:PointToObjectSpace(d.CFrame.Position).X / k)
				end
			end
		end
		assert(scales >= 12, "Kaydo ★2 : écailles attendues sur les deux avant-bras, les épaules et les pommettes (" .. scales .. ")")
		assert(horns >= 4, "Kaydo ★2 : cornes recourbées en deux segments attendues")
		assert(tailX < -2.1, "Kaydo ★2 : la queue doit dépasser de la silhouette sur le côté")
		m:Destroy()
	end
	-- Rika (Yuuto ★2) : tête, bouche peinte de dents, yeux rouges luisants
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "occ_yuuto", level = 1, stars = 2 }).look, { scale = 1 })
		assert(m:FindFirstChild("RikaHead", true), "Rika : tête absente")
		local mouth = m:FindFirstChild("RikaMouth", true)
		assert(mouth and mouth:FindFirstChildOfClass("SurfaceGui"), "Rika : dents non peintes")
		local glow = false
		for _, d in m:GetDescendants() do
			if d.Name == "RikaEye" and d:FindFirstChild("PropGlow") then
				glow = true
			end
		end
		assert(glow, "Rika : yeux sans lueur")
		-- Rika en blocs et coins (crâne anguleux, dos voûté) : plus de grosses sphères
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "RikaHead" or d.Name == "RikaBack") then
				assert(not d:FindFirstChildOfClass("SpecialMesh"), "Rika : " .. d.Name .. " en sphère")
			end
		end
		assert(m:FindFirstChild("RikaBack", true), "Rika : dos voûté absent")
		m:Destroy()
	end
	-- Hakaro : tempes rasées sur les côtés seulement (pas de bande autour de la tête)
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "occ_hakaro", level = 1, stars = 1 }).look, { scale = 1 })
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Shaved" then
				n += 1
				assert(d.Size.X < 0.5, "Hakaro : rasé tout autour de la tête")
			end
		end
		assert(n == 2, "Hakaro : deux tempes rasées attendues")
		m:Destroy()
	end
	-- Gaaro ★2/★3 : le sable sort de la gourde en petits blocs de Sable (aucune boule), avec
	-- grains, jamais plus haut que l'épaule ; au ★3, bouclier mural sur le côté
	for st = 2, 3 do
		local look = Formulas.describe({ id = "ninja_gaaro", level = 1, stars = st }).look
		local m = CharacterBuilder.build(look, { scale = 1 })
		local k = m:GetAttribute("BaseScale") or 1
		local wave = m:FindFirstChild("SandWave", true)
		assert(wave and wave:FindFirstChild("PropDust"), "Gaaro ★" .. st .. " : vague de sable sans grains")
		local torso = m:FindFirstChild("Torso")
		local sand, wall = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Sand" or d.Name == "SandWave" or d.Name == "SandWall") then
				assert(d.Material == Enum.Material.Sand, "Gaaro : sable sans matériau Sable")
				assert(not d:FindFirstChildOfClass("SpecialMesh"), "Gaaro : boule de sable")
				local rel = torso.CFrame:PointToObjectSpace(d.CFrame.Position) / k
				assert(rel.Y <= 1.6, "Gaaro ★" .. st .. " : sable plus haut que l'épaule (" .. rel.Y .. ")")
				sand += 1
				if d.Name == "SandWall" then
					wall += 1
				end
			end
		end
		assert(sand >= 14, "Gaaro ★" .. st .. " : flot de sable trop maigre (" .. sand .. ")")
		assert(st == 2 or wall >= 10, "Gaaro ★3 : bouclier mural attendu")
		m:Destroy()
	end
	-- Coiffures : Muzon ★2 en vagues de coins (pas de boules), Tengan cheveux plaqués + bandeau
	-- à gemmes en néon (pas de hérisson)
	do
		local look = Formulas.describe({ id = "pou_muzon", level = 1, stars = 2 }).look
		for _, p in look.props do
			if p.limb == "Head" then
				assert(p.shape ~= "strand" and p.shape ~= "ball", "Muzon ★2 : boucles en boules")
			end
		end
		local m = CharacterBuilder.build(look, { scale = 1 })
		local curls = 0
		for _, d in m:GetDescendants() do
			if d.Name == "MuzonCurl" then
				assert(d:IsA("WedgePart"), "Muzon : boucle qui n'est pas un coin")
				curls += 1
			end
		end
		assert(curls >= 15, "Muzon ★2 : boucles en vagues attendues")
		m:Destroy()
		local tl = Formulas.describe({ id = "pou_tengan", level = 1, stars = 1 }).look
		assert(tl.hair ~= "hedgehog", "Tengan : hérisson interdit")
		m = CharacterBuilder.build(tl, { scale = 1 })
		local gems, locks = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Gem" then
				assert(d.Material == Enum.Material.Neon, "Tengan : gemme non lumineuse")
				gems += 1
			elseif d.Name == "TenganLock" then
				locks += 1
			end
		end
		assert(gems == 5 and locks >= 3 and locks <= 4, "Tengan : bandeau à gemmes et 3-4 mèches attendus")
		m:Destroy()
	end
	-- Doma : mèches lisses et plates (aucun boudin), sang en éclaboussures plates sur le sommet
	for st = 1, 3 do
		local look = Formulas.describe({ id = "pou_doma", level = 1, stars = st }).look
		local locks, blood = 0, 0
		for _, p in look.props do
			assert(p.shape ~= "strand", "Doma ★" .. st .. " : mèche en boudin")
			if p.name == "DomaLock" then
				locks += 1
			elseif p.name == "DomaBlood" then
				blood += 1
				assert(p.shape == "wedge", "Doma : sang en relief")
			end
		end
		assert(locks >= 14 and blood >= 4, "Doma ★" .. st .. " : mèches plates et sang attendus")
	end
	-- Jirène sans marques sur les joues ; crête de Cel symétrique (une lame de chaque côté)
	assert(not Formulas.describe({ id = "sai_jirene", level = 1, stars = 1 }).look.jawShade, "Jirène : marques sur les joues")
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "sai_cel", level = 1, stars = 1 }).look, { scale = 1 })
		local head = m:FindFirstChild("Head")
		local xs = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 8) == "CelCrest" then
				table.insert(xs, head.CFrame:PointToObjectSpace(d.CFrame.Position).X)
			end
		end
		local l, r = 0, 0
		for _, x in xs do
			if x < -0.1 then
				l += 1
			elseif x > 0.1 then
				r += 1
			end
		end
		assert(l > 0 and l == r, "Cel : crête asymétrique (" .. l .. " / " .. r .. ")")
		m:Destroy()
	end
	-- Pas de bouche « rouge à lèvres » (grand sourire ouvert) pour Hakaro et Inel
	for _, id in { "occ_hakaro", "oce_inel" } do
		local style = Formulas.describe({ id = id, level = 1, stars = 1 }).look.mouthStyle
		assert(style ~= "grin" and style ~= "wide_grin", id .. " : bouche ouverte rouge")
	end
	-- Dos de Minatu : « Quatrième Hokage » en colonne de caractères rouges
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "ninja_minatu", level = 1, stars = 1 }).look, { scale = 1 })
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("TextLabel") and d.Name == "HaoriKanji" then
				n += 1
			end
		end
		assert(n == 5, "Minatu : kanji du dos du haori attendus (" .. n .. ")")
		m:Destroy()
	end
	-- Variété Arc-en-ciel : reflet en bande étroite (la tenue garde sa couleur)
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "pou_muzon", level = 1, stars = 1 }).look, { scale = 1 })
		CharacterBuilder.applyVariety(m, "Arc-en-ciel")
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("UIGradient") and d.Name == "VarietyRainbow" then
				n += 1
				local kp = d.Transparency.Keypoints
				assert(kp[1].Value >= 0.99 and kp[#kp].Value >= 0.99, "Arc-en-ciel : les bords du reflet doivent être transparents")
				local least = 1
				for _, k in kp do
					least = math.min(least, k.Value)
				end
				assert(least >= 0.6, "Arc-en-ciel : reflet trop couvrant")
			end
		end
		assert(n > 0, "Arc-en-ciel : reflet absent")
		m:Destroy()
	end
	-- Chaque perso jouable a une attaque signature valide (plus de repli générique)
	for id in Characters.List do
		local sig = AttackFx.Characters[id]
		assert(sig and AttackFx.Signatures[sig], id .. " : pas d'attaque signature")
		assert(AttackFx.forCharacter(id, "punch") == sig, id .. " : signature non résolue")
	end
	-- Noms proches des originaux, tous différents
	local names = {}
	for id, def in Characters.List do
		assert(not names[def.name], def.name .. " en double (" .. id .. ")")
		names[def.name] = true
	end
end)

test("Intégration v3.2 : variété tirée visible partout (fabrique, aperçu), majuscules accentuées", function()
	local Factory = requireModule(Shared.Modules.CharacterFactory)
	assert(Formulas.upper("Légendaire") == "LÉGENDAIRE" and Formulas.upper("Planète des Guerriers") == "PLANÈTE DES GUERRIERS", "majuscules accentuées")
	local look = Characters.get("ninja_maruto").look
	-- La mutation tirée (champ « aura » = variété) passe par CharacterFactory.build.
	local model = Factory.build("ninja_maruto", 1, look, { variety = "diamant", anchored = true })
	assert(model:GetAttribute("Mutation") == "diamant", "variété non appliquée par la fabrique")
	assert(model:FindFirstChildOfClass("Highlight") == nil, "Highlight posé côté serveur")
	model:Destroy()
	-- Foudre : la partie PERSOS ne teinte que les cheveux, le signe de la mutation est ajouté.
	local bolt = Factory.build("ninja_maruto", 1, look, { variety = "foudre", anchored = true })
	assert(bolt:FindFirstChild("MutationSigne", true), "Foudre sans son signe (éclairs)")
	bolt:Destroy()
	-- Aperçu des menus (ViewportFrame) : la variété aussi, sans contour lumineux.
	local preview = Factory.buildPreview("ninja_maruto", 1, look, "galaxie")
	assert(preview:GetAttribute("Mutation") == "galaxie", "aperçu sans variété")
	assert(preview:FindFirstChildOfClass("Highlight") == nil, "Highlight dans un aperçu")
	preview:Destroy()
	-- Variété inconnue : rien ne casse.
	local plain = Factory.build("ninja_maruto", 1, look, { variety = "inconnue", anchored = true })
	assert(plain:GetAttribute("Mutation") == nil, "variété inconnue appliquée")
	plain:Destroy()
end)

test("Kourama : vraie créature (renard à neuf queues) compatible avec le combat", function()
	local Factory = requireModule(Shared.Modules.CharacterFactory)
	local Creature = requireModule(Shared.Modules.CreatureBuilder)
	local look = Characters.Enemies.ninja_kourama.look
	assert(look.creature == "kurama" and Creature.kindOf(look) == "kurama", "Kourama n'est pas une créature")
	for id, def in Characters.Enemies do
		assert(id == "ninja_kourama" or Creature.kindOf(def.look) == nil, id .. " : créature à tort")
	end
	local s = Economy.Boss.scale
	local model = Factory.build("ninja_kourama", 1, look, { scale = s, humanoid = true, collisionGroup = "Enemies", name = "Kourama" })
	assert(model:GetAttribute("Creature") == "kurama", "attribut Creature manquant")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root and model.PrimaryPart == root and root.Transparency == 1 and root.CanCollide, "HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid and humanoid:FindFirstChildOfClass("Animator"), "Humanoid + Animator")
	assert(math.abs(humanoid.HipHeight - Creature.HipHeight * s) < 1e-4, "HipHeight")
	assert(not model:FindFirstChild("Left Arm") and not model:FindFirstChild("Right Leg"), "construit comme un perso R6")
	assert(math.abs(model:GetAttribute("RootHeight") - Creature.RootHeight * s) < 1e-4 and model:GetAttribute("BaseScale") == s, "attributs d'échelle")
	-- Neuf queues segmentées (Motor6D) + articulations cohérentes.
	local tails, parts, motors, lowest, highest = {}, 0, 0, math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			assert(not d.Anchored, d.Name .. " ancrée")
			assert(d.CollisionGroup == "Enemies", d.Name .. " hors groupe Enemies")
			if d ~= root then
				assert(not d.CanCollide and d.Massless, d.Name .. " : collision / masse")
				-- Étendue verticale réelle de la pièce tournée (les queues sont couchées en éventail).
				local cf, size = d.CFrame, d.Size
				local half = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
				lowest = math.min(lowest, cf.Position.Y - half)
				highest = math.max(highest, d.CFrame.Position.Y)
			end
		elseif d:IsA("Motor6D") then
			motors += 1
			local a = d.Part0.CFrame * d.C0
			local b = d.Part1.CFrame * d.C1
			assert((a.Position - b.Position).Magnitude < 1e-3, "articulation décalée : " .. d.Name)
			local i = string.match(d.Name, "^Tail(%d+)_1$")
			if i then
				tails[i] = true
			end
		end
	end
	local tailCount = 0
	for _ in tails do
		tailCount += 1
	end
	assert(tailCount == 9, "9 queues attendues (" .. tailCount .. ")")
	assert(parts <= 260, "trop de pièces : " .. parts)
	assert(lowest > -0.15 * s and lowest < 0.4 * s, "pattes pas au sol : " .. lowest)
	assert(highest > 5.2 * s, "trop petit pour un boss")
	for _, name in { "Head", "Torso", "Jaw", "LeftEar", "RightEar" } do
		assert(model:FindFirstChild(name), "pièce manquante : " .. name)
	end
	assert(model:FindFirstChild("Head").CanQuery and model:FindFirstChild("Torso").CanQuery, "non cliquable")
	-- Les queues reçoivent aussi les clics (plus de la moitié de la silhouette).
	for i = 1, 9 do
		local seg = model:FindFirstChild("Tail" .. i .. "_2")
		assert(seg and seg.CanQuery, "queue " .. i .. " non cliquable")
	end
	-- Portée (CombatService) et hauteur d'étiquette (NameTags) adaptées à la taille de la créature.
	local reach, tagHeight = model:GetAttribute("Reach"), model:GetAttribute("TagHeight")
	assert(type(reach) == "number" and reach > 2.5 + s * 1.6, "portée Reach manquante ou trop courte")
	assert(type(tagHeight) == "number" and math.abs(tagHeight - (highest - root.CFrame.Position.Y)) < 2 * s, "TagHeight : " .. tostring(tagHeight))
	-- Aperçu des menus : ancré, sans SurfaceGui.
	local preview = Factory.buildPreview("ninja_kourama", 1, look)
	assert(preview:GetAttribute("Creature") == "kurama", "aperçu R6")
	for _, d in preview:GetDescendants() do
		assert(not d:IsA("SurfaceGui"), "SurfaceGui dans l'aperçu")
		assert(not d:IsA("BasePart") or d.Anchored, "aperçu non ancré")
	end
	print(string.format("   %d pièces, %d articulations, %d queues", parts, motors, tailCount))
end)

test("Construction de fusions (toutes les paires Légendaire/Mythique)", function()
	local ids = {}
	for id, def in Characters.List do
		if def.rarity == "legendary" or def.rarity == "mythic" then
			table.insert(ids, id)
		end
	end
	local count = 0
	for _, a in ids do
		for _, b in ids do
			if Characters.get(a).universe ~= Characters.get(b).universe then
				local entry = { id = "fusion", fusion = { a = a, b = b }, level = 1, stars = 2 }
				local desc = Formulas.describe(entry)
				CharacterBuilder.build(desc.look, { scale = 1 })
				count += 1
			end
		end
	end
	print("   " .. count .. " fusions construites")
end)

test("Construction de toutes les reliques", function()
	for id, relic in Universes.Relics do
		local model = RelicBuilder.build(relic.look, relic.tier, 1)
		assert(countParts(model) > 3, id)
	end
end)

local Workspace = game:GetService("Workspace")
local Server = find("ServerScriptService.Server")

test("Construction de la carte", function()
	local WorldBuilder = requireModule(Server.World.WorldBuilder)
	WorldBuilder.build()
	print("   pièces de la carte : " .. countParts(Workspace))
end)

test("Défis : configuration cohérente (paliers croissants, ennemis, récompenses)", function()
	local Quests = requireModule(Shared.Config.Quests)
	assert(#Quests.List >= 35, "pas assez de défis : " .. #Quests.List)
	local ids = {}
	local perUniverse = {}
	for _, quest in Quests.List do
		assert(not ids[quest.id], "identifiant de défi en double : " .. quest.id)
		ids[quest.id] = true
		assert(#quest.tiers >= 3, quest.id .. " : il faut au moins 3 paliers")
		local previous = 0
		for _, tier in quest.tiers do
			assert(tier.goal > previous, quest.id .. " : paliers non croissants")
			previous = tier.goal
			assert((tier.reward.coins or 0) > 0 or (tier.reward.gems or 0) > 0, quest.id .. " : palier sans récompense")
		end
		assert(string.find(quest.title, "%s", 1, true), quest.id .. " : titre sans objectif")
		if quest.universe then
			perUniverse[quest.universe] = (perUniverse[quest.universe] or 0) + 1
		end
	end
	for _, universe in Universes.List do
		assert((perUniverse[universe.id] or 0) >= 5, universe.id .. " : pas assez de défis d'univers")
		local name = Characters.Enemies[universe.enemies[1]].name
		assert(ids["u_" .. universe.id .. "_1"], "défi « tue " .. name .. " » manquant")
	end
	-- Objets des défis d'univers = objets de base de l'univers (palier 1, 2, 3), Saiyan compris.
	local Items = requireModule(Shared.Config.EvolutionItems)
	for universeId, list in Items.Universe do
		for i, itemId in list do
			assert(Quests.UniverseItems[universeId][i] == itemId, "objet de défi décalé : " .. universeId .. " n°" .. i)
		end
	end
	local saiyan3 = Quests.ById.u_saiyan_3.tiers[3].reward.items
	assert(saiyan3 and saiyan3.sai_haricot == 2 and not saiyan3.sai_boule_divine, "défi Saiyan n°3 : objet de palier 2 attendu")
	local saiyanBoss = Quests.ById.u_saiyan_boss.tiers[3].reward.items
	assert(saiyanBoss and saiyanBoss.sai_boule_divine == 1 and saiyanBoss.sai_dragon == 1, "boss Saiyan : palier 3 + Boule du Dragon")
	-- Exemple demandé : « Village Ninja : tue 200 <ennemi> » → 1 000 pièces
	local ninja = Quests.ById.u_ninja_1
	assert(ninja.tiers[2].goal == 200 and ninja.tiers[2].reward.coins == 1000, "exemple 200 kills / 1000 pièces")
	-- Exemple exact de l'utilisateur : « Village Ninja : tue 200 Kakashu » → 1 000 pièces (rival)
	local rival = Quests.ById.u_ninja_rival1
	assert(rival and rival.rival == "ninja_kakashu", "défi « Tue 200 Kakashu » manquant")
	assert(Quests.title(rival, rival.tiers[2].goal) == "Tue 200 Kakashu", Quests.title(rival, rival.tiers[2].goal))
	assert(rival.tiers[2].reward.coins == 1000, "Tue 200 Kakashu doit donner 1 000 pièces (minimum)")
	assert(rival.tiers[1].goal == 50 and rival.tiers[3].goal == 1000, "paliers du rival : 50 → 200 → 1 000")
	-- Pièces adaptées au revenu : minimum = valeur de base, sinon 5 / 15 / 45 min de revenu
	assert(Quests.rewardCoins(rival.tiers[2].reward, 0) == 1000, "sans revenu : valeur de base")
	assert(Quests.rewardCoins(rival.tiers[2].reward, 2540) == 2300000, "15 min de 2 540 ¥/s ≈ 2,3 M")
	assert(Quests.rewardCoins(rival.tiers[1].reward, 2540) == 760000, "5 min de 2 540 ¥/s ≈ 760 k")
	assert(Quests.rewardCoins(Quests.DailyBonus, 100) == 180000, "coffre du jour : 30 min de revenu")
	assert(Quests.rewardCoins(Quests.DailyById.d_kill.reward, 1) == Quests.DailyById.d_kill.reward.coins, "petit revenu : minimum")
	local long = {}
	for _, quest in Quests.List do
		local title = Quests.title(quest, quest.tiers[#quest.tiers].goal)
		if utf8.len(title) > 31 then
			table.insert(long, title)
		end
	end
	assert(#long == 0, "titres trop longs : " .. table.concat(long, " | "))
	local firstNinja
	for _, quest in Quests.List do
		if quest.universe == "ninja" then
			firstNinja = quest
			break
		end
	end
	assert(firstNinja == rival, "le premier défi du Village Ninja doit être « Tue 200 Kakashu »")
	for _, universe in Universes.List do
		assert(#Quests.rivalsFor(universe) >= 2, universe.id .. " : il faut au moins 2 rivaux")
	end
	assert(Quests.Punch.Bags == 3, "il faut exactement 3 punching-balls")
	assert(Quests.punchCycleGems() == 20 and Quests.Punch.Goal == 1000, "1000 coups doivent donner 20 gemmes")
	assert(#Quests.pickDaily(20000, 42) == Quests.DailyCount, "défis du jour")
	local a, b = Quests.pickDaily(20000, 42), Quests.pickDaily(20000, 42)
	assert(table.concat(a) == table.concat(b), "tirage du jour instable")
	assert(Quests.title(ninja, 1000) == "Tue 1 000 Ninjas du Son", Quests.title(ninja, 1000))
	assert(Quests.title(Quests.ById.u_ocean_1, 50) == "Tue 50 Pirates de Buggi", Quests.title(Quests.ById.u_ocean_1, 50))
	-- Défi du jour « Gagne X pièces » adapté au revenu du joueur
	local coinsDaily = Quests.DailyById.d_coins
	assert(Quests.dailyGoalFor(coinsDaily, 0) == coinsDaily.goal, "objectif de pièces minimal")
	assert(Quests.dailyGoalFor(coinsDaily, 10000) == 12000000, "objectif de pièces selon le revenu")
	-- Progression lue dans une sauvegarde
	local data = {
		RollCount = 12,
		stats = { evolutions = 0, playtime = 600 },
		Quests = { counters = { kill = 5 }, claimed = { p_roll = 0 }, daily = { list = { "d_kill" }, base = { kill = 2 }, claimed = {} } },
	}
	assert(Quests.read(data, "stat:RollCount") == 12 and Quests.read(data, "stat:playtime") == 10 and Quests.read(data, "kill") == 5, "lecture des compteurs")
	assert(Quests.dailyProgress(data, "d_kill") == 3, "progression du jour")
	assert(Quests.readyCount(data) == 0, "rien ne doit être prêt")
	data.Quests.counters.kill = 200
	assert(Quests.dailyReady(data, "d_kill") and Quests.readyCount(data) >= 2, "défis prêts non détectés")
end)

test("Zone anti-AFK : 3 punching-balls, invites, compteurs, rien d'agressif", function()
	local Layout = requireModule(Shared.Config.Layout)
	local AfkZone = requireModule(Server.World.AfkZone)
	local world = Workspace:FindFirstChild("World")
	assert(world, "carte absente")
	local zone = world:FindFirstChild("AfkZone")
	assert(zone, "zone anti-AFK absente de la carte")
	local stations = AfkZone.stations(world)
	assert(#stations == 3, "il faut exactement 3 punching-balls (" .. #stations .. ")")
	for i, station in stations do
		assert(station:GetAttribute("Station") == i, "numéro de poste")
		local anchor = station:FindFirstChild("PromptAnchor")
		local prompt = anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
		assert(prompt and prompt.HoldDuration == 0, "invite « Frapper » manquante")
		assert(anchor:FindFirstChild("Counter"), "compteur au-dessus du sac manquant")
		local bag = station:FindFirstChild("Bag")
		assert(bag and bag.PrimaryPart and bag.PrimaryPart.Name == "Hook", "sac sans crochet (pivot)")
		local p = anchor.CFrame.Position
		local c = Layout.AfkZone
		assert(math.sqrt((p.X - c.X) ^ 2 + (p.Z - c.Z) ^ 2) < 30, "poste hors de la zone")
		assert(Layout.isReserved(p, 0), "poste hors du lieu réservé")
	end
	-- Rien d'agressif : aucune arme, aucun ennemi, aucun script dans la zone
	for _, d in zone:GetDescendants() do
		assert(not d:IsA("Humanoid") and not d:IsA("Tool") and not d:IsA("Script"), "objet agressif dans la zone : " .. d:GetFullName())
	end
	print("   pièces de la zone anti-AFK : " .. countParts(zone))
	assert(countParts(zone) < 1500, "zone anti-AFK trop lourde")
end)

test("Décors des 5 univers", function()
	local UniverseDecor = requireModule(Server.World.UniverseDecor)
	local zone = Workspace.World.Zone
	-- chaque univers a son propre module (repère emblématique) et reste dans le budget de pièces
	local signature = {
		ninja = "TourDuChef",
		occulte = "Pagode",
		saiyan = "AreneDuTournoi",
		ocean = "Navire",
		pourfendeur = "PortePourfendeurs",
	}
	local BUDGET = 40000 -- marge pour les autres domaines (marchand, défis, classements)
	for _, universe in Universes.List do
		local decor = UniverseDecor.apply(universe, zone)
		local parts = countParts(decor)
		print(string.format("   %-24s %4d pièces", universe.name, parts))
		assert(parts <= BUDGET, universe.id .. " : trop de pièces (" .. parts .. " > " .. BUDGET .. ")")
		local found = false
		for _, item in decor:GetDescendants() do
			if item:IsA("Model") and item:GetAttribute("Slot") == signature[universe.id] then
				found = true
				break
			end
		end
		assert(found, universe.id .. " : repère « " .. tostring(signature[universe.id]) .. " » absent (module d'univers manquant ?)")
		for _, folderName in { "Anneau", "Ile", "Horizon" } do
			assert(decor:FindFirstChild(folderName), universe.id .. " : dossier " .. folderName .. " absent (toute la carte doit changer)")
		end
		assert(universe.theme.sol and universe.theme.sol.herbe and universe.theme.ciel, universe.id .. " : sol / ciel absents")
	end
end)

test("Lieux réservés dégagés (échanges, marchand, anti-AFK) dans les 5 univers", function()
	local WorldBuilder = requireModule(Server.World.WorldBuilder)
	local UniverseDecor = requireModule(Server.World.UniverseDecor)
	local Layout = requireModule(Shared.Config.Layout)
	local zone = Workspace.World.Zone
	-- l'accès du coin des échanges (entre la promenade et son entrée) est réservé
	assert(WorldBuilder.reserved(Layout.polar(0, 400), 0), "accès du coin des échanges non réservé")
	assert(not WorldBuilder.reserved(Layout.polar(15, 600), 0), "zone libre marquée réservée")
	local flat = { Patch = true, Pebble = true, Road = true, RoadPatch = true, Curb = true, Trail = true, Dirt = true, PathStone = true }
	local function offenders(root: Instance, skip: { [string]: boolean }): { string }
		local found = {}
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and not flat[d.Name] and d.Transparency < 1 then
				local pos = d.CFrame.Position
				if pos.Y < 40 and WorldBuilder.reserved(pos, 0) then
					local top = d
					while top.Parent and top.Parent ~= root do
						top = top.Parent
					end
					if not skip[top.Name] then
						table.insert(found, top.Name .. "/" .. d:GetFullName())
					end
				end
			end
		end
		return found
	end
	local fixed = offenders(Workspace.World, { TradeCorner = true, Paths = true, Boards = true, Zone = true, Plots = true, Merchant = true, AfkZone = true })
	assert(#fixed == 0, "carte fixe : objet dans un lieu réservé : " .. tostring(fixed[1]))
	for _, universe in Universes.List do
		local decor = UniverseDecor.apply(universe, zone)
		local found = offenders(decor, {})
		assert(#found == 0, universe.id .. " : objet dans un lieu réservé : " .. tostring(found[1]))
		local dress = decor:FindFirstChild("Habillage", true)
		assert(dress and (dress:GetAttribute("Elements") or 0) >= 30, universe.id .. " : île pas assez habillée")
		assert((dress:GetAttribute("Landmarks") or 0) >= 8, universe.id .. " : pas assez de grands repères sur l'île")
		-- semis de remplissage (touffes, fleurs, cailloux...) : plus de grandes pelouses unies
		assert((dress:GetAttribute("Semis") or 0) >= 400, universe.id .. " : semis de remplissage absent")
	end
	-- un sentier pavé mène à chaque coin du marchand
	local paths = Workspace.World:FindFirstChild("SentiersMarchand")
	assert(paths and #paths:GetChildren() >= #Layout.MerchantSpots, "sentiers du marchand absents")
	print("   aucun décor sur les lieux réservés ni sur leurs accès")
end)

test("Montagne des chefs (8 têtes sculptées) et enseignes artisanales", function()
	local Hokage = requireModule(Server.World.Kit.Hokage)
	local Archi = requireModule(Server.World.Kit.Archi)
	local R = Harness.roblox
	local folder = R.Instance.new("Folder")
	folder.Parent = Workspace
	local model = Hokage.mountain(folder, R.CFrame.new(0, 0, 2000), Harness.Random.new(3))
	assert(model:GetAttribute("Slot") == "MontagneDesChefs", "emplacement remplaçable absent")
	local heads = model:FindFirstChild("Tetes")
	assert(heads and #heads:GetChildren() == 8, "il faut 8 têtes")
	for _, head in heads:GetChildren() do
		assert((head:GetAttribute("Pieces") or 0) >= 150, head.Name .. " : tête trop simple")
		-- visage taillé en facettes (triangles faits de coins), pas en boules
		local facets, balls = 0, 0
		for _, d in head:GetDescendants() do
			if d:IsA("WedgePart") and d.Name == "Facette" then
				facets += 1
			elseif d:IsA("Part") and d.Shape == R.Enum.PartType.Ball then
				balls += 1
			end
		end
		assert(facets >= 200, head.Name .. " : visage pas facetté (" .. facets .. ")")
		assert(balls <= 6, head.Name .. " : trop de boules (" .. balls .. ")")
	end
	-- un triangle = deux coins dont les sommets retombent sur les trois points demandés
	local tri = R.Instance.new("Folder")
	local n = Hokage.triangle(tri, R.Vector3.new(0, 0, 0), R.Vector3.new(10, 0, 0), R.Vector3.new(3, 8, 0), R.Vector3.new(0, 0, -1), 1, R.Color3.new(1, 1, 1))
	assert(n == 2 and #tri:GetChildren() == 2, "triangle : deux coins attendus")
	-- chaque visage a son caractère : yeux ouverts (iris gravés), sourcils ; moustaches de Naruto
	for _, head in heads:GetChildren() do
		local iris, brows = 0, 0
		for _, d in head:GetDescendants() do
			if d.Name == "Iris" then
				iris += 1
			elseif d.Name == "Sourcil" then
				brows += 1
			end
		end
		assert(iris >= 2 and brows >= 1, head.Name .. " : yeux ouverts ou sourcils absents")
	end
	local whiskers = 0
	for _, d in heads.Naruto:GetDescendants() do
		if d.Name == "Moustache" then
			whiskers += 1
		end
	end
	assert(whiskers == 6, "Naruto : trois moustaches par joue attendues (" .. whiskers .. ")")
	-- contour en dôme : bosse au centre, épaules qui descendent jusqu'au sol
	assert(Hokage.topAt(0) > Hokage.topAt(Hokage.Width / 2) + 30, "sommet plat : pas de dôme")
	assert(Hokage.topAt(Hokage.Reach - 2) < 40, "épaules : le relief ne descend pas jusqu'au sol")
	local parts = countParts(model)
	assert(parts < 5200, "montagne trop lourde : " .. parts)
	print("   montagne : " .. parts .. " pièces dont têtes " .. heads:GetAttribute("Pieces"))
	folder:Destroy()
	assert(Archi.stripIcon("🤝 COIN DES ÉCHANGES") == "COIN DES ÉCHANGES", "émoji non retiré")
	assert(Archi.stripIcon("天下一武道会") == "天下一武道会", "kanji retirés à tort")
	assert(Archi.titleCase("FAIRE ÉVOLUER") == "Faire évoluer", Archi.titleCase("FAIRE ÉVOLUER"))
	local stall = Workspace.World.Hub.Stalls:FindFirstChild("Stall_Forge")
	local painted = false
	for _, d in stall:GetDescendants() do
		if d:IsA("TextLabel") then
			assert(not string.find(d.Text, "🗡"), "émoji encore sur l'enseigne du forgeron")
			-- Dans le fichier pré-construit (bake), Lune ne relit pas toujours la propriété Font :
			-- on regarde alors la famille de FontFace.
			local okFont, font = pcall(function()
				return d.Font
			end)
			local okFace, face = pcall(function()
				return d.FontFace.Family
			end)
			local fondamento = (okFont and font == Harness.roblox.Enum.Font.Fondamento) or (okFace and type(face) == "string" and string.find(face, "Fondamento", 1, true) ~= nil)
			if d.Text == "Forgeron" and fondamento then
				painted = true
			end
		end
	end
	assert(painted, "enseigne peinte du forgeron absente")
end)

test("Carte : le sol suit l'univers, éléments remplaçables", function()
	local UniverseDecor = requireModule(Server.World.UniverseDecor)
	local zone = Workspace.World.Zone
	local grass = Workspace.World.Ground:FindFirstChild("Grass")
	assert(grass and grass:GetAttribute("Role") == "herbe", "herbe de l'île non marquée")
	for _, id in { "occulte", "ninja" } do
		local universe = Universes.get(id)
		UniverseDecor.apply(universe, zone)
		assert(grass.Color == universe.theme.sol.herbe[1], "couleur du sol non appliquée : " .. id)
	end
	local slots, sized = 0, 0
	for _, item in zone.Decor:GetDescendants() do
		if item:IsA("Model") and item:HasTag("DecorSlot") then
			slots += 1
			if (item:GetAttribute("TargetHeight") or 0) > 0 and item:GetAttribute("Slot") then
				sized += 1
			end
		end
	end
	assert(slots > 50 and sized == slots, "emplacements remplaçables manquants")
	print("   emplacements remplaçables (Village Ninja) : " .. slots)
end)

test("Bases des joueurs + toutes les améliorations", function()
	local Remotes = requireModule(Shared.Modules.Remotes)
	assert(Remotes.event("Notify"))
	local PlotService = requireModule(Server.Services.PlotService)
	local allUpgrades = {}
	for _, upgrade in Economy.Upgrades do
		allUpgrades[upgrade.id] = true
	end
	local fakePlayer = { UserId = 1, DisplayName = "Testeur", SetAttribute = function() end, CharacterAdded = fakeSignal }
	local services = {
		DataService = {
			Get = function()
				return { upgrades = allUpgrades, coins = 0, stash = 0 }
			end,
		},
		CharacterService = {
			GetBestLook = function()
				return Characters.get("ninja_maruto").look
			end,
		},
	}
	PlotService:Init(services)
	local plot = PlotService:GetPlots()[1]
	-- Accès interne : on enregistre la base pour ce joueur via _assign simplifié.
	PlotService:_assign(fakePlayer, {})
	assert(PlotService:GetPlot(fakePlayer) == plot, "base non attribuée")
	assert(#plot.ownerFolder.Structures:GetChildren() == #Economy.Upgrades, "structures manquantes")
	-- Chaque bouton est dans la zone de jeu (hors bande de déco de 10 studs).
	local Structures = requireModule(Server.Modules.TycoonStructures)
	local limit = Structures.Spots.inner - 3.8
	for _, upgrade in Economy.Upgrades do
		local pad = Structures.padPosition(upgrade.id)
		assert(pad, "bouton sans position : " .. upgrade.id)
		assert(math.abs(pad.X) <= limit and math.abs(pad.Z) <= limit, "bouton hors de la zone de jeu : " .. upgrade.id)
	end
	assert(#plot.slots == 26 and plot.machine.prompt and plot.skillRefs.prompt, "machine / cases / arbre manquants")
	assert(plot.model:FindFirstChild("Decor") and #plot.signLabels >= 2, "déco de base ou panneau manquant")
	local total = countParts(plot.model)
	print("   pièces d'une base complète : " .. total .. " (déco : " .. countParts(plot.model.Decor) .. ")")
	assert(total < 9000, "base trop lourde : " .. total .. " pièces")
end)

-- Panneaux d'achat : sur un sol dégagé, et jamais l'un sur l'autre vus depuis l'entrée et le coffre.
test("Base : panneaux d'achat dégagés, sans chevauchement (entrée, coffre)", function()
	local roblox = Harness.roblox
	local PlotService = requireModule(Server.Services.PlotService)
	local Structures = requireModule(Server.Modules.TycoonStructures)
	local Kit = requireModule(Server.Modules.TycoonKit)
	local Conveyor = requireModule(Server.Modules.TycoonConveyor)
	local plot = PlotService:GetPlots()[1]
	local Spots = Structures.Spots
	assert(Kit.BoardBottom >= 6.5, "panneaux trop bas (coupés par le socle)")
	-- 1) Le bouton (socle de rayon ~3,9) ne rentre dans aucune pièce solide de la base complète.
	local solids = {}
	for _, folder in { plot.ownerFolder:FindFirstChild("Structures"), plot.model:FindFirstChild("Interactive") } do
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide and d.Transparency < 0.9 and d.Name ~= "Pad" then
				table.insert(solids, d)
			end
		end
	end
	local requiresOf = {}
	for _, upgrade in Economy.Upgrades do
		requiresOf[upgrade.id] = upgrade.requires
	end
	local function descends(id, root)
		local cur = id
		while cur do
			if cur == root then
				return true
			end
			cur = requiresOf[cur]
		end
		return false
	end
	local hits = {}
	for _, upgrade in Economy.Upgrades do
		local pos = Structures.padPosition(upgrade.id)
		local center = (plot.cf * roblox.CFrame.new(pos.X, 1, pos.Z)).Position
		for _, part in solids do
			-- Ce qui ne peut pas exister en même temps que le bouton : sa structure et ses suites.
			local owner = part:FindFirstAncestorOfClass("Model")
			while owner and owner.Parent and owner.Parent.Name ~= "Structures" do
				owner = owner.Parent:FindFirstAncestorOfClass("Model") or owner.Parent
			end
			local skip = owner and owner.Parent and owner.Parent.Name == "Structures" and descends(owner.Name, upgrade.id)
			local cf = part.CFrame
			local loc = cf:PointToObjectSpace(center)
			local half = part.Size / 2
			local clamped = roblox.Vector3.new(math.clamp(loc.X, -half.X, half.X), math.clamp(loc.Y, -half.Y, half.Y), math.clamp(loc.Z, -half.Z, half.Z))
			local closest = cf:PointToWorldSpace(clamped)
			local flat = roblox.Vector3.new(closest.X - center.X, 0, closest.Z - center.Z).Magnitude
			local top = closest.Y - plot.cf.Position.Y
			if not skip and flat < 3.6 and top > 1 and top < 7 then
				table.insert(hits, upgrade.id .. " -> " .. part:GetFullName() .. string.format(" (%.1f / %.1f)", flat, top))
			end
		end
	end
	for _, line in hits do
		print("   ! " .. line)
	end
	assert(#hits == 0, "boutons qui rentrent dans une pièce :\n  " .. table.concat(hits, "\n  "))
	-- 2) Projection des panneaux (1920x1080, champ 70°) depuis des points de vue de joueur.
	local requires = {}
	for _, upgrade in Economy.Upgrades do
		requires[upgrade.id] = upgrade.requires
	end
	local function ancestor(a, b)
		local cur = requires[b]
		while cur do
			if cur == a then
				return true
			end
			cur = requires[cur]
		end
		return false
	end
	local W, H = 1920, 1080
	local f = (H / 2) / math.tan(math.rad(35))
	local stashPos = Spots.chest + roblox.Vector3.new(0, 4.9 + Conveyor.StashCard.offsetY, 0.6)
	local boards = {}
	for _, upgrade in Economy.Upgrades do
		local pos = Structures.padPosition(upgrade.id)
		table.insert(boards, {
			id = upgrade.id,
			ground = pos,
			p = pos + roblox.Vector3.new(0, Kit.BoardBottom + Structures.boardLift(upgrade.id), 0),
			w = { Kit.BoardWidth.studs, Kit.BoardWidth.pixels },
			h = { Kit.BoardHeight.studs, Kit.BoardHeight.pixels },
			-- version compacte au-delà de Kit.BoardFar.distance (client)
			wFar = { Kit.BoardWidth.studs, Kit.BoardFar.widthPixels },
			hFar = { Kit.BoardHeight.studs, Kit.BoardFar.heightPixels },
			far = Kit.BoardFar.distance,
			maxd = Kit.BoardMaxDistance,
		})
	end
	local card = Conveyor.StashCard
	table.insert(boards, { id = "COFFRE", ground = Spots.chest, p = stashPos, w = { card.studsW, card.pixelsW }, h = { card.studsH, card.pixelsH }, maxd = 110 })
	local views = {
		entree = { roblox.Vector3.new(0, 14, -82), roblox.Vector3.new(0, 4, -40) },
		entree_gauche = { roblox.Vector3.new(-12, 13, -80), roblox.Vector3.new(-30, 4, -40) },
		trois_quarts = { roblox.Vector3.new(30, 22, -66), roblox.Vector3.new(-20, 4, -20) },
		coffre_cote = { roblox.Vector3.new(-27, 12, -31), roblox.Vector3.new(-45, 5, -46) },
		coffre_cour = { roblox.Vector3.new(-15, 14, -30), roblox.Vector3.new(-45, 5, -48) },
		coffre_face = { roblox.Vector3.new(-47, 12, -30), roblox.Vector3.new(-47, 5, -55) },
		apparition = { roblox.Vector3.new(0, 12, -68), roblox.Vector3.new(-20, 4, -40) },
	}
	local problems = {}
	for name, view in views do
		local eye, target = view[1], view[2]
		local fw = (target - eye).Unit
		local right = fw:Cross(roblox.Vector3.new(0, 1, 0)).Unit
		local cam = { eye = eye, forward = fw, right = right, up = right:Cross(fw), focal = f, w = W, h = H }
		local rects, list = {}, {}
		for _, b in boards do
			local dist = (b.p - eye).Magnitude
			if dist <= b.maxd then
				local bw, bh = b.w, b.h
				if b.far and dist > b.far then
					bw, bh = b.wFar, b.hFar
				end
				local rect = Formulas.boardRect(cam, b.p, bw[1], bw[2], bh[1], bh[2])
				if rect then
					if b.id == "COFFRE" then
						rect.dist = 0 -- la carte du coffre n'est jamais cachée
					end
					table.insert(rects, rect)
					table.insert(list, b)
				end
			end
		end
		-- Deux panneaux « en conflit » = deux boutons qui peuvent exister EN MÊME TEMPS.
		local function conflicts(i, j)
			local a, c = list[i], list[j]
			return a.id == "COFFRE" or c.id == "COFFRE" or (a.ground ~= c.ground and not ancestor(a.id, c.id) and not ancestor(c.id, a.id))
		end
		local shown = Formulas.declutterBoards(rects, nil, conflicts)
		local count, hidden = 0, {}
		for i, rect in rects do
			if shown[i] then
				count += 1
			elseif rect.dist < 40 then
				-- un panneau PROCHE ne doit jamais être caché : les voisins proches sont placés
				-- pour ne pas se recouvrir
				local by = {}
				for j, other in rects do
					if shown[j] and conflicts(i, j) and math.min(rect.x1, other.x1) > math.max(rect.x0, other.x0) and math.min(rect.y1, other.y1) > math.max(rect.y0, other.y0) then
						table.insert(by, list[j].id)
					end
				end
				table.insert(problems, string.format("%s : %s caché à %d studs (par %s)", name, list[i].id, math.floor(rect.dist), table.concat(by, ", ")))
			else
				table.insert(hidden, list[i].id)
			end
		end
		print(string.format("   %s : %d panneaux affichés, %d cachés au loin (%s)", name, count, #hidden, table.concat(hidden, ", ")))
		if count < 3 then
			table.insert(problems, name .. " : trop peu de panneaux lisibles (" .. count .. ")")
		end
	end
	for _, line in problems do
		print("   ! " .. line)
	end
	assert(#problems == 0, "panneaux qui se recouvrent :\n  " .. table.concat(problems, "\n  "))
end)

test("Boutique Robux : configuration (passes, produits, aides)", function()
	local Robux = requireModule(Shared.Config.Robux)
	for key, pass in Robux.Passes do
		assert(type(pass.id) == "number" and pass.price > 0 and pass.name and pass.desc and pass.icon and pass.color, "passe incomplet : " .. key)
	end
	for _, key in Robux.PassOrder do
		assert(Robux.Passes[key], "passe inconnu dans PassOrder : " .. key)
	end
	assert(Robux.Passes.AutoRoll.price == 29, "Lancer AFK = 29 Robux")
	assert(Robux.Passes.AutoRollPlus.price == 500, "Roulement automatique + = 500 Robux")
	for _, key in { "Roll2", "Roll3", "Coins2", "Luck2", "VIP" } do
		assert(Robux.Passes[key], "passe manquant : " .. key)
	end
	local ids = {}
	for key, product in Robux.Products do
		assert(type(product.id) == "number" and product.price > 0 and product.name, "produit incomplet : " .. key)
		assert(product.kind == "coins" or product.kind == "crystals" or product.kind == "boost" or product.kind == "bundle", "type inconnu : " .. key)
		if product.kind == "boost" then
			for _, boost in product.boosts do
				assert(Robux.Boosts[boost], "boost inconnu : " .. boost)
			end
		end
		if product.id > 0 then
			assert(not ids[product.id], "id en double : " .. product.id)
			ids[product.id] = true
		end
	end
	for _, list in { Robux.CoinPacks, Robux.GemPacks, Robux.BoostPacks } do
		for _, key in list do
			assert(Robux.Products[key], "produit manquant : " .. key)
		end
	end
	-- Aides : attributs Pass_ / Boost_ lus sur n'importe quel objet.
	local attrs = {}
	local fake = {
		GetAttribute = function(_, name)
			return attrs[name]
		end,
	}
	assert(Robux.coinMultiplier(fake) == 1 and Robux.luckMultiplier(fake) == 1 and Robux.rollsPerPull(fake) == 1, "valeurs de base")
	attrs.Pass_Coins2 = true
	attrs.Boost_Coins = os.time() + 60
	assert(Robux.coinMultiplier(fake) == 4, "x2 Argent + boost")
	attrs.Boost_Coins = os.time() - 1
	assert(Robux.coinMultiplier(fake) == 2, "boost expiré")
	attrs.Pass_Roll2 = true
	assert(Robux.rollsPerPull(fake) == 2, "Roll2")
	attrs.Pass_Roll3 = true
	assert(Robux.rollsPerPull(fake) == 3, "Roll3")
	attrs.Boost_Luck = os.time() + 100
	assert(Robux.boostLeft(fake, "Luck") > 90 and Robux.luckMultiplier(fake) == 2, "boost de chance")
	-- Packs de pièces : minimum, puis minutes de revenus, arrondi lisible.
	assert(Robux.coinPackAmount(Robux.Products.CoinsS, 0) == 5000, "minimum du pack")
	local big = Robux.coinPackAmount(Robux.Products.CoinsM, 12345)
	assert(big >= 12345 * 30 * 60 * 0.9 and big <= 12345 * 30 * 60, "pack selon les revenus : " .. big)
	assert(Robux.passKeyById(0) == nil and Robux.productKeyById(-1) == nil, "id 0 jamais reconnu")
end)

test("Épées du Forgeron : détaillées, effet propre, fourreau", function()
	local Swords = requireModule(Shared.Config.Swords)
	local SwordBuilder = requireModule(Shared.Modules.SwordBuilder)
	local styles = {}
	for _, sword in Swords.List do
		assert(not styles[sword.look.style], "deux épées ont la même forme : " .. sword.look.style)
		styles[sword.look.style] = true
		local tool = SwordBuilder.buildTool(sword)
		local handle = tool:FindFirstChild("Handle")
		assert(handle and handle:FindFirstChild("SwingTrail") and handle:FindFirstChild("TrailTip"), sword.id .. " : traînée manquante")
		local parts = countParts(tool)
		assert(parts >= 25 and parts <= 80, sword.id .. " : " .. parts .. " pièces (attendu 25 à 80)")
		-- Lame orientée vers -Z de la poignée.
		assert(tool:GetAttribute("SwordTip") < -sword.look.length * 0.8, sword.id .. " : lame mal orientée")
		local volume = tool:FindFirstChild("AuraVolume")
		assert(volume and volume.Transparency == 1, sword.id .. " : volume d'effet manquant")
		local auras, burst = 0, nil
		for _, child in volume:GetChildren() do
			if child:IsA("ParticleEmitter") then
				if child.Name == "SwingBurst" then
					burst = child
				elseif child.Enabled then
					auras += 1
				end
			end
		end
		assert(auras >= 1 and burst and not burst.Enabled, sword.id .. " : effet permanent ou gerbe de coup manquant")
		local model = SwordBuilder.buildModel(sword)
		assert(model:GetAttribute("Top") > model:GetAttribute("Bottom"), sword.id .. " : cadrage d'aperçu")
		local sheath = SwordBuilder.buildSheath(sword)
		local hilt, other = 0, 0
		for _, part in sheath:GetDescendants() do
			if part:IsA("BasePart") then
				if part:GetAttribute("Hilt") then
					hilt += 1
				else
					other += 1
				end
			end
		end
		assert(hilt >= 5, sword.id .. " : poignée rangée manquante")
		assert(sheath:GetAttribute("Carry") == "back" or other >= 3, sword.id .. " : fourreau manquant")
		print(string.format("   %-22s %2d pièces · fourreau %d", sword.name, parts, hilt + other))
	end
	-- Effet plus intense pour les meilleures épées.
	assert(Swords.power(Swords.List[1]) == 0 and Swords.power(Swords.List[#Swords.List]) == 1, "intensité des effets")
end)

local Vector3 = Harness.roblox.Vector3
local CFrame = Harness.roblox.CFrame
local Instance = Harness.roblox.Instance
local Enum = Harness.roblox.Enum

test("Épées : tenues de chant, Neon discret, lueur plafonnée", function()
	local Swords = requireModule(Shared.Config.Swords)
	local SwordBuilder = requireModule(Shared.Modules.SwordBuilder)
	for _, sword in Swords.List do
		local tool = SwordBuilder.buildTool(sword)
		-- La lame reste le long de -Z de la poignée ; la prise la tient de chant (dos +X vers le haut
		-- du repère de la main), levée devant et vers la droite, roulée pour montrer un peu le plat.
		local inv = tool.Grip:Inverse()
		local blade = inv:VectorToWorldSpace(Vector3.new(0, 0, -1))
		local spine = inv:VectorToWorldSpace(Vector3.new(1, 0, 0))
		assert(blade.Z < -0.6 and blade.Y > math.sin(math.rad(15)) and blade.X > 0.2, sword.id .. " : prise : lame pas levée devant")
		assert(spine.Y > math.cos(math.rad(55)) and spine.Y < math.cos(math.rad(10)), sword.id .. " : lame tenue à plat ou pas roulée")
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") and part.Material == Enum.Material.Neon and not part:FindFirstChildOfClass("SpecialMesh") then
				local s = part.Size
				local thin = math.min(s.X, s.Y, s.Z)
				local mid = s.X + s.Y + s.Z - thin - math.max(s.X, s.Y, s.Z)
				assert(mid <= 0.2 or thin <= 0.036, sword.id .. " : Neon trop large (" .. part.Name .. ")")
			end
		end
		local light = tool.AuraVolume:FindFirstChild("Glow")
		if light then
			assert(light.Brightness <= 1.5 and light.Range <= 8, sword.id .. " : lueur trop forte")
		end
		assert(sword.look.effectName and #sword.look.effectName <= 14, sword.id .. " : nom d'effet manquant ou trop long")
	end
	assert(SwordBuilder.buildTool(Swords.get("celeste")).AuraVolume.Glow.Brightness <= 1.21, "Céleste : lueur trop forte")
end)

test("Épées : portées à la hanche ou dans le dos, hors du corps et du sol (R6)", function()
	local Swords = requireModule(Shared.Config.Swords)
	local SwordBuilder = requireModule(Shared.Modules.SwordBuilder)
	-- Gabarit R6 dans le repère du torse (centre du torse à 3 studs du sol). Le bras et la jambe
	-- gauches sont testés au repos (aucun contact toléré) et balancés comme à la marche (±0,5 rad
	-- autour de l'épaule / de la hanche : léger frôlement toléré, 0,2 stud au plus).
	local limbs = {}
	local function limb(name, center, pivot, half)
		for _, a in { -0.5, -0.25, 0, 0.25, 0.5 } do
			local cf = CFrame.new(pivot) * CFrame.Angles(a, 0, 0) * CFrame.new(center - pivot)
			table.insert(limbs, { name = name, rest = a == 0, inv = cf:Inverse(), half = half })
		end
	end
	for _, side in { -1, 1 } do
		local name = side < 0 and "gauche" or "droit"
		limb("bras " .. name, Vector3.new(side * 1.5, 0, 0), Vector3.new(side * 1.5, 0.5, 0), Vector3.new(0.5, 1, 0.5))
		limb("jambe " .. name, Vector3.new(side * 0.5, -2, 0), Vector3.new(side * 0.5, -1, 0), Vector3.new(0.5, 1, 0.5))
	end
	table.insert(limbs, { name = "Torso", rest = true, inv = CFrame.new(), half = Vector3.new(1, 1, 0.5) })
	table.insert(limbs, { name = "tête", rest = true, inv = CFrame.new(0, -1.5, 0), half = Vector3.new(0.62, 0.5, 0.62) })
	local carries = {}
	local problems = {}
	for _, sword in Swords.List do
		local character = Instance.new("Model")
		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(2, 2, 1)
		torso.CFrame = CFrame.new(10, 3, 5) * CFrame.Angles(0, math.rad(30), 0)
		torso.Parent = character
		local sheath = SwordBuilder.buildSheath(sword)
		assert(SwordBuilder.attachSheath(sheath, character, sword, false), sword.id .. " : fourreau non accroché")
		local carry = sheath:GetAttribute("Carry")
		carries[carry] = (carries[carry] or 0) + 1
		local lowest = math.huge
		local extent = Vector3.new(-math.huge, -math.huge, -math.huge)
		local extentLo = Vector3.new(math.huge, math.huge, math.huge)
		local worst = {}
		for _, part in sheath:GetDescendants() do
			if part:IsA("BasePart") then
				local rel = torso.CFrame:ToObjectSpace(part.CFrame)
				local h = part.Size / 2
				-- Surface de la pièce échantillonnée tous les 0,1 stud (boîte orientée de la pièce).
				local function steps(size)
					return math.clamp(math.ceil(size / 0.1), 1, 40)
				end
				local nx, ny, nz = steps(part.Size.X), steps(part.Size.Y), steps(part.Size.Z)
				for i = 0, nx do
					for j = 0, ny do
						for k = 0, nz do
							if i == 0 or j == 0 or k == 0 or i == nx or j == ny or k == nz then
								local q = rel * Vector3.new(h.X * (2 * i / nx - 1), h.Y * (2 * j / ny - 1), h.Z * (2 * k / nz - 1))
								lowest = math.min(lowest, q.Y)
								extent, extentLo = extent:Max(q), extentLo:Min(q)
								for _, l in limbs do
									local p = l.inv * q
									local pen = math.min(l.half.X - math.abs(p.X), l.half.Y - math.abs(p.Y), l.half.Z - math.abs(p.Z))
									if pen > 0 then
										local key = l.name .. (l.rest and " (repos)" or " (marche)")
										if pen > (worst[key] or 0) then
											worst[key] = pen
										end
									end
								end
							end
						end
					end
				end
			end
		end
		assert(lowest > -2.85, sword.id .. " : le fourreau touche le sol (" .. lowest .. ")")
		for key, pen in worst do
			local limit = string.find(key, "repos", 1, true) and 0.03 or 0.2
			if pen > limit then
				table.insert(problems, string.format("%s : traverse %s de %.2f", sword.id, key, pen))
			end
		end
		-- Pas de « lance » : l'épée rangée ne dépasse pas loin devant / derrière ni sur les côtés.
		assert(extent.Z < 2.6 and extentLo.Z > -2.4, sword.id .. string.format(" : dépasse trop devant/derrière (%.2f / %.2f)", extentLo.Z, extent.Z))
		assert(extent.X < 3 and extentLo.X > -3, sword.id .. string.format(" : dépasse trop sur les côtés (%.2f / %.2f)", extentLo.X, extent.X))
		if carry == "hip" then
			-- Fourreau nettement incliné vers le bas (pas presque à plat).
			local tipZ = sheath:GetAttribute("TipZ")
			local tipWorld = sheath.PrimaryPart.CFrame * Vector3.new(0, 0, tipZ)
			local mouthWorld = sheath.PrimaryPart.CFrame * Vector3.new(0, 0, sheath:GetAttribute("MouthZ"))
			local dir = torso.CFrame:VectorToObjectSpace(tipWorld - mouthWorld).Unit
			assert(math.deg(math.asin(-dir.Y)) >= 28, sword.id .. string.format(" : fourreau trop à plat (%.0f°)", math.deg(math.asin(-dir.Y))))
		end
		print(
			string.format("   %-22s %-4s · pointe à %.2f du sol · étendue x %.1f..%.1f z %.1f..%.1f", sword.name, carry, lowest + 3, extentLo.X, extent.X, extentLo.Z, extent.Z)
		)
	end
	assert((carries.hip or 0) >= 2 and (carries.back or 0) >= 2, "ports de l'épée (hanche / dos)")
	assert(SwordBuilder.carryOf(Swords.get("celeste")) == "back" and SwordBuilder.carryOf(Swords.get("rouillee")) == "hip", "port selon la longueur")
	for _, c in problems do
		print("   !! " .. c)
	end
	assert(#problems == 0, #problems .. " collisions")
end)

Harness.finish()
