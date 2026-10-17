# Retour de l'installation et des mises à jour PWA — 17 octobre 2026

## Périmètre isolé

Enveloppe navigateur `mobile/web/`, générateur de cache `scripts/package-universal-web.mjs`, tests dédiés. Aucun changement Dart, base de données, parcours métier, branche Git ou déploiement. Conserver les modifications de l'autre chat. Références relues : design-system, thème Flutter, PrimaryButton, Réglages et onboarding ; commandes de l'ancien `web/pwa.mjs`.

## Scénarios avant implémentation

| ID | Cas | Résultat attendu |
|---|---|---|
| PWAS-01 | Manifeste et ressources | Nom Statoo, standalone, portée/démarrage relatifs ; logo existant en 192 et 1024 px (taille supérieure à 512), favicon et icône Apple accessibles dans le build Flutter. |
| PWAS-02 | Installation proposée par le navigateur | Commande Installer Statoo, déclenchement seulement au clic ; appui répété protégé, acceptation/refus gérés, aucune installation déclenchée au chargement. |
| PWAS-03 | Safari/iOS ou invite absente | Instructions adaptées pour ajout à l'écran d'accueil/menu navigateur, fermeture possible ; aucune promesse d'invite native disponible. |
| PWAS-04 | Application déjà installée | Masquer commande d'installation dans le mode autonome et après appinstalled ; mise à jour toujours accessible. |
| PWAS-05 | Worker déjà en attente ou détecté ensuite | Notification et une seule commande Mettre à jour Statoo, même après événements répétés ; viser le worker actuellement en attente. |
| PWAS-06 | Confirmation de mise à jour | Prévenir des saisies non validées ; Plus tard/Escape ne change rien ; confirmation envoie SKIP_WAITING, recharge une seule fois après prise de contrôle, jamais avant. |
| PWAS-07 | Première installation / mise à jour activée depuis un autre onglet | Pas de rechargement automatique de l'écran courant ; proposer de recharger après confirmation si autre onglet a activé la version. |
| PWAS-08 | Vérifier les mises à jour | Vérification au chargement et au retour en ligne/premier plan (temporisée), bouton manuel ; absence de version signalée ; échec récupérable sans bloquer Flutter. |
| PWAS-09 | Hors ligne / enregistrement worker refusé / API absente | Application utilisable, statut explicite, réessai possible ; aucune suppression de cache métier, localStorage ou IndexedDB. |
| PWAS-10 | Deux déploiements successifs, fichiers HTTP déjà en cache | Version 1 reste active jusqu'à confirmation ; version 2 et ses ressources effectivement chargées ensuite (précache forcé à revalider) ; persistance localStorage + IndexedDB vérifiée. |
| PWAS-11 | Hors ligne après installation | L'enveloppe reste disponible ; réponses privées/API hors du cache ; ancien portail inchangé. |
| PWAS-12 | Rendu/navigation | Menu compact ancré en haut dans la zone sûre, clavier/focus et dialogues défilants ; clair/sombre, 320/393 px, texte 100/130/200 ; cibles 48 px ; ne pas ajouter de pied fixe sur les validations Flutter. |
| PWAS-13 | Initialisation répétée | Un seul menu et un seul ensemble de listeners ; pas de doublons de notification. |
| PWAS-14 | Préparations historiques | Lien existant vers portal/ préservé sans afficher de secret ni migrer/supprimer les données. |
| PWAS-15 | Échec du précache d'une nouvelle version | Ancienne version préservée, erreur de téléchargement visible, possibilité de vérifier à nouveau ; aucune activation partielle. |
| PWAS-16 | Moteur de rendu Flutter hors ligne | Bootstrap pointe explicitement sur les fichiers CanvasKit embarqués sous le base href, sans dépendre du CDN Google. |
| PWAS-17 | Menu fermé sur mobile | Commande compacte centrée dans l'en-tête ; ne pas intercepter les commandes latérales (Retour/Passer) à 320/393 px et texte 100/130/200. |

## Limites de livraison

Les tests utilisent une origine locale et une fausse application pour isoler le shell, puis deux vrais cycles de service worker. Installation native Android/iOS, clic sur l'invite système, tous les écrans Flutter et site Vercel à vérifier séparément. Un test simulant beforeinstallprompt ne prouve pas l'éligibilité réelle d'un appareil. Le contrôle CDP Chrome utilise un profil temporaire normal pour ne pas confondre l'interdiction d'installation en navigation privée avec un défaut du manifeste.

## Résultats

- RED initial : commandes absentes (0 menu au lieu de 1), portée du manifeste absente. Tests ultérieurs avant correction : téléchargement défaillant sans statut, moteur graphique sans adresse locale et menu interceptant la commande latérale.
- GREEN ciblé : 8 tests (5 navigateur, 2 manifeste/bootstrap, 1 packaging) ; test réel version 1 → version 2, conservation localStorage/IndexedDB et rechargement hors ligne. Chrome ne signale aucune erreur d'éligibilité à l'installation sur l'origine de test avec les icônes existantes 192/1024. Événements d'invite native et mode iOS simulés.
- Régression : **66/66 tests réussis**, commande `node --test web/tests/*.test.mjs web/tests/universal-pwa.e2e.mjs`. Aucun build partagé ni déploiement effectué ; fichiers Dart et tests Flutter de l'autre chat laissés intacts.
- Rendu vu : menu clair/sombre à 393 px ; matrice automatisée 320/393 × texte 100/130/200 × clair/sombre (12 variantes), boutons de 48 px et dialogues sans débordement horizontal. Captures locales temporaires `statoo-pwa-light.png` / `statoo-pwa-dark.png`.
- Contrôle complémentaire avec le build Flutter déjà présent, sans le modifier : serveur temporaire utilisant les sources PWA et le bootstrap recomposé en mémoire avec les morceaux déjà compilés. Onboarding affiché à 393 px, aucune erreur JS après passage du moteur graphique sur les assets locaux. Ce contrôle ne remplace pas un build release neuf ni une recette de tous les écrans.
- Pour une installation qui conserve encore l'ancienne enveloppe sans ces commandes : après le prochain déploiement, fermer une fois tous les onglets et fenêtres Statoo (y compris la PWA), puis rouvrir. Ne pas effacer les données du site. Les mises à jour suivantes disposent de la confirmation dans le menu Application.
