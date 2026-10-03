-- Index (collection) : tous les persos de chaque univers, découverts ou non. + Guide du jeu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.Parent.State)

local Index = {}

local C = Theme.Colors
local new = Theme.new

local window
local guideWindow
local list: ScrollingFrame
local selectedUniverse = 1
local tabs: Frame

local function render()
	Components.clear(list)
	local data = State.data
	local index = data and data.index or {}
	local universe = Universes.List[selectedUniverse]
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
	window.title.Text = "📖 INDEX · " .. found .. "/" .. total .. " persos · " .. fusions .. " crossovers"

	for i, id in universe.characters do
		local def = Characters.get(id)
		local rarity = Rarities.get(def.rarity)
		if index[id] then
			local card = Components.characterCard(list, { id = id, level = 1, stars = 1 }, { size = UDim2.fromOffset(130, 165), layoutOrder = i })
			local level = card:FindFirstChild("Level") :: TextLabel?
			if level then
				level.Text = "✔"
			end
		else
			local card = new("Frame", { Size = UDim2.fromOffset(130, 165), BackgroundColor3 = C.PanelDark, LayoutOrder = i, Parent = list })
			Theme.corner(14).Parent = card
			Theme.stroke(rarity.color:Lerp(C.Stroke, 0.5), 3).Parent = card
			Theme.label({ Text = "?", Size = UDim2.fromScale(0.6, 0.5), Position = UDim2.fromScale(0.2, 0.12), Font = Theme.Fonts.Title, TextColor3 = C.TextDim, Parent = card })
			Theme.label({ Text = "???", Size = UDim2.new(0.94, 0, 0.13, 0), Position = UDim2.fromScale(0.03, 0.74), TextColor3 = C.TextDim, Parent = card })
			Theme.label({
				Text = rarity.name,
				Size = UDim2.new(0.94, 0, 0.1, 0),
				Position = UDim2.fromScale(0.03, 0.87),
				TextColor3 = rarity.color,
				Font = Theme.Fonts.Small,
				Parent = card,
			})
		end
	end
end

local function buildTabs()
	Components.clear(tabs)
	for i, universe in Universes.List do
		Components.button({
			Text = universe.name,
			Color = i == selectedUniverse and universe.color or Color3.fromRGB(80, 75, 110),
			Size = UDim2.new(0.19, 0, 1, 0),
			LayoutOrder = i,
			Parent = tabs,
			OnClick = function()
				selectedUniverse = i
				buildTabs()
				render()
			end,
		})
	end
end

local GUIDE = {
	{
		"🌀 Les univers",
		"Toutes les 30 minutes, la Zone d'Univers au centre change d'animé : Village Ninja, Académie Occulte, Planète des Guerriers, Grand Océan, Ère des Pourfendeurs. Ennemis, boss, reliques et décor changent avec !",
	},
	{
		"🎁 Les reliques",
		"La Machine à Reliques de ta base vend les reliques de l'univers actuel (parchemins, doigts maudits, boules de cristal, fruits du démon...). Pose-les sur un autel : après quelques secondes, ouvre-les pour obtenir un perso !",
	},
	{
		"⚔️ Le combat",
		"Tes persos équipés te suivent. Entre dans la Zone d'Univers : ils attaquent tout seuls les ennemis proches. Clique sur un ennemi pour le cibler. Les ennemis du centre sont plus forts mais rapportent plus. Un boss apparaît régulièrement !",
	},
	{ "📈 Grandir", "Tes persos gagnent de l'XP en combat et en s'entraînant sur ta base. Plus ils montent de niveau, plus ils GRANDISSENT et deviennent puissants." },
	{
		"✨ L'évolution",
		"Au niveau max, fais évoluer un perso à l'Autel d'Éveil avec des matériaux de SON univers (ex : Fragments de Chakra pour le Village Ninja). On ne les trouve que quand son univers est actif !",
	},
	{
		"🏠 Ta base",
		"Les persos exposés sur ta base rapportent des pièces dans le coffre doré : marche dessus pour récupérer. Marche sur les boutons verts pour construire des améliorations (autels, dojo, fontaine...).",
	},
	{
		"🤝 Les échanges",
		"Va au Coin des Échanges, assieds-toi d'un côté de la table : quand un autre joueur s'assoit en face, l'échange s'ouvre. Les persos verrouillés 🔒 ne peuvent pas être échangés.",
	},
	{
		"🌀 La fusion Crossover",
		"Au Portail Crossover, fusionne 2 persos de 2 univers différents (Épique+, ★★) pour créer un perso Crossover unique, comme « Renard de l'Infini » !",
	},
	{ "⚡ Les événements", "Orage Électrique, Éclipse du Néant, Pluie d'Or, Lune de Sang... Pendant un orage, la foudre peut donner l'aura Foudre aux persos de ta base !" },
}

function Index.init(gui: ScreenGui)
	window = Components.window(gui, "📖 INDEX", C.Purple)
	tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = window.content })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = tabs
	list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -54),
		Position = UDim2.fromOffset(0, 54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.content,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(130, 165),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = list,
	})
	Theme.padding(8).Parent = list
	window.onClose = function()
		Menus.closed("Index")
	end
	Menus.register("Index", {
		open = function()
			local current = State.universe()
			selectedUniverse = current.index or 1
			window.open()
			buildTabs()
			render()
		end,
		close = window.close,
	})

	guideWindow = Components.window(gui, "❔ GUIDE DU JOUEUR", Color3.fromRGB(90, 90, 130))
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = guideWindow.content,
	})
	Theme.list(Enum.FillDirection.Vertical, 10).Parent = scroll
	Theme.padding(6).Parent = scroll
	for i, section in GUIDE do
		local frame = new("Frame", { Size = UDim2.new(1, -12, 0, 96), BackgroundColor3 = C.PanelDark, BackgroundTransparency = 0.2, LayoutOrder = i, Parent = scroll })
		Theme.corner(12).Parent = frame
		Theme.label({
			Text = section[1],
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.fromOffset(10, 6),
			Font = Theme.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Gold,
			Parent = frame,
		})
		local body = Theme.label({
			Text = section[2],
			Size = UDim2.new(1, -20, 0, 56),
			Position = UDim2.fromOffset(10, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Font = Theme.Fonts.Small,
			Stroke = false,
			Parent = frame,
		})
		new("UITextSizeConstraint", { MaxTextSize = 17, Parent = body })
	end
	guideWindow.onClose = function()
		Menus.closed("Guide")
	end
	Menus.register("Guide", { open = guideWindow.open, close = guideWindow.close })
end

return Index
