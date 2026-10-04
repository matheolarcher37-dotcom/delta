-- Effets visuels côté client : attaques signature des persos (Rasengan, Chidori, Kamehameha,
-- Violet Imaginaire, Découpe, Gatling, Santoryu, Hinokami Kagura...), attaques de boss, chiffres
-- de dégâts, morts, montées de niveau, éclairs d'événement, faille inter-univers, récompenses.
--
-- Chaque effet est construit en couches : cœur Neon presque blanc + corps coloré + halo transparent
-- + particules + lumière. Les attaques normales utilisent une version légère, les attaques
-- spéciales (toutes les 6 attaques) une version complète avec charge, ondes de choc, cratère,
-- fissures, débris, flash et secousse d'écran.
--
-- Réglages (attributs posés sur le joueur local, par exemple par un menu d'options) :
--   FxShake   = false pour couper la secousse d'écran
--   FxFlash   = false pour couper les flashs et les traits de vitesse
--   FxQuality = "auto" | "high" | "medium" | "low"   (auto : PC = high, console = medium, mobile = low)
-- La liste des effets de chaque perso est dans src/shared/Config/AttackFx.luau.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared.Config.AttackFx)
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Effects = {}

local player = Players.LocalPlayer
local fxFolder: Folder
local anchor: BasePart -- pièce invisible à l'origine : support des Attachments (particules, lumières)
local screenGui: ScreenGui?
local hud = nil
local rng = Random.new()
local now = os.clock

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)
local X_AXIS = Vector3.new(1, 0, 0)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local ROCK = Color3.fromRGB(118, 106, 94)
local SCORCH = Color3.fromRGB(34, 28, 26)

------------------------------------------------------------------------
-- Réglages : qualité, secousse, flash
------------------------------------------------------------------------

local qualityBase = "high" -- qualité choisie (appareil ou réglage du joueur)
local qualityName = "high" -- qualité effective (peut baisser si le jeu rame)
local Q = AttackFx.Quality.high
local LEVELS = { "low", "medium", "high" }

local function levelIndex(name: string): number
	return table.find(LEVELS, name) or 3
end

local function detectQuality(): string
	local pref = player and player:GetAttribute("FxQuality")
	if type(pref) == "string" and AttackFx.Quality[pref] then
		return pref
	end
	local tenFoot = false
	pcall(function()
		tenFoot = GuiService:IsTenFootInterface()
	end)
	if tenFoot then
		return "medium" -- console (Xbox / PlayStation)
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "low" -- mobile / tablette
	end
	return "high"
end

local function setQuality(name: string)
	qualityName = name
	Q = AttackFx.Quality[name] or AttackFx.Quality.high
	-- Qualité EFFECTIVE (auto compris, baisse si le jeu rame) : lue par AuraController.
	if player then
		pcall(function()
			player:SetAttribute("FxQualityEffective", name)
		end)
	end
end

local function refreshQuality()
	qualityBase = detectQuality()
	setQuality(qualityBase)
end

local function shakeEnabled(): boolean
	return not (player and player:GetAttribute("FxShake") == false)
end

local function flashEnabled(): boolean
	return not (player and player:GetAttribute("FxFlash") == false)
end

------------------------------------------------------------------------
-- Sons (sons intégrés de Roblox)
------------------------------------------------------------------------

