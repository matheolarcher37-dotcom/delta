-- TRAITS (Autel des Traits) : relancer le trait d'une unité avec une GEMME DE TRAIT
-- (= Cristal de Trait : 1 gemme = 1 relance ; on en gagne en combat, au punching-ball de la zone
-- anti-AFK, en défis, ou en packs dans la boutique Robux).
--
-- À gauche : la réserve de gemmes (+ achat), la grille des unités (chacune avec son trait) et un
-- bouton pour aller gagner des gemmes.
-- À droite : la grande fiche de l'unité (portrait aux couleurs de son trait, puissance), la carte du
-- trait actuel (emblème, ROULEAU façon machine à sous, rang, bonus, reflets et particules), le
-- gros bouton RELANCER avec son coût, la RELANCE AUTO (s'arrête au rang choisi) et le tableau des
-- chances par rang.
--
-- Relance : le serveur tire le trait (TraitService) ; ici on ne fait que l'AFFICHER :
--   1. le rouleau défile puis ralentit et s'arrête sur le résultat (plus le trait est rare, plus
--      l'arrêt est long et tendu) ;
--   2. la révélation dépend du rang (Traits.revealLevel) :
--        1 = éclat sur la carte ; 2 = étincelles + onde ; 3 = révélation renforcée plein écran
--        (rayons, emblème, gros titre) ; 4 = cinématique dans le monde (Controllers/TraitCinematic :
--        Monarque, Céleste, Midas, Vampire), vue seulement par le joueur.
-- Les réglages Options « Flashs » (FxFlash) et « Secousses » (FxShake) sont respectés.
-- Tout se passe d'un clic, d'un toucher ou avec A / B à la manette.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared.Config.Traits)
local QuestsConfig = require(Shared.Config.Quests)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Icons = require(script.Parent.Icons)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local Console = require(script.Parent.Console)
local State = require(script.Parent.Parent.State)
local TraitCinematic = require(script.Parent.Parent.Controllers.TraitCinematic)

local TraitsMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local ACCENT = Color3.fromRGB(50, 200, 240)
local GEM = QuestsConfig.Gems.Color
local INK = Color3.fromRGB(14, 14, 20)

local PAGE_SIZE = 6
local AUTO_TARGETS = { 3, 4, 5 } -- rangs d'arrêt de la relance auto
local ROW = 32 -- hauteur d'une ligne du rouleau (3 lignes visibles)
local CARD_H = ROW * 3 + 108 -- hauteur de la carte du trait (rouleau, rang, description, pastilles)

local gui: ScreenGui
local window
local refs: { [string]: any } = {}
local selected: string? = nil
local rolling = false
local autoOn = false
local autoTarget = 4
local page = 1
local render: (boolean?) -> ()

local function sound(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	return s
end
local tickSound = sound("rbxasset://sounds/clickfast.wav", 0.22)
local stopSound = sound("rbxasset://sounds/electronicpingshort.wav", 0.35)
local rareSound = sound("rbxasset://sounds/electronicpingshort.wav", 0.6)
local fanfare = sound("rbxasset://sounds/victory.wav", 0.45)

local function play(s: Sound)
	pcall(function()
		SoundService:PlayLocalSound(s)
	end)
end

-- Réglages Options (attributs du joueur) : FxFlash / FxShake = false pour les couper.
local function setting(name: string): boolean
	local player = Players.LocalPlayer
	return not (player and player:GetAttribute(name) == false)
end

local function tierColor(tier: number?): Color3
	return tier and Traits.TierColors[tier] or C.Edge
end

local ACCENTS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["ç"] = "Ç", ["ô"] = "Ô", ["î"] = "Î", ["û"] = "Û" }
local function upper(text: string): string
	local out = string.upper(text)
	for lower, up in ACCENTS do
		out = string.gsub(out, lower, up)
	end
	return out
end

local function stars(tier: number): string
	return string.rep("★", tier) .. string.rep("☆", 5 - tier)
end

local function percent(value: number): string
	return (string.gsub(string.format("%.1f", value), "%.", ",")) .. " %"
end

local function iconOf(traitId: string?): string
	local visual = traitId and Traits.Visual[traitId]
	return visual and visual.icon or "gem"
end

-- Bonus d'un trait en petites pastilles (« +200 % ATQ »...).
local function traitStats(trait): { string }
	local list = {}
	if not trait then
		return list
	end
	if trait.power then
		table.insert(list, "+" .. math.floor(trait.power * 100) .. " % ATQ")
	end
	if trait.speed then
		table.insert(list, "+" .. math.floor(trait.speed * 100) .. " % vitesse")
	end
	if trait.hp then
		table.insert(list, "+" .. math.floor(trait.hp * 100) .. " % PV")
	end
	if trait.crit then
		table.insert(list, "+" .. math.floor(trait.crit * 100) .. " % crit.")
	end
	if trait.coins then
		table.insert(list, "+" .. math.floor(trait.coins * 100) .. " % ¥")
	end
	if trait.xp then
		table.insert(list, "+" .. math.floor(trait.xp * 100) .. " % XP")
	end
	if trait.lifesteal then
		table.insert(list, math.floor(trait.lifesteal * 100) .. " % vol de vie")
	end
	return list
end

local function gems(): number
	return State.data and tonumber(State.data.traitCrystals) or 0
end

------------------------------------------------------------------------
-- Petits effets d'interface : particules, reflet, rayons, emblème
------------------------------------------------------------------------

