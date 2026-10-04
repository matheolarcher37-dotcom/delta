-- MACHINE ROULER + ARBRE DE COMPÉTENCES (la source principale de persos).
--
-- Rouler est gratuit : chaque roulage tire 1 perso (2 puis 3 avec « Multi-tirage ») dans le
-- pool de l'UNIVERS ACTUEL (la rotation des univers compte). Les persos tirés attendent sur
-- l'estrade de la base (data.RolledQueue, 6 places) ; on les « Collecte » en payant leur prix.
--   • chance : arbre (Chance I-V...) ; tous les N roulages, un roulage « Chance x10 »
--   • pitié  : Légendaire / Mythique / Secret garantis au bout de X persos tirés
--   • vitesse: délai entre deux roulages (Taux d'apparition) ; auto-roulage (nœud de l'arbre)
-- Les reliques (HatchService) restent une source secondaire : butin du boss, marchand de
-- reliques de la base, relique de bienvenue. Les deux donnent des persos identiques.
--
-- Remotes : Roll() → ok, résultats | message ; CollectRolled(clé) → ok, message ;
-- SetAutoRoll(bool) → ok, message ; BuySkill(nodeId) → ok, message ; RollResult (serveur → client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Characters = require(Shared.Config.Characters)
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local SkillTree = require(Shared.Config.SkillTree)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local CharacterFactory = require(Shared.Modules.CharacterFactory)
local Remotes = require(Shared.Modules.Remotes)
local Modules = script.Parent.Parent.Modules
local Machine = require(Modules.TycoonMachine)
local Kit = require(Modules.TycoonKit)
local Props = require(Modules.TycoonProps)
local BaseDecor = require(script.Parent.Parent.World.BaseDecor)

local RollService = {}

local Notify = Remotes.event("Notify")
local Announce = Remotes.event("Announce")
local HatchReveal = Remotes.event("HatchReveal")
local RollResult = Remotes.event("RollResult")

local rng = Random.new()
local lastRoll: { [Player]: number } = {}
local warnedFull: { [Player]: number } = {}
local PROTECTED_ORDER = 5 -- Légendaire et plus : jamais poussés hors de l'estrade

local function rarityOrder(id: string): number
	local info = Economy.RollRarities[id]
	return info and info.order or 0
end

function RollService:Init(services)
	self.services = services
end

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------

function RollService:Start()
	local DataService = self.services.DataService

	Remotes.func("Roll").OnServerInvoke = function(player)
		local ok, result = self:Roll(player)
		if not ok and type(result) == "string" then
			Notify:FireClient(player, result, "error")
		end
		return ok, result
	end
	Remotes.func("CollectRolled").OnServerInvoke = function(player, key)
		local ok, message = self:Collect(player, key)
		Notify:FireClient(player, message, ok and "success" or "error")
		return ok, message
	end
	Remotes.func("SetAutoRoll").OnServerInvoke = function(player, enabled)
		local ok, message = self:SetAutoRoll(player, enabled == true)
		if message then
			Notify:FireClient(player, message, ok and "success" or "error")
		end
		return ok, message
	end
	Remotes.func("BuySkill").OnServerInvoke = function(player, nodeId)
		local ok, message = self:BuySkill(player, nodeId)
		Notify:FireClient(player, message, ok and "success" or "error")
		return ok, message
	end

	-- Machine de chaque base : invite « Rouler ».
	for _, plot in self.services.PlotService:GetPlots() do
		local prompt = plot.machine and plot.machine.prompt
		if prompt then
			prompt.Triggered:Connect(function(player)
				if plot.owner ~= player then
					Notify:FireClient(player, "Ce n'est pas ta base !", "error")
					return
				end
				local ok, message = self:Roll(player)
				if not ok and type(message) == "string" then
					Notify:FireClient(player, message, "error")
				end
			end)
		end
	end

	DataService:OnPlayerLoaded(function(player, data)
		self:_cleanQueue(data)
		self:RenderStage(player)
		self:UpdatePanels(player)
		self:_applyWalkSpeed(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			self:_applyWalkSpeed(player)
		end)
		if (data.RollCount or 0) == 0 then
			task.delay(6, function()
				Notify:FireClient(player, "🎲 Appuie sur le gros bouton ROULER de ta base pour tirer des persos !", "info")
			end)
		end
	end)
	DataService:OnPlayerRemoving(function(player)
		lastRoll[player] = nil
		warnedFull[player] = nil
	end)

	-- Déco des bases : celle de l'univers actuel, puis à chaque changement d'univers.
	local UniverseService = self.services.UniverseService
	if UniverseService then
		self:_onUniverse(UniverseService:GetCurrent())
		local gameState = ReplicatedStorage:FindFirstChild("GameState")
		if gameState then
			gameState:GetAttributeChangedSignal("UniverseId"):Connect(function()
				local universe = Universes.get(gameState:GetAttribute("UniverseId"))
				if universe then
					self:_onUniverse(universe)
				end
			end)
		end
	end

	-- Auto-roulage.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local data = DataService:Get(player)
				if data and data.AutoRoll then
					local stats = Formulas.playerStats(data)
					if stats.autoRoll and (not lastRoll[player] or os.clock() - lastRoll[player] >= stats.rollCooldown) then
						local ok, err = pcall(self.Roll, self, player, true)
						if not ok then
							warn("[AnimeTycoon] Auto-roulage : " .. tostring(err))
						end
					end
				end
			end
		end
	end)
