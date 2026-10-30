# F09 — Erreurs de validation sans reprise des secrets soumis

## Scénarios définis avant code applicatif

Les erreurs de modèle de requête renvoient 422 avec un objet JSON `detail` texte
français générique et utile. Ne recopier aucun input, corps, loc dynamique, msg
ou ctx de l'exception : les champs manquants peuvent contenir tout le formulaire,
les clés de dictionnaire peuvent être des données privées et un validateur peut
inclure une valeur dans son message. Conserver les messages métier explicites.

- SEC01 : login, inscription Admin/collectif, ajout de gestionnaire et rotation
  collective : mot de passe court, trop long ou objet invalide → 422, aucune
  valeur soumise dans la réponse ou ses en-têtes, aucune mutation de données.
- SEC02 : vérification de mot de passe collectif/gestionnaire et génération d'un
  nouveau mot de passe : types invalides et champs manquants protégés aussi ;
  les refus métier de longueur/contrat déjà sûrs restent en 422 sans secret.
- SEC03 : champ requis manquant alors que les autres accès sont valides → ne pas
  renvoyer le formulaire complet. Vérifier aussi un corps racine de type liste
  et un JSON mal formé. Aucun groupe, jeton ou opération créé sur refus.
- SEC04 : erreur imbriquée et clé de dictionnaire contrôlée par l'appelant (soldes
  initiaux) → aucune reprise de cette clé/valeur dans loc, message ou contexte.
- SEC05 : validateur de test dont le message contient intentionnellement le
  secret → le gestionnaire ne reprend ni msg ni ctx. Route uniquement ajoutée
  à l'application isolée des tests, jamais au serveur de production.
- SEC06 : Point.model_validate dans la route financière échoue (mauvais type ou
  champ supplémentaire) → 422 sûr, sans convertir l'exception complète en texte.
  Préparer réellement Président/Trésorier et soldes pour atteindre cette validation.
- SEC07 : login incorrect (401), rôle insuffisant (403), mot de passe collectif
  incorrect (400) et règle métier financière (422) conservent leurs statuts et
  messages explicites, sans secret ni mutation de la situation existante.
- SEC08 : une connexion valide émet toujours un jeton ; les droits et les
  mots de passe persistés restent inchangés. Compatibilité des clients : Flutter
  accepte detail texte, et le portail traite déjà ce format pour les refus métier.

## Périmètre et limites

Gestionnaire RequestValidationError et exception Pydantic de la validation
financière interne. Pas de normalisation de mots de passe, de masquage des
réponses de succès autorisées, ni de changement de droits ou d'interface.
Ne pas prétendre nettoyer les journaux externes, reverse proxies, requêtes déjà
capturées ou toutes les erreurs métier futures qui refléteraient volontairement
les entrées. Les tests n'utilisent que des marqueurs synthétiques.

## Résultats

- RED avant correction : **32 échecs, 11 réussites**, en 6,93 s. Échecs
  comportementaux sur le format non protégé des erreurs de requête et sur les
  marqueurs repris par les exceptions financières ; aucune erreur de fixture.
  [Journal RED](validation-secrets-red-2026-10-26.txt).
- GREEN après correction : **43 tests réussis**, en 6,82 s.
  [Journal GREEN](validation-secrets-green-2026-10-26.txt).
- Régression complète backend : **314 tests réussis**, en 362,82 s.
  [Journal complet](validation-secrets-regression-2026-10-26.txt).
- Avertissement existant : dépréciation Starlette TestClient/httpx ; aucun échec.
- Revue distincte après implémentation : aucun défaut bloquant relevé,
  [constats et limites](review-validation-secrets-2026-10-26.md).
- git diff --check réussi. Aucun commit pour ce lot. Pas de test Flutter ou
  contrôle visuel exécuté ; compatibilité du détail texte vérifiée dans le code
  des clients. Les journaux externes restent hors du périmètre vérifié.
