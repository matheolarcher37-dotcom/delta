-- Décor de l'univers GRAND OCÉAN (inspiré de One Piece), sur TOUTE la carte :
--   * dans l'anneau, la ville portuaire : maisons pastel à toits de tuiles, volets, balcons
--     fleuris, enseignes (taverne, armurerie, cartographe...), auvents rayés, tonneaux, filets ;
--     le navire-restaurant échoué, le chantier naval (navire en construction sur son ber,
--     échafaudages, grue), le lagon turquoise et ses palmiers, parasols et transats ;
--   * la grande arche au drapeau à tête de mort sur la route de la base 270° ;
--   * sur l'île : palmeraies, buissons d'hibiscus, cabanes de plage ; le port avec ses jetées
--     et deux navires amarrés ; le phare rayé sur son rocher ;
--   * en mer : le gigantesque navire-baleine, des îles tropicales à l'horizon. Embruns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Build = require(script.Parent.Parent.Parent.Modules.Build)
local Core = require(script.Parent.Parent.Kit.Core)
local Nature = require(script.Parent.Parent.Kit.Nature)
local Archi = require(script.Parent.Parent.Kit.Archi)
local Props = require(script.Parent.Parent.Kit.Props)
local Relief = require(script.Parent.Parent.Kit.Relief)
local Common = require(script.Parent.Common)

local Ocean = {}

local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local shade = Core.shade
local polar = Common.polar
local facing = Common.facing

local HULL = rgb(124, 78, 46)
local HULL_DARK = rgb(84, 52, 34)
local DECK = rgb(180, 136, 90)
local SAIL = rgb(246, 240, 224)
local ROOF_TILE = rgb(196, 100, 64)
local PASTELS = { rgb(244, 236, 220), rgb(250, 220, 150), rgb(240, 170, 140), rgb(170, 210, 230), rgb(200, 230, 190), rgb(240, 200, 210) }
local SHOPS = { "TAVERNE", "ARMURERIE", "CARTES", "VIANDE", "AUBERGE", "VOILERIE", "POISSON", "TRÉSORS" }

local TOP_RING = Common.TOP_RING

------------------------------------------------------------------------
-- Navires
------------------------------------------------------------------------

