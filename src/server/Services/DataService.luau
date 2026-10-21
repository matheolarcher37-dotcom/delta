-- Sauvegarde des joueurs (DataStore) avec verrou de session, sauvegarde auto et synchro client.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Characters = require(Shared.Config.Characters)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Modules.Formulas)
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
local pendingSync: { [Player]: number } = {} -- heure (os.clock) du prochain envoi prévu
local syncWindows: { [Player]: number } = {} -- fenêtre imposée pendant DataService:WithSyncWindow

local DataSync = Remotes.event("DataSync")
local Notify = Remotes.event("Notify")

local function template()
	return {
		version = 3,
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
		shop = { window = 0, bought = {} }, -- achats chez le MARCHAND pendant son passage actuel
		Items = {}, -- objets d'évolution achetés au marchand : { [idObjet] = nombre } (Config/EvolutionItems)
		isNew = true,
		starterGiven = false,
		firstJoin = os.time(),
		-- v3 : machine ROULER et arbre de compétences
		Skills = {}, -- { [idDeNœud] = true } (Config/SkillTree)
		RollCount = 0, -- nombre total de roulages
		X10Counter = 0, -- (ancien « Chance x10 », retiré en v3.2)
		Pity = { mythic = 0 }, -- persos tirés depuis le dernier Mythique (seule pitié du jeu)
		AutoRoll = false, -- « Lancer AFK » en cours (passe Robux AutoRoll) — remis à faux à l'arrivée
		AutoBuy = false, -- « Achat automatique » en cours (passe Robux AutoRollPlus) — idem
		RollMulti = 0, -- persos par roulage choisis (0 = le maximum des passes Roulage x2 / x3)
		-- Réglages de la fenêtre « Roulement automatique » (booléens explicites : faux = désactivé).
		AutoRollSettings = {
			pauseRarities = { common = false, uncommon = false, rare = false, epic = false, legendary = true, mythic = true, secret = true },
			pauseMutations = {}, -- { [mutation] = vrai } : l'AFK s'arrête sur ces mutations
			buyCharacters = {}, -- { [id du perso] = vrai } : cibles de l'achat automatique
			buyRarities = {}, -- { [rareté] = vrai }
			buyMutations = {}, -- { [mutation ou "aucune"] = vrai }
		},
		RolledQueue = {}, -- persos du dernier roulage, sur l'estrade : { key, id, rarity, aura? (= mutation), trait?, price, dps }
		DisplayPins = {}, -- { ["numéro de case"] = uid } : unités placées à la main sur les cases de la base
		FirstCollectDone = false,
		-- Boutique Robux (MonetizationService)
		Receipts = {}, -- { [PurchaseId] = os.time() } reçus déjà accordés (achats jamais donnés deux fois)
		RobuxPasses = {}, -- { [clé] = "studio" } passes simulés dans Studio (jamais appliqués en ligne)
		RobuxBoosts = {}, -- { [clé du boost] = heure de fin (os.time()) }
		RobuxSpent = 0, -- total de Robux dépensés dans le jeu (classement)
		RobuxSlots = 0, -- cases d'unités en plus (passe « Emplacements + », recalculé à chaque arrivée)
		RobuxOnce = {}, -- { [clé du produit] = os.time() } offres à achat unique déjà prises (Pack de départ)
		-- v3.2 : défis (Config/Quests) et zone anti-AFK. Les gemmes de trait = traitCrystals.
		Quests = {
			counters = {}, -- { [clé] = nombre } : kills par ennemi, coups de punching-ball...
			claimed = {}, -- { [idDéfi] = paliers réclamés }
			notified = {}, -- { [idDéfi] = dernier palier annoncé « prêt à réclamer » }
			daily = { day = 0, list = {}, base = {}, claimed = {}, bonus = false },
			punch = 0, -- coups du cycle en cours au punching-ball (0 → 1000)
		},
	}
end

