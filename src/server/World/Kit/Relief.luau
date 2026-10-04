-- Kit/Relief : le sol travaillé de la carte.
--   * rues pavées avec bordures et caniveaux ;
--   * murets de pierres variées, clôtures (bois, piquets, bambou, corde) ;
--   * eau : étangs aux berges de pierres, ruisseaux qui serpentent, pas japonais ;
--   * ponts : pont arqué laqué (taiko-bashi), pont de planches à cordes.
-- Les pièces du sol peuvent recevoir un rôle (Core.solRole) pour suivre l'univers affiché :
-- "pave", "bordure", "eau", "lit" (fond de l'eau), "berge"...

local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Core)

local Relief = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function role(part: BasePart, name: string?, nuance: number?)
	if name then
		Core.solRole(part, name, nuance)
	end
	return part
end

------------------------------------------------------------------------
-- Rues pavées
------------------------------------------------------------------------

export type RoadOptions = {
	color: Color3?,
	curb: Color3?,
	material: Enum.Material?,
	role: string?, -- rôle du pavage (défaut "pave")
	curbRole: string?, -- rôle des bordures (défaut "bordure")
	curbs: boolean?,
	segment: number?, -- longueur des blocs de bordure
	rng: Random?,
}

-- Rue pavée de `a` à `b` (au sol), largeur `width`, dessus à `top`.
function Relief.road(parent: Instance, a: Vector3, b: Vector3, width: number, top: number, o: RoadOptions?)
	local opts = o or {}
	local rng = opts.rng or Random.new(7)
	local delta = flat(b - a)
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local right = dir:Cross(UP)
	local mid = flat(a + b) / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	local main = Build.part(parent, "Road", Vector3.new(width, 0.6, length), cf + Vector3.new(0, top - 0.3, 0), opts.color or rgb(170, 160, 146), {
		Material = opts.material or Enum.Material.Cobblestone,
		CastShadow = false,
	})
	role(main, opts.role or "pave")
	-- pavés plus clairs / plus foncés au milieu (rapiéçages)
	local patches = math.floor(length / 30)
	for _ = 1, patches do
		local p = a + dir * rng:NextNumber(4, length - 4) + right * rng:NextNumber(-width * 0.3, width * 0.3)
		local nuance = rng:NextNumber(-0.1, 0.08)
		local patch = Build.deco(
			parent,
			"RoadPatch",
			Vector3.new(rng:NextNumber(3, 5), 0.1, rng:NextNumber(3, 6)),
			CFrame.lookAt(p, p + dir) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0) + UP * (top + 0.02),
			shade(opts.color or rgb(170, 160, 146), nuance),
			{
				Material = opts.material or Enum.Material.Cobblestone,
				CastShadow = false,
			}
		)
		role(patch, opts.role or "pave", nuance)
	end
	if opts.curbs ~= false then
		local seg = opts.segment or 6
		local n = math.max(1, math.floor(length / seg + 0.5))
		for _, side in { -1, 1 } do
			for i = 0, n - 1 do
				local t0 = i / n
				local p = a + dir * (length * (t0 + 0.5 / n)) + right * side * (width / 2 + 0.55)
				local nuance = rng:NextNumber(-0.08, 0.06)
				local curb = Build.part(
					parent,
					"Curb",
					Vector3.new(1.1, 0.9, length / n - 0.15),
					CFrame.lookAt(p, p + dir) + UP * (top + 0.1),
					shade(opts.curb or rgb(150, 146, 140), nuance),
					{
						Material = Enum.Material.Slate,
						CastShadow = false,
					}
				)
				role(curb, opts.curbRole or "bordure", nuance)
			end
		end
	end
end

------------------------------------------------------------------------
-- Murets et clôtures
------------------------------------------------------------------------

export type WallOptions = {
	color: Color3?,
	cap: Color3?,
	role: string?,
	rng: Random?,
	moss: boolean?,
}

