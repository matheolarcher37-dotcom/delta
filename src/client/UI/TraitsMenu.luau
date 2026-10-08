-- TRAITS (Autel des Traits) : relancer le trait d'une unité avec une GEMME DE TRAIT
-- (= Cristal de Trait : 1 gemme = 1 relance ; on en gagne en combat, au punching-ball de la zone
-- anti-AFK et en défis).
--
-- À gauche : les gemmes, les unités et un bouton pour aller gagner des gemmes.
-- À droite : le portrait de l'unité (lueur de la couleur de son trait), la carte du trait actuel
-- (rouleau qui défile puis s'arrête sur le résultat), RELANCER, la RELANCE AUTO (s'arrête au rang
-- choisi) et l'échelle des chances par rang.
--
-- Animations quand c'est rare (vues seulement par le joueur) :
--   • Rare : éclair, secousse et étincelles sur la carte ;
--   • Mythique (Céleste, Midas) : « ascension » plein écran, rayons et anneaux de lumière ;
--   • Secret (MONARQUE) : petite cinématique dans une salle du trône où des persos viennent
--     s'agenouiller devant ton unité, puis une couronne descend sur sa tête.
-- Toutes se passent d'un clic, d'un toucher ou avec A / B à la manette.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared.Config.Traits)
local Characters = require(Shared.Config.Characters)
local QuestsConfig = require(Shared.Config.Quests)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local Console = require(script.Parent.Console)
local State = require(script.Parent.Parent.State)

local TraitsMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local ACCENT = Color3.fromRGB(50, 200, 240)
local GEM = QuestsConfig.Gems.Color
local GOLD = Color3.fromRGB(255, 206, 64)

local PAGE_SIZE = 6
local AUTO_TARGETS = { 3, 4, 5 } -- rangs d'arrêt de la relance auto

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
local tickSound = sound("rbxasset://sounds/clickfast.wav", 0.25)
local rareSound = sound("rbxasset://sounds/electronicpingshort.wav", 0.5)
local fanfare = sound("rbxasset://sounds/victory.wav", 0.45)

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

-- Bonus d'un trait en petites pastilles (« +200 % puissance »...).
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
		table.insert(list, math.floor(trait.lifesteal * 100) .. " % vol vie")
	end
	return list
end

------------------------------------------------------------------------
-- Carte du trait (rouleau)
------------------------------------------------------------------------

-- Remplit la carte avec un trait (ou « aucun trait »).
local function paintTraitCard(trait)
	local card = refs.traitCard
	if not card or not card.Parent then
		return
	end
	local color = trait and trait.color or Color3.fromRGB(70, 70, 90)
	refs.traitStroke.Color = trait and tierColor(trait.tier) or C.Edge
	refs.traitGradient.Color = Theme.sequence({ Theme.light(color, 0.1), Theme.dark(color, 0.45), Theme.dark(color, 0.75) })
	refs.traitName.Text = trait and trait.name or "AUCUN TRAIT"
	refs.traitTier.Text = trait and (stars(trait.tier) .. "  " .. upper(Traits.TierNames[trait.tier] or "")) or "RELANCE POUR OBTENIR UN BONUS"
	refs.traitTier.TextColor3 = trait and tierColor(trait.tier) or C.TextDim
	refs.traitDesc.Text = trait and trait.description or "Chaque trait donne un bonus permanent à l'unité."
	Components.clear(refs.traitChips)
	for i, text in traitStats(trait) do
		local chip = new("Frame", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.45,
			LayoutOrder = i,
			Parent = refs.traitChips,
		})
		Theme.round().Parent = chip
		Theme.padding(8, 0).Parent = chip
		Theme.label({
			Text = text,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			TextScaled = false,
			TextSize = 14,
			FontFace = Theme.Faces.Heavy,
			StrokeThickness = 1.5,
			Parent = chip,
		})
	end
end

local function buildTraitCard(parent: Instance, props: { [string]: any })
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
	Theme.corner(14).Parent = card
	refs.traitStroke = Theme.stroke(C.Edge, 3)
	refs.traitStroke.Parent = card
	refs.traitGradient = Theme.gradient({ WHITE, WHITE }, 90)
	refs.traitGradient.Parent = card
	Theme.sparkles(card, 7, 13, 0.7)
	refs.traitName = Theme.label({
		Name = "TraitName",
		Size = UDim2.new(1, -24, 0, 38),
		Position = UDim2.fromOffset(14, 8),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = card,
	})
	refs.traitTier = Theme.label({
		Name = "TraitTier",
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(14, 48),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = card,
	})
	refs.traitDesc = Theme.label({
		Name = "TraitDesc",
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(14, 72),
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		StrokeThickness = 1.5,
		MaxSize = 18,
		ZIndex = 3,
		Parent = card,
	})
	refs.traitChips = new("Frame", {
		Name = "Chips",
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(14, 100),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = card,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	layout.Parent = refs.traitChips
	refs.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = card,
	})
	return card
end

------------------------------------------------------------------------
-- Effets de révélation dans la fenêtre
------------------------------------------------------------------------

