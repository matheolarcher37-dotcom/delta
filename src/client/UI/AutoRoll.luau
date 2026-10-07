-- Fenêtre « Roulement automatique » (ouverte depuis la machine ROULER, bouton AUTO), copiée sur
-- la capture de référence : titre violet incliné, croix rouge ronde, deux colonnes.
--
--   • Colonne gauche « Roulement automatique » (passe Robux AutoRoll, 29 Robux) :
--     « Lancer AFK » + bouton Lancer / Arrêter, puis « Pause sur la rareté » (une ligne par rareté,
--     Activé / Désactivé) et « Pause sur la mutation » : la machine roule toute seule et s'arrête
--     dès qu'un perso coché sort (il reste sur l'estrade).
--   • Colonne droite dorée « Roulement automatique + » (passe AutoRollPlus, 500 Robux) :
--     « Achat automatique » (s'arrête si on ne peut pas payer), « Achat sur la mutation » (une
--     ligne par mutation) et « Avancé » (persos et raretés voulus) : la machine roule en continu
--     et ACHÈTE chaque perso tiré qui correspond aux cibles.
-- Sans le passe, la colonne reste visible mais verrouillée, avec un bouton d'achat (prix Robux).
-- Les réglages sont enregistrés sur le serveur (Roll_SaveAutoSettings). Manette : A choisir,
-- B fermer, la croix pour se déplacer.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Economy = require(Shared.Config.Economy)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Modules.Formulas)
local Universes = require(Shared.Config.Universes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local AutoRoll = {}

local rgb = Color3.fromRGB
local new = Theme.new
local C = Theme.Colors
local WHITE = Color3.new(1, 1, 1)
local ON = rgb(64, 206, 40)
local OFF = rgb(214, 30, 34)
local PURPLE = rgb(150, 70, 255)

local player = Players.LocalPlayer
local refs: { [string]: any } = {}
local settings: { [string]: { [string]: boolean } } = {}
local saveToken = 0
local isOpen = false

------------------------------------------------------------------------
-- Passes Robux (prix et achat)
------------------------------------------------------------------------

local function robuxConfig()
	local config = Theme.optionalConfig("Robux")
	return type(config) == "table" and config or nil
end

-- Infos d'un passe : { name, price, id } (Config/Robux si le domaine Robux l'a créé, sinon
-- les valeurs de Config/Economy.RollPasses).
function AutoRoll.passInfo(key: string)
	local fallback = Economy.RollPasses[key] or { name = key, price = 0 }
	local config = robuxConfig()
	local pass = config and type(config.Passes) == "table" and config.Passes[key]
	if type(pass) == "table" then
		return {
			name = pass.name or fallback.name,
			price = tonumber(pass.price) or fallback.price,
			id = tonumber(pass.id) or 0,
		}
	end
	return { name = fallback.name, price = fallback.price, id = 0 }
end

function AutoRoll.hasPass(key: string): boolean
	return player ~= nil and player:GetAttribute("Pass_" .. key) == true
end

-- Ouvre l'achat d'un passe : remote du domaine Robux s'il existe, sinon l'achat Roblox direct
-- (id de Config/Robux), sinon un message (passe pas encore configuré).
local PROMPT_REMOTES = { "Robux_PromptPass", "Robux_BuyPass", "PromptPass", "BuyPass" }
function AutoRoll.promptPass(key: string)
	for _, name in PROMPT_REMOTES do
		local fn = State.remoteFunction(name)
		if fn then
			task.spawn(function()
				pcall(function()
					fn:InvokeServer(key)
				end)
			end)
			return
		end
		local event = State.remoteEvent(name)
		if event then
			event:FireServer(key)
			return
		end
	end
	local info = AutoRoll.passInfo(key)
	if info.id and info.id > 0 then
		local ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, info.id)
		end)
		if ok then
			return
		end
	end
	Notifications.toast("« " .. info.name .. " » (" .. info.price .. " Robux) : bientôt disponible !", "info")
end

------------------------------------------------------------------------
-- Réglages
------------------------------------------------------------------------

local FIELDS = { "pauseRarities", "pauseMutations", "buyCharacters", "buyRarities", "buyMutations" }

