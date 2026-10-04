-- Kit/Core : briques communes du décor (formes de base, emplacements remplaçables, couleurs du sol
-- par univers, semis d'objets, modèles maîtres clonés).
--
-- EMPLACEMENTS REMPLAÇABLES : chaque gros élément (arbre, rocher, bâtiment...) est un Model tagué
-- "DecorSlot" avec les attributs Slot (nom du modèle) et TargetHeight (hauteur en studs).
-- Au lancement, si ServerStorage > ModelesDeco contient un modèle (ou un dossier de plusieurs
-- modèles) portant ce nom, il remplace l'élément : mis à la bonne hauteur, posé au même endroit.
--
-- COULEURS DU SOL : les pièces marquées par Core.solRole (tag "TeinteSol", attributs Role et
-- Nuance) prennent la couleur et le matériau `theme.sol[Role]` de l'univers affiché.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Build = require(script.Parent.Parent.Parent.Modules.Build)

local Core = {}

Core.SlotTag = "DecorSlot"
Core.StoreName = "ModelesDeco"
Core.SolTag = "TeinteSol"

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)
Core.UP = UP

-- Éclaircit (amount > 0) ou assombrit (amount < 0) une couleur.
function Core.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(WHITE, amount)
	end
	return color:Lerp(BLACK, -amount)
end

-- Rend une couleur plus « naturelle » : désature légèrement vers le gris de même luminosité.
function Core.mute(color: Color3, amount: number): Color3
	local l = color.R * 0.3 + color.G * 0.59 + color.B * 0.11
	return color:Lerp(Color3.new(l, l, l), amount)
end

------------------------------------------------------------------------
-- Formes de base
------------------------------------------------------------------------

