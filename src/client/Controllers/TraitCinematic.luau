-- CINÉMATIQUES DES TRAITS TRÈS RARES (vues seulement par le joueur : tout est créé côté client).
--
-- La scène se joue DANS LE MONDE : sur l'unité du joueur posée sur sa base si elle est proche,
-- sinon sur une copie de l'unité à l'endroit où se tient le joueur (son avatar est masqué le temps
-- de la scène). Les objets du décor qui gêneraient (arbres, lampadaires...) sont masqués pour ce
-- joueur seulement, puis réaffichés.
--
--   • MONARQUE (le plus rare) : une estrade dorée sort du sol, des persos (ses autres unités et des
--     ennemis de l'univers) apparaissent en cercle dans des colonnes de lumière et S'AGENOUILLENT
--     devant l'unité ; une couronne d'or descend du ciel sur sa tête, rayons de lumière, titre.
--   • CÉLESTE : un faisceau céleste descend, l'unité s'élève, des ailes de lumière se déploient,
--     des plumes tombent.
--   • MIDAS : pluie de pièces d'or, l'unité se change en or des pieds à la tête et tout l'écran
--     devient doré un instant.
--   • VAMPIRE : la nuit tombe, une lune rouge se lève derrière l'unité, des chauves-souris
--     tourbillonnent, une brume rouge rampe au sol et une cape se déploie.
--
-- 4 à 8 secondes ; bouton PASSER (B / A à la manette, Espace / Entrée au clavier, toucher l'écran).
-- Respecte les réglages Options : FxFlash = false (pas de flash blanc) et FxShake = false (pas de
-- secousse). Le serveur reste maître du tirage : ce module ne fait qu'AFFICHER un résultat reçu.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared.Config.Traits)
local Characters = require(Shared.Config.Characters)
local Formulas = require(Shared.Modules.Formulas)
local CharacterFactory = require(Shared.Modules.CharacterFactory)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local Console = require(UI.Console)
local State = require(script.Parent.Parent.State)

local TraitCinematic = {}

local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 206, 64)
local GOLD_DEEP = Color3.fromRGB(214, 150, 40)
local CREAM = Color3.fromRGB(246, 238, 222)

local SPARKLE_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

-- Durées (secondes) de chaque cinématique.
TraitCinematic.Durations = { monarch = 7.5, celeste = 6.5, midas = 6, vampire = 6.5 }
TraitCinematic.Titles = { monarch = "MONARQUE", celeste = "CÉLESTE", midas = "MIDAS", vampire = "VAMPIRE" }
local TRAIT_OF = { monarch = "monarque", celeste = "celeste", midas = "midas", vampire = "vampire" }

local function sound(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	return s
end
local fanfare = sound("rbxasset://sounds/victory.wav", 0.5)
local ping = sound("rbxasset://sounds/electronicpingshort.wav", 0.5)
local whoosh = sound("rbxasset://sounds/swoosh.wav", 0.5)

local function play(s: Sound)
	pcall(function()
		SoundService:PlayLocalSound(s)
	end)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function easeOutBack(t: number): number
	t = math.clamp(t, 0, 1)
	local c1, c3 = 1.4, 2.4
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function setting(name: string): boolean
	local player = Players.LocalPlayer
	return not (player and player:GetAttribute(name) == false)
end

-- Qualité « basse » (téléphones) : moins de pièces et de particules.
local function lowQuality(): boolean
	local player = Players.LocalPlayer
	local q = player and player:GetAttribute("FxQuality")
	return q == "low" or (q == nil or q == "auto") and Console.isTouch()
end

------------------------------------------------------------------------
-- Pose « à genoux » (modèle aux pièces ancrées, pieds à y = 0, face -Z)
------------------------------------------------------------------------

local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart" }
-- Avec des jambes R6 d'un seul bloc, la pose qui se lit le mieux est « à genoux, tibias au sol » :
-- les deux jambes à plat derrière, le torse incliné, la tête baissée et le poing droit posé au sol
-- devant (le salut du chevalier).
local KNEEL = {
	frontLeg = -90, -- jambe droite à plat derrière (genou à terre)
	backLeg = 90, -- jambe gauche à plat derrière (genou à terre)
	torso = 24, -- torse incliné en révérence
	head = 10, -- tête un peu plus baissée que le torse
	fistLift = 22, -- bras droit vers l'avant : le poing touche le sol
	fistYaw = 0,
	leftArm = 10, -- bras gauche le long du corps
	drop = 1.5, -- le corps descend de la longueur des jambes repliées
}
TraitCinematic.KneelAngles = KNEEL

-- Renvoie { [pièce] = { debout, à genoux } } dans le repère du modèle.
function TraitCinematic.kneelPose(model: Model): { [BasePart]: { CFrame } }
	local parentOf: { [BasePart]: BasePart } = {}
	local function find(p: BasePart): BasePart
		local root = p
		while parentOf[root] and parentOf[root] ~= root do
			root = parentOf[root]
		end
		return root
	end
	local function union(a: any, b: any)
		if typeof(a) == "Instance" and typeof(b) == "Instance" and a:IsA("BasePart") and b:IsA("BasePart") then
			local ra, rb = find(a), find(b)
			if ra ~= rb then
				parentOf[ra] = rb
			end
		end
	end
	local pivots: { [string]: Vector3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local ok, cf = pcall(function()
				return (d.Part0 :: BasePart).CFrame * d.C0
			end)
			if ok and d.Part1 then
				pivots[(d.Part1 :: BasePart).Name] = cf.Position
			end
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			pcall(union, (d :: any).Part0, (d :: any).Part1)
		end
	end
	local limbOfRoot: { [BasePart]: string } = {}
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limbOfRoot[find(limb)] = name
		end
	end
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local result: { [BasePart]: { CFrame } } = {}
	if not torso then
		return result
	end
	local tcf = torso.CFrame
	local right = tcf.RightVector
	local up = tcf.UpVector
	local function pivot(name: string, fallback: Vector3): Vector3
		return pivots[name] or tcf:PointToWorldSpace(fallback)
	end
	local function about(p: Vector3, angle: number): CFrame
		return CFrame.new(p) * CFrame.fromAxisAngle(right, angle) * CFrame.new(-p)
	end
	local function arm(p: Vector3, yaw: number, forward: number): CFrame
		return CFrame.new(p) * CFrame.fromAxisAngle(up, yaw) * CFrame.fromAxisAngle(right, forward) * CFrame.new(-p)
	end
	local hipCenter = tcf:PointToWorldSpace(Vector3.new(0, -1, 0))
	local limbMove = {
		["Right Leg"] = about(pivot("Right Leg", Vector3.new(0.5, -1, 0)), math.rad(KNEEL.frontLeg)),
		["Left Leg"] = about(pivot("Left Leg", Vector3.new(-0.5, -1, 0)), -math.rad(KNEEL.backLeg)),
		["Right Arm"] = arm(pivot("Right Arm", Vector3.new(1, 0.5, 0)), math.rad(KNEEL.fistYaw), math.rad(KNEEL.fistLift)),
		["Left Arm"] = about(pivot("Left Arm", Vector3.new(-1, 0.5, 0)), math.rad(KNEEL.leftArm)),
		Head = about(pivot("Head", Vector3.new(0, 1, 0)), -math.rad(KNEEL.head)),
	}
	local bow = about(hipCenter, -math.rad(KNEEL.torso))
	local down = CFrame.new(0, -KNEEL.drop, 0)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local limb = limbOfRoot[find(d)] or "Torso"
			local cf = d.CFrame
			local target = cf
			if limbMove[limb] then
				target = limbMove[limb] * target
			end
			if limb ~= "Left Leg" and limb ~= "Right Leg" then
				target = bow * target
			end
			result[d] = { cf, down * target }
		end
	end
	return result
end

local function applyPose(pose: { [BasePart]: { CFrame } }, place: CFrame, f: number)
	for part, pair in pose do
		part.CFrame = place * (if f <= 0 then pair[1] elseif f >= 1 then pair[2] else pair[1]:Lerp(pair[2], f))
	end
end

------------------------------------------------------------------------
-- Acteurs (copies d'unités) et pièces de décor de la scène
------------------------------------------------------------------------

-- Modèle de perso pour le monde : pièces ancrées, sans collision ni requêtes, pieds à y = 0,
-- face -Z, à l'origine. Les jointures sont gardées le temps de calculer la pose puis coupées.
local function buildActor(id: string?, stars: number?, look, scale: number?): Model?
	local ok, model = pcall(CharacterFactory.build, id, stars, look, { scale = scale or 1, name = "Actor" })
	if not ok or not model then
		local okPreview, preview = pcall(Components.characterModel, look, id, stars)
		if not okPreview then
			return nil
		end
		model = preview
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		model:PivotTo(CFrame.new())
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			pcall(function()
				d.CanQuery = false
				d.CanTouch = false
			end)
		elseif d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("Humanoid") then
			pcall(function()
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				d.RequiresNeck = false
				d.BreakJointsOnDeath = false
			end)
		end
	end
	-- pieds posés à y = 0
	local bottom = math.huge
	for _, name in { "Left Leg", "Right Leg" } do
		local leg = model:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			bottom = math.min(bottom, leg.CFrame.Position.Y - leg.Size.Y * 0.5)
		end
	end
	if bottom == math.huge then
		bottom = 0
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame - Vector3.new(0, bottom, 0)
		end
	end
	return model
end

-- Coupe les jointures (les pièces ancrées sont ensuite placées une à une).
local function freeze(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			pcall(function()
				(d :: any).Enabled = false
			end)
		end
	end
end

-- Place toutes les pièces d'un modèle (repère d'origine -> `place`).
local function snapshot(model: Model): { [BasePart]: CFrame }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			list[d] = d.CFrame
		end
	end
	return list
end
local function placeAll(list: { [BasePart]: CFrame }, place: CFrame)
	for part, cf in list do
		part.CFrame = place * cf
	end
end

-- Persos qui viennent s'agenouiller : d'abord d'autres unités du joueur, puis des ennemis de
-- l'univers actuel, puis des persos au hasard.
function TraitCinematic.kneelerLooks(exceptUid: string?, count: number): { { look: any, id: string?, stars: number? } }
	local list = {}
	local seen: { [string]: boolean } = {}
	local exceptId = nil
	if exceptUid and State.data and State.data.characters[exceptUid] then
		exceptId = State.data.characters[exceptUid].id
		seen[exceptId] = true
	end
	local units = 0
	for _, item in State.sortedCharacters() do
		if item.uid ~= exceptUid and not item.entry.fusion and not seen[item.entry.id] then
			seen[item.entry.id] = true
			table.insert(list, { look = item.desc.look, id = item.entry.id, stars = item.entry.stars })
			units += 1
			if units >= math.ceil(count * 0.6) then
				break
			end
		end
	end
	local okU, universe = pcall(State.universe)
	local pool = {}
	if okU and universe and universe.enemies then
		for _, id in universe.enemies do
			table.insert(pool, id)
		end
	end
	for _, id in pool do
		if #list >= count then
			break
		end
		if not seen[id] then
			local look = Characters.resolveLook(id, 1)
			if look then
				seen[id] = true
				table.insert(list, { look = look, id = id, stars = 1 })
			end
		end
	end
	local ids = {}
	for id in Characters.List do
		if not seen[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local rng = Random.new(#ids)
	while #list < count and #ids > 0 do
		local id = table.remove(ids, rng:NextInteger(1, #ids))
		local look = Characters.resolveLook(id, 1)
		if look then
			table.insert(list, { look = look, id = id, stars = 1 })
		end
	end
	return list
end

------------------------------------------------------------------------
-- Scène (dossier local, caméra, interface, effets d'écran)
------------------------------------------------------------------------

local current: any = nil

local function hideLocal(scene, part: BasePart)
	if scene.hidden[part] ~= nil then
		return
	end
	local ok, value = pcall(function()
		return part.LocalTransparencyModifier
	end)
	if ok then
		scene.hidden[part] = value
		pcall(function()
			part.LocalTransparencyModifier = 1
		end)
		for _, d in part:GetChildren() do
			if (d:IsA("SurfaceGui") or d:IsA("BillboardGui")) and d.Enabled then
				d.Enabled = false
				table.insert(scene.guis, d)
			elseif d:IsA("ParticleEmitter") and d.Enabled then
				d.Enabled = false
				table.insert(scene.guis, d)
			end
		end
	end
end

local function hideModel(scene, model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			hideLocal(scene, d)
		elseif d:IsA("BillboardGui") and d.Enabled then
			d.Enabled = false
			table.insert(scene.guis, d)
		end
	end
end

-- L'unité du joueur posée dans le monde (base ou équipe), si elle est assez proche.
local function placedUnit(uid: string?, near: Vector3?): Model?
	local player = Players.LocalPlayer
	if not uid or not player then
		return nil
	end
	local best, bestDistance = nil, 160
	for _, model in CollectionService:GetTagged("AnimeRig") do
		if model:IsA("Model") and model:GetAttribute("Uid") == uid and model:GetAttribute("OwnerId") == player.UserId and model:IsDescendantOf(Workspace) then
			local ok, pivot = pcall(function()
				return model:GetPivot()
			end)
			if ok then
				local distance = near and (pivot.Position - near).Magnitude or 0
				if distance < bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

-- Hauteur du sol sous un point (rayon vers le bas qui ignore les persos et la scène).
local function groundBelow(origin: Vector3, ignore: { Instance }): number?
	local ok, result = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = false
		return Workspace:Raycast(origin + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	end)
	if ok and result and typeof(result) ~= "table" then
		return (result :: any).Position.Y
	end
	return nil
end

-- Lieu de la scène : CFrame au sol, -Z = direction vers laquelle l'unité regarde.
function TraitCinematic.stageFor(uid: string?): (CFrame, Model?)
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	local near = root and (root :: BasePart).CFrame.Position or (camera and camera.CFrame.Position) or Vector3.zero
	local unit = placedUnit(uid, near)
	if unit then
		local pivot = unit:GetPivot()
		local feet = pivot.Position.Y - CharacterFactory.rootHeight(unit)
		local look = pivot.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.1 then
			look = Vector3.new(0, 0, -1)
		end
		local center = Vector3.new(pivot.Position.X, feet, pivot.Position.Z)
		return CFrame.lookAt(center, center + look.Unit), unit
	end
	local ignore: { Instance } = {}
	if character then
		table.insert(ignore, character)
	end
	local y = groundBelow(near, ignore) or (near.Y - 3)
	local center = Vector3.new(near.X, y, near.Z)
	-- l'unité regarde vers la caméra du joueur (là où il regardait la scène)
	local toward = camera and (camera.CFrame.Position - center) * Vector3.new(1, 0, 1) or Vector3.new(0, 0, -1)
	if toward.Magnitude < 0.1 then
		toward = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(center, center + toward.Unit), nil
end

-- Masque (pour ce joueur) ce qui dépasse dans le cercle de la scène : arbres, poteaux, autres persos.
local function clearArea(scene, radius: number)
	local center = scene.stage.Position
	local ok, parts = pcall(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { scene.folder }
		return Workspace:GetPartBoundsInRadius(center + Vector3.new(0, 7, 0), radius, params)
	end)
	if not ok or type(parts) ~= "table" then
		return
	end
	for _, part in parts do
		if part:IsA("BasePart") and not part:IsA("Terrain") then
			local size = part.Size
			local top = part.CFrame.Position.Y + size.Y * 0.5
			local biggest = math.max(size.X, size.Z)
			-- le sol (grande dalle plate) reste ; tout ce qui dépasse du sol est masqué
			if top > center.Y + 0.35 and biggest < 60 then
				local model = part:FindFirstAncestorOfClass("Model")
				if model and model ~= Workspace and model:FindFirstChild("HumanoidRootPart") then
					hideModel(scene, model)
				else
					hideLocal(scene, part)
				end
			end
		end
	end
end

local function finishScene(scene)
	if scene.finished then
		return
	end
	scene.finished = true
	if scene.connection then
		scene.connection:Disconnect()
	end
	pcall(function()
		ContextActionService:UnbindAction("AT_TraitCinematic")
	end)
	for part, value in scene.hidden do
		pcall(function()
			part.LocalTransparencyModifier = value
		end)
	end
	for _, gui in scene.guis do
		pcall(function()
			gui.Enabled = true
		end)
	end
	for gui, enabled in scene.screenGuis do
		pcall(function()
			gui.Enabled = enabled
		end)
	end
	for _, effect in scene.effects do
		if effect.Parent then
			effect:Destroy()
		end
	end
	if scene.folder.Parent then
		scene.folder:Destroy()
	end
	if scene.gui.Parent then
		scene.gui:Destroy()
	end
	local camera = scene.camera
	if camera and camera.Parent then
		pcall(function()
			camera.FieldOfView = scene.saved.fov
			camera.CameraType = scene.saved.cameraType
			if scene.saved.subject then
				camera.CameraSubject = scene.saved.subject
			end
		end)
	end
	if current == scene then
		current = nil
	end
	for _, callback in scene.onDone do
		task.spawn(callback)
	end
	task.defer(function()
		pcall(Console.focusCurrent)
	end)
end

-- Bandes noires (format cinéma) qui glissent.
local function letterbox(root: Frame)
	for _, top in { true, false } do
		local bar = new("Frame", {
			Name = top and "BarTop" or "BarBottom",
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = BLACK,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = root,
		})
		Theme.tween(bar, 0.5, { Size = UDim2.new(1, 0, 0.1, 0) })
	end
end

-- Crée la scène commune : dossier local, caméra scriptée, calque d'interface, réglages.
local function begin(kind: string, entry, desc, options)
	if current then
		finishScene(current)
	end
	local opts = options or {}
	local total = opts.duration or TraitCinematic.Durations[kind] or 6
	local player = Players.LocalPlayer
	local stage, unit
	if opts.stage then
		stage = opts.stage
	else
		stage, unit = TraitCinematic.stageFor(entry and entry.uid or opts.uid)
	end
	local folder = Instance.new("Folder")
	folder.Name = "TraitCinematic_" .. kind
	local scene = {
		kind = kind,
		total = total,
		stage = stage,
		folder = folder,
		hidden = {},
		guis = {},
		screenGuis = {},
		effects = {},
		onDone = {},
		steps = {},
		shake = 0,
		finished = false,
		unit = unit,
		entry = entry,
		desc = desc,
		flash = setting("FxFlash"),
		canShake = setting("FxShake"),
		low = lowQuality(),
	}
	current = scene
	folder.Parent = Workspace
	-- caméra
	local camera = Workspace.CurrentCamera
	scene.camera = camera
	scene.saved = {
		fov = camera and camera.FieldOfView or 70,
		cameraType = camera and camera.CameraType or Enum.CameraType.Custom,
		subject = camera and camera.CameraSubject or nil,
	}
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- l'unité d'origine et l'avatar du joueur sont masqués (une copie joue la scène)
	if unit then
		hideModel(scene, unit)
	end
	if player and player.Character then
		hideModel(scene, player.Character)
	end
	clearArea(scene, opts.radius or 14)
	-- interface : on cache les autres écrans le temps de la scène
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, other in playerGui:GetChildren() do
			if other:IsA("ScreenGui") and other.Enabled then
				scene.screenGuis[other] = true
				other.Enabled = false
			end
		end
	end
	local gui = new("ScreenGui", {
		Name = "TraitCinematicUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	scene.gui = gui
	local root = Theme.scaledRoot(gui, "Cinematic_" .. kind, 1)
	scene.root = root
	letterbox(root)
	-- voile pour les flashs et les fondus
	local veil = new("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = root,
	})
	scene.veil = veil
	-- passer : bouton (souris, toucher, manette) + touches
	local function finish()
		finishScene(scene)
	end
	scene.finish = finish
	local catcher = new("TextButton", {
		Name = "TapToSkip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Active = false,
		ZIndex = 35,
		Parent = root,
	})
	local born = os.clock()
	catcher.Activated:Connect(function()
		-- un toucher passe la scène (après un court instant : pas de passe accidentelle)
		if os.clock() - born > 0.8 then
			finish()
		end
	end)
	local skip = Components.button({
		Text = "PASSER",
		Icon = "fast",
		Color = Color3.fromRGB(70, 70, 92),
		Size = UDim2.fromOffset(170, 50),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -22),
		TextSize = 22,
		Hint = "B",
		Parent = root,
		OnClick = finish,
	})
	skip.Name = "Skip"
	skip.ZIndex = 40
	for _, d in skip:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 40
		end
	end
	scene.skip = skip
	pcall(function()
		ContextActionService:BindActionAtPriority("AT_TraitCinematic", function(_, state)
			if state == Enum.UserInputState.Begin then
				finish()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 60, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonA, Enum.KeyCode.Space, Enum.KeyCode.Return)
	end)
	if Console.isGamepad() then
		pcall(function()
			GuiService.SelectedObject = skip
		end)
	end
	-- effets d'écran (sous la caméra : ils ne touchent que ce joueur)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "TraitGrade"
	grade.Parent = camera
	scene.grade = grade
	table.insert(scene.effects, grade)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "TraitBloom"
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 0.92
	bloom.Parent = camera
	table.insert(scene.effects, bloom)
	scene.bloom = bloom
	return scene
end

-- Démarre la boucle d'images : `step(t, dt)` de la scène + caméra + secousse.
local function run(scene, clock: (() -> number)?)
	local now = clock or os.clock
	local start = now()
	local last = start
	local rng = Random.new(7)
	local function frame()
		if scene.finished then
			return
		end
		local t = now() - start
		local dt = math.clamp(t - (last - start), 0, 0.1)
		last = now()
		if t >= scene.total then
			finishScene(scene)
			return
		end
		for _, step in scene.steps do
			local ok, err = pcall(step, t, dt)
			if not ok then
				warn("[TraitCinematic] " .. tostring(err))
				finishScene(scene)
				return
			end
		end
		-- l'avatar et les objets masqués le restent (les scripts de caméra de Roblox les réaffichent)
		for part in scene.hidden do
			pcall(function()
				part.LocalTransparencyModifier = 1
			end)
		end
		if scene.cameraKeys and scene.camera then
			local cf, fov = TraitCinematic.evalCamera(scene.cameraKeys, t)
			local world = scene.stage * cf
			if scene.canShake and scene.shake > 0.01 then
				world = world * CFrame.Angles(rng:NextNumber(-1, 1) * scene.shake * 0.02, rng:NextNumber(-1, 1) * scene.shake * 0.02, 0)
				scene.shake *= math.exp(-dt * 6)
			end
			scene.camera.CFrame = world
			scene.camera.FieldOfView = fov
		end
	end
	scene.frame = frame
	scene.connection = RunService.RenderStepped:Connect(frame)
	frame()
end

-- Clés de caméra : { temps, œil (repère de la scène), point visé, champ de vision }.
function TraitCinematic.evalCamera(keys: { { any } }, t: number): (CFrame, number)
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i][1] and t <= keys[i + 1][1] then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local f = 1
	if t < a[1] then
		f = 0
	elseif b[1] > a[1] and t < b[1] then
		f = smooth((t - a[1]) / (b[1] - a[1]))
	end
	local eye = a[2]:Lerp(b[2], f)
	local target = a[3]:Lerp(b[3], f)
	local fov = (a[4] or 50) + ((b[4] or 50) - (a[4] or 50)) * f
	return CFrame.lookAt(eye, target), fov
end

local function flash(scene, color: Color3, strength: number, duration: number)
	local veil = scene.veil
	if not veil or not veil.Parent then
		return
	end
	-- sans flashs (Options) : simple teinte légère, jamais de blanc plein écran
	local alpha = scene.flash and (1 - strength) or math.max(0.82, 1 - strength * 0.25)
	veil.BackgroundColor3 = color
	veil.BackgroundTransparency = alpha
	Theme.tween(veil, duration, { BackgroundTransparency = 1 })
end

local function shake(scene, amount: number)
	if scene.canShake then
		scene.shake = math.max(scene.shake, amount)
	end
end

-- Grand titre doré (dégradé qui ondule) + sous-titre + badge de rareté.
local function title(scene, text: string, color: Color3, subtitle: string, badge: string?, y: number?)
	local root = scene.root
	if not root or not root.Parent then
		return
	end
	local holder = new("Frame", {
		Name = "TitleBlock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y or 0.24),
		Size = UDim2.fromOffset(980, 190),
		BackgroundTransparency = 1,
		ZIndex = 25,
		Parent = root,
	})
	local label = Theme.label({
		Name = "Title",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(980, 116),
		FontFace = Theme.Faces.Title,
		TextColor3 = WHITE,
		StrokeThickness = 5,
		ZIndex = 26,
		Parent = holder,
	})
	local gradient = Theme.gradient({ Theme.light(color, 0.6), color, Theme.dark(color, 0.3), Theme.light(color, 0.6) }, 0)
	gradient.Parent = label
	Theme.onFrame(gradient, function(_, t)
		gradient.Offset = Vector2.new(math.sin(t * 1.6) * 0.4, 0)
	end)
	local scale = new("UIScale", { Scale = 2.3, Parent = label })
	label.TextTransparency = 1
	Theme.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.tween(label, 0.25, { TextTransparency = 0 })
	-- trait fin de part et d'autre du sous-titre
	for _, side in { -1, 1 } do
		local line = new("Frame", {
			Name = "Rule",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 330, 0, 136),
			Size = UDim2.fromOffset(0, 3),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 26,
			Parent = holder,
		})
		Theme.gradient({ color, color }, 0, side < 0 and { 1, 0 } or { 0, 1 }).Parent = line
		Theme.tween(line, 0.6, { Size = UDim2.fromOffset(200, 3) })
	end
	local sub = Theme.label({
		Name = "Subtitle",
		Text = subtitle,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.fromOffset(440, 34),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = WHITE,
		StrokeThickness = 2.5,
		ZIndex = 26,
		Parent = holder,
	})
	sub.TextTransparency = 1
	task.delay(0.3, function()
		if sub.Parent then
			Theme.tween(sub, 0.4, { TextTransparency = 0 })
		end
	end)
	if badge then
		local pill = new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 160),
			Size = UDim2.fromOffset(250, 28),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.35,
			ZIndex = 26,
			Parent = holder,
		})
		Theme.round().Parent = pill
		Theme.stroke(color, 2).Parent = pill
		Theme.label({
			Text = badge,
			Size = UDim2.new(1, -16, 1, -6),
			Position = UDim2.fromOffset(8, 3),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = Theme.light(color, 0.4),
			StrokeThickness = 1.5,
			ZIndex = 27,
			Parent = pill,
		})
	end
	Theme.sparkles(holder, 12, #text, 0.3, 27)
	return holder
end

local function traitTitle(scene, kind: string)
	local trait = Traits.get(TRAIT_OF[kind])
	local visual = trait and Traits.Visual[trait.id]
	local name = scene.desc and scene.desc.name or "ton unité"
	local tierName = trait and Traits.TierNames[trait.tier] or ""
	local badge = trait and (string.upper(tierName) .. " · " .. string.format("%.1f %%", Traits.chance(trait.id)) .. " de chance") or nil
	local subtitle = (visual and visual.motto or "") .. "  —  " .. name
	return title(scene, TraitCinematic.Titles[kind], trait and trait.color or GOLD, subtitle, badge)
end

-- Pièce de décor de la scène (dans le repère de la scène).
local function part(scene, name: string, size: Vector3, localCf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = scene.stage * localCf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	pcall(function()
		p.CanQuery = false
		p.CanTouch = false
	end)
	p.CastShadow = material ~= Enum.Material.Neon and (transparency or 0) < 0.3
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Transparency = transparency or 0
	p.Parent = scene.folder
	return p
end

local function wedge(scene, name: string, size: Vector3, localCf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = scene.stage * localCf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	pcall(function()
		p.CanQuery = false
		p.CanTouch = false
	end)
	p.CastShadow = false
	p.Transparency = transparency or 0
	p.Parent = scene.folder
	return p
end

local function emitter(parentPart: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE_TEX
	e.LightEmission = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parentPart
	return e
end

local function light(parentPart: BasePart, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parentPart
	return l
end

local CYL = Enum.PartType.Cylinder
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cylindre couché à plat (disque)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout (axe X tourné vers le haut)

-- Copie de l'unité (le héros de la scène), debout à `height` au-dessus du sol de la scène.
local function spawnHero(scene, scale: number, height: number)
	local entry, desc = scene.entry, scene.desc
	local look = desc and desc.look
	if not look and entry then
		local d = Formulas.describe(entry)
		look = d and d.look
	end
	local model = look and buildActor(entry and entry.id, entry and entry.stars, look, scale)
	if not model then
		return nil
	end
	model.Name = "Hero"
	freeze(model)
	local base = snapshot(model)
	scene.hero = model
	scene.heroBase = base
	scene.heroPlace = scene.stage * CFrame.new(0, height, 0)
	placeAll(base, scene.heroPlace)
	model.Parent = scene.folder
	local head = model:FindFirstChild("Head") :: BasePart?
	scene.heroHeadTop = head and (head.CFrame.Position.Y - scene.stage.Position.Y + head.Size.Y * 0.5) or (height + 5 * scale)
	return model
end

-- Couronne d'or (anneau, pointes, perles, gemmes) à l'échelle `k`.
local function buildCrown(scene, k: number): Model
	local crown = Instance.new("Model")
	crown.Name = "Crown"
	local list = {}
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * k
		p.CFrame = cf.Rotation + cf.Position * k
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		pcall(function()
			p.CanQuery = false
			p.CanTouch = false
		end)
		p.Material = material or Enum.Material.Metal
		p.Reflectance = 0.2
		p.CastShadow = false
		if shape then
			p.Shape = shape
		end
		p.Parent = crown
		list[p] = p.CFrame
		return p
	end
	piece("Ring", Vector3.new(0.45, 1.7, 1.7), FLAT, GOLD, CYL)
	piece("RingRim", Vector3.new(0.12, 1.84, 1.84), CFrame.new(0, -0.2, 0) * FLAT, Color3.fromRGB(255, 236, 150), CYL)
	piece("Velvet", Vector3.new(0.3, 1.45, 1.45), CFrame.new(0, 0.12, 0) * FLAT, Color3.fromRGB(170, 20, 40), CYL, Enum.Material.Fabric)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 0.72, 0.5, math.sin(a) * 0.72)
		piece("Spike", Vector3.new(0.3, 0.75, 0.3), CFrame.new(pos) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(8)), GOLD)
		piece("Pearl", Vector3.new(0.26, 0.26, 0.26), CFrame.new(pos + Vector3.new(0, 0.45, 0)), Color3.fromRGB(255, 250, 230), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
		piece(
			"Jewel",
			Vector3.new(0.22, 0.22, 0.22),
			CFrame.new(math.cos(a + 0.6) * 0.86, 0, math.sin(a + 0.6) * 0.86),
			i % 2 == 0 and Color3.fromRGB(220, 30, 50) or Color3.fromRGB(40, 120, 255),
			Enum.PartType.Ball,
			Enum.Material.Glass
		)
	end
	local top = piece("Orb", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, 0.62, 0), GOLD, Enum.PartType.Ball)
	emitter(top, { Color = ColorSequence.new(GOLD), Size = NumberSequence.new(0.5, 0), Rate = 14, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180) })
	light(top, GOLD, 2, 10)
	crown.Parent = scene.folder
	scene.crownParts = list
	return crown
end

------------------------------------------------------------------------
-- MONARQUE
------------------------------------------------------------------------

local MONARCH_RADIUS = 7.6 -- cercle des persos agenouillés autour de l'unité
local MONARCH_COUNT = 8
local DAIS_TOP = 1.2 -- l'unité se tient sur une estrade (2 marches)
local HERO_SCALE = 1.3
TraitCinematic.MonarchRadius = MONARCH_RADIUS
TraitCinematic.MonarchCount = MONARCH_COUNT
TraitCinematic.HeroScale = HERO_SCALE

-- Places des persos (repère de la scène) : cercle complet décalé d'un demi-pas, pour qu'aucun ne
-- soit pile entre la caméra (devant) et l'unité.
function TraitCinematic.monarchSpots(): { Vector3 }
	local spots = {}
	for i = 0, MONARCH_COUNT - 1 do
		local a = (i + 0.5) / MONARCH_COUNT * math.pi * 2
		table.insert(spots, Vector3.new(math.sin(a) * MONARCH_RADIUS, 0, -math.cos(a) * MONARCH_RADIUS))
	end
	return spots
end

-- Trajet de la caméra : vue large qui tourne au-dessus du cercle, puis plan bas devant l'unité
-- (contre-plongée : les persos inclinés au premier plan, l'unité couronnée au centre).
function TraitCinematic.monarchCamera(total: number): { { any } }
	return {
		{ 0, Vector3.new(16, 15, -20), Vector3.new(0, 2.5, 0), 55 },
		{ 2.2, Vector3.new(-9, 11, -19), Vector3.new(0, 3, 0), 52 },
		{ 3.6, Vector3.new(-2.5, 4.4, -17), Vector3.new(0, 4.8, 0), 46 },
		{ math.max(total, 4), Vector3.new(0, 4.2, -14.5), Vector3.new(0, 5.2, 0), 44 },
	}
end

local function monarchScene(scene)
	local total = scene.total
	local s = scene.low and 0.6 or 1
	-- Sol de cérémonie : grand disque de marbre clair cerclé d'or, runes lumineuses qui tournent
	local floor = part(scene, "CeremonyFloor", Vector3.new(0.3, 24, 24), CFrame.new(0, 0.12, 0) * FLAT, CREAM, Enum.Material.Marble, CYL)
	local floorRim = part(scene, "CeremonyRim", Vector3.new(0.32, 25, 25), CFrame.new(0, 0.1, 0) * FLAT, GOLD_DEEP, Enum.Material.Metal, CYL)
	local runes = {}
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local r = 10.6
		local rune = part(scene, "Rune", Vector3.new(0.9, 0.06, 0.25), CFrame.new(math.cos(a) * r, 0.3, math.sin(a) * r) * CFrame.Angles(0, -a, 0), GOLD, Enum.Material.Neon)
		table.insert(runes, { part = rune, a = a, r = r })
	end
	local innerRing = part(scene, "GoldCircle", Vector3.new(0.05, 17, 17), CFrame.new(0, 0.28, 0) * FLAT, Color3.fromRGB(255, 220, 120), Enum.Material.Neon, CYL, 0.55)
	local innerHole = part(scene, "GoldCircleInner", Vector3.new(0.06, 16.4, 16.4), CFrame.new(0, 0.285, 0) * FLAT, CREAM, Enum.Material.Marble, CYL)
	local floorParts = { floor, floorRim, innerRing, innerHole }
	for _, r in runes do
		table.insert(floorParts, r.part)
	end
	-- Estrade (2 marches) + tapis rouge vers la caméra
	local dais1 = part(scene, "DaisLow", Vector3.new(0.6, 7.4, 7.4), CFrame.new(0, 0.3, 0) * FLAT, Color3.fromRGB(250, 246, 236), Enum.Material.Marble, CYL)
	local trim = part(scene, "DaisTrim", Vector3.new(0.1, 7.6, 7.6), CFrame.new(0, 0.62, 0) * FLAT, GOLD, Enum.Material.Metal, CYL)
	local dais2 = part(scene, "DaisHigh", Vector3.new(0.6, 5, 5), CFrame.new(0, 0.9, 0) * FLAT, WHITE, Enum.Material.Marble, CYL)
	local glow = part(scene, "DaisGlow", Vector3.new(0.05, 4, 4), CFrame.new(0, DAIS_TOP + 0.01, 0) * FLAT, Color3.fromRGB(255, 226, 140), Enum.Material.Neon, CYL, 0.35)
	local carpet = part(scene, "Carpet", Vector3.new(3.2, 0.08, 8), CFrame.new(0, 0.31, -7.6), Color3.fromRGB(176, 26, 42), Enum.Material.Fabric)
	for _, x in { -1.7, 1.7 } do
		table.insert(floorParts, part(scene, "CarpetTrim", Vector3.new(0.25, 0.1, 8), CFrame.new(x, 0.32, -7.6), GOLD, Enum.Material.Fabric))
	end
	for _, p in { dais1, trim, dais2, glow, carpet } do
		table.insert(floorParts, p)
	end
	local floorBase = {}
	for _, p in floorParts do
		floorBase[p] = scene.stage:ToObjectSpace(p.CFrame)
	end
	light(glow, Color3.fromRGB(255, 220, 150), 2.5, 18)
	-- L'unité (plus grande que les autres) sur l'estrade
	spawnHero(scene, HERO_SCALE, DAIS_TOP)
	local headTop = scene.heroHeadTop or (DAIS_TOP + 6.5)
	-- Halo et rayons dorés derrière l'unité (apparaissent avec la couronne)
	local haloY = headTop - 1.4
	local halo = part(scene, "Halo", Vector3.new(0.1, 6.4, 6.4), CFrame.new(0, haloY, 1.6) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 214, 100), Enum.Material.Neon, CYL, 1)
	local rays = {}
	for i = 0, 15 do
		local long = i % 2 == 0
		local ray = part(scene, "Ray", Vector3.new(0.22, long and 6 or 3.6, 0.06), CFrame.new(0, haloY, 1.7), Color3.fromRGB(255, 236, 160), Enum.Material.Neon, nil, 1)
		table.insert(rays, { part = ray, a = i / 16 * math.pi * 2, long = long })
	end
	-- Colonne de lumière du ciel sur l'unité (au moment où la couronne descend)
	local sky = part(scene, "SkyBeam", Vector3.new(60, 3.4, 3.4), CFrame.new(0, headTop + 30, 0) * UPRIGHT, Color3.fromRGB(255, 236, 170), Enum.Material.Neon, CYL, 1)
	-- Les persos du cercle : d'abord invisibles, ils apparaissent dans une colonne de lumière
	local kneelers = {}
	for i, info in TraitCinematic.kneelerLooks(scene.entry and scene.entry.uid, MONARCH_COUNT) do
		local model = buildActor(info.id, info.stars, info.look, 1)
		if model then
			model.Name = "Kneeler" .. i
			local pose = TraitCinematic.kneelPose(model)
			freeze(model)
			local spot = TraitCinematic.monarchSpots()[i]
			local place = scene.stage * CFrame.lookAt(spot, Vector3.new(0, 0, 0))
			applyPose(pose, place, 0)
			local pillar = part(scene, "SpawnPillar", Vector3.new(14, 2.6, 2.6), CFrame.new(spot + Vector3.new(0, 7, 0)) * UPRIGHT, Color3.fromRGB(255, 226, 130), Enum.Material.Neon, CYL, 1)
			local spark = emitter(pillar, {
				Color = ColorSequence.new(GOLD),
				Size = NumberSequence.new(0.6, 0),
				Rate = 0,
				Lifetime = NumberRange.new(0.5, 1),
				Speed = NumberRange.new(3, 7),
				SpreadAngle = Vector2.new(180, 180),
			})
			table.insert(kneelers, {
				model = model,
				pose = pose,
				place = place,
				pillar = pillar,
				spark = spark,
				appear = 0.45 + (i - 1) * 0.13,
				kneel = 1.55 + ((i - 1) % 4) * 0.12 + (i > 4 and 0.06 or 0),
				done = false,
			})
		end
	end
	-- Couronne
	local crown = buildCrown(scene, HERO_SCALE)
	local crownBase = scene.crownParts
	local crownTarget = headTop + 0.15 * HERO_SCALE
	-- Étincelles dorées qui montent du sol
	local motes = part(scene, "Motes", Vector3.new(0.2, 20, 20), CFrame.new(0, 0.4, 0) * FLAT, GOLD, Enum.Material.Neon, CYL, 1)
	emitter(motes, {
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 150)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Rate = 40 * s,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(1.5, 3),
		EmissionDirection = Enum.NormalId.Right,
		SpreadAngle = Vector2.new(15, 15),
	})
	-- Lumière chaude, bloom
	scene.grade.TintColor = Color3.fromRGB(255, 244, 222)
	scene.grade.Saturation = 0.12
	scene.grade.Contrast = 0.06
	scene.cameraKeys = TraitCinematic.monarchCamera(total)
	local titled, crowned = false, false
	play(whoosh)
	flash(scene, Color3.fromRGB(255, 236, 170), 0.85, 0.7)
	table.insert(scene.steps, function(t)
		-- l'estrade et le sol sortent du sol (0 -> 0,8 s)
		local rise = smooth(t / 0.8)
		local offset = CFrame.new(0, (rise - 1) * 1.4, 0)
		for p, rel in floorBase do
			p.CFrame = scene.stage * offset * rel
		end
		for _, r in runes do
			local a = r.a + t * 0.25
			r.part.CFrame = scene.stage * offset * CFrame.new(math.cos(a) * r.r, 0.3, math.sin(a) * r.r) * CFrame.Angles(0, -a, 0)
		end
		if scene.hero then
			placeAll(scene.heroBase, scene.stage * offset * CFrame.new(0, DAIS_TOP, 0))
		end
		for _, k in kneelers do
			if not k.model.Parent and t >= k.appear then
				k.model.Parent = scene.folder
				pcall(function()
					k.spark:Emit(18)
				end)
				play(ping)
			end
			local pt = t - k.appear
			k.pillar.Transparency = pt < 0 and 1 or math.clamp(0.15 + pt * 1.6, 0.15, 1)
			if k.model.Parent and not k.done then
				local f = smooth((t - k.kneel) / 0.7)
				applyPose(k.pose, k.place, f)
				if f >= 1 then
					k.done = true
				end
			end
		end
		-- la couronne descend du ciel (2,9 -> 4,3 s) en tournant
		local cf = smooth((t - 2.9) / 1.4)
		local crownCf = scene.stage * CFrame.new(0, crownTarget + (1 - cf) * 9, 0) * CFrame.Angles(0, (1 - cf) * 5 + t * 0.4, 0)
		placeAll(crownBase, crownCf)
		sky.Transparency = 1 - 0.55 * math.clamp(math.min((t - 2.7) / 0.4, (4.6 - t) / 0.6), 0, 1)
		if not crowned and t >= 4.3 then
			crowned = true
			flash(scene, Color3.fromRGB(255, 240, 190), 0.9, 0.8)
			shake(scene, 1)
			play(fanfare)
		end
		-- halo et rayons derrière l'unité, une fois couronnée
		local h = smooth((t - 4.2) / 0.6)
		halo.Transparency = 1 - h * 0.75
		for _, r in rays do
			local a = r.a + t * 0.35
			local len = r.long and 6 or 3.6
			local dist = 3.8 + len * 0.5
			r.part.Transparency = 1 - h * (r.long and 0.6 or 0.4)
			r.part.CFrame = scene.stage
				* CFrame.new(math.cos(a) * dist * (0.6 + 0.4 * h), haloY + math.sin(a) * dist * (0.6 + 0.4 * h), 1.75)
				* CFrame.Angles(0, 0, a - math.pi / 2)
		end
		if not titled and t >= 4.4 then
			titled = true
			traitTitle(scene, "monarch")
		end
	end)
	return crown
end

------------------------------------------------------------------------
-- CÉLESTE
------------------------------------------------------------------------

function TraitCinematic.celesteCamera(total: number): { { any } }
	return {
		{ 0, Vector3.new(7, 1.8, -12), Vector3.new(0, 14, 0), 60 },
		{ 1.4, Vector3.new(4, 2.6, -13), Vector3.new(0, 6, 0), 52 },
		{ 3, Vector3.new(0.5, 3.6, -13), Vector3.new(0, 6.4, 0), 46 },
		{ math.max(total, 3.5), Vector3.new(0, 3.4, -11.5), Vector3.new(0, 6.6, 0), 44 },
	}
end

local function celesteScene(scene)
	local total = scene.total
	local s = scene.low and 0.5 or 1
	local SKY = Color3.fromRGB(200, 240, 255)
	local LIFT = 2.2
	spawnHero(scene, 1.2, 0)
	local headTop = scene.heroHeadTop or 6
	-- Le faisceau céleste (cœur + halo) descend du ciel jusqu'au sol
	local beam = part(scene, "CelestialBeam", Vector3.new(1, 4.2, 4.2), CFrame.new(0, 200, 0) * UPRIGHT, SKY, Enum.Material.Neon, CYL, 0.35)
	local beamGlow = part(scene, "CelestialGlow", Vector3.new(1, 8, 8), CFrame.new(0, 200, 0) * UPRIGHT, Color3.fromRGB(150, 220, 255), Enum.Material.Neon, CYL, 0.82)
	local ring = part(scene, "ImpactRing", Vector3.new(0.05, 4, 4), CFrame.new(0, 0.12, 0) * FLAT, SKY, Enum.Material.Neon, CYL, 1)
	local pool = part(scene, "LightPool", Vector3.new(0.05, 9, 9), CFrame.new(0, 0.1, 0) * FLAT, Color3.fromRGB(230, 250, 255), Enum.Material.Neon, CYL, 1)
	light(pool, SKY, 3, 22)
	emitter(pool, {
		Color = ColorSequence.new(WHITE),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.4), NumberSequenceKeypoint.new(1, 0) }),
		Rate = 35 * s,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(3, 6),
		EmissionDirection = Enum.NormalId.Right,
		SpreadAngle = Vector2.new(10, 10),
	})
	-- Auréole (anneau de 16 segments lumineux) au-dessus de la tête
	local haloSegs = {}
	for i = 0, 15 do
		local seg = part(scene, "HaloSeg", Vector3.new(0.5, 0.12, 0.16), CFrame.new(), Color3.fromRGB(255, 248, 200), Enum.Material.Neon, nil, 1)
		table.insert(haloSegs, { part = seg, a = i / 16 * math.pi * 2 })
	end
	-- Ailes de lumière : 6 rémiges par aile, repliées puis déployées en éventail
	local wings = {}
	for _, side in { -1, 1 } do
		for i = 1, 6 do
			local len = 2.6 + i * 0.55
			local feather = wedge(scene, "WingFeather", Vector3.new(0.14, 0.75, len), CFrame.new(), i % 2 == 0 and Color3.fromRGB(235, 250, 255) or SKY, Enum.Material.Neon, 1)
			table.insert(wings, { part = feather, side = side, i = i, len = len })
		end
	end
	-- Plumes qui tombent en se balançant
	local rng = Random.new(11)
	local feathers = {}
	for i = 1, math.floor(36 * s) do
		local f = part(scene, "Feather", Vector3.new(0.08, 0.5, 0.26), CFrame.new(), WHITE, Enum.Material.SmoothPlastic, nil, 1)
		table.insert(feathers, {
			part = f,
			x = rng:NextNumber(-9, 9),
			z = rng:NextNumber(-8, 6),
			y0 = rng:NextNumber(14, 24),
			start = 1 + rng:NextNumber(0, 3),
			speed = rng:NextNumber(2.2, 3.4),
			phase = rng:NextNumber(0, 6.28),
			_ = i,
		})
	end
	scene.grade.TintColor = Color3.fromRGB(226, 240, 255)
	scene.grade.Brightness = 0.02
	scene.cameraKeys = TraitCinematic.celesteCamera(total)
	local landed, titled = false, false
	play(whoosh)
	table.insert(scene.steps, function(t)
		-- descente du faisceau (0 -> 0,9 s) : la colonne s'allonge du ciel vers le sol
		local d = smooth(t / 0.9)
		local bottom = 120 * (1 - d)
		local length = 160 - bottom
		local mid = bottom + length * 0.5
		beam.Size = Vector3.new(length, 4.2, 4.2)
		beam.CFrame = scene.stage * CFrame.new(0, mid, 0) * UPRIGHT
		beamGlow.Size = Vector3.new(length, 8 + math.sin(t * 6) * 0.4, 8 + math.sin(t * 6) * 0.4)
		beamGlow.CFrame = beam.CFrame
		if not landed and t >= 0.9 then
			landed = true
			flash(scene, WHITE, 0.9, 0.7)
			shake(scene, 0.8)
			play(ping)
		end
		local after = t - 0.9
		ring.Transparency = after < 0 and 1 or math.clamp(0.1 + after * 0.9, 0.1, 1)
		local rs = 4 + math.max(0, after) * 26
		ring.Size = Vector3.new(0.05, rs, rs)
		pool.Transparency = after < 0 and 1 or 0.45
		-- l'unité s'élève (1 -> 2,4 s) puis flotte
		local lift = smooth((t - 1) / 1.4) * LIFT + math.sin(t * 2) * 0.12 * smooth((t - 2.4) / 0.5)
		local body = scene.stage * CFrame.new(0, lift, 0)
		if scene.hero then
			placeAll(scene.heroBase, body)
		end
		-- auréole
		local hv = smooth((t - 1.6) / 0.6)
		for _, seg in haloSegs do
			local a = seg.a + t * 0.8
			seg.part.Transparency = 1 - hv * 0.9
			seg.part.CFrame = body * CFrame.new(math.cos(a) * 0.95, headTop + 0.9, math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0)
		end
		-- ailes (dos de l'unité : +Z, à hauteur des épaules), déploiement 1,8 -> 3 s puis battement
		local open = smooth((t - 1.8) / 1.2)
		local flap = math.sin(t * 2.4) * 0.08 * open
		local shoulder = headTop - 2.2
		for _, w in wings do
			local spread = (w.i - 1) / 5
			local angle = math.rad(-10 + spread * 62) * open + math.rad(4) + flap -- relève en éventail
			local sweep = math.rad(20 + spread * 14) * open + math.rad(6) -- s'écarte du dos
			w.part.Transparency = 1 - open * (0.25 + 0.08 * (w.i % 2))
			w.part.CFrame = body
				* CFrame.new(w.side * 0.6, shoulder, 0.75)
				* CFrame.Angles(0, w.side * (math.pi / 2 - sweep), 0)
				* CFrame.Angles(angle, 0, 0)
				* CFrame.new(0, 0, -w.len * 0.5)
		end
		-- plumes
		for _, f in feathers do
			local ft = t - f.start
			if ft < 0 then
				f.part.Transparency = 1
			else
				local y = f.y0 - ft * f.speed
				f.part.Transparency = y < 0.2 and 1 or 0.05
				f.part.CFrame = scene.stage
					* CFrame.new(f.x + math.sin(ft * 2 + f.phase) * 0.8, math.max(y, 0.1), f.z)
					* CFrame.Angles(math.sin(ft * 3 + f.phase) * 0.7, ft * 1.5, math.cos(ft * 2.5) * 0.6)
			end
		end
		if not titled and t >= 2.9 then
			titled = true
			traitTitle(scene, "celeste")
			play(fanfare)
		end
	end)
end

------------------------------------------------------------------------
-- MIDAS
------------------------------------------------------------------------

function TraitCinematic.midasCamera(total: number): { { any } }
	return {
		{ 0, Vector3.new(-6, 12, -14), Vector3.new(0, 3, 0), 58 },
		{ 1.6, Vector3.new(5, 5, -12), Vector3.new(0, 3.5, 0), 50 },
		{ 3, Vector3.new(1, 3.4, -12), Vector3.new(0, 4.4, 0), 46 },
		{ math.max(total, 3.5), Vector3.new(0, 3.2, -10.5), Vector3.new(0, 4.6, 0), 44 },
	}
end

local MIDAS_GOLD = Color3.fromRGB(255, 196, 52)

local function midasScene(scene)
	local total = scene.total
	local s = scene.low and 0.5 or 1
	spawnHero(scene, 1.2, 0)
	local headTop = scene.heroHeadTop or 6
	-- Les pièces de l'unité (pour la changer en or, des pieds à la tête)
	local heroParts = {}
	if scene.hero then
		for p in scene.heroBase do
			if p.Transparency < 1 then
				table.insert(heroParts, { part = p, color = p.Color, material = p.Material, y = (scene.heroPlace:ToObjectSpace(p.CFrame)).Position.Y })
			end
		end
	end
	-- Pluie de pièces d'or (tombent, tournent, rebondissent puis restent au sol)
	local rng = Random.new(5)
	local coins = {}
	for _ = 1, math.floor(70 * s) do
		local coin = part(scene, "Coin", Vector3.new(0.16, 1.1, 1.1), CFrame.new(), MIDAS_GOLD, Enum.Material.Metal, CYL, 1)
		coin.Reflectance = 0.25
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = math.sqrt(rng:NextNumber(0.02, 1)) * 9
		table.insert(coins, {
			part = coin,
			x = math.cos(angle) * radius,
			z = math.sin(angle) * radius,
			start = rng:NextNumber(0, 3.2),
			y0 = rng:NextNumber(16, 30),
			spin = rng:NextNumber(4, 10),
			tilt = rng:NextNumber(0, math.pi),
			yaw = rng:NextNumber(0, math.pi * 2),
		})
	end
	-- Tas d'or et lueur au sol
	local pool = part(scene, "GoldPool", Vector3.new(0.05, 10, 10), CFrame.new(0, 0.1, 0) * FLAT, Color3.fromRGB(255, 214, 90), Enum.Material.Neon, CYL, 1)
	light(pool, MIDAS_GOLD, 2.5, 20)
	local sparkle = emitter(pool, {
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 140)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Rate = 0,
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(2, 5),
		EmissionDirection = Enum.NormalId.Right,
		SpreadAngle = Vector2.new(40, 40),
	})
	local sweepRing = part(scene, "GoldSweep", Vector3.new(0.12, 3.6, 3.6), CFrame.new(0, 0.2, 0) * FLAT, Color3.fromRGB(255, 236, 150), Enum.Material.Neon, CYL, 1)
	scene.cameraKeys = TraitCinematic.midasCamera(total)
	local grade = scene.grade
	local swept, titled = false, false
	play(whoosh)
	table.insert(scene.steps, function(t)
		local gravity = 38
		for _, c in coins do
			local ct = t - c.start
			if ct < 0 then
				c.part.Transparency = 1
			else
				local fallTime = math.sqrt(2 * c.y0 / gravity)
				local y, rot
				if ct < fallTime then
					y = c.y0 - 0.5 * gravity * ct * ct
					rot = CFrame.Angles(c.tilt + ct * c.spin, c.yaw, 0)
				else
					-- petit rebond puis la pièce se couche à plat
					local bt = ct - fallTime
					local bounce = math.max(0, 1.6 * bt - 0.5 * gravity * bt * bt)
					y = 0.1 + bounce
					local lay = smooth(bt / 0.35)
					rot = CFrame.Angles(0, c.yaw, 0) * CFrame.Angles(0, 0, math.rad(90) * (1 - lay)) * FLAT:Lerp(CFrame.new(), 1 - lay)
				end
				c.part.Transparency = 0
				c.part.CFrame = scene.stage * CFrame.new(c.x, y, c.z) * rot
			end
		end
		-- l'unité se change en or (1,2 -> 2,6 s), une bague lumineuse monte le long du corps
		local g = smooth((t - 1.2) / 1.4)
		local height = g * (headTop + 0.5)
		sweepRing.Transparency = (g <= 0 or g >= 1) and 1 or 0.2
		sweepRing.CFrame = scene.stage * CFrame.new(0, height, 0) * FLAT
		for _, hp in heroParts do
			if hp.y <= height and not hp.gold then
				hp.gold = true
				local lum = hp.color.R * 0.3 + hp.color.G * 0.59 + hp.color.B * 0.11
				hp.part.Color = MIDAS_GOLD:Lerp(Color3.fromRGB(255, 244, 190), math.clamp(lum - 0.35, 0, 0.6))
				hp.part.Material = Enum.Material.Metal
				pcall(function()
					hp.part.Reflectance = 0.25
				end)
			end
		end
		if not swept and t >= 2.6 then
			swept = true
			flash(scene, Color3.fromRGB(255, 220, 110), 0.9, 0.8)
			shake(scene, 0.8)
			pcall(function()
				sparkle:Emit(scene.low and 30 or 60)
			end)
			play(fanfare)
		end
		-- tout l'écran devient doré un instant (2,4 -> 4,4 s)
		local golden = math.clamp(math.min((t - 2.4) / 0.35, (4.6 - t) / 0.8), 0, 1)
		grade.TintColor = WHITE:Lerp(Color3.fromRGB(255, 214, 120), golden)
		grade.Saturation = 0.1 + 0.25 * golden
		grade.Brightness = 0.06 * golden
		pool.Transparency = 1 - 0.55 * smooth((t - 1) / 1)
		if not titled and t >= 2.8 then
			titled = true
			traitTitle(scene, "midas")
		end
	end)
end

------------------------------------------------------------------------
-- VAMPIRE
------------------------------------------------------------------------

function TraitCinematic.vampireCamera(total: number): { { any } }
	return {
		{ 0, Vector3.new(0, 1.6, -22), Vector3.new(0, 9, 30), 56 },
		{ 1.6, Vector3.new(-3, 2.2, -16), Vector3.new(0, 6, 10), 50 },
		{ 3, Vector3.new(-1, 2.6, -12.5), Vector3.new(0, 5, 0), 46 },
		{ math.max(total, 3.5), Vector3.new(0, 2.6, -11), Vector3.new(0, 5.2, 0), 44 },
	}
end

local BLOOD = Color3.fromRGB(150, 12, 32)

local function vampireScene(scene)
	local total = scene.total
	local s = scene.low and 0.5 or 1
	spawnHero(scene, 1.2, 0)
	local headTop = scene.heroHeadTop or 6
	-- La lune rouge se lève derrière l'unité (loin dans le ciel)
	local moon = part(scene, "BloodMoon", Vector3.new(46, 46, 46), CFrame.new(0, 20, 210), Color3.fromRGB(210, 40, 46), Enum.Material.Neon, Enum.PartType.Ball, 1)
	local moonHalo = part(scene, "MoonHalo", Vector3.new(70, 70, 70), CFrame.new(0, 20, 215), Color3.fromRGB(150, 20, 40), Enum.Material.Neon, Enum.PartType.Ball, 1)
	-- Cape (dos de l'unité : +Z) : extérieur noir, doublure rouge, col relevé
	local shoulder = headTop - 2.25
	local cape = part(scene, "Cape", Vector3.new(2.6, 3.6, 0.12), CFrame.new(), Color3.fromRGB(20, 12, 18), Enum.Material.Fabric, nil, 1)
	local lining = part(scene, "CapeLining", Vector3.new(2.4, 3.4, 0.08), CFrame.new(), BLOOD, Enum.Material.Fabric, nil, 1)
	local collar = {}
	for _, side in { -1, 1 } do
		table.insert(collar, { side = side, part = wedge(scene, "Collar", Vector3.new(0.1, 1.1, 0.9), CFrame.new(), BLOOD, Enum.Material.Fabric, 1) })
	end
	-- Brume rouge au sol
	local mistParts = {}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local anchor = part(scene, "Mist", Vector3.new(1, 1, 1), CFrame.new(math.cos(a) * 5, 0.6, math.sin(a) * 5), BLOOD, Enum.Material.SmoothPlastic, nil, 1)
		local e = emitter(anchor, {
			Texture = SMOKE_TEX,
			LightEmission = 0.2,
			Color = ColorSequence.new(Color3.fromRGB(120, 20, 40), Color3.fromRGB(40, 10, 30)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new(4, 8),
			Rate = 0,
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(70, 10),
			RotSpeed = NumberRange.new(-20, 20),
		})
		table.insert(mistParts, e)
	end
	local glowPool = part(scene, "BloodPool", Vector3.new(0.05, 8, 8), CFrame.new(0, 0.1, 0) * FLAT, Color3.fromRGB(200, 20, 40), Enum.Material.Neon, CYL, 1)
	light(glowPool, Color3.fromRGB(255, 40, 60), 2, 16)
	-- Chauves-souris : corps + deux ailes qui battent ; elles jaillissent de l'unité puis tournoient
	local rng = Random.new(3)
	local bats = {}
	for _ = 1, math.floor(16 * s) do
		local body = part(scene, "BatBody", Vector3.new(0.5, 0.5, 0.7), CFrame.new(), Color3.fromRGB(20, 14, 22), Enum.Material.SmoothPlastic, Enum.PartType.Ball, 1)
		local wingL = wedge(scene, "BatWing", Vector3.new(0.06, 0.55, 1.3), CFrame.new(), Color3.fromRGB(34, 18, 30), Enum.Material.SmoothPlastic, 1)
		local wingR = wedge(scene, "BatWing", Vector3.new(0.06, 0.55, 1.3), CFrame.new(), Color3.fromRGB(34, 18, 30), Enum.Material.SmoothPlastic, 1)
		table.insert(bats, {
			body = body,
			wings = { wingL, wingR },
			radius = rng:NextNumber(3.5, 9),
			height = rng:NextNumber(2, 10),
			speed = rng:NextNumber(1.4, 2.4) * (rng:NextNumber() < 0.5 and -1 or 1),
			phase = rng:NextNumber(0, math.pi * 2),
			flap = rng:NextNumber(16, 22),
			start = 0.9 + rng:NextNumber(0, 0.5),
		})
	end
	scene.cameraKeys = TraitCinematic.vampireCamera(total)
	local grade = scene.grade
	local burst, titled = false, false
	play(whoosh)
	table.insert(scene.steps, function(t)
		-- la nuit tombe (0 -> 1,2 s) : image plus sombre et rouge
		local night = smooth(t / 1.2)
		grade.Brightness = -0.16 * night
		grade.Contrast = 0.18 * night
		grade.Saturation = -0.25 * night
		grade.TintColor = WHITE:Lerp(Color3.fromRGB(255, 176, 176), night)
		-- la lune se lève
		local m = smooth(t / 1.8)
		moon.Transparency = 1 - m
		moonHalo.Transparency = 1 - m * 0.18
		moon.CFrame = scene.stage * CFrame.new(0, 20 + m * 45, 210)
		moonHalo.CFrame = scene.stage * CFrame.new(0, 20 + m * 45, 215)
		-- brume
		for _, e in mistParts do
			e.Rate = (t > 0.4 and 6 or 0) * s
		end
		glowPool.Transparency = 1 - 0.6 * night
		-- cape qui se déploie (1 -> 2 s) puis ondule
		local c = smooth((t - 1) / 1)
		local sway = math.sin(t * 2.2) * 0.06
		local back = scene.stage * CFrame.new(0, shoulder, 0.62) * CFrame.Angles(math.rad(8 + 14 * c) + sway, 0, 0)
		cape.Transparency = 1 - c
		lining.Transparency = 1 - c
		cape.Size = Vector3.new(2.2 + 1.2 * c, 3.6, 0.12)
		cape.CFrame = back * CFrame.new(0, -1.8, 0.06)
		lining.CFrame = back * CFrame.new(0, -1.8, -0.02)
		for _, k in collar do
			k.part.Transparency = 1 - c
			k.part.CFrame = scene.stage * CFrame.new(k.side * 0.75, shoulder + 0.45, 0.35) * CFrame.Angles(0, k.side * math.rad(30), 0) * CFrame.Angles(math.rad(-15), 0, 0)
		end
		if not burst and t >= 0.9 then
			burst = true
			flash(scene, Color3.fromRGB(180, 0, 30), 0.7, 0.6)
			shake(scene, 0.7)
			play(ping)
		end
		-- chauves-souris
		for _, b in bats do
			local bt = t - b.start
			if bt < 0 then
				b.body.Transparency = 1
				b.wings[1].Transparency = 1
				b.wings[2].Transparency = 1
			else
				local out = smooth(bt / 0.6)
				local a = b.phase + bt * b.speed
				local leave = smooth((t - (total - 1.2)) / 1)
				local r = b.radius * out + leave * 30
				local pos = Vector3.new(math.cos(a) * r, 3 + (b.height - 3) * out + math.sin(bt * 3 + b.phase) * 0.6 + leave * 14, math.sin(a) * r)
				local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * (b.speed > 0 and 1 or -1)
				local cf = scene.stage * CFrame.lookAt(pos, pos + tangent)
				local wing = math.sin(bt * b.flap) * 0.9
				b.body.Transparency = 0
				b.body.CFrame = cf
				b.wings[1].Transparency = 0
				b.wings[2].Transparency = 0
				b.wings[1].CFrame = cf * CFrame.Angles(0, 0, wing) * CFrame.new(-0.65, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
				b.wings[2].CFrame = cf * CFrame.Angles(0, 0, -wing) * CFrame.new(0.65, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
			end
		end
		if not titled and t >= 2.6 then
			titled = true
			traitTitle(scene, "vampire")
			play(fanfare)
		end
	end)
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

local SCENES = { monarch = monarchScene, celeste = celesteScene, midas = midasScene, vampire = vampireScene }

-- Joue la cinématique `kind` ("monarch", "celeste", "midas", "vampire") pour l'unité `entry`.
-- options : duration, clock (horloge simulée pour les tests), stage (CFrame forcé), onDone.
-- Renvoie la scène : { folder, gui, root, hero, finish(), finished, total }.
function TraitCinematic.play(kind: string, entry, desc, options)
	local build = SCENES[kind]
	if not build then
		return nil
	end
	local opts = options or {}
	local scene = begin(kind, entry, desc, { duration = opts.duration, stage = opts.stage, uid = opts.uid, radius = kind == "monarch" and 14 or 10 })
	if opts.onDone then
		table.insert(scene.onDone, opts.onDone)
	end
	local ok, err = pcall(build, scene)
	if not ok then
		warn("[TraitCinematic] " .. tostring(err))
		finishScene(scene)
		return scene
	end
	run(scene, opts.clock)
	return scene
end

-- Joue la cinématique du trait `traitId` s'il en a une (sinon ne fait rien et renvoie nil).
function TraitCinematic.playTrait(traitId: string?, entry, desc, options)
	local kind = Traits.cinematicOf(traitId)
	if not kind then
		return nil
	end
	return TraitCinematic.play(kind, entry, desc, options)
end

function TraitCinematic.isPlaying(): boolean
	return current ~= nil and not current.finished
end

function TraitCinematic.current()
	return current
end

function TraitCinematic.skip()
	if current then
		finishScene(current)
	end
end

-- Attend la fin de la cinématique en cours (au plus `timeout` secondes).
function TraitCinematic.wait(timeout: number?)
	local limit = os.clock() + (timeout or 12)
	while current and not current.finished and os.clock() < limit do
		task.wait(0.1)
	end
end

-- Relances lancées par l'écran des Traits : il joue lui-même la révélation au bon moment
-- (après le rouleau). Les autres résultats reçus du serveur sont joués directement ici.
local claimed: { [string]: number } = {}
function TraitCinematic.claim(uid: string)
	claimed[uid] = os.clock()
end

function TraitCinematic.init()
	local remote = State.remoteEvent("TraitRolled")
	if not remote then
		return
	end
	remote.OnClientEvent:Connect(function(info)
		if type(info) ~= "table" or type(info.uid) ~= "string" then
			return
		end
		local at = claimed[info.uid]
		if at and os.clock() - at < 15 then
			claimed[info.uid] = nil
			return
		end
		local kind = Traits.cinematicOf(info.traitId)
		if not kind then
			return
		end
		local entry = State.data and State.data.characters[info.uid]
		local desc = entry and Formulas.describe(entry)
		if entry and desc then
			local copy = table.clone(entry)
			copy.uid = info.uid
			TraitCinematic.play(kind, copy, desc)
		end
	end)
end

return TraitCinematic
