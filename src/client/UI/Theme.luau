-- Thème visuel de l'interface + petite fonction de création d'instances.

local TweenService = game:GetService("TweenService")

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	Panel = rgb(28, 24, 48),
	PanelLight = rgb(44, 38, 72),
	PanelDark = rgb(18, 15, 32),
	Stroke = rgb(12, 10, 22),
	Text = rgb(255, 255, 255),
	TextDim = rgb(190, 185, 215),
	Gold = rgb(255, 205, 60),
	Green = rgb(80, 220, 110),
	Red = rgb(240, 70, 80),
	Blue = rgb(70, 150, 255),
	Purple = rgb(160, 90, 255),
	Orange = rgb(255, 150, 40),
	Pink = rgb(255, 100, 180),
}

Theme.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
	Small = Enum.Font.GothamBold,
}

-- Création déclarative : Theme.new("Frame", { Size = ..., Children = { ... } })
function Theme.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance: any = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif key ~= "Children" then
				instance[key] = value
			end
		end
		if props.Children then
			for _, child in props.Children do
				child.Parent = instance
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Theme.corner(radius: number?): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(color: Color3?, thickness: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Theme.gradient(colors: { Color3 }, rotation: number?): UIGradient
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return Theme.new("UIGradient", { Color = ColorSequence.new(keypoints), Rotation = rotation or 90 })
end

function Theme.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Theme.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Theme.list(direction: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return Theme.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
	})
end

function Theme.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Fonts.Body,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		if key ~= "Stroke" and key ~= "StrokeThickness" then
			base[key] = value
		end
	end
	local label = Theme.new("TextLabel", base)
	if props.Stroke ~= false then
		Theme.textStroke(nil, props.StrokeThickness or 2).Parent = label
	end
	return label
end

function Theme.tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- Mise à l'échelle des éléments du HUD (petits écrans / mobile).
local scaled: { UIScale } = {}
local currentScale = 1

function Theme.registerScaled(frame: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Scale = currentScale
	scale.Parent = frame
	table.insert(scaled, scale)
end

function Theme.setScale(value: number)
	currentScale = value
	for _, scale in scaled do
		scale.Scale = value
	end
end

-- Couleur dégradée animée (pour les raretés Crossover / Arc-en-ciel).
function Theme.rainbow(t: number): Color3
	return Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
end

return Theme
