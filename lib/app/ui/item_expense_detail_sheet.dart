/// Detail Sheet — Breakdown Expense Mode "Struk" (Skema V2, UI mode item).
///
/// Menampilkan rincian lengkap sebuah expense berjenis [ExpenseSplitType.item]:
/// * Daftar item (nama, qty × harga/unit = subtotal, siapa yang memakannya).
/// * Ringkasan bagian tiap orang (share per user).
///
/// Dibuka via `showModalBottomSheet` dari [_ExpenseTile] di riwayat transaksi
/// saat expense bertipe ITEM di-tap.
library;

import 'package:flutter/material.dart';

import 'package:debt_splitter/app/state/group_detail_store.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:debt_splitter/core/models/expense_with_items.dart';
import 'package:debt_splitter/core/utils/date_formatter.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';

/// Bottom sheet yang memuat dan menampilkan detail item expense mode Struk.
///
/// [expense] = metadata expense (sudah diketahui dari riwayat).
/// [store]   = store grup untuk query `getExpenseWithItems`.
class ItemExpenseDetailSheet extends StatefulWidget {
  const ItemExpenseDetailSheet({
    required this.expense,
    required this.store,
    super.key,
  });

  final Expense expense;
  final GroupDetailStore store;

  @override
  State<ItemExpenseDetailSheet> createState() => _ItemExpenseDetailSheetState();
}

class _ItemExpenseDetailSheetState extends State<ItemExpenseDetailSheet> {
  late Future<ExpenseWithItems> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.getExpenseWithItems(widget.expense.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.expense.note?.isNotEmpty == true
                                ? widget.expense.note!
                                : 'Detail Struk',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${formatRupiah(widget.expense.amount)}  ·  '
                      '${formatDateFromSeconds(widget.expense.date)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body — async.
              Expanded(
                child: FutureBuilder<ExpenseWithItems>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Gagal memuat detail: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    return _DetailBody(
                      data: data,
                      store: widget.store,
                      scrollController: scrollController,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Isi sheet setelah data dimuat: daftar item + ringkasan bagian per orang.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.store,
    required this.scrollController,
  });

  final ExpenseWithItems data;
  final GroupDetailStore store;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameById = store.memberNameById;

    // Hitung share per user dari ItemBillSplitter.
    final shareByUser = data.split(); // Map<userId, amount>

    // Paidby name
    final paidByName = nameById[data.expense.paidBy] ?? '—';

    if (data.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tidak ada data item untuk expense ini.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // --- Seksi: Daftar Item ---
        _SectionHeader(
          icon: Icons.restaurant_menu,
          label: 'Daftar Item Struk',
          color: colorScheme.primary,
        ),
        const SizedBox(height: 8),
        for (final entry in data.items) ...[
          _ItemRow(
            item: entry.item,
            claimantIds: entry.claimantIds,
            nameById: nameById,
          ),
          const SizedBox(height: 6),
        ],
        // Total baris
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ${formatRupiah(data.total())}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 12),
        // --- Seksi: Ringkasan Bagian Per Orang ---
        _SectionHeader(
          icon: Icons.people_outline,
          label: 'Bagian Tiap Orang',
          color: colorScheme.tertiary,
        ),
        const SizedBox(height: 8),
        _ShareSummary(
          shareByUser: shareByUser,
          paidByUserId: data.expense.paidBy,
          paidByName: paidByName,
          nameById: nameById,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Satu baris item struk: nama, qty × harga, subtotal, siapa yang memakannya.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.claimantIds,
    required this.nameById,
  });

  final ExpenseItem item;
  final List<String> claimantIds;
  final Map<String, String> nameById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtotal = item.unitPrice * item.quantity;
    final claimantNames = claimantIds
        .map((id) => nameById[id] ?? id)
        .toList()
      ..sort();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris atas: nama item + subtotal
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatRupiah(subtotal),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          // Baris qty × harga (hanya tampilkan bila qty > 1 atau perlu)
          if (item.quantity > 1 || item.unitPrice != subtotal)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${item.quantity} × ${formatRupiah(item.unitPrice)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 6),
          // Claimant chips
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final name in claimantNames)
                _ClaimantChip(name: name),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClaimantChip extends StatelessWidget {
  const _ClaimantChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Ringkasan bagian per orang dari hasil alokasi ItemBillSplitter.
class _ShareSummary extends StatelessWidget {
  const _ShareSummary({
    required this.shareByUser,
    required this.paidByUserId,
    required this.paidByName,
    required this.nameById,
  });

  final Map<String, int> shareByUser;
  final String paidByUserId;
  final String paidByName;
  final Map<String, String> nameById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Urutkan: paidBy dahulu, lalu alfabet nama.
    final sortedEntries = shareByUser.entries.toList()
      ..sort((a, b) {
        if (a.key == paidByUserId) return -1;
        if (b.key == paidByUserId) return 1;
        final nameA = nameById[a.key] ?? a.key;
        final nameB = nameById[b.key] ?? b.key;
        return nameA.compareTo(nameB);
      });

    return Column(
      children: [
        for (final entry in sortedEntries) ...[
          _ShareRow(
            name: nameById[entry.key] ?? entry.key,
            amount: entry.value,
            isPayer: entry.key == paidByUserId,
            payerName: paidByName,
          ),
          const SizedBox(height: 6),
        ],
        // Catatan pembayar
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$paidByName yang menalangi pembayaran.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.amount,
    required this.isPayer,
    required this.payerName,
  });

  final String name;
  final int amount;
  final bool isPayer;
  final String payerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isPayer
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPayer
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Avatar inisial
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPayer
                  ? colorScheme.primary
                  : colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isPayer
                    ? colorScheme.onPrimary
                    : colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isPayer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Talang',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
