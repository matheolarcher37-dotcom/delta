-- INDICE (collection) : toutes les unités de chaque univers, découvertes ou non (un onglet par
-- univers, LB / RB à la manette), avec la progression. + GUIDE du jeu (sections illustrées).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.Parent.State)

local Index = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(230, 40, 90)

local window
local guideWindow
local refs: { [string]: any } = {}
local selectedUniverse = 1

local function lockedCard(parent: Instance, rarityId: string, order: number)
	local info = Theme.rarity(rarityId)
	local tint = info.rainbow and C.Magenta or info.color
	local card = new("TextButton", {
		Name = "Locked",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = parent,
	})
	local scale = new("UIScale", { Parent = card })
	local face = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = card })
	Theme.corner(14).Parent = face
	Theme.stroke(Theme.dark(tint, 0.35), 3).Parent = face
	Theme.gradient({ Color3.fromRGB(30, 30, 40), Color3.fromRGB(14, 14, 20), Theme.dark(tint, 0.75) }, 90).Parent = face
	local silhouette = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.fromScale(0.62, 0.52), BackgroundTransparency = 1, Parent = face })
	Icons.make("unit", silhouette, { px = 70, color = Color3.fromRGB(8, 8, 12), ink = Color3.fromRGB(8, 8, 12), shadow = false })
	Theme.label({ Text = "?", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromScale(0.4, 0.3), FontFace = Theme.Faces.Title, TextColor3 = Theme.light(tint, 0.3), ZIndex = 3, Parent = face })
	local strip = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.27),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 3,
		Parent = face,
	})
	Theme.corner(12).Parent = strip
	Theme.label({ Text = "???", Size = UDim2.new(0.94, 0, 0.52, 0), Position = UDim2.fromScale(0.03, 0.04), FontFace = Theme.Faces.Title, TextColor3 = C.TextDim, ZIndex = 4, Parent = strip })
	Theme.label({
		Text = info.name,
		Size = UDim2.new(0.94, 0, 0.36, 0),
		Position = UDim2.fromScale(0.03, 0.58),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = info.rainbow and C.Cyan or Theme.light(tint, 0.2),
		ZIndex = 4,
		StrokeThickness = 1.5,
		Parent = strip,
	})
	Components.interactive(card, scale, 1.04)
	return card
end

local function render()
	Components.clear(refs.grid)
	local data = State.data
	local index = data and data.index or {}
	local universe = Universes.List[selectedUniverse] or Universes.List[1]
	local found, total = 0, 0
	for _, u in Universes.List do
		for _, id in u.characters do
			total += 1
			if index[id] then
				found += 1
			end
		end
	end
	local fusions = 0
	for key in index do
		if string.sub(key, 1, 7) == "fusion:" then
			fusions += 1
		end
	end
	window.subtitle.Text = "Total : " .. found .. " / " .. total .. "  ·  " .. fusions .. " Crossover"
	local here = 0
	for i, id in universe.characters do
		local def = Characters.get(id)
		if index[id] then
			here += 1
			local card = Components.characterCard(refs.grid, { id = id, level = 1, stars = 1 }, { layoutOrder = i, hideLevel = true })
			local badge = new("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = C.Green,
				ZIndex = 6,
				Parent = card,
			})
			Theme.round().Parent = badge
			Theme.stroke(C.Stroke, 2).Parent = badge
			Icons.make("check", badge, { px = 18, size = UDim2.fromScale(0.64, 0.64), shadow = false, zindex = 7 })
			local stars = card:FindFirstChild("Stars", true)
			if stars then
				stars:Destroy()
			end
		else
			lockedCard(refs.grid, def and def.rarity or "common", i)
		end
	end
	local count = #universe.characters
	Components.setPillText(refs.progressPill, universe.name .. " : " .. here .. " / " .. count)
	refs.bar.set(count > 0 and here / count or 0)
	refs.bar.setColor(universe.color)
end

------------------------------------------------------------------------
-- Guide
------------------------------------------------------------------------