local SOUNDS = {
	punch = "rbxasset://sounds/collide.wav",
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	beam = "rbxasset://sounds/Rocket shot.wav",
	ko = "rbxasset://sounds/uuhhh.mp3",
	coin = "rbxasset://sounds/electronicpingshort.wav",
	unsheath = "rbxasset://sounds/unsheath.wav",
	shatter = "rbxasset://sounds/glassbreak.wav",
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

local function cameraPos(): Vector3?
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

local function playAt(name: string, position: Vector3?, volume: number?, pitch: number?)
	local template = soundTemplates[name]
	if not template or soundBudget > 10 then
		return
	end
	local cam = cameraPos()
	if position and cam and (cam - position).Magnitude > 130 then
		return
	end
	soundBudget += 1
	local sound = template:Clone()
	sound.Volume = volume or template.Volume
	sound.PlaybackSpeed = (pitch or 1) * rng:NextNumber(0.92, 1.08)
	if position and anchor then
		local holder = Instance.new("Attachment")
		holder.CFrame = CFrame.new(position)
		holder.Parent = anchor
		sound.RollOffMaxDistance = 150
		sound.Parent = holder
		sound:Play()
		pcall(function()
			Debris:AddItem(holder, 4)
		end)
	else
		sound.Parent = SoundService
		sound:Play()
		pcall(function()
			Debris:AddItem(sound, 4)
		end)
	end
end

------------------------------------------------------------------------
-- Moteur : animations image par image, minuteurs, nettoyage garanti
------------------------------------------------------------------------

-- Debris:AddItem est la sécurité finale (si une animation plante, tout disparaît quand même).
local hasDebris = pcall(function()
	return Debris.AddItem
end)

local live: { [Instance]: number } = {} -- instance -> heure d'expiration
local liveCount = 0
local jobs = {}
local timers = {}
local reported = {}
local droppedJobs = 0 -- animations arrêtées parce que leurs pièces avaient déjà été supprimées

local function report(err)
	local message = tostring(err)
	if reported[message] then
		return
	end
	reported[message] = true
	if RunService:IsStudio() then
		warn("[AnimeTycoon] FX : " .. message)
	end
end

local function track(instance: Instance, life: number)
	if not live[instance] then
		liveCount += 1
	end
	live[instance] = now() + life + 0.15
	if hasDebris then
		Debris:AddItem(instance, life + 1.5)
	end
end

local function kill(instance: Instance?)
	if not instance then
		return
	end
	if live[instance] then
		live[instance] = nil
		liveCount -= 1
	end
	instance:Destroy()
end

-- fn(p, écoulé, dt) est appelée à chaque image ; p va de 0 à 1. Renvoyer true arrête l'animation.
local function job(duration: number, fn: (number, number, number) -> boolean?)
	table.insert(jobs, { t0 = now(), d = math.max(duration, 1e-3), fn = fn })
end

local function after(delay: number, fn: () -> ())
	table.insert(timers, { at = now() + delay, fn = fn })
end

local lastStep = now()
local lastSweep = now()
local slowTime, fastTime = 0, 0

local function sweep(t: number)
	for instance, expiry in live do
		if t >= expiry then
			live[instance] = nil
			liveCount -= 1
			instance:Destroy()
		end
	end
end

-- Qualité automatique : baisse si le jeu rame, remonte quand tout va bien.
local function adapt(dt: number)
	if player and type(player:GetAttribute("FxQuality")) == "string" and player:GetAttribute("FxQuality") ~= "auto" then
		return
	end
	if dt > 1 / 32 then
		slowTime += dt
		fastTime = 0
	elseif dt < 1 / 52 then
		fastTime += dt
		slowTime = math.max(0, slowTime - dt)
	end
	local index = levelIndex(qualityName)
	if slowTime > 2 and index > 1 then
		setQuality(LEVELS[index - 1])
		slowTime = 0
	elseif fastTime > 12 and index < levelIndex(qualityBase) then
		setQuality(LEVELS[index + 1])
		fastTime = 0
	end
end

local function step()
	local t = now()
	local dt = math.clamp(t - lastStep, 0, 0.1)
	lastStep = t
	-- Animations d'abord (leur dernière image est jouée avant les minuteurs qui suppriment les pièces).
	local i = 1
	while i <= #jobs do
		local item = jobs[i]
		local elapsed = t - item.t0
		local p = math.min(1, elapsed / item.d)
		local ok, result = pcall(item.fn, p, elapsed, dt)
		if not ok then
			if string.find(tostring(result), "destroyed", 1, true) then
				droppedJobs += 1
			else
				report(result)
			end
		end
		if not ok or result == true or p >= 1 then
			jobs[i] = jobs[#jobs]
			jobs[#jobs] = nil
		else
			i += 1
		end
	end
	i = 1
	while i <= #timers do
		local timer = timers[i]
		if t >= timer.at then
			timers[i] = timers[#timers]
			timers[#timers] = nil
			local ok, err = pcall(timer.fn)
			if not ok then
				report(err)
			end
		else
			i += 1
		end
	end
	if t - lastSweep > 0.4 then
		lastSweep = t
		sweep(t)
	end
	adapt(dt)
end

------------------------------------------------------------------------
-- Outils de géométrie
------------------------------------------------------------------------

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end

local function darken(c: Color3, k: number): Color3
	return c:Lerp(BLACK, k)
end

local function easeOut(p: number): number
	return 1 - (1 - p) * (1 - p)
end

local function easeIn(p: number): number
	return p * p
end

local function randomUnit(): Vector3
	local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	if v.Magnitude < 0.05 then
		return UP
	end
	return v.Unit
end

local function flatDir(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

-- CFrame qui regarde de a vers b (sans NaN si a == b ou si la direction est verticale).
local function look(a: Vector3, b: Vector3, up: Vector3?): CFrame
	local d = b - a
	if d.Magnitude < 1e-4 then
		return CFrame.new(a)
	end
	local u = up or UP
	if math.abs(d.Unit:Dot(u)) > 0.985 then
		u = X_AXIS
	end
	return CFrame.lookAt(a, b, u)
end

-- Cylindre (axe X de Roblox) allongé de a vers b.
local function tubeCF(a: Vector3, b: Vector3): CFrame
	return look((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
end

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- disque de cylindre posé à plat

------------------------------------------------------------------------
-- Pièces d'effet
------------------------------------------------------------------------

local function newPart(size: Vector3, cf: CFrame, color: Color3, life: number, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props and props.Shape then
		part.Shape = props.Shape
	end
	part.Size = size
	part.CFrame = cf
	part.Color = color
	if props then
		local target: any = part
		for key, value in props do
			if key ~= "Shape" then
				target[key] = value
			end
		end
	end
	part.Parent = fxFolder
	track(part, life)
	return part
end

local function ball(pos: Vector3, diameter: number, color: Color3, life: number, transparency: number?, material: Enum.Material?): Part
	return newPart(Vector3.one * diameter, CFrame.new(pos), color, life, {
		Shape = Enum.PartType.Ball,
		Transparency = transparency or 0,
		Material = material or Enum.Material.Neon,
	})
end

local function setBall(part: BasePart, pos: Vector3, diameter: number, transparency: number?)
	part.Size = Vector3.one * math.max(diameter, 0.05)
	part.CFrame = CFrame.new(pos)
	if transparency then
		part.Transparency = math.clamp(transparency, 0, 1)
	end
end

-- Ellipsoïde (SpecialMesh Sphere) : têtes de rayon, flammes étirées, ombres.
local function ellipsoid(cf: CFrame, size: Vector3, color: Color3, life: number, transparency: number?, material: Enum.Material?): Part
	local part = newPart(size, cf, color, life, { Transparency = transparency or 0, Material = material or Enum.Material.Neon })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function tube(a: Vector3, b: Vector3, diameter: number, color: Color3, life: number, transparency: number?, material: Enum.Material?): Part
	local length = math.max((b - a).Magnitude, 0.05)
	return newPart(Vector3.new(length, diameter, diameter), tubeCF(a, b), color, life, {
		Shape = Enum.PartType.Cylinder,
		Transparency = transparency or 0,
		Material = material or Enum.Material.Neon,
	})
end

local function setTube(part: BasePart, a: Vector3, b: Vector3, diameter: number, transparency: number?)
	part.Size = Vector3.new(math.max((b - a).Magnitude, 0.05), math.max(diameter, 0.05), math.max(diameter, 0.05))
	part.CFrame = tubeCF(a, b)
	if transparency then
		part.Transparency = math.clamp(transparency, 0, 1)
	end
end

------------------------------------------------------------------------
-- Lumières et particules (plafonnées selon la qualité)
------------------------------------------------------------------------

local activeLights = 0
local particleBudget = 0

local function flashLight(pos: Vector3, color: Color3, range: number, brightness: number, life: number)
	if activeLights >= Q.lights then
		return
	end
	activeLights += 1
	local holder = Instance.new("Attachment")
	holder.CFrame = CFrame.new(pos)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.clamp(range, 4, 60)
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = holder
	holder.Parent = anchor
	track(holder, life + 0.1)
	job(life, function(p)
		light.Brightness = brightness * (1 - p)
		return nil
	end)
	after(life, function()
		activeLights -= 1
	end)
end

local function numberSeq(a: number, b: number, c: number?): NumberSequence
	if c then
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.35, b), NumberSequenceKeypoint.new(1, c) })
	end
	return NumberSequence.new(a, b)
end

-- Configure un ParticleEmitter à partir d'une table d'options.
local function configureEmitter(e: ParticleEmitter, o)
	e.Texture = o.texture or SPARKLE
	local c1 = o.color or WHITE
	e.Color = ColorSequence.new(c1, o.color2 or c1)
	e.LightEmission = o.light or 1
	e.LightInfluence = (o.light == 0) and 1 or 0
	e.Brightness = o.brightness or 1.5
	local size = o.size or 1
	if o.grow then
		e.Size = numberSeq(size * 0.4, size * 1.1, size * 1.7)
	else
		e.Size = numberSeq(size, size * 0.7, 0)
	end
	e.Transparency = numberSeq(o.alpha or 0, (o.alpha or 0) * 0.5 + 0.3, 1)
	local life = o.life or 0.6
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(o.speedMin or 4, o.speed or 12)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.EmissionDirection = o.direction or Enum.NormalId.Top
	e.Acceleration = o.gravity or Vector3.zero
	e.Drag = o.drag or 3
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rotation = NumberRange.new(0, 360)
	e.ZOffset = o.zoffset or 0.5
	if o.inward then
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	end
	if o.rate then
		e.Rate = o.rate * Q.particles
	end
end

-- Gerbe de particules ponctuelle.
local function emit(pos: Vector3, o)
	local count = math.floor((o.count or 20) * Q.particles * (o.detail or 1) + 0.5)
	if count <= 0 or particleBudget <= 0 then
		return
	end
	particleBudget -= count
	local holder = Instance.new("Attachment")
	holder.CFrame = CFrame.new(pos)
	local e = Instance.new("ParticleEmitter")
	configureEmitter(e, o)
	e.Enabled = false
	e.Parent = holder
	holder.Parent = anchor
	e:Emit(count)
	track(holder, (o.life or 0.6) + 0.4)
end

-- Émetteur continu attaché à une pièce (charge, traînées, auras).
local function attachEmitter(parent: Instance, o): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	configureEmitter(e, o)
	e.Enabled = true
	e.Parent = parent
	return e
end

local function addTrail(part: BasePart, color: Color3, width: number, lifetime: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(lighten(color, 0.6), color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Lifetime = lifetime
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
end

------------------------------------------------------------------------
-- Anneaux lumineux (SurfaceGui + UIStroke arrondi : un vrai cercle net pour 1 seule pièce)
------------------------------------------------------------------------

local RING_RES = 256

type Ring = { part: BasePart, frames: { Frame }, strokes: { UIStroke }, flat: boolean, radius: number, thickness: number }

local function setRing(r: Ring, radius: number, thickness: number, transparency: number?)
	radius = math.max(radius, 0.1)
	thickness = math.clamp(thickness, 0.02, radius * 1.6)
	local half = radius + thickness
	local size = half * 2
	r.part.Size = r.flat and Vector3.new(size, 0.05, size) or Vector3.new(size, size, 0.05)
	local frameScale = math.max(radius - thickness / 2, 0.01) / half
	local px = thickness / half * (RING_RES / 2)
	for _, frame in r.frames do
		frame.Size = UDim2.fromScale(frameScale, frameScale)
	end
	for _, stroke in r.strokes do
		stroke.Thickness = px
		if transparency then
			stroke.Transparency = math.clamp(transparency, 0, 1)
		end
	end
	if transparency then
		for _, frame in r.frames do
			if frame:GetAttribute("Fill") then
				frame.BackgroundTransparency = math.clamp(frame:GetAttribute("Fill") + (1 - frame:GetAttribute("Fill")) * transparency, 0, 1)
			end
		end
	end
	r.radius = radius
	r.thickness = thickness
end

-- opts : flat (au sol), fill (transparence du disque intérieur), arc (anneau ouvert en dégradé),
-- brightness, rotation (rotation du dégradé).
local function ring(cf: CFrame, radius: number, thickness: number, color: Color3, life: number, opts: { [string]: any }?): Ring
	local o = opts or {}
	local flat = o.flat == true
	local part = newPart(Vector3.one, cf, color, life, { Transparency = 1 })
	local r: Ring = { part = part, frames = {}, strokes = {}, flat = flat, radius = radius, thickness = thickness }
	local faces = flat and { Enum.NormalId.Top } or { Enum.NormalId.Front, Enum.NormalId.Back }
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(RING_RES, RING_RES)
		gui.LightInfluence = 0
		gui.Brightness = o.brightness or 2.5
		gui.ClipsDescendants = false
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.BackgroundColor3 = o.fillColor or color
		frame.BackgroundTransparency = o.fill or 1
		if o.fill then
			frame:SetAttribute("Fill", o.fill)
		end
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = frame
		if o.arc then
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 0.15),
				NumberSequenceKeypoint.new(0.62, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Rotation = o.rotation or 0
			gradient.Parent = stroke
		end
		frame.Parent = gui
		gui.Parent = part
		table.insert(r.frames, frame)
		table.insert(r.strokes, stroke)
	end
	setRing(r, radius, thickness, o.transparency or 0)
	return r
end

local function setRingRotation(r: Ring, degrees: number)
	for _, stroke in r.strokes do
		local gradient = stroke:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Rotation = degrees % 360
		end
	end
end

------------------------------------------------------------------------
-- Briques d'effets réutilisables
------------------------------------------------------------------------

-- Point d'impact : cœur blanc qui éclate + halo coloré + étoile de pointes + lumière.
local function impactFlash(pos: Vector3, size: number, color: Color3, life: number?, spikes: number?)
	local l = life or 0.3
	local core = ball(pos, size * 0.5, lighten(color, 0.7), l, 0)
	local halo = ball(pos, size * 0.8, color, l, 0.4)
	job(l, function(p)
		local e = easeOut(p)
		setBall(core, pos, size * (0.5 + 0.6 * e), p * 1.1)
		setBall(halo, pos, size * (0.8 + 1.5 * e), 0.4 + 0.6 * p)
		return nil
	end)
	local n = spikes or 6
	if n > 0 then
		local list = {}
		for _ = 1, n do
			local dir = randomUnit()
			local length = size * rng:NextNumber(0.9, 1.7)
			local spike = newPart(Vector3.new(0.12, 0.12, 0.1) * size, look(pos, pos + dir), lighten(color, 0.45), l)
			table.insert(list, { part = spike, dir = dir, length = length })
		end
		job(l * 0.85, function(p)
			local e = easeOut(p)
			for _, item in list do
				local length = item.length * (0.25 + 0.9 * e)
				local w = 0.13 * size * (1 - p)
				item.part.Size = Vector3.new(w, w, length)
				item.part.CFrame = look(pos, pos + item.dir) * CFrame.new(0, 0, -(length / 2 + size * 0.25 * e))
				item.part.Transparency = p * 0.8
			end
			return nil
		end)
	end
	flashLight(pos, color, size * 5, 5, l + 0.1)
end

-- Gerbe d'étincelles.
local function sparks(pos: Vector3, color: Color3, count: number, speed: number, size: number?)
	emit(pos, {
		texture = SPARKS,
		color = lighten(color, 0.5),
		color2 = color,
		count = count,
		size = size or 0.5,
		speedMin = speed * 0.4,
		speed = speed,
		life = 0.5,
		drag = 4,
		gravity = Vector3.new(0, -20, 0),
	})
end

-- Onde de choc au sol : anneau net qui s'agrandit.
local function shockRing(groundPos: Vector3, radius: number, color: Color3, duration: number, thickness: number?)
	local th = thickness or math.max(0.4, radius * 0.09)
	local r = ring(CFrame.new(groundPos + Vector3.new(0, 0.18, 0)), radius * 0.15, th, color, duration, { flat = true, brightness = 3 })
	job(duration, function(p)
		local e = easeOut(p)
		setRing(r, radius * (0.15 + 0.85 * e), th * (1 - 0.65 * p), p ^ 1.4)
		return nil
	end)
end

-- Anneau vertical (onde dans l'air) qui s'agrandit, face à une direction.
local function airRing(pos: Vector3, facing: Vector3, radius: number, color: Color3, duration: number, thickness: number?)
	local th = thickness or radius * 0.12
	local r = ring(look(pos, pos + facing), radius * 0.2, th, color, duration, { brightness = 3 })
	job(duration, function(p)
		setRing(r, radius * (0.2 + 0.8 * easeOut(p)), th * (1 - 0.6 * p), p ^ 1.3)
		return nil
	end)
end

-- Dôme d'explosion : cœur blanc + coque colorée + reflet en champ de force.
local function dome(pos: Vector3, radius: number, color: Color3, duration: number, forcefield: boolean?)
	local core = ball(pos, radius * 0.4, lighten(color, 0.6), duration, 0)
	local shell = ball(pos, radius * 0.6, color, duration, 0.4)
	local ff = forcefield and ball(pos, radius * 0.6, lighten(color, 0.3), duration, 0, Enum.Material.ForceField) or nil
	job(duration, function(p)
		local e = easeOut(p)
		setBall(core, pos, radius * (0.4 + 0.7 * e), math.min(1, p * 2))
		setBall(shell, pos, radius * (0.6 + 1.4 * e), 0.4 + 0.6 * p)
		if ff then
			setBall(ff, pos, radius * (0.7 + 1.5 * e), p)
		end
		return nil
	end)
end

-- Poussière soulevée au sol.
local function dust(groundPos: Vector3, radius: number, count: number, tint: Color3?)
	emit(groundPos + Vector3.new(0, 0.6, 0), {
		texture = SMOKE,
		color = tint or Color3.fromRGB(196, 182, 160),
		color2 = Color3.fromRGB(150, 140, 125),
		light = 0,
		alpha = 0.35,
		count = count,
		size = math.max(1.2, radius * 0.35),
		grow = true,
		speedMin = radius * 1.2,
		speed = radius * 2.4,
		life = 1.3,
		drag = 4,
		spread = Vector2.new(85, 85),
		gravity = Vector3.new(0, 1.5, 0),
	})
end

-- Fissures au sol : fentes sombres avec un cœur lumineux, en zigzag depuis le centre.
local function cracks(center: Vector3, length: number, color: Color3, count: number, life: number)
	local parts = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * length * 0.12
		local segments = 3
		local w = math.max(0.25, length * 0.07)
		for s = 1, segments do
			angle += rng:NextNumber(-0.55, 0.55)
			local seg = length / segments * rng:NextNumber(0.7, 1.1)
			local nextPos = pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * seg
			local width = w * (1 - (s - 1) / segments * 0.6)
			local mid = (pos + nextPos) / 2
			local cf = look(mid, nextPos)
			local slit = newPart(Vector3.new(width, 0.06, seg + width * 0.5), cf + Vector3.new(0, 0.07, 0), SCORCH, life, { Material = Enum.Material.Slate })
			local glow = newPart(Vector3.new(width * 0.38, 0.07, seg + width * 0.3), cf + Vector3.new(0, 0.1, 0), color, life)
			table.insert(parts, { slit = slit, glow = glow })
			pos = nextPos
		end
	end
	job(life, function(p)
		for _, item in parts do
			item.glow.Transparency = math.clamp((p - 0.1) * 1.3, 0, 1)
			item.slit.Transparency = math.clamp((p - 0.65) / 0.35, 0, 1)
		end
		return nil
	end)
end

-- Cratère : sol brûlé + cœur incandescent + roches soulevées autour.
local function crater(groundPos: Vector3, radius: number, color: Color3, life: number, detail: number, rockColor: Color3?)
	local scorch = newPart(Vector3.new(0.1, radius * 2.2, radius * 2.2), CFrame.new(groundPos + Vector3.new(0, 0.05, 0)) * FLAT, SCORCH, life, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Basalt,
		Transparency = 0.1,
	})
	local lava = newPart(Vector3.new(0.12, radius * 0.9, radius * 0.9), CFrame.new(groundPos + Vector3.new(0, 0.08, 0)) * FLAT, color, life, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.25,
	})
	local rocks = {}
	if Q.crater then
		local count = math.max(4, math.floor(10 * detail + 0.5))
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local size = radius * rng:NextNumber(0.22, 0.4)
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local base = groundPos + outward * radius * rng:NextNumber(0.85, 1.05)
			local final = CFrame.new(base, base + outward) * CFrame.Angles(rng:NextNumber(0.45, 0.85), 0, rng:NextNumber(-0.3, 0.3))
			local tone = (rockColor or ROCK):Lerp(BLACK, rng:NextNumber(0, 0.3))
			local rock = newPart(Vector3.new(size * 1.3, size * 0.7, size), final - Vector3.new(0, size, 0), tone, life, { Material = Enum.Material.Slate })
			table.insert(rocks, { part = rock, final = final, size = size })
		end
	end
	job(life, function(p, elapsed)
		local rise = math.min(1, elapsed / 0.12)
		local fade = math.clamp((p - 0.7) / 0.3, 0, 1)
		for _, item in rocks do
			item.part.CFrame = item.final - Vector3.new(0, item.size * (1 - easeOut(rise)) + item.size * 0.8 * fade, 0)
			item.part.Transparency = fade
		end
		lava.Transparency = 0.25 + 0.75 * math.min(1, p * 1.6)
		scorch.Transparency = 0.1 + 0.9 * fade
		return nil
	end)
end

-- Débris : roches projetées qui retombent, rebondissent puis s'effacent.
local function debris(origin: Vector3, groundY: number, count: number, power: number, life: number, color: Color3?)
	if count <= 0 then
		return
	end
	local list = {}
	for _ = 1, math.floor(count * Q.debris + 0.5) do
		local size = rng:NextNumber(0.25, 0.75) * math.clamp(power / 14, 0.6, 2.4)
		local dir = flatDir(randomUnit())
		local tone = (color or ROCK):Lerp(BLACK, rng:NextNumber(0, 0.35))
		local rock = newPart(Vector3.new(size, size * rng:NextNumber(0.6, 1), size * rng:NextNumber(0.7, 1.2)), CFrame.new(origin), tone, life, { Material = Enum.Material.Slate })
		table.insert(list, {
			part = rock,
			pos = origin + dir * rng:NextNumber(0, 1),
			vel = dir * power * rng:NextNumber(0.35, 1) + Vector3.new(0, power * rng:NextNumber(0.7, 1.3), 0),
			rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12)),
			half = size * 0.4,
		})
	end
	job(life, function(p, _, dt)
		local fade = math.clamp((p - 0.75) / 0.25, 0, 1)
		for _, item in list do
			item.vel -= Vector3.new(0, 70 * dt, 0)
			local pos = item.pos + item.vel * dt
			if pos.Y < groundY + item.half then
				pos = Vector3.new(pos.X, groundY + item.half, pos.Z)
				item.vel = Vector3.new(item.vel.X * 0.55, math.abs(item.vel.Y) * 0.3, item.vel.Z * 0.55)
				item.spin *= 0.6
			end
			item.pos = pos
			item.rot *= CFrame.Angles(item.spin.X * dt, item.spin.Y * dt, item.spin.Z * dt)
			item.part.CFrame = CFrame.new(pos) * item.rot
			item.part.Transparency = fade
		end
		return nil
	end)
end

-- Éclair à branches : cœur blanc + halo coloré, avec scintillement (le tracé change).
local function boltPath(from: Vector3, to: Vector3, segments: number, jitter: number): { Vector3 }
	local points = { from }
	local delta = to - from
	for i = 1, segments - 1 do
		local t = i / segments
		points[i + 1] = from + delta * t + randomUnit() * jitter * (0.45 + 0.55 * math.sin(t * math.pi))
	end
	points[segments + 1] = to
	return points
end

local function bolt(from: Vector3, to: Vector3, color: Color3, width: number, life: number, opts: { [string]: any }?)
	local o = opts or {}
	local segments = o.segments or 8
	local jitter = o.jitter or ((to - from).Magnitude * 0.08 + 0.4)
	local branches = o.branches or 2
	local flicker = o.flicker or 1
	local core = o.core or lighten(color, 0.8)
	local halo = o.halo ~= false
	local current = {}
	local function segment(a: Vector3, b: Vector3, w: number, l: number)
		local length = (b - a).Magnitude
		if length < 0.01 then
			return
		end
		local cf = look((a + b) / 2, b)
		table.insert(current, newPart(Vector3.new(w * 0.45, w * 0.45, length + w * 0.3), cf, core, l))
		if halo then
			table.insert(current, newPart(Vector3.new(w * 1.6, w * 1.6, length + w), cf, color, l, { Transparency = 0.62 }))
		end
	end
	local function draw(l: number)
		for _, part in current do
			kill(part)
		end
		table.clear(current)
		local points = boltPath(from, to, segments, jitter)
		for i = 1, #points - 1 do
			segment(points[i], points[i + 1], width, l)
		end
		for _ = 1, branches do
			local k = rng:NextInteger(2, math.max(2, #points - 1))
			local start = points[k]
			local dir = ((to - from).Unit * 0.5 + randomUnit()).Unit
			local branchEnd = start + dir * (to - from).Magnitude * rng:NextNumber(0.15, 0.35)
			local sub = boltPath(start, branchEnd, 3, jitter * 0.5)
			for i = 1, #sub - 1 do
				segment(sub[i], sub[i + 1], width * 0.5, l)
			end
		end
	end
	local slice = life / (flicker + 1)
	draw(life)
	for k = 1, flicker do
		after(slice * k, function()
			draw(life - slice * k)
		end)
	end
	after(life, function()
		for _, part in current do
			kill(part)
		end
		table.clear(current)
	end)
end

-- Croissant de lame (tranchant) : segments Neon cœur + halo, qui balayent puis s'élargissent.
-- cf : centre ; l'arc est dans le plan XZ local, tourné vers -Z.
local function crescent(cf: CFrame, radius: number, thickness: number, color: Color3, life: number, opts: { [string]: any }?)
	local o = opts or {}
	local n = o.segments or 12
	local arc = math.rad(o.arc or 150)
	local sweep = o.sweep or life * 0.3
	local core = o.core or lighten(color, 0.85)
	local reverse = o.reverse == true
	local segs = {}
	for i = 1, n do
		local t = (i - 0.5) / n
		local a = -arc / 2 + arc * t
		local edge = 1 - math.abs(t - 0.5) * 2
		local w = thickness * (0.25 + 0.75 * math.sqrt(edge))
		local segLen = radius * arc / n * 1.2
		local c = newPart(Vector3.new(segLen, 0.08, w * 0.42), cf, core, life, { Transparency = 1 })
		local h = newPart(Vector3.new(segLen, 0.05, w), cf, color, life, { Transparency = 1 })
		table.insert(segs, { core = c, halo = h, a = a, w = w, t = reverse and (1 - t) or t, len = segLen })
	end
	job(life, function(p, elapsed)
		local grow = 1 + 0.25 * easeOut(p)
		local fade = math.clamp((elapsed - sweep) / math.max(life - sweep, 0.01), 0, 1)
		for _, s in segs do
			local visible = elapsed >= s.t * sweep
			local r = radius * grow
			local pos = cf * CFrame.new(math.sin(s.a) * r, 0, -math.cos(s.a) * r) * CFrame.Angles(0, -s.a, 0)
			s.core.CFrame = pos
			s.halo.CFrame = pos
			s.core.Size = Vector3.new(s.len * grow, 0.08, s.w * 0.42 * (1 - fade * 0.7))
			s.halo.Size = Vector3.new(s.len * grow, 0.05, s.w * (1 - fade * 0.5))
			s.core.Transparency = visible and fade or 1
			s.halo.Transparency = visible and (0.35 + 0.65 * fade) or 1
		end
		return nil
	end)
end

-- Lame droite (entaille rectiligne) de a vers b : apparaît en balayant puis s'amincit.
local function blade(a: Vector3, b: Vector3, width: number, color: Color3, life: number, up: Vector3?, core: Color3?)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return
	end
	local frame = look(a, b, up or UP)
	local c = newPart(Vector3.new(width * 0.3, 0.06, 0.05), frame, core or lighten(color, 0.85), life)
	local h = newPart(Vector3.new(width, 0.04, 0.05), frame, color, life, { Transparency = 0.4 })
	local sweep = math.min(0.07, life * 0.3)
	job(life, function(_, elapsed)
		local grow = math.min(1, elapsed / sweep)
		local fade = math.clamp((elapsed - sweep) / math.max(life - sweep, 0.01), 0, 1)
		local l = length * easeOut(grow)
		local cf = frame * CFrame.new(0, 0, -l / 2)
		c.Size = Vector3.new(width * 0.3 * (1 - fade), 0.06, math.max(l, 0.05))
		h.Size = Vector3.new(width * (1 - fade * 0.6), 0.04, math.max(l, 0.05))
		c.CFrame = cf
		h.CFrame = cf
		c.Transparency = fade * 0.9
		h.Transparency = 0.4 + 0.6 * fade
		return nil
	end)
end

-- Entaille marquée au sol (après un tranchant).
local function groundCut(a: Vector3, b: Vector3, width: number, color: Color3, life: number)
	local cf = look((a + b) / 2, b)
	local length = (b - a).Magnitude
	local slit = newPart(Vector3.new(width, 0.06, length), cf + Vector3.new(0, 0.07, 0), SCORCH, life, { Material = Enum.Material.Slate })
	local glow = newPart(Vector3.new(width * 0.35, 0.07, length * 0.95), cf + Vector3.new(0, 0.1, 0), color, life)
	job(life, function(p)
		glow.Transparency = math.min(1, p * 1.4)
		slit.Transparency = math.clamp((p - 0.6) / 0.4, 0, 1)
		return nil
	end)
end

-- Orbe d'énergie en couches (cœur, corps, halo, lumière) qu'on peut déplacer.
type Orb = { core: BasePart, body: BasePart, halo: BasePart, shell: BasePart?, light: PointLight?, radius: number }

local function newOrb(pos: Vector3, radius: number, color: Color3, coreColor: Color3, life: number, shell: boolean?): Orb
	local orb: Orb = {
		core = ball(pos, radius * 1.1, coreColor, life, 0),
		body = ball(pos, radius * 2, color, life, 0.12),
		halo = ball(pos, radius * 3.2, color, life, 0.75),
		shell = shell and ball(pos, radius * 2.5, lighten(color, 0.3), life, 0.1, Enum.Material.ForceField) or nil,
		light = nil,
		radius = radius,
	}
	if activeLights < Q.lights then
		activeLights += 1
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = math.clamp(radius * 9, 6, 40)
		light.Brightness = 3
		light.Parent = orb.body
		orb.light = light
		after(life, function()
			activeLights -= 1
		end)
	end
	return orb
end

local function moveOrb(orb: Orb, pos: Vector3, radius: number, fade: number?)
	local f = fade or 0
	setBall(orb.core, pos, radius * 1.1, f)
	setBall(orb.body, pos, radius * 2, 0.12 + 0.88 * f)
	setBall(orb.halo, pos, radius * 3.2 * (1 + 0.06 * math.sin(now() * 30)), 0.75 + 0.25 * f)
	if orb.shell then
		setBall(orb.shell, pos, radius * 2.5, f)
	end
	if orb.light then
		orb.light.Range = math.clamp(radius * 9, 6, 40)
	end
	orb.radius = radius
end

local function killOrb(orb: Orb)
	kill(orb.core)
	kill(orb.body)
	kill(orb.halo)
	kill(orb.shell)
end

------------------------------------------------------------------------
-- Écran : flash, traits de vitesse, secousse (modérés, désactivables)
------------------------------------------------------------------------

local shakeAmount = 0
local shakeUntil = 0

local function shake(intensity: number, duration: number)
	if not shakeEnabled() then
		return
	end
	shakeAmount = math.max(shakeAmount, math.min(intensity, 2.5))
	shakeUntil = math.max(shakeUntil, now() + math.min(duration, 1.2))
end

local function screenFlash(color: Color3, alpha: number, duration: number)
	if not screenGui or not flashEnabled() or alpha <= 0 then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "FxFlash"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - math.min(alpha * 0.7, 0.3)
	frame.BorderSizePixel = 0
	frame.ZIndex = 40
	frame.Active = false
	frame.Parent = screenGui
	track(frame, duration + 0.1)
	local start = frame.BackgroundTransparency
	job(duration, function(p)
		frame.BackgroundTransparency = start + (1 - start) * easeIn(p)
		return nil
	end)
end

-- Traits de vitesse façon manga, autour de l'écran.
local function speedLines(color: Color3, duration: number)
	if not screenGui or not flashEnabled() then
		return
	end
	local holder = Instance.new("Frame")
	holder.Name = "FxSpeedLines"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 39
	holder.Parent = screenGui
	track(holder, duration + 0.1)
	local lines = {}
	local count = math.floor(26 * (Q.particles + 0.3))
	for i = 1, count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Rotation = i / count * 360 + rng:NextNumber(-5, 5)
		line.Size = UDim2.new(0.9, 0, 0, rng:NextInteger(2, 6))
		line.BackgroundColor3 = lighten(color, 0.7)
		line.BorderSizePixel = 0
		line.ZIndex = 39
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.75, 0.35),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		gradient.Parent = line
		line.Parent = holder
		table.insert(lines, { line = line, offset = rng:NextNumber(0, 1) })
	end
	job(duration, function(p, elapsed)
		for _, item in lines do
			local flick = (math.floor(elapsed * 30 + item.offset * 7) % 3 == 0) and 0.5 or 0
			item.line.BackgroundTransparency = math.clamp(p * 1.1 + flick, 0, 1)
		end
		return nil
	end)
end

------------------------------------------------------------------------
-- Textes : chiffres de dégâts, nom de l'attaque spéciale
------------------------------------------------------------------------

local function tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function fadeAndDestroy(part: BasePart, duration: number, goals: { [string]: any }?)
	local g = goals or {}
	g.Transparency = 1
	tween(part, duration, g)
	track(part, duration)
end

-- Texte flottant (dégâts, "LEVEL UP!", "+12 💰"...)
local function floatingText(position: Vector3, text: string, color: Color3, size: number?, duration: number?)
	local d = duration or 0.9
	local holder = newPart(Vector3.one * 0.2, CFrame.new(position), WHITE, d, { Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 64)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = darken(color, 0.85)
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3 * (size or 1)
	scale.Parent = label
	tween(scale, 0.18, { Scale = 1 * (size or 1) }, Enum.EasingStyle.Back)
	tween(holder, d, { CFrame = holder.CFrame + Vector3.new(rng:NextNumber(-1.5, 1.5), 4, 0) })
	task.delay(d * 0.6, function()
		if label.Parent then
			tween(label, d * 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- Nom de l'attaque spéciale en grand au-dessus du perso (façon anime).
local function banner(model: Model, text: string, color: Color3, duration: number)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local scale = model:GetAttribute("BaseScale") or 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "FxBanner"
	gui.Size = UDim2.fromOffset(460, 96)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4 * scale, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Adornee = head
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.55)
	back.Size = UDim2.fromScale(0.96, 0.62)
	back.Rotation = -3
	back.BackgroundColor3 = WHITE
	back.BorderSizePixel = 0
	local backGradient = Instance.new("UIGradient")
	backGradient.Color = ColorSequence.new(darken(color, 0.55), Color3.fromRGB(14, 10, 22))
	backGradient.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.15), NumberSequenceKeypoint.new(0.88, 0.15), NumberSequenceKeypoint.new(1, 1) })
	backGradient.Parent = back
	local backStroke = Instance.new("UIStroke")
	backStroke.Color = color
	backStroke.Thickness = 2
	backStroke.Transparency = 0.2
	backStroke.Parent = back
	back.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.52)
	label.Size = UDim2.fromScale(0.92, 0.72)
	label.Rotation = -3
	label.Text = string.upper(text) .. " !"
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = WHITE
	local textGradient = Instance.new("UIGradient")
	textGradient.Color = ColorSequence.new(WHITE, lighten(color, 0.35))
	textGradient.Rotation = 90
	textGradient.Parent = label
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = darken(color, 0.8)
	textStroke.Thickness = 3
	textStroke.Parent = label
	label.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.2
	uiScale.Parent = back
	local uiScaleText = Instance.new("UIScale")
	uiScaleText.Scale = 0.2
	uiScaleText.Parent = label
	gui.Parent = fxFolder
	track(gui, duration + 0.1)
	job(duration, function(_, elapsed)
		local pop = elapsed < 0.12 and (0.2 + 1.05 * elapsed / 0.12) or math.max(1, 1.25 - (elapsed - 0.12) * 2)
		uiScale.Scale = pop
		uiScaleText.Scale = pop
		local fade = math.clamp((elapsed - (duration - 0.3)) / 0.3, 0, 1)
		label.TextTransparency = fade
		textStroke.Transparency = fade
		backStroke.Transparency = 0.2 + 0.8 * fade
		back.BackgroundTransparency = fade
		return nil
	end)
end

------------------------------------------------------------------------
-- Impact sur l'ennemi : flash blanc (Highlight) plafonné
------------------------------------------------------------------------

local highlights: { [Instance]: Highlight } = {}
local highlightCount = 0
local highlightToken: { [Instance]: any } = {}

local function hitFlash(model: Instance?, color: Color3)
	if not model or not model.Parent or not model:IsA("Model") then
		return
	end
	local h = highlights[model]
	if not h then
		if highlightCount >= Q.highlights then
			return
		end
		h = Instance.new("Highlight")
		h.Name = "FxHit"
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = model
		h.Parent = fxFolder
		highlights[model] = h
		highlightCount += 1
	end
	local highlight = h :: Highlight
	highlight.FillColor = WHITE
	highlight.OutlineColor = lighten(color, 0.3)
	highlight.FillTransparency = 0.15
	highlight.OutlineTransparency = 0
	local token = {}
	highlightToken[model] = token
	job(0.22, function(p)
		if highlightToken[model] ~= token then
			return true
		end
		highlight.FillTransparency = 0.15 + 0.85 * p
		highlight.OutlineTransparency = p
		if p >= 1 then
			highlights[model] = nil
			highlightToken[model] = nil
			highlightCount -= 1
			highlight:Destroy()
		end
		return nil
	end)
end

------------------------------------------------------------------------
-- Sol sous un point (couleur des roches et hauteur réelle si possible)
------------------------------------------------------------------------

local rayParams: RaycastParams? = nil

local function groundAt(pos: Vector3, fallbackY: number): (number, Color3?)
	local ok, result = pcall(function()
		if not rayParams then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.IgnoreWater = true
			rayParams = params
		end
		local params = rayParams :: RaycastParams
		local exclude = { fxFolder }
		for _, name in { "Followers", "Enemies" } do
			local folder = Workspace:FindFirstChild(name)
			if folder then
				table.insert(exclude, folder)
			end
		end
		if player and player.Character then
			table.insert(exclude, player.Character)
		end
		params.FilterDescendantsInstances = exclude
		return Workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), params)
	end)
	if ok and result and result.Instance then
		local hit = result.Instance
		local color = hit:IsA("BasePart") and not hit:IsA("Terrain") and hit.Color or nil
		if hit.Parent and hit.Parent:IsA("Model") and hit.Parent:FindFirstChildOfClass("Humanoid") then
			return fallbackY, nil
		end
		return result.Position.Y, color
	end
	return fallbackY, nil
end

------------------------------------------------------------------------
-- Contexte d'une attaque
------------------------------------------------------------------------

type Ctx = { [string]: any }

local function rootOf(model: Instance?): BasePart?
	if model and model.Parent and model:IsA("Model") then
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
	end
	return nil
end

local function makeCtx(data, attacker: Model?, target: Instance?, sig, mine: boolean, detail: number): Ctx
	local to: Vector3 = data.position
	local attackerScale = attacker and attacker:GetAttribute("BaseScale") or 1
	local targetHeight = (target and target:IsA("Model") and target:GetAttribute("RootHeight")) or 2.6
	local groundY, groundColor = groundAt(to, to.Y - targetHeight)
	local attackerRoot = rootOf(attacker)
	local from0: Vector3 = data.from or (to + Vector3.new(4, 0, 4))
	if attackerRoot then
		from0 = attackerRoot.CFrame.Position
	end
	local ctx: Ctx = {
		sig = sig,
		attacker = attacker,
		target = target,
		mine = mine,
		special = data.special == true,
		detail = detail,
		s = attackerScale * (sig.size or 1),
		scale = attackerScale,
		color = sig.color or data.color or WHITE,
		color2 = sig.color2 or lighten(sig.color or WHITE, 0.6),
		core = sig.core or lighten(sig.color or WHITE, 0.85),
		to = to,
		groundY = groundY,
		ground = Vector3.new(to.X, groundY, to.Z),
		rockColor = groundColor and darken(groundColor, 0.15) or ROCK,
		data = data,
		impacted = false,
	}
	ctx.root = function(): Vector3
		local root = rootOf(attacker)
		if root and attacker and attacker.Parent then
			from0 = root.CFrame.Position
		end
		return from0
	end
	ctx.feet = function(): Vector3
		local h = attacker and attacker:GetAttribute("RootHeight") or 2.6
		return ctx.root() - Vector3.new(0, h, 0)
	end
	ctx.hand = function(): Vector3
		if attacker and attacker.Parent then
			local arm = attacker:FindFirstChild("Right Arm")
			if arm and arm:IsA("BasePart") then
				return (arm.CFrame * CFrame.new(0, -arm.Size.Y * 0.55, 0)).Position
			end
			local root = rootOf(attacker)
			if root then
				return (root.CFrame * CFrame.new(0.9 * attackerScale, 0, -1.4 * attackerScale)).Position
			end
		end
		return from0 + flatDir(to - from0) * 1.4 + Vector3.new(0, 0.3, 0)
	end
	ctx.head = function(): Vector3
		local head = attacker and attacker:FindFirstChild("Head")
		if head and head:IsA("BasePart") and attacker and attacker.Parent then
			return head.CFrame.Position
		end
		return ctx.root() + Vector3.new(0, 1.5 * attackerScale, 0)
	end
	-- Point de départ devant le perso, à hauteur de poitrine.
	ctx.front = function(dist: number?): Vector3
		local root = ctx.root()
		return root + flatDir(to - root) * (dist or 1.4) * attackerScale + Vector3.new(0, 0.4 * attackerScale, 0)
	end
	ctx.dir = function(): Vector3
		return flatDir(to - ctx.root())
	end
	ctx.n = function(x: number): number
		return math.max(1, math.floor(x * detail + 0.5))
	end
	-- Coup porté : chiffre de dégâts + flash de l'ennemi (une seule fois).
	ctx.impact = function()
		if ctx.impacted then
			return
		end
		ctx.impacted = true
		hitFlash(target, ctx.color)
		local amountText = Formulas.formatNumber(data.amount or 0)
		local textPos = to + Vector3.new(0, 2 + targetHeight * 0.4, 0)
		if data.crit then
			floatingText(textPos, "CRITIQUE ! " .. amountText, Color3.fromRGB(255, 70, 50), 1.35, 1.1)
		elseif ctx.special then
			floatingText(textPos, amountText, lighten(ctx.color, 0.35), mine and 1.3 or 0.85, 1.1)
		else
			floatingText(textPos, amountText, mine and Color3.fromRGB(255, 240, 120) or Color3.fromRGB(230, 230, 230), mine and 0.95 or 0.7)
		end
	end
	-- Flash + secousse : uniquement pour TES persos.
	ctx.screen = function(mult: number?)
		if not mine then
			return
		end
		local m = mult or 1
		shake((sig.shake or 1) * m, 0.25 + 0.2 * m)
		screenFlash(lighten(ctx.color, 0.35), (sig.flash or 0) * m, 0.35)
	end
	return ctx
end

------------------------------------------------------------------------
-- Charge avant les attaques spéciales
------------------------------------------------------------------------

-- Aura de charge : cercle au sol qui tourne, flammes d'aura, lumière qui monte.
-- opts.orb : rayon de l'orbe qui se forme ; opts.at : "hand" | "above" | "front" ; opts.bolts : crépitements.
-- onDone(orb?) est appelée à la fin de la charge (l'orbe éventuelle est transmise à l'attaque).
local function chargeUp(ctx: Ctx, opts: { [string]: any }, onDone: (Orb?) -> ())
	local s = ctx.s
	local duration = (ctx.sig.charge or 0.5) * (ctx.mine and 1 or 0.75)
	local color = opts.color or ctx.color
	local life = duration + 0.25
	if ctx.mine and ctx.attacker then
		banner(ctx.attacker, ctx.sig.name or "Attaque spéciale", color, duration + 1.1)
		if (ctx.sig.flash or 0) >= 0.2 then
			speedLines(color, duration + 0.2)
		end
	end
	local outer = ring(CFrame.new(ctx.feet() + Vector3.new(0, 0.2, 0)), 3.2 * s, 0.35 * s, color, life, { flat = true, arc = true, brightness = 3 })
	local inner = ring(CFrame.new(ctx.feet() + Vector3.new(0, 0.22, 0)), 2 * s, 0.18 * s, lighten(color, 0.5), life, { flat = true, fill = 0.82 })
	-- Flammes d'aura qui montent autour du corps.
	local auraPart = newPart(Vector3.new(2.2, 4, 2.2) * ctx.scale, CFrame.new(ctx.root()), color, life, { Transparency = 1 })
	local aura = attachEmitter(auraPart, {
		texture = FIRE,
		color = lighten(color, 0.3),
		color2 = color,
		size = 1.4 * ctx.scale,
		rate = 38 * ctx.detail,
		life = 0.55,
		speedMin = 2,
		speed = 5,
		gravity = Vector3.new(0, 14, 0),
		alpha = 0.25,
		spread = Vector2.new(15, 15),
	})
	aura.Shape = Enum.ParticleEmitterShape.Cylinder
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	local orb: Orb? = nil
	local gather: BasePart? = nil
	local function anchorPos(): Vector3
		if opts.at == "above" then
			return ctx.head() + Vector3.new(0, 2.2 * s + (opts.orb or 1) * 1.2, 0)
		elseif opts.at == "front" then
			return ctx.front(1.6)
		elseif opts.at == "head" then
			return ctx.head() + ctx.dir() * 0.9 * ctx.scale
		end
		return ctx.hand()
	end
	if opts.orb then
		orb = newOrb(anchorPos(), 0.05, color, ctx.core, life + (opts.keep or 1.5), opts.shell)
		gather = newPart(Vector3.one * (opts.orb * 7), CFrame.new(anchorPos()), color, life, { Transparency = 1, Shape = Enum.PartType.Ball })
		local inward = attachEmitter(gather :: BasePart, {
			color = lighten(color, 0.5),
			color2 = color,
			size = 0.45 * s,
			rate = 60 * ctx.detail,
			life = 0.35,
			speedMin = opts.orb * 9,
			speed = opts.orb * 10,
			drag = 0,
			inward = true,
		})
		inward.SpreadAngle = Vector2.new(0, 0)
	end
	local lightHolder = Instance.new("PointLight")
	lightHolder.Color = color
	lightHolder.Range = 10 * s
	lightHolder.Brightness = 0
	lightHolder.Parent = auraPart
	local nextBolt = 0
	job(duration, function(p, elapsed)
		local feet = ctx.feet()
		outer.part.CFrame = CFrame.new(feet + Vector3.new(0, 0.2, 0))
		inner.part.CFrame = CFrame.new(feet + Vector3.new(0, 0.22, 0))
		setRingRotation(outer, elapsed * 540)
		setRing(outer, 3.2 * s * (1.15 - 0.15 * easeOut(p)), 0.35 * s, 0.15)
		setRing(inner, 2 * s * (0.6 + 0.4 * easeOut(p)), 0.18 * s, 0.2)
		auraPart.CFrame = CFrame.new(ctx.root())
		lightHolder.Brightness = 4 * p
		local pos = anchorPos()
		if orb and opts.orb then
			moveOrb(orb, pos, opts.orb * easeOut(p) + 0.05)
			if gather then
				gather.CFrame = CFrame.new(pos)
			end
		end
		if opts.bolts and elapsed >= nextBolt then
			nextBolt = elapsed + 0.06
			for _ = 1, 2 do
				local a = pos + randomUnit() * rng:NextNumber(0.4, 1.8) * s
				bolt(pos, a, opts.boltColor or color, 0.16 * s, 0.07, { segments = 3, branches = 0, flicker = 0, jitter = 0.4 * s })
			end
		end
		return nil
	end)
	after(duration, function()
		aura.Enabled = false
		job(0.2, function(p)
			setRing(outer, 3.2 * s * (1 + p), 0.35 * s * (1 - p), p)
			setRing(inner, 2 * s * (1 + 0.5 * p), 0.18 * s, p)
			return nil
		end)
		onDone(orb)
	end)
end

------------------------------------------------------------------------
-- Explosion complète (fin des attaques spéciales)
------------------------------------------------------------------------

local function bigImpact(ctx: Ctx, size: number, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local s = ctx.s * size
	local pos = o.pos or ctx.to
	local ground = Vector3.new(pos.X, ctx.groundY, pos.Z)
	ctx.impact()
	impactFlash(pos, 4 * s, color, 0.35, ctx.n(8))
	dome(pos, (o.dome or 3.2) * s, color, o.domeTime or 0.55, o.forcefield)
	shockRing(ground, 9 * s, color, 0.55, 0.7 * s)
	if ctx.detail > 0.5 then
		after(0.08, function()
			shockRing(ground, 13 * s, lighten(color, 0.5), 0.7, 0.35 * s)
		end)
	end
	if o.crater ~= false then
		crater(ground, 2.6 * s, o.lava or color, o.craterLife or 2.6, ctx.detail, ctx.rockColor)
	end
	if o.cracks ~= false then
		cracks(ground, 5.5 * s, o.lava or color, ctx.n(6), 2.2)
	end
	debris(ground + Vector3.new(0, 0.5, 0), ctx.groundY, ctx.n(o.debris or 12), 22 * math.sqrt(s), 1.8, ctx.rockColor)
	dust(ground, 3 * s, ctx.n(16))
	sparks(pos, color, ctx.n(30), 30 * math.sqrt(s), 0.6 * math.sqrt(s))
	playAt("punch", pos, 0.5, 0.7)
	if s > 1.4 then
		playAt("shatter", pos, 0.25, 0.8)
	end
	ctx.screen(o.screen or 1)
end

------------------------------------------------------------------------
-- Projectile : déplace un orbe de la main vers la cible
------------------------------------------------------------------------

local function launchOrb(ctx: Ctx, orb: Orb, from: Vector3, to: Vector3, duration: number, radiusFrom: number, radiusTo: number, onArrive: () -> (), arcHeight: number?)
	addTrail(orb.body, ctx.color, radiusFrom * 1.6, 0.18)
	job(duration, function(p)
		local e = p
		local pos = from:Lerp(to, e) + Vector3.new(0, (arcHeight or 0) * math.sin(p * math.pi), 0)
		moveOrb(orb, pos, radiusFrom + (radiusTo - radiusFrom) * p)
		if p >= 1 then
			onArrive()
		end
		return nil
	end)
end

------------------------------------------------------------------------
-- FAMILLES D'EFFETS
------------------------------------------------------------------------

local FAMILIES = {}

-- Coup simple réutilisé partout (version légère par défaut).
local function lightHit(ctx: Ctx, size: number?, color: Color3?)
	local c = color or ctx.color
	local s = ctx.s * (size or 1)
	impactFlash(ctx.to, 2.8 * s, c, 0.3, ctx.n(6))
	if ctx.detail > 0.5 then
		airRing(ctx.to, ctx.to - ctx.root(), 2.2 * s, lighten(c, 0.4), 0.28, 0.22 * s)
		shockRing(ctx.ground, 3 * s, c, 0.35, 0.25 * s)
	end
	sparks(ctx.to, c, ctx.n(12), 18)
	ctx.impact()
end

---------------------------------------------------------------- RASENGAN
FAMILIES.rasengan = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.hand()
		local orb = newOrb(from, 0.45 * s, ctx.color, ctx.core, 0.5)
		local spin = ring(CFrame.new(from), 0.7 * s, 0.1 * s, ctx.color2, 0.5, { arc = true })
		job(0.2, function(_, elapsed)
			spin.part.CFrame = orb.body.CFrame * CFrame.Angles(elapsed * 25, elapsed * 31, 0)
			return nil
		end)
		launchOrb(ctx, orb, from, ctx.to, 0.2, 0.45 * s, 0.5 * s, function()
			killOrb(orb)
			kill(spin.part)
			lightHit(ctx, 1.1)
			airRing(ctx.to, UP, 2 * ctx.s, ctx.color2, 0.3, 0.25 * ctx.s)
		end)
		playAt("beam", from, 0.15, 1.4)
	end,
	full = function(ctx: Ctx)
		local mini = ctx.sig.variant == "mini"
		local s = ctx.s
		local radius = (mini and 0.8 or 1.15) * s
		chargeUp(ctx, { orb = radius, at = "hand", keep = 1.2 }, function(orb)
			if not orb then
				return
			end
			-- Anneaux qui tournent autour de la sphère + vent en spirale.
			local spins = {}
			for i = 1, (mini and 2 or 3) do
				local r = ring(orb.body.CFrame, radius * 1.45, 0.14 * s, i == 1 and ctx.color2 or ctx.color, 1, { arc = true, brightness = 3 })
				table.insert(spins, { ring = r, ax = rng:NextNumber(14, 22) * (i % 2 == 0 and -1 or 1), ay = rng:NextNumber(18, 30), phase = i })
			end
			local from = orb.body.CFrame.Position
			local function updateSpins(pos: Vector3, rr: number, elapsed: number, fade: number)
				for _, item in spins do
					item.ring.part.CFrame = CFrame.new(pos) * CFrame.Angles(elapsed * item.ax + item.phase, elapsed * item.ay, item.phase * 0.7)
					setRing(item.ring, rr * 1.45, 0.14 * s * (rr / radius), fade)
					setRingRotation(item.ring, elapsed * 900)
				end
			end
			playAt("beam", from, 0.3, 1.2)
			-- 1) La sphère file vers la cible.
			addTrail(orb.body, ctx.color, radius * 1.4, 0.22)
			job(0.16, function(p, elapsed)
				local pos = from:Lerp(ctx.to, easeIn(p))
				moveOrb(orb, pos, radius)
				updateSpins(pos, radius, elapsed, 0)
				return nil
			end)
			-- 2) Elle s'enfonce dans l'ennemi en tournant et grossit.
			after(0.16, function()
				ctx.impact()
				local grind = mini and 0.2 or 0.32
				local swirl = newPart(Vector3.one, CFrame.new(ctx.to), ctx.color, grind + 0.1, { Transparency = 1 })
				attachEmitter(
					swirl,
					{ color = lighten(ctx.color, 0.6), color2 = ctx.color, size = 0.5 * s, rate = 120 * ctx.detail, life = 0.3, speedMin = 10, speed = 18, drag = 2 }
				)
				job(grind, function(p, elapsed)
					local rr = radius * (1 + (mini and 0.5 or 0.9) * easeOut(p))
					local pos = ctx.to + randomUnit() * 0.08 * s
					moveOrb(orb, pos, rr)
					updateSpins(pos, rr, elapsed + 0.16, 0)
					return nil
				end)
				for k = 0, 2 do
					after(k * grind / 3, function()
						crescent(
							CFrame.new(ctx.to) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)),
							radius * 2.2,
							0.5 * s,
							ctx.color2,
							0.22,
							{
								arc = 220,
								segments = 10,
							}
						)
					end)
				end
				shake(0.4, grind)
				-- 3) Explosion.
				after(grind, function()
					killOrb(orb)
					for _, item in spins do
						kill(item.ring.part)
					end
					bigImpact(ctx, mini and 0.75 or 1.15, ctx.color, { dome = mini and 2.6 or 3.4, debris = mini and 8 or 14, crater = not mini, screen = mini and 0.6 or 1 })
					for i = 1, (mini and 2 or 4) do
						after(i * 0.05, function()
							airRing(ctx.to, randomUnit(), (3 + i) * s, lighten(ctx.color, 0.4), 0.35, 0.3 * s)
						end)
					end
				end)
			end)
		end)
	end,
}

