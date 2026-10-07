-- BARRE DE DROITE : offres Robux compactes et animées (« x2 Argent », « x2 Chance »,
-- « Roulage x3 », « Lancer AFK »...) avec leur prix en Robux. Un toucher / clic / A ouvre
-- DIRECTEMENT l'achat Roblox. Les passes déjà possédés laissent leur place à l'offre suivante.
-- En bas, le bouton « Boutique » ouvre la boutique Robux complète (manette : Y).
--
-- Placement : bord droit de l'écran, à gauche des panneaux déjà ancrés à droite (panneau de
-- roulage, estrade) s'il y en a, et au-dessus de l'équipe. Plus petite sur téléphone (loin du
-- bouton de saut).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Robux = require(Shared.Config.Robux)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Menus = require(script.Parent.Menus)
local RobuxShop = require(script.Parent.RobuxShop)
local State = require(script.Parent.Parent.State)
local ChatTags = require(script.Parent.Parent.Controllers.ChatTags)

local RobuxSideBar = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local player = Players.LocalPlayer

local BUTTON_W, BUTTON_H, GAP = 104, 92, 8
local ICON_SIZE, ICON_Y, LABEL_Y, LABEL_H = 36, 23, 44, 21 -- icône au-dessus, libellé 4 px dessous
local MAX_SHIFT = 240 -- au-delà, la barre passe SOUS les panneaux de droite au lieu de flotter vers le centre

-- Offres proposées, dans l'ordre (les passes possédés sont sautés).
RobuxSideBar.Offers = {
	{ kind = "pass", key = "Coins2", label = "x2 Argent" },
	{ kind = "pass", key = "Luck2", label = "x2 Chance" },
	{ kind = "pass", key = "Roll3", label = "Roulage x3" },
	{ kind = "pass", key = "AutoRoll", label = "Lancer AFK" },
	{ kind = "pass", key = "VIP", label = "VIP" },
	{ kind = "pass", key = "Roll2", label = "Roulage x2", skipIf = "Roll3" },
	{ kind = "pass", key = "AutoRollPlus", label = "Auto +" },
	{ kind = "product", key = "BoostLuck", label = "Chance x2" },
	{ kind = "product", key = "BoostCoins", label = "Argent x2" },
}

local refs: { [string]: any } = {}
local sweeps: { any } = {}
local timers: { () -> () } = {}
local buttons: { GuiObject } = {}
local lastKey = ""

local function now(): number
	local ok, t = pcall(State.now)
	return ok and t or os.time()
end

-- Offres à afficher maintenant (selon les passes possédés).
function RobuxSideBar.visibleOffers(maxCount: number): { any }
	local list = {}
	for _, offer in RobuxSideBar.Offers do
		local skip = false
		if offer.kind == "pass" then
			skip = Robux.hasPass(player, offer.key) or (offer.skipIf ~= nil and Robux.hasPass(player, offer.skipIf))
		end
		if not skip and #list < maxCount then
			table.insert(list, offer)
		end
	end
	return list
end

local function offerButton(parent: Instance, offer, order: number)
	local entry = Robux.get(offer.kind, offer.key)
	local isBoost = offer.kind == "product"
	local boost = isBoost and Robux.Boosts[entry.boosts[1]] or nil
	local color = boost and boost.color or entry.color
	local icon = boost and boost.icon or entry.icon

	local button = new("TextButton", {
		Name = "Offer_" .. offer.key,
		Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = parent,
	})
	button:SetAttribute("SelKey", offer.key)
	local scale = new("UIScale", { Parent = button })
	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -8),
		BackgroundColor3 = WHITE,
		Parent = button,
	})
	Theme.corner(16).Parent = body
	Theme.stroke(C.Stroke, 2.5).Parent = body
	Theme.gradient({ Theme.light(color, 0.28), color, Theme.dark(color, 0.45) }, 90).Parent = body
	Theme.shine(body, 14, 0.35)
	Theme.sparkles(body, 3, order * 7, 0.6, 3)
	RobuxShop.sweep(body, 16, order * 0.21, sweeps)
	RobuxShop.offerIcon(body, icon, color, ICON_SIZE, nil, UDim2.new(0.5, 0, 0, ICON_Y))
	Theme.label({
		Name = "Label",
		Text = offer.label,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, LABEL_Y),
		Size = UDim2.new(1, -8, 0, LABEL_H),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 2,
		ZIndex = 7,
		Parent = body,
	})
	-- Pastille de prix (dépasse en bas du bouton, comme les jeux de référence).
	local price = new("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(BUTTON_W - 16, 26),
		BackgroundColor3 = WHITE,
		ZIndex = 8,
		Parent = button,
	})
	Theme.round().Parent = price
	Theme.stroke(C.Stroke, 2).Parent = price
	Theme.gradient({ Color3.fromRGB(60, 225, 150), RobuxShop.RobuxGreen, Color3.fromRGB(0, 120, 74) }, 90).Parent = price
	RobuxShop.robuxIcon(price, 17, WHITE, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), ZIndex = 9 })
	local priceLabel = Theme.label({
		Name = "Amount",
		Text = tostring(entry.price),
		Size = UDim2.new(1, -40, 1, -5),
		Position = UDim2.fromOffset(32, 2),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		ZIndex = 9,
		Parent = price,
	})
	if isBoost then
		-- Boost en cours : minuteur à la place du prix (racheter prolonge).
		table.insert(timers, function()
			local left = Robux.boostLeft(player, entry.boosts[1], now())
			priceLabel.Text = left > 0 and Formulas.formatTime(left) or tostring(entry.price)
		end)
	end
	Components.interactive(button, scale, 1.08)
	button.Activated:Connect(function()
		Components.click()
		RobuxShop.buy(offer.kind, offer.key)
	end)
	return button
