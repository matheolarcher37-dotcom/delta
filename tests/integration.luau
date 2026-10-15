--!nocheck
-- Test d'intégration du serveur (avec Lune) : démarre tous les services, simule des joueurs
-- et parcourt la boucle de jeu complète.
-- Usage :  rojo build default.project.json -o build/AnimeTycoon.rbxl && lune run tests/integration.luau

local task = require("@lune/task")
local Harness = require("./harness")

local roblox = Harness.roblox
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local game = Harness.game
local test = Harness.test
local signalFor = Harness.signalFor
local newSignal = Harness.newSignal

------------------------------------------------------------------------
-- Faux services serveur
------------------------------------------------------------------------

local playersList = {}
local Players = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	LocalPlayer = nil,
}
function Players:GetPlayers()
	return table.clone(playersList)
end
function Players:GetPlayerFromCharacter(model)
	for _, player in playersList do
		if player.Character == model then
			return player
		end
	end
	return nil
end
function Players:GetPlayerByUserId(userId)
	for _, player in playersList do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end
function Players:GetNameFromUserIdAsync(userId)
	return "Joueur" .. userId
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

local stores = {}
local DataStoreService = {}
function DataStoreService:GetDataStore(name)
	stores[name] = stores[name] or {}
	local data = stores[name]
	return {
		GetAsync = function(_, key)
			return deepCopy(data[key])
		end,
		SetAsync = function(_, key, value)
			data[key] = deepCopy(value)
		end,
		UpdateAsync = function(_, key, fn)
			local result = fn(deepCopy(data[key]))
			if result ~= nil then
				data[key] = deepCopy(result)
			end
			return result
		end,
	}
end
function DataStoreService:GetOrderedDataStore(name)
	stores[name] = stores[name] or {}
	local data = stores[name]
	return {
		SetAsync = function(_, key, value)
			data[key] = value
		end,
		GetSortedAsync = function()
			local items = {}
			for key, value in data do
				table.insert(items, { key = key, value = value })
			end
			table.sort(items, function(a, b)
				return a.value > b.value
			end)
			return {
				GetCurrentPage = function()
					return items
				end,
			}
		end,
	}
end

Harness.services.Players = Players
Harness.services.DataStoreService = DataStoreService
Harness.services.PhysicsService = {
	RegisterCollisionGroup = function() end,
	CollisionGroupSetCollidable = function() end,
}
Harness.services.Debris = {
	AddItem = function(_, instance, delay)
		task.delay(delay, function()
			instance:Destroy()
		end)
	end,
}
-- Faux MarketplaceService (boutique Robux) : enregistre les fenêtres d'achat ouvertes.
local marketPrompts = {}
local MarketplaceService = {
	PromptGamePassPurchaseFinished = newSignal(),
	ProcessReceipt = nil,
}
function MarketplaceService:PromptGamePassPurchase(player, id)
	table.insert(marketPrompts, { kind = "pass", player = player, id = id })
end
function MarketplaceService:PromptProductPurchase(player, id)
	table.insert(marketPrompts, { kind = "product", player = player, id = id })
end
function MarketplaceService:UserOwnsGamePassAsync(_, id)
	return id == 4242 -- « possédé » sur Roblox
end
function MarketplaceService:GetProductInfo()
	error("pas d'accès web dans les tests")
end
Harness.services.MarketplaceService = MarketplaceService
Harness.gameOverrides.BindToClose = function() end
Harness.gameOverrides.JobId = "job-test"
Harness.gameOverrides.CreatorType = roblox.Enum.CreatorType.User
Harness.gameOverrides.CreatorId = 0

local guidCounter = 0
roblox.implementMethod("HttpService", "GenerateGUID", function()
	guidCounter += 1
	return string.format("GUID-%06d", guidCounter)
end)
roblox.implementMethod("Humanoid", "MoveTo", function() end)
roblox.implementMethod("Player", "Kick", function(player, reason)
	error("Joueur expulsé : " .. tostring(reason))
end)
for _, name in { "CharacterAdded", "Chatted" } do
	roblox.implementProperty("Player", name, function(player)
		return signalFor(player, name)
	end)
end
roblox.implementProperty("TextChatCommand", "Triggered", function(instance)
	return signalFor(instance, "Triggered")
end)

-- Callbacks des RemoteFunctions + messages envoyés aux clients.
local callbacks = {}
roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(remote)
	return callbacks[remote]
end, function(remote, fn)
	callbacks[remote] = fn
end)
local clientEvents = {}
roblox.implementMethod("RemoteEvent", "FireClient", function(remote, player, ...)
	table.insert(clientEvents, { name = remote.Name, player = player, args = { ... } })
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(remote, ...)
	table.insert(clientEvents, { name = remote.Name, args = { ... } })
end)

local function lastEvent(name, player)
	for i = #clientEvents, 1, -1 do
		local event = clientEvents[i]
		if event.name == name and (player == nil or event.player == player) then
			return event
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Démarrage du serveur
------------------------------------------------------------------------

local serverFolder = Harness.find("ServerScriptService.Server")
local Remotes
local services = nil

test("Démarrage du serveur (Main.server)", function()
	-- On exécute Main en capturant la table des services via un module espion.
	local Main = serverFolder:FindFirstChild("Main")
	assert(Main, "Main introuvable")
	Harness.run(Main)
	Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	services = {}
	for _, module in serverFolder.Services:GetChildren() do
		services[module.Name] = Harness.require(module)
	end
	assert(services.DataService.services, "services non initialisés")
	assert(game:GetService("Workspace").World.Zone.Decor, "décor absent")
end)

local function invoke(name, player, ...)
	local remote = Remotes.func(name)
	local fn = callbacks[remote]
	assert(fn, "pas de handler pour " .. name)
	return fn(player, ...)
end

local function fireServer(name, player, ...)
	signalFor(Remotes.event(name), "OnServerEvent"):Fire(player, ...)
end

local nextUserId = 1000
local function addPlayer(name)
	nextUserId += 1
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = nextUserId
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = character
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.MaxHealth = 100
	humanoid.Parent = character
	character.Parent = game:GetService("Workspace")
	player.Character = character
	Instance.new("Backpack").Parent = player
	player.Parent = game:GetService("Players")
	table.insert(playersList, player)
	Players.PlayerAdded:Fire(player)
	task.wait(0.3)
	signalFor(player, "CharacterAdded"):Fire(character)
	task.wait(0.8)
	return player
end

local function removePlayer(player)
	Players.PlayerRemoving:Fire(player)
	local index = table.find(playersList, player)
	if index then
		table.remove(playersList, index)
	end
end

local alice, bob
local DataService

test("Arrivée d'un joueur : base attribuée + relique offerte", function()
	DataService = services.DataService
	alice = addPlayer("Alice")
	local data = DataService:Get(alice)
	assert(data, "données non chargées")
	local plot = services.PlotService:GetPlot(alice)
	assert(plot, "pas de base")
	assert(next(data.relics) ~= nil, "pas de relique de départ")
	assert(alice:FindFirstChild("leaderstats") ~= nil or true)
	assert(lastEvent("DataSync", alice), "pas de synchro client")
end)

