-- HUD : monnaies (compteurs animés), grille de gros boutons du menu, bannière d'univers + compte
-- à rebours, pastilles d'événement/boss, équipe, objectif et boutons de voyage.
-- Tout est placé dans un calque « logique » de 1280 x 720 (Theme.scaledRoot) : la même
-- disposition s'adapte au téléphone, au PC et à la télé.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.Parent.State)

local HUD = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local player = Players.LocalPlayer

local refs: { [string]: any } = {}
local displayed = { coins = 0, crystals = 0 }

-- Tuiles de la grille du HUD (comme la capture de référence) : nom du menu, texte, icône, couleurs.
HUD.Tiles = {
	{ menu = "SkillTree", text = "Améliorations", icon = "upgrade", color = Color3.fromRGB(240, 170, 30), color2 = Color3.fromRGB(150, 80, 10) },
	{ menu = "Shop", text = "Boutique", icon = "shop", color = Color3.fromRGB(200, 50, 230), color2 = Color3.fromRGB(100, 20, 150) },
	{ menu = "Inventory", text = "Unités", icon = "unit", color = Color3.fromRGB(40, 190, 80), color2 = Color3.fromRGB(16, 100, 50) },
	{ menu = "Inventory", arg = "items", text = "Objets", icon = "bag", color = Color3.fromRGB(40, 150, 240), color2 = Color3.fromRGB(20, 70, 160) },
	{ menu = "Index", text = "Indice", icon = "book", color = Color3.fromRGB(230, 40, 90), color2 = Color3.fromRGB(130, 10, 50) },
	{ menu = "MainMenu", text = "Plus", icon = "grid", color = Color3.fromRGB(240, 210, 40), color2 = Color3.fromRGB(170, 110, 10) },
}

------------------------------------------------------------------------
-- Monnaies
------------------------------------------------------------------------

