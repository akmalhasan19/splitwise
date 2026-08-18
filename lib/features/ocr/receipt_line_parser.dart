/// ReceiptLineParser — pure function: teks OCR → kandidat item struk.
///
/// Tidak ada I/O, tidak ada side-effect, 100% unit-testable.
/// Mengonversi baris-baris teks hasil ML Kit Text Recognition menjadi
/// daftar [ReceiptCandidateItem] yang siap ditampilkan di layar review.
///
/// Strategi parsing (lihat `docs/plan_phase5_ocr_scan_struk.md` §2.4):
/// 1. Ekstraksi harga (integer Rupiah) via regex — semua varian format IDR.
/// 2. Klasifikasi baris: header/footer dibuang, item = nama + harga,
///    baris tanpa harga = lanjutan nama, total/struktur dipakai cross-check.
/// 3. Deteksi kuantitas: pola `2x`, `2X`, `x2`, atau nama berulang.
/// 4. Cross-check total: `sum(item × qty)` vs baris TOTAL.
library;

import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/features/ocr/receipt_candidate_item.dart';
import 'package:debt_splitter/features/ocr/receipt_parse_result.dart';

class ReceiptLineParser {
  const ReceiptLineParser._();

  // ── Pola harga dengan prefix Rp ─────────────────────────────────────
  // Menangkap: "Rp 25.000", "Rp25.000", "Rp. 25.000", "Rp 25,000"
  // Grup 1 = angka mentah (tanpa prefix Rp)
  static final RegExp _priceWithPrefix = RegExp(
    r'Rp\.?\s*(\d[\d.,]*\d)',
    caseSensitive: false,
  );

  // ── Pola harga tanpa prefix (angka mentah dengan pemisah ribuan) ───
  // Menangkap: "25.000", "25,000", "1.250.000", "25 000"
  // Hanya match jika ada pemisah (titik/koma/spasi) di dalam angka
  static final RegExp _barePricePattern = RegExp(
    r'(\d{1,3}(?:[.,\s]\d{3,})+)',
  );

  // ── Pola kuantitas ─────────────────────────────────────────────────
  // "2 x Nasi", "2X Nasi", "x2 Nasi", "2x"
  static final RegExp _qtyPrefixPattern = RegExp(
    r'^(\d+)\s*[xX]\s*',
  );

  // ── Pola angka qty di akhir baris ──────────────────────────────────
  // "Nasi Goreng 2" → qty=2
  static final RegExp _qtySuffixPattern = RegExp(
    r'\s+(\d{1,2})\s*$',
  );

