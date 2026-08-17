/// Unit test `WhatsAppSummaryGenerator` — Minggu 3, Task 4.
///
/// Memverifikasi format teks otomatis siap WhatsApp: header grup, total,
/// saldo per anggota (inkl. label berhutang/akan menerima/lunas), daftar
/// rekomendasi pelunasan dengan emoji keycap, serta fallback saat data kosong.
/// Generator adalah pure function — snapshot disuntikkan langsung.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/money/split_calculator.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';
import 'package:debt_splitter/features/settle_up/net_balance_calculator.dart';
import 'package:debt_splitter/features/share/whatsapp_summary_generator.dart';

Group _group({String name = 'Trip Bromo'}) => Group(
  id: 'g1',
  name: name,
  defaultCurrency: 'IDR',
  createdAt: 1_700_000_000,
);

User _user(String id, String name) =>
    User(id: id, name: name, avatarColor: '#21A366', createdAt: 1_700_000_000);

ExpenseWithShares _expense(
  String id,
  String paidBy,
  int amount,
  Map<String, int> shares,
) => ExpenseWithShares(
  expense: Expense(
    id: id,
    groupId: 'g1',
    paidBy: paidBy,
    amount: amount,
    splitType: ExpenseSplitType.exact,
    date: 1_700_000_000,
  ),
  shares: [
    for (final s in shares.entries)
      ExpenseShare(id: '$id-${s.key}', userId: s.key, shareAmount: s.value),
  ],
);

void main() {
  test(
    'grup kosong (tanpa anggota/expense) -> placeholder + status tuntas',
    () {
      final text = WhatsAppSummaryGenerator.generate(
        GroupSummarySnapshot(
          group: _group(),
          members: const [],
          netBalances: const {},
          settlements: const [],
          totalExpenseAmount: 0,
        ),
      );

      expect(text, contains('*Debt-Splitter — Trip Bromo*'));
      expect(text, contains('Total tercatat: Rp0'));
      expect(text, contains('_(belum ada anggota)_'));
      expect(text, contains('Semua tuntas'));
      expect(text, contains('Dibuat oleh Debt-Splitter (offline)'));
    },
  );

  test('satu transaksi equal-split 100.000/3 -> dua pelunasan terurut', () {
    final members = [
      _user('A', 'Andi'),
      _user('B', 'Budi'),
      _user('C', 'Citra'),
    ];
    final amounts = SplitCalculator.equalSplit(100_000, 3);
    final shares = <String, int>{
      for (var i = 0; i < 3; i++) members[i].id: amounts[i],
    };
    final expenses = [_expense('e1', 'A', 100_000, shares)];
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    final settlements = DebtSimplifierEngine.settle(balances);

    final text = WhatsAppSummaryGenerator.generate(
      GroupSummarySnapshot(
        group: _group(),
        members: members,
        netBalances: balances,
        settlements: settlements,
        totalExpenseAmount: 100_000,
      ),
    );

    // Header & total.
    expect(text, contains('Total tercatat: Rp100.000'));
    // Saldo per anggota — A kreditur, B & C debitur.
    expect(text, contains('Andi: Rp+66.666 (akan menerima)'));
    expect(text, contains('Budi: Rp-33.333 (berhutang)'));
    expect(text, contains('Citra: Rp-33.333 (berhutang)'));
    // Rekomendasi pelunasan.
    expect(text, contains('Budi transfer Rp33.333 ke Andi'));
    expect(text, contains('Citra transfer Rp33.333 ke Andi'));
    // Anggota urut nama.
    final andiPos = text.indexOf('Andi: Rp+');
    final budiPos = text.indexOf('Budi: Rp-');
    final citraPos = text.indexOf('Citra: Rp-');
    expect(andiPos, lessThan(budiPos));
    expect(budiPos, lessThan(citraPos));
    // Penanda jumlah transaksi.
    expect(text, contains('Total 2 transaksi pelunasan'));
  });

  test('semua saldo nol -> status tuntas, tanpa baris transfer', () {
    final members = [_user('A', 'Andi'), _user('B', 'Budi')];
    // A menalangi 50.000 untuk B; B menalangi 50.000 untuk A -> net A 0, B 0.
    final expenses = [
      _expense('e1', 'A', 50_000, {'B': 50_000}),
      _expense('e2', 'B', 50_000, {'A': 50_000}),
    ];
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    final settlements = DebtSimplifierEngine.settle(balances);

    final text = WhatsAppSummaryGenerator.generate(
      GroupSummarySnapshot(
        group: _group(name: 'Kosan'),
        members: members,
        netBalances: balances,
        settlements: settlements,
        totalExpenseAmount: 100_000,
      ),
    );

    expect(text, contains('*Debt-Splitter — Kosan*'));
    // Kedua anggota lunas.
    expect(text, contains('Andi: Rp0 (lunas)'));
    expect(text, contains('Budi: Rp0 (lunas)'));
    expect(text, contains('Semua tuntas — tidak ada transaksi tersisa'));
    // Tidak ada baris "transfer".
    expect(text, isNot(contains('transfer')));
  });

  test('anggota yang tidak ikut transaksi -> saldo Rp0 (lunas)', () {
    final members = [_user('A', 'Andi'), _user('D', 'Dewi')]; // Dewi diam.
    final expenses = [
      _expense('e1', 'A', 60_000, {'A': 60_000}),
    ];
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    final settlements = DebtSimplifierEngine.settle(balances);

    final text = WhatsAppSummaryGenerator.generate(
      GroupSummarySnapshot(
        group: _group(),
        members: members,
        netBalances: balances,
        settlements: settlements,
        totalExpenseAmount: 60_000,
      ),
    );

    // Dewi tidak ada di netBalances -> saldo fallback 0 (lunas).
    expect(text, contains('Dewi: Rp0 (lunas)'));
  });

  test('nominal besar miliar tetap format titik (no double/float)', () {
    // U1 menalangi 2M (share U1 750M, U2 750M, U3 500M);
    // U3 menalangi 1.25M (share U3 500M, U2 750M).
    // Net: U1 +1.250M (kreditur), U2 -1.500M (debitur), U3 +250M (kreditur).
    final members = [
      _user('U1', 'Uno'),
      _user('U2', 'Duo'),
      _user('U3', 'Tri'),
    ];
    final expenses = [
      _expense('e1', 'U1', 2_000_000_000, {
        'U1': 750_000_000,
        'U2': 750_000_000,
        'U3': 500_000_000,
      }),
      _expense('e2', 'U3', 1_250_000_000, {
        'U3': 500_000_000,
        'U2': 750_000_000,
      }),
    ];
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    final settlements = DebtSimplifierEngine.settle(balances);

    final text = WhatsAppSummaryGenerator.generate(
      GroupSummarySnapshot(
        group: _group(),
        members: members,
        netBalances: balances,
        settlements: settlements,
        totalExpenseAmount: 3_250_000_000,
      ),
    );

    expect(text, contains('Total tercatat: Rp3.250.000.000'));
    // Duo satu-satunya debitur; Uno & Tri kreditur.
    expect(text, contains('Duo: Rp-1.500.000.000 (berhutang)'));
    expect(text, contains('Uno: Rp+1.250.000.000 (akan menerima)'));
    expect(text, contains('Tri: Rp+250.000.000 (akan menerima)'));
    // Engine: Duo transfer ke Uno (piutang terbesar) lalu ke Tri.
    expect(text, contains('Duo transfer Rp1.250.000.000 ke Uno'));
    expect(text, contains('Duo transfer Rp250.000.000 ke Tri'));
  });
}