-- Particules en losange qui montent doucement (couleur du trait).
local function motes(parent: Instance, color: Color3, count: number, z: number, seed: number?): Frame
	local holder = new("Frame", {
		Name = "Motes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local rng = Random.new(seed or count)
	local list = {}
	for _ = 1, count do
		local size = rng:NextInteger(4, 9)
		local m = {
			x = rng:NextNumber(0.04, 0.96),
			speed = rng:NextNumber(0.06, 0.16),
			phase = rng:NextNumber(0, 1),
			sway = rng:NextNumber(0.008, 0.025),
			frame = new("Frame", {
				Name = "Mote",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(size, size),
				Rotation = 45,
				BackgroundColor3 = color:Lerp(WHITE, rng:NextNumber(0.25, 0.7)),
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = holder,
			}),
		}
		table.insert(list, m)
	end
	local function place(t: number)
		for _, m in list do
			local p = (m.phase + t * m.speed) % 1
			m.frame.Position = UDim2.fromScale(m.x + math.sin(t * 1.4 + m.phase * 9) * m.sway, 1.02 - p * 1.04)
			m.frame.BackgroundTransparency = 0.2 + 0.8 * math.abs(p - 0.5) * 2
		end
	end
	place(0)
	Theme.onFrame(holder, function(_, t)
		place(t)
	end)
	return holder
end

-- Reflet qui balaie une carte en diagonale (toutes les `period` secondes).
local function sweep(parent: Instance, z: number, radius: number, period: number, strength: number?): Frame
	local band = new("Frame", {
		Name = "Sweep",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Theme.corner(radius).Parent = band
	local a = 1 - (strength or 0.35)
	local gradient = Theme.gradient({ WHITE, WHITE }, 25, { 1, 1, a, 1, 1 })
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = band
	Theme.onFrame(gradient, function(_, t)
		local f = (t % period) / period
		gradient.Offset = Vector2.new(-1.2 + f * 3.4, 0)
	end)
	return band
end

-- Rayons de lumière qui tournent (éventail de bandes en dégradé).
local function sunburst(parent: Instance, color: Color3, count: number, z: number, size: number, position: UDim2?): Frame
	local holder = new("Frame", {
		Name = "Sunburst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	for i = 1, count do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, math.max(24, size * 0.05), 1, 0),
			Rotation = (i / count) * 180,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = holder,
		})
		Theme.gradient({ color, WHITE, color }, 90, { 1, 0.55, 1 }).Parent = ray
	end
	Theme.onFrame(holder, function(dt)
		holder.Rotation = (holder.Rotation + dt * 10) % 360
	end)
	return holder
end

-- Emblème du trait : hexagone aux couleurs du rang + icône du trait (+ anneau qui tourne si rare).
local function emblem(parent: Instance, traitId: string?, radius: number, position: UDim2, z: number, backing: boolean?): Frame
	local trait = Traits.get(traitId)
	local color = trait and trait.color or Color3.fromRGB(80, 80, 100)
	local edge = trait and tierColor(trait.tier) or C.Edge
	local holder = new("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	if backing then
		-- disque sombre derrière l'emblème : il se détache même sur une carte de la même couleur
		local disc = new("Frame", {
			Name = "Backing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.3, 1.3),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.25,
			ZIndex = z,
			Parent = holder,
		})
		Theme.round().Parent = disc
		Theme.stroke(Theme.light(edge, 0.2), 2, 0.2).Parent = disc
		Theme.gradient({ Theme.dark(color, 0.55), INK }, 90).Parent = disc
	end
	if trait and trait.tier >= 3 then
		local ring = new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.22, 1.22),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = holder,
		})
		Theme.round().Parent = ring
		local stroke = Theme.stroke(edge, 3)
		stroke.Parent = ring
		local g = Theme.gradient({ edge, WHITE, edge }, 0, { 0, 0.6, 1 })
		g.Parent = stroke
		Theme.onFrame(g, function(dt)
			g.Rotation = (g.Rotation + dt * 140) % 360
		end)
	end
	Components.hexagon(holder, radius, Theme.dark(edge, 0.55), { ZIndex = z, Name = "HexBack" })
	local face = Components.hexagon(holder, radius - 4, color, { ZIndex = z, Name = "HexFace" })
	for _, p in face:GetChildren() do
		if p:IsA("Frame") then
			Theme.gradient({ Theme.light(color, 0.35), color, Theme.dark(color, 0.35) }, 90).Parent = p
		end
	end
	local iconBox = new("Frame", {
		Name = "IconBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 1.05, radius * 1.05),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = holder,
	})
	Icons.make(trait and iconOf(traitId) or "dice", iconBox, { px = radius, color = WHITE, ink = Theme.dark(color, 0.6), zindex = z + 1, shadow = true })
	return holder
end

------------------------------------------------------------------------
-- Carte du trait + rouleau
------------------------------------------------------------------------

-- Une ligne du rouleau (nom du trait coloré par son rang).
local function reelRow(parent: Instance, trait, index: number): TextLabel
	local label = Theme.label({
		Name = "Row" .. index,
		Text = trait and upper(trait.name) or "AUCUN TRAIT",
		Size = UDim2.new(1, 0, 0, ROW),
		Position = UDim2.fromOffset(0, (index - 1) * ROW),
		FontFace = Theme.Faces.Title,
		TextColor3 = trait and Theme.light(trait.color, 0.45) or C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		MaxSize = 30,
		ZIndex = 5,
		Parent = parent,
	})
	label:SetAttribute("TraitId", trait and trait.id or "")
	return label
end

-- Remplit le rouleau avec `list` (traits) et centre la ligne `index`.
local function fillReel(list: { any }, index: number)
	local strip = refs.reelStrip
	if not strip or not strip.Parent then
		return
	end
	strip:ClearAllChildren()
	for i, trait in list do
		reelRow(strip, trait, i)
	end
	strip.Size = UDim2.new(1, 0, 0, #list * ROW)
	strip.Position = UDim2.fromOffset(0, -(index - 2) * ROW)
end

-- Traits voisins (ordre d'affichage) : le rouleau au repos montre le précédent et le suivant.
local function neighbours(traitId: string?): (any, any)
	local order = Traits.Order
	local i = traitId and table.find(order, traitId) or 1
	return Traits.List[order[(i - 2) % #order + 1]], Traits.List[order[i % #order + 1]]
end

-- Peint la carte (couleurs, rang, description, pastilles) pour un trait (ou « aucun trait »).
local function paintTraitCard(trait)
	local card = refs.traitCard
	if not card or not card.Parent then
		return
	end
	local color = trait and trait.color or Color3.fromRGB(70, 70, 90)
	local edge = trait and tierColor(trait.tier) or C.Edge
	refs.traitStroke.Color = edge
	refs.traitGradient.Color = Theme.sequence({ Theme.dark(color, 0.15), Theme.dark(color, 0.55), Theme.dark(color, 0.82) })
	refs.payline.BackgroundColor3 = edge
	refs.traitTier.Text = trait and (stars(trait.tier) .. "  " .. upper(Traits.TierNames[trait.tier] or "") .. "  ·  " .. percent(Traits.chance(trait.id)))
		or "AUCUN TRAIT POUR L'INSTANT"
	refs.traitTier.TextColor3 = trait and Theme.light(edge, 0.15) or C.TextDim
	local visual = trait and Traits.Visual[trait.id]
	refs.traitDesc.Text = trait and (trait.description .. (visual and visual.motto and ("  —  " .. visual.motto) or ""))
		or "Relance pour donner un bonus permanent à cette unité."
	Components.clear(refs.traitChips)
	for i, text in traitStats(trait) do
		local chip = new("Frame", {
			Name = "Chip",
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.4,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = refs.traitChips,
		})
		Theme.round().Parent = chip
		Theme.stroke(Theme.dark(edge, 0.2), 1.5, 0.3).Parent = chip
		Theme.padding(10, 0).Parent = chip
		Theme.label({
			Text = text,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			TextScaled = false,
			TextSize = 15,
			FontFace = Theme.Faces.Heavy,
			StrokeThickness = 1.5,
			ZIndex = 6,
			Parent = chip,
		})
	end
	-- emblème
	if refs.emblem then
		refs.emblem:Destroy()
	end
	refs.emblem = emblem(card, trait and trait.id, 40, UDim2.fromOffset(64, 58), 4, true)
end

-- Ligne voisine du rouleau (au repos) : très effacée et plus petite, pour qu'on ne croie pas que
-- l'unité a plusieurs traits ; seul le trait de la ligne du milieu se lit.
local function dimRow(label: Instance?)
	if not label or not label:IsA("TextLabel") then
		return
	end
	label.TextTransparency = 0.85
	label:SetAttribute("Dimmed", true)
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") then
			child.Transparency = 0.92
		elseif child:IsA("UITextSizeConstraint") then
			child.MaxTextSize = 18
		end
	end
end

local function restReel(trait)
	local before, after = neighbours(trait and trait.id)
	fillReel({ before, trait or false, after }, 2)
	local strip = refs.reelStrip
	if strip and strip.Parent then
		dimRow(strip:FindFirstChild("Row1"))
		dimRow(strip:FindFirstChild("Row3"))
	end
end

local function buildTraitCard(parent: Instance, props: { [string]: any }, trait)
	local card = new("Frame", {
		Name = "TraitCard",
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = parent,
	})
	for k, v in props do
		(card :: any)[k] = v
	end
	refs.traitCard = card
	refs.traitScale = new("UIScale", { Parent = card })
	Theme.corner(16).Parent = card
	refs.traitStroke = Theme.stroke(C.Edge, 3)
	refs.traitStroke.Parent = card
	refs.traitGradient = Theme.gradient({ WHITE, WHITE }, 90)
	refs.traitGradient.Parent = card
	local color = trait and trait.color or Color3.fromRGB(90, 90, 110)
	if trait and trait.tier >= 5 then
		-- Secret : contour doré qui tourne
		local g = Theme.gradient({ tierColor(5), WHITE, Color3.fromRGB(255, 150, 40), tierColor(5) }, 0)
		g.Parent = refs.traitStroke
		Theme.onFrame(g, function(dt)
			g.Rotation = (g.Rotation + dt * 90) % 360
		end)
	end
	-- fond : motif d'étincelles + particules du trait + reflet qui balaie
	Theme.sparkles(card, 8, 13, 0.72, 2)
	motes(card, color, trait and (6 + trait.tier * 4) or 6, 2, 31)
	sweep(card, 3, 16, trait and math.max(2.2, 5 - trait.tier * 0.6) or 5, trait and 0.18 + trait.tier * 0.04 or 0.15)
	-- Rouleau : fenêtre de 3 lignes, la ligne du milieu est le résultat (cadre « ligne de paiement »)
	local reel = new("Frame", {
		Name = "Reel",
		Position = UDim2.fromOffset(128, 10),
		Size = UDim2.new(1, -142, 0, ROW * 3),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.55,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = card,
	})
	Theme.corner(10).Parent = reel
	refs.reel = reel
	refs.payline = new("Frame", {
		Name = "Payline",
		Position = UDim2.fromOffset(0, ROW),
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = reel,
	})
	for _, y in { 0, 1 } do
		new("Frame", {
			Name = "PayEdge",
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = refs.payline,
		})
	end
	local strip = new("Frame", {
		Name = "ReelStrip",
		Size = UDim2.new(1, -16, 0, ROW * 3),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = new("Frame", {
			Name = "StripHolder",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -14, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = reel,
		}),
	})
	refs.reelStrip = strip
	-- fondu en haut et en bas de la fenêtre (les lignes voisines sont estompées)
	local fade = new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = reel,
	})
	new("UIGradient", {
		Color = ColorSequence.new(INK),
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.3, 0.8),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.65, 1),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Parent = fade,
	})
	-- flèches de la ligne de paiement
	for _, side in { 0, 1 } do
		local arrow = new("Frame", {
			Name = "PayArrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(side, side == 0 and 2 or -2, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = reel,
		})
		refs["payArrow" .. side] = arrow
	end
	refs.traitTier = Theme.label({
		Name = "TraitTier",
		Size = UDim2.new(1, -142, 0, 22),
		Position = UDim2.fromOffset(128, ROW * 3 + 12),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		MaxSize = 19,
		ZIndex = 5,
		Parent = card,
	})
	-- description lisible de loin (console, téléphone) : grande, sur deux lignes au besoin
	refs.traitDesc = Theme.label({
		Name = "TraitDesc",
		Size = UDim2.new(1, -28, 0, 36),
		Position = UDim2.fromOffset(14, ROW * 3 + 36),
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		StrokeThickness = 1.5,
		MaxSize = 15,
		ZIndex = 5,
		Parent = card,
	})
	refs.traitChips = new("Frame", {
		Name = "Chips",
		Size = UDim2.new(1, -28, 0, 26),
		Position = UDim2.fromOffset(14, ROW * 3 + 76),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = card,
	})
	Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left).Parent = refs.traitChips
	refs.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = card,
	})
	paintTraitCard(trait)
	restReel(trait)
	return card
