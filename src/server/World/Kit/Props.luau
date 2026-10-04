-- Kit/Props : les accessoires qui font vivre la carte (taille réelle).
--   tonneaux, caisses, sacs, bois de chauffage, charrettes, bancs, étals de marché, bannières
--   (nobori), kiosques, puits, lanternes de pierre (tōrō), lanternes de papier, lampadaires,
--   poteaux d'entraînement, râteliers d'armes, panneaux indicateurs, distributeurs, pots de plantes.
-- Convention : `cf` au sol, -Z local = l'avant de l'objet.

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)

local Props = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade

local WOOD = rgb(140, 98, 64)
local WOOD_DARK = rgb(84, 60, 44)
local METAL = rgb(96, 98, 104)
local STONE = rgb(164, 158, 148)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return Build.part(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic, CanCollide = collide ~= false })
end

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return Build.deco(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic })
end

-- Tonneau cerclé (couché si `lying`).
function Props.barrel(parent: Instance, cf: CFrame, scale: number?, color: Color3?, lying: boolean?)
	local s = scale or 1
	local c = color or rgb(150, 100, 62)
	local base = lying and (cf * CFrame.new(0, 1.3 * s, -1.5 * s) * CFrame.Angles(math.rad(90), 0, 0)) or cf
	Core.vcyl(parent, "Barrel", base, 3 * s, 2.4 * s, c, Enum.Material.WoodPlanks)
	Core.vcyl(parent, "BarrelBelly", base * CFrame.new(0, 0.8 * s, 0), 1.4 * s, 2.6 * s, shade(c, 0.04), Enum.Material.WoodPlanks, false)
	for _, y in { 0.35, 2.55 } do
		Core.vcyl(parent, "BarrelBand", base * CFrame.new(0, y * s, 0), 0.22 * s, 2.5 * s, METAL, Enum.Material.Metal, false)
	end
	Core.vcyl(parent, "BarrelLid", base * CFrame.new(0, 2.95 * s, 0), 0.1 * s, 2.1 * s, shade(c, -0.15), Enum.Material.Wood, false)
end

-- Caisse en bois (planches et cadre).
function Props.crate(parent: Instance, cf: CFrame, size: number?, color: Color3?)
	local s = size or 2.6
	local c = color or rgb(176, 130, 82)
	part(parent, "Crate", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), c, Enum.Material.WoodPlanks)
	for _, y in { 0.12, s - 0.12 } do
		deco(parent, "CrateEdge", Vector3.new(s + 0.12, 0.3, s + 0.12), cf * CFrame.new(0, y, 0), shade(c, -0.22), Enum.Material.Wood)
	end
	deco(parent, "CrateCross", Vector3.new(0.3, s * 1.3, 0.1), cf * CFrame.new(0, s / 2, -s / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(45)), shade(c, -0.18), Enum.Material.Wood)
end

-- Pile de caisses et de tonneaux.
function Props.cargo(parent: Instance, cf: CFrame, rng: Random)
	Props.crate(parent, cf * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), 2.8)
	Props.crate(parent, cf * CFrame.new(3, 0, 0.4) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), 2.4)
	Props.crate(parent, cf * CFrame.new(1.2, 2.8, 0.2) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 2.2)
	Props.barrel(parent, cf * CFrame.new(-2.8, 0, 0.6), 0.9)
	if rng:NextNumber() < 0.5 then
		Props.sack(parent, cf * CFrame.new(4.4, 0, -2), rng)
	end
end

-- Sac de toile ventru (riz, farine).
function Props.sack(parent: Instance, cf: CFrame, rng: Random)
	local c = rgb(206, 186, 146)
	Core.ellipsoid(parent, "Sack", Vector3.new(2, 2.4, 1.6), cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), c, Enum.Material.Fabric)
	deco(parent, "SackTie", Vector3.new(0.6, 0.4, 0.6), cf * CFrame.new(0, 2.3, 0), shade(c, -0.2), Enum.Material.Fabric)
end

