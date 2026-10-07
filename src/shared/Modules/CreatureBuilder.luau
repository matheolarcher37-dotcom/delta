-- Construit les CRÉATURES (pas des persos R6) : pour l'instant Kourama, le renard à neuf queues,
-- boss du Village Ninja (Config/Characters.luau : look.creature = "kurama").
--
--   * silhouette de renard géant accroupi : tête au museau allongé, gueule ouverte aux crocs,
--     yeux rouges lumineux fendus, marques noires, longues oreilles noires à l'intérieur, cou épais,
--     torse massif, pattes avant écartées et pattes arrière repliées, griffes blanches ;
--   * NEUF grandes queues épaisses en éventail, faites de segments reliés par des Motor6D :
--     Controllers/CreatureAnimator les fait onduler (et marcher à quatre pattes, rugir...) ;
--   * compatible avec le jeu : HumanoidRootPart (invisible, collisions) + Humanoid (déplacements,
--     PV, ciblage), attributs BaseScale / RootHeight / Creature.
--
-- Le modèle est construit pattes au sol en (0, 0, 0), museau vers -Z (comme les persos), puis déplacé
-- via PivotTo. À l'échelle 1 il a à peu près la hauteur d'un perso R6 (sans les queues) ; le boss est
-- construit à l'échelle 4.2 (Economy.Boss.scale).

local CreatureBuilder = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Couleurs relevées à la pipette sur l'image de référence de Kurama.
local FOX = {
	main = rgb(206, 114, 36), -- orange du pelage
	shade = rgb(172, 80, 24), -- ombres orange brûlé
	deep = rgb(128, 52, 14), -- ombres profondes (creux, dessous des queues)
	light = rgb(234, 158, 66), -- reflets / dessous
	cream = rgb(242, 194, 120), -- ventre, joues, museau
	black = rgb(30, 20, 18), -- intérieur des oreilles, marques, truffe
	claw = rgb(242, 238, 230), -- griffes et crocs
	eye = rgb(255, 40, 20), -- yeux rouges lumineux
	mouth = rgb(110, 22, 20), -- intérieur de la gueule
}
CreatureBuilder.Palette = FOX

-- Dimensions à l'échelle 1 (multipliées par l'échelle du modèle).
local ROOT_SIZE = Vector3.new(2.4, 2, 3.6)
local ROOT_CENTER = Vector3.new(0, 2.2, -0.3)
CreatureBuilder.RootHeight = ROOT_CENTER.Y -- hauteur du centre du HumanoidRootPart au-dessus du sol
CreatureBuilder.HipHeight = ROOT_CENTER.Y - ROOT_SIZE.Y / 2 -- Humanoid R15 : sol -> bas du HumanoidRootPart
CreatureBuilder.Height = 4.4 -- haut des oreilles (sans les queues)
CreatureBuilder.TailCount = 9
CreatureBuilder.TailSegments = 6
CreatureBuilder.Kinds = { kurama = true }
CreatureBuilder.Reach = 4.0 -- centre du HumanoidRootPart -> museau / griffes de la patte avancée (échelle 1)
-- Os qui reçoivent les clics (en plus des segments 1 à 4 de chaque queue).
local QUERY_BONES =
	{ Torso = true, Hips = true, Head = true, LeftUpperArm = true, RightUpperArm = true, LeftForearm = true, RightForearm = true, LeftThigh = true, RightThigh = true }

local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * cf.Rotation
end

-- Repère dont l'axe Y suit `up` et dont l'avant (-Z) regarde au mieux vers `front`.
local function frameY(position: Vector3, up: Vector3, front: Vector3?): CFrame
	local y = up.Unit
	local f = front or Vector3.new(0, 0, -1)
	local back = -(f - y * f:Dot(y))
	if back.Magnitude < 1e-3 then
		back = math.abs(y.Y) < 0.95 and Vector3.new(0, 1, 0):Cross(y) or Vector3.new(1, 0, 0)
	end
	back = back.Unit
	local right = y:Cross(back).Unit
	return CFrame.fromMatrix(position, right, y, right:Cross(y).Unit)
end

