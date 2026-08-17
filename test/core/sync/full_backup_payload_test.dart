import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/sync/full_backup_payload.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';

void main() {
  GroupSyncPayload groupPayload(String id, String name) {
    return GroupSyncPayload(
      schemaVersion: GroupSyncPayload.currentSchemaVersion,
      exportedAt: 1_700_000_000,
      group: Group(
        id: id,
        name: name,
        defaultCurrency: 'IDR',
        createdAt: 1,
      ),
      members: const [
        User(id: 'u1', name: 'Andi', avatarColor: '#21A366', createdAt: 1),
      ],
      expenses: const [],
    );
  }

  test('roundtrip backup penuh (beberapa grup) identik', () {
    final backup = FullBackupPayload(
      schemaVersion: FullBackupPayload.currentSchemaVersion,
      exportedAt: 1_700_000_500,
      groups: [groupPayload('g1', 'Trip Bromo'), groupPayload('g2', 'Kost')],
    );

    final decoded = FullBackupPayload.fromJson(backup.toJson());
    expect(decoded.schemaVersion, FullBackupPayload.currentSchemaVersion);
    expect(decoded.exportedAt, 1_700_000_500);
    expect(decoded.groups, hasLength(2));
    expect(decoded.groups.map((g) => g.group.name).toList(), [
      'Trip Bromo',
      'Kost',
    ]);
  });

  test('backup tanpa grup valid (aplikasi kosong)', () {
    final backup = FullBackupPayload(
      schemaVersion: 1,
      exportedAt: 1,
      groups: const [],
    );
    final decoded = FullBackupPayload.fromJson(backup.toJson());
    expect(decoded.groups, isEmpty);
  });

  test('menolak marker yang bukan backup', () {
    final json = groupPayload('g1', 'A').toJson(); // marker DS1
    expect(
      () => FullBackupPayload.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('menolak versi backup lebih baru', () {
    final backup = FullBackupPayload(
      schemaVersion: 1,
      exportedAt: 1,
      groups: const [],
    ).toJson()..['v'] = 99;
    expect(
      () => FullBackupPayload.fromJson(backup),
      throwsA(isA<FormatException>()),
    );
  });

  test('menolak entri grup yang bukan payload valid', () {
    final backup = FullBackupPayload(
      schemaVersion: 1,
      exportedAt: 1,
      groups: const [],
    ).toJson()..['g'] = [<String, Object?>{'t': 'DS1', 'v': 1, 'x': 0}];
    expect(
      () => FullBackupPayload.fromJson(backup),
      throwsA(isA<FormatException>()),
    );
  });
}
