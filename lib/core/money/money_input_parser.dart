/// Membaca input string pengguna menjadi [MoneyAmount] (`int`, rupiah utuh).
///
/// Konversi otomatis string -> `Integer` untuk form input nominal
/// (Phase 2, Minggu 1 — Task 4: Data Validation & Helpers).
///
/// Aturan parsing (sengaja konservatif demi presisi keuangan, lihat
/// `docs/architecture.md` §Presisi Keuangan):
///
/// 1. Spasi di awal/akhir serta prefiks mata uang `Rp` / `IDR`
///    (case-insensitive) diizinkan dan dibuang.
/// 2. Pemisah ribuan boleh berupa titik, koma, atau spasi — contoh
///    `1.000.000`, `1,000,000`, `1 000 000`. Semua grup (selain grup
///    pertama) WAJIB tepat 3 digit dan grup pertama 1-3 digit.
/// 3. Nilai pecahan/desimal (sen) TIDAK didukung: satuan terkecil adalah Rp1.
///    Input seperti `100.5` atau `100,50` DITOLAK lewat [FormatException]
///    — tidak pernah dibulatkan diam-diam.
/// 4. Karakter lain (termasuk tanda minus) ditolak.
library;

import 'package:debt_splitter/core/money/money_amount.dart';

class MoneyInputParser {
  const MoneyInputParser._();

  static final RegExp _validChars = RegExp(r'^[0-9.,\s]+$');
  static final RegExp _groupSeparator = RegExp(r'[,.\s]+');
  static const List<String> _currencyPrefixes = <String>['RP', 'IDR'];

  /// Parsing yang dapat melempar [FormatException] untuk input tidak valid.
  static MoneyAmount parse(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('Nominal tidak boleh kosong');
    }

    final upper = value.toUpperCase();
    for (final prefix in _currencyPrefixes) {
      if (upper.startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }

    if (value.isEmpty) {
      throw FormatException('Tidak ada angka setelah prefiks mata uang', input);
    }

    if (!_validChars.hasMatch(value)) {
      throw FormatException(
        'Input hanya boleh angka dan pemisah ribuan (titik/koma/spasi)',
        input,
      );
    }

    if (_groupSeparator.hasMatch(value)) {
      final groups = value
          .split(_groupSeparator)
          .where((group) => group.isNotEmpty)
          .toList();
      if (groups.isEmpty) {
        throw const FormatException('Nominal tidak valid');
      }

      final first = groups.first;
      final validThousands =
          first.length <= 3 &&
          groups.skip(1).every((group) => group.length == 3);
      if (!validThousands) {
        throw FormatException(
          'Desimal/sen tidak didukung; gunakan rupiah utuh (contoh: 100.000)',
          input,
        );
      }

      return int.parse(groups.join());
    }

    return int.parse(value);
  }
}
