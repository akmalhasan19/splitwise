/// Migrasi skema SQLite secara eksplisit & testable (phase yang sama dengan
/// `AppDatabase` tetapi dapat dipanggil langsung terhadap [Database] apa pun,
/// khususnya pada koneksi yang baru dibangun sebagai V1).
///
/// Kebutuhan: database yang diberikan masih memakai **skema V1**
/// (pakai [createSchemaV1Scripts]). Setelah dipanggil, database menjadi
/// **skema V2**: tabel `expense_items` & `item_claims` hadir, dan CHECK
/// `expenses.split_type` memuat `'ITEM'`.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:sqflite/sqflite.dart';

class SchemaMigrator {
  const SchemaMigrator._();

  /// Migrasi V1 -> V2:
  /// 1. Recreate tabel `expenses` (CHECK split_type diperluas dengan `ITEM`)
  ///    memakai jalan "tabel sementara + copy + rename" — SQLite tidak bisa
  ///    mengubah constraint CHECK via ALTER;
  /// 2. Buat tabel baru `expense_items` & `item_claims`.
  ///
  /// `PRAGMA foreign_keys` dimatikan sementara di luar transaksi (pragma
  /// bersifat no-op di dalam transaksi) agar `DROP TABLE expenses` diizinkan
  /// walau `expense_shares` mereferensinya. Setelah selesai, aktifkan lagi.
  static Future<void> migrateV1ToV2(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF;');
    await db.transaction((txn) async {
      // 1a. Tabel expenses versi baru (CHECK memuat 'ITEM').
      await txn.execute(createSchemaV2ExpenseTableScript);
      // 1b. Salin seluruh data lama agar tidak hilang.
      await txn.execute(
        'INSERT INTO expenses_v2 '
        '(id, group_id, paid_by, amount, split_type, date, note) '
        'SELECT id, group_id, paid_by, amount, split_type, date, note '
        'FROM expenses',
      );
      // 1c. Ganti tabel lama dengan yang baru.
      await txn.execute('DROP TABLE expenses');
      await txn.execute('ALTER TABLE expenses_v2 RENAME TO expenses');
      // 2) Tabel baru skema V2.
      for (final statement in createSchemaV2Scripts) {
        await txn.execute(statement);
      }
    });
    await db.execute('PRAGMA foreign_keys = ON;');
  }
}