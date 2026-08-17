/// Formatter tanggal & waktu (display) — `lib/core/utils/` (Minggu 3).
///
/// **Pure function** tanpa `intl`: format deterministik dari [DateTime] /
/// timestamp Unix epoch detik, sehingga 100% unit-testable tanpa locale OS.
/// Tetap memakai `int` untuk seluruh operasi waktu (konsisten dengan
/// `docs/architecture.md` §Presisi Keuangan yang menyimpan timestamp INTEGER).
library;

/// Konversi `DateTime` -> string tanggal pendek `DD MMM yyyy` (id-ID).
///
/// Contoh: `DateTime(2026, 8, 17)` -> `'17 Agu 2026'`.
String formatDate(DateTime date) {
  return '${_pad2(date.day)} ${_monthAbbr(date.month)} ${date.year}';
}

/// Konversi timestamp Unix epoch **detik** -> string tanggal pendek.
String formatDateFromSeconds(int epochSeconds) =>
    formatDate(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));

/// Konversi `DateTime` -> string tanggal+waktu `DD MMM yyyy, HH:MM`.
String formatDateTime(DateTime date) {
  return '${formatDate(date)}, ${_pad2(date.hour)}:${_pad2(date.minute)}';
}

/// Konversi timestamp Unix epoch **detik** -> string tanggal+waktu.
String formatDateTimeFromSeconds(int epochSeconds) =>
    formatDateTime(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));

/// Daftar singkatan bulan id-ID (indeks 1..12).
const List<String> _months = <String>[
  '', // indeks 0 tidak dipakai (bulan mulai dari 1)
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _monthAbbr(int month) =>
    (month >= 1 && month <= 12) ? _months[month] : '???';

/// Melengkapi angka 1 digit menjadi 2 digit dengan leading zero.
String _pad2(int value) => value.toString().padLeft(2, '0');
