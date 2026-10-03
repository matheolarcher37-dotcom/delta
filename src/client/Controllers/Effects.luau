-- Effets visuels côté client : attaques (orbe, rayon, entaille, foudre, flammes, ombres...),
-- chiffres de dégâts, morts, montées de niveau, éclairs d'événement, faille inter-univers,
-- pièces et matériaux qui volent vers le joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Effects = {}

local player = Players.LocalPlayer
local fxFolder: Folder
local screenGui: ScreenGui
local hud = nil
local rng = Random.new()

------------------------------------------------------------------------
-- Sons
------------------------------------------------------------------------

local SOUNDS = {
	punch = "rbxasset://sounds/collide.wav",
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	beam = "rbxasset://sounds/Rocket shot.wav",
	ko = "rbxasset://sounds/uuhhh.mp3",
	coin = "rbxasset://sounds/electronicpingshort.wav",
	unsheath = "rbxasset://sounds/unsheath.wav",
}
local soundTemplates = {}
for name, id in SOUNDS do
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.35
	sound.Parent = SoundService
	soundTemplates[name] = sound
end
local soundBudget = 0

local function playAt(name: string, position: Vector3?, volume: number?)
	local template = soundTemplates[name]
	if not template then
		return
	end
	if soundBudget > 10 then
		return
	end
	local camera = Workspace.CurrentCamera
	if position and camera and (camera.CFrame.Position - position).Magnitude > 120 then
		return
	end
	soundBudget += 1
	local sound = template:Clone()
	sound.Volume = volume or template.Volume
	sound.PlaybackSpeed = rng:NextNumber(0.9, 1.1)
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = Workspace.Terrain
		sound.Parent = holder
		sound.RollOffMaxDistance = 140
		sound:Play()
		sound.Ended:Once(function()
			holder:Destroy()
		end)
		task.delay(4, function()
			if holder.Parent then
				holder:Destroy()
			end
		end)
	else
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

local function fxPart(size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		local target: any = part
		for key, value in props do
			target[key] = value
		end
	end
	part.Parent = fxFolder
	return part
end

local function tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function fadeAndDestroy(part: BasePart, duration: number, goals: { [string]: any }?)
	local g = goals or {}
	g.Transparency = 1
	tween(part, duration, g)
	task.delay(duration, function()
		part:Destroy()
	end)
end

local function burst(position: Vector3, color: Color3, size: number)
	local ball = fxPart(Vector3.one * size * 0.4, CFrame.new(position), color, { Shape = Enum.PartType.Ball, Transparency = 0.1 })
	fadeAndDestroy(ball, 0.35, { Size = Vector3.one * size * 1.6 })
	local ring = fxPart(Vector3.new(0.2, size, size), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, { Shape = Enum.PartType.Cylinder, Transparency = 0.3 })
	fadeAndDestroy(ring, 0.4, { Size = Vector3.new(0.2, size * 3, size * 3) })
end

local function shards(position: Vector3, color: Color3, count: number, power: number)
	for _ = 1, count do
		local cube = fxPart(Vector3.one * rng:NextNumber(0.3, 0.7), CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), color)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1.2), rng:NextNumber(-1, 1)).Unit
		fadeAndDestroy(cube, 0.5, { CFrame = cube.CFrame + dir * power * rng:NextNumber(0.6, 1.2), Size = Vector3.one * 0.1 })
	end
end

local shakeId = 0
local function cameraShake(intensity: number, duration: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	shakeId += 1
	local name = "AnimeTycoonShake" .. shakeId
	local start = os.clock()
	-- Après la caméra par défaut, pour que la secousse soit visible.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local p = (os.clock() - start) / duration
		if p >= 1 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = intensity * (1 - p)
		camera.CFrame *= CFrame.Angles(rng:NextNumber(-k, k) * 0.02, rng:NextNumber(-k, k) * 0.02, 0)
	end)
end

