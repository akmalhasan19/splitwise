/// ItemBillSplitter — alokasi pengeluaran berbasis "menu/struk"
/// (fitur itemized bill / split-item).
///
/// Menyelesaikan kasus nyata: satu orang menalangi bill rumah makan, tapi tiap
/// orang pesan item yang berbeda-beda. Alih-alih mengetik nominal tiap orang
/// secara manual (modus EXACT), user cukup mencatat item dari struk lalu
/// mencentang **siapa yang makan item itu** (boleh lebih dari satu → nominal
/// baris dibagi rata di antara mereka). Aplikasi yang menghitung bagian tiap
/// orang — menghilangkan pekerjaan "ingat pesan + lihat struk + jumlahin pakai
/// kalkulator".
///
/// Kontrak formula (murni integer, tanpa `double`/`float`):
///   * nominal satu baris = `unitPrice * quantity`;
///   * nominal baris dibagi **sama rata** di antara `claimantIds`.
///     Sisa pembulatan didistribusikan ke sebagian claimant (teknik konservasi
///     yang sama dengan `SplitCalculator.equalSplit`);
///   * hasil `allocate` = peta `userId -> share`, dan
///     `sum(share) == totalOf(lines)` == `sum(unitPrice * quantity)` seluruh
///     baris (konservasi uang dijamin).
///
/// Claimant di-normalisasi (sort lexicographic) sehingga hasil **deterministik**
/// — tidak terpengaruh urutan centang di UI.
library;

import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/money/split_calculator.dart';

/// Satu baris item pada struk/bill: harga per unit, jumlah unit, dan daftar id
/// user yang mengonsumsi item ini.
class ItemBillLine {
  const ItemBillLine({
    required this.id,
    required this.unitPrice,
    required this.quantity,
    required this.claimantIds,
  });

  /// Identitas unik baris dalam satu bill (mis. UUID atau indeks urut).
  final String id;

  /// Harga per unit (INTEGER Rupiah utuh).
  final MoneyAmount unitPrice;

  /// Banyak unit pada baris ini (wajib `>= 1`).
  /// Nominal baris = `unitPrice * quantity`.
  final int quantity;

  /// Daftar id user yang makan item ini. Boleh `> 1` (nominal baris dibagi
  /// rata). Wajib tidak kosong dan tanpa id duplikat.
  final List<String> claimantIds;
}

class ItemBillSplitter {
  const ItemBillSplitter._();

  /// Total nominal seluruh baris: `sum(unitPrice * quantity)`.
  ///
  /// Valid: setiap baris divalidasi (harga >= 0, quantity >= 1, claimant
  /// non-kosong & unik) — melempar [ArgumentError] pada data korup.
  static MoneyAmount totalOf(Iterable<ItemBillLine> lines) {
    var total = 0;
    for (final line in lines) {
      _validateLine(line);
      total += line.unitPrice * line.quantity;
    }
    return total;
  }

  /// Membagi keseluruhan [lines] menjadi peta `userId -> share`.
  ///
  /// Peta hanya memuat user yang mengklaim setidaknya satu item (user yang sama
  /// sekali tidak makan apa pun tidak muncul). Menjamin konservasi:
  /// `sum(shares.values) == totalOf(lines)`.
  static Map<String, MoneyAmount> allocate(Iterable<ItemBillLine> lines) {
    final shares = <String, MoneyAmount>{};
    for (final line in lines) {
      _validateLine(line);
      final lineAmount = line.unitPrice * line.quantity;
      // Deterministik: urutkan claimant sebelum mendistribusikan sisa senilai.
      final claimantIds = (List<String>.of(line.claimantIds))..sort();
      final amounts = SplitCalculator.equalSplit(
        lineAmount,
        claimantIds.length,
      );
      for (var i = 0; i < claimantIds.length; i++) {
        shares[claimantIds[i]] = (shares[claimantIds[i]] ?? 0) + amounts[i];
      }
    }
    return shares;
  }

  /// Menegakkan invariant domain sebuah baris item.
  static void _validateLine(ItemBillLine line) {
    if (line.quantity < 1) {
      throw ArgumentError.value(
        line.quantity,
        'quantity',
        'Jumlah unit barang harus minimal 1.',
      );
    }
    if (line.unitPrice < 0) {
      throw ArgumentError.value(
        line.unitPrice,
        'unitPrice',
        'Harga tidak boleh negatif.',
      );
    }
    if (line.claimantIds.isEmpty) {
      throw ArgumentError.value(
        line.claimantIds,
        'claimantIds',
        'Setiap item harus diklaim minimal satu orang.',
      );
    }
    final seen = <String>{};
    for (final id in line.claimantIds) {
      if (!seen.add(id)) {
        throw ArgumentError.value(
          line.claimantIds,
          'claimantIds',
          'Terdapat id claimant duplikat: $id.',
        );
      }
    }
  }
}