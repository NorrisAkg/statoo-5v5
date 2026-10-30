# F06 — Identifiants de connexion après suppression des espaces

## Scénarios définis avant code applicatif

Règle existante conservée : espaces extérieurs supprimés au stockage et à la
recherche, comparaison insensible à la casse par `casefold`, casse d'affichage et
espaces intérieurs conservés. Pas de nouvelle normalisation Unicode/accents.
Un identifiant composé uniquement d'espaces est invalide. Ne pas transformer les
valeurs des modèles avant le calcul de l'empreinte d'inscription : une tentative
historique avec espaces doit rester rejouable avec les mêmes informations.

- ID01 : inscription Admin/collectif équivalents après strip+casefold (espaces de
  part et d'autre, casse, tabulations, espaces Unicode, expansion ß→ss) refusée
  en 422 ; aucun groupe, jeton ou opération d'inscription n'est enregistré.
- ID02 : identifiant Admin ou collectif vide après strip refusé en 422 ; mêmes
  garanties d'atomicité. Une tentative refusée n'accapare pas son operation_id.
- ID03 : identifiants distincts avec espaces/casse conservés correctement au
  stockage ; chaque mot de passe connecte le bon compte et les bons droits.
  Espaces intérieurs et accents restent distinctifs selon la règle existante.
- ID04 : création d'un gestionnaire vide après strip refusée en 422, collision
  avec Admin/collectif refusée en 409 ; snapshot et jetons existants inchangés.
  Un identifiant distinct avec espaces est stocké nettoyé et reste connectable.
- ID05 : rotation de l'accès collectif vers un identifiant vide (422) ou celui
  d'un responsable (409) refusée sans mutation ni révocation du jeton existant.
  Rotation valide : nom nettoyé, nouveau mot de passe connectable, ancien jeton
  collectif révoqué ; droits Admin toujours nécessaires.
- ID06 : login avec identifiant uniquement blanc refusé en 422 ; login normal
  conserve la comparaison strip+casefold et n'altère pas les mots de passe.
- ID07 : reprise de la même inscription avec espaces et operation_id retourne le
  même groupe. L'empreinte persistée correspond au JSON historique non nettoyé ;
  une tentative modifiée reste refusée en 409 selon le mécanisme existant.

## Limites

Aucune migration ni réparation silencieuse des groupes ayant déjà des doublons.
L'Admin d'un groupe historiquement affecté peut renommer l'accès collectif via
la rotation existante. Aucun changement d'interface, de mot de passe, de groupe
ou de politique de caractères/longueur. Tests sur SQLite et requêtes HTTP réelles
TestClient ; pas de recette PostgreSQL concurrente ni sur appareil physique.

## Résultats

- RED : **20 échecs comportementaux et 10 succès**, en 78,49 s. Les collisions
  étaient acceptées et les noms blancs étaient créés/rotés ou traités comme un
  échec d'authentification. `login-identifiers-red-2026-10-26.txt`.
- GREEN ciblé : **30 tests réussis en 68,26 s** ;
  `login-identifiers-green-2026-10-26.txt`.
- Régression API complète : **271 tests réussis en 645,64 s (10 min 45)**,
  code applicatif figé ;
  `login-identifiers-regression-2026-10-26.txt`.
- Revue distincte : `review-login-identifiers-2026-10-26.md`, aucun défaut
  bloquant identifié dans le périmètre. `git diff --check` passe.
- Warning observé : dépréciation Starlette/httpx préexistante, non masquée.

Les groupes et jetons des tests sont synthétiques, dans une base SQLite en mémoire.
Aucun fichier utilisateur ni serveur de production n'est utilisé pour ces tests.
