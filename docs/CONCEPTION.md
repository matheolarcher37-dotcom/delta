# ANIME TYCOON — Document de conception

**Version 3.0** : ta version 1.0, complétée avec tout ce qui est dans le jeu aujourd'hui, ta pépite
(la Fusion Crossover) et tes retours de la version 3. Ces retours portaient sur des persos copiés sur le Kid Naruto,
une carte plus détaillée qui change entièrement à chaque univers, une vraie base tycoon avec la machine ROULER et
l'arbre de compétences, une interface plus belle, des attaques détaillées et la compatibilité console.

> ✅ = dans le jeu · 💡 = idée pour la suite

---

## Concept principal

Un jeu Roblox de type **Tycoon** qui mélange collection de persos d'animé, gestion de base et combat.
Il est inspiré de *Grow a Chicken Fighter* (fonctionnement, base qui grandit) et de *Defeat Anime Bosses* (attaques, style des persos).
Les persos sont de **vrais avatars Roblox R6** aux proportions classiques, avec des noms légèrement changés
(Naruto → Maruto, Gojo → Goju…). On les obtient surtout avec la **machine ROULER** de sa base.

---

## 1. Les persos ✅

- ✅ **40 persos** (8 par univers : 2 Communs, 2 Rares, 2 Épiques, 1 Légendaire, 1 Mythique), **15 ennemis** et **5 boss**.
- ✅ Tous construits comme un **avatar R6 classique** : tête ronde classique, torse 2×2, bras et jambes 1×2, articulations et animations officielles de Roblox.
- ✅ **Maruto ★1 recopie le Kid Naruto** (visage, veste, bandeau). C'est le modèle de référence de tous les styles de persos.
- ✅ Vêtements dessinés comme des habits Roblox classiques (plis, ombres, coutures), visages façon animé, coiffures volumineuses.
- ✅ **3 rangs d'évolution** (★, ★★, ★★★), avec un changement d'apparence visible.
- ✅ On peut **remplacer n'importe quel perso** par un modèle de la Boîte à outils (reconnu par son nom d'origine), par son propre rig R6 ou par des objets du catalogue Roblox.

## 2. La carte ✅

- ✅ **Carte en taille réelle** : hub au centre, anneau de combat autour, 6 bases de 140 × 140, puis une grande île, l'océan et des montagnes enneigées à l'horizon.
- ✅ Carte fixe détaillée : collines, falaises, plage, étang, ruisseau avec pont, rues pavées, vrais arbres détaillés, sol naturel (plus de sol « Lego »).
- ✅ **5 univers**, un nouveau **toutes les 30 minutes** (le même sur tous les serveurs). **TOUTE la carte change** : bâtiments de l'anneau, forêt de l'île, grand monument, montagnes, couleurs du sol, ciel, lumière, particules… et la déco des bases.
  - **Village Ninja** : tour du chef, montagne aux visages, ramen, maisons rondes.
  - **Académie Occulte** : école en bois sombre, pagode, cimetière brumeux, Sanctuaire Malveillant.
  - **Planète des Guerriers** : maisons-dômes, Capsule Corp, voitures volantes, arène du tournoi, tour céleste.
  - **Grand Océan** : port, navires, phare, lagon.
  - **Ère des Pourfendeurs** (la nuit) : ville Taishō, Domaine des Papillons, glycines, rocher fendu, Train de l'Infini.
- ✅ **Faille Inter-Univers** au changement : flash, tremblement, annonce géante.
- ✅ Les arbres, rochers et bâtiments sont **remplaçables** par des modèles de la Boîte à outils (dossier `ServerStorage › ModelesDeco`).

## 3. La base / Tycoon ✅

- ✅ **Machine ROULER** au centre de la base (inspirée de ta capture 5) :
  - une estrade de 6 places avec une ligne lumineuse, un gros bouton hexagonal rouge, la jauge « x10 Chance dans : N », le panneau néon « Garanties » et une arche lumineuse ;
  - animations : le bouton s'enfonce, les places s'allument de la couleur de la rareté, des étincelles jaillissent, et une colonne de lumière monte pour les Légendaires et plus ;
  - on tire dans le pool de l'**univers actuel**, avec **7 raretés** (Commun, Peu commun, Rare, Épique, Légendaire, Mythique, Secret). Un roulage **Chance x10** arrive tous les N roulages, et la **pitié** garantit un Légendaire, un Mythique ou un Secret ;
  - le roulage est gratuit, on paie à la collecte. Le premier perso est offert.
- ✅ **Arbre de compétences hexagonal** (inspiré de ta capture 9) : **56 cases** en 6 branches autour d'un cœur.
  - **Chance** : Chance I à V, Chance Divine, Instinct.
  - **Tirage** : Multi-tirage (2 puis **3 persos par roulage**), Taux d'apparition, Chance x10, Machine Survoltée, **Auto-roulage**, Pitié.
  - **Revenu** : Revenu I à V, Trésor, Butin, Entraînement.
  - **Dégâts** : Dégâts I à V, Frappe, Vitesse.
  - **Critique** : Critique, Dégâts critiques, Lame.
  - **Domaine** : Emplacements I à IV, Grand Domaine, Pas Légers, Œil Céleste.
  - Prix : de 150 à 15 millions de pièces.
