# 🧾 Plan Phase 5: OCR On-Device (Scan Struk) + Saran Sama-Rata per Item

> Dokumen rencana kerja untuk dua fitur berikutnya di atas mode **"Struk"** yang
> sudah rilis (skema V2 + `ItemBillSplitter` + editor item manual):
>
> 1. **OCR On-Device** — memindai struk dan **langsung mengisi daftar item**;
>    user tinggal centang siapa bertanggung jawab atas item apa.
> 2. **Saran Sama-Rata per Item** — item baru **default dicentang "semua orang"**
>    untuk barang yang terasa patungan (lauk, nasi, kerupuk, minum bareng),
>    mempercepat input.
>
> Kedua fitur ini adalah **enhancement di lapisan *upstream*** (generator item →
> `expense_shares`). Seluruh engine yang sudah dirilis — `NetBalanceCalculator`,
> `DebtSimplifierEngine` (greedy), QR sync, export/import JSON, PDF, WhatsApp
> share — **tidak perlu diubah**. Ini prinsip yang sama dengan `informasi.md`:
> *item & claims adalah generator upstream; balance & settlement tetap berjalan di
> atas `expense_shares`.*

---

## 1. Kondisi Saat Ini (Apa yang Sudah Ada)

| Lapisan | Status | File Kunci |
|---|---|---|
| Skema DB V2 (`expense_items`, `item_claims`, `split_type='ITEM'`) | ✅ Selesai | `lib/core/db/local_schema.dart` (`dbSchemaVersion = 2`) |
| Algoritma alokasi item → shares (pure function) | ✅ Selesai + 16 unit test | `lib/core/money/item_bill_splitter.dart` |
| DAO item & claims + `createItemSplitExpense` (atomik) | ✅ Selesai | `lib/features/expenses/data/expense_item_dao.dart`, `item_claim_dao.dart`, `expense_repository.dart` |
| UI mode "Struk" (input item manual + centang claims) | ✅ Selesai (manual) | `lib/app/ui/quick_entry_sheet.dart` (`_ItemBillEditor`) |
| Tombol "Pilih semua" per item | ✅ Ada (manual, per item) | `_DraftItemCard._toggleAllClaimants` |
| Izin kamera (Android + iOS) | ✅ Ada (dari `mobile_scanner` QR) | `AndroidManifest.xml`, `ios/Runner/Info.plist` |

**Yang belum ada:** OCR itu sendiri, default centang otomatis untuk item baru,
dan aksi massal (bulk) centang pada editor item.

> Catatan penting: fitur **B (Saran Sama-Rata)** sebaiknya dikerjakan **dulu**
> karena kecil, berisiko nol, dan menjadi fondasi UX "tinggal centang" yang juga
> dipakai hasil OCR pada fitur **A**.

---

## 2. Fitur A — OCR On-Device (Scan Struk)

### 2.1 Tujuan & Alur Pengguna

**Tujuan:** memindai struk rumah makan/kafe dengan kamera (offline), lalu aplikasi
mengisi daftar item (nama + harga + qty) secara otomatis. User tinggal:
1. mengecek/mengedit hasil OCR,
2. centang siapa makan item apa (dibantu default "semua orang" dari Fitur B),
3. simpan → sisanya (bagian per orang, saldo, settle-up) otomatis.

**Alur di HP:**
```
Mode Struk → tombol "📷 Scan struk"
  → layar kamera (capture 1 foto struk)          [bisa juga pilih dari galeri]
  → proses OCR on-device (100% offline)
  → layar review "Hasil scan"                     [nama/harga/qty diedit; ada peringatan bila total tidak cocok]
  → tap "Pakai hasil ini"
  → daftar item masuk ke editor Struk (draft)
  → centang siapa makan apa → Simpan
```

### 2.2 Pilihan Teknologi

| Opsi | Offline? | Akurasi struk | Ukuran APK | Catatan |
|---|---|---|---|---|
| **`google_mlkit_text_recognition`** ⭐ rekomendasi | ✅ model ter-bundel, tanpa unduhan | Bagus untuk teks Latin (Indonesia) | +~10–20 MB per ABI (diverifikasi saat build) | Pakai package spesifik ini, **bukan** `google_ml_kit` (yang meng-*bundle* semua modul & jauh lebih besar). Proses dari foto diam via `InputImage.fromFilePath`. |
| `tesseract_ocr` (native) | ✅ | Sedang pada struk thermal | Sedang (+ asset `ind.traineddata` ~1–2 MB) | Perlu integrasi native per platform; kualitas parsing baris lebih lemah dari ML Kit. |
| `flutter_vision` + PaddleOCR | ✅ | Tinggi | Sangat besar (±100 MB) | Overkill untuk MVP; cadangan bila akurasi ML Kit terbukti kurang. |
| API cloud (Vision/Gemini dll.) | ❌ | — | — | **Dilarang**: melanggar prinsip *offline-first* (`docs/architecture.md` §2). |

