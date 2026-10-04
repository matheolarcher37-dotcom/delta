-- Menu principal (grande grille de tuiles brillantes avec toutes les fonctions du jeu + voyages)
-- et fenêtre ÉVÉNEMENT (événement en cours, boss, univers actuel et suivant).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.Parent.State)

local MainMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

-- Toutes les fonctions qui existent dans le jeu.
MainMenu.Entries = {
	{ menu = "SkillTree", text = "Améliorations", icon = "upgrade", color = Color3.fromRGB(240, 170, 30), color2 = Color3.fromRGB(150, 80, 10) },
	{ menu = "Shop", text = "Boutique", icon = "shop", color = Color3.fromRGB(200, 50, 230), color2 = Color3.fromRGB(100, 20, 150) },
	{ menu = "Inventory", text = "Unités", icon = "unit", color = Color3.fromRGB(40, 190, 80), color2 = Color3.fromRGB(16, 100, 50) },
	{ menu = "Inventory", arg = "items", text = "Objets", icon = "bag", color = Color3.fromRGB(40, 150, 240), color2 = Color3.fromRGB(20, 70, 160) },
	{ menu = "Index", text = "Indice", icon = "book", color = Color3.fromRGB(230, 40, 90), color2 = Color3.fromRGB(130, 10, 50) },
	{ menu = "Evolution", text = "Évolution", icon = "evolve", color = Color3.fromRGB(150, 70, 255), color2 = Color3.fromRGB(70, 20, 160) },
	{ menu = "Fusion", text = "Fusion", icon = "fusion", color = Color3.fromRGB(255, 80, 170), color2 = Color3.fromRGB(120, 30, 160) },
	{ menu = "Traits", text = "Traits", icon = "gem", color = Color3.fromRGB(40, 200, 230), color2 = Color3.fromRGB(20, 80, 160) },
	{ menu = "Forge", text = "Forgeron", icon = "forge", color = Color3.fromRGB(240, 110, 40), color2 = Color3.fromRGB(120, 40, 20) },
	{ menu = "Guide", text = "Guide", icon = "guide", color = Color3.fromRGB(110, 120, 150), color2 = Color3.fromRGB(40, 44, 70) },
	{ travel = "trade", text = "Échanges", icon = "swap", color = Color3.fromRGB(60, 140, 240), color2 = Color3.fromRGB(30, 50, 140) },
}

local menuWindow
local eventWindow
local eventRefs: { [string]: any } = {}

------------------------------------------------------------------------
-- Grande grille
------------------------------------------------------------------------

