/// Hasil parsing OCR struk — daftar item kandidat + total dari struk + warning.
///
/// Dikembalikan oleh [ReceiptLineParser.parse] sebagai output dari pipeline
/// ekstraksi baris teks OCR menjadi struktur data terstruktur.
library;

import 'package:debt_splitter/features/ocr/receipt_candidate_item.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

class ReceiptParseResult {
  const ReceiptParseResult({
    required this.items,
    required this.totalFromReceipt,
    this.warnings = const [],
  });

  /// Daftar item yang berhasil diekstrak dari struk.
  final List<ReceiptCandidateItem> items;

  /// Total yang tertera di baris TOTAL/SUBTOTAL struk (bila terdeteksi).
  /// `null` bila tidak ditemukan baris total.
  final MoneyAmount? totalFromReceipt;

  /// Daftar pesan warning (mis. ketidakcocokan total).
  final List<String> warnings;

  /// Total seluruh item hasil ekstraksi = `sum(unitPrice * quantity)`.
  MoneyAmount get itemsTotal {
    var total = 0;
    for (final item in items) {
      total += item.lineTotal;
    }
    return total;
  }

  /// `true` bila total item tidak cocok dengan total struk.
  bool get hasTotalMismatch =>
      totalFromReceipt != null && itemsTotal != totalFromReceipt;

  /// `true` bila ada item yang perlu verifikasi manual.
  bool get hasGuessedItems => items.any((item) => item.priceGuessed);
}
