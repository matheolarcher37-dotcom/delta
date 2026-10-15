-- Apparence des MUTATIONS sur un modèle de perso déjà construit (serveur ou aperçu).
--
-- L'apparence PRINCIPALE vient de CharacterBuilder.applyVariety (partie PERSOS) quand elle
-- existe : voile et motifs sur la tenue, cheveux, matières, auréole, ailes, particules. Ce
-- module ne complète que ce qu'elle n'a pas posé (jamais de double voile ni de double
-- particules). Sans applyVariety, il pose tout lui-même (repli) :
--   • voile coloré sur les habits peints (pas sur la tête : le visage reste lisible), avec un
--     reflet pour Or / Diamant / Galaxie / Angélique / Arc-en-ciel et un motif sur le torse
--     (étoiles, pétales, reflet de cristal) ;
--   • cheveux, accessoires et pièces de la tenue teintés (matières Foil, Glass, Ice...) ;
--   • auréole (Angélique) ; particules légères (pétales, scintillements, fumée d'ombre...).
-- En repli, CHAQUE mutation a en plus un signe bien à elle, visible même immobile et de loin :
--   Or : étincelles dorées + reflet qui balaie la tenue (animé côté client) ;
--   Foudre : éclairs Neon cyan sur les bras et le torse + arc électrique entre les mains ;
--   Givre : cristaux de glace (CornerWedge) sur les épaules et les avant-bras ;
--   Diamant : facettes taillées sur toute la tenue, verre ;
--   Angélique : auréole Neon + ailes blanches ;
--   Ombre : volutes de fumée sombre autour du corps ;
--   Néant : disque du vide sous les pieds, fissures violettes, particules noires ASPIRÉES ;
--   Flamme : flammes peintes qui montent des jambes ; Sakura : pétales ; Galaxie : étoiles.
-- Contour lumineux (Highlight) des mutations x3 et plus : posé CÔTÉ CLIENT seulement sur les
-- persos proches de la caméra (Roblox n'affiche que 31 Highlight à la fois) : startClient().
-- Les effets « historiques » (éclairs, givre, flammes, cubes du Néant, paillettes d'or,
-- arc-en-ciel) sont joués en plus côté client (Controllers/AuraController).
--
-- Réglages de chaque mutation : Config/Mutations.luau (champ `look`).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent
local MutationConfig = require(Shared.Config.Mutations)
local CharacterBuilder = require(script.Parent.CharacterBuilder)

local MutationsFx = {}

local BODY = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	HumanoidRootPart = true,
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

local function isHair(part: BasePart): boolean
	local n = part.Name
	return string.sub(n, 1, 4) == "Hair" or n == "Bun" or n == "BunShine" or n == "Knot" or n == "Cranium"
end

-- Voile coloré au-dessus de tout ce qui est peint sur une face.
local function veil(gui: SurfaceGui, look, alpha: number)
	if gui:FindFirstChild("MutationVoile") then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "MutationVoile"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.ZIndex = 1000
	frame.BackgroundColor3 = look.rainbowTint and Color3.new(1, 1, 1) or (look.tint or Color3.new(1, 1, 1))
	frame.BackgroundTransparency = 1 - alpha
	frame.Active = false
	if look.veil then
		-- Voile en dégradé vertical (flammes, éclairs, givre...).
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = colorSequence(look.veil)
		gradient.Parent = frame
	elseif look.rainbowTint or look.shine then
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 35
		if look.rainbowTint then
			gradient.Color = RAINBOW
		else
			-- reflet qui balaie la tenue : animé côté client (startClient)
			CollectionService:AddTag(gradient, "MutationShine")
			local tint = look.tint or Color3.new(1, 1, 1)
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, tint),
				ColorSequenceKeypoint.new(0.42, tint),
				ColorSequenceKeypoint.new(0.5, tint:Lerp(Color3.new(1, 1, 1), 0.75)),
				ColorSequenceKeypoint.new(0.58, tint),
				ColorSequenceKeypoint.new(1, tint:Lerp(Color3.new(0, 0, 0), 0.25)),
			})
		end
		gradient.Parent = frame
	end
	frame.Parent = gui
