/// Unit test `NetBalanceCalculator.calculateBalances` — Phase 2, Minggu 2.
///
/// Kasus yang dicakup: formula `net = total_paid - total_share`, akumulasi
/// multi-expense, pembayar yang juga penerima share, user dengan balance 0,
/// input kosong, serta properti konservasi uang (`sum(balance) == 0`).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/features/settle_up/net_balance_calculator.dart';

/// Helper: satu `ExpenseWithShares` ringkas dari `paidBy`, `amount`, dan peta
/// `userId -> shareAmount`.
ExpenseWithShares _expense({
  required String id,
  required String paidBy,
  required int amount,
  required Map<String, int> shares,
}) {
  return ExpenseWithShares(
    expense: Expense(
      id: id,
      groupId: 'g-1',
      paidBy: paidBy,
      amount: amount,
      splitType: ExpenseSplitType.exact,
      date: 1_700_000_000,
    ),
    shares: [
      for (final share in shares.entries)
        ExpenseShare(
          id: '$id-${share.key}',
          userId: share.key,
          shareAmount: share.value,
        ),
    ],
  );
}

void main() {
  group('NetBalanceCalculator.calculateBalances', () {
    test('kreditur: net = totalPaid - totalShare (sisa ganjil equal split)', () {
      // Rp100.000 / 3 -> [33.334, 33.333, 33.333]; pembayar adalah A sendiri.
      final balances = NetBalanceCalculator.calculateBalances([
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 100_000,
          shares: {'A': 33_334, 'B': 33_333, 'C': 33_333},
        ),
      ]);

      expect(balances, {'A': 66_666, 'B': -33_333, 'C': -33_333});
    });

    test('akumulasi beberapa expense (paid & share dijumlah per user)', () {
      final balances = NetBalanceCalculator.calculateBalances([
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 100_000,
          shares: {'B': 100_000},
        ),
        _expense(
          id: 'e2',
          paidBy: 'B',
          amount: 60_000,
          shares: {'C': 60_000},
        ),
      ]);

      // A: +100.000, B: -100.000 + 60.000 = -40.000, C: -60.000.
      expect(balances, {'A': 100_000, 'B': -40_000, 'C': -60_000});
    });

    test('pembayar yang juga menjadi penerima share dihitung bersih', () {
      final balances = NetBalanceCalculator.calculateBalances([
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 100_000,
          shares: {'A': 40_000, 'B': 60_000},
        ),
      ]);

      expect(balances, {'A': 60_000, 'B': -60_000});
    });

    test('user netral (paid == share) tetap muncul dengan balance 0', () {
      final balances = NetBalanceCalculator.calculateBalances([
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 100_000,
          shares: {'A': 100_000},
        ),
      ]);

      expect(balances, {'A': 0});
    });

    test('user hanya dicatat sebagai pembayar, bukan penerima share', () {
      final balances = NetBalanceCalculator.calculateBalances([
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 50_000,
          shares: {'B': 50_000},
        ),
      ]);

      expect(balances, {'A': 50_000, 'B': -50_000});
    });

    test('list expense kosong -> peta kosong', () {
      expect(NetBalanceCalculator.calculateBalances([]), isEmpty);
    });

    test('properti konservasi: sum seluruh balance == 0', () {
      final expenses = [
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 250_000,
          shares: {'A': 100_000, 'B': 150_000},
        ),
        _expense(
          id: 'e2',
          paidBy: 'B',
          amount: 120_000,
          shares: {'B': 10_000, 'C': 110_000},
        ),
        _expense(
          id: 'e3',
          paidBy: 'C',
          amount: 77_000,
          shares: {'A': 40_000, 'B': 37_000},
        ),
      ];

      final balances = NetBalanceCalculator.calculateBalances(expenses);
      final total = balances.values.fold<int>(0, (acc, value) => acc + value);
      expect(total, 0);
    });

    test('split type (EQUAL/EXACT/PERCENT) tidak memengaruhi formula net', () {
      for (final splitType in ExpenseSplitType.values) {
        final balances = NetBalanceCalculator.calculateBalances([
          ExpenseWithShares(
            expense: Expense(
              id: 'e-type',
              groupId: 'g-1',
              paidBy: 'A',
              amount: 100_000,
              splitType: splitType,
              date: 1_700_000_000,
            ),
            shares: [
              ExpenseShare(id: 's1', userId: 'A', shareAmount: 40_000),
              ExpenseShare(id: 's2', userId: 'B', shareAmount: 60_000),
            ],
          ),
        ]);

        expect(
          balances,
          {'A': 60_000, 'B': -60_000},
          reason: 'splitType=$splitType',
        );
      }
    });
  });
}