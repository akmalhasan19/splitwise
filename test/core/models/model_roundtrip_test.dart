import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/group_member.dart';
import 'package:debt_splitter/core/models/user.dart';

void main() {
  group('Model round-trip toDbMap -> fromDbMap', () {
    test('User', () {
      const user = User(
        id: 'u-1',
        name: 'Andi',
        avatarColor: '#21A366',
        createdAt: 1_700_000_000,
      );
      final restored = User.fromDbMap(user.toDbMap());
      expect(restored.id, 'u-1');
      expect(restored.name, 'Andi');
      expect(restored.avatarColor, '#21A366');
      expect(restored.createdAt, 1_700_000_000);
    });

    test('Group', () {
      const group = Group(
        id: 'g-1',
        name: 'Trip Bali',
        defaultCurrency: 'IDR',
        createdAt: 1_700_000_001,
      );
      final restored = Group.fromDbMap(group.toDbMap());
      expect(restored.id, 'g-1');
      expect(restored.name, 'Trip Bali');
      expect(restored.defaultCurrency, 'IDR');
      expect(restored.createdAt, 1_700_000_001);
    });

    test('GroupMember', () {
      const member = GroupMember(groupId: 'g-1', userId: 'u-2');
      final restored = GroupMember.fromDbMap(member.toDbMap());
      expect(restored.groupId, 'g-1');
      expect(restored.userId, 'u-2');
    });

    test('Expense (dengan note null & terisi)', () {
      for (final note in <String?>[null, 'Makan malam']) {
        final expense = Expense(
          id: 'e-1',
          groupId: 'g-1',
          paidBy: 'u-1',
          amount: 100_000,
          splitType: ExpenseSplitType.equal,
          date: 1_700_000_002,
          note: note,
        );
        final restored = Expense.fromDbMap(expense.toDbMap());
        expect(restored.id, 'e-1');
        expect(restored.groupId, 'g-1');
        expect(restored.paidBy, 'u-1');
        expect(restored.amount, 100_000);
        expect(restored.splitType, ExpenseSplitType.equal);
        expect(restored.date, 1_700_000_002);
        expect(restored.note, note);
      }
    });

    test('ExpenseShare', () {
      const share = ExpenseShare(
        id: 'es-1',
        expenseId: 'e-1',
        userId: 'u-1',
        shareAmount: 50_000,
      );
      final restored = ExpenseShare.fromDbMap(share.toDbMap());
      expect(restored.id, 'es-1');
      expect(restored.expenseId, 'e-1');
      expect(restored.userId, 'u-1');
      expect(restored.shareAmount, 50_000);
    });

    test('ExpenseShare.withExpenseId menyalin dengan expenseId baru', () {
      const share = ExpenseShare(
        id: 'es-1',
        userId: 'u-1',
        shareAmount: 50_000,
      );
      final owned = share.withExpenseId('e-9');
      expect(owned.id, 'es-1');
      expect(owned.expenseId, 'e-9');
      expect(owned.userId, 'u-1');
      expect(owned.shareAmount, 50_000);
    });
  });

  group('ExpenseSplitType', () {
    test('nilai DB = EQUAL/EXACT/PERCENT (selaras CHECK constraint)', () {
      expect(ExpenseSplitType.values, hasLength(3));
      expect(ExpenseSplitType.equal.dbValue, 'EQUAL');
      expect(ExpenseSplitType.exact.dbValue, 'EXACT');
      expect(ExpenseSplitType.percent.dbValue, 'PERCENT');
    });

    test('fromDbValue round-trip seluruh nilai valid', () {
      for (final type in ExpenseSplitType.values) {
        expect(ExpenseSplitType.fromDbValue(type.dbValue), type);
      }
    });
  });
}
