/// Data Access Object tabel `users` (Phase 2, Minggu 1 — Task 3).
///
/// Stateless: seluruh method menerima [DatabaseExecutor] sehingga bisa
/// dipakai pada koneksi biasa maupun di dalam transaksi (`Transaction`),
/// menjaga konsistensi multi-tabel.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:sqflite/sqflite.dart';

class UserDao {
  const UserDao();

  Future<User?> getById(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      DbTable.users,
      where: '${UserCol.id} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return User.fromDbMap(rows.single);
  }

  Future<List<User>> getAll(DatabaseExecutor db, {String? nameContains}) async {
    final rows = await db.query(
      DbTable.users,
      where: nameContains == null ? null : '${UserCol.name} LIKE ?',
      whereArgs: nameContains == null ? null : <Object?>['%$nameContains%'],
      orderBy: '${UserCol.name} COLLATE NOCASE ASC, ${UserCol.id} ASC',
    );
    return rows.map(User.fromDbMap).toList();
  }

  Future<int> insert(DatabaseExecutor db, User user) =>
      db.insert(DbTable.users, user.toDbMap());

  Future<int> update(DatabaseExecutor db, User user) => db.update(
    DbTable.users,
    user.toDbMap(),
    where: '${UserCol.id} = ?',
    whereArgs: <Object?>[user.id],
  );

  Future<int> delete(DatabaseExecutor db, String id) => db.delete(
    DbTable.users,
    where: '${UserCol.id} = ?',
    whereArgs: <Object?>[id],
  );

  Future<int> count(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbTable.users}',
    );
    return rows.single['cnt']! as int;
  }
}
