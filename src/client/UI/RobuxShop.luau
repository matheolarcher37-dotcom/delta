-- BOUTIQUE ROBUX : trois onglets (Passes, Packs, Boosts) en grandes cartes brillantes.
--   • Passes : Roulement automatique + en vedette (500 R$), puis x2 / x3 persos, x2 Argent,
--     x2 Chance, Lancer AFK (29 R$), +2 Cases, VIP et le Pack de départ (un seul achat).
--     Badge « POSSÉDÉ » quand le passe est à toi.
--   • Packs  : pièces (selon tes revenus) et gemmes de trait (Cristaux de Trait).
--   • Boosts : Chance x2 / Argent x2 pendant 15 min (ou les deux pendant 30 min), minuteur en direct.
-- Le bouton de prix ouvre l'achat Roblox (Robux_Buy). Manette : A = acheter, LB / RB = onglets.
-- Pendant la boutique : voile sombre derrière la fenêtre et HUD caché (HUD.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Robux = require(Shared.Config.Robux)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local Console = require(script.Parent.Console)
local State = require(script.Parent.Parent.State)

local RobuxShop = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(200, 50, 230)
RobuxShop.Accent = ACCENT
RobuxShop.RobuxGreen = Color3.fromRGB(0, 178, 110)

local player = Players.LocalPlayer

local window
local refs: { [string]: any } = {}
local sweeps: { { gradient: UIGradient, phase: number } } = {}
local timers: { () -> () } = {}
local busy = false
local currentTab = "passes"

local function isStudio(): boolean
	local ok, result = pcall(function()
		return RunService:IsStudio()
	end)
	return ok and result == true
end

local function now(): number
	local ok, t = pcall(State.now)
	return ok and t or os.time()
end

------------------------------------------------------------------------
-- Petits éléments réutilisables (aussi utilisés par la barre de droite)
------------------------------------------------------------------------

-- Icône Robux (hexagone + carré), dessinée avec des Frames.
function RobuxShop.robuxIcon(parent: Instance, size: number, color: Color3?, props: { [string]: any }?): Frame
	local holder = new("Frame", {
		Name = "RobuxIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(holder :: any)[key] = value
		end
	end
	local tint = color or WHITE
	local z = holder.ZIndex
	local shadow = Components.hexagon(holder, size * 0.5, Color3.new(0, 0, 0), { Position = UDim2.new(0.5, 1, 0.5, 2), ZIndex = z })
	Components.setHexColor(shadow, Color3.new(0, 0, 0), 0.55)
	Components.hexagon(holder, size * 0.5, tint, { ZIndex = z })
	Components.hexagon(holder, size * 0.33, Theme.dark(RobuxShop.RobuxGreen, 0.55), { ZIndex = z })
	local square = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.3, size * 0.3),
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = holder,
	})
	Theme.corner(math.max(1, math.floor(size * 0.06))).Parent = square
	return holder
end

-- Reflet animé qui balaie une carte (dégradé qui respecte les coins arrondis).
function RobuxShop.sweep(parent: GuiObject, radius: number, phase: number, list: { any }?): UIGradient
	local overlay = new("Frame", {
		Name = "Sweep",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = parent.ZIndex + 4,
		Parent = parent,
	})
	Theme.corner(radius).Parent = overlay
	local gradient = new("UIGradient", {
		Rotation = 25,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.47, 0.82),
			NumberSequenceKeypoint.new(0.5, 0.62),
			NumberSequenceKeypoint.new(0.53, 0.82),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = overlay,
	})
	table.insert(list or sweeps, { gradient = gradient, phase = phase })
	return gradient
end

-- Fait avancer les reflets : un passage toutes les ~3,5 s, décalé selon la carte.
function RobuxShop.animateSweeps(list: { any }, t: number)
	for _, info in list do
		local cycle = (t * 0.32 + info.phase) % 1.15
		info.gradient.Offset = Vector2.new(-1 + cycle * 2.2, 0)
	end
end

-- Halo lumineux rond derrière une icône.
local function glow(parent: Instance, color: Color3, size: number, position: UDim2)
	local halo = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.light(color, 0.35),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Theme.round().Parent = halo
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = halo,
	})
	return halo
end