-- Texte flottant (dégâts, "LEVEL UP!", "+12 💰"...)
local function floatingText(position: Vector3, text: string, color: Color3, size: number?, duration: number?)
	local anchor = fxPart(Vector3.one * 0.2, CFrame.new(position), Color3.new(1, 1, 1), { Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3 * (size or 1)
	scale.Parent = label
	tween(scale, 0.18, { Scale = 1 * (size or 1) }, Enum.EasingStyle.Back)
	local d = duration or 0.9
	tween(anchor, d, { CFrame = anchor.CFrame + Vector3.new(rng:NextNumber(-1.5, 1.5), 4, 0) })
	task.delay(d * 0.6, function()
		tween(label, d * 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(d, function()
		anchor:Destroy()
	end)
end

------------------------------------------------------------------------
-- Attaques
------------------------------------------------------------------------

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- Gerbe de particules ponctuelle (ParticleEmitter:Emit).
local function particles(position: Vector3, options)
	local holder = fxPart(Vector3.one * 0.2, CFrame.new(position), Color3.new(1, 1, 1), { Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = options.texture or SPARKLE
	local c1 = options.color or Color3.new(1, 1, 1)
	emitter.Color = ColorSequence.new(c1, options.color2 or c1)
	emitter.LightEmission = options.light or 1
	emitter.LightInfluence = options.light == 0 and 1 or 0
	local size = options.size or 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * (options.grow and 0.4 or 1)), NumberSequenceKeypoint.new(1, size * (options.grow and 1.6 or 0.1)) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, options.alpha or 0), NumberSequenceKeypoint.new(1, 1) })
	local life = options.life or 0.6
	emitter.Lifetime = NumberRange.new(life * 0.6, life)
	emitter.Speed = NumberRange.new(options.speedMin or 4, options.speed or 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = options.gravity or Vector3.zero
	emitter.Drag = options.drag or 3
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(options.count or 20)
	task.delay(life + 0.2, function()
		holder:Destroy()
	end)
end

-- Onde de choc au sol.
local function shockwave(position: Vector3, color: Color3, radius: number, duration: number?)
	local ground = Vector3.new(position.X, position.Y - 1, position.Z)
	local ring = fxPart(Vector3.new(0.25, 2, 2), CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)), color, { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
	fadeAndDestroy(ring, duration or 0.45, { Size = Vector3.new(0.1, radius * 2, radius * 2) })
end

-- Croissant de lame (coup d'épée / tranchant) dans le plan horizontal, incliné de `tilt`.
local function crescent(center: Vector3, direction: Vector3, radius: number, color: Color3, thickness: number, tilt: number?)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local base = CFrame.lookAt(center, center + flat.Unit) * CFrame.Angles(0, 0, tilt or 0)
	local segments = 11
	for i = 0, segments - 1 do
		local a = math.rad(-65 + 130 * i / (segments - 1))
		local edge = 1 - math.abs(i - (segments - 1) / 2) / ((segments - 1) / 2)
		local pos = base * CFrame.new(math.sin(a) * radius, 0, -math.cos(a) * radius)
		local cf = pos * CFrame.Angles(0, -a, 0)
		local width = thickness * (0.35 + edge * 0.65)
		local seg = fxPart(Vector3.new(radius * 0.3, width * 0.4, width), cf, color, { Transparency = 0.05 })
		local core = fxPart(Vector3.new(radius * 0.3, width * 0.2, width * 0.45), cf, Color3.new(1, 1, 1))
		local out = base * CFrame.new(math.sin(a) * radius * 1.25, 0, -math.cos(a) * radius * 1.25) * CFrame.Angles(0, -a, 0)
		fadeAndDestroy(seg, 0.28, { CFrame = out, Size = Vector3.new(radius * 0.32, 0.05, width * 0.4) })
		fadeAndDestroy(core, 0.2, { CFrame = out })
	end
end

local function lightningBolt(from: Vector3, to: Vector3, color: Color3, thickness: number, life: number, jitter: number?)
	local segments = 7
	local previous = from
	local j = jitter or 1.4
	for i = 1, segments do
		local point = from:Lerp(to, i / segments)
		if i < segments then
			point += Vector3.new(rng:NextNumber(-j, j), rng:NextNumber(-j, j), rng:NextNumber(-j, j))
		end
		local length = (point - previous).Magnitude
		local segment = fxPart(Vector3.new(thickness, thickness, length), CFrame.lookAt((previous + point) / 2, point), color)
		fadeAndDestroy(segment, life)
		-- Petites branches
		if i < segments and rng:NextNumber() < 0.35 then
			local branchEnd = point + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), rng:NextNumber(-3, 3))
			local branch = fxPart(Vector3.new(thickness * 0.5, thickness * 0.5, (branchEnd - point).Magnitude), CFrame.lookAt((point + branchEnd) / 2, branchEnd), color)
			fadeAndDestroy(branch, life * 0.8)
		end
		previous = point
	end
end

-- Cristaux de glace qui jaillissent du sol puis éclatent.
local function iceCrystals(position: Vector3, color: Color3, scale: number)
	local ground = Vector3.new(position.X, position.Y - 1.5 * scale, position.Z)
	for i = 0, 6 do
		local angle = i / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dist = i == 0 and 0 or rng:NextNumber(1.2, 2.6) * scale
		local base = ground + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local height = rng:NextNumber(2.5, 4.5) * scale * (i == 0 and 1.4 or 1)
		local tiltCF = CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), angle, rng:NextNumber(-0.4, 0.4))
		local crystal = fxPart(Vector3.new(0.6, 0.2, 0.6) * scale, tiltCF * CFrame.Angles(0, math.rad(45), 0), color:Lerp(Color3.new(1, 1, 1), 0.35), {
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
		local glow = fxPart(Vector3.new(0.3, 0.2, 0.3) * scale, crystal.CFrame, color, { Transparency = 0.1 })
		tween(crystal, 0.12, { Size = Vector3.new(0.9 * scale, height, 0.9 * scale), CFrame = tiltCF * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.rad(45), 0) })
		tween(glow, 0.12, { Size = Vector3.new(0.4 * scale, height * 0.9, 0.4 * scale), CFrame = tiltCF * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.rad(45), 0) })
		task.delay(0.55, function()
			fadeAndDestroy(crystal, 0.25, { Size = Vector3.new(0.2, height * 0.5, 0.2) })
			fadeAndDestroy(glow, 0.2)
		end)
	end
	particles(position, { color = color:Lerp(Color3.new(1, 1, 1), 0.5), count = 26, size = 0.7, speed = 14, life = 0.8, gravity = Vector3.new(0, -8, 0) })
