-- Construit des personnages d'animé en blocs (style voxel / chibi) à partir d'un "look".
-- Utilisé par le serveur (persos de la base, équipe, ennemis) et le client (aperçus UI).
--
-- Le modèle est construit pieds au sol en (0,0,0), face vers -Z, puis déplacé via PivotTo.
-- Les membres sont reliés par des Motor6D (attribut "BaseC0") pour l'animation procédurale côté client.

local CharacterBuilder = {}

local DEFAULT_EYES = Color3.fromRGB(35, 30, 45)
local DEFAULT_SHOES = Color3.fromRGB(45, 40, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(25, 22, 28)
local MOUTH = Color3.fromRGB(120, 30, 40)
local METAL = Color3.fromRGB(195, 200, 210)

-- Centres des membres (échelle 1), pieds au sol.
local CENTERS = {
	HumanoidRootPart = CFrame.new(0, 2.15, 0),
	Torso = CFrame.new(0, 2.15, 0),
	Head = CFrame.new(0, 4.1, 0),
	LeftArm = CFrame.new(-1.4, 2.2, 0),
	RightArm = CFrame.new(1.4, 2.2, 0),
	LeftLeg = CFrame.new(-0.5, 0.65, 0),
	RightLeg = CFrame.new(0.5, 0.65, 0),
}

local SIZES = {
	HumanoidRootPart = Vector3.new(2, 1.7, 1.1),
	Torso = Vector3.new(2, 1.7, 1.1),
	Head = Vector3.new(2.3, 2.2, 2.2),
	LeftArm = Vector3.new(0.8, 1.6, 0.8),
	RightArm = Vector3.new(0.8, 1.6, 0.8),
	LeftLeg = Vector3.new(0.95, 1.3, 0.95),
	RightLeg = Vector3.new(0.95, 1.3, 0.95),
}

-- Articulations : { nom, parent, enfant, position du pivot }
local JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", Vector3.new(0, 2.15, 0) },
	{ "Neck", "Torso", "Head", Vector3.new(0, 3.0, 0) },
	{ "LeftShoulder", "Torso", "LeftArm", Vector3.new(-1.4, 2.8, 0) },
	{ "RightShoulder", "Torso", "RightArm", Vector3.new(1.4, 2.8, 0) },
	{ "LeftHip", "Torso", "LeftLeg", Vector3.new(-0.5, 1.3, 0) },
	{ "RightHip", "Torso", "RightLeg", Vector3.new(0.5, 1.3, 0) },
}

CharacterBuilder.HipHeight = 1.3
CharacterBuilder.Height = 5.2

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * cf.Rotation
end

local function has(look, accessory: string): boolean
	return look.accessories ~= nil and table.find(look.accessories, accessory) ~= nil
end

------------------------------------------------------------------------
-- Contexte de construction
------------------------------------------------------------------------

local function newContext(model: Model, s: number)
	local ctx = { model = model, s = s, limbs = {} }

	-- Crée une pièce attachée à un membre. `offset` est relatif au centre du membre (échelle 1).
	function ctx.add(limbName: string, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?)
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

	return ctx
end

------------------------------------------------------------------------
-- Corps de base
------------------------------------------------------------------------

local function buildBody(ctx, look, options)
	local model, s = ctx.model, ctx.s
	local skin = look.skin or Color3.fromRGB(255, 221, 189)
	local top = look.top or WHITE
	local bottom = look.bottom or BLACK
	local bareTorso = look.shirtless or has(look, "vest_open")
	local bareArms = look.sleeveless or look.shirtless

	local colors = {
		HumanoidRootPart = WHITE,
		Torso = bareTorso and skin or top,
		Head = skin,
		LeftArm = bareArms and skin or top,
		RightArm = bareArms and skin or top,
		LeftLeg = bottom,
		RightLeg = bottom,
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
		local name, parentName, childName, pivot = joint[1], joint[2], joint[3], joint[4]
		local part0, part1 = ctx.limbs[parentName], ctx.limbs[childName]
		local pivotCF = CFrame.new(pivot * s)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = part0.CFrame:Inverse() * pivotCF
		motor.C1 = part1.CFrame:Inverse() * pivotCF
		motor:SetAttribute("BaseC0", motor.C0)
		motor.Parent = part0
	end

	-- Mains (couleur peau) et chaussures.
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "Hand", Vector3.new(0.84, 0.42, 0.84), CFrame.new(0, -0.62, 0), skin)
		if not bareArms then
			-- Bord de manche légèrement plus foncé.
			ctx.add(side, "Cuff", Vector3.new(0.86, 0.14, 0.86), CFrame.new(0, -0.36, 0), darken(top, 0.18))
		end
	end
	local shoes = look.shoes or DEFAULT_SHOES
	for _, side in { "LeftLeg", "RightLeg" } do
		ctx.add(side, "Shoe", Vector3.new(1.0, 0.34, 1.12), CFrame.new(0, -0.5, -0.07), shoes)
	end

	-- Détail de tenue : encolure avec la couleur secondaire.
	if not bareTorso and look.topAccent then
		ctx.add("Torso", "Neckline", Vector3.new(2.04, 0.24, 1.14), CFrame.new(0, 0.73, 0), look.topAccent)
		ctx.add("Torso", "Waist", Vector3.new(2.04, 0.2, 1.14), CFrame.new(0, -0.75, 0), look.topAccent)
	end
	if look.shirtless then
		-- Abdos stylisés.
		ctx.add("Torso", "Abs", Vector3.new(0.08, 0.9, 0.05), CFrame.new(0, -0.15, -0.56), darken(skin, 0.15))
		ctx.add("Torso", "Pecs", Vector3.new(1.3, 0.07, 0.05), CFrame.new(0, 0.25, -0.56), darken(skin, 0.15))
	end
	-- Ceinture du pantalon.
	ctx.add("Torso", "Belt", Vector3.new(2.03, 0.12, 1.13), CFrame.new(0, -0.82, 0), darken(bottom, 0.25))

	local _ = options
end

------------------------------------------------------------------------
-- Visage
------------------------------------------------------------------------

