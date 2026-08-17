/// Layar Detail Grup — riwayat transaksi + daftar anggota + Settle Up (Minggu 3).
///
/// Diberi `groupId` + `groupName` via konstruktor. Menyuntikkan
/// [GroupDetailStore] via [ChangeNotifierProvider]agar seluruh subtree dapat
/// membaca/memicu muat-ulang. Dua tab: "Riwayat" (transaksi) & "Pelunasan"
/// (settle up cards + tombol share WhatsApp).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/state/group_detail_store.dart';
import 'package:debt_splitter/app/ui/quick_entry_sheet.dart';
import 'package:debt_splitter/app/ui/settle_up_tab.dart';
import 'package:debt_splitter/app/widgets/user_avatar.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/utils/date_formatter.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    required this.groupId,
    required this.groupName,
    super.key,
  });

  final String groupId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          GroupDetailStore(context.read<DebtSplitterService>(), groupId)
            ..load(),
      child: _GroupDetailScaffold(groupName: groupName),
    );
  }
}

class _GroupDetailScaffold extends StatelessWidget {
  const _GroupDetailScaffold({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(groupName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'Riwayat'),
              Tab(icon: Icon(Icons.handshake), text: 'Pelunasan'),
            ],
          ),
        ),
        body: Consumer<GroupDetailStore>(
          builder: (context, store, _) {
            if (store.isLoading && store.group == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (store.error != null && store.group == null) {
              return _ErrorView(message: store.error!);
            }
            return TabBarView(
              children: [
                _HistoryTab(store: store),
                SettleUpTab(store: store, groupName: groupName),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openQuickEntry(context),
          tooltip: 'Tambah pengeluaran',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _openQuickEntry(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QuickEntrySheet(),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.store});

  final GroupDetailStore store;

  @override
  Widget build(BuildContext context) {
    if (store.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
              SizedBox(height: 12),
              Text(
                'Belum ada transaksi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 4),
              Text('Tekan + untuk mencatat pengeluaran pertama'),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        // Panel ringkasan: total tercatat + daftar anggota.
        _MembersPanel(store: store),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: store.history.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                _ExpenseTile(store: store, item: store.history[i]),
          ),
        ),
      ],
    );
  }
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.store});

  final GroupDetailStore store;

  @override
  Widget build(BuildContext context) {
    final members = store.members;
    // Konservasi: sum(netBalances) == 0, jadi tampilkan total expense instead.
    var totalExpense = 0;
    for (final item in store.history) {
      totalExpense += item.expense.amount;
    }
    return Container(
      width: double.infinity,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total tercatat: ${formatRupiah(totalExpense)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in members) _MemberChip(user: m, store: store),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.user, required this.store});

  final User user;
  final GroupDetailStore store;

  @override
  Widget build(BuildContext context) {
    final balance = store.netBalances[user.id] ?? 0;
    return Chip(
      avatar: UserAvatar(user: user, radius: 12),
      label: Text(
        '${user.name}: ${formatRupiah(balance)}',
        style: TextStyle(
          fontSize: 12,
          color: balance > 0
              ? Colors.green.shade800
              : balance < 0
              ? Colors.red.shade700
              : null,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.store, required this.item});

  final GroupDetailStore store;
  final ExpenseHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final expense = item.expense;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(Icons.payments_outlined),
      ),
      title: Text(
        expense.note == null || expense.note!.isEmpty
            ? 'Pengeluaran'
            : expense.note!,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${item.paidByName} membayar · ${item.shareCount} orang · '
        '${_splitTypeLabel(expense.splitType)}',
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatRupiah(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            formatDateFromSeconds(expense.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      onLongPress: () => _confirmDelete(context),
    );
  }

  String _splitTypeLabel(ExpenseSplitType t) => switch (t) {
    ExpenseSplitType.equal => 'sama rata',
    ExpenseSplitType.exact => 'nominal custom',
    ExpenseSplitType.percent => 'persen',
  };

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text(formatRupiah(item.expense.amount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<GroupDetailStore>().deleteExpense(item.expense.id);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
