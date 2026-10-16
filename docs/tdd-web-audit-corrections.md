# Corrections des incohérences PWA — 15 octobre 2026

Scénarios écrits avant le code applicatif. Référence : audit PWA du 15 octobre.
AUD-06 : décision utilisateur confirmée avant implémentation : règle de groupe,
6 joueurs par défaut, réglable par l'Admin entre 2 et 30.

| ID | Scénarios prévus | Résultats attendus |
| --- | --- | --- |
| FIX-01 | Brouillons sport/finance à révision inchangée, révision/génération différente, document disparu, ancien brouillon sans contexte, nouvelle échéance devenue occupée ; tentative de publication après actualisation du formulaire | Conserver contenu et contexte d'origine. Bloquer la publication périmée avant tout envoi. Afficher un avertissement et permettre de relire la version publiée puis abandonner explicitement le brouillon. Une annulation conserve les saisies. Une révision identique reste publiable. |
| FIX-02 | Soldes : caisse, date, avance négative et pénalité modifiées ; fermeture, Échap, rechargement, erreur de validation/réseau, confirmation annulée ; succès et déconnexion | Retrouver toutes les saisies pour le même compte/groupe ; ne pas transmettre sans confirmation ; effacer le brouillon après succès ou déconnexion. Un autre compte ne le lit pas. |
| FIX-03 | Mutation acceptée puis lecture réseau/503 échouée ; mutation refusée ; lecture 401 ; mutation suivante réussie | Acquittement conservé avec avertissement visible et actualisation manuelle possible sans répéter l'écriture. Les refus restent des erreurs. Le 401 déconnecte. L'avertissement précédent est effacé au prochain succès. |
| FIX-04 | Deux lectures inversées, dernière lecture échouée, changement de compte et déconnexion pendant la lecture | Seule la dernière lecture demandée du même compte peut modifier affichage/cache/identité. Une réponse périmée ne rétablit pas des données anciennes. |
| FIX-05 | Égalités de points, victoires, séances et noms ; amicaux, brouillons, annulations et tournois | Départager par points, victoires, séances décroissants puis nom ; seules séances clôturées classées contribuent aux victoires/points. Les buts amicaux restent comptés. |
| FIX-06 | Groupe ancien/nouveau, modification Admin/SG/TR/collectif, valeurs 1/2/6/30/31 et booléen/décimal ; clôture classique/tournoi sous/au seuil ; brouillon/annulation ; lecture/import mobile et groupe local | API expose `sport_settings.min_players_per_session` (défaut 6), PUT réservé Admin avec entier 2..30. Web transmet le réglage à la validation ; API refuse la clôture sous le seuil même si le client est ancien. Mobile importe le réglage, le lit pour le groupe partagé et n'autorise pas sa modification locale ; groupes locaux préservés. La nouvelle règle n'invalide pas la lecture des séances historiques. |
| FIX-07 | Catalogue lent, absent, HTTP en erreur, JSON invalide ; connexion sans session et consultation avec session | Aucun blocage du démarrage par le catalogue. État explicite si une création requiert des noms encore indisponibles. Reprise possible après chargement. |
| FIX-08 | Catalogue absent et modification de séance existante ou reprise d'un brouillon déjà nommé | Formulaire utilisable avec les noms sauvegardés. Aucun tirage silencieux remplaçant les noms existants. Une nouvelle séance sans noms ne s'ouvre pas avec des noms invalides. |
| FIX-09 | Getter localStorage/sessionStorage refusé, lecture/écriture/suppression refusées, quota atteint | Afficher une limitation exploitable, aucun écran figé ni exception non traitée. Les envois exigeant une persistance et la création hors ligne sont bloqués sans écriture réseau. Le thème peut changer sans persistance. |
| FIX-10 | Toute la palette des équipes en thèmes clair/sombre, cartes liste/détail | Texte des noms à contraste >= 4,5:1 ; couleur d'équipe conservée dans un repère distinct. |
| FIX-11 | Réponses HTML 503/401/403/422, JSON valide, JSON malformé, succès vide, timeout | Message métier/service compréhensible, statut HTTP conservé pour les protections de session et la file d'envoi ; jamais de message brut de parsing. JSON valide et timeout conservent leur comportement. |
| FIX-12 | Ancien shell PWA en cache et nouveaux fichiers corrigés | Nouvelle version de cache, mêmes ressources publiques disponibles ; aucun cache de réponses privées. |

## Résultats observés

Cas découvert à la relecture avant correction correspondante : FIX-06b — groupe
partagé protégé mais déconnecté. Le réglage synchronisé reste consultable hors
ligne ; les commandes locales ne peuvent pas modifier cette règle de groupe.

FIX-06c — candidat sportif créé avec un ancien minimum puis règle relevée avant
arbitrage : retenir ce candidat clôturé sous le seuil courant est refusé, sans
modifier le conflit. Conserver la version déjà publiée reste autorisé pour ne
pas invalider rétroactivement l'historique.

### Preuves RED

Les [observations RED](web-audit-corrections-results/red-observations.md) recensent
les assertions métier réellement échouées avant chaque correction. Les erreurs
de préparation et de fixtures sont identifiées séparément. Les traces initiales
de l'audit restent inchangées ; les nouvelles mesures sont dans
`docs/web-audit-corrections-results/`.

### Implémentation

- Sport et finances : le brouillon conserve la révision, la génération et le
  responsable de sa base. Une différence bloque l'envoi avant toute requête de
  publication. Les brouillons anciens sans ce contexte sont également bloqués.
  Le contenu reste visible ; relire la version publiée puis confirmer permet
  d'abandonner explicitement le brouillon. Aucune fusion silencieuse.
