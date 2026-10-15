-- Traits : bonus passifs aléatoires sur chaque perso (comme dans les jeux d'animé récents).
-- Un perso peut recevoir un trait à l'ouverture d'une relique, puis le relancer
-- à l'Autel des Traits (au centre de la carte) avec des Cristaux de Trait.

export type Trait = {
	id: string,
	name: string,
	description: string,
	tier: number, -- 1 = commun ... 5 = ultra rare
	weight: number,
	color: Color3,
	power: number?, -- bonus de puissance (+0.2 = +20 %)
	hp: number?, -- bonus de PV
	speed: number?, -- réduction du temps entre deux attaques (0.2 = -20 %)
	crit: number?, -- chance de coup critique en plus
	coins: number?, -- bonus de pièces (combat + revenus de base)
	xp: number?, -- bonus d'XP
	lifesteal: number?, -- part des dégâts rendue en PV
	scale: number?, -- bonus de taille visuelle
}

local rgb = Color3.fromRGB

local Traits = {}

Traits.TierNames = { "Commun", "Peu commun", "Rare", "Mythique", "Secret" }
Traits.TierColors = { rgb(190, 200, 210), rgb(110, 220, 120), rgb(80, 160, 255), rgb(255, 80, 140), rgb(255, 210, 60) }

Traits.List = {
	vigueur1 = { id = "vigueur1", name = "Vigueur I", description = "+10 % de puissance", tier = 1, weight = 18, color = rgb(255, 120, 100), power = 0.1 },
	celerite1 = { id = "celerite1", name = "Célérité I", description = "Attaque 10 % plus vite", tier = 1, weight = 18, color = rgb(120, 220, 255), speed = 0.1 },
	erudit = { id = "erudit", name = "Érudit", description = "+50 % d'XP", tier = 1, weight = 12, color = rgb(180, 140, 255), xp = 0.5 },
	vigueur2 = { id = "vigueur2", name = "Vigueur II", description = "+20 % de puissance", tier = 2, weight = 10, color = rgb(255, 90, 70), power = 0.2 },
	celerite2 = { id = "celerite2", name = "Célérité II", description = "Attaque 18 % plus vite", tier = 2, weight = 10, color = rgb(80, 200, 255), speed = 0.18 },
	fortune = { id = "fortune", name = "Fortuné", description = "+25 % de pièces", tier = 2, weight = 9, color = rgb(255, 210, 80), coins = 0.25 },
	colosse = { id = "colosse", name = "Colosse", description = "+60 % de PV et plus grand", tier = 2, weight = 8, color = rgb(200, 150, 100), hp = 0.6, scale = 0.12 },
	critique = { id = "critique", name = "Critique", description = "+15 % de chance de critique", tier = 3, weight = 7, color = rgb(255, 60, 60), crit = 0.15 },
	vigueur3 = { id = "vigueur3", name = "Vigueur III", description = "+35 % de puissance", tier = 3, weight = 4.5, color = rgb(230, 50, 40), power = 0.35 },
	celerite3 = { id = "celerite3", name = "Célérité III", description = "Attaque 25 % plus vite", tier = 3, weight = 4.5, color = rgb(40, 170, 255), speed = 0.25 },
	-- Vampire fait partie des 4 traits « très rares » à cinématique : rang Mythique (~1,5 %)
	vampire = { id = "vampire", name = "Vampire", description = "Récupère 12 % des dégâts infligés en PV", tier = 4, weight = 1.6, color = rgb(170, 20, 60), lifesteal = 0.12 },
	midas = { id = "midas", name = "Midas", description = "+100 % de pièces", tier = 4, weight = 1.5, color = rgb(255, 190, 30), coins = 1 },
	celeste = {
		id = "celeste",
		name = "Céleste",
		description = "+100 % de puissance, attaque 20 % plus vite",
		tier = 4,
		weight = 0.6,
		color = rgb(140, 230, 255),
		power = 1,
		speed = 0.2,
	},
	monarque = {
		id = "monarque",
		name = "Monarque",
		description = "+200 % de puissance, +50 % de PV, +50 % de pièces",
		tier = 5,
		weight = 0.2,
		color = rgb(255, 215, 60),
		power = 2,
		hp = 0.5,
		coins = 0.5,
		scale = 0.15,
	},
} :: { [string]: Trait }

-- Ordre d'affichage (du plus rare au plus commun).
Traits.Order = { "monarque", "celeste", "midas", "vampire", "celerite3", "vigueur3", "critique", "colosse", "fortune", "celerite2", "vigueur2", "erudit", "celerite1", "vigueur1" }

-- Habillage visuel des traits (écran des Traits + révélations) :
--   icon      = icône vectorielle de l'emblème du trait (UI/Icons, dessinée sans image) ;
--   motto     = petite phrase sous le nom lors de la révélation ;
--   cinematic = cinématique jouée dans le monde (Controllers/TraitCinematic) quand on l'obtient.
-- Les autres traits ont une révélation à l'écran dont la force dépend de leur rang (voir revealLevel).
Traits.Visual = {
	vigueur1 = { icon = "sword", motto = "Un peu plus de force." },
	celerite1 = { icon = "fast", motto = "Un peu plus vif." },
	erudit = { icon = "book", motto = "Apprend deux fois plus vite." },
	vigueur2 = { icon = "sword", motto = "Des coups qui font mal." },
	celerite2 = { icon = "fast", motto = "Vif comme l'éclair." },
	fortune = { icon = "coin", motto = "Les pièces l'adorent." },
	colosse = { icon = "shield", motto = "Une montagne de muscles." },
	critique = { icon = "target", motto = "Chaque coup peut être fatal." },
	vigueur3 = { icon = "sword", motto = "Une force colossale." },
	celerite3 = { icon = "bolt", motto = "Plus rapide que l'œil." },
	vampire = { icon = "heart", motto = "La nuit lui appartient.", cinematic = "vampire" },
	midas = { icon = "coin", motto = "Tout ce qu'il touche devient or.", cinematic = "midas" },
	celeste = { icon = "star", motto = "Béni par les cieux.", cinematic = "celeste" },
	monarque = { icon = "crown", motto = "Tous s'inclinent devant lui.", cinematic = "monarch" },
}

-- Force de la révélation d'un trait : 1 = simple éclat, 2 = étincelles, 3 = révélation renforcée
-- à l'écran (rayons, gros titre), 4 = cinématique dans le monde.
function Traits.revealLevel(id: string?): number
	local trait = id and Traits.List[id]
	if not trait then
		return 0
	end
	local visual = Traits.Visual[id :: string]
	if visual and visual.cinematic then
		return 4
	end
	if trait.tier >= 3 then
		return 3
	end
	return trait.tier >= 2 and 2 or 1
end

-- Cinématique d'un trait (ou nil) : "monarch", "celeste", "midas" ou "vampire".
function Traits.cinematicOf(id: string?): string?
	local visual = id and Traits.Visual[id]
	return visual and visual.cinematic or nil
end

-- Chance d'obtenir un trait directement en ouvrant une relique.
Traits.HatchChance = 0.35

function Traits.get(id: string?): Trait?
	if id == nil then
		return nil
	end
	return Traits.List[id]
end

function Traits.totalWeight(): number
	local total = 0
	for _, trait in Traits.List do
		total += trait.weight
	end
	return total
end

-- Tire un trait au hasard (pondéré). `luck` > 1 augmente les chances des traits rares.
function Traits.roll(rng: Random, luck: number?): string
	local factor = luck or 1
	local weights = {}
	local total = 0
	for _, id in Traits.Order do
		local trait = Traits.List[id]
		local weight = trait.weight * (trait.tier >= 3 and factor or 1)
		weights[id] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for _, id in Traits.Order do
		roll -= weights[id]
		if roll <= 0 then
			return id
		end
	end
	return "vigueur1"
end

-- Probabilité (en %) d'un trait, pour l'affichage.
function Traits.chance(id: string): number
	local trait = Traits.List[id]
	return trait and (trait.weight / Traits.totalWeight() * 100) or 0
end

return Traits
