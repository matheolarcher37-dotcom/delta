-- ROULETTE de la machine ROULER (v3.4), SUR L'ESTRADE : au roulage, à la place du perso tiré,
-- d'autres persos apparaissent tour à tour sur sa case (vite, puis de plus en plus lentement,
-- comme la bille d'une roulette de casino) et ça s'arrête sur le perso tiré. Rien à l'écran : on
-- regarde l'estrade. Une case par perso tiré (x2, x3 : arrêts décalés).
--   • durée : payload.spin (Formulas.rollSpinTime : plus court en auto-roulage, toujours plus
--     court que la recharge de la machine) ;
--   • pendant la roulette, le vrai perso tiré est caché (descendu sous le sol, côté client
--     seulement) et son invite « Collecter » hors de portée : rien n'est dévoilé avant l'arrêt.
--     Le serveur retarde de même les lumières de l'estrade et l'annonce aux autres joueurs ;
--   • les persos qui défilent sont ceux de l'univers du roulage (construits une fois, gardés en
--     réserve : RollSpin.prewarm les prépare quand on arrive à la machine).
-- Loin de la machine (auto-roulage), pas de défilé : RollReveal montre les cartes tout de suite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Economy = require(Shared.Config.Economy)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local CharacterFactory = require(Shared.Modules.CharacterFactory)

local RollSpin = {}

local player = Players.LocalPlayer

RollSpin.Lead = 14 -- persos qui défilent avant le perso tiré
RollSpin.Stagger = 0.3 -- x2 / x3 : écart entre les arrêts de deux cases
RollSpin.Hold = 0.15 -- petite pause après l'arrêt avant la suite (bandeau, annonce)
RollSpin.FolderName = "RouletteEstrade"
-- Raretés des persos qui défilent (un peu de Légendaire / Mythique pour le suspense).
RollSpin.FillerWeights = { common = 40, rare = 30, epic = 16, legendary = 9, mythic = 4, secret = 1 }
RollSpin.TeaseChance = 0.35 -- une grosse rareté juste avant l'arrêt (« presque ! »)

local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxasset://sounds/clickfast.wav"
tickSound.Volume = 0.22
tickSound.Parent = SoundService

local stopSound = Instance.new("Sound")
stopSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
stopSound.Volume = 0.4
stopSound.Parent = SoundService

------------------------------------------------------------------------
-- État : persos en attente de l'arrêt
------------------------------------------------------------------------

local pendingKeys: { [string]: boolean } = {}
local listeners: { () -> () } = {}
local current: { id: number, finish: () -> () }? = nil
local serial = 0
local shown = 0 -- persos montrés sur l'estrade depuis le début (pour les tests)
local history: { string } = {} -- persos montrés par la dernière roulette, dans l'ordre

-- Vrai tant que la roulette de ce perso tourne (son modèle reste caché).
function RollSpin.isPending(key: any): boolean
	return type(key) == "string" and pendingKeys[key] == true
end

-- Vrai si une roulette tourne sur l'estrade.
function RollSpin.active(): boolean
	return current ~= nil
end

-- Nombre de persos montrés sur l'estrade par les roulettes (depuis le lancement du jeu).
function RollSpin.shownCount(): number
	return shown
end

-- Persos (ids) montrés sur l'estrade par la dernière roulette, dans l'ordre d'apparition.
function RollSpin.lastShown(): { string }
	return table.clone(history)
end

-- `fn` est appelé au départ et à l'arrêt de chaque roulette.
function RollSpin.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

local function notify()
	for _, fn in listeners do
		task.spawn(pcall, fn)
	end
end

------------------------------------------------------------------------
-- Estrade de ma base
------------------------------------------------------------------------

local function myPlot(): Instance?
	local index = player and player:GetAttribute("PlotIndex")
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	return plots and index ~= nil and plots:FindFirstChild("Plot" .. tostring(index)) or nil
end

local function rolledFolder(): Instance?
	local plot = myPlot()
	return plot and plot:FindFirstChild("Rolled")
end