local function loadSettings()
	local source = State.data and State.data.AutoRollSettings or {}
	for _, field in FIELDS do
		settings[field] = table.clone(type(source[field]) == "table" and source[field] or {})
	end
end

local function save()
	saveToken += 1
	local token = saveToken
	task.delay(0.35, function()
		if token ~= saveToken then
			return
		end
		local payload = {}
		for _, field in FIELDS do
			payload[field] = table.clone(settings[field] or {})
		end
		local ok, message = State.invoke("Roll_SaveAutoSettings", payload)
		if not ok and type(message) == "string" then
			Notifications.toast(message, "error")
		end
	end)
end

-- Raretés proposées : toutes celles de la machine (comme sur la capture). Une rareté
-- facultative sans aucun perso dans l'univers actuel est affichée grisée.
local function rarityList(): { { id: string, empty: boolean } }
	local universe = State.universe()
	local pools = Formulas.rollPools(universe and universe.id)
	local list = {}
	for _, id in Economy.RollOrder do
		table.insert(list, { id = id, empty = not Formulas.rollRarityAvailable(id, pools) })
	end
	return list
end

------------------------------------------------------------------------
-- Éléments de la fenêtre
------------------------------------------------------------------------

local function text(parent: Instance, value: string, props: { [string]: any }): TextLabel
	local base = {
		Text = value,
		BackgroundTransparency = 1,
		FontFace = Theme.Faces.Heavy,
		TextColor3 = WHITE,
		StrokeThickness = 2,
		Parent = parent,
	}
	for key, v in props do
		base[key] = v
	end
	return Theme.label(base)
end

-- Bouton plat Activé (vert) / Désactivé (rouge), comme sur la capture.
local function flatButton(parent: Instance, props: { [string]: any }, onClick: () -> ()): TextButton
	local button = new("TextButton", {
		Name = props.Name or "Toggle",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or ON,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 3,
		Parent = parent,
	})
	Theme.corner(props.Radius or 4).Parent = button
	Theme.stroke(rgb(20, 20, 20), 1.5, 0.3).Parent = button
	Theme.gradient({ WHITE, rgb(205, 205, 205) }, 90).Parent = button
	local label = text(button, props.Text or "", {
		Name = "Label",
		Size = UDim2.new(1, -12, 1, -10),
		Position = UDim2.fromOffset(6, 5),
		FontFace = Theme.Faces.Heavy,
		ZIndex = (props.ZIndex or 3) + 1,
		StrokeThickness = 2,
		MaxSize = props.TextSize or 26,
	})
	local _ = label
	local scale = new("UIScale", { Parent = button })
	Components.interactive(button, scale, 1.04)
	button.Activated:Connect(function()
		Components.click()
		onClick()
	end)
	return button
end

local function setFlat(button: TextButton, value: boolean, onText: string?, offText: string?)
	button.BackgroundColor3 = value and ON or OFF
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = value and (onText or "Activé") or (offText or "Désactivé")
	end
end