-- v2 -> v3 (version 3.2) : rareté de BASE des persos, mutations, pitié du Mythique seulement.
local function migrateRollV3(data)
	-- Persos possédés : plus de rareté « de machine » collée dessus (ils reprennent la rareté
	-- de leur fiche) ; les anciennes auras deviennent des mutations (Doré -> Or).
	for _, entry in data.characters do
		if type(entry) == "table" then
			entry.rollRarity = nil
			entry.aura = Mutations.normalize(entry.aura)
		end
	end
	-- Estrade : chaque perso reprend sa rareté de base ; on garde les 3 plus rares.
	local queue = {}
	for _, item in data.RolledQueue do
		local def = type(item) == "table" and Characters.get(item.id)
		if def then
			if item.rarity == "secret" and not item.aura then
				item.aura = "arcenciel" -- l'ancien « Secret » = le Mythique Arc-en-ciel
			end
			item.aura = Mutations.normalize(item.aura)
			item.rarity = Economy.RollRarities[def.rarity] and def.rarity or "common"
			item.price = Formulas.rollPrice(item.rarity, item.aura, item.trait)
			table.insert(queue, item)
		end
	end
	table.sort(queue, function(a, b)
		local oa, ob = Economy.RollRarities[a.rarity].order, Economy.RollRarities[b.rarity].order
		if oa ~= ob then
			return oa > ob
		end
		return (tonumber(a.at) or 0) > (tonumber(b.at) or 0)
	end)
	data.RolledQueue = {}
	for i = 1, math.min(#queue, Economy.Roll.QueueMax) do
		table.insert(data.RolledQueue, queue[i])
	end
	-- Pitié : seul le Mythique en a une désormais ; plus de « Chance x10 ».
	data.Pity = { mythic = math.max(0, math.floor(tonumber(data.Pity.mythic) or 0)) }
	data.X10Counter = 0
end

-- Réglages de l'auto-roulage : tables de booléens propres (sauvegardes abîmées ou modifiées).
local function cleanAutoSettings(data)
	local settings = data.AutoRollSettings
	if type(settings) ~= "table" then
		settings = template().AutoRollSettings
		data.AutoRollSettings = settings
	end
	local valid = {
		pauseRarities = function(key)
			return Economy.RollRarities[key] ~= nil
		end,
		pauseMutations = function(key)
			return Mutations.List[key] ~= nil or key == Mutations.None
		end,
		buyCharacters = function(key)
			return Characters.get(key) ~= nil
		end,
		buyRarities = function(key)
			return Economy.RollRarities[key] ~= nil
		end,
		buyMutations = function(key)
			return Mutations.List[key] ~= nil or key == Mutations.None
		end,
	}
	for field, isValid in valid do
		if type(settings[field]) ~= "table" then
			settings[field] = {}
		end
		for key, value in settings[field] do
			if type(key) ~= "string" or type(value) ~= "boolean" or not isValid(key) then
				settings[field][key] = nil
			end
		end
	end
	for key, value in pairs(settings) do
		if valid[key] == nil then
			settings[key] = nil
		end
		local _ = value
	end
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
	-- Objets d'évolution : uniquement des nombres entiers positifs.
	for id, count in data.Items do
		local n = math.floor(tonumber(count) or 0)
		data.Items[id] = if type(id) == "string" and n > 0 then n else nil
	end
	if type(data.shop.bought) ~= "table" then
		data.shop.bought = {}
	end
	data.Pity.mythic = math.max(0, math.floor(tonumber(data.Pity.mythic) or 0))
	-- Boutique Robux
	for key, value in data.Receipts do
		if type(key) ~= "string" or type(value) ~= "number" then
			data.Receipts[key] = nil
		end
	end
	for key, value in data.RobuxBoosts do
		if type(key) ~= "string" or type(value) ~= "number" then
			data.RobuxBoosts[key] = nil
		end
	end
	for key, value in data.RobuxOnce do
		if type(key) ~= "string" or type(value) ~= "number" then
			data.RobuxOnce[key] = nil
		end
	end
	data.RobuxSpent = math.max(0, math.floor(tonumber(data.RobuxSpent) or 0))
	data.RobuxSlots = math.clamp(math.floor(tonumber(data.RobuxSlots) or 0), 0, 4)
	data.RollCount = math.max(0, math.floor(tonumber(data.RollCount) or 0))
	data.X10Counter = math.max(0, math.floor(tonumber(data.X10Counter) or 0))
	-- Défis : sous-tables abîmées remises à neuf, compteurs entiers et positifs.
	local quests = data.Quests
	for _, key in { "counters", "claimed", "notified", "daily" } do
		if type(quests[key]) ~= "table" then
			quests[key] = {}
		end
	end
	for key, value in quests.counters do
		local n = tonumber(value)
		quests.counters[key] = if n and n > 0 then math.floor(n) else nil
	end
	local daily = quests.daily
	daily.day = math.floor(tonumber(daily.day) or 0)
	for _, key in { "list", "base", "claimed" } do
		if type(daily[key]) ~= "table" then
			daily[key] = {}
		end
	end
	daily.bonus = daily.bonus == true
	quests.punch = math.clamp(math.floor(tonumber(quests.punch) or 0), 0, 1000000)
	data.traitCrystals = math.max(0, math.floor(tonumber(data.traitCrystals) or 0))
	if version < 3 then
		migrateRollV3(data)
	end
	cleanAutoSettings(data)
	data.RollMulti = math.clamp(math.floor(tonumber(data.RollMulti) or 0), 0, 3)
	-- L'auto-roulage ne repart jamais tout seul à l'arrivée (le joueur le relance à la machine).
	data.AutoRoll = false
	data.AutoBuy = false
	data.version = 3
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
		if RunService:IsStudio() then
			-- Studio : vérifie que l'accès aux API est autorisé (sinon on joue sans sauvegarde).
			local probeOk = pcall(function()
				(result :: DataStore):GetAsync("__probe")
			end)
			storeAvailable = probeOk
		else
			-- En ligne : on ne coupe JAMAIS la sauvegarde sur une erreur passagère au démarrage
			-- (limite de requêtes, panne de quelques secondes). loadData réessaie, puis expulse
			-- le joueur si sa sauvegarde reste illisible : jamais de partie vierge à la place.
			storeAvailable = true
		end
	end
	if not storeAvailable then
		if RunService:IsStudio() then
			warn("[AnimeTycoon] DataStore indisponible : la progression ne sera PAS sauvegardée. (Studio : Game Settings > Security > Enable Studio Access to API Services)")
		else
			warn("[AnimeTycoon] DataStore introuvable : les joueurs ne pourront pas charger leur sauvegarde.")
		end
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function loadData(player: Player)
	if not storeAvailable or not store then
		-- Sans sauvegarde : partie vierge seulement dans Studio (en ligne, on expulse plutôt
		-- que de remplacer la vraie progression du joueur).
		return if RunService:IsStudio() then template() else nil
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

local function saveData(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not profile.loaded or not storeAvailable or not store then
		return false
	end
	local snapshot = deepCopy(profile.data)
	snapshot.lock = if release then nil else { jobId = game.JobId, time = os.time() }
	local written = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(current)
			if current and current.lock and current.lock.jobId ~= game.JobId and os.time() - (current.lock.time or 0) < LOCK_TIMEOUT then
				-- Un autre serveur a la main : on n'écrase pas.
				written = false
				return nil
			end
			written = true
			return snapshot
		end)
	end)
	if ok and written then
		profile.dirty = false
		return true
	end
	if not ok then
		warn("[AnimeTycoon] Échec de la sauvegarde de " .. player.Name .. " : " .. tostring(err))
	end
	return false
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
	syncWindows[player] = nil
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
-- `window` (secondes, 0,25 par défaut) : délai de regroupement. Les sources fréquentes passent
-- une fenêtre plus longue pour ne pas renvoyer toute la sauvegarde à chaque fois : coups de
-- punching-ball (2 s, QuestService) et auto-roulage loin de la machine (2 s,
-- RollService.AutoSyncWindow : le roulage auto, et l'achat auto via WithSyncWindow ; à la
-- machine, envoi normal, et l'envoi en attente part dès l'arrivée à la machine). Ce qui doit
-- se voir tout de suite a ses propres remotes (RollResult, HatchReveal, Notify...). Un appel
-- normal (0,25 s) reste prioritaire : il avance l'envoi déjà prévu, une action du joueur n'est
-- donc jamais retardée.
function DataService:Sync(player: Player, window: number?)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return
	end
	profile.dirty = true
	local wait = math.max(0, window or syncWindows[player] or 0.25)
	local due = os.clock() + wait
	local planned = pendingSync[player]
	if planned and planned <= due then
		return -- un envoi est déjà prévu plus tôt : il emportera ces changements
	end
	pendingSync[player] = due
	-- Regroupe les modifications rapprochées en un seul envoi.
	task.delay(wait, function()
		if pendingSync[player] ~= due then
			return -- remplacé par un envoi plus proche (ou joueur parti)
		end
		pendingSync[player] = nil
		local current = profiles[player]
		if current and current.loaded and player.Parent then
			DataSync:FireClient(player, current.data)
		end
	end)
