-- Commandes de test (dans Studio, ou pour le créateur du jeu / la liste ADMINS).
-- Dans le chat : "/at argent 100000" ou "!argent 100000". Tape "/at aide" pour la liste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local AdminService = {}

-- Ajoute ici les UserId des admins.
local ADMINS = {}

local Notify = Remotes.event("Notify")

function AdminService:Init(services)
	self.services = services
end

function AdminService:IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(ADMINS, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local HELP = table.concat({
	"argent <n> · univers · boss · event <orage|eclipse|pluie_or|lune_sang>",
	"relique <1|2|3> [n] · materiaux <n> · niveau <n> · etoiles <n> · reset",
}, "\n")

function AdminService:Run(player: Player, text: string)
	if not self:IsAdmin(player) then
		return
	end
	local args = string.split(text, " ")
	local command = string.lower(args[1] or "")
	local number = tonumber(args[2])
	local s = self.services
	local data = s.DataService:Get(player)
	if not data then
		return
	end
	if command == "aide" or command == "help" then
		Notify:FireClient(player, HELP, "info")
	elseif command == "argent" or command == "coins" then
		s.DataService:AddCoins(player, number or 100000)
		Notify:FireClient(player, "💰 +" .. Formulas.formatNumber(number or 100000), "success")
	elseif command == "univers" or command == "universe" then
		s.UniverseService:Skip()
		Notify:FireClient(player, "🌀 Passage à l'univers suivant...", "success")
	elseif command == "boss" then
		s.CombatService:SpawnBoss()
	elseif command == "event" then
		s.EventService:Force(args[2] or "orage")
	elseif command == "relique" or command == "relic" then
		local universe = s.UniverseService:GetCurrent()
		local relic = universe.relics[math.clamp(number or 1, 1, #universe.relics)]
		s.DataService:AddRelic(player, relic.id, tonumber(args[3]) or 1)
		Notify:FireClient(player, "🎁 " .. relic.name .. " ajoutée", "success")
	elseif command == "materiaux" or command == "materials" then
		for _, universe in Universes.List do
			s.DataService:AddMaterial(player, universe.material.id, number or 50)
		end
		Notify:FireClient(player, "✨ Matériaux ajoutés", "success")
	elseif command == "niveau" or command == "level" then
		for _, uid in data.team do
			local entry = data.characters[uid]
			if entry then
				entry.level = math.clamp(number or 30, 1, Formulas.levelCap(entry.stars))
			end
		end
		s.DataService:Sync(player)
		s.CharacterService:Refresh(player)
		s.TeamService:RefreshTeam(player)
	elseif command == "etoiles" or command == "stars" then
		for _, uid in data.team do
			local entry = data.characters[uid]
			if entry then
				entry.stars = math.clamp(number or 3, 1, 3)
			end
		end
		s.DataService:Sync(player)
		s.CharacterService:Refresh(player)
		s.TeamService:RefreshTeam(player)
	elseif command == "reset" then
		s.DataService:Reset(player)
		s.CharacterService:Refresh(player)
		s.TeamService:RefreshTeam(player)
		s.PlotService:RefreshOwnerContent(player)
		s.HatchService:RefreshPedestals(player)
		Notify:FireClient(player, "Données réinitialisées.", "warning")
	end
end

function AdminService:Start()
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "!" then
				self:Run(player, string.sub(message, 2))
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	-- Commande "/at ..." pour le nouveau chat (TextChatService).
	local ok = pcall(function()
		local command = Instance.new("TextChatCommand")
		command.Name = "AnimeTycoonAdmin"
		command.PrimaryAlias = "/at"
		command.SecondaryAlias = "/admin"
		command.Triggered:Connect(function(textSource, text)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if player then
				local rest = string.match(text, "^%S+%s*(.*)$") or ""
				self:Run(player, rest)
			end
		end)
		command.Parent = TextChatService
	end)
	if not ok then
		warn("[AnimeTycoon] TextChatCommand indisponible, utilise '!commande' dans le chat.")
	end
end

return AdminService
