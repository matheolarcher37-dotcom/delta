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
	for _, universe in Universes.List do
		local decor = UniverseDecor.apply(universe, zone)
		print(string.format("   %-24s %4d pièces", universe.name, countParts(decor)))
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
	assert(#plot.ownerFolder.Structures:GetChildren() > 10, "structures manquantes")
	print("   pièces d'une base complète : " .. countParts(plot.model))
end)

Harness.finish()
