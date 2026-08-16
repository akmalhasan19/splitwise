# Guideline Arsitektur & Tech Stack - Debt-Splitter

> Dokumen keluaran **Phase 1 - Task 1: Guideline Arsitektur & Tech Stack** dari
> `implementation_plan.md`. Berisi keputusan arsitektur, prinsip *offline-first*,
> aturan presisi keuangan, dan inisialisasi tech stack - menjadi kontrak
> engineering untuk seluruh fase berikutnya (Task 2, Phase 2, Phase 3).

---

## 1. Ringkasan Keputusan (Decision Summary)

| Area | Keputusan | Alternatif yang dievaluasi | Alasan |
|---|---|---|---|
| Framework | **Flutter** (Dart) - kanal stable | Kotlin Native, Swift | Cross-platform Android + iOS dari satu basis kode; ekosistem package matang; iterasi cepat untuk MVP 4 minggu. |
| Local Storage / DB Engine | **SQLite** (`sqflite`) | Hive, Isar, Room | Skema relasional (FK, PK komposit, join) cocok dengan SQL. SQLite = SQL penuh + ACID + FK constraint. Room khusus Kotlin/Android tidak relevan; `sqflite_common_ffi` memungkinkan unit test DB di desktop. |
| Kompresi Payload P2P | `gzip`/`zlib` (SDK dart:io) + Base64 (SDK dart:convert) | Library eksternal | Tanpa dependency tambahan; dapat dibuat *pure function* yang di-unit-test. |
| QR Code - Generator | `qr_flutter` | Canvas manual | Widget siap pakai (`QrImageView`), popular dan mature. |
| QR Code - Scanner | `mobile_scanner` | barcode_scan, zxing2 | Kamera on-device (CameraX/ML Kit Android, AVFoundation/Vision iOS) mendukung 100% offline. |
| UUID / Identitas | `uuid` (RFC 4122 v4) | AUTOINCREMENT integer | Field `id` string sesuai skema; aman untuk merge/sync P2P antarperangkat tanpa konflik ID. |
| State Management / DI | Ditentukan di Phase 2 Minggu 1 (Project Setup) | - | Bukan lingkup Task 1; tidak membuat keputusan prematur. |

### Versi dependency (verifikasi pub.dev API, 16 Agustus 2026)

| Package | Versi | Peran |
|---|---|---|
| `sqflite` | ^2.4.3 | SQLite DB engine |
| `path` | ^1.9.1 | Path helper |
| `path_provider` | ^2.1.6 | Direktori data aplikasi |
| `qr_flutter` | ^4.1.0 | Generator QR Code |
| `mobile_scanner` | ^7.4.0 | Scanner barcode/QR (on-device) |
| `uuid` | ^4.6.0 | UUID v4 untuk Primary Key |
| `flutter_lints` | ^6.0.0 | Linter (dev) |
| `sqflite_common_ffi` | ^2.4.2+1 | Unit test DB di host (dev) |

> `zlib/gzip` dan Base64 dipakai langsung dari SDK - tanpa dependency eksternal.

## 2. Prinsip Offline-First (Konfigurasi Prinsip)

Sumber: `ide_project.md` - pencatat patungan yang bekerja **100% tanpa sinyal / tanpa internet**.

Aturan wajib:

1. **Zero Backend & Zero Auth** - tidak ada server, tidak ada API eksternal, tidak ada login/token/perautan perangkat. Buka aplikasi langsung pakai.
2. **Single Source of Truth lokal** - seluruh data hidup di SQLite perangkat (bukan cache dari jaringan).
3. **Zero Network Dependency** - fitur inti (grup, expense, settle-up) tidak boleh memakai `http`/`dio`/WebSocket. Satu-satunya jalur keluar-masuk data: **QR P2P (Phase 4)** dan **export/import JSON (Phase 4)**.
4. **Airplane-Mode compatible** - Final QC (Phase 3) memverifikasi semua fitur core berjalan saat kondisi offline total.
5. **Migrasi aman** - akses DB via repository; perubahan schema memakai migration strategy (dibangun Phase 1 Task 2) agar data lama tetap utuh.

### Desain logis P2P Sync (diimplementasikan di Phase 4)

```text
Export: grup+transaksi -> serialisasi JSON -> gzip/ZLibCodec -> Base64 -> QR Code
Import: scan QR -> Base64 decode -> gunzip -> parse JSON -> merge ke DB lokal (dilindungi UUID)
```

---

## 3. Presisi Keuangan (Konfigurasi Tipe Data)

Skema (Phase 1 Task 2) menyimpan nominal uang sebagai `INTEGER` dan semua kalkulasi memakai aritmatika integer.

1. **Unit terkecil = Rp1** (Rupiah penuh). Nominal disimpan dan dihitung sebagai bilangan bulat tanpa desimal.
2. **`double`/`float` DILARANG** untuk penyimpanan maupun kalkulasi uang - ditegakkan ulang di Final QC Phase 3.
3. Seluruh nominal memakai typedef **`MoneyAmount`** (`lib/core/money/money_amount.dart`).
4. **Pembulatan eksplisit** pakai operator `~/` dan `%`. Contoh `Rp100.000 / 3` menghasilkan `33_333` per orang + sisa `1` yang dipertanggungjawabkan satu orang - dijamin tetap `100_000` (unit test: `test/money_amount_test.dart`).
5. **Konservasi**: penjumlahan seluruh `share_amount` setiap expense harus selalu sama persis dengan `amount`.