local function buildCurrency(root: Frame)
	local holder = new("Frame", {
		Name = "Currency",
		Position = UDim2.fromOffset(18, 62),
		Size = UDim2.fromOffset(300, 140),
		BackgroundTransparency = 1,
		Parent = root,
	})
	refs.currency = holder
	-- Pièces : grosse pilule dorée
	local coins = new("Frame", {
		Name = "Coins",
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.fromOffset(250, 54),
		BackgroundColor3 = WHITE,
		Parent = holder,
	})
	Theme.round().Parent = coins
	Theme.stroke(C.Stroke, 3).Parent = coins
	Theme.gradient({ Color3.fromRGB(44, 40, 30), Color3.fromRGB(22, 20, 16) }, 90).Parent = coins
	local coinsEdge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = coins })
	Theme.round().Parent = coinsEdge
	Theme.stroke(C.Gold, 1.5, 0.4).Parent = coinsEdge
	local coinIcon = Components.coinIcon(holder, 62, UDim2.fromOffset(26, 27))
	coinIcon.ZIndex = 3
	refs.coinScale = new("UIScale", { Parent = coinIcon })
	Theme.sparkle(coinIcon, UDim2.fromScale(0.82, 0.18), 14, 0.15, 4)
	refs.coins = Theme.label({
		Name = "Amount",
		Size = UDim2.new(1, -60, 0, 32),
		Position = UDim2.fromOffset(42, 3),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		ZIndex = 2,
		Parent = coins,
	})
	Theme.gradient({ Color3.fromRGB(255, 248, 170), Color3.fromRGB(255, 196, 40) }, 90).Parent = refs.coins
	refs.income = Theme.label({
		Name = "Income",
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.fromOffset(44, 34),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		ZIndex = 2,
		Parent = coins,
	})
	-- Ligne : cristaux + matériaux
	local row = new("Frame", {
		Name = "Row",
		Position = UDim2.fromOffset(4, 62),
		Size = UDim2.fromOffset(300, 74),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local grid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(96, 32),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local _ = grid
	local crystals = new("Frame", {
		Name = "Crystals",
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		LayoutOrder = 0,
		Parent = row,
	})
	Theme.round().Parent = crystals
	Theme.stroke(C.Stroke, 2).Parent = crystals
	Components.gem(crystals, C.Cyan, 16, UDim2.fromOffset(18, 16))
	refs.crystals = Theme.label({
		Size = UDim2.new(1, -40, 1, -8),
		Position = UDim2.fromOffset(34, 4),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Color3.fromRGB(150, 236, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = crystals,
	})
	refs.materials = row
end

------------------------------------------------------------------------
-- Grille de gros boutons (Événement en bandeau + tuiles carrées)
------------------------------------------------------------------------

local function buildMenuGrid(root: Frame)
	local holder = new("Frame", {
		Name = "MenuGrid",
		Position = UDim2.fromOffset(18, 210),
		Size = UDim2.fromOffset(210, 420),
		BackgroundTransparency = 1,
		Parent = root,
	})
	refs.menuGrid = holder
	refs.gridScale = new("UIScale", { Parent = holder })
	local event = Components.tile({
		Text = "Événement",
		Icon = "calendar",
		Color = Color3.fromRGB(150, 40, 70),
		Color2 = Color3.fromRGB(20, 110, 130),
		Size = UDim2.fromOffset(206, 66),
		Wide = true,
		Seed = 3,
		Parent = holder,
		OnClick = function()
			Menus.toggle("Event")
		end,
	})
	refs.eventTile = event
	refs.tiles = {}
	for i, info in HUD.Tiles do
		local col = (i - 1) % 2
		local line = (i - 1) // 2
		local tile = Components.tile({
			Text = info.text,
			Icon = info.icon,
			Color = info.color,
			Color2 = info.color2,
			Size = UDim2.fromOffset(98, 98),
			Position = UDim2.fromOffset(col * 108, 76 + line * 108),
			Seed = i * 11,
			Parent = holder,
			OnClick = function()
				if Menus.current() == info.menu and info.arg == nil then
					Menus.close()
				else
					Menus.open(info.menu, info.arg)
				end
			end,
		})
		refs.tiles[info.text] = tile
	end
	-- Navigation manette entre les tuiles (haut / bas / gauche / droite).
	local order = { event }
	for _, info in HUD.Tiles do
		table.insert(order, refs.tiles[info.text])
	end
	pcall(function()
		event.NextSelectionDown = order[2]
		for i = 2, #order do
			local tile = order[i]
			local index = i - 1
			tile.NextSelectionUp = index <= 2 and event or order[i - 2]
			tile.NextSelectionDown = order[i + 2] or tile
			if index % 2 == 1 then
				tile.NextSelectionRight = order[i + 1] or tile
			else
				tile.NextSelectionLeft = order[i - 1]
			end
		end
	end)
end

------------------------------------------------------------------------
-- Bannière d'univers (haut, centre)
------------------------------------------------------------------------

local function buildBanner(root: Frame)
	local banner = new("Frame", {
		Name = "UniverseBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 82),
		BackgroundColor3 = WHITE,
		Parent = root,
	})
	refs.banner = banner
	Theme.corner(16).Parent = banner
	Theme.stroke(C.Stroke, 3).Parent = banner
	refs.bannerGradient = Theme.gradient({ C.PanelLight, C.Panel, C.PanelDark }, 0)
	refs.bannerGradient.Parent = banner
	local edge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = banner })
	Theme.corner(14).Parent = edge
	refs.bannerEdge = Theme.stroke(WHITE, 1.5, 0.5)
	refs.bannerEdge.Parent = edge
	refs.bannerSparkles = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = banner })
	Theme.sparkles(refs.bannerSparkles, 8, 21, 0.7)
	-- Portail tournant (icône de l'univers)
	local portal = new("Frame", {
		Name = "Portal",
		Position = UDim2.fromOffset(12, 11),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = banner,
	})
	Theme.round().Parent = portal
	Theme.stroke(C.Stroke, 2.5).Parent = portal
	refs.portalGradient = Theme.gradient({ WHITE, C.Purple, C.PanelDark }, 0)
	refs.portalGradient.Parent = portal
	local swirl = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = portal,
	})
	Theme.round().Parent = swirl
	local swirlStroke = Theme.stroke(WHITE, 3, 0.15)
	swirlStroke.Parent = swirl
	Theme.gradient({ WHITE, WHITE }, 0, { 0, 1 }).Parent = swirlStroke
	Theme.onFrame(portal, function(dt)
		refs.portalGradient.Rotation = (refs.portalGradient.Rotation + dt * 90) % 360
		swirl.Rotation = (swirl.Rotation - dt * 220) % 360
	end)
	refs.universeName = Theme.label({
		Name = "UniverseName",
		Size = UDim2.new(1, -184, 0, 32),
		Position = UDim2.fromOffset(84, 8),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 2,
		Parent = banner,
	})
	refs.nameGradient = Theme.gradient({ WHITE, WHITE }, 90)
	refs.nameGradient.Parent = refs.universeName
	refs.universeSub = Theme.label({
		Name = "Next",
		Size = UDim2.new(1, -184, 0, 18),
		Position = UDim2.fromOffset(85, 40),
		TextColor3 = C.TextDim,
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		ZIndex = 2,
		Parent = banner,
	})
	refs.universeBar = Components.progressBar(banner, C.Gold, {
		Size = UDim2.new(1, -100, 0, 10),
		Position = UDim2.fromOffset(84, 62),
		ZIndex = 2,
	})
	-- Compte à rebours (grosse pilule à droite)
	local timer = new("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(92, 44),
		BackgroundColor3 = Color3.fromRGB(8, 8, 14),
		BackgroundTransparency = 0.25,
		ZIndex = 2,
		Parent = banner,
	})
	Theme.corner(12).Parent = timer
	Theme.stroke(C.Stroke, 2).Parent = timer
	local hourglass = new("Frame", { Position = UDim2.fromOffset(6, 10), Size = UDim2.fromOffset(22, 24), BackgroundTransparency = 1, ZIndex = 3, Parent = timer })
	Icons.make("hourglass", hourglass, { px = 22, zindex = 3, ink = C.Gold })
	refs.hourglass = hourglass
	refs.timer = Theme.label({
		Size = UDim2.new(1, -34, 0, 28),
		Position = UDim2.fromOffset(30, 8),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		ZIndex = 3,
		Parent = timer,
	})

	-- Pastilles sous la bannière : événement, boss, boutique
	local chips = new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.fromOffset(700, 32),
		BackgroundTransparency = 1,
		Parent = banner,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	layout.Parent = chips
	local function chip(name: string, color: Color3, icon: string)
		local frame = new("Frame", {
			Name = name,
			Size = UDim2.fromOffset(220, 32),
			BackgroundColor3 = WHITE,
			Visible = false,
			Parent = chips,
		})
		Theme.round().Parent = frame
		Theme.stroke(C.Stroke, 2.5).Parent = frame
		Theme.gradient({ Theme.light(color, 0.2), Theme.dark(color, 0.3) }, 90).Parent = frame
		local ic = new("Frame", { Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = frame })
		Icons.make(icon, ic, { px = 22, ink = Theme.dark(color, 0.4) })
		local label = Theme.label({
			Size = UDim2.new(1, -44, 1, -8),
			Position = UDim2.fromOffset(36, 4),
			FontFace = Theme.Faces.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		return frame, label
	end
	refs.eventChip, refs.eventLabel = chip("Event", C.Purple, "bolt")
	refs.bossChip, refs.bossLabel = chip("Boss", C.Red, "skull")
	refs.shopChip, refs.shopLabel = chip("Shop", C.Blue, "shop")
end

------------------------------------------------------------------------
-- Équipe (bas droite)
------------------------------------------------------------------------

local function buildTeamPanel(root: Frame)
	local panel = new("Frame", {
		Name = "Team",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -14),
		Size = UDim2.fromOffset(330, 70),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = panel
	refs.team = panel
	refs.teamRows = {}
end

------------------------------------------------------------------------
-- Objectif + boutons de voyage (bas centre)
------------------------------------------------------------------------

local TRAVEL = {
	{ id = "base", text = "Base", icon = "home", color = Color3.fromRGB(60, 190, 90) },
	{ id = "zone", text = "Combat", icon = "sword", color = Color3.fromRGB(230, 60, 60) },
	{ id = "hub", text = "Hub", icon = "pin", color = Color3.fromRGB(240, 150, 30) },
	{ id = "boss", text = "Boss", icon = "skull", color = Color3.fromRGB(140, 40, 70) },
	{ id = "trade", text = "Échanges", icon = "swap", color = Color3.fromRGB(60, 140, 240) },
}
HUD.Travel = TRAVEL

function HUD.travel(id: string)
	Remotes.event("Teleport"):FireServer(id)
end

local function buildBottom(root: Frame)
	local frame = new("Frame", {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(560, 44),
		BackgroundColor3 = WHITE,
		Parent = root,
	})
	Theme.round().Parent = frame
	Theme.stroke(C.Stroke, 3).Parent = frame
	Theme.gradient({ Color3.fromRGB(40, 40, 58), Color3.fromRGB(16, 16, 24) }, 90).Parent = frame
	local target = new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Parent = frame })
	Icons.make("target", target, { px = 28, color = C.Red, ink = WHITE })
	refs.objective = Theme.label({
		Size = UDim2.new(1, -60, 1, -14),
		Position = UDim2.fromOffset(46, 7),
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 20,
		Parent = frame,
	})
	refs.objectiveFrame = frame

	local travel = new("Frame", {
		Name = "Travel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -66),
		Size = UDim2.fromOffset(380, 66),
		BackgroundTransparency = 1,
		Parent = root,
	})
	refs.travel = travel
	local layout = Theme.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = travel
	for i, info in TRAVEL do
		local button = new("TextButton", {
			Name = "Travel_" .. info.id,
			Size = UDim2.fromOffset(58, 66),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			Parent = travel,
		})
		local scale = new("UIScale", { Parent = button })
		local disc = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = WHITE,
			Parent = button,
		})
		Theme.round().Parent = disc
		Theme.stroke(C.Stroke, 2.5).Parent = disc
		Theme.gradient({ Theme.light(info.color, 0.3), info.color, Theme.dark(info.color, 0.35) }, 60).Parent = disc
		Theme.shine(disc, 25, 0.35)
		Icons.make(info.icon, disc, { px = 30, size = UDim2.fromScale(0.58, 0.58), ink = Theme.dark(info.color, 0.45), zindex = 3 })
		Theme.label({
			Text = info.text,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1.3, 0, 0, 18),
			FontFace = Theme.Faces.Title,
			ZIndex = 3,
			Parent = button,
		})
		Components.interactive(button, scale, 1.1)
		button.Activated:Connect(function()
			Components.click()
			HUD.travel(info.id)
		end)
	end
