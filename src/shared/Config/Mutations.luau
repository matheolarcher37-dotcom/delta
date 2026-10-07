-- VARIÉTÉS = MUTATIONS des persos (Or, Diamant, Sakura, Angélique...).
--
-- La rareté d'un perso est FIXE (champ `rarity` de Config/Characters : Maruto est Épique, il
-- reste Épique). Une mutation s'ajoute PAR-DESSUS : elle change l'apparence du perso (teinte,
-- matière, reflets, particules légères) et multiplie sa puissance, ses revenus et son prix.
--
-- Une seule liste pour tout le jeu : les anciennes « auras » (Foudre, Givre, Flamme, Néant,
-- Doré, Arc-en-ciel) sont devenues des mutations (Doré s'appelle maintenant Or). Dans les
-- sauvegardes, la mutation d'un perso est rangée dans le champ `aura` (nom historique, gardé
-- pour que les échanges, fusions et anciennes sauvegardes continuent de marcher).
--
-- Champs d'une mutation :
--   id, name, order (de la plus courante à la plus rare, pour les listes),
--   color (couleur principale), gradient (dégradé des étiquettes), rainbow (vrai = arc-en-ciel),
--   multiplier = puissance / revenus / prix (x2 = deux fois plus),
--   chance     = probabilité (0-1) d'apparaître sur un perso tiré à la machine (avant la chance),
--   effect     = effet joué côté client (Controllers/AuraController) : lightning, frost, fire,
--                cubes, gold, rainbow ; "none" = rien côté client (l'apparence est posée par le
--                serveur, Modules/Mutations.luau),
--   look       = apparence posée sur le modèle (Modules/Mutations.luau) :
--                tint (couleur du voile sur les habits), tintAlpha (0 = invisible, 1 = opaque),
--                shine (reflet balayant), hair (couleur des cheveux/accessoires), mix (0-1),
--                material, reflectance, body = { color, mix, material, reflectance } (pièces de la
--                tenue et accessoires), motif ("stars", "petals", "glint" peint sur le torse),
--                particles = { texture, color, rate, size, speed, ... }.
--   Les mutations x3 et plus ont en plus un contour lumineux (Highlight) de leur couleur.
-- Pour équilibrer : changer `chance` ou `multiplier` ici suffit.

local Mutations = {}

local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"

