/// Helper unit-test database lokal (SQLite via `sqflite_common_ffi`).
///
/// Dipakai bersama oleh seluruh test yang menyentuh layer data sehingga
/// setup DB identik (in-memory, koneksi segar per panggilan).
library;

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inisialisasi engine FFI satu kali per file test (`setUpAll`).
void initSqfliteFfi() => sqfliteFfiInit();

/// Membuka database SQLite di memori dengan koneksi baru (bukan singleton
/// global) — aman dipakai di `setUp`, ditutup di `tearDown`.
Future<AppDatabase> openTestDatabase() => AppDatabase.open(
  inMemory: true,
  forceNew: true,
  factory: databaseFactoryFfiNoIsolate,
);