-- Grande icône d'offre (icône vectorielle + badge « x2 / x3 / + »).
function RobuxShop.offerIcon(parent: Instance, icon: string, color: Color3, size: number, badge: string?, position: UDim2?, fill: Color3?)
	local holder = new("Frame", {
		Name = "OfferIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	if icon == "coin" then
		Components.coinIcon(holder, math.floor(size * 0.84)).ZIndex = 3
	else
		Icons.make(icon, holder, { px = size, size = UDim2.fromScale(0.9, 0.9), color = fill, ink = Theme.dark(color, 0.55), zindex = 3 })
	end
	if badge then
		Theme.label({
			Name = "Badge",
			Text = badge,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, size * 0.18, 1, size * 0.08),
			Size = UDim2.fromOffset(size * 0.62, size * 0.46),
			FontFace = Theme.Faces.Title,
			TextColor3 = Color3.fromRGB(255, 236, 90),
			StrokeThickness = math.max(2, size / 22),
			ZIndex = 6,
			Parent = holder,
		})
	end
	return holder
end

-- Bouton de prix en Robux (icône Robux + prix), ou « POSSÉDÉ ».
function RobuxShop.priceButton(parent: Instance, price: number, props: { [string]: any }, onClick: () -> ()): TextButton
	local button = Components.button({
		Text = tostring(price),
		Icon = "coin",
		Color = props.Color or RobuxShop.RobuxGreen,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		TextSize = props.TextSize or 28,
		Parent = parent,
		OnClick = onClick,
	})
	button.Name = "PriceButton"
	local holder = button:FindFirstChild("IconHolder", true)
	if holder then
		Components.clear(holder)
		RobuxShop.robuxIcon(holder, (props.IconSize or 26), WHITE, { ZIndex = 3 })
	end
	return button
end

-- `included` : passe contenu dans un passe plus grand déjà possédé (« INCLUS ✓ »).
function RobuxShop.setOwned(button: Instance, owned: boolean, price: number?, included: boolean?)
	local holder = button:FindFirstChild("IconHolder", true) :: GuiObject?
	if holder then
		holder.Visible = not owned
	end
	Components.setButtonText(button, owned and (included and "INCLUS ✓" or "POSSÉDÉ ✓") or tostring(price or ""))
	Components.setButtonColor(button, owned and Color3.fromRGB(80, 86, 104) or RobuxShop.RobuxGreen)
end

local function ribbon(parent: Instance, text: string, color: Color3, props: { [string]: any }?)
	local band = new("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(150, 28),
		BackgroundColor3 = WHITE,
		ZIndex = 8,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(band :: any)[key] = value
		end
	end
	Theme.round().Parent = band
	Theme.stroke(C.Stroke, 2.5).Parent = band
	Theme.gradient({ Theme.light(color, 0.35), color, Theme.dark(color, 0.3) }, 90).Parent = band
	Theme.label({
		Text = text,
		Size = UDim2.new(1, -14, 1, -6),
		Position = UDim2.fromOffset(7, 3),
		FontFace = Theme.Faces.Title,
		ZIndex = 9,
		StrokeThickness = 2,
		Parent = band,
	})
	return band
end

-- Passe possédé : pastille ✓ ronde dans le coin haut droit (loin de l'icône) et icône atténuée.
-- Le bouton du bas affiche aussi « POSSÉDÉ ✓ ».
local function ownedTag(card: Instance)
	local tag = new("Frame", {
		Name = "Owned",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -9, 0, 9),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = WHITE,
		ZIndex = 9,
		Parent = card,
	})
	Theme.round().Parent = tag
	Theme.stroke(C.Stroke, 2.5).Parent = tag
	Theme.gradient({ Color3.fromRGB(120, 240, 130), C.Green, Color3.fromRGB(30, 140, 60) }, 90).Parent = tag
	Theme.label({
		Text = "✓",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		FontFace = Theme.Faces.Heavy,
		ZIndex = 10,
		StrokeThickness = 1.5,
		Parent = tag,
	})
	-- Icône atténuée (sans CanvasGroup, qui couperait le badge « x2 » qui dépasse).
	local icon = card:FindFirstChild("OfferIcon")
	if icon then
		local function fade(value: number): number
			return 1 - (1 - value) * 0.5
		end
		for _, item in icon:GetDescendants() do
			if item:IsA("TextLabel") then
				item.TextTransparency = fade(item.TextTransparency)
				item.TextStrokeTransparency = fade(item.TextStrokeTransparency)
			end
			if item:IsA("GuiObject") then
				item.BackgroundTransparency = fade(item.BackgroundTransparency)
			elseif item:IsA("UIStroke") then
				item.Transparency = fade(item.Transparency)
			end
		end
	end
	return tag
end

-- Petite mention en bas d'une carte quand l'id n'est pas encore collé dans Config/Robux.
local function configTag(parent: Instance, entry)
	if Robux.isConfigured(entry) then
		return
	end
	local studio = isStudio()
	Theme.label({
		Name = "ConfigTag",
		Text = studio and "Test Studio : achat simulé" or "Bientôt disponible",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -20, 0, 14),
		FontFace = Theme.Faces.Bold,
		TextColor3 = studio and Color3.fromRGB(150, 230, 255) or C.TextDim,
		StrokeThickness = 1,
		MaxSize = 13,
		ZIndex = 6,
		Parent = parent,
	})
end

-- Taille de texte minimale (coordonnées logiques) : à 720p avec la fenêtre réduite à la manette,
-- 17 donne encore environ 14 px réels.
local MIN_TEXT = 17
local function minText(label: TextLabel, value: number?)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not constraint then
		constraint = new("UITextSizeConstraint", { Parent = label })
	end
	local minimum = value or MIN_TEXT
	constraint.MinTextSize = minimum
	constraint.MaxTextSize = math.max(constraint.MaxTextSize, minimum)
	return label
end

-- Fond de carte : dégradé de la couleur, liseré clair, étincelles, reflet animé.
local function cardBase(parent: Instance, name: string, color: Color3, size: UDim2, position: UDim2?, seed: number): Frame
	local card = new("Frame", {
		Name = name,
		Size = size,
		Position = position or UDim2.new(),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	Theme.corner(18).Parent = card
	Theme.stroke(C.Stroke, 3).Parent = card
	Theme.gradient({ Theme.dark(color, 0.12), Theme.dark(color, 0.55), Color3.fromRGB(14, 14, 22) }, 90).Parent = card
	local rim = new("Frame", { Name = "Rim", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Parent = card })
	Theme.corner(15).Parent = rim
	Theme.stroke(Theme.light(color, 0.25), 2, 0.25).Parent = rim
	Theme.sparkles(card, 7, seed, 0.66)
	RobuxShop.sweep(card, 18, (seed % 10) / 10)
	return card
end

------------------------------------------------------------------------
-- Achat
------------------------------------------------------------------------

function RobuxShop.buy(kind: string, key: string)
	local entry = Robux.get(kind, key)
	if not entry or busy then
		return
	end
	if kind == "pass" and Robux.hasPass(player, key) then
		Notifications.toast("Tu possèdes déjà « " .. entry.name .. " » !", "info")
		return
	end
	local bigger = kind == "pass" and Robux.coveredBy(player, key)
	if bigger then
		Notifications.toast("Déjà inclus dans « " .. Robux.Passes[bigger].name .. " » !", "info")
		return
	end
	if kind == "product" and entry.once and Robux.onceTaken(State.data, key) then
		Notifications.toast("Tu as déjà pris « " .. entry.name .. " » (un seul achat).", "info")
		return
	end
	busy = true
	local ok, message = State.invoke("Robux_Buy", kind, key)
	busy = false
	if type(message) == "string" and message ~= "" then
		Notifications.toast(message, ok and "success" or "error")
	end
end

------------------------------------------------------------------------
-- Onglet Passes
------------------------------------------------------------------------

local function passCard(parent: Instance, key: string, size: UDim2, position: UDim2, seed: number)
	local pass = Robux.Passes[key]
	local owned = Robux.passCovered(player, key)
	local included = owned and not Robux.hasPass(player, key)
	local card = cardBase(parent, "Pass_" .. key, pass.color, size, position, seed)
	glow(card, pass.color, 100, UDim2.new(0.5, 0, 0, 52))
	RobuxShop.offerIcon(card, pass.icon, pass.color, 68, pass.badge, UDim2.new(0.5, 0, 0, 50))
	Theme.label({
		Name = "Title",
		Text = pass.name,
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 92),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 2.5,
		MaxSize = 26,
		ZIndex = 3,
		Parent = card,
	})
	minText(Theme.label({
		Name = "Desc",
		Text = pass.desc,
		Size = UDim2.new(1, -16, 0, 46),
		Position = UDim2.fromOffset(8, 122),
		FontFace = Theme.Faces.Bold,
		TextColor3 = Color3.fromRGB(226, 228, 240),
		TextWrapped = true,
		StrokeThickness = 1,
		MaxSize = 18,
		ZIndex = 3,
		Parent = card,
	}))
	local button = RobuxShop.priceButton(card, pass.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -21),
		Size = UDim2.new(1, -28, 0, 42),
	}, function()
		RobuxShop.buy("pass", key)
	end)
	button:SetAttribute("SelKey", "pass_" .. key)
	if owned then
		RobuxShop.setOwned(button, true, nil, included)
		ownedTag(card)
	end
	configTag(card, pass)
	refs.firstButton = refs.firstButton or button
	return card, button
