-- MACHINE ROULER + ARBRE DE COMPÉTENCES (la source principale de persos).
--
-- UN PERSO PAR ROULAGE (v3.2) : chaque appui sur ROULER tire UN perso qui apparaît sur le podium
-- de l'estrade. On le « Collecte » (on paie son prix) ou on le laisse passer : le roulage suivant
-- le remplace. Rouler 2 ou 3 persos à la fois se paie en Robux (passes « Roulage x2 / x3 » :
-- attributs Pass_Roll2 / Pass_Roll3 posés sur le joueur par le domaine Robux).
--   • rareté : la machine tire d'abord une rareté (chances de Config/Economy × chance du joueur),
--     puis un perso de CETTE rareté dans le pool de l'univers actuel (chaque perso garde sa rareté
--     de base, Config/Characters) ; une MUTATION peut s'ajouter par-dessus (Config/Mutations) ;
--   • pitié : uniquement le Mythique (garanti au bout de N persos tirés), le reste = pur hasard ;
--   • chance : arbre (Chance I-V, Bénédiction...), passe « x2 Chance » (Pass_Luck2), potion de
--     chance (Boost_Luck = heure de fin) ;
--   • « Lancer AFK » (passe AutoRoll, 29 Robux) : roule tout seul et s'arrête sur les raretés /
--     mutations cochées ; « Achat automatique » (passe AutoRollPlus, 500 Robux) : roule tout seul
--     et ACHÈTE chaque perso qui correspond aux cibles choisies, s'arrête si on ne peut plus payer.
-- Les reliques (HatchService) restent une source secondaire (butin du boss, autels de la base).
--
-- Remotes : Roll() → ok, résultats | message ; CollectRolled(clé) → ok, message ;
-- SetAutoRoll(bool), Roll_SetAutoBuy(bool), Roll_SaveAutoSettings(réglages), Roll_SetMulti(n)
-- → ok, message ; BuySkill(nodeId) → ok, message ; RollResult (serveur → client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Characters = require(Shared.Config.Characters)
local Mutations = require(Shared.Config.Mutations)
local Traits = require(Shared.Config.Traits)
local SkillTree = require(Shared.Config.SkillTree)
local Universes = require(Shared.Config.Universes)
local Robux = require(Shared.Config.Robux)
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

-- Synchro de la sauvegarde pendant l'auto-roulage (roulage auto + achat auto) : regroupée sur
-- 2 s au lieu de 0,25 s. Même avec la machine la plus rapide (1,8 s avec tout l'arbre),
-- l'auto-roulage n'envoie pas la sauvegarde plus d'une fois toutes les 2 s. La révélation
-- (RollResult), l'estrade (pièces du monde) et les messages (Notify, HatchReveal) partent tout
-- de suite par leurs propres remotes. Le roulage manuel reste à 0,25 s.
RollService.AutoSyncWindow = 2

local rng = Random.new()
local lastRoll: { [Player]: number } = {}
local confirmUntil: { [Player]: number } = {}

local function rarityOrder(id: string?): number
	local info = Economy.RollRarities[id or ""]
	return info and info.order or 0
end

-- Passes Robux (attributs posés par le domaine Robux : achat ou possession).
local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end
RollService.hasPass = hasPass

local function canAfk(player: Player): boolean
	return hasPass(player, "AutoRoll") or hasPass(player, "AutoRollPlus")
end

local function mutationName(id: string?): string?
	local m = Mutations.get(id)
	return m and m.name or nil
end

-- « Itochi (Mythique · Or) »
local function itemLabel(item): string
	local def = Characters.get(item.id)
	local info = Economy.RollRarities[item.rarity] or Economy.RollRarities.common
	local mutation = mutationName(item.aura)
	return (def and def.name or "?") .. " (" .. info.name .. (mutation and (" · " .. mutation) or "") .. ")"
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
		-- Le remote ne roule qu'à la machine (comme la barre ROULER côté client) : sinon un
		-- script client referait gratuitement le Lancer AFK depuis n'importe où.
		if not self:IsAtMachine(player) then
			Notify:FireClient(player, "Va à ta machine ROULER !", "warning")
			return false, "Va à ta machine ROULER !"
		end
		local ok, result, kind = self:Roll(player)
		if not ok and type(result) == "string" then
			Notify:FireClient(player, result, kind or "error")
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
	Remotes.func("Roll_SetAutoBuy").OnServerInvoke = function(player, enabled)
		local ok, message = self:SetAutoBuy(player, enabled == true)
		if message then
			Notify:FireClient(player, message, ok and "success" or "error")
		end
		return ok, message
	end
	Remotes.func("Roll_SaveAutoSettings").OnServerInvoke = function(player, settings)
		return self:SaveAutoSettings(player, settings)
	end
	Remotes.func("Roll_SetMulti").OnServerInvoke = function(player, count)
		local ok, message = self:SetMulti(player, count)
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
				local ok, message, kind = self:Roll(player)
				if not ok and type(message) == "string" then
					Notify:FireClient(player, message, kind or "error")
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
		-- Chance (passe / potion) ou passes de roulage achetés en cours de partie : panneaux à jour.
		for _, attribute in { "Pass_Luck2", "Boost_Luck", "Pass_Roll2", "Pass_Roll3", "Pass_AutoRoll", "Pass_AutoRollPlus" } do
			player:GetAttributeChangedSignal(attribute):Connect(function()
				self:UpdatePanels(player)
			end)
		end
		if (data.RollCount or 0) == 0 then
			task.delay(6, function()
				Notify:FireClient(player, "🎲 Appuie sur le gros bouton ROULER de ta base pour tirer un perso !", "info")
			end)
		end
	end)
	DataService:OnPlayerRemoving(function(player)
		lastRoll[player] = nil
		confirmUntil[player] = nil
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

	-- Auto-roulage (Lancer AFK / Achat automatique).
	task.spawn(function()
		while true do
			task.wait(Economy.Roll.AutoStep or 0.25)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self.AutoStep, self, player)
				if not ok then
					warn("[AnimeTycoon] Auto-roulage : " .. tostring(err))
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
		if plot.owner then
			self:UpdatePanels(plot.owner) -- les raretés présentes changent avec l'univers
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

-- Retire de la file les persos qui n'existent plus (sauvegarde ancienne / persos retirés du jeu)
-- et remet à chacun la rareté de sa fiche.
function RollService:_cleanQueue(data)
	local clean = {}
	for _, item in data.RolledQueue do
		local def = type(item) == "table" and Characters.get(item.id)
		if def and #clean < Economy.Roll.QueueMax then
			item.rarity = Economy.RollRarities[def.rarity] and def.rarity or "common"
			item.aura = Mutations.normalize(item.aura)
			item.price = math.max(0, math.floor(tonumber(item.price) or Formulas.rollPrice(item.rarity, item.aura, item.trait)))
			table.insert(clean, item)
		end
	end
	data.RolledQueue = clean
end

------------------------------------------------------------------------
-- Tirage
------------------------------------------------------------------------

function RollService:_universe()
	return self.services.UniverseService and self.services.UniverseService:GetCurrent() or Universes.List[1]
end

function RollService:_luck(player: Player, stats): number
	-- x2 Chance (Pass_Luck2), VIP (+10 %) et potion (Boost_Luck) : tout est dans Formulas.rollLuck,
	-- le même calcul que la barre ROULER du client.
	return Formulas.rollLuck(stats, player, os.time())
end

-- Tire une rareté (chances × chance du joueur) ; pitié du Mythique uniquement.
function RollService:_pickRarity(data, stats, luck: number, pools): string
	local pityTier = Economy.Roll.PityRarity
	data.Pity[pityTier] = (data.Pity[pityTier] or 0) + 1
	local odds = Formulas.rollOdds(luck, pools)
	local roll = rng:NextNumber()
	local rolled = "common"
	for i = #Economy.RollOrder, 1, -1 do
		local id = Economy.RollOrder[i]
		roll -= odds[id] or 0
		if roll <= 0 and (odds[id] or 0) > 0 then
			rolled = id
			break
		end
	end
	if data.Pity[pityTier] >= Formulas.pityThreshold(pityTier, stats.pityMult) and rarityOrder(rolled) < rarityOrder(pityTier) then
		rolled = pityTier
	end
	if rarityOrder(rolled) >= rarityOrder(pityTier) then
		data.Pity[pityTier] = 0
	end
	return rolled
end

-- Pool de la rareté demandée ; si l'univers n'en a pas, la rareté la plus proche (en dessous
-- d'abord). Renvoie (ids, rareté réellement utilisée).
local function poolFor(pools, rarityId: string): ({ string }, string)
	if pools[rarityId] and #pools[rarityId] > 0 then
		return pools[rarityId], rarityId
	end
	local index = table.find(Economy.RollOrder, rarityId) or 1
	for distance = 1, #Economy.RollOrder do
		for _, i in { index - distance, index + distance } do
			local id = Economy.RollOrder[i]
			if id and pools[id] and #pools[id] > 0 then
				return pools[id], id
			end
		end
	end
	return {}, rarityId
end

-- Crée un perso tiré (pas encore collecté) de la rareté `rarityId` dans l'univers donné.
-- Le perso garde TOUJOURS la rareté de sa fiche ; la mutation s'ajoute par-dessus.
function RollService:MakeItem(universe, rarityId: string, stats, pools)
	local available = pools or Formulas.rollPools(universe.id)
	local pool, usedRarity = poolFor(available, rarityId)
	local id = #pool > 0 and pool[rng:NextInteger(1, #pool)] or universe.characters[1]
	local def = Characters.get(id)
	local rarity = def and Economy.RollRarities[def.rarity] and def.rarity or usedRarity
	local eventLuck = self.services.EventService and self.services.EventService.AuraLuck and self.services.EventService:AuraLuck() or 1
	local mutation = Mutations.roll(rng, eventLuck * (stats.auraLuck or 1))
	local trait = nil
	if rng:NextNumber() < Traits.HatchChance * 0.4 then
		trait = Traits.roll(rng, stats.traitLuck or 1)
	end
	local entry = { id = id, level = 1, xp = 0, stars = 1, aura = mutation, trait = trait }
	return {
		key = self.services.DataService:NewUid(),
		id = id,
		rarity = rarity,
		stars = 1,
		aura = mutation, -- mutation (nom historique du champ)
		variety = mutation, -- variété visible du perso (CharacterFactory : options.variety)
		trait = trait,
		price = Formulas.rollPrice(rarity, mutation, trait, stats.rollDiscount),
		dps = math.floor(Formulas.dps(entry) + 0.5),
		at = os.time(),
	}
end

function RollService:PityRemaining(data, stats)
	local tier = Economy.Roll.PityRarity
	return { [tier] = math.max(1, Formulas.pityThreshold(tier, stats.pityMult) - (data.Pity[tier] or 0)) }
end

-- Persos protégés (Légendaire et plus) encore sur l'estrade.
local function protectedItem(queue)
	local best = nil
	for _, item in queue do
		if rarityOrder(item.rarity) >= Economy.Roll.ProtectOrder and (not best or rarityOrder(item.rarity) > rarityOrder(best.rarity)) then
			best = item
		end
	end
	return best
end

-- Vrai si le joueur se tient dans la zone de SA machine ROULER (Economy.Roll.MachineZone,
-- avec une marge pour la latence). Pas utilisé par l'auto-roulage (passes Robux, à distance).
function RollService:IsAtMachine(player: Player): boolean
	local plot = self.services.PlotService:GetPlot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not plot.cf or not root then
		return false
	end
	local PlotService = self.services.PlotService
	local machineCF = plot.cf * CFrame.new(PlotService.MachineOffset or Vector3.new(0, 0, -30))
	local p = machineCF:PointToObjectSpace(root.CFrame.Position)
	local zone = Economy.Roll.MachineZone
	local margin = Economy.Roll.MachineMargin or 6
	return math.abs(p.X) <= zone.halfX + margin and p.Z >= zone.zMin - margin and p.Z <= zone.zMax + margin and p.Y <= zone.maxY + margin
end

-- Perso de l'estrade sur lequel l'auto-roulage (Lancer AFK ou Achat automatique) doit
-- s'arrêter au lieu de le laisser passer : rareté ou mutation cochée dans « Pause sur... »,
-- ou Légendaire et mieux tant que le joueur n'a pas désactivé la pause pour cette rareté.
local function autoHoldItem(data)
	local settings = data.AutoRollSettings or {}
	local pauseRarities = settings.pauseRarities or {}
	local pauseMutations = settings.pauseMutations or {}
	local best = nil
	for _, item in data.RolledQueue or {} do
		local mutation = Mutations.normalize(item.aura) or Mutations.None
		local protected = rarityOrder(item.rarity) >= Economy.Roll.ProtectOrder and pauseRarities[item.rarity] ~= false
		if pauseRarities[item.rarity] == true or pauseMutations[mutation] == true or protected then
			if not best or rarityOrder(item.rarity) > rarityOrder(best.rarity) then
				best = item
			end
		end
	end
	return best
end

-- Roule la machine. Renvoie (true, résultats) ou (false, message, type de message).
-- options.auto = auto-roulage (pas de demande de confirmation, messages silencieux).
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
	-- Auto-roulage : jamais un perso à garder jeté en silence (AutoStep met alors en pause).
	if auto and autoHoldItem(data) then
		return false, nil
	end
	-- Un Légendaire (ou mieux) attend encore : on demande confirmation avant de le laisser passer.
	if not auto then
		local keep = protectedItem(data.RolledQueue)
		if keep and not (confirmUntil[player] and now <= confirmUntil[player]) then
			confirmUntil[player] = now + (Economy.Roll.ConfirmWindow or 6)
			return false, "⚠️ " .. itemLabel(keep) .. " est encore sur l'estrade ! Collecte-le, ou appuie encore sur ROULER pour le laisser passer.", "warning"
		end
	end
	confirmUntil[player] = nil
	lastRoll[player] = now
	data.RollCount += 1
	local count = Formulas.rollsPerRoll(player, data.RollMulti ~= 0 and data.RollMulti or nil)
	local luck = self:_luck(player, stats)
	local universe = self:_universe()
	local pools = Formulas.rollPools(universe.id)
	-- Les persos du roulage précédent qui n'ont pas été collectés passent.
	data.RolledQueue = {}
	local results = {}
	for _ = 1, count do
		local rarity = self:_pickRarity(data, stats, luck, pools)
		local item = self:MakeItem(universe, rarity, stats, pools)
		table.insert(data.RolledQueue, item)
		table.insert(results, item)
	end
	DataService:Sync(player, auto and RollService.AutoSyncWindow or nil)
	Machine.press(plot.machine, false)
	self:RenderStage(player, results)
	self:UpdatePanels(player)
	local payload = {
		results = results,
		pity = self:PityRemaining(data, stats),
		pityThreshold = Formulas.pityThreshold(Economy.Roll.PityRarity, stats.pityMult),
		luck = luck,
		count = count,
		auto = auto == true,
		universe = universe.id,
	}
	RollResult:FireClient(player, payload)
	for _, item in results do
		local info = Economy.RollRarities[item.rarity]
		local mutation = Mutations.get(item.aura)
		if info.order >= 5 or (mutation and mutation.multiplier >= 3.5) then
			Announce:FireAllClients(
				"✨ " .. player.DisplayName .. " ✨",
				"a tiré " .. itemLabel(item) .. " à la machine ROULER !",
				info.order >= 7 and Color3.fromRGB(255, 255, 255) or (info.order >= 5 and info.color or mutation and mutation.color or info.color)
			)
		end
	end
	return true, results
end

------------------------------------------------------------------------
-- Collecte
------------------------------------------------------------------------

-- Seule la CLÉ du perso est acceptée (jamais sa position).
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

-- Achète un perso tiré (`ref` = clé du perso dans RolledQueue). Renvoie (ok, message, raison).
-- raison : "coins" (pas assez d'argent), "full" (inventaire plein), "gone" (plus là).
function RollService:Collect(player: Player, ref: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return false, "Erreur.", "gone"
	end
	local index = findIndex(data.RolledQueue, ref)
	if not index then
		return false, "Ce perso n'est plus sur l'estrade.", "gone"
	end
	if DataService:CharacterCount(player) >= Economy.MaxCharacters then
		return false, "Inventaire plein (" .. Economy.MaxCharacters .. ") ! Vends des persos.", "full"
	end
	local item = data.RolledQueue[index]
	local free = Formulas.rollCollectFree(data, item.rarity)
	local price = free and 0 or item.price
	if data.coins < price then
		return false, "Il te manque ¥ " .. Formulas.formatNumber(price - data.coins) .. " pour " .. itemLabel(item) .. ".", "coins"
	end
	if price > 0 then
		DataService:SpendCoins(player, price)
	end
	table.remove(data.RolledQueue, index)
	local firstCollect = not data.FirstCollectDone
	data.FirstCollectDone = true
	local CharacterService = self.services.CharacterService
	local entry = CharacterService:CreateEntry(item.id, item.aura, item.trait)
	local isNew = not data.index[item.id]
	local uid = CharacterService:AddCharacter(player, entry)
	data.stats.hatched += 1
	DataService:Sync(player)
	self:RenderStage(player, nil, firstCollect)
	local info = Economy.RollRarities[item.rarity]
	if info.order >= 4 or isNew or item.aura then
		HatchReveal:FireClient(player, { uid = uid, entry = entry, source = "roll", rollRarity = item.rarity, isNew = isNew })
	end
	return true, (free and "🎁 Offert : " or "✅ Collecté : ") .. itemLabel(item)
end

-- Remet à zéro le délai entre deux roulages (tests, commandes admin).
function RollService:ResetCooldown(player: Player)
	lastRoll[player] = nil
end

------------------------------------------------------------------------
-- Auto-roulage (passes Robux)
------------------------------------------------------------------------

-- Nom et prix d'un passe : toujours lus dans Config/Robux (seule source de vérité).
local function priceText(key: string): string
	local pass = Robux.Passes[key]
	return pass and (pass.name .. " (" .. pass.price .. " Robux)") or key
end

-- « Lancer AFK » : roule tout seul, s'arrête sur les raretés / mutations cochées.
function RollService:SetAutoRoll(player: Player, enabled: boolean)
	local data = self.services.DataService:Get(player)
	if not data then
		return false, "Erreur."
	end
	if enabled and not canAfk(player) then
		data.AutoRoll = false
		self.services.DataService:Sync(player)
		-- Passe Robux « Lancer AFK » : on ouvre la boutique Robux sur l'onglet des passes.
		Remotes.event("Robux_OpenShop"):FireClient(player, "passes", "AutoRoll")
		return false, "🔒 Le Lancer AFK demande le passe « " .. priceText("AutoRoll") .. " »."
	end
	data.AutoRoll = enabled
	self.services.DataService:Sync(player)
	return true, enabled and "🤖 Lancer AFK : la machine roule toute seule." or "⏹ Lancer AFK arrêté."
end

-- « Achat automatique » : roule tout seul et ACHÈTE les persos qui correspondent aux cibles.
function RollService:SetAutoBuy(player: Player, enabled: boolean)
	local data = self.services.DataService:Get(player)
	if not data then
		return false, "Erreur."
	end
	if enabled then
		if not hasPass(player, "AutoRollPlus") then
			data.AutoBuy = false
			self.services.DataService:Sync(player)
			return false, "🔒 L'achat automatique demande le passe « " .. priceText("AutoRollPlus") .. " »."
		end
		local settings = data.AutoRollSettings
		local filter = { characters = settings.buyCharacters, rarities = settings.buyRarities, mutations = settings.buyMutations }
		if next(filter.characters) == nil and next(filter.rarities) == nil and next(filter.mutations) == nil then
			data.AutoBuy = false
			self.services.DataService:Sync(player)
			return false, "Choisis d'abord ce que tu veux acheter (persos, raretés ou mutations) avec « Avancé »."
		end
	end
	data.AutoBuy = enabled
	self.services.DataService:Sync(player)
	return true, enabled and "🛒 Achat automatique activé : la machine achète tes cibles pour toi." or "Achat automatique désactivé."
end

local SETTING_KEYS = {
	pauseRarities = "rarity",
	pauseMutations = "mutation",
	buyCharacters = "character",
	buyRarities = "rarity",
	buyMutations = "mutation",
}

local function validKey(kind: string, key: any): boolean
	if type(key) ~= "string" then
		return false
	end
	if kind == "rarity" then
		return Economy.RollRarities[key] ~= nil
	elseif kind == "mutation" then
		return Mutations.List[key] ~= nil or key == Mutations.None
	end
	return Characters.get(key) ~= nil
end

-- Enregistre les réglages de la fenêtre « Roulement automatique » (seulement des booléens
-- sur des clés connues : rien d'autre n'est accepté du client).
function RollService:SaveAutoSettings(player: Player, incoming: any)
	local data = self.services.DataService:Get(player)
	if not data or type(incoming) ~= "table" then
		return false, "Réglages invalides."
	end
	local settings = data.AutoRollSettings
	for field, kind in SETTING_KEYS do
		local values = incoming[field]
		if type(values) == "table" then
			local clean = {}
			local count = 0
			for key, value in values do
				if validKey(kind, key) and type(value) == "boolean" and count < 80 then
					-- Raretés de pause : booléens explicites (faux = désactivé) ; cibles : seulement vrai.
					if field == "pauseRarities" or value then
						clean[key] = value
						count += 1
					end
				end
			end
			settings[field] = clean
		end
	end
	-- Plus aucune cible : l'achat automatique s'arrête.
	if data.AutoBuy and next(settings.buyCharacters) == nil and next(settings.buyRarities) == nil and next(settings.buyMutations) == nil then
		data.AutoBuy = false
	end
	self.services.DataService:Sync(player)
	return true, "Réglages enregistrés."
end

-- Persos par roulage (1 à 3, dans la limite des passes Roulage x2 / x3).
function RollService:SetMulti(player: Player, count: any)
	local data = self.services.DataService:Get(player)
	local n = math.floor(tonumber(count) or 1)
	if not data or n < 1 or n > Economy.Roll.MaxPerRoll then
		return false, "Erreur."
	end
	if n == 3 and not hasPass(player, "Roll3") then
		return false, "🔒 Rouler 3 persos à la fois demande le passe « " .. priceText("Roll3") .. " »."
	end
	if n == 2 and not (hasPass(player, "Roll2") or hasPass(player, "Roll3")) then
		return false, "🔒 Rouler 2 persos à la fois demande le passe « " .. priceText("Roll2") .. " »."
	end
	data.RollMulti = n
	self.services.DataService:Sync(player)
	return true, "🎲 " .. n .. " perso" .. (n > 1 and "s" or "") .. " par roulage."
end

function RollService:_stopAuto(player: Player, data, message: string, kind: string?)
	data.AutoRoll = false
	data.AutoBuy = false
	self.services.DataService:Sync(player)
	Notify:FireClient(player, message, kind or "warning")
end

-- Un pas de l'auto-roulage pour un joueur (appelé toutes les AutoStep secondes).
function RollService:AutoStep(player: Player)
	local data = self.services.DataService:Get(player)
	if not data or not (data.AutoRoll or data.AutoBuy) then
		return
	end
	-- Passe perdu (remboursement...) : on arrête proprement.
	if data.AutoBuy and not hasPass(player, "AutoRollPlus") then
		data.AutoBuy = false
		self.services.DataService:Sync(player)
	end
	if data.AutoRoll and not canAfk(player) then
		data.AutoRoll = false
		self.services.DataService:Sync(player)
	end
	if not (data.AutoRoll or data.AutoBuy) then
		return
	end
	-- Un perso à garder attend déjà sur l'estrade (pause précédente non collectée, Mythique
	-- de la pitié...) : on s'arrête au lieu de le laisser passer.
	local waiting = autoHoldItem(data)
	if waiting then
		self:_stopAuto(player, data, "⏸ Auto-roulage en pause : " .. itemLabel(waiting) .. " t'attend sur l'estrade !", "success")
		return
	end
	local stats = Formulas.playerStats(data)
	if lastRoll[player] and os.clock() - lastRoll[player] < stats.rollCooldown then
		return
	end
	local ok, results = self:Roll(player, true)
	if not ok or type(results) ~= "table" then
		return
	end
	local settings = data.AutoRollSettings
	-- 1) Achat automatique des cibles.
	if data.AutoBuy then
		local filter = { characters = settings.buyCharacters, rarities = settings.buyRarities, mutations = settings.buyMutations }
		for _, item in results do
			if Formulas.rollMatches(item, filter) then
				-- Synchros de l'achat (pièces, inventaire, estrade) regroupées avec celle du roulage.
				local bought, message, reason = self.services.DataService:WithSyncWindow(player, RollService.AutoSyncWindow, self.Collect, self, player, item.key)
				if bought then
					Notify:FireClient(player, "🛒 " .. message, "success")
				elseif reason == "coins" or reason == "full" then
					self:_stopAuto(player, data, "⏹ Achat automatique arrêté : " .. message .. " Il t'attend sur l'estrade.", "error")
					return
				end
			end
		end
	end
	-- 2) Pause sur les raretés / mutations cochées (Lancer AFK et Achat automatique) pour les
	-- persos qui n'ont pas été achetés : ils restent sur l'estrade.
	local hold = autoHoldItem(data)
	if hold then
		self:_stopAuto(player, data, "⏸ Auto-roulage en pause : " .. itemLabel(hold) .. " t'attend sur l'estrade !", "success")
		return
	end
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
	local tier = Economy.Roll.PityRarity
	Machine.setPity(plot.machine, self:PityRemaining(data, stats)[tier], Formulas.pityThreshold(tier, stats.pityMult))
	local luck = self:_luck(player, stats)
	Machine.setOdds(plot.machine, Formulas.rollOdds(luck, Formulas.rollPools(self:_universe().id)), luck)
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

-- Lignes de l'étiquette d'un perso tiré : rareté, mutation, trait, DPS, nom, prix.
local function itemTagLines(item, def)
	local info = Economy.RollRarities[item.rarity] or Economy.RollRarities.common
	local mutation = Mutations.get(item.aura)
	local trait = Traits.get(item.trait)
	local lines = {
		{ name = "Rarete", text = info.name, colors = info.gradient, font = Enum.Font.LuckiestGuy, weight = 0.9 },
	}
	if mutation then
		table.insert(lines, {
			name = "Mutation",
			text = "✦ " .. mutation.name .. " ✦  " .. Mutations.multText(mutation.id),
			colors = mutation.gradient,
			font = Enum.Font.LuckiestGuy,
			weight = 0.75,
		})
	end
	if trait then
		table.insert(lines, { name = "Bonus", text = "◆ " .. trait.name, color = trait.color or Color3.fromRGB(150, 230, 255), font = Enum.Font.GothamBold, weight = 0.5 })
	end
	table.insert(lines, { name = "Dps", text = "DPS " .. Formulas.formatNumber(item.dps or 0), color = Color3.fromRGB(230, 230, 230), font = Enum.Font.GothamBold, weight = 0.5 })
	table.insert(lines, { name = "Nom", text = def.name, color = Color3.new(1, 1, 1), font = Enum.Font.LuckiestGuy, weight = 1 })
	table.insert(lines, { name = "Prix", text = "¥" .. Formulas.formatNumber(item.price), color = Color3.fromRGB(255, 215, 60), font = Enum.Font.LuckiestGuy, weight = 0.9 })
	return lines
end
RollService.itemTagLines = itemTagLines

-- Étiquette du perso tiré : hauteur (studs) et décalage au-dessus de la racine, calés sur le
-- HAUT RÉEL du modèle (cheveux, auréole compris) pour qu'elle flotte juste au-dessus de la tête.
function RollService.tagPlacement(model: Model, root: BasePart, lineCount: number): (number, number)
	local height = 2.2 + lineCount * 0.5
	local scale = model:GetAttribute("BaseScale") or 1
	local fallback = 4.4 * scale + 1.4 + lineCount * 0.25
	-- haut des pièces VISIBLES (une sphère invisible d'effet ne compte pas)
	local maxY = -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			local cf, size = part.CFrame, part.Size
			local _, _, _, _, _, _, r10, r11, r12 = cf:GetComponents()
			maxY = math.max(maxY, cf.Position.Y + (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z) / 2)
		end
	end
	local top = maxY - root.CFrame.Position.Y
	if top <= 0 or top > 12 * scale then
		return height, fallback
	end
	return height, top + 0.5 + height / 2
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
		local mutation = Mutations.get(item.aura)
		local entry = { id = item.id, level = 1, xp = 0, stars = item.stars or 1, aura = item.aura, trait = item.trait }
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
				model:PivotTo(spot.cf * CFrame.new(0, rootHeight, 0))
				local root = model.PrimaryPart
				if root then
					root.CanCollide = false
					local def = Characters.get(item.id)
					local lines = itemTagLines(item, def)
					local height, offset = RollService.tagPlacement(model, root, #lines)
					Kit.unitTag(root, lines, height, offset, 80, 6)
					local prompt = Props.prompt(root, self:_collectText(data, item), def.name, 10)
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
		local strong = info.order >= Economy.Roll.ProtectOrder or (mutation ~= nil and mutation.multiplier >= 3.5)
		local color = info.color.R + info.color.G + info.color.B < 0.3 and Color3.fromRGB(255, 255, 255) or info.color
		Machine.lightSpot(plot.machine, i, color, strong)
		if isFresh[item.key] then
			Machine.burst(plot.machine, i, mutation and mutation.color or info.color, 24 + info.order * 8 + (mutation and 20 or 0))
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
