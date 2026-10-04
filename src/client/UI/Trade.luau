-- ÉCHANGE (ouvert automatiquement quand deux joueurs sont assis à une table d'échange).
-- En haut : les deux offres. En bas : tes unités à proposer, tes matériaux (+ / -), les pièces
-- (boutons rapides utilisables à la manette) et les boutons PRÊT / ANNULER.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.Parent.State)

local Trade = {}

local C = Theme.Colors
local new = Theme.new
local ACCENT = Color3.fromRGB(60, 140, 240)

local window
local refs: { [string]: any } = {}
local trade = nil
local TradeAction = Remotes.event("TradeAction")

local function send(action: string, payload: any?)
	TradeAction:FireServer(action, payload)
end

local function offerColumn(column, side, mine: boolean)
	Components.clear(column.list)
	column.title.Text = mine and "TON OFFRE" or ("OFFRE DE " .. string.upper(side.name))
	column.ready.Visible = side.ready == true
	for i, item in side.characters do
		Components.characterCard(column.list, item.entry, {
			size = UDim2.fromOffset(92, 118),
			layoutOrder = i,
			hideLevel = true,
			onClick = function()
				if mine then
					send("removeCharacter", item.uid)
				end
			end,
		})
	end
	local extras = {}
	for id, amount in side.materials do
		local material = Universes.getMaterial(id)
		table.insert(extras, amount .. " × " .. (material and material.name or id))
	end
	column.coins.Visible = side.coins > 0
	local amount = column.coins:FindFirstChild("Amount") :: TextLabel?
	if amount then
		amount.Text = Formulas.formatNumber(side.coins)
	end
	column.extras.Text = #extras > 0 and table.concat(extras, "  ·  ") or (side.coins > 0 and "" or "Rien pour l'instant")
end

local function render()
	if not trade then
		return
	end
	local mineKey = trade.you
	local otherKey = mineKey == "A" and "B" or "A"
	local mine, other = trade.sides[mineKey], trade.sides[otherKey]
	window.title.Text = "ÉCHANGE AVEC " .. string.upper(other.name)
	offerColumn(refs.mine, mine, true)
	offerColumn(refs.other, other, false)

	-- Inventaire pour ajouter des unités.
	Components.clear(refs.inventory)
	refs.firstCard = nil
	local offered = {}
	for _, item in mine.characters do
		offered[item.uid] = true
	end
	local list = State.sortedCharacters(function(uid, entry)
		return not entry.locked and not offered[uid]
	end)
	for i, item in list do
		if i > 40 then
			break
		end
		local card = Components.characterCard(refs.inventory, item.entry, {
			size = UDim2.fromOffset(92, 118),
			layoutOrder = i,
			inTeam = State.inTeam(item.uid),
			onClick = function()
				send("addCharacter", item.uid)
			end,
		})
		refs.firstCard = refs.firstCard or card
	end

	-- Matériaux (+ / -)
	Components.clear(refs.materials)
	local data = State.data
	local order = 0
	for _, universe in Universes.List do
		local id = universe.material.id
		local owned = data and data.materials[id] or 0
		if owned > 0 then
			order += 1
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, LayoutOrder = order, Parent = refs.materials })
			local current = mine.materials[id] or 0
			Components.gem(row, universe.material.color, 18, UDim2.fromOffset(14, 18))
			Theme.label({
				Text = universe.material.name .. "  " .. current .. " / " .. owned,
				Size = UDim2.new(1, -120, 1, -8),
				Position = UDim2.fromOffset(30, 4),
				FontFace = Theme.Faces.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 1.5,
				Parent = row,
			})
			Components.button({
				Text = "",
				Icon = "minus",
				Color = C.Red,
				Size = UDim2.fromOffset(42, 34),
				Position = UDim2.new(1, -88, 0, 1),
				Parent = row,
				OnClick = function()
					send("setMaterial", { id = id, amount = current - 1 })
				end,
			})
			Components.button({
				Text = "",
				Icon = "plus",
				Color = C.Green,
				Size = UDim2.fromOffset(42, 34),
				Position = UDim2.new(1, -42, 0, 1),
				Parent = row,
				OnClick = function()
					send("setMaterial", { id = id, amount = current + 1 })
				end,
			})
		end
	end
	if order == 0 then
		Components.hintText(refs.materials, "Aucun matériau à proposer.")
	end
	refs.myCoins = mine.coins

	Components.setButtonText(refs.readyButton, mine.ready and "ANNULER PRÊT" or "PRÊT")
	Components.setButtonColor(refs.readyButton, mine.ready and C.Orange or C.Green)
	if trade.state == "countdown" and trade.countdownEnds then
		refs.status.Text = "Échange dans " .. math.max(0, math.ceil(trade.countdownEnds - State.now())) .. "..."
	elseif mine.ready then
		refs.status.Text = "En attente de " .. other.name .. "..."
	else
		refs.status.Text = "Choisis tes unités en bas pour les proposer · choisis ton offre pour la retirer"
	end
end

