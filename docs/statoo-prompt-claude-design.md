# Statoo — Prompts pour Claude Design

**Ce qui change par rapport à Stitch.** Claude Design produit du code (HTML/CSS)
et non une image : les hachures à 45°, `tabular-nums`, les cibles de 52 px et les
valeurs hexadécimales exactes sont tenables au pixel près. Il lit aussi un
document de charte complet et le retient d'un écran à l'autre. Conséquence
directe : **on ne pilote plus par corrections défensives, on pilote par
composants**.

La méthode :

1. **Message 0** — coller le brief et joindre `statoo-design-system.md` au chat.
2. **Message 1** — faire construire la *planche de composants* avant tout écran.
   C'est l'étape qui fait toute la différence : tous les écrans suivants s'y
   réfèrent au lieu de réinventer un bouton à chaque fois.
3. **Messages 2 à 8** — les écrans, groupés par famille (3 à 4 par message).
4. **Message 9** — la passe de vérification.

Les prompts sont en français : Claude Design ne traduit pas spontanément
l'interface, contrairement à Stitch. Aucun garde-fou anti-traduction n'est
nécessaire.

---

## Message 0 — Cadrage

> Joindre `statoo-design-system.md` au chat avant d'envoyer ce message.

```
Je te joins le design system complet d'une application Android que je développe,
Statoo. Lis-le en entier : il fait autorité sur toutes les décisions visuelles,
et je te demande de ne rien ajouter qui n'y figure pas.

Contexte produit en trois phrases. Statoo est le carnet personnel de
l'organisateur d'un foot 5x5 entre amis. Un seul utilisateur, un seul appareil,
aucun compte, aucune fonction sociale, tout hors ligne. L'app se remplit au bord
du terrain, le soir, à une main, et doit permettre d'enregistrer une séance en
moins de deux minutes.

Trois interdits qui viennent du produit, pas du goût :
- aucune gamification (pas de badge, de série, de niveau, d'étoile, de note de
  joueur, de vote du homme du match) — ce sont des mécaniques multi-utilisateurs
  et l'app est mono-utilisateur ;
- aucune hiérarchie entre l'équipe A et l'équipe B — c'est le même groupe d'amis
  coupé en deux, donc jamais de logique domicile/extérieur, jamais deux couleurs
  opposées ; la distinction se fait par la matière, aplat jaune contre hachure ;
- aucun chiffre commenté ou félicité — l'app compte, elle ne juge pas.

Cadre technique de la maquette : frames mobiles 390 × 844, thème sombre unique,
Android. Toutes les valeurs viennent des tokens du document joint, aucune valeur
brute inventée.

Ne produis rien pour l'instant. Dis-moi d'abord, en cinq lignes, ce que tu as
retenu de la direction artistique et du composant signature. Je corrige si tu as
mal lu, puis on construit.
```

---

## Message 1 — La planche de composants

C'est le message le plus important du lot. Tout le reste en dépend.

