-- DecorKit : la nature et les éléments de décor « style animé » de la carte.
--
--   * Arbres arrondis (tronc cylindrique, racines, branches, feuillage en ellipsoïdes de plusieurs
--     tons), arbres géants, sapins, cerisiers, glycines, palmiers, buissons ;
--   * rochers irréguliers, collines et montagnes ;
--   * détails du sol : touffes d'herbe, fleurs, taches de couleur, chemins de pierre ou de terre.
--
-- EMPLACEMENTS REMPLAÇABLES : chaque gros élément (arbre, rocher, bâtiment...) est un Model tagué
-- "DecorSlot" avec les attributs Slot (nom du modèle) et TargetHeight (hauteur en studs).
-- Au lancement, si ServerStorage > ModelesDeco contient un modèle (ou un dossier de plusieurs
-- modèles) portant ce nom, il remplace l'élément : mis à la bonne hauteur, posé au même endroit.
-- Exemple : glisse un arbre de la Boîte à outils dans ServerStorage > ModelesDeco et renomme-le
-- "ArbreRond" : tous les arbres ronds de la carte deviennent cet arbre.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Build = require(script.Parent.Parent.Modules.Build)

local DecorKit = {}

DecorKit.SlotTag = "DecorSlot"
DecorKit.StoreName = "ModelesDeco"
-- Pièces du sol recolorées à chaque changement d'univers (attributs Role et Nuance).
DecorKit.SolTag = "TeinteSol"

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)

-- Palettes par défaut (feuillage : sombre, base, clair, reflet).
DecorKit.Palettes = {
	vert = { rgb(52, 120, 52), rgb(78, 160, 64), rgb(116, 194, 82), rgb(170, 222, 110) },
	foret = { rgb(34, 92, 50), rgb(50, 126, 62), rgb(82, 160, 74), rgb(136, 200, 96) },
	sapin = { rgb(26, 74, 52), rgb(38, 98, 62), rgb(56, 124, 72), rgb(92, 156, 90) },
	cerisier = { rgb(226, 120, 160), rgb(246, 160, 192), rgb(255, 196, 218), rgb(255, 228, 238) },
	glycine = { rgb(120, 84, 190), rgb(160, 120, 230), rgb(196, 160, 250), rgb(230, 208, 255) },
	automne = { rgb(190, 80, 40), rgb(226, 120, 50), rgb(246, 170, 70), rgb(255, 214, 120) },
	palmier = { rgb(46, 130, 60), rgb(70, 160, 70), rgb(104, 190, 84), rgb(150, 214, 110) },
}
local TRUNK = rgb(116, 80, 56)
local TRUNK_DARK = rgb(88, 60, 44)

------------------------------------------------------------------------
-- Pièces de base
------------------------------------------------------------------------

