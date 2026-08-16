/// Repository entitas `User`.
///
/// Bertanggung jawab atas aturan domain yang tidak cukup ditangani SQL:
/// * `id` selalu UUID v4 (aman untuk merge/sync P2P antarperangkat);
/// * nama di-trim dan wajib tidak kosong;
/// * `avatar_color` default dari palet stabil berbasis nama.
library;

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:uuid/uuid.dart';

import 'user_dao.dart';

class UserRepository {
  UserRepository(this._appDatabase, {Uuid? uuid}) : _uuid = uuid ?? Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  static const UserDao _userDao = UserDao();

  /// Palet warna avatar default (hex) — dipakai jika pemanggil tidak
  /// menentukan `avatarColor`.
  static const List<String> avatarPalette = <String>[
    '#21A366', // hijau (primary)
    '#EF6C00', // oranye
    '#7B1FA2', // ungu
    '#0288D1', // biru
    '#C2185B', // pink
    '#5D4037', // cokelat
  ];

  /// Warna avatar stabil berbasis [name] (deterministik + idempoten).
  static String defaultAvatarColor(String name) {
    final sum = name.codeUnits.fold<int>(0, (acc, unit) => acc + unit);
    return avatarPalette[sum % avatarPalette.length];
  }

  /// Membuat user baru. [id] & [createdAt] boleh di-override (untuk test
  /// deterministik); default UUID v4 + epoch detik saat ini.
  Future<User> createUser({
    required String name,
    String? avatarColor,
    String? id,
    int? createdAt,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nama user tidak boleh kosong.');
    }

    final user = User(
      id: id ?? _uuid.v4(),
      name: cleanName,
      avatarColor: avatarColor ?? defaultAvatarColor(cleanName),
      createdAt: createdAt ?? _nowSeconds(),
    );

    await _userDao.insert(_appDatabase.db, user);
    return user;
  }

  Future<User?> getUserById(String id) => _userDao.getById(_appDatabase.db, id);

  Future<List<User>> getAllUsers({String? nameContains}) =>
      _userDao.getAll(_appDatabase.db, nameContains: nameContains);

  Future<void> updateUser(User user) async {
    final cleanName = user.name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(
        user.name,
        'name',
        'Nama user tidak boleh kosong.',
      );
    }
    final cleanAvatar = user.avatarColor.trim();
    if (cleanAvatar.isEmpty) {
      throw ArgumentError.value(
        user.avatarColor,
        'avatarColor',
        'Avatar color tidak boleh kosong.',
      );
    }

    await _userDao.update(_appDatabase.db, user.copyWith(name: cleanName));
  }

  /// Menghapus user. `false` bila user tidak ada. User yang terikat pada
  /// `expenses.paid_by` ditolak DB (ON DELETE RESTRICT) -> [DatabaseException].
  Future<bool> deleteUser(String id) async {
    return await _userDao.delete(_appDatabase.db, id) > 0;
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
