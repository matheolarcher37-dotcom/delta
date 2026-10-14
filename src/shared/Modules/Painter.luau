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

-- Échelle du perso en cours de construction (boss x4.2...) : réglée par CharacterBuilder.build.
-- Les épaisseurs et tailles "en studs" des dessins sont données pour un perso d'échelle 1 :
-- sans cette correction, plis, coutures et contours d'un boss géant devenaient 4 fois plus fins
-- (tenue en gros aplats, sans détails).
Painter.scale = 1

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
			local n = 14
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
	-- Perso géant : un peu plus de pixels qu'à l'échelle 1 (vu de près), sans exploser la mémoire.
	local k = Painter.scale or 1
	gui.PixelsPerStud = pixelsPerStud * math.min(k, 2) / k
	gui.LightInfluence = 1
	-- Distance d'affichage proportionnelle à la taille de la pièce (boss géants vus de plus loin).
	local biggest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	gui.MaxDistance = 55 * math.max(1, biggest / 2)
	gui.ClipsDescendants = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	return gui
end

-- Feuille peinte sur une face d'une pièce (SurfaceGui, ou pièces fines si mode == "parts").
function Painter.sheet(part: BasePart, face: Enum.NormalId, mode: string?, name: string?, pixelsPerStud: number?)
	local w, h = faceSize(part.Size, face)
	local k = Painter.scale or 1
	return newSheet(surface(part, face, name or ("Paint" .. face.Name), pixelsPerStud or 70, mode), w / k, h / k)
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
-- Visage : décalque d'animé (comme les visages des avatars "Kid Naruto"...) dessiné sur les
-- plaques invisibles qui épousent la tête classique (voir CharacterBuilder).
------------------------------------------------------------------------

-- Toile "facettes" : une feuille virtuelle (largeur déroulée du visage) répartie sur plusieurs
-- plaques ; chaque forme n'est dessinée que sur les plaques qu'elle touche.
local Facets = {}
Facets.__index = Facets

function Facets.new(plates, mode: string?, w: number, h: number, pixelsPerStud: number)
	local self = setmetatable({ list = {}, w = w, h = h }, Facets)
	for _, plate in plates do
		local canvas = surface(plate.part, Enum.NormalId.Front, "Face", pixelsPerStud, mode)
		if typeof(canvas) == "Instance" then
			-- Le visage reste affiché plus loin que la tenue (c'est lui qui rend le perso
			-- reconnaissable, aussi loin que le LOD de la tenue) : ~70 Frames, peu coûteux.
			canvas.MaxDistance = 140 * math.max(1, Painter.scale or 1)
		end
		table.insert(self.list, { g = canvas, u0 = plate.u0, u1 = plate.u1 })
	end
	return self
end

function Facets:rect(x: number, y: number, w: number, h: number, color: Color3, o)
	local a = math.rad(o.rotation or 0)
	local ws, hs = w * self.w, h * self.h
	local half = (math.abs(ws * math.cos(a)) + math.abs(hs * math.sin(a))) / 2 / self.w
	if o.stroke then
		half += 0.012
	end
	local first = nil
	for _, f in self.list do
		if x + half > f.u0 and x - half < f.u1 then
			local k = f.u1 - f.u0
			local made = rect(f.g, (x - f.u0) / k, y, w / k, h, color, o)
			first = first or made
		end
	end
	return first
end

-- Inclinaison des paupières et des sourcils (studs de dénivelé, positif = air sévère).
local LID_TILT = { angry = 0.035, fierce = 0.012, happy = -0.012, calm = 0, smirk = 0.006, sad = -0.03 }

------------------------------------------------------------------------
-- Gabarits de visage : chaque perso choisit ses yeux, sa bouche et ses sourcils
-- (look.eyeStyle, look.mouthStyle, look.browStyle). Sans choix explicite, le gabarit
-- vient du caractère (look.face). Dimensions en studs pour une tête d'échelle 1.
------------------------------------------------------------------------

-- Yeux :
--   w, h      : taille du blanc ; iris (largeur relative), irisH (hauteur relative)
--   cut       : paupière supérieure qui couvre cette fraction du haut de l'œil (au centre)
--   drop      : dénivelé de cette paupière (positif = coin intérieur plus bas : regard sévère)
--   wing      : trait de cils prolongé vers l'extérieur ; lashes : nombre de cils (persos féminins)
--   crease    : pli de paupière au-dessus (yeux mi-clos) ; shine3 : troisième reflet (yeux ronds)
local EYE_STYLES = {
	-- Grands yeux ronds et pétillants (Maruto, Loffy, Nezoko)
	round = { w = 0.27, h = 0.25, iris = 0.64, irisH = 0.92, corner = 0.5, shine3 = true, arc = 0.03 },
	-- Yeux francs de héros de shonen (Goko, Tanjiru)
	bold = { w = 0.27, h = 0.2, iris = 0.6, irisH = 0.95, corner = 0.45, arc = 0.015 },
	-- Plissés et menaçants (Sasuki, Itochi, boss)
	sharp = { w = 0.3, h = 0.16, iris = 0.5, irisH = 0.98, corner = 0.35, cut = 0.34, drop = 0.075, wing = true },
	-- Froids, étroits (Megumo, Zoru)
	narrow = { w = 0.3, h = 0.15, iris = 0.48, irisH = 1, corner = 0.4, cut = 0.28, drop = 0.03, wing = true },
	-- Mi-clos, blasés (Kakashu, Shikamaro)
	sleepy = { w = 0.27, h = 0.2, iris = 0.56, irisH = 0.95, corner = 0.45, cut = 0.5, drop = -0.012, crease = true },
	-- Féminins avec cils (Sakoura, Nomi)
	feminine = { w = 0.27, h = 0.235, iris = 0.62, irisH = 0.94, corner = 0.5, lashes = 3, shine3 = true, arc = 0.03 },
	-- Doux (persos calmes)
	soft = { w = 0.26, h = 0.2, iris = 0.6, irisH = 0.94, corner = 0.48, arc = 0.02 },
	-- Écarquillés, petit iris (fous, apeurés : Zenitso, démons)
	wide = { w = 0.28, h = 0.24, iris = 0.36, irisH = 0.5, corner = 0.5, lowerFull = true },
	-- Étroits à paupières lourdes, regard qui toise (moine maudit, manipulateurs)
	heavy = { w = 0.31, h = 0.17, iris = 0.5, irisH = 1, corner = 0.4, cut = 0.52, drop = 0.035, wing = true, crease = true },
}
local MOOD_EYES = { angry = "sharp", smirk = "narrow", happy = "round", fierce = "bold", calm = "soft", sad = "soft" }

-- Sourcils : th (épaisseur), half (demi-longueur), arch (bosse au milieu), tilt (pente, + = froncé)
local BROW_STYLES = {
	bold = { th = 0.042, half = 0.125, arch = 0.012, tilt = 0.03 },
	frown = { th = 0.052, half = 0.13, arch = -0.008, tilt = 0.1 },
	thick = { th = 0.085, half = 0.15, arch = 0.005, tilt = 0.04 },
	arched = { th = 0.022, half = 0.12, arch = 0.035, tilt = -0.025 },
	flat = { th = 0.034, half = 0.115, arch = 0.004, tilt = 0 },
	raised = { th = 0.03, half = 0.115, arch = 0.018, tilt = -0.05, lift = 0.035 },
	short = { th = 0.05, half = 0.075, arch = 0, tilt = 0.035 },
	thin = { th = 0.026, half = 0.12, arch = 0.012, tilt = 0.035 },
	-- Épais, très froncés et bas sur les yeux (regard noir des boss : amiral, brutes)
	glower = { th = 0.085, half = 0.15, arch = -0.012, tilt = 0.15, lift = -0.03 },
	-- Fins mais bas et froncés (menace froide : moine maudit)
	low = { th = 0.034, half = 0.13, arch = -0.006, tilt = 0.09, lift = -0.035 },
}
local MOOD_BROWS = { angry = "frown", fierce = "bold", happy = "bold", calm = "flat", smirk = "bold", sad = "raised" }
local MOOD_MOUTHS = { angry = "frown", fierce = "smile", happy = "smile", calm = "line", smirk = "smirk", sad = "sad" }

local EYE_WHITE = Color3.fromRGB(236, 241, 247)

