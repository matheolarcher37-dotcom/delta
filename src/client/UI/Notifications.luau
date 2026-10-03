-- Notifications (petits messages à droite) et annonces géantes au centre de l'écran.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)

local Notifications = {}

local C = Theme.Colors
local new = Theme.new

local KIND_COLORS = {
	success = C.Green,
	error = C.Red,
	warning = C.Orange,
	info = C.Blue,
}

local toastContainer: Frame
local announceFrame: Frame
local announceQueue = {}
local announcing = false

local pingSound = Instance.new("Sound")
pingSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
pingSound.Volume = 0.35
pingSound.Parent = SoundService

function Notifications.init(gui: ScreenGui)
	toastContainer = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(340, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
	layout.Parent = toastContainer
	Theme.registerScaled(toastContainer)

	announceFrame = new("Frame", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.8, 0.16),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	new("UIScale", { Parent = announceFrame })
	local title = Theme.label({
		Name = "Title",
		Size = UDim2.fromScale(1, 0.62),
		Font = Theme.Fonts.Title,
		ZIndex = 21,
		StrokeThickness = 4,
		Parent = announceFrame,
	})
	Theme.gradient({ Color3.new(1, 1, 1), Color3.new(1, 1, 1) }, 90).Parent = title
	Theme.label({
		Name = "Subtitle",
		Size = UDim2.fromScale(1, 0.34),
		Position = UDim2.fromScale(0, 0.64),
		ZIndex = 21,
		StrokeThickness = 3,
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
	local color = KIND_COLORS[kind or "info"] or C.Blue
	local toast = new("Frame", {
		Size = UDim2.fromOffset(330, 58),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		Parent = toastContainer,
	})
	Theme.corner(12).Parent = toast
	Theme.stroke(C.Stroke, 3).Parent = toast
	local bar = new("Frame", { Size = UDim2.new(0, 8, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = color, Parent = toast })
	Theme.corner(4).Parent = bar
	local label = Theme.label({
		Text = text,
		Size = UDim2.new(1, -30, 1, -10),
		Position = UDim2.fromOffset(22, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = toast,
	})
	new("UITextSizeConstraint", { MaxTextSize = 20, Parent = label })
	local scale = new("UIScale", { Scale = 0.5, Parent = toast })
	Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
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
	if #toasts > 5 then
		toasts[1]:Destroy()
	end
	task.delay(4.5, function()
		if toast.Parent then
			local tween = Theme.tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Wait()
			toast:Destroy()
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
	local color = item.color or C.Gold
	title.Text = item.title
	subtitle.Text = item.subtitle or ""
	local gradient = title:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.55), color)
	end
	local scale = announceFrame:FindFirstChildOfClass("UIScale") :: UIScale
	announceFrame.Visible = true
	scale.Scale = 0.3
	Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		local tween = Theme.tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween.Completed:Wait()
		announceFrame.Visible = false
		announcing = false
		showNext()
	end)
end

function Notifications.announce(titleText: string, subtitle: string?, color: Color3?)
	table.insert(announceQueue, { title = titleText, subtitle = subtitle, color = color })
	if #announceQueue > 4 then
		table.remove(announceQueue, 1)
	end
	showNext()
end

return Notifications
