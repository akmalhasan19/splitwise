/// Model hasil parsing OCR struk — satu baris item kandidat.
///
/// Merepresentasikan satu pos item yang berhasil diekstrak dari teks OCR
/// sebelum diedit oleh user. Field `priceGuessed` menandai item yang perlu
/// verifikasi manual (harga/qty tidak dapat diekstrak secara pasti).
///
/// Seluruh nominal bertipe `MoneyAmount` (`int` Rupiah utuh) — tidak ada
/// `double`/`float` pada jalur uang.
library;

import 'package:debt_splitter/core/money/money_amount.dart';

class ReceiptCandidateItem {
  const ReceiptCandidateItem({
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.priceGuessed = false,
  });

  /// Nama item/menu (mis. "Nasi Goreng").
  final String name;

  /// Harga per unit dalam Rupiah utuh (INTEGER).
  final MoneyAmount unitPrice;

  /// Jumlah unit (default 1). Bisa dideteksi dari pola "2x" atau baris berulang.
  final int quantity;

  /// `true` bila harga atau qty tidak dapat diekstrak secara pasti dari OCR.
  /// Item dengan flag ini tampil dengan gaya "perlu diedit" di layar review.
  final bool priceGuessed;

  /// Subtotal baris ini = `unitPrice * quantity`.
  MoneyAmount get lineTotal => unitPrice * quantity;

  /// Salinan dengan nilai yang diubah.
  ReceiptCandidateItem copyWith({
    String? name,
    MoneyAmount? unitPrice,
    int? quantity,
    bool? priceGuessed,
  }) {
    return ReceiptCandidateItem(
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      priceGuessed: priceGuessed ?? this.priceGuessed,
    );
  }
}
