-- Construit les épées en pièces (outil "Tool" du joueur, modèle d'aperçu du Forgeron, épée rangée
-- au fourreau sur le perso). Chaque épée a sa propre forme (Config/Swords : look.style) :
--   lame profilée (plat, biseaux du tranchant, pointe, gorge, motifs), garde ouvragée, poignée
--   tressée, pommeau, ornements (gemmes, rubans, chaîne), et un EFFET permanent (particules,
--   arcs électriques, flammes, brume...) qui s'intensifie avec le rang de l'épée.
-- Repère : la poignée (Handle) est tenue dans la main ; la lame part vers -Z de la poignée
-- (prise standard des outils Roblox). Le plat de la lame est le plan XZ (épaisseur selon Y),
-- le tranchant principal est du côté -X. L'outil est tenu avec Grip = rotation de -90° autour de Z :
-- en main, la lame est donc DE CHANT (plat vers les côtés, tranchant vers le bas, dos et courbure
-- des katanas vers le haut), comme dans les animés.

local SwordBuilder = {}

-- Prise de l'outil : la lame reste le long de -Z de la poignée, mais tourne de -90° sur elle-même
-- pour être tenue de chant (tranchant -X vers le bas, dos +X vers le haut).
SwordBuilder.GRIP = CFrame.Angles(0, 0, math.rad(-90))

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local IRON = rgb(44, 42, 48)
local GOLD = rgb(222, 178, 72)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local X_AXIS = Vector3.new(1, 0, 0)
local Y_AXIS = Vector3.new(0, 1, 0)
local Z_AXIS = Vector3.new(0, 0, 1)

local GRIP_FRONT = -0.55 -- avant de la poignée (côté garde)

------------------------------------------------------------------------
-- Contexte de construction
------------------------------------------------------------------------

type Ctx = {
	parent: Instance,
	handle: BasePart,
	sword: any,
	look: any,
	k: number, -- intensité de l'effet (0 → 1)
	count: number,
	tip: Vector3, -- pointe de la lame (repère de la poignée)
	bladeStart: number,
	back: number, -- extrémité arrière (pommeau)
	hiltOnly: boolean,
	parts: { BasePart },
}

local function newCtx(parent: Instance, handle: BasePart, sword, power: number): Ctx
	return {
		parent = parent,
		handle = handle,
		sword = sword,
		look = sword.look,
		k = power,
		count = 1,
		tip = Vector3.new(0, 0, -3),
		bladeStart = -0.75,
		back = 0.6,
		hiltOnly = false,
		parts = {},
	}
end

local function material(name: string?): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name or "Metal"]
	end)
	return ok and value or Enum.Material.Metal
end