-- Ligne d'une liste (rareté ou mutation) : nom coloré à gauche, Activé / Désactivé à droite.
local function listRow(parent: Instance, order: number, name: string, color: Color3, rainbow: boolean?, get: () -> boolean, set: (boolean) -> (), note: string?)
	local row = new("Frame", {
		Name = "Row_" .. name,
		Size = UDim2.new(1, -16, 0, 60),
		BackgroundColor3 = rgb(26, 26, 30),
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		ZIndex = 3,
		Parent = parent,
	})
	Theme.corner(14).Parent = row
	if rainbow then
		Theme.rainbowStroke(row, 2.5)
	else
		Theme.stroke(color, 2.5).Parent = row
	end
	Theme.gradient({ rgb(44, 44, 50), rgb(18, 18, 22) }, 90).Parent = row
	local label = text(row, name, {
		Name = "Name",
		Size = UDim2.new(1, -170, 0, 34),
		Position = UDim2.fromOffset(24, 13),
		TextColor3 = rainbow and WHITE or color:Lerp(WHITE, 0.1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		StrokeThickness = 1.5,
	})
	if rainbow then
		Theme.gradient(Theme.RainbowColors, 0).Parent = label
	end
	local toggle
	toggle = flatButton(row, {
		Size = UDim2.fromOffset(114, 42),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		TextSize = 22,
		ZIndex = 4,
	}, function()
		local value = not get()
		set(value)
		setFlat(toggle, value)
		save()
	end)
	setFlat(toggle, get())
	if note then
		-- Ligne grisée (ex. aucun perso de cette rareté dans l'univers actuel) : le réglage reste
		-- modifiable (il servira dans un autre univers), mais la ligne est atténuée.
		row.BackgroundTransparency = 0.45
		label.TextTransparency = 0.45
		label.Size = UDim2.new(1, -170, 0, 26)
		label.Position = UDim2.fromOffset(24, 6)
		text(row, note, {
			Name = "Note",
			Size = UDim2.new(1, -170, 0, 18),
			Position = UDim2.fromOffset(24, 34),
			TextColor3 = rgb(170, 170, 178),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Faces.Bold,
			StrokeThickness = 1,
			ZIndex = 4,
		})
		toggle.BackgroundTransparency = 0.35
	end
	return row, toggle
end

local function sectionTitle(parent: Instance, value: string, order: number, color: Color3?)
	return text(parent, value, {
		Name = "Section",
		Size = UDim2.new(1, -16, 0, 34),
		LayoutOrder = order,
		TextColor3 = color or WHITE,
		ZIndex = 3,
		StrokeThickness = 2,
		MaxSize = 24,
	})
end

local function scrollList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local scroll = new("ScrollingFrame", {
		Name = "List",
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = rgb(120, 120, 130),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Selectable = false,
		ZIndex = 3,
		Parent = parent,
	})
	local layout = Theme.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)
	layout.Parent = scroll
	Theme.padding(0, 4).Parent = scroll
	return scroll
end

-- Cache verrouillé d'une colonne (passe Robux pas encore acheté).
local function lockCover(parent: Instance, key: string, top: number): Frame
	local info = AutoRoll.passInfo(key)
	local cover = new("Frame", {
		Name = "Verrou",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		BackgroundColor3 = rgb(6, 6, 10),
		BackgroundTransparency = 0.08,
		Active = true, -- bloque les clics sur ce qui est dessous
		ZIndex = 8,
		Parent = parent,
	})
	Theme.corner(12).Parent = cover
	local lock = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.08, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = cover,
	})
	Icons.make("lock", lock, { px = 64, zindex = 9, ink = rgb(40, 30, 10) })
	text(cover, info.name, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.08, 72),
		Size = UDim2.new(0.9, 0, 0, 32),
		TextColor3 = key == "AutoRollPlus" and rgb(255, 214, 60) or WHITE,
		ZIndex = 9,
	})
	text(cover, Economy.RollPasses[key] and Economy.RollPasses[key].desc or "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.08, 110),
		Size = UDim2.new(0.86, 0, 0, 56),
		FontFace = Theme.Faces.Bold,
		TextColor3 = rgb(220, 220, 230),
		TextWrapped = true,
		ZIndex = 9,
		StrokeThickness = 1.5,
	})
	local buy = Components.button({
		Text = "Débloquer · " .. info.price .. " R$",
		Color = rgb(40, 200, 90),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.08, 178),
		Size = UDim2.fromOffset(270, 56),
		TextSize = 24,
		Parent = cover,
		OnClick = function()
			AutoRoll.promptPass(key)
		end,
	})
	buy.ZIndex += 9
	for _, d in buy:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 9
		end
	end
	cover:SetAttribute("Pass", key)
	refs["buy_" .. key] = buy
	return cover
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

