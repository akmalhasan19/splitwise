import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/sync/full_backup_payload.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  late AppDatabase db;
  late DebtSplitterService service;

  setUp(() async {
    db = await openTestDatabase();
    service = DebtSplitterService(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Membuka service baru dengan DB benar-benar baru (menutup DB lama dulu,
  /// karena sqflite `singleInstance` meng-cache path `:memory:`).
  Future<DebtSplitterService> freshDevice() async {
    await db.close();
    db = await openTestDatabase();
    return DebtSplitterService(db);
  }

  /// Membuat grup "Trip Bromo" (Andi, Budi, Citra) + 2 expense.
  Future<String> seedGroup() async {
    final group = await service.createGroupWithMembers(
      name: 'Trip Bromo',
      memberNames: const ['Andi', 'Budi', 'Citra'],
    );
    final members = await service.getGroupMembers(group.id);
    await service.addEqualSplitExpense(
      groupId: group.id,
      paidBy: members[0].id,
      amount: 90_000,
      note: 'Makan malam',
    );
    await service.addExactSplitExpense(
      groupId: group.id,
      paidBy: members[1].id,
      amount: 30_000,
      sharesById: <String, MoneyAmount>{members[2].id: 30_000},
      note: 'Tiket',
    );
    return group.id;
  }

  group('DebtSplitterService — sync payload', () {
    test('buildGroupSyncPayload memuat grup, anggota & seluruh transaksi', () async {
      final groupId = await seedGroup();

      final payload = await service.buildGroupSyncPayload(groupId);
      expect(payload.group.name, 'Trip Bromo');
      expect(payload.members, hasLength(3));
      expect(payload.expenses, hasLength(2));

      // Serialisasi -> QR string -> decode ulang identik.
      final json = payload.toJson();
      final decoded = GroupSyncPayload.fromJson(json);
      expect(decoded.group.id, groupId);
      expect(decoded.expenses, hasLength(2));
    });

    test('importGroupSyncPayload: payload dari device A masuk ke DB baru', () async {
      final groupId = await seedGroup();
      final payload = await service.buildGroupSyncPayload(groupId);

      // Device baru = DB baru: tutup dulu DB lama agar instance ':memory:'
      // (singleInstance sqflite) benar-benar terpisah.
      final service2 = await freshDevice();
      final result = await service2.importGroupSyncPayload(payload);
      expect(result.groupsAdded, 1);
      expect(result.usersAdded, 3);
      expect(result.expensesAdded, 2);

      final imported = await service2.getSummarySnapshot(groupId);
      expect(imported.group.name, 'Trip Bromo');
      expect(imported.members, hasLength(3));
      expect(imported.totalExpenseAmount, 120_000);
      expect(imported.settlements, isNotEmpty);
    });
  });

  group('DebtSplitterService — backup export/import JSON', () {
    test('exportAllDataJsonString menghasilkan backup penuh yang valid', () async {
      await seedGroup();
      await service.createGroupWithMembers(
        name: 'Kost',
        memberNames: const ['Andi'],
      );

      final jsonString = await service.exportAllDataJsonString();
      final decoded = jsonDecode(jsonString) as Map<String, Object?>;
      final backup = FullBackupPayload.fromJson(decoded);

      expect(backup.groups, hasLength(2));
      final names = backup.groups.map((g) => g.group.name).toSet();
      expect(names, {'Trip Bromo', 'Kost'});
      final bromo = backup.groups.firstWhere((g) => g.group.name == 'Trip Bromo');
      expect(bromo.expenses, hasLength(2));
    });

    test('importFullBackupJsonString: restore ke DB kosong', () async {
      await seedGroup();
      final jsonString = await service.exportAllDataJsonString();

      final service2 = await freshDevice();
      final result = await service2.importFullBackupJsonString(jsonString);
      expect(result.groupsAdded, 1);
      expect(result.expensesAdded, 2);
      expect((await service2.getAllGroups()), hasLength(1));
    });

    test('exportGroupJsonString & importGroupJsonString roundtrip', () async {
      final groupId = await seedGroup();
      final jsonString = await service.exportGroupJsonString(groupId);

      final service2 = await freshDevice();
      final result = await service2.importGroupJsonString(jsonString);
      expect(result.groupsAdded, 1);
      final restored = await service2.getGroupDashboardEntry(groupId);
      expect(restored.totalExpenseAmount, 120_000);
      expect(restored.memberCount, 3);
    });

    test('import menolak string yang bukan backup Debt-Splitter', () async {
      await expectLater(
        service.importFullBackupJsonString('{"foo": 1}'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.importGroupJsonString('bukan json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
