-- Construit les persos d'animé au format avatar Roblox R6 (comme les jeux d'animé récents) :
--   * corps R6 standard (Torso 2x2x1, bras et jambes 1x2x1) avec les articulations officielles
--     ("Neck", "Left Shoulder"...) : les animations par défaut de Roblox fonctionnent dessus ;
--   * tête arrondie avec un visage d'animé dessiné (Painter) ;
--   * tenue peinte sur le torse, mèches de cheveux en ellipsoïdes, accessoires 3D.
--
-- Le modèle est construit pieds au sol en (0,0,0), face vers -Z, puis déplacé via PivotTo.
-- Pour remplacer un perso par ton propre modèle (fait dans Studio ou avec des objets du catalogue),
-- voir Config/Avatars.luau et le dossier ModelesPersos (README).

local Painter = require(script.Parent.Painter)

local CharacterBuilder = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(25, 22, 28)
local METAL = Color3.fromRGB(195, 200, 210)
local GOLD = Color3.fromRGB(255, 200, 60)
local DEFAULT_SHOES = Color3.fromRGB(45, 40, 45)

-- Tête : bloc arrondi (face avant plate pour le visage).
local HEAD_W, HEAD_H, HEAD_D, HEAD_R = 1.36, 1.26, 1.3, 0.2
local TOP = HEAD_H / 2
local FRONT = -HEAD_D / 2
local BACK = HEAD_D / 2

CharacterBuilder.RootHeight = 3 -- hauteur du HumanoidRootPart au-dessus du sol (échelle 1)
CharacterBuilder.Height = 4 + HEAD_H -- haut de la tête (échelle 1)
CharacterBuilder.HipHeight = 0 -- R6 : la hauteur vient des jambes

local CENTERS = {
	HumanoidRootPart = CFrame.new(0, 3, 0),
	Torso = CFrame.new(0, 3, 0),
	Head = CFrame.new(0, 4 + HEAD_H / 2, 0),
	["Left Arm"] = CFrame.new(-1.5, 3, 0),
	["Right Arm"] = CFrame.new(1.5, 3, 0),
	["Left Leg"] = CFrame.new(-0.5, 1, 0),
	["Right Leg"] = CFrame.new(0.5, 1, 0),
}

local SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(HEAD_W - 2 * HEAD_R, HEAD_H, HEAD_D),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}

-- Repères officiels des articulations R6.
local ROT_A = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local ROT_L = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local ROT_R = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)

local JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), ROT_A },
	{ "Neck", "Torso", "Head", Vector3.new(0, 1, 0), Vector3.new(0, -HEAD_H / 2, 0), ROT_A },
	{ "Left Shoulder", "Torso", "Left Arm", Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0), ROT_L },
	{ "Right Shoulder", "Torso", "Right Arm", Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0), ROT_R },
	{ "Left Hip", "Torso", "Left Leg", Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0), ROT_L },
	{ "Right Hip", "Torso", "Right Leg", Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0), ROT_R },
}
CharacterBuilder.JointNames = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }

-- Manches selon la tenue : "long" (par défaut), "short" ou "skin" (bras nus).
local SLEEVES = {
	tank = "skin",
	shirtless = "skin",
	openvest = "skin",
	egyptian = "skin",
	qipao = "short",
	gi = "short",
	shirt = "short",
	striped = "short",
	overalls = "short",
	openshirt = "short",
	armor = "short",
	sailor = "short",
	chakra = "long",
}

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * cf.Rotation
end

local has = Painter.has

-- Repère dont l'axe Y pointe dans la direction `dir`.
local function alongY(position: Vector3, dir: Vector3): CFrame
	local up = dir.Unit
	local ref = math.abs(up.Y) < 0.95 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
	local right = ref:Cross(up).Unit
	local back = right:Cross(up).Unit
	return CFrame.fromMatrix(position, right, up, back)
end

------------------------------------------------------------------------
-- Contexte de construction
------------------------------------------------------------------------