local function buildTitle(panel: Frame)
	-- Bandeau violet incliné (parallélogramme : bords coupés en biais par le dégradé).
	local tab = new("Frame", {
		Name = "TitleTab",
		Position = UDim2.fromOffset(-24, -26),
		Size = UDim2.fromOffset(560, 74),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = panel,
	})
	local slant = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.07, 1),
		NumberSequenceKeypoint.new(0.0705, 0),
		NumberSequenceKeypoint.new(0.93, 0),
		NumberSequenceKeypoint.new(0.9305, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	local g = new("UIGradient", {
		Color = Theme.sequence({ rgb(190, 120, 255), rgb(140, 60, 245), rgb(98, 32, 210) }),
		Transparency = slant,
		Rotation = 18,
		Parent = tab,
	})
	local _ = g
	local under = new("Frame", {
		Name = "TitleUnder",
		Position = UDim2.fromOffset(-12, 40),
		Size = UDim2.fromOffset(560, 26),
		BackgroundColor3 = rgb(120, 50, 230),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = panel,
	})
	new("UIGradient", {
		Color = Theme.sequence({ rgb(110, 40, 220), rgb(70, 20, 160) }),
		Transparency = slant,
		Rotation = 18,
		Parent = under,
	})
	text(tab, "Roulement automatique", {
		Name = "Title",
		Position = UDim2.fromOffset(52, 15),
		Size = UDim2.new(1, -110, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false, -- une seule ligne (la boîte est assez large pour le titre entier)
		FontFace = Theme.Faces.Heavy,
		ZIndex = 7,
		StrokeThickness = 2.5,
		MaxSize = 32,
	})
end

local function buildClose(panel: Frame)
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -16, 0, 18),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = rgb(200, 30, 36),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 7,
		Parent = panel,
	})
	Theme.round().Parent = close
	Theme.stroke(rgb(30, 10, 12), 4).Parent = close
	Theme.gradient({ rgb(255, 120, 120), rgb(220, 36, 44), rgb(150, 14, 20) }, 90).Parent = close
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -10),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = close,
	})
	Theme.round().Parent = ring
	Theme.stroke(rgb(255, 170, 170), 1.5, 0.3).Parent = ring
	Icons.make("close", close, { px = 34, size = UDim2.fromScale(0.52, 0.52), zindex = 8 })
	local scale = new("UIScale", { Parent = close })
	Components.interactive(close, scale, 1.1)
	Console.hint(close, "B", { Position = UDim2.new(0, -12, 1, -14), ZIndex = 9 })
	close.Activated:Connect(function()
		Components.click()
		Menus.close("AutoRoll")
	end)
	refs.close = close
end

local function buildLeft(panel: Frame)
	local col = new("Frame", {
		Name = "Gauche",
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(0.5, -21, 1, -76),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = panel,
	})
	Theme.corner(12).Parent = col
	Theme.gradient({ rgb(30, 30, 34), rgb(52, 52, 58), rgb(40, 40, 44) }, 90).Parent = col
	refs.left = col
	text(col, "Roulement automatique", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 26), ZIndex = 3, StrokeThickness = 1.5 })
	text(col, "Lancer AFK", { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 40), ZIndex = 3, TextColor3 = rgb(225, 225, 230) })
	refs.afkButton = flatButton(col, {
		Name = "LancerAFK",
		Size = UDim2.fromOffset(236, 54),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		TextSize = 28,
	}, function()
		if not (AutoRoll.hasPass("AutoRoll") or AutoRoll.hasPass("AutoRollPlus")) then
			AutoRoll.promptPass("AutoRoll")
			return
		end
		local running = State.data and State.data.AutoRoll == true
		local ok, message = State.invoke("SetAutoRoll", not running)
		if not ok and type(message) == "string" then
			Notifications.toast(message, "error")
		end
	end)
	text(col, "Pause sur la rareté", { Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 34), ZIndex = 3, TextColor3 = rgb(225, 225, 230) })
	refs.leftList = scrollList(col, UDim2.fromOffset(8, 204), UDim2.new(1, -16, 1, -212))
	refs.leftCover = lockCover(col, "AutoRoll", 0)
end

