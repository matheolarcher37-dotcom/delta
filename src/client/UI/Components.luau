-- Composants d'interface réutilisables : boutons, fenêtres, aperçus 3D, cartes de persos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local CharacterFactory = require(Shared.Modules.CharacterFactory)
local RelicBuilder = require(Shared.Modules.RelicBuilder)

local Theme = require(script.Parent.Theme)

local Components = {}

local C = Theme.Colors
local new = Theme.new

------------------------------------------------------------------------
-- Sons d'interface
------------------------------------------------------------------------

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxasset://sounds/button.wav"
clickSound.Volume = 0.4
clickSound.Parent = SoundService

function Components.click()
	SoundService:PlayLocalSound(clickSound)
end

------------------------------------------------------------------------
-- Bouton
------------------------------------------------------------------------

export type ButtonProps = {
	Text: string,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	LayoutOrder: number?,
	Font: Enum.Font?,
	OnClick: (() -> ())?,
}

function Components.button(props: ButtonProps): TextButton
	local color = props.Color or C.Green
	local button = new("TextButton", {
		Name = "Button",
		Size = props.Size or UDim2.fromOffset(160, 50),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Theme.corner(12).Parent = button
	Theme.stroke(C.Stroke, 3).Parent = button
	Theme.gradient({ color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2) }, 90).Parent = button
	local scale = new("UIScale", { Parent = button })
	local label = Theme.label({
		Name = "Label",
		Text = props.Text,
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		Font = props.Font or Theme.Fonts.Body,
		Parent = button,
	})
	local _ = label
	button.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.06, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.1, { Scale = 1.04 })
	end)
	button.Activated:Connect(function()
		Components.click()
		if props.OnClick then
			props.OnClick()
		end
	end)
	return button
end

function Components.setButtonText(button: TextButton, text: string)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

function Components.setButtonColor(button: TextButton, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2))
	end
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------

function Components.window(parent: Instance, title: string, accent: Color3?, size: UDim2?)
	local color = accent or C.Purple
	local holder = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size or UDim2.fromScale(0.72, 0.74),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(1000, 680), MinSize = Vector2.new(300, 260), Parent = holder })
	Theme.corner(18).Parent = holder
	Theme.stroke(C.Stroke, 4).Parent = holder
	Theme.gradient({ C.PanelLight, C.Panel }, 90).Parent = holder
	local scale = new("UIScale", { Parent = holder })

	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = color,
		ZIndex = 6,
		Parent = holder,
	})
	Theme.corner(18).Parent = header
	Theme.gradient({ color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.25) }, 90).Parent = header
	-- Cache les coins arrondis du bas du bandeau.
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.25),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = header,
	})
	local titleLabel = Theme.label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(20, 8),
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		StrokeThickness = 3,
		Parent = header,
	})
	local closeButton = Components.button({
		Text = "✕",
		Color = C.Red,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -52, 0, 6),
		Parent = header,
	})
	closeButton.ZIndex = 8

	local content = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -24, 1, -72),
		Position = UDim2.fromOffset(12, 64),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = holder,
	})

	local window = { frame = holder, content = content, title = titleLabel, onClose = nil, isOpen = false }

	function window.open()
		if window.isOpen then
			return
		end
		window.isOpen = true
		holder.Visible = true
		scale.Scale = 0.6
		Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	function window.close()
		if not window.isOpen then
			return
		end
		window.isOpen = false
		local tween = Theme.tween(scale, 0.15, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			if not window.isOpen then
				holder.Visible = false
			end
		end)
		if window.onClose then
			window.onClose()
		end
	end

	closeButton.Activated:Connect(function()
		window.close()
	end)
	return window
end

------------------------------------------------------------------------
-- Aperçus 3D (ViewportFrame)
------------------------------------------------------------------------

local spinning = {} -- [ViewportFrame] = { model, base }
local previewCache = {} -- signature -> modèle

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for viewport, info in spinning do
		if not viewport.Parent then
			spinning[viewport] = nil
		elseif viewport.Visible and info.model.Parent then
			info.model:PivotTo(info.base * CFrame.Angles(0, math.sin(t * 0.9 + info.phase) * 0.6, 0))
		end
	end
end)