-- Tas de bûches.
function Props.firewood(parent: Instance, cf: CFrame, rng: Random)
	for row = 0, 2 do
		for i = 0, 3 - row do
			local p = cf * CFrame.new(-1.6 + i * 1.05 + row * 0.5, 0.5 + row * 0.9, 0)
			local log = part(parent, "Log", Vector3.new(3, 1, 1), p * CFrame.Angles(0, math.rad(90) + rng:NextNumber(-0.1, 0.1), 0), shade(rgb(130, 92, 60), rng:NextNumber(-0.1, 0.1)), Enum.Material.Wood)
			log.Shape = Enum.PartType.Cylinder
		end
	end
end

-- Charrette en bois à deux roues.
function Props.cart(parent: Instance, cf: CFrame, cargoColor: Color3?)
	local bed = cf * CFrame.new(0, 2.6, 0)
	part(parent, "CartBed", Vector3.new(4.6, 0.5, 7), bed, WOOD, Enum.Material.WoodPlanks)
	for _, x in { -1, 1 } do
		deco(parent, "CartSide", Vector3.new(0.3, 1.4, 7), bed * CFrame.new(x * 2.15, 0.9, 0), shade(WOOD, -0.08), Enum.Material.WoodPlanks)
		local wheel = part(parent, "Wheel", Vector3.new(0.5, 4.4, 4.4), cf * CFrame.new(x * 2.7, 2.2, 0.8), WOOD_DARK, Enum.Material.Wood)
		wheel.Shape = Enum.PartType.Cylinder
		local hub = deco(parent, "WheelHub", Vector3.new(0.7, 1.2, 1.2), cf * CFrame.new(x * 2.75, 2.2, 0.8), METAL, Enum.Material.Metal)
		hub.Shape = Enum.PartType.Cylinder
		deco(parent, "Spoke", Vector3.new(0.2, 3.8, 0.35), cf * CFrame.new(x * 2.95, 2.2, 0.8), WOOD_DARK, Enum.Material.Wood)
		deco(parent, "Spoke", Vector3.new(0.2, 0.35, 3.8), cf * CFrame.new(x * 2.95, 2.2, 0.8), WOOD_DARK, Enum.Material.Wood)
		Core.beam(parent, "CartHandle", (bed * CFrame.new(x * 1.6, 0, -3.4)).Position, (cf * CFrame.new(x * 1.4, 1.2, -7.4)).Position, 0.35, 0.35, WOOD_DARK, {
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
	deco(parent, "CartFront", Vector3.new(4.6, 1.4, 0.3), bed * CFrame.new(0, 0.9, -3.4), shade(WOOD, -0.08), Enum.Material.WoodPlanks)
	if cargoColor then
		for i = 1, 3 do
			Core.ellipsoid(parent, "CartLoad", Vector3.new(1.8, 1.5, 2), bed * CFrame.new((i - 2) * 1.2, 1, (i % 2) * 1.6 - 0.6), cargoColor, Enum.Material.Fabric)
		end
	end
end

-- Banc en bois (lattes, pieds, dossier).
function Props.bench(parent: Instance, cf: CFrame, color: Color3?)
	local c = color or WOOD
	for k = 0, 2 do
		part(parent, "BenchSlat", Vector3.new(6, 0.3, 0.6), cf * CFrame.new(0, 1.8, -0.7 + k * 0.7), c, Enum.Material.WoodPlanks)
	end
	for _, x in { -2.5, 2.5 } do
		part(parent, "BenchLeg", Vector3.new(0.45, 1.8, 2), cf * CFrame.new(x, 0.9, 0), WOOD_DARK, Enum.Material.Wood)
		deco(parent, "BenchBackPost", Vector3.new(0.35, 2, 0.35), cf * CFrame.new(x, 2.8, 0.85), WOOD_DARK, Enum.Material.Wood)
	end
	deco(parent, "BenchBack", Vector3.new(6, 0.9, 0.25), cf * CFrame.new(0, 3.2, 0.9), c, Enum.Material.WoodPlanks)
end

-- Étal de marché : table, tréteaux, auvent rayé, marchandises (fruits, poissons, bols...).
function Props.stall(parent: Instance, cf: CFrame, color: Color3, goods: string?, rng: Random)
	local w, d = 8, 4.4
	part(parent, "StallTable", Vector3.new(w, 0.5, d), cf * CFrame.new(0, 3, 0), WOOD, Enum.Material.WoodPlanks)
	deco(parent, "StallSkirt", Vector3.new(w, 2.6, 0.2), cf * CFrame.new(0, 1.6, -d / 2), color, Enum.Material.Fabric)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(parent, "StallPost", Vector3.new(0.4, 8, 0.4), cf * CFrame.new(x * (w / 2 - 0.2), 4, z * (d / 2 - 0.2)), WOOD_DARK, Enum.Material.Wood)
		end
	end
	local stripes = 6
	for i = 0, stripes - 1 do
		local c = i % 2 == 0 and color or rgb(250, 244, 230)
		deco(parent, "StallAwning", Vector3.new(w / stripes, 0.25, d + 2), cf * CFrame.new(-w / 2 + (i + 0.5) * w / stripes, 8.2, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), c, Enum.Material.Fabric)
		deco(parent, "StallFlap", Vector3.new(w / stripes, 0.9, 0.12), cf * CFrame.new(-w / 2 + (i + 0.5) * w / stripes, 7.45, -d / 2 - 1.55), c, Enum.Material.Fabric)
	end
	local top = cf * CFrame.new(0, 3.3, 0)
	local kind = goods or "fruits"
	if kind == "fruits" then
		local colors = { rgb(220, 60, 50), rgb(250, 170, 40), rgb(140, 200, 70), rgb(250, 220, 80) }
		for i = 0, 3 do
			deco(parent, "Basket", Vector3.new(1.6, 0.7, 1.6), top * CFrame.new(-2.7 + i * 1.8, 0.35, 0), rgb(170, 130, 80), Enum.Material.Fabric)
			for k = 1, 3 do
				Core.ball(parent, "Fruit", 0.7, (top * CFrame.new(-2.7 + i * 1.8 + (k - 2) * 0.4, 0.85, (k % 2) * 0.3)).Position, colors[i + 1])
			end
		end
	elseif kind == "fish" then
		for i = 0, 4 do
			Core.ellipsoid(parent, "Fish", Vector3.new(0.6, 0.5, 2), top * CFrame.new(-3 + i * 1.5, 0.3, 0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), rgb(150, 170, 190), Enum.Material.Metal)
		end
		deco(parent, "Ice", Vector3.new(w - 0.6, 0.2, d - 0.6), top * CFrame.new(0, 0.05, 0), rgb(220, 240, 250), Enum.Material.Ice)
	elseif kind == "bowls" then
		for i = 0, 4 do
			Core.ball(parent, "Bowl", 1.1, (top * CFrame.new(-3 + i * 1.5, 0.35, 0)).Position, rgb(246, 240, 228))
			deco(parent, "Chopsticks", Vector3.new(0.1, 0.1, 1.4), top * CFrame.new(-3 + i * 1.5, 0.9, 0.2) * CFrame.Angles(0, 0.4, 0), rgb(160, 110, 70), Enum.Material.Wood)
		end
	elseif kind == "masks" then
		local colors = { rgb(240, 240, 240), rgb(220, 60, 60), rgb(250, 200, 80), rgb(70, 120, 220) }
		for i = 0, 3 do
			local mask = Core.ellipsoid(parent, "Mask", Vector3.new(1.4, 1.8, 0.4), cf * CFrame.new(-2.7 + i * 1.8, 6.2, -d / 2 + 0.1), colors[i + 1])
			mask.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- Bannière verticale (nobori) sur sa hampe. `text` est peint sur le tissu.
function Props.banner(parent: Instance, base: Vector3, height: number, color: Color3, text: string?, yaw: number?)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0)
	Core.vcyl(parent, "BannerPole", cf * CFrame.new(0, -0.5, 0), height + 0.5, 0.4, rgb(70, 54, 40), Enum.Material.Wood)
	deco(parent, "BannerBar", Vector3.new(2.8, 0.18, 0.18), cf * CFrame.new(1.2, height - 0.4, 0), rgb(70, 54, 40), Enum.Material.Wood)
	local cloth = deco(parent, "Banner", Vector3.new(2.4, height * 0.62, 0.1), cf * CFrame.new(1.35, height - 0.5 - height * 0.31, 0), color, Enum.Material.Fabric)
	deco(parent, "BannerEdge", Vector3.new(0.12, height * 0.62, 0.14), cf * CFrame.new(0.15, height - 0.5 - height * 0.31, 0), rgb(250, 246, 236), Enum.Material.Fabric)
	if text then
		Build.surfaceText(cloth, Enum.NormalId.Front, text, rgb(255, 250, 240), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		Build.surfaceText(cloth, Enum.NormalId.Back, text, rgb(255, 250, 240), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	end
	return cloth
end

-- Lanterne de pierre japonaise (tōrō) : socle, fût, foyer lumineux, toit à débord, pointe.
function Props.stoneLantern(parent: Instance, base: Vector3, scale: number?, glow: Color3?)
	local s = scale or 1
	local stone = STONE
	local cf = CFrame.new(base)
	part(parent, "LanternBase", Vector3.new(2.8, 0.7, 2.8) * s, cf * CFrame.new(0, 0.35 * s, 0), shade(stone, -0.06), Enum.Material.Slate)
	Core.vcyl(parent, "LanternPost", cf * CFrame.new(0, 0.7 * s, 0), 3 * s, 1.1 * s, stone, Enum.Material.Slate)
	part(parent, "LanternSeat", Vector3.new(2.5, 0.55, 2.5) * s, cf * CFrame.new(0, 3.95 * s, 0), stone, Enum.Material.Slate)
	local light = deco(parent, "LanternLight", Vector3.new(1.6, 1.5, 1.6) * s, cf * CFrame.new(0, 4.95 * s, 0), glow or rgb(255, 200, 120), Enum.Material.Neon)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			deco(parent, "LanternPillar", Vector3.new(0.3, 1.5, 0.3) * s, cf * CFrame.new(x * 0.85 * s, 4.95 * s, z * 0.85 * s), stone, Enum.Material.Slate)
		end
	end
	for _, p in Core.pyramid(parent, "LanternRoof", cf * CFrame.new(0, 5.7 * s, 0), 3.6 * s, 3.6 * s, 1.3 * s, shade(stone, -0.04), Enum.Material.Slate) do
		p.CanCollide = false
	end
	Core.ball(parent, "LanternTop", 0.8 * s, (cf * CFrame.new(0, 7.15 * s, 0)).Position, stone, Enum.Material.Slate)
	Core.light(light, glow or rgb(255, 190, 110), 18, 1.3)
end

-- Lanterne de papier ronde suspendue (et sa lumière).
function Props.paperLantern(parent: Instance, position: Vector3, color: Color3, size: number?, lit: boolean?)
	local s = size or 1
	local lamp = Core.ellipsoid(parent, "PaperLantern", Vector3.new(1.6, 2.1, 1.6) * s, CFrame.new(position), color, Enum.Material.Neon)
	lamp.Transparency = 0.05
	deco(parent, "LanternCap", Vector3.new(1.1, 0.3, 1.1) * s, CFrame.new(position + UP * 1.1 * s), rgb(40, 30, 30))
	deco(parent, "LanternCap", Vector3.new(1.1, 0.3, 1.1) * s, CFrame.new(position - UP * 1.1 * s), rgb(40, 30, 30))
	deco(parent, "LanternTassel", Vector3.new(0.2, 0.8, 0.2) * s, CFrame.new(position - UP * 1.6 * s), rgb(200, 160, 60), Enum.Material.Fabric)
	if lit ~= false then
		Core.light(lamp, color, 14, 1.1)
	end
	return lamp
end

-- Lanterne suspendue à une potence : bras de `anchor` vers `anchor + out`, lanterne dessous.
function Props.hangingLantern(parent: Instance, anchor: Vector3, out: Vector3, color: Color3, size: number?)
	local s = size or 1
	local tip = anchor + out
	Core.beam(parent, "LanternArm", anchor, tip, 0.3, 0.3, rgb(60, 44, 34), { Material = Enum.Material.Wood, CanCollide = false })
	deco(parent, "LanternHook", Vector3.new(0.12, 0.5 * s, 0.12), CFrame.new(tip - UP * 0.25 * s), rgb(50, 50, 54), Enum.Material.Metal)
	return Props.paperLantern(parent, tip - UP * 1.6 * s, color, s)
end

-- Lampadaire en fer forgé (style ville) ou en bois avec lanterne (style village).
function Props.lamppost(parent: Instance, base: Vector3, style: string?, glow: Color3?)
	local g = glow or rgb(255, 222, 160)
	local cf = CFrame.new(base)
	if style == "bois" then
		Core.vcyl(parent, "LampPost", cf * CFrame.new(0, -0.4, 0), 9.4, 0.7, WOOD_DARK, Enum.Material.Wood)
		deco(parent, "LampArm", Vector3.new(2.6, 0.35, 0.35), cf * CFrame.new(1, 8.6, 0), WOOD_DARK, Enum.Material.Wood)
		Props.paperLantern(parent, (cf * CFrame.new(2, 7.2, 0)).Position, g, 0.8)
		return
	end
	Core.vcyl(parent, "LampBase", cf, 1.2, 1.4, rgb(46, 44, 46), Enum.Material.Metal)
	Core.vcyl(parent, "LampPost", cf * CFrame.new(0, 1.2, 0), 9, 0.55, rgb(46, 44, 46), Enum.Material.Metal)
	deco(parent, "LampCage", Vector3.new(1.6, 2, 1.6), cf * CFrame.new(0, 11.2, 0), rgb(46, 44, 46), Enum.Material.Metal)
	local lamp = deco(parent, "Lamp", Vector3.new(1.3, 1.7, 1.3), cf * CFrame.new(0, 11.2, 0), g, Enum.Material.Neon)
	for _, p in Core.pyramid(parent, "LampHat", cf * CFrame.new(0, 12.2, 0), 2.2, 2.2, 0.9, rgb(46, 44, 46), Enum.Material.Metal) do
		p.CanCollide = false
	end
	Core.light(lamp, g, 22, 1.3)
end

-- Poteau d'entraînement (rondin et corde) avec cible.
function Props.trainingPost(parent: Instance, base: Vector3, rng: Random)
	local cf = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	Core.vcyl(parent, "TrainingLog", cf * CFrame.new(0, -0.3, 0), 6.3, 1.8, rgb(140, 98, 62), Enum.Material.Wood)
	Core.vcyl(parent, "Rope", cf * CFrame.new(0, 3, 0), 0.5, 1.9, rgb(222, 204, 156), Enum.Material.Fabric, false)
	Core.vcyl(parent, "Rope", cf * CFrame.new(0, 4.2, 0), 0.4, 1.9, rgb(222, 204, 156), Enum.Material.Fabric, false)
	local target = deco(parent, "Target", Vector3.new(0.15, 1.2, 1.2), cf * CFrame.new(0, 4.8, -0.95) * CFrame.Angles(0, math.rad(90), 0), rgb(200, 50, 40))
	target.Shape = Enum.PartType.Cylinder
	-- kunai plantés
	for k = 1, 2 do
		deco(parent, "Kunai", Vector3.new(0.12, 0.3, 1.1), cf * CFrame.new((k - 1.5) * 0.6, 3.6 + k * 0.4, -1.2) * CFrame.Angles(0.2, 0, 0), rgb(60, 62, 70), Enum.Material.Metal)
	end
end

-- Râtelier d'armes (bâtons / sabres de bois).
function Props.weaponRack(parent: Instance, cf: CFrame)
	for _, x in { -2.2, 2.2 } do
		part(parent, "RackPost", Vector3.new(0.4, 4, 0.4), cf * CFrame.new(x, 2, 0), WOOD_DARK, Enum.Material.Wood)
	end
	for _, y in { 1.2, 3.4 } do
		deco(parent, "RackBar", Vector3.new(4.8, 0.3, 0.4), cf * CFrame.new(0, y, 0), WOOD_DARK, Enum.Material.Wood)
	end
	for i = -2, 2 do
		deco(parent, "Bokken", Vector3.new(0.2, 4.4, 0.25), cf * CFrame.new(i * 0.8, 2.4, -0.3) * CFrame.Angles(0, 0, 0.08), rgb(196, 160, 110), Enum.Material.Wood)
	end
end

-- Panneau indicateur avec flèches (textes vers des directions).
function Props.signpost(parent: Instance, base: Vector3, arrows: { { text: string, yaw: number } })
	Core.vcyl(parent, "SignpostPole", CFrame.new(base - UP * 0.4), 8.4, 0.6, WOOD_DARK, Enum.Material.Wood)
	for i, arrow in arrows do
		local cf = CFrame.new(base + UP * (7.2 - i * 1.4)) * CFrame.Angles(0, arrow.yaw, 0) * CFrame.new(0, 0, -1.9)
		local board = part(parent, "SignArrow", Vector3.new(0.3, 1.1, 3.6), cf, rgb(180, 140, 92), Enum.Material.WoodPlanks, false)
		Build.surfaceText(board, Enum.NormalId.Right, arrow.text, rgb(60, 40, 30), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBold })
		Build.surfaceText(board, Enum.NormalId.Left, arrow.text, rgb(60, 40, 30), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBold })
		Build.wedge(parent, "SignTip", Vector3.new(0.3, 1.1, 0.8), cf * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, 0, 0), rgb(180, 140, 92), { Material = Enum.Material.WoodPlanks, CanCollide = false })
	end
