-- Sauvegarde des joueurs (DataStore) avec verrou de session, sauvegarde auto et synchro client.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Modules.Remotes)

local DataService = {}

local STORE_NAME = "AnimeTycoon_v1"
local AUTOSAVE_INTERVAL = 90
local LOCK_TIMEOUT = 600

local store: DataStore? = nil
local storeAvailable = false

local profiles: { [Player]: { data: any, dirty: boolean, loaded: boolean } } = {}
local loadedCallbacks = {}
local removingCallbacks = {}
local pendingSync: { [Player]: boolean } = {}

local DataSync = Remotes.event("DataSync")
local Notify = Remotes.event("Notify")

local function template()
	return {
		version = 2,
		coins = Economy.StartingCoins,
		totalCoins = 0,
		materials = {},
		relics = {},
		traitCrystals = Economy.StartingTraitCrystals,
		swords = { rouillee = true },
		equippedSword = "rouillee",
		characters = {},
		team = {},
		incubators = {},
		upgrades = {},
		index = {},
		stash = 0,
		stats = { kills = 0, bossKills = 0, hatched = 0, playtime = 0, fusions = 0, trades = 0, evolutions = 0 },
		shop = { window = 0, bought = {} },
		isNew = true,
		starterGiven = false,
		firstJoin = os.time(),
		-- v3 : machine ROULER et arbre de compétences
		Skills = {}, -- { [idDeNœud] = true } (Config/SkillTree)
		RollCount = 0, -- nombre total de roulages
		X10Counter = 0, -- roulages depuis le dernier « Chance x10 »
		Pity = { legendary = 0, mythic = 0, secret = 0 }, -- persos tirés depuis la dernière rareté garantie
		AutoRoll = false,
		RolledQueue = {}, -- persos tirés en attente sur l'estrade : { key, id, rarity, aura?, trait?, price, dps }
		DisplayPins = {}, -- { ["numéro de case"] = uid } : unités placées à la main sur les cases de la base
		FirstCollectDone = false,
	}
end

-- Mise à niveau des anciennes sauvegardes (après reconcile, qui ajoute les champs manquants).
local function migrate(data)
	-- Sauvegarde abîmée : tout champ qui devrait être une table et n'en est pas une est remis
	-- à sa valeur par défaut (sinon la suite planterait).
	for key, value in template() do
		if type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
		end
	end
	local version = tonumber(data.version) or 1
	if version < 2 then
		-- v1 -> v2 : nouveaux champs de la machine ROULER (déjà ajoutés par reconcile).
		-- Les anciens joueurs ont déjà leurs persos : pas de perso offert à la première collecte.
		if next(data.characters) ~= nil then
			data.FirstCollectDone = true
		end
	end
	-- Nettoyage défensif (sauvegardes abîmées ou modifiées à la main).
	if type(data.Skills) ~= "table" then
		data.Skills = {}
	end
	if type(data.RolledQueue) ~= "table" then
		data.RolledQueue = {}
	end
	if type(data.DisplayPins) ~= "table" then
		data.DisplayPins = {}
	end
	for key, value in data.DisplayPins do
		if type(value) ~= "string" and value ~= false then
			data.DisplayPins[key] = nil -- uid, ou false = case laissée vide exprès
		end
	end
	for _, key in { "legendary", "mythic", "secret" } do
		data.Pity[key] = math.max(0, math.floor(tonumber(data.Pity[key]) or 0))
	end
	data.RollCount = math.max(0, math.floor(tonumber(data.RollCount) or 0))
	data.X10Counter = math.max(0, math.floor(tonumber(data.X10Counter) or 0))
	data.version = 2
	return data
end
DataService.migrate = migrate

local function reconcile(data, default)
	for key, value in default do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

function DataService:Init(services)
	self.services = services
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		-- Vérifie que l'accès aux API est autorisé (sinon on joue sans sauvegarde).
		local probeOk = pcall(function()
			(result :: DataStore):GetAsync("__probe")
		end)
		storeAvailable = probeOk
	end
	if not storeAvailable then
		warn("[AnimeTycoon] DataStore indisponible : la progression ne sera PAS sauvegardée. (Studio : Game Settings > Security > Enable Studio Access to API Services)")
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function loadData(player: Player)
	if not storeAvailable or not store then
		return template()
	end
	local key = keyFor(player)
	local result = nil
	for attempt = 1, 6 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(current)
				current = current or template()
				local lock = current.lock
				local now = os.time()
				if lock and lock.jobId ~= game.JobId and now - (lock.time or 0) < LOCK_TIMEOUT and attempt < 6 then
					result = "locked"
					return nil -- n'écrit rien
				end
				current.lock = { jobId = game.JobId, time = now }
				result = current
				return current
			end)
		end)
		if ok and type(result) == "table" then
			return result
		end
		if not ok then
			warn("[AnimeTycoon] Échec du chargement (" .. tostring(err) .. "), nouvel essai...")
		end
		task.wait(attempt * 2)
	end
	return nil
end

