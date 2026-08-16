import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/features/expenses/data/expense_repository.dart';
import 'package:debt_splitter/features/groups/data/group_repository.dart';
import 'package:debt_splitter/features/users/data/user_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  const int fixedCreatedAt = 1_700_000_000;

  late AppDatabase db;
  late UserRepository users;
  late GroupRepository groups;
  late ExpenseRepository expenses;

  setUp(() async {
    db = await openTestDatabase();
    users = UserRepository(db);
    groups = GroupRepository(db);
    expenses = ExpenseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> createUsers(List<String> names) async {
    final ids = <String>[];
    for (final name in names) {
      final user = await users.createUser(
        name: name,
        createdAt: fixedCreatedAt,
      );
      ids.add(user.id);
    }
    return ids;
  }

  group('GroupRepository — CRUD + keanggotaan', () {
    test('createGroup menyimpan grup & anggota dalam satu transaksi', () async {
      final memberIds = await createUsers(const <String>['Andi', 'Budi']);

      final group = await groups.createGroup(
        name: 'Trip Bali',
        memberUserIds: memberIds,
        createdAt: fixedCreatedAt,
      );

      expect(group.id.split('-'), hasLength(5)); // UUID v4
      expect(group.name, 'Trip Bali');
      expect(group.defaultCurrency, 'IDR');
      expect(group.createdAt, fixedCreatedAt);

      final stored = await groups.getGroupById(group.id);
      expect(stored, isNotNull);
      expect(stored!.name, 'Trip Bali');

      expect(
        await groups.getMemberUserIds(group.id),
        unorderedEquals(memberIds),
      );
    });

    test('nama di-trim & mata uang dinormalisasi UPPERCASE', () async {
      final memberIds = await createUsers(const <String>['Andi']);
      final group = await groups.createGroup(
        name: '  Trip Bromo  ',
        defaultCurrency: 'idr',
        memberUserIds: memberIds,
      );
      expect(group.name, 'Trip Bromo');
      expect(group.defaultCurrency, 'IDR');
    });

    test('validasi: nama kosong / tanpa anggota / duplikat anggota', () async {
      final memberIds = await createUsers(const <String>['Andi', 'Budi']);

      await expectLater(
        groups.createGroup(name: '   ', memberUserIds: memberIds),
        throwsArgumentError,
      );
      await expectLater(
        groups.createGroup(name: 'Grup', memberUserIds: const <String>[]),
        throwsArgumentError,
      );
      await expectLater(
        groups.createGroup(
          name: 'Grup',
          memberUserIds: <String>[memberIds[0], memberIds[0]],
        ),
        throwsArgumentError,
      );
    });

    test(
      'anggota harus user yang benar-benar ada (FK group_members)',
      () async {
        await expectLater(
          groups.createGroup(
            name: 'Grup',
            memberUserIds: const <String>['u-gak-ada'],
          ),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test('getGroupById null & getAllGroups urut nama', () async {
      expect(await groups.getGroupById('g-gak-ada'), isNull);

      final userIds = await createUsers(const <String>['Andi']);
      final a = await groups.createGroup(name: 'Alpha', memberUserIds: userIds);
      final b = await groups.createGroup(name: 'Beta', memberUserIds: userIds);

      final all = await groups.getAllGroups();
      expect(all.map((group) => group.id).toList(), <String>[a.id, b.id]);
      expect(all.map((group) => group.name).toList(), <String>[
        'Alpha',
        'Beta',
      ]);
    });

    test('updateGroup menyimpan perubahan nama', () async {
      final userIds = await createUsers(const <String>['Andi']);
      final group = await groups.createGroup(
        name: 'Trip',
        memberUserIds: userIds,
      );

      await groups.updateGroup(group.copyWith(name: 'Trip Bromo'));
      final stored = await groups.getGroupById(group.id);
      expect(stored!.name, 'Trip Bromo');
    });

    test(
      'addMember, isMember & duplikat keanggotaan ditolak (PK komposit)',
      () async {
        final userIds = await createUsers(const <String>['Andi']);
        final groupId = (await groups.createGroup(
          name: 'G',
          memberUserIds: userIds,
        )).id;

        final budi = (await users.createUser(
          name: 'Budi',
          createdAt: fixedCreatedAt,
        )).id;

        expect(await groups.isMember(groupId, budi), isFalse);
        await groups.addMember(groupId, budi);
        expect(await groups.isMember(groupId, budi), isTrue);

        await expectLater(
          groups.addMember(groupId, budi),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test('removeMember menghapus keanggotaan saja', () async {
      final ids = await createUsers(const <String>['Andi', 'Budi']);
      final groupId = (await groups.createGroup(
        name: 'G',
        memberUserIds: ids,
      )).id;

      await groups.removeMember(groupId, ids[1]);
      expect(await groups.getMemberUserIds(groupId), <String>[ids[0]]);
    });

    test('getGroupMembers mengembalikan objek User', () async {
      final ids = await createUsers(const <String>['Zahra', 'Andi']);
      final groupId = (await groups.createGroup(
        name: 'G',
        memberUserIds: ids,
      )).id;

      final members = await groups.getGroupMembers(groupId);
      expect(members, hasLength(2));
      expect(members.map((user) => user.name).toList(), <String>[
        'Andi',
        'Zahra',
      ]);
    });

    test(
      'deleteGroup meng-cascade group_members, expenses, expense_shares',
      () async {
        final ids = await createUsers(const <String>['Andi', 'Budi', 'Citra']);
        final groupId = (await groups.createGroup(
          name: 'Trip',
          memberUserIds: ids,
        )).id;

        await expenses.createEqualSplitExpense(
          groupId: groupId,
          paidBy: ids[0],
          amount: 100_000,
          date: 1_700_000_100,
        );

        await groups.deleteGroup(groupId);

        expect(await groups.getGroupById(groupId), isNull);
        expect(await groups.getMemberUserIds(groupId), isEmpty);
        expect(await expenses.countExpenses(groupId: groupId), 0);
        expect(await expenses.getSharesByGroup(groupId), isEmpty);
      },
    );
  });
}
