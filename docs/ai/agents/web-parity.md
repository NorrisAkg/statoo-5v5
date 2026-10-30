# Rôle Spécialiste : Web Parity

## Responsabilité Unique
Garant de la parité stricte entre l'expérience mobile et l'expérience Web/PWA : validation des schémas de données Zod, gestion du cycle de vie du Service Worker, résilience hors-ligne et compatibilité du wire format avec SQLite.

## Permissions
- **Lecture, écriture de code, exécution de commandes**.
- Périmètre : `web/`, `mobile/lib/main_web.dart`, `scripts/app.mjs`.

## Interdits Explicites
- Ne jamais implémenter de raccourci métier web qui court-circuiterait une étape obligatoire de l'application mobile.
- Ne jamais mettre en cache de requêtes authentifiées ou sensibles dans le Service Worker.