-- Ellipsoïde (pièce + SpecialMesh "Sphere" étiré à la taille de la pièce). Sans collision.
function DecorKit.ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Build.deco(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cylindre de `a` vers `b` (diamètre `diameter`).
function DecorKit.cylinder(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, props: { [string]: any }?): Part
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local dir = (b - a).Unit
	-- L'axe d'un cylindre Roblox est X : on construit un repère dont X suit `dir`.
	local helper = math.abs(dir:Dot(UP)) > 0.95 and Vector3.new(1, 0, 0) or UP
	local z = dir:Cross(helper).Unit
	local y = z:Cross(dir).Unit
	local cf = CFrame.fromMatrix(mid, dir, y, z)
	local part = Build.part(parent, name, Vector3.new(length, diameter, diameter), cf, color, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Disque plat posé au sol (dessus à la hauteur `top`).
function DecorKit.flatDisc(parent: Instance, name: string, center: Vector3, diameter: number, top: number, color: Color3, material: Enum.Material?): Part
	local thickness = 0.4
	local part = Build.deco(
		parent,
		name,
		Vector3.new(thickness, diameter, diameter),
		CFrame.new(center.X, top - thickness / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		{ Material = material or Enum.Material.Grass, CastShadow = false }
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Marque une pièce du sol : sa couleur et son matériau suivront `theme.sol[role]` de l'univers
-- (Nuance = éclaircissement > 0 ou assombrissement < 0, pour garder les variations).
function DecorKit.solRole(part: BasePart, role: string, nuance: number?): BasePart
	part:SetAttribute("Role", role)
	if nuance and nuance ~= 0 then
		part:SetAttribute("Nuance", math.floor(nuance * 100 + 0.5) / 100)
	end
	CollectionService:AddTag(part, DecorKit.SolTag)
	return part
end

-- Applique les couleurs du sol d'un univers à toutes les pièces marquées.
function DecorKit.applySol(sol: { [string]: { any } }?)
	if not sol then
		return
	end
	for _, part in CollectionService:GetTagged(DecorKit.SolTag) do
		if part:IsA("BasePart") then
			local entry = sol[part:GetAttribute("Role") or ""]
			if entry then
				local nuance = part:GetAttribute("Nuance") or 0
				local color: Color3 = entry[1]
				part.Color = if nuance >= 0 then color:Lerp(WHITE, nuance) else color:Lerp(BLACK, -nuance)
				if entry[2] then
					part.Material = entry[2]
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Emplacements remplaçables
------------------------------------------------------------------------

-- Crée un emplacement : un Model tagué "DecorSlot" dont le pivot est au pied de l'élément.
function DecorKit.slot(parent: Instance, slotName: string, base: CFrame, targetHeight: number): Model
	local model = Instance.new("Model")
	model.Name = slotName
	model:SetAttribute("Slot", slotName)
	model:SetAttribute("TargetHeight", math.floor(targetHeight * 10 + 0.5) / 10)
	-- Pied de l'élément et orientation (attributs : lisibles dans Studio et fiables à l'enregistrement).
	local look = base.LookVector
	model:SetAttribute("Base", base.Position)
	model:SetAttribute("Yaw", math.floor(math.deg(math.atan2(-look.X, -look.Z)) * 10 + 0.5) / 10)
	pcall(function()
		model.WorldPivot = base
	end)
	CollectionService:AddTag(model, DecorKit.SlotTag)
	model.Parent = parent
	return model
end

local function pickReplacement(store: Instance, slotName: string, seed: number): Instance?
	local entry = store:FindFirstChild(slotName)
	if not entry then
		return nil
	end
	if entry:IsA("Folder") then
		local choices = {}
		for _, child in entry:GetChildren() do
			if child:IsA("Model") or child:IsA("BasePart") then
				table.insert(choices, child)
			end
		end
		if #choices == 0 then
			return nil
		end
		return choices[(seed % #choices) + 1]
	end
	return entry
end

-- Vrai si ServerStorage.ModelesDeco contient au moins un modèle de remplacement.
function DecorKit.hasStore(): boolean
	local store = ServerStorage:FindFirstChild(DecorKit.StoreName)
	return store ~= nil and #store:GetChildren() > 0
end

-- Remplace les emplacements de `root` par les modèles de ServerStorage.ModelesDeco.
-- Renvoie le nombre d'éléments remplacés.
function DecorKit.replaceSlots(root: Instance): number
	local store = ServerStorage:FindFirstChild(DecorKit.StoreName)
	if not store or #store:GetChildren() == 0 then
		return 0
	end
	local replaced = 0
	local slots = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and CollectionService:HasTag(descendant, DecorKit.SlotTag) then
			table.insert(slots, descendant)
		end
	end
	for index, slot in slots do
		local source = pickReplacement(store, slot:GetAttribute("Slot") or slot.Name, index)
		if source then
			local ok = pcall(function()
				local clone = source:Clone()
				local model: Model
				if clone:IsA("Model") then
					model = clone
				else
					model = Instance.new("Model")
					clone.Parent = model
				end
				-- Sécurité : les modèles de la Boîte à outils peuvent contenir des scripts.
				for _, item in model:GetDescendants() do
					if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
						item:Destroy()
					elseif item:IsA("BasePart") then
						item.Anchored = true
					end
				end
				local target = slot:GetAttribute("TargetHeight")
				local _, size = model:GetBoundingBox()
				if target and size.Y > 0.1 then
					model:ScaleTo(model:GetScale() * target / size.Y)
				end
				local boxCF, boxSize = model:GetBoundingBox()
				model.WorldPivot = CFrame.new(boxCF.Position - Vector3.new(0, boxSize.Y / 2, 0))
				local base = slot:GetAttribute("Base")
				local yaw = slot:GetAttribute("Yaw") or 0
				local place = if typeof(base) == "Vector3" then CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0) else slot:GetPivot()
				model:PivotTo(place)
				model.Name = slot.Name
				model:SetAttribute("Slot", slot:GetAttribute("Slot"))
				model:SetAttribute("TargetHeight", target)
				model:SetAttribute("Remplace", true)
				model.Parent = slot.Parent
				slot:Destroy()
			end)
			if ok then
				replaced += 1
			end
		end
	end
	return replaced
end

------------------------------------------------------------------------
-- Arbres
------------------------------------------------------------------------

local function asCFrame(base: Vector3 | CFrame, rng: Random): CFrame
	if typeof(base) == "CFrame" then
		return base
	end
	return CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(WHITE, amount)
	end
	return color:Lerp(BLACK, -amount)
end

-- Tronc effilé et légèrement courbé (plusieurs segments reliés par des « nœuds » ronds pour
-- cacher les marches), avec des racines évasées. Renvoie le sommet.
local function trunk(model: Model, base: CFrame, height: number, diameter: number, color: Color3, rng: Random, roots: number): Vector3
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * height * 0.07
	local segments = height > 24 and 4 or 3
	local p = base.Position - Vector3.new(0, 0.6, 0)
	for i = 1, segments do
		local t = i / segments
		local q = base.Position + Vector3.new(0, height * t, 0) + lean * (t * t)
		local d = diameter * (1 - 0.42 * (i - 1) / segments)
		DecorKit.cylinder(model, "Trunk", p, q, d, shade(color, (i % 2) * 0.04), { Material = Enum.Material.Wood, CanCollide = i == 1 })
		if i < segments then
			local joint = Build.ball(model, "TrunkJoint", d * 0.97, q, shade(color, (i % 2) * 0.04), { Material = Enum.Material.Wood, CanCollide = false })
			joint.CastShadow = true
		end
		p = q
	end
	for i = 1, roots do
		local angle = (i / roots) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = base.Position + Vector3.new(0, diameter * 0.7, 0) + dir * diameter * 0.15
		local to = base.Position + dir * diameter * rng:NextNumber(1.1, 1.5) - Vector3.new(0, 0.2, 0)
		DecorKit.cylinder(model, "Root", from, to, diameter * 0.38, shade(color, -0.06), { Material = Enum.Material.Wood, CanCollide = false })
		Build.ball(model, "RootTip", diameter * 0.36, to, shade(color, -0.06), { Material = Enum.Material.Wood, CanCollide = false })
	end
	return p
end

-- Grappe de feuillage arrondie : un gros volume central entouré de boules, plus sombre dessous,
-- plus clair dessus (ombrage façon dessin animé).
local function canopy(model: Model, center: Vector3, radius: number, palette: { Color3 }, rng: Random, flat: number?)
	local f = flat or 0.78
	local dark, base, light, top = palette[1], palette[2], palette[3], palette[4]
	DecorKit.ellipsoid(model, "Leaves", Vector3.new(radius * 2, radius * 2 * f, radius * 2), CFrame.new(center), base)
	-- dessous sombre
	DecorKit.ellipsoid(model, "LeavesShadow", Vector3.new(radius * 1.7, radius * 0.9, radius * 1.7), CFrame.new(center - Vector3.new(0, radius * 0.5 * f, 0)), dark)
	-- couronne de boules
	local count = 6
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local angle = turn + i / count * math.pi * 2
		local r = radius * rng:NextNumber(0.62, 0.8)
		local d = radius * rng:NextNumber(0.95, 1.2)
		local y = radius * rng:NextNumber(-0.18, 0.12) * f
		local offset = Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
		local color = (i % 2 == 0) and base or base:Lerp(light, 0.45)
		DecorKit.ellipsoid(model, "Leaves", Vector3.new(d, d * 0.85, d), CFrame.new(center + offset), color)
	end
	-- dessus clair
	for i = 1, 3 do
		local angle = turn + i * 2.1
		local offset = Vector3.new(math.cos(angle) * radius * 0.35, radius * 0.48 * f, math.sin(angle) * radius * 0.35)
		local d = radius * rng:NextNumber(0.9, 1.15)
		DecorKit.ellipsoid(model, "LeavesTop", Vector3.new(d, d * 0.8, d), CFrame.new(center + offset), i == 1 and top or light)
	end
end

local function branch(model: Model, from: Vector3, angle: number, upward: number, length: number, diameter: number, color: Color3): Vector3
	local dir = Vector3.new(math.cos(angle), upward, math.sin(angle)).Unit
	local to = from + dir * length
	DecorKit.cylinder(model, "Branch", from, to, diameter, color, { Material = Enum.Material.Wood, CanCollide = false })
	Build.ball(model, "BranchTip", diameter * 0.95, to, color, { Material = Enum.Material.Wood, CanCollide = false })
	return to
end

export type TreeOptions = {
	height: number?,
	palette: { Color3 }?,
	trunk: Color3?,
	rng: Random?,
	slot: string?,
}

-- Arbre rond style animé (≈ 20 pièces).
function DecorKit.roundTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 22
	local palette = o.palette or DecorKit.Palettes.vert
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "ArbreRond", cf, h)
	local trunkColor = o.trunk or TRUNK
	local d = math.max(1.2, h * 0.075)
	local top = trunk(model, cf, h * 0.5, d, trunkColor, rng, 3)
	local radius = h * 0.3
	local center = top + Vector3.new(0, radius * 0.55, 0)
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, 3 do
		local angle = turn + i * 2.1
		local tip = branch(model, top - Vector3.new(0, h * 0.06, 0), angle, 0.9, radius * 0.9, d * 0.42, trunkColor)
		if i == 1 then
			canopy(model, tip + Vector3.new(0, radius * 0.1, 0), radius * 0.55, palette, rng)
		end
	end
	canopy(model, center, radius, palette, rng)
	return model
end

-- Arbre GÉANT (forêt du village ninja) : tronc épais à grosses racines, branches bien visibles
-- qui portent des grappes de feuillage à plusieurs hauteurs (≈ 60 pièces).
function DecorKit.giantTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 60
	local palette = o.palette or DecorKit.Palettes.foret
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "ArbreGeant", cf, h)
	local trunkColor = o.trunk or rgb(122, 86, 62)
	local d = h * 0.075
	local top = trunk(model, cf, h * 0.66, d, trunkColor, rng, 5)
	local turn = rng:NextNumber(0, math.pi * 2)
	-- branches basses et moyennes, chacune avec sa grappe
	local count = 4
	for i = 1, count do
		local angle = turn + i * (math.pi * 2 / count) + rng:NextNumber(-0.35, 0.35)
		local y = h * (0.3 + (i % 2) * 0.12 + rng:NextNumber(0, 0.05))
		local from = cf.Position + Vector3.new(0, y, 0)
		local length = h * rng:NextNumber(0.24, 0.3)
		local tip = branch(model, from, angle, rng:NextNumber(0.3, 0.55), length, d * 0.36, trunkColor)
		canopy(model, tip + Vector3.new(0, h * 0.035, 0), h * rng:NextNumber(0.12, 0.15), palette, rng, 0.6)
	end
	-- petites branches hautes
	for i = 1, 2 do
		local angle = turn + 0.8 + i * math.pi
		local tip = branch(model, top - Vector3.new(0, h * 0.08, 0), angle, 0.8, h * 0.16, d * 0.28, trunkColor)
		canopy(model, tip + Vector3.new(0, h * 0.02, 0), h * 0.11, palette, rng, 0.65)
	end
	canopy(model, top + Vector3.new(0, h * 0.07, 0), h * 0.17, palette, rng, 0.66)
	return model
end

-- Sapin arrondi : étages d'ellipsoïdes aplatis qui se chevauchent, plus clairs vers le haut.
function DecorKit.pine(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 24
	local palette = o.palette or DecorKit.Palettes.sapin
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "Sapin", cf, h)
	local d = math.max(1, h * 0.06)
	DecorKit.cylinder(model, "Trunk", cf.Position - Vector3.new(0, 0.5, 0), cf.Position + Vector3.new(0, h * 0.5, 0), d, o.trunk or TRUNK_DARK, {
		Material = Enum.Material.Wood,
	})
	local layers = 6
	for i = 0, layers - 1 do
		local t = i / (layers - 1)
		local width = h * (0.56 - t * 0.42)
		local y = h * (0.17 + t * 0.66)
		local color = palette[math.min(4, 1 + math.floor(t * 3.4))]
		local pos = cf.Position + Vector3.new(rng:NextNumber(-0.25, 0.25), y, rng:NextNumber(-0.25, 0.25))
		-- jupe tombante (dessous sombre) + étage
		DecorKit.ellipsoid(model, "LayerShadow", Vector3.new(width * 0.92, width * 0.3, width * 0.92), CFrame.new(pos - Vector3.new(0, width * 0.1, 0)), shade(color, -0.18))
		DecorKit.ellipsoid(model, "Layer", Vector3.new(width, width * 0.42, width), CFrame.new(pos + Vector3.new(0, width * 0.04, 0)), color)
	end
	DecorKit.ellipsoid(model, "Tip", Vector3.new(h * 0.1, h * 0.18, h * 0.1), CFrame.new(cf.Position + Vector3.new(0, h * 0.87, 0)), palette[4])
	return model
end

-- Cerisier en fleurs (canopée large et aplatie, pétales au sol).
function DecorKit.cherryTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 20
	local palette = o.palette or DecorKit.Palettes.cerisier
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "Cerisier", cf, h)
	local trunkColor = o.trunk or rgb(84, 56, 50)
	local d = math.max(1.1, h * 0.07)
	local top = trunk(model, cf, h * 0.45, d, trunkColor, rng, 3)
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, 3 do
		local angle = turn + i * 2.1
		local tip = branch(model, top - Vector3.new(0, h * 0.05, 0), angle, 0.55, h * 0.28, d * 0.4, trunkColor)
		canopy(model, tip + Vector3.new(0, h * 0.06, 0), h * 0.2, palette, rng, 0.62)
	end
	canopy(model, top + Vector3.new(0, h * 0.18, 0), h * 0.24, palette, rng, 0.6)
	for _ = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1, h * 0.5)
		local pos = cf.Position + Vector3.new(math.cos(angle) * r, 0.08, math.sin(angle) * r)
		Build.deco(model, "Petal", Vector3.new(0.7, 0.06, 0.5), CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), palette[3], { CastShadow = false })
	end
	return model
