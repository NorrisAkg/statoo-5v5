# Essais sur Android — corrections des huit majeurs

Campagne commencée le 14 octobre 2026 et poursuivie le 15 octobre. Ce document complète le journal TDD et l’audit initial. **Les huit corrections ne sont pas déclarées intégralement validées sur appareil.** Les résultats ci-dessous portent sur les manipulations et les données effectivement observées.

Mise à jour : les réserves D01–D04 sont reprises dans le [lot TDD du 15 octobre](../tdd-reserves-ui-ux.md). Les captures ci-dessous restent l’historique avant ce lot ; elles ne décrivent pas automatiquement le dernier code. D01 était déjà corrigé dans HEAD ; D02/D03/D04 ont reçu les corrections et tests indiqués dans ce suivi.

## Environnement et précautions

- Téléphone Android physique `7522b268`, écran 1080 × 2400. Tests en portrait, texte système à 90 % ; valeur finale relue : `0.9`.
- APK debug isolé : application `com.kysolutions.statoo.qa`, nom « Statoo QA ». Construction à partir du code corrigé ; seuls l’identifiant Android et le nom ont changé dans une copie sous `mobile/build/device-qa/source`.
- Application habituelle `com.kysolutions.statoo` : ni remplacée, ni réinitialisée. Aucun groupe réel modifié par ces essais.
- Backend réel lancé sur `127.0.0.1:19091`, base SQLite en mémoire, accessible au téléphone par ADB reverse. Les comptes, opérations et montants sont synthétiques. Aucun déploiement du serveur de production.
- Manipulations ADB gardées par vérification de l’application au premier plan. Plusieurs essais ont été interrompus lors de veille, passage dans une autre application ou déconnexion USB ; ces interruptions ne sont pas des échecs applicatifs.
- Les captures hors QA et les identités avec jetons sont exclues par le `.gitignore` de ce dossier. Ne pas les joindre au rapport.

## Résultats par correction