end

-- Motifs peints sur la tenue (étoiles, pétales, reflet, facettes, flammes, fissures), sous forme
-- de pastilles et de losanges au-dessus du voile.
local function motif(gui: SurfaceGui, kind: string, part: string)
	local function dot(x: number, y: number, w: number, h: number, color: Color3, transparency: number, rotation: number?, square: boolean?)
		local f = Instance.new("Frame")
		f.Name = "MutationMotif"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.ZIndex = 1001
		if not square then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = f
		end
		f.Parent = gui
		return f
	end
	local torso = part == "Torso"
	if kind == "stars" then
		for _, st in { { 0.15, 0.2, 0.05 }, { 0.72, 0.14, 0.035 }, { 0.42, 0.42, 0.03 }, { 0.85, 0.55, 0.045 }, { 0.25, 0.7, 0.035 }, { 0.6, 0.82, 0.05 } } do
			dot(st[1], st[2], st[3], st[3] * 0.9, Color3.new(1, 1, 1), 0.05)
		end
		for _, at in { { 0.32, 0.3 }, { 0.75, 0.68 } } do
			dot(at[1], at[2], 0.12, 0.02, Color3.fromRGB(230, 220, 255), 0.1)
			dot(at[1], at[2], 0.02, 0.12, Color3.fromRGB(230, 220, 255), 0.1)
		end
	elseif kind == "petals" then
		for _, at in { { 0.18, 0.18, 30 }, { 0.7, 0.28, -20 }, { 0.4, 0.55, 60 }, { 0.82, 0.72, 15 }, { 0.22, 0.82, -40 } } do
			dot(at[1], at[2], 0.15, 0.085, Color3.fromRGB(255, 196, 220), 0.08, at[3])
			dot(at[1] + 0.02, at[2] - 0.005, 0.06, 0.03, Color3.fromRGB(255, 240, 246), 0.2, at[3])
		end
	elseif kind == "glint" then
		dot(0.35, 0.45, 0.16, 1.4, Color3.new(1, 1, 1), 0.7, 30)
		dot(0.6, 0.5, 0.05, 1.4, Color3.new(1, 1, 1), 0.76, 30)
	elseif kind == "facets" then
		-- pierre taillée : losanges clairs et foncés en quinconce + grand reflet
		local rows = torso and 4 or 5
		local cols = torso and 4 or 2
		for r = 0, rows - 1 do
			for c = 0, cols - 1 do
				local x = (c + 0.5 + (r % 2) * 0.5) / cols
				local y = (r + 0.5) / rows
				local light = (r + c) % 2 == 0
				local size = 0.62 / cols
				dot(
					x,
					y,
					size,
					size * cols / rows * (torso and 1 or 0.55),
					light and Color3.fromRGB(245, 255, 255) or Color3.fromRGB(70, 170, 230),
					light and 0.35 or 0.45,
					45,
					true
				)
			end
		end
		dot(0.3, 0.5, 0.08, 1.5, Color3.new(1, 1, 1), 0.55, 28, true)
	elseif kind == "flames" then
		-- langues de feu qui montent du bas (losanges coupés par le bord bas de la face)
		local tongues = torso and { { 0.12, 0.34 }, { 0.32, 0.5 }, { 0.52, 0.38 }, { 0.72, 0.56 }, { 0.92, 0.36 } } or { { 0.2, 0.55 }, { 0.55, 0.85 }, { 0.88, 0.5 } }
		for _, t in tongues do
			local h = t[2]
			dot(t[1], 1, h * 0.55, h, Color3.fromRGB(255, 70, 10), 0.08, 45, true)
			dot(t[1], 1.02, h * 0.36, h * 0.66, Color3.fromRGB(255, 170, 30), 0.05, 45, true)
			dot(t[1], 1.04, h * 0.2, h * 0.36, Color3.fromRGB(255, 240, 150), 0.05, 45, true)
		end
	elseif kind == "cracks" then
		-- fissures du Néant : zigzags violet vif
		for _, line in { { 0.2, 0.1, 0.35, 0.5, 0.25, 0.9 }, { 0.75, 0.05, 0.6, 0.45, 0.8, 0.8 } } do
			for k = 0, 1 do
				local x0, y0 = line[1 + k * 2], line[2 + k * 2]
				local x1, y1 = line[3 + k * 2], line[4 + k * 2]
				local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
				local angle = math.deg(math.atan2(y1 - y0, x1 - x0))
				dot((x0 + x1) / 2, (y0 + y1) / 2, len, 0.035, Color3.fromRGB(230, 120, 255), 0, angle, true)
			end
		end
	end
