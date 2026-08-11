# Statoo — Cahier des charges

**Version** 1.0 · **Cible** V1 (APK Android) · **Schéma DB** v1

---

## 1. Contexte et objectif

Statoo est une application personnelle de suivi d'un groupe de foot 5x5 entre amis.
Un seul utilisateur : l'administrateur du groupe, qui saisit les séances depuis son
téléphone. Un seul appareil. Aucun compte, aucun partage temps réel.

**Objectif** : remplacer le fichier tableur / les notes du téléphone par un outil qui
enregistre une séance en moins de deux minutes et produit un classement fiable.

**Non-objectif** : servir de terrain d'expérimentation architectural. Trois tables,
pas de couches inutiles.

### Critères de succès

| Critère | Cible |
|---|---|
| Saisie complète d'une séance (tirage → clôture) | < 2 min |
| Fonctionnement hors ligne | 100 % des fonctions |
| Perte de données après réinstallation | 0 (via backup) |
| Ouverture à froid de l'app | < 2 s |

---

## 2. Périmètre

### Dans le périmètre (V1)

- Gestion des joueurs (création, édition, archivage).
- Création de séance, tirage aléatoire des équipes, édition manuelle.
- Saisie du score, des buts, passes et cartons.
- Clôture de séance avec règles de validation.
- Classement (points totaux + points/match) et statistiques individuelles.
- Statistiques globales du groupe.
- Backup JSON vers Supabase Storage + restauration.

### Hors périmètre (explicitement)