-- Repère d'une case de l'estrade (pieds du perso), d'après sa plaque « Place<i> » (TycoonMachine).
function RollSpin.spotCFrame(i: number): CFrame?
	local plot = myPlot()
	local interactive = plot and plot:FindFirstChild("Interactive")
	local machine = interactive and interactive:FindFirstChild("RollMachine")
	local plate = machine and machine:FindFirstChild("Place" .. i)
	if not plate or not plate:IsA("BasePart") then
		return nil
	end
	return plate.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -0.05, 0)
end

-- Le vrai perso tiré est caché (côté client) jusqu'à l'arrêt.
local HIDE_DROP = Vector3.new(0, -400, 0)
local hidden: { [Model]: { home: CFrame, low: CFrame } } = {}
local watch: RBXScriptConnection? = nil

local function hideModel(model: Instance)
	if not model:IsA("Model") or hidden[model] then
		return
	end
	local ok, home = pcall(model.GetPivot, model)
	if not ok then
		return
	end
	local low = home + HIDE_DROP
	hidden[model] = { home = home, low = low }
	pcall(model.PivotTo, model, low)
end

local function showModel(model: Model)
	local info = hidden[model]
	hidden[model] = nil
	if not info or not model.Parent then
		return
	end
	-- (si le serveur l'a déplacé entre-temps, il est déjà à sa vraie place : on n'y touche pas)
	local ok, now = pcall(model.GetPivot, model)
	if ok and (now.Position - info.low.Position).Magnitude < 0.05 then
		pcall(model.PivotTo, model, info.home)
	end
end

local function keyOf(model: Instance): string?
	local name = model.Name
	if string.sub(name, 1, 5) == "Tire_" then
		return string.sub(name, 6)
	end
	return nil
end

local function hidePending()
	local folder = rolledFolder()
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		local key = keyOf(model)
		if key and pendingKeys[key] then
			hideModel(model)
		end
	end
	if watch then
		watch:Disconnect()
	end
	-- (le modèle peut arriver juste après le message du serveur)
	watch = folder.ChildAdded:Connect(function(model)
		local key = keyOf(model)
		if key and pendingKeys[key] then
			hideModel(model)
		end
	end)
end

