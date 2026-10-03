-- "Peintre" : dessine les textures des persos avec des SurfaceGui (aucun asset à importer),
-- à la manière des vêtements classiques Roblox (Shirt / Pants) :
--   * visage d'animé fin (yeux en amande, iris en dégradé à deux reflets, cils épais, sourcils...) ;
--   * tenue peinte sur TOUTES les faces visibles du torse, des bras et des jambes : ombrages
--     (dégradés, bords assombris), plis, coutures, poches, fermetures éclair, cols en fourrure,
--     poignets, bandages, chaussures et sandales...
-- Tout est en coordonnées relatives (0 à 1) sur chaque face, les épaisseurs en studs.
--
-- Deux modes :
--   * SurfaceGui (dans le monde) : rendu complet ;
--   * "parts" (aperçus des menus, où les SurfaceGui ne s'affichent pas) : mêmes dessins en fines
--     pièces, niveau de détail "lite" (les détails marqués `fine` sont omis).

local Painter = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(28, 22, 30)
local MOUTH = Color3.fromRGB(110, 26, 38)
local TONGUE = Color3.fromRGB(235, 110, 120)
local METAL = Color3.fromRGB(200, 205, 215)
local DEFAULT_SKIN = Color3.fromRGB(255, 216, 180)

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Ombre "colorée" (plus belle qu'un simple noir) : on assombrit vers un violet profond.
local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.fromRGB(40, 20, 45), amount)
end

local function has(look, accessory: string): boolean
	return look.accessories ~= nil and table.find(look.accessories, accessory) ~= nil
end
Painter.has = has
Painter.darken = darken
Painter.lighten = lighten

export type RectOptions = {
	rotation: number?,
	corner: number?,
	transparency: number?,
	gradient: { Color3 }?, -- couleurs du dégradé (régulièrement espacées)
	gradientRotation: number?,
	fade: { number }?, -- transparences du dégradé (régulièrement espacées)
	stroke: Color3?,
	strokeThickness: number?,
	z: number?,
	anchor: Vector2?,
	fine: boolean?, -- détail fin : omis dans les aperçus "pièces"
	base: boolean?, -- fond d'une face : omis en "pièces" si la pièce a déjà cette couleur
}

------------------------------------------------------------------------
-- Toile "pièces" : même dessin, mais en fines pièces 3D (visible dans les ViewportFrame
-- des menus, où les SurfaceGui ne s'affichent pas). Gère les 4 faces latérales.
------------------------------------------------------------------------

-- Pour chaque face : direction "droite" de la toile (u) et normale sortante.
local FACE_AXES = {
	-- (clés = noms des faces : les EnumItem ne sont pas des clés fiables hors de Roblox)
	Front = { Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) },
	Back = { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) },
	Right = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) },
	Left = { Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) },
}

-- Taille (en studs) d'une face d'une pièce.
local function faceSize(size: Vector3, face: Enum.NormalId): (number, number)
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return size.Z, size.Y
	elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		return size.X, size.Z
	end
	return size.X, size.Y
end
Painter.faceSize = faceSize

local PartCanvas = {}
PartCanvas.__index = PartCanvas

function PartCanvas.new(part: BasePart, face: Enum.NormalId)
	local axes = FACE_AXES[face.Name] or FACE_AXES.Front
	local u, n = axes[1], axes[2]
	local size = part.Size
	local w, h = faceSize(size, face)
	local half = math.abs(n.X * size.X + n.Y * size.Y + n.Z * size.Z) / 2
	local frame = CFrame.fromMatrix(n * half, u, Vector3.new(0, 1, 0))
	return setmetatable({ part = part, frame = frame, w = w, h = h, count = 0 }, PartCanvas)
end

function PartCanvas:piece(x: number, y: number, w: number, h: number, rotation: number, layer: number, color: Color3, transparency: number, round: boolean)
	local depth = 0.004 + layer * 0.0035
	local base = self.part
	local piece = Instance.new("Part")
	piece.Name = "Paint"
	piece.Size = Vector3.new(math.max(w * self.w, 0.01), math.max(h * self.h, 0.01), 0.01)
	piece.CFrame = base.CFrame * self.frame * CFrame.new((x - 0.5) * self.w, (0.5 - y) * self.h, depth) * CFrame.Angles(0, 0, -math.rad(rotation))
	piece.Color = color
	piece.Transparency = transparency
	piece.Material = Enum.Material.SmoothPlastic
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Massless = true
	piece.Anchored = base.Anchored
	if round then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = piece
	end
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = piece
	weld.C0 = base.CFrame:Inverse() * piece.CFrame
	weld.Parent = piece
	piece.Parent = base.Parent
	self.count += 1
	return piece
end

