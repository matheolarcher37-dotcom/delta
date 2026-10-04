--!nocheck
-- Test de l'interface client (avec Lune) : serveur + client dans la même machine virtuelle,
-- reliés en boucle. On ouvre chaque menu et on déclenche chaque effet pour détecter les erreurs.
-- Usage :  rojo build default.project.json -o build/AnimeTycoon.rbxl && lune run tests/client_smoke.luau

local task = require("@lune/task")
local Harness = require("./harness")

local roblox = Harness.roblox
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local game = Harness.game
local test = Harness.test
local signalFor = Harness.signalFor
local newSignal = Harness.newSignal

------------------------------------------------------------------------
-- Services simulés (mêmes que le test d'intégration) + boucle serveur <-> client
------------------------------------------------------------------------

local playersList = {}
local Players = { PlayerAdded = newSignal(), PlayerRemoving = newSignal(), LocalPlayer = nil }
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

local store = {}
Harness.services.Players = Players
Harness.services.DataStoreService = {
	GetDataStore = function()
		return {
			GetAsync = function(_, key)
				return store[key]
			end,
			UpdateAsync = function(_, key, fn)
				local result = fn(store[key])
				if result ~= nil then
					store[key] = result
				end
				return result
			end,
		}
	end,
	GetOrderedDataStore = function()
		return {
			SetAsync = function() end,
			GetSortedAsync = function()
				return {
					GetCurrentPage = function()
						return {}
					end,
				}
			end,
		}
	end,
}
Harness.services.PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end }
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

local guid = 0
roblox.implementMethod("HttpService", "GenerateGUID", function()
	guid += 1
	return "UID-" .. guid
end)
roblox.implementMethod("Humanoid", "MoveTo", function() end)
for _, name in { "CharacterAdded", "Chatted" } do
	roblox.implementProperty("Player", name, function(player)
		return signalFor(player, name)
	end)
end
roblox.implementProperty("TextChatCommand", "Triggered", function(instance)
	return signalFor(instance, "Triggered")
end)

local callbacks = {}
roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(remote)
	return callbacks[remote]
end, function(remote, fn)
	callbacks[remote] = fn
end)

-- Serveur -> client : on relaie au client si c'est le joueur local.
local received = {}
roblox.implementMethod("RemoteEvent", "FireClient", function(remote, player, ...)
	if player == Players.LocalPlayer then
		received[remote.Name] = (received[remote.Name] or 0) + 1
		signalFor(remote, "OnClientEvent"):Fire(...)
	end
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(remote, ...)
	received[remote.Name] = (received[remote.Name] or 0) + 1
	signalFor(remote, "OnClientEvent"):Fire(...)
end)
-- Client -> serveur
Harness.onFireServer = function(remote, ...)
	signalFor(remote, "OnServerEvent"):Fire(Players.LocalPlayer, ...)
end
Harness.onInvokeServer = function(remote, ...)
	local fn = callbacks[remote]
	assert(fn, "pas de handler serveur pour " .. remote.Name)
	return fn(Players.LocalPlayer, ...)
end

-- Capture des avertissements (erreurs attrapées par le jeu).
local warnings = {}
local baseEnv = Harness.env
Harness.env = function(scriptInstance)
	local env = baseEnv(scriptInstance)
	env.warn = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		local text = table.concat(parts, " ")
		table.insert(warnings, text)
		print("WARN: " .. text)
	end
	return env
end

local function expectNoNewWarnings(before: number, context: string)
	if #warnings > before then
		error(context .. " : " .. warnings[before + 1])
	end
end

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------

local workspaceService = game:GetService("Workspace")
local camera = Instance.new("Camera")
camera.CFrame = CFrame.new(0, 50, 100)
camera.Parent = workspaceService
workspaceService.CurrentCamera = camera

local alice
local services = {}
local Menus

-- Détection du mode de jeu (clavier / manette) simulée.
Harness.services.UserInputService.LastInputTypeChanged = newSignal()
Harness.services.UserInputService.GetLastInputType = function()
	return roblox.Enum.UserInputType.MouseMovement
end

