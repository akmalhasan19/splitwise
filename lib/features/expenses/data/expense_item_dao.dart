/// Data Access Object tabel `expense_items` (skema V2).
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseItemDao {
  const ExpenseItemDao();

  Future<int> insert(DatabaseExecutor db, ExpenseItem item) =>
      db.insert(DbTable.expenseItems, item.toDbMap());

  Future<int> insertAll(DatabaseExecutor db, Iterable<ExpenseItem> items) async {
    var inserted = 0;
    for (final item in items) {
      inserted += await insert(db, item);
    }
    return inserted;
  }

  Future<List<ExpenseItem>> getByExpense(
    DatabaseExecutor db,
    String expenseId,
  ) async {
    final rows = await db.query(
      DbTable.expenseItems,
      where: '${ExpenseItemCol.expenseId} = ?',
      whereArgs: <Object?>[expenseId],
      orderBy: '${ExpenseItemCol.ordering} ASC, ${ExpenseItemCol.id} ASC',
    );
    return rows.map(ExpenseItem.fromDbMap).toList();
  }

  Future<int> deleteByExpense(DatabaseExecutor db, String expenseId) =>
      db.delete(
        DbTable.expenseItems,
        where: '${ExpenseItemCol.expenseId} = ?',
        whereArgs: <Object?>[expenseId],
      );
}