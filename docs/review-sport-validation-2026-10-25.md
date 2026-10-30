# Revue distincte après implémentation — F03

## Périmètre relu

Diff de `backend/app/main.py` limité à `validate_sport` et à l'import standard
`re`, nouveau module de tests, adaptation des deux générateurs de fixtures API.
Lecture croisée du calcul Flutter `computeTournamentResult`, du stockage natif
et de la conversion wire du portail historique.

## Constats

- Les structures et types sont vérifiés avant les opérations sur des ensembles,
  les comparaisons numériques et l'accès à la date ; les valeurs JSON composites
  testées ne peuvent plus provoquer les erreurs 500 constatées à l'audit.
- La validation intervient avant la création d'une candidature ou toute mutation
  du groupe. Les refus HTTP testés laissent le snapshot complet inchangé, y
  compris l'historique d'un document et les obligations financières.
- Le résultat de tournoi est dérivé des victoires selon les mêmes sept cas que
  Flutter ; zéro victoire ne permet pas de clôturer. Les scores optionnels de
  tournoi et les brouillons sans résultat restent autorisés.
- Les camps sont contrôlés indépendamment de la dérogation d'équilibre.
  Les chiffres négatifs/non entiers sont refusés avant les calculs, même dans
  les brouillons et annulations.
- Les options natives attendent 0/1, comme le stockage Flutter et `operation()`
  du portail. L'instantané synthétique interclients existant passe la validation.
- Les identifiants de participation sont désormais requis et uniques dans le
  document. Les fixtures antérieures sans identifiant ont été complétées ;
  aucune assertion de permission, conflit, finance ou cycle de vie n'est retirée.
- L'arbitrage revalide la candidature choisie. Le choix explicite `current`
  conserve le comportement historique, notamment après changement du minimum.

## Limites et conclusion

Aucun défaut bloquant identifié dans le diff du périmètre après vérification
ciblée. La suite globale et les résultats définitifs sont consignés dans le suivi
TDD. Aucun nettoyage des anciens documents n'est effectué. Une ancienne opération
invalide déjà acceptée peut encore retourner sa réponse idempotente enregistrée ;
le correctif empêche les nouvelles écritures invalides sans réécrire l'historique.

Les métadonnées libres, les limites maximales de tous les compteurs et les
collisions d'identifiants entre documents ne sont pas couverts par ce lot.
Les tests SQLite ne valident ni PostgreSQL en production, ni l'interface ou
un appareil physique. Les autres travaux locaux ne font pas partie de cette revue.

## Clôture de revue après régressions

240 tests API complets passent en 5 min 56, puis vérification des résultats
définitifs : 152 tests ciblés API (incluant SV10 ajouté après la collection
globale) et 44 tests Flutter ciblés réussis. Le diff final et la documentation
API ont été relus ; aucun changement applicatif n'a eu lieu pendant ces
régressions. Aucun défaut bloquant restant dans le périmètre. Seul avertissement
exécuté : dépréciation préexistante Starlette/httpx. Aucun commit ni push effectué.
