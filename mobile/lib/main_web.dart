import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'main.dart' as application;

/// Same application, routes and processes; only the SQLite driver differs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfiWeb;
  // Expose Flutter semantics to keyboard users and browser accessibility tools.
  WidgetsBinding.instance.ensureSemantics();
  await application.main();
}
