-- Épées du joueur : on commence avec l'Épée Rouillée, le Forgeron (hub) en vend de meilleures.
-- L'épée est un Tool classique (barre d'outils) : clic = coup d'épée, dégâts côté serveur
-- sur les ennemis devant le joueur, avec l'animation "toolslash" officielle, des traînées
-- colorées et une gerbe de particules propres à chaque épée. Rangée, l'épée reste visible sur
-- le perso (fourreau à la hanche, Couperet dans le dos).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Swords = require(Shared.Config.Swords)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local SwordBuilder = require(Shared.Modules.SwordBuilder)

local SwordService = {}

local CombatFX = Remotes.event("CombatFX")
local rng = Random.new()
local lastSwing: { [Player]: number } = {}

function SwordService:Init(services)
	self.services = services
end

function SwordService:GetEquipped(player: Player)
	local data = self.services.DataService:Get(player)
	return Swords.get(data and data.equippedSword) or Swords.get(Swords.Starter)
end

-- Donne (ou remplace) l'épée équipée dans le sac à dos du joueur.
function SwordService:GiveTool(player: Player)
	local sword = self:GetEquipped(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not sword or not backpack then
		return
	end
	local wasHolding = false
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("SwordId") then
					if child.Parent == character then
						wasHolding = true
					end
					child:Destroy()
				end
			end
		end
	end
	local tool = SwordBuilder.buildTool(sword)
	tool.Parent = backpack
	local sheath = self:AttachSheath(player, sword)
	tool.Activated:Connect(function()
		self:Swing(player, tool)
	end)
	tool.Equipped:Connect(function()
		local sound = tool.Handle:FindFirstChild("Unsheath") :: Sound?
		if sound then
			sound:Play()
		end
		if sheath and sheath.Parent then
			SwordBuilder.setDrawn(sheath, true)
		end
		-- Sortie de l'épée : gerbe et traînées seulement (la lueur ne s'intensifie qu'au coup).
		self:Flash(tool, 0.35, false)
	end)
	tool.Unequipped:Connect(function()
		if sheath and sheath.Parent then
			SwordBuilder.setDrawn(sheath, false)
		end
	end)
	if wasHolding and character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:EquipTool(tool)
		end
	end
end

-- Épée rangée visible sur le perso (fourreau à la hanche, ou Couperet dans le dos).
function SwordService:AttachSheath(player: Player, sword): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local old = character:FindFirstChild("SwordSheath")
	if old then
		old:Destroy()
	end
	local ok, sheath = pcall(SwordBuilder.buildSheath, sword)
	if not ok or not sheath then
		return nil
	end
	if not SwordBuilder.attachSheath(sheath, character, sword, false) then
		sheath:Destroy()
		return nil
	end
	sheath.Parent = character
	return sheath
end

-- Fait jaillir l'effet de l'épée un court instant : gerbe de particules, traînées et, pour un
-- coup (`boostLight` différent de false), éclat de la lueur (×2,2 le temps du coup).
function SwordService:Flash(tool: Tool, duration: number, boostLight: boolean?)
	local handle = tool:FindFirstChild("Handle")
	local volume = tool:FindFirstChild("AuraVolume")
	local switched: { Instance } = {}
	for _, holder in { handle, volume } do
		if holder then
			for _, child in holder:GetChildren() do
				if (child:IsA("Trail") and string.sub(child.Name, 1, 10) == "SwingTrail") or (child:IsA("ParticleEmitter") and child.Name == "SwingBurst") then
					(child :: any).Enabled = true
					table.insert(switched, child)
				end
			end
		end
	end
	local light = volume and volume:FindFirstChild("Glow") :: PointLight?
	local base = light and (light:GetAttribute("BaseBrightness") or light.Brightness)
	if boostLight == false then
		light = nil
	end
	if light and base then
		light:SetAttribute("BaseBrightness", base)
		light.Brightness = base * 2.2
	end
	task.delay(duration, function()
		pcall(function()
			for _, child in switched do
				(child :: any).Enabled = false -- l'épée peut avoir été remplacée entre-temps
			end
			if light and base then
				light.Brightness = base
			end
		end)
	end)
end

function SwordService:Swing(player: Player, tool: Tool)
	local sword = Swords.get(tool:GetAttribute("SwordId"))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not sword or not root or tool.Parent ~= character then
		return
	end
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < sword.cooldown then
		return
	end
	lastSwing[player] = now

	-- Animation officielle de coup d'épée (le script Animate écoute "toolanim").
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 0.3)
	local handle = tool:FindFirstChild("Handle")
	self:Flash(tool, 0.35)
	local sound = handle and handle:FindFirstChild("Slash") :: Sound?
	if sound then
		sound:Play()
	end
	local look = root.CFrame.LookVector
	CombatFX:FireAllClients("SwordSlash", {
		position = root.Position + look * 3,
		direction = look,
		color = sword.look.trail,
		kind = sword.fx,
		range = sword.range,
		owner = player.UserId,
	})

	-- Dégâts juste après le début de l'animation.
	task.delay(0.12, function()
		if not root.Parent then
			return
		end
		local CombatService = self.services.CombatService
		local origin = root.Position
		local forward = root.CFrame.LookVector
		for _, record in CombatService:GetEnemiesNear(origin, sword.range + 8) do
			local enemyRoot = record.root
			if enemyRoot then
				local offset = enemyRoot.Position - origin
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local reach = sword.range + (record.scale or 1) * 1.4
				if flat.Magnitude <= reach and (flat.Magnitude < 2.5 or flat.Unit:Dot(forward) > 0.15) then
					local crit = rng:NextNumber() < Swords.CritChance
					local damage = math.floor(sword.damage * (crit and 2 or 1) * rng:NextNumber(0.9, 1.1))
					CombatService:DamageEnemy(player, record, damage, {
						crit = crit,
						kind = sword.fx,
						color = sword.look.trail,
						from = origin,
						attacker = character,
						sword = true,
					})
				end
			end
		end
	end)
