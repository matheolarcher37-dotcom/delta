-- HUD : bandeau de l'univers (minuteur 30 min), pièces, matériaux, boutons, équipe, objectif.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.Parent.State)

local HUD = {}

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

local refs = {}
local displayedCoins = 0

local function buildBanner(gui: ScreenGui)
	local banner = new("Frame", {
		Name = "UniverseBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(470, 96),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	Theme.corner(18).Parent = banner
	Theme.registerScaled(banner)
	local stroke = Theme.stroke(C.Stroke, 4)
	stroke.Parent = banner
	refs.bannerGradient = Theme.gradient({ C.PanelLight, C.Panel }, 90)
	refs.bannerGradient.Parent = banner
	refs.universeName = Theme.label({
		Name = "UniverseName",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 4),
		Font = Theme.Fonts.Title,
		StrokeThickness = 3,
		Parent = banner,
	})
	refs.nameGradient = Theme.gradient({ Color3.new(1, 1, 1), Color3.new(1, 1, 1) }, 90)
	refs.nameGradient.Parent = refs.universeName
	refs.universeSub = Theme.label({
		Name = "Sub",
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 44),
		TextColor3 = C.TextDim,
		Parent = banner,
	})
	refs.universeBar = Components.progressBar(banner, C.Gold, {
		Size = UDim2.new(1, -40, 0, 12),
		Position = UDim2.fromOffset(20, 72),
	})

	local chips = new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.fromOffset(600, 34),
		BackgroundTransparency = 1,
		Parent = banner,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	layout.Parent = chips
	local function chip(name: string, color: Color3)
		local frame = new("Frame", {
			Name = name,
			Size = UDim2.fromOffset(250, 32),
			BackgroundColor3 = color,
			Visible = false,
			Parent = chips,
		})
		Theme.corner(16).Parent = frame
		Theme.stroke(C.Stroke, 3).Parent = frame
		Theme.gradient({ color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.25) }, 90).Parent = frame
		local label = Theme.label({ Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Parent = frame })
		return frame, label
	end
	refs.eventChip, refs.eventLabel = chip("Event", C.Purple)
	refs.bossChip, refs.bossLabel = chip("Boss", C.Red)
	refs.shopChip, refs.shopLabel = chip("Shop", C.Blue)
end

local function buildCurrency(gui: ScreenGui)
	local holder = new("Frame", {
		Name = "Currency",
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.fromOffset(270, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left).Parent = holder
	Theme.registerScaled(holder)
	local coins = new("Frame", {
		Name = "Coins",
		Size = UDim2.fromOffset(260, 58),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = 1,
		Parent = holder,
	})
	Theme.corner(29).Parent = coins
	Theme.stroke(C.Stroke, 3).Parent = coins
	local icon = new("Frame", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(7, 7),
		BackgroundColor3 = C.Gold,
		Parent = coins,
	})
	Theme.corner(22).Parent = icon
	Theme.stroke(Color3.fromRGB(150, 100, 20), 3).Parent = icon
	Theme.gradient({ Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 170, 30) }, 90).Parent = icon
	Theme.label({
		Text = "$",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.1),
		Font = Theme.Fonts.Title,
		TextColor3 = Color3.fromRGB(150, 90, 10),
		Stroke = false,
		Parent = icon,
	})
	refs.coinScale = new("UIScale", { Parent = icon })
	refs.coins = Theme.label({
		Name = "Amount",
		Size = UDim2.new(1, -70, 0, 34),
		Position = UDim2.fromOffset(58, 4),
		Font = Theme.Fonts.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coins,
	})
	refs.income = Theme.label({
		Name = "Income",
		Size = UDim2.new(1, -70, 0, 16),
		Position = UDim2.fromOffset(60, 38),
		Font = Theme.Fonts.Small,
		TextColor3 = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coins,
	})
	local crystals = new("Frame", {
		Name = "Crystals",
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = 2,
		Parent = holder,
	})
	Theme.corner(17).Parent = crystals
	Theme.stroke(C.Stroke, 2).Parent = crystals
	refs.crystals = Theme.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextColor3 = Color3.fromRGB(140, 230, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = crystals,
	})
	refs.materials = new("Frame", {
		Name = "Materials",
		Size = UDim2.fromOffset(260, 120),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = holder,
	})
	local grid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(124, 34),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.materials,
	})
	local _ = grid
