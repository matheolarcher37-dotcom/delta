--!nocheck
-- Test de fumée hors Roblox (avec Lune) : charge le .rbxl construit par Rojo, exécute les
-- modules de construction (persos, reliques, carte, décors, bases) et vérifie les formules.
-- Usage :  rojo build default.project.json -o build/AnimeTycoon.rbxl && lune run tests/smoke.luau

local Harness = require("./harness")

local game = Harness.game
local requireModule = Harness.require
local find = Harness.find
local test = Harness.test
local countParts = Harness.countParts
local Enum = Harness.roblox.Enum
local fakeSignal = Harness.newSignal()

local Shared = find("ReplicatedStorage.Shared")
local Characters = requireModule(Shared.Config.Characters)
local Universes = requireModule(Shared.Config.Universes)
local Formulas = requireModule(Shared.Modules.Formulas)
local Economy = requireModule(Shared.Config.Economy)
local CharacterBuilder = requireModule(Shared.Modules.CharacterBuilder)
local RelicBuilder = requireModule(Shared.Modules.RelicBuilder)

test("Formules : formatNumber", function()
	local cases = { [0] = "0", [999] = "999", [1000] = "1 k", [1500] = "1,5 k", [12345] = "12,3 k", [100000] = "100 k", [2500000] = "2,5 M", [1e9] = "1 B" }
	for n, expected in cases do
		local got = Formulas.formatNumber(n)
		assert(got == expected, "formatNumber(" .. n .. ") = " .. got .. " (attendu " .. expected .. ")")
	end
	assert(Formulas.formatTime(754) == "12:34", Formulas.formatTime(754))
end)

