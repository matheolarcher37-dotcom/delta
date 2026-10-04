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

-- Ciel et lumière de l'univers : heure, Atmosphere, nuages, soleil/lune/étoiles, effets, couleur
-- de l'eau (theme.ciel, voir Config/Universes).
local function applyLighting(universe, instant: boolean)
	local theme = universe.theme
	local ciel = theme.ciel or {}
	local info = TweenInfo.new(instant and 0 or 2.5, Enum.EasingStyle.Sine)
	local function tween(instance: Instance?, goal: { [string]: any })
		if instance then
			TweenService:Create(instance, info, goal):Play()
		end
	end
	Lighting.ClockTime = ciel.clockTime or theme.clockTime
	Lighting.GeographicLatitude = ciel.latitude or 35
	Lighting.ExposureCompensation = ciel.exposure or 0
	tween(Lighting, { Ambient = theme.ambient, OutdoorAmbient = theme.outdoorAmbient, Brightness = ciel.brightness or 3 })
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), {
		Color = ciel.atmosphereColor or theme.atmosphereColor,
		Decay = ciel.atmosphereDecay or theme.atmosphereDecay,
		Haze = ciel.haze or theme.haze,
		Density = ciel.density or 0.3,
		Offset = ciel.offset or 0.2,
		Glare = ciel.glare or 0.3,
	})
	tween(Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), {
		TintColor = theme.tint,
		Saturation = theme.saturation,
		Contrast = ciel.contrast or 0.08,
	})
	tween(Lighting:FindFirstChildOfClass("BloomEffect"), { Intensity = ciel.bloom or 0.45 })
	tween(Lighting:FindFirstChildOfClass("SunRaysEffect"), { Intensity = ciel.sunRays or 0.1 })
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.StarCount = ciel.stars or 0
		sky.SunAngularSize = ciel.sunSize or 16
		sky.MoonAngularSize = ciel.moonSize or 11
		sky.CelestialBodiesShown = true
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		tween(terrain:FindFirstChildOfClass("Clouds"), {
			Cover = ciel.cloudCover or 0.6,
			Density = ciel.cloudDensity or 0.55,
			Color = ciel.cloudColor or Color3.new(1, 1, 1),
		})
		if ciel.water then
			pcall(function()
				terrain.WaterColor = ciel.water
			end)
		end
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

-- Décor des BASES selon l'univers (murs, portail, déco Naruto / Gojo...) : module
-- World/BaseDecor (domaine des bases). Point d'appel unique : s'il n'existe pas encore, rien ne
-- se passe ; une erreur dedans n'empêche jamais le changement d'univers.
local function applyBaseDecor(universe)
	local world = script.Parent.Parent:FindFirstChild("World")
	local moduleScript = world and world:FindFirstChild("BaseDecor")
	if not moduleScript then
		return
	end
	local ok, err = pcall(function()
		local BaseDecor = require(moduleScript) :: any
		if BaseDecor.applyAll then
			BaseDecor.applyAll(universe)
		end
	end)
	if not ok then
		warn("[UniverseService] BaseDecor.applyAll : " .. tostring(err))
	end
end

function UniverseService:_apply(universe, instant: boolean)
	local zone = Workspace:WaitForChild("World"):WaitForChild("Zone")
	-- toute la carte change : anneau, île, horizon, sol, ciel, particules, puis les bases
	UniverseDecor.apply(universe, zone)
	applyLighting(universe, instant)
	applyBaseDecor(universe)
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

-- Majuscules avec les accents français (string.upper ne touche pas aux lettres accentuées).
local ACCENTS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â", ["î"] = "Î", ["ô"] = "Ô", ["û"] = "Û", ["ç"] = "Ç" }
function UniverseService.upper(text: string): string
	local out = string.upper(text)
	for lower, upperCase in ACCENTS do
		out = string.gsub(out, lower, upperCase)
	end
	return out
end

-- Panneaux des arches d'entrée du hub (tag "UniversePanel" : libellés Title / Timer / Next).
function UniverseService:_updateHubPanels()
	local universe = self:GetCurrent()
	local nextUniverse = Universes.get(gameState:GetAttribute("NextUniverseId") or "") or universe
	local timeText = "⏳ " .. Formulas.formatTime(math.max(0, self:GetEndsAt() - os.time()))
	for _, panel in CollectionService:GetTagged("UniversePanel") do
		for _, gui in panel:GetChildren() do
			if gui:IsA("SurfaceGui") then
				local title = gui:FindFirstChild("Title") :: TextLabel?
				local timer = gui:FindFirstChild("Timer") :: TextLabel?
				local nextLabel = gui:FindFirstChild("Next") :: TextLabel?
				if title then
					title.Text = "🌀 " .. UniverseService.upper(universe.name)
					title.TextColor3 = universe.color:Lerp(Color3.new(1, 1, 1), 0.35)
				end
				if timer then
					timer.Text = timeText
				end
				if nextLabel then
					nextLabel.Text = "Ensuite : " .. nextUniverse.name
				end
			end
		end
	end
end

function UniverseService:_updateInfoBoard()
	self:_updateHubBillboard()
	self:_updateHubPanels()
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