end

-- Puits de pierre avec toit et seau.
function Props.well(parent: Instance, base: Vector3)
	local cf = CFrame.new(base)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(parent, "WellStone", Vector3.new(2, 2.6, 1.1), CFrame.lookAt(base + Vector3.new(math.cos(a) * 2.4, 1.3, math.sin(a) * 2.4), base + UP * 1.3), shade(STONE, (i % 2) * 0.06), Enum.Material.Cobblestone)
	end
	local water = deco(parent, "WellWater", Vector3.new(0.2, 4, 4), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(40, 90, 120), Enum.Material.Glass)
	water.Shape = Enum.PartType.Cylinder
	for _, x in { -1, 1 } do
		part(parent, "WellPost", Vector3.new(0.5, 7, 0.5), cf * CFrame.new(x * 2.6, 3.5, 0), WOOD_DARK, Enum.Material.Wood)
	end
	Build.wedge(parent, "WellRoof", Vector3.new(6.6, 1.6, 2.4), cf * CFrame.new(0, 7.6, 1.1) * CFrame.Angles(0, math.pi, 0), rgb(120, 70, 50), { Material = Enum.Material.WoodPlanks })
	Build.wedge(parent, "WellRoof", Vector3.new(6.6, 1.6, 2.4), cf * CFrame.new(0, 7.6, -1.1), rgb(120, 70, 50), { Material = Enum.Material.WoodPlanks })
	deco(parent, "WellBeam", Vector3.new(5.6, 0.4, 0.4), cf * CFrame.new(0, 6, 0), WOOD_DARK, Enum.Material.Wood)
	deco(parent, "WellRope", Vector3.new(0.1, 2.6, 0.1), cf * CFrame.new(0.4, 4.6, 0), rgb(210, 190, 140), Enum.Material.Fabric)
	Core.vcyl(parent, "Bucket", cf * CFrame.new(0.4, 2.6, 0), 1, 1, rgb(140, 100, 64), Enum.Material.WoodPlanks, false)