---------------------------------------------------------------- CHIDORI / RAIKIRI
FAMILIES.chidori = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.hand()
		bolt(from, ctx.to, ctx.color, 0.32 * s, 0.18, { branches = ctx.detail > 0.5 and 2 or 0, flicker = 1, segments = 7 })
		for _ = 1, ctx.n(3) do
			bolt(ctx.to, ctx.to + randomUnit() * 2.4 * s, ctx.color, 0.14 * s, 0.12, { segments = 3, branches = 0, flicker = 0 })
		end
		lightHit(ctx, 0.9)
		playAt("unsheath", ctx.to, 0.22, 1.3)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local raikiri = ctx.sig.variant == "raikiri"
		chargeUp(ctx, { orb = 0.5 * s, at = "hand", bolts = true, boltColor = ctx.color2, keep = 0.4 }, function(orb)
			if orb then
				killOrb(orb)
			end
			local from = ctx.hand()
			-- Lance de foudre vers la cible (épaisse, scintillante, à branches).
			bolt(from, ctx.to, ctx.color, (raikiri and 0.75 or 0.6) * s, 0.4, { branches = ctx.n(4), flicker = 3, segments = 10 })
			bolt(from, ctx.to, ctx.color2, 0.3 * s, 0.3, { branches = 1, flicker = 2, segments = 9, halo = false })
			-- Traînée du sprint.
			local feet = ctx.feet()
			groundCut(feet, Vector3.new(ctx.to.X, ctx.groundY, ctx.to.Z), 0.6 * s, ctx.color, 1.2)
			playAt("unsheath", ctx.to, 0.4, 0.9)
			after(0.06, function()
				-- Explosion électrique : éclairs en étoile, fissures bleues.
				local count = ctx.n(raikiri and 10 or 8)
				for i = 1, count do
					local a = i / count * math.pi * 2
					local dir = Vector3.new(math.cos(a), rng:NextNumber(-0.2, 0.8), math.sin(a)).Unit
					bolt(ctx.to, ctx.to + dir * rng:NextNumber(4, 7) * s, ctx.color, 0.28 * s, 0.3, { segments = 5, branches = 1, flicker = 2 })
				end
				bigImpact(ctx, raikiri and 1.1 or 1, ctx.color, { dome = 2.6, debris = 10, lava = ctx.color })
				sparks(ctx.to, ctx.color2, ctx.n(30), 40, 0.4 * s)
			end)
		end)
	end,
}

