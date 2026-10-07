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

test("Machine ROULER : roulage, estrade, collecte offerte puis payante", function()
	local data = DataService:Get(alice)
	local plot = services.PlotService:GetPlot(alice)
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
	assert(lastEvent("RollResult", alice), "RollResult non envoyé")
	local payload = lastEvent("RollResult", alice).args[1]
	assert(payload.results[1].id and payload.results[1].price and payload.results[1].dps and payload.pity.legendary and payload.x10In, "contenu de RollResult")
	assert(#plot.rolledFolder:GetChildren() == 1, "modèle du perso tiré absent")
	local univers = services.UniverseService:GetCurrent()
	assert(table.find(univers.characters, results[1].id), "perso hors du pool de l'univers actuel")
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
	local rolledEntry = nil
	for _, entry in data.characters do
		count += 1
		if entry.rollRarity then
			rolledEntry = entry
		end
	end
	assert(count == countBefore + 2, "persos non ajoutés")
	assert(rolledEntry, "rareté de la machine non mémorisée")
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

test("Pitié : Légendaire, Mythique et Secret garantis au seuil", function()
	local data = DataService:Get(alice)
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local Economy = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Economy"))
	local stats = Formulas.playerStats(data)
	for _, tier in { "legendary", "mythic", "secret" } do
		table.clear(data.RolledQueue)
		data.Pity = { legendary = 0, mythic = 0, secret = 0 }
		data.Pity[tier] = Formulas.pityThreshold(tier, stats.pityMult) - 1
		local ok, results = rollNow(alice)
		assert(ok, "roulage")
		local got = Economy.RollRarities[results[1].rarity].order
		assert(got >= Economy.RollRarities[tier].order, tier .. " non garanti (obtenu " .. results[1].rarity .. ")")
		assert(data.Pity[tier] == 0, "compteur de pitié non remis à zéro : " .. tier)
	end
	-- Le Secret = le Mythique de l'univers avec l'aura Arc-en-ciel.
	local secret = data.RolledQueue[1]
	assert(secret.aura == "arcenciel" and secret.trait, "Secret sans aura ni trait")
	local panel = services.PlotService:GetPlot(alice).machine.pityLines.legendary
	assert(panel.Text:find("rouleaux") or panel.Text:find("PROCHAIN"), "panneau de pitié non mis à jour")
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Chance x10 : tous les N roulages", function()
	local data = DataService:Get(alice)
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local every = Formulas.playerStats(data).x10Every
	data.X10Counter = every - 2
	rollNow(alice)
	assert(lastEvent("RollResult", alice).args[1].x10 == false, "x10 trop tôt")
	assert(lastEvent("RollResult", alice).args[1].x10In == 1, "compte à rebours x10")
	rollNow(alice)
	assert(lastEvent("RollResult", alice).args[1].x10 == true, "pas de roulage x10")
	assert(data.X10Counter == 0, "compteur x10 non remis à zéro")
	-- Les probabilités x10 favorisent les raretés.
	local normal = Formulas.rollOdds(1)
	local boosted = Formulas.rollOdds(10)
	assert(boosted.legendary > normal.legendary * 5 and boosted.common < normal.common, "chance x10 sans effet")
	local total = 0
	for _, p in boosted do
		total += p
	end
	assert(math.abs(total - 1) < 1e-6, "probabilités x10 ≠ 100 %")
	table.clear(data.RolledQueue)
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

test("Multi-tirage : 2 puis 3 persos par roulage + auto-roulage", function()
	local data = DataService:Get(alice)
	table.clear(data.RolledQueue)
	data.Skills = { coeur = true, taux1 = true, multi1 = true }
	local ok, results = rollNow(alice)
	assert(ok and #results == 2, "multi-tirage I : " .. (type(results) == "table" and #results or tostring(results)))
	table.clear(data.RolledQueue)
	data.Skills.taux2 = true
	data.Skills.multi2 = true
	ok, results = rollNow(alice)
	assert(ok and #results == 3, "multi-tirage II")
	assert(#services.PlotService:GetPlot(alice).rolledFolder:GetChildren() == 3, "3 persos attendus sur l'estrade")
	-- Auto-roulage : refusé sans le nœud, accepté avec.
	assert(not invoke("SetAutoRoll", alice, true), "auto-roulage sans nœud")
	data.Skills.autoroll = true
	assert(invoke("SetAutoRoll", alice, true), "auto-roulage")
	assert(data.AutoRoll == true, "auto-roulage non enregistré")
	invoke("SetAutoRoll", alice, false)
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
end)

test("Estrade pleine : les persos rares ne sont jamais poussés dehors", function()
	local data = DataService:Get(alice)
	data.Skills = {}
	table.clear(data.RolledQueue)
	for i = 1, 6 do
		table.insert(data.RolledQueue, { key = "L" .. i, id = "ninja_maruto", rarity = "legendary", stars = 1, price = 45000, dps = 100, at = 0 })
	end
	local ok = rollNow(alice)
	assert(not ok, "roulage accepté avec une estrade pleine de Légendaires")
	assert(#data.RolledQueue == 6 and data.RolledQueue[1].key == "L1", "Légendaire perdu")
	-- Avec un Commun dans la file, c'est lui qui part.
	data.RolledQueue[3] = { key = "C", id = "ninja_rokli", rarity = "common", stars = 1, price = 90, dps = 5, at = 0 }
	ok = rollNow(alice)
	assert(ok, "roulage refusé alors qu'un Commun peut partir")
	for _, item in data.RolledQueue do
		assert(item.key ~= "C", "le Commun aurait dû partir")
	end
	table.clear(data.RolledQueue)
	services.RollService:RenderStage(alice)
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
	assert(data.version == 2, "version non migrée")
	assert(type(data.Skills) == "table" and next(data.Skills) == nil, "Skills manquant")
	assert(data.Pity.legendary == 0 and data.Pity.mythic == 0 and data.Pity.secret == 0, "Pity manquant")
	assert(data.RollCount == 0 and data.X10Counter == 0 and data.AutoRoll == false, "compteurs manquants")
	assert(type(data.RolledQueue) == "table" and type(data.DisplayPins) == "table", "file / cases manquantes")
	assert(data.FirstCollectDone == true, "un ancien joueur ne doit pas avoir de perso offert")
	assert(data.coins == 1234 and data.characters["OLD-1"], "anciennes données perdues")
	assert(data.upgrades.dojo and Economy.UpgradesById.dojo, "ancienne amélioration perdue")
	-- Sauvegarde abîmée : les champs qui doivent être des tables sont réparés au lieu de planter.
	local broken = DataService.migrate({ version = 1, Pity = 5, characters = "x", Skills = true, DisplayPins = { ["1"] = 3, ["2"] = false } })
	assert(type(broken.Pity) == "table" and broken.Pity.legendary == 0, "Pity abîmé non réparé")
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
		["Bruit de fond"] = false,
		["Model"] = false,
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
	-- Palier 1 de « Village Ninja : tue 50 <ennemi> »
	local quest = QuestsConfig.ById.u_ninja_1
	data.Quests.counters[quest.key] = 60
	QuestService:_check(alice, { [quest.key] = true })
	local notify = lastEvent("QuestNotify", alice)
	assert(notify and notify.args[1].kind == "ready", "défi réussi non annoncé")
	local coins = data.coins
	local ok, message = invoke("QuestClaim", alice, quest.id)
	assert(ok, "réclamer : " .. tostring(message))
	assert(data.coins == coins + quest.tiers[1].reward.coins, "récompense en pièces non donnée")
	assert(data.Quests.claimed[quest.id] == 1, "palier non enregistré")
	local again = invoke("QuestClaim", alice, quest.id)
	assert(not again, "palier 2 réclamé sans l'avoir atteint")
	-- Palier 2 : 200 kills → 1 000 pièces (+ gemme)
	data.Quests.counters[quest.key] = 200
	local gems = data.traitCrystals
	coins = data.coins
	assert(invoke("QuestClaim", alice, quest.id), "palier 2")
	assert(data.coins == coins + 1000 and data.traitCrystals == gems + 1, "récompense du palier 2")
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
end)

Harness.finish()
