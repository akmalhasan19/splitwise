/// Entitas domain — junction `GroupMember` (tabel `group_members`).
///
/// Menghubungkan `Group` dengan `User`; Primary Key komposit
/// (`group_id`, `user_id`) ditegakkan pada level SQLite.
library;

import 'package:debt_splitter/core/db/local_schema.dart';

class GroupMember {
  const GroupMember({required this.groupId, required this.userId});

  /// FK -> `groups.id`.
  final String groupId;

  /// FK -> `users.id`.
  final String userId;

  factory GroupMember.fromDbMap(Map<String, Object?> map) => GroupMember(
    groupId: map[GroupMemberCol.groupId] as String,
    userId: map[GroupMemberCol.userId] as String,
  );

  Map<String, Object?> toDbMap() => {
    GroupMemberCol.groupId: groupId,
    GroupMemberCol.userId: userId,
  };
}
