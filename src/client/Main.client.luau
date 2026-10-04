-- Point d'entrée client d'ANIME TYCOON : crée l'interface et démarre les contrôleurs.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local UI = script.Parent.UI
local Controllers = script.Parent.Controllers

local Theme = require(UI.Theme)
local Menus = require(UI.Menus)
local Console = require(UI.Console)
local Notifications = require(UI.Notifications)
local HUD = require(UI.HUD)
local RollPanel = require(UI.RollPanel)
local RollReveal = require(UI.RollReveal)
local MainMenu = require(UI.MainMenu)
local SkillTreeMenu = require(UI.SkillTreeMenu)
local Inventory = require(UI.Inventory)
local Shop = require(UI.Shop)
local HatchReveal = require(UI.HatchReveal)
local PlaceUnit = require(UI.PlaceUnit)
local Options = require(UI.Options)
local Evolution = require(UI.Evolution)
local Fusion = require(UI.Fusion)
local Trade = require(UI.Trade)
local Index = require(UI.Index)
local TraitsMenu = require(UI.TraitsMenu)
local ForgeMenu = require(UI.ForgeMenu)

local RigAnimator = require(Controllers.RigAnimator)
local Effects = require(Controllers.Effects)
local AuraController = require(Controllers.AuraController)
local NameTags = require(Controllers.NameTags)
local WorldInteraction = require(Controllers.WorldInteraction)

local gui = Theme.new("ScreenGui", {
	Name = "AnimeTycoonUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Échelle de l'interface : tout est dessiné pour un écran de 1280 x 720 puis agrandi ou réduit
-- (téléphone, PC, télé 4K). Sur télé (interface « à 3 mètres »), un peu plus grand encore.
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		local scale = math.min(size.X / 1280, size.Y / 720)
		if Console.isTenFoot() then
			scale *= 1.06
		end
		Theme.setScale(math.clamp(scale, 0.5, 3))
	end
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function safeInit(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[AnimeTycoon] Échec de l'initialisation de " .. name .. " : " .. tostring(err))
	end
end

safeInit("Menus", Menus.init)
safeInit("Console", function()
	Console.init(gui)
end)
updateScale()
safeInit("HUD", function()
	HUD.init(gui)
end)
safeInit("RollPanel", function()
	RollPanel.init(gui, HUD.root())
end)
safeInit("Notifications", function()
	Notifications.init(gui)
end)
safeInit("RollReveal", function()
	RollReveal.init(gui)
end)
safeInit("MainMenu", function()
	MainMenu.init(gui)
end)
safeInit("SkillTreeMenu", function()
	SkillTreeMenu.init(gui)
end)
safeInit("Inventory", function()
	Inventory.init(gui)
end)
safeInit("Shop", function()
	Shop.init(gui)
end)
safeInit("HatchReveal", function()
	HatchReveal.init(gui)
end)
safeInit("PlaceUnit", function()
	PlaceUnit.init(gui)
end)
safeInit("Options", function()
	Options.init(gui)
end)
safeInit("Evolution", function()
	Evolution.init(gui)
end)
safeInit("Fusion", function()
	Fusion.init(gui)
end)
safeInit("Trade", function()
	Trade.init(gui)
end)
safeInit("Index", function()
	Index.init(gui)
end)
safeInit("ForgeMenu", function()
	ForgeMenu.init(gui)
end)
safeInit("TraitsMenu", function()
	TraitsMenu.init(gui)
end)
safeInit("RigAnimator", RigAnimator.init)
safeInit("Effects", function()
	Effects.init(gui, HUD)
end)
safeInit("AuraController", AuraController.init)
safeInit("NameTags", NameTags.init)
safeInit("WorldInteraction", WorldInteraction.init)

updateScale()

-- Manette : croix haut = menu principal.
Console.setAction("mainMenu", function()
	Menus.open("MainMenu")
end)

-- Barre d'outils visible : c'est là que se trouve l'épée du joueur.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
end)

task.delay(2, function()
	Notifications.announce("ANIME TYCOON", "Roule, collectionne et fais évoluer les héros de 5 univers !", Color3.fromRGB(255, 190, 60))
end)
