# Préparation de groupe hors connexion — scénarios avant code

| ID | Situation | Attendu |
| --- | --- | --- |
| OFF-01 | PWA déjà chargée, réseau coupé, création | Saisir nom et membres, aucun champ d'identifiants ou de mots de passe ; enregistrer sur cet appareil sans requête serveur. |
| OFF-02 | Rechargement hors connexion et reprise | Retrouver le nom, les membres et la référence temporaire ; statut « en attente de connexion », aucun identifiant définitif inventé. |
| OFF-03 | Retour du réseau | Pas de publication automatique ; demander les accès Admin et collectif, puis confirmation par le bouton de création. |
| OFF-04 | Publication réussie | Groupe définitif reçu et affiché, préparation effacée ; seuls nom/membres et métadonnées techniques ont été persistés, aucun mot de passe. |
| OFF-05 | Serveur accepte mais réponse perdue, nouvelle tentative après rechargement | Même opération et mêmes membres renvoyés ; un seul groupe côté serveur. Redemander les accès, geler nom/membres durant l'incertitude. |
| OFF-06 | Réutilisation d'une opération avec un contenu différent | Refus 409, aucune divulgation de jeton ni création supplémentaire. |
| OFF-07 | Stockage plein/refusé ou préparation illisible | Message explicite ; ne pas annoncer une sauvegarde ni écraser silencieusement une préparation corrompue. |
| OFF-08 | Nom vide ou liste de séparateurs sans membres | Refus local, aucune publication ni faux succès. |
| OFF-09 | Abandon volontaire | Confirmation avant effacement ; avertissement spécifique si publication incertaine. |
| OFF-10 | Changement d'API après publication incertaine | Refus de transférer la tentative au nouveau serveur. |
| OFF-11 | Première visite sans réseau et sans shell installé | Pas de promesse de disponibilité : la PWA doit avoir été chargée auparavant ; l'effacement du stockage fait perdre la préparation. |
| OFF-12 | Réponse de publication perdue sans recharger la page | Message indiquant immédiatement la publication à vérifier et la nécessité de reprendre les mêmes accès. |

Le stockage de préparation est propre à l'origine du portail, indépendant des comptes connectés. Une seule préparation locale à la fois. L'identifiant définitif et le partage restent réservés au serveur. La consultation et la saisie de séances/finances avant publication sont hors périmètre.

## Preuves du cycle TDD

- RED avant code : champs de mots de passe visibles hors connexion ; absence de préparation locale ; deux publications de la même opération retournaient deux identifiants de groupe différents.
- GREEN ciblé : conservation après rechargement, exclusion des identifiants/mots de passe du stockage de préparation, erreurs de stockage et corruption, refus des données vides, verrouillage d'une tentative incertaine et refus d'un changement de serveur.
- Navigateur et API locale réelle : coupure réseau, sauvegarde, rechargement hors connexion, reprise en ligne sans publication automatique, réponse volontairement perdue après création, rechargement et nouvelle tentative retrouvant le même groupe. Effacement de la préparation après succès vérifié.
- Abandon : annuler la confirmation conserve la préparation ; confirmer l'efface.
- OFF-12 : absence du message de reprise constatée (RED), puis message explicite validé après correction (GREEN).
- Limites : Chrome automatisé ; installation et fonctionnement physique Android/iOS non rejoués. La préparation n'est pas une sauvegarde externe et reste perdue si le stockage local est effacé.
- Régression finale : `npm run build` réussi avec 43 tests backend et 34 tests unitaires web. Suite navigateur de 30 tests réussie, complétée par les deux tests ciblés incluant le nouvel abandon avec confirmation (31 cas navigateur distincts au total).
