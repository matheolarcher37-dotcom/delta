-- CLASSEMENTS : leaderstats (Tab) + trois grands tableaux dans le monde (World/LeaderboardBoards) :
--   • Robux   : total de Robux dépensés dans le jeu (data.RobuxSpent, compté à chaque achat validé)
--   • Pièces  : les plus riches (pièces actuelles)
--   • Perso   : la meilleure unité (puissance du perso le plus fort)
-- Classements mondiaux avec OrderedDataStore (pcall, écritures espacées). Sans accès aux API
-- (Studio), les tableaux montrent les joueurs du serveur.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local TextFit = require(Shared.Modules.TextFit)
local Layout = require(Shared.Config.Layout)
local LeaderboardBoards = require(script.Parent.Parent.World.LeaderboardBoards)

local LeaderboardService = {}

local PUSH_INTERVAL = 120 -- secondes entre deux envois d'un joueur
local FETCH_INTERVAL = 120 -- secondes entre deux lectures des classements mondiaux
local MAX_VALUE = 2 ^ 53

local STORE_NAMES = {
	Robux = "AnimeTycoon_RobuxSpent_v1",
	Coins = "AnimeTycoon_Coins_v1",
	Power = "AnimeTycoon_BestUnit_v1",
}

local stores: { [string]: any } = {}
local globalTop: { [string]: { { name: string, value: number } } } = { Robux = {}, Coins = {}, Power = {} }
local globalOk: { [string]: boolean } = {}
local lastPushed: { [Player]: { [string]: number } } = {}
local lastPushTime: { [Player]: number } = {}
local dirty: { [Player]: boolean } = {}
local nameCache: { [number]: string } = {}

function LeaderboardService:Init(services)
	self.services = services
	for id, storeName in STORE_NAMES do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(storeName)
		end)
		if ok and store then
			stores[id] = store
		end
	end
end

-- Puissance totale = somme des puissances de l'équipe.
function LeaderboardService:TeamPower(player: Player): number
	local data = self.services.DataService:Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, uid in data.team do
		local entry = data.characters[uid]
		if entry then
			total += Formulas.power(entry)
		end
	end
	return total
end

-- Meilleure unité du joueur : puissance et nom.
function LeaderboardService:BestUnit(player: Player): (number, string?)
	local data = self.services.DataService:Get(player)
	if not data then
		return 0, nil
	end
	local best, bestName = 0, nil
	for _, entry in data.characters do
		local ok, power = pcall(Formulas.power, entry)
		if ok and type(power) == "number" and power > best then
			best = power
			local okDesc, desc = pcall(Formulas.describe, entry)
			bestName = okDesc and desc and desc.name or nil
		end
	end
	return math.floor(best), bestName
end

-- Valeur d'un joueur pour un classement.
function LeaderboardService:Value(player: Player, id: string): number
	local data = self.services.DataService:Get(player)
	if not data then
		return 0
	end
	local value = 0
	if id == "Robux" then
		value = tonumber(data.RobuxSpent) or 0
	elseif id == "Coins" then
		value = tonumber(data.coins) or 0
	elseif id == "Power" then
		value = self:BestUnit(player)
	end
	return math.floor(math.clamp(value, 0, MAX_VALUE))
end

-- Un achat vient d'être validé : on renvoie le total Robux bientôt (sans attendre 2 minutes).
function LeaderboardService:MarkDirty(player: Player)
	dirty[player] = true
end

function LeaderboardService:Start()
	self.services.DataService:OnPlayerLoaded(function(player)
		if player:FindFirstChild("leaderstats") then
			return
		end
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "💰 Pièces"
		coins.Parent = stats
		local power = Instance.new("IntValue")
		power.Name = "⚔️ Puissance"
		power.Parent = stats
		stats.Parent = player
	end)
	Players.PlayerRemoving:Connect(function(player)
		pcall(self._push, self, player)
		lastPushed[player] = nil
		lastPushTime[player] = nil
		dirty[player] = nil
	end)

	-- leaderstats + tableaux (données du serveur) toutes les 2 secondes.
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(2)
			tick += 1
			for _, player in Players:GetPlayers() do
				local data = self.services.DataService:Get(player)
				local stats = player:FindFirstChild("leaderstats")
				if data and stats then
					local coins = stats:FindFirstChild("💰 Pièces") :: IntValue?
					local powerValue = stats:FindFirstChild("⚔️ Puissance") :: IntValue?
					local power = self:TeamPower(player)
					if coins then
						coins.Value = math.floor(math.min(data.coins, MAX_VALUE))
					end
					if powerValue then
						powerValue.Value = power
					end
					player:SetAttribute("TeamPower", power)
				end
				-- Achat Robux validé : envoi rapide (au plus une fois toutes les 10 s).
				if dirty[player] and os.clock() - (lastPushTime[player] or 0) > 10 then
					dirty[player] = nil
					task.spawn(function()
						pcall(self._push, self, player)
					end)
				end
			end
			if tick % 2 == 0 then
				local ok, err = pcall(self._render, self)
				if not ok then
					warn("[AnimeTycoon] Classements : " .. tostring(err))
				end
			end
		end
	end)

	-- Classements mondiaux : envois espacés + lecture toutes les 2 minutes.
	task.spawn(function()
		task.wait(15)
		while true do
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastPushTime[player] or -math.huge) >= PUSH_INTERVAL - 1 then
					pcall(self._push, self, player)
				end
			end
			self:_fetch()
			task.wait(FETCH_INTERVAL)
		end
	end)