local function newContext(model: Model, s: number, paint: string)
	local ctx = { model = model, s = s, limbs = {}, paint = paint }

	-- Crée une pièce soudée à un membre. `offset` est relatif au centre du membre (échelle 1).
	function ctx.add(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		local limb = ctx.limbs[limbName]
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(CENTERS[limbName] * offset, s)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		if props then
			local target: any = part
			for key, value in props do
				target[key] = value
			end
		end
		part.Parent = model
		if limb then
			local weld = Instance.new("Weld")
			weld.Name = "Weld"
			weld.Part0 = limb
			weld.Part1 = part
			weld.C0 = limb.CFrame:Inverse() * part.CFrame
			weld.Parent = part
		end
		return part
	end

	-- Ellipsoïde (SpecialMesh "Sphere" étiré à la taille de la pièce).
	function ctx.ball(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = ctx.add(limbName, name, size, offset, color, props)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end

	-- Cylindre dont l'axe suit l'axe X de `offset`.
	function ctx.cyl(limbName: string, name: string, length: number, diameter: number, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = ctx.add(limbName, name, Vector3.new(length, diameter, diameter), offset, color, props)
		part.Shape = Enum.PartType.Cylinder
		return part
	end

	-- Cylindre vertical.
	function ctx.vcyl(limbName: string, name: string, height: number, diameter: number, offset: CFrame, color: Color3, props: { [string]: any }?): Part
		return ctx.cyl(limbName, name, height, diameter, offset * CFrame.Angles(0, 0, math.pi / 2), color, props)
	end

	-- Bloc aux arêtes verticales arrondies.
	function ctx.rounded(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, radius: number, props: { [string]: any }?)
		local r = math.min(radius, size.X / 2 - 0.01, size.Z / 2 - 0.01)
		local first = ctx.add(limbName, name, Vector3.new(size.X - 2 * r, size.Y, size.Z), offset, color, props)
		ctx.add(limbName, name, Vector3.new(size.X, size.Y, size.Z - 2 * r), offset, color, props)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				ctx.vcyl(limbName, name, size.Y, 2 * r, offset * CFrame.new(sx * (size.X / 2 - r), 0, sz * (size.Z / 2 - r)), color, props)
			end
		end
		return first
	end

	-- Lame triangulaire (deux WedgeParts dos à dos) dans le plan (droite, haut) du repère `frame`.
	local HALF_A = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
	local HALF_B = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
	function ctx.blade(limbName: string, color: Color3, frame: CFrame, length: number, width: number, thickness: number)
		for i, half in { HALF_A, HALF_B } do
			local side = i == 1 and 1 or -1
			local cf = frame * CFrame.new(side * width / 4, length / 2, 0) * half
			local limb = ctx.limbs[limbName]
			local part = Instance.new("WedgePart")
			part.Name = "HairSpike"
			part.Size = Vector3.new(thickness, length, width / 2) * s
			part.CFrame = scaled(CENTERS[limbName] * cf, s)
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.Parent = ctx.model
			local weld = Instance.new("Weld")
			weld.Name = "Weld"
			weld.Part0 = limb
			weld.Part1 = part
			weld.C0 = limb.CFrame:Inverse() * part.CFrame
			weld.Parent = part
		end
	end

	-- Pique pointue (deux lames croisées) partant de `from` dans la direction `dir`.
	function ctx.spike(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, tip: Color3?)
		local frame = alongY(from, dir)
		local thin = math.clamp(width * 0.22, 0.08, 0.16)
		ctx.blade(limbName, color, frame, length, width, thin)
		ctx.blade(limbName, color, frame * CFrame.Angles(0, math.pi / 2, 0), length, width * 0.85, thin)
		if tip then
			local tipFrame = frame * CFrame.new(0, length * 0.6, 0)
			ctx.blade(limbName, tip, tipFrame, length * 0.41, width * 0.44, thin + 0.02)
			ctx.blade(limbName, tip, tipFrame * CFrame.Angles(0, math.pi / 2, 0), length * 0.41, width * 0.38, thin + 0.02)
		end
	end

	-- Mèche plate (une lame tournée vers l'avant), idéale pour la frange.
	function ctx.lock(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, tip: Color3?)
		local up = dir.Unit
		local right = up:Cross(Vector3.new(0, 0, 1))
		if right.Magnitude < 0.1 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		local back = right:Cross(up).Unit
		local frame = CFrame.fromMatrix(from, right, up, back)
		ctx.blade(limbName, color, frame, length, width, 0.14)
		if tip then
			ctx.blade(limbName, tip, frame * CFrame.new(0, length * 0.6, -0.01), length * 0.4, width * 0.42, 0.15)
		end
	end

	-- Mèche arrondie (ellipsoïde), pour les cheveux souples.
	function ctx.strand(limbName: string, color: Color3, from: Vector3, dir: Vector3, length: number, width: number, tip: Color3?)
		local d = dir.Unit
		ctx.ball(limbName, "Strand", Vector3.new(width, length, width * 0.8), alongY(from + d * (length * 0.45), d), color)
		if tip then
			ctx.ball(limbName, "StrandTip", Vector3.new(width * 0.72, length * 0.4, width * 0.6), alongY(from + d * (length * 0.75), d), tip)
		end
	end

	-- Peinture (SurfaceGui dans le monde, pièces fines dans les aperçus).
	function ctx.surface(part: BasePart, face: Enum.NormalId, name: string)
		if ctx.paint == "parts" then
			return Painter.canvas(part, face)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.8
		gui.MaxDistance = 110
		gui.ClipsDescendants = true
		gui.Parent = part
		return gui
	end

	return ctx
end

------------------------------------------------------------------------
-- Corps R6
------------------------------------------------------------------------

local function buildBody(ctx, look)
	local model, s = ctx.model, ctx.s
	local skin = look.skin or Color3.fromRGB(255, 216, 180)
	local top = look.top or WHITE
	local bottom = look.bottom or BLACK
	local outfit = look.outfit or (look.shirtless and "shirtless" or "shirt")
	local sleeves = SLEEVES[outfit] or "long"
	if look.sleeveless or look.shirtless then
		sleeves = "skin"
	end
	local accent = look.topAccent or darken(top, 0.3)

	local colors = {
		HumanoidRootPart = WHITE,
		Torso = (outfit == "shirtless") and skin or top,
		Head = skin,
		["Left Arm"] = sleeves == "long" and top or skin,
		["Right Arm"] = sleeves == "long" and top or skin,
		["Left Leg"] = bottom,
		["Right Leg"] = bottom,
	}

	for name, size in SIZES do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(CENTERS[name], s)
		part.Color = colors[name]
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanTouch = false
		part.Anchored = false
		if name == "HumanoidRootPart" then
			part.Transparency = 1
			part.CanCollide = true
			part.CanQuery = true
			part.Massless = false
			part.RootPriority = 127
		else
			part.CanCollide = false
			part.CanQuery = name == "Torso" or name == "Head"
			part.Massless = true
		end
		part.Parent = model
		ctx.limbs[name] = part
	end

	for _, joint in JOINTS do
		local name, parentName, childName, c0, c1, rot = joint[1], joint[2], joint[3], joint[4], joint[5], joint[6]
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = ctx.limbs[parentName]
		motor.Part1 = ctx.limbs[childName]
		motor.C0 = CFrame.new(c0 * s) * rot
		motor.C1 = CFrame.new(c1 * s) * rot
		motor:SetAttribute("BaseC0", motor.C0)
		motor.Parent = ctx.limbs[parentName]
	end

	-- Tête arrondie : côtés + arêtes en cylindres + petit dôme.
	ctx.add("Head", "HeadSide", Vector3.new(HEAD_W, HEAD_H, HEAD_D - 2 * HEAD_R), CFrame.new(), skin)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ctx.vcyl("Head", "HeadEdge", HEAD_H, 2 * HEAD_R, CFrame.new(sx * (HEAD_W / 2 - HEAD_R), 0, sz * (HEAD_D / 2 - HEAD_R)), skin)
		end
	end
	ctx.ball("Head", "Cranium", Vector3.new(HEAD_W, 0.36, HEAD_D), CFrame.new(0, TOP, 0), skin)
	-- Oreilles
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Ear", Vector3.new(0.14, 0.34, 0.24), CFrame.new(side * (HEAD_W / 2 + 0.03), -0.02, 0.08), darken(skin, 0.05))
	end

	-- Mains, manches et chaussures.
	for _, side in { "Left Arm", "Right Arm" } do
		if sleeves == "long" then
			ctx.add(side, "Hand", Vector3.new(1.02, 0.42, 1.02), CFrame.new(0, -0.8, 0), skin)
			ctx.add(side, "Cuff", Vector3.new(1.05, 0.16, 1.05), CFrame.new(0, -0.53, 0), accent)
		elseif sleeves == "short" then
			ctx.add(side, "Sleeve", Vector3.new(1.05, 0.8, 1.05), CFrame.new(0, 0.6, 0), top)
			ctx.add(side, "SleeveHem", Vector3.new(1.07, 0.12, 1.07), CFrame.new(0, 0.2, 0), accent)
		end
		if outfit == "jacket" or outfit == "jumpsuit" or outfit == "flakvest" then
			ctx.add(side, "ShoulderCap", Vector3.new(1.05, 0.55, 1.05), CFrame.new(0, 0.73, 0), accent)
		end
	end
	local shoes = look.shoes or DEFAULT_SHOES
	for _, side in { "Left Leg", "Right Leg" } do
		ctx.add(side, "Shoe", Vector3.new(1.05, 0.42, 1.16), CFrame.new(0, -0.79, -0.07), shoes)
		ctx.add(side, "Sole", Vector3.new(1.07, 0.1, 1.18), CFrame.new(0, -0.96, -0.07), darken(shoes, 0.45))
	end

	-- Visage et tenue peints.
	if not has(look, "boar_head") then
		local faceTarget = ctx.paint == "parts" and "parts" or nil
		Painter.face(ctx.limbs.Head, look, faceTarget)
	end
	Painter.torso(ctx.limbs.Torso, look, ctx.paint == "parts" and "parts" or nil)
end

------------------------------------------------------------------------
-- Coiffures (repère de la tête : centre de la tête, face vers -Z)
------------------------------------------------------------------------

local function cap(ctx, c: Color3, height: number)
	ctx.rounded("Head", "HairCap", Vector3.new(HEAD_W + 0.12, height, HEAD_D + 0.12), CFrame.new(0, TOP + 0.14 - height / 2, 0.02), c, HEAD_R + 0.06)
	ctx.ball("Head", "HairDome", Vector3.new(HEAD_W + 0.12, 0.42, HEAD_D + 0.12), CFrame.new(0, TOP + 0.12, 0.02), c)
end

local function back(ctx, c: Color3, length: number)
	ctx.rounded("Head", "HairBack", Vector3.new(HEAD_W + 0.12, length, 0.5), CFrame.new(0, TOP + 0.1 - length / 2, BACK - 0.12), c, 0.2)
end

local function sides(ctx, c: Color3, length: number)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.16, length, HEAD_D - 0.1), CFrame.new(side * (HEAD_W / 2 + 0.05), TOP + 0.1 - length / 2, 0.08), c)
	end
end

-- Mèches plates qui tombent sur le front.
local function fringe(ctx, c: Color3, xs: { number }, length: number, width: number, spread: number?, y: number?, z: number?)
	for _, x in xs do
		ctx.lock("Head", c, Vector3.new(x, y or (TOP - 0.02), z or (FRONT - 0.08)), Vector3.new(x * (spread or 0.45), -1, -0.2), length, width)
	end
end

local function wearsHeadband(look): boolean
	return has(look, "headband") or has(look, "headband_tilted") or has(look, "headband_scratched")
end

-- Couronne de piques autour du crâne.
local function crown(ctx, c: Color3, count: number, length: number, width: number, tilt: number, tip: Color3?, phase: number?)
	for i = 0, count - 1 do
		local a = (i / count) * math.pi * 2 + (phase or 0)
		local dx, dz = math.cos(a), math.sin(a)
		ctx.spike("Head", c, Vector3.new(dx * 0.4, TOP + 0.18, dz * 0.38 + 0.05), Vector3.new(dx, tilt, dz * 0.9 + 0.15), length, width, tip)
	end
end

local HAIR = {}

HAIR.short = function(ctx, c, look)
	cap(ctx, c, 0.5)
	back(ctx, c, 1.0)
	sides(ctx, c, 0.75)
	fringe(ctx, c, { -0.4, -0.13, 0.13, 0.4 }, 0.42, 0.36)
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.25, TOP + 0.15, 0.05), Vector3.new(side * 0.5, 1, 0.3), 0.5, 0.61, look.hairTip)
	end
end

