-- TRAITS (Autel des Traits) : relancer le trait d'une unité avec un Cristal de Trait.
-- À gauche les unités, à droite le trait actuel (grande pastille colorée), le bouton RELANCER
-- (animation de tirage : les noms défilent de plus en plus lentement) et le tableau des chances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared.Config.Traits)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local TraitsMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(50, 200, 240)

local PAGE_SIZE = 12

local window
local refs: { [string]: any } = {}
local selected: string? = nil
local rolling = false
local page = 1
local render: (boolean?) -> ()

local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxasset://sounds/clickfast.wav"
tickSound.Volume = 0.25
tickSound.Parent = SoundService

local function invoke(remote: string, ...)
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return Remotes.func(remote):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if ok and message then
		Notifications.toast(message, success and "success" or "error")
	elseif not ok then
		Notifications.toast("Erreur de connexion, réessaie.", "error")
	end
	return ok and success
end

-- Grande pastille du trait (couleur du trait, contour de la couleur du rang).
local function traitBox(parent: Instance, trait, props)
	local box = new("Frame", {
		Name = "TraitBox",
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	for k, v in props do
		(box :: any)[k] = v
	end
	Theme.corner(14).Parent = box
	refs.traitStroke = Theme.stroke(trait and Traits.TierColors[trait.tier] or C.Edge, 3)
	refs.traitStroke.Parent = box
	local color = trait and trait.color or Color3.fromRGB(70, 70, 90)
	refs.traitGradient = Theme.gradient({ Theme.light(color, 0.15), Theme.dark(color, 0.5) }, 90)
	refs.traitGradient.Parent = box
	Theme.sparkles(box, 6, 13, 0.7)
	refs.traitName = Theme.label({
		Text = trait and ("◆ " .. trait.name) or "AUCUN TRAIT",
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 8),
		FontFace = Theme.Faces.Title,
		StrokeThickness = 2.5,
		ZIndex = 3,
		Parent = box,
	})
	refs.traitTier = Theme.label({
		Text = trait and string.upper(Traits.TierNames[trait.tier] or "") or "RELANCE POUR OBTENIR UN BONUS",
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 44),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = trait and Traits.TierColors[trait.tier] or C.TextDim,
		ZIndex = 3,
		Parent = box,
	})
	refs.traitDesc = Theme.label({
		Text = trait and trait.description or "Chaque trait donne un bonus permanent à l'unité.",
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 64),
		FontFace = Theme.Faces.Bold,
		TextWrapped = true,
		ZIndex = 3,
		StrokeThickness = 1.5,
		MaxSize = 17,
		Parent = box,
	})
	return box
end

local function chancesTable(parent: Instance)
	local grid = new("Frame", {
		Name = "Chances",
		Size = UDim2.new(1, -24, 0, 170),
		Position = UDim2.new(0, 12, 1, -182),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Components.sectionTitle(grid, "CHANCES DES TRAITS", { Size = UDim2.new(1, 0, 0, 22), TextColor3 = ACCENT })
	local cells = new("Frame", { Size = UDim2.new(1, 0, 1, -26), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1, Parent = grid })
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 18),
		CellPadding = UDim2.fromOffset(8, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = cells,
	})
	for i, id in Traits.Order do
		local trait = Traits.List[id]
		Theme.label({
			Text = string.format("◆ %s  %.1f %%", trait.name, Traits.chance(id)),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = Theme.light(trait.color, 0.25),
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			LayoutOrder = i,
			Parent = cells,
		})
	end
end