-- Muret de pierres variées de `a` à `b` : âme maçonnée, pierres en saillie de tailles diverses
-- sur les deux faces, chaperon de dalles. Renvoie le modèle.
function Relief.stoneWall(parent: Instance, a: Vector3, b: Vector3, h: number, thick: number, o: WallOptions?): Model
	local opts = o or {}
	local rng = opts.rng or Random.new(11)
	local color = opts.color or rgb(150, 144, 134)
	local model = Instance.new("Model")
	model.Name = "Muret"
	model.Parent = parent
	local delta = flat(b - a)
	local length = delta.Magnitude
	if length < 0.5 then
		return model
	end
	local dir = delta.Unit
	local right = dir:Cross(UP)
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	role(Build.part(model, "WallCore", Vector3.new(thick, h, length), cf + UP * (h / 2), color, { Material = Enum.Material.Cobblestone }), opts.role)
	-- pierres en saillie
	local cols = math.max(1, math.floor(length / 2.4))
	for i = 0, cols - 1 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.75 then
				local y = rng:NextNumber(0.4, h - 0.6)
				local p = a + dir * ((i + rng:NextNumber(0.2, 0.8)) * length / cols) + right * side * (thick / 2) + UP * y
				local s = Vector3.new(rng:NextNumber(0.5, 0.8), rng:NextNumber(0.8, 1.5), rng:NextNumber(1.2, 2.4))
				local nuance = rng:NextNumber(-0.14, 0.1)
				local stone = Build.part(
					model,
					"WallStone",
					s,
					CFrame.lookAt(p, p + dir) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.15, 0.15)),
					shade(color, nuance),
					{
						Material = Enum.Material.Rock,
						CanCollide = false,
					}
				)
				role(stone, opts.role, nuance)
			end
		end
	end
	-- chaperon de dalles
	local caps = math.max(1, math.floor(length / 3))
	for i = 0, caps - 1 do
		local p = a + dir * ((i + 0.5) * length / caps) + UP * (h + 0.25)
		local nuance = rng:NextNumber(-0.06, 0.08)
		local cap = Build.part(
			model,
			"WallCap",
			Vector3.new(thick + 0.7, 0.5, length / caps - 0.1),
			CFrame.lookAt(p, p + dir) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0),
			shade(opts.cap or shade(color, 0.08), nuance),
			{
				Material = Enum.Material.Slate,
			}
		)
		role(cap, opts.role, nuance + 0.08)
		if opts.moss and rng:NextNumber() < 0.35 then
			Core.ellipsoid(
				model,
				"Moss",
				Vector3.new(thick + 0.4, 0.5, rng:NextNumber(1, 2.4)),
				CFrame.lookAt(p + UP * 0.25, p + UP * 0.25 + dir),
				rgb(86, 120, 62),
				Enum.Material.Grass
			)
		end
	end
	return model
end