end

-- Appelle fn(...) en donnant la fenêtre `window` à toutes les synchros sans fenêtre explicite
-- qu'elle déclenche (ex. achat auto : SpendCoins, AddCharacter... dans RollService:Collect).
function DataService:WithSyncWindow(player: Player, window: number, fn: (...any) -> ...any, ...: any): ...any
	local previous = syncWindows[player]
	syncWindows[player] = window
	local results = table.pack(pcall(fn, ...))
	syncWindows[player] = previous
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Secondes avant le prochain envoi prévu au client (nil si aucun) : RollService (arrivée à la
-- machine pendant l'auto-roulage) et tests.
function DataService:PendingSyncDelay(player: Player): number?
	local due = pendingSync[player]
	return due and math.max(0, due - os.clock()) or nil
end

function DataService:SaveNow(player: Player)
	task.spawn(saveData, player, false)
end

-- Sauvegarde tout de suite et attend le résultat (achats Robux : on ne valide un achat
-- qu'une fois enregistré). Sans DataStore : vrai seulement dans Studio (rien à sauvegarder).
function DataService:SaveAndWait(player: Player): boolean
	if not storeAvailable or not store then
		return RunService:IsStudio() and self:IsLoaded(player)
	end
	return saveData(player, false)
end

function DataService:Reset(player: Player)
	local profile = profiles[player]
	if profile and profile.loaded then
		local fresh = template()
		-- Les achats Robux ne sont jamais effacés (un reçu ne doit pas être accordé deux fois).
		for _, key in { "Receipts", "RobuxPasses", "RobuxBoosts", "RobuxSpent", "RobuxSlots", "RobuxOnce" } do
			fresh[key] = profile.data[key]
		end
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

-- Objets d'évolution (marchand) : ajoute (ou retire, si `amount` < 0) des objets.
function DataService:AddItem(player: Player, itemId: string, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	if type(data.Items) ~= "table" then
		data.Items = {}
	end
	local count = math.max(0, (data.Items[itemId] or 0) + math.floor(amount))
	data.Items[itemId] = if count > 0 then count else nil
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