-- Repère dont l'avant (-Z, la face "Front") regarde vers `look`.
local function facing(position: Vector3, look: Vector3, upHint: Vector3?): CFrame
	local back = -look.Unit
	local up = upHint or Vector3.new(0, 1, 0)
	local right = up:Cross(back)
	if right.Magnitude < 1e-3 then
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	return CFrame.fromMatrix(position, right, back:Cross(right).Unit, back)
end

------------------------------------------------------------------------
-- Contexte de construction
------------------------------------------------------------------------

local function newContext(model: Model, s: number)
	local ctx = { model = model, s = s, bones = {}, count = 0, motors = 0 }

	local function finish(part: BasePart, boneName: string?)
		part.Material = part.Material == Enum.Material.Plastic and Enum.Material.SmoothPlastic or part.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.Parent = model
		local bone = boneName and ctx.bones[boneName]
		if bone then
			local weld = Instance.new("Weld")
			weld.Name = "Weld"
			weld.Part0 = bone
			weld.Part1 = part
			weld.C0 = bone.CFrame:Inverse() * part.CFrame
			weld.Parent = part
		end
		ctx.count += 1
	end

	-- Pièce soudée à un os (`cf` en coordonnées du modèle, échelle 1).
	function ctx.add(boneName: string?, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(cf, s)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		if props then
			local target: any = part
			for key, value in props do
				target[key] = value
			end
		end
		finish(part, boneName)
		return part
	end

	-- Ellipsoïde (SpecialMesh "Sphere" étiré à la taille de la pièce).
	function ctx.ball(boneName: string?, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
		local part = ctx.add(boneName, name, size, cf, color, props)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end

	-- Ellipsoïde allongé entre deux points (épaisseur `width` x `depth`).
	function ctx.limb(boneName: string?, name: string, from: Vector3, to: Vector3, width: number, depth: number, color: Color3, extra: number?, front: Vector3?): Part
		local delta = to - from
		local length = delta.Magnitude + (extra or 0)
		return ctx.ball(boneName, name, Vector3.new(width, length, depth), frameY((from + to) / 2, delta, front), color)
	end

	function ctx.wedge(boneName: string?, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
		local part = Instance.new("WedgePart")
		part.Name = name
		part.Size = size * s
		part.CFrame = scaled(cf, s)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		finish(part, boneName)
		return part
	end

	-- Lame triangulaire (deux WedgeParts dos à dos) dans le plan (droite, haut) de `frame` :
	-- base de largeur `width` en (0,0,0), pointe à `length` le long de l'axe Y.
	local HALF_A = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
	local HALF_B = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
	function ctx.blade(boneName: string?, name: string, color: Color3, frame: CFrame, length: number, width: number, thickness: number)
		for i, half in { HALF_A, HALF_B } do
			local side = i == 1 and 1 or -1
			ctx.wedge(boneName, name, Vector3.new(thickness, length, width / 2), frame * CFrame.new(side * width / 4, length / 2, 0) * half, color)
		end
	end

	-- Pointe asymétrique en UNE seule WedgePart, dans le plan (X, Y) de `frame` : base de largeur `width`
	-- en (0,0,0), de x = -width/2 à +width/2, pointe en (+width/2, length) ; `mirror` la retourne
	-- (pointe en x = -width/2). Sert aux pointes de queue en flamme, aux touffes de poils, aux crocs.
	local FIN_A = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0))
	local FIN_B = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, -1, 0))
	function ctx.fin(boneName: string?, name: string, color: Color3, frame: CFrame, length: number, width: number, thickness: number, mirror: boolean?)
		return ctx.wedge(boneName, name, Vector3.new(thickness, width, length), frame * CFrame.new(0, length / 2, 0) * (mirror and FIN_B or FIN_A), color)
	end

	-- Griffe / croc crochu en une WedgePart : dos droit contre le doigt, pointe vers `dir`,
	-- tranchant tourné vers `down`.
	function ctx.hook(boneName: string?, name: string, color: Color3, from: Vector3, dir: Vector3, down: Vector3, length: number, height: number, thickness: number)
		local look = dir.Unit
		local up = -(down - look * down:Dot(look)).Unit
		return ctx.wedge(boneName, name, Vector3.new(thickness, height, length), facing(from + look * (length / 2) + up * (height / 2), look, up), color)
	end

	-- Os : pièce visible reliée à son parent par un Motor6D (articulation en `joint`).
	function ctx.bone(name: string, parentName: string, jointName: string, part: BasePart, joint: CFrame): BasePart
		local parent = ctx.bones[parentName]
		local weld = part:FindFirstChild("Weld")
		if weld then
			weld:Destroy()
		end
		local motor = Instance.new("Motor6D")
		motor.Name = jointName
		motor.Part0 = parent
		motor.Part1 = part
		local j = scaled(joint, s)
		motor.C0 = parent.CFrame:Inverse() * j
		motor.C1 = part.CFrame:Inverse() * j
		motor:SetAttribute("BaseC0", motor.C0)
		motor.Parent = part
		ctx.bones[name] = part
		ctx.motors += 1
		return part
	end

	return ctx
