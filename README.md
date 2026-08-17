# 💸 Debt-Splitter (Splitwise Offline-First)

Aplikasi mobile pencatat utang patungan yang **berjalan 100% lokal** — tanpa backend
server, tanpa login/auth — dilengkapi algoritma **greedy** untuk menyederhanakan utang
("siapa harus transfer ke siapa, berapa") dengan jumlah transaksi seminimal mungkin.

## Dokumen Terkait

- [implementation_plan.md](implementation_plan.md) — rencana implementasi & task tracker
- [ide_project.md](ide_project.md) — ide & spesifikasi produk
- [docs/architecture.md](docs/architecture.md) — 📐 guideline arsitektur & tech stack
- [docs/git_workflow.md](docs/git_workflow.md) — 🔀 git workflow & branch protection
- [docs/user_guide.md](docs/user_guide.md) — 📱 dokumentasi penggunaan & alur eksekusi aplikasi

## Tech Stack

- **Framework**: Flutter (Dart) — kanal `stable`
- **Local Storage DB**: SQLite via `sqflite` (skema relasional + FK)
- **P2P Sync**: kompresi `gzip`/`zlib` + Base64 (bawaan SDK, `dart:io`/`dart:convert`),
  QR Code via `qr_flutter` (generate) & `mobile_scanner` (scan, on-device)
- **Presisi Keuangan**: seluruh nominal uang = **`MoneyAmount`** (`int`, satuan Rupiah).
  `double`/`float` **dilarang** pada kalkulasi uang.

## Quickstart

Persyaratan: [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.44 (Dart ≥ 3.12).

```bash
# 1. Generate folder platform (android/ios/web/...)
flutter create --project-name debt_splitter .

# 2. Ambil dependency
flutter pub get

# 3. Verifikasi lint & test
flutter analyze
flutter test

# 4. Jalankan
flutter run
```

## Status

- ☑ **Phase 1 Task 1** — Guideline Arsitektur & Tech Stack *(selesai)*
- ☑ **Phase 1 Task 2** — Implementasi Skema Data Lokal *(selesai)*
- ☑ **Phase 2 Minggu 1** — Setup Proyek, Data Layer & CRUD Core *(selesai)*
- ☑ **Phase 2 Minggu 2** — Engine Net Balance & Greedy Settlement *(selesai)*
- ☑ **Phase 2 Minggu 3** — UI/UX & WhatsApp Share *(selesai)*
- ☑ **Phase 2 Minggu 4** — Advanced Offline Features & Polish *(selesai: QR sync P2P (generate/scan + gzip/Base64 payload), backup export/import JSON, PDF summary report, unit test 189 lulus, APK release candidate dibangun)*
- ☐ Phase 3 — Final Quality Control & Developer Checklist *(berikutnya)*