end

-- Fumée noire.
local function blackSmoke(position: Vector3, scale: number, tint: Color3?)
	particles(position, {
		texture = SMOKE,
		color = Color3.fromRGB(15, 10, 20),
		color2 = tint or Color3.fromRGB(60, 20, 90),
		light = 0,
		alpha = 0.15,
		count = 18,
		size = 2.2 * scale,
		grow = true,
		speedMin = 1,
		speed = 5,
		life = 1.1,
		gravity = Vector3.new(0, 3, 0),
		drag = 2,
	})
end

local ATTACKS = {}

ATTACKS.punch = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	burst(to, color, 2 * scale)
	shockwave(to + Vector3.new(0, 1, 0), color, 3 * scale, 0.3)
	particles(to, { color = color, count = 10, size = 0.5, speed = 10, life = 0.35 })
	playAt("punch", to, 0.25)
	local _ = from
end

ATTACKS.orb = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	local orb = fxPart(Vector3.one * 1.6 * scale, CFrame.new(from), color, { Shape = Enum.PartType.Ball, Transparency = 0.05 })
	local core = fxPart(Vector3.one * 0.9 * scale, CFrame.new(from), Color3.new(1, 1, 1), { Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 3
	light.Parent = orb
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SPARKLE
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(0.6 * scale, 0)
	trail.Lifetime = NumberRange.new(0.2, 0.35)
	trail.Rate = 80
	trail.Speed = NumberRange.new(1, 3)
	trail.SpreadAngle = Vector2.new(180, 180)
	trail.Parent = orb
	tween(orb, 0.22, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	tween(core, 0.22, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	playAt("beam", from, 0.2)
	task.delay(0.22, function()
		orb:Destroy()
		core:Destroy()
		burst(to, color, 3.2 * scale)
		shockwave(to, color, 5 * scale)
		particles(to, { color = color, color2 = Color3.new(1, 1, 1), count = 24, size = 0.8 * scale, speed = 16, life = 0.5 })
	end)
end

ATTACKS.beam = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	local length = (to - from).Magnitude
	local beam = fxPart(Vector3.new(1.4 * scale, 1.4 * scale, length), CFrame.lookAt((from + to) / 2, to), color, { Transparency = 0.1 })
	local core = fxPart(Vector3.new(0.6 * scale, 0.6 * scale, length), beam.CFrame, Color3.new(1, 1, 1))
	fadeAndDestroy(beam, 0.32, { Size = Vector3.new(0.1, 0.1, length) })
	fadeAndDestroy(core, 0.26)
	burst(to, color, 3.2 * scale)
	particles(to, { color = color, color2 = Color3.new(1, 1, 1), count = 22, size = 0.7 * scale, speed = 14, life = 0.45 })
	playAt("beam", from, 0.25)
end

ATTACKS.slash = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	crescent(to, to - from, 2.4 * scale, color, 1.2 * scale, math.rad(rng:NextNumber(-35, 35)))
	particles(to, { color = color, count = 10, size = 0.5, speed = 12, life = 0.35 })
	playAt("slash", to, 0.3)
end

ATTACKS.lightning = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	lightningBolt(from, to, color, 0.4 * scale, 0.2)
	lightningBolt(from, to, Color3.new(1, 1, 1), 0.16 * scale, 0.14, 0.8)
	-- Éclairs qui crépitent autour de la cible
	for _ = 1, 3 do
		local a = to + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 3), rng:NextNumber(-3, 3)) * scale
		lightningBolt(to, a, color, 0.18 * scale, 0.16, 0.6)
	end
	burst(to, color, 2.4 * scale)
	particles(to, { color = color, color2 = Color3.new(1, 1, 1), count = 18, size = 0.5 * scale, speed = 18, life = 0.35 })
	playAt("unsheath", to, 0.25)
end

ATTACKS.flame = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	for _ = 1, 6 do
		local start = from:Lerp(to, rng:NextNumber(0, 0.4))
		local cube = fxPart(
			Vector3.one * rng:NextNumber(0.8, 1.5) * scale,
			CFrame.new(start) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			color:Lerp(Color3.fromRGB(255, 240, 120), rng:NextNumber(0, 0.5))
		)
		fadeAndDestroy(cube, 0.35, { CFrame = CFrame.new(to + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 2), rng:NextNumber(-1.5, 1.5))), Size = Vector3.one * 0.3 })
	end
	particles(to, {
		texture = FIRE,
		color = color,
		color2 = Color3.fromRGB(255, 230, 120),
		count = 22,
		size = 1.6 * scale,
		speedMin = 2,
		speed = 8,
		life = 0.6,
		gravity = Vector3.new(0, 10, 0),
		alpha = 0.1,
	})
	burst(to, color, 2.4 * scale)
	playAt("lunge", to, 0.25)
