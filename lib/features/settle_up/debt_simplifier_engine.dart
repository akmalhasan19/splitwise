/// Greedy Settlement Engine — Phase 2, Minggu 2, Task 2.
///
/// Menerima peta `net_balance[user]` (output `NetBalanceCalculator`) lalu
/// menghasilkan daftar transaksi rekomendasi pelunasan dengan jumlah transaksi
/// seminimal mungkin.
///
/// Algoritma (O(n log n), memakai dua Max-Heap dari `package:collection`):
/// 1. Pisahkan **Kreditur** (`balance > 0`) dan **Debitur** (`balance < 0`).
/// 2. Ambil kreditur dengan piutang terbesar (`max_creditor`) dan debitur
///    dengan `|utang|` terbesar (`max_debtor`).
/// 3. Hitung `settle_amount = min(max_creditor.balance, |max_debtor.balance|)`.
/// 4. Buat objek rekomendasi pelunasan: `max_debtor -> max_creditor:
///    settle_amount` ([SettlementPayment]).
/// 5. Update saldo kedua pihak; bila masih tersisa, masukkan kembali ke heap.
/// 6. Ulangi sampai seluruh saldo net bernilai 0.
///
/// Modul terisolasi & **pure function** — bebas side-effect (tanpa I/O, tanpa
/// DB, tanpa randomness); seluruh nominal `int` (tanpa `double`/`float`).
///
/// Hasil **deterministik**: untuk nominal yang sama, `userId` terkecil
/// (lexicographic) diproses duluan — aman untuk unit-test snapshot.
library;

import 'package:collection/collection.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

/// Rekomendasi satu transaksi pelunasan keluaran greedy engine.
///
/// Dibaca sebagai: **[debtorId] transfer [amount] ke [creditorId]**.
class SettlementPayment {
  const SettlementPayment({
    required this.debtorId,
    required this.creditorId,
    required this.amount,
  });

  /// User yang wajib membayar (net balance negatif).
  final String debtorId;

  /// User yang berhak menerima (net balance positif).
  final String creditorId;

  /// Nominal transfer — INTEGER satuan Rupiah, tanpa desimal.
  final MoneyAmount amount;

  @override
  bool operator ==(Object other) =>
      other is SettlementPayment &&
      other.debtorId == debtorId &&
      other.creditorId == creditorId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(debtorId, creditorId, amount);

  @override
  String toString() =>
      'SettlementPayment($debtorId -> $creditorId: Rp$amount)';
}

/// Entri internal heap: seorang user + balance (piutang/utang) miliknya.
class _HeapEntry {
  const _HeapEntry(this.userId, this.balance);

  final String userId;

  /// Untuk kreditur bernilai `> 0`, untuk debitur bernilai `< 0`.
  final MoneyAmount balance;
}

class DebtSimplifierEngine {
  const DebtSimplifierEngine._();

  /// Menyelesaikan seluruh saldo pada [netBalances] menjadi daftar
  /// [SettlementPayment] rekomendasi.
  ///
  /// Kontrak input:
  /// * [netBalances] = peta `userId -> balance` (dari
  ///   `NetBalanceCalculator.calculateBalances`);
  /// * peta kosong / seluruh saldo `0` dikembalikan sebagai `[]`;
  /// * **konservasi uang**: `sum(netBalances.values) == 0` wajib dipenuhi.
  ///   Pelanggaran melempar [ArgumentError] agar data korup tidak masuk engine.
  static List<SettlementPayment> settle(Map<String, MoneyAmount> netBalances) {
    _validateBalances(netBalances);

    // Max-Heap Kreditur: piutang terbesar (balance > 0) keluar pertama.
    final creditors = PriorityQueue<_HeapEntry>(_creditorComparator);
    // Max-Heap Debitur: |utang| terbesar (balance < 0) keluar pertama.
    final debtors = PriorityQueue<_HeapEntry>(_debtorComparator);

    for (final entry in netBalances.entries) {
      if (entry.value > 0) {
        creditors.add(_HeapEntry(entry.key, entry.value));
      } else if (entry.value < 0) {
        debtors.add(_HeapEntry(entry.key, entry.value));
      }
      // Balance 0 diabaikan (tidak perlu membayar maupun menerima).
    }

    final settlements = <SettlementPayment>[];
    while (creditors.isNotEmpty) {
      assert(
        debtors.isNotEmpty,
        'Invariant: selama kreditur tersisa, debitur pasti juga tersisa.',
      );

      final creditor = creditors.removeFirst();
      final debtor = debtors.removeFirst();
      final debtorAbsBalance = -debtor.balance;
      final settleAmount =
          creditor.balance <= debtorAbsBalance
              ? creditor.balance
              : debtorAbsBalance;

      settlements.add(
        SettlementPayment(
          debtorId: debtor.userId,
          creditorId: creditor.userId,
          amount: settleAmount,
        ),
      );

      // Update saldo kedua pihak; sisa > 0 dimasukkan kembali ke heap.
      final creditorRemaining = creditor.balance - settleAmount;
      final debtorRemaining = debtor.balance + settleAmount;

      if (creditorRemaining > 0) {
        creditors.add(_HeapEntry(creditor.userId, creditorRemaining));
      }
      if (debtorRemaining < 0) {
        debtors.add(_HeapEntry(debtor.userId, debtorRemaining));
      }
    }

    assert(
      debtors.isEmpty,
      'Konservasi: seluruh balance harus saling menutup sampai nol.',
    );
    return settlements;
  }

  /// Menegakkan kontrak konservasi uang: `sum(balance) == 0`.
  static void _validateBalances(Map<String, MoneyAmount> netBalances) {
    var total = 0;
    for (final balance in netBalances.values) {
      total += balance;
    }
    if (total != 0) {
      throw ArgumentError.value(
        netBalances,
        'netBalances',
        'Total seluruh balance harus 0 (konservasi uang), ditemukan $total.',
      );
    }
  }

  /// Max-heap kreditur: `balance` terbesar keluar pertama; bila sama besar,
  /// `userId` terkecil (lexicographic) keluar pertama (tie-break deterministik).
  static int _creditorComparator(_HeapEntry a, _HeapEntry b) {
    final byBalance = b.balance.compareTo(a.balance);
    if (byBalance != 0) {
      return byBalance;
    }
    return a.userId.compareTo(b.userId);
  }

  /// Max-heap debitur: `|balance|` terbesar keluar pertama (seluruh nilai
  /// selalu negatif); bila sama besar, `userId` terkecil (lexicographic)
  /// keluar pertama.
  static int _debtorComparator(_HeapEntry a, _HeapEntry b) {
    final byAbsBalance = (-b.balance).compareTo(-a.balance);
    if (byAbsBalance != 0) {
      return byAbsBalance;
    }
    return a.userId.compareTo(b.userId);
  }
}