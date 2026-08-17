/// UI Scanner QR Code (import / sinkronisasi offline) — Phase 2, Minggu 4,
/// Task 1.
///
/// Memakai `mobile_scanner` (kamera on-device, 100% offline — tanpa ML cloud).
/// Alur:
/// 1. Scan QR berisi payload Debt-Splitter (keluaran [QrShareSheet]);
/// 2. Decode Base64 -> gunzip -> JSON -> [GroupSyncPayload] (validasi ketat);
/// 3. Preview data (nama grup, jumlah anggota & transaksi) -> konfirmasi;
/// 4. Import/merge ke DB lokal via [DebtSplitterService.importGroupSyncPayload]
///    (idempoten, dilindungi UUID) lalu tampilkan ringkasan hasil.
///
/// Kegagalan decode (QR bukan milik Debt-Splitter / korup) ditangani dengan
/// pesan ramah dan pemindaian dilanjutkan.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/ui/import_json_flow.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';
import 'package:debt_splitter/core/sync/payload_codec.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// `true` saat sedang memproses hasil scan (cegah scan ganda).
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR — Sinkronisasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Nyalakan senter',
            onPressed: _busy ? null : _controller.toggleTorch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _ScannerErrorView(
                message: _describeError(error),
                onRetry: _controller.start,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Column(
              children: [
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _status!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const Icon(Icons.qr_code_scanner, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Arahkan kamera ke QR "Bagikan via QR" dari perangkat lain.\n'
                  'Data diimpor offline — tidak dikirim ke mana pun.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;

    _busy = true;
    setState(() => _status = 'Memproses payload…');
    await _controller.stop();

    final GroupSyncPayload? payload;
    try {
      payload = PayloadCodec.decodeGroupPayload(raw);
    } catch (e) {
      _busy = false;
      if (!mounted) return;
      setState(() => _status = null);
      await _showInvalidQr('$e');
      await _controller.start();
      return;
    }

    if (!mounted) return;
    await _showImportPreview(payload);
    _busy = false;
    if (mounted) {
      setState(() => _status = null);
      // Selesai (hasil import sudah ditampilkan); tutup layar.
      Navigator.of(context).pop();
    }
  }

  /// Menampilkan preview payload & meminta konfirmasi sebelum import.
  Future<void> _showImportPreview(GroupSyncPayload payload) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import grup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group),
              title: Text(payload.group.name),
              subtitle: Text(
                '${payload.members.length} anggota · '
                '${payload.expenses.length} transaksi',
              ),
            ),
            const Text(
              'Data akan digabungkan ke perangkat ini. Data yang sudah ada '
              'tidak akan dihapus.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final service = context.read<DebtSplitterService>();
      final result = await service.importGroupSyncPayload(payload);
      if (!mounted) return;
      await showImportResultDialog(context, result);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import gagal'),
          content: Text('$e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showInvalidQr(String reason) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR tidak valid'),
        content: Text(
          'QR yang dipindai bukan payload Debt-Splitter yang sah.\n\n'
          'Detail: $reason',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _describeError(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Izin kamera ditolak. Aktifkan akses kamera di pengaturan perangkat, '
            'lalu coba lagi.',
      MobileScannerErrorCode.controllerUninitialized ||
      MobileScannerErrorCode.unsupported =>
        'Scanner tidak tersedia di perangkat ini.',
      _ => 'Terjadi kesalahan kamera: ${error.errorDetails?.message ?? error}',
    };
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.message, required this.onRetry});

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
            Icon(Icons.no_photography_outlined,
                size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),

          ],
        ),
      ),
    );
  }
}
