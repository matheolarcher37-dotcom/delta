-- ÉVOLUTION (Autel d'Éveil) : faire évoluer une unité (★ → ★★ → ★★★) avec les matériaux de son
-- univers ET l'objet d'évolution qu'elle demande (vendu par le Marchand ambulant : Boule du Dragon
-- pour Goko, Parchemin d'Ermite pour Maruto...). À gauche les unités (les prêtes d'abord), à droite
-- l'avant / après, les conditions (coches vertes / croix rouges), l'objet requis (possédé, manquant,
-- « chez le marchand »), le prix et le bouton ÉVEILLER.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local EvolutionItems = require(Shared.Config.EvolutionItems)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Evolution = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

local PAGE_SIZE = 12

local window
local refs: { [string]: any } = {}
local selected: string? = nil
local page = 1
local merchantStock: { [string]: number } = {} -- objets en vente chez le marchand (reste en stock)
local merchantWindow = -1

local function ownedItems(data, itemId: string): number
	local items = data and data.Items
	return type(items) == "table" and (items[itemId] or 0) or 0
end

local function isReady(entry): boolean
	local cost = Formulas.evolutionCost(entry)
	return cost ~= nil and entry.level >= cost.levelRequired
end

local function canAfford(entry, data): boolean
	local cost = Formulas.evolutionCost(entry)
	if not cost or entry.level < cost.levelRequired or data.coins < cost.coins then
		return false
	end
	for materialId, amount in cost.materials do
		if (data.materials[materialId] or 0) < amount then
			return false
		end
	end
	local need = EvolutionItems.requirement(entry)
	if need and ownedItems(data, need.item) < need.amount then
		return false
	end
	return true
end

-- Ce que vend le marchand en ce moment (pour dire « en vente maintenant ! »).
local function refreshMerchantStock()
	local remote = State.remoteFunction("Merchant_GetStock")
	if not remote then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer()
		end)
		if ok and type(result) == "table" and type(result.items) == "table" then
			local stock = {}
			for _, entry in result.items do
				stock[entry.id] = entry.remaining
			end
			merchantStock = stock
			merchantWindow = result.window or -1
			if Evolution._rerender then
				Evolution._rerender()
			end
		end
	end)
end

