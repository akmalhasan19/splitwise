/// Formatter & parser tampilan nominal Rupiah — `lib/core/utils/` (Minggu 3).
///
/// **Pure function** tanpa dependency eksternal (tanpa `intl`) agar:
/// * deterministik & 100% unit-testable (konsisten dengan `MoneyInputParser`);
/// * ringan & offline (tak ada pengambilan locale dari OS/jaringan);
/// * mempertahankan presisi `int` ([MoneyAmount]) — tanpa `double`/`float`.
///
/// Konvensi format display (id-ID):
/// * pemisah ribuan = titik (`.`), contoh `Rp100.000`;
/// * tanpa pecahan sen (satuan terkecil = Rp1);
/// * input pemisah ribuan boleh titik/koma/spasi — ditangani
///   [MoneyInputParser.parse] saat konversi ke [MoneyAmount].
library;

import 'package:debt_splitter/core/money/money_amount.dart';

/// Format [MoneyAmount] menjadi string display Rupiah dengan pemisah ribuan.
///
/// Contoh: `100000` -> `'Rp100.000'`; `0` -> `'Rp0'`; `1500000` -> `'Rp1.500.000'`.
/// Fungsi ini hanya untuk tampilan; data tetap disimpan sebagai `int`.
String formatRupiah(MoneyAmount amount, {String symbol = 'Rp'}) {
  final isNegative = amount < 0;
  final absValue = amount.abs();
  final grouped = _groupThousands(absValue);
  final body = isNegative ? '-$grouped' : grouped;
  return '$symbol$body';
}

/// Sama dengan [formatRupiah] tanpa prefiks simbol — berguna untuk input field
/// yang sudah memiliki label "Rp" terpisah.
String formatRupiahPlain(MoneyAmount amount) =>
    formatRupiah(amount, symbol: '');

/// Membentuk string nominal dengan pemisah ribuan titik dari sebuah integer
/// non-negatif. `1234567` -> `'1.234.567'`; `0` -> `'0'`.
String _groupThousands(MoneyAmount value) {
  if (value == 0) return '0';
  final digits = value.toString();
  final buffer = StringBuffer();
  var count = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
    count++;
  }
  // Hasil terbalik (ditulis kanan-ke-kiri) -> balik kembali.
  final chars = buffer.toString().split('').reversed.join();
  return chars;
}

/// Membersihkan nilai mentah input mata uang — membuang prefiks `Rp`/`IDR`
/// dan seluruh pemisah ribuan sehingga hanya menyisakan digit ASCII.
///
/// Mengembalikan `null` bila tidak ada digit sama sekali / gagal parsing agar
/// pemanggil bisa menampilkan field kosong alih-alih melempar exception saat
/// user masih mengetik (mis. teks sementara `'Rp1.00'`).
MoneyAmount? tryParseRupiahField(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'^\s*(Rp|IDR|rp|idr)\s*'), '')
      .replaceAll(RegExp(r'[\s.,]'), '');
  if (cleaned.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(cleaned)) return null;
  return int.tryParse(cleaned);
}