end

ATTACKS.ice = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	local shard = fxPart(Vector3.new(0.4, 0.4, 2.2) * scale, CFrame.lookAt(from, to), color:Lerp(Color3.new(1, 1, 1), 0.4), { Material = Enum.Material.Glass, Transparency = 0.1 })
	tween(shard, 0.16, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }, Enum.EasingStyle.Linear)
	task.delay(0.16, function()
		shard:Destroy()
		iceCrystals(to, color, scale)
	end)
	playAt("slash", to, 0.25)
end

ATTACKS.shadow = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	local ground = Vector3.new(to.X, to.Y - 2 * scale, to.Z)
	for i = 0, 4 do
		local offset = Vector3.new(math.cos(i * 1.26) * 1.5, 0, math.sin(i * 1.26) * 1.5) * scale
		local spike = fxPart(Vector3.new(0.6, 0.2, 0.6) * scale, CFrame.new(ground + offset), Color3.fromRGB(20, 15, 25), { Material = Enum.Material.SmoothPlastic })
		fadeAndDestroy(spike, 0.5, {
			Size = Vector3.new(0.5, 6, 0.5) * scale,
			CFrame = CFrame.new(ground + offset + Vector3.new(0, 3 * scale, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
		})
	end
	blackSmoke(to, scale, color)
	playAt("lunge", to, 0.2)
	local _ = from
end

ATTACKS.wind = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	for k = 0, 1 do
		task.delay(k * 0.06, function()
			crescent(to, to - from, (2 + k) * scale, color, 0.9 * scale, math.rad(-20 + k * 40))
		end)
	end
	particles(to, { color = color, count = 14, size = 0.45, speed = 16, life = 0.5, drag = 1 })
	playAt("slash", to, 0.3)
end

ATTACKS.mist = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	crescent(to, to - from, 3.2 * scale, color, 1.6 * scale, 0)
	particles(
		to,
		{ texture = SMOKE, color = Color3.fromRGB(230, 240, 255), light = 0, alpha = 0.3, count = 14, size = 2.5 * scale, grow = true, speedMin = 1, speed = 4, life = 1.2 }
	)
	playAt("slash", to, 0.3)
end

ATTACKS.stretch = function(from: Vector3, to: Vector3, color: Color3, scale: number)
	local length = (to - from).Magnitude
	local arm = fxPart(Vector3.new(0.9 * scale, 0.9 * scale, 0.5), CFrame.lookAt(from, to), color, { Material = Enum.Material.SmoothPlastic })
	tween(arm, 0.12, { Size = Vector3.new(0.9 * scale, 0.9 * scale, length), CFrame = CFrame.lookAt((from + to) / 2, to) })
	task.delay(0.16, function()
		fadeAndDestroy(arm, 0.12, { Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.lookAt(from, to) })
	end)
	task.delay(0.1, function()
		burst(to, color, 2.4 * scale)
		shockwave(to, color, 4 * scale, 0.3)
	end)
	playAt("punch", to, 0.3)
end

------------------------------------------------------------------------
-- Gestion des évènements serveur
------------------------------------------------------------------------

local HANDLERS = {}

HANDLERS.Hit = function(data)
	local attacker = data.attacker
	local from = data.from or data.position
	local to = data.position
	local color = data.color or Color3.new(1, 1, 1)
	local scale = 1
	if typeof(attacker) == "Instance" and attacker:IsA("Model") then
		scale = attacker:GetAttribute("BaseScale") or 1
		local root = attacker.PrimaryPart
		if root then
			from = root.Position + root.CFrame.LookVector * 1.5 * scale + Vector3.new(0, 0.5 * scale, 0)
		end
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - to).Magnitude > 160 then
		return
	end
	local kind = data.kind or "punch"
	local special = data.special
	local fx = ATTACKS[kind] or ATTACKS.punch
	fx(from, to, color, special and scale * 1.8 or scale)
	local mine = data.owner == player.UserId
	if special then
		shards(to, color, 10, 8)
		if mine and typeof(attacker) == "Instance" and attacker.PrimaryPart then
			-- Nom de l'attaque façon anime !
			local name = attacker:GetAttribute("AttackName")
			floatingText(attacker.PrimaryPart.Position + Vector3.new(0, 5 * scale, 0), (name or "ATTAQUE SPÉCIALE") .. " !", color:Lerp(Color3.new(1, 1, 1), 0.3), 1.3, 1.3)
			cameraShake(1.5, 0.25)
		end
	end
	local amountText = Formulas.formatNumber(data.amount or 0)
	if data.crit then
		floatingText(to + Vector3.new(0, 2, 0), "CRIT! " .. amountText, Color3.fromRGB(255, 80, 60), 1.25)
	else
		floatingText(to + Vector3.new(0, 2, 0), amountText, mine and Color3.fromRGB(255, 240, 120) or Color3.fromRGB(230, 230, 230), mine and 0.95 or 0.7)
	end
end

-- Coup d'épée du joueur : croissant lumineux + particules selon l'épée.
HANDLERS.SwordSlash = function(data)
	local camera = Workspace.CurrentCamera
	local position = data.position
	if not position or (camera and (camera.CFrame.Position - position).Magnitude > 160) then
		return
	end
	local color = data.color or Color3.new(1, 1, 1)
	local direction = data.direction or Vector3.new(0, 0, -1)
	local radius = math.clamp((data.range or 7) * 0.45, 2.5, 6)
	crescent(position, direction, radius, color, 1.3, math.rad(rng:NextNumber(-25, 25)))
	local kind = data.kind
	if kind == "lightning" then
		for _ = 1, 2 do
			lightningBolt(position, position + direction * radius + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-1, 2), rng:NextNumber(-2, 2)), color, 0.2, 0.15, 0.7)
		end
	elseif kind == "flame" then
		particles(
			position + direction * 2,
			{ texture = FIRE, color = color, color2 = Color3.fromRGB(255, 230, 120), count = 12, size = 1.2, speedMin = 2, speed = 6, life = 0.5, gravity = Vector3.new(0, 8, 0) }
		)
	elseif kind == "shadow" then
		blackSmoke(position + direction * 2, 0.8, color)
	elseif kind == "ice" then
		particles(position + direction * 2, { color = color:Lerp(Color3.new(1, 1, 1), 0.5), count = 16, size = 0.5, speed = 10, life = 0.6 })
	elseif kind == "wind" or kind == "mist" then
		particles(position + direction * 2, { color = color, count = 12, size = 0.45, speed = 14, life = 0.45, drag = 1 })
	end
