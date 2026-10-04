--!nocheck
-- Outils communs aux tests Lune : chargement du .rbxl, compléments d'API Roblox,
-- faux services, signaux simulés et require() façon Roblox.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local Harness = {}

-- Fichier testé : celui livré (carte pré-construite) ou un autre via ANIME_PLACE.
local placePath = require("@lune/process").env.ANIME_PLACE or "build/AnimeTycoon.rbxl"
local game = roblox.deserializePlace(fs.readFile(placePath))
Harness.game = game
Harness.roblox = roblox

------------------------------------------------------------------------
-- Signaux simulés (on peut les déclencher depuis les tests)
------------------------------------------------------------------------

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		local connection = {}
		function connection.Disconnect()
			local index = table.find(signal.handlers, fn)
			if index then
				table.remove(signal.handlers, index)
			end
		end
		return connection
	end
	function signal:Once(fn)
		local connection
		connection = self:Connect(function(...)
			connection.Disconnect()
			fn(...)
		end)
		return connection
	end
	function signal:Wait()
		return nil
	end
	function signal:Fire(...)
		for _, handler in table.clone(self.handlers) do
			task.spawn(handler, ...)
		end
	end
	return signal
end
Harness.newSignal = newSignal

local signals = {}
local function signalFor(instance, name)
	signals[instance] = signals[instance] or {}
	local signal = signals[instance][name]
	if not signal then
		signal = newSignal()
		signals[instance][name] = signal
	end
	return signal
end
Harness.signalFor = signalFor

local EVENT_PROPERTIES = {
	{ "ProximityPrompt", "Triggered" },
	{ "BasePart", "Touched" },
	{ "Instance", "DescendantAdded" },
	{ "Instance", "ChildAdded" },
	{ "GuiButton", "Activated" },
	{ "GuiButton", "MouseButton1Down" },
	{ "GuiButton", "MouseButton1Up" },
	{ "GuiButton", "MouseButton1Click" },
	{ "GuiObject", "MouseEnter" },
	{ "GuiObject", "MouseLeave" },
	{ "RemoteEvent", "OnClientEvent" },
	{ "RemoteEvent", "OnServerEvent" },
	{ "Sound", "Ended" },
	{ "TextBox", "FocusLost" },
	{ "Tool", "Activated" },
	{ "Tool", "Equipped" },
	{ "Tool", "Unequipped" },
}
for _, pair in EVENT_PROPERTIES do
	local name = pair[2]
	roblox.implementProperty(pair[1], name, function(instance)
		return signalFor(instance, name)
	end)
end
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(instance, property)
	return signalFor(instance, "Changed:" .. property)
end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(instance, attribute)
	return signalFor(instance, "Attr:" .. attribute)
end)

------------------------------------------------------------------------
-- Méthodes manquantes
------------------------------------------------------------------------

local function pivotOf(model)
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end
	return CFrame.new()
end
roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(model, target)
	local delta = target * pivotOf(model):Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
roblox.implementMethod("BasePart", "SetNetworkOwner", function() end)

roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild infini : " .. self:GetFullName() .. "." .. tostring(name))
	return child
end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Humanoid", "EquipTool", function(humanoid, tool)
	tool.Parent = humanoid.Parent
end)
roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
roblox.implementMethod("Camera", "ViewportPointToRay", function()
	return { Origin = Vector3.zero, Direction = Vector3.new(0, 0, -1) }
end)

-- Réponses simulées des RemoteFunctions (côté client).
-- (remplaçables par les tests via Harness.onInvokeServer / Harness.onFireServer)
Harness.invokeResponses = {}
Harness.firedToServer = {}
function Harness.onInvokeServer(remote, ...)
	local responder = Harness.invokeResponses[remote.Name]
	if responder then
		return responder(...)
	end
	return true, nil
end
function Harness.onFireServer(remote, ...)
	table.insert(Harness.firedToServer, { remote.Name, ... })
end
roblox.implementMethod("RemoteFunction", "InvokeServer", function(remote, ...)
	return Harness.onInvokeServer(remote, ...)
end)
roblox.implementMethod("RemoteEvent", "FireServer", function(remote, ...)
	return Harness.onFireServer(remote, ...)
end)

------------------------------------------------------------------------
-- Random (absent de Lune)
------------------------------------------------------------------------

local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ state = math.floor((seed or os.clock() * 1e6) % 2147483646) + 1 }, Random)
end
function Random:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min, max)
	local r = self:_next()
	if min then
		return min + (max - min) * r
	end
	return r
end
function Random:NextInteger(min, max)
	return math.floor(min + (max - min + 1) * self:_next())
end
Harness.Random = Random

------------------------------------------------------------------------
-- Faux services
------------------------------------------------------------------------

local tags = {}
local tagAdded, tagRemoved = {}, {}
local function alive(instance)
	local ok = pcall(function()
		return instance.Name
	end)
	return ok
end
-- Les tags sont aussi écrits sur les instances (ils sont alors enregistrés dans le fichier .rbxl).
Harness.CollectionService = {
	AddTag = function(_, instance, tag)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], instance)
		pcall(function()
			instance:AddTag(tag)
		end)
		if tagAdded[tag] then
			tagAdded[tag]:Fire(instance)
		end
	end,
	HasTag = function(_, instance, tag)
		local ok, has = pcall(function()
			return instance:HasTag(tag)
		end)
		return (ok and has) or (tags[tag] ~= nil and table.find(tags[tag], instance) ~= nil)
	end,
	GetTagged = function(_, tag)
		local result, seen = {}, {}
		for _, instance in tags[tag] or {} do
			if not seen[instance] and alive(instance) then
				seen[instance] = true
				table.insert(result, instance)
			end
		end
		-- Instances déjà taguées dans le fichier (carte pré-construite).
		for _, instance in game:GetDescendants() do
			if not seen[instance] and instance:HasTag(tag) then
				seen[instance] = true
				table.insert(result, instance)
			end
		end
		return result
	end,
	GetInstanceAddedSignal = function(_, tag)
		tagAdded[tag] = tagAdded[tag] or newSignal()
		return tagAdded[tag]
	end,
	GetInstanceRemovedSignal = function(_, tag)
		tagRemoved[tag] = tagRemoved[tag] or newSignal()
		return tagRemoved[tag]
	end,
}

