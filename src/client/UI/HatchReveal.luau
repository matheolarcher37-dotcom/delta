-- Animation de révélation d'un perso obtenu (roulage automatique de la machine ROULER, fusion
-- crossover) : rayons, flash, le perso apparaît avec son nom, sa rareté et son trait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Menus = require(script.Parent.Menus)

local HatchReveal = {}

local C = Theme.Colors
local new = Theme.new

local overlay: Frame
local revealQueue = {}
local revealing = false

local revealSound = Instance.new("Sound")
revealSound.SoundId = "rbxasset://sounds/glassbreak.wav"
revealSound.Volume = 0.5
revealSound.Parent = SoundService

------------------------------------------------------------------------
-- Révélation
------------------------------------------------------------------------

local function playReveal(info)
	revealing = true
	local entry = info.entry
	local desc = Formulas.describe(entry)
	if not desc then
		revealing = false
		return
	end
	local rarity = Rarities.get(desc.rarity)
	Components.clear(overlay)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	Theme.tween(overlay, 0.3, { BackgroundTransparency = 0.25 })

	local stage = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 420),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = overlay,
	})
	-- Rayons de lumière tournants.
	local rays = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.6, 1.6),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = stage,
	})
	for i = 0, 11 do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 26, 1, 0),
			Rotation = i * 15,
			BackgroundColor3 = rarity.color,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			ZIndex = 31,
			Parent = rays,
		})
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rarity.color),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, rarity.color),
			}),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Rotation = 90,
			Parent = ray,
		})
	end
	rays.Visible = false
	local spinConn = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 25
	end)

	-- 1) Petite attente, puis flash !
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = stage,
	})
	task.wait(0.4)
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 40, Parent = overlay })
	Theme.tween(flash, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.6, function()
		flash:Destroy()
	end)
	SoundService:PlayLocalSound(revealSound)
	Components.clear(holder)
	rays.Visible = true

	-- 2) Le perso apparaît.
	local viewport = Components.characterViewport(holder, desc.look, true, entry)
	viewport.ZIndex = 32
	local popScale = new("UIScale", { Scale = 0.2, Parent = holder })
	Theme.tween(popScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local text = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 215),
		Size = UDim2.fromOffset(600, 170),
		BackgroundTransparency = 1,
		ZIndex = 33,
		Parent = overlay,
	})
	local headline = info.fusion and "🌀 CROSSOVER ! 🌀" or (info.isNew and "✨ NOUVEAU ! ✨" or "TU AS OBTENU")
	Theme.label({ Text = headline, Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.Gold, ZIndex = 33, Parent = text })
	local name = Theme.label({
		Text = desc.name,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 32),
		Font = Theme.Fonts.Title,
		ZIndex = 33,
		StrokeThickness = 4,
		Parent = text,
	})
	Theme.gradient({ rarity.gradient[1], rarity.gradient[#rarity.gradient] }, 90).Parent = name
	local universe = Universes.get(desc.universe)
	local sub = rarity.name .. "  ·  " .. (universe and universe.name or "")
	local aura = Auras.get(entry.aura)
	if aura then
		sub ..= "  ·  Aura " .. aura.name .. " (×" .. aura.multiplier .. ")"
	end
	local trait = Traits.get(entry.trait)
	if trait then
		sub ..= "  ·  ◆ " .. trait.name
	end
	Theme.label({
		Text = sub,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 90),
		TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.3),
		ZIndex = 33,
		Parent = text,
	})
	local closeButton = Components.button({
		Hint = "A",
		Text = "Génial !",
		Color = rarity.color,
		Size = UDim2.fromOffset(180, 46),
		Position = UDim2.new(0.5, -90, 0, 122),
		Parent = text,
	})
	closeButton.ZIndex = 34
	Console.select(closeButton)

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		spinConn:Disconnect()
		local tween = Theme.tween(overlay, 0.25, { BackgroundTransparency = 1 })
		Components.clear(overlay)
		tween.Completed:Wait()
		overlay.Visible = false
		revealing = false
		if #revealQueue > 0 then
			playReveal(table.remove(revealQueue, 1))
		end
	end
	closeButton.Activated:Connect(finish)
	task.delay(7, finish)
end

function HatchReveal.init(gui: ScreenGui)
	-- Calque de révélation (coordonnées logiques 1280 x 720, comme le reste de l'interface).
	overlay = Theme.scaledRoot(gui, "RevealOverlay", 30)
	overlay.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	overlay.Visible = false

	Remotes.event("HatchReveal").OnClientEvent:Connect(function(info)
		Menus.close()
		if revealing then
			table.insert(revealQueue, info)
		else
			task.spawn(playReveal, info)
		end
	end)
end

return HatchReveal
