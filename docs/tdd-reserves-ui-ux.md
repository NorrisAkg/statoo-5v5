# TDD — réserves D01 à D04 (15 octobre 2026)

Scénarios écrits avant modification applicative de ce lot. D01 est déjà implémenté dans HEAD `8519fba` : vérifier et compléter la non-régression, sans inventer une nouvelle preuve RED. D02/D03 : changement de présentation seulement ; contrat d’arbitrage, sélection et motif conservés. D04 : texte agrandi respecté, sans réduire artificiellement sa taille.

| ID | Conditions | Résultat attendu |
|---|---|---|
| D01-01 | Tournoi clôturé, scores nuls, victoires 3/1/0 | Trois noms et victoires ; pas de faux score A–B 0–0. |
| D01-02 | Tournoi DRAW_ALL 2/2/2, scores nuls | Trois compteurs égaux, troisième équipe présente. |
| D01-03 | Match classique et séance active | Scores classiques conservés ; séance active prioritaire ; lien vers la séance affichée conservé. Tests existants ACC. |
| D02-01 | Six membres identiques, dépenses Terrain 30/Eau 80 | Les deux dépenses différentes sont visibles dans le dialogue 393 × 852 sans traverser les lignes inchangées. |
| D02-02 | Don et pénalités inchangés | Repliés par défaut, consultables à la demande pour chaque version ; aucun détail supprimé. |
| D02-03 | Valeurs ajoutées/supprimées, zéro vs absence | Différences visibles, absence explicitée ; aucun rapprochement par libellé/homonyme. |
| D02-04 | Versions identiques ou plusieurs candidates | État sans différence explicite ; comparaison avec toutes les autres versions ; une sélection unique. |
| D02-05 | Changement de version puis ouverture/fermeture détails | Sélection conservée ; intitulé, auteur, date et motif de version accessibles. |
| D02-06 | Confirmation motivée candidate ou version publiée | Une requête avec révision, id sélectionné et motif nettoyé ; annulation = zéro requête. |
| D02-07 | Conflit sportif, noms JSON, victoires/compteurs différents | Même présentation des différences ; détail intégral accessible ; tests UX04 sportifs conservés. |
| D02-08 | Noms/motifs longs, 320/393 dp, thèmes clair/sombre, texte jusqu’à 200 % | Retour à la ligne, défilement possible, pas de perte de différence ni débordement ; contrôle de grandes listes reste distinct des mesures de performance. |
| D03-01 | Motif vide, détails longs, valider | Dialogue ouvert, zéro requête, erreur textuelle immédiatement visible dans la zone du dialogue. |
| D03-02 | Motif uniquement espaces | Même refus ; sélection préservée ; saisie corrigeable. |
| D03-03 | Erreur affichée | Message dans une région sémantique live ; information ne dépend pas uniquement du rouge. TalkBack parlé reste un contrôle physique. |
| D03-04 | Motif rempli après refus, candidate choisie | Correction possible sans quitter la comparaison, envoi du bon id et motif nettoyé. |
| D03-05 | Clavier réel/simulé, texte agrandi | Champ de motif et erreur ne disparaissent pas sous les détails ; actions restent atteignables ; test géométrique avec inset de clavier. |
| D03-06 | Annuler, retour système, fermeture après saisie | Aucun arbitrage ; contrôleur libéré après la transition ; tests existants de durée de vie conservés. |
| D04-01 | Détail draft, 393 dp, texte 200 %, action autorisée | Pas d’overflow ; titre et ajout dans la largeur ; ajout atteignable au défilement. |
| D04-02 | Même cas à 320 dp et 100/130 % | Même résultat ; pas de réduction du facteur de texte. |
| D04-03 | Thèmes clair/sombre | Même géométrie fonctionnelle et couleurs du thème conservées. |
| D04-04 | Lecture seule/clôturée | Pas d’action d’ajout introduite ; titre lisible à 200 %. |
| D04-05 | Séance active et brouillon en attente ; 2/3 équipes | États, noms/compteurs et commandes existants conservés ; pas d’overflow des en-têtes de cartes. |
| D04-06 | Noms d’équipe longs à texte agrandi | Noms complets sur plusieurs lignes, compte de joueurs lisible, cartes dans la largeur. |

## Exécution

