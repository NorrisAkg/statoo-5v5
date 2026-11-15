# Audit Statoo — 07. Multi-tenant et données

- **Domaine** : isolation entre tenants (mobile, backend, synchronisation, portail), schéma SQLite et migrations, intégrité, index, transactions, suppression et archivage, données personnelles, sauvegarde et restauration.
- **Date** : 14/11/2026. Arbre de travail de la branche `fix/mobile-red-tests` (HEAD `2a9a3c7`).
- **Méthode** : principalement statique (lecture de `mobile/lib/core/data/app_database.dart`, `mobile/lib/features/*/data/`, `mobile/lib/features/settings/`, `mobile/lib/features/shared/data/shared_service.dart`, `backend/app/models.py`, `backend/app/main.py`, `web/client.mjs`, `web/registration-draft.mjs`, `docs/database.md`, `docs/backup.md`, `docs/outbox-sync.md`). Exécution limitée à deux scripts Python sur une base SQLite **en mémoire** du scratchpad (comportement des clés étrangères, CHECK, plans de requête). Aucune suite relancée ; `statoo.db` non ouvert.
- **Limites** : pas d'exécution Flutter ni backend pour ce domaine ; pas d'accès à Neon (taille réelle de `groups.state` inconnue) ; aucune mesure de volumétrie. Les constats marqués [déduit] reposent sur la lecture du code sans reproduction.

## Synthèse

L'isolation entre groupes est **globalement bien tenue** au niveau des requêtes : les repositories mobiles portent `team_id` (ou passent par une séance dont l'appartenance au groupe vient d'être vérifiée dans la même transaction), un trigger SQLite empêche une participation de relier un joueur et une séance de groupes différents, le backend vérifie à chaque route que le jeton appartient au `group_id` de l'URL, l'outbox filtre par groupe et par auteur, et le portail préfixe son stockage par `api|groupe|compte`. Aucune fuite directe entre tenants n'a été trouvée.

Les faiblesses portent sur **le modèle de données et le cycle de vie** : l'agrégat JSON `groups.state` grossit sans limite (opérations, audit, historique, photos en base64 des membres) et est relu, copié et verrouillé à chaque requête, derrière un verrou Python global qui sérialise tous les groupes ; l'outbox locale n'est jamais purgée, contrairement à la documentation ; la fusion de sauvegarde mélange tous les groupes d'un fichier dans un seul ; une migration SQLite refusée empêche l'application de démarrer ; il n'existe aucun moyen de supprimer un groupe, un compte ou un membre côté serveur (minimisation et effacement des données personnelles). Le schéma n'a aucun index secondaire et diverge entre base neuve et base migrée.

**Note proposée : 3/5.** Cloisonnement correct et défendu en profondeur, transactions présentes sur les opérations sensibles, tests de migration réels ; mais croissance non bornée des données partagées, absence de stratégie d'effacement et plusieurs incohérences de schéma qui freineront l'évolution.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| DAT-001 | Majeur | Photos base64 et lignes `players` brutes publiées dans `groups.state` sans schéma | `mobile/lib/features/shared/presentation/shared_group_screen.dart` | M |
| DAT-002 | Majeur | Agrégat `groups.state` à croissance non bornée, relu et verrouillé à chaque requête | `backend/app/main.py` | L |
| DAT-003 | Majeur | Verrou Python global : toutes les requêtes de tous les groupes sont sérialisées | `backend/app/main.py` | S |
| DAT-004 | Majeur | Outbox jamais purgée, parcours complets répétés de `meta` | `mobile/lib/features/shared/data/shared_service.dart` | M |
| DAT-005 | Majeur | La fusion de sauvegarde regroupe tous les groupes du fichier dans un seul | `mobile/lib/features/settings/data/backup_service.dart` | M |
| DAT-006 | Majeur | Une migration SQLite refusée bloque le démarrage sans voie de reprise | `mobile/lib/core/data/app_database.dart` | M |
| DAT-007 | Majeur | Aucun effacement possible : groupe, compte, membre, jetons, données locales après déconnexion | `backend/app/main.py` | L |
| DAT-008 | Mineur | Schéma divergent entre base neuve et base migrée (`sessions.team_id`) | `mobile/lib/core/data/app_database.dart` | S |
| DAT-009 | Mineur | Clés `meta` orphelines après suppression d'un groupe ou d'une séance | `mobile/lib/features/team/data/team_repository.dart` | S |
| DAT-010 | Mineur | Un groupe supprimé peut renaître depuis les SharedPreferences héritées | `mobile/lib/features/team/data/team_repository.dart` | S |
| DAT-011 | Mineur | Réglage `min_players_per_session` non scopé appliqué à tous les groupes | `mobile/lib/features/settings/data/group_settings_repository.dart` | S |
| DAT-012 | Mineur | Aucun index secondaire sur les colonnes filtrées | `mobile/lib/core/data/app_database.dart` | S |
| DAT-013 | Mineur | Statut `CANCELLED` : accepté par l'API, refusé par SQLite, séance supprimée localement | `mobile/lib/features/shared/data/shared_service.dart` | M |
| DAT-014 | Mineur | Identifiants de joueurs et de groupes à la milliseconde | `mobile/lib/features/players/data/players_repository.dart` | S |
| DAT-015 | Mineur | Import du snapshot : lignes serveur insérées telles quelles dans SQLite | `mobile/lib/features/shared/data/shared_service.dart` | M |
| DAT-016 | Mineur | Garde multi-tenant limitée aux participations | `mobile/lib/core/data/app_database.dart` | S |
| DAT-017 | Mineur | Backend sans migrations et table `tokens` sans index ni purge | `backend/app/models.py` | M |
| DAT-018 | Mineur | Snapshot : journal d'audit et responsables exposés à tous les comptes, y compris l'accès collectif | `backend/app/main.py` | S |
| DAT-019 | Mineur | Sauvegarde : un fichier unique contient tous les groupes, photos et métadonnées partagées | `mobile/lib/features/settings/data/backup_service.dart` | M |
| DAT-020 | Mineur | Documentation données en écart avec le code | `docs/outbox-sync.md` | XS |