local function buildFace(ctx, look)
	if has(look, "boar_head") then
		return
	end
	local eyes = look.eyes or DEFAULT_EYES
	local face = look.face or "calm"
	local browColor = darken(look.hairColor or BLACK, 0.35)
	if look.hair == "bald" or look.hair == "none" then
		browColor = darken(look.skin or WHITE, 0.5)
	end
	local hideEyes = has(look, "blindfold")
	local Z = -1.1

	if not hideEyes then
		if has(look, "cyclops") then
			ctx.add("Head", "EyeWhite", Vector3.new(0.95, 0.8, 0.05), CFrame.new(0, 0, Z - 0.02), WHITE)
			ctx.add("Head", "Iris", Vector3.new(0.55, 0.6, 0.05), CFrame.new(0, -0.05, Z - 0.05), eyes)
			ctx.add("Head", "Shine", Vector3.new(0.18, 0.18, 0.05), CFrame.new(-0.12, 0.12, Z - 0.08), WHITE)
			ctx.add("Head", "Brow", Vector3.new(1.1, 0.14, 0.06), CFrame.new(0, 0.5, Z - 0.03), browColor)
		else
			for _, side in { -1, 1 } do
				local x = 0.48 * side
				ctx.add("Head", "EyeWhite", Vector3.new(0.55, 0.62, 0.05), CFrame.new(x, -0.1, Z - 0.02), WHITE)
				ctx.add("Head", "Iris", Vector3.new(0.4, 0.52, 0.05), CFrame.new(x - 0.03 * side, -0.14, Z - 0.05), eyes)
				ctx.add("Head", "Pupil", Vector3.new(0.2, 0.26, 0.05), CFrame.new(x - 0.03 * side, -0.18, Z - 0.07), darken(eyes, 0.6))
				ctx.add("Head", "Shine", Vector3.new(0.14, 0.14, 0.05), CFrame.new(x + 0.08 * side, 0.0, Z - 0.09), WHITE)

				-- Sourcils : orientation selon l'expression.
				local tilt = 0
				if face == "angry" then
					tilt = 0.38
				elseif face == "fierce" then
					tilt = 0.24
				elseif face == "happy" then
					tilt = -0.12
				elseif face == "smirk" then
					tilt = side > 0 and -0.2 or 0.15
				end
				local browY = 0.33
				if face == "smirk" and side > 0 then
					browY = 0.4
				end
				ctx.add("Head", "Brow", Vector3.new(0.62, 0.13, 0.06), CFrame.new(x, browY, Z - 0.03) * CFrame.Angles(0, 0, tilt * side), browColor)
			end
		end
	end

	-- Bouche (cachée par les masques).
	if has(look, "mask_lower") or has(look, "muzzle") then
		return
	end
	if face == "happy" then
		ctx.add("Head", "Mouth", Vector3.new(0.6, 0.22, 0.05), CFrame.new(0, -0.62, Z - 0.02), MOUTH)
		ctx.add("Head", "Teeth", Vector3.new(0.6, 0.08, 0.05), CFrame.new(0, -0.55, Z - 0.04), WHITE)
	elseif face == "fierce" then
		ctx.add("Head", "Mouth", Vector3.new(0.55, 0.3, 0.05), CFrame.new(0, -0.62, Z - 0.02), MOUTH)
		ctx.add("Head", "Teeth", Vector3.new(0.55, 0.08, 0.05), CFrame.new(0, -0.51, Z - 0.04), WHITE)
		ctx.add("Head", "TeethLow", Vector3.new(0.55, 0.06, 0.05), CFrame.new(0, -0.74, Z - 0.04), WHITE)
	elseif face == "angry" then
		ctx.add("Head", "Mouth", Vector3.new(0.5, 0.1, 0.05), CFrame.new(0, -0.62, Z - 0.02), BLACK)
		ctx.add("Head", "MouthCorner", Vector3.new(0.12, 0.12, 0.05), CFrame.new(-0.28, -0.66, Z - 0.02), BLACK)
		ctx.add("Head", "MouthCorner2", Vector3.new(0.12, 0.12, 0.05), CFrame.new(0.28, -0.66, Z - 0.02), BLACK)
	elseif face == "smirk" then
		ctx.add("Head", "Mouth", Vector3.new(0.45, 0.09, 0.05), CFrame.new(0.08, -0.6, Z - 0.02) * CFrame.Angles(0, 0, 0.22), BLACK)
	else
		ctx.add("Head", "Mouth", Vector3.new(0.34, 0.08, 0.05), CFrame.new(0, -0.62, Z - 0.02), BLACK)
	end
end

------------------------------------------------------------------------
-- Coiffures
------------------------------------------------------------------------

local HX, HY, HZ = 1.15, 1.1, 1.1

local function hairCap(ctx, color, height)
	ctx.add("Head", "HairCap", Vector3.new(2.5, height, 2.42), CFrame.new(0, HY + height / 2 - 0.12, 0.03), color)
end

local function hairBack(ctx, color, length)
	ctx.add("Head", "HairBack", Vector3.new(2.5, length, 0.42), CFrame.new(0, HY - length / 2 + 0.1, HZ + 0.15), color)
end

local function hairSides(ctx, color, length)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.3, length, 1.9), CFrame.new((HX + 0.12) * side, HY - length / 2 + 0.1, 0.2), color)
	end
end

local function hairFringe(ctx, color)
	ctx.add("Head", "Fringe", Vector3.new(2.5, 0.36, 0.3), CFrame.new(0, HY - 0.12, -HZ - 0.1), color)
end

local function spike(ctx, color, pos: Vector3, size: Vector3, rot: Vector3, tip: Color3?)
	local cf = CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
	ctx.add("Head", "Spike", size, cf, color)
	if tip then
		ctx.add("Head", "SpikeTip", size * Vector3.new(0.9, 0.4, 0.9), cf * CFrame.new(0, size.Y * 0.42, 0), tip)
	end
end

local HAIR = {}

HAIR.short = function(ctx, c, look)
	hairCap(ctx, c, 0.45)
	hairBack(ctx, c, 1.2)
	hairSides(ctx, c, 0.8)
	hairFringe(ctx, c)
	for i = -1, 1 do
		spike(ctx, c, Vector3.new(i * 0.7, HY - 0.3, -HZ - 0.12), Vector3.new(0.55, 0.45, 0.25), Vector3.new(0, 0, math.rad(45)), nil)
	end
	local _ = look
end

HAIR.spiky = function(ctx, c, look)
	local tip = look.hairTip
	hairCap(ctx, c, 0.5)
	hairBack(ctx, c, 1.3)
	hairSides(ctx, c, 0.9)
	hairFringe(ctx, c)
	-- Mèches en pointe sur le front.
	for i = -1.5, 1.5 do
		spike(ctx, c, Vector3.new(i * 0.58, HY - 0.32, -HZ - 0.12), Vector3.new(0.5, 0.5, 0.26), Vector3.new(0, 0, math.rad(45)), nil)
	end
	-- Piques sur le dessus.
	local spikes = {
		{ Vector3.new(-0.8, HY + 0.55, -0.35), Vector3.new(0, 0, 0.55) },
		{ Vector3.new(0, HY + 0.75, -0.25), Vector3.new(-0.2, 0, 0) },
		{ Vector3.new(0.8, HY + 0.55, -0.35), Vector3.new(0, 0, -0.55) },
		{ Vector3.new(-0.55, HY + 0.6, 0.55), Vector3.new(-0.5, 0, 0.45) },
		{ Vector3.new(0.55, HY + 0.6, 0.55), Vector3.new(-0.5, 0, -0.45) },
		{ Vector3.new(0, HY + 0.45, 1.0), Vector3.new(-0.95, 0, 0) },
		{ Vector3.new(-1.3, HY - 0.05, 0.2), Vector3.new(0, 0, 1.05) },
		{ Vector3.new(1.3, HY - 0.05, 0.2), Vector3.new(0, 0, -1.05) },
	}
	for _, sp in spikes do
		spike(ctx, c, sp[1], Vector3.new(0.75, 1.05, 0.75), sp[2], tip)
	end
end

HAIR.spiky_back = function(ctx, c, look)
	hairCap(ctx, c, 0.5)
	hairSides(ctx, c, 1.0)
	hairFringe(ctx, c)
	-- Longues mèches qui encadrent le visage.
	for _, side in { -1, 1 } do
		ctx.add("Head", "Bang", Vector3.new(0.42, 1.3, 0.3), CFrame.new(0.92 * side, 0.35, -HZ - 0.12) * CFrame.Angles(0, 0, 0.12 * side), c)
	end
	ctx.add("Head", "Bang", Vector3.new(0.5, 0.9, 0.3), CFrame.new(-0.2, 0.55, -HZ - 0.14) * CFrame.Angles(0, 0, -0.2), c)
	-- Piques vers l'arrière.
	local spikes = {
		{ Vector3.new(0, HY + 0.3, 1.0), Vector3.new(-1.0, 0, 0) },
		{ Vector3.new(-0.6, HY + 0.1, 1.15), Vector3.new(-1.2, 0, 0.35) },
		{ Vector3.new(0.6, HY + 0.1, 1.15), Vector3.new(-1.2, 0, -0.35) },
		{ Vector3.new(0, HY - 0.3, 1.35), Vector3.new(-1.4, 0, 0) },
		{ Vector3.new(-0.5, HY + 0.5, 0.4), Vector3.new(-0.6, 0, 0.3) },
		{ Vector3.new(0.5, HY + 0.5, 0.4), Vector3.new(-0.6, 0, -0.3) },
	}
	for _, sp in spikes do
		spike(ctx, c, sp[1], Vector3.new(0.8, 1.2, 0.8), sp[2], look.hairTip)
	end
end

