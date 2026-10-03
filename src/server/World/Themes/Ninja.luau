-- Décor de l'univers VILLAGE NINJA (inspiré de Naruto), à l'échelle de TOUTE la carte et en
-- taille réelle (perso R6 ≈ 5,3 studs, porte ≈ 8 studs) :
--   * dans l'anneau : le village (tour ronde rouge du chef, maisons cylindriques à toits rouges,
--     immeubles avec réservoirs d'eau, stand de ramen), places en terre, arbres, lanternes ;
--   * la grande porte du village sur la route de la base 270° (« あ » et « ん » sur les battants) ;
--   * autour des bases : la forêt d'arbres géants ;
--   * au bord de l'île : la montagne des chefs avec 5 visages sculptés dans la falaise ;
--   * à l'horizon : une couronne de montagnes vertes.
-- Les gros éléments sont des emplacements remplaçables (DecorKit.slot) : un modèle de la Boîte à
-- outils rangé dans ServerStorage > ModelesDeco sous le même nom les remplace au lancement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Parent.Modules.Build)
local DecorKit = require(script.Parent.Parent.DecorKit)
local WorldBuilder = require(script.Parent.Parent.WorldBuilder)

local Ninja = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local CREAM = rgb(240, 228, 204)
local CREAM_DARK = rgb(214, 198, 170)
local RED = rgb(196, 66, 48)
local RED_ROOF = rgb(206, 78, 54)
local TEAL_ROOF = rgb(64, 118, 112)
local ORANGE_ROOF = rgb(226, 132, 62)
local WOOD = rgb(150, 102, 64)
local WOOD_DARK = rgb(96, 64, 44)
local WINDOW = rgb(54, 70, 92)
local ROCK = rgb(178, 150, 116)
local ROCK_LIGHT = rgb(200, 174, 138)
local ROCK_DARK = rgb(120, 98, 76)

local TOP_RING = 0.08
local TOP_PLAZA = 0.13

local function shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(WHITE, amount)
	end
	return color:Lerp(BLACK, -amount)
end

local function polarDeg(angle: number, radius: number, y: number?): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
end

-- Repère au sol à (angle, rayon), -Z local tourné vers le centre de la carte.
local function facing(angle: number, radius: number, y: number?): CFrame
	local pos = polarDeg(angle, radius, y)
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

-- Cylindre vertical posé à `base` (bas), dans le repère `cf` si donné.
local function vcyl(parent: Instance, name: string, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local part = Build.part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, {
		Material = material or Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
		CanCollide = collide ~= false,
	})
	return part
end