| Correction | Résultat sur appareil | Preuves | Ce que cela ne valide pas |
|---|---|---|---|
| UX01 — remplacement explicite | Confirmation affichée sur appareil initialement vide ; absence de groupe existant annoncée ; QA Alpha/QA Beta, six joueurs et deux séances listés ; import confirmé et données retrouvées. | [Récapitulatif](captures/12-import-recap.png), [accueil restauré](captures/15-qa-reprise-restauree.png). Copie SQLite initiale : deux groupes et deux tournois CLOSED. | Annulation avec deux groupes préexistants, fichier invalide, double appui, modification concurrente du périmètre et parcours depuis Réglages restent à tester sur appareil. |
| UX02 — protection des saisies | Cotisation Alice saisie à 5 F. Flèche retour : dialogue. Continuer : montant conservé. Premier retour Android : clavier fermé. Second retour : dialogue. Abandon explicite : sortie ; réouverture : total 0 F. Formulaire inchangé : sortie sans dialogue. | Captures [22](captures/22-finance-modifiee.png), [26](captures/26-garde-retour.png), [27](captures/27-saisie-conservee.png), [28](captures/28-garde-android.png), [29](captures/29-garde-android-sans-clavier.png), [30](captures/30-abandon-explicite.png), [31](captures/31-apres-abandon.png). | Une seule cotisation modifiée ; autres champs, sauvegarde lente, geste prédictif et arrêt forcé avec reprise de brouillon non validés. |
| UX03 — identités des séances | Deux séances créées par l’UI dans qa-depart le 15/10 ; références `2026-10-15-1` et `2026-10-15-2`, identifiants et alias financiers distincts retrouvés dans SQLite. La seconde est correctement enregistrée en brouillon car la première est en cours. | [Première séance](captures/87-seance-test-1.png), [seconde séance](captures/94-seconde-seance.png), [preuves filtrées](preuves-filtres.json). | L’indépendance de deux paiements effectivement enregistrés, les créations concurrentes et l’export/restauration des alias ne sont pas validés par ces créations. |
| UX04 — arbitrage détaillé | Deux versions à versements identiques : dépenses Terrain QA 30 F et Eau QA 80 F distinguées textuellement ; don, pénalités, membres, auteur et date lisibles au défilement. Motif vide : dialogue maintenu. Motif `Controle-QA` : version publiée conservée, conflit résolu, révision 2 et raison présentes dans le journal serveur. | [Version publiée](captures/68-comparaison-conflit.png), [dépense publiée](captures/69-conflit-bas-version.png), [dépense concurrente](captures/71-conflit-motif.png), [validation vide](captures/72-conflit-validation-vide.png), [résultat](captures/74-conflit-decision.png), preuves filtrées. | Choix d’une candidate différente de la version publiée, conflits sportifs, nombreuses candidates, révision périmée et expiration pendant décision restent à tester sur appareil. Réserves ergonomiques ci-dessous. |
| UX05 — relecture du départ | Révision des soldes avant POST d’approbation : caisse 1 000 F, date, trésorier, horodatage, Alice avance 200 F/pénalité 30 F, Benoit dette 100 F. Confirmation : POST 200 et événement `opening_approved`. Échec de rafraîchissement signalé séparément de l’approbation acquise. | [Relecture](captures/61-recap-depart.png), [approbation acquise et actualisation impossible](captures/62-approbation-perimee.png), journal synthétique des preuves filtrées. **Le nom de la capture 62 est trompeur : ce n’est pas un test de proposition périmée.** | Le script de modification concurrente n’a pas été exécuté correctement avant confirmation : pas de validation du 409 sur téléphone. Ce cas reste couvert par les tests API antérieurs, pas par cet essai manuel. |
| UX06 — actions selon droits | Président seul : pas de Nouvelle séance à l’accueil ni d’ajout dans la liste joueurs. Après transfert explicite SG au même compte fictif : création sportive accessible et réussie. Sélecteur de retardataires : quatre membres existants, aucune création de membre. | [PDT accueil](captures/76-pdt-accueil.png), [PDT joueurs](captures/77-pdt-joueurs.png), [SG accueil](captures/81-sg-accueil.png), [composition](captures/83-sg-composition.png), [retardataires](captures/88-sg-retardataires.png), [transfert synthétique](role-sport-test.json). | Matrice complète des rôles, retrait pendant saisie, session expirée, propriété d’une autre séance et ADMIN/TR sur tous les écrans non validés sur appareil. |
| UX07 — tournois restaurés | Deux tournois CLOSED avec scores A/B nuls restent clôturés : victoires 3/1/0 et 2/2/2, résultats A et DRAW_ALL. Liste et détail présentent les victoires ; classement : Alice et Benoit 4 points, Camille 1 point. | [Liste](captures/16-liste-tournois.png), [détail](captures/17-detail-tournoi.png), [classement à l’accueil](captures/15-qa-reprise-restauree.png). | Fusion, tous les résultats d’égalité, sauvegardes historiques et normalisation des tournois incohérents restent à tester sur appareil. L’accueil présente encore un résumé A–B erroné : D01. |
| UX08 — lisibilité des thèmes | Boutons principaux et en-têtes observés en clair ; bascule sombre appliquée aux réglages et à l’accueil, textes et actions visibles. Contrôle final du détail à 200 % : **échec de mise en page D04**, puis taille initiale rétablie. Les ratios chiffrés proviennent des tests automatisés, pas d’une mesure optique du téléphone. | [Clair](captures/35-parametres.png), [menu](captures/44-theme-menu.png), [sombre](captures/45-theme-sombre.png), [accueil sombre](captures/49-accueil-bas.png), [texte 200 %](captures/95-detail-texte-200.png). | Autres écrans à 200 %, 100/130 %, TalkBack parlé, paysage, petit écran et lumière extérieure non testés. |

## Réserves objectives découvertes

### D01 — l’accueil présente un tournoi comme un match A–B à 0–0

