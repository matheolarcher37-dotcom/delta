-- Épées du Forgeron (stand au centre du hub). Le joueur commence avec l'Épée Rouillée.
-- damage : dégâts par coup · cooldown : secondes entre deux coups · range : portée (studs)
-- fx : effet visuel du coup ("slash", "wind", "lightning", "flame", "mist", "shadow", "ice")
-- look : apparence construite par SwordBuilder. style = forme propre à chaque épée (garde, lame,
--   poignée, ornements, fourreau et effet permanent). L'effet s'intensifie avec le rang de l'épée.
--   blade / bevel = plat et biseau (tranchant) de la lame · guard = garde · hilt = tressage
--   grip = poignée · accent = ornements · gem = gemme · trail / trail2 = traînée de coup
--   edge = fil du tranchant · aura = particules · sheath = fourreau (épée rangée à la hanche ou au dos)
--   effectName = nom court de l'effet affiché au Forgeron

local rgb = Color3.fromRGB

local Swords = {}

Swords.List = {
	{
		id = "rouillee",
		name = "Épée Rouillée",
		description = "Une vieille lame toute émoussée. C'est un début...",
		price = 0,
		damage = 6,
		cooldown = 0.6,
		range = 7,
		fx = "slash",
		look = {
			style = "rusty",
			effectName = "Entaille",
			length = 3.2,
			width = 0.32,
			blade = rgb(128, 108, 92),
			bevel = rgb(168, 148, 126),
			material = "CorrodedMetal",
			guard = rgb(96, 82, 70),
			hilt = rgb(176, 152, 112),
			grip = rgb(84, 56, 38),
			accent = rgb(150, 80, 42),
			trail = rgb(220, 210, 200),
			trail2 = rgb(150, 130, 110),
			aura = rgb(150, 92, 52),
			sheath = rgb(92, 62, 40),
			features = "Garde droite tordue, lame ébréchée et piquée de rouille, poignée rafistolée avec des bandes de tissu.",
		},
	},
	{
		id = "acier",
		name = "Lame d'Acier",
		description = "Solide et bien équilibrée.",
		price = 1500,
		damage = 18,
		cooldown = 0.55,
		range = 7.5,
		fx = "slash",
		look = {
			style = "steel",
			effectName = "Reflets",
			length = 3.8,
			width = 0.34,
			blade = rgb(192, 198, 210),
			bevel = rgb(228, 233, 242),
			material = "Metal",
			guard = rgb(176, 182, 194),
			hilt = rgb(52, 32, 24),
			grip = rgb(96, 58, 38),
			accent = rgb(222, 178, 72),
			gem = rgb(200, 30, 40),
			trail = rgb(235, 240, 255),
			trail2 = rgb(150, 190, 255),
			aura = rgb(255, 255, 255),
			sheath = rgb(86, 52, 34),
			features = "Quillons courbés terminés par des boules d'or, gouttière centrale, poinçon du forgeron, pommeau en roue serti d'un rubis.",
		},
	},
	{
		id = "vent",
		name = "Katana du Vent",
		description = "Chaque coup soulève une rafale.",
		price = 12000,
		damage = 55,
		cooldown = 0.5,
		range = 8,
		fx = "wind",
		look = {
			style = "wind",
			effectName = "Rafale",
			length = 4.4,
			width = 0.24,
			curve = 2.6,
			blade = rgb(200, 212, 224),
			bevel = rgb(238, 248, 250),
			material = "Metal",
			guard = rgb(40, 46, 56),
			hilt = rgb(46, 178, 186),
			grip = rgb(236, 232, 220),
			accent = rgb(222, 178, 72),
			trail = rgb(120, 255, 230),
			trail2 = rgb(220, 255, 250),
			edge = rgb(150, 255, 240),
			aura = rgb(170, 255, 240),
			sheath = rgb(24, 70, 78),
			features = "Tsuba ajourée cerclée de turquoise, tsuka-ito en losanges, gorge creusée, fil bleuté et ruban qui flotte au vent.",
		},
	},
	{
		id = "foudre",
		name = "Lame de Foudre",
		description = "La foudre jaillit à chaque entaille.",
		price = 60000,
		damage = 160,
		cooldown = 0.5,
		range = 8.5,
		fx = "lightning",
		look = {
			style = "thunder",
			effectName = "Éclairs",
			length = 4.6,
			width = 0.26,
			curve = 2.4,
			blade = rgb(214, 216, 226),
			bevel = rgb(255, 248, 205),
			material = "Metal",
			guard = rgb(255, 200, 40),
			hilt = rgb(255, 204, 36),
			grip = rgb(38, 38, 54),
			accent = rgb(255, 214, 70),
			trail = rgb(255, 235, 80),
			trail2 = rgb(255, 255, 230),
			edge = rgb(255, 240, 90),
			aura = rgb(255, 236, 110),
			sheath = rgb(30, 30, 44),
			features = "Hamon en éclair jaune, tsuba en étoile de foudre, tsuka noire tressée d'or et pompon. Des arcs électriques courent sur la lame.",
		},
	},
	{
		id = "solaire",
		name = "Lame Solaire",
		description = "Une lame rougeoyante qui brûle les démons.",
		price = 250000,
		damage = 420,
		cooldown = 0.48,
		range = 9,
		fx = "flame",
		look = {
			style = "sun",
			effectName = "Flammes",
			length = 4.8,
			width = 0.28,
			curve = 2.2,
			blade = rgb(168, 38, 30),
			bevel = rgb(255, 140, 64),
			material = "Metal",
			guard = rgb(176, 40, 24),
			hilt = rgb(196, 30, 30),
			grip = rgb(242, 236, 224),
			accent = rgb(255, 170, 50),
			trail = rgb(255, 140, 40),
			trail2 = rgb(255, 230, 120),
			edge = rgb(255, 200, 80),
			aura = rgb(255, 150, 40),
			sheath = rgb(120, 22, 18),
			features = "Lame cramoisie léchée de flammes, inscription gravée, tsuba en soleil de flammes, tsuka rouge et blanche. Elle brûle en permanence.",
		},
	},
	{
		id = "brume",
		name = "Couperet de la Brume",
		description = "Un énorme couperet qui fend tout sur son passage.",
		price = 900000,
		damage = 1100,
		cooldown = 0.7,
		range = 11,
		fx = "mist",
		look = {
			style = "mist",
			effectName = "Brume",
			length = 5.4,
			width = 1.3,
			blade = rgb(148, 158, 172),
			bevel = rgb(232, 238, 246),
			material = "Metal",
			guard = rgb(70, 74, 84),
			hilt = rgb(222, 212, 186),
			grip = rgb(62, 44, 34),
			accent = rgb(86, 92, 104),
			trail = rgb(200, 230, 255),
			trail2 = rgb(240, 250, 255),
			aura = rgb(215, 232, 245),
			sheath = rgb(60, 44, 34),
			features = "Couperet géant avec le trou rond au bout et l'encoche au dos, dos renforcé, longue poignée bandée. Une brume froide l'enveloppe.",
		},
	},
	{
		id = "abysses",
		name = "Lame des Abysses",
		description = "Forgée dans les ténèbres, elle dévore la lumière.",
		price = 3000000,
		damage = 3000,
		cooldown = 0.45,
		range = 10,
		fx = "shadow",
		look = {
			style = "abyss",
			effectName = "Fumée noire",
			length = 5,
			width = 0.5,
			blade = rgb(36, 30, 48),
			bevel = rgb(84, 62, 112),
			material = "Metal",
			guard = rgb(66, 56, 82),
			hilt = rgb(170, 70, 255),
			grip = rgb(30, 24, 36),
			accent = rgb(170, 70, 255),
			trail = rgb(150, 60, 255),
			trail2 = rgb(60, 16, 100),
			edge = rgb(170, 70, 255),
			aura = rgb(60, 16, 90),
			sheath = rgb(26, 22, 32),
			features = "Lame d'obsidienne dentelée parcourue d'une veine violette et de runes, garde à cornes avec un œil démoniaque, chaîne au pommeau.",
		},
	},
	{
		id = "celeste",
		name = "Épée Céleste",
		description = "L'arme des légendes : elle gèle le temps lui-même.",
		price = 12000000,
		damage = 8000,
		cooldown = 0.42,
		range = 11,
		fx = "ice",
		look = {
			style = "celestial",
			effectName = "Étoiles",
			length = 5.4,
			width = 0.45,
			blade = rgb(200, 226, 255),
			bevel = rgb(238, 247, 255),
			material = "Glass",
			guard = rgb(255, 215, 90),
			hilt = rgb(255, 215, 90),
			grip = rgb(242, 242, 252),
			accent = rgb(255, 215, 90),
			gem = rgb(120, 210, 255),
			trail = rgb(140, 220, 255),
			trail2 = rgb(255, 255, 255),
			edge = rgb(160, 230, 255),
			aura = rgb(170, 230, 255),
			sheath = rgb(236, 238, 248),
			features = "Lame de cristal à canal de lumière et étoiles d'or, garde en ailes d'ange, gemme et auréole, ruban bleu. Une neige d'étoiles l'entoure.",
		},
	},
}

Swords.ById = {}
for index, sword in Swords.List do
	sword.index = index
	Swords.ById[sword.id] = sword
end

Swords.Starter = "rouillee"
Swords.CritChance = 0.1

function Swords.get(id: string?)
	return id and Swords.ById[id] or nil
end

-- Intensité de l'effet permanent (0 pour la première épée, 1 pour la dernière).
function Swords.power(sword): number
	local count = #Swords.List
	if not sword or not sword.index or count <= 1 then
		return 0
	end
	return (sword.index - 1) / (count - 1)
end

return Swords