local function flashCard(color: Color3, strong: boolean)
	local flash = refs.flash
	if not flash or not flash.Parent then
		return
	end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = strong and 0.05 or 0.35
	Theme.tween(flash, strong and 0.6 or 0.35, { BackgroundTransparency = 1 })
	local scale = refs.traitScale
	if scale then
		scale.Scale = strong and 1.12 or 1.05
		Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function sparkleBurst(parent: Instance, color: Color3, count: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local spark = Theme.sparkle(parent, UDim2.fromScale(0.5, 0.5), math.random(12, 22), 0.1, 8)
		for _, bar in spark:GetChildren() do
			if bar:IsA("Frame") then
				bar.BackgroundColor3 = color:Lerp(WHITE, 0.3)
			end
		end
		local distance = math.random(120, 240)
		Theme.tween(spark, 0.7, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance * 0.6),
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

local function shake(frame: GuiObject?)
	if not frame then
		return
	end
	local base = frame.Position
	task.spawn(function()
		for i = 1, 8 do
			if not frame.Parent then
				return
			end
			local amp = (9 - i) * 1.5
			frame.Position = base + UDim2.fromOffset(math.random(-amp, amp), math.random(-amp, amp))
			task.wait(0.03)
		end
		frame.Position = base
	end)
end

------------------------------------------------------------------------
-- Cinématiques (plein écran, vues seulement par le joueur)
------------------------------------------------------------------------

local cinematicRoot: Frame? = nil
local cinematicSkip: (() -> ())? = nil

local function endCinematic()
	if cinematicRoot then
		cinematicRoot:Destroy()
		cinematicRoot = nil
	end
	cinematicSkip = nil
	pcall(function()
		ContextActionService:UnbindAction("AT_Cinematique")
	end)
end

-- Calque plein écran + bandes noires + « passer ». Renvoie le calque et une fonction `done`.
local function cinematicLayer(name: string, duration: number): (Frame, () -> boolean)
	endCinematic()
	local root = Theme.scaledRoot(gui, "Cinematic_" .. name, 60)
	cinematicRoot = root
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		if cinematicRoot == root then
			endCinematic()
		elseif root.Parent then
			root:Destroy()
		end
	end
	cinematicSkip = finish
	local catcher = new("TextButton", {
		Name = "Skip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 40,
		Parent = root,
	})
	catcher.Activated:Connect(finish)
	pcall(function()
		ContextActionService:BindActionAtPriority("AT_Cinematique", function(_, state)
			if state == Enum.UserInputState.Begin then
				finish()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.Space, Enum.KeyCode.Return)
	end)
	local skipLabel = Theme.label({
		Text = Console.isGamepad() and "A : passer" or "Clique pour passer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -14),
		Size = UDim2.fromOffset(260, 22),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 41,
		Parent = root,
	})
	skipLabel.TextTransparency = 0.2
	task.delay(duration, finish)
	return root, function()
		return finished
	end
end

-- Bandes noires (format cinéma) qui glissent.
local function letterbox(root: Frame, z: number)
	for _, top in { true, false } do
		local bar = new("Frame", {
			Name = top and "BarTop" or "BarBottom",
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = BLACK,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = root,
		})
		Theme.tween(bar, 0.5, { Size = UDim2.new(1, 0, 0.11, 0) })
	end
end

-- Rayons de lumière qui tournent (éventail de bandes en dégradé).
local function sunburst(parent: Instance, color: Color3, count: number, z: number, position: UDim2?): Frame
	local holder = new("Frame", {
		Name = "Sunburst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1400, 1400),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	for i = 1, count do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 70, 1, 0),
			Rotation = (i / count) * 180,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = holder,
		})
		Theme.gradient({ color, WHITE, color }, 90, { 1, 0.55, 1 }).Parent = ray
	end
	Theme.onFrame(holder, function(dt)
		holder.Rotation = (holder.Rotation + dt * 12) % 360
	end)
	return holder
end

local function bigTitle(root: Frame, text: string, color: Color3, subtitle: string, z: number, y: number, x: number?)
	local title = Theme.label({
		Name = "Title",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x or 0.5, y),
		Size = UDim2.fromOffset(900, 110),
		FontFace = Theme.Faces.Title,
		TextColor3 = WHITE,
		StrokeThickness = 5,
		ZIndex = z,
		Parent = root,
	})
	local gradient = Theme.gradient({ Theme.light(color, 0.55), color, Theme.dark(color, 0.25), Theme.light(color, 0.55) }, 0)
	gradient.Parent = title
	Theme.onFrame(gradient, function(_, t)
		gradient.Offset = Vector2.new(math.sin(t * 1.6) * 0.4, 0)
	end)
	local scale = new("UIScale", { Scale = 2.4, Parent = title })
	title.TextTransparency = 1
	Theme.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.tween(title, 0.3, { TextTransparency = 0 })
	local sub = Theme.label({
		Name = "Subtitle",
		Text = subtitle,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(x or 0.5, 0, y, 76),
		Size = UDim2.fromOffset(900, 34),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = WHITE,
		StrokeThickness = 2.5,
		ZIndex = z,
		Parent = root,
	})
	sub.TextTransparency = 1
	task.delay(0.35, function()
		if sub.Parent then
			Theme.tween(sub, 0.4, { TextTransparency = 0 })
		end
	end)
	Theme.sparkles(root, 14, 99, 0.35, z)
	return title
end

