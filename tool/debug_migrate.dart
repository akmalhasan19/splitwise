// ignore_for_file: avoid_print
import 'dart:io';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  final dir = await Directory.systemTemp.createTemp('ds_debug_migrate');
  final dbPath = '${dir.path}/db_v1.sqlite';

  final factory = databaseFactoryFfiNoIsolate;
  final v1 = await factory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        for (final s in createSchemaV1Scripts) {
          await db.execute(s);
        }
      },
    ),
  );
  print('v1 opened, user_version before insert');
  await v1.insert(DbTable.users, {
    UserCol.id: 'u-1',
    UserCol.name: 'Andi',
    UserCol.avatarColor: '#21A366',
    UserCol.createdAt: 1_700_000_000,
  });
  final rows = await v1.rawQuery('SELECT COUNT(*) AS c FROM users');
  print('v1 user count: ${rows.single['c']}');
  print('v1 user_version: ${await v1.getVersion()}');
  await v1.close();

  final app = await AppDatabase.open(
    databasePath: dbPath,
    factory: factory,
    forceNew: true,
  );
  print('app opened user_version: ${await app.db.getVersion()}');
  final after = await app.db.rawQuery('SELECT COUNT(*) AS c FROM users');
  print('after migration user count: ${after.single['c']}');
  final tables = await app.db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_sqlite_%'",
  );
  print('tables: ${tables.map((r) => r['name']).toList()}');
  await app.close();
  print('closed ok');
}