Total : 0 Critique, 7 Majeur, 13 Mineur (et des Info en §6).

---

### DAT-001 — Photos base64 et lignes `players` brutes publiées dans `groups.state` sans schéma
- Sévérité : Majeur / Domaine : données personnelles, volumétrie / Statut : confirmé (lecture)
- Preuve :
  - `mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:46` : `final photo = await PlayerPhoto.encode(bytes);` ; `mobile/lib/core/media/player_photo.dart:12` (`maxBytes = 2 * 1024 * 1024`) et `:103` (`'data:$mime;base64,…'`). La photo est stockée en data URI dans `players.avatar_url`.
  - `mobile/lib/features/shared/presentation/shared_group_screen.dart:1161-1171` : `_publishMembers` lit `db.query('players', where: 'team_id = ?', …)` et l'envoie tel quel : `service.request('PUT', '/groups/${service.groupId}/members', members)`.
  - `backend/app/main.py:659` : `def members(group_id: str, body: list[dict], …)` ; seuls `id` et `name` sont contrôlés (l. 662-665), puis `state["members"] = body` (l. 670). Aucune liste blanche de champs ni limite de taille par membre.
  - `backend/app/main.py:509` : le snapshot renvoie `members` à tout compte authentifié.
- Impact : jusqu'à 1 000 membres × ~2,7 Mo de base64 dans une seule ligne JSON, renvoyée en entier à chaque `GET /groups/{id}` (toutes les 45 s par appareil, `shared_service.dart:241-244`) et recopiée à chaque requête (DAT-002). Les photos (donnée personnelle) sont diffusées à tous les comptes du groupe sans choix explicite. Des champs locaux (`team_id`, `created_at`, `updated_at`) sont persistés côté serveur sans contrat.
- Recommandation : définir un modèle Pydantic `Member` (id, name, nickname, is_active, avatar optionnelle bornée) ; côté client, projeter explicitement les champs publiés ; stocker les photos hors de l'agrégat (table ou stockage objet référencé par URL) ou les exclure de la publication.
- Effort : M

### DAT-002 — Agrégat `groups.state` à croissance non bornée, relu et verrouillé à chaque requête
- Sévérité : Majeur / Domaine : modèle de données backend, performance / Statut : confirmé (lecture) ; volumétrie réelle non mesurée
- Preuve :
  - `backend/app/models.py:11-14` : une seule colonne `state: Mapped[dict] = mapped_column(JSON)` par groupe.
  - Ajouts sans purge : `main.py:822` (`state["operations"][body.operation_id] = …` à chaque synchronisation), `main.py:326` (`state["audit"].append(…)` à chaque écriture), `main.py:801` et `:852` (`document["history"].append(…)`), `main.py:789/792` (`document["candidates"].append(…)`). Aucun code ne retire d'entrée de ces collections (`grep -n "delete\|\.remove" backend/app/main.py` ne renvoie que des suppressions de `Token`).
  - `main.py:308-309` : chaque requête authentifiée, y compris le `GET` de snapshot, fait `select(Group)….with_for_update()` puis `copy.deepcopy(group.state)` ; chaque écriture réécrit tout le JSON (`group.state = state`).
- Impact : coût mémoire et CPU proportionnel à tout l'historique du groupe à chaque appel ; les lectures concurrentes d'un même groupe sont sérialisées par `FOR UPDATE` ; la ligne PostgreSQL grossit indéfiniment (TOAST, WAL). Les contraintes d'intégrité (unicité d'opération, appartenance des membres) n'existent que dans le code Python.
- Recommandation : sortir `operations`, `audit` et `history` dans des tables dédiées indexées par `group_id` (ou au minimum borner/archiver) ; ne prendre `FOR UPDATE` que sur les routes d'écriture ; prévoir une politique de rétention.
- Effort : L