HAIR.wild = function(ctx, c, look)
	hairCap(ctx, c, 0.6)
	hairBack(ctx, c, 1.2)
	hairSides(ctx, c, 0.8)
	hairFringe(ctx, c)
	for i = -1, 1 do
		spike(ctx, c, Vector3.new(i * 0.75, HY - 0.32, -HZ - 0.12), Vector3.new(0.55, 0.6, 0.26), Vector3.new(0, 0, math.rad(45)), nil)
	end
	local spikes = {
		{ Vector3.new(-0.7, HY + 0.9, -0.3), Vector3.new(0.15, 0, 0.35) },
		{ Vector3.new(0, HY + 1.05, -0.1), Vector3.new(0.05, 0, 0.05) },
		{ Vector3.new(0.7, HY + 0.9, -0.2), Vector3.new(0.1, 0, -0.4) },
		{ Vector3.new(-0.45, HY + 0.85, 0.6), Vector3.new(-0.3, 0, 0.3) },
		{ Vector3.new(0.45, HY + 0.85, 0.6), Vector3.new(-0.3, 0, -0.3) },
		{ Vector3.new(-1.15, HY + 0.4, 0.1), Vector3.new(0, 0, 0.8) },
		{ Vector3.new(1.15, HY + 0.4, 0.1), Vector3.new(0, 0, -0.8) },
		{ Vector3.new(0, HY + 0.5, 1.0), Vector3.new(-0.7, 0, 0) },
	}
	for _, sp in spikes do
		spike(ctx, c, sp[1], Vector3.new(0.8, 1.5, 0.8), sp[2], look.hairTip)
	end
end

HAIR.tall_spiky = function(ctx, c, look)
	HAIR.wild(ctx, c, look)
	-- Très longue crinière dorée.
	ctx.add("Head", "Mane", Vector3.new(2.4, 4.2, 0.6), CFrame.new(0, -1.4, HZ + 0.35), c)
	ctx.add("Head", "Mane2", Vector3.new(1.8, 1.0, 0.6), CFrame.new(0, -3.9, HZ + 0.3) * CFrame.Angles(0, 0, math.rad(45)), c)
	ctx.add("Head", "Fringe2", Vector3.new(0.5, 1.4, 0.3), CFrame.new(-0.3, 0.3, -HZ - 0.15) * CFrame.Angles(0, 0, 0.15), c)
end

HAIR.long = function(ctx, c, look)
	hairCap(ctx, c, 0.45)
	hairFringe(ctx, c)
	ctx.add("Head", "HairBack", Vector3.new(2.5, 3.0, 0.45), CFrame.new(0, -0.35, HZ + 0.16), c)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.3, 2.6, 1.7), CFrame.new((HX + 0.12) * side, -0.15, 0.25), c)
		ctx.add("Head", "Bang", Vector3.new(0.45, 1.0, 0.3), CFrame.new(0.95 * side, 0.4, -HZ - 0.12), c)
	end
	if look.hairTip then
		ctx.add("Head", "HairTip", Vector3.new(2.52, 0.7, 0.47), CFrame.new(0, -1.55, HZ + 0.16), look.hairTip)
		for _, side in { -1, 1 } do
			ctx.add("Head", "HairSideTip", Vector3.new(0.32, 0.6, 1.72), CFrame.new((HX + 0.12) * side, -1.2, 0.25), look.hairTip)
		end
	end
end

HAIR.ponytail = function(ctx, c, look)
	hairCap(ctx, c, 0.45)
	hairBack(ctx, c, 1.1)
	hairSides(ctx, c, 0.9)
	hairFringe(ctx, c)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Bang", Vector3.new(0.4, 1.0, 0.3), CFrame.new(0.95 * side, 0.4, -HZ - 0.12), c)
	end
	ctx.add("Head", "Tie", Vector3.new(0.6, 0.3, 0.3), CFrame.new(0, 0.3, HZ + 0.45), darken(c, 0.4))
	ctx.add("Head", "Tail", Vector3.new(0.7, 2.4, 0.7), CFrame.new(0, -0.9, HZ + 0.7) * CFrame.Angles(0.25, 0, 0), c)
	if look.hairTip then
		ctx.add("Head", "TailTip", Vector3.new(0.72, 0.6, 0.72), CFrame.new(0, -2.0, HZ + 1.0) * CFrame.Angles(0.25, 0, 0), look.hairTip)
	end
end

HAIR.ponytail_spiky = function(ctx, c, look)
	hairCap(ctx, c, 0.45)
	hairBack(ctx, c, 0.9)
	hairSides(ctx, c, 0.7)
	ctx.add("Head", "Tie", Vector3.new(0.5, 0.3, 0.4), CFrame.new(0, HY + 0.3, 0.9), darken(c, 0.4))
	spike(ctx, c, Vector3.new(0, HY + 0.85, 1.05), Vector3.new(0.75, 1.1, 0.75), Vector3.new(-0.5, 0, 0), look.hairTip)
	spike(ctx, c, Vector3.new(-0.3, HY + 0.8, 1.15), Vector3.new(0.6, 0.9, 0.6), Vector3.new(-0.7, 0, 0.6), look.hairTip)
	spike(ctx, c, Vector3.new(0.3, HY + 0.8, 1.15), Vector3.new(0.6, 0.9, 0.6), Vector3.new(-0.7, 0, -0.6), look.hairTip)
end

HAIR.slick = function(ctx, c, look)
	hairCap(ctx, c, 0.5)
	hairBack(ctx, c, 1.4)
	hairSides(ctx, c, 0.7)
	ctx.add("Head", "Part", Vector3.new(1.2, 0.3, 0.3), CFrame.new(-0.6, HY + 0.15, -HZ - 0.05), c)
	local _ = look
end

HAIR.slick_up = function(ctx, c, look)
	hairCap(ctx, c, 0.45)
	hairBack(ctx, c, 1.1)
	hairSides(ctx, c, 0.6)
	local spikes = {
		{ Vector3.new(0, HY + 0.45, -0.6), Vector3.new(-0.9, 0, 0) },
		{ Vector3.new(-0.7, HY + 0.4, -0.4), Vector3.new(-0.9, 0, 0.3) },
		{ Vector3.new(0.7, HY + 0.4, -0.4), Vector3.new(-0.9, 0, -0.3) },
		{ Vector3.new(0, HY + 0.5, 0.3), Vector3.new(-1.1, 0, 0) },
		{ Vector3.new(-0.6, HY + 0.4, 0.5), Vector3.new(-1.2, 0, 0.3) },
		{ Vector3.new(0.6, HY + 0.4, 0.5), Vector3.new(-1.2, 0, -0.3) },
	}
	for _, sp in spikes do
		spike(ctx, c, sp[1], Vector3.new(0.7, 1.2, 0.7), sp[2], look.hairTip)
	end
end

HAIR.bob = function(ctx, c, look)
	hairCap(ctx, c, 0.5)
	hairBack(ctx, c, 1.9)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HairSide", Vector3.new(0.34, 1.9, 2.0), CFrame.new((HX + 0.13) * side, HY - 0.85, 0.15), c)
	end
	ctx.add("Head", "Fringe", Vector3.new(2.5, 0.6, 0.3), CFrame.new(0, HY - 0.2, -HZ - 0.1), c)
	local _ = look
end

HAIR.flame = function(ctx, c, look)
	local tip = look.hairTip or c
	hairSides(ctx, c, 0.6)
	ctx.add("Head", "Flame1", Vector3.new(2.45, 0.9, 2.3), CFrame.new(0, HY + 0.35, 0.1), c)
	ctx.add("Head", "Flame2", Vector3.new(2.0, 0.9, 1.9), CFrame.new(0, HY + 1.15, 0.2), c)
	ctx.add("Head", "Flame3", Vector3.new(1.4, 0.9, 1.3), CFrame.new(0, HY + 1.95, 0.3), tip)
	ctx.add("Head", "Flame4", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, HY + 2.6, 0.35) * CFrame.Angles(0, math.rad(45), 0), tip)
	for _, side in { -1, 1 } do
		spike(ctx, c, Vector3.new(1.05 * side, HY + 0.9, 0.2), Vector3.new(0.7, 1.3, 0.7), Vector3.new(0, 0, -0.45 * side), nil)
	end
	-- Pointe sur le front.
	ctx.add("Head", "Peak", Vector3.new(0.6, 0.6, 0.3), CFrame.new(0, HY - 0.05, -HZ - 0.08) * CFrame.Angles(0, 0, math.rad(45)), c)