end

local function shopButton(parent: Instance, order: number)
	local button = new("TextButton", {
		Name = "OpenShop",
		Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = parent,
	})
	button:SetAttribute("SelKey", "OpenShop")
	local scale = new("UIScale", { Parent = button })
	local body = new("Frame", { Name = "Body", Size = UDim2.new(1, 0, 1, -8), BackgroundColor3 = WHITE, Parent = button })
	Theme.corner(16).Parent = body
	Theme.stroke(C.Stroke, 2.5).Parent = body
	Theme.gradient({ Color3.fromRGB(70, 235, 160), RobuxShop.RobuxGreen, Color3.fromRGB(0, 100, 64) }, 90).Parent = body
	Theme.shine(body, 14, 0.35)
	Theme.sparkles(body, 3, 41, 0.6, 3)
	RobuxShop.sweep(body, 16, 0.55, sweeps)
	RobuxShop.robuxIcon(body, ICON_SIZE - 2, WHITE, { Position = UDim2.new(0.5, 0, 0, ICON_Y), ZIndex = 4 })
	Theme.label({
		Name = "Label",
		Text = "Boutique",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, LABEL_Y),
		Size = UDim2.new(1, -8, 0, LABEL_H),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 2,
		ZIndex = 7,
		Parent = body,
	})
	local more = new("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(BUTTON_W - 16, 26),
		BackgroundColor3 = WHITE,
		ZIndex = 8,
		Parent = button,
	})
	Theme.round().Parent = more
	Theme.stroke(C.Stroke, 2).Parent = more
	Theme.gradient({ Color3.fromRGB(255, 236, 120), C.Gold, Color3.fromRGB(210, 140, 20) }, 90).Parent = more
	Theme.label({
		Name = "Amount",
		Text = "Tout voir",
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 1.5,
		ZIndex = 9,
		Parent = more,
	})
	Console.hint(button, "Y", { Position = UDim2.fromOffset(-14, -8), ZIndex = 12 })
	Components.interactive(button, scale, 1.08)
	button.Activated:Connect(function()
		Components.click()
		Menus.toggle("RobuxShop")
	end)
	return button
end