end

-- Pendant le rouleau, la carte ne montre plus l'ancien trait (sinon on lirait deux traits à la
-- fois) : emblème « ? » qui tourne, rang « … », description et pastilles vidées, surbrillance du
-- tableau des chances retirée. paintTraitCard(résultat) repeint tout à l'arrêt.
local function suspendTraitCard()
	local card = refs.traitCard
	if not card or not card.Parent then
		return
	end
	refs.traitStroke.Color = C.Edge
	refs.traitGradient.Color = Theme.sequence({ Color3.fromRGB(52, 50, 72), Color3.fromRGB(30, 28, 44), Color3.fromRGB(16, 16, 26) })
	refs.traitTier.Text = "…   TIRAGE EN COURS   …"
	refs.traitTier.TextColor3 = C.TextDim
	refs.traitDesc.Text = ""
	Components.clear(refs.traitChips)
	if refs.emblem then
		refs.emblem:Destroy()
	end
	local holder = emblem(card, nil, 40, UDim2.fromOffset(64, 58), 4, true)
	refs.emblem = holder
	local box = holder:FindFirstChild("IconBox")
	if box then
		box:ClearAllChildren()
		local mark = Theme.label({
			Name = "Mystery",
			Text = "?",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.3, 1.3),
			FontFace = Theme.Faces.Title,
			TextColor3 = WHITE,
			StrokeThickness = 3,
			ZIndex = 6,
			Parent = box,
		})
		Theme.onFrame(mark, function(_, t)
			mark.Rotation = math.sin(t * 9) * 14
			mark.TextTransparency = 0.15 + 0.15 * math.sin(t * 12)
		end)
	end
	for _, item in refs.chanceMine or {} do
		pcall(item)
	end
	refs.chanceMine = nil
end

