/// Unit test `money_formatter` — Minggu 3 (util display Rupiah, pure fn).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/utils/money_formatter.dart';

void main() {
  group('formatRupiah', () {
    test('nol', () {
      expect(formatRupiah(0), 'Rp0');
    });
    test('tanpa pemisah (< 1000)', () {
      expect(formatRupiah(999), 'Rp999');
    });
    test('pemisah ribuan titik', () {
      expect(formatRupiah(1_000), 'Rp1.000');
      expect(formatRupiah(100_000), 'Rp100.000');
      expect(formatRupiah(1_500_000), 'Rp1.500.000');
    });
    test('nominal besar miliar', () {
      expect(formatRupiah(2_000_000_000), 'Rp2.000.000.000');
    });
    test('nilai negatif memakai tanda minus', () {
      expect(formatRupiah(-33_333), 'Rp-33.333');
    });
    test('simbol bisa diganti', () {
      expect(formatRupiah(100, symbol: ''), '100');
      expect(formatRupiah(1_000, symbol: 'IDR '), 'IDR 1.000');
    });
  });

  group('formatRupiahPlain', () {
    test('tanpa simbol', () {
      expect(formatRupiahPlain(100_000), '100.000');
      expect(formatRupiahPlain(0), '0');
    });
  });

  group('tryParseRupiahField', () {
    test('digit murni', () {
      expect(tryParseRupiahField('100000'), 100_000);
    });
    test('pemisah titik dibuang', () {
      expect(tryParseRupiahField('100.000'), 100_000);
      expect(tryParseRupiahField('1.500.000'), 1_500_000);
    });
    test('prefiks Rp/IDR (case-insensitive) dibuang', () {
      expect(tryParseRupiahField('Rp100.000'), 100_000);
      expect(tryParseRupiahField('IDR 1.000'), 1_000);
      expect(tryParseRupiahField('rp 50'), 50);
    });
    test('koma & spasi dibuang', () {
      expect(tryParseRupiahField('1,000,000'), 1_000_000);
      expect(tryParseRupiahField('1 000 000'), 1_000_000);
    });
    test('kosong -> null (bukan exception)', () {
      expect(tryParseRupiahField(''), isNull);
      expect(tryParseRupiahField('Rp'), isNull);
    });
    test('huruf/karakter aneh ditolak -> null', () {
      expect(tryParseRupiahField('abc'), isNull);
      expect(tryParseRupiahField('12-34'), isNull);
      // Tanda plus/minus di tengah bukan digit.
      expect(tryParseRupiahField('Rp+12'), isNull);
    });

    test('titik di tengah angka diperlakukan pemisah (lenient)', () {
      // `100.5` ditafsirkan sebagai "1005" (titik diabaikan) — konsisten
      // dengan filter digitsOnly pada field nominal (titik otomatis dari
      // formatter ribuan, bukan ditikik manual user).
      expect(tryParseRupiahField('100.5'), 1005);
    });
  });
}