end

local function featuredCard(parent: Instance, key: string, size: UDim2)
	local pass = Robux.Passes[key]
	local owned = Robux.passCovered(player, key)
	local included = owned and not Robux.hasPass(player, key)
	local card = cardBase(parent, "Pass_" .. key, pass.color, size, UDim2.new(), 3)
	Theme.rainbowStroke(card:FindFirstChild("Rim") :: GuiObject, 3)
	ribbon(card, "MEILLEURE OFFRE", C.Gold, { Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(190, 32) })
	glow(card, pass.color, 170, UDim2.new(0.5, 0, 0, 108))
	RobuxShop.offerIcon(card, pass.icon, pass.color, 112, pass.badge, UDim2.new(0.5, 0, 0, 104))
	Theme.label({
		Name = "Title",
		Text = "ROULEMENT\nAUTOMATIQUE +",
		Size = UDim2.new(1, -24, 0, 62),
		Position = UDim2.fromOffset(12, 170),
		FontFace = Theme.Faces.Title,
		TextColor3 = WHITE,
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = card,
	})
	local list = new("Frame", { Name = "Perks", Size = UDim2.new(1, -36, 0, 150), Position = UDim2.fromOffset(18, 240), BackgroundTransparency = 1, Parent = card })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left).Parent = list
	for i, perk in pass.perks or {} do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = i, Parent = list })
		local check = new("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(0, 2), BackgroundColor3 = C.Green, Parent = row })
		Theme.round().Parent = check
		Theme.stroke(C.Stroke, 2).Parent = check
		Theme.label({ Text = "✓", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), FontFace = Theme.Faces.Heavy, Parent = check })
		Theme.label({
			Text = perk,
			Size = UDim2.new(1, -36, 1, -4),
			Position = UDim2.fromOffset(34, 2),
			FontFace = Theme.Faces.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			MaxSize = 19,
			Parent = row,
		})
	end
	local button = RobuxShop.priceButton(card, pass.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(1, -36, 0, 58),
		TextSize = 34,
		IconSize = 32,
	}, function()
		RobuxShop.buy("pass", key)
	end)
	button:SetAttribute("SelKey", "pass_" .. key)
	if owned then
		RobuxShop.setOwned(button, true, nil, included)
		ownedTag(card)
	end
	configTag(card, pass)
	return card, button