-- Fait défiler le rouleau puis l'arrête sur `finalId`. Plus le trait est rare, plus le rouleau
-- tourne longtemps et ralentit lentement (suspense). Bloquant (attend la fin).
local function spinReel(finalId: string?, fast: boolean, fromId: string?)
	local final = Traits.get(finalId)
	local tier = final and final.tier or 1
	local count = fast and 9 or (20 + tier * 3)
	local duration = fast and 0.75 or (1.5 + tier * 0.22)
	local order = Traits.Order
	local list = {}
	table.insert(list, Traits.get(fromId) or false)
	local rng = Random.new()
	for i = 2, count - 1 do
		-- les traits rares passent un peu plus souvent (on les voit défiler)
		local id = order[rng:NextInteger(1, #order)]
		if i == count - 1 and tier >= 3 then
			id = order[rng:NextInteger(1, 4)] -- « presque ! » juste avant l'arrêt
		end
		table.insert(list, Traits.List[id])
	end
	table.insert(list, final or false)
	local _, after = neighbours(finalId)
	table.insert(list, after)
	local strip = refs.reelStrip
	if not strip or not strip.Parent then
		return
	end
	suspendTraitCard()
	strip:ClearAllChildren()
	for i, trait in list do
		reelRow(strip, trait, i)
	end
	strip.Size = UDim2.new(1, 0, 0, #list * ROW)
	-- ligne centrée : de 1 (trait actuel) à count (résultat) ; décélération « quint » + petit
	-- dépassement puis retour (le rouleau « cale » sur la ligne)
	local startRow, endRow = 1, count
	local t0 = os.clock()
	local lastRow = startRow
	while true do
		local f = math.clamp((os.clock() - t0) / duration, 0, 1)
		local eased = 1 - (1 - f) ^ 4
		local overshoot = math.sin(f * math.pi) * 0.18 * f ^ 6
		local row = startRow + (endRow - startRow) * eased + overshoot
		if not strip.Parent then
			return
		end
		strip.Position = UDim2.fromOffset(0, -(row - 2) * ROW)
		local whole = math.floor(row + 0.5)
		if whole ~= lastRow then
			lastRow = whole
			play(tickSound)
			local passing = list[whole]
			if passing and refs.payline and refs.payline.Parent then
				refs.payline.BackgroundColor3 = tierColor(passing.tier)
			end
		end
		if f >= 1 then
			break
		end
		task.wait()
	end
	strip.Position = UDim2.fromOffset(0, -(endRow - 2) * ROW)
	play(stopSound)
	-- arrêt : seul le résultat reste lisible
	dimRow(strip:FindFirstChild("Row" .. (endRow - 1)))
	dimRow(strip:FindFirstChild("Row" .. (endRow + 1)))
end

------------------------------------------------------------------------
-- Révélations à l'écran
------------------------------------------------------------------------

local function flashCard(color: Color3, strength: number)
	local flash = refs.flash
	if not flash or not flash.Parent then
		return
	end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = setting("FxFlash") and (1 - strength) or math.max(0.75, 1 - strength * 0.3)
	Theme.tween(flash, 0.5, { BackgroundTransparency = 1 })
	local scale = refs.traitScale
	if scale then
		scale.Scale = 1 + strength * 0.08
		Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function sparkleBurst(parent: Instance, color: Color3, count: number, distance: number?)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local spark = Theme.sparkle(parent, UDim2.fromScale(0.5, 0.5), math.random(12, 22), 0.1, 12)
		for _, bar in spark:GetChildren() do
			if bar:IsA("Frame") then
				bar.BackgroundColor3 = color:Lerp(WHITE, 0.3)
			end
		end
		local d = (distance or 1) * math.random(120, 240)
		Theme.tween(spark, 0.7, {
			Position = UDim2.new(0.5, math.cos(angle) * d, 0.5, math.sin(angle) * d * 0.6),
			Rotation = math.random(-180, 180),
		}, Enum.EasingStyle.Quart)
		task.delay(0.45, function()
			if not spark.Parent then
				return
			end
			for _, bar in spark:GetChildren() do
				if bar:IsA("Frame") then
					Theme.tween(bar, 0.3, { BackgroundTransparency = 1 })
				end
			end
		end)
		task.delay(0.9, function()
			if spark.Parent then
				spark:Destroy()
			end
		end)
	end
end

-- Onde (anneau qui s'agrandit et s'efface) au centre de `parent`.
local function ringPulse(parent: Instance, color: Color3, size: number, z: number)
	local ring = new("Frame", {
		Name = "Pulse",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	Theme.round().Parent = ring
	local stroke = Theme.stroke(color:Lerp(WHITE, 0.35), 5)
	stroke.Parent = ring
	Theme.tween(ring, 0.8, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quart)
	Theme.tween(stroke, 0.8, { Transparency = 1 })
	task.delay(0.85, function()
		if ring.Parent then
			ring:Destroy()
		end
	end)
end

local function shake(frame: GuiObject?, amount: number)
	if not frame or not setting("FxShake") then
		return
	end
	local base = frame.Position
	task.spawn(function()
		for i = 1, 10 do
			if not frame.Parent then
				return
			end
			local amp = (11 - i) * amount
			frame.Position = base + UDim2.fromOffset(math.random(-amp, amp), math.random(-amp, amp))
			task.wait(0.03)
		end
		frame.Position = base
	end)
end

-- Révélation renforcée (traits rares sans cinématique) : calque plein écran au-dessus de la fenêtre.
local overlay: Frame? = nil
local overlaySkip: (() -> ())? = nil

local function endOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	overlaySkip = nil
	pcall(function()
		ContextActionService:UnbindAction("AT_TraitReveal")
	end)
end

function TraitsMenu.playReveal(trait, desc, duration: number?): Frame?
	if not trait or not gui then
		return nil
	end
	endOverlay()
	local total = duration or 2.6
	local color = trait.color
	local edge = tierColor(trait.tier)
	local root = Theme.scaledRoot(gui, "TraitReveal", 60)
	overlay = root
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		if overlay == root then
			endOverlay()
		elseif root.Parent then
			root:Destroy()
		end
	end
	overlaySkip = finish
	local catcher = new("TextButton", {
		Name = "Skip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		ZIndex = 1,
		Parent = root,
	})
	Theme.tween(catcher, 0.25, { BackgroundTransparency = 0.18 })
	catcher.Activated:Connect(finish)
	pcall(function()
		ContextActionService:BindActionAtPriority("AT_TraitReveal", function(_, state)
			if state == Enum.UserInputState.Begin then
				finish()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.Space, Enum.KeyCode.Return)
	end)
	-- halo coloré : disques concentriques très transparents empilés (un dégradé « radial », que
	-- UIGradient ne sait pas faire) + rayons + anneaux
	local glow = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(820, 820),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	local glowScale = new("UIScale", { Scale = 0.4, Parent = glow })
	Theme.tween(glowScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Quart)
	local LAYERS = 13
	for i = 1, LAYERS do
		local f = (i - 1) / (LAYERS - 1) -- 0 = disque extérieur, 1 = cœur
		local disc = new("Frame", {
			Name = "GlowLayer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 - f * 0.8, 1 - f * 0.8),
			BackgroundColor3 = color:Lerp(WHITE, f * f * 0.75),
			BackgroundTransparency = 0.9 - f * 0.04,
			ZIndex = 2,
			Parent = glow,
		})
		Theme.round().Parent = disc
	end
	sunburst(root, color:Lerp(edge, 0.35), 12, 3, 1300, UDim2.fromScale(0.5, 0.4)).Name = "Sunburst"
	ringPulse(root, edge, 900, 4)
	task.delay(0.25, function()
		if root.Parent then
			ringPulse(root, color, 700, 4)
		end
	end)
	motes(root, color, 26, 4, 77)
	-- emblème géant
	local big = emblem(root, trait.id, 92, UDim2.fromScale(0.5, 0.36), 6)
	local bigScale = new("UIScale", { Scale = 0.2, Parent = big })
	Theme.tween(bigScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	-- bandeau sombre derrière les textes (lisibles par-dessus la fenêtre)
	local band = new("Frame", {
		Name = "TextBand",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.6, -58),
		Size = UDim2.new(1, 0, 0, 228),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = root,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.28, 0.3),
			NumberSequenceKeypoint.new(0.72, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	-- titre
	local title = Theme.label({
		Name = "Title",
		Text = upper(trait.name),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(900, 96),
		FontFace = Theme.Faces.Title,
		TextColor3 = WHITE,
		StrokeThickness = 5,
		ZIndex = 8,
		Parent = root,
	})
	local tg = Theme.gradient({ Theme.light(color, 0.6), Theme.light(color, 0.15), Theme.dark(color, 0.1), Theme.light(color, 0.6) }, 0)
	tg.Parent = title
	Theme.onFrame(tg, function(_, t)
		tg.Offset = Vector2.new(math.sin(t * 1.6) * 0.4, 0)
	end)
	local ts = new("UIScale", { Scale = 2.2, Parent = title })
	title.TextTransparency = 1
	Theme.tween(ts, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.tween(title, 0.25, { TextTransparency = 0 })
	local tierLine = Theme.label({
		Name = "Tier",
		Text = stars(trait.tier) .. "  " .. upper(Traits.TierNames[trait.tier] or "") .. "  ·  " .. percent(Traits.chance(trait.id)) .. " de chance",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.6, 62),
		Size = UDim2.fromOffset(700, 30),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(edge, 0.2),
		StrokeThickness = 2.5,
		ZIndex = 8,
		Parent = root,
	})
	local visual = Traits.Visual[trait.id]
	local sub = Theme.label({
		Name = "Subtitle",
		Text = (visual and visual.motto or trait.description) .. (desc and desc.name and ("  —  " .. desc.name) or ""),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.6, 100),
		Size = UDim2.fromOffset(760, 28),
		FontFace = Theme.Faces.Bold,
		TextColor3 = WHITE,
		StrokeThickness = 2,
		ZIndex = 8,
		Parent = root,
	})
	-- pastilles des bonus
	local chips = new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.6, 142),
		Size = UDim2.fromOffset(760, 34),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = root,
	})
	Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center).Parent = chips
	for i, text in traitStats(trait) do
		local chip = new("Frame", {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.3,
			LayoutOrder = i,
			ZIndex = 8,
			Parent = chips,
		})
		Theme.round().Parent = chip
		Theme.stroke(edge, 2).Parent = chip
		Theme.padding(14, 0).Parent = chip
		Theme.label({
			Text = text,
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			TextScaled = false,
			TextSize = 20,
			FontFace = Theme.Faces.Heavy,
			StrokeThickness = 2,
			ZIndex = 9,
			Parent = chip,
		})
	end
	for _, l in { tierLine, sub } do
		l.TextTransparency = 1
		task.delay(0.3, function()
			if l.Parent then
				Theme.tween(l, 0.35, { TextTransparency = 0 })
			end
		end)
	end
	Theme.sparkles(root, 16, 99, 0.35, 7)
	sparkleBurst(root, edge, 18, 1.8)
	Theme.label({
		Name = "SkipHint",
		Text = Console.isGamepad() and "A : continuer" or (Console.isTouch() and "Touche pour continuer" or "Clique pour continuer"),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -18),
		Size = UDim2.fromOffset(300, 22),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 9,
		Parent = root,
	})
	-- flash (si autorisé) puis secousse de la fenêtre
	local veil = new("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.light(color, 0.6),
		BackgroundTransparency = setting("FxFlash") and 0.1 or 0.8,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = root,
	})
	Theme.tween(veil, 0.6, { BackgroundTransparency = 1 })
	shake(refs.windowPanel, 2)
	play(trait.tier >= 4 and fanfare or rareSound)
	task.delay(total, finish)
	root:SetAttribute("Done", false)
	return root