## 4. Inisialisasi Tech Stack (detail)

### 4.1 Framework: Flutter (Dart)

- Project name `debt_splitter` di `pubspec.yaml`; SDK Dart `>=3.12.0 <4.0.0`, Flutter `>=3.44.0`.
- Entry point minimal `lib/main.dart` (offline-first, tanpa panggilan jaringan apa pun).

### 4.2 DB Engine: SQLite (sqflite)

- Koneksi `openDatabase` dibuat idempoten, `onConfigure` mengaktifkan **Foreign Keys**, `onCreate`/`onUpgrade` jadi basis migration - diimplementasikan di **Phase 1 Task 2** (`lib/core/db/`).
- `sqflite_common_ffi` dipakai untuk unit test DB pada host tanpa emulator (dev).

### 4.3 P2P Sync Library (setup Task 1, dipakai Phase 4)

| Komponen | Dependency | Dipakai untuk |
|---|---|---|
| Kompresi | `gzip`/`ZLibCodec` (SDK dart:io) | Mengompres payload JSON sebelum masuk ke QR |
| Encoding | `base64Encode/Decode` (SDK dart:convert) | Binary ke teks QR dan sebaliknya |
| Generator QR | `qr_flutter` ^4.1.0 | `QrImageView(data: ...)` |
| Scanner QR | `mobile_scanner` ^7.4.0 | `MobileScanner(onDetect: ...)` - kamera on-device |

> Catatan implementasi Phase 4: Android perlu `<uses-permission android:name="android.permission.CAMERA"/>`; iOS perlu `NSCameraUsageDescription`.

---

## 5. Struktur Folder (Feature-First; diterapkan di Phase 2 Minggu 1)

| Path | Isi | Status |
|---|---|---|
| `lib/app/` | App shell, routing, DI | placeholder (`Minggu 3`) |
| `lib/core/money/` | `MoneyAmount`, `MoneyInputParser` (validator string -> int), `SplitCalculator` (equal split) | ✅ Minggu 1 |
| `lib/core/models/` | Entitas domain: `User`, `Group`, `GroupMember`, `Expense`, `ExpenseShare`, `ExpenseWithShares` | ✅ Minggu 1 |
| `lib/core/db/` | `AppDatabase` (sqflite) + `local_schema` (migration strategy) | ✅ Phase 1 |
| `lib/core/sync/` | Helper payload gzip+base64 & QR | placeholder (`Phase 4`) |
| `lib/core/utils/` | Formatter Rupiah, timestamp | placeholder (`Minggu 3`) |
| `lib/features/users/data/` | `UserDao` + `UserRepository` | ✅ Minggu 1 |
| `lib/features/groups/data/` | `GroupDao`, `GroupMemberDao` + `GroupRepository` | ✅ Minggu 1 |
| `lib/features/expenses/data/` | `ExpenseDao`, `ExpenseShareDao` + `ExpenseRepository` | ✅ Minggu 1 |
| `lib/features/settle_up/` | `DebtSimplifierEngine` + card UI | placeholder (`Minggu 2/3`) |
| `lib/features/share/` | WhatsApp summary | placeholder (`Minggu 3`) |
| `test/core/`, `test/features/` | Unit test per modul | ✅ aktif |

Keputusan kualitas: `DebtSimplifierEngine` dan semua modul kalkulasi uang dibuat **pure function** (bebas I/O) sehingga 100% unit-testable. UI hanya berbicara ke repository - tidak ke SQL langsung.

Setiap DAO bersifat **stateless**: method-nya menerima `DatabaseExecutor` sehingga aman dipakai pada koneksi biasa maupun di dalam *transaction* (multi-tabel atomik, mis. expense + shares). Repositori menyuntikkan UUID & menegakkan aturan domain (konservasi uang `sum(share) == amount`, pembayar/penerima wajib anggota grup, dsb).

---

## 6. Alur Data

```text
UI -> Validator (string -> int Money) -> Service/UseCase -> Repository -> AppDatabase (SQLite)
    -> Engine net-balance & greedy (Minggu 2) -> Settle-Up cards / WhatsApp summary (Minggu 3)
    -> Payload QR P2P (Minggu 4)
```

---

## 7. Perintah Developer

```bash
flutter pub get                     # tarik dependency
flutter analyze                     # wajib bersih sebelum commit
flutter test                        # unit test (100% wajib untuk modul keuangan/engine)
dart format lib test                # format kode (standar linter: analysis_options.yaml)
flutter run                         # jalankan app
```

---

## 8. Kesesuaian dengan Checklist `implementation_plan.md` (Phase 1 Task 1)

| Checklist | Pemenuhan |
|---|---|
| Konfigurasi Prinsip Offline-First (100% lokal tanpa backend/login) | Bagian 2 + `pubspec.yaml` tanpa dependency network + `lib/main.dart` |
| Konfigurasi Tipe Data Presisi Keuangan (seluruh `Integer`) | Bagian 3 + `lib/core/money/money_amount.dart` + unit test |
| Setup Framework pilihan | Bagian 4.1 + `pubspec.yaml` + `lib/main.dart` |
| Setup Local Storage DB Engine | Bagian 4.2 + dep `sqflite`, `path`, `path_provider`, `sqflite_common_ffi` |
| Setup P2P Sync Library (gzip & QR) | Bagian 4.3 + dep `qr_flutter`, `mobile_scanner` (gzip/Base64 dari SDK) |