end

-- Glycine : canopée en dôme et grappes violettes pendantes.
function DecorKit.wisteriaTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 20
	local palette = o.palette or DecorKit.Palettes.glycine
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "Glycine", cf, h)
	local trunkColor = o.trunk or rgb(90, 64, 52)
	local d = math.max(1.1, h * 0.075)
	local top = trunk(model, cf, h * 0.55, d, trunkColor, rng, 3)
	local radius = h * 0.32
	canopy(model, top + Vector3.new(0, radius * 0.3, 0), radius, { DecorKit.Palettes.vert[1], palette[1], palette[2], palette[4] }, rng, 0.5)
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = radius * rng:NextNumber(0.4, 0.95)
		local length = h * rng:NextNumber(0.12, 0.24)
		local from = top + Vector3.new(math.cos(angle) * r, radius * 0.05, math.sin(angle) * r)
		DecorKit.ellipsoid(
			model,
			"Bloom",
			Vector3.new(h * 0.06, length, h * 0.06),
			CFrame.new(from - Vector3.new(0, length / 2, 0)),
			palette[rng:NextInteger(2, 4)],
			rng:NextNumber() < 0.3 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		)
	end
	return model
end

-- Palmier au tronc courbé (segments annelés) et palmes arquées en 3 parties.
function DecorKit.palmTree(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 22
	local palette = o.palette or DecorKit.Palettes.palmier
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "Palmier", cf, h)
	local segments = 8
	local bend = rng:NextNumber(0.3, 0.5)
	local p = cf.Position - Vector3.new(0, 0.5, 0)
	local dir = Vector3.new(0, 1, 0)
	local side = cf.LookVector
	for i = 1, segments do
		local nextDir = (dir + side * bend * 0.16).Unit
		local q = p + nextDir * (h * 0.86 / segments)
		local color = (i % 2 == 0) and rgb(168, 126, 82) or rgb(140, 102, 68)
		local d = h * (0.07 - i * 0.0035)
		DecorKit.cylinder(model, "Trunk", p, q + nextDir * 0.25, d, color, { Material = Enum.Material.Wood, CanCollide = i <= 2 })
		Build.ball(model, "TrunkRing", d * 1.08, q, rgb(120, 88, 58), { Material = Enum.Material.Wood, CanCollide = false })
		p, dir = q, nextDir
	end
	local fronds = 9
	for i = 1, fronds do
		local angle = i / fronds * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local lift = rng:NextNumber(0.02, 0.08)
		local points = {
			p,
			p + out * h * 0.13 + Vector3.new(0, h * (0.05 + lift), 0),
			p + out * h * 0.27 + Vector3.new(0, h * lift * 0.5, 0),
			p + out * h * 0.38 - Vector3.new(0, h * 0.09, 0),
		}
		local color = palette[(i % 3) + 2]
		for k = 1, 3 do
			local a, b = points[k], points[k + 1]
			local length = (b - a).Magnitude
			local width = h * (0.1 - k * 0.018)
			DecorKit.ellipsoid(model, "Frond", Vector3.new(width, h * 0.014, length * 1.2), CFrame.lookAt((a + b) / 2, b), shade(color, -0.04 * k))
		end
	end
	DecorKit.ellipsoid(model, "Crown", Vector3.new(h * 0.09, h * 0.07, h * 0.09), CFrame.new(p), palette[1])
	for i = 1, 3 do
		Build.ball(model, "Coconut", h * 0.05, p + Vector3.new(math.cos(i * 2.1) * h * 0.03, -h * 0.035, math.sin(i * 2.1) * h * 0.03), rgb(110, 74, 42), {
			CanCollide = false,
		})
	end
	return model
