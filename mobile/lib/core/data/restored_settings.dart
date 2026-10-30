import 'package:sqflite/sqflite.dart';

/// Local marker: an empty restored database must not migrate legacy teams again.
const restoredDatabaseKey = '_restore_completed';
const restoredMinimumKey = 'min_players_per_session';

Future<bool> hasRestoredDatabase(DatabaseExecutor db) async => (await db.query(
  'meta',
  columns: ['key'],
  where: 'key = ?',
  whereArgs: [restoredDatabaseKey],
  limit: 1,
)).isNotEmpty;
