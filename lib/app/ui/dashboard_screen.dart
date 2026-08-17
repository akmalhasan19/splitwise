/// Layar Dashboard — daftar grup & ringkasan total saldo (Minggu 3, Task 1).
///
/// Menampilkan seluruh grup dari DB lokal beserta total tercatat & ringkasan
/// saldo anggota. Memakai [GroupListStore] (ChangeNotifier via provider).
/// FAB membuka dialog pembuatan grup baru (instant-start, tanpa login).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/backup_service.dart';
import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/state/group_list_store.dart';
import 'package:debt_splitter/app/ui/create_group_dialog.dart';
import 'package:debt_splitter/app/ui/group_detail_screen.dart';
import 'package:debt_splitter/app/ui/import_json_flow.dart';
import 'package:debt_splitter/app/ui/qr_scan_screen.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Muat setelah frame pertama agar BuildContext memiliki akses provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupListStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt-Splitter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () => context.read<GroupListStore>().load(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sinkronisasi & cadangan',
            onSelected: (value) => _onMenuSelected(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'scan',
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner),
                  title: Text('Scan QR (sinkronisasi)'),
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Export semua data (JSON)'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download), title: Text('Import dari file (JSON)'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GroupListStore>(
        builder: (context, store, _) {
          if (store.isLoading && store.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (store.error != null) {
            return _ErrorView(message: store.error!, onRetry: store.load);
          }
          if (store.entries.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: store.load,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: store.entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = store.entries[i];
                return _GroupCard(entry: entry);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateGroup(context),
        icon: const Icon(Icons.add),
        label: const Text('Grup Baru'),
      ),
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'scan':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QrScanScreen()),
        );
      case 'export':
        _exportAllData(context);
      case 'import':
        showImportJsonFlow(
          context,
          onImported: () => context.read<GroupListStore>().load(),
        );
    }
  }

  /// Export seluruh data (semua grup) ke file JSON lalu buka Share Sheet.
  Future<void> _exportAllData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = context.read<DebtSplitterService>();
      final backupService = context.read<BackupService>();
      final json = await service.exportAllDataJsonString();
      final filename =
          'debt_splitter_backup_${_dateStamp()}.json';
      final file = await backupService.writeJsonToTempFile(filename, json);
      await backupService.shareFiles(
        [file],
        subject: 'Backup Debt-Splitter',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal export data: $e')),
      );
    }
  }

  static String _dateStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}';
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    final store = context.read<GroupListStore>();
    final created = await showDialog<Group>(
      context: context,
      builder: (_) => CreateGroupDialog(store: store),
    );
    if (created != null && context.mounted) {
      _openGroupDetail(context, created.id, created.name);
    }
  }

  void _openGroupDetail(BuildContext context, String id, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(groupId: id, groupName: name),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.entry});

  final GroupDashboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final group = entry.group;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.group),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.memberCount} anggota · '
                'Total tercatat: ${formatRupiah(entry.totalExpenseAmount)}',
              ),
              const SizedBox(height: 4),
              _SaldoChips(entry: entry),
            ],
          ),
        ),
        trailing: group.defaultCurrency != 'IDR'
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(group.defaultCurrency),
              )
            : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                GroupDetailScreen(groupId: group.id, groupName: group.name),
          ),
        ),
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus grup?'),
        content: Text(
          'Grup "${entry.group.name}" beserta seluruh transaksinya akan '
          'dihapus permanen.',
        ),
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
      await context.read<GroupListStore>().deleteGroup(entry.group.id);
    }
  }
}

class _SaldoChips extends StatelessWidget {
  const _SaldoChips({required this.entry});

  final GroupDashboardEntry entry;

  @override
  Widget build(BuildContext context) {
    // Tampilkan hingga 3 baris ringkasan saldo terbesar (|balance|).
    final balances = entry.netBalances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    if (balances.isEmpty) {
      return const Text(
        'Belum ada transaksi',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    final shown = balances.take(3).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final b in shown)
          Chip(
            labelPadding: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(
              formatRupiah(b.value),
              style: TextStyle(
                fontSize: 12,
                color: b.value >= 0
                    ? Colors.green.shade800
                    : Colors.red.shade700,
              ),
            ),
            backgroundColor: b.value >= 0
                ? Colors.green.shade50
                : Colors.red.shade50,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 56),
            SizedBox(height: 12),
            Text(
              'Belum ada grup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4),
            Text(
              'Buat grup patungan pertama — tanpa login, tanpa internet.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Semua data tersimpan lokal di perangkat',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            SizedBox(height: 12),
            Text(
              'Gagal memuat data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, maxLines: 4),
            SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
