# Retrait du réglage serveur — 17 octobre 2026

Scénarios écrits avant modification applicative :
- Connexion et partage : aucun bloc Serveur, Connexion à Statoo ou champ Adresse du serveur, ni champ technique caché dans une expansion.
- Conserver les champs métier et les actions Se connecter / Créer le groupe partagé ; clair et sombre, écran étroit.
- Utiliser automatiquement STATOO_API défini à la compilation, avec valeur par défaut existante. Le build web transmet déjà STATOO_PUBLIC_API_URL à STATOO_API.
- Ne pas modifier les identités déjà enregistrées, leurs URL et les mécanismes de synchronisation.

Références : design-system, thème/AppCard, création de groupe et onboarding.

Résultats : deux échecs RED sur le bloc Serveur encore affiché en clair et sombre ; 11 tests GREEN de formulaire, service et transport réussis après correction. Aucune identité persistée modifiée. Le réglage de déploiement reste STATOO_PUBLIC_API_URL (transmis à STATOO_API par le script de build). Recette visuelle distincte des tests automatisés.
Build web release réussi et copié dans l’aperçu 19095 (même origine, données locales conservées). Cet aperçu comprend aussi les trois réflexions implémentées sur la branche courante. Pas de commit ni push.