end

HAIR.curly = function(ctx, c, look)
	hairBack(ctx, c, 1.3)
	hairSides(ctx, c, 1.0)
	local bumps = {
		Vector3.new(-0.7, HY + 0.2, -0.6),
		Vector3.new(0.1, HY + 0.3, -0.7),
		Vector3.new(0.8, HY + 0.2, -0.5),
		Vector3.new(-0.8, HY + 0.3, 0.3),
		Vector3.new(0, HY + 0.45, 0.1),
		Vector3.new(0.8, HY + 0.3, 0.3),
		Vector3.new(-0.4, HY + 0.3, 0.9),
		Vector3.new(0.4, HY + 0.3, 0.9),
	}
	for i, pos in bumps do
		ctx.add("Head", "Curl", Vector3.new(1.0, 0.9, 1.0), CFrame.new(pos) * CFrame.Angles(0, i * 0.4, 0), c)
	end
	local _ = look
end

HAIR.messy = function(ctx, c, look)
	hairCap(ctx, c, 0.55)
	hairBack(ctx, c, 1.3)
	hairSides(ctx, c, 0.9)
	local bangs = { { -0.85, 0.5 }, { -0.3, 0.7 }, { 0.25, 0.55 }, { 0.8, 0.65 } }
	for i, b in bangs do
		ctx.add("Head", "Bang", Vector3.new(0.55, b[2], 0.3), CFrame.new(b[1], HY - 0.05 - b[2] / 2 + 0.2, -HZ - 0.12) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.18 or -0.18), c)
	end
	spike(ctx, c, Vector3.new(-0.5, HY + 0.45, 0.4), Vector3.new(0.7, 0.8, 0.7), Vector3.new(-0.4, 0, 0.5), nil)
	spike(ctx, c, Vector3.new(0.6, HY + 0.4, 0.5), Vector3.new(0.7, 0.8, 0.7), Vector3.new(-0.4, 0, -0.5), nil)
	local _ = look
end

HAIR.cover_eye = function(ctx, c, look)
	hairCap(ctx, c, 0.45)
	hairBack(ctx, c, 1.2)
	hairSides(ctx, c, 0.9)
	ctx.add("Head", "Fringe", Vector3.new(1.4, 0.36, 0.3), CFrame.new(-0.55, HY - 0.12, -HZ - 0.1), c)
	-- La longue mèche qui cache un œil.
	ctx.add("Head", "Cover", Vector3.new(1.15, 1.25, 0.25), CFrame.new(0.55, 0.35, -HZ - 0.2), c)
	local _ = look
end

HAIR.bald = function(ctx, c, look)
	-- Petit reflet sur le crâne.
	ctx.add("Head", "Shine", Vector3.new(0.6, 0.05, 0.4), CFrame.new(-0.4, HY + 0.02, -0.3), lighten(look.skin or WHITE, 0.4))
	local _ = c
end

HAIR.none = function() end

------------------------------------------------------------------------
-- Accessoires
------------------------------------------------------------------------

local ACC = {}
local Z = -1.1

ACC.headband = function(ctx, look)
	local band = look.headbandColor or Color3.fromRGB(40, 50, 90)
	ctx.add("Head", "Headband", Vector3.new(2.42, 0.38, 2.32), CFrame.new(0, 0.62, 0), band)
	ctx.add("Head", "Plate", Vector3.new(1.05, 0.42, 0.08), CFrame.new(0, 0.62, Z - 0.13), METAL, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	ctx.add("Head", "Symbol", Vector3.new(0.35, 0.1, 0.05), CFrame.new(0, 0.62, Z - 0.18), Color3.fromRGB(70, 75, 90))
	ctx.add("Head", "Knot", Vector3.new(0.35, 0.35, 0.3), CFrame.new(0, 0.62, -Z + 0.2), band)
	ctx.add("Head", "Tail", Vector3.new(0.25, 0.8, 0.12), CFrame.new(0.2, 0.25, -Z + 0.3) * CFrame.Angles(0.3, 0, -0.3), band)
end

ACC.mask_lower = function(ctx, look)
	ctx.add("Head", "Mask", Vector3.new(2.36, 0.85, 2.26), CFrame.new(0, -0.68, 0), look.accColor or Color3.fromRGB(40, 45, 60))
end

ACC.whiskers = function(ctx, look)
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			ctx.add(
				"Head",
				"Whisker",
				Vector3.new(0.42, 0.06, 0.04),
				CFrame.new(0.82 * side, -0.38 - i * 0.13, Z - 0.03) * CFrame.Angles(0, 0, (i - 1) * 0.15 * side),
				darken(look.skin, 0.45)
			)
		end
	end
end

ACC.glasses = function(ctx, look)
	local frame = Color3.fromRGB(30, 30, 35)
	for _, side in { -1, 1 } do
		ctx.add(
			"Head",
			"Lens",
			Vector3.new(0.66, 0.52, 0.04),
			CFrame.new(0.48 * side, -0.1, Z - 0.12),
			Color3.fromRGB(180, 220, 255),
			{ Transparency = 0.55, Material = Enum.Material.Glass }
		)
		ctx.add("Head", "Frame", Vector3.new(0.7, 0.07, 0.05), CFrame.new(0.48 * side, 0.17, Z - 0.13), frame)
	end
	ctx.add("Head", "Bridge", Vector3.new(0.3, 0.06, 0.05), CFrame.new(0, 0.12, Z - 0.13), frame)
	local _ = look
end

ACC.blindfold = function(ctx, look)
	ctx.add("Head", "Blindfold", Vector3.new(2.42, 0.62, 2.32), CFrame.new(0, -0.08, 0), Color3.fromRGB(20, 20, 25))
	local _ = look
end

ACC.tattoos = function(ctx, look)
	local ink = Color3.fromRGB(25, 20, 25)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Tattoo", Vector3.new(0.5, 0.07, 0.04), CFrame.new(0.5 * side, -0.5, Z - 0.03), ink)
		ctx.add("Head", "Tattoo", Vector3.new(0.07, 0.4, 0.04), CFrame.new(0.95 * side, -0.25, Z - 0.03), ink)
	end
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "ArmTattoo", Vector3.new(0.83, 0.08, 0.83), CFrame.new(0, 0.1, 0), ink)
		ctx.add(side, "ArmTattoo2", Vector3.new(0.83, 0.08, 0.83), CFrame.new(0, -0.15, 0), ink)
	end
	ctx.add("Head", "ForeheadTattoo", Vector3.new(0.6, 0.07, 0.04), CFrame.new(0, 0.6, Z - 0.03), ink)
	local _ = look
end

ACC.tattoos_blue = function(ctx, look)
	local ink = look.accColor or Color3.fromRGB(60, 80, 220)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Tattoo", Vector3.new(0.07, 0.9, 0.04), CFrame.new(0.85 * side, -0.2, Z - 0.03), ink)
	end
	for i = 0, 2 do
		ctx.add("Torso", "BodyTattoo", Vector3.new(2.03, 0.08, 1.13), CFrame.new(0, 0.5 - i * 0.4, 0), ink)
	end
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "ArmTattoo", Vector3.new(0.83, 0.08, 0.83), CFrame.new(0, 0.2, 0), ink)
		ctx.add(side, "ArmTattoo2", Vector3.new(0.83, 0.08, 0.83), CFrame.new(0, -0.2, 0), ink)
	end
end

ACC.extra_eyes = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.add("Head", "ExtraEye", Vector3.new(0.32, 0.18, 0.05), CFrame.new(0.68 * side, -0.55, Z - 0.03), look.eyes or Color3.fromRGB(220, 20, 30))
	end
end

