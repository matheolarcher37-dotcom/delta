-- Les stands du hub central : chaque stand ouvre son menu (Fusionner, Traits, Forgeron,
-- Faire évoluer, Index). Le stand "Défi" téléporte à l'arène du boss.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local HubService = {}

local OpenMenu = Remotes.event("OpenMenu")
local Notify = Remotes.event("Notify")

function HubService:Init(services)
	self.services = services
end

-- Entrée de l'arène du boss (côté hub), tournée vers l'arène.
function HubService:GetArenaEntrance(): CFrame
	local center = Layout.BossArena
	local inward = -center.Unit
	local pos = center + inward * (Layout.BossArenaRadius + 6)
	return CFrame.lookAt(pos + Vector3.new(0, 3, 0), center + Vector3.new(0, 3, 0))
end

function HubService:Challenge(player: Player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	character:PivotTo(self:GetArenaEntrance())
	if self.services.TeamService then
		task.delay(0.2, function()
			self.services.TeamService:TeleportTeam(player)
		end)
	end
	local CombatService = self.services.CombatService
	local boss = CombatService and CombatService:GetBoss()
	if boss then
		Notify:FireClient(player, "👹 Le boss est là ! À l'attaque !", "success")
	else
		local gameState = ReplicatedStorage:FindFirstChild("GameState")
		local bossAt = gameState and gameState:GetAttribute("BossAt")
		if bossAt then
			Notify:FireClient(player, "👹 Prochain boss dans " .. Formulas.formatTime(bossAt - os.time()), "info")
		else
			Notify:FireClient(player, "👹 Le boss arrive bientôt ici !", "info")
		end
	end
end

function HubService:_hook(stall: Instance)
	local menu = stall:GetAttribute("Menu")
	for _, prompt in stall:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				if menu == "Challenge" then
					self:Challenge(player)
				elseif menu then
					OpenMenu:FireClient(player, menu)
				end
			end)
		end
	end
end

function HubService:Start()
	for _, stall in CollectionService:GetTagged("HubStall") do
		self:_hook(stall)
	end
	CollectionService:GetInstanceAddedSignal("HubStall"):Connect(function(stall)
		self:_hook(stall)
	end)
end

return HubService
