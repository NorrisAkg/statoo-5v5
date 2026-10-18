# Validation de création gestionnaire

Scénarios avant code :
- V01 : identifiant vide ou espaces, mot de passe vide/7 caractères : aucune requête, dialogue ouvert, erreurs françaises sous champs.
- V02 : identifiant nettoyé, mot de passe 8 caractères, membre et rôle sélectionnés : un POST, fermeture après succès seulement.
- V03 : refus 422, 409, panne réseau ou serveur : saisies conservées dans le dialogue, message français sans JSON, possibilité de réessayer.
- V04 : attente : double soumission, annulation et fermeture empêchées ; pas de faux succès si synchronisation échoue après création, pas de second POST.
- V05 : annulation avant envoi : aucun POST ; membre/rôle obligatoires inchangés.
- V06 : cadrage 320/393, texte 100/130/200, clair/sombre et clavier simulé : actions défilantes sans exception ; recette visuelle physique distincte.

Références : design-system, AppTheme, showAppFormDialog, création de compte et modification des rôles, carte collective existante. Travaux préexistants sur génération des accès gestionnaires préservés ; cette correction valide les champs actuellement présents.

Évolution du 18 octobre — génération automatique : V01 ne propose plus de saisie du mot de passe. La validation porte sur l’identifiant ; V02 vérifie un mot de passe généré de 8 caractères, transmis sans champ éditable. V03–V06 restent applicables. Les tests ont été adaptés à ce contrat, en préservant les erreurs dans le formulaire, le réessai et la distinction entre compte créé et mémorisation/actualisation échouées. Résultats finaux : [lot accès gestionnaires](tdd-manager-access-2026-10-17.md).