HAIR.spiky = function(ctx, c, look)
	local tip = look.hairTip
	cap(ctx, c, 0.5)
	back(ctx, c, 0.85)
	sides(ctx, c, 0.6)
	-- Mèches en pointe sur le front (par-dessus le haut du bandeau).
	if wearsHeadband(look) then
		fringe(ctx, c, { -0.46, -0.23, 0, 0.23, 0.46 }, 0.34, 0.36, 0.6, TOP + 0.14, FRONT - 0.17)
	else
		fringe(ctx, c, { -0.46, -0.23, 0, 0.23, 0.46 }, 0.45, 0.36, 0.6, TOP + 0.04)
	end
	crown(ctx, c, 8, 1.0, 0.72, 0.8, tip)
	for _, x in { -0.3, 0.3 } do
		ctx.spike("Head", c, Vector3.new(x, TOP + 0.2, 0.1), Vector3.new(x, 1, 0.3), 0.8, 0.68, tip)
	end
	-- Piques à l'arrière et sur les côtés.
	for _, x in { -0.42, 0, 0.42 } do
		ctx.spike("Head", c, Vector3.new(x, 0.15, BACK - 0.05), Vector3.new(x, -0.3, 1), 0.75, 0.68, tip)
	end
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.62, 0.3, 0.05), Vector3.new(side, 0.15, 0.15), 0.6, 0.57, tip)
	end
end

HAIR.wild = function(ctx, c, look)
	local tip = look.hairTip
	cap(ctx, c, 0.55)
	back(ctx, c, 0.95)
	sides(ctx, c, 0.7)
	-- Grosses mèches sur le front (style guerrier).
	ctx.lock("Head", c, Vector3.new(-0.32, TOP + 0.02, FRONT - 0.03), Vector3.new(-0.35, -1, -0.3), 0.62, 0.45, tip)
	ctx.lock("Head", c, Vector3.new(0.05, TOP + 0.05, FRONT - 0.03), Vector3.new(0.2, -1, -0.3), 0.48, 0.42, tip)
	ctx.lock("Head", c, Vector3.new(0.42, TOP + 0.02, FRONT - 0.03), Vector3.new(0.6, -0.8, -0.3), 0.55, 0.4, tip)
	crown(ctx, c, 7, 1.2, 0.89, 1.1, tip, 0.3)
	ctx.spike("Head", c, Vector3.new(0, TOP + 0.2, 0), Vector3.new(0.1, 1, 0.1), 1.15, 0.89, tip)
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.62, 0.25, 0.1), Vector3.new(side, -0.2, 0.2), 0.85, 0.74, tip)
	end
	for _, x in { -0.35, 0.35 } do
		ctx.spike("Head", c, Vector3.new(x, 0.1, BACK - 0.05), Vector3.new(x, -0.4, 1), 0.9, 0.78, tip)
	end
end

HAIR.tall_spiky = function(ctx, c, look)
	HAIR.wild(ctx, c, look)
	-- Très longue crinière jusqu'aux jambes.
	for _, x in { -0.35, 0, 0.35 } do
		ctx.spike("Head", c, Vector3.new(x, 0.35, BACK - 0.1), Vector3.new(x * 0.3, -1, 0.25), 3.4, 1.22, look.hairTip)
	end
	ctx.strand("Head", c, Vector3.new(0, 0.5, BACK - 0.15), Vector3.new(0, -1, 0.4), 2.6, 1.1)
end

HAIR.spiky_back = function(ctx, c, look)
	cap(ctx, c, 0.5)
	sides(ctx, c, 0.9)
	-- Longues mèches qui encadrent le visage.
	for _, side in { -1, 1 } do
		ctx.lock("Head", c, Vector3.new(side * 0.5, TOP - 0.02, FRONT - 0.04), Vector3.new(side * 0.1, -1, -0.08), 1.15, 0.3)
	end
	ctx.lock("Head", c, Vector3.new(-0.12, TOP, FRONT - 0.04), Vector3.new(-0.25, -1, -0.25), 0.62, 0.34)
	ctx.lock("Head", c, Vector3.new(0.18, TOP, FRONT - 0.04), Vector3.new(0.3, -1, -0.25), 0.5, 0.3)
	-- Piques vers l'arrière.
	for _, p in { { -0.4, 0.2 }, { 0, 0.35 }, { 0.4, 0.2 }, { -0.25, -0.1 }, { 0.25, -0.1 }, { 0, -0.3 } } do
		ctx.spike("Head", c, Vector3.new(p[1], TOP + p[2] * 0.4, 0.25), Vector3.new(p[1] * 0.7, 0.35 + p[2], 1), 1.0, 0.81, look.hairTip)
	end
end

HAIR.long = function(ctx, c, look)
	cap(ctx, c, 0.45)
	fringe(ctx, c, { -0.3, 0, 0.3 }, 0.42, 0.36, 0.25)
	ctx.rounded("Head", "HairBack", Vector3.new(HEAD_W + 0.12, 2.6, 0.5), CFrame.new(0, TOP + 0.1 - 1.3, BACK - 0.08), c, 0.22)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.18, 1.9, HEAD_D - 0.2), CFrame.new(side * (HEAD_W / 2 + 0.06), TOP - 0.8, 0.12), c)
		ctx.lock("Head", c, Vector3.new(side * 0.5, TOP - 0.02, FRONT - 0.04), Vector3.new(side * 0.04, -1, -0.04), 1.6, 0.36, look.hairTip)
	end
	if look.hairTip then
		ctx.rounded("Head", "HairTip", Vector3.new(HEAD_W + 0.14, 0.5, 0.52), CFrame.new(0, TOP + 0.1 - 2.45, BACK - 0.08), look.hairTip, 0.22)
	end
end

HAIR.ponytail = function(ctx, c, look)
	cap(ctx, c, 0.48)
	back(ctx, c, 0.95)
	sides(ctx, c, 0.85)
	fringe(ctx, c, { -0.3, 0, 0.3 }, 0.42, 0.36)
	for _, side in { -1, 1 } do
		ctx.lock("Head", c, Vector3.new(side * 0.52, TOP - 0.02, FRONT - 0.04), Vector3.new(side * 0.06, -1, -0.04), 1.0, 0.3)
	end
	ctx.ball("Head", "Tie", Vector3.new(0.34, 0.3, 0.3), CFrame.new(0, 0.3, BACK + 0.12), darken(c, 0.45))
	ctx.strand("Head", c, Vector3.new(0, 0.32, BACK + 0.18), Vector3.new(0, -1, 0.35), 2.0, 0.6, look.hairTip)
end

HAIR.side_ponytail = function(ctx, c, look)
	cap(ctx, c, 0.48)
	back(ctx, c, 0.95)
	sides(ctx, c, 0.8)
	fringe(ctx, c, { -0.3, 0, 0.3 }, 0.42, 0.36)
	ctx.ball("Head", "Tie", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.72, 0.35, 0.25), darken(c, 0.45))
	ctx.strand("Head", c, Vector3.new(0.78, 0.35, 0.3), Vector3.new(0.5, -1, 0.3), 1.6, 0.55, look.hairTip)
end

HAIR.ponytail_spiky = function(ctx, c, look)
	cap(ctx, c, 0.45)
	back(ctx, c, 0.8)
	sides(ctx, c, 0.65)
	fringe(ctx, c, { -0.38, 0.38 }, 0.4, 0.32)
	ctx.ball("Head", "Tie", Vector3.new(0.3, 0.26, 0.3), CFrame.new(0, TOP + 0.18, 0.45), darken(c, 0.45))
	for _, p in { { 0, 0 }, { -0.25, 0.4 }, { 0.25, -0.4 } } do
		ctx.spike("Head", c, Vector3.new(p[1] * 0.4, TOP + 0.25, 0.5), Vector3.new(p[2], 1, 0.7), 0.85, 0.68, look.hairTip)
	end
end

HAIR.slick = function(ctx, c, look)
	cap(ctx, c, 0.48)
	back(ctx, c, 1.1)
	sides(ctx, c, 0.65)
	ctx.lock("Head", c, Vector3.new(-0.3, TOP + 0.05, FRONT - 0.03), Vector3.new(-1, -0.4, -0.1), 0.6, 0.32)
	local _ = look
end

HAIR.slick_up = function(ctx, c, look)
	cap(ctx, c, 0.45)
	back(ctx, c, 0.9)
	sides(ctx, c, 0.55)
	-- Cheveux dressés en flamme vers le haut (prince guerrier).
	for _, p in { { -0.4, -0.3 }, { 0, -0.35 }, { 0.4, -0.3 }, { -0.25, 0.1 }, { 0.25, 0.1 }, { 0, 0.3 } } do
		ctx.spike("Head", c, Vector3.new(p[1], TOP + 0.1, p[2]), Vector3.new(p[1] * 0.5, 1, 0.25 + p[2] * 0.3), 1.25, 0.81, look.hairTip)
	end
	ctx.spike("Head", c, Vector3.new(0, TOP + 0.15, 0), Vector3.new(0, 1, 0.1), 1.5, 0.94, look.hairTip)
end

