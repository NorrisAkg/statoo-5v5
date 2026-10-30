# F09 — Revue distincte après implémentation

## Périmètre relu

Gestionnaire RequestValidationError dans create_app, interception prioritaire de
ValidationError dans la synchronisation financière, tests et contrat README.
Le diff Git contient aussi F03/F06 déjà présents ; ils ne sont pas attribués à F09.
Revue réalisée après les 43 tests ciblés GREEN, indépendamment de leur résultat.

## Constats

- Le gestionnaire ne lit ni corps, ni errors(), ni chemins, messages ou contexte
  de l'exception. La réponse JSON statique ne peut pas reprendre ces données.
- ValidationError est interceptée avant ValueError (sa classe parente), ce qui
  ferme la fuite par str(exc). Les autres ValueError du chemin financier ont été
  relues : leurs messages métier sont constants et restent utiles au client.
- Aucun changement des dépendances d'authentification, des rôles, de la génération
  des jetons, du hachage ou des écritures. Les tests comparent les états Group,
  Token et RegistrationOperation avant/après refus.
- Les tests financiers installent réellement les responsables et approuvent les
  soldes initiaux pour atteindre la validation concernée. La route au validateur
  volontairement indiscret existe seulement dans l'application de test.
- Le détail texte est compatible avec SharedApiException et les deux transports
  Flutter, ainsi qu'avec le client du portail historique (lecture du code).
- Les anciens détails par champ deviennent génériques pour toutes les erreurs de
  modèle de requête : compromis explicite de confidentialité. Les refus métier
  HTTPException conservent leurs statuts et messages.

Aucun défaut bloquant relevé dans le périmètre.

## Vérifications et limites

- RED : 32 échecs comportementaux, 11 cas déjà sûrs réussis ; aucune erreur de
  préparation. Les erreurs de requête échouaient sur le contrat detail texte ;
  les deux erreurs financières échouaient sur la présence du marqueur synthétique.
- GREEN : 43 tests réussis en 6,82 s.
- Régression backend complète : 314 tests réussis en 362,82 s, incluant les 43
  nouveaux cas. Un avertissement existant de dépréciation TestClient/httpx.
- git diff --check : réussi.
- Pas de contrôle visuel ni de suite Flutter exécutée pour ce lot backend.
- Le schéma OpenAPI de validation FastAPI reste standard ; les consommateurs
  doivent utiliser le contrat detail texte décrit au README pour les erreurs.
- Les journaux externes et d'éventuelles futures erreurs métier contenant des
  entrées nécessitent leur propre protection ; aucune promesse de nettoyage.
- Aucun commit créé pour ce lot.
