# Revue avant commit — 16 octobre 2026

Périmètre : corrections de parité API/web/mobile, interactions stables, parcours sportif, loaders et validation Zod. Exclusion : dossiers natifs racine android/ et ios/ préexistants.

Revue dédiée en lecture seule : aucun défaut bloquant identifié. Le message court de succès d'arbitrage reste accompagné de l'alerte globale si l'actualisation échoue.

## Scénarios avant les ajustements de revue

- GRP-09 : créer un groupe sans identifiant imposé doit envoyer un corps sans group_id et conserver l'identifiant attribué par le serveur. Le contrôle statique précédent échoue parce qu'il trouve maintenant group_id dans la validation de connexion ; ce faux positif n'est pas un RED produit. Remplacement par un test du client réel avec transport simulé ; le test navigateur existant vérifie déjà le corps émis par l'interface.
- STYLE-01 : l'analyse des trois fichiers Flutter modifiés doit ne signaler aucune information. Observation avant correction : deux cascade_invocations. Fusionner uniquement les appels consécutifs au même receveur ; aucune règle métier modifiée.
- REG-01 : les tests web unitaires/navigateur, API et Flutter existants doivent rester tous verts après ces ajustements. Les tests de restauration et d'import existants couvrent les deux chemins Flutter concernés. Aucun test comportemental supplémentaire pour la syntaxe de cascade seule.

Les scénarios et preuves RED/GREEN des évolutions applicatives sont conservés dans les quatre journaux docs/tdd-web-*.md et leurs répertoires de résultats.

## Résultats de la revue

Relecteur dédié : avis favorable initial et confirmation après les ajustements GRP-09/cascades. Aucun nouveau défaut bloquant.

- Web unitaire : 52 réussis, 0 échec.
- Navigateur Chromium : 99 réussis, 0 échec.
- Flutter complet : 300 réussis, 0 échec ; relance ciblée après cascades : 7 réussis.
- Analyse Flutter ciblée : No issues found.
- Construction PWA : réussie ; bundle Zod régénéré avec empreinte SHA-256 identique.
- git diff --check : réussi.

Traces de cette campagne : [commit-review-results](commit-review-results/).
Les vérifications physiques iOS/Safari, installation et lecteurs d'écran restent manuelles, comme indiqué dans les journaux TDD. Le commit ne vaut pas déploiement.

API : 62 tests réussis, 0 échec. Un avertissement de dépréciation Starlette/httpx préexistant, sans échec.

Les traces texte ont été normalisées uniquement pour retirer les espaces en fin de ligne et les lignes vides terminales avant git diff --cached --check ; les résultats sont conservés.
