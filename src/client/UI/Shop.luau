-- ÉCRAN DU MARCHAND AMBULANT : les objets d'évolution en vente pendant son passage.
--   • à gauche, les objets (aperçu 3D, palier, prix, stock ; « UTILE » si une de tes unités en a
--     besoin pour évoluer) ;
--   • à droite, la fiche de l'objet choisi : description, persos qui l'utilisent, tes unités qui
--     l'attendent, et le bouton ACHETER.
-- Il faut être devant le marchand pour acheter. De loin, l'écran montre son stock et le bouton
-- « Montrer le chemin » trace une ligne lumineuse jusqu'à lui.
-- Manette : la croix ou le joystick choisissent un objet, A achète / choisit, B ferme.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EvolutionItems = require(Shared.Config.EvolutionItems)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Shop = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = EvolutionItems.Merchant.Color

local window
local refs: { [string]: any } = {}
local shopState = nil
local selectedId: string? = nil
local guide: { beam: Beam, a0: Attachment, a1: Attachment, holder: Part, endsAt: number }? = nil

------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------

local function rootPart(): BasePart?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function merchantPosition(): Vector3?
	if shopState and typeof(shopState.position) == "Vector3" then
		return shopState.position
	end
	local attr = State.gameState():GetAttribute("MerchantPosition")
	return typeof(attr) == "Vector3" and attr or nil
end

-- Distance à plat jusqu'au marchand (nil si inconnue).
local function distanceToMerchant(): number?
	local root = rootPart()
	local target = merchantPosition()
	if not root or not target then
		return nil
	end
	local delta = root.Position - target
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function isNear(): boolean
	local distance = distanceToMerchant()
	-- Le comptoir est ~3 studs devant le centre de l'échoppe : petite marge.
	return distance ~= nil and distance <= EvolutionItems.Merchant.BuyDistance + 3
end

-- Tes unités qui attendent cet objet pour leur prochaine évolution.
local function unitsNeeding(itemId: string): { { name: string, stars: number, amount: number } }
	local result = {}
	local data = State.data
	if not data then
		return result
	end
	for _, entry in data.characters do
		local need = EvolutionItems.requirement(entry)
		if need and need.item == itemId then
			local desc = Formulas.describe(entry)
			table.insert(result, { name = desc and desc.name or "?", stars = entry.stars or 1, amount = need.amount })
		end
	end
	table.sort(result, function(a, b)
		if a.stars ~= b.stars then
			return a.stars > b.stars
		end
		return a.name < b.name
	end)
	return result
end

local function owned(itemId: string): number
	local data = State.data
	local items = data and data.Items
	return type(items) == "table" and (items[itemId] or 0) or 0
end

local function universeName(item): string
	local universe = item.universe and Universes.get(item.universe)
	return universe and universe.name or "Tous les univers"
end

local function universeColor(item): Color3
	local universe = item.universe and Universes.get(item.universe)
	return universe and universe.color or C.Cyan
end

------------------------------------------------------------------------
-- Ligne lumineuse jusqu'au marchand (« Montrer le chemin »)
------------------------------------------------------------------------

local function stopGuide()
	if guide then
		guide.holder:Destroy()
		guide.a0:Destroy()
		guide = nil
	end
end

local function startGuide()
	stopGuide()
	local root = rootPart()
	local target = merchantPosition()
	if not root or not target then
		Notifications.toast("Impossible de trouver le marchand pour l'instant.", "error")
		return
	end
	local holder = new("Part", {
		Name = "MerchantGuide",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(target + Vector3.new(0, 4, 0)),
		Parent = Workspace,
	})
	local a1 = new("Attachment", { Parent = holder })
	local a0 = new("Attachment", { Name = "MerchantGuideStart", Position = Vector3.new(0, -2, 0), Parent = root })
	local beam = new("Beam", {
		Attachment0 = a0,
		Attachment1 = a1,
		Color = ColorSequence.new(WHITE, ACCENT),
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Width0 = 1.2,
		Width1 = 3,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureMode = Enum.TextureMode.Static,
		TextureLength = 6,
		TextureSpeed = 1.5,
		Transparency = NumberSequence.new(0.2),
		Parent = holder,
	})
	guide = { beam = beam, a0 = a0, a1 = a1, holder = holder, endsAt = State.now() + 90 }
	Notifications.toast("Suis la ligne violette jusqu'au Marchand !", "info")
	Menus.close("Shop")
end

------------------------------------------------------------------------
-- Achat
------------------------------------------------------------------------

