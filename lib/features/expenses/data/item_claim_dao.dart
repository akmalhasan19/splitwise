/// Data Access Object tabel `item_claims` (skema V2).
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/item_claim.dart';
import 'package:sqflite/sqflite.dart';

class ItemClaimDao {
  const ItemClaimDao();

  Future<int> insert(DatabaseExecutor db, ItemClaim claim) =>
      db.insert(DbTable.itemClaims, claim.toDbMap());

  Future<int> insertAll(
    DatabaseExecutor db,
    Iterable<ItemClaim> claims,
  ) async {
    var inserted = 0;
    for (final claim in claims) {
      inserted += await insert(db, claim);
    }
    return inserted;
  }

  /// Peta `expenseItemId -> daftar userId` seluruh claim pada [expenseId].
  Future<Map<String, List<String>>> getClaimantsByExpense(
    DatabaseExecutor db,
    String expenseId,
  ) async {
    final rows = await db.rawQuery(
      'SELECT ic.${ItemClaimCol.expenseItemId} AS ei, '
      '       ic.${ItemClaimCol.userId} AS uid '
      'FROM ${DbTable.itemClaims} ic '
      'INNER JOIN ${DbTable.expenseItems} it '
      '  ON it.${ExpenseItemCol.id} = ic.${ItemClaimCol.expenseItemId} '
      'WHERE it.${ExpenseItemCol.expenseId} = ? '
      'ORDER BY ic.${ItemClaimCol.userId} ASC',
      <Object?>[expenseId],
    );
    final result = <String, List<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['ei'] as String, () => <String>[])
          .add(row['uid'] as String);
    }
    return result;
  }

  /// Hapus seluruh claim milik item-item dalam [expenseId] (via subquery).
  Future<int> deleteByExpense(DatabaseExecutor db, String expenseId) =>
      db.delete(
        DbTable.itemClaims,
        where: '${ItemClaimCol.expenseItemId} IN '
            '(SELECT ${ExpenseItemCol.id} FROM ${DbTable.expenseItems} '
            ' WHERE ${ExpenseItemCol.expenseId} = ?)',
        whereArgs: <Object?>[expenseId],
      );
}