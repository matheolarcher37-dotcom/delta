-- Kit/Archi : briques d'architecture détaillée en TAILLE RÉELLE (perso R6 ≈ 5,3 studs, porte ≈ 8).
--
-- Convention : `cf` est posé AU SOL (ou au niveau indiqué), -Z local = la façade (vers la rue).
--   * socles, murs à colombages (poteaux et poutres apparents), bandeaux d'étage ;
--   * fenêtres encadrées (appui, linteau, croisillons, volets ouverts, vitre allumée la nuit) ;
--   * portes avec encadrement, marche, auvent ou rideau noren ;
--   * toits à deux pans avec débords, chevrons, planches de rive, faîtage et coins relevés ;
--     toits en croupe (pyramide), toits à étages (pagode) ;
--   * balcons à balustres, escaliers, enseignes (horizontales, verticales, suspendues) ;
--   * réservoirs d'eau sur pieds avec tuyaux, climatiseurs, cheminées ;
--   * poteaux électriques et câbles qui pendent, guirlandes de lanternes en papier.

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)

local Archi = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade

Archi.Colors = {
	plaster = rgb(232, 222, 202),
	plasterDark = rgb(204, 190, 166),
	wood = rgb(132, 92, 62),
	woodDark = rgb(78, 54, 40),
	stone = rgb(160, 154, 144),
	stoneDark = rgb(118, 112, 106),
	glass = rgb(64, 84, 104),
	glassLit = rgb(255, 214, 150),
	metal = rgb(150, 152, 156),
	paper = rgb(246, 238, 220),
}
local C = Archi.Colors

-- Bloc dont la base est posée sur `cf` (décalé de `offset` dans le repère de cf).
function Archi.block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return Build.part(parent, name, size, cf * CFrame.new(0, size.Y / 2, 0), color, {
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = collide ~= false,
	})
end

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return Build.deco(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic })
end
Archi.deco = deco

------------------------------------------------------------------------
-- Socle et murs
------------------------------------------------------------------------

-- Socle de pierre (un peu plus large que le bâtiment), avec une arête claire.
function Archi.plinth(parent: Instance, cf: CFrame, w: number, d: number, h: number, color: Color3?, material: Enum.Material?)
	local c = color or C.stone
	Archi.block(parent, "Plinth", Vector3.new(w, h, d), cf, c, material or Enum.Material.Cobblestone)
	deco(parent, "PlinthCap", Vector3.new(w + 0.4, 0.35, d + 0.4), cf * CFrame.new(0, h - 0.1, 0), shade(c, 0.1), Enum.Material.Slate)
end

export type WallOptions = {
	material: Enum.Material?,
	frame: Color3?, -- couleur des poteaux et poutres apparents (colombages)
	spacing: number?, -- distance entre poteaux de façade
	base: Color3?, -- soubassement (bas des murs)
	baseHeight: number?,
	band: Color3?, -- bandeau en haut des murs
}

-- Murs (un bloc plein) avec colombages : poteaux d'angle et de façade, sablière en haut,
-- lisse basse, soubassement facultatif. Les 4 faces sont détaillées.
function Archi.walls(parent: Instance, cf: CFrame, w: number, d: number, h: number, color: Color3, o: WallOptions?): Part
	local opts = o or {}
	local body = Archi.block(parent, "Walls", Vector3.new(w, h, d), cf, color, opts.material or Enum.Material.Plaster)
	if opts.base then
		local bh = opts.baseHeight or 2.4
		Archi.block(parent, "WallBase", Vector3.new(w + 0.3, bh, d + 0.3), cf, opts.base, Enum.Material.WoodPlanks, false)
	end
	if opts.frame then
		local f = opts.frame
		local t = 0.7
		-- poteaux d'angle
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				Archi.block(parent, "Post", Vector3.new(t, h, t), cf * CFrame.new(x * (w / 2 - t / 2 + 0.2), 0, z * (d / 2 - t / 2 + 0.2)), f, Enum.Material.Wood, false)
			end
		end
		-- poteaux intermédiaires sur les 4 faces
		local spacing = opts.spacing or 8
		local function facePosts(len: number, place: (number) -> CFrame)
			local n = math.floor(len / spacing)
			for i = 1, n - 1 do
				local x = -len / 2 + i * len / n
				Archi.block(parent, "Post", Vector3.new(0.5, h, 0.3), place(x), f, Enum.Material.Wood, false)
			end
		end
		facePosts(w, function(x)
			return cf * CFrame.new(x, 0, -d / 2 - 0.12)
		end)
		facePosts(w, function(x)
			return cf * CFrame.new(x, 0, d / 2 + 0.12)
		end)
		facePosts(d, function(z)
			return cf * CFrame.new(-w / 2 - 0.12, 0, z) * CFrame.Angles(0, math.pi / 2, 0)
		end)
		facePosts(d, function(z)
			return cf * CFrame.new(w / 2 + 0.12, 0, z) * CFrame.Angles(0, math.pi / 2, 0)
		end)
		-- sablière (haut) et lisse (bas)
		deco(parent, "Beam", Vector3.new(w + 0.6, 0.8, d + 0.6), cf * CFrame.new(0, h - 0.4, 0), f, Enum.Material.Wood)
		deco(parent, "Sill", Vector3.new(w + 0.5, 0.6, d + 0.5), cf * CFrame.new(0, 0.3, 0), f, Enum.Material.Wood)
	end
	if opts.band then
		deco(parent, "Band", Vector3.new(w + 0.4, 1.2, d + 0.4), cf * CFrame.new(0, h - 1.6, 0), opts.band)
	end
	return body
end

-- Bandeau horizontal autour d'un bloc (séparation d'étages).
function Archi.floorBand(parent: Instance, cf: CFrame, w: number, d: number, y: number, color: Color3, thickness: number?)
	deco(parent, "FloorBand", Vector3.new(w + 0.5, thickness or 0.8, d + 0.5), cf * CFrame.new(0, y, 0), color)
end

------------------------------------------------------------------------
-- Ouvertures
------------------------------------------------------------------------

export type WindowOptions = {
	frame: Color3?,
	glass: Color3?,
	lit: boolean?, -- vitre lumineuse (néon chaud)
	shutters: Color3?, -- volets ouverts
	sill: Color3?,
	bars: boolean?, -- croisillons
	shoji: boolean?, -- panneau de papier à grille (style japonais)
	box: Color3?, -- jardinière sous la fenêtre (couleur des fleurs)
}

