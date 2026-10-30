# F11 — Groupe actif disponible avant la première route

## Scénarios définis avant code applicatif

L'entrée main_web délègue à main.dart. Le groupe effectivement résolu par le
repository au démarrage doit initialiser activeTeamIdProvider avant l'affichage,
comme hasTeamProvider. Aucun chargement de l'accueil ne doit être nécessaire.

- BOOT01 : démarrer réellement main() directement sur /stats avec un groupe,
  six joueurs, une séance close 1-0 et une passe → identifiant immédiatement
  disponible, statistiques 1/6/1/1 ; aucun passage par l'accueil.
- BOOT02 : deux groupes aux chiffres distincts, le second sélectionné en meta →
  afficher uniquement le second ; ne pas revenir au premier ni agréger les deux.
- BOOT03 : ancienne sélection uniquement dans SharedPreferences → retrouver ce
  groupe ; une sélection SQLite existante reste prioritaire sur les préférences.
- BOOT04 : identifiant périmé ou absent → reprendre le premier groupe selon la
  règle existante du repository, et initialiser le provider avec cet identifiant.
- BOOT05 : aucun groupe → identifiant null, hasTeam false, route bienvenue après
  onboarding ; statistiques vides justifiées, pas de groupe artificiel.
- BOOT06 : anciennes préférences team_name sans groupe SQLite → reprise existante
  vers team_1 et provider initialisé, sans changer la migration du repository.
- BOOT07 : démarrage sans onboarding terminé → conserver la redirection vers
  onboarding, même si un groupe existe ; identifiant déjà prêt.
- BOOT08 : les providers de joueurs/séances consomment le même identifiant sans
  initialisation par l'accueil. Une sélection différente après démarrage actualise
  statistiques et listes ; un nouveau lancement retrouve cette sélection.
- BOOT09 : la correction ne modifie pas joueurs/séances/participations au démarrage.
  Si la lecture SQLite échoue, main() échoue avant montage, sans afficher de faux
  groupe vide. Vérifier dans une base temporaire, jamais dans la base utilisateur.
- BOOT10 : navigateur Chrome, vrai build Flutter web : créer un groupe local et
  un effectif, relever Stats puis recharger directement #/stats et rouvrir cette
  route dans un nouvel onglet de la même origine → mêmes valeurs persistées.
  Régression native par tests Flutter/SQLite ; appareil physique non couvert.

## Périmètre et résultats

Initialisation du provider dans main.dart seulement, sans modification de widgets
ou de règles métier. Tests du démarrage réel et contrôle navigateur du parcours
existant ; aucun déploiement.

- RED Flutter : 8 échecs comportementaux (identifiant actif null), 2 réussites.
  [Journal](startup-group-red-2026-10-26.txt). Un défaut initial de nettoyage de
  la fixture a été corrigé avant cette preuve ; ce défaut n'est pas compté comme RED.
- GREEN ciblé : 10 tests réussis, [journal](startup-group-green-2026-10-26.txt).
- Suite Flutter complète : **962 tests réussis**, en 3 min 10 s,
  [journal](startup-group-regression-2026-10-26.txt).
- Analyse : 2 infos cascade_invocations préexistantes dans MyApp, aucune dans les
  tests nouveaux ou les trois lignes ajoutées ; [sortie](startup-group-analyze-2026-10-26.txt).
- RED Chrome sur le précédent build : 6 joueurs avant rechargement, 0 après,
  [journal](startup-group-browser-red-2026-10-26.txt). Les premiers essais de
  saisie/sélecteurs n'étaient pas des preuves du défaut ; la dernière exécution
  atteint /stats, capture 6 joueurs, recharge puis échoue sur la valeur 0.
  Captures vues : [avant](startup-group-2026-10-26/red/before-reload.png) et
  [après](startup-group-2026-10-26/red/after-reload.png).
- Build web release corrigé : réussi en 133,3 s,
  [journal](startup-group-build-2026-10-26.txt).
- GREEN Chrome : scénario réussi en 28,54 s ; 6 joueurs avant et après
  rechargement direct de #/stats, puis dans un nouvel onglet de la même origine.
  Aucune erreur JavaScript capturée. [Journal](startup-group-browser-green-2026-10-26.txt),
  [capture après rechargement](startup-group-2026-10-26/green/after-reload.png)
  vue, [nouvel onglet](startup-group-2026-10-26/green/new-tab.txt) vérifié dans
  l'arbre accessible. Le premier lancement du GREEN avait été empêché par une
  limite d'utilisation du service d'approbation ; la reprise a été autorisée
  puis exécutée avec succès.
- [Revue distincte](review-startup-group-2026-10-26.md) : aucun défaut bloquant.
- Pas de recette sur téléphone physique ni de vérification visuelle exhaustive.
  Le navigateur couvre un groupe local de six joueurs sans séance ; les tests
  SQLite couvrent les séances closes, buts, passes et plusieurs groupes.
- Contrôle final git diff --check réussi. Modifications non commitées.