end

-- Teinte des cheveux, accessoires et pièces de la tenue (si CharacterBuilder.applyVariety
-- n'existe pas ou n'a rien teint).
local function tintParts(model: Model, look, hairToo: boolean)
	local custom = model:GetAttribute("CustomModel") == true
	local body = look.body
	local i = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not BODY[d.Name] and d.Transparency < 0.9 and d.Name ~= "FacePlate" and not d:FindFirstChildOfClass("SurfaceGui") then
			local hair = isHair(d) or custom
			if hair and hairToo then
				i += 1
				if look.rainbowTint then
					d.Color = Color3.fromHSV((i * 0.13) % 1, 0.55, 1)
				elseif look.hair then
					d.Color = d.Color:Lerp(look.hair, look.mix or 0.5)
					if look.material then
						d.Material = look.material
					end
					if look.reflectance then
						d.Reflectance = look.reflectance
					end
				end
			elseif not hair and body and d.Material ~= Enum.Material.Neon then
				d.Color = d.Color:Lerp(body.color, body.mix or 0.4)
				if body.material then
					d.Material = body.material
				end
				if body.reflectance then
					d.Reflectance = body.reflectance
				end
			end
		end
	end
end

-- Pièce décorative d'une mutation, soudée à `anchor` (rangée dans le modèle « MutationSigne »).
local function signFolder(model: Model): Model
	local folder = model:FindFirstChild("MutationSigne") :: Model?
	if not folder then
		folder = Instance.new("Model")
		folder.Name = "MutationSigne"
		folder.Parent = model
	end
	return folder :: Model
end

local function fxPart(model: Model, anchor: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, kind: string?): BasePart
	local part: BasePart
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	elseif kind == "CornerWedge" then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		if kind == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		part = p
	end
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = anchor.Anchored
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = signFolder(model)
	return part
end