local function buy(itemId: string)
	local ok, success, message, newState = pcall(function()
		return State.invoke("Merchant_Buy", itemId)
	end)
	if not ok then
		Notifications.toast("Erreur de connexion, réessaie.", "error")
		return
	end
	-- (les erreurs sont déjà annoncées par le serveur)
	if success and message then
		Notifications.toast(message, "success")
		Components.click()
	end
	if type(newState) == "table" then
		shopState = newState
	end
	Shop.render()
end

------------------------------------------------------------------------
-- Rendu
------------------------------------------------------------------------

local function stateItem(itemId: string?)
	if not shopState or not itemId then
		return nil
	end
	for _, entry in shopState.items do
		if entry.id == itemId then
			return entry
		end
	end
	return nil
end

local function itemViewport(parent: Instance, itemId: string, spin: boolean, distance: number?)
	local model = EvolutionItems.build(itemId, 1)
	return Components.viewport(parent, model, Vector3.new(0, 1.35, 0), distance or 7.2, nil, spin)
end

local function smallTag(parent: Instance, text: string, color: Color3, props: { [string]: any })
	local tag = new("Frame", {
		Name = "Tag",
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		ZIndex = 6,
		Parent = parent,
	})
	for key, value in props do
		(tag :: any)[key] = value
	end
	Theme.round().Parent = tag
	Theme.stroke(C.Stroke, 2).Parent = tag
	Theme.gradient({ Theme.light(color, 0.25), Theme.dark(color, 0.2) }, 90).Parent = tag
	Theme.padding(8, 0).Parent = tag
	Theme.label({
		Text = text,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 14,
		FontFace = Theme.Faces.Title,
		ZIndex = 7,
		StrokeThickness = 1.5,
		Parent = tag,
	})
	return tag
end

local function renderGrid()
	local grid = refs.grid
	Components.clear(grid)
	refs.selectedCard = nil
	refs.firstCard = nil
	if not shopState then
		Components.emptyState(grid, "Le marchand déballe sa marchandise…", "shop")
		return
	end
	local coins = State.data and State.data.coins or 0
	for index, entry in shopState.items do
		local item = EvolutionItems.get(entry.id)
		if item then
			local tier = EvolutionItems.Tiers[item.tier]
			local card, preview = Components.itemCard(grid, {
				title = item.name,
				subtitle = "¥ " .. Formulas.formatNumber(item.price),
				subtitleColor = coins >= item.price and C.Gold or Color3.fromRGB(255, 110, 110),
				color = tier.color,
				size = UDim2.fromOffset(136, 186),
				badge = entry.remaining > 0 and ("× " .. entry.remaining) or nil,
				layoutOrder = index,
				selected = entry.id == selectedId,
				selKey = "item_" .. entry.id,
				onClick = function()
					selectedId = entry.id
					Shop.render()
				end,
			})
			itemViewport(preview, entry.id, entry.id == selectedId)
			local face = card:FindFirstChild("Face")
			local tagsHolder = new("Frame", {
				Name = "Tags",
				Position = UDim2.fromOffset(6, 34),
				Size = UDim2.new(1, -12, 0, 24),
				BackgroundTransparency = 1,
				ZIndex = 6,
				Parent = face,
			})
			local list = Theme.list(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Left)
			list.Parent = tagsHolder
			if #unitsNeeding(entry.id) > 0 then
				smallTag(tagsHolder, "UTILE", C.Green, { LayoutOrder = 1 })
			elseif item.signature then
				smallTag(tagsHolder, "SIGNATURE", C.Orange, { LayoutOrder = 2 })
			end
			if entry.remaining <= 0 then
				local soldOut = new("Frame", {
					Name = "SoldOut",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.fromRGB(8, 8, 12),
					BackgroundTransparency = 0.4,
					ZIndex = 8,
					Parent = face,
				})
				Theme.corner(14).Parent = soldOut
				Theme.label({
					Text = "ÉPUISÉ",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.42),
					Size = UDim2.new(0.9, 0, 0, 34),
					Rotation = -12,
					FontFace = Theme.Faces.Title,
					TextColor3 = Color3.fromRGB(255, 110, 110),
					ZIndex = 9,
					Parent = soldOut,
				})
			end
			if entry.id == selectedId then
				refs.selectedCard = card
			end
			refs.firstCard = refs.firstCard or card
		end
	end
end

