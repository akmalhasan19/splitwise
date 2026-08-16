/// Gabungan `Expense` + daftar [ExpenseShare] miliknya.
///
/// Dipakai sebagai unit kerja kalkulasi net-balance (Minggu 2) dan
/// penghitungan saldo per user dalam grup.
library;

import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';

class ExpenseWithShares {
  const ExpenseWithShares({required this.expense, required this.shares});

  final Expense expense;

  /// Seluruh share milik [expense].
  final List<ExpenseShare> shares;
}