local function limb(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Auréole Neon (anneau de 16 segments) au-dessus des cheveux.
local function halo(model: Model, s: number)
	local head = limb(model, "Head")
	if not head or model:FindFirstChild("MutationAureole", true) then
		return
	end
	local radius = 0.78 * s
	local n = 16
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local part = fxPart(
			model,
			head,
			"MutationAureole",
			Vector3.new(2 * math.pi * radius / n * 1.15, 0.14 * s, 0.2 * s),
			head.CFrame * CFrame.new(math.cos(a) * radius, 2.05 * s, math.sin(a) * radius) * CFrame.Angles(0, -(a + math.pi / 2), 0),
			Color3.fromRGB(255, 226, 120),
			Enum.Material.Neon
		)
		part:SetAttribute("Halo", true)
	end
end

-- Ailes blanches (3 plumes en coin de chaque côté, dans le dos).
local function wings(model: Model, s: number)
	local torso = limb(model, "Torso")
	if not torso then
		return
	end
	for _, side in { -1, 1 } do
		for k, f in { { 2.3, 2.6, 0.55 }, { 2.0, 1.8, -0.15 }, { 1.6, 1.15, -0.7 } } do
			local span, height, y = f[1] * s, f[2] * s, f[3] * s
			fxPart(
				model,
				torso,
				"MutationAile",
				Vector3.new(0.16 * s, height, span),
				torso.CFrame * CFrame.new(side * (0.55 * s + span / 2), y + height / 2 - 0.2 * s, 0.62 * s + k * 0.05 * s) * CFrame.Angles(0, side * math.pi / 2, 0),
				k == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(244, 246, 255),
				Enum.Material.SmoothPlastic,
				"Wedge"
			)
		end
	end
end

-- Éclairs Neon en zigzag sur l'avant des bras et du torse + arc électrique entre les mains.
local function bolts(model: Model, s: number, spec)
	local color = spec.color or Color3.fromRGB(150, 240, 255)
	local function zigzag(anchor: BasePart, points: { Vector2 }, z: number, width: number)
		for i = 1, #points - 1 do
			local p0, p1 = points[i], points[i + 1]
			local mid = (p0 + p1) / 2
			local delta = p1 - p0
			fxPart(
				model,
				anchor,
				"MutationEclair",
				Vector3.new(delta.Magnitude + width * 0.6, width, 0.06 * s),
				anchor.CFrame * CFrame.new(mid.X * s, mid.Y * s, z) * CFrame.Angles(0, 0, math.atan2(delta.Y, delta.X)),
				color,
				Enum.Material.Neon
			)
		end
	end
	for _, name in { "Left Arm", "Right Arm" } do
		local arm = limb(model, name)
		if arm then
			zigzag(arm, { Vector2.new(0.05, 0.95), Vector2.new(-0.25, 0.4), Vector2.new(0.2, 0.05), Vector2.new(-0.2, -0.45), Vector2.new(0.1, -0.9) }, -0.52 * s, 0.13 * s)
		end
	end
	local torso = limb(model, "Torso")
	if torso then
		zigzag(torso, { Vector2.new(-0.55, 0.9), Vector2.new(-0.05, 0.25), Vector2.new(-0.35, 0.1), Vector2.new(0.45, -0.85) }, -0.52 * s, 0.17 * s)
	end
	-- arc électrique (Beam) d'une main à l'autre, derrière le dos
	local left, right = limb(model, "Left Arm"), limb(model, "Right Arm")
	if left and right then
		local a0 = Instance.new("Attachment")
		a0.Name = "MutationArc0"
		a0.Position = Vector3.new(0, -1 * s, 0)
		a0.Parent = left
		local a1 = Instance.new("Attachment")
		a1.Name = "MutationArc1"
		a1.Position = Vector3.new(0, -1 * s, 0)
		a1.Parent = right
		local beam = Instance.new("Beam")
		beam.Name = "MutationArc"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 210), color)
		beam.LightEmission = 1
		beam.Width0 = 0.35 * s
		beam.Width1 = 0.35 * s
		beam.CurveSize0 = 2.4 * s
		beam.CurveSize1 = -2.4 * s
		beam.Segments = 16
		beam.FaceCamera = true
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 1.5 * s
		beam.TextureSpeed = 3
		beam.Parent = left
	end
end

-- Cristaux de glace (CornerWedge) sur les épaules et les avant-bras.
local function crystals(model: Model, s: number, spec)
	local color = spec.color or Color3.fromRGB(225, 248, 255)
	local material = spec.material or Enum.Material.Ice
	for _, name in { "Left Arm", "Right Arm" } do
		local arm = limb(model, name)
		if arm then
			local side = name == "Left Arm" and -1 or 1
			for _, c in
				{
					{ 0.1, 1.05, 0, 0.5, 1.15, 0.2 },
					{ 0.3, 0.95, -0.25, 0.36, 0.8, 0.55 },
					{ -0.15, 0.95, 0.25, 0.32, 0.7, -0.35 },
					{ 0.5, -0.25, 0, 0.3, 0.6, 1.1 },
				}
			do
				fxPart(
					model,
					arm,
					"MutationCristal",
					Vector3.new(c[4], c[5], c[4]) * s,
					arm.CFrame * CFrame.new(side * c[1] * s, c[2] * s + c[5] * s / 2, c[3] * s) * CFrame.Angles(0, side * 0.6, -side * c[6]),
					color,
					material,
					"CornerWedge"
				)
			end
		end
	end
end