- ✅ **28 constructions** sur 3 paliers, toutes visibles : distributeurs, aimant, lanternes, allée de torii, ramen, fontaine, dojo, pagode, jardin de cerisiers, gong, tours de guet, statue dorée, sanctuaire… Les boutons d'achat ont un anneau vert ou rouge, un panneau nom/effet/prix et un **fantôme** de la construction, qui apparaît ensuite avec une animation.
- ✅ **24 cases d'unités** hexagonales : les unités s'y tiennent avec leur nom, leurs étoiles et leur rareté, et remplissent le **coffre** (les pièces roulent sur un tapis). Les cases verrouillées montrent « ??? ». « **Remplacer l'unité** » permet de choisir qui se tient sur une case.
- ✅ **Déco de base par univers** : base Ninja quand c'est le thème Ninja, base Occulte (Gojo) quand c'est le thème Occulte, etc. Elle change les murs, le portail, le sol et les accessoires.
- ✅ Les **reliques** et leurs autels restent une source secondaire de persos (butin du boss, marchand de reliques).

## 4. Le combat ✅

- ✅ Les persos équipés (3 places, jusqu'à 5) **suivent le joueur** et attaquent tout seuls dans l'anneau ; clic sur un ennemi = cible prioritaire.
- ✅ Le joueur se bat aussi, avec une épée achetée au **Forgeron** (8 épées avec effets).
- ✅ **Attaques signature détaillées** (comme *Defeat Anime Bosses*) : chaque attaque spéciale commence par une **charge** (cercle au sol, aura, énergie qui se rassemble). Le nom de l'attaque s'affiche en grand, puis viennent l'explosion, l'onde de choc, le cratère, les fissures et les roches projetées.
  - **8 attaques uniques** : Rasengan, Chidori, Kamehameha, Violet Imaginaire, Découpe, Gatling + Red Hawk, Santoryu Oni Giri, Hinokami Kagura.
  - Les autres persos utilisent **9 familles d'effets** déclinées en variantes.
- ✅ **Boss** toutes les 8 minutes, avec une attaque de zone propre à chacun : piliers de feu, météores de magma, dôme maudit, rayons, éclairs.
- ✅ **Qualité automatique** des effets (PC haute, console moyenne, mobile basse), qui baisse toute seule si le jeu rame. Le menu Options permet de couper la secousse et les flashs.

## 5. Évolution, traits, forge ✅

- ✅ Les persos montent de niveau et **grandissent**. Plafond : ★ = 30, ★★ = 60, ★★★ = 100.
- ✅ **Évolution** à l'Autel d'Éveil avec des pièces et les **matériaux de l'univers du perso**, qui ne tombent que quand cet univers est actif.
- ✅ **Traits** : bonus aléatoires (de Vigueur I à **Monarque**), relancés avec des Cristaux de Trait.
- ✅ **Forgeron** : 8 épées, de l'Épée Rouillée (offerte) à l'Épée Céleste.

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

- ✅ **Auras** (Foudre, Givre, Flamme, Néant, Doré, Arc-en-ciel).
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
| 💡 **Quêtes journalières** | « Roule 50 fois », « Bats 3 boss »… | Fidélisation |
| 💡 **Saisons** | Un 6e univers temporaire (Bleach, Hunter x Hunter…). | Garder le jeu frais |
| 💡 **Monétisation** | Game passes (×2 pièces, auto-roulage dès le début, estrade plus grande), roulages porte-bonheur. | Revenus en Robux |
| 💡 **Sons et musiques** | Une musique par univers et des sons d'attaque dédiés (à importer dans Studio). | Ambiance |

---

## Équilibrage (valeurs de départ)

| Élément | Valeur |
|---|---|
| Durée d'un univers | 30 min |
| Raretés de la machine (chance de base) | Commun 60 % · Peu commun 24 % · Rare 11,5 % · Épique 3,8 % · Légendaire 0,6 % · Mythique 0,09 % · Secret 0,01 % |
| Pitié (garantie) | Légendaire 150 · Mythique 1 200 · Secret 8 000 roulages |
| Chance x10 | tous les 10 roulages (moins avec l'arbre) |
| Estrade | 6 persos en attente |
| Cases d'unités | 6 au départ, jusqu'à 24 |
| Arbre de compétences | 56 cases, de 150 à 15 000 000 pièces |
| Constructions de la base | 28, de 400 à 3 000 000 pièces |
| Boss | toutes les 8 min (80 000 PV) |
| Événement céleste | toutes les 11 min (pendant 2 min 30) |
| Pièces au départ | 250 + 1 relique offerte + premier perso de la machine offert |
| Équipe | 3 places (jusqu'à 5) |
| Inventaire | 150 persos max |

Ces valeurs se changent dans `src/shared/Config/Economy.luau` et `src/shared/Config/SkillTree.luau`.
