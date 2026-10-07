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

local RobuxSideBar = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local player = Players.LocalPlayer

local BUTTON_W, BUTTON_H, GAP = 96, 84, 8

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
	local badge = if isBoost then "x2" else entry.badge

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
	RobuxShop.offerIcon(body, icon, color, 38, badge, UDim2.new(0.5, -4, 0, 24))
	Theme.label({
		Name = "Label",
		Text = offer.label,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.new(1, -8, 0, 20),
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
		Size = UDim2.fromOffset(BUTTON_W - 14, 24),
		BackgroundColor3 = WHITE,
		ZIndex = 8,
		Parent = button,
	})
	Theme.round().Parent = price
	Theme.stroke(C.Stroke, 2).Parent = price
	Theme.gradient({ Color3.fromRGB(60, 225, 150), RobuxShop.RobuxGreen, Color3.fromRGB(0, 120, 74) }, 90).Parent = price
	RobuxShop.robuxIcon(price, 16, WHITE, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 9 })
	local priceLabel = Theme.label({
		Name = "Amount",
		Text = tostring(entry.price),
		Size = UDim2.new(1, -34, 1, -4),
		Position = UDim2.fromOffset(28, 2),
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
		Size = UDim2.fromOffset(BUTTON_W, 46),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = parent,
	})
	button:SetAttribute("SelKey", "OpenShop")
	local scale = new("UIScale", { Parent = button })
	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = button })
	Theme.corner(14).Parent = body
	Theme.stroke(C.Stroke, 2.5).Parent = body
	Theme.gradient({ Color3.fromRGB(70, 235, 160), RobuxShop.RobuxGreen, Color3.fromRGB(0, 110, 70) }, 90).Parent = body
	Theme.shine(body, 12, 0.35)
	RobuxShop.sweep(body, 14, 0.55, sweeps)
	RobuxShop.robuxIcon(body, 24, WHITE, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 4 })
	Theme.label({
		Name = "Label",
		Text = "Boutique",
		Size = UDim2.new(1, -42, 1, -14),
		Position = UDim2.fromOffset(36, 7),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 2,
		ZIndex = 7,
		Parent = body,
	})
	Console.hint(button, "Y", { Position = UDim2.fromOffset(-16, -10), ZIndex = 12 })
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

-- Place la barre : bord droit, à gauche des panneaux ancrés à droite qu'elle croiserait.
function RobuxSideBar.layout()
	local holder, root = refs.holder, refs.root
	if not holder or not root then
		return
	end
	local touch = Console.isTouch()
	local scaleValue = touch and 0.8 or 1
	refs.scale.Scale = scaleValue
	local count = #buttons
	local height = (math.max(0, count - 1) * (BUTTON_H + GAP) + 46) * scaleValue
	local top = touch and 236 or 152
	local bottom = top + height
	local H = rootHeight(root)
	local right = 16
	for _, child in root:GetChildren() do
		if child ~= holder and child:IsA("GuiObject") and child.Visible and child.AnchorPoint.X == 1 and child.Position.X.Scale == 1 then
			local h = child.Size.Y.Scale * H + child.Size.Y.Offset
			local y = child.Position.Y.Scale * H + child.Position.Y.Offset - child.AnchorPoint.Y * h
			if y < bottom and y + h > top then
				right = math.max(right, -child.Position.X.Offset + child.Size.X.Offset + 10)
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

	-- VIP : étiquette dorée devant le nom dans le chat.
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		TextChatService.OnIncomingMessage = function(message)
			local properties = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			local speaker = source and Players:GetPlayerByUserId(source.UserId)
			if speaker and Robux.hasPass(speaker, "VIP") then
				properties.PrefixText = '<font color="#FFD24A">[👑 VIP]</font> ' .. message.PrefixText
			end
			return properties
		end
	end)
end

function RobuxSideBar.holder(): Frame?
	return refs.holder
end

return RobuxSideBar