À compléter avec les échecs comportementaux observés, puis les résultats GREEN. Un échec de fixture/compilation n’est pas une preuve RED. Les tests automatisés ne certifient ni TalkBack parlé ni le nouvel APK sur téléphone.

### Résultats automatisés

- D01 : déjà corrigé dans HEAD ; tests ACC existants conservés, nouveau cas de tournoi restauré DRAW_ALL 2/2/2 avec scores absents réussi. Aucune prétendue correction nouvelle de l’accueil.
- RED D02 : dépenses différentes non atteignables dans le dialogue à 393 dp ; détails inchangés non repliables ; aucune présentation explicite de versions identiques.
- RED D03 : erreur non immédiatement visible sur le cas long ; aucune région live explicite. Les refus ne doivent toujours envoyer aucune requête.
- RED D04 : débordements observés aux largeurs 320/393 dp, avec variantes de taille de texte et noms longs.
- GREEN ciblé : 62 tests réussis. Comprend 36 variantes de détail (320/393 dp × 100/130/200 % × clair/sombre × actif/brouillon en attente/lecture seule), différences ajoutées/supprimées, détail dépliable, choix de candidate, motif vide/espaces et clavier simulé de 300 dp.
- Suite Flutter complète : **343 tests réussis**, trace locale `tdd-reserves-flutter-validation.log`. Aucun changement backend dans ce lot ; pas de nouvelle prétention de validation serveur.
- Analyse ciblée : aucune erreur ni warning ; six informations de style dans du code préexistant. Les nouveaux diagnostics const des tests ont été corrigés.
- APK debug QA séparé compilé et installé avec succès par mise à jour (`adb install -r -t`, sans réinitialisation). Le lancement de contrôle suivant a échoué parce que le téléphone n’était plus détecté (`device 7522b268 not found`). Aucune nouvelle capture du rendu corrigé n’est donc présentée comme acquise à ce stade ; une reconnexion a été demandée. L’application réelle n’a pas été remplacée.

Traces RED locales : `tdd-reserves-red.log` et `tdd-reserves-red-complet.log`. Corrections de montage exclues des preuves RED : assertion de zéro trop large sur toute la page d’accueil, nettoyage tardif d’un handle sémantique, attente de frame après défilement et élément non encore construit dans une ListView. La réussite au vert n’est pas obtenue en supprimant les contrôles métier : les détails complets sont vérifiés après dépliage et le corps de décision reste vérifié.

### Reprise physique après reconnexion

ADB détecte `7522b268`, mais la nouvelle capture `100-reserves-nouvel-apk.png` est noire. Android indique `mWakefulness=Dozing` et `Keyguard showing=true` ; le garde-fou interrompt les interactions faute d’activité QA visible. Aucun rendu corrigé n’est validé par cette tentative. Déverrouillage et maintien de Statoo QA à l’écran demandés. Facteur de texte lu à 0,9 et non modifié ; aucune donnée applicative modifiée pendant cette tentative.

### Changements réalisés

### Validation physique acquise après déverrouillage

Téléphone Android `7522b268`, portrait 1080 × 2400, thème sombre, APK QA mis à jour. Les premières captures noires 100/101 ne constituent pas une preuve de rendu. L’activité QA et son accueil sont ensuite confirmés dans la capture 102.

- **D04 confirmé sur le cas reproduit** : brouillon en attente du groupe fictif qa-depart, six joueurs, texte système 200 %. Le titre Composition & Équipes, l’ajout revenu à la ligne, les deux onglets et les effectifs restent dans la largeur. Défilement effectué, sans modifier la séance. [Capture 104](essais-appareil-2026-10-14/captures/104-detail-200-composition.png). Facteur initial 0,9 restauré dans un finally puis relu à 0,9.
- **D02 confirmé sur deux versions financières** : occurrence synthétique dédiée qa-reserves-15, Terrain QA 30 F contre Eau QA 80 F ; les deux différences sont visibles sans défilement, 28 détails identiques repliés. [Capture 105](essais-appareil-2026-10-14/captures/105-arbitrage-differences.png). La candidate reste sélectionnée au dépliage ; cotisations, pénalités et motif restent consultables. [Capture 107](essais-appareil-2026-10-14/captures/107-arbitrage-details-deplies.png).
- **D03 confirmé pour motif vide** : appui sur Retenir cette version, dialogue maintenu et message textuel immédiatement visible sous le champ. [Capture 106](essais-appareil-2026-10-14/captures/106-arbitrage-erreur-visible.png). Annulation ensuite ; le conflit reste affiché. [Capture 108](essais-appareil-2026-10-14/captures/108-arbitrage-annule.png). Aucun arbitrage volontairement envoyé ; l’absence de POST est prouvée par les tests automatisés, pas par une interception réseau dans cette série.

