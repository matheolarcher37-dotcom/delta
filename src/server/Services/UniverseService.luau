-- Rotation des univers : un nouvel univers toutes les 30 minutes (même univers sur tous les serveurs).
-- Change le décor de la zone, l'ambiance lumineuse, les ennemis et les reliques en vente.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local RelicBuilder = require(Shared.Modules.RelicBuilder)
local UniverseDecor = require(script.Parent.Parent.World.UniverseDecor)

local UniverseService = {}

local Announce = Remotes.event("Announce")
local CombatFX = Remotes.event("CombatFX")

local gameState: Folder
local currentIndex = 0
local offset = 0 -- décalage de temps (commandes admin pour tester)
local infoLabels = nil

function UniverseService:Init(services)
	self.services = services
	gameState = ReplicatedStorage:FindFirstChild("GameState") :: Folder
	if not gameState then
		gameState = Instance.new("Folder")
		gameState.Name = "GameState"
		gameState.Parent = ReplicatedStorage
	end
end

function UniverseService:Now(): number
	return os.time() + offset
end

function UniverseService:IndexAt(time: number): number
	return math.floor(time / Economy.UniverseDuration) % #Universes.List + 1
end

function UniverseService:GetCurrent()
	return Universes.List[currentIndex] or Universes.List[1]
end

function UniverseService:GetEndsAt(): number
	local now = self:Now()
	return (math.floor(now / Economy.UniverseDuration) + 1) * Economy.UniverseDuration - offset
end

-- Passe à l'univers suivant immédiatement (admin / tests).
function UniverseService:Skip()
	local now = self:Now()
	local remaining = (math.floor(now / Economy.UniverseDuration) + 1) * Economy.UniverseDuration - now
	offset += remaining + 1
end

local function applyLighting(universe, instant: boolean)
	local theme = universe.theme
	local info = TweenInfo.new(instant and 0 or 2.5, Enum.EasingStyle.Sine)
	Lighting.ClockTime = theme.clockTime
	TweenService:Create(Lighting, info, { Ambient = theme.ambient, OutdoorAmbient = theme.outdoorAmbient }):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Color = theme.atmosphereColor, Decay = theme.atmosphereDecay, Haze = theme.haze }):Play()
	end
	local grading = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grading then
		TweenService:Create(grading, info, { TintColor = theme.tint, Saturation = theme.saturation }):Play()
	end
end

function UniverseService:_updateMachines(universe)
	local relic = universe.relics[#universe.relics]
	for _, plot in self.services.PlotService:GetPlots() do
		local machine = plot.model.Interactive:FindFirstChild("RelicMachine")
		if machine and plot.relicDisplayCF then
			local old = machine:FindFirstChild("DomeRelic")
			if old then
				old:Destroy()
			end
			local model = RelicBuilder.build(relic.look, relic.tier, 1.4)
			model.Name = "DomeRelic"
			model:PivotTo(plot.relicDisplayCF)
			model:SetAttribute("SpinSpeed", 1.2)
			CollectionService:AddTag(model, "SpinModel")
			model.Parent = machine
		end
	end
end

function UniverseService:_apply(universe, instant: boolean)
	local zone = Workspace:WaitForChild("World"):WaitForChild("Zone")
	UniverseDecor.apply(universe, zone)
	applyLighting(universe, instant)
	self:_updateMachines(universe)
	self.services.CombatService:Reset()
	gameState:SetAttribute("UniverseId", universe.id)
	gameState:SetAttribute("UniverseIndex", universe.index)
end

function UniverseService:Start()
	currentIndex = self:IndexAt(self:Now())
	self:_apply(self:GetCurrent(), true)
	self:_setupInfoBoard()

	task.spawn(function()
		while true do
			task.wait(1)
			local index = self:IndexAt(self:Now())
			local nextIndex = index % #Universes.List + 1
			gameState:SetAttribute("UniverseEndsAt", self:GetEndsAt())
			gameState:SetAttribute("NextUniverseId", Universes.List[nextIndex].id)
			if index ~= currentIndex then
				currentIndex = index
				local universe = self:GetCurrent()
				CombatFX:FireAllClients("Rift", { color = universe.color })
				Announce:FireAllClients("🌀 FAILLE INTER-UNIVERS 🌀", "Bienvenue dans : " .. universe.name .. " (inspiré de " .. universe.inspiration .. ")", universe.color)
				task.wait(1.2)
				self:_apply(universe, false)
			end
			self:_updateInfoBoard()
		end
	end)
end

------------------------------------------------------------------------
-- Panneau d'information
------------------------------------------------------------------------

function UniverseService:_setupInfoBoard()
	local board = Workspace.World.Boards:FindFirstChild("InfoBoard")
	local gui = board and board.Panel:FindFirstChild("Display")
	if not gui then
		return
	end
	local function label(name: string, y: number, h: number, color: Color3, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.TextScaled = true
		l.Font = font
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.2
		l.Text = ""
		l.Parent = gui
		return l
	end
	infoLabels = {
		name = label("Name", 0.04, 0.2, Color3.new(1, 1, 1), Enum.Font.LuckiestGuy),
		inspiration = label("Inspiration", 0.25, 0.1, Color3.fromRGB(200, 200, 220), Enum.Font.GothamBold),
		timer = label("Timer", 0.38, 0.18, Color3.fromRGB(255, 220, 90), Enum.Font.LuckiestGuy),
		nextName = label("Next", 0.6, 0.1, Color3.fromRGB(180, 220, 255), Enum.Font.GothamBold),
		boss = label("Boss", 0.74, 0.1, Color3.fromRGB(255, 120, 120), Enum.Font.GothamBold),
		event = label("Event", 0.86, 0.1, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold),
	}
end

-- Panneau flottant au-dessus du cristal du hub.
function UniverseService:_updateHubBillboard()
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local crystal = hub and hub:FindFirstChild("Crystal", true)
	local gui = crystal and crystal:FindFirstChild("UniverseBillboard")
	if not gui then
		return
	end
	local universe = self:GetCurrent()
	local title = gui:FindFirstChild("Title") :: TextLabel?
	local timer = gui:FindFirstChild("Timer") :: TextLabel?
	if title then
		title.Text = "🌀 " .. universe.name
		title.TextColor3 = universe.color:Lerp(Color3.new(1, 1, 1), 0.3)
	end
	if timer then
		timer.Text = "⏳ Prochain univers dans " .. Formulas.formatTime(self:GetEndsAt() - os.time())
	end
end

function UniverseService:_updateInfoBoard()
	self:_updateHubBillboard()
	if not infoLabels then
		return
	end
	local universe = self:GetCurrent()
	local nextUniverse = Universes.get(gameState:GetAttribute("NextUniverseId") or "") or universe
	infoLabels.name.Text = universe.name
	infoLabels.name.TextColor3 = universe.color
	infoLabels.inspiration.Text = "Inspiré de " .. universe.inspiration
	infoLabels.timer.Text = "⏳ " .. Formulas.formatTime(self:GetEndsAt() - os.time())
	infoLabels.nextName.Text = "Ensuite : " .. nextUniverse.name
	local bossAt = gameState:GetAttribute("BossAt")
	if gameState:GetAttribute("BossAlive") then
		infoLabels.boss.Text = "👹 Boss en cours dans l'arène !"
	elseif bossAt then
		infoLabels.boss.Text = "👹 Boss dans " .. Formulas.formatTime(bossAt - os.time())
	end
	local eventName = gameState:GetAttribute("EventName")
	infoLabels.event.Text = eventName and ("✨ Événement : " .. eventName) or ""
end

return UniverseService
