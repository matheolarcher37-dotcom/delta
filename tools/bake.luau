--!nocheck
-- Pré-construit le jeu DANS le fichier .rbxl pour que tout soit visible et modifiable dans
-- Roblox Studio sans lancer la partie :
--   * Workspace > World : la carte (hub, stands, anneau, arène, chemins, île, bases...)
--   * Workspace > World > Zone > Decor : le décor du 1er univers ; les 4 autres sont dans
--     ServerStorage > DecorsUnivers (glisse-les dans Workspace pour les voir / modifier)
--   * Workspace > World > Plots > Plot1 : une base d'exemple avec toutes les améliorations
--     (déco du 1er univers) ; la déco de base des 5 univers est dans ServerStorage > DecorsBase
--   * Workspace > GaleriePersos : tous les persos et ennemis (modifiables, repris par le jeu)
--   * ServerStorage > ModelesDeco : dossier (vide) pour les modèles de la Boîte à outils qui
--     remplacent les arbres, rochers, maisons... de la carte (même nom que l'élément, ex. "ArbreGeant")
--
-- Usage :
--   rojo build default.project.json -o build/_rojo.rbxl
--   ANIME_PLACE=build/_rojo.rbxl lune run tools/bake.luau build/AnimeTycoon.rbxl

local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("../tests/harness")

local roblox = Harness.roblox
local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local Enum = roblox.Enum
local game = Harness.game
local OUT = process.args[1] or "build/AnimeTycoon.rbxl"

Harness.services.PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end }

local Shared = Harness.find("ReplicatedStorage.Shared")
local Server = Harness.find("ServerScriptService.Server")
local Layout = Harness.require(Shared.Config.Layout)
local Characters = Harness.require(Shared.Config.Characters)
local Universes = Harness.require(Shared.Config.Universes)
local Economy = Harness.require(Shared.Config.Economy)
local Formulas = Harness.require(Shared.Modules.Formulas)
local CharacterBuilder = Harness.require(Shared.Modules.CharacterBuilder)
local Build = Harness.require(Server.Modules.Build)
local WorldBuilder = Harness.require(Server.World.WorldBuilder)
local UniverseDecor = Harness.require(Server.World.UniverseDecor)

local function count(root)
	return Harness.countParts(root)
end

------------------------------------------------------------------------
-- 1) Carte
------------------------------------------------------------------------

local existing = game.Workspace:FindFirstChild("World")
if existing then
	existing:Destroy()
end
local built = WorldBuilder.build({ water = false })
local world = built.world
world:SetAttribute("Baked", true)
print("carte :", count(world), "pièces")

------------------------------------------------------------------------
-- 2) Décors des univers
------------------------------------------------------------------------

local first = Universes.List[1]
local firstDecor = UniverseDecor.apply(first, built.zone)
print("décor", first.id, count(firstDecor), "pièces")
local ServerStorage = game:GetService("ServerStorage")
local store = ServerStorage:FindFirstChild("DecorsUnivers")
if store then
	store:Destroy()
end
store = Instance.new("Folder")
store.Name = "DecorsUnivers"
store.Parent = ServerStorage
-- Dossier des modèles de remplacement (Boîte à outils de Studio), voir World/DecorKit.
if not ServerStorage:FindFirstChild("ModelesDeco") then
	local modeles = Instance.new("Folder")
	modeles.Name = "ModelesDeco"
	modeles.Parent = ServerStorage
end
for i = 2, #Universes.List do
	local universe = Universes.List[i]
	local decor = UniverseDecor.build(universe)
	decor.Name = universe.id
	decor.Parent = store
	print("décor", universe.id, count(decor), "pièces")
end

