-- Notifications animées (bandeaux qui glissent sous la bannière d'univers) et grandes annonces
-- au centre de l'écran (ruban sombre, titre dégradé, étincelles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local Notifications = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

local KINDS = {
	success = { color = C.Green, icon = "star" },
	error = { color = C.Red, icon = "close" },
	warning = { color = C.Orange, icon = "bolt" },
	info = { color = C.Blue, icon = "guide" },
}

local toastContainer: Frame
local announceFrame: Frame
local announceQueue = {}
local announcing = false
local toastCount = 0

local pingSound = Instance.new("Sound")
pingSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
pingSound.Volume = 0.35
pingSound.Parent = SoundService

local fanfare = Instance.new("Sound")
fanfare.SoundId = "rbxasset://sounds/victory.wav"
fanfare.Volume = 0.3
fanfare.Parent = SoundService

function Notifications.init(gui: ScreenGui)
	local root = Theme.scaledRoot(gui, "Notifications", 40)
	toastContainer = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(460, 300),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local layout = Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	layout.Parent = toastContainer

	announceFrame = new("Frame", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromOffset(900, 130),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	new("UIScale", { Parent = announceFrame })
	local ribbon = new("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0.86, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = announceFrame,
	})
	Theme.gradient({ WHITE, WHITE, WHITE }, 0, { 1, 0.35, 1 }).Parent = ribbon
	local glow = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.7, 0, 0.04, 0),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = announceFrame,
	})
	Theme.gradient({ WHITE, WHITE, WHITE }, 0, { 1, 0, 1 }).Parent = glow
	glow.Position = UDim2.fromScale(0.5, 0.93)
	local sparkles = new("Frame", { Name = "Sparkles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = announceFrame })
	Theme.sparkles(sparkles, 12, 99, 0.35, 2)
	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(0.94, 0, 0.58, 0),
		Position = UDim2.fromScale(0.03, 0.06),
		FontFace = Theme.Faces.Title,
		ZIndex = 3,
		StrokeThickness = 4,
		Parent = announceFrame,
	})
	Theme.gradient({ WHITE, WHITE }, 90).Parent = title
	Theme.label({
		Name = "Subtitle",
		Size = UDim2.new(0.9, 0, 0.26, 0),
		Position = UDim2.fromScale(0.05, 0.66),
		FontFace = Theme.Faces.Bold,
		ZIndex = 3,
		StrokeThickness = 2.5,
		Parent = announceFrame,
	})

	Remotes.event("Notify").OnClientEvent:Connect(function(text, kind)
		Notifications.toast(text, kind)
	end)
	Remotes.event("Announce").OnClientEvent:Connect(function(titleText, subtitle, color)
		Notifications.announce(titleText, subtitle, color)
	end)
end

function Notifications.toast(text: string, kind: string?)
	if not toastContainer then
		return
	end
	local info = KINDS[kind or "info"] or KINDS.info
	toastCount += 1
	local holder = new("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(440, 52),
		BackgroundTransparency = 1,
		LayoutOrder = toastCount,
		Parent = toastContainer,
	})
	local toast = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -20),
		BackgroundColor3 = WHITE,
		Parent = holder,
	})
	Theme.round().Parent = toast
	Theme.stroke(C.Stroke, 3).Parent = toast
	Theme.gradient({ Theme.dark(info.color, 0.45), Color3.fromRGB(22, 22, 32), Color3.fromRGB(16, 16, 24) }, 0).Parent = toast
	local edge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = toast })
	Theme.round().Parent = edge
	Theme.stroke(info.color, 1.5, 0.3).Parent = edge
	local badge = new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = WHITE,
		Parent = toast,
	})
	Theme.round().Parent = badge
	Theme.stroke(C.Stroke, 2).Parent = badge
	Theme.gradient({ Theme.light(info.color, 0.3), info.color, Theme.dark(info.color, 0.3) }, 90).Parent = badge
	Icons.make(info.icon, badge, { px = 22, size = UDim2.fromScale(0.58, 0.58), ink = Theme.dark(info.color, 0.4) })
	Theme.label({
		Text = text,
		Size = UDim2.new(1, -66, 1, -12),
		Position = UDim2.fromOffset(52, 6),
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		MaxSize = 20,
		Parent = toast,
	})
	local scale = new("UIScale", { Scale = 0.6, Parent = toast })
	Theme.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.tween(toast, 0.3, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	if kind == "success" or kind == "error" then
		SoundService:PlayLocalSound(pingSound)
	end

	-- Limite le nombre de messages affichés.
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts > 4 do
		table.remove(toasts, 1):Destroy()
	end
	task.delay(4, function()
		if holder.Parent then
			Theme.tween(scale, 0.2, { Scale = 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.22)
			if holder.Parent then
				holder:Destroy()
			end
		end
	end)
end

local function showNext()
	if announcing or #announceQueue == 0 then
		return
	end
	announcing = true
	local item = table.remove(announceQueue, 1)
	local title = announceFrame:FindFirstChild("Title") :: TextLabel
	local subtitle = announceFrame:FindFirstChild("Subtitle") :: TextLabel
	local glow = announceFrame:FindFirstChild("Glow") :: Frame
	local color = item.color or C.Gold
	title.Text = item.title
	subtitle.Text = item.subtitle or ""
	glow.BackgroundColor3 = color
	local gradient = title:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = Theme.sequence({ Theme.light(color, 0.7), Theme.light(color, 0.15), color })
	end
	local scale = announceFrame:FindFirstChildOfClass("UIScale") :: UIScale
	announceFrame.Visible = true
	announceFrame.Rotation = -4
	scale.Scale = 0.3
	Theme.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.tween(announceFrame, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
	if item.fanfare then
		SoundService:PlayLocalSound(fanfare)
	end
	task.delay(3.2, function()
		Theme.tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.27)
		announceFrame.Visible = false
		announcing = false
		showNext()
	end)
end

function Notifications.announce(titleText: string, subtitle: string?, color: Color3?, withFanfare: boolean?)
	table.insert(announceQueue, { title = titleText, subtitle = subtitle, color = color, fanfare = withFanfare })
	if #announceQueue > 4 then
		table.remove(announceQueue, 1)
	end
	if announceFrame then
		showNext()
	end
end

return Notifications
