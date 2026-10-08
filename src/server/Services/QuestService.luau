-- DÉFIS (permanents à paliers + quotidiens), GEMMES DE TRAIT et ZONE ANTI-AFK (punching-balls).
--
-- • Les compteurs (kills par ennemi, boss, coups de punching-ball, relances de trait...) sont tenus
--   ici, côté serveur, dans data.Quests.counters ; les autres (roulages, évolutions, pièces...)
--   sont lus directement dans la sauvegarde (Config/Quests : Quests.read).
-- • Quand un palier est atteint, le joueur est prévenu (bandeau + suivi à l'écran) et va réclamer
--   sa récompense dans l'écran Défis (remote QuestClaim / QuestClaimAll).
-- • Les défis quotidiens sont tirés chaque jour (minuit UTC), différents pour chaque joueur.
-- • Zone anti-AFK : 3 punching-balls, un par joueur à la fois (réservé à celui qui tape, libéré
--   quand il s'en va). Coups comptés ici avec une cadence plafonnée (anti-triche) ; 1000 coups =
--   20 gemmes de trait, données palier par palier. Les sacs ne font jamais de dégâts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Layout = require(Shared.Config.Layout)
local Remotes = require(Shared.Modules.Remotes)
local AfkZone = require(script.Parent.Parent.World.AfkZone)

local QuestService = {}

local Notify = Remotes.event("Notify")
local Reward = Remotes.event("Reward")
local QuestNotify = Remotes.event("QuestNotify")

local PUNCH = Quests.Punch

-- État en mémoire (non sauvegardé)
local dirty: { [Player]: { [string]: boolean } } = {} -- compteurs modifiés depuis la dernière vérification
local buckets: { [Player]: { [string]: number } } = {} -- dernier quart de progression annoncé par défi
local lastPunch: { [Player]: number } = {}
local busyWarned: { [Player]: number } = {}
local stations: { [Model]: { owner: Player?, lastHit: number, farSince: number? } } = {}
local stationList: { Model } = {}

function QuestService:Init(services)
	self.services = services
end

------------------------------------------------------------------------
-- Données
------------------------------------------------------------------------

-- Garantit la structure de data.Quests (sauvegardes anciennes ou abîmées).
local function ensure(data)
	if type(data.Quests) ~= "table" then
		data.Quests = {}
	end
	local q = data.Quests
	for _, key in { "counters", "claimed", "notified", "daily" } do
		if type(q[key]) ~= "table" then
			q[key] = {}
		end
	end
	for _, key in { "list", "base", "claimed", "goals" } do
		if type(q.daily[key]) ~= "table" then
			q.daily[key] = {}
		end
	end
	q.daily.day = tonumber(q.daily.day) or 0
	q.punch = tonumber(q.punch) or 0
	return q
end
QuestService.ensure = ensure

-- Nouveaux défis du jour si la journée a changé. Renvoie vrai si renouvelés.
function QuestService:_refreshDaily(player: Player, data): boolean
	local q = ensure(data)
	local today = Quests.day(os.time())
	if q.daily.day == today and #q.daily.list > 0 then
		return false
	end
	local list = Quests.pickDaily(today, player.UserId)
	local base, goals = {}, {}
	local income = tonumber(player:GetAttribute("IncomePerSec")) or 0
	for _, id in list do
		local daily = Quests.DailyById[id]
		if daily then
			base[daily.key] = Quests.read(data, daily.key)
			goals[id] = Quests.dailyGoalFor(daily, income)
		end
	end
	q.daily = { day = today, list = list, base = base, goals = goals, claimed = {}, bonus = false }
	return true
end

-- Le revenu du joueur peut être calculé juste après le tirage (au chargement) : tant qu'un défi
-- de pièces du jour n'a ni progressé ni été réclamé, son objectif suit le revenu actuel.
function QuestService:_adjustIncomeGoals(player: Player, data)
	local q = ensure(data)
	local income = tonumber(player:GetAttribute("IncomePerSec")) or 0
	if income <= 0 then
		return
	end
	for _, id in q.daily.list do
		local daily = Quests.DailyById[id]
		if daily and daily.incomeMinutes and not q.daily.claimed[id] then
			local wanted = Quests.dailyGoalFor(daily, income)
			local current = tonumber(q.daily.goals[id]) or daily.goal
			local progress = Quests.dailyProgress(data, id)
			if wanted > current and progress < current * 0.05 then
				q.daily.goals[id] = wanted
			end
		end
	end
end

-- Incrémente un compteur de défi.
function QuestService:Add(player: Player, key: string, amount: number?)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local q = ensure(data)
	q.counters[key] = (tonumber(q.counters[key]) or 0) + (amount or 1)
	dirty[player] = dirty[player] or {}
	dirty[player][key] = true
end

function QuestService:Count(player: Player, key: string): number
	local data = self.services.DataService:Get(player)
	return data and Quests.read(data, key) or 0
end

-- Donne des gemmes de trait (= Cristaux de Trait, 1 gemme = 1 relance).
function QuestService:GrantGems(player: Player, amount: number, position: Vector3?, countForQuests: boolean?)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	data.traitCrystals = (tonumber(data.traitCrystals) or 0) + amount
	Reward:FireClient(player, "crystal", amount, position)
	if countForQuests ~= false then
		self:Add(player, "gems", amount)
	end
	DataService:Sync(player)
end

------------------------------------------------------------------------
-- Événements de jeu (appelés par CombatService, TraitService, SwordService)
------------------------------------------------------------------------

function QuestService:OnEnemyKilled(player: Player, record, info)
	if not record then
		return
	end
	self:Add(player, "kill")
	self:Add(player, "kill:" .. tostring(record.defId))
	local universe = self.services.UniverseService and self.services.UniverseService:GetCurrent()
	if universe then
		self:Add(player, "killu:" .. universe.id)
	end
	if (record.tier or 1) >= 3 then
		self:Add(player, "elite")
	end
	if info and info.sword then
		self:Add(player, "swordkill")
	end
end

function QuestService:OnBossKilled(player: Player, record)
	self:Add(player, "boss")
	if record and record.defId then
		self:Add(player, "boss:" .. tostring(record.defId))
	end
	local universe = self.services.UniverseService and self.services.UniverseService:GetCurrent()
	if universe then
		self:Add(player, "killu:" .. universe.id)
	end
end

function QuestService:OnTraitReroll(player: Player)
	self:Add(player, "reroll")
end

------------------------------------------------------------------------
-- Récompenses
------------------------------------------------------------------------

local evolutionItems = nil
local function itemConfig()
	if evolutionItems == nil then
		evolutionItems = false
		local config = Shared:FindFirstChild("Config")
		local module = config and config:FindFirstChild("EvolutionItems")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				evolutionItems = result
			end
		end
	end
	return evolutionItems or nil
end

-- Nom d'un objet du marchand (ou nil s'il n'existe pas dans ce jeu).
local function itemInfo(itemId: string)
	local config = itemConfig()
	if config and type(config.get) == "function" then
		local ok, item = pcall(config.get, itemId)
		if ok and type(item) == "table" then
			return item
		end
	end
	return nil
end

local function fallbackCoins(itemId: string): number
	for _, list in Quests.UniverseItems do
		local index = table.find(list, itemId)
		if index then
			return Quests.ItemFallbackCoins[index] or 5000
		end
	end
	return 5000
end

-- Applique une récompense ; renvoie le texte « +1 000 ¥, +2 gemmes ».
function QuestService:GiveReward(player: Player, reward): string
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(reward) ~= "table" then
		return ""
	end
	local parts = {}
	-- pièces adaptées au revenu du joueur (minimum = valeur de base du défi)
	local coins = Quests.rewardCoins(reward, player:GetAttribute("IncomePerSec"))
	if type(reward.items) == "table" then
		for itemId, amount in reward.items do
			local item = itemInfo(itemId)
			if item then
				if type(data.Items) ~= "table" then
					data.Items = {}
				end
				data.Items[itemId] = (tonumber(data.Items[itemId]) or 0) + amount
				table.insert(parts, "+" .. amount .. " " .. tostring(item.name or itemId))
			else
				coins += fallbackCoins(itemId) * amount -- objet inconnu : des pièces à la place
			end
		end
	end
	if coins > 0 then
		DataService:AddCoins(player, coins)
		Reward:FireClient(player, "coins", coins, nil)
		table.insert(parts, 1, "+" .. Quests.formatNumber(coins) .. " ¥")
	end
	if (reward.gems or 0) > 0 then
		self:GrantGems(player, reward.gems, nil, false)
		table.insert(parts, math.min(#parts + 1, 2), "+" .. reward.gems .. " gemme" .. (reward.gems > 1 and "s" or "") .. " de trait")
	end
	DataService:Sync(player)
	return table.concat(parts, ", ")
end

------------------------------------------------------------------------
-- Réclamer
------------------------------------------------------------------------

local dailyReady = Quests.dailyReady
local bonusReady = Quests.bonusReady

function QuestService:Claim(player: Player, id: any): (boolean, string)
	local data = self.services.DataService:Get(player)
	if not data or type(id) ~= "string" then
		return false, "Erreur."
	end
	self:_refreshDaily(player, data)
	local q = ensure(data)
	if id == "bonus" then
		if q.daily.bonus then
			return false, "Coffre du jour déjà ouvert : reviens demain !"
		end
		if not bonusReady(data) then
			return false, "Réclame d'abord les " .. Quests.DailyCount .. " défis du jour."
		end
		q.daily.bonus = true
		local text = self:GiveReward(player, Quests.DailyBonus)
		return true, "Coffre du jour : " .. text
	end
	local daily = Quests.DailyById[id]
	if daily then
		if not table.find(q.daily.list, id) then
			return false, "Ce défi n'est pas au programme aujourd'hui."
		end
		if q.daily.claimed[id] then
			return false, "Déjà réclamé."
		end
		local progress, goal = Quests.dailyProgress(data, id)
		if progress < goal then
			return false, "Pas encore : " .. Quests.formatNumber(progress) .. " / " .. Quests.formatNumber(goal)
		end
		q.daily.claimed[id] = true
		local text = self:GiveReward(player, daily.reward)
		return true, "Défi du jour réussi ! " .. text
	end
	local quest = Quests.ById[id]
	if not quest then
		return false, "Défi inconnu."
	end
	local tier, index, progress, goal = Quests.status(data, quest)
	if not tier then
		return false, "Défi déjà terminé !"
	end
	if progress < goal then
		return false, "Pas encore : " .. Quests.formatNumber(progress) .. " / " .. Quests.formatNumber(goal)
	end
	q.claimed[quest.id] = index
	local text = self:GiveReward(player, tier.reward)
	return true, Quests.title(quest, goal) .. " : " .. text
end

-- Réclame tout ce qui est prêt (défis du jour, coffre, défis permanents).
function QuestService:ClaimAll(player: Player): (boolean, string)
	local data = self.services.DataService:Get(player)
	if not data then
		return false, "Erreur."
	end
	self:_refreshDaily(player, data)
	local q = ensure(data)
	local claimed = 0
	for _, id in table.clone(q.daily.list) do
		if dailyReady(data, id) and self:Claim(player, id) then
			claimed += 1
		end
	end
	if bonusReady(data) and self:Claim(player, "bonus") then
		claimed += 1
	end
	for _, quest in Quests.List do
		-- plusieurs paliers peuvent être prêts d'un coup
		for _ = 1, #quest.tiers do
			local tier, _, progress, goal = Quests.status(data, quest)
			if tier and progress >= goal and self:Claim(player, quest.id) then
				claimed += 1
			else
				break
			end
		end
	end
	if claimed == 0 then
		return false, "Aucune récompense prête pour l'instant."
	end
	return true, claimed .. " récompense" .. (claimed > 1 and "s" or "") .. " réclamée" .. (claimed > 1 and "s" or "") .. " !"
end

-- Nombre de récompenses prêtes (pastille du bouton Défis).
function QuestService:ReadyCount(player: Player): number
	local data = self.services.DataService:Get(player)
	return data and Quests.readyCount(data) or 0
end

------------------------------------------------------------------------
-- Annonces de progression
------------------------------------------------------------------------

-- Vérifie les défis du joueur : prêts à réclamer (une seule annonce par palier) et quarts de
-- progression franchis (suivi à l'écran) pour les compteurs modifiés.
function QuestService:_check(player: Player, changed: { [string]: boolean }?)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return
	end
	local q = ensure(data)
	if self:_refreshDaily(player, data) then
		QuestNotify:FireClient(player, { kind = "daily" })
	end
	self:_adjustIncomeGoals(player, data)
	local seen = buckets[player] or {}
	buckets[player] = seen
	local readyTitles = {}

	local function progressStep(key: string, id: string, title: string, progress: number, goal: number, icon: string)
		if not changed or not changed[key] or goal <= 0 then
			return
		end
		local bucket = math.floor(math.clamp(progress / goal, 0, 1) * 4)
		local previous = seen[id]
		seen[id] = bucket
		if previous ~= nil and bucket > previous and bucket < 4 then
			QuestNotify:FireClient(player, { kind = "progress", id = id, title = title, progress = progress, goal = goal, icon = icon })
		end
	end

	-- Défis du jour
	for _, id in q.daily.list do
		local daily = Quests.DailyById[id]
		if daily and not q.daily.claimed[id] then
			local progress, goal = Quests.dailyProgress(data, id)
			local title = Quests.title(daily, goal)
			local key = "d:" .. q.daily.day .. ":" .. id
			if progress >= goal then
				if not q.notified[key] then
					q.notified[key] = true
					table.insert(readyTitles, title)
					QuestNotify:FireClient(player, { kind = "ready", id = id, title = title, daily = true, icon = daily.icon, reward = daily.reward })
				end
			else
				progressStep(daily.key, id, title, progress, goal, daily.icon)
			end
		end
	end
	-- Défis permanents
	for _, quest in Quests.List do
		local tier, index, progress, goal = Quests.status(data, quest)
		if tier then
			local title = Quests.title(quest, goal)
			if progress >= goal then
				if (tonumber(q.notified[quest.id]) or 0) < index then
					q.notified[quest.id] = index
					table.insert(readyTitles, title)
					QuestNotify:FireClient(player, { kind = "ready", id = quest.id, title = title, icon = quest.icon, reward = tier.reward })
				end
			else
				progressStep(quest.key, quest.id, title, progress, goal, quest.icon)
			end
		end
	end
	-- Nettoie les anciennes annonces des jours passés
	for key in q.notified do
		if type(key) == "string" and string.sub(key, 1, 2) == "d:" and not string.find(key, "d:" .. q.daily.day .. ":", 1, true) then
			q.notified[key] = nil
		end
	end
	if #readyTitles > 0 then
		-- Un seul bandeau récapitulatif, affiché par le client (pas quand l'écran Défis est ouvert :
		-- il montre déjà le compteur de récompenses prêtes).
		QuestNotify:FireClient(player, { kind = "readySummary", count = #readyTitles, title = readyTitles[1] })
		DataService:Sync(player)
	end
end

------------------------------------------------------------------------
-- Punching-balls
------------------------------------------------------------------------

local function stationAnchor(station: Model): BasePart?
	return station:FindFirstChild("PromptAnchor") :: BasePart?
end

local function setText(gui: Instance?, name: string, text: string, color: Color3?)
	local label = gui and gui:FindFirstChild(name, true) :: TextLabel?
	if label then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
end

function QuestService:_refreshStation(station: Model)
	local state = stations[station]
	local anchor = stationAnchor(station)
	local gui = anchor and anchor:FindFirstChild("Counter")
	if not state or not gui then
		return
	end
	local owner = state.owner
	local fill = gui:FindFirstChild("Fill", true) :: Frame?
	if owner then
		local data = self.services.DataService:Get(owner)
		local count = data and ensure(data).punch or 0
		local nextTier = Quests.nextPunchTier(count)
		station:SetAttribute("Count", count)
		station:SetAttribute("Owner", owner.DisplayName)
		station:SetAttribute("OwnerId", owner.UserId)
		setText(gui, "Owner", owner.DisplayName, Color3.fromRGB(255, 214, 90))
		setText(gui, "Count", Quests.formatNumber(count) .. " / " .. Quests.formatNumber(PUNCH.Goal))
		setText(gui, "Next", nextTier and ("Prochain palier : " .. nextTier[1] .. " coups → +" .. nextTier[2] .. " gemmes") or "Cycle terminé !")
		if fill then
			fill.Size = UDim2.fromScale(math.clamp(count / PUNCH.Goal, 0, 1), 1)
		end
	else
		station:SetAttribute("Count", 0)
		station:SetAttribute("Owner", nil)
		station:SetAttribute("OwnerId", nil)
		setText(gui, "Owner", "LIBRE", Color3.fromRGB(130, 240, 150))
		setText(gui, "Count", "Sors ton épée et frappe !")
		setText(gui, "Next", Quests.Punch.Goal .. " coups = " .. Quests.punchCycleGems() .. " relances de trait")
		if fill then
			fill.Size = UDim2.fromScale(0, 1)
		end
	end
end

function QuestService:_release(station: Model, reason: string?)
	local state = stations[station]
	if not state or not state.owner then
		return
	end
	local owner = state.owner
	state.owner = nil
	state.farSince = nil
	self:_refreshStation(station)
	if reason and owner.Parent then
		Notify:FireClient(owner, reason, "info")
	end
end

function QuestService:StationOf(player: Player): Model?
	for station, state in stations do
		if state.owner == player then
			return station
		end
	end
	return nil
end

function QuestService:GetStations(): { Model }
	return stationList
end

-- Poste le plus proche que le joueur peut toucher (devant lui, à portée).
function QuestService:_stationInReach(origin: Vector3, forward: Vector3?): Model?
	local best, bestDist = nil, PUNCH.Reach
	for _, station in stationList do
		local anchor = stationAnchor(station)
		if anchor then
			local offset = anchor.CFrame.Position - origin
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			local facing = not forward or distance < 3 or flat.Unit:Dot(Vector3.new(forward.X, 0, forward.Z).Unit) > 0.2
			if distance <= bestDist and facing and math.abs(offset.Y) < 8 then
				best, bestDist = station, distance
			end
		end
	end
	return best
end

-- Un coup sur un punching-ball. Renvoie vrai si le coup a été compté.
function QuestService:Punch(player: Player, station: Model?, origin: Vector3?, forward: Vector3?): boolean
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return false
	end
	local position = origin or root.Position
	local target = station or self:_stationInReach(position, forward)
	if not target or not stations[target] then
		return false
	end
	local anchor = stationAnchor(target)
	if not anchor then
		return false
	end
	-- Anti-triche : à portée du sac, et pas plus d'un coup toutes les MinInterval secondes.
	local offset = anchor.CFrame.Position - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > PUNCH.Reach + 1.5 then
		return false
	end
	local now = os.clock()
	if lastPunch[player] and now - lastPunch[player] < PUNCH.MinInterval then
		return false
	end
	local state = stations[target]
	if state.owner and state.owner ~= player then
		if not busyWarned[player] or now - busyWarned[player] > 4 then
			busyWarned[player] = now
			Notify:FireClient(player, "Ce punching-ball est pris par " .. state.owner.DisplayName .. " : prends-en un libre !", "warning")
		end
		return false
	end
	-- Un seul sac par joueur.
	local previous = self:StationOf(player)
	if previous and previous ~= target then
		self:_release(previous)
	end
	if state.owner ~= player then
		state.owner = player
		Notify:FireClient(player, "🥊 Punching-ball n°" .. tostring(target:GetAttribute("Station")) .. " réservé : tape !", "info")
	end
	state.lastHit = now
	state.farSince = nil
	lastPunch[player] = now

	local q = ensure(data)
	local before = q.punch
	local after = before + 1
	self:Add(player, "punch")
	local anchorPos = anchor.CFrame.Position
	for index, tier in PUNCH.Tiers do
		if before < tier[1] and after >= tier[1] then
			self:GrantGems(player, tier[2], anchorPos + Vector3.new(0, 2, 0))
			QuestNotify:FireClient(player, { kind = "punchTier", tier = index, hits = tier[1], gems = tier[2] })
			Notify:FireClient(player, "🥊 " .. tier[1] .. " coups : +" .. tier[2] .. " gemmes de trait !", "success")
		end
	end
	if after >= PUNCH.Goal then
		after = 0
		QuestNotify:FireClient(player, { kind = "punchCycle", gems = Quests.punchCycleGems() })
	end
	q.punch = after
	target:SetAttribute("HitTick", (target:GetAttribute("HitTick") or 0) + 1)
	target:SetAttribute("HitDir", Vector3.new(offset.X, 0, offset.Z).Unit)
	self:_refreshStation(target)
	DataService:Sync(player)
	return true
end

-- Coup d'épée n'importe où : compte s'il touche un punching-ball.
function QuestService:OnSwordSwing(player: Player, origin: Vector3, forward: Vector3)
	if #stationList == 0 then
		return false
	end
	local station = self:_stationInReach(origin, forward)
	if station then
		return self:Punch(player, station, origin, forward)
	end
	return false
end

-- Invite « Frapper » : sort l'épée, se tourne vers le sac et frappe.
function QuestService:PromptPunch(player: Player, station: Model)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local anchor = stationAnchor(station)
	if not root or not anchor or not character then
		return
	end
	local state = stations[station]
	if state and state.owner and state.owner ~= player then
		self:Punch(player, station) -- affiche « pris par »
		return
	end
	local target = anchor.CFrame.Position
	pcall(function()
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
	end)
	local SwordService = self.services.SwordService
	local tool: Tool? = nil
	for _, container in { character, player:FindFirstChildOfClass("Backpack") } do
		if container and not tool then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("SwordId") then
					tool = child
					break
				end
			end
		end
	end
	if tool and SwordService then
		if tool.Parent ~= character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			pcall(function()
				(humanoid :: Humanoid):EquipTool(tool :: Tool)
			end)
			if tool.Parent ~= character then
				tool.Parent = character
			end
		end
		SwordService:Swing(player, tool, station)
	else
		self:Punch(player, station)
	end
end

function QuestService:_setupStations()
	local world = Workspace:FindFirstChild("World")
	if not world then
		return
	end
	stationList = AfkZone.stations(world)
	for _, station in stationList do
		stations[station] = { owner = nil, lastHit = 0, farSince = nil }
		self:_refreshStation(station)
		local anchor = stationAnchor(station)
		local prompt = anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				self:PromptPunch(player, station)
			end)
		end
	end
end

-- Libère les sacs des joueurs partis, éloignés ou inactifs.
function QuestService:_tickStations()
	local now = os.clock()
	for station, state in stations do
		local owner = state.owner
		if owner then
			local character = owner.Parent and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local anchor = stationAnchor(station)
			if not root or not anchor then
				self:_release(station)
			elseif now - state.lastHit > PUNCH.IdleRelease then
				self:_release(station, "Punching-ball libéré (tu ne tapais plus).")
			else
				local offset = anchor.CFrame.Position - root.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude > PUNCH.ReleaseDistance then
					state.farSince = state.farSince or now
					if now - state.farSince >= PUNCH.ReleaseDelay then
						self:_release(station, "Punching-ball libéré : tu t'es éloigné.")
					end
				else
					state.farSince = nil
				end
			end
		end
	end
end

-- Voyage jusqu'à l'entrée de la zone anti-AFK (bouton de l'écran Défis).
function QuestService:GoToAfkZone(player: Player): (boolean, string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return false, "Attends d'être apparu."
	end
	if self.services.TradeService and self.services.TradeService:IsInTrade(player) then
		return false, "Impossible pendant un échange."
	end
	local center = Layout.AfkZone
	local inward = (Vector3.zero - center).Unit
	local spot = center + inward * 40 + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z)))
	return true, "Bienvenue à la zone anti-AFK : prends un punching-ball libre !"
end

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------

function QuestService:Start()
	local DataService = self.services.DataService
	DataService:OnPlayerLoaded(function(player, data)
		ensure(data)
		self:_refreshDaily(player, data)
		buckets[player] = {}
		-- Annonce une fois les défis déjà prêts (sans « quart » de progression au chargement).
		self:_check(player, nil)
		DataService:Sync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for station, state in stations do
			if state.owner == player then
				self:_release(station)
			end
		end
		dirty[player] = nil
		buckets[player] = nil
		lastPunch[player] = nil
		busyWarned[player] = nil
	end)

	Remotes.func("QuestClaim").OnServerInvoke = function(player, id)
		local ok, message = self:Claim(player, id)
		if ok then
			self:_check(player, nil)
		end
		return ok, message
	end
	Remotes.func("QuestClaimAll").OnServerInvoke = function(player)
		local ok, message = self:ClaimAll(player)
		if ok then
			self:_check(player, nil)
		end
		return ok, message
	end

	Remotes.func("QuestGoAfk").OnServerInvoke = function(player)
		return self:GoToAfkZone(player)
	end

	self:_setupStations()

	-- Vérifications : compteurs modifiés (chaque seconde), tous les joueurs (toutes les 5 s,
	-- pour les défis lus dans la sauvegarde : roulages, pièces, temps de jeu...), sacs libérés.
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for player, changed in dirty do
				dirty[player] = nil
				local ok, err = pcall(self._check, self, player, changed)
				if not ok then
					warn("[AnimeTycoon] Défis : " .. tostring(err))
				end
			end
			if tick % 5 == 0 then
				for _, player in Players:GetPlayers() do
					if DataService:IsLoaded(player) then
						local changed = {}
						for _, prefix in
							{ "stat:RollCount", "stat:hatched", "stat:index", "stat:evolutions", "stat:fusions", "stat:skills", "stat:totalCoins", "stat:trades", "stat:playtime" }
						do
							changed[prefix] = true
						end
						pcall(self._check, self, player, changed)
					end
				end
			end
			pcall(self._tickStations, self)
		end
	end)
end

return QuestService
