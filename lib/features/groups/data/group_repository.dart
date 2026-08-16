/// Repository entitas `Group` (+ keanggotaan lewat `group_members`).
///
/// `createGroup` bersifat transaksional: grup + seluruh anggota ditulis dalam
/// satu `Transaction` sehingga tidak ada grup yang tersimpan tanpa metadata
/// keanggotaan lengkap.
library;

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:uuid/uuid.dart';

import '../../users/data/user_dao.dart';
import 'group_dao.dart';
import 'group_member_dao.dart';

class GroupRepository {
  GroupRepository(this._appDatabase, {Uuid? uuid}) : _uuid = uuid ?? Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  static const GroupDao _groupDao = GroupDao();
  static const GroupMemberDao _memberDao = GroupMemberDao();
  static const UserDao _userDao = UserDao();

  /// Membuat grup baru beserta daftar anggota awal ([memberUserIds]) dalam
  /// satu transaksi DB. Semua anggota harus sudah menjadi row `users` yang sah
  /// (dijamin Foreign Key pada `group_members`).
  Future<Group> createGroup({
    required String name,
    String defaultCurrency = 'IDR',
    required List<String> memberUserIds,
    String? id,
    int? createdAt,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nama grup tidak boleh kosong.');
    }
    if (memberUserIds.isEmpty) {
      throw ArgumentError.value(
        memberUserIds,
        'memberUserIds',
        'Grup harus memiliki minimal satu anggota.',
      );
    }
    if (memberUserIds.toSet().length != memberUserIds.length) {
      throw ArgumentError.value(
        memberUserIds,
        'memberUserIds',
        'Daftar anggota mengandung duplikat.',
      );
    }

    final cleanCurrency = defaultCurrency.trim().toUpperCase();
    if (cleanCurrency.isEmpty) {
      throw ArgumentError.value(
        defaultCurrency,
        'defaultCurrency',
        'Mata uang tidak boleh kosong.',
      );
    }

    final group = Group(
      id: id ?? _uuid.v4(),
      name: cleanName,
      defaultCurrency: cleanCurrency,
      createdAt: createdAt ?? _nowSeconds(),
    );

    await _appDatabase.db.transaction((txn) async {
      await _groupDao.insert(txn, group);
      await _memberDao.addAll(txn, groupId: group.id, userIds: memberUserIds);
    });
    return group;
  }

  Future<Group?> getGroupById(String id) =>
      _groupDao.getById(_appDatabase.db, id);

  Future<List<Group>> getAllGroups() => _groupDao.getAll(_appDatabase.db);

  Future<void> updateGroup(Group group) async {
    final cleanName = group.name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(
        group.name,
        'name',
        'Nama grup tidak boleh kosong.',
      );
    }
    await _groupDao.update(_appDatabase.db, group.copyWith(name: cleanName));
  }

  /// Menghapus grup beserta seluruh relasi tersambung (ON DELETE CASCADE:
  /// `group_members`, `expenses`, `expense_shares`).
  Future<void> deleteGroup(String id) async {
    await _groupDao.delete(_appDatabase.db, id);
  }

  Future<List<String>> getMemberUserIds(String groupId) =>
      _memberDao.getMemberUserIds(_appDatabase.db, groupId);

  /// Daftar objek [User] anggota grup (urutan nama).
  Future<List<User>> getGroupMembers(String groupId) async {
    final userIds = await getMemberUserIds(groupId);
    final members = <User>[];
    for (final userId in userIds) {
      final user = await _userDao.getById(_appDatabase.db, userId);
      if (user != null) {
        members.add(user);
      }
    }
    members.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return members;
  }

  Future<bool> isMember(String groupId, String userId) async {
    final ids = await getMemberUserIds(groupId);
    return ids.contains(userId);
  }

  /// Duplikat keanggotaan memunculkan [DatabaseException] (PK komposit).
  Future<void> addMember(String groupId, String userId) =>
      _memberDao.addMember(_appDatabase.db, groupId: groupId, userId: userId);

  /// Menghapus keanggotaan (tidak menghapus user/grup itu sendiri).
  Future<void> removeMember(String groupId, String userId) => _memberDao
      .removeMember(_appDatabase.db, groupId: groupId, userId: userId);

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