-- Navire pirate : coque effilée (proue en coins), pont, gaillards, mâts, voiles, haubans, canons,
-- figure de proue. `cf` = au niveau de la ligne de flottaison, -Z local = la proue.
-- `kind` : "mouton" (figure de bélier), "lion", "baleine" (proue en tête de baleine).
local function ship(parent: Instance, cf: CFrame, scale: number, kind: string, flag: Color3?, rng: Random): Model
	local s = scale
	local model = Core.slot(parent, "Navire", cf, 40 * s)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local L, W, H = 40 * s, 12 * s, 7 * s
	local hullColor = kind == "baleine" and rgb(236, 232, 224) or HULL
	-- coque : corps, bas plus étroit, proue en deux coins, poupe relevée
	Build.part(model, "Hull", Vector3.new(W, H, L * 0.7), cf * CFrame.new(0, H / 2 - 2 * s, L * 0.1), hullColor, { Material = Enum.Material.WoodPlanks })
	Build.part(model, "HullLow", Vector3.new(W * 0.7, H * 0.6, L * 0.62), cf * CFrame.new(0, -2.6 * s, L * 0.1), shade(hullColor, -0.2), { Material = Enum.Material.WoodPlanks })
	for _, side in { -1, 1 } do
		Build.wedge(model, "Bow", Vector3.new(W / 2, H, L * 0.22), cf * CFrame.new(side * W / 4, H / 2 - 2 * s, -L * 0.36) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, side * 0.05, 0), hullColor, {
			Material = Enum.Material.WoodPlanks,
		})
		Build.deco(model, "Wale", Vector3.new(0.4 * s, 0.7 * s, L * 0.7), cf * CFrame.new(side * (W / 2 + 0.1), H * 0.55 - 2 * s, L * 0.1), kind == "baleine" and rgb(60, 110, 170) or rgb(220, 180, 80), {
			Material = Enum.Material.Wood,
		})
		-- sabords et canons
		for k = 0, 3 do
			local z = -L * 0.15 + k * L * 0.13
			Build.deco(model, "Gunport", Vector3.new(0.3 * s, 1.2 * s, 1.4 * s), cf * CFrame.new(side * (W / 2 + 0.05), H * 0.25 - 2 * s, z), rgb(30, 24, 20))
			Core.cylinder(model, "Cannon", (cf * CFrame.new(side * (W / 2 - 0.4), H * 0.25 - 2 * s, z)).Position, (cf * CFrame.new(side * (W / 2 + 1.4 * s), H * 0.25 - 2 * s, z)).Position, 0.8 * s, rgb(40, 40, 44), {
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
		end
		Build.deco(model, "Rail", Vector3.new(0.5 * s, 1.2 * s, L * 0.7), cf * CFrame.new(side * (W / 2 - 0.2), H - 1.4 * s, L * 0.1), HULL_DARK, { Material = Enum.Material.Wood })
	end
	Build.part(model, "Deck", Vector3.new(W - 0.8, 0.4, L * 0.72), cf * CFrame.new(0, H - 2 * s, L * 0.08), DECK, { Material = Enum.Material.WoodPlanks })
	-- gaillard d'arrière (cabine) avec fenêtres
	local stern = cf * CFrame.new(0, H - 2 * s, L * 0.36)
	Build.part(model, "Cabin", Vector3.new(W - 1, 5 * s, L * 0.16), stern * CFrame.new(0, 2.5 * s, 0), shade(hullColor, 0.08), { Material = Enum.Material.WoodPlanks })
	for k = -1, 1 do
		Archi.window(model, stern * CFrame.new(k * W * 0.28, 2.6 * s, -L * 0.08 - 0.05), 1.6 * s, 1.6 * s, { frame = rgb(220, 180, 80), lit = true })
	end
	Build.part(model, "CabinRoof", Vector3.new(W, 0.5, L * 0.18), stern * CFrame.new(0, 5.2 * s, 0), HULL_DARK, { Material = Enum.Material.WoodPlanks })
	-- mâts, vergues et voiles
	local masts = kind == "baleine" and 3 or 2
	for m = 1, masts do
		local z = -L * 0.2 + (m - 1) * (L * 0.42 / math.max(1, masts - 1))
		local mh = (m == 1 and 30 or 26) * s
		local base = cf * CFrame.new(0, H - 2 * s, z)
		Core.vcyl(model, "Mast", base, mh, 1.2 * s, HULL_DARK, Enum.Material.Wood, false)
		for k, y in { mh * 0.45, mh * 0.8 } do
			local wide = (k == 1 and 16 or 12) * s
			Build.deco(model, "Yard", Vector3.new(wide, 0.5 * s, 0.5 * s), base * CFrame.new(0, y, 0), HULL_DARK, { Material = Enum.Material.Wood })
			local sailH = (k == 1 and 10 or 7) * s
			local sail = Build.deco(model, "Sail", Vector3.new(wide - 1, sailH, 0.3 * s), base * CFrame.new(0, y - sailH / 2 - 0.3, -0.6 * s) * CFrame.Angles(math.rad(-6), 0, 0), SAIL, {
				Material = Enum.Material.Fabric,
			})
			if k == 1 and flag then
				Core.plaqueText(model, base * CFrame.new(0, y - sailH / 2 - 0.3, -1.1 * s) * CFrame.Angles(math.rad(-6), 0, 0), Vector2.new(sailH * 0.8, sailH * 0.8), "☠", rgb(30, 26, 26))
			end
			local _ = sail
		end
		Core.ball(model, "CrowsNest", 2.6 * s, (base * CFrame.new(0, mh * 0.88, 0)).Position, HULL_DARK, Enum.Material.WoodPlanks)
		-- haubans
		for _, side in { -1, 1 } do
			Archi.cable(model, (base * CFrame.new(0, mh * 0.85, 0)).Position, (cf * CFrame.new(side * (W / 2 - 0.3), H - 1.2 * s, z + 3 * s)).Position, 0.3, 0.15, rgb(60, 50, 40))
		end
	end
	-- pavillon en haut du grand mât
	Build.deco(model, "JollyRoger", Vector3.new(0.15, 3 * s, 4.4 * s), cf * CFrame.new(0, H - 2 * s + 31 * s, -L * 0.2 + 2.2 * s), flag or rgb(30, 26, 26), { Material = Enum.Material.Fabric })
	-- beaupré et figure de proue
	local bow = cf * CFrame.new(0, H - 1 * s, -L * 0.47)
	Core.cylinder(model, "Bowsprit", bow.Position, (bow * CFrame.new(0, 4 * s, -10 * s)).Position, 0.8 * s, HULL_DARK, { Material = Enum.Material.Wood, CanCollide = false })
	if kind == "mouton" then
		Core.ball(model, "Figurehead", 4.4 * s, (bow * CFrame.new(0, 1.6 * s, -1 * s)).Position, rgb(250, 246, 236), Enum.Material.Fabric)
		Core.ball(model, "FigureFace", 2.4 * s, (bow * CFrame.new(0, 1.4 * s, -3 * s)).Position, rgb(250, 230, 190))
		for _, side in { -1, 1 } do
			Core.ellipsoid(model, "Horn", Vector3.new(1.4, 2.4, 1.4) * s, bow * CFrame.new(side * 2 * s, 2.6 * s, -1.6 * s) * CFrame.Angles(0, 0, side * 0.8), rgb(220, 200, 150))
		end
	elseif kind == "lion" then
		Core.ball(model, "Mane", 6 * s, (bow * CFrame.new(0, 1.6 * s, -1.4 * s)).Position, rgb(240, 170, 50), Enum.Material.Fabric)
		Core.ball(model, "FigureFace", 3.6 * s, (bow * CFrame.new(0, 1.6 * s, -3.4 * s)).Position, rgb(250, 220, 120))
	else
		-- proue en tête de baleine : grand bulbe blanc, yeux, bouche
		Core.ellipsoid(model, "WhaleHead", Vector3.new(W * 1.1, H * 1.6, L * 0.36), cf * CFrame.new(0, H * 0.4, -L * 0.42), hullColor)
		for _, side in { -1, 1 } do
			Core.ball(model, "WhaleEye", 2.4 * s, (cf * CFrame.new(side * W * 0.5, H * 0.7, -L * 0.48)).Position, rgb(30, 30, 40))
		end
		Build.deco(model, "WhaleMouth", Vector3.new(W * 1.12, 0.5 * s, L * 0.2), cf * CFrame.new(0, H * 0.05, -L * 0.5), rgb(60, 50, 60))
	end
	local _ = rng
	return model
end

------------------------------------------------------------------------
-- Ville portuaire
------------------------------------------------------------------------

-- Maison du port : murs pastel, toit de tuiles en croupe, fenêtres à volets et jardinières,
-- balcon, enseigne de boutique et auvent rayé au rez-de-chaussée.
local function portHouse(parent: Instance, cf: CFrame, size: Vector3, rng: Random): Model
	local model = Core.slot(parent, "MaisonDuPort", cf, size.Y + 8)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local wall = PASTELS[rng:NextInteger(1, #PASTELS)]
	local trim = rgb(250, 248, 240)
	local shutter = ({ rgb(60, 120, 170), rgb(70, 140, 90), rgb(170, 70, 60), rgb(90, 80, 150) })[rng:NextInteger(1, 4)]
	Archi.plinth(model, cf, size.X + 1.4, size.Z + 1.4, 0.8, rgb(176, 166, 150))
	local base = cf * CFrame.new(0, 0.8, 0)
	Archi.walls(model, base, size.X, size.Z, size.Y, wall, { band = trim })
	local floors = math.max(1, math.floor(size.Y / 9))
	for f = 0, floors - 1 do
		local y = 5 + f * 9
		Archi.windowRow(model, base * CFrame.new(0, y, -size.Z / 2 - 0.05), size.X, math.max(1, math.floor(size.X / 6)), 2.4, 3, {
			frame = trim,
			shutters = shutter,
			box = (f > 0 and rng:NextNumber() < 0.6) and rgb(230, 60, 80) or nil,
		}, function(x)
			return f == 0 and math.abs(x) < 3.6
		end)
		for _, side in { -1, 1 } do
			Archi.windowRow(model, base * CFrame.new(side * (size.X / 2 + 0.05), y, 0) * CFrame.Angles(0, side * math.pi / 2, 0), size.Z, math.max(1, math.floor(size.Z / 7)), 2.2, 2.8, { frame = trim, shutters = shutter })
		end
	end
	Archi.door(model, base * CFrame.new(0, 0, -size.Z / 2 - 0.05), 4, 7, { color = rgb(110, 70, 44), lamp = rgb(255, 210, 140) })
	if floors >= 2 then
		Archi.balcony(model, base * CFrame.new(0, 9, -size.Z / 2), math.min(size.X - 2, 9), 2.6, rgb(70, 60, 56))
	end
	Archi.hipRoof(model, base * CFrame.new(0, size.Y, 0), size.X, size.Z, size.Y * 0.32, 1.8, ROOF_TILE, { trim = shade(ROOF_TILE, -0.3) })
	if rng:NextNumber() < 0.5 then
		Archi.chimney(model, base * CFrame.new(size.X * 0.25, size.Y + 1, size.Z * 0.15), 5)
	end
	-- auvent rayé et enseigne
	local stripes = 5
	local color = ({ rgb(200, 60, 50), rgb(40, 110, 180), rgb(240, 170, 40), rgb(60, 150, 90) })[rng:NextInteger(1, 4)]
	for i = 0, stripes - 1 do
		Build.deco(model, "Awning", Vector3.new(size.X * 0.7 / stripes, 0.2, 3), base * CFrame.new(-size.X * 0.35 + (i + 0.5) * size.X * 0.7 / stripes, 7.8, -size.Z / 2 - 1.4) * CFrame.Angles(math.rad(-18), 0, 0), i % 2 == 0 and color or rgb(250, 246, 236), {
			Material = Enum.Material.Fabric,
		})
	end
	Archi.sign(model, base * CFrame.new(0, 9.6, -size.Z / 2 - 0.4), size.X * 0.6, 1.6, SHOPS[rng:NextInteger(1, #SHOPS)], { bg = rgb(60, 40, 30), text = rgb(255, 226, 150) })
	return model
end

-- Navire-restaurant échoué sur le sable (bâtiment sur le pont, enseigne en forme de poisson).
local function shipRestaurant(parent: Instance, cf: CFrame, rng: Random): Model
	local model = ship(parent, cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(90), 0), 1.1, "lion", nil, rng)
	model.Name = "NavireRestaurant"
	model:SetAttribute("Slot", "NavireRestaurant")
	local deck = cf * CFrame.new(0, 2 + 5.7, 0)
	Archi.walls(model, deck, 18, 9, 7, rgb(244, 236, 220), { frame = HULL_DARK, spacing = 4.5 })
	Archi.windowRow(model, deck * CFrame.new(0, 4, -4.55), 18, 3, 2.4, 2.4, { frame = HULL_DARK, lit = true })
	Archi.hipRoof(model, deck * CFrame.new(0, 7, 0), 18, 9, 3, 1.4, rgb(60, 110, 160), { trim = HULL_DARK })
	Archi.sign(model, deck * CFrame.new(0, 11.6, -3) * CFrame.Angles(math.rad(-10), 0, 0), 14, 3, "🐟 LE NAVIRE-RESTAURANT", { bg = rgb(40, 90, 150), text = rgb(255, 240, 200) })
	-- coque calée par des étais et des tonneaux
	for _, x in { -12, 0, 12 } do
		for _, side in { -1, 1 } do
			Core.beam(model, "Prop", (cf * CFrame.new(x, 0, side * 9)).Position, (cf * CFrame.new(x, 4, side * 6)).Position, 0.8, 0.8, HULL_DARK, { Material = Enum.Material.Wood })
		end
	end
	Archi.stairs(model, cf * CFrame.new(0, 0, -11) , 5, 7.6, 7, 8, rgb(150, 110, 74), Enum.Material.WoodPlanks)
	return model
end

-- Chantier naval : navire en construction sur son ber, échafaudages, grue, bois empilé.
local function shipyard(parent: Instance, cf: CFrame, rng: Random): Model
	local model = Core.slot(parent, "ChantierNaval", cf, 40)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Build.part(model, "Slipway", Vector3.new(30, 1, 56), cf * CFrame.new(0, 0.5, 0), rgb(150, 116, 80), { Material = Enum.Material.WoodPlanks })
	for k = -2, 2 do
		Build.part(model, "Cradle", Vector3.new(16, 3, 1.6), cf * CFrame.new(0, 2.5, k * 9), HULL_DARK, { Material = Enum.Material.Wood })
	end
	ship(model, cf * CFrame.new(0, 6, 0), 0.9, "mouton", nil, rng)
	-- échafaudage de part et d'autre
	for _, side in { -1, 1 } do
		for k = -2, 2 do
			Archi.block(model, "Scaffold", Vector3.new(0.5, 18, 0.5), cf * CFrame.new(side * 9, 1, k * 9), rgb(170, 140, 100), Enum.Material.Wood)
		end
		for _, y in { 6, 12 } do
			Build.part(model, "ScaffoldDeck", Vector3.new(2.4, 0.3, 38), cf * CFrame.new(side * 9.6, y, 0), rgb(176, 140, 96), { Material = Enum.Material.WoodPlanks })
		end
	end
	-- grue en bois
	local crane = cf * CFrame.new(18, 0, -10)
	Archi.block(model, "CraneTower", Vector3.new(2, 30, 2), crane, HULL_DARK, Enum.Material.Wood)
	Core.beam(model, "CraneBoom", (crane * CFrame.new(0, 28, 0)).Position, (crane * CFrame.new(-16, 32, 6)).Position, 1, 1, HULL_DARK, { Material = Enum.Material.Wood, CanCollide = false })
	Build.deco(model, "CraneRope", Vector3.new(0.15, 14, 0.15), crane * CFrame.new(-16, 25, 6), rgb(200, 180, 130), { Material = Enum.Material.Fabric })
	Props.crate(model, crane * CFrame.new(-16, 15, 6), 2.4)
	-- bois empilé
	for row = 0, 2 do
		for k = 0, 4 - row do
			local log = Build.part(model, "Lumber", Vector3.new(14, 1.2, 1.2), cf * CFrame.new(-18, 0.6 + row * 1.1, -12 + k * 1.25 + row * 0.6) * CFrame.Angles(0, math.rad(90), 0), shade(rgb(170, 128, 84), (k % 2) * 0.06), {
				Material = Enum.Material.Wood,
			})
			log.Shape = Enum.PartType.Cylinder
		end
	end
	Archi.sign(model, cf * CFrame.new(0, 10, -30), 16, 3, "⚓ CHANTIER NAVAL", { posts = 8, bg = rgb(60, 40, 30) })
	return model
end

-- Grande arche pirate (route de la base 270°).
local function pirateArch(parent: Instance, cf: CFrame): Model
	local model = Core.slot(parent, "ArchePirate", cf, 32)
	for _, side in { -1, 1 } do
		local p = cf * CFrame.new(side * 12, 0, 0)
		Core.vcyl(model, "ArchMast", p, 26, 2.4, HULL_DARK, Enum.Material.Wood)
		for k = 1, 4 do
			Core.vcyl(model, "Rope", p * CFrame.new(0, k * 5, 0), 0.6, 2.6, rgb(200, 176, 120), Enum.Material.Fabric, false)
		end
		-- ancre au pied
		local anchor = p * CFrame.new(side * 3, 0, -2)
		Build.part(model, "AnchorShank", Vector3.new(0.8, 7, 0.8), anchor * CFrame.new(0, 3.5, 0), rgb(60, 62, 66), { Material = Enum.Material.Metal })
		Build.part(model, "AnchorArm", Vector3.new(5, 0.8, 0.8), anchor * CFrame.new(0, 0.8, 0), rgb(60, 62, 66), { Material = Enum.Material.Metal })
		Core.ball(model, "AnchorRing", 1.6, (anchor * CFrame.new(0, 7.4, 0)).Position, rgb(60, 62, 66), Enum.Material.Metal)
	end
	Build.part(model, "ArchBeam", Vector3.new(30, 2.4, 2.4), cf * CFrame.new(0, 24, 0), HULL_DARK, { Material = Enum.Material.Wood })
	local flag = Build.deco(model, "Flag", Vector3.new(14, 9, 0.2), cf * CFrame.new(0, 18.4, -0.6), rgb(28, 24, 26), { Material = Enum.Material.Fabric })
	Build.surfaceText(flag, Enum.NormalId.Front, "☠", rgb(250, 250, 246), { TextStrokeTransparency = 1 })
	Build.surfaceText(flag, Enum.NormalId.Back, "☠", rgb(250, 250, 246), { TextStrokeTransparency = 1 })
	-- barre de navire au sommet
	local wheel = Build.deco(model, "ShipWheel", Vector3.new(0.6, 7, 7), cf * CFrame.new(0, 28.6, 0) * CFrame.Angles(0, math.rad(90), 0), rgb(150, 100, 60), { Material = Enum.Material.Wood })
	wheel.Shape = Enum.PartType.Cylinder
	for k = 0, 3 do
		Build.deco(model, "WheelSpoke", Vector3.new(0.5, 9, 0.5), cf * CFrame.new(0, 28.6, -0.4) * CFrame.Angles(0, 0, k * math.pi / 4), rgb(150, 100, 60), { Material = Enum.Material.Wood })
	end
	return model
end

-- Phare rayé sur son rocher, au large.
local function lighthouse(parent: Instance, base: Vector3, rng: Random): Model
	local cf = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
	local model = Core.slot(parent, "Phare", cf, 70)
	Nature.cliff(model, cf * CFrame.new(0, -4, 0), 34, 16, 30, { rng = rng, color = rgb(190, 178, 154), top = rgb(100, 160, 80), role = nil, slot = "RocherDuPhare", rubble = true, ramp = 1 })
	local top = cf * CFrame.new(0, 12, 0)
	for k = 0, 5 do
		Core.vcyl(model, "Tower", top * CFrame.new(0, k * 7, 0), 7, 10 - k * 0.6, k % 2 == 0 and rgb(240, 240, 236) or rgb(200, 50, 46), Enum.Material.SmoothPlastic)
	end
	local lamp = top * CFrame.new(0, 42, 0)
	Core.vcyl(model, "Gallery", lamp, 0.8, 11, rgb(50, 50, 56), Enum.Material.Metal)
	local light = Core.vcyl(model, "Lantern", lamp * CFrame.new(0, 0.8, 0), 5, 5, rgb(255, 240, 180), Enum.Material.Neon, false)
	Core.light(light, rgb(255, 240, 190), 60, 2)
	for _, p in Core.pyramid(model, "LanternRoof", lamp * CFrame.new(0, 5.8, 0), 6.4, 6.4, 3, rgb(200, 50, 46), Enum.Material.Metal) do
		p.CanCollide = false
	end
	return model
end

-- Cabane de plage sur pilotis (toit de palmes).
local function beachHut(parent: Instance, cf: CFrame)
	local model = Core.slot(parent, "CabaneDePlage", cf, 12)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3, 3 } do
			Archi.block(model, "Stilt", Vector3.new(0.6, 3, 0.6), cf * CFrame.new(x, 0, z), HULL_DARK, Enum.Material.Wood)
		end
	end
	Build.part(model, "HutFloor", Vector3.new(9, 0.5, 8), cf * CFrame.new(0, 3, 0), rgb(170, 130, 86), { Material = Enum.Material.WoodPlanks })
	Archi.walls(model, cf * CFrame.new(0, 3.2, 0.6), 7, 6, 5, rgb(196, 160, 110), { material = Enum.Material.WoodPlanks })
	for _, p in Core.pyramid(model, "Thatch", cf * CFrame.new(0, 8.2, 0.6), 10, 9, 4.4, rgb(196, 170, 100), Enum.Material.Grass) do
		p.CanCollide = true
	end
end

------------------------------------------------------------------------
-- Construction du décor
------------------------------------------------------------------------

local WHALE_ANGLE = 270
local PORT_ANGLE = 312

function Ocean.build(decor: Instance, rng: Random, _theme)
	local ring = Build.folder(decor, "Anneau")
	local island = Build.folder(decor, "Ile")
	local horizon = Build.folder(decor, "Horizon")
	local town = Build.folder(ring, "Ville")

	-- 1) Ville portuaire : deux rangées de maisons pastel.
	for i = 0, 47 do
		local angle = i * 7.5 + 3.75 + rng:NextNumber(-1, 1)
		local outer = i % 2 == 0
		local radius = outer and 316 or 292
		local pos = polar(angle, radius)
		local reserved = Common.angleDiff(angle, 300) < 10 or Common.angleDiff(angle, 120) < 13
		if not Layout.onPath(pos, 10) and not reserved and not Layout.inBossArena(pos, 14) then
			local size = Vector3.new(rng:NextNumber(13, 18), outer and rng:NextNumber(14, 20) or rng:NextNumber(10, 13), rng:NextNumber(11, 13))
			portHouse(town, facing(angle, radius, TOP_RING), size, rng)
		end
	end
	Common.ringStreet(town, 266, 280, "pave", rng)
	shipRestaurant(ring, facing(300, 304, TOP_RING), rng)
	shipyard(ring, facing(120, 300, TOP_RING), rng)

	-- 2) Marché du port et accessoires.
	local market = Build.folder(ring, "Marche")
	local colors = { rgb(200, 60, 50), rgb(40, 110, 180), rgb(240, 170, 40), rgb(60, 150, 90) }
	for i, angle in { 50, 56, 62, 68, 236, 242, 248 } do
		Props.stall(market, facing(angle, 270, TOP_RING) * CFrame.Angles(0, math.pi, 0), colors[(i - 1) % 4 + 1], i % 2 == 0 and "fish" or "fruits", rng)
	end
	for _, angle in { 14, 80, 140, 190, 226, 280, 344 } do
		Props.cargo(market, facing(angle, 278, TOP_RING) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng)
		Props.barrel(market, facing(angle + 2, 276, TOP_RING), 1, nil, true)
	end
	Common.alongRoads({ 104, 200, 262 }, 5, function(pos)
		Props.lamppost(market, pos, nil, rgb(255, 214, 150))
	end)

	-- 3) Lagon turquoise avec palmiers, parasols et transats (secteur 60°).
	local lagoonCenter = polar(60, 200)
	Relief.pond(ring, lagoonCenter, 24, { rng = rng, color = rgb(70, 200, 210), bed = rgb(220, 210, 170), bank = rgb(230, 214, 166), reeds = false, lilies = false }, Nature)
	for k = 0, 7 do
		local a = k / 8 * 360 + rng:NextNumber(-10, 10)
		local p = lagoonCenter + polar(a, rng:NextNumber(44, 54))
		if Common.ringFree(p, 4) then
			Nature.tree("Palmier", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(20, 28), detail = "normal" })
		end
	end
	for k = 0, 3 do
		local p = lagoonCenter + polar(200 + k * 25, 40)
		Core.vcyl(ring, "UmbrellaPole", CFrame.new(p), 7, 0.3, rgb(240, 240, 236), Enum.Material.Metal, false)
		for j = 0, 1 do
			for _, part in Core.pyramid(ring, "Umbrella", CFrame.new(p + UP * 7) * CFrame.Angles(0, j * math.pi / 4, 0), 8, 8, 1.6, k % 2 == 0 and rgb(230, 70, 60) or rgb(60, 140, 220), Enum.Material.Fabric) do
				part.CanCollide = false
			end
		end
		Build.part(ring, "Lounger", Vector3.new(2.2, 0.5, 6), CFrame.lookAt(p + polar(200 + k * 25, 4) + UP * 1, lagoonCenter + UP * 1) * CFrame.Angles(math.rad(8), 0, 0), rgb(250, 250, 246), { Material = Enum.Material.Fabric })
	end

	-- 4) Palmiers et végétation tropicale dans l'anneau.
	Core.scatter(rng, 44, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 40, function(p)
		return Common.ringFree(p, 6) and (lagoonCenter - Vector3.new(p.X, 0, p.Z)).Magnitude > 60
	end, function(p)
		Nature.tree("Palmier", ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(18, 28), detail = "normal" })
	end)
	Core.scatter(rng, 60, Vector3.zero, Layout.RingInner + 6, Layout.RingOuter - 6, function(p)
		return Common.ringFree(p, 4) and (lagoonCenter - Vector3.new(p.X, 0, p.Z)).Magnitude > 40
	end, function(p)
		if rng:NextNumber() < 0.6 then
			Nature.bush(ring, p + UP * TOP_RING, { rng = rng, height = rng:NextNumber(3, 5), palette = "tropical", flowers = rng:NextNumber() < 0.5 and rgb(230, 40, 70) or nil })
		else
			Nature.rock(ring, p + UP * TOP_RING, rng:NextNumber(2.5, 5), { rng = rng, color = rgb(196, 184, 160), material = Enum.Material.Limestone })
		end
	end)
	-- coquillages et pièces d'or dans le sable
	Core.scatter(rng, 50, Vector3.zero, Layout.RingInner + 4, Layout.RingOuter - 4, function(p)
		return Common.ringFree(p, 1)
	end, function(p)
		local shells = { rgb(255, 170, 180), rgb(255, 140, 60), rgb(250, 240, 220) }
		Core.ellipsoid(ring, "Shell", Vector3.new(0.8, 0.35, 0.7), CFrame.new(p + UP * (TOP_RING + 0.1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), shells[rng:NextInteger(1, 3)]).CastShadow = false
	end)
	Common.ringGround(ring, rng, { patches = 20, tufts = 160, flowers = 30, flowerColors = { rgb(230, 40, 70), rgb(250, 200, 60) }, patchRole = "herbe" })

	-- 5) Arche pirate sur la route 270°, drapeaux sur les autres routes.
	pirateArch(ring, facing(270, Layout.RingFenceRadius + 3, TOP_RING))
	for _, plotAngle in Layout.PlotAngles do
		local deg = math.deg(plotAngle)
		if Common.angleDiff(deg, 270) > 5 then
			for _, side in { -1, 1 } do
				local p = polar(deg + side * math.deg(11 / Layout.RingFenceRadius), Layout.RingFenceRadius + 2, TOP_RING)
				Core.vcyl(ring, "FlagPole", CFrame.new(p), 18, 0.6, HULL_DARK, Enum.Material.Wood)
				local flag = Build.deco(ring, "Flag", Vector3.new(0.15, 4, 6), CFrame.new(p + UP * 15.5) * CFrame.Angles(0, math.rad(-deg), 0) * CFrame.new(0, 0, 3), rgb(28, 24, 26), { Material = Enum.Material.Fabric })
				Build.surfaceText(flag, Enum.NormalId.Right, "☠", rgb(250, 250, 246), { TextStrokeTransparency = 1 })
				Build.surfaceText(flag, Enum.NormalId.Left, "☠", rgb(250, 250, 246), { TextStrokeTransparency = 1 })
			end
		end
	end

	-- 6) Île : palmeraies, hibiscus, cabanes de plage, port et navires, phare.
	local portCenter = polar(PORT_ANGLE, 650)
	local free = Common.islandFree({ { portCenter, 50 } })
	Common.forest(island, rng, {
		groves = 30,
		perGrove = { 4, 8 },
		radius = { 20, 36 },
		free = free,
		spacing = 0.4,
		species = {
			{ "Palmier", 6, 18, 30 },
			{ "ArbreFeuillu", 2, 18, 28, "tropical" },
			{ "Bambou", 1, 20, 28 },
		},
		undergrowth = { palette = "tropical", ferns = rgb(70, 130, 60), flowers = { rgb(230, 40, 70), rgb(250, 140, 40), rgb(250, 220, 80) }, rocks = rgb(196, 184, 160) },
	})
	for _, angle in { 40, 150, 200, 250, 340 } do
		local p = polar(angle, 664)
		if not WorldBuilderInCliffs(p) then
			beachHut(island, CFrame.lookAt(p, Vector3.zero) * CFrame.new(0, -0.4, 0))
			Nature.tree("Palmier", island, p + polar(angle + 90, 10) + UP * -0.4, { rng = rng, height = 22, detail = "low" })
		end
	end
	-- port : jetées de bois et deux navires amarrés
	local port = Build.folder(island, "Port")
	for _, offset in { -18, 18 } do
		local a = polar(PORT_ANGLE + math.deg(offset / 650), 640, 0.3)
		local dir = (Vector3.new(a.X, 0, a.Z)).Unit
		local b = a + dir * 90
		Relief.plankBridge(port, a, b, 8, 0.6)
		for k = 0, 9 do
			local p = a + dir * (k * 10)
			for _, side in { -1, 1 } do
				Core.vcyl(port, "Piling", CFrame.new(p + dir:Cross(UP) * side * 4.4 - UP * 6), 8, 1.2, HULL_DARK, Enum.Material.Wood)
			end
		end
	end
	local portDir = Vector3.new(portCenter.X, 0, portCenter.Z).Unit
	local shipA = portCenter + portDir * 56 + portDir:Cross(UP) * 38
	local shipB = portCenter + portDir * 66 - portDir:Cross(UP) * 38
	ship(port, CFrame.lookAt(shipA - UP * 1.2, shipA - UP * 1.2 + portDir), 1, "mouton", rgb(28, 24, 26), rng)
	ship(port, CFrame.lookAt(shipB - UP * 1.2, shipB - UP * 1.2 + portDir), 1.3, "lion", rgb(28, 24, 26), rng)
	for k = 0, 2 do
		Props.cargo(port, CFrame.new(portCenter + portDir:Cross(UP) * (k * 8 - 8) - portDir * 6), rng)
	end
	lighthouse(horizon, polar(150, 730, -2), rng)

	-- 7) En mer : le navire-baleine et des îles tropicales.
	local whale = polar(WHALE_ANGLE, 790, -1)
	ship(horizon, CFrame.lookAt(whale, whale + Vector3.new(1, 0, 0)), 3, "baleine", rgb(28, 24, 26), rng)
	for i = 0, 15 do
		local angle = i * 22.5 + rng:NextNumber(-6, 6)
		if Common.angleDiff(angle, WHALE_ANGLE) > 18 and Common.angleDiff(angle, 150) > 8 and Common.angleDiff(angle, PORT_ANGLE) > 12 then
			local center = polar(angle, rng:NextNumber(Layout.HorizonInner + 60, Layout.HorizonOuter - 40), -2)
			Nature.mountain(horizon, center, rng:NextNumber(120, 200), rng:NextNumber(40, 90), {
				rng = rng,
				rock = rgb(170, 160, 140),
				grass = rgb(80, 150, 70),
				trees = rgb(50, 110, 50),
				slot = "IleTropicale",
				material = Enum.Material.Limestone,
			})
			for k = 1, 3 do
				Nature.tree("Palmier", horizon, center + polar(rng:NextNumber(0, 360), rng:NextNumber(50, 70)), { rng = rng, height = rng:NextNumber(26, 34), detail = "low" })
				local _ = k
			end
		end
	end

	-- 8) Lampes de la promenade, embruns et mouettes.
	Common.walkwayLamps(ring, 15, function(pos)
		Props.lamppost(ring, pos, nil, rgb(255, 214, 150))
	end)
	Common.ambient(decor, "Embruns", {
		colors = ColorSequence.new(rgb(230, 250, 255), rgb(180, 230, 255)),
		size = 0.5,
		rate = 24,
		speed = NumberRange.new(1, 2),
		direction = Enum.NormalId.Top,
		y = 0.5,
		radius = 360,
		lightEmission = 0.6,
	})
	Common.ambient(decor, "Mouettes", {
		colors = ColorSequence.new(rgb(255, 255, 255)),
		size = 1.4,
		rate = 4,
		speed = NumberRange.new(8, 12),
		direction = Enum.NormalId.Front,
		y = 90,
		radius = 500,
		lifetime = NumberRange.new(16, 22),
		spin = false,
	})
end

-- Vrai si la position est dans un cap rocheux de l'île (pas de cabane de plage dessus).
function WorldBuilderInCliffs(pos: Vector3): boolean
	return require(script.Parent.Parent.WorldBuilder).inCliffs(pos, 10)
end

return Ocean
