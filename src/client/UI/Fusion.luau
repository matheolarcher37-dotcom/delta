-- FUSION (Portail Crossover) : fusionner deux unités de deux univers différents.
-- En haut : emplacement A + emplacement B = Crossover, avec les conditions et le bouton FUSIONNER.
-- En bas : les unités éligibles (A puis B : la sélection passe toute seule à B).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Fusion = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(255, 80, 170)

local window
local refs: { [string]: any } = {}
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
	local active = activeSlot == label
	local frame = new("TextButton", {
		Name = "Slot" .. label,
		Size = UDim2.new(0.28, 0, 1, 0),
		Position = UDim2.fromScale(x, 0),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Text = "",
		Parent = parent,
	})
	local scale = new("UIScale", { Parent = frame })
	Theme.corner(14).Parent = frame
	Theme.stroke(active and C.Gold or C.Edge, active and 4 or 2.5).Parent = frame
	if entry then
		local desc = Formulas.describe(entry)
		local universe = Universes.get(desc.universe)
		local tint = universe and universe.color or C.Purple
		Theme.gradient({ Theme.dark(tint, 0.35), Color3.fromRGB(16, 16, 22) }, 90).Parent = frame
		local holder = new("Frame", { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1, Parent = frame })
		Components.characterViewport(holder, desc.look, true, entry)
		Theme.label({ Text = desc.name, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.new(0, 5, 1, -28), FontFace = Theme.Faces.Title, ZIndex = 3, Parent = frame })
		Theme.label({
			Text = universe and universe.name or "",
			Size = UDim2.new(1, -10, 0, 18),
			Position = UDim2.fromOffset(5, 6),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = Theme.light(tint, 0.35),
			ZIndex = 3,
			Parent = frame,
		})
	else
		Theme.gradient({ Color3.fromRGB(30, 30, 42), Color3.fromRGB(14, 14, 20) }, 90).Parent = frame
		local plus = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Parent = frame })
		Icons.make("unit", plus, { px = 60, color = Color3.fromRGB(90, 90, 115), ink = C.PanelDark })
		Theme.label({
			Text = "UNITÉ " .. label,
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.new(0, 8, 0.62, 0),
			FontFace = Theme.Faces.Title,
			TextColor3 = active and C.Gold or C.TextDim,
			Parent = frame,
		})
		Theme.label({
			Text = active and "Choisis-la en bas" or "",
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.new(0, 8, 0.62, 30),
			FontFace = Theme.Faces.Bold,
			TextColor3 = C.TextDim,
			StrokeThickness = 1,
			Parent = frame,
		})
	end
	Components.interactive(frame, scale, 1.04)
	frame.Activated:Connect(function()
		Components.click()
		activeSlot = label
		render()
	end)
	return frame
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
	Components.bigSymbol(refs.top, "plus", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.32, 0.5) })
	slotFrame(refs.top, 0.36, slotB, "B")
	Components.bigSymbol(refs.top, "arrowRight", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.68, 0.5) })
	local result = new("Frame", { Name = "Result", Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.72, 0), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = refs.top })
	Theme.corner(14).Parent = result
	Theme.rainbowStroke(result, 4)
	Theme.gradient({ Color3.fromRGB(40, 20, 60), Color3.fromRGB(14, 10, 24) }, 90).Parent = result
	Theme.sparkles(result, 7, 31, 0.6)

	local entryA = slotA and data.characters[slotA]
	local entryB = slotB and data.characters[slotB]
	local sameUniverse = false
	if entryA and entryB then
		local preview = { id = "fusion", fusion = { a = entryA.id, b = entryB.id }, level = 1, xp = 0, stars = 1 }
		local desc = Formulas.describe(preview)
		if desc then
			local holder = new("Frame", { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1, Parent = result })
			Components.characterViewport(holder, desc.look, true)
			local name = Theme.label({ Text = desc.name, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.new(0, 5, 1, -28), FontFace = Theme.Faces.Title, ZIndex = 3, Parent = result })
			Theme.gradient(Theme.RainbowColors, 0).Parent = name
			Theme.label({
				Text = "Puissance " .. Formulas.formatNumber(Formulas.power(preview)),
				Size = UDim2.new(1, -10, 0, 18),
				Position = UDim2.fromOffset(5, 6),
				FontFace = Theme.Faces.Heavy,
				TextColor3 = C.Green,
				ZIndex = 3,
				Parent = result,
			})
		end
		sameUniverse = Formulas.describe(entryA).universe == Formulas.describe(entryB).universe
	else
		Theme.label({ Text = "?", Size = UDim2.fromScale(0.5, 0.42), Position = UDim2.fromScale(0.25, 0.22), FontFace = Theme.Faces.Title, TextColor3 = Color3.fromRGB(200, 160, 255), Parent = result })
		Theme.label({ Text = "CROSSOVER", Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 0.7, 0), FontFace = Theme.Faces.Title, Parent = result })
	end

	-- Conditions
	Components.clear(refs.rules)
	local rule = Economy.Fusion
	local order = 0
	local function req(text: string, ok: boolean)
		order += 1
		Components.requirement(refs.rules, text, ok, order, 30)
	end
	req("Deux univers différents", entryA ~= nil and entryB ~= nil and not sameUniverse)
	local allOk = entryA ~= nil and entryB ~= nil and not sameUniverse
	if entryA and entryB then
		for _, entry in { entryA, entryB } do
			local desc = Formulas.describe(entry)
			local material = Universes.get(desc.universe).material
			local owned = data.materials[material.id] or 0
			req(rule.materials .. " × " .. material.name .. "  (" .. owned .. ")", owned >= rule.materials)
			allOk = allOk and owned >= rule.materials
		end
	else
		req(rule.materials .. " matériaux de chaque univers", false)
	end
	req(Formulas.formatNumber(rule.coins) .. " pièces", data.coins >= rule.coins)
	allOk = allOk and data.coins >= rule.coins
	Components.setButtonColor(refs.fuseButton, allOk and ACCENT or C.Gray)
	Components.setPriceAffordable(refs.price, data.coins >= rule.coins)

	-- Liste des unités éligibles
	Components.clear(refs.list)
	refs.firstCard = nil
	local list = State.sortedCharacters(function(_, entry)
		return eligible(entry)
	end)
	if #list == 0 then
		Components.emptyState(
			refs.list,
			"Aucune unité éligible : fais évoluer des unités Épiques ou mieux au rang ★★ (menu Évolution) !",
			"fusion"
		).Size = UDim2.new(1, -20, 0, 140)
	end
	for i, item in list do
		if i > 36 then
			break
		end
		local card = Components.characterCard(refs.list, item.entry, {
			size = UDim2.fromOffset(110, 142),
			selected = item.uid == slotA or item.uid == slotB,
			layoutOrder = i,
			hideLevel = true,
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
		refs.firstCard = refs.firstCard or card
	end
end

function Fusion.init(gui: ScreenGui)
	window = Components.window(gui, "FUSION", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "fusion",
		subtitle = "Deux unités de deux univers = un Crossover unique",
	})
	local content = window.content
	refs.top = new("Frame", { Name = "Top", Size = UDim2.new(0.64, -8, 0, 262), BackgroundTransparency = 1, Parent = content })
	local side = Components.sheet(content, { Name = "Rules", Size = UDim2.new(0.36, -8, 0, 262), Position = UDim2.new(0.64, 8, 0, 0) })
	Components.sectionTitle(side, "CONDITIONS", { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 8), TextColor3 = ACCENT })
	refs.rules = new("Frame", { Size = UDim2.new(1, -24, 0, 140), Position = UDim2.fromOffset(12, 34), BackgroundTransparency = 1, Parent = side })
	Theme.list(Enum.FillDirection.Vertical, 5, Enum.HorizontalAlignment.Left).Parent = refs.rules
	refs.fuseButton = Components.button({
		Text = "FUSIONNER",
		Icon = "fusion",
		Color = ACCENT,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0.6, -12, 0, 52),
		TextSize = 22,
		Parent = side,
		OnClick = function()
			if not slotA or not slotB then
				Notifications.toast("Choisis deux unités.", "error")
				return
			end
			local a, b = slotA, slotB
			local ok, success, message = pcall(function()
				return Remotes.func("Fuse"):InvokeServer(a, b)
			end)
			if ok and message then
				Notifications.toast(message, success and "success" or "error")
			end
			if ok and success then
				slotA, slotB = nil, nil
				activeSlot = "A"
				render()
			end
		end,
	})
	refs.price = Components.price(side, Economy.Fusion.coins, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -18),
		Size = UDim2.new(0.4, -8, 0, 40),
	})

	local bottom = Components.sheet(content, { Name = "Eligible", Size = UDim2.new(1, 0, 1, -274), Position = UDim2.fromOffset(0, 274) })
	Components.sectionTitle(bottom, "UNITÉS ÉLIGIBLES (ÉPIQUE+ ★★)", { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 8), TextColor3 = C.Gold })
	refs.list = Components.cardGrid(bottom, Vector2.new(110, 142), { Size = UDim2.new(1, -12, 1, -36), Position = UDim2.fromOffset(6, 32) }, 8)

	Components.registerWindow(Menus, "Fusion", window, function()
		render()
	end, function()
		return refs.firstCard or window.firstSelectable()
	end)
end

return Fusion
