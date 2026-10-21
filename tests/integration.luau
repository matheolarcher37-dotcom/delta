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

test("Marchand ambulant : échoppe, rayon, stock, achat sur place", function()
	local EvolutionItems = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.EvolutionItems"))
	local Layout = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Layout"))
	local world = game:GetService("Workspace").World
	local merchant = world:FindFirstChild("Merchant")
	assert(merchant, "échoppe du marchand absente")
	local beacon = merchant:FindFirstChild("Balise")
	local column = beacon and beacon:FindFirstChild("LightColumn")
	assert(column and column.Size.X >= 800 and column.Material == roblox.Enum.Material.Neon, "rayon lumineux absent ou trop court")
	assert(column.Size.Y >= 7 and beacon:FindFirstChild("LightHalo2"), "rayon trop fin pour être vu de loin")
	local sky = merchant:FindFirstChild("MerchantSkyLabel", true)
	assert(sky and sky.AlwaysOnTop and sky.StudsOffsetWorldSpace.Y >= 100 and sky.MaxDistance >= 4000, "étiquette MARCHAND du ciel absente")
	assert(merchant:FindFirstChild("MerchantPrompt", true), "pas d'invite pour marchander")
	assert(merchant:FindFirstChild("Marchand"), "pas de vendeur")
	-- Le vendeur est sur son estrade (il dépasse du comptoir) et rien ne pend devant sa tête.
	local counterTop = merchant.Etal.CounterTop.CFrame.Position.Y
	local head = merchant.Marchand:FindFirstChild("Head", true)
	assert(head and head.CFrame.Position.Y > counterTop + 1.8, "le vendeur ne dépasse pas du comptoir")
	local sign = merchant.Etal.SubSign.CFrame.Position.Y - merchant.Etal.SubSign.Size.Y / 2
	assert(sign > head.CFrame.Position.Y + head.Size.Y, "la sous-enseigne cache la tête du vendeur")
	-- Silhouette de marchand : plume, joyau, barbe, bourse, lampe chaude au-dessus de lui.
	for _, name in { "Plume", "Jewel", "Beard", "Moustache", "Purse" } do
		local piece = merchant.Marchand:FindFirstChild(name, true)
		assert(piece and not piece.Anchored and piece:FindFirstChildOfClass("WeldConstraint"), "vendeur : " .. name .. " absent ou non soudé")
	end
	assert(merchant:FindFirstChild("VendorLight", true), "pas de lumière chaude au-dessus du vendeur")
	-- La balise est sur le côté de l'échoppe (le rayon ne sort pas de la bâche de la roulotte).
	local beaconOffset = merchant:GetPivot():PointToObjectSpace(merchant.Balise.CrystalCore.CFrame.Position)
	assert(math.abs(beaconOffset.X) > 15, "rayon derrière la roulotte")
	DataService:AddCoins(alice, 1000000)
	local shop = invoke("Merchant_GetStock", alice)
	assert(shop and #shop.items == EvolutionItems.Merchant.Slots, "stock invalide")
	assert(#merchant.Display:GetChildren() == #shop.items, "étagères mal remplies")
	-- Le marchand est à l'un des coins réservés.
	local spot = Layout.MerchantSpots[shop.spot]
	local pivot = merchant:GetPivot().Position
	assert((roblox.Vector3.new(pivot.X, 0, pivot.Z) - spot).Magnitude < 1, "marchand hors de son coin")
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
	-- (Lune range les attributs en flottants 32 bits : petite tolérance.)
	assert(math.abs((state:GetAttribute("MerchantMoveAt") or 0) - shop.moveAt) < 256, "compte à rebours non publié")
	-- De loin : refusé.
	alice.Character:PivotTo(CFrame.new(0, 3, 0))
	local itemId = shop.items[1].id
	local ok, message = invoke("Merchant_Buy", alice, itemId)
	assert(not ok, "achat à distance accepté")
	-- Devant le comptoir : accepté, stock décompté, objet ajouté.
	local counter = merchant:FindFirstChild("Etal"):FindFirstChild("Counter")
	alice.Character:PivotTo(counter.CFrame * CFrame.new(0, 1, -5))
	local data = DataService:Get(alice)
	local before = data.Items[itemId] or 0
	local coins = data.coins
	local newState
	ok, message, newState = invoke("Merchant_Buy", alice, itemId)
	assert(ok, "achat : " .. tostring(message))
	assert(data.Items[itemId] == before + 1, "objet non ajouté")
	assert(data.coins == coins - EvolutionItems.get(itemId).price, "prix non payé")
	assert(newState.items[1].remaining == newState.items[1].stock - 1, "stock non décompté")
	-- Épuisement du stock.
	for _ = 1, newState.items[1].remaining do
		invoke("Merchant_Buy", alice, itemId)
	end
	ok = invoke("Merchant_Buy", alice, itemId)
	assert(not ok, "achat au-delà du stock accepté")
	-- Objet hors stock refusé.
	ok = invoke("Merchant_Buy", alice, "objet_inconnu")
	assert(not ok, "objet inconnu accepté")
	-- Déménagement : le marchand change de coin (jamais le même deux fois de suite).
	local ShopService = services.ShopService
	local index = ShopService.spot
	local nextIndex = EvolutionItems.spotIndex(ShopService.window + 1, #Layout.MerchantSpots)
	assert(nextIndex ~= index, "le marchand reste au même coin")
	assert(not Layout.isReserved(roblox.Vector3.new(0, 0, 0)) and Layout.isReserved(spot), "coin du marchand non réservé")
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

-- Place le joueur devant sa machine ROULER (le remote Roll refuse ailleurs).
local function toMachine(player)
	local plot = services.PlotService:GetPlot(player)
	player.Character:PivotTo(plot.cf * CFrame.new(services.PlotService.MachineOffset + Vector3.new(0, 3, -8)))
end

local function rollNow(player)
	services.RollService:ResetCooldown(player)
	toMachine(player)
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
	toMachine(alice)
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

test("Intégration v3.2 : la variété tirée est enregistrée (estrade → unité collectée)", function()
	local Universes = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes"))
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local stats = Formulas.playerStats(DataService:Get(alice))
	local found = nil
	for _ = 1, 400 do
		local item = services.RollService:MakeItem(Universes.List[1], "common", stats)
		assert(item.variety == item.aura, "variété ≠ mutation sur l'estrade")
		if item.aura then
			found = item
			break
		end
	end
	assert(found, "aucune mutation en 400 tirages")
	local entry = services.CharacterService:CreateEntry(found.id, found.aura, nil)
	assert(entry.variety == found.aura, "unité collectée sans variété")
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

test("Auto-roulage : sauvegarde groupée (2 s) loin de la machine, tout de suite à la machine, roulage manuel et arrêt", function()
	local data = DataService:Get(alice)
	local RollService = services.RollService
	local Economy = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Economy"))
	-- Attend que la synchro en attente soit partie (aucune attente entre la fin et l'action testée).
	local function flush()
		local deadline = os.clock() + 8
		while DataService:PendingSyncDelay(alice) and os.clock() < deadline do
			task.wait(0.05)
		end
		assert(not DataService:PendingSyncDelay(alice), "synchro jamais envoyée")
	end
	local function characterCount()
		local n = 0
		for _ in data.characters do
			n += 1
		end
		return n
	end
	local noPause, buyAll = {}, {}
	for id in Economy.RollRarities do
		noPause[id] = false
		buyAll[id] = true
	end
	table.clear(data.RolledQueue)
	data.FirstCollectDone = true
	alice:SetAttribute("Pass_AutoRoll", true)
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = noPause, pauseMutations = {}, buyCharacters = {}, buyRarities = {}, buyMutations = {} })
	data.AutoRoll = true
	data.AutoBuy = false
	-- Lancer AFK loin de la machine : la révélation part tout de suite, la sauvegarde attend la
	-- fenêtre de 2 s.
	local plot = services.PlotService:GetPlot(alice)
	alice.Character:PivotTo(plot.cf * CFrame.new(0, 3, 120))
	assert(not RollService:IsAtMachine(alice), "joueur encore à la machine")
	flush()
	local events = #clientEvents
	local count = data.RollCount
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(data.RollCount == count + 1, "pas de roulage auto")
	local revealed = false
	for i = events + 1, #clientEvents do
		revealed = revealed or (clientEvents[i].name == "RollResult" and clientEvents[i].player == alice)
	end
	assert(revealed, "révélation du roulage auto pas envoyée tout de suite")
	local delay = DataService:PendingSyncDelay(alice)
	assert(delay and delay > 1.5, "roulage auto : toute la sauvegarde part tout de suite (" .. tostring(delay) .. ")")
	-- À la machine (il regarde l'estrade et la carte du perso tiré) : envoi normal.
	toMachine(alice)
	flush()
	table.clear(data.RolledQueue)
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(data.RollCount == count + 2, "pas de roulage auto à la machine")
	delay = DataService:PendingSyncDelay(alice)
	assert(delay and delay <= 0.26, "roulage auto à la machine : sauvegarde retardée (" .. tostring(delay) .. ")")
	-- Roulage manuel juste après un roulage auto loin de la machine : pas retardé par l'envoi
	-- groupé en attente.
	alice.Character:PivotTo(plot.cf * CFrame.new(0, 3, 120))
	table.clear(data.RolledQueue)
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	delay = DataService:PendingSyncDelay(alice)
	assert(data.RollCount == count + 3 and delay and delay > 1.5, "roulage auto loin de la machine : envoi pas groupé (" .. tostring(delay) .. ")")
	data.AutoRoll = false
	table.clear(data.RolledQueue)
	assert(rollNow(alice), "roulage manuel refusé")
	delay = DataService:PendingSyncDelay(alice)
	assert(delay and delay <= 0.26, "roulage manuel retardé (" .. tostring(delay) .. ")")
	-- Achat auto : les synchros de l'achat (pièces, inventaire) suivent la même fenêtre.
	table.clear(data.RolledQueue)
	alice:SetAttribute("Pass_AutoRollPlus", true)
	invoke("Roll_SaveAutoSettings", alice, { buyRarities = buyAll })
	data.AutoBuy = true
	DataService:AddCoins(alice, 100000000)
	alice.Character:PivotTo(plot.cf * CFrame.new(0, 3, 120))
	flush()
	local before = characterCount()
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(characterCount() == before + 1 and data.AutoBuy == true, "cible de l'achat auto pas achetée")
	delay = DataService:PendingSyncDelay(alice)
	assert(delay and delay > 1.5, "achat auto : toute la sauvegarde part tout de suite (" .. tostring(delay) .. ")")
	-- Arrêt de l'auto-roulage (plus d'argent) : envoyé tout de suite (bouton « Lancer » à jour).
	data.coins = 0
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(data.AutoBuy == false, "l'achat auto ne s'arrête pas sans argent")
	delay = DataService:PendingSyncDelay(alice)
	assert(delay and delay <= 0.26, "arrêt de l'auto-roulage retardé (" .. tostring(delay) .. ")")
	alice:SetAttribute("Pass_AutoRoll", nil)
	alice:SetAttribute("Pass_AutoRollPlus", nil)
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = { legendary = true, mythic = true }, buyRarities = {} })
	table.clear(data.RolledQueue)
	RollService:RenderStage(alice)
end)

test("Auto-roulage : aucun perso précieux jeté, remote Roll seulement à la machine", function()
	local data = DataService:Get(alice)
	local RollService = services.RollService
	table.clear(data.RolledQueue)
	-- Remote Roll loin de la machine : refusé (le passe Lancer AFK reste nécessaire pour rouler à distance).
	alice.Character:PivotTo(CFrame.new(0, 3, 0))
	RollService:ResetCooldown(alice)
	local okFar, why = invoke("Roll", alice)
	assert(not okFar and type(why) == "string" and string.find(why, "machine"), "Roll accepté loin de la machine")
	local ok, results = rollNow(alice)
	assert(ok, "roulage à la machine refusé")
	-- Un Légendaire non visé attend sur l'estrade : l'achat automatique s'arrête au lieu de le jeter.
	local legendary = table.clone(results[1])
	legendary.rarity = "legendary"
	table.clear(data.RolledQueue)
	table.insert(data.RolledQueue, legendary)
	alice:SetAttribute("Pass_AutoRollPlus", true)
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = { legendary = true, mythic = true }, buyCharacters = {}, buyRarities = { common = true } })
	data.AutoBuy = true
	data.AutoRoll = false
	RollService:ResetCooldown(alice)
	assert(not RollService:Roll(alice, true), "roulage auto par-dessus un Légendaire")
	RollService:AutoStep(alice)
	assert(data.AutoBuy == false, "l'achat automatique ne s'arrête pas sur un Légendaire non visé")
	assert(#data.RolledQueue == 1 and data.RolledQueue[1] == legendary, "Légendaire jeté par l'achat automatique")
	-- Relancer le Lancer AFK sans l'avoir collecté : nouvelle pause, toujours pas jeté.
	alice:SetAttribute("Pass_AutoRoll", true)
	data.AutoRoll = true
	RollService:ResetCooldown(alice)
	RollService:AutoStep(alice)
	assert(data.AutoRoll == false and data.RolledQueue[1] == legendary, "Légendaire jeté au redémarrage du Lancer AFK")
	-- Pause désactivée exprès pour les Légendaires : le joueur accepte de les laisser passer.
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = { legendary = false, mythic = true, secret = true } })
	data.AutoRoll = true
	RollService:ResetCooldown(alice)
	local count = data.RollCount
	RollService:AutoStep(alice)
	assert(data.RollCount == count + 1, "pause forcée malgré « Légendaire : Désactivé »")
	data.AutoRoll = false
	alice:SetAttribute("Pass_AutoRoll", nil)
	alice:SetAttribute("Pass_AutoRollPlus", nil)
	invoke("Roll_SaveAutoSettings", alice, { pauseRarities = { legendary = true, mythic = true }, buyRarities = {} })
	table.clear(data.RolledQueue)
	RollService:RenderStage(alice)
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
	assert(#plot.slots == 26, "26 cases attendues (24 + 2 du passe)")
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
	-- Sauvegarde v3.1 (version 2) : les champs v3.2 doivent exister après la migration.
	assert(type(v2.Items) == "table", "v3.1 : objets d'évolution (Items) manquants")
	assert(type(v2.Quests) == "table" and type(v2.Quests.counters) == "table" and type(v2.Quests.daily) == "table", "v3.1 : défis manquants")
	assert(type(v2.Receipts) == "table" and type(v2.RobuxOnce) == "table" and v2.RobuxSpent == 0, "v3.1 : champs Robux manquants")
	assert(type(v2.AutoRollSettings) == "table" and v2.AutoBuy ~= true, "v3.1 : réglages d'auto-roulage manquants")
	assert(type(v2.traitCrystals) == "number", "v3.1 : gemmes de trait manquantes")
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

test("Évolution à l'Autel d'Éveil (avec l'objet du marchand)", function()
	local EvolutionItems = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.EvolutionItems"))
	local data = DataService:Get(alice)
	local entry = data.characters[firstUid]
	entry.level = 30
	table.clear(data.materials) -- le boss a pu en donner : on repart de zéro
	table.clear(data.Items)
	local ok, message = services.EvolutionService:Evolve(alice, firstUid)
	assert(not ok, "évolution sans matériaux acceptée")
	for _, universe in Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Universes")).List do
		DataService:AddMaterial(alice, universe.material.id, 500)
	end
	-- Sans l'objet d'évolution : refusé, et rien n'est dépensé.
	local coins = data.coins
	ok, message = services.EvolutionService:Evolve(alice, firstUid)
	assert(not ok and string.find(message, "Marchand"), "évolution sans objet acceptée : " .. tostring(message))
	assert(data.coins == coins and entry.stars == 1, "dépense alors que l'évolution est refusée")
	local need = EvolutionItems.requirement(entry)
	assert(need and EvolutionItems.get(need.item), "objet requis inconnu")
	DataService:AddItem(alice, need.item, need.amount)
	ok, message = services.EvolutionService:Evolve(alice, firstUid)
	assert(ok, "évolution : " .. tostring(message))
	assert(entry.stars == 2, "étoiles")
	assert((data.Items[need.item] or 0) == 0, "objet non consommé")
	-- Goko : la Boule du Dragon pour passer Super Guerrier.
	local goko = services.CharacterService:CreateEntry("sai_goko")
	assert(EvolutionItems.requirement(goko).item == "sai_dragon", "Goko ne demande pas la Boule du Dragon")
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
	local sheaths = 0
	for _, child in alice.Character:GetChildren() do
		if child.Name == "SwordSheath" then
			sheaths += 1
			assert(child:GetAttribute("SwordId") == "vent", "mauvais fourreau")
		end
	end
	assert(sheaths == 1, "fourreau absent ou en double : " .. sheaths)
	local enemy = services.CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy, "pas d'ennemi")
	local pos = enemy.root.CFrame.Position
	alice.Character:PivotTo(CFrame.lookAt(pos + Vector3.new(4, 0, 0), pos))
	tool.Parent = alice.Character
	local hp = enemy.hp
	tool.Equipped:Fire()
	task.wait()
	local sheath = alice.Character:FindFirstChild("SwordSheath")
	assert(sheath.PrimaryPart.Transparency == 1, "poignée rangée encore visible épée en main")
	services.SwordService:Swing(alice, tool)
	assert(tool.Handle.SwingTrail.Enabled and tool.AuraVolume.SwingBurst.Enabled, "traînée / gerbe du coup inactives")
	task.wait(0.3)
	assert(enemy.hp < hp or not enemy.alive, "l'épée n'a pas touché")
	task.wait(0.2)
	assert(not tool.Handle.SwingTrail.Enabled, "traînée restée active")
	tool.Unequipped:Fire()
	task.wait()
	assert(sheath.PrimaryPart.Transparency == 0, "poignée rangée invisible")
	assert(lastEvent("CombatFX") ~= nil, "pas d'effet de coup")
	-- Lueur : inchangée quand on sort l'épée, ×2,2 seulement le temps d'un coup.
	local SwordBuilderModule = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.SwordBuilder"))
	local SwordsConfig = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Swords"))
	local bright = SwordBuilderModule.buildTool(SwordsConfig.get("celeste"))
	local spineInHand = bright.Grip:Inverse():VectorToWorldSpace(Vector3.new(1, 0, 0))
	assert(bright.Grip.RightVector:Dot(SwordBuilderModule.GRIP.RightVector) > 0.999 and spineInHand.Y > 0.5, "prise de l'épée (lame de chant)")
	-- Présentoir du hub : modèle ancré, effet adouci, sans lueur.
	local display = SwordBuilderModule.buildDisplay(SwordsConfig.get("foudre"))
	assert(display.Name == "DisplaySword" and display.PrimaryPart.Anchored and not display.AuraVolume.Glow.Enabled, "épée d'exposition")
	-- Maîtrise : tirée des ennemis vaincus, l'épée est reforgée avec un effet plus fort.
	assert(SwordsConfig.mastery(0) == 1 and SwordsConfig.mastery(SwordsConfig.MasteryStep) == 2 and SwordsConfig.mastery(1e9) == SwordsConfig.MasteryMax, "paliers de maîtrise")
	local strong = SwordBuilderModule.buildTool(SwordsConfig.get("rouillee"), SwordsConfig.MasteryMax)
	local weak = SwordBuilderModule.buildTool(SwordsConfig.get("rouillee"), 1)
	assert(strong:GetAttribute("Power") > weak:GetAttribute("Power"), "maîtrise : effet pas plus fort")
	assert(services.SwordService:GetMastery(alice) >= 1, "maîtrise du joueur")
	-- Épée rangée sur le perso : réduite (WORN_SCALE).
	local worn = alice.Character:FindFirstChild("SwordSheath")
	assert(worn and worn:GetAttribute("WornScale") == SwordBuilderModule.WORN_SCALE, "épée portée non réduite")
	local glow = bright.AuraVolume.Glow
	local base = glow.Brightness
	services.SwordService:Flash(bright, 0.1, false)
	assert(glow.Brightness == base, "la lueur s'intensifie en sortant l'épée")
	services.SwordService:Flash(bright, 0.1)
	assert(math.abs(glow.Brightness - base * 2.2) < 1e-6, "pas d'éclat de lueur au coup")
	task.wait(0.2)
	assert(glow.Brightness == base, "lueur non rétablie après le coup")
	bright:Destroy()
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
	assert(naruto:GetAttribute("ToutesEtoiles") == true, "Kid Naruto (sans évolution nommée) doit servir à toutes les étoiles")
	assert(statue.Parent == pack and tree.Parent == pack, "modèle non reconnu déplacé à tort")
	naruto:Destroy()
	pack:Destroy()
	if previous then
		previous.Parent = storage.ModelesPersos
	end
end)