end

-- Envoie les valeurs du joueur (seulement celles qui ont changé).
function LeaderboardService:_push(player: Player)
	if not self.services.DataService:IsLoaded(player) then
		return
	end
	lastPushTime[player] = os.clock()
	local previous = lastPushed[player] or {}
	lastPushed[player] = previous
	for id, store in stores do
		local value = self:Value(player, id)
		if value > 0 and previous[id] ~= value then
			local ok = pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				previous[id] = value
			end
		end
	end
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(result) == "string" then
		nameCache[userId] = result
		return result
	end
	return "Joueur"
end

function LeaderboardService:_fetch()
	for id, store in stores do
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 10)
		end)
		local list = {}
		local okPage = ok
			and pages ~= nil
			and pcall(function()
				for _, item in pages:GetCurrentPage() do
					local userId = tonumber(item.key)
					table.insert(list, { name = userId and nameFor(userId) or "Joueur", value = tonumber(item.value) or 0 })
				end
			end)
		globalOk[id] = okPage == true
		if okPage then
			globalTop[id] = list
		end
	end
end

local function formatValue(id: string, value: number): string
	if id == "Robux" then
		return Formulas.formatNumber(value) .. " R$"
	elseif id == "Coins" then
		return "¥ " .. Formulas.formatNumber(value)
	end
	return "⚔ " .. Formulas.formatNumber(value)
end

-- Liste affichée : classement mondial s'il a pu être lu, sinon les joueurs du serveur.
function LeaderboardService:List(id: string): { { name: string, value: number, extra: string? } }
	local list = {}
	if globalOk[id] and #globalTop[id] > 0 then
		for _, row in globalTop[id] do
			table.insert(list, { name = row.name, value = row.value })
		end
	else
		for _, player in Players:GetPlayers() do
			local value = self:Value(player, id)
			if value > 0 then
				local extra = nil
				if id == "Power" then
					local _, unitName = self:BestUnit(player)
					extra = unitName
				end
				table.insert(list, { name = player.DisplayName, value = value, extra = extra })
			end
		end
		table.sort(list, function(a, b)
			return a.value > b.value
		end)
	end
	return list
end

-- Retrouve (ou reconstruit, sur une ancienne carte) les tableaux.
function LeaderboardService:_boards(): { [string]: Instance }
	local world = Workspace:FindFirstChild("World")
	if not world then
		return {}
	end
	local folder = world:FindFirstChild("Boards")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Boards"
		folder.Parent = world
	end
	local result = {}
	local missing = false
	for _, info in LeaderboardBoards.List do
		local model = folder:FindFirstChild(info.name)
		if model then
			result[info.id] = model
		else
			missing = true
		end
	end
	if missing and not self._rebuilt then
		self._rebuilt = true
		local old = folder:FindFirstChild("Leaderboard")
		if old then
			old:Destroy()
		end
		for _, model in LeaderboardBoards.build(folder, Layout.Leaderboard) do
			for _, info in LeaderboardBoards.List do
				if model.Name == info.name then
					result[info.id] = model
				end
			end
		end
	end
	return result
end

function LeaderboardService:_render()
	for id, model in self:_boards() do
		local panel = model:FindFirstChild("Panel")
		local gui = panel and panel:FindFirstChild("Display")
		local bg = gui and gui:FindFirstChild("Fond")
		if bg then
			local list = self:List(id)
			for i = 1, LeaderboardBoards.Rows do
				local row = bg:FindFirstChild("Row" .. i)
				if row then
					local entry = list[i]
					local name = row:FindFirstChild("Nom") :: TextLabel?
					local value = row:FindFirstChild("Valeur") :: TextLabel?
					if name then
						TextFit.set(name, entry and (entry.extra and (entry.name .. "  ·  " .. entry.extra) or entry.name) or "—")
					end
					if value then
						TextFit.set(value, entry and formatValue(id, entry.value) or "")
					end
				end
			end
		end
	end
end

return LeaderboardService
