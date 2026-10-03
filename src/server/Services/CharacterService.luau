-- Personnages possédés : ajout, niveaux, exposition sur la base, revenus passifs,
-- équiper / verrouiller / vendre.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local CharacterBuilder = require(Shared.Modules.CharacterBuilder)

local CharacterService = {}

local Notify = Remotes.event("Notify")
local CombatFX = Remotes.event("CombatFX")

-- state[player] = { models = { [uid] = { model, signature, slot } } }
local state: { [Player]: any } = {}

local function signatureOf(entry): string
	return string.format("%s|%s|%d|%s|%.2f", entry.id, entry.fusion and (entry.fusion.a .. entry.fusion.b) or "", entry.stars or 1, entry.aura or "", Formulas.visualScale(entry))
end
CharacterService.signatureOf = signatureOf

-- Applique les attributs visibles par le client (étiquettes, auras, animations).
function CharacterService:ApplyAttributes(model: Model, player: Player, uid: string, entry)
	local desc = Formulas.describe(entry)
	model:SetAttribute("Uid", uid)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("DisplayName", desc and desc.name or "?")
	model:SetAttribute("Rarity", desc and desc.rarity or "common")
	model:SetAttribute("Level", entry.level)
	model:SetAttribute("Stars", entry.stars or 1)
	model:SetAttribute("Aura", entry.aura)
	model:SetAttribute("AttackKind", desc and desc.attack.kind or "punch")
	model:SetAttribute("AttackColor", desc and desc.attack.color or Color3.new(1, 1, 1))
	model:SetAttribute("AttackName", desc and desc.attack.name or "Attaque")
	model:SetAttribute("Power", Formulas.power(entry))
end

function CharacterService:BuildModel(player: Player, uid: string, entry, options)
	local desc = Formulas.describe(entry)
	if not desc then
		return nil
	end
	local scale = Formulas.visualScale(entry)
	local opts = options or {}
	local model = CharacterBuilder.build(desc.look, {
		scale = scale,
		name = desc.name,
		humanoid = opts.humanoid,
		anchored = opts.anchored,
		walkSpeed = opts.walkSpeed,
		collisionGroup = opts.collisionGroup,
	})
	self:ApplyAttributes(model, player, uid, entry)
	CollectionService:AddTag(model, "AnimeRig")
	return model
end

function CharacterService:Init(services)
	self.services = services
end

function CharacterService:Start()
	local DataService = self.services.DataService
	DataService:OnPlayerLoaded(function(player, data)
		state[player] = { models = {}, syncTimer = 0 }
		-- Nettoyage d'éventuelles entrées invalides.
		for uid, entry in data.characters do
			if not Formulas.describe(entry) then
				data.characters[uid] = nil
			end
		end
		local cleanTeam = {}
		for _, uid in data.team do
			if data.characters[uid] and not table.find(cleanTeam, uid) then
				table.insert(cleanTeam, uid)
			end
		end
		data.team = cleanTeam
		self:Refresh(player)
	end)
	DataService:OnPlayerRemoving(function(player)
		local s = state[player]
		if s then
			for _, info in s.models do
				if info.model then
					info.model:Destroy()
				end
			end
		end
		state[player] = nil
	end)

	Remotes.func("EquipCharacter").OnServerInvoke = function(player, uid, equip)
		return self:SetEquipped(player, uid, equip == true)
	end
	Remotes.func("ToggleLock").OnServerInvoke = function(player, uid)
		return self:ToggleLock(player, uid)
	end
	Remotes.func("SellCharacter").OnServerInvoke = function(player, uid)
		return self:Sell(player, uid)
	end
	Remotes.func("AutoEquip").OnServerInvoke = function(player)
		return self:AutoEquip(player)
	end

	-- Boucle de revenus / entraînement passif (1 fois par seconde).
	task.spawn(function()
		while true do
			task.wait(1)
			for player, s in state do
				local ok, err = pcall(self._tick, self, player, s)
				if not ok then
					warn("[AnimeTycoon] tick : " .. tostring(err))
				end
			end
		end
	end)
end

function CharacterService:_tick(player: Player, s)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return
	end
	local stats = Formulas.upgradeStats(data.upgrades)
	local coinMult = self.services.EventService and self.services.EventService:CoinMultiplier() or 1
	local total = 0
	local xpGain = Economy.PassiveXP * stats.xp
	for _, uid in self:GetDisplayed(player) do
		local entry = data.characters[uid]
		if entry then
			total += Formulas.income(entry, stats.income)
			self:AddXP(player, uid, xpGain, true)
		end
	end
	data.stash += total * coinMult
	player:SetAttribute("IncomePerSec", math.floor(total * coinMult))
	-- Synchro légère toutes les 5 secondes pour l'XP passive.
	s.syncTimer += 1
	if s.syncTimer >= 5 then
		s.syncTimer = 0
		DataService:Sync(player)
	end
