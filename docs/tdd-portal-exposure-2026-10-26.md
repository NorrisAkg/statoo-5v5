# F10 — Ressources publiques du portail

## Scénarios définis avant code applicatif

Le portail historique reste accessible sous /portal/. Seuls ses fichiers publics
explicitement autorisés doivent être servis par l'API ; aucun parcours métier
ni stockage du navigateur n'est modifié.

- PORT01 : GET et HEAD sur un test réel, fixture, script Python de test, prototype,
  README, répertoires de tests/prototypes → 404 sans leur contenu.
- PORT02 : variantes encodées, chemin normalisé et paramètres de requête ne
  contournent pas le refus ; tentative vers backend/app/main.py → 404.
- PORT03 : fichier de développement ajouté ultérieurement, fichier inconnu dans
  icons/fonts/vendor, artefact sous dist/universal-dist → 404 (fixture temporaire).
- PORT04 : index /portal/ et /portal/index.html → 200 HTML identique ; /portal
  redirige vers /portal/. Modules, CSS, manifeste, données publiques, icônes,
  polices et licences nécessaires → GET/HEAD 200 avec MIME adapté et corps HEAD vide.
- PORT05 : toutes les ressources du shell du service worker et les imports locaux
  des modules publics sont accessibles ; aucune ressource de tests n'est requise.
- PORT06 : config.json reste la route dynamique publique, limitée à api_url,
  ignorant les secrets serveur et le contenu du fichier statique.
- PORT07 : ETag/If-None-Match → 304 ; méthode POST sur un fichier public → 405 ;
  ressource absente → 404. Pas de fallback index pour un chemin privé ou inconnu.
- PORT08 : un lien symbolique d'un fichier public vers un fichier extérieur au
  portail reste refusé par la protection StaticFiles (fixture temporaire).
  Un lien vers un fichier privé à l'intérieur du portail doit aussi être refusé,
  aussi bien par /portal/ que par /portal/index.html.
- PORT09 : /health et un refus d'authentification API restent inchangés. Les
  tests de configuration/déploiement et la suite backend servent de régression.

## Résultats et limites

- RED complet avant code : **31 échecs comportementaux, 61 réussites**, en
  1,86 s. Les chemins privés ou liens internes répondaient 200 au lieu de 404.
  [Preuve RED](portal-exposure-red-2026-10-26.txt).
- GREEN ciblé : **98 réussites**, en 2,12 s, dont les 92 cas nouveaux et les
  6 cas existants de configuration/déploiement.
  [Preuve GREEN](portal-exposure-green-2026-10-26.txt).
- Régression du portail : **61 tests Node réussis**, aucun ignoré, en 0,91 s.
  [Preuve Node](portal-exposure-web-2026-10-26.txt).
- Régression backend complète : **406 tests réussis**, en 379,11 s.
  [Preuve complète](portal-exposure-regression-2026-10-26.txt).
- Contrôle final `git diff --check` réussi.
- [Revue distincte](review-portal-exposure-2026-10-26.md) après implémentation :
  aucun défaut bloquant relevé. Aucun commit créé.

Les essais emploient une base SQLite en mémoire et des fichiers temporaires ;
aucun déploiement externe. Les premiers lancements Python/Node en bac à sable
n'ont pas fourni de résultats exploitables ; seules les relances hors bac à
sable sont retenues comme preuves. Un avertissement TestClient/httpx existe.
L'hébergement statique Vercel et les anciens caches déjà installés ne sont pas
modifiés par ce changement du serveur API. Aucun contrôle visuel prévu.
