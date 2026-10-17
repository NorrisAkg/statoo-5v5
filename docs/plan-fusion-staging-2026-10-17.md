# Plan de fusion de staging — examen du 17 octobre 2026

## État vérifié après fetch

- Base commune : `4266cdaa473e42d5e73d9cfec449be2b2beb3e81`.
- `staging` local : `8193637` — saisie en direct et journal local, prototype et tests.
- `origin/staging` : `e6cef61` — gestion sportive accordée aux comptes individuels ADMIN/PDT/VP en plus de SG/SGA, tests et documentation associés.
- Divergence : un commit de chaque côté. La précédente fusion était locale ; elle n'incluait pas le commit distant et aucun push n'a été effectué.
- Dossier courant : 55 fichiers suivis modifiés et 91 fichiers non suivis, inventoriés individuellement. Ce sont aussi des travaux à préserver, distincts des deux commits.

La simulation `git merge-tree --write-tree --messages staging origin/staging` réussit sans conflit ; arbre synthétique `f52c15cb62b1166e556949b6d3dbc1e8a4762ef9`. Elle écrit seulement des objets Git : aucune fusion appliquée, aucun déplacement de branche, aucun fichier de travail remplacé.

## Contenus importants à conserver

| Source | À conserver |
|---|---|
| Commit local | But/buteur/passeur atomiques, journal, correction/annulation, contrôle de propriété via SharedService, tournoi par victoires, résumé validé et tests. |
| Commit distant | Rôles sportifs ADMIN/PDT/VP/SG/SGA sur API, Flutter et portail ; transferts vers ces responsables ; comptes collectifs toujours refusés ; propriété/conflits et droits financiers inchangés. |
| Travaux non commités | Flutter web commun, transport HTTP multiplateforme, cycle de vie partagé `is_active`, gestion des conflits de démarrage, noms courts et sauvegardes, onboarding web, cadrage/accessibilité des finances et écrans, règles de design/tests. Classer séparément les preuves d'audit et captures. |
| Choix produit récent | Préremplissage de toutes les cotisations au tarif, effacement des impayés ; décision enregistrée, pas encore implémentée. |

**Point de livraison important :** `mobile/lib/main_web.dart`, `mobile/web/index.html`, `scripts/build-universal-web.sh`, `scripts/package-universal-web.mjs`, `mobile/lib/core/data/shared_http.dart` et `vercel.json` ne sont suivis ni dans `staging` local ni dans le distant. Ils existent dans les travaux locaux. La seule fusion des deux commits ne livrerait donc pas le parcours Flutter web montré dans l'aperçu. Les tests annoncés pour l'intégration ont été exécutés dans ce dossier enrichi, pas dans un checkout ne contenant que `8193637`.

## Recouvrements avec les modifications non commitées

Simulation trois voies par fichier, avec base commune, fichier local courant et version distante. Aucune modification de ces fichiers ; copies temporaires uniquement dans `mobile/build/merge-plan-*`.

| Fichier | Résultat textuel | Arbitrage nécessaire |
|---|---|---|
| `backend/app/main.py` | Sans conflit | Garder les rôles distants ET le cycle de vie local des séances. |
| `mobile/lib/features/shared/data/shared_service.dart` | Sans conflit | Garder droits distants ET transport web, état actif et récupération locale. |
| `mobile/lib/features/shared/presentation/shared_group_screen.dart` | Sans conflit | Garder destinataires ADMIN/PDT/VP ET adaptations locales de présentation. |
| `web/README.md` | Sans conflit | Décrire les deux parcours et l'état réel du packaging. |
| `web/app.mjs` | Sans conflit | Garder onboarding local ET droits/messages/transferts distants. |
| `web/tests/browser.e2e.mjs` | Sans conflit | Conserver les deux séries de scénarios. |
| `web/tests/sport-flow.e2e.mjs` | Sans conflit | Conserver nouveaux rôles et parcours locaux. |
| `web/sw.js` | 1 conflit | Remplacer les deux versions concurrentes de cache par une nouvelle version de livraison commune. |
| `web/tests/pwa.test.mjs` | 2 conflits | Lister tous les anciens caches, conserver uniquement le nouveau cache du bon scope ; préserver les caches hors scope. |

Aucune collision de nom entre les fichiers non suivis actuels et les fichiers ajoutés/modifiés par le commit distant. L'absence de conflit textuel ne prouve pas la compatibilité métier.