------------------------------------------------------------------------
-- 3) Bases (et base d'exemple complète)
------------------------------------------------------------------------

local PlotService = Harness.require(Server.Services.PlotService)
local BaseDecor = Harness.require(Server.World.BaseDecor)
local Kit = Harness.require(Server.Modules.TycoonKit)
local TycoonMachine = Harness.require(Server.Modules.TycoonMachine)
-- Déco de base des 5 univers : ServerStorage > DecorsBase (modifiable dans Studio).
local oldDecors = game:GetService("ServerStorage"):FindFirstChild("DecorsBase")
if oldDecors then
	oldDecors:Destroy()
end
BaseDecor.buildAllTemplates(Universes.List)
local allUpgrades = {}
for _, upgrade in Economy.Upgrades do
	allUpgrades[upgrade.id] = true
end
local exampleData = { upgrades = allUpgrades, coins = 0, stash = 0, Skills = {}, DisplayPins = {}, RolledQueue = {} }
PlotService:Init({
	DataService = {
		Get = function()
			return exampleData
		end,
	},
	CharacterService = {
		GetBestLook = function()
			return Characters.get("ninja_maruto").look
		end,
	},
})
local example = { UserId = 1, DisplayName = "Exemple", SetAttribute = function() end, CharacterAdded = Harness.newSignal() }
PlotService:_assign(example, {})
local plot = PlotService:GetPlot(example)
local displayIds = { "ninja_maruto", "occ_goju", "sai_goko", "oce_loffy", "pou_tanjiru", "occ_sukana", "ninja_sasuki", "pou_rengoko", "sai_vejeta", "oce_zoru" }
local displayed = {}
for slot, id in displayIds do
	local entry = { id = id, level = 10 + slot * 8, stars = (slot % 3) + 1 }
	local model = CharacterBuilder.build(Formulas.describe(entry).look, { scale = Formulas.visualScale(entry), anchored = true, name = id })
	model:PivotTo(PlotService:GetDisplayCFrame(plot, slot) * CFrame.new(0, model:GetAttribute("RootHeight"), 0))
	PlotService:DecorateUnit(plot, model, entry)
	model.Parent = plot.displayFolder
	displayed[slot] = id
end
PlotService:RefreshSlots(example, displayed)
-- Quelques persos d'exemple sur l'estrade de la machine ROULER.
local rolledIds = { { "ninja_sakoura", "uncommon" }, { "ninja_konohamaro", "common" }, { "ninja_itochi", "mythic" } }
for i, pair in rolledIds do
	local info = Economy.RollRarities[pair[2]]
	local entry = { id = pair[1], level = 1, stars = 1 }
	local model = CharacterBuilder.build(Formulas.describe(entry).look, { anchored = true, name = "Tire_" .. pair[1] })
	local spot = plot.machine.spots[i]
	model:PivotTo(spot.cf * CFrame.new(0, model:GetAttribute("RootHeight"), 0))
	Kit.unitTag(model.PrimaryPart, {
		{ text = info.name, colors = info.gradient, weight = 0.9 },
		{ text = "DPS " .. math.floor(Formulas.dps(entry)), color = Color3.fromRGB(230, 230, 230), font = Enum.Font.GothamBold, weight = 0.5 },
		{ text = Characters.get(pair[1]).name, color = Color3.new(1, 1, 1), weight = 1 },
		{ text = "¥" .. Formulas.formatNumber(Formulas.rollPrice(pair[2])), color = Color3.fromRGB(255, 215, 60), weight = 0.9 },
	}, 3, 6, 70, 5.4)
	model.Parent = plot.rolledFolder
	TycoonMachine.lightSpot(plot.machine, i, info.color, info.order >= 5)
end
TycoonMachine.setX10(plot.machine, 4, 10)
plot.machine.universeLabel.Text = "Univers : " .. Universes.List[1].name
TycoonMachine.setPity(plot.machine, { legendary = 45, mythic = 415, secret = 5300 })
BaseDecor.setSign(plot, "BASE D'EXEMPLE")
plot.model:SetAttribute("OwnerId", nil)
print("bases :", count(world.Plots), "pièces")

------------------------------------------------------------------------
-- 4) Galerie des persos (modèles repris par le jeu au lancement)
------------------------------------------------------------------------

local old = game.Workspace:FindFirstChild("GaleriePersos")
if old then
	old:Destroy()
end
local gallery = Instance.new("Folder")
gallery.Name = "GaleriePersos"
gallery.Parent = game.Workspace
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = gallery
local models = Instance.new("Folder")
models.Name = "ModelesPersos"
models.Parent = gallery

