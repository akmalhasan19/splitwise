/// Alur Import data dari file JSON lokal — Phase 2, Minggu 4, Task 2.
///
/// Satu alur untuk dua format yang didukung:
/// * **Backup penuh** (marker `DSB1`, [FullBackupPayload]) — seluruh grup;
/// * **Payload satu grup** (marker `DS1`, [GroupSyncPayload]) — satu grup.
///
/// Alur: pilih file `.json` (system file picker) -> parse & validasi ->
/// preview ringkasan -> konfirmasi -> import/merge ke DB lokal (idempoten,
/// dilindungi UUID) -> dialog hasil. Semua offline, tanpa jaringan.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/backup_service.dart';
import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/core/sync/full_backup_payload.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';
import 'package:debt_splitter/features/sync/data/sync_importer.dart';

/// Menjalankan alur import dari file JSON (pilih -> preview -> import).
///
/// [onImported] dipanggil setelah import sukses (mis. memuat ulang daftar
/// grup di dashboard).
Future<void> showImportJsonFlow(
  BuildContext context, {
  Future<void> Function()? onImported,
}) async {
  final backupService = context.read<BackupService>();
  final content = await backupService.pickJsonFileContent();
  if (content == null || !context.mounted) return;

  final service = context.read<DebtSplitterService>();
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('File bukan objek JSON.');
    }
    final json = Map<String, Object?>.from(decoded);
    final marker = json['t'];
    final String previewSummary;
    if (marker == FullBackupPayload.typeMarker) {
      final backup = FullBackupPayload.fromJson(json);
      final groups = backup.groups.length;
      final members = backup.groups.fold<int>(
        0,
        (acc, g) => acc + g.members.length,
      );
      previewSummary = '$groups grup · $members anggota';
    } else if (marker == GroupSyncPayload.typeMarker) {
      final payload = GroupSyncPayload.fromJson(json);
      previewSummary =
          '1 grup ("${payload.group.name}")\n'
          '${payload.members.length} anggota · '
          '${payload.expenses.length} transaksi';
    } else {
      throw const FormatException(
        'File bukan backup Debt-Splitter (marker tidak dikenal).',
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(previewSummary),
            const SizedBox(height: 8),
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
    if (confirmed != true || !context.mounted) return;

    final SyncImportResult result;
    if (marker == FullBackupPayload.typeMarker) {
      result = await service.importFullBackupJsonString(content);
    } else {
      result = await service.importGroupJsonString(content);
    }
    if (!context.mounted) return;
    await showImportResultDialog(context, result);
    if (onImported != null && context.mounted) {
      await onImported();
    }
  } catch (e) {
    if (!context.mounted) return;
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

/// Dialog ringkasan hasil import (dipakai alur file JSON & scan QR).
Future<void> showImportResultDialog(
  BuildContext context,
  SyncImportResult result,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sinkronisasi selesai'),
      content: Text(importResultMessage(result)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Pesan teks ringkasan hasil import.
String importResultMessage(SyncImportResult result) {
  if (result.totalChanges == 0) {
    return 'Data sudah sinkron — tidak ada perubahan yang diperlukan.';
  }
  return [
    'Grup baru: ${result.groupsAdded}',
    'Grup diperbarui: ${result.groupsUpdated}',
    'Anggota baru: ${result.usersAdded + result.membersAdded}',
    'Transaksi baru: ${result.expensesAdded}',
    'Transaksi diperbarui: ${result.expensesUpdated}',
  ].join('\n');
}
