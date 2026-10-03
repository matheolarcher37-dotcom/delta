-- Interactions avec le monde : objets qui tournent/flottent, minuteurs des autels,
-- boutons d'amélioration colorés selon tes pièces, clic sur un ennemi pour le cibler.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local State = require(script.Parent.Parent.State)

local WorldInteraction = {}

local player = Players.LocalPlayer
local spinners: { [Instance]: any } = {}
local marker: Part? = nil
local targetModel: Model? = nil

local function addSpinner(instance: Instance)
	if spinners[instance] or not instance.Parent then
		return
	end
	if instance:IsA("BasePart") then
		spinners[instance] = { base = instance.CFrame, phase = math.random() * 6 }
	elseif instance:IsA("Model") then
		spinners[instance] = { base = instance:GetPivot(), phase = math.random() * 6, model = true }
	end
end

local function axisRotation(axis: string?, angle: number): CFrame
	if axis == "X" then
		return CFrame.Angles(angle, 0, 0)
	elseif axis == "Z" then
		return CFrame.Angles(0, 0, angle)
	end
	return CFrame.Angles(0, angle, 0)
end

local function setTarget(model: Model?)
	targetModel = model
	Remotes.event("SetTarget"):FireServer(model)
	if not marker then
		local part = Instance.new("Part")
		part.Name = "TargetMarker"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 60, 60)
		part.Transparency = 0.35
		part.Parent = Workspace
		marker = part
	end
end

function WorldInteraction.init()
	for _, tag in { "Spin", "SpinModel" } do
		for _, instance in CollectionService:GetTagged(tag) do
			addSpinner(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			task.wait()
			addSpinner(instance)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			spinners[instance] = nil
		end)
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for instance, info in spinners do
			if not instance.Parent then
				continue
			end
			local speed = instance:GetAttribute("SpinSpeed") or 1
			local bob = instance:GetAttribute("Bob") or 0
			local cf = info.base * CFrame.new(0, math.sin(t * 2 + info.phase) * bob, 0) * axisRotation(instance:GetAttribute("SpinAxis"), t * speed)
			if info.model then
				(instance :: Model):PivotTo(cf)
			else
				(instance :: BasePart).CFrame = cf
			end
		end
		-- Marqueur de cible sous l'ennemi.
		if marker then
			local root = targetModel and targetModel.Parent and targetModel.PrimaryPart
			if root and not targetModel:GetAttribute("Dead") then
				local scale = targetModel:GetAttribute("BaseScale") or 1
				local size = 4 * scale
				marker.Size = Vector3.new(0.2, size, size)
				marker.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.05 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(t * 2, 0, 0)
				marker.Transparency = 0.35
			else
				marker.Transparency = 1
				targetModel = nil
			end
		end
	end)

	-- Clic / toucher sur un ennemi = cible prioritaire.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local enemyFolder = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Zone") and Workspace.World.Zone:FindFirstChild("Enemies")
		if not enemyFolder then
			return
		end
		params.FilterDescendantsInstances = { enemyFolder }
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			while model and not CollectionService:HasTag(model, "Enemy") do
				model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") or nil
			end
			if model then
				setTarget(model)
			end
		end
	end)

	-- Textes des autels + couleur des boutons d'amélioration.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = State.now()
			for _, pedestal in CollectionService:GetTagged("Pedestal") do
				local top = pedestal:FindFirstChild("Top")
				local gui = top and top:FindFirstChild("Timer")
				local label = gui and gui:FindFirstChild("Text") :: TextLabel?
				local glow = pedestal:FindFirstChild("Glow") :: BasePart?
				if label then
					local readyAt = pedestal:GetAttribute("ReadyAt")
					if readyAt then
						local remaining = readyAt - now
						if remaining > 0 then
							label.Text = (pedestal:GetAttribute("RelicName") or "Relique") .. "\n⏳ " .. Formulas.formatTime(remaining)
							label.TextColor3 = Color3.new(1, 1, 1)
						else
							label.Text = "✨ PRÊT ! ✨\nAppuie sur E"
							label.TextColor3 = Color3.fromHSV((os.clock() * 0.5) % 1, 0.5, 1)
						end
						if glow then
							glow.Color = remaining > 0 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(120, 255, 140)
						end
					else
						local plot = pedestal:FindFirstAncestorWhichIsA("Model")
						while plot and not plot:GetAttribute("PlotIndex") do
							plot = plot.Parent and plot.Parent:FindFirstAncestorWhichIsA("Model") or nil
						end
						local mine = plot and plot:GetAttribute("OwnerId") == player.UserId
						label.Text = mine and "Autel libre\nPose une relique" or ""
						if glow then
							glow.Color = Color3.fromRGB(120, 220, 255)
						end
					end
				end
			end
			local coins = State.data and State.data.coins or 0
			for _, pad in CollectionService:GetTagged("UpgradePad") do
				local part = pad:FindFirstChild("Pad") :: BasePart?
				local price = pad:GetAttribute("Price") or 0
				local plot = pad:FindFirstAncestorWhichIsA("Model")
				while plot and not plot:GetAttribute("PlotIndex") do
					plot = plot.Parent and plot.Parent:FindFirstAncestorWhichIsA("Model") or nil
				end
				if part and plot and plot:GetAttribute("OwnerId") == player.UserId then
					part.Color = coins >= price and Color3.fromRGB(80, 230, 120) or Color3.fromRGB(230, 90, 90)
				end
			end
		end
	end)
end

return WorldInteraction