-- Volutes de fumée sombre autour du corps (Ombre).
local function wisps(model: Model, s: number)
	local torso = limb(model, "Torso")
	if not torso then
		return
	end
	for i, w in { { -1.3, -2.4, 0.4, 1.3 }, { 1.2, -2.6, 0.2, 1.5 }, { 0.2, -2.9, -0.5, 1.2 }, { -1.5, 0.6, 0.6, 0.9 }, { 1.4, 0.9, 0.5, 0.8 }, { 0, -2.7, 1, 1.4 } } do
		local part = fxPart(
			model,
			torso,
			"MutationFumee",
			Vector3.one * w[4] * s,
			torso.CFrame * CFrame.new(w[1] * s, w[2] * s, w[3] * s),
			i % 2 == 0 and Color3.fromRGB(46, 18, 78) or Color3.fromRGB(14, 6, 24),
			Enum.Material.SmoothPlastic,
			"Ball"
		)
		part.Transparency = 0.3
	end
end

-- Disque du vide sous les pieds (Néant) : noir, liseré violet lumineux.
local function voidDisc(model: Model, s: number)
	local torso = limb(model, "Torso")
	if not torso then
		return
	end
	local floor = torso.CFrame * CFrame.new(0, -3 * s, 0)
	local flat = CFrame.new(floor.Position) * CFrame.Angles(0, 0, math.pi / 2)
	fxPart(model, torso, "MutationVide", Vector3.new(0.06 * s, 5 * s, 5 * s), flat * CFrame.new(0.03 * s, 0, 0), Color3.fromRGB(190, 70, 255), Enum.Material.Neon, "Cylinder")
	fxPart(
		model,
		torso,
		"MutationVide",
		Vector3.new(0.08 * s, 4.4 * s, 4.4 * s),
		flat * CFrame.new(0.07 * s, 0, 0),
		Color3.fromRGB(6, 2, 12),
		Enum.Material.SmoothPlastic,
		"Cylinder"
	)
end

-- Étincelles dorées (étoiles à 4 branches) autour du perso (Or).
local function sparkles(model: Model, s: number, spec)
	local torso = limb(model, "Torso")
	if not torso then
		return
	end
	local color = spec.color or Color3.fromRGB(255, 226, 110)
	for _, at in { { -1.6, 1.6, -0.6, 1 }, { 1.7, 0.9, -0.5, 0.8 }, { -1.5, -0.9, -0.7, 0.65 }, { 1.5, -1.8, -0.6, 0.75 }, { 0.9, 2.9, -0.4, 0.6 } } do
		local cf = torso.CFrame * CFrame.new(at[1] * s, at[2] * s, at[3] * s)
		local len = at[4] * s
		fxPart(model, torso, "MutationEtincelle", Vector3.new(len, 0.1 * s, 0.06 * s), cf, color, Enum.Material.Neon)
		fxPart(model, torso, "MutationEtincelle", Vector3.new(0.1 * s, len, 0.06 * s), cf, color, Enum.Material.Neon)
		fxPart(model, torso, "MutationEtincelle", Vector3.new(len * 0.45, 0.08 * s, 0.05 * s), cf * CFrame.Angles(0, 0, math.pi / 4), Color3.new(1, 1, 1), Enum.Material.Neon)
		fxPart(model, torso, "MutationEtincelle", Vector3.new(len * 0.45, 0.08 * s, 0.05 * s), cf * CFrame.Angles(0, 0, -math.pi / 4), Color3.new(1, 1, 1), Enum.Material.Neon)
	end
end

