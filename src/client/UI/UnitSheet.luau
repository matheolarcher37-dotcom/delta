-- Fiche d'unité (comme la capture de référence) : grand portrait 3D du perso, nom, rareté,
-- trait coloré, badge de type, et tuiles de statistiques calculées avec Formulas :
--   DMG (rouge + épée), SPA (bleu + sablier), CRITIQUE (jaune + dé), DÉGÂTS CRITIQUES (orange + cible).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local State = require(script.Parent.Parent.State)

local UnitSheet = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

local rgb = Color3.fromRGB

-- Types d'attaque (badge sous le nom).
local TYPES = {
	punch = { name = "Physique", icon = "sword" },
	slash = { name = "Physique", icon = "sword" },
	stretch = { name = "Physique", icon = "sword" },
	orb = { name = "Magique", icon = "star" },
	beam = { name = "Magique", icon = "star" },
	shadow = { name = "Maudit", icon = "eye" },
	lightning = { name = "Élémentaire", icon = "bolt" },
	flame = { name = "Élémentaire", icon = "bolt" },
	ice = { name = "Élémentaire", icon = "bolt" },
}

UnitSheet.StatStyles = {
	dmg = { label = "DMG", icon = "sword", color = rgb(255, 64, 64), bg = rgb(80, 14, 18) },
	spa = { label = "SPA", icon = "hourglass", color = rgb(60, 190, 255), bg = rgb(10, 52, 84) },
	crit = { label = "CRITIQUE", icon = "dice", color = rgb(255, 214, 40), bg = rgb(84, 64, 6) },
	critdmg = { label = "DÉGÂTS CRITIQUES", icon = "target", color = rgb(255, 120, 40), bg = rgb(90, 36, 8) },
}

-- Statistiques d'un perso possédé, avec les bonus de l'arbre de compétences.
function UnitSheet.stats(entry)
	local tree = State.treeStats()
	local damage = Formulas.power(entry) * (tree.damage or 1)
	-- Le serveur (CombatService) applique la vitesse d'attaque de l'arbre en bonus de dégâts
	-- par seconde : délai équivalent = délai / (1 + bonus).
	local spa = Formulas.attackCooldown(entry) / (1 + math.max(0, tree.attackSpeed or 0))
	local crit = Formulas.critChance(entry) + (tree.crit or 0)
	local critDamage = ((tree.critDamage or 2) - 1)
	return {
		dmg = damage,
		spa = spa,
		crit = math.clamp(crit, 0, 1),
		critdmg = critDamage,
	}
end

function UnitSheet.formatStat(key: string, value: number): string
	if key == "dmg" then
		return Formulas.formatNumber(math.floor(value))
	elseif key == "spa" then
		return string.format("%.1fs", value)
	else
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end
end

-- Tuile de statistique (fond sombre coloré, contour de la couleur, icône, libellé, valeur).
function UnitSheet.statTile(parent: Instance, key: string, value: string, props: { [string]: any }?): Frame
	local style = UnitSheet.StatStyles[key]
	local tile = new("Frame", {
		Name = "Stat_" .. key,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(tile :: any)[k] = v
		end
	end
	Theme.corner(10).Parent = tile
	Theme.stroke(style.color, 2.5).Parent = tile
	Theme.gradient({ Theme.light(style.bg, 0.12), style.bg, Theme.dark(style.bg, 0.35) }, 90).Parent = tile
	local shine = new("Frame", {
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = tile,
	})
	Theme.corner(8).Parent = shine
	Theme.gradient({ WHITE, WHITE }, 90, { 0.88, 1 }).Parent = shine
	local icon = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = tile,
	})
	Icons.make(style.icon, icon, { px = 34, color = style.color, ink = style.bg, zindex = 2 })
	local long = #style.label > 8
	Theme.label({
		Name = "Label",
		Text = style.label,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 54, 0.5, 0),
		Size = UDim2.new(0.48, -54, 0, long and 34 or 28),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = style.color,
		TextWrapped = long,
		TextXAlignment = long and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
		ZIndex = 2,
		StrokeThickness = 1.5,
		Parent = tile,
	})
	Theme.label({
		Name = "Value",
		Text = value,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0.46, 0, 0, 28),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = tile,
	})
	return tile
