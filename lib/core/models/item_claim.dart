/// Entitas domain — `ItemClaim` (tabel `item_claims`, skema V2).
///
/// Menghubungkan satu [ExpenseItem] dengan satu [User] yang mengonsumsinya.
/// Satu item dengan banyak claim (lebih dari satu orang) berarti nominal
/// baris item dibagi rata di antara para claimant.
/// Primary Key komposit `(expense_item_id, user_id)`.
library;

import 'package:debt_splitter/core/db/local_schema.dart';

class ItemClaim {
  const ItemClaim({required this.expenseItemId, required this.userId});

  /// FK -> `expense_items.id`.
  final String expenseItemId;

  /// FK -> `users.id` (orang yang makan item ini).
  final String userId;

  factory ItemClaim.fromDbMap(Map<String, Object?> map) => ItemClaim(
    expenseItemId: map[ItemClaimCol.expenseItemId] as String,
    userId: map[ItemClaimCol.userId] as String,
  );

  Map<String, Object?> toDbMap() => {
    ItemClaimCol.expenseItemId: expenseItemId,
    ItemClaimCol.userId: userId,
  };
}