-- Clôture de `a` à `b`. Styles : "bois" (poteaux + 2 lisses), "piquets", "bambou", "corde".
function Relief.fence(parent: Instance, a: Vector3, b: Vector3, style: string?, h: number?, color: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Cloture"
	model.Parent = parent
	local height = h or 4
	local delta = flat(b - a)
	local length = delta.Magnitude
	if length < 0.5 then
		return model
	end
	local dir = delta.Unit
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	local s = style or "bois"
	local wood = color or rgb(118, 82, 56)
	local postGap = s == "corde" and 8 or 6
	local posts = math.max(1, math.floor(length / postGap + 0.5))
	for i = 0, posts do
		local p = a + delta * (i / posts)
		if s == "bambou" then
			Core.vcyl(model, "Post", CFrame.new(p - UP * 0.3), height + 0.6, 0.6, rgb(150, 140, 80), Enum.Material.SmoothPlastic)
		else
			Build.part(model, "Post", Vector3.new(0.8, height, 0.8), CFrame.lookAt(p, p + dir) + UP * (height / 2), wood, { Material = Enum.Material.Wood })
			Build.deco(model, "PostCap", Vector3.new(1, 0.3, 1), CFrame.lookAt(p, p + dir) + UP * (height + 0.1), shade(wood, -0.2), { Material = Enum.Material.Wood })
		end
	end
	if s == "bois" then
		for _, y in { height * 0.4, height * 0.78 } do
			Build.part(model, "Rail", Vector3.new(0.35, 0.5, length), cf + UP * y, wood, { Material = Enum.Material.Wood })
		end
	elseif s == "piquets" then
		Build.part(model, "Rail", Vector3.new(0.3, 0.4, length), cf + UP * (height * 0.3), wood, { Material = Enum.Material.Wood })
		Build.part(model, "Rail", Vector3.new(0.3, 0.4, length), cf + UP * (height * 0.75), wood, { Material = Enum.Material.Wood })
		local pickets = math.floor(length / 1.1)
		for i = 0, pickets do
			local p = a + delta * (i / pickets)
			Build.deco(
				model,
				"Picket",
				Vector3.new(0.2, height * 0.95, 0.6),
				CFrame.lookAt(p, p + dir) + UP * (height * 0.47),
				shade(wood, (i % 2) * 0.05),
				{ Material = Enum.Material.WoodPlanks }
			)
		end
	elseif s == "bambou" then
		local cane = rgb(160, 150, 86)
		for _, y in { height * 0.25, height * 0.55, height * 0.85 } do
			local rail =
				Build.part(model, "Rail", Vector3.new(length, 0.35, 0.35), cf * CFrame.Angles(0, math.rad(90), 0) + UP * y, cane, { Material = Enum.Material.SmoothPlastic })
			rail.Shape = Enum.PartType.Cylinder
		end
		local canes = math.floor(length / 0.9)
		for i = 0, canes do
			local p = a + delta * (i / canes)
			Core.vcyl(model, "Cane", CFrame.new(p), height * 0.9, 0.35, shade(cane, (i % 3 - 1) * 0.06), Enum.Material.SmoothPlastic, false)
		end
	elseif s == "corde" then
		for i = 0, posts - 1 do
			local p0 = a + delta * (i / posts) + UP * (height * 0.8)
			local p1 = a + delta * ((i + 1) / posts) + UP * (height * 0.8)
			local prev = p0
			for k = 1, 4 do
				local t = k / 4
				local q = p0:Lerp(p1, t) - UP * (2.4 * t * (1 - t))
				Core.cylinder(model, "Rope", prev, q, 0.25, rgb(200, 176, 120), { CanCollide = false, Material = Enum.Material.Fabric })
				prev = q
			end
		end
	end
	return model
end

------------------------------------------------------------------------
-- Eau
------------------------------------------------------------------------

export type WaterOptions = {
	color: Color3?,
	bed: Color3?,
	bank: Color3?,
	level: number?, -- hauteur de la surface de l'eau (le sol est à 0)
	rng: Random?,
	reeds: boolean?,
	lilies: boolean?,
}

local function waterSurface(parent: Instance, cf: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local water = Build.part(parent, "Water", size, cf, color, {
		Material = Enum.Material.Glass,
		Transparency = 0.32,
		Reflectance = 0.12,
		CanCollide = false,
		CastShadow = false,
	})
	water.CanQuery = false
	if shape then
		water.Shape = shape
	end
	role(water, "eau")
	return water
end

-- Étang de forme organique (plusieurs disques), fond sombre, berges de pierres et de terre,
-- roseaux et nénuphars. On y entre jusqu'aux chevilles. Renvoie le dossier.
function Relief.pond(parent: Instance, center: Vector3, radius: number, o: WaterOptions?, nature: any?): Folder
	local opts = o or {}
	local rng = opts.rng or Random.new(3)
	local folder = Build.folder(parent, "Etang")
	local level = opts.level or 0.9
	local lobes = {}
	table.insert(lobes, { center, radius })
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.4, 0.4)
		local r = radius * rng:NextNumber(0.5, 0.75)
		table.insert(lobes, { center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rng:NextNumber(0.45, 0.6), r })
	end
	for i, lobe in lobes do
		local c, r = lobe[1], lobe[2]
		role(Core.flatDisc(folder, "PondBank", c, r * 2 + 6, 0.12 + i * 0.003, opts.bank or rgb(120, 104, 80), Enum.Material.Ground), "berge")
		role(Core.flatDisc(folder, "PondBed", c, r * 2, 0.16 + i * 0.003, opts.bed or rgb(60, 74, 66), Enum.Material.Mud), "lit")
		waterSurface(
			folder,
			CFrame.new(c.X, level - 0.15 + i * 0.004, c.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.3, r * 2 - 0.6, r * 2 - 0.6),
			opts.color or rgb(70, 130, 140),
			Enum.PartType.Cylinder
		)
	end
	-- pierres de berge tout autour (en suivant le contour extérieur des lobes)
	for _, lobe in lobes do
		local c, r = lobe[1], lobe[2]
		local n = math.floor(r * 2 * math.pi / 4)
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (r + rng:NextNumber(-0.4, 0.8))
			local inside = false
			for _, other in lobes do
				if other ~= lobe and (flat(p - other[1])).Magnitude < other[2] - 1 then
					inside = true
				end
			end
			if not inside and rng:NextNumber() < 0.8 then
				local s = Vector3.new(rng:NextNumber(1.6, 3.2), rng:NextNumber(0.8, 1.8), rng:NextNumber(1.4, 2.6))
				local nuance = rng:NextNumber(-0.1, 0.1)
				local stone = Build.part(
					folder,
					"BankStone",
					s,
					CFrame.new(p + UP * (s.Y * 0.3)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
					shade(rgb(130, 126, 118), nuance),
					{
						Material = Enum.Material.Rock,
					}
				)
				role(stone, "roche", nuance)
				if nature and opts.reeds ~= false and rng:NextNumber() < 0.18 then
					nature.reeds(folder, p + (flat(c - p)).Unit * 1.5, rng:NextNumber(3.5, 5.5), rng)
				end
			end
		end
	end
	if nature and opts.lilies ~= false then
		for _ = 1, math.floor(radius / 2.5) do
			local lobe = lobes[rng:NextInteger(1, #lobes)]
			local a = rng:NextNumber(0, math.pi * 2)
			local p = lobe[1] + Vector3.new(math.cos(a), 0, math.sin(a)) * lobe[2] * rng:NextNumber(0.2, 0.8)
			nature.lilyPad(folder, p + UP * (level + 0.02), rng:NextNumber(1.6, 2.8), rng)
		end
	end
	return folder
end

-- Ruisseau qui passe par `points` (au sol), largeur `width`. Berges de pierres et roseaux.
function Relief.stream(parent: Instance, points: { Vector3 }, width: number, o: WaterOptions?, nature: any?): Folder
	local opts = o or {}
	local rng = opts.rng or Random.new(5)
	local folder = Build.folder(parent, "Ruisseau")
	local level = opts.level or 0.8
	for i = 1, #points - 1 do
		local a, b = flat(points[i]), flat(points[i + 1])
		local delta = b - a
		local length = delta.Magnitude
		local dir = delta.Unit
		local right = dir:Cross(UP)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, mid + dir)
		role(
			Build.deco(
				folder,
				"StreamBank",
				Vector3.new(width + 5, 0.3, length + 2),
				cf + UP * 0.1,
				opts.bank or rgb(120, 104, 80),
				{ Material = Enum.Material.Ground, CastShadow = false }
			),
			"berge"
		)
		role(
			Build.deco(
				folder,
				"StreamBed",
				Vector3.new(width, 0.3, length + 1),
				cf + UP * 0.16,
				opts.bed or rgb(60, 74, 66),
				{ Material = Enum.Material.Pebble, CastShadow = false }
			),
			"lit"
		)
		waterSurface(folder, cf + UP * (level - 0.15), Vector3.new(width - 0.4, 0.3, length + 0.8), opts.color or rgb(70, 130, 140))
		-- arrondi aux coudes
		role(Core.flatDisc(folder, "StreamBank", b, width + 5, 0.24, opts.bank or rgb(120, 104, 80), Enum.Material.Ground), "berge")
		role(Core.flatDisc(folder, "StreamBed", b, width, 0.3, opts.bed or rgb(60, 74, 66), Enum.Material.Pebble), "lit")
		waterSurface(
			folder,
			CFrame.new(b.X, level - 0.14, b.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.3, width - 0.4, width - 0.4),
			opts.color or rgb(70, 130, 140),
			Enum.PartType.Cylinder
		)
		-- galets et pierres des berges
		local n = math.floor(length / 3.5)
		for k = 1, n do
			local side = (k % 2 == 0) and 1 or -1
			local p = a + dir * (k / n * length + rng:NextNumber(-1, 1)) + right * side * (width / 2 + rng:NextNumber(0.2, 1.6))
			local s = Vector3.new(rng:NextNumber(1.2, 2.6), rng:NextNumber(0.6, 1.4), rng:NextNumber(1.2, 2.2))
			local nuance = rng:NextNumber(-0.1, 0.1)
			local stone = Build.part(
				folder,
				"BankStone",
				s,
				CFrame.new(p + UP * (s.Y * 0.3)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
				shade(rgb(130, 126, 118), nuance),
				{
					Material = Enum.Material.Rock,
				}
			)
			role(stone, "roche", nuance)
			if nature and rng:NextNumber() < 0.2 then
				nature.reeds(folder, p - right * side * 0.8, rng:NextNumber(3, 5), rng)
			end
		end
	end
	return folder
end

-- Pas japonais : dalles plates en pas à pas de `a` à `b`.
function Relief.steppingStones(parent: Instance, a: Vector3, b: Vector3, top: number, rng: Random, color: Color3?)
	local delta = flat(b - a)
	local n = math.max(2, math.floor(delta.Magnitude / 3.2))
	local right = delta.Unit:Cross(UP)
	for i = 0, n do
		local p = a + delta * (i / n) + right * ((i % 2 == 0) and 0.6 or -0.6)
		local d = rng:NextNumber(2.2, 2.9)
		local nuance = rng:NextNumber(-0.1, 0.1)
		local stone = Build.part(
			parent,
			"SteppingStone",
			Vector3.new(0.6, d, d * rng:NextNumber(0.8, 1)),
			CFrame.new(p.X, top + 0.1, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)),
			shade(color or rgb(150, 146, 140), nuance),
			{
				Material = Enum.Material.Slate,
				Shape = Enum.PartType.Cylinder,
			}
		)
		role(stone, "dalle", nuance)
	end
end

------------------------------------------------------------------------
-- Ponts
------------------------------------------------------------------------

-- Pont arqué (taiko-bashi) de `a` à `b` : tablier en segments praticables qui suivent l'arc,
-- garde-corps à poteaux coiffés de boules (giboshi). `color` = laque des garde-corps.
function Relief.archBridge(parent: Instance, a: Vector3, b: Vector3, width: number, rise: number, color: Color3?, deck: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "PontArque"
	model.Parent = parent
	local lacquer = color or rgb(196, 58, 40)
	local plank = deck or rgb(150, 108, 72)
	local delta = flat(b - a)
	local right = delta.Unit:Cross(UP)
	local n = 9
	local function at(t: number): Vector3
		return a + delta * t + UP * (rise * 4 * t * (1 - t))
	end
	for i = 0, n - 1 do
		local p0, p1 = at(i / n), at((i + 1) / n)
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.3
		Build.part(model, "Deck", Vector3.new(width, 0.6, len), CFrame.lookAt(mid, p1) * CFrame.new(0, -0.1, 0), shade(plank, (i % 2) * 0.05), {
			Material = Enum.Material.WoodPlanks,
		})
		for _, side in { -1, 1 } do
			local r0 = p0 + right * side * (width / 2 - 0.3) + UP * 2.8
			local r1 = p1 + right * side * (width / 2 - 0.3) + UP * 2.8
			Core.beam(model, "Handrail", r0, r1, 0.45, 0.45, lacquer, { CanCollide = false })
			Core.beam(model, "MidRail", r0 - UP * 1.4, r1 - UP * 1.4, 0.3, 0.3, lacquer, { CanCollide = false })
		end
	end
	for i = 0, n do
		local p = at(i / n)
		for _, side in { -1, 1 } do
			local q = p + right * side * (width / 2 - 0.3)
			local post = i == 0 or i == n or i == math.floor(n / 2)
			Build.part(model, "RailPost", Vector3.new(post and 0.7 or 0.5, 3.4, post and 0.7 or 0.5), CFrame.new(q + UP * 1.4), lacquer)
			if post then
				Core.ball(model, "Giboshi", 0.9, q + UP * 3.4, rgb(210, 170, 70), Enum.Material.Metal)
			end
		end
	end
	-- poutres et piles sous le tablier
	for _, t in { 0.25, 0.75 } do
		local p = at(t)
		for _, side in { -1, 1 } do
			Core.vcyl(model, "Pile", CFrame.new(flat(p) + right * side * (width / 2 - 0.8) - UP * 1), p.Y + 0.6, 0.9, shade(lacquer, -0.3), Enum.Material.Wood, false)
		end
	end
	return model
end

-- Pont de planches avec garde-corps de corde. Praticable.
function Relief.plankBridge(parent: Instance, a: Vector3, b: Vector3, width: number, top: number): Model
	local model = Instance.new("Model")
	model.Name = "PontPlanches"
	model.Parent = parent
	local delta = flat(b - a)
	local span = delta.Magnitude
	local dir = delta.Unit
	local right = dir:Cross(UP)
	local planks = math.max(3, math.floor(span / 1.3))
	for i = 0, planks - 1 do
		local p = a + delta * ((i + 0.5) / planks) + UP * top
		Build.part(model, "Plank", Vector3.new(width, 0.4, span / planks - 0.15), CFrame.lookAt(p, p + dir), shade(rgb(150, 110, 74), ((i * 7) % 5) * 0.025 - 0.05), {
			Material = Enum.Material.WoodPlanks,
		})
	end
	for _, side in { -1, 1 } do
		Build.deco(
			model,
			"Stringer",
			Vector3.new(0.5, 0.6, span + 1),
			CFrame.lookAt(flat(a + b) / 2, flat(a + b) / 2 + dir) + right * side * (width / 2 - 0.25) + UP * (top - 0.4),
			rgb(96, 70, 50),
			{ Material = Enum.Material.Wood }
		)
		local posts = math.max(2, math.floor(span / 5))
		local prev = nil
		for i = 0, posts do
			local p = a + delta * (i / posts) + right * side * (width / 2 - 0.25)
			Build.part(model, "RopePost", Vector3.new(0.5, 4.2, 0.5), CFrame.new(p + UP * (top + 1.6)), rgb(96, 70, 50), { Material = Enum.Material.Wood })
			local q = p + UP * (top + 3.4)
			if prev then
				Core.cylinder(model, "Rope", prev, q, 0.25, rgb(200, 176, 120), { CanCollide = false, Material = Enum.Material.Fabric })
			end
			prev = q
		end
	end
	return model
end

return Relief
