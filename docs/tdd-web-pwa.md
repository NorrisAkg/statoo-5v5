# Web PWA — scénarios avant implémentation

## État initial observé le 15 octobre 2026

Le dossier `web/` contient un portail HTML/CSS/JavaScript en consultation uniquement. Il n'a ni manifeste, ni service worker, ni icônes d'installation. Le backend le sert sous `/portal/`. Le build copie actuellement quatre fichiers et n'exécute qu'un test de classement.

Écarts avec le mobile : absence du nom de l'équipe C dans les résumés de tournoi, des couleurs et des buteurs ; navigation et présentation différentes. L'authentification utilise un jeton en `sessionStorage`. Les droits sont contrôlés par l'API.

## Socle commun aux deux périmètres possibles

| ID | Scénario | Résultat attendu |
| --- | --- | --- |
| PWA-01 | Installation depuis `/portal/` | Manifeste français avec nom, identifiant, démarrage et scope relatifs, affichage standalone et icônes PNG 192 et au moins 512 valides. Les icônes natives existantes 192/1024 sont réutilisées sans transformation. |
| PWA-02 | Ouverture directe depuis un hébergement statique à la racine | Les chemins relatifs du manifeste, du worker et des ressources restent valides. |
| PWA-03 | Première visite en ligne | Enregistrement du worker ; interface utilisable même si son enregistrement échoue ou n'est pas pris en charge. |
| PWA-04 | Retour hors ligne après une visite réussie | Interface de base disponible ; indication claire de l'absence de réseau, aucune donnée inventée. La consultation des données hors ligne reste un périmètre à décider. |
| PWA-05 | Requête API authentifiée, connexion ou déconnexion | Aucun jeton, mot de passe ou réponse API mis dans le cache de ressources du worker. |
| PWA-06 | Actualisation du worker | Nouveau cache complet installé avant activation ; nettoyage limité aux anciens caches Statoo de ce scope. |
| PWA-07 | Build du portail | Tous les fichiers nécessaires à la PWA sont livrés ; tous les tests web sont exécutés. |
| PWA-08 | Session expirée, déconnexion ou changement de compte | Anciennes données masquées/effacées ; aucune fuite d'affichage entre comptes. |
| PWA-09 | Mobile 320/360/390 px, tablette et bureau | Navigation accessible au toucher, noms longs lisibles, aucun débordement horizontal de page ; tableaux confinés à leur propre défilement. |
| PWA-10 | Visite sans prise en charge de l'installation | Consultation normale dans le navigateur ; aucun bouton d'installation inopérant. |

## Périmètre accepté : gestion complète selon les rôles

Réutiliser l'API et ses règles ; ne pas introduire un second backend. Interface mobile d'abord avec accueil, séances, membres, classement, finances et gestion. Les simples membres utilisent l'accès collectif ; les responsables leurs comptes individuels. La PWA permet de créer un groupe et les accès, composer/suivre/clôturer/annuler une séance, gérer les membres, comptes/rôles, finances, soldes initiaux, conflits et transferts.

Les saisies restent dans des brouillons locaux séparés par serveur/groupe/compte. Un envoi sportif/financier est persisté avec son identifiant avant le réseau pour autoriser une reprise idempotente. Aucun arbitrage ou transfert n'est effectué automatiquement. Les opérations administratives nécessitent le réseau. Les données de consultation sont conservées pour une connexion valide, avec date de dernière actualisation ; une déconnexion ou un 401 efface les données de ce compte. La disponibilité hors ligne n'annule pas les vérifications du serveur à la reconnexion.

