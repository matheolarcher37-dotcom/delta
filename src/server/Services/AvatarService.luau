-- Construit les avatars du catalogue Roblox déclarés dans Config/Avatars.luau (optionnel)
-- et les range dans ReplicatedStorage.AvatarsCatalogue, où CharacterFactory les trouve.
-- Rassemble aussi les modèles perso de la galerie Studio (Workspace.GaleriePersos) et les persos
-- insérés depuis la Boîte à outils, reconnus par leur nom (voir Config/NomsOriginaux.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Avatars = require(Shared.Config.Avatars)
local Characters = require(Shared.Config.Characters)
local NomsOriginaux = require(Shared.Config.NomsOriginaux)

local AvatarService = {}

local function folder(name: string): Folder
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = ReplicatedStorage
	return created
end

-- La galerie visible dans Studio devient la bibliothèque de modèles du jeu.
function AvatarService:CollectGallery()
	local gallery = Workspace:FindFirstChild("GaleriePersos")
	if not gallery then
		return
	end
	local source = gallery:FindFirstChild("ModelesPersos")
	if source then
		local target = folder("ModelesPersos")
		for _, model in source:GetChildren() do
			if not target:FindFirstChild(model.Name) then
				model.Parent = target
			end
		end
	end
	gallery:Destroy()
end

-- Dossiers du jeu à ne pas fouiller (la carte, la galerie, les persos qui suivent les joueurs...).
local SKIP = { World = true, GaleriePersos = true, Followers = true, Camera = true, Terrain = true }

local function matchModel(model: Model, humanoid: Humanoid): string?
	local key = NomsOriginaux.match(model.Name) or NomsOriginaux.match(humanoid.DisplayName)
	local parent = model.Parent
	while not key and parent and parent ~= Workspace do
		key = NomsOriginaux.match(parent.Name)
		parent = parent.Parent
	end
	return key
end

-- Ramène un modèle de la Boîte à outils à la taille d'un perso R6 (≈ 5,3 studs).
local function normalizeSize(model: Model)
	local ok, size = pcall(function()
		return select(2, model:GetBoundingBox())
	end)
	if ok and size and (size.Y > 8 or size.Y < 3.5) then
		pcall(function()
			model:ScaleTo(model:GetScale() * 5.3 / size.Y)
		end)
	end
end

-- Persos insérés depuis la Boîte à outils n'importe où dans Workspace (ex. « Kid Naruto ») :
-- s'ils portent le nom d'un perso d'origine, ils remplacent le perso intégré correspondant.
function AvatarService:CollectUserModels(): { [string]: string }
	local found = {}
	local target
	local function visit(container: Instance)
		for _, child in container:GetChildren() do
			if SKIP[child.Name] and container == Workspace then
				continue
			end
			if Players:GetPlayerFromCharacter(child) then
				continue
			end
			local humanoid = child:IsA("Model") and child:FindFirstChildOfClass("Humanoid")
			if humanoid and child:FindFirstChild("HumanoidRootPart") then
				local key = matchModel(child :: Model, humanoid)
				if key and not found[key] then
					found[key] = child.Name
					for _, descendant in child:GetDescendants() do
						if descendant:IsA("LuaSourceContainer") then
							descendant:Destroy() -- les scripts des modèles gratuits ne servent pas (et peuvent être piégés)
						end
					end
					normalizeSize(child :: Model)
					target = target or folder("ModelesPersos")
					local previous = target:FindFirstChild(key)
					if previous then
						previous:Destroy()
					end
					child.Name = key
					child.Parent = target
				end
			elseif child:IsA("Model") or child:IsA("Folder") then
				visit(child)
			end
		end
	end
	visit(Workspace)
	for key, original in found do
		print("[AnimeTycoon] Modèle « " .. original .. " » utilisé pour " .. key)
	end
	return found
end

local function accessoryList(ids, accessoryType: Enum.AccessoryType)
	local list = {}
	for i, id in ids or {} do
		if type(id) == "number" then
			table.insert(list, { AssetId = id, AccessoryType = accessoryType, Order = i })
		elseif type(id) == "table" and id.Id then
			local kind = Enum.AccessoryType[id.Type or "Hat"] or accessoryType
			table.insert(list, { AssetId = id.Id, AccessoryType = kind, Order = i })
		end
	end
	return list
end

function AvatarService:_build(key: string, spec, target: Folder)
	local id = string.gsub(key, "_%d+$", "")
	local def = Characters.get(id) or Characters.Enemies[id]
	local look = def and def.look or {}
	local description = Instance.new("HumanoidDescription")
	local skin = spec.Skin or look.skin or Color3.fromRGB(255, 216, 180)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = spec.LegColor or look.bottom or skin
	description.RightLegColor = spec.LegColor or look.bottom or skin
	description.TorsoColor = spec.TorsoColor or look.top or skin
	if spec.Shirt then
		description.Shirt = spec.Shirt
	end
	if spec.Pants then
		description.Pants = spec.Pants
	end
	if spec.TShirt then
		description.GraphicTShirt = spec.TShirt
	end
	if spec.Face then
		description.Face = spec.Face
	end
	if spec.Head then
		description.Head = spec.Head
	end
	local accessories = accessoryList(spec.Hair, Enum.AccessoryType.Hair)
	for _, item in accessoryList(spec.Accessories, Enum.AccessoryType.Hat) do
		table.insert(accessories, item)
	end
	if #accessories > 0 then
		description:SetAccessories(accessories, true)
	end
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	model.Name = key
	model.Parent = target
end

function AvatarService:Init(services)
	self.services = services
	self:CollectUserModels()
	self:CollectGallery()
	local target = folder("AvatarsCatalogue")
	local pending = 0
	for key, spec in Avatars.List do
		if not target:FindFirstChild(key) then
			pending += 1
			task.spawn(function()
				local ok, err = pcall(function()
					self:_build(key, spec, target)
				end)
				if not ok then
					warn("[AnimeTycoon] Avatar du catalogue '" .. key .. "' impossible à créer : " .. tostring(err))
				end
				pending -= 1
			end)
		end
	end
	-- On attend (au plus 15 s) que les avatars soient prêts avant de faire apparaître les persos.
	local started = os.clock()
	while pending > 0 and os.clock() - started < 15 do
		task.wait(0.1)
	end
end

function AvatarService:Start() end

return AvatarService
