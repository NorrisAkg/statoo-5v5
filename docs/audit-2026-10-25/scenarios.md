# Périmètre et scénarios de l’audit du 25 octobre 2026

Référence initiale : staging, 1daa008. Audit sans correction applicative.
Scénarios complémentaires définis avant l’écriture des sondes de cet audit.

| ID | Scénario | Attendu |
|---|---|---|
| AUD-01 | Suites existantes backend, Flutter, web et analyse | Résultats actuels, erreurs d’environnement distinguées des défauts. |
| AUD-02 | Premier lancement, création locale, navigation, création de joueurs et séance | Actions compréhensibles, transitions explicites, saisies préservées. |
| AUD-03 | 320/393/desktop, clair/sombre, grand texte, clavier | Contenu et actions atteignables, aucune coupure, focus et noms accessibles. |
| AUD-04 | Sport classique/tournoi : données mal formées, date, résultat, équipes, identités | Rejet 4xx sans publier de document invalide ni provoquer de 500. |
| AUD-05 | Authentification, rôles, groupe tiers, expiration/révocation | Aucun accès hors périmètre ; refus sans mutation. |
| AUD-06 | Création avec identifiants différant par espaces, puis connexion aux deux comptes | Identifiants réellement distincts après normalisation. |
| AUD-07 | Validation contenant un mot de passe invalide | Aucun secret soumis recopié dans la réponse d’erreur. |
| AUD-08 | Chemins statiques du portail : sources/tests, traversée | Aucun fichier serveur hors racine ; exposition des fichiers internes identifiée. |
| AUD-09 | Sauvegarde/restauration, version future, fusion/remplacement et métadonnées sensibles | Refus avant mutation, conservation des données et secrets exclus. |
| AUD-10 | Migration SQLite de versions historiques avec participations | Conservation des séances/participations, intégrité référentielle. |
| AUD-11 | Déconnexion hors ligne, refus de sync, rôle actualisé | Nettoyage local possible et erreur récupérable ; droits cohérents. |
| AUD-12 | Cache/offline, installation et mise à jour | Pas de perte de saisie, même version cohérente, reprise locale. |
| AUD-13 | Montants, dettes, annulation, soldes et concurrence | Valeurs strictes, autorisations, idempotence et calculs préservés. |
| AUD-14 | Livraison, sécurité de configuration, CI, observabilité et confidentialité | État factuel et limites explicites, aucun secret dans le rapport. |
| AUD-15 | Admin modifie/ archive un membre, puis reçoit le snapshot avant publication manuelle | Modification locale non perdue silencieusement ; préparation identifiable. |
| AUD-16 | Premier événement de la file refusé durablement (403), puis autre événement valide | Refus visible et conservation ; les opérations indépendantes restent traitables. |
| AUD-17 | Données fictives 50 joueurs / 500 séances | Mesurer les requêtes SQL locales, sans assimiler ce résultat à la fluidité sur téléphone. |
| AUD-18 | Recharger directement /stats d’un groupe local contenant une séance close | Groupe actif initialisé sans passage par l’accueil ; totaux inchangés, aucun faux état vide. |

Les sondes API utilisent uniquement une base SQLite en mémoire et des comptes fictifs. Les contrôles manuels sur téléphone, lecteurs d’écran et charge de production seront distingués des exécutions locales.
