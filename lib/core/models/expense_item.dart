/// Entitas domain — `ExpenseItem` (tabel `expense_items`, skema V2).
///
/// Satu pos item pada bill "Struk" (fitur itemized split). Milik sebuah
/// [Expense]; `unitPrice` bertipe [MoneyAmount] (INTEGER Rupiah utuh).
/// Nominal baris item = `unitPrice * quantity`.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.ordering,
    this.expenseId = '',
  });

  /// UUID v4 — Primary Key tabel `expense_items`.
  final String id;

  /// FK -> `expenses.id` (diisi repository saat insert).
  final String expenseId;

  /// Nama menu/pos (mis. "Nasi Goreng").
  final String name;

  /// Harga per unit (INTEGER Rupiah utuh).
  final MoneyAmount unitPrice;

  /// Jumlah unit pada baris ini (`>= 1`).
  final int quantity;

  /// Urutan tampil pada bill (untuk konservasi urutan list di UI).
  final int ordering;

  factory ExpenseItem.fromDbMap(Map<String, Object?> map) => ExpenseItem(
    id: map[ExpenseItemCol.id] as String,
    expenseId: map[ExpenseItemCol.expenseId] as String,
    name: map[ExpenseItemCol.name] as String,
    unitPrice: map[ExpenseItemCol.unitPrice] as int,
    quantity: map[ExpenseItemCol.quantity] as int,
    ordering: map[ExpenseItemCol.ordering] as int,
  );

  Map<String, Object?> toDbMap() => {
    ExpenseItemCol.id: id,
    ExpenseItemCol.expenseId: expenseId,
    ExpenseItemCol.name: name,
    ExpenseItemCol.unitPrice: unitPrice,
    ExpenseItemCol.quantity: quantity,
    ExpenseItemCol.ordering: ordering,
  };

  /// Salinan item dengan [expenseId] baru (dipakai repository saat insert).
  ExpenseItem withExpenseId(String expenseId) => ExpenseItem(
    id: id,
    name: name,
    unitPrice: unitPrice,
    quantity: quantity,
    ordering: ordering,
    expenseId: expenseId,
  );
}