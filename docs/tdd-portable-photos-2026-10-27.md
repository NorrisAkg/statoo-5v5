# F15 — Photos portables

## Périmètre et scénarios préalables

Références lues : mémoire du design, thème actuel, InitialAvatar, liste/détail des
joueurs, formulaire joueur et deux compositions de séance. Conserver dimensions,
couleurs et initiales existantes ; photo circulaire avec repli sur les initiales.

1. Export d'une photo locale PNG/JPEG/WebP : octets intégrés dans `avatar_url` sous forme de data URI ; source SQLite inchangée. Après suppression du fichier source et restauration dans une autre base, image encore décodable.
2. Photos intégrées web et joueurs sans photo : aller-retour intact, JSON v1/v2 accepté.
3. Export avec fichier absent, contenu corrompu/non-image ou image trop lourde : erreur explicite, aucune sauvegarde présentée comme complète et aucune mutation SQLite.
4. Limites communes : 2 Mio par image encodée, 16 millions de pixels, 32 Mio d'images cumulées par sauvegarde ; rejet avant stockage/décodage excessif. PNG/JPEG/WebP seulement. Contrôle de taille avant lecture locale et avant décodage base64.
5. Restauration avec image intégrée invalide : rejet avant remplacement SQL ; état précédent intact.
6. Ancien chemin local, file URI, blob URI dans une sauvegarde : ne jamais lire le fichier de destination ni une ressource arbitraire. Conserver le joueur sans photo et annoncer le nombre de références écartées dans les deux parcours de restauration.
7. Anciennes URL HTTP(S) : conserver la référence sans téléchargement automatique à l'export/restauration ; leur disponibilité hors ligne n'est pas garantie.
8. Fusion : nouveaux joueurs avec photos portables ; joueur réconcilié garde sa photo locale et ses données existantes.
9. Sélection d'une nouvelle image : même data URI sur natif/web, contrôle de validité/taille ; annulation conserve le choix précédent, erreur visible sans perte du nom ; droits inchangés.
10. Affichage : mémoire pour data URI, lecture bornée pour ancienne photo locale, réseau pour HTTP(S). Image absente/invalide/inaccessible => initiales, aucune exception non gérée. Liste, détail et deux compositions utilisent le même composant.
11. Cadrage du composant : clair/sombre, 320/393 dp, texte 100/130/200 %, noms longs ; photo décorative (nom déjà adjacent), dimensions existantes. Régressions des formulaires/clavier/permissions existants.

Tests comportementaux avant code applicatif. Les nouveaux composants absents ne
constituent pas un RED par compilation : le premier RED porte sur BackupService
existant. Les références d'anciens fichiers perdues ne peuvent être reconstruites.
Les essais physiques de galerie Android/iOS et la durabilité après coupure réelle
resteront explicitement séparés des tests automatisés.

Cas précisé avant correction du compteur : en fusion, une référence locale écartée
pour un joueur réconcilié ne doit pas être annoncée comme perdue puisque sa photo
existante est conservée. Le compteur ne concerne que les joueurs réellement insérés.

## Cas découverts en recette/revue, avant correction

- Chrome réel : la restauration d'un PNG valide doit réussir et rester visible après
  rechargement. RED navigateur constaté : `ImageDescriptor.width/height` n'existent
  pas sur Flutter web (confirmation dans le SDK local). Les 1038 tests natifs verts
  ne couvrent pas cette différence de plateforme.
- Limiter également chaque côté à 4096 pixels : un panorama très étroit ne doit pas
  provoquer un agrandissement démesuré lors de la validation. Test avec PNG valide
  de 4097 × 1 avant correction ; décodage de contrôle sans agrandissement.

## Résultats intermédiaires et limites de preuve

