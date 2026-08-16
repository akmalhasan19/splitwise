import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/features/users/data/user_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  const int fixedCreatedAt = 1_700_000_000;

  late AppDatabase db;
  late UserRepository repository;

  setUp(() async {
    db = await openTestDatabase();
    repository = UserRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('UserRepository — CRUD', () {
    test(
      'createUser: id UUID, avatar default stabil, created_at override',
      () async {
        final user = await repository.createUser(
          name: 'Andi',
          createdAt: fixedCreatedAt,
        );

        expect(user.id, isNotEmpty);
        expect(user.id.split('-'), hasLength(5)); // format UUID v4
        expect(user.name, 'Andi');
        expect(user.avatarColor, UserRepository.defaultAvatarColor('Andi'));
        expect(user.createdAt, fixedCreatedAt);

        final fetched = await repository.getUserById(user.id);
        expect(fetched, isNotNull);
        expect(fetched!.name, 'Andi');
      },
    );

    test('nama di-trim; nama kosong ditolak', () async {
      final user = await repository.createUser(
        name: '  Budi Santoso  ',
        createdAt: fixedCreatedAt,
      );
      expect(user.name, 'Budi Santoso');

      await expectLater(
        repository.createUser(name: '   '),
        throwsArgumentError,
      );
    });

    test('getUserById mengembalikan null bila tidak ada', () async {
      expect(await repository.getUserById('u-gak-ada'), isNull);
    });

    test('getAllUsers & filter nama (LIKE)', () async {
      final andi = await repository.createUser(
        name: 'Andi',
        createdAt: fixedCreatedAt,
      );
      final budi = await repository.createUser(
        name: 'Budi',
        createdAt: fixedCreatedAt,
      );

      final all = await repository.getAllUsers();
      expect(all, hasLength(2));
      expect(
        all.map((user) => user.id),
        containsAll(<String>[andi.id, budi.id]),
      );

      final filtered = await repository.getAllUsers(nameContains: 'and');
      expect(filtered.map((user) => user.name).toList(), <String>['Andi']);
    });

    test('updateUser menyimpan perubahan nama/avatar', () async {
      final user = await repository.createUser(
        name: 'Andi',
        createdAt: fixedCreatedAt,
      );
      await repository.updateUser(user.copyWith(name: 'Andi Malang'));

      final fetched = await repository.getUserById(user.id);
      expect(fetched!.name, 'Andi Malang');
      expect(fetched.avatarColor, user.avatarColor);

      await expectLater(
        repository.updateUser(user.copyWith(name: ' ')),
        throwsArgumentError,
      );
    });

    test('deleteUser menghapus & false bila user tidak ada', () async {
      final user = await repository.createUser(
        name: 'Citra',
        createdAt: fixedCreatedAt,
      );

      expect(await repository.deleteUser(user.id), isTrue);
      expect(await repository.getUserById(user.id), isNull);

      expect(await repository.deleteUser(user.id), isFalse);
    });

    test('id duplikat ditolak (Primary Key)', () async {
      await repository.createUser(
        id: 'u-1',
        name: 'Andi',
        createdAt: fixedCreatedAt,
      );
      await expectLater(
        repository.createUser(
          id: 'u-1',
          name: 'Budi',
          createdAt: fixedCreatedAt,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