end

------------------------------------------------------------------------
-- Kourama (Kurama), le renard à neuf queues
------------------------------------------------------------------------

-- Aléa déterministe (même renard à chaque construction) : 0..1.
local function noise(i: number, salt: number): number
	local x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function buildHead(ctx)
	local C = FOX
	-- Cou épais et bas (tête portée en avant, menaçante), soudé au torse.
	ctx.ball("Torso", "Neck", Vector3.new(1.4, 1.75, 1.5), CFrame.new(0, 2.75, -1.85) * CFrame.Angles(0.75, 0, 0), C.main)
	ctx.ball("Torso", "NeckFur", Vector3.new(1.15, 1.0, 1.0), CFrame.new(0, 2.3, -2.2) * CFrame.Angles(0.4, 0, 0), C.light)
	-- Creux sombre sous le cou.
	ctx.ball("Torso", "NeckShade", Vector3.new(0.95, 0.6, 1.1), CFrame.new(0, 2.05, -2.0) * CFrame.Angles(0.3, 0, 0), C.shade)
	for _, sx in { -1, 1 } do
		-- Collerette de poils en pointes derrière les joues.
		for i, e in { { 0.55, 3.0, -1.75, 0.55, 0.75, 0.7 }, { 0.75, 2.6, -1.7, 0.95, 0.15, 0.6 }, { 0.65, 2.2, -1.9, 0.85, -0.45, 0.45 } } do
			local from = Vector3.new(sx * e[1], e[2], e[3])
			ctx.fin("Torso", "NeckTuft", i == 2 and C.main or C.shade, frameY(from, Vector3.new(sx * e[4], e[5], e[6]), Vector3.new(sx * 0.6, 0, -0.6)), 0.85, 0.5, 0.2, sx < 0)
		end
	end

	-- Tête : basse et en avant, légèrement penchée vers le bas.
	local HF = CFrame.new(0, 2.7, -2.8) * CFrame.Angles(-0.1, 0, 0)
	local function at(x: number, y: number, z: number): CFrame
		return HF * CFrame.new(x, y, z)
	end
	local head = ctx.ball(nil, "Head", Vector3.new(1.5, 1.1, 1.3), HF, C.main)
	ctx.bone("Head", "Torso", "Neck", head, CFrame.new(0, 2.75, -2.05))

	for _, sx in { -1, 1 } do
		-- Arcades sourcilières très inclinées (regard dur).
		ctx.ball("Head", "Brow", Vector3.new(0.52, 0.2, 0.5), at(sx * 0.33, 0.28, -0.38) * CFrame.Angles(0, 0, sx * -0.6), C.main)
		-- Joues larges tirées vers l'arrière (tête triangulaire) + pointes de poils.
		ctx.ball("Head", "Cheek", Vector3.new(0.7, 0.62, 1.05), at(sx * 0.58, -0.2, 0.08) * CFrame.Angles(0, sx * 0.25, 0), C.light)
		local face = HF:VectorToWorldSpace(Vector3.new(sx * 0.3, 0, -1))
		ctx.fin(
			"Head",
			"CheekTuft",
			C.light,
			frameY(HF * Vector3.new(sx * 0.7, -0.2, 0.3), HF:VectorToWorldSpace(Vector3.new(sx * 0.9, -0.25, 0.6)), face),
			0.7,
			0.42,
			0.14,
			sx > 0
		)
		ctx.fin(
			"Head",
			"CheekTuft",
			C.cream,
			frameY(HF * Vector3.new(sx * 0.6, -0.42, 0.15), HF:VectorToWorldSpace(Vector3.new(sx * 0.7, -0.75, 0.45)), face),
			0.55,
			0.34,
			0.12,
			sx > 0
		)
	end

	-- Museau long et fin : arête, lèvre supérieure, babine noire retroussée, truffe.
	ctx.ball("Head", "Muzzle", Vector3.new(0.65, 0.5, 1.5), at(0, -0.12, -0.98), C.main)
	ctx.ball("Head", "UpperLip", Vector3.new(0.6, 0.24, 1.25), at(0, -0.3, -1.02), C.cream)
	ctx.ball("Head", "Lip", Vector3.new(0.64, 0.08, 1.12), at(0, -0.41, -1.0), C.black)
	ctx.ball("Head", "Nose", Vector3.new(0.28, 0.2, 0.24), at(0, -0.06, -1.7), C.black)
	-- Gueule ouverte très sombre et crocs séparés.
	ctx.ball("Head", "Mouth", Vector3.new(0.54, 0.26, 1.0), at(0, -0.5, -0.95), C.mouth)
	local down = HF:VectorToWorldSpace(Vector3.new(0, -1, -0.05))
	local fwd = HF:VectorToWorldSpace(Vector3.new(0, 0, -1))
	for _, f in { { 0.13, -1.38, 0.42 }, { 0.25, -1.02, 0.34 } } do
		for _, sx in { -1, 1 } do
			ctx.hook("Head", "Fang", C.claw, HF * Vector3.new(sx * f[1], -0.4, f[2]), down, -fwd, f[3], 0.12, 0.07)
		end
	end
	-- Mâchoire inférieure (os animé : rugissement).
	local jaw = ctx.ball(nil, "Jaw", Vector3.new(0.56, 0.24, 1.12), at(0, -0.66, -0.88) * CFrame.Angles(-0.12, 0, 0), C.cream)
	ctx.bone("Jaw", "Head", "Jaw", jaw, at(0, -0.36, -0.3))
	for _, sx in { -1, 1 } do
		ctx.hook("Jaw", "Fang", C.claw, HF * Vector3.new(sx * 0.17, -0.58, -1.25), -down, -fwd, 0.3, 0.1, 0.06)
	end

	-- Yeux rouges lumineux, fendus, cerclés de noir (marques qui filent vers les oreilles).
	for _, sx in { -1, 1 } do
		local normal = HF:VectorToWorldSpace(Vector3.new(sx * 0.55, 0.12, -0.83))
		local base = HF * Vector3.new(sx * 0.38, 0.11, -0.56)
		local roll = CFrame.Angles(0, 0, sx * 0.42)
		local eyeFrame = facing(base, normal) * roll
		ctx.ball("Head", "EyeMark", Vector3.new(0.66, 0.3, 0.12), eyeFrame * CFrame.new(sx * 0.05, 0.01, -0.01), C.black)
		ctx.ball("Head", "Eye", Vector3.new(0.46, 0.16, 0.1), eyeFrame * CFrame.new(0, 0, -0.05), C.eye, { Material = Enum.Material.Neon })
		ctx.ball("Head", "Pupil", Vector3.new(0.05, 0.15, 0.06), eyeFrame * CFrame.new(-sx * 0.02, 0, -0.08), C.black)
		ctx.ball(
			"Head",
			"Mark",
			Vector3.new(0.1, 0.42, 0.08),
			facing(HF * Vector3.new(sx * 0.42, 0.36, -0.36), HF:VectorToWorldSpace(Vector3.new(sx * 0.6, 0.35, -0.7))) * CFrame.Angles(0, 0, sx * 0.5),
			C.black
		)
	end

	-- Longues oreilles pointues, noires à l'intérieur (os animés : frémissements).
	for _, sx in { -1, 1 } do
		local side = sx < 0 and "Left" or "Right"
		local base = HF * Vector3.new(sx * 0.4, 0.42, 0.12)
		local up = HF:VectorToWorldSpace(Vector3.new(sx * 0.42, 1, 0.3))
		local front = HF:VectorToWorldSpace(Vector3.new(sx * 0.35, 0, -1))
		local root = ctx.ball(nil, side .. "Ear", Vector3.new(0.5, 0.42, 0.42), frameY(base, up, front), C.main)
		ctx.bone(side .. "Ear", "Head", side .. "EarJoint", root, CFrame.new(base))
		local ear = frameY(base, up, front)
		ctx.blade(side .. "Ear", "EarOuter", C.main, ear * CFrame.new(0, -0.05, 0.03), 1.9, 0.78, 0.16)
		ctx.blade(side .. "Ear", "EarInner", C.black, ear * CFrame.new(0, 0.1, -0.07), 1.6, 0.54, 0.06)
	end
