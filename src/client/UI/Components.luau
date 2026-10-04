-- Composants d'interface réutilisables : boutons brillants, grandes tuiles de menu, fenêtres,
-- onglets, hexagones, aperçus 3D, cartes de persos, barres, pastilles...
-- Tout est compatible souris, tactile ET manette (Selectable + image de sélection).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local CharacterFactory = require(Shared.Modules.CharacterFactory)
local RelicBuilder = require(Shared.Modules.RelicBuilder)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Console = require(script.Parent.Console)

local Components = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

------------------------------------------------------------------------
-- Sons d'interface
------------------------------------------------------------------------

local function sound(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	return s
end

local clickSound = sound("rbxasset://sounds/button.wav", 0.4)
local hoverSound = sound("rbxasset://sounds/clickfast.wav", 0.12)
local errorSound = sound("rbxasset://sounds/electronicpingshort.wav", 0.25)

function Components.click()
	SoundService:PlayLocalSound(clickSound)
end

function Components.hover()
	SoundService:PlayLocalSound(hoverSound)
end

function Components.errorSound()
	SoundService:PlayLocalSound(errorSound)
end

------------------------------------------------------------------------
-- Image de sélection manette (contour blanc épais et lumineux)
------------------------------------------------------------------------

local selectionImage = new("Frame", {
	Name = "SelectionCursor",
	Size = UDim2.new(1, 12, 1, 12),
	Position = UDim2.fromOffset(-6, -6),
	BackgroundTransparency = 1,
})
Theme.corner(16).Parent = selectionImage
do
	local stroke = Theme.stroke(WHITE, 4)
	stroke.Parent = selectionImage
	Theme.gradient({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 255, 255) }, 45).Parent = stroke
end
Components.selectionImage = selectionImage

-- Rend un bouton navigable à la manette, avec effet de survol / sélection.
function Components.interactive(button: GuiButton, scale: UIScale?, hoverScale: number?)
	button.Selectable = true
	button.SelectionImageObject = selectionImage
	local target = hoverScale or 1.06
	if scale then
		local function grow()
			Theme.tween(scale, 0.12, { Scale = target })
		end
		local function shrink()
			Theme.tween(scale, 0.12, { Scale = 1 })
		end
		button.MouseEnter:Connect(grow)
		button.MouseLeave:Connect(shrink)
		pcall(function()
			button.SelectionGained:Connect(function()
				grow()
				Components.hover()
			end)
			button.SelectionLost:Connect(shrink)
		end)
		button.MouseButton1Down:Connect(function()
			Theme.tween(scale, 0.06, { Scale = 0.94 })
		end)
		button.MouseButton1Up:Connect(function()
			Theme.tween(scale, 0.1, { Scale = target })
		end)
	end
end

------------------------------------------------------------------------
-- Bouton brillant (face dégradée + lèvre 3D + reflet + texte contouré)
------------------------------------------------------------------------

export type ButtonProps = {
	Text: string,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	LayoutOrder: number?,
	Font: any?,
	Icon: string?,
	Hint: string?,
	TextSize: number?,
	OnClick: (() -> ())?,
}

local function buttonColors(face: Frame, lip: Frame, color: Color3)
	local gradient = face:FindFirstChild("Gradient") :: UIGradient?
	if gradient then
		gradient.Color = Theme.sequence({ Theme.light(color, 0.32), color, Theme.dark(color, 0.18) })
	end
	lip.BackgroundColor3 = Theme.dark(color, 0.5)
end