test("Univers : persos, ennemis, reliques cohérents", function()
	for _, universe in Universes.List do
		assert(#universe.characters >= 6, universe.id .. " : pas assez de persos")
		for _, id in universe.characters do
			local def = Characters.get(id)
			assert(def, "perso manquant " .. id)
			assert(def.universe == universe.id, id .. " n'est pas dans " .. universe.id)
		end
		for _, id in universe.enemies do
			assert(Characters.Enemies[id], "ennemi manquant " .. id)
		end
		assert(Characters.Enemies[universe.boss], "boss manquant " .. universe.boss)
		for _, relic in universe.relics do
			local total = 0
			for rarity, weight in relic.odds do
				local found = false
				for _, id in universe.characters do
					if Characters.get(id).rarity == rarity then
						found = true
					end
				end
				assert(found, relic.id .. " : aucune rareté " .. rarity .. " dans " .. universe.id)
				total += weight
			end
			assert(math.abs(total - 100) < 0.01, relic.id .. " : probabilités = " .. total)
		end
	end
end)

test("Formules : puissance, évolution, fusion", function()
	local entry = { id = "ninja_maruto", level = 30, xp = 0, stars = 1 }
	assert(Formulas.power(entry) > 0)
	local cost = Formulas.evolutionCost(entry)
	assert(cost and cost.stars == 2 and cost.materials.chakra, "coût d'évolution")
	local fusion = { id = "fusion", fusion = { a = "ninja_maruto", b = "occ_goju" }, level = 1, xp = 0, stars = 1 }
	local desc = Formulas.describe(fusion)
	assert(desc.name == "Renard de l'Infini", desc.name)
	local fcost = Formulas.evolutionCost(fusion)
	assert(fcost.materials.chakra and fcost.materials.maudite, "coût fusion")
	local stats = Formulas.upgradeStats({ autel2 = true, equipe4 = true })
	assert(stats.incubators == 2 and stats.team == 4, "upgradeStats")
end)

test("Arbre de compétences : 40-60 nœuds hexagonaux cohérents", function()
	local SkillTree = requireModule(Shared.Config.SkillTree)
	assert(#SkillTree.Nodes >= 40 and #SkillTree.Nodes <= 60, "nombre de nœuds : " .. #SkillTree.Nodes)
	local cells = {}
	for _, n in SkillTree.Nodes do
		local key = n.q .. "," .. n.r
		assert(not cells[key], "deux nœuds sur la même case : " .. key)
		cells[key] = n.id
		assert(n.cost >= 0 and n.currency == "Coins", "coût invalide : " .. n.id)
		assert(n.effect and n.effect.stat and SkillTree.Base[n.effect.stat] ~= nil, "effet invalide : " .. n.id)
		assert(SkillTree.Branches[n.branch], "branche inconnue : " .. n.id)
		for _, req in n.requires do
			local r = SkillTree.get(req)
			assert(r, n.id .. " : prérequis inconnu " .. req)
			assert(SkillTree.distance(n.q, n.r, r.q, r.r) == 1, n.id .. " n'est pas voisin de " .. req)
			assert(r.order < n.order, n.id .. " défini avant son prérequis " .. req)
		end
	end
	local all = {}
	for _, n in SkillTree.Nodes do
		all[n.id] = true
	end
	local max = SkillTree.stats(all)
	assert(max.rollsPerPull == 3, "multi-tirage maximum : " .. max.rollsPerPull)
	assert(max.autoRoll == true and max.luck > 3 and max.rollCooldown >= SkillTree.Limits.rollCooldown, "statistiques maximales")
	local none = SkillTree.stats({})
	assert(none.rollsPerPull == 1 and none.luck == 1 and none.autoRoll == false, "statistiques de départ")
	-- Coûts croissants le long de chaque branche.
	for _, n in SkillTree.Nodes do
		for _, req in n.requires do
			assert(SkillTree.get(req).cost <= n.cost, n.id .. " coûte moins que son prérequis")
		end
	end
end)

test("Machine ROULER : probabilités, prix, pitié", function()
	for _, luck in { 1, 2.5, 10, 35 } do
		local odds = Formulas.rollOdds(luck)
		local total = 0
		for _, id in Economy.RollOrder do
			assert(odds[id] and odds[id] >= 0, "probabilité manquante : " .. id)
			total += odds[id]
		end
		assert(math.abs(total - 1) < 1e-6, "total des probabilités ≠ 1 (chance " .. luck .. ")")
		assert(odds.common >= 0.05 - 1e-9, "le Commun doit garder 5 %")
	end
	assert(Formulas.rollOdds(2).legendary > Formulas.rollOdds(1).legendary, "la chance n'augmente pas les Légendaires")
	local last = 0
	for _, id in Economy.RollOrder do
		local price = Formulas.rollPrice(id)
		assert(price > last, "prix non croissants : " .. id)
		last = price
	end
	assert(Formulas.rollPrice("rare", "dore") > Formulas.rollPrice("rare"), "l'aura n'augmente pas le prix")
	-- Ce que la rareté garantit n'est pas facturé une 2e fois : un Secret (aura Arc-en-ciel et
	-- trait de palier 3 garantis) coûte bien le prix annoncé.
	assert(Formulas.rollPrice("secret", "arcenciel", "critique") == Economy.RollRarities.secret.price, "prix du Secret ≠ prix annoncé")
	assert(Formulas.rollPrice("mythic", "arcenciel") < Formulas.rollPrice("secret", "arcenciel", "critique"), "Mythique Arc-en-ciel plus cher qu'un Secret")
	-- Première collecte offerte : seulement jusqu'au Rare.
	assert(Formulas.rollCollectFree({ FirstCollectDone = false }, "rare"), "Rare non offert")
	assert(not Formulas.rollCollectFree({ FirstCollectDone = false }, "legendary"), "Légendaire offert")
	assert(not Formulas.rollCollectFree({ FirstCollectDone = true }, "common"), "2e collecte offerte")
	assert(Formulas.pityThreshold("legendary", 0.7) < Formulas.pityThreshold("legendary", 1), "pitié de l'arbre sans effet")
	assert(#Economy.Upgrades >= 25 and #Economy.Upgrades <= 30, "25 à 30 améliorations attendues")
end)

test("Construction de tous les persos (★1 à ★3)", function()
	local total, maxParts = 0, 0
	for id in Characters.List do
		for stars = 1, 3 do
			local entry = { id = id, level = 50, stars = stars }
			local model = CharacterBuilder.build(Formulas.describe(entry).look, { scale = Formulas.visualScale(entry), humanoid = true, collisionGroup = "Followers" })
			assert(model.PrimaryPart, id .. " sans PrimaryPart")
			local n = countParts(model)
			maxParts = math.max(maxParts, n)
			total += 1
		end
	end
	print(string.format("   %d modèles, max %d pièces par perso", total, maxParts))
end)

test("Persos R6 classiques : proportions, tête, visage, budgets", function()
	local function check(label, look)
		-- proportions à l'échelle 1 (sans la carrure propre des Secrets, `bodyScale`)
		look = table.clone(look)
		look.bodyScale = nil
		look.minScale = nil
		local model = CharacterBuilder.build(look, { scale = 1 })
		local head = model:FindFirstChild("Head")
		assert(head and head.Size.X == 2 and head.Size.Y == 1 and head.Size.Z == 1, label .. " : tête classique 2x1x1 attendue")
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		assert(
			mesh
				and mesh.MeshType.Name == "Head"
				and math.abs(mesh.Scale.Y - 1.25 * (look.headScale and (typeof(look.headScale) == "Vector3" and look.headScale.Y or look.headScale) or 1)) < 1e-4,
			label .. " : maillage Head 1.25 (x headScale)"
		)
		local torso = model:FindFirstChild("Torso")
		assert(torso.Size.X == 2 and torso.Size.Y == 2 and torso.Size.Z == 1, label .. " : torse 2x2x1")
		for _, limb in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local part = model:FindFirstChild(limb)
			assert(part and part.Size.X == 1 and part.Size.Y == 2 and part.Size.Z == 1, label .. " : " .. limb .. " 1x2x1")
		end
		for _, joint in CharacterBuilder.JointNames do
			assert(model:FindFirstChild(joint, true), label .. " : articulation " .. joint)
		end
		local plates, frames, parts, lodFrames, lods = 0, 0, 0, 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				if d.Name == "FacePlate" then
					plates += 1
					assert(d.Transparency == 1 and d:FindFirstChildOfClass("SurfaceGui"), label .. " : plaque du visage")
				end
			elseif d:IsA("Frame") then
				local gui = d:FindFirstAncestorOfClass("SurfaceGui")
				if gui and gui:GetAttribute("LodNear") then
					lodFrames += 1
				else
					frames += 1
				end
			elseif d:IsA("SurfaceGui") and d:GetAttribute("LodNear") then
				lods += 1
				assert(d.MaxDistance > d:GetAttribute("LodNear") and d.ZOffset < 1, label .. " : LOD affiché plus loin et sous la peinture complète")
			end
		end
		assert(lods >= 6, label .. " : niveau de détail intermédiaire attendu (" .. lods .. ")")
		assert(lodFrames <= 160, label .. " : LOD trop lourd (" .. lodFrames .. ")")
		local boar = look.accessories and table.find(look.accessories, "boar_head")
		assert(boar or plates == 6, label .. " : 6 plaques de visage attendues (" .. plates .. ")")
		assert(parts <= 180, label .. " : trop de pièces (" .. parts .. ")")
		assert(frames <= 520, label .. " : trop de Frames (" .. frames .. ")")
		local preview = CharacterBuilder.buildPreview(look)
		local previewParts = 0
		for _, d in preview:GetDescendants() do
			if d:IsA("BasePart") then
				previewParts += 1
			end
			assert(not d:IsA("SurfaceGui"), label .. " : SurfaceGui dans l'aperçu")
		end
		assert(previewParts <= 400, label .. " : aperçu trop lourd (" .. previewParts .. ")")
		return parts, frames, previewParts
	end
	local maxParts, maxFrames, maxPreview = 0, 0, 0
	for id in Characters.List do
		for stars = 1, 3 do
			local p, f, v = check(id .. " ★" .. stars, Formulas.describe({ id = id, level = 1, stars = stars }).look)
			maxParts, maxFrames, maxPreview = math.max(maxParts, p), math.max(maxFrames, f), math.max(maxPreview, v)
		end
	end
	for id, def in Characters.Enemies do
		check(id, def.look)
	end
	print(string.format("   max %d pièces, %d Frames, aperçu %d pièces", maxParts, maxFrames, maxPreview))
end)

test("Construction des ennemis et boss", function()
	for id, def in Characters.Enemies do
		local model = CharacterBuilder.build(def.look, { scale = 4.2, humanoid = true })
		assert(model.PrimaryPart, id)
	end
end)

test("Boss lisibles (liseré, lumières, aura) et variétés des persos", function()
	for id, def in Characters.Enemies do
		if def.look.boss then
			local model = CharacterBuilder.build(def.look, { scale = 4.2, humanoid = true })
			assert(model:FindFirstChildOfClass("Highlight"), id .. " : liseré lumineux (Highlight) attendu")
			local lights, guis = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("PointLight") then
					lights += 1
				elseif d:IsA("SurfaceGui") then
					guis += 1
					assert(d.LightInfluence < 1, id .. " : peinture lisible dans la pénombre")
					assert(d.Name ~= "ShirtFront" or d.PixelsPerStud < 70, id .. " : résolution des peintures adaptée à la taille")
				end
			end
			assert(lights >= 2, id .. " : lumières sur le boss")
			assert(guis > 10, id .. " : tenue peinte")
		end
	end
	-- Les ennemis ordinaires n'ont pas de Highlight (limite de 31 par client)
	local minion = CharacterBuilder.build(Characters.Enemies.sai_saibamon.look, { scale = 1 })
	assert(not minion:FindFirstChildOfClass("Highlight"), "pas de Highlight hors boss")
	local look = Formulas.describe({ id = "sai_goko", level = 1, stars = 1 }).look
	for _, v in { "Or", "Diamant", "Sakura", "Angélique", "Ombre", "Galaxie", "Arc-en-ciel", "dore", "neant" } do
		local model = CharacterBuilder.build(look, { scale = 1 })
		assert(CharacterBuilder.applyVariety(model, v), "variété inconnue : " .. v)
		assert(model:GetAttribute("Variety"), v .. " : attribut Variety")
	end
	local plain = CharacterBuilder.build(look, { scale = 1 })
	assert(not CharacterBuilder.applyVariety(plain, "inconnue"), "variété inconnue refusée")
	-- La fabrique applique la variété tirée de l'unité (options.variety) au modèle et à l'aperçu
	local CharacterFactory = requireModule(Shared.Modules.CharacterFactory)
	local fromUnit = CharacterFactory.build("sai_goko", 1, look, { scale = 1, variety = "Diamant" })
	assert(fromUnit:GetAttribute("Variety") == "diamond", "fabrique : variété de l'unité appliquée")
	local previewV = CharacterFactory.buildPreview("sai_goko", 1, look, "Sakura")
	assert(previewV:GetAttribute("Variety") == "sakura", "fabrique : variété appliquée à l'aperçu")
	local noVariety = CharacterFactory.build("sai_goko", 1, look, { scale = 1 })
	assert(noVariety:GetAttribute("Variety") == nil, "fabrique : pas de variété par défaut")
	-- Reliefs 3D génériques : col fourré de Maruto, ceinture du gi, semelles
	local function named(model, name)
		local n = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				n += 1
			end
		end
		return n
	end
	local maruto = CharacterBuilder.build(Formulas.describe({ id = "ninja_maruto", level = 1, stars = 1 }).look, { scale = 1 })
	assert(named(maruto, "ReliefCollarBack") == 1 and named(maruto, "ReliefCollarFront") == 2, "Maruto : col fourré en relief")
	assert(named(maruto, "ReliefSole") == 2, "Maruto : semelles en relief")
	local reliefs = 0
	for id in Characters.List do
		local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = 1 }).look, { scale = 1 })
		if named(m, "ReliefBelt") > 0 then
			reliefs += 1
		end
		m:Destroy()
	end
	assert(reliefs >= 8, "ceintures en relief sur les persos en gi/uniforme (" .. reliefs .. ")")
	-- Or : peinture re-teintée (pas de voile qui noie les plis), cheveux en or poli, LOD refait
	local goldLook = table.clone(look)
	goldLook.variety = "Or"
	local gold = CharacterBuilder.build(goldLook, { scale = 1 })
	assert(gold:GetAttribute("Variety") == "gold", "une unité Or a l'attribut Variety = gold")
	assert(not gold:FindFirstChild("VarietyTint", true), "Or : plus de voile par-dessus la peinture")
	local foil, lodAfter = false, 0
	for _, d in gold:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Hair" and d.Material == Enum.Material.Foil then
			foil = true
		elseif d:IsA("SurfaceGui") and d:GetAttribute("LodNear") then
			lodAfter += 1
		end
	end
	assert(foil and lodAfter >= 6, "Or : cheveux Foil et LOD présents")
	local shadow = CharacterBuilder.build(look, { scale = 1 })
	CharacterBuilder.applyVariety(shadow, "Ombre")
	local rim = shadow:FindFirstChild("VarietyRim")
	assert(rim and rim:IsA("Highlight") and rim.FillTransparency == 1, "Ombre : liseré violet (contour seul)")
	-- Boss : contour seul, lumière de face blanc chaud
	local ken = CharacterBuilder.build(Characters.Enemies.occ_kenjakou.look, { scale = 4.2 })
	local bossRim = ken:FindFirstChild("BossRim")
	assert(bossRim and bossRim.FillTransparency == 1, "BossRim sans remplissage")
	local key = ken:FindFirstChild("BossKey", true)
	assert(key and key.Color.R > key.Color.B, "lumière de face blanc chaud")
	assert(ken:FindFirstChild("BossFaceLight", true), "lumière douce sous le visage")
	-- Auras d'évolution : particules depuis la surface d'une enveloppe + rayons, plus de plaques
	local ssj = CharacterBuilder.build(Formulas.describe({ id = "sai_brolo", level = 1, stars = 2 }).look, { scale = 1 })
	local beams, surface = 0, false
	for _, d in ssj:GetDescendants() do
		assert(d.Name ~= "AuraFlame", "plus de plaques d'aura")
		if d:IsA("Beam") then
			beams += 1
		elseif d:IsA("ParticleEmitter") and d.ShapeStyle == Enum.ParticleEmitterShapeStyle.Surface then
			surface = true
		end
	end
	assert(beams >= 2 and surface, "aura : 2 rayons et des particules autour de la silhouette")
	-- CHAQUE perso change à CHAQUE étoile (★1 -> ★2 -> ★3) : coiffure, yeux ou pièce de tenue
	-- (une aura seule ne suffit pas), et la silhouette construite change (pièces/effets en plus)
	local STRONG = {
		"hair",
		"hairColor",
		"hairLength",
		"eyes",
		"pupil",
		"eyeGlow",
		"eyeMarks",
		"eyeStyle",
		"top",
		"bottom",
		"outfit",
		"skin",
		"markLarge",
		"curseSpread",
		"nails",
		"armVeins",
	}
	local AURAS = { energy_aura = true, ssj_aura = true, steam = true }
	local ids = {}
	for id in Characters.List do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		for st = 1, 2 do
			local la = Formulas.describe({ id = id, level = 1, stars = st }).look
			local lb = Formulas.describe({ id = id, level = 1, stars = st + 1 }).look
			-- Objets sur mesure (look.props) différents : pièces visibles en plus ou en moins
			local function sig(props)
				local out = {}
				for _, p in props or {} do
					table.insert(out, tostring(p.shape) .. tostring(p.limb) .. tostring(p.at) .. tostring(p.size))
				end
				return table.concat(out, ";")
			end
			local strong = sig(la.props) ~= sig(lb.props)
			for _, k in STRONG do
				if la[k] ~= lb[k] then
					strong = true
				end
			end
			local accA, accB = {}, {}
			for _, a in la.accessories or {} do
				accA[a] = true
			end
			for _, a in lb.accessories or {} do
				accB[a] = true
			end
			for a in accB do
				if not accA[a] and not AURAS[a] then
					strong = true
				end
			end
			for a in accA do
				if not accB[a] and not AURAS[a] then
					strong = true
				end
			end
			assert(strong, id .. " ★" .. st .. " -> ★" .. (st + 1) .. " : coiffure, yeux ou tenue doivent changer")
		end
	end
	for _, id in ids do
		local function names(stars)
			local set = {}
			local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = stars }).look, { scale = 1 })
			-- Signature : noms des pièces et effets + nombre de pièces + boîte englobante arrondie
			local n, top, wide = 0, 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("ParticleEmitter") then
					set[d.Name] = true
				end
				if d:IsA("BasePart") then
					n += 1
					local p = d.CFrame.Position
					top = math.max(top, p.Y + d.Size.Y / 2)
					wide = math.max(wide, math.abs(p.X) + d.Size.X / 2)
				end
			end
			set["#" .. n .. "/" .. math.floor(top * 10) .. "/" .. math.floor(wide * 10)] = true
			return set
		end
		local sets = { names(1), names(2), names(3) }
		for st = 1, 2 do
			local a, b = sets[st], sets[st + 1]
			local changed = false
			for n in b do
				if not a[n] then
					changed = true
				end
			end
			for n in a do
				if not b[n] then
					changed = true
				end
			end
			assert(changed, id .. " ★" .. st .. " -> ★" .. (st + 1) .. " : la silhouette doit changer")
		end
	end
	local withVariety = table.clone(look)
	withVariety.variety = "Angélique"
	local angel = CharacterBuilder.build(withVariety, { scale = 1 })
	assert(angel:FindFirstChild("VarietyHalo"), "auréole de la variété Angélique")
	assert(angel:GetAttribute("Variety") == "angelic", "look.variety appliqué à la construction")
