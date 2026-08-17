/// Generator ringkasan utang format WhatsApp — Phase 2, Minggu 3, Task 4.
///
/// Membaca data final sebuah grup (saldo per anggota + rekomendasi pelunasan
/// keluaran `DebtSimplifierEngine`) lalu merangkainya menjadi **teks ringkas
/// siap tempel ke WhatsApp** — memakai formatasi WhatsApp (asterisk `*bold*`,
/// emoji) tanpa markdown工具 eksternal.
///
/// Pure function: tidak menyentuh I/O, DB, atau jaringan. Diberi snapshot data
/// domain (`Group`, `User`, net balance, [SettlementPayment]) — diuji via
/// unit test. Integrasi ke Share Sheet ditangani `lib/app/` / layar UI,
/// memakai `share_plus` (`Share.share`).
library;

import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';

/// DTO snapshot data grup yang dibutuhkan generator ringkasan.
///
/// Diproduksi oleh service/repo layer (UI hanya menyatukan data), sehingga
/// generator tetap pure-function & mudah diuji tanpa DB.
class GroupSummarySnapshot {
  const GroupSummarySnapshot({
    required this.group,
    required this.members,
    required this.netBalances,
    required this.settlements,
    required this.totalExpenseAmount,
  });

  final Group group;

  /// Seluruh anggota grup (untuk resolusi id -> nama).
  final List<User> members;

  /// `userId -> net balance` ( keluaran `NetBalanceCalculator.calculateBalances`).
  final Map<String, MoneyAmount> netBalances;

  /// Rekomendasi pelunasan (keluaran `DebtSimplifierEngine.settle`).
  final List<SettlementPayment> settlements;

  /// Total seluruh nominal expense dalam grup (untuk barik "Total tercatat").
  final MoneyAmount totalExpenseAmount;
}

class WhatsAppSummaryGenerator {
  const WhatsAppSummaryGenerator._();

  /// Membangun teks ringkasan patungan siap-bagi ke WhatsApp.
  ///
  /// Format (whatsapp-flavored, asterisk = *bold*):
  ///
  /// ```
  /// *Debt-Splitter — Trip Bromo*
  /// 📊 Total tercatat: Rp1.234.000
  ///
  /// *Saldo per anggota:*
  /// • Andi: Rp+66.666 (akan menerima)
  /// • Budi: Rp-33.333 (berhutang)
  ///
  /// *Cara pelunasan (Settle Up):*
  /// 1️⃣ Budi transfer Rp33.333 ke Andi
  ///
  /// ✅ Semua tuntas — tidak ada transaksi tersisa.
  /// ```
  static String generate(GroupSummarySnapshot snapshot) {
    final group = snapshot.group;
    final nameById = {for (final m in snapshot.members) m.id: m.name};

    final buffer = StringBuffer()
      ..writeAll([
        '*Debt-Splitter — ${group.name}*\n',
        '📊 Total tercatat: ${formatRupiah(snapshot.totalExpenseAmount)}\n',
        '\n',
      ]);

    // Bagian saldo per anggota (urut nama).
    buffer.writeln('*Saldo per anggota:*');
    final sortedMembers = [...snapshot.members]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (sortedMembers.isEmpty) {
      buffer.writeln('_(belum ada anggota)_');
    } else {
      for (final member in sortedMembers) {
        final balance = snapshot.netBalances[member.id] ?? 0;
        buffer.writeln('• ${member.name}: ${_formatBalance(balance)}');
      }
    }

    // Bagian rekomendasi pelunasan.
    buffer.writeln('\n*Cara pelunasan (Settle Up):*');
    if (snapshot.settlements.isEmpty) {
      buffer.writeln('✅ Semua tuntas — tidak ada transaksi tersisa.');
    } else {
      for (var i = 0; i < snapshot.settlements.length; i++) {
        final s = snapshot.settlements[i];
        final debtor = nameById[s.debtorId] ?? _shortId(s.debtorId);
        final creditor = nameById[s.creditorId] ?? _shortId(s.creditorId);
        buffer.writeln(
          '${_numberEmoji(i + 1)} $debtor transfer ${formatRupiah(s.amount)} '
          'ke $creditor',
        );
      }
      buffer.writeln(
        '\n✅ Total ${snapshot.settlements.length} transaksi pelunasan.',
      );
    }

    buffer.writeln('\n— Dibuat oleh Debt-Splitter (offline)');
    return buffer.toString();
  }

  /// `Rp+66.666 (akan menerima)` / `Rp-33.333 (berhutang)` / `Rp0 (lunas)`.
  static String _formatBalance(MoneyAmount balance) {
    if (balance == 0) return '${formatRupiah(0)} (lunas)';
    final sign = balance > 0 ? '+' : '';
    final role = balance > 0 ? '(akan menerima)' : '(berhutang)';
    return '${formatRupiah(balance, symbol: 'Rp$sign')} $role';
  }

  /// 1..N -> emoji keycap berurutan (1️⃣ 2️⃣ …); di luar jangkauan kembali
  /// ke `'N.'`. Dipakai untuk menomori baris rekomendasi pelunasan.
  static String _numberEmoji(int n) {
    const keycaps = <String>[
      '0️⃣',
      '1️⃣',
      '2️⃣',
      '3️⃣',
      '4️⃣',
      '5️⃣',
      '6️⃣',
      '7️⃣',
      '8️⃣',
      '9️⃣',
    ];
    if (n <= 0) return '$n.';
    final digits = n.toString();
    final out = StringBuffer();
    for (final d in digits.codeUnits) {
      final idx = d - 0x30; // '0' == 0x30
      if (idx >= 0 && idx <= 9) {
        out.write(keycaps[idx]);
      }
    }
    return out.toString();
  }

  /// Memendangkan UUID menjadi 4 karakter depan (fallback bila nama tidak ada).
  static String _shortId(String id) => id.length <= 4 ? id : id.substring(0, 4);
}
