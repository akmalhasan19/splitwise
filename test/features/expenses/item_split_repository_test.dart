import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:debt_splitter/core/models/expense_with_items.dart';
import 'package:debt_splitter/features/expenses/data/expense_repository.dart';
import 'package:debt_splitter/features/groups/data/group_repository.dart';
import 'package:debt_splitter/features/settle_up/net_balance_calculator.dart';
import 'package:debt_splitter/features/users/data/user_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);
  const fixedCreatedAt = 1_700_000_000;

  late AppDatabase db;
  late UserRepository users;
  late GroupRepository groups;
  late ExpenseRepository expenses;
  late String groupId;
  late List<String> m; // id anggota (Andi, Budi, Citra)

  /// Auto-increment counter agar setiap item mendapat ordering unik
  /// (ORDER BY ordering, id → deterministik).
  var nextOrdering = 0;

  setUp(() async {
    db = await openTestDatabase();
    users = UserRepository(db);
    groups = GroupRepository(db);
    expenses = ExpenseRepository(db);
    m = <String>[];
    for (final name in const <String>['Andi', 'Budi', 'Citra']) {
      m.add((await users.createUser(name: name, createdAt: fixedCreatedAt)).id);
    }
    groupId = (await groups.createGroup(
      name: 'RM',
      memberUserIds: m,
      createdAt: fixedCreatedAt,
    )).id;
    nextOrdering = 0;
  });

  tearDown(() async => db.close());

  ExpenseItemWithClaims it(
    int price,
    List<String> claimants, {
    int quantity = 1,
    String name = 'Item',
  }) =>
      ExpenseItemWithClaims(
        item: ExpenseItem(
          id: '',
          name: name,
          unitPrice: price,
          quantity: quantity,
          ordering: nextOrdering++,
        ),
        claimantIds: claimants,
      );

  test(
    'createItemSplitExpense: bagian dihitung otomatis & item/claim tersimpan',
    () async {
      final created = await expenses.createItemSplitExpense(
        groupId: groupId,
        paidBy: m[0],
        date: 1_700_000_100,
        note: 'Makan rm',
        items: [
          it(25_000, [m[0]], name: 'I1'),            // ordering 0
          it(30_000, [m[0], m[1]], name: 'I2'),      // ordering 1
          it(8_000, [m[0]], name: 'I3'),             // ordering 2
          it(8_000, [m[2]], name: 'I4'),             // ordering 3
          it(28_000, [m[1]], name: 'I5'),            // ordering 4
          it(25_000, [m[2]], name: 'I6'),            // ordering 5
          it(10_000, [m[1], m[2]], name: 'I7'),      // ordering 6
          it(20_000, [m[2]], name: 'I8'),            // ordering 7
        ],
      );

      expect(created.expense.splitType, ExpenseSplitType.item);
      expect(created.expense.amount, 154_000);
      expect(created.expense.id.split('-'), hasLength(5)); // UUID v4

      final shares = await expenses.getSharesByExpense(created.expense.id);
      final sum = shares.fold<int>(0, (a, s) => a + s.shareAmount);
      expect(sum, created.expense.amount);
      expect(
        {for (final s in shares) s.userId: s.shareAmount},
        {m[0]: 48_000, m[1]: 48_000, m[2]: 58_000},
      );

      // Item & claim dapat dibaca kembali lengkap — urutan deterministik
      // karena ordering unik (0–7), di-sort ASC oleh DAO.
      final loaded = await expenses.getExpenseWithItems(created.expense.id);
      expect(loaded.items, hasLength(8));
      expect(loaded.items.firstWhere((i) => i.item.name == 'I1').claimantIds, [m[0]]);
      expect(loaded.items.firstWhere((i) => i.item.name == 'I2').claimantIds, containsAll(<String>[m[0], m[1]]));
    },
  );

  test('item dibagi rata antar claimant (berbagi menu)', () async {
    final created = await expenses.createItemSplitExpense(
      groupId: groupId,
      paidBy: m[0],
      date: 1_700_000_200,
      items: [it(30_000, [m[0], m[1], m[2]])],
    );
    expect(created.expense.amount, 30_000);
    final shares = await expenses.getSharesByExpense(created.expense.id);
    expect(
      {for (final s in shares) s.userId: s.shareAmount},
      {m[0]: 10_000, m[1]: 10_000, m[2]: 10_000},
    );
  });

  test('quantity mengalikan nominal baris item', () async {
    final created = await expenses.createItemSplitExpense(
      groupId: groupId,
      paidBy: m[0],
      date: 1_700_000_300,
      items: [it(8_000, [m[0], m[2]], quantity: 2)],
    );
    // 2 Es Teh @ 8.000 = 16.000 dibagi A & C.
    expect(created.expense.amount, 16_000);
  });

  test('net balance tetap konsisten dari shares item (engine tak berubah)', () async {
    await expenses.createItemSplitExpense(
      groupId: groupId,
      paidBy: m[0],
      date: 1_700_000_100,
      items: [
        it(25_000, [m[0]]),
        it(30_000, [m[0], m[1]]),
        it(8_000, [m[0]]),
        it(8_000, [m[2]]),
        it(28_000, [m[1]]),
        it(25_000, [m[2]]),
        it(10_000, [m[1], m[2]]),
        it(20_000, [m[2]]),
      ],
    );
    final withItems = await expenses.getExpenseWithSharesByGroupWithItems(groupId);
    final balances = NetBalanceCalculator.calculateBalances(withItems);
    // Pembayar A: 154.000 - 48.000 = +106.000; B -48.000; C -58.000.
    expect(balances, {m[0]: 106_000, m[1]: -48_000, m[2]: -58_000});
  });

  test('menolak input korup', () async {
    await expectLater(
      expenses.createItemSplitExpense(
        groupId: groupId,
        paidBy: m[0],
        date: 1_700_000_000,
        items: const <ExpenseItemWithClaims>[],
      ),
      throwsArgumentError,
    );

    // Claimant bukan anggota grup.
    await expectLater(
      expenses.createItemSplitExpense(
        groupId: groupId,
        paidBy: m[0],
        date: 1_700_000_000,
        items: [it(1_000, ['u-luar'])],
      ),
      throwsArgumentError,
    );

    // Pembayar bukan anggota grup.
    await expectLater(
      expenses.createItemSplitExpense(
        groupId: groupId,
        paidBy: 'u-luar',
        date: 1_700_000_000,
        items: [it(1_000, [m[0]])],
      ),
      throwsArgumentError,
    );
  });
}