### DAT-003 — Verrou Python global : toutes les requêtes de tous les groupes sont sérialisées
- Sévérité : Majeur / Domaine : transactions backend / Statut : confirmé (lecture)
- Preuve : `backend/app/main.py:284` `lock = threading.Lock()` puis `:299` `with lock, Session(engine) as session, session.begin():`. Le commentaire (l. 282-283) annonce « Also serialize SQLite development transactions. PostgreSQL uses row locks across workers. » mais le verrou s'applique quel que soit le moteur.
- Impact : dans un worker, une requête lente d'un groupe bloque toutes les requêtes des autres groupes (y compris `/health` n'en dépend pas, mais login, snapshot, sync oui). L'isolation entre tenants n'est pas atteinte en disponibilité. Le comportement contredit son commentaire.
- Recommandation : n'activer le verrou que pour les URL `sqlite` ; s'appuyer sur les verrous de ligne PostgreSQL. Ajouter un test qui vérifie que deux groupes peuvent être servis en parallèle.
- Effort : S
- Renvoi : performance.

### DAT-004 — Outbox jamais purgée, parcours complets répétés de `meta`
- Sévérité : Majeur / Domaine : synchronisation, volumétrie locale / Statut : confirmé (lecture)
- Preuve :
  - Seule suppression d'un `outbox_*` : `shared_service.dart:389`, qui ne vise qu'un événement `pending` non tenté du même auteur, domaine, groupe et séance. Après réponse serveur, l'événement est seulement mis à jour (`:628-635`, statut `accepted` ou `conflict`). `grep -rn "outbox_" mobile/lib` ne montre aucune autre suppression.
  - Parcours complets : `shared_service.dart:556-561`, `:684`, `:885-889` (requête sur **tous** les `outbox_` exécutée **pour chaque document** du snapshot, dans la boucle l. 857), `:986`. Le filtre `substr(key,1,7) = ?` empêche l'usage de l'index de clé primaire : plan `SCAN meta` (script `qp.py`, voir DAT-012).
  - `mobile/lib/core/data/occurrence_registry.dart:17` : `JOIN sessions s ON m.key = ? || s.id` force aussi un parcours de `meta`.
  - Écart documentaire : `docs/outbox-sync.md:42` indique « Retirée de la file outbox » pour un 200.
- Impact : la table `meta`, qui mêle réglages, points financiers, snapshot, outbox et alias, grossit à chaque saisie synchronisée ; `importSnapshot` devient O(documents × événements) dans une transaction d'écriture exécutée toutes les 45 s. La sauvegarde exporte aussi tout cet historique (DAT-019).
- Recommandation : supprimer (ou archiver dans une table dédiée) les événements `accepted`/`resolved` après mise à jour de `shared_revision_*` ; sortir l'outbox de `meta` dans une table `outbox(id, group_id, status, …)` indexée ; lire les événements une fois par import.
- Effort : M

### DAT-005 — La fusion de sauvegarde regroupe tous les groupes du fichier dans un seul
- Sévérité : Majeur / Domaine : multi-tenant, restauration / Statut : confirmé (lecture) ; documenté dans `docs/backup.md:34`
- Preuve : `backup_service.dart:322-345` : chaque joueur de `payload.players` reçoit `newPlayer['team_id'] = localTeamId`, quel que soit son groupe d'origine ; `:359-373` : chaque séance de `payload.sessions` reçoit `newSession['team_id'] = localTeamId`. Le rapprochement par nom (`:306-327`) fusionne un « Lucas » du groupe X du fichier avec le « Lucas » du groupe cible. Si `targetTeamId` est absent ou introuvable, la cible est `localTeams.first` (`:279-283`), choix arbitraire.
- Impact : une sauvegarde multi-groupes fusionnée mélange définitivement les joueurs et les classements de plusieurs groupes dans un seul ; aucun retour arrière hors sauvegarde externe. Les séances d'un autre groupe tombant à la même date qu'une séance locale sont silencieusement ignorées (`:362-366`).
- Recommandation : en mode fusion, exiger le choix d'**un** groupe source et filtrer joueurs, séances et participations sur ce `team_id` ; refuser la fusion si `targetTeamId` est nul alors que plusieurs groupes existent ; afficher le détail par groupe avant validation.
- Effort : M

### DAT-006 — Une migration SQLite refusée bloque le démarrage sans voie de reprise
- Sévérité : Majeur / Domaine : migrations / Statut : confirmé (lecture) pour l'enchaînement ; fréquence réelle [déduit] faible
- Preuve :
  - `app_database.dart:189-195` : après une migration depuis une version < 7, `PRAGMA foreign_key_check` non vide lève `StateError('Migration annulée : …')`. La reconstruction v7 (`:144-183`) impose `team_id TEXT NOT NULL` : une séance à `team_id` NULL fait échouer l'`INSERT … SELECT` (cas testé : `mobile/test/core/data/database_migration_test.dart`, MIG05 « rejects null-team »).
  - La branche `< 4` (`:80-91`) n'affecte un `team_id` que si au moins une ligne `teams` existe, et l'affecte au **premier** groupe trouvé (`limit: 1`) pour toutes les séances.
  - `mobile/lib/main.dart:29-30` : `await teamRepository.getTeamInfo()` ouvre la base avant `runApp`, sans `try/catch`.
