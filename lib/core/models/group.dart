/// Entitas domain — `Group` (tabel `groups`).
///
/// Sesuai `docs/architecture.md`: seluruh `id` UUID v4; `created_at` berupa
/// INTEGER (Unix epoch detik).
library;

import 'package:debt_splitter/core/db/local_schema.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.defaultCurrency,
    required this.createdAt,
  });

  /// UUID v4 — Primary Key tabel `groups`.
  final String id;

  /// Nama grup (mis. "Trip Bromo").
  final String name;

  /// Kode mata uang default (ISO 4217, mis. `IDR`).
  final String defaultCurrency;

  /// Timestamp dibuat (Unix epoch detik).
  final int createdAt;

  factory Group.fromDbMap(Map<String, Object?> map) => Group(
    id: map[GroupCol.id] as String,
    name: map[GroupCol.name] as String,
    defaultCurrency: map[GroupCol.defaultCurrency] as String,
    createdAt: map[GroupCol.createdAt] as int,
  );

  Map<String, Object?> toDbMap() => {
    GroupCol.id: id,
    GroupCol.name: name,
    GroupCol.defaultCurrency: defaultCurrency,
    GroupCol.createdAt: createdAt,
  };

  Group copyWith({String? name, String? defaultCurrency}) => Group(
    id: id,
    name: name ?? this.name,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    createdAt: createdAt,
  );
}
