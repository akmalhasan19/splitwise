/// Unit test `date_formatter` — Minggu 3 (format tanggal id-ID, pure fn).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/utils/date_formatter.dart';

void main() {
  group('formatDate', () {
    test('17 Agustus 2026', () {
      expect(formatDate(DateTime(2026, 8, 17)), '17 Agu 2026');
    });
    test('leading zero hari', () {
      expect(formatDate(DateTime(2026, 1, 5)), '05 Jan 2026');
    });
    test('setiap singkatan bulan benar', () {
      final expected = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      for (var i = 0; i < 12; i++) {
        expect(formatDate(DateTime(2026, i + 1, 10)), '10 ${expected[i]} 2026');
      }
    });
  });

  group('formatDateFromSeconds', () {
    test('konversi epoch detik -> string tanggal', () {
      // 2026-08-17 00:00:00 UTC = 1789968000 detik (perhitungan kasar).
      // Cukup verifikasi konsistensi dengan formatDate via DateTime.
      const epoch = 1_700_000_000; // ~2023-11-{14ish} UTC
      final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      expect(formatDateFromSeconds(epoch), formatDate(dt));
    });
  });

  group('formatDateTime', () {
    test('tanggal + jam:menit dengan leading zero', () {
      final dt = DateTime(2026, 8, 17, 9, 5);
      expect(formatDateTime(dt), '17 Agu 2026, 09:05');
    });
  });

  group('formatDateTimeFromSeconds', () {
    test('konsistensi dengan formatDateTime', () {
      const epoch = 1_700_000_000;
      final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      expect(formatDateTimeFromSeconds(epoch), formatDateTime(dt));
    });
  });
}