HAIR.mohawk = function(ctx, c, look)
	for i = 0, 4 do
		local z = FRONT + 0.15 + i * 0.25
		ctx.spike("Head", c, Vector3.new(0, TOP + 0.05, z), Vector3.new(0, 1, (i - 2) * 0.25), 0.75 + (i == 1 and 0.2 or 0), 0.4, look.hairTip)
	end
	ctx.add("Head", "Crest", Vector3.new(0.3, 0.2, HEAD_D), CFrame.new(0, TOP + 0.08, 0), c)
end

HAIR.flame_spiky = function(ctx, c, look)
	local tip = look.hairTip
	cap(ctx, c, 0.5)
	back(ctx, c, 1.0)
	sides(ctx, c, 0.75)
	fringe(ctx, c, { -0.42, -0.14, 0.14, 0.42 }, 0.45, 0.34, 0.9)
	-- Piques balayées vers l'arrière comme des flammes.
	for i = 0, 6 do
		local x = -0.6 + i * 0.2
		ctx.spike("Head", c, Vector3.new(x, TOP + 0.05, 0.0), Vector3.new(x * 0.8, 0.7, 1), 1.0, 0.7, tip)
	end
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.62, 0.2, 0.2), Vector3.new(side, -0.2, 0.6), 0.8, 0.65, tip)
	end
end

HAIR.flame = function(ctx, c, look)
	local tip = look.hairTip or c
	sides(ctx, c, 0.5)
	cap(ctx, c, 0.4)
	ctx.ball("Head", "Flame1", Vector3.new(1.35, 0.9, 1.3), CFrame.new(0, TOP + 0.4, 0.08), c)
	ctx.ball("Head", "Flame2", Vector3.new(1.0, 0.95, 0.95), CFrame.new(0, TOP + 0.95, 0.15), c)
	ctx.spike("Head", tip, Vector3.new(0, TOP + 1.1, 0.2), Vector3.new(0, 1, 0.15), 1.0, 0.94)
	for _, side in { -1, 1 } do
		ctx.spike("Head", c, Vector3.new(side * 0.42, TOP + 0.45, 0.1), Vector3.new(side * 0.6, 1, 0.1), 0.9, 0.74, tip)
	end
	fringe(ctx, c, { 0 }, 0.4, 0.36)
end

HAIR.curly = function(ctx, c, look)
	back(ctx, c, 1.1)
	sides(ctx, c, 0.95)
	local bumps = {
		Vector3.new(-0.45, TOP + 0.1, FRONT + 0.1),
		Vector3.new(0.05, TOP + 0.15, FRONT + 0.05),
		Vector3.new(0.5, TOP + 0.1, FRONT + 0.12),
		Vector3.new(-0.5, TOP + 0.2, 0.15),
		Vector3.new(0, TOP + 0.3, 0.05),
		Vector3.new(0.5, TOP + 0.2, 0.15),
		Vector3.new(-0.3, TOP + 0.15, BACK - 0.1),
		Vector3.new(0.3, TOP + 0.15, BACK - 0.1),
		Vector3.new(-0.72, 0.25, 0.1),
		Vector3.new(0.72, 0.25, 0.1),
	}
	for _, pos in bumps do
		ctx.ball("Head", "Curl", Vector3.new(0.68, 0.6, 0.68), CFrame.new(pos), c)
	end
	local _ = look
end

HAIR.messy = function(ctx, c, look)
	cap(ctx, c, 0.55)
	back(ctx, c, 1.05)
	sides(ctx, c, 0.85)
	local bangs = { { -0.45, 0.5, -0.4 }, { -0.15, 0.6, 0.3 }, { 0.18, 0.5, -0.2 }, { 0.47, 0.55, 0.4 } }
	for _, b in bangs do
		ctx.lock("Head", c, Vector3.new(b[1], TOP, FRONT - 0.04), Vector3.new(b[3], -1, -0.25), b[2], 0.36)
	end
	for _, p in { { -0.45, 0.3, -0.6 }, { 0.5, 0.35, 0.7 }, { 0, 0.5, 0.2 }, { -0.2, 0.2, -0.3 } } do
		ctx.spike("Head", c, Vector3.new(p[1], TOP + 0.1, p[2]), Vector3.new(p[3], 1, p[2]), 0.6, 0.68, look.hairTip)
	end
end

HAIR.cover_eye = function(ctx, c, look)
	cap(ctx, c, 0.5)
	back(ctx, c, 1.1)
	sides(ctx, c, 0.85)
	-- Longue mèche qui cache un œil.
	ctx.ball("Head", "Cover", Vector3.new(0.5, 0.85, 0.16), CFrame.new(-0.22, 0.18, FRONT - 0.06) * CFrame.Angles(0, 0, -0.15), c)
	ctx.lock("Head", c, Vector3.new(0.3, TOP, FRONT - 0.04), Vector3.new(0.5, -1, -0.2), 0.4, 0.34)
	local _ = look
end

HAIR.bun = function(ctx, c, look)
	cap(ctx, c, 0.48)
	back(ctx, c, 0.9)
	sides(ctx, c, 0.7)
	fringe(ctx, c, { -0.3, 0.05, 0.35 }, 0.42, 0.36)
	ctx.ball("Head", "Bun", Vector3.new(0.7, 0.62, 0.7), CFrame.new(0, TOP + 0.35, 0.35), c)
	ctx.ball("Head", "BunTie", Vector3.new(0.55, 0.12, 0.55), CFrame.new(0, TOP + 0.1, 0.3), darken(c, 0.4))
	local _ = look
end

HAIR.topknot = function(ctx, c, look)
	cap(ctx, c, 0.45)
	back(ctx, c, 0.8)
	sides(ctx, c, 0.6)
	ctx.ball("Head", "Knot", Vector3.new(0.5, 0.45, 0.5), CFrame.new(0, TOP + 0.38, 0.2), c)
	ctx.strand("Head", c, Vector3.new(0, TOP + 0.5, 0.25), Vector3.new(0, 1, 0.5), 0.6, 0.3)
	local _ = look
end

HAIR.bowl = function(ctx, c, look)
	-- Coupe au bol bien nette et brillante.
	ctx.rounded("Head", "Bowl", Vector3.new(HEAD_W + 0.14, 0.78, HEAD_D + 0.14), CFrame.new(0, TOP - 0.22, 0.01), c, HEAD_R + 0.07, { Reflectance = 0.08 })
	ctx.ball("Head", "BowlDome", Vector3.new(HEAD_W + 0.14, 0.55, HEAD_D + 0.14), CFrame.new(0, TOP + 0.16, 0.01), c, { Reflectance = 0.08 })
	back(ctx, c, 1.15)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.18, 0.9, HEAD_D - 0.2), CFrame.new(side * (HEAD_W / 2 + 0.07), 0.05, 0.1), c)
	end
	local _ = look
end

HAIR.bob = function(ctx, c, look)
	cap(ctx, c, 0.55)
	ctx.rounded("Head", "HairBack", Vector3.new(HEAD_W + 0.14, 1.45, 0.55), CFrame.new(0, TOP + 0.1 - 0.72, BACK - 0.12), c, 0.22)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.2, 1.45, HEAD_D - 0.05), CFrame.new(side * (HEAD_W / 2 + 0.07), TOP + 0.1 - 0.72, 0.05), c)
	end
	ctx.add("Head", "Fringe", Vector3.new(HEAD_W + 0.1, 0.3, 0.12), CFrame.new(0, TOP - 0.1, FRONT - 0.08), c)
	local _ = look
end

HAIR.bald = function(ctx, c, look)
	ctx.ball("Head", "Shine", Vector3.new(0.45, 0.06, 0.3), CFrame.new(-0.25, TOP + 0.17, -0.2), lighten(look.skin or WHITE, 0.45))
	local _ = c
end

HAIR.none = function() end

------------------------------------------------------------------------
-- Accessoires
------------------------------------------------------------------------

local ACC = {}
local PAINTED = {
	"whiskers",
	"tear_lines",
	"extra_eyes",
	"scar_eye",
	"scar_cheek",
	"scar_face",
	"scar_forehead",
	"forehead_mark",
	"dots",
	"facepaint",
	"stitches_forehead",
	"glasses",
	"cyclops",
}
for _, name in PAINTED do
	ACC[name] = function() end -- dessinés par Painter
end

-- Peint un motif sur une face d'une pièce (haori, cape...).
local function paintPanel(ctx, part: BasePart, face: Enum.NormalId, painter: (any) -> ())
	painter(ctx.surface(part, face, "Pattern"))
end

