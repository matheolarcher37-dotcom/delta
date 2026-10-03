-- Raretés des personnages : couleurs, puissance de base, valeur de revente.

export type Rarity = {
	id: string,
	name: string,
	order: number,
	color: Color3,
	gradient: { Color3 },
	basePower: number,
	sellValue: number,
}

local Rarities = {}

Rarities.List = {
	common = {
		id = "common",
		name = "Commun",
		order = 1,
		color = Color3.fromRGB(176, 186, 197),
		gradient = { Color3.fromRGB(210, 218, 226), Color3.fromRGB(140, 152, 166) },
		basePower = 10,
		sellValue = 40,
	},
	rare = {
		id = "rare",
		name = "Rare",
		order = 2,
		color = Color3.fromRGB(64, 160, 255),
		gradient = { Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 110, 230) },
		basePower = 25,
		sellValue = 400,
	},
	epic = {
		id = "epic",
		name = "Épique",
		order = 3,
		color = Color3.fromRGB(176, 92, 255),
		gradient = { Color3.fromRGB(214, 140, 255), Color3.fromRGB(122, 50, 220) },
		basePower = 60,
		sellValue = 3500,
	},
	legendary = {
		id = "legendary",
		name = "Légendaire",
		order = 4,
		color = Color3.fromRGB(255, 190, 40),
		gradient = { Color3.fromRGB(255, 226, 90), Color3.fromRGB(255, 140, 20) },
		basePower = 150,
		sellValue = 25000,
	},
	mythic = {
		id = "mythic",
		name = "Mythique",
		order = 5,
		color = Color3.fromRGB(255, 60, 110),
		gradient = { Color3.fromRGB(255, 110, 150), Color3.fromRGB(200, 20, 80) },
		basePower = 400,
		sellValue = 150000,
	},
	crossover = {
		id = "crossover",
		name = "Crossover",
		order = 6,
		color = Color3.fromRGB(80, 255, 220),
		gradient = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(90, 120, 255), Color3.fromRGB(255, 90, 230) },
		basePower = 1000,
		sellValue = 600000,
	},
} :: { [string]: Rarity }

Rarities.Order = { "common", "rare", "epic", "legendary", "mythic", "crossover" }

function Rarities.get(id: string): Rarity
	return Rarities.List[id] or Rarities.List.common
end

return Rarities
