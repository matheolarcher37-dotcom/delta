-- Construit les épées en pièces (outil "Tool" du joueur ou modèle d'aperçu du Forgeron).
-- La poignée (Handle) est tenue dans la main ; la lame part vers -Z de la poignée,
-- c'est-à-dire vers l'avant quand le bras est tendu (prise standard des outils Roblox).

local SwordBuilder = {}

local function weld(handle: BasePart, part: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = handle
	constraint.Part1 = part
	constraint.Parent = part
end

local function piece(parent: Instance, handle: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = handle.CFrame * offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = handle.Anchored
	if props then
		local target: any = part
		for key, value in props do
			target[key] = value
		end
	end
	part.Parent = parent
	weld(handle, part)
	return part
end

-- Ajoute la lame, la garde et la traînée autour d'une poignée déjà créée.
local function dress(parent: Instance, handle: BasePart, sword)
	local look = sword.look
	local length, width = look.length, look.width
	local material = Enum.Material[look.material or "Metal"] or Enum.Material.Metal
	local bladeProps = { Material = material, Reflectance = material == Enum.Material.Metal and 0.2 or 0 }
	if material == Enum.Material.Glass then
		bladeProps.Transparency = 0.15
	end
	local start = -0.75 -- début de la lame (devant la garde)
	local tip = start - length

	-- Garde
	if look.style == "katana" then
		piece(parent, handle, "Guard", Vector3.new(0.12, 0.7, 0.7), CFrame.new(0, 0, -0.55) * CFrame.Angles(0, math.rad(90), 0), look.guard, { Shape = Enum.PartType.Cylinder })
	elseif look.style == "cleaver" then
		piece(parent, handle, "Guard", Vector3.new(0.5, 0.5, 0.3), CFrame.new(0, 0, -0.6), look.guard)
	else
		piece(parent, handle, "Guard", Vector3.new(1.4, 0.22, 0.26), CFrame.new(0, 0, -0.6), look.guard, { Material = Enum.Material.Metal })
	end

	-- Lame
	if look.style == "cleaver" then
		piece(parent, handle, "Blade", Vector3.new(width, 0.12, length), CFrame.new(width * 0.3, 0, start - length / 2), look.blade, bladeProps)
		piece(parent, handle, "Hole", Vector3.new(0.4, 0.14, 0.4), CFrame.new(width * 0.3 + width * 0.22, 0, tip + 0.6), Color3.fromRGB(20, 20, 25))
	elseif look.style == "jagged" then
		piece(parent, handle, "Blade", Vector3.new(width, 0.12, length), CFrame.new(0, 0, start - length / 2), look.blade, bladeProps)
		for i = 0, 3 do
			piece(
				parent,
				handle,
				"Spike",
				Vector3.new(0.35, 0.1, 0.6),
				CFrame.new(width * 0.55, 0, start - 0.6 - i * length / 4) * CFrame.Angles(0, math.rad(35), 0),
				look.blade,
				bladeProps
			)
		end
	else
		-- Lame droite ou légèrement courbée (katana) : deux segments.
		local curve = look.style == "katana" and math.rad(4) or 0
		local half = length / 2
		piece(parent, handle, "Blade", Vector3.new(width, 0.1, half + 0.05), CFrame.new(0, 0, start - half / 2), look.blade, bladeProps)
		local second = CFrame.new(0, 0, start - half) * CFrame.Angles(0, curve, 0) * CFrame.new(0, 0, -half / 2)
		piece(parent, handle, "Blade2", Vector3.new(width * 0.95, 0.1, half), second, look.blade, bladeProps)
		local tipCF = CFrame.new(0, 0, start - half) * CFrame.Angles(0, curve, 0) * CFrame.new(0, 0, -half - width * 0.35) * CFrame.Angles(0, math.rad(45), 0)
		piece(parent, handle, "Tip", Vector3.new(width * 0.7, 0.09, width * 0.7), tipCF, look.blade, bladeProps)
	end
	if look.edge then
		piece(parent, handle, "Edge", Vector3.new(0.06, 0.12, length * 0.92), CFrame.new(-width / 2, 0, start - length * 0.48), look.edge, { Material = Enum.Material.Neon })
	end
	if look.style == "holy" then
		local gem = piece(
			parent,
			handle,
			"Gem",
			Vector3.new(0.45, 0.45, 0.45),
			CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			look.edge or look.trail,
			{ Material = Enum.Material.Neon }
		)
		local light = Instance.new("PointLight")
		light.Color = look.trail
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = gem
	end

	-- Traînée lumineuse pendant les coups.
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, 0, start - 0.3)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, 0, tip)
	a1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(look.trail, look.trail:Lerp(Color3.new(1, 1, 1), 0.5))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.18
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle
end

-- Outil à donner au joueur (va dans son sac à dos).
function SwordBuilder.buildTool(sword): Tool
	local tool = Instance.new("Tool")
	tool.Name = sword.name
	tool.ToolTip = sword.name .. " · " .. sword.damage .. " dégâts"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new()
	local look = sword.look
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.1)
	handle.Color = look.hilt
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool
	piece(tool, handle, "Pommel", Vector3.new(0.38, 0.38, 0.25), CFrame.new(0, 0, 0.62), look.guard)
	dress(tool, handle, sword)
	tool:SetAttribute("SwordId", sword.id)
	local equip = Instance.new("Sound")
	equip.Name = "Unsheath"
	equip.SoundId = "rbxasset://sounds/unsheath.wav"
	equip.Volume = 0.5
	equip.Parent = handle
	local slash = Instance.new("Sound")
	slash.Name = "Slash"
	slash.SoundId = "rbxasset://sounds/swordslash.wav"
	slash.Volume = 0.6
	slash.Parent = handle
	return tool
end

-- Modèle ancré pour l'aperçu dans le menu du Forgeron (lame vers le haut).
function SwordBuilder.buildModel(sword): Model
	local tool = SwordBuilder.buildTool(sword)
	local model = Instance.new("Model")
	model.Name = sword.name
	for _, child in tool:GetChildren() do
		child.Parent = model
	end
	tool:Destroy()
	local handle = model:FindFirstChild("Handle") :: BasePart
	model.PrimaryPart = handle
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		elseif descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(math.rad(-90), 0, 0))
	return model
end

return SwordBuilder