end

-- Patte avant : bras sec et long, grande main aux longs doigts griffus. La patte droite est
-- avancée (vers la caméra de 3/4, comme sur la référence), la gauche reculée.
local FRONT_POSE = {
	Right = { elbow = Vector3.new(1.85, 1.6, -1.75), wrist = Vector3.new(2.0, 0.36, -3.4) },
	Left = { elbow = Vector3.new(1.95, 1.65, -1.0), wrist = Vector3.new(2.15, 0.38, -2.35) },
}
local function buildFrontLeg(ctx, sx: number)
	local C = FOX
	local side = sx < 0 and "Left" or "Right"
	local pose = FRONT_POSE[side]
	local shoulder = Vector3.new(sx * 1.0, 2.55, -1.05)
	local elbow = pose.elbow * Vector3.new(sx, 1, 1)
	local wrist = pose.wrist * Vector3.new(sx, 1, 1)
	local upper = ctx.limb(nil, side .. "UpperArm", shoulder, elbow, 0.85, 0.95, C.main, 0.6)
	ctx.bone(side .. "UpperArm", "Torso", side .. "Shoulder", upper, CFrame.new(shoulder))
	-- Creux sombre de l'aisselle.
	ctx.ball(side .. "UpperArm", "Armpit", Vector3.new(0.5, 1.0, 0.7), CFrame.new(shoulder:Lerp(elbow, 0.45) + Vector3.new(-sx * 0.3, -0.1, 0.25)), C.shade)
	ctx.fin(
		side .. "UpperArm",
		"ElbowTuft",
		C.shade,
		frameY(elbow + Vector3.new(sx * 0.15, 0.1, 0.15), Vector3.new(sx * 0.6, 0.15, 0.8), Vector3.new(sx, 0, 0)),
		0.65,
		0.4,
		0.14,
		sx > 0
	)
	local fore = ctx.limb(nil, side .. "Forearm", elbow, wrist, 0.62, 0.66, C.main, 0.4)
	ctx.bone(side .. "Forearm", side .. "UpperArm", side .. "Elbow", fore, CFrame.new(elbow))
	-- Grande main : paume, quatre longs doigts écartés, griffes blanches crochues.
	local palm = wrist + Vector3.new(sx * 0.05, -0.16, -0.3)
	ctx.ball(side .. "Forearm", "Paw", Vector3.new(0.9, 0.36, 0.95), CFrame.new(palm), C.main)
	for i, dx in { -0.3, -0.1, 0.1, 0.3 } do
		local from = palm + Vector3.new(sx * dx * 1.2, -0.03, -0.35)
		local tip = palm + Vector3.new(sx * dx * 2.4, -0.12, -1.35 + math.abs(dx) * 0.6)
		ctx.limb(side .. "Forearm", "Finger", from, tip, 0.2, 0.2, i % 2 == 0 and C.main or C.shade, 0.16, Vector3.new(0, 1, 0))
		local dir = (tip - from).Unit
		ctx.hook(side .. "Forearm", "Claw", C.claw, tip + dir * 0.02 + Vector3.new(0, -0.06, 0), dir, Vector3.new(0, -1, 0), 0.58, 0.17, 0.09)
	end
