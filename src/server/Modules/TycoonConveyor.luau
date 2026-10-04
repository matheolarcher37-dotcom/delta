-- Chaîne de production de la base : tapis roulant, distributeurs (« droppers »), coffre des
-- revenus et grand compteur d'argent. Les distributeurs lâchent des pièces qui glissent sur
-- le tapis jusqu'au coffre : c'est visuel (le revenu réel est calculé par CharacterService),
-- mais c'est ce qui donne vie à la base, comme dans les tycoons classiques.
--
-- Un chemin de pièces = { kind = "coin" | "gold" | "gem", interval = s, points = { Vector3 (monde) } } :
-- point 1 = sortie de la buse, puis le tapis, le dernier point = l'intérieur du coffre.

local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Build)
local Kit = require(script.Parent.TycoonKit)

local Conveyor = {}

local rgb = Color3.fromRGB
local C = Kit.Colors
local BELT_SPEED = 7 -- studs par seconde

Conveyor.Styles = {
	bronze = { body = C.Lacquer, trim = C.Gold, glow = rgb(255, 190, 80), coin = "coin", interval = 2.4, label = "x1" },
	gold = { body = rgb(250, 196, 50), trim = rgb(255, 245, 200), glow = rgb(255, 230, 120), coin = "gold", interval = 1.8, label = "x2" },
	crystal = { body = rgb(70, 110, 220), trim = rgb(170, 240, 255), glow = rgb(120, 230, 255), coin = "gem", interval = 1.4, label = "x5" },
}

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

