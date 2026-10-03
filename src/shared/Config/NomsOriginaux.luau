-- Reconnaissance automatique des modèles de la Boîte à outils de Studio.
--
-- Insère un perso depuis la Boîte à outils (ex. « Kid Naruto ») n'importe où dans Workspace,
-- puis enregistre le fichier : au lancement, le jeu reconnaît le nom du modèle et l'utilise
-- à la place du perso intégré correspondant (ici Maruto). Pas besoin de le déplacer ni de le
-- renommer.
--
-- names    : mots cherchés dans le nom du modèle (en minuscules, sans accents)
-- variants : mots qui désignent une évolution (★★ = 2, ★★★ = 3)
-- Les mots les plus longs sont testés en premier ; ajoute ici tes propres noms si besoin.

local NomsOriginaux = {}

NomsOriginaux.List = {
	-- Village Ninja
	{ id = "ninja_maruto", names = { "naruto" }, variants = { [2] = { "sage", "ermite", "sennin" }, [3] = { "kurama", "kyubi", "kyuubi", "baryon", "nine tail", "chakra mode" } } },
	{ id = "ninja_sasuki", names = { "sasuke" }, variants = { [2] = { "curse mark", "marque maudite" }, [3] = { "rinnegan", "susanoo" } } },
	{ id = "ninja_sakoura", names = { "sakura" } },
	{ id = "ninja_kakashu", names = { "kakashi" } },
	{ id = "ninja_itochi", names = { "itachi" } },
	{ id = "ninja_shikamaro", names = { "shikamaru" } },
	{ id = "ninja_rokli", names = { "rock lee", "rocklee" } },
	{ id = "ninja_konohamaro", names = { "konohamaru" } },
	{ id = "ninja_kourama", names = { "kurama", "kyubi", "kyuubi", "nine tails" } },
	{ id = "ninja_kabouto", names = { "kabuto" } },
	{ id = "ninja_zabouza", names = { "zabuza" } },
	{ id = "ninja_son", names = { "sound ninja", "ninja du son" } },
	-- Académie Occulte
	{ id = "occ_goju", names = { "gojo", "satoru" }, variants = { [3] = { "unsealed", "no blindfold", "sans bandeau" } } },
	{ id = "occ_sukana", names = { "sukuna" } },
	{ id = "occ_yuzi", names = { "yuji", "itadori" } },
	{ id = "occ_megumo", names = { "megumi", "fushiguro" } },
	{ id = "occ_nobora", names = { "nobara", "kugisaki" } },
	{ id = "occ_mako", names = { "maki", "zenin" } },
	{ id = "occ_inumako", names = { "inumaki", "toge" } },
	{ id = "occ_toudo", names = { "todo", "aoi todo" } },
	{ id = "occ_jogou", names = { "jogo" } },
	{ id = "occ_mahitto", names = { "mahito" } },
	{ id = "occ_kenjakou", names = { "kenjaku", "geto", "getou" } },
	{ id = "occ_fleau", names = { "cursed spirit", "fleau" } },
	-- Planète des Guerriers
	{ id = "sai_goko", names = { "goku", "kakarot" }, variants = { [2] = { "ssj", "super saiyan", "super sayan" }, [3] = { "ultra instinct", "blue", "ssj3", "ssjb" } } },
	{ id = "sai_vejeta", names = { "vegeta" } },
	{ id = "sai_gohon", names = { "gohan" } },
	{ id = "sai_piccola", names = { "piccolo" } },
	{ id = "sai_krilin", names = { "krillin", "krilin" } },
	{ id = "sai_yamcho", names = { "yamcha" } },
	{ id = "sai_c81", names = { "android 18", "c18", "c-18" } },
	{ id = "sai_beeros", names = { "beerus", "beerus sama", "bills" } },
	{ id = "sai_freezo", names = { "frieza", "freezer", "freeza" } },
	{ id = "sai_celjr", names = { "cell jr", "cell junior" } },
	{ id = "sai_saibamon", names = { "saibaman", "saibamen" } },
	{ id = "sai_soldat", names = { "frieza soldier", "frieza force", "soldat de freezer" } },
	-- Grand Océan
	{ id = "oce_loffy", names = { "luffy", "monkey d" }, variants = { [2] = { "gear 4", "gear4", "snakeman", "boundman" }, [3] = { "gear 5", "gear5", "nika", "sun god" } } },
	{ id = "oce_zoru", names = { "zoro" } },
	{ id = "oce_sanjo", names = { "sanji" } },
	{ id = "oce_nomi", names = { "nami" } },
	{ id = "oce_usupp", names = { "usopp", "sogeking" } },
	{ id = "oce_buggi", names = { "buggy" } },
	{ id = "oce_kobi", names = { "koby", "coby" } },
	{ id = "oce_shonks", names = { "shanks" } },
	{ id = "oce_arlang", names = { "arlong" } },
	{ id = "oce_akaino", names = { "akainu", "sakazuki" } },
	-- Ère des Pourfendeurs
	{ id = "pou_tanjiru", names = { "tanjiro" }, variants = { [3] = { "sun breathing", "hinokami", "demon slayer mark" } } },
	{ id = "pou_nezoko", names = { "nezuko" } },
	{ id = "pou_zenitso", names = { "zenitsu" } },
	{ id = "pou_inosoke", names = { "inosuke" } },
	{ id = "pou_rengoko", names = { "rengoku" } },
	{ id = "pou_kanoa", names = { "kanao" } },
	{ id = "pou_genyo", names = { "genya" } },
	{ id = "pou_yoriichu", names = { "yoriichi" } },
	{ id = "pou_akazo", names = { "akaza" } },
	{ id = "pou_ruy", names = { "rui" } },
	{ id = "pou_enmo", names = { "enmu" } },
}