end

------------------------------------------------------------------------

local function objectiveText(data): string
	if not data then
		return "Chargement de ta sauvegarde..."
	end
	local characterCount = 0
	for _ in data.characters do
		characterCount += 1
	end
	local relicCount = 0
	for _, count in data.relics do
		relicCount += count
	end
	local incubating, ready = false, false
	for _, inc in data.incubators do
		incubating = true
		if State.now() >= inc.start + inc.duration then
			ready = true
		end
	end
	if ready then
		return "Ta relique est prête ! Ouvre-la sur l'autel de ta base"
	end
	local queue = data.RolledQueue
	if type(queue) == "table" and #queue > 0 then
		return "Des persos t'attendent sur l'estrade : récupère-les !"
	end
	if characterCount == 0 then
		if State.remoteFunction("Roll") then
			return "Fais tourner la machine ROULER de ta base pour obtenir ton premier perso !"
		elseif incubating then
			return "Ta relique s'ouvre bientôt..."
		elseif relicCount > 0 then
			return "Pose ta relique sur l'autel de ta base (appuie sur E)"
		else
			return "Achète une relique dans la Boutique de ta base"
		end
	end
	if data.stats.kills == 0 then
		return "Va combattre dans la Zone d'Univers au centre de la carte"
	end
	if data.stash >= 50 then
		return "Récupère tes pièces : marche sur le coffre doré de ta base"
	end
	local tree = State.skillTree()
	local skills = State.skills()
	for _, node in tree.Nodes do
		if not skills[node.id] and data.coins >= node.cost then
			local ok = true
			for _, req in node.requires do
				ok = ok and skills[req] == true
			end
			if ok then
				return "Améliore-toi : « " .. node.name .. " » est disponible dans Améliorations !"
			end
		end
	end
	for _, entry in data.characters do
		if (entry.stars or 1) < 3 and entry.level >= Formulas.levelCap(entry.stars) then
			return "Un perso a atteint son niveau max : fais-le évoluer (menu Évolution)"
		end
	end
	local state = State.gameState()
	local nextUniverse = Universes.get(state:GetAttribute("NextUniverseId") or "")
	local endsAt = state:GetAttribute("UniverseEndsAt") or State.now()
	return "Collectionne les persos de chaque univers ! Ensuite : " .. (nextUniverse and nextUniverse.name or "?") .. " dans " .. Formulas.formatTime(endsAt - State.now())
