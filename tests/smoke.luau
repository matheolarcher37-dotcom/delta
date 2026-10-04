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
	assert(max.rollsPerPull == 3, "multi-tirage maximum : " .. max.rollsPerPull)
	assert(max.autoRoll == true and max.luck > 3 and max.rollCooldown >= SkillTree.Limits.rollCooldown, "statistiques maximales")
	local none = SkillTree.stats({})
	assert(none.rollsPerPull == 1 and none.luck == 1 and none.autoRoll == false, "statistiques de départ")
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
	local last = 0
	for _, id in Economy.RollOrder do
		local price = Formulas.rollPrice(id)
		assert(price > last, "prix non croissants : " .. id)
		last = price
	end
	assert(Formulas.rollPrice("rare", "dore") > Formulas.rollPrice("rare"), "l'aura n'augmente pas le prix")
	-- Ce que la rareté garantit n'est pas facturé une 2e fois : un Secret (aura Arc-en-ciel et
	-- trait de palier 3 garantis) coûte bien le prix annoncé.
	assert(Formulas.rollPrice("secret", "arcenciel", "critique") == Economy.RollRarities.secret.price, "prix du Secret ≠ prix annoncé")
	assert(Formulas.rollPrice("mythic", "arcenciel") < Formulas.rollPrice("secret", "arcenciel", "critique"), "Mythique Arc-en-ciel plus cher qu'un Secret")
	-- Première collecte offerte : seulement jusqu'au Rare.
	assert(Formulas.rollCollectFree({ FirstCollectDone = false }, "rare"), "Rare non offert")
	assert(not Formulas.rollCollectFree({ FirstCollectDone = false }, "legendary"), "Légendaire offert")
	assert(not Formulas.rollCollectFree({ FirstCollectDone = true }, "common"), "2e collecte offerte")
	assert(Formulas.pityThreshold("legendary", 0.7) < Formulas.pityThreshold("legendary", 1), "pitié de l'arbre sans effet")
	assert(#Economy.Upgrades >= 25 and #Economy.Upgrades <= 30, "25 à 30 améliorations attendues")
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

Harness.finish()
