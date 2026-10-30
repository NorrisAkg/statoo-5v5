# Groupes partagés et finances

## Organisation

Le monorepo sépare le client Flutter (`mobile/`), l’API FastAPI (`backend/`) et la consultation web (`web/`). Les données locales existantes restent dans la même base SQLite de l’application : déplacer les sources ne change pas l’identité native ni l’emplacement des données sur le téléphone.

## Rôles

Tous les comptes ont MEMBER. ADMIN est le créateur et gère les comptes et le répertoire. Les titulaires peuvent cumuler des rôles ; chaque rôle de direction a au plus un titulaire par groupe. PDT et TR doivent être attribués avant la première synchronisation métier.

Les simples membres consultent via l'accès collectif : aucun compte individuel n'est à créer pour eux. Toute nouvelle création de compte individuel exige au moins un rôle de responsable (y compris Censeur). Les comptes existants sont conservés ; un ancien responsable ayant transmis son dernier rôle garde son accès de consultation et son historique. Le rôle MEMBER demeure ajouté automatiquement aux comptes des responsables.

| Rôle | Action |
| --- | --- |
| ADMIN | Comptes, attribution et transfert explicite de rôles, accès collectif, répertoire |
| PDT / VP | Arbitrage des conflits, approbation des soldes, transferts exceptionnels |
| SG / SGA | Données sportives |
| TR / TGA | Données financières |
| CENSOR / MEMBER | Consultation |

ADMIN ne donne pas implicitement les droits sportifs ou financiers. Le compte collectif MEMBER ne peut écrire. La rotation de ses identifiants révoque les connexions collectives. Les gestionnaires ont des comptes individuels pour tracer les actions.

## Responsabilités et synchronisation

Chaque échéance possède une référence commune : par défaut date + numéro 1, modifiable pour distinguer plusieurs séances le même jour. Sport et finances ont des responsables indépendants.

Le démarrage hors ligne est autorisé avec une connexion préalablement mise en cache. Deux responsables peuvent produire des versions concurrentes. Les opérations sont persistées et possèdent un identifiant unique : un nouvel envoi de la même opération ne crée pas un second encaissement.

Le serveur conserve la version publiée et les versions concurrentes. PDT ou VP choisit une version avec un motif, sans fusion automatique des montants. Un transfert explicite change la génération ; les anciennes écritures ne remplacent pas la version retenue. Les droits révoqués sont appliqués à la reconnexion, car un appareil déconnecté ne peut pas connaître immédiatement une révocation.

### Refus dans la file Flutter — 25 octobre 2026

Un refus HTTP 400/403/404/409/410/422 conserve l'opération avec son contenu et son
motif, sans empêcher l'envoi des autres documents. Les opérations suivantes du
même document attendent la prochaine passe. Le conflit particulier de démarrage
d'une séance déjà active conserve son traitement de blocage existant.

Un refus définitif n'est pas renvoyé automatiquement : une nouvelle correction
par l'édition habituelle produit une nouvelle opération. Tant qu'elle n'est pas
acquittée, l'avertissement reste disponible dans l'écran du groupe partagé et les
données locales non publiées restent protégées des snapshots distants.

Une erreur de connexion 401, une limitation 429, un timeout ou une panne réseau/
serveur conserve l'opération en attente et interrompt la passe. La reprise garde
son identifiant et son contenu pour respecter l'idempotence. Les métadonnées de
diagnostic restent locales. Scénarios et preuves : [suivi F05](tdd-outbox-rejections-2026-10-25.md).

## Finances

Le point propose Encaissements et Dépenses, recherche des membres, participants d’abord et absents ensuite. La cotisation et le paiement des pénalités sont séparés. Le montant de pénalité dû est saisi avec son motif. Les dons et dépenses sont des mouvements distincts.

La validation demande confirmation. Une correction remplace les montants de la période et exige un motif ; elle conserve l’état précédent dans l’historique.

