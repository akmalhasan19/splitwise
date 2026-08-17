import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';

/// QA performa (Phase 2, Minggu 4, Task 3 — audit performa & memori):
/// memastikan greedy engine tetap cepat pada grup sangat besar (perangkat
/// berspesifikasi rendah). Algoritma O(n log n); seluruh aritmatika integer.
void main() {
  group('DebtSimplifierEngine — skala besar & performa', () {
    test('1000 user (500 debitur, 500 kreditur) selesai < 5 detik', () {
      final balances = <String, MoneyAmount>{};
      for (var i = 0; i < 500; i++) {
        balances['debtor-$i'] = -(i * 1000 + 1);
        balances['creditor-$i'] = i * 1000 + 1;
      }

      final stopwatch = Stopwatch()..start();
      final settlements = DebtSimplifierEngine.settle(balances);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      // Karena balance saling menutup berpasangan, hasil = 500 transaksi.
      expect(settlements, hasLength(500));

      // Konservasi: total amount yang ditransfer = total piutang.
      var total = 0;
      for (final s in settlements) {
        total += s.amount;
      }
      var expected = 0;
      for (var i = 0; i < 500; i++) {
        expected += i * 1000 + 1;
      }
      expect(total, expected);
    });

    test('jaringan padat (banyak expense, saldo acak) deterministik', () {
      // Simulasi saldo hasil patungan besar: kreditur & debitur dengan
      // nominal acak-deterministik (tanpa randomness sesungguhnya).
      final balances = <String, MoneyAmount>{};
      for (var i = 0; i < 250; i++) {
        balances['d$i'] = -(i % 7 * 3333 + 1);
        balances['c$i'] = i % 7 * 3333 + 1;
      }

      final first = DebtSimplifierEngine.settle(balances);
      final second = DebtSimplifierEngine.settle(balances);
      expect(first, second); // deterministik
    });

    test('1000 user saling tumpang-tindih tetap konservatif', () {
      // 1000 user berpasangan (kreditur/debitur) dengan nominal saling tumpang
      // tindih sehingga greedy menghasilkan banyak transaksi parsial.
      final balances = <String, MoneyAmount>{};
      for (var i = 0; i < 500; i++) {
        final value = i * 37 + 13;
        balances['cred-$i'] = value;
        balances['deb-$i'] = -value;
      }
      final settlements = DebtSimplifierEngine.settle(balances);
      expect(settlements, hasLength(500));

      var totalTransferred = 0;
      for (final s in settlements) {
        totalTransferred += s.amount;
      }
      // Konservasi: total transfer == total piutang == total utang.
      var expected = 0;
      for (var i = 0; i < 500; i++) {
        expected += i * 37 + 13;
      }
      expect(totalTransferred, expected);
    });
  });
}