- Impact : sur un appareil dont l'ancienne base contient une séance sans groupe ou une référence invalide, l'exception remonte hors de `main()` et l'application ne s'affiche pas ; l'utilisateur ne peut ni exporter ni réparer. Les données sont préservées (rollback), mais inaccessibles. Les branches `< 4` et `< 5` ne sont couvertes par aucun test (`MIG01`-`MIG11` partent de v6/v7).
- Recommandation : capturer l'échec d'ouverture et afficher un écran de secours proposant l'export brut du fichier `statoo.db` ; pour `team_id` NULL, rattacher à un groupe « À reclasser » plutôt que d'échouer ; ajouter des tests de migration depuis v3/v4.
- Effort : M

### DAT-007 — Aucun effacement possible : groupe, compte, membre, jetons, données locales après déconnexion
- Sévérité : Majeur / Domaine : données personnelles / Statut : confirmé (lecture)
- Preuve :
  - Aucune route `DELETE` ni suppression de groupe ou de compte : `grep -n "@app.delete\|DELETE" backend/app/main.py` ne renvoie rien ; CORS limite d'ailleurs les méthodes à `GET, POST, PUT` (`main.py:281`).
  - Suppression de membre refusée : `main.py:668-669` `fail(409, "Archivez les membres au lieu de les supprimer")`.
  - Jetons expirés jamais purgés : seules suppressions de `Token` aux l. 440, 497-498, 584-585, 605-607, 696-697 (déconnexion, réinitialisations).
  - Journal d'audit et historique conservés indéfiniment (DAT-002).
  - `shared_service.dart:248-295` (`disconnect`) efface les identifiants du stockage sécurisé mais aucune ligne SQLite : joueurs, séances, points financiers et `shared_snapshot_<groupe>` (comptes, journal) restent lisibles sur l'appareil.
- Impact : impossible de répondre à une demande d'effacement d'un joueur (nom, surnom, photo) ou de clôturer un groupe ; aucune durée de conservation définie. Sur un appareil partagé, les données d'un groupe restent consultables après déconnexion [déduit : le groupe reste listé, en lecture seule via `protectedGroups`].
- Recommandation : définir une politique de conservation ; ajouter la suppression d'un groupe (et de ses jetons), l'anonymisation d'un membre (nom remplacé, photo retirée, identifiant conservé pour l'historique) ; purger les jetons expirés ; proposer « effacer les données locales de ce groupe » à la déconnexion.
- Effort : L

### DAT-008 — Schéma divergent entre base neuve et base migrée (`sessions.team_id`)
- Sévérité : Mineur / Domaine : schéma / Statut : confirmé (lecture et exécution en mémoire)
- Preuve : `app_database.dart:318` (création) `team_id TEXT REFERENCES teams(id) ON DELETE CASCADE` (nullable) contre `:146` (reconstruction v7) `team_id TEXT NOT NULL …`. Script `fk.py` sur le DDL de création : `INSERT INTO sessions VALUES('s2',NULL,'DRAFT')` est accepté. `seedDemoData` (`:705-709`, `@visibleForTesting`) insère d'ailleurs des séances sans `team_id`. Par ailleurs `meta.schema_version` vaut `'1'` (`:364`) alors que la version est 8 (`:15`, `:62`). Écart déjà signalé dans `docs/database.md:7,25`.
- Impact : deux bases « v8 » n'ont pas les mêmes contraintes ; une séance orpheline est possible sur une installation neuve (les repositories fournissent toujours `team_id`, et le trigger de participations bloque l'usage d'une telle séance, d'où la sévérité Mineur). Les tests sur base neuve ne couvrent pas la contrainte des bases migrées.
- Recommandation : aligner la création sur `NOT NULL` via une migration v9 (reconstruction contrôlée) ; supprimer ou mettre à jour `meta.schema_version` ; corriger `seedDemoData`.
- Effort : S

### DAT-009 — Clés `meta` orphelines après suppression d'un groupe ou d'une séance
- Sévérité : Mineur / Domaine : suppression, intégrité / Statut : confirmé (lecture)
- Preuve :
  - `team_repository.dart:138-151` : `deleteTeam` supprime la ligne `teams` (cascade SQL vérifiée par `fk.py` : `delete team OK (0,)` participations) puis seulement 5 clés `meta` (`active_session_id_`, `team_short_name_`, `mvp_weights_`, `min_players_per_session_`, `tournament_draw_points_`). Restent : `finance_rate_<g>`, `finance_late_penalty_<g>`, `finance_point_<g>_*`, `finance_validated_<g>_*`, `shared_finance_alias_<g>_*`, `shared_snapshot_<g>`, `shared_group_<g>`, `live_stats_<g>_*`, `outbox_*` du groupe.
  - `sessions_repository.dart:889-904` : `deleteSession` supprime la séance et la clé de séance active, mais pas `finance_point_<g>_<séance>`, `live_stats_<g>_<séance>`, `shared_occurrence_<séance>`, `shared_owner_*`, `shared_revision_*`.
