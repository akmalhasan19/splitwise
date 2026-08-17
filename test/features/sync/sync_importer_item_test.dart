/// Test integrasi [SyncImporter] untuk expense bertipe ITEM (Skema V2).
///
/// Memverifikasi bahwa:
/// 1. Import payload V2 menyimpan expense_items + item_claims ke DB.
/// 2. Import ulang identik bersifat idempoten.
/// 3. Shares di-derive ulang dari item+claims via ItemBillSplitter, BUKAN
///    dari nilai `sh` di payload — konservasi uang selalu konsisten.
/// 4. Net balance dihitung benar setelah import (engine tak berubah).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_items.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';
import 'package:debt_splitter/features/expenses/data/expense_repository.dart';
import 'package:debt_splitter/features/settle_up/net_balance_calculator.dart';
import 'package:debt_splitter/features/sync/data/sync_importer.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  const int ts = 1_700_000_000;
  const String gId = 'rm-group-1';
  const String eId = 're-item-1';
  const String uA = 'user-a';
  const String uB = 'user-b';
  const String uC = 'user-c';

  late AppDatabase db;
  late ExpenseRepository expenses;
  late SyncImporter importer;

  setUp(() async {
    db = await openTestDatabase();
    expenses = ExpenseRepository(db);
    importer = SyncImporter(db);
  });

  tearDown(() async => db.close());

  // ---------- Factory helpers ----------

  User makeUser(String id, String name) =>
      User(id: id, name: name, avatarColor: '#FF5733', createdAt: ts);

  Group makeGroup() => Group(
    id: gId,
    name: 'Rumah Makan Test',
    defaultCurrency: 'IDR',
    createdAt: ts,
  );

  /// Bill Rp 154.000 (skenario dari informasi.md):
  /// Nasi Goreng 25k → A | Sate 30k → A,B | Es Teh 8k → A | Es Teh 8k → C
  /// Ayam Geprek 28k → B | Mie Ayam 25k → C | Nasi Putih 10k → B,C | Es Jeruk 20k → C
  /// Hasil: A=48k, B=48k, C=58k
  List<ExpenseItemWithClaims> billItems154k() => [
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i1', name: 'Nasi Goreng', unitPrice: 25_000, quantity: 1, ordering: 0),
      claimantIds: [uA],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i2', name: 'Sate', unitPrice: 30_000, quantity: 1, ordering: 1),
      claimantIds: [uA, uB],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i3', name: 'Es Teh A', unitPrice: 8_000, quantity: 1, ordering: 2),
      claimantIds: [uA],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i4', name: 'Es Teh C', unitPrice: 8_000, quantity: 1, ordering: 3),
      claimantIds: [uC],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i5', name: 'Ayam Geprek', unitPrice: 28_000, quantity: 1, ordering: 4),
      claimantIds: [uB],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i6', name: 'Mie Ayam', unitPrice: 25_000, quantity: 1, ordering: 5),
      claimantIds: [uC],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i7', name: 'Nasi Putih', unitPrice: 10_000, quantity: 1, ordering: 6),
      claimantIds: [uB, uC],
    ),
    ExpenseItemWithClaims(
      item: ExpenseItem(id: 'i8', name: 'Es Jeruk', unitPrice: 20_000, quantity: 1, ordering: 7),
      claimantIds: [uC],
    ),
  ];

  /// Payload V2 dengan satu expense ITEM bill Rp 154.000.
  /// [wrongShares]=true: shares di payload SENGAJA salah alokasi — test
  /// memverifikasi importer mengabaikannya dan re-derive dari item+claims.
  GroupSyncPayload makeItemPayload({bool wrongShares = false}) {
    final items = billItems154k();
    final payloadShares = wrongShares
        ? [
            // Alokasi salah tapi sum=154k — harus diabaikan importer.
            ExpenseShare(id: 'ps-a', expenseId: eId, userId: uA, shareAmount: 60_000),
            ExpenseShare(id: 'ps-b', expenseId: eId, userId: uB, shareAmount: 54_000),
            ExpenseShare(id: 'ps-c', expenseId: eId, userId: uC, shareAmount: 40_000),
          ]
        : [
            ExpenseShare(id: 'ps-a', expenseId: eId, userId: uA, shareAmount: 48_000),
            ExpenseShare(id: 'ps-b', expenseId: eId, userId: uB, shareAmount: 48_000),
            ExpenseShare(id: 'ps-c', expenseId: eId, userId: uC, shareAmount: 58_000),
          ];

    return GroupSyncPayload(
      schemaVersion: GroupSyncPayload.currentSchemaVersion,
      exportedAt: ts,
      group: makeGroup(),
      members: [makeUser(uA, 'Andi'), makeUser(uB, 'Budi'), makeUser(uC, 'Citra')],
      expenses: [
        ExpenseWithShares(
          expense: Expense(
            id: eId,
            groupId: gId,
            paidBy: uA,
            amount: 154_000,
            splitType: ExpenseSplitType.item,
            date: ts + 100,
            note: 'Makan Siang RM',
          ),
          shares: payloadShares,
          items: items,
        ),
      ],
    );
  }

  // ---------- Tests ----------

  group('SyncImporter \u2014 expense ITEM V2', () {
    test('import fresh: expense + item/claim tersimpan, shares di-derive dari item', () async {
      final result = await importer.importGroupPayload(makeItemPayload());

      expect(result.expensesAdded, 1);
      expect(result.itemsInserted, 8);
      expect(result.sharesInserted, 3); // A, B, C

      // Shares harus dari ItemBillSplitter (bukan payload).
      final shares = await expenses.getSharesByExpense(eId);
      expect(
        {for (final s in shares) s.userId: s.shareAmount},
        {uA: 48_000, uB: 48_000, uC: 58_000},
        reason: 'Shares harus di-derive dari item+claims (A=48k, B=48k, C=58k)',
      );

      // Item tersimpan lengkap.
      final withItems = await expenses.getExpenseWithItems(eId);
      expect(withItems.items, hasLength(8));
    });

    test('import ulang payload identik bersifat idempoten', () async {
      final payload = makeItemPayload();
      final r1 = await importer.importGroupPayload(payload);
      expect(r1.totalChanges, greaterThan(0));

      // Import ulang — tidak boleh ada perubahan ke DB.
      final r2 = await importer.importGroupPayload(payload);
      expect(
        r2.totalChanges,
        0,
        reason: 'Import ulang payload identik tidak boleh menulis ke DB',
      );
    });

    test('shares di-derive dari item meski payload punya shares yang salah', () async {
      await importer.importGroupPayload(makeItemPayload(wrongShares: true));

      final shares = await expenses.getSharesByExpense(eId);
      expect(
        {for (final s in shares) s.userId: s.shareAmount},
        {uA: 48_000, uB: 48_000, uC: 58_000},
        reason: 'Harus selalu dari ItemBillSplitter, bukan payload',
      );
      // Konservasi: sum(shares) == expense.amount.
      final sum = shares.fold<int>(0, (a, s) => a + s.shareAmount);
      expect(sum, 154_000);
    });

    test('net balance setelah import konsisten dengan engine', () async {
      await importer.importGroupPayload(makeItemPayload());

      final expensesList = await expenses.getExpenseWithSharesByGroup(gId);
      final balances = NetBalanceCalculator.calculateBalances(expensesList);

      // A menalangi 154k, bagiannya 48k → net +106k; B -48k; C -58k.
      expect(balances, {uA: 106_000, uB: -48_000, uC: -58_000});
    });

    test('update expense ITEM: item+shares diperbarui, konservasi terjaga', () async {
      // Import pertama.
      await importer.importGroupPayload(makeItemPayload());

      // Sate naik dari 30k → 40k → total 164k; A=53k, B=53k, C=58k.
      final updatedItems = [
        billItems154k()[0], // Nasi Goreng 25k → A
        ExpenseItemWithClaims(
          item: ExpenseItem(id: 'i2', name: 'Sate', unitPrice: 40_000, quantity: 1, ordering: 1),
          claimantIds: [uA, uB],
        ),
        ...billItems154k().sublist(2), // sisanya sama
      ];
      const newTotal = 164_000;

      final updatedPayload = GroupSyncPayload(
        schemaVersion: GroupSyncPayload.currentSchemaVersion,
        exportedAt: ts + 200,
        group: makeGroup(),
        members: [makeUser(uA, 'Andi'), makeUser(uB, 'Budi'), makeUser(uC, 'Citra')],
        expenses: [
          ExpenseWithShares(
            expense: Expense(
              id: eId,
              groupId: gId,
              paidBy: uA,
              amount: newTotal,
              splitType: ExpenseSplitType.item,
              date: ts + 100,
              note: 'Makan Siang RM',
            ),
            shares: [
              // Shares di payload — akan diabaikan, di-re-derive.
              ExpenseShare(id: 'ps-a', expenseId: eId, userId: uA, shareAmount: 53_000),
              ExpenseShare(id: 'ps-b', expenseId: eId, userId: uB, shareAmount: 53_000),
              ExpenseShare(id: 'ps-c', expenseId: eId, userId: uC, shareAmount: 58_000),
            ],
            items: updatedItems,
          ),
        ],
      );

      final r = await importer.importGroupPayload(updatedPayload);
      expect(r.expensesUpdated, 1);

      final shares = await expenses.getSharesByExpense(eId);
      final shareMap = {for (final s in shares) s.userId: s.shareAmount};
      // Sate 40k dibagi A+B = 20k each. A: 25+20+8=53k, B: 20+28+5=53k, C: 58k.
      expect(shareMap[uA], 53_000);
      expect(shareMap[uB], 53_000);
      expect(shareMap[uC], 58_000);
      expect(
        shareMap.values.fold<int>(0, (a, b) => a + b),
        newTotal,
        reason: 'Konservasi uang harus terjaga setelah update',
      );
    });

    test('round-trip: item + split() dari ExpenseWithItems konsisten dengan DB shares', () async {
      await importer.importGroupPayload(makeItemPayload());

      final withItems = await expenses.getExpenseWithItems(eId);
      expect(withItems.expense.splitType, ExpenseSplitType.item);
      expect(withItems.items, hasLength(8));
      expect(withItems.total(), 154_000);

      // split() dari model harus menghasilkan alokasi yang sama dengan shares di DB.
      final splitResult = withItems.split();
      expect(splitResult, {uA: 48_000, uB: 48_000, uC: 58_000});
    });
  });
}