end

local lastMaterialKey = ""
local function refreshMaterials(data)
	local parts = {}
	for _, universe in Universes.List do
		table.insert(parts, tostring(data.materials[universe.material.id] or 0))
	end
	local key = table.concat(parts, ",")
	if key == lastMaterialKey then
		return
	end
	lastMaterialKey = key
	for _, child in refs.materials:GetChildren() do
		if child.Name:sub(1, 5) == "Pill_" then
			child:Destroy()
		end
	end
	local order = 0
	for _, universe in Universes.List do
		local count = data.materials[universe.material.id] or 0
		if count > 0 then
			order += 1
			local pill = Components.materialPill(refs.materials, universe.material.id, count, order)
			local _ = pill
		end
	end
end

local function refreshTeam(data)
	for _, row in refs.teamRows do
		row.frame:Destroy()
	end
	refs.teamRows = {}
	for i, uid in data.team do
		local entry = data.characters[uid]
		local desc = entry and Formulas.describe(entry)
		if desc then
			local info = Theme.rarity(Components.rarityOf(entry, desc))
			local tint = info.rainbow and C.Cyan or info.color
			local frame = new("Frame", {
				Name = "TeamRow",
				Size = UDim2.fromOffset(60, 66),
				BackgroundColor3 = WHITE,
				LayoutOrder = i,
				Parent = refs.team,
			})
			Theme.corner(12).Parent = frame
			Theme.stroke(C.Stroke, 2.5).Parent = frame
			Theme.gradient({ Theme.dark(tint, 0.2), Theme.dark(tint, 0.6), Color3.fromRGB(14, 14, 20) }, 90).Parent = frame
			local edge = new("Frame", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, Parent = frame })
			Theme.corner(10).Parent = edge
			Theme.stroke(tint, 1.5, 0.2).Parent = edge
			Theme.label({
				Text = "Nv." .. entry.level,
				Size = UDim2.new(1, -6, 0, 16),
				Position = UDim2.fromOffset(3, 4),
				FontFace = Theme.Faces.Heavy,
				TextColor3 = C.Yellow,
				Parent = frame,
			})
			Theme.label({
				Text = desc.name,
				Size = UDim2.new(1, -6, 0, 26),
				Position = UDim2.fromOffset(3, 21),
				FontFace = Theme.Faces.Title,
				TextWrapped = true,
				Parent = frame,
			})
			local bar = Components.progressBar(frame, C.Green, {
				Size = UDim2.new(1, -10, 0, 8),
				Position = UDim2.new(0, 5, 1, -13),
			})
			bar.set(1)
			table.insert(refs.teamRows, { frame = frame, bar = bar, uid = uid })
		end
	end