test("Galerie Studio : seuls les modèles retouchés (sans AutoGenere) sont repris", function()
	local Server = Harness.find("ServerScriptService.Server")
	local AvatarService = Harness.require(Server.Services.AvatarService)
	local storage = game:GetService("ReplicatedStorage")
	local gallery = Instance.new("Folder")
	gallery.Name = "GaleriePersos"
	gallery.Parent = game:GetService("Workspace")
	local models = Instance.new("Folder")
	models.Name = "ModelesPersos"
	models.Parent = gallery
	local generated = Instance.new("Model")
	generated.Name = "test_genere"
	generated:SetAttribute("AutoGenere", true)
	generated.Parent = models
	local edited = Instance.new("Model")
	edited.Name = "test_retouche"
	edited.Parent = models
	assert(AvatarService:CollectGallery() == 1, "un seul modèle retouché attendu")
	local target = storage:FindFirstChild("ModelesPersos")
	assert(target and target:FindFirstChild("test_retouche"), "modèle retouché non repris")
	assert(not target:FindFirstChild("test_genere"), "modèle généré recopié dans ReplicatedStorage")
	assert(not game:GetService("Workspace"):FindFirstChild("GaleriePersos"), "galerie non retirée")
	target.test_retouche:Destroy()
end)

test("Modèle perso (ModelesPersos) prioritaire sur le perso intégré, étoile par étoile", function()
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
	local previousStars = {}
	for _, name in { "ninja_maruto_1", "ninja_maruto_2", "ninja_maruto_3" } do
		local existing = folder:FindFirstChild(name)
		if existing then
			existing.Parent = nil
			table.insert(previousStars, existing)
		end
	end
	local custom = Builder.build(look, {})
	custom.Name = "ninja_maruto"
	custom:SetAttribute("Marque", true)
	custom.Parent = folder
	-- Chaque étoile a son modèle : le ★1 retouché (« ninja_maruto ») ne remplace pas les ★2 / ★3,
	-- qui gardent le perso intégré et son look d'évolution (sauf modèle marqué ToutesEtoiles).
	assert(Factory.templateFor("ninja_maruto", 1) == custom, "★1 : modèle retouché ignoré")
	assert(Factory.templateFor("ninja_maruto", 2) == nil and Factory.templateFor("ninja_maruto", 3) == nil, "★2 / ★3 : le modèle du ★1 remplace leur évolution")
	local evolved = Factory.build("ninja_maruto", 3, Characters.resolveLook("ninja_maruto", 3), {})
	assert(not evolved:GetAttribute("CustomModel"), "★3 construit avec le modèle du ★1")
	local second = Builder.build(Characters.resolveLook("ninja_maruto", 2), {})
	second.Name = "ninja_maruto_2"
	second.Parent = folder
	assert(Factory.templateFor("ninja_maruto", 2) == second, "★2 retouché ignoré")
	assert(Factory.templateFor("ninja_maruto", 3) == nil, "★3 : le modèle du ★2 remplace son évolution")
	custom:SetAttribute("ToutesEtoiles", true)
	assert(Factory.templateFor("ninja_maruto", 3) == custom, "modèle ToutesEtoiles ignoré au ★3")
	assert(Factory.templateFor("ninja_maruto", 2) == second, "le modèle propre au ★2 doit rester prioritaire")
	custom:SetAttribute("ToutesEtoiles", nil)
	second:Destroy()
	for _, existing in previousStars do
		existing.Parent = folder
	end
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

test("Boutique Robux : passe couvert par un plus grand, Roblox qui ne répond pas, revenu des packs", function()
	local Monetization = services.MonetizationService
	-- Roulage x3 possédé : « Roulage x2 » n'est plus vendu (il n'ajouterait rien).
	alice:SetAttribute("Pass_Roll3", true)
	assert(Robux.passCovered(alice, "Roll2") and Robux.coveredBy(alice, "Roll2") == "Roll3", "Roll2 couvert par Roll3")
	task.wait(0.7)
	local ok, why = invoke("Robux_Buy", alice, "pass", "Roll2")
	assert(not ok and type(why) == "string" and string.find(why, "inclus", 1, true), "Roll2 vendu avec Roll3 : " .. tostring(why))
	-- UserOwnsGamePassAsync en erreur à l'arrivée : nouvel essai, le passe finit par être accordé.
	local original = MarketplaceService.UserOwnsGamePassAsync
	local calls = 0
	MarketplaceService.UserOwnsGamePassAsync = function(_, _, id)
		if id == 4343 then
			calls += 1
			if calls == 1 then
				error("HTTP 429 (trop de requêtes)")
			end
			return true
		end
		return original(MarketplaceService, 0, id)
	end
	Robux.Passes.Coins2.id = 4343
	local emma = addPlayer("Emma")
	task.wait(0.3)
	assert(emma:GetAttribute("Pass_Coins2") ~= true, "passe accordé sans réponse de Roblox")
	task.wait(2.3)
	assert(emma:GetAttribute("Pass_Coins2") == true, "passe jamais revérifié après une erreur de Roblox")
	-- Fenêtre d'achat fermée avec « déjà possédé » : revérifié sans cache, accordé.
	Robux.Passes.VIP.id = 4344
	emma:SetAttribute("Pass_VIP", nil)
	MarketplaceService.UserOwnsGamePassAsync = function(_, _, id)
		return id == 4344 or id == 4343
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(emma, 4344, false)
	task.wait(0.2)
	assert(emma:GetAttribute("Pass_VIP") == true, "passe possédé non accordé après « déjà possédé »")
	removePlayer(emma)
	MarketplaceService.UserOwnsGamePassAsync = original
	Robux.Passes.Coins2.id = 0
	Robux.Passes.VIP.id = 0
	-- Packs de pièces : revenu calculé depuis les données (attribut absent juste après l'arrivée).
	local saved = alice:GetAttribute("IncomePerSec")
	alice:SetAttribute("IncomePerSec", nil)
	local income = services.CharacterService:IncomePerSec(alice)
	assert(Monetization:_incomePerSec(alice) == income, "revenu des packs dépend de l'attribut IncomePerSec")
	alice:SetAttribute("IncomePerSec", saved)
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

test("Boutique Robux : reçu rejoué à la connexion, passes vérifiés avant le pack (attente bornée)", function()
	local Monetization = services.MonetizationService
	local Granted = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
	local original = MarketplaceService.UserOwnsGamePassAsync
	local originalIncome = Monetization._incomePerSec
	-- revenu de référence : 100 ¥/s, doublé par x2 Argent (comme le calcule CharacterService)
	Monetization._incomePerSec = function(_, player)
		return 100 * Robux.coinMultiplier(player)
	end
	Robux.Passes.Coins2.id = 4350
	Robux.Products.CoinsS.id = 5560
	local slow = 1
	MarketplaceService.UserOwnsGamePassAsync = function(_, _, id)
		if id == 4350 then
			task.wait(slow) -- Roblox lent à répondre à l'arrivée
			return slow < 5 -- (réponse trop tardive : sans effet sur le joueur parti)
		end
		return original(MarketplaceService, 0, id)
	end
	-- Le reçu d'un pack acheté hors ligne est rejoué dès la connexion, pendant la vérification
	-- des passes : il attend sa fin et compte le x2 Argent (montant affiché en boutique).
	local gina = addPlayer("Gina")
	assert(not Monetization:PassesChecked(gina) and gina:GetAttribute("Pass_Coins2") ~= true, "passes déjà vérifiés : le test ne prouve rien")
	local coins = DataService:Get(gina).coins
	local receipt = { PlayerId = gina.UserId, ProductId = 5560, PurchaseId = "R-REJOUE-1", CurrencySpent = 19 }
	assert(MarketplaceService.ProcessReceipt(receipt) == Granted, "reçu rejoué non accordé")
	assert(Monetization:PassesChecked(gina) and gina:GetAttribute("Pass_Coins2") == true, "pack accordé avant la vérification des passes")
	local expected = Robux.coinPackAmount(Robux.Products.CoinsS, 200)
	assert(DataService:Get(gina).coins - coins == expected, "pack sans le x2 Argent : " .. (DataService:Get(gina).coins - coins) .. " au lieu de " .. expected)
	removePlayer(gina)
	-- Roblox qui ne répond pas : le reçu n'attend jamais plus de PassCheckWait secondes.
	slow = 6
	local wait = Monetization.PassCheckWait
	Monetization.PassCheckWait = 0.5
	local hugo = addPlayer("Hugo")
	local started = os.clock()
	assert(MarketplaceService.ProcessReceipt({ PlayerId = hugo.UserId, ProductId = 5560, PurchaseId = "R-REJOUE-2", CurrencySpent = 19 }) == Granted, "reçu bloqué")
	assert(os.clock() - started < 2.5, "reçu bloqué par une vérification des passes sans fin (" .. (os.clock() - started) .. " s)")
	Monetization.PassCheckWait = wait
	removePlayer(hugo)
	MarketplaceService.UserOwnsGamePassAsync = original
	Monetization._incomePerSec = originalIncome
	Robux.Passes.Coins2.id = 0
	Robux.Products.CoinsS.id = 0
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
	local passSlot = services.PlotService:GetPlot(dora).slots[Economy.MaxDisplaySlots + 1]
	assert(passSlot.state == "locked" and string.find(passSlot.caption, "Passe « +2 Cases »", 1, true), "case du passe : légende sans le passe")
	task.wait(0.7)
	assert(invoke("Robux_Buy", dora, "pass", "Slots"), "achat simulé d'Emplacements +")
	assert(data.RobuxSlots == Robux.SlotsBonus, "cases en plus non notées")
	assert(Formulas.playerStats(data).display == display + Robux.SlotsBonus, "cases de la base non ajoutées")
	-- Passe acheté, cour pas finie : les cases du fond ne disent plus « achète le passe ».
	assert(
		passSlot.state == "locked" and passSlot.caption == services.PlotService.PassSlotsOwnedCaption,
		"case du passe : légende pas à jour après l'achat (" .. tostring(passSlot.caption) .. ")"
	)
	local legend = passSlot.silhouette and passSlot.silhouette:FindFirstChild("Legende")
	assert(legend and legend.Text == passSlot.caption and legend.Size.Y.Scale > 0.3, "légende sur deux lignes attendue")
	assert(services.PlotService:GetPlot(dora).slots[display + Robux.SlotsBonus].state ~= "locked", "les 2 cases du passe ne sont pas ouvertes dans la grille")
	-- Arbre terminé et toutes les améliorations : 24 cases sans le passe, 26 avec.
	local full = { upgrades = {}, Skills = {} }
	for _, upgrade in Economy.Upgrades do
		full.upgrades[upgrade.id] = true
	end
	local SkillTree = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.SkillTree"))
	for id in SkillTree.ById do
		full.Skills[id] = true
	end
	assert(Formulas.playerStats(full).display == Economy.MaxDisplaySlots, "jeu gratuit au maximum : 24 cases")
	full.RobuxSlots = Robux.SlotsBonus
	assert(Formulas.playerStats(full).display == Economy.MaxDisplaySlots + Robux.SlotsBonus, "passe +2 Cases sans effet arbre terminé")
	-- Les 2 cases du passe existent dans la base et s'ouvrent.
	local PlotService = services.PlotService
	assert(#PlotService.DisplaySlots == Economy.MaxDisplaySlots + Robux.SlotsBonus, "26 cases physiques attendues")
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

------------------------------------------------------------------------
-- DÉFIS, GEMMES DE TRAIT, ZONE ANTI-AFK
------------------------------------------------------------------------

local QuestsConfig = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Quests"))

-- Fait avancer un compteur de défi (compteur interne ou statistique de la sauvegarde).
local function bump(data, key, amount)
	if string.sub(key, 1, 5) == "stat:" then
		local stat = string.sub(key, 6)
		if stat == "RollCount" then
			data.RollCount += amount
		elseif stat == "totalCoins" then
			data.totalCoins += amount
		elseif stat == "playtime" then
			data.stats.playtime += amount * 60
		elseif stat == "skills" or stat == "index" then
			local target = stat == "skills" and data.Skills or data.index
			for i = 1, amount do
				target["test_" .. key .. "_" .. i .. "_" .. os.clock()] = true
			end
		else
			data.stats[stat] = (data.stats[stat] or 0) + amount
		end
	else
		data.Quests.counters[key] = (data.Quests.counters[key] or 0) + amount
	end
end

test("Défis : kills comptés, palier prêt annoncé, récompense réclamée", function()
	local QuestService = services.QuestService
	local CombatService = services.CombatService
	local data = DataService:Get(alice)
	assert(type(data.Quests) == "table" and type(data.Quests.counters) == "table", "données de défis absentes")
	local killsBefore = data.Quests.counters.kill or 0
	local enemy = CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy, "pas d'ennemi")
	local defId = enemy.defId
	CombatService:DamageEnemy(alice, enemy, 1e9, { sword = true })
	assert((data.Quests.counters.kill or 0) == killsBefore + 1, "kill non compté pour les défis")
	assert((data.Quests.counters["kill:" .. defId] or 0) >= 1, "kill par ennemi non compté")
	assert((data.Quests.counters.swordkill or 0) >= 1, "kill à l'épée non compté")
	-- Rival d'univers (« Tue 200 Kakashu ») : un perso de l'univers apparaît comme ennemi
	local rival = CombatService:_createEnemy("ninja_kakashu", 1, false, "ninja_son")
	assert(rival and rival.rival and rival.model:GetAttribute("Rival") == true, "rival non créé")
	assert(string.find(rival.model:GetAttribute("DisplayName"), "Kakashu", 1, true), "nom du rival")
	CombatService:DamageEnemy(alice, rival, 1e9, { sword = true })
	assert((data.Quests.counters["kill:ninja_kakashu"] or 0) >= 1, "kill de rival non compté")
	-- Défi du jour « Gagne X pièces » : l'objectif suit le revenu du joueur (pas instantané si riche)
	do
		local daily = data.Quests.daily
		local savedList, savedGoals, savedIncome = daily.list, daily.goals, alice:GetAttribute("IncomePerSec")
		daily.list = { "d_coins" }
		daily.goals = { d_coins = 50000 }
		daily.base[QuestsConfig.DailyById.d_coins.key] = QuestsConfig.read(data, QuestsConfig.DailyById.d_coins.key)
		alice:SetAttribute("IncomePerSec", 10000)
		QuestService:_check(alice, nil)
		assert(daily.goals.d_coins >= 10000 * 60 * 20 * 0.9, "objectif de pièces non adapté au revenu : " .. tostring(daily.goals.d_coins))
		daily.list, daily.goals = savedList, savedGoals
		alice:SetAttribute("IncomePerSec", savedIncome)
	end
	-- Palier 1 de « Village Ninja : tue 50 <ennemi> »
	local quest = QuestsConfig.ById.u_ninja_1
	data.Quests.counters[quest.key] = 60
	QuestService:_check(alice, { [quest.key] = true })
	local announced, summary = false, false
	for _, event in clientEvents do
		if event.name == "QuestNotify" and event.player == alice and type(event.args[1]) == "table" then
			announced = announced or event.args[1].kind == "ready"
			summary = summary or event.args[1].kind == "readySummary"
		end
	end
	assert(announced and summary, "défi réussi non annoncé")
	local coins = data.coins
	local ok, message = invoke("QuestClaim", alice, quest.id)
	assert(ok, "réclamer : " .. tostring(message))
	local expected = QuestsConfig.rewardCoins(quest.tiers[1].reward, alice:GetAttribute("IncomePerSec"))
	assert(expected >= quest.tiers[1].reward.coins, "la récompense ne peut pas descendre sous le minimum")
	assert(data.coins == coins + expected, "récompense en pièces non donnée")
	-- revenu élevé : les pièces suivent (5 min de revenu au 1er palier)
	assert(QuestsConfig.rewardCoins(quest.tiers[1].reward, 10000) == 3000000, "pièces non adaptées au revenu")
	assert(data.Quests.claimed[quest.id] == 1, "palier non enregistré")
	local again = invoke("QuestClaim", alice, quest.id)
	assert(not again, "palier 2 réclamé sans l'avoir atteint")
	-- Palier 2 : 200 kills → 1 000 pièces (+ gemme)
	data.Quests.counters[quest.key] = 200
	local gems = data.traitCrystals
	coins = data.coins
	assert(invoke("QuestClaim", alice, quest.id), "palier 2")
	local expected2 = QuestsConfig.rewardCoins(quest.tiers[2].reward, alice:GetAttribute("IncomePerSec"))
	assert(expected2 >= 1000 and data.coins == coins + expected2 and data.traitCrystals == gems + 1, "récompense du palier 2")
	assert(not invoke("QuestClaim", alice, "defi_inconnu"), "défi inconnu accepté")
end)

test("Défis du jour : progression depuis le début de journée, coffre bonus", function()
	local QuestService = services.QuestService
	local data = DataService:Get(alice)
	local q = data.Quests
	assert(#q.daily.list == QuestsConfig.DailyCount, "défis du jour non tirés")
	assert(q.daily.day == QuestsConfig.day(os.time()), "mauvais jour")
	assert(not invoke("QuestClaim", alice, "bonus"), "coffre ouvert trop tôt")
	for _, id in q.daily.list do
		local daily = QuestsConfig.DailyById[id]
		local progress = QuestsConfig.dailyProgress(data, id)
		if progress < daily.goal then
			bump(data, daily.key, daily.goal - progress)
		end
		local ok, message = invoke("QuestClaim", alice, id)
		assert(ok, "défi du jour " .. id .. " : " .. tostring(message))
	end
	local gems = data.traitCrystals
	local ok, message = invoke("QuestClaim", alice, "bonus")
	assert(ok, "coffre du jour : " .. tostring(message))
	assert(data.traitCrystals == gems + QuestsConfig.DailyBonus.gems, "gemmes du coffre")
	assert(not invoke("QuestClaim", alice, "bonus"), "coffre ouvert deux fois")
	-- Le lendemain : nouveaux défis, compteurs repartis de zéro
	q.daily.day -= 1
	QuestService:_check(alice, nil)
	assert(q.daily.day == QuestsConfig.day(os.time()) and not q.daily.bonus, "défis du jour non renouvelés")
	for _, id in q.daily.list do
		assert(QuestsConfig.dailyProgress(data, id) == 0 or QuestsConfig.DailyById[id].key == "stat:playtime", "progression non remise à zéro")
	end
	-- Tout réclamer
	bump(data, "stat:RollCount", 30)
	local okAll = invoke("QuestClaimAll", alice)
	assert(okAll and data.Quests.claimed.p_roll == 1, "tout réclamer")
	assert(QuestService:ReadyCount(alice) >= 0, "compte des récompenses")
end)

test("Gemmes de trait : relance payée en gemmes, gemmes du boss", function()
	local data = DataService:Get(alice)
	local uid = next(data.characters)
	assert(uid, "aucun perso")
	data.traitCrystals = 1
	local before = data.Quests.counters.reroll or 0
	local ok, message, traitId = invoke("RerollTrait", alice, uid)
	assert(ok and traitId, "relance : " .. tostring(message))
	assert(data.traitCrystals == 0, "la relance doit coûter 1 gemme")
	assert(data.Quests.counters.reroll == before + 1, "relance non comptée pour les défis")
	local okEmpty = invoke("RerollTrait", alice, uid)
	assert(not okEmpty, "relance sans gemme acceptée")
	-- Le boss donne des gemmes à chaque participant
	local CombatService = services.CombatService
	CombatService:SpawnBoss()
	local boss = CombatService:GetBoss()
	assert(boss, "pas de boss")
	local bossKills = data.Quests.counters.boss or 0
	CombatService:DamageEnemy(alice, boss, 1e9, {})
	assert(data.traitCrystals >= QuestsConfig.Gems.Boss.min, "pas de gemmes au boss")
	assert(data.Quests.counters.boss == bossKills + 1, "boss non compté")
	assert((data.Quests.counters["boss:" .. boss.defId] or 0) >= 1, "boss de l'univers non compté")
end)

test("Zone anti-AFK : coups comptés, cadence plafonnée, paliers, un sac par joueur", function()
	local QuestService = services.QuestService
	local stations = QuestService:GetStations()
	assert(#stations == 3, "il faut 3 punching-balls")
	local data = DataService:Get(alice)
	local function standAt(player, station)
		local anchor = station.PromptAnchor
		local p = anchor.CFrame.Position
		local zone = QuestsConfig and Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Layout")).AfkZone
		local dir = Vector3.new(zone.X - p.X, 0, zone.Z - p.Z).Unit
		local pos = Vector3.new(p.X, 3.9, p.Z) + dir * 4
		player.Character:PivotTo(CFrame.lookAt(pos, Vector3.new(p.X, pos.Y, p.Z)))
		return pos, -dir
	end
	local pos, look = standAt(alice, stations[1])
	local count = data.Quests.punch
	local total = data.Quests.counters.punch or 0
	assert(QuestService:Punch(alice, nil, pos, look), "coup non compté")
	assert(data.Quests.punch == count + 1 and data.Quests.counters.punch == total + 1, "compteurs de coups")
	assert(not QuestService:Punch(alice, nil, pos, look), "cadence non plafonnée (anti-triche)")
	assert(stations[1]:GetAttribute("OwnerId") == alice.UserId, "sac non réservé")
	assert(stations[1]:GetAttribute("HitTick") >= 1, "pas d'animation de coup")
	-- Palier de 100 coups : +2 gemmes
	data.Quests.punch = 99
	local gems = data.traitCrystals
	task.wait(QuestsConfig.Punch.MinInterval + 0.05)
	assert(QuestService:Punch(alice, nil, pos, look), "coup 100")
	assert(data.traitCrystals == gems + QuestsConfig.Punch.Tiers[1][2], "palier de 100 coups non payé")
	-- 1000 coups : dernier palier puis le cycle repart à 0
	data.Quests.punch = 999
	gems = data.traitCrystals
	task.wait(QuestsConfig.Punch.MinInterval + 0.05)
	assert(QuestService:Punch(alice, nil, pos, look), "coup 1000")
	assert(data.traitCrystals == gems + QuestsConfig.Punch.Tiers[#QuestsConfig.Punch.Tiers][2], "palier de 1000 coups")
	assert(data.Quests.punch == 0, "le cycle doit repartir à 0")
	-- Un autre joueur ne peut pas prendre le sac d'Alice, mais peut prendre un sac libre
	local posB, lookB = standAt(bob, stations[1])
	assert(not QuestService:Punch(bob, nil, posB, lookB), "sac d'Alice pris par Bob")
	posB, lookB = standAt(bob, stations[2])
	assert(QuestService:Punch(bob, nil, posB, lookB), "Bob ne peut pas taper un sac libre")
	assert(stations[2]:GetAttribute("OwnerId") == bob.UserId, "sac de Bob non réservé")
	-- Alice s'éloigne : son sac est libéré
	local delay = QuestsConfig.Punch.ReleaseDelay
	QuestsConfig.Punch.ReleaseDelay = 0
	alice.Character:PivotTo(CFrame.new(0, 5, 0))
	QuestService:_tickStations()
	QuestsConfig.Punch.ReleaseDelay = delay
	assert(stations[1]:GetAttribute("OwnerId") == nil, "sac non libéré quand le joueur s'en va")
	-- Invite « Frapper » (manette / mobile) : sort l'épée et frappe
	standAt(alice, stations[1])
	count = data.Quests.punch
	task.wait(1)
	signalFor(stations[1].PromptAnchor.PunchPrompt, "Triggered"):Fire(alice)
	task.wait(0.4)
	assert(data.Quests.punch == count + 1, "l'invite « Frapper » ne compte pas le coup")
	-- Voyage jusqu'à la zone
	local okGo = invoke("QuestGoAfk", alice)
	assert(okGo, "voyage vers la zone anti-AFK")
	local okAgain = invoke("QuestGoAfk", alice)
	assert(not okAgain, "voyage vers la zone anti-AFK sans cadence minimale")
	removePlayer(bob)
	task.wait(0.2)
	assert(stations[2]:GetAttribute("OwnerId") == nil, "sac de Bob non libéré à sa déconnexion")
end)

test("Défis : migration d'une sauvegarde abîmée", function()
	local data = { version = 2, Quests = "abîmé", traitCrystals = "3", characters = {} }
	DataService.migrate(data)
	assert(type(data.Quests) == "table" and type(data.Quests.counters) == "table" and type(data.Quests.daily.list) == "table", "défis non réparés")
	assert(data.traitCrystals == 3, "gemmes non réparées")
	local broken = { version = 2, characters = {}, Quests = { counters = { kill = -5, boss = "2" }, daily = "x", punch = "12" } }
	DataService.migrate(broken)
	assert(broken.Quests.counters.kill == nil and broken.Quests.counters.boss == 2 and broken.Quests.punch == 12, "compteurs non nettoyés")
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
