/// Unit test formatter input ribuan (Quick-Entry Sheet) — Minggu 3, Task 2.
///
/// Menguji auto-formatting currency realtime: pemisah titik ditambahkan saat
/// angka diketik, dan mengabaikan non-digit.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/app/ui/quick_entry_sheet.dart';

void main() {
  final formatter = thousandsInputFormatter();

  TextEditingValue edit(String before, String after, {int? sel}) =>
      formatter.formatEditUpdate(
        TextEditingValue(text: before),
        TextEditingValue(
          text: after,
          selection: TextSelection.collapsed(offset: sel ?? after.length),
        ),
      );

  test('menambahkan pemisah titik setiap 3 digit', () {
    final v = edit('', '100000');
    expect(v.text, '100.000');
    expect(v.selection.baseOffset, '100.000'.length);
  });

  test('digit tunggal tidak dapat pemisah', () {
    expect(edit('', '5').text, '5');
    expect(edit('', '999').text, '999');
  });

  test('tepat 4 digit -> 1 pemisah', () {
    expect(edit('', '1000').text, '1.000');
  });

  test('6 digit -> 2 pemisah', () {
    expect(edit('', '123456').text, '123.456');
  });

  test('membuang pemisah yang sudah ada (re-format dari mentah)', () {
    final v = edit('100.000', '100.0000');
    // Semua non-digit dibuang dulu, lalu di-group ulang.
    expect(v.text, '1.000.000');
  });

  test('kosong -> string kosong', () {
    final v = edit('1.000', '');
    expect(v.text, '');
    expect(v.selection.baseOffset, 0);
  });

  test('non-digit ditolak (hanya digit diproses)', () {
    final v = edit('', '12a34');
    expect(v.text, '1.234');
  });
}
