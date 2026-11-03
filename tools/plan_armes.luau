--!nocheck
-- Plan d'import des armes du fichier « perso.rbxl » pour le Forgeron (v3.5) :
--   lune run tools/import_armes.luau perso.rbxl tools/plan_armes.luau
--
-- source    : l'arme dans le Workspace (« Dossier > Modèle ») ;
-- repere    : pièce dont le repère sert à décrire la prise ;
-- prise     : point tenu par la main (dans ce repère) ; lame : direction de la lame ;
-- epaisseur : direction de l'épaisseur de la lame (le plat lui est perpendiculaire) ;
-- longueur  : longueur de l'arme dans le jeu ; debutLame : fin de la poignée (avant mise à l'échelle) ;
-- section   : largeur et épaisseur de la pièce d'une arme en maillage de fichier (sa vraie forme).

-- Sabres de Zoro : poignées d'outil classiques (Zoro les tient ainsi dans son modèle : la main
-- serre la pièce à z = -1,66, la lame part vers +Z).
local function sabre(id: string, source: string)
	return {
		id = id,
		source = source,
		repere = source,
		prise = { 0, 0, -1.66 },
		lame = { 0, 0, 1 },
		epaisseur = { 0, 1, 0 },
		longueur = 4.9,
		debutLame = -0.9,
		section = { 0.32, 0.16 },
	}
end

return {
	sabre("zoro_wado", "Wado Ichimonji"),
	sabre("zoro_shusui", "Shuusui"),
	sabre("zoro_kitetsu", "Santa Kitetsu"),
	sabre("zoro_yubashiri", "Yubarashi"),
	-- Tensa Zangetsu : dans la main droite d'Ichigo (lame vers l'avant, de chant)
	{
		id = "tensa_zangetsu",
		source = "Ichigo Rage > Tensa Zangetsu > Zangetsu",
		repere = "Ichigo Rage >  > Right Arm",
		prise = { 0.02, -1, -0.15 },
		lame = { 0, 0, -1 },
		epaisseur = { 1, 0, 0 },
		longueur = 5.2,
		debutLame = -0.75,
	},
	-- Éventail de guerre de Madara : poignée gainée (y de 0,4 à 2,9), éventail au bout (vers +Y)
	{
		id = "gunbai_madara",
		source = "madaras gunbai",
		repere = "madaras gunbai > handle > Union",
		prise = { 0, 1.6, 0 },
		lame = { 0, 1, 0 },
		epaisseur = { 1, 0, 0 },
		longueur = 5.4,
		debutLame = -1.4,
	},
}
