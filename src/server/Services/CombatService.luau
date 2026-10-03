-- Ennemis de la zone d'univers : apparition par anneaux (faibles dehors, forts au centre),
-- IA simple, boss périodique, dégâts, récompenses (pièces, XP, matériaux d'évolution).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Characters = require(Shared.Config.Characters)
local Layout = require(Shared.Config.Layout)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local CharacterFactory = require(Shared.Modules.CharacterFactory)

local CombatService = {}

local CombatFX = Remotes.event("CombatFX")
local Reward = Remotes.event("Reward")
local Notify = Remotes.event("Notify")
local Announce = Remotes.event("Announce")

local AI_TICK = 0.2
local rng = Random.new()

local enemies = {} -- liste des enregistrements vivants
local byModel: { [Model]: any } = {}
local generation = 0
local enemiesFolder: Instance
local boss = nil

function CombatService:Init(services)
	self.services = services
end

function CombatService:Start()
	local zone = Workspace:WaitForChild("World"):WaitForChild("Zone")
	enemiesFolder = zone:WaitForChild("Enemies")

	task.spawn(function()
		while true do
			task.wait(AI_TICK)
			local now = os.clock()
			for i = #enemies, 1, -1 do
				local record = enemies[i]
				if record.alive then
					local ok, err = pcall(self._updateEnemy, self, record, now)
					if not ok then
						warn("[AnimeTycoon] IA ennemi : " .. tostring(err))
					end
				end
			end
		end
	end)

	-- Apparition du boss à heure fixe (identique sur tous les serveurs).
	task.spawn(function()
		local lastWindow = math.floor(os.time() / Economy.BossInterval)
		while true do
			task.wait(1)
			local window = math.floor(os.time() / Economy.BossInterval)
			local state = ReplicatedStorage:FindFirstChild("GameState")
			if state then
				state:SetAttribute("BossAt", (window + 1) * Economy.BossInterval)
				state:SetAttribute("BossAlive", boss ~= nil and boss.alive)
			end
			if window ~= lastWindow then
				lastWindow = window
				self:SpawnBoss()
			end
		end
	end)
end

------------------------------------------------------------------------
-- Apparition
------------------------------------------------------------------------

local function groundY(): number
	return 0.15
end

function CombatService:_currentUniverse()
	return self.services.UniverseService:GetCurrent()
end

function CombatService:_createEnemy(defId: string, tier: number, isBoss: boolean)
	local def = Characters.Enemies[defId]
	if not def then
		return nil
	end
	local tierStats = isBoss and Economy.Boss or Economy.EnemyTiers[tier]
	local scale = tierStats.scale
	local model = CharacterFactory.build(defId, 1, def.look, {
		scale = scale,
		name = def.name,
		humanoid = true,
		walkSpeed = isBoss and 14 or (tier == 3 and 11 or 13),
		collisionGroup = "Enemies",
	})
	local level = tierStats.level + (isBoss and 0 or rng:NextInteger(0, 3))
	local hp = tierStats.hp * (isBoss and 1 or (1 + (level - tierStats.level) * 0.08))
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Boss", isBoss)
	model:SetAttribute("DisplayName", def.name)
	model:SetAttribute("Level", level)
	model:SetAttribute("Tier", tier)
	model:SetAttribute("HP", hp)
	model:SetAttribute("MaxHP", hp)
	model:SetAttribute("AttackTick", 0)
	model:SetAttribute("AttackKind", "punch")
	model:SetAttribute("AttackColor", Color3.fromRGB(255, 80, 80))
	CollectionService:AddTag(model, "Enemy")
	CollectionService:AddTag(model, "AnimeRig")

	local spawnPos
	if isBoss then
		spawnPos = Vector3.new(0, 0, 0)
	else
		local ring = tierStats.ring
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(ring[1], ring[2])
		spawnPos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	local y = groundY() + CharacterFactory.rootHeight(model) + 0.3
	model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = enemiesFolder
	if model.PrimaryPart then
		pcall(function()
			model.PrimaryPart:SetNetworkOwner(nil)
		end)
	end

	local record = {
		defId = defId,
		def = def,
		tier = tier,
		isBoss = isBoss,
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		root = model.PrimaryPart,
		hp = hp,
		maxHp = hp,
		damage = tierStats.damage * (1 + (level - tierStats.level) * 0.05),
		level = level,
		scale = scale,
		spawnPos = spawnPos,
		alive = true,
		target = nil,
		lastAttack = 0,
		lastWander = 0,
		lastSlam = os.clock(),
		damageBy = {},
		generation = generation,
		stats = tierStats,
	}
	table.insert(enemies, record)
	byModel[model] = record
	return record
end

function CombatService:SpawnWave()
	local universe = self:_currentUniverse()
	if not universe then
		return
	end
	for tier, tierStats in Economy.EnemyTiers do
		local defId = universe.enemies[tier]
		for _ = 1, tierStats.count do
			self:_createEnemy(defId, tier, false)
		end
	end
end

function CombatService:SpawnBoss()
	if boss and boss.alive then
		return
	end
	local universe = self:_currentUniverse()
	if not universe then
		return
	end
	boss = self:_createEnemy(universe.boss, 4, true)
	if boss then
		Announce:FireAllClients("⚠️ BOSS EN APPROCHE ⚠️", boss.def.name .. " est apparu au centre de la zone !", universe.color)
	end
end

-- Supprime tous les ennemis (changement d'univers).
function CombatService:Reset()
	generation += 1
	for _, record in enemies do
		record.alive = false
		if record.model then
			record.model:Destroy()
		end
	end
	table.clear(enemies)
	table.clear(byModel)
	boss = nil
	self:SpawnWave()
end

------------------------------------------------------------------------
-- Requêtes
------------------------------------------------------------------------

function CombatService:IsInZone(position: Vector3, margin: number?): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	return flat.Magnitude < Layout.ZoneRadius + (margin or 0)
end

function CombatService:GetEnemyByModel(model: any)
	if typeof(model) ~= "Instance" then
		return nil
	end
	local record = byModel[model :: Model]
	if record and record.alive then
		return record
	end
	return nil
end

function CombatService:NearestEnemy(position: Vector3, maxDistance: number, anchor: Vector3?)
	local best, bestDist = nil, math.huge
	local center = anchor or position
	for _, record in enemies do
		if record.alive and record.root then
			local p = record.root.Position
			if (p - center).Magnitude <= maxDistance then
				local d = (p - position).Magnitude
				if d < bestDist then
					best, bestDist = record, d
				end
			end
		end
	end
	return best
end

function CombatService:GetBoss()
	return boss
end

------------------------------------------------------------------------
-- IA des ennemis
------------------------------------------------------------------------

function CombatService:_updateEnemy(record, now: number)
	local root = record.root
	local humanoid = record.humanoid
	if not root or not humanoid or not record.model.Parent then
		record.alive = false
		return
	end
	local TeamService = self.services.TeamService
	local leash = record.isBoss and 34 or 24
	local fromSpawn = (Vector3.new(root.Position.X, 0, root.Position.Z) - record.spawnPos).Magnitude

	-- Choix / validation de la cible (un perso de l'équipe d'un joueur).
	local target = record.target
	if target then
		local follower = target.follower
		if follower.koUntil or not follower.model.Parent or (follower.root.Position - root.Position).Magnitude > 40 or fromSpawn > leash then
			record.target = nil
			target = nil
		end
	end
	if not target and fromSpawn <= leash then
		local aggro = record.isBoss and 30 or 16
		local best, bestDist = nil, aggro
		for _, item in TeamService:AllFollowers() do
			local d = (item.follower.root.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = item, d
			end
		end
		if best then
			record.target = best
			target = best
		end
	end

	if record.isBoss then
		-- Attaque de zone : onde de choc.
		if now - record.lastSlam > 4 then
			local hits = {}
			for _, item in TeamService:AllFollowers() do
				if (item.follower.root.Position - root.Position).Magnitude < 20 then
					table.insert(hits, item)
				end
			end
			if #hits > 0 then
				record.lastSlam = now
				record.model:SetAttribute("AttackTick", (record.model:GetAttribute("AttackTick") or 0) + 1)
				CombatFX:FireAllClients("Slam", { position = root.Position - Vector3.new(0, CharacterFactory.rootHeight(record.model), 0), radius = 20 })
				for _, item in hits do
					TeamService:DamageFollower(item.player, item.follower, record.damage * 0.6)
				end
			end
		end
	end

	if target then
		local tpos = target.follower.root.Position
		local delta = Vector3.new(tpos.X - root.Position.X, 0, tpos.Z - root.Position.Z)
		local distance = delta.Magnitude
		local reach = 2.5 + record.scale * 1.6
		if distance > reach then
			humanoid:MoveTo(tpos - delta.Unit * (reach - 1))
		else
			humanoid:MoveTo(root.Position)
			if distance > 0.1 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + delta)
			end
			if now - record.lastAttack > (record.isBoss and 1.4 or 1.6) then
				record.lastAttack = now
				record.model:SetAttribute("AttackTick", (record.model:GetAttribute("AttackTick") or 0) + 1)
				CombatFX:FireAllClients("EnemyHit", { position = tpos, from = root.Position, amount = math.floor(record.damage) })
				TeamService:DamageFollower(target.player, target.follower, record.damage)
			end
		end
	elseif fromSpawn > 4 and fromSpawn > leash * 0.5 then
		humanoid:MoveTo(record.spawnPos + Vector3.new(0, root.Position.Y, 0))
	elseif now - record.lastWander > rng:NextNumber(3, 6) then
		record.lastWander = now
		local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		humanoid:MoveTo(record.spawnPos + offset + Vector3.new(0, root.Position.Y, 0))
	end
end

------------------------------------------------------------------------
-- Dégâts & récompenses
------------------------------------------------------------------------

function CombatService:DamageEnemy(player: Player, record, amount: number, info)
	if not record or not record.alive then
		return
	end
	record.hp -= amount
	record.damageBy[player] = (record.damageBy[player] or 0) + amount
	record.model:SetAttribute("HP", math.max(0, math.floor(record.hp)))
	record.model:SetAttribute("HitTick", (record.model:GetAttribute("HitTick") or 0) + 1)
	CombatFX:FireAllClients("Hit", {
		position = record.root.Position,
		amount = amount,
		crit = info and info.crit,
		special = info and info.special,
		kind = info and info.kind,
		color = info and info.color,
		from = info and info.from,
		attacker = info and info.attacker,
		target = record.model,
		owner = player.UserId,
	})
	if record.hp <= 0 then
		self:_kill(record, player, info)
	end
end

function CombatService:_kill(record, killer: Player, info)
	record.alive = false
	byModel[record.model] = nil
	local index = table.find(enemies, record)
	if index then
		table.remove(enemies, index)
	end
	local position = record.root.Position
	record.model:SetAttribute("Dead", true)
	CombatFX:FireAllClients("Death", { position = position, boss = record.isBoss, target = record.model })
	Debris:AddItem(record.model, 1.2)

	local universe = self:_currentUniverse()
	if record.isBoss then
		self:_rewardBoss(record, universe, position)
		boss = nil
	else
		self:_reward(killer, record, universe, position, info)
		local gen = record.generation
		task.delay(Economy.EnemyRespawn, function()
			if gen == generation then
				self:_createEnemy(record.defId, record.tier, false)
			end
		end)
	end
end

local function coinMultiplier(self, player: Player): number
	local data = self.services.DataService:Get(player)
	local stats = data and Formulas.upgradeStats(data.upgrades)
	local eventMult = self.services.EventService and self.services.EventService:CoinMultiplier() or 1
	return (stats and stats.combatCoins or 1) * eventMult
end

function CombatService:_reward(player: Player, record, universe, position: Vector3, info)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or not player.Parent then
		return
	end
	local stats = record.stats
	local bonus = 1 + (info and info.coinBonus or 0)
	local coins = math.floor(stats.coins * (1 + (record.level - stats.level) * 0.05) * coinMultiplier(self, player) * bonus)
	DataService:AddCoins(player, coins)
	Reward:FireClient(player, "coins", coins, position)
	data.stats.kills += 1

	local materialMult = self.services.EventService and self.services.EventService:MaterialMultiplier() or 1
	if universe and rng:NextNumber() < stats.materialChance then
		local amount = (record.tier == 3 and rng:NextInteger(1, 2) or 1) * materialMult
		DataService:AddMaterial(player, universe.material.id, amount)
		Reward:FireClient(player, "material", amount, position, universe.material.id)
	end
	if record.tier == 3 and rng:NextNumber() < Economy.TraitCrystalTier3Chance then
		data.traitCrystals = (data.traitCrystals or 0) + 1
		Reward:FireClient(player, "crystal", 1, position)
	end
	self.services.TeamService:GrantCombatXP(player, stats.xp)
end

function CombatService:_rewardBoss(record, universe, position: Vector3)
	local DataService = self.services.DataService
	local total = 0
	for _, damage in record.damageBy do
		total += damage
	end
	if total <= 0 then
		return
	end
	local stats = Economy.Boss
	local materialMult = self.services.EventService and self.services.EventService:MaterialMultiplier() or 1
	for player, damage in record.damageBy do
		local share = damage / total
		local data = DataService:Get(player)
		if data and player.Parent and share >= 0.03 then
			local coins = math.floor(stats.coins * math.max(share, 0.15) * coinMultiplier(self, player))
			DataService:AddCoins(player, coins)
			Reward:FireClient(player, "coins", coins, position)
			if universe then
				local amount = rng:NextInteger(stats.materials[1], stats.materials[2]) * materialMult
				DataService:AddMaterial(player, universe.material.id, amount)
				Reward:FireClient(player, "material", amount, position, universe.material.id)
				if rng:NextNumber() < stats.relicChance then
					local relic = universe.relics[#universe.relics]
					DataService:AddRelic(player, relic.id, 1)
					Notify:FireClient(player, "🎁 Le boss a lâché une relique rare : " .. relic.name .. " !", "success")
				end
			end
			local crystals = rng:NextInteger(Economy.TraitCrystalBossDrop[1], Economy.TraitCrystalBossDrop[2])
			data.traitCrystals = (data.traitCrystals or 0) + crystals
			Reward:FireClient(player, "crystal", crystals, position)
			data.stats.bossKills += 1
			self.services.TeamService:GrantCombatXP(player, stats.xp * math.max(share, 0.2))
			Notify:FireClient(player, "🏆 Boss vaincu ! Participation : " .. math.floor(share * 100) .. "%", "success")
		end
	end
	Announce:FireAllClients("🏆 BOSS VAINCU !", record.def.name .. " a été terrassé !", Color3.fromRGB(255, 200, 60))
end

return CombatService
