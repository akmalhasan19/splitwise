import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/db/local_schema.dart';

void main() {
  group('Local Schema — konstanta & DDL (Phase 1 Task 2)', () {
    test('dbSchemaVersion dimulai dari 1 (skema awal)', () {
      expect(dbSchemaVersion, 1);
    });

    test('createSchemaV1Scripts berisi tepat 5 perintah CREATE TABLE', () {
      expect(createSchemaV1Scripts, hasLength(5));
      for (final script in createSchemaV1Scripts) {
        expect(script.trim(), startsWith('CREATE TABLE '));
      }
    });

    test('tabel users: id/name/avatar_color/created_at sesuai plan', () {
      final script = createSchemaV1Scripts[0];
      expect(script, contains('users'));
      expect(script, contains('id TEXT NOT NULL PRIMARY KEY'));
      expect(script, contains('name TEXT NOT NULL'));
      expect(script, contains('avatar_color TEXT NOT NULL'));
      expect(script, contains('created_at INTEGER NOT NULL'));
    });

    test('tabel groups: id/name/default_currency/created_at sesuai plan', () {
      final script = createSchemaV1Scripts[1];
      expect(script, contains('groups'));
      expect(script, contains('id TEXT NOT NULL PRIMARY KEY'));
      expect(script, contains('name TEXT NOT NULL'));
      expect(script, contains('default_currency TEXT NOT NULL'));
      expect(script, contains('created_at INTEGER NOT NULL'));
    });

    test('group_members: PK komposit (group_id, user_id) + FK dua arah', () {
      final script = createSchemaV1Scripts[2];
      expect(script, contains('group_members'));
      expect(script, contains('PRIMARY KEY (group_id, user_id)'));
      expect(script, contains('group_id TEXT NOT NULL'));
      expect(script, contains('REFERENCES groups (id)'));
      expect(script, contains('user_id TEXT NOT NULL'));
      expect(script, contains('REFERENCES users (id)'));
    });

    test('expenses: seluruh kolom + CHECK split_type sesuai plan', () {
      final script = createSchemaV1Scripts[3];
      expect(script, contains('expenses'));
      expect(script, contains('id TEXT NOT NULL PRIMARY KEY'));
      expect(script, contains('group_id TEXT NOT NULL'));
      expect(script, contains('REFERENCES groups (id)'));
      expect(script, contains('paid_by TEXT NOT NULL'));
      expect(script, contains('REFERENCES users (id)'));
      expect(script, contains('amount INTEGER NOT NULL'));
      expect(
        script,
        contains("CHECK (split_type IN ('EQUAL', 'EXACT', 'PERCENT'))"),
      );
      expect(script, contains('date INTEGER NOT NULL'));
      expect(script, contains('note TEXT'));
    });

    test('expense_shares: id/expense_id/user_id/share_amount sesuai plan', () {
      final script = createSchemaV1Scripts[4];
      expect(script, contains('expense_shares'));
      expect(script, contains('id TEXT NOT NULL PRIMARY KEY'));
      expect(script, contains('expense_id TEXT NOT NULL'));
      expect(script, contains('REFERENCES expenses (id)'));
      expect(script, contains('user_id TEXT NOT NULL'));
      expect(script, contains('REFERENCES users (id)'));
      expect(script, contains('share_amount INTEGER NOT NULL'));
    });
  });

  group('ExpenseSplitType', () {
    test('nilai DB = EQUAL, EXACT, PERCENT (selaras CHECK constraint)', () {
      expect(ExpenseSplitType.values, hasLength(3));
      expect(ExpenseSplitType.equal.dbValue, 'EQUAL');
      expect(ExpenseSplitType.exact.dbValue, 'EXACT');
      expect(ExpenseSplitType.percent.dbValue, 'PERCENT');
    });

    test('fromDbValue me-roundtrip ketiga nilai valid', () {
      for (final type in ExpenseSplitType.values) {
        expect(ExpenseSplitType.fromDbValue(type.dbValue), type);
      }
    });

    test('fromDbValue menolak nilai asing/korup', () {
      expect(() => ExpenseSplitType.fromDbValue('HALF'), throwsArgumentError);
      expect(() => ExpenseSplitType.fromDbValue('equal'), throwsArgumentError);
    });
  });
}