end)

test("Nouveaux persos v3.2, uniformes personnalisés, boss Akaino/Freezo", function()
	local NEW = {
		ninja = { "ninja_hinato", "ninja_jiriya" },
		occulte = { "occ_nanamo", "occ_chosu" },
		saiyan = { "sai_trunk", "sai_brolo" },
		ocean = { "oce_robine", "oce_ase" },
		pourfendeur = { "pou_shinobo", "pou_giyo" },
	}
	local rarities = { common = true, rare = true, epic = true, legendary = true, mythic = true, secret = true }
	for _, universe in Universes.List do
		assert(#universe.characters >= 10, universe.id .. " : au moins 10 persos attendus (" .. #universe.characters .. ")")
		for _, id in NEW[universe.id] or {} do
			assert(table.find(universe.characters, id), id .. " absent des tables de tirage de " .. universe.id)
			local def = Characters.get(id)
			assert(def and def.universe == universe.id and rarities[def.rarity], id .. " : univers ou rareté de base invalide")
		end
	end
	local function partNamed(look, name)
		local model = CharacterBuilder.build(look, { scale = 1 })
		local count = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				count += 1
			end
		end
		return count
	end
	local function look(id)
		return Formulas.describe({ id = id, level = 1, stars = 1 }).look
	end
	assert(partNamed(look("pou_giyo"), "HaoriBack") == 2, "Giyo : haori coupé en deux moitiés")
	assert(partNamed(look("ninja_jiriya"), "OilPlate") == 1, "Jiriya : plaque du bandeau à cornes")
	assert(partNamed(look("oce_ase"), "HatCrown") == 1, "Ase : chapeau de cow-boy")
	assert(partNamed(look("occ_nobora"), "Skirt") == 1, "Nobora : jupe plissée")
	assert(partNamed(look("occ_yuzi"), "HoodCord") == 2, "Yuzi : capuche à cordons")
	local akaino = Characters.Enemies.oce_akaino.look
	assert(partNamed(akaino, "CoatSleeveShell") == 0 and partNamed(akaino, "CoatShoulder") == 0, "Akaino : plus de blocs aux épaules ni de coques de manches")
	assert(partNamed(akaino, "CoatDrape") == 2 and partNamed(akaino, "CoatDrapeFall") == 2, "Akaino : manteau posé sur les épaules (pans fins + retombée)")
	assert(partNamed(akaino, "EpauletteFringe") == 12, "Akaino : épaulettes fines à 6 franges")
	assert(partNamed(akaino, "CoatPan") == 0, "Akaino : plus de panneaux latéraux")
	assert(
		partNamed(akaino, "MagmaSleeve") == 0 and partNamed(akaino, "MagmaFist") == 1 and partNamed(akaino, "MagmaRock") == 5,
		"Akaino : poing de lave ajusté et croûtes de basalte"
	)
	do
		local m = CharacterBuilder.build(akaino, { scale = 1 })
		local fist = m:FindFirstChild("MagmaFist") :: BasePart
		assert(fist.Size.X <= 1.21 and fist.Size.Z <= 1.21, "Akaino : poing pas plus gros que le bras + 0,2")
		local lava = 0
		for _, d in m:FindFirstChild("Right Arm"):GetChildren() do
			if d:IsA("SurfaceGui") and d:GetAttribute("ZTop") then
				lava += 1
				assert(d.ZOffset == 1.5 and d.LightInfluence == 0, "Akaino : lave peinte par-dessus la manche, lumineuse")
			end
		end
		assert(lava == 4, "Akaino : lave peinte sur les 4 faces de l'avant-bras")
		local mesh = m.Head:FindFirstChild("Mesh") :: SpecialMesh
		assert(mesh.Scale.X > 1.25 * 1.1, "Akaino : tête agrandie (headScale)")
		assert(math.abs(m.Head.CFrame.Position.Y - m.Torso.CFrame.Position.Y - 1.5 - 0.6 * 0.13) < 0.01, "Akaino : la tête agrandie monte (le cou reste en place)")
	end
	local freezo = Characters.Enemies.sai_freezo.look
	assert(partNamed(freezo, "GemShoulder") == 2 and partNamed(freezo, "GemShoulderBevel") == 0, "Freezo : épaulières bombées")
	assert(partNamed(freezo, "Chin") == 2 and partNamed(freezo, "BrowRidge") == 2 and partNamed(freezo, "TailTip") == 1, "Freezo : menton, front en V, queue")
	local kenjakou = Characters.Enemies.occ_kenjakou.look
	assert(
		partNamed(kenjakou, "KesaRing") == 0 and partNamed(kenjakou, "KesaKnot") == 1 and partNamed(kenjakou, "KesaTrim") == 0,
		"Kenjakou : nœud de cordon, kesa sans planches en relief"
	)
	do
		local m = CharacterBuilder.build(kenjakou, { scale = 1 })
		assert((m:FindFirstChild("Kesa") :: BasePart).Size.X <= 0.55, "Kenjakou : kesa fin")
	end
	assert(look("occ_megumo").uniformStyle == "spiral", "Megumo : col à bouton spirale")
	-- Coiffures à silhouette propre (cheveux noirs à pointes)
	local hairs = {}
	for _, id in { "sai_goko", "sai_vejeta", "occ_megumo", "sai_brolo", "sai_gohon" } do
		local h = look(id).hair
		assert(not hairs[h], id .. " : même coiffure que " .. tostring(hairs[h]))
		hairs[h] = id
	end
	-- Chaque perso tirable figure dans une table de tirage
	for id in Characters.List do
		local found = false
		for _, universe in Universes.List do
			if table.find(universe.characters, id) then
				found = true
			end
		end
		assert(found, id .. " absent de toutes les tables de tirage")
	end
end)

test("Roster v3.2 : 16 persos de plus, raretés de base, signatures, noms d'origine", function()
	local Rarities = requireModule(Shared.Config.Rarities)
	local AttackFx = requireModule(Shared.Config.AttackFx)
	local Noms = requireModule(Shared.Config.NomsOriginaux)
	local EFFECTS = { energy_aura = true, ssj_aura = true, steam = true, energy_fists = true, chidori = true, hollow_purple = true, sun_flames = true }
	local function propSig(props)
		local parts = {}
		for _, p in props or {} do
			table.insert(parts, tostring(p.shape) .. tostring(p.limb) .. tostring(p.at) .. tostring(p.size) .. tostring(p.color))
		end
		return table.concat(parts, ";")
	end
	local ROSTER = {
		ninja = { ninja_gaaro = "epic", ninja_minatu = "mythic", ninja_radama = "secret" },
		occulte = { occ_hakaro = "epic", occ_toja = "mythic", occ_yuuto = "legendary", occ_ijichu = "common" },
		saiyan = { sai_cel = "legendary", sai_jirene = "legendary", sai_gojita = "secret" },
		ocean = { oce_inel = "mythic", oce_lao = "legendary", oce_kaydo = "secret" },
		pourfendeur = { pou_tengan = "legendary", pou_doma = "mythic", pou_muzon = "secret" },
	}
	-- La rareté Secret existe et se place entre Mythique et Crossover
	local secret = Rarities.get("secret")
	assert(secret.id == "secret" and table.find(Rarities.Order, "secret"), "rareté Secret manquante")
	assert(secret.basePower > Rarities.get("mythic").basePower and secret.basePower < Rarities.get("crossover").basePower, "puissance Secret mal placée")
	assert(secret.order > Rarities.get("mythic").order and secret.order < Rarities.get("crossover").order, "ordre Secret mal placé")
	-- Raretés de base cohérentes (Maruto Épique, Sukana Secret, Goju Mythique)
	assert(Characters.get("ninja_maruto").rarity == "epic", "Maruto doit être Épique")
	assert(Characters.get("occ_sukana").rarity == "secret", "Sukana doit être Secret")
	assert(Characters.get("occ_goju").rarity == "mythic", "Goju doit être Mythique")
	-- Persos très populaires/puissants pas en Commun (Toudo Épique, Inumako Rare)
	assert(Characters.get("occ_toudo").rarity == "epic", "Toudo doit être Épique")
	assert(Characters.get("occ_inumako").rarity == "rare", "Inumako doit être Rare")
	-- Héros vedettes alignés : Goko et Itochi Mythiques comme Goju
	assert(Characters.get("sai_goko").rarity == "mythic", "Goko doit être Mythique")
	assert(Characters.get("ninja_itochi").rarity == "mythic", "Itochi doit être Mythique")
	-- La couleur unie du Secret est claire (texte lisible sur fond sombre) et il s'affiche en arc-en-ciel
	local sc = Rarities.get("secret").color
	assert(Rarities.get("secret").rainbow and sc.R + sc.G + sc.B > 2.4, "Secret : couleur claire + arc-en-ciel")
	-- Les persos Secrets du jeu : exactement un par univers, ceux attendus
	local SECRETS = { ninja_radama = true, occ_sukana = true, sai_gojita = true, oce_kaydo = true, pou_muzon = true }
	local named = {}
	for _, entry in Noms.List do
		named[entry.id] = true
	end
	local total = 0
	for _, universe in Universes.List do
		local count = {}
		for _, id in universe.characters do
			local r = Characters.get(id).rarity
			count[r] = (count[r] or 0) + 1
		end
		assert(#universe.characters >= 13 and #universe.characters <= 14, universe.id .. " : 13 ou 14 persos attendus (" .. #universe.characters .. ")")
		assert((count.common or 0) >= 2, universe.id .. " : au moins 2 Communs (persos secondaires)")
		assert(count.secret == 1 and (count.mythic or 0) >= 1 and (count.mythic or 0) <= 2, universe.id .. " : un Secret et 1 ou 2 Mythiques")
		for _, id in universe.characters do
			if Characters.get(id).rarity == "secret" then
				assert(SECRETS[id], id .. " : Secret inattendu")
			end
		end
		for id, rarity in ROSTER[universe.id] do
			total += 1
			local def = Characters.get(id)
			assert(def and def.universe == universe.id, id .. " : univers")
			assert(table.find(universe.characters, id), id .. " absent de la table de tirage")
			assert(def.rarity == rarity, id .. " : rareté de base " .. tostring(def.rarity) .. " (attendu " .. rarity .. ")")
			assert(def.evolve and def.evolve[2] and def.evolve[3], id .. " : évolutions ★2/★3")
			assert(def.fusion and def.fusion.prefix and def.fusion.suffix, id .. " : préfixe/suffixe de fusion")
			assert(def.attack and def.attack.name and def.attack.kind, id .. " : attaque")
			assert(named[id], id .. " : nom d'origine manquant")
			-- Chaque étoile change la tenue, la coiffure ou les objets (hors auras et effets)
			for st = 1, 2 do
				local la = Formulas.describe({ id = id, level = 1, stars = st }).look
				local lb = Formulas.describe({ id = id, level = 1, stars = st + 1 }).look
				local visible = propSig(la.props) ~= propSig(lb.props)
				for _, k in { "top", "outfit", "hair", "hairColor", "bottom", "skin" } do
					if la[k] ~= lb[k] then
						visible = true
					end
				end
				local accA, accB = {}, {}
				for _, a in la.accessories or {} do
					accA[a] = true
				end
				for _, a in lb.accessories or {} do
					accB[a] = true
				end
				for a in accB do
					if not accA[a] and not EFFECTS[a] then
						visible = true
					end
				end
				for a in accA do
					if not accB[a] and not EFFECTS[a] then
						visible = true
					end
				end
				assert(visible, id .. " ★" .. st .. " -> ★" .. (st + 1) .. " : tenue, coiffure ou objets doivent changer (pas seulement l'aura)")
			end
			-- Budget de pièces respecté à chaque étoile, objets sur mesure bien construits
			for st = 1, 3 do
				local look = Formulas.describe({ id = id, level = 1, stars = st }).look
				local m = CharacterBuilder.build(look, { scale = 1 })
				local n, props = 0, 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						n += 1
						if d.Name == "Prop" then
							props += 1
						end
					end
				end
				assert(n <= 178, id .. " ★" .. st .. " : trop de pièces (" .. n .. ")")
				-- Seuil d'alerte : garder de la marge sous le plafond (les objets passent après les
				-- accessoires et seraient les premiers sacrifiés si la coiffure ou la tenue s'alourdit)
				assert(n <= 165, id .. " ★" .. st .. " : " .. n .. " pièces, au-delà du seuil d'alerte (165)")
				if look.props then
					assert(props > 0 or #look.props > 0, id .. " : objets sur mesure absents")
				end
				m:Destroy()
			end
		end
	end
	assert(total == 16, "16 nouveaux persos attendus")
	-- Nuque « soignée » : de la couleur des cheveux, remontée dans la coiffure (plus de pavé sombre)
	for _, id in { "occ_toja", "occ_yuuto", "oce_inel", "sai_gojita", "pou_muzon" } do
		local look = Formulas.describe({ id = id, level = 1, stars = 1 }).look
		assert(look.napeTidy, id .. " : nuque soignée attendue")
		local m = CharacterBuilder.build(look, { scale = 1 })
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "HairNape" then
				assert(d.Color == look.hairColor, id .. " : nuque d'une autre couleur que les cheveux")
			end
		end
		m:Destroy()
	end
	-- Objets peints (armure lamellaire de Radama, kanji de Gaaro) : la peinture est bien posée
	local function painted(id, stars, name)
		local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = stars }).look, { scale = 1 })
		local found = false
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name and #d:GetChildren() > 0 then
				for _, c in d:GetDescendants() do
					if c:IsA("SurfaceGui") then
						found = true
					end
				end
			end
		end
		m:Destroy()
		return found
	end
	assert(painted("ninja_gaaro", 1, "Kanji"), "Gaaro : kanji du front non peint")
	assert(painted("ninja_radama", 1, "Prop"), "Radama : armure lamellaire non peinte")
	-- Aperçus des menus (mode « parts » : fiche, inventaire, révélation) : Radama garde son armure
	-- (bandes sombres des lamelles) et tous les nouveaux persos restent sous 390 pièces (marge)
	for _, id in { "ninja_radama", "ninja_minatu", "oce_kaydo", "sai_cel", "pou_muzon", "occ_yuuto" } do
		for st = 1, 3 do
			local m = CharacterBuilder.buildPreview(Formulas.describe({ id = id, level = 1, stars = st }).look)
			local n, bands = 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
					if d.Name == "PropBand" then
						bands += 1
					end
				end
			end
			assert(n <= 390, id .. " ★" .. st .. " (menus) : " .. n .. " pièces (> 390)")
			if id == "ninja_radama" and st <= 2 then
				assert(bands >= 4, "Radama ★" .. st .. " (menus) : armure lamellaire non dessinée")
			end
			m:Destroy()
		end
	end
	-- Objets signature des Secrets (lisibles de loin)
	local function hasProp(id, stars, name)
		local m = CharacterBuilder.build(Formulas.describe({ id = id, level = 1, stars = stars }).look, { scale = 1 })
		local found = false
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				found = true
			end
		end
		m:Destroy()
		return found
	end
	for _, id in { "ninja_radama", "sai_gojita", "oce_kaydo", "pou_muzon" } do
		assert(#Characters.get(id).look.props >= 5 and hasProp(id, 1, "Prop"), id .. " : objet signature")
	end
	-- Carrure : plus de sphères « bulk » (épaules en ballons) sur les persos du roster ; deltoïdes
	-- intégrés à la place pour les colosses
	for _, list in ROSTER do
		for id in list do
			for st = 1, 3 do
				local look = Formulas.describe({ id = id, level = 1, stars = st }).look
				for _, a in look.accessories or {} do
					assert(a ~= "bulk", id .. " ★" .. st .. " : accessoire « bulk » interdit (épaules en ballons)")
				end
				-- plaques d'avant-bras peintes (pastille ronde en surbrillance = « ballon » dans les menus)
				assert(look.armPlates == nil, id .. " ★" .. st .. " : armPlates interdit (pastilles rondes sur les bras)")
			end
		end
	end
	for _, id in { "oce_kaydo", "sai_jirene" } do
		assert(hasProp(id, 1, "Deltoid") and hasProp(id, 1, "Trapezius"), id .. " : deltoïdes intégrés attendus")
	end
	-- Kaydo ★2/★3 (forme hybride) : écailles plates en coins le long des avant-bras, pas de boule
	for st = 2, 3 do
		local m = CharacterBuilder.build(Formulas.describe({ id = "oce_kaydo", level = 1, stars = st }).look, { scale = 1 })
		local n = 0
		for _, d in m:GetDescendants() do
			if d.Name == "KaydoScale" then
				assert(d:IsA("WedgePart") and math.min(d.Size.X, d.Size.Y, d.Size.Z) <= 0.1 * m:GetAttribute("BaseScale"), "Kaydo : écaille non plate")
				n += 1
			end
		end
		assert(n >= 6, "Kaydo ★" .. st .. " : écailles des avant-bras attendues (" .. n .. ")")
		m:Destroy()
	end
	-- Secrets : plus grands que les autres (Kaydo le géant encore plus) et éclat arc-en-ciel au
	-- sol dès le ★1 ; ni l'un ni l'autre dans les aperçus des menus (cadrés à la même taille)
	for id in SECRETS do
		local look = Formulas.describe({ id = id, level = 1, stars = 1 }).look
		assert((look.bodyScale or 1) >= 1.12, id .. " : Secret à peine plus grand attendu")
		local m = CharacterBuilder.build(look, { scale = 1 })
		local expected = math.max(look.bodyScale, look.minScale or 0)
		assert(math.abs((m:GetAttribute("BaseScale") or 1) - expected) < 1e-6, id .. " : BaseScale = carrure du Secret")
		m:Destroy()
		-- au niveau 1 (taille de niveau 0.85) : jamais plus petit que l'avatar joueur (plancher)
		m = CharacterBuilder.build(look, { scale = Formulas.visualScale({ id = id, level = 1, stars = 1 }) })
		assert((m:GetAttribute("BaseScale") or 1) >= 1.05 - 1e-6, id .. " : Secret plus petit que l'avatar au niveau 1")
		local glint = m:FindFirstChild("SecretGlint", true)
		assert(glint and glint:FindFirstChildOfClass("ParticleEmitter"), id .. " : éclat arc-en-ciel du Secret absent")
		m:Destroy()
		local preview = CharacterBuilder.buildPreview(look)
		assert(preview:FindFirstChild("SecretGlint", true) == nil, id .. " : éclat dans l'aperçu des menus")
		assert((preview:GetAttribute("BaseScale") or 1) == 1, id .. " : aperçu des menus à l'échelle 1")
		preview:Destroy()
	end
	assert(Formulas.describe({ id = "oce_kaydo", level = 1, stars = 1 }).look.bodyScale >= 1.25, "Kaydo : géant attendu")
	do
		-- Kaydo le géant : ~30 % de plus que l'avatar joueur (échelle 1) dès le niveau 1
		local entry = { id = "oce_kaydo", level = 1, stars = 1 }
		local m = CharacterBuilder.build(Formulas.describe(entry).look, { scale = Formulas.visualScale(entry) })
		assert(m:GetAttribute("BaseScale") >= 1.3, "Kaydo : pas un géant en jeu (" .. m:GetAttribute("BaseScale") .. ")")
		m:Destroy()
		-- les aperçus des menus restent cadrés à l'échelle 1
		local preview = CharacterBuilder.buildPreview(Formulas.describe(entry).look)
		assert((preview:GetAttribute("BaseScale") or 1) == 1, "Kaydo : aperçu des menus à l'échelle 1")
		preview:Destroy()
	end
	-- Susanoo de Radama ★2 : squelette en blocs et coins (aucune sphère, en jeu comme dans les
	-- menus), colonne centrée, côtes symétriques qui contournent les bras, crâne centré derrière
	-- la tête, colonne en flammèches bleues (en jeu seulement)
	for _, mode in { "game", "parts" } do
		local look = Formulas.describe({ id = "ninja_radama", level = 1, stars = 2 }).look
		local m = mode == "parts" and CharacterBuilder.buildPreview(look) or CharacterBuilder.build(look, { scale = 1 })
		local k = m:GetAttribute("BaseScale") or 1
		local tag = "Susanoo (" .. mode .. ") : "
		local spine = m:FindFirstChild("SusanooSpine", true)
		assert(spine, tag .. "colonne absente")
		if mode == "game" then
			assert(spine:FindFirstChild("PropFlames"), tag .. "flammèches de la colonne absentes")
		end
		assert(m:FindFirstChild("SusanooSkull", true) and m:FindFirstChild("SusanooOrbit", true) and m:FindFirstChild("SusanooJaw", true), tag .. "crâne incomplet")
		local torso = m:FindFirstChild("Torso")
		local head = m:FindFirstChild("Head")
		local left, right = {}, {}
		local skullX, skullN = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 7) == "Susanoo" then
				assert(not d:FindFirstChildOfClass("SpecialMesh"), tag .. d.Name .. " en sphère")
				assert(not (d:IsA("Part") and d.Shape == Enum.PartType.Ball), tag .. d.Name .. " en boule")
				local rel = torso.CFrame:PointToObjectSpace(d.CFrame.Position) / k
				if d.Name == "SusanooRib" then
					-- devant le plan du dos : seulement à l'extérieur des bras (jamais devant l'armure)
					if rel.Z < 0.5 then
						assert(math.abs(rel.X) >= 1.95, tag .. "côte devant le torse (x = " .. rel.X .. ", z = " .. rel.Z .. ")")
					end
					table.insert(rel.X < 0 and left or right, rel)
				elseif d.Name == "SusanooSpine" or d.Name == "SusanooVertebra" then
					assert(math.abs(rel.X) < 0.05 and rel.Z > 0.5 and rel.Z < 1.0, tag .. "colonne décentrée")
				elseif d.Name == "SusanooSkull" then
					local h = head.CFrame:PointToObjectSpace(d.CFrame.Position) / k
					skullX += h.X
					skullN += 1
					assert(h.Z > 0.5 and h.Y < 2.2, tag .. "crâne mal placé")
				end
			end
		end
		-- côtes symétriques : même nombre de chaque côté, positions en miroir
		assert(#left == #right and #left >= 16, tag .. "côtes asymétriques (" .. #left .. " / " .. #right .. ")")
		local widest = 0
		for _, r in right do
			widest = math.max(widest, r.X)
			local mirrored = false
			for _, l in left do
				if math.abs(l.X + r.X) + math.abs(l.Y - r.Y) + math.abs(l.Z - r.Z) < 0.03 then
					mirrored = true
					break
				end
			end
			assert(mirrored, tag .. "côte sans pendant en miroir")
		end
		assert(widest >= 2.4, tag .. "cage trop étroite (" .. widest .. ")")
		assert(skullN >= 3 and math.abs(skullX / skullN) < 0.05, tag .. "crâne décentré")
		m:Destroy()
	end
	-- Kaydo : la massue n'est jamais devant ni derrière le visage (tenue verticale sur le flanc
	-- droit) ; mèches latérales derrière les oreilles
	for st = 1, 3 do
		local look = Formulas.describe({ id = "oce_kaydo", level = 1, stars = st }).look
		assert((look.hairSweep or 108) <= 95, "Kaydo : mèches latérales sur le visage")
		for _, mode in { "game", "parts" } do
			local m = mode == "parts" and CharacterBuilder.buildPreview(look) or CharacterBuilder.build(look, { scale = 1 })
			local k = m:GetAttribute("BaseScale") or 1
			local head = m:FindFirstChild("Head")
			local n = 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Kanabo" then
					n += 1
					local rel = head.CFrame:PointToObjectSpace(d.CFrame.Position) / k
					assert(math.abs(rel.X) > 1.3, "Kaydo ★" .. st .. " : massue dans l'axe de la tête (x = " .. rel.X .. ")")
					assert(rel.Y < 0, "Kaydo ★" .. st .. " : massue à hauteur du visage")
				end
			end
			assert(n >= 5, "Kaydo ★" .. st .. " : massue absente")
			m:Destroy()
		end
	end
	-- Kaydo ★2 (forme dragon) : se distingue du ★1 au premier coup d'œil
	do
		local l1 = Formulas.describe({ id = "oce_kaydo", level = 1, stars = 1 }).look
		local l2 = Formulas.describe({ id = "oce_kaydo", level = 1, stars = 2 }).look
		assert(l2.eyeGlow and not l1.eyeGlow, "Kaydo ★2 : yeux luisants attendus")
		assert(l2.capeColor ~= l1.capeColor, "Kaydo ★2 : cape d'une autre teinte attendue")
		local m = CharacterBuilder.build(l2, { scale = 1 })
		local k = m:GetAttribute("BaseScale")
		local torso = m:FindFirstChild("Torso")
		local limbs, scales, horns, tailX = {}, 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "KaydoScale" then
					scales += 1
					limbs[d.Parent and d.Parent.Name or "?"] = true
				elseif d.Name == "KaydoHorn" then
					horns += 1
				elseif d.Name == "KaydoTail" then
					tailX = math.min(tailX, torso.CFrame:PointToObjectSpace(d.CFrame.Position).X / k)
				end
			end
		end
		assert(scales >= 12, "Kaydo ★2 : écailles attendues sur les deux avant-bras, les épaules et les pommettes (" .. scales .. ")")
		assert(horns >= 4, "Kaydo ★2 : cornes recourbées en deux segments attendues")
		assert(tailX < -2.1, "Kaydo ★2 : la queue doit dépasser de la silhouette sur le côté")
		m:Destroy()
	end
	-- Rika (Yuuto ★2) : tête, bouche peinte de dents, yeux rouges luisants
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "occ_yuuto", level = 1, stars = 2 }).look, { scale = 1 })
		assert(m:FindFirstChild("RikaHead", true), "Rika : tête absente")
		local mouth = m:FindFirstChild("RikaMouth", true)
		assert(mouth and mouth:FindFirstChildOfClass("SurfaceGui"), "Rika : dents non peintes")
		local glow = false
		for _, d in m:GetDescendants() do
			if d.Name == "RikaEye" and d:FindFirstChild("PropGlow") then
				glow = true
			end
		end
		assert(glow, "Rika : yeux sans lueur")
		-- Rika en blocs et coins (crâne anguleux, dos voûté) : plus de grosses sphères
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "RikaHead" or d.Name == "RikaBack") then
				assert(not d:FindFirstChildOfClass("SpecialMesh"), "Rika : " .. d.Name .. " en sphère")
			end
		end
		assert(m:FindFirstChild("RikaBack", true), "Rika : dos voûté absent")
		m:Destroy()
	end
	-- Hakaro : tempes rasées sur les côtés seulement (pas de bande autour de la tête)
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "occ_hakaro", level = 1, stars = 1 }).look, { scale = 1 })
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Shaved" then
				n += 1
				assert(d.Size.X < 0.5, "Hakaro : rasé tout autour de la tête")
			end
		end
		assert(n == 2, "Hakaro : deux tempes rasées attendues")
		m:Destroy()
	end
	-- Gaaro ★2/★3 : le sable sort de la gourde en petits blocs de Sable (aucune boule), avec
	-- grains, jamais plus haut que l'épaule ; au ★3, bouclier mural sur le côté
	for st = 2, 3 do
		local look = Formulas.describe({ id = "ninja_gaaro", level = 1, stars = st }).look
		local m = CharacterBuilder.build(look, { scale = 1 })
		local k = m:GetAttribute("BaseScale") or 1
		local wave = m:FindFirstChild("SandWave", true)
		assert(wave and wave:FindFirstChild("PropDust"), "Gaaro ★" .. st .. " : vague de sable sans grains")
		local torso = m:FindFirstChild("Torso")
		local sand, wall = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Sand" or d.Name == "SandWave" or d.Name == "SandWall") then
				assert(d.Material == Enum.Material.Sand, "Gaaro : sable sans matériau Sable")
				assert(not d:FindFirstChildOfClass("SpecialMesh"), "Gaaro : boule de sable")
				local rel = torso.CFrame:PointToObjectSpace(d.CFrame.Position) / k
				assert(rel.Y <= 1.6, "Gaaro ★" .. st .. " : sable plus haut que l'épaule (" .. rel.Y .. ")")
				sand += 1
				if d.Name == "SandWall" then
					wall += 1
				end
			end
		end
		assert(sand >= 14, "Gaaro ★" .. st .. " : flot de sable trop maigre (" .. sand .. ")")
		assert(st == 2 or wall >= 10, "Gaaro ★3 : bouclier mural attendu")
		m:Destroy()
	end
	-- Coiffures : Muzon ★2 en vagues de coins (pas de boules), Tengan cheveux plaqués + bandeau
	-- à gemmes en néon (pas de hérisson)
	do
		local look = Formulas.describe({ id = "pou_muzon", level = 1, stars = 2 }).look
		for _, p in look.props do
			if p.limb == "Head" then
				assert(p.shape ~= "strand" and p.shape ~= "ball", "Muzon ★2 : boucles en boules")
			end
		end
		local m = CharacterBuilder.build(look, { scale = 1 })
		local curls = 0
		for _, d in m:GetDescendants() do
			if d.Name == "MuzonCurl" then
				assert(d:IsA("WedgePart"), "Muzon : boucle qui n'est pas un coin")
				curls += 1
			end
		end
		assert(curls >= 15, "Muzon ★2 : boucles en vagues attendues")
		m:Destroy()
		local tl = Formulas.describe({ id = "pou_tengan", level = 1, stars = 1 }).look
		assert(tl.hair ~= "hedgehog", "Tengan : hérisson interdit")
		m = CharacterBuilder.build(tl, { scale = 1 })
		local gems, locks = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Gem" then
				assert(d.Material == Enum.Material.Neon, "Tengan : gemme non lumineuse")
				gems += 1
			elseif d.Name == "TenganLock" then
				locks += 1
			end
		end
		assert(gems == 5 and locks >= 3 and locks <= 4, "Tengan : bandeau à gemmes et 3-4 mèches attendus")
		m:Destroy()
	end
	-- Doma : mèches lisses et plates (aucun boudin), sang en éclaboussures plates sur le sommet
	for st = 1, 3 do
		local look = Formulas.describe({ id = "pou_doma", level = 1, stars = st }).look
		local locks, blood = 0, 0
		for _, p in look.props do
			assert(p.shape ~= "strand", "Doma ★" .. st .. " : mèche en boudin")
			if p.name == "DomaLock" then
				locks += 1
			elseif p.name == "DomaBlood" then
				blood += 1
				assert(p.shape == "wedge", "Doma : sang en relief")
			end
		end
		assert(locks >= 14 and blood >= 4, "Doma ★" .. st .. " : mèches plates et sang attendus")
	end
	-- Jirène sans marques sur les joues ; crête de Cel symétrique (une lame de chaque côté)
	assert(not Formulas.describe({ id = "sai_jirene", level = 1, stars = 1 }).look.jawShade, "Jirène : marques sur les joues")
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "sai_cel", level = 1, stars = 1 }).look, { scale = 1 })
		local head = m:FindFirstChild("Head")
		local xs = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 8) == "CelCrest" then
				table.insert(xs, head.CFrame:PointToObjectSpace(d.CFrame.Position).X)
			end
		end
		local l, r = 0, 0
		for _, x in xs do
			if x < -0.1 then
				l += 1
			elseif x > 0.1 then
				r += 1
			end
		end
		assert(l > 0 and l == r, "Cel : crête asymétrique (" .. l .. " / " .. r .. ")")
		m:Destroy()
	end
	-- Pas de bouche « rouge à lèvres » (grand sourire ouvert) pour Hakaro et Inel
	for _, id in { "occ_hakaro", "oce_inel" } do
		local style = Formulas.describe({ id = id, level = 1, stars = 1 }).look.mouthStyle
		assert(style ~= "grin" and style ~= "wide_grin", id .. " : bouche ouverte rouge")
	end
	-- Dos de Minatu : « Quatrième Hokage » en colonne de caractères rouges
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "ninja_minatu", level = 1, stars = 1 }).look, { scale = 1 })
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("TextLabel") and d.Name == "HaoriKanji" then
				n += 1
			end
		end
		assert(n == 5, "Minatu : kanji du dos du haori attendus (" .. n .. ")")
		m:Destroy()
	end
	-- Variété Arc-en-ciel : reflet en bande étroite (la tenue garde sa couleur)
	do
		local m = CharacterBuilder.build(Formulas.describe({ id = "pou_muzon", level = 1, stars = 1 }).look, { scale = 1 })
		CharacterBuilder.applyVariety(m, "Arc-en-ciel")
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("UIGradient") and d.Name == "VarietyRainbow" then
				n += 1
				local kp = d.Transparency.Keypoints
				assert(kp[1].Value >= 0.99 and kp[#kp].Value >= 0.99, "Arc-en-ciel : les bords du reflet doivent être transparents")
				local least = 1
				for _, k in kp do
					least = math.min(least, k.Value)
				end
				assert(least >= 0.6, "Arc-en-ciel : reflet trop couvrant")
			end
		end
		assert(n > 0, "Arc-en-ciel : reflet absent")
		m:Destroy()
	end
	-- Chaque perso jouable a une attaque signature valide (plus de repli générique)
	for id in Characters.List do
		local sig = AttackFx.Characters[id]
		assert(sig and AttackFx.Signatures[sig], id .. " : pas d'attaque signature")
		assert(AttackFx.forCharacter(id, "punch") == sig, id .. " : signature non résolue")
	end
	-- Noms proches des originaux, tous différents
	local names = {}
	for id, def in Characters.List do
		assert(not names[def.name], def.name .. " en double (" .. id .. ")")
		names[def.name] = true
	end
end)

test("Construction de fusions (toutes les paires Légendaire/Mythique)", function()
	local ids = {}
	for id, def in Characters.List do
		if def.rarity == "legendary" or def.rarity == "mythic" then
			table.insert(ids, id)
		end
	end
	local count = 0
	for _, a in ids do
		for _, b in ids do
			if Characters.get(a).universe ~= Characters.get(b).universe then
				local entry = { id = "fusion", fusion = { a = a, b = b }, level = 1, stars = 2 }
				local desc = Formulas.describe(entry)
				CharacterBuilder.build(desc.look, { scale = 1 })
				count += 1
			end
		end
	end
	print("   " .. count .. " fusions construites")
end)

test("Construction de toutes les reliques", function()
	for id, relic in Universes.Relics do
		local model = RelicBuilder.build(relic.look, relic.tier, 1)
		assert(countParts(model) > 3, id)
	end
end)

local Workspace = game:GetService("Workspace")
local Server = find("ServerScriptService.Server")

test("Construction de la carte", function()
	local WorldBuilder = requireModule(Server.World.WorldBuilder)
	WorldBuilder.build()
	print("   pièces de la carte : " .. countParts(Workspace))
end)

test("Décors des 5 univers", function()
	local UniverseDecor = requireModule(Server.World.UniverseDecor)
	local zone = Workspace.World.Zone
	-- chaque univers a son propre module (repère emblématique) et reste dans le budget de pièces
	local signature = {
		ninja = "TourDuChef",
		occulte = "Pagode",
		saiyan = "AreneDuTournoi",
		ocean = "Navire",
		pourfendeur = "PortePourfendeurs",
	}
	local BUDGET = 45000
	for _, universe in Universes.List do
		local decor = UniverseDecor.apply(universe, zone)
		local parts = countParts(decor)
		print(string.format("   %-24s %4d pièces", universe.name, parts))
		assert(parts <= BUDGET, universe.id .. " : trop de pièces (" .. parts .. " > " .. BUDGET .. ")")
		local found = false
		for _, item in decor:GetDescendants() do
			if item:IsA("Model") and item:GetAttribute("Slot") == signature[universe.id] then
				found = true
				break
			end
		end
		assert(found, universe.id .. " : repère « " .. tostring(signature[universe.id]) .. " » absent (module d'univers manquant ?)")
		for _, folderName in { "Anneau", "Ile", "Horizon" } do
			assert(decor:FindFirstChild(folderName), universe.id .. " : dossier " .. folderName .. " absent (toute la carte doit changer)")
		end
		assert(universe.theme.sol and universe.theme.sol.herbe and universe.theme.ciel, universe.id .. " : sol / ciel absents")
	end
end)

test("Carte : le sol suit l'univers, éléments remplaçables", function()
	local UniverseDecor = requireModule(Server.World.UniverseDecor)
	local zone = Workspace.World.Zone
	local grass = Workspace.World.Ground:FindFirstChild("Grass")
	assert(grass and grass:GetAttribute("Role") == "herbe", "herbe de l'île non marquée")
	for _, id in { "occulte", "ninja" } do
		local universe = Universes.get(id)
		UniverseDecor.apply(universe, zone)
		assert(grass.Color == universe.theme.sol.herbe[1], "couleur du sol non appliquée : " .. id)
	end
	local slots, sized = 0, 0
	for _, item in zone.Decor:GetDescendants() do
		if item:IsA("Model") and item:HasTag("DecorSlot") then
			slots += 1
			if (item:GetAttribute("TargetHeight") or 0) > 0 and item:GetAttribute("Slot") then
				sized += 1
			end
		end
	end
	assert(slots > 50 and sized == slots, "emplacements remplaçables manquants")
	print("   emplacements remplaçables (Village Ninja) : " .. slots)
end)

test("Bases des joueurs + toutes les améliorations", function()
	local Remotes = requireModule(Shared.Modules.Remotes)
	assert(Remotes.event("Notify"))
	local PlotService = requireModule(Server.Services.PlotService)
	local allUpgrades = {}
	for _, upgrade in Economy.Upgrades do
		allUpgrades[upgrade.id] = true
	end
	local fakePlayer = { UserId = 1, DisplayName = "Testeur", SetAttribute = function() end, CharacterAdded = fakeSignal }
	local services = {
		DataService = {
			Get = function()
				return { upgrades = allUpgrades, coins = 0, stash = 0 }
			end,
		},
		CharacterService = {
			GetBestLook = function()
				return Characters.get("ninja_maruto").look
			end,
		},
	}
	PlotService:Init(services)
	local plot = PlotService:GetPlots()[1]
	-- Accès interne : on enregistre la base pour ce joueur via _assign simplifié.
	PlotService:_assign(fakePlayer, {})
	assert(PlotService:GetPlot(fakePlayer) == plot, "base non attribuée")
	assert(#plot.ownerFolder.Structures:GetChildren() == #Economy.Upgrades, "structures manquantes")
	-- Chaque bouton est dans la zone de jeu (hors bande de déco de 10 studs).
	local Structures = requireModule(Server.Modules.TycoonStructures)
	local limit = Structures.Spots.inner - 3.8
	for _, upgrade in Economy.Upgrades do
		local pad = Structures.padPosition(upgrade.id)
		assert(pad, "bouton sans position : " .. upgrade.id)
		assert(math.abs(pad.X) <= limit and math.abs(pad.Z) <= limit, "bouton hors de la zone de jeu : " .. upgrade.id)
	end
	assert(#plot.slots == 24 and plot.machine.prompt and plot.skillRefs.prompt, "machine / cases / arbre manquants")
	assert(plot.model:FindFirstChild("Decor") and #plot.signLabels >= 2, "déco de base ou panneau manquant")
	local total = countParts(plot.model)
	print("   pièces d'une base complète : " .. total .. " (déco : " .. countParts(plot.model.Decor) .. ")")
	assert(total < 9000, "base trop lourde : " .. total .. " pièces")
end)

Harness.finish()
