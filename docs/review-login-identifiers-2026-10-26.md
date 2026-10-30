# Revue distincte après implémentation — F06

## Périmètre relu

Nouveaux validateurs de non-vacuité de `Credentials`, `Registration` et
`AccountInput`, comparaison Admin/collectif dans `register`, tests HTTP et
preuves de non-mutation. Lecture croisée des chemins de login, ajout de compte,
rotation collective, replay d'inscription et révocation des jetons.
Le durcissement sportif F03 déjà local n'est pas remanié par ce lot.

## Constats

- La comparaison initiale utilise désormais `strip().casefold()`, comme le
  stockage nettoyé et les recherches existantes. Elle précède la génération du
  groupe, la création des comptes et l'enregistrement de l'opération de reprise.
- Les validateurs refusent les noms entièrement blancs, y compris tabulations et
  espaces insécables, sans réécrire la valeur du modèle. Ils s'appliquent aux
  entrées initiales, au login, à l'ajout de compte et à la rotation collective.
- L'héritage de Credentials protège le username Admin lors de l'inscription et
  celui de la rotation ; le champ partagé initial reçoit son propre validateur.
- Aucun mot de passe, droit, identifiant de groupe ou contrôle de longueur n'est
  modifié. La casse d'affichage, les espaces intérieurs et les accents restent
  conservés ; aucune normalisation Unicode supplémentaire n'est introduite.
- Les refus d'inscription ne modifient pas les comptes SQL de groupes, jetons et
  opérations de reprise. Les refus sur un groupe existant ne changent ni son
  snapshot ni la validité de son jeton collectif.
- Le test de reprise compare l'empreinte persistée au JSON historique brut, puis
  rejoue l'opération avec espaces et vérifie le même groupe. Une transformation
  `strip` dans un validateur aurait rompu ce contrat ; elle n'est pas appliquée.
- La rotation valide reste soumise au rôle Admin et révoque l'ancien accès
  collectif. Les comptes distincts sont connectables avec leurs propres rôles,
  pas seulement acceptés lors de la création.

## Conclusion et limites

Aucun défaut bloquant identifié dans le diff du périmètre après les 30 tests
ciblés réussis. Résultats de la suite complète dans le document TDD associé.
Aucune réparation ou suppression automatique des doublons historiques : un
Admin encore connecté peut renommer l'accès collectif par la rotation existante.
Un compte historique dont le nom stocké est vide nécessite une reprise explicite ;
les nouvelles entrées entièrement blanches sont refusées, y compris au login.
Les garanties de replay testées concernent les identifiants non vides avec espaces.

SQLite en mémoire et requêtes HTTP TestClient, sans validation de concurrence
PostgreSQL ni recette d'interface/appareil. Aucun commit ni push effectué.

## Clôture après régression complète

271 tests API réussis en 10 min 45, dont les 30 nouveaux scénarios. Relecture du
diff final et des résultats après cette exécution ; aucun changement applicatif
pendant la régression, aucun défaut bloquant restant identifié dans le périmètre.
`git diff --check` passe. Un seul warning préexistant : dépréciation Starlette/httpx.