local function buildRight(panel: Frame)
	local col = new("Frame", {
		Name = "Droite",
		Position = UDim2.new(0.5, 7, 0, 62),
		Size = UDim2.new(0.5, -21, 1, -76),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = panel,
	})
	Theme.corner(12).Parent = col
	Theme.gradient({ rgb(26, 24, 18), rgb(46, 42, 20), rgb(120, 104, 20) }, 90).Parent = col
	refs.right = col
	text(col, "Roulement automatique +", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 26), ZIndex = 3, TextColor3 = rgb(255, 214, 40), StrokeThickness = 1.5 })
	text(col, "Achat automatique", { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 38), ZIndex = 3, TextColor3 = rgb(225, 225, 230) })
	text(col, "S'arrête si vous ne pouvez pas payer !", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 3,
		FontFace = Theme.Faces.Bold,
		TextColor3 = rgb(210, 210, 215),
		StrokeThickness = 1,
	})
	refs.buyButton = flatButton(col, {
		Name = "AchatAuto",
		Size = UDim2.fromOffset(236, 54),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 106),
		TextSize = 28,
	}, function()
		if not AutoRoll.hasPass("AutoRollPlus") then
			AutoRoll.promptPass("AutoRollPlus")
			return
		end
		local running = State.data and State.data.AutoBuy == true
		local ok, message = State.invoke("Roll_SetAutoBuy", not running)
		if not ok and type(message) == "string" then
			Notifications.toast(message, "error")
		end
	end)
	text(col, "Achat sur la mutation", { Position = UDim2.fromOffset(0, 168), Size = UDim2.new(1, 0, 0, 30), ZIndex = 3, TextColor3 = rgb(225, 225, 230) })
	refs.advancedButton = flatButton(col, {
		Name = "Avance",
		Size = UDim2.fromOffset(150, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 202),
		Color = rgb(196, 196, 204),
		Text = "Avancé",
		TextSize = 20,
		Radius = 3,
	}, function()
		AutoRoll.showAdvanced(true)
	end)
	refs.rightList = scrollList(col, UDim2.fromOffset(8, 242), UDim2.new(1, -16, 1, -250))
	refs.rightCover = lockCover(col, "AutoRollPlus", 0)
end

-- Panneau « Avancé » : persos et raretés que l'achat automatique doit acheter.
local function buildAdvanced(panel: Frame)
	local adv = new("Frame", {
		Name = "Avance",
		Position = UDim2.new(0.5, 7, 0, 62),
		Size = UDim2.new(0.5, -21, 1, -76),
		BackgroundColor3 = WHITE,
		Visible = false,
		ZIndex = 10,
		Parent = panel,
	})
	Theme.corner(12).Parent = adv
	Theme.stroke(rgb(255, 214, 40), 2).Parent = adv
	Theme.gradient({ rgb(30, 28, 20), rgb(18, 16, 12) }, 90).Parent = adv
	text(
		adv,
		"Avancé : que faut-il acheter ?",
		{ Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -120, 0, 28), ZIndex = 11, TextColor3 = rgb(255, 214, 40), TextXAlignment = Enum.TextXAlignment.Left }
	)
	refs.advancedBack = flatButton(adv, {
		Name = "Retour",
		Size = UDim2.fromOffset(100, 32),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Color = rgb(196, 196, 204),
		Text = "Retour",
		TextSize = 20,
		ZIndex = 11,
	}, function()
		AutoRoll.showAdvanced(false)
	end)
	text(adv, "Un perso est acheté s'il correspond à TOUS les groupes cochés (persos, raretés, mutations).", {
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 0, 32),
		FontFace = Theme.Faces.Bold,
		TextColor3 = rgb(210, 210, 215),
		TextWrapped = true,
		ZIndex = 11,
		StrokeThickness = 1,
	})
	local scroll = new("ScrollingFrame", {
		Name = "Liste",
		Position = UDim2.fromOffset(8, 80),
		Size = UDim2.new(1, -16, 1, -88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = rgb(160, 140, 60),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Selectable = false,
		ZIndex = 11,
		Parent = adv,
	})
	Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = scroll
	refs.advanced = adv
	refs.advancedList = scroll
end

-- Pastille à cocher (persos et raretés du panneau Avancé).
local function chip(parent: Instance, order: number, label: string, color: Color3, field: string, key: string)
	local button
	local function paint()
		local on = settings[field][key] == true
		button.BackgroundColor3 = on and color:Lerp(rgb(0, 0, 0), 0.15) or rgb(34, 32, 30)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = on and WHITE or color
		end
		local l = button:FindFirstChild("Label") :: TextLabel?
		if l then
			l.Text = (on and "✓ " or "") .. label
		end
	end
	button = new("TextButton", {
		Name = "Chip_" .. key,
		Size = UDim2.fromOffset(140, 36),
		BackgroundColor3 = rgb(34, 32, 30),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		ZIndex = 12,
		Parent = parent,
	})
	Theme.corner(8).Parent = button
	Theme.stroke(color, 2).Parent = button
	text(
		button,
		label,
		{ Name = "Label", Size = UDim2.new(1, -10, 1, -8), Position = UDim2.fromOffset(5, 4), ZIndex = 13, FontFace = Theme.Faces.Heavy, StrokeThickness = 1.5, MaxSize = 18 }
	)
	local scale = new("UIScale", { Parent = button })
	Components.interactive(button, scale, 1.05)
	button.Activated:Connect(function()
		Components.click()
		settings[field][key] = not settings[field][key] or nil
		paint()
		save()
	end)
	paint()
	return button
end

local function grid(parent: Instance, order: number, height: number): Frame
	local holder = new("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = 11,
		Parent = parent,
	})
	local layout = Theme.grid(Vector2.new(140, 36), 8, Enum.HorizontalAlignment.Center)
	layout.Parent = holder
	return holder
