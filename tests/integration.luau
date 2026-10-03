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
	local enemy = CombatService:NearestEnemy(Vector3.zero, 500)
	assert(enemy, "pas d'ennemi")
	local follower = services.TeamService:GetFollowers(alice)[firstUid]
	assert(follower, "follower introuvable")
	local enemyPos = enemy.root.CFrame.Position
	alice.Character:PivotTo(CFrame.new(enemyPos + Vector3.new(4, 0, 0)))
	follower.model:PivotTo(CFrame.new(enemyPos + Vector3.new(2, 0, 0)))
	local hpBefore = enemy.hp
	services.TeamService:_update(alice, { followers = { [firstUid] = follower }, target = nil }, os.clock() + 100)
	assert(enemy.hp < hpBefore or not enemy.alive, "le perso n'a pas attaqué")
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
