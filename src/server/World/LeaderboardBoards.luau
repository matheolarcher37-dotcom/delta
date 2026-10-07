-- TROIS GRANDS TABLEAUX DE CLASSEMENT (près de Layout.Leaderboard, tournés vers le hub) :
--   • LES PLUS GÉNÉREUX : Robux dépensés dans le jeu
--   • LES PLUS RICHES    : pièces (¥)
--   • LE PERSO LE PLUS FORT : puissance de la meilleure unité
-- Tableau en bois sculpté avec cadre, fronton peint, petit toit, lanternes et 10 lignes (rang,
-- nom, valeur). Les lignes sont remplies par LeaderboardService.

local Build = require(script.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Kit.Core)
local Archi = require(script.Parent.Kit.Archi)
local Props = require(script.Parent.Kit.Props)

local LeaderboardBoards = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local WOOD = rgb(92, 62, 42)
local WOOD_DARK = rgb(58, 38, 28)
local STONE = rgb(120, 116, 110)
local GOLD = rgb(214, 170, 72)

LeaderboardBoards.List = {
	{ id = "Robux", name = "Classement_Robux", title = "LES PLUS GÉNÉREUX", sub = "Robux dépensés dans le jeu", color = rgb(40, 170, 110), crest = "R$" },
	{ id = "Coins", name = "Classement_Pieces", title = "LES PLUS RICHES", sub = "Pièces (¥)", color = rgb(200, 150, 40), crest = "¥" },
	{ id = "Power", name = "Classement_Perso", title = "LE PERSO LE PLUS FORT", sub = "Puissance de la meilleure unité", color = rgb(190, 60, 60), crest = "⚔" },
}

LeaderboardBoards.Rows = 10
local MEDALS = { rgb(255, 210, 70), rgb(215, 222, 235), rgb(220, 140, 80) }
LeaderboardBoards.Medals = MEDALS

local function text(parent: Instance, name: string, value: string, size: UDim2, position: UDim2, color: Color3, font: Enum.Font, align: Enum.TextXAlignment?)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = rgb(20, 12, 8)
	label.Parent = parent
	return label
end

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

-- Contenu du tableau (SurfaceGui « Display » sur la face avant du panneau).
local function display(panel: BasePart, info)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = panel

	local bg = Instance.new("Frame")
	bg.Name = "Fond"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(26, 22, 30)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(46, 38, 44), rgb(18, 16, 22))
	gradient.Rotation = 90
	gradient.Parent = bg

	text(bg, "Sous", info.sub, UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.02), rgb(235, 220, 190), Enum.Font.GothamBold)
	text(bg, "ColRang", "RANG", UDim2.fromScale(0.14, 0.032), UDim2.fromScale(0.04, 0.095), rgb(170, 160, 150), Enum.Font.GothamBold)
	text(bg, "ColNom", "JOUEUR", UDim2.fromScale(0.4, 0.032), UDim2.fromScale(0.2, 0.095), rgb(170, 160, 150), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	text(bg, "ColValeur", "VALEUR", UDim2.fromScale(0.3, 0.032), UDim2.fromScale(0.66, 0.095), rgb(170, 160, 150), Enum.Font.GothamBold, Enum.TextXAlignment.Right)

	for i = 1, LeaderboardBoards.Rows do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Size = UDim2.fromScale(0.94, 0.074)
		row.Position = UDim2.fromScale(0.03, 0.14 + (i - 1) * 0.081)
		row.BackgroundColor3 = i <= 3 and MEDALS[i]:Lerp(rgb(30, 24, 30), 0.72) or (i % 2 == 0 and rgb(40, 34, 42) or rgb(32, 28, 36))
		row.BorderSizePixel = 0
		row.Parent = bg
		corner(row, 0.25)
		if i <= 3 then
			local stroke = Instance.new("UIStroke")
			stroke.Color = MEDALS[i]
			stroke.Thickness = 2
			stroke.Transparency = 0.25
			stroke.Parent = row
		end
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.fromScale(0.1, 0.84)
		badge.Position = UDim2.fromScale(0.03, 0.08)
		badge.BackgroundColor3 = MEDALS[i] or rgb(84, 78, 90)
		badge.BorderSizePixel = 0
		badge.Parent = row
		corner(badge, 0.5)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.Parent = badge
		text(badge, "Rang", tostring(i), UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), i <= 3 and rgb(60, 36, 10) or rgb(240, 236, 230), Enum.Font.LuckiestGuy).TextStrokeTransparency =
			1
		text(row, "Nom", "—", UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.17, 0.15), i <= 3 and MEDALS[i] or rgb(240, 236, 230), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		text(
			row,
			"Valeur",
			"",
			UDim2.fromScale(0.32, 0.7),
			UDim2.fromScale(0.65, 0.15),
			info.color:Lerp(rgb(255, 255, 255), 0.45),
			Enum.Font.GothamBlack,
			Enum.TextXAlignment.Right
		)
	end
	text(bg, "Pied", "Mis à jour toutes les 2 minutes", UDim2.fromScale(0.9, 0.03), UDim2.fromScale(0.05, 0.955), rgb(150, 140, 130), Enum.Font.Gotham)
	return gui
end

