import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/db/schema_migrator.dart';

Future<int> _countRows(
  Database db,
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final sql =
      'SELECT COUNT(*) AS cnt FROM $table'
      '${where == null ? '' : ' WHERE $where'}';
  final rows = await db.rawQuery(sql, whereArgs);
  return rows.single['cnt']! as int;
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('SchemaMigrator.migrateV1ToV2 — migrasi V1 -> V2', () {
    test(
      'data V1 tetap utuh; tabel V2 hadir; CHECK sekarang menerima ITEM',
      () async {
        final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              for (final statement in createSchemaV1Scripts) {
                await db.execute(statement);
              }
            },
          ),
        );
        addTearDown(v1.close);

        // Isi data lama (persis seperti aplikasi versi V1).
        await v1.insert(DbTable.users, {
          UserCol.id: 'u-1',
          UserCol.name: 'Andi',
          UserCol.avatarColor: '#21A366',
          UserCol.createdAt: 1_700_000_000,
        });
        await v1.insert(DbTable.users, {
          UserCol.id: 'u-2',
          UserCol.name: 'Budi',
          UserCol.avatarColor: '#EF6C00',
          UserCol.createdAt: 1_700_000_000,
        });
        await v1.insert(DbTable.groups, {
          GroupCol.id: 'g-1',
          GroupCol.name: 'Trip Lama',
          GroupCol.defaultCurrency: 'IDR',
          GroupCol.createdAt: 1_700_000_000,
        });
        await v1.insert(DbTable.groupMembers, {
          GroupMemberCol.groupId: 'g-1',
          GroupMemberCol.userId: 'u-1',
        });
        await v1.insert(DbTable.expenses, {
          ExpenseCol.id: 'e-1',
          ExpenseCol.groupId: 'g-1',
          ExpenseCol.paidBy: 'u-1',
          ExpenseCol.amount: 100_000,
          ExpenseCol.splitType: 'EQUAL',
          ExpenseCol.date: 1_700_000_100,
          ExpenseCol.note: null,
        });
        await v1.insert(DbTable.expenseShares, {
          ExpenseShareCol.id: 's-1',
          ExpenseShareCol.expenseId: 'e-1',
          ExpenseShareCol.userId: 'u-1',
          ExpenseShareCol.shareAmount: 50_000,
        });
        await v1.insert(DbTable.expenseShares, {
          ExpenseShareCol.id: 's-2',
          ExpenseShareCol.expenseId: 'e-1',
          ExpenseShareCol.userId: 'u-2',
          ExpenseShareCol.shareAmount: 50_000,
        });

        // Jalankan migrasi pada koneksi yang sama (identik dgn alur onUpgrade).
        await SchemaMigrator.migrateV1ToV2(v1);

        // Data lama tetap utuh (tidak hilang saat migrasi).
        expect(await _countRows(v1, DbTable.users), 2);
        expect(await _countRows(v1, DbTable.groups), 1);
        expect(await _countRows(v1, DbTable.groupMembers), 1);
        expect(await _countRows(v1, DbTable.expenses), 1);
        expect(await _countRows(v1, DbTable.expenseShares), 2);
        final row = await v1.query(
          DbTable.expenses,
          where: '${ExpenseCol.id} = ?',
          whereArgs: <Object?>['e-1'],
        );
        expect(row.single[ExpenseCol.amount], 100_000);

        // CHECK baru menerima ITEM.
        await v1.insert(DbTable.expenses, {
          ExpenseCol.id: 'e-2',
          ExpenseCol.groupId: 'g-1',
          ExpenseCol.paidBy: 'u-1',
          ExpenseCol.amount: 30_000,
          ExpenseCol.splitType: 'ITEM',
          ExpenseCol.date: 1_700_000_200,
          ExpenseCol.note: null,
        });

        // Tabel V2 bisa dipakai menulis item + claim.
        await v1.insert(DbTable.expenseItems, {
          ExpenseItemCol.id: 'it-1',
          ExpenseItemCol.expenseId: 'e-2',
          ExpenseItemCol.name: 'Nasi Goreng',
          ExpenseItemCol.unitPrice: 15_000,
          ExpenseItemCol.quantity: 2,
          ExpenseItemCol.ordering: 0,
        });
        await v1.insert(DbTable.itemClaims, {
          ItemClaimCol.expenseItemId: 'it-1',
          ItemClaimCol.userId: 'u-1',
        });
        expect(await _countRows(v1, DbTable.expenseItems), 1);
        expect(await _countRows(v1, DbTable.itemClaims), 1);
      },
    );
  });
}