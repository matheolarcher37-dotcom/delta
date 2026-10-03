-- Équipe du joueur : les persos équipés le suivent et combattent automatiquement
-- les ennemis de la zone d'univers (ciblage auto ou clic sur un ennemi).

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local TeamService = {}

local CombatFX = Remotes.event("CombatFX")
local Notify = Remotes.event("Notify")

local TICK = 0.15
local rng = Random.new()

-- state[player] = { followers = { [uid] = follower }, target = enemyRecord? }
local state: { [Player]: any } = {}
local followersFolder: Folder

local function setupCollisionGroups()
	for _, name in { "Players", "Followers", "Enemies" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	local pairs_ = {
		{ "Followers", "Players" },
		{ "Followers", "Followers" },
		{ "Followers", "Enemies" },
		{ "Enemies", "Players" },
		{ "Enemies", "Enemies" },
	}
	for _, pair in pairs_ do
		PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], false)
	end
end

local function setCharacterGroup(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end)
end

function TeamService:Init(services)
	self.services = services
	setupCollisionGroups()
	followersFolder = Instance.new("Folder")
	followersFolder.Name = "Followers"
	followersFolder.Parent = Workspace
end

function TeamService:Start()
	local DataService = self.services.DataService

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			setCharacterGroup(character)
			task.wait(0.5)
			self:TeleportTeam(player)
		end)
		if player.Character then
			setCharacterGroup(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	DataService:OnPlayerLoaded(function(player)
		state[player] = { followers = {}, target = nil }
		self:RefreshTeam(player)
	end)
	DataService:OnPlayerRemoving(function(player)
		self:_clear(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_clear(player)
	end)

	Remotes.event("SetTarget").OnServerEvent:Connect(function(player, enemyModel)
		local s = state[player]
		if not s then
			return
		end
		local record = self.services.CombatService:GetEnemyByModel(enemyModel)
		s.target = record
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for player, s in state do
				local ok, err = pcall(self._update, self, player, s, now)
				if not ok then
					warn("[AnimeTycoon] équipe : " .. tostring(err))
				end
			end
		end
	end)
end

function TeamService:_clear(player: Player)
	local s = state[player]
	if not s then
		return
	end
	for _, follower in s.followers do
		if follower.model then
			follower.model:Destroy()
		end
	end
	state[player] = nil
end

local function ownerRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Position de formation derrière le joueur.
local function formationOffset(index: number): CFrame
	local row = (index - 1) // 3
	local col = (index - 1) % 3 - 1
	return CFrame.new(col * 5, 0, 6 + row * 5)
end

function TeamService:_spawnFollower(player: Player, uid: string, entry, index: number, previous)
	local CharacterService = self.services.CharacterService
	local model = CharacterService:BuildModel(player, uid, entry, {
		humanoid = true,
		walkSpeed = 26,
		collisionGroup = "Followers",
	})
	if not model then
		return nil
	end
	local maxHp = Formulas.maxHp(entry)
	local hp = previous and math.min(previous.hp, maxHp) or maxHp
	model:SetAttribute("Follower", true)
	model:SetAttribute("MaxHP", maxHp)
	model:SetAttribute("HP", hp)
	model:SetAttribute("AttackTick", 0)
	CollectionService:AddTag(model, "Follower")
	local scale = Formulas.visualScale(entry)
	local root = ownerRoot(player)
	local spawnCF
	if previous and previous.model and previous.model.PrimaryPart then
		spawnCF = previous.model.PrimaryPart.CFrame
	elseif root then
		spawnCF = root.CFrame * formationOffset(index) + Vector3.new(0, 2.15 * scale - 3, 0)
	else
		local plot = self.services.PlotService:GetPlot(player)
		spawnCF = plot and (self.services.PlotService:GetSpawnCFrame(plot) * CFrame.new(0, 2, 4)) or CFrame.new(0, 10, 0)
	end
	model:PivotTo(spawnCF)
	model.Parent = followersFolder
	local primary = model.PrimaryPart
	if primary then
		pcall(function()
			primary:SetNetworkOwner(nil)
		end)
	end
	return {
		uid = uid,
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		root = model.PrimaryPart,
		hp = hp,
		maxHp = maxHp,
		signature = CharacterService.signatureOf(entry),
		lastAttack = 0,
		attackCount = 0,
		koUntil = nil,
		index = index,
		lastMove = 0,
	}
end

-- Synchronise les persos qui suivent le joueur avec son équipe.
function TeamService:RefreshTeam(player: Player)
	local s = state[player]
	local data = self.services.DataService:Get(player)
	if not s or not data then
		return
	end
	local keep = {}
	for index, uid in data.team do
		local entry = data.characters[uid]
		if entry then
			keep[uid] = true
			local follower = s.followers[uid]
			local signature = self.services.CharacterService.signatureOf(entry)
			if follower and follower.signature ~= signature then
				local previous = follower
				s.followers[uid] = self:_spawnFollower(player, uid, entry, index, previous)
				previous.model:Destroy()
			elseif not follower then
				s.followers[uid] = self:_spawnFollower(player, uid, entry, index, nil)
			else
				follower.index = index
				follower.maxHp = Formulas.maxHp(entry)
				follower.model:SetAttribute("MaxHP", follower.maxHp)
				self.services.CharacterService:ApplyAttributes(follower.model, player, uid, entry)
			end
		end
	end
	for uid, follower in s.followers do
		if not keep[uid] then
			follower.model:Destroy()
			s.followers[uid] = nil
		end
	end
end

function TeamService:TeleportTeam(player: Player)
	local s = state[player]
	local root = ownerRoot(player)
	if not s or not root then
		return
	end
	for _, follower in s.followers do
		if follower.model.Parent and follower.root then
			local scale = follower.model:GetAttribute("BaseScale") or 1
			follower.model:PivotTo(root.CFrame * formationOffset(follower.index) + Vector3.new(0, 2.15 * scale - 3 + 0.5, 0))
		end
	end
end

function TeamService:GetFollowerModel(player: Player, uid: string): Model?
	local s = state[player]
	local follower = s and s.followers[uid]
	return follower and follower.model
end

function TeamService:GetFollowers(player: Player)
	local s = state[player]
	return s and s.followers or {}
end

function TeamService:AllFollowers()
	local list = {}
	for player, s in state do
		for _, follower in s.followers do
			if not follower.koUntil and follower.model.Parent then
				table.insert(list, { player = player, follower = follower })
			end
		end
	end
	return list
end

------------------------------------------------------------------------
-- Combat
------------------------------------------------------------------------

function TeamService:DamageFollower(player: Player, follower, amount: number)
	if follower.koUntil then
		return
	end
	follower.hp -= amount
	follower.model:SetAttribute("HP", math.max(0, follower.hp))
	follower.model:SetAttribute("HitTick", (follower.model:GetAttribute("HitTick") or 0) + 1)
	if follower.hp <= 0 then
		follower.koUntil = os.clock() + Economy.FollowerKOTime
		follower.hp = 0
		CombatFX:FireAllClients("KO", { position = follower.root.Position })
		follower.model.Parent = nil
		local desc = self.services.DataService:Get(player)
		local entry = desc and desc.characters[follower.uid]
		local info = entry and Formulas.describe(entry)
		Notify:FireClient(player, "💫 " .. (info and info.name or "Un perso") .. " est K.O. ! Retour dans " .. Economy.FollowerKOTime .. "s", "warning")
	end
end

function TeamService:_update(player: Player, s, now: number)
	local root = ownerRoot(player)
	local CombatService = self.services.CombatService
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local ownerInZone = root ~= nil and CombatService:IsInZone(root.Position, 6)

	-- Cible prioritaire (clic) encore valide ?
	if s.target and (not s.target.alive or not ownerInZone) then
		s.target = nil
	end

	for _, follower in s.followers do
		local model = follower.model
		if follower.koUntil then
			if now >= follower.koUntil then
				follower.koUntil = nil
				follower.hp = follower.maxHp
				model:SetAttribute("HP", follower.hp)
				model.Parent = followersFolder
				if root then
					local scale = model:GetAttribute("BaseScale") or 1
					model:PivotTo(root.CFrame * formationOffset(follower.index) + Vector3.new(0, 2.15 * scale - 2.5, 0))
				end
			end
			continue
		end
		local froot = follower.root
		local humanoid = follower.humanoid
		if not froot or not humanoid or not model.Parent then
			continue
		end
		local scale = model:GetAttribute("BaseScale") or 1

		-- Régénération hors de la zone.
		if not ownerInZone and follower.hp < follower.maxHp then
			follower.hp = math.min(follower.maxHp, follower.hp + follower.maxHp * 0.04 * TICK * 4)
			model:SetAttribute("HP", math.floor(follower.hp))
		end

		local target = nil
		if ownerInZone and root then
			if s.target and s.target.alive then
				target = s.target
			else
				target = CombatService:NearestEnemy(froot.Position, Economy.FollowerAggroRange, root.Position)
			end
		end

		if target and target.root then
			local targetPos = target.root.Position
			local flatDelta = Vector3.new(targetPos.X - froot.Position.X, 0, targetPos.Z - froot.Position.Z)
			local distance = flatDelta.Magnitude
			local reach = Economy.FollowerRange + (target.scale or 1) * 1.6 + scale
			local kind = model:GetAttribute("AttackKind")
			if kind == "beam" or kind == "orb" or kind == "lightning" then
				reach += 6 -- attaques à distance
			end
			if distance > reach then
				local goal = targetPos - flatDelta.Unit * (reach - 1.5)
				if now - follower.lastMove > 0.3 then
					humanoid:MoveTo(goal)
					follower.lastMove = now
				end
			else
				humanoid:MoveTo(froot.Position)
				if distance > 0.1 then
					froot.CFrame = CFrame.lookAt(froot.Position, froot.Position + flatDelta)
				end
				if now - follower.lastAttack >= Economy.FollowerAttackCooldown then
					follower.lastAttack = now
					self:_attack(player, follower, target, data)
				end
			end
		elseif root then
			-- Suivre le joueur en formation.
			local goalCF = root.CFrame * formationOffset(follower.index)
			local goal = goalCF.Position
			local distance = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(froot.Position.X, 0, froot.Position.Z)).Magnitude
			if distance > 90 then
				model:PivotTo(CFrame.new(goal + Vector3.new(0, 2.15 * scale - 2.5, 0)) * root.CFrame.Rotation)
			elseif distance > 3 then
				if now - follower.lastMove > 0.2 then
					humanoid:MoveTo(goal)
					follower.lastMove = now
				end
				humanoid.WalkSpeed = distance > 20 and 34 or 26
			end
		end
	end
end

function TeamService:_attack(player: Player, follower, target, data)
	local entry = data.characters[follower.uid]
	if not entry then
		return
	end
	follower.attackCount += 1
	local special = follower.attackCount % Economy.SpecialEvery == 0
	local crit = rng:NextNumber() < Economy.CritChance
	local damage = Formulas.power(entry) * rng:NextNumber(0.9, 1.1)
	if special then
		damage *= 3
	end
	if crit then
		damage *= 2
	end
	local model = follower.model
	model:SetAttribute("AttackTick", (model:GetAttribute("AttackTick") or 0) + 1)
	if special then
		model:SetAttribute("SpecialTick", (model:GetAttribute("SpecialTick") or 0) + 1)
	end
	self.services.CombatService:DamageEnemy(player, target, math.floor(damage), {
		crit = crit,
		special = special,
		kind = model:GetAttribute("AttackKind"),
		color = model:GetAttribute("AttackColor"),
		from = follower.root.Position,
		attacker = model,
	})
end

-- XP de combat partagée entre les persos actifs de l'équipe.
function TeamService:GrantCombatXP(player: Player, amount: number)
	local s = state[player]
	if not s then
		return
	end
	local active = {}
	for uid, follower in s.followers do
		if not follower.koUntil then
			table.insert(active, uid)
		end
	end
	if #active == 0 then
		return
	end
	local share = amount / #active
	for _, uid in active do
		self.services.CharacterService:AddXP(player, uid, share)
	end
end

return TeamService