-- Fenêtre encadrée. `cf` = centre de la fenêtre SUR la façade, -Z local vers l'extérieur.
function Archi.window(parent: Instance, cf: CFrame, w: number, h: number, o: WindowOptions?)
	local opts = o or {}
	local frame = opts.frame or C.woodDark
	deco(parent, "WindowFrame", Vector3.new(w + 0.7, h + 0.7, 0.3), cf * CFrame.new(0, 0, -0.1), frame, Enum.Material.Wood)
	local glassColor = opts.shoji and C.paper or (opts.lit and C.glassLit or (opts.glass or C.glass))
	local glass = deco(
		parent,
		"Window",
		Vector3.new(w, h, 0.2),
		cf * CFrame.new(0, 0, -0.22),
		glassColor,
		opts.lit and Enum.Material.Neon or (opts.shoji and Enum.Material.Fabric or Enum.Material.Glass)
	)
	if opts.lit then
		glass.Transparency = 0.15
	elseif not opts.shoji then
		glass.Reflectance = 0.12
	end
	if opts.bars or opts.shoji then
		local bar = opts.shoji and shade(frame, 0.2) or frame
		deco(parent, "WindowBar", Vector3.new(0.18, h, 0.1), cf * CFrame.new(0, 0, -0.34), bar, Enum.Material.Wood)
		deco(parent, "WindowBar", Vector3.new(w, 0.18, 0.1), cf * CFrame.new(0, 0, -0.34), bar, Enum.Material.Wood)
		if opts.shoji and w > 3 then
			for _, x in { -w / 4, w / 4 } do
				deco(parent, "WindowBar", Vector3.new(0.14, h, 0.1), cf * CFrame.new(x, 0, -0.34), bar, Enum.Material.Wood)
			end
		end
	end
	local sill = opts.sill or shade(frame, 0.15)
	deco(parent, "WindowSill", Vector3.new(w + 1.2, 0.35, 0.9), cf * CFrame.new(0, -h / 2 - 0.4, -0.35), sill, Enum.Material.Wood)
	deco(parent, "WindowLintel", Vector3.new(w + 1.1, 0.45, 0.6), cf * CFrame.new(0, h / 2 + 0.45, -0.25), sill, Enum.Material.Wood)
	if opts.shutters then
		for _, side in { -1, 1 } do
			local hinge = cf * CFrame.new(side * (w / 2 + 0.35), 0, -0.3)
			deco(
				parent,
				"Shutter",
				Vector3.new(w / 2, h + 0.2, 0.18),
				hinge * CFrame.Angles(0, side * math.rad(-105), 0) * CFrame.new(side * w / 4, 0, 0),
				opts.shutters,
				Enum.Material.WoodPlanks
			)
		end
	end
	if opts.box then
		deco(parent, "FlowerBox", Vector3.new(w + 0.6, 0.8, 0.9), cf * CFrame.new(0, -h / 2 - 1.0, -0.6), C.woodDark, Enum.Material.WoodPlanks)
		for i = -1, 1 do
			Core.ball(parent, "Flower", 0.75, (cf * CFrame.new(i * w * 0.3, -h / 2 - 0.45, -0.6)).Position, i == 0 and opts.box or shade(opts.box, 0.2))
		end
	end
end

-- Rangée de fenêtres sur une façade (centrées, `count` fenêtres sur la largeur `span`).
function Archi.windowRow(parent: Instance, cf: CFrame, span: number, count: number, w: number, h: number, o: WindowOptions?, skip: ((number) -> boolean)?)
	for i = 1, count do
		local x = -span / 2 + (i - 0.5) * span / count
		if not (skip and skip(x)) then
			Archi.window(parent, cf * CFrame.new(x, 0, 0), w, h, o)
		end
	end
end

export type DoorOptions = {
	color: Color3?,
	frame: Color3?,
	awning: Color3?, -- petit auvent incliné
	noren: Color3?, -- rideau de tissu fendu
	norenText: string?,
	step: boolean?,
	lamp: Color3?, -- lanterne à côté de la porte
	sliding: boolean?, -- porte coulissante à grille (japonaise)
}

-- Porte. `cf` = bas de la porte, au milieu, SUR la façade (-Z local vers la rue).
function Archi.door(parent: Instance, cf: CFrame, w: number, h: number, o: DoorOptions?)
	local opts = o or {}
	local frame = opts.frame or C.woodDark
	deco(parent, "DoorFrame", Vector3.new(w + 1, h + 0.6, 0.35), cf * CFrame.new(0, (h + 0.6) / 2, -0.1), frame, Enum.Material.Wood)
	local doorColor = opts.color or C.wood
	if opts.sliding then
		for _, side in { -1, 1 } do
			deco(parent, "Door", Vector3.new(w / 2 - 0.1, h, 0.2), cf * CFrame.new(side * w / 4, h / 2, -0.28), C.paper, Enum.Material.Fabric)
			deco(parent, "DoorBar", Vector3.new(0.16, h, 0.1), cf * CFrame.new(side * w / 4, h / 2, -0.4), doorColor, Enum.Material.Wood)
			for k = 1, 3 do
				deco(parent, "DoorBar", Vector3.new(w / 2 - 0.1, 0.16, 0.1), cf * CFrame.new(side * w / 4, h * k / 4, -0.4), doorColor, Enum.Material.Wood)
			end
		end
	else
		deco(parent, "Door", Vector3.new(w, h, 0.25), cf * CFrame.new(0, h / 2, -0.28), doorColor, Enum.Material.WoodPlanks)
		deco(parent, "DoorKnob", Vector3.new(0.35, 0.35, 0.3), cf * CFrame.new(w * 0.32, h * 0.48, -0.5), rgb(200, 170, 80), Enum.Material.Metal)
	end
	if opts.step ~= false then
		Build.part(parent, "Step", Vector3.new(w + 2, 0.6, 2.2), cf * CFrame.new(0, 0.3, -1.3), C.stone, { Material = Enum.Material.Slate })
	end
	if opts.awning then
		deco(parent, "DoorAwning", Vector3.new(w + 3, 0.4, 3), cf * CFrame.new(0, h + 1.4, -1.4) * CFrame.Angles(math.rad(-16), 0, 0), opts.awning, Enum.Material.ClayRoofTiles)
		for _, side in { -1, 1 } do
			Core.beam(
				parent,
				"Bracket",
				(cf * CFrame.new(side * (w / 2 + 1), h + 0.2, -0.2)).Position,
				(cf * CFrame.new(side * (w / 2 + 1), h + 1.1, -2.4)).Position,
				0.3,
				0.3,
				frame,
				{
					Material = Enum.Material.Wood,
					CanCollide = false,
				}
			)
		end
	end
	if opts.noren then
		Archi.noren(parent, cf * CFrame.new(0, h - 0.2, -0.6), w + 0.6, h * 0.42, opts.noren, opts.norenText)
	end
	if opts.lamp then
		Archi.wallLamp(parent, cf * CFrame.new(w / 2 + 1.4, h * 0.75, -0.3), opts.lamp)
	end