ACC.dots = function(ctx, look)
	for row = 0, 1 do
		for col = -1, 1 do
			ctx.add("Head", "Dot", Vector3.new(0.12, 0.12, 0.04), CFrame.new(col * 0.3, 0.72 + row * 0.2, Z - 0.03), darken(look.skin, 0.4))
		end
	end
end

ACC.turban = function(ctx, look)
	local color = look.accColor or WHITE
	ctx.add("Head", "Turban", Vector3.new(2.5, 1.1, 2.42), CFrame.new(0, HY + 0.3, 0.02), color)
	ctx.add("Head", "TurbanBand", Vector3.new(2.54, 0.25, 2.46), CFrame.new(0, HY - 0.1, 0.02), darken(color, 0.15))
	ctx.add("Head", "TurbanGem", Vector3.new(0.4, 0.4, 0.1), CFrame.new(0, HY + 0.25, -HZ - 0.12), Color3.fromRGB(150, 60, 200), { Material = Enum.Material.Neon })
end

ACC.antennae = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Antenna", Vector3.new(0.13, 1.0, 0.13), CFrame.new(0.42 * side, HY + 0.85, -0.55) * CFrame.Angles(-0.3, 0, -0.35 * side), look.skin)
		ctx.add("Head", "AntennaTip", Vector3.new(0.24, 0.24, 0.24), CFrame.new(0.6 * side, HY + 1.35, -0.7), look.skin)
	end
end

local function ears(ctx, color, inner, size)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Ear", Vector3.new(size, size, 0.3), CFrame.new(0.78 * side, HY + 0.25, 0.1) * CFrame.Angles(0, 0, math.rad(45)), color)
		ctx.add("Head", "EarInner", Vector3.new(size * 0.55, size * 0.55, 0.32), CFrame.new(0.78 * side, HY + 0.25, 0.08) * CFrame.Angles(0, 0, math.rad(45)), inner)
	end
end

ACC.cat_ears = function(ctx, look)
	ears(ctx, look.skin, Color3.fromRGB(255, 180, 200), 0.75)
end

ACC.fox_ears = function(ctx, look)
	ears(ctx, look.accColor or Color3.fromRGB(255, 120, 20), Color3.fromRGB(40, 20, 20), 1.0)
end

ACC.bandana = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(200, 40, 40)
	ctx.add("Head", "Bandana", Vector3.new(2.48, 0.65, 2.38), CFrame.new(0, 0.9, 0), color)
	ctx.add("Head", "BandanaKnot", Vector3.new(0.45, 0.45, 0.3), CFrame.new(0.5, 0.75, HZ + 0.22), color)
	ctx.add("Head", "BandanaTail", Vector3.new(0.3, 0.7, 0.12), CFrame.new(0.65, 0.35, HZ + 0.3) * CFrame.Angles(0.2, 0, -0.25), color)
end

ACC.cap = function(ctx, look)
	local color = look.accColor or WHITE
	ctx.add("Head", "Cap", Vector3.new(2.48, 0.7, 2.38), CFrame.new(0, HY + 0.2, 0), color)
	ctx.add("Head", "CapBand", Vector3.new(2.5, 0.2, 2.4), CFrame.new(0, HY - 0.1, 0), Color3.fromRGB(40, 60, 140))
	ctx.add("Head", "Brim", Vector3.new(2.2, 0.15, 0.9), CFrame.new(0, HY - 0.15, -HZ - 0.4), Color3.fromRGB(30, 30, 40))
end

ACC.long_nose = function(ctx, look)
	ctx.add("Head", "Nose", Vector3.new(0.3, 0.3, 1.1), CFrame.new(0, -0.3, Z - 0.55), look.skin)
end

ACC.scar_eye = function(ctx, look)
	ctx.add("Head", "Scar", Vector3.new(0.08, 1.0, 0.04), CFrame.new(-0.48, -0.1, Z - 0.11), Color3.fromRGB(150, 50, 50))
	local _ = look
end

ACC.scar_cheek = function(ctx, look)
	ctx.add("Head", "Scar", Vector3.new(0.4, 0.06, 0.04), CFrame.new(-0.55, -0.48, Z - 0.03), Color3.fromRGB(150, 60, 60))
	for i = -1, 1 do
		ctx.add("Head", "Stitch", Vector3.new(0.05, 0.16, 0.04), CFrame.new(-0.55 + i * 0.12, -0.48, Z - 0.04), Color3.fromRGB(150, 60, 60))
	end
	local _ = look
end

ACC.straw_hat = function(ctx, look)
	local straw = look.accColor or Color3.fromRGB(240, 210, 110)
	local up = CFrame.Angles(0, 0, math.rad(90))
	ctx.add("Head", "Brim", Vector3.new(0.18, 3.8, 3.8), CFrame.new(0, HY + 0.1, 0) * up, straw, { Shape = Enum.PartType.Cylinder })
	ctx.add("Head", "Crown", Vector3.new(1.0, 2.5, 2.5), CFrame.new(0, HY + 0.6, 0) * up, straw, { Shape = Enum.PartType.Cylinder })
	ctx.add("Head", "Ribbon", Vector3.new(0.32, 2.56, 2.56), CFrame.new(0, HY + 0.3, 0) * up, Color3.fromRGB(210, 30, 40), { Shape = Enum.PartType.Cylinder })
end

ACC.earrings = function(ctx, look)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Earring", Vector3.new(0.08, 0.5, 0.32), CFrame.new(1.2 * side, -0.55, 0), WHITE)
		ctx.add("Head", "EarringSun", Vector3.new(0.1, 0.2, 0.2), CFrame.new(1.2 * side, -0.5, 0), Color3.fromRGB(220, 40, 40))
	end
	local _ = look
end

ACC.scar_forehead = function(ctx, look)
	ctx.add("Head", "Scar", Vector3.new(0.5, 0.32, 0.04), CFrame.new(-0.45, 0.6, Z - 0.03), Color3.fromRGB(170, 60, 50))
	local _ = look
end

ACC.forehead_mark = function(ctx, look)
	local red = Color3.fromRGB(200, 30, 30)
	ctx.add("Head", "Mark", Vector3.new(0.55, 0.3, 0.04), CFrame.new(-0.45, 0.6, Z - 0.03), red)
	ctx.add("Head", "Mark2", Vector3.new(0.25, 0.35, 0.04), CFrame.new(-0.6, 0.85, Z - 0.03) * CFrame.Angles(0, 0, 0.4), red)
	local _ = look
end

ACC.muzzle = function(ctx, look)
	local bamboo = Color3.fromRGB(120, 170, 70)
	ctx.add("Head", "Bamboo", Vector3.new(1.9, 0.3, 0.3), CFrame.new(0, -0.6, Z - 0.12), bamboo)
	ctx.add("Head", "Knot", Vector3.new(0.1, 0.34, 0.34), CFrame.new(-0.4, -0.6, Z - 0.12), darken(bamboo, 0.3))
	ctx.add("Head", "Knot", Vector3.new(0.1, 0.34, 0.34), CFrame.new(0.4, -0.6, Z - 0.12), darken(bamboo, 0.3))
	ctx.add("Head", "String", Vector3.new(2.38, 0.08, 2.28), CFrame.new(0, -0.6, 0), Color3.fromRGB(200, 60, 60))
	local _ = look
end

ACC.facepaint = function(ctx, look)
	local paint = look.accColor or Color3.fromRGB(140, 50, 180)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Paint", Vector3.new(0.12, 0.65, 0.04), CFrame.new(0.5 * side, -0.55, Z - 0.03), paint)
		ctx.add("Head", "Paint", Vector3.new(0.4, 0.1, 0.04), CFrame.new(0.5 * side, 0.4, Z - 0.03), paint)
	end
end

ACC.cyclops = function() end -- géré dans buildFace

