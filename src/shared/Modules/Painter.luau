-- "Peintre" : dessine des textures en 2D sur les persos avec des SurfaceGui (aucun asset à importer).
--   * visage d'animé (grands yeux brillants, cils, sourcils, bouche, moustaches, tatouages...)
--   * tenue sur le torse (fermeture éclair, col, boutons, ceinture, symboles dans le dos...)
-- Tout est en coordonnées relatives (0 à 1), donc indépendant de la taille du perso.

local Painter = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(28, 22, 30)
local MOUTH = Color3.fromRGB(120, 28, 40)
local TONGUE = Color3.fromRGB(235, 110, 120)

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function has(look, accessory: string): boolean
	return look.accessories ~= nil and table.find(look.accessories, accessory) ~= nil
end
Painter.has = has

export type RectOptions = {
	rotation: number?,
	corner: number?,
	transparency: number?,
	gradient: { Color3 }?,
	gradientRotation: number?,
	stroke: Color3?,
	strokeThickness: number?,
	z: number?,
	anchor: Vector2?,
}

------------------------------------------------------------------------
-- Toile "pièces" : même dessin, mais en fines pièces 3D (visible dans les ViewportFrame
-- des menus, où les SurfaceGui ne s'affichent pas).
------------------------------------------------------------------------

local PartCanvas = {}
PartCanvas.__index = PartCanvas

function PartCanvas.new(part: BasePart, face: Enum.NormalId)
	return setmetatable({ part = part, front = face ~= Enum.NormalId.Back, size = part.Size, count = 0 }, PartCanvas)
end

function PartCanvas:piece(x: number, y: number, w: number, h: number, rotation: number, layer: number, color: Color3, transparency: number, round: boolean)
	local size = self.size
	local depth = 0.004 + layer * 0.0035
	local lx = (self.front and (0.5 - x) or (x - 0.5)) * size.X
	local ly = (0.5 - y) * size.Y
	local lz = self.front and -(size.Z / 2 + depth) or (size.Z / 2 + depth)
	local angle = math.rad(rotation) * (self.front and 1 or -1)
	local base = self.part
	local piece = Instance.new("Part")
	piece.Name = "Paint"
	piece.Size = Vector3.new(math.max(w * size.X, 0.01), math.max(h * size.Y, 0.01), 0.01)
	piece.CFrame = base.CFrame * CFrame.new(lx, ly, lz) * CFrame.Angles(0, 0, angle)
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

function PartCanvas:rect(x: number, y: number, w: number, h: number, color: Color3, o)
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
	local layer = o.z or 1
	local transparency = o.transparency or 0
	local round = (o.corner or 0) >= 0.3
	if o.stroke then
		local pad = (o.strokeThickness or 1.5) * 0.006
		local padX, padY = pad / self.size.X, pad / self.size.Y
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

-- Convertit une SurfaceGui (avant/arrière) en fines pièces : sert aux aperçus des menus
-- (les ViewportFrame n'affichent pas les SurfaceGui). Gère les Frame en coordonnées "Scale".
function Painter.bakeToParts(gui: SurfaceGui)
	local part = (gui.Adornee or gui.Parent) :: any
	if not part or not part:IsA("BasePart") or (gui.Face ~= Enum.NormalId.Front and gui.Face ~= Enum.NormalId.Back) then
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
			local colors = nil
			if gradient then
				colors = {}
				for _, key in gradient.Color.Keypoints do
					table.insert(colors, key.Value)
				end
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
			canvas:rect(x + w / 2, y + h / 2, w, h, frame.BackgroundColor3, {
				rotation = frame.Rotation,
				corner = radius,
				transparency = frame.BackgroundTransparency,
				gradient = colors,
				stroke = stroke and stroke.Color or nil,
				strokeThickness = stroke and stroke.Thickness or nil,
				z = frame.ZIndex,
			})
		end
	end
	gui:Destroy()
end

function Painter.canvas(part: BasePart, face: Enum.NormalId)
	return PartCanvas.new(part, face)
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
	gui.LightInfluence = 0.8
	gui.MaxDistance = 110
	gui.ClipsDescendants = true
	gui.Parent = part
	return gui
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
	if o.gradient then
		local keys = {}
		for i, c in o.gradient do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #o.gradient - 1), c))
		end
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(keys)
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
-- Visage
------------------------------------------------------------------------

local BROW_TILT = { angry = 16, fierce = 9, happy = -6, calm = 0, smirk = 0 }
local LASH_TILT = { angry = 10, fierce = 6, happy = -4, calm = -2, smirk = 0 }

local function eye(gui: any, look, x: number, y: number, w: number, h: number, viewerSide: number)
	local iris = look.eyes or Color3.fromRGB(45, 35, 60)
	local face = look.face or "calm"
	if look.eyeShadow then
		rect(gui, x, y - h * 0.08, w * 1.4, h * 0.85, look.eyeShadow, { corner = 0.5, transparency = 0.1, z = 1 })
	end
	-- Blanc de l'œil (avec un fin contour)
	rect(gui, x, y, w, h, WHITE, { corner = 0.45, stroke = darken(iris, 0.7), strokeThickness = 1.2, z = 2 })
	-- Iris en dégradé
	local ix = x - viewerSide * w * 0.06
	rect(gui, ix, y + h * 0.05, w * 0.7, h * 0.86, iris, { corner = 0.5, gradient = { darken(iris, 0.55), iris, lighten(iris, 0.35) }, z = 3 })
	-- Pupille
	rect(gui, ix, y + h * 0.06, w * 0.32, h * 0.42, darken(iris, 0.75), { corner = 0.5, z = 4 })
	-- Reflets
	rect(gui, ix + viewerSide * w * 0.17, y - h * 0.16, w * 0.26, h * 0.22, WHITE, { corner = 0.5, z = 5 })
	rect(gui, ix - viewerSide * w * 0.14, y + h * 0.22, w * 0.12, h * 0.1, WHITE, { corner = 0.5, z = 5, transparency = 0.15 })
	-- Cil supérieur (épais, style animé)
	local tilt = (LASH_TILT[face] or 0) * viewerSide
	rect(gui, x, y - h * 0.47, w * 1.12, h * 0.17, INK, { corner = 0.4, rotation = tilt, z = 6 })
	-- Petit trait en coin (cils longs)
	if look.blush then
		rect(gui, x + viewerSide * w * 0.55, y - h * 0.5, w * 0.28, h * 0.1, INK, { corner = 0.4, rotation = -28 * viewerSide, z = 6 })
	end
	-- Cil inférieur discret
	rect(gui, x, y + h * 0.5, w * 0.55, h * 0.05, INK, { corner = 0.5, transparency = 0.45, z = 6 })
end

local function mouth(gui: any, look, skin: Color3)
	local face = look.face or "calm"
	local y = 0.83
	if face == "happy" then
		rect(gui, 0.5, y, 0.19, 0.11, MOUTH, { corner = 0.5, z = 2 })
		rect(gui, 0.5, y - 0.035, 0.21, 0.06, skin, { z = 3 })
		rect(gui, 0.5, y + 0.03, 0.08, 0.035, TONGUE, { corner = 0.5, z = 4 })
		rect(gui, 0.5, y - 0.005, 0.15, 0.018, WHITE, { z = 4 })
	elseif face == "fierce" then
		rect(gui, 0.5, y, 0.15, 0.12, MOUTH, { corner = 0.3, z = 2 })
		rect(gui, 0.5, y - 0.045, 0.14, 0.03, WHITE, { z = 3 })
		rect(gui, 0.5, y + 0.05, 0.12, 0.02, WHITE, { z = 3 })
		rect(gui, 0.5, y + 0.025, 0.07, 0.03, TONGUE, { corner = 0.5, z = 3 })
	elseif face == "angry" then
		rect(gui, 0.5, y, 0.14, 0.024, INK, { corner = 0.5, z = 2 })
		rect(gui, 0.43, y + 0.012, 0.03, 0.02, INK, { rotation = 35, z = 2 })
		rect(gui, 0.57, y + 0.012, 0.03, 0.02, INK, { rotation = -35, z = 2 })
	elseif face == "smirk" then
		rect(gui, 0.53, y, 0.12, 0.022, INK, { corner = 0.5, rotation = -12, z = 2 })
		rect(gui, 0.6, y - 0.018, 0.03, 0.018, INK, { corner = 0.5, rotation = -40, z = 2 })
	else
		rect(gui, 0.5, y, 0.08, 0.02, INK, { corner = 0.5, z = 2 })
	end
end

local function faceMarks(gui: any, look, skin: Color3)
	local accColor = look.accColor
	if has(look, "whiskers") then
		for _, side in { -1, 1 } do
			local x = 0.5 + side * 0.38
			for i = 0, 2 do
				rect(gui, x, 0.66 + i * 0.05, 0.13, 0.017, darken(skin, 0.55), { corner = 0.5, rotation = (i - 1) * 9 * side, z = 7 })
			end
		end
	end
	if has(look, "tear_lines") then
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.14, 0.67, 0.014, 0.12, darken(skin, 0.45), { corner = 0.5, rotation = side * 8, z = 7 })
		end
	end
	if has(look, "tattoos") then
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.22, 0.69, 0.17, 0.022, INK, { corner = 0.5, z = 7 })
			rect(gui, 0.5 + side * 0.36, 0.61, 0.02, 0.14, INK, { corner = 0.5, z = 7 })
		end
		rect(gui, 0.5, 0.07, 0.14, 0.022, INK, { corner = 0.5, z = 7 })
	end
	if has(look, "tattoos_blue") then
		local ink = accColor or Color3.fromRGB(60, 80, 220)
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.4, 0.5, 0.014, 0.6, ink, { z = 7 })
			rect(gui, 0.5 + side * 0.12, 0.1, 0.014, 0.16, ink, { z = 7 })
		end
	end
	if has(look, "extra_eyes") then
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.32, 0.7, 0.09, 0.04, look.eyes or Color3.fromRGB(220, 20, 30), { corner = 0.5, stroke = INK, strokeThickness = 1, z = 7 })
		end
	end
	if has(look, "scar_eye") then
		rect(gui, 0.71, 0.53, 0.02, 0.36, Color3.fromRGB(150, 50, 50), { rotation = 8, z = 8 })
	end
	if has(look, "scar_cheek") then
		rect(gui, 0.27, 0.7, 0.12, 0.016, Color3.fromRGB(150, 60, 60), { z = 7 })
		for i = -1, 1 do
			rect(gui, 0.27 + i * 0.035, 0.7, 0.008, 0.035, Color3.fromRGB(150, 60, 60), { z = 7 })
		end
	end
	if has(look, "scar_face") then
		rect(gui, 0.5, 0.6, 0.62, 0.02, Color3.fromRGB(160, 70, 70), { rotation = 22, z = 7 })
	end
	if has(look, "scar_forehead") then
		rect(gui, 0.66, 0.11, 0.17, 0.1, Color3.fromRGB(170, 60, 50), { corner = 0.35, transparency = 0.15, z = 7 })
	end
	if has(look, "forehead_mark") then
		local red = Color3.fromRGB(200, 30, 30)
		rect(gui, 0.66, 0.12, 0.15, 0.08, red, { corner = 0.4, z = 7 })
		rect(gui, 0.6, 0.06, 0.06, 0.08, red, { corner = 0.4, rotation = -25, z = 7 })
		rect(gui, 0.72, 0.05, 0.05, 0.07, red, { corner = 0.4, rotation = 20, z = 7 })
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
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.3, 0.68, 0.025, 0.22, paint, { corner = 0.5, z = 7 })
			rect(gui, 0.5 + side * 0.29, 0.22, 0.12, 0.02, paint, { corner = 0.5, z = 7 })
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
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.21, 0.53, 0.29, 0.26, Color3.fromRGB(190, 225, 255), { corner = 0.3, transparency = 0.7, stroke = INK, strokeThickness = 2.2, z = 9 })
		end
		rect(gui, 0.5, 0.49, 0.13, 0.02, INK, { z = 9 })
	end
	if look.blush then
		for _, side in { -1, 1 } do
			rect(gui, 0.5 + side * 0.33, 0.7, 0.13, 0.05, Color3.fromRGB(255, 130, 150), { corner = 0.5, transparency = 0.45, z = 1 })
		end
	end