local function particles(model: Model, spec, scale: number)
	local torso = (model:FindFirstChild("Torso") or model.PrimaryPart) :: BasePart?
	if not torso or torso:FindFirstChild("MutationParticules") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationParticules"
	emitter.Texture = spec.texture
	emitter.Color = colorSequence(spec.color)
	emitter.Rate = spec.rate or 6
	emitter.Lifetime = NumberRange.new((spec.lifetime or 1.2) * 0.7, spec.lifetime or 1.2)
	emitter.Speed = NumberRange.new((spec.speed or 1) * 0.5, spec.speed or 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (spec.size or 0.4) * scale), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.transparency or 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = spec.lightEmission or 0.6
	emitter.Acceleration = spec.acceleration or Vector3.zero
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-(spec.rotSpeed or 0), spec.rotSpeed or 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	if spec.inward then
		-- particules ASPIRÉES vers le torse (Néant) : elles naissent sur une sphère invisible
		-- autour du perso et filent vers son centre
		local vortex = fxPart(model, torso, "MutationVortex", Vector3.one * 6 * scale, torso.CFrame, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, "Ball")
		vortex.Transparency = 1
		emitter.Shape = Enum.ParticleEmitterShape.Sphere
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		pcall(function()
			(emitter :: any).ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		end)
		emitter.SpreadAngle = Vector2.zero
		emitter.Parent = vortex
		return
	end
	emitter.Parent = torso
end

-- Pose la mutation `id` sur le modèle. Renvoie vrai si une mutation connue a été posée.
-- Sans danger si on l'appelle deux fois (rien n'est ajouté en double).
function MutationsFx.apply(model: Model, id: any): boolean
	local mutation = MutationConfig.get(id)
	if not mutation or not model then
		return false
	end
	if model:GetAttribute("Mutation") == mutation.id then
		return true
	end
	model:SetAttribute("Mutation", mutation.id)
	local look = mutation.look or {}
	local scale = model:GetAttribute("BaseScale") or 1
	-- 1) Apparence principale : CharacterBuilder.applyVariety (partie PERSOS) si elle existe.
	local applyVariety = (CharacterBuilder :: any).applyVariety
	local done = false
	if type(applyVariety) == "function" then
		local ok, result = pcall(applyVariety, model, mutation.id)
		done = ok and result == true
	end
	local tinted = done and model:FindFirstChild("VarietyTint", true) ~= nil
	local hasFx = done and model:FindFirstChild("VarietyFx", true) ~= nil
	-- 2) Repli (ou complément quand applyVariety n'a pas teint la tenue) : voile sur les habits
	--    peints SAUF la tête (le visage reste net), motif sur le torse, pièces de la tenue.
	if not tinted then
		local alpha = look.tintAlpha or 0
		local torso = model:FindFirstChild("Torso")
		local motifOn = look.motifOn or "torso" -- "torso", "legs" (jambes + torse) ou "all"
		for _, d in model:GetDescendants() do
			if d:IsA("SurfaceGui") and d.Parent and d.Parent.Name ~= "Head" and d.Name ~= "Face" then
				if alpha > 0 then
					veil(d, look, alpha)
				end
				local partName = d.Parent.Name
				local frontBack = d.Face == Enum.NormalId.Front or d.Face == Enum.NormalId.Back
				local wanted = d.Parent == torso or (motifOn == "all" and BODY[partName]) or (motifOn == "legs" and (partName == "Left Leg" or partName == "Right Leg"))
				if look.motif and wanted and frontBack and not d:FindFirstChild("MutationMotif") then
					motif(d, look.motif, d.Parent == torso and "Torso" or partName)
				end
			end
		end
		tintParts(model, look, not done)
	end
	-- 3) Signe propre à la mutation (repli) : ajouté APRÈS la teinte de la tenue.
	--    Aussi quand applyVariety n'a fait que teinter les cheveux (Foudre, Givre, Néant, Flamme) :
	--    le signe reste le moyen de reconnaître la mutation.
	if (not done or not tinted) and not model:FindFirstChild("MutationSigne") then
		if look.halo then
			halo(model, scale)
		end
		if look.wings then
			wings(model, scale)
		end
		if look.bolts then
			bolts(model, scale, look.bolts)
		end
		if look.crystals then
			crystals(model, scale, look.crystals)
		end
		if look.wisps then
			wisps(model, scale)
		end
		if look.voidDisc then
			voidDisc(model, scale)
		end
		if look.sparkles then
			sparkles(model, scale, look.sparkles)
		end
	end
	-- 4) Particules légères (si applyVariety n'en a pas mis).
	if look.particles and not hasFx then
		particles(model, look.particles, scale)
	end
	-- 5) Contour lumineux des mutations x3 et plus : marqué ici, posé par le CLIENT sur les
	--    persos proches seulement (startClient).
	if (mutation.multiplier or 1) >= MutationsFx.GlowMultiplier then
		model:SetAttribute("MutationColor", model:GetAttribute("VarietyRim") or mutation.color)
		CollectionService:AddTag(model, "MutationGlow")
	end
	return true
