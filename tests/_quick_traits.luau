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


for _, id in { "occ_goju", "ninja_maruto", "sai_goko", "oce_loffy" } do
	local entry = services.CharacterService:CreateEntry(id)
	entry.level = 20
	services.CharacterService:AddCharacter(alice, entry)
end
services.DataService:Sync(alice)
task.wait(0.5)
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
	assert(TraitsConfig.revealLevel("critique") == 3 and TraitsConfig.revealLevel("fortune") == 2 and TraitsConfig.revealLevel("vigueur1") == 1, "niveaux de révélation")
	Menus.close("Traits")
	expectNoNewWarnings(before, "traits")
end)

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
	assert(math.abs(ring.CFrame.Position.Y - headTop) < 0.8, "la couronne doit être posée sur la tête (" .. ring.CFrame.Position.Y .. " / " .. headTop .. ")")
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
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
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.Name ~= "Crown" then
			for _, part in child:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local v = camera.CFrame:PointToObjectSpace(part.CFrame.Position)
					assert(v.Z < 0, "perso derrière la caméra : " .. child.Name)
					assert(math.abs(v.X / -v.Z) < tanH * 0.98, "perso coupé par le bord : " .. child.Name)
					assert(math.abs(v.Y / -v.Z) < tanV * 0.8, "perso coupé par les bandes noires : " .. child.Name)
				end
			end
			local torsoPart = child:FindFirstChild("Torso")
			table.insert(boxes, { name = child.Name, model = child, frame = torsoPart and torsoPart.CFrame.Rotation or CFrame.new() })
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
	assert(pose[torso][2].UpVector.Y > 0.9, "le torse doit rester presque droit")
	assert(pose[model:FindFirstChild("Head")][2].LookVector.Y < -0.3, "la tête doit être baissée")
	for _, legName in { "Left Leg", "Right Leg" } do
		local leg = model:FindFirstChild(legName)
		local cf = pose[leg][2]
		assert(math.abs(cf.UpVector.Y) < 0.2, legName .. " doit être repliée à plat")
		assert(cf.Position.Y - leg.Size.X * 0.5 > -0.3 and cf.Position.Y < 1.2, legName .. " doit reposer au sol")
	end
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
		if kind == "midas" then
			local torso = scene.hero and scene.hero:FindFirstChild("Torso")
			assert(torso and torso.Material == roblox.Enum.Material.Metal, "Midas : l'unité doit être changée en or")
		end
		TraitCinematic.skip()
		assert(scene.finished and not scene.folder.Parent, kind .. " : scène non nettoyée")
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


Harness.finish()
