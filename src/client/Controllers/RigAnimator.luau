-- Animation des persos : animations R6 officielles de Roblox (repos, marche, coup d'épée, salut,
-- danse...) jouées localement, plus de petites poses procédurales par-dessus (coups de poing,
-- attaques spéciales, recul quand on est touché). Fonctionne aussi avec tes propres modèles R6.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RigAnimator = {}

local ANIMATIONS = {
	idle = "rbxassetid://180435571",
	idle2 = "rbxassetid://180435792",
	walk = "rbxassetid://180426354",
	slash = "rbxassetid://129967390",
	lunge = "rbxassetid://129967478",
	wave = "rbxassetid://128777973",
	point = "rbxassetid://128853357",
	cheer = "rbxassetid://129423030",
	laugh = "rbxassetid://129423131",
	dance = "rbxassetid://182435998",
	dance2 = "rbxassetid://182436842",
	dance3 = "rbxassetid://182436935",
}
local IDLE_ACTIONS = { "wave", "cheer", "laugh", "dance", "punch", "point", "dance2", "punch", "dance3", "flex" }
local JOINTS = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local NEAR, FAR = 90, 200

local animationObjects: { [string]: Animation } = {}
local function animation(name: string): Animation
	local existing = animationObjects[name]
	if existing then
		return existing
	end
	local anim = Instance.new("Animation")
	anim.Name = name
	anim.AnimationId = ANIMATIONS[name]
	animationObjects[name] = anim
	return anim
end

local rigs: { [Model]: any } = {}

local function findAnimator(model: Model): Animator?
	local owner = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not owner then
		return nil
	end
	return owner:FindFirstChildOfClass("Animator") or owner:WaitForChild("Animator", 5) :: Animator?
end

local function loadTrack(st, name: string, looped: boolean, priority: Enum.AnimationPriority)
	if st.tracks[name] then
		return st.tracks[name]
	end
	if not st.animator then
		return nil
	end
	local ok, track = pcall(function()
		return st.animator:LoadAnimation(animation(name))
	end)
	if not ok or not track then
		return nil
	end
	track.Looped = looped
	track.Priority = priority
	st.tracks[name] = track
	return track
end

local function play(st, name: string, fade: number?, speed: number?)
	local track = loadTrack(st, name, false, Enum.AnimationPriority.Action)
	if track then
		track:Play(fade or 0.1, 1, speed or 1)
	end
	return track
end

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	task.spawn(function()
		local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not root then
			return
		end
		task.wait()
		-- Le modèle a pu partir pendant l'attente (perso collecté, sorti du streaming) :
		-- unregister est déjà passé, on ne crée pas d'entrée orpheline.
		local stillHere = false
		pcall(function()
			stillHere = model:IsDescendantOf(Workspace)
		end)
		if not stillHere or rigs[model :: Model] then
			return
		end
		local motors = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Motor6D") and table.find(JOINTS, descendant.Name) then
				local base = descendant:GetAttribute("BaseC0") or descendant.C0
				motors[descendant.Name] = { motor = descendant, base = base }
			end
		end
		local st = {
			model = model,
			root = root,
			motors = motors,
			animator = findAnimator(model),
			tracks = {},
			speed = 0,
			moving = false,
			active = false,
			lastPos = root.Position,
			seed = math.random() * 10,
			lastAttackTick = model:GetAttribute("AttackTick"),
			lastSpecialTick = model:GetAttribute("SpecialTick"),
			lastHitTick = model:GetAttribute("HitTick"),
			nextIdleAction = os.clock() + math.random(2, 8),
			frame = 0,
		}
		rigs[model] = st
	end)
end

local function unregister(model: Instance)
	local st = rigs[model :: Model]
	if st then
		for _, track in st.tracks do
			pcall(function()
				track:Stop(0)
			end)
		end
	end
	rigs[model :: Model] = nil
end