- Soldes initiaux : caisse, date et lignes sont enregistrées dans la partition
  locale du compte/groupe, retrouvées après fermeture ou rechargement, puis
  retirées après soumission acceptée. La déconnexion conserve sa sémantique
  existante d'effacement des données locales du compte.
- Les mutations administratives acquittées restent réussies si la relecture
  échoue, avec avertissement et possibilité d'actualiser sans réécrire. Un 401
  garde son traitement d'expiration de session.
- Les lectures du même compte sont séquencées : une réponse dépassée ne remplace
  ni les données ni leur cache, même si la dernière lecture échoue.
- Départage : points, victoires, séances, nom. Les amicaux ne donnent pas de
  victoires au classement ; leurs buts et passes restent comptés.
- Le minimum commun est exposé en `sport_settings.min_players_per_session`,
  avec 6 par défaut pour les groupes nouveaux ou historiques. Seul l'Admin peut
  appeler `PUT /groups/{id}/sport-settings`, avec un entier de 2 à 30.
  La clôture et la sélection d'une candidate d'arbitrage sont vérifiées par
  l'API ; conserver un résultat historique déjà publié reste possible.
- Configuration via PWA → Gérer le groupe → Paramètres sportifs. Le mobile
  importe et observe cette valeur ; ses contrôles locaux sont désactivés pour
  les groupes partagés, y compris protégés mais déconnectés. Le réglage des
  groupes locaux reste disponible.
- Le catalogue d'équipes charge indépendamment du démarrage. Une séance ou un
  brouillon déjà nommé reste éditable sans ce fichier. Une création sans noms
  conserve un message explicite d'indisponibilité.
- Les accès refusés aux objets de stockage n'empêchent plus le rendu du shell.
  Les opérations nécessitant une persistance ne bénéficient d'aucune fausse
  garantie d'enregistrement.
- Les noms d'équipe utilisent la couleur de texte du thème ; un repère distinct
  conserve la couleur du camp. Toute la palette est mesurée dans les deux thèmes.
- Les réponses HTML/non JSON produisent un message exploitable en conservant le
  statut HTTP. Un succès vide est accepté ; un JSON invalide de succès est signalé.
- Cache PWA renouvelé. Le lot d'interactions présent dans le dépôt ajoute son
  module au précache et au paquet statique. Les dix scénarios navigateur de cet
  audit rejoignent la commande régulière `npm run test:web:browser`.

### Vérifications exécutées le 16 octobre

| Contrôle | Résultat |
| --- | --- |
| `npm run test:web` | **45 tests réussis, 0 échec** — [trace](web-audit-corrections-results/web-unit-green.txt) |
| `node --test web/tests/audit/client.audit.mjs web/tests/audit/browser.audit.mjs` | **15 tests réussis, 0 échec** — [trace](web-audit-corrections-results/audit-green.txt) |
| `flutter test --no-pub` depuis mobile | **300 tests réussis, 0 échec** — [trace](web-audit-corrections-results/flutter-green.txt) |
| `pytest -q --tb=short` depuis backend | **62 tests réussis, 0 échec**, 298 s — [trace](web-audit-corrections-results/backend-green.txt). Un avertissement de dépréciation Starlette/httpx, sans échec. |
| `npm run test:web:browser`, audit inclus | **55 tests réussis, 0 échec** — [trace](web-audit-corrections-results/web-browser-green.txt). Comprend les interactions et le paquet statique du lot voisin. |
| Analyse Flutter ciblée | Pas d'erreur ni avertissement ; 2 informations de style (`cascade_invocations`) dans la [trace](web-audit-corrections-results/flutter-analysis.txt). |

Les fixtures sportives anciennes de régression ont reçu des effectifs légaux et
des seuils explicitement configurés (2 ou 3) pour continuer à tester leur objet
initial. Le défaut de production reste 6, vérifié séparément. Aucun contrôle
applicatif n'a été retiré pour faire passer les anciens tests.

### Limites et livraison

Les variantes du catalogue sont un périmètre de vérification, pas une déclaration
de couverture exhaustive. Les tests couvrent notamment les révisions et
générations périmées, les brouillons historiques, les annulations de confirmation,
la reprise des soldes après rechargement, les réponses inversées, les refus HTTP,
les bornes du minimum et toute la palette clair/sombre. Les combinaisons non
exécutées ne sont pas réputées validées.

Restent distincts : installation physique Android/iOS, Safari, TalkBack/VoiceOver,
réseau mobile réel, reprise après interruption du système et comparaison visuelle
sur appareils. Aucune validation de production ou de ces environnements n'est
déduite des tests Chrome et Flutter.

Cette livraison ne réalise pas les fonctions encore absentes de la PWA relevées
par l'audit comparatif (fiches joueurs, statistiques/MVP, sauvegardes et mode local
autonome, notamment). Le lot d'interactions voisin conserve sa propre traçabilité
dans `docs/tdd-web-interactions-stables.md`.

Le nouveau contrat sportif nécessite une livraison cohérente API/PWA/mobile. Les
anciens clients peuvent recevoir un refus explicite si leur clôture est sous le
minimum du groupe. Aucun déploiement, commit ou push effectué dans cette passe.

La dernière vérification `git diff --check` est sans erreur. Les régressions
finales ont été exécutées sur l'ensemble des changements présents, y compris le
lot voisin de conservation des interactions. Les rapports d'audit historiques
n'ont pas été réécrits pour refléter les corrections.
