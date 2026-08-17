# 📱 Debt-Splitter — Dokumentasi Penggunaan & Alur Eksekusi

> Deliverable **Phase 2 — Minggu 4** (Advanced Offline Features & Polish).
> Aplikasi pencatat utang patungan **offline-first**: berjalan 100% lokal,
> tanpa backend server, tanpa login/auth, tanpa koneksi internet.

---

## 1. Prinsip & Persyaratan

| Aspek | Keterangan |
|---|---|
| Koneksi internet | **Tidak diperlukan sama sekali** — seluruh fitur bekerja di *Airplane Mode*. |
| Data | Tersimpan di SQLite lokal perangkat (`debt_splitter.db`). |
| Pertukaran data antarperangkat | QR Code (sinkronisasi P2P) & file JSON (backup/restore) — keduanya offline. |
| Nominal uang | Seluruhnya `INTEGER` Rupiah utuh (`MoneyAmount`) — tanpa `double`/`float`. |

Persyaratan perangkat untuk fitur scan QR: kamera (izin kamera otomatis
diminta saat pertama kali membuka layar Scan).

---

## 2. Alur Eksekusi Aplikasi (End-to-End)

```text
Buka aplikasi (tanpa login)
  └─ Dashboard: daftar grup + ringkasan saldo
       ├─ "+ Grup Baru"  → isi nama grup + nama anggota → otomatis masuk Detail Grup
       └─ menu ⋮ (kanan atas)
            ├─ Scan QR (sinkronisasi)  → import grup dari perangkat lain
            ├─ Export semua data (JSON) → simpan/share file backup
            └─ Import dari file (JSON)   → restore backup
              
Detail Grup (2 tab)
  ├─ Tab "Riwayat"   → daftar transaksi + chip saldo per anggota
  ├─ Tab "Pelunasan" → kartu "X transfer Rp… ke Y" + tombol "Bagikan" (WhatsApp)
  └─ FAB "+"          → catat pengeluaran cepat (nominal auto-format, pilih pembayar,
                        split sama rata / custom)
  └─ menu ⋮ (kanan atas)
       ├─ Bagikan via QR (sync offline) → tampilkan QR untuk dipindai perangkat lain
       ├─ Export grup (JSON)            → file backup satu grup
       └─ Cetak PDF ringkasan           → laporan PDF (saldo + pelunasan) untuk dibagikan/dicetak
```

---

## 3. Fitur per Layar

### 3.1 Dashboard
- Daftar seluruh grup, jumlah anggota, total tercatat, dan chip ringkasan saldo
  terbesar (hijau = piutang, merah = utang).
- Geser ke bawah untuk muat ulang; ikon ↻ di AppBar juga memuat ulang.
- Tekan lama kartu grup untuk **menghapus** grup beserta seluruh transaksinya.

### 3.2 Form Catat Pengeluaran (Quick Entry)
- Nominal diinput dengan **auto-formatting ribuan** (`Rp 1.000.000`).
- Pilih pembayar ("Dibayar oleh") dari anggota grup.
- Split **Sama rata**: sisa pembagian otomatis didistribusikan
  (contoh Rp100.000 / 3 → 33.334 + 33.333 + 33.333; konservasi terjaga).
- Split **Custom**: isi nominal per orang; ada indikator
  "Total bagian … / target" (✓/✗) dan saran sama-rata.

### 3.3 Settle Up
- Kartu instruksi pelunasan hasil algoritma greedy
  (*"Budi transfer Rp33.333 ke Andi"*) — jumlah transaksi seminimal mungkin.
- Tombol **Bagikan** membuka OS Share Sheet dengan ringkasan berformat
  WhatsApp (bold `*…*`, emoji, saldo & langkah pelunasan).

### 3.4 QR Sync (P2P Offline) — *baru di Minggu 4*
**Bagikan (Generator):**
1. Buka grup → menu ⋮ → **"Bagikan via QR (sync offline)"**.
2. QR menampilkan payload grup (metadata + anggota + seluruh transaksi) yang
   dikompresi `gzip` lalu di-encode Base64 (ringkas & muat di QR).