-- Prépare une pose « chevalier à genou » pour un modèle d'aperçu (pièces ancrées) :
-- renvoie { [pièce] = { debout, à genoux } } dans le repère du modèle (pieds à y = 0, face -Z).
local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart" }
-- Angles de la pose « chevalier à genou » (degrés).
-- Avec des jambes R6 d'un seul bloc, la pose qui se lit le mieux (essais de rendu) est « à genoux,
-- tibias au sol » : les deux jambes à plat derrière, le torse droit, la tête baissée et le poing
-- droit posé au sol devant (le salut du chevalier). Un seul genou levé ressemblait à un grand écart.
local KNEEL = {
	frontLeg = -90, -- jambe droite à plat derrière (genou à terre)
	backLeg = 90, -- jambe gauche à plat derrière (genou à terre)
	torso = 14, -- torse presque droit, légèrement incliné
	head = 28, -- tête baissée
	fistLift = 30, -- bras droit vers l'avant : le poing touche le sol
	fistYaw = 0,
	leftArm = 10, -- bras gauche le long du corps
	drop = 1.5, -- le corps descend de la longueur des jambes repliées
}
TraitsMenu.KneelAngles = KNEEL

function TraitsMenu.kneelPose(model: Model): { [BasePart]: { CFrame } }
	-- Regroupe les pièces par membre (soudures, sans les articulations).
	local parentOf: { [BasePart]: BasePart } = {}
	local function find(p: BasePart): BasePart
		local root = p
		while parentOf[root] and parentOf[root] ~= root do
			root = parentOf[root]
		end
		return root
	end
	local function union(a: any, b: any)
		if typeof(a) == "Instance" and typeof(b) == "Instance" and a:IsA("BasePart") and b:IsA("BasePart") then
			local ra, rb = find(a), find(b)
			if ra ~= rb then
				parentOf[ra] = rb
			end
		end
	end
	local pivots: { [string]: Vector3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local ok, cf = pcall(function()
				return (d.Part0 :: BasePart).CFrame * d.C0
			end)
			if ok and d.Part1 then
				pivots[(d.Part1 :: BasePart).Name] = cf.Position
			end
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			pcall(union, (d :: any).Part0, (d :: any).Part1)
		end
	end
	local limbOfRoot: { [BasePart]: string } = {}
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limbOfRoot[find(limb)] = name
		end
	end
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local result: { [BasePart]: { CFrame } } = {}
	if not torso then
		return result
	end
	local tcf = torso.CFrame
	local right = tcf.RightVector
	local function pivot(name: string, fallback: Vector3): Vector3
		return pivots[name] or tcf:PointToWorldSpace(fallback)
	end
	local function about(p: Vector3, angle: number): CFrame
		return CFrame.new(p) * CFrame.fromAxisAngle(right, angle) * CFrame.new(-p)
	end
	-- À genoux (angles dans KNEEL) : jambes repliées à plat derrière, torse presque droit,
	-- tête baissée, poing droit posé au sol devant, main gauche le long du corps.
	local up = tcf.UpVector
	local drop = KNEEL.drop
	local hipCenter = tcf:PointToWorldSpace(Vector3.new(0, -1, 0))
	local function arm(p: Vector3, yaw: number, forward: number): CFrame
		return CFrame.new(p) * CFrame.fromAxisAngle(up, yaw) * CFrame.fromAxisAngle(right, forward) * CFrame.new(-p)
	end
	local limbMove = {
		["Right Leg"] = about(pivot("Right Leg", Vector3.new(0.5, -1, 0)), math.rad(KNEEL.frontLeg)),
		["Left Leg"] = about(pivot("Left Leg", Vector3.new(-0.5, -1, 0)), -math.rad(KNEEL.backLeg)),
		["Right Arm"] = arm(pivot("Right Arm", Vector3.new(1, 0.5, 0)), math.rad(KNEEL.fistYaw), math.rad(KNEEL.fistLift)),
		["Left Arm"] = about(pivot("Left Arm", Vector3.new(-1, 0.5, 0)), math.rad(KNEEL.leftArm)),
		Head = about(pivot("Head", Vector3.new(0, 1, 0)), -math.rad(KNEEL.head)),
	}
	local bow = about(hipCenter, -math.rad(KNEEL.torso))
	local down = CFrame.new(0, -drop, 0)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local limb = limbOfRoot[find(d)] or "Torso"
			local cf = d.CFrame
			local target = cf
			if limbMove[limb] then
				target = limbMove[limb] * target
			end
			if limb ~= "Left Leg" and limb ~= "Right Leg" then
				target = bow * target
			end
			result[d] = { cf, down * target }
		end
	end
	return result
end

local function applyPose(pose: { [BasePart]: { CFrame } }, place: CFrame, f: number)
	for part, pair in pose do
		part.CFrame = place * (if f <= 0 then pair[1] elseif f >= 1 then pair[2] else pair[1]:Lerp(pair[2], f))
	end
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Couronne d'or (anneau, pointes, gemmes).
local function buildCrown(parent: Instance): Model
	local crown = Instance.new("Model")
	crown.Name = "Crown"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Anchored = true
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.25
		if shape then
			p.Shape = shape
		end
		p.Parent = crown
		return p
	end
	-- pivot droit (sans rotation) : l'anneau est un cylindre couché qu'on ne doit pas redresser
	local base = part("Base", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), GOLD)
	base.Transparency = 1
	crown.PrimaryPart = base
	part("Ring", Vector3.new(0.45, 1.7, 1.7), CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.PartType.Cylinder)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 0.72, 0.5, math.sin(a) * 0.72)
		part("Spike", Vector3.new(0.3, 0.75, 0.3), CFrame.new(pos) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(8)), GOLD)
		part("Pearl", Vector3.new(0.26, 0.26, 0.26), CFrame.new(pos + Vector3.new(0, 0.45, 0)), Color3.fromRGB(255, 250, 230), Enum.PartType.Ball)
		part(
			"Jewel",
			Vector3.new(0.22, 0.22, 0.22),
			CFrame.new(math.cos(a + 0.6) * 0.86, 0, math.sin(a + 0.6) * 0.86),
			i % 2 == 0 and Color3.fromRGB(220, 30, 50) or Color3.fromRGB(40, 120, 255),
			Enum.PartType.Ball
		)
	end
	crown.Parent = parent
	return crown