-- Un tableau : poteaux, cadre sculpté, fronton, toit, lanternes. `cf` = centre au sol, face avant
-- (LookVector) tournée vers les joueurs.
local function board(parent: Instance, info, cf: CFrame)
	local model = Build.model(parent, info.name)
	local W, H = 22, 25
	local panelCF = cf * CFrame.new(0, 4 + H / 2, 0)
	local panel = Build.part(model, "Panel", Vector3.new(W, H, 0.8), panelCF, rgb(30, 26, 32), { Material = Enum.Material.SmoothPlastic })
	-- Planche de fond (dos) et cadre en bois sculpté avec coins dorés.
	Build.part(model, "Dos", Vector3.new(W + 2.4, H + 2.4, 0.6), panelCF * CFrame.new(0, 0, 0.6), WOOD_DARK, { Material = Enum.Material.Wood })
	for _, side in { -1, 1 } do
		Build.part(model, "CadreV", Vector3.new(1.2, H + 2.4, 1.3), panelCF * CFrame.new(side * (W / 2 + 0.6), 0, 0.05), WOOD, { Material = Enum.Material.Wood })
		Build.part(model, "CadreH", Vector3.new(W + 2.4, 1.2, 1.3), panelCF * CFrame.new(0, side * (H / 2 + 0.6), 0.05), WOOD, { Material = Enum.Material.Wood })
		for _, vertical in { -1, 1 } do
			Build.part(model, "CoinDore", Vector3.new(1.6, 1.6, 1.5), panelCF * CFrame.new(side * (W / 2 + 0.6), vertical * (H / 2 + 0.6), 0), GOLD, {
				Material = Enum.Material.Metal,
			})
		end
	end
	-- Poteaux et pieds en pierre.
	for _, side in { -1, 1 } do
		local x = side * (W / 2 + 1.6)
		Build.part(model, "Poteau", Vector3.new(1.6, H + 9, 1.6), cf * CFrame.new(x, (H + 9) / 2, 0.4), WOOD_DARK, { Material = Enum.Material.Wood })
		Archi.block(model, "Pied", Vector3.new(2.8, 1.4, 2.8), cf * CFrame.new(x, 0, 0.4), STONE, Enum.Material.Slate)
		local rot = cf - cf.Position
		Props.hangingLantern(model, (cf * CFrame.new(x + side * 0.8, H + 1, 0.4)).Position, rot:VectorToWorldSpace(Vector3.new(side * 1.8, 0, 0)), info.color, 1)
	end
	-- Fronton peint (titre) et petit toit.
	local header = Build.part(model, "Header", Vector3.new(W + 3, 4.2, 1.4), cf * CFrame.new(0, 4 + H + 3.2, 0), info.color:Lerp(WOOD_DARK, 0.35), {
		Material = Enum.Material.Wood,
	})
	Build.surfaceText(header, Enum.NormalId.Front, info.title, rgb(255, 246, 225), { Font = Enum.Font.LuckiestGuy })
	Archi.gableRoof(model, cf * CFrame.new(0, 4 + H + 5.5, 0.3), W + 4, 3.2, 2.2, 1.2, rgb(70, 56, 52), { upturn = true })
	-- Écusson au-dessus du fronton (R$, ¥, épée).
	local crest = Build.part(model, "Ecusson", Vector3.new(0.6, 4, 4), cf * CFrame.new(0, 4 + H + 8.6, -0.4) * CFrame.Angles(0, math.rad(90), 0), GOLD, {
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Cylinder,
	})
	Build.surfaceText(crest, Enum.NormalId.Right, info.crest, rgb(70, 40, 10), { Font = Enum.Font.LuckiestGuy, TextStrokeTransparency = 1 })
	display(panel, info)
	-- Lumière douce pour lire le tableau la nuit.
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Brightness = 0.6
	light.Range = 10
	light.Angle = 70
	light.Color = rgb(255, 230, 190)
	light.Parent = header
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	return model
end

-- Construit les trois tableaux en arc autour de `center`, tournés vers le hub (0, 0, 0).
function LeaderboardBoards.build(parent: Instance, center: Vector3): { Model }
	local flat = Vector3.new(center.X, 0, center.Z)
	local toHub = (-flat).Unit
	local right = toHub:Cross(UP).Unit
	local models = {}
	local spots = {
		{ offset = -25, forward = 5, turn = -24 },
		{ offset = 0, forward = 0, turn = 0 },
		{ offset = 25, forward = 5, turn = 24 },
	}
	for i, info in LeaderboardBoards.List do
		local spot = spots[i]
		local position = Vector3.new(center.X, center.Y, center.Z) + right * spot.offset + toHub * spot.forward
		local cf = CFrame.lookAt(position, position + toHub) * CFrame.Angles(0, math.rad(spot.turn), 0)
		table.insert(models, board(parent, info, cf))
	end
	-- Petit dallage devant les tableaux.
	local paving = Core.shade(STONE, 0.05)
	Build.part(
		parent,
		"DallageClassements",
		Vector3.new(70, 0.4, 16),
		CFrame.lookAt(flat + toHub * 9 + Vector3.new(0, 0.2, 0), flat + toHub * 20 + Vector3.new(0, 0.2, 0)),
		paving,
		{
			Material = Enum.Material.Cobblestone,
			CanCollide = false,
		}
	)
	return models
end

return LeaderboardBoards
