-- Bases des joueurs ("tycoon") : construction, attribution, améliorations (boutons à marcher dessus),
-- coffre de revenus, téléportation à l'apparition.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local CharacterBuilder = require(Shared.Modules.CharacterBuilder)
local Build = require(script.Parent.Parent.Modules.Build)

local PlotService = {}

local rgb = Color3.fromRGB
local Notify = Remotes.event("Notify")
local OpenMenu = Remotes.event("OpenMenu")
local CombatFX = Remotes.event("CombatFX")

local plots = {}
local playerPlots: { [Player]: any } = {}

local PLOT_GRASS = { rgb(126, 214, 88), rgb(116, 204, 80) }
local DIRT = rgb(160, 112, 72)
local DIRT_DARK = rgb(135, 92, 60)

PlotService.PedestalSlots = {
	Vector3.new(14, 0, 34),
	Vector3.new(22, 0, 34),
	Vector3.new(30, 0, 34),
	Vector3.new(38, 0, 34),
}
PlotService.SpawnOffset = Vector3.new(0, 3, -40)
PlotService.StashOffset = Vector3.new(14, 0, -40)

-- Emplacements d'exposition des persos (grille 6 x 3 dans l'arène de la base).
PlotService.DisplaySlots = {}
for row = 0, 2 do
	for col = 0, 5 do
		table.insert(PlotService.DisplaySlots, Vector3.new(-17.5 + col * 7, 0.35, -19 + row * 9))
	end
end

------------------------------------------------------------------------
-- Construction statique d'une base
------------------------------------------------------------------------

local function toWorld(plot, x: number, y: number, z: number): CFrame
	return plot.cf * CFrame.new(x, y, z)
end

local function buildPedestal(plot, parent: Instance, slot: number)
	local pos = PlotService.PedestalSlots[slot]
	local model = Build.model(parent, "Pedestal" .. slot)
	local base = toWorld(plot, pos.X, 0, pos.Z)
	Build.part(model, "Base", Vector3.new(5, 1.2, 5), base * CFrame.new(0, 0.6, 0), rgb(150, 145, 160), { Material = Enum.Material.Slate })
	Build.part(model, "Column", Vector3.new(3.4, 2, 3.4), base * CFrame.new(0, 2.2, 0), rgb(175, 170, 185), { Material = Enum.Material.Slate })
	local top = Build.part(model, "Top", Vector3.new(4.4, 0.6, 4.4), base * CFrame.new(0, 3.5, 0), rgb(120, 110, 140), { Material = Enum.Material.Slate })
	local ring = Build.deco(model, "Glow", Vector3.new(4.6, 0.15, 4.6), base * CFrame.new(0, 3.85, 0), rgb(120, 220, 255), { Material = Enum.Material.Neon, Transparency = 0.4 })
	ring.Name = "Glow"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Placer une relique"
	prompt.ObjectText = "Autel #" .. slot
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	local gui = Build.billboard(top, UDim2.fromOffset(200, 60), Vector3.new(0, 6.5, 0), 70)
	gui.Name = "Timer"
	local label = Build.label(gui, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), rgb(255, 255, 255))
	label.Name = "Text"
	model:SetAttribute("Slot", slot)
	model:SetAttribute("PlotIndex", plot.index)
	CollectionService:AddTag(model, "Pedestal")
	return model
end

local function buildRelicMachine(plot, parent: Instance)
	local model = Build.model(parent, "RelicMachine")
	local base = toWorld(plot, -16, 0, 36) -- face avant (-Z) vers l'arène
	local red = rgb(220, 50, 60)
	local gold = rgb(255, 200, 60)
	Build.part(model, "Base", Vector3.new(9, 3, 7), base * CFrame.new(0, 1.5, 0), red)
	Build.part(model, "Body", Vector3.new(8, 6, 6), base * CFrame.new(0, 6, 0), rgb(250, 245, 240))
	Build.part(model, "Trim", Vector3.new(8.4, 0.6, 6.4), base * CFrame.new(0, 3.2, 0), gold, { Material = Enum.Material.Metal })
	Build.part(model, "TopTrim", Vector3.new(8.4, 0.6, 6.4), base * CFrame.new(0, 9.2, 0), gold, { Material = Enum.Material.Metal })
	local dome =
		Build.ball(model, "Dome", 7.5, (base * CFrame.new(0, 11.5, 0)).Position, rgb(200, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = false })
	dome.Name = "Dome"
	Build.part(model, "Panel", Vector3.new(5, 3.4, 0.3), base * CFrame.new(0, 6.2, -3.1), rgb(40, 35, 60))
	Build.deco(model, "Slot", Vector3.new(1.6, 0.3, 0.2), base * CFrame.new(0, 4.2, -3.3), rgb(20, 20, 20))
	Build.deco(model, "Chute", Vector3.new(2.6, 1.4, 0.3), base * CFrame.new(0, 1.6, -3.55), rgb(30, 25, 35))
	-- Levier
	Build.part(model, "LeverBase", Vector3.new(1, 1, 1), base * CFrame.new(4.5, 6, 0), gold, { Material = Enum.Material.Metal })
	Build.deco(model, "Lever", Vector3.new(0.35, 3, 0.35), base * CFrame.new(5, 7.4, 0) * CFrame.Angles(0, 0, -0.3), rgb(80, 80, 90), { Material = Enum.Material.Metal })
	Build.ball(model, "LeverKnob", 1.2, (base * CFrame.new(5.45, 8.9, 0)).Position, red)
	-- Ampoules décoratives
	for i = -3, 3 do
		Build.deco(
			model,
			"Bulb",
			Vector3.new(0.5, 0.5, 0.5),
			base * CFrame.new(i * 1.1, 9.2, -3.25),
			i % 2 == 0 and rgb(255, 230, 90) or rgb(120, 220, 255),
			{ Material = Enum.Material.Neon }
		)
	end
	local sign = model:FindFirstChild("Panel") :: BasePart
	Build.surfaceText(sign, Enum.NormalId.Front, "RELIQUES", rgb(255, 220, 90))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Acheter des reliques"
	prompt.ObjectText = "Machine à Reliques"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:FindFirstChild("Base")
	plot.relicDisplayCF = base * CFrame.new(0, 10.6, 0)
	return model