```
Construis d'abord une planche de composants sur une seule page large, avant tout
écran. Elle sert de référence à tout ce qui suivra : chaque composant y est
nommé, dans un état par défaut et dans ses variantes.

1. ScoreBar — le composant signature.
   Barre horizontale divisée proportionnellement au score. Partie gauche
   (équipe A) : aplat #FFC94F. Partie droite (équipe B) : PAS une seconde
   couleur, mais des hachures à 45° de traits fins #8CA096 sur fond #1B2721,
   avec un contour 1px #2A3831. Minimum 4px par côté pour qu'une équipe à 0
   reste visible.
   Variantes à montrer : xs 2px (4—2), sm 6px (2—2), lg 40px (4—2),
   cas 0—0 (deux moitiés vides séparées d'un filet 1px), et état brouillon
   (contour pointillé, aucun remplissage).

2. StatStepper — le composant le plus utilisé de l'app.
   [bouton − 52px] [valeur 44px de large, 22px expanded bold, tabular-nums]
   [bouton + 52px], le tout aligné à droite, le libellé 13px à gauche.
   Boutons #1B2721, contour 1px #2A3831, glyphes #EAF0EC.
   Variantes : valeur 3, valeur 0 avec le "−" désactivé en #3F4E48 mais jamais
   masqué (la position ne bouge pas), et un focus visible #FFC94F.

3. PlayerRow — avatar 36px en initiales sur #1B2721, nom 15px + surnom 13px
   #8CA096, trois chiffres à droite en tabular-nums (J / Pts / Buts).
   Variantes : actif, et archivé (nom et chiffres en #8CA096, avatar à 50 %
   d'opacité, petit badge "Archivé").

4. Team pills — "ÉQUIPE A" en aplat #FFC94F sur texte #0B120F ;
   "ÉQUIPE B" en contour avec remplissage hachuré 45°, texte #EAF0EC.
   Les deux ont exactement le même poids visuel.

5. Badges — "Brouillon" et "Amical" : contour 1px #3F4E48, texte #8CA096 et
   #D3DED8. Format "5v5" : même traitement. Pastille d'écart de buts : point
   #FF7361 de 6px. Une séance close ne porte aucun badge.

6. Boutons — primaire pleine largeur 56px #FFC94F texte #0B120F ; ghost 52px
   contour 1px #2A3831 ; destructif 52px #F0503C texte blanc ; état désactivé.

7. Bandeau d'avertissement — fond #260907, contour 1px #A22C1E, sans icône et
   sans bouton d'action. Il est informatif, pas bloquant : il ne doit pas
   ressembler à une erreur.

8. Barre d'onglets basse, 64px, 5 entrées icône + libellé :
   Accueil · Joueurs · Séances · Classement · Stats.
   Actif #FFC94F, inactif #8CA096.

Contraintes transverses : aucune ombre portée, aucun dégradé, aucune
illustration, aucune icône décorative. La hiérarchie vient uniquement de la
valeur du fond (#0B120F → #121B17 → #1B2721) et des filets 1px #2A3831.
Tous les chiffres alignés en colonne portent font-variant-numeric: tabular-nums.
```

**Point de contrôle avant de continuer.** Regarder trois choses : les hachures
sont bien des traits fins et non un aplat gris ; le bouton `−` désactivé occupe
toujours sa place ; le bandeau d'avertissement ne ressemble pas à une erreur
bloquante. Corriger ici, une fois, plutôt que sur quinze écrans.

---

## Message 2 — Jeu de données

```
Avant les écrans, fixons le contenu. Utilise ces données partout, sans jamais
les changer d'un écran à l'autre : c'est ce qui fera tenir la maquette debout.

Joueurs actifs : Karim (surnom Kaka), Yannick, Ismaël (Isma), Prosper, Éric,
Adamou, Rachid, Sylvain, Boris, Landry, Marc, Théo.
Archivés : Didier, Serge.

Classement — J / V / N / D / Pts / Pts par match :
Karim 18 11 3 4 36 2,00 · Yannick 17 10 2 5 32 1,88 ·
Ismaël 16 8 4 4 28 1,75 · Prosper 15 7 3 5 24 1,60 ·
Adamou 12 5 3 4 18 1,50 · Rachid 11 4 3 4 15 1,36 · Éric 9 3 3 3 12 1,33.
Sous le seuil des 50 % : Éric (il manque 3 séances), Sylvain (il manque 5).

Séances, de la plus récente à la plus ancienne :
sam. 9 août — brouillon, aucun score ;
mar. 4 août 20:30 — 5v5, 4 — 2 ;
jeu. 30 juil. — 6v5, 3 — 3, amicale ;
mar. 28 juil. — 5v5, 1 — 5, avec un écart de buts ;
mar. 21 juil. — 5v5, 2 — 1.

Totaux du groupe : 24 séances jouées dont 21 classées, 12 joueurs actifs sur 14,
138 buts marqués, 121 attribués (écart 17), 5,75 buts par séance, 74 passes,
19 cartons jaunes, 2 rouges.

Buteurs : Karim 24, Prosper 14, Yannick 11, Ismaël 9, Adamou 7.
Passeurs : Yannick 15, Karim 11, Adamou 8, Rachid 6, Boris 4.

Formats de date à l'écran : "Mar. 4 août · 20:30". Décimales à la virgule.
```

---

## Message 3 — Accueil, Joueurs, Fiche joueur, Formulaire joueur