---------------------------------------------------------------- KAMEHAMEHA / CANON GALACTIQUE / MASENKO
local function energyBeam(ctx: Ctx, from: Vector3, to: Vector3, width: number, hold: number, color: Color3, core: Color3, onEnd: () -> ())
	local s = ctx.s
	local grow, shrink = 0.12, 0.22
	local total = grow + hold + shrink
	local life = total + 0.1
	local coreTube = tube(from, from, width * 0.45, core, life, 0)
	local body = tube(from, from, width, color, life, 0.15)
	local halo = tube(from, from, width * 1.7, color, life, 0.72)
	local shimmer = ctx.detail > 0.5 and tube(from, from, width * 2.1, lighten(color, 0.3), life, 0.2, Enum.Material.ForceField) or nil
	local muzzle = newOrb(from, width * 0.75, color, core, life)
	local head = newOrb(to, width * 0.9, color, core, life)
	local nextRing = 0
	local nextSpark = 0
	job(total, function(_, elapsed)
		local reach = math.min(1, elapsed / grow)
		local tip = from:Lerp(to, easeOut(reach))
		local thin = 1
		if elapsed > grow + hold then
			thin = 1 - (elapsed - grow - hold) / shrink
		end
		local pulse = 1 + 0.08 * math.sin(elapsed * 40)
		local w = width * thin * pulse
		setTube(coreTube, from, tip, w * 0.32, 1 - thin)
		setTube(body, from, tip, w, 0.15 + 0.85 * (1 - thin))
		setTube(halo, from, tip, w * 1.7, 0.8 + 0.2 * (1 - thin))
		if shimmer then
			setTube(shimmer, from, tip, w * 2.1, 0.2 + 0.8 * (1 - thin))
		end
		moveOrb(muzzle, from, width * 0.75 * thin * pulse, 1 - thin)
		moveOrb(head, tip, width * (0.9 + 0.35 * reach) * thin * pulse, reach < 1 and 0.4 or 1 - thin)
		-- Anneaux qui filent le long du rayon.
		if elapsed >= nextRing and thin > 0.5 and ctx.detail > 0.3 then
			nextRing = elapsed + 0.07
			local r = ring(look(from, to), width * 0.9, 0.12 * s, lighten(color, 0.5), 0.3, { brightness = 3 })
			job(0.28, function(p)
				local pos = from:Lerp(tip, p)
				r.part.CFrame = look(pos, to)
				setRing(r, width * (0.9 + 0.5 * p), 0.12 * s, p)
				return nil
			end)
		end
		if reach >= 1 and elapsed >= nextSpark and thin > 0.5 then
			nextSpark = elapsed + 0.08
			sparks(to, color, ctx.n(10), 30, 0.5 * s)
			emit(
				Vector3.new(to.X, ctx.groundY + 0.5, to.Z),
				{ texture = SMOKE, color = Color3.fromRGB(200, 190, 170), light = 0, alpha = 0.4, count = 4, size = 2 * s, grow = true, speedMin = 8, speed = 14, life = 0.8 }
			)
		end
		return nil
	end)
	after(grow, function()
		ctx.impact()
		shake(0.6, hold)
		hitFlash(ctx.target, color)
	end)
	after(total - shrink * 0.5, onEnd)
end

-- Rochers qui lévitent pendant la charge (Kamehameha, Sphère de destruction).
local function levitate(ctx: Ctx, duration: number)
	local feet = ctx.feet()
	local s = ctx.s
	local list = {}
	for _ = 1, ctx.n(6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local base = feet + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2.5, 5) * s
		local size = rng:NextNumber(0.3, 0.8) * s
		local rock =
			newPart(Vector3.new(size, size * 0.8, size), CFrame.new(base), darken(ctx.rockColor, rng:NextNumber(0, 0.3)), duration + 0.6, { Material = Enum.Material.Slate })
		table.insert(list, { part = rock, base = base, height = rng:NextNumber(1.5, 4) * s, spin = rng:NextNumber(-3, 3), size = size })
	end
	job(duration + 0.5, function(_, elapsed)
		for _, item in list do
			local rise = math.min(1, elapsed / duration)
			local fall = math.max(0, elapsed - duration) / 0.5
			local y = item.height * easeOut(rise) * (1 - easeIn(fall)) + math.sin(elapsed * 6 + item.spin) * 0.15 * s
			item.part.CFrame = CFrame.new(item.base + Vector3.new(0, y + item.size / 2, 0)) * CFrame.Angles(elapsed * item.spin, elapsed * item.spin * 0.7, 0)
			item.part.Transparency = fall
		end
		return nil
	end)
end

FAMILIES.kamehameha = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.sig.variant == "masenko" and ctx.head() + ctx.dir() * 1.2 * ctx.scale or ctx.hand()
		local orb = newOrb(from, 0.42 * s, ctx.color, ctx.core, 0.5)
		launchOrb(ctx, orb, from, ctx.to, 0.18, 0.42 * s, 0.42 * s, function()
			killOrb(orb)
			lightHit(ctx, 1.1)
		end)
		playAt("beam", from, 0.18, 1.2)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local masenko = ctx.sig.variant == "masenko"
		local duration = ctx.sig.charge or 0.7
		levitate(ctx, duration)
		chargeUp(ctx, { orb = 0.9 * s, at = masenko and "head" or "front", keep = 0.3 }, function(orb)
			if orb then
				killOrb(orb)
			end
			local from = masenko and ctx.head() + ctx.dir() * 1.4 * ctx.scale or ctx.front(1.8)
			local to = ctx.to
			playAt("beam", from, 0.5, 0.8)
			energyBeam(ctx, from, to, 2.1 * s, ctx.special and 0.55 or 0.3, ctx.color, ctx.core, function()
				bigImpact(ctx, 1.25, ctx.color, { dome = 3.6, debris = 16, screen = 1 })
				for i = 1, 3 do
					after(i * 0.06, function()
						airRing(to, randomUnit(), (4 + i * 1.5) * s, lighten(ctx.color, 0.4), 0.4, 0.35 * s)
					end)
				end
			end)
		end)
	end,
}

---------------------------------------------------------------- VIOLET IMAGINAIRE (Bleu + Rouge)
FAMILIES.hollow_purple = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local blue = ctx.sig.color3 or Color3.fromRGB(60, 140, 255)
		local red = ctx.sig.color2 or Color3.fromRGB(255, 60, 70)
		if rng:NextNumber() < 0.5 then
			-- « Bleu » : une sphère d'attraction apparaît sur l'ennemi et aspire tout.
			local orb = newOrb(ctx.to, 0.1, blue, lighten(blue, 0.8), 0.5)
			local r = ring(CFrame.new(ctx.to), 2.5 * s, 0.15 * s, blue, 0.5, { arc = true })
			local gather = ball(ctx.to, 5 * s, blue, 0.4, 1)
			local inward = attachEmitter(
				gather,
				{ color = lighten(blue, 0.5), color2 = blue, size = 0.4 * s, rate = 70 * ctx.detail, life = 0.25, speedMin = 9 * s, speed = 10 * s, drag = 0, inward = true }
			)
			inward.SpreadAngle = Vector2.new(0, 0)
			job(0.35, function(p, elapsed)
				moveOrb(orb, ctx.to, 0.7 * s * math.sin(p * math.pi) + 0.05)
				r.part.CFrame = CFrame.new(ctx.to) * CFrame.Angles(elapsed * 9, elapsed * 13, 0)
				setRing(r, 2.5 * s * (1 - p * 0.8), 0.15 * s, p)
				return nil
			end)
			after(0.3, function()
				lightHit(ctx, 1, blue)
			end)
		else
			-- « Rouge » : une boule de répulsion fuse et explose.
			local from = ctx.hand()
			local orb = newOrb(from, 0.45 * s, red, lighten(red, 0.8), 0.5)
			launchOrb(ctx, orb, from, ctx.to, 0.16, 0.45 * s, 0.5 * s, function()
				killOrb(orb)
				lightHit(ctx, 1.2, red)
				shockRing(ctx.ground, 4 * s, red, 0.35, 0.3 * s)
			end)
		end
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local blue = ctx.sig.color3 or Color3.fromRGB(60, 140, 255)
		local red = ctx.sig.color2 or Color3.fromRGB(255, 60, 70)
		local purple = ctx.color
		local duration = (ctx.sig.charge or 0.8) * (ctx.mine and 1 or 0.75)
		-- Charge : Bleu et Rouge tournent autour du perso et se rapprochent.
		local life = duration + 0.2
		local orbBlue = newOrb(ctx.front(1), 0.1, blue, lighten(blue, 0.8), life)
		local orbRed = newOrb(ctx.front(1), 0.1, red, lighten(red, 0.8), life)
		cracks(ctx.feet(), 5 * s, purple, ctx.n(5), duration + 1)
		if ctx.mine then
			screenFlash(Color3.fromRGB(30, 0, 50), 0.25, duration + 0.3)
		end
		chargeUp(ctx, { at = "front" }, function()
			killOrb(orbBlue)
			killOrb(orbRed)
		end)
		job(duration, function(p, elapsed)
			local center = ctx.front(2)
			local right = ctx.dir():Cross(UP)
			local spread = 2.6 * s * (1 - easeIn(p))
			local angle = elapsed * 6
			local offset = (right * math.cos(angle) + UP * math.sin(angle) * 0.5) * spread
			moveOrb(orbBlue, center + offset, 0.6 * s * math.min(1, p * 3) + 0.05)
			moveOrb(orbRed, center - offset, 0.6 * s * math.min(1, p * 3) + 0.05)
			return nil
		end)
		after(duration, function()
			local center = ctx.front(2)
			impactFlash(center, 3 * s, WHITE, 0.25, 0)
			local orb = newOrb(center, 1.6 * s, purple, Color3.fromRGB(245, 225, 255), 1.2, true)
			local rings = {}
			for i = 1, 2 do
				table.insert(rings, ring(CFrame.new(center), 2.4 * s, 0.2 * s, i == 1 and red or blue, 1, { arc = true, brightness = 3 }))
			end
			local to = ctx.to
			local travel = 0.42
			local lastTrench = center
			playAt("beam", center, 0.5, 0.6)
			job(travel, function(p, elapsed)
				local pos = center:Lerp(to, easeIn(p))
				local r = (1.6 + 1.2 * p) * s
				moveOrb(orb, pos, r)
				for i, rg in rings do
					rg.part.CFrame = CFrame.new(pos) * CFrame.Angles(elapsed * (i == 1 and 12 or -10), elapsed * 8, i)
					setRing(rg, r * 1.5, 0.2 * s, 0)
					setRingRotation(rg, elapsed * 700)
				end
				-- Tranchée creusée au sol sur le passage.
				local groundPos = Vector3.new(pos.X, ctx.groundY, pos.Z)
				local lastGround = Vector3.new(lastTrench.X, ctx.groundY, lastTrench.Z)
				if (groundPos - lastGround).Magnitude > 1.6 * s then
					groundCut(lastGround, groundPos, 2.4 * s, purple, 1.6)
					lastTrench = pos
				end
				return nil
			end)
			after(travel, function()
				killOrb(orb)
				for _, rg in rings do
					kill(rg.part)
				end
				bigImpact(ctx, 1.4, purple, { dome = 4, forcefield = true, debris = 18, screen = 1.2, domeTime = 0.7 })
				dome(to, 2.4 * s, WHITE, 0.3)
				for i = 1, 3 do
					after(i * 0.07, function()
						airRing(to, randomUnit(), (5 + i * 2) * s, i == 2 and red or (i == 1 and blue or purple), 0.45, 0.4 * s)
					end)
				end
			end)
		end)
	end,
}

---------------------------------------------------------------- DÉCOUPE / ENTAILLE (Sukana)
local function randomSlash(ctx: Ctx, center: Vector3, length: number, width: number, color: Color3, life: number)
	local dir = randomUnit()
	local perp = dir:Cross(randomUnit())
	if perp.Magnitude < 0.05 then
		perp = UP
	end
	local a = center - dir * length / 2
	local b = center + dir * length / 2
	blade(a, b, width, color, life, perp.Unit, WHITE)
	local _ = ctx
end

