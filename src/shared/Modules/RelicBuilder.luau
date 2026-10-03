-- Construit les reliques (l'équivalent des œufs) : parchemin, doigt maudit, boule de cristal, fruit du démon...
-- Le modèle est centré en (0, 0, 0) avec le bas posé à y = 0. Toutes les pièces sont ancrées.

local RelicBuilder = {}

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function newContext(model: Model, s: number)
	local ctx = {}
	function ctx.add(name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * s
		part.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = true
		if props then
			local target: any = part
			for key, value in props do
				target[key] = value
			end
		end
		part.Parent = model
		return part
	end
	return ctx
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre vertical

local KINDS = {}

KINDS.scroll = function(ctx, look)
	local paper = look.accent
	local cap = look.color
	ctx.add("Paper", Vector3.new(2.6, 1.3, 1.3), CFrame.new(0, 0.75, 0), paper, { Shape = Enum.PartType.Cylinder })
	for _, side in { -1, 1 } do
		ctx.add("Cap", Vector3.new(0.35, 1.5, 1.5), CFrame.new(1.4 * side, 0.75, 0), cap, { Shape = Enum.PartType.Cylinder })
		ctx.add("Knob", Vector3.new(0.3, 0.6, 0.6), CFrame.new(1.7 * side, 0.75, 0), darken(cap, 0.3), { Shape = Enum.PartType.Cylinder })
	end
	ctx.add("Seal", Vector3.new(0.5, 1.36, 1.36), CFrame.new(0, 0.75, 0), cap, { Shape = Enum.PartType.Cylinder })
	ctx.add("SealMark", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.75, -0.72), lighten(cap, 0.5), { Material = Enum.Material.Neon })
end

KINDS.talisman = function(ctx, look)
	ctx.add("Paper", Vector3.new(1.3, 2.4, 0.08), CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, 0.08), look.color)
	for i = 0, 3 do
		ctx.add("Glyph", Vector3.new(0.6 - i * 0.08, 0.12, 0.1), CFrame.new(0, 2.0 - i * 0.42, -0.02) * CFrame.Angles(0, 0, 0.08), look.accent)
	end
	ctx.add("Glyph", Vector3.new(0.12, 1.6, 0.1), CFrame.new(0, 1.35, -0.03) * CFrame.Angles(0, 0, 0.08), look.accent)
	ctx.add("Stand", Vector3.new(0.9, 0.2, 0.6), CFrame.new(0, 0.1, 0), darken(look.accent, 0.3))
end

KINDS.box = function(ctx, look)
	ctx.add("Box", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(20), 0), look.color, { Material = Enum.Material.Wood })
	for _, y in { 0.25, 1.55 } do
		ctx.add("Band", Vector3.new(1.86, 0.15, 1.86), CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(20), 0), look.accent, { Material = Enum.Material.Metal })
	end
	ctx.add("Seal", Vector3.new(0.5, 1.6, 0.06), CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(20), 0) * CFrame.new(0, 0, -0.93), Color3.fromRGB(245, 235, 200))
	ctx.add(
		"Eye",
		Vector3.new(0.35, 0.2, 0.06),
		CFrame.new(0, 1.05, 0) * CFrame.Angles(0, math.rad(20), 0) * CFrame.new(0, 0, -0.96),
		Color3.fromRGB(220, 30, 40),
		{ Material = Enum.Material.Neon }
	)
end

KINDS.finger = function(ctx, look)
	local flesh = look.color
	local cf = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-12))
	ctx.add("Seg1", Vector3.new(0.75, 1.1, 0.75), cf * CFrame.new(0, 0.55, 0), flesh)
	ctx.add("Knuckle1", Vector3.new(0.82, 0.2, 0.82), cf * CFrame.new(0, 1.15, 0), darken(flesh, 0.2))
	ctx.add("Seg2", Vector3.new(0.7, 0.9, 0.7), cf * CFrame.new(0, 1.65, 0), flesh)
	ctx.add("Knuckle2", Vector3.new(0.76, 0.18, 0.76), cf * CFrame.new(0, 2.15, 0), darken(flesh, 0.2))
	ctx.add("Seg3", Vector3.new(0.64, 0.7, 0.64), cf * CFrame.new(0, 2.55, 0), flesh)
	ctx.add("Nail", Vector3.new(0.5, 0.45, 0.08), cf * CFrame.new(0, 2.65, -0.33), look.accent)
	ctx.add("Wrap", Vector3.new(0.8, 0.3, 0.8), cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(245, 235, 200))
	ctx.add("WrapMark", Vector3.new(0.2, 0.32, 0.82), cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(200, 30, 40))
end