end

local function updateTeamHealth()
	local folder = Workspace:FindFirstChild("Followers")
	local models = {}
	if folder then
		for _, model in folder:GetChildren() do
			if model:GetAttribute("OwnerId") == player.UserId then
				models[model:GetAttribute("Uid")] = model
			end
		end
	end
	for _, row in refs.teamRows do
		local model = models[row.uid]
		if model then
			local hp = model:GetAttribute("HP") or 0
			local maxHp = model:GetAttribute("MaxHP") or 1
			row.bar.set(hp / maxHp)
			row.bar.setColor(hp / maxHp > 0.35 and C.Green or C.Red)
		else
			row.bar.set(0)
		end
	end
end

-- Pastille « ! » sur Améliorations quand un nœud est achetable.
local function refreshBadges(data)
	local tree = State.skillTree()
	local skills = State.skills()
	local affordable = false
	for _, node in tree.Nodes do
		if not skills[node.id] and data.coins >= node.cost then
			local ok = true
			for _, req in node.requires do
				ok = ok and skills[req] == true
			end
			if ok then
				affordable = true
				break
			end
		end
	end
	local tile = refs.tiles and refs.tiles["Améliorations"]
	if tile then
		Components.setBadge(tile, affordable and "!" or nil)
	end
end

local function layoutForDevice()
	-- Sur téléphone, le bouton de saut et le joystick occupent les coins du bas.
	local touch = Console.isTouch()
	if refs.team then
		refs.team.Position = touch and UDim2.new(1, -16, 1, -190) or UDim2.new(1, -16, 1, -14)
	end
	if refs.gridScale then
		refs.gridScale.Scale = touch and 0.78 or 1
	end
end