end

-- Dessine un visage d'animé sur la face avant de `part`.
function Painter.face(part: BasePart, look, mode: string?)
	if has(look, "boar_head") then
		return nil
	end
	local skin = look.skin or Color3.fromRGB(255, 216, 180)
	local gui = surface(part, Enum.NormalId.Front, "Face", 160, mode)
	local hideEyes = has(look, "blindfold")
	local face = look.face or "calm"
	if not hideEyes then
		if has(look, "cyclops") then
			eye(gui, look, 0.5, 0.52, 0.32, 0.36, 1)
		else
			eye(gui, look, 0.29, 0.53, 0.22, 0.27, -1)
			eye(gui, look, 0.71, 0.53, 0.22, 0.27, 1)
		end
		-- Sourcils
		local browColor = darken(look.hairColor or INK, 0.25)
		if look.hair == "bald" or look.hair == "none" then
			browColor = darken(skin, 0.45)
		end
		local browH = look.bigBrows and 0.085 or 0.04
		local browW = look.bigBrows and 0.26 or 0.21
		for _, side in { -1, 1 } do
			local tilt = (BROW_TILT[face] or 0) * -side
			local y = 0.29
			if face == "smirk" and side > 0 then
				y = 0.25
				tilt = -8
			end
			rect(gui, 0.5 + side * 0.21, y, browW, browH, browColor, { corner = 0.5, rotation = tilt, z = 7 })
		end
	end
	-- Nez : petite ombre
	rect(gui, 0.52, 0.69, 0.025, 0.05, darken(skin, 0.25), { corner = 0.5, transparency = 0.25, z = 1 })
	if not has(look, "mask_lower") and not has(look, "muzzle") and not has(look, "mask_bandage") and not has(look, "collar_high") then
		mouth(gui, look, skin)
	end
	faceMarks(gui, look, skin)
	return gui
