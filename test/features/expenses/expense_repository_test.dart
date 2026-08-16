import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/money/split_calculator.dart';
import 'package:debt_splitter/features/expenses/data/expense_repository.dart';
import 'package:debt_splitter/features/groups/data/group_repository.dart';
import 'package:debt_splitter/features/users/data/user_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  const int fixedCreatedAt = 1_700_000_000;

  late AppDatabase db;
  late UserRepository users;
  late GroupRepository groups;
  late ExpenseRepository expenses;

  late String groupId;
  late List<String> memberIds;

  setUp(() async {
    db = await openTestDatabase();
    users = UserRepository(db);
    groups = GroupRepository(db);
    expenses = ExpenseRepository(db);

    memberIds = <String>[];
    for (final name in const <String>['Andi', 'Budi', 'Citra']) {
      final user = await users.createUser(
        name: name,
        createdAt: fixedCreatedAt,
      );
      memberIds.add(user.id);
    }
    groupId = (await groups.createGroup(
      name: 'Trip Bromo',
      memberUserIds: memberIds,
      createdAt: fixedCreatedAt,
    )).id;
  });

  tearDown(() async {
    await db.close();
  });

  List<ExpenseShare> buildShares(List<int> amounts) => <ExpenseShare>[
    for (var i = 0; i < amounts.length; i++)
      ExpenseShare(
        id: 'share-$i',
        userId: memberIds[i],
        shareAmount: amounts[i],
        // sengaja tanpa expenseId: repository wajib mengisinya sendiri.
      ),
  ];

  int shareSum(List<ExpenseShare> shares) =>
      SplitCalculator.sum(shares.map((share) => share.shareAmount));

  group('ExpenseRepository — CRUD transaksi Expense', () {
    test(
      'createExpense menyimpan expense + shares (expenseId diisi otomatis)',
      () async {
        final expense = await expenses.createExpense(
          groupId: groupId,
          paidBy: memberIds[0],
          amount: 100_000,
          splitType: ExpenseSplitType.equal,
          date: 1_700_000_100,
          note: 'Makan malam',
          shares: buildShares(const <int>[33_334, 33_333, 33_333]),
        );

        expect(expense.id.split('-'), hasLength(5)); // UUID v4
        expect(expense.groupId, groupId);
        expect(expense.paidBy, memberIds[0]);
        expect(expense.amount, 100_000);
        expect(expense.splitType, ExpenseSplitType.equal);
        expect(expense.date, 1_700_000_100);
        expect(expense.note, 'Makan malam');

        final stored = await expenses.getExpenseById(expense.id);
        expect(stored, isNotNull);
        expect(stored!.note, 'Makan malam');

        final shares = await expenses.getSharesByExpense(expense.id);
        expect(shares, hasLength(3));
        expect(shares.every((share) => share.expenseId == expense.id), isTrue);
        expect(shareSum(shares), 100_000);
      },
    );

    test(
      'createEqualSplitExpense: Rp100.000 / 3 = [33.334, 33.333, 33.333]',
      () async {
        final expense = await expenses.createEqualSplitExpense(
          groupId: groupId,
          paidBy: memberIds[0],
          amount: 100_000,
          date: 1_700_000_100,
        );

        final shares = await expenses.getSharesByExpense(expense.id);
        expect(shares, hasLength(3));

        final amounts = shares.map((share) => share.shareAmount).toList()
          ..sort();
        expect(amounts, <int>[33_333, 33_333, 33_334]);
        expect(shareSum(shares), 100_000);
        expect(expense.splitType, ExpenseSplitType.equal);
      },
    );

    test(
      'createExpense menolak sum share != amount (konservasi uang)',
      () async {
        await expectLater(
          expenses.createExpense(
            groupId: groupId,
            paidBy: memberIds[0],
            amount: 100_000,
            splitType: ExpenseSplitType.exact,
            date: 1_700_000_100,
            shares: buildShares(const <int>[50_000, 30_000, 10_000]),
          ),
          throwsArgumentError,
        );
        expect(await expenses.countExpenses(groupId: groupId), 0);
      },
    );

    test('createExpense menolak amount <= 0', () async {
      await expectLater(
        expenses.createExpense(
          groupId: groupId,
          paidBy: memberIds[0],
          amount: 0,
          splitType: ExpenseSplitType.exact,
          date: 1_700_000_100,
          shares: const <ExpenseShare>[],
        ),
        throwsArgumentError,
      );
    });

    test('createExpense menolak pembayar bukan anggota grup', () async {
      final outsider = (await users.createUser(
        name: 'Doni',
        createdAt: fixedCreatedAt,
      )).id;

      await expectLater(
        expenses.createExpense(
          groupId: groupId,
          paidBy: outsider,
          amount: 100_000,
          splitType: ExpenseSplitType.equal,
          date: 1_700_000_100,
          shares: buildShares(const <int>[33_334, 33_333, 33_333]),
        ),
        throwsArgumentError,
      );
    });

    test('createExpense menolak penerima share bukan anggota grup', () async {
      final outsider = (await users.createUser(
        name: 'Doni',
        createdAt: fixedCreatedAt,
      )).id;

      await expectLater(
        expenses.createExpense(
          groupId: groupId,
          paidBy: memberIds[0],
          amount: 100_000,
          splitType: ExpenseSplitType.exact,
          date: 1_700_000_100,
          shares: <ExpenseShare>[
            ExpenseShare(id: 'x-1', userId: memberIds[0], shareAmount: 50_000),
            ExpenseShare(id: 'x-2', userId: outsider, shareAmount: 50_000),
          ],
        ),
        throwsArgumentError,
      );
      expect(await expenses.countExpenses(groupId: groupId), 0);
    });

    test('getExpensesByGroup urut tanggal terbaru dahulu', () async {
      await expenses.createEqualSplitExpense(
        groupId: groupId,
        paidBy: memberIds[0],
        amount: 10_000,
        date: 1_700_000_100,
      );
      await expenses.createEqualSplitExpense(
        groupId: groupId,
        paidBy: memberIds[1],
        amount: 20_000,
        date: 1_700_000_300,
      );
      await expenses.createEqualSplitExpense(
        groupId: groupId,
        paidBy: memberIds[2],
        amount: 30_000,
        date: 1_700_000_200,
      );

      final list = await expenses.getExpensesByGroup(groupId);
      expect(list.map((expense) => expense.amount).toList(), <int>[
        20_000,
        30_000,
        10_000,
      ]);
      expect(await expenses.countExpenses(groupId: groupId), 3);
      expect(await expenses.countExpenses(), 3);
    });

    test(
      'getExpenseWithShares memuat dua-duanya & melempar bila hilang',
      () async {
        final created = await expenses.createEqualSplitExpense(
          groupId: groupId,
          paidBy: memberIds[0],
          amount: 100_000,
          date: 1_700_000_100,
        );

        final detail = await expenses.getExpenseWithShares(created.id);
        expect(detail.expense.id, created.id);
        expect(detail.shares, hasLength(3));

        await expectLater(
          expenses.getExpenseWithShares('e-gak-ada'),
          throwsStateError,
        );
      },
    );

    test(
      'getExpenseWithSharesByGroup menyertakan semua expense + shares',
      () async {
        await expenses.createEqualSplitExpense(
          groupId: groupId,
          paidBy: memberIds[0],
          amount: 60_000,
          date: 1_700_000_100,
        );
        await expenses.createExpense(
          groupId: groupId,
          paidBy: memberIds[1],
          amount: 150_000,
          splitType: ExpenseSplitType.exact,
          date: 1_700_000_200,
          shares: buildShares(const <int>[50_000, 50_000, 50_000]),
        );

        final details = await expenses.getExpenseWithSharesByGroup(groupId);
        expect(details, hasLength(2));
        for (final detail in details) {
          expect(shareSum(detail.shares), detail.expense.amount);
        }
      },
    );

    test('updateExpenseWithShares mengganti shares secara atomik', () async {
      final created = await expenses.createEqualSplitExpense(
        groupId: groupId,
        paidBy: memberIds[0],
        amount: 90_000,
        date: 1_700_000_100,
      );
      expect(await expenses.getSharesByExpense(created.id), hasLength(3));

      final updated = await expenses.updateExpenseWithShares(
        Expense(
          id: created.id,
          groupId: groupId,
          paidBy: memberIds[1],
          amount: 120_000,
          splitType: ExpenseSplitType.exact,
          date: 1_700_000_100,
          note: 'update tagihan',
        ),
        <ExpenseShare>[
          ExpenseShare(id: 'u-1', userId: memberIds[0], shareAmount: 70_000),
          ExpenseShare(id: 'u-2', userId: memberIds[1], shareAmount: 50_000),
        ],
      );

      expect(updated.amount, 120_000);
      expect(updated.paidBy, memberIds[1]);

      final shares = await expenses.getSharesByExpense(created.id);
      expect(shares, hasLength(2));
      expect(shareSum(shares), 120_000);
      final stored = await expenses.getExpenseById(created.id);
      expect(stored, isNotNull);
      expect(stored!.note, 'update tagihan');
    });

    test('updateExpenseWithShares menolak expense tak dikenal', () async {
      await expectLater(
        expenses.updateExpenseWithShares(
          const Expense(
            id: 'e-gak-ada',
            groupId: '',
            paidBy: '',
            amount: 1000,
            splitType: ExpenseSplitType.equal,
            date: 1_700_000_100,
          ),
          const <ExpenseShare>[],
        ),
        throwsStateError,
      );
    });

    test('deleteExpense menghapus expense beserta shares (CASCADE)', () async {
      final created = await expenses.createEqualSplitExpense(
        groupId: groupId,
        paidBy: memberIds[0],
        amount: 100_000,
        date: 1_700_000_100,
      );
      expect(await expenses.getSharesByExpense(created.id), hasLength(3));

      await expenses.deleteExpense(created.id);

      expect(await expenses.getExpenseById(created.id), isNull);
      expect(await expenses.getSharesByExpense(created.id), isEmpty);
      expect(await expenses.countExpenses(groupId: groupId), 0);
    });
  });
}