local function lookSignature(look): string
	local parts = {}
	for key, value in look do
		local v = value
		if typeof(v) == "Color3" then
			v = v:ToHex()
		elseif type(v) == "table" then
			v = table.concat(v, ",")
		end
		table.insert(parts, key .. "=" .. tostring(v))
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function Components.characterModel(look, id: string?, stars: number?): Model
	local template = CharacterFactory.templateFor(id, stars)
	local signature = lookSignature(look) .. (template and ("|" .. template:GetFullName()) or "")
	local cached = previewCache[signature]
	if not cached then
		cached = CharacterFactory.buildPreview(id, stars, look)
		previewCache[signature] = cached
	end
	return cached:Clone()
end

function Components.viewport(parent: Instance, model: Model, focus: Vector3, distance: number, props: { [string]: any }?, spin: boolean?): ViewportFrame
	local viewport = new("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(viewport :: any)[key] = value
		end
	end
	local camera = new("Camera", {
		FieldOfView = 35,
		Parent = viewport,
	})
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.28, distance * 0.12, -distance), focus)
	viewport.CurrentCamera = camera
	model.Parent = viewport
	if spin then
		spinning[viewport] = { model = model, base = model:GetPivot(), phase = math.random() * 6 }
	end
	return viewport
end

-- `entry` (facultatif) permet d'utiliser le modèle personnalisé du perso s'il existe.
function Components.characterViewport(parent: Instance, look, spin: boolean?, entry: any?): ViewportFrame
	local model = Components.characterModel(look, entry and entry.id, entry and entry.stars)
	return Components.viewport(parent, model, Vector3.new(0, 3.6, 0), 12.5, nil, spin)
end

function Components.relicViewport(parent: Instance, relic, spin: boolean?): ViewportFrame
	local model = RelicBuilder.build(relic.look, relic.tier, 1)
	return Components.viewport(parent, model, Vector3.new(0, 1.3, 0), 7, nil, spin)
end

------------------------------------------------------------------------
-- Carte de personnage
------------------------------------------------------------------------

export type CardOptions = {
	size: UDim2?,
	inTeam: boolean?,
	selected: boolean?,
	onClick: (() -> ())?,
	layoutOrder: number?,
	spin: boolean?,
}

