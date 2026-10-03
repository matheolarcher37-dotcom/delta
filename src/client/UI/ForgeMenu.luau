-- Le Forgeron (stand du hub) : acheter et équiper des épées pour combattre soi-même.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Swords = require(Shared.Config.Swords)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local SwordBuilder = require(Shared.Modules.SwordBuilder)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local ForgeMenu = {}

local C = Theme.Colors
local new = Theme.new

local window
local refs = {}
local selected: string = Swords.Starter
local render: (boolean?) -> ()

local FX_NAMES = {
	slash = "Entaille",
	wind = "Rafale de vent",
	lightning = "Éclair",
	flame = "Flammes",
	mist = "Brume tranchante",
	shadow = "Fumée noire",
	ice = "Cristaux de glace",
}

local function swordViewport(parent: Instance, sword, spin: boolean?)
	local model = SwordBuilder.buildModel(sword)
	local length = sword.look.length + 1.5
	return Components.viewport(parent, model, Vector3.new(0, length * 0.42, 0), length * 2.2, nil, spin)
end

local function owned(id: string): boolean
	local data = State.data
	return data ~= nil and data.swords ~= nil and data.swords[id] == true
end

local function renderDetail()
	local panel = refs.detail
	Components.clear(panel)
	local sword = Swords.get(selected) or Swords.List[1]
	local data = State.data
	local preview = new("Frame", { Size = UDim2.new(1, -16, 0.42, 0), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = C.PanelDark, Parent = panel })
	Theme.corner(12).Parent = preview
	Theme.gradient({ sword.look.trail:Lerp(Color3.new(0, 0, 0), 0.55), C.PanelDark }, 90).Parent = preview
	swordViewport(preview, sword, true)
	Theme.label({
		Text = "🗡️ " .. sword.name,
		Size = UDim2.new(1, -16, 0.07, 0),
		Position = UDim2.new(0, 8, 0.44, 0),
		Font = Theme.Fonts.Title,
		TextColor3 = sword.look.trail:Lerp(Color3.new(1, 1, 1), 0.4),
		Parent = panel,
	})
	Theme.label({
		Text = sword.description,
		Size = UDim2.new(1, -16, 0.06, 0),
		Position = UDim2.new(0, 8, 0.51, 0),
		Font = Theme.Fonts.Small,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		Parent = panel,
	})
	local dps = sword.damage / sword.cooldown
	local lines = {
		{ "⚔️ Dégâts", Formulas.formatNumber(sword.damage) },
		{ "⏱️ Vitesse", string.format("%.2f s", sword.cooldown) },
		{ "💥 Dégâts / s", Formulas.formatNumber(math.floor(dps)) },
		{ "📏 Portée", tostring(sword.range) .. " studs" },
		{ "✨ Effet", FX_NAMES[sword.fx] or sword.fx },
	}
	for i, line in lines do
		local y = 0.585 + (i - 1) * 0.055
		Theme.label({
			Text = line[1],
			Size = UDim2.new(0.5, -8, 0.05, 0),
			Position = UDim2.new(0, 10, y, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.Body,
			Parent = panel,
		})
		Theme.label({
			Text = line[2],
			Size = UDim2.new(0.5, -10, 0.05, 0),
			Position = UDim2.new(0.5, 0, y, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Theme.Fonts.Body,
			TextColor3 = C.Gold,
			Parent = panel,
		})
	end
	local isOwned = owned(sword.id)
	local isEquipped = data ~= nil and data.equippedSword == sword.id
	local text, color
	if isEquipped then
		text, color = "✅ ÉQUIPÉE", C.PanelLight
	elseif isOwned then
		text, color = "ÉQUIPER", C.Blue
	else
		text, color = "ACHETER · 💰 " .. Formulas.formatNumber(sword.price), C.Green
	end
	Components.button({
		Text = text,
		Color = color,
		Size = UDim2.new(1, -16, 0, 48),
		Position = UDim2.new(0, 8, 1, -56),
		Parent = panel,
		OnClick = function()
			if isEquipped then
				return
			end
			local remote = isOwned and "EquipSword" or "BuySword"
			local ok, success, message = pcall(function()
				return Remotes.func(remote):InvokeServer(sword.id)
			end)
			if ok and message then
				Notifications.toast(message, success and "success" or "error")
			end
			render(true)
		end,
	})
end

local function renderGrid()
	Components.clear(refs.grid)
	local data = State.data
	for i, sword in Swords.List do
		local card = new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = sword.id == selected and C.PanelLight or C.Panel,
			LayoutOrder = i,
			Parent = refs.grid,
		})
		Theme.corner(12).Parent = card
		Theme.stroke(sword.id == selected and C.Gold or sword.look.trail:Lerp(C.Stroke, 0.4), sword.id == selected and 3 or 2).Parent = card
		local holder = new("Frame", { Size = UDim2.new(1, -8, 0.62, 0), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Parent = card })
		swordViewport(holder, sword, false)
		Theme.label({ Text = sword.name, Size = UDim2.new(1, -8, 0.16, 0), Position = UDim2.new(0, 4, 0.63, 0), Font = Theme.Fonts.Body, TextScaled = true, Parent = card })
		local status
		if data and data.equippedSword == sword.id then
			status = "✅ Équipée"
		elseif owned(sword.id) then
			status = "Possédée"
		else
			status = "💰 " .. Formulas.formatNumber(sword.price)
		end
		Theme.label({ Text = status, Size = UDim2.new(1, -8, 0.15, 0), Position = UDim2.new(0, 4, 0.81, 0), Font = Theme.Fonts.Small, TextColor3 = C.Gold, Parent = card })
		card.MouseButton1Click:Connect(function()
			Components.click()
			selected = sword.id
			render(true)
		end)
	end
end

local lastKey = ""
render = function(force: boolean?)
	if not window or not window.isOpen then
		return
	end
	local data = State.data
	local parts = { selected, tostring(data and data.equippedSword), tostring(data and data.coins) }
	for id in (data and data.swords) or {} do
		table.insert(parts, id)
	end
	table.sort(parts)
	local key = table.concat(parts, "|")
	if not force and key == lastKey then
		return
	end
	lastKey = key
	renderGrid()
	renderDetail()
end

function ForgeMenu.init(gui: ScreenGui)
	window = Components.window(gui, "🗡️ LE FORGERON", C.Orange)
	local content = window.content
	Theme.label({
		Text = "Achète une épée et frappe toi-même les ennemis (touche 1 pour la sortir, clic pour frapper) !",
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Small,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		Parent = content,
	})
	refs.grid = new("ScrollingFrame", {
		Size = UDim2.new(0.55, 0, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(120, 140), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.grid })
	Theme.padding(6).Parent = refs.grid
	refs.detail = new("Frame", {
		Size = UDim2.new(0.44, 0, 1, -40),
		Position = UDim2.new(0.56, 0, 0, 40),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		Parent = content,
	})
	Theme.corner(14).Parent = refs.detail
	Theme.stroke(C.Stroke, 3).Parent = refs.detail

	window.onClose = function()
		Menus.closed("Forge")
	end
	Menus.register("Forge", {
		open = function()
			local data = State.data
			selected = data and data.equippedSword or Swords.Starter
			window.open()
			render(true)
		end,
		close = window.close,
	})
	State.onChanged(function()
		render()
	end)
end

return ForgeMenu