- Catégorie : bug fonctionnel de présentation ; sévérité modérée. Confiance élevée, confirmé à l’écran.
- Reproduction : restaurer les deux tournois de démonstration ; ouvrir l’accueil QA Alpha. Comparer « Dernière séance » avec la liste Séances et le détail du tournoi de 19 h.
- Observé : « Équipe A 0–0 Équipe B ». La liste présente pourtant trois équipes avec 2 victoires chacune. Le type et les résultats détaillés sont conservés.
- Attendu : résumé à trois équipes et victoires, ou lien de tournoi sans score de match inventé.
- Impact : lecture erronée du résultat récent, incohérence avec la liste et le détail.
- Preuves : captures 15, 16 et 40 ; composant concerné à rechercher dans `mobile/lib/features/home/presentation/home_screen.dart`.
- Correction recommandée : sélectionner le résumé selon `session_type` et réutiliser les données du tournoi. Validation : tests de l’accueil pour A gagnant et DRAW_ALL, puis comparaison à l’écran avec le détail. Écrire le test échouant avant modification.

### D02 — comparaison financière excessivement longue dès six membres

- Catégorie : problème UX ; sévérité modérée. Confiance élevée sur la densité observée ; gain utilisateur à évaluer après proposition.
- Reproduction : ouvrir le conflit qa-finance comprenant six membres et deux versions, sur cet appareil au texte 90 %.
- Observé : les mêmes lignes de cotisations, pénalités nulles et motifs vides sont répétées pour chaque version dans une colonne étroite. Trois longs défilements ont été nécessaires pour atteindre la dépense concurrente et le motif. Le bouton de décision reste visible avant les différences utiles.
- Attendu : différences et totaux comparables d’emblée ; détail intégral consultable au besoin.
- Impact : effort de comparaison et risque de retenir la version par défaut sans repérer la seule dépense différente.
- Preuves : captures 68 à 71. Il ne s’agit pas d’une perte de données : les différences sont présentes.
- Recommandation : résumé des changements par version en tête, détails inchangés repliables et sélection indépendante de la hauteur du texte. Validation : les deux dépenses et leurs montants se comparent sans traverser toutes les lignes inchangées ; le détail reste accessible et la sélection reste unique au défilement.

### D03 — message du motif obligatoire non visible immédiatement

- Catégorie : accessibilité/UX ; sévérité modérée pour l’identification de l’erreur. Confirmé pour la capture, cause précise à vérifier.
- Reproduction : atteindre le bas du conflit puis retenir la version avec motif vide.
- Observé : le dialogue reste ouvert et le champ est bordé de rouge ; le texte d’erreur n’est pas visible dans la zone capturée au déclenchement. Le code définit pourtant `errorText: reasonError` : on ne conclut pas à l’absence de message dans tout le document sémantique.
- Attendu : motif du refus immédiatement lisible, sans dépendre seulement de la couleur ni d’un défilement à découvrir.
- Impact : l’utilisateur peut ignorer pourquoi le bouton n’aboutit pas. Références WCAG 1.4.1 et 3.3.1, sans déclaration de conformité globale.
- Preuve : capture 72 ; `mobile/lib/features/shared/presentation/shared_group_screen.dart`, champ « Motif de décision ».
- Recommandation : rendre le champ et son aide visibles après validation, réserver la hauteur du message et annoncer l’erreur. Validation : message lisible après appui sans geste supplémentaire et annoncé par TalkBack, y compris texte agrandi.

### D04 — débordement du titre et de l’action de composition à 200 %

- Catégorie : accessibilité/défaut visuel ; sévérité modérée. Confirmé sur téléphone, confiance élevée.
- Reproduction : ouvrir le détail de la seconde séance en brouillon, avec compte SG ; régler le texte Android à 200 %, en portrait sur l’écran de test.
- Observé : la ligne « Composition & Équipes » et « Ajouter un joueur » ne tient plus dans la largeur. L’APK debug matérialise un `RenderFlex overflowed by 237 pixels` à droite ; une partie de l’action sort de l’écran.
- Attendu : titre et action se répartissent sur plusieurs lignes ou sur des lignes séparées, avec cible utilisable sans débordement.
- Impact : lecture et accès à l’action dégradés pour les utilisateurs qui agrandissent le texte. Référence WCAG 1.4.4, sans conclusion de conformité générale.
- Preuve : [capture du détail à 200 %](captures/95-detail-texte-200.png), à comparer à [90 %](captures/94-seconde-seance.png) ; `mobile/lib/features/sessions/presentation/session_detail_screen.dart`, ligne de composition et ajout.
- Recommandation : remplacer l’alignement rigide par une disposition adaptée à la largeur et au texte, sans brider le facteur d’agrandissement. Validation : test widget 393 dp/200 % avec `tester.takeException()` vide et action atteignable, puis essai physique. Étendre ensuite à 320 dp et aux noms longs.

