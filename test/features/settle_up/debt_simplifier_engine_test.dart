/// Unit test `DebtSimplifierEngine.settle` — Phase 2, Minggu 2, Task 3.
///
/// Menjamin **100% coverage** modul core logic + edge cases keuangan:
/// * Kasus wajib 1: transaksi melingkar 3+ orang (A -> B -> C -> A);
/// * Kasus wajib 2: penanganan sisa ganjil pembulatan equal split;
/// * Kasus wajib 3: satu orang membayarkan seluruh transaksi grup;
/// * edge cases: input kosong, saldo netral, tie-break deterministik,
///   kreditur/debitur multipel, serta properti konservasi (total 0 & jejak
///   pembayaran selalu menutup seluruh saldo).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/money/split_calculator.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';
import 'package:debt_splitter/features/settle_up/net_balance_calculator.dart';

/// Helper: membangun `ExpenseWithShares` dari data mentah expense.
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

/// Memverifikasi jejak pembayaran: bila seluruh pembayaran diterapkan ulang ke
/// saldo awal, semua saldo harus kembali nol.
void _assertPaymentsClearAll(
  Map<String, int> netBalances,
  List<SettlementPayment> payments,
) {
  final residual = Map<String, int>.from(netBalances);
  for (final payment in payments) {
    residual[payment.debtorId] =
        (residual[payment.debtorId] ?? 0) + payment.amount;
    residual[payment.creditorId] =
        (residual[payment.creditorId] ?? 0) - payment.amount;
  }
  for (final balance in residual.values) {
    expect(balance, 0, reason: 'Seluruh saldo harus tuntas: $residual');
  }
}

