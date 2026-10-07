-- LE MARCHAND AMBULANT : sa roulotte-échoppe, son étal, ses lanternes, ses caisses, et un grand
-- RAYON de lumière violette qui monte jusqu'au ciel pour qu'on le repère de toute la carte
-- (simple signe distinctif : il n'attaque personne).
--
-- Le modèle est construit une fois (Workspace › World › Merchant) ; ShopService le déplace d'un
-- coin à l'autre (Layout.MerchantSpots) et remplit ses étagères avec le stock du moment.
-- Repère local : origine au sol, -Z = l'avant de l'échoppe (tourné vers le hub).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local EvolutionItems = require(Shared.Config.EvolutionItems)
local CharacterBuilder = require(Shared.Modules.CharacterBuilder)
local Build = require(script.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Kit.Core)
local Props = require(script.Parent.Kit.Props)
local Archi = require(script.Parent.Kit.Archi)

local Merchant = {}

local rgb = Color3.fromRGB
local shade = Core.shade

local WOOD = rgb(150, 104, 66)
local WOOD_DARK = rgb(82, 56, 40)
local WOOD_OLD = rgb(120, 86, 58)
local STONE = rgb(150, 144, 136)
local PAINT = rgb(96, 40, 104) -- roulotte peinte (prune)
local PAINT_TRIM = rgb(222, 176, 74) -- dorures
local CANVAS = rgb(236, 224, 196)
local CLOTH = rgb(150, 50, 140)
local GOLD = rgb(240, 196, 80)

Merchant.Color = EvolutionItems.Merchant.Color
Merchant.DeckTop = 1.1
Merchant.BeamHeight = 900
local DISPLAY_SCALE = 0.75 -- taille des objets exposés sur les étagères

local SIGN_FONT = Font.new("rbxasset://fonts/families/Fondamento.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

-- Vendeur : voyageur au turban, longue robe prune, écharpe dorée.
Merchant.NpcLook = {
	skin = rgb(214, 162, 122),
	hair = "short",
	hairColor = rgb(196, 196, 204),
	eyes = rgb(70, 46, 30),
	face = "happy",
	outfit = "robe",
	top = rgb(104, 48, 120),
	topAccent = PAINT_TRIM,
	bottom = rgb(60, 36, 64),
	shoes = rgb(70, 46, 34),
	accessories = { "turban", "scarf_long", "sash" },
	accColor = PAINT_TRIM,
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return Build.part(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic, CanCollide = collide ~= false })
end

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return Build.deco(parent, name, size, cf, color, { Material = material or Enum.Material.SmoothPlastic })
end

local function cyl(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = deco(parent, name, size, cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Position (au sol) d'un coin du marchand. `groundY` : hauteur du sol (WorldBuilder.groundY).
function Merchant.spotCFrame(index: number, groundY: ((Vector3) -> number)?): CFrame
	local spots = Layout.MerchantSpots
	local spot = spots[math.clamp(index, 1, #spots)]
	local y = 0
	if groundY then
		-- Le plancher repose sur le point le plus haut sous l'échoppe (pas de pieds enterrés).
		for _, offset in { Vector3.zero, Vector3.new(11, 0, 9), Vector3.new(-11, 0, 9), Vector3.new(11, 0, -9), Vector3.new(-11, 0, -9) } do
			local ok, h = pcall(groundY, spot + offset)
			if ok and type(h) == "number" then
				y = math.max(y, h)
			end
		end
	end
	local base = Vector3.new(spot.X, y, spot.Z)
	return CFrame.lookAt(base, Vector3.new(0, y, 0))
end

------------------------------------------------------------------------
-- Roulotte
------------------------------------------------------------------------

local function buildWagon(model: Model, cf: CFrame)
	local wagon = Build.model(model, "Roulotte")
	local deck = Merchant.DeckTop
	local wheelD = 4.8
	local axleY = deck + wheelD / 2
	local bodyBottom = axleY + 0.4
	local bodyH = 6.4
	local bodyTop = bodyBottom + bodyH
	local L, D = 15, 7.6
	local center = cf * CFrame.new(0, 0, 6.4)
	-- Châssis, caisse peinte et dorures.
	part(wagon, "Chassis", Vector3.new(L + 0.6, 0.6, D - 1), center * CFrame.new(0, bodyBottom - 0.3, 0), WOOD_DARK, Enum.Material.Wood)
	part(wagon, "Body", Vector3.new(L, bodyH, D), center * CFrame.new(0, bodyBottom + bodyH / 2, 0), PAINT, Enum.Material.WoodPlanks)
	for _, y in { bodyBottom + 0.25, bodyTop - 0.25 } do
		deco(wagon, "Trim", Vector3.new(L + 0.2, 0.32, D + 0.2), center * CFrame.new(0, y, 0), PAINT_TRIM, Enum.Material.Wood)
	end
	for _, x in { -1, 1 } do
		deco(wagon, "CornerPost", Vector3.new(0.5, bodyH, 0.5), center * CFrame.new(x * (L / 2), bodyBottom + bodyH / 2, -D / 2), PAINT_TRIM, Enum.Material.Wood)
		deco(wagon, "CornerPost", Vector3.new(0.5, bodyH, 0.5), center * CFrame.new(x * (L / 2), bodyBottom + bodyH / 2, D / 2), PAINT_TRIM, Enum.Material.Wood)
	end
	-- Panneaux décoratifs sur les flancs (cadres dorés, rosaces) et petites fenêtres à volets.
	for _, x in { -1, 1 } do
		local side = center * CFrame.new(x * (L / 2 + 0.05), bodyBottom + bodyH / 2, 0) * CFrame.Angles(0, x * math.rad(90), 0)
		deco(wagon, "Window", Vector3.new(2.6, 2.2, 0.1), side * CFrame.new(0, 0.6, -0.05), rgb(255, 214, 140), Enum.Material.Neon).Transparency = 0.2
		deco(wagon, "WindowFrame", Vector3.new(3.0, 0.25, 0.2), side * CFrame.new(0, 1.8, -0.1), PAINT_TRIM, Enum.Material.Wood)
		deco(wagon, "WindowFrame", Vector3.new(3.0, 0.25, 0.2), side * CFrame.new(0, -0.6, -0.1), PAINT_TRIM, Enum.Material.Wood)
		deco(wagon, "WindowBar", Vector3.new(0.18, 2.4, 0.2), side * CFrame.new(0, 0.6, -0.1), PAINT_TRIM, Enum.Material.Wood)
		for _, s in { -1, 1 } do
			deco(wagon, "Shutter", Vector3.new(1.2, 2.4, 0.15), side * CFrame.new(s * 2.1, 0.6, -0.12), rgb(60, 110, 90), Enum.Material.WoodPlanks)
			deco(wagon, "Rosette", Vector3.new(0.12, 0.9, 0.9), side * CFrame.new(s * 4.6, 0.2, -0.08) * CFrame.Angles(0, math.rad(90), 0), PAINT_TRIM, Enum.Material.Wood).Shape =
				Enum.PartType.Cylinder
		end
		deco(wagon, "Flowerbox", Vector3.new(3.2, 0.6, 0.7), side * CFrame.new(0, -1.0, -0.4), WOOD_OLD, Enum.Material.Wood)
		for k = -1, 1 do
			Core.ball(wagon, "Flower", 0.5, (side * CFrame.new(k * 0.9, -0.55, -0.45)).Position, k == 0 and rgb(250, 220, 90) or rgb(240, 90, 120))
		end
	end
	-- Toit bâché arrondi (cylindre à moitié dans la caisse) avec arceaux et rayures.
	local roofCF = center * CFrame.new(0, bodyTop, 0)
	cyl(wagon, "Canvas", Vector3.new(L + 0.8, D + 0.6, D + 0.6), roofCF, CANVAS, Enum.Material.Fabric)
	for i = 0, 4 do
		local x = -L / 2 + 0.4 + i * (L - 0.8) / 4
		cyl(wagon, "Hoop", Vector3.new(0.35, D + 0.9, D + 0.9), roofCF * CFrame.new(x, 0, 0), WOOD_DARK, Enum.Material.Wood)
	end
	for _, x in { -3.6, 0, 3.6 } do
		cyl(wagon, "Stripe", Vector3.new(1.4, D + 0.7, D + 0.7), roofCF * CFrame.new(x, 0, 0), CLOTH, Enum.Material.Fabric)
	end
	-- Tuyau de poêle qui fume.
	local pipeBase = center * CFrame.new(L / 2 - 2.5, bodyTop + 2.6, 1.2)
	Core.vcyl(wagon, "StovePipe", pipeBase, 3.4, 0.8, rgb(60, 60, 66), Enum.Material.Metal, false)
	local capPart = deco(wagon, "StoveCap", Vector3.new(1.4, 0.3, 1.4), pipeBase * CFrame.new(0, 3.55, 0), rgb(50, 50, 56), Enum.Material.Metal)
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(220, 220, 225)
	smoke.Opacity = 0.08
	smoke.RiseVelocity = 3
	smoke.Size = 1.5
	smoke.Parent = capPart
	-- Roues à rayons.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local wheelCF = center * CFrame.new(x * (L / 2 - 2.6), axleY, z * (D / 2 + 0.35)) * CFrame.Angles(0, math.rad(90), 0)
			cyl(wagon, "Wheel", Vector3.new(0.45, wheelD, wheelD), wheelCF, WOOD_DARK, Enum.Material.Wood).CanCollide = true
			cyl(wagon, "Tyre", Vector3.new(0.5, wheelD + 0.15, wheelD + 0.15), wheelCF, rgb(56, 56, 60), Enum.Material.Metal).Transparency = 0
			cyl(wagon, "WheelInner", Vector3.new(0.55, wheelD - 0.8, wheelD - 0.8), wheelCF, PAINT_TRIM, Enum.Material.Wood)
			for k = 0, 3 do
				deco(wagon, "Spoke", Vector3.new(0.65, wheelD - 1, 0.25), wheelCF * CFrame.Angles(k * math.pi / 4, 0, 0), WOOD_DARK, Enum.Material.Wood)
			end
			cyl(wagon, "Hub", Vector3.new(0.8, 1.0, 1.0), wheelCF, rgb(70, 70, 76), Enum.Material.Metal)
		end
	end
	-- Façade avant : grande ouverture d'échoppe, volet relevé en auvent, étagères.
	local front = center * CFrame.new(0, 0, -D / 2 - 0.05)
	deco(wagon, "ShopBack", Vector3.new(L - 1.6, bodyH - 1.2, 0.1), front * CFrame.new(0, bodyBottom + bodyH / 2 + 0.2, 0.02), rgb(52, 30, 40), Enum.Material.Wood)
	deco(wagon, "ShopFrame", Vector3.new(L - 1.2, 0.4, 0.3), front * CFrame.new(0, bodyTop - 0.4, -0.1), PAINT_TRIM, Enum.Material.Wood)
	for _, x in { -1, 1 } do
		deco(wagon, "ShopJamb", Vector3.new(0.4, bodyH - 0.8, 0.3), front * CFrame.new(x * (L / 2 - 0.8), bodyBottom + bodyH / 2, -0.1), PAINT_TRIM, Enum.Material.Wood)
	end
	local shelves = {}
	for row, y in { bodyBottom + 2.5, bodyBottom + 4.6 } do
		local shelf = part(wagon, "Shelf", Vector3.new(L - 2.2, 0.25, 1.3), front * CFrame.new(0, y, -0.55), WOOD, Enum.Material.Wood, false)
		deco(wagon, "ShelfLip", Vector3.new(L - 2.2, 0.35, 0.1), front * CFrame.new(0, y + 0.2, -1.2), PAINT_TRIM, Enum.Material.Wood)
		shelves[row] = shelf
	end
	-- Volet relevé (auvent de bois) au-dessus de l'ouverture.
	local flap = front * CFrame.new(0, bodyTop + 0.2, -1.4) * CFrame.Angles(math.rad(-28), 0, 0)
	part(wagon, "Flap", Vector3.new(L - 0.6, 0.3, 3.2), flap, PAINT, Enum.Material.WoodPlanks, false)
	deco(wagon, "FlapTrim", Vector3.new(L - 0.4, 0.35, 0.3), flap * CFrame.new(0, 0, -1.6), PAINT_TRIM, Enum.Material.Wood)
	-- Brancards à l'arrière (rangés).
	for _, x in { -1, 1 } do
		Core.beam(
			wagon,
			"Shaft",
			(center * CFrame.new(x * 2, bodyBottom - 0.2, D / 2)).Position,
			(center * CFrame.new(x * 2.2, deck + 0.3, D / 2 + 6)).Position,
			0.35,
			0.35,
			WOOD_DARK,
			{ Material = Enum.Material.Wood, CanCollide = false }
		)
	end
	-- Casseroles et lanternes accrochées aux coins.
	for _, x in { -1, 1 } do
		local corner = center * CFrame.new(x * (L / 2 + 0.3), bodyTop - 0.6, -D / 2)
		Props.hangingLantern(wagon, corner.Position, (corner.RightVector * x) * 1.4, rgb(255, 180, 90), 0.8)
	end
	for i, x in { -5.2, -4.2 } do
		cyl(
			wagon,
			"Pan",
			Vector3.new(0.2, 1.1 - i * 0.15, 1.1 - i * 0.15),
			center * CFrame.new(x, bodyBottom + 1.4, D / 2 + 0.15) * CFrame.Angles(0, math.rad(90), 0),
			rgb(150, 100, 70),
			Enum.Material.Metal
		)
	end
	return wagon, shelves
end

------------------------------------------------------------------------
-- Étal, auvent, enseigne
------------------------------------------------------------------------

local function buildFront(model: Model, cf: CFrame): BasePart
	local deck = Merchant.DeckTop
	local stall = Build.model(model, "Etal")
	-- Comptoir en bois massif avec jupe de tissu brodée.
	local counterCF = cf * CFrame.new(0, deck, -2.6)
	local counter = part(stall, "Counter", Vector3.new(13, 3.2, 2.4), counterCF * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.WoodPlanks)
	part(stall, "CounterTop", Vector3.new(13.8, 0.4, 3.0), counterCF * CFrame.new(0, 3.4, 0), rgb(176, 124, 80), Enum.Material.Wood)
	deco(stall, "Skirt", Vector3.new(12.6, 2.2, 0.12), counterCF * CFrame.new(0, 1.85, -1.27), CLOTH, Enum.Material.Fabric)
	deco(stall, "SkirtHem", Vector3.new(12.6, 0.3, 0.14), counterCF * CFrame.new(0, 0.85, -1.28), GOLD, Enum.Material.Fabric)
	for k = -2, 2 do
		deco(stall, "SkirtMotif", Vector3.new(0.5, 0.5, 0.14), counterCF * CFrame.new(k * 2.4, 2.0, -1.29) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Fabric)
	end
	for _, x in { -1, 1 } do
		deco(stall, "CounterPost", Vector3.new(0.5, 3.2, 0.5), counterCF * CFrame.new(x * 6.3, 1.6, -1.25), WOOD_DARK, Enum.Material.Wood)
	end
	-- Sur le comptoir : balance, pile de pièces, registre, petite lanterne.
	local top = counterCF * CFrame.new(0, 3.6, 0)
	deco(stall, "ScaleBase", Vector3.new(0.9, 0.2, 0.9), top * CFrame.new(-4.6, 0.1, 0), rgb(160, 120, 60), Enum.Material.Metal)
	deco(stall, "ScalePost", Vector3.new(0.15, 1.6, 0.15), top * CFrame.new(-4.6, 0.9, 0), rgb(200, 160, 70), Enum.Material.Metal)
	deco(stall, "ScaleBeam", Vector3.new(2.2, 0.12, 0.12), top * CFrame.new(-4.6, 1.7, 0), rgb(200, 160, 70), Enum.Material.Metal)
	for _, x in { -1, 1 } do
		cyl(stall, "ScalePan", Vector3.new(0.08, 0.9, 0.9), top * CFrame.new(-4.6 + x * 1.05, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(210, 170, 80), Enum.Material.Metal)
		deco(stall, "ScaleCord", Vector3.new(0.04, 0.55, 0.04), top * CFrame.new(-4.6 + x * 1.05, 1.42, 0), rgb(60, 50, 40))
	end
	for i = 0, 5 do
		cyl(
			stall,
			"Coin",
			Vector3.new(0.12, 0.6, 0.6),
			top * CFrame.new(-2.6 + (i % 2) * 0.15, 0.06 + i * 0.13, 0.2) * CFrame.Angles(0, 0, math.rad(90)),
			GOLD,
			Enum.Material.Metal
		)
	end
	for i = 0, 3 do
		cyl(stall, "Coin", Vector3.new(0.12, 0.6, 0.6), top * CFrame.new(-1.9, 0.06 + i * 0.13, -0.3) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal)
	end
	deco(stall, "Ledger", Vector3.new(1.6, 0.25, 1.1), top * CFrame.new(4.4, 0.12, 0.1) * CFrame.Angles(0, 0.3, 0), rgb(120, 40, 40), Enum.Material.Fabric)
	deco(stall, "LedgerPages", Vector3.new(1.5, 0.2, 1.0), top * CFrame.new(4.42, 0.26, 0.1) * CFrame.Angles(0, 0.3, 0), rgb(240, 230, 205))
	deco(stall, "Quill", Vector3.new(0.08, 0.08, 1.2), top * CFrame.new(4.9, 0.42, 0.0) * CFrame.Angles(0.4, 0.8, 0), rgb(245, 245, 245))
	Props.paperLantern(stall, (top * CFrame.new(5.8, 0.8, 0.6)).Position, rgb(255, 190, 110), 0.55)

	-- Tapis devant l'étal.
	deco(stall, "Rug", Vector3.new(10, 0.08, 5), cf * CFrame.new(0, deck + 0.04, -6.6), rgb(150, 40, 50), Enum.Material.Fabric)
	deco(stall, "RugBorder", Vector3.new(10.6, 0.06, 5.6), cf * CFrame.new(0, deck + 0.02, -6.6), GOLD, Enum.Material.Fabric)
	deco(stall, "RugMotif", Vector3.new(2.2, 0.1, 2.2), cf * CFrame.new(0, deck + 0.06, -6.6) * CFrame.Angles(0, math.rad(45), 0), rgb(40, 60, 110), Enum.Material.Fabric)

	-- Auvent rayé : de la roulotte jusqu'à la poutre avant (poteaux à x = ±7,6, z = -7).
	local frontZ, frontY = -7.2, deck + 9.2
	local backZ, backY = 2.4, deck + 12.6
	for _, x in { -1, 1 } do
		part(stall, "Pole", Vector3.new(0.7, frontY - deck + 0.4, 0.7), cf * CFrame.new(x * 7.6, deck + (frontY - deck) / 2, frontZ), WOOD_DARK, Enum.Material.Wood)
		deco(stall, "PoleFoot", Vector3.new(1.2, 0.5, 1.2), cf * CFrame.new(x * 7.6, deck + 0.25, frontZ), STONE, Enum.Material.Slate)
		deco(stall, "PoleCap", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(x * 7.6, frontY + 0.6, frontZ), GOLD, Enum.Material.Metal).Shape = Enum.PartType.Ball
	end
	deco(stall, "FrontBeam", Vector3.new(16, 0.6, 0.6), cf * CFrame.new(0, frontY, frontZ), WOOD_DARK, Enum.Material.Wood)
	local a = Vector3.new(0, frontY + 0.35, frontZ)
	local b = Vector3.new(0, backY, backZ)
	local length = (b - a).Magnitude
	local pitch = math.atan2(backY - frontY, backZ - frontZ)
	local strips = 8
	for i = 0, strips - 1 do
		local x = -8 + (i + 0.5) * 16 / strips
		local color = i % 2 == 0 and CLOTH or CANVAS
		local mid = cf * CFrame.new(x, (a.Y + b.Y) / 2, (a.Z + b.Z) / 2) * CFrame.Angles(-pitch, 0, 0)
		deco(stall, "Awning", Vector3.new(16 / strips, 0.2, length), mid, color, Enum.Material.Fabric)
		-- Festons qui pendent à l'avant.
		local flapCF = cf * CFrame.new(x, frontY - 0.35, frontZ - 0.45)
		deco(stall, "Scallop", Vector3.new(16 / strips - 0.1, 0.9, 0.1), flapCF, color, Enum.Material.Fabric)
		deco(stall, "ScallopTip", Vector3.new(0.7, 0.7, 0.1), flapCF * CFrame.new(0, -0.45, 0) * CFrame.Angles(0, 0, math.rad(45)), color, Enum.Material.Fabric)
	end
	-- Guirlandes de lanternes le long des côtés de l'auvent (l'enseigne reste bien visible devant).
	for _, x in { -1, 1 } do
		Archi.lanternString(stall, (cf * CFrame.new(x * 8.1, frontY - 0.2, frontZ)).Position, (cf * CFrame.new(x * 8.1, backY - 1.2, backZ - 0.4)).Position, 3, {
			rgb(255, 120, 90),
			rgb(255, 210, 110),
			rgb(214, 110, 255),
		}, 0.9)
	end
	for _, x in { -1, 1 } do
		Props.hangingLantern(stall, (cf * CFrame.new(x * 7.6, frontY - 1.6, frontZ)).Position, cf:VectorToWorldSpace(Vector3.new(x * 1.6, 0, 0)), rgb(255, 170, 80), 0.9)
	end

	-- Enseigne de bois sculptée « MARCHAND », suspendue par deux chaînes sous la poutre.
	local signCF = cf * CFrame.new(0, frontY - 1.75, frontZ - 0.35)
	for _, x in { -3.2, 3.2 } do
		for k = 0, 1 do
			deco(
				stall,
				"Chain",
				Vector3.new(0.12, 0.34, 0.24),
				signCF * CFrame.new(x, 1.25 + k * 0.3, 0) * CFrame.Angles(0, k % 2 == 0 and 0 or math.rad(90), 0),
				rgb(70, 70, 74),
				Enum.Material.Metal
			)
		end
	end
	deco(stall, "SignFrame", Vector3.new(9.4, 2.4, 0.35), signCF, WOOD_DARK, Enum.Material.Wood)
	local plank = deco(stall, "Sign", Vector3.new(8.8, 1.9, 0.45), signCF, rgb(118, 82, 52), Enum.Material.WoodPlanks)
	for _, x in { -4.1, 4.1 } do
		deco(stall, "SignCorner", Vector3.new(0.5, 0.5, 0.5), signCF * CFrame.new(x, 0.85, -0.05) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
		deco(stall, "SignCorner", Vector3.new(0.5, 0.5, 0.5), signCF * CFrame.new(x, -0.85, -0.05) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	end
	-- Petits motifs peints : une bourse dorée à gauche, un parchemin à droite.
	cyl(stall, "MotifCoin", Vector3.new(0.12, 0.9, 0.9), signCF * CFrame.new(-3.55, 0, -0.26) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal)
	cyl(stall, "MotifCoinInner", Vector3.new(0.14, 0.5, 0.5), signCF * CFrame.new(-3.55, 0, -0.27) * CFrame.Angles(0, math.rad(90), 0), shade(GOLD, -0.25), Enum.Material.Metal)
	cyl(stall, "MotifScroll", Vector3.new(0.9, 0.36, 0.36), signCF * CFrame.new(3.55, 0, -0.27), rgb(240, 226, 190))
	for _, x in { 3.1, 4.0 } do
		cyl(stall, "MotifScrollEnd", Vector3.new(0.14, 0.48, 0.48), signCF * CFrame.new(x, 0, -0.27), rgb(160, 40, 60))
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = Build.surfaceText(plank, face, "MARCHAND", rgb(250, 214, 120), {
			TextStrokeTransparency = 0.2,
			TextStrokeColor3 = rgb(50, 26, 14),
		})
		label.FontFace = SIGN_FONT
		label.Size = UDim2.new(0.66, 0, 0.84, 0)
		label.Position = UDim2.new(0.17, 0, 0.08, 0)
	end
	local sub = deco(stall, "SubSign", Vector3.new(6.4, 0.9, 0.25), signCF * CFrame.new(0, -1.55, 0), rgb(236, 220, 186), Enum.Material.Wood)
	for _, x in { -2, 2 } do
		deco(stall, "SubChain", Vector3.new(0.1, 0.5, 0.1), signCF * CFrame.new(x, -1.2, 0), rgb(70, 70, 74), Enum.Material.Metal)
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = Build.surfaceText(sub, face, "Objets d'évolution", rgb(90, 40, 30), { TextStrokeTransparency = 1 })
		label.FontFace = SIGN_FONT
	end
	return counter
end

------------------------------------------------------------------------
-- Rayon lumineux jusqu'au ciel (balise derrière la roulotte)
------------------------------------------------------------------------

local function buildBeacon(model: Model, cf: CFrame): BasePart
	local beacon = Build.model(model, "Balise")
	local color = Merchant.Color
	local base = cf * CFrame.new(0, 0, 14.5)
	-- Socle de pierre gravée et cercle lumineux au sol.
	Core.vcyl(beacon, "BeaconBase", base, 1.2, 6.4, STONE, Enum.Material.Slate)
	Core.vcyl(beacon, "BeaconStep", base * CFrame.new(0, 1.2, 0), 0.8, 4.6, shade(STONE, -0.1), Enum.Material.Slate)
	local ring = cyl(beacon, "GlowRing", Vector3.new(0.12, 9, 9), base * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon)
	ring.Transparency = 0.55
	-- Mât de bois sculpté, cerclé de métal doré.
	Core.vcyl(beacon, "Mast", base * CFrame.new(0, 2, 0), 12, 1.3, WOOD_DARK, Enum.Material.Wood, true)
	for _, y in { 3.2, 7.0, 11.4 } do
		Core.vcyl(beacon, "MastRing", base * CFrame.new(0, y, 0), 0.4, 1.6, GOLD, Enum.Material.Metal, false)
	end
	-- Griffes qui tiennent le cristal.
	for i = 0, 3 do
		local a = i * math.pi / 2
		Core.beam(
			beacon,
			"Claw",
			(base * CFrame.new(math.cos(a) * 0.5, 13.6, math.sin(a) * 0.5)).Position,
			(base * CFrame.new(math.cos(a) * 1.5, 16.2, math.sin(a) * 1.5)).Position,
			0.3,
			0.3,
			GOLD,
			{ Material = Enum.Material.Metal, CanCollide = false }
		)
	end
	local crystalCF = base * CFrame.new(0, 16.4, 0)
	local crystal = deco(beacon, "Crystal", Vector3.new(2.2, 3.6, 2.2), crystalCF * CFrame.Angles(0, math.rad(45), 0), color, Enum.Material.Glass)
	crystal.Transparency = 0.15
	crystal.Reflectance = 0.2
	local core = deco(beacon, "CrystalCore", Vector3.new(1.3, 2.6, 1.3), crystalCF * CFrame.Angles(0, math.rad(45), 0), Color3.new(1, 1, 1):Lerp(color, 0.4), Enum.Material.Neon)
	core.CastShadow = false
	Core.light(core, color, 40, 3)
	-- Le rayon : cœur blanc, colonne colorée, halo large et transparent.
	local height = Merchant.BeamHeight
	local beamCF = crystalCF * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	local layers = {
		{ "LightCore", 1.6, Color3.new(1, 1, 1):Lerp(color, 0.2), 0.05 },
		{ "LightColumn", 4.4, color, 0.3 },
		{ "LightHalo", 12, color, 0.84 },
	}
	for _, layer in layers do
		local p = cyl(beacon, layer[1], Vector3.new(height, layer[2], layer[2]), beamCF, layer[3], Enum.Material.Neon)
		p.Transparency = layer[4]
		p.CastShadow = false
	end
	-- Étincelles qui montent le long du rayon (Beam texturé qui défile + particules).
	local bottom = Instance.new("Attachment")
	bottom.Name = "BeamBottom"
	bottom.Parent = core
	local topPart = deco(beacon, "BeamTop", Vector3.new(1, 1, 1), crystalCF * CFrame.new(0, height, 0), color)
	topPart.Transparency = 1
	local topAttachment = Instance.new("Attachment")
	topAttachment.Name = "BeamTop"
	topAttachment.Parent = topPart
	local sparkBeam = Instance.new("Beam")
	sparkBeam.Name = "SparkBeam"
	sparkBeam.Attachment0 = bottom
	sparkBeam.Attachment1 = topAttachment
	sparkBeam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparkBeam.LightEmission = 1
	sparkBeam.LightInfluence = 0
	sparkBeam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkBeam.TextureMode = Enum.TextureMode.Static
	sparkBeam.TextureLength = 14
	sparkBeam.TextureSpeed = -0.6
	sparkBeam.Width0 = 8
	sparkBeam.Width1 = 10
	sparkBeam.FaceCamera = true
	sparkBeam.Transparency = NumberSequence.new(0.15)
	sparkBeam.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparks.LightEmission = 1
	sparks.Rate = 10
	sparks.Lifetime = NumberRange.new(3, 5)
	sparks.Speed = NumberRange.new(14, 26)
	sparks.SpreadAngle = Vector2.new(8, 8)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparks.Parent = core
	-- Étiquette visible de loin.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MerchantLabel"
	billboard.Size = UDim2.fromOffset(250, 78)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 4000
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.Adornee = core
	billboard.Parent = core
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = rgb(52, 30, 24)
	plate.BackgroundTransparency = 0.12
	plate.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Color = EvolutionItems.Merchant.Color2
	stroke.Thickness = 3
	stroke.Parent = plate
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(140, 100, 70), rgb(60, 36, 26))
	gradient.Rotation = 90
	gradient.Parent = plate
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0.58, 0)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.FontFace = SIGN_FONT
	title.Text = "MARCHAND"
	title.TextScaled = true
	title.TextColor3 = rgb(255, 222, 130)
	title.TextStrokeTransparency = 0.3
	title.TextStrokeColor3 = rgb(40, 20, 10)
	title.Parent = plate
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -16, 0.34, 0)
	status.Position = UDim2.new(0, 8, 0.6, 0)
	status.Font = Enum.Font.GothamBold
	status.Text = "Objets d'évolution"
	status.TextScaled = true
	status.TextColor3 = rgb(244, 230, 210)
	status.TextStrokeTransparency = 0.5
	status.Parent = plate
	return core
end

------------------------------------------------------------------------
-- Plancher, accessoires, vendeur
------------------------------------------------------------------------

local function buildDeck(model: Model, cf: CFrame)
	local deck = Merchant.DeckTop
	local floor = Build.model(model, "Plancher")
	-- Fondation de pierre (descend sous le sol pour les terrains en pente) et plancher.
	part(floor, "Foundation", Vector3.new(27, 5, 21), cf * CFrame.new(0, deck - 2.9, 1.2), STONE, Enum.Material.Cobblestone)
	part(floor, "Deck", Vector3.new(26, 0.4, 20), cf * CFrame.new(0, deck - 0.2, 1.2), WOOD, Enum.Material.WoodPlanks)
	for _, z in { -8.8, 11.2 } do
		deco(floor, "DeckEdge", Vector3.new(26.4, 0.5, 0.5), cf * CFrame.new(0, deck - 0.15, z), WOOD_DARK, Enum.Material.Wood)
	end
	for _, x in { -13, 13 } do
		deco(floor, "DeckEdge", Vector3.new(0.5, 0.5, 20.4), cf * CFrame.new(x, deck - 0.15, 1.2), WOOD_DARK, Enum.Material.Wood)
	end
	-- Marches à l'avant.
	part(floor, "Step", Vector3.new(14, 0.55, 1.8), cf * CFrame.new(0, deck - 0.55, -9.7), STONE, Enum.Material.Slate)
	part(floor, "Step2", Vector3.new(14, 0.55, 1.8), cf * CFrame.new(0, deck - 1.1, -11.2), shade(STONE, -0.08), Enum.Material.Slate)
end

local function buildProps(model: Model, cf: CFrame)
	local deck = Merchant.DeckTop
	local props = Build.model(model, "Accessoires")
	local rng = Random.new(2024)
	local floorCF = cf * CFrame.new(0, deck, 0)
	-- Caisses et tonneaux de marchandises sur les côtés.
	Props.crate(props, floorCF * CFrame.new(-10.6, 0, -5.4) * CFrame.Angles(0, 0.2, 0), 2.6, rgb(170, 124, 80))
	Props.crate(props, floorCF * CFrame.new(-10.4, 2.6, -5.2) * CFrame.Angles(0, -0.25, 0), 2, rgb(150, 110, 72))
	Props.barrel(props, floorCF * CFrame.new(-11, 0, -1.5), 0.85)
	Props.sack(props, floorCF * CFrame.new(-9.2, 0, -7.4), rng)
	Props.barrel(props, floorCF * CFrame.new(10.8, 0, -5.4), 0.9)
	Props.crate(props, floorCF * CFrame.new(10.6, 0, -1.8) * CFrame.Angles(0, -0.3, 0), 2.4, rgb(176, 130, 82))
	Props.sack(props, floorCF * CFrame.new(9.0, 0, -7.6), rng)
	-- Coffre au trésor entrouvert, plein de pièces.
	local chestCF = floorCF * CFrame.new(-8.2, 0, -7.2) * CFrame.Angles(0, 0.35, 0)
	part(props, "Chest", Vector3.new(2.6, 1.4, 1.7), chestCF * CFrame.new(0, 0.7, 0), rgb(120, 70, 40), Enum.Material.Wood)
	deco(props, "ChestGold", Vector3.new(2.3, 0.4, 1.4), chestCF * CFrame.new(0, 1.45, 0), GOLD, Enum.Material.Metal)
	deco(props, "ChestLid", Vector3.new(2.6, 0.3, 1.7), chestCF * CFrame.new(0, 2.0, 1.0) * CFrame.Angles(math.rad(-70), 0, 0), rgb(110, 64, 36), Enum.Material.Wood)
	for _, x in { -1, 1 } do
		deco(props, "ChestBand", Vector3.new(0.25, 1.45, 1.75), chestCF * CFrame.new(x * 0.9, 0.7, 0), GOLD, Enum.Material.Metal)
	end
	-- Grand sac à dos de voyage et couverture roulée, posés contre la roue.
	local packCF = floorCF * CFrame.new(8.6, 0, 1.6) * CFrame.Angles(0, -0.4, 0)
	Core.ellipsoid(props, "Backpack", Vector3.new(2.4, 3.2, 1.8), packCF * CFrame.new(0, 1.6, 0), rgb(130, 90, 60), Enum.Material.Fabric)
	cyl(props, "Bedroll", Vector3.new(2.6, 1.0, 1.0), packCF * CFrame.new(0, 3.3, 0), rgb(60, 100, 140), Enum.Material.Fabric)
	deco(props, "PackStrap", Vector3.new(0.3, 3.0, 1.9), packCF * CFrame.new(0.5, 1.6, 0), rgb(80, 50, 30), Enum.Material.Fabric)
	-- Plantes en pot de part et d'autre des marches.
	Props.pottedPlant(props, (floorCF * CFrame.new(-7.6, 0, -8.2)).Position, rng)
	Props.pottedPlant(props, (floorCF * CFrame.new(7.6, 0, -8.2)).Position, rng)
	-- Fanions sur les côtés.
	local yaw = math.atan2(cf.LookVector.X, cf.LookVector.Z)
	Props.banner(props, (floorCF * CFrame.new(-12.4, 0, -8.2)).Position, 10, CLOTH, nil, yaw)
	Props.banner(props, (floorCF * CFrame.new(12.4, 0, -8.2)).Position, 10, CLOTH, nil, yaw)
end

local function buildNpc(model: Model, cf: CFrame)
	local ok, npc = pcall(CharacterBuilder.build, Merchant.NpcLook, { name = "Marchand", anchored = true })
	if not ok or not npc then
		warn("[AnimeTycoon] Marchand : vendeur non construit (" .. tostring(npc) .. ")")
		return nil
	end
	npc:PivotTo(cf * CFrame.new(0, Merchant.DeckTop + CharacterBuilder.RootHeight, -0.4))
	npc:SetAttribute("NPC", true)
	npc:SetAttribute("DisplayName", "Marchand")
	npc.Parent = model
	CollectionService:AddTag(npc, "AnimeRig")
	return npc
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Construit le marchand (à son premier coin) dans `parent` (le dossier World).
function Merchant.build(parent: Instance, groundY: ((Vector3) -> number)?): Model
	local existing = parent:FindFirstChild("Merchant")
	if existing then
		existing:Destroy()
	end
	local cf = Merchant.spotCFrame(1, groundY)
	local model = Build.model(parent, "Merchant")
	buildDeck(model, cf)
	local _, shelves = buildWagon(model, cf)
	local counter = buildFront(model, cf)
	buildProps(model, cf)
	buildBeacon(model, cf)
	buildNpc(model, cf)
	for row, shelf in shelves do
		shelf.Name = "Shelf" .. row
	end
	Build.folder(model, "Display")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MerchantPrompt"
	prompt.ActionText = "Marchander"
	prompt.ObjectText = "Marchand ambulant"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = counter

	-- Repère invisible au sol : sert de pivot pour déplacer toute l'échoppe d'un coin à l'autre.
	local pivot = Build.deco(model, "Pivot", Vector3.new(1, 1, 1), cf, Color3.new(1, 1, 1), { Transparency = 1, CastShadow = false })
	model.PrimaryPart = pivot
	model.WorldPivot = cf
	model:SetAttribute("SpotIndex", 1)
	CollectionService:AddTag(model, "Merchant")
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	return model
end

-- Déplace le marchand vers un coin. Retourne le CFrame de ce coin.
function Merchant.place(model: Model, index: number, groundY: ((Vector3) -> number)?): CFrame
	local cf = Merchant.spotCFrame(index, groundY)
	model:PivotTo(cf)
	model:SetAttribute("SpotIndex", index)
	return cf
end

-- Remplit les étagères avec les objets en vente (modèles 3D réduits).
function Merchant.setDisplay(model: Model, itemIds: { string })
	local display = model:FindFirstChild("Display")
	if not display then
		display = Build.folder(model, "Display")
	end
	display:ClearAllChildren()
	local wagon = model:FindFirstChild("Roulotte")
	if not wagon then
		return
	end
	local rows = { wagon:FindFirstChild("Shelf1") :: BasePart?, wagon:FindFirstChild("Shelf2") :: BasePart? }
	local perRow = { math.ceil(#itemIds / 2), #itemIds - math.ceil(#itemIds / 2) }
	local index = 0
	for row, shelf in rows do
		if shelf then
			local count = perRow[row]
			for k = 1, count do
				index += 1
				local id = itemIds[index]
				if id then
					local item = EvolutionItems.build(id, DISPLAY_SCALE)
					local x = (k - (count + 1) / 2) * math.min(3, (shelf.Size.X - 1.5) / math.max(1, count))
					local cf = shelf.CFrame * CFrame.new(x, shelf.Size.Y / 2, 0)
					item:PivotTo(cf * CFrame.new(0, 1.2 * DISPLAY_SCALE, 0))
					item.Parent = display
				end
			end
		end
	end
end

-- Texte sous « MARCHAND » sur l'étiquette visible de loin.
function Merchant.setStatus(model: Model, text: string)
	local beacon = model:FindFirstChild("Balise")
	local core = beacon and beacon:FindFirstChild("CrystalCore")
	local label = core and core:FindFirstChild("MerchantLabel")
	local plate = label and label:FindFirstChild("Plate")
	local status = plate and plate:FindFirstChild("Status")
	if status and status:IsA("TextLabel") and status.Text ~= text then
		status.Text = text
	end
end

-- Position du comptoir (pour vérifier la distance d'achat).
function Merchant.counterPosition(model: Model): Vector3
	local stall = model:FindFirstChild("Etal")
	local counter = stall and stall:FindFirstChild("Counter")
	if counter and counter:IsA("BasePart") then
		return counter.CFrame.Position
	end
	return model:GetPivot().Position
end

return Merchant
