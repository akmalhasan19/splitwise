/// Entitas domain `User` (tabel `users`).
///
/// Sesuai `docs/architecture.md`:
/// * `id` selalu UUID v4 (TEXT) — aman untuk merge/sync P2P antarperangkat;
/// * `createdAt` timestamp INTEGER (Unix epoch detik).
library;

import 'package:debt_splitter/core/db/local_schema.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.createdAt,
  });

  /// UUID v4 — Primary Key tabel `users`.
  final String id;

  /// Nama tampilan user.
  final String name;

  /// Kode warna avatar (hex seperti `#21A366`).
  final String avatarColor;

  /// Timestamp dibuat (Unix epoch detik).
  final int createdAt;

  factory User.fromDbMap(Map<String, Object?> map) => User(
    id: map[UserCol.id] as String,
    name: map[UserCol.name] as String,
    avatarColor: map[UserCol.avatarColor] as String,
    createdAt: map[UserCol.createdAt] as int,
  );

  Map<String, Object?> toDbMap() => {
    UserCol.id: id,
    UserCol.name: name,
    UserCol.avatarColor: avatarColor,
    UserCol.createdAt: createdAt,
  };

  User copyWith({String? name, String? avatarColor}) => User(
    id: id,
    name: name ?? this.name,
    avatarColor: avatarColor ?? this.avatarColor,
    createdAt: createdAt,
  );
}