-- Tapis roulant de `a` à `b` (positions monde au sol), dessus à la hauteur `y`.
function Conveyor.belt(folder: Instance, a: Vector3, b: Vector3, y: number)
	local delta = b - a
	local length = delta.Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + Vector3.new(delta.X, 0, delta.Z)) -- longueur sur Z
	local model = Build.model(folder, "Tapis")
	Build.part(model, "Chassis", Vector3.new(4.6, y - 0.4, length + 4.6), cf * CFrame.new(0, (y - 0.4) / 2, 0), rgb(70, 72, 82), { Material = Enum.Material.DiamondPlate })
	local surface = Build.part(model, "Bande", Vector3.new(3.6, 0.3, length + 3.6), cf * CFrame.new(0, y - 0.15, 0), rgb(38, 38, 44), { Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		Build.part(model, "Rebord", Vector3.new(0.5, 0.7, length + 4.6), cf * CFrame.new(side * 2.05, y + 0.15, 0), rgb(255, 196, 40), { Material = Enum.Material.Metal })
	end
	local rollers = math.floor(length / 3)
	for i = 0, rollers do
		local z = -length / 2 + length * i / math.max(rollers, 1)
		Build.part(model, "Rouleau", Vector3.new(4.75, 0.7, 0.7), cf * CFrame.new(0, y - 0.55, z), rgb(150, 152, 160), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	-- Flèches lumineuses qui défilent (texture intégrée animée par le moteur, sans script).
	Kit.beam(surface, Vector3.new(0, 0.2, length / 2 + 1.5), Vector3.new(0, 0.2, -length / 2 - 1.5), {
		FaceCamera = false,
		TextureLength = 3,
		TextureSpeed = 1.2,
		Width0 = 2.6,
		Width1 = 2.6,
		LightEmission = 0.6,
		Transparency = NumberSequence.new(0.55),
		Color = ColorSequence.new(rgb(255, 220, 120)),
	})
	return model
end

-- Distributeur posé à côté du tapis : `cf` = pied du distributeur, la buse est à `+nozzleX` (X local).
function Conveyor.dropper(folder: Instance, cf: CFrame, nozzleX: number, styleName: string, ghost: boolean?)
	local style = Conveyor.Styles[styleName] or Conveyor.Styles.bronze
	for _, x in { -2.3, 2.3 } do
		for _, dz in { -2.3, 2.3 } do
			Build.part(folder, "Pied", Vector3.new(0.9, 6, 0.9), cf * CFrame.new(x, 3, dz), C.WoodDark, { Material = Enum.Material.Wood })
		end
	end
	Build.part(folder, "Plateforme", Vector3.new(6.2, 0.6, 6.2), cf * CFrame.new(0, 6.2, 0), C.WoodDark, { Material = Enum.Material.Wood })
	local body = Build.part(folder, "Caisson", Vector3.new(5.4, 4.6, 5.4), cf * CFrame.new(0, 8.8, 0), style.body, { Material = Enum.Material.SmoothPlastic })
	for _, y in { 6.75, 10.85 } do
		Build.part(folder, "Cerclage", Vector3.new(5.8, 0.45, 5.8), cf * CFrame.new(0, y, 0), style.trim, { Material = Enum.Material.Metal })
	end
	Build.part(folder, "Hublot", Vector3.new(0.3, 2.6, 2.6), cf * CFrame.new(2.75, 8.8, 0), style.glow, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon })
	Kit.roof(folder, cf * CFrame.new(0, 11.1, 0), 7, 7.4, 2.2, C.RoofTile, { name = "ToitDistributeur" })
	-- Bras + buse au-dessus du tapis.
	Build.part(folder, "Bras", Vector3.new(nozzleX - 2.4, 1.6, 1.6), cf * CFrame.new(2.7 + (nozzleX - 2.7) / 2, 9.4, 0), rgb(90, 92, 104), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
	Kit.cylinder(folder, "Buse", 3, 2, cf * CFrame.new(nozzleX, 8.2, 0), rgb(90, 92, 104), { Material = Enum.Material.Metal })
	Kit.cylinder(folder, "BuseLueur", 0.3, 1.5, cf * CFrame.new(nozzleX, 6.6, 0), style.glow, { Material = Enum.Material.Neon, CanCollide = false })
	local plate = Build.part(folder, "Plaque", Vector3.new(0.3, 1.6, 3.4), cf * CFrame.new(2.85, 7.6, 0), C.Panel)
	if not ghost then
		Build.surfaceText(plate, Enum.NormalId.Right, "🪙 " .. style.label, style.glow)
		Kit.light(body, style.glow, 12, 1.2)
	end
end

-- Coffre des revenus : on marche sur le disque doré pour récupérer l'argent accumulé.
-- `cf` = centre du coffre au sol (face -Z vers l'entrée). Renvoie (modèle, pad, label).
function Conveyor.chest(folder: Instance, cf: CFrame)
	local model = Build.model(folder, "Stash")
	local padCF = cf * CFrame.new(0, 0, -5.5)
	local pad = Build.part(model, "Pad", Vector3.new(0.5, 7.5, 7.5), padCF * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 200, 50), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	pad.CanTouch = true
	Build.part(model, "PadBord", Vector3.new(0.4, 8.6, 8.6), padCF * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(60, 50, 40), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
	local wood = rgb(140, 90, 50)
	Build.part(model, "Socle", Vector3.new(8, 1, 6), cf * CFrame.new(0, 0.5, 0), C.StoneMid, { Material = Enum.Material.Slate })
	Build.part(model, "Chest", Vector3.new(6.4, 3.2, 4.2), cf * CFrame.new(0, 2.6, 0), wood, { Material = Enum.Material.WoodPlanks })
	local lid = Build.part(model, "Lid", Vector3.new(6.6, 1.4, 4.4), cf * CFrame.new(0, 4.9, 0.6) * CFrame.Angles(math.rad(-25), 0, 0), wood:Lerp(rgb(0, 0, 0), 0.15), {
		Material = Enum.Material.WoodPlanks,
	})
	local gold = Build.deco(model, "Gold", Vector3.new(5.8, 0.5, 3.6), cf * CFrame.new(0, 4.25, 0), rgb(255, 210, 60), { Material = Enum.Material.Neon })
	for _, x in { -2.4, 2.4 } do
		Build.deco(model, "Band", Vector3.new(0.45, 3.4, 4.35), cf * CFrame.new(x, 2.6, 0), rgb(255, 200, 60), { Material = Enum.Material.Metal })
	end
	Build.deco(model, "Serrure", Vector3.new(1, 1.2, 0.3), cf * CFrame.new(0, 3.4, -2.2), rgb(255, 220, 90), { Material = Enum.Material.Metal })
	for i = 1, 7 do
		Kit.coin(model, cf * CFrame.new(-2.6 + i * 0.7, 4.65 + (i % 2) * 0.2, -0.8 + (i % 3) * 0.6) * CFrame.Angles(0.4 * (i % 3), 0, 0.3), 1.2)
	end
	Kit.light(gold, rgb(255, 210, 90), 14, 1.4)
	Kit.particles(gold, {
		Name = "Scintillement",
		Color = ColorSequence.new(rgb(255, 230, 120)),
		Size = NumberSequence.new(0.5, 0),
		Rate = 6,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(40, 40),
	})
	local gui = Build.billboard(lid, UDim2.new(6, 60, 2.2, 24), Vector3.new(0, 4.2, 0), 120)
	gui.Name = "StashGui"
	local label = Kit.text(gui, "Amount", "¥ 0", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.62), rgb(255, 225, 80), Enum.Font.LuckiestGuy)
	Kit.text(gui, "Hint", "Marche sur le disque doré pour récupérer", UDim2.fromScale(0, 0.64), UDim2.fromScale(1, 0.34), rgb(255, 255, 255), Enum.Font.GothamBold)
	return model, pad, label
end

-- Grand compteur d'argent (lisible de loin, à la télé comme sur mobile).
-- Renvoie (modèle, labels = { coffre, revenu, pieces }).
function Conveyor.moneyBoard(folder: Instance, cf: CFrame)
	local model = Build.model(folder, "CompteurArgent")
	for _, side in { -1, 1 } do
		Build.part(model, "Pied", Vector3.new(0.9, 9, 0.9), cf * CFrame.new(side * 6.4, 4.5, 0.4), C.WoodDark, { Material = Enum.Material.Wood })
	end
	local board = Build.part(model, "Panneau", Vector3.new(13.6, 7, 0.5), cf * CFrame.new(0, 6.8, 0), rgb(24, 20, 34), { Material = Enum.Material.Metal })
	Build.part(model, "Cadre", Vector3.new(14.4, 0.5, 0.9), cf * CFrame.new(0, 10.4, 0), C.Gold, { Material = Enum.Material.Metal })
	Build.part(model, "Cadre", Vector3.new(14.4, 0.5, 0.9), cf * CFrame.new(0, 3.2, 0), C.Gold, { Material = Enum.Material.Metal })
	Kit.roof(model, cf * CFrame.new(0, 10.6, 0), 16, 3, 1.4, C.RoofTile, { curve = true, name = "Auvent" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.Parent = gui
	Kit.gradient(bg, { rgb(46, 34, 72), rgb(16, 12, 26) })
	local title = Kit.text(gui, "Titre", "💰 TRÉSOR DE LA BASE", UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.2), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
	Kit.gradient(title, { rgb(255, 240, 150), rgb(255, 170, 40) })
	local coffre = Kit.text(gui, "Coffre", "¥ 0", UDim2.fromScale(0.04, 0.25), UDim2.fromScale(0.92, 0.34), rgb(255, 225, 80), Enum.Font.LuckiestGuy)
	local revenu = Kit.text(gui, "Revenu", "+0 / s", UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.92, 0.17), rgb(120, 255, 130), Enum.Font.GothamBlack)
	local pieces = Kit.text(gui, "Pieces", "Tes pièces : ¥ 0", UDim2.fromScale(0.04, 0.8), UDim2.fromScale(0.92, 0.15), rgb(220, 220, 255), Enum.Font.GothamBold)
	return model, { coffre = coffre, revenu = revenu, pieces = pieces }
end

------------------------------------------------------------------------
-- Animation des pièces
------------------------------------------------------------------------

local function makeCoin(parent: Instance, kind: string, position: Vector3): BasePart
	if kind == "gem" then
		return Kit.blob(parent, "Gemme", Vector3.new(0.9, 1.3, 0.9), CFrame.new(position), rgb(120, 230, 255), {
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
	end
	local coin = Kit.coin(parent, CFrame.new(position), kind == "gold" and 1.9 or 1.4)
	if kind == "gold" then
		coin.Color = rgb(255, 225, 90)
		coin.Material = Enum.Material.Neon
	end
	return coin
end

-- Fait apparaître une pièce et la fait voyager le long du chemin. Renvoie la durée du trajet.
function Conveyor.spawn(parent: Instance, path): number
	local points = path.points
	local coin = makeCoin(parent, path.kind, points[1])
	local elapsed = 0
	for i = 2, #points do
		local from, to = points[i - 1], points[i]
		local duration
		local style = Enum.EasingStyle.Linear
		if i == 2 then
			duration = 0.35 -- chute depuis la buse
			style = Enum.EasingStyle.Quad
		elseif i == #points then
			duration = 0.3 -- saut dans le coffre
			style = Enum.EasingStyle.Quad
		else
			duration = (to - from).Magnitude / BELT_SPEED
		end
		local target = CFrame.new(to) * CFrame.Angles(0, elapsed * 2, 0)
		task.delay(elapsed, function()
			pcall(function()
				TweenService:Create(coin, TweenInfo.new(duration, style, Enum.EasingDirection.In), { CFrame = target }):Play()
			end)
		end)
		elapsed += duration
	end
	task.delay(elapsed + 0.05, function()
		pcall(function()
			coin:Destroy()
		end)
	end)
	return elapsed
end

-- À appeler régulièrement : lâche une pièce par distributeur quand son intervalle est écoulé.
function Conveyor.step(parent: Instance, paths, now: number)
	for _, path in paths do
		if not path.nextDrop or now >= path.nextDrop then
			path.nextDrop = now + path.interval
			Conveyor.spawn(parent, path)
		end
	end
end

return Conveyor
