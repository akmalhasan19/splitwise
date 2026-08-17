/// Gabungan `Expense` + daftar [ExpenseShare] miliknya.
///
/// Dipakai sebagai unit kerja kalkulasi net-balance (Minggu 2) dan
/// penghitungan saldo per user dalam grup.
library;

import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_items.dart';

class ExpenseWithShares {
  const ExpenseWithShares({
    required this.expense,
    required this.shares,
    this.items = const [],
  });

  final Expense expense;

  /// Seluruh share milik [expense].
  final List<ExpenseShare> shares;

  /// Detail item/claim milik [expense] (skema V2). Kosong untuk expense selain
  /// berjenis `ITEM` atau bila payload versi lama tanpa informasi item.
  final List<ExpenseItemWithClaims> items;
}