local function headbandBase(ctx, look, tilt: number, scratched: boolean)
	local band = look.headbandColor or Color3.fromRGB(35, 45, 90)
	local rot = CFrame.Angles(0, 0, tilt)
	ctx.rounded("Head", "Headband", Vector3.new(HEAD_W + 0.24, 0.24, HEAD_D + 0.22), CFrame.new(0, 0.45, 0.01) * rot, band, HEAD_R + 0.1)
	local plate = ctx.add("Head", "Plate", Vector3.new(0.74, 0.3, 0.06), CFrame.new(0, 0.45, FRONT - 0.15) * rot, METAL, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	paintPanel(ctx, plate, Enum.NormalId.Front, function(canvas)
		Painter.rect(canvas, 0.5, 0.5, 0.3, 0.62, METAL, { corner = 0.5, transparency = 1, stroke = Color3.fromRGB(70, 75, 90), strokeThickness = 2, z = 2 })
		Painter.rect(canvas, 0.6, 0.38, 0.1, 0.35, Color3.fromRGB(70, 75, 90), { corner = 0.5, rotation = 35, z = 2 })
		if scratched then
			Painter.rect(canvas, 0.5, 0.5, 0.9, 0.08, Color3.fromRGB(60, 60, 70), { rotation = -8, z = 3 })
		end
	end)
	ctx.ball("Head", "Knot", Vector3.new(0.26, 0.24, 0.2), CFrame.new(0, 0.45, BACK + 0.13) * rot, band)
	ctx.strand("Head", band, Vector3.new(-0.08, 0.42, BACK + 0.15), Vector3.new(-0.3, -1, 0.5), 0.8, 0.16)
	ctx.strand("Head", band, Vector3.new(0.08, 0.42, BACK + 0.15), Vector3.new(0.35, -1, 0.4), 0.7, 0.16)
end

ACC.headband = function(ctx, look)
	headbandBase(ctx, look, 0, false)
end

ACC.headband_tilted = function(ctx, look)
	headbandBase(ctx, look, 0.12, false)
end

ACC.headband_scratched = function(ctx, look)
	headbandBase(ctx, look, 0, true)
end

ACC.headband_belt = function(ctx, look)
	local band = look.headbandColor or Color3.fromRGB(200, 40, 40)
	ctx.add("Torso", "BeltBand", Vector3.new(2.06, 0.32, 1.06), CFrame.new(0, -0.76, 0), band)
	ctx.add("Torso", "BeltPlate", Vector3.new(0.7, 0.3, 0.06), CFrame.new(0, -0.76, -0.56), METAL, { Material = Enum.Material.Metal, Reflectance = 0.2 })
end

ACC.mask_lower = function(ctx, look)
	ctx.rounded("Head", "Mask", Vector3.new(HEAD_W + 0.05, 0.42, HEAD_D + 0.05), CFrame.new(0, -0.43, 0), look.accColor or Color3.fromRGB(45, 50, 65), HEAD_R + 0.03)
	ctx.ball("Head", "MaskNose", Vector3.new(0.22, 0.2, 0.12), CFrame.new(0, -0.27, FRONT - 0.04), look.accColor or Color3.fromRGB(45, 50, 65))
end

ACC.mask_bandage = function(ctx, look)
	local cloth = look.accColor or Color3.fromRGB(235, 230, 220)
	ctx.rounded("Head", "Bandage", Vector3.new(HEAD_W + 0.05, 0.45, HEAD_D + 0.05), CFrame.new(0, -0.4, 0), cloth, HEAD_R + 0.03)
	ctx.add("Head", "BandageWrap", Vector3.new(HEAD_W + 0.07, 0.06, HEAD_D + 0.07), CFrame.new(0, -0.32, 0), darken(cloth, 0.15))
end

ACC.blindfold = function(ctx, look)
	ctx.rounded("Head", "Blindfold", Vector3.new(HEAD_W + 0.06, 0.42, HEAD_D + 0.06), CFrame.new(0, 0.0, 0), look.blindColor or Color3.fromRGB(20, 20, 26), HEAD_R + 0.03)
end

ACC.tattoos = function(ctx, look)
	local ink = Color3.fromRGB(25, 20, 25)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.add(side, "ArmTattoo", Vector3.new(1.03, 0.08, 1.03), CFrame.new(0, 0.1, 0), ink)
		ctx.add(side, "ArmTattoo", Vector3.new(1.03, 0.08, 1.03), CFrame.new(0, -0.2, 0), ink)
	end
	local _ = look
end

ACC.tattoos_blue = function(ctx, look)
	local ink = look.accColor or Color3.fromRGB(60, 80, 220)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.add(side, "ArmTattoo", Vector3.new(1.03, 0.08, 1.03), CFrame.new(0, 0.25, 0), ink)
		ctx.add(side, "ArmTattoo", Vector3.new(1.03, 0.08, 1.03), CFrame.new(0, -0.15, 0), ink)
	end
	for _, side in { -1, 1 } do
		ctx.add("Torso", "BodyTattoo", Vector3.new(0.06, 1.6, 1.03), CFrame.new(side * 0.99, 0, 0), ink)
	end
end

ACC.stitches = function(ctx, look)
	local thread = Color3.fromRGB(60, 50, 60)
	ctx.add("Torso", "BodyStitch", Vector3.new(2.03, 0.05, 1.03), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, 0.35), thread)
	local _ = look
end

ACC.earrings = function(ctx, look)
	for _, side in { -1, 1 } do
		local x = side * (HEAD_W / 2 + 0.06)
		ctx.add("Head", "Earring", Vector3.new(0.05, 0.36, 0.2), CFrame.new(x, -0.38, 0.06), WHITE)
		local sun = ctx.add("Head", "EarringSun", Vector3.new(0.06, 0.13, 0.13), CFrame.new(x + side * 0.005, -0.35, 0.06), Color3.fromRGB(220, 40, 40))
		sun.Shape = Enum.PartType.Cylinder
	end
	local _ = look
end

ACC.earrings_stud = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Stud", Vector3.new(0.12, 0.12, 0.12), CFrame.new(side * (HEAD_W / 2 + 0.07), -0.18, 0.08), look.accColor or GOLD, { Material = Enum.Material.Metal })
	end
end

ACC.earrings_gold = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "GoldRing", Vector3.new(0.08, 0.26, 0.26), CFrame.new(side * (HEAD_W / 2 + 0.07), -0.3, 0.08), GOLD, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	end
	local _ = look
end

ACC.cap = function(ctx, look)
	local color = look.accColor or WHITE
	ctx.rounded("Head", "Cap", Vector3.new(HEAD_W + 0.16, 0.42, HEAD_D + 0.16), CFrame.new(0, TOP + 0.02, 0), color, HEAD_R + 0.08)
	ctx.ball("Head", "CapDome", Vector3.new(HEAD_W + 0.16, 0.5, HEAD_D + 0.16), CFrame.new(0, TOP + 0.22, 0), color)
	ctx.rounded("Head", "CapBand", Vector3.new(HEAD_W + 0.18, 0.12, HEAD_D + 0.18), CFrame.new(0, TOP - 0.14, 0), look.capBand or Color3.fromRGB(40, 60, 140), HEAD_R + 0.09)
	ctx.add("Head", "Brim", Vector3.new(1.1, 0.08, 0.6), CFrame.new(0, TOP - 0.14, FRONT - 0.32), look.capBrim or Color3.fromRGB(30, 30, 40))
end

ACC.bandana = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(200, 40, 40)
	ctx.rounded("Head", "Bandana", Vector3.new(HEAD_W + 0.16, 0.45, HEAD_D + 0.16), CFrame.new(0, TOP - 0.05, 0), color, HEAD_R + 0.08)
	ctx.ball("Head", "BandanaDome", Vector3.new(HEAD_W + 0.16, 0.5, HEAD_D + 0.16), CFrame.new(0, TOP + 0.14, 0), color)
	ctx.ball("Head", "BandanaKnot", Vector3.new(0.3, 0.26, 0.22), CFrame.new(0.3, TOP - 0.1, BACK + 0.12), color)
	ctx.strand("Head", color, Vector3.new(0.32, TOP - 0.12, BACK + 0.15), Vector3.new(0.3, -1, 0.5), 0.6, 0.2)
end

ACC.turban = function(ctx, look)
	local color = look.accColor or WHITE
	ctx.rounded("Head", "Turban", Vector3.new(HEAD_W + 0.2, 0.55, HEAD_D + 0.2), CFrame.new(0, TOP + 0.05, 0), color, HEAD_R + 0.1)
	ctx.ball("Head", "TurbanTop", Vector3.new(HEAD_W + 0.2, 0.8, HEAD_D + 0.2), CFrame.new(0, TOP + 0.3, 0), color)
	ctx.ball("Head", "TurbanGem", Vector3.new(0.24, 0.24, 0.12), CFrame.new(0, TOP + 0.12, FRONT - 0.12), Color3.fromRGB(150, 60, 200), { Material = Enum.Material.Neon })