KINDS.capsule = function(ctx, look)
	local cf = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.rad(30), math.rad(15))
	ctx.add("Top", Vector3.new(1.0, 1.1, 1.1), cf * CFrame.new(0.5, 0, 0), look.color, { Shape = Enum.PartType.Cylinder })
	ctx.add("Bottom", Vector3.new(1.0, 1.1, 1.1), cf * CFrame.new(-0.5, 0, 0), look.accent, { Shape = Enum.PartType.Cylinder })
	ctx.add("CapTop", Vector3.new(1.1, 1.1, 1.1), cf * CFrame.new(1.0, 0, 0), look.color, { Shape = Enum.PartType.Ball })
	ctx.add("CapBottom", Vector3.new(1.1, 1.1, 1.1), cf * CFrame.new(-1.0, 0, 0), look.accent, { Shape = Enum.PartType.Ball })
	ctx.add("Ring", Vector3.new(0.15, 1.18, 1.18), cf, Color3.fromRGB(60, 60, 70), { Shape = Enum.PartType.Cylinder })
	ctx.add("Button", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(1.5, 0, 0), Color3.fromRGB(60, 60, 70), { Shape = Enum.PartType.Ball })
end

KINDS.orb = function(ctx, look)
	ctx.add(
		"Orb",
		Vector3.new(2.0, 2.0, 2.0),
		CFrame.new(0, 1.2, 0),
		look.color,
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2 }
	)
	ctx.add("Core", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 1.2, 0), lighten(look.color, 0.2), { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Transparency = 0.45 })
	-- Étoiles à l'intérieur (en losange).
	local stars = { Vector3.new(0, 1.55, -0.85), Vector3.new(-0.45, 1.05, -0.85), Vector3.new(0.45, 1.05, -0.85), Vector3.new(0, 0.8, -0.9) }
	for _, pos in stars do
		ctx.add("Star", Vector3.new(0.28, 0.28, 0.12), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(45)), look.accent, { Material = Enum.Material.Neon })
	end
	ctx.add("Stand", Vector3.new(0.3, 1.2, 1.2), CFrame.new(0, 0.15, 0) * UP, Color3.fromRGB(90, 70, 60), { Shape = Enum.PartType.Cylinder })
end

KINDS.bottle = function(ctx, look)
	local cf = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(25), math.rad(8))
	ctx.add("Glass", Vector3.new(2.0, 1.1, 1.1), cf, look.color, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.35 })
	ctx.add("Neck", Vector3.new(0.7, 0.55, 0.55), cf * CFrame.new(1.25, 0, 0), look.color, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Transparency = 0.3 })
	ctx.add("Cork", Vector3.new(0.35, 0.5, 0.5), cf * CFrame.new(1.7, 0, 0), Color3.fromRGB(170, 120, 70), { Shape = Enum.PartType.Cylinder })
	ctx.add("Letter", Vector3.new(1.4, 0.55, 0.55), cf, look.accent, { Shape = Enum.PartType.Cylinder })
	ctx.add("Ribbon", Vector3.new(0.12, 0.6, 0.6), cf * CFrame.new(0.2, 0, 0), Color3.fromRGB(220, 40, 40), { Shape = Enum.PartType.Cylinder })
end

KINDS.chest = function(ctx, look)
	local wood = look.color
	local gold = look.accent
	ctx.add("Body", Vector3.new(2.4, 1.2, 1.6), CFrame.new(0, 0.6, 0), wood, { Material = Enum.Material.Wood })
	ctx.add("Lid", Vector3.new(2.4, 1.6, 1.6), CFrame.new(0, 1.2, 0), darken(wood, 0.1), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	for _, x in { -0.9, 0.9 } do
		ctx.add("Strap", Vector3.new(0.25, 1.25, 1.65), CFrame.new(x, 0.6, 0), gold, { Material = Enum.Material.Metal })
		ctx.add("LidStrap", Vector3.new(0.25, 1.65, 1.65), CFrame.new(x, 1.2, 0), gold, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end
	ctx.add("Lock", Vector3.new(0.4, 0.5, 0.15), CFrame.new(0, 1.05, -0.85), gold, { Material = Enum.Material.Metal })
	ctx.add("Coins", Vector3.new(1.8, 0.2, 1.0), CFrame.new(0, 1.25, 0), Color3.fromRGB(255, 210, 60), { Material = Enum.Material.Neon, Transparency = 0.3 })
end

KINDS.fruit = function(ctx, look)
	ctx.add("Fruit", Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, 1.0, 0), look.color, { Shape = Enum.PartType.Ball })
	-- Spirales caractéristiques.
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local cf = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.1, -0.92)
		ctx.add("Swirl", Vector3.new(0.35, 0.35, 0.1), cf * CFrame.Angles(0, 0, math.rad(45)), lighten(look.color, 0.35))
		ctx.add("SwirlCore", Vector3.new(0.15, 0.15, 0.12), cf, darken(look.color, 0.35))
	end
	ctx.add("Swirl", Vector3.new(0.5, 0.5, 0.1), CFrame.new(0, 1.92, 0) * CFrame.Angles(math.rad(90), 0, math.rad(45)), lighten(look.color, 0.35))
	ctx.add("Stem", Vector3.new(0.18, 0.7, 0.18), CFrame.new(0.05, 2.15, 0) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(90, 70, 40))
	ctx.add("Leaf", Vector3.new(0.7, 0.1, 0.4), CFrame.new(0.4, 2.3, 0) * CFrame.Angles(0, 0, 0.3), look.accent)
