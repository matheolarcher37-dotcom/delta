-- Pièces qui glissent sur le tapis roulant des bases (purement visuel, animé ici côté client).
-- Le serveur publie les chemins (TycoonConveyor.publish) : dossier étiqueté "CoinConveyor",
-- un Configuration par distributeur avec les attributs Kind ("coin" | "gold" | "gem"),
-- Interval (s) et Points ("x,y,z;x,y,z;..." : buse, tapis, coffre). Seules les bases proches
-- de la caméra sont animées, avec un plafond de pièces en vol.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CoinConveyor = {}

local TAG = "CoinConveyor"
local BELT_SPEED = 7 -- studs par seconde (comme côté serveur)
local VIEW_DISTANCE = 220 -- au-delà, on n'anime pas
local MAX_COINS = 40

local rgb = Color3.fromRGB
local folderFx: Folder? = nil
local live = 0
local nextDrop: { [Instance]: number } = {}
local pathCache: { [Instance]: { raw: string, points: { Vector3 } } } = {}

local function decode(config: Instance): { Vector3 }?
	local raw = config:GetAttribute("Points")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local cached = pathCache[config]
	if cached and cached.raw == raw then
		return cached.points
	end
	local points = {}
	for chunk in string.gmatch(raw, "[^;]+") do
		local x, y, z = string.match(chunk, "^(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+)$")
		if x then
			table.insert(points, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number))
		end
	end
	if #points < 2 then
		return nil
	end
	pathCache[config] = { raw = raw, points = points }
	return points
end

local function makeCoin(kind: string, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "gem" then
		part.Name = "Gemme"
		part.Size = Vector3.new(0.9, 1.3, 0.9)
		part.Color = rgb(120, 230, 255)
		part.Material = Enum.Material.Neon
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	else
		local d = kind == "gold" and 1.9 or 1.4
		part.Name = "Coin"
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.3, d, d)
		part.Color = kind == "gold" and rgb(255, 225, 90) or rgb(255, 200, 40)
		part.Material = kind == "gold" and Enum.Material.Neon or Enum.Material.Metal
		part.Reflectance = kind == "gold" and 0 or 0.2
	end
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, kind == "gem" and 0 or math.rad(90))
	part.Parent = folderFx
	return part
end

-- Une pièce voyage le long du chemin puis disparaît dans le coffre.
local function launch(kind: string, points: { Vector3 })
	live += 1
	local coin = makeCoin(kind, points[1])
	local elapsed = 0
	for i = 2, #points do
		local from, to = points[i - 1], points[i]
		local duration
		local style = Enum.EasingStyle.Linear
		if i == 2 then
			duration = 0.35 -- chute depuis la buse
			style = Enum.EasingStyle.Quad
		elseif i == #points then
			duration = 0.3 -- saut dans le coffre
			style = Enum.EasingStyle.Quad
		else
			duration = (to - from).Magnitude / BELT_SPEED
		end
		local target = CFrame.new(to) * CFrame.Angles(0, elapsed * 2, kind == "gem" and 0 or math.rad(90))
		task.delay(elapsed, function()
			if coin.Parent then
				TweenService:Create(coin, TweenInfo.new(duration, style, Enum.EasingDirection.In), { CFrame = target }):Play()
			end
		end)
		elapsed += duration
	end
	task.delay(elapsed + 0.05, function()
		live -= 1
		if coin.Parent then
			coin:Destroy()
		end
	end)
end

local function step(now: number)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for _, folder in CollectionService:GetTagged(TAG) do
		if folder:GetAttribute("Active") and folder:IsDescendantOf(Workspace) then
			for _, config in folder:GetChildren() do
				if config:IsA("Configuration") then
					local points = decode(config)
					local due = nextDrop[config]
					if points and (not due or now >= due) then
						local interval = math.max(0.5, tonumber(config:GetAttribute("Interval")) or 2)
						nextDrop[config] = now + interval
						-- Première fois : décalage au hasard pour que les distributeurs ne tombent pas ensemble.
						if due and live < MAX_COINS and (not eye or (points[1] - eye).Magnitude < VIEW_DISTANCE) then
							launch(tostring(config:GetAttribute("Kind") or "coin"), points)
						elseif not due then
							nextDrop[config] = now + math.random() * interval
						end
					end
				end
			end
		end
	end
	-- Oubli des chemins disparus (base libérée, sortie du streaming).
	for config in nextDrop do
		if not config.Parent then
			nextDrop[config] = nil
			pathCache[config] = nil
		end
	end
end

function CoinConveyor.init()
	local fx = Instance.new("Folder")
	fx.Name = "PiecesTapis"
	fx.Parent = Workspace
	folderFx = fx
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(step, os.clock())
			if not ok then
				warn("[AnimeTycoon] Tapis de pièces : " .. tostring(err))
				task.wait(2)
			end
		end
	end)
end

-- Nombre de pièces en vol (tests).
function CoinConveyor.liveCount(): number
	return live
end

return CoinConveyor
