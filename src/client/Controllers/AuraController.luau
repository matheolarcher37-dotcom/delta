-- Auras visuelles des persos (comme les poulets "électrique" et "néant" de l'image) :
-- éclairs jaunes, cubes violets en orbite, flammes, givre, paillettes dorées, arc-en-ciel.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Config.Auras)

local AuraController = {}

local active: { [Model]: any } = {}
local rng = Random.new()
local folder: Folder

local function newPart(size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.Color = color
	part.Parent = folder
	return part
end

local function particles(parent: Instance, color: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
	return emitter
end

local function clear(model: Model)
	local state = active[model]
	if not state then
		return
	end
	for _, instance in state.instances do
		instance:Destroy()
	end
	active[model] = nil
end

local function apply(model: Model)
	clear(model)
	local auraId = model:GetAttribute("Aura")
	local aura = Auras.get(auraId)
	if not aura then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if not root or not torso then
		return
	end
	local scale = model:GetAttribute("BaseScale") or 1
	local state = { model = model, root = root, aura = aura, scale = scale, instances = {}, orbit = {}, nextBolt = 0 }

	local light = Instance.new("PointLight")
	light.Color = aura.color
	light.Range = 10 * scale
	light.Brightness = 1.5
	light.Parent = torso
	table.insert(state.instances, light)

	if aura.effect == "lightning" then
		table.insert(state.instances, particles(torso, aura.color, 12, 0.4 * scale))
	elseif aura.effect == "cubes" or aura.effect == "rainbow" then
		for i = 1, 7 do
			local cube = newPart(Vector3.one * rng:NextNumber(0.5, 0.9) * scale, aura.color)
			table.insert(state.instances, cube)
			table.insert(state.orbit, {
				part = cube,
				radius = rng:NextNumber(2.2, 3.4) * scale,
				height = rng:NextNumber(-2, 3) * scale,
				speed = rng:NextNumber(1.2, 2.4) * (i % 2 == 0 and 1 or -1),
				phase = i,
			})
		end
		table.insert(state.instances, particles(torso, aura.color, 8, 0.5 * scale))
	elseif aura.effect == "fire" then
		local fire = Instance.new("Fire")
		fire.Color = aura.color
		fire.SecondaryColor = Color3.fromRGB(255, 230, 90)
		fire.Size = 4 * scale
		fire.Heat = 6
		fire.Parent = torso
		table.insert(state.instances, fire)
	elseif aura.effect == "frost" then
		table.insert(state.instances, particles(torso, aura.color, 16, 0.5 * scale))
		for i = 1, 4 do
			local shard = newPart(Vector3.new(0.4, 1.2, 0.4) * scale, aura.color)
			shard.Transparency = 0.25
			table.insert(state.instances, shard)
			table.insert(state.orbit, { part = shard, radius = 2.4 * scale, height = (i - 2) * 0.8 * scale, speed = 0.8, phase = i * 1.57 })
		end
	elseif aura.effect == "gold" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = aura.color
		sparkles.Parent = torso
		table.insert(state.instances, sparkles)
		table.insert(state.instances, particles(torso, aura.color, 10, 0.35 * scale))
	end
	active[model] = state
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.spawn(function()
		model:WaitForChild("Torso", 10)
		apply(model)
	end)
	model:GetAttributeChangedSignal("Aura"):Connect(function()
		apply(model)
	end)
end

function AuraController.init()
	folder = Instance.new("Folder")
	folder.Name = "AuraFX"
	folder.Parent = Workspace

	for _, model in CollectionService:GetTagged("AnimeRig") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("AnimeRig"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("AnimeRig"):Connect(function(model)
		clear(model :: Model)
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camera = Workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		for model, state in active do
			if not model.Parent then
				-- Perso K.O. ou détruit : on cache les effets.
				for _, item in state.orbit do
					item.part.Transparency = 1
				end
				continue
			end
			local center = state.root.Position
			local near = (center - camPos).Magnitude < 150
			for _, item in state.orbit do
				local angle = t * item.speed + item.phase
				local hue = state.aura.effect == "rainbow" and Color3.fromHSV((t * 0.3 + item.phase * 0.14) % 1, 0.8, 1) or nil
				if hue then
					item.part.Color = hue
				end
				item.part.Transparency = near and (state.aura.effect == "frost" and 0.25 or 0) or 1
				item.part.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * item.radius, item.height + math.sin(t * 2 + item.phase) * 0.4, math.sin(angle) * item.radius))
					* CFrame.Angles(t * 2, t * 1.5, 0)
			end
			-- Petits éclairs autour du perso (cœur blanc + halo coloré, parfois une branche).
			if state.aura.effect == "lightning" and near and t >= state.nextBolt then
				local lowQuality = Players.LocalPlayer and Players.LocalPlayer:GetAttribute("FxQuality") == "low"
				state.nextBolt = t + rng:NextNumber(0.12, 0.4) * (lowQuality and 2 or 1)
				local s = state.scale
				local from = center + Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-2, 3), rng:NextNumber(-1.8, 1.8)) * s
				local previous = from
				for i = 1, 3 do
					local point = previous + Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(-1.5, 0.5), rng:NextNumber(-1.2, 1.2)) * s
					local length = (point - previous).Magnitude
					local cf = CFrame.lookAt((previous + point) / 2, point)
					local core = newPart(Vector3.new(0.09 * s, 0.09 * s, length), Color3.new(1, 1, 1):Lerp(state.aura.color, 0.25))
					core.CFrame = cf
					local halo = newPart(Vector3.new(0.32 * s, 0.32 * s, length + 0.1 * s), state.aura.color)
					halo.Transparency = 0.6
					halo.CFrame = cf
					local parts = { core, halo }
					if i == 2 and not lowQuality and rng:NextNumber() < 0.5 then
						local branchEnd = point + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 0.6), rng:NextNumber(-1, 1)) * s
						local branch = newPart(Vector3.new(0.06 * s, 0.06 * s, (branchEnd - point).Magnitude), state.aura.color)
						branch.CFrame = CFrame.lookAt((point + branchEnd) / 2, branchEnd)
						table.insert(parts, branch)
					end
					task.delay(0.08, function()
						for _, part in parts do
							part:Destroy()
						end
					end)
					previous = point
				end
			end
		end
	end)
end

return AuraController