end

local function buildHindLeg(ctx, sx: number)
	local C = FOX
	local side = sx < 0 and "Left" or "Right"
	local hip = Vector3.new(sx * 0.9, 2.2, 1.5)
	local knee = Vector3.new(sx * 1.22, 1.1, 0.45)
	local hock = Vector3.new(sx * 1.22, 0.55, 1.4)
	local foot = Vector3.new(sx * 1.25, 0.2, 0.9)
	local thigh = ctx.ball(nil, side .. "Thigh", Vector3.new(0.9, 1.95, 1.4), frameY(Vector3.new(sx * 1.05, 1.65, 1.05), hip - knee), C.main)
	ctx.bone(side .. "Thigh", "Hips", side .. "Hip", thigh, CFrame.new(hip))
	-- Arrière de cuisse dans l'ombre + touffe.
	ctx.ball(side .. "Thigh", "ThighShade", Vector3.new(0.7, 1.5, 0.7), frameY(Vector3.new(sx * 1.1, 1.55, 1.55), hip - knee), C.shade)
	ctx.fin(side .. "Thigh", "HaunchTuft", C.shade, frameY(Vector3.new(sx * 1.25, 1.7, 1.75), Vector3.new(sx * 0.35, -0.2, 1), Vector3.new(sx, 0, 0)), 0.65, 0.42, 0.14, sx > 0)
	local shin = ctx.limb(nil, side .. "Shin", knee, hock, 0.55, 0.58, C.shade, 0.4)
	ctx.bone(side .. "Shin", side .. "Thigh", side .. "Knee", shin, CFrame.new(knee))
	ctx.limb(side .. "Shin", "Hock", hock, foot, 0.46, 0.46, C.main, 0.3)
	ctx.ball(side .. "Shin", "Foot", Vector3.new(0.64, 0.34, 0.9), CFrame.new(sx * 1.26, 0.17, 0.6), C.main)
	for _, dx in { -0.18, 0, 0.18 } do
		local x = sx * (1.26 + dx)
		local from = Vector3.new(x, 0.16, 0.4)
		local tip = Vector3.new(x + sx * dx * 0.4, 0.12, 0.0)
		ctx.limb(side .. "Shin", "Toe", from, tip, 0.18, 0.17, C.main, 0.14, Vector3.new(0, 1, 0))
		ctx.hook(side .. "Shin", "Claw", C.claw, tip + Vector3.new(0, -0.05, -0.02), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), 0.38, 0.16, 0.08)
	end
