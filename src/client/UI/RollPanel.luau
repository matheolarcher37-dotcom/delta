-- Panneau de ROULAGE (côté droit du HUD) : « Chance x10 dans N », pitié (Légendaire, Mythique,
-- Secret), chance actuelle, bouton ROULER (X à la manette), auto-roulage, et les persos tirés qui
-- attendent sur l'estrade (bouton « Prendre » = remote CollectRolled).
-- Les remotes Roll / CollectRolled / SetAutoRoll sont créées par le domaine BASE : tant qu'elles
-- n'existent pas, les boutons affichent « Bientôt disponible ».

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local RollPanel = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

local refs: { [string]: any } = {}
local rolling = false
local cooldownUntil = 0

local PITY_DEFAULT = { legendary = 150, mythic = 1200, secret = 8000 }
local PITY_ROWS = { "legendary", "mythic", "secret" }

-- Seuil de pitié d'une rareté (après l'arbre de compétences).
function RollPanel.pityThreshold(rarityId: string, pityMult: number?): number
	local fn = (Formulas :: any).pityThreshold
	if fn then
		local ok, value = pcall(fn, rarityId, pityMult)
		if ok and type(value) == "number" then
			return value
		end
	end
	local roll = (Economy :: any).Roll
	local base = (roll and roll.Pity and roll.Pity[rarityId]) or PITY_DEFAULT[rarityId] or 100
	return math.max(1, math.floor(base * (pityMult or 1) + 0.5))
end

local function characterName(id: string?): string
	local def = id and Characters.get(id)
	return def and def.name or "Perso"
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

function RollPanel.roll()
	if rolling then
		return
	end
	if os.clock() < cooldownUntil then
		return
	end
	rolling = true
	local ok, result = State.invoke("Roll")
	rolling = false
	if ok then
		local stats = State.treeStats()
		cooldownUntil = os.clock() + (stats.rollCooldown or 3)
	elseif type(result) == "string" then
		Notifications.toast(result, "error")
	end
end

local function setAuto(value: boolean)
	local ok, message = State.invoke("SetAutoRoll", value)
	if type(message) == "string" then
		Notifications.toast(message, ok and "success" or "error")
	end
end

-- On envoie la CLÉ du perso (jamais sa position : la file bouge à chaque roulage).
local function collect(key: string)
	local ok, message = State.invoke("CollectRolled", key)
	if type(message) == "string" then
		Notifications.toast(message, ok and "success" or "error")
	end
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

