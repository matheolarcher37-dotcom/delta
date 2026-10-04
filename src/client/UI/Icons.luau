-- Icônes vectorielles dessinées avec des Frames (aucune image importée) : blanches avec une
-- ombre douce, détails « encre » de la couleur du bouton, comme les icônes plates des jeux de
-- référence (calendrier, chevrons, boutique, unité, sac, livre, couronne...).
--
-- Icons.make("shop", parent, { px = 48, color = blanc, ink = couleurSombre, shadow = true })
-- Coordonnées des formes : centre (x, y) et taille (w, h) entre 0 et 1 dans un carré.

local Theme = require(script.Parent.Theme)

local Icons = {}

local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

-- Formes : { k = "r" (rectangle) | "c" (cercle) | "o" (anneau) | "t" (texte), x, y, w, h,
--            rot (degrés), rad (arrondi 0-0,5), ink (couleur de détail), th (épaisseur anneau) }
local function r(x, y, w, h, rad, rot, ink)
	return { k = "r", x = x, y = y, w = w, h = h, rad = rad or 0, rot = rot or 0, ink = ink }
end
local function c(x, y, d, ink)
	return { k = "c", x = x, y = y, w = d, h = d, ink = ink }
end
local function o(x, y, d, th, ink)
	return { k = "o", x = x, y = y, w = d, h = d, th = th, ink = ink }
end
local function t(x, y, s, text, ink)
	return { k = "t", x = x, y = y, w = s, h = s, text = text, ink = ink }
end
local I = true -- détail à l'encre