end

function RollService:_onUniverse(universe)
	BaseDecor.applyAll(universe, self.services.PlotService:GetPlots())
	for _, plot in self.services.PlotService:GetPlots() do
		local label = plot.machine and plot.machine.universeLabel
		if label then
			label.Text = "Univers : " .. universe.name
		end
	end
end

function RollService:_applyWalkSpeed(player: Player)
	local data = self.services.DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	local base = 22
	pcall(function()
		base = game:GetService("StarterPlayer").CharacterWalkSpeed
	end)
	humanoid.WalkSpeed = base + SkillTree.stats(data.Skills).walkSpeed
end

-- Retire de la file les persos qui n'existent plus (sauvegarde ancienne / persos retirés du jeu).
function RollService:_cleanQueue(data)
	local clean = {}
	for _, item in data.RolledQueue do
		if type(item) == "table" and Characters.get(item.id) and Economy.RollRarities[item.rarity] and #clean < Economy.Roll.QueueMax then
			item.price = math.max(0, math.floor(tonumber(item.price) or Formulas.rollPrice(item.rarity, item.aura, item.trait)))
			table.insert(clean, item)
		end
	end
	data.RolledQueue = clean
end

------------------------------------------------------------------------
-- Tirage
------------------------------------------------------------------------

-- Tire une rareté de la machine en tenant compte de la chance et de la pitié.
function RollService:_pickRarity(data, stats, luck: number): string
	for _, tier in Economy.Roll.PityOrder do
		data.Pity[tier] = (data.Pity[tier] or 0) + 1
	end
	local odds = Formulas.rollOdds(luck)
	local roll = rng:NextNumber()
	local rolled = "common"
	for i = #Economy.RollOrder, 1, -1 do
		local id = Economy.RollOrder[i]
		roll -= odds[id] or 0
		if roll <= 0 then
			rolled = id
			break
		end
	end
	-- Pitié : la plus haute rareté dont le compteur a atteint son seuil est garantie.
	for _, tier in Economy.Roll.PityOrder do
		if data.Pity[tier] >= Formulas.pityThreshold(tier, stats.pityMult) and rarityOrder(rolled) < rarityOrder(tier) then
			rolled = tier
		end
	end
	for _, tier in Economy.Roll.PityOrder do
		if rarityOrder(rolled) >= rarityOrder(tier) then
			data.Pity[tier] = 0
		end
	end
	return rolled
end