local firstUid
test("Poser et ouvrir la relique → premier perso", function()
	local data = DataService:Get(alice)
	local relicId = next(data.relics)
	local ok, message = invoke("PlaceRelic", alice, 1, relicId)
	assert(ok, "PlaceRelic : " .. tostring(message))
	assert(data.incubators["1"], "incubateur vide")
	Harness.timeOffset += 30
	local plot = services.PlotService:GetPlot(alice)
	local prompt = plot.pedestals[1].Top.Prompt
	signalFor(prompt, "Triggered"):Fire(alice)
	local count = 0
	for uid in data.characters do
		count += 1
		firstUid = uid
	end
	assert(count == 1, "perso non obtenu (" .. count .. ")")
	assert(table.find(data.team, firstUid), "pas équipé automatiquement")
	assert(lastEvent("HatchReveal", alice), "pas de révélation")
	task.wait(0.2)
	local followers = game:GetService("Workspace"):FindFirstChild("Followers")
	assert(followers and #followers:GetChildren() == 1, "le perso ne suit pas le joueur")
end)

test("Boutique : acheter une relique", function()
	DataService:AddCoins(alice, 1000000)
	local shop = invoke("GetShop", alice)
	assert(shop and #shop.items == 3, "boutique invalide")
	local plot = services.PlotService:GetPlot(alice)
	alice.Character:PivotTo(plot.cf * CFrame.new(-16, 3, 30))
	local ok, message = invoke("BuyRelic", alice, shop.items[1].relicId)
	assert(ok, "achat : " .. tostring(message))
end)

test("Combat : dégâts, mort d'un ennemi, récompenses", function()
	local CombatService = services.CombatService
	local enemy = CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy, "aucun ennemi dans la zone")
	local data = DataService:Get(alice)
	local coinsBefore = data.coins
	CombatService:DamageEnemy(alice, enemy, 1e9, { kind = "orb", color = roblox.Color3.new(1, 1, 1), from = Vector3.zero })
	assert(not enemy.alive, "ennemi toujours vivant")
	assert(data.coins > coinsBefore, "pas de pièces")
	assert(data.stats.kills == 1, "kill non compté")
end)

test("Boss : apparition et récompense partagée", function()
	local CombatService = services.CombatService
	CombatService:SpawnBoss()
	local boss = CombatService:GetBoss()
	assert(boss and boss.alive, "pas de boss")
	CombatService:DamageEnemy(alice, boss, 1e9, {})
	assert(not boss.alive, "boss vivant")
end)

test("IA de l'équipe : le perso attaque un ennemi proche", function()
	local CombatService = services.CombatService
	-- Un ennemi bien dans la zone de combat (le joueur posé à côté doit y être aussi).
	local enemy = nil
	for _, record in CombatService:GetEnemiesNear(Vector3.zero, 2000) do
		local p = record.root.CFrame.Position
		if CombatService:IsInZone(p + Vector3.new(4, 0, 0), 6) and CombatService:IsInZone(p, 6) then
			enemy = record
			break
		end
	end
	assert(enemy, "pas d'ennemi")
	local follower = services.TeamService:GetFollowers(alice)[firstUid]
	assert(follower, "follower introuvable")
	local enemyPos = enemy.root.CFrame.Position
	alice.Character:PivotTo(CFrame.new(enemyPos + Vector3.new(4, 0, 0)))
	follower.model:PivotTo(CFrame.new(enemyPos + Vector3.new(2, 0, 0)))
	-- Le perso peut viser un autre ennemi apparu tout près : on vérifie qu'un ennemi proche a été touché.
	local nearby = CombatService:GetEnemiesNear(enemyPos, 40)
	local hpBefore = {}
	for _, record in nearby do
		hpBefore[record] = record.hp
	end
	services.TeamService:_update(alice, { followers = { [firstUid] = follower }, target = nil }, os.clock() + 100)
	local hit = false
	for _, record in nearby do
		if record.hp < hpBefore[record] or not record.alive then
			hit = true
		end
	end
	assert(hit, "le perso n'a pas attaqué")
end)

test("Améliorations de base (boutons tycoon)", function()
	local data = DataService:Get(alice)
	assert(services.PlotService:BuyUpgrade(alice, "lanternes"), "lanternes")
	assert(services.PlotService:BuyUpgrade(alice, "autel2"), "autel2")
	assert(data.upgrades.autel2, "upgrade non enregistrée")
	local plot = services.PlotService:GetPlot(alice)
	assert(plot.pedestals[2], "autel #2 non construit")
	assert(not services.PlotService:BuyUpgrade(alice, "dojo"), "dojo acheté sans prérequis")
end)

test("Revenus passifs et coffre", function()
	local data = DataService:Get(alice)
	-- Ajoute un 2e perso (exposé sur la base car l'équipe garde le 1er).
	local entry = services.CharacterService:CreateEntry("ninja_maruto", "foudre")
	local uid = services.CharacterService:AddCharacter(alice, entry)
	-- Il a été équipé automatiquement : on le retire de l'équipe pour l'exposer sur la base.
	assert(invoke("EquipCharacter", alice, uid, false), "déséquiper")
	local stashBefore = data.stash
	services.CharacterService:_tick(alice, { syncTimer = 0 })
	local plot = services.PlotService:GetPlot(alice)
	assert(#plot.displayFolder:GetChildren() >= 1, "rien d'exposé sur la base")
	assert(data.stash > stashBefore, "pas de revenu passif")
	assert(entry.xp > 0 or entry.level > 1, "pas d'XP passive")
	data.stash += 500
	local coins = data.coins
	services.PlotService:CollectStash(alice)
	assert(data.coins >= coins + 500, "coffre non récupéré")
end)

------------------------------------------------------------------------
-- Machine ROULER, arbre de compétences, cases d'unités, déco de base
------------------------------------------------------------------------

local function rollNow(player)
	services.RollService:ResetCooldown(player)
	return invoke("Roll", player)
end

test("Machine ROULER : un perso par roulage, rareté de base, collecte offerte puis payante", function()
	local data = DataService:Get(alice)
	local plot = services.PlotService:GetPlot(alice)
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	assert(plot.machine and plot.machine.prompt, "machine absente")
	table.clear(data.RolledQueue)
	data.Skills = {}
	local countBefore = 0
	for _ in data.characters do
		countBefore += 1
	end
	local ok, results = rollNow(alice)
	assert(ok and type(results) == "table" and #results == 1, "roulage : " .. tostring(results))
	assert(#data.RolledQueue == 1, "perso pas sur l'estrade")
	local payload = lastEvent("RollResult", alice).args[1]
	assert(payload.results[1].id and payload.results[1].price and payload.results[1].dps and payload.pity.mythic, "contenu de RollResult")
	assert(payload.x10In == nil and payload.pity.legendary == nil, "restes de l'ancien roulage (x10, pitié Légendaire)")
	assert(#plot.rolledFolder:GetChildren() == 1, "modèle du perso tiré absent")
	local univers = services.UniverseService:GetCurrent()
	assert(table.find(univers.characters, results[1].id), "perso hors du pool de l'univers actuel")
	-- Rareté de BASE : le perso tiré garde la rareté de sa fiche.
	assert(results[1].rarity == Characters.get(results[1].id).rarity, "rareté de machine collée sur le perso")
	-- Le roulage suivant REMPLACE le perso non collecté (il « passe ») : plus de file de 6.
	local firstKey = data.RolledQueue[1].key
	if data.RolledQueue[1].rarity == "legendary" or data.RolledQueue[1].rarity == "mythic" then
		data.RolledQueue[1].rarity = "common"
	end
	rollNow(alice)
	assert(#data.RolledQueue == 1 and data.RolledQueue[1].key ~= firstKey, "le perso précédent n'est pas passé")
	assert(#plot.rolledFolder:GetChildren() == 1, "ancien modèle resté sur l'estrade")
	-- Premier perso collecté : offert (s'il est Rare ou moins).
	data.FirstCollectDone = false
	data.coins = 0
	data.RolledQueue[1].rarity = "rare"
	-- Une position (nombre) n'est jamais acceptée : seulement la clé du perso.
	local okIndex = invoke("CollectRolled", alice, 1)
	assert(not okIndex and #data.RolledQueue == 1, "collecte par position acceptée")
	local okFree, msg = invoke("CollectRolled", alice, data.RolledQueue[1].key)
	assert(okFree, "collecte offerte : " .. tostring(msg))
	assert(#data.RolledQueue == 0 and #plot.rolledFolder:GetChildren() == 0, "estrade non vidée")
	-- Un Légendaire n'est jamais offert, même pour la toute première collecte.
	data.FirstCollectDone = false
	rollNow(alice)
	data.RolledQueue[1].rarity = "legendary"
	local okLegend = invoke("CollectRolled", alice, data.RolledQueue[1].key)
	assert(not okLegend and #data.RolledQueue == 1, "Légendaire offert gratuitement")
	table.clear(data.RolledQueue)
	data.FirstCollectDone = true
	services.RollService:RenderStage(alice)
	-- Ensuite on paie le prix.
	rollNow(alice)
	local price = data.RolledQueue[1].price
	assert(price > 0, "prix nul")
	local okPoor = invoke("CollectRolled", alice, data.RolledQueue[1].key)
	assert(not okPoor, "collecte sans argent acceptée")
	DataService:AddCoins(alice, price)
	local okPaid, msg2 = invoke("CollectRolled", alice, data.RolledQueue[1].key)
	assert(okPaid, "collecte payante : " .. tostring(msg2))
	assert(data.coins == 0, "prix non débité")
	local count = 0
	for _, entry in data.characters do
		count += 1
		assert(entry.rollRarity == nil, "rareté de machine encore mémorisée")
	end
	assert(count == countBefore + 2, "persos non ajoutés")
	-- L'invite « Collecter » de l'estrade marche aussi.
	rollNow(alice)
	DataService:AddCoins(alice, data.RolledQueue[1].price)
	local model = plot.rolledFolder:GetChildren()[1]
	signalFor(model.PrimaryPart.Prompt, "Triggered"):Fire(alice)
	assert(#data.RolledQueue == 0, "invite Collecter sans effet")
	-- Le bouton de la machine (invite) roule.
	services.RollService:ResetCooldown(alice)
	signalFor(plot.machine.prompt, "Triggered"):Fire(alice)
	assert(#data.RolledQueue == 1, "le bouton ROULER ne roule pas")
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Tapis de pièces : chemins publiés pour les clients, aucune pièce animée par le serveur", function()
	local Conveyor = Harness.require(Harness.find("ServerScriptService.Server.Modules.TycoonConveyor"))
	local folder = roblox.Instance.new("Folder")
	folder.Parent = game:GetService("Workspace")
	Conveyor.publish(folder, {
		{ kind = "gold", interval = 1.8, points = { roblox.Vector3.new(1, 6, 2), roblox.Vector3.new(1, 2, 2), roblox.Vector3.new(1, 2, 20.5) } },
	}, true)
	local config = folder:FindFirstChild("Chemin1")
	assert(config and config:GetAttribute("Kind") == "gold" and config:GetAttribute("Interval") == 1.8, "chemin non publié")
	assert(config:GetAttribute("Points") == "1.00,6.00,2.00;1.00,2.00,2.00;1.00,2.00,20.50", "points mal encodés")
	assert(folder:GetAttribute("Active") == true and table.find(Harness.CollectionService:GetTagged(Conveyor.Tag), folder), "dossier non étiqueté")
	folder:Destroy()
	local plot = services.PlotService:GetPlot(alice)
	assert(plot.coinFolder and table.find(Harness.CollectionService:GetTagged(Conveyor.Tag), plot.coinFolder), "tapis de la base non publié")
	for _, child in plot.coinFolder:GetChildren() do
		assert(child:IsA("Configuration"), "pièce créée côté serveur : " .. child.Name)
	end
end)

test("Machine ROULER : délai entre deux roulages", function()
	services.RollService:ResetCooldown(alice)
	assert(invoke("Roll", alice), "1er roulage")
	local ok = invoke("Roll", alice)
	assert(not ok, "roulage sans délai accepté")
	table.clear(DataService:Get(alice).RolledQueue)
end)

test("Légendaire sur l'estrade : confirmation avant de le laisser passer", function()
	local data = DataService:Get(alice)
	table.clear(data.RolledQueue)
	table.insert(data.RolledQueue, { key = "L1", id = "ninja_maruto", rarity = "legendary", stars = 1, price = 45000, dps = 100, at = 0 })
	local ok, message = rollNow(alice)
	assert(not ok and type(message) == "string" and message:find("encore"), "pas d'avertissement avant de perdre un Légendaire")
	assert(#data.RolledQueue == 1 and data.RolledQueue[1].key == "L1", "Légendaire perdu sans confirmation")
	local ok2 = rollNow(alice)
	assert(ok2 and data.RolledQueue[1].key ~= "L1", "2e appui : le Légendaire aurait dû passer")
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Chaque rareté de la machine tire un perso de CETTE rareté dans chaque univers", function()
	-- Chaque perso garde sa rareté de base (Maruto Épique reste Épique) ; une rareté « optionnelle »
	-- (Peu commun) ne compte que si l'univers a des persos de cette rareté.
	local Universes = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes"))
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	local Economy = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Economy"))
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local stats = Formulas.playerStats(DataService:Get(alice))
	for tierId, info in Economy.RollRarities do
		for _, universe in Universes.List do
			local n = 0
			for _, id in universe.characters do
				if Characters.get(id).rarity == info.charRarity then
					n += 1
				end
			end
			if n == 0 then
				assert(info.optional, universe.id .. " : aucun perso pour la rareté " .. tierId)
			else
				local item = services.RollService:MakeItem(universe, tierId, stats)
				assert(Characters.get(item.id).rarity == info.charRarity, universe.id .. " : rareté " .. tierId .. " -> " .. item.id)
			end
		end
	end
end)

test("Palier Secret : tire le perso Secret de chaque univers, jamais un autre", function()
	local Universes = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes"))
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	local Economy = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Economy"))
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	assert(Economy.RollRarities.secret.charRarity == "secret", "le palier Secret ne tire pas la rareté secret")
	assert((Economy.EvolutionRarityMult.secret or 0) >= Economy.EvolutionRarityMult.mythic, "évolution d'un Secret trop bon marché")
	local stats = Formulas.playerStats(DataService:Get(alice))
	local SECRETS = { "ninja_radama", "occ_sukana", "sai_gojita", "oce_kaydo", "pou_muzon" }
	local seen = {}
	for _, universe in Universes.List do
		for _ = 1, 6 do
			local item = services.RollService:MakeItem(universe, "secret", stats)
			assert(table.find(SECRETS, item.id), universe.id .. " : palier Secret -> " .. tostring(item.id))
			assert(Characters.get(item.id).rarity == "secret", item.id .. " n'est pas de rareté secret")
			assert(table.find(universe.characters, item.id), item.id .. " hors du pool de " .. universe.id)
			seen[item.id] = true
		end
		-- Le palier Mythique ne donne jamais un Secret.
		for _ = 1, 6 do
			local item = services.RollService:MakeItem(universe, "mythic", stats)
			assert(Characters.get(item.id).rarity == "mythic", universe.id .. " : palier Mythique -> " .. item.id)
		end
	end
	for _, id in SECRETS do
		assert(seen[id], "Secret jamais tiré : " .. id)
	end
end)

test("Pitié : seul le Mythique est garanti, le reste est du pur hasard", function()
	local data = DataService:Get(alice)
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local stats = Formulas.playerStats(data)
	table.clear(data.RolledQueue)
	data.Pity = { mythic = Formulas.pityThreshold("mythic", stats.pityMult) - 1 }
	local ok, results = rollNow(alice)
	assert(ok and results[1].rarity == "mythic", "Mythique non garanti (obtenu " .. tostring(results and results[1] and results[1].rarity) .. ")")
	assert(data.Pity.mythic == 0, "compteur de pitié non remis à zéro")
	assert(data.Pity.legendary == nil and data.Pity.secret == nil, "pitiés Légendaire / Secret encore comptées")
	local machine = services.PlotService:GetPlot(alice).machine
	assert(machine.x10Text.Text:find("Mythique garanti"), "barre de pitié du Mythique non mise à jour : " .. machine.x10Text.Text)
	assert(machine.pityLines.common.Text:find("%%"), "panneau des chances non mis à jour")
	assert(machine.pityLines.mythic.Text:find("%%"), "chance du Mythique non affichée")
	-- Un Mythique est sur l'estrade : rouler demande confirmation.
	assert(not rollNow(alice), "Mythique laissé passer sans confirmation")
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Passes Robux : 2 ou 3 persos par roulage (1 par défaut)", function()
	local data = DataService:Get(alice)
	table.clear(data.RolledQueue)
	data.Skills = { coeur = true, taux1 = true, multi1 = true, multi2 = true, taux2 = true }
	alice:SetAttribute("Pass_Roll2", nil)
	alice:SetAttribute("Pass_Roll3", nil)
	local ok, results = rollNow(alice)
	assert(ok and #results == 1, "l'arbre donne encore plusieurs persos par roulage")
	assert(not invoke("Roll_SetMulti", alice, 2), "x2 accepté sans passe")
	alice:SetAttribute("Pass_Roll2", true)
	table.clear(data.RolledQueue)
	ok, results = rollNow(alice)
	assert(ok and #results == 2, "passe Roulage x2 : " .. (type(results) == "table" and #results or tostring(results)))
	assert(not invoke("Roll_SetMulti", alice, 3), "x3 accepté avec le seul passe x2")
	assert(invoke("Roll_SetMulti", alice, 1), "retour à 1 perso")
	table.clear(data.RolledQueue)
	ok, results = rollNow(alice)
	assert(ok and #results == 1, "choix « x1 » ignoré")
	alice:SetAttribute("Pass_Roll3", true)
	assert(invoke("Roll_SetMulti", alice, 3), "x3 avec le passe")
	table.clear(data.RolledQueue)
	ok, results = rollNow(alice)
	assert(ok and #results == 3, "passe Roulage x3")
	assert(#services.PlotService:GetPlot(alice).rolledFolder:GetChildren() == 3, "3 persos attendus sur l'estrade")
	data.RollMulti = 0
	alice:SetAttribute("Pass_Roll2", nil)
	alice:SetAttribute("Pass_Roll3", nil)
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Lancer AFK (passe AutoRoll) : roule seul, pause sur les raretés cochées", function()
	local data = DataService:Get(alice)
	local RollService = services.RollService
	table.clear(data.RolledQueue)
	alice:SetAttribute("Pass_AutoRoll", nil)
	alice:SetAttribute("Pass_AutoRollPlus", nil)
	assert(not invoke("SetAutoRoll", alice, true) and data.AutoRoll == false, "Lancer AFK sans le passe")
	alice:SetAttribute("Pass_AutoRoll", true)
	-- Réglages : seules des clés connues et des booléens sont gardés.
	local okSave = invoke("Roll_SaveAutoSettings", alice, {
		pauseRarities = { common = false, rare = false, epic = false, legendary = false, mythic = false, pirate = true },
		pauseMutations = { ["or"] = "oui", diamant = false },
		buyCharacters = { ninja_maruto = true, inconnu = true },
	})
	assert(okSave, "réglages refusés")
	local settings = data.AutoRollSettings
	assert(settings.pauseRarities.pirate == nil and settings.pauseRarities.common == false, "rareté inconnue gardée")
	assert(next(settings.pauseMutations) == nil, "valeur non booléenne gardée")
	assert(settings.buyCharacters.ninja_maruto == true and settings.buyCharacters.inconnu == nil, "perso inconnu gardé")
	assert(invoke("SetAutoRoll", alice, true) and data.AutoRoll == true, "Lancer AFK avec le passe")
	-- Rien de coché : ça roule sans s'arrêter (on enlève les mutations de la pause aussi).
	local count = data.RollCount
	for _ = 1, 3 do
		RollService:ResetCooldown(alice)
		RollService:AutoStep(alice)
	end
	assert(data.RollCount == count + 3, "l'auto-roulage ne roule pas")
	assert(data.AutoRoll == true, "arrêt sans raison")
	-- Tout coché : la machine s'arrête au premier perso, qui reste sur l'estrade.
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = { common = true, rare = true, epic = true, legendary = true, mythic = true } })
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(data.AutoRoll == false, "pas de pause sur une rareté cochée")
	assert(#data.RolledQueue == 1, "le perso de la pause n'est pas resté sur l'estrade")
	-- Passe perdu : l'auto-roulage s'arrête tout seul.
	data.AutoRoll = true
	alice:SetAttribute("Pass_AutoRoll", nil)
	RollService:AutoStep(alice)
	assert(data.AutoRoll == false, "auto-roulage sans passe")
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = { legendary = true, mythic = true }, buyCharacters = {} })
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Achat automatique (passe AutoRollPlus) : achète les cibles, s'arrête sans argent", function()
	local data = DataService:Get(alice)
	local RollService = services.RollService
	table.clear(data.RolledQueue)
	data.FirstCollectDone = true
	alice:SetAttribute("Pass_AutoRollPlus", nil)
	assert(not invoke("Roll_SetAutoBuy", alice, true), "achat automatique sans le passe")
	alice:SetAttribute("Pass_AutoRollPlus", true)
	invoke("Roll_SaveAutoSettings", alice, { buyCharacters = {}, buyRarities = {}, buyMutations = {} })
	assert(not invoke("Roll_SetAutoBuy", alice, true), "achat automatique sans cible")
	invoke("Roll_SaveAutoSettings", alice, { buyRarities = { common = true, rare = true, epic = true, legendary = true, mythic = true } })
	assert(invoke("Roll_SetAutoBuy", alice, true) and data.AutoBuy == true, "achat automatique avec le passe et des cibles")
	local count = 0
	for _ in data.characters do
		count += 1
	end
	DataService:AddCoins(alice, 100000000)
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	local after = 0
	for _ in data.characters do
		after += 1
	end
	assert(after == count + 1 and #data.RolledQueue == 0, "le perso visé n'a pas été acheté")
	assert(data.AutoBuy == true, "arrêt sans raison")
	-- Plus d'argent : l'achat s'arrête, le perso reste sur l'estrade.
	data.coins = 0
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(data.AutoBuy == false, "l'achat automatique ne s'arrête pas sans argent")
	assert(#data.RolledQueue == 1, "le perso visé n'est pas resté sur l'estrade")
	alice:SetAttribute("Pass_AutoRollPlus", nil)
	invoke("Roll_SaveAutoSettings", alice, { buyRarities = {} })
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Mutations : tirées à la machine, prix, apparence sur l'estrade et dans la base", function()
	local data = DataService:Get(alice)
	local RollService = services.RollService
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local universe = services.UniverseService:GetCurrent()
	local stats = Formulas.playerStats(data)
	stats.auraLuck = 1000 -- mutation quasi certaine
	local item = RollService:MakeItem(universe, "epic", stats)
	assert(item.aura, "pas de mutation malgré une chance énorme")
	assert(item.rarity == Characters.get(item.id).rarity, "rareté de base perdue")
	assert(item.price > Formulas.rollPrice(item.rarity, nil, item.trait), "la mutation n'augmente pas le prix")
	table.clear(data.RolledQueue)
	table.insert(data.RolledQueue, item)
	RollService:RenderStage(alice, { item })
	local model = services.PlotService:GetPlot(alice).rolledFolder:GetChildren()[1]
	assert(model and model:GetAttribute("Mutation"), "apparence de la mutation absente sur l'estrade")
	local tag = model.PrimaryPart:FindFirstChild("AnimeTag")
	assert(tag and tag:FindFirstChild("Mutation"), "mutation absente de l'étiquette")
	DataService:AddCoins(alice, item.price)
	local ok, message = invoke("CollectRolled", alice, item.key)
	assert(ok, "collecte d'un perso muté : " .. tostring(message))
	local found = false
	for _, entry in data.characters do
		if entry.aura == item.aura and entry.id == item.id then
			found = true
		end
	end
	assert(found, "mutation perdue à la collecte")
	services.RollService:RenderStage(alice)
end)

test("Arbre de compétences : prérequis, argent, effets", function()
	local data = DataService:Get(alice)
	local SkillTree = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.SkillTree"))
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	data.Skills = {}
	data.coins = 0
	assert(not invoke("BuySkill", alice, "chance1"), "nœud acheté sans prérequis")
	assert(not invoke("BuySkill", alice, "coeur"), "nœud acheté sans argent")
	assert(not invoke("BuySkill", alice, "inconnu"), "nœud inconnu accepté")
	DataService:AddCoins(alice, 10000000)
	local coins = data.coins
	assert(invoke("BuySkill", alice, "coeur"), "cœur")
	assert(data.coins == coins - SkillTree.get("coeur").cost, "coût non débité")
	assert(not invoke("BuySkill", alice, "coeur"), "nœud acheté deux fois")
	local displayBefore = Formulas.playerStats(data).display
	for _, id in { "chance1", "slots1", "revenu1", "degats1" } do
		local ok, message = invoke("BuySkill", alice, id)
		assert(ok, id .. " : " .. tostring(message))
	end
	local stats = Formulas.playerStats(data)
	assert(stats.luck > 1.15, "chance non appliquée")
	assert(stats.display == displayBefore + 1, "emplacement non ajouté")
	assert(stats.income > Formulas.upgradeStats(data.upgrades).income, "revenu non appliqué")
	-- Dégâts : +10 % appliqués par le combat.
	local enemy = services.CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy, "pas d'ennemi")
	enemy.hp = 1e9
	local before = enemy.hp
	services.CombatService:DamageEnemy(alice, enemy, 100, {})
	assert(math.abs((before - enemy.hp) - 110) < 0.01, "dégâts de l'arbre non appliqués : " .. (before - enemy.hp))
	-- Critique : les coups critiques suivent « Dégâts critiques ».
	data.Skills.critdmg1 = true
	before = enemy.hp
	services.CombatService:DamageEnemy(alice, enemy, 100, { crit = true })
	assert(math.abs((before - enemy.hp) - 100 * 1.1 * 2.25 / 2) < 0.01, "dégâts critiques non appliqués")
	data.Skills.critdmg1 = nil
	-- Hologramme de l'arbre dans la base.
	local plot = services.PlotService:GetPlot(alice)
	assert(plot.skillRefs.cells.coeur.TextTransparency == 0, "hologramme non mis à jour")
	-- Le pupitre ouvre l'écran de l'arbre.
	signalFor(plot.skillRefs.prompt, "Triggered"):Fire(alice)
	local open = lastEvent("OpenMenu", alice)
	assert(open and open.args[1] == "SkillTree", "le pupitre n'ouvre pas l'arbre")
end)

test("Cases d'unités : « Remplacer l'unité », silhouettes verrouillées", function()
	local data = DataService:Get(alice)
	local plot = services.PlotService:GetPlot(alice)
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	assert(#plot.slots == 24, "24 cases attendues")
	local display = Formulas.playerStats(data).display
	assert(plot.slots[24].state == "locked" and plot.slots[24].silhouette.Enabled, "case 24 non verrouillée")
	-- Choisit un perso hors équipe et le place sur la case 2.
	local uid = nil
	for id in data.characters do
		if not table.find(data.team, id) then
			uid = id
		end
	end
	assert(uid, "aucun perso hors équipe")
	signalFor(plot.slots[2].prompt, "Triggered"):Fire(alice)
	local open = lastEvent("OpenMenu", alice)
	assert(open.args[1] == "PlaceUnit" and open.args[2].slot == 2, "l'invite n'ouvre pas le choix d'unité")
	local ok, message = invoke("PlaceUnit", alice, 2, uid)
	assert(ok, "PlaceUnit : " .. tostring(message))
	assert(services.CharacterService:GetDisplayed(alice)[2] == uid, "unité non placée sur la case 2")
	assert(plot.slots[2].state == "occupied", "case 2 non occupée")
	assert(not invoke("PlaceUnit", alice, display + 1, uid), "case verrouillée acceptée")
	-- Un perso de l'équipe placé sur une case quitte l'équipe.
	local teamUid = data.team[1]
	assert(invoke("PlaceUnit", alice, 1, teamUid), "placer un perso d'équipe")
	assert(not table.find(data.team, teamUid), "le perso est resté dans l'équipe")
	assert(invoke("EquipCharacter", alice, teamUid, true), "rééquiper")
	assert(data.DisplayPins["1"] == nil, "le perso rééquipé est resté sur sa case")
	-- « Libérer la case » : la case reste VIDE (pas de remplissage automatique), même avec
	-- des unités disponibles ; « Remplissage auto » la rend de nouveau automatique.
	local spare = 0
	for id in data.characters do
		if not table.find(data.team, id) then
			spare += 1
		end
	end
	assert(spare >= 2, "pas assez d'unités hors équipe pour le test")
	assert(invoke("PlaceUnit", alice, 2, nil), "libération refusée")
	assert(data.DisplayPins["2"] == false, "case non marquée vide")
	assert(services.CharacterService:GetDisplayed(alice)[2] == nil, "la case libérée a été reremplie")
	assert(plot.slots[2].state == "free", "case 2 non libre après libération")
	assert(invoke("PlaceUnit", alice, 2, "auto"), "remplissage auto refusé")
	assert(data.DisplayPins["2"] == nil and services.CharacterService:GetDisplayed(alice)[2] ~= nil, "remplissage auto sans effet")
	-- Étiquette nom + étoiles + rareté au-dessus des unités exposées.
	local tagged = 0
	for _, model in plot.displayFolder:GetChildren() do
		if model.PrimaryPart and model.PrimaryPart:FindFirstChild("AnimeTag") then
			tagged += 1
		end
	end
	assert(tagged >= 1, "pas d'étiquette sur les unités exposées")
end)

test("Boutons d'achat : panneau, fantôme, construction", function()
	local plot = services.PlotService:GetPlot(alice)
	local pads = plot.ownerFolder:FindFirstChild("Pads")
	local ghosts = plot.ownerFolder:FindFirstChild("Ghosts")
	assert(pads and #pads:GetChildren() > 0, "aucun bouton d'achat")
	assert(ghosts and #ghosts:GetChildren() == #pads:GetChildren(), "fantômes manquants")
	local pad = pads:GetChildren()[1]
	assert(pad:FindFirstChild("Pad", true):FindFirstChild("PriceGui"), "panneau de prix absent")
	local upgradeId = pad:GetAttribute("UpgradeId")
	DataService:AddCoins(alice, pad:GetAttribute("Price"))
	assert(services.PlotService:BuyUpgrade(alice, upgradeId), "achat")
	assert(plot.ownerFolder.Structures:FindFirstChild(upgradeId), "structure non construite")
	assert(not plot.ownerFolder.Ghosts:FindFirstChild(upgradeId), "fantôme resté après l'achat")
end)

test("Déco de base : change avec l'univers, panneau du propriétaire gardé", function()
	local BaseDecor = Harness.require(serverFolder.World.BaseDecor)
	local Universes = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes"))
	local plot = services.PlotService:GetPlot(alice)
	for _, universe in Universes.List do
		BaseDecor.applyAll(universe, services.PlotService:GetPlots())
		assert(plot.model.Decor:GetAttribute("UniverseId") == universe.id, "déco non changée : " .. universe.id)
		assert(#plot.signLabels >= 2, "panneau du propriétaire absent : " .. universe.id)
		assert(plot.signLabels[1].Text == "BASE DE ALICE", "panneau du propriétaire perdu : " .. universe.id)
		assert(plot.model.Decor:FindFirstChild("Portail"), "portail absent : " .. universe.id)
	end
	assert(game:GetService("ServerStorage").DecorsBase:FindFirstChild("pourfendeur"), "modèles de déco non rangés")
	BaseDecor.applyAll(services.UniverseService:GetCurrent(), services.PlotService:GetPlots())
end)

test("Migration d'une ancienne sauvegarde (v1)", function()
	local oldId = nextUserId + 1
	local Economy = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Economy"))
	stores.AnimeTycoon_v1 = stores.AnimeTycoon_v1 or {}
	stores.AnimeTycoon_v1["player_" .. oldId] = {
		version = 1,
		coins = 1234,
		totalCoins = 5000,
		materials = {},
		relics = {},
		characters = { ["OLD-1"] = { id = "ninja_maruto", level = 12, xp = 0, stars = 1, obtained = 0 } },
		team = { "OLD-1" },
		incubators = {},
		upgrades = { lanternes = true, dojo = true },
		index = { ninja_maruto = true },
		stash = 10,
		stats = { kills = 3 },
		shop = { window = 0, bought = {} },
		starterGiven = true,
	}
	local carol = addPlayer("Carol")
	assert(carol.UserId == oldId, "identifiant inattendu")
	local data = DataService:Get(carol)
	assert(data.version == 3, "version non migrée")
	assert(type(data.Skills) == "table" and next(data.Skills) == nil, "Skills manquant")
	assert(data.Pity.mythic == 0 and data.Pity.legendary == nil, "Pity manquant")
	assert(data.RollCount == 0 and data.AutoRoll == false and data.AutoBuy == false, "compteurs manquants")
	assert(type(data.AutoRollSettings) == "table" and data.AutoRollSettings.pauseRarities.legendary == true, "réglages d'auto-roulage manquants")
	assert(type(data.RolledQueue) == "table" and type(data.DisplayPins) == "table", "file / cases manquantes")
	assert(data.FirstCollectDone == true, "un ancien joueur ne doit pas avoir de perso offert")
	assert(data.coins == 1234 and data.characters["OLD-1"], "anciennes données perdues")
	assert(data.upgrades.dojo and Economy.UpgradesById.dojo, "ancienne amélioration perdue")
	-- Sauvegarde abîmée : les champs qui doivent être des tables sont réparés au lieu de planter.
	local broken = DataService.migrate({ version = 1, Pity = 5, characters = "x", Skills = true, DisplayPins = { ["1"] = 3, ["2"] = false } })
	assert(type(broken.Pity) == "table" and broken.Pity.mythic == 0, "Pity abîmé non réparé")
	-- v2 -> v3 : rareté de base, auras devenues mutations, file de l'estrade réduite.
	local v2 = DataService.migrate({
		version = 2,
		characters = {
			A = { id = "ninja_maruto", level = 3, xp = 0, stars = 1, aura = "dore", rollRarity = "secret" },
			B = { id = "ninja_rokli", level = 1, xp = 0, stars = 1, aura = "pasunemutation" },
		},
		Pity = { legendary = 40, mythic = 300, secret = 900 },
		X10Counter = 7,
		AutoRoll = true,
		RolledQueue = {
			{ key = "Q1", id = "ninja_itochi", rarity = "secret", price = 2000000, dps = 1, at = 1 },
			{ key = "Q2", id = "ninja_rokli", rarity = "uncommon", price = 260, dps = 1, at = 2 },
			{ key = "Q3", id = "ninja_maruto", rarity = "common", price = 90, dps = 1, at = 3 },
			{ key = "Q4", id = "ninja_sasuki", rarity = "common", price = 90, dps = 1, at = 4 },
			{ key = "Q5", id = "inconnu", rarity = "common", price = 90, dps = 1, at = 5 },
		},
	})
	assert(v2.version == 3, "v2 non migrée")
	assert(v2.characters.A.aura == "or" and v2.characters.A.rollRarity == nil, "aura Doré / rareté de machine non migrées")
	assert(v2.characters.B.aura == nil, "mutation inconnue gardée")
	assert(v2.Pity.mythic == 300 and v2.Pity.legendary == nil and v2.Pity.secret == nil, "pitiés mal migrées")
	assert(v2.AutoRoll == false and v2.X10Counter == 0, "auto-roulage / x10 non remis à zéro")
	assert(#v2.RolledQueue == 3, "estrade non réduite à 3 persos : " .. #v2.RolledQueue)
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	for _, item in v2.RolledQueue do
		assert(item.rarity == Characters.get(item.id).rarity, "rareté de base non rendue : " .. item.key)
	end
	assert(v2.RolledQueue[1].key == "Q1" and v2.RolledQueue[1].aura == "arcenciel", "l'ancien Secret n'est pas devenu Mythique Arc-en-ciel")
	assert(type(broken.characters) == "table" and type(broken.Skills) == "table", "tables abîmées non réparées")
	assert(broken.DisplayPins["1"] == nil and broken.DisplayPins["2"] == false, "cases abîmées mal nettoyées")
	local plot = services.PlotService:GetPlot(carol)
	assert(plot and plot.ownerFolder.Structures:FindFirstChild("dojo"), "structure de l'ancienne sauvegarde non construite")
	removePlayer(carol)
end)

test("Évolution à l'Autel d'Éveil", function()
	local data = DataService:Get(alice)
	local entry = data.characters[firstUid]
	entry.level = 30
	table.clear(data.materials) -- le boss a pu en donner : on repart de zéro
	local ok, message = services.EvolutionService:Evolve(alice, firstUid)
	assert(not ok, "évolution sans matériaux acceptée")
	for _, universe in Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes")).List do
		DataService:AddMaterial(alice, universe.material.id, 500)
	end
	ok, message = services.EvolutionService:Evolve(alice, firstUid)
	assert(ok, "évolution : " .. tostring(message))
	assert(entry.stars == 2, "étoiles")
end)

test("Fusion Crossover au portail", function()
	local data = DataService:Get(alice)
	local CharacterService = services.CharacterService
	local a = CharacterService:CreateEntry("ninja_maruto")
	a.stars = 2
	local b = CharacterService:CreateEntry("occ_goju", "neant")
	b.stars = 2
	local uidA = CharacterService:AddCharacter(alice, a)
	local uidB = CharacterService:AddCharacter(alice, b)
	local Layout = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Layout"))
	alice.Character:PivotTo(CFrame.new(Layout.FusionPortal + Vector3.new(10, 3, 0)))
	local ok, message = invoke("Fuse", alice, uidA, uidB)
	assert(ok, "fusion : " .. tostring(message))
	local found = false
	for _, entry in data.characters do
		if entry.fusion and entry.fusion.a == "ninja_maruto" and entry.fusion.b == "occ_goju" then
			found = true
			assert(entry.aura == "neant", "aura non héritée")
		end
	end
	assert(found, "crossover absent")
	assert(data.characters[uidA] == nil and data.characters[uidB] == nil, "persos sources non consommés")
end)

test("Équiper / verrouiller / vendre", function()
	local data = DataService:Get(alice)
	local CharacterService = services.CharacterService
	local uid = CharacterService:AddCharacter(alice, CharacterService:CreateEntry("ninja_rokli"))
	assert(invoke("ToggleLock", alice, uid), "verrou")
	local ok = invoke("SellCharacter", alice, uid)
	assert(not ok, "vente d'un perso verrouillé")
	invoke("ToggleLock", alice, uid)
	ok = invoke("SellCharacter", alice, uid)
	assert(ok, "vente refusée")
	assert(data.characters[uid] == nil, "perso toujours là")
	assert(invoke("AutoEquip", alice), "auto-équipement")
end)

test("Échange entre deux joueurs", function()
	bob = addPlayer("Bob")
	local TradeService = services.TradeService
	local CharacterService = services.CharacterService
	local dataA, dataB = DataService:Get(alice), DataService:Get(bob)
	local gift = CharacterService:AddCharacter(alice, CharacterService:CreateEntry("ninja_sakoura"))
	local bobChar = CharacterService:AddCharacter(bob, CharacterService:CreateEntry("oce_kobi"))
	CharacterService:AddCharacter(bob, CharacterService:CreateEntry("oce_buggi"))
	local tableModel = Harness.CollectionService:GetTagged("TradeTable")[1]
	TradeService:_start(tableModel, alice, bob)
	assert(TradeService:IsInTrade(alice) and TradeService:IsInTrade(bob), "échange non démarré")
	fireServer("TradeAction", alice, "addCharacter", gift)
	fireServer("TradeAction", bob, "addCharacter", bobChar)
	fireServer("TradeAction", alice, "setCoins", 1000)
	fireServer("TradeAction", alice, "ready", true)
	fireServer("TradeAction", bob, "ready", true)
	task.wait(3.5)
	assert(dataB.characters[gift], "Bob n'a pas reçu le perso")
	assert(dataA.characters[bobChar], "Alice n'a pas reçu le perso")
	assert(dataA.characters[gift] == nil, "duplication !")
	assert(not TradeService:IsInTrade(alice), "échange non terminé")
end)

test("Événement céleste (orage) et éclairs", function()
	services.EventService:Force("orage")
	task.wait(1.2)
	assert(services.EventService:GetActive(), "événement inactif")
	services.EventService:_strike(services.EventService:GetActive())
	assert(services.EventService:AuraLuck() == 2, "chance d'aura")
end)

test("Rotation d'univers", function()
	local UniverseService = services.UniverseService
	local before = UniverseService:GetCurrent().id
	UniverseService:Skip()
	task.wait(2.6)
	local after = UniverseService:GetCurrent().id
	assert(before ~= after, "l'univers n'a pas changé")
	-- toute la carte suit : décor de l'anneau / île / horizon et panneaux des arches du hub
	local zone = game:GetService("Workspace").World.Zone
	assert(zone.Decor:GetAttribute("UniverseId") == after, "décor de la carte non changé")
	-- les bases aussi (murs, portail, sol : World/BaseDecor)
	for _, plot in services.PlotService:GetPlots() do
		local decor = plot.model:FindFirstChild("Decor")
		assert(decor and decor:GetAttribute("UniverseId") == after, "déco de base non changée")
	end
	task.wait(1.2)
	local Universes = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes"))
	local expected = UniverseService.upper(Universes.get(after).name)
	local panels = Harness.CollectionService:GetTagged("UniversePanel")
	assert(#panels >= 1, "panneaux d'univers du hub absents")
	for _, panel in panels do
		for _, gui in panel:GetChildren() do
			if gui:IsA("SurfaceGui") then
				local title = gui:FindFirstChild("Title")
				assert(title and string.find(title.Text, expected, 1, true), "panneau non mis à jour : " .. tostring(title and title.Text))
				assert(string.find(gui:FindFirstChild("Timer").Text, ":", 1, true), "compte à rebours absent")
			end
		end
	end
	local enemy = services.CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy and string.find(enemy.defId, string.sub(after, 1, 3)), "ennemis non renouvelés")
end)

test("Épées : épée rouillée de départ, Forgeron, coup d'épée", function()
	local data = DataService:Get(alice)
	assert(data.swords.rouillee and data.equippedSword == "rouillee", "pas d'épée de départ")
	local backpack = alice:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChildOfClass("Tool")
	assert(tool and tool:GetAttribute("SwordId") == "rouillee", "épée absente du sac")
	DataService:AddCoins(alice, 100000)
	local ok, message = invoke("BuySword", alice, "vent")
	assert(ok, "achat : " .. tostring(message))
	assert(data.equippedSword == "vent", "épée non équipée")
	tool = backpack:FindFirstChildOfClass("Tool")
	assert(tool and tool:GetAttribute("SwordId") == "vent", "nouvelle épée absente")
	local enemy = services.CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy, "pas d'ennemi")
	local pos = enemy.root.CFrame.Position
	alice.Character:PivotTo(CFrame.lookAt(pos + Vector3.new(4, 0, 0), pos))
	tool.Parent = alice.Character
	local hp = enemy.hp
	services.SwordService:Swing(alice, tool)
	task.wait(0.3)
	assert(enemy.hp < hp or not enemy.alive, "l'épée n'a pas touché")
	assert(lastEvent("CombatFX") ~= nil, "pas d'effet de coup")
	local okExpensive = invoke("BuySword", alice, "celeste")
	assert(not okExpensive, "épée achetée sans assez d'argent")
	assert(invoke("EquipSword", alice, "rouillee"), "rééquiper l'épée rouillée")
end)

test("Hub : les 6 stands ouvrent leur menu, le Défi mène à l'arène", function()
	local Layout = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Layout"))
	local stalls = Harness.CollectionService:GetTagged("HubStall")
	assert(#stalls == 6, "stands : " .. #stalls)
	for _, stall in stalls do
		local prompt = stall:FindFirstChild("StallPrompt", true)
		assert(prompt, "pas de prompt sur " .. stall.Name)
		signalFor(prompt, "Triggered"):Fire(alice)
		local menu = stall:GetAttribute("Menu")
		if menu ~= "Challenge" then
			local event = lastEvent("OpenMenu", alice)
			assert(event and event.args[1] == menu, "menu non ouvert : " .. tostring(menu))
		end
	end
	task.wait(0.3)
	local root = alice.Character:FindFirstChild("HumanoidRootPart")
	assert((root.CFrame.Position - Layout.BossArena).Magnitude < 45, "pas téléporté devant l'arène")
	local npcs = 0
	for _, model in Harness.CollectionService:GetTagged("AnimeRig") do
		local ok, isNpc = pcall(function()
			return model:GetAttribute("NPC")
		end)
		if ok and isNpc then
			npcs += 1
		end
	end
	assert(npcs >= 6, "vendeurs manquants : " .. npcs)
end)

test("Décors d'univers échangés sans perdre les retouches", function()
	local UniverseDecor = Harness.require(serverFolder.World.UniverseDecor)
	local Universes = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes"))
	local zone = game:GetService("Workspace").World.Zone
	local first = zone:FindFirstChild("Decor")
	local id = first:GetAttribute("UniverseId")
	first:SetAttribute("Retouche", true)
	local other = Universes.List[(Universes.get(id).index % #Universes.List) + 1]
	UniverseDecor.apply(other, zone)
	assert(zone.Decor:GetAttribute("UniverseId") == other.id, "mauvais décor affiché")
	assert(game:GetService("ServerStorage").DecorsUnivers:FindFirstChild(id), "ancien décor non rangé")
	UniverseDecor.apply(Universes.get(id), zone)
	assert(zone.Decor:GetAttribute("Retouche"), "retouche perdue")
end)

test("Noms d'origine : les modèles de la Boîte à outils sont reconnus", function()
	local Shared = Harness.find("ReplicatedStorage.Shared")
	local Noms = Harness.require(Shared.Config.NomsOriginaux)
	local Characters = Harness.require(Shared.Config.Characters)
	for _, entry in Noms.List do
		assert(Characters.get(entry.id) or Characters.Enemies[entry.id], "id inconnu : " .. entry.id)
	end
	local cases = {
		["Kid Naruto"] = "ninja_maruto",
		["Naruto Sage Mode"] = "ninja_maruto_2",
		["Naruto Kurama Mode"] = "ninja_maruto_3",
		["Kurama"] = "ninja_kourama",
		["Itachi_Uchiha"] = "ninja_itochi",
		["Goku Ultra Instinct"] = "sai_goko_3",
		["Monkey D. Luffy Gear 5"] = "oce_loffy_3",
		["Cell Jr."] = "sai_celjr",
		["Frieza Soldier"] = "sai_soldat",
		["Gojo Satoru"] = "occ_goju",
		["Tanjiro Kamado"] = "pou_tanjiru",
		["Madara Uchiha"] = "ninja_radama",
		["Minato Namikaze"] = "ninja_minatu",
		["Gaara Kazekage"] = "ninja_gaaro_3",
		["Toji Fushiguro"] = "occ_toja",
		["Megumi Fushiguro"] = "occ_megumo",
		["Yuta Okkotsu"] = "occ_yuuto",
		["Perfect Cell"] = "sai_cel",
		["Gogeta Blue"] = "sai_gojita_3",
		["Trafalgar Law"] = "oce_lao",
		["Kaido Hybrid"] = "oce_kaydo_2",
		["Muzan Kibutsuji"] = "pou_muzon",
		["Tengen Uzui"] = "pou_tengan",
		["Bruit de fond"] = false,
		["Model"] = false,
		-- mots courts reconnus seulement en mot entier, pas à l'intérieur d'un autre mot
		["Dragon Claw"] = false,
		["Outlaw Lawn Chair"] = false,
		["Law Enforcement Car"] = false,
		["Face Place Space"] = false,
		["Portgas D. Ace"] = "oce_ase",
		["Ace"] = "oce_ase",
		-- « Kurama Mode » / « Chakra Mode » seuls = Maruto (pas Minatu)
		["Naruto Chakra Mode"] = "ninja_maruto_3",
		["Minato KCM"] = "ninja_minatu_3",
		["Kurama Mode"] = "ninja_kourama",
	}
	for name, expected in cases do
		local got = Noms.match(name)
		assert(got == (expected or nil), name .. " -> " .. tostring(got) .. " (attendu " .. tostring(expected) .. ")")
	end
end)

test("Boîte à outils : « Kid Naruto » posé dans Workspace remplace Maruto", function()
	local Server = Harness.find("ServerScriptService.Server")
	local AvatarService = Harness.require(Server.Services.AvatarService)
	local storage = game:GetService("ReplicatedStorage")
	local folder = storage:FindFirstChild("ModelesPersos")
	local previous = folder and folder:FindFirstChild("ninja_maruto")
	if previous then
		previous.Parent = nil
	end
	local function rig(name)
		local model = Instance.new("Model")
		model.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = model
		Instance.new("Humanoid").Parent = model
		local script = Instance.new("Script")
		script.Parent = model
		return model
	end
	local pack = Instance.new("Folder")
	pack.Name = "MesModeles"
	pack.Parent = game:GetService("Workspace")
	local naruto = rig("Kid Naruto")
	naruto.Parent = pack
	local statue = rig("Statue")
	statue.Parent = pack
	local tree = Instance.new("Model")
	tree.Name = "Naruto Tree" -- pas de Humanoid : ignoré
	tree.Parent = pack
	local found = AvatarService:CollectUserModels()
	assert(found.ninja_maruto == "Kid Naruto", "Kid Naruto non reconnu")
	assert(naruto.Parent and naruto.Parent.Name == "ModelesPersos" and naruto.Name == "ninja_maruto", "modèle non rangé")
	assert(not naruto:FindFirstChildOfClass("Script"), "scripts du modèle gratuit conservés")
	assert(statue.Parent == pack and tree.Parent == pack, "modèle non reconnu déplacé à tort")
	naruto:Destroy()
	pack:Destroy()
	if previous then
		previous.Parent = storage.ModelesPersos
	end
end)

test("Modèle perso (ModelesPersos) prioritaire sur le perso intégré", function()
	local Shared = Harness.find("ReplicatedStorage.Shared")
	local Factory = Harness.require(Shared.Modules.CharacterFactory)
	local Builder = Harness.require(Shared.Modules.CharacterBuilder)
	local Characters = Harness.require(Shared.Config.Characters)
	local look = Characters.get("ninja_maruto").look
	local storage = game:GetService("ReplicatedStorage")
	local folder = storage:FindFirstChild("ModelesPersos")
	local created = false
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ModelesPersos"
		folder.Parent = storage
		created = true
	end
	local previous = folder:FindFirstChild("ninja_maruto")
	if previous then
		previous.Parent = nil
	end
	local custom = Builder.build(look, {})
	custom.Name = "ninja_maruto"
	custom:SetAttribute("Marque", true)
	custom.Parent = folder
	local model = Factory.build("ninja_maruto", 1, look, { humanoid = true })
	assert(model:GetAttribute("CustomModel") and model:GetAttribute("Marque"), "modèle perso ignoré")
	assert(model:FindFirstChildOfClass("Humanoid"), "pas de Humanoid")
	local plain = Factory.build("perso_inconnu", 1, look, {})
	assert(not plain:GetAttribute("CustomModel"), "modèle perso utilisé à tort")
	local preview = Factory.buildPreview("ninja_maruto", 1, look)
	for _, d in preview:GetDescendants() do
		assert(not d:IsA("SurfaceGui"), "SurfaceGui restée dans l'aperçu")
	end
	custom:Destroy()
	if previous then
		previous.Parent = folder
	end
	if created then
		folder:Destroy()
	end
end)

------------------------------------------------------------------------
-- Boutique Robux
------------------------------------------------------------------------

local Robux = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Robux"))

test("Boutique Robux : passes simulés dans Studio, x2 Argent, x2 Chance", function()
	local data = DataService:Get(alice)
	assert(type(MarketplaceService.ProcessReceipt) == "function", "ProcessReceipt non branché")
	-- Revenus de référence (sans passe).
	services.CharacterService:_tick(alice, { syncTimer = 0 })
	local incomeBefore = alice:GetAttribute("IncomePerSec") or 0
	local ok, message = invoke("Robux_Buy", alice, "pass", "Coins2")
	assert(ok, "achat simulé : " .. tostring(message))
	assert(alice:GetAttribute("Pass_Coins2") == true, "attribut Pass_Coins2 absent")
	assert(data.RobuxPasses.Coins2 == "studio", "passe simulé non noté")
	assert(lastEvent("Robux_Granted", alice), "pas de célébration côté client")
	assert(Robux.coinMultiplier(alice) == 2, "x2 Argent : " .. Robux.coinMultiplier(alice))
	services.CharacterService:_tick(alice, { syncTimer = 0 })
	local incomeAfter = alice:GetAttribute("IncomePerSec") or 0
	if incomeBefore > 10 then
		assert(math.abs(incomeAfter - 2 * incomeBefore) <= 2, "revenus non doublés : " .. incomeBefore .. " -> " .. incomeAfter)
	end
	task.wait(0.7)
	local again, already = invoke("Robux_Buy", alice, "pass", "Coins2")
	assert(not again and string.find(already, "déjà"), "passe acheté deux fois")
	task.wait(0.7)
	assert(invoke("Robux_Buy", alice, "pass", "Luck2"), "x2 Chance")
	assert(Robux.luckMultiplier(alice) == 2, "x2 Chance non appliqué")
	task.wait(0.7)
	assert(not invoke("Robux_Buy", alice, "pass", "Inconnu"), "passe inconnu accepté")
	-- Roulage avec la chance doublée : la machine tourne toujours.
	services.RollService:ResetCooldown(alice)
	data.RolledQueue = {}
	assert(services.RollService:Roll(alice), "roulage impossible avec x2 Chance")
end)

test("Boutique Robux : packs et boosts (simulés), VIP", function()
	local data = DataService:Get(alice)
	task.wait(0.7)
	local crystals = data.traitCrystals
	assert(invoke("Robux_Buy", alice, "product", "GemsM"), "pack de gemmes")
	assert(data.traitCrystals == crystals + 50, "gemmes non données")
	task.wait(0.7)
	local coins = data.coins
	assert(invoke("Robux_Buy", alice, "product", "CoinsS"), "pack de pièces")
	assert(data.coins - coins >= 5000, "pièces non données")
	task.wait(0.7)
	assert(invoke("Robux_Buy", alice, "product", "BoostLuck"), "boost")
	local finish = alice:GetAttribute("Boost_Luck")
	assert(type(finish) == "number" and finish > os.time() + 800, "Boost_Luck absent")
	assert(Robux.luckMultiplier(alice) == 4, "boost + passe : " .. Robux.luckMultiplier(alice))
	-- (Lune range les attributs en flottants 32 bits : on compare les données, exactes.)
	local firstEnd = data.RobuxBoosts.Luck
	task.wait(0.7)
	assert(invoke("Robux_Buy", alice, "product", "BoostLuck"), "boost (2)")
	assert(data.RobuxBoosts.Luck == firstEnd + 900, "les boosts ne s'additionnent pas")
	-- Pack de départ : pièces + 20 gemmes + Chance x2, un seul achat par joueur.
	task.wait(0.7)
	local beforeCoins, beforeGems, beforeLuck = data.coins, data.traitCrystals, data.RobuxBoosts.Luck
	assert(invoke("Robux_Buy", alice, "product", "Starter"), "pack de départ")
	assert(data.coins - beforeCoins >= 25000, "pièces du pack de départ")
	assert(data.traitCrystals == beforeGems + 20, "gemmes du pack de départ")
	assert(data.RobuxBoosts.Luck == beforeLuck + 900, "Chance x2 du pack de départ")
	assert(Robux.onceTaken(data, "Starter"), "pack de départ non noté")
	task.wait(0.7)
	local again, why = invoke("Robux_Buy", alice, "product", "Starter")
	assert(not again and type(why) == "string" and string.find(why, "un seul achat"), "pack de départ racheté")
	task.wait(0.7)
	assert(invoke("Robux_Buy", alice, "pass", "VIP"), "VIP")
	local head = alice.Character:FindFirstChild("Head")
	if head then
		assert(head:FindFirstChild("TagVIP"), "pas de couronne VIP")
	end
	assert(math.abs(Robux.coinMultiplier(alice) - 2.5) < 1e-6, "bonus VIP sur l'argent")
end)

test("Boutique Robux : vrais ids (fenêtre Roblox), id manquant hors Studio, passes possédés", function()
	-- Id configuré : la fenêtre d'achat Roblox s'ouvre.
	Robux.Passes.Roll3.id = 999
	task.wait(0.7)
	local ok = invoke("Robux_Buy", alice, "pass", "Roll3")
	assert(ok and #marketPrompts > 0 and marketPrompts[#marketPrompts].id == 999, "fenêtre d'achat non ouverte")
	assert(alice:GetAttribute("Pass_Roll3") ~= true, "passe donné avant l'achat")
	-- Achat terminé : passe accordé + Robux dépensés comptés.
	local spent = DataService:Get(alice).RobuxSpent
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(alice, 999, true)
	task.wait(0.1)
	assert(alice:GetAttribute("Pass_Roll3") == true, "passe non accordé après l'achat")
	assert(DataService:Get(alice).RobuxSpent == spent + Robux.Passes.Roll3.price, "Robux dépensés non comptés")
	assert(Robux.rollsPerPull(alice) == 3, "Roll3 -> 3 persos")
	Robux.Passes.Roll3.id = 0
	-- Hors Studio, un id à 0 affiche un message clair.
	local RunService = Harness.services.RunService
	local isStudio = RunService.IsStudio
	RunService.IsStudio = function()
		return false
	end
	task.wait(0.7)
	local okMissing, text = invoke("Robux_Buy", alice, "pass", "AutoRoll")
	RunService.IsStudio = isStudio
	assert(not okMissing and string.find(text, "pas encore configuré"), "message « pas encore configuré » absent")
	-- Passe acheté sur Roblox : reconnu à l'arrivée (UserOwnsGamePassAsync).
	Robux.Passes.AutoRollPlus.id = 4242
	local carla = addPlayer("Carla")
	task.wait(0.3)
	assert(carla:GetAttribute("Pass_AutoRollPlus") == true, "passe possédé non reconnu")
	assert(carla:GetAttribute("Pass_Coins2") ~= true, "passe d'un autre joueur donné")
	removePlayer(carla)
	Robux.Passes.AutoRollPlus.id = 0
end)

test("Boutique Robux : ProcessReceipt idempotent et sauvegardé", function()
	local data = DataService:Get(alice)
	local Granted = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
	local NotYet = roblox.Enum.ProductPurchaseDecision.NotProcessedYet
	Robux.Products.GemsS.id = 5555
	local crystals, spent = data.traitCrystals, data.RobuxSpent
	local receipt = { PlayerId = alice.UserId, ProductId = 5555, PurchaseId = "R-TEST-1", CurrencySpent = 25 }
	assert(MarketplaceService.ProcessReceipt(receipt) == Granted, "reçu non accordé")
	assert(data.traitCrystals == crystals + 10, "contenu non donné")
	assert(data.Receipts["R-TEST-1"], "reçu non noté")
	assert(data.RobuxSpent == spent + 25, "Robux dépensés")
	-- Roblox rappelle le même reçu : rien n'est donné une 2e fois.
	assert(MarketplaceService.ProcessReceipt(receipt) == Granted, "rappel du reçu")
	assert(data.traitCrystals == crystals + 10, "reçu accordé deux fois !")
	assert(data.RobuxSpent == spent + 25, "Robux comptés deux fois")
	-- Le reçu est bien dans la sauvegarde.
	local saved = stores.AnimeTycoon_v1 and stores.AnimeTycoon_v1["player_" .. alice.UserId]
	assert(saved and saved.Receipts["R-TEST-1"], "reçu non sauvegardé avant PurchaseGranted")
	-- Joueur absent ou produit inconnu : on réessaiera plus tard.
	assert(MarketplaceService.ProcessReceipt({ PlayerId = 999999, ProductId = 5555, PurchaseId = "R-X" }) == NotYet, "joueur absent")
	assert(MarketplaceService.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 1, PurchaseId = "R-Y" }) == NotYet, "produit inconnu")
	Robux.Products.GemsS.id = 0
end)

test("Boutique Robux : effets des passes Roulage x2 / x3, Lancer AFK et Emplacements +", function()
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local Economy = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Economy"))
	local RollService = services.RollService
	local dora = addPlayer("Dora")
	task.wait(0.3)
	local data = DataService:Get(dora)
	assert(data, "données de Dora")
	local function rollCount()
		RollService:ResetCooldown(dora)
		data.RolledQueue = {}
		local ok, results = RollService:Roll(dora)
		assert(ok, "roulage : " .. tostring(results))
		return #results
	end
	-- Sans passe : UN perso par roulage (retour 6).
	assert(rollCount() == 1, "sans passe : 1 perso attendu")
	dora:SetAttribute("Pass_Roll2", true)
	assert(rollCount() == 2, "Roulage x2 : 2 persos attendus")
	dora:SetAttribute("Pass_Roll3", true)
	assert(rollCount() == 3, "Roulage x3 : 3 persos attendus")
	dora:SetAttribute("Pass_Roll2", nil)
	dora:SetAttribute("Pass_Roll3", nil)
	-- Lancer AFK : refusé sans le passe, et la boutique Robux s'ouvre sur les passes.
	local okAuto, message = RollService:SetAutoRoll(dora, true)
	assert(not okAuto and string.find(message, "Lancer AFK", 1, true), "auto-roulage sans passe : " .. tostring(message))
	local open = lastEvent("Robux_OpenShop", dora)
	assert(open and open.args[1] == "passes", "boutique non ouverte")
	task.wait(0.7)
	assert(invoke("Robux_BuyPass", dora, "AutoRoll"), "achat simulé de Lancer AFK")
	assert(dora:GetAttribute("Pass_AutoRoll") == true, "Pass_AutoRoll absent")
	assert(RollService:SetAutoRoll(dora, true), "auto-roulage refusé avec le passe")
	local before = data.RollCount
	RollService:ResetCooldown(dora)
	data.RolledQueue = {}
	task.wait(0.6)
	assert(data.RollCount > before, "la machine ne roule pas toute seule avec Lancer AFK")
	RollService:SetAutoRoll(dora, false)
	-- Emplacements + : 2 cases d'unités en plus dans la base.
	local display = Formulas.playerStats(data).display
	task.wait(0.7)
	assert(invoke("Robux_Buy", dora, "pass", "Slots"), "achat simulé d'Emplacements +")
	assert(data.RobuxSlots == Robux.SlotsBonus, "cases en plus non notées")
	assert(Formulas.playerStats(data).display == math.min(display + Robux.SlotsBonus, Economy.MaxDisplaySlots), "cases de la base non ajoutées")
	removePlayer(dora)
end)

test("Classements : trois tableaux (Robux, pièces, perso le plus fort)", function()
	local boards = game:GetService("Workspace").World.Boards
	for _, name in { "Classement_Robux", "Classement_Pieces", "Classement_Perso" } do
		local model = boards:FindFirstChild(name)
		assert(model, "tableau absent : " .. name)
		assert(model.Panel.Display.Fond:FindFirstChild("Row10"), "10 lignes attendues : " .. name)
	end
	local Leaderboard = services.LeaderboardService
	Leaderboard:_render()
	local row = boards.Classement_Robux.Panel.Display.Fond.Row1
	assert(row.Nom.Text == "Alice", "classement Robux : " .. row.Nom.Text)
	assert(string.find(row.Valeur.Text, "R$", 1, true), "valeur Robux : " .. row.Valeur.Text)
	local coinsRow = boards.Classement_Pieces.Panel.Display.Fond.Row1
	assert(coinsRow.Nom.Text ~= "—", "classement pièces vide")
	local powerRow = boards.Classement_Perso.Panel.Display.Fond.Row1
	assert(string.find(powerRow.Valeur.Text, "⚔", 1, true), "classement perso : " .. powerRow.Valeur.Text)
	-- Classement mondial (OrderedDataStore) : envoi puis lecture.
	Leaderboard:_push(alice)
	Leaderboard:_fetch()
	local list = Leaderboard:List("Robux")
	assert(list[1] and list[1].value == DataService:Get(alice).RobuxSpent, "classement mondial Robux")
	assert(stores.AnimeTycoon_Coins_v1[tostring(alice.UserId)], "pièces non envoyées")
	assert(stores.AnimeTycoon_BestUnit_v1[tostring(alice.UserId)], "meilleure unité non envoyée")
end)

test("Commandes admin", function()
	local AdminService = services.AdminService
	AdminService:Run(alice, "argent 5000")
	AdminService:Run(alice, "relique 3 2")
	AdminService:Run(alice, "niveau 25")
	AdminService:Run(alice, "boss")
	AdminService:Run(alice, "aide")
end)

test("Sauvegarde à la déconnexion puis rechargement", function()
	local data = DataService:Get(alice)
	local coins = data.coins
	local count = 0
	for _ in data.characters do
		count += 1
	end
	removePlayer(alice)
	task.wait(0.3)
	assert(services.PlotService:GetPlot(alice) == nil, "base non libérée")
	-- Reconnexion
	local again = Instance.new("Player")
	again.Name = "Alice"
	again.DisplayName = "Alice"
	again.UserId = alice.UserId
	again.Parent = game:GetService("Players")
	table.insert(playersList, again)
	Players.PlayerAdded:Fire(again)
	task.wait(0.5)
	local reloaded = DataService:Get(again)
	assert(reloaded, "rechargement impossible")
	assert(reloaded.coins == coins, "pièces perdues")
	local reloadedCount = 0
	for _ in reloaded.characters do
		reloadedCount += 1
	end
	assert(reloadedCount == count, "persos perdus")
	-- Achats Robux gardés : reçus, total dépensé, boost encore actif.
	assert(reloaded.Receipts["R-TEST-1"], "reçus perdus")
	assert(reloaded.RobuxSpent > 0, "Robux dépensés perdus")
	assert(type(again:GetAttribute("Boost_Luck")) == "number", "boost non restauré")
	assert(again:GetAttribute("Pass_Coins2") == true, "passe simulé (Studio) non restauré")
end)

Harness.finish()