end

KINDS.tsuba = function(ctx, look)
	ctx.add(
		"Guard",
		Vector3.new(0.25, 2.2, 2.2),
		CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(90), 0),
		look.color,
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal }
	)
	ctx.add(
		"Rim",
		Vector3.new(0.3, 2.3, 2.3),
		CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(90), 0),
		look.accent,
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Transparency = 0.6 }
	)
	ctx.add("Hole", Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, 1.2, 0), Color3.fromRGB(20, 20, 20))
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		ctx.add(
			"Pattern",
			Vector3.new(0.35, 0.35, 0.3),
			CFrame.new(math.cos(angle) * 0.65, 1.2 + math.sin(angle) * 0.65, 0) * CFrame.Angles(0, 0, angle),
			look.accent,
			{ Material = Enum.Material.Metal }
		)
	end
	ctx.add("Stand", Vector3.new(1.0, 0.2, 0.6), CFrame.new(0, 0.1, 0), Color3.fromRGB(90, 60, 40), { Material = Enum.Material.Wood })
end

KINDS.mask = function(ctx, look)
	local base = look.color
	local red = look.accent
	ctx.add("Face", Vector3.new(1.8, 2.0, 0.5), CFrame.new(0, 1.2, 0), base)
	ctx.add("Snout", Vector3.new(0.9, 0.7, 0.6), CFrame.new(0, 0.85, -0.45), base)
	ctx.add("Nose", Vector3.new(0.3, 0.2, 0.1), CFrame.new(0, 1.0, -0.78), Color3.fromRGB(30, 30, 30))
	for _, side in { -1, 1 } do
		ctx.add("Ear", Vector3.new(0.6, 0.6, 0.4), CFrame.new(0.6 * side, 2.2, 0) * CFrame.Angles(0, 0, math.rad(45)), base)
		ctx.add("EarInner", Vector3.new(0.35, 0.35, 0.42), CFrame.new(0.6 * side, 2.2, -0.01) * CFrame.Angles(0, 0, math.rad(45)), red)
		ctx.add("Eye", Vector3.new(0.45, 0.15, 0.1), CFrame.new(0.45 * side, 1.45, -0.27) * CFrame.Angles(0, 0, 0.3 * side), Color3.fromRGB(30, 30, 30))
		ctx.add("Marking", Vector3.new(0.12, 0.5, 0.1), CFrame.new(0.65 * side, 1.15, -0.27), red)
	end
	ctx.add("Forehead", Vector3.new(0.25, 0.4, 0.1), CFrame.new(0, 1.8, -0.27), red)
	ctx.add("Scar", Vector3.new(0.1, 0.6, 0.1), CFrame.new(-0.3, 0.75, -0.27) * CFrame.Angles(0, 0, 0.4), red)
end

KINDS.lily = function(ctx, look)
	local petal = look.color
	ctx.add("Stem", Vector3.new(0.15, 2.0, 0.15), CFrame.new(0, 1.0, 0), look.accent)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local cf = CFrame.new(0, 2.1, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.new(0, 0.55, 0)
		ctx.add("Petal", Vector3.new(0.22, 1.2, 0.08), cf, petal, { Material = Enum.Material.Neon, Transparency = 0.1 })
		ctx.add(
			"Stamen",
			Vector3.new(0.05, 1.1, 0.05),
			CFrame.new(0, 2.1, 0) * CFrame.Angles(0, angle + 0.5, 0) * CFrame.Angles(math.rad(-30), 0, 0) * CFrame.new(0, 0.55, 0),
			lighten(petal, 0.6)
		)
	end
	ctx.add("Leaf", Vector3.new(0.8, 0.08, 0.3), CFrame.new(0.35, 0.7, 0) * CFrame.Angles(0, 0, 0.5), look.accent)
	ctx.add("Pot", Vector3.new(0.5, 1.0, 1.0), CFrame.new(0, 0.25, 0) * UP, Color3.fromRGB(60, 50, 70), { Shape = Enum.PartType.Cylinder })
end

function RelicBuilder.build(look, tier: number?, scale: number?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Relic"
	local ctx = newContext(model, s)

	local root = ctx.add("Root", Vector3.new(1, 1, 1), CFrame.new(0, 1.2, 0), Color3.new(1, 1, 1), { Transparency = 1 })
	model.PrimaryPart = root

	local builder = KINDS[look.kind] or KINDS.orb
	builder(ctx, look)

	-- Les reliques de haut palier brillent.
	local t = tier or 1
	if t >= 2 then
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Brightness = t == 3 and 3 or 1.5
		light.Range = 10 * s
		light.Parent = root
	end
	if t >= 3 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = look.accent
		sparkles.Parent = root
	end
	model:SetAttribute("Tier", t)
	return model
end

return RelicBuilder