ACC.horns = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(235, 225, 205)
	for _, side in { -1, 1 } do
		ctx.add("Head", "Horn", Vector3.new(0.4, 0.8, 0.4), CFrame.new(0.72 * side, HY + 0.35, -0.3) * CFrame.Angles(0, 0, -0.35 * side), color)
		ctx.add("Head", "HornTip", Vector3.new(0.25, 0.5, 0.25), CFrame.new(0.92 * side, HY + 0.85, -0.3) * CFrame.Angles(0, 0, -0.6 * side), color)
	end
end

ACC.volcano = function(ctx, look)
	local rock = look.accColor or Color3.fromRGB(80, 60, 50)
	ctx.add("Head", "Volcano1", Vector3.new(2.3, 0.7, 2.2), CFrame.new(0, HY + 0.3, 0), rock)
	ctx.add("Head", "Volcano2", Vector3.new(1.6, 0.6, 1.5), CFrame.new(0, HY + 0.9, 0), rock)
	ctx.add("Head", "Lava", Vector3.new(0.9, 0.12, 0.9), CFrame.new(0, HY + 1.2, 0), Color3.fromRGB(255, 120, 20), { Material = Enum.Material.Neon })
end

ACC.stitches = function(ctx, look)
	local thread = Color3.fromRGB(60, 50, 60)
	ctx.add("Head", "Stitch", Vector3.new(1.4, 0.06, 0.04), CFrame.new(0.1, 0.2, Z - 0.1) * CFrame.Angles(0, 0, -0.5), thread)
	for i = -2, 2 do
		ctx.add("Head", "StitchCross", Vector3.new(0.05, 0.22, 0.04), CFrame.new(0.1 + i * 0.25, 0.2 - i * 0.135, Z - 0.11) * CFrame.Angles(0, 0, -0.5), thread)
	end
	ctx.add("Torso", "BodyStitch", Vector3.new(2.03, 0.06, 1.13), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, 0.3), thread)
	local _ = look
end

ACC.scouter = function(ctx, look)
	ctx.add(
		"Head",
		"ScouterLens",
		Vector3.new(0.65, 0.48, 0.05),
		CFrame.new(0.5, -0.05, Z - 0.14),
		Color3.fromRGB(80, 255, 120),
		{ Material = Enum.Material.Neon, Transparency = 0.35 }
	)
	ctx.add("Head", "ScouterBody", Vector3.new(0.25, 0.6, 0.6), CFrame.new(1.25, 0, -0.35), Color3.fromRGB(240, 240, 240))
	ctx.add("Head", "ScouterArm", Vector3.new(0.1, 0.1, 0.7), CFrame.new(1.1, 0.2, Z + 0.05), Color3.fromRGB(240, 240, 240))
	local _ = look
end

ACC.dome = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(150, 60, 200)
	ctx.add("Head", "Dome", Vector3.new(2.0, 0.85, 1.9), CFrame.new(0, HY + 0.3, 0.05), color, { Reflectance = 0.25 })
	ctx.add("Head", "DomeTop", Vector3.new(1.2, 0.35, 1.1), CFrame.new(0, HY + 0.85, 0.05), color, { Reflectance = 0.25 })
end

ACC.hood = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(200, 30, 40)
	ctx.add("Torso", "Hood", Vector3.new(2.1, 0.75, 0.5), CFrame.new(0, 0.85, 0.78), color)
	ctx.add("Torso", "HoodCollar", Vector3.new(2.06, 0.3, 1.16), CFrame.new(0, 0.75, 0), color)
end

ACC.hood_full = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(25, 25, 30)
	ctx.add("Head", "HoodTop", Vector3.new(2.6, 0.35, 2.55), CFrame.new(0, HY + 0.15, 0.05), color)
	ctx.add("Head", "HoodBack", Vector3.new(2.6, 2.45, 0.35), CFrame.new(0, -0.05, HZ + 0.15), color)
	for _, side in { -1, 1 } do
		ctx.add("Head", "HoodSide", Vector3.new(0.3, 2.45, 2.5), CFrame.new((HX + 0.15) * side, -0.05, 0.05), color)
	end
	ctx.add("Head", "HoodBrow", Vector3.new(2.6, 0.35, 0.3), CFrame.new(0, HY - 0.15, -HZ - 0.05), color)
end

ACC.boar_head = function(ctx, look)
	local fur = look.accColor or Color3.fromRGB(110, 110, 120)
	ctx.add("Head", "BoarHead", Vector3.new(2.6, 2.5, 2.6), CFrame.new(0, 0.1, 0), fur)
	ctx.add("Head", "Snout", Vector3.new(1.2, 0.85, 0.7), CFrame.new(0, -0.45, -1.6), lighten(fur, 0.35))
	ctx.add("Head", "Nostril", Vector3.new(0.2, 0.3, 0.05), CFrame.new(-0.25, -0.45, -1.97), BLACK)
	ctx.add("Head", "Nostril", Vector3.new(0.2, 0.3, 0.05), CFrame.new(0.25, -0.45, -1.97), BLACK)
	for _, side in { -1, 1 } do
		ctx.add("Head", "BoarEye", Vector3.new(0.35, 0.35, 0.05), CFrame.new(0.6 * side, 0.3, -1.32), Color3.fromRGB(150, 190, 220))
		ctx.add("Head", "BoarEar", Vector3.new(0.6, 0.6, 0.3), CFrame.new(0.95 * side, 1.45, 0) * CFrame.Angles(0, 0, math.rad(45)), fur)
		ctx.add("Head", "Tusk", Vector3.new(0.15, 0.4, 0.15), CFrame.new(0.55 * side, -0.75, -1.8), WHITE)
	end
	ctx.add("Head", "Mane", Vector3.new(0.8, 0.6, 2.4), CFrame.new(0, 1.5, 0.2), darken(fur, 0.3))
end

-- Accessoires du corps -------------------------------------------------

ACC.vest = function(ctx, look)
	local color = look.topAccent or look.accColor or Color3.fromRGB(90, 110, 60)
	ctx.add("Torso", "Vest", Vector3.new(2.1, 1.55, 1.2), CFrame.new(0, -0.05, 0), color)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "Pocket", Vector3.new(0.5, 0.4, 0.08), CFrame.new(0.55 * side, -0.25, -0.62), darken(color, 0.15))
	end
	ctx.add("Torso", "VestCollar", Vector3.new(2.14, 0.3, 1.24), CFrame.new(0, 0.75, 0), darken(color, 0.1))
end

ACC.collar = function(ctx, look)
	local color = look.accColor or look.top or WHITE
	ctx.add("Torso", "Collar", Vector3.new(2.12, 0.55, 1.22), CFrame.new(0, 0.95, 0), color)
	ctx.add("Torso", "CollarButton", Vector3.new(0.25, 0.25, 0.06), CFrame.new(0, 0.5, -0.58), Color3.fromRGB(230, 200, 80))
end

ACC.collar_gold = function(ctx, look)
	local gold = look.accColor or Color3.fromRGB(255, 200, 60)
	ctx.add("Torso", "GoldCollar", Vector3.new(2.25, 0.4, 1.3), CFrame.new(0, 0.8, 0), gold, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	ctx.add("Torso", "Gem", Vector3.new(0.35, 0.35, 0.08), CFrame.new(0, 0.7, -0.68), Color3.fromRGB(80, 200, 255), { Material = Enum.Material.Neon })
end

ACC.collar_sailor = function(ctx, look)
	local color = look.topAccent or Color3.fromRGB(40, 90, 200)
	ctx.add("Torso", "SailorCollar", Vector3.new(2.0, 0.85, 0.1), CFrame.new(0, 0.4, 0.6), color)
	ctx.add("Torso", "SailorTie", Vector3.new(0.4, 0.4, 0.08), CFrame.new(0, 0.45, -0.6) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(220, 40, 40))
end

ACC.tie = function(ctx, look)
	ctx.add("Torso", "Shirt", Vector3.new(0.7, 1.2, 0.05), CFrame.new(0, 0.2, -0.56), look.topAccent or WHITE)
	ctx.add("Torso", "Tie", Vector3.new(0.25, 1.0, 0.05), CFrame.new(0, 0.15, -0.58), look.accColor or Color3.fromRGB(30, 30, 40))
	ctx.add("Torso", "TieKnot", Vector3.new(0.3, 0.2, 0.06), CFrame.new(0, 0.7, -0.59), look.accColor or Color3.fromRGB(30, 30, 40))
end

ACC.belt = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(30, 30, 30)
	ctx.add("Torso", "Sash", Vector3.new(2.08, 0.32, 1.18), CFrame.new(0, -0.68, 0), color)
	ctx.add("Torso", "SashKnot", Vector3.new(0.4, 0.35, 0.12), CFrame.new(0.35, -0.68, -0.62), color)
	ctx.add("Torso", "SashTail", Vector3.new(0.18, 0.6, 0.08), CFrame.new(0.45, -1.05, -0.63) * CFrame.Angles(0, 0, 0.15), color)
end

ACC.armor = function(ctx, look)
	local plate = look.accColor or Color3.fromRGB(245, 245, 235)
	local trim = Color3.fromRGB(230, 185, 80)
	ctx.add("Torso", "ChestPlate", Vector3.new(2.16, 1.25, 1.26), CFrame.new(0, 0.2, 0), plate)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "ShoulderPad", Vector3.new(0.95, 0.35, 1.1), CFrame.new(1.4 * side, 0.92, 0) * CFrame.Angles(0, 0, -0.25 * side), trim)
	end