end

local function buildAltar(plot, parent: Instance)
	local model = Build.model(parent, "EvolutionAltar")
	local base = toWorld(plot, 0, 0, 38)
	local stone = rgb(140, 135, 160)
	Build.part(model, "Step1", Vector3.new(14, 1, 10), base * CFrame.new(0, 0.5, 0), stone, { Material = Enum.Material.Slate })
	Build.part(model, "Step2", Vector3.new(10, 1, 7), base * CFrame.new(0, 1.5, 0.5), stone:Lerp(rgb(255, 255, 255), 0.1), { Material = Enum.Material.Slate })
	local altar = Build.part(model, "Altar", Vector3.new(5, 3, 4), base * CFrame.new(0, 3.5, 1), rgb(90, 80, 120), { Material = Enum.Material.Slate })
	for _, side in { -1, 1 } do
		Build.part(model, "Pillar", Vector3.new(1.6, 9, 1.6), base * CFrame.new(side * 5.5, 6, 2.5), stone, { Material = Enum.Material.Slate })
		Build.deco(model, "Flame", Vector3.new(1, 1.4, 1), base * CFrame.new(side * 5.5, 11.2, 2.5), rgb(160, 90, 255), { Material = Enum.Material.Neon })
	end
	local crystal = Build.deco(model, "Crystal", Vector3.new(2.2, 3.2, 2.2), base * CFrame.new(0, 8, 1), rgb(170, 110, 255), { Material = Enum.Material.Neon, Transparency = 0.15 })
	crystal:SetAttribute("SpinAxis", "Y")
	crystal:SetAttribute("SpinSpeed", 1)
	crystal:SetAttribute("Bob", 0.6)
	CollectionService:AddTag(crystal, "Spin")
	local light = Instance.new("PointLight")
	light.Color = rgb(170, 110, 255)
	light.Range = 18
	light.Brightness = 2
	light.Parent = crystal
	local sign = Build.part(model, "Sign", Vector3.new(9, 1.8, 0.3), base * CFrame.new(0, 3.4, -1.15), rgb(60, 50, 80))
	Build.surfaceText(sign, Enum.NormalId.Front, "AUTEL D'ÉVEIL", rgb(220, 190, 255))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Éveiller un perso"
	prompt.ObjectText = "Autel d'Éveil"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
	return model
end