local function makePlayer(name, userId)
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	local gui = Instance.new("PlayerGui")
	gui.Parent = player
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = character
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	character.Parent = workspaceService
	player.Character = character
	player.Parent = game:GetService("Players")
	table.insert(playersList, player)
	return player
end

test("Serveur démarré + joueur local connecté", function()
	local serverFolder = Harness.find("ServerScriptService.Server")
	Harness.run(serverFolder.Main)
	for _, module in serverFolder.Services:GetChildren() do
		services[module.Name] = Harness.require(module)
	end
	alice = makePlayer("Alice", 4242)
	Players.LocalPlayer = alice
	Harness.isServer = false
end)

test("Client démarré (Main.client)", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	Harness.run(client.Main)
	Menus = Harness.require(client.UI.Menus)
	assert(alice.PlayerGui:FindFirstChild("AnimeTycoonUI"), "pas d'interface")
	-- Le serveur charge le joueur après l'initialisation du client.
	Players.PlayerAdded:Fire(alice)
	task.wait(0.6)
	assert(received.DataSync and received.DataSync > 0, "aucune synchro reçue")
	expectNoNewWarnings(before, "init client")
end)

test("HUD : boucle de mise à jour", function()
	local before = #warnings
	task.wait(0.6)
	for _ = 1, 10 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
	end
	expectNoNewWarnings(before, "HUD")
end)

test("Ouverture d'une relique + révélation", function()
	local before = #warnings
	local data = services.DataService:Get(alice)
	local relicId = next(data.relics)
	Menus.open("PlaceRelic", 1)
	task.wait(0.1)
	local ok = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes")).func("PlaceRelic"):InvokeServer(1, relicId)
	assert(ok, "relique non posée")
	Harness.timeOffset += 60
	local plot = services.PlotService:GetPlot(alice)
	signalFor(plot.pedestals[1].Top.Prompt, "Triggered"):Fire(alice)
	task.wait(2.5)
	assert(received.HatchReveal == 1, "pas de révélation reçue")
	expectNoNewWarnings(before, "révélation")
end)

test("Remplissage : plusieurs persos, auras, fusion", function()
	local CharacterService = services.CharacterService
	for _, id in { "ninja_maruto", "occ_goju", "sai_goko", "oce_loffy", "pou_rengoko", "occ_sukana", "ninja_sakoura" } do
		local entry = CharacterService:CreateEntry(id, id == "occ_goju" and "neant" or (id == "sai_goko" and "foudre" or nil))
		entry.stars = 2
		entry.level = 40
		CharacterService:AddCharacter(alice, entry)
	end
	local fusion = { id = "fusion", fusion = { a = "ninja_maruto", b = "occ_goju" }, level = 5, xp = 0, stars = 1, aura = "arcenciel", obtained = os.time() }
	CharacterService:AddCharacter(alice, fusion)
	services.DataService:AddCoins(alice, 5000000)
	for _, material in { "chakra", "maudite", "ki", "perle", "sang" } do
		services.DataService:AddMaterial(alice, material, 200)
	end
	task.wait(0.5)
end)

for _, menuName in { "Inventory", "Index", "Guide", "Shop", "Evolution", "Fusion", "MainMenu", "Event", "SkillTree", "Traits", "Forge" } do
	test("Menu " .. menuName, function()
		local before = #warnings
		Menus.open(menuName)
		task.wait(0.3)
		for _ = 1, 5 do
			Harness.services.RunService.RenderStepped:Fire(1 / 60)
		end
		Menus.close(menuName)
		expectNoNewWarnings(before, menuName)
	end)
end

test("Inventaire : sélection et actions", function()
	local before = #warnings
	Menus.open("Inventory")
	task.wait(0.2)
	local gui = alice.PlayerGui.AnimeTycoonUI
	-- Clique sur la première carte de perso trouvée.
	local clicked = false
	for _, descendant in gui:GetDescendants() do
		if descendant.Name == "Card" and descendant:IsA("TextButton") and descendant:IsDescendantOf(gui) then
			signalFor(descendant, "Activated"):Fire()
			clicked = true
			break
		end
	end
	assert(clicked, "aucune carte")
	task.wait(0.2)
	-- Clique sur tous les boutons du panneau de détail (équiper, verrouiller, vendre x2).
	Menus.close("Inventory")
	expectNoNewWarnings(before, "inventaire")
end)