Ces constats ne sont pas des préférences de palette. Aucune correction applicative supplémentaire n’a été écrite pendant cette campagne : les prochains changements doivent recevoir leurs scénarios et leur test RED.

## Incidents de préparation et limites de preuve

1. Installation initialement refusée par Android, puis autorisée par l’utilisateur. Les captures 00/01 montrent l’application habituelle ; elles ne prouvent aucune correction et sont exclues du rapport.
2. Captures initiales parfois prises pendant le démarrage blanc ou un chargement. Elles ne suffisent pas à conclure à un blocage permanent ; le helper attend désormais trois secondes après action. La campagne debug n’est pas un benchmark de production.
3. Les identifiants a…f étaient communs au jeu local et au jeu distant. L’import distant a correctement refusé ce mélange. Une intervention sur la seule base QA a été tentée pour corriger la fixture. Le redémarrage suivant a présenté un groupe local vide ; **les états locaux après cette intervention ne prouvent plus la persistance de l’import initial**. Cause instrumentale non établie ; ne pas attribuer cette perte au code applicatif sans reproduction par l’UI. Les preuves 15–17 sont antérieures à cette intervention. La génération des sauvegardes utilise maintenant des identifiants locaux préfixés.
4. La capture 62 correspond à une approbation normale, suivie d’un échec d’import dû à cette collision. Le test de proposition périmée a été invalidé par un mauvais chemin Python du montage ; ne pas le compter comme réussi ou comme bug applicatif.
5. Le 15 octobre, QA Alpha a été retrouvé avec 11 joueurs et une séance en cours. Ces données n’ont pas été réinitialisées pour poursuivre les essais ; les créations suivantes sont limitées à qa-depart.
6. Les interruptions de veille, changement d’application et USB sont consignées. Aucun essai interrompu n’est transformé en réussite. La seconde création a finalement abouti après adaptation au parcours Liste → + et à l’enregistrement en brouillon. Le premier essai de texte 200 % a été interrompu hors QA ; le contrôle final a bien porté sur le détail QA et a révélé D04. Les gestes prédictifs et TalkBack ne sont pas équivalents à `adb input keyevent 4` et à une lecture d’arbre sémantique.

## Suite priorisée

1. Reproduire D01 dans un test d’accueil puis corriger le résumé du tournoi ; vérifier à nouveau la liste et le détail.
2. Ajouter le test de régression D04 puis corriger la disposition de composition à 200 %. Reconcevoir et tester D02/D03 : différences visibles, motif atteignable, erreur annoncée ; contrôle à 100/130/200 % avant changement applicatif.
3. Compléter UX01 sur un groupe exclusivement synthétique dédié : annulations, fichier invalide, deux groupes existants, conservation intégrale des métadonnées et mode Réglages.
4. Compléter UX03 : enregistrer deux paiements distincts sur les deux références, rouvrir en ordre inverse, synchroniser, exporter et restaurer sans mélange.
5. Refaire UX05 avec modification concurrente réussie et preuve 409 ; compléter la matrice de rôles et les refus tardifs UX06.
6. TalkBack, texte agrandi, paysage, connexion lente et interruptions OS restent un lot de validation dédié.

La matrice CSV conserve ses résultats automatisés et reçoit des colonnes séparées pour les essais appareil. Les 271 tests Flutter et 24 tests backend mentionnés dans le journal sont les validations antérieures ; ils n’ont pas été relancés pour ces seuls ajouts de documentation et de préparation.