- Multi-utilisateurs, authentification, rôles, partage.
- Synchronisation bidirectionnelle, résolution de conflits.
- Backend applicatif, API serveur.
- Notifications, invitations, calendrier, gestion des présences prévisionnelles.
- Tournois, championnats sur plusieurs saisons, poules.
- Export PDF/CSV, graphiques avancés.
- `BalancedSplitter` (prévu V2, l'interface est en place).

---

## 3. Stack technique

| Couche | Choix |
|---|---|
| Framework | Nuxt 4 (mode SPA / `ssr: false`) + Vue 3 `<script setup>` |
| UI | Nuxt UI |
| Base locale | SQLite via `@capacitor-community/sqlite` — **source de vérité** |
| Packaging | Capacitor (build APK Android) |
| Backup | Supabase Storage, bucket privé, RLS owner |
| Backend | Aucun |

### Contraintes d'architecture

- Les agrégats ne sont **jamais** calculés en JavaScript : ils sortent des vues SQL
  (`v_player_stats`, `v_standings`, `v_group_totals`, `v_session_summary`).
- Une seule connexion SQLite ouverte au démarrage, fermée à la mise en arrière-plan.
- Le web (dev) utilise le driver `jeep-sqlite` ; l'APK utilise le driver natif. Le
  même code d'accès sert les deux.
- Les migrations sont des fichiers SQL numérotés (`001_init.sql`, `002_views.sql`, …)
  appliqués séquentiellement selon `meta.schema_version`.

---

## 4. Modèle de données — figé

### 4.1 Tables

**players**
`id` (TEXT, PK), `name` (NOT NULL), `nickname`, `avatar_url`,
`is_active` (0/1, def. 1), `created_at`, `updated_at`

**sessions**
`id` (TEXT, PK), `played_at` (NOT NULL),
`status` ∈ {`DRAFT`, `CLOSED`} (def. `DRAFT`),
`split_mode` ∈ {`RANDOM`, `RANDOM_ADJUSTED`, `MANUAL`} (def. `MANUAL`),
`allow_uneven_teams` (0/1, def. 0), `is_ranked` (0/1, def. 1),
`score_a`, `score_b`, `result` ∈ {`A`, `B`, `DRAW`},
`unassigned_goals_a`, `unassigned_goals_b` (def. 0), `notes`,
`created_at`, `updated_at`

**participations**
`id` (TEXT, PK), `session_id` (FK → sessions, ON DELETE CASCADE),
`player_id` (FK → players, ON DELETE RESTRICT), `team` ∈ {`A`, `B`},
`goals`, `assists`, `yellow_cards`, `red_cards` (tous ≥ 0, def. 0),
`created_at`, `updated_at`, **UNIQUE (session_id, player_id)**

**meta**
`key` (PK), `value` — contient `schema_version`.

### 4.2 Contraintes garanties par le schéma

- Une séance `CLOSED` porte obligatoirement `score_a`, `score_b` et `result`.
- `result` est cohérent avec les scores (CHECK dérivé).
- Un joueur ne peut pas apparaître deux fois dans la même séance (UNIQUE).
- Un joueur ayant des participations ne peut pas être supprimé (`ON DELETE RESTRICT`).
- Supprimer une séance supprime ses participations (`ON DELETE CASCADE`).
- `updated_at` maintenu par triggers.

### 4.3 Vues dérivées

| Vue | Rôle |
|---|---|
| `v_closed_participations` | Base : une ligne par participation en séance close, avec sa valeur en points (NULL si non classée) |
| `v_ranked_session_count` | Dénominateur mobile du seuil de 50 % |
| `v_player_stats` | Une ligne par joueur, y compris archivés |
| `v_standings` | Classement par points totaux |
| `v_standings_per_match` | Classement par efficacité, filtré par le seuil |
| `v_group_totals` | Totaux du groupe |
| `v_session_summary` | Effectifs, format dérivé, contrôle de cohérence des buts |

---

## 5. Règles métier invariantes

Toute proposition contredisant ces règles doit être signalée explicitement, jamais
appliquée silencieusement.

1. **`participations` est l'unique source de vérité.** Aucun cumul stocké. Points,
   totaux, classement, pourcentages : tous dérivés à la lecture.
2. **Une séance = un match.** Barème 3 (victoire) / 1 (nul) / 0 (défaite).
3. **Conditions de clôture** : score renseigné, tous les présents affectés à une
   équipe, aucun joueur dans les deux équipes, écart d'effectif ≤ 1 sauf si
   `allow_uneven_teams = true`.
4. **Avertissement non bloquant** si `Σ goals(équipe) + unassigned ≠ score`. La
   clôture reste possible.
5. **Agrégats de points** calculés sur `status = 'CLOSED' AND is_ranked = true`.
   Les buts, passes et cartons comptent même si `is_ranked = false`.
6. **Aucune suppression de joueur ayant joué** : `is_active = false` (archivage).
   Le joueur archivé reste dans les statistiques historiques.
7. **Le format n'est pas stocké** (5v5, 4v4, 6v4) : il se dérive du comptage par
   équipe dans `v_session_summary`.

---

## 6. Fonctionnalités

### 6.1 Joueurs

**Liste**
- Actifs d'abord, triés par nom ; archivés dans une section repliée.
- Chaque ligne : avatar (ou initiales), nom, surnom, J / points / buts.
- Recherche par nom ou surnom.

**Création / édition**
- Champs : nom (obligatoire), surnom, avatar (optionnel).
- Doublon de nom : avertissement, pas de blocage (des homonymes existent).

**Archivage**
- Bouton « Archiver » → `is_active = 0`. Réversible.
- Un joueur archivé n'apparaît plus dans la sélection des présents mais reste
  au classement et dans l'historique.
- La suppression définitive n'est proposée que si le joueur n'a aucune
  participation. Sinon le bouton est absent (pas grisé avec explication : absent).

**Fiche joueur**
- Bloc synthèse : J, V/N/D, points, pts/match, % victoires.
- Bloc brut : buts, passes, cartons jaunes/rouges, apparitions totales.
- Historique des séances jouées, plus récentes d'abord.

### 6.2 Séances

**Liste**
- Ordre antéchronologique (`played_at DESC`).
- Badge `DRAFT` / `CLOSED`, format dérivé (« 5v5 »), score, badge « Amical » si
  `is_ranked = false`, pastille d'avertissement si `has_goal_mismatch = 1`.

**Création**
1. Date et heure (`played_at`, pré-remplies à maintenant).
2. Sélection des présents parmi les joueurs actifs.
3. Options : séance classée (défaut oui), effectifs inégaux autorisés (défaut non).
4. La séance est créée en `DRAFT`.

**Composition des équipes**
- Bouton « Tirer au sort » : `RandomSplitter` (Fisher-Yates), `split_mode = 'RANDOM'`.
- Le tirage produit un brouillon éditable jusqu'à la clôture.
- **Le bouton de tirage reste accessible en permanence.** Il écrase la composition
  courante, avec confirmation explicite (« Remplacer la composition actuelle ? »).
- Édition manuelle : déplacer un joueur d'une équipe à l'autre, ajouter un présent
  oublié, retirer un absent. Toute édition manuelle bascule `split_mode` sur
  `'MANUAL'` si le mode était `'RANDOM'`.
- L'édition manuelle **n'est pas un splitter** : c'est une opération sur
  `TeamAssignment` (`move` / `add` / `remove`). Elle n'implémente pas `TeamSplitter`.

**Saisie des statistiques**
- Score de chaque équipe (obligatoire pour clore).
- Par joueur : buts, passes, cartons — compteurs +/-, valeur par défaut 0.
- Buts non attribués : `unassigned_goals_a` / `unassigned_goals_b`, saisis
  directement ou proposés automatiquement comme le reste entre le score et la
  somme des buts individuels.

**Clôture**
- Contrôles bloquants : score des deux équipes renseigné ; tout présent affecté à
  A ou B ; aucun joueur dans les deux équipes (garanti par UNIQUE) ; `|size_a −
  size_b| ≤ 1` sauf `allow_uneven_teams`.
- Contrôle non bloquant : cohérence des buts (règle 4) → bandeau d'avertissement,
  clôture possible après confirmation.
- À la clôture : `result` calculé depuis les scores, `status = 'CLOSED'`, puis
  déclenchement automatique du snapshot de backup.

**Réouverture / suppression**
- Une séance close peut être rouverte (`status = 'DRAFT'`) après confirmation ; le
  classement se recalcule immédiatement puisque tout est dérivé.
- Suppression d'une séance : confirmation, cascade sur les participations.

### 6.3 Classement

**Tri par défaut : points totaux**
- Colonnes : rang, joueur, **J** (toujours visible), V, N, D, points, pts/match.
- Départage : points desc → pts/match desc → J desc → (buts + passes) desc → nom.
- Le total est dominé par l'assiduité : c'est assumé et rendu lisible par la
  présence permanente de la colonne J.

**Tri alternatif : points/match**
- Seuil d'éligibilité : avoir disputé ≥ 50 % des séances classées closes
  (`is_eligible`, dénominateur mobile).
- Départage : pts/match desc → J desc → (buts + passes) desc → nom.
- Les joueurs sous le seuil sont listés à part, en dessous, en gris, avec la
  mention du nombre de séances manquantes.

**Classements secondaires** : meilleurs buteurs, meilleurs passeurs, cartons.
Ceux-là comptent toutes les séances closes, classées ou non (règle 5).

### 6.4 Statistiques globales

Depuis `v_group_totals` : séances jouées, dont classées, joueurs actifs / total,
buts totaux (score réel), buts attribués, écart attribué/réel, passes, cartons,
moyenne de buts par séance.

### 6.5 Backup et restauration

**Snapshot**
- Déclenché automatiquement après chaque clôture de séance, et manuellement
  depuis les réglages.
- Contenu : export intégral des trois tables + `meta`.
- Le champ `schema_version` est **obligatoire en tête du JSON**.
- Nommage : `statoo-backup-YYYYMMDD-HHmmss.json`.
- Destination : Supabase Storage, bucket privé, RLS owner.
- Si l'appareil est hors ligne : échec silencieux non bloquant, marqué comme
  « backup en attente », retenté au prochain lancement avec réseau.

**Rétention**
- 20 fichiers conservés, les plus anciens supprimés à l'ajout d'un nouveau.

**Restauration**
- Liste des sauvegardes disponibles (date, taille, nombre de séances).
- Procédure : confirmation explicite → **wipe local complet** → réimport intégral.
- Refus si `schema_version` du fichier > version supportée par l'app.
- Pas de synchronisation bidirectionnelle, pas de fusion, pas de résolution de
  conflit. La restauration écrase, point.

---

## 7. Écrans

| Écran | Contenu |
|---|---|
| Accueil | Dernière séance, prochaine action (« Nouvelle séance »), top 3 du classement, état du dernier backup |
| Joueurs | Liste + recherche + accès création |
| Fiche joueur | Synthèse, stats brutes, historique |
| Séances | Liste antéchronologique |
| Détail séance | Composition, saisie stats, clôture |
| Classement | Onglets « Points » / « Pts/match » + classements secondaires |
| Statistiques | Totaux du groupe |
| Réglages | Backup manuel, restauration, version du schéma, à propos |

---

## 8. Exigences non fonctionnelles

- **Hors ligne** : toutes les fonctions sauf backup/restauration.
- **Performance** : listes fluides jusqu'à 50 joueurs et 500 séances. Les vues SQL
  suffisent à cette échelle ; pas de cache applicatif.
- **Intégrité** : `PRAGMA foreign_keys = ON` à chaque ouverture de connexion.
- **Écriture** : toute opération multi-tables (création de séance + participations,
  clôture, restauration) est encapsulée dans une transaction.
- **Ergonomie** : usage à une main, cibles tactiles ≥ 44 px, saisie des stats
  possible bord de terrain.
- **Langue** : interface en français ; code, identifiants et commentaires en anglais.

---

## 9. Conventions de développement

- Explications et échanges : **français**. Code, identifiants, commentaires,
  messages de commit : **anglais**.
- Conventional commits (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`).
- Pas de sur-ingénierie : ni DDD, ni event sourcing, ni CQRS sur ce projet.
- Une seule interface d'abstraction assumée : `TeamSplitter`, justifiée par le
  `BalancedSplitter` prévu en V2.
- Toute proposition contredisant les invariants de la section 5 doit être signalée
  explicitement.

### Arborescence indicative

```
app/
  pages/          index, players/, sessions/, standings, stats, settings
  components/     player/, session/, standings/
  composables/    useDb, usePlayers, useSessions, useStandings, useBackup
  lib/
    db/           connection, migrations, queries
    splitter/     TeamSplitter.ts, RandomSplitter.ts, TeamAssignment.ts
    backup/       exporter, importer, supabase client
db/migrations/    001_init.sql, 002_views.sql
```

---

## 10. Plan de livraison

| Lot | Contenu | Sortie |
|---|---|---|
| L1 | Connexion SQLite, migrations, CRUD joueurs | App qui liste et crée des joueurs |
| L2 | Séances : création, présents, tirage, édition manuelle | Brouillon de composition |
| L3 | Saisie stats + clôture + règles de validation | Séance close en base |
| L4 | Classement et statistiques (vues) | Classement complet |
| L5 | Backup / restauration Supabase | Sauvegarde automatique après clôture |
| L6 | Build APK Capacitor, tests sur appareil | APK installable |

---

## 11. Risques

| Risque | Mitigation |
|---|---|
| Perte du téléphone / réinstallation | Backup automatique après chaque clôture |
| Seuil de 50 % instable en début de saison | Dénominateur mobile assumé ; le classement par points reste le tri par défaut |
| Buts mal attribués | Avertissement non bloquant + champs `unassigned_goals` |
| Divergence entre score réel et buts attribués sur les stats globales | Les deux chiffres sont affichés séparément dans `v_group_totals` |
| Migration de schéma future | `meta.schema_version` + refus de restaurer un backup plus récent que l'app |

---

## 12. Glossaire

- **Séance** : une soirée de foot = un match unique avec un résultat.
- **Séance classée** (`is_ranked = 1`) : compte pour les points. Sinon « amicale ».
- **Format** : notation « 5v5 », dérivée du comptage par équipe, jamais stockée.
- **Buts non attribués** : buts marqués mais non affectés à un joueur (csc, oubli).
- **Éligible** : joueur ayant disputé ≥ 50 % des séances classées, seul à figurer
  au classement pts/match.
