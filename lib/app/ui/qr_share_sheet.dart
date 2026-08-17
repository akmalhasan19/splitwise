/// UI Generator QR Code — Phase 2, Minggu 4, Task 1 (QR Sync).
///
/// Modal bottom sheet yang menampilkan QR Code berisi payload sinkronisasi
/// satu grup (serialisasi JSON ringkas -> gzip -> Base64). Perangkat lain
/// memindai QR ini (via [QrScanScreen]) untuk meng-import grup secara
/// *offline* tanpa internet/server.
///
/// Juga menyediakan aksi "Bagikan teks" (kirim payload via WhatsApp/chat
/// lain) dan "Salin" — jalur alternatif bila pemindaian QR tidak memungkinkan.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/services/share_service.dart';
import 'package:debt_splitter/core/sync/payload_codec.dart';

class QrShareSheet extends StatefulWidget {
  const QrShareSheet({required this.groupId, super.key});

  final String groupId;

  @override
  State<QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends State<QrShareSheet> {
  String? _qrData;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildPayload();
  }

  Future<void> _buildPayload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<DebtSplitterService>();
      final payload = await service.buildGroupSyncPayload(widget.groupId);
      final data = PayloadCodec.encodeGroupPayload(payload);
      if (!mounted) return;
      setState(() {
        _qrData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DragHandle(),
            const SizedBox(height: 8),
            Text('Bagikan via QR', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Scan dari perangkat lain untuk menyinkronkan grup ini — '
              '100% offline, tanpa server.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 8),
                    Text(
                      'Gagal membuat QR',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: _buildPayload,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 220,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_qrData!.length} karakter terenkripsi (gzip + Base64)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _shareText,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Bagikan teks'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Buka "Scan QR" di perangkat tujuan → pilih "Sinkronisasi".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _qrData!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payload disalin ke clipboard')),
    );
  }

  Future<void> _shareText() async {
    final shareService = context.read<ShareService>();
    await shareService.shareText(_qrData!);
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