```
Quatre écrans, en réutilisant strictement les composants de la planche.

ÉCRAN 1 — Accueil.
En-tête : "Statoo" à gauche en display expanded, icône réglages #8CA096 à droite.
Carte "dernière séance" : eyebrow "DERNIÈRE SÉANCE", ScoreBar sm 6px en 4—2,
le score "4 — 2" en 32px avec "Équipe A" / "Équipe B" en 13px sous chaque
chiffre, puis la méta "Mar. 4 août · 20:30 · 5v5".
Bouton primaire pleine largeur 56px : "Nouvelle séance".
Carte "CLASSEMENT" : le top 3 (1 Karim 36, 2 Yannick 32, 3 Ismaël 28), le rang 1
en #FFC94F et rien d'autre de particulier, puis un lien "Voir le classement".
Pied de page en eyebrow #8CA096 : "SAUVEGARDÉ IL Y A 2 JOURS".
Onglet Accueil actif.

ÉCRAN 2 — Joueurs.
Titre "Joueurs", bouton "+" en haut à droite, champ de recherche 44px
placeholder "Rechercher un joueur", puis la liste de PlayerRow (Karim, Yannick,
Ismaël, Prosper, Adamou, Éric, Rachid, Sylvain), en-têtes de colonne en eyebrow
J · PTS · BUTS au-dessus de la première ligne seulement.
Sous un filet, une section repliée avec chevron : "Archivés (2)".
Onglet Joueurs actif.

ÉCRAN 3 — Fiche joueur (Karim).
Chevron retour, avatar 56px "KA", nom "Karim" en title, surnom "Kaka",
petit bouton contour "Modifier".
Bloc "Synthèse" : trois grands chiffres en 32px avec eyebrow dessous —
"18 SÉANCES", "1,83 PTS/MATCH", "61 % VICTOIRES" — puis une ligne
"11 V · 3 N · 4 D" et "36 points".
Bloc "STATISTIQUES BRUTES" : lignes libellé/valeur séparées de filets —
Buts 24, Passes 11, Cartons jaunes 3, Cartons rouges 0, Apparitions 20.
Bloc "HISTORIQUE" : quatre lignes de séance, ScoreBar xs en tête de chaque ligne,
date à gauche, la contribution du joueur en 13px #8CA096 ("1 but · 1 passe"),
score à droite. Pas de barre d'onglets, c'est une vue poussée.

ÉCRAN 4 — Nouveau joueur.
Feuille modale par le bas sur la liste assombrie, coins hauts 14px, poignée 4px.
Titre "Nouveau joueur". Champs 52px : "Nom" rempli avec "Landry",
"Surnom (optionnel)" vide, et une ligne "Ajouter une photo" avec un cercle 48px.
Sous le champ nom, un avertissement non bloquant en 13px #FF7361 :
"Un joueur porte déjà ce nom. Vous pouvez continuer."
Deux boutons empilés : "Annuler" en ghost au-dessus, "Enregistrer" en primaire
en dessous — l'action principale est toujours la plus basse, la plus proche du
pouce.
```

---

## Message 4 — Le parcours de séance (le cœur de l'app)

