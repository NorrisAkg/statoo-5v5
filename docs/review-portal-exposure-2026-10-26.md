# F10 — Revue distincte après implémentation

## Périmètre et méthode

Relecture du nouveau module app/portal.py, de son montage dans create_app,
des 92 nouveaux cas et de la documentation après le GREEN ciblé (98 tests).
Le diff de main.py contient les lots antérieurs F03/F06/F09 : seule la substitution
du montage statique et son import appartiennent à F10.

## Constats

- Liste explicite de fichiers, sans autorisation globale par extension ou dossier.
  Les ressources ajoutées sous icons/fonts/vendor sont privées par défaut.
- lookup_path protège aussi les recherches internes de StaticFiles (index,
  éventuelle page 404), pas seulement le chemin initial de la requête.
- Les chemins sont normalisés par StaticFiles puis comparés à la liste ; encodage,
  traversée et paramètres sont testés. La vérification du chemin réel empêche
  un fichier public symbolique de servir un fichier privé interne. La protection
  native contre la sortie du répertoire est conservée.
- Le répertoire racine est admis pour rechercher index.html. Aucun listing ni
  fallback vers index pour les chemins privés/inconnus n'est introduit.
- Le service statique natif conserve HEAD, MIME, ETag/304 et refus des méthodes.
  La route dynamique config.json précède le montage et ne sert que api_url.
- Les tests sollicitent la véritable application ASGI ; les fichiers privés
  supplémentaires et liens symboliques sont créés dans des dossiers temporaires.
  Les ressources du shell et imports relatifs des modules sont parcourus via HTTP.
- Aucun changement des permissions métier, de la base, des écritures, des données
  du navigateur ou du code Flutter. L'accès public reste prévu pour le portail.

Aucun défaut bloquant relevé dans le périmètre.

## Vérifications et limites

- RED : 31 échecs comportementaux (ressources privées répondant 200), 61 réussites.
- GREEN ciblé : 98 réussites, incluant les 92 nouveaux tests et 6 tests existants
  de configuration/déploiement.
- Régression Node : 61 tests réussis, 0 ignoré.
- Régression backend complète : 406 tests réussis en 379,11 s. Un avertissement
  existant de dépréciation Starlette TestClient/httpx, sans échec.
- Contrôle final git diff --check réussi.
- Le premier lancement Python dans le bac à sable s'est bloqué, et le premier
  rapport Node ne comptait que les fichiers. Ces sorties ne sont pas utilisées
  comme preuves ; les exécutions hors bac à sable sont les preuves conservées.
- Tests locaux Linux : pas de navigateur, de contrôle visuel, de Windows ou de
  déploiement externe pour ce lot. Vercel, autres serveurs statiques et caches
  déjà installés ne sont pas corrigés par le montage API.
- La liste publique doit être maintenue lors de futurs ajouts de ressources ;
  les tests du shell et des imports détectent les dépendances locales manquantes.
- Aucun commit créé.
