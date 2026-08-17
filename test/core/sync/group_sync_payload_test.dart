import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';

void main() {
  const sampleGroup = Group(
    id: 'g1',
    name: 'Trip Bromo',
    defaultCurrency: 'IDR',
    createdAt: 1_700_000_000,
  );

  const members = <User>[
    User(id: 'u1', name: 'Andi', avatarColor: '#21A366', createdAt: 1),
    User(id: 'u2', name: 'Budi', avatarColor: '#EF6C00', createdAt: 2),
    User(id: 'u3', name: 'Citra', avatarColor: '#7B1FA2', createdAt: 3),
  ];

  List<ExpenseWithShares> sampleExpenses({String groupId = 'g1'}) {
    return [
      ExpenseWithShares(
        expense: Expense(
          id: 'e1',
          groupId: groupId,
          paidBy: 'u1',
          amount: 100_000,
          splitType: ExpenseSplitType.equal,
          date: 1_700_000_100,
          note: 'Makan malam',
        ),
        shares: const [
          ExpenseShare(id: 's1', expenseId: 'e1', userId: 'u1', shareAmount: 33_334),
          ExpenseShare(id: 's2', expenseId: 'e1', userId: 'u2', shareAmount: 33_333),
          ExpenseShare(id: 's3', expenseId: 'e1', userId: 'u3', shareAmount: 33_333),
        ],
      ),
      ExpenseWithShares(
        expense: Expense(
          id: 'e2',
          groupId: groupId,
          paidBy: 'u2',
          amount: 50_000,
          splitType: ExpenseSplitType.exact,
          date: 1_700_000_200,
          note: null,
        ),
        shares: const [
          ExpenseShare(id: 's4', expenseId: 'e2', userId: 'u1', shareAmount: 50_000),
        ],
      ),
    ];
  }

  GroupSyncPayload buildPayload({
    Group g = sampleGroup,
    List<User> m = members,
    List<ExpenseWithShares>? e,
  }) {
    return GroupSyncPayload(
      schemaVersion: GroupSyncPayload.currentSchemaVersion,
      exportedAt: 1_700_000_500,
      group: g,
      members: m,
      expenses: e ?? sampleExpenses(),
    );
  }

  group('GroupSyncPayload.toJson/fromJson — roundtrip', () {
    test('payload lengkap (grup + anggota + transaksi) lolos roundtrip', () {
      final payload = buildPayload();
      final decoded = GroupSyncPayload.fromJson(payload.toJson());

      expect(decoded.schemaVersion, GroupSyncPayload.currentSchemaVersion);
      expect(decoded.exportedAt, 1_700_000_500);
      expect(decoded.group.id, 'g1');
      expect(decoded.group.name, 'Trip Bromo');
      expect(decoded.group.defaultCurrency, 'IDR');
      expect(decoded.members, hasLength(3));
      expect(decoded.members.map((u) => u.name).toList(), contains('Citra'));
      expect(decoded.expenses, hasLength(2));

      final first = decoded.expenses.first;
      expect(first.expense.amount, 100_000);
      expect(first.expense.splitType, ExpenseSplitType.equal);
      expect(first.expense.note, 'Makan malam');
      expect(first.shares, hasLength(3));
      // Konservasi uang tetap terjaga setelah serialisasi.
      var sum = 0;
      for (final share in first.shares) {
        sum += share.shareAmount;
      }
      expect(sum, first.expense.amount);

      final second = decoded.expenses[1];
      expect(second.expense.note, isNull);
      expect(second.expense.splitType, ExpenseSplitType.exact);
    });

    test('expense tanpa anggota bisa roundtrip (daftar kosong)', () {
      final payload = buildPayload(e: const <ExpenseWithShares>[]);
      final decoded = GroupSyncPayload.fromJson(payload.toJson());
      expect(decoded.expenses, isEmpty);
    });

    test('serialisasi ringkas: key pendek & note null dihilangkan', () {
      final json = buildPayload().toJson();
      expect(json['t'], 'DS1');
      expect(json['v'], 1);
      expect(json.containsKey('x'), isTrue);

      final groupJson = json['g']! as Map<String, Object?>;
      expect(groupJson.keys.toSet(), {'id', 'n', 'c', 'ca'});

      final expenses = json['e']! as List<Object?>;
      final second = expenses[1]! as Map<String, Object?>;
      // note null dihilangkan agar payload ringkas.
      expect(second.containsKey('n'), isFalse);
    });
  });

  group('GroupSyncPayload.fromJson — validasi', () {
    test('menolak marker tipe yang salah', () {
      final json = buildPayload().toJson()..['t'] = 'XXX';
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak schemaVersion lebih baru dari dukungan', () {
      final json = buildPayload().toJson()..['v'] = 99;
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak tanpa anggota', () {
      final json = buildPayload(m: const <User>[]).toJson();
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak expense milik grup lain', () {
      final json = buildPayload(e: sampleExpenses(groupId: 'g-lain')).toJson();
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak pembayar yang bukan anggota', () {
      final bad = sampleExpenses();
      final e1 = bad.first.expense;
      bad[0] = ExpenseWithShares(
        expense: Expense(
          id: e1.id,
          groupId: e1.groupId,
          paidBy: 'u-999',
          amount: e1.amount,
          splitType: e1.splitType,
          date: e1.date,
          note: e1.note,
        ),
        shares: bad.first.shares,
      );
      final json = buildPayload(e: bad).toJson();
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak konservasi uang yang dilanggar (sum share != amount)', () {
      final bad = sampleExpenses();
      final first = bad.first;
      final brokenShares = [
        for (final s in first.shares)
          ExpenseShare(
            id: s.id,
            expenseId: s.expenseId,
            userId: s.userId,
            shareAmount: 1, // total jadi 3, bukan 100_000
          ),
      ];
      bad[0] = ExpenseWithShares(
        expense: first.expense,
        shares: brokenShares,
      );
      final json = buildPayload(e: bad).toJson();
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak penerima share yang bukan anggota', () {
      final bad = sampleExpenses();
      final first = bad.first;
      bad[0] = ExpenseWithShares(
        expense: first.expense,
        shares: [
          for (final s in first.shares)
            ExpenseShare(
              id: s.id,
              expenseId: s.expenseId,
              userId: s.userId == 'u1' ? 'u-999' : s.userId,
              shareAmount: s.shareAmount,
            ),
        ],
      );
      final json = buildPayload(e: bad).toJson();
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak expense tanpa share', () {
      final bad = sampleExpenses();
      bad[0] = ExpenseWithShares(
        expense: bad.first.expense,
        shares: const <ExpenseShare>[],
      );
      final json = buildPayload(e: bad).toJson();
      expect(
        () => GroupSyncPayload.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