-- Texte peint sur la face avant d'une plaque invisible (visible des deux côtés si `both`).
local function plaqueText(parent: Instance, cf: CFrame, size: Vector2, text: string, color: Color3)
	local plaque = Build.deco(parent, "Texte", Vector3.new(size.X, size.Y, 0.1), cf, WHITE, { Transparency = 1, CastShadow = false })
	Build.surfaceText(plaque, Enum.NormalId.Front, text, color, { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	return plaque
end

-- Fenêtres réparties autour d'un cylindre (centre `cf`, rayon `radius`, hauteur `y`).
local function ringWindows(parent: Instance, cf: CFrame, radius: number, y: number, count: number, size: Vector2, skipFront: boolean?)
	for i = 0, count - 1 do
		local a = (i + 0.5) / count * math.pi * 2
		local front = math.abs(math.cos(a - math.pi / 2) - 1) < 0.15
		if not (skipFront and front) then
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local local_ = CFrame.lookAt(dir * (radius - 0.15) + Vector3.new(0, y, 0), dir * (radius + 5) + Vector3.new(0, y, 0))
			local wcf = cf * local_
			Build.deco(parent, "Window", Vector3.new(size.X, size.Y, 0.6), wcf, WINDOW, { Material = Enum.Material.Glass, Reflectance = 0.1 })
			Build.deco(parent, "Sill", Vector3.new(size.X + 0.8, 0.4, 1), wcf * CFrame.new(0, -size.Y / 2 - 0.2, -0.2), CREAM_DARK)
		end
	end
end

------------------------------------------------------------------------
-- Bâtiments du village
------------------------------------------------------------------------

-- Réservoir d'eau sur pieds (sur les toits du village).
local function waterTank(parent: Instance, base: CFrame, scale: number?)
	local s = scale or 1
	for _, off in { Vector3.new(2.4, 0, 2.4), Vector3.new(-2.4, 0, 2.4), Vector3.new(2.4, 0, -2.4), Vector3.new(-2.4, 0, -2.4) } do
		Build.part(parent, "TankLeg", Vector3.new(0.5, 3, 0.5) * s, base * CFrame.new(off * s + Vector3.new(0, 1.5 * s, 0)), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	vcyl(parent, "Tank", base * CFrame.new(0, 3 * s, 0), 5.5 * s, 7 * s, CREAM, Enum.Material.Plaster)
	vcyl(parent, "TankBand", base * CFrame.new(0, 5 * s, 0), 0.8 * s, 7.2 * s, RED, Enum.Material.SmoothPlastic, false)
	DecorKit.ellipsoid(parent, "TankRoof", Vector3.new(7.6, 3, 7.6) * s, base * CFrame.new(0, 8.5 * s, 0), RED_ROOF)
end

-- Maison cylindrique du village : murs crème, bandeaux par étage, fenêtres, toit en dôme.
local function roundHouse(parent: Instance, cf: CFrame, diameter: number, floors: number, roof: Color3, rng: Random): Model
	local floorH = 11
	local height = floors * floorH
	local model = DecorKit.slot(parent, "MaisonRonde", cf, height + diameter * 0.2)
	vcyl(model, "Plinth", cf, 1, diameter + 2, rgb(160, 152, 140), Enum.Material.Cobblestone)
	vcyl(model, "Walls", cf * CFrame.new(0, 1, 0), height, diameter, CREAM, Enum.Material.Plaster)
	for f = 1, floors do
		local y = 1 + f * floorH
		if f < floors then
			vcyl(model, "FloorBand", cf * CFrame.new(0, y - 0.6, 0), 1.2, diameter + 0.6, shade(roof, -0.1), Enum.Material.SmoothPlastic, false)
		end
		ringWindows(model, cf, diameter / 2, y - floorH * 0.45, math.max(5, math.floor(diameter / 3.6)), Vector2.new(2.6, 3.2), f == 1)
	end
	-- Porte d'entrée (face au centre) avec petit auvent.
	local door = cf * CFrame.new(0, 1 + 4, -diameter / 2 - 0.1)
	Build.deco(model, "Door", Vector3.new(5, 8, 0.6), door, WOOD, { Material = Enum.Material.WoodPlanks })
	Build.deco(model, "DoorFrame", Vector3.new(6.2, 0.8, 0.8), door * CFrame.new(0, 4.3, 0), WOOD_DARK)
	Build.part(
		model,
		"DoorAwning",
		Vector3.new(8, 0.6, 3.2),
		door * CFrame.new(0, 5.4, -1.4) * CFrame.Angles(math.rad(-12), 0, 0),
		roof,
		{ Material = Enum.Material.ClayRoofTiles }
	)
	-- Toit : débord + dôme aplati.
	vcyl(model, "RoofRim", cf * CFrame.new(0, 1 + height, 0), 1.2, diameter + 3, shade(roof, -0.15), Enum.Material.SmoothPlastic)
	DecorKit.ellipsoid(model, "RoofDome", Vector3.new(diameter + 1.5, diameter * 0.42, diameter + 1.5), cf * CFrame.new(0, 2.2 + height, 0), roof)
	if rng:NextNumber() < 0.6 then
		waterTank(model, cf * CFrame.new(diameter * 0.12, 1 + height + diameter * 0.16, diameter * 0.12), 0.9)
	end
	return model
end

-- Immeuble carré : murs crème, rayure colorée, toit-terrasse et réservoir d'eau.
local function boxHouse(parent: Instance, cf: CFrame, size: Vector3, accent: Color3, rng: Random): Model
	local model = DecorKit.slot(parent, "Immeuble", cf, size.Y + 6)
	local hx, hz = size.X / 2, size.Z / 2
	Build.part(model, "Plinth", Vector3.new(size.X + 2, 1, size.Z + 2), cf * CFrame.new(0, 0.5, 0), rgb(160, 152, 140), { Material = Enum.Material.Cobblestone })
	Build.part(model, "Walls", size, cf * CFrame.new(0, 1 + size.Y / 2, 0), CREAM, { Material = Enum.Material.Plaster })
	Build.part(model, "Stripe", Vector3.new(size.X + 0.3, 1.6, size.Z + 0.3), cf * CFrame.new(0, 1 + size.Y - 2.4, 0), accent, { CanCollide = false })
	Build.part(model, "Parapet", Vector3.new(size.X + 0.8, 1.4, size.Z + 0.8), cf * CFrame.new(0, 1 + size.Y + 0.5, 0), CREAM_DARK, { Material = Enum.Material.Concrete })
	Build.part(model, "Roof", Vector3.new(size.X - 0.4, 0.4, size.Z - 0.4), cf * CFrame.new(0, 1 + size.Y + 1, 0), rgb(150, 140, 128), { Material = Enum.Material.Concrete })
	-- Fenêtres sur la façade et les côtés.
	local floors = math.max(1, math.floor(size.Y / 10))
	for f = 0, floors - 1 do
		local y = 1 + 6.4 + f * 10
		local cols = math.max(1, math.floor(size.X / 6))
		for c = 0, cols - 1 do
			local x = -hx + (c + 0.5) * size.X / cols
			if not (f == 0 and math.abs(x) < 3.5) then
				Build.deco(model, "Window", Vector3.new(3, 3.4, 0.5), cf * CFrame.new(x, y, -hz - 0.1), WINDOW, { Material = Enum.Material.Glass })
				Build.deco(model, "Sill", Vector3.new(3.8, 0.4, 0.9), cf * CFrame.new(x, y - 1.9, -hz - 0.3), CREAM_DARK)
			end
		end
		for _, side in { -1, 1 } do
			local rows = math.max(1, math.floor(size.Z / 7))
			for c = 0, rows - 1 do
				local z = -hz + (c + 0.5) * size.Z / rows
				Build.deco(model, "Window", Vector3.new(0.5, 3.4, 3), cf * CFrame.new(side * (hx + 0.1), y, z), WINDOW, { Material = Enum.Material.Glass })
			end
		end
	end
	local door = cf * CFrame.new(0, 1 + 4, -hz - 0.1)
	Build.deco(model, "Door", Vector3.new(5, 8, 0.6), door, WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "Awning", Vector3.new(9, 0.5, 3.4), door * CFrame.new(0, 5, -1.5) * CFrame.Angles(math.rad(-14), 0, 0), accent, { Material = Enum.Material.Fabric })
	-- Climatiseur et réservoir.
	Build.part(model, "AC", Vector3.new(3, 2, 1.6), cf * CFrame.new(hx * 0.5, 1 + size.Y * 0.55, -hz - 0.9), rgb(220, 220, 214), { Material = Enum.Material.Metal })
	if rng:NextNumber() < 0.7 then
		waterTank(model, cf * CFrame.new(-hx * 0.35, 1 + size.Y + 1.2, hz * 0.2), 1)
	end
	return model
end

-- Tour ronde rouge du chef du village, avec la plaque « 火 ».
local function chiefTower(parent: Instance, cf: CFrame): Model
	local model = DecorKit.slot(parent, "TourDuChef", cf, 56)
	local d1, d2 = 46, 40
	vcyl(model, "Plinth", cf, 1.4, d1 + 6, rgb(168, 160, 148), Enum.Material.Cobblestone)
	vcyl(model, "Level1", cf * CFrame.new(0, 1.4, 0), 22, d1, RED, Enum.Material.Plaster)
	vcyl(model, "Band", cf * CFrame.new(0, 23.4, 0), 2.2, d1 + 1.6, CREAM, Enum.Material.SmoothPlastic)
	vcyl(model, "Level2", cf * CFrame.new(0, 25.6, 0), 11, d2, RED, Enum.Material.Plaster)
	vcyl(model, "RoofRim", cf * CFrame.new(0, 36.6, 0), 1.6, d1 + 4, rgb(110, 44, 36), Enum.Material.SmoothPlastic)
	DecorKit.ellipsoid(model, "RoofDome", Vector3.new(d1, 14, d1), cf * CFrame.new(0, 38.2, 0), RED_ROOF)
	vcyl(model, "Lookout", cf * CFrame.new(0, 42, 0), 6, 12, CREAM, Enum.Material.Plaster)
	DecorKit.ellipsoid(model, "LookoutRoof", Vector3.new(15, 5, 15), cf * CFrame.new(0, 48.4, 0), RED_ROOF)
	-- Fenêtres sur deux étages.
	ringWindows(model, cf, d1 / 2, 9, 16, Vector2.new(3, 4.4), true)
	ringWindows(model, cf, d1 / 2, 17.5, 16, Vector2.new(3, 4.4), false)
	ringWindows(model, cf, d2 / 2, 30, 14, Vector2.new(2.6, 3.6), true)
	-- Plaque blanche ronde « 火 » sur la façade.
	local plaqueCF = cf * CFrame.new(0, 30.6, -d2 / 2 - 0.6)
	local disc = Build.deco(model, "Plaque", Vector3.new(0.8, 9, 9), plaqueCF * CFrame.Angles(0, math.rad(90), 0), WHITE)
	disc.Shape = Enum.PartType.Cylinder
	plaqueText(model, plaqueCF * CFrame.new(0, 0, -0.5), Vector2.new(7, 7), "火", RED)
	-- Grande porte et marches.
	local door = cf * CFrame.new(0, 1.4 + 5.5, -d1 / 2 - 0.2)
	Build.deco(model, "Door", Vector3.new(9, 11, 0.6), door, WOOD_DARK, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "Porch", Vector3.new(16, 0.8, 6), door * CFrame.new(0, 7, -2.8), RED_ROOF, { Material = Enum.Material.ClayRoofTiles })
	for _, side in { -1, 1 } do
		Build.part(model, "PorchPost", Vector3.new(0.9, 12.5, 0.9), door * CFrame.new(side * 7, 0.6, -5.2), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	for i = 0, 2 do
		Build.part(model, "Step", Vector3.new(14, 0.5, 2), cf * CFrame.new(0, 0.25 + i * 0.45, -d1 / 2 - 7 + i * 1.6), rgb(176, 168, 156), { Material = Enum.Material.Slate })
	end
	return model
end

-- Stand de ramen : comptoir et tabourets, rideaux noren, lanternes rouges, enseigne.
local function ramenStand(parent: Instance, cf: CFrame): Model
	local model = DecorKit.slot(parent, "StandRamen", cf, 13)
	local w, d = 18, 11
	Build.part(model, "Floor", Vector3.new(w + 2, 0.6, d + 2), cf * CFrame.new(0, 0.3, 0), rgb(168, 160, 148), { Material = Enum.Material.Cobblestone })
	Build.part(model, "Kitchen", Vector3.new(w, 10, 4), cf * CFrame.new(0, 5.6, d / 2 - 2), CREAM, { Material = Enum.Material.Plaster })
	Build.part(model, "Counter", Vector3.new(w - 2, 3.4, 2.4), cf * CFrame.new(0, 2.3, -1), WOOD, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "CounterTop", Vector3.new(w - 1.4, 0.4, 3), cf * CFrame.new(0, 4.2, -1), rgb(190, 140, 92), { Material = Enum.Material.Wood })
	for i = -2, 2 do
		local stool = cf * CFrame.new(i * 3.2, 0.6, -4)
		vcyl(model, "StoolLeg", stool, 2.2, 0.6, rgb(80, 80, 86), Enum.Material.Metal)
		vcyl(model, "StoolSeat", stool * CFrame.new(0, 2.2, 0), 0.5, 2, RED, Enum.Material.SmoothPlastic)
		Build.ball(model, "Bowl", 1, (cf * CFrame.new(i * 3.2, 4.7, -1.2)).Position, rgb(250, 246, 236), { CanCollide = false })
	end
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.9, 11, 0.9), cf * CFrame.new(side * (w / 2 - 0.4), 6, -d / 2 + 0.5), WOOD_DARK, { Material = Enum.Material.Wood })
	end
	-- Toit en pente (tuiles) vers l'avant.
	Build.wedge(model, "Roof", Vector3.new(w + 3, 2.6, d + 3), cf * CFrame.new(0, 12.4, 0), rgb(150, 54, 40), { Material = Enum.Material.ClayRoofTiles })
	Build.part(model, "Beam", Vector3.new(w + 1, 0.9, 0.9), cf * CFrame.new(0, 10.8, -d / 2 + 0.5), WOOD_DARK, { Material = Enum.Material.Wood })
	-- Noren blancs, chacun porte une lettre de « ラーメン ».
	local panels = 5
	for i = 0, panels - 1 do
		local x = -w / 2 + 1 + (i + 0.5) * (w - 2) / panels
		local panel = Build.deco(model, "Noren", Vector3.new((w - 2) / panels - 0.25, 3.4, 0.15), cf * CFrame.new(x, 8.6, -d / 2 + 0.3), rgb(248, 244, 236), {
			Material = Enum.Material.Fabric,
		})
		local text = ({ "🍜", "ン", "メ", "ー", "ラ" })[i + 1] -- de droite à gauche vu de face (+X local = à gauche)
		Build.surfaceText(panel, Enum.NormalId.Front, text, RED, { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	end
	-- Enseigne et lanternes rouges.
	local sign = Build.part(model, "Sign", Vector3.new(12, 3, 0.6), cf * CFrame.new(0, 15, -d / 2 + 1) * CFrame.Angles(math.rad(-8), 0, 0), rgb(120, 40, 32), {
		Material = Enum.Material.Wood,
	})
	Build.surfaceText(sign, Enum.NormalId.Front, "RAMEN", rgb(255, 236, 190))
	for _, side in { -1, 1 } do
		local lamp = DecorKit.ellipsoid(model, "Lantern", Vector3.new(2, 2.8, 2), cf * CFrame.new(side * (w / 2 + 0.6), 8.4, -d / 2 + 0.5), rgb(255, 70, 50), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 120, 80)
		light.Range = 14
		light.Parent = lamp
	end
	return model
end

-- Grande porte du village (à cheval sur la route), avec ses battants verts ouverts et un bout de rempart.
local function villageGate(parent: Instance, cf: CFrame): Model
	local model = DecorKit.slot(parent, "PorteDuVillage", cf, 46)
	local frame = rgb(176, 78, 50)
	local opening = 28
	local h = 34
	for _, side in { -1, 1 } do
		local x = side * (opening / 2 + 3)
		Build.part(model, "Pillar", Vector3.new(6, h, 8), cf * CFrame.new(x, h / 2, 0), frame, { Material = Enum.Material.WoodPlanks })
		Build.part(model, "PillarBase", Vector3.new(7.4, 3, 9.4), cf * CFrame.new(x, 1.5, 0), rgb(150, 142, 132), { Material = Enum.Material.Cobblestone })
		-- Battant ouvert vers l'intérieur du village (le long du mur), avec son caractère.
		local hinge = cf * CFrame.new(side * opening / 2, 0, -4)
		local leaf = hinge * CFrame.Angles(0, side * math.rad(-80), 0) * CFrame.new(-side * opening / 4, h * 0.42, 0)
		local door = Build.part(model, "DoorLeaf", Vector3.new(opening / 2, h * 0.84, 1.2), leaf, rgb(70, 132, 92), { Material = Enum.Material.WoodPlanks })
		Build.surfaceText(door, Enum.NormalId.Front, side < 0 and "あ" or "ん", rgb(200, 60, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		Build.surfaceText(door, Enum.NormalId.Back, side < 0 and "あ" or "ん", rgb(200, 60, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		-- Rempart de part et d'autre.
		local wallLen = 30
		local wx = side * (opening / 2 + 6 + wallLen / 2)
		Build.part(model, "Rampart", Vector3.new(wallLen, 15, 4), cf * CFrame.new(wx, 7.5, 1), rgb(196, 112, 76), { Material = Enum.Material.Plaster })
		Build.part(model, "RampartCap", Vector3.new(wallLen + 1, 1.6, 6), cf * CFrame.new(wx, 15.6, 1), TEAL_ROOF, { Material = Enum.Material.ClayRoofTiles })
		Build.part(model, "RampartBase", Vector3.new(wallLen, 2.4, 5), cf * CFrame.new(wx, 1.2, 1), rgb(150, 142, 132), { Material = Enum.Material.Cobblestone })
	end
	Build.part(model, "Lintel", Vector3.new(opening + 16, 4, 9), cf * CFrame.new(0, h + 2, 0), frame, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "Lintel2", Vector3.new(opening + 10, 2, 7), cf * CFrame.new(0, h - 4, 0), frame, { Material = Enum.Material.WoodPlanks })
	-- Toit à deux pans en tuiles vertes.
	for _, side in { -1, 1 } do
		Build.wedge(
			model,
			"Roof",
			Vector3.new(opening + 24, 6, 8),
			cf * CFrame.new(0, h + 7, side * 4) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
			TEAL_ROOF,
			{ Material = Enum.Material.ClayRoofTiles }
		)
	end
	Build.part(model, "Ridge", Vector3.new(opening + 26, 1.4, 1.6), cf * CFrame.new(0, h + 10.2, 0), shade(TEAL_ROOF, -0.35), { Material = Enum.Material.Slate })
	-- Plaque « 忍 » au-dessus du passage (des deux côtés).
	for _, z in { -4.6, 4.6 } do
		local plaque = Build.part(model, "Plaque", Vector3.new(9, 7, 0.6), cf * CFrame.new(0, h - 0.5, z), rgb(244, 232, 206), { CanCollide = false })
		Build.surfaceText(plaque, z < 0 and Enum.NormalId.Front or Enum.NormalId.Back, "忍", rgb(200, 50, 40), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	end
	return model
end

-- Montagne des chefs : falaise de roche avec 5 visages sculptés. `cf` = pied de la falaise,
-- -Z local vers le village. Largeur ≈ 460, hauteur ≈ 150.
local function chiefMountain(parent: Instance, cf: CFrame, rng: Random): Model
	local model = DecorKit.slot(parent, "MontagneDesChefs", cf, 150)
	-- Corps de la falaise : grands blocs inclinés (silhouette irrégulière).
	local blocks = {
		{ -200, 120, 110, 0.06 },
		{ -120, 150, 120, -0.04 },
		{ -30, 160, 110, 0.03 },
		{ 60, 155, 120, -0.05 },
		{ 150, 140, 110, 0.04 },
		{ 225, 105, 90, -0.06 },
	}
	for i, b in blocks do
		local x, h, w, tilt = b[1], b[2], b[3], b[4]
		Build.part(
			model,
			"Cliff",
			Vector3.new(w, h, 150),
			cf * CFrame.new(x, h / 2 - 2, 80 + (i % 2) * 6) * CFrame.Angles(0, tilt, tilt * 0.5),
			shade(ROCK, ((i % 3) - 1) * 0.05),
			{ Material = Enum.Material.Rock, CastShadow = true }
		)
		-- Sommet herbeux et arbres.
		DecorKit.ellipsoid(model, "CliffTop", Vector3.new(w * 1.08, 46, 168), cf * CFrame.new(x, h - 10, 86), rgb(88, 150, 70), Enum.Material.Grass)
		DecorKit.ellipsoid(model, "CliffTop", Vector3.new(w * 0.6, 30, 90), cf * CFrame.new(x + rng:NextNumber(-12, 12), h + 4, 100), rgb(104, 166, 80), Enum.Material.Grass)
	end
	for _ = 1, 14 do
		local x = rng:NextNumber(-220, 220)
		local top = 0
		for _, b in blocks do
			if math.abs(x - b[1]) < b[3] / 2 then
				top = math.max(top, b[2])
			end
		end
		if top > 0 then
			DecorKit.roundTree(model, (cf * CFrame.new(x, top + 4, rng:NextNumber(60, 130))).Position, {
				rng = rng,
				height = rng:NextNumber(24, 34),
				palette = DecorKit.Palettes.foret,
				slot = "ArbreRond",
			})
		end
	end
	-- Éboulis au pied.
	for _ = 1, 16 do
		DecorKit.rock(model, (cf * CFrame.new(rng:NextNumber(-230, 230), 0, rng:NextNumber(-14, 2))).Position, rng:NextNumber(6, 16), {
			rng = rng,
			color = ROCK_DARK,
			slot = "RocherFalaise",
		})
	end
	-- Les 5 visages (yeux, sourcils, nez, bouche, cheveux différents).
	local faces = { -168, -84, 0, 84, 168 }
	for i, x in faces do
		local head = cf * CFrame.new(x, 92 + (i == 3 and 6 or 0), -4)
		local s = 1
		DecorKit.ellipsoid(model, "Face", Vector3.new(40, 50, 22) * s, head, ROCK_LIGHT, Enum.Material.Rock)
		DecorKit.ellipsoid(model, "Jaw", Vector3.new(28, 20, 16) * s, head * CFrame.new(0, -20, -2), ROCK_LIGHT, Enum.Material.Rock)
		for _, side in { -1, 1 } do
			local tilt = side * math.rad(i % 2 == 0 and 12 or -6)
			Build.part(model, "Brow", Vector3.new(13, 3.2, 5), head * CFrame.new(side * 9, 9, -9.5) * CFrame.Angles(0, 0, tilt), ROCK, { Material = Enum.Material.Rock })
			DecorKit.ellipsoid(model, "Eye", Vector3.new(9, 4.2, 3), head * CFrame.new(side * 9, 4, -9.6), shade(ROCK, -0.08), Enum.Material.Rock)
			Build.part(model, "Pupil", Vector3.new(2.6, 2.6, 1.2), head * CFrame.new(side * 8.4, 3.8, -10.9), ROCK_DARK, { Material = Enum.Material.Rock })
			Build.part(
				model,
				"Cheek",
				Vector3.new(2, 8, 2),
				head * CFrame.new(side * 13, -8, -9) * CFrame.Angles(0, 0, side * 0.3),
				shade(ROCK, -0.1),
				{ Material = Enum.Material.Rock }
			)
		end
		Build.wedge(model, "Nose", Vector3.new(6, 11, 6), head * CFrame.new(0, -3, -12) * CFrame.Angles(0, math.pi, 0), ROCK_LIGHT, { Material = Enum.Material.Rock })
		Build.part(model, "Mouth", Vector3.new(12, 1.6, 2), head * CFrame.new(0, -14, -10.5), shade(ROCK, -0.2), { Material = Enum.Material.Rock })
		-- Cheveux.
		if i == 1 then
			-- longs et lisses
			DecorKit.ellipsoid(model, "Hair", Vector3.new(46, 24, 26), head * CFrame.new(0, 22, 2), ROCK, Enum.Material.Rock)
			for _, side in { -1, 1 } do
				Build.part(
					model,
					"HairSide",
					Vector3.new(9, 52, 14),
					head * CFrame.new(side * 22, -6, 4) * CFrame.Angles(0, 0, side * 0.06),
					ROCK,
					{ Material = Enum.Material.Rock }
				)
			end
		elseif i == 2 then
			-- courts en pointes
			for k = -2, 2 do
				Build.wedge(model, "Spike", Vector3.new(10, 14, 12), head * CFrame.new(k * 8, 26, 0) * CFrame.Angles(0, 0, k * 0.25), ROCK, { Material = Enum.Material.Rock })
			end
			DecorKit.ellipsoid(model, "Hair", Vector3.new(42, 16, 24), head * CFrame.new(0, 20, 2), ROCK, Enum.Material.Rock)
		elseif i == 3 then
			-- le vieux sage : grand chapeau
			DecorKit.ellipsoid(model, "Hat", Vector3.new(60, 10, 30), head * CFrame.new(0, 22, 0), ROCK, Enum.Material.Rock)
			DecorKit.ellipsoid(model, "HatTop", Vector3.new(30, 22, 22), head * CFrame.new(0, 30, 2), ROCK, Enum.Material.Rock)
			Build.part(model, "Beard", Vector3.new(14, 8, 4), head * CFrame.new(0, -27, -6), ROCK, { Material = Enum.Material.Rock })
		elseif i == 4 then
			-- hérissés (style héros blond)
			for k = -3, 3 do
				local spike = head * CFrame.new(k * 7, 24 + (3 - math.abs(k)) * 1.5, -2) * CFrame.Angles(math.rad(-20), 0, k * 0.32)
				Build.wedge(model, "Spike", Vector3.new(8, 18, 10), spike * CFrame.Angles(0, math.pi, 0), ROCK, { Material = Enum.Material.Rock })
			end
			for _, side in { -1, 1 } do
				Build.wedge(model, "Bang", Vector3.new(8, 20, 8), head * CFrame.new(side * 19, 4, -4) * CFrame.Angles(0, 0, side * 0.2), ROCK, { Material = Enum.Material.Rock })
			end
		else
			-- deux couettes
			DecorKit.ellipsoid(model, "Hair", Vector3.new(44, 22, 24), head * CFrame.new(0, 21, 2), ROCK, Enum.Material.Rock)
			for _, side in { -1, 1 } do
				DecorKit.ellipsoid(model, "Pigtail", Vector3.new(10, 40, 12), head * CFrame.new(side * 25, -12, 4), ROCK, Enum.Material.Rock)
			end
			Build.part(model, "Mark", Vector3.new(3, 3, 1), head * CFrame.new(0, 12, -11) * CFrame.Angles(0, 0, math.rad(45)), ROCK_DARK, { Material = Enum.Material.Rock })
		end
	end
	return model
end

------------------------------------------------------------------------
-- Construction du décor
------------------------------------------------------------------------

local FOREST = DecorKit.Palettes.foret
local GREEN = DecorKit.Palettes.vert

-- Vrai si l'endroit de l'anneau est libre (hors chemins, arène, hub).
local function ringFree(pos: Vector3, margin: number): boolean
	local r = Vector3.new(pos.X, 0, pos.Z).Magnitude
	return r > Layout.RingInner + margin and r < Layout.RingOuter - margin and not Layout.onPath(pos, margin + 2) and not Layout.inBossArena(pos, margin + 6)
end

-- Zone de la montagne des chefs (pas d'arbres de forêt dedans).
local MOUNTAIN_ANGLE = 270
local MOUNTAIN_RADIUS = 588
local function nearMountain(pos: Vector3): boolean
	local cf = facing(MOUNTAIN_ANGLE, MOUNTAIN_RADIUS)
	local p = cf:PointToObjectSpace(pos)
	return math.abs(p.X) < 250 and p.Z > -40
end

-- Les bâtiments du village : { angle, rayon, type, paramètres }.
local BUILDINGS = {
	{ 300, 303, "tower" },
	{ 283, 318, "box", Vector3.new(16, 20, 14), ORANGE_ROOF },
	{ 317, 318, "box", Vector3.new(18, 24, 14), RED },
	{ 257, 316, "ramen" },
	{ 244, 312, "round", 24, 2, RED_ROOF },
	{ 228, 311, "round", 20, 3, ORANGE_ROOF },
	{ 216, 320, "box", Vector3.new(14, 16, 12), TEAL_ROOF },
	{ 196, 311, "round", 18, 3, TEAL_ROOF },
	{ 181, 318, "box", Vector3.new(20, 22, 14), RED },
	{ 165, 312, "round", 26, 2, RED_ROOF },
	{ 136, 313, "round", 20, 2, ORANGE_ROOF },
	{ 119, 311, "round", 28, 2, RED_ROOF },
	{ 103, 319, "box", Vector3.new(16, 18, 12), TEAL_ROOF },
	{ 77, 311, "round", 24, 2, TEAL_ROOF },
	{ 61, 318, "box", Vector3.new(22, 16, 14), ORANGE_ROOF },
	{ 45, 312, "round", 22, 3, RED_ROOF },
	{ 13, 312, "round", 22, 2, ORANGE_ROOF },
	{ 357, 319, "box", Vector3.new(16, 22, 12), RED },
	{ 343, 312, "round", 20, 2, TEAL_ROOF },
}

-- Deuxième rangée de petites maisons (juste devant la première).
local SECOND_ROW = { 350, 6, 22, 38, 53, 68, 82, 98, 112, 127, 142, 158, 172, 188, 203, 220, 236, 250, 262, 278, 312, 324, 337 }

function Ninja.build(decor: Instance, rng: Random, _theme)
	local ring = Build.folder(decor, "Anneau")
	local island = Build.folder(decor, "Ile")
	local horizon = Build.folder(decor, "Horizon")

	-- 1) Village dans l'anneau.
	local village = Build.folder(ring, "Village")
	for _, b in BUILDINGS do
		local angle, radius, kind = b[1], b[2], b[3]
		local cf = facing(angle, radius, TOP_RING)
		-- Place en terre battue devant le bâtiment.
		DecorKit.patch(
			ring,
			polarDeg(angle, radius - (kind == "tower" and 36 or 18)),
			kind == "tower" and 40 or 30,
			TOP_PLAZA,
			rgb(196, 158, 108),
			Enum.Material.Ground,
			rng,
			"terre"
		)
		if kind == "tower" then
			chiefTower(village, cf)
		elseif kind == "box" then
			boxHouse(village, cf, b[4], b[5], rng)
		elseif kind == "round" then
			roundHouse(village, cf, b[4], b[5], b[6], rng)
		elseif kind == "ramen" then
			ramenStand(village, cf)
		end
	end
	local roofs = { RED_ROOF, ORANGE_ROOF, TEAL_ROOF }
	for i, angle in SECOND_ROW do
		local cf = facing(angle + rng:NextNumber(-1.5, 1.5), 289 + rng:NextNumber(-2, 2), TOP_RING)
		if i % 2 == 0 then
			roundHouse(village, cf, rng:NextNumber(13, 17), rng:NextInteger(1, 2), roofs[rng:NextInteger(1, 3)], rng)
		else
			boxHouse(village, cf, Vector3.new(rng:NextNumber(12, 15), rng:NextNumber(11, 16), rng:NextNumber(10, 12)), roofs[rng:NextInteger(1, 3)], rng)
		end
	end
	-- Lanternes de pierre et lanternes de papier le long des routes, près du hub et des bâtiments.
	for _, angle in Layout.PlotAngles do
		local deg = math.deg(angle)
		for _, side in { -1, 1 } do
			for _, radius in { 104, 200, 290 } do
				local offset = math.deg((Layout.PathWidth / 2 + 5) / radius) * side
				WorldBuilder.stoneLantern(ring, polarDeg(deg + offset, radius, TOP_RING))
			end
		end
	end
	-- Terrain d'entraînement (poteaux de bois) et souches.
	local training = polarDeg(180, 140, TOP_RING)
	DecorKit.patch(ring, training, 34, TOP_PLAZA, rgb(196, 158, 108), Enum.Material.Ground, rng, "terre")
	for k = -1, 1 do
		local p = training + Vector3.new(k * 7, 0, rng:NextNumber(-3, 3))
		Build.disc(ring, "TrainingLog", 6, 2, p, rgb(140, 95, 60), { Material = Enum.Material.Wood })
		Build.disc(ring, "Rope", 0.5, 2.15, p + Vector3.new(0, 3.6, 0), rgb(226, 206, 156), { Material = Enum.Material.Fabric })
	end
	-- Arbres, buissons, rochers, touffes et fleurs dans l'anneau.
	DecorKit.scatter(rng, 9, Vector3.zero, 172, 180, function(p)
		return ringFree(p, 14)
	end, function(p)
		DecorKit.giantTree(ring, p + Vector3.new(0, TOP_RING, 0), { rng = rng, height = rng:NextNumber(48, 62) })
	end)
	DecorKit.scatter(rng, 56, Vector3.zero, Layout.RingInner + 10, Layout.RingBuildInner - 8, function(p)
		return ringFree(p, 8)
	end, function(p)
		if rng:NextNumber() < 0.75 then
			DecorKit.roundTree(ring, p + Vector3.new(0, TOP_RING, 0), { rng = rng, height = rng:NextNumber(18, 28), palette = GREEN })
		else
			DecorKit.cherryTree(ring, p + Vector3.new(0, TOP_RING, 0), { rng = rng, height = rng:NextNumber(16, 22) })
		end
	end)
	DecorKit.scatter(rng, 60, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 6, function(p)
		return ringFree(p, 4)
	end, function(p)
		if rng:NextNumber() < 0.7 then
			DecorKit.bush(ring, p + Vector3.new(0, TOP_RING, 0), { rng = rng, height = rng:NextNumber(3, 5) })
		else
			DecorKit.rock(ring, p + Vector3.new(0, TOP_RING, 0), rng:NextNumber(3, 6), { rng = rng })
		end
	end)
	DecorKit.scatter(rng, 24, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 10, function(p)
		return ringFree(p, 6)
	end, function(p)
		DecorKit.patch(ring, p, rng:NextNumber(18, 36), TOP_PLAZA - 0.02, rgb(132, 190, 84), Enum.Material.LeafyGrass, rng, "herbe2")
	end)
	DecorKit.scatter(rng, 420, Vector3.zero, Layout.RingInner + 2, Layout.RingOuter - 2, function(p)
		return ringFree(p, 0)
	end, function(p)
		DecorKit.tuft(ring, p + Vector3.new(0, TOP_RING, 0), rng:NextNumber(1.1, 1.8), rgb(96, 168, 64), rng, "touffe")
	end)
	local flowerColors = { rgb(255, 110, 140), rgb(255, 214, 80), rgb(255, 255, 255) }
	DecorKit.scatter(rng, 90, Vector3.zero, Layout.RingInner + 2, Layout.RingOuter - 2, function(p)
		return ringFree(p, 0)
	end, function(p)
		DecorKit.flower(ring, p + Vector3.new(0, TOP_RING, 0), flowerColors[rng:NextInteger(1, #flowerColors)], rng)
	end)

	-- 2) Grande porte du village sur la route de la base à 270°.
	villageGate(ring, facing(270, Layout.RingFenceRadius + 3, TOP_RING))

	-- 3) Forêt d'arbres géants autour des bases.
	local free = function(p: Vector3, margin: number)
		return WorldBuilder.isFree(p, margin) and not nearMountain(p)
	end
	DecorKit.scatter(rng, 70, Vector3.zero, Layout.WalkwayOuter + 20, Layout.IslandRadius - 14, function(p)
		return free(p, 16)
	end, function(p)
		DecorKit.giantTree(island, p, { rng = rng, height = rng:NextNumber(55, 85) })
	end)
	DecorKit.scatter(rng, 60, Vector3.zero, Layout.WalkwayOuter + 8, Layout.IslandRadius - 10, function(p)
		return free(p, 8)
	end, function(p)
		local roll = rng:NextNumber()
		if roll < 0.6 then
			DecorKit.roundTree(island, p, { rng = rng, height = rng:NextNumber(20, 30), palette = roll < 0.3 and FOREST or GREEN })
		else
			DecorKit.pine(island, p, { rng = rng, height = rng:NextNumber(24, 34) })
		end
	end)
	DecorKit.scatter(rng, 70, Vector3.zero, Layout.WalkwayOuter + 6, Layout.IslandRadius - 8, function(p)
		return free(p, 3)
	end, function(p)
		if rng:NextNumber() < 0.7 then
			DecorKit.bush(island, p, { rng = rng, height = rng:NextNumber(3.5, 6) })
		else
			DecorKit.rock(island, p, rng:NextNumber(4, 9), { rng = rng })
		end
	end)

	-- 4) Montagne des chefs au bord de l'île, derrière la base 270°.
	chiefMountain(horizon, facing(MOUNTAIN_ANGLE, MOUNTAIN_RADIUS), rng)

	-- 5) Couronne de montagnes vertes à l'horizon (dans la mer).
	for i = 0, 23 do
		local angle = i / 24 * 360 + rng:NextNumber(-4, 4)
		local diff = math.abs((angle - MOUNTAIN_ANGLE + 180) % 360 - 180)
		if diff > 28 then
			local radius = rng:NextNumber(Layout.HorizonInner + 60, Layout.HorizonOuter - 60)
			local width = rng:NextNumber(150, 240)
			DecorKit.mountain(horizon, polarDeg(angle, radius, -2), width, rng:NextNumber(90, 170), {
				rng = rng,
				rock = rgb(132, 120, 104),
				grass = rgb(78, 140, 66),
				slot = "MontagneHorizon",
			})
		end
	end

	-- Feuilles qui tombent doucement sur l'anneau.
	local emitterPart = Build.deco(decor, "Ambient", Vector3.new(Layout.RingOuter * 2, 1, Layout.RingOuter * 2), CFrame.new(0, 60, 0), WHITE, { Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rgb(120, 200, 80), rgb(180, 230, 100))
	emitter.LightEmission = 0.3
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.3) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(10, 14)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(3, 5)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = emitterPart
end

return Ninja