FAMILIES.dismantle = {
	light = function(ctx: Ctx)
		local s = ctx.s
		for i = 1, ctx.n(3) do
			after((i - 1) * 0.04, function()
				randomSlash(ctx, ctx.to + randomUnit() * 0.5 * s, 6 * s, 0.45 * s, ctx.color, 0.22)
			end)
		end
		sparks(ctx.to, ctx.color, ctx.n(8), 16)
		after(0.05, ctx.impact)
		playAt("slash", ctx.to, 0.3, 1.3)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		chargeUp(ctx, { color = ctx.color }, function()
			local count = ctx.n(14)
			local spread = 0.55
			emit(ctx.to, {
				texture = SMOKE,
				color = Color3.fromRGB(30, 0, 5),
				color2 = darken(ctx.color, 0.5),
				light = 0,
				alpha = 0.3,
				count = 14,
				size = 3 * s,
				grow = true,
				speedMin = 2,
				speed = 6,
				life = 1,
			})
			for i = 1, count do
				after(spread * (i - 1) / count, function()
					randomSlash(ctx, ctx.to + randomUnit() * 2.2 * s, rng:NextNumber(6, 10) * s, 0.4 * s, ctx.color, 0.25)
					if i % 3 == 0 then
						local a = ctx.ground + flatDir(randomUnit()) * 4 * s
						groundCut(a, ctx.ground * 2 - a, 0.35 * s, ctx.color, 1.6)
					end
					if i % 2 == 0 then
						playAt("slash", ctx.to, 0.25, rng:NextNumber(1.1, 1.5))
					end
				end)
			end
			after(0.05, ctx.impact)
			-- « Fendre » : grande croix finale.
			after(spread + 0.05, function()
				local dir = ctx.dir()
				local right = dir:Cross(UP)
				local L = 14 * s
				local c = ctx.to
				blade(c + (UP + right).Unit * L / 2, c - (UP + right).Unit * L / 2, 1.1 * s, ctx.color, 0.45, dir, WHITE)
				blade(c + (UP - right).Unit * L / 2, c - (UP - right).Unit * L / 2, 1.1 * s, ctx.color, 0.45, dir, WHITE)
				bigImpact(ctx, 1.15, ctx.color, { dome = 2.4, debris = 14, lava = ctx.color })
				dome(c, 2 * s, ctx.color2, 0.5)
			end)
		end)
	end,
}

---------------------------------------------------------------- GOMU (Gatling / Red Hawk / Pistolet)
local function stretchPunch(ctx: Ctx, from: Vector3, to: Vector3, width: number, extend: number, retract: number, fire: boolean?)
	local skin = ctx.sig.skin or Color3.fromRGB(255, 210, 170)
	local arm = tube(from, from, width, skin, extend + retract + 0.1, 0, Enum.Material.SmoothPlastic)
	local fist = ball(from, width * 1.9, skin, extend + retract + 0.1, 0, Enum.Material.SmoothPlastic)
	local flame: BasePart? = nil
	if fire then
		flame = ball(from, width * 3.2, ctx.color2, extend + retract + 0.1, 0.35)
		attachEmitter(
			fist,
			{ texture = FIRE, color = ctx.color2, color2 = ctx.color, size = width * 2.2, rate = 80, life = 0.3, speedMin = 1, speed = 3, gravity = Vector3.new(0, 8, 0) }
		)
	end
	job(extend + retract, function(_, elapsed)
		local reach
		if elapsed < extend then
			reach = easeOut(elapsed / extend)
		else
			reach = 1 - easeIn((elapsed - extend) / retract)
		end
		local tip = from:Lerp(to, reach)
		setTube(arm, from, tip, width)
		fist.CFrame = CFrame.new(tip)
		if flame then
			setBall(flame, tip, width * 3.2 * (1 + 0.1 * math.sin(elapsed * 50)), 0.35)
		end
		return nil
	end)
end

FAMILIES.gomu = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.hand()
		stretchPunch(ctx, from, ctx.to, 0.42 * s, 0.08, 0.1)
		-- Traits de vitesse le long du bras.
		for _ = 1, ctx.n(3) do
			local offset = randomUnit() * 0.6 * s
			blade(from + offset, ctx.to + offset, 0.15 * s, WHITE, 0.15)
		end
		after(0.08, function()
			lightHit(ctx, 1.1, WHITE:Lerp(ctx.color2, 0.3))
			shockRing(ctx.ground, 3.5 * s, WHITE, 0.3, 0.25 * s)
		end)
		playAt("punch", ctx.to, 0.3, 1.1)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		-- Vapeur rose du « Gear Second » pendant la charge.
		emit(ctx.root(), {
			texture = SMOKE,
			color = Color3.fromRGB(255, 190, 200),
			light = 0,
			alpha = 0.4,
			count = 18,
			size = 2 * ctx.scale,
			grow = true,
			speedMin = 2,
			speed = 4,
			life = 1.1,
			gravity = Vector3.new(0, 6, 0),
		})
		chargeUp(ctx, { color = ctx.color2 }, function()
			-- Gatling : une pluie de poings.
			local count = ctx.n(14)
			local rush = 0.6
			for i = 1, count do
				after(rush * (i - 1) / count, function()
					local from = ctx.root() + ctx.dir() * 0.8 * ctx.scale + randomUnit() * 0.7 * s
					local target = ctx.to + randomUnit() * 1.3 * s
					stretchPunch(ctx, from, target, 0.32 * s, 0.05, 0.06)
					after(0.05, function()
						impactFlash(target, 1.6 * s, WHITE, 0.18, ctx.detail > 0.6 and 3 or 0)
						if i % 3 == 0 then
							airRing(target, target - from, 1.5 * s, WHITE, 0.2, 0.15 * s)
							playAt("punch", target, 0.2, rng:NextNumber(1, 1.4))
						end
					end)
				end)
			end
			after(0.06, ctx.impact)
			-- Red Hawk : poing enflammé final.
			after(rush + 0.08, function()
				local from = ctx.hand()
				stretchPunch(ctx, from, ctx.to, 0.5 * s, 0.09, 0.15, true)
				after(0.09, function()
					bigImpact(ctx, 1.2, ctx.color2, { dome = 3, debris = 14, lava = ctx.color })
					emit(ctx.to, {
						texture = FIRE,
						color = ctx.color2,
						color2 = ctx.color,
						count = 40,
						size = 2.4 * s,
						speedMin = 8,
						speed = 22,
						life = 0.7,
						gravity = Vector3.new(0, 12, 0),
						drag = 3,
					})
					local flameRing = ring(CFrame.new(ctx.ground + Vector3.new(0, 0.3, 0)), 2 * s, 0.8 * s, ctx.color2, 0.6, { flat = true, brightness = 4 })
					job(0.6, function(p)
						setRing(flameRing, (2 + 7 * easeOut(p)) * s, 0.8 * s * (1 - p * 0.5), p)
						return nil
					end)
				end)
			end)
		end)
	end,
}

---------------------------------------------------------------- SANTORYU (Zoru)
FAMILIES.santoryu = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local dir = ctx.dir()
		local base = CFrame.lookAt(ctx.to, ctx.to + dir)
		crescent(base * CFrame.Angles(0, 0, math.rad(35)), 2.4 * s, 1 * s, ctx.color, 0.3, { segments = 10 })
		after(0.06, function()
			crescent(base * CFrame.Angles(0, 0, math.rad(-35)), 2.6 * s, 1 * s, ctx.color, 0.3, { segments = 10, reverse = true })
		end)
		emit(ctx.to, { color = ctx.color2, count = 10, size = 0.35 * s, speed = 16, life = 0.4, drag = 1 })
		after(0.05, function()
			lightHit(ctx, 0.8)
		end)
		playAt("slash", ctx.to, 0.3, 1.1)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		chargeUp(ctx, {}, function()
			local start = ctx.root()
			local dir = ctx.dir()
			local right = dir:Cross(UP)
			local past = ctx.to + dir * 6 * s
			-- Oni Giri : trois traits de lame parallèles qui traversent l'ennemi.
			for i = -1, 1 do
				local offset = right * i * 0.9 * s + UP * (i * 0.4 * s)
				blade(start + offset, past + offset, 0.9 * s, ctx.color, 0.5, right:Cross(dir).Unit, WHITE)
			end
			groundCut(Vector3.new(start.X, ctx.groundY, start.Z), Vector3.new(past.X, ctx.groundY, past.Z), 0.9 * s, ctx.color, 1.6)
			playAt("lunge", ctx.to, 0.4, 0.9)
			after(0.12, function()
				local base = CFrame.lookAt(ctx.to, ctx.to + dir)
				for k, tilt in { 40, -40, 0 } do
					after(k * 0.04, function()
						crescent(base * CFrame.Angles(0, 0, math.rad(tilt)), (3 + k * 0.5) * s, 1.4 * s, ctx.color, 0.4, { segments = 14, arc = 170 })
					end)
				end
				-- Tornade verte qui monte.
				local rings = {}
				for i = 1, ctx.n(5) do
					table.insert(
						rings,
						ring(CFrame.new(ctx.ground), (1.5 + i * 0.6) * s, 0.22 * s, i % 2 == 0 and ctx.color2 or ctx.color, 0.8, { flat = true, arc = true, brightness = 3 })
					)
				end
				job(0.75, function(p, elapsed)
					for i, rg in rings do
						rg.part.CFrame = CFrame.new(ctx.ground + Vector3.new(0, i * 1.1 * s * (0.4 + p), 0))
						setRingRotation(rg, elapsed * 800 + i * 50)
						setRing(rg, (1.5 + i * 0.6) * s * (1 + p * 0.5), 0.22 * s, p)
					end
					return nil
				end)
				bigImpact(ctx, 1.05, ctx.color, { dome = 2.2, debris = 12, crater = false })
			end)
		end)
	end,
}

---------------------------------------------------------------- HINOKAMI KAGURA / RENGOKU / DANSE DU SOLEIL
local function waterSlash(ctx: Ctx, color: Color3)
	local s = ctx.s
	local dir = ctx.dir()
	local base = CFrame.lookAt(ctx.to, ctx.to + dir) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-30, 30)))
	crescent(base, 2.6 * s, 1.1 * s, color, 0.35, { segments = 12, arc = 170, core = lighten(color, 0.9) })
	emit(ctx.to, { color = lighten(color, 0.6), color2 = color, count = 16, size = 0.4 * s, speedMin = 6, speed = 14, life = 0.6, gravity = Vector3.new(0, -35, 0), drag = 1 })
	shockRing(ctx.ground, 2.6 * s, lighten(color, 0.5), 0.35, 0.18 * s)
end

FAMILIES.hinokami = {
	light = function(ctx: Ctx)
		local variant = ctx.sig.variant
		if variant == "tanjiru" then
			-- Souffle de l'eau pour les coups normaux.
			waterSlash(ctx, ctx.sig.water or Color3.fromRGB(70, 170, 255))
		else
			local s = ctx.s
			local base = CFrame.lookAt(ctx.to, ctx.to + ctx.dir()) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-30, 30)))
			crescent(base, 2.6 * s, 1.1 * s, ctx.color, 0.35, { segments = 12, arc = 170 })
			emit(
				ctx.to,
				{ texture = FIRE, color = ctx.color2, color2 = ctx.color, count = 14, size = 1.2 * s, speedMin = 2, speed = 8, life = 0.5, gravity = Vector3.new(0, 10, 0) }
			)
		end
		after(0.05, function()
			lightHit(ctx, 0.8)
		end)
		playAt("slash", ctx.to, 0.3, 1.05)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		chargeUp(ctx, { color = ctx.color }, function()
			local start = ctx.front(1)
			local to = ctx.to
			local dir = ctx.dir()
			-- Roue de feu qui roule jusqu'à l'ennemi en laissant des flammes.
			local wheelRadius = (variant == "rengoku" and 3.4 or 2.8) * s
			local wheel = ring(look(start, start + dir:Cross(UP)), wheelRadius, 0.6 * s, ctx.color, 0.5, { arc = true, brightness = 4 })
			local inner = ring(look(start, start + dir:Cross(UP)), wheelRadius * 0.75, 0.3 * s, ctx.color2, 0.5, { brightness = 4 })
			local fireHolder = newPart(Vector3.one * wheelRadius, CFrame.new(start), ctx.color, 0.5, { Transparency = 1 })
			attachEmitter(fireHolder, {
				texture = FIRE,
				color = ctx.color2,
				color2 = ctx.color,
				size = 2 * s,
				rate = 90 * ctx.detail,
				life = 0.45,
				speedMin = 1,
				speed = 4,
				gravity = Vector3.new(0, 12, 0),
			})
			local travel = 0.3
			playAt("lunge", start, 0.4, 0.8)
			job(travel, function(p, elapsed)
				local pos = start:Lerp(to, easeOut(p))
				local cf = look(pos, pos + dir:Cross(UP)) * CFrame.Angles(0, 0, -elapsed * 20)
				wheel.part.CFrame = cf
				inner.part.CFrame = cf
				setRingRotation(wheel, elapsed * 900)
				fireHolder.CFrame = CFrame.new(pos)
				return nil
			end)
			after(travel, function()
				kill(wheel.part)
				kill(inner.part)
				-- Grande entaille de feu verticale puis explosion solaire.
				local base = CFrame.lookAt(to, to + dir) * CFrame.Angles(0, 0, math.rad(90))
				crescent(base, 3.4 * s, 1.6 * s, ctx.color, 0.45, { segments = 16, arc = 200, core = ctx.color2 })
				if variant ~= "tanjiru" then
					for k = 1, (variant == "yoriichi" and 4 or 2) do
						after(k * 0.05, function()
							crescent(base * CFrame.Angles(0, 0, math.rad(k * 45)), (3 + k * 0.4) * s, 1.2 * s, ctx.color, 0.4, { segments = 12, arc = 180, core = ctx.color2 })
						end)
					end
				end
				-- Rayons du soleil.
				local rays = {}
				for _ = 1, ctx.n(10) do
					local d = (randomUnit() + UP * 0.6).Unit
					local ray = newPart(Vector3.new(0.35 * s, 0.35 * s, 0.1), look(to, to + d), ctx.color2, 0.5)
					table.insert(rays, { part = ray, dir = d, length = rng:NextNumber(6, 11) * s })
				end
				job(0.45, function(p)
					for _, item in rays do
						local length = item.length * easeOut(math.min(1, p * 2))
						local w = 0.35 * s * (1 - p)
						item.part.Size = Vector3.new(w, w, math.max(length, 0.1))
						item.part.CFrame = look(to, to + item.dir) * CFrame.new(0, 0, -length / 2 - 1.2 * s)
						item.part.Transparency = p
					end
					return nil
				end)
				bigImpact(ctx, variant == "tanjiru" and 1.15 or 1.3, ctx.color, { dome = 3.2, debris = 14, lava = ctx.color })
				emit(to, {
					texture = FIRE,
					color = ctx.color2,
					color2 = ctx.color,
					count = 40,
					size = 2.6 * s,
					speedMin = 6,
					speed = 18,
					life = 0.8,
					gravity = Vector3.new(0, 14, 0),
					drag = 3,
				})
				emit(to, { texture = SPARKS, color = ctx.color2, count = 30, size = 0.4 * s, speedMin = 6, speed = 20, life = 1.2, gravity = Vector3.new(0, 6, 0), drag = 2 })
			end)
		end)
	end,
}

---------------------------------------------------------------- COUPS (impact)
FAMILIES.impact = {
	light = function(ctx: Ctx)
		local variant = ctx.sig.variant
		if variant == "kick" then
			local base = CFrame.lookAt(ctx.to, ctx.to + ctx.dir()) * CFrame.Angles(0, 0, math.rad(-20))
			crescent(base, 2 * ctx.s, 0.7 * ctx.s, ctx.color2, 0.22, { segments = 9 })
		end
		lightHit(ctx, variant == "smash" and 1.2 or 1)
		if ctx.sig.petals then
			emit(ctx.to, { color = ctx.color, color2 = ctx.color2, count = 10, size = 0.35 * ctx.s, speed = 10, life = 0.9, gravity = Vector3.new(0, -6, 0), drag = 2 })
		end
		if variant == "divergent" then
			after(0.12, function()
				impactFlash(ctx.to, 1.8 * ctx.s, ctx.color2:Lerp(ctx.color, 0.3), 0.22, 3)
			end)
		end
		playAt("punch", ctx.to, 0.28, rng:NextNumber(0.95, 1.15))
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		chargeUp(ctx, {}, function()
			if variant == "clap" then
				-- Ondes de pression de la frappe dans les mains.
				local from = ctx.front(1)
				for i = 0, 3 do
					after(i * 0.05, function()
						local pos = from:Lerp(ctx.to, i / 3)
						airRing(pos, ctx.to - from, (1.4 + i * 0.6) * s, lighten(ctx.color, 0.4), 0.3, 0.25 * s)
					end)
				end
				impactFlash(from, 2.4 * s, WHITE, 0.2, 0)
				after(0.18, function()
					bigImpact(ctx, 0.95, ctx.color, { dome = 2.2, debris = 10, crater = false })
				end)
			elseif variant == "multi" then
				-- Rafale de coups puis coup final.
				local count = ctx.n(8)
				for i = 1, count do
					after((i - 1) * 0.045, function()
						local p = ctx.to + randomUnit() * 1.2 * s
						impactFlash(p, 1.5 * s, ctx.color, 0.16, 3)
						if i % 2 == 0 then
							playAt("punch", p, 0.18, 1.3)
						end
					end)
				end
				if ctx.mine then
					speedLines(ctx.color, 0.5)
				end
				after(count * 0.045 + 0.05, function()
					bigImpact(ctx, 1, ctx.color, { dome = 2.4, debris = 10 })
				end)
			elseif variant == "divergent" then
				bigImpact(ctx, 1, ctx.color, { dome = 2.4, debris = 10 })
				after(0.16, function()
					-- Second impact décalé (énergie occulte noire et bleue).
					impactFlash(ctx.to, 4.4 * s, ctx.color, 0.35, 8)
					dome(ctx.to, 2.6 * s, Color3.fromRGB(20, 10, 40), 0.45)
					sparks(ctx.to, Color3.fromRGB(20, 20, 40), ctx.n(20), 26, 0.5 * s)
					shake(0.8, 0.2)
				end)
			else
				-- Coup de poing / pied écrasant (smash, kick, punch).
				if variant == "kick" then
					local base = CFrame.lookAt(ctx.to, ctx.to + ctx.dir()) * CFrame.Angles(0, 0, math.rad(-25))
					crescent(base, 3 * s, 1.2 * s, ctx.color2, 0.35, { segments = 12 })
				end
				bigImpact(ctx, variant == "smash" and 1.25 or 1, ctx.color, { dome = 2.6, debris = variant == "smash" and 16 or 10 })
				if ctx.sig.petals then
					emit(
						ctx.to,
						{ color = ctx.color, color2 = ctx.color2, count = 36, size = 0.45 * s, speedMin = 8, speed = 20, life = 1.4, gravity = Vector3.new(0, -5, 0), drag = 2 }
					)
				end
			end
		end)
	end,
}

