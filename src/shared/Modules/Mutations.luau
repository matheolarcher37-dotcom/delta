-- Apparence des MUTATIONS sur un modèle de perso déjà construit (serveur ou aperçu).
--
--   • voile coloré sur les habits peints (un cadre semi-transparent par SurfaceGui, avec un
--     reflet qui balaie pour Or / Diamant / Galaxie / Angélique / Arc-en-ciel) ;
--   • cheveux et accessoires teintés (via CharacterBuilder.applyVariety quand il existe : il
--     ajoute aussi l'auréole, les ailes ou la fleur ; sinon une teinte simple ici) ;
--   • particules légères (pétales, scintillements, fumée d'ombre...).
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
	if look.rainbowTint or look.shine then
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

-- Teinte simple des cheveux / accessoires (si CharacterBuilder.applyVariety n'existe pas).
local function tintHair(model: Model, look)
	if not look.hair then
		return
	end
	local custom = model:GetAttribute("CustomModel") == true
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not BODY[d.Name] and d.Transparency < 1 and (isHair(d) or custom) and not d:FindFirstChildOfClass("SurfaceGui") then
			d.Color = d.Color:Lerp(look.hair, look.mix or 0.5)
			if look.material then
				d.Material = look.material
			end
			if look.reflectance then
				d.Reflectance = look.reflectance
			end
		end
	end
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
		bead.Size = Vector3.one * 0.34 * scale
		bead.Material = Enum.Material.Neon
		bead.Color = Color3.fromRGB(255, 226, 120)
		bead.CanCollide = false
		bead.CanTouch = false
		bead.CanQuery = false
		bead.CastShadow = false
		bead.Massless = true
		bead.Anchored = head.Anchored
		bead.CFrame = head.CFrame * CFrame.new(math.cos(a) * 0.72 * scale, 1.1 * scale, math.sin(a) * 0.72 * scale)
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
	-- 1) Voile sur les habits peints (le visage un peu moins, pour rester lisible).
	local alpha = look.tintAlpha or 0
	if alpha > 0 then
		for _, d in model:GetDescendants() do
			if d:IsA("SurfaceGui") then
				local part = d.Parent
				local onHead = part and part.Name == "Head"
				veil(d, look, onHead and alpha * 0.55 or alpha)
			end
		end
	end
	-- 2) Cheveux / accessoires (et auréole, ailes, fleur selon la mutation).
	local applyVariety = (CharacterBuilder :: any).applyVariety
	local done = false
	if type(applyVariety) == "function" then
		local ok, result = pcall(applyVariety, model, mutation.id)
		done = ok and result == true
	end
	if not done then
		tintHair(model, look)
		if look.halo then
			halo(model, scale)
		end
	end
	-- 3) Particules légères.
	if look.particles then
		particles(model, look.particles, scale)
	end
	return true
end

return MutationsFx
