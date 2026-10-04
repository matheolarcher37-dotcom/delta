-- Décor de l'UNIVERS : change complètement toutes les 30 min, sur TOUTE la carte.
--
-- Chaque univers a son module dans World/Themes (Ninja, Occulte, Saiyan, Ocean, Pourfendeur) qui
-- construit, en taille réelle :
--   * le décor de l'anneau (village, école, arène, port, ville de nuit...) ;
--   * la nature de l'île (forêts, rochers, sous-bois) et son grand repère au bord de l'île ;
--   * l'horizon (montagnes, îles, navires...) et les particules d'ambiance.
-- Le sol de toute la carte (herbe, collines, falaises, pavés, eau...) prend les couleurs de
-- theme.sol, et le ciel / la lumière suivent theme.ciel (UniverseService).
--
-- Dans le fichier fourni, les 5 décors sont déjà construits : celui de l'univers affiché est dans
-- Workspace > World > Zone > Decor, les autres sont rangés dans ServerStorage > DecorsUnivers.
-- Tu peux les modifier dans Studio (glisse-en un dans Workspace pour le voir, puis remets-le) :
-- au changement d'univers, le jeu échange simplement ces dossiers, tes retouches sont gardées.

local ServerStorage = game:GetService("ServerStorage")

local Core = require(script.Parent.Kit.Core)

local UniverseDecor = {}

-- Modules d'univers (theme.decor -> nom du module dans World/Themes).
local MODULE_NAMES = {
	ninja = "Ninja",
	occulte = "Occulte",
	saiyan = "Saiyan",
	ocean = "Ocean",
	pourfendeur = "Pourfendeur",
}
local modules = {}

local function themeModule(key: string)
	if modules[key] == nil then
		local themes = script.Parent:FindFirstChild("Themes")
		local moduleScript = themes and themes:FindFirstChild(MODULE_NAMES[key] or "")
		modules[key] = moduleScript and require(moduleScript) or false
	end
	return modules[key] or nil
end

-- Construit le décor d'un univers (sans le placer).
function UniverseDecor.build(universe): Model
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	local rng = Random.new(universe.index * 1000 + 7)
	local module = themeModule(universe.theme.decor) or themeModule("ninja")
	module.build(decor, rng, universe.theme)
	decor:SetAttribute("UniverseId", universe.id)
	return decor
end

local function storage(): Folder
	local folder = ServerStorage:FindFirstChild("DecorsUnivers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DecorsUnivers"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

-- Colore les éléments marqués "UniverseTint" (cristal du hub, arène, arches...) aux couleurs de
-- l'univers et applique les couleurs / matériaux du sol de l'univers à toute la carte.
function UniverseDecor.tint(universe, root: Instance)
	Core.applySol(universe.theme.sol)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("UniverseTint") then
			descendant.Color = universe.color
			local light = descendant:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = universe.color
			end
		end
	end
end

-- Modèles de la Boîte à outils (ServerStorage > ModelesDeco) à la place des éléments remplaçables.
local function replaceOnce(decor: Instance)
	if not decor:GetAttribute("SlotsRemplaces") and Core.hasStore() then
		Core.replaceSlots(decor)
		decor:SetAttribute("SlotsRemplaces", true)
	end
end

-- Affiche le décor d'un univers (anneau, île, horizon). Les décors déjà construits (ou retouchés
-- dans Studio) sont simplement échangés avec ServerStorage.DecorsUnivers.
function UniverseDecor.apply(universe, zone: Instance)
	local store = storage()
	local current = zone:FindFirstChild("Decor")
	if current then
		local id = current:GetAttribute("UniverseId")
		if id == universe.id then
			replaceOnce(current)
			UniverseDecor.tint(universe, zone.Parent or zone)
			return current
		end
		if id and not store:FindFirstChild(id) then
			current.Name = id
			current.Parent = store
		else
			current:Destroy()
		end
	end
	local decor = store:FindFirstChild(universe.id)
	if decor then
		decor.Name = "Decor"
	else
		decor = UniverseDecor.build(universe)
	end
	pcall(function()
		(decor :: Model).ModelStreamingMode = Enum.ModelStreamingMode.Default
	end)
	decor.Parent = zone
	replaceOnce(decor)
	UniverseDecor.tint(universe, zone.Parent or zone)
	return decor
end

return UniverseDecor