local function renderDetail()
	local holder = refs.detail
	Components.clear(holder)
	refs.buyButton = nil
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
	local entry = stateItem(selectedId)
	local item = entry and EvolutionItems.get(entry.id)
	if not entry or not item then
		Components.emptyState(sheet, "Choisis un objet.\nIls servent à faire évoluer tes persos (★★, ★★★) !", "evolve").Position = UDim2.new(0, 10, 0.3, 0)
		return
	end
	local tier = EvolutionItems.Tiers[item.tier]
	local data = State.data
	local coins = data and data.coins or 0

	-- En-tête : grand aperçu + nom, palier, univers, possédés.
	local view = new("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(176, 176),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(16).Parent = view
	Theme.stroke(tier.color, 3).Parent = view
	Theme.gradient({ Theme.dark(tier.color, 0.35), Color3.fromRGB(16, 14, 22) }, 90).Parent = view
	Theme.sparkles(view, 6, item.order * 7, 0.6)
	itemViewport(view, item.id, true, 6.4)
	Theme.label({
		Text = item.name,
		Position = UDim2.fromOffset(204, 14),
		Size = UDim2.new(1, -218, 0, 38),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = sheet,
	})
	local tags = new("Frame", { Position = UDim2.fromOffset(204, 58), Size = UDim2.new(1, -218, 0, 26), BackgroundTransparency = 1, Parent = sheet })
	local tagList = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	tagList.Parent = tags
	smallTag(tags, string.upper(tier.name), tier.color, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 24) })
	if item.signature then
		smallTag(tags, "SIGNATURE", C.Orange, { LayoutOrder = 2, Size = UDim2.fromOffset(0, 24) })
	end
	Theme.label({
		Text = universeName(item),
		Position = UDim2.fromOffset(204, 90),
		Size = UDim2.new(1, -218, 0, 22),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(universeColor(item), 0.35),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = sheet,
	})
	Components.pill(sheet, "bag", "Tu en as : × " .. owned(item.id), owned(item.id) > 0 and C.Green or C.Gray, {
		Position = UDim2.fromOffset(204, 122),
		Size = UDim2.fromOffset(210, 32),
	})
	Components.pill(
		sheet,
		"gift",
		entry.remaining > 0 and ("Stock : " .. entry.remaining .. " / " .. entry.stock) or "Épuisé jusqu'au prochain passage",
		entry.remaining > 0 and C.Cyan or C.Red,
		{
			Position = UDim2.fromOffset(204, 158),
			Size = UDim2.new(1, -218, 0, 32),
		}
	)

	-- Corps : description, persos qui l'utilisent, tes unités qui l'attendent.
	local body = Components.scroll(sheet, { Position = UDim2.fromOffset(14, 202), Size = UDim2.new(1, -28, 1, -290) })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left).Parent = body
	Theme.label({
		Text = item.desc,
		Size = UDim2.new(1, -8, 0, 44),
		FontFace = Theme.Faces.Bold,
		TextColor3 = Color3.fromRGB(230, 226, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		StrokeThickness = 1.5,
		MaxSize = 18,
		LayoutOrder = 1,
		Parent = body,
	})
	local waiting = unitsNeeding(item.id)
	if #waiting > 0 then
		Components.sectionTitle(body, "TES UNITÉS QUI EN ONT BESOIN", { LayoutOrder = 2, Size = UDim2.new(1, -8, 0, 22) }, C.Green)
		for i, unit in waiting do
			if i > 4 then
				Components.hintText(body, "… et " .. (#waiting - 4) .. " autre(s)", { LayoutOrder = 3 + i })
				break
			end
			Components.requirement(
				body,
				unit.name .. "  " .. string.rep("★", unit.stars) .. " → " .. string.rep("★", unit.stars + 1) .. "  (× " .. unit.amount .. ")",
				owned(item.id) >= unit.amount,
				2 + i,
				28
			)
		end
	end
	local users = EvolutionItems.usedBy(item.id)
	Components.sectionTitle(body, "SERT À FAIRE ÉVOLUER", { LayoutOrder = 20, Size = UDim2.new(1, -8, 0, 22) })
	Theme.label({
		Text = #users > 0 and table.concat(users, ", ") or "Les persos venus d'autres mondes",
		Size = UDim2.new(1, -8, 0, 40),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		StrokeThickness = 1.2,
		MaxSize = 16,
		LayoutOrder = 21,
		Parent = body,
	})

	-- Pied : prix + bouton (ou « Montrer le chemin » si on est loin).
	local near = isNear()
	local affordable = coins >= item.price
	local canBuy = near and entry.remaining > 0 and affordable
	local price = Components.price(sheet, item.price, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -18),
		Size = UDim2.new(0.38, -14, 0, 46),
	})
	Components.setPriceAffordable(price, affordable)
	local text, color, icon
	if not near then
		text, color, icon = "MONTRER LE CHEMIN", C.Cyan, "pin"
	elseif entry.remaining <= 0 then
		text, color, icon = "ÉPUISÉ", C.Gray, nil
	elseif not affordable then
		text, color, icon = "PAS ASSEZ", Color3.fromRGB(200, 70, 70), "coin"
	else
		text, color, icon = "ACHETER", C.Green, "bag"
	end
	local itemId = item.id
	refs.buyButton = Components.button({
		Text = text,
		Icon = icon,
		Color = color,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.new(0.62, -14, 0, 56),
		TextSize = 24,
		Hint = "A",
		Parent = sheet,
		OnClick = function()
			if not isNear() then
				startGuide()
			elseif canBuy then
				buy(itemId)
			elseif entry.remaining <= 0 then
				Notifications.toast("Rupture de stock : reviens au prochain passage du marchand !", "error")
			else
				Notifications.toast("Il te manque ¥ " .. Formulas.formatNumber(item.price - coins), "error")
			end
		end,
	})
	refs.buyButton.Name = "BuyButton"
end

local function renderTop()
	if not refs.locationPill then
		return
	end
	local distance = distanceToMerchant()
	if isNear() then
		Components.setPillText(refs.locationPill, "Tu es chez le Marchand !")
	elseif distance then
		Components.setPillText(refs.locationPill, "Le Marchand est à " .. math.floor(distance) .. " studs")
	else
		Components.setPillText(refs.locationPill, "Suis le rayon violet !")
	end
	if shopState then
		Components.setPillText(refs.timerPill, "Change de coin dans " .. Formulas.formatTime(math.max(0, shopState.moveAt - State.now())))
	end
	if State.data then
		Components.setPillText(refs.coinsPill, Formulas.formatNumber(State.data.coins))
	end
end

function Shop.render()
	if not window then
		return
	end
	if shopState and not stateItem(selectedId) then
		selectedId = shopState.items[1] and shopState.items[1].id or nil
	end
	Components.preserveSelection(window.content, function()
		renderGrid()
		renderDetail()
	end)
	renderTop()
	local near = isNear()
	window.subtitle.Text = near and "Objets d'évolution : ils font évoluer tes persos (★★, ★★★)" or "Tu regardes son stock de loin : va le voir pour acheter"
end

local function refresh()
	local remote = State.remoteFunction("Merchant_GetStock")
	if not remote then
		return
	end
	local ok, result = pcall(function()
		return remote:InvokeServer()
	end)
	if ok and type(result) == "table" then
		shopState = result
		Shop.render()
	end
end

function Shop.init(gui: ScreenGui)
	window = Components.window(gui, "MARCHAND", ACCENT, UDim2.fromOffset(1140, 640), {
		icon = "shop",
		subtitle = "Objets d'évolution",
	})
	local content = window.content
	local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	local layout = Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = top
	refs.locationPill = Components.pill(top, "pin", "Suis le rayon violet !", ACCENT, { Size = UDim2.fromOffset(360, 36), LayoutOrder = 1 })
	refs.timerPill = Components.pill(top, "hourglass", "Change de coin dans --:--", C.Cyan, { Size = UDim2.fromOffset(330, 36), LayoutOrder = 2 })
	refs.coinsPill = Components.pill(top, "coin", "0", C.Gold, { Size = UDim2.fromOffset(200, 36), LayoutOrder = 3 })

	local left = new("Frame", {
		Name = "Left",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(0.56, -8, 1, -50),
		BackgroundTransparency = 1,
		Parent = content,
	})
	refs.grid = Components.cardGrid(left, Vector2.new(136, 186), { Name = "Grid", Size = UDim2.fromScale(1, 1) }, 12)
	refs.detail = new("Frame", {
		Name = "DetailHolder",
		Position = UDim2.new(0.56, 8, 0, 50),
		Size = UDim2.new(0.44, -8, 1, -50),
		BackgroundTransparency = 1,
		Parent = content,
	})

	Components.registerWindow(Menus, "Shop", window, function(arg)
		if type(arg) == "string" and EvolutionItems.get(arg) then
			selectedId = arg
		end
		Shop.render()
		refresh()
	end, function()
		return refs.selectedCard or refs.firstCard or refs.buyButton or window.firstSelectable()
	end)

	State.onChanged(function()
		if window.isOpen then
			Shop.render()
		end
	end)

	task.spawn(function()
		local wasNear = nil
		while true do
			task.wait(1)
			-- Ligne vers le marchand : s'efface à l'arrivée ou après 90 s.
			if guide then
				local distance = distanceToMerchant()
				if (distance and distance < 24) or State.now() > guide.endsAt or not guide.a0.Parent then
					stopGuide()
				end
			end
			if window.isOpen then
				local near = isNear()
				if shopState and (State.now() >= shopState.moveAt or near ~= wasNear) then
					wasNear = near
					refresh()
				end
				renderTop()
			end
		end
	end)
end

-- Pour les tests : état affiché.
function Shop._state()
	return shopState
end

return Shop