local function offerSheet(parent: Instance, x: number, color: Color3)
	local sheet = Components.sheet(parent, { Size = UDim2.new(0.5, -6, 0, 236), Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0) })
	local column = { sheet = sheet }
	column.title = Theme.label({
		Text = "OFFRE",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -140, 0, 28),
		FontFace = Theme.Faces.Title,
		TextColor3 = Theme.light(color, 0.3),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sheet,
	})
	column.ready = Components.pill(sheet, "check", "PRÊT", C.Green, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(110, 30) })
	column.ready.Visible = false
	column.list = Components.cardGrid(sheet, Vector2.new(92, 118), { Size = UDim2.new(1, -12, 1, -86), Position = UDim2.fromOffset(6, 40) }, 6)
	column.coins = Components.price(sheet, 0, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10), Size = UDim2.fromOffset(150, 32) })
	column.extras = Theme.label({
		Text = "",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 172, 1, -12),
		Size = UDim2.new(1, -184, 0, 28),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		MaxSize = 18,
		Parent = sheet,
	})
	return column
end

function Trade.init(gui: ScreenGui)
	window = Components.window(gui, "ÉCHANGE", ACCENT, UDim2.fromOffset(1180, 650), { icon = "swap" })
	local content = window.content
	refs.mine = offerSheet(content, 0, C.Green)
	refs.other = offerSheet(content, 0.5, C.Orange)
	refs.status = Theme.label({
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 242),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		StrokeThickness = 1.5,
		MaxSize = 19,
		Parent = content,
	})

	local inventorySheet = Components.sheet(content, { Size = UDim2.new(0.6, -6, 1, -274), Position = UDim2.fromOffset(0, 274) })
	Components.sectionTitle(inventorySheet, "TES UNITÉS (non verrouillées)", { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 6) })
	refs.inventory = Components.cardGrid(inventorySheet, Vector2.new(92, 118), { Size = UDim2.new(1, -12, 1, -34), Position = UDim2.fromOffset(6, 30) }, 6)

	local side = Components.sheet(content, { Size = UDim2.new(0.4, -6, 1, -274), Position = UDim2.new(0.6, 6, 0, 274) })
	Components.sectionTitle(side, "MATÉRIAUX ET PIÈCES", { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 6) })
	refs.materials = Components.scroll(side, { Size = UDim2.new(1, -16, 1, -150), Position = UDim2.fromOffset(8, 30) })
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left).Parent = refs.materials
	-- Pièces : boutons rapides (manette) + saisie libre (clavier)
	local coinsRow = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -66), Size = UDim2.new(1, -20, 0, 44), BackgroundTransparency = 1, Parent = side })
	local layout = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = coinsRow
	refs.myCoins = 0
	for i, step in { 1000, 10000, 100000 } do
		Components.button({
			Text = "+" .. Formulas.formatNumber(step),
			Color = C.Gold,
			Size = UDim2.fromOffset(78, 40),
			TextSize = 17,
			LayoutOrder = i,
			Parent = coinsRow,
			OnClick = function()
				send("setCoins", (refs.myCoins or 0) + step)
			end,
		})
	end
	Components.button({
		Text = "0",
		Color = C.Gray,
		Size = UDim2.fromOffset(44, 40),
		TextSize = 17,
		LayoutOrder = 4,
		Parent = coinsRow,
		OnClick = function()
			send("setCoins", 0)
		end,
	})
	local coinsBox = new("TextBox", {
		Size = UDim2.new(1, -330, 0, 40),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		PlaceholderText = "Montant",
		Text = "",
		TextColor3 = C.Gold,
		PlaceholderColor3 = C.TextDim,
		FontFace = Theme.Faces.Heavy,
		TextScaled = true,
		ClearTextOnFocus = false,
		LayoutOrder = 5,
		Parent = coinsRow,
	})
	Theme.corner(10).Parent = coinsBox
	Theme.stroke(C.Stroke, 2).Parent = coinsBox
	Theme.padding(8, 6).Parent = coinsBox
	coinsBox.FocusLost:Connect(function()
		local amount = tonumber((string.gsub(coinsBox.Text, "[^%d]", "")))
		if amount then
			send("setCoins", amount)
		end
	end)

	refs.readyButton = Components.button({
		Text = "PRÊT",
		Icon = "check",
		Color = C.Green,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(0.55, -14, 0, 48),
		Parent = side,
		OnClick = function()
			local mine = trade and trade.sides[trade.you]
			send("ready", not (mine and mine.ready))
		end,
	})
	Components.button({
		Text = "ANNULER",
		Icon = "close",
		Color = C.Red,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.new(0.45, -6, 0, 48),
		Parent = side,
		OnClick = function()
			send("cancel")
		end,
	})

	local function cancelOnClose()
		Menus.closed("Trade")
		if trade then
			send("cancel")
		end
	end
	window.onClose = cancelOnClose
	Menus.register("Trade", {
		open = function()
			window.open()
			render()
		end,
		close = window.close,
		selection = function()
			return refs.firstCard or window.firstSelectable()
		end,
	})

	Remotes.event("TradeState").OnClientEvent:Connect(function(state)
		trade = state
		if state then
			if not window.isOpen then
				Menus.open("Trade")
			else
				render()
			end
		elseif window.isOpen then
			window.onClose = function()
				Menus.closed("Trade")
			end
			window.close()
			window.onClose = cancelOnClose
		end
	end)
	State.onChanged(function()
		if trade and window.isOpen then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if trade and trade.state == "countdown" and window.isOpen then
				refs.status.Text = "Échange dans " .. math.max(0, math.ceil((trade.countdownEnds or 0) - State.now())) .. "..."
			end
		end
	end)
end

return Trade
