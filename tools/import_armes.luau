--!nocheck
-- Importe les armes d'un fichier .rbxl pour le Forgeron (v3.5) : chaque arme devient un modèle
-- assets/ModelesArmes/<id>.rbxm (-> ReplicatedStorage.ModelesArmes), repris par Modules/SwordBuilder
-- (style « modele », voir Config/Swords).
--
--   lune run tools/import_armes.luau <fichier.rbxl> tools/plan_armes.luau
--
-- La prise en main vient du plan (tools/plan_armes.luau) : point tenu par la main, direction de la
-- lame et épaisseur, dans le repère d'une pièce du fichier. Pour une arme tenue par un perso du
-- fichier (Tensa Zangetsu dans la main d'Ichigo, sabres de Zoro), on reprend exactement sa prise.
-- Le modèle obtenu suit le repère des épées du jeu : la main tient la pièce « Prise », la lame part
-- vers -Z, son plat est le plan XZ (épaisseur selon Y). Attributs : Pointe et Arriere (bouts de
-- l'arme selon Z), DebutLame (fin de la poignée), Largeur.
-- SÉCURITÉ : seules les pièces et leurs habillages sont copiés (scripts, sons, interfaces : non).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Enum = roblox.Enum

local OUT_DIR = "assets/ModelesArmes"
local SEP = " > "
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
	PointLight = true,
}

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

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function invisible(part): boolean
	if part.Transparency < 0.99 then
		return false
	end
	for _, d in part:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			return false
		end
	end
	return true
end

local function import(game, spec)
	local ws = game:GetService("Workspace")
	local source = resolve(ws, spec.source)
	local ref = resolve(ws, spec.repere)
	-- Repère de la main : Z = -lame, Y = épaisseur (plat de la lame), X = Y x Z
	local blade = v3(spec.lame).Unit
	local thick = v3(spec.epaisseur).Unit
	local z = -blade
	local y = (thick - z * thick:Dot(z)).Unit
	local x = y:Cross(z)
	local grip = ref.CFrame * CFrame.fromMatrix(v3(spec.prise), x, y, z)
	local list = source:IsA("BasePart") and { source } or {}
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	local model = Instance.new("Model")
	model.Name = spec.id
	local parts = {}
	for _, src in list do
		if invisible(src) then
			continue
		end
		local copy = src:Clone()
		for _, d in copy:GetChildren() do
			if d:IsA("BasePart") then
				d:Destroy()
			end
		end
		for _, d in copy:GetDescendants() do
			if d.Parent and not KEEP[d.ClassName] then
				d:Destroy()
			end
		end
		copy.Anchored = false
		copy.CanCollide = false
		copy.CanTouch = false
		copy.CanQuery = false
		copy.Massless = true
		copy.CFrame = grip:ToObjectSpace(src.CFrame) -- repère de la prise (origine = main)
		-- Maillage de bloc (BlockMesh, coin, sphère...) : sa mise à l'échelle passe dans la taille de
		-- la pièce (même rendu, mais une boîte qui colle à ce qu'on voit).
		local mesh = copy:FindFirstChildWhichIsA("DataModelMesh")
		if mesh and (mesh:IsA("BlockMesh") or mesh:IsA("CylinderMesh") or (mesh:IsA("SpecialMesh") and mesh.MeshType ~= Enum.MeshType.FileMesh)) then
			copy.Size = copy.Size * mesh.Scale
			mesh.Scale = Vector3.new(1, 1, 1)
		elseif mesh and spec.section then
			-- maillage de fichier : la pièce prend la section donnée (le maillage ne suit pas sa taille)
			copy.Size = Vector3.new(spec.section[1], spec.section[2], copy.Size.Z)
		end
		copy.Parent = model
		table.insert(parts, copy)
	end
	-- Bouts de l'arme selon Z, puis mise à la longueur voulue
	local lo, hi, wide = math.huge, -math.huge, 0
	for _, p in parts do
		local size = p.Size
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local q = p.CFrame * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
					lo, hi = math.min(lo, q.Z), math.max(hi, q.Z)
					wide = math.max(wide, math.abs(q.X))
				end
			end
		end
	end
	-- (un maillage de fichier est supposé remplir sa pièce, comme les poignées d'outils classiques)
	local k = spec.longueur / (hi - lo)
	for _, p in parts do
		local cf = p.CFrame
		p.Size = p.Size * k
		p.CFrame = CFrame.new(cf.Position * k) * (cf - cf.Position)
		local mesh = p:FindFirstChildWhichIsA("DataModelMesh")
		if mesh then
			if mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.FileMesh then
				mesh.Scale = mesh.Scale * k
			end
			mesh.Offset = mesh.Offset * k
		end
	end
	local prise = Instance.new("Part")
	prise.Name = "Prise"
	prise.Size = Vector3.new(0.2, 0.2, 0.2)
	prise.Transparency = 1
	prise.CanCollide = false
	prise.CanTouch = false
	prise.CanQuery = false
	prise.Massless = true
	prise.CFrame = CFrame.new()
	prise.Parent = model
	model.PrimaryPart = prise
	model:SetAttribute("Pointe", lo * k)
	model:SetAttribute("Arriere", hi * k)
	model:SetAttribute("DebutLame", (spec.debutLame or -0.7) * k)
	model:SetAttribute("Largeur", math.max(wide * 2 * k, 0.2))
	model:SetAttribute("Source", spec.source)
	fs.writeFile(OUT_DIR .. "/" .. spec.id .. ".rbxm", roblox.serializeModel({ model }))
	print(
		string.format(
			"%-16s <- %s (%d pièces, longueur %.2f, pointe %.2f, arrière %.2f, largeur %.2f)",
			spec.id,
			spec.source,
			#parts,
			(hi - lo) * k,
			lo * k,
			hi * k,
			wide * 2 * k
		)
	)
end

local file, planFile = process.args[1], process.args[2]
assert(file and planFile, "usage : lune run tools/import_armes.luau <fichier.rbxl> tools/plan_armes.luau")
local game = roblox.deserializePlace(fs.readFile(file))
local plan = luau.load(fs.readFile(planFile), { debugName = planFile })()
pcall(fs.writeDir, OUT_DIR)
for _, spec in plan do
	import(game, spec)
end