end

------------------------------------------------------------------------
-- Symboles (logos)
------------------------------------------------------------------------

local function logo(gui: any, spec, x: number, y: number, size: number)
	local color = spec.color or Color3.fromRGB(220, 40, 40)
	if spec.kind == "spiral" then
		if spec.bg then
			rect(gui, x, y, size, size, spec.bg, { corner = 0.5, z = 6 })
		end
		rect(gui, x, y, size * 0.72, size * 0.72, spec.bg or WHITE, { corner = 0.5, stroke = color, strokeThickness = 5, transparency = spec.bg and 0 or 1, z = 7 })
		rect(gui, x, y, size * 0.36, size * 0.36, color, { corner = 0.5, z = 8 })
		rect(gui, x + size * 0.18, y - size * 0.05, size * 0.1, size * 0.34, color, { corner = 0.5, rotation = 30, z = 8 })
	elseif spec.kind == "fan" then
		rect(gui, x, y - size * 0.12, size * 0.8, size * 0.4, color, { corner = 0.5, z = 7 })
		rect(gui, x, y + size * 0.12, size * 0.8, size * 0.36, WHITE, { corner = 0.5, z = 7 })
		rect(gui, x, y + size * 0.42, size * 0.12, size * 0.3, Color3.fromRGB(200, 200, 200), { z = 6 })
	elseif spec.kind == "circle" then
		rect(gui, x, y, size, size, WHITE, { corner = 0.5, transparency = 1, stroke = color, strokeThickness = 6, z = 7 })
	elseif spec.kind == "kanji" then
		rect(gui, x, y, size, size, spec.bg or WHITE, { corner = 0.5, z = 7 })
		if type(gui) == "table" then
			-- Toile "pièces" : un simple trait épais à la place du caractère.
			rect(gui, x, y, size * 0.5, size * 0.12, color, { z = 8 })
			rect(gui, x, y, size * 0.12, size * 0.55, color, { z = 8 })
			return
		end
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(size * 0.85, size * 0.85)
		label.BackgroundTransparency = 1
		label.Text = spec.text or "力"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = color
		label.ZIndex = 8
		label.Parent = gui
	end
