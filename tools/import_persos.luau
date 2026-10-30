--!nocheck
-- Importe des persos de la Boîte à outils (R15 ou R6) depuis un fichier .rbxl et les range dans
-- assets/ModelesPersos (un fichier .rbxm par perso et par étoile), où le jeu les reprend
-- (ReplicatedStorage > ModelesPersos, voir Modules/CharacterFactory).
--
-- Les rigs R15 sont convertis en rigs R6 qui gardent EXACTEMENT leur apparence : vêtements
-- (Shirt / Pants), tête et visage, cheveux, accessoires et pièces en plus (capes, queues, auras...)
-- soudés au membre R6 qui occupe la même place. Les animations, épées et effets du jeu (prévus
-- pour le R6) marchent ainsi sur eux. Les scripts des modèles sont retirés.
--
-- Usage :
--   lune run tools/import_persos.luau <fichier.rbxl>                 -> liste des modèles trouvés
--   lune run tools/import_persos.luau <fichier.rbxl> 1=ninja_maruto 4=ninja_maruto_2 ...
--     n = numéro du modèle dans la liste ; « id » = ★1 seulement, « id_2 » / « id_3 » = ★★ / ★★★,
--     « id* » = le même modèle pour toutes les étoiles du perso.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Enum = roblox.Enum

local OUT_DIR = "assets/ModelesPersos"
local SKIP = { World = true, GaleriePersos = true, Followers = true, Camera = true, Terrain = true }

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

-- Repères officiels des articulations R6 (comme Modules/CharacterBuilder).
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

-- Liste des persos (modèles avec un Humanoid, éventuellement dans un sous-modèle) du Workspace.
local function findCharacters(game)
	local list = {}
	local ws = game:GetService("Workspace")
	local function visit(container, depth)
		for _, child in container:GetChildren() do
			if depth == 0 and SKIP[child.Name] then
				continue
			end
			if child:IsA("Model") then
				local rig = nil
				if child:FindFirstChildOfClass("Humanoid") then
					rig = child
				else
					for _, sub in child:GetDescendants() do
						if sub:IsA("Model") and sub:FindFirstChildOfClass("Humanoid") then
							rig = sub
							break
						end
					end
				end
				if rig and rig:FindFirstChild("Head") and (rig:FindFirstChild("UpperTorso") or rig:FindFirstChild("Torso")) then
					table.insert(list, { model = child, rig = rig })
				elseif not rig then
					visit(child, depth + 1)
				end
			elseif child:IsA("Folder") then
				visit(child, depth + 1)
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