3. Alternatif: tombol **Salin** / **Bagikan teks** mengirim payload sebagai
   teks (WhatsApp/chat lain).

**Scan & Import (perangkat tujuan):**
1. Dashboard → menu ⋮ → **"Scan QR (sinkronisasi)"**.
2. Arahkan kamera ke QR; aplikasi mendeteksi format Debt-Splitter (`DS1`).
3. Preview grup (nama, jumlah anggota & transaksi) → tekan **Import**.
4. Data di-*merge* ke DB lokal **dilindungi UUID** (idempoten):
   - anggota/user baru ditambahkan, yang sudah ada diperbarui;
   - transaksi baru ditambahkan, transaksi yang berubah diperbarui;
   - **tidak ada data yang dihapus** — aman diulang berapa kali pun.

### 3.5 Backup & Export/Import (JSON) — *baru di Minggu 4*
- **Export semua data**: Dashboard → ⋮ → *Export semua data (JSON)* →
  file `debt_splitter_backup_<waktu>.json` dibuka lewat Share Sheet
  (simpan ke file manager / kirim via chat).
- **Export per grup**: Detail grup → ⋮ → *Export grup (JSON)*.
- **Import dari file**: Dashboard → ⋮ → *Import dari file (JSON)* → pilih
  file `.json` (format backup `DSB1` atau payload grup `DS1` keduanya
  didukung) → preview → Import. Idempoten & non-destruktif seperti QR.

### 3.6 Cetak PDF Ringkasan — *baru di Minggu 4*
- Detail grup → ⋮ → **"Cetak PDF ringkasan"** → file
  `debt_splitter_summary_<waktu>.pdf` (A4) berisi: judul grup, total tercatat,
  tabel saldo per anggota (lunas/berhutang/akan menerima), dan tabel
  rekomendasi pelunasan. Bagikan via Share Sheet untuk dicetak/dikirim.

---

## 4. Format File Backup (Ringkas)

- **Payload grup** (marker `DS1`): `t`, `v` (versi), `x` (waktu export),
  `g` (grup), `m` (anggota), `e` (transaksi + share).
- **Backup penuh** (marker `DSB1`): daftar payload grup.
- Key memakai nama pendek agar payload ringkas; dikompresi gzip + Base64
  untuk QR. Seluruh nominal tetap `int`.

---

## 5. QA / Performa (Minggu 4)

- Unit test **189 lulus** (`flutter test`), termasuk:
  - roundtrip serialisasi payload & backup (format korup ditolak);
  - merge importer (fresh import, idempoten, update, konservasi uang);
  - **performa engine pada skala besar** (1000 user selesai < 5 detik,
    O(n log n), deterministik);
  - edge case pembagian uang & konservasi total.
- `flutter analyze` bersih (0 issue).
- UI memakai daftar *lazy* (`ListView.builder`) & ikon di-tree-shake pada
  build release (log: pengurangan font ikon 99.7%).
- **Verifikasi di perangkat nyata** (langkah manual, disarankan sebelum
  rilis): uji QR scan pada 2 perangkat, import/export file, dan sentuhan UI
  pada perangkat berspesifikasi rendah.

---

## 6. Build Release Candidate (RC)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Catatan:
- **Android**: APK RC sudah teruji build (Android SDK 36, AGP 9.0.1).
- **iOS (IPA)**: memerlukan macOS + Xcode — build di lingkungan macOS dengan
  `flutter build ipa`; izin kamera (`NSCameraUsageDescription`) sudah
  disiapkan di `ios/Runner/Info.plist`.
- APK release ditandatangani dengan debug key bawaan template (untuk RC
  distribusi publik, ganti dengan signing config produksi di
  `android/app/build.gradle.kts`).

---

## 7. Perintah Developer

```bash
flutter pub get
flutter analyze        # wajib bersih
flutter test           # 100% unit test
flutter run            # jalankan di device/emulator
flutter build apk --release
```