local function renderDetail()
	local holder = refs.detail
	Components.clear(holder)
	local data = State.data
	local entry = data and selected and data.characters[selected]
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
	chancesTable(sheet)
	if not entry then
		Components.emptyState(sheet, "Choisis une unité à gauche pour relancer son trait.", "gem").Position = UDim2.new(0, 10, 0.12, 0)
		return
	end
	local desc = Formulas.describe(entry)
	if not desc then
		return
	end
	local info = Theme.rarity(Components.rarityOf(entry, desc))
	local tint = info.rainbow and C.Cyan or info.color
	local portrait = new("Frame", {
		Size = UDim2.new(0.4, -16, 0, 300),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(12).Parent = portrait
	Theme.stroke(tint, 2).Parent = portrait
	Theme.gradient({ Color3.fromRGB(34, 34, 46), Color3.fromRGB(16, 16, 22), Theme.dark(tint, 0.6) }, 90).Parent = portrait
	Components.characterViewport(portrait, desc.look, true, entry)
	Theme.label({
		Text = desc.name,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 28),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = portrait,
	})
	Components.rarityTag(portrait, Components.rarityOf(entry, desc), { Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(110, 22), ZIndex = 3 })

	local right = new("Frame", { Size = UDim2.new(0.6, -12, 0, 300), Position = UDim2.new(0.4, 0, 0, 12), BackgroundTransparency = 1, Parent = sheet })
	Components.sectionTitle(right, "TRAIT ACTUEL", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = ACCENT })
	local trait = Traits.get(entry.trait)
	traitBox(right, trait, { Size = UDim2.new(1, 0, 0, 108), Position = UDim2.fromOffset(0, 30) })
	local crystals = data.traitCrystals or 0
	local uid = selected :: string
	refs.rollButton = Components.button({
		Text = "RELANCER",
		Icon = "dice",
		Color = crystals > 0 and C.Purple or C.Gray,
		Size = UDim2.new(0.62, -6, 0, 56),
		Position = UDim2.fromOffset(0, 152),
		Hint = "A",
		Parent = right,
		OnClick = function()
			if rolling then
				return
			end
			if (State.data and State.data.traitCrystals or 0) < 1 then
				Notifications.toast("Il te faut un Cristal de Trait : achète-le en haut à gauche !", "error")
				return
			end
			rolling = true
			local order = Traits.Order
			local delay = 0.04
			for _ = 1, 18 do
				local random = Traits.List[order[math.random(1, #order)]]
				if refs.traitName and refs.traitName.Parent then
					refs.traitName.Text = "◆ " .. random.name
					refs.traitTier.Text = string.upper(Traits.TierNames[random.tier] or "")
					refs.traitTier.TextColor3 = Traits.TierColors[random.tier] or WHITE
					refs.traitGradient.Color = Theme.sequence({ Theme.light(random.color, 0.15), Theme.dark(random.color, 0.5) })
					refs.traitStroke.Color = Traits.TierColors[random.tier] or WHITE
				end
				SoundService:PlayLocalSound(tickSound)
				task.wait(delay)
				delay *= 1.12
			end
			invoke("RerollTrait", uid)
			rolling = false
			render(true)
		end,
	})
	local cost = Components.price(right, 1, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 160),
		Size = UDim2.new(0.38, -6, 0, 40),
	}, "crystals")
	Components.setPriceAffordable(cost, crystals > 0, "crystals")
	Components.hintText(right, "Le nouveau trait remplace l'ancien. Les traits rares (Monarque, Céleste...) sont très puissants !", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 220),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local function renderGrid()
	Components.clear(refs.grid)
	refs.selectedCard = nil
	local list = State.sortedCharacters()
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
	refs.grid.Size = UDim2.new(1, 0, 1, pages > 1 and -100 or -50)
	for i = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[i]
		local card = Components.characterCard(refs.grid, item.entry, {
			selKey = item.uid,
			selected = item.uid == selected,
			inTeam = State.inTeam(item.uid),
			layoutOrder = i,
			onClick = function()
				selected = item.uid
				render(true)
			end,
		})
		if item.uid == selected then
			refs.selectedCard = card
		end
	end
	if #list == 0 then
		Components.emptyState(refs.grid, "Aucune unité. Roule à la machine ROULER !", "dice")
	end
	Components.setPillText(refs.crystals, "Cristaux : " .. Formulas.formatNumber(data and data.traitCrystals or 0))
end

local lastKey = ""
render = function(force: boolean?)
	if not window or not window.isOpen or rolling then
		return
	end
	local data = State.data
	if not data then
		return
	end
	local parts = { tostring(selected), tostring(data.traitCrystals), tostring(page) }
	for uid, entry in data.characters do
		table.insert(parts, uid .. tostring(entry.trait) .. entry.level .. entry.stars)
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

function TraitsMenu.init(gui: ScreenGui)
	window = Components.window(gui, "TRAITS", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "gem",
		subtitle = "Relance le trait de tes unités avec des Cristaux de Trait",
	})
	local content = window.content
	local left = new("Frame", { Name = "Left", Size = UDim2.new(0.38, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	local toolbar = new("Frame", { Name = "Toolbar", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = left })
	refs.crystals = Components.pill(toolbar, "gem", "Cristaux : 0", C.Cyan, { Size = UDim2.new(0.44, -4, 0, 38), Position = UDim2.fromOffset(0, 3) })
	Components.button({
		Text = "ACHETER " .. Formulas.formatNumber(Economy.TraitCrystalPrice),
		Icon = "coin",
		Color = C.Blue,
		Size = UDim2.new(0.56, -4, 0, 42),
		Position = UDim2.new(0.44, 4, 0, 1),
		TextSize = 20,
		Parent = toolbar,
		OnClick = function()
			invoke("BuyTraitCrystal")
		end,
	})
	refs.grid = Components.cardGrid(left, Vector2.new(124, 160), { Name = "Grid", Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50) }, 10)
	refs.pager = Components.pager(left, { Position = UDim2.new(0, 0, 1, -44) }, function(target)
		page = target
		render(true)
	end)
	refs.detail = new("Frame", {
		Name = "DetailHolder",
		Size = UDim2.new(0.62, -8, 1, 0),
		Position = UDim2.new(0.38, 8, 0, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Components.registerWindow(Menus, "Traits", window, function(arg)
		if type(arg) == "string" then
			selected = arg
		end
		render(true)
	end, function()
		return refs.selectedCard or window.firstSelectable()
	end)
	State.onChanged(function()
		render()
	end)
end

return TraitsMenu
