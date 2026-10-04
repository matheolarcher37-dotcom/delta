-- Fabrique de modèles de persos : choisit la meilleure source disponible.
--   1) ReplicatedStorage.ModelesPersos : TES modèles (faits ou retouchés dans Studio).
--      Nom du modèle = identifiant du perso, avec ou sans étoiles : "ninja_maruto_2", "ninja_maruto".
--      Dans le fichier fourni, ces modèles sont visibles dans Workspace > GaleriePersos pendant
--      l'édition : modifie-les directement, le jeu les reprend au lancement.
--   2) ReplicatedStorage.AvatarsCatalogue : avatars construits depuis Config/Avatars.luau
--      (objets du catalogue Roblox : cheveux, vêtements, visage...).
--   3) CharacterBuilder : le perso R6 "peint" intégré.
-- Les modèles perso doivent être des rigs R6 (Torso, Head, "Left Arm"...) avec un HumanoidRootPart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterBuilder = require(script.Parent.CharacterBuilder)
local Painter = require(script.Parent.Painter)

local CharacterFactory = {}

CharacterFactory.Folders = { "ModelesPersos", "AvatarsCatalogue" }

local function lookup(folder: Instance, id: string, stars: number): Instance?
	for s = stars, 1, -1 do
		local found = folder:FindFirstChild(id .. "_" .. s)
		if found then
			return found
		end
	end
	return folder:FindFirstChild(id)
end

-- Renvoie le modèle à cloner pour ce perso (ou nil s'il faut utiliser le perso intégré).
function CharacterFactory.templateFor(id: string?, stars: number?): Model?
	if not id then
		return nil
	end
	for _, folderName in CharacterFactory.Folders do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			local found = lookup(folder, id, stars or 1)
			if found and found:IsA("Model") and found:FindFirstChild("HumanoidRootPart") then
				return found
			end
		end
	end
	return nil
end

-- Hauteur du HumanoidRootPart au-dessus des pieds.
function CharacterFactory.rootHeight(model: Model): number
	local stored = model:GetAttribute("RootHeight")
	if stored then
		return stored
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ok, height = pcall(function()
		local cf, size = model:GetBoundingBox()
		return (root :: BasePart).CFrame.Position.Y - (cf.Position.Y - size.Y / 2)
	end)
	if ok and height and height > 0.5 then
		return height
	end
	return CharacterBuilder.RootHeight * (model:GetAttribute("BaseScale") or 1)
end

-- Prépare un modèle personnalisé cloné (physique, Humanoid, animations, échelle).
function CharacterFactory.prepare(model: Model, options)
	local opts = options or {}
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.PrimaryPart = root
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanTouch = false
			if descendant ~= root then
				descendant.CanCollide = false
				descendant.Massless = true
				descendant.CanQuery = descendant.Name == "Torso" or descendant.Name == "Head" or descendant.Name == "UpperTorso"
			end
			if opts.collisionGroup then
				descendant.CollisionGroup = opts.collisionGroup
			end
		elseif descendant:IsA("BaseScript") then
			descendant:Destroy() -- pas de scripts dans les persos (ex. "Animate" des avatars)
		end
	end
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.Massless = false
	root.Anchored = opts.anchored == true

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if opts.humanoid and not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.Parent = model
	end
	if humanoid then
		humanoid.WalkSpeed = opts.walkSpeed or 16
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.MaxHealth = 1e9
		humanoid.Health = 1e9
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid
		end
	else
		local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
		controller.Parent = model
		if not controller:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = controller
		end
	end

	local scale = opts.scale or 1
	local baseHeight = CharacterFactory.rootHeight(model)
	if scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	model:SetAttribute("BaseScale", scale)
	model:SetAttribute("RootHeight", baseHeight * scale)
	model:SetAttribute("CustomModel", true)
	return model
end

-- Construit le modèle d'un perso (ou d'un ennemi) avec la meilleure source disponible.
function CharacterFactory.build(id: string?, stars: number?, look, options)
	local opts = options or {}
	local template = CharacterFactory.templateFor(id, stars)
	local model
	if template then
		model = template:Clone()
		model.Name = opts.name or model.Name
		model = CharacterFactory.prepare(model, opts)
	else
		model = CharacterBuilder.build(look, opts)
	end
	-- Chargement progressif (StreamingEnabled) : un perso arrive toujours en entier chez le
	-- client (animations, étiquettes et effets ont besoin de toutes ses pièces).
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	return model
end

-- Modèle ancré pour les aperçus des menus.
function CharacterFactory.buildPreview(id: string?, stars: number?, look): Model
	local template = CharacterFactory.templateFor(id, stars)
	if not template then
		return CharacterBuilder.buildPreview(look)
	end
	local model = template:Clone()
	model.Name = "Preview"
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.PrimaryPart = root
	local guis = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		elseif descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("SurfaceGui") then
			table.insert(guis, descendant)
		end
	end
	-- Les ViewportFrame n'affichent pas les SurfaceGui : on les convertit en pièces.
	for _, gui in guis do
		Painter.bakeToParts(gui)
	end
	local height = CharacterFactory.rootHeight(model)
	model:PivotTo(CFrame.new(0, height, 0))
	return model
end

return CharacterFactory