## Ordre d'exécution proposé

1. **Geler et sauvegarder le travail courant.** Relever les SHA, créer des références de sécurité pour les deux commits et conserver les diffs binaires, l'inventaire et une copie des fichiers non suivis. Vérifier les empreintes de la copie. Garder les captures, bases locales, `.env` et autres fichiers ignorés utiles hors des commits applicatifs et dans une sauvegarde privée appropriée. Ne pas compter sur un stash simple, qui omet les non-suivis.
2. **Préparer un checkout isolé.** Utiliser un worktree géré sur une branche `codex/merge-staging-2026-10-17`, à partir du dernier `origin/staging`. Ne pas faire de checkout/reset du dossier sale actuel. Réutiliser un worktree adapté s'il existe déjà.
3. **Fusionner le commit local dans cette branche.** Merge normal de `8193637`, sans squash ni réécriture, pour conserver les deux historiques. La simulation actuelle prévoit zéro conflit. Vérifier que les deux SHA sont ancêtres du candidat.
4. **Réintégrer les travaux non commités par lots cohérents**, à partir de la sauvegarde : (a) plateforme Flutter web et build/transport ; (b) cycle de vie API et synchronisation ; (c) identité, noms courts et sauvegardes ; (d) onboarding/portail ; (e) cadrage/design/finance. Conserver chaque test, documentation et dépendance de son lot. Les preuves brutes d'audit restent disponibles sans être ajoutées automatiquement au commit. Recontrôler le périmètre des lots car certains fichiers portent plusieurs sujets.
5. **Résoudre le cache PWA et ses tests ensemble.** Écrire avant modification les scénarios de coexistence/suppression des versions locales et distantes. Employer une nouvelle version, ne pas choisir aveuglément `ours` ou `theirs`.
6. **Valider l'ensemble dans le checkout propre**, selon la matrice ci-dessous. Corriger avec scénarios/tests RED avant tout correctif. Faire une revue dédiée de la fusion et des permissions.
7. **Comparer à nouveau au distant.** Refetch juste avant livraison. Si le distant a bougé, intégrer les nouveaux commits et reprendre les contrôles concernés. Avancer `staging` vers le candidat vérifié puis effectuer un push normal uniquement quand la livraison est demandée. Aucun `push --force`, `reset --hard` ni `clean`.
8. **Garder la sauvegarde tant que la recette n'est pas terminée.** Comparer l'inventaire initial aux fichiers conservés/intégrés/exclus avec raison. Ne supprimer aucun travail local au motif qu'il serait absent du commit final. Un retour arrière avant push consiste à abandonner le candidat, sans toucher au dossier original ; après publication, utiliser un revert explicite si nécessaire.

## Matrice de validation de la fusion

- Permissions croisées API/Flutter/portail : ADMIN, PDT, VP, SG et SGA peuvent gérer leurs séances ; MEMBER, comptes collectifs, identité expirée et mauvais groupe refusés ; responsable tiers et conflits restent protégés ; aucun droit financier ajouté.
- Saisie live pour ces cinq rôles : but/passe, cartons, victoires, correction/annulation, redémarrage et clôture. Journal obsolète après changement externe toujours protégé.
- Synchronisation : `is_active`, unicité de séance active, conflit de démarrage hors ligne récupérable, anciens snapshots compatibles, outbox préservée.
- Sauvegardes : noms courts et agrégats conservés ; fusion vers groupe existant et base vide ; inventaire des métadonnées vérifié.
- Tests backend complets, Flutter complet ou justification des zones non exécutées, tests unitaires et navigateur du portail, tests du Flutter web commun, build/packaging depuis le checkout isolé.
- Cache : nouvelle version réellement distribuée, anciens caches locaux et distants supprimés au bon scope, hors scope préservé, données SQLite intactes.
- Recette UI distincte : création/reprise, live, permissions et finance ; clair/sombre, 320/393, texte 100/130/200, noms longs. Ne pas confondre absence d'overflow et rendu visuel validé.

Les nombres de tests figurant dans les anciens rapports restent des résultats historiques. Aucun test applicatif ni déploiement n'a été rejoué pour cette simple préparation. Les simulations ci-dessus valident seulement la fusion textuelle. L'exécution de ce plan reste à faire.