end

-- Distributeur de boissons (rue japonaise moderne), lumineux.
function Props.vendingMachine(parent: Instance, cf: CFrame, color: Color3?)
	local c = color or rgb(200, 50, 50)
	part(parent, "Vending", Vector3.new(3.4, 6, 2.4), cf * CFrame.new(0, 3, 0), c, Enum.Material.Metal)
	local panel = deco(parent, "VendingPanel", Vector3.new(2.8, 3, 0.1), cf * CFrame.new(0, 4, -1.22), rgb(230, 240, 255), Enum.Material.Neon)
	panel.Transparency = 0.2
	for row = 0, 2 do
		for i = 0, 3 do
			deco(parent, "Can", Vector3.new(0.4, 0.7, 0.1), cf * CFrame.new(-1 + i * 0.66, 3 + row * 0.95, -1.3), ({ rgb(240, 60, 60), rgb(60, 140, 240), rgb(250, 200, 60), rgb(80, 200, 120) })[i + 1])
		end
	end
	deco(parent, "VendingSlot", Vector3.new(2, 0.6, 0.12), cf * CFrame.new(0, 1, -1.22), rgb(30, 30, 34))
	Core.light(panel, rgb(220, 235, 255), 10, 0.8)
end

-- Pot de plante (bonsaï ou arbuste) sur le sol ou un rebord.
function Props.pottedPlant(parent: Instance, base: Vector3, rng: Random, potColor: Color3?)
	local pot = potColor or rgb(150, 86, 60)
	Core.vcyl(parent, "Pot", CFrame.new(base), 1.4, 1.6, pot, Enum.Material.Slate, false)
	Core.vcyl(parent, "PotRim", CFrame.new(base + UP * 1.3), 0.3, 1.9, shade(pot, -0.1), Enum.Material.Slate, false)
	local green = rgb(72, 124, 58)
	for k = 1, 3 do
		Core.ball(parent, "Leaves", rng:NextNumber(1, 1.5), base + UP * (2 + k * 0.3) + Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), shade(green, rng:NextNumber(-0.1, 0.15)), Enum.Material.Grass)
	end