-- Dévoile les persos `keys` (et tout modèle caché qui n'est plus en attente).
local function revealKeys(keys: { string })
	for _, key in keys do
		pendingKeys[key] = nil
	end
	for model in hidden do
		local key = keyOf(model)
		if not key or not pendingKeys[key] then
			showModel(model)
		end
	end
	if next(pendingKeys) == nil and watch then
		watch:Disconnect()
		watch = nil
	end
end

------------------------------------------------------------------------
-- Persos qui défilent
------------------------------------------------------------------------

local function weightedRarity(pools, rng: Random, weights): string
	local total = 0
	for rarity, weight in weights do
		if pools[rarity] and #pools[rarity] > 0 then
			total += weight
		end
	end
	if total <= 0 then
		return "common"
	end
	local pick = rng:NextNumber() * total
	for _, rarity in { "common", "rare", "epic", "legendary", "mythic", "secret" } do
		local weight = weights[rarity]
		if weight and pools[rarity] and #pools[rarity] > 0 then
			pick -= weight
			if pick <= 0 then
				return rarity
			end
		end
	end
	return "common"
end

-- Suite des persos d'une case : Lead persos de l'univers du roulage (ceux que la machine peut
-- vraiment donner, jamais deux fois le même d'affilée), puis le perso tiré.
function RollSpin.sequence(result, universeId: string?, seed: number?)
	local rng = Random.new(seed or os.clock() * 1000)
	local universe = Universes.get(universeId or "") or Universes.List[1]
	local pools = Formulas.rollPools(universe.id)
	local list = {}
	local function filler(previous: string?, weights)
		local rarity = weightedRarity(pools, rng, weights)
		local pool = pools[rarity]
		if not pool or #pool == 0 then
			return { id = result.id, rarity = result.rarity }
		end
		local id = pool[rng:NextInteger(1, #pool)]
		if id == previous and #pool > 1 then
			id = pool[(table.find(pool, id) :: number) % #pool + 1]
		end
		return { id = id, rarity = rarity }
	end
	for i = 1, RollSpin.Lead do
		list[i] = filler(list[i - 1] and list[i - 1].id, RollSpin.FillerWeights)
	end
	-- « Presque ! » : une grosse rareté juste avant l'arrêt (si elle existe dans l'univers).
	if rng:NextNumber() < RollSpin.TeaseChance then
		local tease = filler(list[RollSpin.Lead - 1] and list[RollSpin.Lead - 1].id, { legendary = 3, mythic = 2, secret = 1 })
		if tease.rarity ~= "common" and tease.id ~= result.id then
			list[RollSpin.Lead] = tease
		end
	end
	list[RollSpin.Lead + 1] = { id = result.id, rarity = result.rarity or "common", winner = true }
	return list
end

-- Moments d'apparition des persos (0 → durée) : vite au début, de plus en plus lent (la k-ième
-- apparition quand une « bille » qui freine passe la case k). Le dernier = l'arrêt.
function RollSpin.schedule(count: number, duration: number): { number }
	local times = {}
	for k = 1, count do
		times[k] = duration * (1 - (1 - (k - 1) / (count - 1)) ^ (1 / 3))
	end
	return times
end

-- Réserve de modèles (un par perso, cloné à chaque apparition).
local templates: { [string]: Model } = {}
local failed: { [string]: boolean } = {} -- persos impossibles à construire (on ne réessaie pas)
local templateUniverse: string? = nil

local function templateFor(id: string): Model?
	local cached = templates[id]
	if cached then
		return cached
	end
	local def = Characters.get(id)
	if not def then
		return nil
	end
	local entry = { id = id, level = 1, xp = 0, stars = 1 }
	local okDesc, desc = pcall(Formulas.describe, entry)
	if not okDesc or not desc then
		return nil
	end
	local ok, model = pcall(CharacterFactory.build, id, 1, desc.look, { scale = Formulas.visualScale(entry), anchored = true, name = def.name })
	if not ok or not model then
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	templates[id] = model
	return model
end

-- Prépare (une par image) les persos de l'univers : la roulette n'a plus qu'à les cloner.
-- (un nouvel univers demandé pendant la préparation la redirige aussitôt)
local warming = false
local warmTarget = Universes.List[1]
function RollSpin.prewarm(universeId: string?)
	local universe = Universes.get(universeId or "") or Universes.List[1]
	warmTarget = universe
	if templateUniverse ~= universe.id then
		-- autre univers : on ne garde que les persos de celui-ci (réserve légère)
		for id, model in templates do
			if not table.find(universe.characters, id) then
				model:Destroy()
				templates[id] = nil
			end
		end
		templateUniverse = universe.id
	end
	if warming then
		return
	end
	warming = true
	task.spawn(function()
		while true do
			local missing = nil
			for _, id in warmTarget.characters do
				if not templates[id] and Characters.get(id) and not failed[id] then
					missing = id
					break
				end
			end
			if not missing then
				break
			end
			if not templateFor(missing) then
				failed[missing] = true
			end
			task.wait()
		end
		warming = false
	end)
end

-- Vrai quand tous les persos de l'univers sont prêts (RollSpin.prewarm terminé).
function RollSpin.isWarm(universeId: string?): boolean
	local universe = Universes.get(universeId or "") or Universes.List[1]
	for _, id in universe.characters do
		if not templates[id] and Characters.get(id) and not failed[id] then
			return false
		end
	end
	return true
end

local function stageFolder(): Folder
	local folder = workspace:FindFirstChild(RollSpin.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RollSpin.FolderName
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Lumière de la case (côté client) : un éclair de la couleur de la rareté à chaque perso.
local function spotLight(cf: CFrame): (Part, PointLight)
	local holder = Instance.new("Part")
	holder.Name = "Lumiere"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = cf * CFrame.new(0, 3, -2)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	holder.Parent = stageFolder()
	return holder, light
end

local function rarityColor(rarityId: string?): Color3
	local info = Economy.RollRarities[rarityId or "common"]
	return info and info.color or Color3.new(1, 1, 1)
end

------------------------------------------------------------------------
-- Roulette
------------------------------------------------------------------------

-- Joue la roulette des persos de `payload.results` sur l'estrade (case i = perso tiré i), puis
-- appelle `onDone` à l'arrêt de la dernière case. Sans durée (payload.spin) ou loin de la
-- machine (`atMachine` faux) : `onDone` tout de suite. Une nouvelle roulette (ou RollSpin.finish)
-- termine aussitôt la précédente.
function RollSpin.play(payload, atMachine: boolean, onDone: (() -> ())?)
	if current then
		current.finish()
	end
	local results = payload.results or {}
	local spin = tonumber(payload.spin) or 0
	if spin <= 0 or #results == 0 or not atMachine or not RollSpin.spotCFrame(1) then
		if onDone then
			onDone()
		end
		return
	end
	serial += 1
	local id = serial
	table.clear(history)
	-- (horloge prise avant toute construction : la roulette dure `spin` en tout, comme le serveur
	-- le compte pour les lumières de l'estrade)
	local started = os.clock()
	local keys = {}
	for _, result in results do
		if type(result.key) == "string" then
			pendingKeys[result.key] = true
			table.insert(keys, result.key)
		end
	end
	pcall(hidePending)
	RollSpin.prewarm(payload.universe)
	notify()
	local cases = {}
	local n = math.min(#results, 3)
	for i = 1, n do
		local cf = RollSpin.spotCFrame(i)
		if cf then
			local list = RollSpin.sequence(results[i], payload.universe, (os.clock() * 1000 + i * 7919 + id * 31) % 2 ^ 31)
			local duration = math.max(0.4, spin - (n - i) * RollSpin.Stagger)
			local holder, light = spotLight(cf)
			table.insert(cases, {
				cf = cf,
				list = list,
				times = RollSpin.schedule(RollSpin.Lead + 1, duration),
				duration = duration,
				step = 0,
				model = nil :: Model?,
				holder = holder,
				light = light,
				key = results[i].key,
				done = false,
			})
		end
	end
	local finished = false
	-- Montre le k-ième perso d'une case (le dernier = le vrai perso tiré, dévoilé).
	local function showStep(case, k: number)
		if case.done or k <= case.step then
			return
		end
		case.step = k
		if case.model then
			case.model:Destroy()
			case.model = nil
		end
		local item = case.list[k]
		local color = rarityColor(item.rarity)
		case.light.Color = color
		if item.winner then
			case.done = true
			if type(case.key) == "string" then
				revealKeys({ case.key })
			end
			case.light.Brightness = 3
			SoundService:PlayLocalSound(stopSound)
			return
		end
		local template = templateFor(item.id)
		if template then
			local clone = template:Clone()
			clone.Name = "Defile_" .. item.id
			local rootHeight = CharacterFactory.rootHeight(clone)
			pcall(clone.PivotTo, clone, case.cf * CFrame.new(0, rootHeight, 0))
			clone.Parent = stageFolder()
			case.model = clone
			shown += 1
			table.insert(history, item.id)
		end
		case.light.Brightness = 2.2
		SoundService:PlayLocalSound(tickSound)
	end
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, case in cases do
			showStep(case, RollSpin.Lead + 1)
			if case.model then
				case.model:Destroy()
				case.model = nil
			end
			case.holder:Destroy()
		end
		if current and current.id == id then
			current = nil
		end
		revealKeys(keys)
		notify()
		if onDone then
			task.spawn(onDone)
		end
	end
	current = { id = id, finish = finish }
	-- Chaque case suit son horaire (fil à part : même sans images, la roulette avance à l'heure).
	for _, case in cases do
		task.spawn(function()
			for k = 1, RollSpin.Lead + 1 do
				local delay = case.times[k] - (os.clock() - started)
				if delay > 0 then
					task.wait(delay)
				end
				if finished then
					return
				end
				showStep(case, k)
				-- l'éclair retombe entre deux persos
				local light = case.light
				task.delay(0.08, function()
					if light.Parent and not case.done then
						light.Brightness = 0.6
					end
				end)
			end
		end)
	end
	local longest = 0
	for _, case in cases do
		longest = math.max(longest, case.duration)
	end
	task.delay(math.max(0, started + longest - os.clock()) + RollSpin.Hold, finish)
end

-- Termine tout de suite la roulette en cours (persos dévoilés).
function RollSpin.finish()
	if current then
		current.finish()
	end
end

return RollSpin