local SHAPES: { [string]: { any } } = {
	calendar = {
		r(0.5, 0.58, 0.82, 0.7, 0.16),
		r(0.5, 0.36, 0.82, 0.06, 0, 0, I),
		r(0.3, 0.2, 0.1, 0.2, 0.5),
		r(0.7, 0.2, 0.1, 0.2, 0.5),
		r(0.3, 0.55, 0.12, 0.1, 0.25, 0, I),
		r(0.5, 0.55, 0.12, 0.1, 0.25, 0, I),
		r(0.7, 0.55, 0.12, 0.1, 0.25, 0, I),
		r(0.3, 0.74, 0.12, 0.1, 0.25, 0, I),
		r(0.5, 0.74, 0.12, 0.1, 0.25, 0, I),
	},
	upgrade = {
		r(0.33, 0.27, 0.42, 0.15, 0.5, -36),
		r(0.67, 0.27, 0.42, 0.15, 0.5, 36),
		r(0.33, 0.5, 0.42, 0.15, 0.5, -36),
		r(0.67, 0.5, 0.42, 0.15, 0.5, 36),
		r(0.33, 0.73, 0.42, 0.15, 0.5, -36),
		r(0.67, 0.73, 0.42, 0.15, 0.5, 36),
	},
	shop = {
		r(0.5, 0.68, 0.7, 0.44, 0.1),
		r(0.5, 0.27, 0.86, 0.2, 0.3),
		c(0.18, 0.4, 0.22),
		c(0.39, 0.4, 0.22),
		c(0.61, 0.4, 0.22),
		c(0.82, 0.4, 0.22),
		r(0.5, 0.78, 0.22, 0.26, 0.3, 0, I),
		r(0.3, 0.6, 0.1, 0.03, 0, 0, I),
		r(0.7, 0.6, 0.1, 0.03, 0, 0, I),
	},
	unit = {
		c(0.5, 0.31, 0.38),
		r(0.5, 0.8, 0.74, 0.38, 0.45),
	},
	team = {
		c(0.66, 0.32, 0.3),
		r(0.68, 0.76, 0.5, 0.36, 0.45),
		c(0.36, 0.36, 0.34),
		r(0.36, 0.8, 0.6, 0.38, 0.45),
	},
	bag = {
		o(0.5, 0.2, 0.32, 0.08),
		r(0.5, 0.6, 0.7, 0.72, 0.28),
		r(0.5, 0.72, 0.44, 0.26, 0.3, 0, I),
		r(0.5, 0.42, 0.44, 0.05, 0.5, 0, I),
	},
	book = {
		r(0.52, 0.5, 0.64, 0.8, 0.12),
		r(0.3, 0.5, 0.06, 0.8, 0, 0, I),
		r(0.56, 0.32, 0.3, 0.07, 0.5, 0, I),
		r(0.56, 0.46, 0.3, 0.07, 0.5, 0, I),
		r(0.55, 0.82, 0.48, 0.05, 0.5, 0, I),
	},
	crown = {
		r(0.5, 0.74, 0.74, 0.16, 0.3),
		r(0.5, 0.6, 0.66, 0.2, 0),
		r(0.2, 0.5, 0.24, 0.24, 0.1, 45),
		r(0.5, 0.42, 0.26, 0.26, 0.1, 45),
		r(0.8, 0.5, 0.24, 0.24, 0.1, 45),
		c(0.2, 0.33, 0.13),
		c(0.5, 0.24, 0.13),
		c(0.8, 0.33, 0.13),
		c(0.5, 0.74, 0.1, I),
	},
	fusion = {
		o(0.37, 0.5, 0.5, 0.11),
		o(0.63, 0.5, 0.5, 0.11),
		r(0.5, 0.18, 0.06, 0.16, 0.5),
		r(0.5, 0.18, 0.16, 0.06, 0.5),
	},
	gem = {
		r(0.5, 0.34, 0.7, 0.2, 0.12),
		r(0.5, 0.52, 0.5, 0.5, 0.08, 45),
		r(0.5, 0.36, 0.08, 0.12, 0, 0, I),
		r(0.34, 0.36, 0.06, 0.12, 0, 0, I),
		r(0.66, 0.36, 0.06, 0.12, 0, 0, I),
	},
	forge = {
		r(0.38, 0.56, 0.12, 0.58, 0.4, 40),
		r(0.6, 0.32, 0.5, 0.22, 0.2, 40),
		r(0.5, 0.86, 0.76, 0.1, 0.4),
		r(0.5, 0.78, 0.42, 0.1, 0.2),
	},
	evolve = {
		o(0.5, 0.5, 0.86, 0.08),
		r(0.5, 0.6, 0.16, 0.42, 0.4),
		r(0.4, 0.38, 0.32, 0.14, 0.5, -45),
		r(0.6, 0.38, 0.32, 0.14, 0.5, 45),
	},
	guide = {
		o(0.5, 0.5, 0.86, 0.08),
		t(0.5, 0.52, 0.66, "?"),
	},
	sword = {
		r(0.58, 0.42, 0.13, 0.66, 0.4, 45),
		r(0.3, 0.7, 0.4, 0.1, 0.5, -45),
		r(0.22, 0.78, 0.1, 0.24, 0.4, 45),
		c(0.15, 0.85, 0.12),
	},
	hourglass = {
		r(0.5, 0.13, 0.68, 0.1, 0.5),
		r(0.5, 0.87, 0.68, 0.1, 0.5),
		r(0.5, 0.32, 0.38, 0.38, 0.12, 45),
		r(0.5, 0.68, 0.38, 0.38, 0.12, 45),
		r(0.5, 0.72, 0.18, 0.18, 0.1, 45, I),
	},
	dice = {
		r(0.5, 0.5, 0.8, 0.8, 0.22),
		c(0.3, 0.3, 0.15, I),
		c(0.7, 0.3, 0.15, I),
		c(0.5, 0.5, 0.15, I),
		c(0.3, 0.7, 0.15, I),
		c(0.7, 0.7, 0.15, I),
	},
	target = {
		c(0.5, 0.5, 0.88),
		c(0.5, 0.5, 0.64, I),
		c(0.5, 0.5, 0.42),
		c(0.5, 0.5, 0.18, I),
	},
	gift = {
		r(0.5, 0.65, 0.72, 0.5, 0.1),
		r(0.5, 0.36, 0.84, 0.18, 0.12),
		r(0.5, 0.6, 0.12, 0.6, 0, 0, I),
		c(0.38, 0.2, 0.2),
		c(0.62, 0.2, 0.2),
	},
	lock = {
		o(0.5, 0.36, 0.42, 0.1),
		r(0.5, 0.68, 0.7, 0.5, 0.18),
		c(0.5, 0.64, 0.14, I),
		r(0.5, 0.74, 0.06, 0.14, 0.3, 0, I),
	},
	close = {
		r(0.5, 0.5, 0.86, 0.2, 0.5, 45),
		r(0.5, 0.5, 0.86, 0.2, 0.5, -45),
	},
	home = {
		r(0.5, 0.68, 0.62, 0.48, 0.08),
		r(0.32, 0.38, 0.52, 0.15, 0.5, -38),
		r(0.68, 0.38, 0.52, 0.15, 0.5, 38),
		r(0.5, 0.78, 0.2, 0.28, 0.25, 0, I),
	},
	pin = {
		r(0.5, 0.6, 0.38, 0.38, 0.1, 45),
		c(0.5, 0.38, 0.6),
		c(0.5, 0.38, 0.24, I),
	},
	swap = {
		r(0.44, 0.33, 0.6, 0.12, 0.5),
		r(0.72, 0.26, 0.26, 0.11, 0.5, 40),
		r(0.72, 0.4, 0.26, 0.11, 0.5, -40),
		r(0.56, 0.67, 0.6, 0.12, 0.5),
		r(0.28, 0.6, 0.26, 0.11, 0.5, -40),
		r(0.28, 0.74, 0.26, 0.11, 0.5, 40),
	},
	clover = {
		c(0.36, 0.36, 0.34),
		c(0.64, 0.36, 0.34),
		c(0.36, 0.62, 0.34),
		c(0.64, 0.62, 0.34),
		r(0.6, 0.84, 0.08, 0.3, 0.5, -30),
	},
	skull = {
		c(0.5, 0.42, 0.7),
		r(0.5, 0.72, 0.42, 0.3, 0.2),
		c(0.36, 0.44, 0.18, I),
		c(0.64, 0.44, 0.18, I),
		r(0.44, 0.8, 0.05, 0.14, 0, 0, I),
		r(0.56, 0.8, 0.05, 0.14, 0, 0, I),
	},
	grid = {
		r(0.3, 0.3, 0.34, 0.34, 0.25),
		r(0.7, 0.3, 0.34, 0.34, 0.25),
		r(0.3, 0.7, 0.34, 0.34, 0.25),
		r(0.7, 0.7, 0.34, 0.34, 0.25),
	},
	heart = {
		c(0.34, 0.38, 0.4),
		c(0.66, 0.38, 0.4),
		r(0.5, 0.58, 0.48, 0.48, 0.08, 45),
	},
	coin = {
		c(0.5, 0.5, 0.9),
		o(0.5, 0.5, 0.64, 0.07, I),
		t(0.5, 0.52, 0.5, "$", I),
	},
	bolt = {
		r(0.56, 0.3, 0.2, 0.48, 0.1, 22),
		r(0.44, 0.7, 0.2, 0.48, 0.1, 22),
		r(0.5, 0.5, 0.5, 0.14, 0.1, -10),
	},
	star = {
		r(0.5, 0.5, 0.2, 0.86, 0.5, 0),
		r(0.5, 0.5, 0.2, 0.86, 0.5, 72),
		r(0.5, 0.5, 0.2, 0.86, 0.5, 144),
		r(0.5, 0.5, 0.2, 0.86, 0.5, 216),
		r(0.5, 0.5, 0.2, 0.86, 0.5, 288),
		c(0.5, 0.5, 0.4),
	},
	play = {
		r(0.42, 0.34, 0.5, 0.16, 0.5, 33),
		r(0.42, 0.66, 0.5, 0.16, 0.5, -33),
		r(0.24, 0.5, 0.16, 0.5, 0.5),
	},
	chart = {
		r(0.24, 0.66, 0.16, 0.4, 0.2),
		r(0.5, 0.54, 0.16, 0.64, 0.2),
		r(0.76, 0.42, 0.16, 0.88, 0.2),
	},
	boot = {
		r(0.42, 0.42, 0.3, 0.6, 0.2),
		r(0.56, 0.78, 0.66, 0.24, 0.5),
	},
	eye = {
		r(0.5, 0.5, 0.86, 0.5, 0.5),
		c(0.5, 0.5, 0.36, I),
		c(0.5, 0.5, 0.14),
	},
	shield = {
		r(0.5, 0.36, 0.72, 0.46, 0.18),
		r(0.5, 0.58, 0.5, 0.5, 0.1, 45),
		r(0.5, 0.52, 0.1, 0.5, 0, 0, I),
	},
	robot = {
		r(0.5, 0.56, 0.74, 0.58, 0.22),
		c(0.36, 0.54, 0.16, I),
		c(0.64, 0.54, 0.16, I),
		r(0.5, 0.2, 0.06, 0.16, 0),
		c(0.5, 0.12, 0.14),
	},
	fast = {
		r(0.3, 0.36, 0.38, 0.14, 0.5, 36),
		r(0.3, 0.64, 0.38, 0.14, 0.5, -36),
		r(0.62, 0.36, 0.38, 0.14, 0.5, 36),
		r(0.62, 0.64, 0.38, 0.14, 0.5, -36),
	},
}