local function setActive(st, active: boolean)
	if st.active == active then
		return
	end
	st.active = active
	if active then
		local idle = loadTrack(st, math.random() < 0.5 and "idle" or "idle2", true, Enum.AnimationPriority.Idle)
		st.idleTrack = idle
		if idle then
			idle:Play(0.3)
		end
	else
		for _, track in st.tracks do
			track:Stop(0.2)
		end
	end
end

-- Pose procédurale ajoutée par-dessus les animations (repères officiels des articulations R6).
local function pose(st, t: number)
	local model = st.model
	local scale = model:GetAttribute("BaseScale") or 1
	local armR, armL = 0, 0 -- levée vers l'avant (radians)
	local outR, outL = 0, 0 -- écartement sur le côté
	local legR, legL = 0, 0
	local lean, twist, bob, nod = 0, 0, 0, 0

	-- Coup / attaque
	local attackTick = model:GetAttribute("AttackTick")
	if attackTick ~= st.lastAttackTick then
		st.lastAttackTick = attackTick
		st.attackKind = model:GetAttribute("AttackKind") or "punch"
		st.attackSide = ((attackTick or 0) % 2 == 0)
		st.attackStart = t
		if st.attackKind == "slash" then
			play(st, "slash", 0.05, 1.4)
		elseif st.attackKind == "lightning" or st.attackKind == "stretch" then
			play(st, "lunge", 0.05, 1.3)
		end
	end
	if st.attackStart then
		local p = (t - st.attackStart) / 0.35
		if p >= 1 then
			st.attackStart = nil
		else
			local k = math.sin(p * math.pi)
			local kind = st.attackKind
			if kind == "beam" or kind == "orb" or kind == "flame" or kind == "ice" then
				armR, armL = 1.5 * k, 1.5 * k
				outR, outL = 0.25 * k, 0.25 * k
				lean = 0.1 * k
			elseif kind == "shadow" then
				armR, armL = 0.9 * k, 0.9 * k
				outR, outL = -0.7 * k, -0.7 * k
			elseif kind == "punch" or kind == "stretch" then
				if st.attackSide then
					armR = 1.65 * k
				else
					armL = 1.65 * k
				end
				twist = (st.attackSide and 0.35 or -0.35) * k
				lean = 0.1 * k
			end
		end
	end

	-- Attaque spéciale : bras levés + petit saut
	local specialTick = model:GetAttribute("SpecialTick")
	if specialTick ~= st.lastSpecialTick then
		st.lastSpecialTick = specialTick
		st.specialStart = t
	end
	if st.specialStart then
		local p = (t - st.specialStart) / 0.6
		if p >= 1 then
			st.specialStart = nil
		else
			local k = math.sin(p * math.pi)
			armR, armL = 2.9 * k, 2.9 * k
			outR, outL = -0.3 * k, -0.3 * k
			bob += 1.2 * k
			legR, legL = 0.5 * k, -0.4 * k
		end
	end

	-- Coup reçu : recul
	local hitTick = model:GetAttribute("HitTick")
	if hitTick ~= st.lastHitTick then
		st.lastHitTick = hitTick
		st.hitStart = t
	end
	if st.hitStart then
		local p = (t - st.hitStart) / 0.22
		if p >= 1 then
			st.hitStart = nil
		else
			lean -= 0.3 * math.sin(p * math.pi)
		end
	end

	-- Petites actions des persos exposés sur la base (vivants comme les poulets !)
	if st.root.Anchored and not st.attackStart then
		if not st.idleAction and t >= st.nextIdleAction then
			st.idleAction = IDLE_ACTIONS[math.random(1, #IDLE_ACTIONS)]
			st.idleStart = t
			if ANIMATIONS[st.idleAction] then
				play(st, st.idleAction, 0.2)
			end
		end
		if st.idleAction then
			local duration = (st.idleAction == "dance" or st.idleAction == "dance2" or st.idleAction == "dance3") and 4 or 1.4
			local p = (t - st.idleStart) / duration
			if p >= 1 then
				local track = st.tracks[st.idleAction]
				if track then
					track:Stop(0.3)
				end
				st.idleAction = nil
				st.nextIdleAction = t + math.random(4, 10)
			elseif st.idleAction == "punch" then
				local combo = math.floor(p * 5) % 2 == 0
				local kk = math.abs(math.sin(p * 5 * math.pi))
				if combo then
					armR = 1.6 * kk
				else
					armL = 1.6 * kk
				end
				twist = (combo and 0.3 or -0.3) * kk
			elseif st.idleAction == "flex" then
				local k = math.sin(p * math.pi)
				armR, armL = 1.0 * k, 1.0 * k
				outR, outL = -1.4 * k, -1.4 * k
				nod = -0.2 * k
			end
		end
	end

	local m = st.motors
	if m.RootJoint then
		m.RootJoint.motor.C0 = m.RootJoint.base * CFrame.new(0, 0, bob * scale) * CFrame.Angles(lean, 0, twist)
	end
	if m.Neck then
		m.Neck.motor.C0 = m.Neck.base * CFrame.Angles(nod + math.sin(t * 2 + st.seed) * 0.03, 0, 0)
	end
	if m["Right Shoulder"] then
		m["Right Shoulder"].motor.C0 = m["Right Shoulder"].base * CFrame.Angles(outR, 0, armR)
	end
	if m["Left Shoulder"] then
		m["Left Shoulder"].motor.C0 = m["Left Shoulder"].base * CFrame.Angles(outL, 0, -armL)
	end
	if m["Right Hip"] then
		m["Right Hip"].motor.C0 = m["Right Hip"].base * CFrame.Angles(0, 0, legR)
	end
	if m["Left Hip"] then
		m["Left Hip"].motor.C0 = m["Left Hip"].base * CFrame.Angles(0, 0, -legL)
	end
end

local function update(st, dt: number, t: number)
	local root = st.root
	local scale = st.model:GetAttribute("BaseScale") or 1
	local pos = root.Position
	local velocity = (pos - st.lastPos) / math.max(dt, 1e-3)
	st.lastPos = pos
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if flatSpeed > 80 then
		flatSpeed = 0 -- téléportation
	end
	st.speed += (flatSpeed - st.speed) * math.min(1, dt * 8)
	local moving = st.speed > 1.5
	if moving ~= st.moving then
		st.moving = moving
		local walk = loadTrack(st, "walk", true, Enum.AnimationPriority.Movement)
		if walk then
			if moving then
				walk:Play(0.2)
			else
				walk:Stop(0.25)
			end
		end
	end
	if moving then
		local walk = st.tracks.walk
		if walk then
			walk:AdjustSpeed(math.clamp(st.speed / (14.5 * scale), 0.3, 2.5))
		end
	end
	pose(st, t)
end

function RigAnimator.init()
	for _, model in CollectionService:GetTagged("AnimeRig") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("AnimeRig"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("AnimeRig"):Connect(unregister)

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for model, st in rigs do
			if not model.Parent or not st.root.Parent then
				-- Le modèle peut revenir (perso K.O. qui revient) : on garde l'état un moment,
				-- puis on l'oublie (sinon fuite).
				st.goneSince = st.goneSince or t
				if t - st.goneSince > 30 then
					rigs[model] = nil
				end
				continue
			end
			st.goneSince = nil
			local distance = (st.root.Position - camPos).Magnitude
			setActive(st, distance < FAR)
			if st.active then
				st.frame += 1
				-- Les persos lointains sont mis à jour une image sur deux.
				if distance < NEAR or st.frame % 2 == 0 then
					update(st, distance < NEAR and dt or dt * 2, t)
				end
			else
				st.lastPos = st.root.Position
			end
		end
	end)
end

return RigAnimator
