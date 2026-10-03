-- Animation procédurale des persos en blocs (marche, respiration, coups, attaques spéciales,
-- petites actions sur la base). Tout est calculé côté client en modifiant les Motor6D.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RigAnimator = {}

local rigs: { [Model]: any } = {}
local JOINTS = { "RootJoint", "Neck", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip" }
local IDLE_ACTIONS = { "punch", "wave", "flex", "kick", "punch" }

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
		local motors = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Motor6D") and table.find(JOINTS, descendant.Name) then
				local base = descendant:GetAttribute("BaseC0") or descendant.C0
				motors[descendant.Name] = { motor = descendant, base = base }
			end
		end
		if not motors.RootJoint then
			return
		end
		rigs[model] = {
			model = model,
			root = root,
			motors = motors,
			phase = 0,
			speed = 0,
			lastPos = root.Position,
			seed = math.random() * 10,
			lastAttackTick = model:GetAttribute("AttackTick"),
			lastSpecialTick = model:GetAttribute("SpecialTick"),
			lastHitTick = model:GetAttribute("HitTick"),
			attackStart = nil,
			specialStart = nil,
			hitStart = nil,
			nextIdleAction = os.clock() + math.random(3, 9),
			idleAction = nil,
			idleStart = 0,
			frame = 0,
		}
	end)
end

local function unregister(model: Instance)
	rigs[model :: Model] = nil
end

local function animate(st, dt: number, t: number)
	local model = st.model
	local root = st.root
	local scale = model:GetAttribute("BaseScale") or 1

	-- Vitesse de déplacement
	local pos = root.Position
	local velocity = (pos - st.lastPos) / math.max(dt, 1e-3)
	st.lastPos = pos
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if flatSpeed > 80 then
		flatSpeed = 0 -- téléportation
	end
	st.speed += (flatSpeed - st.speed) * math.min(1, dt * 10)
	local moving = st.speed > 1.2
	st.phase += dt * (st.speed / scale) * 1.5
	local amp = math.clamp(st.speed / (7 * scale), 0, 1) * 0.95
	local swing = math.sin(st.phase) * amp
	local breathe = math.sin(t * 2.2 + st.seed)

	local legL, legR = swing, -swing
	local armL, armR = -swing * 0.9 + breathe * 0.04, swing * 0.9 - breathe * 0.04
	local armLz, armRz = -0.1, 0.1
	local bob = moving and math.abs(math.sin(st.phase)) * 0.18 or breathe * 0.04
	local rootRot = CFrame.new()
	local neck = CFrame.Angles(breathe * 0.03, 0, 0)

	-- Coup / attaque
	local attackTick = model:GetAttribute("AttackTick")
	if attackTick ~= st.lastAttackTick then
		st.lastAttackTick = attackTick
		st.attackStart = t
		st.attackKind = model:GetAttribute("AttackKind") or "punch"
		st.attackSide = ((attackTick or 0) % 2 == 0)
	end
	if st.attackStart then
		local p = (t - st.attackStart) / 0.35
		if p >= 1 then
			st.attackStart = nil
		else
			local k = math.sin(p * math.pi)
			local kind = st.attackKind
			if kind == "beam" or kind == "orb" then
				armL, armR = 1.55 * k, 1.55 * k
				armLz, armRz = 0.25 * k, -0.25 * k
			elseif kind == "slash" then
				armR = 2.6 * k
				armRz = 0.2
				rootRot = CFrame.Angles(0, -0.5 * k, 0)
			elseif kind == "lightning" then
				armR = 1.7 * k
				legL = -0.5 * k
			elseif kind == "shadow" then
				armL, armR = 0.9 * k, 0.9 * k
				armLz, armRz = -0.6 * k, 0.6 * k
			else
				if st.attackSide then
					armR = 1.7 * k
				else
					armL = 1.7 * k
				end
				rootRot = CFrame.Angles(-0.12 * k, (st.attackSide and -0.3 or 0.3) * k, 0)
			end
		end
	end

	-- Attaque spéciale : pose héroïque + petit saut
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
			armL, armR = 2.9 * k, 2.9 * k
			armLz, armRz = -0.3 * k, 0.3 * k
			bob += 1.2 * k
			legL, legR = -0.6 * k, 0.4 * k
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
			rootRot *= CFrame.Angles(0.3 * math.sin(p * math.pi), 0, 0)
		end
	end

	-- Petites actions des persos exposés sur la base (vivant comme les poulets !)
	if root.Anchored and not st.attackStart then
		if not st.idleAction and t >= st.nextIdleAction then
			st.idleAction = IDLE_ACTIONS[math.random(1, #IDLE_ACTIONS)]
			st.idleStart = t
		end
		if st.idleAction then
			local p = (t - st.idleStart) / 1.2
			if p >= 1 then
				st.idleAction = nil
				st.nextIdleAction = t + math.random(4, 10)
			else
				local k = math.sin(p * math.pi)
				if st.idleAction == "punch" then
					local combo = math.floor(p * 4) % 2 == 0
					local kk = math.abs(math.sin(p * 4 * math.pi))
					if combo then
						armR = 1.6 * kk
					else
						armL = 1.6 * kk
					end
					rootRot = CFrame.Angles(-0.08, (combo and -0.25 or 0.25) * kk, 0)
				elseif st.idleAction == "wave" then
					armRz = 2.6 * k
					armR = math.sin(t * 14) * 0.3 * k
				elseif st.idleAction == "flex" then
					armL, armR = 1.2 * k, 1.2 * k
					armLz, armRz = -1.5 * k, 1.5 * k
					neck = CFrame.Angles(-0.2 * k, 0, 0)
				elseif st.idleAction == "kick" then
					legR = 1.6 * k
					armL = 0.6 * k
					rootRot = CFrame.Angles(0.15 * k, 0, 0)
				end
			end
		end
	end

	local m = st.motors
	m.RootJoint.motor.C0 = m.RootJoint.base * CFrame.new(0, bob * scale, 0) * rootRot
	if m.Neck then
		m.Neck.motor.C0 = m.Neck.base * neck
	end
	if m.LeftShoulder then
		m.LeftShoulder.motor.C0 = m.LeftShoulder.base * CFrame.Angles(armL, 0, armLz)
	end
	if m.RightShoulder then
		m.RightShoulder.motor.C0 = m.RightShoulder.base * CFrame.Angles(armR, 0, armRz)
	end
	if m.LeftHip then
		m.LeftHip.motor.C0 = m.LeftHip.base * CFrame.Angles(legL, 0, 0)
	end
	if m.RightHip then
		m.RightHip.motor.C0 = m.RightHip.base * CFrame.Angles(legR, 0, 0)
	end
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
				if not model.Parent then
					-- Le modèle peut revenir (perso K.O. qui revient) : on garde l'état.
					continue
				end
			end
			local distance = (st.root.Position - camPos).Magnitude
			if distance < 220 then
				st.frame += 1
				-- Les persos lointains sont animés une image sur deux.
				if distance < 90 or st.frame % 2 == 0 then
					animate(st, distance < 90 and dt or dt * 2, t)
				end
			else
				st.lastPos = st.root.Position
			end
		end
	end)
end

return RigAnimator
