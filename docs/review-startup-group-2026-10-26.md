# F11 — Revue distincte après implémentation

## Périmètre relu

Trois lignes dans main.dart : initialisation d'activeTeamIdProvider avec team?.id,
ainsi que les tests du démarrage réel et le scénario navigateur. Revue effectuée
après le GREEN ciblé, séparément de l'implémentation.

## Constats

- Le même résultat du repository alimente hasTeam et activeTeamId. Le groupe est
  résolu avant runApp ; aucun écran ne doit déclencher TeamInfoNotifier pour
  initialiser le contexte des statistiques.
- main_web appelle toujours main.dart : même initialisation native/web, seules
  les implémentations de stockage diffèrent.
- Le repository garde la priorité SQLite, la compatibilité SharedPreferences,
  le repli vers le premier groupe et l'import des anciennes préférences. Aucun
  nouvel identifiant inventé ni nouvel accès réseau.
- Le notifier reste mutable. Les changements de groupe et rechargements depuis
  la base après restauration continuent à utiliser ses méthodes existantes.
  Aucun invalidate(activeTeamIdProvider) n'existe dans le code de production relu.
- SharedService.load termine avant ProviderScope, comme auparavant : la protection
  des groupes partagés est déjà chargée quand les permissions lisent l'identifiant.
- Les tests appellent réellement main(), avec les vrais repositories et SQLite
  dans un dossier temporaire. Ils ne remplacent pas activeTeamIdProvider par le
  résultat attendu. Ils vérifient également les listes et l'isolation entre groupes.
- Le contrôle d'intégrité compare les groupes, joueurs, séances et participations
  avant/après démarrage. Une erreur SQLite ne devient pas un faux état vide.

Aucun défaut bloquant relevé dans le périmètre.

## Résultats et limites

- RED : 8 échecs sur l'identifiant null ; 2 cas déjà corrects réussis.
- GREEN ciblé : 10 tests réussis.
- Analyse : nouveaux tests sans diagnostic ; deux infos cascade_invocations
  préexistantes dans MyApp (lignes déplacées 59/61), hors des trois lignes ajoutées.
  Les mêmes instructions figurent dans HEAD ; aucune nouvelle erreur d'analyse.
- Suite complète Flutter : 962 tests réussis en 3 min 10 s.
- Navigateur : RED reproduit sur l'ancien build, 6 joueurs puis 0 au rechargement.
  Build release corrigé réussi en 133,3 s, puis GREEN Chrome réussi en 28,54 s :
  6 joueurs avant/après rechargement et dans un nouvel onglet. Capture du rendu
  après rechargement examinée ; arbres accessibles des trois étapes conservés.
- git diff --check final réussi.
- Aucun widget ni thème modifié, pas de validation visuelle exhaustive.
- Appareils Android/iOS physiques et navigateurs autres que Chrome non couverts.
- Aucun commit ni déploiement pour ce lot.