local ACCENTS = { ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["à"] = "a", ["â"] = "a", ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["û"] = "u", ["ù"] = "u", ["ç"] = "c" }

local function normalize(text: string): string
	local lower = string.lower(text)
	for accent, plain in ACCENTS do
		lower = string.gsub(lower, accent, plain)
	end
	return " " .. string.gsub(lower, "[_%-%.]", " ") .. " "
end

-- Liste (mot, entrée) triée du mot le plus long au plus court (à égalité, dans l'ordre de la liste).
local index = {}
for _, entry in NomsOriginaux.List do
	for _, name in entry.names do
		table.insert(index, { word = name, entry = entry, order = #index })
	end
end
table.sort(index, function(a, b)
	if #a.word ~= #b.word then
		return #a.word > #b.word
	end
	return a.order < b.order
end)

local function contains(haystack: string, word: string): boolean
	-- Mot entier (pour que « rui » ne corresponde pas à « bruit »).
	local start = 1
	while true do
		local i, j = string.find(haystack, word, start, true)
		if not i then
			return false
		end
		local before = string.sub(haystack, i - 1, i - 1)
		local after = string.sub(haystack, j + 1, j + 1)
		if not string.match(before, "%w") and not string.match(after, "%w") then
			return true
		end
		start = j + 1
	end
end

local function variantOf(entry, text: string): number?
	for _, stars in { 3, 2 } do
		for _, word in (entry.variants and entry.variants[stars]) or {} do
			if contains(text, word) then
				return stars
			end
		end
	end
	return nil
end

-- Renvoie la clé de modèle ("ninja_maruto", "ninja_maruto_2"...) qui correspond à un nom, ou nil.
-- Un perso dont l'évolution est nommée l'emporte (« Naruto Kurama Mode » = Maruto ★★★, pas Kourama).
function NomsOriginaux.match(modelName: string): string?
	local text = normalize(modelName)
	local first
	for _, item in index do
		if contains(text, item.word) then
			local stars = variantOf(item.entry, text)
			if stars then
				return item.entry.id .. "_" .. stars
			end
			first = first or item.entry.id
		end
	end
	return first
end

return NomsOriginaux
