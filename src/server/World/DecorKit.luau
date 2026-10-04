-- DecorKit : point d'entrée unique du kit de décor de la carte (compatible avec l'ancien kit).
--
--   Kit/Core    : formes de base, emplacements remplaçables (DecorSlot), couleurs du sol par
--                 univers (TeinteSol), semis, modèles maîtres clonés ;
--   Kit/Nature  : arbres (feuillus, géants, sapins, cèdres, cerisiers, érables, glycines, saules,
--                 palmiers, bambous...), buissons, haies, fleurs, herbes, rochers, falaises, montagnes ;
--   Kit/Archi   : toits en couches, poutres, fenêtres encadrées, volets, balcons, escaliers,
--                 enseignes, réservoirs, climatiseurs, poteaux et câbles, guirlandes de lanternes ;
--   Kit/Props   : accessoires (tonneaux, caisses, charrettes, bancs, étals, bannières, kiosques...) ;
--   Kit/Relief  : sol pavé, murets, clôtures, eau (étangs, ruisseaux), ponts.
--
-- EMPLACEMENTS REMPLAÇABLES : chaque gros élément (arbre, rocher, bâtiment...) est un Model tagué
-- "DecorSlot" avec les attributs Slot (nom du modèle) et TargetHeight (hauteur en studs).
-- Au lancement, si ServerStorage > ModelesDeco contient un modèle (ou un dossier de plusieurs
-- modèles) portant ce nom, il remplace l'élément : mis à la bonne hauteur, posé au même endroit.
-- Exemple : glisse un arbre de la Boîte à outils dans ServerStorage > ModelesDeco et renomme-le
-- "ArbreFeuillu" : tous les feuillus de la carte deviennent cet arbre.

local Core = require(script.Parent.Kit.Core)
local Nature = require(script.Parent.Kit.Nature)

local DecorKit = {}

-- Core
DecorKit.SlotTag = Core.SlotTag
DecorKit.StoreName = Core.StoreName
DecorKit.SolTag = Core.SolTag
DecorKit.shade = Core.shade
DecorKit.ellipsoid = Core.ellipsoid
DecorKit.ball = Core.ball
DecorKit.cylinder = Core.cylinder
DecorKit.beam = Core.beam
DecorKit.vcyl = Core.vcyl
DecorKit.pyramid = Core.pyramid
DecorKit.flatDisc = Core.flatDisc
DecorKit.plaqueText = Core.plaqueText
DecorKit.light = Core.light
DecorKit.solRole = Core.solRole
DecorKit.applySol = Core.applySol
DecorKit.slot = Core.slot
DecorKit.hasStore = Core.hasStore
DecorKit.replaceSlots = Core.replaceSlots
DecorKit.scatter = Core.scatter
DecorKit.scatterSpaced = Core.scatterSpaced

-- Nature
DecorKit.Palettes = Nature.Palettes
DecorKit.tree = Nature.tree
DecorKit.roundTree = Nature.roundTree
DecorKit.giantTree = Nature.giantTree
DecorKit.pine = Nature.pine
DecorKit.cherryTree = Nature.cherryTree
DecorKit.wisteriaTree = Nature.wisteriaTree
DecorKit.palmTree = Nature.palmTree
DecorKit.bush = Nature.bush
DecorKit.hedge = Nature.hedge
DecorKit.tuft = Nature.tuft
DecorKit.tallGrass = Nature.tallGrass
DecorKit.fern = Nature.fern
DecorKit.reeds = Nature.reeds
DecorKit.flower = Nature.flower
DecorKit.flowerBed = Nature.flowerBed
DecorKit.rock = Nature.rock
DecorKit.cliff = Nature.cliff
DecorKit.hill = Nature.hill
DecorKit.mountain = Nature.mountain

local UP = Vector3.new(0, 1, 0)

-- Tache de sol organique (plusieurs disques qui se chevauchent).
function DecorKit.patch(parent: Instance, center: Vector3, size: number, top: number, color: Color3, material: Enum.Material?, rng: Random, role: string?)
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = i == 1 and 0 or size * rng:NextNumber(0.2, 0.42)
		local d = size * (i == 1 and 0.8 or rng:NextNumber(0.4, 0.65))
		local pos = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local disc = Core.flatDisc(parent, "Patch", pos, d, top + (i % 2) * 0.01, color, material)
		if role then
			Core.solRole(disc, role)
		end
	end
end

-- Chemin de dalles de pierre irrégulières de `a` à `b`.
function DecorKit.stonePath(parent: Instance, a: Vector3, b: Vector3, width: number, top: number, color: Color3, rng: Random, role: string?)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local right = dir:Cross(UP)
	for d = 0, length, 2.6 do
		local count = math.max(1, math.floor(width / 2.6))
		for k = 1, count do
			local lateral = (k - (count + 1) / 2) * 2.5 + rng:NextNumber(-0.5, 0.5)
			local pos = a + dir * (d + rng:NextNumber(-0.6, 0.6)) + right * lateral
			local size = rng:NextNumber(1.9, 2.5)
			local nuance = rng:NextNumber(-0.12, 0.1)
			local stone = Core.flatDisc(parent, "PathStone", pos, size, top, Core.shade(color, nuance), Enum.Material.Slate)
			if role then
				Core.solRole(stone, role, nuance)
			end
		end
	end
end

-- Chemin de terre aux bords irréguliers (disques qui se chevauchent).
function DecorKit.dirtPath(parent: Instance, a: Vector3, b: Vector3, width: number, top: number, color: Color3, rng: Random, role: string?)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local right = dir:Cross(UP)
	for d = 0, length, width * 0.45 do
		local pos = a + dir * d + right * rng:NextNumber(-0.12, 0.12) * width
		local nuance = rng:NextNumber(-0.05, 0.05)
		local disc = Core.flatDisc(parent, "Dirt", pos, width * rng:NextNumber(0.9, 1.15), top + rng:NextNumber(0, 0.01), Core.shade(color, nuance), Enum.Material.Ground)
		if role then
			Core.solRole(disc, role, nuance)
		end
	end
end

return DecorKit