end

ACC.straw_hat = function(ctx, look)
	local straw = look.accColor or Color3.fromRGB(240, 210, 110)
	ctx.vcyl("Head", "Brim", 0.1, 2.7, CFrame.new(0, TOP + 0.05, 0), straw)
	ctx.vcyl("Head", "Crown", 0.55, 1.62, CFrame.new(0, TOP + 0.3, 0), straw)
	ctx.ball("Head", "CrownTop", Vector3.new(1.62, 0.3, 1.62), CFrame.new(0, TOP + 0.57, 0), straw)
	ctx.vcyl("Head", "Ribbon", 0.17, 1.64, CFrame.new(0, TOP + 0.16, 0), Color3.fromRGB(210, 30, 40))
end

ACC.dome = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(150, 60, 200)
	ctx.ball("Head", "Dome", Vector3.new(HEAD_W + 0.1, 1.0, HEAD_D + 0.1), CFrame.new(0, TOP + 0.05, 0.04), color, { Reflectance = 0.25 })
	ctx.ball("Head", "DomeShine", Vector3.new(0.35, 0.2, 0.25), CFrame.new(-0.25, TOP + 0.42, -0.3), lighten(color, 0.5))
end

ACC.volcano = function(ctx, look)
	local rock = look.accColor or Color3.fromRGB(80, 60, 50)
	ctx.vcyl("Head", "Volcano1", 0.5, 1.4, CFrame.new(0, TOP + 0.15, 0), rock)
	ctx.vcyl("Head", "Volcano2", 0.45, 1.0, CFrame.new(0, TOP + 0.6, 0), rock)
	ctx.vcyl("Head", "Lava", 0.1, 0.7, CFrame.new(0, TOP + 0.85, 0), Color3.fromRGB(255, 120, 20), { Material = Enum.Material.Neon })
end

ACC.antennae = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.strand("Head", look.skin, Vector3.new(side * 0.22, TOP + 0.1, -0.3), Vector3.new(side * 0.25, 1, -0.45), 0.85, 0.12)
		ctx.ball("Head", "AntennaTip", Vector3.new(0.14, 0.14, 0.14), CFrame.new(side * 0.42, TOP + 0.85, -0.65), look.skin)
	end
end

ACC.horns = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(235, 225, 205)
	for _, side in { -1, 1 } do
		ctx.spike("Head", color, Vector3.new(side * 0.42, TOP + 0.05, -0.15), Vector3.new(side * 0.45, 1, -0.1), 0.7, 0.41)
	end
end

local function ears(ctx, color: Color3, inner: Color3, size: number)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * 0.42, TOP + 0.3, 0.05) * CFrame.Angles(0, 0, -0.35 * side)
		ctx.ball("Head", "AnimalEar", Vector3.new(size * 0.7, size, 0.16), cf, color)
		ctx.ball("Head", "AnimalEarInner", Vector3.new(size * 0.4, size * 0.65, 0.17), cf * CFrame.new(0, -0.04, -0.02), inner)
	end
end

ACC.cat_ears = function(ctx, look)
	ears(ctx, look.hairColor or look.skin, Color3.fromRGB(255, 180, 200), 0.55)
end

ACC.fox_ears = function(ctx, look)
	ears(ctx, look.accColor or Color3.fromRGB(255, 120, 20), Color3.fromRGB(40, 20, 20), 0.7)
end

ACC.scouter = function(ctx, look)
	ctx.add(
		"Head",
		"ScouterLens",
		Vector3.new(0.38, 0.32, 0.04),
		CFrame.new(-0.22, 0.02, FRONT - 0.1),
		Color3.fromRGB(80, 255, 120),
		{ Material = Enum.Material.Neon, Transparency = 0.35 }
	)
	ctx.add("Head", "ScouterBody", Vector3.new(0.16, 0.42, 0.42), CFrame.new(-(HEAD_W / 2 + 0.08), 0.05, -0.2), Color3.fromRGB(240, 240, 240))
	ctx.add("Head", "ScouterArm", Vector3.new(0.3, 0.06, 0.06), CFrame.new(-0.55, 0.12, FRONT - 0.06), Color3.fromRGB(240, 240, 240))
	local _ = look
end

ACC.long_nose = function(ctx, look)
	ctx.ball("Head", "LongNose", Vector3.new(0.16, 0.16, 0.8), CFrame.new(0, -0.17, FRONT - 0.36), look.skin)
end

ACC.saw_nose = function(ctx, look)
	local skin = look.skin
	ctx.add("Head", "SawNose", Vector3.new(0.14, 0.1, 0.95), CFrame.new(0, -0.12, FRONT - 0.45), skin)
	for i = 0, 3 do
		ctx.add("Head", "SawTooth", Vector3.new(0.3, 0.05, 0.08), CFrame.new(0, -0.12, FRONT - 0.15 - i * 0.22), WHITE)
	end
end

ACC.clown_nose = function(ctx, look)
	ctx.ball("Head", "ClownNose", Vector3.new(0.3, 0.28, 0.28), CFrame.new(0, -0.15, FRONT - 0.07), Color3.fromRGB(230, 30, 40))
	local _ = look
end

ACC.muzzle = function(ctx, look)
	local bamboo = Color3.fromRGB(120, 170, 70)
	ctx.cyl("Head", "Bamboo", 1.05, 0.22, CFrame.new(0, -0.42, FRONT - 0.1), bamboo)
	ctx.cyl("Head", "BambooKnot", 0.06, 0.25, CFrame.new(-0.25, -0.42, FRONT - 0.1), darken(bamboo, 0.3))
	ctx.cyl("Head", "BambooKnot", 0.06, 0.25, CFrame.new(0.25, -0.42, FRONT - 0.1), darken(bamboo, 0.3))
	ctx.rounded("Head", "BambooString", Vector3.new(HEAD_W + 0.03, 0.06, HEAD_D + 0.03), CFrame.new(0, -0.42, 0), Color3.fromRGB(200, 60, 60), HEAD_R)
	local _ = look
end

ACC.boar_head = function(ctx, look)
	local fur = look.accColor or Color3.fromRGB(110, 110, 120)
	ctx.rounded("Head", "BoarHead", Vector3.new(HEAD_W + 0.3, HEAD_H + 0.3, HEAD_D + 0.3), CFrame.new(0, 0.1, 0), fur, HEAD_R + 0.15)
	ctx.ball("Head", "BoarDome", Vector3.new(HEAD_W + 0.3, 0.6, HEAD_D + 0.3), CFrame.new(0, TOP + 0.25, 0), fur)
	ctx.rounded("Head", "Snout", Vector3.new(0.75, 0.55, 0.5), CFrame.new(0, -0.25, FRONT - 0.32), lighten(fur, 0.35), 0.15)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Nostril", Vector3.new(0.12, 0.18, 0.05), CFrame.new(side * 0.15, -0.25, FRONT - 0.58), BLACK)
		ctx.ball("Head", "BoarEye", Vector3.new(0.24, 0.24, 0.06), CFrame.new(side * 0.38, 0.22, FRONT - 0.15), Color3.fromRGB(150, 190, 220))
		ctx.ball("Head", "BoarPupil", Vector3.new(0.1, 0.1, 0.06), CFrame.new(side * 0.38, 0.22, FRONT - 0.18), BLACK)
		ctx.ball("Head", "BoarEar", Vector3.new(0.35, 0.45, 0.14), CFrame.new(side * 0.6, TOP + 0.4, 0) * CFrame.Angles(0, 0, -0.5 * side), fur)
		ctx.spike("Head", WHITE, Vector3.new(side * 0.3, -0.45, FRONT - 0.4), Vector3.new(side * 0.3, 1, -0.6), 0.35, 0.19)
	end
	ctx.strand("Head", darken(fur, 0.35), Vector3.new(0, TOP + 0.3, 0.2), Vector3.new(0, 0.6, 1), 0.9, 0.5)
end

ACC.hood = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(200, 30, 40)
	ctx.ball("Torso", "Hood", Vector3.new(1.6, 0.9, 0.7), CFrame.new(0, 0.95, 0.6), color)
	ctx.add("Torso", "HoodCollar", Vector3.new(2.06, 0.3, 1.08), CFrame.new(0, 0.86, 0), color)
end

