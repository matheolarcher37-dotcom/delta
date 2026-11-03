--!nocheck
-- Importe des persos de la Boîte à outils (R15 ou R6) depuis un fichier .rbxl et les range dans
-- assets/ModelesPersos (un fichier .rbxm par perso et par étoile), où le jeu les reprend
-- (ReplicatedStorage > ModelesPersos, voir Modules/CharacterFactory).
--
-- Les rigs R15 sont convertis en rigs R6 qui gardent EXACTEMENT leur apparence : vêtements
-- (Shirt / Pants), tête et visage, cheveux, accessoires et pièces en plus (capes, queues, kits
-- « Morph », auras...) soudés au membre R6 qui occupe la même place. Les animations, épées et
-- effets du jeu (prévus pour le R6) marchent ainsi sur eux.
-- SÉCURITÉ : seules les pièces et leurs habillages (maillages, décalques, textures, particules,
-- lumières) sont copiés. Scripts, interfaces, sons, valeurs, remotes... sont tous laissés de côté
-- (des modèles de la Boîte à outils cachent des scripts « Runtime » / « ScreenBuilder »).
--
-- Usage :
--   lune run tools/import_persos.luau <fichier.rbxl>
--       -> liste des persos trouvés, avec leur chemin (« Dossier > Modèle », « Nom#2 » = le 2e
--          enfant de ce nom)
--   lune run tools/import_persos.luau <fichier.rbxl> --plan tools/plan_persos.luau
--       -> importe tout ce que décrit le plan (voir tools/plan_persos.luau)
--   lune run tools/import_persos.luau <fichier.rbxl> 1=ninja_maruto 4=ninja_maruto_2 ...
--       -> ancien mode : n = numéro dans la liste
-- Cibles : « id » = ★1 seulement, « id_2 » / « id_3 » = ★★ / ★★★, « id* » = le même modèle
-- pour toutes les étoiles, « id+ » = le même modèle à ★1, puis avec une aura à ★★ et une aura plus
-- forte à ★★★ (option aura = { r, g, b }). L'aura est notée sur le modèle (attributs AuraCouleur et
-- AuraEtoiles = force à chaque étoile) et ajoutée par le jeu : un seul fichier sert à ces étoiles.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local Enum = roblox.Enum

local OUT_DIR = "assets/ModelesPersos"
local SKIP = { World = true, GaleriePersos = true, Followers = true, Camera = true, Terrain = true }
local SEP = " > "
-- Ce qui peut habiller une pièce copiée (tout le reste est retiré).
local KEEP = {
	SpecialMesh = true,
	BlockMesh = true,
	CylinderMesh = true,
	FileMesh = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
	Attachment = true,
	ParticleEmitter = true,
	Beam = true,
	Trail = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
}
-- Effets visibles (une pièce transparente qui en porte un est gardée).
local EFFECTS = { ParticleEmitter = true, Beam = true, Trail = true, PointLight = true, SpotLight = true, SurfaceLight = true, Fire = true, Smoke = true, Sparkles = true }
local BUDGET = 180 -- pièces au plus par perso (comme les persos du jeu)

local function prop(inst, name)
	local ok, v = pcall(function()
		return inst[name]
	end)
	return ok and v or nil
end

-- Membres R15 -> membre R6 qui occupe la même place.
local R15_TO_R6 = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	HumanoidRootPart = "Torso",
	LeftUpperArm = "Left Arm",
	LeftLowerArm = "Left Arm",
	LeftHand = "Left Arm",
	RightUpperArm = "Right Arm",
	RightLowerArm = "Right Arm",
	RightHand = "Right Arm",
	LeftUpperLeg = "Left Leg",
	LeftLowerLeg = "Left Leg",
	LeftFoot = "Left Leg",
	RightUpperLeg = "Right Leg",
	RightLowerLeg = "Right Leg",
	RightFoot = "Right Leg",
}
local R6_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- Repères officiels des articulations R6 (comme Modules/CharacterBuilder), pour un torse de 2 de haut.
local ROT_A = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local ROT_L = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local ROT_R = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), ROT_A },
	{ "Neck", "Torso", "Head", Vector3.new(0, 1, 0), Vector3.new(0, -0.5, 0), ROT_A },
	{ "Left Shoulder", "Torso", "Left Arm", Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0), ROT_L },
	{ "Right Shoulder", "Torso", "Right Arm", Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0), ROT_R },
	{ "Left Hip", "Torso", "Left Leg", Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0), ROT_L },
	{ "Right Hip", "Torso", "Right Leg", Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0), ROT_R },
}