end

-- Buisson arrondi (3 à 5 boules).
function DecorKit.bush(parent: Instance, base: Vector3 | CFrame, options: TreeOptions?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local h = o.height or 4
	local palette = o.palette or DecorKit.Palettes.vert
	local cf = asCFrame(base, rng)
	local model = DecorKit.slot(parent, o.slot or "Buisson", cf, h)
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local r = i == 1 and 0 or h * 0.45
		local d = h * (i == 1 and 1.5 or rng:NextNumber(0.9, 1.15))
		local pos = cf.Position + Vector3.new(math.cos(angle) * r, d * 0.36, math.sin(angle) * r)
		DecorKit.ellipsoid(model, "Bush", Vector3.new(d, d * 0.8, d), CFrame.new(pos), palette[i == 1 and 2 or ((i % 2) + 2)])
	end
	DecorKit.ellipsoid(model, "BushTop", Vector3.new(h * 0.8, h * 0.5, h * 0.8), CFrame.new(cf.Position + Vector3.new(0, h * 0.85, 0)), palette[4])
	return model
end

------------------------------------------------------------------------
-- Rochers, collines et montagnes
------------------------------------------------------------------------

-- Rocher irrégulier à facettes : blocs fortement inclinés et à moitié enterrés, qui
-- s'interpénètrent (silhouette « low-poly » plutôt que des cubes).
function DecorKit.rock(parent: Instance, base: Vector3 | CFrame, size: number, options: { color: Color3?, rng: Random?, material: Enum.Material?, slot: string? }?): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local cf = asCFrame(base, rng)
	local color = o.color or rgb(150, 146, 140)
	local model = DecorKit.slot(parent, o.slot or "Rocher", cf, size * 0.75)
	local material = o.material or Enum.Material.Rock
	local blocks = rng:NextInteger(4, 6)
	for i = 1, blocks do
		local s = size * (i == 1 and 1 or rng:NextNumber(0.4, 0.7))
		local dims = Vector3.new(s * rng:NextNumber(0.8, 1.1), s * rng:NextNumber(0.6, 0.9), s * rng:NextNumber(0.7, 1))
		local offset = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-0.5, 0.5) * size, 0, rng:NextNumber(-0.5, 0.5) * size)
		local tilt = CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, math.pi), rng:NextNumber(-0.7, 0.7))
		local pos = cf * CFrame.new(offset + Vector3.new(0, dims.Y * (i == 1 and 0.18 or 0.05), 0))
		Build.part(model, "Rock", dims, CFrame.new(pos.Position) * tilt, shade(color, rng:NextNumber(-0.1, 0.12)), { Material = material })
	end
	return model
