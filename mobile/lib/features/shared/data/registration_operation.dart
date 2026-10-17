import 'dart:math';

import 'package:sqflite/sqflite.dart';

Future<String> registrationOperationId(Database db, String sourceGroup) =>
    db.transaction((txn) async {
      final key = 'registration_operation_$sourceGroup';
      final rows = await txn.query('meta', where: 'key = ?', whereArgs: [key]);
      if (rows.isNotEmpty) return rows.single['value']! as String;
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await txn.insert('meta', {'key': key, 'value': id});
      return id;
    });