end

HANDLERS.EnemyHit = function(data)
	burst(data.position, Color3.fromRGB(255, 70, 70), 1.6)
	floatingText(data.position + Vector3.new(0, 2, 0), "-" .. Formulas.formatNumber(data.amount or 0), Color3.fromRGB(255, 90, 90), 0.6)
end

HANDLERS.Death = function(data)
	local position = data.position
	burst(position, Color3.new(1, 1, 1), data.boss and 10 or 4)
	shards(position, Color3.fromRGB(255, 230, 120), data.boss and 30 or 10, data.boss and 18 or 8)
	local model = data.target
	if typeof(model) == "Instance" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				tween(part, 0.8, { Transparency = 1 })
			end
		end
	end
	if data.boss then
		cameraShake(4, 0.8)
	end
end

HANDLERS.KO = function(data)
	for _ = 1, 8 do
		local puff = fxPart(
			Vector3.one * rng:NextNumber(1, 2),
			CFrame.new(data.position + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 2), rng:NextNumber(-1.5, 1.5))),
			Color3.fromRGB(200, 200, 210),
			{ Material = Enum.Material.SmoothPlastic, Transparency = 0.2 }
		)
		fadeAndDestroy(puff, 0.7, { Size = Vector3.one * 3, CFrame = puff.CFrame + Vector3.new(0, 3, 0) })
	end
	playAt("ko", data.position, 0.4)
