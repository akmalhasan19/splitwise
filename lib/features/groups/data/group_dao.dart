/// Data Access Object tabel `groups`.
///
/// Stateless seperti seluruh DAO lain: menerima [DatabaseExecutor] sehingga
/// aman dipakai di dalam transaksi.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:sqflite/sqflite.dart';

class GroupDao {
  const GroupDao();

  Future<Group?> getById(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      DbTable.groups,
      where: '${GroupCol.id} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Group.fromDbMap(rows.single);
  }

  Future<List<Group>> getAll(
    DatabaseExecutor db, {
    String? nameContains,
  }) async {
    final rows = await db.query(
      DbTable.groups,
      where: nameContains == null ? null : '${GroupCol.name} LIKE ?',
      whereArgs: nameContains == null ? null : <Object?>['%$nameContains%'],
      orderBy: '${GroupCol.name} COLLATE NOCASE ASC, ${GroupCol.id} ASC',
    );
    return rows.map(Group.fromDbMap).toList();
  }

  Future<int> insert(DatabaseExecutor db, Group group) =>
      db.insert(DbTable.groups, group.toDbMap());

  Future<int> update(DatabaseExecutor db, Group group) => db.update(
    DbTable.groups,
    group.toDbMap(),
    where: '${GroupCol.id} = ?',
    whereArgs: <Object?>[group.id],
  );

  Future<int> delete(DatabaseExecutor db, String id) => db.delete(
    DbTable.groups,
    where: '${GroupCol.id} = ?',
    whereArgs: <Object?>[id],
  );

  Future<int> count(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbTable.groups}',
    );
    return rows.single['cnt']! as int;
  }
}
