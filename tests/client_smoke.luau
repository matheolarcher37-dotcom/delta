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
local Vector2 = roblox.Vector2
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
local realIndexAt -- UniverseService.IndexAt d'origine (l'univers est figé pendant les menus)
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
	-- Univers figé pendant les tests de menus : un changement d'univers en plein test (passage
	-- d'une demi-heure pile) lance la faille et ses effets, sans rapport avec le menu testé.
	-- Rétabli avant le test « Rotation d'univers ».
	local universeService = services.UniverseService
	local frozen = universeService:IndexAt(universeService:Now())
	realIndexAt = universeService.IndexAt
	universeService.IndexAt = function()
		return frozen
	end
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

for _, menuName in { "Inventory", "Index", "Guide", "Shop", "Evolution", "Fusion", "MainMenu", "Event", "SkillTree", "Traits", "Forge", "PlaceUnit", "Options", "Quests" } do
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

test("Marchand : écran, achat sur place, objet requis à l'Évolution, onglet Objets", function()
	local before = #warnings
	local gui = alice.PlayerGui.AnimeTycoonUI
	local EvolutionItems = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.EvolutionItems"))
	local data = services.DataService:Get(alice)
	local function find(name, root)
		for _, d in (root or gui):GetDescendants() do
			if d.Name == name then
				return d
			end
		end
		return nil
	end
	local function count(name, root)
		local n = 0
		for _, d in (root or gui):GetDescendants() do
			if d.Name == name then
				n += 1
			end
		end
		return n
	end
	-- Devant le comptoir du marchand.
	local merchant = game:GetService("Workspace").World.Merchant
	local counter = merchant.Etal.Counter
	alice.Character:PivotTo(counter.CFrame * CFrame.new(0, 1, -5))
	Menus.open("Shop")
	task.wait(0.4)
	local shopWindow = find("WindowRoot_MARCHAND")
	assert(shopWindow and shopWindow.Visible, "écran du marchand fermé")
	assert(count("ItemCard", shopWindow) == EvolutionItems.Merchant.Slots, "objets du marchand manquants")
	local buyButton = find("BuyButton", shopWindow)
	assert(buyButton, "pas de bouton d'achat")
	-- Étiquettes UTILE / SIGNATURE en bas de la vignette (jamais sur la pastille × N en haut).
	for _, d in shopWindow:GetDescendants() do
		if d.Name == "Tags" and d.Parent and d.Parent.Name == "Face" then
			assert(d.AnchorPoint.Y == 1 and d.Position.Y.Scale > 0.5, "étiquettes du marchand en haut de la vignette")
		end
	end
	-- Majuscules accentuées : « LÉGENDAIRE », jamais « LéGENDAIRE ».
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and d:IsDescendantOf(shopWindow) then
			assert(not string.find(d.Text, "LéG") and not string.find(d.Text, "PLANèTE"), "majuscule accentuée cassée : " .. d.Text)
		end
	end
	local Shop = Harness.require(Harness.find("StarterPlayer.StarterPlayerScripts.Client.UI.Shop"))
	local firstId = Shop._state().items[1].id
	local owned = data.Items[firstId] or 0
	signalFor(buyButton, "Activated"):Fire()
	task.wait(0.4)
	assert((data.Items[firstId] or 0) == owned + 1, "achat depuis l'écran non effectué")
	Menus.close("Shop")
	-- De loin : « Montrer le chemin » pose une flèche devant le joueur et des lumières au sol.
	alice.Character:PivotTo(counter.CFrame * CFrame.new(0, 1, -160))
	Menus.open("Shop")
	task.wait(0.4)
	signalFor(find("BuyButton", find("WindowRoot_MARCHAND")), "Activated"):Fire()
	task.wait(0.2)
	local guideFolder = game:GetService("Workspace"):FindFirstChild("MerchantGuide")
	assert(guideFolder and guideFolder:FindFirstChild("GuideArrow"), "pas de flèche vers le marchand")
	local wisps = 0
	for _, d in guideFolder:GetChildren() do
		if d.Name == "Wisp" and d.Transparency < 1 then
			wisps += 1
		end
	end
	assert(wisps >= 3, "chemin de lumières absent")
	alice.Character:PivotTo(counter.CFrame * CFrame.new(0, 1, -5))
	task.wait(1.3)
	assert(not game:GetService("Workspace"):FindFirstChild("MerchantGuide"), "le guidage ne s'efface pas à l'arrivée")
	-- Évolution de Goko : la Boule du Dragon est demandée, avec un lien vers le marchand.
	local goko = services.CharacterService:CreateEntry("sai_goko")
	goko.level = 30
	local uid = services.CharacterService:AddCharacter(alice, goko)
	data.Items.sai_dragon = nil
	services.DataService:Sync(alice)
	task.wait(0.3)
	Menus.open("Evolution", uid)
	task.wait(0.4)
	local box = find("RequiredItem")
	assert(box, "objet requis non affiché")
	local found = false
	for _, d in box:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "Boule du Dragon") then
			found = true
		end
	end
	assert(found, "la Boule du Dragon n'est pas demandée pour Goko")
	-- Sa carte n'affiche pas « PRÊT ! » mais « OBJET MANQUANT » (avec la Boule du Dragon).
	local evoWindow = find("WindowRoot_ÉVOLUTION")
	local gokoCard = nil
	for _, d in evoWindow:GetDescendants() do
		if d:GetAttribute("SelKey") == uid then
			gokoCard = d
		end
	end
	assert(gokoCard, "carte de Goko absente")
	assert(gokoCard:FindFirstChild("MissingItem") and not gokoCard:FindFirstChild("Ready"), "Goko marqué PRÊT sans la Boule du Dragon")
	-- Le ruban est en bas du portrait (le visage reste visible).
	local ribbon = gokoCard.MissingItem
	assert(ribbon.AnchorPoint.Y == 1 and ribbon.Position.Y.Scale >= 0.7, "ruban posé sur le visage")
	local icon = find("ItemIcon", gokoCard)
	assert(icon and icon:GetAttribute("ItemId") == "sai_dragon", "mini-icône de l'objet manquant")
	-- L'aperçu « après » montre Goko ★★ en Super Guerrier (cheveux dorés).
	local after = find("After", evoWindow)
	assert(after and after:GetAttribute("Stars") == 2, "aperçu ★★ absent")
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	local gold = Characters.resolveLook("sai_goko", 2).hairColor
	local golden = false
	for _, d in after:GetDescendants() do
		if d:IsA("BasePart") then
			local c = d.Color
			if math.abs(c.R - gold.R) + math.abs(c.G - gold.G) + math.abs(c.B - gold.B) < 0.06 then
				golden = true
			end
		end
	end
	assert(golden, "l'aperçu ★★ de Goko n'a pas les cheveux de Super Guerrier")
	local merchantButton = find("MerchantButton", box)
	assert(merchantButton, "pas de lien vers le marchand")
	signalFor(merchantButton, "Activated"):Fire()
	task.wait(0.3)
	assert(find("WindowRoot_MARCHAND").Visible, "le lien n'ouvre pas le marchand")
	Menus.close("Shop")
	-- Inventaire › Objets : l'objet acheté apparaît, avec sa fiche.
	Menus.open("Inventory", "items")
	task.wait(0.3)
	local card = nil
	for _, d in gui:GetDescendants() do
		if d.Name == "ItemCard" and d:GetAttribute("SelKey") == "evo_" .. firstId then
			card = d
		end
	end
	assert(card, "objet d'évolution absent de l'inventaire")
	-- Grille des objets en 4 colonnes plus larges, noms lisibles (12 px minimum).
	local invWindow = find("WindowRoot_UNITÉS")
	assert(find("Left", invWindow).Size.X.Scale > 0.5, "grille des objets trop étroite")
	local title = card.Face.Strip.Title
	local constraint = title:FindFirstChildOfClass("UITextSizeConstraint")
	assert(constraint and constraint.MinTextSize >= 12, "nom d'objet sans taille minimale")
	signalFor(card, "Activated"):Fire()
	task.wait(0.3)
	assert(find("MerchantButton", invWindow), "fiche de l'objet absente")
	-- Bas de la fiche : les persos concernés en 3D.
	local usedBy = find("UsedBy", invWindow)
	assert(usedBy and #usedBy:GetChildren() >= 2, "persos concernés non affichés")
	Menus.close("Inventory")
	-- HUD : la pastille du marchand.
	task.wait(0.4)
	local chip = find("Shop", find("Chips"))
	assert(chip and chip.Visible, "pastille du marchand absente")
	local label = nil
	for _, d in chip:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "Marchand") then
			label = d
		end
	end
	assert(label, "la pastille n'affiche pas « Marchand : mm:ss »")
	expectNoNewWarnings(before, "marchand")
end)

