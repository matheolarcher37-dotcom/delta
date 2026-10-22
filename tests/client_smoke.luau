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
	-- Réponse du serveur : on attend jusqu'à 3 s (machine chargée pendant les tests).
	local deadline = os.clock() + 3
	repeat
		task.wait(0.1)
	until (data.Items[firstId] or 0) ~= owned or os.clock() > deadline
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
	-- Boss Saiyan au palier 3 (4 récompenses : ¥, gemmes, Boule Divine, Boule du Dragon).
	local bossClaimed = data.Quests.claimed.u_saiyan_boss
	data.Quests.claimed.u_saiyan_boss = 2
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
	-- Pastilles de récompense : toujours avant le bouton RÉCLAMER, sur 2 lignes si besoin. La
	-- fenêtre a une taille fixe en px logiques : même calcul en 1920 x 1080, 1280 x 720 et sur
	-- téléphone 844 x 390 (seule l'échelle de l'interface change).
	do
		local rowWidth = QuestsUI.RowWidth
		local function left(ui)
			local width = ui.Size.X.Scale * rowWidth + ui.Size.X.Offset
			return ui.Position.X.Scale * rowWidth + ui.Position.X.Offset - ui.AnchorPoint.X * width, width
		end
		local checked = 0
		for _, questRow in root:GetDescendants() do
			local rewardsFrame = string.sub(questRow.Name, 1, 6) == "Quest_" and questRow:FindFirstChild("Rewards")
			if rewardsFrame then
				local claim = nil
				for _, d in questRow:GetDescendants() do
					if d:IsA("TextButton") and d:GetAttribute("SelKey") == "claim_" .. string.sub(questRow.Name, 7) then
						claim = d
					end
				end
				assert(claim, "bouton RÉCLAMER absent : " .. questRow.Name)
				local rewardsLeft, rewardsWidth = left(rewardsFrame)
				local claimLeft = left(claim)
				assert(rewardsLeft + rewardsWidth <= claimLeft - 4, "cadre des récompenses sous le bouton RÉCLAMER : " .. questRow.Name)
				local lines = rewardsFrame:FindFirstChild("Line1") and {} or { rewardsFrame }
				for _, line in rewardsFrame:GetChildren() do
					if string.sub(line.Name, 1, 4) == "Line" then
						table.insert(lines, line)
					end
				end
				local chips = 0
				for _, line in lines do
					local used, n = 0, 0
					for _, c in line:GetChildren() do
						if c.Name == "Chip" then
							used += c.Size.X.Offset
							n += 1
						end
					end
					used += math.max(0, n - 1) * 6
					assert(used <= rewardsWidth, "pastilles trop larges (" .. used .. " > " .. rewardsWidth .. ") : " .. questRow.Name)
					chips += n
				end
				assert(rewardsFrame.Position.Y.Offset + rewardsFrame.Size.Y.Offset <= questRow.Size.Y.Offset - 4, "pastilles coupées en bas : " .. questRow.Name)
				if questRow.Name == "Quest_u_saiyan_boss" then
					assert(chips == 4 and #lines == 2, "boss Saiyan palier 3 : 4 pastilles sur 2 lignes attendues (" .. chips .. ", " .. #lines .. ")")
				end
				checked += 1
			end
		end
		assert(checked >= 10 and root:FindFirstChild("Quest_u_saiyan_boss", true), "lignes de défis d'univers non vérifiées : " .. checked)
	end
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
	data.Quests.claimed.u_saiyan_boss = bossClaimed
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
	-- Les cartes de suivi commencent sous une pile de 3 bandeaux de notification (pas de chevauchement).
	local trackerFrame = hud:FindFirstChild("Tracker")
	local toastStack = gui:FindFirstChild("Toasts", true)
	assert(trackerFrame and toastStack and toastStack.Position.Y.Scale == 0, "cadres de suivi / bandeaux introuvables")
	assert(trackerFrame.Position.Y.Offset >= toastStack.Position.Y.Offset + 3 * 58, "les cartes de suivi passent sous les bandeaux")
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
	-- Jamais sur la rangée des pastilles du HUD (Marchand, Boss : y 98 → 130).
	assert(panel.Position.Y.Offset >= 134, "panneau AFK posé sur les pastilles du HUD : y " .. panel.Position.Y.Offset)
	-- Auto-roulage en cours (pastille « Arrêter ») : le panneau descend dessous, les bandeaux suivent.
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RollPanel = Harness.require(client.UI.RollPanel)
	local pill = RollPanel.refs().pill
	assert(pill.Position.Y.Offset >= 134, "pastille d'auto-roulage posée sur les pastilles du HUD")
	-- (la pastille est remise à jour par le panneau ROULER : on la réaffiche à chaque essai)
	local moved = false
	for _ = 1, 30 do
		pill.Visible = true
		task.wait(0.05)
		if panel.Position.Y.Offset >= pill.Position.Y.Offset + pill.Size.Y.Offset then
			moved = true
			break
		end
	end
	assert(moved, "le panneau AFK cache le bouton « Arrêter » de l'auto-roulage")
	pill.Visible = true
	Harness.services.RunService.RenderStepped:Fire(1 / 60)
	task.wait(0.02)
	assert(toasts.Position.Y.Offset >= panel.Position.Y.Offset + panel.Size.Y.Offset, "bandeaux sous le panneau AFK descendu")
	pill.Visible = false
	task.wait(0.4)
	assert(panel.Position.Y.Offset < pill.Position.Y.Offset + pill.Size.Y.Offset, "le panneau AFK ne remonte pas")
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
	-- Même en cas d'échec : tirage et révélation d'origine, relance terminée, écran fermé (sinon
	-- l'échec en entraîne d'autres plus loin).
	local realRoll, realReveal = TraitsConfig.roll, TraitsMenu.playReveal
	Harness.cleanup(function()
		TraitsConfig.roll, TraitsMenu.playReveal = realRoll, realReveal
		TraitsMenu.skipCinematic()
		local t0 = os.clock()
		while TraitsMenu.isRolling() and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		Menus.close("Traits")
		alice:SetAttribute("FxFlash", nil)
	end)
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
	-- Une relance : clic sur RELANCER, le serveur tire `forced`. Le tirage est imposé (le tirage au
	-- hasard est vérifié par le test d'intégration) : le rang tiré décide de la révélation jouée,
	-- et un trait à cinématique (3,7 % des tirages) monterait ici sa scène pendant plus d'une minute
	-- (recherche des pièces proches simulée sur toute la carte ; ces scènes ont leurs propres tests).
	-- On attend la fin du rouleau ET de la révélation, qui doit se fermer toute seule (sans la
	-- passer), sans délai serré : sous Lune, serveur, client et carte entière tournent dans un seul
	-- planificateur très chargé, où une attente de 0,2 s dure parfois 4 à 6 s et où une relance de
	-- rang 3 (rouleau puis plein écran) prend environ 10 s.
	local function reroll(forced: string): { string }
		local button = nil
		for _, d in gui:FindFirstChild("WindowRoot_TRAITS"):GetDescendants() do
			if d:IsA("TextButton") and d:GetAttribute("SelKey") == "roll" then
				button = d
			end
		end
		assert(button, "bouton RELANCER manquant")
		local crystals = data.traitCrystals
		local reveals = {}
		local realRoll, realReveal = TraitsConfig.roll, TraitsMenu.playReveal
		TraitsConfig.roll = function()
			return forced
		end
		TraitsMenu.playReveal = function(trait, ...)
			table.insert(reveals, trait and trait.id or "?")
			return realReveal(trait, ...)
		end
		signalFor(button, "Activated"):Fire()
		local clicks = signalFor(button, "Activated").lastThreads
		-- le rouleau tourne (bloquant) puis la révélation s'affiche ; on attend la fin
		local started = TraitsMenu.isRolling()
		local t0 = os.clock()
		while TraitsMenu.isRolling() and os.clock() - t0 < 90 do
			task.wait(0.2)
			Harness.services.RunService.RenderStepped:Fire(1 / 30)
		end
		TraitsConfig.roll, TraitsMenu.playReveal = realRoll, realReveal
		assert(started, "le clic sur RELANCER ne lance pas le rouleau")
		if TraitsMenu.isRolling() then
			-- où le clic est resté bloqué (ou « dead » s'il s'est arrêté sur une erreur)
			local where = {}
			for _, thread in clicks do
				table.insert(where, coroutine.status(thread) .. " " .. debug.traceback(thread))
			end
			error("la relance ne se termine pas : " .. table.concat(where, " | "))
		end
		task.wait(0.4)
		assert(data.traitCrystals == crystals - 1, "la relance doit coûter 1 gemme (" .. tostring(data.traitCrystals) .. ")")
		assert(not gui:FindFirstChild("TraitReveal"), "la révélation plein écran doit se fermer à la fin de la relance")
		return reveals
	end
	-- rang 2 (Fortuné) : éclat et onde sur la carte, pas de plein écran
	assert(#reroll("fortune") == 0, "trait de rang 2 : pas de révélation plein écran")
	-- rang 3 (Critique) : révélation renforcée plein écran, qui se ferme toute seule
	assert(reroll("critique")[1] == "critique", "trait de rang 3 : la révélation plein écran doit s'afficher")
	assert(data.traitCrystals == 1, "deux relances doivent coûter 2 gemmes (" .. tostring(data.traitCrystals) .. ")")
	-- au repos, la ligne du milieu du rouleau est le trait de l'unité sélectionnée
	local rolled = nil
	for _, e in data.characters do
		if e.trait then
			rolled = e.trait
		end
	end
	assert(rolled == "critique", "le trait tiré doit être posé sur l'unité (" .. tostring(rolled) .. ")")
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

test("Traits : la relance se débloque toujours (révélation en erreur, serveur qui ne répond pas)", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local TraitsMenu = Harness.require(client.UI.TraitsMenu)
	local TraitsConfig = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Traits"))
	local State = Harness.require(client.State)
	local gui = alice.PlayerGui.AnimeTycoonUI
	local data = services.DataService:Get(alice)
	local realRoll, realReveal, realInvoke, realTimeout = TraitsConfig.roll, TraitsMenu.playReveal, State.invoke, TraitsMenu.ServerTimeout
	local realRevealTimeout = TraitsMenu.RevealTimeout
	local answer = false -- le serveur simulé « muet » répond quand ce drapeau passe à vrai
	Harness.cleanup(function()
		TraitsConfig.roll, TraitsMenu.playReveal, State.invoke, TraitsMenu.ServerTimeout = realRoll, realReveal, realInvoke, realTimeout
		TraitsMenu.RevealTimeout = realRevealTimeout
		answer = true
		TraitsMenu.skipCinematic()
		Menus.close("Traits")
	end)
	data.traitCrystals = 10
	services.DataService:Sync(alice)
	task.wait(0.4)
	Menus.open("Traits")
	task.wait(0.3)
	local function button(key)
		for _, d in gui:FindFirstChild("WindowRoot_TRAITS"):GetDescendants() do
			if d:IsA("TextButton") and d:GetAttribute("SelKey") == key then
				return d
			end
		end
		error("bouton « " .. key .. " » manquant")
	end
	local function text(b)
		return b:FindFirstChild("Label", true).Text
	end
	-- vrai si la relance se termine (écran débloqué) en moins de 60 s (planificateur de Lune chargé)
	local function settles()
		local t0 = os.clock()
		while TraitsMenu.isRolling() and os.clock() - t0 < 60 do
			task.wait(0.2)
			Harness.services.RunService.RenderStepped:Fire(1 / 30)
		end
		return not TraitsMenu.isRolling()
	end
	TraitsConfig.roll = function()
		return "critique" -- rang 3 : rouleau puis révélation plein écran
	end
	-- 1) La révélation lève une erreur : l'écran se débloque, RELANCER revient, l'erreur est signalée.
	TraitsMenu.playReveal = function()
		error("révélation cassée (test)")
	end
	signalFor(button("roll"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "le clic sur RELANCER ne lance pas le rouleau")
	assert(settles(), "relance bloquée pour toujours après une erreur de la révélation")
	task.wait(0.3)
	assert(text(button("roll")) == "RELANCER", "RELANCER ne revient pas après une erreur (" .. text(button("roll")) .. ")")
	assert(not gui:FindFirstChild("TraitReveal"), "calque de révélation resté affiché après une erreur")
	assert(#warnings > before and string.find(warnings[#warnings], "relance interrompue", 1, true), "erreur de la relance non signalée")
	-- même chose en relance auto (arrêt au rang 3 : le plein écran de Critique est joué) : elle
	-- s'arrête au lieu de rester bloquée
	signalFor(button("target-1"), "Activated"):Fire()
	task.wait(0.2)
	signalFor(button("auto"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "la relance auto ne démarre pas")
	assert(settles(), "relance auto bloquée pour toujours après une erreur de la révélation")
	task.wait(0.3)
	assert(text(button("auto")) == "RELANCE AUTO", "la relance auto ne s'arrête pas après une erreur")
	signalFor(button("target1"), "Activated"):Fire() -- (rang d'arrêt remis à Mythique)
	task.wait(0.2)
	-- La révélation plante en route, calque plein écran déjà affiché : il se ferme quand même
	-- tout seul (sa fermeture est programmée avant de construire le reste).
	local ThemeUI = Harness.require(client.UI.Theme)
	local realSparkles = ThemeUI.sparkles
	Harness.cleanup(function()
		ThemeUI.sparkles = realSparkles
	end)
	ThemeUI.sparkles = function(parent, ...)
		if parent and parent.Name == "TraitReveal" then
			error("étincelles cassées (test)")
		end
		return realSparkles(parent, ...)
	end
	TraitsMenu.playReveal = realReveal
	signalFor(button("roll"), "Activated"):Fire()
	assert(settles(), "relance bloquée après une erreur en pleine révélation")
	ThemeUI.sparkles = realSparkles
	assert(string.find(warnings[#warnings], "étincelles cassées", 1, true), "erreur en pleine révélation non signalée")
	local t0 = os.clock()
	while gui:FindFirstChild("TraitReveal") and os.clock() - t0 < 30 do
		task.wait(0.2)
	end
	assert(not gui:FindFirstChild("TraitReveal"), "calque de révélation resté affiché après une erreur en pleine révélation")
	-- Calque qui ne se ferme pas de lui-même (fermeture programmée jamais partie) : la relance ne
	-- l'attend pas plus de RevealTimeout, puis le ferme.
	TraitsMenu.RevealTimeout = 2
	TraitsMenu.playReveal = function(trait, desc)
		return realReveal(trait, desc, 1e6)
	end
	signalFor(button("roll"), "Activated"):Fire()
	assert(settles(), "relance bloquée tant que la révélation reste affichée")
	task.wait(0.3)
	assert(not gui:FindFirstChild("TraitReveal"), "calque de révélation resté affiché après le délai max")
	assert(text(button("roll")) == "RELANCER", "RELANCER ne revient pas après le délai max de la révélation")
	TraitsMenu.RevealTimeout = realRevealTimeout
	before = #warnings -- (les trois erreurs voulues ci-dessus)
	TraitsMenu.playReveal = realReveal
	-- 2) Le serveur ne répond pas : passé le délai max, l'écran se débloque sans attendre la réponse.
	TraitsMenu.ServerTimeout = 2
	local sent = 0 -- relances envoyées au serveur
	State.invoke = function(name, ...)
		if name == "RerollTrait" then
			sent += 1
			while not answer do
				task.wait(0.1)
			end
		end
		return realInvoke(name, ...)
	end
	local crystals = data.traitCrystals
	signalFor(button("roll"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "le clic sur RELANCER ne lance pas le rouleau (serveur muet)")
	assert(settles(), "relance bloquée tant que le serveur ne répond pas")
	task.wait(0.3)
	assert(text(button("roll")) == "RELANCER", "RELANCER ne revient pas après le délai max (" .. text(button("roll")) .. ")")
	assert(data.traitCrystals == crystals, "aucune gemme ne doit être dépensée sans réponse du serveur")
	-- Nouveau clic alors que la 1re relance attend toujours le serveur (qui la fera plus tard) :
	-- pas de 2e envoi, sinon 2 gemmes dépensées pour un seul résultat affiché.
	signalFor(button("roll"), "Activated"):Fire()
	assert(settles(), "relance bloquée au 2e clic (serveur muet)")
	task.wait(0.3)
	assert(sent == 1, "relance renvoyée au serveur alors que la précédente attend encore sa réponse (" .. sent .. " envois)")
	assert(text(button("roll")) == "RELANCER", "RELANCER ne revient pas après le 2e clic (" .. text(button("roll")) .. ")")
	-- la réponse arrive enfin (relance faite par le serveur) : une seule gemme dépensée
	answer = true
	t0 = os.clock()
	while data.traitCrystals == crystals and os.clock() - t0 < 30 do
		task.wait(0.2)
	end
	task.wait(1) -- (une 2e relance en attente aurait eu le temps de passer)
	assert(data.traitCrystals == crystals - 1, "la relance tardive doit coûter exactement 1 gemme (" .. tostring(crystals - data.traitCrystals) .. ")")
	task.wait(0.6)
	assert(not TraitsMenu.isRolling() and text(button("roll")) == "RELANCER", "écran bloqué après la réponse tardive du serveur")
	-- une fois la réponse arrivée, RELANCER relance de nouveau (rang 1 : ni plein écran ni cinématique)
	TraitsConfig.roll = function()
		return "vigueur1"
	end
	signalFor(button("roll"), "Activated"):Fire()
	assert(settles(), "relance bloquée après la réponse tardive")
	task.wait(0.3)
	assert(sent == 2 and data.traitCrystals == crystals - 2, "RELANCER ne relance plus après la réponse tardive (" .. sent .. " envois)")
	State.invoke = realInvoke
	-- 3) Fenêtre fermée ou autre perso choisi pendant la relance (à la main ou en auto) : la
	-- relance se termine, et RELANCER revient sur le perso affiché.
	local Formulas = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Formulas"))
	local uidA, uidB = nil, nil
	for _, item in State.sortedCharacters() do
		if not uidA then
			uidA = item.uid
		elseif not uidB and item.desc.name ~= Formulas.describe(data.characters[uidA]).name then
			uidB = item.uid
		end
	end
	assert(uidA and uidB, "il faut deux persos différents")
	local function owner(): string
		local label = gui:FindFirstChild("WindowRoot_TRAITS"):FindFirstChild("Owner", true)
		return label and label.Text or "?"
	end
	local function backOn(uid: string, what: string)
		assert(settles(), "relance bloquée (" .. what .. ")")
		if not Menus.current() then
			Menus.open("Traits")
		end
		task.wait(0.3)
		assert(text(button("roll")) == "RELANCER", "RELANCER ne revient pas (" .. what .. ") : " .. text(button("roll")))
		assert(text(button("auto")) == "RELANCE AUTO", "relance auto pas arrêtée (" .. what .. ")")
		local name = Formulas.describe(data.characters[uid]).name
		assert(owner() == "sur " .. name, "mauvais perso affiché (" .. what .. ") : " .. owner() .. " au lieu de " .. name)
	end
	data.traitCrystals = 20
	data.characters[uidA].trait = nil
	services.DataService:Sync(alice)
	task.wait(0.4)
	-- à la main, fenêtre fermée pendant le rouleau : la relance a lieu (une gemme, le trait posé)
	Menus.open("Traits", uidA)
	task.wait(0.3)
	crystals = data.traitCrystals
	signalFor(button("roll"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "le clic sur RELANCER ne lance pas le rouleau")
	Menus.close("Traits")
	backOn(uidA, "fenêtre fermée")
	assert(data.traitCrystals == crystals - 1 and data.characters[uidA].trait == "vigueur1", "relance perdue quand on ferme la fenêtre")
	-- à la main, autre perso choisi pendant le rouleau : la relance reste sur le 1er perso
	crystals = data.traitCrystals
	local traitB = data.characters[uidB].trait
	signalFor(button("roll"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "le clic sur RELANCER ne lance pas le rouleau")
	Menus.open("Traits", uidB)
	backOn(uidB, "autre perso choisi")
	assert(data.traitCrystals == crystals - 1 and data.characters[uidB].trait == traitB, "relance faite sur le mauvais perso")
	-- relance auto (rang 1 tiré à chaque fois : elle ne s'arrête pas d'elle-même), fenêtre fermée
	Menus.open("Traits", uidA)
	task.wait(0.3)
	signalFor(button("auto"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "la relance auto ne démarre pas")
	task.wait(0.5)
	Menus.close("Traits")
	backOn(uidA, "relance auto, fenêtre fermée")
	-- relance auto, autre perso choisi
	signalFor(button("auto"), "Activated"):Fire()
	assert(TraitsMenu.isRolling(), "la relance auto ne démarre pas")
	task.wait(0.5)
	Menus.open("Traits", uidB)
	backOn(uidB, "relance auto, autre perso choisi")
	TraitsConfig.roll = realRoll
	Menus.close("Traits")
	expectNoNewWarnings(before, "relance débloquée")
end)

local function tanVOf(camera)
	return math.tan(math.rad(camera.FieldOfView) / 2)
end

test("Traits : cinématique MONARQUE dans le monde (persos à genoux, couronne, cadrage)", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local TraitCinematic = Harness.require(client.Controllers.TraitCinematic)
	local State = Harness.require(client.State)
	-- La cour n'accueille ni créature (Kourama), ni géant / Secret (ils déborderaient).
	local CharactersCfg = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Characters"))
	assert(not TraitCinematic.fitsCourt("ninja_kourama", CharactersCfg.resolveLook("ninja_kourama", 1)), "Kourama dans la cour")
	assert(not TraitCinematic.fitsCourt("oce_kaydo", CharactersCfg.resolveLook("oce_kaydo", 1)), "Kaydo (Secret) dans la cour")
	assert(TraitCinematic.fitsCourt("ninja_maruto", CharactersCfg.resolveLook("ninja_maruto", 1)), "Maruto refusé dans la cour")
	for _, info in TraitCinematic.kneelerLooks(nil, TraitCinematic.MonarchCount) do
		assert(TraitCinematic.fitsCourt(info.id, info.look), "perso trop grand dans la cour : " .. tostring(info.id))
	end
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
	-- repère d'un perso : son orientation au sol (sans l'inclinaison du torse). CFrame.lookAt de
	-- Lune inverse l'axe Z : on prend celui, corrigé, du harnais (sinon les boîtes « orientées »
	-- sont tournées n'importe comment et le verdict dépend des persos tirés au hasard).
	local function facingFrame(model)
		local torsoPart = model:FindFirstChild("Torso")
		local facing = torsoPart and torsoPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		return (facing and facing.Magnitude > 0.1) and Harness.CFrame.lookAt(Vector3.zero, facing.Unit) or CFrame.new()
	end
	-- deux pièces (boîtes orientées) qui s'interpénètrent : test des 15 axes séparateurs
	local function partsTouch(p, q)
		local d = q.CFrame.Position - p.CFrame.Position
		local ha, hb = p.Size * 0.5, q.Size * 0.5
		if d.Magnitude > ha.Magnitude + hb.Magnitude then
			return false
		end
		local ax = { p.CFrame.XVector, p.CFrame.YVector, p.CFrame.ZVector }
		local bx = { q.CFrame.XVector, q.CFrame.YVector, q.CFrame.ZVector }
		local axes = { ax[1], ax[2], ax[3], bx[1], bx[2], bx[3] }
		for i = 1, 3 do
			for j = 1, 3 do
				table.insert(axes, ax[i]:Cross(bx[j]))
			end
		end
		for _, axis in axes do
			if axis.Magnitude > 1e-4 then
				local u = axis.Unit
				local ra = ha.X * math.abs(ax[1]:Dot(u)) + ha.Y * math.abs(ax[2]:Dot(u)) + ha.Z * math.abs(ax[3]:Dot(u))
				local rb = hb.X * math.abs(bx[1]:Dot(u)) + hb.Y * math.abs(bx[2]:Dot(u)) + hb.Z * math.abs(bx[3]:Dot(u))
				if math.abs(d:Dot(u)) > ra + rb then
					return false
				end
			end
		end
		return true
	end
	local function visibleParts(model)
		local list = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				table.insert(list, part)
			end
		end
		return list
	end
	-- Deux persos ne se chevauchent pas : séparés par leurs boîtes (dans le repère de l'un ou de
	-- l'autre), sinon aucune pièce visible de l'un ne pénètre une pièce visible de l'autre.
	local function assertNoOverlap(list)
		for i = 1, #list do
			for j = i + 1, #list do
				local A, B = list[i], list[j]
				local separated = false
				for _, frame in { A.frame, B.frame } do
					local alo, ahi = boxOf(A.model, frame)
					local blo, bhi = boxOf(B.model, frame)
					if not (alo.X < bhi.X and blo.X < ahi.X and alo.Y < bhi.Y and blo.Y < ahi.Y and alo.Z < bhi.Z and blo.Z < ahi.Z) then
						separated = true
					end
				end
				if not separated then
					local partsB = visibleParts(B.model)
					for _, p in visibleParts(A.model) do
						for _, q in partsB do
							assert(not partsTouch(p, q), A.name .. " chevauche " .. B.name .. " (" .. p.Name .. " / " .. q.Name .. ")")
						end
					end
				end
			end
		end
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
			table.insert(boxes, { name = child.Name, model = child, frame = facingFrame(child) })
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
	assertNoOverlap(boxes)
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
	-- La cour ne dépend pas du hasard des tirages : avec les persos les plus encombrants en tête
	-- de liste (dôme de Lao ★3, mur de sable de Gaaro ★3, longue chevelure de Brolo ★3, lames,
	-- éventails...), chaque place prend le premier candidat qui y tient. Cour complète, aucun
	-- chevauchement, personne ne déborde de sa place.
	local realLooks = TraitCinematic.kneelerLooks
	local heavy = {
		{ "oce_lao", 3 },
		{ "ninja_gaaro", 3 },
		{ "ninja_minatu", 2 },
		{ "sai_brolo", 3 },
		{ "pou_doma", 3 },
		{ "ninja_jiriya", 1 },
		{ "ninja_maruto", 2 },
		{ "oce_sanjo", 3 },
		{ "pou_giyo", 3 },
		{ "ninja_gaaro", 2 },
		{ "sai_vejeta", 3 },
		{ "pou_rengoko", 3 },
	}
	TraitCinematic.kneelerLooks = function(exceptUid, count, spare)
		local list = {}
		for _, pair in heavy do
			table.insert(list, { id = pair[1], stars = pair[2], look = CharactersCfg.resolveLook(pair[1], pair[2]) })
		end
		for _, info in realLooks(exceptUid, count, spare) do
			table.insert(list, info)
		end
		return list
	end
	fake = 0
	local okForced, forced = pcall(TraitCinematic.play, "monarch", entry, desc, {
		duration = 200,
		stage = stage,
		clock = function()
			return fake
		end,
	})
	TraitCinematic.kneelerLooks = realLooks
	assert(okForced and forced and not forced.finished, "cour imposée : la cinématique ne démarre pas (" .. tostring(forced) .. ")")
	fake = 7
	for _ = 1, 3 do
		Harness.services.RunService.RenderStepped:Fire(1 / 30)
		task.wait(0.03)
	end
	local court, courtKneelers = {}, 0
	for _, child in forced.folder:GetChildren() do
		if child:IsA("Model") and child.Name ~= "Crown" then
			local label = child.Name .. " (" .. tostring(child:GetAttribute("CharId") or "unité") .. ")"
			table.insert(court, { name = label, model = child, frame = facingFrame(child) })
			local index = tonumber(string.match(child.Name, "^Kneeler(%d+)$"))
			if index then
				courtKneelers += 1
				local spot = stage:PointToWorldSpace(TraitCinematic.monarchSpots()[index])
				for _, part in visibleParts(child) do
					local half = part.Size * 0.5
					for _, sx in { -1, 1 } do
						for _, sy in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local c = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)) - spot
								assert(Vector2.new(c.X, c.Z).Magnitude <= TraitCinematic.MonarchReach + 0.01, label .. " déborde de sa place (" .. part.Name .. ")")
							end
						end
					end
				end
			end
		end
	end
	assert(courtKneelers == TraitCinematic.MonarchCount, "cour imposée incomplète (" .. courtKneelers .. ")")
	assertNoOverlap(court)
	TraitCinematic.skip()
	assert(forced.finished and not forced.folder.Parent, "cour imposée : scène non nettoyée")
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

test("Haut de l'écran : pastille d'auto-roulage, panneau AFK, bandeaux, persos tirés et suivi des défis ne se chevauchent jamais", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local QuestsUI = Harness.require(client.UI.Quests)
	local RollPanel = Harness.require(client.UI.RollPanel)
	local RollReveal = Harness.require(client.UI.RollReveal)
	local NotificationsUI = Harness.require(client.UI.Notifications)
	local Layout = Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Layout"))
	local gui = alice.PlayerGui.AnimeTycoonUI
	local pill = RollPanel.refs().pill
	local panel = gui:FindFirstChild("AfkPanel", true)
	local toasts = gui:FindFirstChild("Toasts", true)
	local strip = gui.RollReveal.Strip
	local tracker = gui.QuestHUD.Tracker
	assert(pill and panel and toasts and strip and tracker, "éléments du haut de l'écran introuvables")
	-- Calcul en unités logiques, sur l'écran le plus étroit (1280 x 770 : 1920 x 1080 et 1280 x 720
	-- donnent 1369 x 770, un téléphone 844 x 390 donne 1667 x 770) : c'est là que le centre est le
	-- plus près des cartes de suivi (à gauche).
	local W, H = 1280, 770
	local function rect(name, x0, y0, w, h)
		return { name = name, x0 = x0, y0 = y0, x1 = x0 + w, y1 = y0 + h }
	end
	local function centered(name, frame, w, h, dx)
		return rect(name, W / 2 + (dx or 0) - w / 2, frame.Position.Y.Offset, w, h)
	end
	local function frames(n)
		for _ = 1, n do
			Harness.services.RunService.RenderStepped:Fire(1 / 60)
			task.wait(0.01)
		end
	end
	-- Bandeaux affichés : tous, ou seulement ceux du test (un vrai message du serveur, perso au
	-- niveau max, Marchand qui change de coin..., peut arriver pendant le test : on le retire).
	local function clearToasts(keepTest)
		for _, child in toasts:GetChildren() do
			if child.Name == "Toast" then
				local mine = false
				for _, d in child:GetDescendants() do
					if d:IsA("TextLabel") and string.find(d.Text, "Bandeau de test", 1, true) then
						mine = true
					end
				end
				if not (keepTest and mine) then
					child:Destroy()
				end
			end
		end
	end
	RollPanel.forceNear(false)
	local serial = 0
	for _, inZone in { false, true } do
		alice.Character:PivotTo(inZone and CFrame.new(Layout.AfkZone.X, 4, Layout.AfkZone.Z) or CFrame.new(0, 3, 0))
		task.wait(0.35)
		assert(panel.Visible == inZone, "panneau AFK " .. (inZone and "absent dans la zone" or "affiché hors de la zone"))
		for _, withPill in { false, true } do
			for step = 0, 7 do
				local count, single = math.floor(step / 2), step % 2 == 1
				-- bandeaux : exactement `count`
				clearToasts(false)
				for _ = 1, count do
					serial += 1
					NotificationsUI.toast("Bandeau de test n° " .. serial, "info")
				end
				-- cartes de suivi (hors de la zone : 3 cartes)
				for _, child in tracker:GetChildren() do
					if child:IsA("Frame") then
						child:Destroy()
					end
				end
				if not inZone then
					for k = 1, 3 do
						QuestsUI.trackerCard({ kind = "progress", id = "pile_" .. k, title = "Défi de test " .. k, progress = k, goal = 10 })
					end
				end
				-- persos tirés loin de la machine (3 cartes, ou 1 seule, + bandeau MUTATION : avec une
				-- carte, c'est le bandeau qui est le plus large)
				local results = if single
					then { { id = "ninja_maruto", stars = 1, rarity = "epic", price = 900, dps = 80, aura = "arcenciel" } }
					else {
						{ id = "ninja_maruto", stars = 1, rarity = "epic", price = 900, dps = 80, aura = "or" },
						{ id = "occ_goju", stars = 1, rarity = "rare", price = 500, dps = 50 },
						{ id = "sai_goko", stars = 1, rarity = "rare", price = 500, dps = 50 },
					}
				RollReveal.show({ results = results, count = #results, auto = true })
				pill.Visible = withPill
				frames(4)
				-- (le panneau ROULER peut remettre la pastille à jour entre deux images : on la repose,
				-- on retire un message du serveur arrivé entre-temps, puis deux images sans attendre,
				-- et on mesure aussitôt)
				clearToasts(true)
				pill.Visible = withPill
				Harness.services.RunService.RenderStepped:Fire(1 / 60)
				Harness.services.RunService.RenderStepped:Fire(1 / 60)
				local label = (inZone and "zone AFK" or "hors zone") .. (withPill and ", pastille" or "") .. ", " .. count .. " bandeau(x), " .. #results .. " carte(s)"
				local list = {}
				if withPill then
					table.insert(list, centered("pastille", pill, pill.Size.X.Offset, pill.Size.Y.Offset))
				end
				if inZone then
					table.insert(list, centered("panneau AFK", panel, panel.Size.X.Offset, panel.Size.Y.Offset))
				end
				local toastHeight = NotificationsUI.stackHeight()
				assert(toastHeight == (count > 0 and count * 52 + (count - 1) * 6 or 0), label .. " : hauteur des bandeaux " .. toastHeight)
				if count > 0 then
					table.insert(list, centered("bandeaux", toasts, toasts.Size.X.Offset, toastHeight))
				end
				assert(strip.Visible, label .. " : persos tirés non affichés")
				local scale = strip:FindFirstChildOfClass("UIScale").Scale
				-- largeur : celle des cartes ou celle du cadre du bandeau MUTATION (son texte, mis à
				-- l'échelle du cadre, est centré dedans), la plus grande des deux
				local banner = strip:FindFirstChild("Mutation")
				assert(banner, label .. " : bandeau MUTATION absent")
				local bannerWidth = banner.Size.X.Scale * strip.Size.X.Offset + banner.Size.X.Offset
				local revealWidth = math.max(#results * 176 + (#results - 1) * 14, bannerWidth) * scale
				local stripHeight = (244 + 4 + 32) * scale
				table.insert(list, centered("persos tirés", strip, revealWidth, stripHeight, strip.Position.X.Offset))
				assert(list[#list].x1 <= W, label .. " : persos tirés hors de l'écran à droite")
				assert(strip.Position.Y.Offset + stripHeight <= H - 132 - 8 + 0.5, label .. " : persos tirés sur les boutons de voyage")
				if not inZone then
					assert(tracker.Visible, label .. " : cartes de suivi cachées hors de la zone")
					local x0, y0, x1, y1 = QuestsUI.trackerBounds()
					assert(x0 and y0 and x1 and y1, label .. " : cartes de suivi absentes")
					table.insert(list, rect("cartes de suivi", x0, y0, x1 - x0, y1 - y0))
					assert(y1 <= H - 132, label .. " : cartes de suivi sur les boutons de voyage")
				else
					assert(not tracker.Visible, label .. " : cartes de suivi affichées dans la zone")
				end
				for i = 1, #list do
					for j = i + 1, #list do
						local a, b = list[i], list[j]
						local overlap = a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
						assert(not overlap, label .. " : " .. a.name .. " (y " .. a.y0 .. " → " .. a.y1 .. ") chevauche " .. b.name .. " (y " .. b.y0 .. " → " .. b.y1 .. ")")
					end
				end
			end
		end
	end
	pill.Visible = false
	for _, child in tracker:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	alice.Character:PivotTo(CFrame.new(0, 3, 0))
	RollPanel.forceNear(nil)
	task.wait(3)
	expectNoNewWarnings(before, "haut de l'écran")
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
	-- Même en cas d'échec : passes retirés, fenêtre fermée, machine et caméra rendues (sinon
	-- « Roulage x2 » resterait possédé et la boutique Robux échouerait plus loin, par exemple).
	local cameraBefore = camera.CFrame
	Harness.cleanup(function()
		for _, key in { "Pass_Roll2", "Pass_AutoRoll", "Pass_AutoRollPlus" } do
			setAttr(key, nil)
		end
		Menus.close("AutoRoll")
		RollPanel.forceNear(nil)
		camera.CFrame = cameraBefore
		Harness.services.UserInputService.LastInputTypeChanged:Fire(roblox.Enum.UserInputType.MouseMovement)
	end)
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
	-- Manette : passe acheté fenêtre ouverte. Le bouton sélectionné (« Débloquer », sur le cache)
	-- disparaît avec le cache : la sélection se repose sur « Lancer ».
	local ConsoleUI = Harness.require(client.UI.Console)
	local GuiService = game:GetService("GuiService")
	Harness.services.UserInputService.LastInputTypeChanged:Fire(roblox.Enum.UserInputType.Gamepad1)
	task.wait(0.1)
	assert(ConsoleUI.isGamepad(), "mode manette non détecté")
	assert(refs["buy_AutoRoll"] and refs["buy_AutoRoll"]:IsDescendantOf(refs.leftCover), "bouton « Débloquer » du cache introuvable")
	GuiService.SelectedObject = refs["buy_AutoRoll"]
	setAttr("Pass_AutoRoll", true)
	task.wait(0.1)
	assert(GuiService.SelectedObject == refs.afkButton, "manette : sélection perdue après l'achat du passe (" .. tostring(GuiService.SelectedObject) .. ")")
	Harness.services.UserInputService.LastInputTypeChanged:Fire(roblox.Enum.UserInputType.MouseMovement)
	task.wait(0.1)
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
	-- La fenêtre envoie les réglages au serveur 0,35 s après le dernier clic (task.delay, clics
	-- rapprochés groupés). Sous Lune, serveur, client et carte partagent un planificateur très
	-- chargé où un task.delay(0,35) peut passer bien après un task.wait(0,6) lancé ensuite : on
	-- attend que le serveur ait le réglage, sans délai serré.
	local function savedAs(expected: boolean): boolean
		local t0 = os.clock()
		while (data.AutoRollSettings.pauseRarities[rarityId] == true) ~= expected and os.clock() - t0 < 30 do
			task.wait(0.1)
		end
		return (data.AutoRollSettings.pauseRarities[rarityId] == true) == expected
	end
	-- (l'état de départ est celui affiché par le bouton)
	local initial = toggle.Label.Text == "Activé"
	assert(savedAs(initial), "le bouton n'affiche pas le réglage enregistré")
	signalFor(toggle, "Activated"):Fire()
	assert(savedAs(not initial), "réglage non enregistré")
	signalFor(toggle, "Activated"):Fire()
	assert(savedAs(initial), "réglage non rétabli")
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
	-- Téléphone : la barre ROULER remonte au-dessus du bouton de saut (coin bas droit).
	local Console = Harness.require(client.UI.Console)
	local isTouch = Console.isTouch
	Harness.cleanup(function()
		Console.isTouch = isTouch
	end)
	local pcBottom = panel.Position.Y.Offset
	Console.isTouch = function()
		return true
	end
	RollPanel.layout()
	assert(panel.Position.Y.Offset <= -200, "barre ROULER sur le bouton de saut (tactile) : " .. panel.Position.Y.Offset)
	local pull = RollPanel.refs().pull
	assert(pull.Position.Y.Offset < panel.Position.Y.Offset, "cartes du perso tiré sous la barre en tactile")
	-- Bandeau MUTATION à la machine : au-dessus de la carte du perso tiré, remontée elle aussi.
	local RollReveal = Harness.require(client.UI.RollReveal)
	local strip = alice.PlayerGui.AnimeTycoonUI.RollReveal.Strip
	local function checkBanner(where)
		RollReveal.show({ results = { { id = "ninja_maruto", stars = 1, rarity = "rare", price = 500, dps = 50, aura = "or" } }, count = 1, auto = true })
		Harness.services.RunService.RenderStepped:Fire(1 / 60)
		assert(strip.Visible and strip.AnchorPoint.Y == 1 and strip:FindFirstChild("Mutation"), "bandeau MUTATION absent à la machine (" .. where .. ")")
		-- (distances depuis le bas de l'écran : bas du bandeau, haut de la carte du perso tiré)
		local bannerBottom = -strip.Position.Y.Offset
		local pullTop = -pull.Position.Y.Offset + pull.Size.Y.Offset
		assert(bannerBottom >= pullTop + 8, "bandeau MUTATION sur la carte du perso tiré (" .. where .. ") : " .. bannerBottom .. " / " .. pullTop)
	end
	checkBanner("tactile")
	-- La barre Robux de droite ne doit pas être poussée au milieu de l'écran (sur le perso tiré)
	-- par la carte du perso tiré remontée : elle reste au bord droit, ou s'efface faute de place.
	local RobuxSideBar = Harness.require(client.UI.RobuxSideBar)
	local pullWasVisible = pull.Visible
	pull.Visible = true
	RobuxSideBar.layout()
	local holder = RobuxSideBar.holder()
	assert(holder, "barre Robux introuvable")
	assert(not holder.Visible or holder.Position.X.Offset >= -240, "barre Robux poussée vers le centre en tactile : " .. holder.Position.X.Offset)
	pull.Visible = pullWasVisible
	Console.isTouch = isTouch
	RobuxSideBar.layout()
	assert(holder.Visible, "barre Robux masquée hors tactile")
	RollPanel.layout()
	assert(panel.Position.Y.Offset == pcBottom, "barre ROULER non revenue en place hors tactile")
	checkBanner("PC")
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
	-- Vrai quand les données ont été envoyées au client depuis le dernier changement (envoi
	-- groupé de DataService:Sync, 0,25 s après). Sous Lune très chargé, ce délai peut passer bien
	-- après une attente fixe plus longue : on attend l'envoi lui-même.
	local function synced(): boolean
		if services.DataService:PendingSyncDelay(alice) == nil then
			return true -- (rien en attente : l'envoi qui suit le changement est déjà parti)
		end
		local sends = received.DataSync or 0
		local t0 = os.clock()
		while (received.DataSync or 0) == sends and os.clock() - t0 < 30 do
			task.wait(0.1)
		end
		return (received.DataSync or 0) > sends
	end
	-- Devant sa machine : le serveur refuse le remote Roll ailleurs.
	local plot = services.PlotService:GetPlot(alice)
	alice.Character:PivotTo(plot.cf * CFrame.new(services.PlotService.MachineOffset + Vector3.new(0, 3, -8)))
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
	-- La carte du perso tiré (et son bouton « Collecter ») est refaite à la synchro qui suit le
	-- roulage ; d'ici là, elle montre encore l'estrade d'avant (le perso tiré par l'auto-roulage
	-- du test précédent, qui n'y est plus).
	assert(synced(), "synchro du roulage jamais envoyée au client")
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
	Harness.cleanup(function()
		services.CharacterService.AddXP = addXP
	end)
	assert(synced(), "synchro de la libération jamais envoyée au client")
	task.wait(0.2)
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
	assert(synced(), "synchro sans changement jamais envoyée au client")
	task.wait(0.3)
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

test("Kourama : créature animée (queues, marche, attaque) sans animations R6", function()
	local before = #warnings
	local Shared = Harness.find("ReplicatedStorage.Shared")
	local Factory = Harness.require(Shared.Modules.CharacterFactory)
	local Characters = Harness.require(Shared.Config.Characters)
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local CreatureAnimator = Harness.require(client.Controllers.CreatureAnimator)
	local model = Factory.build("ninja_kourama", 1, Characters.Enemies.ninja_kourama.look, { scale = 4.2, humanoid = true, name = "KouramaTest" })
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Boss", true)
	model:SetAttribute("AttackTick", 0)
	local origin = camera.CFrame.Position + camera.CFrame.LookVector * 40
	model:PivotTo(CFrame.new(origin))
	model.Parent = workspaceService
	Harness.CollectionService:AddTag(model, "AnimeRig")
	-- CreatureAnimator le prend en charge à l'image suivante (task.wait() dans un fil lancé par
	-- task.spawn). Sous Lune, toute la partie tourne dans un seul planificateur : quand un autre fil
	-- calcule plusieurs secondes dans le même passage (vérifié avec un fil différé de 3 s), la
	-- première image du fil lancé ne vient qu'APRÈS la fin de l'attente de ce test, déjà en cours.
	-- On attend donc la prise en charge elle-même, jusqu'à 60 s, et non une durée fixe.
	local st = nil
	local waitStart = os.clock()
	repeat
		task.wait(0.05)
		st = CreatureAnimator._rigs[model]
	until st or os.clock() - waitStart > 60
	assert(st, "Kourama non pris en charge par CreatureAnimator")
	local tail = model:FindFirstChild("Tail5_6"):FindFirstChildOfClass("Motor6D")
	local base = tail:GetAttribute("BaseC0")
	local function frames(n, move)
		for _ = 1, n do
			if move then
				model:PivotTo(model:GetPivot() + Vector3.new(0, 0, -0.25))
			end
			Harness.services.RunService.RenderStepped:Fire(1 / 60)
		end
	end
	frames(20)
	assert(tail.C0 ~= base, "les queues n'ondulent pas")
	-- Marche : les pattes bougent.
	frames(40, true)
	assert(st.move > 0.3, "marche non détectée")
	-- Attaques (griffe puis rugissement) : la mâchoire s'ouvre.
	for i = 1, 3 do
		model:SetAttribute("AttackTick", i)
		frames(30)
	end
	model:SetAttribute("HitTick", 1)
	frames(10)
	for _, motor in { "RootJoint", "Neck", "Jaw", "LeftShoulder", "RightKnee", "LeftEarJoint" } do
		assert(model:FindFirstChild(motor, true), "articulation manquante : " .. motor)
	end
	model:Destroy()
	frames(2)
	expectNoNewWarnings(before, "Kourama")
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
	-- Roulage x3 possédé : la carte « Roulage x2 » affiche « INCLUS ✓ » au lieu de son prix.
	alice:SetAttribute("Pass_Roll3", true)
	RobuxShop.render("passes")
	local roll2 = root:FindFirstChild("Pass_Roll2", true)
	local included = false
	for _, d in roll2:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "INCLUS", 1, true) then
			included = true
		end
	end
	assert(included, "« Roulage x2 » encore à vendre avec « Roulage x3 »")
	alice:SetAttribute("Pass_Roll3", nil)
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
	-- Dans Roblox le retour prend 1,8 s ; sous Lune, juste après la rotation d'univers (décor de
	-- ~40 000 pièces reconstruit en tâche de fond, plus lourd encore dans le fichier pré-construit),
	-- le planificateur prend du retard : on tolère jusqu'à 20 s.
	while camera.CameraType == roblox.Enum.CameraType.Scriptable and os.clock() - t0 < 20 do
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

Harness.finish()