end

HANDLERS.LevelUp = function(data)
	floatingText(data.position + Vector3.new(0, 6, 0), "LEVEL UP! " .. tostring(data.level), Color3.fromRGB(255, 230, 60), 1.2, 1.4)
	local ring = fxPart(
		Vector3.new(0.3, 4, 4),
		CFrame.new(data.position - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 230, 60),
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.2 }
	)
	fadeAndDestroy(ring, 0.6, { Size = Vector3.new(0.3, 12, 12), CFrame = ring.CFrame + Vector3.new(0, 3, 0) })
end

HANDLERS.Slam = function(data)
	local ring = fxPart(
		Vector3.new(0.6, 6, 6),
		CFrame.new(data.position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 80, 60),
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.15 }
	)
	fadeAndDestroy(ring, 0.5, { Size = Vector3.new(0.6, data.radius * 2, data.radius * 2) })
	shards(data.position + Vector3.new(0, 1, 0), Color3.fromRGB(150, 120, 100), 16, 12)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - data.position).Magnitude < 60 then
		cameraShake(3, 0.4)
	end
end

HANDLERS.Strike = function(data)
	local top = data.position + Vector3.new(rng:NextNumber(-6, 6), 90, rng:NextNumber(-6, 6))
	local color = data.color or Color3.fromRGB(255, 230, 60)
	if data.aura == "neant" then
		-- Pluie de cubes du néant
		for i = 1, 6 do
			local cube = fxPart(Vector3.one * 1.4, CFrame.new(data.position + Vector3.new(rng:NextNumber(-3, 3), 40 + i * 4, rng:NextNumber(-3, 3))), color)
			tween(
				cube,
				0.5,
				{ CFrame = CFrame.new(data.position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))) * CFrame.Angles(1, 1, 0) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(0.5, function()
				fadeAndDestroy(cube, 0.4, { Size = Vector3.one * 3 })
			end)
		end
	else
		lightningBolt(top, data.position, color, 1.2, 0.35)
		lightningBolt(top, data.position, Color3.new(1, 1, 1), 0.5, 0.25)
	end
	task.delay(0.3, function()
		burst(data.position, color, 6)
	end)
	playAt("beam", data.position, 0.5)
end

HANDLERS.Build = function(data)
	burst(data.position, Color3.fromRGB(255, 230, 120), 8)
	shards(data.position, Color3.fromRGB(255, 255, 255), 16, 10)
	floatingText(data.position + Vector3.new(0, 4, 0), "CONSTRUIT !", Color3.fromRGB(120, 255, 140), 1.2, 1.2)
end