ACC.hood_full = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(25, 25, 30)
	ctx.rounded("Head", "HoodTop", Vector3.new(HEAD_W + 0.26, 0.3, HEAD_D + 0.24), CFrame.new(0, TOP + 0.12, 0.04), color, HEAD_R + 0.1)
	ctx.add("Head", "HoodBack", Vector3.new(HEAD_W + 0.26, HEAD_H + 0.3, 0.2), CFrame.new(0, 0, BACK + 0.1), color)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HoodSide", Vector3.new(0.16, HEAD_H + 0.3, HEAD_D + 0.1), CFrame.new(side * (HEAD_W / 2 + 0.1), 0, 0.05), color)
	end
end

ACC.hair_ribbon = function(ctx, look)
	local pink = look.accColor or Color3.fromRGB(255, 120, 170)
	for _, side in { -1, 1 } do
		ctx.ball("Head", "Ribbon", Vector3.new(0.42, 0.3, 0.12), CFrame.new(side * 0.24, 0.42, BACK + 0.12) * CFrame.Angles(0, 0, 0.3 * side), pink)
	end
	ctx.ball("Head", "RibbonKnot", Vector3.new(0.16, 0.16, 0.14), CFrame.new(0, 0.42, BACK + 0.14), darken(pink, 0.2))
end

ACC.butterfly_clip = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(140, 80, 220)
	for _, side in { -1, 1 } do
		ctx.ball(
			"Head",
			"ButterflyWing",
			Vector3.new(0.12, 0.45, 0.55),
			CFrame.new(HEAD_W / 2 + 0.12, 0.45 + side * 0.15, 0.25 + side * 0.15) * CFrame.Angles(side * 0.6, 0, 0),
			color,
			{ Transparency = 0.15 }
		)
	end
end

-- Corps -----------------------------------------------------------------

ACC.belt = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(30, 30, 30)
	ctx.add("Torso", "Belt", Vector3.new(2.05, 0.26, 1.05), CFrame.new(0, -0.8, 0), color)
	ctx.ball("Torso", "BeltKnot", Vector3.new(0.34, 0.28, 0.16), CFrame.new(0.4, -0.8, -0.56), color)
	ctx.strand("Torso", color, Vector3.new(0.45, -0.85, -0.57), Vector3.new(0.15, -1, -0.1), 0.6, 0.18)
end

ACC.sash = function(ctx, look)
	local color = look.sashColor or look.accColor or Color3.fromRGB(240, 200, 80)
	ctx.add("Torso", "Sash", Vector3.new(0.3, 2.55, 1.06), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0.75), color)
end

ACC.cape = function(ctx, look)
	local color = look.capeColor or look.accColor or Color3.fromRGB(200, 40, 40)
	ctx.add("Torso", "Cape", Vector3.new(2.3, 3.5, 0.12), CFrame.new(0, -0.65, 0.66) * CFrame.Angles(0.1, 0, 0), color)
	ctx.add("Torso", "CapeLining", Vector3.new(2.2, 3.4, 0.04), CFrame.new(0, -0.65, 0.58) * CFrame.Angles(0.1, 0, 0), darken(color, 0.3))
	ctx.add("Torso", "CapeCollar", Vector3.new(2.3, 0.35, 1.2), CFrame.new(0, 0.9, 0.05), color)
	for _, side in { -1, 1 } do
		ctx.ball("Torso", "CapeClasp", Vector3.new(0.25, 0.25, 0.12), CFrame.new(side * 0.7, 0.85, -0.58), GOLD, { Material = Enum.Material.Metal })
	end
end

ACC.marine_coat = function(ctx, look)
	local white = WHITE
	ctx.add("Torso", "Coat", Vector3.new(2.4, 3.4, 0.12), CFrame.new(0, -0.55, 0.62) * CFrame.Angles(0.08, 0, 0), white)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "CoatShoulder", Vector3.new(1.3, 0.3, 1.3), CFrame.new(side * 1.5, 1.05, 0.05), white)
		ctx.add("Torso", "CoatSleeve", Vector3.new(0.12, 2.6, 1.1), CFrame.new(side * 2.1, -0.4, 0.15), white)
	end
	local _ = look
end

ACC.cloak_skirt = function(ctx, look)
	local color = look.skirtColor or look.top or Color3.fromRGB(40, 40, 50)
	ctx.add("Torso", "Skirt", Vector3.new(2.1, 1.6, 1.1), CFrame.new(0, -1.7, 0), color)
	ctx.add("Torso", "SkirtHem", Vector3.new(2.12, 0.12, 1.12), CFrame.new(0, -2.45, 0), darken(color, 0.3))
end

ACC.collar_high = function(ctx, look)
	local color = look.topAccent or look.top or Color3.fromRGB(30, 30, 40)
	ctx.rounded("Torso", "HighCollar", Vector3.new(1.55, 0.55, 1.45), CFrame.new(0, 1.12, 0), color, 0.3)
end

ACC.collar_gold = function(ctx, look)
	ctx.add("Torso", "GoldCollar", Vector3.new(2.15, 0.35, 1.15), CFrame.new(0, 0.85, 0), GOLD, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	ctx.ball("Torso", "Gem", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.75, -0.6), look.gemColor or Color3.fromRGB(80, 200, 255), { Material = Enum.Material.Neon })
end

ACC.scarf_long = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(60, 110, 210)
	ctx.rounded("Torso", "Scarf", Vector3.new(1.6, 0.36, 1.35), CFrame.new(0, 1.05, 0), color, 0.3)
	ctx.add("Torso", "ScarfTail", Vector3.new(0.35, 2.4, 0.1), CFrame.new(0.5, -0.1, 0.62) * CFrame.Angles(0.25, 0, 0.1), color)
	ctx.add("Torso", "ScarfTail", Vector3.new(0.35, 2.0, 0.1), CFrame.new(0.05, 0.0, 0.6) * CFrame.Angles(0.35, 0, -0.15), darken(color, 0.1))
end

ACC.shoulder_pads = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(230, 185, 80)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.rounded(side, "ShoulderPad", Vector3.new(1.3, 0.32, 1.3), CFrame.new(0, 1.05, 0), color, 0.3)
	end
end

ACC.wristbands = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(220, 40, 40)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.add(side, "Wristband", Vector3.new(1.08, 0.3, 1.08), CFrame.new(0, -0.5, 0), color)
	end
end

ACC.leg_warmers = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(255, 120, 30)
	for _, side in { "Left Leg", "Right Leg" } do
		ctx.add(side, "LegWarmer", Vector3.new(1.08, 0.75, 1.08), CFrame.new(0, -0.3, 0), color)
	end
end

local HAORI_TOP = 0.95

local function haoriBase(ctx, look, color: Color3, pattern: ((any, boolean) -> ())?)
	local length = 2.7
	local y = HAORI_TOP - length / 2
	local backPanel = ctx.add("Torso", "HaoriBack", Vector3.new(2.14, length, 0.1), CFrame.new(0, y, 0.56), color)
	local fronts = {}
	for _, side in { -1, 1 } do
		table.insert(fronts, ctx.add("Torso", "HaoriFront", Vector3.new(0.62, length, 0.1), CFrame.new(side * 0.76, y, -0.56), color))
		ctx.add("Torso", "HaoriSide", Vector3.new(0.1, length, 1.22), CFrame.new(side * 1.07, y, 0), color)
	end
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.add(side, "HaoriSleeve", Vector3.new(1.22, 1.3, 1.22), CFrame.new(0, 0.38, 0), color)
	end
	if pattern then
		paintPanel(ctx, backPanel, Enum.NormalId.Back, function(canvas)
			pattern(canvas, true)
		end)
		for _, panel in fronts do
			paintPanel(ctx, panel, Enum.NormalId.Front, function(canvas)
				pattern(canvas, false)
			end)
		end
	end
	local _ = look
end

ACC.haori = function(ctx, look)
	-- Jaune avec des triangles blancs en bas.
	haoriBase(ctx, look, look.accColor or Color3.fromRGB(255, 205, 40), function(canvas, isBack)
		local n = isBack and 5 or 2
		for i = 0, n - 1 do
			Painter.rect(canvas, (i + 0.5) / n, 0.98, 0.7 / n, 0.24, WHITE, { rotation = 45, z = 2 })
		end
	end)
end

ACC.haori_checker = function(ctx, look)
	local green = look.accColor or Color3.fromRGB(40, 130, 90)
	haoriBase(ctx, look, BLACK, function(canvas, isBack)
		local cols = isBack and 6 or 2
		local rows = 8
		for r = 0, rows - 1 do
			for col = 0, cols - 1 do
				if (r + col) % 2 == 0 then
					Painter.rect(canvas, (col + 0.5) / cols, (r + 0.5) / rows, 1 / cols + 0.002, 1 / rows + 0.002, green, { z = 2 })
				end
			end
		end
	end)