end

export type SheetActions = { { text: string, color: Color3, icon: string?, onClick: () -> () } }

-- Construit la fiche dans `parent` (prend toute la place). `actions` = boutons en bas à droite.
function UnitSheet.build(parent: Instance, entry, actions: SheetActions?): Frame?
	local desc = Formulas.describe(entry)
	if not desc then
		return nil
	end
	local rarityId = Components.rarityOf(entry, desc)
	local info = Theme.rarity(rarityId)
	local tint = info.rainbow and C.Cyan or info.color
	local sheet = new("Frame", {
		Name = "UnitSheet",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	Theme.corner(16).Parent = sheet
	Theme.stroke(C.Stroke, 3).Parent = sheet
	Theme.gradient({ rgb(22, 22, 28), rgb(12, 12, 16) }, 90).Parent = sheet
	local edge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = sheet })
	Theme.corner(14).Parent = edge
	Theme.stroke(rgb(120, 120, 140), 1.5, 0.45).Parent = edge
	-- Onglet du haut (« Fiche d'unité »)
	local tab = new("Frame", {
		Name = "Tab",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(190, 30),
		BackgroundColor3 = rgb(16, 16, 20),
		ZIndex = 3,
		Parent = sheet,
	})
	Theme.corner(10).Parent = tab
	Theme.stroke(rgb(120, 120, 140), 1.5, 0.3).Parent = tab
	local ready = (entry.stars or 1) < 3 and entry.level >= Formulas.levelCap(entry.stars)
	Theme.label({
		Text = ready and "Prêt à évoluer !" or "Fiche d'unité",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		FontFace = Theme.Faces.Bold,
		TextColor3 = ready and C.Green or WHITE,
		ZIndex = 4,
		StrokeThickness = 1,
		Parent = tab,
	})

	-- Portrait (gauche)
	local portrait = new("Frame", {
		Name = "Portrait",
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.new(0.52, -18, 1, -34),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(12).Parent = portrait
	Theme.stroke(rgb(90, 90, 110), 1.5, 0.3).Parent = portrait
	Theme.gradient({ rgb(30, 30, 38), rgb(16, 16, 22), Theme.dark(tint, 0.7) }, 90).Parent = portrait
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.58, 0.58),
		Size = UDim2.fromScale(0.95, 0.8),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = portrait,
	})
	Theme.round().Parent = glow
	Theme.gradient({ WHITE, WHITE }, 90, { 0.45, 1 }).Parent = glow
	local view = new("Frame", {
		Name = "Preview",
		Position = UDim2.fromScale(0.12, 0.12),
		Size = UDim2.fromScale(0.9, 0.86),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = portrait,
	})
	local viewport = Components.characterViewport(view, desc.look, true, entry)
	viewport.ZIndex = 2
	Theme.label({
		Name = "Name",
		Text = desc.name,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 34),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 2,
		Parent = portrait,
	})
	local rarityLabel = Theme.label({
		Name = "RarityName",
		Text = info.name,
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 22),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = info.rainbow and WHITE or Theme.light(tint, 0.1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 1.5,
		Parent = portrait,
	})
	if info.rainbow then
		Theme.gradient(Theme.RainbowColors, 0).Parent = rarityLabel
	end
	local trait = Traits.get(entry.trait)
	Theme.label({
		Name = "Trait",
		Text = trait and string.upper(trait.name) or "SANS TRAIT",
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 0, 20),
		FontFace = Theme.Faces.Title,
		TextColor3 = trait and trait.color or rgb(120, 120, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 1.5,
		Parent = portrait,
	})
	-- Badge de type
	local kind = TYPES[desc.attack and desc.attack.kind or "punch"] or TYPES.punch
	local badge = new("Frame", {
		Name = "TypeBadge",
		Position = UDim2.fromOffset(12, 98),
		Size = UDim2.fromOffset(142, 32),
		BackgroundColor3 = rgb(10, 10, 14),
		BackgroundTransparency = 0.15,
		ZIndex = 3,
		Parent = portrait,
	})
	Theme.round().Parent = badge
	Theme.stroke(rgb(200, 200, 215), 1.5, 0.2).Parent = badge
	local badgeIcon = new("Frame", { Position = UDim2.fromOffset(9, 5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, ZIndex = 4, Parent = badge })
	Icons.make(kind.icon, badgeIcon, { px = 22, zindex = 4, ink = rgb(10, 10, 14) })
	Theme.label({
		Text = kind.name,
		Position = UDim2.fromOffset(36, 5),
		Size = UDim2.new(1, -44, 0, 22),
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		StrokeThickness = 1,
		Parent = badge,
	})
	-- Étoiles, aura, univers (bas du portrait)
	local universe = Universes.get(desc.universe)
	local aura = Auras.get(entry.aura)
	local footer = new("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = portrait,
	})
	Theme.label({
		Text = string.rep("★", entry.stars or 1) .. "  Nv." .. entry.level .. " / " .. Formulas.levelCap(entry.stars),
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.6, 0, 0, 20),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = footer,
	})
	Theme.label({
		Text = (universe and universe.name or "") .. (aura and ("  ·  Aura " .. aura.name) or ""),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.new(0.42, 0, 0, 16),
		FontFace = Theme.Faces.Bold,
		TextColor3 = aura and aura.color or C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
		StrokeThickness = 1,
		Parent = footer,
	})
	local cap = Formulas.levelCap(entry.stars)
	local xpBar = Components.progressBar(footer, C.Blue, { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 34), ZIndex = 4 })
	xpBar.set(entry.level >= cap and 1 or (entry.xp or 0) / Formulas.xpToNext(entry.level))
	if entry.level >= cap then
		xpBar.setColor(C.Green)
	end

	-- Statistiques (droite)
	local right = new("Frame", {
		Name = "Stats",
		Position = UDim2.new(0.52, 0, 0, 22),
		Size = UDim2.new(0.48, -12, 1, -34),
		BackgroundTransparency = 1,
		Parent = sheet,
	})
	local stats = UnitSheet.stats(entry)
	local list = new("Frame", { Size = UDim2.new(1, 0, 0, 4 * 64), BackgroundTransparency = 1, Parent = right })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = list
	for i, key in { "dmg", "spa", "crit", "critdmg" } do
		UnitSheet.statTile(list, key, UnitSheet.formatStat(key, stats[key]), { LayoutOrder = i })
	end
	-- Ligne d'infos : revenu et PV
	local extra = new("Frame", { Name = "Extra", Position = UDim2.fromOffset(0, 4 * 64 + 2), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = right })
	Theme.label({
		Text = "+" .. Formulas.formatNumber(Formulas.income(entry, State.stats().income)) .. "/s   ·   PV " .. Formulas.formatNumber(Formulas.maxHp(entry)),
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		StrokeThickness = 1,
		Parent = extra,
	})
	-- Boutons d'action
	if actions and #actions > 0 then
		local area = new("Frame", {
			Name = "Actions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 1, -(4 * 64 + 30)),
			BackgroundColor3 = rgb(26, 26, 32),
			Parent = right,
		})
		Theme.corner(10).Parent = area
		Theme.stroke(rgb(90, 90, 110), 1.5, 0.4).Parent = area
		local grid = new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 44),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = area,
		})
		if #actions == 1 then
			grid.CellSize = UDim2.new(1, -10, 0, 50)
		end
		Theme.padding(5).Parent = area
		for i, action in actions do
			Components.button({
				Text = action.text,
				Color = action.color,
				Icon = action.icon,
				LayoutOrder = i,
				TextSize = 18,
				Parent = area,
				OnClick = action.onClick,
			})
		end
	end
	return sheet
end

return UnitSheet
