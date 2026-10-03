# 🌀 ANIME TYCOON

**Un jeu Roblox de type Tycoon** inspiré de *Grow a Chicken Fighter* : à la place des poulets, tu collectionnes, entraînes et fais évoluer des **héros d'animé en blocs**. À la place des œufs, tu ouvres des **reliques des séries** : parchemins ninja, doigts maudits, boules de cristal, fruits du démon…

![Vue d'ensemble de la carte](docs/images/world.png)

> Toutes les images de ce README sont des rendus réels des modèles du jeu (générés à partir du code, hors Roblox).

---

## 🚀 Lancer le jeu en 2 minutes

1. Installe **Roblox Studio** (gratuit).
2. Télécharge le fichier **[`build/AnimeTycoon.rbxl`](build/AnimeTycoon.rbxl)** de ce dépôt.
3. Double-clique dessus (ou *Fichier → Ouvrir* dans Studio).
4. Clique sur **▶ Play**. La carte, les bases et les décors se construisent tout seuls au démarrage.

**Pour sauvegarder la progression** : publie le jeu (*Fichier → Publier sur Roblox*), puis active
*Paramètres du jeu → Sécurité → « Enable Studio Access to API Services »*. Sans ça, le jeu marche
mais rien n'est sauvegardé (un message te le rappelle en jeu).

### Pour les développeurs (Rojo)

Le code source est dans `src/` et se synchronise avec [Rojo](https://rojo.space) :

```bash
rojo serve                                        # synchro en direct avec le plugin Rojo de Studio
rojo build default.project.json -o AnimeTycoon.rbxl   # ou générer le fichier de jeu
```

---

## 🎮 La boucle de jeu

| Étape | Ce que tu fais |
|---|---|
| 🎁 **Reliques** | La **Machine à Reliques** de ta base vend les reliques de l'univers actuel. Pose-en une sur un **autel** : après quelques secondes, ouvre-la et découvre ton perso (avec une révélation animée). |
| ⚔️ **Combat** | Tes persos équipés **te suivent**. Entre dans la **Zone d'Univers** au centre : ils attaquent tout seuls. Clique sur un ennemi pour le cibler. Plus on va vers le centre, plus les ennemis sont forts. Un **boss** apparaît toutes les 8 minutes. |
| 📈 **Grandir** | Les persos gagnent de l'XP en combat et en s'entraînant sur ta base. En montant de niveau, ils **grandissent** (comme les poulets !). |
| ✨ **Évoluer** | Au niveau max, fais-les évoluer à l'**Autel d'Éveil** (★ → ★★ → ★★★) avec les matériaux de **leur** univers. Leur apparence change (cheveux dorés, Gear 5, bandeau retiré…). |
| 🏠 **Tycoon** | Les persos exposés sur ta base remplissent ton **coffre doré**. Marche sur les **boutons verts** pour construire : autels, dojo, fontaine, statue dorée de ton meilleur perso… |
| 🤝 **Échanges** | Au **Coin des Échanges**, assieds-toi à une table : quand un joueur s'assoit en face, l'échange s'ouvre. |
| 🌀 **Fusion** | Au **Portail Crossover**, fusionne deux persos de deux univers différents pour créer un perso unique. *(La pépite, voir plus bas.)* |

### 🌀 Un nouvel univers toutes les 30 minutes

Le même univers est actif **en même temps sur tous les serveurs**. À chaque changement, une
**Faille Inter-Univers** traverse la carte : le décor de la zone, la lumière, les ennemis, le boss et
les reliques en vente changent.

| Village Ninja | Académie Occulte | Planète des Guerriers |
|---|---|---|
| ![](docs/images/zone_ninja.png) | ![](docs/images/zone_occulte.png) | ![](docs/images/zone_saiyan.png) |
| **Grand Océan** | **Ère des Pourfendeurs** | **Ta base (toutes les améliorations)** |
| ![](docs/images/zone_ocean.png) | ![](docs/images/zone_pourfendeur.png) | ![](docs/images/plot.png) |

---

## 👥 Les 40 personnages

Chaque univers a 8 persos (2 communs, 2 rares, 2 épiques, 1 légendaire, 1 mythique), 3 ennemis,
1 boss, 3 reliques et 1 matériau d'évolution.

![Les personnages](docs/images/personnages.png)

| Univers (inspiration) | Légendaire | Mythique | Épiques | Reliques | Boss |
|---|---|---|---|---|---|
| **Village Ninja** (Naruto) | Ninja Renard | Nuage Écarlate | Ninja Vengeur, Sensei Copieur | Parchemin d'Entraînement / Secret / Interdit | Démon Renard à Neuf Queues |
| **Académie Occulte** (Jujutsu Kaisen) | Le Plus Fort | Roi des Fléaux | Poing Divergent, Héritière Maudite | Talisman Scellé / Coffret Maudit / Doigt du Roi | Fléau de la Calamité |
| **Planète des Guerriers** (Dragon Ball) | Guerrier Légendaire | Dieu de la Destruction | Prince Fier, Fils Prodige | Petite Capsule / Boule de Cristal / Boule Divine | Empereur Glacial |
| **Grand Océan** (One Piece) | Capitaine Élastique | Empereur Roux | Sabreur aux Trois Lames, Cuisinier Flamboyant | Bouteille à la Mer / Coffre au Trésor / Fruit du Démon | Amiral Magma |
| **Ère des Pourfendeurs** (Demon Slayer) | Pilier de la Flamme | Premier Souffle | Pourfendeur de l'Eau, Sœur Démon | Garde de Sabre / Masque de Renard / Lys Araignée Bleu | Lune Supérieure |

<details>
<summary>Voir les persos évolués ★★★</summary>

![Persos évolués](docs/images/personnages_evolues.png)
</details>

### 🎁 Les reliques (à la place des œufs)

![Les reliques](docs/images/relics.png)

| Palier | Prix | Stock / 5 min | Ouverture | Chances |
|---|---|---|---|---|
| Commune | 150 | 8 | 12 s | Commun 70 % · Rare 25 % · Épique 4,5 % · Légendaire 0,5 % |
| Rare | 2 500 | 3 | 60 s | Commun 25 % · Rare 45 % · Épique 24 % · Légendaire 5,5 % · Mythique 0,5 % |
| Légendaire | 40 000 | 1 (60 % du temps) | 3 min | Rare 20 % · Épique 50 % · Légendaire 25 % · Mythique 5 % |

---

## 💎 La pépite : la Fusion Crossover

> Ton document laissait une mécanique à inventer. Voici ma proposition, déjà intégrée au jeu.

Au **Portail Crossover**, tu fusionnes **deux persos de deux univers différents** (Épique ou mieux, évolués
au moins ★★) pour créer un **perso Crossover unique** : coiffure et visage du premier, tenue du second,
nom généré automatiquement.

![Fusions](docs/images/fusions.png)

*Exemples : Ninja Renard + Le Plus Fort = **« Renard de l'Infini »**, Le Plus Fort + Ninja Renard = **« Infini du Renard »**,
Guerrier Légendaire + Capitaine Élastique = **« Saiyen Élastique »**.*

**Pourquoi ça marche avec ton concept :**
- Les univers tournent toutes les 30 min, donc il faut **revenir à plusieurs rotations** pour réunir deux persos compatibles.
- Ça donne une raison forte d'**échanger** : il te manque un perso de l'Académie Occulte ? Trouve quelqu'un à la table d'échange.
- **320 combinaisons** possibles (rareté Crossover, puissance de base = somme des deux ×2) à découvrir dans l'Index : de quoi garder les joueurs longtemps.
- Le Crossover **hérite de la meilleure aura** des deux persos et peut lui-même évoluer jusqu'à ★★★.

### Bonus intégrés : auras et événements célestes

Comme les poulets « électriques » et « néant » de l'image, les persos peuvent avoir une **aura** (Foudre ×1,5,
Givre ×1,6, Flamme ×1,75, Néant ×2, Doré ×3, Arc-en-ciel ×5) avec des effets visuels (éclairs jaunes, cubes violets en orbite…).
Toutes les 11 minutes, un **événement céleste** : *Orage Électrique* (la foudre frappe les bases et donne l'aura Foudre),
*Éclipse du Néant*, *Pluie d'Or* (pièces ×2) ou *Lune de Sang* (matériaux ×2).

D'autres idées pour la suite sont dans le [document de conception](docs/CONCEPTION.md).

---

## 🏗️ Améliorations de la base (boutons « tycoon »)

| Amélioration | Prix | Effet | | Amélioration | Prix | Effet |
|---|---|---|---|---|---|---|
| Lanternes de Papier | 600 | +10 % revenus | | Autel de Relique #2 | 1 500 | +1 autel |
| Tatami d'Entraînement | 3 000 | +50 % XP | | Arène Agrandie | 12 000 | +4 persos exposés |
| Aimant à Pièces | 7 500 | +25 % pièces de combat | | Bannière d'Équipe #4 | 25 000 | +1 place d'équipe |
| Fontaine de Chakra | 35 000 | +25 % revenus | | Autel de Relique #3 | 50 000 | +1 autel |
| Horloge Mystique | 80 000 | −25 % temps d'ouverture | | Grande Arène | 220 000 | +6 persos exposés |
| Dojo Légendaire | 150 000 | +100 % XP | | Autel de Relique #4 | 450 000 | +1 autel |
| Coffre du Shogun | 300 000 | +50 % pièces de combat | | Bannière d'Équipe #5 | 600 000 | +1 place d'équipe |
| Statue Dorée | 900 000 | +50 % revenus | | Sablier Divin | 1 500 000 | −25 % temps d'ouverture |

Chaque bouton n'apparaît qu'une fois le précédent acheté, et chaque achat **construit** quelque chose de visible dans la base.

---

## 🛠️ Personnaliser le jeu

Tout l'équilibrage est dans des fichiers de configuration faciles à lire :

| Je veux… | Fichier |
|---|---|
| Renommer un perso, changer ses couleurs, sa coiffure, ses accessoires | `src/shared/Config/Characters.luau` |
| Changer les univers, reliques, ennemis, ambiance lumineuse | `src/shared/Config/Universes.luau` |
| Changer les prix, la durée des univers (30 min), les boss, les améliorations | `src/shared/Config/Economy.luau` |
| Changer les raretés ou les auras | `src/shared/Config/Rarities.luau`, `src/shared/Config/Auras.luau` |
| Ajouter des admins | `ADMINS` dans `src/server/Services/AdminService.luau` |

**Coiffures disponibles** : `short`, `spiky`, `spiky_back`, `wild`, `tall_spiky`, `long`, `ponytail`, `ponytail_spiky`, `slick`, `slick_up`, `bob`, `flame`, `curly`, `messy`, `cover_eye`, `bald`, `none`.
**Accessoires** : `headband`, `mask_lower`, `whiskers`, `blindfold`, `straw_hat`, `cape`, `haori_checker`, `boar_head`, `swords`, `tails9`… (voir `CharacterBuilder.luau`).

### 🧪 Commandes de test (dans Studio, ou pour le créateur du jeu)

Tape dans le chat `/at <commande>` (ou `!<commande>`) :

| Commande | Effet |
|---|---|
| `/at argent 100000` | Ajoute des pièces |
| `/at univers` | Passe à l'univers suivant (pour voir la Faille !) |
| `/at boss` | Fait apparaître le boss |
| `/at event orage` | Lance un événement (`orage`, `eclipse`, `pluie_or`, `lune_sang`) |
| `/at relique 3 5` | Donne 5 reliques légendaires de l'univers actuel |
| `/at materiaux 50` | Donne 50 de chaque matériau |
| `/at niveau 30` · `/at etoiles 3` | Monte le niveau / les étoiles de ton équipe |
| `/at reset` | Remet ta sauvegarde à zéro |

---

## ⚠️ Droits d'auteur

Les persos sont des **clins d'œil** (noms parodiques, modèles originaux en blocs) : aucun nom, logo ou image
officiel n'est utilisé. C'est la pratique des gros jeux d'animé sur Roblox, et ça limite le risque de
signalement. Si tu remets les vrais noms (Naruto, Gojo…), Roblox peut modérer le jeu : c'est à tes risques.

---

## 🧱 Architecture du code

```
src/
├── shared/                 (ReplicatedStorage.Shared — partagé serveur/client)
│   ├── Config/             Univers, persos, économie, raretés, auras, disposition de la carte
│   └── Modules/            CharacterBuilder (persos en blocs), RelicBuilder, Formulas, Remotes
├── server/                 (ServerScriptService.Server)
│   ├── Main.server.luau    Construit la carte puis démarre les services
│   ├── World/              WorldBuilder (carte), UniverseDecor (5 décors)
│   └── Services/           Data, Plot, Character, Team, Combat, Universe, Shop, Hatch,
│                           Evolution, Fusion, Trade, Event, Leaderboard, Admin
└── client/                 (StarterPlayerScripts.Client)
    ├── UI/                 HUD, Inventaire, Boutique, Révélation, Éveil, Fusion, Échange, Index, Guide
    └── Controllers/        Animations procédurales, effets de combat, auras, étiquettes « LV.67 »
```

- **Serveur autoritaire** : toutes les actions (achats, ouvertures, échanges…) sont vérifiées côté serveur.
- **Sauvegarde** avec verrou de session (pas de duplication entre serveurs), sauvegarde auto toutes les 90 s.
- **Échanges atomiques** : validation au dernier moment, transfert sans attente, sauvegarde immédiate.
- **Tout est procédural** : aucun asset externe à importer, le jeu fonctionne dès l'ouverture du fichier.

### ✅ Vérifications

Les outils (Rojo, Selene, StyLua, Lune) sont listés dans `rokit.toml`.

```bash
selene src                       # analyse statique (0 erreur, 0 avertissement)
stylua --check src tests         # formatage
rojo build default.project.json -o build/AnimeTycoon.rbxl
lune run tests/smoke.luau        # construit les 40 persos, 80 fusions, reliques, carte, 5 décors, bases
lune run tests/integration.luau  # simule des joueurs : relique, combat, boss, tycoon, éveil, fusion, échange, rotation, sauvegarde
lune run tests/client_smoke.luau # serveur + client : tous les menus, effets et animations
```

Ces tests tournent hors de Roblox avec [Lune](https://lune-org.github.io/docs). Ils ne remplacent pas une
vraie partie dans Studio : la physique, le rendu et les sensations de jeu restent à tester en jouant.
