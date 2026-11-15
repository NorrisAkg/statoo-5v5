// Espaces, plus l'espace de largeur nulle et le BOM, fréquents dans un
// copier-coller depuis une messagerie.
final _spaces = RegExp('[\\s\u200b\ufeff]+');
final _serverDigits = RegExp(r'^[0-9]{8}$');

/// UX-003 : identifiant de groupe tel que saisi par un membre. Les espaces sont
/// ignorés et le « # » est facultatif devant les 8 chiffres attribués par le
/// serveur. Les autres formats (groupes historiques) sont laissés tels quels.
///
/// L'API applique la même règle (`group_id_candidates`, `backend/app/main.py`),
/// mais essaie d'abord la saisie exacte : un groupe historique nommé par
/// 8 chiffres sans « # » n'est joignable que par le portail. Aucun n'existe :
/// avant le 15/10/2026, les identifiants étaient de la forme `team_<horodatage>`.
String normalizeGroupId(String raw) {
  final typed = raw.replaceAll(_spaces, '');
  return _serverDigits.hasMatch(typed) ? '#$typed' : typed;
}