local fakeTween = {
	Play = function() end,
	Cancel = function() end,
	Completed = newSignal(),
}
Harness.isServer = true
Harness.services = {
	CollectionService = Harness.CollectionService,
	RunService = {
		IsServer = function()
			return Harness.isServer
		end,
		IsClient = function()
			return not Harness.isServer
		end,
		IsStudio = function()
			return true
		end,
		RenderStepped = newSignal(),
		Heartbeat = newSignal(),
		Stepped = newSignal(),
		BindToRenderStep = function() end,
		UnbindFromRenderStep = function() end,
	},
	TweenService = {
		Create = function()
			return fakeTween
		end,
	},
	UserInputService = {
		InputBegan = newSignal(),
		InputEnded = newSignal(),
		TouchEnabled = false,
	},
}

Harness.gameOverrides = {}
local gameProxy = setmetatable({}, {
	__index = function(_, key)
		if Harness.gameOverrides[key] ~= nil then
			return Harness.gameOverrides[key]
		end
		if key == "GetService" then
			return function(_, name)
				if Harness.services[name] then
					return Harness.services[name]
				end
				return game:GetService(name)
			end
		end
		local value = game[key]
		if type(value) == "function" then
			return function(_, ...)
				return value(game, ...)
			end
		end
		return value
	end,
})
Harness.gameProxy = gameProxy

------------------------------------------------------------------------
-- require() façon Roblox
------------------------------------------------------------------------

local cache = {}
local function requireModule(moduleScript)
	if cache[moduleScript] ~= nil then
		return cache[moduleScript]
	end
	assert(moduleScript:IsA("ModuleScript"), "require d'un non-ModuleScript : " .. moduleScript:GetFullName())
	local result = Harness.run(moduleScript)
	cache[moduleScript] = result
	return result
end
Harness.require = requireModule

-- CFrame.lookAt de Lune inverse l'axe Z (bug de Lune, pas de Roblox) : on le remplace.
local function lookAt(at, target, up)
	local upVector = up or Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(upVector).Unit
	local realUp = right:Cross(look).Unit
	return CFrame.fromMatrix(at, right, realUp, -look)
end
local CFrameProxy = setmetatable({ lookAt = lookAt }, { __index = CFrame })
Harness.CFrame = CFrameProxy

-- Décalage de temps (pour simuler l'attente sans attendre vraiment).
Harness.timeOffset = 0
local fakeOs = setmetatable({
	time = function(t)
		if t then
			return os.time(t)
		end
		return os.time() + Harness.timeOffset
	end,
}, { __index = os })
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.time() + Harness.timeOffset
end)

function Harness.env(scriptInstance)
	return {
		os = fakeOs,
		script = scriptInstance,
		game = gameProxy,
		workspace = game:GetService("Workspace"),
		require = requireModule,
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrameProxy,
		Color3 = roblox.Color3,
		Font = roblox.Font,
		Rect = roblox.Rect,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		TweenInfo = {
			new = function()
				return {}
			end,
		},
		Random = Random,
		task = task,
		warn = function(...)
			print("WARN:", ...)
		end,
	}
end

-- Exécute un script (Module, Script ou LocalScript) et renvoie son résultat.
-- Lune ne dérive pas BasePart.Position du CFrame : on réécrit les lectures sur les
-- variables qui contiennent des pièces (root, froot, PrimaryPart, stashPad...).
local function patchSource(source: string): string
	source = string.gsub(source, "(%f[%w_][%w_]*[Rr]oot)%.Position%f[^%w_]", "%1.CFrame.Position")
	source = string.gsub(source, "(%f[%w_]froot)%.Position%f[^%w_]", "%1.CFrame.Position")
	source = string.gsub(source, "(PrimaryPart)%.Position%f[^%w_]", "%1.CFrame.Position")
	source = string.gsub(source, "(stashPad)%.Position%f[^%w_]", "%1.CFrame.Position")
	source = string.gsub(source, "(%f[%w_]part)%.Position%f[^%w_]", "%1.CFrame.Position")
	-- Propriétés calculées par le moteur (absentes dans Lune).
	source = string.gsub(source, "camera%.ViewportSize", "Vector2.new(1280, 760)")
	return source
end

function Harness.run(scriptInstance)
	local fn = luau.load(patchSource(scriptInstance.Source), { debugName = scriptInstance:GetFullName(), environment = Harness.env(scriptInstance) })
	return fn()
end

function Harness.find(path)
	local current = game
	for _, name in string.split(path, ".") do
		current = current:FindFirstChild(name) or (current == game and game:GetService(name))
		assert(current, "introuvable : " .. path)
	end
	return current
end

function Harness.countParts(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local failures = 0
function Harness.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("✅ " .. name)
	else
		failures += 1
		print("❌ " .. name .. "\n   " .. tostring(err))
	end
end

function Harness.finish()
	print(string.rep("-", 40))
	if failures > 0 then
		print(failures .. " test(s) en échec")
		require("@lune/process").exit(1)
	end
	print("Tous les tests sont passés !")
	-- Les boucles du jeu tournent en arrière-plan : on quitte explicitement.
	require("@lune/process").exit(0)
end

return Harness