function RobuxSideBar.rebuild(force: boolean?)
	local holder = refs.holder
	if not holder then
		return
	end
	local maxCount = Console.isTouch() and 3 or 4
	local offers = RobuxSideBar.visibleOffers(maxCount)
	local key = tostring(maxCount)
	for _, offer in offers do
		key ..= "," .. offer.key
	end
	if key == lastKey and not force then
		return
	end
	lastKey = key
	Components.preserveSelection(holder, function()
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(sweeps)
		table.clear(timers)
		table.clear(buttons)
		for i, offer in offers do
			table.insert(buttons, offerButton(holder, offer, i))
		end
		table.insert(buttons, shopButton(holder, #offers + 1))
	end)
	for _, update in timers do
		update()
	end
end

-- Hauteur « logique » du calque du HUD.
local function rootHeight(root: Frame): number
	local scale = math.max(0.1, Theme.getScale())
	local ok, size = pcall(function()
		return root.AbsoluteSize
	end)
	local height = (ok and typeof(size) == "Vector2") and size.Y / scale or 0
	return height >= 300 and height or 770
end

-- Échelle de la barre : plus petite au toucher (téléphone), plus grande à la manette / télé
-- (libellés d'au moins ~18 px à 1280 x 720).
function RobuxSideBar.scaleFor(): number
	if Console.isTouch() then
		return 0.8
	elseif Console.isGamepad() or Console.isTenFoot() then
		return 1.14
	end
	return 1
end

-- Panneaux ancrés au bord droit du HUD (panneau de roulage, estrade, équipe...) : { y, h, right }.
local function rightPanels(root: Frame, holder: Frame, H: number)
	local list = {}
	for _, child in root:GetChildren() do
		if child ~= holder and child:IsA("GuiObject") and child.Visible and child.AnchorPoint.X == 1 and child.Position.X.Scale == 1 then
			local h = child.Size.Y.Scale * H + child.Size.Y.Offset
			local y = child.Position.Y.Scale * H + child.Position.Y.Offset - child.AnchorPoint.Y * h
			table.insert(list, { y = y, h = h, right = -child.Position.X.Offset + child.Size.X.Offset + 10 })
		end
	end
	return list
end

-- Place la barre : collée au bord droit ; si un panneau de droite la croise, à sa gauche, ou
-- en dessous de lui quand elle devrait sinon flotter vers le centre de l'écran.
function RobuxSideBar.layout()
	local holder, root = refs.holder, refs.root
	if not holder or not root then
		return
	end
	local touch = Console.isTouch()
	local scaleValue = RobuxSideBar.scaleFor()
	refs.scale.Scale = scaleValue
	local count = #buttons
	local height = (count * (BUTTON_H + GAP) - GAP) * scaleValue
	local top = touch and 236 or 152
	local H = rootHeight(root)
	local panels = rightPanels(root, holder, H)
	local function rightFor(y0: number): (number, number)
		local right, below = 16, y0
		for _, panel in panels do
			if panel.y < y0 + height and panel.y + panel.h > y0 then
				right = math.max(right, panel.right)
				below = math.max(below, panel.y + panel.h + 10)
			end
		end
		return right, below
	end
	local right, below = rightFor(top)
	if right > MAX_SHIFT then
		-- Trop loin du bord : on essaie sous les panneaux (au-dessus du bouton de saut sur mobile).
		local limit = H - (touch and 200 or 16)
		if below + height <= limit then
			local rightBelow = rightFor(below)
			if rightBelow < right then
				top, right = below, rightBelow
			end
		end
	end
	holder.Position = UDim2.new(1, -right, 0, top)
	holder.Size = UDim2.fromOffset(BUTTON_W + 20, height / scaleValue)
end

function RobuxSideBar.init(root: Frame)
	local holder = new("Frame", {
		Name = "RobuxSideBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 152),
		Size = UDim2.fromOffset(BUTTON_W + 20, 400),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local layout = Theme.list(Enum.FillDirection.Vertical, GAP, Enum.HorizontalAlignment.Right)
	layout.Parent = holder
	refs.holder = holder
	refs.root = root
	refs.scale = new("UIScale", { Parent = holder })
	RobuxSideBar.rebuild(true)
	RobuxSideBar.layout()

	-- Animations : reflets, petit rebond l'un après l'autre, minuteurs des boosts.
	local elapsed = 0
	Theme.onFrame(holder, function(dt, t)
		if not root.Visible then
			return
		end
		RobuxShop.animateSweeps(sweeps, t)
		local active = math.floor(t / 2.2) % math.max(1, #buttons)
		for i, button in buttons do
			local body = button:FindFirstChild("Body") :: GuiObject?
			if body then
				local phase = (t % 2.2) / 2.2
				local lift = (i - 1 == active) and math.sin(math.min(1, phase * 2.5) * math.pi) * 4 or 0
				body.Position = UDim2.fromOffset(0, -lift)
			end
		end
		elapsed += dt
		if elapsed >= 0.5 then
			elapsed = 0
			for _, update in timers do
				update()
			end
			RobuxSideBar.rebuild() -- ne reconstruit que si les offres ont changé
			RobuxSideBar.layout()
		end
	end)

	for key in Robux.Passes do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
			RobuxSideBar.rebuild()
			RobuxSideBar.layout()
		end)
	end
	Console.onModeChanged(function()
		RobuxSideBar.rebuild()
		RobuxSideBar.layout()
	end)

	-- Manette : Y ouvre la boutique Robux (hors menus).
	pcall(function()
		ContextActionService:BindActionAtPriority("AT_BoutiqueRobux", function(_, state)
			if state ~= Enum.UserInputState.Begin or Menus.current() ~= nil then
				return Enum.ContextActionResult.Pass
			end
			Menus.open("RobuxShop")
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonY)
	end)

	-- VIP : étiquette dorée devant le nom dans le chat (Controllers/ChatTags combine les étiquettes).
	ChatTags.addPrefix("VIP", function(speaker: Player)
		return Robux.hasPass(speaker, "VIP") and '<font color="#FFD24A">[👑 VIP]</font>' or nil
	end)
end

function RobuxSideBar.holder(): Frame?
	return refs.holder
end

return RobuxSideBar
