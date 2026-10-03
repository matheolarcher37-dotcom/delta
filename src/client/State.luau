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
	return Formulas.upgradeStats(State.data.upgrades)
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
