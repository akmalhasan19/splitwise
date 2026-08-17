/// Payload cadangan penuh (full backup) — seluruh data aplikasi (semua grup),
/// Phase 2, Minggu 4, Task 2 (Backup & Export/Import).
///
/// Struktur JSON (key ringkas, mengikuti konvensi `GroupSyncPayload`):
/// ```text
/// t = type marker ("DSB1")   v = schemaVersion   x = exportedAt
/// g = daftar GroupSyncPayload (satu per grup)
/// ```
/// Format ini dipakai untuk **Export DB ke file JSON lokal** dan
/// **Import data dari file JSON lokal**. Restore bersifat *merge* (dilindungi
/// UUID): data yang sudah ada dipertahankan/diperbarui, tidak pernah dihapus.
library;

import 'package:debt_splitter/core/sync/group_sync_payload.dart';

class FullBackupPayload {
  const FullBackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.groups,
  });

  /// Marker tipe payload backup.
  static const String typeMarker = 'DSB1';

  /// Versi format backup saat ini.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;

  /// Waktu backup dibuat (Unix epoch detik).
  final int exportedAt;

  /// Seluruh grup yang dibackup (masing-masing payload lengkap).
  final List<GroupSyncPayload> groups;

  Map<String, Object?> toJson() => <String, Object?>{
    't': typeMarker,
    'v': schemaVersion,
    'x': exportedAt,
    'g': <Object?>[for (final group in groups) group.toJson()],
  };

  static FullBackupPayload fromJson(Map<String, Object?> json) {
    if (json['t'] != typeMarker) {
      throw const FormatException(
        'Bukan file backup Debt-Splitter (marker "DSB1" tidak ditemukan).',
      );
    }
    final schemaVersion = json['v'];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const FormatException('Field "v" (versi backup) tidak valid.');
    }
    if (schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'Backup versi $schemaVersion lebih baru dari yang didukung '
        '($currentSchemaVersion). Perbarui aplikasi Debt-Splitter.',
      );
    }
    final exportedAt = json['x'];
    if (exportedAt is! int || exportedAt < 0) {
      throw const FormatException('Field "x" (waktu backup) tidak valid.');
    }
    final rawGroups = json['g'];
    if (rawGroups is! List) {
      throw const FormatException('Field "g" (daftar grup) tidak valid.');
    }
    final groups = <GroupSyncPayload>[];
    for (final raw in rawGroups) {
      if (raw is! Map) {
        throw const FormatException('Entri grup backup bukan objek JSON.');
      }
      groups.add(
        GroupSyncPayload.fromJson(Map<String, Object?>.from(raw)),
      );
    }
    return FullBackupPayload(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      groups: groups,
    );
  }
}