| ID | Scénario | Résultat attendu |
| --- | --- | --- |
| WEB-01 | Connexion collective, individuelle, incorrecte, expirée | Accueil et rôle explicite si valide ; erreur sinon ; aucune donnée ancienne visible après 401. |
| WEB-02 | Créer un groupe | Noms du groupe/membres, Admin et accès collectif créés ; guide PDT/TR/SG et soldes avant utilisation. |
| WEB-03 | MEMBER/CENSOR/compte collectif, même avec rôles supplémentaires | Consultation seule, aucun formulaire d'écriture ; API toujours autoritaire. |
| WEB-04 | ADMIN, SG/SGA, TR/TGA, PDT/VP, rôles cumulés | Actions exactement selon les capacités ; Admin sans sport/finance implicites. |
| WEB-05 | Accueil avec séance en cours, dernière terminée, aucune séance | Priorité au brouillon actif représenté par une séance publiée DRAFT, sinon dernière CLOSED ; états vides ; navigation vers détail. |
| WEB-06 | Détail de match/tournoi | Deux ou trois équipes, couleurs/noms, scores ou victoires et buteurs triés par buts puis nom, seulement ceux de la séance ; buts non attribués et état vide. |
| WEB-07 | Création sportive | Deux/trois noms aléatoires distincts du catalogue mobile, couleurs distinctes, présence et affectation explicites, tirage équilibré ; aucune création de membre réservée au SG. |
| WEB-08 | Brouillon sportif et mise à jour | Toutes les statistiques et compositions conservées, pas de mutation du snapshot avant acceptation. |
| WEB-09 | Clôture classique/tournoi | Résultat calculé, égalités partielles/totales et points de nul ; absence de victoire en tournoi refusée ; effectifs/buts/passes validés. |
| WEB-10 | Doublons, inconnus, équipe C en classique, nombres négatifs/fractionnaires, couleurs identiques, date/référence invalide | Refus avant envoi, données de saisie conservées. |
| WEB-11 | Autre responsable, conflit en cours | Modification directe indisponible ; transfert/arbitrage explicite requis. |
| WEB-12 | Correction sportive/financière | Motif obligatoire ; validation après récapitulatif et confirmation. |
| WEB-13 | Références d'échéance | Date-numéro libre proposé ; référence existante explicite pour rattachement ; même référence sportive/financière sans double cotisation. |
| WEB-14 | Annulation sportive | Confirmation ; envoi CANCELLED ; refus serveur si mouvements financiers préexistants ; données conservées en cas de refus. |
| WEB-15 | Répertoire Admin | Ajout, modification, archivage et réactivation ; identifiants et anciens membres préservés. |
| WEB-16 | Création de responsable | Membre existant, identifiants distincts, mot de passe >=8 et rôle responsable obligatoire ; erreur serveur lisible si rôle déjà attribué. |
| WEB-17 | Attribution/transfert de rôles | Liste actuelle relue, transfert explicite avec motif ; réattribution obligatoire Admin/PDT/TR contrôlée par serveur. |
| WEB-18 | Rotation accès collectif | Confirmation, PUT, révocation par le serveur ; pas de mot de passe journalisé ni conservé. |
| WEB-19 | Paramètres financiers | ADMIN/TR/TGA seulement, entiers positifs ou nuls ; aucune modification des taux historiques. |
| WEB-20 | Proposition de soldes TR/TGA | Caisse, date, avances/dettes signées et pénalités distinctes ; récapitulatif avant envoi. |
| WEB-21 | Approbation PDT/VP | Proposition complète affichée ; corps identique à celle relue ; proposition périmée refusée en 409. |
| WEB-22 | Nouveau point TR/TGA avec/sans séance sportive | Tous les membres de l'échéance inclus, absents aussi ; taux figé ; encaissements cotisation/pénalités, sanctions avec motif, dons et dépenses distincts. |
| WEB-23 | Correction de point | Réutiliser les membres historiques, mouvements et identifiants ; ne pas additionner une seconde fois les valeurs corrigées. |
| WEB-24 | Montants invalides, pénalités sans motif, surpaiement de pénalité, échéance annulée | Validation locale et refus serveur ; aucune perte du formulaire. |
| WEB-25 | Arbitrages PDT/VP | Comparaison lisible de toutes les valeurs de chaque version, choix explicite et motif, révision exacte ; aucun montant fusionné. |
| WEB-26 | Transfert de responsabilité | Auteur autorisé ou PDT/VP, cible habilitée au domaine, révision et motif ; blocage si conflit. |
| WEB-27 | Actualiser avec formulaire modifié / fermer / navigation | Confirmation de perte ou sauvegarde du brouillon ; conservation après rechargement pour le même compte. |
| WEB-28 | Réseau absent ou timeout après envoi | Opération conservée ; même operation_id et même corps au nouvel essai ; double clic bloqué. |
| WEB-29 | Réponse conflict | Message distinct d'une publication réussie, snapshot actualisé sans réenvoyer automatiquement la version concurrente. |
| WEB-30 | Révocation 403/expiration 401 | 403 visible et droits relus ; 401 nettoie session et cache privé ; aucune tentative infinie. |
| WEB-31 | Changement de compte/serveur/groupe | Brouillons et opérations isolés, jamais rejoués sous une autre identité. |
| WEB-32 | Stockage indisponible/corrompu | Message clair ; aucun envoi métier sans persistance de son identifiant ; interface publique reste utilisable. |
| WEB-33 | Classement | Séances fermées classées pour les points, amicaux pour buts/passes comme le portail existant ; égalités de tournoi, noms et tri français déterministes. |
| WEB-34 | Données contenant du HTML | Affichage en texte ; aucune exécution de contenu saisi dans noms, motifs ou historique. |
| WEB-35 | Rendu 320/360/390/768/1440 px, thèmes clair/sombre, texte agrandi et clavier | Formulaires, actions et dialogues lisibles ; pas de débordement de page ; focus et libellés accessibles. |
| WEB-36 | Refus définitif 403/409/422 d'un envoi | Le brouillon reste modifiable ; seule cette opération refusée sort de la file, pour permettre une correction. Un timeout conserve au contraire l'opération exacte. |
| WEB-37 | Connexion stockée sans expiration valide | État rejeté, données privées non affichées ; reconnexion nécessaire. |
| WEB-38 | Ancienne séance sans noms/couleurs personnalisés | Noms Équipe A/B/C et couleurs par défaut ; modification possible sans changer ses identifiants. |
| WEB-39 | Réponse réseau ancienne reçue après changement de compte | Ne remplace ni snapshot, ni droits, ni brouillons du nouveau compte ; un ancien 401 ne le déconnecte pas. |
| WEB-40 | Récapitulatif administratif avant confirmation | Noms des membres et responsables, rôles traduits et statuts lisibles ; aucun identifiant technique ni mot de passe affiché en clair. |
| WEB-41 | Publication PWA récupérée sur le mobile | Noms/couleurs encodés comme les colonnes texte JSON SQLite et booléens sportifs en 0/1 ; séance, participants et statistiques importables par SharedService. |

