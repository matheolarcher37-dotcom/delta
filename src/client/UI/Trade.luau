-- Interface d'échange (ouverte automatiquement quand deux joueurs sont assis à une table d'échange).

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

local window
local refs = {}
local trade = nil
local TradeAction = Remotes.event("TradeAction")

local function send(action: string, payload: any?)
	TradeAction:FireServer(action, payload)
end

local function offerColumn(parent: Instance, side, mine: boolean)
	Components.clear(parent)
	Theme.label({
		Text = (mine and "TON OFFRE" or ("OFFRE DE " .. string.upper(side.name))) .. (side.ready and "  ✅ PRÊT" or ""),
		Size = UDim2.new(1, -10, 0, 26),
		Position = UDim2.fromOffset(5, 4),
		TextColor3 = side.ready and C.Green or C.Text,
		Font = Theme.Fonts.Title,
		Parent = parent,
	})
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -10, 1, -70),
		Position = UDim2.fromOffset(5, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(88, 112), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, item in side.characters do
		Components.characterCard(list, item.entry, {
			size = UDim2.fromOffset(88, 112),
			layoutOrder = i,
			onClick = function()
				if mine then
					send("removeCharacter", item.uid)
				end
			end,
		})
	end
	local extras = {}
	if side.coins > 0 then
		table.insert(extras, "💰 " .. Formulas.formatNumber(side.coins))
	end
	for id, amount in side.materials do
		local material = Universes.getMaterial(id)
		table.insert(extras, amount .. " × " .. (material and material.name or id))
	end
	Theme.label({
		Text = #extras > 0 and table.concat(extras, "  ·  ") or "—",
		Size = UDim2.new(1, -10, 0, 28),
		Position = UDim2.new(0, 5, 1, -32),
		TextColor3 = C.Gold,
		TextWrapped = true,
		Parent = parent,
	})
end

local function render()
	if not trade then
		return
	end
	local mineKey = trade.you
	local otherKey = mineKey == "A" and "B" or "A"
	local mine, other = trade.sides[mineKey], trade.sides[otherKey]
	window.title.Text = "🤝 ÉCHANGE AVEC " .. string.upper(other.name)
	offerColumn(refs.mine, mine, true)
	offerColumn(refs.other, other, false)

	-- Inventaire pour ajouter des persos.
	Components.clear(refs.inventory)
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
		Components.characterCard(refs.inventory, item.entry, {
			size = UDim2.fromOffset(84, 108),
			layoutOrder = i,
			inTeam = State.inTeam(item.uid),
			onClick = function()
				send("addCharacter", item.uid)
			end,
		})
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
			local row = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Parent = refs.materials })
			local current = mine.materials[id] or 0
			Theme.label({ Text = universe.material.name .. " : " .. current .. "/" .. owned, Size = UDim2.new(1, -80, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Fonts.Small, Parent = row })
			Components.button({ Text = "-", Color = C.Red, Size = UDim2.fromOffset(34, 30), Position = UDim2.new(1, -74, 0, 1), Parent = row, OnClick = function()
				send("setMaterial", { id = id, amount = current - 1 })
			end })
			Components.button({ Text = "+", Color = C.Green, Size = UDim2.fromOffset(34, 30), Position = UDim2.new(1, -36, 0, 1), Parent = row, OnClick = function()
				send("setMaterial", { id = id, amount = current + 1 })
			end })
		end
	end

	Components.setButtonText(refs.readyButton, mine.ready and "Annuler Prêt" or "✅ PRÊT")
	Components.setButtonColor(refs.readyButton, mine.ready and C.Orange or C.Green)
	if trade.state == "countdown" and trade.countdownEnds then
		refs.status.Text = "⏳ Échange dans " .. math.max(0, math.ceil(trade.countdownEnds - State.now())) .. "..."
	elseif mine.ready then
		refs.status.Text = "En attente de " .. other.name .. "..."
	else
		refs.status.Text = "Clique sur tes persos pour les proposer. Clique sur ton offre pour retirer."
	end
end

function Trade.init(gui: ScreenGui)
	window = Components.window(gui, "🤝 ÉCHANGE", C.Orange, UDim2.fromScale(0.8, 0.8))
	local content = window.content
	local function column(x: number)
		local frame = new("Frame", { Size = UDim2.new(0.49, 0, 0.42, 0), Position = UDim2.fromScale(x, 0), BackgroundColor3 = C.PanelDark, BackgroundTransparency = 0.2, Parent = content })
		Theme.corner(12).Parent = frame
		Theme.stroke(C.Stroke, 3).Parent = frame
		return frame
	end
	refs.mine = column(0)
	refs.other = column(0.51)
	refs.status = Theme.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromScale(0, 0.43), TextColor3 = C.TextDim, Parent = content })
	refs.inventory = new("ScrollingFrame", {
		Size = UDim2.new(0.6, 0, 0.4, 0),
		Position = UDim2.fromScale(0, 0.48),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Theme.corner(12).Parent = refs.inventory
	new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 108), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.inventory })
	Theme.padding(6).Parent = refs.inventory

	local side = new("Frame", { Size = UDim2.new(0.38, 0, 0.4, 0), Position = UDim2.fromScale(0.62, 0.48), BackgroundTransparency = 1, Parent = content })
	refs.materials = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = side,
	})
	Theme.list(Enum.FillDirection.Vertical, 4).Parent = refs.materials
	local coinsBox = new("TextBox", {
		Size = UDim2.new(0.6, 0, 0, 38),
		Position = UDim2.new(0, 0, 1, -40),
		BackgroundColor3 = C.PanelDark,
		PlaceholderText = "💰 Pièces à donner",
		Text = "",
		TextColor3 = C.Gold,
		PlaceholderColor3 = C.TextDim,
		Font = Theme.Fonts.Body,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = side,
	})
	Theme.corner(10).Parent = coinsBox
	Theme.stroke(C.Stroke, 2).Parent = coinsBox
	Components.button({ Text = "OK", Color = C.Blue, Size = UDim2.new(0.37, 0, 0, 38), Position = UDim2.new(0.63, 0, 1, -40), Parent = side, OnClick = function()
		local amount = tonumber((string.gsub(coinsBox.Text, "[^%d]", ""))) or 0
		send("setCoins", amount)
	end })

	refs.readyButton = Components.button({
		Text = "✅ PRÊT",
		Color = C.Green,
		Size = UDim2.new(0.48, 0, 0, 50),
		Position = UDim2.new(0, 0, 1, -52),
		Parent = content,
		OnClick = function()
			local mine = trade and trade.sides[trade.you]
			send("ready", not (mine and mine.ready))
		end,
	})
	Components.button({
		Text = "Annuler l'échange",
		Color = C.Red,
		Size = UDim2.new(0.48, 0, 0, 50),
		Position = UDim2.new(0.52, 0, 1, -52),
		Parent = content,
		OnClick = function()
			send("cancel")
		end,
	})

	window.onClose = function()
		Menus.closed("Trade")
		if trade then
			send("cancel")
		end
	end
	Menus.register("Trade", {
		open = function()
			window.open()
			render()
		end,
		close = window.close,
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
			window.onClose = function()
				Menus.closed("Trade")
				if trade then
					send("cancel")
				end
			end
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
				refs.status.Text = "⏳ Échange dans " .. math.max(0, math.ceil((trade.countdownEnds or 0) - State.now())) .. "..."
			end
		end
	end)
end

return Trade
