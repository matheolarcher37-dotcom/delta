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

-- PC / manette : icône, libellé et prix. Téléphone : bouton carré, icône + prix (pas de libellé,
-- illisible à cette taille), voir `dims`.
local BUTTON_W, BUTTON_H, GAP = 104, 86, 6
local ICON_SIZE, ICON_Y, LABEL_Y, LABEL_H = 34, 21, 40, 20 -- icône au-dessus, libellé dessous
local TOUCH_SIZE, TOUCH_ICON = 78, 40
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

-- Mesures du bouton selon l'appareil : largeur, hauteur, mode compact (téléphone).
local function dims(): (number, number, boolean)
	if Console.isTouch() then
		return TOUCH_SIZE, TOUCH_SIZE, true
	end
	return BUTTON_W, BUTTON_H, false
end

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
			skip = Robux.passCovered(player, offer.key) or (offer.skipIf ~= nil and Robux.hasPass(player, offer.skipIf))
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

	local w, h, compact = dims()
	local button = new("TextButton", {
		Name = "Offer_" .. offer.key,
		Size = UDim2.fromOffset(w, h),
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
	local badge = (offer.key == "Roll3" and "x3") or (offer.key == "Roll2" and "x2") or nil
	if compact then
		-- Téléphone : grande icône (avec « x2 / x3 » pour le roulage), prix dessous.
		RobuxShop.offerIcon(body, icon, color, TOUCH_ICON, badge, UDim2.new(0.5, 0, 0, 28))
	else
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
	end
	-- Pastille de prix (dépasse en bas du bouton, comme les jeux de référence).
	local price = new("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(w - (compact and 6 or 16), compact and 28 or 26),
		BackgroundColor3 = WHITE,
		ZIndex = 8,
		Parent = button,
	})
	Theme.round().Parent = price
	Theme.stroke(C.Stroke, 2).Parent = price
	Theme.gradient({ Color3.fromRGB(60, 225, 150), RobuxShop.RobuxGreen, Color3.fromRGB(0, 120, 74) }, 90).Parent = price
	RobuxShop.robuxIcon(price, 17, WHITE, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, compact and 5 or 9, 0.5, 0), ZIndex = 9 })
	local priceLabel = Theme.label({
		Name = "Amount",
		Text = tostring(entry.price),
		Size = UDim2.new(1, compact and -30 or -40, 1, -4),
		Position = UDim2.fromOffset(compact and 25 or 32, 2),
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
	local w, h, compact = dims()
	local button = new("TextButton", {
		Name = "OpenShop",
		Size = UDim2.fromOffset(w, h),
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
	if compact then
		RobuxShop.robuxIcon(body, TOUCH_ICON - 4, WHITE, { Position = UDim2.new(0.5, 0, 0, 28), ZIndex = 4 })
	else
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
	end
	local more = new("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(w - (compact and 6 or 16), compact and 28 or 26),
		BackgroundColor3 = WHITE,
		ZIndex = 8,
		Parent = button,
	})
	Theme.round().Parent = more
	Theme.stroke(C.Stroke, 2).Parent = more
	Theme.gradient({ Color3.fromRGB(255, 236, 120), C.Gold, Color3.fromRGB(210, 140, 20) }, 90).Parent = more
	Theme.label({
		Name = "Amount",
		Text = compact and "Boutique" or "Tout voir",
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
	-- (refs.cap : moins d'offres quand un panneau du bas — barre ROULER, carte du perso tiré,
	-- équipe — laisse moins de hauteur ; voir RobuxSideBar.layout)
	local maxCount = math.max(0, math.min(Console.isTouch() and 3 or 4, refs.cap or 4))
	local offers = RobuxSideBar.visibleOffers(maxCount)
	local key = tostring(maxCount) .. (Console.isTouch() and "t" or "")
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
		return 0.95
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
			-- (ancré en bas de l'écran : barre ROULER, carte du perso tiré, équipe sur PC)
			local bottom = child.Position.Y.Scale >= 1
			table.insert(list, { y = y, h = h, right = -child.Position.X.Offset + child.Size.X.Offset + 10, bottom = bottom })
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
	local w, h = dims()
	local height = (count * (h + GAP) - GAP) * scaleValue
	local top = touch and 236 or 152
	local H = rootHeight(root)
	local panels = {}
	-- Les panneaux du bas (barre ROULER et carte du perso tiré à la machine, équipe) ne poussent
	-- pas la barre vers le centre : ils limitent sa hauteur (moins d'offres, la Boutique reste).
	-- Un panneau ancré en bas compte toujours comme « du bas », même remonté au-dessus du bouton
	-- de saut sur téléphone (sinon la barre flotterait au milieu de l'écran, sur le perso tiré).
	local limitY = H - 16
	for _, panel in rightPanels(root, holder, H) do
		if panel.bottom or panel.y > H * 0.45 then
			-- (marge : les cartes du perso tiré peuvent dépasser un peu leur cadre vers le haut)
			limitY = math.min(limitY, panel.y - 30)
		else
			table.insert(panels, panel)
		end
	end
	local full = ((math.min(Console.isTouch() and 3 or 4, #RobuxSideBar.visibleOffers(4)) + 1) * (h + GAP) - GAP) * scaleValue
	if not touch and top + full > limitY then
		top = 112 -- un peu plus haut (le bord droit est libre sous le haut de l'écran)
	end
	local fit = math.floor(((limitY - top) / scaleValue + GAP) / (h + GAP)) - 1 -- (- 1 : la Boutique)
	fit = math.clamp(fit, 0, 4)
	if fit ~= (refs.cap or 4) then
		refs.cap = fit
		RobuxSideBar.rebuild()
		count = #buttons
		height = (count * (h + GAP) - GAP) * scaleValue
	end
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
	holder.Size = UDim2.fromOffset(w + 20, height / scaleValue)
	-- Pas même la place du bouton Boutique (téléphone à la machine : barre ROULER et carte du
	-- perso tiré remontées au-dessus du bouton de saut) : la barre s'efface plutôt que d'être
	-- coupée par la carte. La Boutique reste ouverte par sa tuile du HUD à gauche.
	holder.Visible = limitY - top >= (h + 24) * scaleValue
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