end

-- Kiosque rond couvert (thé, journaux) : comptoir, poteaux, toit en pyramide octogonale simulée.
function Props.kiosk(parent: Instance, base: Vector3, color: Color3, roof: Color3, text: string?)
	local cf = CFrame.new(base)
	Core.vcyl(parent, "KioskFloor", cf, 0.6, 12, STONE, Enum.Material.Cobblestone)
	Core.vcyl(parent, "KioskCounter", cf * CFrame.new(0, 0.6, 0), 3.2, 7, color, Enum.Material.WoodPlanks)
	Core.vcyl(parent, "KioskTop", cf * CFrame.new(0, 3.8, 0), 0.35, 7.8, shade(color, 0.15), Enum.Material.Wood, false)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part(parent, "KioskPost", Vector3.new(0.45, 8, 0.45), cf * CFrame.new(math.cos(a) * 5.4, 4.6, math.sin(a) * 5.4), WOOD_DARK, Enum.Material.Wood)
	end
	for k = 0, 1 do
		for _, p in Core.pyramid(parent, "KioskRoof", cf * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, k * math.pi / 4, 0), 13, 13, 4, roof, Enum.Material.ClayRoofTiles) do
			p.CanCollide = k == 0
		end
	end
	Core.ball(parent, "KioskFinial", 1, (cf * CFrame.new(0, 12.8, 0)).Position, rgb(220, 180, 70), Enum.Material.Metal)
	if text then
		local sign = deco(parent, "KioskSign", Vector3.new(6, 1.4, 0.3), cf * CFrame.new(0, 7.6, -5.6), rgb(54, 40, 32), Enum.Material.Wood)
		Build.surfaceText(sign, Enum.NormalId.Front, text, rgb(255, 232, 170), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	end
end

return Props