local function saveData(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not profile.loaded or not storeAvailable or not store then
		return
	end
	local snapshot = deepCopy(profile.data)
	snapshot.lock = if release then nil else { jobId = game.JobId, time = os.time() }
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(current)
			if current and current.lock and current.lock.jobId ~= game.JobId and os.time() - (current.lock.time or 0) < LOCK_TIMEOUT then
				-- Un autre serveur a la main : on n'écrase pas.
				return nil
			end
			return snapshot
		end)
	end)
	if ok then
		profile.dirty = false
	else
		warn("[AnimeTycoon] Échec de la sauvegarde de " .. player.Name .. " : " .. tostring(err))
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_onPlayerAdded(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if profile.loaded then
					task.spawn(saveData, player, false)
				end
			end
		end
	end)

	-- Temps de jeu
	task.spawn(function()
		while true do
			task.wait(60)
			for _, profile in profiles do
				if profile.loaded then
					profile.data.stats.playtime += 60
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not storeAvailable then
			return
		end
		local threads = 0
		for player in profiles do
			threads += 1
			task.spawn(function()
				saveData(player, true)
				threads -= 1
			end)
		end
		local start = os.clock()
		while threads > 0 and os.clock() - start < 25 do
			task.wait(0.2)
		end
	end)
end

function DataService:_onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	profiles[player] = { data = nil, dirty = false, loaded = false }
	local data = loadData(player)
	if not player.Parent then
		profiles[player] = nil
		return
	end
	if not data then
		player:Kick("Impossible de charger ta sauvegarde. Réessaie dans un instant !")
		profiles[player] = nil
		return
	end
	data.lock = nil
	local okMigrate, migrateError = pcall(function()
		reconcile(data, template())
		migrate(data)
	end)
	if not okMigrate then
		-- Sauvegarde illisible : on ne garde pas un profil à moitié chargé (rien ne serait
		-- sauvegardé et le verrou resterait posé) ; on libère le verrou et on prévient le joueur.
		warn("[AnimeTycoon] Sauvegarde illisible pour " .. player.Name .. " : " .. tostring(migrateError))
		self:_releaseLock(player)
		profiles[player] = nil
		player:Kick("Ta sauvegarde n'a pas pu être lue. Réessaie dans un instant !")
		return
	end
	profiles[player].data = data
	profiles[player].loaded = true

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
	data.isNew = false
	self:Sync(player)
	if not storeAvailable then
		task.delay(4, function()
			Notify:FireClient(player, "⚠️ Sauvegarde désactivée (API Services non autorisées dans Studio).", "warning")
		end)
	end
end

-- Retire notre verrou de la sauvegarde sans rien changer d'autre.
function DataService:_releaseLock(player: Player)
	if not storeAvailable or not store then
		return
	end
	pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(current)
			if type(current) ~= "table" or type(current.lock) ~= "table" or current.lock.jobId ~= game.JobId then
				return nil
			end
			current.lock = nil
			return current
		end)
	end)
end

function DataService:_onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.loaded then
		for _, callback in removingCallbacks do
			local ok, err = pcall(callback, player, profile.data)
			if not ok then
				warn("[AnimeTycoon] Erreur à la déconnexion : " .. tostring(err))
			end
		end
		saveData(player, true)
	end
	profiles[player] = nil
	pendingSync[player] = nil
end

-- API -------------------------------------------------------------------

function DataService:OnPlayerLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		if profile.loaded then
			task.spawn(callback, player, profile.data)
		end
	end
end

function DataService:OnPlayerRemoving(callback: (Player, any) -> ())
	table.insert(removingCallbacks, callback)
end

function DataService:Get(player: Player)
	local profile = profiles[player]
	if profile and profile.loaded then
		return profile.data
	end
	return nil
end

function DataService:IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.loaded
end

-- Marque les données comme modifiées et programme une synchro vers le client.
function DataService:Sync(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return
	end
	profile.dirty = true
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	-- Regroupe les modifications rapprochées en un seul envoi.
	task.delay(0.25, function()
		pendingSync[player] = nil
		local current = profiles[player]
		if current and current.loaded and player.Parent then
			DataSync:FireClient(player, current.data)
		end
	end)
end

function DataService:SaveNow(player: Player)
	task.spawn(saveData, player, false)
end

function DataService:Reset(player: Player)
	local profile = profiles[player]
	if profile and profile.loaded then
		local fresh = template()
		for key in profile.data do
			profile.data[key] = nil
		end
		for key, value in fresh do
			profile.data[key] = value
		end
		self:Sync(player)
	end
end

-- Monnaie ---------------------------------------------------------------

function DataService:AddCoins(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	amount = math.floor(amount)
	data.coins += amount
	if amount > 0 then
		data.totalCoins += amount
	end
	self:Sync(player)
end

function DataService:SpendCoins(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or data.coins < amount then
		return false
	end
	data.coins -= math.floor(amount)
	self:Sync(player)
	return true
end

function DataService:AddMaterial(player: Player, materialId: string, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.materials[materialId] = math.max(0, (data.materials[materialId] or 0) + amount)
	self:Sync(player)
end

function DataService:AddRelic(player: Player, relicId: string, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.relics[relicId] = math.max(0, (data.relics[relicId] or 0) + amount)
	if data.relics[relicId] == 0 then
		data.relics[relicId] = nil
	end
	self:Sync(player)
end

function DataService:NewUid(): string
	return HttpService:GenerateGUID(false)
end

function DataService:CharacterCount(player: Player): number
	local data = self:Get(player)
	if not data then
		return 0
	end
	local count = 0
	for _ in data.characters do
		count += 1
	end
	return count
end

return DataService
