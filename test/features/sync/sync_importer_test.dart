import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/sync/full_backup_payload.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';
import 'package:debt_splitter/features/expenses/data/expense_repository.dart';
import 'package:debt_splitter/features/groups/data/group_repository.dart';
import 'package:debt_splitter/features/sync/data/sync_importer.dart';
import 'package:debt_splitter/features/users/data/user_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  const int fixedCreatedAt = 1_700_000_000;

  late AppDatabase db;
  late UserRepository users;
  late GroupRepository groups;
  late ExpenseRepository expenses;
  late SyncImporter importer;

  setUp(() async {
    db = await openTestDatabase();
    users = UserRepository(db);
    groups = GroupRepository(db);
    expenses = ExpenseRepository(db);
    importer = SyncImporter(db);
  });

  tearDown(() async {
    await db.close();
  });

  GroupSyncPayload remotePayload({
    String groupId = 'remote-g1',
    String groupName = 'Trip Bromo',
    List<String> memberIds = const ['ru1', 'ru2', 'ru3'],
    bool withExpense = true,
  }) {
    final members = [
      for (final id in memberIds)
        User(
          id: id,
          name: 'Nama $id',
          avatarColor: '#21A366',
          createdAt: fixedCreatedAt,
        ),
    ];
    final expensesList = <ExpenseWithShares>[];
    if (withExpense) {
      final paidBy = memberIds.first;
      final share = 100_000 ~/ memberIds.length;
      expensesList.add(
        ExpenseWithShares(
          expense: Expense(
            id: 're1',
            groupId: groupId,
            paidBy: paidBy,
            amount: 100_000,
            splitType: ExpenseSplitType.equal,
            date: 1_700_000_100,
            note: 'Makan malam',
          ),
          shares: [
            for (final id in memberIds)
              ExpenseShare(
                id: 'rs-$id',
                expenseId: 're1',
                userId: id,
                shareAmount: share + (id == paidBy ? 100_000 % memberIds.length : 0),
              ),
          ],
        ),
      );
    }
    return GroupSyncPayload(
      schemaVersion: GroupSyncPayload.currentSchemaVersion,
      exportedAt: 1_700_000_500,
      group: Group(
        id: groupId,
        name: groupName,
        defaultCurrency: 'IDR',
        createdAt: fixedCreatedAt,
      ),
      members: members,
      expenses: expensesList,
    );
  }

  group('SyncImporter — import payload grup', () {
    test('import fresh payload: grup, anggota, expense & share dibuat', () async {
      final result = await importer.importGroupPayload(remotePayload());

      expect(result.groupsAdded, 1);
      expect(result.usersAdded, 3);
      expect(result.membersAdded, 3);
      expect(result.expensesAdded, 1);
      expect(result.sharesInserted, 3);
      expect(result.totalChanges, 11);

      // Verifikasi isi DB.
      final group = await groups.getGroupById('remote-g1');
      expect(group!.name, 'Trip Bromo');
      expect(await groups.getGroupMembers('remote-g1'), hasLength(3));

      final stored = await expenses.getExpenseWithSharesByGroup('remote-g1');
      expect(stored, hasLength(1));
      expect(stored.first.expense.amount, 100_000);
      expect(stored.first.shares, hasLength(3));
      var sum = 0;
      for (final share in stored.first.shares) {
        sum += share.shareAmount;
      }
      expect(sum, 100_000); // konservasi uang terjaga
    });

    test('import ulang payload identik -> idempoten (0 perubahan)', () async {
      await importer.importGroupPayload(remotePayload());
      final second = await importer.importGroupPayload(remotePayload());
      expect(second.totalChanges, 0);

      // Data tidak duplikat.
      expect(await groups.getGroupMembers('remote-g1'), hasLength(3));
      expect(await expenses.getExpenseWithSharesByGroup('remote-g1'), hasLength(1));
      expect(await expenses.getSharesByGroup('remote-g1'), hasLength(3));
    });

    test('update nama user & nama grup disebarkan (upsert)', () async {
      await importer.importGroupPayload(remotePayload());

      final updated = remotePayload(
        groupName: 'Trip Bromo Update',
        memberIds: const ['ru1', 'ru2', 'ru3'],
      );
      // Rubah nama user ru2 di payload.
      final updatedMembers = [
        for (final m in updated.members)
          m.id == 'ru2' ? User(id: m.id, name: 'Budi Baru', avatarColor: m.avatarColor, createdAt: m.createdAt) : m,
      ];
      final changed = GroupSyncPayload(
        schemaVersion: updated.schemaVersion,
        exportedAt: updated.exportedAt,
        group: updated.group,
        members: updatedMembers,
        expenses: updated.expenses,
      );

      final result = await importer.importGroupPayload(changed);
      expect(result.groupsUpdated, 1);
      expect(result.usersUpdated, 1);
      expect(result.expensesAdded, 0);
      expect(result.totalChanges, 2);

      expect((await groups.getGroupById('remote-g1'))!.name, 'Trip Bromo Update');
      final member = await users.getUserById('ru2');
      expect(member!.name, 'Budi Baru');
    });

    test('edit expense: baris diperbarui & share diganti, bukan duplikat', () async {
      await importer.importGroupPayload(remotePayload());

      // Payload dengan expense yang sama tapi nominal & note berubah.
      final edited = remotePayload();
      final item = edited.expenses.first;
      final editedExpenses = [
        ExpenseWithShares(
          expense: Expense(
            id: item.expense.id,
            groupId: item.expense.groupId,
            paidBy: item.expense.paidBy,
            amount: 60_000,
            splitType: ExpenseSplitType.exact,
            date: item.expense.date,
            note: 'Pindah nominal',
          ),
          shares: const [
            ExpenseShare(id: 'rs-new1', expenseId: 're1', userId: 'ru1', shareAmount: 60_000),
          ],
        ),
      ];
      final changed = GroupSyncPayload(
        schemaVersion: edited.schemaVersion,
        exportedAt: edited.exportedAt,
        group: edited.group,
        members: edited.members,
        expenses: editedExpenses,
      );

      final result = await importer.importGroupPayload(changed);
      expect(result.expensesUpdated, 1);
      expect(result.sharesInserted, 1);
      expect(result.expensesAdded, 0);

      final stored = await expenses.getExpenseWithSharesByGroup('remote-g1');
      expect(stored, hasLength(1));
      expect(stored.first.expense.amount, 60_000);
      expect(stored.first.expense.note, 'Pindah nominal');
      expect(stored.first.shares, hasLength(1));
      expect(stored.first.shares.first.shareAmount, 60_000);
    });

    test('merge ke grup yang sudah ada: anggota & expense baru ditambahkan', () async {
      // Device A punya grup lokal dengan id sama & 1 anggota.
      final localUser = await users.createUser(
        name: 'Andi Lokal',
        createdAt: fixedCreatedAt,
      );
      await groups.createGroup(
        name: 'Trip Bromo',
        memberUserIds: [localUser.id],
        id: 'remote-g1',
        createdAt: fixedCreatedAt,
      );

      final result = await importer.importGroupPayload(
        remotePayload(memberIds: const ['ru1', 'ru2']),
      );

      // Anggota baru ditambahkan; anggota lokal tetap ada.
      expect(result.groupsAdded, 0);
      expect(result.membersAdded, 2);
      final memberIds = await groups.getMemberUserIds('remote-g1');
      expect(memberIds, containsAll(<String>[localUser.id, 'ru1', 'ru2']));
      expect(await expenses.getExpenseWithSharesByGroup('remote-g1'), hasLength(1));
    });

    test('importer menolak payload yang melanggar konservasi uang', () async {
      final payload = remotePayload();
      final item = payload.expenses.first;
      final broken = GroupSyncPayload(
        schemaVersion: payload.schemaVersion,
        exportedAt: payload.exportedAt,
        group: payload.group,
        members: payload.members,
        expenses: [
          ExpenseWithShares(
            expense: item.expense,
            shares: [
              for (final s in item.shares)
                ExpenseShare(
                  id: s.id,
                  expenseId: s.expenseId,
                  userId: s.userId,
                  shareAmount: 1,
                ),
            ],
          ),
        ],
      );
      await expectLater(
        importer.importGroupPayload(broken),
        throwsArgumentError,
      );
    });
  });

  group('SyncImporter — full backup', () {
    test('import backup multi-grup dalam satu transaksi', () async {
      final backup = FullBackupPayload(
        schemaVersion: FullBackupPayload.currentSchemaVersion,
        exportedAt: 1_700_000_000,
        groups: [
          remotePayload(groupId: 'g-a', groupName: 'Trip Bromo'),
          remotePayload(
            groupId: 'g-b',
            groupName: 'Kost',
            withExpense: false,
          ),
        ],
      );

      final result = await importer.importFullBackup(backup);
      expect(result.groupsAdded, 2);
      expect(result.expensesAdded, 1);

      expect((await groups.getAllGroups()).length, 2);
      expect(await expenses.getExpenseWithSharesByGroup('g-a'), hasLength(1));
      expect(await expenses.getExpenseWithSharesByGroup('g-b'), isEmpty);
    });

    test('import ulang backup identik idempoten', () async {
      final backup = FullBackupPayload(
        schemaVersion: 1,
        exportedAt: 1,
        groups: [remotePayload(groupId: 'g-a')],
      );
      await importer.importFullBackup(backup);
      final result = await importer.importFullBackup(backup);
      expect(result.totalChanges, 0);
    });
  });
}