- Impact : données financières et personnelles (lignes par membre) d'un groupe supprimé conservées, exportées dans les sauvegardes, et réutilisées si un identifiant de groupe est recréé (ex. `team_1`, voir DAT-010).
- Recommandation : supprimer par préfixe toutes les clés du groupe dans la même transaction que `DELETE FROM teams` ; à terme, sortir ces données de `meta` dans des tables avec `team_id` et `ON DELETE CASCADE`.
- Effort : S

### DAT-010 — Un groupe supprimé peut renaître depuis les SharedPreferences héritées
- Sévérité : Mineur / Domaine : suppression / Statut : confirmé (lecture), non reproduit
- Preuve : `team_repository.dart:127-134` : chaque `saveTeamInfo` écrit `team_name`, `team_format`, `team_location` dans SharedPreferences. `deleteTeam` (`:153-163`) ne retire que `active_team_id`. `getActiveTeam` (`:89-103`) : sans groupe ni marqueur de restauration, il recrée un groupe `id: 'team_1'` à partir de `prefs.getString('team_name')`. `main.dart:30` appelle ce chemin au démarrage. Le test `test/startup/active_group_test.dart:200-214` valide ce comportement pour la migration héritée, pas le cas « après suppression ».
- Reproduction : créer un groupe, le supprimer (dernier groupe), relancer l'application : un groupe vide `team_1` portant le nom du groupe supprimé réapparaît.
- Impact : suppression non définitive ; réapparition d'un nom supprimé ; collision possible avec un `team_1` d'une sauvegarde et avec les clés orphelines de DAT-009.
- Recommandation : ne plus écrire ces préférences héritées (ou les effacer dans `deleteTeam`) ; poser un marqueur « migration héritée faite ».
- Effort : S

### DAT-011 — Réglage `min_players_per_session` non scopé appliqué à tous les groupes
- Sévérité : Mineur / Domaine : multi-tenant (réglages) / Statut : confirmé (lecture)
- Preuve : `group_settings_repository.dart:29-33` : sans clé `min_players_per_session_<groupe>`, la valeur globale `meta['min_players_per_session']` (`restored_settings.dart:5`) est renvoyée pour **tout** groupe ; `settings_provider.dart:39-44` retombe ensuite sur `prefs.getInt(key)` global. La restauration écrit cette clé globale (`backup_service.dart:229-231`) et l'export la lit depuis SharedPreferences (`:65`).
- Impact : le minimum d'un groupe restauré s'applique aux groupes créés ensuite ; le minimum conditionne le démarrage et la clôture des séances.
- Recommandation : à la restauration, écrire la valeur par groupe ; supprimer les replis globaux.
- Effort : S

### DAT-012 — Aucun index secondaire sur les colonnes filtrées
- Sévérité : Mineur / Domaine : performance des requêtes / Statut : confirmé (exécution)
- Preuve : `grep -rn "CREATE INDEX" mobile/lib` ne renvoie rien. Script `qp.py` (DDL extrait de `app_database.dart`, base en mémoire) :
  ```
  SELECT * FROM sessions WHERE team_id=? AND status='CLOSED' ORDER BY played_at DESC -> ['SCAN sessions', 'USE TEMP B-TREE FOR ORDER BY']
  SELECT * FROM players WHERE team_id=? -> ['SCAN players']
  SELECT COUNT(*) FROM participations WHERE player_id=? -> ['SCAN participations USING COVERING INDEX sqlite_autoindex_participations_2']
  SELECT * FROM meta WHERE substr(key,1,7)=? -> ['SCAN meta']
  ```
  Seuls index : clés primaires et `UNIQUE(session_id, player_id)`.
- Impact : faible aux volumes actuels (MIG10 : 500 séances, 5 000 participations) ; les vues `v_*` agrègent tous les groupes avant filtrage par `team_id`, donc le coût croît avec le nombre de groupes de l'appareil.
- Recommandation : migration v9 avec `players(team_id)`, `sessions(team_id, status, played_at)`, `participations(player_id)` ; remplacer les filtres `substr(key,…)` par `key >= ? AND key < ?` ou des tables dédiées.
- Effort : S