end

local function overlayOpen(): boolean
	return overlay ~= nil and overlay.Parent ~= nil
end

-- Effet de révélation selon le rang ; bloquant tant qu'une révélation plein écran est affichée.
local function reveal(trait, entry, desc, fast: boolean)
	if not trait then
		return
	end
	local level = Traits.revealLevel(trait.id)
	local edge = tierColor(trait.tier)
	if level >= 4 then
		flashCard(edge, 1)
		play(rareSound)
		task.wait(0.35)
		local copy = table.clone(entry)
		copy.uid = copy.uid or selected
		local scene = TraitCinematic.playTrait(trait.id, copy, desc)
		if scene then
			TraitCinematic.wait(12)
		else
			TraitsMenu.playReveal(trait, desc, fast and 1.4 or 2.6)
		end
	elseif level == 3 and fast and trait.tier < autoTarget then
		-- relance auto : un trait rare mais sous le rang visé ne coupe pas le rythme (pas de plein écran)
		flashCard(edge, 1)
		sparkleBurst(refs.traitCard or gui, edge, 14)
		play(rareSound)
	elseif level == 3 then
		flashCard(edge, 1)
		sparkleBurst(refs.traitCard or gui, edge, 14)
		TraitsMenu.playReveal(trait, desc, fast and 1.4 or 2.6)
	elseif level == 2 then
		flashCard(edge, 0.7)
		ringPulse(refs.traitCard or gui, edge, 520, 10)
		sparkleBurst(refs.traitCard or gui, edge, 10, 0.8)
		play(rareSound)
	else
		flashCard(edge, 0.4)
	end
	while overlayOpen() do
		task.wait(0.1)
	end
end

