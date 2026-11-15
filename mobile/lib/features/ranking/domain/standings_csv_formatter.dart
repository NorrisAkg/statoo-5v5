import 'standing_entry.dart';

/// Formateur de classement au format CSV conforme à la RFC 4180.
///
/// Inclut par défaut le BOM UTF-8 (`\uFEFF`) pour la compatibilité Excel
/// et termine chaque ligne par CRLF (`\r\n`).
class StandingsCsvFormatter {
  const StandingsCsvFormatter({
    this.separator = ';',
    this.includeBom = true,
  });

  final String separator;
  final bool includeBom;

  static const List<String> _headers = [
    'Rang',
    'Nom',
    'Surnom',
    'Points',
    'Matchs Joués',
    'Victoires',
    'Nuls',
    'Défaites',
    'Buts',
    'Passes Décisives',
  ];

  /// Convertit une liste de [StandingEntry] en flux CSV conforme.
  String format(List<StandingEntry> standings) {
    final buffer = StringBuffer();
    if (includeBom) {
      buffer.write('\uFEFF');
    }

    // Ligne d'en-tête
    buffer
      ..write(_formatRow(_headers))
      ..write('\r\n');

    // Lignes de données
    for (final entry in standings) {
      final fields = [
        entry.rank.toString(),
        entry.name,
        entry.nickname ?? '',
        entry.points.toString(),
        entry.matchesPlayed.toString(),
        entry.wins.toString(),
        entry.draws.toString(),
        entry.losses.toString(),
        entry.goals.toString(),
        entry.assists.toString(),
      ];
      buffer
        ..write(_formatRow(fields))
        ..write('\r\n');
    }

    return buffer.toString();
  }

  String _formatRow(List<String> fields) {
    return fields.map(_escapeField).join(separator);
  }

  /// Échappe une cellule selon la RFC 4180 si elle contient le séparateur,
  /// des guillemets doubles, ou des sauts de ligne.
  String _escapeField(String field) {
    final needsQuotes = field.contains(separator) ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r');

    if (!needsQuotes) {
      return field;
    }

    final escaped = field.replaceAll('"', '""');
    return '"$escaped"';
  }
}