```
Cinq écrans qui forment un parcours. C'est la partie critique : elle doit se
lire comme une seule séquence, du brouillon à la clôture.

ÉCRAN 5 — Séances, la liste.
Titre "Séances", bouton "+". Cartes antéchronologiques, chacune construite avec
un ScoreBar xs 2px en tout haut de carte, puis une ligne méta : date à gauche,
badges, score à droite en 18px expanded.
Sam. 9 août — barre pointillée, badge "Brouillon", score en tiret cadratin muet.
Mar. 4 août · 20:30 — barre 4/2, badge "5v5", "4 — 2".
Jeu. 30 juil. — barre 3/3, badges "6v5" et "Amical", "3 — 3".
Mar. 28 juil. — barre 1/5, pastille #FF7361 avant la date, "1 — 5".
Mar. 21 juil. — barre 2/1, "2 — 1".
Onglet Séances actif.

ÉCRAN 6 — Nouvelle séance.
Section "QUAND" : deux champs côte à côte, "Mar. 4 août 2026" et "20:30".
Section "PRÉSENTS · 10 SÉLECTIONNÉS" : grille deux colonnes de puces 44px.
Sélectionnée = contour 1px #FFC94F, texte #EAF0EC. Non sélectionnée = contour
1px #2A3831, texte #8CA096. Sélectionnés : les dix premiers joueurs de la liste.
Non sélectionnés : Marc, Théo.
Section "OPTIONS" : deux lignes libellé + interrupteur, séparées d'un filet.
"Séance classée" / sous-libellé "Compte pour le classement" — actif, en #FFC94F.
"Autoriser des effectifs inégaux" / "Par exemple 6 contre 4" — inactif.
Barre collée en bas : bouton primaire 56px "Créer la séance".

ÉCRAN 7 — Détail de séance, composition (brouillon).
En-tête : ScoreBar lg 40px en pointillés sans remplissage, "— —" en 44px muet,
méta "5v5 · 10 présents", badge "Brouillon".
Deux colonnes A et B séparées par un unique filet vertical 1px #2A3831, chacune
coiffée de son team pill. Cinq lignes de 44px par colonne : avatar 28px en
initiales, prénom, et une poignée de déplacement #8CA096 sur le bord extérieur.
A : Karim, Ismaël, Rachid, Boris, Landry. B : Yannick, Prosper, Éric, Adamou,
Sylvain.
Sous les colonnes, bouton ghost pleine largeur "Tirer au sort".
Barre collée en bas : "Saisir les statistiques".

ÉCRAN 8 — Confirmation d'écrasement.
Écran 7 assombri à 60 %, feuille modale par le bas.
Titre "Remplacer la composition actuelle ?".
Corps 15px #8CA096 : "Le tirage écrase les équipes que vous avez ajustées à la
main. Les statistiques déjà saisies sont conservées."
"Annuler" en ghost au-dessus, "Tirer au sort" en destructif #F0503C en dessous.

ÉCRAN 9 — Saisie des statistiques. L'écran le plus important de l'app.
En-tête "SCORE" : deux StatStepper côte à côte, un par équipe, valeur en 44px,
team pill au-dessus de chacun. Valeurs 4 et 2. Sous eux, ScoreBar lg 40px
remplie 4/2.
Puis une liste de joueurs en accordéon, un seul ouvert à la fois.
Lignes repliées 44px : avatar, prénom, résumé compact à droite "2 B · 1 P" en
13px #8CA096, chevron.
La ligne "Karim" est ouverte et révèle quatre StatStepper : "Buts" 2,
"Passes" 1, "Cartons jaunes" 0, "Cartons rouges" 0 — avec le "−" désactivé sur
les deux dernières.
Section "BUTS NON ATTRIBUÉS" : deux steppers plus petits, "Équipe A" 1 et
"Équipe B" 0, avec la ligne d'aide 13px : "Buts marqués sans buteur identifié
(csc, oubli)."
Barre collée en bas : bouton primaire 56px "Clôturer la séance".
```

---

## Message 5 — Les deux variantes de l'écran de saisie

```
Deux variantes de l'écran 9, à partir du même écran.

ÉCRAN 10 — Avec le bandeau d'écart de buts.
Insère, juste au-dessus de la barre d'action collée, le bandeau d'avertissement
de la planche : fond #260907, contour 1px #A22C1E, sans icône, sans bouton.
Première ligne 13px gras #FF7361 : "Écart de buts".
Seconde ligne 13px #EAF0EC : "Équipe A : 4 marqués, 3 attribués. Vous pouvez
clore quand même."
Le bouton "Clôturer la séance" reste actif et primaire : l'avertissement est
informatif, il ne bloque rien et ne prend pas le focus.

ÉCRAN 11 — La séance close, en lecture seule.
ScoreBar lg 40px remplie 4/2, les chiffres "4" et "2" en 44px de part et d'autre,
"Équipe A" / "Équipe B" en 13px dessous, méta "Mar. 4 août · 20:30 · 5v5".
Aucun badge : une séance close est la norme, on ne badge pas la norme.
Deux colonnes A/B séparées d'un filet, chaque prénom suivi à droite de sa
contribution en 13px #8CA096 : Karim "2 B · 1 P", Ismaël "1 B", Prosper avec un
rectangle jaune vertical de 3 × 10px pour le carton, les autres sans rien.
Sous la colonne A, une ligne muette : "Buts non attribués · 1".
Tout en bas, sous un filet, deux liens : "Rouvrir la séance" en #EAF0EC et
"Supprimer" en #FF7361.
```

---

## Message 6 — Classement et statistiques

