/// Skema Data Lokal — Phase 1, Task 2.
///
/// Definisi skema SQLite (via `sqflite`) sesuai `implementation_plan.md`:
/// entitas `User`, `Group`, `GroupMember` (junction), `Expense`, dan
/// `ExpenseShare`.
///
/// Konvensi yang dianut (kontrak `docs/architecture.md`):
/// 1. Seluruh `id` bertipe `TEXT` berisi UUID (RFC 4122 v4) — aman untuk
///    merge/sync P2P antarperangkat tanpa konflik identitas.
/// 2. Nominal uang (`amount`, `share_amount`) bertipe `INTEGER` — konsisten
///    dengan `lib/core/money/money_amount.dart` (tanpa `double`/`float`).
/// 3. Timestamp (`created_at`, `date`) bertipe `INTEGER` (Unix epoch detik).
/// 4. `expenses.split_type` dibatasi `EQUAL` | `EXACT` | `PERCENT` via CHECK.
/// 5. Relasi antar tabel memakai Foreign Key; `group_members` memakai
///    Primary Key komposit (`group_id`, `user_id`).
library;

/// Versi skema database saat ini (1 = skema awal aplikasi).
///
/// Naikkan angka ini setiap kali struktur berubah, lalu daftarkan langkah
/// migrasi di `AppDatabase._onUpgrade`. Jangan pernah mengubah isi
/// `createSchemaV1Scripts` setelah dirilis.
const int dbSchemaVersion = 1;

/// Nama-nama tabel skema lokal.
///
/// Dipakai bersama (shared) oleh seluruh DAO/repository agar bebas typo.
abstract final class DbTable {
  static const String users = 'users';
  static const String groups = 'groups';
  static const String groupMembers = 'group_members';
  static const String expenses = 'expenses';
  static const String expenseShares = 'expense_shares';
}

/// Kolom tabel `users` (entitas `User`).
abstract final class UserCol {
  static const String id = 'id'; // TEXT, UUID, PRIMARY KEY
  static const String name = 'name'; // TEXT
  static const String avatarColor = 'avatar_color'; // TEXT
  static const String createdAt = 'created_at'; // INTEGER (timestamp)
}

/// Kolom tabel `groups` (entitas `Group`).
abstract final class GroupCol {
  static const String id = 'id'; // TEXT, UUID, PRIMARY KEY
  static const String name = 'name'; // TEXT
  static const String defaultCurrency = 'default_currency'; // TEXT
  static const String createdAt = 'created_at'; // INTEGER (timestamp)
}

/// Kolom tabel `group_members` (junction `GroupMember`).
abstract final class GroupMemberCol {
  static const String groupId = 'group_id'; // TEXT -> groups.id (FK)
  static const String userId = 'user_id'; // TEXT -> users.id (FK)
}

/// Kolom tabel `expenses` (entitas `Expense`).
abstract final class ExpenseCol {
  static const String id = 'id'; // TEXT, UUID, PRIMARY KEY
  static const String groupId = 'group_id'; // TEXT -> groups.id (FK)
  static const String paidBy = 'paid_by'; // TEXT -> users.id (FK)
  static const String amount = 'amount'; // INTEGER (nominal uang utuh)
  static const String splitType = 'split_type'; // TEXT: EQUAL|EXACT|PERCENT
  static const String date = 'date'; // INTEGER (timestamp)
  static const String note = 'note'; // TEXT (nullable)
}

/// Kolom tabel `expense_shares` (entitas `ExpenseShare`).
abstract final class ExpenseShareCol {
  static const String id = 'id'; // TEXT, UUID, PRIMARY KEY
  static const String expenseId = 'expense_id'; // TEXT -> expenses.id (FK)
  static const String userId = 'user_id'; // TEXT -> users.id (FK)
  static const String shareAmount = 'share_amount'; // INTEGER (nominal utuh)
}

/// Tipe pembagian biaya pada sebuah expense (kolom `expenses.split_type`).
///
/// Nilai yang disimpan ke DB adalah string UPPER-CASE (`dbValue`), persis sama
/// dengan daftar CHECK constraint pada skema — jangan diubah sepihak.
enum ExpenseSplitType {
  equal('EQUAL'),
  exact('EXACT'),
  percent('PERCENT');

  const ExpenseSplitType(this.dbValue);

  /// Nilai yang disimpan di kolom `expenses.split_type`.
  final String dbValue;

  /// Mencari enum dari nilai DB (UPPER-CASE). Melempar [ArgumentError] jika
  /// nilai tidak dikenal — menolak data korup sebelum masuk ke lapisan bisnis.
  static ExpenseSplitType fromDbValue(String value) {
    for (final type in ExpenseSplitType.values) {
      if (type.dbValue == value) {
        return type;
      }
    }
    throw ArgumentError.value(
      value,
      'value',
      'split_type tidak dikenal (harus EQUAL/EXACT/PERCENT): $value',
    );
  }
}

/// Pernyataan DDL untuk membuat skema V1 (5 tabel).
///
/// ⚠️ KONTRAK MIGRASI: setelah rilis, daftar ini TIDAK BOLEH diubah/di-edit.
/// Perubahan struktur hanya boleh lewat langkah migrasi berurutan di
/// `AppDatabase._upgradeSchema` (produk dari `onUpgrade` sqflite), sehingga
/// data lama perangkat tetap utuh.
final List<String> createSchemaV1Scripts = const <String>[
  '''
  CREATE TABLE users (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    avatar_color TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE groups (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    default_currency TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE group_members (
    group_id TEXT NOT NULL
      REFERENCES groups (id) ON DELETE CASCADE,
    user_id TEXT NOT NULL
      REFERENCES users (id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, user_id)
  )
  ''',
  '''
  CREATE TABLE expenses (
    id TEXT NOT NULL PRIMARY KEY,
    group_id TEXT NOT NULL
      REFERENCES groups (id) ON DELETE CASCADE,
    paid_by TEXT NOT NULL
      REFERENCES users (id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL,
    split_type TEXT NOT NULL
      CHECK (split_type IN ('EQUAL', 'EXACT', 'PERCENT')),
    date INTEGER NOT NULL,
    note TEXT
  )
  ''',
  '''
  CREATE TABLE expense_shares (
    id TEXT NOT NULL PRIMARY KEY,
    expense_id TEXT NOT NULL
      REFERENCES expenses (id) ON DELETE CASCADE,
    user_id TEXT NOT NULL
      REFERENCES users (id) ON DELETE CASCADE,
    share_amount INTEGER NOT NULL
  )
  ''',
];
