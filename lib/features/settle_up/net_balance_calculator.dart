/// Kalkulasi net balance per user dalam grup — Phase 2, Minggu 2, Task 1.
///
/// Formula kontrak (sesuai `implementation_plan.md`):
///
///     net_balance[user] = total_paid - total_share
///
/// * `total_paid`  — seluruh nominal yang dibayarkan oleh user tersebut
///   (kolom `expenses.paid_by`);
/// * `total_share` — seluruh bagian tanggungan user
///   (kolom `expense_shares.share_amount`).
///
/// Modul murni **pure function** dengan aritmatika integer **tanpa
/// `double`/`float`** — konsisten dengan `docs/architecture.md` §Presisi
/// Keuangan, sehingga 100% unit-testable tanpa I/O maupun DB.
library;

import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

class NetBalanceCalculator {
  const NetBalanceCalculator._();

  /// Menghitung peta `userId -> net balance` untuk seluruh [expenses]
  /// dalam sebuah grup.
  ///
  /// Konvensi tanda:
  /// * `> 0` — **kreditur**: user membayar lebih besar dari total
  ///   tanggungannya (berhak menerima uang);
  /// * `< 0` — **debitur**: tanggungan lebih besar daripada yang dia bayar
  ///   (wajib membayar);
  /// * `0`  — netral (posisi hutang-piutangnya tidak berubah).
  ///
  /// User yang sama sekali tidak pernah membayar maupun menerima share tidak
  /// muncul di peta hasil.
  static Map<String, MoneyAmount> calculateBalances(
    Iterable<ExpenseWithShares> expenses,
  ) {
    final totalPaid = <String, MoneyAmount>{};
    final totalShare = <String, MoneyAmount>{};

    for (final item in expenses) {
      final paidBy = item.expense.paidBy;
      totalPaid[paidBy] = (totalPaid[paidBy] ?? 0) + item.expense.amount;

      for (final share in item.shares) {
        totalShare[share.userId] =
            (totalShare[share.userId] ?? 0) + share.shareAmount;
      }
    }

    final balances = <String, MoneyAmount>{};
    for (final userId in {...totalPaid.keys, ...totalShare.keys}) {
      balances[userId] = (totalPaid[userId] ?? 0) - (totalShare[userId] ?? 0);
    }
    return balances;
  }
}