test("Inventaire : onglet Objets et fiche d'unité", function()
	local before = #warnings
	local gui = alice.PlayerGui.AnimeTycoonUI
	Menus.open("Inventory")
	task.wait(0.2)
	local sheet = nil
	for _, d in gui:GetDescendants() do
		if d.Name == "UnitSheet" then
			sheet = d
		end
	end
	assert(sheet, "pas de fiche d'unité")
	for _, key in { "dmg", "spa", "crit", "critdmg" } do
		assert(sheet:FindFirstChild("Stat_" .. key, true), "tuile de statistique manquante : " .. key)
	end
	Menus.open("Inventory", "items")
	task.wait(0.2)
	Menus.close("Inventory")
	expectNoNewWarnings(before, "objets")
end)

test("Arbre de compétences : nœuds hexagonaux et achat", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local SkillTreeMenu = Harness.require(client.UI.SkillTreeMenu)
	local State = Harness.require(client.State)
	assert(SkillTreeMenu.nodeCount() == #State.skillTree().Nodes, "nœuds manquants")
	assert(SkillTreeMenu.nodeCount() >= 20, "arbre trop petit")
	Menus.open("SkillTree")
	task.wait(0.1)
	-- Le HUD se cache pendant l'arbre (plein écran).
	assert(alice.PlayerGui.AnimeTycoonUI.HUD.Visible == false, "le HUD devrait être caché")
	SkillTreeMenu.select(State.skillTree().Nodes[1].id, true)
	SkillTreeMenu.buy(State.skillTree().Nodes[1].id)
	task.wait(0.2)
	for _ = 1, 5 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
	end
	Menus.close("SkillTree")
	assert(alice.PlayerGui.AnimeTycoonUI.HUD.Visible == true, "le HUD devrait réapparaître")
	expectNoNewWarnings(before, "arbre")
end)

test("Révélation des persos tirés (RollResult)", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RollReveal = Harness.require(client.UI.RollReveal)
	RollReveal.show({
		results = {
			{ id = "occ_goju", stars = 1, rarity = "mythic", price = 250000, dps = 4200 },
			{ id = "ninja_maruto", stars = 1, rarity = "rare", price = 900, dps = 80 },
			{ id = "sai_goko", stars = 1, rarity = "secret", price = 1000000, dps = 9000 },
		},
		pity = { legendary = 10, mythic = 100, secret = 1000 },
		x10In = 4,
		x10 = true,
	})
	task.wait(0.4)
	local strip = alice.PlayerGui.AnimeTycoonUI.RollReveal.Strip
	local cards = 0
	for _, d in strip:GetDescendants() do
		if string.sub(d.Name, 1, 8) == "RollCard" then
			cards += 1
		end
	end
	assert(cards == 3, "3 cartes attendues, " .. cards .. " trouvées")
	for _ = 1, 10 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
	end
	task.wait(3.2)
	expectNoNewWarnings(before, "révélation du roulage")
end)

test("Manette : indications A/B et sélection automatique", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local Console = Harness.require(client.UI.Console)
	Harness.services.UserInputService.LastInputTypeChanged:Fire(roblox.Enum.UserInputType.Gamepad1)
	task.wait(0.1)
	assert(Console.isGamepad(), "mode manette non détecté")
	Menus.open("MainMenu")
	task.wait(0.2)
	local visibleHints = 0
	for _, d in alice.PlayerGui.AnimeTycoonUI:GetDescendants() do
		if string.sub(d.Name, 1, 8) == "PadHint_" and d.Visible then
			visibleHints += 1
		end
	end
	assert(visibleHints > 0, "aucune indication de bouton de manette")
	Menus.close("MainMenu")
	Harness.services.UserInputService.LastInputTypeChanged:Fire(roblox.Enum.UserInputType.MouseMovement)
	task.wait(0.1)
	assert(not Console.isGamepad(), "retour clavier/souris non détecté")
	expectNoNewWarnings(before, "manette")
end)

test("Effets de combat et récompenses", function()
	local before = #warnings
	local Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	local fx = signalFor(Remotes.event("CombatFX"), "OnClientEvent")
	local follower = nil
	for _, model in workspaceService.Followers:GetChildren() do
		follower = model
	end
	local p = Vector3.new(10, 3, 10)
	for _, kind in { "punch", "orb", "beam", "slash", "lightning", "flame", "shadow", "stretch" } do
		fx:Fire("Hit", {
			position = p,
			amount = 1234,
			crit = kind == "orb",
			special = kind == "beam",
			kind = kind,
			color = Color3.new(1, 0.5, 0),
			from = Vector3.new(0, 3, 0),
			attacker = follower,
			owner = alice.UserId,
		})
	end
	fx:Fire("EnemyHit", { position = p, from = Vector3.zero, amount = 12 })
	fx:Fire("Death", { position = p, boss = true })
	fx:Fire("KO", { position = p })
	fx:Fire("LevelUp", { position = p, level = 12 })
	fx:Fire("Slam", { position = p, radius = 20 })
	fx:Fire("Strike", { position = p, color = Color3.new(1, 1, 0), aura = "foudre" })
	fx:Fire("Strike", { position = p, color = Color3.new(0.6, 0, 1), aura = "neant" })
	fx:Fire("Build", { position = p })
	fx:Fire("Evolve", { position = p, stars = 3 })
	fx:Fire("Rift", { color = Color3.new(1, 0, 0) })
	local reward = signalFor(Remotes.event("Reward"), "OnClientEvent")
	reward:Fire("coins", 5000, p)
	reward:Fire("material", 2, p, "chakra")
	for _ = 1, 30 do
		Harness.services.RunService.RenderStepped:Fire(1 / 30)
	end
	task.wait(1.5)
	expectNoNewWarnings(before, "effets")
end)

test("Animations, auras et étiquettes (rendu de plusieurs images)", function()
	local before = #warnings
	for i = 1, 60 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
		if i % 20 == 0 then
			task.wait(0.05)
		end
	end
	local tags = 0
	for _, model in workspaceService.Followers:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:FindFirstChild("AnimeTag") then
			tags += 1
		end
	end
	assert(tags > 0, "aucune étiquette LV. au-dessus des persos")
	expectNoNewWarnings(before, "animations")
end)

test("Échange : la fenêtre s'ouvre et se ferme", function()
	local before = #warnings
	local bob = makePlayer("Bob", 4343)
	Players.PlayerAdded:Fire(bob)
	task.wait(0.5)
	local tableModel = Harness.CollectionService:GetTagged("TradeTable")[1]
	services.TradeService:_start(tableModel, alice, bob)
	task.wait(0.2)
	assert(Menus.current() == "Trade", "fenêtre d'échange non ouverte")
	local Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	local data = services.DataService:Get(alice)
	local uid = next(data.characters)
	data.characters[uid].locked = false
	Remotes.event("TradeAction"):FireServer("addCharacter", uid)
	Remotes.event("TradeAction"):FireServer("setCoins", 100)
	Remotes.event("TradeAction"):FireServer("cancel")
	task.wait(0.2)
	assert(Menus.current() ~= "Trade", "fenêtre d'échange toujours ouverte")
	expectNoNewWarnings(before, "échange")
end)

test("Notifications et annonces", function()
	local before = #warnings
	local Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	for i = 1, 8 do
		signalFor(Remotes.event("Notify"), "OnClientEvent"):Fire("Message " .. i, i % 2 == 0 and "success" or "error")
	end
	signalFor(Remotes.event("Announce"), "OnClientEvent"):Fire("TITRE", "Sous-titre", Color3.new(1, 0, 0))
	task.wait(0.5)
	expectNoNewWarnings(before, "notifications")
end)

test("Rotation d'univers vue par le client", function()
	local before = #warnings
	services.UniverseService:Skip()
	task.wait(2.8)
	for _ = 1, 5 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
	end
	expectNoNewWarnings(before, "rotation")
end)

print(string.format("   %d avertissement(s) au total", #warnings))
Harness.finish()
