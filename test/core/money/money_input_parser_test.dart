import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/money/money_input_parser.dart';

void main() {
  group('MoneyInputParser — string ke Integer (rupiah utuh)', () {
    test('angka polos tanpa pemisah', () {
      expect(MoneyInputParser.parse('100000'), 100_000);
      expect(MoneyInputParser.parse('0'), 0);
      expect(MoneyInputParser.parse('7'), 7);
    });

    test('pemisah ribuan titik', () {
      expect(MoneyInputParser.parse('100.000'), 100_000);
      expect(MoneyInputParser.parse('1.000.000'), 1_000_000);
      expect(MoneyInputParser.parse('12.345.678'), 12_345_678);
    });

    test('pemisah ribuan koma', () {
      expect(MoneyInputParser.parse('1,000,000'), 1_000_000);
    });

    test('pemisah ribuan spasi', () {
      expect(MoneyInputParser.parse('1 000 000'), 1_000_000);
    });

    test('prefiks Rp / IDR (case-insensitive)', () {
      expect(MoneyInputParser.parse('Rp 100.000'), 100_000);
      expect(MoneyInputParser.parse('Rp100.000'), 100_000);
      expect(MoneyInputParser.parse('rp1375000'), 1_375_000);
      expect(MoneyInputParser.parse('IDR 250000'), 250_000);
      expect(MoneyInputParser.parse('Rp. 100.000'), 100_000);
    });

    test('whitespace di sekitar input diabaikan', () {
      expect(MoneyInputParser.parse('  100000  '), 100_000);
    });

    test('contoh plan: Rp100.000 / 3 tetap integer', () {
      final total = MoneyInputParser.parse('Rp100.000');
      expect(total, 100_000);
      expect(total ~/ 3, 33_333); // base share
      expect(total % 3, 1); // sisa dibagikan eksplisit
    });

    test('menolak input kosong', () {
      expect(() => MoneyInputParser.parse(''), throwsFormatException);
      expect(() => MoneyInputParser.parse('   '), throwsFormatException);
    });

    test('menolak prefiks mata uang tanpa angka', () {
      expect(() => MoneyInputParser.parse('Rp'), throwsFormatException);
      expect(() => MoneyInputParser.parse('IDR'), throwsFormatException);
    });

    test('menolak karakter selain angka/pemisah', () {
      expect(() => MoneyInputParser.parse('abc100'), throwsFormatException);
      expect(() => MoneyInputParser.parse('100abc'), throwsFormatException);
      expect(() => MoneyInputParser.parse('-100000'), throwsFormatException);
      expect(() => MoneyInputParser.parse('Rp-100.000'), throwsFormatException);
    });

    test('menolak desimal/sen (tidak dibulatkan diam-diam)', () {
      expect(() => MoneyInputParser.parse('100.5'), throwsFormatException);
      expect(() => MoneyInputParser.parse('100,5'), throwsFormatException);
      expect(() => MoneyInputParser.parse('100,50'), throwsFormatException);
      expect(() => MoneyInputParser.parse('1.000,50'), throwsFormatException);
      expect(() => MoneyInputParser.parse('10.00'), throwsFormatException);
    });

    test('menolak pengelompokan ribuan tidak valid', () {
      expect(() => MoneyInputParser.parse('1.00.000'), throwsFormatException);
      expect(() => MoneyInputParser.parse('12.3456'), throwsFormatException);
      expect(() => MoneyInputParser.parse('12.34.560'), throwsFormatException);
      expect(() => MoneyInputParser.parse('...'), throwsFormatException);
    });
  });
}