local function buildMenu(gui: ScreenGui)
	menuWindow = Components.window(gui, "MENU", C.Gold, UDim2.fromOffset(1060, 620), { icon = "grid", subtitle = "Toutes les fonctions du jeu" })
	local content = menuWindow.content
	-- Bandeau large « Événement » (comme la grille de référence) avec l'événement en cours.
	local event = Components.tile({
		Text = "Événement",
		Icon = "calendar",
		Color = Color3.fromRGB(150, 40, 70),
		Color2 = Color3.fromRGB(20, 110, 130),
		Size = UDim2.new(1, -24, 0, 76),
		Position = UDim2.fromOffset(12, 0),
		Wide = true,
		Seed = 5,
		Parent = content,
		OnClick = function()
			Menus.open("Event")
		end,
	})
	local eventLabel = event:FindFirstChild("Label", true) :: TextLabel?
	local grid = new("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 318),
		Position = UDim2.fromOffset(0, 88),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local layout = Theme.grid(Vector2.new(152, 152), 14, Enum.HorizontalAlignment.Center)
	layout.Parent = grid
	local tiles = {}
	for i, entry in MainMenu.Entries do
		local tile = Components.tile({
			Text = entry.text,
			Icon = entry.icon,
			Color = entry.color,
			Color2 = entry.color2,
			LayoutOrder = i,
			Seed = i * 7,
			Parent = grid,
			OnClick = function()
				if entry.travel then
					Menus.close()
					HUD.travel(entry.travel)
				else
					Menus.open(entry.menu, entry.arg)
				end
			end,
		})
		tiles[i] = tile
	end
	pcall(function()
		event.NextSelectionDown = tiles[1]
		for i = 1, math.min(6, #tiles) do
			tiles[i].NextSelectionUp = event
		end
	end)
	-- Voyages rapides
	Components.sectionTitle(content, "VOYAGER", { Position = UDim2.fromOffset(12, 414) })
	local travel = new("Frame", {
		Name = "Travel",
		Size = UDim2.new(1, 0, 0, 62),
		Position = UDim2.fromOffset(0, 444),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local travelLayout = Theme.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	travelLayout.Parent = travel
	for i, info in HUD.Travel do
		Components.button({
			Text = info.text,
			Icon = info.icon,
			Color = info.color,
			Size = UDim2.fromOffset(186, 56),
			LayoutOrder = i,
			Parent = travel,
			OnClick = function()
				Menus.close()
				HUD.travel(info.id)
			end,
		})
	end
	Components.registerWindow(Menus, "MainMenu", menuWindow, nil, function()
		return tiles[1] or event
	end)
	-- Texte du bandeau : événement en cours (ou prochain boss).
	task.spawn(function()
		while true do
			if menuWindow.isOpen and eventLabel then
				local state = State.gameState()
				local now = State.now()
				local name = state:GetAttribute("EventName")
				local bossAt = state:GetAttribute("BossAt")
				if name then
					eventLabel.Text = "Événement : " .. name .. "  ·  " .. Formulas.formatTime((state:GetAttribute("EventEndsAt") or now) - now)
				elseif state:GetAttribute("BossAlive") then
					eventLabel.Text = "Événement : le BOSS est là !"
				elseif bossAt then
					eventLabel.Text = "Événement  ·  Boss dans " .. Formulas.formatTime(bossAt - now)
				else
					eventLabel.Text = "Événement"
				end
				Components.setBadge(event, (name or state:GetAttribute("BossAlive")) and "!" or nil)
			end
			task.wait(0.5)
		end
	end)
end

------------------------------------------------------------------------
-- Fenêtre Événement
------------------------------------------------------------------------

local function eventCard(parent: Instance, event, order: number)
	local card = new("Frame", {
		Name = "Event_" .. event.id,
		Size = UDim2.new(0.25, -9, 1, 0),
		BackgroundColor3 = WHITE,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(14).Parent = card
	local stroke = Theme.stroke(C.Stroke, 3)
	stroke.Parent = card
	Theme.gradient({ Theme.dark(event.color, 0.25), Theme.dark(event.color, 0.65), Color3.fromRGB(14, 14, 20) }, 90).Parent = card
	Theme.sparkles(card, 5, order * 17, 0.7)
	local icon =
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(54, 54), BackgroundTransparency = 1, Parent = card })
	local iconName = ({ orage = "bolt", eclipse = "eye", pluie_or = "coin", lune_sang = "skull" })[event.id] or "star"
	Icons.make(iconName, icon, { px = 54, ink = Theme.dark(event.color, 0.5) })
	Theme.label({
		Text = event.name,
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 72),
		FontFace = Theme.Faces.Title,
		Parent = card,
	})
	Theme.label({
		Text = event.description,
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromOffset(10, 102),
		FontFace = Theme.Faces.Medium,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		MaxSize = 16,
		StrokeThickness = 1,
		Parent = card,
	})
	local active = Theme.label({
		Name = "Active",
		Text = "EN COURS",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.8, 0, 0, 22),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Green,
		Visible = false,
		Parent = card,
	})
	return { card = card, stroke = stroke, active = active }
end

local function buildEvent(gui: ScreenGui)
	eventWindow = Components.window(gui, "ÉVÉNEMENT", Color3.fromRGB(190, 50, 90), UDim2.fromOffset(1000, 580), { icon = "calendar" })
	local content = eventWindow.content
	-- Grand bandeau : événement actuel
	local hero = Components.panel(content, { Name = "Hero", Size = UDim2.new(1, 0, 0, 130) })
	eventRefs.heroGradient = hero:FindFirstChildOfClass("UIGradient")
	Theme.sparkles(hero, 10, 4, 0.7)
	local heroIcon = new("Frame", { Position = UDim2.fromOffset(18, 20), Size = UDim2.fromOffset(90, 90), BackgroundTransparency = 1, Parent = hero })
	eventRefs.heroIcon = heroIcon
	eventRefs.heroTitle = Theme.label({
		Size = UDim2.new(1, -330, 0, 44),
		Position = UDim2.fromOffset(124, 18),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = hero,
	})
	eventRefs.heroDesc = Theme.label({
		Size = UDim2.new(1, -330, 0, 50),
		Position = UDim2.fromOffset(124, 64),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 20,
		Parent = hero,
	})
	local timer = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(180, 80),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Parent = hero,
	})
	Theme.corner(14).Parent = timer
	Theme.label({ Text = "TEMPS RESTANT", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 8), FontFace = Theme.Faces.Heavy, TextColor3 = C.TextDim, Parent = timer })
	eventRefs.heroTimer = Theme.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 30), FontFace = Theme.Faces.Heavy, TextColor3 = C.Gold, Parent = timer })

	-- Les 4 événements possibles
	Components.sectionTitle(content, "LES ÉVÉNEMENTS", { Position = UDim2.fromOffset(4, 142) })
	local row = new("Frame", { Name = "Events", Size = UDim2.new(1, 0, 0, 196), Position = UDim2.fromOffset(0, 172), BackgroundTransparency = 1, Parent = content })
	Theme.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Left).Parent = row
	eventRefs.cards = {}
	for i, id in Economy.EventOrder do
		local event = Economy.Events[id]
		if event then
			eventRefs.cards[id] = eventCard(row, event, i)
		end
	end

	-- Univers et boss
	local bottom = new("Frame", { Name = "Bottom", Size = UDim2.new(1, 0, 0, 92), Position = UDim2.fromOffset(0, 380), BackgroundTransparency = 1, Parent = content })
	local function infoBox(x: number, title: string, icon: string, color: Color3)
		local box = Components.panel(bottom, { Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0) }, color)
		local ic = new("Frame", { Position = UDim2.fromOffset(14, 18), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Parent = box })
		Icons.make(icon, ic, { px = 56, color = Theme.light(color, 0.3), ink = C.PanelDark })
		Theme.label({
			Text = title,
			Size = UDim2.new(1, -96, 0, 22),
			Position = UDim2.fromOffset(84, 12),
			FontFace = Theme.Faces.Title,
			TextColor3 = Theme.light(color, 0.3),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		local value = Theme.label({
			Size = UDim2.new(1, -96, 0, 42),
			Position = UDim2.fromOffset(84, 38),
			FontFace = Theme.Faces.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			MaxSize = 20,
			Parent = box,
		})
		return value
	end
	eventRefs.universe = infoBox(0, "UNIVERS", "pin", C.Purple)
	eventRefs.boss = infoBox(0.5, "BOSS", "skull", C.Red)

	Components.registerWindow(Menus, "Event", eventWindow)

	task.spawn(function()
		local lastEvent = "?"
		while true do
			if eventWindow.isOpen then
				local state = State.gameState()
				local now = State.now()
				local name = state:GetAttribute("EventName")
				local current = nil
				for _, id in Economy.EventOrder do
					if Economy.Events[id] and Economy.Events[id].name == name then
						current = Economy.Events[id]
					end
				end
				local color = current and current.color or C.Gray
				if (current and current.id or "") ~= lastEvent then
					lastEvent = current and current.id or ""
					Components.clear(eventRefs.heroIcon)
					local iconName = current and (({ orage = "bolt", eclipse = "eye", pluie_or = "coin", lune_sang = "skull" })[current.id] or "star") or "calendar"
					Icons.make(iconName, eventRefs.heroIcon, { px = 90, ink = Theme.dark(color, 0.5) })
				end
				eventRefs.heroGradient.Color = Theme.sequence({ Theme.dark(color, 0.2), Theme.dark(color, 0.7) })
				eventRefs.heroTitle.Text = current and string.upper(current.name) or "AUCUN ÉVÉNEMENT"
				eventRefs.heroDesc.Text = current and current.description or "Un nouvel événement arrive bientôt : orage, pluie d'or, éclipse ou lune de sang !"
				eventRefs.heroTimer.Text = current and Formulas.formatTime((state:GetAttribute("EventEndsAt") or now) - now) or "--:--"
				for id, card in eventRefs.cards do
					local active = current ~= nil and current.id == id
					card.active.Visible = active
					card.stroke.Color = active and C.Gold or C.Stroke
					card.stroke.Thickness = active and 4 or 3
				end
				local universe = State.universe()
				local nextUniverse = Universes.get(state:GetAttribute("NextUniverseId") or "")
				eventRefs.universe.Text = universe.name
					.. "  ·  "
					.. Formulas.formatTime((state:GetAttribute("UniverseEndsAt") or now) - now)
					.. "\nEnsuite : "
					.. (nextUniverse and nextUniverse.name or "?")
				local bossAt = state:GetAttribute("BossAt")
				if state:GetAttribute("BossAlive") then
					eventRefs.boss.Text = "Le boss est au centre de la Zone ! Fonce !"
				elseif bossAt then
					eventRefs.boss.Text = "Prochain boss dans " .. Formulas.formatTime(bossAt - now)
				else
					eventRefs.boss.Text = "Le boss arrive bientôt."
				end
			end
			task.wait(0.5)
		end
	end)
end

function MainMenu.init(gui: ScreenGui)
	buildMenu(gui)
	buildEvent(gui)
end

return MainMenu
