import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_schema.dart';
import 'schema_migrator.dart';

/// Layer akses database lokal (SQLite via `sqflite`) — Phase 1, Task 2.
///
/// Sesuai `docs/architecture.md` §4.2:
/// * Koneksi `openDatabase` dibuat **idempoten** (singleton) — panggil
///   `AppDatabase.open()` berkali-kali tetap mengembalikan koneksi yang sama.
/// * `onConfigure` mengaktifkan `PRAGMA foreign_keys = ON` (wajib agar semua
///   kontrak Foreign Key / Primary Key komposit ditegakkan engine SQLite).
/// * `onCreate`/`onUpgrade` menjadi **basis migration strategy** — perubahan
///   skema masa depan (V2, dst.) ditambahkan sebagai langkah berurutan di
///   `_onUpgrade`, bukan dengan meng-edit DDL V1.
///
/// Koneksi test dapat disuntikkan lewat [open] ([factory] + `inMemory`),
/// memakai `sqflite_common_ffi` sehingga unit-test berjalan di host/desktop.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// Instance global tunggal — diisi saat `open()` tanpa [forceNew].
  static AppDatabase? _instance;

  /// Nama file database di direktori data aplikasi.
  static const String databaseFilename = 'debt_splitter.db';

  /// Koneksi SQLite aktif (berisi seluruh tabel skema lokal).
  Database get db => _db;

  /// `true` selama koneksi masih terbuka.
  bool get isOpen => _db.isOpen;

  /// Instance global yang sudah dibuka via [open], atau `null` bila belum.
  ///
  /// Dipakai layer DI (`lib/app/`) untuk menyuntikkan repo pada startup tanpa
  /// membuka koneksi baru — konsisten dengan jaminan idempoten [open].
  static AppDatabase? get instance => _instance;

  /// Membuka (atau mengambil koneksi yang sudah terbuka) database lokal.
  ///
  /// * [inMemory] — pakai database di memori (`:memory:`), untuk unit test.
  /// * [databasePath] — lokasi DB kustom; produksi cukup `open()` dan path
  ///   dihitung otomatis ke direktori data aplikasi.
  /// * [factory] — suntik `DatabaseFactory` kustom (test: FFI sqflite).
  /// * [forceNew] — paksa buka koneksi baru dan lewati singleton.
  ///
  /// Panggilan berulang tanpa `forceNew` mengembalikan instance yang sama
  /// sehingga idempoten.
  static Future<AppDatabase> open({
    bool forceNew = false,
    bool inMemory = false,
    String? databasePath,
    DatabaseFactory? factory,
  }) async {
    final existing = _instance;
    if (!forceNew && existing != null) {
      return existing;
    }

    final openedPath =
        databasePath ??
        (inMemory ? inMemoryDatabasePath : await defaultDatabasePath());
    return _openAt(openedPath, forceNew: forceNew, factory: factory);
  }

  /// Lokasi default file DB: `<dataDir>/debt_splitter.db`.
  static Future<String> defaultDatabasePath() async {
    final databases = await getDatabasesPath();
    return p.join(databases, databaseFilename);
  }

  static Future<AppDatabase> _openAt(
    String atPath, {
    required bool forceNew,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final db = await dbFactory.openDatabase(
      atPath,
      options: OpenDatabaseOptions(
        version: dbSchemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    final instance = AppDatabase._(db);
    if (!forceNew) {
      _instance = instance;
    }
    return instance;
  }

  /// Mengaktifkan Foreign Keys SEBELUM query apa pun dieksekusi.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Dipanggil saat database baru pertama kali dibuat (belum ada skema).
  ///
  /// Menjalankan skema V1 lalu (bila `dbSchemaVersion >= 2`) langsung
  /// menerapkan langkah V2 yang sama seperti migrasi — sehingga *fresh install*
  /// dan hasil `onUpgrade` menghasilkan struktur database yang identik.
  static Future<void> _onCreate(Database db, int version) async {
    assert(version == dbSchemaVersion, 'onCreate harus versi $dbSchemaVersion');
    for (final statement in createSchemaV1Scripts) {
      await db.execute(statement);
    }
    if (dbSchemaVersion >= 2) {
      await SchemaMigrator.migrateV1ToV2(db);
    }
  }

  /// Basis migration strategy: langkah berurutan V(n) -> V(n+1).
  ///
  /// ⚠️ JANGAN pernah meng-edit DDL V1 setelah rilis — perubahan skema
  /// dilakukan hanya lewat blok `if (oldVersion < n)` di bawah ini.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    assert(
      newVersion == dbSchemaVersion,
      'Versi skema $newVersion belum didukung (maks $dbSchemaVersion); '
      'perbarui aplikasi sebelum membuka database ini.',
    );
    assert(oldVersion <= newVersion, 'oldVersion harus <= newVersion');

    if (oldVersion < 2) {
      await SchemaMigrator.migrateV1ToV2(db);
    }
  }

  /// Menutup koneksi & membersihkan instance global (open berikutnya baru).
  Future<void> close() async {
    await _db.close();
    if (identical(_instance, this)) {
      _instance = null;
    }
  }
}
