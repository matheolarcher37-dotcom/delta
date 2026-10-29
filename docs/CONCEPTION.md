# ANIME TYCOON — Document de conception

**Version 3.2** : ta version 1.0, complétée avec tout ce qui est dans le jeu aujourd'hui, ta pépite
(la Fusion Crossover) et tes retours des versions 3 et 3.1. Ceux de la 3.1 portaient sur des persos encore plus
détaillés (et plus nombreux, avec des variétés), un roulage d'un perso à la fois (2 ou 3 en payant), la pitié du
Mythique seulement, le roulement automatique payant, une vraie boutique Robux, un marchand d'objets d'évolution
repérable de loin, des défis, une zone anti-AFK, des traits relancés avec des gemmes, une belle montagne des chefs,
des épées détaillées et des panneaux de base qui ne rentrent plus dans le sol.

> ✅ = dans le jeu · 💡 = idée pour la suite

---

## Concept principal

Un jeu Roblox de type **Tycoon** qui mélange collection de persos d'animé, gestion de base et combat.
Il est inspiré de *Grow a Chicken Fighter* (fonctionnement, base qui grandit) et de *Defeat Anime Bosses* (attaques, style des persos).
Les persos sont de **vrais avatars Roblox R6** aux proportions classiques, avec des noms légèrement changés
(Naruto → Maruto, Gojo → Goju…). On les obtient surtout avec la **machine ROULER** de sa base.

---

## 1. Les persos ✅

- ✅ **66 persos** répartis dans 5 univers (Communs, Rares, Épiques, Légendaires, Mythiques et **un Secret par univers** : Radama, Sukana, Gojita, Kaydo, Muzon), des ennemis et **5 boss**.
- ✅ Tous construits comme un **avatar R6 classique** : tête ronde classique, torse 2×2, bras et jambes 1×2, articulations et animations officielles de Roblox.
- ✅ **Maruto ★1 recopie le Kid Naruto** (visage, veste, bandeau). C'est le modèle de référence de tous les styles de persos.
- ✅ Très détaillés : vêtements dessinés comme des habits Roblox classiques (plis, ombres, coutures), mèches à base arrondie avec reflets, cols, ceintures et semelles en relief, visages et formes de tête variés, accessoires propres à chacun (Susanoo de Radama, massue et forme dragon de Kaydo, sable de Gaaro…).
- ✅ **3 rangs d'évolution** (★, ★★, ★★★) : **chaque étoile change l'apparence**.
- ✅ **Rareté de base fixe** (Maruto est Épique, il reste Épique) + une **variété** tirée par-dessus : Foudre, Givre, Flamme, Sakura, Ombre, Or, Néant, Diamant, Galaxie, Angélique, Arc-en-ciel (multiplicateur de puissance et de prix de ×1,5 à ×6). Chacune a son signe visible sur le perso, partout (base, combat, menus).
- ✅ **Boss soignés** (liseré lumineux, lumière de face, aura), et **Kourama est une vraie créature** : un renard géant à neuf queues animé.
- ✅ On peut **remplacer n'importe quel perso** par un modèle de la Boîte à outils (reconnu par son nom d'origine), par son propre rig R6 ou par des objets du catalogue Roblox.

## 2. La carte ✅

- ✅ **Carte en taille réelle** : hub au centre, anneau de combat autour, 6 bases de 140 × 140, puis une grande île, l'océan et des montagnes enneigées à l'horizon.
- ✅ Carte fixe détaillée : collines, falaises, plage, étang, ruisseau avec pont, rues pavées, vrais arbres détaillés, sol naturel. L'île est **habillée partout** (touffes, fleurs, cailloux, buissons, souches, chemins de dalles autour des portiques).
- ✅ **5 univers**, un nouveau **toutes les 30 minutes** (le même sur tous les serveurs). **TOUTE la carte change** : bâtiments de l'anneau, forêt de l'île, grand monument, montagnes, couleurs du sol, ciel, lumière, particules… et la déco des bases.
  - **Village Ninja** : tour du chef, **montagne des chefs** (monument en dôme, 8 têtes sculptées sur deux rangs, chacune avec son caractère), ramen, maisons rondes.
  - **Académie Occulte** : école en bois sombre, pagode, cimetière brumeux, Sanctuaire Malveillant.
  - **Planète des Guerriers** : maisons-dômes, Capsule Corp, voitures volantes, arène du tournoi, tour céleste.
  - **Grand Océan** : port, navires, phare, lagon.
  - **Ère des Pourfendeurs** (la nuit) : ville Taishō, Domaine des Papillons, glycines, rocher fendu, Train de l'Infini.