end

local function fillAdvanced()
	local scroll = refs.advancedList
	Components.clear(scroll)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	sectionTitle(scroll, "Raretés voulues", nextOrder(), rgb(255, 214, 40)).ZIndex = 12
	local rarities = grid(scroll, nextOrder(), 36)
	-- (seulement les raretés qu'au moins un perso du jeu possède)
	local present = {}
	for _, def in Characters.List do
		present[def.rarity] = true
	end
	for i, item in rarityList() do
		if present[item.id] then
			local info = Theme.rarity(item.id)
			chip(rarities, i, info.name, info.rainbow and C.Magenta or info.color, "buyRarities", item.id)
		end
	end
	-- Persos : l'univers actuel d'abord, puis les autres.
	local current = State.universe()
	local ordered = { current }
	for _, universe in Universes.List do
		if universe.id ~= current.id then
			table.insert(ordered, universe)
		end
	end
	for _, universe in ordered do
		sectionTitle(scroll, "Persos : " .. universe.name .. (universe.id == current.id and " (actuel)" or ""), nextOrder(), rgb(255, 214, 40)).ZIndex = 12
		local chars = grid(scroll, nextOrder(), 36)
		for i, id in universe.characters do
			local def = Characters.get(id)
			if def then
				local info = Theme.rarity(def.rarity)
				chip(chars, i, def.name, info.rainbow and C.Magenta or info.color, "buyCharacters", id)
			end
		end
	end
end

local function fillLists()
	-- Gauche : pause sur la rareté, puis sur la mutation.
	local left = refs.leftList
	Components.clear(left)
	local order = 0
	for _, item in rarityList() do
		local id = item.id
		order += 1
		local info = Theme.rarity(id)
		listRow(left, order, info.name, info.color, info.rainbow, function()
			return settings.pauseRarities[id] == true
		end, function(value)
			settings.pauseRarities[id] = value
		end, item.empty and "aucun perso dans cet univers" or nil)
	end
	order += 1
	sectionTitle(left, "Pause sur la mutation", order, rgb(225, 225, 230))
	for _, id in Mutations.MenuOrder do
		local m = Mutations.List[id]
		order += 1
		listRow(left, order, m.name, m.color, m.rainbow, function()
			return settings.pauseMutations[id] == true
		end, function(value)
			settings.pauseMutations[id] = value or nil
		end)
	end
	-- Droite : mutations voulues pour l'achat automatique (« Pas de mutation » compris).
	local right = refs.rightList
	Components.clear(right)
	listRow(right, 1, "Pas de mutation", rgb(200, 200, 205), false, function()
		return settings.buyMutations[Mutations.None] == true
	end, function(value)
		settings.buyMutations[Mutations.None] = value or nil
	end)
	for i, id in Mutations.MenuOrder do
		local m = Mutations.List[id]
		listRow(right, i + 1, m.name, m.color, m.rainbow, function()
			return settings.buyMutations[id] == true
		end, function(value)
			settings.buyMutations[id] = value or nil
		end)
	end
end

local function refreshState()
	if not refs.afkButton then
		return
	end
	local data = State.data or {}
	setFlat(refs.afkButton, data.AutoRoll ~= true, "Lancer", "Arrêter")
	setFlat(refs.buyButton, data.AutoBuy == true)
	refs.leftCover.Visible = not (AutoRoll.hasPass("AutoRoll") or AutoRoll.hasPass("AutoRollPlus"))
	refs.rightCover.Visible = not AutoRoll.hasPass("AutoRollPlus")
	-- Manette : on ne peut pas sélectionner ce qui est sous un cache verrouillé.
	for _, pair in { { refs.left, refs.leftCover }, { refs.right, refs.rightCover } } do
		local col, cover = pair[1], pair[2]
		for _, d in col:GetDescendants() do
			if d:IsA("GuiButton") and not d:IsDescendantOf(cover) then
				d.Selectable = not cover.Visible
			end
		end
	end
end

function AutoRoll.showAdvanced(show: boolean)
	if not refs.advanced then
		return
	end
	refs.advanced.Visible = show
	if show then
		fillAdvanced()
		Console.select(refs.advancedBack)
	else
		Console.select(refs.advancedButton)
	end
end

local function build(gui: ScreenGui)
	local root = Theme.scaledRoot(gui, "AutoRollRoot", 14)
	root.Visible = false
	refs.root = root
	local dim = new("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rgb(4, 4, 10),
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Parent = root,
	})
	dim.Activated:Connect(function()
		Menus.close("AutoRoll")
	end)
	local holder = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(1000, 590),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local panel = new("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Parent = holder,
	})
	refs.anim = new("UIScale", { Parent = panel })
	Theme.corner(16).Parent = panel
	Theme.stroke(PURPLE, 5).Parent = panel
	Theme.gradient({ rgb(20, 20, 24), rgb(12, 12, 14) }, 90).Parent = panel
	local inner = new("Frame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Theme.corner(13).Parent = inner
	Theme.stroke(rgb(60, 20, 120), 2, 0.2).Parent = inner
	refs.panel = panel
	buildTitle(panel)
	buildClose(panel)
	buildLeft(panel)
	buildRight(panel)
	buildAdvanced(panel)
	Console.hintBar(panel, { { "A", "Choisir" }, { "B", "Fermer" } }, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8) })
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