local function average(values: { number }): number
	local sum = 0
	for _, v in values do
		sum += v
	end
	return sum / math.max(1, #values)
end

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.06
end

function PartCanvas:rect(x: number, y: number, w: number, h: number, color: Color3, o)
	if o.fine then
		return nil
	end
	local rotation = o.rotation or 0
	if rotation == 0 then
		-- Découpe aux bords de la face (comme ClipsDescendants).
		local x0, x1 = math.max(x - w / 2, 0), math.min(x + w / 2, 1)
		local y0, y1 = math.max(y - h / 2, 0), math.min(y + h / 2, 1)
		if x1 <= x0 or y1 <= y0 then
			return nil
		end
		x, w, y, h = (x0 + x1) / 2, x1 - x0, (y0 + y1) / 2, y1 - y0
	end
	if o.gradient then
		color = o.gradient[math.ceil(#o.gradient / 2)]
	end
	if o.base and close(color, self.part.Color) then
		return nil
	end
	local layer = o.z or 1
	local transparency = o.transparency or 0
	if o.fade then
		transparency = 1 - (1 - transparency) * (1 - average(o.fade))
		if transparency > 0.6 then
			return nil
		end
	end
	local round = (o.corner or 0) >= 0.3
	-- Niveau de détail lite : pas de contour sur les grandes formes (une pièce de moins).
	if o.stroke and (w * self.w > 0.45 or h * self.h > 0.45) and transparency < 0.95 then
		o = table.clone(o)
		o.stroke = nil
	end
	if o.stroke then
		local pad = (o.strokeThickness or 1.5) * 0.006
		local padX, padY = pad / self.w, pad / self.h
		if transparency >= 0.95 then
			-- Anneau seul : petits points le long du contour.
			local n = 22
			for i = 0, n - 1 do
				local a = i / n * math.pi * 2
				local px, py = x + w / 2 * math.cos(a), y + h / 2 * math.sin(a)
				self:piece(px, py, padX * 2.4, padY * 2.4, 0, layer, o.stroke, 0, true)
			end
			return nil
		end
		self:piece(x, y, w + padX * 2, h + padY * 2, rotation, layer - 0.5, o.stroke, 0, round)
	end
	if transparency >= 0.98 then
		return nil
	end
	return self:piece(x, y, w, h, rotation, layer, color, transparency, round)
end

-- Rectangle centré en (x, y), taille (w, h), en coordonnées relatives.
-- `parent` est soit un objet d'interface (SurfaceGui...), soit une toile "pièces".
local function rect(parent: any, x: number, y: number, w: number, h: number, color: Color3, opts: RectOptions?): any
	local o = opts or {}
	if type(parent) == "table" then
		return parent:rect(x, y, w, h, color, o)
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = o.anchor or Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = o.transparency or 0
	frame.BorderSizePixel = 0
	frame.Rotation = o.rotation or 0
	frame.ZIndex = o.z or 1
	if o.corner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(o.corner, 0)
		corner.Parent = frame
	end
	if o.gradient or o.fade then
		local gradient = Instance.new("UIGradient")
		if o.gradient then
			-- La couleur d'un UIGradient est MULTIPLIÉE par BackgroundColor3 : fond blanc.
			frame.BackgroundColor3 = WHITE
			local keys = {}
			for i, c in o.gradient do
				table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #o.gradient - 1), c))
			end
			if #keys == 1 then
				table.insert(keys, ColorSequenceKeypoint.new(1, o.gradient[1]))
			end
			gradient.Color = ColorSequence.new(keys)
		end
		if o.fade then
			local keys = {}
			for i, t in o.fade do
				table.insert(keys, NumberSequenceKeypoint.new((i - 1) / math.max(1, #o.fade - 1), t))
			end
			if #keys == 1 then
				table.insert(keys, NumberSequenceKeypoint.new(1, o.fade[1]))
			end
			gradient.Transparency = NumberSequence.new(keys)
		end
		gradient.Rotation = o.gradientRotation or 90
		gradient.Parent = frame
	end
	if o.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = o.stroke
		stroke.Thickness = o.strokeThickness or 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end
	frame.Parent = parent
	return frame
end
Painter.rect = rect

------------------------------------------------------------------------
-- Feuilles : une face peinte, avec des aides en studs (traits, points, boîtes).
------------------------------------------------------------------------

local Sheet = {}
Sheet.__index = Sheet

local function newSheet(g: any, w: number, h: number)
	return setmetatable({ g = g, w = w, h = h, lite = type(g) == "table" }, Sheet)
end

-- Rectangle en coordonnées relatives.
function Sheet:rect(x: number, y: number, w: number, h: number, color: Color3, o: RectOptions?)
	return rect(self.g, x, y, w, h, color, o)
end

-- Boîte centrée en (x, y) relatifs, taille en studs.
function Sheet:box(x: number, y: number, ws: number, hs: number, color: Color3, o: RectOptions?)
	return rect(self.g, x, y, ws / self.w, hs / self.h, color, o)
end

-- Disque / ellipse (diamètres en studs).
function Sheet:oval(x: number, y: number, ws: number, hs: number, color: Color3, o: RectOptions?)
	local opts = table.clone(o or {})
	opts.corner = 0.5
	return rect(self.g, x, y, ws / self.w, hs / self.h, color, opts)
end

-- Trait de (x0, y0) à (x1, y1) (relatifs), épaisseur en studs, bouts arrondis.
function Sheet:line(x0: number, y0: number, x1: number, y1: number, th: number, color: Color3, o: RectOptions?)
	local dx, dy = (x1 - x0) * self.w, (y1 - y0) * self.h
	local len = math.sqrt(dx * dx + dy * dy)
	local opts = table.clone(o or {})
	opts.rotation = math.deg(math.atan2(dy, dx))
	if opts.corner == nil then
		opts.corner = 0.5
	end
	return rect(self.g, (x0 + x1) / 2, (y0 + y1) / 2, len / self.w, th / self.h, color, opts)
end

-- Décalages en studs -> coordonnées relatives.
function Sheet:dx(studs: number): number
	return studs / self.w
end

function Sheet:dy(studs: number): number
	return studs / self.h
end

local function surface(part: BasePart, face: Enum.NormalId, name: string, pixelsPerStud: number, mode: string?): any
	if mode == "parts" then
		return PartCanvas.new(part, face)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 1
	gui.MaxDistance = 140
	gui.ClipsDescendants = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	return gui
end

-- Feuille peinte sur une face d'une pièce (SurfaceGui, ou pièces fines si mode == "parts").
function Painter.sheet(part: BasePart, face: Enum.NormalId, mode: string?, name: string?, pixelsPerStud: number?)
	local w, h = faceSize(part.Size, face)
	return newSheet(surface(part, face, name or ("Paint" .. face.Name), pixelsPerStud or 70, mode), w, h)
end

-- Ancienne API : toile brute (utilisée par les motifs des accessoires).
function Painter.canvas(part: BasePart, face: Enum.NormalId)
	return PartCanvas.new(part, face)
end

-- Convertit une SurfaceGui en fines pièces : sert aux aperçus des menus
-- (les ViewportFrame n'affichent pas les SurfaceGui). Gère les Frame en coordonnées "Scale".
function Painter.bakeToParts(gui: SurfaceGui)
	local part = (gui.Adornee or gui.Parent) :: any
	if not part or not part:IsA("BasePart") or not FACE_AXES[gui.Face.Name] then
		gui:Destroy()
		return
	end
	local canvas = PartCanvas.new(part, gui.Face)
	local function absolute(frame: GuiObject): (number, number, number, number)
		local parent = frame.Parent
		local px, py, pw, ph = 0, 0, 1, 1
		if parent and parent:IsA("GuiObject") then
			px, py, pw, ph = absolute(parent)
		end
		local w, h = frame.Size.X.Scale * pw, frame.Size.Y.Scale * ph
		local x = px + frame.Position.X.Scale * pw - frame.AnchorPoint.X * w
		local y = py + frame.Position.Y.Scale * ph - frame.AnchorPoint.Y * h
		return x, y, w, h
	end
	for _, frame in gui:GetDescendants() do
		if frame:IsA("Frame") and frame.Visible then
			local x, y, w, h = absolute(frame)
			local corner = frame:FindFirstChildOfClass("UICorner")
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			local gradient = frame:FindFirstChildOfClass("UIGradient")
			local color = frame.BackgroundColor3
			local transparency = frame.BackgroundTransparency
			if gradient then
				local keys = gradient.Color.Keypoints
				local mid = keys[math.ceil(#keys / 2)].Value
				color = Color3.new(color.R * mid.R, color.G * mid.G, color.B * mid.B)
				local sum, n = 0, 0
				for _, key in gradient.Transparency.Keypoints do
					sum += key.Value
					n += 1
				end
				transparency = 1 - (1 - transparency) * (1 - sum / math.max(1, n))
			end
			local radius = nil
			if corner then
				local ok, value = pcall(function()
					return corner.CornerRadius.Scale
				end)
				if not ok then
					-- Fichiers récents : arrondi enregistré coin par coin.
					ok, value = pcall(function()
						return (corner :: any).TopLeftRadius.Scale
					end)
				end
				radius = ok and value or 0.5
			end
			if transparency < 0.6 then
				canvas:rect(x + w / 2, y + h / 2, w, h, color, {
					rotation = frame.Rotation,
					corner = radius,
					transparency = transparency,
					stroke = stroke and stroke.Color or nil,
					strokeThickness = stroke and stroke.Thickness or nil,
					z = frame.ZIndex,
				})
			end
		end
	end
	gui:Destroy()
end

------------------------------------------------------------------------
-- Visage (face avant plate de la tête)
------------------------------------------------------------------------

-- Inclinaison des paupières et des sourcils (degrés, positif = air sévère).
local LID_TILT = { angry = 9, fierce = 5, happy = -3, calm = 0, smirk = 2 }
local BROW_TILT = { angry = 17, fierce = 10, happy = -7, calm = -2, smirk = 0 }

local function eye(S, look, cx: number, cy: number, s: number, big: number?)
	local k = (big or 1) * 1.2
	local iris = look.eyes or Color3.fromRGB(80, 55, 40)
	local face = look.face or "calm"
	local lash = look.lashColor or INK
	local rot = -s * (LID_TILT[face] or 0)
	local W, H = 0.235 * k, 0.16 * k
	local function at(dx: number, dy: number): (number, number)
		-- décalage (studs) dans le repère incliné de l'œil
		local a = math.rad(rot)
		local rx = dx * math.cos(a) - dy * math.sin(a)
		local ry = dx * math.sin(a) + dy * math.cos(a)
		return cx + rx / S.w, cy + ry / S.h
	end
	if look.eyeShadow then
		-- Pigments autour des yeux (mode Ermite...)
		local x, y = at(s * 0.015, -0.01)
		S:oval(x, y, W * 1.55, H * 1.9, look.eyeShadow, { rotation = rot, fade = { 0.05, 0.25, 0.7 }, gradientRotation = 90, z = 1 })
	end
	-- Blanc de l'œil (ombre de la paupière en haut)
	S:oval(cx, cy, W, H, WHITE, { rotation = rot, gradient = { Color3.fromRGB(205, 210, 235), WHITE, WHITE }, z = 2 })
	-- Iris en dégradé (sombre en haut, clair en bas), cerclé, qui passe sous le trait de cils
	local ix, iy = at(0, 0.006 * k)
	local IW, IH = 0.13 * k, 0.16 * k
	S:oval(ix, iy, IW, IH, iris, {
		gradient = { darken(iris, 0.6), darken(iris, 0.1), lighten(iris, 0.42) },
		stroke = darken(iris, 0.72),
		strokeThickness = 1,
		z = 3,
	})
	-- Pupille
	local pupil = darken(iris, 0.85)
	if look.pupil == "bar" then
		S:box(ix, iy, IW * 0.82, IH * 0.2, pupil, { corner = 0.3, z = 4 })
	elseif look.pupil == "slit" then
		S:oval(ix, iy, IW * 0.22, IH * 0.75, pupil, { z = 4 })
	elseif look.pupil == "ring" then
		S:oval(ix, iy, IW * 0.6, IH * 0.6, pupil, { transparency = 1, stroke = pupil, strokeThickness = 1.5, z = 4 })
		S:oval(ix, iy, IW * 0.22, IH * 0.22, pupil, { z = 4 })
	else
		S:oval(ix, iy - S:dy(0.012 * k), IW * 0.46, IH * 0.5, pupil, { z = 4 })
	end
	-- Ombre de la paupière sur le haut de l'iris
	local x, y = at(0, -H * 0.3)
	S:oval(x, y, W * 0.8, H * 0.3, darken(iris, 0.8), { rotation = rot, transparency = 0.65, z = 5, fine = true })
	-- Deux reflets
	S:oval(ix - S:dx(0.03 * k), iy - S:dy(0.034 * k), 0.056 * k, 0.056 * k, WHITE, { z = 6 })
	S:oval(ix + S:dx(0.032 * k), iy + S:dy(0.042 * k), 0.026 * k, 0.026 * k, WHITE, { transparency = 0.1, z = 6 })
	-- Trait de cils supérieur épais en 3 segments (forme en amande) qui recouvre le haut de l'œil
	local ly = -H * 0.47
	x, y = at(0, ly)
	S:box(x, y, W * 0.98, 0.048 * k, lash, { corner = 0.5, rotation = rot, z = 7 })
	local x0, y0 = at(s * W * 0.42, ly)
	local x1, y1 = at(s * W * 0.6, ly + H * 0.36)
	S:line(x0, y0, x1, y1, 0.044 * k, lash, { z = 7 })
	x0, y0 = at(-s * W * 0.42, ly)
	x1, y1 = at(-s * W * 0.52, ly + H * 0.22)
	S:line(x0, y0, x1, y1, 0.032 * k, lash, { z = 7 })
	if look.blush then
		-- Cils longs (persos féminins)
		x0, y0 = at(s * W * 0.46, ly)
		x1, y1 = at(s * (W * 0.64), ly - 0.05 * k)
		S:line(x0, y0, x1, y1, 0.026 * k, lash, { z = 7 })
		x1, y1 = at(s * (W * 0.56), ly - 0.085 * k)
		S:line(x0, y0, x1, y1, 0.02 * k, lash, { z = 7 })
	end
	-- Trait inférieur (moitié externe)
	x, y = at(s * W * 0.2, H * 0.5)
	S:box(x, y, W * 0.48, 0.016, lash, { corner = 0.5, rotation = rot, transparency = 0.25, z = 7 })
end

local function brows(S, look, skin: Color3, y: number)
	local face = look.face or "calm"
	local color = shade(look.browColor or look.hairColor or INK, 0.5)
	if look.hair == "bald" or look.hair == "none" then
		color = darken(skin, 0.45)
	end
	local thick = look.bigBrows and 0.075 or 0.042
	local width = look.bigBrows and 0.27 or 0.23
	for _, s in { -1, 1 } do
		local tilt = (BROW_TILT[face] or 0) * -s
		local by = y
		if face == "smirk" and s > 0 then
			by -= S:dy(0.04)
			tilt = -9
		end
		-- Sourcil effilé : plus épais côté intérieur
		S:box(0.5 + S:dx(s * 0.175), by, width, thick, color, {
			corner = 0.5,
			rotation = tilt,
			fade = s < 0 and { 0.55, 0 } or { 0, 0.55 },
			gradientRotation = 0,
			z = 8,
		})
	end
end

local function mouth(S, look, skin: Color3, y: number)
	local face = look.face or "calm"
	local lip = shade(skin, 0.45)
	if face == "happy" then
		-- Grand sourire ouvert en "D"
		S:oval(0.5, y, 0.24, 0.15, MOUTH, { stroke = darken(MOUTH, 0.4), strokeThickness = 1, z = 2 })
		S:box(0.5, y - S:dy(0.045), 0.27, 0.075, skin, { z = 3 })
		S:box(0.5, y - S:dy(0.002), 0.2, 0.026, WHITE, { corner = 0.3, z = 4 })
		S:oval(0.5, y + S:dy(0.04), 0.11, 0.045, TONGUE, { z = 4 })
		S:line(0.5 - S:dx(0.125), y - S:dy(0.012), 0.5 + S:dx(0.125), y - S:dy(0.012), 0.016, INK, { z = 5 })
	elseif face == "fierce" then
		-- Sourire confiant, dents serrées (comme la référence)
		S:box(0.5, y, 0.21, 0.07, WHITE, { corner = 0.35, stroke = INK, strokeThickness = 1.4, z = 2 })
		S:box(0.5, y, 0.19, 0.008, Color3.fromRGB(150, 140, 150), { z = 3 })
		for _, s in { -1, 1 } do
			S:line(0.5 + S:dx(s * 0.105), y - S:dy(0.03), 0.5 + S:dx(s * 0.13), y - S:dy(0.055), 0.016, INK, { z = 3 })
			S:box(0.5 + S:dx(s * 0.045), y, 0.006, 0.06, Color3.fromRGB(170, 160, 170), { z = 3, fine = true })
		end
	elseif face == "angry" then
		S:line(0.5 - S:dx(0.065), y, 0.5 + S:dx(0.065), y, 0.02, INK, { z = 2 })
		S:line(0.5 - S:dx(0.065), y, 0.5 - S:dx(0.09), y + S:dy(0.02), 0.018, INK, { z = 2 })
		S:line(0.5 + S:dx(0.065), y, 0.5 + S:dx(0.09), y + S:dy(0.02), 0.018, INK, { z = 2 })
		S:box(0.5, y + S:dy(0.035), 0.06, 0.012, lip, { corner = 0.5, transparency = 0.4, z = 2, fine = true })
	elseif face == "smirk" then
		S:line(0.5 - S:dx(0.07), y + S:dy(0.008), 0.5 + S:dx(0.06), y - S:dy(0.008), 0.02, INK, { z = 2 })
		S:line(0.5 + S:dx(0.06), y - S:dy(0.008), 0.5 + S:dx(0.095), y - S:dy(0.035), 0.018, INK, { z = 2 })
		S:box(0.5, y + S:dy(0.035), 0.05, 0.012, lip, { corner = 0.5, transparency = 0.4, z = 2, fine = true })
	else
		S:line(0.5 - S:dx(0.04), y, 0.5 + S:dx(0.04), y, 0.018, INK, { z = 2 })
		S:box(0.5, y + S:dy(0.03), 0.045, 0.012, lip, { corner = 0.5, transparency = 0.45, z = 2, fine = true })
	end
end

local function faceMarks(S, look, skin: Color3, eyeY: number)
	local accColor = look.accColor
	local gui = S.g
	local d = eyeY - 0.53 -- les marques suivent la hauteur des yeux
	if has(look, "whiskers") then
		for _, s in { -1, 1 } do
			for i = 0, 2 do
				local y = 0.7 + d + i * 0.045
				S:line(0.5 + s * 0.3, y + (i - 1) * 0.006, 0.5 + s * 0.44, y + (i - 1) * 0.022, 0.018, shade(skin, 0.6), { z = 7 })
			end
		end
	end
	if has(look, "tear_lines") then
		for _, s in { -1, 1 } do
			rect(gui, 0.5 + s * 0.14, 0.67 + d, 0.014, 0.12, shade(skin, 0.5), { corner = 0.5, rotation = s * 8, z = 7 })
		end
	end
	if has(look, "tattoos") then
		-- Deux traits sous chaque œil + marque sur le front
		for _, s in { -1, 1 } do
			for i = 0, 1 do
				S:line(0.5 + s * 0.12, 0.67 + d + i * 0.04, 0.5 + s * 0.38, 0.65 + d + i * 0.04, 0.02, INK, { z = 7 })
			end
		end
		rect(gui, 0.5, 0.07, 0.14, 0.022, INK, { corner = 0.5, z = 7 })
	end
	if has(look, "tattoos_blue") then
		local ink = accColor or Color3.fromRGB(60, 80, 220)
		for _, s in { -1, 1 } do
			rect(gui, 0.5 + s * 0.4, 0.5, 0.014, 0.6, ink, { z = 7 })
			rect(gui, 0.5 + s * 0.12, 0.1, 0.014, 0.16, ink, { z = 7 })
		end
	end
	if has(look, "extra_eyes") then
		-- Seconds yeux sous les yeux (fléau)
		for _, s in { -1, 1 } do
			local x, y = 0.5 + s * 0.27, 0.72 + d
			S:oval(x, y, 0.11, 0.05, WHITE, { z = 8 })
			S:oval(x, y, 0.05, 0.05, look.eyes or Color3.fromRGB(220, 20, 30), { z = 9 })
			S:box(x, y - S:dy(0.025), 0.13, 0.018, INK, { corner = 0.5, rotation = s * -6, z = 9 })
		end
	end
	if has(look, "scar_eye") then
		rect(gui, 0.71, 0.53 + d, 0.02, 0.36, Color3.fromRGB(150, 50, 50), { rotation = 8, z = 9 })
	end
	if has(look, "scar_cheek") then
		local red = Color3.fromRGB(150, 60, 60)
		S:line(0.2, 0.72 + d, 0.34, 0.72 + d, 0.014, red, { z = 8 })
		for i = -1, 1 do
			S:line(0.27 + i * 0.035, 0.7 + d, 0.27 + i * 0.035, 0.74 + d, 0.01, red, { z = 8 })
		end
	end
	if has(look, "scar_face") then
		rect(gui, 0.5, 0.6, 0.62, 0.02, Color3.fromRGB(160, 70, 70), { rotation = 22, z = 7 })
	end
	if has(look, "scar_forehead") then
		S:oval(0.33, 0.24, 0.14, 0.1, Color3.fromRGB(175, 65, 55), { transparency = 0.2, rotation = -15, z = 7 })
	end
	if has(look, "forehead_mark") then
		local red = Color3.fromRGB(205, 35, 30)
		S:oval(0.33, 0.25, 0.15, 0.1, red, { rotation = -15, z = 7 })
		S:line(0.28, 0.22, 0.24, 0.13, 0.04, red, { z = 7 })
		S:line(0.36, 0.22, 0.38, 0.12, 0.035, red, { z = 7 })
	end
	if has(look, "dots") then
		for row = 0, 1 do
			for col = -1, 1 do
				rect(gui, 0.5 + col * 0.07, 0.06 + row * 0.06, 0.03, 0.03, darken(skin, 0.4), { corner = 0.5, z = 7 })
			end
		end
	end
	if has(look, "facepaint") then
		local paint = accColor or Color3.fromRGB(140, 50, 180)
		for _, s in { -1, 1 } do
			rect(gui, 0.5 + s * 0.3, 0.68, 0.025, 0.22, paint, { corner = 0.5, z = 7 })
			rect(gui, 0.5 + s * 0.29, 0.22, 0.12, 0.02, paint, { corner = 0.5, z = 7 })
		end
	end
	if has(look, "stitches") then
		rect(gui, 0.5, 0.42, 0.7, 0.014, INK, { rotation = -28, z = 8 })
		for i = -3, 3 do
			rect(gui, 0.5 + i * 0.09, 0.42 - i * 0.048, 0.01, 0.05, INK, { rotation = -28, z = 8 })
		end
	end
	if has(look, "stitches_forehead") then
		rect(gui, 0.5, 0.07, 0.7, 0.014, INK, { z = 8 })
		for i = -3, 3 do
			rect(gui, 0.5 + i * 0.09, 0.07, 0.01, 0.05, INK, { z = 8 })
		end
	end
	if has(look, "glasses") then
		for _, s in { -1, 1 } do
			rect(gui, 0.5 + s * 0.21, eyeY, 0.31, 0.2, Color3.fromRGB(190, 225, 255), { corner = 0.3, transparency = 0.7, stroke = INK, strokeThickness = 2.2, z = 10 })
		end
		rect(gui, 0.5, eyeY - 0.04, 0.12, 0.02, INK, { z = 10 })
	end
	if look.blush then
		for _, s in { -1, 1 } do
			local x, y = 0.5 + s * 0.3, 0.7 + d
			S:oval(x, y, 0.16, 0.07, Color3.fromRGB(255, 120, 145), { fade = { 0.75, 0.35, 0.75 }, gradientRotation = 0, z = 1 })
			for i = -1, 1 do
				S:line(x + i * 0.05 - 0.012, y + 0.012, x + i * 0.05 + 0.012, y - 0.012, 0.01, Color3.fromRGB(230, 90, 110), { z = 2, fine = true })
			end
		end
	end
end

-- Dessine un visage d'animé sur la face avant de `part`.
function Painter.face(part: BasePart, look, mode: string?)
	if has(look, "boar_head") then
		return nil
	end
	local skin = look.skin or DEFAULT_SKIN
	local S = Painter.sheet(part, Enum.NormalId.Front, mode, "Face", 170)
	local hideEyes = has(look, "blindfold")
	local eyeY = 0.56
	-- Ombre portée de la frange / du bandeau sur le front
	if look.hair ~= "bald" and look.hair ~= "none" then
		S:oval(0.5, 0.06, 0.95, 0.3, shade(skin, 0.5), { fade = { 0.55, 1 }, gradientRotation = 90, z = 1, fine = true })
	end
	-- Joues légèrement ombrées vers le bas (volume)
	S:oval(0.5, 0.97, 0.9, 0.25, shade(skin, 0.4), { fade = { 1, 0.75 }, gradientRotation = 90, z = 1, fine = true })
	if not hideEyes then
		if has(look, "cyclops") then
			eye(S, look, 0.5, eyeY - 0.02, 1, 1.5)
		else
			eye(S, look, 0.5 - S:dx(0.2), eyeY, -1)
			eye(S, look, 0.5 + S:dx(0.2), eyeY, 1)
		end
		brows(S, look, skin, eyeY - S:dy(0.21))
	end
	-- Petit nez : ombre + reflet
	S:line(0.53, 0.68, 0.51, 0.715, 0.022, shade(skin, 0.45), { transparency = 0.25, z = 2 })
	S:oval(0.49, 0.7, 0.018, 0.018, lighten(skin, 0.5), { transparency = 0.3, z = 2, fine = true })
	if not has(look, "mask_lower") and not has(look, "muzzle") and not has(look, "mask_bandage") and not has(look, "collar_high") then
		mouth(S, look, skin, 0.83)
	end
	faceMarks(S, look, skin, eyeY)
	return S.g
end

------------------------------------------------------------------------
-- Symboles (logos)
------------------------------------------------------------------------

local function logo(gui: any, spec, x: number, y: number, size: number, aspect: number?)
	local color = spec.color or Color3.fromRGB(220, 40, 40)
	local ar = aspect or 1 -- largeur / hauteur de la face, pour garder des cercles ronds
	local sx, sy = size, size * ar
	if spec.kind == "spiral" then
		if spec.bg then
			rect(gui, x, y, sx, sy, spec.bg, { corner = 0.5, z = 6 })
		end
		rect(gui, x, y, sx * 0.72, sy * 0.72, spec.bg or WHITE, { corner = 0.5, stroke = color, strokeThickness = 5, transparency = spec.bg and 0 or 1, z = 7 })
		rect(gui, x, y, sx * 0.34, sy * 0.34, color, { corner = 0.5, z = 8 })
		rect(gui, x + sx * 0.18, y - sy * 0.05, sx * 0.1, sy * 0.34, color, { corner = 0.5, rotation = 30, z = 8 })
	elseif spec.kind == "fan" then
		rect(gui, x, y - sy * 0.12, sx * 0.8, sy * 0.4, color, { corner = 0.5, z = 7 })
		rect(gui, x, y + sy * 0.12, sx * 0.8, sy * 0.36, WHITE, { corner = 0.5, z = 7 })
		rect(gui, x, y + sy * 0.42, sx * 0.12, sy * 0.3, Color3.fromRGB(200, 200, 200), { z = 6 })
	elseif spec.kind == "circle" then
		rect(gui, x, y, sx, sy, WHITE, { corner = 0.5, transparency = 1, stroke = color, strokeThickness = 6, z = 7 })
	elseif spec.kind == "kanji" then
		rect(gui, x, y, sx, sy, spec.bg or WHITE, { corner = 0.5, stroke = darken(spec.bg or WHITE, 0.3), strokeThickness = 1, z = 7 })
		if type(gui) == "table" then
			-- Toile "pièces" : un simple trait épais à la place du caractère.
			rect(gui, x, y, sx * 0.5, sy * 0.12, color, { z = 8 })
			rect(gui, x, y, sx * 0.12, sy * 0.55, color, { z = 8 })
			return
		end
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(sx * 0.78, sy * 0.78)
		label.BackgroundTransparency = 1
		label.Text = spec.text or "力"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = color
		label.ZIndex = 8
		label.Parent = gui
	end
end
Painter.logo = logo

-- Nuage rouge (cape à nuages)
local function cloud(gui: any, x: number, y: number, s: number, color: Color3)
	for _, offset in { { -0.35, 0.1, 0.55 }, { 0, -0.12, 0.7 }, { 0.38, 0.08, 0.55 }, { 0.05, 0.18, 0.6 } } do
		rect(gui, x + offset[1] * s, y + offset[2] * s, offset[3] * s, offset[3] * s * 0.8, color, { corner = 0.5, stroke = WHITE, strokeThickness = 2, z = 6 })
	end
end

------------------------------------------------------------------------
-- Outils "vêtements" (style cel des vêtements classiques Roblox dessinés à la main) :
-- aplats d'ombre francs, traits d'encre, reflets sur les tissus sombres.
------------------------------------------------------------------------

local function luminance(color: Color3): number
	return 0.3 * color.R + 0.59 * color.G + 0.11 * color.B
end

-- Couleur de l'ombre franche d'un tissu (sur un tissu très sombre : un reflet bleuté).
local function celShadow(color: Color3): Color3
	if luminance(color) < 0.16 then
		return color:Lerp(Color3.fromRGB(95, 105, 135), 0.35)
	end
	return shade(color, 0.34)
end

-- Encre des plis et coutures.
local function inkOf(color: Color3): Color3
	if luminance(color) < 0.16 then
		return color:Lerp(Color3.fromRGB(150, 160, 190), 0.45)
	end
	return shade(color, 0.72)
end

-- Fond d'une face de vêtement : dégradé vertical (haut éclairé, bas plus sombre).
local function cloth(S, color: Color3, o)
	local opts = o or {}
	local top = opts.top or 0
	local bottom = opts.bottom or 1
	local h = bottom - top
	S:rect(0.5, top + h / 2, 1, h, color, {
		gradient = { lighten(color, 0.12), color, shade(color, 0.14) },
		z = opts.z or 0,
		base = top == 0 and bottom == 1,
	})
end

-- Ombre franche le long d'un bord vertical ("l" ou "r"), largeur relative.
local function edgeShade(S, side: string, w: number, color: Color3, top: number?, bottom: number?, z: number?)
	local t, b = top or 0, bottom or 1
	local x = side == "l" and w / 2 or 1 - w / 2
	S:rect(x, (t + b) / 2, w, b - t, celShadow(color), {
		fade = side == "l" and { 0.1, 0.1, 0.25, 1 } or { 1, 0.25, 0.1, 0.1 },
		gradientRotation = 0,
		z = z or 1,
		fine = true,
	})
end

-- Pli : trait d'encre (bouts estompés) + aplat d'ombre juste dessous qui s'estompe en s'éloignant.
local function fold(S, x0: number, y0: number, x1: number, y1: number, color: Color3, o)
	local opts = o or {}
	if x1 < x0 then
		x0, y0, x1, y1 = x1, y1, x0, y0
	end
	local z = opts.z or 3
	local w = opts.w or 0.16
	local dx, dy = (x1 - x0) * S.w, (y1 - y0) * S.h
	local len = math.max(math.sqrt(dx * dx + dy * dy), 1e-3)
	-- normale "vers le bas" du trait (en studs), convertie en relatif
	local ox, oy = -dy / len * w * 0.5 / S.w, dx / len * w * 0.5 / S.h
	S:line(x0 + ox, y0 + oy, x1 + ox, y1 + oy, w, celShadow(color), { fade = { 0.05, 0.35, 1 }, gradientRotation = 90, z = z, fine = true })
	-- Aperçus "pièces" (niveau de détail lite) : seuls les plis principaux sont gardés.
	local fine = opts.fine or (S.lite and w < 0.13)
	S:line(x0, y0, x1, y1, opts.ink or 0.022, inkOf(color), { fade = { 0.85, 0, 0, 0.85 }, gradientRotation = 0, z = z + 1, fine = fine })
end

-- Couture (trait fin).
local function seam(S, x0: number, y0: number, x1: number, y1: number, color: Color3, z: number?)
	S:line(x0, y0, x1, y1, 0.016, inkOf(color), { transparency = 0.35, corner = 0, z = z or 3, fine = true })
end

-- Bande horizontale (poignet, ceinture, ourlet) avec son volume et un trait d'encre dessous.
local function band(S, y: number, h: number, color: Color3, z: number?, ink: boolean?)
	local zz = z or 6
	S:rect(0.5, y, 1, h, color, { gradient = { lighten(color, 0.22), color, celShadow(color) }, z = zz })
	if ink ~= false then
		S:rect(0.5, y + h / 2, 1, S:dy(0.022), inkOf(color), { z = zz + 1 })
	end
end

-- Bande ombrée qui s'estompe vers le bas (ombre portée d'un col, d'un empiècement...).
local function castShadow(S, y: number, h: number, color: Color3, z: number?)
	S:rect(0.5, y + h / 2, 1, h, celShadow(color), { fade = { 0.15, 0.4, 1 }, gradientRotation = 90, z = z or 3, fine = true })
end

-- Col en fourrure : bande blanche au bord festonné de touffes, ombres bleutées.
local function furTrim(S, y: number, h: number, color: Color3, z: number?)
	local zz = z or 8
	local cool = color:Lerp(Color3.fromRGB(120, 140, 185), 0.45)
	S:rect(0.5, y, 1, h, color, { gradient = { WHITE, color, cool }, z = zz })
	local tuft = h * S.h * 1.05
	local n = math.max(3, math.floor(S.w / (tuft * 0.72) + 0.5))
	for i = 0, n - 1 do
		local x = (i + 0.5) / n
		local dy = (i % 2 == 0) and 0.25 or 0.42
		S:oval(x, y + h / 2 - S:dy(tuft * 0.1), tuft, tuft * 0.95, color, {
			gradient = { WHITE, color, cool },
			z = zz + 1,
		})
		if i % 2 == 0 then
			S:line(x + 0.18 / n, y + h / 2 + S:dy(tuft * (dy - 0.05)), x + 0.35 / n, y + h / 2 + S:dy(tuft * dy), 0.02, shade(cool, 0.25), { z = zz + 2, fine = true })
		end
	end
	castShadow(S, y + h / 2 + S:dy(tuft * 0.35), S:dy(0.16), S.under or color, zz - 3)
end

-- Fermeture éclair verticale avec tirette.
local function zipper(S, x: number, y0: number, y1: number, under: Color3, z: number?)
	local zz = z or 5
	S:box(x, (y0 + y1) / 2, 0.08, (y1 - y0) * S.h, inkOf(under), { z = zz })
	S:box(x, (y0 + y1) / 2, 0.032, (y1 - y0) * S.h, Color3.fromRGB(205, 208, 218), { gradient = { WHITE, METAL }, gradientRotation = 0, z = zz + 1 })
	S:box(x + S:dx(0.035), y0 + S:dy(0.1), 0.06, 0.13, METAL, { corner = 0.3, stroke = Color3.fromRGB(80, 80, 95), strokeThickness = 1, z = zz + 2 })
	S:oval(x + S:dx(0.035), y0 + S:dy(0.21), 0.08, 0.08, METAL, { transparency = 1, stroke = Color3.fromRGB(235, 235, 240), strokeThickness = 2, z = zz + 2, fine = true })
end

-- Poche à rabat.
local function pocket(S, x: number, y: number, ws: number, hs: number, color: Color3, z: number?)
	local zz = z or 5
	S:box(x, y, ws, hs, color, { gradient = { lighten(color, 0.1), celShadow(color) }, corner = 0.12, stroke = inkOf(color), strokeThickness = 1.2, z = zz })
	S:box(
		x,
		y - S:dy(hs * 0.3),
		ws * 1.06,
		hs * 0.42,
		color,
		{ gradient = { lighten(color, 0.18), color }, corner = 0.15, stroke = inkOf(color), strokeThickness = 1.2, z = zz + 1 }
	)
	S:oval(x, y - S:dy(hs * 0.18), 0.05, 0.05, METAL, { z = zz + 2, fine = true })
end

-- Bandage (bandes blanches qui se chevauchent).
local function bandage(S, y0: number, y1: number, z: number?, n: number?, color: Color3?)
	local zz = z or 6
	local wrap = color or Color3.fromRGB(238, 234, 226)
	local count = n or 3
	S:rect(0.5, (y0 + y1) / 2, 1, y1 - y0, wrap, { gradient = { WHITE, wrap, shade(wrap, 0.22) }, z = zz })
	for i = 1, count - 1 do
		local y = y0 + (y1 - y0) * i / count
		S:line(0, y + S:dy(0.03), 1, y - S:dy(0.03), 0.018, shade(wrap, 0.45), { corner = 0, transparency = 0.15, z = zz + 1, fine = true })
	end
	S:rect(0.5, y1, 1, S:dy(0.02), shade(wrap, 0.55), { z = zz + 1 })
end

------------------------------------------------------------------------
-- Manches, pantalons, chaussures (selon la tenue)
------------------------------------------------------------------------

-- Manches selon la tenue : "long" (par défaut), "short", "skin" (bras nus) ou "wide" (kimono).
local SLEEVES = {
	tank = "skin",
	shirtless = "skin",
	openvest = "skin",
	egyptian = "skin",
	qipao = "short",
	gi = "short",
	shirt = "short",
	striped = "short",
	overalls = "short",
	openshirt = "short",
	armor = "short",
	sailor = "short",
	highcollar = "long",
	chakra = "long",
	robe = "wide",
	kimono = "wide",
	openrobe = "wide",
}

function Painter.sleeves(look): string
	local outfit = look.outfit or (look.shirtless and "shirtless" or "shirt")
	local sleeves = look.sleeves or SLEEVES[outfit] or "long"
	if look.sleeveless or look.shirtless then
		sleeves = "skin"
	end
	return sleeves
end

-- Palette d'un look.
local function palette(look)
	local skin = look.skin or DEFAULT_SKIN
	local outfit = look.outfit or (look.shirtless and "shirtless" or "shirt")
	local top = (outfit == "shirtless") and skin or (look.top or WHITE)
	return {
		skin = skin,
		top = top,
		accent = look.topAccent or darken(top, 0.3),
		bottom = look.bottom or INK,
		shoes = look.shoes or Color3.fromRGB(45, 40, 45),
		acc = look.accColor,
		outfit = outfit,
		sleeves = Painter.sleeves(look),
		sleeve = look.sleeveColor or top,
		pants = look.pants or "long",
		footwear = look.footwear or "shoes",
	}
end
Painter.palette = palette

-- Couleur de base de chaque membre (sous la peinture) : bras couverts ou nus, jambes...
function Painter.limbColors(look)
	local c = palette(look)
	local arm = (c.sleeves == "long" or c.sleeves == "wide") and c.sleeve or c.skin
	local leg = c.pants == "long" and c.bottom or c.skin
	return { Torso = c.top, Arm = arm, Leg = leg }
end

-- Main (peau) et doigts.
local function hand(S, c, side: string, isLeft: boolean, top: number)
	local skin = c.skin
	S:rect(0.5, (top + 1) / 2, 1, 1 - top, skin, { gradient = { skin, shade(skin, 0.18) }, z = 7 })
	S:rect(0.5, top + S:dy(0.03), 1, S:dy(0.06), shade(skin, 0.4), { fade = { 0.35, 1 }, gradientRotation = 90, z = 8, fine = true })
	if side == "front" then
		-- Pouce (côté du torse)
		local x = isLeft and 0.22 or 0.78
		S:line(x, top + 0.04, x + (isLeft and 0.06 or -0.06), 0.97, 0.02, shade(skin, 0.5), { transparency = 0.2, z = 8, fine = true })
	elseif side == "back" then
		for i = 0, 2 do
			S:line(0.3 + i * 0.2, 0.92, 0.3 + i * 0.2, 0.985, 0.016, shade(skin, 0.45), { transparency = 0.35, z = 8, fine = true })
		end
	end
end

-- Face d'un bras. `side` : "front", "back", "out" (extérieur) ou "in" (contre le torse).
local function paintArm(S, look, c, side: string, isLeft: boolean)
	local skin = c.skin
	local sleeves = c.sleeves
	local sleeve = c.sleeve
	local handTop = 0.82
	-- Bord côté torse sur les faces avant / arrière ("l" ou "r" de la toile)
	local inner = nil
	if side == "front" then
		inner = isLeft and "l" or "r"
	elseif side == "back" then
		inner = isLeft and "r" or "l"
	end
	if sleeves == "long" or sleeves == "wide" then
		cloth(S, sleeve)
		if side ~= "in" then
			if inner then
				edgeShade(S, inner, 0.32, sleeve, 0, handTop)
			end
			-- Plis du coude et du poignet (longs, presque toute la largeur)
			fold(S, 0.04, 0.4, 0.96, 0.47, sleeve)
			fold(S, 0.06, 0.56, 0.94, 0.52, sleeve, { w = 0.13 })
			fold(S, 0.1, 0.7, 0.9, 0.73, sleeve, { w = 0.1 })
			if side == "out" then
				seam(S, 0.5, 0.02, 0.5, handTop - 0.06, sleeve)
			end
		end
		local cuff = look.cuffColor or (sleeves == "wide" and shade(sleeve, 0.1) or nil)
		if cuff then
			band(S, handTop - 0.04, sleeves == "wide" and 0.08 or 0.07, cuff, 6)
		else
			S:rect(0.5, handTop - 0.012, 1, S:dy(0.03), inkOf(sleeve), { z = 6 })
		end
	elseif sleeves == "short" then
		cloth(S, skin)
		if inner then
			edgeShade(S, inner, 0.3, skin, 0.4, handTop)
		end
		local sleeveEnd = look.sleeveEnd or 0.42
		cloth(S, sleeve, { top = 0, bottom = sleeveEnd, z = 4 })
		if inner then
			edgeShade(S, inner, 0.32, sleeve, 0, sleeveEnd, 5)
		end
		band(S, sleeveEnd - 0.025, 0.05, look.hemColor or shade(sleeve, 0.12), 6)
		if side ~= "in" then
			fold(S, 0.12, 0.2, 0.6, 0.27, sleeve, { z = 6, w = 0.06 })
			fold(S, 0.5, 0.31, 0.9, 0.28, sleeve, { z = 6, w = 0.05 })
			-- Coude
			fold(S, 0.3, 0.6, 0.7, 0.6, skin, { w = 0.05, z = 2 })
		end
	else
		cloth(S, skin)
		if inner then
			edgeShade(S, inner, 0.3, skin, 0, handTop)
		end
		if side == "front" or side == "out" then
			-- Biceps / avant-bras
			S:oval(0.5, 0.2, 0.62, 0.55, lighten(skin, 0.3), { fade = { 0.55, 1 }, gradientRotation = 90, z = 1, fine = true })
			fold(S, 0.28, 0.5, 0.72, 0.5, skin, { w = 0.05, z = 2 })
		elseif side == "back" then
			fold(S, 0.32, 0.55, 0.68, 0.57, skin, { w = 0.05, z = 2 })
		end
	end
	hand(S, c, side, isLeft, handTop)
	-- Le haut du bras est caché par la manche d'un haori : inutile d'y peindre des détails.
	local covered = false
	for _, accessory in look.accessories or {} do
		if string.sub(accessory, 1, 5) == "haori" then
			covered = true
		end
	end
	-- Épaules d'une autre couleur (veste de Maruto...)
	if look.shoulders and not covered and (sleeves == "long" or sleeves == "wide") then
		local col = look.shoulders
		S:rect(0.5, 0.12, 1, 0.24, col, { gradient = { lighten(col, 0.18), col }, z = 5 })
		S:oval(0.5, 0.24, 1.2, 0.14, col, { stroke = inkOf(col), strokeThickness = 1.5, z = 4 })
		castShadow(S, 0.29, 0.07, sleeve, 3)
	end
	-- Accessoires peints
	if has(look, "wristbands") then
		local col = c.acc or Color3.fromRGB(220, 40, 40)
		band(S, handTop - 0.075, 0.15, col, 9)
		S:rect(0.5, handTop - 0.075, 1, S:dy(0.018), inkOf(col), { transparency = 0.4, z = 11, fine = true })
	end
	if look.armWarmers then
		-- Manchettes (avant-bras) tenues par des lanières croisées
		local col = look.armWarmers
		S:rect(0.5, 0.64, 1, 0.34, col, { gradient = { lighten(col, 0.15), col, celShadow(col) }, z = 8 })
		S:rect(0.5, 0.47, 1, S:dy(0.03), inkOf(col), { z = 9 })
		if side ~= "in" and look.armWarmerStraps then
			S:line(0.05, 0.52, 0.95, 0.7, 0.045, look.armWarmerStraps, { corner = 0.2, z = 10 })
			S:line(0.95, 0.52, 0.05, 0.7, 0.045, look.armWarmerStraps, { corner = 0.2, z = 10 })
		elseif side ~= "in" then
			fold(S, 0.15, 0.62, 0.85, 0.66, col, { z = 9, w = 0.05 })
		end
	end
	if look.armband and isLeft then
		-- Bandana noué sur le bras gauche (sabreur)
		local col = look.armband
		band(S, 0.3, 0.13, col, 9)
		if side == "out" then
			S:oval(0.55, 0.32, 0.26, 0.2, col, { stroke = inkOf(col), strokeThickness = 1, z = 11 })
			S:line(0.55, 0.36, 0.4, 0.5, 0.09, col, { z = 10 })
			S:line(0.6, 0.36, 0.72, 0.48, 0.08, celShadow(col), { z = 10 })
		end
	end
	if has(look, "tattoos") then
		for _, y in { 0.6, 0.68 } do
			S:rect(0.5, y, 1, S:dy(0.055), INK, { z = 9 })
		end
	end
	if look.shoulderMark and not covered and side == "out" and (not look.shoulderMarkLeft or isLeft) then
		local y = look.shoulders and 0.36 or 0.17
		logo(S.g, look.shoulderMark, 0.5, y, 0.42, S.w / S.h)
	end
end

-- Chaussures et sandales.
local function paintFeet(S, look, c, side: string)
	local skin = c.skin
	local foot = c.footwear
	local shoes = c.shoes
	if foot == "sandals" then
		-- Sandales ninja : orteils à l'air devant, talon fermé derrière, semelle épaisse
		local y0 = 0.82
		S:rect(0.5, (y0 + 1) / 2, 1, 1 - y0, shoes, { gradient = { lighten(shoes, 0.2), shoes, celShadow(shoes) }, z = 10 })
		S:rect(0.5, y0, 1, S:dy(0.025), inkOf(shoes), { z = 11 })
		if side == "front" then
			S:rect(0.5, 0.925, 0.86, 0.095, skin, { gradient = { skin, shade(skin, 0.22) }, corner = 0.2, z = 11 })
			for i = 1, 3 do
				S:line(0.07 + i * 0.215, 0.9, 0.07 + i * 0.215, 0.965, 0.016, shade(skin, 0.5), { transparency = 0.2, z = 12, fine = true })
			end
			S:line(0.04, 0.865, 0.96, 0.865, 0.06, shoes, { corner = 0.25, z = 12 })
		elseif side == "out" or side == "in" then
			S:rect(0.28, 0.925, 0.5, 0.1, skin, { gradient = { skin, shade(skin, 0.22) }, z = 11 })
			S:line(0.03, 0.88, 0.55, 0.88, 0.05, shoes, { corner = 0.2, z = 12 })
		end
		S:rect(0.5, 0.985, 1, 0.03, shade(shoes, 0.55), { z = 12 })
	elseif foot == "zori" then
		-- Chaussettes tabi blanches + sandales de paille
		local sock = Color3.fromRGB(242, 240, 234)
		S:rect(0.5, 0.91, 1, 0.18, sock, { gradient = { WHITE, sock, shade(sock, 0.2) }, z = 10 })
		S:rect(0.5, 0.82, 1, S:dy(0.022), shade(sock, 0.45), { z = 11 })
		S:rect(0.5, 0.985, 1, 0.035, shoes, { gradient = { lighten(shoes, 0.2), shoes }, z = 11 })
		if side == "front" then
			S:line(0.5, 0.89, 0.5, 0.965, 0.025, shade(sock, 0.35), { z = 11, fine = true })
			S:line(0.18, 0.95, 0.5, 0.885, 0.04, Color3.fromRGB(70, 55, 60), { z = 12 })
			S:line(0.82, 0.95, 0.5, 0.885, 0.04, Color3.fromRGB(70, 55, 60), { z = 12 })
		end
	elseif foot == "boots" then
		local y0 = look.bootTop or 0.66
		S:rect(0.5, (y0 + 1) / 2, 1, 1 - y0, shoes, { gradient = { lighten(shoes, 0.2), shoes, celShadow(shoes) }, z = 10 })
		band(S, y0 + 0.025, 0.05, look.bootTrim or shade(shoes, 0.2), 11)
		if side == "front" then
			fold(S, 0.15, y0 + 0.13, 0.7, y0 + 0.17, shoes, { z = 11, w = 0.05 })
			S:line(0.5, y0 + 0.06, 0.5, 0.9, 0.06, look.bootLace or shade(shoes, 0.25), { corner = 0.3, z = 11 })
		elseif side == "out" then
			fold(S, 0.2, y0 + 0.16, 0.85, y0 + 0.13, shoes, { z = 11, w = 0.05 })
		end
		S:rect(0.5, 0.982, 1, 0.036, shade(shoes, 0.6), { z = 12 })
	elseif foot == "barefoot" then
		S:rect(0.5, 0.92, 1, 0.16, skin, { gradient = { skin, shade(skin, 0.2) }, z = 10 })
	else
		local y0 = 0.84
		S:rect(0.5, (y0 + 1) / 2, 1, 1 - y0, shoes, { gradient = { lighten(shoes, 0.2), shoes, celShadow(shoes) }, z = 10 })
		S:rect(0.5, y0, 1, S:dy(0.022), inkOf(shoes), { z = 11 })
		S:rect(0.5, 0.978, 1, 0.044, lighten(shoes, 0.55), { z = 11 })
		if side == "front" then
			for i = 0, 1 do
				S:line(0.35, 0.87 + i * 0.035, 0.65, 0.875 + i * 0.035, 0.022, lighten(shoes, 0.5), { z = 11, fine = true })
			end
		end
	end
end

-- Face d'une jambe.
local function paintLeg(S, look, c, side: string, isLeft: boolean)
	local skin = c.skin
	local pants = c.pants
	local bottom = c.bottom
	local pantsEnd = 1
	if pants == "shorts" then
		pantsEnd = look.shortsLength or 0.5
	elseif pants == "kimono" then
		pantsEnd = look.kimonoLength or 0.38
	end
	-- Côté de l'entrejambe sur les faces avant / arrière
	local inner = nil
	if side == "front" then
		inner = isLeft and "l" or "r"
	elseif side == "back" then
		inner = isLeft and "r" or "l"
	end
	if pantsEnd < 1 then
		cloth(S, skin)
		if inner then
			edgeShade(S, inner, 0.3, skin, pantsEnd, 1)
		end
		cloth(S, bottom, { top = 0, bottom = pantsEnd, z = 2 })
		if inner then
			edgeShade(S, inner, 0.32, bottom, 0, pantsEnd, 3)
		end
		local hem = look.hemBottom or shade(bottom, 0.12)
		band(S, pantsEnd - 0.025, look.hemBottomSize or 0.05, hem, 4)
		if side ~= "in" then
			fold(S, 0.15, pantsEnd * 0.55, 0.65, pantsEnd * 0.42, bottom, { z = 3, w = 0.06 })
			fold(S, 0.5, pantsEnd * 0.8, 0.9, pantsEnd * 0.72, bottom, { z = 3, w = 0.05 })
		end
		if side == "front" then
			-- Genou
			fold(S, 0.32, 0.62, 0.68, 0.6, skin, { w = 0.05, z = 1 })
		end
	else
		cloth(S, bottom)
		if inner then
			edgeShade(S, inner, 0.34, bottom)
		end
		if side == "front" then
			-- Plis de l'entrejambe, du genou et des chevilles
			local inX = isLeft and 0.02 or 0.98
			local d = isLeft and 1 or -1
			fold(S, inX, 0.04, inX + d * 0.6, 0.2, bottom, { w = 0.12 })
			fold(S, 0.05, 0.45, 0.95, 0.42, bottom)
			fold(S, 0.1, 0.56, 0.9, 0.53, bottom, { w = 0.12 })
			fold(S, 0.08, 0.72, 0.92, 0.75, bottom, { w = 0.1 })
		elseif side == "back" then
			fold(S, 0.06, 0.1, 0.94, 0.13, bottom, { w = 0.12 })
			fold(S, 0.08, 0.5, 0.92, 0.47, bottom)
			fold(S, 0.15, 0.72, 0.85, 0.7, bottom, { w = 0.1 })
		elseif side == "out" then
			seam(S, 0.5, 0.0, 0.5, 0.82, bottom)
			fold(S, 0.06, 0.46, 0.94, 0.5, bottom)
			fold(S, 0.1, 0.72, 0.9, 0.7, bottom, { w = 0.1 })
		end
	end
	-- Bandes de jambe (tibias bandés façon ninja / jambières de pourfendeur)
	if look.legWraps then
		local col = look.legWraps
		local y0 = look.legWrapTop or 0.56
		local y1 = 0.86
		bandage(S, y0, y1, 6, 4, col)
		if look.legWrapStraps and side ~= "in" then
			S:line(0.08, y0 + 0.03, 0.92, y1 - 0.07, 0.045, look.legWrapStraps, { corner = 0.2, z = 8 })
			S:line(0.92, y0 + 0.03, 0.08, y1 - 0.07, 0.045, look.legWrapStraps, { corner = 0.2, z = 8 })
		end
	end
	-- Bandage + étui sur la cuisse droite (ninja)
	if look.holster and not isLeft then
		bandage(S, 0.3, 0.42, 6, 3)
		if side == "front" or side == "out" then
			local col = look.holster
			S:box(0.5, 0.39, 0.56, 0.32, col, { corner = 0.15, gradient = { lighten(col, 0.18), celShadow(col) }, stroke = inkOf(col), strokeThickness = 1.2, z = 8 })
			S:box(0.5, 0.345, 0.6, 0.12, col, { corner = 0.2, gradient = { lighten(col, 0.25), col }, stroke = inkOf(col), strokeThickness = 1, z = 9 })
			S:oval(0.5, 0.37, 0.07, 0.07, METAL, { z = 10, fine = true })
		end
	end
	paintFeet(S, look, c, side)
end

------------------------------------------------------------------------
-- Torse (avant / arrière) selon la tenue
------------------------------------------------------------------------

-- Plis génériques du torse (aisselles, ventre).
local function torsoFolds(S, color: Color3, o)
	local opts = o or {}
	fold(S, 0.02, 0.3, 0.36, 0.55, color)
	fold(S, 0.98, 0.3, 0.64, 0.55, color)
	if opts.belly ~= false then
		fold(S, 0.06, 0.72, 0.42, 0.78, color, { w = 0.12 })
		fold(S, 0.58, 0.79, 0.94, 0.73, color, { w = 0.12 })
	end
end

-- Ombres franches sur les deux bords du torse.
local function torsoEdges(S, color: Color3, top: number?, bottom: number?)
	edgeShade(S, "l", 0.13, color, top, bottom)
	edgeShade(S, "r", 0.13, color, top, bottom)
end

-- Ceinture de taille peinte (haramaki, ceinture d'étoffe...).
local function waistband(S, color: Color3, front: boolean)
	band(S, 0.84, 0.16, color, 7)
	if front then
		fold(S, 0.1, 0.82, 0.45, 0.85, color, { z = 8, w = 0.05 })
		fold(S, 0.6, 0.86, 0.9, 0.83, color, { z = 8, w = 0.05 })
	end
end

local OUTFITS = {}

OUTFITS.shirt = function(S, look, c)
	local top = c.top
	torsoEdges(S, top)
	-- Encolure ronde (côtes)
	S:oval(0.5, 0.0, 0.5, 0.22, shade(top, 0.12), { stroke = inkOf(top), strokeThickness = 1.2, z = 2 })
	S:oval(0.5, -0.01, 0.4, 0.15, c.skin, { gradient = { shade(c.skin, 0.35), c.skin }, z = 3 })
	torsoFolds(S, top)
	fold(S, 0.3, 0.4, 0.45, 0.6, top, { w = 0.06 })
	if look.waistband then
		waistband(S, look.waistband, true)
	end
end

OUTFITS.jacket = function(S, look, c)
	local top = c.top
	local yoke = look.shoulders or c.accent
	S.under = yoke
	torsoEdges(S, top)
	-- Empiècement d'épaules (bleu nuit sur la veste de Maruto) au bord arrondi
	S:rect(0.5, 0.15, 1, 0.3, yoke, { gradient = { lighten(yoke, 0.2), yoke, shade(yoke, 0.15) }, z = 2 })
	for _, x in { 0.2, 0.8 } do
		S:oval(x, 0.3, 0.95, 0.2, yoke, { stroke = inkOf(yoke), strokeThickness = 1.6, z = 1 })
	end
	castShadow(S, 0.36, 0.1, top, 1)
	torsoFolds(S, top)
	-- Poches en biais
	for _, s in { -1, 1 } do
		S:line(0.5 + s * 0.2, 0.63, 0.5 + s * 0.35, 0.75, 0.035, inkOf(top), { z = 4 })
		S:line(0.5 + s * 0.215, 0.61, 0.5 + s * 0.365, 0.73, 0.02, lighten(top, 0.35), { transparency = 0.2, z = 4, fine = true })
	end
	-- Ourlet du bas
	band(S, 0.9, 0.06, shade(top, 0.08), 4)
	zipper(S, 0.5, 0.06, 0.93, top, 5)
	if look.collar == "fur" then
		furTrim(S, 0.075, 0.15, look.collarColor or Color3.fromRGB(240, 238, 230), 8)
	else
		S:oval(0.5, 0.02, 0.56, 0.24, yoke, { stroke = inkOf(yoke), strokeThickness = 1, z = 6 })
		S:oval(0.5, 0.0, 0.36, 0.14, shade(yoke, 0.55), { z = 7 })
	end
	if look.chestMark then
		logo(S.g, look.chestMark, 0.28, 0.22, 0.16)
	end
end

OUTFITS.jumpsuit = function(S, look, c)
	local top, accent = c.top, c.accent
	torsoEdges(S, top)
	S:rect(0.5, 0.05, 0.6, 0.1, accent, { z = 2 })
	zipper(S, 0.5, 0.06, 0.92, top, 5)
	torsoFolds(S, top)
	local _ = look
end

OUTFITS.uniform = function(S, look, c)
	local top = c.top
	torsoEdges(S, top)
	-- Col montant + boutons dorés (uniforme de pourfendeur)
	S:rect(0.5, 0.055, 0.6, 0.11, shade(top, 0.1), { corner = 0.2, stroke = inkOf(top), strokeThickness = 1.2, z = 4 })
	S:line(0.5, 0.11, 0.5, 0.95, 0.03, inkOf(top), { z = 3 })
	local gold = look.buttonColor or Color3.fromRGB(235, 200, 90)
	for i = 0, 3 do
		local y = 0.2 + i * 0.16
		S:oval(0.54, y, 0.085, 0.085, gold, { gradient = { lighten(gold, 0.4), gold, darken(gold, 0.3) }, stroke = darken(gold, 0.5), strokeThickness = 1, z = 5 })
	end
	torsoFolds(S, top)
	fold(S, 0.2, 0.55, 0.4, 0.62, top, { w = 0.06 })
	-- Ceinture blanche
	if look.topAccent then
		band(S, 0.86, 0.08, c.accent, 7)
		S:box(0.5, 0.86, 0.24, 0.14, c.accent, { corner = 0.12, gradient = { WHITE, c.accent }, stroke = inkOf(c.accent), strokeThickness = 1.2, z = 9 })
	end
end

OUTFITS.gi = function(S, look, c)
	local top = c.top
	local under = c.accent
	torsoEdges(S, top)
	-- Col croisé (kimono d'arts martiaux) sur un maillot de dessous
	S:rect(0.5, 0.0, 0.44, 0.62, under, { rotation = 45, gradient = { lighten(under, 0.2), under }, z = 2 })
	S:line(0.22, 0.0, 0.53, 0.52, 0.16, top, { corner = 0, gradient = { lighten(top, 0.15), top }, gradientRotation = 90, z = 3 })
	S:line(0.78, 0.0, 0.47, 0.52, 0.16, top, { corner = 0, gradient = { lighten(top, 0.15), top }, gradientRotation = 90, z = 4 })
	S:line(0.29, 0.02, 0.54, 0.45, 0.025, inkOf(top), { z = 5 })
	S:line(0.71, 0.02, 0.46, 0.45, 0.025, inkOf(top), { z = 5 })
	castShadow(S, 0.0, 0.12, under, 2)
	torsoFolds(S, top)
	fold(S, 0.56, 0.55, 0.82, 0.66, top, { w = 0.07 })
	if look.logo and not look.logo.back then
		logo(S.g, look.logo, 0.74, 0.32, 0.22)
	elseif look.logo then
		logo(S.g, look.logo, 0.76, 0.3, 0.17)
	end
	-- Ceinture nouée
	local belt = c.acc or under
	band(S, 0.85, 0.11, belt, 7)
	S:oval(0.38, 0.86, 0.24, 0.17, belt, { gradient = { lighten(belt, 0.2), belt }, stroke = inkOf(belt), strokeThickness = 1.2, z = 9 })
	S:line(0.35, 0.9, 0.29, 1.06, 0.12, belt, { corner = 0.2, z = 8 })
	S:line(0.41, 0.9, 0.47, 1.06, 0.12, celShadow(belt), { corner = 0.2, z = 8 })
end

OUTFITS.highcollar = function(S, look, c)
	local top = c.top
	torsoEdges(S, top)
	-- Haut col montant
	S:rect(0.5, 0.06, 0.76, 0.12, shade(top, 0.08), { corner = 0.25, gradient = { lighten(top, 0.2), top }, stroke = inkOf(top), strokeThickness = 1.2, z = 3 })
	S:oval(0.5, 0.0, 0.44, 0.08, shade(top, 0.6), { z = 4 })
	castShadow(S, 0.12, 0.08, top, 2)
	if look.collarButton then
		local col = look.collarButton
		S:oval(0.38, 0.075, 0.14, 0.14, col, { gradient = { lighten(col, 0.4), col }, stroke = darken(col, 0.45), strokeThickness = 1, z = 5 })
		S:oval(0.38, 0.075, 0.06, 0.06, darken(col, 0.35), { z = 6, fine = true })
	end
	if look.frontZip then
		S:line(0.5, 0.12, 0.5, 0.95, 0.03, inkOf(top), { corner = 0, z = 3 })
		S:line(0.515, 0.12, 0.515, 0.95, 0.015, lighten(top, 0.25), { corner = 0, transparency = 0.3, z = 3, fine = true })
	end
	torsoFolds(S, top)
	fold(S, 0.6, 0.45, 0.8, 0.58, top, { w = 0.06 })
	-- Bas de la tunique (ourlet)
	band(S, 0.88, 0.05, look.hemColor or c.accent, 6)
end

OUTFITS.flakvest = function(S, _look, c)
	local vest = c.accent
	torsoEdges(S, c.top)
	-- Gilet tactique : col roulé, fermeture, poches à rouleaux
	S:rect(0.5, 0.55, 0.84, 0.9, vest, { gradient = { lighten(vest, 0.14), vest, celShadow(vest) }, corner = 0.05, stroke = inkOf(vest), strokeThickness = 1.2, z = 2 })
	S:oval(0.5, 0.08, 0.98, 0.26, vest, { gradient = { lighten(vest, 0.2), vest }, stroke = inkOf(vest), strokeThickness = 1.2, z = 4 })
	S:oval(0.5, 0.035, 0.58, 0.13, c.top, { z = 5 })
	zipper(S, 0.5, 0.15, 0.98, vest, 3)
	for _, x in { 0.28, 0.72 } do
		for _, y in { 0.42, 0.66 } do
			pocket(S, x, y, 0.34, 0.38, vest, 5)
		end
	end
	edgeShade(S, "l", 0.2, vest, 0.1, 1, 4)
	edgeShade(S, "r", 0.2, vest, 0.1, 1, 4)
	fold(S, 0.12, 0.86, 0.4, 0.89, vest, { w = 0.05, z = 8 })
	fold(S, 0.88, 0.86, 0.6, 0.89, vest, { w = 0.05, z = 8 })
end

OUTFITS.robe = function(S, look, c)
	local top = c.top
	torsoEdges(S, top)
	-- Col croisé (kimono) + large ceinture (obi)
	S:rect(0.5, 0.04, 0.26, 0.26, look.underColor or c.skin, { rotation = 45, z = 2 })
	S:line(0.28, 0.0, 0.56, 0.62, 0.13, top, { corner = 0, gradient = { lighten(top, 0.1), top }, gradientRotation = 90, z = 3 })
	S:line(0.72, 0.0, 0.44, 0.62, 0.13, top, { corner = 0, gradient = { lighten(top, 0.1), top }, gradientRotation = 90, z = 4 })
	S:line(0.34, 0.0, 0.58, 0.55, 0.022, inkOf(top), { z = 4 })
	S:line(0.66, 0.0, 0.42, 0.55, 0.022, inkOf(top), { z = 5 })
	fold(S, 0.06, 0.35, 0.3, 0.55, top)
	fold(S, 0.94, 0.35, 0.7, 0.55, top)
	fold(S, 0.6, 0.15, 0.8, 0.4, top, { w = 0.06 })
	local obi = c.accent
	band(S, 0.8, 0.2, obi, 7)
	fold(S, 0.1, 0.78, 0.5, 0.8, obi, { z = 9, w = 0.05 })
	if look.obiCord then
		S:rect(0.5, 0.8, 1, S:dy(0.06), look.obiCord, { z = 9 })
		S:oval(0.5, 0.8, 0.14, 0.1, look.obiCord, { stroke = inkOf(look.obiCord), strokeThickness = 1, z = 10 })
	end
end

-- Motif feuille de chanvre (asanoha simplifié) : étoiles à 6 branches.
local function asanoha(S, ink: Color3, rows: number, cols: number, y0: number, y1: number)
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local x = (col + 0.5 + (row % 2) * 0.5) / cols
			local y = y0 + (row + 0.5) / rows * (y1 - y0)
			if x < 1 then
				for k = 0, 2 do
					local a = math.rad(k * 60 + 90)
					local dx, dy = math.cos(a) * 0.1, math.sin(a) * 0.1
					S:line(x - dx / S.w, y - dy / S.h, x + dx / S.w, y + dy / S.h, 0.016, ink, { transparency = 0.2, z = 2, fine = true })
				end
			end
		end
	end
end
Painter.asanoha = asanoha

OUTFITS.kimono = function(S, look, c)
	if look.pattern == "asanoha" then
		asanoha(S, look.patternColor or shade(c.top, 0.3), 3, 3, 0.02, 0.7)
	else
		for i = 0, 5 do
			S:oval(0.15 + (i % 3) * 0.35, 0.22 + math.floor(i / 3) * 0.3, 0.12, 0.12, lighten(c.top, 0.4), { transparency = 0.3, z = 2 })
		end
	end
	OUTFITS.robe(S, look, c)
end

OUTFITS.suit = function(S, look, c)
	local top = c.top
	torsoEdges(S, top)
	-- Chemise blanche en V, cravate, revers
	S:rect(0.5, 0.12, 0.34, 0.5, c.accent, { z = 2 })
	S:line(0.3, 0.0, 0.42, 0.55, 0.12, shade(top, 0.15), { corner = 0, z = 3 })
	S:line(0.7, 0.0, 0.58, 0.55, 0.12, shade(top, 0.15), { corner = 0, z = 3 })
	S:rect(0.5, 0.3, 0.07, 0.42, Color3.fromRGB(40, 40, 50), { corner = 0.3, z = 4 })
	S:rect(0.5, 0.11, 0.09, 0.06, Color3.fromRGB(40, 40, 50), { corner = 0.3, z = 4 })
	for i = 0, 1 do
		S:oval(0.6, 0.64 + i * 0.12, 0.07, 0.07, shade(top, 0.5), { z = 4 })
	end
	torsoFolds(S, top)
	local _ = look
end

OUTFITS.armor = function(S, look, c)
	local accent = c.accent
	-- Plastron de combat
	S:rect(0.5, 0.36, 1, 0.72, accent, { corner = 0.12, gradient = { lighten(accent, 0.18), accent, celShadow(accent) }, stroke = inkOf(accent), strokeThickness = 1.2, z = 2 })
	S:rect(0.5, 0.72, 0.9, 0.04, inkOf(accent), { z = 3 })
	S:rect(0.5, 0.36, 0.015, 0.6, celShadow(accent), { z = 3 })
	local _ = look
end

OUTFITS.tank = function(S, look, c)
	local skin = c.skin
	torsoEdges(S, c.top)
	S:oval(0.5, 0.0, 0.5, 0.28, skin, { z = 2 })
	S:rect(0.08, 0.1, 0.16, 0.22, skin, { z = 2 })
	S:rect(0.92, 0.1, 0.16, 0.22, skin, { z = 2 })
	torsoFolds(S, c.top)
	local _ = look
end

OUTFITS.qipao = function(S, look, c)
	local accent, skin = c.accent, c.skin
	torsoEdges(S, c.top)
	S:rect(0.5, 0.05, 0.5, 0.1, accent, { z = 2 })
	S:line(0.5, 0.06, 0.72, 0.42, 0.06, accent, { z = 3 })
	S:rect(0.5, 0.45, 0.012, 0.75, inkOf(c.top), { z = 2 })
	S:rect(0.08, 0.1, 0.16, 0.2, skin, { z = 2 })
	S:rect(0.92, 0.1, 0.16, 0.2, skin, { z = 2 })
	torsoFolds(S, c.top)
	local _ = look
end

-- Torse nu (pectoraux, abdominaux)
local function chest(S, skin: Color3, o)
	local opts = o or {}
	local x0 = opts.x0 or 0.18
	local x1 = opts.x1 or 0.82
	S:line(x0, 0.33, 0.47, 0.37, 0.04, shade(skin, 0.32), { fade = { 0.85, 0.05 }, gradientRotation = 0, z = 3 })
	S:line(x1, 0.33, 0.53, 0.37, 0.04, shade(skin, 0.32), { fade = { 0.85, 0.05 }, gradientRotation = 0, z = 3 })
	S:oval(0.33, 0.2, 0.46, 0.28, lighten(skin, 0.3), { transparency = 0.55, z = 2, fine = true })
	S:oval(0.67, 0.2, 0.46, 0.28, lighten(skin, 0.3), { transparency = 0.55, z = 2, fine = true })
	if opts.abs ~= false then
		S:line(0.5, 0.42, 0.5, 0.86, 0.028, shade(skin, 0.3), { transparency = 0.25, z = 3, fine = true })
		for i = 0, 2 do
			local y = 0.52 + i * 0.12
			S:line(0.4, y, 0.47, y + 0.01, 0.022, shade(skin, 0.3), { transparency = 0.35, z = 3, fine = true })
			S:line(0.6, y, 0.53, y + 0.01, 0.022, shade(skin, 0.3), { transparency = 0.35, z = 3, fine = true })
		end
	end
end

OUTFITS.openvest = function(S, look, c)
	local skin, top = c.skin, c.top
	torsoEdges(S, top)
	-- Gilet ouvert sur torse nu
	S:rect(0.5, 0.5, 0.5, 1, skin, { gradient = { lighten(skin, 0.1), skin, shade(skin, 0.16) }, z = 2 })
	chest(S, skin, { x0 = 0.28, x1 = 0.72 })
	if look.chestScar then
		local scar = Color3.fromRGB(185, 90, 80)
		S:line(0.36, 0.1, 0.62, 0.42, 0.05, scar, { z = 4 })
		S:line(0.64, 0.1, 0.38, 0.42, 0.05, scar, { z = 4 })
	end
	for _, s in { -1, 1 } do
		S:line(0.5 + s * 0.25, 0.0, 0.5 + s * 0.25, 1.0, 0.035, inkOf(top), { corner = 0, z = 3 })
		S:line(0.5 + s * 0.235, 0.0, 0.5 + s * 0.235, 1.0, 0.018, lighten(top, 0.3), { corner = 0, transparency = 0.3, z = 3, fine = true })
	end
	for i = 0, 2 do
		S:oval(0.2, 0.25 + i * 0.17, 0.075, 0.075, Color3.fromRGB(245, 205, 90), { stroke = Color3.fromRGB(150, 110, 40), strokeThickness = 1, z = 4 })
	end
	fold(S, 0.05, 0.4, 0.18, 0.55, top, { w = 0.06 })
	fold(S, 0.95, 0.4, 0.82, 0.55, top, { w = 0.06 })
	if look.waistband then
		waistband(S, look.waistband, true)
	end
end

OUTFITS.openshirt = function(S, look, c)
	local skin, top = c.skin, c.top
	torsoEdges(S, top)
	S:rect(0.5, 0.15, 0.3, 0.45, skin, { z = 2 })
	S:oval(0.5, 0.36, 0.3, 0.2, skin, { z = 2 })
	chest(S, skin, { abs = false })
	S:line(0.36, 0.0, 0.47, 0.48, 0.1, shade(top, 0.06), { corner = 0, z = 3 })
	S:line(0.64, 0.0, 0.53, 0.48, 0.1, shade(top, 0.06), { corner = 0, z = 3 })
	S:line(0.395, 0.0, 0.495, 0.47, 0.018, inkOf(top), { z = 4 })
	S:line(0.605, 0.0, 0.505, 0.47, 0.018, inkOf(top), { z = 4 })
	torsoFolds(S, top)
	if look.waistband then
		waistband(S, look.waistband, true)
	end
end

OUTFITS.openrobe = function(S, look, c)
	OUTFITS.openshirt(S, look, c)
	band(S, 0.82, 0.08, c.accent, 6)
end

OUTFITS.striped = function(S, look, c)
	for i = 0, 3 do
		S:rect(0.5, 0.18 + i * 0.2, 1, 0.08, c.accent, { z = 2 })
	end
	torsoEdges(S, c.top)
	torsoFolds(S, c.top)
	local _ = look
end

OUTFITS.sailor = function(S, look, c)
	S:rect(0.5, 0.0, 0.7, 0.6, c.accent, { z = 2 })
	S:rect(0.5, 0.06, 0.4, 0.5, c.top, { rotation = 45, z = 3 })
	S:rect(0.5, 0.36, 0.12, 0.1, Color3.fromRGB(220, 40, 40), { corner = 0.3, rotation = 45, z = 4 })
	torsoEdges(S, c.top)
	local _ = look
end

OUTFITS.overalls = function(S, look, c)
	local accent = c.accent
	torsoEdges(S, c.top)
	S:rect(0.5, 0.65, 0.6, 0.7, accent, { corner = 0.08, gradient = { lighten(accent, 0.12), accent, celShadow(accent) }, z = 2 })
	S:rect(0.27, 0.25, 0.06, 0.5, accent, { z = 2 })
	S:rect(0.73, 0.25, 0.06, 0.5, accent, { z = 2 })
	S:oval(0.27, 0.42, 0.08, 0.08, Color3.fromRGB(230, 200, 90), { z = 3 })
	S:oval(0.73, 0.42, 0.08, 0.08, Color3.fromRGB(230, 200, 90), { z = 3 })
	local _ = look
end

OUTFITS.coat = function(S, look, c)
	local accent = c.accent
	torsoEdges(S, c.top)
	S:rect(0.5, 0.5, 0.06, 1, accent, { z = 2 })
	S:rect(0.5, 0.04, 0.8, 0.1, accent, { corner = 0.4, z = 2 })
	for i = 0, 3 do
		S:oval(0.6, 0.2 + i * 0.18, 0.07, 0.07, accent, { z = 3 })
	end
	torsoFolds(S, c.top)
	local _ = look
end

OUTFITS.denim = function(S, _look, c)
	local accent = c.accent
	torsoEdges(S, c.top)
	S:rect(0.5, 0.5, 0.42, 1, accent, { z = 2 })
	for i = 0, 3 do
		S:rect(0.5, 0.15 + i * 0.22, 0.42, 0.06, lighten(accent, 0.6), { z = 3 })
	end
	S:rect(0.2, 0.5, 0.012, 0.9, inkOf(c.top), { z = 3 })
	S:rect(0.8, 0.5, 0.012, 0.9, inkOf(c.top), { z = 3 })
end

OUTFITS.egyptian = function(S, look, c)
	torsoEdges(S, c.top)
	S:rect(0.5, 0.86, 1, 0.08, c.accent, { z = 2 })
	for i = 0, 4 do
		S:rect(0.1 + i * 0.2, 0.86, 0.06, 0.06, c.top, { rotation = 45, z = 3 })
	end
	local _ = look
end

OUTFITS.chakra = function(S, look, c)
	local accent = c.accent
	-- Mode Démon Renard : motifs noirs sur un corps doré
	for i = 0, 5 do
		S:oval(0.12 + i * 0.152, 0.06, 0.18, 0.18, accent, { z = 3 })
	end
	S:oval(0.5, 0.5, 0.84, 0.84, accent, { transparency = 1, stroke = accent, strokeThickness = 4, z = 3 })
	S:rect(0.2, 0.55, 0.03, 0.7, accent, { z = 3 })
	S:rect(0.8, 0.55, 0.03, 0.7, accent, { z = 3 })
	S:oval(0.5, 0.5, 1.4, 1.4, Color3.fromRGB(255, 240, 160), { transparency = 0.6, z = 1, fine = true })
	local _ = look
end

OUTFITS.cloak = function(S, look, c)
	torsoEdges(S, c.top)
	S:rect(0.5, 0.08, 0.84, 0.16, shade(c.top, 0.2), { corner = 0.3, z = 2 })
	cloud(S.g, 0.27, 0.4, 0.3, c.accent)
	cloud(S.g, 0.72, 0.7, 0.28, c.accent)
	torsoFolds(S, c.top)
	local _ = look
end

OUTFITS.fur = function(S, look, c)
	S:oval(0.5, 0.55, 1.2, 1.6, lighten(c.top, 0.25), { z = 2 })
	local _ = look
end

OUTFITS.shirtless = function(S, look, c)
	torsoEdges(S, c.skin)
	chest(S, c.skin)
	local _ = look
end

-- Peint le dos du torse.
local function torsoBack(S, look, c)
	local outfit = c.outfit
	torsoEdges(S, c.top)
	if outfit == "cloak" then
		cloud(S.g, 0.3, 0.3, 0.32, c.accent)
		cloud(S.g, 0.7, 0.62, 0.32, c.accent)
	elseif outfit == "jacket" or outfit == "jumpsuit" or outfit == "flakvest" then
		local yoke = look.shoulders or c.accent
		if outfit == "flakvest" then
			S:rect(0.5, 0.55, 0.9, 0.9, c.accent, { gradient = { lighten(c.accent, 0.12), c.accent, celShadow(c.accent) }, stroke = inkOf(c.accent), strokeThickness = 1.2, z = 2 })
			S:rect(0.5, 0.07, 0.86, 0.14, c.accent, { corner = 0.4, gradient = { lighten(c.accent, 0.2), c.accent }, stroke = inkOf(c.accent), strokeThickness = 1.2, z = 3 })
			S:rect(0.5, 0.86, 0.9, S:dy(0.03), inkOf(c.accent), { z = 3 })
		else
			S.under = yoke
			S:rect(0.5, 0.18, 1, 0.36, yoke, { gradient = { lighten(yoke, 0.2), yoke, shade(yoke, 0.15) }, z = 2 })
			S:oval(0.5, 0.36, 1.5, 0.14, yoke, { stroke = inkOf(yoke), strokeThickness = 1.6, z = 1 })
			castShadow(S, 0.4, 0.1, c.top, 1)
			band(S, 0.9, 0.06, shade(c.top, 0.08), 4)
			if look.collar == "fur" then
				furTrim(S, 0.06, 0.12, look.collarColor or Color3.fromRGB(240, 238, 230), 8)
			end
		end
	elseif outfit == "gi" then
		S:oval(0.5, 0.0, 0.5, 0.16, c.accent, { z = 2 })
		local belt = c.acc or c.accent
		band(S, 0.85, 0.11, belt, 7)
	elseif outfit == "uniform" and look.topAccent then
		band(S, 0.86, 0.08, c.accent, 7)
	elseif outfit == "robe" or outfit == "kimono" then
		if look.pattern == "asanoha" then
			asanoha(S, look.patternColor or shade(c.top, 0.3), 3, 3, 0.02, 0.7)
		end
		band(S, 0.8, 0.2, c.accent, 7)
		if look.obiBow then
			S:oval(0.5, 0.72, 0.9, 0.42, look.obiBow, { gradient = { lighten(look.obiBow, 0.2), look.obiBow }, stroke = inkOf(look.obiBow), strokeThickness = 1.2, z = 9 })
			S:oval(0.5, 0.72, 0.22, 0.3, celShadow(look.obiBow), { z = 10 })
		end
	elseif outfit == "highcollar" then
		S:rect(0.5, 0.06, 0.76, 0.12, shade(c.top, 0.08), { corner = 0.25, gradient = { lighten(c.top, 0.2), c.top }, stroke = inkOf(c.top), strokeThickness = 1.2, z = 3 })
		band(S, 0.88, 0.05, look.hemColor or c.accent, 6)
	elseif outfit == "shirt" then
		S:oval(0.5, 0.0, 0.46, 0.12, shade(c.top, 0.12), { stroke = inkOf(c.top), strokeThickness = 1.2, z = 2 })
	elseif outfit == "shirtless" then
		S:line(0.5, 0.15, 0.5, 0.85, 0.03, shade(c.skin, 0.3), { transparency = 0.4, z = 2 })
	end
	if outfit == "openvest" or outfit == "openshirt" or outfit == "shirt" then
		if look.waistband then
			waistband(S, look.waistband, false)
		end
	end
	if outfit ~= "shirtless" and outfit ~= "flakvest" then
		-- Omoplates
		fold(S, 0.14, 0.24, 0.34, 0.44, c.top, { w = 0.07 })
		fold(S, 0.86, 0.24, 0.66, 0.44, c.top, { w = 0.07 })
		fold(S, 0.3, 0.7, 0.7, 0.72, c.top, { w = 0.06 })
	end
	if look.logo and look.logo.back then
		logo(S.g, look.logo, 0.5, 0.5, 0.42)
	end
end

------------------------------------------------------------------------
-- Habillage complet (toutes les faces visibles du torse, des bras et des jambes)
------------------------------------------------------------------------

local SIDE_NAMES = {
	{ Enum.NormalId.Front, "front" },
	{ Enum.NormalId.Back, "back" },
	{ Enum.NormalId.Left, "left" },
	{ Enum.NormalId.Right, "right" },
}

-- Peint la tenue d'un perso R6. `limbs` : table nom -> pièce (Torso, "Left Arm"...).
-- Les faces latérales du torse et intérieures des membres (cachées sauf en mouvement)
-- reçoivent une peinture simplifiée.
function Painter.dress(limbs, look, mode: string?)
	local c = palette(look)
	local top = c.top
	local painter = OUTFITS[c.outfit] or OUTFITS.shirt
	local torso = limbs.Torso
	if torso then
		for _, entry in SIDE_NAMES do
			local face, name = entry[1], entry[2]
			if mode == "parts" and (name == "left" or name == "right") then
				continue -- faces cachées par les bras : inutiles dans les aperçus
			end
			local S = Painter.sheet(torso, face, mode, "Shirt" .. face.Name, 70)
			cloth(S, top)
			if name == "front" then
				painter(S, look, c)
			elseif name == "back" then
				torsoBack(S, look, c)
			else
				if look.shoulders then
					S:rect(0.5, 0.15, 1, 0.3, look.shoulders, { z = 2 })
				end
				fold(S, 0.2, 0.32, 0.8, 0.42, top, { w = 0.07 })
				if look.waistband then
					band(S, 0.84, 0.16, look.waistband, 7)
				end
			end
			-- Haut du pantalon visible en bas du torse
			local bottom = c.bottom
			if c.pants ~= "kimono" and c.outfit ~= "robe" and c.outfit ~= "kimono" then
				S:rect(0.5, 0.965, 1, 0.07, bottom, { gradient = { bottom, shade(bottom, 0.2) }, z = 6 })
				S:rect(0.5, 0.93, 1, S:dy(0.03), inkOf(bottom), { z = 6 })
			end
		end
	end
	for _, limbName in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local part = limbs[limbName]
		if part then
			local isLeft = string.sub(limbName, 1, 4) == "Left"
			local isArm = string.find(limbName, "Arm") ~= nil
			for _, entry in SIDE_NAMES do
				local face, name = entry[1], entry[2]
				local side = name
				if name == "left" then
					side = isLeft and "out" or "in"
				elseif name == "right" then
					side = isLeft and "in" or "out"
				end
				if mode == "parts" and side == "in" then
					continue -- face collée au torse / à l'autre jambe : inutile dans les aperçus
				end
				local S = Painter.sheet(part, face, mode, (isArm and "Sleeve" or "Pants") .. face.Name, 70)
				if isArm then
					paintArm(S, look, c, side, isLeft)
				else
					paintLeg(S, look, c, side, isLeft)
				end
			end
		end
	end
end

-- Ancienne API : torse seul.
function Painter.torso(part: BasePart, look, mode: string?)
	Painter.dress({ Torso = part }, look, mode)
end

-- Panneau de tissu (haori, cape...) : ombrage + motif optionnel.
function Painter.panel(part: BasePart, face: Enum.NormalId, mode: string?, color: Color3, pattern: ((any) -> ())?, o)
	local opts = o or {}
	local S = Painter.sheet(part, face, mode, "Pattern" .. face.Name, 60)
	cloth(S, color)
	if pattern then
		pattern(S)
	end
	if opts.folds ~= false then
		fold(S, 0.25, 0.15, 0.32, 0.75, color, { w = 0.08, z = 6 })
		fold(S, 0.72, 0.2, 0.64, 0.8, color, { w = 0.08, z = 6 })
	end
	if opts.edges ~= false then
		edgeShade(S, "l", 0.14, color, 0, 1, 5)
		edgeShade(S, "r", 0.14, color, 0, 1, 5)
	end
	return S
end

Painter.cloth = cloth
Painter.fold = fold
Painter.band = band
Painter.shade = shade
Painter.celShadow = celShadow
Painter.inkOf = inkOf
Painter.edgeShade = edgeShade

return Painter