end

-- Colline arrondie (ellipsoïde à moitié enterré), herbeuse.
function DecorKit.hill(parent: Instance, center: Vector3, size: Vector3, color: Color3, material: Enum.Material?): Part
	local hill = DecorKit.ellipsoid(parent, "Hill", size, CFrame.new(center), color, material or Enum.Material.Grass)
	hill.CanCollide = true
	return hill
end

-- Montagne arrondie style animé : grand dôme principal (ellipsoïde à moitié enfoncé), bosses
-- autour, quelques affleurements rocheux et un sommet plus clair (ou enneigé).
-- `base` est le centre au niveau de la mer.
function DecorKit.mountain(
	parent: Instance,
	base: Vector3,
	width: number,
	height: number,
	options: { rock: Color3?, grass: Color3?, snow: Color3?, rng: Random?, slot: string? }?
): Model
	local o = options or {}
	local rng = o.rng or Random.new()
	local rock = o.rock or rgb(120, 112, 104)
	local grass = o.grass or rgb(84, 150, 70)
	local model = DecorKit.slot(parent, o.slot or "Montagne", CFrame.new(base), height)
	local function blob(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?)
		local part = DecorKit.ellipsoid(model, name, size, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), color, material or Enum.Material.Grass)
		part.CastShadow = false
		return part
	end
	-- dôme principal et sommet
	blob("Body", Vector3.new(width * 0.72, height * 2, width * 0.62), base, grass)
	local peak = base + Vector3.new(rng:NextNumber(-0.06, 0.06) * width, height * 0.72, rng:NextNumber(-0.06, 0.06) * width)
	blob("Peak", Vector3.new(width * 0.34, height * 0.62, width * 0.3), peak, o.snow or shade(grass, 0.12), o.snow and Enum.Material.Snow or nil)
	-- bosses autour (plus sombres en bas)
	local lumps = rng:NextInteger(3, 5)
	for i = 1, lumps do
		local angle = i / lumps * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = width * rng:NextNumber(0.26, 0.38)
		local h = height * rng:NextNumber(0.75, 1.15)
		local pos = base + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		blob("Lump", Vector3.new(width * rng:NextNumber(0.38, 0.5), h, width * rng:NextNumber(0.34, 0.46)), pos, shade(grass, rng:NextNumber(-0.14, 0.04)))
	end
	-- affleurements rocheux (falaises)
	for _ = 1, rng:NextInteger(2, 3) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local y = height * rng:NextNumber(0.25, 0.6)
		local r = width * 0.36 * math.sqrt(math.max(0.05, 1 - (y / height) ^ 2))
		local size = width * rng:NextNumber(0.1, 0.16)
		local pos = base + Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
		local part = Build.part(
			model,
			"Outcrop",
			Vector3.new(size, size * 0.9, size * 0.7),
			CFrame.lookAt(pos, base + Vector3.new(0, y, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.4, 0.4)),
			shade(rock, rng:NextNumber(-0.06, 0.08)),
			{
				Material = Enum.Material.Rock,
				CastShadow = false,
			}
		)
		part.CanCollide = false
	end
	return model