-- Pièce soudée à la poignée. `cf` est exprimé dans le repère de la poignée.
local function part(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = ctx.handle.CFrame * cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = ctx.handle.Anchored
	if p.Material == Enum.Material.Metal or p.Material == Enum.Material.Foil then
		p.Reflectance = 0.12
	end
	if p.Material == Enum.Material.Neon or math.min(size.X, size.Y, size.Z) < 0.07 then
		p.CastShadow = false
	end
	if props then
		local target: any = p
		for key, value in props do
			target[key] = value
		end
	end
	p.Parent = ctx.parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.handle
	weld.Part1 = p
	weld.Parent = p
	ctx.count += 1
	table.insert(ctx.parts, p)
	return p
end

local function block(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): BasePart
	return part(ctx, name, size, cf, color, mat, props)
end

-- Ellipsoïde (gemme, boule) : bloc + maillage sphère.
local function orb(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): BasePart
	local p = part(ctx, name, size, cf, color, mat, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Cylindre dont l'axe suit Z (anneaux, viroles, tsuba).
local function disc(ctx: Ctx, name: string, diameter: number, thickness: number, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): BasePart
	local p = part(ctx, name, Vector3.new(thickness, diameter, diameter), cf * CFrame.Angles(0, math.rad(90), 0), color, mat, props);
	(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

-- Cylindre dont l'axe suit Y (pommeau en roue vu de face).
local function wheel(ctx: Ctx, name: string, diameter: number, thickness: number, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): BasePart
	local p = part(ctx, name, Vector3.new(thickness, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, props);
	(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

-- Triangle rectangle dans le plan XY du repère `cf` : angle droit à l'origine, côté `a` selon X,
-- côté `b` selon Y (négatifs = de l'autre côté), épaisseur `d` selon Z. C'est une WedgePart.
local WEDGE_ORIENT = CFrame.fromMatrix(Vector3.zero, Z_AXIS, Y_AXIS, -X_AXIS)
local function tri(ctx: Ctx, name: string, a: number, b: number, d: number, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): BasePart
	local flip = CFrame.new()
	if a < 0 then
		flip *= CFrame.Angles(0, math.pi, 0)
	end
	if b < 0 then
		flip *= CFrame.Angles(math.pi, 0, 0)
	end
	local A, B = math.abs(a), math.abs(b)
	return part(ctx, name, Vector3.new(d, B, A), cf * flip * CFrame.new(A / 2, B / 2, 0) * WEDGE_ORIENT, color, mat, props, "WedgePart")
end

-- Repère « plan de la lame » en (x, z) : X = largeur, Y = vers la pointe (-Z), Z = épaisseur.
local function BP(x: number, z: number, y: number?): CFrame
	return CFrame.fromMatrix(Vector3.new(x, y or 0, z), X_AXIS, -Z_AXIS, Y_AXIS)
end

-- Repère « plan de la lame » orienté vers l'arrière (pommeau) : Y = +Z.
local function PP(x: number, z: number): CFrame
	return CFrame.fromMatrix(Vector3.new(x, 0, z), X_AXIS, Z_AXIS, -Y_AXIS)
end

------------------------------------------------------------------------
-- Lames
------------------------------------------------------------------------

-- Tronçon de lame dans le repère S (de 0 à -len selon -Z) : plat + biseaux du tranchant.
-- edges = "both" (lame droite à deux tranchants) ou "left" (katana : tranchant côté -X).
local function bladeSection(ctx: Ctx, S: CFrame, len: number, w: number, t: number, edges: string, bevelRatio: number?)
	local look = ctx.look
	local bladeMat = material(look.material)
	local props = nil
	if bladeMat == Enum.Material.Glass then
		props = { Transparency = 0.12, Reflectance = 0.25 }
	end
	local bevelW = w * (bevelRatio or 0.3)
	local mid = S * CFrame.new(0, 0, -len / 2)
	if edges == "both" then
		local coreW = w - bevelW * 2
		block(ctx, "Blade", Vector3.new(coreW, t, len), mid, look.blade, bladeMat, props)
		for _, side in { -1, 1 } do
			for _, up in { 1, -1 } do
				tri(ctx, "Bevel", side * bevelW, up * t / 2, len, mid * CFrame.new(side * coreW / 2, 0, 0), look.bevel or look.blade, bladeMat, props)
			end
		end
	else
		local coreW = w - bevelW
		block(ctx, "Blade", Vector3.new(coreW, t, len), mid * CFrame.new(bevelW / 2, 0, 0), look.blade, bladeMat, props)
		for _, up in { 1, -1 } do
			tri(ctx, "Bevel", -bevelW, up * t / 2, len, mid * CFrame.new(-w / 2 + bevelW, 0, 0), look.bevel or look.blade, bladeMat, props)
		end
	end
end

-- Pointe à deux tranchants (losange) au bout d'une lame droite.
local function westernTip(ctx: Ctx, z: number, w: number, t: number, tipLen: number, coreRatio: number?)
	local look = ctx.look
	local bladeMat = material(look.material)
	local props = bladeMat == Enum.Material.Glass and { Transparency = 0.12, Reflectance = 0.25 } or nil
	for _, side in { -1, 1 } do
		tri(ctx, "Tip", side * w / 2, tipLen, t, BP(0, z), look.bevel or look.blade, bladeMat, props)
	end
	local core = w * (coreRatio or 0.4)
	for _, side in { -1, 1 } do
		tri(ctx, "TipRidge", side * core / 2, tipLen * 0.78, t + 0.012, BP(0, z), look.blade, bladeMat, props)
	end
	ctx.tip = Vector3.new(0, 0, z - tipLen)
end

-- Lame droite (épées européennes) : renvoie la position du bout du plat (avant la pointe).
local function straightBlade(ctx: Ctx, start: number, length: number, w: number, t: number, tipLen: number): number
	local bodyLen = length - tipLen
	bladeSection(ctx, CFrame.new(0, 0, start), bodyLen + 0.01, w, t, "both")
	westernTip(ctx, start - bodyLen, w, t, tipLen)
	return start - bodyLen
end

-- Lame de katana courbée (3 tronçons, courbure vers le dos), avec pointe kissaki.
-- `decorate(i, S, segLen, w)` ajoute les motifs propres à l'épée sur chaque tronçon.
local function katanaBlade(ctx: Ctx, start: number, length: number, w: number, t: number, curveDeg: number, decorate: ((number, CFrame, number, number) -> ())?): { CFrame }
	local look = ctx.look
	local tipLen = w * 1.35
	local bodyLen = length - tipLen
	local n = 3
	local segLen = bodyLen / n
	local frames = {}
	local S = CFrame.new(0, 0, start)
	local width = w
	for i = 1, n do
		width = w * (1 - 0.05 * (i - 1))
		table.insert(frames, S)
		bladeSection(ctx, S, segLen + 0.03, width, t, "left", 0.36)
		if look.edge then
			-- Fil du tranchant poli (Foil coloré, pas de Neon sur toute la longueur).
			block(ctx, "EdgeLine", Vector3.new(0.022, 0.028, segLen + 0.02), S * CFrame.new(-width / 2 + 0.011, 0, -segLen / 2), look.edge, Enum.Material.Foil)
		end
		if decorate then
			decorate(i, S, segLen, width)
		end
		S = S * CFrame.new(0, 0, -segLen) * CFrame.Angles(0, -math.rad(curveDeg), 0)
	end
	-- Kissaki : le tranchant remonte vers le dos.
	local bladeMat = material(look.material)
	tri(ctx, "Kissaki", -width, tipLen, t, S * BP(width / 2, 0), look.bevel or look.blade, bladeMat)
	tri(ctx, "KissakiRidge", -width * 0.45, tipLen * 0.55, t + 0.01, S * BP(width / 2, 0), look.blade, bladeMat)
	table.insert(frames, S)
	ctx.tip = (S * CFrame.new(width / 2, 0, -tipLen)).Position
	return frames
end

-- Ligne gravée / lumineuse posée sur les deux faces du plat (légèrement plus épaisse que la lame).
-- Le Neon reste DISCRET : gravure fine (0,03 de large au plus), légèrement transparente.
local NEON_MAX = 0.03
local function inlay(ctx: Ctx, name: string, S: CFrame, x: number, z: number, len: number, width: number, t: number, angle: number, color: Color3, mat: Enum.Material?)
	local m = mat or Enum.Material.Neon
	local props = nil
	if m == Enum.Material.Neon then
		width = math.min(width, NEON_MAX)
		props = { Transparency = 0.2 }
	end
	return block(ctx, name, Vector3.new(width, t + 0.014, len), S * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(angle), 0), color, m, props)
end

------------------------------------------------------------------------
-- Poignées et gardes communes
------------------------------------------------------------------------

-- Tsuka de katana : peau de raie + tsuka-ito croisé en losanges, fuchi, kashira, menuki.
local function tsuka(ctx: Ctx, length: number, rayskin: Color3, ito: Color3, metal: Color3, ornament: Color3?)
	local back = GRIP_FRONT + length
	local extra = back - 0.55
	if extra > 0.02 then
		block(ctx, "TsukaEnd", Vector3.new(0.3, 0.24, extra + 0.02), CFrame.new(0, 0, 0.55 + extra / 2 - 0.01), rayskin, Enum.Material.SmoothPlastic)
	end
	local pitch = 0.255
	local z = GRIP_FRONT + 0.16
	while z < back - 0.12 do
		for _, sign in { 1, -1 } do
			block(ctx, "TsukaIto", Vector3.new(0.35, 0.27, 0.075), CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(38 * sign), 0), ito, Enum.Material.Fabric)
		end
		z += pitch
	end
	for _, side in { 1, -1 } do
		orb(ctx, "Menuki", Vector3.new(0.12, 0.06, 0.2), CFrame.new(0, side * 0.135, GRIP_FRONT + length * 0.45), ornament or metal, Enum.Material.Foil)
	end
	block(ctx, "Fuchi", Vector3.new(0.34, 0.28, 0.09), CFrame.new(0, 0, GRIP_FRONT - 0.02), metal, Enum.Material.Metal)
	block(ctx, "Kashira", Vector3.new(0.34, 0.28, 0.12), CFrame.new(0, 0, back + 0.04), metal, Enum.Material.Metal)
	orb(ctx, "KashiraCap", Vector3.new(0.3, 0.24, 0.12), CFrame.new(0, 0, back + 0.1), metal, Enum.Material.Metal)
	ctx.back = back + 0.16
	return back
end

-- Habaki (collier doré à la base de la lame) et seppa (rondelles de part et d'autre de la tsuba).
local function habakiSeppa(ctx: Ctx, tsubaZ: number, tsubaT: number, w: number, t: number, color: Color3)
	disc(ctx, "Seppa", 0.42, 0.03, CFrame.new(0, 0, tsubaZ + tsubaT / 2 + 0.015), color, Enum.Material.Foil)
	disc(ctx, "Seppa", 0.42, 0.03, CFrame.new(0, 0, tsubaZ - tsubaT / 2 - 0.015), color, Enum.Material.Foil)
	local start = tsubaZ - tsubaT / 2 - 0.03
	block(ctx, "Habaki", Vector3.new(w + 0.05, t + 0.07, 0.2), CFrame.new(0.01, 0, start - 0.1), color, Enum.Material.Foil)
	return start
end

-- Poignée de cuir enroulée (épées européennes).
local function leatherGrip(ctx: Ctx, wrap: Color3, bands: number, angle: number)
	for i = 1, bands do
		local z = GRIP_FRONT + (i - 0.5) * (1.1 / bands)
		local sign = i % 2 == 0 and 1 or -1
		block(ctx, "Wrap", Vector3.new(0.32, 0.3, 0.075), CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(angle * sign), 0), wrap, Enum.Material.Fabric)
	end
end

------------------------------------------------------------------------
-- Effets permanents (particules, lumières, arcs)
------------------------------------------------------------------------

type EmitterSpec = {
	name: string?,
	texture: string?,
	color: Color3,
	color2: Color3?,
	size: { number },
	transparency: { number }?,
	life: { number },
	rate: number,
	speed: { number },
	spread: number?,
	accel: Vector3?,
	drag: number?,
	light: number?,
	rot: number?,
	enabled: boolean?,
	influence: number?,
}

local function sequence(values: { number }): NumberSequence
	if #values == 1 then
		return NumberSequence.new(values[1])
	end
	local kps = {}
	for i, v in values do
		table.insert(kps, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent: Instance, spec: EmitterSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = spec.name or "Aura"
	e.Texture = spec.texture or SPARK
	e.Color = ColorSequence.new(spec.color, spec.color2 or spec.color)
	e.Size = sequence(spec.size)
	e.Transparency = sequence(spec.transparency or { 0, 1 })
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.Rate = spec.rate
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	e.SpreadAngle = Vector2.new(spec.spread or 180, spec.spread or 180)
	e.Acceleration = spec.accel or Vector3.zero
	e.Drag = spec.drag or 0
	e.LightEmission = spec.light or 0
	e.LightInfluence = spec.influence or (spec.light and spec.light > 0.5 and 0 or 1)
	e.RotSpeed = NumberRange.new(-(spec.rot or 0), spec.rot or 0)
	e.Rotation = NumberRange.new(0, 360)
	e.Enabled = spec.enabled ~= false
	e.Parent = parent
	return e
end

-- Volume invisible le long de la lame : porte les particules, la lumière et les arcs.
local function auraVolume(ctx: Ctx, w: number, t: number): BasePart
	local startZ = ctx.bladeStart
	local tip = ctx.tip
	local len = math.max(startZ - tip.Z, 0.5)
	local center = Vector3.new(tip.X * 0.5, 0, (startZ + tip.Z) / 2)
	local vol = block(ctx, "AuraVolume", Vector3.new(w, t + 0.1, len), CFrame.new(center), WHITE, Enum.Material.SmoothPlastic, { Transparency = 1, CastShadow = false })
	return vol
end

local function glow(holder: Instance, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = color
	-- Plafonné pour ne pas noyer la lame dans la lueur (même au rang le plus haut).
	light.Brightness = math.min(brightness, 1.5)
	light.Range = math.min(range, 8)
	light.Shadows = false
	light.Parent = holder
	return light
end

-- Arc lumineux entre deux points du volume (Beam animé par sa texture).
local function arc(vol: BasePart, name: string, fromZ: number, toZ: number, curve: number, color: Color3, width: number, transparency: number, speed: number, texture: string?)
	local a0 = Instance.new("Attachment")
	a0.Name = name .. "A"
	a0.CFrame = CFrame.new(0, 0, fromZ)
	a0.Parent = vol
	local a1 = Instance.new("Attachment")
	a1.Name = name .. "B"
	a1.CFrame = CFrame.new(0, 0, toZ)
	a1.Parent = vol
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, transparency),
		NumberSequenceKeypoint.new(0.8, transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = width
	beam.Width1 = width * 0.6
	beam.CurveSize0 = curve
	beam.CurveSize1 = curve -- même signe : courbe en S le long de la lame
	beam.Segments = 12
	beam.FaceCamera = true
	beam.Texture = texture or SPARK
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 1.2
	beam.TextureSpeed = speed
	beam.Parent = vol
	return beam
end

-- Effet propre à chaque style. `k` = intensité (rang de l'épée).
local EFFECTS: { [string]: (Ctx, BasePart, number) -> () } = {}

EFFECTS.rusty = function(ctx, vol, _k)
	emitter(vol, {
		color = ctx.look.aura,
		color2 = rgb(90, 60, 40),
		size = { 0.1, 0.06 },
		transparency = { 0.2, 1 },
		life = { 1, 1.6 },
		rate = 1.5,
		speed = { 0.1, 0.4 },
		accel = Vector3.new(0, -3, 0),
		rot = 200,
	})
end

EFFECTS.steel = function(ctx, vol, k)
	emitter(vol, {
		name = "Glint",
		color = WHITE,
		color2 = ctx.look.trail2,
		size = { 0, 0.42, 0 },
		transparency = { 0, 0.1, 1 },
		life = { 0.25, 0.4 },
		rate = 1.5 + 2 * k,
		speed = { 0, 0 },
		light = 1,
	})
end

EFFECTS.wind = function(ctx, vol, k)
	local look = ctx.look
	emitter(vol, {
		name = "Gust",
		texture = SMOKE,
		color = look.aura,
		color2 = WHITE,
		size = { 0.25, 0.9 },
		transparency = { 0.55, 1 },
		life = { 0.6, 1 },
		rate = 5 + 8 * k,
		speed = { 1.5, 3 },
		drag = 2,
		light = 0.6,
		rot = 180,
	})
	emitter(vol, {
		name = "Leaves",
		color = rgb(150, 255, 200),
		color2 = look.trail,
		size = { 0.14, 0.08 },
		transparency = { 0.1, 1 },
		life = { 0.8, 1.3 },
		rate = 2 + 3 * k,
		speed = { 1, 2.5 },
		drag = 1,
		light = 0.8,
		rot = 300,
	})
	local len = vol.Size.Z
	arc(vol, "WindRibbon", len * 0.42, -len * 0.48, 0.32, look.trail, 0.14, 0.55, 2.5, SMOKE)
end

EFFECTS.thunder = function(ctx, vol, k)
	local look = ctx.look
	emitter(vol, {
		name = "Sparks",
		color = look.aura,
		color2 = WHITE,
		size = { 0.2, 0 },
		transparency = { 0, 1 },
		life = { 0.08, 0.22 },
		rate = 10 + 16 * k,
		speed = { 3, 7 },
		light = 1,
	})
	local len = vol.Size.Z
	arc(vol, "Arc1", len * 0.45, -len * 0.05, 0.16, look.edge, 0.18, 0.15, 7)
	arc(vol, "Arc2", -len * 0.02, -len * 0.47, -0.14, WHITE:Lerp(look.edge, 0.5), 0.15, 0.2, -8)
	glow(vol, look.aura, 0.5 + 1.1 * k, 6 + 4 * k)
end

EFFECTS.sun = function(ctx, vol, k)
	local look = ctx.look
	emitter(vol, {
		name = "Flames",
		texture = FIRE,
		color = rgb(255, 190, 70),
		color2 = rgb(230, 50, 20),
		size = { 0.35, 0.6, 0.05 },
		transparency = { 0.25, 0.35, 1 },
		life = { 0.35, 0.6 },
		rate = 14 + 18 * k,
		speed = { 0.3, 1 },
		accel = Vector3.new(0, 3.5, 0),
		light = 1,
		rot = 90,
	})
	emitter(vol, {
		name = "Embers",
		color = rgb(255, 210, 90),
		color2 = rgb(255, 90, 30),
		size = { 0.12, 0 },
		transparency = { 0, 1 },
		life = { 0.6, 1.1 },
		rate = 4 + 6 * k,
		speed = { 0.5, 1.5 },
		accel = Vector3.new(0, 4, 0),
		light = 1,
	})
	glow(vol, look.aura, 1 + 1.6 * k, 8 + 3 * k)
end

EFFECTS.mist = function(ctx, vol, k)
	local look = ctx.look
	emitter(vol, {
		name = "Mist",
		texture = SMOKE,
		color = look.aura,
		color2 = WHITE,
		size = { 0.8, 2.6 },
		transparency = { 0.85, 1 },
		life = { 1.6, 2.6 },
		rate = 5 + 6 * k,
		speed = { 0.2, 0.8 },
		drag = 1,
		light = 0.15,
		rot = 25,
	})
	emitter(vol, {
		name = "Droplets",
		color = rgb(200, 235, 255),
		size = { 0.09, 0.05 },
		transparency = { 0.1, 1 },
		life = { 0.5, 0.9 },
		rate = 3 + 3 * k,
		speed = { 0.2, 0.6 },
		accel = Vector3.new(0, -5, 0),
		light = 0.7,
	})
end

EFFECTS.abyss = function(ctx, vol, k)
	local look = ctx.look
	emitter(vol, {
		name = "Shadow",
		texture = SMOKE,
		color = look.aura,
		color2 = rgb(8, 4, 14),
		size = { 0.5, 1.6 },
		transparency = { 0.45, 1 },
		life = { 0.9, 1.5 },
		rate = 8 + 9 * k,
		speed = { 0.3, 1 },
		accel = Vector3.new(0, 1.5, 0),
		rot = 60,
	})
	emitter(vol, {
		name = "Embers",
		color = look.edge,
		color2 = rgb(255, 120, 255),
		size = { 0.13, 0 },
		transparency = { 0, 1 },
		life = { 0.5, 1 },
		rate = 4 + 5 * k,
		speed = { 0.4, 1.2 },
		accel = Vector3.new(0, 2.5, 0),
		light = 1,
	})
	glow(vol, look.edge, 0.8 + 1.2 * k, 7)
end

EFFECTS.celestial = function(ctx, vol, k)
	local look = ctx.look
	emitter(vol, {
		name = "Stars",
		color = look.aura,
		color2 = WHITE,
		size = { 0, 0.32, 0 },
		transparency = { 0, 0.1, 1 },
		life = { 0.8, 1.4 },
		rate = 10 + 10 * k,
		speed = { 0.2, 0.6 },
		accel = Vector3.new(0, 1.2, 0),
		light = 1,
	})
	emitter(vol, {
		name = "Snow",
		color = WHITE,
		size = { 0.12, 0.08 },
		transparency = { 0.1, 1 },
		life = { 1.2, 1.8 },
		rate = 3 + 3 * k,
		speed = { 0.2, 0.5 },
		accel = Vector3.new(0, -1.5, 0),
		light = 0.6,
		rot = 120,
	})
	local len = vol.Size.Z
	arc(vol, "Halo", len * 0.48, -len * 0.5, 0, look.aura, 0.75, 0.9, 0.6, SMOKE)
	glow(vol, look.aura, 1.2, 8)
end

-- Gerbe de particules du coup (activée un court instant par SwordService à chaque coup).
local BURSTS: { [string]: EmitterSpec } = {
	rusty = { texture = SMOKE, color = rgb(170, 150, 130), size = { 0.3, 0.8 }, transparency = { 0.5, 1 }, life = { 0.3, 0.5 }, rate = 30, speed = { 2, 4 }, drag = 3 },
	steel = { color = WHITE, size = { 0.3, 0 }, life = { 0.15, 0.3 }, rate = 50, speed = { 4, 8 }, light = 1 },
	wind = { texture = SMOKE, color = rgb(170, 255, 240), size = { 0.4, 1.4 }, transparency = { 0.4, 1 }, life = { 0.3, 0.5 }, rate = 60, speed = { 8, 14 }, drag = 4, light = 0.6 },
	thunder = { color = rgb(255, 240, 120), color2 = WHITE, size = { 0.3, 0 }, life = { 0.1, 0.25 }, rate = 90, speed = { 8, 16 }, light = 1 },
	sun = {
		texture = FIRE,
		color = rgb(255, 200, 80),
		color2 = rgb(230, 50, 20),
		size = { 0.7, 0.1 },
		transparency = { 0.2, 1 },
		life = { 0.25, 0.45 },
		rate = 80,
		speed = { 4, 9 },
		light = 1,
		drag = 3,
	},
	mist = { texture = SMOKE, color = rgb(220, 236, 250), size = { 1, 3 }, transparency = { 0.6, 1 }, life = { 0.5, 0.9 }, rate = 50, speed = { 4, 8 }, drag = 3, light = 0.2 },
	abyss = {
		texture = SMOKE,
		color = rgb(90, 30, 150),
		color2 = rgb(10, 4, 18),
		size = { 0.6, 1.8 },
		transparency = { 0.3, 1 },
		life = { 0.3, 0.6 },
		rate = 70,
		speed = { 4, 9 },
		drag = 3,
	},
	celestial = { color = rgb(190, 240, 255), color2 = WHITE, size = { 0.35, 0 }, life = { 0.3, 0.6 }, rate = 90, speed = { 5, 10 }, light = 1, drag = 2 },
}

-- Traînées du coup : une large traînée colorée et un fil lumineux plus fin (épées de haut rang).
local function swingTrails(ctx: Ctx, handle: BasePart)
	local look = ctx.look
	local k = ctx.k
	local tip = ctx.tip
	local function makeTrail(name: string, base: Vector3, top: Vector3, c0: Color3, c1: Color3, life: number, emission: number)
		local a0 = Instance.new("Attachment")
		a0.Name = name == "SwingTrail" and "TrailBase" or name .. "Base"
		a0.CFrame = CFrame.new(base)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Name = name == "SwingTrail" and "TrailTip" or name .. "Tip"
		a1.CFrame = CFrame.new(top)
		a1.Parent = handle
		local trail = Instance.new("Trail")
		trail.Name = name
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(c0, c1)
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime = life
		trail.LightEmission = emission
		trail.LightInfluence = emission > 0.5 and 0 or 1
		trail.FaceCamera = true
		trail.MinLength = 0.05
		trail.Enabled = false
		trail.Parent = handle
		return trail
	end
	local base = Vector3.new(tip.X * 0.15, 0, ctx.bladeStart - 0.3)
	makeTrail("SwingTrail", base, tip, look.trail, look.trail2 or look.trail:Lerp(WHITE, 0.5), 0.14 + 0.14 * k, 0.6 + 0.4 * k)
	if k >= 0.25 then
		local inner = base:Lerp(tip, 0.72)
		makeTrail("SwingTrailCore", inner, tip, WHITE, look.trail, 0.1 + 0.08 * k, 1)
	end
end

------------------------------------------------------------------------
-- Les 8 épées
------------------------------------------------------------------------

type Style = {
	hilt: (Ctx) -> (),
	blade: (Ctx) -> (),
	width: number,
	carry: string, -- "hip" (fourreau à la hanche) ou "back" (dans le dos)
	sheath: string, -- "saya" (katana), "scabbard" (droit) ou "none"
	handle: Vector3,
}

local STYLES: { [string]: Style } = {}

-- 1. Épée Rouillée : épée d'armes usée.
STYLES.rusty = {
	width = 0.32,
	carry = "hip",
	sheath = "scabbard",
	handle = Vector3.new(0.27, 0.25, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		local corroded = Enum.Material.CorrodedMetal
		block(ctx, "GuardCenter", Vector3.new(0.3, 0.24, 0.22), CFrame.new(0, 0, -0.64), look.guard, corroded)
		for _, side in { -1, 1 } do
			block(ctx, "Quillon", Vector3.new(0.5, 0.15, 0.15), CFrame.new(side * 0.38, 0, -0.66) * CFrame.Angles(0, math.rad(side * 7), 0), look.guard, corroded)
			orb(ctx, "QuillonEnd", Vector3.new(0.19, 0.19, 0.19), CFrame.new(side * 0.64, 0, -0.71), look.guard, corroded)
		end
		for i, z in { -0.32, 0.02, 0.34 } do
			block(ctx, "Rag", Vector3.new(0.32, 0.3, 0.09), CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(i % 2 == 0 and 14 or -12), 0), look.hilt, Enum.Material.Fabric)
		end
		block(ctx, "RagEnd", Vector3.new(0.07, 0.02, 0.5), CFrame.new(0.17, 0.06, 0.52) * CFrame.Angles(0, math.rad(24), math.rad(10)), look.hilt, Enum.Material.Fabric)
		orb(ctx, "Pommel", Vector3.new(0.32, 0.32, 0.3), CFrame.new(0, 0, 0.68), look.guard, corroded)
		block(ctx, "Peen", Vector3.new(0.1, 0.1, 0.08), CFrame.new(0, 0, 0.86), look.guard, corroded)
		ctx.back = 0.9
	end,
	blade = function(ctx)
		local look = ctx.look
		local start, w, t = -0.75, look.width, 0.09
		ctx.bladeStart = start
		local endZ = straightBlade(ctx, start, look.length, w, t, 0.42)
		local rust = Enum.Material.CorrodedMetal
		local S = CFrame.new(0, 0, start)
		inlay(ctx, "Rust", S, 0.03, -0.75, 0.3, 0.11, t, 8, look.accent, rust)
		inlay(ctx, "Rust", S, -0.04, -1.85, 0.18, 0.08, t, -12, look.accent, rust)
		inlay(ctx, "Rust", S, 0.05, -2.45, 0.22, 0.07, t, 4, rgb(120, 64, 36), rust)
		-- Ébréchures sur les tranchants.
		tri(ctx, "Nick", 0.07, 0.1, t + 0.01, BP(-w / 2, start - 1.25), rgb(58, 44, 36), rust)
		tri(ctx, "Nick", -0.06, 0.09, t + 0.01, BP(w / 2, start - 2.1), rgb(58, 44, 36), rust)
		local _ = endZ
	end,
}

-- 2. Lame d'Acier : épée longue de chevalier.
STYLES.steel = {
	width = 0.34,
	carry = "hip",
	sheath = "scabbard",
	handle = Vector3.new(0.27, 0.25, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		local gold = look.accent
		leatherGrip(ctx, look.hilt, 4, 30)
		for _, z in { -0.5, 0.5 } do
			disc(ctx, "Wire", 0.31, 0.06, CFrame.new(0, 0, z), gold, Enum.Material.Foil)
		end
		block(ctx, "Escutcheon", Vector3.new(0.34, 0.27, 0.2), CFrame.new(0, 0, -0.64), gold, Enum.Material.Foil)
		for _, side in { -1, 1 } do
			local arm1 = CFrame.new(side * 0.17, 0, -0.64) * CFrame.Angles(0, math.rad(side * 9), 0) * CFrame.new(side * 0.18, 0, 0)
			block(ctx, "Quillon", Vector3.new(0.38, 0.13, 0.13), arm1, look.guard, Enum.Material.Metal)
			local arm2 = arm1 * CFrame.new(side * 0.18, 0, 0) * CFrame.Angles(0, math.rad(side * 22), 0) * CFrame.new(side * 0.14, 0, 0)
			block(ctx, "Quillon", Vector3.new(0.3, 0.11, 0.11), arm2, look.guard, Enum.Material.Metal)
			orb(ctx, "Finial", Vector3.new(0.17, 0.17, 0.17), arm2 * CFrame.new(side * 0.16, 0, 0), gold, Enum.Material.Foil)
		end
		wheel(ctx, "PommelRim", 0.42, 0.1, CFrame.new(0, 0, 0.72), gold, Enum.Material.Foil)
		wheel(ctx, "Pommel", 0.36, 0.17, CFrame.new(0, 0, 0.72), look.guard, Enum.Material.Metal)
		orb(ctx, "PommelGem", Vector3.new(0.13, 0.21, 0.13), CFrame.new(0, 0, 0.72), look.gem, Enum.Material.Neon)
		block(ctx, "Peen", Vector3.new(0.1, 0.1, 0.08), CFrame.new(0, 0, 0.95), gold, Enum.Material.Foil)
		ctx.back = 0.98
	end,
	blade = function(ctx)
		local look = ctx.look
		local start, w, t = -0.74, look.width, 0.09
		ctx.bladeStart = start
		straightBlade(ctx, start, look.length, w, t, 0.46)
		local S = CFrame.new(0, 0, start)
		inlay(ctx, "Fuller", S, 0, -0.35 - look.length * 0.31, look.length * 0.62, 0.06, t - 0.002, 0, rgb(96, 100, 112), Enum.Material.Metal)
		-- Langets dorés et poinçon du forgeron.
		for _, side in { -1, 1 } do
			tri(ctx, "Langet", side * 0.09, 0.24, t + 0.05, BP(0, start), look.accent, Enum.Material.Foil)
		end
		block(ctx, "MakerMark", Vector3.new(0.07, t + 0.018, 0.07), S * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.rad(45), 0), look.accent, Enum.Material.Foil)
	end,
}

-- 3. Katana du Vent.
STYLES.wind = {
	width = 0.24,
	carry = "hip",
	sheath = "saya",
	handle = Vector3.new(0.3, 0.24, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		local back = tsuka(ctx, 1.5, look.grip, look.hilt, IRON, look.accent)
		local z = -0.68
		disc(ctx, "TsubaRim", 0.86, 0.045, CFrame.new(0, 0, z), look.hilt, Enum.Material.Metal)
		disc(ctx, "Tsuba", 0.8, 0.075, CFrame.new(0, 0, z), look.guard, Enum.Material.Metal)
		for i = 0, 3 do
			local a = math.rad(45 + i * 90)
			disc(ctx, "TsubaOpening", 0.15, 0.085, CFrame.new(math.cos(a) * 0.27, math.sin(a) * 0.27, z), rgb(18, 60, 66), Enum.Material.SmoothPlastic)
		end
		ctx.bladeStart = habakiSeppa(ctx, z, 0.075, look.width, 0.08, look.accent)
		-- Ruban sageo noué au kashira, qui flotte.
		local knot = CFrame.new(0, 0, back + 0.16)
		orb(ctx, "SageoKnot", Vector3.new(0.16, 0.12, 0.12), knot, look.hilt, Enum.Material.Fabric)
		local cf = knot * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(0, 0, 0.22)
		for i = 1, 3 do
			block(ctx, "Sageo", Vector3.new(0.09, 0.016, 0.44), cf, look.hilt, Enum.Material.Fabric)
			cf = cf * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.rad(i % 2 == 1 and 30 or -24), 0) * CFrame.new(0, 0, 0.2)
		end
		ctx.back = back + 1.15
	end,
	blade = function(ctx)
		local look = ctx.look
		local t = 0.08
		katanaBlade(ctx, ctx.bladeStart, look.length, look.width, t, look.curve or 2.5, function(i, S, segLen, w)
			if i <= 2 then
				inlay(ctx, "Bohi", S, w * 0.2, -segLen / 2 - (i == 1 and 0.12 or 0), segLen - (i == 1 and 0.24 or 0), 0.035, t - 0.004, 0, rgb(30, 90, 100), Enum.Material.Metal)
			end
			if i == 1 then
				-- Gravure en spirale de vent près du habaki.
				inlay(ctx, "Horimono", S, w * 0.12, -0.55, 0.22, 0.025, t, 30, look.edge)
				inlay(ctx, "Horimono", S, w * 0.12, -0.75, 0.22, 0.025, t, -30, look.edge)
			end
		end)
	end,
}

-- 4. Lame de Foudre.
STYLES.thunder = {
	width = 0.26,
	carry = "hip",
	sheath = "saya",
	handle = Vector3.new(0.3, 0.24, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		local back = tsuka(ctx, 1.5, look.grip, look.hilt, look.accent)
		local z = -0.68
		-- Tsuba en étoile de foudre : disque laqué noir cerclé d'or, quatre éclairs en zigzag
		-- (deux biseaux chacun) sertis d'une petite gemme jaune.
		disc(ctx, "TsubaRim", 0.56, 0.05, CFrame.new(0, 0, z), look.accent, Enum.Material.Metal)
		disc(ctx, "Tsuba", 0.5, 0.085, CFrame.new(0, 0, z), rgb(20, 20, 28), Enum.Material.SmoothPlastic, { Reflectance = 0.18 })
		for i = 0, 3 do
			local branch = CFrame.new(0, 0, z) * CFrame.Angles(0, 0, math.rad(45 + i * 90))
			-- Bas de l'éclair (pointe vers le centre) puis haut de l'éclair (pointe vers l'extérieur) :
			-- les deux biseaux se chevauchent en « Z ».
			tri(ctx, "TsubaBolt", -0.19, 0.13, 0.12, branch * CFrame.new(0.37, -0.065, 0), look.guard, Enum.Material.Metal)
			tri(ctx, "TsubaBolt", 0.25, -0.13, 0.12, branch * CFrame.new(0.3, 0.06, 0), look.guard, Enum.Material.Metal)
			orb(ctx, "BoltGem", Vector3.new(0.075, 0.075, 0.15), branch * CFrame.new(0.335, 0, 0), look.edge, Enum.Material.Neon)
		end
		ctx.bladeStart = habakiSeppa(ctx, z, 0.08, look.width, 0.08, look.accent)
		-- Pompon jaune au kashira.
		block(ctx, "TasselCord", Vector3.new(0.04, 0.04, 0.3), CFrame.new(0.05, 0, back + 0.3) * CFrame.Angles(0, math.rad(15), 0), look.hilt, Enum.Material.Fabric)
		orb(ctx, "Tassel", Vector3.new(0.13, 0.13, 0.26), CFrame.new(0.1, 0, back + 0.52) * CFrame.Angles(0, math.rad(15), 0), look.hilt, Enum.Material.Fabric)
		ctx.back = back + 0.66
	end,
	blade = function(ctx)
		local look = ctx.look
		local t = 0.08
		katanaBlade(ctx, ctx.bladeStart, look.length, look.width, t, look.curve or 2.4, function(i, S, segLen, w)
			-- Hamon en éclair : zigzag doré (Foil) le long du tranchant, avec seulement trois courts
			-- tronçons lumineux (un par tronçon de lame).
			local x = -w / 2 + w * 0.36
			local offsets = { 0.045, -0.04, 0.05, -0.035 }
			local pieces = #offsets
			local step = segLen / pieces
			local px, pz = x, 0
			for j = 1, pieces do
				local nx, nz = x + offsets[j], -j * step
				if j == pieces then
					nx = x
				end
				local dx, dz = nx - px, nz - pz
				local len = math.sqrt(dx * dx + dz * dz)
				local lit = j == ({ 2, 3, 1 })[i]
				local mat = if lit then Enum.Material.Neon else Enum.Material.Foil
				inlay(ctx, lit and "LightningGlow" or "Lightning", S, (px + nx) / 2, (pz + nz) / 2, len + 0.02, 0.026, t, math.deg(math.atan2(-dx, -dz)), look.edge, mat)
				px, pz = nx, nz
			end
		end)
	end,
}

-- 5. Lame Solaire.
STYLES.sun = {
	width = 0.28,
	carry = "hip",
	sheath = "saya",
	handle = Vector3.new(0.3, 0.24, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		tsuka(ctx, 1.5, look.grip, look.hilt, look.accent)
		local z = -0.68
		disc(ctx, "Tsuba", 0.58, 0.08, CFrame.new(0, 0, z), look.guard, Enum.Material.Metal)
		for i = 0, 7 do
			local frame = CFrame.new(0, 0, z) * CFrame.Angles(0, 0, math.rad(i * 45)) * CFrame.new(0.2, 0, 0)
			local long = i % 2 == 0
			tri(ctx, "TsubaFlame", long and 0.32 or 0.22, 0.17, 0.07, frame, long and look.accent or rgb(230, 70, 30), Enum.Material.Metal)
		end
		ctx.bladeStart = habakiSeppa(ctx, z, 0.08, look.width, 0.08, look.accent)
	end,
	blade = function(ctx)
		local look = ctx.look
		local t = 0.08
		katanaBlade(ctx, ctx.bladeStart, look.length, look.width, t, look.curve or 2.2, function(i, S, segLen, w)
			-- Flammes qui lèchent la lame depuis le tranchant.
			local x = -w / 2 + w * 0.3
			local count = i == 3 and 1 or 2
			for j = 1, count do
				local z = -segLen * (j - 0.5) / 2
				tri(ctx, "Flame", w * 0.42, 0.52, t + 0.014, S * BP(x, z + 0.2), look.bevel, Enum.Material.Foil)
				tri(ctx, "Flame", w * 0.26, -0.16, t + 0.012, S * BP(x, z + 0.2), look.edge, Enum.Material.Foil)
			end
			if i == 1 then
				-- Inscription gravée (« Détruis tous les démons »).
				for j = 0, 3 do
					inlay(ctx, "Kanji", S, w * 0.18, -0.25 - j * 0.16, 0.09, 0.045, t, j % 2 == 0 and 0 or 90, rgb(40, 10, 8), Enum.Material.SmoothPlastic)
				end
			end
		end)
	end,
}

-- 6. Couperet de la Brume : trou rond au bout, encoche au dos.
STYLES.mist = {
	width = 1.3,
	carry = "back",
	sheath = "none",
	handle = Vector3.new(0.26, 0.26, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		block(ctx, "HandleEnd", Vector3.new(0.26, 0.26, 0.62), CFrame.new(0, 0, 0.85), look.grip, Enum.Material.Wood)
		for i = 1, 6 do
			local z = GRIP_FRONT + 0.12 + (i - 1) * 0.27
			block(ctx, "Bandage", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(i % 2 == 0 and 18 or -18), 0), look.hilt, Enum.Material.Fabric)
		end
		disc(ctx, "ButtCap", 0.32, 0.14, CFrame.new(0, 0, 1.2), look.guard, Enum.Material.Metal)
		disc(ctx, "ButtRing", 0.28, 0.06, CFrame.new(0, 0, 1.33), look.accent, Enum.Material.Metal)
		disc(ctx, "Collar", 0.36, 0.12, CFrame.new(0, 0, -0.6), look.guard, Enum.Material.Metal)
		ctx.back = 1.38
		ctx.bladeStart = -0.66
	end,
	blade = function(ctx)
		local look = ctx.look
		local s, L, w, t = -0.66, look.length, look.width, 0.12
		local m = Enum.Material.Metal
		local bevelW = 0.24
		local left = -w / 2 + bevelW -- bord du plat côté tranchant
		local right = w / 2
		local function slab(name: string, x0: number, x1: number, z0: number, z1: number)
			block(ctx, name, Vector3.new(x1 - x0, t, z0 - z1), CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2), look.blade, m)
		end
		block(ctx, "Socket", Vector3.new(0.34, t + 0.08, 0.24), CFrame.new(0, 0, s + 0.02), look.guard, m)
		-- A : base avec l'encoche demi-ronde au dos.
		local notch = 0.3
		slab("Blade", left, right - notch, s, s - 0.7)
		tri(ctx, "NotchRound", notch * 0.55, -0.22, t, BP(right - notch, s - 0.7), look.blade, m)
		tri(ctx, "NotchRound", notch * 0.55, 0.22, t, BP(right - notch, s), look.blade, m)
		-- B : corps.
		local holeZ = s - (L - 0.72)
		local r = 0.29
		local hx = right - 0.5
		slab("Blade", left, right, s - 0.7, holeZ + r + 0.2)
		-- C : autour du trou (octogonal).
		slab("Blade", left, hx - r, holeZ + r + 0.2, holeZ - r - 0.2)
		slab("Blade", hx + r, right, holeZ + r + 0.2, holeZ - r - 0.2)
		slab("Blade", hx - r, hx + r, holeZ + r + 0.2, holeZ + r)
		slab("Blade", hx - r, hx + r, holeZ - r, holeZ - r - 0.2)
		local c = r * 0.55
		tri(ctx, "HoleCorner", c, c, t, BP(hx - r, holeZ + r), look.blade, m)
		tri(ctx, "HoleCorner", -c, c, t, BP(hx + r, holeZ + r), look.blade, m)
		tri(ctx, "HoleCorner", c, -c, t, BP(hx - r, holeZ - r), look.blade, m)
		tri(ctx, "HoleCorner", -c, -c, t, BP(hx + r, holeZ - r), look.blade, m)
		-- D : bout, légèrement biseauté côté dos.
		local tipZ = s - L
		slab("Blade", left, right - 0.12, holeZ - r - 0.2, tipZ)
		tri(ctx, "EndCorner", 0.12, 0.16, t, BP(right - 0.12, tipZ + 0.16), look.blade, m)
		block(ctx, "EndCornerFill", Vector3.new(0.12, t, holeZ - r - 0.2 - (tipZ + 0.16) + 0.01), CFrame.new(right - 0.06, 0, (holeZ - r - 0.2 + tipZ + 0.16) / 2), look.blade, m)
		-- Tranchant (biseaux) sur toute la longueur et dos renforcé.
		for _, up in { 1, -1 } do
			tri(ctx, "Bevel", -bevelW, up * t / 2, L, CFrame.new(left, 0, s - L / 2), look.bevel, m)
		end
		-- Ligne de trempe le long du tranchant et rivets de la soie.
		block(ctx, "TemperLine", Vector3.new(0.03, t + 0.012, L - 0.3), CFrame.new(left + 0.015, 0, s - L / 2 - 0.1), look.accent, m)
		for _, x in { -0.09, 0.09 } do
			orb(ctx, "Rivet", Vector3.new(0.08, t + 0.12, 0.08), CFrame.new(x, 0, s - 0.03), look.bevel, m)
		end
		block(ctx, "Spine", Vector3.new(0.09, t + 0.035, L - 0.85), CFrame.new(right - 0.045, 0, s - 0.7 - (L - 0.85) / 2 + 0.01), look.accent, m)
		ctx.tip = Vector3.new(0, 0, tipZ)
	end,
}

-- 7. Lame des Abysses : obsidienne dentelée, œil démoniaque, chaîne.
STYLES.abyss = {
	width = 0.5,
	carry = "hip",
	sheath = "scabbard",
	handle = Vector3.new(0.27, 0.25, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		for i, z in { -0.3, 0.02, 0.32 } do
			block(ctx, "Binding", Vector3.new(0.3, 0.28, 0.035), CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(i % 2 == 0 and 22 or -22), 0), look.hilt, Enum.Material.Neon)
		end
		local z = -0.68
		block(ctx, "GuardCore", Vector3.new(0.4, 0.3, 0.28), CFrame.new(0, 0, z), look.guard, Enum.Material.Metal)
		orb(ctx, "Eye", Vector3.new(0.3, 0.42, 0.2), CFrame.new(0, 0, z), look.accent, Enum.Material.Neon)
		block(ctx, "Pupil", Vector3.new(0.05, 0.44, 0.15), CFrame.new(0, 0, z), rgb(10, 4, 14), Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			local h1 = CFrame.new(side * 0.2, 0, z) * CFrame.Angles(0, math.rad(side * 18), 0) * CFrame.new(side * 0.16, 0, 0)
			block(ctx, "Horn", Vector3.new(0.34, 0.16, 0.16), h1, look.guard, Enum.Material.Metal)
			local h2 = h1 * CFrame.new(side * 0.16, 0, 0) * CFrame.Angles(0, math.rad(side * 38), 0) * CFrame.new(side * 0.13, 0, 0)
			block(ctx, "Horn", Vector3.new(0.28, 0.13, 0.13), h2, look.guard, Enum.Material.Metal)
			local h3 = h2 * CFrame.new(side * 0.14, 0, 0) * CFrame.Angles(0, math.rad(side * 40), 0)
			tri(ctx, "HornTip", side * 0.26, 0.065, 0.11, h3 * CFrame.fromMatrix(Vector3.zero, X_AXIS, -Z_AXIS, Y_AXIS), look.accent, Enum.Material.Neon)
			tri(ctx, "HornTip", side * 0.26, -0.065, 0.11, h3 * CFrame.fromMatrix(Vector3.zero, X_AXIS, -Z_AXIS, Y_AXIS), look.accent, Enum.Material.Neon)
		end
		orb(ctx, "Pommel", Vector3.new(0.3, 0.3, 0.28), CFrame.new(0, 0, 0.68), look.guard, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			tri(ctx, "PommelSpike", side * 0.1, 0.3, 0.12, PP(0, 0.76), look.guard, Enum.Material.Metal)
		end
		-- Chaîne qui pend du pommeau.
		local cf = CFrame.new(0.12, 0, 0.82) * CFrame.Angles(0, math.rad(30), 0)
		for i = 1, 4 do
			local link = cf * CFrame.new(0, 0, 0.09) * CFrame.Angles(0, 0, i % 2 == 0 and math.rad(90) or 0)
			block(ctx, "ChainLink", Vector3.new(0.09, 0.035, 0.17), link, rgb(120, 116, 130), Enum.Material.Metal)
			cf = cf * CFrame.new(0, 0, 0.15) * CFrame.Angles(0, math.rad(12), 0)
		end
		orb(ctx, "ChainGem", Vector3.new(0.12, 0.12, 0.16), cf * CFrame.new(0, 0, 0.1), look.accent, Enum.Material.Neon)
		ctx.back = 1.5
		ctx.bladeStart = -0.82
	end,
	blade = function(ctx)
		local look = ctx.look
		local start, w, t = -0.82, look.width, 0.1
		local L = look.length
		ctx.bladeStart = start
		local endZ = straightBlade(ctx, start, L, w, t, 0.7)
		local m = Enum.Material.Metal
		-- Dents en crochet sur les deux tranchants.
		for i = 1, 4 do
			local z = start - 0.45 - (i - 1) * (start - endZ - 0.6) / 3.4
			tri(ctx, "Tooth", -0.15, 0.27, t, BP(-w / 2 + 0.01, z), look.bevel, m)
			tri(ctx, "Tooth", 0.15, 0.27, t, BP(w / 2 - 0.01, z - 0.2), look.bevel, m)
		end
		local S = CFrame.new(0, 0, start)
		local span = start - endZ
		inlay(ctx, "Vein", S, 0, -span * 0.5 - 0.05, span * 0.9, 0.035, t, 0, look.edge, Enum.Material.Foil)
		for j = 1, 3 do
			-- Runes gravées ; seule celle du milieu luit.
			local z = -0.5 - (j - 1) * span * 0.28
			local mat = if j == 2 then Enum.Material.Neon else Enum.Material.Foil
			inlay(ctx, "Rune", S, 0, z, 0.2, 0.03, t + 0.004, 45, look.edge, mat)
			inlay(ctx, "Rune", S, 0, z, 0.2, 0.03, t + 0.004, -45, look.edge, mat)
		end
	end,
}

-- 8. Épée Céleste : ailes d'or, gemme, auréole, lame de cristal.
STYLES.celestial = {
	width = 0.45,
	carry = "hip",
	sheath = "scabbard",
	handle = Vector3.new(0.27, 0.25, 1.1),
	hilt = function(ctx)
		local look = ctx.look
		local gold = look.accent
		for _, z in { -0.36, 0, 0.36 } do
			disc(ctx, "Wire", 0.31, 0.05, CFrame.new(0, 0, z), gold, Enum.Material.Foil)
		end
		-- Pommeau étoile.
		block(ctx, "PommelStar", Vector3.new(0.3, 0.13, 0.3), CFrame.new(0, 0, 0.76), gold, Enum.Material.Foil)
		block(ctx, "PommelStar", Vector3.new(0.3, 0.13, 0.3), CFrame.new(0, 0, 0.76) * CFrame.Angles(0, math.rad(45), 0), gold, Enum.Material.Foil)
		orb(ctx, "PommelGem", Vector3.new(0.14, 0.2, 0.14), CFrame.new(0, 0, 0.76), look.gem, Enum.Material.Neon)
		-- Garde lisible en trois plans : la gemme (la « tête ») devant, l'auréole fine juste au-dessus
		-- et derrière elle, les deux ailes nettement en dessous.
		local z = -0.68
		block(ctx, "GemFrame", Vector3.new(0.28, 0.22, 0.28), CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(45), 0), gold, Enum.Material.Foil)
		orb(ctx, "Gem", Vector3.new(0.22, 0.3, 0.27), CFrame.new(0, 0, z), look.gem, Enum.Material.Neon)
		-- Ailes : trois plumes blanches en éventail par côté, bordées d'or, inclinées vers le pommeau.
		local feathers = { { 0.66, 8 }, { 0.54, 30 }, { 0.4, 52 } }
		for _, side in { -1, 1 } do
			for i, spec in feathers do
				local len, angle = spec[1], spec[2]
				local d = 0.05 + i * 0.012
				local frame = BP(side * 0.12, z + 0.08) * CFrame.Angles(0, 0, math.rad(-side * angle))
				tri(ctx, "Feather", side * len, 0.13, d, frame, rgb(250, 248, 240), Enum.Material.Foil)
				block(ctx, "FeatherEdge", Vector3.new(len * 0.94, 0.028, d + 0.012), frame * CFrame.new(side * len * 0.47, 0.014, 0), gold, Enum.Material.Foil)
			end
		end
		-- Auréole : un seul anneau fin (8 segments), doré mat, au-dessus de la gemme et derrière elle.
		local segs = 8
		local radius = 0.3
		local hz = z - 0.17
		for i = 0, segs - 1 do
			local a = (i + 0.5) / segs * math.pi * 2
			block(
				ctx,
				"Halo",
				Vector3.new(0.04, 0.11, 2 * radius * math.sin(math.pi / segs) + 0.015),
				CFrame.new(math.cos(a) * radius, 0, hz + math.sin(a) * radius) * CFrame.Angles(0, -a, 0),
				gold,
				Enum.Material.SmoothPlastic,
				{ Reflectance = 0.1 }
			)
		end
		-- Ruban bleu noué sous la garde.
		orb(ctx, "RibbonKnot", Vector3.new(0.18, 0.2, 0.12), CFrame.new(0.1, 0, -0.42), look.gem, Enum.Material.Fabric)
		block(ctx, "Ribbon", Vector3.new(0.09, 0.016, 0.5), CFrame.new(0.2, 0, -0.2) * CFrame.Angles(0, math.rad(25), 0), look.gem, Enum.Material.Fabric)
		block(ctx, "Ribbon", Vector3.new(0.09, 0.016, 0.42), CFrame.new(0.08, 0, -0.18) * CFrame.Angles(0, math.rad(-8), 0), look.gem, Enum.Material.Fabric)
		ctx.back = 0.92
		ctx.bladeStart = -0.84
	end,
	blade = function(ctx)
		local look = ctx.look
		local start, w, t = -0.84, look.width, 0.09
		local L = look.length
		ctx.bladeStart = start
		local endZ = straightBlade(ctx, start, L, w, t, 0.62)
		local S = CFrame.new(0, 0, start)
		local span = start - endZ
		inlay(ctx, "LightChannel", S, 0, -span * 0.46 - 0.12, span * 0.82, 0.085, t - 0.002, 0, look.edge, Enum.Material.Foil)
		for j = 1, 3 do
			local z = -0.55 - (j - 1) * span * 0.3
			block(ctx, "StarInlay", Vector3.new(0.09, t + 0.02, 0.09), S * CFrame.new(0, 0, z), look.accent, Enum.Material.Foil)
			block(ctx, "StarInlay", Vector3.new(0.09, t + 0.02, 0.09), S * CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(45), 0), look.accent, Enum.Material.Foil)
			if j < 3 then
				-- Courte gravure lumineuse entre deux étoiles.
				inlay(ctx, "LightGlow", S, 0, z - span * 0.15, span * 0.12, 0.03, t + 0.004, 0, WHITE)
			end
		end
		for _, side in { -1, 1 } do
			block(ctx, "EdgeLine", Vector3.new(0.02, 0.026, span), S * CFrame.new(side * (w / 2 - 0.01), 0, -span / 2), look.edge, Enum.Material.Foil)
			tri(ctx, "Ricasso", side * 0.14, 0.32, t + 0.03, BP(side * w / 2 - side * 0.02, start), look.accent, Enum.Material.Foil)
		end
	end,
}

STYLES.classic = STYLES.steel

------------------------------------------------------------------------
-- Fourreaux (épée rangée)
------------------------------------------------------------------------

-- Fourreau qui suit la lame. Les katanas ont une saya laquée courbée, les épées droites un
-- fourreau de cuir avec bouterolle.
local function buildScabbard(ctx: Ctx, style: Style)
	local look = ctx.look
	local start = ctx.bladeStart
	local length = look.length + 0.05
	local w = look.width
	local color = look.sheath or rgb(60, 40, 30)
	local trim = look.accent or GOLD
	if style.sheath == "saya" then
		local curve = look.curve or 2.5
		local seg = length / 3
		local S = CFrame.new(0, 0, start)
		block(ctx, "Koiguchi", Vector3.new(w + 0.17, 0.25, 0.14), S * CFrame.new(0.01, 0, -0.07), rgb(230, 225, 210), Enum.Material.SmoothPlastic)
		for i = 1, 3 do
			local ww = w * (1 - 0.05 * (i - 1)) + 0.12
			block(ctx, "Saya", Vector3.new(ww, 0.2, seg + 0.03), S * CFrame.new(0.01, 0, -seg / 2), color, Enum.Material.SmoothPlastic, { Reflectance = 0.08 })
			if i == 1 then
				block(ctx, "Kurikata", Vector3.new(0.1, 0.12, 0.16), S * CFrame.new(w / 2 + 0.08, 0, -0.45), color, Enum.Material.SmoothPlastic)
				for _, sign in { 1, -1 } do
					block(
						ctx,
						"SageoWrap",
						Vector3.new(ww + 0.03, 0.22, 0.05),
						S * CFrame.new(0.01, 0, -0.62 - (sign + 1) * 0.06) * CFrame.Angles(0, math.rad(25 * sign), 0),
						look.hilt,
						Enum.Material.Fabric
					)
				end
			end
			S = S * CFrame.new(0, 0, -seg) * CFrame.Angles(0, -math.rad(curve), 0)
		end
		block(ctx, "Kojiri", Vector3.new(w * 0.9 + 0.12, 0.22, 0.14), S * CFrame.new(0.01, 0, -0.05), trim, Enum.Material.Metal)
		ctx.tip = (S * CFrame.new(0, 0, -0.12)).Position
	elseif style.sheath == "scabbard" then
		local ww = w + 0.1
		local body = length - 0.45
		block(ctx, "Locket", Vector3.new(ww + 0.06, 0.2, 0.3), CFrame.new(0, 0, start - 0.15), trim, Enum.Material.Metal)
		block(ctx, "Scabbard", Vector3.new(ww, 0.16, body), CFrame.new(0, 0, start - body / 2), color, Enum.Material.Fabric)
		block(ctx, "ScabbardBand", Vector3.new(ww + 0.04, 0.19, 0.12), CFrame.new(0, 0, start - body * 0.45), trim, Enum.Material.Metal)
		local chapeZ = start - body
		for _, side in { -1, 1 } do
			tri(ctx, "Chape", side * (ww + 0.06) / 2, 0.45, 0.2, BP(0, chapeZ + 0.02), trim, Enum.Material.Metal)
		end
		ctx.tip = Vector3.new(0, 0, chapeZ - 0.45)
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

local function styleOf(sword): Style
	return STYLES[sword.look.style] or STYLES.steel
end

local function powerOf(sword, level: number?): number
	local count = 8
	local index = sword.index or 1
	local k = math.clamp((index - 1) / (count - 1), 0, 1)
	if level and level > 1 then
		k = math.clamp(k + (level - 1) * 0.1, 0, 1.3)
	end
	return k
end

local function newHandle(sword, style: Style): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = style.handle
	handle.Color = sword.look.grip or sword.look.hilt
	handle.Material = style.sheath == "saya" and Enum.Material.SmoothPlastic or Enum.Material.Fabric
	if sword.look.style == "mist" then
		handle.Material = Enum.Material.Wood
	end
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	return handle
end

-- Outil à donner au joueur (va dans son sac à dos). `level` (facultatif) renforce l'effet.
function SwordBuilder.buildTool(sword, level: number?): Tool
	local style = styleOf(sword)
	local tool = Instance.new("Tool")
	tool.Name = sword.name
	tool.ToolTip = sword.name .. " · " .. sword.damage .. " dégâts"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- Lame de chant : tranchant vers le bas, plat vers les côtés.
	tool.Grip = SwordBuilder.GRIP
	local handle = newHandle(sword, style)
	handle.Parent = tool
	local ctx = newCtx(tool, handle, sword, powerOf(sword, level))
	style.hilt(ctx)
	style.blade(ctx)
	local vol = auraVolume(ctx, style.width, 0.1)
	local effect = EFFECTS[sword.look.style]
	if effect then
		effect(ctx, vol, ctx.k)
	end
	local burst = BURSTS[sword.look.style]
	if burst then
		local spec = table.clone(burst)
		spec.name = "SwingBurst"
		spec.enabled = false
		emitter(vol, spec)
	end
	swingTrails(ctx, handle)
	tool:SetAttribute("SwordId", sword.id)
	tool:SetAttribute("SwordTip", ctx.tip.Z)
	tool:SetAttribute("SwordBack", ctx.back)
	tool:SetAttribute("SwordParts", ctx.count)
	local equip = Instance.new("Sound")
	equip.Name = "Unsheath"
	equip.SoundId = "rbxasset://sounds/unsheath.wav"
	equip.Volume = 0.5
	equip.Parent = handle
	local slash = Instance.new("Sound")
	slash.Name = "Slash"
	slash.SoundId = "rbxasset://sounds/swordslash.wav"
	slash.Volume = 0.6
	slash.Parent = handle
	return tool
end

-- Modèle ancré pour l'aperçu dans le menu du Forgeron (lame vers le haut, poignée en bas).
-- Attributs Top / Bottom : hauteur de la pointe et du pommeau (pour cadrer la caméra).
function SwordBuilder.buildModel(sword): Model
	local tool = SwordBuilder.buildTool(sword)
	local model = Instance.new("Model")
	model.Name = sword.name
	for _, child in tool:GetChildren() do
		child.Parent = model
	end
	local top = -(tool:GetAttribute("SwordTip") or -4)
	local bottom = -(tool:GetAttribute("SwordBack") or 0.6)
	tool:Destroy()
	local handle = model:FindFirstChild("Handle") :: BasePart
	model.PrimaryPart = handle
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		elseif descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(math.rad(90), 0, 0))
	model:SetAttribute("Top", top)
	model:SetAttribute("Bottom", bottom)
	return model
end

-- Hauteurs de la pointe et du pommeau d'une épée (repère du modèle d'aperçu).
function SwordBuilder.span(sword): (number, number)
	local model = SwordBuilder.buildModel(sword)
	local top, bottom = model:GetAttribute("Top"), model:GetAttribute("Bottom")
	model:Destroy()
	return top, bottom
end

-- Épée rangée : poignée + fourreau (katanas et épées droites, à la hanche) ou épée entière dans
-- le dos (Couperet). Les pièces de la poignée portent l'attribut "Hilt" (cachées quand l'épée
-- est en main), le reste est le fourreau.
function SwordBuilder.buildSheath(sword): Model
	local style = styleOf(sword)
	local model = Instance.new("Model")
	model.Name = "SwordSheath"
	local handle = newHandle(sword, style)
	handle.Parent = model
	local ctx = newCtx(model, handle, sword, 0)
	style.hilt(ctx)
	handle:SetAttribute("Hilt", true)
	for _, p in ctx.parts do
		p:SetAttribute("Hilt", true)
	end
	if style.sheath == "none" then
		style.blade(ctx)
		for _, p in ctx.parts do
			p:SetAttribute("Hilt", true)
		end
	else
		local mouth = ctx.bladeStart
		buildScabbard(ctx, style)
		model:SetAttribute("MouthZ", mouth)
		model:SetAttribute("TipZ", ctx.tip.Z)
	end
	model.PrimaryPart = handle
	model:SetAttribute("SwordId", sword.id)
	model:SetAttribute("Carry", style.carry)
	return model
end

-- Montre ou cache la poignée rangée (cachée quand l'épée est en main).
function SwordBuilder.setDrawn(sheath: Model, drawn: boolean)
	for _, p in sheath:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Hilt") then
			p.Transparency = drawn and 1 or 0
		end
	end
end

-- Port à la hanche (repère du torse R6 : centre du torse, x vers la droite du perso, -z devant).
-- Positions calculées pour ne toucher ni le torse, ni le bras gauche, ni la jambe gauche au repos,
-- et pour rester presque hors d'eux pendant le balancement de la marche : l'embouchure du fourreau
-- est sous le bras (y < -1) et à gauche de la jambe (x < -1), la poignée sort en avant et vers le
-- haut, le fourreau descend vers l'arrière le long de la cuisse.
--   mouth : embouchure du fourreau · pitch : inclinaison maximale (degrés, poignée vers le haut)
--   yaw : pommeau tourné vers le ventre (degrés) · roll : rotation sur l'axe de la lame (degrés)
local HIP_CARRY = {
	-- Katanas : tranchant vers le haut, tourné de 40° vers le corps (port traditionnel).
	saya = { mouth = Vector3.new(-1.3, -1.2, -0.9), pitch = 20, yaw = 4, roll = 40 },
	-- Épées droites : fourreau de cuir pendu à plat contre la cuisse, garde à l'horizontale.
	scabbard = { mouth = Vector3.new(-1.4, -1.0, -1.0), pitch = 22, yaw = 0, roll = 90 },
}
SwordBuilder.HIP_CARRY = HIP_CARRY

-- Repère de la poignée (dans le repère du torse) pour une épée rangée à la hanche.
local function hipFrame(carry, mouth: Vector3, floorY: number, mouthZ: number, length: number): CFrame
	-- La pointe reste au-dessus du sol : on réduit l'inclinaison pour les longues lames.
	local room = mouth.Y - floorY - 0.6
	local pitch = math.clamp(math.asin(math.clamp(room / length, 0, 1)), math.rad(12), math.rad(carry.pitch))
	local yaw = math.rad(carry.yaw)
	local toPommel = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	local up = Vector3.new(0, 1, 0)
	-- Dos de la lame (+X de la poignée) vers le bas, puis tourné vers l'extérieur de `roll`.
	local spine = -(up - toPommel * up:Dot(toPommel)).Unit
	local side = toPommel:Cross(spine)
	local r = math.rad(carry.roll)
	local spineRolled = spine * math.cos(r) + side * math.sin(r)
	if spineRolled.X > spine.X then
		spineRolled = spine * math.cos(r) - side * math.sin(r)
	end
	local sideRolled = toPommel:Cross(spineRolled)
	return CFrame.fromMatrix(mouth - toPommel * mouthZ, spineRolled, sideRolled, toPommel)
end

-- Accroche le fourreau au perso et le soude.
--   Hanche : voir HIP_CARRY (katana tranchant en haut, épées droites à plat contre la cuisse).
--   Dos : le Couperet entier, en diagonale, plat contre le dos.
function SwordBuilder.attachSheath(sheath: Model, character: Model, sword, drawn: boolean?): boolean
	local style = styleOf(sword)
	local handle = sheath.PrimaryPart
	-- R6 (Torso), R15 (LowerTorso / UpperTorso), sinon la racine du perso (même gabarit que le Torso R6).
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = (character:FindFirstChild("Torso") or character:FindFirstChild("LowerTorso") or root) :: BasePart?
	local upper = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or root) :: BasePart?
	if not handle or not torso or not upper then
		return false
	end
	local r6 = torso.Name ~= "LowerTorso"
	local target: CFrame
	local anchor: BasePart
	if style.carry == "back" then
		anchor = upper
		-- Diagonale à 40°, centrée sur le dos : la poignée dépasse au-dessus de l'épaule droite,
		-- la pointe reste au-dessus du sol (le Couperet est plus long que le perso n'est haut).
		local c, s = math.cos(math.rad(40)), math.sin(math.rad(40))
		local back = CFrame.fromMatrix(Vector3.zero, Vector3.new(-s, c, 0), Z_AXIS, Vector3.new(c, s, 0))
		local half = (0.75 + sword.look.length - 1.2) / 2
		target = upper.CFrame * CFrame.new(0, r6 and 0.1 or 0.5, upper.Size.Z / 2 + 0.12) * back * CFrame.new(0, 0, half)
	else
		anchor = torso
		local mouthZ = sheath:GetAttribute("MouthZ") or -0.75
		local tipZ = sheath:GetAttribute("TipZ") or (mouthZ - sword.look.length)
		local length = math.max(mouthZ - tipZ, 1)
		local carry = HIP_CARRY[style.sheath] or HIP_CARRY.scabbard
		local mouth, floorY = carry.mouth, -3
		if not r6 then
			-- R15 : le LowerTorso est centré environ 0,8 plus bas que le Torso R6.
			mouth += Vector3.new(0, 0.8, 0)
			floorY = -2.2
		end
		target = torso.CFrame * hipFrame(carry, mouth, floorY, mouthZ, length)
	end
	local delta = target * handle.CFrame:Inverse()
	for _, p in sheath:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = delta * p.CFrame
			p.Anchored = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "SheathWeld"
	weld.Part0 = anchor
	weld.Part1 = handle
	weld.Parent = handle
	SwordBuilder.setDrawn(sheath, drawn == true)
	return true
end

return SwordBuilder