Limites : D01 non revu physiquement (la séance active reste prioritaire, elle n’a pas été clôturée pour le test). Ni TalkBack parlé, ni espaces seuls, ni clavier réel, ni arbitrage à 200 %, ni thème clair contrôlés dans cette reprise. Ces cas restent distingués de leurs preuves automatisées. Aucune donnée de l’application habituelle n’a été touchée ; seules deux versions fictives ont été ajoutées au backend QA local.

### Détail de l’implémentation

D02 : les différences apparaissent en premier, sur toute la largeur du contenu ; les valeurs identiques restent accessibles dans « Détails inchangés ». Le choix de version est indépendant du détail et reste conservé au dépliage.

D03 : champ et erreur en dehors de la zone de versions défilante ; erreur textuelle avec région sémantique live, visible immédiatement. Ce test sémantique ne remplace pas l’écoute de TalkBack.

D04 : titre de composition et ajout passent à la ligne par Wrap ; en-têtes de cartes d’équipe flexibles pour conserver noms et effectifs à texte agrandi. Aucun nouveau plafonnement du texte.

## Ce qui reste sur les huit majeurs

Les corrections de code et les preuves unitaires ne signifient pas que les 148 scénarios ont tous été exécutés sur téléphone. La matrice d’origine reste la source de couverture ; les résultats physiques antérieurs ne sont pas remplacés par les tests de ce lot.

| Majeur | Vérifications encore nécessaires pour une validation complète |
|---|---|
| UX01 — remplacement | Annulation avec plusieurs groupes, fichier invalide, double appui, modification du périmètre pendant le choix, parcours Réglages, comparaison exhaustive des données conservées après refus/échec. |
| UX02 — saisies financières | Protection après chaque type de champ/don/dépense/annulation ; échec ou lenteur pendant sauvegarde ; changements de groupe, gestes prédictifs et interruptions. La persistance après arrêt forcé n’est pas implémentée dans ce périmètre. |
| UX03 — références | Deux paiements effectivement différents, réouverture en ordre inverse, synchronisation puis export/restauration sans mélange ; concurrents et variantes d’alias historiques. Les deux références -1/-2 ont déjà été contrôlées sur appareil. |
| UX04 — arbitrage | Affichage des deux différences, erreur de motif vide, sélection/dépliage et annulation contrôlés sur appareil. Restent confirmation motivée de candidate dans le nouvel APK, conflits sportifs, nombreuses candidates, révision périmée et expiration pendant décision. |
| UX05 — approbation | Refaire le test physique de proposition remplacée avec preuve 409, double approbation, révocation/expiration et récupération réseau. L’ancien montage de test 409 avait échoué ; les tests API existaient déjà. |
| UX06 — permissions | Matrice complète rôles/domaines sur appareil ; retrait pendant saisie, propriété d’une autre séance, groupe partagé déconnecté/restauré, toutes les commandes et voies indirectes. Les refus et capacités sont partiellement automatisés ; PDT/SG ont été observés physiquement. |
| UX07 — restauration tournoi | Fusion, autres égalités et gagnants, anciennes sauvegardes, tournois invalides et normalisation expliquée, répétition/rollback, lien financier conservé. Deux tournois valides et leur classement ont été vérifiés physiquement. |
| UX08 — accessibilité | Nouveau détail en brouillon contrôlé à 200 % sur ce téléphone. Restent autres états/écrans physiques, TalkBack parlé/focus, forte lumière et petits écrans. Portrait uniquement dans le produit actuel ; paysage hors support produit à documenter plutôt que prétendre validé. |

Priorité de validation : UX03 (intégrité des paiements), UX01 (conservation après refus), UX05/UX06 (approbation et autorisations), puis cas de présentation et couverture physique complémentaire. Aucun de ces cas n’est annoncé réussi sans exécution correspondante.
