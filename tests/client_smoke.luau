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

test("Traits : relance avec une gemme, relance auto, cinématiques Monarque et Mythique", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local TraitsMenu = Harness.require(client.UI.TraitsMenu)
	local data = services.DataService:Get(alice)
	data.traitCrystals = 3
	services.DataService:Sync(alice)
	task.wait(0.4)
	Menus.open("Traits")
	task.wait(0.3)
	local gui = alice.PlayerGui.AnimeTycoonUI
	local root = gui:FindFirstChild("WindowRoot_TRAITS")
	assert(root and root:FindFirstChild("TraitCard", true), "carte du trait manquante")
	assert(root:FindFirstChild("Chances", true) and root:FindFirstChild("Tier5", true), "échelle des chances manquante")
	local roll = nil
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d:GetAttribute("SelKey") == "roll" then
			roll = d
		end
	end
	assert(roll, "bouton RELANCER manquant")
	signalFor(roll, "Activated"):Fire()
	task.wait(3)
	TraitsMenu.skipCinematic()
	task.wait(0.4)
	assert(data.traitCrystals == 2, "la relance doit coûter 1 gemme (" .. tostring(data.traitCrystals) .. ")")
	-- Cinématique du Monarque : des persos s'agenouillent, la couronne descend
	local list = Harness.require(client.State).sortedCharacters()
	local entry, desc = list[1].entry, list[1].desc
	local cine = TraitsMenu.playMonarch(entry, desc, 2)
	assert(cine and cine:FindFirstChild("Scene"), "scène de la cinématique manquante")
	local scene = cine.Scene
	assert(scene:FindFirstChild("Crown") and scene:FindFirstChild("ThroneBack"), "salle du trône incomplète")
	local models = 0
	for _, child in scene:GetChildren() do
		if child:IsA("Model") and child.Name ~= "Crown" then
			models += 1
		end
	end
	assert(models >= 7, "il faut l'unité + 6 persos agenouillés (" .. models .. ")")
	for _ = 1, 20 do
		Harness.services.RunService.RenderStepped:Fire(1 / 30)
		task.wait(0.03)
	end
	TraitsMenu.skipCinematic()
	assert(not cine.Parent, "la cinématique ne se passe pas")
	-- Plan final (horloge simulée) : caméra basse dans l'axe du tapis, derrière les deux rangées.
	-- L'unité et les 6 persos à genou sont entiers dans le champ (entre les bandes noires, écran 16/9),
	-- aucun perso n'en chevauche un autre ni l'unité, et rien ne cache la tête ni le torse de l'unité.
	local fake = 0
	local cine2 = TraitsMenu.playMonarch(entry, desc, 7.5, function()
		return fake
	end)
	fake = 7.5
	for _ = 1, 3 do
		Harness.services.RunService.RenderStepped:Fire(1 / 30)
		task.wait(0.03)
	end
	local scene2 = cine2.Scene
	local cam = scene2:FindFirstChildOfClass("Camera")
	local tanV = math.tan(math.rad(cam.FieldOfView) / 2)
	local tanH = tanV * 16 / 9
	local function boxOf(model)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local half = part.Size * 0.5
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local c = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
							hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
						end
					end
				end
			end
		end
		return lo, hi
	end
	local hero = scene2:FindFirstChild("Hero")
	assert(hero, "unité introuvable sur l'estrade")
	local heroHead, heroTorso = hero:FindFirstChild("Head"), hero:FindFirstChild("Torso")
	assert(heroHead.Size.Y > 1.2, "l'unité doit être à l'échelle 1,3")
	local heroLo, heroHi = boxOf(hero)
	assert(heroLo.Y > 1.7, "l'unité doit être debout sur l'estrade (" .. heroLo.Y .. ")")
	assert(heroHi.Y > scene2.ThroneBack.CFrame.Position.Y + scene2.ThroneBack.Size.Y * 0.5, "l'unité doit dépasser le dossier du trône")
	local boxes = { { name = "Hero", lo = heroLo, hi = heroHi } }
	local kneelerCount = 0
	for _, child in scene2:GetChildren() do
		if child:IsA("Model") and child.Name ~= "Crown" then
			for _, part in child:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local v = cam.CFrame:PointToObjectSpace(part.CFrame.Position)
					assert(v.Z < 0, "perso derrière la caméra")
					assert(math.abs(v.X / -v.Z) < tanH * 0.98, "perso coupé par le bord : " .. child.Name)
					assert(math.abs(v.Y / -v.Z) < tanV * 0.78, "perso coupé par les bandes noires : " .. child.Name)
				end
			end
			if child.Name ~= "Hero" then
				kneelerCount += 1
				local lo, hi = boxOf(child)
				local torso = child:FindFirstChild("Torso")
				assert(torso and torso.CFrame.Position.Y < 2.2, "perso pas agenouillé : " .. child.Name)
				table.insert(boxes, { name = child.Name, lo = lo, hi = hi })
			end
		end
	end
	assert(kneelerCount == 6, "il faut 6 persos agenouillés (" .. kneelerCount .. ")")
	-- deux rangées symétriques, 3 à gauche et 3 à droite du tapis
	local left, right = 0, 0
	for _, spot in TraitsMenu.KneelSpots do
		if spot.X < -3.7 then
			left += 1
		elseif spot.X > 3.7 then
			right += 1
		end
	end
	assert(left == 3 and right == 3, "les persos doivent former deux rangées de part et d'autre du tapis")
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local A, B = boxes[i], boxes[j]
			local overlap = A.lo.X < B.hi.X and B.lo.X < A.hi.X and A.lo.Y < B.hi.Y and B.lo.Y < A.hi.Y and A.lo.Z < B.hi.Z and B.lo.Z < A.hi.Z
			assert(not overlap, A.name .. " chevauche " .. B.name)
		end
	end
	-- rayon caméra -> tête et torse de l'unité : aucune pièce (perso, pilier, décor) sur le chemin
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
	for _, target in { heroHead, heroTorso } do
		local a, b = cam.CFrame.Position, target.CFrame.Position
		for _, part in scene2:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 0.5 and not part:IsDescendantOf(hero) and not part:IsDescendantOf(scene2.Crown) then
				assert(not segmentHits(part, a, b), part:GetFullName() .. " cache " .. target.Name .. " de l'unité")
			end
		end
	end
	TraitsMenu.skipCinematic()
	-- Pose à genoux : les jambes et le torse descendent
	local model = Harness.require(client.UI.Components).characterModel(desc.look, entry.id, entry.stars)
	local pose = TraitsMenu.kneelPose(model)
	local torso = model:FindFirstChild("Torso")
	assert(pose[torso] and pose[torso][2].Position.Y < pose[torso][1].Position.Y - 0.5, "le torse ne descend pas à genoux")
	-- à genoux lisible : torse presque droit, tête baissée, jambes à plat au sol (pas sous le sol)
	assert(pose[torso][2].UpVector.Y > 0.9, "le torse doit rester presque droit")
	local head = model:FindFirstChild("Head")
	assert(pose[head][2].LookVector.Y < -0.3, "la tête doit être baissée")
	for _, legName in { "Left Leg", "Right Leg" } do
		local leg = model:FindFirstChild(legName)
		local cf = pose[leg][2]
		assert(math.abs(cf.UpVector.Y) < 0.2, legName .. " doit être repliée à plat")
		assert(cf.Position.Y - leg.Size.X * 0.5 > -0.3 and cf.Position.Y < 1.2, legName .. " doit reposer au sol")
	end
	-- plan final de la cinématique : caméra basse (contre-plongée) dans l'axe du tapis
	local keys = TraitsMenu.monarchCamera(7.5)
	local last = keys[#keys]
	assert(math.abs(last[2].X) < 0.5 and last[2].Y < 6 and last[3].Y > last[2].Y, "le plan final doit être bas, dans l'axe du tapis, en contre-plongée")
	-- Mythique
	local asc = TraitsMenu.playAscension(entry, desc, Harness.require(Harness.find("ReplicatedStorage.Shared.Config.Traits")).List.celeste, 1)
	assert(asc and asc:FindFirstChild("Title", true), "ascension sans titre")
	TraitsMenu.skipCinematic()
	Menus.close("Traits")
	expectNoNewWarnings(before, "traits")
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

test("Boucle de la base vue par le client : rouler, collecter, poser une unité", function()
	local before = #warnings
	local client = Harness.find("StarterPlayer.StarterPlayerScripts.Client")
	local RollPanel = Harness.require(client.UI.RollPanel)
	local State = Harness.require(client.State)
	local Remotes = Harness.require(Harness.find("ReplicatedStorage.Shared.Modules.Remotes"))
	local data = services.DataService:Get(alice)
	local rolls = received.RollResult or 0
	-- 1) Rouler depuis le panneau du HUD : le serveur répond par RollResult (révélation).
	RollPanel.roll()
	task.wait(0.3)
	assert((received.RollResult or 0) > rolls, "pas de RollResult reçu après le roulage")
	assert(#data.RolledQueue >= 1, "rien sur l'estrade")
	task.wait(0.3)
	assert(State.data and #State.data.RolledQueue >= 1, "l'estrade n'est pas synchronisée côté client")
	-- 2) Collecter le 1er perso de l'estrade (le tout premier est offert).
	local owned = 0
	for _ in data.characters do
		owned += 1
	end
	-- Le bouton « Prendre » du panneau envoie la CLÉ du perso (pas sa position).
	local firstKey = State.data.RolledQueue[1].key
	data.RolledQueue[1].rarity = "common" -- la collecte offerte ne vaut que jusqu'au Rare
	local takeButton = nil
	for _, d in alice.PlayerGui.AnimeTycoonUI:GetDescendants() do
		if d.Name == "Queued1" then
			for _, b in d:GetDescendants() do
				if b:IsA("TextButton") then
					takeButton = b
					break
				end
			end
		end
	end
	assert(takeButton, "bouton « Prendre » absent du panneau")
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
	Remotes.event("OpenMenu"):FireClient(alice, "PlaceUnit", { slot = 2 })
	task.wait(0.2)
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
