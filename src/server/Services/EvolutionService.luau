-- Évolution (Éveil) : quand un perso atteint son niveau max, on le fait évoluer à l'Autel d'Éveil
-- avec les matériaux de SON univers (qu'on ne trouve que quand cet univers est actif !).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local EvolutionService = {}

local CombatFX = Remotes.event("CombatFX")
local Announce = Remotes.event("Announce")

function EvolutionService:Init(services)
	self.services = services
end

function EvolutionService:Evolve(player: Player, uid: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(uid) ~= "string" then
		return false, "Erreur."
	end
	local entry = data.characters[uid]
	if not entry then
		return false, "Perso introuvable."
	end
	local cost = Formulas.evolutionCost(entry)
	if not cost then
		return false, "Ce perso est déjà au maximum ★★★ !"
	end
	if entry.level < cost.levelRequired then
		return false, "Niveau " .. cost.levelRequired .. " requis (actuellement " .. entry.level .. ")."
	end
	if data.coins < cost.coins then
		return false, "Il te manque 💰 " .. Formulas.formatNumber(cost.coins - data.coins)
	end
	for materialId, amount in cost.materials do
		if (data.materials[materialId] or 0) < amount then
			local material = Universes.getMaterial(materialId)
			return false, "Il te manque " .. (amount - (data.materials[materialId] or 0)) .. " × " .. (material and material.name or materialId)
		end
	end
	DataService:SpendCoins(player, cost.coins)
	for materialId, amount in cost.materials do
		DataService:AddMaterial(player, materialId, -amount)
	end
	entry.stars = cost.stars
	entry.xp = 0
	data.stats.evolutions += 1
	DataService:Sync(player)
	self.services.CharacterService:Refresh(player)
	self.services.TeamService:RefreshTeam(player)

	local desc = Formulas.describe(entry)
	local plot = self.services.PlotService:GetPlot(player)
	if plot then
		CombatFX:FireClient(player, "Evolve", { position = (plot.cf * CFrame.new(0, 8, 38)).Position, stars = entry.stars })
	end
	if entry.stars >= 3 then
		Announce:FireAllClients(
			"🌟 ÉVEIL ULTIME 🌟",
			player.DisplayName .. " a éveillé " .. (desc and desc.name or "un perso") .. " au rang ★★★ !",
			Color3.fromRGB(200, 140, 255)
		)
	end
	return true, (desc and desc.name or "Perso") .. " évolue au rang " .. string.rep("★", entry.stars) .. " !"
end

function EvolutionService:Start()
	Remotes.func("Evolve").OnServerInvoke = function(player, uid)
		return self:Evolve(player, uid)
	end
end

return EvolutionService
