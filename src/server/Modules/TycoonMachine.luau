-- MACHINE DE ROULAGE « ROULER » (comme dans les jeux de tirage) :
--   estrade sombre où les persos tirés apparaissent (6 places, ligne rouge lumineuse),
--   gros bouton hexagonal rouge « ROULER » à gauche (+ barre « x10 Chance dans : N »),
--   panneau néon de pitié à droite (Légendaire / Mythique / Secret dans X rouleaux),
--   grande arche lumineuse derrière, tapis rouge devant.
--
-- Tout est construit par rapport à `cf` : centre de l'estrade, au sol, face (-Z) vers le joueur.
-- La logique (tirage, prix, collecte) est dans Services/RollService.luau.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Build)
local Kit = require(script.Parent.TycoonKit)

local Machine = {}

local rgb = Color3.fromRGB

Machine.TopY = 2.4 -- hauteur du dessus de l'estrade
Machine.Spots = { 15, 9, 3, -3, -9, -15 } -- X des places, de gauche à droite vu du joueur (le perso regarde vers -Z)
Machine.ButtonX = 27 -- à gauche vu du joueur qui arrive par l'entrée
Machine.PityX = -27

local DARK = rgb(46, 50, 64)
local DARK2 = rgb(34, 37, 48)
local EDGE = rgb(70, 76, 96)
local RED = rgb(225, 38, 48)
local RED_DARK = rgb(140, 18, 26)
local CYAN = rgb(60, 220, 255)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radius, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function surface(part: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 50
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = part
	return gui
end

------------------------------------------------------------------------
-- Estrade
------------------------------------------------------------------------

local function buildStage(model: Model, cf: CFrame, refs)
	local top = Machine.TopY
	-- Socle en deux niveaux (bords biseautés par une bande plus claire).
	Build.part(model, "Socle", Vector3.new(46, top - 0.6, 11), cf * CFrame.new(0, (top - 0.6) / 2, 0), DARK2, { Material = Enum.Material.Slate })
	Build.part(model, "Plateau", Vector3.new(44, 0.6, 9.4), cf * CFrame.new(0, top - 0.3, 0), DARK, { Material = Enum.Material.Slate })
	for _, side in { -1, 1 } do
		Build.part(model, "Arete", Vector3.new(46.2, 0.35, 0.6), cf * CFrame.new(0, top - 0.55, side * 5.3), EDGE, { Material = Enum.Material.Metal })
		Build.part(model, "Bout", Vector3.new(0.6, 0.35, 11.2), cf * CFrame.new(side * 22.9, top - 0.55, 0), EDGE, { Material = Enum.Material.Metal })
	end
	-- Marche devant (pour monter regarder les persos de près).
	Build.part(model, "Marche", Vector3.new(30, 0.8, 2.2), cf * CFrame.new(0, 0.4, -6.6), DARK2, { Material = Enum.Material.Slate })
	Build.deco(model, "MarcheLiseré", Vector3.new(30.2, 0.12, 0.25), cf * CFrame.new(0, 0.82, -7.6), rgb(255, 205, 60), { Material = Enum.Material.Neon })
	-- Dalles du plateau (joints).
	for i = -10, 10 do
		Build.deco(model, "Joint", Vector3.new(0.12, 0.05, 9.2), cf * CFrame.new(i * 2.1, top + 0.01, 0), DARK2, { Material = Enum.Material.Slate })
	end
	-- Ligne rouge lumineuse au milieu (comme sur l'image de référence) + faisceau qui défile.
	local line = Build.deco(model, "LigneRouge", Vector3.new(42, 0.08, 0.6), cf * CFrame.new(0, top + 0.03, -2.6), RED, { Material = Enum.Material.Neon })
	Kit.beam(line, Vector3.new(-21, 0.06, 0), Vector3.new(21, 0.06, 0), {
		Width0 = 0.9,
		Width1 = 0.9,
		FaceCamera = false,
		TextureSpeed = 1.6,
		TextureLength = 3,
		Color = ColorSequence.new(rgb(255, 160, 150)),
		Transparency = NumberSequence.new(0.35),
	})
	-- Rambarde arrière avec bandeau néon cyan.
	Build.part(model, "Rambarde", Vector3.new(44, 1.6, 0.8), cf * CFrame.new(0, top + 0.8, 4.4), DARK2, { Material = Enum.Material.Metal })
	local strip = Build.deco(model, "Bandeau", Vector3.new(43, 0.25, 0.85), cf * CFrame.new(0, top + 1.3, 4.4), CYAN, { Material = Enum.Material.Neon })
	Kit.beam(strip, Vector3.new(-21.5, 0, -0.5), Vector3.new(21.5, 0, -0.5), {
		Width0 = 0.5,
		Width1 = 0.5,
		FaceCamera = false,
		TextureSpeed = -1.2,
		Color = ColorSequence.new(rgb(200, 250, 255)),
		Transparency = NumberSequence.new(0.3),
	})

	-- Places : anneau néon (couleur de la rareté quand un perso est là) + projecteur.
	refs.spots = {}
	for i, x in Machine.Spots do
		local spotCF = cf * CFrame.new(x, top, 0)
		local plate = Build.part(model, "Place" .. i, Vector3.new(0.2, 4.6, 4.6), spotCF * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK2, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
		})
		local ring = Build.deco(model, "Anneau" .. i, Vector3.new(0.12, 5, 5), spotCF * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), EDGE, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
		local light = Kit.light(ring, Color3.new(1, 1, 1), 12, 0)
		local burst = Kit.particles(ring, {
			Name = "Eclat",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 4,
		})
		local rise = Kit.particles(ring, {
			Name = "Colonne",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			EmissionDirection = Enum.NormalId.Right, -- axe du cylindre = vers le haut
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(8, 8),
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		local _ = plate
		refs.spots[i] = { cf = spotCF, ring = ring, light = light, burst = burst, rise = rise }
	end
end

------------------------------------------------------------------------
-- Bouton « ROULER » + barre x10
------------------------------------------------------------------------

local function buildButton(model: Model, cf: CFrame, refs)
	local base = cf * CFrame.new(Machine.ButtonX, 0, -0.5)
	Kit.hexTile(model, "SocleHex", base * CFrame.new(0, 1, 0), 4.6, 1, DARK2, { Material = Enum.Material.Slate })
	Kit.hexTile(model, "SocleHex2", base * CFrame.new(0, 1.15, 0), 4.2, 0.2, EDGE, { Material = Enum.Material.Metal })
	Build.part(model, "Colonne", Vector3.new(3, 2.4, 2.4), base * CFrame.new(0, 2.2, 0.4), DARK, { Material = Enum.Material.Metal })
	-- Pupitre incliné vers le joueur.
	local desk = base * CFrame.new(0, 4.1, 0) * CFrame.Angles(math.rad(-28), 0, 0)
	local frame = Build.part(model, "Pupitre", Vector3.new(8.4, 0.9, 6), desk, DARK2, { Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		Build.part(model, "PupitreBord", Vector3.new(0.5, 1.2, 6.2), desk * CFrame.new(side * 4.3, 0.15, 0), DARK, { Material = Enum.Material.Metal })
		Build.part(model, "PupitreBord", Vector3.new(9.1, 1.2, 0.5), desk * CFrame.new(0, 0.15, side * 3.1), DARK, { Material = Enum.Material.Metal })
	end
	-- Gros bouton hexagonal rouge (le dessus s'enfonce quand on roule).
	local hexCF = desk * CFrame.new(0, 0.45, 0)
	Kit.hexTile(model, "BoutonCadre", hexCF * CFrame.new(0, 0.35, 0), 3.3, 0.35, rgb(30, 30, 36), { Material = Enum.Material.Metal })
	local buttonParts = Kit.hexTile(model, "Bouton", hexCF * CFrame.new(0, 0.85, 0), 2.9, 0.6, RED, { Material = Enum.Material.SmoothPlastic })
	Kit.hexTile(model, "BoutonLueur", hexCF * CFrame.new(0, 0.92, 0), 2.35, 0.08, rgb(255, 90, 90), { Material = Enum.Material.Neon, CanCollide = false })
	-- Plaque couchée sur le bouton : sa face avant regarde vers le haut du pupitre, le haut du
	-- texte part vers le fond → lisible par le joueur qui se tient devant.
	local label = Build.deco(model, "BoutonTexte", Vector3.new(4.4, 1.6, 0.05), hexCF * CFrame.new(0, 0.98, 0) * CFrame.Angles(math.rad(90), 0, 0), RED, { Transparency = 1 })
	local gui = surface(label, Enum.NormalId.Front, 60)
	Kit.text(gui, "Texte", "ROULER", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy, RED_DARK)
	local glow = Kit.light(buttonParts[1], rgb(255, 70, 70), 14, 1.2)
	refs.buttonParts = buttonParts
	refs.buttonGlow = glow
	refs.buttonPress = desk.UpVector * -0.35

	-- Barre « x10 Chance dans : N » au-dessus du pupitre.
	local barCF = base * CFrame.new(0, 7.6, 1.6)
	local bar = Build.part(model, "PanneauX10", Vector3.new(8.4, 2.4, 0.4), barCF, DARK2, { Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		Build.part(model, "MontantX10", Vector3.new(0.4, 5, 0.4), base * CFrame.new(side * 3.6, 6.2, 1.8), DARK, { Material = Enum.Material.Metal })
	end
	local barGui = surface(bar, Enum.NormalId.Front, 50)
	local x10Text = Kit.text(barGui, "Titre", "x10 Chance dans : 10", UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.46), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	local track = Instance.new("Frame")
	track.Name = "Jauge"
	track.Position = UDim2.fromScale(0.06, 0.58)
	track.Size = UDim2.fromScale(0.88, 0.3)
	track.BackgroundColor3 = rgb(20, 22, 28)
	track.BorderSizePixel = 0
	track.Parent = barGui
	corner(track, 0.5)
	stroke(track, rgb(0, 0, 0), 2)
	local fill = Instance.new("Frame")
	fill.Name = "Remplissage"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = rgb(110, 230, 60)
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 0.5)
	Kit.gradient(fill, { rgb(170, 255, 90), rgb(60, 190, 40) })
	refs.x10Text = x10Text
	refs.x10Fill = fill
	refs.x10Panel = bar

	-- Invite (clavier E, manette X, toucher sur mobile).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Rouler"
	prompt.ObjectText = "Machine ROULER"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = frame
	refs.prompt = prompt
end

------------------------------------------------------------------------
-- Panneau de pitié
------------------------------------------------------------------------

local function buildPityPanel(model: Model, cf: CFrame, refs)
	local base = cf * CFrame.new(Machine.PityX, 0, -0.5)
	Build.part(model, "SoclePitie", Vector3.new(8.6, 1.2, 4.4), base * CFrame.new(0, 0.6, 0.6), DARK2, { Material = Enum.Material.Slate })
	local stripe = Build.deco(model, "SoclePitieNeon", Vector3.new(8.8, 0.3, 4.6), base * CFrame.new(0, 1.05, 0.6), CYAN, { Material = Enum.Material.Neon })
	Kit.light(stripe, CYAN, 10, 1)
	local panelCF = base * CFrame.new(0, 4.4, 0.8) * CFrame.Angles(math.rad(-12), 0, 0)
	local panel = Build.part(model, "PanneauPitie", Vector3.new(8.6, 5.6, 0.5), panelCF, rgb(16, 18, 26), { Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		Build.part(model, "CadrePitie", Vector3.new(0.5, 6.2, 0.8), panelCF * CFrame.new(side * 4.45, 0, 0), DARK, { Material = Enum.Material.Metal })
		Build.part(model, "CadrePitie", Vector3.new(9.4, 0.5, 0.8), panelCF * CFrame.new(0, side * 3, 0), DARK, { Material = Enum.Material.Metal })
	end
	local gui = surface(panel, Enum.NormalId.Front, 40)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(14, 16, 26)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	Kit.gradient(bg, { rgb(30, 34, 56), rgb(10, 10, 18) })
	local title = Kit.text(gui, "Titre", "🛡️ GARANTIES", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.2), rgb(120, 230, 255), Enum.Font.LuckiestGuy)
	local _ = title
	refs.pityLines = {}
	local defs = {
		{ "legendary", "Légendaire", { rgb(255, 236, 110), rgb(255, 150, 20) } },
		{ "mythic", "Mythique", { rgb(255, 120, 110), rgb(210, 20, 40) } },
		{ "secret", "Secret", { rgb(255, 90, 90), rgb(255, 230, 70), rgb(90, 255, 120), rgb(90, 170, 255), rgb(230, 100, 255) } },
	}
	for i, d in defs do
		local y = 0.26 + (i - 1) * 0.245
		local row = Instance.new("Frame")
		row.Name = "Ligne" .. d[1]
		row.Position = UDim2.fromScale(0.04, y)
		row.Size = UDim2.fromScale(0.92, 0.22)
		row.BackgroundColor3 = rgb(0, 0, 0)
		row.BackgroundTransparency = 0.45
		row.BorderSizePixel = 0
		row.Parent = gui
		corner(row, 0.3)
		local name = Kit.text(row, "Rarete", d[2], UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.42, 0.84), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
		Kit.gradient(name, d[3], 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local count = Kit.text(row, "Reste", "dans 150 rouleaux", UDim2.fromScale(0.45, 0.14), UDim2.fromScale(0.53, 0.72), Color3.new(1, 1, 1), Enum.Font.GothamBold)
		count.TextXAlignment = Enum.TextXAlignment.Right
		refs.pityLines[d[1]] = count
	end
end

------------------------------------------------------------------------
-- Arche lumineuse
------------------------------------------------------------------------

local function buildArch(model: Model, cf: CFrame, refs)
	local back = cf * CFrame.new(0, 0, 7.4)
	local h = 17
	for _, side in { -1, 1 } do
		local pcf = back * CFrame.new(side * 21.5, 0, 0)
		Kit.hexTile(model, "PiedPilier", pcf * CFrame.new(0, 1.4, 0), 2.8, 1.4, DARK2, { Material = Enum.Material.Slate })
		Build.part(model, "Pilier", Vector3.new(2.6, h, 2.6), pcf * CFrame.new(0, h / 2 + 1.4, 0), DARK, { Material = Enum.Material.Metal })
		-- Capsule de verre lumineuse sur chaque pilier (tourbillon d'énergie).
		local capsule = Build.deco(model, "Capsule", Vector3.new(6, 2.2, 2.2), pcf * CFrame.new(0, 7, -1.7) * CFrame.Angles(0, 0, math.rad(90)), rgb(170, 230, 255), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Glass,
			Transparency = 0.45,
		})
		local core = Build.deco(model, "Noyau", Vector3.new(5, 1, 1), pcf * CFrame.new(0, 7, -1.7) * CFrame.Angles(0, 0, math.rad(90)), CYAN, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
		})
		Kit.particles(core, {
			Name = "Tourbillon",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 10,
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new(rgb(160, 240, 255)),
		})
		Kit.light(core, CYAN, 12, 1.4)
		local _ = capsule
		for k = 0, 3 do
			Build.deco(model, "Bague", Vector3.new(2.9, 0.4, 2.9), pcf * CFrame.new(0, 3 + k * 4.4, 0), rgb(255, 205, 60), { Material = Enum.Material.Metal })
		end
	end
	-- Linteau + enseigne.
	local beamCF = back * CFrame.new(0, h + 2.6, 0)
	Build.part(model, "Linteau", Vector3.new(47, 3.2, 3), beamCF, DARK, { Material = Enum.Material.Metal })
	Build.part(model, "LinteauHaut", Vector3.new(49, 0.8, 3.6), beamCF * CFrame.new(0, 2, 0), DARK2, { Material = Enum.Material.Metal })
	local neon = Build.deco(model, "LinteauNeon", Vector3.new(47.2, 0.3, 3.1), beamCF * CFrame.new(0, -1.7, 0), rgb(255, 60, 80), { Material = Enum.Material.Neon })
	Kit.beam(neon, Vector3.new(-23, -0.2, -1.6), Vector3.new(23, -0.2, -1.6), {
		Width0 = 0.6,
		Width1 = 0.6,
		FaceCamera = false,
		TextureSpeed = 2,
		Color = ColorSequence.new(rgb(255, 200, 200)),
		Transparency = NumberSequence.new(0.25),
	})
	local sign = Build.part(model, "Enseigne", Vector3.new(24, 4.6, 0.6), beamCF * CFrame.new(0, 0.6, -1.8), rgb(18, 18, 26), { Material = Enum.Material.Metal })
	local gui = surface(sign, Enum.NormalId.Front, 30)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = rgb(255, 255, 255)
	bg.Parent = gui
	Kit.gradient(bg, { rgb(120, 20, 40), rgb(40, 10, 30) })
	local title = Kit.text(gui, "Titre", "MACHINE À PERSOS", UDim2.fromScale(0.03, 0.06), UDim2.fromScale(0.94, 0.6), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
	Kit.gradient(title, { rgb(255, 245, 160), rgb(255, 170, 40) })
	refs.universeLabel = Kit.text(gui, "Univers", "Univers actuel", UDim2.fromScale(0.05, 0.66), UDim2.fromScale(0.9, 0.3), rgb(150, 230, 255), Enum.Font.GothamBlack)
	-- Emblème hexagonal qui tourne au-dessus (animé par le client, tag « Spin »).
	local emblem = Build.deco(model, "Embleme", Vector3.new(7, 7, 0.4), beamCF * CFrame.new(0, 6.6, 0), rgb(20, 20, 28), { Transparency = 1 })
	local egui = surface(emblem, Enum.NormalId.Front, 40)
	local hex = Kit.text(egui, "Hex", "⬢", UDim2.fromScale(-0.1, -0.15), UDim2.fromScale(1.2, 1.3), rgb(255, 255, 255), Enum.Font.GothamBlack)
	Kit.gradient(hex, { rgb(255, 80, 90), rgb(255, 210, 60), rgb(80, 220, 255) }, 45)
	local star = Kit.text(egui, "Etoile", "★", UDim2.fromScale(0.25, 0.22), UDim2.fromScale(0.5, 0.56), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	local _ = star
	local egui2 = surface(emblem, Enum.NormalId.Back, 40)
	local hex2 = Kit.text(egui2, "Hex", "⬢", UDim2.fromScale(-0.1, -0.15), UDim2.fromScale(1.2, 1.3), rgb(255, 255, 255), Enum.Font.GothamBlack)
	Kit.gradient(hex2, { rgb(255, 80, 90), rgb(255, 210, 60), rgb(80, 220, 255) }, 45)
	emblem:SetAttribute("SpinAxis", "Z")
	emblem:SetAttribute("SpinSpeed", 0.8)
	emblem:SetAttribute("Bob", 0.3)
	CollectionService:AddTag(emblem, "Spin")
	-- Projecteurs suspendus au linteau, braqués sur l'estrade.
	for i, x in Machine.Spots do
		local lamp = Build.deco(
			model,
			"Projecteur" .. i,
			Vector3.new(1.2, 1.2, 1.6),
			beamCF * CFrame.new(x, -2.4, -1.2) * CFrame.Angles(math.rad(-50), 0, 0),
			DARK2,
			{ Material = Enum.Material.Metal }
		)
		Build.deco(model, "ProjecteurVerre", Vector3.new(0.9, 0.9, 0.1), lamp.CFrame * CFrame.new(0, 0, -0.85), rgb(255, 245, 210), { Material = Enum.Material.Neon })
	end
	refs.sign = sign
end

-- Tapis rouge qui mène de l'entrée à l'estrade.
local function buildCarpet(model: Model, cf: CFrame, length: number)
	local start = cf * CFrame.new(0, 0, -7.7 - length / 2)
	Build.part(model, "Tapis", Vector3.new(9, 0.16, length), start * CFrame.new(0, 0.28, 0), rgb(196, 30, 40), { Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		Build.part(model, "TapisBord", Vector3.new(0.7, 0.18, length), start * CFrame.new(side * 4.85, 0.29, 0), rgb(255, 200, 60), { Material = Enum.Material.Fabric })
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Construit la machine ; renvoie (modèle, refs) — refs : prompt, spots[i] = { cf, ring, light,
-- burst, rise }, x10Text, x10Fill, pityLines[rareté], buttonParts, universeLabel.
function Machine.build(parent: Instance, cf: CFrame, carpetLength: number?)
	local model = Build.model(parent, "RollMachine")
	local refs = { model = model }
	buildStage(model, cf, refs)
	buildButton(model, cf, refs)
	buildPityPanel(model, cf, refs)
	buildArch(model, cf, refs)
	buildCarpet(model, cf, carpetLength or 20)
	return model, refs
end

-- Retrouve les références d'une machine déjà construite (fichier pré-construit / Studio).
function Machine.bind(model: Model, cf: CFrame)
	local refs = { model = model }
	local frame = model:FindFirstChild("Pupitre")
	refs.prompt = frame and frame:FindFirstChild("Prompt")
	refs.spots = {}
	for i, x in Machine.Spots do
		local ring = model:FindFirstChild("Anneau" .. i)
		refs.spots[i] = {
			cf = cf * CFrame.new(x, Machine.TopY, 0),
			ring = ring,
			light = ring and ring:FindFirstChildOfClass("PointLight"),
			burst = ring and ring:FindFirstChild("Eclat"),
			rise = ring and ring:FindFirstChild("Colonne"),
		}
	end
	local bar = model:FindFirstChild("PanneauX10")
	local barGui = bar and bar:FindFirstChildOfClass("SurfaceGui")
	refs.x10Text = barGui and barGui:FindFirstChild("Titre")
	local track = barGui and barGui:FindFirstChild("Jauge")
	refs.x10Fill = track and track:FindFirstChild("Remplissage")
	refs.pityLines = {}
	local panel = model:FindFirstChild("PanneauPitie")
	local gui = panel and panel:FindFirstChildOfClass("SurfaceGui")
	for _, key in { "legendary", "mythic", "secret" } do
		local row = gui and gui:FindFirstChild("Ligne" .. key)
		refs.pityLines[key] = row and row:FindFirstChild("Reste")
	end
	refs.buttonParts = {}
	for _, child in model:GetChildren() do
		if child.Name == "Bouton" and child:IsA("BasePart") then
			table.insert(refs.buttonParts, child)
		end
	end
	local sign = model:FindFirstChild("Enseigne")
	local signGui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	refs.universeLabel = signGui and signGui:FindFirstChild("Univers")
	local pupitre = model:FindFirstChild("Pupitre") :: BasePart?
	refs.buttonPress = pupitre and pupitre.CFrame.UpVector * -0.35 or Vector3.new(0, -0.3, 0)
	return refs
end

function Machine.setX10(refs, remaining: number, every: number)
	if refs.x10Text then
		refs.x10Text.Text = remaining <= 1 and "⚡ PROCHAIN : CHANCE x10 ! ⚡" or ("x10 Chance dans : " .. remaining)
		refs.x10Text.TextColor3 = remaining <= 1 and rgb(255, 230, 80) or Color3.new(1, 1, 1)
	end
	if refs.x10Fill then
		local ratio = math.clamp((every - remaining) / math.max(1, every - 1), 0, 1)
		refs.x10Fill.Size = UDim2.fromScale(math.max(0.04, ratio), 1)
	end
end

function Machine.setPity(refs, remaining: { [string]: number })
	for key, label in refs.pityLines or {} do
		local n = remaining[key]
		if label and n then
			label.Text = n <= 1 and "PROCHAIN ROULEAU !" or ("dans " .. n .. " rouleaux")
		end
	end
end

-- Le bouton s'enfonce puis remonte, et la lueur clignote.
function Machine.press(refs, x10: boolean?)
	for _, part in refs.buttonParts or {} do
		local home = part.CFrame
		local down = TweenService:Create(part, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { CFrame = home + refs.buttonPress })
		down:Play()
		part.Color = x10 and rgb(255, 210, 50) or RED
		task.delay(0.25, function()
			pcall(function()
				part.CFrame = home
				part.Color = RED
			end)
		end)
	end
end

-- Allume la place `i` à la couleur de la rareté (ou l'éteint avec nil).
function Machine.lightSpot(refs, i: number, color: Color3?, strong: boolean?)
	local spot = refs.spots and refs.spots[i]
	if not spot or not spot.ring then
		return
	end
	spot.ring.Color = color or EDGE
	spot.ring.Transparency = color and 0 or 0.2
	if spot.light then
		spot.light.Color = color or Color3.new(1, 1, 1)
		spot.light.Brightness = color and (strong and 3 or 1.6) or 0
		spot.light.Range = strong and 18 or 12
	end
	if spot.rise then
		spot.rise.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
		spot.rise.Rate = (color and strong) and 14 or 0
	end
end

-- Gerbe d'étincelles quand un perso apparaît.
function Machine.burst(refs, i: number, color: Color3, amount: number?)
	local spot = refs.spots and refs.spots[i]
	if spot and spot.burst then
		spot.burst.Color = ColorSequence.new(color)
		spot.burst:Emit(amount or 30)
	end
end

return Machine
