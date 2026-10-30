# F02 — Préserver les modifications locales des membres

## Périmètre défini avant implémentation

Conserver la publication manuelle existante. Comparer, dans la transaction
d'import, chaque champ éditable local au dernier instantané distant enregistré.
Un champ divergent reste local ; les champs inchangés reçoivent la version
distante. Enregistrer ensuite le nouvel instantané distant comme référence.
Champs : nom, surnom, avatar et état actif. Une convergence distante vers la
valeur locale vaut acquittement ; une modification distante ultérieure peut
alors être importée. Préserver la date locale de modification tant qu'un champ
local reste divergent. Aucun changement de schéma ni de contrat HTTP.

Ce correctif ne résout pas les publications concurrentes depuis plusieurs
appareils (le serveur n'a pas de révision d'effectif), ni la suppression locale
d'un membre déjà publié. Ces comportements restent hors périmètre.

## Scénarios et résultats attendus

- MEM01 : renommer, supprimer le surnom et archiver localement ; deux imports
  identiques ne rétablissent aucun de ces champs ni la date locale.
- MEM02 : modifier le nom localement ; un changement distant du surnom et
  d'un autre membre est importé, le nom local reste intact.
- MEM03 : modifier simultanément le même champ côté local et distant ; conserver
  la valeur locale, y compris après un nouvel import du nouvel état distant.
- MEM04 : le serveur confirme la valeur locale publiée ; un changement distant
  ultérieur de ce champ est alors importé (pas de verrou permanent).
- MEM05 : recréer le service sur la même base ; les modifications locales restent
  protégées grâce à la référence persistée, sans état mémoire supplémentaire.
- MEM06 : ajouter un membre local et recevoir un nouveau membre distant ;
  conserver les deux et ne modifier aucun membre d'un autre groupe.
- MEM07 : sans modification locale, importer les changements distants, y compris
  les champs optionnels absents (surnom/avatar nuls, actif par défaut).
- MEM08 : un identifiant distant appartient à un autre groupe ; refuser l'import
  et annuler toutes ses écritures, y compris la nouvelle référence distante.
- MEM09 (complément de revue, avant son test) : modifier l'avatar localement ;
  préserver cette valeur face à un avatar distant concurrent.
- MEM10 (complément de revue, avant son test) : une référence distante omet
  initialement les champs optionnels ; leurs valeurs SQLite par défaut ne doivent
  pas être interprétées comme des modifications locales lors de l'import suivant.
- MEM11 (complément de revue, avant son test) : le client web publie l'état actif
  sous forme booléenne ; normaliser la référence et l'import en 0/1 pour que
  l'archivage et la réactivation distants restent importables sans fausse divergence.

## Validation

- RED initial : 3 succès, 5 échecs comportementaux (MEM01/02/03/05/07),
  `member-sync-red-2026-10-25.txt`. Les valeurs locales étaient remplacées et les
  champs optionnels absents n'étaient pas effacés.
- Complément de revue RED MEM11 : l'import de l'état booléen du client web
  échouait sur un argument SQL `bool`, `member-sync-review-red-2026-10-25.txt`.
  Ce cas utilise un instantané conforme au contrat web réel, pas une fixture
  de schéma manquante ni un échec de compilation.
- GREEN final ciblé : 16 tests réussis (MEM01–MEM11 et 5 tests du service partagé),
  `member-sync-green-2026-10-25.txt`.
- Analyse statique ciblée : aucune erreur ni avertissement, 3 informations
  préexistantes d'ordre des imports, `member-sync-analyze-2026-10-25.txt`.
- Première régression globale : 846 tests réussis en 2 min 54 ; exécution
  commencée avant la fin des compléments de revue. Une exécution finale figée
  est donc exécutée séparément : **847 tests réussis en 2 min 16**, sans échec,
  `member-sync-regression-final-2026-10-25.txt`.
- Revue : `review-member-sync-2026-10-25.md` ; le point de compatibilité découvert
  est corrigé et testé avant la conclusion de revue.

Les tests SQLite ne constituent pas une validation visuelle ou sur téléphone.
