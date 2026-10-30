# F03 — Validation serveur des documents sportifs

## Périmètre et scénarios définis avant code applicatif

Le serveur doit refuser en HTTP 422 les documents mal formés avant toute
écriture (document, candidat, opération, audit, obligations, séance active).
Le mobile Flutter fournit la référence de calcul des vainqueurs de tournoi
(`computeTournamentResult`). Le format historique sans `session_type` reste
un classique ; les participations transmises doivent avoir un identifiant
stable, comme celles produites par les clients actuels. Les anciennes fixtures
API sans identifiant seront complétées sans modifier leurs assertions métier.

- SV01 — Date requise : dates civiles ISO valides et timestamps ISO avec/sans
  fraction, Z ou décalage acceptés ; absence, null, types composites, texte,
  date impossible et semaine ISO non civile refusés sans erreur 500.
- SV02 — Structure : session objet, participations liste de 0 à 1000 objets ;
  identifiants session/participation/joueur/liaison non vides de type chaîne,
  identifiants de participation et de joueur uniques ; membre inconnu refusé.
  Les valeurs non hachables renvoient 422, jamais 500.
- SV03 — Format/statut/camp : seuls CLASSIC_2 (ou absent historique) et
  TOURNAMENT_3, DRAFT/CLOSED/CANCELLED ; A/B en classique, A/B/C en tournoi,
  y compris avec dérogation d'effectif. Types composites refusés sans 500.
- SV04 — Chiffres : scores présents non nuls, victoires, points de nul, buts
  non attribués et statistiques sont des entiers positifs ou nuls, jamais des
  booléens, chaînes ou flottants. Les scores peuvent être nuls/non renseignés
  dans un brouillon ou un tournoi ; une clôture classique exige A et B.
  Contrôler aussi les chiffres d'un brouillon ou d'une annulation.
- SV05 — Options natives : allow_uneven_teams et is_ranked présents sont des
  entiers 0/1 ; split_mode absent/null ou RANDOM/RANDOM_ADJUSTED/MANUAL.
  is_active reste un booléen. Ne pas accepter une chaîne truthy comme dérogation.
- SV06 — Tournoi clôturé : victoires non négatives et au moins une victoire ;
  vainqueur calculé selon le maximum, y compris DRAW_AB/BC/AC/ALL. Chaque
  combinaison valide acceptée ; résultat différent refusé. Un brouillon de
  tournoi à zéro victoire et résultat nul reste valide.
- SV07 — Invariants existants : minimum de présents, équilibre sauf dérogation,
  total buts+non attribués=score, passes<=buts et pas d'auto-passe conservés.
  Un but joueur compensé par -1 but non attribué est refusé.
- SV08 — Effets et permissions : chaque requête invalide laisse le snapshot
  inchangé ; une correction invalide ne modifie pas l'historique ; une version
  invalide d'un autre auteur ne devient pas candidat. Un rôle sans droit sport
  reste refusé en 403 et les conflits valides restent fonctionnels.
- SV09 — Arbitrage : une ancienne candidature invalide stockée avant le
  durcissement doit être refusée à la sélection ; conservation explicite de
  la version courante historique toujours permise selon la règle existante.
- SV10 — Compatibilité interclients : l'instantané synthétique exporté par le
  portail et importé par Flutter conserve un document sportif valide côté API.
  Vérification ajoutée avant son test, sans changement applicatif supplémentaire.

## Limites du lot

Pas de nettoyage des documents historiques, pas de changement des permissions,
ni de l'interface, ni de contrôle de révision des membres. Ce lot vise les champs
structurels et sportifs connus ; il ne définit pas un nouveau format de sauvegarde.
Les validations supplémentaires de métadonnées libres relèvent d'un autre lot.

## Résultats

- RED comportemental : **81 échecs, 70 succès**, en 10,76 s.
  `sport-validation-red-2026-10-25.txt` montre des réponses 200 et 500 à la
  place du 422 attendu. Une première préparation incomplète du groupe avait
  renvoyé 409 avant validation ; elle a été corrigée et n'est pas comptée comme RED.
- GREEN ciblé final : **152 tests réussis**, en 8,08 s, dont la fixture
  interclients existante ajoutée sans changement applicatif supplémentaire.
  Preuve : `sport-validation-green-2026-10-25.txt`.
- Régression Flutter ciblée : **44 tests réussis** (clôture, tournoi à trois
  équipes, import wire du portail), `sport-validation-client-regression-2026-10-25.txt`.
- Régression API complète : **240 tests réussis** en 356,46 s ; code applicatif
  figé avant son lancement. La collection précède l'ajout du test SV10, exécuté
  séparément avec les 152 tests ciblés finaux. Preuve :
  `sport-validation-regression-2026-10-25.txt`.
- Revue distincte : `review-sport-validation-2026-10-25.md`, aucun défaut
  bloquant identifié dans le périmètre. `git diff --check` passe.

Les tests API utilisent des groupes synthétiques et SQLite en mémoire. Aucun
PostgreSQL de production, navigateur interactif ou téléphone physique n'est validé.
Le warning Starlette/httpx observé est préexistant ; les tests ne le suppriment pas.