-- Une relance (renvoie l'id du trait obtenu, ou nil si impossible).
local function rerollOnce(uid: string, fast: boolean): string?
	if gems() < 1 then
		Notifications.toast("Plus de gemmes de trait ! Tue des ennemis, tape le punching-ball ou réussis des défis.", "error")
		return nil
	end
	-- l'écran joue lui-même la révélation (TraitCinematic ne la rejoue pas en recevant TraitRolled)
	TraitCinematic.claim(uid)
	local before = State.data and State.data.characters[uid]
	local fromId = before and before.trait
	local stock = gems()
	-- pendant le rouleau : bouton RELANCER grisé (« ... ») et gemme décomptée tout de suite
	if refs.rollButton and refs.rollButton.Parent then
		Components.setButtonText(refs.rollButton, "...")
		Components.setButtonColor(refs.rollButton, C.Gray)
	end
	local ok, message, traitId = State.invoke("RerollTrait", uid)
	if not ok then
		Notifications.toast(message or "Impossible pour l'instant.", "error")
		if refs.rollButton and refs.rollButton.Parent then
			Components.setButtonText(refs.rollButton, "RELANCER")
			Components.setButtonColor(refs.rollButton, C.Purple)
		end
		return nil
	end
	if refs.bankCount and refs.bankCount.Parent then
		refs.bankCount.Text = Formulas.formatNumber(math.max(0, math.min(stock - 1, gems())))
	end
	spinReel(traitId, fast, fromId)
	local entry = State.data and State.data.characters[uid]
	local desc = entry and Formulas.describe(entry)
	local trait = Traits.get(traitId)
	if trait then
		paintTraitCard(trait)
	end
	if desc and entry then
		local copy = table.clone(entry) :: any
		copy.uid = uid
		reveal(trait, copy, desc, fast)
	end
	if message and not fast then
		Notifications.toast(message, "success")
	end
	return traitId
end

local function setAuto(on: boolean)
	autoOn = on
	if refs.autoButton then
		Components.setButtonText(refs.autoButton, on and "STOP AUTO" or "RELANCE AUTO")
		Components.setButtonColor(refs.autoButton, on and C.Red or C.Blue)
	end
end

local function startAuto(uid: string)
	if rolling then
		return
	end
	setAuto(true)
	rolling = true
	task.spawn(function()
		local count = 0
		while autoOn and window and window.isOpen and selected == uid do
			local traitId = rerollOnce(uid, true)
			if not traitId then
				break
			end
			count += 1
			local trait = Traits.get(traitId)
			if trait and trait.tier >= autoTarget then
				Notifications.toast("Relance auto : " .. trait.name .. " obtenu après " .. count .. " relance" .. (count > 1 and "s" or "") .. " !", "success")
				break
			end
			task.wait(0.2)
		end
		setAuto(false)
		rolling = false
		render(true)
	end)
end

------------------------------------------------------------------------
-- Rendu
------------------------------------------------------------------------

-- Tableau des chances : une colonne par rang (en-tête coloré, total, puis chaque trait avec
-- son icône, son nom et sa chance ; le trait actuel est surligné).
-- largeur des colonnes selon leurs noms (« Célérité III » chez les Rares, un seul trait Secret)
local COLUMN_WIDTH = { 0.2, 0.215, 0.23, 0.17, 0.185 }

local function chancesTable(parent: Instance, y: number)
	local box = new("Frame", {
		Name = "Chances",
		Size = UDim2.new(1, -24, 1, -y - 12),
		Position = UDim2.fromOffset(12, y),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Components.sectionTitle(box, "CHANCES PAR RANG", { Size = UDim2.new(0.5, 0, 0, 22), TextColor3 = ACCENT })
	Theme.label({
		Text = "Chaque relance tire au hasard parmi tous les traits",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		Size = UDim2.new(0.5, 0, 0, 16),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 1,
		MaxSize = 14,
		Parent = box,
	})
	local row = new("Frame", { Name = "Columns", Size = UDim2.new(1, 0, 1, -28), Position = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, Parent = box })
	Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = row
	local current = selected and State.data and State.data.characters[selected]
	local currentTrait = current and Traits.get(current.trait)
	for tier = 1, 5 do
		local color = tierColor(tier)
		local total = 0
		local items = {}
		for _, id in Traits.Order do
			local trait = Traits.List[id]
			if trait.tier == tier then
				total += Traits.chance(id)
				table.insert(items, 1, trait)
			end
		end
		local isCurrent = currentTrait ~= nil and currentTrait.tier == tier
		local col = new("Frame", {
			Name = "Tier" .. tier,
			Size = UDim2.new(COLUMN_WIDTH[tier], -7, 1, 0),
			BackgroundColor3 = WHITE,
			ClipsDescendants = true,
			LayoutOrder = tier,
			Parent = row,
		})
		Theme.corner(12).Parent = col
		local colStroke = Theme.stroke(isCurrent and WHITE or Theme.dark(color, 0.25), isCurrent and 3 or 2)
		colStroke.Parent = col
		if isCurrent then
			refs.chanceMine = refs.chanceMine or {}
			table.insert(refs.chanceMine, function()
				colStroke.Color = Theme.dark(color, 0.25)
				colStroke.Thickness = 2
			end)
		end
		Theme.gradient({ Theme.dark(color, 0.62), Color3.fromRGB(16, 16, 24), Color3.fromRGB(12, 12, 18) }, 90).Parent = col
		-- en-tête
		local head = new("Frame", {
			Name = "Head",
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = col,
		})
		Theme.gradient({ Theme.light(color, 0.1), Theme.dark(color, 0.3) }, 90).Parent = head
		if tier >= 4 then
			sweep(head, 2, 0, 3.5 - (tier - 4), 0.35)
		end
		-- nom du rang (une ligne pleine largeur), puis total du rang et étoiles
		Theme.label({
			Name = "TierName",
			Text = upper(Traits.TierNames[tier] or ""),
			Size = UDim2.new(1, -12, 0, 19),
			Position = UDim2.fromOffset(7, 2),
			FontFace = Theme.Faces.Title,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 2,
			MaxSize = 18,
			ZIndex = 3,
			Parent = head,
		})
		Theme.label({
			Name = "TierTotal",
			Text = percent(total),
			Size = UDim2.new(0.5, -7, 0, 14),
			Position = UDim2.fromOffset(7, 21),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = Theme.light(color, 0.6),
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			MaxSize = 14,
			ZIndex = 3,
			Parent = head,
		})
		Theme.label({
			Name = "TierStars",
			Text = stars(tier),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0.5, -6, 0, 12),
			Position = UDim2.new(1, -6, 0, 22),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 1,
			MaxSize = 12,
			ZIndex = 3,
			Parent = head,
		})
		local list = new("Frame", { Name = "List", Size = UDim2.new(1, -10, 1, -42), Position = UDim2.fromOffset(5, 42), BackgroundTransparency = 1, Parent = col })
		Theme.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left).Parent = list
		-- lignes lisibles de loin (TV, téléphone) : nom en grand, chance en gras ; une barre de la
		-- couleur du trait remplace l'icône pour laisser toute la place au texte
		for i, trait in items do
			local mine = currentTrait == trait
			local line = new("Frame", {
				Name = "Line",
				Size = UDim2.new(1, 0, 0, 25),
				BackgroundColor3 = mine and Theme.dark(color, 0.2) or BLACK,
				BackgroundTransparency = mine and 0.1 or 0.6,
				LayoutOrder = i,
				Parent = list,
			})
			Theme.corner(7).Parent = line
			local lineStroke = Theme.stroke(WHITE, 1.5)
			lineStroke.Enabled = mine
			lineStroke.Parent = line
			local bar = new("Frame", {
				Name = "Bar",
				Position = UDim2.fromOffset(3, 4),
				Size = UDim2.new(0, 4, 1, -8),
				BackgroundColor3 = Theme.light(trait.color, 0.2),
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = line,
			})
			Theme.round().Parent = bar
			local name = Theme.label({
				Name = "TraitName",
				Text = trait.name,
				Size = UDim2.new(1, -58, 1, -2),
				Position = UDim2.fromOffset(11, 1),
				FontFace = Theme.Faces.Heavy,
				TextColor3 = mine and WHITE or Theme.light(trait.color, 0.4),
				TextXAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 1.5,
				MaxSize = 14,
				ZIndex = 2,
				Parent = line,
			})
			Theme.label({
				Name = "Chance",
				Text = percent(Traits.chance(trait.id)),
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.new(0, 44, 1, -2),
				Position = UDim2.new(1, -3, 0, 1),
				FontFace = Theme.Faces.Heavy,
				TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Right,
				StrokeThickness = 1.5,
				MaxSize = 13,
				ZIndex = 2,
				Parent = line,
			})
			if mine then
				refs.chanceMine = refs.chanceMine or {}
				table.insert(refs.chanceMine, function()
					line.BackgroundColor3 = BLACK
					line.BackgroundTransparency = 0.6
					lineStroke.Enabled = false
					name.TextColor3 = Theme.light(trait.color, 0.4)
				end)
			end
		end
	end
end

-- Ligne de statistique de la fiche (icône, nom, valeur, bonus du trait).
local function statLine(parent: Instance, order: number, icon: string, name: string, value: string, bonus: string?, color: Color3)
	local line = new("Frame", {
		Name = "Stat",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.45,
		LayoutOrder = order,
		ZIndex = 4,
		Parent = parent,
	})
	Theme.corner(8).Parent = line
	local ib = new("Frame", { Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ZIndex = 4, Parent = line })
	Icons.make(icon, ib, { px = 18, color = color, ink = INK, zindex = 5 })
	Theme.label({
		Text = name,
		Size = UDim2.new(0.42, 0, 1, -6),
		Position = UDim2.fromOffset(26, 3),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1,
		MaxSize = 14,
		ZIndex = 5,
		Parent = line,
	})
	Theme.label({
		Text = value .. (bonus and ('  <font color="#7CFF8A">' .. bonus .. "</font>") or ""),
		RichText = true,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.58, -8, 1, -6),
		Position = UDim2.new(1, -6, 0, 3),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 1.5,
		MaxSize = 15,
		ZIndex = 5,
		Parent = line,
	})