end

-- Pack de départ (dernière case de la grille) : pièces + gemmes de trait + Chance x2, un seul achat.
local function starterCard(parent: Instance, size: UDim2, position: UDim2, seed: number)
	local key = "Starter"
	local product = Robux.Products[key]
	local color = Color3.fromRGB(255, 170, 40)
	local taken = Robux.onceTaken(State.data, key)
	local card = cardBase(parent, "Pack_" .. key, color, size, position, seed)
	Theme.rainbowStroke(card:FindFirstChild("Rim") :: GuiObject, 2)
	ribbon(card, product.ribbon or "1 SEUL ACHAT", C.Red, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(150, 26) })
	glow(card, color, 110, UDim2.new(0.5, 0, 0, 54))
	-- Trois objets du pack : pièces, gemme de trait, trèfle de chance.
	local icons = new("Frame", {
		Name = "OfferIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(140, 70),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = card,
	})
	Components.coinIcon(icons, 50, UDim2.fromScale(0.2, 0.55)).ZIndex = 3
	Components.gem(icons, C.Cyan, 40, UDim2.fromScale(0.5, 0.42)).ZIndex = 4
	RobuxShop.offerIcon(icons, "clover", Robux.Boosts.Luck.color, 50, nil, UDim2.fromScale(0.8, 0.55), Robux.Boosts.Luck.color)
	Theme.label({
		Name = "Title",
		Text = product.name,
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 92),
		FontFace = Theme.Faces.Title,
		TextColor3 = Color3.fromRGB(255, 226, 120),
		StrokeThickness = 2.5,
		MaxSize = 26,
		ZIndex = 3,
		Parent = card,
	})
	minText(Theme.label({
		Name = "Desc",
		Text = "¥ + " .. (product.crystals or 0) .. " gemmes + Chance x2",
		Size = UDim2.new(1, -16, 0, 46),
		Position = UDim2.fromOffset(8, 122),
		FontFace = Theme.Faces.Bold,
		TextColor3 = Color3.fromRGB(226, 228, 240),
		TextWrapped = true,
		StrokeThickness = 1,
		MaxSize = 18,
		ZIndex = 3,
		Parent = card,
	}))
	local button = RobuxShop.priceButton(card, product.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -21),
		Size = UDim2.new(1, -28, 0, 42),
		Color = Color3.fromRGB(230, 140, 20),
	}, function()
		RobuxShop.buy("product", key)
	end)
	button:SetAttribute("SelKey", "product_" .. key)
	if taken then
		RobuxShop.setOwned(button, true)
		Components.setButtonText(button, "DÉJÀ PRIS ✓")
		ownedTag(card)
	end
	configTag(card, product)
	return card, button
