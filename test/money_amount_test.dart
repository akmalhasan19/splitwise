import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/money/money_amount.dart';

void main() {
  group('MoneyAmount (Presisi Keuangan — Integer)', () {
    test('nominal uang bertipe int, bukan double/float', () {
      const MoneyAmount amount = 100_000; // Rp100.000
      expect(amount, isA<int>());
      expect(amount is double, isFalse);
    });

    test(
      'equal split Rp100.000 / 3 memakai integer: sisa ditangani eksplisit',
      () {
        const MoneyAmount total = 100_000;
        const int members = 3;

        final MoneyAmount baseShare = total ~/ members; // 33.333
        final MoneyAmount remainder = total % members; // sisa 1

        expect(baseShare, 33_333);
        expect(remainder, 1);

        // Konservasi total: sisa dibagikan ke salah satu anggota.
        final MoneyAmount allocated =
            baseShare * (members - 1) + (baseShare + remainder);
        expect(allocated, total);
      },
    );

    test('tidak ada floating-point rounding error pada akumulasi integer', () {
      MoneyAmount sum = 0;
      for (var i = 0; i < 1_000; i++) {
        sum += 1; // 1 Rupiah per iterasi
      }
      expect(sum, 1_000);
    });
  });
}