-- Ellipsoïde (pièce + SpecialMesh "Sphere" étiré à la taille de la pièce). Sans collision.
function Core.ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Build.deco(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Boule (vraie sphère Roblox : matériau bien rendu, collision ronde). Sans collision par défaut.
function Core.ball(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local part = Build.part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, {
		Material = material or Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		CanCollide = collide == true,
	})
	if not collide then
		part.CanQuery = false
	end
	return part
end

-- Repère dont l'axe X suit `dir` (les cylindres Roblox sont orientés selon X).
local function frameAlong(mid: Vector3, dir: Vector3): CFrame
	local helper = math.abs(dir:Dot(UP)) > 0.95 and Vector3.new(1, 0, 0) or UP
	local z = dir:Cross(helper).Unit
	local y = z:Cross(dir).Unit
	return CFrame.fromMatrix(mid, dir, y, z)
end
Core.frameAlong = frameAlong

-- Cylindre de `a` vers `b` (diamètre `diameter`).
function Core.cylinder(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, props: { [string]: any }?): Part
	local delta = b - a
	local length = math.max(0.05, delta.Magnitude)
	local dir = length > 0.05 and delta.Unit or UP
	local part = Build.part(parent, name, Vector3.new(length, diameter, diameter), frameAlong((a + b) / 2, dir), color, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Poutre (bloc) de `a` vers `b`, section `w` x `h` (h vertical quand c'est possible).
function Core.beam(parent: Instance, name: string, a: Vector3, b: Vector3, w: number, h: number, color: Color3, props: { [string]: any }?): Part
	local delta = b - a
	local length = math.max(0.05, delta.Magnitude)
	local dir = length > 0.05 and delta.Unit or Vector3.new(0, 0, -1)
	if math.abs(dir:Dot(UP)) > 0.98 then
		return Build.part(parent, name, Vector3.new(w, length, h), CFrame.new((a + b) / 2), color, props)
	end
	return Build.part(parent, name, Vector3.new(w, h, length), CFrame.lookAt((a + b) / 2, b), color, props)
end

-- Cylindre vertical posé sur `cf` (bas), hauteur `height`.
function Core.vcyl(parent: Instance, name: string, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return Build.part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, {
		Material = material or Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
		CanCollide = collide ~= false,
	})
end

-- Pyramide (4 coins biseautés) : base `wx` x `wz` centrée sur `cf`, sommet à `h` au-dessus.
-- Sert aux pics rocheux, aux toits en croupe et aux pointes de cristal.
function Core.pyramid(parent: Instance, name: string, cf: CFrame, wx: number, wz: number, h: number, color: Color3, material: Enum.Material?): { BasePart }
	local parts = {}
	for k = 0, 3 do
		local qx = (k % 2 == 0) and wx or wz
		local qz = (k % 2 == 0) and wz or wx
		local part = Instance.new("CornerWedgePart")
		part.Name = name
		part.Size = Vector3.new(qx / 2, h, qz / 2)
		part.CFrame = cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(-qx / 4, h / 2, qz / 4)
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		table.insert(parts, part)
	end
	return parts
end

-- Disque plat posé au sol (dessus à la hauteur `top`).
function Core.flatDisc(parent: Instance, name: string, center: Vector3, diameter: number, top: number, color: Color3, material: Enum.Material?): Part
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

-- Texte sur une plaque invisible (face avant).
function Core.plaqueText(parent: Instance, cf: CFrame, size: Vector2, text: string, color: Color3, font: Enum.Font?): Part
	local plaque = Build.deco(parent, "Texte", Vector3.new(size.X, size.Y, 0.1), cf, WHITE, { Transparency = 1, CastShadow = false })
	Build.surfaceText(plaque, Enum.NormalId.Front, text, color, { TextStrokeTransparency = 1, Font = font or Enum.Font.GothamBlack })
	return plaque
end

-- Lumière ponctuelle douce.
function Core.light(part: BasePart, color: Color3, range: number, brightness: number?, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.2
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

------------------------------------------------------------------------
-- Couleurs du sol par univers
------------------------------------------------------------------------

-- Marque une pièce du sol : sa couleur et son matériau suivront `theme.sol[role]` de l'univers
-- (Nuance = éclaircissement > 0 ou assombrissement < 0, pour garder les variations).
function Core.solRole(part: BasePart, role: string, nuance: number?): BasePart
	part:SetAttribute("Role", role)
	if nuance and nuance ~= 0 then
		part:SetAttribute("Nuance", math.floor(nuance * 100 + 0.5) / 100)
	end
	CollectionService:AddTag(part, Core.SolTag)
	return part
end

-- Applique les couleurs du sol d'un univers à toutes les pièces marquées (ou à celles de `root`).
function Core.applySol(sol: { [string]: { any } }?, root: Instance?)
	if not sol then
		return
	end
	local list = CollectionService:GetTagged(Core.SolTag)
	for _, part in list do
		if part:IsA("BasePart") and (root == nil or part:IsDescendantOf(root)) then
			local entry = sol[part:GetAttribute("Role") or ""]
			if entry then
				local nuance = part:GetAttribute("Nuance") or 0
				local color: Color3 = entry[1]
				part.Color = Core.shade(color, nuance)
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
function Core.slot(parent: Instance, slotName: string, base: CFrame, targetHeight: number): Model
	local model = Instance.new("Model")
	model.Name = slotName
	Core.markSlot(model, slotName, base, targetHeight)
	model.Parent = parent
	return model
end

-- Pose (ou repose) les attributs d'emplacement sur un modèle existant.
function Core.markSlot(model: Model, slotName: string, base: CFrame, targetHeight: number)
	model:SetAttribute("Slot", slotName)
	model:SetAttribute("TargetHeight", math.floor(targetHeight * 10 + 0.5) / 10)
	local look = base.LookVector
	model:SetAttribute("Base", base.Position)
	model:SetAttribute("Yaw", math.floor(math.deg(math.atan2(-look.X, -look.Z)) * 10 + 0.5) / 10)
	pcall(function()
		model.WorldPivot = base
	end)
	CollectionService:AddTag(model, Core.SlotTag)
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
function Core.hasStore(): boolean
	local store = ServerStorage:FindFirstChild(Core.StoreName)
	return store ~= nil and #store:GetChildren() > 0
end

-- Remplace les emplacements de `root` par les modèles de ServerStorage.ModelesDeco.
-- Renvoie le nombre d'éléments remplacés.
function Core.replaceSlots(root: Instance): number
	local store = ServerStorage:FindFirstChild(Core.StoreName)
	if not store or #store:GetChildren() == 0 then
		return 0
	end
	local replaced = 0
	local slots = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and CollectionService:HasTag(descendant, Core.SlotTag) then
			table.insert(slots, descendant)
		end
	end
	for index, slot in slots do
		local source = pickReplacement(store, slot:GetAttribute("Slot") or slot.Name, index)
		if source and slot.Parent then
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
-- Modèles maîtres clonés (performance)
------------------------------------------------------------------------
-- Un arbre (ou un objet) est construit une seule fois par variante, à l'origine et à une hauteur de
-- référence, puis cloné, tourné et mis à l'échelle à chaque emplacement : la construction est
-- rapide et Roblox regroupe le rendu des pièces identiques.

local masters: { [string]: Model } = {}

function Core.master(key: string, build: () -> Model): Model
	local model = masters[key]
	if not model then
		model = build()
		masters[key] = model
	end
	return model
end

-- Vide le cache des modèles maîtres (tests).
function Core.clearMasters()
	masters = {}
end

-- Clone un modèle maître (pied à l'origine) au repère `base`, mis à l'échelle `scale`.
-- `tint` (facultatif) éclaircit/assombrit légèrement les pièces nommées "Leaves" (variété).
function Core.placeClone(master: Model, parent: Instance, base: CFrame, scale: number, tint: number?): Model
	local model = master:Clone()
	local rot = base - base.Position
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local cf = item.CFrame
			item.Size = item.Size * scale
			item.CFrame = CFrame.new(base.Position + rot:VectorToWorldSpace(cf.Position * scale)) * rot * (cf - cf.Position)
			if tint and tint ~= 0 and item.Name == "Leaves" then
				item.Color = Core.shade(item.Color, tint)
			end
		elseif item:IsA("PointLight") or item:IsA("SpotLight") then
			item.Range = math.min(60, item.Range * scale)
		end
	end
	Core.markSlot(model, model:GetAttribute("Slot") or model.Name, base, (model:GetAttribute("TargetHeight") or 1) * scale)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------
-- Semis
------------------------------------------------------------------------

-- Sème `count` éléments dans un disque/anneau en évitant les zones refusées par `allowed`.
function Core.scatter(rng: Random, count: number, center: Vector3, minR: number, maxR: number, allowed: (Vector3) -> boolean, place: (Vector3) -> ())
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

-- Sème en gardant une distance minimale entre les éléments (forêts plus naturelles).
function Core.scatterSpaced(
	rng: Random,
	count: number,
	center: Vector3,
	minR: number,
	maxR: number,
	spacing: number,
	allowed: (Vector3) -> boolean,
	place: (Vector3) -> (),
	taken: { Vector3 }?
)
	local points = taken or {}
	return Core.scatter(rng, count, center, minR, maxR, function(pos)
		if not allowed(pos) then
			return false
		end
		for _, other in points do
			if (other - pos).Magnitude < spacing then
				return false
			end
		end
		return true
	end, function(pos)
		table.insert(points, pos)
		place(pos)
	end)
end

-- Repère au sol tourné au hasard (si `base` est un Vector3).
function Core.asCFrame(base: Vector3 | CFrame, rng: Random): CFrame
	if typeof(base) == "CFrame" then
		return base
	end
	return CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

return Core
