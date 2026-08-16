/// Entitas domain — `Expense` (tabel `expenses`).
///
/// Aturan presisi keuangan: `amount` bertipe [MoneyAmount] = `int`
/// (rupiah utuh, tanpa `double`/`float`).
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.amount,
    required this.splitType,
    required this.date,
    this.note,
  });

  /// UUID v4 — Primary Key tabel `expenses`.
  final String id;

  /// FK -> `groups.id`.
  final String groupId;

  /// FK -> `users.id` (siapa yang membayar).
  final String paidBy;

  /// Nominal uang utuh (INTEGER, satuan Rupiah).
  final MoneyAmount amount;

  /// Cara pembagian: EQUAL | EXACT | PERCENT.
  final ExpenseSplitType splitType;

  /// Tanggal transaksi (Unix epoch detik).
  final int date;

  /// Catatan bebas; nullable.
  final String? note;

  factory Expense.fromDbMap(Map<String, Object?> map) => Expense(
    id: map[ExpenseCol.id] as String,
    groupId: map[ExpenseCol.groupId] as String,
    paidBy: map[ExpenseCol.paidBy] as String,
    amount: map[ExpenseCol.amount] as int,
    splitType: ExpenseSplitType.fromDbValue(
      map[ExpenseCol.splitType] as String,
    ),
    date: map[ExpenseCol.date] as int,
    note: map[ExpenseCol.note] as String?,
  );

  Map<String, Object?> toDbMap() => {
    ExpenseCol.id: id,
    ExpenseCol.groupId: groupId,
    ExpenseCol.paidBy: paidBy,
    ExpenseCol.amount: amount,
    ExpenseCol.splitType: splitType.dbValue,
    ExpenseCol.date: date,
    ExpenseCol.note: note,
  };
}