-- Identifiant de « pas de mutation » (listes de l'auto-roulage, filtres).
Mutations.None = "aucune"

Mutations.List = {
	foudre = {
		id = "foudre",
		name = "Foudre",
		order = 1,
		color = rgb(255, 230, 40),
		gradient = { rgb(255, 250, 160), rgb(255, 200, 20) },
		multiplier = 1.5,
		chance = 0.02,
		effect = "lightning",
		look = {
			tint = rgb(255, 236, 90),
			veil = { rgb(255, 252, 200), rgb(255, 225, 40), rgb(255, 170, 0) },
			tintAlpha = 0.4,
			motif = "glint",
			hair = rgb(255, 236, 90),
			mix = 0.5,
			body = { color = rgb(255, 225, 60), mix = 0.3 },
			particles = { texture = SPARK, color = { rgb(255, 255, 200), rgb(255, 220, 40) }, rate = 6, size = 0.36, speed = 2.2, lifetime = 0.5, rotSpeed = 200 },
		},
	},
	givre = {
		id = "givre",
		name = "Givre",
		order = 2,
		color = rgb(120, 230, 255),
		gradient = { rgb(220, 250, 255), rgb(90, 190, 255) },
		multiplier = 1.6,
		chance = 0.016,
		effect = "frost",
		look = {
			tint = rgb(170, 230, 255),
			veil = { rgb(250, 255, 255), rgb(170, 225, 255), rgb(90, 170, 240) },
			tintAlpha = 0.45,
			hair = rgb(200, 242, 255),
			mix = 0.6,
			material = Enum.Material.Ice,
			body = { color = rgb(180, 230, 255), mix = 0.45, material = Enum.Material.Ice },
			particles = {
				texture = SPARK,
				color = { rgb(255, 255, 255), rgb(170, 230, 255) },
				rate = 7,
				size = 0.3,
				speed = 0.5,
				lifetime = 1.8,
				acceleration = Vector3.new(0, -1, 0),
			},
		},
	},
	flamme = {
		id = "flamme",
		name = "Flamme",
		order = 3,
		color = rgb(255, 120, 30),
		gradient = { rgb(255, 210, 90), rgb(240, 70, 20) },
		multiplier = 1.75,
		chance = 0.014,
		effect = "fire",
		look = {
			tint = rgb(255, 120, 40),
			veil = { rgb(255, 225, 90), rgb(255, 100, 20), rgb(170, 20, 10) },
			tintAlpha = 0.48,
			hair = rgb(255, 110, 30),
			mix = 0.55,
			body = { color = rgb(230, 70, 20), mix = 0.35 },
			particles = {
				texture = FIRE_SPARKS,
				color = { rgb(255, 220, 90), rgb(255, 80, 20) },
				rate = 9,
				size = 0.4,
				speed = 1.6,
				lifetime = 0.9,
				acceleration = Vector3.new(0, 3, 0),
			},
		},
	},
	sakura = {
		id = "sakura",
		name = "Sakura",
		order = 4,
		color = rgb(255, 150, 200),
		gradient = { rgb(255, 225, 240), rgb(255, 120, 185) },
		multiplier = 1.8,
		chance = 0.025,
		effect = "none",
		look = {
			tint = rgb(255, 170, 210),
			tintAlpha = 0.44,
			hair = rgb(255, 168, 204),
			mix = 0.7,
			motif = "petals",
			body = { color = rgb(255, 170, 205), mix = 0.4 },
			particles = {
				texture = SPARK,
				color = { rgb(255, 205, 225), rgb(255, 140, 190) },
				rate = 10,
				size = 0.42,
				speed = 1.2,
				lifetime = 2.2,
				acceleration = Vector3.new(0.6, -1.2, 0),
				rotSpeed = 120,
			},
		},
	},
	["or"] = {
		id = "or",
		name = "Or",
		order = 5,
		color = rgb(255, 200, 50),
		gradient = { rgb(255, 245, 170), rgb(240, 160, 20) },
		multiplier = 2.5,
		chance = 0.035,
		effect = "gold",
		look = {
			tint = rgb(255, 196, 40),
			tintAlpha = 0.55,
			shine = true,
			hair = rgb(255, 196, 56),
			mix = 0.8,
			material = Enum.Material.Foil,
			reflectance = 0.2,
			body = { color = rgb(255, 190, 50), mix = 0.6, material = Enum.Material.Foil, reflectance = 0.18 },
			particles = { texture = SPARK, color = { rgb(255, 240, 150), rgb(255, 170, 30) }, rate = 7, size = 0.34, speed = 0.8, lifetime = 1.1, rotSpeed = 90 },
		},
	},
	ombre = {
		id = "ombre",
		name = "Ombre",
		order = 6,
		color = rgb(120, 70, 190),
		gradient = { rgb(190, 150, 255), rgb(40, 20, 70) },
		multiplier = 2.2,
		chance = 0.015,
		effect = "none",
		look = {
			tint = rgb(22, 10, 38),
			veil = { rgb(70, 30, 120), rgb(18, 8, 30), rgb(8, 4, 14) },
			tintAlpha = 0.72,
			hair = rgb(30, 16, 50),
			mix = 0.88,
			body = { color = rgb(26, 16, 40), mix = 0.7 },
			particles = {
				texture = SMOKE,
				color = { rgb(70, 30, 120), rgb(10, 6, 20) },
				rate = 11,
				size = 1.5,
				speed = 0.8,
				lifetime = 1.6,
				transparency = 0.55,
				lightEmission = 0,
			},
		},
	},
	neant = {
		id = "neant",
		name = "Néant",
		order = 7,
		color = rgb(170, 60, 255),
		gradient = { rgb(220, 160, 255), rgb(110, 30, 200) },
		multiplier = 2.5,
		chance = 0.008,
		effect = "cubes",
		look = {
			tint = rgb(120, 50, 200),
			veil = { rgb(210, 140, 255), rgb(120, 40, 220), rgb(40, 10, 90) },
			tintAlpha = 0.5,
			hair = rgb(120, 50, 200),
			mix = 0.6,
			body = { color = rgb(90, 30, 160), mix = 0.45 },
			particles = { texture = SPARK, color = { rgb(220, 160, 255), rgb(110, 30, 200) }, rate = 7, size = 0.38, speed = 0.7, lifetime = 1.3, rotSpeed = 140 },
		},
	},
	diamant = {
		id = "diamant",
		name = "Diamant",
		order = 8,
		color = rgb(130, 235, 255),
		gradient = { rgb(240, 255, 255), rgb(90, 200, 255) },
		multiplier = 3.5,
		chance = 0.012,
		effect = "none",
		look = {
			tint = rgb(190, 245, 255),
			tintAlpha = 0.46,
			shine = true,
			hair = rgb(196, 242, 255),
			mix = 0.85,
			material = Enum.Material.Glass,
			reflectance = 0.35,
			motif = "glint",
			body = { color = rgb(160, 225, 255), mix = 0.55, material = Enum.Material.Glass, reflectance = 0.3 },
			particles = { texture = SPARK, color = { rgb(255, 255, 255), rgb(150, 235, 255) }, rate = 6, size = 0.5, speed = 0.6, lifetime = 1.1, rotSpeed = 60 },
		},
	},
	galaxie = {
		id = "galaxie",
		name = "Galaxie",
		order = 9,
		color = rgb(90, 80, 255),
		gradient = { rgb(170, 140, 255), rgb(30, 20, 110), rgb(255, 120, 230) },
		multiplier = 4,
		chance = 0.005,
		effect = "none",
		look = {
			tint = rgb(46, 34, 120),
			tintAlpha = 0.64,
			shine = true,
			hair = rgb(46, 34, 120),
			mix = 0.75,
			motif = "stars",
			body = { color = rgb(40, 24, 100), mix = 0.6 },
			particles = {
				texture = SPARK,
				color = { rgb(255, 255, 255), rgb(160, 140, 255), rgb(255, 130, 230) },
				rate = 10,
				size = 0.32,
				speed = 0.4,
				lifetime = 1.6,
				rotSpeed = 30,
			},
		},
	},
	angelique = {
		id = "angelique",
		name = "Angélique",
		order = 10,
		color = rgb(255, 240, 190),
		gradient = { rgb(255, 255, 255), rgb(255, 220, 120) },
		multiplier = 4.5,
		chance = 0.004,
		effect = "none",
		look = {
			tint = rgb(255, 250, 230),
			tintAlpha = 0.52,
			shine = true,
			hair = rgb(255, 246, 214),
			mix = 0.7,
			halo = true,
			body = { color = rgb(255, 252, 240), mix = 0.45 },
			particles = {
				texture = SPARK,
				color = { rgb(255, 255, 255), rgb(255, 230, 150) },
				rate = 8,
				size = 0.45,
				speed = 1.4,
				lifetime = 1.4,
				acceleration = Vector3.new(0, 1.5, 0),
			},
		},
	},
	arcenciel = {
		id = "arcenciel",
		name = "Arc-en-ciel",
		order = 11,
		color = rgb(255, 120, 200),
		gradient = { rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 255, 120), rgb(80, 160, 255), rgb(220, 90, 255) },
		rainbow = true,
		multiplier = 6,
		chance = 0.0015,
		effect = "rainbow",
		look = {
			rainbowTint = true,
			tintAlpha = 0.3,
			shine = true,
			particles = {
				texture = FIRE_SPARKS,
				color = { rgb(255, 90, 90), rgb(255, 230, 70), rgb(90, 255, 120), rgb(90, 170, 255), rgb(230, 100, 255) },
				rate = 9,
				size = 0.4,
				speed = 1.6,
				lifetime = 1.2,
			},
		},
	},
}