end

-- Rideau noren (panneaux de tissu fendus) suspendu à `cf` (haut, milieu), texte facultatif.
function Archi.noren(parent: Instance, cf: CFrame, w: number, h: number, color: Color3, text: string?)
	deco(parent, "NorenRod", Vector3.new(w + 0.8, 0.25, 0.25), cf, C.woodDark, Enum.Material.Wood)
	local panels = math.max(2, math.floor(w / 2.4 + 0.5))
	local pw = w / panels
	for i = 0, panels - 1 do
		local panel = deco(parent, "Noren", Vector3.new(pw - 0.15, h, 0.12), cf * CFrame.new(-w / 2 + (i + 0.5) * pw, -h / 2 - 0.1, 0), color, Enum.Material.Fabric)
		if text and i == math.floor(panels / 2) then
			Build.surfaceText(panel, Enum.NormalId.Front, text, rgb(255, 250, 240), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		end
	end
end

-- Petite lanterne murale (boîte lumineuse sur potence).
function Archi.wallLamp(parent: Instance, cf: CFrame, color: Color3)
	deco(parent, "LampArm", Vector3.new(0.25, 0.25, 1.2), cf * CFrame.new(0, 0.9, -0.5), C.woodDark, Enum.Material.Metal)
	local lamp = deco(parent, "Lamp", Vector3.new(0.9, 1.2, 0.9), cf * CFrame.new(0, 0.2, -1), color, Enum.Material.Neon)
	deco(parent, "LampCap", Vector3.new(1.2, 0.25, 1.2), cf * CFrame.new(0, 0.9, -1), C.woodDark)
	Core.light(lamp, color, 12, 1)
end

------------------------------------------------------------------------
-- Toits
------------------------------------------------------------------------

export type RoofOptions = {
	material: Enum.Material?,
	ridge: Color3?, -- faîtage
	trim: Color3?, -- planches de rive et bord de toit
	rafters: Color3?, -- chevrons visibles sous le débord
	upturn: boolean?, -- coins relevés (toit asiatique)
	gableFill: Color3?, -- pignon (triangle de mur)
	thickness: number?,
}

-- Toit à deux pans. `cf` = centre du bâtiment au niveau de l'égout (haut des murs), faîtage selon X.
-- `w` x `d` = emprise des murs ; `over` = débord ; `rise` = hauteur du faîtage.
function Archi.gableRoof(parent: Instance, cf: CFrame, w: number, d: number, rise: number, over: number, color: Color3, o: RoofOptions?)
	local opts = o or {}
	local material = opts.material or Enum.Material.ClayRoofTiles
	local half = d / 2 + over
	local thick = opts.thickness or 0.8
	-- pignons (triangles de mur sous le toit)
	if opts.gableFill then
		for _, side in { -1, 1 } do
			Build.wedge(parent, "Gable", Vector3.new(0.6, rise, d / 2), cf * CFrame.new(side * (w / 2 - 0.3), rise / 2, d / 4) * CFrame.Angles(0, math.pi, 0), opts.gableFill, {
				Material = Enum.Material.Plaster,
			})
			Build.wedge(
				parent,
				"Gable",
				Vector3.new(0.6, rise, d / 2),
				cf * CFrame.new(side * (w / 2 - 0.3), rise / 2, -d / 4),
				opts.gableFill,
				{ Material = Enum.Material.Plaster }
			)
		end
	end
	-- pans : un coin (wedge) plein par côté + une plaque de couverture qui déborde
	local slope = math.atan2(rise, half)
	local slant = math.sqrt(rise * rise + half * half)
	for _, side in { -1, 1 } do
		local panelCF = cf * CFrame.new(0, rise / 2 - thick * 0.2, side * half / 2) * CFrame.Angles(side * slope, 0, 0)
		Build.part(parent, "Roof", Vector3.new(w + over * 2, thick, slant + 0.4), panelCF, color, { Material = material })
		-- bord épais (planche de rive) en bas du pan
		local eave = cf * CFrame.new(0, -thick * 0.35, side * (half - 0.15))
		deco(parent, "Eave", Vector3.new(w + over * 2 + 0.2, thick * 0.9, 0.5), eave, opts.trim or shade(color, -0.25), Enum.Material.Wood)
		if opts.rafters then
			local count = math.max(3, math.floor((w + over * 2) / 2.4))
			for i = 0, count do
				local x = -(w / 2 + over) + i * (w + over * 2) / count
				local a = (cf * CFrame.new(x, -thick * 0.6, side * (d / 2 - 0.2))).Position
				local b = (cf * CFrame.new(x, -thick * 0.6 - over * math.tan(slope) * 0.2, side * (half - 0.5))).Position
				Core.beam(parent, "Rafter", a, b, 0.35, 0.45, opts.rafters, { Material = Enum.Material.Wood, CanCollide = false })
			end
		end
		if opts.upturn then
			for _, x in { -1, 1 } do
				local tip = cf * CFrame.new(x * (w / 2 + over - 0.6), 0.2, side * (half - 0.6))
				Build.wedge(
					parent,
					"RoofTip",
					Vector3.new(1.4, 1.6, 2.4),
					tip * CFrame.Angles(0, (side > 0) and math.pi or 0, 0) * CFrame.Angles(0, x * math.rad(-30), 0),
					opts.trim or shade(color, -0.2),
					{
						Material = material,
						CanCollide = false,
					}
				)
			end
		end
	end
	-- faîtage
	local ridge = opts.ridge or shade(color, -0.3)
	deco(parent, "Ridge", Vector3.new(w + over * 2 + 0.8, 1, 1.4), cf * CFrame.new(0, rise + thick * 0.3, 0), ridge, Enum.Material.Slate)
	if opts.upturn then
		for _, x in { -1, 1 } do
			deco(
				parent,
				"RidgeEnd",
				Vector3.new(1.2, 1.8, 1.8),
				cf * CFrame.new(x * (w / 2 + over + 0.6), rise + 0.8, 0) * CFrame.Angles(0, 0, x * math.rad(-20)),
				ridge,
				Enum.Material.Slate
			)
		end
	end
	-- planches de rive sur les pignons
	if opts.trim then
		for _, x in { -1, 1 } do
			for _, side in { -1, 1 } do
				local a = (cf * CFrame.new(x * (w / 2 + over), 0, side * half)).Position
				local b = (cf * CFrame.new(x * (w / 2 + over), rise + 0.3, 0)).Position
				Core.beam(parent, "Barge", a, b, 0.4, 1, opts.trim, { Material = Enum.Material.Wood, CanCollide = false })
			end
		end
	end
end

-- Toit en croupe (pyramide) avec une dalle de débord dessous. `cf` = centre au niveau de l'égout.
function Archi.hipRoof(parent: Instance, cf: CFrame, w: number, d: number, rise: number, over: number, color: Color3, o: RoofOptions?)
	local opts = o or {}
	local material = opts.material or Enum.Material.ClayRoofTiles
	deco(parent, "RoofSlab", Vector3.new(w + over * 2, 0.7, d + over * 2), cf * CFrame.new(0, 0, 0), opts.trim or shade(color, -0.25), Enum.Material.Wood)
	for _, part in Core.pyramid(parent, "Roof", cf * CFrame.new(0, 0.3, 0), w + over * 2 - 0.2, d + over * 2 - 0.2, rise, color, material) do
		part.CanCollide = true
	end
	if opts.ridge then
		Core.ball(parent, "RoofFinial", 1.2, (cf * CFrame.new(0, rise + 0.6, 0)).Position, opts.ridge, Enum.Material.Metal)
	end
	if opts.rafters then
		local n = math.max(3, math.floor(w / 2.6))
		for _, side in { -1, 1 } do
			for i = 0, n do
				local x = -w / 2 + i * w / n
				deco(parent, "Rafter", Vector3.new(0.35, 0.4, over), cf * CFrame.new(x, -0.5, side * (d / 2 + over / 2)), opts.rafters, Enum.Material.Wood)
			end
		end
	end
end

-- Toit à étages façon pagode : plusieurs croupes de plus en plus petites.
function Archi.tieredRoof(parent: Instance, cf: CFrame, w: number, d: number, tiers: number, tierH: number, color: Color3, o: RoofOptions?)
	for i = 0, tiers - 1 do
		local k = 1 - i * 0.22
		local y = i * tierH
		if i > 0 then
			Archi.block(
				parent,
				"TierWall",
				Vector3.new(w * k * 0.7, tierH * 0.55, d * k * 0.7),
				cf * CFrame.new(0, y - tierH * 0.45, 0),
				Archi.Colors.plaster,
				Enum.Material.Plaster,
				false
			)
		end
		Archi.hipRoof(parent, cf * CFrame.new(0, y, 0), w * k, d * k, tierH * 0.6, 2.4, color, o)
	end
end

------------------------------------------------------------------------
-- Balcons, escaliers, enseignes
------------------------------------------------------------------------

-- Balcon : plancher, poteaux et balustres, main courante, consoles. `cf` = milieu du bord du mur,
-- au niveau du plancher, -Z local vers l'extérieur.
function Archi.balcony(parent: Instance, cf: CFrame, w: number, depth: number, color: Color3?)
	local c = color or C.woodDark
	Build.part(parent, "BalconyFloor", Vector3.new(w, 0.5, depth), cf * CFrame.new(0, -0.25, -depth / 2), c, { Material = Enum.Material.WoodPlanks })
	deco(parent, "Rail", Vector3.new(w, 0.35, 0.4), cf * CFrame.new(0, 3, -depth + 0.2), shade(c, 0.1), Enum.Material.Wood)
	local posts = math.max(3, math.floor(w / 1.3))
	for i = 0, posts do
		local x = -w / 2 + i * w / posts
		local main = i == 0 or i == posts
		deco(parent, main and "RailPost" or "Baluster", Vector3.new(main and 0.45 or 0.22, 3, main and 0.45 or 0.22), cf * CFrame.new(x, 1.5, -depth + 0.2), c, Enum.Material.Wood)
	end
	for _, x in { -1, 1 } do
		deco(parent, "RailSide", Vector3.new(0.35, 0.35, depth), cf * CFrame.new(x * w / 2, 3, -depth / 2), shade(c, 0.1), Enum.Material.Wood)
		Core.beam(parent, "Bracket", (cf * CFrame.new(x * (w / 2 - 0.5), -2.4, 0)).Position, (cf * CFrame.new(x * (w / 2 - 0.5), -0.4, -depth + 0.4)).Position, 0.35, 0.35, c, {
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
end

-- Escalier droit : `cf` = centre de l'emprise au sol ; la première marche est à l'avant (-Z local)
-- et l'escalier monte vers l'arrière (+Z local) jusqu'à la hauteur `rise`.
function Archi.stairs(parent: Instance, cf: CFrame, w: number, rise: number, run: number, steps: number, color: Color3?, material: Enum.Material?)
	local c = color or C.stone
	local stepH = rise / steps
	local stepD = run / steps
	for i = 0, steps - 1 do
		Build.part(parent, "Step", Vector3.new(w, stepH * (i + 1), stepD), cf * CFrame.new(0, stepH * (i + 1) / 2, -run / 2 + (i + 0.5) * stepD), shade(c, (i % 2) * 0.04), {
			Material = material or Enum.Material.Slate,
		})
	end
end

export type SignOptions = {
	bg: Color3?,
	frame: Color3?,
	text: Color3?,
	font: Enum.Font?,
	both: boolean?, -- texte des deux côtés
	posts: number?, -- hauteur des pieds (enseigne sur pieds)
	hanging: boolean?, -- suspendue à une potence
}

-- Police des enseignes peintes à la main (lettres calligraphiées, pas la police arrondie générique).
Archi.SignFont = Enum.Font.Fondamento
Archi.SignPaint = rgb(238, 224, 192)
Archi.SignInk = rgb(40, 26, 18)

-- Retire un pictogramme (émoji) en tête de texte : « 🤝 COIN » -> « COIN ». Les enseignes
-- portent un motif peint à la place. Les kanji (sans espace après) sont gardés.
function Archi.stripIcon(text: string): string
	local first, rest = string.match(text, "^(%S+)%s+(.+)$")
	if first and rest and #first <= 8 and not string.find(first, "[%w]") then
		local ok, cp = pcall(utf8.codepoint, first, 1)
		if ok and cp >= 0x2190 and not (cp >= 0x3000 and cp <= 0x9FFF) then
			return rest
		end
	end
	return text
end

-- Met une majuscule seulement à la première lettre (« FAIRE ÉVOLUER » -> « Faire évoluer »), pour
-- des lettres peintes plus naturelles. Gère les capitales accentuées courantes.
local ACCENTS = { ["É"] = "é", ["È"] = "è", ["Ê"] = "ê", ["À"] = "à", ["Â"] = "â", ["Ô"] = "ô", ["Î"] = "î", ["Ç"] = "ç", ["Û"] = "û" }
function Archi.titleCase(text: string): string
	local lower = string.lower(text)
	for upper, small in ACCENTS do
		lower = string.gsub(lower, upper, small)
	end
	local head = string.sub(lower, 1, 1)
	if string.match(head, "%a") then
		return string.upper(head) .. string.sub(lower, 2)
	end
	return lower
end

-- Ferrures d'angle (équerres de fer et clous) sur un panneau de `w` x `h` (face -Z de `cf`).
local function cornerIrons(parent: Instance, cf: CFrame, w: number, h: number, z: number)
	local iron = rgb(58, 54, 52)
	local s = math.clamp(math.min(w, h) * 0.16, 0.45, 1.3)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			local corner = cf * CFrame.new(x * (w / 2 - s / 2), y * (h / 2 - s / 2), z)
			deco(parent, "Ferrure", Vector3.new(s, s * 0.32, 0.08), corner * CFrame.new(0, y * s * 0.34, 0), iron, Enum.Material.Metal)
			deco(parent, "Ferrure", Vector3.new(s * 0.32, s, 0.08), corner * CFrame.new(x * s * 0.34, 0, 0), iron, Enum.Material.Metal)
			deco(parent, "Clou", Vector3.new(s * 0.16, s * 0.16, 0.12), corner * CFrame.new(x * s * 0.3, y * s * 0.3, -0.04), shade(iron, 0.25), Enum.Material.Metal)
		end
	end
end

-- Texte peint sur une plaque invisible juste devant `cf` (face -Z, ou +Z si `back`).
local function paint(parent: Instance, cf: CFrame, w: number, h: number, text: string, color: Color3, font: Enum.Font?, back: boolean?): Part
	local plaque = Build.deco(parent, "Peinture", Vector3.new(w, h, 0.05), cf, rgb(255, 255, 255), { Transparency = 1, CastShadow = false })
	plaque.CanQuery = false
	Build.surfaceText(plaque, back and Enum.NormalId.Back or Enum.NormalId.Front, text, color, {
		TextStrokeTransparency = 0.72,
		TextStrokeColor3 = Archi.SignInk,
		Font = font or Archi.SignFont,
		TextTransparency = 0.04,
	})
	return plaque
end
Archi.paint = paint

-- Enseigne avec texte. `cf` = centre du panneau, -Z local = face lisible. Planche de bois aux
-- lattes visibles, cadre, ferrures d'angle et lettres peintes (police calligraphiée).
function Archi.sign(parent: Instance, cf: CFrame, w: number, h: number, text: string, o: SignOptions?): Part
	local opts = o or {}
	local frame = opts.frame or C.woodDark
	text = Archi.stripIcon(text)
	deco(parent, "SignFrame", Vector3.new(w + 0.6, h + 0.6, 0.4), cf * CFrame.new(0, 0, 0.1), frame, Enum.Material.Wood)
	local bg = opts.bg or rgb(54, 40, 32)
	local panel = Build.part(parent, "Sign", Vector3.new(w, h, 0.5), cf, bg, { Material = Enum.Material.WoodPlanks, CanCollide = false })
	-- joints des lattes (le bois n'est pas une plaque lisse)
	local slats = math.clamp(math.floor(h / 1.1), 1, 4)
	for k = 1, slats - 1 do
		local y = -h / 2 + k * h / slats
		deco(parent, "Latte", Vector3.new(w, 0.08, 0.06), cf * CFrame.new(0, y, -0.26), shade(bg, -0.3), Enum.Material.Wood)
		if opts.both then
			deco(parent, "Latte", Vector3.new(w, 0.08, 0.06), cf * CFrame.new(0, y, 0.26), shade(bg, -0.3), Enum.Material.Wood)
		end
	end
	if w > 3 and h > 1.4 then
		cornerIrons(parent, cf, w, h, -0.29)
	end
	local color = opts.text or rgb(255, 232, 170)
	local font = opts.font or Archi.SignFont
	Build.surfaceText(panel, Enum.NormalId.Front, text, color, { TextStrokeTransparency = 0.72, TextStrokeColor3 = Archi.SignInk, Font = font })
	if opts.both then
		Build.surfaceText(panel, Enum.NormalId.Back, text, color, { TextStrokeTransparency = 0.72, TextStrokeColor3 = Archi.SignInk, Font = font })
	end
	if opts.posts then
		for _, x in { -1, 1 } do
			Build.part(
				parent,
				"SignPost",
				Vector3.new(0.6, opts.posts, 0.6),
				cf * CFrame.new(x * (w / 2 - 0.3), -h / 2 - opts.posts / 2, 0.1),
				frame,
				{ Material = Enum.Material.Wood }
			)
		end
	end
	if opts.hanging then
		deco(parent, "SignArm", Vector3.new(0.3, 0.3, w * 0.25 + 1.5), cf * CFrame.new(0, h / 2 + 0.9, 0), frame, Enum.Material.Metal)
		for _, x in { -1, 1 } do
			deco(parent, "SignChain", Vector3.new(0.1, 0.9, 0.1), cf * CFrame.new(x * w * 0.35, h / 2 + 0.45, 0), C.metal, Enum.Material.Metal)
		end
	end
	return panel
end

-- Chaîne de maillons (alternés à 90°) de `a` à `b`.
function Archi.chain(parent: Instance, a: Vector3, b: Vector3, link: number?)
	local size = link or 0.5
	local delta = b - a
	local count = math.max(1, math.floor(delta.Magnitude / (size * 0.8)))
	local iron = rgb(62, 58, 56)
	for i = 0, count - 1 do
		local p = a + delta * ((i + 0.5) / count)
		local cf = CFrame.lookAt(p, p + delta.Unit) * CFrame.Angles(0, 0, (i % 2) * math.pi / 2)
		deco(parent, "Maillon", Vector3.new(size * 0.55, size * 0.14, size), cf, iron, Enum.Material.Metal)
	end
end

export type CarvedSignOptions = {
	motif: string?, -- kanji peint dans un médaillon de chaque côté du texte
	accent: Color3?, -- couleur (sourde) du médaillon
	wood: Color3?,
	paint: Color3?,
	chains: number?, -- longueur des chaînes (enseigne suspendue), sinon accrochée à plat
	back: boolean?, -- peinte des deux côtés
	lantern: Color3?, -- petite lanterne accrochée sous un coin
}

-- Enseigne ARTISANALE : planche de bois vieillie (lattes de tons différents, nœuds), cadre en
-- relief avec filet clair, ferrures d'angle, lettres peintes (police calligraphiée) avec un petit
-- médaillon peint (kanji) de chaque côté, suspendue par deux chaînes à des crochets.
-- `cf` = centre du panneau, -Z local = face lisible. Renvoie la première latte.
function Archi.carvedSign(parent: Instance, cf: CFrame, w: number, h: number, text: string, o: CarvedSignOptions?): Part
	local opts = o or {}
	local wood = opts.wood or rgb(122, 86, 58)
	local dark = shade(wood, -0.42)
	local rng = Random.new(#text * 31 + math.floor(w * 7))
	text = Archi.stripIcon(text)
	-- lattes horizontales de tons différents, légèrement décalées
	local slats = math.clamp(math.floor(h / 1.2), 2, 4)
	local board: Part? = nil
	for k = 0, slats - 1 do
		local sh = h / slats
		local y = -h / 2 + (k + 0.5) * sh
		local slat = Build.part(
			parent,
			k == 0 and "Sign" or "SignLatte",
			Vector3.new(w + rng:NextNumber(-0.15, 0.15), sh - 0.06, 0.45),
			cf * CFrame.new(rng:NextNumber(-0.06, 0.06), y, rng:NextNumber(-0.03, 0.03)) * CFrame.Angles(0, 0, rng:NextNumber(-0.006, 0.006)),
			shade(wood, rng:NextNumber(-0.1, 0.06)),
			{ Material = Enum.Material.WoodPlanks, CanCollide = false }
		)
		board = board or slat
	end
	-- nœuds du bois
	for _ = 1, math.floor(w / 3) do
		local knot = Core.ellipsoid(
			parent,
			"Noeud",
			Vector3.new(rng:NextNumber(0.3, 0.6), rng:NextNumber(0.18, 0.3), 0.06),
			cf * CFrame.new(rng:NextNumber(-w / 2 + 1, w / 2 - 1), rng:NextNumber(-h / 2 + 0.4, h / 2 - 0.4), -0.24),
			dark,
			Enum.Material.Wood
		)
		knot.CastShadow = false
	end
	-- cadre en relief (quatre baguettes) et filet clair à l'intérieur
	local t = math.clamp(h * 0.11, 0.28, 0.6)
	for _, y in { -1, 1 } do
		deco(parent, "Cadre", Vector3.new(w + t * 2, t, 0.7), cf * CFrame.new(0, y * (h / 2 + t / 2), -0.05), dark, Enum.Material.Wood)
		deco(parent, "Filet", Vector3.new(w - 0.2, 0.09, 0.08), cf * CFrame.new(0, y * (h / 2 - 0.22), -0.25), shade(wood, 0.25), Enum.Material.Wood)
	end
	for _, x in { -1, 1 } do
		deco(parent, "Cadre", Vector3.new(t, h, 0.7), cf * CFrame.new(x * (w / 2 + t / 2), 0, -0.05), dark, Enum.Material.Wood)
	end
	cornerIrons(parent, cf, w + t * 2, h + t * 2, -0.42)
	-- médaillons peints (kanji) et texte
	local paintColor = opts.paint or Archi.SignPaint
	local motifW = 0
	if opts.motif then
		local d = h * 0.74
		motifW = d + 0.5
		local accent = Core.mute(opts.accent or rgb(150, 60, 40), 0.35):Lerp(dark, 0.25)
		for _, x in { -1, 1 } do
			local mcf = cf * CFrame.new(x * (w / 2 - d / 2 - 0.35), 0, -0.25)
			local ring = Build.deco(parent, "MedaillonBord", Vector3.new(0.04, d + 0.18, d + 0.18), mcf * CFrame.Angles(0, math.pi / 2, 0), paintColor, {
				Material = Enum.Material.Wood,
				CastShadow = false,
			})
			ring.Shape = Enum.PartType.Cylinder
			local disc = Build.deco(parent, "Medaillon", Vector3.new(0.06, d, d), mcf * CFrame.new(0, 0, -0.02) * CFrame.Angles(0, math.pi / 2, 0), accent, {
				Material = Enum.Material.Wood,
				CastShadow = false,
			})
			disc.Shape = Enum.PartType.Cylinder
			paint(parent, mcf * CFrame.new(0, 0, -0.08), d * 0.8, d * 0.8, opts.motif, paintColor, Enum.Font.Fondamento)
		end
	end
	paint(parent, cf * CFrame.new(0, -h * 0.02, -0.26), w - motifW * 2 - 0.4, h * 0.78, text, paintColor)
	if opts.back then
		paint(parent, cf * CFrame.new(0, -h * 0.02, 0.26), w - 0.8, h * 0.78, text, paintColor, nil, true)
	end
	-- suspension : pitons sur la planche, chaînes jusqu'aux crochets du dessus
	if opts.chains then
		local rot = cf - cf.Position
		for _, x in { -1, 1 } do
			local eye = (cf * CFrame.new(x * (w / 2 - w * 0.12), h / 2 + t + 0.2, 0)).Position
			local hook = eye + cf.UpVector * opts.chains
			deco(parent, "Piton", Vector3.new(0.18, 0.5, 0.18), CFrame.new(eye) * rot, rgb(62, 58, 56), Enum.Material.Metal)
			Archi.chain(parent, eye + cf.UpVector * 0.2, hook, 0.5)
			deco(parent, "Crochet", Vector3.new(0.5, 0.25, 0.5), CFrame.new(hook) * rot, rgb(62, 58, 56), Enum.Material.Metal)
		end
	end
	if opts.lantern then
		local pos = (cf * CFrame.new(w / 2 + t + 0.6, -h / 2 - 0.4, 0)).Position
		deco(parent, "LanterneAttache", Vector3.new(0.1, 1.2, 0.1), CFrame.new(pos + Vector3.new(0, 0.6, 0)), rgb(62, 58, 56), Enum.Material.Metal)
		local glow = Core.ellipsoid(parent, "Lanterne", Vector3.new(1.1, 1.5, 1.1), CFrame.new(pos - Vector3.new(0, 0.5, 0)), opts.lantern, Enum.Material.Neon)
		glow.Transparency = 0.15
		deco(parent, "LanterneChapeau", Vector3.new(1.2, 0.25, 1.2), CFrame.new(pos + Vector3.new(0, 0.3, 0)), rgb(40, 32, 28), Enum.Material.Wood)
		Core.light(glow, opts.lantern, 10, 0.9)
	end
	return board :: Part
end

-- Enseigne verticale japonaise (kanban) fixée au mur. `cf` = centre, -Z local vers la rue.
function Archi.verticalSign(parent: Instance, cf: CFrame, h: number, text: string, bg: Color3, fg: Color3?)
	local panel = Build.part(parent, "VSign", Vector3.new(1.8, h, 0.4), cf * CFrame.Angles(0, math.pi / 2, 0), bg, { CanCollide = false })
	Build.surfaceText(panel, Enum.NormalId.Front, text, fg or rgb(255, 245, 225), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	Build.surfaceText(panel, Enum.NormalId.Back, text, fg or rgb(255, 245, 225), { TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
	deco(parent, "VSignCap", Vector3.new(2.2, 0.4, 0.6), cf * CFrame.new(0, h / 2 + 0.2, 0) * CFrame.Angles(0, math.pi / 2, 0), C.woodDark, Enum.Material.Wood)
	deco(parent, "VSignArm", Vector3.new(0.3, 0.3, 1.2), cf * CFrame.new(0, h / 2 - 0.4, 0.8), C.woodDark, Enum.Material.Metal)
	return panel
end

------------------------------------------------------------------------
-- Équipements de toit et de rue
------------------------------------------------------------------------

-- Tuyau passant par une suite de points (coudes arrondis).
function Archi.pipe(parent: Instance, points: { Vector3 }, d: number, color: Color3?)
	local c = color or C.metal
	for i = 1, #points - 1 do
		Core.cylinder(parent, "Pipe", points[i], points[i + 1], d, c, { Material = Enum.Material.Metal, CanCollide = false })
		if i > 1 then
			Core.ball(parent, "PipeElbow", d * 1.15, points[i], c, Enum.Material.Metal)
		end
	end
end

-- Réservoir d'eau sur pieds avec croisillons, échelle et tuyau qui descend dans le toit.
-- `cf` = pied du réservoir (sur le toit).
function Archi.waterTank(parent: Instance, cf: CFrame, scale: number?, tankColor: Color3?, band: Color3?)
	local s = scale or 1
	local legH = 4 * s
	local r = 2.6 * s
	local wood = C.woodDark
	for _, off in { Vector3.new(r, 0, r), Vector3.new(-r, 0, r), Vector3.new(r, 0, -r), Vector3.new(-r, 0, -r) } do
		Archi.block(parent, "TankLeg", Vector3.new(0.5 * s, legH, 0.5 * s), cf * CFrame.new(off), wood, Enum.Material.Wood, false)
	end
	for _, side in { -1, 1 } do
		Core.beam(parent, "TankBrace", (cf * CFrame.new(-r, 0.4, side * r)).Position, (cf * CFrame.new(r, legH - 0.4, side * r)).Position, 0.25 * s, 0.25 * s, wood, {
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
	deco(parent, "TankFloor", Vector3.new(r * 2 + 1, 0.4 * s, r * 2 + 1), cf * CFrame.new(0, legH, 0), wood, Enum.Material.WoodPlanks)
	local body = tankColor or rgb(226, 218, 200)
	Core.vcyl(parent, "Tank", cf * CFrame.new(0, legH + 0.2 * s, 0), 5.2 * s, 6.4 * s, body, Enum.Material.Metal, false)
	Core.vcyl(parent, "TankBand", cf * CFrame.new(0, legH + 1.2 * s, 0), 0.5 * s, 6.6 * s, band or rgb(180, 66, 50), Enum.Material.Metal, false)
	Core.vcyl(parent, "TankBand", cf * CFrame.new(0, legH + 3.9 * s, 0), 0.5 * s, 6.6 * s, band or rgb(180, 66, 50), Enum.Material.Metal, false)
	for _, part in Core.pyramid(parent, "TankRoof", cf * CFrame.new(0, legH + 5.4 * s, 0), 6.6 * s, 6.6 * s, 1.8 * s, band or rgb(180, 66, 50), Enum.Material.Metal) do
		part.CanCollide = false
	end
	-- échelle
	for _, x in { -0.5, 0.5 } do
		deco(parent, "Ladder", Vector3.new(0.18, legH + 5 * s, 0.18), cf * CFrame.new(x * s, (legH + 5 * s) / 2, -3.35 * s), C.metal, Enum.Material.Metal)
	end
	for k = 1, 6 do
		deco(parent, "LadderRung", Vector3.new(1 * s, 0.14, 0.14), cf * CFrame.new(0, k * (legH + 5 * s) / 7, -3.35 * s), C.metal, Enum.Material.Metal)
	end
	-- tuyau
	local p0 = (cf * CFrame.new(2.2 * s, legH + 0.6 * s, 2.2 * s)).Position
	Archi.pipe(parent, { p0, p0 - UP * (legH - 0.4), p0 - UP * (legH - 0.4) + (cf.RightVector * 2) }, 0.5 * s)
end

-- Climatiseur (boîtier, grille ronde du ventilateur, console). `cf` = contre le mur, -Z vers dehors.
function Archi.acUnit(parent: Instance, cf: CFrame)
	deco(parent, "AC", Vector3.new(3, 2.2, 1.4), cf * CFrame.new(0, 0, -0.7), rgb(222, 222, 216), Enum.Material.Metal)
	local fan = deco(parent, "ACFan", Vector3.new(0.12, 1.7, 1.7), cf * CFrame.new(0.5, 0, -1.42) * CFrame.Angles(0, math.rad(90), 0), rgb(70, 72, 78), Enum.Material.DiamondPlate)
	fan.Shape = Enum.PartType.Cylinder
	deco(parent, "ACGrill", Vector3.new(0.7, 1.6, 0.1), cf * CFrame.new(-0.9, 0, -1.42), rgb(180, 180, 176), Enum.Material.DiamondPlate)
	deco(parent, "ACBracket", Vector3.new(3.2, 0.25, 1.6), cf * CFrame.new(0, -1.2, -0.8), C.metal, Enum.Material.Metal)
	Archi.pipe(
		parent,
		{ (cf * CFrame.new(1.6, 0.6, -0.4)).Position, (cf * CFrame.new(2.2, 0.6, -0.15)).Position, (cf * CFrame.new(2.2, -4, -0.15)).Position },
		0.22,
		rgb(236, 236, 230)
	)
end

-- Cheminée de brique avec chapeau.
function Archi.chimney(parent: Instance, cf: CFrame, h: number, color: Color3?)
	Archi.block(parent, "Chimney", Vector3.new(2, h, 2), cf, color or rgb(150, 90, 70), Enum.Material.Brick, false)
	deco(parent, "ChimneyCap", Vector3.new(2.6, 0.4, 2.6), cf * CFrame.new(0, h + 0.2, 0), C.stoneDark, Enum.Material.Slate)
end

-- Câble qui pend entre deux points (chaînette approchée en `segments` morceaux).
function Archi.cable(parent: Instance, a: Vector3, b: Vector3, sag: number, d: number?, color: Color3?)
	local segments = 5
	local prev = a
	for i = 1, segments do
		local t = i / segments
		local p = a:Lerp(b, t) - UP * (4 * sag * t * (1 - t))
		Core.cylinder(parent, "Cable", prev, p, d or 0.15, color or rgb(36, 34, 34), { CanCollide = false, CastShadow = false })
		prev = p
	end
end

-- Poteau électrique en bois : traverse, isolateurs, transformateur facultatif. Renvoie les deux
-- points d'attache des câbles.
function Archi.pole(parent: Instance, base: Vector3, h: number, yaw: number?, transformer: boolean?): (Vector3, Vector3)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0)
	Core.vcyl(parent, "Pole", cf * CFrame.new(0, -0.5, 0), h + 0.5, 1, rgb(110, 88, 66), Enum.Material.Wood)
	deco(parent, "CrossArm", Vector3.new(6, 0.5, 0.5), cf * CFrame.new(0, h - 1.2, 0), rgb(96, 76, 58), Enum.Material.Wood)
	local left = (cf * CFrame.new(-2.6, h - 0.6, 0)).Position
	local right = (cf * CFrame.new(2.6, h - 0.6, 0)).Position
	for _, p in { left, right } do
		deco(parent, "Insulator", Vector3.new(0.4, 0.7, 0.4), CFrame.new(p), rgb(230, 230, 236), Enum.Material.Glass)
	end
	if transformer then
		Core.vcyl(parent, "Transformer", cf * CFrame.new(0, h - 5, -0.9), 2.4, 1.6, rgb(120, 124, 130), Enum.Material.Metal, false)
	end
	return left, right
end

-- Guirlande de lanternes en papier sur une corde entre `a` et `b` (une lumière sur trois).
function Archi.lanternString(parent: Instance, a: Vector3, b: Vector3, count: number, colors: { Color3 }, sag: number?)
	local s = sag or 1.5
	Archi.cable(parent, a, b, s, 0.12, rgb(70, 50, 40))
	for i = 1, count do
		local t = i / (count + 1)
		local p = a:Lerp(b, t) - UP * (4 * s * t * (1 - t)) - UP * 1.3
		local color = colors[(i - 1) % #colors + 1]
		local lamp = Core.ellipsoid(parent, "PaperLantern", Vector3.new(1.3, 1.7, 1.3), CFrame.new(p), color, Enum.Material.Neon)
		lamp.Transparency = 0.08
		deco(parent, "LanternCap", Vector3.new(0.8, 0.2, 0.8), CFrame.new(p + UP * 0.85), rgb(40, 30, 30))
		deco(parent, "LanternCap", Vector3.new(0.8, 0.2, 0.8), CFrame.new(p - UP * 0.85), rgb(40, 30, 30))
		if i % 3 == 2 then
			Core.light(lamp, color, 14, 0.9)
		end
	end
end

-- Corde à linge avec quelques vêtements qui sèchent.
function Archi.laundry(parent: Instance, a: Vector3, b: Vector3, rng: Random)
	Archi.cable(parent, a, b, 0.8, 0.1, rgb(220, 214, 200))
	local colors = { rgb(240, 240, 236), rgb(90, 130, 200), rgb(220, 110, 90), rgb(250, 210, 90), rgb(120, 170, 110) }
	local n = math.max(2, math.floor((b - a).Magnitude / 3))
	for i = 1, n do
		local t = i / (n + 1)
		local p = a:Lerp(b, t) - UP * (3.2 * t * (1 - t)) - UP * 0.9
		local cf = CFrame.lookAt(p, p + (b - a).Unit:Cross(UP))
		deco(parent, "Cloth", Vector3.new(rng:NextNumber(1.2, 2), rng:NextNumber(1.4, 2.2), 0.1), cf, colors[rng:NextInteger(1, #colors)], Enum.Material.Fabric)
	end
end

return Archi