void main() {
  group('DebtSimplifierEngine — Kasus Wajib 1: Transaksi melingkar 3+ orang', () {
    test('lingkaran penuh A->B->C->A saling meniadakan -> tidak ada transfer', () {
      // A berutang ke B, B berutang ke C, C berutang ke A — semua senilai sama.
      final expenses = [
        _expense(id: 'e1', paidBy: 'B', amount: 30_000, shares: {'A': 30_000}),
        _expense(id: 'e2', paidBy: 'C', amount: 30_000, shares: {'B': 30_000}),
        _expense(id: 'e3', paidBy: 'A', amount: 30_000, shares: {'C': 30_000}),
      ];
      final balances = NetBalanceCalculator.calculateBalances(expenses);

      expect(balances, {'A': 0, 'B': 0, 'C': 0});
      expect(DebtSimplifierEngine.settle(balances), isEmpty);
    });

    test('lingkaran + sisa utang: disederhanakan dari 3 transfer menjadi 2', () {
      // A mengutang B 50.000, B mengutang C 30.000, C mengutang A 20.000.
      final expenses = [
        _expense(id: 'e1', paidBy: 'B', amount: 50_000, shares: {'A': 50_000}),
        _expense(id: 'e2', paidBy: 'C', amount: 30_000, shares: {'B': 30_000}),
        _expense(id: 'e3', paidBy: 'A', amount: 20_000, shares: {'C': 20_000}),
      ];
      final balances = NetBalanceCalculator.calculateBalances(expenses);
      // net: A -30.000, B +20.000, C +10.000.

      final payments = DebtSimplifierEngine.settle(balances);

      expect(payments, <SettlementPayment>[
        const SettlementPayment(debtorId: 'A', creditorId: 'B', amount: 20_000),
        const SettlementPayment(debtorId: 'A', creditorId: 'C', amount: 10_000),
      ]);
      _assertPaymentsClearAll(balances, payments);
    });
  });

  group('DebtSimplifierEngine — Kasus Wajib 2: Sisa ganjil equal split', () {
    test('Rp100.000 / 3 -> sisa 1 rupiah masuk share pembayar (A +66.666)', () {
      final members = const ['A', 'B', 'C'];
      final amounts = SplitCalculator.equalSplit(100_000, members.length);
      final shares = <String, int>{
        for (var i = 0; i < members.length; i++) members[i]: amounts[i],
      };
      final expenses = [
        _expense(id: 'e1', paidBy: 'A', amount: 100_000, shares: shares),
      ];
      final balances = NetBalanceCalculator.calculateBalances(expenses);

      // A menerima 66.666 (bukan 66.667), B & C masing-masing membayar 33.333.
      expect(DebtSimplifierEngine.settle(balances), <SettlementPayment>[
        const SettlementPayment(debtorId: 'B', creditorId: 'A', amount: 33_333),
        const SettlementPayment(debtorId: 'C', creditorId: 'A', amount: 33_333),
      ]);
    });

    test('pembayar murni (tanpa share) tanpa sisa pembulatan', () {
      // A menalangi 100.000 untuk B & C: Rp50.000 + Rp50.000 habis tanpa sisa.
      final expenses = [
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 100_000,
          shares: {'B': 50_000, 'C': 50_000},
        ),
      ];
      final balances = NetBalanceCalculator.calculateBalances(expenses);

      expect(DebtSimplifierEngine.settle(balances), <SettlementPayment>[
        const SettlementPayment(debtorId: 'B', creditorId: 'A', amount: 50_000),
        const SettlementPayment(debtorId: 'C', creditorId: 'A', amount: 50_000),
      ]);
    });
  });

  group('DebtSimplifierEngine — Kasus Wajib 3: 1 orang membayar semua', () {
    test('A membayar seluruh transaksi grup -> B/C mengangsur ke A', () {
      final expenses = [
        _expense(
          id: 'e1',
          paidBy: 'A',
          amount: 60_000,
          shares: {'B': 40_000, 'C': 20_000},
        ),
        _expense(
          id: 'e2',
          paidBy: 'A',
          amount: 24_000,
          shares: {'C': 24_000},
        ),
      ];
      final balances = NetBalanceCalculator.calculateBalances(expenses);

      final settlements = DebtSimplifierEngine.settle(balances);

      expect(settlements, <SettlementPayment>[
        const SettlementPayment(debtorId: 'B', creditorId: 'A', amount: 40_000),
        const SettlementPayment(debtorId: 'C', creditorId: 'A', amount: 44_000),
      ]);
      _assertPaymentsClearAll(balances, settlements);
    });
  });

  group('Edge cases kalkulasi keuangan', () {
    test('peta kosong -> tidak ada rekomendasi', () {
      expect(DebtSimplifierEngine.settle({}), isEmpty);
    });

    test('seluruh saldo nol -> tidak ada rekomendasi', () {
      expect(DebtSimplifierEngine.settle({'A': 0, 'B': 0}), isEmpty);
    });

    test('satu lawan satu: debitur -> kreditur tepat habis', () {
      expect(
        DebtSimplifierEngine.settle({'A': 100_000, 'C': -100_000}),
        <SettlementPayment>[
          const SettlementPayment(
            debtorId: 'C',
            creditorId: 'A',
            amount: 100_000,
          ),
        ],
      );
    });

    test('banyak kreditur, satu debitur -> urut sesuai besar piutang', () {
      final settlements = DebtSimplifierEngine.settle({
        'A': 40_000,
        'B': 60_000,
        'C': -100_000,
      });

      expect(settlements, <SettlementPayment>[
        const SettlementPayment(debtorId: 'C', creditorId: 'B', amount: 60_000),
        const SettlementPayment(debtorId: 'C', creditorId: 'A', amount: 40_000),
      ]);
    });

    test('satu kreditur, banyak debitur -> sisa debitur masuk heap lagi', () {
      final settlements = DebtSimplifierEngine.settle({
        'A': 100_000,
        'B': -40_000,
        'C': -60_000,
      });

      expect(settlements, <SettlementPayment>[
        const SettlementPayment(debtorId: 'C', creditorId: 'A', amount: 60_000),
        const SettlementPayment(debtorId: 'B', creditorId: 'A', amount: 40_000),
      ]);
    });

    test('tie-break deterministik pada kreditur & debitur senilai sama', () {
      // Kreditur A & B sama-sama +100; debitur C = -50, D = -150.
      final settlements = DebtSimplifierEngine.settle({
        'A': 100,
        'B': 100,
        'C': -50,
        'D': -150,
      });

      // Kreditur A menang tie-break (id terkecil); debitur D (|150|) terbesar.
      expect(settlements, <SettlementPayment>[
        const SettlementPayment(debtorId: 'D', creditorId: 'A', amount: 100),
        // Debitur C & D sisa -50 tie; C (id terkecil) diproses duluan.
        const SettlementPayment(debtorId: 'C', creditorId: 'B', amount: 50),
        const SettlementPayment(debtorId: 'D', creditorId: 'B', amount: 50),
      ]);
    });

    test('menolak konservasi uang yang rusak (ArgumentError)', () {
      // Total balance != 0: 100 - 50 = 50.
      expect(
        () => DebtSimplifierEngine.settle({'A': 100, 'B': -50}),
        throwsArgumentError,
      );
      // Hanya kreditur tanpa satu debitur pun.
      expect(
        () => DebtSimplifierEngine.settle({'A': 100}),
        throwsArgumentError,
      );
      // Hanya debitur tanpa kreditur.
      expect(
        () => DebtSimplifierEngine.settle({'A': -100}),
        throwsArgumentError,
      );
    });

    test('nominal besar tetap integer murni (no double/float)', () {
      final settlements = DebtSimplifierEngine.settle({
        'U1': 2_000_000_000,
        'U2': 1_250_000_000,
        'U3': -3_250_000_000,
      });

      expect(settlements, <SettlementPayment>[
        const SettlementPayment(
          debtorId: 'U3',
          creditorId: 'U1',
          amount: 2_000_000_000,
        ),
        const SettlementPayment(
          debtorId: 'U3',
          creditorId: 'U2',
          amount: 1_250_000_000,
        ),
      ]);
      for (final payment in settlements) {
        expect(payment.amount, isA<int>());
      }
    });

    test(
      'properti: semua kombinasi kecil terclear, transfer minimal, deterministik',
      () {
        // Enumerasi seluruh kombinasi balance kecil yang konservasi (sum == 0),
        // lalu pastikan engine (a) menutup semua saldo, (b) jumlah transfer
        // <= n-1, dan (c) hasil pemanggilan ulang identik.
        const users = <String>['a', 'b', 'c', 'd'];
        for (var a = -3; a <= 3; a++) {
          for (var b = -3; b <= 3; b++) {
            for (var c = -3; c <= 3; c++) {
              for (var d = -3; d <= 3; d++) {
                if (a + b + c + d != 0) {
                  continue;
                }
                final balances = {'a': a, 'b': b, 'c': c, 'd': d};

                final settlements = DebtSimplifierEngine.settle(balances);
                _assertPaymentsClearAll(balances, settlements);
                expect(
                  settlements.length,
                  lessThanOrEqualTo(users.length - 1),
                  reason: 'Max transfer <= n-1 untuk $balances',
                );

                // Deterministik: hasil kedua pemanggilan identik.
                final again = DebtSimplifierEngine.settle(Map.of(balances));
                expect(again, settlements);
              }
            }
          }
        }
      },
    );
  });
}