end

------------------------------------------------------------------------
-- CÔTÉ CLIENT : contours lumineux des persos proches + reflet animé de l'Or / du Diamant.
------------------------------------------------------------------------

MutationsFx.GlowMultiplier = 3 -- mutations à contour lumineux (x3 et plus)
MutationsFx.GlowRadius = 40 -- studs autour de la caméra
MutationsFx.GlowMax = 8 -- contours affichés en même temps (Roblox en affiche 31 au plus)
MutationsFx.ShineRadius = 70 -- reflets animés autour de la caméra

local function modelPosition(model: Model): Vector3?
	local root = model.PrimaryPart or model:FindFirstChild("Torso")
	return if root and root:IsA("BasePart") then root.CFrame.Position else nil
end

-- Choisit les persos à contour (les plus proches de `eye`) : renvoie une liste de modèles.
function MutationsFx.pickGlows(models: { Model }, eye: Vector3): { Model }
	local near = {}
	for _, model in models do
		local pos = model:IsA("Model") and modelPosition(model)
		if pos then
			local dist = (pos - eye).Magnitude
			if dist <= MutationsFx.GlowRadius then
				table.insert(near, { model = model, dist = dist })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.dist < b.dist
	end)
	local out = {}
	for i = 1, math.min(#near, MutationsFx.GlowMax) do
		table.insert(out, near[i].model)
	end
	return out
end

local glows: { [Model]: Highlight } = {}
local shines: { UIGradient } = {}
local started = false

-- Une passe (deux fois par seconde) : contours et liste des reflets à animer.
function MutationsFx.clientStep(eye: Vector3)
	local tagged = {}
	for _, model in CollectionService:GetTagged("MutationGlow") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			table.insert(tagged, model)
		end
	end
	local keep = {}
	for _, model in MutationsFx.pickGlows(tagged, eye) do
		keep[model] = true
		if not glows[model] or not glows[model].Parent then
			local color = model:GetAttribute("MutationColor")
			local highlight = Instance.new("Highlight")
			highlight.Name = "MutationContour"
			highlight.OutlineColor = typeof(color) == "Color3" and color or Color3.new(1, 1, 1)
			highlight.OutlineTransparency = 0.25
			highlight.FillColor = highlight.OutlineColor
			highlight.FillTransparency = 0.88
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Adornee = model
			highlight.Parent = model
			glows[model] = highlight
		end
	end
	for model, highlight in glows do
		if not keep[model] then
			if highlight.Parent then
				highlight:Destroy()
			end
			glows[model] = nil
		end
	end
	table.clear(shines)
	for _, gradient in CollectionService:GetTagged("MutationShine") do
		local model = gradient:IsDescendantOf(workspace) and gradient:FindFirstAncestorOfClass("Model")
		local pos = model and modelPosition(model)
		if pos and (pos - eye).Magnitude <= MutationsFx.ShineRadius then
			table.insert(shines, gradient)
		end
	end
end

-- Nombre de contours affichés (tests).
function MutationsFx.glowCount(): number
	local n = 0
	for _ in glows do
		n += 1
	end
	return n
end

function MutationsFx.startClient()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local camera = workspace.CurrentCamera
			if camera then
				pcall(MutationsFx.clientStep, camera.CFrame.Position)
			end
			task.wait(0.5)
		end
	end)
	-- reflet qui balaie la tenue (Or, Diamant...) : seulement les persos proches
	RunService.Heartbeat:Connect(function()
		local offset = Vector2.new((os.clock() * 0.45) % 2 - 1, 0)
		for _, gradient in shines do
			if gradient.Parent then
				gradient.Offset = offset
			end
		end
	end)
end

return MutationsFx
