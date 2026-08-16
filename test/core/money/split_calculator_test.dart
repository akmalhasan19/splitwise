import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/money/split_calculator.dart';

void main() {
  group('SplitCalculator.equalSplit — pembagian integer + penanganan sisa', () {
    test('Rp100.000 dibagi 3 (rencana: sisa 1 rupiah ke anggota pertama)', () {
      final shares = SplitCalculator.equalSplit(100_000, 3);
      expect(shares, <int>[33_334, 33_333, 33_333]);
      expect(SplitCalculator.sum(shares), 100_000);
    });

    test('terbagi habis rata tanpa sisa', () {
      expect(SplitCalculator.equalSplit(90_000, 3), <int>[
        30_000,
        30_000,
        30_000,
      ]);
    });

    test('satu orang menanggung seluruh nominal', () {
      expect(SplitCalculator.equalSplit(100_000, 1), <int>[100_000]);
    });

    test('sisa lebih besar dari jumlah pembagi (nominal kecil)', () {
      // Rp2 / 5 orang: base 0, sisa 2 -> dua orang pertama dapat Rp1.
      expect(SplitCalculator.equalSplit(2, 5), <int>[1, 1, 0, 0, 0]);
    });

    test('nominal 0 menghasilkan seluruhnya 0', () {
      expect(SplitCalculator.equalSplit(0, 4), <int>[0, 0, 0, 0]);
    });

    test('sepuluh juta dibagi 3: konservasi total terjaga', () {
      final shares = SplitCalculator.equalSplit(10_000_000, 3);
      expect(SplitCalculator.sum(shares), 10_000_000);
      final minShare = shares.reduce((a, b) => a < b ? a : b);
      final maxShare = shares.reduce((a, b) => a > b ? a : b);
      expect(maxShare - minShare, 1);
    });

    test('konservasi total untuk semua kombinasi kecil (brute)', () {
      for (var total = 0; total <= 500; total++) {
        for (var memberCount = 1; memberCount <= 12; memberCount++) {
          final shares = SplitCalculator.equalSplit(total, memberCount);
          expect(shares, hasLength(memberCount));
          expect(
            SplitCalculator.sum(shares),
            total,
            reason: 'total=$total n=$memberCount',
          );
          expect(shares.every((share) => share >= 0), isTrue);
        }
      }
    });

    test('menolak argumen tidak valid', () {
      expect(() => SplitCalculator.equalSplit(100, 0), throwsArgumentError);
      expect(() => SplitCalculator.equalSplit(100, -3), throwsArgumentError);
      expect(() => SplitCalculator.equalSplit(-100, 3), throwsArgumentError);
    });
  });

  group('SplitCalculator.sum', () {
    test('menjumlahkan kumpulan nominal', () {
      expect(SplitCalculator.sum(const <int>[1, 2, 3]), 6);
      expect(SplitCalculator.sum(const <int>[]), 0);
      expect(SplitCalculator.sum(const <int>[100_000]), 100_000);
    });
  });
}
