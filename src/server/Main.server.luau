-- Point d'entrée serveur d'ANIME TYCOON.
-- 1) construit la carte, 2) initialise puis démarre chaque service dans l'ordre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Modules.Remotes) -- crée les RemoteEvents / RemoteFunctions

local WorldBuilder = require(script.Parent.World.WorldBuilder)
WorldBuilder.build()

local ORDER = {
	"AvatarService",
	"DataService",
	"PlotService",
	"CharacterService",
	"TeamService",
	"CombatService",
	"UniverseService",
	"ShopService",
	"HatchService",
	"EvolutionService",
	"FusionService",
	"TraitService",
	"HubService",
	"SwordService",
	"TradeService",
	"EventService",
	"LeaderboardService",
	"AdminService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(script.Parent.Services[name])
end
for _, name in ORDER do
	services[name]:Init(services)
end
for _, name in ORDER do
	local ok, err = pcall(services[name].Start, services[name])
	if not ok then
		warn("[AnimeTycoon] Échec du démarrage de " .. name .. " : " .. tostring(err))
	end
end

print("[AnimeTycoon] Serveur prêt ! Univers actuel : " .. services.UniverseService:GetCurrent().name)