local function buildStash(plot, parent: Instance)
	local model = Build.model(parent, "Stash")
	local base = toWorld(plot, PlotService.StashOffset.X, 0, PlotService.StashOffset.Z)
	local pad = Build.disc(model, "Pad", 0.5, 9, base.Position + Vector3.new(0, 0.05, 0), rgb(255, 200, 50), { Material = Enum.Material.Neon, Transparency = 0.25 })
	pad.CanTouch = true
	pad.Name = "Pad"
	local wood = rgb(140, 90, 50)
	local chestCF = base * CFrame.new(0, 0, 3.5) * CFrame.Angles(0, math.pi, 0)
	Build.part(model, "Chest", Vector3.new(5, 2.6, 3.4), chestCF * CFrame.new(0, 1.3, 0), wood, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "Lid", Vector3.new(5.2, 1.2, 3.6), chestCF * CFrame.new(0, 3.1, 0), wood:Lerp(rgb(0, 0, 0), 0.15), { Material = Enum.Material.WoodPlanks })
	Build.deco(model, "Gold", Vector3.new(4.4, 0.4, 2.8), chestCF * CFrame.new(0, 2.7, 0), rgb(255, 210, 60), { Material = Enum.Material.Neon })
	for _, x in { -1.8, 1.8 } do
		Build.deco(model, "Band", Vector3.new(0.4, 3.9, 3.7), chestCF * CFrame.new(x, 1.95, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	end
	local gui = Build.billboard(model:FindFirstChild("Lid") :: BasePart, UDim2.fromOffset(220, 70), Vector3.new(0, 4, 0), 90)
	gui.Name = "StashGui"
	local label = Build.label(gui, "💰 0", UDim2.fromScale(1, 0.65), UDim2.fromScale(0, 0), rgb(255, 225, 80))
	label.Name = "Amount"
	local hint = Build.label(gui, "Marche ici pour récupérer", UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), rgb(255, 255, 255), Enum.Font.GothamBold)
	hint.Name = "Hint"
	plot.stashPad = pad
	plot.stashLabel = label
	return model
end

local function buildPlot(index: number, parent: Instance)
	local plot = {
		index = index,
		cf = Layout.plotCFrame(index),
		owner = nil,
	}
	local model = Build.model(parent, "Plot" .. index)
	plot.model = model
	local static = Build.folder(model, "Static")

	-- Sol : damier d'herbe plus clair + bordure de pierre.
	local half = Layout.PlotSize / 2
	local tile = 25
	for x = 0, 3 do
		for z = 0, 3 do
			Build.part(static, "Grass", Vector3.new(tile, 1, tile), toWorld(plot, -half + tile / 2 + x * tile, -0.35, -half + tile / 2 + z * tile), PLOT_GRASS[((x + z) % 2) + 1])
		end
	end
	for _, side in { -1, 1 } do
		Build.part(static, "Border", Vector3.new(Layout.PlotSize + 2, 1, 1.5), toWorld(plot, 0, -0.3, side * (half + 0.5)), rgb(170, 160, 150), { Material = Enum.Material.Slate })
		Build.part(static, "Border", Vector3.new(1.5, 1, Layout.PlotSize + 2), toWorld(plot, side * (half + 0.5), -0.3, 0), rgb(170, 160, 150), { Material = Enum.Material.Slate })
	end

	-- Clôture avec ouverture à l'avant.
	local fence = Build.folder(static, "Fence")
	local y = 0.15
	local function w(x: number, z: number): Vector3
		return toWorld(plot, x, y, z).Position
	end
	Build.fenceLine(fence, w(-half, -half), w(-9, -half), 4)
	Build.fenceLine(fence, w(9, -half), w(half, -half), 4)
	Build.fenceLine(fence, w(half, -half), w(half, half), 4)
	Build.fenceLine(fence, w(half, half), w(-half, half), 4)
	Build.fenceLine(fence, w(-half, half), w(-half, -half), 4)

	-- Portail avec panneau du propriétaire.
	for _, side in { -1, 1 } do
		Build.part(static, "GatePost", Vector3.new(1.8, 13, 1.8), toWorld(plot, side * 9.5, 6.5, -half), rgb(110, 75, 50), { Material = Enum.Material.Wood })
		Build.deco(static, "GateTop", Vector3.new(2.4, 1, 2.4), toWorld(plot, side * 9.5, 13.4, -half), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	end
	local sign = Build.part(static, "OwnerSign", Vector3.new(20, 4, 0.8), toWorld(plot, 0, 11, -half), rgb(120, 80, 50), { Material = Enum.Material.Wood })
	local frontText = Build.surfaceText(sign, Enum.NormalId.Front, "BASE LIBRE", rgb(255, 255, 255))
	local backText = Build.surfaceText(sign, Enum.NormalId.Back, "BASE LIBRE", rgb(255, 255, 255))
	plot.signLabels = { frontText, backText }

	-- Arène d'exposition (terre battue entourée d'une petite clôture, comme l'image).
	Build.part(static, "Arena", Vector3.new(46, 0.5, 34), toWorld(plot, 0, 0.05, -8), DIRT)
	Build.part(static, "ArenaEdge", Vector3.new(48, 0.4, 36), toWorld(plot, 0, -0.05, -8), DIRT_DARK)
	local arenaFence = Build.folder(static, "ArenaFence")
	local function a(x: number, z: number): Vector3
		return toWorld(plot, x, 0.3, z).Position
	end
	Build.fenceLine(arenaFence, a(-24, -26), a(-5, -26), 2.6, 6)
	Build.fenceLine(arenaFence, a(5, -26), a(24, -26), 2.6, 6)
	Build.fenceLine(arenaFence, a(24, -26), a(24, 10), 2.6, 6)
	Build.fenceLine(arenaFence, a(24, 10), a(-24, 10), 2.6, 6)
	Build.fenceLine(arenaFence, a(-24, 10), a(-24, -26), 2.6, 6)
	local rng = Random.new(index * 99)
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-21, 21), rng:NextNumber(-24, 7)
		Build.deco(
			static,
			"Pebble",
			Vector3.new(rng:NextNumber(0.6, 1.4), 0.4, rng:NextNumber(0.6, 1.2)),
			toWorld(plot, x, 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			rgb(150, 145, 140)
		)
	end

	-- Éléments interactifs.
	local interactive = Build.folder(model, "Interactive")
	buildRelicMachine(plot, interactive)
	buildAltar(plot, interactive)
	buildStash(plot, interactive)
	plot.pedestalFolder = Build.folder(interactive, "Pedestals")
	plot.pedestals = {}
	plot.pedestals[1] = buildPedestal(plot, plot.pedestalFolder, 1)

	-- Contenu propre au propriétaire (améliorations, persos).
	plot.ownerFolder = Build.folder(model, "Owner")
	plot.displayFolder = Build.folder(model, "Display")

	-- Arbres décoratifs dans les coins.
	for _, corner in { { -44, 44 }, { 44, 44 }, { -44, -44 }, { 44, -44 } } do
		Build.tree(static, toWorld(plot, corner[1], 0, corner[2]).Position, 1.2, nil, nil, rng)
	end

	model:SetAttribute("PlotIndex", index)
	return plot
end

------------------------------------------------------------------------
-- Structures d'amélioration
------------------------------------------------------------------------

local STRUCTURES = {}

STRUCTURES.lanternes = function(plot, folder)
	for _, p in { { -14, -46 }, { 14, -46 }, { -28, -46 }, { 28, -46 }, { -27, 12 }, { 27, 12 } } do
		Build.lantern(folder, toWorld(plot, p[1], 0, p[2]).Position, rgb(255, 120, 70))
	end
end

STRUCTURES.tatami = function(plot, folder)
	local base = toWorld(plot, -36, 0, 20)
	Build.part(folder, "TatamiFrame", Vector3.new(17, 0.6, 11), base * CFrame.new(0, 0.3, 0), rgb(110, 75, 50), { Material = Enum.Material.Wood })
	for i = 0, 3 do
		Build.part(folder, "Tatami", Vector3.new(3.8, 0.3, 10), base * CFrame.new(-6 + i * 4, 0.7, 0), rgb(170, 190, 110), { Material = Enum.Material.Fabric })
	end
	local dummy = base * CFrame.new(0, 0, 3)
	Build.part(folder, "DummyPost", Vector3.new(0.8, 5, 0.8), dummy * CFrame.new(0, 3, 0), rgb(120, 85, 55), { Material = Enum.Material.Wood })
	Build.part(folder, "DummyBody", Vector3.new(2.4, 2.6, 1.4), dummy * CFrame.new(0, 4.3, 0), rgb(200, 170, 120), { Material = Enum.Material.Fabric })
	Build.part(folder, "DummyArms", Vector3.new(4.4, 0.6, 0.6), dummy * CFrame.new(0, 4.8, 0), rgb(120, 85, 55), { Material = Enum.Material.Wood })
	Build.part(folder, "DummyHead", Vector3.new(1.6, 1.6, 1.6), dummy * CFrame.new(0, 6.4, 0), rgb(200, 170, 120), { Material = Enum.Material.Fabric })
end

STRUCTURES.fontaine = function(plot, folder)
	local base = toWorld(plot, -26, 0, -38).Position
	Build.disc(folder, "Basin", 1.6, 11, base, rgb(170, 170, 180), { Material = Enum.Material.Slate })
	Build.disc(folder, "Water", 0.3, 9.6, base + Vector3.new(0, 1.35, 0), rgb(70, 170, 255), { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	Build.disc(folder, "Column", 4, 1.6, base + Vector3.new(0, 1.6, 0), rgb(170, 170, 180), { Material = Enum.Material.Slate })
	local orb = Build.ball(folder, "ChakraOrb", 2.4, base + Vector3.new(0, 6.6, 0), rgb(90, 190, 255), { Material = Enum.Material.Neon, CanCollide = false })
	orb:SetAttribute("Bob", 0.8)
	CollectionService:AddTag(orb, "Spin")
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(rgb(140, 220, 255))
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.5, 0)
	particles.Rate = 18
	particles.Speed = NumberRange.new(3, 6)
	particles.Lifetime = NumberRange.new(1, 1.6)
	particles.SpreadAngle = Vector2.new(25, 25)
	particles.Acceleration = Vector3.new(0, -12, 0)
	particles.Parent = orb
end

STRUCTURES.dojo = function(plot, folder)
	local cf = toWorld(plot, -36, 0, 38)
	Build.house(folder, cf, Vector3.new(18, 10, 13), rgb(235, 225, 205), rgb(60, 50, 60), rgb(150, 40, 40))
	local sign = Build.part(folder, "DojoSign", Vector3.new(7, 2, 0.4), cf * CFrame.new(0, 8.5, -6.8), rgb(30, 25, 25))
	Build.surfaceText(sign, Enum.NormalId.Front, "DOJO", rgb(255, 200, 80))
end

STRUCTURES.statue = function(plot, folder, ctx)
	local base = toWorld(plot, -36, 0, -36) * CFrame.Angles(0, math.pi, 0)
	Build.part(folder, "StatueBase", Vector3.new(7, 3, 7), base * CFrame.new(0, 1.5, 0), rgb(200, 195, 190), { Material = Enum.Material.Marble })
	local look = ctx and ctx.bestLook
	if look then
		local statue = CharacterBuilder.build(look, { scale = 1.6, name = "GoldenStatue" })
		for _, part in statue:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.Color = rgb(255, 200, 60):Lerp(part.Color, 0.15)
				part.Material = Enum.Material.Metal
				part.Reflectance = 0.15
				part.CanCollide = false
			end
		end
		statue:PivotTo(base * CFrame.new(0, 3, 0) * CFrame.new(0, CharacterBuilder.HipHeight * 1.6 + 0.85 * 1.6, 0) * CFrame.Angles(0, math.pi, 0))
		statue.Parent = folder
	end
end

STRUCTURES.aimant = function(plot, folder)
	local base = toWorld(plot, -22, 0, 22)
	Build.part(folder, "MagnetBase", Vector3.new(4, 1, 4), base * CFrame.new(0, 0.5, 0), rgb(90, 90, 100), { Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		Build.part(folder, "MagnetArm", Vector3.new(1.6, 6, 1.6), base * CFrame.new(side * 1.8, 4, 0), rgb(220, 40, 40))
		Build.part(folder, "MagnetTip", Vector3.new(1.7, 1.2, 1.7), base * CFrame.new(side * 1.8, 7.6, 0), rgb(220, 220, 230), { Material = Enum.Material.Metal })
	end
	Build.part(folder, "MagnetBridge", Vector3.new(5.2, 1.6, 1.6), base * CFrame.new(0, 1.8, 0), rgb(220, 40, 40))
	local coin =
		Build.deco(folder, "Coin", Vector3.new(0.4, 2.6, 2.6), base * CFrame.new(0, 9.5, 0), rgb(255, 210, 60), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon })
	coin:SetAttribute("SpinAxis", "Y")
	coin:SetAttribute("SpinSpeed", 2)
	CollectionService:AddTag(coin, "Spin")
end

STRUCTURES.horloge = function(plot, folder)
	local base = toWorld(plot, 44, 0, 21) * CFrame.Angles(0, math.rad(90), 0)
	Build.part(folder, "Tower", Vector3.new(5, 14, 5), base * CFrame.new(0, 7, 0), rgb(200, 180, 150), { Material = Enum.Material.Brick })
	Build.part(folder, "TowerRoof", Vector3.new(6.4, 1, 6.4), base * CFrame.new(0, 14.5, 0), rgb(60, 70, 120))
	Build.part(folder, "TowerTop", Vector3.new(4, 2, 4), base * CFrame.new(0, 16, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(60, 70, 120))
	local face = Build.deco(
		folder,
		"ClockFace",
		Vector3.new(0.3, 4, 4),
		base * CFrame.new(0, 11, -2.6) * CFrame.Angles(0, math.rad(90), 0),
		rgb(250, 245, 230),
		{ Shape = Enum.PartType.Cylinder }
	)
	local hand = Build.deco(folder, "Hand", Vector3.new(0.2, 1.6, 0.25), base * CFrame.new(0, 11.6, -2.8), rgb(30, 30, 30))
	hand:SetAttribute("SpinAxis", "Z")
	hand:SetAttribute("SpinSpeed", 1.2)
	CollectionService:AddTag(hand, "Spin")
	local _ = face
end

STRUCTURES.coffre = function(plot, folder)
	local base = toWorld(plot, 28, 0, -40)
	Build.part(folder, "ShogunChest", Vector3.new(6, 3.6, 4), base * CFrame.new(0, 1.8, 0), rgb(150, 30, 40))
	Build.part(folder, "ShogunLid", Vector3.new(6.2, 1.2, 4.2), base * CFrame.new(0, 4.2, 0), rgb(30, 25, 25))
	Build.deco(
		folder,
		"ShogunEmblem",
		Vector3.new(1.4, 1.4, 0.2),
		base * CFrame.new(0, 2.2, -2.05) * CFrame.Angles(0, 0, math.rad(45)),
		rgb(255, 200, 60),
		{ Material = Enum.Material.Metal }
	)
end

STRUCTURES.sablier = function(plot, folder)
	local base = toWorld(plot, 8, 0, 22)
	Build.part(folder, "HourBase", Vector3.new(4, 0.6, 4), base * CFrame.new(0, 0.3, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	Build.part(folder, "HourTop", Vector3.new(4, 0.6, 4), base * CFrame.new(0, 8.3, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	for _, x in { -1.6, 1.6 } do
		Build.part(folder, "HourRod", Vector3.new(0.4, 7.6, 0.4), base * CFrame.new(x, 4.3, -1.6), rgb(255, 200, 60), { Material = Enum.Material.Metal })
		Build.part(folder, "HourRod", Vector3.new(0.4, 7.6, 0.4), base * CFrame.new(x, 4.3, 1.6), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	end
	Build.deco(folder, "GlassTop", Vector3.new(2.6, 3, 2.6), base * CFrame.new(0, 6.2, 0), rgb(200, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.5 })
	Build.deco(folder, "GlassBottom", Vector3.new(2.6, 3, 2.6), base * CFrame.new(0, 2.4, 0), rgb(200, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.5 })
	Build.deco(folder, "Sand", Vector3.new(2, 1.4, 2), base * CFrame.new(0, 1.6, 0), rgb(255, 220, 120), { Material = Enum.Material.Neon })
	Build.deco(folder, "SandStream", Vector3.new(0.25, 3, 0.25), base * CFrame.new(0, 4, 0), rgb(255, 220, 120), { Material = Enum.Material.Neon })
end

STRUCTURES.arene1 = function(plot, folder)
	for _, p in { { -24, -26 }, { 24, -26 }, { -24, 10 }, { 24, 10 } } do
		local base = toWorld(plot, p[1], 0, p[2])
		Build.part(folder, "TorchPost", Vector3.new(1, 6, 1), base * CFrame.new(0, 3, 0), rgb(90, 60, 40), { Material = Enum.Material.Wood })
		local flame = Build.deco(folder, "TorchFlame", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 6.6, 0), rgb(255, 150, 40), { Material = Enum.Material.Neon })
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = flame
	end
end

STRUCTURES.arene2 = function(plot, folder)
	for step = 0, 2 do
		Build.part(
			folder,
			"Bleacher",
			Vector3.new(40, 1 + step, 1.6),
			toWorld(plot, 0, (1 + step) / 2, 11.5 + step * 1.6),
			rgb(150, 110, 75):Lerp(rgb(255, 255, 255), step * 0.06),
			{ Material = Enum.Material.WoodPlanks }
		)
	end
	for i = -2, 2 do
		Build.deco(
			folder,
			"Pennant",
			Vector3.new(2, 3, 0.2),
			toWorld(plot, i * 8, 6.5, 14.5),
			i % 2 == 0 and rgb(230, 50, 60) or rgb(255, 200, 60),
			{ Material = Enum.Material.Fabric }
		)
		Build.part(folder, "PennantPole", Vector3.new(0.3, 7, 0.3), toWorld(plot, i * 8 - 1, 3.5, 14.6), rgb(90, 60, 40), { Material = Enum.Material.Wood })
	end
end

local function banner(plot, folder, x: number, color: Color3)
	local base = toWorld(plot, x, 0, -29)
	Build.part(folder, "BannerPole", Vector3.new(0.6, 12, 0.6), base * CFrame.new(0, 6, 0), rgb(90, 60, 40), { Material = Enum.Material.Wood })
	Build.deco(folder, "Banner", Vector3.new(3, 6, 0.2), base * CFrame.new(1.8, 8.5, 0), color, { Material = Enum.Material.Fabric })
	Build.deco(
		folder,
		"BannerStar",
		Vector3.new(1.2, 1.2, 0.25),
		base * CFrame.new(1.8, 9, 0) * CFrame.Angles(0, 0, math.rad(45)),
		rgb(255, 230, 120),
		{ Material = Enum.Material.Neon }
	)
end

STRUCTURES.equipe4 = function(plot, folder)
	banner(plot, folder, -28, rgb(60, 120, 230))
end

STRUCTURES.equipe5 = function(plot, folder)
	banner(plot, folder, 25, rgb(230, 60, 90))
end

------------------------------------------------------------------------
-- Gestion du propriétaire
------------------------------------------------------------------------

function PlotService:Init(services)
	self.services = services
	local world = Workspace:WaitForChild("World")
	local folder = world:FindFirstChild("Plots") or Build.folder(world, "Plots")
	for i = 1, Layout.PlotCount do
		local plot = buildPlot(i, folder)
		plots[i] = plot
		self:_connectPrompts(plot)
	end
end

function PlotService:_connectPrompts(plot)
	local interactive = plot.model.Interactive
	local machinePrompt = interactive.RelicMachine.Base:FindFirstChild("Prompt") :: ProximityPrompt
	machinePrompt.Triggered:Connect(function(player)
		if plot.owner == player then
			OpenMenu:FireClient(player, "Shop")
		else
			Notify:FireClient(player, "Ce n'est pas ta base !", "error")
		end
	end)
	local altarPrompt = interactive.EvolutionAltar.Altar:FindFirstChild("Prompt") :: ProximityPrompt
	altarPrompt.Triggered:Connect(function(player)
		if plot.owner == player then
			OpenMenu:FireClient(player, "Evolution")
		else
			Notify:FireClient(player, "Ce n'est pas ta base !", "error")
		end
	end)
	local debounce = {}
	plot.stashPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= plot.owner then
			return
		end
		if debounce[player] and os.clock() - debounce[player] < 1 then
			return
		end
		debounce[player] = os.clock()
		self:CollectStash(player)
	end)
end

function PlotService:Start()
	local DataService = self.services.DataService
	DataService:OnPlayerLoaded(function(player, data)
		self:_assign(player, data)
	end)
	DataService:OnPlayerRemoving(function(player)
		self:_release(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	-- Téléportations rapides (boutons du HUD).
	local lastTeleport = {}
	Remotes.event("Teleport").OnServerEvent:Connect(function(player, destination)
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then
			return
		end
		if lastTeleport[player] and os.clock() - lastTeleport[player] < 3 then
			return
		end
		lastTeleport[player] = os.clock()
		local target: CFrame? = nil
		if destination == "base" then
			local plot = playerPlots[player]
			target = plot and self:GetSpawnCFrame(plot)
		elseif destination == "zone" then
			local plot = playerPlots[player]
			local angle = plot and Layout.PlotAngles[plot.index] or 0
			local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Layout.ZoneFenceRadius + 8)
			target = CFrame.lookAt(pos + Vector3.new(0, 3, 0), Vector3.new(0, 3, 0))
		elseif destination == "trade" then
			target = CFrame.lookAt(Layout.TradeCorner + Vector3.new(-30, 3, 0), Layout.TradeCorner + Vector3.new(0, 3, 0))
		elseif destination == "fusion" then
			target = CFrame.lookAt(Layout.FusionPortal + Vector3.new(30, 3, 0), Layout.FusionPortal + Vector3.new(0, 3, 0))
		end
		if target then
			character:PivotTo(target)
			if self.services.TeamService then
				task.delay(0.2, function()
					self.services.TeamService:TeleportTeam(player)
				end)
			end
		end
	end)

	-- Mise à jour de l'affichage du coffre.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in plots do
				if plot.owner then
					local data = DataService:Get(plot.owner)
					if data then
						plot.stashLabel.Text = "💰 " .. Formulas.formatNumber(data.stash)
					end
				else
					plot.stashLabel.Text = ""
				end
			end
		end
	end)
end

function PlotService:_assign(player: Player, data)
	if playerPlots[player] then
		return
	end
	local chosen = nil
	for _, plot in plots do
		if plot.owner == nil then
			chosen = plot
			break
		end
	end
	if not chosen then
		Notify:FireClient(player, "Aucune base libre sur ce serveur.", "error")
		return
	end
	chosen.owner = player
	playerPlots[player] = chosen
	chosen.model:SetAttribute("OwnerId", player.UserId)
	player:SetAttribute("PlotIndex", chosen.index)
	for _, label in chosen.signLabels do
		label.Text = "BASE DE " .. string.upper(player.DisplayName)
	end
	self:RefreshOwnerContent(player)

	local function onCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and playerPlots[player] == chosen then
			task.wait(0.1)
			character:PivotTo(self:GetSpawnCFrame(chosen))
		end
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	chosen.charConn = player.CharacterAdded:Connect(onCharacter)
	local _ = data
end

function PlotService:_release(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	playerPlots[player] = nil
	plot.owner = nil
	plot.model:SetAttribute("OwnerId", nil)
	if plot.charConn then
		plot.charConn:Disconnect()
		plot.charConn = nil
	end
	for _, label in plot.signLabels do
		label.Text = "BASE LIBRE"
	end
	plot.ownerFolder:ClearAllChildren()
	plot.displayFolder:ClearAllChildren()
	for slot = 2, #PlotService.PedestalSlots do
		if plot.pedestals[slot] then
			plot.pedestals[slot]:Destroy()
			plot.pedestals[slot] = nil
		end
	end
	local pedestal = plot.pedestals[1]
	if pedestal then
		pedestal:SetAttribute("RelicId", nil)
		pedestal:SetAttribute("ReadyAt", nil)
		local relic = pedestal:FindFirstChild("RelicModel")
		if relic then
			relic:Destroy()
		end
	end
end

function PlotService:GetPlot(player: Player)
	return playerPlots[player]
end

function PlotService:GetPlots()
	return plots
end

function PlotService:GetSpawnCFrame(plot): CFrame
	local pos = (plot.cf * CFrame.new(PlotService.SpawnOffset)).Position
	local target = (plot.cf * CFrame.new(0, 3, 0)).Position
	return CFrame.lookAt(pos, target)
end

function PlotService:GetDisplayCFrame(plot, slot: number): CFrame
	local offset = PlotService.DisplaySlots[slot] or PlotService.DisplaySlots[1]
	-- Les persos regardent vers l'entrée de la base (-Z local).
	return plot.cf * CFrame.new(offset)
end

function PlotService:ToWorld(plot, x: number, y: number, z: number): CFrame
	return toWorld(plot, x, y, z)
end

-- Reconstruit améliorations, boutons et autels supplémentaires.
function PlotService:RefreshOwnerContent(player: Player)
	local plot = playerPlots[player]
	local data = self.services.DataService:Get(player)
	if not plot or not data then
		return
	end
	plot.ownerFolder:ClearAllChildren()
	local structures = Build.folder(plot.ownerFolder, "Structures")
	local pads = Build.folder(plot.ownerFolder, "Pads")

	local ctx = { bestLook = self.services.CharacterService and self.services.CharacterService:GetBestLook(player) }
	for _, upgrade in Economy.Upgrades do
		if data.upgrades[upgrade.id] then
			local builder = STRUCTURES[upgrade.id]
			if builder then
				local ok, err = pcall(builder, plot, structures, ctx)
				if not ok then
					warn("[AnimeTycoon] Structure " .. upgrade.id .. " : " .. tostring(err))
				end
			end
		elseif upgrade.requires == nil or data.upgrades[upgrade.requires] then
			self:_buildPad(player, plot, pads, upgrade)
		end
	end

	-- Autels (incubateurs) selon les améliorations.
	local stats = Formulas.upgradeStats(data.upgrades)
	for slot = 2, #PlotService.PedestalSlots do
		if slot <= stats.incubators and not plot.pedestals[slot] then
			plot.pedestals[slot] = buildPedestal(plot, plot.pedestalFolder, slot)
			if self.services.HatchService then
				self.services.HatchService:ConnectPedestal(plot, plot.pedestals[slot])
			end
		end
	end
	if self.services.HatchService then
		self.services.HatchService:RefreshPedestals(player)
	end
end

function PlotService:_buildPad(player: Player, plot, parent: Instance, upgrade)
	local base = toWorld(plot, upgrade.slot[1], 0, upgrade.slot[2])
	local model = Build.model(parent, "Pad_" .. upgrade.id)
	local pad = Build.disc(model, "Pad", 0.5, 5.5, base.Position + Vector3.new(0, 0.05, 0), rgb(80, 230, 120), { Material = Enum.Material.Neon, Transparency = 0.15 })
	pad.CanTouch = true
	Build.disc(model, "PadRing", 0.3, 6.6, base.Position, rgb(40, 40, 50))
	local gui = Build.billboard(pad, UDim2.fromOffset(190, 70), Vector3.new(0, 3.2, 0), 60)
	local title = Build.label(gui, upgrade.name, UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0), rgb(255, 255, 255))
	title.Name = "Title"
	local price = Build.label(gui, "💰 " .. Formulas.formatNumber(upgrade.price), UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.5), rgb(255, 220, 80))
	price.Name = "Price"
	model:SetAttribute("UpgradeId", upgrade.id)
	model:SetAttribute("Price", upgrade.price)
	CollectionService:AddTag(model, "UpgradePad")
	local busy = false
	pad.Touched:Connect(function(hit)
		if busy then
			return
		end
		local toucher = Players:GetPlayerFromCharacter(hit.Parent)
		if toucher ~= player then
			return
		end
		busy = true
		self:BuyUpgrade(player, upgrade.id)
		task.delay(1, function()
			busy = false
		end)
	end)
end

function PlotService:BuyUpgrade(player: Player, upgradeId: string): boolean
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local upgrade = Economy.UpgradesById[upgradeId]
	if not data or not upgrade or data.upgrades[upgradeId] then
		return false
	end
	if upgrade.requires and not data.upgrades[upgrade.requires] then
		return false
	end
	if data.coins < upgrade.price then
		Notify:FireClient(player, "Il te manque 💰 " .. Formulas.formatNumber(upgrade.price - data.coins) .. " pour " .. upgrade.name, "error")
		return false
	end
	DataService:SpendCoins(player, upgrade.price)
	data.upgrades[upgradeId] = true
	DataService:Sync(player)
	self:RefreshOwnerContent(player)
	if self.services.CharacterService then
		self.services.CharacterService:Refresh(player)
	end
	if self.services.TeamService then
		self.services.TeamService:RefreshTeam(player)
	end
	Notify:FireClient(player, "✨ " .. upgrade.name .. " construit !", "success")
	local plot = playerPlots[player]
	if plot then
		CombatFX:FireClient(player, "Build", { position = toWorld(plot, upgrade.slot[1], 2, upgrade.slot[2]).Position })
	end
	return true
end

function PlotService:CollectStash(player: Player)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or data.stash < 1 then
		return
	end
	local amount = math.floor(data.stash)
	data.stash -= amount
	DataService:AddCoins(player, amount)
	local plot = playerPlots[player]
	Remotes.event("Reward"):FireClient(player, "coins", amount, plot and plot.stashPad.Position or nil)
end

return PlotService
