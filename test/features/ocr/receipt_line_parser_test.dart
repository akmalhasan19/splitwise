/// Unit test ReceiptLineParser — minimal 20 kasus fixture struk Indonesia.
///
/// Menguji ekstraksi harga, klasifikasi baris, deteksi qty, cross-check
/// total, dan edge cases (baris kosong, header/footer, dll.).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:debt_splitter/features/ocr/receipt_candidate_item.dart';
import 'package:debt_splitter/features/ocr/receipt_line_parser.dart';
import 'package:debt_splitter/features/ocr/receipt_parse_result.dart';

void main() {
  group('ReceiptLineParser.parse', () {
    // ── Kasus 1: Struk warung sederhana ──────────────────────────────
    test('1. Warung sederhana — 2 item + total', () {
      final lines = [
        'WARUNG MAKAN ENAK',
        'Jl. Merdeka No. 10',
        '-------------------',
        'Nasi Goreng    Rp 25.000',
        'Es Teh         Rp 8.000',
        '-------------------',
        'TOTAL          Rp 33.000',
        'TERIMA KASIH',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Nasi Goreng');
      expect(result.items[0].unitPrice, 25000);
      expect(result.items[1].name, 'Es Teh');
      expect(result.items[1].unitPrice, 8000);
      expect(result.totalFromReceipt, 33000);
      expect(result.warnings, isEmpty);
    });

    // ── Kasus 2: Harga tanpa prefix Rp ───────────────────────────────
    test('2. Harga tanpa prefix Rp', () {
      final lines = [
        'Mie Ayam       18.000',
        'Bakso          22.000',
        'TOTAL: 40.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 2);
      expect(result.items[0].unitPrice, 18000);
      expect(result.items[1].unitPrice, 22000);
      expect(result.totalFromReceipt, 40000);
    });

    // ── Kasus 3: Format Rp25.000 (tanpa spasi) ──────────────────────
    test('3. Format Rp25.000 tanpa spasi', () {
      final lines = [
        'Kopi Susu      Rp25.000',
        'TOTAL Rp25.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 25000);
    });

    // ── Kasus 4: Harga dengan suffix ",-" ────────────────────────────
    test('4. Harga dengan suffix ",-"', () {
      final lines = [
        'Nasi Uduk      Rp 15.000,-',
        'Kerupuk        Rp 5.000,-',
        'TOTAL Rp 20.000,-',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 2);
      expect(result.items[0].unitPrice, 15000);
      expect(result.items[1].unitPrice, 5000);
      expect(result.totalFromReceipt, 20000);
    });

    // ── Kasus 5: Kuantitas prefix "2x" ──────────────────────────────
    test('5. Deteksi kuantitas prefix 2x', () {
      final lines = [
        '2 x Nasi Goreng  Rp 25.000',
        '1 x Es Teh       Rp 8.000',
        'TOTAL Rp 58.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Nasi Goreng');
      expect(result.items[0].quantity, 2);
      expect(result.items[0].unitPrice, 25000);
      expect(result.items[1].quantity, 1);
      expect(result.totalFromReceipt, 58000);
    });

    // ── Kasus 6: Harga Rp 1.250.000 (jutaan) ───────────────────────
    test('6. Harga jutaan dengan ribuan', () {
      final lines = [
        'Paket Hemat     Rp 1.250.000',
        'TOTAL Rp 1.250.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 1250000);
    });

    // ── Kasus 7: Total tidak cocok → warning ────────────────────────
    test('7. Total tidak cocok menghasilkan warning', () {
      final lines = [
        'Nasi Goreng    Rp 25.000',
        'Es Teh         Rp 8.000',
        'TOTAL          Rp 40.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.itemsTotal, 33000);
      expect(result.totalFromReceipt, 40000);
      expect(result.hasTotalMismatch, isTrue);
      expect(result.warnings.length, 1);
      expect(result.warnings[0], contains('tidak cocok'));
    });

    // ── Kasus 8: Baris header/footer dibuang ─────────────────────────
    test('8. Header dan footer dibuang', () {
      final lines = [
        'WARUNG BAHARI',
        'Jl. Sudirman No. 5',
        'TLP: 021-12345',
        'SELAMAT DATANG',
        'Nasi Goreng    Rp 25.000',
        'TOTAL Rp 25.000',
        'TERIMA KASIH',
        'KASIR: BUDI',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Nasi Goreng');
    });

    // ── Kasus 9: Baris BATAL/RETUR dilewati ──────────────────────────
    test('9. Baris BATAL tidak menjadi item', () {
      final lines = [
        'Nasi Goreng    Rp 25.000',
        'BATAL Nasi     Rp 25.000',
        'TOTAL Rp 0',
      ];
      final result = ReceiptLineParser.parse(lines);

      // Baris BATAL mengandung "BATAL" → skip
      // Hanya Nasi Goreng yang lolos
      expect(result.items.length, 1);
      expect(result.items[0].name, 'Nasi Goreng');
    });

    // ── Kasus 10: Subtotal dan total ─────────────────────────────────
    test('10. SUBTOTAL dan TOTAL keduanya terdeteksi', () {
      final lines = [
        'Nasi Goreng    Rp 25.000',
        'Es Teh         Rp 8.000',
        'SUBTOTAL Rp 33.000',
        'PAJAK 10%      Rp 3.300',
        'TOTAL Rp 36.300',
      ];
      final result = ReceiptLineParser.parse(lines);

      // PAJAK/PPN termasuk skip pattern → tidak jadi item
      expect(result.items.length, 2);
      // Total dari yang terakhir (TOTAL meng-override SUBTOTAL)
      expect(result.totalFromReceipt, 36300);
    });

    // ── Kasus 11: Struk kosong ───────────────────────────────────────
    test('11. Input kosong menghasilkan result kosong', () {
      final result = ReceiptLineParser.parse([]);

      expect(result.items, isEmpty);
      expect(result.totalFromReceipt, isNull);
      expect(result.warnings, isEmpty);
    });

    // ── Kasus 12: Harga koma sebagai desimal ─────────────────────────
    test('12. Harga dengan koma', () {
      final lines = [
        'Es Jeruk       Rp 12,500',
        'TOTAL Rp 12.500',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 12500);
    });

    // ── Kasus 13: Format 25,000 (koma pemisah ribuan) ───────────────
    test('13. Format koma sebagai pemisah ribuan', () {
      final lines = [
        'Item A         25,000',
        'TOTAL 25,000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 25000);
    });

    // ── Kasus 14: Nama item 2 baris ──────────────────────────────────
    test('14. Nama item 2 baris (baris tanpa harga)', () {
      final lines = [
        'Nasi Goreng',
        'Spesial        Rp 30.000',
        'TOTAL Rp 30.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      // Nama tergabung dari 2 baris
      expect(result.items[0].name, contains('Nasi Goreng'));
      expect(result.items[0].unitPrice, 30000);
    });

    // ── Kasus 15: Banyak item (8+) ──────────────────────────────────
    test('15. Struk dengan banyak item', () {
      final lines = [
        'Nasi Goreng    Rp 25.000',
        'Mie Ayam       Rp 18.000',
        'Bakso          Rp 22.000',
        'Es Teh         Rp 8.000',
        'Es Jeruk       Rp 10.000',
        'Kerupuk        Rp 5.000',
        'Kopi Susu      Rp 22.000',
        'Pisang Goreng  Rp 12.000',
        'TOTAL Rp 122.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 8);
      expect(result.totalFromReceipt, 122000);
      expect(result.warnings, isEmpty);
    });

    // ── Kasus 16: Harga satuan Rp 5.000 ─────────────────────────────
    test('16. Harga kecil (Rp 5.000)', () {
      final lines = [
        'Kerupuk        Rp 5.000',
        'TOTAL Rp 5.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 5000);
    });

    // ── Kasus 17: Garis dekoratif diabaikan ──────────────────────────
    test('17. Garis dekoratif diabaikan', () {
      final lines = [
        '===================',
        'Nasi Goreng    Rp 25.000',
        '===================',
        'TOTAL Rp 25.000',
        '*******************',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
    });

    // ── Kasus 18: Total tanpa item (edge case) ───────────────────────
    test('18. Total tanpa item yang valid', () {
      final lines = [
        'WARUNG ABC',
        'TOTAL Rp 50.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items, isEmpty);
      expect(result.totalFromReceipt, 50000);
    });

    // ── Kasus 19: Qty suffix "Nasi Goreng 2" ────────────────────────
    test('19. Qty suffix pada baris tanpa harga', () {
      final lines = [
        'Nasi Goreng    Rp 25.000',
        'Es Teh         2',
        'TOTAL Rp 41.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 2);
      // Baris kedua "Es Teh 2" — pending name "Es Teh" + qty suffix
      expect(result.items[1].name, 'Es Teh');
    });

    // ── Kasus 20: priceGuessed untuk item tanpa harga ────────────────
    test('20. Item tanpa harga ditandai priceGuessed', () {
      final lines = [
        'Nasi Goreng    Rp 25.000',
        'Mystery Item',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 2);
      expect(result.items[0].priceGuessed, isFalse);
      expect(result.items[1].priceGuessed, isTrue);
      expect(result.items[1].unitPrice, 0);
    });

    // ── Kasus 21: Format "Rp. 25.000" (titik setelah Rp) ────────────
    test('21. Format Rp. (titik) setelah prefix', () {
      final lines = [
        'Kopi Hitam      Rp. 15.000',
        'TOTAL Rp. 15.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 15000);
    });

    // ── Kasus 22: Harga besar 1.000.000 ─────────────────────────────
    test('22. Harga satu juta', () {
      final lines = [
        'Paket VIP       Rp 1.000.000',
        'TOTAL Rp 1.000.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 1000000);
    });

    // ── Kasus 23: Baris tanggal dan jam dilewati ─────────────────────
    test('23. Baris tanggal dan jam dilewati', () {
      final lines = [
        '18/08/2026',
        '14:30',
        'Nasi Goreng    Rp 25.000',
        'TOTAL Rp 25.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
    });

    // ── Kasus 24: Nama item dengan karakter khusus ───────────────────
    test('24. Nama item dengan underscore/star', () {
      final lines = [
        '___Nasi Goreng___    Rp 25.000',
        'TOTAL Rp 25.000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Nasi Goreng');
    });

    // ── Kasus 25: Harga dengan spasi pemisah ribuan ─────────────────
    test('25. Harga dengan spasi sebagai pemisah ribuan', () {
      final lines = [
        'Nasi Goreng    25 000',
        'TOTAL 25 000',
      ];
      final result = ReceiptLineParser.parse(lines);

      expect(result.items.length, 1);
      expect(result.items[0].unitPrice, 25000);
    });
  });

  group('ReceiptCandidateItem', () {
    test('lineTotal menghitung unitPrice * quantity', () {
      final item = ReceiptCandidateItem(
        name: 'Nasi Goreng',
        unitPrice: 25000,
        quantity: 2,
      );
      expect(item.lineTotal, 50000);
    });

    test('copyWith mempertahankan nilai sebelumnya', () {
      final item = ReceiptCandidateItem(
        name: 'Nasi Goreng',
        unitPrice: 25000,
        quantity: 1,
      );
      final edited = item.copyWith(unitPrice: 30000);
      expect(edited.unitPrice, 30000);
      expect(edited.name, 'Nasi Goreng');
    });
  });

  group('ReceiptParseResult', () {
    test('itemsTotal menjumlahkan semua item', () {
      final result = ReceiptParseResult(
        items: [
          ReceiptCandidateItem(name: 'A', unitPrice: 10000, quantity: 2),
          ReceiptCandidateItem(name: 'B', unitPrice: 5000, quantity: 1),
        ],
        totalFromReceipt: 25000,
      );
      expect(result.itemsTotal, 25000);
    });

    test('hasTotalMismatch true saat beda', () {
      final result = ReceiptParseResult(
        items: [
          ReceiptCandidateItem(name: 'A', unitPrice: 10000),
        ],
        totalFromReceipt: 20000,
      );
      expect(result.hasTotalMismatch, isTrue);
    });

    test('hasGuessedItems true bila ada item priceGuessed', () {
      final result = ReceiptParseResult(
        items: [
          ReceiptCandidateItem(name: 'A', unitPrice: 10000),
          ReceiptCandidateItem(
            name: 'B',
            unitPrice: 0,
            priceGuessed: true,
          ),
        ],
        totalFromReceipt: 10000,
      );
      expect(result.hasGuessedItems, isTrue);
    });
  });
}