**Keputusan:** `google_mlkit_text_recognition` (bundled model). Detail:
- Tidak butuh koneksi internet / Play Services download (berbeda dari varian
  `play-services-mlkit`).
- Mendukung aksara Latin — struk Indonesia (huruf Latin) tercakup.
- Package ini hanya memuat modul text recognition → ukuran lebih terkendali.

**Risiko ukuran APK — mitigasi:**
- Bangun release memakai **Android App Bundle** (AAB) dan/atau **ABI splits**
  (`arm64-v8a`, `armeabi-v7a`, `x86_64`) sehingga tiap perangkat hanya
  mengunduh satu ABI — dampak per pengguna jauh lebih kecil dari angka mentah.
- Ukur delta APK sebelum/ sesudah (`flutter build apk --release`) dan catat
  angkanya di dokumen ini saat Task 1 selesai.

### 2.3 Arsitektur & File Baru

Struktur mengikuti pola *feature-first* yang sudah ada. Folder baru:

```
lib/features/ocr/
├── receipt_candidate_item.dart      # model hasil parsing (name, unitPrice, quantity, priceGuessed)
├── receipt_parse_result.dart        # hasil scan: items + totalFromReceipt + warnings
├── receipt_line_parser.dart         # ⭐ PURE FUNCTION: teks OCR → kandidat item (wajib unit test)
├── receipt_ocr_engine.dart          # wrap google_mlkit: InputImage → daftar baris teks
└── ui/
    ├── receipt_scan_screen.dart     # layar kamera + tombol capture
    └── receipt_review_sheet.dart    # review/editing hasil scan → kirim ke editor Struk
```

Plus (opsional, Task 5): tabel **`menu_dictionary`** — kamus lokal
(`id`, `name`, `last_price`, `updated_at`) agar saat mengetik nama menu yang
pernah dicatat, harga terakhir auto-terisi (dari `informasi.md`). Bila dibuat,
naikkan `dbSchemaVersion` 2 → 3 (tabel baru, tanpa recreate — jauh lebih mudah
dari migrasi V1→V2).

**Integrasi ke mode Struk (minimal invasive):**
- `_ItemBillEditor` menambah satu tombol **"📷 Scan struk"** di header.
- Hasil OCR dikonversi ke `List<ExpenseItemWithClaims>` (id item kosong,
  claimant memakai default dari Fitur B) lalu di-*merge* ke draft `_lines`
  yang sudah ada — **tanpa mengubah kontrak simpan** (`store.addItemSplitExpense`).
- Alur input foto: pakai plugin `camera` (satu foto, tombol capture) — izin
  `CAMERA` sudah terpasang untuk `mobile_scanner`, jadi tidak ada permission baru.
  Opsi "pilih dari galeri" (plugin `image_picker`) boleh ditambahkan belakangan
  (perlu `NSPhotoLibraryUsageDescription` di iOS).

### 2.4 Strategi Parsing (Inti dari Fitur Ini)

ML Kit hanya memberi **teks + bounding box per baris** — tidak ada struktur
tabel/kolom. Semua kecerdasan ada di `ReceiptLineParser` (pure function, bebas
I/O, 100% unit-testable):

1. **Ekstraksi harga (integer, tanpa `double`)** — regex menangkap variasi
   format struk Indonesia:
   - `Rp 25.000`, `Rp25.000`, `25.000`, `25.000,-`, `25,000` (koma = desimal
     hanya bila 2 digit & tidak ada titik ribuan lain).
   - Konversi ke `MoneyAmount` (int Rupiah) via parser yang **sudah ada**:
     `tryParseRupiahField` (`lib/core/money/money_input_parser.dart`).
2. **Klasifikasi baris:**
   - *Header/footer* dibuang: nama warung, alamat, tanggal, "TERIMA KASIH",
     "SELAMAT DATANG", nomor telepon, dll.
   - *Baris item* = (nama + harga) di baris yang sama; baris tanpa harga dianggap
     **lanjutan nama** item sebelumnya (nama menu 2 baris).
   - Baris *total/struktur* dikenali: `TOTAL`, `SUBTOTAL`, `PAJAK`, `DISC`,
     `BAYAR`, `KEMBALI`, `PPN`, `SERVICE` — tidak dijadikan item, tapi dipakai
     cross-check.
   - Baris `BATAL`/`RETUR` dilewati (barang yang dibatalkan).