function Components.characterCard(parent: Instance, entry, options: CardOptions?)
	local opts = options or {}
	local desc = Formulas.describe(entry)
	local rarity = Rarities.get(desc and desc.rarity or "common")
	local card = new("TextButton", {
		Name = "Card",
		Size = opts.size or UDim2.fromOffset(130, 165),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = opts.layoutOrder or 0,
		Parent = parent,
	})
	Theme.corner(14).Parent = card
	local stroke = Theme.stroke(opts.selected and C.Gold or rarity.color:Lerp(Color3.new(0, 0, 0), 0.3), opts.selected and 5 or 3)
	stroke.Parent = card
	Theme.gradient({ rarity.gradient[1]:Lerp(C.Panel, 0.35), rarity.gradient[#rarity.gradient]:Lerp(C.PanelDark, 0.55) }, 90).Parent = card
	local scale = new("UIScale", { Parent = card })

	if desc then
		local holder = new("Frame", {
			Size = UDim2.new(1, -8, 0.72, 0),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Parent = card,
		})
		Components.characterViewport(holder, desc.look, opts.spin, entry)
	end

	Theme.label({
		Name = "Level",
		Text = "Lv." .. entry.level,
		Size = UDim2.new(0.55, 0, 0.14, 0),
		Position = UDim2.fromScale(0.04, 0.02),
		Font = Theme.Fonts.Title,
		TextColor3 = Color3.fromRGB(255, 230, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	Theme.label({
		Name = "Stars",
		Text = string.rep("★", entry.stars or 1),
		Size = UDim2.new(0.45, 0, 0.13, 0),
		Position = UDim2.fromScale(0.53, 0.03),
		TextColor3 = Color3.fromRGB(255, 220, 90),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
	Theme.label({
		Name = "CharName",
		Text = desc and desc.name or "?",
		Size = UDim2.new(0.94, 0, 0.13, 0),
		Position = UDim2.fromScale(0.03, 0.74),
		Parent = card,
	})
	Theme.label({
		Name = "Rarity",
		Text = rarity.name,
		Size = UDim2.new(0.94, 0, 0.1, 0),
		Position = UDim2.fromScale(0.03, 0.87),
		TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.25),
		Font = Theme.Fonts.Small,
		Parent = card,
	})
	local aura = Auras.get(entry.aura)
	if aura then
		local chip = new("Frame", {
			Size = UDim2.new(0.62, 0, 0.11, 0),
			Position = UDim2.fromScale(0.04, 0.6),
			BackgroundColor3 = aura.color,
			Parent = card,
		})
		Theme.corner(8).Parent = chip
		Theme.stroke(C.Stroke, 2).Parent = chip
		Theme.label({ Text = aura.name, Size = UDim2.fromScale(0.94, 0.9), Position = UDim2.fromScale(0.03, 0.05), Font = Theme.Fonts.Small, Parent = chip })
	end
	if entry.trait and Traits.get(entry.trait) then
		Components.traitChip(card, entry.trait, UDim2.new(0.62, 0, 0.11, 0), UDim2.fromScale(0.04, aura and 0.48 or 0.6))
	end
	if opts.inTeam then
		local badge = new("Frame", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, -32, 0.6, -6),
			BackgroundColor3 = C.Blue,
			Parent = card,
		})
		Theme.corner(14).Parent = badge
		Theme.stroke(C.Stroke, 2).Parent = badge
		Theme.label({ Text = "⚔️", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Parent = badge, Stroke = false })
	end
	if entry.locked then
		Theme.label({ Text = "🔒", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -26, 0.17, 0), Parent = card, Stroke = false })
	end
	if desc and desc.isFusion then
		local glow = Theme.stroke(Rarities.get("crossover").color, 3, 0.2)
		glow.Parent = card
		local gradient = Theme.gradient(Rarities.get("crossover").gradient, 45)
		gradient.Parent = glow
		task.spawn(function()
			while gradient.Parent do
				gradient.Rotation = (gradient.Rotation + 4) % 360
				task.wait(0.03)
			end
		end)
	end

	card.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.05 })
	end)
	card.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	card.Activated:Connect(function()
		Components.click()
		if opts.onClick then
			opts.onClick()
		end
	end)
	return card
end

------------------------------------------------------------------------
-- Divers
------------------------------------------------------------------------

function Components.progressBar(parent: Instance, color: Color3, props: { [string]: any }?)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = C.PanelDark,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	Theme.corner(7).Parent = frame
	Theme.stroke(C.Stroke, 2).Parent = frame
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	})
	Theme.corner(7).Parent = fill
	local gradient = Theme.gradient({ color:Lerp(Color3.new(1, 1, 1), 0.3), color }, 90)
	gradient.Parent = fill
	local bar = { frame = frame, fill = fill }
	function bar.set(fraction: number)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
	function bar.setColor(newColor: Color3)
		gradient.Color = ColorSequence.new(newColor:Lerp(Color3.new(1, 1, 1), 0.3), newColor)
	end
	return bar
end

function Components.materialPill(parent: Instance, materialId: string, count: number, layoutOrder: number?)
	local material = Universes.getMaterial(materialId)
	local pill = new("Frame", {
		Name = "Pill_" .. materialId,
		Size = UDim2.fromOffset(118, 34),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.15,
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})
	Theme.corner(17).Parent = pill
	Theme.stroke(C.Stroke, 2).Parent = pill
	local gem = new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(8, 7),
		Rotation = 45,
		BackgroundColor3 = material and material.color or Color3.new(1, 1, 1),
		Parent = pill,
	})
	Theme.corner(4).Parent = gem
	Theme.stroke(C.Stroke, 2).Parent = gem
	Theme.label({
		Name = "Count",
		Text = Formulas.formatNumber(count),
		Size = UDim2.new(1, -40, 1, -8),
		Position = UDim2.fromOffset(34, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})
	return pill
end

-- Petite pastille colorée avec le nom du trait (dégradé + contour).
function Components.traitChip(parent: Instance, traitId: string, size: UDim2, position: UDim2)
	local trait = Traits.get(traitId)
	if not trait then
		return nil
	end
	local chip = new("Frame", {
		Name = "TraitChip",
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Theme.corner(8).Parent = chip
	Theme.stroke(Traits.TierColors[trait.tier] or C.Stroke, 2).Parent = chip
	Theme.gradient({ trait.color:Lerp(Color3.new(1, 1, 1), 0.2), trait.color:Lerp(Color3.new(0, 0, 0), 0.35) }, 90).Parent = chip
	Theme.label({ Text = "◆ " .. trait.name, Size = UDim2.fromScale(0.94, 0.9), Position = UDim2.fromScale(0.03, 0.05), Font = Theme.Fonts.Small, Parent = chip })
	return chip
end

function Components.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

return Components
