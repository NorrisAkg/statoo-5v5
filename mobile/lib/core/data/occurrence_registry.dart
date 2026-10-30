import 'package:sqflite/sqflite.dart';

/// Calcule la prochaine référence d'occurrence libre pour le groupe et la date donnés,
/// sans entrer en collision avec les séances ou échéances existantes.
Future<String> nextFreeOccurrenceReference(
  DatabaseExecutor db,
  String group,
  DateTime date,
) async {
  final prefix = 'shared_finance_alias_${group}_';
  final aliases = await db.query(
    'meta',
    where: 'substr(key,1,?) = ?',
    whereArgs: [prefix.length, prefix],
  );
  final existing = await db.rawQuery(
    'SELECT m.value FROM meta m JOIN sessions s ON m.key = ? || s.id WHERE s.team_id = ?',
    ['shared_occurrence_', group],
  );
  final used = <String>{
    ...aliases.map((r) => (r['key']! as String).substring(prefix.length)),
    ...existing.map((r) => r['value']! as String),
  };
  final day = date.toIso8601String().substring(0, 10);
  var number = 1;
  while (used.contains('$day-$number')) {
    number++;
  }
  return '$day-$number';
}

/// À appeler dans la transaction qui crée l'objet ou prend en charge un ancien
/// objet : référence et alias sont réservés ensemble, sans course entre lectures.
Future<({String reference, String canonicalId})> reserveOccurrence(
  DatabaseExecutor db,
  String group,
  String session,
  DateTime date,
) async {
  final rows = await db.query(
    'meta',
    where: 'key = ?',
    whereArgs: ['shared_occurrence_$session'],
  );
  String reference;
  final prefix = 'shared_finance_alias_${group}_';
  if (rows.isNotEmpty) {
    reference = rows.single['value']! as String;
  } else {
    reference = await nextFreeOccurrenceReference(db, group, date);
    await db.insert('meta', {
      'key': 'shared_occurrence_$session',
      'value': reference,
    });
  }
  final aliasKey = '$prefix$reference';
  final alias = await db.query('meta', where: 'key = ?', whereArgs: [aliasKey]);
  final id = alias.isEmpty ? session : alias.single['value']! as String;
  if (alias.isEmpty) await db.insert('meta', {'key': aliasKey, 'value': id});
  return (reference: reference, canonicalId: id);
}
