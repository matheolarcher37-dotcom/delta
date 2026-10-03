-- Événements célestes (météo) : Orage Électrique, Éclipse du Néant, Pluie d'Or, Lune de Sang.
-- Pendant un orage, la foudre frappe les bases et peut donner l'aura Foudre aux persos exposés !

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Auras = require(Shared.Config.Auras)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local EventService = {}

local Announce = Remotes.event("Announce")
local CombatFX = Remotes.event("CombatFX")
local Notify = Remotes.event("Notify")

local rng = Random.new()
local active = nil -- { def, endsAt }
local forced = nil

function EventService:Init(services)
	self.services = services
end

function EventService:_scheduled()
	local now = os.time()
	if forced and now < forced.endsAt then
		return forced.def, forced.endsAt
	end
	forced = nil
	local window = math.floor(now / Economy.EventInterval)
	local elapsed = now % Economy.EventInterval
	if elapsed < Economy.EventDuration then
		local id = Economy.EventOrder[window % #Economy.EventOrder + 1]
		return Economy.Events[id], window * Economy.EventInterval + Economy.EventDuration
	end
	return nil, nil
end

function EventService:Force(eventId: string)
	local def = Economy.Events[eventId]
	if def then
		forced = { def = def, endsAt = os.time() + Economy.EventDuration }
	end
end

function EventService:GetActive()
	return active and active.def or nil
end

function EventService:CoinMultiplier(): number
	return active and active.def.coinMultiplier or 1
end

function EventService:MaterialMultiplier(): number
	return active and active.def.materialMultiplier or 1
end

function EventService:AuraLuck(): number
	return (active and active.def.aura) and 2 or 1
end

function EventService:Start()
	task.spawn(function()
		local strikeTimer = 0
		while true do
			task.wait(1)
			local def, endsAt = self:_scheduled()
			local state = ReplicatedStorage:FindFirstChild("GameState")
			if def and (not active or active.def ~= def) then
				active = { def = def, endsAt = endsAt }
				Announce:FireAllClients("✨ " .. def.name .. " ✨", def.description, def.color)
			elseif not def and active then
				Notify:FireAllClients("L'événement " .. active.def.name .. " est terminé.", "info")
				active = nil
			end
			if state then
				state:SetAttribute("EventId", active and active.def.id or nil)
				state:SetAttribute("EventName", active and active.def.name or nil)
				state:SetAttribute("EventEndsAt", active and active.endsAt or nil)
				state:SetAttribute("NextEventAt", (math.floor(os.time() / Economy.EventInterval) + 1) * Economy.EventInterval)
			end
			if active and active.def.aura then
				strikeTimer += 1
				if strikeTimer >= 4 then
					strikeTimer = 0
					local ok, err = pcall(self._strike, self, active.def)
					if not ok then
						warn("[AnimeTycoon] éclair : " .. tostring(err))
					end
				end
			end
		end
	end)
end

-- Un éclair frappe un perso exposé au hasard sur une base occupée.
function EventService:_strike(def)
	local candidates = {}
	for _, plot in self.services.PlotService:GetPlots() do
		if plot.owner then
			for uid, info in self.services.CharacterService:GetDisplayModels(plot.owner) do
				table.insert(candidates, { player = plot.owner, uid = uid, model = info.model })
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	local position = pick.model.PrimaryPart and pick.model.PrimaryPart.Position
	if not position then
		return
	end
	CombatFX:FireAllClients("Strike", { position = position, color = def.color, aura = def.aura })
	if rng:NextNumber() > def.strikeChance then
		return
	end
	local DataService = self.services.DataService
	local data = DataService:Get(pick.player)
	local entry = data and data.characters[pick.uid]
	if not entry then
		return
	end
	local newAura = Auras.get(def.aura)
	local current = Auras.get(entry.aura)
	if current and newAura and current.multiplier >= newAura.multiplier then
		return
	end
	entry.aura = def.aura
	DataService:Sync(pick.player)
	self.services.CharacterService:Refresh(pick.player)
	local desc = Formulas.describe(entry)
	Notify:FireClient(pick.player, "⚡ " .. (desc and desc.name or "Un perso") .. " a reçu l'aura " .. (newAura and newAura.name or "") .. " !", "success")
end

return EventService
