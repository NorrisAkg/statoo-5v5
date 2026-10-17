# Entrée groupe et attribution des rôles — scénarios avant code

## Périmètre accepté
Choix Créer/Rejoindre au démarrage sans groupe. Créer conserve la présentation du produit, la création locale et l’effectif, puis propose accès Admin et désignation des responsables. Rejoindre ouvre directement la connexion. Groupes existants continuent vers l’accueil. Aucune auto-attribution des rôles depuis un compte membre.

| ID | Scénario | Résultat attendu |
|---|---|---|
| ENT01 | Installation vierge ou introduction déjà vue, aucun groupe | Après splash, deux choix explicites Créer un groupe / Rejoindre un groupe. |
| ENT02 | Créer, introduction vue ou pas | Introduction si nécessaire, puis groupe, effectif, accès Admin ; intention conservée dans URL et rechargement. |
| ENT03 | Rejoindre sans groupe ni introduction vue | Formulaire de connexion direct, pas de création locale préalable. Retour possible au choix. |
| ENT04 | Accès Admin | Titre explicite, autres responsabilités annoncées comme étape suivante ; aucune adresse serveur exposée. |
| ENT05 | Succès de création partagée | Désigner les responsables : comptes individuels liés à un membre, rôles existants, possibilité de modifier un compte et de terminer ou passer. |
| ENT06 | Succès de connexion membre ou responsable | Accueil, droits attribués par serveur ; aucune possibilité de choisir soi-même ses rôles. |
| ENT07 | Erreur réseau / identifiants / double appui | Rester dans formulaire, afficher erreur, conserver préparation et champs ; bouton bloqué pendant requête ; aucune étape de succès. |
| ENT08 | Offline à la création | Préparation locale conservée ; Continuer sur cet appareil possible, partage retrouvable ensuite. Aucun compte distant inventé. |
| ENT09 | Groupe existant, gestion hors installation | Démarrage accueil, parcours groupe local/backup et gestion partagée existants conservés ; Admin seul attribue rôles. |
| ENT10 | Cadrage | Clair/sombre 320/393, texte100/130/200, largeur web838, clavier, noms longs, zones sûres ; boutons et contenu défilants. Tests overflow distincts des captures et contrôle physique. |

Références examinées : docs/design-system.md, thème/AppCard/PrimaryButton, onboarding, création de groupe et groupe partagé. Scénarios nouveaux découverts en cours à écrire avant leur correction. Revue dédiée avant commit selon conventions ; audits locaux exclus.
ENT05 variante avant correction : ouvrir Ajouter un gestionnaire immédiatement après création doit charger l’effectif et proposer Alice, même si aucun écran Accueil n’a encore chargé la liste. Une panne de chargement doit être affichée et permettre de réessayer ; empêcher le double dialogue.
ENT11 avant correction (revue) : partager un effectif local non vide doit copier les joueurs avec identifiants distants distincts, sans déplacer ni écraser les joueurs, séances et finances du groupe local. La copie est stable sur une nouvelle tentative et les IDs respectent les limites du transport. Test navigateur avec API et SQLite réels ; la collision intergroupe doit rester refusée pour des imports étrangers.
ENT10 précision avant correction : chaque champ de connexion doit porter son libellé dans l’arbre d’accessibilité ; le mot de passe commun doit se distinguer du mot de passe Admin pour lecteur d’écran et navigation clavier.
ENT07/11 précision revue, avant correction : conserver un operation_id de création en base locale avant la requête, le réutiliser pour le même groupe, différent pour un autre groupe ; après création dont la réponse est perdue, une nouvelle tentative doit rejouer le même groupe serveur et non créer un doublon.

## Résultats et recette

- RED comportementaux : choix d’entrée absents, intention d’URL perdue, effectif indisponible sans ouverture préalable de l’accueil, libellé accessible manquant, copie des identifiants et opération persistée manquantes, retour après rechargement absent, débordement du bouton d’effectif à 320/200 %. Les échecs de compilation et de fixture rencontrés ont été corrigés et ne sont pas comptés comme RED.
- Régression complète : **502 tests Flutter réussis** (`group-entry-regression.txt`). Inclut les 12 combinaisons entrée320/393, texte100/130/200 %, clair/sombre, et le bouton d’effectif à 320/200 %.
- Chrome + API locale réelle + SQLite navigateur : **création avec six joueurs, interruption volontaire du snapshot après création, erreur maintenue sur formulaire, nouvelle tentative vers le même identifiant de groupe, attribution Président à Alice, connexion collective sur un nouveau navigateur, accueil du bon groupe et absence d’attribution de rôles** : réussi (`group-entry-browser.txt`).
- Régressions navigateur : groupe partagé et reprise séance active réussis (`group-entry-browser-shared.txt`) ; groupe local, démarrage explicite, backup, restauration et rechargement hors connexion réussis (`group-entry-browser-local.txt`). Les anciennes fixtures de saisie Flutter utilisent désormais une frappe suivie de Tab. Les délais initiaux du test offline provenaient de l’aperçu Flutter non empaqueté sans service worker ; l’empaquetage universel a été appliqué avant le résultat vert.
- Builds web release QA et aperçu vers API par défaut réussis. Aucun appel de test de création n’a été envoyé au backend public. Analyse sans erreur ni avertissement, dix informations de style conservées dans le journal.
- Visuellement examinés : entrée838clair, formulaire Admin, dialogue de rôles, liste des membres et accueil collectif393clair. Captures locales hors commit. Sombre et grand texte vérifiés par widgets pour le cadrage, pas par une recette visuelle complète. Clavier testé dans Chrome ; appareil physique, clavier virtuel et lecteur d’écran restent non couverts.
- Revue dédiée : collision intergroupe et reprise de création corrigées, revue validée après résultat navigateur vert. Le groupe local est conservé ; seule une copie de l’effectif est partagée, pas une migration de l’historique local.
- Les modifications PWA concurrentes et les anciens audits du dossier ne font pas partie du commit. Aperçu utilisateur mis à jour sur19095, données du navigateur conservées.
