-- Portail Crossover : fusionner deux persos de deux univers différents (la "pépite").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Fusion = {}

local C = Theme.Colors
local new = Theme.new

local window
local refs = {}
local slotA: string? = nil
local slotB: string? = nil
local activeSlot = "A"

local function eligible(entry): boolean
	if entry.fusion then
		return false
	end
	local desc = Formulas.describe(entry)
	return desc ~= nil and (entry.stars or 1) >= Economy.Fusion.minStars and Rarities.get(desc.rarity).order >= Economy.Fusion.minRarityOrder
end

local render

local function slotFrame(parent: Instance, x: number, uid: string?, label: string)
	local data = State.data
	local entry = data and uid and data.characters[uid]
	local frame = new("TextButton", {
		Size = UDim2.fromScale(0.3, 1),
		Position = UDim2.fromScale(x, 0),
		BackgroundColor3 = C.PanelDark,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	})
	Theme.corner(14).Parent = frame
	Theme.stroke(activeSlot == label and C.Gold or C.Stroke, activeSlot == label and 4 or 3).Parent = frame
	if entry then
		local desc = Formulas.describe(entry)
		Components.characterViewport(frame, desc.look, true)
		Theme.label({ Text = desc.name, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -28), Parent = frame })
		local universe = Universes.get(desc.universe)
		Theme.label({
			Text = universe and universe.name or "",
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 6),
			TextColor3 = universe and universe.color or C.TextDim,
			Font = Theme.Fonts.Small,
			Parent = frame,
		})
	else
		Theme.label({
			Text = "Perso " .. label .. "\n(clique puis choisis)",
			Size = UDim2.new(1, -16, 0, 60),
			Position = UDim2.new(0, 8, 0.4, 0),
			TextColor3 = C.TextDim,
			TextWrapped = true,
			Parent = frame,
		})
	end
	frame.Activated:Connect(function()
		Components.click()
		activeSlot = label
		render()
	end)
end