test("Défis : les 5 onglets, réclamer, suivi à l'écran", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local QuestsUI = Harness.require(client.UI.Quests)
	local data = services.DataService:Get(alice)
	-- Un défi prêt à réclamer pour avoir un bouton vert
	data.Quests.counters["kill:ninja_son"] = 60
	services.DataService:Sync(alice)
	task.wait(0.4)
	Menus.open("Quests")
	task.wait(0.2)
	local gui = alice.PlayerGui.AnimeTycoonUI
	local root = gui:FindFirstChild("WindowRoot_DÉFIS")
	assert(root and root.Visible, "fenêtre Défis non ouverte")
	assert(root:FindFirstChild("Daily_" .. data.Quests.daily.list[1], true), "carte du défi du jour manquante")
	assert(root:FindFirstChild("Bonus", true), "coffre du jour manquant")
	local menu = Menus.get("Quests")
	for _ = 1, 4 do
		menu.tab(1)
		task.wait(0.15)
		for _ = 1, 3 do
			Harness.services.RunService.RenderStepped:Fire(1 / 60)
		end
	end
	assert(root:FindFirstChild("PunchCycle", true), "panneau du punching-ball (onglet Entraînement) manquant")
	menu.tab(-3) -- onglet Univers
	task.wait(0.2)
	local row = root:FindFirstChild("Quest_u_ninja_1", true)
	assert(row, "ligne du défi « Village Ninja : tue 50 ... » manquante")
	-- Réclamer depuis le bouton de la ligne
	local claimed = false
	for _, d in row:GetDescendants() do
		if d:IsA("TextButton") and d:GetAttribute("SelKey") == "claim_u_ninja_1" then
			signalFor(d, "Activated"):Fire()
			claimed = true
		end
	end
	assert(claimed, "bouton RÉCLAMER introuvable")
	-- laisse les pièces de la récompense voler jusqu'au joueur (images d'effets)
	for _ = 1, 50 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
		task.wait(0.02)
	end
	assert(data.Quests.claimed.u_ninja_1 == 1, "réclamer depuis l'écran ne marche pas")
	assert(QuestsUI.readyCount() >= 0, "compte des récompenses")
	-- Bandeaux de notification : en bas de l'écran tant que la fenêtre Défis est ouverte
	local toasts = gui:FindFirstChild("Toasts", true)
	assert(toasts, "conteneur des bandeaux introuvable")
	Harness.services.RunService.RenderStepped:Fire(1 / 60)
	assert(toasts.Position == QuestsUI.ToastPositionWhileOpen, "les bandeaux masquent les onglets de la fenêtre Défis")
	Menus.close("Quests")
	task.wait(0.1)
	Harness.services.RunService.RenderStepped:Fire(1 / 60)
	assert(toasts.Position ~= QuestsUI.ToastPositionWhileOpen, "les bandeaux ne reviennent pas à leur place")
	-- Suivi : bandeaux de progression et de réussite
	local QuestNotify = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes")).event("QuestNotify")
	signalFor(QuestNotify, "OnClientEvent"):Fire({ kind = "progress", id = "c_kill", title = "Tue 500 ennemis", progress = 250, goal = 500, icon = "sword" })
	signalFor(QuestNotify, "OnClientEvent"):Fire({ kind = "ready", id = "d_kill", title = "Tue 150 ennemis", daily = true, icon = "sword" })
	signalFor(QuestNotify, "OnClientEvent"):Fire({ kind = "punchTier", tier = 1, hits = 100, gems = 2 })
	task.wait(0.1)
	local hud = gui:FindFirstChild("QuestHUD")
	assert(hud and hud:FindFirstChild("Tracker_c_kill", true) and hud:FindFirstChild("Tracker_d_kill", true), "bandeaux de suivi manquants")
	assert(hud:FindFirstChild("PunchPop", true), "annonce de palier manquante")
	expectNoNewWarnings(before, "défis")
end)