local function isJoint(inst): boolean
	return inst:IsA("JointInstance") or inst:IsA("WeldConstraint") or inst:IsA("NoCollisionConstraint")
end

-- Retire d'une copie tout ce qui n'est pas un habillage autorisé (scripts, GUI, sons...).
local function clean(inst)
	for _, d in inst:GetDescendants() do
		if d.Parent and not KEEP[d.ClassName] then
			d:Destroy()
		end
	end
end

-- Enfant de `parent` qui est une PIÈCE de ce nom (certains modèles ont aussi des Models « Right Arm »).
-- Les espaces en trop autour du nom sont ignorés (« Head » s'appelle parfois « Head  »).
local function partChild(parent, name: string)
	for _, c in parent:GetChildren() do
		if c:IsA("BasePart") and string.match(c.Name, "^%s*(.-)%s*$") == name then
			return c
		end
	end
	return nil
end

-- Texture d'un vêtement : les vieux modèles n'ont que l'ancienne adresse (ShirtTemplate...). Dans
-- le fichier du jeu, Roblox Studio refuse un vêtement dont la nouvelle adresse (ShirtTemplateContent)
-- diffère de l'ancienne (« Content property conflict ») : on recopie l'ancienne dans la nouvelle.
local CONTENT = { Shirt = "ShirtTemplate", Pants = "PantsTemplate", ShirtGraphic = "Graphic" }
local function syncContent(inst)
	local legacy = CONTENT[inst.ClassName]
	local value = legacy and prop(inst, legacy)
	if type(value) == "string" then
		inst[legacy .. "Content"] = roblox.Content.fromUri(value)
	end
end

local function isRig(model): boolean
	return model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") ~= nil and (partChild(model, "Torso") ~= nil or partChild(model, "UpperTorso") ~= nil)
end

-- Nom unique d'un enfant dans son parent (« Nom#2 » si plusieurs enfants portent ce nom).
local function segment(child): string
	local n, index = 0, 0
	for _, c in child.Parent:GetChildren() do
		if c.Name == child.Name then
			n += 1
			if c == child then
				index = n
			end
		end
	end
	return n > 1 and (child.Name .. "#" .. index) or child.Name
end

local function pathOf(inst, root): string
	local list = {}
	local cur = inst
	while cur and cur ~= root do
		table.insert(list, 1, segment(cur))
		cur = cur.Parent
	end
	return table.concat(list, SEP)
end

local function resolve(root, path: string)
	local cur = root
	for seg in string.gmatch(path .. SEP, "(.-)" .. SEP) do
		local name, k = string.match(seg, "^(.-)#(%d+)$")
		name = name or seg
		k = tonumber(k) or 1
		local found, n = nil, 0
		for _, c in cur:GetChildren() do
			if c.Name == name then
				n += 1
				if n == k then
					found = c
					break
				end
			end
		end
		assert(found, "introuvable : « " .. seg .. " » dans « " .. path .. " »")
		cur = found
	end
	return cur
end

-- Le rig d'une source : elle-même, ou le premier modèle humanoïde qu'elle contient.
local function rigOf(source)
	if isRig(source) then
		return source
	end
	for _, d in source:GetDescendants() do
		if isRig(d) then
			return d
		end
	end
	return nil
end

-- Liste des persos du Workspace : { model = source, rig = rig, path = chemin }.
local function findCharacters(game)
	local list = {}
	local ws = game:GetService("Workspace")
	local function visit(container, depth)
		for _, child in container:GetChildren() do
			if depth == 0 and SKIP[child.Name] then
				continue
			end
			if child:IsA("Model") or child:IsA("Folder") then
				if isRig(child) then
					table.insert(list, { model = child, rig = child, path = pathOf(child, ws) })
				else
					local before = #list
					visit(child, depth + 1)
					-- un modèle sans rig à lui mais avec un rig caché tout au fond
					if #list == before and child:IsA("Model") then
						local rig = rigOf(child)
						if rig then
							table.insert(list, { model = child, rig = rig, path = pathOf(child, ws) })
						end
					end
				end
			end
		end
	end
	visit(ws, 0)
	return list
end

-- Point du haut / du bas d'une pièce (le long de son axe Y).
local function topOf(p)
	return (p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)).Position