-- Feuille du visage en studs : x le long de la courbe (+ = droite de l'observateur),
-- y dans le repère de la tête (0 = centre de la tête, + vers le haut).
local function faceTools(S, centerY: number)
	local T = {}
	local function X(xs: number): number
		return 0.5 + xs / S.w
	end
	local function Y(ys: number): number
		return 0.5 - (ys - centerY) / S.h
	end
	T.X, T.Y = X, Y
	T.lite = S.lite
	function T.oval(x: number, y: number, w: number, h: number, color: Color3, o: RectOptions?)
		return S:oval(X(x), Y(y), w, h, color, o)
	end
	function T.box(x: number, y: number, w: number, h: number, color: Color3, o: RectOptions?)
		return S:box(X(x), Y(y), w, h, color, o)
	end
	function T.line(x0: number, y0: number, x1: number, y1: number, th: number, color: Color3, o: RectOptions?)
		return S:line(X(x0), Y(y0), X(x1), Y(y1), th, color, o)
	end
	-- Courbe douce en 3 segments (de (x0,y0) à (x1,y1), bosse `bulge` au milieu)
	function T.curve(x0: number, y0: number, x1: number, y1: number, bulge: number, th: number, color: Color3, o: RectOptions?)
		local mx, my = (x0 + x1) / 2, (y0 + y1) / 2 + bulge
		local ax, ay = (x0 + mx) / 2, (y0 + my) / 2 + bulge * 0.35
		local bx, by = (mx + x1) / 2, (my + y1) / 2 + bulge * 0.35
		T.line(x0, y0, ax, ay, th, color, o)
		T.line(ax, ay, bx, by, th, color, o)
		T.line(bx, by, x1, y1, th, color, o)
	end
	return T
end

local function eyeStyleOf(look)
	local name = look.eyeStyle or ((look.blush or look.lashes) and "feminine") or MOOD_EYES[look.face or "calm"] or "bold"
	return EYE_STYLES[name] or EYE_STYLES.bold
end
Painter.EyeStyles = EYE_STYLES

-- Un œil. `s` = 1 pour l'œil de droite (vu de face), -1 pour celui de gauche.
local function eye(T, look, cx: number, cy: number, s: number, k: number)
	local st = eyeStyleOf(look)
	local iris = look.eyes or Color3.fromRGB(80, 55, 40)
	local lash = look.lashColor or INK
	local skin = look.skin or DEFAULT_SKIN
	local W, H = (look.eyeWidth or st.w) * k, (look.eyeHeight or st.h) * k
	if look.eyeStyle == nil and look.eyeHeight == nil and (look.face == "angry" or look.face == "smirk") and not st.cut then
		H *= 0.82
	end
	if look.eyeShadow then
		-- Pigments autour des yeux (mode Ermite...)
		T.oval(cx + s * 0.02, cy + 0.01, W * 1.5, H * 1.75, look.eyeShadow, { fade = { 0.1, 0.35, 0.8 }, gradientRotation = 90, z = 1 })
	end
	-- Blanc de l'œil (ombre de la paupière en haut)
	local white = look.scleraColor or EYE_WHITE
	T.box(cx, cy - 0.005, W, H, white, { corner = st.corner, gradient = { Painter.shade(white, 0.25), white, white }, z = 2 })
	-- Iris : sombre sous la paupière, clair en bas, cerclé
	local IW, IH = W * st.iris, H * st.irisH
	local ix, iy = cx + s * W * 0.04, cy - H * (st.lowerFull and 0 or 0.03)
	if st.cut then
		iy += H * 0.04
	end
	-- irisRainbow : iris en dégradé arc-en-ciel (deuxième lune démoniaque)
	local irisRamp = look.irisRainbow
			and {
				Color3.fromRGB(120, 200, 255),
				Color3.fromRGB(110, 230, 150),
				Color3.fromRGB(255, 220, 90),
				Color3.fromRGB(255, 120, 150),
				Color3.fromRGB(190, 120, 255),
			}
		or { darken(iris, 0.65), darken(iris, 0.1), lighten(iris, 0.42) }
	T.oval(ix, iy, IW, IH, iris, {
		gradient = irisRamp,
		stroke = not T.lite and darken(iris, 0.78) or nil,
		strokeThickness = 1,
		z = 3,
	})
	-- Pupille
	local pupil = look.pupilColor or darken(iris, 0.88)
	if look.pupil == "bar" then
		T.box(ix, iy, IW * 0.85, IH * 0.18, pupil, { corner = 0.3, z = 4 })
	elseif look.pupil == "slit" then
		T.oval(ix, iy, IW * 0.2, IH * 0.78, pupil, { z = 4 })
	elseif look.pupil == "ring" then
		for _, r in { 0.82, 0.55 } do
			T.oval(ix, iy, IW * r, IH * r, pupil, { transparency = 1, stroke = pupil, strokeThickness = 1.2, z = 4 })
		end
		T.oval(ix, iy, IW * 0.22, IH * 0.22, pupil, { z = 4 })
	elseif look.pupil == "tomoe" then
		-- Yeux rouges à trois virgules (clan maudit)
		T.oval(ix, iy, IW * 0.62, IH * 0.62, pupil, { transparency = 1, stroke = pupil, strokeThickness = 1, z = 4, fine = true })
		T.oval(ix, iy, IW * 0.28, IH * 0.28, pupil, { z = 4 })
		for i = 0, 2 do
			local a = math.rad(90 + i * 120)
			T.oval(ix + math.cos(a) * IW * 0.31, iy + math.sin(a) * IH * 0.31, IW * 0.2, IW * 0.2, pupil, { z = 5 })
		end
	elseif look.pupil ~= "none" then
		T.oval(ix, iy + H * 0.03, IW * (st.cut and 0.4 or 0.46), IH * 0.48, pupil, { z = 4 })
	end
	-- Reflets (gros reflet en haut, petit en bas ; un troisième pour les yeux ronds)
	if look.pupil ~= "none" or look.eyeGlow then
		local up = st.cut and IH * 0.05 or IH * 0.22
		T.oval(ix + IW * 0.2, iy + up, IW * 0.38, IW * 0.38, WHITE, { z = 6 })
		T.oval(ix - IW * 0.22, iy - IH * 0.24, IW * 0.18, IW * 0.18, WHITE, { transparency = 0.15, z = 6 })
		if st.shine3 and not T.lite then
			T.oval(ix - IW * 0.05, iy + IH * 0.3, IW * 0.12, IW * 0.12, WHITE, { transparency = 0.3, z = 6, fine = true })
		end
	end
	local th = (look.lashThickness or 0.05) * k
	local innerX, outerX = cx - s * W * 0.52, cx + s * W * 0.56
	if st.cut then
		-- Paupière lourde : un pan de peau incliné recouvre le haut de l'œil, le trait de cils
		-- suit son bord (regard plissé, menaçant ou blasé).
		local drop = (look.lidDrop or st.drop) * k
		local a = s * math.atan2(drop, W)
		local ca, sa = math.cos(a), math.sin(a)
		local mx, my = cx, cy - 0.005 + H / 2 - st.cut * H
		local hb = H * 1.2
		T.box(mx - sa * hb / 2, my + ca * hb / 2, W * 1.4, hb, skin, { rotation = -math.deg(a), z = 6.5 })
		local ox, oy = mx + s * ca * W * 0.6, my + s * sa * W * 0.6
		local nx, ny = mx - s * ca * W * 0.55, my - s * sa * W * 0.55
		T.line(nx, ny, ox, oy, th * 1.1, lash, { z = 7 })
		-- Ombre de la paupière juste sous le trait
		T.line(nx, ny - 0.02 * k, ox, oy - 0.02 * k, H * 0.18, darken(iris, 0.75), { transparency = 0.65, z = 6, fine = true, corner = 0.3 })
		if st.wing then
			T.line(ox, oy, ox + s * 0.05 * k, oy + 0.012 * k, th * 0.75, lash, { z = 7 })
		end
		if st.crease then
			T.line(nx, ny + 0.055 * k, ox, oy + 0.05 * k, th * 0.35, Painter.shade(skin, 0.45), { transparency = 0.2, z = 7, fine = T.lite })
		end
	else
		-- Trait de cils supérieur : épais, en arc, avec un petit crochet au coin extérieur
		local tilt = (LID_TILT[look.face or "calm"] or 0) * k
		local top = cy + H * 0.44
		local innerY, outerY = top - tilt - H * 0.08, top + tilt * 0.5
		local midX = cx + s * W * 0.06
		local midY = top + (st.arc or 0.012) * k
		T.line(innerX, innerY, midX, midY, th * 0.8, lash, { z = 7 })
		T.line(midX, midY, outerX, outerY, th, lash, { z = 7 })
		T.line(outerX, outerY, outerX + s * 0.035 * k, outerY - H * 0.3, th * 0.75, lash, { z = 7 })
		-- Ombre de la paupière sur le haut de l'œil (sous le trait)
		T.box(cx, top - H * 0.1, W * 0.96, H * 0.2, darken(iris, 0.75), { corner = 0.4, transparency = 0.7, z = 6, fine = true })
		if st.lashes then
			-- Cils longs (persos féminins) : trois cils qui s'envolent au coin extérieur
			for i = 0, st.lashes - 1 do
				local bx = outerX - s * i * 0.035 * k
				local by = outerY + (i == 0 and 0 or 0.01 * k)
				T.line(bx, by, bx + s * (0.07 - i * 0.012) * k, by + (0.03 + i * 0.022) * k, (0.024 - i * 0.003) * k, lash, { z = 7 })
			end
		end
	end
	-- Trait inférieur (moitié extérieure, ou tout le tour pour les yeux écarquillés)
	if st.lowerFull then
		T.line(cx - s * W * 0.45, cy - H * 0.46, cx + s * W * 0.45, cy - H * 0.46, 0.016 * k, lash, { transparency = 0.2, z = 7, fine = T.lite })
	else
		T.line(cx - s * W * 0.1, cy - H * 0.5, cx + s * W * 0.5, cy - H * 0.36, 0.016 * k, lash, { transparency = 0.25, z = 7, fine = T.lite })
	end
	if st.lashes and not T.lite then
		T.line(cx + s * W * 0.42, cy - H * 0.4, cx + s * W * 0.56, cy - H * 0.5, 0.012 * k, lash, { z = 7, fine = true })
	end
end

local function brows(T, look, skin: Color3, eyeX: number, eyeY: number, k: number)
	local face = look.face or "calm"
	local name = look.browStyle or (look.bigBrows and "thick") or (look.browThin and "thin") or ((look.blush or look.lashes) and "arched") or MOOD_BROWS[face] or "bold"
	if name == "none" then
		return
	end
	local st = BROW_STYLES[name] or BROW_STYLES.bold
	local color = look.browColor or Painter.shade(look.hairColor or INK, 0.35)
	if look.hair == "bald" or look.hair == "none" then
		color = darken(skin, 0.45)
	end
	local thick = st.th * k
	local half = st.half * k
	local by = eyeY + ((look.browY or 0.155) + (st.lift or 0)) * k
	for _, s in { -1, 1 } do
		local tilt = (look.browTilt or st.tilt) * k
		local lift = 0
		if face == "smirk" and s > 0 and look.browStyle == nil then
			-- Sourcil relevé d'un côté (air narquois)
			tilt = -0.03 * k
			lift = 0.015
		end
		local cx = s * eyeX
		local ix, iy = cx - s * half, by - tilt / 2 + lift
		local ox, oy = cx + s * half * 1.08, by + tilt / 2 + lift
		local mx, my = (ix + ox) / 2, (iy + oy) / 2 + st.arch * k
		-- Sourcil effilé : épais côté intérieur, fin vers l'extérieur
		T.line(ix, iy, mx, my, thick, color, { z = 8 })
		T.line(mx, my, ox, oy, thick * 0.62, color, { z = 8 })
		if name == "thick" then
			T.line(ix, iy - thick * 0.25, ox, oy - thick * 0.2, thick * 0.8, color, { z = 8 })
		elseif name == "glower" then
			-- Masse du sourcil (deux couches) qui écrase l'œil
			T.line(ix, iy - thick * 0.3, ox, oy - thick * 0.25, thick * 0.75, color, { z = 8 })
			if not T.lite then
				T.line(s * 0.035, by - 0.02, s * 0.055, by - 0.09, 0.014 * k, Painter.shade(skin, 0.5), { transparency = 0.15, z = 7, fine = true })
			end
		elseif (name == "frown" or name == "low") and not T.lite then
			-- Ride du froncement entre les sourcils
			T.line(s * 0.035, by - 0.01, s * 0.05, by - 0.07, 0.012 * k, Painter.shade(skin, 0.45), { transparency = 0.25, z = 7, fine = true })
		end
	end
end

local TEETH = Color3.fromRGB(232, 236, 242)

local function mouth(T, look, skin: Color3, y: number)
	local face = look.face or "calm"
	local style = look.mouthStyle or MOOD_MOUTHS[face] or "line"
	local lip = Painter.shade(skin, 0.4)
	local w = look.mouthWidth or 0.18
	if look.blush and not look.mouthWidth then
		w *= 0.8
	end
	local th = 0.018
	if style == "toothy" then
		-- Petite bouche en trait, sourire en coin avec une dent visible (comme Kid Naruto)
		T.curve(-w * 0.5, y + 0.012, w * 0.45, y + 0.004, -0.018, th, INK, { z = 3 })
		T.line(w * 0.45, y + 0.004, w * 0.6, y + 0.04, 0.015, INK, { z = 3 })
		T.box(w * 0.28, y - 0.012, 0.045, 0.036, TEETH, { corner = 0.25, stroke = not T.lite and INK or nil, strokeThickness = 1, z = 2 })
		T.box(0, y - 0.03, w * 0.35, 0.012, lip, { corner = 0.5, transparency = 0.5, z = 2, fine = true })
	elseif style == "grin" or style == "wide_grin" then
		-- Grand sourire ouvert en "D" (rangée de dents en haut, langue)
		local ww = style == "wide_grin" and w * 1.6 or w * 1.15
		local hh = style == "wide_grin" and 0.15 or 0.12
		T.oval(0, y - 0.01, ww, hh, MOUTH, { stroke = not T.lite and INK or nil, strokeThickness = 1.3, z = 2 })
		T.box(0, y + hh * 0.42, ww * 1.15, hh * 0.5, skin, { z = 3 })
		T.box(0, y + 0.01, ww * 0.8, hh * 0.24, TEETH, { corner = 0.3, z = 4 })
		T.oval(0, y - hh * 0.32, ww * 0.45, hh * 0.32, TONGUE, { z = 4 })
		T.curve(-ww * 0.56, y + 0.026, ww * 0.56, y + 0.026, -0.008, th, INK, { z = 5 })
		T.line(ww * 0.56, y + 0.026, ww * 0.62, y + 0.05, 0.014, INK, { z = 5 })
		T.line(-ww * 0.56, y + 0.026, -ww * 0.62, y + 0.05, 0.014, INK, { z = 5 })
	elseif style == "teeth" then
		-- Dents serrées (effort, rage contenue)
		T.box(0, y, w, 0.062, TEETH, { corner = 0.4, stroke = INK, strokeThickness = 1.5, gradient = { WHITE, TEETH, Color3.fromRGB(190, 200, 215) }, z = 2 })
		T.line(-w * 0.45, y + 0.002, w * 0.45, y + 0.002, 0.008, Color3.fromRGB(150, 160, 178), { corner = 0, z = 3 })
		for i = 1, 4 do
			local x = -w / 2 + w * i / 5
			T.line(x, y + 0.026, x, y - 0.026, 0.007, Color3.fromRGB(160, 168, 185), { corner = 0, z = 3, fine = true })
		end
	elseif style == "snarl" or style == "fang" then
		-- Rictus ouvert de démon : dents et crocs
		local ww = w * 1.25
		T.box(0, y, ww, 0.075, MOUTH, { corner = 0.35, stroke = not T.lite and INK or nil, strokeThickness = 1.4, z = 2 })
		T.box(0, y + 0.022, ww * 0.92, 0.025, TEETH, { corner = 0.2, z = 3 })
		T.box(0, y - 0.024, ww * 0.8, 0.018, TEETH, { corner = 0.2, z = 3 })
		for _, sx in { -1, 1 } do
			T.line(sx * ww * 0.3, y + 0.03, sx * ww * 0.27, y - 0.02, 0.026, TEETH, { corner = 0.1, z = 4 })
		end
		T.line(ww * 0.5, y + 0.01, ww * 0.62, y + 0.05, 0.016, INK, { z = 4 })
		T.line(-ww * 0.5, y + 0.01, -ww * 0.62, y + 0.05, 0.016, INK, { z = 4 })
	elseif style == "smile" then
		-- Sourire fermé, confiant
		T.curve(-w * 0.45, y + 0.02, w * 0.45, y + 0.02, -0.03, th, INK, { z = 2 })
		T.box(0, y - 0.035, w * 0.3, 0.012, lip, { corner = 0.5, transparency = 0.45, z = 2, fine = true })
	elseif style == "smirk" then
		-- Sourire en coin, asymétrique
		T.line(-w * 0.42, y - 0.004, w * 0.25, y + 0.002, th, INK, { z = 2 })
		T.line(w * 0.25, y + 0.002, w * 0.5, y + 0.045, 0.016, INK, { z = 2 })
		T.line(w * 0.5, y + 0.045, w * 0.55, y + 0.03, 0.01, INK, { z = 2, fine = true })
		T.box(w * 0.05, y - 0.03, w * 0.3, 0.012, lip, { corner = 0.5, transparency = 0.4, z = 2, fine = true })
	elseif style == "sneer" then
		-- Demi-sourire en coin, cruel : un seul coin relevé et creusé, l'autre tombe, lèvre fine
		T.line(-w * 0.5, y - 0.02, -w * 0.1, y - 0.002, th, INK, { z = 2 })
		T.line(-w * 0.1, y - 0.002, w * 0.38, y + 0.012, th, INK, { z = 2 })
		T.line(w * 0.38, y + 0.012, w * 0.6, y + 0.06, 0.018, INK, { z = 2 })
		T.line(w * 0.56, y + 0.07, w * 0.64, y + 0.035, 0.012, INK, { z = 2, fine = true })
		if not T.lite then
			-- Fossette du rictus et ombre de la lèvre inférieure
			T.line(w * 0.66, y + 0.08, w * 0.7, y - 0.01, 0.012, Painter.shade(skin, 0.45), { transparency = 0.25, z = 2, fine = true })
		end
		T.box(-w * 0.05, y - 0.032, w * 0.38, 0.012, lip, { corner = 0.5, transparency = 0.35, z = 2, fine = true })
	elseif style == "frown" then
		-- Bouche fermée, coins tombants
		T.curve(-w * 0.42, y - 0.022, w * 0.42, y - 0.022, 0.022, th, INK, { z = 2 })
		T.box(0, y - 0.04, w * 0.28, 0.012, lip, { corner = 0.5, transparency = 0.45, z = 2, fine = true })
	elseif style == "shout" then
		-- Bouche grande ouverte (cri)
		T.oval(0, y - 0.02, w * 0.9, 0.14, MOUTH, { stroke = not T.lite and INK or nil, strokeThickness = 1.4, z = 2 })
		T.box(0, y + 0.035, w * 0.6, 0.022, TEETH, { corner = 0.3, z = 3 })
		T.oval(0, y - 0.06, w * 0.45, 0.04, TONGUE, { z = 3 })
	elseif style == "o" then
		T.oval(0, y - 0.005, 0.075, 0.07, MOUTH, { stroke = not T.lite and INK or nil, strokeThickness = 1.2, z = 2 })
	elseif style == "sad" then
		T.line(-w * 0.35, y - 0.015, 0, y + 0.005, 0.016, INK, { z = 2 })
		T.line(0, y + 0.005, w * 0.35, y - 0.015, 0.016, INK, { z = 2 })
	elseif style == "pout" then
		-- Petite bouche (persos féminins) : court trait et lèvre inférieure
		T.curve(-w * 0.28, y + 0.008, w * 0.28, y + 0.008, -0.01, 0.016, INK, { z = 2 })
		T.box(0, y - 0.02, w * 0.26, 0.016, Color3.fromRGB(235, 140, 150), { corner = 0.5, transparency = 0.35, z = 2 })
	elseif style ~= "none" then
		-- Petit trait
		T.line(-w * 0.32, y, w * 0.32, y, th, INK, { z = 2 })
		T.box(0, y - 0.028, w * 0.26, 0.012, lip, { corner = 0.5, transparency = 0.45, z = 2, fine = true })
	end
end

local function faceMarks(T, look, skin: Color3, eyeX: number, eyeY: number)
	local accColor = look.accColor
	if has(look, "whiskers") then
		-- Trois moustaches de renard par joue
		local ink = look.whiskerColor or Painter.shade(skin, 0.5)
		for _, s in { -1, 1 } do
			for i = 0, 2 do
				local y = eyeY - 0.17 - i * 0.065
				T.line(s * 0.3, y + 0.01 - i * 0.008, s * 0.46, y + 0.025 - i * 0.03, 0.015, ink, { z = 7 })
			end
		end
	end
	if has(look, "freckles") then
		-- Taches de rousseur sur les joues et le nez
		local dot = Painter.shade(skin, 0.32)
		for _, s in { -1, 1 } do
			for i, d in { { 0.16, -0.2 }, { 0.22, -0.17 }, { 0.28, -0.21 }, { 0.2, -0.25 }, { 0.26, -0.27 } } do
				T.oval(s * d[1], eyeY + d[2], 0.026 - (i % 2) * 0.006, 0.026 - (i % 2) * 0.006, dot, { z = 7, fine = true })
			end
		end
	end
	if has(look, "nose_line") then
		-- Trait de sang en travers du nez (bande sombre d'une joue à l'autre)
		local ink = look.markColor or Color3.fromRGB(70, 30, 50)
		T.line(-0.44, eyeY - 0.12, 0.44, eyeY - 0.12, 0.05, ink, { transparency = 0.1, z = 7 })
	end
	if has(look, "sage_lines") then
		-- Longues larmes rouges qui descendent des yeux (ermite)
		local red = look.markColor or Color3.fromRGB(200, 30, 40)
		for _, s in { -1, 1 } do
			T.line(s * (eyeX - 0.05), eyeY - 0.1, s * (eyeX - 0.02), eyeY - 0.36, 0.03, red, { z = 7 })
		end
	end
	if has(look, "tear_lines") then
		for _, s in { -1, 1 } do
			T.line(s * (eyeX - 0.08), eyeY - 0.1, s * (eyeX - 0.1), eyeY - 0.26, 0.018, Painter.shade(skin, 0.55), { z = 7 })
		end
	end
	if has(look, "tattoos") then
		-- Deux traits sous chaque œil + marque sur le front (roi des fléaux)
		for _, s in { -1, 1 } do
			for i = 0, 1 do
				T.line(s * 0.12, eyeY - 0.12 - i * 0.05, s * 0.44, eyeY - 0.15 - i * 0.05, 0.024, INK, { z = 7 })
			end
		end
		T.line(-0.08, eyeY + 0.3, 0.08, eyeY + 0.3, 0.024, INK, { z = 7 })
	end
	if has(look, "tattoos_blue") then
		local ink = accColor or Color3.fromRGB(60, 80, 220)
		for _, s in { -1, 1 } do
			T.line(s * 0.5, eyeY + 0.35, s * 0.5, eyeY - 0.45, 0.018, ink, { z = 7 })
			T.line(s * 0.1, eyeY + 0.38, s * 0.1, eyeY + 0.22, 0.018, ink, { z = 7 })
		end
	end
	if has(look, "extra_eyes") then
		-- Seconds yeux sous les yeux (roi des fléaux)
		for _, s in { -1, 1 } do
			local x, y = s * (eyeX + 0.06), eyeY - 0.2
			T.oval(x, y, 0.13, 0.06, WHITE, { z = 8 })
			T.oval(x, y, 0.055, 0.055, look.eyes or Color3.fromRGB(220, 20, 30), { z = 9 })
			T.line(x - 0.075, y + 0.03 - s * 0.005, x + 0.075, y + 0.03 + s * 0.005, 0.02, INK, { z = 9 })
		end
	end
	if look.curseSpread then
		-- Marque maudite déployée : flammes noires qui envahissent la moitié du visage
		local x0 = eyeX + 0.05
		for i, e in { { 0.12, 0.3, 0.16 }, { -0.1, 0.24, 0.12 }, { 0.16, 0.06, 0.15 }, { -0.04, -0.12, 0.13 }, { 0.12, -0.32, 0.14 } } do
			local x, y = x0 + e[1], eyeY + e[2]
			T.line(x, y, x + 0.12, y + 0.12, e[3] * 0.45, INK, { z = 9 })
			T.line(x, y, x - 0.08, y + 0.1, e[3] * 0.3, INK, { z = 9 })
			T.oval(x, y, e[3], e[3] * 0.7, INK, { z = 9 })
			if i % 2 == 0 then
				T.line(x - 0.05, y - 0.02, x - 0.16, y + 0.06, 0.02, INK, { z = 9 })
			end
		end
	end
	if has(look, "curse_mark") and not look.curseSpread then
		-- Marque maudite : virgules noires en flammes sur la joue et la tempe gauches
		local x0 = eyeX + 0.12
		for i, e in { { 0.0, 0.18, 0.13 }, { 0.06, -0.02, 0.11 }, { -0.02, -0.22, 0.12 } } do
			local x, y = x0 + e[1], eyeY + e[2]
			T.oval(x, y, e[3], e[3] * 0.85, INK, { z = 9 })
			T.line(x, y, x + 0.09, y + 0.07 + i * 0.01, 0.035, INK, { z = 9 })
		end
	end
	if has(look, "scar_eye") then
		local x = look.scarSide == "left" and -eyeX or eyeX
		T.line(x + 0.02, eyeY + 0.2, x - 0.03, eyeY - 0.2, 0.022, Color3.fromRGB(150, 50, 50), { z = 9 })
	end
	if has(look, "scar_cheek") then
		local red = Color3.fromRGB(150, 60, 60)
		local x = -eyeX
		T.line(x - 0.08, eyeY - 0.13, x + 0.08, eyeY - 0.13, 0.014, red, { z = 8 })
		for i = -1, 1 do
			T.line(x + i * 0.045, eyeY - 0.1, x + i * 0.045, eyeY - 0.16, 0.011, red, { z = 8 })
		end
	end
	if has(look, "scar_face") then
		T.line(-0.45, eyeY + 0.12, 0.45, eyeY - 0.22, 0.022, Color3.fromRGB(160, 70, 70), { z = 7 })
	end
	if has(look, "scar_forehead") then
		T.oval(-0.16, eyeY + 0.3, 0.17, 0.1, Color3.fromRGB(175, 65, 55), { transparency = 0.2, rotation = -15, z = 7 })
	end
	if has(look, "forehead_mark") then
		local red = Color3.fromRGB(205, 35, 30)
		if look.markLarge then
			-- Marque du pourfendeur pleinement éveillée : grande flamme rouge sur le front et la tempe
			T.oval(-0.2, eyeY + 0.3, 0.3, 0.16, red, { rotation = -18, z = 7 })
			for i, e in { { -0.32, 0.42, -0.4 }, { -0.2, 0.46, -0.24 }, { -0.08, 0.43, -0.06 }, { -0.38, 0.3, -0.5 } } do
				T.line(e[1] + 0.03, eyeY + 0.32, e[1] + e[3] * 0.1, eyeY + e[2], 0.05 - i * 0.004, red, { z = 7 })
			end
			T.oval(-0.36, eyeY + 0.16, 0.1, 0.07, Color3.fromRGB(225, 60, 40), { rotation = 25, z = 7 })
		else
			T.oval(-0.18, eyeY + 0.3, 0.17, 0.1, red, { rotation = -15, z = 7 })
			T.line(-0.22, eyeY + 0.32, -0.26, eyeY + 0.4, 0.035, red, { z = 7 })
			T.line(-0.14, eyeY + 0.33, -0.12, eyeY + 0.41, 0.03, red, { z = 7 })
		end
	end
	if has(look, "brow_ridge") then
		-- Arcade sourcilière marquée, sans sourcils (Super Saiyan 3)
		local ridge = Painter.shade(skin, 0.42)
		for _, s in { -1, 1 } do
			T.line(s * (eyeX - 0.14), eyeY + 0.16, s * (eyeX + 0.16), eyeY + 0.2, 0.022, ridge, { z = 7 })
			T.line(s * 0.04, eyeY + 0.14, s * (eyeX - 0.14), eyeY + 0.16, 0.03, ridge, { z = 7 })
		end
	end
	if has(look, "dots") then
		for row = 0, 1 do
			for col = -1, 1 do
				T.oval(col * 0.08, eyeY + 0.33 + row * 0.07, 0.035, 0.035, darken(skin, 0.4), { z = 7 })
			end
		end
	end
	if has(look, "facepaint") then
		local paint = accColor or Color3.fromRGB(140, 50, 180)
		for _, s in { -1, 1 } do
			T.line(s * eyeX, eyeY - 0.12, s * eyeX, eyeY - 0.35, 0.03, paint, { z = 7 })
			T.line(s * (eyeX - 0.08), eyeY + 0.22, s * (eyeX + 0.08), eyeY + 0.22, 0.025, paint, { z = 7 })
		end
	end
	if has(look, "stitches") then
		T.line(-0.45, eyeY + 0.12, 0.45, eyeY - 0.3, 0.016, INK, { z = 8 })
		for i = -3, 3 do
			local x = i * 0.12
			local y = eyeY - 0.09 - i * 0.049
			T.line(x - 0.01, y + 0.035, x + 0.01, y - 0.035, 0.012, INK, { z = 8 })
		end
	end
	if has(look, "stitches_forehead") then
		-- Cicatrice qui fait tout le tour du front : peau boursouflée rosée, fil sombre, points croisés
		local y = eyeY + 0.33
		T.box(0, y, 1.0, 0.07, Color3.fromRGB(214, 150, 150), { transparency = 0.45, fade = { 0.8, 0.2, 0.2, 0.8 }, gradientRotation = 0, z = 7 })
		T.line(-0.5, y, 0.5, y, 0.02, Color3.fromRGB(60, 34, 50), { z = 8 })
		for i = -4, 4 do
			local x = i * 0.11
			T.line(x - 0.018, y + 0.04, x + 0.018, y - 0.04, 0.014, INK, { z = 9 })
			if not T.lite then
				T.line(x + 0.018, y + 0.04, x - 0.018, y - 0.04, 0.01, Color3.fromRGB(80, 50, 70), { z = 9, fine = true })
			end
		end
	end
	if has(look, "glasses") then
		local frame = look.glassesColor or INK
		for _, s in { -1, 1 } do
			T.box(s * eyeX, eyeY, 0.34, 0.24, Color3.fromRGB(190, 225, 255), { corner = 0.3, transparency = 0.72, stroke = frame, strokeThickness = 2.2, z = 10 })
		end
		T.line(-eyeX + 0.17, eyeY + 0.04, eyeX - 0.17, eyeY + 0.04, 0.025, frame, { z = 10 })
	end
	if look.blush then
		for _, s in { -1, 1 } do
			local x, y = s * (eyeX + 0.06), eyeY - 0.2
			T.oval(x, y, 0.18, 0.08, Color3.fromRGB(255, 120, 145), { fade = { 0.75, 0.4, 0.75 }, gradientRotation = 0, z = 1 })
			for i = -1, 1 do
				T.line(x + i * 0.05 - 0.012, y - 0.012, x + i * 0.05 + 0.012, y + 0.012, 0.01, Color3.fromRGB(230, 90, 110), { z = 2, fine = true })
			end
		end
	end
end

-- Dessine un visage d'animé sur les plaques du visage (`plates` = { {part, u0, u1} }).
-- `geom` = { width, height, centerY } (voir CharacterBuilder.Face).
function Painter.face(plates, look, mode: string?, geom)
	if has(look, "boar_head") then
		return nil
	end
	local skin = look.skin or DEFAULT_SKIN
	local canvas = Facets.new(plates, mode, geom.width, geom.height, 180)
	local S = newSheet(canvas, geom.width, geom.height)
	S.lite = mode == "parts"
	local T = faceTools(S, geom.centerY)
	T.lite = S.lite
	local hideEyes = has(look, "blindfold")
	local eyeY = look.eyeY or 0.03
	local eyeX = look.eyeX or 0.25
	local k = look.eyeScale or 1
	-- Ombre portée des cheveux / du bandeau sur le front
	if look.hair ~= "bald" and look.hair ~= "none" then
		local shadowY = 0.42
		if look.headbandY and (has(look, "headband") or has(look, "headband_tilted") or has(look, "headband_scratched")) then
			shadowY = look.headbandY - (look.headbandHeight or 0.36) / 2 - 0.04
		end
		T.box(0, shadowY, 1.3, 0.12, Painter.shade(skin, 0.4), { fade = { 0.55, 1 }, gradientRotation = 90, z = 1, fine = true })
	end
	if look.visorShadow then
		-- Ombre portée de la visière (casquette, chapeau) : le haut du visage dans l'ombre
		local v = look.visorShadow
		T.box(0, 0.32, 1.3, 0.3, Painter.shade(skin, 0.5), { fade = { 0.1, 0.45, 1 }, gradientRotation = 90, z = 1 })
		T.box(0, 0.42, 1.3, 0.1, Painter.shade(skin, 0.65), { transparency = 1 - v, z = 1 })
	end
	if look.sideburns then
		-- Pattes : bande de cheveux devant l'oreille, qui s'effile vers la mâchoire
		for _, sx in { -1, 1 } do
			T.box(sx * 0.565, 0.16, 0.12, 0.3, look.sideburns, { corner = 0.25, z = 3 })
			T.line(sx * 0.56, 0.02, sx * 0.53, -0.12, 0.07, look.sideburns, { z = 3 })
			if not T.lite then
				T.line(sx * 0.505, 0.28, sx * 0.495, -0.08, 0.012, darken(look.sideburns, 0.5), { transparency = 0.3, z = 3, fine = true })
			end
		end
	end
	if look.headShade then
		-- Ombrage des côtés de la tête (le volume se lit même sur une peau très claire)
		T.box(-0.53, -0.02, 0.2, 1.0, look.headShade, { fade = { 0.15, 1 }, gradientRotation = 0, z = 1 })
		T.box(0.53, -0.02, 0.2, 1.0, look.headShade, { fade = { 1, 0.15 }, gradientRotation = 0, z = 1 })
		T.box(0, -0.46, 1.2, 0.12, look.headShade, { fade = { 1, 0.3 }, gradientRotation = 90, z = 1 })
	end
	if look.cheekShade then
		-- Joues creusées / pommettes sombres (sous les yeux, vers l'extérieur)
		for _, sx in { -1, 1 } do
			T.oval(sx * 0.4, eyeY - 0.2, 0.2, 0.28, look.cheekShade, { transparency = 0.35, fade = { 0.2, 0.8 }, gradientRotation = sx > 0 and 0 or 180, z = 1 })
			T.line(sx * 0.3, eyeY - 0.14, sx * 0.4, eyeY - 0.34, 0.016, darken(look.cheekShade, 0.3), { transparency = 0.2, z = 2, fine = true })
		end
	end
	if look.jawShade then
		-- Mâchoire carrée : ombre sous les pommettes et ligne de mâchoire marquée
		local jc = Painter.shade(skin, 0.42)
		for _, sx in { -1, 1 } do
			T.line(sx * 0.5, -0.08, sx * 0.32, -0.42, 0.05, jc, { transparency = 0.45, z = 1 })
			T.line(sx * 0.32, -0.42, sx * 0.12, -0.47, 0.04, jc, { transparency = 0.5, z = 1 })
		end
		T.box(0, -0.43, 0.22, 0.05, jc, { corner = 0.5, transparency = 0.6, z = 1, fine = true })
	end
	if not hideEyes then
		if has(look, "cyclops") then
			eye(T, look, 0, eyeY, 1, 1.6)
		else
			eye(T, look, -eyeX, eyeY, -1, k)
			eye(T, look, eyeX, eyeY, 1, k)
		end
		if not has(look, "cyclops") then
			brows(T, look, skin, eyeX, eyeY, k)
		end
	end
	-- Petit nez rosé
	local nose = skin:Lerp(Color3.fromRGB(190, 95, 90), 0.38)
	local noseY = look.noseY or (eyeY - 0.31)
	T.oval(0.01, noseY, 0.1, 0.045, nose, { transparency = 0.1, z = 2 })
	T.line(0.03, noseY + 0.11, 0.0, noseY + 0.025, 0.016, Painter.shade(skin, 0.3), { transparency = 0.5, z = 2, fine = true })
	if not has(look, "mask_lower") and not has(look, "muzzle") and not has(look, "mask_bandage") and not has(look, "collar_high") then
		mouth(T, look, skin, look.mouthY or (eyeY - 0.46))
	end
	if look.lipColor then
		-- Lèvres colorées (empereur du froid : lèvres violettes)
		local my = look.mouthY or (eyeY - 0.46)
		T.box(0.01, my - 0.016, 0.17, 0.045, look.lipColor, { corner = 0.5, gradient = { lighten(look.lipColor, 0.2), look.lipColor, darken(look.lipColor, 0.3) }, z = 1 })
		T.line(-0.085, my + 0.004, 0.09, my + 0.006, 0.014, darken(look.lipColor, 0.55), { z = 3 })
	end
	if look.eyeMarks then
		-- Marques sous les yeux (traits qui prolongent le coin extérieur vers la joue)
		for _, s in { -1, 1 } do
			local x = s * (eyeX + 0.1 * k)
			T.line(x, eyeY - 0.02, x + s * 0.05, eyeY - 0.2, 0.026, look.eyeMarks, { z = 8 })
			T.line(s * (eyeX - 0.02), eyeY - 0.11, s * (eyeX + 0.06), eyeY - 0.13, 0.018, look.eyeMarks, { transparency = 0.2, z = 8 })
		end
	end
	if look.eyeKanji and not T.lite then
		-- Rang de lune démoniaque gravé dans les iris : petits traits dans chaque œil
		for _, s in { -1, 1 } do
			local x = s * eyeX
			T.line(x - 0.035, eyeY + 0.01, x + 0.035, eyeY + 0.01, 0.012, look.eyeKanji, { z = 5, corner = 0 })
			T.line(x - 0.025, eyeY - 0.03, x + 0.025, eyeY - 0.03, 0.012, look.eyeKanji, { z = 5, corner = 0 })
			T.line(x, eyeY + 0.03, x, eyeY - 0.05, 0.01, look.eyeKanji, { z = 5, corner = 0 })
		end
	end
	faceMarks(T, look, skin, eyeX, eyeY)
	return canvas
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
		return color:Lerp(Color3.fromRGB(95, 105, 135), 0.3)
	end
	return shade(color, 0.3)
end

-- Encre des plis et coutures.
local function inkOf(color: Color3): Color3
	if luminance(color) < 0.16 then
		return color:Lerp(Color3.fromRGB(150, 160, 190), 0.42)
	end
	return color:Lerp(Color3.fromRGB(22, 14, 14), 0.84)
end

-- Fond d'une face de vêtement : dégradé vertical (haut éclairé, bas plus sombre).
local function cloth(S, color: Color3, o)
	local opts = o or {}
	local top = opts.top or 0
	local bottom = opts.bottom or 1
	local h = bottom - top
	S:rect(0.5, top + h / 2, 1, h, color, {
		gradient = { lighten(color, 0.06), color, shade(color, 0.07) },
		z = opts.z or 0,
		base = top == 0 and bottom == 1,
	})
end

-- Ombre franche le long d'un bord vertical ("l" ou "r"), largeur relative.
local function edgeShade(S, side: string, w: number, color: Color3, top: number?, bottom: number?, z: number?)
	local t, b = top or 0, bottom or 1
	local x = side == "l" and w / 2 or 1 - w / 2
	S:rect(x, (t + b) / 2, w, b - t, celShadow(color), {
		fade = side == "l" and { 0.05, 0.05, 0.12, 1 } or { 1, 0.12, 0.05, 0.05 },
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
	S:line(x0 + ox, y0 + oy, x1 + ox, y1 + oy, w, celShadow(color), { fade = { 0.08, 0.2, 0.85 }, gradientRotation = 90, z = z, fine = true })
	-- Aperçus "pièces" (niveau de détail lite) : seuls les plis principaux sont gardés.
	local fine = opts.fine or (S.lite and w < 0.13)
	S:line(x0, y0, x1, y1, opts.ink or 0.02, inkOf(color), { fade = { 0.7, 0, 0, 0.7 }, gradientRotation = 0, z = z + 1, fine = fine })
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
	creature = "skin",
	biosuit = "skin",
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

-- Le perso porte-t-il un haori (veste ouverte 3D) ?
local function haoriOf(look): boolean
	for _, accessory in look.accessories or {} do
		if string.sub(accessory, 1, 5) == "haori" then
			return true
		end
	end
	return false
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
		haori = haoriOf(look), -- veste ouverte portée par-dessus (cache le dos et le haut des bras)
		carapace = look.carapace,
		nails = look.nails,
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
	if c.nails then
		-- Ongles noirs (possession) : quatre petits ongles au bout des doigts
		for i = 0, 3 do
			S:rect(0.2 + i * 0.2, 0.975, 0.11, S:dy(0.05), c.nails, { corner = 0.3, z = 9 })
		end
	end
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

------------------------------------------------------------------------
-- Veste de ninja (copie de la texture "Kid Naruto") : veste orangée, empiècement bleu nuit sur
-- les épaules et le haut des manches, col en fourrure, patte à fermeture éclair, grandes ombres
-- franches et traits de plis à l'encre ; pantalon assorti, sandales bleu nuit.
------------------------------------------------------------------------

-- Trait d'encre net (pli dessiné).
local function ink(S, x0: number, y0: number, x1: number, y1: number, color: Color3, th: number?, z: number?)
	-- Aperçus "pièces" : seuls les traits principaux (épaisseur par défaut) sont gardés.
	S:line(x0, y0, x1, y1, th or 0.022, inkOf(color), { z = z or 5, fine = S.lite and th ~= nil })
end

-- Ombre franche en "V" (deux bandes qui se rejoignent) : grands plis de la veste.
local function shadowV(S, x0: number, y0: number, xm: number, ym: number, x1: number, y1: number, th: number, color: Color3, z: number?)
	local col = celShadow(color)
	S:line(x0, y0, xm, ym, th, col, { z = z or 2, corner = 0.5 })
	S:line(xm, ym, x1, y1, th * 0.8, col, { z = z or 2, corner = 0.5 })
end

-- Ombre franche "en dents de scie" le long d'un bord ("l" / "r") : bande d'ombre dont le bord
-- intérieur est découpé en pointes anguleuses (comme les ombres peintes à la main des vêtements
-- classiques, au lieu d'ovales qui faisaient des taches). `w` = largeur relative de la bande.
local TEETH_PATTERN = { 1, 0.62, 0.86, 0.5, 0.74 }
local function jagShade(S, edge: string, w: number, y0: number, y1: number, color: Color3, n: number?, z: number?)
	local col = celShadow(color)
	local zz = z or 1
	local x = edge == "l" and w / 2 or 1 - w / 2
	S:rect(x, (y0 + y1) / 2, w, y1 - y0, col, { z = zz })
	local count = n or 3
	local bx = edge == "l" and w or 1 - w
	for i = 1, count do
		local y = y0 + (y1 - y0) * (i - 0.5) / count
		local size = (y1 - y0) * S.h / count * 0.92 * TEETH_PATTERN[(i - 1) % #TEETH_PATTERN + 1]
		local dir = edge == "l" and 1 or -1
		S:box(bx + dir * S:dx(size * 0.12), y, size, size * 0.62, col, { rotation = dir * (40 + i * 7), z = zz })
	end
end
Painter.jagShade = jagShade

-- Col en fourrure façon texture classique : bande claire au bord effiloché, petits traits de poils.
local function furCollar(S, y0: number, y1: number, color: Color3, z: number)
	-- Fourrure duveteuse : touffes arrondies de tailles inégales qui débordent sur le bas, creux
	-- bleutés entre les touffes, quelques mèches de poils.
	local cool = color:Lerp(Color3.fromRGB(120, 140, 182), 0.42)
	S:rect(0.5, (y0 + y1) / 2, 1, y1 - y0, color, { gradient = { lighten(color, 0.2), color, cool }, z = z })
	local n = math.max(3, math.floor(S.w / (S.lite and 0.3 or 0.2) + 0.5))
	local tuft = (y1 - y0) * S.h
	for i = 0, n - 1 do
		local x = (i + 0.5) / n
		local big = (i % 3 ~= 1)
		local size = tuft * (big and 0.62 or 0.48)
		S:oval(x, y1 - S:dy(size * (big and 0.18 or 0.3)), size * 1.25, size, i % 2 == 0 and color or lighten(color, 0.1), {
			gradient = { lighten(color, 0.25), color, cool },
			z = z,
		})
		if i % 2 == 1 and not S.lite then
			S:line(x - 0.18 / n, y0 + (y1 - y0) * 0.3, x + 0.05 / n, y0 + (y1 - y0) * 0.75, 0.014, shade(cool, 0.3), { z = z + 1, fine = true })
		end
	end
	-- Ombre de la fourrure sur ce qui est dessous
	S:rect(0.5, y1 + S:dy(0.08), 1, S:dy(0.08), celShadow(S.under or color), { fade = { 0.2, 1 }, gradientRotation = 90, z = z - 1, fine = true })
end

-- Patte de boutonnage avec fermeture éclair (bande verticale cernée d'encre).
local function placket(S, x: number, y0: number, y1: number, color: Color3, z: number)
	local h = y1 - y0
	S:box(x, y0 + h / 2, 0.3, h * S.h, lighten(color, 0.05), { z = z })
	for _, s in { -1, 1 } do
		S:box(x + S:dx(s * 0.15), y0 + h / 2, 0.026, h * S.h, inkOf(color), { z = z + 1 })
	end
	S:box(x + S:dx(0.02), y0 + h / 2, 0.016, h * S.h, Color3.fromRGB(150, 195, 222), { z = z + 1 })
	S:box(x - S:dx(0.02), y0 + h / 2, 0.012, h * S.h, inkOf(color), { transparency = 0.3, z = z + 1, fine = true })
	-- Tirette
	S:box(x + S:dx(0.02), y0 + S:dy(0.1), 0.06, 0.1, METAL, { corner = 0.3, stroke = inkOf(color), strokeThickness = 1, z = z + 2, fine = S.lite })
end

local function jacketFront(S, look, c)
	local top = c.top
	local yoke = look.shoulders or c.accent
	S.under = yoke
	-- Grandes ombres franches (plis en "V" qui convergent vers la patte)
	shadowV(S, -0.02, 0.5, 0.36, 0.64, 0.0, 0.8, 0.22, top)
	shadowV(S, 1.02, 0.5, 0.64, 0.64, 1.0, 0.8, 0.22, top)
	S:rect(0.5, 0.84, 1, 0.06, celShadow(top), { transparency = 0.35, z = 2 })
	edgeShade(S, "l", 0.13, top)
	edgeShade(S, "r", 0.13, top)
	-- Traits de plis
	ink(S, 0.08, 0.56, 0.24, 0.6, top)
	ink(S, 0.14, 0.7, 0.3, 0.68, top, 0.021)
	ink(S, 0.92, 0.56, 0.76, 0.6, top)
	ink(S, 0.86, 0.7, 0.7, 0.69, top, 0.021)
	ink(S, 0.44, 0.75, 0.62, 0.72, top, 0.02)
	-- Bas de la veste froissé (plis encrés serrés au-dessus de l'ourlet)
	ink(S, 0.06, 0.8, 0.2, 0.77, top, 0.018)
	ink(S, 0.27, 0.82, 0.4, 0.78, top, 0.018)
	ink(S, 0.62, 0.79, 0.74, 0.82, top, 0.018)
	ink(S, 0.8, 0.77, 0.94, 0.8, top, 0.018)
	-- Empiècement bleu nuit (épaules + haut de la poitrine), bord inférieur en deux lobes
	S:rect(0.5, 0.28, 1, 0.28, yoke, { gradient = { shade(yoke, 0.25), yoke, lighten(yoke, 0.08) }, z = 3 })
	for _, x in { 0.25, 0.75 } do
		S:oval(x, 0.4, 0.95, 0.24, yoke, { stroke = inkOf(top), strokeThickness = 1.3, z = 2 })
		S:oval(x, 0.33, 0.6, 0.14, lighten(yoke, 0.14), { transparency = 0.35, z = 3, fine = true })
	end
	S:rect(0.04, 0.3, 0.08, 0.3, shade(yoke, 0.3), { z = 3, fine = true })
	S:rect(0.96, 0.3, 0.08, 0.3, shade(yoke, 0.3), { z = 3, fine = true })
	-- Ourlet du bas
	S:rect(0.5, 0.86, 1, S:dy(0.024), inkOf(top), { z = 4 })
	S:rect(0.5, 0.895, 1, 0.06, lighten(top, 0.08), { z = 3 })
	placket(S, 0.5, 0.0, 0.93, top, 6)
	if look.collar == "fur" then
		furCollar(S, 0.0, 0.2, look.collarColor or Color3.fromRGB(226, 232, 238), 9)
	end
	if look.chestMark then
		logo(S.g, look.chestMark, 0.28, 0.24, 0.16)
	end
end

local function jacketBack(S, look, c)
	local top = c.top
	local yoke = look.shoulders or c.accent
	S.under = yoke
	shadowV(S, -0.02, 0.45, 0.3, 0.62, 0.0, 0.85, 0.2, top)
	shadowV(S, 1.02, 0.45, 0.7, 0.62, 1.0, 0.85, 0.2, top)
	edgeShade(S, "l", 0.13, top)
	edgeShade(S, "r", 0.13, top)
	ink(S, 0.1, 0.62, 0.3, 0.66, top)
	ink(S, 0.9, 0.62, 0.7, 0.66, top)
	ink(S, 0.4, 0.78, 0.6, 0.8, top)
	S:rect(0.5, 0.2, 1, 0.4, yoke, { gradient = { shade(yoke, 0.2), yoke, lighten(yoke, 0.06) }, z = 3 })
	S:oval(0.5, 0.4, 1.9, 0.22, yoke, { stroke = inkOf(top), strokeThickness = 1.3, z = 2 })
	S:rect(0.5, 0.86, 1, S:dy(0.024), inkOf(top), { z = 4 })
	S:rect(0.5, 0.895, 1, 0.06, lighten(top, 0.08), { z = 3 })
	if look.collar == "fur" then
		furCollar(S, 0.0, 0.14, look.collarColor or Color3.fromRGB(226, 232, 238), 9)
	end
end

-- Manche longue façon texture classique : ombres franches, plis à l'encre, poignet resserré.
-- Sur la veste de ninja : empiècement bleu nuit en raglan sur le haut (côté torse).
local function classicSleeve(S, look, c, side: string, inner: string?, handTop: number)
	local sleeve = c.sleeve
	local yoke = c.outfit == "jacket" and look.shoulders or nil
	cloth(S, sleeve)
	if side == "in" then
		S:rect(0.5, handTop - 0.13, 1, 0.012, inkOf(sleeve), { z = 4 })
		return
	end
	if c.haori then
		-- Haut du bras caché par la manche du haori : seul le bas est peint.
		S:line(0.0, handTop - 0.14, 0.5, handTop - 0.125, 0.024, inkOf(sleeve), { z = 5 })
		S:line(0.5, handTop - 0.125, 1.0, handTop - 0.14, 0.024, inkOf(sleeve), { z = 5 })
		S:rect(0.5, handTop - 0.06, 1, 0.11, look.cuffColor or lighten(sleeve, 0.04), { z = 4 })
		return
	end
	-- Ombres franches côté extérieur et sous le coude
	local outerX = inner == "l" and 0.85 or (inner == "r" and 0.15 or 0.5)
	if inner then
		jagShade(S, outerX > 0.5 and "r" or "l", 0.3, 0.02, handTop - 0.12, sleeve, 4)
		-- Pli du coude (ombre en "V" côté intérieur)
		local ex = 1 - outerX
		shadowV(S, ex - 0.25, 0.6, ex, 0.68, ex + 0.25, 0.62, 0.1, sleeve, 1)
	else
		jagShade(S, "r", 0.34, 0.02, handTop - 0.12, sleeve, 3)
	end
	-- Plis
	local d = inner == "l" and 1 or -1
	ink(S, 0.5 - d * 0.35, 0.34, 0.5 - d * 0.1, 0.3, sleeve)
	ink(S, 0.5 + d * 0.05, 0.48, 0.5 + d * 0.3, 0.45, sleeve, 0.021)
	ink(S, 0.5 - d * 0.3, 0.58, 0.5 - d * 0.05, 0.62, sleeve)
	ink(S, 0.5 + d * 0.1, 0.68, 0.5 + d * 0.35, 0.7, sleeve, 0.018)
	if yoke then
		if inner then
			-- Raglan : grand arrondi bleu nuit dans le coin intérieur du haut
			local x = inner == "l" and 0 or 1
			S:oval(x, 0.0, 1.5, 1.05, yoke, { stroke = inkOf(sleeve), strokeThickness = 1.3, z = 3 })
			S:oval(x, 0.0, 0.8, 0.5, shade(yoke, 0.25), { z = 3, fine = true })
			if look.collar == "fur" and side == "front" then
				S:box(x == 0 and 0.12 or 0.88, 0.04, 0.28, 0.14, look.collarColor or Color3.fromRGB(226, 232, 238), { corner = 0.4, z = 4 })
			end
		else
			S:rect(0.5, 0.05, 1, 0.1, yoke, { z = 3 })
			S:oval(0.5, 0.1, 1.3, 0.16, yoke, { stroke = inkOf(sleeve), strokeThickness = 1.3, z = 3 })
		end
	end
	-- Poignet resserré : trait d'encre arrondi + bande (couleur du poignet si précisée)
	S:line(0.0, handTop - 0.14, 0.5, handTop - 0.125, 0.024, inkOf(sleeve), { z = 5 })
	S:line(0.5, handTop - 0.125, 1.0, handTop - 0.14, 0.024, inkOf(sleeve), { z = 5 })
	local cuff = look.cuffColor or lighten(sleeve, 0.04)
	S:rect(0.5, handTop - 0.06, 1, 0.11, cuff, { z = 4 })
	ink(S, 0.2, handTop - 0.07, 0.42, handTop - 0.05, cuff, 0.016)
	ink(S, 0.6, handTop - 0.04, 0.8, handTop - 0.065, cuff, 0.016)
end

-- Pantalon de ninja : pli de l'entrejambe en éventail, grandes ombres des cuisses, bas resserré.
local function ninjaPants(S, look, c, side: string, isLeft: boolean, inner: string?)
	local bottom = c.bottom
	cloth(S, bottom)
	if side == "in" then
		return
	end
	if inner then
		local ix = inner == "l" and 0 or 1
		local d = inner == "l" and 1 or -1
		-- Ombre de la cuisse côté extérieur + éventail de l'entrejambe
		jagShade(S, ix == 0 and "r" or "l", 0.3, 0.0, 0.78, bottom, 4)
		-- Ombre de l'entrejambe (triangle sous l'aine)
		S:box(ix, 0.06, 0.62, 0.36, celShadow(bottom), { rotation = d * 30, z = 1 })
		for i = 0, side == "back" and 1 or 3 do
			local y = 0.04 + i * 0.05
			S:line(ix + d * 0.04, y, ix + d * (0.42 - i * 0.04), y + 0.03, 0.022, inkOf(bottom), { z = 4, fine = S.lite and i % 2 == 1 })
		end
		ink(S, 0.5 - d * 0.1, 0.42, 0.5 + d * 0.15, 0.38, bottom)
		ink(S, 0.5 - d * 0.25, 0.58, 0.5 - d * 0.05, 0.62, bottom)
		-- Plis de la cuisse
		ink(S, 0.5 + d * 0.05, 0.2, 0.5 + d * 0.3, 0.24, bottom, 0.018)
		ink(S, 0.5 - d * 0.3, 0.5, 0.5 - d * 0.1, 0.47, bottom, 0.018)
		S:box(ix - d * 0.0, 0.5, 0.03, 2, inkOf(bottom), { transparency = 0.2, z = 4 })
	else
		jagShade(S, "r", 0.34, 0.0, 0.78, bottom, 3)
		ink(S, 0.3, 0.4, 0.6, 0.36, bottom)
		ink(S, 0.35, 0.6, 0.7, 0.63, bottom)
	end
	-- Bas resserré au-dessus des sandales
	S:rect(0.5, 0.76, 1, 0.07, celShadow(bottom), { transparency = 0.25, z = 2 })
	S:line(0.0, 0.79, 0.5, 0.81, 0.026, inkOf(bottom), { z = 5 })
	S:line(0.5, 0.81, 1.0, 0.79, 0.026, inkOf(bottom), { z = 5 })
	if look.holsterStyle == "band" and look.holster and not isLeft then
		-- Bandage de la cuisse : sangle bleu nuit bordée de blanc
		local col = look.holster
		local wrap = Color3.fromRGB(226, 234, 240)
		S:rect(0.5, 0.285, 1, 0.022, wrap, { z = 6 })
		S:rect(0.5, 0.325, 1, 0.06, col, { gradient = { lighten(col, 0.2), col, shade(col, 0.2) }, z = 6 })
		S:rect(0.5, 0.37, 1, 0.022, wrap, { z = 6 })
		S:rect(0.5, 0.385, 1, S:dy(0.02), inkOf(bottom), { z = 6 })
	end
end

-- Face d'un bras. `side` : "front", "back", "out" (extérieur) ou "in" (contre le torse).
local function paintArm(S, look, c, side: string, isLeft: boolean)
	local skin = c.skin
	local sleeves = c.sleeves
	local sleeve = c.sleeve
	local handTop = look.handTop or (sleeves == "long" and 0.9 or 0.86)
	-- Bord côté torse sur les faces avant / arrière ("l" ou "r" de la toile)
	local inner = nil
	if side == "front" then
		inner = isLeft and "l" or "r"
	elseif side == "back" then
		inner = isLeft and "r" or "l"
	end
	if sleeves == "long" then
		classicSleeve(S, look, c, side, inner, handTop)
	elseif sleeves == "wide" then
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
	if look.shoulders and not covered and c.outfit ~= "jacket" and (sleeves == "long" or sleeves == "wide") then
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
	if look.armPlates and side ~= "in" then
		-- Plaques des avant-bras (armure organique)
		local col = look.armPlates
		S:box(0.5, 0.66, 0.92, 0.62, col, { corner = 0.35, gradient = { lighten(col, 0.35), col, darken(col, 0.3) }, stroke = inkOf(col), strokeThickness = 1.3, z = 8 })
		S:oval(0.38, 0.6, 0.22, 0.22, lighten(col, 0.6), { transparency = 0.35, z = 9, fine = true })
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
	if look.curseSpread and side ~= "in" and isLeft then
		-- Flammes noires de la marque maudite qui descendent le bras
		for i, y in { 0.12, 0.3, 0.5 } do
			S:line(0.3 + i * 0.1, y, 0.62, y + 0.14, 0.08, INK, { z = 9 })
			S:line(0.62, y + 0.14, 0.5, y + 0.22, 0.04, INK, { z = 9 })
		end
	end
	if look.armVeins and side ~= "in" then
		-- Veines gonflées (deuxième vitesse) ou fêlures de feu sur les bras nus
		local v = look.armVeins
		S:line(0.36, 0.22, 0.44, 0.4, 0.03, v, { z = 9, transparency = 0.2 })
		S:line(0.44, 0.4, 0.4, 0.58, 0.026, v, { z = 9, transparency = 0.2 })
		S:line(0.4, 0.58, 0.47, 0.76, 0.022, v, { z = 9, transparency = 0.25 })
		S:line(0.44, 0.4, 0.6, 0.5, 0.02, v, { z = 9, transparency = 0.3, fine = true })
		S:line(0.6, 0.5, 0.64, 0.66, 0.018, v, { z = 9, transparency = 0.35, fine = true })
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
		-- Sandales ninja (comme la référence) : bleu nuit, orteils à l'air devant, talon fermé
		local y0 = look.sandalTop or 0.84
		S:rect(0.5, (y0 + 1) / 2, 1, 1 - y0, shoes, { gradient = { lighten(shoes, 0.15), shoes, shade(shoes, 0.2) }, z = 10 })
		S:rect(0.5, y0 + S:dy(0.012), 1, S:dy(0.024), inkOf(shoes), { z = 11 })
		if side == "front" then
			S:oval(0.5, 1.0, 0.74, 0.2, skin, { gradient = { lighten(skin, 0.1), skin, shade(skin, 0.15) }, z = 11 })
			for i = -1, 1 do
				S:line(0.5 + i * 0.13, 0.955, 0.5 + i * 0.13, 0.995, 0.012, shade(skin, 0.45), { transparency = 0.2, z = 12, fine = true })
			end
			S:oval(0.5, 1.0, 0.74, 0.2, skin, { transparency = 1, stroke = inkOf(shoes), strokeThickness = 1.2, z = 12, fine = S.lite })
		elseif side == "out" or side == "in" then
			S:oval(0.0, 1.0, 0.6, 0.2, skin, { gradient = { skin, shade(skin, 0.15) }, z = 11 })
		end
		S:rect(0.5, 0.99, 1, 0.02, shade(shoes, 0.5), { z = 12 })
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
	elseif look.pantsStyle == "hakama" then
		-- Hakama : larges plis plats verticaux, ourlet du bas
		cloth(S, bottom)
		if inner then
			edgeShade(S, inner, 0.3, bottom)
		end
		if side ~= "in" then
			for _, x in { 0.22, 0.5, 0.78 } do
				S:line(x, 0.02, x + (x - 0.5) * 0.15, 0.9, 0.022, inkOf(bottom), { corner = 0, z = 3 })
				S:line(x + 0.05, 0.02, x + 0.05 + (x - 0.5) * 0.15, 0.9, 0.09, celShadow(bottom), { corner = 0, transparency = 0.5, z = 2, fine = true })
			end
			fold(S, 0.1, 0.62, 0.9, 0.66, bottom, { w = 0.08 })
		end
		band(S, 0.9, 0.04, shade(bottom, 0.15), 4)
	elseif look.pantsStyle ~= "plain" then
		ninjaPants(S, look, c, side, isLeft, inner)
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
	if look.shinPlates then
		-- Plaques des tibias (armure organique), bombées avec un reflet
		local col = look.shinPlates
		if side ~= "in" then
			S:box(0.5, 0.72, 0.9, 0.95, col, { corner = 0.35, gradient = { lighten(col, 0.35), col, darken(col, 0.3) }, stroke = inkOf(col), strokeThickness = 1.3, z = 7 })
			S:oval(0.38, 0.64, 0.22, 0.3, lighten(col, 0.6), { transparency = 0.35, z = 8, fine = true })
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
	if look.holster and not isLeft and look.holsterStyle ~= "band" then
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
	-- Grandes ombres franches en "V" (texture classique)
	shadowV(S, -0.02, 0.48, 0.3, 0.6, 0.0, 0.76, 0.17, color, 1)
	shadowV(S, 1.02, 0.48, 0.7, 0.6, 1.0, 0.76, 0.17, color, 1)
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

OUTFITS.jacket = jacketFront

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
	local style = look.uniformStyle
	local gold = look.buttonColor or Color3.fromRGB(235, 200, 90)
	local goldLit, goldDark = lighten(gold, 0.4), darken(gold, 0.3)
	torsoEdges(S, top)
	-- Col montant (plus haut pour « spiral » : uniforme d'exorciste à col officier)
	local collarH = style == "spiral" and 0.17 or 0.11
	S:rect(0.5, collarH / 2, style == "spiral" and 0.66 or 0.6, collarH, shade(top, 0.1), { corner = 0.2, stroke = inkOf(top), strokeThickness = 1.2, z = 4 })
	castShadow(S, collarH, 0.06, top, 3)
	if style == "spiral" then
		-- Bouton en spirale doré sur le col (côté gauche), fermeture cachée décalée
		local bx, by = 0.36, collarH * 0.55
		S:oval(bx, by, 0.13, 0.13, gold, { gradient = { goldLit, gold, goldDark }, stroke = darken(gold, 0.55), strokeThickness = 1.2, z = 6 })
		S:oval(bx, by, 0.085, 0.085, gold, { transparency = 1, stroke = darken(gold, 0.55), strokeThickness = 1, z = 7, fine = true })
		S:oval(bx + 0.01, by - 0.005, 0.035, 0.035, darken(gold, 0.55), { z = 7, fine = true })
		S:line(bx + 0.04, by, bx + 0.06, by + 0.035, 0.012, darken(gold, 0.55), { z = 7, fine = true })
		S:line(0.42, collarH, 0.44, 0.95, 0.022, inkOf(top), { z = 3 })
		S:line(0.435, collarH, 0.455, 0.95, 0.01, lighten(top, 0.18), { transparency = 0.3, z = 3, fine = true })
		fold(S, 0.55, 0.3, 0.85, 0.4, top, { w = 0.06 })
	elseif style == "zip" then
		-- Veste fermée par une glissière décalée, deux poches à rabat
		zipper(S, 0.58, collarH, 0.92, top, 5)
		pocket(S, 0.27, 0.62, 0.3, 0.2, top, 5)
		pocket(S, 0.8, 0.62, 0.26, 0.2, top, 5)
	else
		S:line(0.5, collarH, 0.5, 0.95, 0.03, inkOf(top), { z = 3 })
		for i = 0, 3 do
			local y = 0.2 + i * 0.16
			S:oval(0.54, y, 0.085, 0.085, gold, { gradient = { goldLit, gold, goldDark }, stroke = darken(gold, 0.5), strokeThickness = 1, z = 5 })
		end
	end
	torsoFolds(S, top)
	fold(S, 0.2, 0.55, 0.4, 0.62, top, { w = 0.06 })
	-- Ceinture (blanche des pourfendeurs, ou de cuir avec boucle : look.beltColor)
	local belt = look.beltColor or (look.topAccent and c.accent)
	if belt then
		band(S, 0.86, 0.08, belt, 7)
		local buckle = look.beltColor and gold or belt
		S:box(0.5, 0.86, 0.24, 0.14, buckle, { corner = 0.12, gradient = { lighten(buckle, 0.4), buckle }, stroke = inkOf(buckle), strokeThickness = 1.2, z = 9 })
	end
end

-- Veste d'uniforme ouverte sur un maillot (manches retroussées : sleeves = "short", sleeveEnd).
OUTFITS.openjacket = function(S, look, c)
	local top, skin = c.top, c.skin
	local under = look.underColor or WHITE
	local gold = look.buttonColor or Color3.fromRGB(235, 200, 90)
	torsoEdges(S, top)
	-- Maillot (débardeur) qui se voit entre les pans
	S:rect(0.5, 0.5, 0.44, 1, under, { gradient = { lighten(under, 0.05), shade(under, 0.12) }, gradientRotation = 90, z = 2 })
	S:oval(0.5, 0.0, 0.3, 0.2, skin, { gradient = { shade(skin, 0.3), skin }, z = 3 })
	fold(S, 0.38, 0.35, 0.5, 0.55, under, { w = 0.05, z = 3 })
	fold(S, 0.6, 0.6, 0.48, 0.78, under, { w = 0.05, z = 3 })
	-- Pans de la veste ouverte : ombre portée sur le maillot, revers, boutons d'un côté
	for _, x in { 0.28, 0.72 } do
		S:rect(x < 0.5 and x + 0.035 or x - 0.035, 0.5, 0.04, 1, shade(under, 0.35), { transparency = 0.35, z = 3 })
		S:line(x, 0.0, x, 1.0, 0.025, inkOf(top), { z = 5 })
	end
	S:line(0.3, 0.0, 0.2, 0.22, 0.08, shade(top, 0.12), { corner = 0, z = 4 })
	S:line(0.7, 0.0, 0.8, 0.22, 0.08, shade(top, 0.12), { corner = 0, z = 4 })
	for i = 0, 3 do
		S:oval(0.235, 0.22 + i * 0.16, 0.07, 0.07, gold, { gradient = { lighten(gold, 0.4), gold, darken(gold, 0.3) }, stroke = darken(gold, 0.5), strokeThickness = 1, z = 6 })
	end
	fold(S, 0.04, 0.4, 0.22, 0.55, top, { w = 0.06 })
	fold(S, 0.96, 0.42, 0.78, 0.58, top, { w = 0.06 })
	if look.waistband then
		waistband(S, look.waistband, true)
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
	if not look.noButtons then
		for i = 0, 2 do
			S:oval(0.2, 0.25 + i * 0.17, 0.075, 0.075, Color3.fromRGB(245, 205, 90), { stroke = Color3.fromRGB(150, 110, 40), strokeThickness = 1, z = 4 })
		end
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

-- Combinaison organique de l'empereur du froid : corps blanc, plaque pectorale violette
-- bombée (reflet), ventre en segments, flancs lavande.
local function biosuitPlate(S, color: Color3, y: number, h: number)
	S:oval(0.5, y, 1.08, h, color, { gradient = { lighten(color, 0.35), color, darken(color, 0.35) }, stroke = inkOf(color), strokeThickness = 1.4, z = 4 })
	S:oval(0.36, y - 0.06, 0.34, 0.14, lighten(color, 0.6), { transparency = 0.35, rotation = -18, z = 5 })
	S:oval(0.62, y + 0.05, 0.1, 0.06, lighten(color, 0.7), { transparency = 0.2, z = 5, fine = true })
end

OUTFITS.biosuit = function(S, look, c)
	local body = c.top
	local gem = c.accent
	torsoEdges(S, body)
	-- Flancs gris-lavande en dégradé (volume du torse sur un corps blanc)
	local flank = body:Lerp(Color3.fromRGB(150, 138, 190), 0.55)
	S:rect(0.11, 0.55, 0.22, 0.9, flank, { fade = { 0.05, 0.4, 1 }, gradientRotation = 0, z = 1 })
	S:rect(0.89, 0.55, 0.22, 0.9, flank, { fade = { 1, 0.4, 0.05 }, gradientRotation = 0, z = 1 })
	S:rect(0.5, 0.95, 1, 0.1, flank, { fade = { 1, 0.3 }, gradientRotation = 90, z = 1, fine = true })
	biosuitPlate(S, gem, 0.2, 0.62)
	-- Ventre en segments (abdominaux de l'armure organique)
	for i = 0, 3 do
		local y = 0.5 + i * 0.105
		S:line(0.3, y, 0.48, y + 0.012, 0.03, shade(body, 0.28), { transparency = 0.1, z = 3 })
		S:line(0.7, y, 0.52, y + 0.012, 0.03, shade(body, 0.28), { transparency = 0.1, z = 3 })
	end
	S:line(0.5, 0.44, 0.5, 0.92, 0.03, shade(body, 0.3), { z = 3 })
	fold(S, 0.06, 0.5, 0.26, 0.7, body, { w = 0.08 })
	fold(S, 0.94, 0.5, 0.74, 0.7, body, { w = 0.08 })
	local _ = look
end

-- Taches sombres (carapace de la créature parfaite...).
local function spots(S, color: Color3, n: number, seed: number)
	for i = 0, n - 1 do
		local v = math.sin(seed * 91.7 + i * 47.3) * 43758.5453
		local r = v - math.floor(v)
		local x = 0.15 + ((i * 0.37 + r * 0.3) % 0.7)
		local y = (i + 0.5) / n
		local d = 0.12 + r * 0.1
		S:oval(x, y, d, d * 0.85, color, { z = 3 })
	end
end
Painter.spots = spots

-- Corps de créature (monstres, fléaux) : peau nue musclée, veines, carapace, taches, gueule
-- dentée sur le ventre (look.carapace, look.veins, look.spots, look.maw).
OUTFITS.creature = function(S, look, c)
	local body = c.top
	torsoEdges(S, body)
	-- Pectoraux et abdominaux
	for _, x in { 0.32, 0.68 } do
		S:oval(x, 0.24, 0.66, 0.44, lighten(body, 0.14), { transparency = 0.25, z = 1, fine = true })
	end
	S:line(0.16, 0.4, 0.47, 0.45, 0.05, celShadow(body), { fade = { 0.8, 0 }, gradientRotation = 0, z = 2 })
	S:line(0.84, 0.4, 0.53, 0.45, 0.05, celShadow(body), { fade = { 0.8, 0 }, gradientRotation = 0, z = 2 })
	S:line(0.5, 0.46, 0.5, 0.92, 0.035, celShadow(body), { z = 2 })
	for i = 0, 2 do
		local y = 0.56 + i * 0.12
		S:line(0.36, y, 0.48, y + 0.01, 0.03, celShadow(body), { z = 2 })
		S:line(0.64, y, 0.52, y + 0.01, 0.03, celShadow(body), { z = 2 })
	end
	if look.carapace then
		local plate = look.carapace
		S:box(0.5, 0.2, 1.7, 0.6, plate, { corner = 0.35, gradient = { lighten(plate, 0.25), plate, darken(plate, 0.2) }, stroke = inkOf(plate), strokeThickness = 1.3, z = 4 })
		for _, x in { 0.12, 0.88 } do
			S:box(x, 0.62, 0.34, 1.0, plate, { corner = 0.4, gradient = { lighten(plate, 0.2), plate }, stroke = inkOf(plate), strokeThickness = 1.2, z = 4 })
		end
	end
	if look.veins then
		local v = look.veins
		S:line(0.2, 0.1, 0.32, 0.36, 0.025, v, { z = 3, fine = true })
		S:line(0.32, 0.36, 0.26, 0.6, 0.02, v, { z = 3, fine = true })
		S:line(0.8, 0.12, 0.7, 0.34, 0.025, v, { z = 3 })
		S:line(0.7, 0.34, 0.78, 0.55, 0.02, v, { z = 3, fine = true })
	end
	if look.spots then
		spots(S, look.spots, 6, 3)
	end
	if look.maw then
		-- Gueule béante sur le ventre : bord charnu, rangées de crocs, langue
		local lip = darken(body, 0.35)
		S:oval(0.5, 0.62, 1.3, 0.62, Color3.fromRGB(70, 10, 24), { stroke = lip, strokeThickness = 2.4, z = 5 })
		S:oval(0.5, 0.72, 0.6, 0.22, Color3.fromRGB(200, 60, 90), { z = 6 })
		for i = 0, 5 do
			local x = 0.24 + i * 0.104
			S:box(x, 0.53, 0.13, 0.13, Color3.fromRGB(240, 236, 220), { rotation = 45, z = 7 })
			if i < 5 then
				S:box(x + 0.052, 0.71, 0.11, 0.11, Color3.fromRGB(230, 226, 210), { rotation = 45, z = 7 })
			end
		end
	end
end

-- Motif de roses (costume de l'amiral magma) : fleurs sombres à spirale + feuilles.
local function roses(S, color: Color3, n: number, seed: number)
	local dark = darken(color, 0.45)
	-- Pseudo-hasard déterministe (même motif à chaque construction)
	local function jitter(i: number, k: number): number
		local v = math.sin((seed * 12.9898 + i * 78.233 + k * 37.719)) * 43758.5453
		return v - math.floor(v)
	end
	for i = 0, n - 1 do
		local x = (i % 2 == 0 and 0.27 or 0.72) + (jitter(i, 1) - 0.5) * 0.16
		local y = (i + 0.5) / n + (jitter(i, 2) - 0.5) * 0.08
		local r = 0.22 + jitter(i, 3) * 0.06
		S:oval(x, y, r, r * 0.9, dark, { stroke = darken(color, 0.65), strokeThickness = 1, z = 2 })
		S:oval(x + S:dx(0.02), y, r * 0.55, r * 0.5, color, { transparency = 0.35, stroke = darken(color, 0.7), strokeThickness = 1, z = 2, fine = true })
		S:line(x - S:dx(r * 0.6), y + S:dy(r * 0.5), x - S:dx(r * 1.0), y + S:dy(r * 0.75), 0.07, darken(color, 0.55), { z = 2, fine = true })
	end
end
Painter.roses = roses

-- Tatouages de lignes du démon (Akazo) : bandes horizontales terminées par des crochets.
local function lineTattoo(S, y: number, ink: Color3, x0: number?, x1: number?)
	local a, b = x0 or 0, x1 or 1
	S:line(a, y, b, y, 0.05, ink, { corner = 0, z = 9 })
	S:line(b, y, b, y + S:dy(0.12), 0.05, ink, { corner = 0, z = 9, fine = true })
	S:line(a, y, a, y + S:dy(0.12), 0.05, ink, { corner = 0, z = 9, fine = true })
end
Painter.lineTattoo = lineTattoo

-- Peint le dos du torse.
local function torsoBack(S, look, c)
	local outfit = c.outfit
	torsoEdges(S, c.top)
	if outfit == "cloak" then
		cloud(S.g, 0.3, 0.3, 0.32, c.accent)
		cloud(S.g, 0.7, 0.62, 0.32, c.accent)
	elseif outfit == "jacket" then
		jacketBack(S, look, c)
		if look.logo and look.logo.back then
			logo(S.g, look.logo, 0.5, 0.52, 0.4)
		end
		return
	elseif outfit == "jumpsuit" or outfit == "flakvest" then
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
	elseif outfit == "creature" then
		-- Colonne vertébrale en crête + omoplates
		for i = 0, 4 do
			S:oval(0.5, 0.14 + i * 0.17, 0.18, 0.12, c.carapace or shade(c.top, 0.25), { stroke = inkOf(c.top), strokeThickness = 1, z = 3 })
		end
		if look.spots then
			spots(S, look.spots, 6, 9)
		end
		if look.carapace then
			S:box(
				0.5,
				0.25,
				1.8,
				0.8,
				look.carapace,
				{ corner = 0.35, gradient = { lighten(look.carapace, 0.2), look.carapace }, stroke = inkOf(look.carapace), strokeThickness = 1.2, z = 2 }
			)
		end
	elseif outfit == "biosuit" then
		biosuitPlate(S, c.accent, 0.22, 0.52)
		S:line(0.5, 0.45, 0.5, 0.9, 0.03, shade(c.top, 0.3), { z = 3 })
	end
	if look.pattern == "roses" and outfit ~= "shirtless" then
		roses(S, c.top, 4, 7)
	end
	if look.bodyTattoo then
		for _, y in { 0.3, 0.5, 0.7 } do
			lineTattoo(S, y, look.bodyTattoo, 0.0, 1.0)
		end
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
			if mode == "parts" and (name == "left" or name == "right" or name == "back") then
				-- faces cachées par les bras, et dos (les aperçus des menus ne pivotent que de ±35°)
				continue
			end
			local S = Painter.sheet(torso, face, mode, "Shirt" .. face.Name, 70)
			cloth(S, top)
			if name == "front" then
				if look.pattern == "roses" then
					roses(S, top, 4, 3)
				end
				painter(S, look, c)
				if look.bodyTattoo then
					-- Lignes tatouées sur la poitrine et le ventre (visibles entre les pans ouverts)
					for _, y in { 0.42, 0.6, 0.76 } do
						lineTattoo(S, y, look.bodyTattoo, 0.3, 0.7)
					end
				end
				if mode ~= "parts" then
					for _, x in { 0, 1 } do
						S:rect(x, 0.5, S:dx(0.05), 1, INK, { transparency = 0.55, z = 20 })
					end
				end
			elseif name == "back" then
				if not c.haori then
					torsoBack(S, look, c) -- (dos caché par le panneau du haori sinon)
				end
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
				if mode == "parts" and (side == "in" or side == "back") then
					continue -- face collée au torse / à l'autre jambe, ou dos : jamais vus dans les aperçus
				end
				local S = Painter.sheet(part, face, mode, (isArm and "Sleeve" or "Pants") .. face.Name, 70)
				if look.pattern == "roses" and side ~= "in" and (not isArm or c.sleeves == "long") then
					roses(S, isArm and c.sleeve or c.bottom, 2, (isArm and 11 or 17) + (isLeft and 1 or 0))
				end
				if isArm then
					paintArm(S, look, c, side, isLeft)
				else
					paintLeg(S, look, c, side, isLeft)
				end
				if look.spots and side ~= "in" then
					spots(S, look.spots, 3, (isArm and 5 or 13) + (isLeft and 2 or 0) + #side)
				end
				if look.limbPlates and side ~= "in" then
					-- Plaques de carapace sur le haut des bras / des cuisses
					local col = look.limbPlates
					S:box(0.5, 0.25, 1.0, 0.8, col, { corner = 0.35, gradient = { lighten(col, 0.25), col, darken(col, 0.2) }, stroke = inkOf(col), strokeThickness = 1.2, z = 8 })
				end
				if look.bodyTattoo then
					-- Anneaux tatoués : avant-bras / poignets, mollets et chevilles
					for _, y in (isArm and { 0.56, 0.7, 0.8 } or { 0.66, 0.78 }) do
						lineTattoo(S, y, look.bodyTattoo)
					end
				end
				if side == "front" and mode ~= "parts" then
					-- Contour encré des bords (comme les vêtements classiques dessinés à la main)
					for _, x in { 0, 1 } do
						S:rect(x, 0.5, S:dx(0.05), 1, INK, { transparency = 0.55, z = 20 })
					end
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

------------------------------------------------------------------------
-- Niveau de détail intermédiaire (LOD) : au-delà de ~55 studs la tenue complète (SurfaceGui de
-- centaines de Frames) n'est plus dessinée. Pour qu'un perso posé sur la base, vu à 50-140 studs,
-- ne redevienne pas un assemblage de blocs unis, chaque face peinte reçoit une seconde
-- SurfaceGui légère : les grandes formes de la peinture (fond de tissu et son ombrage, col,
-- ceinture, poignets, emblème, grandes ombres), 10 Frames au plus, en basse résolution.
-- Elle est dessinée SOUS la peinture complète (ZOffset plus petit) : de près, la peinture
-- complète la recouvre exactement ; le RigAnimator la coupe en plus quand la caméra est proche.
------------------------------------------------------------------------

local LOD_FRAMES = 10
local LOD_DISTANCE = 2.6 -- distance d'affichage du LOD = 2,6 x celle de la peinture complète

local function frameTone(frame: Frame): Color3
	local color = frame.BackgroundColor3
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then
		local keys = gradient.Color.Keypoints
		local mid = keys[math.ceil(#keys / 2)].Value
		color = Color3.new(color.R * mid.R, color.G * mid.G, color.B * mid.B)
	end
	return color
end

local function tone(c: Color3): number
	return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
end

-- Crée le LOD d'une face peinte. Renvoie la SurfaceGui LOD (ou nil).
function Painter.lod(gui: SurfaceGui, maxFrames: number?): SurfaceGui?
	local parent = gui.Parent
	if not parent then
		return nil
	end
	local frames = {}
	local covered = false
	local base: Color3? = nil
	for order, child in gui:GetChildren() do
		if not child:IsA("Frame") or not child.Visible or child.BackgroundTransparency >= 0.6 then
			continue
		end
		local w, h = child.Size.X.Scale, child.Size.Y.Scale
		local gradient = child:FindFirstChildOfClass("UIGradient")
		local faded = false
		if gradient then
			for _, k in gradient.Transparency.Keypoints do
				if k.Value > 0.05 then
					faded = true
				end
			end
		end
		local opaque = child.BackgroundTransparency < 0.05 and not faded
		if opaque and w >= 0.97 and h >= 0.97 and child.Rotation == 0 then
			covered = true
			base = base or frameTone(child)
		end
		table.insert(frames, { f = child, area = w * h, opaque = opaque, order = order, rotated = child.Rotation ~= 0 })
	end
	if #frames == 0 then
		return nil
	end
	-- Sans fond opaque qui couvre toute la face, une forme translucide recopiée se verrait en
	-- double de près : on ne garde alors que les formes opaques.
	local reference = base or frameTone(frames[1].f)
	local picked = {}
	for _, e in frames do
		if not covered and not e.opaque then
			continue
		end
		-- Les traits fins (plis, coutures, contours) ne se voient plus à cette distance.
		if e.area < 0.012 or (e.rotated and e.area < 0.05) then
			continue
		end
		local c = frameTone(e.f)
		local contrast = math.abs(tone(c) - tone(reference)) + (math.abs(c.R - reference.R) + math.abs(c.G - reference.G) + math.abs(c.B - reference.B)) * 0.5
		e.score = e.area * (0.25 + contrast) * (e.opaque and 1 or 0.6) + (e.area >= 0.9 and 10 or 0)
		table.insert(picked, e)
	end
	table.sort(picked, function(a, b)
		return a.score > b.score
	end)
	-- Budget selon la taille de la face (en studs² à l'échelle 1) : 10 Frames pour le devant du
	-- torse, 5 ou 6 pour un bras, 2 ou 3 pour le dessus d'un membre ou un petit accessoire.
	local fw, fh = faceSize((parent :: BasePart).Size, gui.Face)
	local k = (parent :: any):FindFirstAncestorOfClass("Model")
	local scale = k and k:GetAttribute("BaseScale") or Painter.scale or 1
	local area = fw * fh / (scale * scale)
	local limit = maxFrames or math.clamp(math.floor(area * 2.6 + 0.5), 1, LOD_FRAMES)
	if limit < 2 then
		-- Petite face : la couleur de la pièce suffit à cette distance
		return nil
	end
	local keep = {}
	for i = 1, math.min(limit, #picked) do
		table.insert(keep, picked[i])
	end
	if #keep == 0 then
		return nil
	end
	table.sort(keep, function(a, b)
		return a.order < b.order
	end)
	local lod = Instance.new("SurfaceGui")
	lod.Name = "Lod" .. gui.Name
	lod.Face = gui.Face
	lod.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	lod.PixelsPerStud = math.max(8, gui.PixelsPerStud * 0.3)
	lod.LightInfluence = gui.LightInfluence
	lod.Brightness = gui.Brightness
	lod.ClipsDescendants = true
	lod.ZIndexBehavior = gui.ZIndexBehavior
	lod.MaxDistance = gui.MaxDistance * LOD_DISTANCE
	lod.ZOffset = gui.ZOffset - 1
	lod:SetAttribute("LodNear", gui.MaxDistance)
	for _, e in keep do
		local copy = e.f:Clone()
		-- Les enfants Frame (motifs imbriqués) ne sont pas gardés : seulement l'aspect de la forme.
		for _, d in copy:GetChildren() do
			if d:IsA("GuiObject") or d:IsA("UIStroke") then
				d:Destroy()
			end
		end
		copy.Parent = lod
	end
	lod.Parent = parent
	return lod
end

-- LOD de toutes les faces peintes d'un modèle (sauf le visage, déjà affiché plus loin).
function Painter.lods(model: Instance)
	local guis = {}
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceGui") and d:GetAttribute("LodNear") then
			d:Destroy()
		elseif d:IsA("SurfaceGui") and d.Name ~= "Face" and d.Enabled then
			table.insert(guis, d)
		end
	end
	for _, gui in guis do
		-- Couche peinte par-dessus la tenue (lave du poing de magma...) : ZOffset plus haut
		gui.ZOffset = gui:GetAttribute("ZTop") and 1.5 or 1
		Painter.lod(gui)
	end
end

Painter.cloth = cloth
Painter.cloud = cloud
Painter.fold = fold
Painter.band = band
Painter.shade = shade
Painter.celShadow = celShadow
Painter.inkOf = inkOf
Painter.edgeShade = edgeShade

return Painter