Ces scénarios constituent le périmètre de validation. Les preuves automatisées et contrôles visuels seront consignés distinctement ; un scénario non exécuté ne sera pas présenté comme validé.

Les contrôles de manifeste/cache/build peuvent être automatisés. L'installation réelle, les interactions tactiles et le rendu visuel nécessitent également une vérification dans un navigateur ; ne pas les déduire de tests de fichiers.

## Résultats observés — 15 octobre 2026

- Les scénarios PWA-01 à PWA-10 et WEB-01 à WEB-35 ont été écrits avant l'implémentation fonctionnelle. Les cas WEB-36 à WEB-40 ont été ajoutés au fur et à mesure des cas découverts, avant leur correction.
- RED initial : 15 échecs sur 16 tests Node avec stubs explicites, manifeste et worker absents. Le test navigateur Admin constatait également l'absence de l'action de gestion. Un test de validation négative passait déjà avec le stub et n'a pas été utilisé comme preuve fonctionnelle.
- RED complémentaires observés : file refusée non libérée, expiration absente acceptée, réponse tardive remplaçant le nouveau compte, rôle révoqué non relu, ancienne séance sans couleurs impossible à modifier, file corrompue laissant partir une nouvelle opération.
- GREEN : 27 tests Node, 27 tests Chrome automatisés et 38 tests backend passent. `npm run build` compile l'API, exécute les tests et livre les ressources PWA dans `web/dist/`. `npm run build:web` permet de reconstruire seulement la PWA en réexécutant tous ses tests Node.
- Le parcours Chrome intégré utilise l'API réelle avec SQLite en mémoire : création du groupe, attribution Admin/PDT/TR/SG, proposition et approbation des soldes, tournoi clôturé, point financier lié puis connexion collective de consultation. Le serveur de test est isolé et n'utilise pas les groupes de production.
- Les autres tests navigateur contrôlent la matrice des rôles, les comptes, les membres, l'accès collectif, les paramètres, l'annulation, les décisions et transferts, le brouillon après rechargement, le contenu HTML affiché comme texte, les largeurs 320/360/390/768/1440 et le rechargement hors ligne avec snapshot privé.
- Rendu inspecté sur captures locales clair/sombre : tournoi à trois blocs verticaux, buteurs, navigation mobile et formulaire étroit. Les captures restent sous `mobile/build/pwa-qa/`, hors Git.
- WEB-41 : échec d'import SQLite reproduit avant correction (booléens et objets non acceptés par les colonnes). Après sérialisation à la frontière réseau de la PWA, le test Flutter `pwa_wire_import_test.dart` importe le fixture produit par le code web, retrouve les trois équipes, leurs couleurs, la clôture et les statistiques. La logique applicative mobile n'a pas été modifiée.

### Limites explicites

L'installation depuis l'écran d'accueil d'un Android/iPhone physique et Safari/iOS n'a pas été exécutée. La campagne Chrome ne remplace pas un contrôle TalkBack/VoiceOver, clavier physique, zoom système et interaction tactile sur téléphone. Le remplacement de cache est testé en simulation ; l'invite de mise à jour entre deux versions hébergées reste à contrôler en déploiement de test.

Les vérifications de refus métier avancés et de concurrence reposent aussi sur la suite API existante : tous les cas ne sont pas rejoués via l'interface. L'API ne transfère pas les réglages natifs, fichiers de sauvegarde SQLite et statistiques avancées MVP ; ils ne sont pas présentés comme une parité web acquise.

Aucun déploiement ni commit réalisé pour cette PWA.
