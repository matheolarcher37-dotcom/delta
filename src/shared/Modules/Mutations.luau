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
-- Dans les deux cas, les mutations x3 et plus reçoivent un contour lumineux (Highlight).
-- Les effets « historiques » (éclairs, givre, flammes, cubes du Néant, paillettes d'or,
-- arc-en-ciel) sont joués en plus côté client (Controllers/AuraController).
--
-- Réglages de chaque mutation : Config/Mutations.luau (champ `look`).

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

-- Petits motifs peints sur le torse (étoiles, pétales, reflet de cristal), sous forme de pastilles.
local function motif(gui: SurfaceGui, kind: string)
	local function dot(x: number, y: number, w: number, h: number, color: Color3, transparency: number, rotation: number?)
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
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = gui
	end
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

-- Contour lumineux des mutations rares (x3 et plus) : se voit de loin dans la base.
local function outline(model: Model, mutation)
	if (mutation.multiplier or 1) < 3 or model:FindFirstChild("MutationContour") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "MutationContour"
	highlight.OutlineColor = mutation.color
	highlight.OutlineTransparency = 0.25
	highlight.FillColor = mutation.color
	highlight.FillTransparency = 0.88
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
end

-- Auréole simple (si CharacterBuilder.applyVariety n'existe pas) : 10 perles lumineuses.
local function halo(model: Model, scale: number)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head or model:FindFirstChild("MutationAureole") then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "MutationAureole"
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local bead = Instance.new("Part")
		bead.Name = "Perle"
		bead.Shape = Enum.PartType.Ball
		bead.Size = Vector3.one * 0.38 * scale
		bead.Material = Enum.Material.Neon
		bead.Color = Color3.fromRGB(255, 226, 120)
		bead.CanCollide = false
		bead.CanTouch = false
		bead.CanQuery = false
		bead.CastShadow = false
		bead.Massless = true
		bead.Anchored = head.Anchored
		-- au-dessus des cheveux (les mèches montent jusqu'à ~1,6 au-dessus du centre de la tête)
		bead.CFrame = head.CFrame * CFrame.new(math.cos(a) * 0.85 * scale, 1.95 * scale, math.sin(a) * 0.85 * scale)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = bead
		weld.Parent = bead
		bead.Parent = folder
	end
	folder.Parent = model
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
		for _, d in model:GetDescendants() do
			if d:IsA("SurfaceGui") and d.Parent and d.Parent.Name ~= "Head" and d.Name ~= "Face" then
				if alpha > 0 then
					veil(d, look, alpha)
				end
				if look.motif and d.Parent == torso and (d.Face == Enum.NormalId.Front or d.Face == Enum.NormalId.Back) and not d:FindFirstChild("MutationMotif") then
					motif(d, look.motif)
				end
			end
		end
		tintParts(model, look, not done)
	end
	if not done and look.halo then
		halo(model, scale)
	end
	-- 3) Particules légères (si applyVariety n'en a pas mis).
	if look.particles and not hasFx then
		particles(model, look.particles, scale)
	end
	-- 4) Contour lumineux des mutations x3 et plus.
	outline(model, mutation)
	return true
end

return MutationsFx
