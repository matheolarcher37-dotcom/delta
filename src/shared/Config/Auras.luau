-- Ancien nom des MUTATIONS (v3.2) : les « auras » (Foudre, Givre, Flamme, Néant, Doré,
-- Arc-en-ciel) font maintenant partie des mutations (Or, Diamant, Sakura, Angélique...).
-- Ce module reste pour les scripts qui utilisent encore `Auras` : il renvoie la même liste que
-- Config/Mutations.luau (même API : List, RollOrder, get, roll). Modifie les mutations là-bas.

export type Aura = {
	id: string,
	name: string,
	color: Color3,
	multiplier: number,
	chance: number, -- probabilité sur un perso tiré (0-1)
	effect: string, -- type d'effet visuel côté client
}

local Mutations = require(script.Parent.Mutations)

local Auras = {}

Auras.List = Mutations.List :: { [string]: any }
Auras.RollOrder = Mutations.RollOrder

function Auras.get(id: string?): Aura?
	return Mutations.get(id)
end

-- Tire une mutation (ou nil). `luck` multiplie toutes les chances.
function Auras.roll(rng: Random, luck: number?): string?
	return Mutations.roll(rng, luck)
end

return Auras