  // ── Baris noise/header/footer (DILUAR total) ───────────────────────
  // CATATAN: TOTAL/SUBTOTAL TIDAK di sini — ditangani terpisah.
  static final List<RegExp> _skipPatterns = [
    RegExp(r'^(WARUNG|TOKO|RESTO|CAFE|KEDAI|RM\b|RESTORAN)', caseSensitive: false),
    RegExp(r'(Jl\.|Jalan|Gang|Gg\.|No\.\s*\d)', caseSensitive: false),
    RegExp(r'(TLP|TELP|PHONE|HOTLINE|WA\s*:)', caseSensitive: false),
    RegExp(r'(TERIMA\s*KASIH|SELAMAT\s*(DATANG|MAKAN))', caseSensitive: false),
    RegExp(r'(STRUK\s*(BELANJA|PEMBELIAN|TRANSAKSI))', caseSensitive: false),
    RegExp(r'(KASIR|CAPIE|KREDIT|DEBIT|TUNAI|CASH)', caseSensitive: false),
    RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}'), // tanggal
    RegExp(r'^\d{1,2}:\d{2}'), // jam
    RegExp(r'(PPN|DPP|PAJAK|TAX|SERVICE|CHARGE|DISC|POTONGAN)', caseSensitive: false),
    RegExp(r'(BAYAR|BATAL|RETUR|VOID|REFUND)', caseSensitive: false),
    RegExp(r'(KEMBALI|CHANGE)', caseSensitive: false),
    RegExp(r'(kartu|card|member|point)', caseSensitive: false),
    RegExp(r'^\*+$'), // garis bintang
    RegExp(r'^[-=_]{3,}$'), // garis pemisah (seluruh baris)
  ];

  // ── Pola baris total ───────────────────────────────────────────────
  static final RegExp _totalPattern = RegExp(
    r'(SUBTOTAL|GRAND\s*TOTAL|TOTAL|NETT|NET\b)',
    caseSensitive: false,
  );

  /// Entry point: parsing daftar baris teks OCR menjadi [ReceiptParseResult].
  static ReceiptParseResult parse(List<String> lines) {
    final items = <ReceiptCandidateItem>[];
    MoneyAmount? totalFromReceipt;
    final warnings = <String>[];
    String? pendingName; // nama item 2 baris (baris sebelumnya tanpa harga)

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;

      // 1. Deteksi baris total DULU (sebelum skip)
      if (_totalPattern.hasMatch(raw)) {
        final price = _extractPrice(raw);
        if (price != null && price > 0) {
          totalFromReceipt = price;
        }
        // Total memutus rantai pending name
        pendingName = null;
        continue;
      }

      // 2. Skip baris noise/header/footer
      if (_shouldSkip(raw)) {
        pendingName = null;
        continue;
      }

      // 3. Coba ekstrak harga dari baris
      final price = _extractPrice(raw);

      if (price != null && price > 0) {
        var name = _extractName(raw);
        var qty = 1;

        // Cek pola qty prefix: "2x Nasi Goreng"
        final qtyMatch = _qtyPrefixPattern.firstMatch(raw);
        if (qtyMatch != null) {
          qty = int.parse(qtyMatch.group(1)!);
          name = name.replaceFirst(qtyMatch.group(0)!, '').trim();
        }

        // Gabungkan dengan pending name dari baris sebelumnya
        if (pendingName != null) {
          name = pendingName;
          pendingName = null;
        }

        if (name.isNotEmpty) {
          items.add(ReceiptCandidateItem(
            name: name,
            unitPrice: price,
            quantity: qty,
          ));
        }
      } else {
        // Baris tanpa harga
        var cleanName = raw.replaceAll(RegExp(r'[_*#]+'), '').trim();
        if (cleanName.isEmpty) {
          pendingName = null;
          continue;
        }

        // Cek qty suffix: "Es Teh         2"
        final qtyMatch = _qtySuffixPattern.firstMatch(cleanName);
        if (qtyMatch != null) {
          final possibleQty = int.tryParse(qtyMatch.group(1)!);
          if (possibleQty != null && possibleQty > 1 && possibleQty <= 99) {
            final namePart = cleanName.substring(0, qtyMatch.start).trim();
            final effectiveName = namePart.isNotEmpty
                ? namePart
                : (pendingName ?? '');
            if (effectiveName.isNotEmpty) {
              items.add(ReceiptCandidateItem(
                name: effectiveName,
                unitPrice: 0,
                quantity: possibleQty,
                priceGuessed: true,
              ));
              pendingName = null;
              continue;
            }
          }
        }

        // Baris tanpa harga → mungkin lanjutan nama item sebelumnya
        if (pendingName != null) {
          pendingName = '$pendingName $cleanName';
        } else {
          pendingName = cleanName;
        }
      }
    }

    // Flush sisa pending name (item tanpa harga di akhir)
    if (pendingName != null && pendingName.isNotEmpty) {
      items.add(ReceiptCandidateItem(
        name: pendingName,
        unitPrice: 0,
        priceGuessed: true,
      ));
    }

    // Cross-check total
    if (totalFromReceipt != null && items.isNotEmpty) {
      var itemsTotal = 0;
      for (final item in items) {
        itemsTotal += item.lineTotal;
      }
      if (itemsTotal != totalFromReceipt) {
        warnings.add(
          'Total item ($itemsTotal) tidak cocok dengan TOTAL struk '
          '($totalFromReceipt). Periksa kembali.',
        );
      }
    }

    return ReceiptParseResult(
      items: items,
      totalFromReceipt: totalFromReceipt,
      warnings: warnings,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Memeriksa apakah baris harus dibuang (header, footer, noise).
  static bool _shouldSkip(String line) {
    final upper = line.toUpperCase();
    for (final pattern in _skipPatterns) {
      if (pattern.hasMatch(upper) || pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  /// Mengekstrak harga dari baris teks (integer Rupiah utuh).
  static MoneyAmount? _extractPrice(String line) {
    // Coba dengan prefix Rp dulu
    var match = _priceWithPrefix.firstMatch(line);
    if (match != null) {
      return _parseRupiah(match.group(1)!);
    }

    // Coba angka mentah dengan pemisah ribuan
    match = _barePricePattern.firstMatch(line);
    if (match != null) {
      return _parseRupiah(match.group(1)!);
    }

    return null;
  }

  /// Mengonversi string harga mentah ke integer Rupiah.
  static MoneyAmount _parseRupiah(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[^\d.,]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[,.-]+$'), '');
    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      return int.tryParse(parts.join()) ?? 0;
    }

    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      return int.tryParse(parts.join()) ?? 0;
    }

    return int.tryParse(cleaned) ?? 0;
  }

  /// Mengekstrak nama item dari baris (teks sebelum harga).
  static String _extractName(String line) {
    var name = line
        .replaceAll(_priceWithPrefix, '')
        .replaceAll(_barePricePattern, '')
        .replaceAll(RegExp(r'[-–—]+$'), '')
        .trim();

    // Buang karakter dekoratif di awal/akhir
    name = name.trim();
    while (name.isNotEmpty &&
        '_*#-–— '.contains(name[0])) {
      name = name.substring(1);
    }
    while (name.isNotEmpty &&
        '_*#-–— '.contains(name[name.length - 1])) {
      name = name.substring(0, name.length - 1);
    }
    name = name.trim();

    return name;
  }
}
