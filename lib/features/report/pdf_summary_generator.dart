/// Generator laporan ringkasan PDF — Phase 2, Minggu 4, Task 2
/// (Fitur Cetak PDF *summary report*).
///
/// Membangun dokumen PDF (A4) dari [GroupSummarySnapshot] (data yang sama
/// dengan generator WhatsApp, agar laporan konsisten): judul grup, tanggal,
/// total tercatat, saldo per anggota, dan rekomendasi pelunasan (Settle Up).
///
/// Seluruh nominal memakai [formatRupiah] dari `MoneyAmount` (`int`) — tidak
/// ada `double`/`float` pada representasi uang. PDF dibuat **offline** (paket
/// `pdf` murni client-side), lalu file-nya dibagikan via OS Share Sheet
/// (lihat `lib/app/`).
library;

import 'dart:typed_data';

import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/utils/date_formatter.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';
import 'package:debt_splitter/features/share/whatsapp_summary_generator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfSummaryGenerator {
  const PdfSummaryGenerator._();

  /// Menghasilkan byte dokumen PDF ringkasan [snapshot].
  static Future<Uint8List> generate(GroupSummarySnapshot snapshot) async {
    final doc = pw.Document(title: 'Ringkasan ${snapshot.group.name}');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => _buildContent(snapshot),
      ),
    );
    return doc.save();
  }

  static pw.Widget _buildContent(GroupSummarySnapshot snapshot) {
    final group = snapshot.group;
    final nameById = {for (final m in snapshot.members) m.id: m.name};

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Debt-Splitter — Ringkasan Patungan',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          group.name,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Total tercatat: ${formatRupiah(snapshot.totalExpenseAmount)}',
          style: pw.TextStyle(fontSize: 13, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 16),

        // ----- Saldo per anggota -----
        pw.Text(
          'Saldo per anggota',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['Anggota', 'Saldo', 'Status'],
          data: [
            for (final member in _sortedMembers(snapshot)) ...[
              [
                member.name,
                formatRupiah(snapshot.netBalances[member.id] ?? 0),
                _balanceStatus(snapshot.netBalances[member.id] ?? 0),
              ],
            ],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.green700,
          ),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.center,
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.5,
          ),
        ),
        pw.SizedBox(height: 20),

        // ----- Rekomendasi pelunasan -----
        pw.Text(
          'Cara pelunasan (Settle Up)',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (snapshot.settlements.isEmpty)
          pw.Text(
            '✅ Semua tuntas — tidak ada transaksi pelunasan tersisa.',
            style: const pw.TextStyle(fontSize: 12),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Debitur', 'Kreditur', 'Nominal'],
            data: [
              for (var i = 0; i < snapshot.settlements.length; i++) ...[
                [
                  '${i + 1}',
                  nameById[snapshot.settlements[i].debtorId] ??
                      _shortId(snapshot.settlements[i].debtorId),
                  nameById[snapshot.settlements[i].creditorId] ??
                      _shortId(snapshot.settlements[i].creditorId),
                  formatRupiah(snapshot.settlements[i].amount),
                ],
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.green700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),

        pw.SizedBox(height: 24),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Text(
          'Dibuat oleh Debt-Splitter (offline) — '
          '${formatDateFromSeconds(DateTime.now().millisecondsSinceEpoch ~/ 1000)}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static List<User> _sortedMembers(GroupSummarySnapshot snapshot) {
    final members = [...snapshot.members]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }

  static String _balanceStatus(int balance) {
    if (balance > 0) return 'akan menerima';
    if (balance < 0) return 'berhutang';
    return 'lunas';
  }

  static String _shortId(String id) => id.length <= 4 ? id : id.substring(0, 4);
}