---------------------------------------------------------------- ORBES (orb)
FAMILIES.orb = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		local from = ctx.hand()
		if variant == "disc" then
			local disc = newPart(Vector3.new(0.12, 1.8 * s, 1.8 * s), CFrame.new(from) * FLAT, ctx.color, 0.4, { Shape = Enum.PartType.Cylinder, Transparency = 0.1 })
			local edge = ring(CFrame.new(from), 1 * s, 0.15 * s, ctx.color2, 0.4, { flat = true, brightness = 3 })
			job(0.2, function(p, elapsed)
				local pos = from:Lerp(ctx.to, p)
				disc.CFrame = CFrame.new(pos) * CFrame.Angles(0, elapsed * 30, 0) * FLAT
				edge.part.CFrame = CFrame.new(pos)
				return nil
			end)
			after(0.2, function()
				kill(disc)
				kill(edge.part)
				lightHit(ctx, 1)
				crescent(CFrame.lookAt(ctx.to, ctx.to + ctx.dir()), 2 * s, 0.6 * s, ctx.color, 0.25, { arc = 300, segments = 12 })
			end)
			playAt("slash", from, 0.2, 1.4)
			return
		end
		local count = variant == "star" and ctx.n(3) or 1
		for i = 1, count do
			after((i - 1) * 0.07, function()
				local orb = newOrb(from, 0.4 * s, ctx.color, ctx.core, 0.5)
				local target = ctx.to + (count > 1 and randomUnit() * 0.8 * s or Vector3.zero)
				launchOrb(ctx, orb, from, target, 0.2, 0.4 * s, 0.4 * s, function()
					killOrb(orb)
					impactFlash(target, 2 * s, ctx.color, 0.25, 4)
					if variant == "star" then
						emit(target, { texture = FIRE, color = ctx.color2, color2 = ctx.color, count = 10, size = 1 * s, speed = 8, life = 0.4, gravity = Vector3.new(0, 8, 0) })
					end
					ctx.impact()
				end, count > 1 and 1.5 * s or 0)
			end)
		end
		playAt("beam", from, 0.15, 1.3)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		if variant == "destruction" then
			-- Sphère de destruction : énorme boule chargée au-dessus de la tête.
			levitate(ctx, ctx.sig.charge or 0.7)
			chargeUp(ctx, { orb = 2.4 * s, at = "above", shell = true, keep = 1.2 }, function(orb)
				if not orb then
					return
				end
				local from = orb.body.CFrame.Position
				local layer = ball(from, 4 * s, ctx.color2, 0.8, 0.55)
				job(0.5, function(p)
					setBall(layer, orb.body.CFrame.Position, 6.5 * s * (1 + 0.05 * math.sin(p * 40)), 0.55)
					return nil
				end)
				launchOrb(ctx, orb, from, ctx.to, 0.5, 2.4 * s, 2.6 * s, function()
					killOrb(orb)
					kill(layer)
					bigImpact(ctx, 1.6, ctx.color, { dome = 4.4, forcefield = true, debris = 20, screen = 1.2, domeTime = 0.8 })
					dome(ctx.to, 3 * s, ctx.color2, 0.6)
				end)
			end)
			return
		end
		if variant == "disc" then
			chargeUp(ctx, { at = "above" }, function()
				local from = ctx.head() + Vector3.new(0, 1.5 * s, 0)
				local disc = newPart(Vector3.new(0.15, 3.6 * s, 3.6 * s), CFrame.new(from) * FLAT, ctx.color, 0.5, { Shape = Enum.PartType.Cylinder, Transparency = 0.05 })
				local edge = ring(CFrame.new(from), 2 * s, 0.25 * s, ctx.color2, 0.5, { flat = true, brightness = 4 })
				addTrail(disc, ctx.color, 1.5 * s, 0.25)
				job(0.3, function(p, elapsed)
					local pos = from:Lerp(ctx.to, easeIn(p))
					disc.CFrame = CFrame.new(pos) * CFrame.Angles(0, elapsed * 40, 0) * FLAT
					edge.part.CFrame = CFrame.new(pos)
					return nil
				end)
				after(0.3, function()
					kill(disc)
					kill(edge.part)
					crescent(CFrame.lookAt(ctx.to, ctx.to + ctx.dir()), 3.5 * s, 1 * s, ctx.color, 0.35, { arc = 340, segments = 16 })
					bigImpact(ctx, 1, ctx.color, { dome = 2.4, debris = 10, crater = false })
				end)
			end)
			return
		end
		chargeUp(ctx, { orb = 0.9 * s, at = "hand", keep = 1 }, function(orb)
			if not orb then
				return
			end
			local from = orb.body.CFrame.Position
			launchOrb(ctx, orb, from, ctx.to, 0.25, 0.9 * s, 1.1 * s, function()
				killOrb(orb)
				bigImpact(ctx, 1.1, ctx.color, { dome = 3, debris = 12 })
				if variant == "star" then
					emit(
						ctx.to,
						{ texture = FIRE, color = ctx.color2, color2 = ctx.color, count = 36, size = 2 * s, speedMin = 6, speed = 18, life = 0.7, gravity = Vector3.new(0, 12, 0) }
					)
				end
			end, variant == "star" and 2 * s or 0)
		end)
	end,
}

---------------------------------------------------------------- RAYONS (beam)
local function drillHelix(ctx: Ctx, from: Vector3, to: Vector3, color: Color3, life: number)
	local s = ctx.s
	local axis = look(from, to)
	local length = (to - from).Magnitude
	local count = ctx.n(18)
	local parts = {}
	for i = 1, count do
		local part = ball(from, 0.35 * s, color, life, 0)
		table.insert(parts, { part = part, t = i / count })
	end
	job(life, function(p, elapsed)
		for _, item in parts do
			local angle = item.t * math.pi * 8 + elapsed * 30
			local pos = axis * CFrame.new(math.cos(angle) * 0.7 * s, math.sin(angle) * 0.7 * s, -item.t * length)
			setBall(item.part, pos.Position, 0.35 * s * (1 - p), p)
		end
		return nil
	end)
end

FAMILIES.beam = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.hand()
		local life = 0.28
		local core = tube(from, ctx.to, 0.25 * s, ctx.core, life, 0)
		local body = tube(from, ctx.to, 0.6 * s, ctx.color, life, 0.3)
		job(life, function(p)
			setTube(core, from, ctx.to, 0.25 * s * (1 - p), p)
			setTube(body, from, ctx.to, 0.6 * s * (1 - p * 0.7), 0.3 + 0.7 * p)
			return nil
		end)
		if ctx.sig.variant == "drill" and ctx.detail > 0.5 then
			drillHelix(ctx, from, ctx.to, ctx.color2, life)
		end
		impactFlash(from, 1.2 * s, ctx.color, 0.15, 0)
		lightHit(ctx, 1)
		playAt("beam", from, 0.2, 1.3)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local drill = ctx.sig.variant == "drill"
		chargeUp(ctx, { orb = 0.6 * s, at = drill and "head" or "hand", bolts = drill, boltColor = ctx.color2, keep = 0.3 }, function(orb)
			if orb then
				killOrb(orb)
			end
			local from = drill and ctx.head() + ctx.dir() * 0.9 * ctx.scale or ctx.hand()
			local past = ctx.to + (ctx.to - from).Unit * 8 * s
			energyBeam(ctx, from, drill and past or ctx.to, (drill and 0.9 or 1.6) * s, 0.35, ctx.color, ctx.core, function()
				bigImpact(ctx, drill and 0.9 or 1.1, ctx.color, { dome = 2.6, debris = 10 })
			end)
			if drill then
				drillHelix(ctx, from, past, ctx.color2, 0.65)
			end
			playAt("beam", from, 0.45, 0.9)
		end)
	end,
}

---------------------------------------------------------------- LAMES (slash)
FAMILIES.slash = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		local dir = ctx.dir()
		local base = CFrame.lookAt(ctx.to, ctx.to + dir)
		if variant == "thrust" then
			local from = ctx.hand()
			blade(from, ctx.to + dir * 1.5 * s, 0.5 * s, ctx.color, 0.25, dir:Cross(UP), WHITE)
			ellipsoid(look(ctx.to, ctx.to + dir), Vector3.new(0.5, 0.5, 2) * s, ctx.color, 0.2, 0.2)
		elseif variant == "scatter" then
			for i = 1, ctx.n(4) do
				after((i - 1) * 0.04, function()
					crescent(
						CFrame.new(ctx.to + randomUnit() * 1.2 * s) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
						1.2 * s,
						0.5 * s,
						ctx.color,
						0.2,
						{ segments = 7 }
					)
				end)
			end
		elseif variant == "haki" then
			for _ = 1, ctx.n(3) do
				bolt(ctx.root(), ctx.root() + randomUnit() * 4 * s, Color3.fromRGB(20, 0, 0), 0.25 * s, 0.15, { segments = 4, branches = 1, flicker = 1, core = ctx.color })
			end
			crescent(base * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-40, 40))), 2.6 * s, 1 * s, ctx.color, 0.3, { segments = 10 })
		elseif variant == "double" or variant == "serrated" then
			crescent(base * CFrame.Angles(0, 0, math.rad(30)), 2.4 * s, 0.9 * s, ctx.color, 0.28, { segments = variant == "serrated" and 7 or 10 })
			after(0.05, function()
				crescent(base * CFrame.Angles(0, 0, math.rad(-30)), 2.4 * s, 0.9 * s, ctx.color, 0.28, { segments = variant == "serrated" and 7 or 10, reverse = true })
			end)
		elseif variant == "water" then
			waterSlash(ctx, ctx.color)
		else
			crescent(base * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-35, 35))), 2.5 * s, 1 * s, ctx.color, 0.28, { segments = 11 })
		end
		if variant == "petals" then
			emit(ctx.to, { color = ctx.color, color2 = ctx.color2, count = 12, size = 0.35 * s, speed = 10, life = 1, gravity = Vector3.new(0, -5, 0), drag = 2 })
		end
		emit(ctx.to, { color = ctx.color2, count = 8, size = 0.35 * s, speed = 14, life = 0.35 })
		after(0.05, function()
			lightHit(ctx, 0.7)
		end)
		playAt("slash", ctx.to, 0.3, rng:NextNumber(0.95, 1.2))
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		chargeUp(ctx, {}, function()
			local dir = ctx.dir()
			local base = CFrame.lookAt(ctx.to, ctx.to + dir)
			if variant == "haki" then
				-- Haki des rois : éclairs rouges et noirs, onde qui écrase tout.
				local root = ctx.root()
				for _ = 1, ctx.n(8) do
					bolt(
						root,
						root + (randomUnit() + UP * 0.3).Unit * rng:NextNumber(5, 9) * s,
						Color3.fromRGB(25, 0, 0),
						0.35 * s,
						0.35,
						{ segments = 6, branches = 2, flicker = 2, core = ctx.color }
					)
				end
				dome(root, 5 * s, darken(ctx.color, 0.4), 0.6, true)
				shockRing(Vector3.new(root.X, ctx.feet().Y, root.Z), 16 * s, ctx.color, 0.6, 0.6 * s)
				if ctx.mine then
					screenFlash(Color3.fromRGB(60, 0, 0), 0.3, 0.5)
				end
				after(0.15, function()
					crescent(base * CFrame.Angles(0, 0, math.rad(25)), 4 * s, 1.6 * s, ctx.color, 0.45, { segments = 16, arc = 170, core = WHITE })
					bigImpact(ctx, 1.25, ctx.color, { dome = 3, debris = 16, lava = ctx.color })
				end)
			elseif variant == "thrust" then
				local from = ctx.hand()
				local past = ctx.to + dir * 6 * s
				blade(from, past, 1.1 * s, ctx.color, 0.45, dir:Cross(UP), WHITE)
				ellipsoid(look(ctx.to, past), Vector3.new(1, 1, 5) * s, ctx.color, 0.35, 0.3)
				for i = 1, 3 do
					after(i * 0.04, function()
						airRing(from:Lerp(ctx.to, i / 3), dir, (1 + i * 0.4) * s, ctx.color2, 0.3, 0.2 * s)
					end)
				end
				bigImpact(ctx, 1, ctx.color, { dome = 2.2, debris = 10, crater = false })
			elseif variant == "scatter" then
				for i = 1, ctx.n(10) do
					after((i - 1) * 0.04, function()
						crescent(
							CFrame.new(ctx.to + randomUnit() * 2 * s) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
							1.6 * s,
							0.6 * s,
							ctx.color,
							0.25,
							{ segments = 8 }
						)
					end)
				end
				after(0.45, function()
					bigImpact(ctx, 0.9, ctx.color, { dome = 2, debris = 8, crater = false })
				end)
			else
				-- Grandes entailles croisées.
				local tilts = variant == "single" and { 30 } or { 35, -35, 0 }
				for k, tilt in tilts do
					after((k - 1) * 0.06, function()
						crescent(
							base * CFrame.Angles(0, 0, math.rad(tilt)),
							(3.2 + k * 0.4) * s,
							1.4 * s,
							ctx.color,
							0.4,
							{ segments = variant == "serrated" and 9 or 15, arc = 170 }
						)
						playAt("slash", ctx.to, 0.35, 1 + k * 0.1)
					end)
				end
				local groundA = ctx.ground - dir:Cross(UP) * 4 * s
				groundCut(groundA, ctx.ground + dir:Cross(UP) * 4 * s, 0.6 * s, ctx.color, 1.5)
				if variant == "water" then
					emit(ctx.to, {
						color = lighten(ctx.color, 0.6),
						color2 = ctx.color,
						count = 40,
						size = 0.5 * s,
						speedMin = 8,
						speed = 22,
						life = 0.9,
						gravity = Vector3.new(0, -35, 0),
						drag = 1,
					})
				elseif variant == "petals" then
					emit(
						ctx.to,
						{ color = ctx.color, color2 = ctx.color2, count = 36, size = 0.45 * s, speedMin = 6, speed = 18, life = 1.4, gravity = Vector3.new(0, -5, 0), drag = 2 }
					)
				end
				after(#tilts * 0.06, function()
					bigImpact(ctx, 1, ctx.color, { dome = 2.4, debris = 10, crater = false })
				end)
			end
		end)
	end,
}

---------------------------------------------------------------- FOUDRE (bolt)
FAMILIES.bolt = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		if variant == "sky" then
			local top = ctx.to + Vector3.new(rng:NextNumber(-2, 2), 30, rng:NextNumber(-2, 2))
			bolt(top, ctx.to, ctx.color, 0.45 * s, 0.2, { segments = 9, branches = 2, flicker = 1 })
		elseif variant == "dash" then
			local from = ctx.root()
			bolt(from, ctx.to, ctx.color, 0.35 * s, 0.2, { segments = 6, branches = 1, flicker = 1, jitter = 0.8 * s })
			blade(from, ctx.to, 0.5 * s, ctx.color, 0.2)
		else
			bolt(ctx.hand(), ctx.to, ctx.color, 0.3 * s, 0.18, { segments = 7, branches = ctx.detail > 0.5 and 2 or 0 })
		end
		lightHit(ctx, 0.9)
		playAt("unsheath", ctx.to, 0.22, 1.2)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		chargeUp(ctx, { bolts = true, orb = variant == "arc" and 0.5 * s or nil, keep = 0.3 }, function(orb)
			if orb then
				killOrb(orb)
			end
			if variant == "sky" then
				-- Nuage d'orage puis foudre géante depuis le ciel.
				local top = ctx.to + Vector3.new(0, 34, 0)
				emit(top, {
					texture = SMOKE,
					color = Color3.fromRGB(50, 50, 70),
					light = 0,
					alpha = 0.2,
					count = 16,
					size = 8,
					grow = true,
					speedMin = 3,
					speed = 8,
					life = 1.4,
					drag = 2,
				})
				after(0.12, function()
					bolt(top, ctx.to, ctx.color, 1.1 * s, 0.45, { segments = 12, branches = ctx.n(5), flicker = 3 })
					bolt(top + Vector3.new(4, 0, 2), ctx.to + randomUnit() * 3 * s, ctx.color, 0.5 * s, 0.3, { segments = 10, branches = 2, flicker = 2 })
					bigImpact(ctx, 1.15, ctx.color, { dome = 2.8, debris = 12, lava = ctx.color })
					playAt("beam", ctx.to, 0.5, 0.6)
				end)
			elseif variant == "dash" then
				-- Premier mouvement : sprint éclair en zigzag (3 passages).
				local from = ctx.root()
				for k = 0, 2 do
					after(k * 0.08, function()
						local side = ctx.dir():Cross(UP) * (k - 1) * 2 * s
						local mid = from:Lerp(ctx.to, 0.5) + side
						bolt(from, mid, ctx.color, 0.55 * s, 0.3, { segments = 5, branches = 2, flicker = 2 })
						bolt(mid, ctx.to + ctx.dir() * 3 * s, ctx.color, 0.55 * s, 0.3, { segments = 5, branches = 2, flicker = 2 })
						blade(from, ctx.to + ctx.dir() * 4 * s, 0.8 * s, ctx.color, 0.3)
					end)
				end
				groundCut(ctx.feet(), ctx.ground + ctx.dir() * 4 * s, 0.6 * s, ctx.color, 1.4)
				if ctx.mine then
					speedLines(ctx.color, 0.45)
				end
				after(0.25, function()
					bigImpact(ctx, 1.05, ctx.color, { dome = 2.6, debris = 10, lava = ctx.color })
				end)
			else
				local from = ctx.hand()
				for _ = 1, ctx.n(3) do
					bolt(from, ctx.to + randomUnit() * 1.2 * s, ctx.color, 0.45 * s, 0.35, { segments = 9, branches = 2, flicker = 2 })
				end
				bigImpact(ctx, 1, ctx.color, { dome = 2.4, debris = 10, lava = ctx.color })
			end
		end)
	end,
}

---------------------------------------------------------------- FLAMMES (flame)
local function blackFlames(_ctx: Ctx, pos: Vector3, scale: number, duration: number)
	local holder = newPart(Vector3.new(2, 3, 2) * scale, CFrame.new(pos), BLACK, duration + 0.8, { Transparency = 1 })
	local e = attachEmitter(holder, {
		texture = FIRE,
		color = Color3.fromRGB(20, 5, 25),
		color2 = Color3.fromRGB(70, 20, 90),
		light = 0,
		size = 2.2 * scale,
		rate = 50,
		life = 0.7,
		speedMin = 2,
		speed = 5,
		gravity = Vector3.new(0, 10, 0),
		alpha = 0.05,
	})
	e.Shape = Enum.ParticleEmitterShape.Box
	after(duration, function()
		e.Enabled = false
	end)
end