-- Encadré « OBJET REQUIS » : aperçu 3D, nom, quantité, statut et lien vers le marchand.
local function itemBox(parent: Instance, need, data, order: number)
	local item = EvolutionItems.get(need.item)
	if not item then
		return
	end
	local tier = EvolutionItems.Tiers[item.tier]
	local have = ownedItems(data, item.id)
	local ok = have >= need.amount
	local box = new("Frame", {
		Name = "RequiredItem",
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = WHITE,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(12).Parent = box
	Theme.stroke(ok and C.Green or tier.color, 2.5, 0.1).Parent = box
	Theme.gradient({ Theme.dark(ok and C.Green or tier.color, 0.55), Color3.fromRGB(18, 16, 26) }, 0).Parent = box
	local view = new("Frame", {
		Name = "ItemView",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = Color3.fromRGB(14, 12, 20),
		ClipsDescendants = true,
		Parent = box,
	})
	Theme.corner(10).Parent = view
	Theme.stroke(tier.color, 2).Parent = view
	Components.viewport(view, EvolutionItems.build(item.id, 1), Vector3.new(0, 1.35, 0), 6.6, nil, true)
	Theme.label({
		Text = "OBJET REQUIS : " .. need.amount .. " × " .. item.name,
		Position = UDim2.fromOffset(82, 8),
		Size = UDim2.new(1, -96, 0, 26),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		MaxSize = 20,
		Parent = box,
	})
	local status
	local statusColor
	if ok then
		status = "Tu en as " .. have .. " : c'est bon !"
		statusColor = Color3.fromRGB(150, 255, 170)
	elseif (merchantStock[item.id] or 0) > 0 then
		status = "Tu en as " .. have .. " · EN VENTE chez le Marchand en ce moment !"
		statusColor = C.Gold
	else
		status = "Tu en as " .. have .. " · manquant : chez le Marchand ambulant"
		statusColor = Color3.fromRGB(255, 160, 160)
	end
	Theme.label({
		Name = "Status",
		Text = status,
		Position = UDim2.fromOffset(82, 38),
		Size = UDim2.new(1, -96 - (ok and 0 or 120), 0, 22),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = statusColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		MaxSize = 17,
		Parent = box,
	})
	if not ok then
		refs.merchantButton = Components.button({
			Text = "MARCHAND",
			Icon = "shop",
			Color = EvolutionItems.Merchant.Color,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.fromOffset(128, 36),
			TextSize = 15,
			Parent = box,
			OnClick = function()
				Menus.open("Shop", item.id)
			end,
		})
		refs.merchantButton.Name = "MerchantButton"
	end
	return box
end

local function preview(parent: Instance, entry, x: number, starsText: string, tint: Color3)
	local frame = new("Frame", {
		Size = UDim2.new(0.42, 0, 1, 0),
		Position = UDim2.fromScale(x, 0),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = parent,
	})
	Theme.corner(14).Parent = frame
	Theme.stroke(tint, 2.5).Parent = frame
	Theme.gradient({ Color3.fromRGB(34, 34, 46), Color3.fromRGB(16, 16, 22), Theme.dark(tint, 0.6) }, 90).Parent = frame
	local desc = Formulas.describe(entry)
	if desc then
		local holder = new("Frame", { Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, Parent = frame })
		Components.characterViewport(holder, desc.look, true, entry)
	end
	Theme.label({
		Text = starsText,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -10, 0, 26),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		ZIndex = 3,
		Parent = frame,
	})
	return frame
end

local function evolve(uid: string)
	local ok, success, message = pcall(function()
		return Remotes.func("Evolve"):InvokeServer(uid)
	end)
	if ok and message then
		Notifications.toast(message, success and "success" or "error")
	elseif not ok then
		Notifications.toast("Erreur de connexion, réessaie.", "error")
	end
end

local function renderDetail()
	local holder = refs.detail
	Components.clear(holder)
	local data = State.data
	local entry = data and selected and data.characters[selected]
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
	if not entry then
		Components.emptyState(sheet, "Choisis une unité à éveiller.\nLes matériaux viennent des ennemis de son univers !", "evolve").Position = UDim2.new(0, 10, 0.3, 0)
		return
	end
	local desc = Formulas.describe(entry)
	if not desc then
		return
	end
	local info = Theme.rarity(Components.rarityOf(entry, desc))
	local tint = info.rainbow and C.Cyan or info.color
	local cost = Formulas.evolutionCost(entry)

	Theme.label({
		Text = desc.name,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -170, 0, 34),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = sheet,
	})
	Components.rarityTag(sheet, Components.rarityOf(entry, desc), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 18), Size = UDim2.fromOffset(130, 26) })

	-- Avant / après
	local compare = new("Frame", { Size = UDim2.new(1, -32, 0, 150), Position = UDim2.fromOffset(16, 52), BackgroundTransparency = 1, Parent = sheet })
	preview(compare, entry, 0, string.rep("★", entry.stars or 1) .. "  Nv." .. entry.level, tint)
	Components.bigSymbol(compare, "arrowRight", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56) })
	if cost then
		local nextEntry = table.clone(entry)
		nextEntry.stars = cost.stars
		preview(compare, nextEntry, 0.58, string.rep("★", cost.stars) .. "  Nv. max " .. Formulas.levelCap(cost.stars), C.Gold)
	else
		local maxBox = new("Frame", { Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromScale(0.58, 0), BackgroundColor3 = WHITE, Parent = compare })
		Theme.corner(14).Parent = maxBox
		Theme.stroke(C.Gold, 2.5).Parent = maxBox
		Theme.gradient({ Theme.dark(C.Gold, 0.4), Color3.fromRGB(20, 16, 8) }, 90).Parent = maxBox
		Theme.sparkles(maxBox, 6, 9, 0.6)
		Theme.label({
			Text = "MAX\n★★★",
			Size = UDim2.fromScale(0.8, 0.5),
			Position = UDim2.fromScale(0.1, 0.25),
			FontFace = Theme.Faces.Title,
			TextColor3 = C.Gold,
			Parent = maxBox,
		})
	end

	-- Conditions
	local list = new("Frame", { Size = UDim2.new(1, -32, 0, 230), Position = UDim2.fromOffset(16, 210), BackgroundTransparency = 1, Parent = sheet })
	Theme.list(Enum.FillDirection.Vertical, 5, Enum.HorizontalAlignment.Left).Parent = list
	refs.merchantButton = nil
	if not cost then
		Components.hintText(list, "Cette unité est au sommet de sa puissance !", { Size = UDim2.new(1, 0, 0, 30) })
		return
	end
	Components.requirement(list, "Niveau " .. cost.levelRequired .. "  (actuel : " .. entry.level .. ")", entry.level >= cost.levelRequired, 1, 28)
	Components.requirement(list, Formulas.formatNumber(cost.coins) .. " pièces  (tu as " .. Formulas.formatNumber(data.coins) .. ")", data.coins >= cost.coins, 2, 28)
	local order = 2
	for materialId, amount in cost.materials do
		order += 1
		local material = Universes.getMaterial(materialId)
		local owned = data.materials[materialId] or 0
		Components.requirement(list, amount .. " × " .. (material and material.name or materialId) .. "  (tu as " .. owned .. ")", owned >= amount, order, 28)
	end
	local need = EvolutionItems.requirement(entry)
	if need then
		itemBox(list, need, data, 20)
	end
	local nextEntry = table.clone(entry)
	nextEntry.stars = cost.stars
	Components.pill(
		sheet,
		"sword",
		"Puissance " .. Formulas.formatNumber(Formulas.power(entry)) .. "  →  " .. Formulas.formatNumber(Formulas.power(nextEntry)),
		C.Green,
		{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -76), Size = UDim2.new(1, -32, 0, 32) }
	)
	local can = canAfford(entry, data)
	local uid = selected :: string
	local button = Components.button({
		Text = "ÉVEILLER",
		Icon = "evolve",
		Color = can and C.Purple or C.Gray,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.new(0.62, -16, 0, 54),
		Hint = "A",
		Parent = sheet,
		OnClick = function()
			evolve(uid)
		end,
	})
	refs.evolveButton = button
	local price = Components.price(sheet, cost.coins, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -20),
		Size = UDim2.new(0.38, -10, 0, 42),
	})
	Components.setPriceAffordable(price, data.coins >= cost.coins)
