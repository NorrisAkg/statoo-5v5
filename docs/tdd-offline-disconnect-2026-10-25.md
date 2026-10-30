# F04 — Déconnexion locale indépendante du réseau

## Scénarios définis avant implémentation

La déconnexion est locale : effacer identité, jeton, instantané en mémoire,
URL de connexion et avertissement, arrêter le timer, puis supprimer la connexion
persistée et les accès collectif/gestionnaires du contexte courant. Préserver
les groupes, leur protection en écriture, leurs données et opérations non envoyées,
ainsi que les secrets des autres contextes. La révocation serveur est tentée
avec l'ancien jeton mais ne conditionne pas la fin de la déconnexion locale.
Une erreur réelle du stockage sécurisé doit rester visible : ne pas annoncer
une suppression réussie si le stockage la refuse.

- OUT01 : réponse logout normale → tous les éléments locaux ci-dessus effacés,
  une seule tentative de révocation avec l'ancien contexte.
- OUT02 : réseau inaccessible → même résultat local, aucune exception réseau
  remontée par disconnect ; un nouveau service ne restaure aucune identité.
- OUT03 : session refusée en 401/403, serveur en 500 ou réponse illisible → même
  résultat local ; l'échec de révocation ne devient pas un échec de déconnexion.
- OUT04 : logout distant suspendu → la déconnexion locale se termine sans attendre
  la réponse ; une réponse tardive ne rétablit pas la connexion.
- OUT05 : préserver les secrets d'un autre serveur/groupe/compte et les données
  SQLite, marqueurs de protection, brouillons et outbox. Les écritures dans le
  groupe partagé restent interdites après déconnexion.
- OUT06 : appel répété ou déjà déconnecté → opération idempotente ; l'ancien
  timer ne déclenche plus de synchronisation.
- OUT07 : synchronisation suspendue au premier ou dernier GET → une réponse
  tardive ne restaure ni identité, ni jeton, ni connexion persistée et n'envoie
  plus d'opération après la déconnexion.
- OUT08 : écriture de connexion sécurisée déjà commencée → la suppression locale
  s'effectue après cette écriture, pour empêcher la résurrection du jeton.
- OUT09 : connexion/login ou chargement initial suspendu → une déconnexion
  ultérieure invalide la réponse ancienne ; aucun timer ni secret recréé.
- OUT10 : suppression refusée par le stockage sécurisé → identité mémoire
  neutralisée, erreur de stockage propagée, aucune prétention de succès durable.
- OUT11 (complément de revue, avant test/correction) : une notification locale
  lève une exception ; l'effacement des secrets doit quand même être terminé.
- OUT12 (complément de revue, avant test) : une ancienne synchronisation répond
  après une nouvelle connexion ; ne pas altérer ni supprimer la nouvelle identité.

## Périmètre et limites

Aucun écran ni contrat API modifié. Aucun effacement du groupe ni de l'outbox.
La révocation distante hors ligne n'est pas garantie et n'est pas mise en file
avec un jeton conservé ; son expiration et sa révocation côté serveur restent
indépendantes. Contrôles automatisés du service ; pas de validation de trousseau
sur appareil physique revendiquée.

## Résultats

- RED initial : 13 échecs comportementaux et 2 succès ; les erreurs distantes
  remontaient avant effacement et les opérations tardives restauraient l'identité.
  Preuve : `offline-disconnect-red-2026-10-25.txt`.
- Complément de revue OUT11 RED : le callback interrompait l'effacement et le
  jeton restait présent. Preuve : `offline-disconnect-review-red-2026-10-25.txt`.
- GREEN ciblé final : 30 tests réussis (17 cas de ce lot et 13 tests existants
  des accès collectif/gestionnaires et du cycle de synchronisation), en 1 s.
  Preuve : `offline-disconnect-green-2026-10-25.txt`.
- Analyse ciblée : 3 informations préexistantes sur l'ordre des imports, aucune
  nouvelle information/erreur/alerte ; `offline-disconnect-analyze-2026-10-25.txt`.
- Régression Flutter complète : **864 tests réussis en 2 min 04**, code figé ;
  `offline-disconnect-regression-2026-10-25.txt`.
- Revue distincte : `review-offline-disconnect-2026-10-25.md` ; point OUT11
  corrigé en TDD et vérifié, aucun autre blocage identifié dans le périmètre.

La fixture du test de timer sépare l'horloge simulée Flutter des opérations réelles
SQLite/stockage (`runAsync`) ; son attente initiale ne constituait pas un RED
applicatif supplémentaire. Les tests contrôlent le service et les frontières
asynchrones, sans valider visuellement un écran ou un trousseau physique.