FAMILIES.flame = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		if variant == "black" then
			blackFlames(ctx, ctx.to, s * 0.8, 0.5)
			impactFlash(ctx.to, 1.6 * s, Color3.fromRGB(90, 30, 110), 0.25, 0)
			ctx.impact()
		else
			if variant == "kick" then
				crescent(CFrame.lookAt(ctx.to, ctx.to + ctx.dir()) * CFrame.Angles(0, 0, math.rad(-25)), 2.2 * s, 0.9 * s, ctx.color, 0.3, { segments = 10, core = ctx.color2 })
			else
				local from = ctx.hand()
				for i = 1, ctx.n(4) do
					local p = from:Lerp(ctx.to, i / 4)
					after(i * 0.03, function()
						emit(p, {
							texture = FIRE,
							color = ctx.color2,
							color2 = ctx.color,
							count = 6,
							size = 1.2 * s,
							speedMin = 1,
							speed = 4,
							life = 0.4,
							gravity = Vector3.new(0, 8, 0),
						})
					end)
				end
			end
			emit(ctx.to, {
				texture = FIRE,
				color = ctx.color2,
				color2 = ctx.color,
				count = 16,
				size = 1.4 * s,
				speedMin = 2,
				speed = 9,
				life = 0.5,
				gravity = Vector3.new(0, 10, 0),
				alpha = 0.1,
			})
			lightHit(ctx, 0.9)
		end
		playAt("lunge", ctx.to, 0.25)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		chargeUp(ctx, {}, function()
			if variant == "black" then
				-- Amaterasu : flammes noires qui dévorent la cible et le sol autour.
				if ctx.attacker then
					local eye = ctx.head() + ctx.dir() * 0.5 * ctx.scale
					impactFlash(eye, 1.2 * ctx.scale, Color3.fromRGB(255, 30, 30), 0.3, 0)
				end
				after(0.15, function()
					ctx.impact()
					blackFlames(ctx, ctx.to, s * 1.4, 1.4)
					for i = 1, ctx.n(5) do
						local a = i / 5 * math.pi * 2
						blackFlames(ctx, ctx.ground + Vector3.new(math.cos(a), 0.8, math.sin(a)) * 3 * s, s * 0.7, 1.1)
					end
					cracks(ctx.ground, 5 * s, Color3.fromRGB(110, 40, 140), ctx.n(6), 2)
					crater(ctx.ground, 2.4 * s, Color3.fromRGB(80, 20, 100), 2.4, ctx.detail, ctx.rockColor)
					shockRing(ctx.ground, 7 * s, Color3.fromRGB(60, 10, 80), 0.6, 0.6 * s)
					ctx.screen(0.8)
				end)
			else
				if variant == "kick" then
					local base = CFrame.lookAt(ctx.to, ctx.to + ctx.dir())
					for k, tilt in { -25, 30 } do
						after((k - 1) * 0.07, function()
							crescent(base * CFrame.Angles(0, 0, math.rad(tilt)), 3.2 * s, 1.3 * s, ctx.color, 0.4, { segments = 13, core = ctx.color2 })
						end)
					end
				else
					local from = ctx.hand()
					for i = 1, ctx.n(7) do
						local p = from:Lerp(ctx.to, i / 7)
						after(i * 0.03, function()
							emit(p, {
								texture = FIRE,
								color = ctx.color2,
								color2 = ctx.color,
								count = 10,
								size = 2 * s,
								speedMin = 1,
								speed = 5,
								life = 0.5,
								gravity = Vector3.new(0, 10, 0),
							})
							ball(p, 1.2 * s, ctx.color, 0.2, 0.4)
						end)
					end
				end
				after(0.2, function()
					bigImpact(ctx, 1.1, ctx.color, { dome = 3, debris = 12, lava = ctx.color })
					emit(ctx.to, {
						texture = FIRE,
						color = ctx.color2,
						color2 = ctx.color,
						count = 40,
						size = 2.4 * s,
						speedMin = 6,
						speed = 18,
						life = 0.8,
						gravity = Vector3.new(0, 14, 0),
					})
				end)
			end
		end)
	end,
}

---------------------------------------------------------------- OMBRES (shadow)
FAMILIES.shadow = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		if variant == "voice" then
			local from = ctx.head()
			for i = 0, 2 do
				after(i * 0.05, function()
					local pos = from:Lerp(ctx.to, (i + 1) / 3)
					airRing(pos, ctx.to - from, (0.8 + i * 0.5) * s, ctx.color2, 0.25, 0.15 * s)
				end)
			end
			after(0.15, function()
				lightHit(ctx, 1)
			end)
			return
		end
		-- Ombre qui file au sol puis pics noirs qui jaillissent.
		local start = ctx.feet()
		local strip = newPart(Vector3.new(0.9 * s, 0.06, 0.1), CFrame.new(start), Color3.fromRGB(12, 8, 18), 0.6, { Material = Enum.Material.SmoothPlastic })
		job(0.15, function(p)
			local tip = start:Lerp(ctx.ground, p)
			strip.Size = Vector3.new(0.9 * s, 0.06, math.max(0.1, (tip - start).Magnitude))
			strip.CFrame = look((start + tip) / 2, tip) + Vector3.new(0, 0.08, 0)
			return nil
		end)
		after(0.15, function()
			for i = 0, ctx.n(4) do
				local offset = Vector3.new(math.cos(i * 1.4), 0, math.sin(i * 1.4)) * 1.3 * s
				local base = ctx.ground + offset
				local spike = newPart(Vector3.new(0.4, 0.2, 0.4) * s, CFrame.new(base), Color3.fromRGB(15, 10, 22), 0.5, { Material = Enum.Material.SmoothPlastic })
				local tip = newPart(Vector3.new(0.2, 0.2, 0.2) * s, CFrame.new(base), ctx.color2, 0.5)
				local tilt = CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
				job(0.5, function(p)
					local h = 4 * s * easeOut(math.min(1, p * 4)) * (1 - math.max(0, p - 0.6) / 0.4)
					spike.Size = Vector3.new(0.4 * s, math.max(h, 0.1), 0.4 * s)
					spike.CFrame = CFrame.new(base) * tilt * CFrame.new(0, h / 2, 0)
					tip.CFrame = CFrame.new(base) * tilt * CFrame.new(0, h, 0)
					tip.Transparency = p
					return nil
				end)
			end
			emit(ctx.to, {
				texture = SMOKE,
				color = Color3.fromRGB(15, 10, 20),
				color2 = ctx.color2,
				light = 0,
				alpha = 0.2,
				count = 10,
				size = 2 * s,
				grow = true,
				speedMin = 1,
				speed = 4,
				life = 0.9,
				gravity = Vector3.new(0, 3, 0),
			})
			ctx.impact()
			hitFlash(ctx.target, ctx.color2)
		end)
		playAt("lunge", ctx.to, 0.2, 0.8)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		local variant = ctx.sig.variant
		chargeUp(ctx, { color = ctx.color2 }, function()
			if variant == "dogs" then
				-- Chiens d'ombre : deux bêtes sombres bondissent sur l'ennemi.
				for k = -1, 1, 2 do
					local start = ctx.root() + ctx.dir():Cross(UP) * k * 1.5 * s
					local body = ellipsoid(look(start, ctx.to), Vector3.new(1.2, 1.2, 2.6) * s, Color3.fromRGB(15, 15, 30), 0.5, 0, Enum.Material.SmoothPlastic)
					local eyes = ball(start, 0.35 * s, ctx.color2, 0.5, 0)
					local smoke = attachEmitter(
						body,
						{ texture = SMOKE, color = Color3.fromRGB(15, 10, 30), light = 0, alpha = 0.3, size = 1.4 * s, rate = 40, life = 0.5, speedMin = 0, speed = 1, grow = true }
					)
					job(0.35, function(p)
						local pos = start:Lerp(ctx.to, p) + Vector3.new(0, 2.5 * s * math.sin(p * math.pi), 0)
						local cf = look(pos, ctx.to)
						body.CFrame = cf
						eyes.CFrame = cf * CFrame.new(0, 0.3 * s, -1.2 * s)
						return nil
					end)
					after(0.35, function()
						smoke.Enabled = false
						kill(body)
						kill(eyes)
					end)
				end
				after(0.35, function()
					bigImpact(ctx, 1, ctx.color2, { dome = 2.4, debris = 10, lava = ctx.color2 })
					emit(ctx.to, {
						texture = SMOKE,
						color = Color3.fromRGB(15, 10, 30),
						color2 = ctx.color,
						light = 0,
						alpha = 0.2,
						count = 20,
						size = 3 * s,
						grow = true,
						speedMin = 3,
						speed = 8,
						life = 1.1,
					})
				end)
			elseif variant == "voice" then
				-- Parole maudite : ondes sonores puis explosion.
				local from = ctx.head()
				for i = 0, 5 do
					after(i * 0.05, function()
						airRing(from:Lerp(ctx.to, (i + 1) / 6), ctx.to - from, (1 + i * 0.4) * s, i % 2 == 0 and ctx.color2 or ctx.color, 0.3, 0.2 * s)
					end)
				end
				after(0.32, function()
					bigImpact(ctx, 1.1, ctx.color, { dome = 3, debris = 12, lava = ctx.color })
				end)
			else
				-- Étreinte d'ombre : l'ombre attrape la cible puis l'écrase.
				FAMILIES.shadow.light(ctx)
				after(0.35, function()
					ctx.impacted = true
					bigImpact(ctx, 0.9, ctx.color2, { dome = 2, debris = 8, crater = false, lava = ctx.color2 })
					emit(ctx.to, {
						texture = SMOKE,
						color = Color3.fromRGB(15, 10, 20),
						color2 = ctx.color2,
						light = 0,
						alpha = 0.2,
						count = 18,
						size = 3 * s,
						grow = true,
						speedMin = 2,
						speed = 6,
						life = 1.1,
					})
				end)
			end
		end)
	end,
}

---------------------------------------------------------------- CLOUS (Nobora) et TIRS (Genyo)
FAMILIES.nails = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.hand()
		for i = 1, ctx.n(3) do
			after((i - 1) * 0.04, function()
				local target = ctx.to + randomUnit() * 0.6 * s
				local nail = tube(from, from + (target - from).Unit * 0.9 * s, 0.14 * s, Color3.fromRGB(190, 190, 200), 0.3, 0, Enum.Material.Metal)
				local glow = tube(from, from, 0.35 * s, ctx.color, 0.3, 0.5)
				job(0.14, function(p)
					local pos = from:Lerp(target, p)
					local dir = (target - from).Unit
					setTube(nail, pos - dir * 0.9 * s, pos, 0.14 * s)
					setTube(glow, pos - dir * 1.6 * s, pos, 0.35 * s, 0.5)
					return nil
				end)
				after(0.14, function()
					kill(glow)
					impactFlash(target, 1.2 * s, ctx.color, 0.2, 3)
				end)
			end)
		end
		after(0.16, ctx.impact)
		playAt("punch", ctx.to, 0.22, 1.5)
	end,
	full = function(ctx: Ctx)
		local s = ctx.s
		chargeUp(ctx, {}, function()
			FAMILIES.nails.light(ctx)
			-- Résonance : la cible vibre puis explose.
			after(0.3, function()
				for i = 1, 3 do
					after(i * 0.06, function()
						airRing(ctx.to, randomUnit(), (2 + i) * s, ctx.color, 0.35, 0.3 * s)
					end)
				end
				ctx.impacted = true
				bigImpact(ctx, 1, ctx.color, { dome = 2.6, debris = 10, crater = false })
			end)
		end)
	end,
}

FAMILIES.bullets = {
	light = function(ctx: Ctx)
		local s = ctx.s
		local from = ctx.hand()
		for i = 1, ctx.n(4) do
			after((i - 1) * 0.05, function()
				local target = ctx.to + randomUnit() * 0.8 * s
				impactFlash(from, 0.9 * s, ctx.color2, 0.1, 3)
				local tracer = tube(from, from, 0.12 * s, ctx.color2, 0.2, 0)
				job(0.1, function(p)
					local head = from:Lerp(target, p)
					local tail = from:Lerp(target, math.max(0, p - 0.35))
					setTube(tracer, tail, head, 0.12 * s, p * 0.3)
					return nil
				end)
				after(0.1, function()
					kill(tracer)
					sparks(target, ctx.color2, 5, 14, 0.3)
				end)
			end)
		end
		after(0.12, ctx.impact)
		playAt("punch", from, 0.2, 1.8)
	end,
	full = function(ctx: Ctx)
		chargeUp(ctx, { orb = 0.5 * ctx.s, keep = 0.3 }, function(orb)
			if orb then
				killOrb(orb)
			end
			for k = 0, 2 do
				after(k * 0.12, function()
					FAMILIES.bullets.light(ctx)
				end)
			end
			after(0.45, function()
				ctx.impacted = true
				bigImpact(ctx, 1, ctx.color2, { dome = 2.4, debris = 10 })
			end)
		end)
	end,
}

------------------------------------------------------------------------
-- Attaques de boss
------------------------------------------------------------------------

local enemyIdByName: { [string]: string } = {}
for id, def in Characters.Enemies or {} do
	if def.name then
		enemyIdByName[def.name] = id
	end
end

local function bossNear(position: Vector3, radius: number): Model?
	local best, bestDist = nil, radius
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:IsA("Model") and model:GetAttribute("Boss") then
			local root = rootOf(model)
			if root then
				local dist = (root.CFrame.Position - position).Magnitude
				if dist < bestDist then
					best, bestDist = model, dist
				end
			end
		end
	end
	return best
end

local function bossStyle(model: Model?)
	local name = model and model:GetAttribute("DisplayName")
	local id = name and enemyIdByName[name]
	return AttackFx.boss(id)
end

local function distanceToMe(position: Vector3): number
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root.CFrame.Position - position).Magnitude
	end
	local cam = cameraPos()
	return cam and (cam - position).Magnitude or 0
end

local function bossSlam(position: Vector3, radius: number, style)
	local color, color2 = style.color, style.color2
	local center = position + Vector3.new(0, 0.2, 0)
	local detail = math.clamp(1 - liveCount / Q.parts, 0.35, 1)
	local function n(x: number): number
		return math.max(1, math.floor(x * detail + 0.5))
	end
	-- Ondes de choc successives + dôme + cratère.
	for i = 0, 2 do
		after(i * 0.1, function()
			shockRing(center, radius * (1 - i * 0.15), i == 1 and color2 or color, 0.7, 1.2 - i * 0.3)
		end)
	end
	dome(position + Vector3.new(0, 2, 0), radius * 0.35, color, 0.7, true)
	impactFlash(position + Vector3.new(0, 3, 0), 9, color, 0.4, 8)
	crater(position, radius * 0.3, color, 3, detail, nil)
	cracks(position, radius * 0.9, color, n(8), 2.6)
	debris(position + Vector3.new(0, 1, 0), position.Y, n(22), 34, 2.2, nil)
	dust(position, radius * 0.4, n(26))
	playAt("punch", position, 0.6, 0.55)
	playAt("shatter", position, 0.3, 0.6)
	if style.style == "fire" or style.style == "magma" then
		-- Piliers de flammes / météores de magma.
		for i = 1, n(8) do
			local a = i / 8 * math.pi * 2
			local p = position + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.6
			after(0.1 + i * 0.04, function()
				if style.style == "magma" then
					local top = p + Vector3.new(rng:NextNumber(-6, 6), 40, rng:NextNumber(-6, 6))
					local rock = ball(top, 2.4, color, 0.5, 0, Enum.Material.CrackedLava)
					addTrail(rock, color, 2, 0.3)
					job(0.35, function(q)
						rock.CFrame = CFrame.new(top:Lerp(p, easeIn(q)))
						return nil
					end)
					after(0.35, function()
						kill(rock)
						impactFlash(p + Vector3.new(0, 1, 0), 5, color, 0.3, 4)
						cracks(p, 6, color, 4, 1.8)
					end)
				else
					emit(p + Vector3.new(0, 1, 0), {
						texture = FIRE,
						color = color2,
						color2 = color,
						count = 24,
						size = 4,
						speedMin = 18,
						speed = 30,
						life = 0.7,
						spread = Vector2.new(12, 12),
						gravity = Vector3.new(0, 10, 0),
						drag = 2,
					})
					local pillar = tube(p, p + Vector3.new(0, 14, 0), 2.2, color, 0.5, 0.3)
					job(0.5, function(q)
						setTube(pillar, p, p + Vector3.new(0, 14 * easeOut(math.min(1, q * 3)), 0), 2.2 * (1 - q), 0.3 + 0.7 * q)
						return nil
					end)
				end
			end)
		end
	elseif style.style == "curse" then
		dome(position + Vector3.new(0, 1, 0), radius * 0.6, darken(color, 0.6), 1, true)
		for _ = 1, n(10) do
			local a = rng:NextNumber(0, math.pi * 2)
			local base = position + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, radius * 0.8)
			local spike = newPart(Vector3.new(0.8, 0.2, 0.8), CFrame.new(base), color2, 0.8, { Material = Enum.Material.SmoothPlastic })
			local glow = newPart(Vector3.new(0.3, 0.2, 0.3), CFrame.new(base), color, 0.8)
			job(0.8, function(q)
				local h = 7 * easeOut(math.min(1, q * 4)) * (1 - math.max(0, q - 0.6) / 0.4)
				spike.Size = Vector3.new(0.8, math.max(h, 0.1), 0.8)
				spike.CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0))
				glow.Size = Vector3.new(0.3, math.max(h * 1.02, 0.1), 0.3)
				glow.CFrame = spike.CFrame
				return nil
			end)
		end
		emit(
			position + Vector3.new(0, 2, 0),
			{ texture = SMOKE, color = color2, color2 = color, light = 0, alpha = 0.2, count = 30, size = 6, grow = true, speedMin = 6, speed = 14, life = 1.4 }
		)
	elseif style.style == "beam" then
		for i = 1, n(6) do
			local a = i / 6 * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local from = position + Vector3.new(0, 2, 0)
			local beamPart = tube(from, from + dir * radius, 1.2, color, 0.5, 0)
			local core = tube(from, from + dir * radius, 0.5, color2, 0.5, 0)
			job(0.5, function(q)
				local reach = from + dir * radius * easeOut(math.min(1, q * 3))
				setTube(beamPart, from, reach, 1.2 * (1 - q), q)
				setTube(core, from, reach, 0.5 * (1 - q), q)
				return nil
			end)
		end
	else
		for _ = 1, n(6) do
			bolt(
				position + Vector3.new(0, 2, 0),
				position + Vector3.new(rng:NextNumber(-1, 1), 0.2, rng:NextNumber(-1, 1)).Unit * radius * 0.8,
				color,
				0.6,
				0.35,
				{ segments = 6, branches = 1, flicker = 2 }
			)
		end
	end
	local dist = distanceToMe(position)
	if dist < 80 then
		local k = 1 - dist / 80
		shake(2.2 * k, 0.6)
		screenFlash(lighten(color, 0.5), 0.25 * k, 0.4)
	end