local function rollTrait(minTier: number?, luck: number): string?
	if not minTier then
		return Traits.roll(rng, luck)
	end
	for _ = 1, 60 do
		local id = Traits.roll(rng, luck * 2)
		local trait = Traits.get(id)
		if trait and trait.tier >= minTier then
			return id
		end
	end
	for _, id in Traits.Order do
		if Traits.List[id].tier >= minTier then
			return id
		end
	end
	return nil
end

-- Crée un perso tiré (pas encore collecté) de la rareté `rarityId` dans l'univers donné.
function RollService:MakeItem(universe, rarityId: string, stats)
	local info = Economy.RollRarities[rarityId] or Economy.RollRarities.common
	local pool = {}
	for _, id in universe.characters do
		local def = Characters.get(id)
		if def and def.rarity == info.charRarity then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		pool = table.clone(universe.characters)
	end
	local id = pool[rng:NextInteger(1, #pool)]
	local eventLuck = self.services.EventService and self.services.EventService.AuraLuck and self.services.EventService:AuraLuck() or 1
	local aura = info.aura or Auras.roll(rng, eventLuck * (stats.auraLuck or 1))
	local trait = nil
	if info.traitMinTier then
		trait = rollTrait(info.traitMinTier, stats.traitLuck or 1)
	elseif rng:NextNumber() < Traits.HatchChance * 0.4 then
		trait = rollTrait(nil, stats.traitLuck or 1)
	end
	local entry = { id = id, level = 1, xp = 0, stars = 1, aura = aura, trait = trait }
	return {
		key = self.services.DataService:NewUid(),
		id = id,
		rarity = rarityId,
		stars = 1,
		aura = aura,
		trait = trait,
		price = Formulas.rollPrice(rarityId, aura, trait),
		dps = math.floor(Formulas.dps(entry) + 0.5),
		at = os.time(),
	}
end

-- Fait de la place sur l'estrade pour `count` nouveaux persos (les plus anciens et les moins
-- rares partent d'abord ; les Légendaires et plus ne partent jamais tout seuls).
local function makeRoom(queue, count: number): boolean
	while #queue + count > Economy.Roll.QueueMax do
		local removed = false
		for i, item in queue do
			if rarityOrder(item.rarity) < PROTECTED_ORDER then
				table.remove(queue, i)
				removed = true
				break
			end
		end
		if not removed then
			return false
		end
	end
	return true
end

function RollService:PityRemaining(data, stats)
	local remaining = {}
	for _, tier in Economy.Roll.PityOrder do
		remaining[tier] = math.max(1, Formulas.pityThreshold(tier, stats.pityMult) - (data.Pity[tier] or 0))
	end
	return remaining
end

-- Roule la machine. Renvoie (true, résultats) ou (false, message).
function RollService:Roll(player: Player, auto: boolean?)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local plot = self.services.PlotService:GetPlot(player)
	if not data or not plot then
		return false, "Ta base n'est pas prête."
	end
	local stats = Formulas.playerStats(data)
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < stats.rollCooldown - 0.05 then
		if auto then
			return false, nil
		end
		return false, "La machine recharge..."
	end
	local count = stats.rollsPerPull
	if not makeRoom(data.RolledQueue, count) then
		lastRoll[player] = now
		local message = "Estrade pleine de persos rares : collecte-les d'abord !"
		if not auto then
			return false, message -- l'appelant prévient le joueur (un seul message)
		end
		-- Auto-roulage : on prévient de temps en temps seulement.
		if not warnedFull[player] or now - warnedFull[player] > 20 then
			warnedFull[player] = now
			Notify:FireClient(player, message, "warning")
		end
		return false, nil
	end
	lastRoll[player] = now
	data.RollCount += 1
	data.X10Counter += 1
	local isX10 = data.X10Counter >= stats.x10Every
	if isX10 then
		data.X10Counter = 0
	end
	local luck = stats.luck * (isX10 and Economy.Roll.X10Luck or 1)
	local universe = self.services.UniverseService and self.services.UniverseService:GetCurrent() or Universes.List[1]
	local results = {}
	for _ = 1, count do
		local rarity = self:_pickRarity(data, stats, luck)
		local item = self:MakeItem(universe, rarity, stats)
		table.insert(data.RolledQueue, item)
		table.insert(results, item)
	end
	DataService:Sync(player)
	Machine.press(plot.machine, isX10)
	self:RenderStage(player, results)
	self:UpdatePanels(player)
	local payload = {
		results = results,
		pity = self:PityRemaining(data, stats),
		x10In = stats.x10Every - data.X10Counter,
		x10 = isX10,
		universe = universe.id,
	}
	RollResult:FireClient(player, payload)
	for _, item in results do
		local info = Economy.RollRarities[item.rarity]
		if info.order >= PROTECTED_ORDER then
			local def = Characters.get(item.id)
			Announce:FireAllClients(
				"✨ " .. player.DisplayName .. " ✨",
				"a tiré " .. def.name .. " (" .. info.name .. ") à la machine ROULER !",
				info.order >= 7 and Color3.fromRGB(255, 255, 255) or info.color
			)
		end
	end
	return true, results
end

------------------------------------------------------------------------
-- Collecte
------------------------------------------------------------------------

-- Seule la CLÉ du perso est acceptée (jamais sa position : la file bouge à chaque roulage,
-- on risquerait d'acheter un autre perso que celui choisi).
local function findIndex(queue, ref): number?
	if type(ref) == "string" then
		for i, item in queue do
			if item.key == ref then
				return i
			end
		end
	end
	return nil
end

-- Achète un perso tiré (`ref` = clé du perso dans RolledQueue).
function RollService:Collect(player: Player, ref: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return false, "Erreur."
	end
	local index = findIndex(data.RolledQueue, ref)
	if not index then
		return false, "Ce perso n'est plus sur l'estrade."
	end
	if DataService:CharacterCount(player) >= Economy.MaxCharacters then
		return false, "Inventaire plein (" .. Economy.MaxCharacters .. ") ! Vends des persos."
	end
	local item = data.RolledQueue[index]
	local free = Formulas.rollCollectFree(data, item.rarity)
	local price = free and 0 or item.price
	if data.coins < price then
		return false, "Il te manque ¥ " .. Formulas.formatNumber(price - data.coins) .. " pour ce perso."
	end
	if price > 0 then
		DataService:SpendCoins(player, price)
	end
	table.remove(data.RolledQueue, index)
	local firstCollect = not data.FirstCollectDone
	data.FirstCollectDone = true
	local CharacterService = self.services.CharacterService
	local entry = CharacterService:CreateEntry(item.id, item.aura, item.trait)
	entry.rollRarity = item.rarity
	local isNew = not data.index[item.id]
	local uid = CharacterService:AddCharacter(player, entry)
	data.stats.hatched += 1
	DataService:Sync(player)
	self:RenderStage(player, nil, firstCollect)
	local info = Economy.RollRarities[item.rarity]
	if info.order >= 4 or isNew then
		HatchReveal:FireClient(player, { uid = uid, entry = entry, source = "roll", rollRarity = item.rarity, isNew = isNew })
	end
	local def = Characters.get(item.id)
	return true, (free and "🎁 Offert : " or "✅ Collecté : ") .. def.name .. " (" .. info.name .. ")"
end

-- Remet à zéro le délai entre deux roulages (tests, commandes admin).
function RollService:ResetCooldown(player: Player)
	lastRoll[player] = nil
end

function RollService:SetAutoRoll(player: Player, enabled: boolean)
	local data = self.services.DataService:Get(player)
	if not data then
		return false, "Erreur."
	end
	if enabled and not Formulas.playerStats(data).autoRoll then
		data.AutoRoll = false
		return false, "Débloque « Auto-roulage » dans l'arbre de compétences."
	end
	data.AutoRoll = enabled
	self.services.DataService:Sync(player)
	return true, enabled and "🤖 Auto-roulage activé" or "Auto-roulage désactivé"
end

------------------------------------------------------------------------
-- Arbre de compétences
------------------------------------------------------------------------

function RollService:BuySkill(player: Player, nodeId: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(nodeId) ~= "string" then
		return false, "Erreur."
	end
	local node = SkillTree.get(nodeId)
	if not node then
		return false, "Compétence inconnue."
	end
	if data.Skills[nodeId] then
		return false, node.name .. " est déjà débloqué."
	end
	if not SkillTree.canUnlock(data.Skills, nodeId) then
		local missing = {}
		for _, req in node.requires do
			if not data.Skills[req] then
				local reqNode = SkillTree.get(req)
				table.insert(missing, reqNode and reqNode.name or req)
			end
		end
		return false, "Débloque d'abord : " .. table.concat(missing, ", ")
	end
	if data.coins < node.cost then
		return false, "Il te manque ¥ " .. Formulas.formatNumber(node.cost - data.coins) .. " pour " .. node.name
	end
	DataService:SpendCoins(player, node.cost)
	data.Skills[nodeId] = true
	-- Le palier « Chance x10 » a pu baisser : le compteur ne doit pas le dépasser.
	data.X10Counter = math.min(data.X10Counter or 0, math.max(0, Formulas.playerStats(data).x10Every - 1))
	DataService:Sync(player)
	local plot = self.services.PlotService:GetPlot(player)
	if plot and plot.skillRefs then
		Props.refreshSkillCells(plot.skillRefs.cells, data.Skills)
	end
	if self.services.CharacterService then
		self.services.CharacterService:Refresh(player) -- emplacements, revenus
	end
	self:UpdatePanels(player)
	self:_applyWalkSpeed(player)
	return true, "✨ " .. node.name .. " débloqué ! " .. node.desc
end

------------------------------------------------------------------------
-- Affichage : estrade, panneaux
------------------------------------------------------------------------

function RollService:UpdatePanels(player: Player)
	local data = self.services.DataService:Get(player)
	local plot = self.services.PlotService:GetPlot(player)
	if not data or not plot or not plot.machine then
		return
	end
	local stats = Formulas.playerStats(data)
	Machine.setX10(plot.machine, stats.x10Every - data.X10Counter, stats.x10Every)
	Machine.setPity(plot.machine, self:PityRemaining(data, stats))
end

function RollService:ClearStage(plot)
	if plot.rolledFolder then
		plot.rolledFolder:ClearAllChildren()
	end
	plot.stage = {}
	for i = 1, #Machine.Spots do
		if plot.machine then
			Machine.lightSpot(plot.machine, i, nil)
		end
	end
end

local function itemTagLines(item, def)
	local info = Economy.RollRarities[item.rarity]
	local aura = Auras.get(item.aura)
	local trait = Traits.get(item.trait)
	local extras = {}
	if aura then
		table.insert(extras, "✦ " .. aura.name)
	end
	if trait then
		table.insert(extras, "◆ " .. trait.name)
	end
	local lines = {
		{ name = "Rarete", text = info.name, colors = info.gradient, font = Enum.Font.LuckiestGuy, weight = 0.9 },
		{ name = "Dps", text = "DPS " .. Formulas.formatNumber(item.dps or 0), color = Color3.fromRGB(230, 230, 230), font = Enum.Font.GothamBold, weight = 0.5 },
		{ name = "Nom", text = def.name, color = Color3.new(1, 1, 1), font = Enum.Font.LuckiestGuy, weight = 1 },
		{ name = "Prix", text = "¥" .. Formulas.formatNumber(item.price), color = Color3.fromRGB(255, 215, 60), font = Enum.Font.LuckiestGuy, weight = 0.9 },
	}
	if #extras > 0 then
		table.insert(lines, 3, { name = "Bonus", text = table.concat(extras, "  "), color = Color3.fromRGB(150, 230, 255), font = Enum.Font.GothamBold, weight = 0.5 })
	end
	return lines
end

-- Texte de l'invite « Collecter » d'un perso de l'estrade (prix, ou « offert »).
function RollService:_collectText(data, item): string
	if Formulas.rollCollectFree(data, item.rarity) then
		return "Collecter (offert)"
	end
	return "Collecter (¥" .. Formulas.formatNumber(item.price) .. ")"
end

-- Affiche les persos de RolledQueue sur l'estrade (`fresh` = persos qui viennent d'arriver).
-- `refreshPrompts` = remettre à jour le texte des invites (fin de la collecte offerte).
function RollService:RenderStage(player: Player, fresh: { any }?, refreshPrompts: boolean?)
	local data = self.services.DataService:Get(player)
	local plot = self.services.PlotService:GetPlot(player)
	if not data or not plot or not plot.machine or not plot.rolledFolder then
		return
	end
	plot.stage = plot.stage or {}
	local isFresh = {}
	for _, item in fresh or {} do
		isFresh[item.key] = true
	end
	local keep = {}
	for i, item in data.RolledQueue do
		if i > #Machine.Spots then
			break
		end
		keep[item.key] = true
		local spot = plot.machine.spots[i]
		local info = Economy.RollRarities[item.rarity] or Economy.RollRarities.common
		local entry = { id = item.id, level = 1, xp = 0, stars = item.stars or 1, aura = item.aura, trait = item.trait, rollRarity = item.rarity }
		local existing = plot.stage[item.key]
		if existing and existing.model.Parent then
			if refreshPrompts and existing.prompt then
				existing.prompt.ActionText = self:_collectText(data, item)
			end
			if existing.spot ~= i then
				existing.model:PivotTo(spot.cf * CFrame.new(0, existing.rootHeight, 0))
				existing.spot = i
			end
		else
			local ok, model = pcall(self.services.CharacterService.BuildModel, self.services.CharacterService, player, item.key, entry, { anchored = true })
			local promptRef = nil
			if ok and model then
				local rootHeight = CharacterFactory.rootHeight(model)
				model.Name = "Tire_" .. item.key
				model:SetAttribute("Rolled", true)
				model:SetAttribute("RollRarity", item.rarity)
				model:PivotTo(spot.cf * CFrame.new(0, rootHeight, 0))
				local root = model.PrimaryPart
				if root then
					root.CanCollide = false
					local def = Characters.get(item.id)
					Kit.unitTag(root, itemTagLines(item, def), 3, 4.4 * (model:GetAttribute("BaseScale") or 1) + 1.6, 70, 5.4)
					local prompt = Props.prompt(root, self:_collectText(data, item), def.name, 9)
					promptRef = prompt
					prompt.Triggered:Connect(function(who)
						if who ~= plot.owner then
							Notify:FireClient(who, "Ce n'est pas ta base !", "error")
							return
						end
						local okCollect, message = self:Collect(who, item.key)
						Notify:FireClient(who, message, okCollect and "success" or "error")
					end)
				end
				model.Parent = plot.rolledFolder
				existing = { model = model, spot = i, rootHeight = rootHeight, prompt = promptRef }
				plot.stage[item.key] = existing
			else
				warn("[AnimeTycoon] Perso tiré : " .. tostring(model))
			end
		end
		Machine.lightSpot(plot.machine, i, info.color.R + info.color.G + info.color.B < 0.3 and Color3.fromRGB(255, 255, 255) or info.color, info.order >= PROTECTED_ORDER)
		if isFresh[item.key] then
			Machine.burst(plot.machine, i, info.color, 20 + info.order * 8)
		end
	end
	for key, info in plot.stage do
		if not keep[key] then
			pcall(function()
				info.model:Destroy()
			end)
			plot.stage[key] = nil
		end
	end
	for i = #data.RolledQueue + 1, #Machine.Spots do
		Machine.lightSpot(plot.machine, i, nil)
	end
end

return RollService
