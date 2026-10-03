-- Avatars du catalogue Roblox (OPTIONNEL).
--
-- Par défaut, chaque perso est un avatar R6 "peint" construit par le jeu (CharacterBuilder).
-- Tu peux aussi lui donner de VRAIS objets du catalogue Roblox (cheveux, vêtements, visage),
-- comme dans les jeux d'animé récents. Pour ça, ajoute une entrée ci-dessous avec les identifiants
-- (le nombre dans l'adresse de l'objet sur roblox.com/catalog/XXXXXXXX/...).
--
-- Exemple :
--   ninja_maruto = {
--       Shirt = 1234567890, -- "Classic Shirt" (haut)
--       Pants = 1234567891, -- "Classic Pants" (pantalon)
--       Face = 1234567892, -- visage (décalque)
--       Hair = { 1234567893 }, -- un ou plusieurs accessoires de cheveux
--       Accessories = { 1234567894 }, -- chapeau, bandeau, lunettes... (n'importe quel accessoire)
--       Skin = Color3.fromRGB(255, 216, 180), -- facultatif (sinon la peau du look)
--   },
--   ninja_maruto_2 = { ... }, -- facultatif : version ★★ (sinon la version ci-dessus est gardée)
--
-- Les ennemis marchent pareil (ex. ninja_kourama = { ... }).
-- Astuce : tu peux aussi faire ton perso à la main dans Studio et le mettre dans
-- Workspace > GaleriePersos > ModelesPersos (voir le README) : il remplace alors le perso intégré.

local Avatars = {}

Avatars.List = {
	-- Ajoute tes avatars ici.
}

return Avatars