end

local function buildMenuButtons(gui: ScreenGui)
	local holder = new("Frame", {
		Name = "MenuButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.55, 0),
		Size = UDim2.fromOffset(84, 420),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left).Parent = holder
	Theme.registerScaled(holder)
	local buttons = {
		{
			"🎒\nPersos",
			C.Blue,
			function()
				Menus.toggle("Inventory")
			end,
		},
		{
			"📖\nIndex",
			C.Purple,
			function()
				Menus.toggle("Index")
			end,
		},
		{
			"🏠\nBase",
			C.Green,
			function()
				Remotes.event("Teleport"):FireServer("base")
			end,
		},
		{
			"⚔️\nZone",
			C.Red,
			function()
				Remotes.event("Teleport"):FireServer("zone")
			end,
		},
		{
			"🤝\nTroc",
			C.Orange,
			function()
				Remotes.event("Teleport"):FireServer("trade")
			end,
		},
		{
			"🏛️\nHub",
			C.Pink,
			function()
				Remotes.event("Teleport"):FireServer("hub")
			end,
		},
		{
			"👹\nBoss",
			Color3.fromRGB(150, 40, 60),
			function()
				Remotes.event("Teleport"):FireServer("boss")
			end,
		},
		{
			"❔\nGuide",
			Color3.fromRGB(90, 90, 120),
			function()
				Menus.toggle("Guide")
			end,
		},
	}
	for i, info in buttons do
		Components.button({
			Text = info[1],
			Color = info[2],
			Size = UDim2.fromOffset(78, 54),
			LayoutOrder = i,
			OnClick = info[3],
			Parent = holder,
		})
	end
end

local function buildTeamPanel(gui: ScreenGui)
	local panel = new("Frame", {
		Name = "Team",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -96),
		Size = UDim2.fromOffset(240, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = panel
	Theme.registerScaled(panel)
	refs.team = panel
	refs.teamRows = {}
end

local function buildObjective(gui: ScreenGui)
	local frame = new("Frame", {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(520, 46),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	Theme.corner(23).Parent = frame
	Theme.stroke(C.Stroke, 3).Parent = frame
	Theme.registerScaled(frame)
	refs.objective = Theme.label({
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		Parent = frame,
	})
	new("UITextSizeConstraint", { MaxTextSize = 22, Parent = refs.objective })
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
		return "🎯 Ta relique est prête ! Ouvre-la sur l'autel de ta base ✨"
	end
	if characterCount == 0 then
		if incubating then
			return "🎯 Ta relique s'ouvre bientôt... ⏳"
		elseif relicCount > 0 then
			return "🎯 Pose ta relique sur l'autel de ta base (appuie sur E)"
		else
			return "🎯 Achète une relique à la Machine à Reliques de ta base 🛒"
		end
	end
	if data.stats.kills == 0 then
		return "🎯 Va combattre dans la Zone d'Univers au centre de la carte ⚔️"
	end
	if data.stash >= 50 then
		return "🎯 Récupère tes pièces : marche sur le coffre doré de ta base 💰"
	end
	if next(data.upgrades) == nil and data.coins >= Economy.Upgrades[1].price then
		return "🎯 Améliore ta base : marche sur un bouton vert !"
	end
	for _, entry in data.characters do
		if (entry.stars or 1) < 3 and entry.level >= Formulas.levelCap(entry.stars) then
			return "🎯 Un perso a atteint son niveau max : fais-le évoluer à l'Autel d'Éveil ✨"
		end
	end
	if relicCount > 0 and not incubating then
		return "🎯 Tu as des reliques à ouvrir sur tes autels 🎁"
	end
	local state = State.gameState()
	local nextUniverse = Universes.get(state:GetAttribute("NextUniverseId") or "")
	local endsAt = state:GetAttribute("UniverseEndsAt") or State.now()
	return "🎯 Collectionne les persos de chaque univers ! Ensuite : " .. (nextUniverse and nextUniverse.name or "?") .. " dans " .. Formulas.formatTime(endsAt - State.now())
end

local function refreshMaterials(data)
	if refs.crystals then
		refs.crystals.Text = "💎 " .. Formulas.formatNumber(data.traitCrystals or 0) .. " cristaux"
	end
	Components.clear(refs.materials)
	local order = 0
	for _, universe in Universes.List do
		local count = data.materials[universe.material.id] or 0
		if count > 0 then
			order += 1
			Components.materialPill(refs.materials, universe.material.id, count, order)
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
			local frame = new("Frame", {
				Size = UDim2.fromOffset(230, 42),
				BackgroundColor3 = C.Panel,
				BackgroundTransparency = 0.15,
				LayoutOrder = i,
				Parent = refs.team,
			})
			Theme.corner(12).Parent = frame
			Theme.stroke(C.Stroke, 2).Parent = frame
			Theme.label({
				Text = "Lv." .. entry.level .. "  " .. desc.name,
				Size = UDim2.new(1, -16, 0, 20),
				Position = UDim2.fromOffset(8, 3),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			})
			local bar = Components.progressBar(frame, C.Green, {
				Size = UDim2.new(1, -16, 0, 10),
				Position = UDim2.fromOffset(8, 26),
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

function HUD.init(gui: ScreenGui)
	buildBanner(gui)
	buildCurrency(gui)
	buildMenuButtons(gui)
	buildTeamPanel(gui)
	buildObjective(gui)

	local lastTeamKey = ""
	State.onChanged(function(data)
		refreshMaterials(data)
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

	-- Pièces qui "roulent" + mise à jour du minuteur.
	task.spawn(function()
		while true do
			local data = State.data
			if data then
				local target = data.coins
				if math.abs(target - displayedCoins) < 1 then
					displayedCoins = target
				else
					displayedCoins += (target - displayedCoins) * 0.25
				end
				refs.coins.Text = Formulas.formatNumber(displayedCoins)
				refs.income.Text = "+"
					.. Formulas.formatNumber(player:GetAttribute("IncomePerSec") or 0)
					.. " /s  ·  ⚔️ "
					.. Formulas.formatNumber(player:GetAttribute("TeamPower") or 0)
			end
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		while true do
			local state = State.gameState()
			local universe = State.universe()
			local now = State.now()
			local endsAt = state:GetAttribute("UniverseEndsAt") or now
			local remaining = math.max(0, endsAt - now)
			local nextUniverse = Universes.get(state:GetAttribute("NextUniverseId") or "")
			refs.universeName.Text = "🌀 " .. string.upper(universe.name)
			refs.nameGradient.Color = ColorSequence.new(universe.color:Lerp(Color3.new(1, 1, 1), 0.5), universe.color)
			refs.universeSub.Text = "⏳ " .. Formulas.formatTime(remaining) .. "  ·  Ensuite : " .. (nextUniverse and nextUniverse.name or "?")
			refs.universeBar.set(1 - remaining / Economy.UniverseDuration)
			refs.universeBar.setColor(universe.color)

			local eventName = state:GetAttribute("EventName")
			refs.eventChip.Visible = eventName ~= nil
			if eventName then
				refs.eventLabel.Text = "✨ " .. eventName .. " · " .. Formulas.formatTime((state:GetAttribute("EventEndsAt") or now) - now)
			end
			local bossAt = state:GetAttribute("BossAt")
			refs.bossChip.Visible = bossAt ~= nil
			if state:GetAttribute("BossAlive") then
				refs.bossLabel.Text = "👹 BOSS AU CENTRE !"
			elseif bossAt then
				refs.bossLabel.Text = "👹 Boss dans " .. Formulas.formatTime(bossAt - now)
			end
			local restock = state:GetAttribute("ShopRestockAt")
			refs.shopChip.Visible = restock ~= nil
			if restock then
				refs.shopLabel.Text = "🛒 Reliques : " .. Formulas.formatTime(restock - now)
			end
			refs.objective.Text = objectiveText(State.data)
			updateTeamHealth()
			task.wait(0.25)
		end
	end)
end

-- Petit rebond de l'icône de pièce (appelé quand on gagne des pièces).
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

return HUD