function Components.button(props: ButtonProps): TextButton
	local color = props.Color or C.Green
	local button = new("TextButton", {
		Name = "Button",
		Size = props.Size or UDim2.fromOffset(170, 52),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local scale = new("UIScale", { Parent = button })
	local lip = new("Frame", {
		Name = "Lip",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.dark(color, 0.5),
		BorderSizePixel = 0,
		Parent = button,
	})
	Theme.corner(12).Parent = lip
	Theme.stroke(C.Stroke, 2.5).Parent = lip
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = button,
	})
	Theme.corner(12).Parent = face
	local gradient = Theme.gradient({ Theme.light(color, 0.32), color, Theme.dark(color, 0.18) }, 90)
	gradient.Name = "Gradient"
	gradient.Parent = face
	Theme.shine(face, 10, 0.32)
	local content = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -14, 1, -8),
		Position = UDim2.fromOffset(7, 4),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = face,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = content
	if props.Icon then
		local iconHolder = new("Frame", {
			Name = "IconHolder",
			Size = UDim2.new(0, 30, 0.86, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			ZIndex = 3,
			Parent = content,
		})
		new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = iconHolder })
		Icons.make(props.Icon, iconHolder, { px = 28, ink = Theme.dark(color, 0.45), zindex = 3 })
	end
	local label = Theme.label({
		Name = "Label",
		Text = props.Text,
		Size = UDim2.new(1, props.Icon and -38 or 0, 1, 0),
		FontFace = Theme.Faces.Title,
		LayoutOrder = 2,
		ZIndex = 3,
		StrokeThickness = 2,
		MaxSize = props.TextSize or 26,
		Parent = content,
	})
	if props.Text == "" then
		label.Visible = false
	end
	if props.Hint then
		Console.hint(button, props.Hint, { Position = UDim2.new(0, -10, 0, -10), ZIndex = 6 })
	end
	Components.interactive(button, scale, 1.05)
	button.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 3)
	end)
	button.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	button.MouseLeave:Connect(function()
		face.Position = UDim2.new()
	end)
	button.Activated:Connect(function()
		Components.click()
		face.Position = UDim2.new()
		if props.OnClick then
			props.OnClick()
		end
	end)
	return button
end

function Components.setButtonText(button: Instance, text: string)
	local label = button:FindFirstChild("Label", true) :: TextLabel?
	if label then
		label.Text = text
		label.Visible = text ~= ""
	end
end

function Components.setButtonColor(button: Instance, color: Color3)
	local face = button:FindFirstChild("Face") :: Frame?
	local lip = button:FindFirstChild("Lip") :: Frame?
	if face and lip then
		buttonColors(face, lip, color)
	end
end

------------------------------------------------------------------------
-- Grande tuile carrée du menu (comme la grille de référence) : contour épais clair,
-- dégradé en diagonale, étincelles, reflet balayant, icône blanche, texte gras italique.
------------------------------------------------------------------------

export type TileProps = {
	Text: string,
	Icon: string,
	Color: Color3,
	Color2: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	Parent: Instance?,
	LayoutOrder: number?,
	Wide: boolean?,
	Seed: number?,
	OnClick: (() -> ())?,
}

function Components.tile(props: TileProps): TextButton
	local color = props.Color
	local color2 = props.Color2 or Theme.dark(color, 0.45)
	local button = new("TextButton", {
		Name = "Tile_" .. props.Text,
		Size = props.Size or UDim2.fromOffset(96, 96),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local scale = new("UIScale", { Parent = button })
	-- Bord épais (couleur claire) + contour noir fin.
	local rim = new("Frame", {
		Name = "Rim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = button,
	})
	Theme.corner(14).Parent = rim
	Theme.stroke(C.Stroke, 2.5).Parent = rim
	Theme.gradient({ Theme.light(color, 0.55), Theme.light(color, 0.15), Theme.dark(color, 0.1) }, 70).Parent = rim
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = rim,
	})
	Theme.corner(10).Parent = face
	Theme.gradient({ Theme.light(color, 0.12), color, color2 }, 55).Parent = face
	Theme.sparkles(face, props.Wide and 9 or 5, props.Seed or #props.Text, 0.7)
	-- Reflet diagonal qui balaie la tuile de temps en temps.
	local sweep = new("Frame", {
		Name = "Sweep",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.6, 0.5),
		Size = UDim2.new(0.28, 0, 2.2, 0),
		Rotation = 25,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = face,
	})
	Theme.gradient({ WHITE, WHITE, WHITE }, 0, { 1, 0.55, 1 }).Parent = sweep
	local phase = ((props.Seed or #props.Text) * 0.37) % 1
	Theme.onFrame(sweep, function(_, t)
		local cycle = (t * 0.22 + phase) % 1
		sweep.Position = UDim2.fromScale(-0.6 + cycle * 4, 0.5)
	end)
	-- Reflet fixe (haut)
	local gloss = new("Frame", {
		Name = "Gloss",
		Size = UDim2.new(1, 0, 0.45, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = face,
	})
	Theme.gradient({ WHITE, WHITE }, 90, { 0.72, 1 }).Parent = gloss

	local iconBox
	if props.Wide then
		iconBox = new("Frame", {
			Name = "IconBox",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.new(0, 0, 0.7, 0),
			BackgroundColor3 = Theme.dark(color2, 0.35),
			BackgroundTransparency = 0.25,
			ZIndex = 3,
			Parent = face,
		})
		new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = iconBox })
		iconBox.Size = UDim2.new(0.7, 0, 0.7, 0)
		Theme.corner(10).Parent = iconBox
		Icons.make(props.Icon, iconBox, { px = 36, size = UDim2.fromScale(0.72, 0.72), ink = Theme.dark(color2, 0.4), zindex = 4 })
		Theme.label({
			Name = "Label",
			Text = props.Text,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.3, 0, 0.5, 0),
			Size = UDim2.new(0.66, 0, 0.42, 0),
			FontFace = Theme.Faces.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			StrokeThickness = 2.5,
			Parent = face,
		})
	else
		iconBox = new("Frame", {
			Name = "IconBox",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.56, 0.56),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = face,
		})
		Icons.make(props.Icon, iconBox, { px = 48, ink = Theme.dark(color2, 0.35), zindex = 3 })
		Theme.label({
			Name = "Label",
			Text = props.Text,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1.06, 0, 0.27, 0),
			FontFace = Theme.Faces.Title,
			ZIndex = 5,
			StrokeThickness = 2.5,
			Parent = rim,
		})
	end
	-- Pastille de notification (ex : « ! » quand un nœud est achetable).
	local dot = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 8,
		Parent = button,
	})
	Theme.round().Parent = dot
	Theme.stroke(WHITE, 2).Parent = dot
	Theme.label({ Name = "Text", Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), FontFace = Theme.Faces.Heavy, ZIndex = 9, Parent = dot })
	Theme.onFrame(dot, function(_, t)
		if dot.Visible then
			dot.Rotation = math.sin(t * 6) * 10
		end
	end)

	Components.interactive(button, scale, 1.07)
	button.Activated:Connect(function()
		Components.click()
		if props.OnClick then
			props.OnClick()
		end
	end)
	return button