end

ACC.stripes = function(ctx, look)
	local color = look.topAccent or Color3.fromRGB(40, 80, 180)
	for i = 0, 2 do
		ctx.add("Torso", "Stripe", Vector3.new(2.04, 0.18, 1.14), CFrame.new(0, 0.4 - i * 0.42, 0), color)
	end
end

ACC.vest_open = function(ctx, look)
	local color = look.top or Color3.fromRGB(210, 30, 40)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "VestPanel", Vector3.new(0.7, 1.7, 0.1), CFrame.new(0.66 * side, 0, -0.58), color)
		ctx.add("Torso", "VestSide", Vector3.new(0.1, 1.7, 1.14), CFrame.new(1.03 * side, 0, 0), color)
	end
	ctx.add("Torso", "VestBack", Vector3.new(2.06, 1.7, 0.1), CFrame.new(0, 0, 0.58), color)
	ctx.add("Torso", "Sash", Vector3.new(2.06, 0.25, 1.16), CFrame.new(0, -0.75, 0), Color3.fromRGB(240, 200, 80))
end

ACC.cape = function(ctx, look)
	local color = look.capeColor or look.accColor or Color3.fromRGB(200, 40, 40)
	ctx.add("Torso", "Cape", Vector3.new(2.2, 3.1, 0.15), CFrame.new(0, -0.55, 0.7) * CFrame.Angles(0.12, 0, 0), color)
	ctx.add("Torso", "CapeLining", Vector3.new(2.1, 3.0, 0.05), CFrame.new(0, -0.55, 0.62) * CFrame.Angles(0.12, 0, 0), darken(color, 0.3))
	for _, side in { -1, 1 } do
		ctx.add("Torso", "CapeClasp", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.8 * side, 0.75, 0.55), Color3.fromRGB(230, 190, 70))
	end
end

ACC.cloak_clouds = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(25, 25, 30)
	ctx.add("Torso", "Cloak", Vector3.new(2.14, 1.76, 1.22), CFrame.new(0, 0, 0), color)
	ctx.add("Torso", "CloakSkirt", Vector3.new(2.18, 1.1, 1.26), CFrame.new(0, -1.35, 0), color)
	ctx.add("Torso", "CloakCollar", Vector3.new(2.2, 0.7, 1.3), CFrame.new(0, 1.0, 0), color)
	local cloud = Color3.fromRGB(210, 20, 30)
	local clouds = { { -0.5, 0.2, -0.63 }, { 0.55, -0.4, -0.63 }, { 0, -1.3, -0.65 }, { 0.3, 0.3, 0.63 }, { -0.4, -1.2, 0.65 } }
	for _, p in clouds do
		ctx.add("Torso", "CloudOutline", Vector3.new(0.7, 0.42, 0.04), CFrame.new(p[1], p[2], p[3]), WHITE)
		ctx.add("Torso", "Cloud", Vector3.new(0.6, 0.32, 0.05), CFrame.new(p[1], p[2], p[3] + (p[3] < 0 and -0.01 or 0.01)), cloud)
	end
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "Sleeve", Vector3.new(0.92, 1.3, 0.92), CFrame.new(0, 0.15, 0), color)
	end
end

ACC.kimono = function(ctx, look)
	local color = look.accColor or look.top or WHITE
	ctx.add("Torso", "Kimono", Vector3.new(2.1, 1.75, 1.2), CFrame.new(0, 0, 0), color)
	ctx.add("Torso", "KimonoV", Vector3.new(0.5, 0.9, 0.05), CFrame.new(0, 0.45, -0.61) * CFrame.Angles(0, 0, math.rad(45)), look.topAccent or darken(color, 0.4))
	ctx.add("Torso", "KimonoSkirt", Vector3.new(2.16, 0.9, 1.24), CFrame.new(0, -1.25, 0), color)
	ctx.add("Torso", "Obi", Vector3.new(2.14, 0.35, 1.24), CFrame.new(0, -0.65, 0), look.topAccent or darken(color, 0.4))
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "WideSleeve", Vector3.new(1.0, 1.25, 1.0), CFrame.new(0, 0.1, 0), color)
	end
end

local function haoriBase(ctx, look, color, pattern)
	-- pattern(ctx, panelName, size, cf) permet de décorer chaque panneau.
	local back = { Vector3.new(2.15, 2.6, 0.12), CFrame.new(0, -0.45, 0.62) }
	ctx.add("Torso", "HaoriBack", back[1], back[2], color)
	for _, side in { -1, 1 } do
		ctx.add("Torso", "HaoriFront", Vector3.new(0.6, 2.6, 0.1), CFrame.new(0.78 * side, -0.45, -0.62), color)
		ctx.add("Torso", "HaoriSide", Vector3.new(0.1, 2.6, 1.2), CFrame.new(1.08 * side, -0.45, 0), color)
	end
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "HaoriSleeve", Vector3.new(0.95, 1.3, 0.95), CFrame.new(0, 0.12, 0), color)
	end
	if pattern then
		pattern(ctx, look)
	end
end

ACC.haori = function(ctx, look)
	local color = look.accColor or Color3.fromRGB(255, 210, 40)
	haoriBase(ctx, look, color, function(c2)
		-- Motif de triangles blancs.
		for i = -1, 1 do
			c2.add("Torso", "HaoriTri", Vector3.new(0.4, 0.4, 0.04), CFrame.new(i * 0.6, -1.5, 0.69) * CFrame.Angles(0, 0, math.rad(45)), WHITE)
		end
		for _, side in { -1, 1 } do
			c2.add("Torso", "HaoriTri", Vector3.new(0.35, 0.35, 0.04), CFrame.new(0.78 * side, -1.5, -0.68) * CFrame.Angles(0, 0, math.rad(45)), WHITE)
		end
	end)
end

ACC.haori_checker = function(ctx, look)
	local green = look.accColor or Color3.fromRGB(40, 130, 90)
	haoriBase(ctx, look, BLACK, function(c2)
		-- Damier vert/noir.
		for row = 0, 4 do
			for col = 0, 3 do
				if (row + col) % 2 == 0 then
					local x = -0.81 + col * 0.54
					local y = 0.6 - row * 0.52
					c2.add("Torso", "Check", Vector3.new(0.54, 0.52, 0.04), CFrame.new(x, y, 0.69), green)
				end
			end
			for _, side in { -1, 1 } do
				if row % 2 == 0 then
					c2.add("Torso", "Check", Vector3.new(0.3, 0.52, 0.04), CFrame.new(0.78 * side + 0.15 * side, 0.6 - row * 0.52, -0.68), green)
				else
					c2.add("Torso", "Check", Vector3.new(0.3, 0.52, 0.04), CFrame.new(0.78 * side - 0.15 * side, 0.6 - row * 0.52, -0.68), green)
				end
			end
		end
		for _, side in { "LeftArm", "RightArm" } do
			c2.add(side, "SleeveCheck", Vector3.new(0.97, 0.45, 0.48), CFrame.new(0, 0.4, -0.24), green)
			c2.add(side, "SleeveCheck", Vector3.new(0.97, 0.45, 0.48), CFrame.new(0, -0.05, 0.24), green)
		end
	end)