local center = Layout.GalleryCenter
local WOOD = Color3.fromRGB(170, 120, 75)
Build.part(decor, "Deck", Vector3.new(210, 1, 150), CFrame.new(center + Vector3.new(0, -0.5, 0)), WOOD, { Material = Enum.Material.WoodPlanks })
local sign = Build.part(decor, "Sign", Vector3.new(70, 9, 1), CFrame.new(center + Vector3.new(0, 8, -78)), Color3.fromRGB(60, 40, 30), { Material = Enum.Material.Wood })
Build.surfaceText(sign, Enum.NormalId.Front, "GALERIE DES PERSOS · modifie-les ici !", Color3.fromRGB(255, 220, 90))
local info = Build.part(decor, "Info", Vector3.new(70, 4, 1), CFrame.new(center + Vector3.new(0, 1.8, -78)), Color3.fromRGB(40, 30, 25), { Material = Enum.Material.Wood })
Build.surfaceText(info, Enum.NormalId.Front, "Visible seulement dans Studio : le jeu reprend ces modèles au lancement", Color3.fromRGB(255, 255, 255))

local function pedestal(position: Vector3, title: string, color: Color3)
	Build.part(decor, "Pedestal", Vector3.new(4, 0.6, 4), CFrame.new(position + Vector3.new(0, 0.3, 0)), color, { Material = Enum.Material.SmoothPlastic })
	local plate = Build.part(decor, "NamePlate", Vector3.new(4, 0.9, 0.2), CFrame.new(position + Vector3.new(0, 0.45, -2.1)), Color3.fromRGB(30, 25, 35))
	Build.surfaceText(plate, Enum.NormalId.Front, title, Color3.fromRGB(255, 255, 255), { Font = Enum.Font.GothamBold })
end

local function addModel(key: string, look, position: Vector3, title: string, color: Color3)
	local model = CharacterBuilder.build(look, { name = key, anchored = true })
	model:PivotTo(CFrame.new(position + Vector3.new(0, 0.6 + CharacterBuilder.RootHeight, 0)))
	model.Parent = models
	pedestal(position, title, color)
	return model
end

local total = 0
for u, universe in Universes.List do
	local z = center.Z - 58 + (u - 1) * 21
	local x = -96
	local zoneSign = Build.part(decor, "RowSign", Vector3.new(14, 3, 0.6), CFrame.new(center.X - 112, 3, z), universe.color)
	Build.surfaceText(zoneSign, Enum.NormalId.Front, universe.name, Color3.fromRGB(255, 255, 255))
	for _, id in universe.characters do
		local def = Characters.get(id)
		local variants = { 1 }
		if def.evolve then
			for stars = 2, 3 do
				if def.evolve[stars] then
					table.insert(variants, stars)
				end
			end
		end
		for _, stars in variants do
			local key = stars == 1 and id or (id .. "_" .. stars)
			local title = def.name .. (stars > 1 and (" " .. string.rep("★", stars)) or "")
			addModel(key, Characters.resolveLook(id, stars), Vector3.new(center.X + x, 0, z), title, universe.color)
			x += 6.5
			total += 1
		end
	end
end
-- Ennemis et boss
local ex = -96
for _, universe in Universes.List do
	for _, id in universe.enemies do
		addModel(id, Characters.Enemies[id].look, Vector3.new(center.X + ex, 0, center.Z + 52), Characters.Enemies[id].name, Color3.fromRGB(200, 60, 60))
		ex += 6.5
		total += 1
	end
	local boss = Characters.Enemies[universe.boss]
	addModel(universe.boss, boss.look, Vector3.new(center.X + ex, 0, center.Z + 52), "👹 " .. boss.name, Color3.fromRGB(120, 20, 30))
	ex += 6.5
	total += 1
end
print("galerie :", total, "modèles,", count(gallery), "pièces")

------------------------------------------------------------------------
-- 5) Nettoyage et écriture
------------------------------------------------------------------------

-- Lune écrit "Font" comme un EnumItem : on le convertit en FontFace avant d'enregistrer.
for _, item in game:GetDescendants() do
	if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
		local font = item.Font
		if typeof(font) == "EnumItem" then
			item.FontFace = roblox.Font.fromEnum(font)
		end
	end
end
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if remotes then
	remotes:Destroy() -- recréés au lancement
end
local bytes = roblox.serializePlace(game)
fs.writeFile(OUT, bytes)
print(string.format("écrit %s (%.1f Mo)", OUT, #bytes / 1e6))
process.exit(0)