end

local function renderDetail()
	local holder = refs.detail
	Components.clear(holder)
	refs.traitCard = nil
	refs.emblem = nil
	refs.chanceMine = nil
	local data = State.data
	local entry = data and selected and data.characters[selected]
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
	chancesTable(sheet, 364)
	if not entry then
		Components.emptyState(sheet, "Choisis une unité à gauche pour relancer son trait.", "gem").Position = UDim2.new(0, 10, 0.12, 0)
		return
	end
	local desc = Formulas.describe(entry)
	if not desc then
		return
	end
	local trait = Traits.get(entry.trait)
	local glow = trait and trait.color or Color3.fromRGB(90, 90, 120)
	local edge = trait and tierColor(trait.tier) or C.Edge

	-- Portrait (fond aux couleurs du trait, rayons si rare, particules, socle lumineux)
	local portrait = new("Frame", {
		Name = "Portrait",
		Size = UDim2.fromOffset(250, 346),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(14).Parent = portrait
	Theme.stroke(edge, 3).Parent = portrait
	Theme.gradient({ Theme.dark(glow, 0.3), Theme.dark(glow, 0.72), Color3.fromRGB(10, 10, 16) }, 90).Parent = portrait
	if trait and trait.tier >= 3 then
		sunburst(portrait, glow, 7 + trait.tier, 1, 600, UDim2.fromScale(0.5, 0.48))
	end
	motes(portrait, glow, trait and (6 + trait.tier * 3) or 5, 1, 53)
	local pedestal = new("Frame", {
		Name = "Pedestal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(196, 44),
		BackgroundColor3 = glow,
		BackgroundTransparency = 0.3,
		Parent = portrait,
	})
	Theme.round().Parent = pedestal
	Theme.gradient({ WHITE, glow }, 90, { 0.15, 0.6 }).Parent = pedestal
	local viewArea = new("Frame", {
		Name = "ViewArea",
		Size = UDim2.new(1, 0, 1, -96),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = portrait,
	})
	local viewport = Components.characterViewport(viewArea, desc.look, true, entry)
	viewport.ZIndex = 2
	Theme.label({
		Text = desc.name,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 28),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		ZIndex = 3,
		Parent = portrait,
	})
	local rarity = Components.rarityTag(portrait, Components.rarityOf(entry, desc), { Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(112, 22), ZIndex = 3 })
	-- Components met le nom en majuscules sans gérer les accents (« LéGENDAIRE ») : on corrige.
	for _, d in rarity:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = upper(d.Text)
		end
	end
	Theme.label({
		Text = "Nv." .. tostring(entry.level or 1) .. "  " .. string.rep("★", entry.stars or 1),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 42),
		Size = UDim2.fromOffset(110, 20),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = portrait,
	})
	-- Statistiques avec le bonus du trait
	local stats = new("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, 84),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = portrait,
	})
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left).Parent = stats
	local function pct(v: number?): string?
		return v and ("+" .. math.floor(v * 100) .. " %") or nil
	end
	local okP, power = pcall(Formulas.power, entry)
	local okH, hp = pcall(Formulas.maxHp, entry)
	local okI, income = pcall(Formulas.income, entry)
	statLine(stats, 1, "sword", "Puissance", okP and Formulas.formatNumber(power) or "?", pct(trait and trait.power), Color3.fromRGB(255, 120, 100))
	statLine(stats, 2, "heart", "PV", okH and Formulas.formatNumber(hp) or "?", pct(trait and trait.hp), Color3.fromRGB(255, 90, 130))
	statLine(stats, 3, "coin", "Revenu", okI and ("¥ " .. Formulas.formatNumber(income) .. "/s") or "?", pct(trait and trait.coins), C.Gold)

	-- Trait actuel + boutons
	local right = new("Frame", { Name = "Right", Size = UDim2.new(1, -290, 0, 350), Position = UDim2.fromOffset(276, 10), BackgroundTransparency = 1, Parent = sheet })
	Components.sectionTitle(right, "TRAIT ACTUEL", { Size = UDim2.new(0.6, 0, 0, 24), TextColor3 = ACCENT })
	Theme.label({
		Name = "Owner",
		Text = "sur " .. desc.name,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(0.4, 0, 0, 18),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 1,
		MaxSize = 15,
		Parent = right,
	})
	buildTraitCard(right, { Size = UDim2.new(1, 0, 0, CARD_H), Position = UDim2.fromOffset(0, 28) }, trait)
	local uid = selected :: string
	local count = gems()
	local buttonsY = 28 + CARD_H + 8
	refs.rollButton = Components.button({
		Text = "RELANCER",
		Icon = "dice",
		Color = count > 0 and C.Purple or C.Gray,
		Size = UDim2.new(0.66, -6, 0, 62),
		Position = UDim2.fromOffset(0, buttonsY),
		TextSize = 34,
		Hint = "A",
		Parent = right,
		OnClick = function()
			if rolling then
				return
			end
			if autoOn then
				setAuto(false)
			end
			rolling = true
			rerollOnce(uid, false)
			rolling = false
			render(true)
		end,
	})
	refs.rollButton:SetAttribute("SelKey", "roll")
	if count > 0 then
		sweep(refs.rollButton:FindFirstChild("Face") :: Frame, 4, 12, 2.6, 0.3)
	end
	-- coût de la relance
	local cost = new("Frame", {
		Name = "Cost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, buttonsY),
		Size = UDim2.new(0.34, -6, 0, 57),
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		BackgroundTransparency = 0.15,
		Parent = right,
	})
	Theme.corner(14).Parent = cost
	Theme.stroke(count > 0 and GEM or C.Red, 2).Parent = cost
	Components.gem(cost, GEM, 26, UDim2.new(0, 30, 0.5, 0))
	Theme.label({
		Text = "COÛT",
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -62, 0, 16),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1,
		Parent = cost,
	})
	Theme.label({
		Name = "Amount",
		Text = "1 gemme",
		Position = UDim2.fromOffset(56, 22),
		Size = UDim2.new(1, -62, 0, 28),
		FontFace = Theme.Faces.Title,
		TextColor3 = count > 0 and Color3.fromRGB(150, 236, 255) or Color3.fromRGB(255, 90, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = cost,
	})
	-- Relance auto : s'arrête au rang choisi
	local autoY = buttonsY + 70
	refs.autoButton = Components.button({
		Text = autoOn and "STOP AUTO" or "RELANCE AUTO",
		Icon = "fast",
		Color = autoOn and C.Red or C.Blue,
		Size = UDim2.new(0.5, -6, 0, 42),
		Position = UDim2.fromOffset(0, autoY),
		TextSize = 20,
		Parent = right,
		OnClick = function()
			if autoOn then
				setAuto(false)
			else
				startAuto(uid)
			end
		end,
	})
	refs.autoButton:SetAttribute("SelKey", "auto")
	local target = new("Frame", {
		Name = "AutoTarget",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, autoY),
		Size = UDim2.new(0.5, -6, 0, 40),
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BackgroundTransparency = 0.15,
		Parent = right,
	})
	Theme.corner(12).Parent = target
	Theme.stroke(tierColor(autoTarget), 2).Parent = target
	Theme.label({
		Text = "S'ARRÊTE AU RANG",
		Size = UDim2.new(1, -96, 0, 13),
		Position = UDim2.fromOffset(48, 4),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.TextDim,
		StrokeThickness = 1,
		Parent = target,
	})
	refs.autoTargetLabel = Theme.label({
		Text = upper(Traits.TierNames[autoTarget] or "") .. (autoTarget < 5 and " +" or ""),
		Size = UDim2.new(1, -96, 0, 22),
		Position = UDim2.fromOffset(48, 17),
		FontFace = Theme.Faces.Title,
		TextColor3 = tierColor(autoTarget),
		StrokeThickness = 2,
		Parent = target,
	})
	local function arrow(icon: string, x: number, delta: number)
		local b = Components.button({
			Text = "",
			Icon = icon,
			Color = C.Purple,
			Size = UDim2.fromOffset(38, 32),
			AnchorPoint = Vector2.new(x, 0.5),
			Position = UDim2.new(x, x == 0 and 4 or -4, 0.5, 0),
			Parent = target,
			OnClick = function()
				local index = table.find(AUTO_TARGETS, autoTarget) or 2
				index = math.clamp(index + delta, 1, #AUTO_TARGETS)
				autoTarget = AUTO_TARGETS[index]
				render(true)
			end,
		})
		b:SetAttribute("SelKey", "target" .. delta)
		return b
	end
	arrow("arrowLeft", 0, -1)
	arrow("arrowRight", 1, 1)
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
	for i = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[i]
		local card = Components.characterCard(refs.grid, item.entry, {
			size = UDim2.fromOffset(112, 150),
			selKey = item.uid,
			selected = item.uid == selected,
			inTeam = State.inTeam(item.uid),
			layoutOrder = i,
			onClick = function()
				if rolling then
					return
				end
				if autoOn then
					setAuto(false)
				end
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
	local n = gems()
	if refs.bankCount then
		refs.bankCount.Text = Formulas.formatNumber(n)
		refs.bankLabel.Text = n > 1 and "GEMMES DE TRAIT" or "GEMME DE TRAIT"
	end
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
	local parts = { tostring(selected), tostring(data.traitCrystals), tostring(page), tostring(autoTarget), tostring(autoOn) }
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

-- Réserve de gemmes (en haut à gauche) : gros compteur + achat.
local function buildBank(parent: Instance)
	local bank = new("Frame", {
		Name = "Bank",
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = parent,
	})
	Theme.corner(14).Parent = bank
	Theme.stroke(Theme.dark(GEM, 0.2), 2.5).Parent = bank
	Theme.gradient({ Theme.dark(GEM, 0.45), Color3.fromRGB(14, 30, 44), Color3.fromRGB(12, 14, 22) }, 0).Parent = bank
	motes(bank, GEM, 8, 1, 5)
	sweep(bank, 2, 14, 4.5, 0.18)
	local gem = Components.gem(bank, GEM, 34, UDim2.fromOffset(40, 37))
	gem.ZIndex = 3
	Theme.onFrame(gem, function(_, t)
		gem.Rotation = 45 + math.sin(t * 2) * 6
	end)
	refs.bankCount = Theme.label({
		Name = "Count",
		Text = "0",
		Position = UDim2.fromOffset(76, 6),
		Size = UDim2.new(1, -150, 0, 40),
		FontFace = Theme.Faces.Title,
		TextColor3 = Color3.fromRGB(170, 240, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = bank,
	})
	refs.bankLabel = Theme.label({
		Name = "Label",
		Text = "GEMMES DE TRAIT",
		Position = UDim2.fromOffset(78, 46),
		Size = UDim2.new(1, -150, 0, 18),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		ZIndex = 3,
		Parent = bank,
	})
	local buy = Components.button({
		Text = "+",
		Color = C.Green,
		Size = UDim2.fromOffset(60, 56),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		TextSize = 40,
		Parent = bank,
		OnClick = function()
			-- packs de gemmes contre des Robux (boutique Robux) ; sinon, on va en gagner en jouant
			if Menus.exists("RobuxShop") then
				Menus.open("RobuxShop", "packs")
			else
				Menus.open("Quests", "afk")
			end
		end,
	})
	buy.Name = "BuyGems"
	buy.ZIndex = 4
	buy:SetAttribute("SelKey", "buy")
	return bank
end

function TraitsMenu.init(screenGui: ScreenGui)
	gui = screenGui
	window = Components.window(gui, "TRAITS", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "gem",
		subtitle = "1 gemme de trait = 1 relance du trait d'une unité",
	})
	local content = window.content
	refs.windowPanel = content:FindFirstAncestor("Window")
	-- fenêtre remontée : la barre d'aides manette (A Choisir / B Fermer), posée sous la fenêtre,
	-- reste entièrement dans l'écran
	if refs.windowPanel then
		refs.windowPanel.Position = UDim2.new(0.5, 0, 0.5, -16)
		-- aides manette sur une pastille sombre : lisibles même par-dessus le bandeau du HUD
		local hints = refs.windowPanel:FindFirstChild("PadHints", true)
		if hints and hints:IsA("Frame") then
			hints.Size = UDim2.fromOffset(0, 36)
			hints.AutomaticSize = Enum.AutomaticSize.X
			hints.BackgroundColor3 = INK
			hints.BackgroundTransparency = 0
			Theme.round().Parent = hints
			Theme.padding(18, 0).Parent = hints
		end
	end
	local left = new("Frame", { Name = "Left", Size = UDim2.new(0, 376, 1, 0), BackgroundTransparency = 1, Parent = content })
	buildBank(left)
	refs.grid = Components.cardGrid(left, Vector2.new(112, 150), { Name = "Grid", Size = UDim2.new(1, 0, 1, -184), Position = UDim2.fromOffset(0, 82) }, 8)
	refs.pager = Components.pager(left, { Position = UDim2.new(0, 0, 1, -96) }, function(target)
		page = target
		render(true)
	end)
	local earn = Components.button({
		Text = "GAGNER DES GEMMES",
		Icon = "target",
		Color = Color3.fromRGB(30, 150, 170),
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.new(0, 0, 1, -46),
		TextSize = 20,
		Parent = left,
		OnClick = function()
			Menus.open("Quests", "afk")
		end,
	})
	earn:SetAttribute("SelKey", "earn")
	refs.detail = new("Frame", {
		Name = "DetailHolder",
		Size = UDim2.new(1, -388, 1, 0),
		Position = UDim2.fromOffset(388, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Components.registerWindow(Menus, "Traits", window, function(arg)
		if type(arg) == "string" then
			selected = arg
		end
		render(true)
	end, function()
		return refs.rollButton or refs.selectedCard or window.firstSelectable()
	end)
	local baseClose = window.onClose
	window.onClose = function()
		setAuto(false)
		if baseClose then
			baseClose()
		end
	end
	State.onChanged(function()
		render()
	end)
end

-- Pour les tests : interrompt la révélation plein écran et la cinématique en cours.
function TraitsMenu.skipCinematic()
	if overlaySkip then
		overlaySkip()
	end
	TraitCinematic.skip()
end

function TraitsMenu.isRolling(): boolean
	return rolling
end

return TraitsMenu