end

local COLUMNS = 4
local FEATURED_W = 300

local function renderPasses(container: Frame)
	local _, featuredButton = featuredCard(container, "AutoRollPlus", UDim2.new(0, FEATURED_W, 1, 0))
	local grid = new("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, -(FEATURED_W + 12), 1, 0),
		Position = UDim2.fromOffset(FEATURED_W + 12, 0),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local buttons = {}
	local index = 0
	local function cell(i: number): (UDim2, UDim2)
		local col = (i - 1) % COLUMNS
		local row = (i - 1) // COLUMNS
		return UDim2.new(1 / COLUMNS, -9, 0.5, -6), UDim2.new(col / COLUMNS, col * 3, row * 0.5, row * 12)
	end
	for _, key in Robux.PassOrder do
		if key ~= "AutoRollPlus" then
			index += 1
			local size, position = cell(index)
			local _, button = passCard(grid, key, size, position, index * 11)
			buttons[index] = button
		end
	end
	if index < COLUMNS * 2 then
		index += 1
		local size, position = cell(index)
		local _, button = starterCard(grid, size, position, index * 11)
		buttons[index] = button
	end
	refs.firstButton = featuredButton
	-- Navigation manette : la vedette à gauche, la grille 4 x 2 à droite.
	pcall(function()
		featuredButton.NextSelectionRight = buttons[1]
		for i, button in buttons do
			if (i - 1) % COLUMNS == 0 then
				button.NextSelectionLeft = featuredButton
			end
		end
	end)
end

------------------------------------------------------------------------
-- Onglet Packs
------------------------------------------------------------------------

local function coinPile(parent: Instance, tier: number)
	local holder = new("Frame", {
		Name = "Pile",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(120, 80),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	local spots = {
		{ { 0.5, 0.55, 58 } },
		{ { 0.38, 0.6, 52 }, { 0.62, 0.48, 56 } },
		{ { 0.3, 0.62, 48 }, { 0.7, 0.62, 48 }, { 0.5, 0.42, 56 } },
		{ { 0.22, 0.66, 44 }, { 0.78, 0.66, 44 }, { 0.38, 0.4, 50 }, { 0.62, 0.42, 54 }, { 0.5, 0.66, 52 } },
	}
	for _, spot in spots[math.clamp(tier, 1, 4)] do
		Components.coinIcon(holder, spot[3], UDim2.fromScale(spot[1], spot[2])).ZIndex = 3
	end
	return holder
end

local function gemPile(parent: Instance, tier: number)
	local holder = new("Frame", {
		Name = "Pile",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(120, 80),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	local spots = {
		{ { 0.5, 0.5, 40 } },
		{ { 0.36, 0.58, 34 }, { 0.64, 0.46, 40 } },
		{ { 0.26, 0.62, 32 }, { 0.74, 0.62, 32 }, { 0.5, 0.42, 42 } },
	}
	local colors = { C.Cyan, Color3.fromRGB(120, 140, 255), Color3.fromRGB(80, 230, 255) }
	for i, spot in spots[math.clamp(tier, 1, 3)] do
		Components.gem(holder, colors[(i - 1) % #colors + 1], spot[3], UDim2.fromScale(spot[1], spot[2])).ZIndex = 3
	end
	return holder
end

local function packCard(parent: Instance, key: string, size: UDim2, position: UDim2, seed: number)
	local product = Robux.Products[key]
	local isCoins = product.kind == "coins"
	local color = isCoins and Color3.fromRGB(255, 180, 40) or Color3.fromRGB(40, 190, 240)
	local card = cardBase(parent, "Pack_" .. key, color, size, position, seed)
	glow(card, color, 100, UDim2.new(0.5, 0, 0, 50))
	if isCoins then
		coinPile(card, product.tier)
	else
		gemPile(card, product.tier)
	end
	if product.ribbon then
		ribbon(card, product.ribbon, product.ribbon == "MEILLEUR PRIX" and C.Red or C.Purple, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(product.ribbon == "MEILLEUR PRIX" and 132 or 104, 24),
			Rotation = 6,
		})
	end
	local amount = Theme.label({
		Name = "Amount",
		Text = "",
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(10, 88),
		FontFace = Theme.Faces.Title,
		TextColor3 = isCoins and C.Gold or Color3.fromRGB(150, 236, 255),
		StrokeThickness = 2.5,
		ZIndex = 3,
		Parent = card,
	})
	local sub = Theme.label({
		Name = "Sub",
		Text = product.name,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 121),
		FontFace = Theme.Faces.Bold,
		TextColor3 = Color3.fromRGB(220, 222, 236),
		StrokeThickness = 1,
		MaxSize = 16,
		ZIndex = 3,
		Parent = card,
	})
	local function update()
		if isCoins then
			local value = Robux.coinPackAmount(product, player:GetAttribute("IncomePerSec"))
			amount.Text = "¥ " .. Formulas.formatNumber(value)
			sub.Text = product.name .. " · " .. (product.minutes >= 60 and (product.minutes // 60 .. " h") or (product.minutes .. " min")) .. " de revenus"
		else
			amount.Text = "+" .. product.amount .. " gemmes"
		end
	end
	update()
	table.insert(timers, update)
	local button = RobuxShop.priceButton(card, product.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -21),
		Size = UDim2.new(1, -28, 0, 38),
	}, function()
		RobuxShop.buy("product", key)
	end)
	button:SetAttribute("SelKey", "product_" .. key)
	configTag(card, product)
	return card, button
end

local function renderPacks(container: Frame)
	Components.sectionTitle(container, "PIÈCES  ·  plus tu gagnes, plus les packs sont gros !", { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 0, 24) })
	local coins = new("Frame", { Name = "Coins", Size = UDim2.new(1, 0, 0, 214), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, Parent = container })
	local rowA, rowB = {}, {}
	for i, key in Robux.CoinPacks do
		local col = i - 1
		local _, button = packCard(coins, key, UDim2.new(0.25, -9, 1, 0), UDim2.new(col / 4, col * 3, 0, 0), i * 5)
		rowA[i] = button
	end
	Components.sectionTitle(
		container,
		"GEMMES DE TRAIT  ·  pour relancer les traits de tes persos",
		{ Position = UDim2.fromOffset(4, 254), Size = UDim2.new(1, -8, 0, 24) },
		Color3.fromRGB(120, 220, 255)
	)
	local gems = new("Frame", { Name = "Gems", Size = UDim2.new(1, 0, 0, 214), Position = UDim2.fromOffset(0, 284), BackgroundTransparency = 1, Parent = container })
	for i, key in Robux.GemPacks do
		local col = i - 1
		local _, button = packCard(gems, key, UDim2.new(1 / 3, -8, 1, 0), UDim2.new(col / 3, col * 4, 0, 0), i * 9 + 3)
		rowB[i] = button
	end
	refs.firstButton = rowA[1]
	pcall(function()
		for i, button in rowA do
			button.NextSelectionDown = rowB[math.clamp(math.ceil(i * 3 / 4), 1, #rowB)]
		end
		for i, button in rowB do
			button.NextSelectionUp = rowA[math.clamp(math.floor((i - 1) * 4 / 3) + 1, 1, #rowA)]
		end
	end)
end

------------------------------------------------------------------------
-- Onglet Boosts
------------------------------------------------------------------------

local function multiplierPill(parent: Instance, icon: string, color: Color3, order: number)
	local pill = Components.pill(parent, icon, "", color, { Size = UDim2.new(1 / 3, -8, 0, 40), LayoutOrder = order })
	return pill
end

local function boostCard(parent: Instance, key: string, size: UDim2, position: UDim2, seed: number)
	local product = Robux.Products[key]
	local first = Robux.Boosts[product.boosts[1]]
	local combo = #product.boosts > 1
	local color = combo and Color3.fromRGB(255, 120, 60) or first.color
	local card = cardBase(parent, "Boost_" .. key, color, size, position, seed)
	glow(card, color, 150, UDim2.new(0.5, 0, 0, 92))
	if combo then
		RobuxShop.offerIcon(card, "clover", Robux.Boosts.Luck.color, 84, nil, UDim2.new(0.5, -34, 0, 88), Theme.light(Robux.Boosts.Luck.color, 0.2))
		RobuxShop.offerIcon(card, "coin", Robux.Boosts.Coins.color, 84, nil, UDim2.new(0.5, 34, 0, 98))
		ribbon(card, product.ribbon or "LES DEUX", C.Red, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(150, 28) })
	else
		RobuxShop.offerIcon(card, first.icon, first.color, 100, "x2", UDim2.new(0.5, 0, 0, 92), Theme.light(first.color, 0.2))
	end
	Theme.label({
		Name = "Title",
		Text = Formulas.upper(combo and "Chance x2 + Argent x2" or product.name),
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 166),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 2.5,
		MaxSize = 30,
		ZIndex = 3,
		Parent = card,
	})
	Components.pill(card, "hourglass", math.floor(product.duration / 60) .. " minutes", C.Gold, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 206),
		Size = UDim2.fromOffset(170, 32),
	})
	Theme.label({
		Name = "Desc",
		Text = combo and "Chance ET argent doublés" or (product.boosts[1] == "Luck" and "Chance doublée à la machine" or "Toutes tes pièces doublées"),
		Size = UDim2.new(1, -30, 0, 40),
		Position = UDim2.fromOffset(15, 246),
		FontFace = Theme.Faces.Medium,
		TextColor3 = Color3.fromRGB(220, 222, 236),
		TextWrapped = true,
		StrokeThickness = 1,
		MaxSize = 18,
		ZIndex = 3,
		Parent = card,
	})
	minText(card:FindFirstChild("Desc") :: TextLabel)
	local status = Components.pill(card, "bolt", "Inactif", C.Gray, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 292),
		Size = UDim2.new(1, -40, 0, 34),
	})
	local function update()
		-- Actif seulement si TOUS les boosts du produit le sont (le plus court compte).
		local left = math.huge
		for _, boost in product.boosts do
			left = math.min(left, Robux.boostLeft(player, boost, now()))
		end
		Components.setPillText(status, left > 0 and ("ACTIF : " .. Formulas.formatTime(left)) or "Inactif · rachète pour prolonger")
		local stroke = status:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = left > 0 and C.Green or Theme.dark(C.Gray, 0.25)
		end
	end
	update()
	table.insert(timers, update)
	local button = RobuxShop.priceButton(card, product.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.new(1, -36, 0, 52),
		TextSize = 30,
		IconSize = 30,
	}, function()
		RobuxShop.buy("product", key)
	end)
	button:SetAttribute("SelKey", "product_" .. key)
	configTag(card, product)
	return card, button
end

local function renderBoosts(container: Frame)
	local strip = Components.panel(container, { Name = "Multipliers", Size = UDim2.new(1, 0, 0, 62) })
	Theme.label({
		Text = "TES BONUS ACTUELS",
		Size = UDim2.fromOffset(230, 26),
		Position = UDim2.fromOffset(16, 18),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = strip,
	})
	local row = new("Frame", { Size = UDim2.new(1, -260, 1, -14), Position = UDim2.fromOffset(250, 7), BackgroundTransparency = 1, Parent = strip })
	local layout = Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row
	local coinsPill = multiplierPill(row, "coin", C.Gold, 1)
	local luckPill = multiplierPill(row, "clover", C.Green, 2)
	local vipPill = multiplierPill(row, "crown", C.Purple, 3)
	-- « Passe x2 Argent » (définitif) et « Boost Argent x2 · 12:04 » (temporaire) sont bien distingués.
	local function bonusText(passKey: string, boostKey: string, label: string): string
		local pass = Robux.hasPass(player, passKey)
		local left = Robux.boostLeft(player, boostKey, now())
		if pass and left > 0 then
			return "Passe + Boost · " .. Formulas.formatTime(left)
		elseif left > 0 then
			return "Boost x2 · " .. Formulas.formatTime(left)
		elseif pass then
			return "Passe x2 " .. label
		end
		return label .. " : aucun bonus"
	end
	table.insert(timers, function()
		Components.setPillText(coinsPill, bonusText("Coins2", "Coins", "Argent"))
		Components.setPillText(luckPill, bonusText("Luck2", "Luck", "Chance"))
		Components.setPillText(vipPill, Robux.hasPass(player, "VIP") and "VIP actif" or "Pas encore VIP")
	end)
	local cards = new("Frame", { Name = "Cards", Size = UDim2.new(1, 0, 1, -74), Position = UDim2.fromOffset(0, 74), BackgroundTransparency = 1, Parent = container })
	local buttons = {}
	for i, key in Robux.BoostPacks do
		local col = i - 1
		local _, button = boostCard(cards, key, UDim2.new(1 / 3, -8, 1, 0), UDim2.new(col / 3, col * 4, 0, 0), i * 13)
		buttons[i] = button
	end
	refs.firstButton = buttons[1]
	for _, update in timers do
		update()
	end
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------

function RobuxShop.render(tab: string?)
	currentTab = tab or currentTab
	if not refs.container then
		return
	end
	Components.preserveSelection(refs.container, function()
		Components.clear(refs.container)
		table.clear(sweeps)
		table.clear(timers)
		refs.firstButton = nil
		if currentTab == "packs" then
			renderPacks(refs.container)
		elseif currentTab == "boosts" then
			renderBoosts(refs.container)
		else
			renderPasses(refs.container)
		end
	end)
end

function RobuxShop.open(tab: string?)
	Menus.open("RobuxShop", tab)
end

function RobuxShop.init(gui: ScreenGui)
	window = Components.window(gui, "BOUTIQUE ROBUX", ACCENT, UDim2.fromOffset(1120, 640), {
		icon = "shop",
		subtitle = "Passes, packs et boosts en Robux",
		tabs = {
			{ id = "passes", text = "Passes", icon = "crown" },
			{ id = "packs", text = "Packs", icon = "coin" },
			{ id = "boosts", text = "Boosts", icon = "bolt" },
		},
		onTab = function(id)
			RobuxShop.render(id)
			task.defer(function()
				Console.select(refs.firstButton)
			end)
		end,
	})
	refs.window = window
	refs.container = new("Frame", { Name = "Offers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = window.content })

	-- Manette / télé : fenêtre réduite et remontée, pour que la barre d'indications (A, B, LB, RB)
	-- reste bien dans la zone sûre de l'écran (marges des téléviseurs).
	local holder = window.frame
	if typeof(holder) == "Instance" and holder:IsA("GuiObject") then
		local consoleScale = new("UIScale", { Name = "ConsoleScale", Parent = holder })
		local function fitConsole()
			local tv = Console.isGamepad() or Console.isTenFoot()
			consoleScale.Scale = tv and 0.9 or 1
			holder.Position = tv and UDim2.new(0.5, 0, 0.5, -10) or UDim2.fromScale(0.5, 0.52)
		end
		fitConsole()
		Console.onModeChanged(fitConsole)
	end

	-- Voile sombre derrière la fenêtre (le HUD est aussi caché pendant la boutique, voir HUD.luau) :
	-- on ne regarde que la boutique, et les clics à côté sont bloqués.
	local dim = holder and holder.Parent and holder.Parent:FindFirstChild("Dim")
	if dim and dim:IsA("GuiObject") then
		dim.Active = true
	end
	-- Barre d'indications manette (A / B / LB / RB) sur une pastille sombre collée sous la fenêtre.
	local hints = holder and holder:FindFirstChild("PadHints", true)
	if hints and hints:IsA("Frame") then
		hints.AutomaticSize = Enum.AutomaticSize.None
		hints.Size = UDim2.fromOffset(620, 40)
		hints.Position = UDim2.new(0.5, 0, 1, 4)
		hints.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
		hints.BackgroundTransparency = 0.15
		Theme.corner(12).Parent = hints
		Theme.stroke(Color3.fromRGB(90, 70, 130), 1.5, 0.3).Parent = hints
		new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = hints })
	end

	Components.registerWindow(Menus, "RobuxShop", window, function(arg)
		local tab = (arg == "packs" or arg == "boosts" or arg == "passes") and arg or currentTab
		window.setTab(tab, true)
		RobuxShop.render(tab)
		if dim and dim:IsA("GuiObject") then
			dim.BackgroundTransparency = 1
			Theme.tween(dim, 0.15, { BackgroundTransparency = 0.42 })
		end
	end, function()
		return refs.firstButton or window.firstSelectable()
	end)

	-- Reflets et minuteurs (seulement quand la boutique est ouverte).
	local elapsed = 0
	Theme.onFrame(refs.container, function(dt, t)
		if not window.isOpen then
			return
		end
		RobuxShop.animateSweeps(sweeps, t)
		elapsed += dt
		if elapsed >= 0.5 then
			elapsed = 0
			for _, update in timers do
				update()
			end
		end
	end)

	-- Un passe vient d'être accordé (achat, simulation Studio, vérification à l'arrivée).
	for key in Robux.Passes do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
			if window.isOpen then
				RobuxShop.render()
			end
		end)
	end

	-- Le serveur demande d'ouvrir la boutique (passe manquant, ex. « Lancer AFK »).
	Remotes.event("Robux_OpenShop").OnClientEvent:Connect(function(tab)
		RobuxShop.open((tab == "packs" or tab == "boosts") and tab or "passes")
	end)

	-- Achat validé : petite fête.
	Remotes.event("Robux_Granted").OnClientEvent:Connect(function(kind, key, details)
		local entry = Robux.get(kind, key)
		if not entry then
			return
		end
		local text = kind == "pass" and ("« " .. entry.name .. " » est à toi !") or ((type(details) == "table" and details.text) or entry.name)
		Notifications.announce("MERCI ! 💚", text, Color3.fromRGB(90, 255, 160), true)
		if window.isOpen then
			RobuxShop.render()
			-- Offre unique : la sauvegarde arrive juste après, on redessine pour afficher « DÉJÀ PRIS ».
			if kind == "product" and entry.once then
				task.delay(0.6, function()
					if window.isOpen then
						RobuxShop.render()
					end
				end)
			end
		end
	end)
end

return RobuxShop
