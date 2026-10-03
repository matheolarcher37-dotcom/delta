# ANIME TYCOON — Document de conception

**Version 2.0** : ta version 1.0, complétée avec ce qui est implémenté dans le jeu, ma « pépite », tes demandes de la version 2 (persos R6 façon jeux d'animé récents, hub central, anneau d'univers, épées, traits, édition dans Studio) et des idées pour la suite.

> ✅ = implémenté dans le jeu · 💡 = idée proposée pour la suite

---

## Concept principal

Un jeu Roblox de type **Tycoon** qui mélange combat, collection de personnages d'animé, évolution et gestion de base.
Il est inspiré de *Grow a Chicken Fighter* : même carte (herbe en damier, arènes de terre, clôtures en bois, style voxel),
même fonctionnement, mais avec des **persos d'animé** à la place des poulets et des **reliques des séries** à la place des œufs.
Les persos ont le format **avatar Roblox R6** des jeux d'animé récents (*Defeat Anime Bosses*…), avec des noms légèrement changés (Naruto → Maruto, Gojo → Goju…).

---

## 1. Les maps ✅

- ✅ **Un hub central** (zone sûre) avec 6 stands et leurs vendeurs : Défi (arène du boss), Fusionner, Traits, Forgeron, Faire évoluer, Index.
- ✅ **Un nouvel univers toutes les 30 minutes** dans l'**anneau d'univers** qui entoure le hub (c'est l'anneau qui change, pas le centre).
- ✅ Le même univers est actif **en même temps sur tous les serveurs** (calculé à partir de l'heure), ce qui est utile pour les échanges.
- ✅ **5 univers** : Village Ninja (Naruto), Académie Occulte (Jujutsu Kaisen, avec Goju), Planète des Guerriers (Dragon Ball), Grand Océan (One Piece), Ère des Pourfendeurs (Demon Slayer).
- ✅ Chaque univers a son **décor** (maisons, portiques, château d'eau, temple, pics rocheux, bateau pirate, glycines…), sa **lumière** (jour, crépuscule violet, nuit de pleine lune…), ses **particules**, ses **3 ennemis** et son **boss**.
- ✅ **Faille Inter-Univers** au changement : flash, tremblement de caméra, annonce géante, puis le décor change.

## 2. Le système de combat ✅

- ✅ Les persos équipés (3 places, jusqu'à 5 avec les améliorations) **suivent le joueur** et attaquent automatiquement dans la zone.
- ✅ **Clic sur un ennemi** = cible prioritaire (un anneau rouge s'affiche dessous).
- ✅ **3 bandes de difficulté** dans l'anneau : faibles près du hub, forts au bord.
- ✅ **Le joueur se bat aussi** : il commence avec une Épée Rouillée toute faible et achète de meilleures épées au **Forgeron** (8 épées, de 6 à 8 000 dégâts, avec effets de vent, foudre, flammes, fumée noire, glace…).
- ✅ **9 types d'attaques** avec effets visuels et particules : poing, orbe (Orbe Spirale, Violet Imaginaire…), rayon (Vague Déferlante…), entaille, éclairs, flammes, fumée noire, cristaux de glace, bras élastique.
- ✅ Une **attaque spéciale** toutes les 6 attaques (×3 dégâts, nom de l'attaque affiché façon anime), coups critiques.
- ✅ Les ennemis ripostent : un perso K.O. revient après 8 secondes.
- ✅ **Boss** toutes les 8 minutes dans l'**arène rocheuse** de l'anneau, avec une onde de choc de zone et des récompenses partagées selon les dégâts infligés (et une chance de relique légendaire).
- ✅ Récompenses : pièces (qui volent vers le joueur), XP pour l'équipe, **matériaux d'évolution** de l'univers.

## 3. La base / Tycoon ✅

- ✅ Chaque joueur reçoit une **base** (6 par serveur), avec son nom sur le portail.
- ✅ **Machine à Reliques** (le tirage) : vend les 3 reliques de l'univers actuel, stock renouvelé toutes les 5 minutes.
- ✅ **Autels** : on y pose une relique, on attend, on l'ouvre (révélation animée avec rayons de lumière).
- ✅ **Arène d'exposition** : les persos hors équipe s'y entraînent (XP passive), font des petites actions (coups de poing, salut, pose) et **remplissent le coffre doré** (revenus passifs).
- ✅ **16 améliorations** sous forme de boutons à marcher dessus, débloqués progressivement. Chaque achat construit une structure : lanternes, tatami, fontaine de chakra, dojo, statue dorée de ton meilleur perso, horloge, sablier, gradins…

## 4. Système d'évolution ✅

- ✅ Les persos montent de niveau et **grandissent** (taille visible).
- ✅ Plafond de niveau par rang : ★ = 30, ★★ = 60, ★★★ = 100.
- ✅ À l'**Autel d'Éveil**, évolution avec des pièces + les **matériaux de l'univers du perso** (Fragment de Chakra, Énergie Maudite, Éclat de Ki, Perle des Abysses, Sang de Démon).
- ✅ Comme ces matériaux ne tombent que quand **leur** univers est actif, ça pousse à revenir à chaque rotation.
- ✅ **L'apparence change** à l'évolution : Maruto en mode Ermite puis Renard, Goju sans son bandeau, cheveux dorés pour les guerriers, Loffy tout blanc (Gear 5)…
- ✅ **Traits** : bonus aléatoires (Vigueur, Célérité, Fortuné, Vampire… jusqu'à Monarque), obtenus avec les reliques ou relancés avec des Cristaux de Trait au stand Traits.

## 5. Les échanges ✅

- ✅ **Coin des Échanges** : un ponton avec un auvent rayé, des lanternes et **2 tables**.
- ✅ On s'assoit d'un côté : quand quelqu'un s'assoit en face, la fenêtre d'échange s'ouvre.
- ✅ On propose des persos, des matériaux, des pièces. Les deux joueurs cliquent sur « Prêt », puis un **compte à rebours de 3 secondes** valide l'échange.
- ✅ Sécurité : toute modification annule le « Prêt », les persos **verrouillés 🔒** ne peuvent pas être échangés, la validation se fait au dernier moment et le transfert est **atomique** (pas de duplication possible).

## 6. La pépite ✅ : la Fusion Crossover

> « Une mécanique reste à définir. Elle sera ajoutée dès que tu trouveras ta petite pépite. »

**La Fusion Crossover** (stand Fusionner du hub) : on fusionne **deux persos de deux univers différents** pour créer un perso **Crossover** unique.

- Conditions : Épique ou mieux, évolués au moins ★★, univers différents, 100 000 pièces + 15 matériaux de chaque univers.
- Résultat : coiffure, visage et accessoires de tête du **premier** + tenue et accessoires du corps du **second**, nom composé (préfixe de l'un + suffixe de l'autre).
  - Maruto + Goju = **Renard de l'Infini**
  - Goju + Maruto = **Infini du Renard** (l'ordre compte !)
  - Rengoko + Sukana = **Flamme des Fléaux**
- Rareté **Crossover** (au-dessus de Mythique), puissance de base = (puissance des deux) × 2. Le Crossover hérite de la **meilleure aura** et du **meilleur trait**, et peut évoluer jusqu'à ★★★.
- **320 combinaisons** à découvrir dans l'Index.

**Pourquoi c'est la bonne pépite pour ce jeu :**
1. Elle **exploite la rotation des univers** : il faut jouer sur plusieurs rotations pour réunir deux persos compatibles.
2. Elle **nourrit les échanges** : il te manque un perso d'un autre univers ? Va à la table d'échange.
3. Elle donne un **objectif de fin de partie** quasi infini (320 Crossovers) sans avoir à créer de nouveaux modèles : le générateur de persos mélange tout seul les looks.
4. C'est **le fantasme des fans d'animé** : « et si Naruto avait les pouvoirs de Gojo ? »

### Bonus implémentés en plus de la pépite

- ✅ **Auras** (comme les poulets électriques et néant de l'image) : Foudre, Givre, Flamme, Néant, Doré, Arc-en-ciel. Elles multiplient la puissance (de ×1,5 à ×5) et ont des effets visuels animés.
- ✅ **Événements célestes** toutes les 11 minutes : Orage Électrique (la foudre frappe les bases et peut donner l'aura Foudre), Éclipse du Néant, Pluie d'Or (pièces ×2), Lune de Sang (matériaux ×2).
- ✅ **Index** (collection) par univers, avec les persos non découverts en « ? ».
- ✅ **Classement** global « Les plus puissants » + panneau d'information sur l'univers en cours.
- ✅ **Objectif guidé** en bas de l'écran pour les nouveaux joueurs + **Guide** complet en jeu.
- ✅ Boutons de **téléportation** rapide : Base, Zone, Troc, Hub, Boss.
- ✅ **Tout est visible et modifiable dans Studio** sans lancer la partie : carte, décors des 5 univers, base d'exemple et galerie de tous les persos (repris par le jeu au lancement). On peut aussi remplacer un perso par son propre modèle R6 ou par des objets du catalogue Roblox (`Config/Avatars.luau`).

---

## 7. Idées pour la suite 💡

| Idée | Description | Intérêt |
|---|---|---|
| 💡 **Expansion de Domaine** | Une jauge se remplit en combat. Une fois pleine, ton équipe déploie un domaine (le décor change autour de toi pendant 15 s, et tes persos font +100 % de dégâts). | Moment « wow » très anime, se montre aux autres joueurs |
| 💡 **Raids inter-univers** | Pendant les 2 dernières minutes d'un univers, le boss du suivant envahit la zone : tous les joueurs coopèrent. | Rend la fin de rotation excitante |
| 💡 **Arène JcJ** | Duels entre les équipes de deux joueurs dans une arène, comme le visuel de *Grow a Chicken Fighter* (poulet contre poulet). | Rejouabilité, classement compétitif |
| 💡 **Quêtes journalières** | « Bats 50 ennemis du Grand Océan », « Ouvre 3 reliques »… avec des récompenses en reliques. | Fidélisation au quotidien |
| 💡 **Saisons** | Un 6e univers temporaire (Bleach, Hunter x Hunter, My Hero Academia…) pendant un mois. | Garder le jeu frais |
| 💡 **Monétisation** | Game passes : ×2 pièces, 6e place d'équipe, autel supplémentaire, ouverture rapide ; Developer Products : reliques premium. | Revenus en Robux |
| 💡 **Sons et musiques** | Une musique par univers + des sons d'attaque dédiés (à importer dans Studio). | Ambiance |

---

## Équilibrage (valeurs de départ)

| Élément | Valeur |
|---|---|
| Durée d'un univers | 30 min |
| Réapprovisionnement de la Machine à Reliques | 5 min |
| Boss | toutes les 8 min (80 000 PV) |
| Événement céleste | toutes les 11 min (pendant 2 min 30) |
| Pièces au départ | 250 + 1 relique offerte |
| Équipe | 3 places (jusqu'à 5) |
| Persos exposés sur la base | 8 (jusqu'à 18) |
| Inventaire | 150 persos max |

Toutes ces valeurs se changent dans `src/shared/Config/Economy.luau`.
