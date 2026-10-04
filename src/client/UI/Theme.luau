-- Thème visuel de l'interface (style « jeu de tirage » brillant) + petites fonctions de création.
--
-- Tout est construit en code (aucune image importée) : dégradés, reflets, contours épais,
-- motifs d'étincelles, polices intégrées de Roblox (GothamSSm, Fredoka One, Luckiest Guy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

Theme.Colors = {
	-- Panneaux sombres « verre fumé » (comme la fiche d'unité de référence)
	Panel = rgb(24, 24, 34),
	PanelLight = rgb(44, 44, 62),
	PanelDark = rgb(12, 12, 18),
	Inset = rgb(32, 32, 46),
	Edge = rgb(92, 92, 118), -- liseré clair des panneaux
	Stroke = rgb(6, 6, 10), -- contour noir épais
	Text = rgb(255, 255, 255),
	TextDim = rgb(172, 174, 196),
	-- Couleurs vives
	Gold = rgb(255, 206, 64),
	Green = rgb(70, 214, 96),
	Red = rgb(236, 60, 70),
	Blue = rgb(54, 150, 255),
	Cyan = rgb(50, 214, 255),
	Purple = rgb(168, 78, 255),
	Magenta = rgb(222, 60, 230),
	Orange = rgb(255, 140, 36),
	Pink = rgb(255, 84, 170),
	Yellow = rgb(255, 222, 50),
	Gray = rgb(110, 112, 130),
}

-- Polices (FontFace) : titres en gras italique contouré, comme les boutons de référence.
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
Theme.Faces = {
	Title = Font.new(GOTHAM, Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	Heavy = Font.new(GOTHAM, Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
	Bold = Font.new(GOTHAM, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	Medium = Font.new(GOTHAM, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
	Cartoon = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Round = Font.new("rbxasset://fonts/families/FredokaOne.json"),
}

-- Anciennes polices (Enum.Font) : converties automatiquement en FontFace par Theme.label.
Theme.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
	Small = Enum.Font.GothamBold,
}
local ENUM_TO_FACE = {
	[Enum.Font.LuckiestGuy] = Theme.Faces.Title,
	[Enum.Font.FredokaOne] = Theme.Faces.Bold,
	[Enum.Font.GothamBold] = Theme.Faces.Medium,
	[Enum.Font.GothamBlack] = Theme.Faces.Heavy,
}

------------------------------------------------------------------------
-- Raretés (communes à tout le jeu)
-- Commun gris · Peu commun vert · Rare bleu · Épique violet · Légendaire or · Mythique rouge
-- · Secret noir/arc-en-ciel · Crossover (fusions) turquoise/arc-en-ciel.
------------------------------------------------------------------------

local RARITY = {
	common = { name = "Commun", order = 1, color = rgb(176, 186, 197), dark = rgb(70, 76, 88) },
	uncommon = { name = "Peu commun", order = 2, color = rgb(84, 220, 96), dark = rgb(22, 96, 40) },
	rare = { name = "Rare", order = 3, color = rgb(64, 160, 255), dark = rgb(18, 60, 140) },
	epic = { name = "Épique", order = 4, color = rgb(176, 92, 255), dark = rgb(70, 26, 140) },
	legendary = { name = "Légendaire", order = 5, color = rgb(255, 190, 40), dark = rgb(150, 86, 6) },
	mythic = { name = "Mythique", order = 6, color = rgb(255, 52, 64), dark = rgb(130, 10, 26) },
	secret = { name = "Secret", order = 7, color = rgb(28, 24, 36), dark = rgb(6, 6, 10), rainbow = true },
	crossover = { name = "Crossover", order = 8, color = rgb(80, 255, 220), dark = rgb(20, 90, 110), rainbow = true },
}
Theme.RarityOrder = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret", "crossover" }
Theme.RainbowColors = { rgb(255, 80, 80), rgb(255, 210, 60), rgb(80, 255, 120), rgb(70, 170, 255), rgb(220, 90, 255) }

-- Infos d'une rareté (nom, couleur, couleur sombre, arc-en-ciel ?). Les raretés de la machine
-- (Economy.RollRarities, si elles existent) gardent leurs couleurs.
function Theme.rarity(id: string?)
	local key = id or "common"
	local info = RARITY[key] or RARITY.common
	return info
end

function Theme.rarityGradient(id: string?): { Color3 }
	local info = Theme.rarity(id)
	if info.rainbow then
		return Theme.RainbowColors
	end
	return { info.color:Lerp(WHITE, 0.35), info.color, info.dark }
end

------------------------------------------------------------------------
-- Création déclarative : Theme.new("Frame", { Size = ..., Children = { ... } })
------------------------------------------------------------------------

function Theme.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance: any = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif key == "Font" and typeof(value) == "EnumItem" then
				instance.FontFace = ENUM_TO_FACE[value] or Font.fromEnum(value)
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

local new = Theme.new

function Theme.corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.round(): UICorner
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Theme.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Theme.textStroke(color: Color3?, thickness: number?): UIStroke
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Theme.sequence(colors: { Color3 }): ColorSequence
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return ColorSequence.new(keypoints)
end

function Theme.gradient(colors: { Color3 }, rotation: number?, transparency: { number }?): UIGradient
	local gradient = new("UIGradient", { Color = Theme.sequence(colors), Rotation = rotation or 90 })
	if transparency then
		local keypoints = {}
		for i, value in transparency do
			table.insert(keypoints, NumberSequenceKeypoint.new((i - 1) / math.max(1, #transparency - 1), value))
		end
		gradient.Transparency = NumberSequence.new(keypoints)
	end
	return gradient
end

function Theme.padding(px: number, py: number?): UIPadding
	local h = UDim.new(0, px)
	local v = UDim.new(0, py or px)
	return new("UIPadding", { PaddingTop = v, PaddingBottom = v, PaddingLeft = h, PaddingRight = h })
end

function Theme.list(direction: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
	})
end

function Theme.grid(cell: Vector2, gap: number?, align: Enum.HorizontalAlignment?): UIGridLayout
	return new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap or 10, gap or 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

-- Texte : par défaut GothamSSm gras, blanc, contour noir, taille automatique.
function Theme.label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Text,
		FontFace = Theme.Faces.Bold,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		if key ~= "Stroke" and key ~= "StrokeThickness" and key ~= "StrokeColor" and key ~= "MaxSize" then
			base[key] = value
		end
	end
	local label = new("TextLabel", base)
	if props.Stroke ~= false then
		Theme.textStroke(props.StrokeColor, props.StrokeThickness or 2).Parent = label
	end
	if props.MaxSize then
		new("UITextSizeConstraint", { MaxTextSize = props.MaxSize, Parent = label })
	end
	return label
end

function Theme.tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

------------------------------------------------------------------------
-- Décor : reflet brillant, étincelles, ombre portée
------------------------------------------------------------------------

-- Reflet blanc en haut d'un bouton (moitié haute, coins arrondis).
function Theme.shine(parent: Instance, radius: number?, strength: number?): Frame
	local shine = new("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -6, 0.48, 0),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
	Theme.corner(radius or 10).Parent = shine
	local a = 1 - (strength or 0.4)
	Theme.gradient({ WHITE, WHITE }, 90, { a, 1 }).Parent = shine
	return shine
end

-- Petite étincelle à 4 branches (deux traits arrondis croisés).
function Theme.sparkle(parent: Instance, position: UDim2, size: number, transparency: number?, zindex: number?): Frame
	local holder = new("Frame", {
		Name = "Sparkle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = 0,
		ZIndex = zindex or 2,
		Parent = parent,
	})
	for i = 0, 1 do
		local bar = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = i == 0 and UDim2.new(0.22, 0, 1, 0) or UDim2.new(1, 0, 0.22, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = transparency or 0.75,
			BorderSizePixel = 0,
			ZIndex = zindex or 2,
			Parent = holder,
		})
		Theme.round().Parent = bar
	end
	return holder
end

-- Motif discret d'étincelles (positions pseudo-aléatoires mais stables grâce à la graine).
function Theme.sparkles(parent: Instance, count: number, seed: number?, transparency: number?, zindex: number?)
	local rng = Random.new(seed or 7)
	for _ = 1, count do
		Theme.sparkle(
			parent,
			UDim2.fromScale(rng:NextNumber(0.08, 0.92), rng:NextNumber(0.08, 0.92)),
			rng:NextInteger(6, 13),
			(transparency or 0.72) + rng:NextNumber(0, 0.15),
			zindex
		)
	end
end

-- Ombre portée douce (cadre noir décalé derrière l'élément).
function Theme.dropShadow(parent: Instance, radius: number?, offset: number?): Frame
	local shadow = new("Frame", {
		Name = "Shadow",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, offset or 5),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = parent,
	})
	Theme.corner(radius or 12).Parent = shadow
	return shadow
end

------------------------------------------------------------------------
-- Animations par image (une seule boucle pour toute l'interface)
------------------------------------------------------------------------

local frameCallbacks: { [any]: (number, number) -> () } = {}
local clock = 0

-- Appelle `callback(dt, t)` à chaque image tant que `owner` est dans l'arbre.
function Theme.onFrame(owner: Instance, callback: (number, number) -> ())
	frameCallbacks[owner] = callback
end

function Theme.stopFrame(owner: Instance)
	frameCallbacks[owner] = nil
end

RunService.RenderStepped:Connect(function(dt)
	clock += dt or 0
	for owner, callback in frameCallbacks do
		if owner.Parent == nil then
			frameCallbacks[owner] = nil
		else
			local ok, err = pcall(callback, dt or 0, clock)
			if not ok then
				frameCallbacks[owner] = nil
				warn("[Interface] animation arrêtée : " .. tostring(err))
			end
		end
	end
end)

function Theme.time(): number
	return clock
end

-- Contour arc-en-ciel qui tourne (raretés Secret / Crossover).
function Theme.rainbowStroke(parent: GuiObject, thickness: number?): UIStroke
	local stroke = Theme.stroke(WHITE, thickness or 3)
	stroke.Parent = parent
	local gradient = Theme.gradient(Theme.RainbowColors, 0)
	gradient.Parent = stroke
	Theme.onFrame(gradient, function(dt)
		gradient.Rotation = (gradient.Rotation + dt * 120) % 360
	end)
	return stroke
end

------------------------------------------------------------------------
-- Mise à l'échelle (écran de référence 1280 x 720, télé, mobile)
------------------------------------------------------------------------

local scaled: { UIScale } = {}
local currentScale = 1

function Theme.registerScaled(frame: GuiObject): UIScale
	local scale = Instance.new("UIScale")
	scale.Scale = currentScale
	scale.Parent = frame
	table.insert(scaled, scale)
	return scale
end

-- Calque plein écran en coordonnées « logiques » : sa taille vaut écran / échelle et son UIScale
-- le ramène à la taille de l'écran. Tout ce qu'il contient se place donc comme sur un écran
-- de 1280 x 720, quelle que soit la vraie résolution (téléphone, PC, télé 4K).
local roots: { Frame } = {}

function Theme.scaledRoot(parent: Instance, name: string, zindex: number?): Frame
	local root = new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1 / currentScale, 1 / currentScale),
		BackgroundTransparency = 1,
		ZIndex = zindex or 1,
		Parent = parent,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = currentScale
	scale.Parent = root
	table.insert(roots, root)
	return root
end

function Theme.setScale(value: number)
	currentScale = value
	for i = #scaled, 1, -1 do
		local scale = scaled[i]
		if scale.Parent then
			scale.Scale = value
		else
			table.remove(scaled, i)
		end
	end
	for _, root in roots do
		root.Size = UDim2.fromScale(1 / value, 1 / value)
		local scale = root:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = value
		end
	end
end

function Theme.getScale(): number
	return currentScale
end

-- Couleur arc-en-ciel animée.
function Theme.rainbow(t: number): Color3
	return Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
end

-- Éclaircit / assombrit une couleur.
function Theme.light(color: Color3, amount: number?): Color3
	return color:Lerp(WHITE, amount or 0.3)
end

function Theme.dark(color: Color3, amount: number?): Color3
	return color:Lerp(BLACK, amount or 0.3)
end

-- Module partagé facultatif (créé par un autre domaine) : nil s'il n'existe pas encore.
function Theme.optionalConfig(name: string): any?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	local module = config and config:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
	end
	return nil
end

return Theme
