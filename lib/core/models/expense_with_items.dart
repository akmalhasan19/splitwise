/// Gabungan `Expense` + daftar item (beserta claimant-nya) — skema V2.
///
/// Representasi penuh sebuah bill "Struk" sebelum/atau setelah disimpan.
/// Menyediakan konversi murni ke `List<ItemBillLine>` dan kalkulasi pembagian
/// via `ItemBillSplitter` (`ExpenseWithItems.split()`) serta total bill
/// (`ExpenseWithItems.total()`), sehingga konservasi uang selalu teruji.
library;

import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:debt_splitter/core/money/item_bill_splitter.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

/// Sebuah item bill beserta daftar id user yang mengonsumsinya.
class ExpenseItemWithClaims {
  const ExpenseItemWithClaims({
    required this.item,
    required this.claimantIds,
  });

  final ExpenseItem item;

  /// Id user yang makan item ini (boleh lebih dari satu -> dibagi rata).
  final List<String> claimantIds;
}

/// Expense berjenis item/struk lengkap dengan baris item & claimant.
class ExpenseWithItems {
  const ExpenseWithItems({required this.expense, required this.items});

  final Expense expense;

  /// Seluruh baris item beserta claimant-nya, urut `ordering`.
  final List<ExpenseItemWithClaims> items;

  /// Proyeksi murni ke bentuk yang dipahami [ItemBillSplitter].
  List<ItemBillLine> toBillLines() => [
    for (final entry in items)
      ItemBillLine(
        id: entry.item.id,
        unitPrice: entry.item.unitPrice,
        quantity: entry.item.quantity,
        claimantIds: entry.claimantIds,
      ),
  ];

  /// Total nominal seluruh baris = `sum(unitPrice * quantity)`.
  MoneyAmount total() => ItemBillSplitter.totalOf(toBillLines());

  /// Peta `userId -> share` hasil pembagian item/claim.
  Map<String, MoneyAmount> split() => ItemBillSplitter.allocate(toBillLines());
}