import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';

/// Membuka database SQLite di memori via FFI (host/desktop) — koneksi segar
/// setiap dipanggil (forceNew) agar tiap test saling independen.
Future<AppDatabase> _openTestDatabase() {
  return AppDatabase.open(
    inMemory: true,
    forceNew: true,
    factory: databaseFactoryFfiNoIsolate,
  );
}

Future<List<Map<String, Object?>>> _tableInfo(Database db, String table) =>
    db.rawQuery('PRAGMA table_info("$table")');

Future<List<Map<String, Object?>>> _foreignKeys(Database db, String table) =>
    db.rawQuery('PRAGMA foreign_key_list("$table")');

Future<Map<String, Object?>> _columnInfo(
  Database db,
  String table,
  String column,
) async {
  final rows = await _tableInfo(db, table);
  return rows.firstWhere(
    (row) => row['name'] == column,
    orElse: () => <String, Object?>{},
  );
}

Future<int> _countRows(
  Database db,
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final sql =
      'SELECT COUNT(*) AS cnt FROM $table'
      '${where == null ? '' : ' WHERE $where'}';
  final rows = await db.rawQuery(sql, whereArgs);
  return rows.single['cnt']! as int;
}

Future<void> _insertUser(Database db, String id, {String name = 'Andi'}) =>
    db.insert(DbTable.users, {
      UserCol.id: id,
      UserCol.name: name,
      UserCol.avatarColor: '#21A366',
      UserCol.createdAt: 1_700_000_000,
    });

Future<void> _insertGroup(
  Database db,
  String id, {
  String name = 'Trip Bali',
  String defaultCurrency = 'IDR',
}) => db.insert(DbTable.groups, {
  GroupCol.id: id,
  GroupCol.name: name,
  GroupCol.defaultCurrency: defaultCurrency,
  GroupCol.createdAt: 1_700_000_000,
});

Future<void> _insertMembership(
  Database db, {
  required String groupId,
  required String userId,
}) => db.insert(DbTable.groupMembers, {
  GroupMemberCol.groupId: groupId,
  GroupMemberCol.userId: userId,
});

Future<void> _insertExpense(
  Database db, {
  required String id,
  required String groupId,
  required String paidBy,
  int amount = 100_000,
  String splitType = 'EQUAL',
  String? note,
}) => db.insert(DbTable.expenses, {
  ExpenseCol.id: id,
  ExpenseCol.groupId: groupId,
  ExpenseCol.paidBy: paidBy,
  ExpenseCol.amount: amount,
  ExpenseCol.splitType: splitType,
  ExpenseCol.date: 1_700_000_000,
  ExpenseCol.note: note,
});

Future<void> _insertShare(
  Database db, {
  required String id,
  required String expenseId,
  required String userId,
  required int amount,
}) => db.insert(DbTable.expenseShares, {
  ExpenseShareCol.id: id,
  ExpenseShareCol.expenseId: expenseId,
  ExpenseShareCol.userId: userId,
  ExpenseShareCol.shareAmount: amount,
});

