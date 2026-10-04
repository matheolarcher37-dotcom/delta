-- FORGERON (stand du hub) : acheter et équiper des épées pour combattre soi-même.
-- À gauche les épées (prix bien visible), à droite la fiche de l'épée : aperçu 3D, tuiles de
-- statistiques (dégâts, vitesse), portée, effet et bouton ACHETER / ÉQUIPER.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Swords = require(Shared.Config.Swords)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local SwordBuilder = require(Shared.Modules.SwordBuilder)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UnitSheet = require(script.Parent.UnitSheet)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local ForgeMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(240, 110, 40)

local window
local refs: { [string]: any } = {}
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
	local holder = refs.detail
	Components.clear(holder)
	local sword = Swords.get(selected) or Swords.List[1]
	local data = State.data
	local tint = sword.look.trail
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })

	local preview = new("Frame", {
		Size = UDim2.new(0.5, -18, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(12).Parent = preview
	Theme.stroke(Theme.dark(tint, 0.1), 2).Parent = preview
	Theme.gradient({ Color3.fromRGB(30, 30, 40), Color3.fromRGB(14, 14, 20), Theme.dark(tint, 0.55) }, 90).Parent = preview
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.9, 0.6),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = preview,
	})
	Theme.round().Parent = glow
	Theme.gradient({ WHITE, WHITE }, 90, { 0.4, 1 }).Parent = glow
	local view = new("Frame", { Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 70), BackgroundTransparency = 1, ZIndex = 2, Parent = preview })
	swordViewport(view, sword, true).ZIndex = 2
	Theme.label({
		Text = sword.name,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 32),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(tint, 0.45),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = preview,
	})
	Theme.label({
		Text = sword.description,
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 36),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 3,
		StrokeThickness = 1,
		MaxSize = 16,
		Parent = preview,
	})

	local right = new("Frame", { Size = UDim2.new(0.5, -18, 1, -24), Position = UDim2.new(0.5, 6, 0, 12), BackgroundTransparency = 1, Parent = sheet })
	local list = new("Frame", { Size = UDim2.new(1, 0, 0, 2 * 64), BackgroundTransparency = 1, Parent = right })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = list
	UnitSheet.statTile(list, "dmg", Formulas.formatNumber(sword.damage), { LayoutOrder = 1 })
	UnitSheet.statTile(list, "spa", string.format("%.2fs", sword.cooldown), { LayoutOrder = 2 })
	local infos = new("Frame", { Size = UDim2.new(1, 0, 0, 3 * 42), Position = UDim2.fromOffset(0, 2 * 64 + 4), BackgroundTransparency = 1, Parent = right })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = infos
	Components.pill(infos, "star", "Dégâts / s : " .. Formulas.formatNumber(math.floor(sword.damage / sword.cooldown)), C.Red, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 })
	Components.pill(infos, "target", "Portée : " .. tostring(sword.range) .. " studs", C.Blue, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 })
	Components.pill(infos, "bolt", "Effet : " .. (FX_NAMES[sword.fx] or tostring(sword.fx)), tint, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 })

	local isOwned = owned(sword.id)
	local isEquipped = data ~= nil and data.equippedSword == sword.id
	local text, color, icon
	if isEquipped then
		text, color, icon = "ÉQUIPÉE", C.Gray, "check"
	elseif isOwned then
		text, color, icon = "ÉQUIPER", C.Blue, "sword"
	else
		text, color, icon = "ACHETER", C.Green, "coin"
	end
	if not isOwned then
		local price = Components.price(right, sword.price, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -66),
			Size = UDim2.new(1, 0, 0, 42),
		})
		Components.setPriceAffordable(price, data ~= nil and data.coins >= sword.price)
	end
	Components.button({
		Text = text,
		Icon = icon,
		Color = color,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 54),
		Hint = "A",
		Parent = right,
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
	refs.selectedCard = nil
	local data = State.data
	for i, sword in Swords.List do
		local status, statusColor
		if data and data.equippedSword == sword.id then
			status, statusColor = "Équipée", C.Green
		elseif owned(sword.id) then
			status, statusColor = "Possédée", C.Cyan
		else
			status, statusColor = Formulas.formatNumber(sword.price) .. " pièces", (data and data.coins >= sword.price) and C.Gold or Color3.fromRGB(255, 110, 110)
		end
		local card, preview = Components.itemCard(refs.grid, {
			title = sword.name,
			subtitle = status,
			subtitleColor = statusColor,
			color = sword.look.trail,
			layoutOrder = i,
			selected = sword.id == selected,
			selKey = sword.id,
			onClick = function()
				selected = sword.id
				render(true)
			end,
		})
		swordViewport(preview, sword, false)
		if sword.id == selected then
			refs.selectedCard = card
		end
	end
end

local lastKey = ""
render = function(force: boolean?)
	if not window or not window.isOpen then
		return
	end
	local data = State.data
	local parts = { selected, tostring(data and data.equippedSword), tostring(data and math.floor(data.coins)) }
	for id in (data and data.swords) or {} do
		table.insert(parts, id)
	end
	table.sort(parts)
	local key = table.concat(parts, "|")
	if not force and key == lastKey then
		return
	end
	lastKey = key
	Components.preserveSelection(window.content, function()
		renderGrid()
		renderDetail()
	end)
end

function ForgeMenu.init(gui: ScreenGui)
	window = Components.window(gui, "FORGERON", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "forge",
		subtitle = "Touche 1 (manette : LB / RB) pour sortir ton épée",
	})
	local content = window.content
	refs.grid = Components.cardGrid(content, Vector2.new(124, 160), { Name = "Grid", Size = UDim2.new(0.38, -8, 1, 0) }, 10)
	refs.detail = new("Frame", {
		Name = "DetailHolder",
		Size = UDim2.new(0.62, -8, 1, 0),
		Position = UDim2.new(0.38, 8, 0, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Components.registerWindow(Menus, "Forge", window, function()
		local data = State.data
		selected = data and data.equippedSword or Swords.Starter
		render(true)
	end, function()
		return refs.selectedCard or window.firstSelectable()
	end)
	State.onChanged(function()
		render()
	end)
end

return ForgeMenu