```
Quatre écrans. Le classement est l'écran qu'on rouvre le mardi soir : c'est lui
qui mérite le meilleur traitement typographique de l'app.

ÉCRAN 12 — Classement, onglet Points.
Titre "Classement", segmented control 44px sur #1B2721 : "Points" actif (pastille
#121B17, texte #EAF0EC, soulignement 1px #FFC94F) et "Pts/match" inactif.
Tableau, en-têtes en eyebrow : (vide) · JOUEUR · J · V · N · D · PTS · PTS/M.
Lignes de 48px séparées de filets 1px, chiffres en tabular-nums alignés à droite,
prénom en sans à gauche, chiffres en display.
Les sept lignes du jeu de données.
Le rang 1 : le numéro en #FFC94F, strictement rien d'autre — pas de médaille,
pas de fond doré, pas de couronne.
La colonne PTS en #EAF0EC, toutes les autres colonnes chiffrées en #8CA096 :
l'œil doit tomber sur la colonne de tri.
La colonne J est toujours visible. Aucun défilement horizontal : si ça ne tient
pas, retire une colonne.
Onglet Classement actif.

ÉCRAN 13 — Classement, onglet Pts/match.
Même tableau retrié, PTS/M passe en #EAF0EC et PTS en #8CA096.
Sous la dernière ligne éligible, un filet 1px puis un bloc entièrement en
#8CA096 avec l'eyebrow "SOUS LE SEUIL". Deux lignes où les chiffres sont
remplacés par une phrase : "Éric — il manque 3 séances" et "Sylvain — il manque
5 séances". N'écris jamais "non éligible" : donne toujours le décompte réel.

ÉCRAN 14 — Classements secondaires.
Le même écran Classement, défilé plus bas : trois cartes empilées, eyebrows
"MEILLEURS BUTEURS", "MEILLEURS PASSEURS", "CARTONS", cinq lignes chacune
(rang, prénom, chiffre à droite).
La carte cartons montre par ligne deux indicateurs : un rectangle jaune 3 × 10px
avec son compte, un rectangle rouge avec le sien — Prosper 4/0, Boris 3/1,
Karim 3/0, Éric 2/0, Sylvain 1/0.
Note de bas de bloc en 13px #8CA096 : "Ces classements comptent toutes les
séances, amicales incluses."

ÉCRAN 15 — Statistiques.
Grille deux colonnes de tuiles : chiffre 32px au-dessus d'un eyebrow —
24 SÉANCES JOUÉES, 21 DONT CLASSÉES, 12 JOUEURS ACTIFS, 14 JOUEURS AU TOTAL,
138 BUTS TOTAUX, 5,75 BUTS PAR SÉANCE.
Carte "ATTRIBUTION DES BUTS" : "Buts marqués 138", "Buts attribués à un joueur
121", "Écart 17" avec la valeur en #FF7361, puis la ligne d'aide
"Buts marqués sans buteur identifié."
Carte "DISCIPLINE" : Passes décisives 74, Cartons jaunes 19, Cartons rouges 2.
Onglet Stats actif.
```

---

## Message 7 — Réglages, restauration, états vides