end

ACC.haori_flame = function(ctx, look)
	haoriBase(ctx, look, look.accColor or WHITE, function(canvas, isBack)
		local n = isBack and 7 or 2
		for i = 0, n - 1 do
			local x = (i + 0.5) / n
			Painter.rect(canvas, x, 0.9, 0.9 / n, 0.32, Color3.fromRGB(230, 50, 20), { corner = 0.5, z = 2 })
			Painter.rect(canvas, x, 0.93, 0.5 / n, 0.18, Color3.fromRGB(255, 170, 40), { corner = 0.5, z = 3 })
		end
	end)
end

ACC.haori_sage = function(ctx, look)
	-- Manteau d'ermite rouge avec des flammes noires en bas.
	haoriBase(ctx, look, look.accColor or Color3.fromRGB(200, 40, 40), function(canvas, isBack)
		local n = isBack and 6 or 2
		for i = 0, n - 1 do
			Painter.rect(canvas, (i + 0.5) / n, 0.97, 0.75 / n, 0.3, BLACK, { rotation = 45, z = 2 })
		end
		if isBack then
			Painter.rect(canvas, 0.5, 0.3, 0.35, 0.2, BLACK, { corner = 0.3, z = 2 })
		end
	end)
end

local function sword(ctx, limb: string, cf: CFrame, handle: Color3, sheath: Color3?, length: number?)
	local l = length or 2.8
	ctx.add(limb, "Sheath", Vector3.new(0.2, l, 0.2), cf, sheath or Color3.fromRGB(30, 30, 35))
	ctx.cyl(limb, "Guard", 0.08, 0.45, cf * CFrame.new(0, l / 2 + 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, { Material = Enum.Material.Metal })
	ctx.add(limb, "Handle", Vector3.new(0.18, 0.8, 0.18), cf * CFrame.new(0, l / 2 + 0.48, 0), handle)
end

ACC.sword_hip = function(ctx, look)
	sword(ctx, "Torso", CFrame.new(-1.12, -0.75, 0.05) * CFrame.Angles(math.rad(-70), 0, 0), look.accColor or WHITE)
end

ACC.swords = function(ctx, look)
	local handle = look.accColor or WHITE
	sword(ctx, "Torso", CFrame.new(-1.12, -0.75, -0.1) * CFrame.Angles(math.rad(-70), 0, 0), handle)
	sword(ctx, "Torso", CFrame.new(-1.15, -0.8, 0.2) * CFrame.Angles(math.rad(-65), 0, 0), Color3.fromRGB(200, 40, 40))
	sword(ctx, "Torso", CFrame.new(1.12, -0.75, 0.05) * CFrame.Angles(math.rad(-70), 0, 0), Color3.fromRGB(30, 30, 30))
end

ACC.sword_back = function(ctx, look)
	sword(ctx, "Torso", CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, 0.75), look.accColor or Color3.fromRGB(80, 60, 130), nil, 3.2)
end

ACC.big_sword = function(ctx, look)
	-- Énorme couperet porté dans le dos.
	local cf = CFrame.new(0.2, 0.2, 0.68) * CFrame.Angles(0, 0, -0.6)
	ctx.add("Torso", "Cleaver", Vector3.new(1.0, 4.2, 0.08), cf, METAL, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	ctx.ball("Torso", "CleaverHole", Vector3.new(0.4, 0.4, 0.1), cf * CFrame.new(0.15, 1.6, 0), BLACK)
	ctx.add("Torso", "CleaverHandle", Vector3.new(0.2, 1.0, 0.2), cf * CFrame.new(0, -2.55, 0), look.accColor or Color3.fromRGB(70, 60, 50))
end

ACC.hammer = function(ctx, look)
	local cf = CFrame.new(0, -0.95, -0.6) * CFrame.Angles(math.rad(90), 0, 0)
	ctx.add("Right Arm", "HammerHandle", Vector3.new(0.18, 1.8, 0.18), cf, look.accColor or Color3.fromRGB(110, 80, 60))
	ctx.add("Right Arm", "HammerHead", Vector3.new(0.9, 0.5, 0.5), cf * CFrame.new(0, 0.9, 0), METAL, { Material = Enum.Material.Metal })
end

ACC.spear = function(ctx, look)
	local cf = CFrame.new(0, -0.9, -0.45)
	ctx.add("Right Arm", "SpearShaft", Vector3.new(0.16, 5.0, 0.16), cf, look.accColor or Color3.fromRGB(120, 100, 70))
	ctx.ball("Right Arm", "SpearTip", Vector3.new(0.3, 0.8, 0.1), cf * CFrame.new(0, 2.8, 0), METAL, { Material = Enum.Material.Metal })
end

ACC.tail = function(ctx, look)
	local color = look.tailColor or Color3.fromRGB(120, 80, 50)
	if look.hair == "none" then
		color = look.skin
	end
	ctx.strand("Torso", color, Vector3.new(0, -0.75, 0.45), Vector3.new(0.1, -0.2, 1), 1.0, 0.3)
	ctx.strand("Torso", color, Vector3.new(0.05, -0.85, 1.2), Vector3.new(0.3, 1, 0.4), 0.8, 0.28)
end

ACC.tails9 = function(ctx, look)
	local fur = look.accColor or Color3.fromRGB(255, 120, 20)
	for i = 0, 8 do
		local a = -1.2 + i * (2.4 / 8)
		ctx.strand("Torso", fur, Vector3.new(0, -0.7, 0.5), Vector3.new(math.sin(a), math.cos(a) * 0.9 + 0.1, 0.8), 3.2, 0.8, lighten(fur, 0.6))
	end
end

ACC.fins = function(ctx, look)
	local fin = look.accColor or Color3.fromRGB(60, 120, 180)
	ctx.ball("Torso", "DorsalFin", Vector3.new(0.12, 1.3, 0.9), CFrame.new(0, 0.5, 0.75) * CFrame.Angles(-0.4, 0, 0), fin)
	for _, side in { "Left Arm", "Right Arm" } do
		ctx.ball(side, "ArmFin", Vector3.new(0.1, 0.8, 0.6), CFrame.new(0, 0.1, 0.6) * CFrame.Angles(-0.3, 0, 0), fin)
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

export type BuildOptions = {
	scale: number?,
	name: string?,
	humanoid: boolean?,
	anchored: boolean?,
	walkSpeed: number?,
	collisionGroup: string?,
	paint: string?, -- "gui" (par défaut) ou "parts" (aperçus des menus)
}

local HATS = { "boar_head", "hood_full", "straw_hat", "volcano", "dome", "turban", "cap", "bandana" }

function CharacterBuilder.build(look, options: BuildOptions?): Model
	local opts = options or {}
	local s = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = opts.name or "Character"

	local ctx = newContext(model, s, opts.paint or "gui")
	buildBody(ctx, look)

	local hairColor = look.hairColor or BLACK
	local covered = false
	for _, hat in HATS do
		if has(look, hat) then
			covered = true
			break
		end
	end
	if not covered then
		local builder = HAIR[look.hair or "short"] or HAIR.short
		builder(ctx, hairColor, look)
	elseif (has(look, "straw_hat") or has(look, "cap") or has(look, "bandana")) and look.hair ~= "none" and look.hair ~= "bald" then
		-- Cheveux visibles sous le chapeau.
		back(ctx, hairColor, 1.0)
		sides(ctx, hairColor, 0.7)
		fringe(ctx, hairColor, { -0.35, 0, 0.35 }, 0.38, 0.34)
	end

	for _, accessory in look.accessories or {} do
		local builder = ACC[accessory]
		if builder then
			builder(ctx, look)
		end
	end

	local root = ctx.limbs.HumanoidRootPart
	model.PrimaryPart = root
	if opts.anchored then
		root.Anchored = true
	end

	if opts.collisionGroup then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = opts.collisionGroup
			end
		end
	end

	if opts.humanoid then
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.WalkSpeed = opts.walkSpeed or 16
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.AutoJumpEnabled = true
		humanoid.MaxHealth = 1e9
		humanoid.Health = 1e9
		humanoid.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	else
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = controller
	end

	model:SetAttribute("BaseScale", s)
	model:SetAttribute("RootHeight", CharacterBuilder.RootHeight * s)
	return model
end

-- Modèle ancré pour les aperçus des menus (visage et tenue en pièces : visibles en ViewportFrame).
function CharacterBuilder.buildPreview(look): Model
	local model = CharacterBuilder.build(look, { scale = 1, name = "Preview", paint = "parts" })
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

return CharacterBuilder