-- Convertit un rig (R15 ou R6) en rig R6 propre ; renvoie le nouveau modèle.
local function convert(entry, name: string)
	local outer, rig = entry.model, entry.rig
	local isR15 = rig:FindFirstChild("UpperTorso") ~= nil
	local model = Instance.new("Model")
	model.Name = name
	local parts = {}
	local rest = {} -- CFrame de repos des nouveaux membres

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

	if isR15 then
		local ut, lt = rig:FindFirstChild("UpperTorso"), rig:FindFirstChild("LowerTorso")
		local torsoCF, torsoH = spanCFrame(topOf(ut), bottomOf(lt or ut), ut)
		newPart("Torso", Vector3.new(ut.Size.X, torsoH, ut.Size.Z), torsoCF, ut.Color, ut.Material)
		for _, side in { "Left", "Right" } do
			local upper, hand = rig:FindFirstChild(side .. "UpperArm"), rig:FindFirstChild(side .. "Hand")
			local cf, h = spanCFrame(topOf(upper), bottomOf(hand or upper), upper)
			newPart(side .. " Arm", Vector3.new(upper.Size.X, h, upper.Size.Z), cf, upper.Color, upper.Material)
			local thigh, foot = rig:FindFirstChild(side .. "UpperLeg"), rig:FindFirstChild(side .. "Foot")
			local lcf, lh = spanCFrame(topOf(thigh), bottomOf(foot or thigh), thigh)
			newPart(side .. " Leg", Vector3.new(thigh.Size.X, lh, thigh.Size.Z), lcf, thigh.Color, thigh.Material)
		end
	else
		for _, partName in { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local src = rig:FindFirstChild(partName)
			newPart(partName, src.Size, src.CFrame, src.Color, src.Material)
		end
	end
	-- Tête : celle du modèle (maillage de tête, visage, attachements des chapeaux), sans ses joints
	local head = rig:FindFirstChild("Head"):Clone()
	for _, d in head:GetDescendants() do
		if isJoint(d) or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	head.Anchored = false
	head.Parent = model
	parts.Head = head
	rest.Head = head.CFrame
	-- Racine au centre du torse
	local root = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), rest.Torso, parts.Torso.Color)
	root.Transparency = 1
	root.CanCollide = false
	-- Articulations R6
	for _, j in JOINTS do
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0 = parts[j[2]]
		m.Part1 = parts[j[3]]
		m.C0 = CFrame.new(j[4]) * j[6]
		m.C1 = CFrame.new(j[5]) * j[6]
		m.Parent = parts[j[2]]
	end
	-- Place de chaque membre dans le modèle d'origine : les pièces en plus y sont soudées (même
	-- place par rapport à SON membre, même si les articulations R6 le décalent d'un poil)
	local geom = table.clone(rest)
	-- Les membres R6 se posent là où les articulations les mettent
	local torsoCF = rest.Torso
	for _, j in JOINTS do
		if j[2] == "Torso" then
			rest[j[3]] = torsoCF * (CFrame.new(j[4]) * j[6]) * (CFrame.new(j[5]) * j[6]):Inverse()
			parts[j[3]].CFrame = rest[j[3]]
		end
	end
	-- Humanoid R6
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	-- Vêtements classiques et couleurs du corps
	for _, d in outer:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Clone().Parent = model
		end
	end

	-- Graphe des pièces : soudures, articulations et attachements des accessoires
	local bodyOf = {}
	for _, d in rig:GetChildren() do
		if d:IsA("BasePart") and (R15_TO_R6[d.Name] or table.find(R6_PARTS, d.Name)) then
			bodyOf[d] = R15_TO_R6[d.Name] or d.Name
		end
	end
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
		if d:IsA("BasePart") and not bodyOf[d] then
			table.insert(extras, d)
		end
	end
	local folder = Instance.new("Model")
	folder.Name = "Tenue"
	folder.Parent = model
	local kept = 0
	for _, src in extras do
		local r6 = owner[src]
		if not r6 then
			-- pièce flottante : membre le plus proche
			local best, dist = "Torso", math.huge
			for _, n in R6_PARTS do
				local dd = (rest[n].Position - src.CFrame.Position).Magnitude
				if dd < dist then
					best, dist = n, dd
				end
			end
			r6 = best
		end
		local copy = src:Clone()
		for _, d in copy:GetChildren() do
			if d:IsA("BasePart") then
				d:Destroy() -- les sous-pièces sont copiées pour elles-mêmes
			end
		end
		for _, d in copy:GetDescendants() do
			if isJoint(d) or d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		copy.Anchored = false
		copy.CanCollide = false
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
	end
	-- Particules et lumières posées sur la racine ou le torse R15 : sur la nouvelle racine
	for _, n in { "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso" } do
		local src = rig:FindFirstChild(n)
		if src then
			for _, d in src:GetChildren() do
				if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") then
					d:Clone().Parent = (n == "HumanoidRootPart") and root or parts.Torso
				end
			end
		end
	end
	model.PrimaryPart = root
	local drift = 0
	for _, n in R6_PARTS do
		drift = math.max(drift, (geom[n].Position - rest[n].Position).Magnitude)
	end
	return model, kept, isR15, drift
end

local file = process.args[1]
assert(file, "usage : lune run tools/import_persos.luau <fichier.rbxl> [n=id ...]")
local game = roblox.deserializePlace(fs.readFile(file))
local list = findCharacters(game)
if #process.args < 2 then
	for i, entry in list do
		local hair = "?"
		for _, d in entry.model:GetDescendants() do
			if d:IsA("MeshPart") and string.find(string.lower(d.Name), "hair") then
				local c = prop(d, "MeshContent")
				hair = d.Name .. " " .. tostring(c and c.Uri or "")
				break
			end
		end
		print(string.format("%d. %s (%s) cheveux : %s", i, entry.model.Name, entry.rig:FindFirstChild("UpperTorso") and "R15" or "R6", hair))
	end
	return
end
pcall(fs.writeDir, OUT_DIR)
for i = 2, #process.args do
	local index, target = string.match(process.args[i], "^(%d+)=([%w_]+%*?)$")
	assert(index and target, "argument invalide : " .. process.args[i])
	local entry = list[tonumber(index)]
	assert(entry, "pas de modèle n°" .. index)
	local allStars = string.sub(target, -1) == "*"
	local id = allStars and string.sub(target, 1, -2) or target
	local model, kept, wasR15, drift = convert(entry, id)
	if allStars then
		model:SetAttribute("ToutesEtoiles", true)
	end
	model:SetAttribute("ImporteDe", "Boîte à outils")
	fs.writeFile(OUT_DIR .. "/" .. id .. ".rbxm", roblox.serializeModel({ model }))
	print(
		string.format(
			"%s <- modèle %s (%s, %d pièces en plus, écart des membres %.2f)%s",
			id,
			index,
			wasR15 and "R15 converti en R6" or "R6",
			kept,
			drift,
			allStars and ", toutes les étoiles" or ""
		)
	)
end