```
Six écrans pour terminer.

ÉCRAN 16 — Réglages.
Section "SAUVEGARDE" : ligne d'état avec un point 8px #FFC94F, "Sauvegardé il y
a 2 jours", et en 13px #8CA096 "statoo-backup-20260804-214512.json · 84 Ko".
Bouton ghost 48px "Sauvegarder maintenant", puis une ligne à chevron
"Restaurer une sauvegarde".
Section "DONNÉES" : Version du schéma 1, Séances 24, Joueurs 14.
Section "À PROPOS" : "Statoo 1.0.0" et la ligne muette "Application personnelle.
Aucune donnée ne quitte l'appareil en dehors des sauvegardes."
Pas de barre d'onglets.

ÉCRAN 17 — Restaurer une sauvegarde.
Liste de cinq sauvegardes, lignes de 64px : "4 août 2026 · 21:45" en #EAF0EC,
"24 séances · 84 Ko" en 13px #8CA096, sélecteur radio à droite, la première
sélectionnée en #FFC94F.
Carte d'alerte : fond #260907, contour #A22C1E, première ligne gras #FF7361
"Cette action est irréversible", corps 13px "La restauration efface toutes les
données de l'appareil et les remplace par celles de la sauvegarde. Aucune fusion
n'est possible."
Champ de confirmation 52px, libellé "Tapez le nom du groupe pour confirmer",
placeholder "Nom du groupe".
Barre collée en bas : "Annuler" en ghost au-dessus, puis le bouton destructif
"Restaurer et écraser" en #F0503C, affiché désactivé à 50 % tant que le champ
est vide.

ÉCRANS 18 à 21 — Les quatre états vides.
Un état vide est une invitation, pas un décor : aucune illustration, aucune
icône de plus de 24px. Bloc centré, phrase en 15px #8CA096, un seul bouton.
Séances : "Aucune séance. La première prend deux minutes." + primaire
"Nouvelle séance".
Joueurs : "Ajoutez les joueurs du groupe pour commencer." + primaire
"Nouveau joueur".
Classement : "Le classement apparaîtra après la première séance close." — sans
bouton.
Sauvegardes : "Aucune sauvegarde. Elle se déclenchera à la prochaine clôture."
+ ghost "Sauvegarder maintenant".
Chaque écran garde son en-tête et sa barre d'onglets avec le bon onglet actif.
```

---

## Message 8 — La passe de vérification

Ce message n'existe pas chez Stitch : il exploite le fait que Claude Design peut
relire sa propre production contre la charte.

```
Passe de contrôle. Reprends les 21 écrans et vérifie-les point par point contre
le design system que je t'ai joint. Pour chaque écart, dis-moi lequel et
corrige-le. Liste de contrôle :

1. Aucune ombre portée, aucun dégradé, aucune illustration nulle part.
2. L'équipe B est bien hachurée à 45° et jamais colorée d'une seconde teinte.
   Les deux team pills ont le même poids visuel.
3. Le rang 1 n'est marqué que par son numéro en #FFC94F. Aucune médaille.
4. Aucun emoji, aucune flamme, aucune série, aucune étoile, aucune note.
5. Tous les chiffres en colonne sont en tabular-nums et alignés à droite.
6. La colonne J est présente dans les deux onglets du classement, et aucun
   tableau ne défile horizontalement.
7. Toute action principale est en barre collée en bas, 56px, pleine largeur.
   Dans chaque feuille modale, l'action destructive est le bouton le plus bas.
8. Aucun bouton jaune plein dans un écran de séance à part "Clôturer la séance".
   Ailleurs, le jaune signifie "équipe A".
9. Le vocabulaire est celui du groupe : "séance", "présents", "amical",
   "brouillon", "archivé". Jamais de terme de base de données.
10. Aucun chiffre n'est commenté, félicité ou qualifié.
11. Les cibles font 44px minimum, 52px pour les compteurs.
12. Les contrastes tiennent 4.5:1, y compris #8CA096 sur #0B120F.

Ensuite, exporte-moi le code des composants ScoreBar, StatStepper, PlayerRow et
StandingsTable séparément : je vais les porter en composants Vue dans un projet
Nuxt UI, donc écris-les avec des classes utilitaires Tailwind et des variables
CSS, sans dépendance à ton canevas.
```

---

## Récapitulatif des 21 écrans

| # | Écran | Message |
|---|---|---|
| — | Planche de composants | 1 |
| 1 | Accueil | 3 |
| 2 | Joueurs — liste | 3 |
| 3 | Fiche joueur | 3 |
| 4 | Nouveau joueur — feuille modale | 3 |
| 5 | Séances — liste | 4 |
| 6 | Nouvelle séance — présents et options | 4 |
| 7 | Détail séance — composition (brouillon) | 4 |
| 8 | Confirmation d'écrasement | 4 |
| 9 | Détail séance — saisie des statistiques | 4 |
| 10 | Saisie + bandeau d'écart de buts | 5 |
| 11 | Détail séance — close, lecture seule | 5 |
| 12 | Classement — Points | 6 |
| 13 | Classement — Pts/match + bloc sous le seuil | 6 |
| 14 | Classements secondaires | 6 |
| 15 | Statistiques globales | 6 |
| 16 | Réglages | 7 |
| 17 | Restauration d'une sauvegarde | 7 |
| 18–21 | États vides (séances, joueurs, classement, sauvegardes) | 7 |