### DAT-013 — Statut `CANCELLED` : accepté par l'API, refusé par SQLite, séance supprimée localement
- Sévérité : Mineur / Domaine : cohérence modèle ↔ domaine / Statut : confirmé (lecture et exécution)
- Preuve : `backend/app/main.py:911` accepte `status` dans `("DRAFT", "CLOSED", "CANCELLED")` ; `app_database.dart:320` `CHECK(status IN ('DRAFT', 'CLOSED'))` (`fk.py` : `CANCELLED: CHECK constraint failed`). Le client contourne : `shared_service.dart:444` fabrique `CANCELLED` uniquement pour l'envoi, et à l'import `:939-944` **supprime** la séance locale (`txn.delete('sessions', …)`), participations comprises par cascade. Côté finance, l'annulation est un booléen dans le JSON (`financial_point.dart:53`).
- Impact : trois représentations d'une même notion ; une séance annulée n'existe plus localement (pas d'archive ni d'historique consultable), alors qu'elle reste un document serveur. Toute évolution (afficher les séances annulées) imposera une migration.
- Recommandation : décider d'une représentation unique (statut `CANCELLED` dans SQLite, filtré par les vues) et l'aligner dans les trois copies des règles.
- Effort : M

### DAT-014 — Identifiants de joueurs et de groupes à la milliseconde
- Sévérité : Mineur / Domaine : intégrité des identifiants / Statut : confirmé (lecture) ; collision [déduit] rare
- Preuve : `players_repository.dart:166` `id: 'p_${now.millisecondsSinceEpoch}'` ; `team/presentation/create_team_screen.dart:53` `id: 'team_${DateTime.now().millisecondsSinceEpoch}'` ; `backup_service.dart:332` idem en fusion. À l'inverse, séances (`sessions_provider.dart:216`) et opérations (`shared_service.dart:342-348`, `Random.secure()`) sont aléatoires.
- Impact : `players.id` est une clé primaire globale à l'appareil, alors que le serveur scope les membres par groupe. Deux appareils créant un membre à la même milliseconde dans deux groupes, puis un troisième appareil rejoignant les deux groupes : `importSnapshot` lève « Identifiant de membre d'un autre groupe » (`shared_service.dart:796-797`) et toute la synchronisation de ce groupe est bloquée.
- Recommandation : identifiants aléatoires (UUID ou `operationId()`) pour joueurs et groupes.
- Effort : S

### DAT-015 — Import du snapshot : lignes serveur insérées telles quelles dans SQLite
- Sévérité : Mineur / Domaine : synchronisation, robustesse / Statut : confirmé (lecture) ; scénario de blocage [déduit]
- Preuve : `shared_service.dart:929-947` : `session = Map.from(payload['session'])..['team_id'] = groupId` puis `txn.insert('sessions', session)` ; participations insérées brutes (`:961-965`). Le serveur ne restreint pas les clés de `session` ni de chaque participation (`main.py:903-975` valide des champs connus mais n'interdit pas les autres) ; `members` est un `list[dict]` libre (DAT-001).
- Impact : un document contenant une colonne inconnue (client plus récent, portail, appel API direct d'un compte habilité) fait échouer l'insertion ; l'import se fait en une seule transaction, donc **tous** les appareils mobiles du groupe cessent de se synchroniser. Le cloisonnement reste assuré (`team_id` forcé, trigger, contrôle d'identifiants étrangers).
- Recommandation : projeter explicitement les colonnes connues à l'import ; côté API, rejeter les clés inconnues (`extra="forbid"`) ; isoler l'échec d'un document au lieu d'annuler tout l'import.
- Effort : M
- Renvoi : sécurité (validation des entrées API).

### DAT-016 — Garde multi-tenant limitée aux participations
- Sévérité : Mineur / Domaine : intégrité multi-tenant / Statut : confirmé (lecture)
- Preuve : `app_database.dart:251-278` : triggers uniquement `BEFORE INSERT ON participations` et `BEFORE UPDATE OF player_id, session_id ON participations`. Rien n'empêche `UPDATE players SET team_id = …` ou `UPDATE sessions SET team_id = …` sur une ligne déjà référencée. Aucun chemin applicatif actuel ne le fait (vérifié : `importSnapshot` refuse un identifiant d'un autre groupe, l. 796 et 936).
- Impact : défense en profondeur incomplète ; une future évolution (déplacer un joueur de groupe) créerait des participations croisées sans erreur.
- Recommandation : ajouter des triggers `BEFORE UPDATE OF team_id` sur `players` et `sessions` qui refusent si des participations existent.
- Effort : S

### DAT-017 — Backend sans migrations et table `tokens` sans index ni purge
- Sévérité : Mineur / Domaine : schéma backend / Statut : confirmé (lecture)
- Preuve : `main.py:254` `Base.metadata.create_all(schema_engine)` au démarrage, aucun outil de migration dans `backend/requirements.txt`. `models.py:17-22` : `tokens` a pour seule clé `digest` ; les requêtes `select(Token).where(Token.group_id == …, Token.account_id == …)` (`main.py:497, 584, 605, 696`) n'ont pas d'index ; `group_id`/`account_id` des jetons ne sont liés à aucune contrainte vers un compte (les comptes vivent dans le JSON).
- Impact : `create_all` ne modifie jamais une table existante : tout ajout de colonne ou d'index en production devra être appliqué à la main sur Neon. La table des jetons grossit sans fin (DAT-007) et chaque réinitialisation la parcourt.
- Recommandation : introduire Alembic (ou des scripts SQL versionnés) ; index `tokens(group_id, account_id)` et `tokens(expires_at)` ; tâche de purge.
- Effort : M