function HUD.init(gui: ScreenGui)
	local root = Theme.scaledRoot(gui, "HUD", 1)
	refs.root = root
	buildCurrency(root)
	buildMenuGrid(root)
	buildBanner(root)
	buildTeamPanel(root)
	buildBottom(root)
	layoutForDevice()
	Console.onModeChanged(layoutForDevice)
	-- L'arbre de compétences occupe tout l'écran : le HUD se cache pendant ce temps.
	Menus.onChanged(function(name)
		root.Visible = name ~= "SkillTree"
	end)

	local lastTeamKey = ""
	State.onChanged(function(data)
		refreshMaterials(data)
		refreshBadges(data)
		local key = table.concat(data.team, ",")
		for _, uid in data.team do
			local entry = data.characters[uid]
			key ..= entry and (entry.level .. entry.stars) or ""
		end
		if key ~= lastTeamKey then
			lastTeamKey = key
			refreshTeam(data)
		end
	end)

	-- Compteurs qui « roulent » (pièces, cristaux).
	Theme.onFrame(refs.coins, function()
		local data = State.data
		if not data then
			return
		end
		local target = data.coins
		if math.abs(target - displayed.coins) < 1 then
			displayed.coins = target
		else
			displayed.coins += (target - displayed.coins) * 0.18
		end
		refs.coins.Text = Formulas.formatNumber(math.floor(displayed.coins))
		local crystals = data.traitCrystals or 0
		displayed.crystals = crystals
		refs.crystals.Text = Formulas.formatNumber(crystals)
		refs.income.Text = "+"
			.. Formulas.formatNumber(player:GetAttribute("IncomePerSec") or 0)
			.. " /s   ·   Puissance "
			.. Formulas.formatNumber(player:GetAttribute("TeamPower") or 0)
	end)

	task.spawn(function()
		while true do
			local state = State.gameState()
			local universe = State.universe()
			local now = State.now()
			local endsAt = state:GetAttribute("UniverseEndsAt") or now
			local remaining = math.max(0, endsAt - now)
			local nextUniverse = Universes.get(state:GetAttribute("NextUniverseId") or "")
			refs.universeName.Text = string.upper(universe.name)
			refs.nameGradient.Color = Theme.sequence({ Theme.light(universe.color, 0.65), Theme.light(universe.color, 0.15) })
			refs.bannerGradient.Color = Theme.sequence({ Theme.dark(universe.color, 0.35), Theme.dark(universe.color, 0.72), Color3.fromRGB(14, 14, 20) })
			refs.bannerEdge.Color = Theme.light(universe.color, 0.4)
			refs.portalGradient.Color = Theme.sequence({ WHITE, universe.color, Theme.dark(universe.color, 0.6) })
			refs.universeSub.Text = "Ensuite : " .. (nextUniverse and nextUniverse.name or "?")
			refs.timer.Text = Formulas.formatTime(remaining)
			refs.timer.TextColor3 = remaining < 60 and C.Red or C.Gold
			refs.universeBar.set(1 - remaining / Economy.UniverseDuration)
			refs.universeBar.setColor(universe.color)

			local eventName = state:GetAttribute("EventName")
			refs.eventChip.Visible = eventName ~= nil
			if eventName then
				refs.eventLabel.Text = eventName .. " · " .. Formulas.formatTime((state:GetAttribute("EventEndsAt") or now) - now)
			end
			Components.setBadge(refs.eventTile, eventName and "!" or nil)
			local bossAt = state:GetAttribute("BossAt")
			refs.bossChip.Visible = bossAt ~= nil or state:GetAttribute("BossAlive") == true
			if state:GetAttribute("BossAlive") then
				refs.bossLabel.Text = "BOSS AU CENTRE !"
			elseif bossAt then
				refs.bossLabel.Text = "Boss dans " .. Formulas.formatTime(bossAt - now)
			end
			local restock = state:GetAttribute("ShopRestockAt")
			refs.shopChip.Visible = restock ~= nil
			if restock then
				refs.shopLabel.Text = "Boutique : " .. Formulas.formatTime(restock - now)
			end
			refs.objective.Text = objectiveText(State.data)
			updateTeamHealth()
			task.wait(0.25)
		end
	end)
end

-- Rebond de la pièce (appelé quand on gagne des pièces).
function HUD.pulseCoins()
	if refs.coinScale then
		refs.coinScale.Scale = 1.35
		Theme.tween(refs.coinScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function HUD.coinScreenPosition(): Vector2?
	local frame = refs.coins
	if not frame then
		return nil
	end
	return frame.AbsolutePosition + Vector2.new(20, frame.AbsoluteSize.Y / 2)
end

function HUD.root(): Frame?
	return refs.root
end

-- Premier bouton de la grille (sélection manette quand on entre dans le HUD).
function HUD.firstTile(): GuiObject?
	return refs.eventTile
end

return HUD