function AutoRoll.open()
	if not refs.root then
		return
	end
	loadSettings()
	fillLists()
	refreshState()
	refs.advanced.Visible = false
	refs.root.Visible = true
	isOpen = true
	refs.anim.Scale = 0.86
	Theme.tween(refs.anim, 0.26, { Scale = 1 }, Enum.EasingStyle.Back)
end

function AutoRoll.close()
	if not refs.root then
		return
	end
	isOpen = false
	refs.root.Visible = false
end

function AutoRoll.isOpen(): boolean
	return isOpen
end

function AutoRoll.toggle()
	if Menus.current() == "AutoRoll" then
		Menus.close("AutoRoll")
	else
		Menus.open("AutoRoll")
	end
end

-- Premier bouton sélectionné à la manette.
local function selection(): GuiObject?
	if refs.leftCover and not refs.leftCover.Visible then
		return refs.afkButton
	end
	return refs.close
end

function AutoRoll.init(gui: ScreenGui)
	if refs.root then
		return
	end
	build(gui)
	Menus.register("AutoRoll", {
		open = function()
			AutoRoll.open()
		end,
		close = function()
			AutoRoll.close()
		end,
		isOpen = AutoRoll.isOpen,
		selection = selection,
	})
	State.onChanged(function()
		refreshState()
	end)
	if player then
		for _, key in { "Pass_AutoRoll", "Pass_AutoRollPlus" } do
			player:GetAttributeChangedSignal(key):Connect(refreshState)
		end
	end
end

-- Pour les tests et les rendus.
function AutoRoll.refs()
	return refs
end

return AutoRoll
