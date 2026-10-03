-- Auras (mutations) : rares variantes visuelles qui multiplient la puissance.
-- Inspirées des poulets "électriques" et "néant" de Grow a Chicken Fighter.

export type Aura = {
	id: string,
	name: string,
	color: Color3,
	multiplier: number,
	chance: number, -- probabilité à l'ouverture d'une relique (0-1)
	effect: string, -- type d'effet visuel côté client
}

local Auras = {}

Auras.List = {
	foudre = {
		id = "foudre",
		name = "Foudre",
		color = Color3.fromRGB(255, 230, 40),
		multiplier = 1.5,
		chance = 0.04,
		effect = "lightning",
	},
	givre = {
		id = "givre",
		name = "Givre",
		color = Color3.fromRGB(120, 230, 255),
		multiplier = 1.6,
		chance = 0.03,
		effect = "frost",
	},
	flamme = {
		id = "flamme",
		name = "Flamme",
		color = Color3.fromRGB(255, 120, 30),
		multiplier = 1.75,
		chance = 0.025,
		effect = "fire",
	},
	neant = {
		id = "neant",
		name = "Néant",
		color = Color3.fromRGB(170, 60, 255),
		multiplier = 2,
		chance = 0.015,
		effect = "cubes",
	},
	dore = {
		id = "dore",
		name = "Doré",
		color = Color3.fromRGB(255, 200, 60),
		multiplier = 3,
		chance = 0.006,
		effect = "gold",
	},
	arcenciel = {
		id = "arcenciel",
		name = "Arc-en-ciel",
		color = Color3.fromRGB(255, 120, 200),
		multiplier = 5,
		chance = 0.0015,
		effect = "rainbow",
	},
} :: { [string]: Aura }

-- Ordre de tirage : du plus rare au plus commun.
Auras.RollOrder = { "arcenciel", "dore", "neant", "flamme", "givre", "foudre" }

function Auras.get(id: string?): Aura?
	if id == nil then
		return nil
	end
	return Auras.List[id]
end

-- Tire une aura (ou nil). `luck` multiplie toutes les chances.
function Auras.roll(rng: Random, luck: number?): string?
	local factor = luck or 1
	for _, id in Auras.RollOrder do
		if rng:NextNumber() < Auras.List[id].chance * factor then
			return id
		end
	end
	return nil
end

return Auras
