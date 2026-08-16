/// Data Access Object tabel `expense_shares`.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseShareDao {
  const ExpenseShareDao();

  Future<int> insert(DatabaseExecutor db, ExpenseShare share) =>
      db.insert(DbTable.expenseShares, share.toDbMap());

  Future<int> insertAll(
    DatabaseExecutor db,
    Iterable<ExpenseShare> shares,
  ) async {
    var inserted = 0;
    for (final share in shares) {
      inserted += await insert(db, share);
    }
    return inserted;
  }

  Future<List<ExpenseShare>> getByExpense(
    DatabaseExecutor db,
    String expenseId,
  ) async {
    final rows = await db.query(
      DbTable.expenseShares,
      where: '${ExpenseShareCol.expenseId} = ?',
      whereArgs: <Object?>[expenseId],
      orderBy: '${ExpenseShareCol.userId} ASC',
    );
    return rows.map(ExpenseShare.fromDbMap).toList();
  }

  Future<List<ExpenseShare>> getByGroup(
    DatabaseExecutor db,
    String groupId,
  ) async {
    final rows = await db.rawQuery(
      'SELECT es.* FROM ${DbTable.expenseShares} es '
      'INNER JOIN ${DbTable.expenses} e '
      '  ON e.${ExpenseCol.id} = es.${ExpenseShareCol.expenseId} '
      'WHERE e.${ExpenseCol.groupId} = ? '
      'ORDER BY e.${ExpenseCol.date} DESC, es.${ExpenseShareCol.userId} ASC',
      <Object?>[groupId],
    );
    return rows.map(ExpenseShare.fromDbMap).toList();
  }

  Future<int> deleteByExpense(DatabaseExecutor db, String expenseId) =>
      db.delete(
        DbTable.expenseShares,
        where: '${ExpenseShareCol.expenseId} = ?',
        whereArgs: <Object?>[expenseId],
      );

  Future<int> countByExpense(DatabaseExecutor db, String expenseId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbTable.expenseShares} '
      'WHERE ${ExpenseShareCol.expenseId} = ?',
      <Object?>[expenseId],
    );
    return rows.single['cnt']! as int;
  }
}
