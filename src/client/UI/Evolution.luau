-- Autel d'Éveil : faire évoluer un perso (★ → ★★ → ★★★) avec les matériaux de son univers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Universes = require(Shared.Config.Universes)
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

local window
local refs = {}
local selected: string? = nil

local function isReady(entry): boolean
	local cost = Formulas.evolutionCost(entry)
	return cost ~= nil and entry.level >= cost.levelRequired
end

local function renderDetail()
	local panel = refs.detail
	Components.clear(panel)
	local data = State.data
	local entry = data and selected and data.characters[selected]
	if not entry then
		Theme.label({ Text = "Choisis un perso à éveiller.\nLes matériaux viennent des ennemis de son univers !", Size = UDim2.new(1, -20, 0, 80), Position = UDim2.new(0, 10, 0.4, 0), TextColor3 = C.TextDim, TextWrapped = true, Parent = panel })
		return
	end
	local desc = Formulas.describe(entry)
	local cost = Formulas.evolutionCost(entry)
	local rarity = Rarities.get(desc.rarity)
	Theme.label({ Text = desc.name, Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 4), Font = Theme.Fonts.Title, TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.3), Parent = panel })

	-- Avant / après
	local compare = new("Frame", { Size = UDim2.new(1, -16, 0.42, 0), Position = UDim2.fromOffset(8, 44), BackgroundTransparency = 1, Parent = panel })
	local function preview(look, x: number, title: string)
		local frame = new("Frame", { Size = UDim2.fromScale(0.44, 1), Position = UDim2.fromScale(x, 0), BackgroundColor3 = C.PanelDark, Parent = compare })
		Theme.corner(12).Parent = frame
		Theme.stroke(rarity.color, 2).Parent = frame
		Components.characterViewport(frame, look, true)
		Theme.label({ Text = title, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -26), TextColor3 = C.Gold, Parent = frame })
	end
	preview(desc.look, 0, string.rep("★", entry.stars))
	Theme.label({ Text = "➜", Size = UDim2.fromScale(0.12, 0.3), Position = UDim2.fromScale(0.44, 0.35), Font = Theme.Fonts.Title, Parent = compare })
	if cost then
		local nextEntry = table.clone(entry)
		nextEntry.stars = cost.stars
		local nextDesc = Formulas.describe(nextEntry)
		preview(nextDesc.look, 0.56, string.rep("★", cost.stars))
	else
		Theme.label({ Text = "MAX ★★★", Size = UDim2.fromScale(0.44, 0.3), Position = UDim2.fromScale(0.56, 0.35), Font = Theme.Fonts.Title, TextColor3 = C.Gold, Parent = compare })
	end

	local y = 0.52
	local function requirement(text: string, ok: boolean)
		Theme.label({ Text = (ok and "✅ " or "❌ ") .. text, Size = UDim2.new(1, -24, 0.055, 0), Position = UDim2.new(0, 12, y, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ok and C.Text or Color3.fromRGB(255, 160, 160), Parent = panel })
		y += 0.06
	end
	if not cost then
		Theme.label({ Text = "Ce perso est au sommet de sa puissance !", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, y, 0), TextColor3 = C.TextDim, Parent = panel })
		return
	end
	requirement("Niveau " .. cost.levelRequired .. " (actuel : " .. entry.level .. ")", entry.level >= cost.levelRequired)
	requirement("💰 " .. Formulas.formatNumber(cost.coins), data.coins >= cost.coins)
	local allMaterials = true
	for materialId, amount in cost.materials do
		local material = Universes.getMaterial(materialId)
		local owned = data.materials[materialId] or 0
		allMaterials = allMaterials and owned >= amount
		requirement(amount .. " × " .. (material and material.name or materialId) .. " (" .. owned .. ")", owned >= amount)
	end
	local nextEntry = table.clone(entry)
	nextEntry.stars = cost.stars
	Theme.label({
		Text = "⚔️ " .. Formulas.formatNumber(Formulas.power(entry)) .. " ➜ " .. Formulas.formatNumber(Formulas.power(nextEntry)) .. "   ·   Niveau max " .. Formulas.levelCap(cost.stars),
		Size = UDim2.new(1, -24, 0.055, 0),
		Position = UDim2.new(0, 12, y, 0),
		TextColor3 = C.Green,
		Parent = panel,
	})
	local can = entry.level >= cost.levelRequired and data.coins >= cost.coins and allMaterials
	local uid = selected :: string
	Components.button({
		Text = "✨ ÉVEILLER",
		Color = can and C.Purple or Color3.fromRGB(110, 110, 120),
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.new(0, 12, 1, -58),
		Parent = panel,
		OnClick = function()
			local ok, success, message = pcall(function()
				return Remotes.func("Evolve"):InvokeServer(uid)
			end)
			if ok and message then
				Notifications.toast(message, success and "success" or "error")
			end
		end,
	})
end

local function renderList()
	Components.clear(refs.list)
	local list = State.sortedCharacters()
	table.sort(list, function(a, b)
		local ra, rb = isReady(a.entry), isReady(b.entry)
		if ra ~= rb then
			return ra
		end
		return a.power > b.power
	end)
	for i, item in list do
		if i > 40 then
			break
		end
		local card = Components.characterCard(refs.list, item.entry, {
			size = UDim2.fromOffset(104, 132),
			selected = item.uid == selected,
			layoutOrder = i,
			onClick = function()
				selected = item.uid
				renderList()
				renderDetail()
			end,
		})
		if isReady(item.entry) then
			Theme.label({ Text = "PRÊT ✨", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0.45, 0), TextColor3 = C.Green, Parent = card })
		end
	end
end

function Evolution.init(gui: ScreenGui)
	window = Components.window(gui, "✨ AUTEL D'ÉVEIL", C.Purple)
	refs.list = new("ScrollingFrame", {
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.content,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 132), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.list })
	Theme.padding(6).Parent = refs.list
	refs.detail = new("Frame", {
		Size = UDim2.new(0.49, 0, 1, 0),
		Position = UDim2.fromScale(0.51, 0),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		Parent = window.content,
	})
	Theme.corner(14).Parent = refs.detail
	Theme.stroke(C.Stroke, 3).Parent = refs.detail

	window.onClose = function()
		Menus.closed("Evolution")
	end
	Menus.register("Evolution", {
		open = function()
			window.open()
			renderList()
			renderDetail()
		end,
		close = window.close,
	})
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
		table.sort(parts)
		local key = table.concat(parts, "|")
		if key ~= lastKey then
			lastKey = key
			renderList()
			renderDetail()
		end
	end)
end

return Evolution
