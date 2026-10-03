-- Épées du Forgeron (stand au centre du hub). Le joueur commence avec l'Épée Rouillée.
-- damage : dégâts par coup · cooldown : secondes entre deux coups · range : portée (studs)
-- fx : effet visuel du coup ("slash", "wind", "lightning", "flame", "mist", "shadow", "ice")

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
			style = "classic",
			length = 3.2,
			width = 0.32,
			blade = rgb(150, 120, 95),
			material = "CorrodedMetal",
			guard = rgb(90, 70, 55),
			hilt = rgb(110, 75, 50),
			trail = rgb(220, 210, 200),
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
			style = "classic",
			length = 3.8,
			width = 0.34,
			blade = rgb(205, 210, 220),
			material = "Metal",
			guard = rgb(170, 140, 70),
			hilt = rgb(70, 45, 35),
			trail = rgb(235, 240, 255),
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
			style = "katana",
			length = 4.4,
			width = 0.24,
			blade = rgb(225, 240, 245),
			material = "Metal",
			guard = rgb(40, 40, 50),
			hilt = rgb(60, 190, 200),
			trail = rgb(120, 255, 230),
			edge = rgb(150, 255, 240),
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
			style = "katana",
			length = 4.6,
			width = 0.26,
			blade = rgb(250, 240, 180),
			material = "Metal",
			guard = rgb(255, 200, 40),
			hilt = rgb(40, 40, 60),
			trail = rgb(255, 235, 80),
			edge = rgb(255, 240, 90),
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
			style = "katana",
			length = 4.8,
			width = 0.28,
			blade = rgb(255, 120, 60),
			material = "Metal",
			guard = rgb(255, 90, 30),
			hilt = rgb(70, 20, 20),
			trail = rgb(255, 140, 40),
			edge = rgb(255, 200, 80),
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
			style = "cleaver",
			length = 5.4,
			width = 1.3,
			blade = rgb(190, 200, 210),
			material = "Metal",
			guard = rgb(60, 60, 70),
			hilt = rgb(80, 60, 50),
			trail = rgb(200, 230, 255),
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
			style = "jagged",
			length = 5,
			width = 0.5,
			blade = rgb(30, 25, 40),
			material = "Metal",
			guard = rgb(90, 30, 140),
			hilt = rgb(25, 20, 30),
			trail = rgb(150, 60, 255),
			edge = rgb(170, 70, 255),
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
			style = "holy",
			length = 5.4,
			width = 0.45,
			blade = rgb(235, 245, 255),
			material = "Glass",
			guard = rgb(255, 215, 90),
			hilt = rgb(240, 240, 255),
			trail = rgb(140, 220, 255),
			edge = rgb(160, 230, 255),
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

return Swords