end
local function bottomOf(p)
	return (p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)).Position
end

-- CFrame d'un membre R6 qui couvre de `top` à `bottom`, orienté comme `ref`.
local function spanCFrame(top, bottom, ref)
	local mid = (top + bottom) / 2
	return CFrame.new(mid) * (ref.CFrame - ref.CFrame.Position), (top - bottom).Magnitude
end

local function inside(part, roots): boolean
	for _, r in roots do
		if part == r or part:IsDescendantOf(r) then
			return true
		end
	end
	return false
end

-- Une pièce invisible qui ne porte aucun effet ne sert à rien (repère « Middle » des kits Morph...).
local function invisible(part): boolean
	if part.Transparency < 0.99 then
		return false
	end
	for _, d in part:GetDescendants() do
		if EFFECTS[d.ClassName] and prop(d, "Enabled") ~= false then
			return false
		end
	end
	return true
end

-- Aura d'évolution : notée sur le modèle (couleur + force à chaque étoile), le jeu l'ajoute à la
-- construction (Modules/CharacterFactory). Un seul fichier sert ainsi à plusieurs étoiles.
local function setAura(model, rgb, forces: { number })
	model:SetAttribute("AuraCouleur", Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
	model:SetAttribute("AuraEtoiles", table.concat(forces, ","))
end

-- Convertit un rig (R15 ou R6) en rig R6 propre ; renvoie le nouveau modèle et un rapport.
local function convert(entry, name: string, opts)
	opts = opts or {}
	local outer, rig = entry.model, entry.rig
	local isR15 = partChild(rig, "UpperTorso") ~= nil
	local model = Instance.new("Model")
	model.Name = name
	local parts = {}
	local rest = {} -- CFrame de repos des nouveaux membres
	-- Parties à laisser de côté : options « sans » + autres persos (humanoïdes) rangés dans la source
	local excluded = {}
	for _, n in opts.sans or {} do
		table.insert(excluded, resolve(outer, n))
	end
	for _, d in outer:GetDescendants() do
		if d ~= rig and d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not rig:IsDescendantOf(d) then
			table.insert(excluded, d)
		end
	end

	local function newPart(partName, size, cf, color, material)
		local p = Instance.new("Part")
		p.Name = partName
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = false
		p.Parent = model
		parts[partName] = p
		rest[partName] = cf
		return p
	end

	local scale = 1
	local custom = opts.membres -- rig sur mesure (membres en maillages rangés dans des modèles)
	local ownerOf = {} -- pièce d'origine -> membre R6 imposé (rigs sur mesure)
	if custom then
		-- Torse : centre et orientation de la pièce de torse ; membres R6 invisibles placés par les
		-- articulations, à l'échelle du torse. Les maillages de chaque groupe sont soudés à leur membre
		-- à leur place exacte d'origine (rien ne bouge à l'arrêt).
		local torsoSrc = resolve(outer, custom.Torso)
		local ref = torsoSrc:IsA("BasePart") and torsoSrc or torsoSrc:FindFirstChildWhichIsA("BasePart", true)
		local _, size = (torsoSrc:IsA("Model") and torsoSrc or {
			GetBoundingBox = function()
				return ref.CFrame, ref.Size
			end,
		}):GetBoundingBox()
		scale = opts.echelle or (size.Y / 2)
		local torso = newPart("Torso", Vector3.new(2, 2, 1) * scale, CFrame.new(ref.CFrame.Position) * (ref.CFrame - ref.CFrame.Position), ref.Color)
		torso.Transparency = 1
		for limb, path in custom do
			local container = resolve(outer, path)
			local list = container:IsA("BasePart") and { container } or {}
			for _, d in container:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
			for _, d in list do
				ownerOf[d] = limb
			end
		end
		for _, limb in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local p = newPart(limb, Vector3.new(1, 2, 1) * scale, torso.CFrame, torso.Color)
			p.Transparency = 1
		end
	elseif isR15 then
		local ut, lt = partChild(rig, "UpperTorso"), partChild(rig, "LowerTorso")
		local torsoCF, torsoH = spanCFrame(topOf(ut), bottomOf(lt or ut), ut)
		newPart("Torso", Vector3.new(ut.Size.X, torsoH, ut.Size.Z), torsoCF, ut.Color, ut.Material)
		for _, side in { "Left", "Right" } do
			local upper, hand = partChild(rig, side .. "UpperArm"), partChild(rig, side .. "Hand")
			local cf, h = spanCFrame(topOf(upper), bottomOf(hand or upper), upper)
			newPart(side .. " Arm", Vector3.new(upper.Size.X, h, upper.Size.Z), cf, upper.Color, upper.Material)
			local thigh, foot = partChild(rig, side .. "UpperLeg"), partChild(rig, side .. "Foot")
			local lcf, lh = spanCFrame(topOf(thigh), bottomOf(foot or thigh), thigh)
			newPart(side .. " Leg", Vector3.new(thigh.Size.X, lh, thigh.Size.Z), lcf, thigh.Color, thigh.Material)
		end
		scale = torsoH / 2
	else
		for _, partName in { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local src = partChild(rig, partName)
			assert(src, name .. " : membre R6 absent (" .. partName .. ")")
			newPart(partName, src.Size, src.CFrame, src.Color, src.Material)
			if src.Transparency > 0 then
				parts[partName].Transparency = src.Transparency
			end
		end
		scale = parts.Torso.Size.Y / 2
	end
	if math.abs(scale - 1) < 0.06 then
		scale = 1
	end
	-- Tête : celle du modèle (maillage de tête, visage, attachements des chapeaux), sans ses joints.
	-- Option « tete » : chemin d'une autre pièce (ex. « Model > FakeHead » quand la vraie tête manque).
	local srcHead = opts.tete and resolve(outer, opts.tete) or (not custom and partChild(rig, "Head")) or nil
	if not srcHead and custom then
		srcHead = Instance.new("Part")
		srcHead.Name = "Head"
		srcHead.Size = Vector3.new(2, 1, 1) * scale
		srcHead.Transparency = 1
		srcHead.CFrame = parts.Torso.CFrame * CFrame.new(0, 1.5 * scale, 0)
	elseif not srcHead then
		for _, d in rig:GetDescendants() do
			local n = string.match(d.Name, "^%s*(.-)%s*$")
			if d:IsA("BasePart") and (n == "FakeHead" or n == "Head") and not inside(d, excluded) then
				srcHead = d
				break
			end
		end
	end
	assert(srcHead, name .. " : pas de tête")
	local head = srcHead:Clone()
	for _, d in head:GetChildren() do
		if d:IsA("BasePart") then
			d:Destroy()
		end
	end
	clean(head)
	head.Name = "Head"
	head.Anchored = false
	head.Parent = model
	parts.Head = head
	rest.Head = head.CFrame
	-- Racine au centre du torse
	local root = newPart("HumanoidRootPart", Vector3.new(2, 2, 1) * scale, rest.Torso, parts.Torso.Color)
	root.Transparency = 1
	root.CanCollide = false
	-- Articulations R6 (à l'échelle du torse pour les rigs agrandis)
	for _, j in JOINTS do
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0 = parts[j[2]]
		m.Part1 = parts[j[3]]
		m.C0 = CFrame.new(j[4] * scale) * j[6]
		m.C1 = CFrame.new(j[5] * scale) * j[6]
		m.Parent = parts[j[2]]
	end
	-- Place de chaque membre dans le modèle d'origine : les pièces en plus y sont soudées (même
	-- place par rapport à SON membre, même si les articulations R6 le décalent d'un poil)
	local geom = table.clone(rest)
	local torsoCF = rest.Torso
	for _, j in JOINTS do
		if j[2] == "Torso" then
			rest[j[3]] = torsoCF * (CFrame.new(j[4] * scale) * j[6]) * (CFrame.new(j[5] * scale) * j[6]):Inverse()
			parts[j[3]].CFrame = rest[j[3]]
		end
	end
	if custom then
		geom = table.clone(rest) -- les maillages gardent leur place exacte autour des membres posés
	end
	-- Humanoid R6
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	-- Vêtements classiques et couleurs du corps : ceux du rig d'abord, sinon ceux de la source
	for _, class in { "Shirt", "Pants", "ShirtGraphic", "BodyColors" } do
		local found = rig:FindFirstChildOfClass(class)
		if not found then
			for _, d in outer:GetDescendants() do
				if d.ClassName == class and not inside(d, excluded) then
					found = d
					break
				end
			end
		end
		if found then
			local copy = found:Clone()
			copy:ClearAllChildren() -- (rien d'autre que le vêtement lui-même)
			syncContent(copy)
			copy.Parent = model
		end
	end

	-- Graphe des pièces : soudures, articulations et attachements des accessoires
	local bodyOf = {}
	for _, d in (custom and {} or rig:GetChildren()) do
		local n = string.match(d.Name, "^%s*(.-)%s*$")
		if d:IsA("BasePart") and (R15_TO_R6[n] or table.find(R6_PARTS, n)) then
			bodyOf[d] = R15_TO_R6[n] or n
		end
	end
	bodyOf[srcHead] = "Head"
	local links = {}
	local function link(a, b)
		if a and b then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, d in outer:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			link(prop(d, "Part0"), prop(d, "Part1"))
		end
		-- une pièce rangée DANS un membre (ex. LeftUpperArm.larm) lui est rattachée
		if d:IsA("BasePart") and d.Parent and d.Parent:IsA("BasePart") then
			link(d, d.Parent)
		end
	end
	-- Accessoires : Handle relié au membre qui porte l'attachement du même nom
	for _, acc in outer:GetDescendants() do
		if acc:IsA("Accoutrement") then
			local handle = acc:FindFirstChild("Handle")
			local att = handle and handle:FindFirstChildOfClass("Attachment")
			if att then
				for body in bodyOf do
					if body:FindFirstChild(att.Name) then
						link(handle, body)
					end
				end
			end
		end
	end
	-- Chaque pièce en plus prend le membre R6 auquel elle est (indirectement) reliée
	local owner = {}
	local queue = {}
	for body, r6 in bodyOf do
		owner[body] = r6
		table.insert(queue, body)
	end
	for d, r6 in ownerOf do
		owner[d] = r6
		table.insert(queue, d)
	end
	local qi = 1
	while qi <= #queue do
		local p = queue[qi]
		qi += 1
		for _, n in links[p] or {} do
			if not owner[n] then
				owner[n] = owner[p]
				table.insert(queue, n)
			end
		end
	end
	local extras = {}
	for _, d in outer:GetDescendants() do
		if d:IsA("BasePart") and not bodyOf[d] and not inside(d, excluded) then
			table.insert(extras, d)
		end
	end
	-- Pièces reliées à aucun membre (kits « Morph » soudés par un script au lancement) : chaque
	-- groupe de pièces soudées entre elles va au membre le plus proche de son repère « Middle »
	-- (ou de sa poignée « Handle », sinon de sa plus grosse pièce).
	local function nearest(position)
		local best, dist = "Torso", math.huge
		for _, n in R6_PARTS do
			local dd = (geom[n].Position - position).Magnitude
			if dd < dist then
				best, dist = n, dd
			end
		end
		return best, dist
	end
	local far, farNames = 0, nil
	for _, src in extras do
		if owner[src] then
			continue
		end
		local group, stack = { src }, { src }
		local seen = { [src] = true }
		while #stack > 0 do
			local p = table.remove(stack)
			for _, n in links[p] or {} do
				if not seen[n] and n:IsA("BasePart") and not bodyOf[n] then
					seen[n] = true
					table.insert(group, n)
					table.insert(stack, n)
				end
			end
		end
		-- Repère du groupe : « Middle » (kits Morph), puis « Handle » (arme tenue en main)
		local anchor = nil
		for _, wanted in { "Middle", "Handle" } do
			for _, p in group do
				if not anchor and p.Name == wanted then
					anchor = p
				end
			end
		end
		if not anchor then
			local volume = -1
			for _, p in group do
				local v = p.Size.X * p.Size.Y * p.Size.Z
				if v > volume then
					anchor, volume = p, v
				end
			end
		end
		local limb, dist = nearest(anchor.CFrame.Position)
		if dist > 4 * scale then
			far += 1
			farNames = (farNames and farNames .. ", " or "") .. anchor.Name .. string.format(" (%.1f)", dist)
		end
		for _, p in group do
			owner[p] = limb
		end
	end
	local folder = Instance.new("Model")
	folder.Name = "Tenue"
	folder.Parent = model
	local kept, perLimb, dropped = 0, {}, 0
	for _, src in extras do
		if invisible(src) then
			dropped += 1
			continue
		end
		local r6 = owner[src]
		local copy = src:Clone()
		for _, d in copy:GetChildren() do
			if d:IsA("BasePart") then
				d:Destroy() -- les sous-pièces sont copiées pour elles-mêmes
			end
		end
		clean(copy)
		copy.Anchored = false
		copy.CanCollide = false
		copy.CanTouch = false
		copy.Massless = true
		copy.Parent = folder
		local weld = Instance.new("Weld")
		weld.Name = "Soudure"
		weld.Part0 = parts[r6]
		weld.Part1 = copy
		weld.C0 = geom[r6]:Inverse() * src.CFrame
		weld.C1 = CFrame.new()
		weld.Parent = copy
		kept += 1
		perLimb[r6] = (perLimb[r6] or 0) + 1
	end
	-- Particules et lumières posées sur la racine ou le torse d'origine : sur la nouvelle racine
	for _, n in { "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso" } do
		local src = partChild(rig, n)
		if src then
			for _, d in src:GetChildren() do
				if EFFECTS[d.ClassName] then
					local c = d:Clone()
					clean(c)
					c.Parent = (n == "HumanoidRootPart") and root or parts.Torso
				end
			end
		end
	end
	model.PrimaryPart = root
	local drift = 0
	for _, n in R6_PARTS do
		drift = math.max(drift, (geom[n].Position - rest[n].Position).Magnitude)
	end
	local total = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			total += 1
		end
	end
	return model,
		{
			kept = kept,
			dropped = dropped,
			r15 = isR15,
			drift = drift,
			far = far,
			farNames = farNames,
			scale = scale,
			total = total,
			perLimb = perLimb,
		}
end

-- Met le perso à l'échelle `k` autour de sa racine (pièces, maillages, soudures, attachements).
-- Les maillages de fichier (SpecialMesh FileMesh) ne suivent pas la taille de leur pièce.
local function rescale(model, k: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	local origin = root.CFrame
	local function scaled(cf)
		return CFrame.new(cf.Position * k) * (cf - cf.Position)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * k
			d.CFrame = origin * scaled(rel)
			local mesh = d:FindFirstChildWhichIsA("DataModelMesh")
			if mesh then
				if mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.FileMesh then
					mesh.Scale = mesh.Scale * k
				end
				mesh.Offset = mesh.Offset * k
			end
		elseif d:IsA("JointInstance") then
			d.C0 = scaled(d.C0)
			d.C1 = scaled(d.C1)
		elseif d:IsA("Attachment") then
			d.CFrame = scaled(d.CFrame)
		elseif d:IsA("Texture") then
			d.StudsPerTileU *= k
			d.StudsPerTileV *= k
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range *= k
		end
	end
end

-- Plafond de particules d'un perso (débit total, par seconde) : certains modèles en lancent des
-- milliers, et une base en montre jusqu'à 26 à la fois. Au-delà, tous les débits sont réduits d'autant.
local PARTICLE_CAP = 300
local function capParticles(model): number
	local total, list = 0, {}
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			total += d.Rate
			table.insert(list, d)
		end
	end
	if total > PARTICLE_CAP then
		local k = PARTICLE_CAP / total
		for _, e in list do
			e.Rate = e.Rate * k
		end
	end
	return total
end

local function save(model, id: string)
	fs.writeFile(OUT_DIR .. "/" .. id .. ".rbxm", roblox.serializeModel({ model }))
end

-- Importe une source vers une cible (voir l'en-tête) ; renvoie le rapport.
local function import(entry, target: string, opts)
	opts = opts or {}
	local mode = string.sub(target, -1)
	local id = (mode == "*" or mode == "+") and string.sub(target, 1, -2) or target
	local model, report = convert(entry, id, opts)
	-- Taille normale d'un perso du jeu (ou `taille` pour les géants : Titans, Barbe Neige...)
	local k = (opts.taille or 1) / report.scale
	if math.abs(k - 1) > 0.03 then
		rescale(model, k)
	end
	local particles = capParticles(model)
	-- Hauteur de la racine au-dessus des pieds, d'après les jambes (et ce qui leur est soudé) : une
	-- longue crinière ou une arme qui descend plus bas ne fait pas flotter le perso.
	local root = model:FindFirstChild("HumanoidRootPart")
	local lowest = math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local weld = p:FindFirstChild("Soudure")
			local limb = weld and weld.Part0 or p
			if limb.Name == "Left Leg" or limb.Name == "Right Leg" then
				if p.Transparency < 0.99 or p == limb then
					local cf = weld and (weld.Part0.CFrame * weld.C0) or p.CFrame
					local rel = root.CFrame:ToObjectSpace(cf)
					for _, sy in { -1, 1 } do
						for _, sx in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local q = rel * Vector3.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)
								lowest = math.min(lowest, q.Y)
							end
						end
					end
				end
			end
		end
	end
	model:SetAttribute("RootHeight", math.floor(-lowest * 100 + 0.5) / 100)
	assert(report.total <= BUDGET, string.format("%s : %d pièces (au plus %d)", id, report.total, BUDGET))
	model:SetAttribute("ImporteDe", "Boîte à outils")
	model:SetAttribute("Source", entry.path)
	if mode == "*" then
		model:SetAttribute("ToutesEtoiles", true)
	elseif mode == "+" then
		-- ★ tel quel, ★★ avec une aura, ★★★ avec une aura plus forte (même fichier)
		assert(opts.aura, id .. "+ : il faut une couleur d'aura (aura = { r, g, b })")
		model:SetAttribute("ToutesEtoiles", true)
		setAura(model, opts.aura, { 0, 1, 2 })
	else
		local star = tonumber(string.match(id, "_(%d)$")) or 1
		local forces = { 0, 0, 0 }
		if opts.aura then
			forces[star] = opts.force or 1
		end
		-- même modèle repris à ★★★ avec une aura (voir le plan) : pas de 2e fichier
		if opts.etoile3 then
			forces[3] = opts.etoile3.force or 2
		end
		if opts.aura or opts.etoile3 then
			setAura(model, opts.aura or opts.etoile3.aura, forces)
		end
	end
	save(model, id)
	local limbs = {}
	for limb, n in report.perLimb do
		table.insert(limbs, limb .. "=" .. n)
	end
	table.sort(limbs)
	print(
		string.format(
			"%-26s <- %s (%s, %d pièces, %d en plus [%s], %d invisibles retirées, écart %.2f%s%s%s)",
			target,
			entry.path,
			report.r15 and "R15 -> R6" or "R6",
			report.total,
			report.kept,
			table.concat(limbs, " "),
			report.dropped,
			report.drift,
			math.abs(k - 1) > 0.03 and string.format(", taille d'origine x%.2f -> x%.2f", report.scale, opts.taille or 1) or "",
			particles > PARTICLE_CAP and string.format(", particules %d/s -> %d/s", particles, PARTICLE_CAP) or "",
			report.far > 0 and string.format(", %d groupe(s) loin du corps : %s !", report.far, report.farNames) or ""
		)
	)
	return report
end

local file = process.args[1]
assert(file, "usage : lune run tools/import_persos.luau <fichier.rbxl> [--plan plan.luau | n=id ...]")
local game = roblox.deserializePlace(fs.readFile(file))
local list = findCharacters(game)
if #process.args < 2 then
	for i, entry in list do
		local count = 0
		for _, d in entry.model:GetDescendants() do
			if d:IsA("BasePart") then
				count += 1
			end
		end
		print(string.format("%d. %s (%s, %d pièces)", i, entry.path, partChild(entry.rig, "UpperTorso") and "R15" or "R6", count))
	end
	return
end
pcall(fs.writeDir, OUT_DIR)
if process.args[2] == "--plan" then
	local plan = luau.load(fs.readFile(process.args[3]), { debugName = process.args[3] })()
	local ws = game:GetService("Workspace")
	-- « id_3 » = le même modèle que « id_2 » avec une aura : noté sur le fichier de ★★ (un seul fichier)
	local byTarget, skip = {}, {}
	for _, row in plan do
		byTarget[row[2]] = row
	end
	for i, row in plan do
		local id2 = string.match(row[2], "^(.+)_3$")
		local twin = id2 and byTarget[id2 .. "_2"]
		if twin and twin[1] == row[1] and row.aura and not twin.aura then
			twin.etoile3 = { aura = row.aura, force = row.force or 2 }
			skip[i] = true
		end
	end
	local done, failed = 0, {}
	for i, row in plan do
		if skip[i] then
			print(string.format("%-26s = %s avec une aura", row[2], string.gsub(row[2], "_3$", "_2")))
			done += 1
			continue
		end
		local ok, err = pcall(function()
			local source = resolve(ws, row[1])
			local rig = rigOf(source)
			assert(rig, row[1] .. " : aucun rig humanoïde")
			import({ model = source, rig = rig, path = row[1] }, row[2], row)
		end)
		if ok then
			done += 1
		else
			table.insert(failed, row[2] .. " : " .. tostring(err))
		end
	end
	print(done .. " imports, " .. #failed .. " échecs")
	for _, f in failed do
		print("ÉCHEC " .. f)
	end
	if #failed > 0 then
		process.exit(1)
	end
	return
end
for i = 2, #process.args do
	local index, target = string.match(process.args[i], "^(%d+)=([%w_]+[%*%+]?)$")
	assert(index and target, "argument invalide : " .. process.args[i])
	local entry = list[tonumber(index)]
	assert(entry, "pas de modèle n°" .. index)
	import(entry, target)
end
