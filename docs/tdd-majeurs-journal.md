# Journal TDD des huit majeurs UI/UX

14 octobre 2026. À lire avec le [catalogue des 148 scénarios](tdd-majeurs-ui-ux.md) et la [matrice de couverture](tdd-majeurs-ui-ux-couverture.csv).

Les correctifs portent sur UX01 à UX08. Les tests de régression incluent des tests déjà présents ; **271 tests réussis ne signifient pas 271 scénarios nouveaux, ni l'exécution des 148 lignes du catalogue**. Une couverture partielle est identifiée comme telle dans la matrice. Les constats historiques de l'audit n'ont pas été réécrits.

## Preuves RED → GREEN

| Majeur | Échec constaté avant correction | Correction et preuve automatisée |
|---|---|---|
| UX07 — restauration des tournois | Les 14 combinaisons de sept résultats × fusion/remplacement attendaient CLOSED et obtenaient DRAFT. Le classement attendait 3 points et obtenait 0. | Normalisation selon CLASSIC_2/TOURNAMENT_3, comparaison du résultat aux victoires selon la règle de clôture existante. Tournois valides conservés ; résultats incomplets/incohérents récupérés en brouillon, sans résultat fabriqué. Test d'export/restauration et lecture de la vue de classement. |
| UX01 — remplacement explicite | Le spy de restauration était déjà appelé avant confirmation : attendu 0, obtenu 1. Deux sélections simultanées étaient possibles : attendu 1, obtenu 2. | Dialogue commun à Nouveau groupe et Réglages : tous les groupes affectés et contenu entrant, annulation sûre, action explicite. Sélecteur protégé contre la répétition. Tests widgets : annuler, confirmer, erreur et sélection annulée. |
| UX01 — périmètre devenu périmé | Trois tests ajout/suppression/renommage attendaient un refus et obtenaient une restauration réussie. | Le service compare identifiants et noms relus aux groupes confirmés **dans la transaction, avant toute suppression**. Refus conserve les tables et métadonnées, dont la file d'attente. |
| UX03 — identités financières | Deuxième référence attendue -2, obtenue -1 ; trois créations concurrentes donnaient une seule référence ; deux anciennes séances non référencées donnaient une seule période en attente. | Registre commun avec réservation transactionnelle du premier numéro libre, par groupe/date. Intégration dans la création SQLite, le rapprochement financier et la mise en file partagée. Alias explicites et historiques conservés. Deux points distincts enregistrent des paiements distincts et leurs dettes sont calculées séparément. |
| UX03 — création manuelle concurrente | Deux demandes de la même référence réussissaient : attendu un seul succès, obtenu deux. | Vérification, référence, alias, point et mise en file réunis dans une transaction ; un seul succès, un point, aucune réservation orpheline. Référence rendue accessible dans le formulaire local ; rattachement existant expliqué avant accord. |
| UX02 — garde de sortie | Après saisie, la route était quittée et aucun dialogue d'abandon n'existait, pour la flèche et `Navigator.maybePop`. | Empreinte des valeurs du point, garde PopScope, Continuer/Abandonner, protection pendant la validation et nouvelle référence de comparaison après succès. Tests : sortie sans changement, continuation avec valeurs conservées, abandon explicite, retour aux valeurs initiales et sauvegarde réussie. |
| UX05 — relecture des soldes | L'ouverture du récapitulatif envoyait déjà un POST sans corps. L'API acceptait une approbation sans précondition et approuvait une proposition remplacée : 200 au lieu de 422/409. | Récapitulatif caisse/date/avances/dettes/pénalités, auteur/date si disponibles dans le journal, confirmation explicite. Copie profonde de la proposition relue ; comparaison serveur avec la proposition actuelle dans la transaction existante. Tests API : contenu exact, trois modifications périmées, président/vice, autres rôles refusés et approbation unique. |
| UX04 — comparaison des versions | Les dépenses, dons, motifs et auteurs étaient absents ; un motif vide fermait le dialogue. Un tournoi au format réellement synchronisé perdait les noms de ses équipes dans la comparaison. | Détail par version des données financières/sportives, auteur, date, motif, différences textuelles, ajouts/suppressions et identifiants de membres. Noms d'équipes acceptés sous forme Map ou JSON SQLite. Motif vide garde le dialogue ouvert avec erreur. Tests widgets sur dépenses différentes à versements identiques, dons, pénalités, auteurs et victoires de tournoi. |
| UX06 — droits cohérents | MEMBER/CENSOR/SG/TR voyaient le bouton joueurs ; une identité expirée conservait `canWrite=true` ; un groupe local autonome était refusé avec une identité distante. | Capacité commune observée par les écrans ; groupe partagé protégé, expiration et compte collectif contrôlés ; groupe local existant utilisable indépendamment. Matrice des neuf rôles testée avec SharedService réel et SQLite. Propriété de séance relue avant affichage des mutations. |
| UX06 — refus tardifs | Ajout joueur et incrément de score lançaient une StateError non traitée après retrait du rôle. | Erreurs explicites dans les formulaires et les mutations sportives. Saisie joueur conservée ; formulaire de statistiques ne se ferme qu'en cas de succès. Route directe de création sportive bloquée pour consultation. Statut « En cours » préservé pour le lecteur, séparément de la possibilité d'éditer. |
| UX06 — accès indirects | SG seul disposait encore de « Nouveau joueur » dans la composition et de « Créer » dans la sélection des retardataires ; deux assertions `findsNothing` échouaient. | Les deux parcours observent la capacité `members` ; sélection des joueurs existants conservée, création réservée à ADMIN dans un groupe partagé. |
| UX08 — contrastes | Le bouton clair échouait au seuil 4,5 ; le petit texte vert aussi ; retour sur barre transparente : 1,17 au lieu de 3. | `onPrimary` blanc en clair, sombre préservé ; vert de petit texte assombri ; sous-titres Joueurs/Séances sur `onHeader` ; icônes des barres transparentes sur le premier plan de page. Mesures sur styles effectifs du bouton, retour réel et sous-titre Joueurs, plus paires de fonds clair/sombre. |