- Premier RED : 11 échecs comportementaux / 7 succès sur BackupService existant.
- La première fixture PNG copiée contenait un flux invalide ; elle a été remplacée
  par un PNG synthétique avec CRC correct. Les échecs de décodage de cette fixture
  ne sont pas des défauts applicatifs. Un test de galerie a également nécessité
  `runAsync` et l'avancement des trames pour ses accès fichiers réels.
- Compteur de fusion : RED dédié puis correction, sans remplacer la photo locale
  d'un joueur réconcilié.
- Premier passage global : 1038 succès, mais recette Chrome RED ensuite. Le SDK web
  expose ImageDescriptor sans dimensions pour les images encodées. Le lecteur
  d'en-têtes JPEG/WebP de `image` (version 4.10.1 déjà verrouillée) est désormais une
  dépendance directe ; aucune version de dépendance n'a changé. PNG est contrôlé
  directement dans IHDR avant le décodage Flutter ; aucune décompression de texte
  PNG n'est nécessaire à la vérification des dimensions.
- Cas d'aspect extrême : le premier test rejetait pour une erreur de redimensionnement
  au lieu de la limite attendue. L'assertion a été précisée, le RED conservé, puis le
  contrôle explicite de 4096 pixels/côté et le décodage sans agrandissement ajoutés.
- GREEN ciblé après correction : 59 tests, 16 s, comprenant le formulaire réel,
  ses régressions clavier, le composant avatar et les sauvegardes.

Les photos historiques HTTP(S) restent des références externes. Les fichiers locaux
absents/corrompus interrompent explicitement l'export : aucune sauvegarde complète
n'est annoncée à tort. Les anciens chemins d'une sauvegarde importée sont écartés
sans lecture locale, avec avertissement ; leurs octets absents ne sont pas récupérables.
Les limites portent sur les photos, pas sur la taille totale des autres données JSON.

Revue finale, cas précisé avant correction : lorsqu'une ligne est réutilisée pour un
autre joueur/source, le chargement de sa nouvelle photo doit afficher ses initiales,
pas conserver l'ancienne image dans le FutureBuilder. Test de remplacement par un
fichier local dont la lecture asynchrone est encore en attente.

## Validation finale et revue

- Suite globale après correction de compatibilité web : **1039 tests réussis**, 5 min 12 s.
- Revue distincte : ajout d'une assertion précise sur le budget de 32 Mio et d'un test
  explicite d'insertion en fusion. Détection d'un ancien portrait conservé pendant le
  chargement d'une nouvelle source : RED dédié, correction du contrôle d'état du
  FutureBuilder, puis **43 tests ciblés réussis** en 5 s. Ces 43 tests recouvrent une
  partie de la suite globale ; ne pas additionner les compteurs.
- La suite globale n'a pas été répétée après ce dernier correctif de cycle de vie ;
  le composant et les sauvegardes ont été vérifiés par les 43 tests ciblés.
- Analyse : aucun nouveau diagnostic ; trois informations préexistantes dans
  `settings_screen.dart` (ordre de deux imports et accolades ligne 225), vérifiées
  dans HEAD et laissées hors périmètre. `git diff --check` réussi.
- Chrome : restauration réelle de la fixture PNG, liste puis détail, rechargement
  direct, liste sombre 320 dp / texte 200 %. Captures examinées : `list-light.png`,
  `detail-after-reload.png`, `list-dark-small.png` dans `portable-photos-2026-10-27/`.
  Le disque rouge est volontairement une image synthétique de test, pas une photo
  manquante : les initiales n'y sont pas affichées. Police et écrans de production.
- Les dimensions du portrait sont conservées. La capture à 320 dp / 200 % montre
  encore un placeholder de recherche tronqué et des mots coupés dans le nom ; ne
  pas interpréter ce lot comme une validation visuelle globale de cet écran.
- La matrice 320/393, 100/130/200 %, clair/sombre est automatisée sur le composant ;
  les tests existants de formulaire/clavier et permissions passent dans la suite.
  Pas de sélection physique Android/iOS ni de contrôle TalkBack/VoiceOver.
