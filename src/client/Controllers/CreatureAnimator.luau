-- Animation procédurale des CRÉATURES (Kourama, le renard à neuf queues — Modules/CreatureBuilder) :
--   * les neuf queues ondulent en décalé (plus fort au bout, et quand il marche ou rugit) ;
--   * respiration (torse qui se soulève, gueule qui s'entrouvre), tête qui bouge un peu ;
--   * marche à quatre pattes (trot) quand il se déplace ;
--   * oreilles qui frémissent de temps en temps (et se couchent quand il rugit) ;
--   * attaque : coup de griffe d'une patte avant avec un bond, ou grand rugissement ;
--   * recul quand il est touché.
-- Tout se fait en local en modifiant les C0 des Motor6D (le modèle n'est jamais ancré).
-- Seules les créatures assez proches de la caméra sont animées (moins souvent de loin).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CreatureAnimator = {}

local NEAR, FAR = 150, 320 -- studs (le boss mesure une trentaine de studs avec ses queues)
local TAU = math.pi * 2

local rigs: { [Model]: any } = {}

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
		local stillHere = false
		pcall(function()
			stillHere = model:IsDescendantOf(Workspace)
		end)
		if not stillHere or rigs[model :: Model] or not model:GetAttribute("Creature") then
			return
		end
		local motors = {}
		local tails = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Motor6D") then
				local entry = { motor = descendant, base = descendant:GetAttribute("BaseC0") or descendant.C0 }
				motors[descendant.Name] = entry
				local i, k = string.match(descendant.Name, "^Tail(%d+)_(%d+)$")
				if i then
					local index = tonumber(i) :: number
					tails[index] = tails[index] or {}
					tails[index][tonumber(k) :: number] = entry
				end
			end
		end
		local t = os.clock()
		rigs[model :: Model] = {
			model = model,
			root = root,
			motors = motors,
			tails = tails,
			speed = 0,
			move = 0,
			phase = 0,
			lastPos = root.CFrame.Position,
			seed = math.random() * 10,
			lastAttackTick = model:GetAttribute("AttackTick"),
			lastHitTick = model:GetAttribute("HitTick"),
			attackCount = 0,
			ears = { Left = t + math.random() * 3, Right = t + 1 + math.random() * 3 },
			earStart = {},
			frame = 0,
		}
	end)
end

local function unregister(model: Instance)
	rigs[model :: Model] = nil
end

local function set(st, name: string, offset: CFrame)
	local entry = st.motors[name]
	if entry then
		entry.motor.C0 = entry.base * offset
	end
end

-- Courbe 0 -> 1 -> 0 sur la durée d'une action (p de 0 à 1).
local function bump(p: number): number
	return math.sin(math.clamp(p, 0, 1) * math.pi)
end

local function update(st, dt: number, t: number)
	local model = st.model
	local s = model:GetAttribute("BaseScale") or 1
	local pos = st.root.CFrame.Position
	local velocity = (pos - st.lastPos) / math.max(dt, 1e-3)
	st.lastPos = pos
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if flatSpeed > 120 then
		flatSpeed = 0 -- téléportation
	end
	st.speed += (flatSpeed - st.speed) * math.min(1, dt * 6)
	local target = st.speed > 1.5 and 1 or 0
	st.move += (target - st.move) * math.min(1, dt * 4)
	local move = st.move
	-- Une foulée complète tous les ~5 studs (x l'échelle).
	st.phase = (st.phase + dt * st.speed / (5 * s) * TAU) % TAU
	local phase = st.phase

	-- Attaque : coup de griffe (2 fois sur 3) ou rugissement.
	local attackTick = model:GetAttribute("AttackTick")
	if attackTick ~= st.lastAttackTick then
		st.lastAttackTick = attackTick
		st.attackCount += 1
		st.attackStart = t
		st.attackKind = st.attackCount % 3 == 0 and "roar" or "claw"
		st.attackSide = st.attackCount % 2 == 0 and "Left" or "Right"
	end
	local claw, roar, clawP = 0, 0, 0
	if st.attackStart then
		local duration = st.attackKind == "roar" and 1.2 or 0.6
		local p = (t - st.attackStart) / duration
		if p >= 1 then
			st.attackStart = nil
		elseif st.attackKind == "roar" then
			-- Montée rapide, tenue, puis relâchement.
			roar = p < 0.15 and p / 0.15 or (p < 0.7 and 1 or (1 - p) / 0.3)
		else
			claw = bump(p)
			clawP = p
		end
	end
	local hit = 0
	local hitTick = model:GetAttribute("HitTick")
	if hitTick ~= st.lastHitTick then
		st.lastHitTick = hitTick
		st.hitStart = t
	end
	if st.hitStart then
		local p = (t - st.hitStart) / 0.25
		if p >= 1 then
			st.hitStart = nil
		else
			hit = bump(p)
		end
	end

	local breath = math.sin(t * 1.7 + st.seed)
	local step = math.sin(phase)

	-- Corps : respiration, petit balancement du trot, bond du coup de griffe, recul.
	local bob = breath * 0.03 + math.abs(math.cos(phase)) * 0.1 * move - claw * 0.05 + roar * 0.12
	local lunge = -claw * 0.6 + hit * 0.15
	local pitch = breath * 0.012 + claw * 0.12 + roar * 0.14 - hit * 0.08
	set(st, "RootJoint", CFrame.new(0, bob * s, lunge * s) * CFrame.Angles(pitch, step * 0.04 * move, step * 0.03 * move))
	set(st, "Spine", CFrame.Angles(-breath * 0.02 - roar * 0.08, -step * 0.08 * move, 0))
	-- Tête : regarde un peu autour, hoche en marchant, se dresse pour rugir.
	local look = math.sin(t * 0.55 + st.seed) * 0.12 * (1 - move)
	local nod = math.sin(phase * 2) * 0.05 * move + roar * 0.35 - claw * 0.12 + hit * 0.1
	set(st, "Neck", CFrame.Angles(nod + breath * 0.02, look, math.sin(t * 0.4 + st.seed) * 0.04))
	set(st, "Jaw", CFrame.Angles(-(0.05 + (breath + 1) * 0.03 + roar * 0.55 + claw * 0.15), 0, 0))

	-- Oreilles : frémissement de temps en temps, couchées en arrière pendant le rugissement.
	for _, side in { "Left", "Right" } do
		local sx = side == "Left" and -1 or 1
		if t >= st.ears[side] then
			st.earStart[side] = t
			st.ears[side] = t + 1.5 + math.random() * 4
		end
		local twitch = 0
		local start = st.earStart[side]
		if start then
			local p = (t - start) / 0.3
			if p >= 1 then
				st.earStart[side] = nil
			else
				twitch = math.sin(p * TAU * 2) * (1 - p)
			end
		end
		set(st, side .. "EarJoint", CFrame.Angles(twitch * 0.25 + roar * 0.6 + hit * 0.3, twitch * 0.2 * sx, sx * (twitch * 0.15 - roar * 0.25)))
	end

	-- Pattes : trot (diagonales ensemble) + coup de griffe d'une patte avant.
	for _, side in { "Left", "Right" } do
		local sx = side == "Left" and -1 or 1
		local front = side == "Left" and 0 or math.pi
		local back = front + math.pi
		local swing = math.sin(phase + front) * 0.4 * move
		local lift = math.max(0, math.cos(phase + front)) * 0.7 * move
		-- L'avant-bras penche vers l'avant : le replier vers l'avant soulève la patte (jambe levée,
		-- ou ramenée en arrière, sinon elle s'enfoncerait dans le sol).
		local shoulder, elbow, outward = swing, lift * 0.6 + math.max(0, -swing) * 1.4, 0
		if claw > 0 and side == st.attackSide then
			-- Préparation (patte levée vers l'avant), puis frappe vers le bas.
			local raise = clawP < 0.45 and clawP / 0.45 or math.max(0, 1 - (clawP - 0.45) / 0.3)
			shoulder = 1.5 * raise - 0.2 * claw
			elbow = -0.9 * raise
			outward = 0.25 * raise
		elseif roar > 0 then
			shoulder += roar * 0.15
		end
		set(st, side .. "Shoulder", CFrame.Angles(shoulder, 0, -sx * outward))
		set(st, side .. "Elbow", CFrame.Angles(elbow, 0, 0))
		local hipSwing = math.sin(phase + back) * 0.4 * move
		local knee = math.max(0, math.cos(phase + back)) * 0.5 * move
		set(st, side .. "Hip", CFrame.Angles(hipSwing - claw * 0.2, 0, 0))
		set(st, side .. "Knee", CFrame.Angles(knee, 0, 0))
	end

	-- Queues : vagues décalées d'une queue à l'autre et le long de chaque queue.
	local energy = 1 + move * 0.7 + roar * 1.3 + hit * 0.8
	for i, chain in st.tails do
		local offset = i * 0.83 + st.seed
		for k, entry in chain do
			local amp = (0.035 + 0.022 * k) * energy
			local wave = math.sin(t * 1.5 + offset - k * 0.6) * amp
			local swayBack = math.sin(t * 1.05 + offset * 1.7 - k * 0.5) * amp * 0.6 - roar * 0.06
			entry.motor.C0 = entry.base * CFrame.Angles(swayBack, 0, wave)
		end
	end
end

function CreatureAnimator.init()
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
				st.goneSince = st.goneSince or t
				if t - st.goneSince > 30 then
					rigs[model] = nil
				end
				continue
			end
			st.goneSince = nil
			if model:GetAttribute("Dead") then
				continue
			end
			local distance = (st.root.CFrame.Position - camPos).Magnitude
			st.frame += 1
			st.acc = (st.acc or 0) + dt
			if distance > FAR then
				st.lastPos = st.root.CFrame.Position
				st.acc = 0
			elseif distance < NEAR or st.frame % 3 == 0 then
				-- De loin : une image sur trois (avec le temps écoulé cumulé).
				update(st, st.acc, t)
				st.acc = 0
			end
		end
	end)
end

CreatureAnimator._rigs = rigs -- pour les tests

return CreatureAnimator