end

------------------------------------------------------------------------
-- Détails du sol
------------------------------------------------------------------------

-- Touffe d'herbe : 3 brins pointus (coins) en éventail.
-- Avec `role`, les brins suivent la couleur d'herbe de l'univers.
function DecorKit.tuft(parent: Instance, base: Vector3, height: number, color: Color3, rng: Random, role: string?)
	local yaw = rng:NextNumber(0, math.pi * 2)
	for i = 1, 3 do
		local h = height * rng:NextNumber(0.7, 1.1)
		local angle = yaw + i * 2.1
		local cf = CFrame.new(base) * CFrame.Angles(0, angle, 0) * CFrame.Angles(rng:NextNumber(0.15, 0.4), 0, 0) * CFrame.new(0, h / 2, 0)
		local nuance = rng:NextNumber(-0.1, 0.12)
		local blade = Build.wedge(parent, "Grass", Vector3.new(0.22, h, height * 0.5), cf, shade(color, nuance), {
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		if role then
			DecorKit.solRole(blade, role, nuance)
		end
	end
end

-- Petite fleur (tige + corolle + cœur).
function DecorKit.flower(parent: Instance, base: Vector3, color: Color3, rng: Random)
	local h = rng:NextNumber(0.7, 1.2)
	Build.deco(parent, "Stem", Vector3.new(0.14, h, 0.14), CFrame.new(base + Vector3.new(0, h / 2, 0)), rgb(70, 140, 60), { CastShadow = false })
	DecorKit.ellipsoid(parent, "Petals", Vector3.new(0.8, 0.3, 0.8), CFrame.new(base + Vector3.new(0, h, 0)), color).CastShadow = false
	DecorKit.ellipsoid(parent, "Heart", Vector3.new(0.3, 0.32, 0.3), CFrame.new(base + Vector3.new(0, h + 0.08, 0)), rgb(255, 214, 80)).CastShadow = false
end

-- Tache de sol organique (plusieurs disques qui se chevauchent).
function DecorKit.patch(parent: Instance, center: Vector3, size: number, top: number, color: Color3, material: Enum.Material?, rng: Random, role: string?)
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = i == 1 and 0 or size * rng:NextNumber(0.2, 0.42)
		local d = size * (i == 1 and 0.8 or rng:NextNumber(0.4, 0.65))
		local pos = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local disc = DecorKit.flatDisc(parent, "Patch", pos, d, top + (i % 2) * 0.01, color, material)
		if role then
			DecorKit.solRole(disc, role)
		end
	end
end

-- Chemin de dalles de pierre irrégulières de `a` à `b`.
function DecorKit.stonePath(parent: Instance, a: Vector3, b: Vector3, width: number, top: number, color: Color3, rng: Random)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local right = dir:Cross(UP)
	local step = 2.6
	for d = 0, length, step do
		local count = math.max(1, math.floor(width / 2.6))
		for k = 1, count do
			local lateral = (k - (count + 1) / 2) * 2.5 + rng:NextNumber(-0.5, 0.5)
			local pos = a + dir * (d + rng:NextNumber(-0.6, 0.6)) + right * lateral
			local size = rng:NextNumber(1.9, 2.5)
			local stone = DecorKit.flatDisc(parent, "PathStone", pos, size, top, shade(color, rng:NextNumber(-0.12, 0.1)), Enum.Material.Slate)
			stone.Size = Vector3.new(0.4, size, size)
		end
	end
end

-- Chemin de terre aux bords irréguliers (disques qui se chevauchent).
function DecorKit.dirtPath(parent: Instance, a: Vector3, b: Vector3, width: number, top: number, color: Color3, rng: Random, role: string?)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local right = dir:Cross(UP)
	for d = 0, length, width * 0.45 do
		local pos = a + dir * d + right * rng:NextNumber(-0.12, 0.12) * width
		local nuance = rng:NextNumber(-0.05, 0.05)
		local disc = DecorKit.flatDisc(parent, "Dirt", pos, width * rng:NextNumber(0.9, 1.15), top + rng:NextNumber(0, 0.01), shade(color, nuance), Enum.Material.Ground)
		if role then
			DecorKit.solRole(disc, role, nuance)
		end
	end
end

-- Sème `count` éléments dans un disque/anneau en évitant les zones refusées par `allowed`.
function DecorKit.scatter(rng: Random, count: number, center: Vector3, minR: number, maxR: number, allowed: (Vector3) -> boolean, place: (Vector3) -> ())
	local placed, attempts = 0, 0
	while placed < count and attempts < count * 15 do
		attempts += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(minR * minR, maxR * maxR))
		local pos = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		if allowed(pos) then
			place(pos)
			placed += 1
		end
	end
	return placed
end

return DecorKit