end

-- Salle du trône (sol, tapis, estrade, trône, piliers, bannières) dans le ViewportFrame.
local function buildThroneRoom(parent: Instance)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Anchored = true
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		return p
	end
	local CYL = Enum.PartType.Cylinder
	part("Floor", Vector3.new(90, 1, 90), CFrame.new(0, -0.5, -20), Color3.fromRGB(46, 38, 52), Enum.Material.Marble)
	for i = -4, 4 do
		part("FloorLine", Vector3.new(0.12, 0.02, 90), CFrame.new(i * 8, 0.01, -20), Color3.fromRGB(70, 58, 78))
	end
	part("Carpet", Vector3.new(7, 0.1, 44), CFrame.new(0, 0.05, -22), Color3.fromRGB(150, 18, 32), Enum.Material.Fabric)
	for _, x in { -3.7, 3.7 } do
		part("CarpetTrim", Vector3.new(0.4, 0.12, 44), CFrame.new(x, 0.06, -22), GOLD, Enum.Material.Fabric)
	end
	part("DaisLow", Vector3.new(0.6, 11, 11), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 234, 222), Enum.Material.Marble, CYL)
	part("DaisTrim", Vector3.new(0.12, 11.2, 11.2), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal, CYL)
	part("DaisHigh", Vector3.new(0.6, 8, 8), CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(252, 248, 238), Enum.Material.Marble, CYL)
	part("DaisGlow", Vector3.new(0.05, 6.4, 6.4), CFrame.new(0, 1.22, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 226, 140), Enum.Material.Neon, CYL).Transparency =
		0.35
	-- Le héros ressort : grand disque doré derrière lui, anneau d'or et rayons
	-- (un ViewportFrame n'affiche pas les PointLight : la lumière est faite de couleurs vives).
	local halo =
		part("Halo", Vector3.new(0.1, 6.6, 6.6), CFrame.new(0, 5.4, 1.0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 206, 84), Enum.Material.SmoothPlastic, CYL)
	halo.Transparency = 0.05
	part("HaloRing", Vector3.new(0.12, 7.6, 7.6), CFrame.new(0, 5.4, 1.05) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal, CYL)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local long = i % 2 == 0
		part(
			"HaloRay",
			Vector3.new(0.28, long and 2.2 or 1.3, 0.08),
			CFrame.new(math.cos(a) * (long and 5 or 4.55), 5.4 + math.sin(a) * (long and 5 or 4.55), 1.85) * CFrame.Angles(0, 0, a - math.pi / 2),
			Color3.fromRGB(255, 232, 150),
			Enum.Material.Neon
		)
	end
	-- Trône
	part("ThroneSeat", Vector3.new(4, 1.2, 3), CFrame.new(0, 1.8, 2.6), Color3.fromRGB(160, 20, 36), Enum.Material.Fabric)
	part("ThroneBack", Vector3.new(4.4, 8, 0.8), CFrame.new(0, 5.2, 4.1), GOLD, Enum.Material.Metal)
	part("ThroneCushion", Vector3.new(3.4, 6.4, 0.3), CFrame.new(0, 5, 3.6), Color3.fromRGB(196, 30, 48), Enum.Material.Fabric)
	part("ThroneTop", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 9.6, 4.1), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	for _, x in { -2.4, 2.4 } do
		part("ThroneArm", Vector3.new(0.6, 2.4, 3.2), CFrame.new(x, 2.4, 2.6), GOLD, Enum.Material.Metal)
	end
	-- Piliers et bannières
	-- (rangées écartées : la caméra de 3/4 passe entre les piliers sans être masquée)
	for _, z in { -3, -15, -27 } do
		for _, x in { -27, 27 } do
			part("Pillar", Vector3.new(18, 2.2, 2.2), CFrame.new(x, 9, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 216, 200), Enum.Material.Marble, CYL)
			part("PillarCap", Vector3.new(3, 1, 3), CFrame.new(x, 18.2, z), GOLD, Enum.Material.Metal)
			part("PillarFoot", Vector3.new(3, 1, 3), CFrame.new(x, 0.5, z), Color3.fromRGB(190, 180, 168), Enum.Material.Marble)
			part("Banner", Vector3.new(0.2, 9, 3), CFrame.new(x + (x > 0 and -1.3 or 1.3), 12, z - 0.2), Color3.fromRGB(150, 18, 32), Enum.Material.Fabric)
			part("BannerTrim", Vector3.new(0.22, 0.5, 3.1), CFrame.new(x + (x > 0 and -1.3 or 1.3), 7.6, z - 0.2), GOLD, Enum.Material.Fabric)
		end
	end
	part("BackWall", Vector3.new(60, 30, 1), CFrame.new(0, 15, 8), Color3.fromRGB(60, 34, 50), Enum.Material.Plaster)
	part("BackBanner", Vector3.new(10, 18, 0.3), CFrame.new(0, 13, 7.3), Color3.fromRGB(130, 16, 30), Enum.Material.Fabric)
	part("BackEmblem", Vector3.new(0.3, 4, 4), CFrame.new(0, 15, 7.1) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal, CYL)
end

-- Persos qui s'agenouillent : les autres unités du joueur d'abord, puis des persos au hasard.
local function kneelerLooks(exceptUid: string?, count: number): { { look: any, id: string?, stars: number? } }
	local list = {}
	local seen = {}
	for _, item in State.sortedCharacters() do
		if item.uid ~= exceptUid and not item.entry.fusion and not seen[item.entry.id] then
			seen[item.entry.id] = true
			table.insert(list, { look = item.desc.look, id = item.entry.id, stars = item.entry.stars })
			if #list >= count then
				return list
			end
		end
	end
	local ids = {}
	for id in Characters.List do
		if not seen[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	while #list < count and #ids > 0 do
		local id = table.remove(ids, math.random(1, #ids))
		local look = Characters.resolveLook(id, 1)
		if look then
			table.insert(list, { look = look, id = id, stars = 1 })
		end
	end
	return list
end

-- Trajet de la caméra de la cinématique MONARQUE : { temps, position, point visé }.
local function monarchCamera(total: number): { { any } }
	return {
		-- arrivée : plan large et haut dans l'axe du tapis (personne n'est coupé par le bord)
		{ 0, Vector3.new(0, 9, -34), Vector3.new(0, 3.5, -4) },
		{ 1.6, Vector3.new(10, 9, -28), Vector3.new(0, 3.2, -5) },
		-- plan final de 3/4 : l'unité de face devant son trône, les 6 persos à genoux de profil
		{ 3, Vector3.new(18, 8.4, -23.5), Vector3.new(1.5, 3, -9) },
		{ math.max(total, 3.8), Vector3.new(17, 8, -22.5), Vector3.new(1.5, 3, -9) },
	}
end
TraitsMenu.monarchCamera = monarchCamera

-- MONARQUE : salle du trône, les persos s'agenouillent, la couronne descend.
-- `clock` (facultatif, pour les tests) remplace os.clock comme horloge de la scène.
function TraitsMenu.playMonarch(entry, desc, duration: number?, clock: (() -> number)?)
	local total = duration or 7.5
	local root, isDone = cinematicLayer("Monarque", total)
	local backdrop = new("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		ZIndex = 1,
		Parent = root,
	})
	Theme.gradient({ Color3.fromRGB(70, 30, 60), Color3.fromRGB(20, 10, 24) }, 90).Parent = backdrop
	sunburst(root, GOLD, 9, 2, UDim2.fromScale(0.5, 0.36))
	local viewport = new("ViewportFrame", {
		Name = "Scene",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(176, 150, 146),
		LightColor = Color3.fromRGB(255, 232, 186),
		LightDirection = Vector3.new(-0.5, -1, 0.7),
		ZIndex = 3,
		Parent = root,
	})
	local camera = new("Camera", { FieldOfView = 50, Parent = viewport })
	viewport.CurrentCamera = camera
	buildThroneRoom(viewport)
	-- L'unité, debout sur l'estrade
	local hero = Components.characterModel(desc.look, entry and entry.id, entry and entry.stars)
	hero.Parent = viewport
	local heroPivot = hero:GetPivot()
	hero:PivotTo(heroPivot + Vector3.new(0, 1.2, 0))
	local head = hero:FindFirstChild("Head") :: BasePart?
	local headTop = head and (head.CFrame.Position.Y + head.Size.Y * 0.5 + 0.55) or 6.9
	-- Les persos qui s'agenouillent, de part et d'autre du tapis
	local spots = {
		Vector3.new(-4.6, 0, -7),
		Vector3.new(4.6, 0, -7),
		Vector3.new(-4.6, 0, -11),
		Vector3.new(4.6, 0, -11),
		Vector3.new(-4.6, 0, -15),
		Vector3.new(4.6, 0, -15),
	}
	local kneelers = {}
	for i, info in kneelerLooks(entry and entry.uid or selected, #spots) do
		local model = Components.characterModel(info.look, info.id, info.stars)
		local pose = TraitsMenu.kneelPose(model)
		local place = CFrame.lookAt(spots[i], Vector3.new(0, 0, spots[i].Z + 12)) -- tournés vers le trône
		applyPose(pose, place, 0)
		model.Parent = viewport
		table.insert(kneelers, { pose = pose, place = place, delay = 0.7 + i * 0.16 })
	end
	local crown = buildCrown(viewport)
	local crownTarget = Vector3.new(0, headTop, 0)
	-- Caméra : arrivée dans l'axe du tapis (les persos sont debout), puis plan de 3/4 de côté
	-- qui montre les 6 persos à genou de profil et l'unité en entier devant son trône.
	local keys = monarchCamera(total)
	local now = clock or os.clock
	local start = now()
	local function step()
		local t = now() - start
		local a, b = keys[1], keys[#keys]
		for i = 1, #keys - 1 do
			if t >= keys[i][1] and t <= keys[i + 1][1] then
				a, b = keys[i], keys[i + 1]
			end
		end
		local f = smooth((t - a[1]) / math.max(0.01, b[1] - a[1]))
		if t >= b[1] then
			f = 1
		end
		local pos = a[2]:Lerp(b[2], f)
		local look = a[3]:Lerp(b[3], f)
		camera.CFrame = CFrame.lookAt(pos, look)
		for _, k in kneelers do
			applyPose(k.pose, k.place, smooth((t - k.delay) / 0.7))
		end
		local cf = smooth((t - 2.6) / 1.3)
		crown:PivotTo(CFrame.new(crownTarget + Vector3.new(0, (1 - cf) * 7, 0)) * CFrame.Angles(0, (1 - cf) * 4 + t * 0.4, 0))
	end
	step()
	Theme.onFrame(viewport, step)
	letterbox(root, 20)
	SoundService:PlayLocalSound(fanfare)
	local name = desc and desc.name or "ton unité"
	task.delay(3.7, function()
		if not isDone() and root.Parent then
			-- titre à droite : le héros (à gauche) et les persos à genou restent visibles
			bigTitle(root, "MONARQUE", GOLD, "Tous s'inclinent devant " .. name .. " !", 25, 0.22, 0.66)
			SoundService:PlayLocalSound(rareSound)
		end
	end)
	return root
end

-- MYTHIQUE (Céleste, Midas...) : ascension avec rayons et anneaux de lumière.
function TraitsMenu.playAscension(entry, desc, trait, duration: number?)
	local total = duration or 3.2
	local color = trait and trait.color or C.Cyan
	local root = cinematicLayer("Ascension", total)
	local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 1, Parent = root })
	Theme.tween(dim, 0.3, { BackgroundTransparency = 0.25 })
	sunburst(root, color, 8, 2, UDim2.fromScale(0.5, 0.45))
	for i = 1, 3 do
		local ring = new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(60, 60),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = root,
		})
		Theme.round().Parent = ring
		local stroke = Theme.stroke(color:Lerp(WHITE, 0.4), 6)
		stroke.Parent = ring
		task.delay((i - 1) * 0.35, function()
			if ring.Parent then
				Theme.tween(ring, 1.2, { Size = UDim2.fromOffset(900, 900) }, Enum.EasingStyle.Quart)
				Theme.tween(stroke, 1.2, { Transparency = 1 })
			end
		end)
	end
	local stage = new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(420, 460),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = root,
	})
	local viewport = Components.characterViewport(stage, desc.look, true, entry)
	viewport.ZIndex = 4
	local stageScale = new("UIScale", { Scale = 0.6, Parent = stage })
	Theme.tween(stageScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	letterbox(root, 20)
	SoundService:PlayLocalSound(rareSound)
	bigTitle(root, upper(trait and trait.name or "TRAIT"), color, upper(Traits.TierNames[trait and trait.tier or 4] or "") .. " · " .. (desc and desc.name or ""), 25, 0.17)
	return root
end

------------------------------------------------------------------------
-- Relance
------------------------------------------------------------------------

local function gems(): number
	return State.data and tonumber(State.data.traitCrystals) or 0
end

-- Fait défiler le rouleau puis s'arrête sur `finalId`.
local function spinReel(finalId: string?, fast: boolean)
	local order = Traits.Order
	local steps = fast and 7 or 16
	local delay = fast and 0.035 or 0.04
	for i = 1, steps do
		local random = Traits.List[order[math.random(1, #order)]]
		if i == steps and finalId then
			random = Traits.get(finalId) or random
		end
		paintTraitCard(random)
		if refs.traitName and refs.traitName.Parent then
			refs.traitName.Position = UDim2.fromOffset(14, -18)
			Theme.tween(refs.traitName, delay * 0.9, { Position = UDim2.fromOffset(14, 8) })
		end
		SoundService:PlayLocalSound(tickSound)
		task.wait(delay)
		delay *= fast and 1.08 or 1.13
	end
end

-- Effet de révélation selon le rang ; renvoie quand l'animation (bloquante) est finie.
local function reveal(trait, entry, desc)
	if not trait then
		return
	end
	if trait.tier >= 5 then
		flashCard(trait.color, true)
		TraitsMenu.playMonarch(entry, desc)
	elseif trait.tier == 4 then
		flashCard(trait.color, true)
		TraitsMenu.playAscension(entry, desc, trait)
	elseif trait.tier == 3 then
		flashCard(trait.color, true)
		shake(refs.traitCard)
		sparkleBurst(refs.traitCard, trait.color, 12)
		SoundService:PlayLocalSound(rareSound)
	else
		flashCard(trait.color, false)
	end
end

-- Une relance (renvoie l'id du trait obtenu, ou nil si impossible).
local function rerollOnce(uid: string, fast: boolean): string?
	if gems() < 1 then
		Notifications.toast("Plus de gemmes de trait ! Tue des ennemis, tape le punching-ball ou réussis des défis.", "error")
		return nil
	end
	local ok, message, traitId = State.invoke("RerollTrait", uid)
	if not ok then
		Notifications.toast(message or "Impossible pour l'instant.", "error")
		return nil
	end
	spinReel(traitId, fast)
	local entry = State.data and State.data.characters[uid]
	local desc = entry and Formulas.describe(entry)
	local trait = Traits.get(traitId)
	if desc and entry then
		reveal(trait, table.clone(entry) :: any, desc)
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
			-- laisse la cinématique se finir avant de continuer
			while cinematicRoot do
				task.wait(0.1)
			end
			task.wait(0.25)
		end
		setAuto(false)
		rolling = false
		render(true)
	end)
end

------------------------------------------------------------------------
-- Rendu
------------------------------------------------------------------------

local function chancesLadder(parent: Instance)
	local ladder = new("Frame", {
		Name = "Chances",
		Size = UDim2.new(1, -24, 0, 196),
		Position = UDim2.new(0, 12, 1, -206),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Components.sectionTitle(ladder, "CHANCES PAR RANG", { Size = UDim2.new(1, 0, 0, 22), TextColor3 = ACCENT })
	local row = new("Frame", { Size = UDim2.new(1, 0, 1, -28), Position = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, Parent = ladder })
	Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = row
	local current = selected and State.data and State.data.characters[selected]
	local currentTrait = current and Traits.get(current.trait)
	for tier = 1, 5 do
		local color = tierColor(tier)
		local total = 0
		local names = {}
		for _, id in Traits.Order do
			local trait = Traits.List[id]
			if trait.tier == tier then
				total += Traits.chance(id)
				table.insert(names, 1, { trait = trait, chance = Traits.chance(id) })
			end
		end
		local col = new("Frame", {
			Name = "Tier" .. tier,
			Size = UDim2.new(0.2, -7, 1, 0),
			BackgroundColor3 = WHITE,
			LayoutOrder = tier,
			Parent = row,
		})
		Theme.corner(10).Parent = col
		local isCurrent = currentTrait ~= nil and currentTrait.tier == tier
		Theme.stroke(isCurrent and WHITE or Theme.dark(color, 0.3), isCurrent and 3 or 2).Parent = col
		Theme.gradient({ Theme.dark(color, 0.45), Color3.fromRGB(18, 18, 26) }, 90).Parent = col
		Theme.label({
			Text = upper(Traits.TierNames[tier] or ""),
			Size = UDim2.new(1, -10, 0, 18),
			Position = UDim2.fromOffset(5, 5),
			FontFace = Theme.Faces.Title,
			TextColor3 = Theme.light(color, 0.2),
			StrokeThickness = 2,
			Parent = col,
		})
		Theme.label({
			Text = string.format("%.1f %%", total),
			Size = UDim2.new(1, -10, 0, 24),
			Position = UDim2.fromOffset(5, 24),
			FontFace = Theme.Faces.Heavy,
			StrokeThickness = 2,
			Parent = col,
		})
		local list = new("Frame", { Size = UDim2.new(1, -10, 1, -54), Position = UDim2.fromOffset(5, 52), BackgroundTransparency = 1, Parent = col })
		Theme.list(Enum.FillDirection.Vertical, 1, Enum.HorizontalAlignment.Left).Parent = list
		for i, item in names do
			Theme.label({
				Text = item.trait.name .. "  " .. string.format("%.1f", item.chance),
				Size = UDim2.new(1, 0, 0, 18),
				FontFace = Theme.Faces.Bold,
				TextColor3 = (currentTrait == item.trait) and WHITE or Theme.light(item.trait.color, 0.35),
				TextXAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 1.5,
				MaxSize = 15,
				LayoutOrder = i,
				Parent = list,
			})
		end
	end
end

local function renderDetail()
	local holder = refs.detail
	Components.clear(holder)
	refs.traitCard = nil
	local data = State.data
	local entry = data and selected and data.characters[selected]
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
	chancesLadder(sheet)
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
	-- Portrait
	local portrait = new("Frame", {
		Name = "Portrait",
		Size = UDim2.fromOffset(250, 318),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(14).Parent = portrait
	Theme.stroke(trait and tierColor(trait.tier) or C.Edge, 3).Parent = portrait
	Theme.gradient({ Theme.dark(glow, 0.35), Color3.fromRGB(20, 20, 28), Color3.fromRGB(12, 12, 18) }, 90).Parent = portrait
	if trait and trait.tier >= 3 then
		local rays = sunburst(portrait, glow, 6, 1, UDim2.fromScale(0.5, 0.55))
		rays.Size = UDim2.fromOffset(520, 520)
	end
	local pedestal = new("Frame", {
		Name = "Pedestal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(190, 46),
		BackgroundColor3 = glow,
		BackgroundTransparency = 0.35,
		Parent = portrait,
	})
	Theme.round().Parent = pedestal
	Theme.gradient({ WHITE, glow }, 90, { 0.2, 0.6 }).Parent = pedestal
	local viewport = Components.characterViewport(portrait, desc.look, true, entry)
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
	local rarity = Components.rarityTag(portrait, Components.rarityOf(entry, desc), { Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(110, 22), ZIndex = 3 })
	-- Components met le nom en majuscules sans gérer les accents (« LéGENDAIRE ») : on corrige.
	for _, d in rarity:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = upper(d.Text)
		end
	end

	-- Trait actuel + boutons
	local right = new("Frame", { Name = "Right", Size = UDim2.new(1, -290, 0, 318), Position = UDim2.fromOffset(276, 12), BackgroundTransparency = 1, Parent = sheet })
	Components.sectionTitle(right, "TRAIT ACTUEL", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = ACCENT })
	buildTraitCard(right, { Size = UDim2.new(1, 0, 0, 132), Position = UDim2.fromOffset(0, 28) })
	paintTraitCard(trait)
	local uid = selected :: string
	local count = gems()
	refs.rollButton = Components.button({
		Text = "RELANCER",
		Icon = "dice",
		Color = count > 0 and C.Purple or C.Gray,
		Size = UDim2.new(0.62, -6, 0, 58),
		Position = UDim2.fromOffset(0, 172),
		Hint = "A",
		Parent = right,
		OnClick = function()
			if rolling then
				return
			end
			rolling = true
			rerollOnce(uid, false)
			while cinematicRoot do
				task.wait(0.1)
			end
			rolling = false
			render(true)
		end,
	})
	refs.rollButton:SetAttribute("SelKey", "roll")
	local cost = Components.price(right, 1, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 180),
		Size = UDim2.new(0.38, -6, 0, 42),
	}, "crystals")
	Components.setPriceAffordable(cost, count > 0, "crystals")
	local costLabel = cost:FindFirstChild("Amount") :: TextLabel?
	if costLabel then
		costLabel.Text = "1 gemme"
	end
	-- Relance auto : s'arrête au rang choisi
	refs.autoButton = Components.button({
		Text = autoOn and "STOP AUTO" or "RELANCE AUTO",
		Icon = "fast",
		Color = autoOn and C.Red or C.Blue,
		Size = UDim2.new(0.62, -6, 0, 50),
		Position = UDim2.fromOffset(0, 240),
		TextSize = 22,
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
		Position = UDim2.new(1, 0, 0, 240),
		Size = UDim2.new(0.38, -6, 0, 50),
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BackgroundTransparency = 0.2,
		Parent = right,
	})
	Theme.corner(12).Parent = target
	Theme.stroke(tierColor(autoTarget), 2).Parent = target
	Theme.label({
		Text = "ARRÊT AU RANG",
		Size = UDim2.new(1, -80, 0, 14),
		Position = UDim2.fromOffset(40, 5),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.TextDim,
		StrokeThickness = 1,
		Parent = target,
	})
	refs.autoTargetLabel = Theme.label({
		Text = (Traits.TierNames[autoTarget] or "") .. (autoTarget < 5 and " +" or ""),
		Size = UDim2.new(1, -80, 0, 24),
		Position = UDim2.fromOffset(40, 20),
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
			Size = UDim2.fromOffset(36, 42),
			AnchorPoint = Vector2.new(x, 0.5),
			Position = UDim2.new(x, x == 0 and 3 or -3, 0.5, 0),
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
	Components.hintText(right, "1 relance = 1 gemme de trait. La relance auto s'arrête au rang choisi (ou sans gemmes).", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 298),
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
	refs.grid.Size = UDim2.new(1, 0, 1, pages > 1 and -150 or -104)
	for i = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[i]
		local card = Components.characterCard(refs.grid, item.entry, {
			selKey = item.uid,
			selected = item.uid == selected,
			inTeam = State.inTeam(item.uid),
			layoutOrder = i,
			onClick = function()
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
	local n = data and data.traitCrystals or 0
	Components.setPillText(refs.crystals, Formulas.formatNumber(n) .. " gemme" .. (n > 1 and "s" or "") .. " de trait")
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

function TraitsMenu.init(screenGui: ScreenGui)
	gui = screenGui
	window = Components.window(gui, "TRAITS", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "gem",
		subtitle = "1 gemme de trait = 1 relance du trait d'une unité",
	})
	local content = window.content
	local left = new("Frame", { Name = "Left", Size = UDim2.new(0, 400, 1, 0), BackgroundTransparency = 1, Parent = content })
	local toolbar = new("Frame", { Name = "Toolbar", Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = left })
	-- Les gemmes se gagnent en jeu (ennemis, boss, punching-ball, défis) : pas d'achat en pièces ici.
	refs.crystals = Components.pill(toolbar, "gem", "0 gemme de trait", GEM, { Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 2) })
	refs.grid = Components.cardGrid(left, Vector2.new(118, 152), { Name = "Grid", Size = UDim2.new(1, 0, 1, -104), Position = UDim2.fromOffset(0, 52) }, 8)
	refs.pager = Components.pager(left, { Position = UDim2.new(0, 0, 1, -96) }, function(target)
		page = target
		render(true)
	end)
	local earn = Components.button({
		Text = "GAGNER DES GEMMES",
		Icon = "gem",
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
		Size = UDim2.new(1, -412, 1, 0),
		Position = UDim2.fromOffset(412, 0),
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

-- Pour les tests : interrompt une cinématique en cours.
function TraitsMenu.skipCinematic()
	if cinematicSkip then
		cinematicSkip()
	end
end

return TraitsMenu