local function pityRow(parent: Instance, rarityId: string, order: number)
	local info = Theme.rarity(rarityId)
	local row = new("Frame", {
		Name = "Pity_" .. rarityId,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local label = Theme.label({
		Text = info.name,
		Size = UDim2.new(0.42, 0, 0, 16),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = info.rainbow and WHITE or Theme.light(info.color, 0.2),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	if info.rainbow then
		Theme.gradient(Theme.RainbowColors, 0).Parent = label
	end
	local count = Theme.label({
		Name = "Count",
		Text = "0 / 0",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.56, 0, 0, 16),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 1.5,
		Parent = row,
	})
	local bar = Components.progressBar(row, info.rainbow and C.Magenta or info.color, {
		Size = UDim2.new(1, 0, 0, 9),
		Position = UDim2.fromOffset(0, 19),
	})
	return { count = count, bar = bar }
end

local ROW_H = 38
local PANEL_H = 276

local function buildQueueRow(parent: Instance, item, index: number)
	local rarityId = item.rarity or "common"
	local info = Theme.rarity(rarityId)
	local free = Formulas.rollCollectFree(State.data, rarityId)
	local row = new("Frame", {
		Name = "Queued" .. index,
		Size = UDim2.new(1, -6, 0, ROW_H),
		BackgroundColor3 = WHITE,
		LayoutOrder = index,
		Parent = parent,
	})
	Theme.corner(10).Parent = row
	if info.rainbow then
		Theme.rainbowStroke(row, 2)
	else
		Theme.stroke(info.color, 2).Parent = row
	end
	Theme.gradient({ Theme.dark(info.rainbow and C.Magenta or info.color, 0.5), Color3.fromRGB(16, 16, 24) }, 0).Parent = row
	Theme.label({
		Text = characterName(item.id),
		Size = UDim2.new(1, -96, 0, 18),
		Position = UDim2.fromOffset(8, 2),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local priceRow = new("Frame", { Size = UDim2.new(1, -96, 0, 15), Position = UDim2.fromOffset(8, 20), BackgroundTransparency = 1, Parent = row })
	Components.coinIcon(priceRow, 14, UDim2.fromOffset(8, 8))
	Theme.label({
		Text = (free and "OFFERT" or Formulas.formatNumber(item.price or 0)) .. "   ·   " .. info.name,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = free and Color3.fromRGB(140, 255, 150) or C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = priceRow,
	})
	local affordable = free or (State.data and State.data.coins or 0) >= (item.price or 0)
	local key = item.key
	Components.button({
		Text = free and "Offert" or "Prendre",
		Color = affordable and C.Green or C.Gray,
		Size = UDim2.fromOffset(82, ROW_H - 6),
		Position = UDim2.new(1, -88, 0, 3),
		TextSize = 18,
		Parent = row,
		OnClick = function()
			if type(key) == "string" then
				collect(key)
			end
		end,
	})
end

local function build(root: Frame)
	local panel = new("Frame", {
		Name = "RollPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 170),
		Size = UDim2.fromOffset(250, PANEL_H),
		BackgroundColor3 = WHITE,
		Parent = root,
	})
	refs.panel = panel
	Theme.corner(16).Parent = panel
	Theme.stroke(C.Stroke, 3).Parent = panel
	Theme.gradient({ Color3.fromRGB(36, 30, 56), Color3.fromRGB(18, 16, 28) }, 90).Parent = panel
	local edge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = panel })
	Theme.corner(14).Parent = edge
	Theme.stroke(C.Purple, 1.5, 0.4).Parent = edge

	-- Titre
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, -12, 0, 34),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = WHITE,
		Parent = panel,
	})
	Theme.corner(11).Parent = header
	Theme.gradient({ Color3.fromRGB(190, 90, 255), Color3.fromRGB(110, 40, 200) }, 0).Parent = header
	Theme.sparkles(header, 4, 5, 0.6)
	local dice = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = header })
	Icons.make("dice", dice, { px = 26, ink = Color3.fromRGB(110, 40, 200) })
	refs.dice = dice
	Theme.label({
		Text = "ROULAGE",
		Size = UDim2.new(0.6, 0, 0, 24),
		Position = UDim2.fromOffset(38, 5),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = header,
	})
	refs.luck = Theme.label({
		Name = "Luck",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 7),
		Size = UDim2.fromOffset(90, 20),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Color3.fromRGB(170, 255, 170),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	-- Chance x10 : segments
	local x10 = new("Frame", {
		Name = "X10",
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 46),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	refs.x10Label = Theme.label({
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = x10,
	})
	local segments = new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1, Parent = x10 })
	local segLayout = Theme.list(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left)
	segLayout.Parent = segments
	refs.segments = segments

	-- Pitié
	Theme.label({
		Name = "PityTitle",
		Text = "GARANTIES (persos tirés)",
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 92),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = panel,
	})
	local pity = new("Frame", {
		Name = "PityRows",
		Size = UDim2.new(1, -24, 0, 102),
		Position = UDim2.fromOffset(12, 108),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left).Parent = pity
	refs.pity = {}
	for i, rarityId in PITY_ROWS do
		refs.pity[rarityId] = pityRow(pity, rarityId, i)
	end

	-- Boutons
	refs.rollButton = Components.button({
		Text = "ROULER",
		Icon = "dice",
		Color = Color3.fromRGB(255, 180, 30),
		Size = UDim2.new(0.64, -6, 0, 50),
		Position = UDim2.new(0, 12, 1, -60),
		Hint = "X",
		Parent = panel,
		OnClick = RollPanel.roll,
	})
	local cooldown = new("Frame", {
		Name = "Cooldown",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = false,
		Parent = refs.rollButton,
	})
	Theme.corner(12).Parent = cooldown
	refs.cooldown = cooldown
	refs.autoButton = Components.button({
		Text = "AUTO",
		Color = C.Gray,
		Size = UDim2.new(0.36, -12, 0, 50),
		Position = UDim2.new(0.64, 6, 1, -60),
		TextSize = 20,
		Parent = panel,
		OnClick = function()
			local info = State.rollInfo()
			if not info.autoUnlocked then
				Notifications.toast("Débloque l'Auto-roulage dans les Améliorations !", "info")
				return
			end
			setAuto(not info.autoRoll)
		end,
	})

	-- Persos qui attendent sur l'estrade (tous : jusqu'à Economy.Roll.QueueMax). Sur PC/console,
	-- entre le panneau et l'équipe (ancré par le bas) ; sur tactile, à gauche du panneau, loin du
	-- bouton de saut. La liste défile si la place manque.
	local queueBox = new("Frame", {
		Name = "QueueBox",
		Size = UDim2.fromOffset(256, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	refs.queueTitle = Theme.label({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -6, 0, 20),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = queueBox,
	})
	local queue = new("ScrollingFrame", {
		Name = "Queue",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Gold,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Selectable = false,
		Parent = queueBox,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left).Parent = queue
	refs.queue = queue
	refs.queueBox = queueBox
	refs.root = root

	Theme.onFrame(cooldown, function()
		local left = cooldownUntil - os.clock()
		if left > 0 then
			local total = math.max(0.1, State.treeStats().rollCooldown or 3)
			cooldown.Visible = true
			cooldown.Size = UDim2.new(math.clamp(left / total, 0, 1), 0, 1, -5)
		else
			cooldown.Visible = false
		end
		if rolling then
			refs.dice.Rotation = (refs.dice.Rotation + 12) % 360
		else
			refs.dice.Rotation = 0
		end
	end)
end

local lastQueueKey = ""
local function refresh()
	local info = State.rollInfo()
	local stats = info.stats
	refs.luck.Text = string.format("Chance x%.2f", stats.luck or 1)
	if info.x10In <= 1 then
		refs.x10Label.Text = "CHANCE x10 : PROCHAIN ROULAGE !"
	else
		refs.x10Label.Text = "Chance x10 dans " .. info.x10In
	end
	-- Segments
	local every = math.clamp(info.x10Every, 1, 20)
	local existing = {}
	for _, child in refs.segments:GetChildren() do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	if #existing ~= every then
		for _, child in existing do
			child:Destroy()
		end
		existing = {}
		for i = 1, every do
			local seg = new("Frame", {
				Name = "Seg" .. i,
				Size = UDim2.new(1 / every, -3, 1, 0),
				BackgroundColor3 = Color3.fromRGB(40, 40, 56),
				LayoutOrder = i,
				Parent = refs.segments,
			})
			Theme.corner(4).Parent = seg
			Theme.stroke(C.Stroke, 1.5).Parent = seg
			table.insert(existing, seg)
		end
		table.sort(existing, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
	end
	local filled = every - info.x10In
	for i, seg in existing do
		seg.BackgroundColor3 = i <= filled and (i == every and C.Orange or C.Gold) or Color3.fromRGB(40, 40, 56)
	end
	-- Pitié
	for _, rarityId in PITY_ROWS do
		local row = refs.pity[rarityId]
		local current = tonumber(info.pity[rarityId]) or 0
		local threshold = RollPanel.pityThreshold(rarityId, stats.pityMult)
		row.count.Text = Formulas.formatNumber(current) .. " / " .. Formulas.formatNumber(threshold)
		row.bar.set(current / threshold)
	end
	-- Auto
	if info.autoUnlocked then
		Components.setButtonText(refs.autoButton, info.autoRoll and "AUTO ✓" or "AUTO")
		Components.setButtonColor(refs.autoButton, info.autoRoll and C.Green or C.Blue)
	else
		Components.setButtonText(refs.autoButton, "AUTO")
		Components.setButtonColor(refs.autoButton, C.Gray)
	end
	-- File d'attente
	local parts = {}
	for i, item in info.queue do
		table.insert(parts, i .. ":" .. tostring(item.key or item.id) .. ":" .. tostring(item.price))
	end
	local coinsOk = {}
	for _, item in info.queue do
		table.insert(coinsOk, (State.data and State.data.coins or 0) >= (item.price or 0) and "1" or "0")
	end
	local key = table.concat(parts, "|") .. table.concat(coinsOk) .. tostring(State.data and State.data.FirstCollectDone)
	if key ~= lastQueueKey then
		lastQueueKey = key
		Components.clear(refs.queue)
		refs.queueTitle.Text = "SUR L'ESTRADE (" .. #info.queue .. "/" .. Economy.Roll.QueueMax .. ")"
		for i, item in info.queue do
			buildQueueRow(refs.queue, item, i)
		end
		RollPanel.layoutQueue()
	end
end

-- Place la liste de l'estrade selon l'appareil et la hauteur réellement libre.
function RollPanel.layoutQueue()
	local box, root = refs.queueBox, refs.root
	if not box or not root then
		return
	end
	local count = #State.rollInfo().queue
	box.Visible = count > 0
	local scale = math.max(0.1, Theme.getScale())
	local okSize, absolute = pcall(function()
		return root.AbsoluteSize
	end)
	local height = (okSize and typeof(absolute) == "Vector2") and absolute.Y / scale or 0
	if height < 300 then
		height = 770
	end
	local wanted = 24 + count * (ROW_H + 4)
	local free
	if Console.isTouch() then
		-- À gauche du panneau ROULER, sous la bannière : le coin bas-droit est au bouton de saut.
		box.AnchorPoint = Vector2.new(1, 0)
		box.Position = UDim2.new(1, -16 - 250 - 10, 0, 170)
		free = height - 170 - 120
	else
		-- Juste au-dessus de l'équipe (bas droite, 70 de haut à 14 du bord).
		box.AnchorPoint = Vector2.new(1, 1)
		box.Position = UDim2.new(1, -13, 1, -98)
		free = height - 98 - (170 + PANEL_H + 8)
	end
	box.Size = UDim2.fromOffset(256, math.max(24 + ROW_H, math.min(wanted, free)))
end

function RollPanel.init(gui: ScreenGui, hudRoot: Frame?)
	local root = hudRoot or Theme.scaledRoot(gui, "RollHUD", 1)
	build(root)
	refresh()
	State.onChanged(refresh)
	Console.setAction("roll", RollPanel.roll)
	Console.onModeChanged(RollPanel.layoutQueue)
	pcall(function()
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(RollPanel.layoutQueue)
	end)
end

function RollPanel.panel(): Frame?
	return refs.panel
end

return RollPanel