-- Correspondance emoji -> icône (pour les nœuds de l'arbre et les données qui donnent un emoji).
Icons.FromEmoji = {
	["🍀"] = "clover",
	["🌈"] = "star",
	["🔟"] = "dice",
	["🧬"] = "gem",
	["⏩"] = "fast",
	["👥"] = "team",
	["🎲"] = "dice",
	["⚡"] = "bolt",
	["🤖"] = "robot",
	["💰"] = "coin",
	["👑"] = "crown",
	["🪙"] = "coin",
	["📈"] = "chart",
	["⚔️"] = "sword",
	["💥"] = "star",
	["💨"] = "fast",
	["🎯"] = "target",
	["💢"] = "target",
	["🗡️"] = "sword",
	["🔷"] = "grid",
	["🏯"] = "home",
	["👟"] = "boot",
	["🛡️"] = "shield",
	["👁️"] = "eye",
	["✨"] = "star",
}

function Icons.has(name: string): boolean
	return SHAPES[name] ~= nil
end

local function drawShape(holder: Frame, shape, color: Color3, ink: Color3, px: number, z: number, transparency: number)
	local fill = shape.ink and ink or color
	if shape.k == "t" then
		local label = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(shape.x, shape.y),
			Size = UDim2.fromScale(shape.w, shape.h),
			BackgroundTransparency = 1,
			Text = shape.text,
			TextScaled = true,
			FontFace = Theme.Faces.Heavy,
			TextColor3 = fill,
			TextTransparency = transparency,
			ZIndex = z,
			Parent = holder,
		})
		return label
	end
	local frame = new("Frame", {
		Name = shape.ink and "Ink" or "Shape",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(shape.x, shape.y),
		Size = UDim2.fromScale(shape.w, shape.h),
		Rotation = shape.rot or 0,
		BackgroundColor3 = fill,
		BackgroundTransparency = shape.k == "o" and 1 or transparency,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = holder,
	})
	if shape.k == "c" or shape.k == "o" then
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	elseif (shape.rad or 0) > 0 then
		new("UICorner", { CornerRadius = UDim.new(shape.rad, 0), Parent = frame })
	end
	if shape.k == "o" then
		new("UIStroke", {
			Color = fill,
			Thickness = math.max(1, (shape.th or 0.08) * px),
			Transparency = transparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
	end
	return frame
end

export type IconOptions = {
	px: number?, -- taille approximative en pixels (épaisseur des anneaux)
	color: Color3?,
	ink: Color3?,
	shadow: boolean?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zindex: number?,
	name: string?,
}

-- Dessine l'icône `name` dans un cadre carré. Si l'icône n'existe pas, `name` est affiché
-- comme texte (emoji ou caractère), ce qui sert de repli pour les données externes.
function Icons.make(name: string, parent: Instance, options: IconOptions?): Frame
	local opts = options or {}
	local px = opts.px or 40
	local z = opts.zindex or 3
	local holder = new("Frame", {
		Name = opts.name or ("Icon_" .. name),
		AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5),
		Position = opts.position or UDim2.fromScale(0.5, 0.5),
		Size = opts.size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = holder })
	local key = SHAPES[name] and name or Icons.FromEmoji[name]
	local shapes = key and SHAPES[key]
	if not shapes then
		Theme.label({
			Text = name,
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = opts.color or WHITE,
			ZIndex = z,
			StrokeThickness = 1.5,
			Parent = holder,
		})
		return holder
	end
	local color = opts.color or WHITE
	local ink = opts.ink or Color3.fromRGB(40, 40, 60)
	if opts.shadow ~= false then
		local shadow = new("Frame", {
			Name = "IconShadow",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.035, 0.05),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = holder,
		})
		for _, shape in shapes do
			if not shape.ink then
				drawShape(shadow, shape, Color3.new(0, 0, 0), Color3.new(0, 0, 0), px, z, 0.62)
			end
		end
	end
	for _, shape in shapes do
		drawShape(holder, shape, color, ink, px, z + (shape.ink and 1 or 0), 0)
	end
	return holder
end

-- Recolore une icône existante (sauf les détails « encre »).
function Icons.recolor(holder: Instance, color: Color3)
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") and child.Name == "Shape" then
			if child.BackgroundTransparency < 1 then
				child.BackgroundColor3 = color
			end
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = color
			end
		end
	end
end

return Icons