end

ACC.haori_flame = function(ctx, look)
	local white = look.accColor or WHITE
	haoriBase(ctx, look, white, function(c2)
		local flames = { Color3.fromRGB(230, 40, 20), Color3.fromRGB(255, 150, 30) }
		for i = 0, 7 do
			local x = -0.95 + i * 0.27
			local h = (i % 2 == 0) and 0.7 or 0.45
			c2.add("Torso", "Flame", Vector3.new(0.27, h, 0.05), CFrame.new(x, -1.75 + h / 2, 0.69), flames[(i % 2) + 1])
		end
		for _, side in { -1, 1 } do
			c2.add("Torso", "Flame", Vector3.new(0.6, 0.55, 0.05), CFrame.new(0.78 * side, -1.5, -0.68), flames[1])
		end
		for _, side in { "LeftArm", "RightArm" } do
			c2.add(side, "SleeveFlame", Vector3.new(0.97, 0.3, 0.97), CFrame.new(0, -0.4, 0), flames[1])
		end
	end)
end

ACC.sword_back = function(ctx, look)
	local handle = look.accColor or Color3.fromRGB(80, 60, 130)
	local tilt = CFrame.Angles(0, 0, 0.75)
	ctx.add("Torso", "Sheath", Vector3.new(0.28, 3.0, 0.28), CFrame.new(0, -0.1, 0.75) * tilt, Color3.fromRGB(30, 30, 35))
	ctx.add("Torso", "Guard", Vector3.new(0.6, 0.12, 0.6), CFrame.new(0, -0.1, 0.75) * tilt * CFrame.new(0, 1.55, 0), Color3.fromRGB(200, 170, 80))
	ctx.add("Torso", "Handle", Vector3.new(0.24, 0.9, 0.24), CFrame.new(0, -0.1, 0.75) * tilt * CFrame.new(0, 2.05, 0), handle)
end

local function hipSword(ctx, side: number, z: number, handle: Color3)
	local cf = CFrame.new(1.15 * side, -0.65, z) * CFrame.Angles(math.rad(-75), 0, 0)
	ctx.add("Torso", "Sheath", Vector3.new(0.22, 2.6, 0.22), cf, Color3.fromRGB(30, 30, 35))
	ctx.add("Torso", "Guard", Vector3.new(0.5, 0.1, 0.5), cf * CFrame.new(0, 1.35, 0), Color3.fromRGB(200, 170, 80))
	ctx.add("Torso", "Handle", Vector3.new(0.2, 0.75, 0.2), cf * CFrame.new(0, 1.78, 0), handle)
end

ACC.sword_hip = function(ctx, look)
	hipSword(ctx, -1, 0, look.accColor or Color3.fromRGB(240, 240, 240))
end

ACC.swords = function(ctx, look)
	local handle = look.accColor or Color3.fromRGB(240, 240, 240)
	hipSword(ctx, -1, -0.15, handle)
	hipSword(ctx, -1, 0.2, Color3.fromRGB(200, 40, 40))
	hipSword(ctx, 1, 0, Color3.fromRGB(30, 30, 30))
end

ACC.hammer = function(ctx, look)
	local cf = CFrame.new(0, -0.75, -0.6) * CFrame.Angles(math.rad(90), 0, 0)
	ctx.add("RightArm", "HammerHandle", Vector3.new(0.18, 1.8, 0.18), cf, look.accColor or Color3.fromRGB(110, 80, 60))
	ctx.add("RightArm", "HammerHead", Vector3.new(0.9, 0.5, 0.5), cf * CFrame.new(0, 0.9, 0), METAL, { Material = Enum.Material.Metal })
end

ACC.spear = function(ctx, look)
	local cf = CFrame.new(0, -0.7, -0.45)
	ctx.add("RightArm", "SpearShaft", Vector3.new(0.18, 5.0, 0.18), cf, look.accColor or Color3.fromRGB(120, 100, 70))
	ctx.add("RightArm", "SpearTip", Vector3.new(0.35, 0.8, 0.12), cf * CFrame.new(0, 2.8, 0), METAL, { Material = Enum.Material.Metal })
end

ACC.tail = function(ctx, look)
	local color = look.tailColor or Color3.fromRGB(120, 80, 50)
	if look.hair == "none" then
		color = look.skin
	end
	ctx.add("Torso", "Tail", Vector3.new(0.35, 0.35, 1.6), CFrame.new(0, -0.7, 1.2) * CFrame.Angles(0.6, 0, 0), color)
	ctx.add("Torso", "TailTip", Vector3.new(0.4, 0.4, 0.8), CFrame.new(0, -0.15, 1.9) * CFrame.Angles(1.1, 0, 0), color)
end

ACC.tails9 = function(ctx, look)
	local fur = look.accColor or Color3.fromRGB(255, 120, 20)
	for i = 0, 8 do
		local angle = -1.25 + i * (2.5 / 8)
		local cf = CFrame.new(0, -0.6, 0.6) * CFrame.Angles(0, 0, angle) * CFrame.Angles(-0.5, 0, 0) * CFrame.new(0, 1.4, 0.8)
		ctx.add("Torso", "FoxTail", Vector3.new(0.6, 2.8, 0.6), cf, fur)
		ctx.add("Torso", "FoxTailTip", Vector3.new(0.62, 0.6, 0.62), cf * CFrame.new(0, 1.3, 0), lighten(fur, 0.6))
	end
end

ACC.fins = function(ctx, look)
	local fin = look.accColor or Color3.fromRGB(60, 120, 180)
	ctx.add("Torso", "DorsalFin", Vector3.new(0.15, 1.2, 0.9), CFrame.new(0, 0.4, 0.95) * CFrame.Angles(-0.4, 0, 0), fin)
	for _, side in { "LeftArm", "RightArm" } do
		ctx.add(side, "ArmFin", Vector3.new(0.12, 0.8, 0.6), CFrame.new(0, 0.1, 0.55) * CFrame.Angles(-0.3, 0, 0), fin)
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
}

function CharacterBuilder.build(look, options: BuildOptions?): Model
	local opts = options or {}
	local s = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = opts.name or "Character"

	local ctx = newContext(model, s)
	buildBody(ctx, look, opts)
	buildFace(ctx, look)

	local hairStyle = look.hair or "short"
	if
		not has(look, "boar_head")
		and not has(look, "hood_full")
		and not has(look, "straw_hat")
		and not has(look, "volcano")
		and not has(look, "dome")
		and not has(look, "turban")
		and not has(look, "cap")
	then
		local builder = HAIR[hairStyle] or HAIR.short
		builder(ctx, look.hairColor or BLACK, look)
	elseif has(look, "straw_hat") or has(look, "cap") then
		-- Cheveux visibles sous le chapeau.
		hairBack(ctx, look.hairColor or BLACK, 1.3)
		hairSides(ctx, look.hairColor or BLACK, 0.9)
		hairFringe(ctx, look.hairColor or BLACK)
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
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.HipHeight = CharacterBuilder.HipHeight * s
		humanoid.WalkSpeed = opts.walkSpeed or 16
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.AutoJumpEnabled = true
		humanoid.MaxHealth = 1e9
		humanoid.Health = 1e9
		humanoid.Parent = model
	end

	model:SetAttribute("BaseScale", s)
	return model
end

-- Construit un modèle simple (sans Humanoid, ancré) pour les aperçus UI.
function CharacterBuilder.buildPreview(look): Model
	local model = CharacterBuilder.build(look, { scale = 1, name = "Preview" })
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

return CharacterBuilder