end

-- Nuage rouge (cape à nuages)
local function cloud(gui: any, x: number, y: number, s: number, color: Color3)
	for _, offset in { { -0.35, 0.1, 0.55 }, { 0, -0.12, 0.7 }, { 0.38, 0.08, 0.55 }, { 0.05, 0.18, 0.6 } } do
		rect(gui, x + offset[1] * s, y + offset[2] * s, offset[3] * s, offset[3] * s * 0.8, color, { corner = 0.5, stroke = WHITE, strokeThickness = 2, z = 6 })
	end
end

------------------------------------------------------------------------
-- Torse (avant / arrière)
------------------------------------------------------------------------

local OUTFITS = {}

OUTFITS.shirt = function(gui, look, top, accent)
	rect(gui, 0.5, 0.04, 0.4, 0.08, darken(top, 0.25), { corner = 0.5, z = 2 })
	local _ = look
	local _a = accent
end

OUTFITS.jacket = function(gui, look, top, accent)
	-- Épaules et col de couleur secondaire (comme la veste de Maruto)
	rect(gui, 0.16, 0.1, 0.34, 0.2, accent, { z = 2 })
	rect(gui, 0.84, 0.1, 0.34, 0.2, accent, { z = 2 })
	rect(gui, 0.5, 0.05, 0.5, 0.1, accent, { z = 2 })
	-- Fermeture éclair
	rect(gui, 0.5, 0.5, 0.035, 0.84, Color3.fromRGB(215, 215, 225), { z = 3 })
	rect(gui, 0.5, 0.2, 0.06, 0.05, Color3.fromRGB(170, 170, 180), { corner = 0.3, z = 4 })
	-- Poches
	rect(gui, 0.24, 0.66, 0.26, 0.02, darken(top, 0.35), { z = 3 })
	rect(gui, 0.76, 0.66, 0.26, 0.02, darken(top, 0.35), { z = 3 })
	local _ = look