end

local function renderList()
	Components.clear(refs.list)
	refs.selectedCard = nil
	local list = State.sortedCharacters()
	table.sort(list, function(a, b)
		local ra, rb = isReady(a.entry), isReady(b.entry)
		if ra ~= rb then
			return ra
		end
		local ma, mb = Formulas.evolutionCost(a.entry) == nil, Formulas.evolutionCost(b.entry) == nil
		if ma ~= mb then
			return mb
		end
		if a.power == b.power then
			return a.uid < b.uid
		end
		return a.power > b.power
	end)
	local data = State.data
	if selected and data and not data.characters[selected] then
		selected = nil
	end
	if not selected and list[1] then
		selected = list[1].uid
	end
	local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
	page = math.clamp(page, 1, pages)
	refs.pager.set(page, pages)
	refs.list.Size = UDim2.new(1, 0, 1, pages > 1 and -50 or 0)
	local ready = 0
	for _, item in list do
		if isReady(item.entry) then
			ready += 1
		end
	end
	window.subtitle.Text = ready > 0 and (ready .. " unité(s) prête(s) à évoluer !") or "Monte le niveau de tes unités pour les faire évoluer"
	if #list == 0 then
		Components.emptyState(refs.list, "Aucune unité. Roule à la machine ROULER !", "dice")
	end
	for i = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[i]
		local card = Components.characterCard(refs.list, item.entry, {
			selKey = item.uid,
			selected = item.uid == selected,
			layoutOrder = i,
			onClick = function()
				selected = item.uid
				renderList()
				renderDetail()
			end,
		})
		if item.uid == selected then
			refs.selectedCard = card
		end
		if isReady(item.entry) then
			local ribbon = new("Frame", {
				Name = "Ready",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -16, 0, 24),
				BackgroundColor3 = WHITE,
				ZIndex = 6,
				Parent = card,
			})
			Theme.corner(8).Parent = ribbon
			Theme.stroke(C.Stroke, 2).Parent = ribbon
			Theme.gradient({ Color3.fromRGB(120, 255, 140), Color3.fromRGB(30, 170, 70) }, 90).Parent = ribbon
			Theme.label({ Text = "PRÊT !", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), FontFace = Theme.Faces.Title, ZIndex = 7, Parent = ribbon })
		end
	end
end

function Evolution.init(gui: ScreenGui)
	window = Components.window(gui, "ÉVOLUTION", C.Purple, UDim2.fromOffset(1180, 640), { icon = "evolve", subtitle = "" })
	local content = window.content
	local left = new("Frame", { Name = "Left", Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	refs.list = Components.cardGrid(left, Vector2.new(124, 160), { Name = "Grid", Size = UDim2.new(1, 0, 1, -50) }, 10)
	refs.pager = Components.pager(left, { Position = UDim2.new(0, 0, 1, -44) }, function(target)
		page = target
		renderList()
	end)
	refs.detail = new("Frame", {
		Name = "DetailHolder",
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.new(0.5, 8, 0, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})

	Components.registerWindow(Menus, "Evolution", window, function(arg)
		if type(arg) == "string" then
			selected = arg
			page = 1
		end
		refreshMerchantStock()
		renderList()
		renderDetail()
	end, function()
		return refs.selectedCard or window.firstSelectable()
	end)
	Evolution._rerender = function()
		if window.isOpen then
			Components.preserveSelection(window.content, function()
				renderList()
				renderDetail()
			end)
		end
	end
	local lastKey = ""
	State.onChanged(function(data)
		if not window.isOpen then
			return
		end
		local parts = { tostring(selected), tostring(math.floor(data.coins / 1000)) }
		for uid, entry in data.characters do
			table.insert(parts, uid .. ":" .. entry.level .. ":" .. entry.stars)
		end
		for id, count in data.materials do
			table.insert(parts, id .. "=" .. count)
		end
		if type(data.Items) == "table" then
			for id, count in data.Items do
				table.insert(parts, "item_" .. id .. "=" .. count)
			end
		end
		table.insert(parts, "w" .. merchantWindow)
		table.sort(parts)
		local key = table.concat(parts, "|")
		if key ~= lastKey then
			lastKey = key
			-- La carte choisie à la manette reste sélectionnée après la reconstruction.
			Components.preserveSelection(window.content, function()
				renderList()
				renderDetail()
			end)
		end
	end)
end

return Evolution
