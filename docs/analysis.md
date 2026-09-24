# Analyse du projet Statoo

Ce document synthétise les règles métier, la liste des écrans, les divergences identifiées entre le Cahier des Charges (CDC) et les maquettes, ainsi que les questions ouvertes avant de démarrer le développement.

## 1. Entités et Modèle de Données (Source de vérité)

Le CDC (Section 4) définit un modèle de données strict basé sur SQLite, qui sera implémenté en priorité via des entités métier et un stockage in-memory pour la phase de prototypage.

*   **Player (`players`) :** Identifiant, nom, surnom, avatar_url, statut actif/archivé.
*   **Session (`sessions`) :** Identifiant, date/heure, statut (`DRAFT` ou `CLOSED`), mode de répartition, indicateur si équipes inégales autorisées, indicateur de match classé, scores, buts non attribués et notes.
*   **Participation (`participations`) :** C'est la **seule source de vérité**. Identifiant, joueur, séance, équipe (A ou B), buts, passes, cartons jaunes, cartons rouges.

## 2. Règles Métier Invariantes

*   **Calculs dynamiques :** Aucun cumul n'est stocké en base. Tous les totaux (points, classements, statistiques) sont déduits à la volée depuis la table `participations` (ou les vues SQL).
*   **Barème :** 3 pts pour une victoire, 1 pt pour un nul, 0 pt pour une défaite.
*   **Clôture bloquante :** Le score doit être renseigné, tous les joueurs présents doivent être affectés, aucun joueur ne doit être en double, et l'écart d'effectif doit être ≤ 1 (sauf exception explicitement autorisée `allow_uneven_teams = true`).
*   **Clôture non bloquante :** Si la somme des buts (attribués aux joueurs + non attribués) est différente du score final, un avertissement est affiché, mais la clôture reste possible.
*   **Classement :** Ne prend en compte que les séances avec `status = 'CLOSED'` et `is_ranked = true`.
*   **Archivage :** Un joueur ayant déjà joué au moins une fois ne peut pas être supprimé (règle `ON DELETE RESTRICT`). Il est simplement passé en `is_active = false`.

## 3. Liste des Écrans et Sources

| Écran | Route | Source Principale | Remarques |
| :--- | :--- | :--- | :--- |
| Accueil | `/` | Capture (`01-accueil.jpg`) | Contient le résumé de la dernière séance et le top 3 du classement. |
| Nouvelle séance (1/3) | `/seances/nouvelle` | Capture (`04-seances-nouvelle.jpg`) | Sélection de la date/heure. |
| Nouvelle séance (2/3) | `/seances/nouvelle` | CDC (6.2) | Déduit : Présélection des joueurs et tirage aléatoire des équipes. |
| Nouvelle séance (3/3) | `/seances/nouvelle` | CDC (6.2) | Déduit : Saisie du score et statistiques individuelles avant validation. |
| Détail séance | `/seances/:id` | Capture (`08-seance-detail-s9.jpg`) | Score, composition, statistiques par équipe et actions (Rouvrir/Supprimer). |
| Fiche joueur | `/joueurs/:id` | Capture (`09-joueur-detail-p1.jpg`) | Synthèse, statistiques brutes et historique des matchs. |
| Liste Joueurs | `/joueurs` | CDC (6.1) / Extrapolation | Tri par nom (actifs d'abord), recherche. Maquette = Placeholder. |
| Liste Séances | `/seances` | Extrapolation | Liste chronologique inversée. Maquette = Placeholder. |
| Classement | `/classement` | CDC (6.3) / Extrapolation | Principal (assiduité/points totaux) et Alternatif (ratio, min 50% présence). |
| Stats globales | `/stats` | CDC (6.3) / Extrapolation | Totaux du groupe (buts, passes, cartons, moyenne). |
| Réglages | `/reglages` | CDC (6.4) / Extrapolation | Sauvegarde et restauration Supabase. |

## 4. Divergences identifiées (Maquettes vs CDC)

Conformément aux consignes, **le design des maquettes prime sur le CDC**.

1.  **Thème Clair / Sombre :** Le CDC (Section 3) mentionne des "modes clair/sombre basés sur Figma". Cependant, la consigne (Section 4) indique explicitement "Application en thème sombre uniquement (pas de thème clair dans cette version)". **Résolution :** Implémentation du thème sombre uniquement.
2.  **Affichage de l'accueil :** Le CDC ne précise pas le contenu de la page d'accueil. La maquette montre un résumé très spécifique (Dernière séance, classement Top 3, 3 tuiles de statistiques). **Résolution :** Suivi strict de la maquette.
3.  **Classement :** La maquette de l'accueil montre un classement par "points totaux" et "assiduité" (ex: J 14). Le CDC précise l'existence d'un classement alternatif par ratio (pts/match) pour ceux ayant ≥ 50% de présence. **Résolution :** Le Top 3 de l'accueil affichera le classement principal (Points totaux) comme sur la maquette. Le classement alternatif sera disponible sur l'écran dédié `/classement` (Placeholder).

## 5. Questions ouvertes / Hypothèses (TODO cdc)

*   **`TODO(cdc)` - Étapes 2 et 3 de la création de séance :** Je pars de l'hypothèse suivante pour le wizard de création de séance :
    *   **Étape 1 :** Date et Heure (conforme à la capture).
    *   **Étape 2 :** Sélection des joueurs présents, puis génération automatique des équipes (`RandomSplitter`). L'utilisateur peut ajuster manuellement.
    *   **Étape 3 :** Saisie des scores finaux, des buts non attribués, et des statistiques individuelles (buts, passes, cartons) avant de valider la séance. Est-ce bien le flux attendu ?
*   **`TODO(cdc)` - Supabase (Lot 5) :** L'intégration de `supabase_flutter` pour le backup JSON est listée au lot 5 du CDC. Dans cette première itération (focalisée UI + in-memory data), doit-on préparer l'UI pour la restauration (écran réglages) avec des mocks, ou implémenter directement le SDK ? *Choix par défaut : Mocks UI d'abord.*