end

OUTFITS.jumpsuit = function(gui, look, top, accent)
	rect(gui, 0.5, 0.05, 0.6, 0.1, accent, { z = 2 })
	rect(gui, 0.5, 0.45, 0.03, 0.8, darken(top, 0.4), { z = 3 })
	rect(gui, 0.16, 0.14, 0.26, 0.2, accent, { corner = 0.2, transparency = 0.3, z = 2 })
	rect(gui, 0.84, 0.14, 0.26, 0.2, accent, { corner = 0.2, transparency = 0.3, z = 2 })
	local _ = look
end

OUTFITS.uniform = function(gui, look, top, accent)
	rect(gui, 0.5, 0.06, 0.62, 0.12, darken(top, 0.35), { z = 2 })
	rect(gui, 0.5, 0.45, 0.012, 0.78, darken(top, 0.45), { z = 2 })
	for i = 0, 3 do
		rect(gui, 0.56, 0.2 + i * 0.16, 0.06, 0.06, Color3.fromRGB(230, 195, 80), { corner = 0.5, stroke = darken(Color3.fromRGB(230, 195, 80), 0.4), strokeThickness = 1, z = 3 })
	end
	if look.topAccent then
		rect(gui, 0.5, 0.86, 1, 0.08, accent, { z = 3 })
	end
end