local GUIDE = {
	{
		"dice",
		"La machine ROULER",
		"Appuie sur le gros bouton ROULER de ta base (ou X à la manette) : la machine tire des unités. Elles attendent sur l'estrade : prends celles que tu veux en payant leur prix !",
		Color3.fromRGB(255, 180, 30),
	},
	{
		"upgrade",
		"Les Améliorations",
		"Dans l'arbre de compétences, achète plus de chance, des roulages plus rapides, 2 puis 3 unités par roulage, l'auto-roulage, plus de revenus et de dégâts...",
		Color3.fromRGB(240, 170, 30),
	},
	{
		"pin",
		"Les univers",
		"Toutes les 30 minutes, l'univers change : Village Ninja, Académie Occulte, Planète des Guerriers, Grand Océan, Ère des Pourfendeurs. Ennemis, boss, unités et décor changent avec !",
		Color3.fromRGB(168, 78, 255),
	},
	{
		"sword",
		"Le combat",
		"Tes unités équipées te suivent et attaquent seules les ennemis proches dans la Zone d'Univers. Un boss apparaît régulièrement au centre !",
		Color3.fromRGB(236, 60, 70),
	},
	{
		"chart",
		"Grandir",
		"Tes unités gagnent de l'XP en combat et sur ta base. Plus elles montent de niveau, plus elles grandissent et deviennent puissantes.",
		Color3.fromRGB(70, 214, 96),
	},
	{
		"evolve",
		"L'évolution",
		"Au niveau max, fais évoluer une unité (menu Évolution) avec des matériaux de SON univers : on ne les trouve que quand son univers est actif !",
		Color3.fromRGB(150, 70, 255),
	},
	{
		"gem",
		"Les traits",
		"Chaque unité peut avoir un trait (Vif, Génie, Monarque...). Relance-le avec un Cristal de Trait dans le menu Traits.",
		Color3.fromRGB(50, 200, 240),
	},
	{
		"fusion",
		"La fusion Crossover",
		"Fusionne 2 unités de 2 univers différents (Épique+, ★★) pour créer un Crossover unique !",
		Color3.fromRGB(255, 80, 170),
	},
	{
		"gift",
		"Les reliques",
		"La Boutique vend les reliques de l'univers actuel. Pose-les sur un autel de ta base : après quelques secondes, ouvre-les pour obtenir une unité.",
		Color3.fromRGB(64, 160, 255),
	},
	{
		"swap",
		"Les échanges",
		"Au Coin des Échanges, assieds-toi à une table : quand un joueur s'assoit en face, l'échange s'ouvre. Les unités verrouillées ne peuvent pas être échangées.",
		Color3.fromRGB(60, 140, 240),
	},
	{
		"bolt",
		"Les événements",
		"Orage Électrique, Éclipse du Néant, Pluie d'Or, Lune de Sang... Pendant un orage, la foudre peut donner l'aura Foudre aux unités de ta base !",
		Color3.fromRGB(255, 222, 50),
	},
	{
		"robot",
		"À la manette",
		"A : choisir · B : fermer · X : ROULER · LB / RB : onglets · croix haut : menu principal.",
		Color3.fromRGB(110, 120, 150),
	},
}

local function buildGuide(gui: ScreenGui)
	guideWindow = Components.window(gui, "GUIDE", Color3.fromRGB(110, 120, 150), UDim2.fromOffset(1180, 640), {
		icon = "guide",
		subtitle = "Tout ce qu'il faut savoir pour devenir le plus fort",
	})
	local scroll = Components.scroll(guideWindow.content, { Size = UDim2.fromScale(1, 1) })
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -12, 0, 118),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Theme.padding(6).Parent = scroll
	for i, section in GUIDE do
		local color = section[4]
		local frame = new("Frame", { Name = "Section", BackgroundColor3 = WHITE, LayoutOrder = i, Parent = scroll })
		Theme.corner(14).Parent = frame
		Theme.stroke(Theme.dark(color, 0.2), 2, 0.2).Parent = frame
		Theme.gradient({ Theme.dark(color, 0.6), Color3.fromRGB(16, 16, 22) }, 0).Parent = frame
		local tile = new("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = WHITE, Parent = frame })
		Theme.corner(14).Parent = tile
		Theme.stroke(C.Stroke, 2.5).Parent = tile
		Theme.gradient({ Theme.light(color, 0.3), color, Theme.dark(color, 0.35) }, 60).Parent = tile
		Icons.make(section[1], tile, { px = 42, size = UDim2.fromScale(0.68, 0.68), ink = Theme.dark(color, 0.5) })
		Theme.label({
			Text = section[2],
			Position = UDim2.fromOffset(88, 10),
			Size = UDim2.new(1, -100, 0, 28),
			FontFace = Theme.Faces.Title,
			TextColor3 = Theme.light(color, 0.35),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		Theme.label({
			Text = section[3],
			Position = UDim2.fromOffset(88, 40),
			Size = UDim2.new(1, -100, 1, -48),
			FontFace = Theme.Faces.Medium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			StrokeThickness = 1,
			MaxSize = 17,
			Parent = frame,
		})
	end
	Components.registerWindow(Menus, "Guide", guideWindow)
end

function Index.init(gui: ScreenGui)
	local tabs = {}
	for i, universe in Universes.List do
		table.insert(tabs, { id = tostring(i), text = universe.name })
	end
	window = Components.window(gui, "INDICE", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "book",
		tabs = tabs,
		onTab = function(id)
			selectedUniverse = tonumber(id) or 1
			render()
		end,
	})
	local content = window.content
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	refs.progressPill = Components.pill(top, "book", "", ACCENT, { Size = UDim2.fromOffset(330, 36), Position = UDim2.fromOffset(0, 2) })
	refs.bar = Components.progressBar(top, C.Gold, { Size = UDim2.new(1, -350, 0, 16), Position = UDim2.new(0, 346, 0.5, -8) })
	refs.grid = Components.cardGrid(content, Vector2.new(170, 220), { Name = "Grid", Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50) }, 12)
	local layout = refs.grid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	Components.registerWindow(Menus, "Index", window, function()
		local current = State.universe()
		selectedUniverse = current.index or 1
		window.setTab(tostring(selectedUniverse), true)
		render()
	end)
	-- Reconstruit seulement si la collection a changé (pas à chaque gain de pièces).
	local lastKey = ""
	State.onChanged(function(data)
		if not window.isOpen then
			return
		end
		local keys = { tostring(selectedUniverse) }
		for key in data.index or {} do
			table.insert(keys, key)
		end
		table.sort(keys)
		local key = table.concat(keys, ",")
		if key ~= lastKey then
			lastKey = key
			render()
		end
	end)
	buildGuide(gui)
end

return Index
