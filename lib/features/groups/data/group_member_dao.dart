/// Data Access Object tabel junction `group_members` (PK komposit).
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/group_member.dart';
import 'package:sqflite/sqflite.dart';

class GroupMemberDao {
  const GroupMemberDao();

  /// PK komposit duplicate akan memunculkan [DatabaseException].
  Future<int> addMember(
    DatabaseExecutor db, {
    required String groupId,
    required String userId,
  }) => db.insert(DbTable.groupMembers, <String, Object?>{
    GroupMemberCol.groupId: groupId,
    GroupMemberCol.userId: userId,
  });

  Future<int> addAll(
    DatabaseExecutor db, {
    required String groupId,
    required Iterable<String> userIds,
  }) async {
    var inserted = 0;
    for (final userId in userIds) {
      inserted += await addMember(db, groupId: groupId, userId: userId);
    }
    return inserted;
  }

  Future<int> removeMember(
    DatabaseExecutor db, {
    required String groupId,
    required String userId,
  }) => db.delete(
    DbTable.groupMembers,
    where: '${GroupMemberCol.groupId} = ? AND ${GroupMemberCol.userId} = ?',
    whereArgs: <Object?>[groupId, userId],
  );

  Future<int> deleteByGroup(DatabaseExecutor db, String groupId) => db.delete(
    DbTable.groupMembers,
    where: '${GroupMemberCol.groupId} = ?',
    whereArgs: <Object?>[groupId],
  );

  Future<List<GroupMember>> getByGroup(
    DatabaseExecutor db,
    String groupId,
  ) async {
    final rows = await db.query(
      DbTable.groupMembers,
      where: '${GroupMemberCol.groupId} = ?',
      whereArgs: <Object?>[groupId],
      orderBy: '${GroupMemberCol.userId} ASC',
    );
    return rows.map(GroupMember.fromDbMap).toList();
  }

  Future<List<String>> getMemberUserIds(
    DatabaseExecutor db,
    String groupId,
  ) async {
    final members = await getByGroup(db, groupId);
    return members.map((member) => member.userId).toList();
  }

  Future<int> memberCount(DatabaseExecutor db, String groupId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbTable.groupMembers} '
      'WHERE ${GroupMemberCol.groupId} = ?',
      <Object?>[groupId],
    );
    return rows.single['cnt']! as int;
  }
}
