# Bouton de mise à jour unique — scénarios avant correction

- UPD-01 : un worker est déjà en attente, puis plusieurs événements statechange/updatefound arrivent : un seul bouton de mise à jour existe.
- UPD-02 : le worker en attente est remplacé : le bouton existant cible le worker actuel, sans créer un autre bouton.
- UPD-03 : annuler la confirmation n'envoie rien ; confirmer envoie un seul SKIP_WAITING pour ce clic.
- UPD-04 : sans mise à jour, aucun bouton ; la première prise de contrôle ne recharge pas la page ; une mise à jour du contrôleur ne recharge qu'une fois.
- UPD-05 : installation standard, cache du shell et nouvelle version de la PWA restent disponibles.

RED : les événements répétés produisaient quatre boutons au lieu d'un dans le test ciblé. GREEN : une seule instance conservée ; le clic vise toujours le worker actuel et respecte la confirmation. Les deux tests ciblés passent ; `npm run build:web` réussit avec 38 tests unitaires. Shell versionné pour distribuer le correctif. Aucun changement du backend.