### DAT-018 — Snapshot : journal d'audit et responsables exposés à tous les comptes, y compris l'accès collectif
- Sévérité : Mineur / Domaine : minimisation / Statut : confirmé (lecture)
- Preuve : `main.py:509` `result = {k: state[k] for k in ("name", "roles", "members", "documents", "opening", "audit")}` sans condition de rôle ; `:517` `result["leaders"] = [public_account(a) …]` (identifiants de connexion et rôles des responsables). Seuls `history`/`candidates` (l. 518-522, hors PDT/VP) et `accounts` (l. 523-524, ADMIN) sont filtrés.
- Impact : tout porteur de l'accès collectif voit l'intégralité du journal (motifs de correction, auteurs, dates) et les noms d'utilisateur des responsables, utiles à une attaque par mot de passe ciblée. Ces données sont ensuite stockées dans `meta` (`shared_snapshot_<g>`) et exportées en sauvegarde.
- Recommandation : réserver `audit` aux rôles de gouvernance ; tronquer aux N dernières entrées ; ne pas exposer `username` des responsables aux comptes partagés.
- Effort : S
- Renvoi : sécurité.

### DAT-019 — Sauvegarde : un fichier unique contient tous les groupes, photos et métadonnées partagées
- Sévérité : Mineur / Domaine : sauvegarde, données personnelles / Statut : confirmé (lecture)
- Preuve : `backup_service.dart:70-84` exporte toutes les lignes de `teams`, `players`, `sessions`, `participations` et `meta` (outbox, snapshots, finances de tous les groupes) ; les photos locales sont relues et intégrées en base64 jusqu'à 32 Mio (`player_photo.dart:13`, `prepareRows` l. 151-188). Le fichier est écrit en clair dans le répertoire temporaire puis partagé (`:41-55`), sans suppression ultérieure. Le remplacement complet restaure aussi `meta` tel quel (`:218-225`), dont `shared_group_*` et `outbox_*` d'un autre appareil.
- Impact : partager la sauvegarde d'un groupe expose les données de tous les autres groupes de l'appareil ; le fichier temporaire persiste. Une restauration complète importe des événements d'outbox étrangers, ignorés par la synchronisation (filtre auteur, `shared_service.dart:569-571`) mais conservés indéfiniment.
- Recommandation : proposer l'export par groupe ; exclure `outbox_*` et `shared_snapshot_*` de l'export ; supprimer le fichier temporaire après partage ; documenter le caractère sensible du fichier.
- Effort : M

### DAT-020 — Documentation données en écart avec le code
- Sévérité : Mineur / Domaine : documentation / Statut : confirmé (lecture)
- Preuve :
  - `docs/outbox-sync.md:42` : un 200 est « Retirée de la file outbox » ; code : conservé avec `status: accepted` (DAT-004). `docs/outbox-sync.md:45` range 409 hors des refus permanents ; code : `const [400, 403, 404, 409, 410, 422]` (`shared_service.dart:612-613`) traite tout 409 non `active_session_conflict` comme `rejected`.
  - `docs/outbox-sync.md:52` : « Chaque opération outbox est explicitement liée au `team_id` actif » ; exact pour le champ `group_id`, mais l'outbox n'existe que pour le groupe connecté (`shared_service.dart:358`).
  - `docs/backup.md:24` : « une version future n'est pas explicitement refusée » ; code : `backup_payload.dart:92-97` la refuse.
  - `docs/database.md:7` : « onConfigure active les clés étrangères » ; code : désactivées pour les versions 1 à 6 pendant la migration (`app_database.dart:66-70`).
- Impact : les décisions (purge, rejeu) s'appuient sur une doc inexacte.
- Recommandation : corriger les trois documents.
- Effort : XS

---

## 5. Hypothèses à vérifier