end

function SwordService:Buy(player: Player, swordId: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local sword = Swords.get(type(swordId) == "string" and swordId or nil)
	if not data or not sword then
		return false, "Épée inconnue."
	end
	if data.swords[sword.id] then
		return self:Equip(player, sword.id)
	end
	if data.coins < sword.price then
		return false, "Il te manque 💰 " .. Formulas.formatNumber(sword.price - data.coins)
	end
	DataService:SpendCoins(player, sword.price)
	data.swords[sword.id] = true
	data.equippedSword = sword.id
	DataService:Sync(player)
	self:GiveTool(player)
	return true, "🗡️ " .. sword.name .. " achetée et équipée !"
end

function SwordService:Equip(player: Player, swordId: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local sword = Swords.get(type(swordId) == "string" and swordId or nil)
	if not data or not sword or not data.swords[sword.id] then
		return false, "Tu ne possèdes pas cette épée."
	end
	data.equippedSword = sword.id
	DataService:Sync(player)
	self:GiveTool(player)
	return true, "🗡️ " .. sword.name .. " équipée !"
end

function SwordService:Start()
	local DataService = self.services.DataService
	DataService:OnPlayerLoaded(function(player, data)
		data.swords = data.swords or {}
		data.swords[Swords.Starter] = true
		if not Swords.get(data.equippedSword) or not data.swords[data.equippedSword] then
			data.equippedSword = Swords.Starter
		end
		local function onCharacter()
			task.wait(0.5)
			self:GiveTool(player)
		end
		if player.Character then
			task.spawn(onCharacter)
		end
		player.CharacterAdded:Connect(onCharacter)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
	Remotes.func("BuySword").OnServerInvoke = function(player, swordId)
		return self:Buy(player, swordId)
	end
	Remotes.func("EquipSword").OnServerInvoke = function(player, swordId)
		return self:Equip(player, swordId)
	end
end

return SwordService