OUTFITS.gi = function(gui, look, top, accent)
	-- Col croisé (kimono d'arts martiaux) + maillot de dessous
	local under = accent
	rect(gui, 0.5, 0.0, 0.36, 0.5, under, { rotation = 45, z = 2 })
	rect(gui, 0.36, 0.3, 0.05, 0.62, darken(top, 0.3), { rotation = -32, z = 3 })
	rect(gui, 0.64, 0.3, 0.05, 0.62, darken(top, 0.3), { rotation = 32, z = 3 })
	if look.logo and not look.logo.back then
		logo(gui, look.logo, 0.72, 0.42, 0.22)
	end
end

OUTFITS.highcollar = function(gui, look, top, accent)
	rect(gui, 0.5, 0.07, 0.7, 0.14, darken(top, 0.3), { corner = 0.2, z = 2 })
	rect(gui, 0.5, 0.22, 0.02, 0.18, darken(top, 0.5), { z = 3 })
	rect(gui, 0.5, 0.86, 1, 0.06, accent, { z = 3 })
	local _ = look
end

OUTFITS.flakvest = function(gui, look, top, accent)
	-- Gilet tactique avec poches
	rect(gui, 0.5, 0.55, 0.86, 0.9, accent, { gradient = { lighten(accent, 0.08), darken(accent, 0.15) }, z = 2 })
	rect(gui, 0.5, 0.06, 0.62, 0.14, darken(accent, 0.15), { corner = 0.4, z = 3 })
	rect(gui, 0.5, 0.55, 0.025, 0.8, darken(accent, 0.45), { z = 3 })
	for _, x in { 0.27, 0.73 } do
		rect(gui, x, 0.38, 0.26, 0.16, darken(accent, 0.12), { corner = 0.15, stroke = darken(accent, 0.45), strokeThickness = 1, z = 4 })
		rect(gui, x, 0.62, 0.26, 0.16, darken(accent, 0.12), { corner = 0.15, stroke = darken(accent, 0.45), strokeThickness = 1, z = 4 })
	end
	local _ = look
	local _t = top
end

OUTFITS.robe = function(gui, look, top, accent)
	rect(gui, 0.42, 0.28, 0.05, 0.62, darken(top, 0.25), { rotation = -30, z = 3 })
	rect(gui, 0.58, 0.28, 0.05, 0.62, darken(top, 0.25), { rotation = 30, z = 3 })
	rect(gui, 0.5, 0.04, 0.22, 0.12, look.skin or WHITE, { rotation = 45, z = 2 })
	rect(gui, 0.5, 0.78, 1, 0.14, accent, { gradient = { lighten(accent, 0.1), darken(accent, 0.2) }, z = 3 })
end

OUTFITS.kimono = function(gui, look, top, accent)
	OUTFITS.robe(gui, look, top, accent)
	for i = 0, 5 do
		rect(gui, 0.15 + (i % 3) * 0.35, 0.25 + math.floor(i / 3) * 0.3, 0.06, 0.06, lighten(top, 0.4), { corner = 0.5, transparency = 0.3, z = 2 })
	end
end

OUTFITS.suit = function(gui, look, top, accent)
	-- Chemise blanche en V, cravate, revers
	rect(gui, 0.5, 0.12, 0.34, 0.5, accent, { rotation = 0, z = 2 })
	rect(gui, 0.36, 0.3, 0.06, 0.55, darken(top, 0.35), { rotation = -18, z = 3 })
	rect(gui, 0.64, 0.3, 0.06, 0.55, darken(top, 0.35), { rotation = 18, z = 3 })
	rect(gui, 0.5, 0.3, 0.07, 0.42, Color3.fromRGB(40, 40, 50), { corner = 0.3, z = 4 })
	rect(gui, 0.5, 0.11, 0.09, 0.06, Color3.fromRGB(40, 40, 50), { corner = 0.3, z = 4 })
	for i = 0, 1 do
		rect(gui, 0.6, 0.62 + i * 0.12, 0.04, 0.04, darken(top, 0.5), { corner = 0.5, z = 4 })
	end
	local _ = look
end

OUTFITS.armor = function(gui, look, top, accent)
	-- Plastron de combat
	rect(gui, 0.5, 0.36, 1, 0.72, accent, { corner = 0.12, gradient = { lighten(accent, 0.1), darken(accent, 0.12) }, z = 2 })
	rect(gui, 0.5, 0.72, 0.9, 0.04, darken(accent, 0.3), { z = 3 })
	rect(gui, 0.5, 0.36, 0.015, 0.6, darken(accent, 0.25), { z = 3 })
	local _ = look
	local _t = top
end

OUTFITS.tank = function(gui, look, top, accent)
	rect(gui, 0.5, 0.0, 0.5, 0.28, look.skin or WHITE, { corner = 0.5, z = 2 })
	rect(gui, 0.08, 0.1, 0.16, 0.22, look.skin or WHITE, { z = 2 })
	rect(gui, 0.92, 0.1, 0.16, 0.22, look.skin or WHITE, { z = 2 })
	local _ = top
	local _a = accent
end

OUTFITS.qipao = function(gui, look, top, accent)
	rect(gui, 0.5, 0.05, 0.5, 0.1, accent, { z = 2 })
	rect(gui, 0.62, 0.25, 0.04, 0.4, accent, { rotation = 30, z = 3 })
	rect(gui, 0.5, 0.45, 0.012, 0.75, darken(top, 0.35), { z = 2 })
	rect(gui, 0.08, 0.1, 0.16, 0.2, look.skin or WHITE, { z = 2 })
	rect(gui, 0.92, 0.1, 0.16, 0.2, look.skin or WHITE, { z = 2 })
end

OUTFITS.openvest = function(gui, look, top, accent)
	local skin = look.skin or WHITE
	rect(gui, 0.5, 0.5, 0.46, 1, skin, { z = 2 })
	rect(gui, 0.5, 0.36, 0.012, 0.3, darken(skin, 0.18), { z = 3 })
	rect(gui, 0.42, 0.28, 0.13, 0.012, darken(skin, 0.18), { z = 3 })
	rect(gui, 0.58, 0.28, 0.13, 0.012, darken(skin, 0.18), { z = 3 })
	for i = 0, 2 do
		rect(gui, 0.26, 0.25 + i * 0.18, 0.04, 0.04, Color3.fromRGB(240, 210, 110), { corner = 0.5, z = 3 })
	end
	local _ = top
	local _a = accent
end

OUTFITS.openshirt = function(gui, look, top, accent)
	local skin = look.skin or WHITE
	rect(gui, 0.5, 0.0, 0.28, 0.5, skin, { z = 2 })
	rect(gui, 0.4, 0.22, 0.05, 0.5, darken(top, 0.2), { rotation = -20, z = 3 })
	rect(gui, 0.6, 0.22, 0.05, 0.5, darken(top, 0.2), { rotation = 20, z = 3 })
	local _ = accent
end

OUTFITS.openrobe = function(gui, look, top, accent)
	OUTFITS.openshirt(gui, look, top, accent)
	rect(gui, 0.5, 0.82, 1, 0.08, accent, { z = 4 })
end

OUTFITS.striped = function(gui, look, top, accent)
	for i = 0, 3 do
		rect(gui, 0.5, 0.18 + i * 0.2, 1, 0.08, accent, { z = 2 })
	end
	local _ = look
	local _t = top
end

OUTFITS.sailor = function(gui, look, top, accent)
	rect(gui, 0.5, 0.0, 0.7, 0.6, accent, { rotation = 0, z = 2 })
	rect(gui, 0.5, 0.06, 0.4, 0.5, top, { rotation = 45, z = 3 })
	rect(gui, 0.5, 0.36, 0.12, 0.1, Color3.fromRGB(220, 40, 40), { corner = 0.3, rotation = 45, z = 4 })
	local _ = look
end

OUTFITS.overalls = function(gui, look, top, accent)
	rect(gui, 0.5, 0.65, 0.6, 0.7, accent, { corner = 0.08, z = 2 })
	rect(gui, 0.27, 0.25, 0.06, 0.5, accent, { z = 2 })
	rect(gui, 0.73, 0.25, 0.06, 0.5, accent, { z = 2 })
	rect(gui, 0.27, 0.42, 0.06, 0.06, Color3.fromRGB(230, 200, 90), { corner = 0.5, z = 3 })
	rect(gui, 0.73, 0.42, 0.06, 0.06, Color3.fromRGB(230, 200, 90), { corner = 0.5, z = 3 })
	local _ = look
	local _t = top
end

OUTFITS.coat = function(gui, look, top, accent)
	rect(gui, 0.5, 0.5, 0.06, 1, accent, { z = 2 })
	rect(gui, 0.5, 0.04, 0.8, 0.1, accent, { corner = 0.4, z = 2 })
	for i = 0, 3 do
		rect(gui, 0.6, 0.2 + i * 0.18, 0.05, 0.05, accent, { corner = 0.5, z = 3 })
	end
	local _ = look
	local _t = top
end

OUTFITS.denim = function(gui, _look, top, accent)
	rect(gui, 0.5, 0.5, 0.42, 1, accent, { z = 2 })
	for i = 0, 3 do
		rect(gui, 0.5, 0.15 + i * 0.22, 0.42, 0.06, lighten(accent, 0.6), { z = 3 })
	end
	rect(gui, 0.2, 0.5, 0.012, 0.9, darken(top, 0.3), { z = 3 })
	rect(gui, 0.8, 0.5, 0.012, 0.9, darken(top, 0.3), { z = 3 })
end

OUTFITS.egyptian = function(gui, look, top, accent)
	rect(gui, 0.5, 0.86, 1, 0.08, accent, { z = 2 })
	for i = 0, 4 do
		rect(gui, 0.1 + i * 0.2, 0.86, 0.06, 0.06, top, { rotation = 45, z = 3 })
	end
	local _ = look
end

OUTFITS.chakra = function(gui, look, top, accent)
	-- Mode Démon Renard : motifs noirs sur un corps doré
	for i = 0, 5 do
		rect(gui, 0.12 + i * 0.152, 0.06, 0.09, 0.09, accent, { corner = 0.5, z = 3 })
	end
	rect(gui, 0.5, 0.5, 0.42, 0.42, accent, { corner = 0.5, transparency = 1, stroke = accent, strokeThickness = 4, z = 3 })
	rect(gui, 0.2, 0.55, 0.03, 0.7, accent, { z = 3 })
	rect(gui, 0.8, 0.55, 0.03, 0.7, accent, { z = 3 })
	local _ = look
	local _t = top
end

OUTFITS.cloak = function(gui, look, top, accent)
	rect(gui, 0.5, 0.08, 0.84, 0.16, darken(top, 0.2), { corner = 0.3, z = 2 })
	cloud(gui, 0.27, 0.4, 0.3, accent)
	cloud(gui, 0.72, 0.7, 0.28, accent)
	local _ = look
end

OUTFITS.fur = function(gui, look, top, accent)
	rect(gui, 0.5, 0.55, 0.6, 0.8, lighten(top, 0.25), { corner = 0.5, z = 2 })
	local _ = look
	local _a = accent
end

OUTFITS.shirtless = function(gui, look, top, accent)
	local skin = look.skin or WHITE
	rect(gui, 0.5, 0.0, 1, 2, skin, { z = 1 })
	rect(gui, 0.3, 0.32, 0.36, 0.02, darken(skin, 0.22), { corner = 0.5, rotation = 8, z = 2 })
	rect(gui, 0.7, 0.32, 0.36, 0.02, darken(skin, 0.22), { corner = 0.5, rotation = -8, z = 2 })
	rect(gui, 0.5, 0.6, 0.015, 0.36, darken(skin, 0.22), { z = 2 })
	rect(gui, 0.5, 0.55, 0.22, 0.012, darken(skin, 0.2), { z = 2 })
	rect(gui, 0.5, 0.68, 0.22, 0.012, darken(skin, 0.2), { z = 2 })
	local _ = top
	local _a = accent
end

-- Dessine la tenue sur la face avant et arrière du torse.
function Painter.torso(part: BasePart, look, mode: string?)
	local top = look.shirtless and (look.skin or WHITE) or (look.top or WHITE)
	local accent = look.topAccent or darken(top, 0.3)
	local outfit = look.outfit or (look.shirtless and "shirtless" or "shirt")

	local front = surface(part, Enum.NormalId.Front, "ShirtFront", 60, mode)
	-- Base avec léger dégradé (volume) + bords plus sombres
	rect(front, 0.5, 0.5, 1, 1, top, { gradient = { lighten(top, 0.08), darken(top, 0.12) }, z = 0 })
	local painter = OUTFITS[outfit] or OUTFITS.shirt
	painter(front, look, top, accent)
	-- Pantalon visible en bas du torse
	local bottom = look.bottom or INK
	rect(front, 0.5, 0.97, 1, 0.06, bottom, { z = 9 })
	rect(front, 0.5, 0.94, 1, 0.012, darken(bottom, 0.4), { z = 9 })
	-- Ombres sur les côtés (effet de volume)
	rect(front, 0.03, 0.5, 0.06, 1, Color3.new(0, 0, 0), { transparency = 0.82, z = 10 })
	rect(front, 0.97, 0.5, 0.06, 1, Color3.new(0, 0, 0), { transparency = 0.82, z = 10 })

	local back = surface(part, Enum.NormalId.Back, "ShirtBack", 60, mode)
	rect(back, 0.5, 0.5, 1, 1, top, { gradient = { lighten(top, 0.05), darken(top, 0.15) }, z = 0 })
	if outfit == "cloak" then
		cloud(back, 0.3, 0.3, 0.32, accent)
		cloud(back, 0.7, 0.62, 0.32, accent)
	elseif outfit == "jacket" or outfit == "jumpsuit" or outfit == "flakvest" then
		rect(back, 0.5, 0.06, 0.6, 0.12, accent, { z = 2 })
	elseif outfit == "shirtless" then
		rect(back, 0.5, 0.5, 0.015, 0.7, darken(top, 0.18), { z = 2 })
	end
	if look.logo and look.logo.back then
		logo(back, look.logo, 0.5, 0.42, 0.45)
	end
	rect(back, 0.5, 0.97, 1, 0.06, bottom, { z = 9 })
	return front, back
end

return Painter