- ✅ **Enseignes artisanales** sur les 6 stands du hub (planche de bois sculptée, lettres peintes, motif, lanterne) et **présentoir de vraies épées** au Forgeron.
- ✅ **Lieux réservés**, toujours dégagés : coin des échanges, zone anti-AFK, coins du marchand, tableaux de classement.
- ✅ **Faille Inter-Univers** au changement : flash, tremblement, annonce géante.
- ✅ Chaque univers reste sous **40 000 pièces** (fluide sur mobile et console). Arbres, rochers, bâtiments et la montagne sont **remplaçables** par des modèles de la Boîte à outils (`ServerStorage › ModelesDeco`).

## 3. La base / Tycoon ✅

- ✅ **Machine ROULER** au centre de la base :
  - **un perso par roulage** (2 ou 3 avec les passes Robux « Roulage x2 / x3 ») ; il s'affiche sur le podium avec une étiquette au-dessus de la tête (rareté, variété, DPS, nom, prix) ;
  - on tire une rareté, puis un perso de cette rareté dans le pool de l'**univers actuel**, puis éventuellement une variété ;
  - **pitié du Mythique seulement** (garanti au bout de 1 000 persos tirés), tout le reste est du pur hasard ; panneau des chances à jour ;
  - le roulage est gratuit, on paie à la collecte (le premier perso est offert) ; un Légendaire ou mieux demande confirmation avant de partir ;
  - à la machine : une petite barre ROULER (x1 / x2 / x3, AUTO) en bas à droite (plus de carte du perso tiré depuis la v3.4 : on collecte sur l'estrade), la roulette défile sur l'estrade, et la caméra montre le podium 1,5 s pour un Légendaire ou mieux.
- ✅ **Roulement automatique** (fenêtre AUTO, à la machine) : **Lancer AFK** (29 Robux, pause sur les raretés et variétés cochées) et **Roulement automatique +** (500 Robux : choisir le perso, la rareté et la variété, la machine l'achète toute seule).
- ✅ **Arbre de compétences hexagonal** : **56 cases** en 6 branches autour d'un cœur.
  - **Chance** : Chance I à V, Chance Divine, Bénédiction, Instinct.
  - **Tirage** : Taux d'apparition, Marchandage (persos moins chers), Machine Survoltée, Flair des mutations.
  - **Revenu**, **Dégâts**, **Critique**, **Domaine** (Emplacements, Pas Légers, Pitié Mythique, Œil Céleste).
  - Prix : de 150 à 15 millions de pièces.
- ✅ **28 constructions** sur 3 paliers, toutes visibles. Les boutons d'achat ont un anneau vert ou rouge, un **panneau relevé** (bord bas à 7 studs : jamais coupé par le sol ou un socle), lisible jusqu'à 140 studs, en version compacte au loin, et les panneaux qui se recouvrent se cachent automatiquement.
- ✅ **24 cases d'unités** hexagonales qui remplissent le **coffre** (les pièces roulent sur un tapis ; compteur aéré au-dessus du coffre). « **Remplacer l'unité** » permet de choisir qui se tient sur une case.
- ✅ **Déco de base par univers**.
- ✅ La **pastille Marchand** du HUD ouvre l'écran du marchand ambulant (avec « Montrer le chemin ») ; le comptoir de la base et l'autel d'éveil ont été retirés en v3.4 (doublons du marchand ambulant et du stand FAIRE ÉVOLUER du hub), comme l'Aimant à Pièces (remboursé). Les **reliques** et leurs autels ont été retirés en v3.3 (autels achetés remboursés) : la machine ROULER est la seule source de persos.
- ✅ **Roulette sur l'estrade** (v3.4, UI/RollSpin) : des persos de l'univers défilent sur la case du perso tiré puis s'arrêtent dessus ; le vrai perso est caché côté client pendant ce temps, le serveur retarde les lumières de l'estrade et l'annonce (Formulas.rollSpinTime). Plus de cartes « Collecter » : la collecte se fait de près, avec l'invite du perso sur l'estrade.

## 4. Le combat ✅

- ✅ Les persos équipés (3 places, jusqu'à 5) **suivent le joueur** et attaquent tout seuls dans l'anneau ; clic sur un ennemi = cible prioritaire.
- ✅ Le joueur se bat aussi, avec une épée achetée au **Forgeron** (8 épées avec effets).
- ✅ **Attaques signature détaillées** (comme *Defeat Anime Bosses*) : chaque attaque spéciale commence par une **charge** (cercle au sol, aura, énergie qui se rassemble). Le nom de l'attaque s'affiche en grand, puis viennent l'explosion, l'onde de choc, le cratère, les fissures et les roches projetées.
  - **8 attaques uniques** : Rasengan, Chidori, Kamehameha, Violet Imaginaire, Découpe, Gatling + Red Hawk, Santoryu Oni Giri, Hinokami Kagura.
  - Les autres persos utilisent **9 familles d'effets** déclinées en variantes.
- ✅ **Boss** toutes les 8 minutes, avec une attaque de zone propre à chacun : piliers de feu, météores de magma, dôme maudit, rayons, éclairs.
- ✅ **Qualité automatique** des effets (PC haute, console moyenne, mobile basse), qui baisse toute seule si le jeu rame. Le menu Options permet de couper la secousse et les flashs.

## 5. Évolution, marchand, traits, forge ✅

- ✅ Les persos montent de niveau et **grandissent**. Plafond : ★ = 30, ★★ = 60, ★★★ = 100.
- ✅ **Évolution** au stand FAIRE ÉVOLUER du hub (Autel d'Éveil) avec le niveau, des pièces et **un objet d'évolution** (ex. Goko ★★ demande une **Boule du Dragon**).
- ✅ **Marchand ambulant** : il s'installe dans un coin de la carte et change de coin toutes les 8 minutes ; un **rayon violet** monte dans le ciel à côté de son échoppe (repère, pas une attaque) avec l'étiquette MARCHAND. Il vend toujours l'objet signature de l'univers en cours. Ses objets servent **uniquement** à faire évoluer les persos. Pastille « Marchand : mm:ss » et flèche sur l'écran, bouton « Montrer le chemin ».
- ✅ **Traits** : bonus aléatoires (de Vigueur I à **Monarque**), relancés avec des **gemmes de trait** (gagnées en battant des ennemis, le boss, au punching-ball, en défis, ou en packs Robux ; jamais avec des pièces). Écran animé (rouleau à suspense, révélation selon la rareté) et **cinématiques** pour Monarque (une cour de persos s'agenouille devant ton unité), Céleste, Midas et Vampire.
- ✅ **Forgeron** : 8 épées détaillées (lame, garde, poignée tressée, ornements), chacune avec son effet, qui **grandit avec la maîtrise** (tous les 500 ennemis vaincus, jusqu'au niveau 4). En main, lame levée ; rangée, à la hanche ou dans le dos.

## 5 bis. Boutique Robux, défis, zone anti-AFK, classements ✅

- ✅ **Boutique Robux** : 8 passes (Roulage x2 / x3, x2 Argent, x2 Chance, Lancer AFK 29, Roulement automatique + 500, +2 Cases, VIP), packs de pièces et de gemmes, boosts de 15 min, **Pack de départ** (un seul achat). Boutons « x2 Argent », « Roulage x3 »… à droite de l'écran. Les numéros des passes et produits sont à coller dans `src/shared/Config/Robux.luau`.
- ✅ **Défis** : défis à paliers par univers (« Tue 200 Kakashu » → au moins 1 000 pièces), combat, entraînement, collection, 4 défis du jour + un coffre bonus. Les pièces suivent le revenu du joueur. Rivaux d'univers (environ 1 ennemi sur 4).
- ✅ **Zone anti-AFK** : 3 punching-balls (un par joueur), aucune attaque ; tous les 1 000 coups d'épée = 20 gemmes de trait.
- ✅ **3 tableaux de classement** : Robux dépensés, plus riches, perso le plus fort.

## 6. Les échanges ✅

- ✅ **Coin des Échanges** : on s'assoit à une table ; quand quelqu'un s'assoit en face, la fenêtre s'ouvre.
- ✅ Persos, matériaux et pièces. Il y a des boutons +1k / +10k / +100k pour la manette, « Prêt » des deux côtés et un compte à rebours de 3 secondes.
- ✅ Sécurité : toute modification annule le « Prêt », les persos verrouillés 🔒 ne s'échangent pas et le transfert est atomique.

## 7. La pépite ✅ : la Fusion Crossover

On fusionne **deux persos de deux univers différents** (Épique ou mieux, au moins ★★) pour créer un perso **Crossover** unique :
la coiffure et le visage du premier, la tenue du second, et un nom composé (Maruto + Goju = **Renard de l'Infini**).
Il y a **320 combinaisons** à découvrir. Le Crossover hérite de la meilleure aura et du meilleur trait.

Pourquoi c'est la bonne pépite :
1. Elle exploite la **rotation des univers**.
2. Elle nourrit les **échanges**.
3. Elle donne un objectif de fin de partie quasi infini.
4. C'est le fantasme des fans : « et si Naruto avait les pouvoirs de Gojo ? »

### Autres bonus ✅

- ✅ **Variétés** (11, de Foudre à Arc-en-ciel), visibles sur le perso partout.
- ✅ **Événements célestes** toutes les 11 minutes : Orage Électrique, Éclipse du Néant, Pluie d'Or, Lune de Sang.
- ✅ **Index** de la collection, **Guide** illustré en jeu, **classement**, voyages rapides (Base, Combat, Hub, Boss, Échanges).
- ✅ **Compatible console** : tout se joue à la manette (A choisir, B fermer, X rouler ou utiliser une invite, LB/RB onglets, croix haut = menu), l'interface s'agrandit sur télé et respecte la zone sûre.
- ✅ **Tout est visible et modifiable dans Studio** en mode édition : carte, 5 décors, déco des bases, base d'exemple, galerie des persos.

---

## 8. Idées pour la suite 💡

| Idée | Description | Intérêt |
|---|---|---|
| 💡 **Expansion de Domaine** | Une jauge se remplit en combat ; une fois pleine, ton équipe déploie un domaine (+100 % de dégâts pendant 15 s, décor qui change autour de toi). | Moment « wow » très animé |
| 💡 **Raids inter-univers** | Pendant les 2 dernières minutes d'un univers, le boss du suivant envahit la zone. | Fin de rotation excitante |
| 💡 **Arène JcJ** | Duels entre les équipes de deux joueurs. | Rejouabilité, classement |
| 💡 **Saisons** | Un 6e univers temporaire (Bleach, Hunter x Hunter…). | Garder le jeu frais |
| 💡 **Offres saisonnières** | Packs Robux limités dans le temps, variétés exclusives d'événement. | Revenus en Robux |
| 💡 **Sons et musiques** | Une musique par univers et des sons d'attaque dédiés (à importer dans Studio). | Ambiance |

---

## Équilibrage (valeurs de départ)

| Élément | Valeur |
|---|---|
| Durée d'un univers | 30 min |
| Raretés de la machine (chance) | Commun 70 % · Rare 22 % · Épique 6,5 % · Légendaire 1,3 % · Mythique 0,2 % · Secret 0,02 % |
| Variétés | environ 15 % des tirages (Or 3,5 % … Arc-en-ciel 0,15 %), ×1,5 à ×6 |
| Pitié (garantie) | Mythique seulement, au bout de 1 000 persos tirés |
| Persos par roulage | 1 (2 ou 3 avec les passes Robux) |
| Marchand ambulant | change de coin et de stock toutes les 8 min |
| Punching-ball | 1 000 coups = 20 gemmes de trait |
| Cases d'unités | 6 au départ, jusqu'à 24 |
| Arbre de compétences | 56 cases, de 150 à 15 000 000 pièces |
| Constructions de la base | 28, de 400 à 3 000 000 pièces |
| Boss | toutes les 8 min (80 000 PV) |
| Événement céleste | toutes les 11 min (pendant 2 min 30) |
| Pièces au départ | 250 + premier perso de la machine offert |
| Équipe | 3 places (jusqu'à 5) |
| Inventaire | 150 persos max |

Ces valeurs se changent dans `src/shared/Config/Economy.luau`, `Mutations.luau`, `EvolutionItems.luau`, `Quests.luau`, `Robux.luau` et `SkillTree.luau` (dossier `src/shared/Config`).