- Tous les membres actifs doivent une cotisation par échéance, même absents.
- Un versement intégral entre dans la caisse à sa date de réception.
- Le solde de cotisation positif est une avance ; négatif, une dette.
- L’avance ne paie ni retards ni sanctions. Leur dette est suivie séparément.
- Une échéance annulée conserve la cotisation due mais n’accepte aucun mouvement de caisse ni nouvelle pénalité.
- Les dépenses diminuent la caisse ; les dons n’augmentent pas l’avance d’un membre.
- Une échéance financière peut être créée sans séance sportive.
- Les soldes initiaux sont proposés par TR/TGA et approuvés par PDT/VP avant la première publication financière. Ils ne sont pas des encaissements.

## Exploitation et vérifications avant diffusion

Après un import partagé réussi, les fiches joueur déjà ouvertes actualisent leurs
statistiques, leur historique et les possibilités de suppression sans devoir
quitter l'écran. Les requêtes restent limitées au groupe actif et la suppression
conserve sa vérification métier en base. Scénarios et limites :
[suivi F12](tdd-player-sync-refresh-2026-10-26.md).

Le backend est préparé pour Render et Neon mais n’est pas déployé. Choisir et vérifier sauvegardes, restauration, supervision et accès aux secrets. Tester la reconnexion et l’arbitrage sur deux appareils ainsi que la consultation web contre PostgreSQL avant ouverture au groupe.

Les montants sont des entiers en F. Les montants par défaut du groupe sont configurables dans Réglages → Finances du groupe (cotisation initiale : 100, retard : 0). ADMIN, TR et TGA peuvent les modifier dans un groupe partagé. La cotisation est figée par échéance ; les changements du groupe concernent les nouvelles séances. Les montants affichés dans les champs vides sont indicatifs et ne constituent pas des encaissements. Le retard est enregistré explicitement : cette version ne déduit pas une heure d’arrivée automatiquement.

Les sauvegardes locales conservent les données financières mais pas le jeton sécurisé. Une restauration exige une nouvelle connexion. La fusion de sauvegardes financières/partagées est refusée pour éviter une remise en correspondance incorrecte des identifiants : utiliser une restauration complète.

L'export lit les groupes, joueurs, séances, participations et métadonnées dans
une même transaction SQLite. Une écriture concurrente ne peut donc pas être
intercalée entre ces lectures. Le réglage historique provenant des préférences
est lu séparément ; aucune transaction commune entre ces deux stockages n'est
annoncée. Format JSON inchangé. Scénarios et limites :
[suivi F13](tdd-backup-snapshot-2026-10-27.md).

## Plan documentaire

1. Mettre à jour le schéma, les parcours et les conventions historiques avec les nouveaux modules.
2. Documenter les scénarios d’exploitation : renouvellement d’accès, remplacement d’un responsable et arbitrage.
3. Écrire le guide Render/Neon après un déploiement de test effectivement vérifié.
4. Compléter le guide de distribution APK et du portail avec leurs URL réelles.

### Restauration atomique des réglages — 27 octobre 2026

La restauration complète valide dans une même transaction SQLite les données, le
groupe actif et le minimum global de secours. Elle ne modifie plus SharedPreferences.
Les lecteurs privilégient cet état SQL ; les installations jamais restaurées gardent
leur migration historique. Une restauration vide ne réintroduit plus l'ancien groupe.
Le marqueur local de remplacement est exclu de l'export. Scénarios et preuves :
[tdd-restore-atomicity-2026-10-27.md](tdd-restore-atomicity-2026-10-27.md).

### Photos portables — 27 octobre 2026

Les nouvelles photos PNG/JPEG/WebP sont intégrées dans `avatar_url` sur web et mobile.
L'export convertit les anciennes photos locales après lecture du snapshot SQL ; il
refuse explicitement un fichier absent ou illisible. À l'import, les anciens chemins
locaux ne sont jamais lus et leur omission est signalée. Les URL HTTP(S) historiques
restent des références externes. Limites : 2 Mio/image, 4096 pixels/côté, 16 Mpx,
32 Mio d'images cumulées. Format JSON v2 conservé, import v1/v2.
Scénarios et preuves : [tdd-portable-photos-2026-10-27.md](tdd-portable-photos-2026-10-27.md).