-- Anciens identifiants (sauvegardes d'avant la v3.2, autres modules) -> mutation actuelle.
Mutations.Aliases = {
	dore = "or",
	gold = "or",
	diamond = "diamant",
	blossom = "sakura",
	angelic = "angelique",
	shadow = "ombre",
	galaxy = "galaxie",
	rainbow = "arcenciel",
}

-- Ordre d'affichage (listes) : de la plus courante à la plus rare.
Mutations.Order = {}
for id in Mutations.List do
	table.insert(Mutations.Order, id)
end
table.sort(Mutations.Order, function(a, b)
	return Mutations.List[a].order < Mutations.List[b].order
end)

-- Ordre des listes de l'interface (fenêtre « Roulement automatique ») : les mutations
-- phares d'abord (comme sur la capture de référence), puis les autres.
Mutations.MenuOrder = { "or", "diamant", "sakura", "angelique", "arcenciel", "galaxie", "ombre", "neant", "flamme", "givre", "foudre" }

-- Ordre de tirage : de la plus rare à la plus courante (la plus rare est testée d'abord).
Mutations.RollOrder = {}
for i = #Mutations.Order, 1, -1 do
	table.insert(Mutations.RollOrder, Mutations.Order[i])
end

-- Identifiant normalisé (alias compris) ou nil.
function Mutations.normalize(id: any): string?
	if type(id) ~= "string" or id == "" or id == Mutations.None then
		return nil
	end
	local key = Mutations.Aliases[id] or id
	if Mutations.List[key] then
		return key
	end
	return nil
end

function Mutations.get(id: any)
	local key = Mutations.normalize(id)
	return key and Mutations.List[key] or nil
end

-- Multiplicateur de puissance / prix (1 sans mutation).
function Mutations.multiplier(id: any): number
	local m = Mutations.get(id)
	return m and m.multiplier or 1
end

-- « x2,5 » (multiplicateur écrit à la française).
function Mutations.multText(id: any): string
	local m = Mutations.get(id)
	local value = m and m.multiplier or 1
	local text = value == math.floor(value) and tostring(math.floor(value)) or string.format("%.2f", value):gsub("0+$", "")
	return "x" .. (string.gsub(text, "%.", ","))
end

-- Probabilité totale d'avoir une mutation (pour l'affichage), avec une chance donnée.
function Mutations.totalChance(luck: number?): number
	local factor = math.max(0, luck or 1)
	local none = 1
	for _, id in Mutations.RollOrder do
		none *= 1 - math.min(1, Mutations.List[id].chance * factor)
	end
	return 1 - none
end

-- Tire une mutation (ou nil). `luck` multiplie toutes les chances.
function Mutations.roll(rng: Random, luck: number?): string?
	local factor = luck or 1
	for _, id in Mutations.RollOrder do
		if rng:NextNumber() < Mutations.List[id].chance * factor then
			return id
		end
	end
	return nil
end

return Mutations
