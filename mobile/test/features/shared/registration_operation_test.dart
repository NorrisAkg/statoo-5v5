import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/features/shared/data/registration_operation.dart';

void main() {
  test(
    'ENT07/11 operation persists for retries without mixing local groups',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      final first = await registrationOperationId(db, 'local');
      expect(first, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(await registrationOperationId(db, 'local'), first);
      expect(await registrationOperationId(db, 'another'), isNot(first));
      expect(
        (await db.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['registration_operation_local'],
        )).single['value'],
        first,
      );
    },
  );
}
