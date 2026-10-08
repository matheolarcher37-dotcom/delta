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
		local model = CharacterBuilder.build(look, { scale = 1 })
		local head = model:FindFirstChild("Head")
		assert(head and head.Size.X == 2 and head.Size.Y == 1 and head.Size.Z == 1, label .. " : tête classique 2x1x1 attendue")
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		assert(mesh and mesh.MeshType.Name == "Head" and math.abs(mesh.Scale.X - 1.25) < 1e-6, label .. " : maillage Head 1.25")
		local torso = model:FindFirstChild("Torso")
		assert(torso.Size.X == 2 and torso.Size.Y == 2 and torso.Size.Z == 1, label .. " : torse 2x2x1")
		for _, limb in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local part = model:FindFirstChild(limb)
			assert(part and part.Size.X == 1 and part.Size.Y == 2 and part.Size.Z == 1, label .. " : " .. limb .. " 1x2x1")
		end
		for _, joint in CharacterBuilder.JointNames do
			assert(model:FindFirstChild(joint, true), label .. " : articulation " .. joint)
		end
		local plates, frames, parts = 0, 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				if d.Name == "FacePlate" then
					plates += 1
					assert(d.Transparency == 1 and d:FindFirstChildOfClass("SurfaceGui"), label .. " : plaque du visage")
				end
			elseif d:IsA("Frame") then
				frames += 1
			end
		end
		local boar = look.accessories and table.find(look.accessories, "boar_head")
		assert(boar or plates == 6, label .. " : 6 plaques de visage attendues (" .. plates .. ")")
		assert(parts <= 150, label .. " : trop de pièces (" .. parts .. ")")
		assert(frames <= 450, label .. " : trop de Frames (" .. frames .. ")")
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
	local BUDGET = 45000
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
	assert(#plot.slots == 24 and plot.machine.prompt and plot.skillRefs.prompt, "machine / cases / arbre manquants")
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

Harness.finish()
