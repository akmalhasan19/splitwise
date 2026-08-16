/// Entitas domain — `ExpenseShare` (tabel `expense_shares`).
///
/// Satu baris = bagian tanggungan seorang user dalam sebuah expense.
/// `shareAmount` bertipe [MoneyAmount] (`INTEGER`, tanpa `double`/`float`).
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

class ExpenseShare {
  const ExpenseShare({
    required this.id,
    required this.userId,
    required this.shareAmount,
    this.expenseId = '',
  });

  /// UUID v4 — Primary Key tabel `expense_shares`.
  final String id;

  /// FK -> `expenses.id` (diisi oleh repository, lihat
  /// [ExpenseRepository.createExpense]).
  final String expenseId;

  /// FK -> `users.id` (penerima tagihan).
  final String userId;

  /// Bagian nominal (INTEGER, satuan Rupiah).
  final MoneyAmount shareAmount;

  factory ExpenseShare.fromDbMap(Map<String, Object?> map) => ExpenseShare(
    id: map[ExpenseShareCol.id] as String,
    expenseId: map[ExpenseShareCol.expenseId] as String,
    userId: map[ExpenseShareCol.userId] as String,
    shareAmount: map[ExpenseShareCol.shareAmount] as int,
  );

  Map<String, Object?> toDbMap() => {
    ExpenseShareCol.id: id,
    ExpenseShareCol.expenseId: expenseId,
    ExpenseShareCol.userId: userId,
    ExpenseShareCol.shareAmount: shareAmount,
  };

  /// Salinan share dengan [expenseId] baru (dipakai repository saat
  /// membungkus share mentah ke dalam sebuah transaksi expense).
  ExpenseShare withExpenseId(String expenseId) => ExpenseShare(
    id: id,
    expenseId: expenseId,
    userId: userId,
    shareAmount: shareAmount,
  );
}
