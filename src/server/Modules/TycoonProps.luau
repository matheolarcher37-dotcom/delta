-- Éléments fixes de la base (présents dès le départ) : arbre de compétences lumineux + pupitre.
-- (Le comptoir du marchand et l'autel d'éveil ont quitté la base en v3.4 : le marchand ambulant
-- et le stand FAIRE ÉVOLUER du hub font la même chose.)
-- Tout est construit à partir d'un CFrame (repère de la base).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTree = require(Shared.Config.SkillTree)
local Build = require(script.Parent.Build)
local Kit = require(script.Parent.TycoonKit)

local Props = {}

local rgb = Color3.fromRGB
local C = Kit.Colors

local function prompt(parent: Instance, action: string, object: string, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end
Props.prompt = prompt

------------------------------------------------------------------------
-- Arbre de compétences
------------------------------------------------------------------------

local HOLO_SIZE = Vector2.new(17, 15) -- studs
local HEX_PX = 15 -- taille d'une case de l'hologramme (pixels, 20 px/stud)

-- Position (pixels) d'une case hexagonale (q, r) sur l'hologramme (pointe en haut).
local function hexPixel(q: number, r: number): Vector2
	local size = HEX_PX
	return Vector2.new(size * math.sqrt(3) * (q + r / 2), size * 1.5 * r)
end

-- Arbre stylisé : tronc torsadé, houppier sombre piqué de fruits hexagonaux lumineux,
-- hologramme de l'arbre de compétences (cases allumées = nœuds achetés), pupitre avec invite.
function Props.skillTree(parent: Instance, cf: CFrame, lecternCF: CFrame)
	local model = Build.model(parent, "ArbreCompetences")
	local bark = rgb(70, 52, 60)
	-- Socle circulaire en pierre avec incrustations.
	Kit.cylinder(model, "Socle", 1, 17, cf * CFrame.new(0, 0.5, 0), C.StoneDark, { Material = Enum.Material.Slate })
	Kit.cylinder(model, "SocleHaut", 0.4, 15, cf * CFrame.new(0, 1.2, 0), C.StoneMid, { Material = Enum.Material.Slate })
	local ring = Kit.cylinder(model, "AnneauRunes", 0.12, 15.4, cf * CFrame.new(0, 1.0, 0), rgb(120, 230, 255), { Material = Enum.Material.Neon, CanCollide = false })
	Kit.light(ring, rgb(120, 230, 255), 16, 1)
	-- Tronc en segments torsadés + racines.
	local p = cf * CFrame.new(0, 1.4, 0)
	for i, seg in { { 4, 3.2, 8 }, { 4, 2.6, -12 }, { 3.6, 2.1, 14 }, { 3, 1.6, -10 } } do
		local len, thick, twist = seg[1], seg[2], seg[3]
		p = p * CFrame.Angles(0, math.rad(twist * 3), math.rad(twist * 0.4))
		Build.part(model, "Tronc", Vector3.new(thick, len + 0.6, thick), p * CFrame.new(0, len / 2, 0), bark:Lerp(rgb(0, 0, 0), i * 0.04), { Material = Enum.Material.Wood })
		p = p * CFrame.new(0, len, 0)
	end
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5 + 0.3
		Build.part(
			model,
			"Racine",
			Vector3.new(1.2, 1, 4.4),
			cf * CFrame.new(math.cos(a) * 2.6, 1.6, math.sin(a) * 2.6) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(18), 0, 0),
			bark,
			{
				Material = Enum.Material.Wood,
			}
		)
	end
	-- Branches.
	local top = p
	for k = 0, 5 do
		local a = k * math.pi / 3
		local dir = Vector3.new(math.cos(a) * 0.85, 0.55, math.sin(a) * 0.85).Unit
		local start = top.Position - Vector3.new(0, 2, 0)
		local len = 6
		local mid = start + dir * len / 2
		Build.part(model, "Branche", Vector3.new(0.9, len, 0.9), CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(90), 0, 0), bark, { Material = Enum.Material.Wood })
	end
	-- Houppier : boules sombres (bleu nuit) + fruits hexagonaux lumineux aux couleurs des branches.
	local crown = top.Position + Vector3.new(0, 2.2, 0)
	local foliage = { rgb(40, 70, 110), rgb(50, 90, 130), rgb(34, 58, 96) }
	Kit.blob(model, "Feuillage", Vector3.new(15, 8, 15), CFrame.new(crown), foliage[1], { Material = Enum.Material.Grass })
	for k = 1, 8 do
		local a = k * math.pi * 2 / 8
		local offset = Vector3.new(math.cos(a) * 5.4, (k % 2) * 1.6 - 0.6, math.sin(a) * 5.4)
		Kit.blob(model, "Feuillage", Vector3.new(7, 5, 7), CFrame.new(crown + offset), foliage[(k % 3) + 1], { Material = Enum.Material.Grass })
	end
	Kit.blob(model, "Feuillage", Vector3.new(8, 5, 8), CFrame.new(crown + Vector3.new(0, 3.6, 0)), foliage[2], { Material = Enum.Material.Grass })
	local branches = { "chance", "tirage", "revenu", "degats", "critique", "domaine" }
	for k = 1, 12 do
		local a = k * math.pi * 2 / 12 + 0.2
		local y = (k % 3) * 1.6 - 1.4
		local pos = crown + Vector3.new(math.cos(a) * 7.4, y, math.sin(a) * 7.4)
		local color = SkillTree.Branches[branches[(k % 6) + 1]].color
		local fruit = Build.ball(model, "Fruit", 1.2, pos, color, { Material = Enum.Material.Neon, CanCollide = false })
		fruit:SetAttribute("Bob", 0.25)
		CollectionService:AddTag(fruit, "Spin")
	end
	Kit.particles(model:FindFirstChild("Feuillage") :: BasePart, {
		Name = "Lucioles",
		Color = ColorSequence.new(rgb(160, 240, 255)),
		Size = NumberSequence.new(0.35, 0),
		Rate = 6,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180),
	})

	-- Hologramme (panneau transparent, vu de l'avant) : l'arbre de compétences en miniature.
	local holoCF = lecternCF * CFrame.new(0, 9.5, 2.6)
	local holo = Build.deco(model, "Hologramme", Vector3.new(HOLO_SIZE.X, HOLO_SIZE.Y, 0.1), holoCF, rgb(120, 230, 255), { Transparency = 1 })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HoloGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	gui.Parent = holo
	local title = Kit.text(gui, "Titre", "ARBRE DE COMPÉTENCES", UDim2.fromScale(0.05, 0.0), UDim2.fromScale(0.9, 0.09), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
	Kit.gradient(title, { rgb(170, 255, 255), rgb(90, 170, 255) })
	local center = Vector2.new(HOLO_SIZE.X * 20 / 2, HOLO_SIZE.Y * 20 / 2 + 14)
	local cells = {}
	for _, n in SkillTree.Nodes do
		local px = center + hexPixel(n.q, n.r)
		local cell = Instance.new("TextLabel")
		cell.Name = n.id
		cell.BackgroundTransparency = 1
		cell.AnchorPoint = Vector2.new(0.5, 0.5)
		cell.Position = UDim2.fromOffset(px.X, px.Y)
		cell.Size = UDim2.fromOffset(HEX_PX * 1.9, HEX_PX * 1.9)
		cell.Text = "⬢"
		cell.TextScaled = true
		cell.Font = Enum.Font.GothamBlack
		cell.TextColor3 = rgb(60, 70, 90)
		cell.TextTransparency = 0.35
		cell.TextStrokeTransparency = 1
		cell.Parent = gui
		cells[n.id] = cell
	end
	-- Pupitre (lutrin de pierre) avec l'invite qui ouvre l'écran de l'arbre.
	local lectern = Build.model(model, "Pupitre")
	Build.part(lectern, "Pied", Vector3.new(2.2, 3.2, 1.6), lecternCF * CFrame.new(0, 1.6, 0), C.StoneMid, { Material = Enum.Material.Slate })
	local desk = Build.part(
		lectern,
		"Plateau",
		Vector3.new(3.6, 0.5, 2.6),
		lecternCF * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(-25), 0, 0),
		C.StoneDark,
		{ Material = Enum.Material.Slate }
	)
	local book = Build.deco(
		lectern,
		"Grimoire",
		Vector3.new(2.8, 0.25, 1.9),
		desk.CFrame * CFrame.new(0, 0.35, 0),
		rgb(120, 230, 255),
		{ Material = Enum.Material.Neon, Transparency = 0.2 }
	)
	Kit.light(book, rgb(120, 230, 255), 10, 1.4)
	local p2 = prompt(desk, "Ouvrir l'arbre", "Arbre de compétences", 12)
	model:SetAttribute("OpensMenu", "SkillTree")
	return model, { prompt = p2, cells = cells }
end

-- Met à jour l'hologramme : nœuds possédés allumés, nœuds achetables clignotants (plus clairs).
function Props.refreshSkillCells(cells, owned: { [string]: boolean }?)
	for id, cell in cells or {} do
		local n = SkillTree.get(id)
		if n then
			local color = SkillTree.Branches[n.branch].color
			if owned and owned[id] then
				cell.TextColor3 = color
				cell.TextTransparency = 0
			elseif SkillTree.canUnlock(owned, id) then
				cell.TextColor3 = color:Lerp(rgb(255, 255, 255), 0.55)
				cell.TextTransparency = 0.55
			else
				cell.TextColor3 = rgb(60, 70, 90)
				cell.TextTransparency = 0.35
			end
		end
	end
end

function Props.bindSkillTree(model: Model)
	local lectern = model:FindFirstChild("Pupitre")
	local desk = lectern and lectern:FindFirstChild("Plateau")
	local holo = model:FindFirstChild("Hologramme")
	local gui = holo and holo:FindFirstChild("HoloGui")
	local cells = {}
	if gui then
		for _, n in SkillTree.Nodes do
			cells[n.id] = gui:FindFirstChild(n.id)
		end
	end
	return { prompt = desk and desk:FindFirstChild("Prompt"), cells = cells }
end

return Props
