/// Data Access Object tabel `expenses`.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseDao {
  const ExpenseDao();

  Future<Expense?> getById(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      DbTable.expenses,
      where: '${ExpenseCol.id} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Expense.fromDbMap(rows.single);
  }

  Future<List<Expense>> getByGroup(DatabaseExecutor db, String groupId) async {
    final rows = await db.query(
      DbTable.expenses,
      where: '${ExpenseCol.groupId} = ?',
      whereArgs: <Object?>[groupId],
      orderBy: '${ExpenseCol.date} DESC, ${ExpenseCol.id} DESC',
    );
    return rows.map(Expense.fromDbMap).toList();
  }

  Future<List<Expense>> getAll(DatabaseExecutor db) async {
    final rows = await db.query(
      DbTable.expenses,
      orderBy: '${ExpenseCol.date} DESC, ${ExpenseCol.id} DESC',
    );
    return rows.map(Expense.fromDbMap).toList();
  }

  Future<int> insert(DatabaseExecutor db, Expense expense) =>
      db.insert(DbTable.expenses, expense.toDbMap());

  Future<int> update(DatabaseExecutor db, Expense expense) => db.update(
    DbTable.expenses,
    expense.toDbMap(),
    where: '${ExpenseCol.id} = ?',
    whereArgs: <Object?>[expense.id],
  );

  Future<int> delete(DatabaseExecutor db, String id) => db.delete(
    DbTable.expenses,
    where: '${ExpenseCol.id} = ?',
    whereArgs: <Object?>[id],
  );

  Future<int> count(DatabaseExecutor db, {String? groupId}) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbTable.expenses}'
      '${groupId == null ? '' : ' WHERE ${ExpenseCol.groupId} = ?'}',
      groupId == null ? null : <Object?>[groupId],
    );
    return rows.single['cnt']! as int;
  }
}