end

function Components.setBadge(tile: Instance, text: string?)
	local dot = tile:FindFirstChild("Badge") :: Frame?
	if dot then
		dot.Visible = text ~= nil
		local label = dot:FindFirstChild("Text") :: TextLabel?
		if label and text then
			label.Text = text
		end
	end
end

------------------------------------------------------------------------
-- Fenêtre (panneau sombre façon « verre fumé », bandeau coloré, onglets, ✕ / B)
------------------------------------------------------------------------

export type WindowOptions = {
	icon: string?,
	tabs: { { id: string, text: string, icon: string? } }?,
	onTab: ((string) -> ())?,
	noDim: boolean?,
	subtitle: string?,
}

function Components.window(parent: Instance, title: string, accent: Color3?, size: UDim2?, options: WindowOptions?)
	local opts = options or {}
	local color = accent or C.Purple
	-- Calque plein écran à l'échelle (coordonnées logiques 1280 x 720).
	local root = Theme.scaledRoot(parent, "WindowRoot_" .. title, 10)
	root.Visible = false
	local dim = new("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 4, 10),
		BackgroundTransparency = opts.noDim and 1 or 0.5,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Parent = root,
	})
	local holder = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size or UDim2.fromOffset(1060, 600),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local panel = new("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = holder,
	})
	local anim = new("UIScale", { Parent = panel })
	Theme.corner(18).Parent = panel
	Theme.stroke(C.Stroke, 4).Parent = panel
	Theme.gradient({ Color3.fromRGB(34, 34, 50), Color3.fromRGB(20, 20, 30), Color3.fromRGB(12, 12, 18) }, 90).Parent = panel
	-- Liseré clair intérieur
	local edge = new("Frame", {
		Name = "Edge",
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Theme.corner(16).Parent = edge
	Theme.stroke(C.Edge, 1.5, 0.35).Parent = edge
	-- Lueur colorée en haut
	local glow = new("Frame", {
		Name = "Glow",
		Size = UDim2.new(1, -8, 0, 150),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = panel,
	})
	Theme.corner(15).Parent = glow
	Theme.gradient({ color, color }, 90, { 0.62, 1 }).Parent = glow
	Theme.sparkles(glow, 10, #title, 0.82)

	-- Bandeau du titre
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = panel,
	})
	local iconBox = new("Frame", {
		Name = "TitleIcon",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = header,
	})
	Theme.corner(12).Parent = iconBox
	Theme.stroke(C.Stroke, 2.5).Parent = iconBox
	Theme.gradient({ Theme.light(color, 0.35), color, Theme.dark(color, 0.35) }, 60).Parent = iconBox
	Icons.make(opts.icon or "star", iconBox, { px = 34, size = UDim2.fromScale(0.72, 0.72), ink = Theme.dark(color, 0.5), zindex = 3 })
	if not opts.icon then
		iconBox.Visible = false
	end
	local titleLabel = Theme.label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -230, 0, 40),
		Position = UDim2.fromOffset(opts.icon and 78 or 22, 13),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 3,
		Parent = header,
	})
	local subtitle = Theme.label({
		Name = "Subtitle",
		Text = opts.subtitle or "",
		Size = UDim2.new(0, 360, 0, 22),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -86, 0, 23),
		TextColor3 = C.TextDim,
		FontFace = Theme.Faces.Bold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		StrokeThickness = 1.5,
		Parent = header,
	})
	-- Bouton fermer (carré rouge) + indication B
	local closeButton = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Parent = header,
	})
	Theme.corner(12).Parent = closeButton
	Theme.stroke(C.Stroke, 2.5).Parent = closeButton
	Theme.gradient({ Color3.fromRGB(255, 110, 110), Color3.fromRGB(220, 40, 50), Color3.fromRGB(150, 20, 30) }, 90).Parent = closeButton
	Icons.make("close", closeButton, { px = 30, size = UDim2.fromScale(0.5, 0.5), zindex = 4 })
	local closeScale = new("UIScale", { Parent = closeButton })
	Components.interactive(closeButton, closeScale, 1.1)
	Console.hint(closeButton, "B", { Position = UDim2.new(0, -14, 1, -14), ZIndex = 6 })

	local top = 70
	local window = {
		frame = holder,
		root = root,
		panel = panel,
		content = nil :: any,
		title = titleLabel,
		subtitle = subtitle,
		onClose = nil :: (() -> ())?,
		isOpen = false,
		tabs = {},
		tabId = nil :: string?,
		accent = color,
	}

	-- Onglets (pilules) avec LB / RB
	if opts.tabs then
		local bar = new("Frame", {
			Name = "Tabs",
			Size = UDim2.new(1, -40, 0, 42),
			Position = UDim2.fromOffset(20, top),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = panel,
		})
		local layout = Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = bar
		local lb = Console.hint(bar, "LB", { LayoutOrder = 0 })
		local _ = lb
		for i, tab in opts.tabs do
			local pill = new("TextButton", {
				Name = "Tab_" .. tab.id,
				Size = UDim2.fromOffset(0, 38),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = C.Inset,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				ZIndex = 2,
				Parent = bar,
			})
			Theme.corner(19).Parent = pill
			local pillStroke = Theme.stroke(C.Stroke, 2)
			pillStroke.Parent = pill
			Theme.padding(18, 0).Parent = pill
			local inner = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
			inner.VerticalAlignment = Enum.VerticalAlignment.Center
			inner.Parent = pill
			if tab.icon then
				local ic = new("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 3, Parent = pill })
				Icons.make(tab.icon, ic, { px = 22, zindex = 3, ink = C.PanelDark })
			end
			Theme.label({
				Name = "Label",
				Text = tab.text,
				Size = UDim2.fromOffset(0, 26),
				AutomaticSize = Enum.AutomaticSize.X,
				TextScaled = false,
				TextSize = 20,
				FontFace = Theme.Faces.Title,
				LayoutOrder = 2,
				ZIndex = 3,
				Parent = pill,
			})
			local pillScale = new("UIScale", { Parent = pill })
			Components.interactive(pill, pillScale, 1.05)
			pill.Activated:Connect(function()
				Components.click()
				window.setTab(tab.id)
			end)
			window.tabs[tab.id] = { button = pill, stroke = pillStroke, order = i }
		end
		Console.hint(bar, "RB", { LayoutOrder = #opts.tabs + 1 })
		top += 50
	end

	local content = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -40, 1, -(top + 22)),
		Position = UDim2.fromOffset(20, top + 4),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = panel,
	})
	window.content = content

	local items = { { "A", "Choisir" }, { "B", "Fermer" } }
	if opts.tabs then
		table.insert(items, { "LB", "Onglet" })
		table.insert(items, { "RB", "Onglet" })
	end
	Console.hintBar(panel, items, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6) })

	function window.setTab(id: string, silent: boolean?)
		window.tabId = id
		for tabId, info in window.tabs do
			local active = tabId == id
			info.button.BackgroundColor3 = active and color or C.Inset
			info.stroke.Color = active and WHITE or C.Stroke
		end
		if not silent and opts.onTab then
			opts.onTab(id)
		end
	end

	function window.cycleTab(direction: number)
		if not opts.tabs then
			return
		end
		local index = 1
		for i, tab in opts.tabs do
			if tab.id == window.tabId then
				index = i
			end
		end
		index = (index - 1 + direction) % #opts.tabs + 1
		Components.click()
		window.setTab(opts.tabs[index].id)
	end

	function window.open()
		if window.isOpen then
			return
		end
		window.isOpen = true
		root.Visible = true
		anim.Scale = 0.86
		Theme.tween(anim, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		if not opts.noDim then
			dim.BackgroundTransparency = 1
			Theme.tween(dim, 0.25, { BackgroundTransparency = 0.5 })
		end
	end

	function window.close()
		if not window.isOpen then
			return
		end
		window.isOpen = false
		local tween = Theme.tween(anim, 0.14, { Scale = 0.86 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			if not window.isOpen then
				root.Visible = false
			end
		end)
		task.delay(0.2, function()
			if not window.isOpen then
				root.Visible = false
			end
		end)
		if window.onClose then
			window.onClose()
		end
	end

	-- Premier bouton sélectionnable du contenu (pour la manette).
	function window.firstSelectable(): GuiObject?
		local best, bestY, bestX = nil, math.huge, math.huge
		for _, d in content:GetDescendants() do
			if d:IsA("GuiButton") and d.Selectable and d.Visible then
				local ok, p = pcall(function()
					return d.AbsolutePosition
				end)
				if not ok or typeof(p) ~= "Vector2" then
					return best or d
				end
				if p.Y < bestY - 4 or (math.abs(p.Y - bestY) <= 4 and p.X < bestX) then
					best, bestY, bestX = d, p.Y, p.X
				end
			end
		end
		return best or closeButton
	end

	closeButton.Activated:Connect(function()
		Components.click()
		window.close()
	end)
	dim.Activated:Connect(function()
		window.close()
	end)
	return window
end

-- Enregistre une fenêtre auprès de Menus (avec onglets LB/RB et sélection manette).
function Components.registerWindow(Menus, name: string, window, onOpen: ((any?) -> ())?, selection: (() -> GuiObject?)?)
	window.onClose = function()
		Menus.closed(name)
	end
	Menus.register(name, {
		open = function(arg)
			window.open()
			if onOpen then
				onOpen(arg)
			end
		end,
		close = window.close,
		tab = window.cycleTab,
		selection = selection or window.firstSelectable,
	})
end

------------------------------------------------------------------------
-- Panneaux, titres, défilement
------------------------------------------------------------------------

function Components.panel(parent: Instance, props: { [string]: any }?, accent: Color3?): Frame
	local frame = new("Frame", {
		Name = "Panel",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	Theme.corner(14).Parent = frame
	Theme.stroke(accent and Theme.dark(accent, 0.2) or C.Edge, 2, accent and 0 or 0.45).Parent = frame
	Theme.gradient({ Color3.fromRGB(30, 30, 44), Color3.fromRGB(16, 16, 24) }, 90).Parent = frame
	return frame
end

function Components.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local scroll = new("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(150, 150, 180),
		ScrollBarImageTransparency = 0.2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(scroll :: any)[key] = value
		end
	end
	return scroll
end

function Components.sectionTitle(parent: Instance, text: string, props: { [string]: any }?, color: Color3?): TextLabel
	local label = Theme.label({
		Name = "Section",
		Text = text,
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color or C.Gold,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

function Components.emptyState(parent: Instance, text: string, icon: string?): Frame
	local frame = new("Frame", {
		Name = "Empty",
		Size = UDim2.new(1, -20, 0, 150),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local iconHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Icons.make(icon or "gift", iconHolder, { px = 64, color = Color3.fromRGB(120, 120, 150), ink = C.PanelDark })
	Theme.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 72),
		TextColor3 = C.TextDim,
		TextWrapped = true,
		MaxSize = 22,
		Parent = frame,
	})
	return frame
end

------------------------------------------------------------------------
-- Hexagone (3 rectangles tournés à 0°, 60° et 120° : aucune image nécessaire)
------------------------------------------------------------------------

-- Crée un hexagone « pointe en haut » de rayon `radius` (en pixels) centré dans `parent`.
function Components.hexagon(parent: Instance, radius: number, color: Color3, props: { [string]: any }?): Frame
	local holder = new("Frame", {
		Name = "Hex",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(holder :: any)[key] = value
		end
	end
	local w = math.sqrt(3) * radius
	for i = 0, 2 do
		new("Frame", {
			Name = "Part" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(w, radius),
			Rotation = i * 60,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
	end
	return holder
end

function Components.setHexColor(hex: Instance, color: Color3, transparency: number?)
	for _, part in hex:GetChildren() do
		if part:IsA("Frame") then
			part.BackgroundColor3 = color
			if transparency then
				part.BackgroundTransparency = transparency
			end
		end
	end
end

------------------------------------------------------------------------
-- Aperçus 3D (ViewportFrame)
------------------------------------------------------------------------

local spinning = {} -- [ViewportFrame] = { model, base, phase }
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
			local inner = {}
			for k2, v2 in v do
				table.insert(inner, tostring(k2) .. ":" .. (typeof(v2) == "Color3" and v2:ToHex() or tostring(v2)))
			end
			table.sort(inner)
			v = table.concat(inner, ",")
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
		Ambient = Color3.fromRGB(190, 190, 205),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-0.5, -0.9, -0.9),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(viewport :: any)[key] = value
		end
	end
	local camera = new("Camera", {
		FieldOfView = 32,
		Parent = viewport,
	})
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.26, distance * 0.1, -distance), focus)
	viewport.CurrentCamera = camera
	model.Parent = viewport
	if spin then
		spinning[viewport] = { model = model, base = model:GetPivot(), phase = math.random() * 6 }
	end
	return viewport
end

-- `entry` (facultatif) permet d'utiliser le modèle personnalisé du perso s'il existe.
-- `framing` : "full" (corps entier, défaut) ou "bust" (buste, plus proche).
function Components.characterViewport(parent: Instance, look, spin: boolean?, entry: any?, framing: string?): ViewportFrame
	local model = Components.characterModel(look, entry and entry.id, entry and entry.stars)
	if framing == "bust" then
		return Components.viewport(parent, model, Vector3.new(0, 4.3, 0), 8.5, nil, spin)
	end
	return Components.viewport(parent, model, Vector3.new(0, 3.5, 0), 12.5, nil, spin)
end

function Components.relicViewport(parent: Instance, relic, spin: boolean?): ViewportFrame
	local model = RelicBuilder.build(relic.look, relic.tier, 1)
	return Components.viewport(parent, model, Vector3.new(0, 1.3, 0), 7, nil, spin)
end

------------------------------------------------------------------------
-- Rareté d'un perso possédé (raretés de la machine si présentes, sinon celle du perso)
------------------------------------------------------------------------

function Components.rarityOf(entry, desc): string
	if entry and (entry.rollRarity or entry.rarity) then
		return entry.rollRarity or entry.rarity
	end
	if desc and desc.isFusion then
		return "crossover"
	end
	return desc and desc.rarity or "common"
end

-- Petite étiquette de rareté (pilule colorée, arc-en-ciel pour Secret / Crossover).
function Components.rarityTag(parent: Instance, rarityId: string, props: { [string]: any }?): Frame
	local info = Theme.rarity(rarityId)
	local tag = new("Frame", {
		Name = "RarityTag",
		Size = UDim2.fromOffset(110, 24),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(tag :: any)[key] = value
		end
	end
	Theme.corner(8).Parent = tag
	Theme.stroke(C.Stroke, 2).Parent = tag
	local gradient = Theme.gradient(Theme.rarityGradient(rarityId), info.rainbow and 0 or 90)
	gradient.Parent = tag
	if info.rainbow then
		Theme.onFrame(gradient, function(_, t)
			gradient.Offset = Vector2.new(math.sin(t * 1.5) * 0.3, 0)
		end)
	end
	Theme.label({
		Text = string.upper(info.name),
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		FontFace = Theme.Faces.Title,
		ZIndex = tag.ZIndex + 1,
		StrokeThickness = 1.5,
		Parent = tag,
	})
	return tag
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
	hideLevel: boolean?,
	caption: string?,
}

function Components.characterCard(parent: Instance, entry, options: CardOptions?)
	local opts = options or {}
	local desc = Formulas.describe(entry)
	local rarityId = Components.rarityOf(entry, desc)
	local info = Theme.rarity(rarityId)
	local card = new("TextButton", {
		Name = "Card",
		Size = opts.size or UDim2.fromOffset(140, 180),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = opts.layoutOrder or 0,
		Parent = parent,
	})
	local scale = new("UIScale", { Parent = card })
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = card,
	})
	Theme.corner(14).Parent = face
	Theme.gradient({ Color3.fromRGB(46, 46, 64), Color3.fromRGB(24, 24, 34), Theme.dark(info.rainbow and C.Cyan or info.color, 0.55) }, 90).Parent = face
	if info.rainbow then
		Theme.rainbowStroke(face, opts.selected and 5 or 3)
	else
		Theme.stroke(opts.selected and C.Gold or info.color, opts.selected and 5 or 3).Parent = face
	end
	-- Lueur de rareté derrière le perso
	local glow = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0.62),
		BackgroundColor3 = info.rainbow and C.Cyan or info.color,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = face,
	})
	Theme.round().Parent = glow
	Theme.gradient({ WHITE, WHITE }, 90, { 0.35, 1 }).Parent = glow

	if desc then
		local holder = new("Frame", {
			Name = "Preview",
			Size = UDim2.new(1, -8, 0.7, 0),
			Position = UDim2.fromOffset(4, 6),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = face,
		})
		local viewport = Components.characterViewport(holder, desc.look, opts.spin, entry)
		viewport.ZIndex = 2
	end

	-- Bandeau du bas : nom + rareté
	local strip = new("Frame", {
		Name = "Strip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.27),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = face,
	})
	Theme.corner(12).Parent = strip
	Theme.label({
		Name = "CharName",
		Text = desc and desc.name or "?",
		Size = UDim2.new(0.94, 0, 0.52, 0),
		Position = UDim2.fromScale(0.03, 0.04),
		FontFace = Theme.Faces.Title,
		ZIndex = 4,
		Parent = strip,
	})
	Theme.label({
		Name = "Rarity",
		Text = opts.caption or info.name,
		Size = UDim2.new(0.94, 0, 0.36, 0),
		Position = UDim2.fromScale(0.03, 0.58),
		TextColor3 = info.rainbow and C.Cyan or Theme.light(info.color, 0.2),
		FontFace = Theme.Faces.Heavy,
		ZIndex = 4,
		StrokeThickness = 1.5,
		Parent = strip,
	})
	if not opts.hideLevel then
		local levelBadge = new("Frame", {
			Name = "LevelBadge",
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(0.46, 0, 0.13, 0),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.4,
			ZIndex = 4,
			Parent = face,
		})
		Theme.corner(8).Parent = levelBadge
		Theme.label({
			Name = "Level",
			Text = "Nv." .. tostring(entry.level or 1),
			Size = UDim2.new(1, -8, 1, -4),
			Position = UDim2.fromOffset(4, 2),
			FontFace = Theme.Faces.Title,
			TextColor3 = C.Yellow,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Parent = levelBadge,
		})
	end
	Theme.label({
		Name = "Stars",
		Text = string.rep("★", entry.stars or 1),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.44, 0, 0.12, 0),
		Position = UDim2.new(1, -6, 0, 6),
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.Faces.Heavy,
		ZIndex = 4,
		Parent = face,
	})
	local aura = Auras.get(entry.aura)
	local chipY = 0.58
	if entry.trait and Traits.get(entry.trait) then
		local chip = Components.traitChip(face, entry.trait, UDim2.new(0.66, 0, 0.11, 0), UDim2.fromScale(0.04, chipY))
		if chip then
			chip.ZIndex = 4
		end
		chipY -= 0.12
	end
	if aura then
		local chip = new("Frame", {
			Name = "AuraChip",
			Size = UDim2.new(0.6, 0, 0.1, 0),
			Position = UDim2.fromScale(0.04, chipY),
			BackgroundColor3 = aura.color,
			ZIndex = 4,
			Parent = face,
		})
		Theme.corner(8).Parent = chip
		Theme.stroke(C.Stroke, 2).Parent = chip
		Theme.label({ Text = aura.name, Size = UDim2.fromScale(0.92, 0.86), Position = UDim2.fromScale(0.04, 0.07), FontFace = Theme.Faces.Heavy, ZIndex = 5, Parent = chip })
	end
	if opts.inTeam then
		local badge = new("Frame", {
			Name = "TeamBadge",
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -5, 0.15, 0),
			BackgroundColor3 = C.Blue,
			ZIndex = 4,
			Parent = face,
		})
		Theme.round().Parent = badge
		Theme.stroke(WHITE, 2).Parent = badge
		Icons.make("sword", badge, { px = 20, size = UDim2.fromScale(0.62, 0.62), zindex = 5, ink = C.Blue })
	end
	if entry.locked then
		local lock = new("Frame", {
			Name = "LockBadge",
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(1, -8, 0.15, opts.inTeam and 34 or 0),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = face,
		})
		Icons.make("lock", lock, { px = 24, zindex = 5, ink = C.PanelDark })
	end

	Components.interactive(card, scale, 1.05)
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
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	Theme.round().Parent = frame
	Theme.stroke(C.Stroke, 2).Parent = frame
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	Theme.round().Parent = fill
	local gradient = Theme.gradient({ Theme.light(color, 0.35), color, Theme.dark(color, 0.15) }, 90)
	gradient.Parent = fill
	local shine = new("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -4, 0.4, 0),
		Position = UDim2.new(0, 2, 0.1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex,
		Parent = fill,
	})
	Theme.round().Parent = shine
	local bar = { frame = frame, fill = fill }
	function bar.set(fraction: number)
		local f = math.clamp(fraction, 0, 1)
		fill.Size = UDim2.fromScale(f, 1)
		fill.Visible = f > 0.001
	end
	function bar.setColor(newColor: Color3)
		gradient.Color = Theme.sequence({ Theme.light(newColor, 0.35), newColor, Theme.dark(newColor, 0.15) })
	end
	return bar
end

-- Petite gemme (losange) de la couleur d'un matériau.
function Components.gem(parent: Instance, color: Color3, size: number, position: UDim2?): Frame
	local gem = new("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	Theme.corner(math.max(2, size // 6)).Parent = gem
	Theme.stroke(C.Stroke, 2).Parent = gem
	Theme.gradient({ Theme.light(color, 0.5), color, Theme.dark(color, 0.35) }, 0).Parent = gem
	return gem
end

-- Pièce d'or (cercle doré avec « $ »).
function Components.coinIcon(parent: Instance, size: number, position: UDim2?): Frame
	local coin = new("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	Theme.round().Parent = coin
	Theme.stroke(Color3.fromRGB(120, 70, 8), math.max(2, size / 14)).Parent = coin
	Theme.gradient({ Color3.fromRGB(255, 246, 160), Color3.fromRGB(255, 200, 50), Color3.fromRGB(230, 140, 20) }, 60).Parent = coin
	local inner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		BackgroundTransparency = 1,
		Parent = coin,
	})
	Theme.round().Parent = inner
	Theme.stroke(Color3.fromRGB(200, 120, 10), math.max(1, size / 22), 0.3).Parent = inner
	Theme.label({
		Text = "$",
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.19, 0.2),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Color3.fromRGB(170, 96, 8),
		Stroke = false,
		Parent = coin,
	})
	return coin
end

function Components.materialPill(parent: Instance, materialId: string, count: number, layoutOrder: number?)
	local material = Universes.getMaterial(materialId)
	local pill = new("Frame", {
		Name = "Pill_" .. materialId,
		Size = UDim2.fromOffset(112, 32),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})
	Theme.round().Parent = pill
	Theme.stroke(C.Stroke, 2).Parent = pill
	Components.gem(pill, material and material.color or WHITE, 16, UDim2.fromOffset(18, 16))
	Theme.label({
		Name = "Count",
		Text = Formulas.formatNumber(count),
		Size = UDim2.new(1, -42, 1, -8),
		Position = UDim2.fromOffset(34, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Faces.Heavy,
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
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	Theme.corner(8).Parent = chip
	Theme.stroke(Traits.TierColors[trait.tier] or C.Stroke, 2).Parent = chip
	Theme.gradient({ Theme.light(trait.color, 0.2), Theme.dark(trait.color, 0.35) }, 90).Parent = chip
	Theme.label({ Text = "◆ " .. trait.name, Size = UDim2.fromScale(0.94, 0.86), Position = UDim2.fromScale(0.03, 0.07), FontFace = Theme.Faces.Heavy, ZIndex = chip.ZIndex + 1, Parent = chip })
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
