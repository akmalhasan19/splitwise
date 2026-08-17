/// Tab "Pelunasan" — visual card instruksi pembayaran (Minggu 3, Task 3)
/// + tombol Share ringkasan WhatsApp (Minggu 3, Task 4).
///
/// Setiap card = satu [SettlementPayment] keluaran greedy engine, dibaca
/// sebagai "debtor transfer Rp... ke creditor". Tombol di header membuka
/// OS Share Sheet dengan teks dari [WhatsAppSummaryGenerator.generate].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/services/share_service.dart';
import 'package:debt_splitter/app/state/group_detail_store.dart';
import 'package:debt_splitter/app/widgets/user_avatar.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';
import 'package:debt_splitter/features/share/whatsapp_summary_generator.dart';

class SettleUpTab extends StatelessWidget {
  const SettleUpTab({required this.store, required this.groupName, super.key});

  final GroupDetailStore store;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    final settlements = store.settlements;
    if (settlements.isEmpty) {
      return _AllSettledView();
    }
    return Column(
      children: [
        _ShareHeaderBar(store: store, groupName: groupName),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: settlements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SettlementCard(
              payment: settlements[i],
              store: store,
              index: i + 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareHeaderBar extends StatelessWidget {
  const _ShareHeaderBar({required this.store, required this.groupName});

  final GroupDetailStore store;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${store.settlements.length} transaksi pelunasan',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          FilledButton.icon(
            onPressed: () => _share(context),
            icon: const Icon(Icons.share),
            label: const Text('Bagikan'),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final service = context.read<DebtSplitterService>();
    final shareService = context.read<ShareService>();
    try {
      final snapshot = await service.getSummarySnapshot(store.groupId);
      final text = WhatsAppSummaryGenerator.generate(snapshot);
      await shareService.shareText(
        text,
        subject: 'Ringkasan patungan: $groupName',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
      }
    }
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.payment,
    required this.store,
    required this.index,
  });

  final SettlementPayment payment;
  final GroupDetailStore store;
  final int index;

  @override
  Widget build(BuildContext context) {
    final debtor = _find(payment.debtorId);
    final creditor = _find(payment.creditorId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text('$index'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${debtor?.name ?? '—'} transfer',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (debtor != null)
                        UserAvatar(user: debtor, radius: 10)
                      else
                        const Icon(Icons.person_outline, size: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      if (creditor != null)
                        UserAvatar(user: creditor, radius: 10)
                      else
                        const Icon(Icons.person_outline, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        creditor?.name ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatRupiah(payment.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  User? _find(String id) {
    for (final m in store.members) {
      if (m.id == id) return m;
    }
    return null;
  }
}

class _AllSettledView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 56, color: Colors.green.shade400),
            SizedBox(height: 12),
            Text(
              'Semua tuntas!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4),
            Text('Tidak ada transaksi pelunasan tersisa.'),
          ],
        ),
      ),
    );
  }
}