end

------------------------------------------------------------------------
-- Gestion des évènements serveur
------------------------------------------------------------------------

local HANDLERS = {}

local function cameraDistance(position: Vector3): number
	local cam = cameraPos()
	return cam and (cam - position).Magnitude or 0
end

-- Choix du niveau de détail selon la distance, la charge et à qui appartient l'attaque.
local function detailFor(position: Vector3, mine: boolean): (number, boolean)
	local load = liveCount / Q.parts
	if load > 1 then
		return 0, false -- saturé : impact minimal
	end
	local detail = mine and 1 or 0.6
	local dist = cameraDistance(position)
	if dist > 110 then
		detail *= 0.5
	end
	if load > 0.65 then
		detail *= 0.5
	end
	return math.clamp(detail, 0.2, 1), load <= 0.85
end

function Effects.playAttack(data)
	local to = data.position
	if typeof(to) ~= "Vector3" then
		return
	end
	if cameraDistance(to) > 220 then
		return
	end
	local attacker = nil
	if typeof(data.attacker) == "Instance" and data.attacker:IsA("Model") then
		attacker = data.attacker
	end
	local target = typeof(data.target) == "Instance" and data.target or nil
	local mine = player ~= nil and data.owner == player.UserId
	local fxId = attacker and attacker:GetAttribute("AttackFx")
	if type(fxId) ~= "string" or not AttackFx.get(fxId) then
		fxId = AttackFx.forCharacter(nil, data.kind)
	end
	local sig = AttackFx.get(fxId) or AttackFx.Signatures.basic_punch
	local family = FAMILIES[sig.family] or FAMILIES.impact
	local detail, allowFull = detailFor(to, mine)
	local ctx = makeCtx(data, attacker, target, sig, mine, math.max(detail, 0.2))
	if detail <= 0 then
		impactFlash(to, 1.6 * ctx.s, ctx.color, 0.2, 0)
		ctx.impact()
		return
	end
	if data.special and allowFull then
		family.full(ctx)
	else
		family.light(ctx)
	end
	-- Sécurité : le chiffre de dégâts s'affiche toujours.
	after(2.5, ctx.impact)
end

HANDLERS.Hit = Effects.playAttack

-- Coup d'épée du joueur : croissant lumineux + particules selon l'épée.
HANDLERS.SwordSlash = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" or cameraDistance(position) > 160 then
		return
	end
	local color = data.color or WHITE
	local direction = data.direction or Vector3.new(0, 0, -1)
	local radius = math.clamp((data.range or 7) * 0.45, 2.5, 6)
	local base = CFrame.lookAt(position, position + flatDir(direction)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25)))
	crescent(base, radius, 1.3, color, 0.3, { segments = 12, arc = 160 })
	local kind = data.kind
	if kind == "lightning" then
		for _ = 1, 2 do
			bolt(position, position + direction * radius + randomUnit() * 2, color, 0.2, 0.15, { segments = 5, branches = 1 })
		end
	elseif kind == "flame" then
		emit(
			position + direction * 2,
			{ texture = FIRE, color = color, color2 = Color3.fromRGB(255, 230, 120), count = 12, size = 1.2, speedMin = 2, speed = 6, life = 0.5, gravity = Vector3.new(0, 8, 0) }
		)
	elseif kind == "shadow" then
		emit(position + direction * 2, {
			texture = SMOKE,
			color = Color3.fromRGB(15, 10, 20),
			color2 = color,
			light = 0,
			alpha = 0.2,
			count = 12,
			size = 1.8,
			grow = true,
			speedMin = 1,
			speed = 4,
			life = 0.9,
		})
	elseif kind == "ice" then
		emit(position + direction * 2, { color = lighten(color, 0.5), count = 16, size = 0.5, speed = 10, life = 0.6 })
	elseif kind == "wind" or kind == "mist" then
		emit(position + direction * 2, { color = color, count = 12, size = 0.45, speed = 14, life = 0.45, drag = 1 })
	end
end

-- Un ennemi frappe un perso : griffure rouge (lourde et plus grosse si c'est le boss).
HANDLERS.EnemyHit = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" or cameraDistance(position) > 160 then
		return
	end
	local from = typeof(data.from) == "Vector3" and data.from or position + Vector3.new(0, 0, 3)
	local boss = bossNear(from, 12)
	local color = Color3.fromRGB(255, 70, 70)
	local dir = flatDir(position - from)
	local right = dir:Cross(UP)
	if boss then
		local style = bossStyle(boss)
		color = style.color
		for i = -1, 1 do
			local offset = right * i * 0.9
			blade(position + offset + UP * 2.5 - right * 1.5, position + offset - UP * 2 + right * 1.5, 0.6, color, 0.3, dir, WHITE)
		end
		impactFlash(position, 4, color, 0.3, 6)
		shockRing(position - Vector3.new(0, 2.5, 0), 6, color, 0.4, 0.4)
		debris(position, position.Y - 2.5, 6, 18, 1.4, nil)
		playAt("punch", position, 0.45, 0.6)
	else
		for i = -1, 1 do
			local offset = right * i * 0.45
			blade(position + offset + UP * 1.2 - right * 0.7, position + offset - UP * 1 + right * 0.7, 0.25, color, 0.2, dir)
		end
		impactFlash(position, 1.6, color, 0.2, 3)
	end
	floatingText(position + Vector3.new(0, 2, 0), "-" .. Formulas.formatNumber(data.amount or 0), Color3.fromRGB(255, 90, 90), 0.6)
end

HANDLERS.Death = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	local model = data.target
	if typeof(model) == "Instance" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				tween(part, 0.8, { Transparency = 1 })
			end
		end
	end
	if cameraDistance(position) > 200 then
		return
	end
	if data.boss then
		local gold = Color3.fromRGB(255, 220, 90)
		dome(position, 8, WHITE, 0.8, true)
		impactFlash(position, 12, gold, 0.5, 10)
		local column = tube(position - Vector3.new(0, 4, 0), position + Vector3.new(0, 80, 0), 6, gold, 1.4, 0.2)
		job(1.4, function(p)
			setTube(column, position - Vector3.new(0, 4, 0), position + Vector3.new(0, 80, 0), 6 * (1 - p) + 0.5, 0.2 + 0.8 * p)
			return nil
		end)
		for i = 0, 3 do
			after(i * 0.12, function()
				shockRing(position - Vector3.new(0, 3, 0), 26 + i * 6, i % 2 == 0 and gold or WHITE, 0.8, 1)
			end)
		end
		debris(position, position.Y - 4, 24, 40, 2.4, nil)
		emit(position, { color = gold, color2 = WHITE, count = 80, size = 1.2, speedMin = 10, speed = 40, life = 1.6, gravity = Vector3.new(0, -10, 0), drag = 1 })
		playAt("shatter", position, 0.5, 0.7)
		shake(2.5, 0.8)
		screenFlash(WHITE, 0.35, 0.6)
	else
		impactFlash(position, 4, WHITE, 0.35, 6)
		airRing(position, UP, 4, Color3.fromRGB(255, 230, 120), 0.4, 0.4)
		-- Âme qui s'envole.
		emit(position, {
			color = Color3.fromRGB(255, 240, 180),
			color2 = Color3.fromRGB(255, 200, 80),
			count = 16,
			size = 0.5,
			speedMin = 2,
			speed = 6,
			life = 1.1,
			gravity = Vector3.new(0, 10, 0),
			drag = 1,
		})
		debris(position, position.Y - 2, 6, 14, 1.2, Color3.fromRGB(255, 220, 120))
	end
end

HANDLERS.KO = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	emit(position, {
		texture = SMOKE,
		color = Color3.fromRGB(210, 210, 220),
		light = 0,
		alpha = 0.2,
		count = 14,
		size = 2.2,
		grow = true,
		speedMin = 2,
		speed = 6,
		life = 0.9,
		gravity = Vector3.new(0, 4, 0),
	})
	impactFlash(position, 2.4, Color3.fromRGB(200, 200, 220), 0.3, 0)
	playAt("ko", position, 0.4)
end

HANDLERS.LevelUp = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	floatingText(position + Vector3.new(0, 6, 0), "LEVEL UP! " .. tostring(data.level), Color3.fromRGB(255, 230, 60), 1.2, 1.4)
	local gold = Color3.fromRGB(255, 230, 60)
	local r = ring(CFrame.new(position - Vector3.new(0, 1.5, 0)), 2, 0.4, gold, 0.8, { flat = true, brightness = 3 })
	job(0.8, function(p)
		r.part.CFrame = CFrame.new(position - Vector3.new(0, 1.5, 0) + Vector3.new(0, 4 * p, 0))
		setRing(r, 2 + 4 * easeOut(p), 0.4, p)
		return nil
	end)
	emit(position, { color = gold, color2 = WHITE, count = 20, size = 0.5, speedMin = 2, speed = 6, life = 1, gravity = Vector3.new(0, 8, 0) })
end

HANDLERS.Slam = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" or cameraDistance(position) > 260 then
		return
	end
	local boss = bossNear(position + Vector3.new(0, 6, 0), 30)
	local style = bossStyle(boss)
	bossSlam(position, data.radius or 20, style)
	if boss and distanceToMe(position) < 90 then
		banner(boss, style.name, style.color, 1.4)
	end
end

HANDLERS.Strike = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	local color = data.color or Color3.fromRGB(255, 230, 60)
	if data.aura == "neant" then
		-- Pluie de cubes du néant.
		for i = 1, 6 do
			local start = position + Vector3.new(rng:NextNumber(-3, 3), 40 + i * 4, rng:NextNumber(-3, 3))
			local finish = position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
			local cube = newPart(Vector3.one * 1.4, CFrame.new(start), color, 0.9)
			job(0.5, function(p)
				cube.CFrame = CFrame.new(start:Lerp(finish, easeIn(p))) * CFrame.Angles(p * 3, p * 3, 0)
				return nil
			end)
			after(0.5, function()
				fadeAndDestroy(cube, 0.4, { Size = Vector3.one * 3 })
			end)
		end
	else
		local top = position + Vector3.new(rng:NextNumber(-6, 6), 90, rng:NextNumber(-6, 6))
		bolt(top, position, color, 1.3, 0.4, { segments = 12, branches = 3, flicker = 2 })
	end
	after(0.3, function()
		impactFlash(position, 8, color, 0.4, 8)
		shockRing(position, 10, color, 0.5, 0.6)
	end)
	playAt("beam", position, 0.5)
end

HANDLERS.Build = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	impactFlash(position, 8, Color3.fromRGB(255, 230, 120), 0.4, 8)
	emit(position, { color = WHITE, color2 = Color3.fromRGB(255, 230, 120), count = 30, size = 0.6, speedMin = 8, speed = 18, life = 0.8, gravity = Vector3.new(0, -12, 0) })
	floatingText(position + Vector3.new(0, 4, 0), "CONSTRUIT !", Color3.fromRGB(120, 255, 140), 1.2, 1.2)
end

HANDLERS.Evolve = function(data)
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	local violet = Color3.fromRGB(200, 140, 255)
	local column = tube(position - Vector3.new(0, 4, 0), position + Vector3.new(0, 36, 0), 4, violet, 1.2, 0.2)
	job(1.2, function(p)
		setTube(column, position - Vector3.new(0, 4, 0), position + Vector3.new(0, 36 + 20 * p, 0), 4 * (1 - p) + 0.4, 0.2 + 0.8 * p)
		return nil
	end)
	for i = 0, 2 do
		after(i * 0.15, function()
			airRing(position + Vector3.new(0, i * 3, 0), UP, 6 + i * 2, i == 1 and Color3.fromRGB(255, 220, 120) or violet, 0.6, 0.5)
		end)
	end
	emit(position, { color = Color3.fromRGB(255, 220, 120), color2 = violet, count = 40, size = 0.7, speedMin = 8, speed = 18, life = 1.2, gravity = Vector3.new(0, 6, 0) })
	floatingText(position + Vector3.new(0, 6, 0), string.rep("★", data.stars or 2) .. " ÉVEIL !", Color3.fromRGB(230, 190, 255), 1.5, 1.6)
	shake(1, 0.4)
end

HANDLERS.Rift = function(data)
	local color = data.color or WHITE
	if not screenGui then
		return
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 50
	flash.Parent = screenGui
	track(flash, 2.6)
	-- Le passage d'univers est un moment fort : flash plus doux si les flashs sont désactivés.
	local peak = flashEnabled() and 0 or 0.6
	job(0.6, function(p)
		flash.BackgroundTransparency = 1 - (1 - peak) * p
		return nil
	end)
	after(0.9, function()
		flash.BackgroundColor3 = color
		job(1.4, function(p)
			flash.BackgroundTransparency = peak + (1 - peak) * p
			return nil
		end)
	end)
	shake(2, 1.2)
end

------------------------------------------------------------------------
-- Récompenses : pièces et matériaux qui volent vers le joueur
------------------------------------------------------------------------

local function flyTo(part: BasePart, duration: number, onArrive: () -> ())
	local start = part.CFrame.Position
	local arc = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(4, 8), rng:NextNumber(-4, 4))
	track(part, duration + 0.5)
	job(duration, function(p, elapsed)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			kill(part)
			return true
		end
		local target = root.CFrame.Position
		local position = start:Lerp(target, p * p) + arc * math.sin(p * math.pi)
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, elapsed * 8, 0)
		if p >= 1 then
			kill(part)
			onArrive()
		end
		return nil
	end)
end

local function onReward(kind: string, amount: number, position: Vector3?, extra: string?)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = position or (root and root:IsA("BasePart") and root.CFrame.Position) or Vector3.zero
	if kind == "coins" then
		local count = math.clamp(math.floor(math.log10(math.max(amount, 1)) * 2) + 2, 3, 10)
		for i = 1, count do
			local coin = newPart(
				Vector3.new(0.25, 1.1, 1.1),
				CFrame.new(origin + Vector3.new(rng:NextNumber(-1.5, 1.5), 1, rng:NextNumber(-1.5, 1.5))),
				Color3.fromRGB(255, 205, 50),
				2,
				{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.3 }
			)
			after(i * 0.04, function()
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
		local color = material and material.color or WHITE
		local gem = newPart(Vector3.one * 1.2, CFrame.new(origin + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), color, 2)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Parent = gem
		flyTo(gem, 0.8, function() end)
		floatingText(origin + Vector3.new(0, 4, 0), "+" .. amount .. " " .. (material and material.name or ""), lighten(color, 0.3), 1, 1.4)
	elseif kind == "crystal" then
		local color = Color3.fromRGB(120, 230, 255)
		local gem = newPart(Vector3.new(0.9, 1.6, 0.9), CFrame.new(origin + Vector3.new(0, 2, 0)), color, 2, { Transparency = 0.1 })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Brightness = 2
		light.Parent = gem
		flyTo(gem, 0.9, function() end)
		floatingText(origin + Vector3.new(0, 5, 0), "+" .. amount .. " CRISTAL DE TRAIT 💎", color, 1.2, 1.6)
	end
end

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------

-- Prépare le dossier d'effets et la boucle d'animation (sans brancher les évènements réseau).
function Effects.setup(gui: ScreenGui?, hudModule)
	screenGui = gui
	hud = hudModule
	if fxFolder and fxFolder.Parent then
		return
	end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = Workspace
	anchor = Instance.new("Part")
	anchor.Name = "FxAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new()
	anchor.Parent = fxFolder
	refreshQuality()
	particleBudget = 600
	if player then
		-- FxShake / FxFlash sont relus à chaque effet : seul FxQuality change la qualité
		-- (sinon on annulerait la baisse automatique décidée quand le jeu rame).
		player:GetAttributeChangedSignal("FxQuality"):Connect(refreshQuality)
	end
	lastStep = now()
	RunService.RenderStepped:Connect(step)
	-- Secousse d'écran : appliquée après la caméra par défaut.
	RunService:BindToRenderStep("AnimeTycoonFxShake", Enum.RenderPriority.Camera.Value + 1, function()
		local t = now()
		if t >= shakeUntil or shakeAmount <= 0 then
			shakeAmount = 0
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local k = shakeAmount * math.clamp((shakeUntil - t) / 0.4, 0, 1)
		camera.CFrame *= CFrame.new(rng:NextNumber(-k, k) * 0.12, rng:NextNumber(-k, k) * 0.12, 0) * CFrame.Angles(rng:NextNumber(-k, k) * 0.012, rng:NextNumber(-k, k) * 0.012, 0)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			soundBudget = 0
			-- Budget de particules par seconde (selon la qualité).
			particleBudget = math.floor(700 * Q.particles)
			-- Flashs d'ennemis orphelins (ennemi détruit pendant le flash).
			for model, h in highlights do
				if not model.Parent then
					highlights[model] = nil
					highlightToken[model] = nil
					highlightCount -= 1
					h:Destroy()
				end
			end
		end
	end)
end

function Effects.init(gui: ScreenGui, hudModule)
	Effects.setup(gui, hudModule)
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
		local ok, err = pcall(onReward, kind, amount, position, extra)
		if not ok then
			warn("[AnimeTycoon] Récompense : " .. tostring(err))
		end
	end)
end

-- Déclenche un évènement d'effet localement (tests, aperçus, autres modules).
function Effects.handle(kind: string, data)
	local handler = HANDLERS[kind]
	if handler then
		handler(data or {})
	end
end

-- Horloge des animations (les tests et les aperçus avancent le temps eux-mêmes).
function Effects.setClock(fn: (() -> number)?)
	local before = now()
	now = fn or os.clock
	-- Les effets en cours gardent leur avancement dans la nouvelle horloge.
	local offset = now() - before
	for _, item in jobs do
		item.t0 += offset
	end
	for _, timer in timers do
		timer.at += offset
	end
	for instance, expiry in live do
		live[instance] = expiry + offset
	end
	shakeUntil += offset
	lastStep = now()
	lastSweep = now()
end

-- Force le nettoyage des effets expirés (tests).
function Effects.sweep()
	sweep(now())
end

-- Statistiques (tests et réglage des performances).
function Effects.stats()
	return { parts = liveCount, jobs = #jobs, timers = #timers, lights = activeLights, quality = qualityName, highlights = highlightCount, dropped = droppedJobs }
end

-- Réglages joueur (menu d'options) : "FxShake" / "FxFlash" (booléens), "FxQuality" ("auto", "high", "medium", "low").
function Effects.setOption(name: string, value: any)
	if player then
		player:SetAttribute(name, value)
	end
	refreshQuality()
end

Effects.floatingText = floatingText
Effects.burst = function(position: Vector3, color: Color3, size: number)
	impactFlash(position, size, color, 0.35, 4)
end
Effects.families = FAMILIES -- exposé pour les tests

return Effects
