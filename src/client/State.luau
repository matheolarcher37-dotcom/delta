-- État côté client : dernière copie des données du joueur + état global du jeu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local State = {}

State.data = nil
local listeners = {}

function State.onChanged(callback: (any) -> ()): () -> ()
	table.insert(listeners, callback)
	if State.data then
		task.spawn(callback, State.data)
	end
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

Remotes.event("DataSync").OnClientEvent:Connect(function(data)
	State.data = data
	for _, callback in listeners do
		task.spawn(callback, data)
	end
end)

function State.gameState(): Folder
	return ReplicatedStorage:WaitForChild("GameState") :: Folder
end

function State.now(): number
	return Workspace:GetServerTimeNow()
end

function State.universe()
	local id = State.gameState():GetAttribute("UniverseId")
	return Universes.get(id or "") or Universes.List[1]
end

function State.stats()
	if not State.data then
		return Formulas.upgradeStats({})
	end
	return Formulas.upgradeStats(State.data.upgrades, State.data.Skills)
end

------------------------------------------------------------------------
-- Machine ROULER + arbre de compétences (Config/SkillTree, créé par le domaine BASE).
-- Tant que ces données n'existent pas (anciennes sauvegardes), on renvoie des valeurs par défaut.
------------------------------------------------------------------------

local skillTreeModule = nil
function State.skillTree()
	if skillTreeModule == nil then
		local config = Shared:FindFirstChild("Config")
		local module = config and config:FindFirstChild("SkillTree")
		local ok, result = false, nil
		if module then
			ok, result = pcall(require, module)
		end
		if ok and type(result) == "table" and result.Nodes then
			skillTreeModule = result
		else
			skillTreeModule = require(script.Parent.UI.SkillTreeExample)
		end
	end
	return skillTreeModule
end

function State.skills(): { [string]: boolean }
	return (State.data and State.data.Skills) or {}
end

-- Statistiques de l'arbre : { luck, rollsPerPull, rollCooldown, x10Every, pityMult, autoRoll, ... }.
function State.treeStats()
	local tree = State.skillTree()
	local ok, stats = pcall(tree.stats, State.skills())
	if ok and type(stats) == "table" then
		return stats
	end
	return { luck = 1, rollsPerPull = 1, rollCooldown = 3.5, x10Every = 10, pityMult = 1, autoRoll = false, income = 1, damage = 1, crit = 0, critDamage = 2, unitSlots = 0 }
end

-- État du roulage (pitié, compteur x10...) à partir des données du joueur.
function State.rollInfo()
	local data = State.data or {}
	local stats = State.treeStats()
	local every = math.max(1, math.floor(stats.x10Every or 10))
	local counter = tonumber(data.X10Counter) or 0
	return {
		count = tonumber(data.RollCount) or 0,
		x10Every = every,
		-- Même calcul que le serveur (RollService:Roll) : x10 quand X10Counter + 1 >= x10Every.
		x10In = math.max(1, every - counter),
		x10Counter = math.min(counter, every),
		pity = data.Pity or { legendary = 0, mythic = 0, secret = 0 },
		autoRoll = data.AutoRoll == true,
		autoUnlocked = stats.autoRoll == true,
		queue = data.RolledQueue or {},
		stats = stats,
	}
end

-- RemoteFunction facultative (créée par un autre domaine) : nil si elle n'existe pas encore.
function State.remoteFunction(name: string): RemoteFunction?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end
	return nil
end

function State.remoteEvent(name: string): RemoteEvent?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

-- Appelle une RemoteFunction en toute sécurité : renvoie (réussi, message|résultat, ...).
function State.invoke(name: string, ...): (boolean, any, any)
	local remote = State.remoteFunction(name)
	if not remote then
		return false, "Bientôt disponible !"
	end
	local args = table.pack(...)
	local ok, a, b, c = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "Erreur de connexion, réessaie."
	end
	return a == true, b, c
end

function State.inTeam(uid: string): boolean
	return State.data ~= nil and table.find(State.data.team, uid) ~= nil
end

-- Liste triée des persos possédés : { { uid, entry, desc, power } }
function State.sortedCharacters(filter: ((string, any) -> boolean)?)
	local list = {}
	if not State.data then
		return list
	end
	for uid, entry in State.data.characters do
		if not filter or filter(uid, entry) then
			local desc = Formulas.describe(entry)
			if desc then
				table.insert(list, { uid = uid, entry = entry, desc = desc, power = Formulas.power(entry) })
			end
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = State.inTeam(a.uid), State.inTeam(b.uid)
		if ta ~= tb then
			return ta
		end
		if a.power == b.power then
			return a.uid < b.uid
		end
		return a.power > b.power
	end)
	return list
end

return State