end

-- Une queue : chaîne de segments (os) qui part de la croupe, en fuseau (fine à la base, large au
-- milieu, effilée au bout). Les ellipsoïdes se chevauchent beaucoup (deux voisins diffèrent peu en
-- largeur) pour donner une grande mèche lisse ; dessous dans l'ombre, liseré clair sur le dessus.
local TAIL_WIDTH = { 0.55, 0.78, 0.96, 1.04, 0.94, 0.72 }
local TAIL_OVERLAP = 3.5
-- Courbure (rad) à chaque jointure : départ vers l'extérieur puis bout qui se relève (S).
local TAIL_BEND = { -0.22, -0.16, 0.06, 0.3, 0.42, 0.5 }
-- Côté +X (à gauche de l'image en vue de 3/4 avant) : queues plus longues et plus couchées,
-- comme la gerbe asymétrique de la référence.
local FAN_SHIFT = math.rad(8)
local function buildTail(ctx, index: number, count: number)
	local C = FOX
	local u = (index - 1) / (count - 1) * 2 - 1 -- -1 (gauche) .. 1 (droite)
	-- 0 = vers le haut ; un peu d'aléa par queue pour casser la symétrie « queue de paon ».
	local fan = math.sign(u) * math.abs(u) ^ 0.95 * math.rad(u > 0 and 102 or 100) + FAN_SHIFT + (noise(index, 1) - 0.5) * math.rad(10)
	local base = Vector3.new(math.sin(fan) * 0.5, 2.6 + math.cos(fan) * 0.15, 2.1)
	local dir = Vector3.new(math.sin(fan), math.cos(fan) + 0.4, 0.3 + 0.1 * math.cos(fan)).Unit
	local tangent = Vector3.new(math.cos(fan), -math.sin(fan), 0)
	-- Repère : Y le long de la queue, X dans le plan de l'éventail.
	local back = tangent:Cross(dir).Unit
	local frame = CFrame.fromMatrix(base, dir:Cross(back).Unit, dir, back)
	local length = (9.0 - math.abs(u) * 0.3) * (0.87 + noise(index, 2) * 0.26) * (1 + math.max(0, u) * 0.12)
	local seg = length / #TAIL_WIDTH
	local wmax = 2.4
	-- Courbe en S marquée : la base part vers l'extérieur, le bout se relève (pointe recourbée).
	local curl = fan >= 0 and 1 or -1
	local bendAmount = 0.8 + noise(index, 3) * 0.4
	local parentName = "Hips"
	for k, w in TAIL_WIDTH do
		local width = w * wmax
		local name = "Tail" .. index .. "_" .. k
		local part = ctx.ball(nil, name, Vector3.new(width, seg * TAIL_OVERLAP, width * 0.6), frame * CFrame.new(0, seg * 0.5, 0), C.main)
		ctx.bone(name, parentName, name, part, frame)
		-- Dessous / intérieur de l'éventail dans l'ombre (bande continue d'un segment à l'autre).
		if k >= 2 then
			ctx.ball(
				name,
				"TailShade",
				Vector3.new(width * 0.8, seg * TAIL_OVERLAP * 0.97, width * 0.62),
				frame * CFrame.new(curl * width * 0.13, seg * 0.5, 0),
				k == 2 and C.deep or C.shade
			)
		end
		if k >= 3 and k <= 5 then
			-- Reflet clair sur l'arête du dessus.
			ctx.ball(name, "TailLight", Vector3.new(width * 0.5, seg * TAIL_OVERLAP * 0.9, width * 0.58), frame * CFrame.new(-curl * width * 0.2, seg * 0.5, 0), C.light)
		end
		parentName = name
		local bendZ = TAIL_BEND[k] * curl * (0.45 + 0.55 * math.abs(u)) * bendAmount
		local bendX = (k <= 2 and 0.12 or -0.16)
		frame = frame * CFrame.new(0, seg, 0) * CFrame.Angles(bendX, 0, bendZ)
	end
	-- Pointe en flamme : deux fuseaux de plus en plus fins qui se recourbent, puis une courte pointe.
	local lastWidth = TAIL_WIDTH[#TAIL_WIDTH] * wmax
	local tipWidth = lastWidth * 0.82
	ctx.ball(parentName, "TailTip", Vector3.new(tipWidth, seg * 2.6, tipWidth * 0.55), frame * CFrame.new(0, seg * 0.55, 0), C.main)
	local tip2 = frame * CFrame.new(0, seg * 1.15, 0) * CFrame.Angles(0, 0, 0.3 * curl)
	ctx.ball(parentName, "TailTip", Vector3.new(tipWidth * 0.58, seg * 2.0, tipWidth * 0.36), tip2 * CFrame.new(0, seg * 0.55, 0), C.main)
	local point = tip2 * CFrame.new(0, seg * 1.25, 0) * CFrame.Angles(0, 0, 0.35 * curl)
	ctx.fin(parentName, "TailFlame", C.main, point * CFrame.new(0, -seg * 0.25, 0), seg * 1.05, tipWidth * 0.5, 0.2, curl > 0)
end

local function buildKurama(ctx)
	local C = FOX
	-- Corps : torse massif penché vers l'avant, croupe haute (posture prête à bondir).
	local BF = CFrame.new(0, 2.25, 0) * CFrame.Angles(0.2, 0, 0)
	local torso = ctx.ball(nil, "Torso", Vector3.new(2.25, 2.1, 2.4), BF * CFrame.new(0, 0.15, -0.9), C.main)
	ctx.bone("Torso", "HumanoidRootPart", "RootJoint", torso, CFrame.new(0, 2.25, -0.3))
	ctx.ball("Torso", "Chest", Vector3.new(1.5, 1.65, 0.9), BF * CFrame.new(0, 0.0, -1.85), C.light)
	ctx.ball("Torso", "Belly", Vector3.new(1.7, 1.5, 2.15), BF * CFrame.new(0, -0.05, 0.3), C.main)
	ctx.ball("Torso", "Underbelly", Vector3.new(1.3, 0.85, 2.2), BF * CFrame.new(0, -0.55, -0.2), C.cream)
	local hips = ctx.ball(nil, "Hips", Vector3.new(1.8, 1.6, 1.7), BF * CFrame.new(0, 0.12, 1.4), C.main)
	ctx.bone("Hips", "Torso", "Spine", hips, CFrame.new(0, 2.1, 0.6))
	ctx.ball("Hips", "Rump", Vector3.new(1.3, 1.1, 1.0), BF * CFrame.new(0, 0.5, 2.0), C.shade)
	buildHead(ctx)
	for _, sx in { -1, 1 } do
		buildFrontLeg(ctx, sx)
		buildHindLeg(ctx, sx)
	end
	for i = 1, CreatureBuilder.TailCount do
		buildTail(ctx, i, CreatureBuilder.TailCount)
	end
end

local KINDS = { kurama = buildKurama }

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
	paint: string?, -- ignoré (les créatures n'ont pas de peinture en SurfaceGui)
}

-- Nom de la créature à construire pour ce look (nil = perso R6 classique).
function CreatureBuilder.kindOf(look): string?
	local kind = type(look) == "table" and look.creature or nil
	if kind and KINDS[kind] then
		return kind
	end
	return nil
end

function CreatureBuilder.build(look, options: BuildOptions?): Model
	local opts = options or {}
	local s = opts.scale or 1
	local kind = CreatureBuilder.kindOf(look) or "kurama"
	local model = Instance.new("Model")
	model.Name = opts.name or "Creature"

	local ctx = newContext(model, s)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE * s
	root.CFrame = CFrame.new(ROOT_CENTER * s)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	root.Massless = false
	root.Anchored = opts.anchored == true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		root.RootPriority = 127
	end)
	root.Parent = model
	ctx.bones.HumanoidRootPart = root
	model.PrimaryPart = root

	KINDS[kind](ctx)

	-- Les gros volumes reçoivent les clics (ciblage), y compris les queues (plus de la moitié de la
	-- silhouette) ; le reste est purement décoratif.
	for name, part in ctx.bones do
		if name ~= "HumanoidRootPart" and (QUERY_BONES[name] or string.match(name, "^Tail%d+_[1-4]$")) then
			part.CanQuery = true
		end
	end
	-- Point le plus haut (bout des queues) au-dessus du centre du HumanoidRootPart : NameTags pose
	-- l'étiquette au-dessus de l'éventail (attribut TagHeight).
	local top = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local cf, size = descendant.CFrame, descendant.Size
			local half = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
			top = math.max(top, cf.Position.Y + half)
		end
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
		-- R15 : la hauteur vient de HipHeight (pas de jambes R6 sur une créature).
		humanoid.RigType = Enum.HumanoidRigType.R15
		pcall(function()
			humanoid.AutomaticScalingEnabled = false
		end)
		humanoid.HipHeight = CreatureBuilder.HipHeight * s
		humanoid.WalkSpeed = opts.walkSpeed or 16
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.AutoJumpEnabled = true
		humanoid.MaxHealth = 1e9
		humanoid.Health = 1e9
		humanoid.Parent = model
		Instance.new("Animator").Parent = humanoid
	else
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		Instance.new("Animator").Parent = controller
	end

	model:SetAttribute("Creature", kind)
	model:SetAttribute("BaseScale", s)
	model:SetAttribute("RootHeight", CreatureBuilder.RootHeight * s)
	model:SetAttribute("PartCount", ctx.count + 1)
	-- Portée de corps à corps (CombatService) : du centre du HumanoidRootPart au bout des griffes.
	model:SetAttribute("Reach", CreatureBuilder.Reach * s)
	model:SetAttribute("TagHeight", top - CreatureBuilder.RootHeight * s + 0.6 * s)
	return model
end

-- Modèle ancré pour les aperçus des menus (toutes les pièces visibles en ViewportFrame).
function CreatureBuilder.buildPreview(look): Model
	local model = CreatureBuilder.build(look, { scale = 0.8, name = "Preview", paint = "parts" })
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

return CreatureBuilder
