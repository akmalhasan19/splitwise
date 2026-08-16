/// Helper kalkulasi pembagian nominal — aritmatika integer murni.
///
/// Seluruh matematika memakai operator `~/` dan `%` (tanpa `double`/`float`)
/// sehingga bebas floating-point rounding error. Menjaga **konservasi total**:
/// jumlah seluruh hasil pembagian selalu persis sama dengan nominal awal.
/// (Contoh kontrak: `equalSplit(100_000, 3)` => `[33_334, 33_333, 33_333]`.)
library;

import 'package:debt_splitter/core/money/money_amount.dart';

class SplitCalculator {
  const SplitCalculator._();

  /// Membagi [total] secara merata ke [memberCount] orang.
  ///
  /// * `base = total ~/ memberCount`;
  /// * `remainder = total % memberCount` (dijamin `0 <= remainder < memberCount`);
  /// * `remainder` anggota pertama (indeks `0..remainder-1`) menerima
  ///   `base + 1`, sisanya `base`.
  ///
  /// Sisa pembulatan dengan demikian SELALU didistribusikan (tidak dibuang),
  /// dan `sum(hasil) == total` terpenuhi dalam semua kasus.
  static List<MoneyAmount> equalSplit(MoneyAmount total, int memberCount) {
    if (memberCount <= 0) {
      throw ArgumentError.value(
        memberCount,
        'memberCount',
        'Jumlah anggota harus lebih dari 0.',
      );
    }
    if (total < 0) {
      throw ArgumentError.value(total, 'total', 'Nominal tidak boleh negatif.');
    }

    final base = total ~/ memberCount;
    final remainder = total % memberCount;

    return List<MoneyAmount>.generate(
      memberCount,
      (index) => base + (index < remainder ? 1 : 0),
    );
  }

  /// Jumlah seluruh [shares] — identik dengan aturan konservasi uang
  /// (`sum(share_amount) == expense.amount`).
  static MoneyAmount sum(Iterable<MoneyAmount> shares) =>
      shares.fold<MoneyAmount>(0, (acc, value) => acc + value);
}