HANDLERS.Evolve = function(data)
	local column = fxPart(Vector3.new(4, 40, 4), CFrame.new(data.position + Vector3.new(0, 16, 0)), Color3.fromRGB(200, 140, 255), { Transparency = 0.2 })
	fadeAndDestroy(column, 1.2, { Size = Vector3.new(0.5, 60, 0.5) })
	shards(data.position, Color3.fromRGB(255, 220, 120), 20, 12)
	floatingText(data.position + Vector3.new(0, 6, 0), string.rep("★", data.stars or 2) .. " ÉVEIL !", Color3.fromRGB(230, 190, 255), 1.5, 1.6)
	cameraShake(1.5, 0.5)
end

HANDLERS.Rift = function(data)
	local color = data.color or Color3.new(1, 1, 1)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 50
	flash.Parent = screenGui
	tween(flash, 0.6, { BackgroundTransparency = 0 })
	task.delay(0.9, function()
		flash.BackgroundColor3 = color
		tween(flash, 1.4, { BackgroundTransparency = 1 })
		task.delay(1.5, function()
			flash:Destroy()
		end)
	end)
	cameraShake(3, 1.5)
end

------------------------------------------------------------------------
-- Récompenses : pièces et matériaux qui volent vers le joueur
------------------------------------------------------------------------

local function flyTo(part: BasePart, duration: number, onArrive: () -> ())
	local start = part.Position
	local startTime = os.clock()
	local arc = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(4, 8), rng:NextNumber(-4, 4))
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local p = math.min(1, (os.clock() - startTime) / duration)
		if not root then
			connection:Disconnect()
			part:Destroy()
			return
		end
		local target = root.Position
		local eased = p * p
		local position = start:Lerp(target, eased) + arc * math.sin(p * math.pi)
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, os.clock() * 8, 0)
		if p >= 1 then
			connection:Disconnect()
			part:Destroy()
			onArrive()
		end
	end)
end

local function onReward(kind: string, amount: number, position: Vector3?, extra: string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = position or (root and root.Position) or Vector3.zero
	if kind == "coins" then
		local count = math.clamp(math.floor(math.log10(math.max(amount, 1)) * 2) + 2, 3, 10)
		for i = 1, count do
			local coin = fxPart(
				Vector3.new(0.25, 1.1, 1.1),
				CFrame.new(origin + Vector3.new(rng:NextNumber(-1.5, 1.5), 1, rng:NextNumber(-1.5, 1.5))),
				Color3.fromRGB(255, 205, 50),
				{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.3 }
			)
			task.delay(i * 0.04, function()
				flyTo(coin, 0.55, function()
					if i == 1 and hud then
						hud.pulseCoins()
					end
				end)
			end)
		end
		floatingText(origin + Vector3.new(0, 3, 0), "+" .. Formulas.formatNumber(amount) .. " 💰", Color3.fromRGB(255, 220, 70), 1)
		playAt("coin", nil, 0.15)
	elseif kind == "material" then
		local material = extra and Universes.getMaterial(extra)
		local color = material and material.color or Color3.new(1, 1, 1)
		local gem = fxPart(Vector3.one * 1.2, CFrame.new(origin + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), color)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Parent = gem
		flyTo(gem, 0.8, function() end)
		floatingText(origin + Vector3.new(0, 4, 0), "+" .. amount .. " " .. (material and material.name or ""), color:Lerp(Color3.new(1, 1, 1), 0.3), 1, 1.4)
	elseif kind == "crystal" then
		local color = Color3.fromRGB(120, 230, 255)
		local gem = fxPart(Vector3.new(0.9, 1.6, 0.9), CFrame.new(origin + Vector3.new(0, 2, 0)), color, { Transparency = 0.1 })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Brightness = 2
		light.Parent = gem
		flyTo(gem, 0.9, function() end)
		floatingText(origin + Vector3.new(0, 5, 0), "+" .. amount .. " CRISTAL DE TRAIT 💎", color, 1.2, 1.6)
	end
end

function Effects.init(gui: ScreenGui, hudModule)
	screenGui = gui
	hud = hudModule
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = Workspace

	Remotes.event("CombatFX").OnClientEvent:Connect(function(kind, data)
		local handler = HANDLERS[kind]
		if handler then
			local ok, err = pcall(handler, data or {})
			if not ok then
				warn("[AnimeTycoon] FX " .. tostring(kind) .. " : " .. tostring(err))
			end
		end
	end)
	Remotes.event("Reward").OnClientEvent:Connect(function(kind, amount, position, extra)
		onReward(kind, amount, position, extra)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			soundBudget = 0
		end
	end)
end

Effects.floatingText = floatingText
Effects.burst = burst

return Effects