render = function()
	if not window or not window.isOpen then
		return
	end
	local data = State.data
	if not data then
		return
	end
	if slotA and not data.characters[slotA] then
		slotA = nil
	end
	if slotB and not data.characters[slotB] then
		slotB = nil
	end

	-- Emplacements + résultat
	Components.clear(refs.top)
	slotFrame(refs.top, 0, slotA, "A")
	Theme.label({ Text = "+", Size = UDim2.fromScale(0.05, 0.3), Position = UDim2.fromScale(0.3, 0.35), Font = Theme.Fonts.Title, Parent = refs.top })
	slotFrame(refs.top, 0.35, slotB, "B")
	Theme.label({ Text = "=", Size = UDim2.fromScale(0.05, 0.3), Position = UDim2.fromScale(0.65, 0.35), Font = Theme.Fonts.Title, Parent = refs.top })
	local result = new("Frame", { Size = UDim2.fromScale(0.3, 1), Position = UDim2.fromScale(0.7, 0), BackgroundColor3 = C.PanelDark, Parent = refs.top })
	Theme.corner(14).Parent = result
	local resultStroke = Theme.stroke(Rarities.get("crossover").color, 4)
	resultStroke.Parent = result
	Theme.gradient(Rarities.get("crossover").gradient, 45).Parent = resultStroke

	local entryA = slotA and data.characters[slotA]
	local entryB = slotB and data.characters[slotB]
	local message = nil
	if entryA and entryB then
		local preview = { id = "fusion", fusion = { a = entryA.id, b = entryB.id }, level = 1, xp = 0, stars = 1 }
		local desc = Formulas.describe(preview)
		if desc then
			Components.characterViewport(result, desc.look, true)
			Theme.label({ Text = desc.name, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -28), Font = Theme.Fonts.Title, Parent = result })
			Theme.label({
				Text = "⚔️ " .. Formulas.formatNumber(Formulas.power(preview)) .. " (niv. 1)",
				Size = UDim2.new(1, -8, 0, 18),
				Position = UDim2.fromOffset(4, 6),
				TextColor3 = C.Green,
				Font = Theme.Fonts.Small,
				Parent = result,
			})
		end
		local da, db = Formulas.describe(entryA), Formulas.describe(entryB)
		if da.universe == db.universe then
			message = "❌ Les deux persos doivent venir d'univers différents !"
		end
	else
		Theme.label({ Text = "?", Size = UDim2.fromScale(0.5, 0.4), Position = UDim2.fromScale(0.25, 0.3), Font = Theme.Fonts.Title, TextColor3 = C.TextDim, Parent = result })
	end

	-- Conditions
	Components.clear(refs.info)
	local rule = Economy.Fusion
	local lines = {
		"Règles : 2 persos d'UNIVERS DIFFÉRENTS, Épique ou mieux, évolués au moins ★★.",
		"Coût : 💰 " .. Formulas.formatNumber(rule.coins) .. " + " .. rule.materials .. " matériaux de chaque univers.",
		"Le Crossover hérite de la meilleure aura et peut évoluer jusqu'à ★★★ !",
	}
	if entryA and entryB then
		for _, entry in { entryA, entryB } do
			local desc = Formulas.describe(entry)
			local material = Universes.get(desc.universe).material
			local owned = data.materials[material.id] or 0
			table.insert(lines, (owned >= rule.materials and "✅ " or "❌ ") .. rule.materials .. " × " .. material.name .. " (" .. owned .. ")")
		end
		table.insert(lines, (data.coins >= rule.coins and "✅ " or "❌ ") .. "💰 " .. Formulas.formatNumber(rule.coins))
	end
	if message then
		table.insert(lines, message)
	end
	for i, text in lines do
		local label = Theme.label({
			Text = text,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, (i - 1) * 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = i <= 3 and C.TextDim or C.Text,
			Font = Theme.Fonts.Small,
			Parent = refs.info,
		})
		new("UITextSizeConstraint", { MaxTextSize = 16, Parent = label })
	end

	-- Liste des persos éligibles
	Components.clear(refs.list)
	local list = State.sortedCharacters(function(_, entry)
		return eligible(entry)
	end)
	if #list == 0 then
		Theme.label({
			Text = "Aucun perso éligible : fais évoluer des persos Épiques ou mieux au rang ★★ à l'Autel d'Éveil !",
			Size = UDim2.new(1, -10, 0, 50),
			TextColor3 = C.TextDim,
			TextWrapped = true,
			Parent = refs.list,
		})
	end
	for i, item in list do
		Components.characterCard(refs.list, item.entry, {
			size = UDim2.fromOffset(96, 122),
			selected = item.uid == slotA or item.uid == slotB,
			layoutOrder = i,
			onClick = function()
				if activeSlot == "A" then
					slotA = item.uid
					if slotB == item.uid then
						slotB = nil
					end
					activeSlot = "B"
				else
					slotB = item.uid
					if slotA == item.uid then
						slotA = nil
					end
				end
				render()
			end,
		})
	end
	Components.setButtonColor(refs.fuseButton, (entryA and entryB and not message) and C.Pink or Color3.fromRGB(110, 110, 120))
end

function Fusion.init(gui: ScreenGui)
	window = Components.window(gui, "🌀 PORTAIL CROSSOVER", C.Pink)
	local content = window.content
	refs.top = new("Frame", { Size = UDim2.new(1, 0, 0.42, 0), BackgroundTransparency = 1, Parent = content })
	refs.info = new("Frame", { Size = UDim2.new(0.62, 0, 0.2, 0), Position = UDim2.fromScale(0, 0.44), BackgroundTransparency = 1, Parent = content })
	refs.fuseButton = Components.button({
		Text = "🌀 FUSIONNER",
		Color = C.Pink,
		Size = UDim2.new(0.34, 0, 0, 56),
		Position = UDim2.fromScale(0.65, 0.47),
		Parent = content,
		OnClick = function()
			if not slotA or not slotB then
				Notifications.toast("Choisis deux persos.", "error")
				return
			end
			local a, b = slotA, slotB
			local ok, success = pcall(function()
				return Remotes.func("Fuse"):InvokeServer(a, b)
			end)
			if ok and success then
				slotA, slotB = nil, nil
				activeSlot = "A"
			end
		end,
	})
	refs.list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0.34, 0),
		Position = UDim2.fromScale(0, 0.66),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Theme.corner(12).Parent = refs.list
	new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 122), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.list })
	Theme.padding(6).Parent = refs.list

	window.onClose = function()
		Menus.closed("Fusion")
	end
	Menus.register("Fusion", {
		open = function()
			window.open()
			render()
		end,
		close = window.close,
	})
end

return Fusion
