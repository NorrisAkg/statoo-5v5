# Revue dédiée — stabilité des interactions web

Validation finale : 16 octobre 2026.

Revue en lecture seule du module `web/interaction.mjs`, de son intégration dans
les rendus de `web/app.mjs`, de l’isolation des critères de séances, des gardes
après actualisation et des tests/livraisons PWA.

Résultat : aucune anomalie applicative bloquante identifiée. Le test de
livraison statique a également été exécuté par le relecteur : 1/1 réussi.

Constat initial sur les tests : le callback périodique ne retourne pas la promesse
de l’actualisation ; attendre `window.stabilityPending` n’attendait donc rien.
Une attente fixe de 100 ms rendait la preuve fragile.

Correction : instrumentation dans les tests de la consommation `text/json` des
réponses du groupe. Les assertions attendent ce signal, après lequel les suites
de promesses de lecture et de rendu s’exécutent dans la même chaîne de microtâches.
Pas de modification du code applicatif pour satisfaire l’instrumentation.

Seconde revue : constat levé. La course STAB-05 est toujours exercée par une
réponse contrôlée bloquée puis libérée après ouverture et saisie dans le dialogue.
Aucune anomalie bloquante restante dans le périmètre relu.