Les traces RED ci-dessus décrivent des échecs d'assertion métier observés. Des corrections de fixture ont aussi été nécessaires : attente de spinner indéterminé, frame après saisie, champ hors zone visible, nom du bouton et types de provider. **Ces erreurs de test ne sont pas comptées comme preuves RED.**

## Tests exécutés

Depuis `mobile` :

```powershell
flutter test --reporter expanded
```

Résultat final : **271 tests réussis, 0 échec**. Trace locale : `docs/tdd-flutter-validation.log`.

Depuis `backend`, suite complète découverte (deux fichiers) :

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Résultat : **24 tests réussis**. Un avertissement de dépréciation Starlette/httpx, sans échec. Trace locale : `docs/tdd-backend-validation.log`.

L'analyse Dart ciblée s'est terminée sans erreur ni avertissement, avec des informations de style ; ce n'est pas une déclaration d'analyse globale sans diagnostic. `git diff --check` exécuté sans erreur de contenu ; Git signale les conversions LF/CRLF configurées sur Windows.

Les tests anciens de coordination avec de faux repositories appelaient implicitement le singleton SQLite de production pour les permissions. Ils injectent désormais `LocalTestSharedService` explicitement. Cette doublure n'est utilisée dans aucun test de sécurité : la matrice des droits, les marqueurs restaurés et la propriété utilisent SharedService réel sur SQLite en mémoire. Aucun contrôle applicatif n'a été supprimé pour faire passer ces tests.

## Livraison et compatibilité

- L'API `POST /groups/{id}/opening/approve` exige désormais `{"proposal": ...}`. Une requête ancienne sans proposition est refusée en 422 ; une proposition différente de l'actuelle est refusée en 409. **Déployer le serveur et le mobile de façon coordonnée** ; les anciens mobiles ne pourront plus approuver après mise à jour du serveur. Aucun serveur n'a été déployé pendant ce travail.
- La correction UX03 évite les nouveaux rapprochements involontaires. Les alias historiques déjà communs sont conservés : les données ne permettent pas de déterminer automatiquement si un rapprochement ancien était voulu. Aucune répartition rétroactive de paiements n'est inventée.
- UX02 protège les sorties par navigation. **Pas de brouillon persistant après arrêt forcé du processus** dans cet incrément. C'est la limite annoncée dans le catalogue, pas un scénario déclaré réussi.
- Les changements préexistants en finance et groupe partagé ont été conservés. Aucun commit, aucune migration destructive et aucune écriture sur les groupes réels du téléphone.

## Vérifications restantes, non présentées comme acquises

La matrice distingue les cas automatisés, partiels et non exécutés. Notamment : TalkBack, gestes Android et retour prédictif, clavier réel, texte 200 % sur chaque écran, lumière extérieure, reprise après interruption OS, fonctionnement réseau lent réel et comparaison visuelle sur l'APK. Les vérifications à plusieurs acteurs/concurrence sont simulées ou réalisées en API isolée ; ce ne sont pas des essais sur un groupe de production.

Tous les cas combinatoires du catalogue n'ont pas reçu un test exécuté dans ce lot : notamment conservation après chaque type de modification du point, listes très longues, interruptions à chaque `await`, toutes les variantes de restauration historique et permutations multi-appareils. Les passer au vert demande les tests correspondants ; ne pas inférer leur réussite des 271 tests existants.

## Essais physiques des 14–15 octobre 2026

La campagne sur l’APK debug isolé **Statoo QA** est décrite dans [le rapport appareil](essais-appareil-2026-10-14/rapport.md), avec captures et limites. Aucun changement applicatif supplémentaire n’a été effectué pendant ces essais. Les résultats automatiques ci-dessus restent ceux de la livraison ; la matrice de 148 scénarios dispose de colonnes séparées `AppareilStatut`, `PreuveAppareil`, `LimiteAppareil`.

Observations acquises : récapitulatif d’import à vide, conservation des tournois clôturés et contribution au classement, protection/continuation/abandon d’une cotisation au clavier Android, relecture du départ financier, détail des deux dépenses concurrentes et résolution motivée, distinction PDT/SG et accès indirect des retardataires, rendu clair/sombre. Les combinaisons non exécutées ne sont pas réputées validées. La mise en scène du départ périmé a échoué avant la modification concurrente ; le 409 reste une preuve API automatisée, pas une preuve appareil.

Réserves à traiter en TDD : résumé de tournoi A–B 0–0 sur l’accueil, longueur de comparaison des versions financières, visibilité immédiate du message de motif obligatoire et débordement de 237 pixels de la ligne Composition à 200 % sur téléphone. Deux créations UI du même jour ont produit les références -1/-2 et des alias distincts ; les deux paiements restent à vérifier. Un incident de manipulation de la fixture locale a invalidé son état après une copie de base : ne pas utiliser les états postérieurs pour certifier la persistance de l’import initial. L’application habituelle et ses groupes réels n’ont pas été modifiés.