end

------------------------------------------------------------------------
-- Inventaire
------------------------------------------------------------------------

function CharacterService:CreateEntry(characterId: string, aura: string?)
	return {
		id = characterId,
		level = 1,
		xp = 0,
		stars = 1,
		aura = aura,
		locked = false,
		obtained = os.time(),
	}
end

function CharacterService:AddCharacter(player: Player, entry): string?
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return nil
	end
	local uid = DataService:NewUid()
	data.characters[uid] = entry
	data.index[Formulas.indexKey(entry)] = true
	-- Équipe automatiquement si l'équipe n'est pas pleine.
	local stats = Formulas.upgradeStats(data.upgrades)
	if #data.team < stats.team then
		table.insert(data.team, uid)
	end
	DataService:Sync(player)
	self:Refresh(player)
	if self.services.TeamService then
		self.services.TeamService:RefreshTeam(player)
	end
	return uid
end

function CharacterService:RemoveCharacter(player: Player, uid: string)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return
	end
	data.characters[uid] = nil
	local index = table.find(data.team, uid)
	if index then
		table.remove(data.team, index)
	end
	DataService:Sync(player)
end

-- Persos exposés sur la base : hors équipe, triés par puissance.
function CharacterService:GetDisplayed(player: Player): { string }
	local data = self.services.DataService:Get(player)
	if not data then
		return {}
	end
	local list = {}
	for uid, entry in data.characters do
		if not table.find(data.team, uid) then
			table.insert(list, { uid = uid, power = Formulas.power(entry) })
		end
	end
	table.sort(list, function(a, b)
		if a.power == b.power then
			return a.uid < b.uid
		end
		return a.power > b.power
	end)
	local stats = Formulas.upgradeStats(data.upgrades)
	local result = {}
	for i = 1, math.min(#list, stats.display, #self.services.PlotService.DisplaySlots) do
		result[i] = list[i].uid
	end
	return result
end

function CharacterService:GetBestLook(player: Player)
	local data = self.services.DataService:Get(player)
	if not data then
		return nil
	end
	local best, bestPower = nil, -1
	for _, entry in data.characters do
		local power = Formulas.power(entry)
		if power > bestPower then
			best, bestPower = entry, power
		end
	end
	local desc = best and Formulas.describe(best)
	return desc and desc.look
end

-- Met à jour les modèles exposés sur la base.
function CharacterService:Refresh(player: Player)
	local s = state[player]
	local data = self.services.DataService:Get(player)
	local plot = self.services.PlotService:GetPlot(player)
	if not s or not data or not plot then
		return
	end
	local displayed = self:GetDisplayed(player)
	local keep = {}
	for slot, uid in displayed do
		keep[uid] = true
		local entry = data.characters[uid]
		local info = s.models[uid]
		local signature = signatureOf(entry)
		if info and info.signature ~= signature then
			info.model:Destroy()
			info = nil
			s.models[uid] = nil
		end
		local scale = Formulas.visualScale(entry)
		local target = self.services.PlotService:GetDisplayCFrame(plot, slot) * CFrame.new(0, 2.15 * scale, 0)
		if not info then
			local model = self:BuildModel(player, uid, entry, { anchored = true })
			if model then
				model.PrimaryPart.CanCollide = false
				CollectionService:AddTag(model, "DisplayCharacter")
				model:PivotTo(target)
				model.Parent = plot.displayFolder
				s.models[uid] = { model = model, signature = signature, slot = slot }
			end
		else
			if info.slot ~= slot then
				info.model:PivotTo(target)
				info.slot = slot
			end
			self:ApplyAttributes(info.model, player, uid, entry)
		end
	end
	for uid, info in s.models do
		if not keep[uid] then
			info.model:Destroy()
			s.models[uid] = nil
		end
	end
end

function CharacterService:GetDisplayModel(player: Player, uid: string): Model?
	local s = state[player]
	local info = s and s.models[uid]
	return info and info.model
end

function CharacterService:GetDisplayModels(player: Player)
	local s = state[player]
	return s and s.models or {}
end

------------------------------------------------------------------------
-- Niveaux
------------------------------------------------------------------------

function CharacterService:AddXP(player: Player, uid: string, amount: number, silent: boolean?)
	local data = self.services.DataService:Get(player)
	local entry = data and data.characters[uid]
	if not entry then
		return
	end
	local cap = Formulas.levelCap(entry.stars)
	if entry.level >= cap then
		entry.xp = math.min(entry.xp + amount, Formulas.xpToNext(entry.level))
		return
	end
	entry.xp += amount
	local leveled = false
	local oldScale = Formulas.visualScale(entry)
	while entry.level < cap and entry.xp >= Formulas.xpToNext(entry.level) do
		entry.xp -= Formulas.xpToNext(entry.level)
		entry.level += 1
		leveled = true
	end
	if entry.level >= cap then
		entry.xp = math.min(entry.xp, Formulas.xpToNext(entry.level))
	end
	if leveled then
		local model = self:GetDisplayModel(player, uid)
		local follower = self.services.TeamService and self.services.TeamService:GetFollowerModel(player, uid)
		local target = model or follower
		if target and target.PrimaryPart then
			target:SetAttribute("Level", entry.level)
			target:SetAttribute("Power", Formulas.power(entry))
			CombatFX:FireClient(player, "LevelUp", { position = target.PrimaryPart.Position, level = entry.level })
		end
		if Formulas.visualScale(entry) ~= oldScale then
			-- Le perso grandit ! On reconstruit son modèle.
			self:Refresh(player)
			if self.services.TeamService then
				self.services.TeamService:RefreshTeam(player)
			end
		end
		if entry.level >= cap and not silent then
			local desc = Formulas.describe(entry)
			Notify:FireClient(player, "⭐ " .. (desc and desc.name or "Perso") .. " a atteint le niveau max ! Fais-le évoluer à l'Autel d'Éveil.", "info")
		end
		self.services.DataService:Sync(player)
	end
end

------------------------------------------------------------------------
-- Actions du joueur
------------------------------------------------------------------------

function CharacterService:SetEquipped(player: Player, uid: any, equip: boolean)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(uid) ~= "string" or not data.characters[uid] then
		return false, "Perso introuvable."
	end
	local index = table.find(data.team, uid)
	if equip then
		if index then
			return true
		end
		local stats = Formulas.upgradeStats(data.upgrades)
		if #data.team >= stats.team then
			return false, "Équipe pleine (" .. stats.team .. " max). Débloque plus de places dans ta base !"
		end
		table.insert(data.team, uid)
	else
		if not index then
			return true
		end
		table.remove(data.team, index)
	end
	DataService:Sync(player)
	self:Refresh(player)
	self.services.TeamService:RefreshTeam(player)
	return true
end

function CharacterService:AutoEquip(player: Player)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local list = {}
	for uid, entry in data.characters do
		table.insert(list, { uid = uid, power = Formulas.power(entry) })
	end
	table.sort(list, function(a, b)
		return a.power > b.power
	end)
	local stats = Formulas.upgradeStats(data.upgrades)
	data.team = {}
	for i = 1, math.min(stats.team, #list) do
		table.insert(data.team, list[i].uid)
	end
	DataService:Sync(player)
	self:Refresh(player)
	self.services.TeamService:RefreshTeam(player)
	return true
end

function CharacterService:ToggleLock(player: Player, uid: any)
	local data = self.services.DataService:Get(player)
	if not data or type(uid) ~= "string" or not data.characters[uid] then
		return false
	end
	local entry = data.characters[uid]
	entry.locked = not entry.locked
	self.services.DataService:Sync(player)
	return true
end

function CharacterService:Sell(player: Player, uid: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(uid) ~= "string" or not data.characters[uid] then
		return false, "Perso introuvable."
	end
	local entry = data.characters[uid]
	if entry.locked then
		return false, "Ce perso est verrouillé 🔒"
	end
	if self.services.TradeService and self.services.TradeService:IsInTrade(player) then
		return false, "Impossible pendant un échange."
	end
	if DataService:CharacterCount(player) <= 1 then
		return false, "Tu dois garder au moins un perso !"
	end
	local value = Formulas.sellValue(entry)
	self:RemoveCharacter(player, uid)
	DataService:AddCoins(player, value)
	self:Refresh(player)
	self.services.TeamService:RefreshTeam(player)
	local desc = Formulas.describe(entry)
	local rarity = Rarities.get(desc and desc.rarity or "common")
	return true, "Vendu " .. (desc and desc.name or "") .. " (" .. rarity.name .. ") pour 💰 " .. Formulas.formatNumber(value)
end

return CharacterService