1. **Restauration complète et `protectedGroups`** : la restauration remplace `meta`, donc les marqueurs `shared_group_<g>` (`backup_service.dart:181, 218-225`). Après redémarrage, un groupe partagé absent du fichier restauré ne serait plus protégé : `canWrite` (`shared_service.dart:34-38`) autoriserait des écritures locales hors synchronisation. À reproduire par un test.
2. **Restauration complète avec `team_id` mixtes** : un joueur à `team_id` inconnu est remappé vers le premier groupe (`backup_service.dart:193-200`) tandis que ses séances gardent un `team_id` valide d'un autre groupe ; le trigger de participations ferait alors échouer toute la restauration. À vérifier avec un fichier construit.
3. **Taille réelle de `groups.state` en production** : non mesurée (pas d'accès Neon). Requête suggérée, en lecture seule et avec accord : `SELECT id, pg_column_size(state) FROM groups ORDER BY 2 DESC LIMIT 10`.
4. **Flutter web** : la base `statoo.db` via `sqflite_common_ffi_web` est partagée par tous les groupes d'une même origine et n'est pas effacée à la déconnexion (DAT-007) ; impact sur un navigateur partagé à confirmer en exécution.
5. **Suppression locale d'un groupe partagé** : `deleteTeam` n'empêche pas de supprimer le groupe connecté ; le prochain `importSnapshot` le recréerait partiellement (joueurs, documents) sans les réglages locaux supprimés. Non reproduit.

## 6. Points positifs (Info)

- **Requêtes mobiles scopées** : toutes les lectures et écritures de `players`, `sessions`, vues `v_*` et clés `meta` par groupe portent `team_id` (repositories `players`, `ranking`, `stats`, `finance`, `sessions`, `team`). Les requêtes sans `team_id` sont : (a) les participations filtrées par `session_id` **après** vérification `id = ? AND team_id = ?` dans la même transaction (`sessions_repository.dart:413, 586, 627, 759, 846, 870`, `live_stats_repository.dart:83, 124` via `_snapshot` l. 249/298, `shared_service.dart:437-441`) ; (b) `players_repository.dart:231` (comptage par identifiant de joueur, suivi d'un contrôle d'appartenance l. 236) ; (c) les lectures globales voulues (`teams`, sauvegarde, `active_team_id`, `_restore_completed`, `schema_version`) ; (d) les clés `shared_occurrence_<séance>`, `shared_owner|revision|generation_<domaine>_<séance>`, `outbox_<id>` (groupe porté par la valeur), sûres tant que les identifiants de séance restent aléatoires ; (e) le repli global de DAT-011.
- **Défense en profondeur SQLite** : triggers `trg_participations_same_team_*`, recréés par `_ensureViews` s'ils manquent ; `INSERT OR REPLACE` d'une séance d'un autre groupe refusé (`sessions_repository.dart:361-371`) ; vues partitionnées par `team_id` (`ROW_NUMBER() OVER (PARTITION BY team_id …)`).
- **Backend** : `scoped()` (`main.py:315-319`) compare le groupe du jeton au `group_id` de l'URL sur toutes les routes de groupe ; `validate_sport` impose `session.team_id == group_id` et des participants membres du groupe ; idempotence par `operation_id` avec empreinte et auteur (`main.py:758-763`).
- **Outbox** : événements filtrés par `group_id` et auteur à l'envoi (`shared_service.dart:567-571`) et à l'import ; génération de connexion qui neutralise les réponses tardives après déconnexion.
- **Portail** : stockage local préfixé par `api|groupe|compte` (`web/client.mjs:46-57`) et purgé par préfixe à la déconnexion (`:121-139`) ; brouillon d'inscription sans mot de passe (`web/registration-draft.mjs:62-78`).
- **Transactions** : création et clôture de séance, saisie en direct, import de snapshot, restauration (photos préparées hors transaction, SharedPreferences jamais modifiées dans la transaction, `backup_service.dart:161-237`) ; migrations atomiques avec contrôle `foreign_key_check` et tests MIG01 à MIG11, dont un volume de 5 000 participations.
- **Caches Riverpod** : les providers de données (`players`, `sessions`, `ranking`, `stats`, `finance`, `settings`, `shared`) font `ref.watch(activeTeamIdProvider)` et sont donc recalculés au changement de groupe ; `GroupIntSettingNotifier._load` ignore une valeur lue pour un groupe devenu inactif (`settings_provider.dart:48-53`).
- **Sauvegarde** : version validée (refus des versions futures), statuts `CLOSED` sans score ramenés en brouillon comme la migration v5, photos bornées (2 Mio par photo, 32 Mio au total), chemins locaux importés ignorés.

## 7. Renvois vers d'autres domaines

- Sécurité : validation des entrées API (`list[dict]` libres pour `members`, clés de séance non contraintes, DAT-001/DAT-015) ; exposition des noms d'utilisateur des responsables (DAT-018).
- Performance : verrou global et `FOR UPDATE` sur les lectures (DAT-002/DAT-003) ; synchronisation toutes les 45 s qui télécharge le snapshot complet avec photos.
- Architecture : accès SQLite et HTTP depuis `presentation/` dans `shared_group_screen.dart:1161-1171` (`_publishMembers`).
- Parité web-mobile : la représentation de l'annulation diffère entre portail, API et mobile (DAT-013).

## Vérification croisée (Phase 4, 14/11/2026)

Tous les constats Critique et Majeur de ce rapport ont été relus et **confirmés** (aucun retrait, aucune requalification). Verdicts : [raw/verification-phase4.md](raw/verification-phase4.md).