void main() {
  setUpAll(sqfliteFfiInit);

  group('AppDatabase — tabel & kolom sesuai skema', () {
    late AppDatabase app;

    setUp(() async {
      app = await _openTestDatabase();
    });

    tearDown(() async {
      await app.close();
    });

    test('onCreate menghasilkan tepat 7 tabel aplikasi', () async {
      final rows = await app.db.rawQuery(
        'SELECT name FROM sqlite_master '
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
        "AND name NOT LIKE '_sqlite_%'",
      );
      final names = rows.map((row) => row['name'] as String).toSet();

      expect(names, hasLength(7));
      expect(
        names,
        containsAll(<String>[
          DbTable.users,
          DbTable.groups,
          DbTable.groupMembers,
          DbTable.expenses,
          DbTable.expenseShares,
          DbTable.expenseItems,
          DbTable.itemClaims,
        ]),
      );
    });

    test('tabel users: PK TEXT, name/avatar TEXT, createdAt INTEGER', () async {
      final info = await _tableInfo(app.db, DbTable.users);
      expect(info, hasLength(4));

      final id = await _columnInfo(app.db, DbTable.users, UserCol.id);
      expect(id['type'], 'TEXT');
      expect(id['pk'], 1);
      expect(id['notnull'], 1);

      final name = await _columnInfo(app.db, DbTable.users, UserCol.name);
      expect(name['type'], 'TEXT');
      expect(name['notnull'], 1);

      final avatar = await _columnInfo(
        app.db,
        DbTable.users,
        UserCol.avatarColor,
      );
      expect(avatar['type'], 'TEXT');
      expect(avatar['notnull'], 1);

      final createdAt = await _columnInfo(
        app.db,
        DbTable.users,
        UserCol.createdAt,
      );
      expect(createdAt['type'], 'INTEGER');
      expect(createdAt['notnull'], 1);
    });
    test('tabel groups: id, name, default_currency, created_at', () async {
      final info = await _tableInfo(app.db, DbTable.groups);
      expect(info, hasLength(4));

      final id = await _columnInfo(app.db, DbTable.groups, GroupCol.id);
      expect(id['type'], 'TEXT');
      expect(id['pk'], 1);

      final name = await _columnInfo(app.db, DbTable.groups, GroupCol.name);
      expect(name['type'], 'TEXT');
      expect(name['notnull'], 1);

      final currency = await _columnInfo(
        app.db,
        DbTable.groups,
        GroupCol.defaultCurrency,
      );
      expect(currency['type'], 'TEXT');
      expect(currency['notnull'], 1);

      final createdAt = await _columnInfo(
        app.db,
        DbTable.groups,
        GroupCol.createdAt,
      );
      expect(createdAt['type'], 'INTEGER');
      expect(createdAt['notnull'], 1);
    });

    test('group_members: 2 kolom, PK komposit (group_id, user_id)', () async {
      final info = await _tableInfo(app.db, DbTable.groupMembers);
      expect(info, hasLength(2));

      final groupId = await _columnInfo(
        app.db,
        DbTable.groupMembers,
        GroupMemberCol.groupId,
      );
      expect(groupId['type'], 'TEXT');
      expect(groupId['notnull'], 1);
      expect(groupId['pk'], 1);

      final userId = await _columnInfo(
        app.db,
        DbTable.groupMembers,
        GroupMemberCol.userId,
      );
      expect(userId['type'], 'TEXT');
      expect(userId['notnull'], 1);
      expect(userId['pk'], 2);
    });

    test('expenses: 7 kolom, amount/date INTEGER, note nullable', () async {
      final info = await _tableInfo(app.db, DbTable.expenses);
      expect(info, hasLength(7));

      final id = await _columnInfo(app.db, DbTable.expenses, ExpenseCol.id);
      expect(id['type'], 'TEXT');
      expect(id['pk'], 1);

      final amount = await _columnInfo(
        app.db,
        DbTable.expenses,
        ExpenseCol.amount,
      );
      expect(amount['type'], 'INTEGER');
      expect(amount['notnull'], 1);

      final splitType = await _columnInfo(
        app.db,
        DbTable.expenses,
        ExpenseCol.splitType,
      );
      expect(splitType['type'], 'TEXT');
      expect(splitType['notnull'], 1);

      final date = await _columnInfo(app.db, DbTable.expenses, ExpenseCol.date);
      expect(date['type'], 'INTEGER');
      expect(date['notnull'], 1);

      final note = await _columnInfo(app.db, DbTable.expenses, ExpenseCol.note);
      expect(note['type'], 'TEXT');
      expect(note['notnull'], 0); // nullable
    });

    test('expense_shares: 4 kolom, share_amount INTEGER NOT NULL', () async {
      final info = await _tableInfo(app.db, DbTable.expenseShares);
      expect(info, hasLength(4));

      final id = await _columnInfo(
        app.db,
        DbTable.expenseShares,
        ExpenseShareCol.id,
      );
      expect(id['type'], 'TEXT');
      expect(id['pk'], 1);

      final amount = await _columnInfo(
        app.db,
        DbTable.expenseShares,
        ExpenseShareCol.shareAmount,
      );
      expect(amount['type'], 'INTEGER');
      expect(amount['notnull'], 1);
    });

    test('expense_items: 6 kolom, unit_price INTEGER, quantity CHECK', () async {
      final info = await _tableInfo(app.db, DbTable.expenseItems);
      expect(info, hasLength(6));

      final id = await _columnInfo(app.db, DbTable.expenseItems, ExpenseItemCol.id);
      expect(id['type'], 'TEXT');
      expect(id['pk'], 1);

      final expenseId = await _columnInfo(
        app.db,
        DbTable.expenseItems,
        ExpenseItemCol.expenseId,
      );
      expect(expenseId['type'], 'TEXT');
      expect(expenseId['notnull'], 1);

      final price = await _columnInfo(
        app.db,
        DbTable.expenseItems,
        ExpenseItemCol.unitPrice,
      );
      expect(price['type'], 'INTEGER');
      expect(price['notnull'], 1);

      final qty = await _columnInfo(
        app.db,
        DbTable.expenseItems,
        ExpenseItemCol.quantity,
      );
      expect(qty['type'], 'INTEGER');
      expect(qty['notnull'], 1);
    });

    test('item_claims: 2 kolom, PK komposit (expense_item_id, user_id)', () async {
      final info = await _tableInfo(app.db, DbTable.itemClaims);
      expect(info, hasLength(2));

      final itemId = await _columnInfo(
        app.db,
        DbTable.itemClaims,
        ItemClaimCol.expenseItemId,
      );
      expect(itemId['type'], 'TEXT');
      expect(itemId['notnull'], 1);
      expect(itemId['pk'], 1);

      final userId = await _columnInfo(
        app.db,
        DbTable.itemClaims,
        ItemClaimCol.userId,
      );
      expect(userId['type'], 'TEXT');
      expect(userId['notnull'], 1);
      expect(userId['pk'], 2);
    });
  });
  group('AppDatabase — relasi Foreign Key & Primary Key komposit', () {
    late AppDatabase appHandle;
    late Database db;

    setUp(() async {
      appHandle = await _openTestDatabase();
      db = appHandle.db;
    });

    tearDown(() async {
      await appHandle.close();
    });

    test('FK: group_members -> groups & users, ON DELETE CASCADE', () async {
      final fks = await _foreignKeys(db, DbTable.groupMembers);
      expect(fks, hasLength(2));

      final byFrom = {for (final fk in fks) fk['from']! as String: fk};

      expect(byFrom[GroupMemberCol.groupId]!['table'], DbTable.groups);
      expect(byFrom[GroupMemberCol.groupId]!['on_delete'], 'CASCADE');
      expect(byFrom[GroupMemberCol.userId]!['table'], DbTable.users);
      expect(byFrom[GroupMemberCol.userId]!['on_delete'], 'CASCADE');
    });

    test('FK: expenses -> groups CASCADE & users RESTRICT', () async {
      final fks = await _foreignKeys(db, DbTable.expenses);
      expect(fks, hasLength(2));

      final byFrom = {for (final fk in fks) fk['from']! as String: fk};

      expect(byFrom[ExpenseCol.groupId]!['table'], DbTable.groups);
      expect(byFrom[ExpenseCol.groupId]!['on_delete'], 'CASCADE');
      expect(byFrom[ExpenseCol.paidBy]!['table'], DbTable.users);
      expect(byFrom[ExpenseCol.paidBy]!['on_delete'], 'RESTRICT');
    });

    test('FK: expense_shares -> expenses CASCADE & users CASCADE', () async {
      final fks = await _foreignKeys(db, DbTable.expenseShares);
      expect(fks, hasLength(2));

      final byFrom = {for (final fk in fks) fk['from']! as String: fk};

      expect(byFrom[ExpenseShareCol.expenseId]!['table'], DbTable.expenses);
      expect(byFrom[ExpenseShareCol.expenseId]!['on_delete'], 'CASCADE');
      expect(byFrom[ExpenseShareCol.userId]!['table'], DbTable.users);
      expect(byFrom[ExpenseShareCol.userId]!['on_delete'], 'CASCADE');
    });
    test(
      'PRAGMA foreign_keys aktif: expenses.group_id menolak grup asing',
      () async {
        await _insertUser(db, 'u-1');

        await expectLater(
          _insertExpense(db, id: 'e-1', groupId: 'g-tidak-ada', paidBy: 'u-1'),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test(
      'PRAGMA foreign_keys aktif: expenses.paid_by menolak user asing',
      () async {
        await _insertGroup(db, 'g-1');

        await expectLater(
          _insertExpense(db, id: 'e-1', groupId: 'g-1', paidBy: 'u-tidak-ada'),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test(
      'PRAGMA foreign_keys aktif: group_members menolak user non-anggota',
      () async {
        await _insertGroup(db, 'g-1');
        await _insertUser(db, 'u-1');

        await expectLater(
          _insertMembership(db, groupId: 'g-1', userId: 'u-luar'),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test(
      'hapus group => CASCADE: group_members, expenses, expense_shares',
      () async {
        await _insertUser(db, 'u-1');
        await _insertUser(db, 'u-2', name: 'Budi');
        await _insertGroup(db, 'g-1');
        await _insertMembership(db, groupId: 'g-1', userId: 'u-1');
        await _insertMembership(db, groupId: 'g-1', userId: 'u-2');
        await _insertExpense(db, id: 'e-1', groupId: 'g-1', paidBy: 'u-1');
        await _insertShare(
          db,
          id: 's-1',
          expenseId: 'e-1',
          userId: 'u-1',
          amount: 50_000,
        );
        await _insertShare(
          db,
          id: 's-2',
          expenseId: 'e-1',
          userId: 'u-2',
          amount: 50_000,
        );

        await db.delete(
          DbTable.groups,
          where: '${GroupCol.id} = ?',
          whereArgs: <Object?>['g-1'],
        );

        expect(await _countRows(db, DbTable.groupMembers), 0);
        expect(await _countRows(db, DbTable.expenses), 0);
        expect(await _countRows(db, DbTable.expenseShares), 0);
        // User tidak ikut terhapus — hanya relasinya yang di-cascade.
        expect(
          await _countRows(
            db,
            DbTable.users,
            where: '${UserCol.id} = ?',
            whereArgs: <Object?>['u-1'],
          ),
          1,
        );
      },
    );

    test(
      'hapus user tercatat paid_by => DITOLAK (ON DELETE RESTRICT)',
      () async {
        await _insertUser(db, 'u-1');
        await _insertGroup(db, 'g-1');
        await _insertExpense(db, id: 'e-1', groupId: 'g-1', paidBy: 'u-1');

        await expectLater(
          db.delete(
            DbTable.users,
            where: '${UserCol.id} = ?',
            whereArgs: <Object?>['u-1'],
          ),
          throwsA(isA<DatabaseException>()),
        );

        expect(
          await _countRows(
            db,
            DbTable.users,
            where: '${UserCol.id} = ?',
            whereArgs: <Object?>['u-1'],
          ),
          1,
        );
      },
    );
  });
  group('AppDatabase — CHECK constraint & presisi Integer', () {
    late AppDatabase appHandle;
    late Database db;

    setUp(() async {
      appHandle = await _openTestDatabase();
      db = appHandle.db;
      await _insertUser(db, 'u-1');
      await _insertGroup(db, 'g-1');
    });

    tearDown(() async {
      await appHandle.close();
    });

    test('split_type menerima EQUAL, EXACT, PERCENT, dan ITEM', () async {
      for (final type in ExpenseSplitType.values) {
        await _insertExpense(
          db,
          id: 'e-${type.dbValue}',
          groupId: 'g-1',
          paidBy: 'u-1',
          splitType: type.dbValue,
        );
      }

      expect(await _countRows(db, DbTable.expenses), 4);
    });

    test('split_type menolak nilai di luar CHECK constraint', () async {
      await expectLater(
        _insertExpense(
          db,
          id: 'e-1',
          groupId: 'g-1',
          paidBy: 'u-1',
          splitType: 'HALF',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('amount & date tersimpan utuh sebagai int (bukan double)', () async {
      const int amount = 123_456_789;
      await _insertExpense(
        db,
        id: 'e-1',
        groupId: 'g-1',
        paidBy: 'u-1',
        amount: amount,
      );

      final rows = await db.query(DbTable.expenses);
      expect(rows, hasLength(1));

      final stored = rows.single;
      expect(stored[ExpenseCol.amount], isA<int>());
      expect(stored[ExpenseCol.amount], 123_456_789);
      expect(stored[ExpenseCol.date], isA<int>());
      expect(stored[ExpenseCol.date], 1_700_000_000);
    });

    test('share_amount tersimpan utuh sebagai INTEGER', () async {
      await _insertExpense(db, id: 'e-1', groupId: 'g-1', paidBy: 'u-1');
      await _insertShare(
        db,
        id: 's-1',
        expenseId: 'e-1',
        userId: 'u-1',
        amount: 33_334,
      );

      final rows = await db.query(DbTable.expenseShares);
      expect(rows, hasLength(1));
      expect(rows.single[ExpenseShareCol.shareAmount], isA<int>());
      expect(rows.single[ExpenseShareCol.shareAmount], 33_334);
    });
  });

  group('AppDatabase — lifecycle & idempotensi open', () {
    test(
      'open() berulang tanpa forceNew = instance yang sama (singleton)',
      () async {
        final first = await AppDatabase.open(
          inMemory: true,
          factory: databaseFactoryFfiNoIsolate,
        );
        addTearDown(first.close);

        final second = await AppDatabase.open(
          inMemory: true,
          factory: databaseFactoryFfiNoIsolate,
        );

        expect(identical(first, second), isTrue);
      },
    );

    test('forceNew menghadirkan koneksi terpisah', () async {
      final first = await _openTestDatabase();
      addTearDown(first.close);
      final second = await _openTestDatabase();
      addTearDown(second.close);

      expect(identical(first, second), isFalse);
      expect(first.isOpen, isTrue);
      expect(second.isOpen, isTrue);
    });

    test('close() menutup koneksi & me-reset singleton global', () async {
      final first = await AppDatabase.open(
        inMemory: true,
        factory: databaseFactoryFfiNoIsolate,
      );
      expect(first.isOpen, isTrue);

      await first.close();
      expect(first.isOpen, isFalse);

      final second = await AppDatabase.open(
        inMemory: true,
        factory: databaseFactoryFfiNoIsolate,
      );
      addTearDown(second.close);
      expect(identical(first, second), isFalse);
    });
  });
}