test("Zone anti-AFK : panneau affiché sur place, sac qui se balance", function()
	local before = #warnings
	local Layout = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Layout"))
	local gui = alice.PlayerGui.AnimeTycoonUI
	local zone = Layout.AfkZone
	alice.Character:PivotTo(CFrame.new(zone.X, 4, zone.Z))
	task.wait(0.4)
	local panel = gui:FindFirstChild("AfkPanel", true)
	assert(panel and panel.Visible, "panneau de la zone anti-AFK non affiché")
	-- compact, en haut au centre (sous la bannière d'univers), suivi des défis masqué dans la zone
	assert(panel.Position.Y.Scale == 0 and panel.AnchorPoint.Y == 0 and panel.Size.Y.Offset <= 80, "panneau AFK : en haut, compact")
	Harness.services.RunService.RenderStepped:Fire(1 / 60)
	task.wait(0.05)
	local tracker = gui:FindFirstChild("QuestHUD") and gui.QuestHUD:FindFirstChild("Tracker")
	assert(tracker and not tracker.Visible, "les cartes de suivi des défis doivent être masquées dans la zone")
	local toasts = gui:FindFirstChild("Toasts", true)
	assert(toasts and toasts.Position.Y.Offset >= panel.Position.Y.Offset + panel.Size.Y.Offset, "les bandeaux doivent passer sous le panneau AFK")
	local station = workspaceService.World.AfkZone.Stations.Station1
	-- compteur en studs (rapetisse avec la distance) et tableau ligne par ligne, texte fixe
	local counter = station:FindFirstChild("Counter", true)
	assert(counter and counter.Size.X.Offset == 0 and counter.Size.X.Scale >= 5, "compteur du sac : taille en studs")
	local tiersBoard = workspaceService.World.AfkZone:FindFirstChild("TiersBoard", true)
	local line1 = tiersBoard and tiersBoard:FindFirstChild("Line1", true)
	assert(line1 and not line1.TextScaled and line1.TextSize >= 22, "tableau PALIERS : une ligne par texte, taille fixe")
	local bag = station.Bag
	local pivot = bag:GetPivot()
	station:SetAttribute("HitDir", Vector3.new(1, 0, 0))
	station:SetAttribute("HitTick", (station:GetAttribute("HitTick") or 0) + 1)
	task.wait(0.05)
	for _ = 1, 6 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
		task.wait(0.02)
	end
	assert((bag:GetPivot().Position - pivot.Position).Magnitude < 0.01, "le sac doit tourner autour de son crochet")
	alice.Character:PivotTo(CFrame.new(0, 3, 0))
	task.wait(0.4)
	assert(not panel.Visible, "panneau toujours affiché hors de la zone")
	expectNoNewWarnings(before, "zone anti-AFK")
end)

test("Traits : écran, rouleau, relance avec une gemme et révélation renforcée", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local TraitsMenu = Harness.require(client.UI.TraitsMenu)
	local TraitsConfig = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Traits"))
	local data = services.DataService:Get(alice)
	data.traitCrystals = 3
	for _, e in data.characters do
		e.trait = nil
	end
	services.DataService:Sync(alice)
	task.wait(0.4)
	Menus.open("Traits")
	task.wait(0.3)
	local gui = alice.PlayerGui.AnimeTycoonUI
	local root = gui:FindFirstChild("WindowRoot_TRAITS")
	assert(root and root:FindFirstChild("TraitCard", true), "carte du trait manquante")
	assert(root:FindFirstChild("Reel", true) and root:FindFirstChild("Emblem", true), "rouleau ou emblème du trait manquant")
	-- au repos, seul le trait de la ligne du milieu se lit (les voisins sont effacés)
	local restStrip = root:FindFirstChild("ReelStrip", true)
	for _, name in { "Row1", "Row3" } do
		local row = restStrip and restStrip:FindFirstChild(name)
		assert(row and row.TextTransparency >= 0.8 and row:GetAttribute("Dimmed"), "rouleau au repos : la ligne voisine " .. name .. " doit être effacée")
	end
	assert(restStrip.Row2.TextTransparency < 0.1, "rouleau au repos : le trait actuel doit rester bien lisible")
	assert(root:FindFirstChild("Chances", true) and root:FindFirstChild("Tier5", true), "tableau des chances manquant")
	local bank = root:FindFirstChild("Bank", true)
	assert(bank and bank:FindFirstChild("Count") and bank.Count.Text == "3", "réserve de gemmes : compteur faux")
	assert(bank:FindFirstChild("BuyGems"), "bouton d'achat de gemmes manquant")
	local roll = nil
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d:GetAttribute("SelKey") == "roll" then
			roll = d
		end
	end
	assert(roll, "bouton RELANCER manquant")
	signalFor(roll, "Activated"):Fire()
	-- le rouleau tourne (bloquant) puis la révélation s'affiche ; on attend la fin
	local t0 = os.clock()
	task.wait(0.2)
	while TraitsMenu.isRolling() and os.clock() - t0 < 10 do
		task.wait(0.2)
		Harness.services.RunService.RenderStepped:Fire(1 / 30)
		if os.clock() - t0 > 3.5 then
			TraitsMenu.skipCinematic()
		end
	end
	assert(not TraitsMenu.isRolling(), "la relance ne se termine pas")
	task.wait(0.4)
	assert(data.traitCrystals == 2, "la relance doit coûter 1 gemme (" .. tostring(data.traitCrystals) .. ")")
	-- au repos, la ligne du milieu du rouleau est le trait de l'unité sélectionnée
	local rolled = nil
	for _, e in data.characters do
		if e.trait then
			rolled = e.trait
		end
	end
	assert(rolled, "aucun trait tiré")
	root = gui:FindFirstChild("WindowRoot_TRAITS")
	local strip = root:FindFirstChild("ReelStrip", true)
	local row2 = strip and strip:FindFirstChild("Row2")
	assert(row2 and row2:GetAttribute("TraitId") == rolled, "le rouleau doit s'arrêter sur le trait tiré")
	-- à l'arrêt, la carte est repeinte avec le résultat (plus de « ? » ni de rang « … »)
	local card = root:FindFirstChild("TraitCard", true)
	assert(card and not card:FindFirstChild("Mystery", true), "l'emblème « ? » du rouleau doit disparaître à l'arrêt")
	local desc = card:FindFirstChild("TraitDesc")
	assert(desc and desc.Text ~= "" and desc.TextWrapped, "description du trait vide ou sur une seule ligne")
	-- tableau des chances lisible : noms et chances en grand
	for _, label in root:FindFirstChild("Chances", true):GetDescendants() do
		if label:IsA("TextLabel") and (label.Name == "TraitName" or label.Name == "Chance") then
			local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			assert(limit and limit.MaxTextSize >= (label.Name == "TraitName" and 14 or 12), "texte du tableau des chances trop petit")
		end
	end
	-- révélation renforcée (trait rare sans cinématique)
	local overlay = TraitsMenu.playReveal(TraitsConfig.List.critique, { name = "Test" }, 5)
	assert(overlay and overlay:FindFirstChild("Title") and overlay.Title.Text == "CRITIQUE", "révélation renforcée sans titre")
	assert(overlay:FindFirstChild("Sunburst") and overlay:FindFirstChild("Emblem"), "révélation renforcée sans rayons ni emblème")
	TraitsMenu.skipCinematic()
	assert(not overlay.Parent, "la révélation ne se passe pas")
	-- sans flashs (Options) : pas de voile blanc plein écran
	alice:SetAttribute("FxFlash", false)
	local overlay2 = TraitsMenu.playReveal(TraitsConfig.List.vigueur3, nil, 5)
	assert(overlay2.Veil.BackgroundTransparency >= 0.75, "le flash doit être coupé par l'option")
	TraitsMenu.skipCinematic()
	alice:SetAttribute("FxFlash", nil)
	-- niveaux de révélation
	assert(TraitsConfig.revealLevel("monarque") == 4 and TraitsConfig.revealLevel("vampire") == 4, "Monarque / Vampire : cinématique")
	-- les 4 traits à cinématique sont tous très rares (Mythique ou Secret, moins de 2 %)
	for _, id in { "monarque", "celeste", "midas", "vampire" } do
		assert(TraitsConfig.List[id].tier >= 4 and TraitsConfig.chance(id) < 2, id .. " doit être très rare")
	end
	assert(TraitsConfig.revealLevel("critique") == 3 and TraitsConfig.revealLevel("fortune") == 2 and TraitsConfig.revealLevel("vigueur1") == 1, "niveaux de révélation")
	Menus.close("Traits")
	expectNoNewWarnings(before, "traits")
end)

local function tanVOf(camera)
	return math.tan(math.rad(camera.FieldOfView) / 2)
end

test("Traits : cinématique MONARQUE dans le monde (persos à genoux, couronne, cadrage)", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local TraitCinematic = Harness.require(client.Controllers.TraitCinematic)
	local State = Harness.require(client.State)
	local list = State.sortedCharacters()
	local entry, desc = table.clone(list[1].entry), list[1].desc
	entry.uid = list[1].uid
	local fake = 0
	local stage = CFrame.new(40, 0.5, 40)
	local scene = TraitCinematic.play("monarch", entry, desc, {
		duration = 200,
		stage = stage,
		clock = function()
			return fake
		end,
	})
	assert(scene and not scene.finished, "la cinématique ne démarre pas")
	local folder = scene.folder
	assert(folder.Parent == game.Workspace, "la scène doit être dans le monde (Workspace)")
	assert(alice.PlayerGui:FindFirstChild("TraitCinematicUI"), "interface de la cinématique manquante")
	assert(not alice.PlayerGui.AnimeTycoonUI.Enabled, "l'interface du jeu doit être masquée pendant la scène")
	local camera = game.Workspace.CurrentCamera
	assert(camera.CameraType == roblox.Enum.CameraType.Scriptable, "caméra non scriptée")
	-- plan final (couronne posée, persos à genoux)
	fake = 7
	for _ = 1, 3 do
		Harness.services.RunService.RenderStepped:Fire(1 / 30)
		task.wait(0.03)
	end
	local hero = folder:FindFirstChild("Hero")
	assert(hero, "unité introuvable")
	local crown = folder:FindFirstChild("Crown")
	assert(crown, "couronne manquante")
	local head = hero:FindFirstChild("Head")
	local ring = crown:FindFirstChild("Ring")
	local headTop = head.CFrame.Position.Y + head.Size.Y * 0.5
	local ringY = ring.CFrame.Position.Y
	assert(math.abs(ringY - (stage.Position.Y + scene.crownY)) < 0.05, "la couronne n'est pas arrivée à sa place")
	-- elle flotte juste au-dessus de la coiffure (0,4 stud), sans cacher la tête ni les cheveux
	local crownBottom = math.huge
	for _, piece in crown:GetDescendants() do
		if piece:IsA("BasePart") then
			crownBottom = math.min(crownBottom, piece.CFrame.Position.Y - piece.Size.X * 0.5)
		end
	end
	local hairTop = stage.Position.Y + math.max(scene.heroHairTop, headTop - stage.Position.Y)
	assert(crownBottom >= hairTop + 0.3, "la couronne touche ou cache les cheveux (" .. crownBottom .. " / " .. hairTop .. ")")
	assert(crownBottom <= hairTop + 0.6, "la couronne flotte trop haut (" .. crownBottom .. " / " .. hairTop .. ")")
	-- le titre tient entièrement sur la bande noire du haut (10 % de l'image), sans mordre sur la scène
	local titleBlock = alice.PlayerGui.TraitCinematicUI:FindFirstChild("TitleBlock", true)
	assert(titleBlock, "titre manquant")
	local titleTop = titleBlock.Position.Y.Scale - titleBlock.AnchorPoint.Y * titleBlock.Size.Y.Scale
	local titleBottom = titleTop + titleBlock.Size.Y.Scale
	assert(titleTop >= 0 and titleBottom <= 0.1 and titleBlock.Size.Y.Offset == 0, "le titre doit tenir sur la bande noire (" .. titleTop .. " / " .. titleBottom .. ")")
	local crownView = camera.CFrame:PointToObjectSpace(ring.CFrame.Position + Vector3.new(0, ring.Size.Y * 0.5, 0))
	local crownScreenY = 0.5 - (crownView.Y / -crownView.Z) / tanVOf(camera) * 0.5
	assert(crownScreenY > 0.12, "la couronne est sous la bande noire (" .. crownScreenY .. ")")
	-- les persos sont en demi-cercle DEVANT l'unité (côté -Z de la scène)
	for _, spot in TraitCinematic.monarchSpots() do
		assert(spot.Z < -0.2, "un perso n'est pas devant l'unité")
	end
	-- plans 1 et 2 : caméra haute, aucun perso de la cour près de l'objectif (pas de perso énorme
	-- au premier plan)
	local keys = TraitCinematic.monarchCamera(7)
	for i = 1, 2 do
		local eye = keys[i][2]
		assert(eye.Y >= 11, "plan " .. i .. " : caméra trop basse")
		for _, spot in TraitCinematic.monarchSpots() do
			assert((spot - eye).Magnitude > 13, "plan " .. i .. " : un perso de la cour est trop près de la caméra")
		end
	end
	-- jamais une copie du héros dans la cour
	for _, info in TraitCinematic.kneelerLooks(entry.uid, TraitCinematic.MonarchCount) do
		assert(info.id ~= entry.id, "une copie du héros est dans la cour")
	end
	-- légendes lisibles de loin : phrase >= 26 px, badge >= 20 px
	local sub = alice.PlayerGui.TraitCinematicUI:FindFirstChild("Subtitle", true)
	assert(sub and not sub.TextScaled and sub.TextSize >= 26, "phrase de la cinématique trop petite")
	local badgeText = alice.PlayerGui.TraitCinematicUI:FindFirstChild("BadgeText", true)
	assert(badgeText and not badgeText.TextScaled and badgeText.TextSize >= 20, "badge de rang trop petit")
	local tanV = tanVOf(camera)
	local tanH = tanV * 16 / 9
	-- boîte d'un perso dans le repère `frame` (repère du perso : boîtes orientées, plus justes
	-- qu'une boîte alignée sur le monde pour des persos disposés en cercle)
	local function boxOf(model, frame)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local half = part.Size * 0.5
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local c = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
							lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
							hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
						end
					end
				end
			end
		end
		return lo, hi
	end
	local boxes = {}
	local kneelers = 0
	local function onScreen(point)
		local v = camera.CFrame:PointToObjectSpace(point)
		return v.Z < 0 and math.abs(v.X / -v.Z) < tanH * 0.98 and math.abs(v.Y / -v.Z) < tanV * 0.8, v
	end
	-- plan final : l'unité entière est dans l'image et occupe ~40 % de sa hauteur ; la cour
	-- (de dos, inclinée) encadre le bas de l'image : la tête de chaque perso est visible
	local headsVisible = 0
	local heroLow, heroHigh = math.huge, -math.huge
	for _, part in hero:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local ok, v = onScreen(part.CFrame.Position)
			assert(ok, "unité coupée par le cadre : " .. part.Name)
			local y = 0.5 - (v.Y / -v.Z) / tanV * 0.5
			heroLow, heroHigh = math.min(heroLow, y), math.max(heroHigh, y)
		end
	end
	assert(heroHigh - heroLow > 0.3, "l'unité couronnée est trop petite dans le plan final (" .. (heroHigh - heroLow) .. ")")
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.Name ~= "Crown" then
			local kneelerHead = child:FindFirstChild("Head")
			if kneelerHead and child ~= hero then
				-- les persos du rang extérieur avant peuvent être coupés par le bord de l'image
				-- (premier plan), mais leur tête reste au moins en partie visible
				local inFrame, v = onScreen(kneelerHead.CFrame.Position)
				if inFrame then
					headsVisible += 1
				else
					assert(v.Z < 0 and math.abs(v.X / -v.Z) < tanH * 1.2, "tête loin hors du cadre : " .. child.Name)
				end
			end
			-- repère du perso : son orientation au sol (sans l'inclinaison du torse)
			local torsoPart = child:FindFirstChild("Torso")
			local facing = torsoPart and torsoPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			local frame = (facing and facing.Magnitude > 0.1) and CFrame.lookAt(Vector3.zero, facing.Unit) or CFrame.new()
			table.insert(boxes, { name = child.Name, model = child, frame = frame })
			if string.sub(child.Name, 1, 7) == "Kneeler" then
				kneelers += 1
				local torso = child:FindFirstChild("Torso")
				assert(torso and torso.CFrame.Position.Y - stage.Position.Y < 2.4, "perso pas agenouillé : " .. child.Name)
				-- tourné vers l'unité
				local look = torso.CFrame.LookVector * Vector3.new(1, 0, 1)
				local to = (stage.Position - torso.CFrame.Position) * Vector3.new(1, 0, 1)
				assert(look.Unit:Dot(to.Unit) > 0.8, child.Name .. " ne regarde pas l'unité")
			end
		end
	end
	assert(headsVisible >= TraitCinematic.MonarchCount - 2, "trop de persos de la cour hors du cadre (" .. headsVisible .. ")")
	assert(kneelers == TraitCinematic.MonarchCount, "il faut " .. TraitCinematic.MonarchCount .. " persos agenouillés (" .. kneelers .. ")")
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local A, B = boxes[i], boxes[j]
			local separated = false
			for _, frame in { A.frame, B.frame } do
				local alo, ahi = boxOf(A.model, frame)
				local blo, bhi = boxOf(B.model, frame)
				if not (alo.X < bhi.X and blo.X < ahi.X and alo.Y < bhi.Y and blo.Y < ahi.Y and alo.Z < bhi.Z and blo.Z < ahi.Z) then
					separated = true
				end
			end
			assert(separated, A.name .. " chevauche " .. B.name)
		end
	end
	-- rien entre la caméra et la tête / le torse de l'unité
	local function segmentHits(part, a, b)
		local pa, pb = part.CFrame:PointToObjectSpace(a), part.CFrame:PointToObjectSpace(b)
		local half = part.Size * 0.5
		local t0, t1 = 0, 1
		for _, axis in { "X", "Y", "Z" } do
			local p0, d = pa[axis], pb[axis] - pa[axis]
			local h = half[axis]
			if math.abs(d) < 1e-6 then
				if p0 < -h or p0 > h then
					return false
				end
			else
				local u0, u1 = (-h - p0) / d, (h - p0) / d
				if u0 > u1 then
					u0, u1 = u1, u0
				end
				t0, t1 = math.max(t0, u0), math.min(t1, u1)
				if t0 > t1 then
					return false
				end
			end
		end
		return true
	end
	for _, target in { head, hero:FindFirstChild("Torso") } do
		local a, b = camera.CFrame.Position, target.CFrame.Position
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 0.5 and not part:IsDescendantOf(hero) and not part:IsDescendantOf(crown) then
				assert(not segmentHits(part, a, b), part:GetFullName() .. " cache " .. target.Name .. " de l'unité")
			end
		end
	end
	-- titre affiché, bouton Passer
	local ui = alice.PlayerGui.TraitCinematicUI
	local title = ui:FindFirstChild("Title", true)
	assert(title and title.Text == "MONARQUE", "titre MONARQUE manquant")
	assert(ui:FindFirstChild("Skip", true), "bouton Passer manquant")
	TraitCinematic.skip()
	assert(scene.finished and not folder.Parent, "la scène n'est pas nettoyée")
	assert(not alice.PlayerGui:FindFirstChild("TraitCinematicUI"), "interface de la cinématique non retirée")
	assert(alice.PlayerGui.AnimeTycoonUI.Enabled, "l'interface du jeu doit revenir")
	assert(camera.CameraType ~= roblox.Enum.CameraType.Scriptable, "la caméra doit revenir au joueur")
	-- Pose à genoux lisible
	local Components = Harness.require(client.UI.Components)
	local model = Components.characterModel(desc.look, entry.id, entry.stars)
	local pose = TraitCinematic.kneelPose(model)
	local torso = model:FindFirstChild("Torso")
	assert(pose[torso] and pose[torso][2].Position.Y < pose[torso][1].Position.Y - 0.5, "le torse ne descend pas à genoux")
	assert(pose[torso][2].UpVector.Y > 0.75, "le torse doit rester assez droit (révérence, pas couché)")
	-- deux temps : la tête reste dans l'axe du torse quand le corps descend, puis s'incline
	local headPose = pose[model:FindFirstChild("Head")]
	assert(headPose[3] and headPose[3].LookVector.Y < headPose[2].LookVector.Y - 0.2, "la tête doit s'incliner dans un 2e temps")
	assert(headPose[3].LookVector.Y < -0.6, "la tête doit être bien baissée")
	-- génuflexion « chevalier » : jambe avant (droite) presque verticale, jambe arrière (gauche)
	-- couchée au sol derrière le perso, son bout posé au sol
	local rightLeg, leftLeg = model:FindFirstChild("Right Leg"), model:FindFirstChild("Left Leg")
	local front, back = pose[rightLeg][2], pose[leftLeg][2]
	assert(front.UpVector.Y > 0.97, "la jambe avant doit rester presque verticale (tibia du genou levé)")
	assert(math.abs(back.UpVector.Y) < 0.3, "la jambe arrière doit être couchée (genou et tibia au sol)")
	assert(back.Position.Z > pose[leftLeg][1].Position.Z + 0.8, "la jambe arrière doit partir vers l'arrière")
	local lowest = math.huge
	local half = leftLeg.Size * 0.5
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				lowest = math.min(lowest, back:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y)
			end
		end
	end
	assert(math.abs(lowest) < 0.1, "le bout de la jambe arrière doit toucher le sol (" .. lowest .. ")")
	assert(pose[torso][2].LookVector.Y < -0.4, "le torse doit s'incliner en révérence")
	-- la main droite repose sur la cuisse avant (bras un peu en avant), le bras gauche le long du corps
	local rightArm, leftArm = pose[model:FindFirstChild("Right Arm")][2], pose[model:FindFirstChild("Left Arm")][2]
	assert(rightArm.UpVector:Dot(pose[torso][2].UpVector) < 0.99, "la main droite doit avancer vers la cuisse")
	assert(leftArm.UpVector:Dot(pose[torso][2].UpVector) > 0.98, "le bras gauche doit rester le long du corps")
	expectNoNewWarnings(before, "cinématique Monarque")
end)

test("Traits : cinématiques Céleste, Midas, Vampire et résultat reçu du serveur", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local TraitCinematic = Harness.require(client.Controllers.TraitCinematic)
	local State = Harness.require(client.State)
	local item = State.sortedCharacters()[1]
	local entry = table.clone(item.entry)
	entry.uid = item.uid
	alice:SetAttribute("FxShake", false)
	local clockBefore = game:GetService("Lighting").ClockTime
	for kind, expect in { celeste = { "CelestialBeam", "WingFeather" }, midas = { "Coin", "GoldPool" }, vampire = { "BloodMoon", "BatBody" } } do
		local fake = 0
		local scene = TraitCinematic.play(kind, entry, item.desc, {
			duration = 200,
			stage = CFrame.new(-40, 0.5, 40),
			clock = function()
				return fake
			end,
		})
		assert(scene and not scene.finished, kind .. " ne démarre pas")
		for _, name in expect do
			assert(scene.folder:FindFirstChild(name, true), kind .. " : " .. name .. " manquant")
		end
		fake = 4
		for _ = 1, 3 do
			Harness.services.RunService.RenderStepped:Fire(1 / 30)
			task.wait(0.03)
		end
		assert(not scene.finished, kind .. " s'est arrêtée en route")
		assert(scene.shake == 0, kind .. " : la secousse doit être coupée par l'option")
		local title = alice.PlayerGui.TraitCinematicUI:FindFirstChild("Title", true)
		assert(title and title.Text == TraitCinematic.Titles[kind], kind .. " : titre manquant")
		if kind == "celeste" then
			-- la caméra démarre hors du faisceau (8 studs ou plus sur le côté)
			local first = TraitCinematic.celesteCamera(6)[1][2]
			assert(math.abs(first.X) >= 8, "Céleste : la caméra démarre dans le faisceau")
			-- le faisceau entoure l'unité (plus large que ses épaules), très translucide, et l'unité est
			-- détachée par un contour blanc
			local beam = scene.folder:FindFirstChild("CelestialBeam")
			assert(beam and beam.Transparency >= 0.85, "Céleste : faisceau trop opaque")
			assert(math.min(beam.Size.Y, beam.Size.Z) >= 5.5, "Céleste : le faisceau doit entourer l'unité, pas la traverser")
			local outline = scene.hero and scene.hero:FindFirstChild("CelestialOutline")
			assert(outline and outline:IsA("Highlight") and outline.FillTransparency >= 0.75, "Céleste : contour blanc de l'unité manquant")
			-- chaque aile part de son épaule vers l'extérieur (pas à travers le corps) et un peu en arrière
			local stage = scene.stage
			local count = 0
			for _, feather in scene.folder:GetDescendants() do
				if feather.Name == "WingFeather" then
					count += 1
					local rel = stage:ToObjectSpace(feather.CFrame)
					local root = rel.Position - rel.LookVector * feather.Size.Z * 0.5 -- bout côté épaule
					local tip = rel.Position + rel.LookVector * feather.Size.Z * 0.5
					assert(math.abs(tip.X) > math.abs(root.X) + 1, "Céleste : une rémige ne s'écarte pas du corps")
					assert(math.sign(tip.X) == math.sign(root.X), "Céleste : une aile traverse le corps")
					assert(tip.Z > root.Z - 0.05, "Céleste : les ailes doivent partir vers l'arrière")
				end
			end
			assert(count == 14, "Céleste : 2 ailes de 7 rémiges attendues (" .. count .. ")")
			-- un sort lancé pendant la scène (dossier ClientFX) est masqué dès son apparition
			local fx = game.Workspace:FindFirstChild("ClientFX") or Instance.new("Folder")
			fx.Name = "ClientFX"
			fx.Parent = game.Workspace
			local spell = Instance.new("Part")
			spell.Parent = fx
			signalFor(fx, "DescendantAdded"):Fire(spell)
			assert(spell.LocalTransparencyModifier == 1, "Céleste : un sort apparu pendant la scène doit être masqué")
			scene.testSpell = spell
		end
		if kind == "midas" then
			local torso = scene.hero and scene.hero:FindFirstChild("Torso")
			assert(torso and torso.Material == roblox.Enum.Material.Foil and torso.Reflectance >= 0.3, "Midas : l'unité doit être changée en or poli")
			assert(scene.hero:FindFirstChild("MidasGlow"), "Midas : contour doré manquant")
			-- aucun disque plein devant les jambes : l'anneau qui monte est un cerceau de segments fins
			for _, sweepPart in scene.folder:GetDescendants() do
				if sweepPart.Name == "GoldSweep" then
					assert(math.max(sweepPart.Size.X, sweepPart.Size.Y, sweepPart.Size.Z) < 1, "Midas : bloc doré devant l'unité")
				end
				if sweepPart.Name == "CoinHeap" then
					assert(sweepPart.CFrame.Position.Y - scene.stage.Position.Y < 0.85, "Midas : tas de pièces trop haut")
					assert(math.abs(scene.stage:PointToObjectSpace(sweepPart.CFrame.Position).X) > 2, "Midas : tas de pièces devant l'unité")
				end
			end
			-- aucune pièce ne tombe entre la caméra et l'unité (vue de dessus)
			local keys = TraitCinematic.midasCamera(6)
			local spots = TraitCinematic.coinSpots(keys, 70, 5)
			assert(#spots >= 60, "Midas : trop peu de pièces")
			for _, key in keys do
				local eye = Vector2.new(key[2].X, key[2].Z)
				assert(eye.Magnitude >= 12, "Midas : la caméra doit rester à 12 studs ou plus")
				for _, spot in spots do
					local p = Vector2.new(spot.X, spot.Z)
					local along = p:Dot(eye.Unit)
					if along >= 0 then
						local side = (p - eye.Unit * math.min(along, eye.Magnitude)).Magnitude
						assert(side >= 2.3, "Midas : une pièce tombe devant la caméra")
					end
				end
			end
		end
		local lighting = game:GetService("Lighting")
		if kind == "vampire" then
			-- la nuit tombe chez ce joueur seulement (éclairage local), puis le jour revient
			assert(lighting.ClockTime < 1 or lighting.ClockTime > 23.5, "Vampire : la nuit doit tomber (" .. lighting.ClockTime .. ")")
			-- nuit rouge mais lisible : ambiance claire, contour rouge et rai de lune sur l'unité
			local amb = lighting.OutdoorAmbient
			assert(amb.R * 255 >= 70 and amb.G * 255 >= 25, "Vampire : ambiance de nuit trop sombre")
			local outline = scene.hero and scene.hero:FindFirstChild("VampireOutline")
			assert(outline and outline:IsA("Highlight") and outline.OutlineTransparency < 0.1, "Vampire : contour rouge de l'unité manquant")
			local ray = scene.folder:FindFirstChild("MoonRay", true)
			assert(ray and ray:IsA("SpotLight") and ray.Brightness >= 2, "Vampire : rai de lune manquant")
		end
		TraitCinematic.skip()
		assert(scene.finished and not scene.folder.Parent, kind .. " : scène non nettoyée")
		if scene.testSpell then
			assert(scene.testSpell.LocalTransparencyModifier == 0, "le sort masqué doit réapparaître après la scène")
			scene.testSpell:Destroy()
		end
		if kind == "vampire" then
			task.wait(0.05)
			assert(lighting.ClockTime == clockBefore, "Vampire : l'heure du jour doit revenir (" .. lighting.ClockTime .. ")")
		end
	end
	alice:SetAttribute("FxShake", nil)
	-- Résultat reçu du serveur (relance faite ailleurs que dans l'écran) : la cinématique se joue
	local remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	signalFor(remotes.event("TraitRolled"), "OnClientEvent"):Fire({ uid = item.uid, traitId = "monarque" })
	task.wait(0.1)
	assert(TraitCinematic.isPlaying(), "TraitRolled (Monarque) doit lancer la cinématique")
	TraitCinematic.skip()
	-- une relance réclamée par l'écran des Traits n'est pas rejouée
	TraitCinematic.claim(item.uid)
	signalFor(remotes.event("TraitRolled"), "OnClientEvent"):Fire({ uid = item.uid, traitId = "celeste" })
	task.wait(0.1)
	assert(not TraitCinematic.isPlaying(), "relance réclamée : pas de double cinématique")
	-- traits ordinaires : pas de cinématique
	signalFor(remotes.event("TraitRolled"), "OnClientEvent"):Fire({ uid = item.uid, traitId = "vigueur1" })
	task.wait(0.1)
	assert(not TraitCinematic.isPlaying(), "trait commun : pas de cinématique")
	expectNoNewWarnings(before, "cinématiques des traits")
end)

test("Forgeron : vignettes inclinées à 45°, grand aperçu qui tourne, nom d'effet court", function()
	local before = #warnings
	Menus.open("Forge")
	task.wait(0.3)
	local gui = alice.PlayerGui.AnimeTycoonUI
	local thumbs, bigs = {}, {}
	for _, d in gui:GetDescendants() do
		if d:IsA("ViewportFrame") then
			local model = d:FindFirstChildOfClass("Model")
			local handle = model and model:FindFirstChild("Handle")
			if handle and model:GetAttribute("Top") then
				local inGrid, inDetail = false, false
				local node = d.Parent
				while node and node ~= gui do
					if node.Name == "Grid" then
						inGrid = true
					elseif node.Name == "DetailHolder" then
						inDetail = true
					end
					node = node.Parent
				end
				if inGrid then
					table.insert(thumbs, handle)
				elseif inDetail then
					table.insert(bigs, { model = model, handle = handle })
				end
			end
		end
	end
	assert(#thumbs >= 8, "vignettes d'épées : " .. #thumbs)
	for _, handle in thumbs do
		-- La lame (-Z de la poignée) part en diagonale (45°) dans le plan de l'écran.
		local blade = handle.CFrame.LookVector
		assert(math.abs(math.abs(blade.X) - 0.7071) < 0.02 and math.abs(math.abs(blade.Y) - 0.7071) < 0.02, "vignette non inclinée")
	end
	assert(#bigs == 1, "grand aperçu : " .. #bigs)
	local big = bigs[1]
	local start = big.handle.CFrame
	for _ = 1, 10 do
		Harness.services.RunService.RenderStepped:Fire(0.1)
	end
	local turned = big.handle.CFrame
	local angle = math.deg(math.acos(math.clamp(start.RightVector:Dot(turned.RightVector), -1, 1)))
	assert(angle > 5 and angle < 60, "le grand aperçu ne tourne pas lentement (" .. angle .. "°)")
	local effect = nil
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "Effet : ", 1, true) and d:IsDescendantOf(gui) then
			effect = d.Text
		end
	end
	assert(effect and not string.find(effect, "Cristaux", 1, true), "nom d'effet : " .. tostring(effect))
	Menus.close("Forge")
	expectNoNewWarnings(before, "forgeron")
end)

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
			{ id = "occ_goju", stars = 1, rarity = "mythic", price = 250000, dps = 4200, aura = "diamant" },
			{ id = "ninja_maruto", stars = 1, rarity = "epic", price = 900, dps = 80 },
			{ id = "sai_goko", stars = 1, rarity = "mythic", price = 1000000, dps = 9000, aura = "or" },
		},
		pity = { mythic = 100 },
		count = 3,
	})
	task.wait(0.4)
	local strip = alice.PlayerGui.AnimeTycoonUI.RollReveal.Strip
	local cards, chips = 0, 0
	for _, d in strip:GetDescendants() do
		if string.sub(d.Name, 1, 8) == "RollCard" then
			cards += 1
		elseif d.Name == "Mutation" and d:IsA("Frame") then
			chips += 1
		end
	end
	assert(cards == 3, "3 cartes attendues, " .. cards .. " trouvées")
	assert(chips == 2, "mutations non affichées sur les cartes : " .. chips)
	local banner = strip:FindFirstChild("Mutation")
	assert(banner and banner.Text:find("DIAMANT"), "bandeau de la meilleure mutation absent")
	for _ = 1, 10 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
	end
	task.wait(3.2)
	expectNoNewWarnings(before, "révélation du roulage")
end)

test("Machine ROULER : commandes à la machine seulement + fenêtre « Roulement automatique »", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RollPanel = Harness.require(client.UI.RollPanel)
	local AutoRoll = Harness.require(client.UI.AutoRoll)
	local State = Harness.require(client.State)
	local data = services.DataService:Get(alice)
	local ui = alice.PlayerGui.AnimeTycoonUI
	-- Passe Robux posé sur le joueur (le harnais ne déclenche pas tout seul le signal d'attribut).
	local function setAttr(name, value)
		alice:SetAttribute(name, value)
		signalFor(alice, "Attr:" .. name):Fire()
	end
	-- Plus de panneau ROULAGE permanent à droite du HUD.
	assert(ui.HUD:FindFirstChild("RollPanel") == nil, "l'ancien panneau ROULAGE est encore dans le HUD")
	local panel = RollPanel.panel()
	assert(panel and panel.Name == "MachinePanel", "commandes de la machine absentes")
	-- Loin de la machine : rien. À la machine : ROULER, x1/x2/x3, AUTO.
	RollPanel.forceNear(false)
	assert(panel.Visible == false, "commandes affichées loin de la machine")
	RollPanel.forceNear(true)
	assert(panel.Visible == true, "commandes cachées à la machine")
	-- À la machine, les panneaux d'achat éloignés (cour, stands) se cachent, puis reviennent.
	local plot = services.PlotService:GetPlot(alice)
	local farBoards, hiddenFar = 0, 0
	local machineCF = RollPanel.machineCFrame()
	for _, d in plot.ownerFolder.Pads:GetDescendants() do
		if d.Name == "PriceGui" then
			local localPos = machineCF:PointToObjectSpace(d.Parent.CFrame.Position)
			local far = localPos.Magnitude > RollPanel.DeclutterRadius or localPos.Z > 4
			if far then
				farBoards += 1
				if d.Enabled == false then
					hiddenFar += 1
				end
			end
		end
	end
	assert(farBoards > 0 and hiddenFar == farBoards, "panneaux éloignés encore visibles à la machine : " .. hiddenFar .. "/" .. farBoards)
	-- Loin de la machine, caméra tournée vers le ciel (aucun panneau à l'écran) : tous visibles.
	local savedCamera = camera.CFrame
	camera.CFrame = CFrame.new(0, 400, 0) * CFrame.Angles(math.rad(85), 0, 0)
	RollPanel.forceNear(false)
	RollPanel.updateBoards()
	for _, d in plot.ownerFolder.Pads:GetDescendants() do
		if d.Name == "PriceGui" then
			assert(d.Enabled, "panneau d'achat resté caché loin de la machine")
		end
	end
	-- Vue de l'entrée de la base : version compacte au loin, aucun recouvrement à l'écran.
	do -- (CFrame.lookAt de Lune inverse l'axe Z : on construit le repère à la main)
		local eye, target = (plot.cf * CFrame.new(0, 14, -82)).Position, (plot.cf * CFrame.new(0, 4, -40)).Position
		local fw = (target - eye).Unit
		local right = fw:Cross(Vector3.new(0, 1, 0)).Unit
		camera.CFrame = CFrame.fromMatrix(eye, right, right:Cross(fw), -fw)
	end
	RollPanel.updateBoards()
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared").Modules.Formulas)
	local view = {
		eye = camera.CFrame.Position,
		forward = camera.CFrame.LookVector,
		right = camera.CFrame.RightVector,
		up = camera.CFrame.UpVector,
		focal = 380 / math.tan(math.rad(camera.FieldOfView / 2)),
		w = 1280,
		h = 760,
	}
	local onScreen, compactFar, nearFull = {}, 0, 0
	for _, d in plot.ownerFolder.Pads:GetDescendants() do
		if d.Name == "PriceGui" and d.Enabled then
			local pos = d.Parent.CFrame.Position + d.StudsOffsetWorldSpace
			local dist = (pos - view.eye).Magnitude
			if dist > d:GetAttribute("FarDistance") then
				assert(d:GetAttribute("Compact") == true and not d.Card.Effect.Visible, "panneau lointain pas en version compacte")
				compactFar += 1
			else
				assert(d:GetAttribute("Compact") == false and d.Card.Effect.Visible, "panneau proche en version compacte")
				nearFull += 1
			end
			local rect = Formulas.boardRect(view, pos, d.Size.X.Scale, d.Size.X.Offset, d.Size.Y.Scale / 2, d.Size.Y.Offset / 2)
			if rect then
				table.insert(onScreen, rect)
			end
		end
	end
	assert(#onScreen >= 3, "trop peu de panneaux lisibles depuis l'entrée : " .. #onScreen)
	for i = 1, #onScreen do
		for j = i + 1, #onScreen do
			local a, b = onScreen[i], onScreen[j]
			local ox = math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0))
			local oy = math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0))
			local area = math.min((a.x1 - a.x0) * (a.y1 - a.y0), (b.x1 - b.x0) * (b.y1 - b.y0))
			assert(ox * oy <= Formulas.BoardMaxOverlap * area + 1e-6, "deux panneaux affichés se recouvrent depuis l'entrée")
		end
	end
	assert(nearFull > 0 and compactFar > 0, "panneaux complets (près) et compacts (loin) attendus : " .. nearFull .. " / " .. compactFar)
	camera.CFrame = savedCamera
	RollPanel.forceNear(true)
	local r = RollPanel.refs()
	assert(r.multi[2].tag.Visible and r.multi[3].tag.Visible, "prix Robux des passes x2 / x3 absents")
	assert(r.multi[2].price.Text:find("R%$"), "prix du passe x2 : " .. r.multi[2].price.Text)
	assert(r.pityText.Text:find("Mythique"), "pitié du Mythique absente : " .. r.pityText.Text)
	setAttr("Pass_Roll2", true)
	task.wait(0.1)
	assert(not r.multi[2].tag.Visible, "passe x2 possédé mais encore « à acheter »")
	-- AUTO ouvre la fenêtre « Roulement automatique ».
	signalFor(r.autoButton, "Activated"):Fire()
	task.wait(0.2)
	assert(Menus.current() == "AutoRoll", "la fenêtre AUTO ne s'ouvre pas")
	local refs = AutoRoll.refs()
	assert(refs.root.Visible, "fenêtre invisible")
	assert(refs.leftCover.Visible and refs.rightCover.Visible, "colonnes non verrouillées sans passe")
	local rows = 0
	for _, d in refs.leftList:GetChildren() do
		if string.sub(d.Name, 1, 4) == "Row_" then
			rows += 1
		end
	end
	assert(rows >= 5 + 6, "lignes de rareté / mutation manquantes : " .. rows)
	-- Avec le passe : on lance l'AFK depuis la fenêtre.
	setAttr("Pass_AutoRoll", true)
	task.wait(0.1)
	assert(not refs.leftCover.Visible, "colonne gauche encore verrouillée avec le passe")
	assert(refs.rightCover.Visible, "colonne droite déverrouillée sans le passe +")
	signalFor(refs.afkButton, "Activated"):Fire()
	task.wait(0.3)
	assert(data.AutoRoll == true, "« Lancer » n'a pas lancé l'auto-roulage")
	signalFor(refs.afkButton, "Activated"):Fire()
	task.wait(0.3)
	assert(data.AutoRoll == false, "« Arrêter » n'a pas arrêté l'auto-roulage")
	-- Une ligne Activé / Désactivé enregistre le réglage (sur une rareté présente dans l'univers
	-- actuel ; les raretés sans perso ont un bouton grisé « — » qui ne fait rien).
	local ThemeUI = Harness.require(Harness.find("StarterPlayer.StarterPlayerScripts.Client").UI.Theme)
	local toggle, rarityId, greyed = nil, nil, 0
	for _, id in { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" } do
		local info = ThemeUI.rarity(id)
		local row = info and refs.leftList:FindFirstChild("Row_" .. info.name)
		local button = row and row:FindFirstChild("Toggle")
		if button and button:GetAttribute("Disabled") then
			greyed += 1
			assert(button.Label.Text == "—" and button.Selectable == false, "bouton d'une rareté vide pas grisé")
			local beforeValue = data.AutoRollSettings.pauseRarities[id]
			signalFor(button, "Activated"):Fire()
			task.wait(0.1)
			assert(data.AutoRollSettings.pauseRarities[id] == beforeValue, "bouton grisé encore actif")
		elseif button and not toggle then
			toggle, rarityId = button, id
		end
	end
	assert(toggle, "aucune ligne de rareté réglable")
	-- (l'état de départ est celui affiché par le bouton)
	local initial = toggle.Label.Text == "Activé"
	signalFor(toggle, "Activated"):Fire()
	task.wait(0.6)
	assert((data.AutoRollSettings.pauseRarities[rarityId] == true) == not initial, "réglage non enregistré")
	signalFor(toggle, "Activated"):Fire()
	task.wait(0.6)
	assert((data.AutoRollSettings.pauseRarities[rarityId] == true) == initial, "réglage non rétabli")
	print("   raretés grisées (aucun perso dans l'univers) : " .. greyed)
	-- Avancé (achat automatique +).
	setAttr("Pass_AutoRollPlus", true)
	task.wait(0.1)
	assert(not refs.rightCover.Visible, "colonne droite encore verrouillée avec le passe +")
	AutoRoll.showAdvanced(true)
	assert(refs.advanced.Visible and #refs.advancedList:GetChildren() > 3, "panneau Avancé vide")
	AutoRoll.showAdvanced(false)
	Menus.close("AutoRoll")
	assert(not refs.root.Visible, "fenêtre AUTO non fermée")
	for _, key in { "Pass_Roll2", "Pass_AutoRoll", "Pass_AutoRollPlus" } do
		setAttr(key, nil)
	end
	RollPanel.forceNear(nil)
	local _ = State
	expectNoNewWarnings(before, "machine ROULER")
end)

test("Boucle de la base vue par le client : rouler, collecter, poser une unité", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RollPanel = Harness.require(client.UI.RollPanel)
	local State = Harness.require(client.State)
	local Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	local data = services.DataService:Get(alice)
	local rolls = received.RollResult or 0
	-- 1) Rouler depuis le panneau du HUD : le serveur répond par RollResult (révélation).
	-- (la machine du serveur peut encore recharger après le test précédent : on réessaie)
	for _ = 1, 15 do
		RollPanel.roll()
		task.wait(0.3)
		if (received.RollResult or 0) > rolls then
			break
		end
	end
	assert((received.RollResult or 0) > rolls, "pas de RollResult reçu après le roulage")
	assert(#data.RolledQueue >= 1, "rien sur l'estrade")
	task.wait(0.3)
	assert(State.data and #State.data.RolledQueue >= 1, "l'estrade n'est pas synchronisée côté client")
	-- 2) Collecter le 1er perso de l'estrade (le tout premier est offert).
	local owned = 0
	for _ in data.characters do
		owned += 1
	end
	-- Le bouton « Collecter » de la carte du perso tiré envoie la CLÉ du perso (pas sa position).
	local firstKey = State.data.RolledQueue[1].key
	data.RolledQueue[1].rarity = "common" -- la collecte offerte ne vaut que jusqu'au Rare
	local takeButton = nil
	for _, d in alice.PlayerGui.AnimeTycoonUI:GetDescendants() do
		if d.Name == "Tire1" then
			for _, b in d:GetDescendants() do
				if b:IsA("TextButton") then
					takeButton = b
					break
				end
			end
		end
	end
	assert(takeButton, "bouton « Collecter » absent de la carte du perso tiré")
	signalFor(takeButton, "Activated"):Fire()
	task.wait(0.3)
	local ok = true
	for _, item in data.RolledQueue do
		if item.key == firstKey then
			ok = false
		end
	end
	assert(ok, "collecte refusée")
	local after = 0
	for _ in data.characters do
		after += 1
	end
	assert(after == owned + 1, "le perso collecté n'a pas été ajouté")
	task.wait(3.5)
	-- 3) « Remplacer l'unité » : le serveur ouvre le menu, on choisit une carte.
	Remotes.event("OpenMenu"):FireClient(alice, "PlaceUnit", { slot = 2 })
	task.wait(0.2)
	assert(Menus.current() == "PlaceUnit", "le menu PlaceUnit ne s'est pas ouvert")
	local root = alice.PlayerGui.AnimeTycoonUI:FindFirstChild("WindowRoot_EMPLACEMENT")
	assert(root, "fenêtre EMPLACEMENT absente")
	local card = nil
	for _, d in root:GetDescendants() do
		if d.Name == "Card" and d:IsA("TextButton") then
			card = d
			break
		end
	end
	assert(card, "aucune carte d'unité dans le menu PlaceUnit")
	signalFor(card, "Activated"):Fire()
	task.wait(0.3)
	assert(data.DisplayPins["2"] ~= nil, "l'unité n'a pas été posée sur la case 2")
	assert(Menus.current() ~= "PlaceUnit", "le menu devrait se fermer après le choix")
	-- 4) Libérer la case.
	assert(services.PlotService:PlaceUnit(alice, 2, nil), "libération refusée")
	assert(data.DisplayPins["2"] == false, "case non libérée")
	assert(services.CharacterService:GetDisplayed(alice)[2] == nil, "la case libérée a été reremplie")
	-- Le menu ne se reconstruit pas à chaque synchro si rien n'a changé.
	-- (on attend d'abord la synchro groupée de la libération : 0,25 s côté serveur ; l'XP passive
	-- des unités exposées est suspendue le temps du contrôle : un niveau gagné change VRAIMENT
	-- les cartes, et la grille doit alors être reconstruite)
	local addXP = services.CharacterService.AddXP
	services.CharacterService.AddXP = function() end
	task.wait(0.5)
	Remotes.event("OpenMenu"):FireClient(alice, "PlaceUnit", { slot = 2 })
	task.wait(0.4)
	local firstGrid = nil
	for _, d in root:GetDescendants() do
		if d.Name == "Card" and d:IsA("TextButton") then
			firstGrid = d
			break
		end
	end
	assert(firstGrid, "aucune carte après réouverture")
	services.DataService:Sync(alice)
	task.wait(0.5)
	local okAlive, gridParent = pcall(function()
		return firstGrid.Parent
	end)
	services.CharacterService.AddXP = addXP
	assert(okAlive and gridParent ~= nil, "la grille a été reconstruite sans changement")
	Menus.close("PlaceUnit")
	assert(services.PlotService:PlaceUnit(alice, 2, "auto"), "remplissage auto refusé")
	-- 5) Options : couper la secousse d'écran.
	Menus.open("Options")
	task.wait(0.1)
	local Options = Harness.require(client.UI.Options)
	Options.set("FxShake", false)
	assert(alice:GetAttribute("FxShake") == false, "réglage FxShake non appliqué")
	Options.set("FxShake", true)
	Menus.close("Options")
	expectNoNewWarnings(before, "boucle de la base")
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

test("Effets signature : 40 persos (normal + spéciale), boss, nettoyage", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local Effects = Harness.require(client.Controllers.Effects)
	local AttackFx = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.AttackFx"))
	local Characters = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	-- Chaque perso jouable a un effet signature valide, joué par une famille existante.
	local count = 0
	for charId, fxId in AttackFx.Characters do
		local sig = AttackFx.get(fxId)
		assert(sig, "effet inconnu pour " .. charId .. " : " .. tostring(fxId))
		assert(Effects.families[sig.family], "famille sans code : " .. tostring(sig.family))
		count += 1
	end
	assert(count >= 40, "seulement " .. count .. " persos ont un effet signature")
	for _, sig in AttackFx.Signatures do
		assert(Effects.families[sig.family], "famille sans code : " .. tostring(sig.family))
	end
	for kind, fxId in AttackFx.Kinds do
		assert(AttackFx.get(fxId), "type d'attaque " .. kind .. " sans effet")
	end
	-- L'attribut AttackFx est posé sur les persos.
	local follower = nil
	for _, model in workspaceService.Followers:GetChildren() do
		follower = model
	end
	assert(follower, "aucun perso actif")
	assert(type(follower:GetAttribute("AttackFx")) == "string", "attribut AttackFx absent")
	local enemy = Harness.CollectionService:GetTagged("Enemy")[1]
	assert(enemy, "aucun ennemi")

	-- Horloge simulée : on joue chaque effet en entier, image par image.
	local clock = 0
	Effects.setClock(function()
		return clock
	end)
	local function run(seconds)
		for _ = 1, math.ceil(seconds * 20) do
			clock += 1 / 20
			Harness.services.RunService.RenderStepped:Fire(1 / 20)
		end
	end
	local savedCamera = camera.CFrame
	local p = enemy.PrimaryPart.CFrame.Position
	camera.CFrame = CFrame.new(p + Vector3.new(0, 20, 40), p)
	local ids = {}
	for id in AttackFx.Signatures do
		table.insert(ids, id)
	end
	table.sort(ids)
	local peak = 0
	for _, fxId in ids do
		follower:SetAttribute("AttackFx", fxId)
		for _, special in { false, true } do
			Effects.handle("Hit", {
				position = p,
				amount = 4321,
				crit = not special,
				special = special,
				kind = "punch",
				color = Color3.new(1, 0.5, 0),
				from = follower.PrimaryPart.CFrame.Position,
				attacker = follower,
				target = enemy,
				owner = alice.UserId,
			})
			run(special and 1.6 or 0.4)
			peak = math.max(peak, Effects.stats().parts)
		end
	end
	-- Attaques de zone de chaque boss + coups de boss.
	local savedName, savedBoss = enemy:GetAttribute("DisplayName"), enemy:GetAttribute("Boss")
	enemy:SetAttribute("Boss", true)
	for bossId in AttackFx.Bosses do
		local def = Characters.Enemies[bossId]
		enemy:SetAttribute("DisplayName", def and def.name or "?")
		Effects.handle("Slam", { position = p - Vector3.new(0, 3, 0), radius = 20 })
		Effects.handle("EnemyHit", { position = p + Vector3.new(3, 0, 0), from = p, amount = 99 })
		run(1.2)
		peak = math.max(peak, Effects.stats().parts)
	end
	enemy:SetAttribute("DisplayName", savedName)
	enemy:SetAttribute("Boss", savedBoss)
	Effects.handle("Death", { position = p, boss = true })
	-- Qualité réduite (mobile / console) : les effets tournent encore.
	Effects.setOption("FxQuality", "low")
	assert(Effects.stats().quality == "low", "qualité non appliquée")
	follower:SetAttribute("AttackFx", "hollow_purple")
	Effects.handle("Hit", { position = p, amount = 1, special = true, attacker = follower, target = enemy, owner = alice.UserId })
	Effects.setOption("FxShake", false)
	Effects.setOption("FxFlash", false)
	Effects.handle("Hit", { position = p, amount = 1, special = true, attacker = follower, target = enemy, owner = alice.UserId })
	run(4)
	Effects.setOption("FxQuality", "auto")
	Effects.setOption("FxShake", true)
	Effects.setOption("FxFlash", true)
	-- Tout est nettoyé une fois les effets terminés.
	run(4)
	Effects.sweep()
	local stats = Effects.stats()
	print(string.format("   pic de pièces d'effet : %d ; restantes : %d ; animations : %d ; interrompues : %d", peak, stats.parts, stats.jobs, stats.dropped))
	assert(stats.parts == 0, stats.parts .. " pièces d'effet non nettoyées")
	assert(stats.jobs == 0, stats.jobs .. " animations encore actives")
	assert(stats.lights == 0, stats.lights .. " lumières non libérées")
	assert(peak <= 700, "trop de pièces simultanées : " .. peak)
	follower:SetAttribute("AttackFx", AttackFx.forCharacter(nil, "punch"))
	camera.CFrame = savedCamera
	Effects.setClock(nil)
	expectNoNewWarnings(before, "effets signature")
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

test("Boutique Robux : onglets, barre de droite, achat simulé", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RobuxShop = Harness.require(client.UI.RobuxShop)
	local HUD = Harness.require(client.UI.HUD)
	local gui = alice.PlayerGui.AnimeTycoonUI
	local function frames(n)
		for _ = 1, n do
			Harness.services.RunService.RenderStepped:Fire(1 / 60)
		end
	end
	local bar = gui:FindFirstChild("RobuxSideBar", true)
	assert(bar and bar:FindFirstChild("Offer_Coins2") and bar:FindFirstChild("OpenShop"), "barre de droite absente")
	-- Le bouton « Boutique » du HUD ouvre la boutique Robux.
	local found = false
	for _, info in HUD.Tiles do
		found = found or (info.text == "Boutique" and info.menu == "RobuxShop")
	end
	assert(found, "la tuile Boutique n'ouvre pas la boutique Robux")
	Menus.open("RobuxShop", "passes")
	task.wait(0.3)
	frames(10)
	local root = gui:FindFirstChild("WindowRoot_BOUTIQUE ROBUX")
	assert(root and root.Visible, "boutique Robux non ouverte")
	for _, key in { "AutoRollPlus", "Roll2", "Roll3", "Coins2", "Luck2", "AutoRoll", "Slots", "VIP" } do
		assert(root:FindFirstChild("Pass_" .. key, true), "carte manquante : " .. key)
	end
	assert(root:FindFirstChild("Pack_Starter", true), "carte « Pack de départ » absente")
	-- Boutique ouverte : HUD caché, voile sombre, indications manette sur une pastille sombre.
	assert(HUD.root() and not HUD.root().Visible, "le HUD reste visible derrière la boutique")
	local dim = root:FindFirstChild("Dim")
	assert(dim and dim.Visible and dim.Active, "pas de voile derrière la boutique") -- (fondu : tween)
	local hints = root:FindFirstChild("PadHints", true)
	assert(hints and hints.BackgroundTransparency < 0.5, "indications manette sans fond")
	RobuxShop.render("packs")
	assert(root:FindFirstChild("Pack_CoinsXL", true) and root:FindFirstChild("Pack_GemsL", true), "onglet Packs")
	RobuxShop.render("boosts")
	frames(40)
	assert(root:FindFirstChild("Boost_BoostCombo", true), "onglet Boosts")
	Menus.close()
	assert(HUD.root().Visible and bar.Visible, "HUD ou barre de droite non revenus après la boutique")
	-- Une autre fenêtre : la barre du bas, la bannière d'univers et la barre Robux se cachent.
	Menus.open("Options")
	task.wait(0.1)
	assert(HUD.root().Visible and not bar.Visible, "barre Robux visible sous une fenêtre")
	local banner = HUD.root():FindFirstChild("UniverseBanner")
	local travel = HUD.root():FindFirstChild("Travel")
	assert(banner and not banner.Visible and travel and not travel.Visible, "bannière ou barre du bas visibles sous une fenêtre")
	Menus.close()
	assert(bar.Visible and banner.Visible and travel.Visible, "HUD non rétabli après la fenêtre")
	-- Achat (simulé dans Studio) directement depuis la barre de droite.
	signalFor(bar:FindFirstChild("Offer_Coins2"), "Activated"):Fire()
	task.wait(0.3)
	assert(alice:GetAttribute("Pass_Coins2") == true, "achat simulé non accordé")
	frames(45)
	assert(not bar:FindFirstChild("Offer_Coins2"), "un passe possédé est encore proposé")
	expectNoNewWarnings(before, "boutique Robux")
end)

test("Annonces en bandeau pendant un menu, boutique ouverte par le serveur", function()
	local before = #warnings
	local Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	local gui = alice.PlayerGui.AnimeTycoonUI
	-- Le serveur demande la boutique (passe manquant) : elle s'ouvre sur les passes.
	Menus.close()
	signalFor(Remotes.event("Robux_OpenShop"), "OnClientEvent"):Fire("passes", "AutoRoll")
	task.wait(0.2)
	local root = gui:FindFirstChild("WindowRoot_BOUTIQUE ROBUX")
	assert(root and root.Visible and Menus.current() == "RobuxShop", "boutique non ouverte par Robux_OpenShop")
	-- Une annonce pendant la boutique : petit bandeau en haut, jamais par-dessus la fenêtre.
	signalFor(Remotes.event("Announce"), "OnClientEvent"):Fire("BANDEAU TEST", "pendant un menu", Color3.new(1, 0, 0))
	local announce = gui:FindFirstChild("Announce", true)
	assert(announce, "cadre d'annonce absent")
	local title = announce:FindFirstChild("Title")
	local waited = 0
	while not (announce.Visible and title.Text == "BANDEAU TEST") and waited < 14 do
		task.wait(0.25)
		waited += 0.25
	end
	assert(title.Text == "BANDEAU TEST", "annonce jamais affichée")
	assert(announce.Position.Y.Scale == 0 and announce.Position.Y.Offset <= 60, "annonce au centre pendant un menu")
	Menus.close()
	task.wait(0.1)
	if announce.Visible then
		assert(announce.Position.Y.Scale > 0.2, "l'annonce ne revient pas au centre après le menu")
	end
	expectNoNewWarnings(before, "annonces")
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
	if realIndexAt then
		services.UniverseService.IndexAt = realIndexAt
	end
	services.UniverseService:Skip()
	task.wait(2.8)
	for _ = 1, 5 do
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
	end
	expectNoNewWarnings(before, "rotation")
end)

print(string.format("   %d avertissement(s) au total", #warnings))
test("Révélation À LA MACHINE : pas de vignettes, la caméra cadre le podium (Légendaire et plus)", function()
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RollPanel = Harness.require(client.UI.RollPanel)
	local RollReveal = Harness.require(client.UI.RollReveal)
	camera.CameraType = roblox.Enum.CameraType.Custom
	RollPanel.forceNear(true)
	RollReveal.show({ results = { { id = "ninja_itochi", stars = 1, rarity = "mythic", aura = "diamant", price = 10, dps = 5 } }, count = 1 })
	task.wait(0.1)
	local strip = alice.PlayerGui:FindFirstChild("Strip", true)
	local cards = strip and strip:FindFirstChild("Cards")
	assert(cards and not cards.Visible and #cards:GetChildren() <= 1, "vignettes affichées à la machine")
	assert(strip:FindFirstChild("Mutation"), "bandeau MUTATION absent")
	assert(camera.CameraType == roblox.Enum.CameraType.Scriptable, "la caméra ne cadre pas le podium")
	local t0 = os.clock()
	while camera.CameraType == roblox.Enum.CameraType.Scriptable and os.clock() - t0 < 8 do
		task.wait(0.1)
	end
	print(string.format("   caméra rendue après %.2f s", os.clock() - t0))
	assert(camera.CameraType == roblox.Enum.CameraType.Custom, "caméra non rendue au joueur")
	-- Un Commun ne bouge pas la caméra.
	RollReveal.show({ results = { { id = "ninja_rokli", stars = 1, rarity = "common", price = 10, dps = 5 } }, count = 1 })
	task.wait(0.1)
	assert(camera.CameraType == roblox.Enum.CameraType.Custom, "caméra déplacée pour un Commun")
	RollPanel.forceNear(nil)
	task.wait(3)
end)

Harness.finish()