3. **Deteksi kuantitas:** pola `2 x`, `2X`, `x2`, atau nama berulang pada baris
   berurutan → `quantity > 1`.
4. **Cross-check total:** bandingkan `sum(item × qty)` dengan baris `TOTAL`.
   Beda nominal → tampilkan **warning** ("Total item Rp148.000 vs TOTAL struk
   Rp154.000 — periksa kembali") alih-alih menolak input. Konservasi akhir tetap
   dijamin `ItemBillSplitter` (harga final adalah yang disimpan user).
5. **Penanda kepercayaan:** item yang harga/qty-nya tidak dapat diekstrak diberi
   flag `priceGuessed` dan tampil dengan gaya "perlu diedit" di layar review.
   *Catatan:* confidence score boleh bertipe `double` karena **bukan** nominal
   uang (aturan `docs/architecture.md` §3 hanya mengikat kalkulasi uang).

**Ruang lingkup v1:** satu foto per struk. Struk bergulir panjang (multi-capture /
stitching) = fase lanjutan, dicatat sebagai *out of scope*.

### 2.5 Task Breakdown Fitur A

| # | Task | Detail & Definition of Done | Estimasi |
|---|---|---|---|
| A1 | Setup dependency & platform | Tambah `google_mlkit_text_recognition` (+ `camera`). Verifikasi build Android & iOS, ukur **delta ukuran APK**, catat angka di sini. `flutter analyze` bersih. | 0,5–1 hari |
| A2 | `ReceiptLineParser` + unit test | Pure function: ekstraksi harga (semua varian format IDR), klasifikasi baris, qty, cross-check TOTAL. Fixture struk asli (5–8 contoh: warung, kafe, restoran cepat saji) di `test/features/ocr/receipt_line_parser_test.dart`. **Wajib 100% lulus.** | 2–3 hari |
| A3 | `ReceiptOcrEngine` | `InputImage` (dari foto) → daftar baris teks via ML Kit. Uji manual offline (mode pesawat). | 0,5 hari |
| A4 | Layar scan + review | `ReceiptScanScreen` (kamera + capture) dan `ReceiptReviewSheet` (edit nama/harga/qty, warning total, hapus item salah). Hasil "Pakai" → merge ke `_ItemBillEditor` draft. | 2 hari |
| A5 | (Opsional) `menu_dictionary` | Migrasi schema v3 + auto-fill harga saat mengetik nama item yang pernah dicatat. Pisahkan sebagai milestone terpisah bila ingin dirilis dulu. | 1–2 hari |
| A6 | QA perangkat nyata | Uji di 2–3 perangkat (Android low-end + iOS), struk thermal asli, mode pesawat. Sesuaikan heuristik parser bila perlu. | 1 hari |

**Total estimasi Fitur A: ±7–9 hari kerja** (tanpa A5).

---

## 3. Fitur B — Saran Sama-Rata per Item

### 3.1 Masalah Saat Ini

Di editor Struk (`quick_entry_sheet.dart`):
- Setiap item baru **mulai dengan centang kosong** → untuk item patungan
  (nasi, lauk, kerupuk, air putih bareng) user harus tap "Pilih semua" setiap kali.
- Belum ada aksi **massal** untuk satu bill penuh (mis. 10 item, 8 di antaranya
  patungan → 8× tap "Pilih semua").

### 3.2 Desain Fitur

1. **Pengaturan default centang item baru** — satu toggle di header editor Struk:
   - **"Item baru otomatis dibagi semua anggota"** (default: **ON**).
   - Saat ON, setiap baris baru langsung `claimants = semua id anggota`.
   - User tetap bisa meng-uncentang per orang (minuman pribadi, dll.) — perilaku
     per item tidak berubah.
2. **Aksi massal (bulk)** di header editor:
   - **"Centang semua"** dan **"Kosongkan semua"** untuk **seluruh bill** —
     sekali tap untuk bill yang mayoritas patungan (atau sebaliknya).
3. **(Opsional, mode tambahan)** pilihan strategi default: `Semua` / `Kosong` /
   `Ikuti item sebelumnya`. Mode "Ikuti item sebelumnya" berguna saat tiap orang
   pesan set menu yang mirip (centang hampir sama antar item). V1 cukup `Semua` +
   `Kosong`; mode ini bisa menyusul.

**Sinergi dengan OCR:** hasil scan (Fitur A) langsung memakai default ini — item
hasil OCR langsung tercantang "semua orang", user tinggal menyesuaikan. Ini yang
mewujudkan kalimat *"user tinggal centang siapa bertanggung jawab atas apa"*.

### 3.3 Perubahan File

| File | Perubahan |
|---|---|
| `lib/app/ui/quick_entry_sheet.dart` | `_DraftLine` diberi flag `prefillAll`; `_addLine` mengisi semua claimant sesuai pengaturan; header `_ItemBillEditor` mendapat toggle default + 2 tombol bulk; perbaiki `_emit()` (sudah menyala setiap perubahan). |
| `test/app/quick_entry_sheet_test.dart` | Test widget baru (lihat 3.5). |

Tidak ada perubahan schema/DB, repository, atau engine.

### 3.4 Task Breakdown Fitur B

| # | Task | Definition of Done | Estimasi |
|---|---|---|---|
| B1 | Default centang item baru | Toggle di header editor (default ON). Item baru ter-centang semua saat ON. | 0,5 hari |
| B2 | Aksi massal | Tombol "Centang semua" / "Kosongkan semua" berlaku ke seluruh bill. | 0,5 hari |
| B3 | Unit/widget test | Item baru pre-checked sesuai toggle; bulk select/deselect; toggle global ON/OFF; perilaku per-item tetap (uncentang individu). | 0,5–1 hari |

**Total estimasi Fitur B: ±1,5–2 hari kerja.**

---

## 4. Urutan Pengerjaan & Dependensi

```text
Fitur B (B1 → B2 → B3)          ≈ 2 hari     ← kecil, 0 risiko, fondasi UX
        ↓
Fitur A (A1 → A2 → A3 → A4 → A6) ≈ 7–9 hari  ← A5 (menu dictionary) opsional setelah A4
```

- B **tidak** bergantung pada A; A memakai default centang dari B untuk hasil OCR.
- A2 (parser) adalah bagian paling berisiko → dikerjakan lebih awal dan diuji
  dengan fixture struk sebelum menyentuh UI.
- Setiap task ditutup dengan `flutter analyze` bersih dan test lulus
  (`flutter test`) — mengikuti standar `docs/architecture.md` §7.

---

## 5. Daftar Periksa Kualitas (Final QC)

- [ ] **Offline-first:** scan struk & parsing berjalan di mode pesawat, tanpa
      panggilan jaringan (tidak ada dependency `http`/`dio` baru).
- [ ] **Presisi keuangan:** seluruh harga struk dikonversi ke `MoneyAmount`
      (`int`) tanpa `double` pada jalur uang; reuse `tryParseRupiahField`.
- [ ] **Konservasi:** `sum(expense_shares) == expense.amount` tetap dijamin —
      tidak ada perubahan pada `ItemBillSplitter` / repository.
- [ ] **Migrasi aman:** bila `menu_dictionary` jadi, migrasi 2→3 hanya `CREATE
      TABLE` baru (tanpa recreate) dan `dbSchemaVersion` dinaikkan.
- [ ] **Unit test:** parser OCR ≥ 20 kasus (fixture struk ID); widget test editor
      Struk (Fitur B) lulus; seluruh suite lama tetap hijau.
- [ ] **Ukuran APK:** delta ukuran terdokumentasi; release memakai AAB/ABI-split.
- [ ] **Tidak mengubah lapisan rilis:** engine balance, greedy, QR sync,
      export/import, PDF, WhatsApp share tanpa modifikasi (kecuali serialisasi
      item/claims yang sudah ada di V2).

---

## 6. Yang TIDAK Perlu Diubah (Nilai Tambah Arsitektur Ini)

Karena `expense_shares` tetap satu-satunya input engine:

- `NetBalanceCalculator`, `DebtSimplifierEngine` (greedy), tampilan hijau/merah
  balance anggota → **tanpa perubahan**.
- QR sync, export/import JSON, PDF summary, WhatsApp share → **tanpa perubahan**
  (item & claims sudah terserialisasi di skema V2 / `GroupSyncPayload` v2).
- `ItemBillSplitter` dan 16 unit test-nya → **tanpa perubahan**.

OCR & Saran Sama-Rata hanyalah **cara baru mengisi input** — seluruh mesin di
bawahnya tetap seperti sekarang.
