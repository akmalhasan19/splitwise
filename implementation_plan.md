# 🚀 Implementation Plan & Task Tracker: Mobile Offline App "Debt-Splitter"

---

## 🛠️ Phase 1: Arsitektur & Setup Basis Data

### 1. Guideline Arsitektur & Tech Stack
- [x] **Konfigurasi Prinsip Offline-First**
  - [x] Memastikan aplikasi berjalan 100% lokal tanpa backend server atau login auth
- [x] **Konfigurasi Tipe Data Presisi Keuangan**
  - [x] Memastikan seluruh nominal uang dihitung dan disimpan sebagai `Integer` (satuan Rupiah/Sen terendah)
- [x] **Inisialisasi Tech Stack**
  - [x] Setup Framework pilihan (Flutter)
  - [x] Setup Local Storage DB Engine (SQLite via `sqflite`)
  - [x] Setup P2P Sync Library (zlib/gzip compression & QR Code Generator/Scanner)

### 2. Implementasi Skema Data Lokal (Database Schema)
- [x] **Entitas / Tabel `User`**
  - [x] Field `id`: STRING (UUID, Primary Key)
  - [x] Field `name`: STRING
  - [x] Field `avatar_color`: STRING
  - [x] Field `created_at`: INTEGER (Timestamp)
- [x] **Entitas / Tabel `Group`**
  - [x] Field `id`: STRING (UUID, Primary Key)
  - [x] Field `name`: STRING
  - [x] Field `default_currency`: STRING
  - [x] Field `created_at`: INTEGER (Timestamp)
- [x] **Entitas / Tabel `GroupMember` (Junction Table)**
  - [x] Foreign Key `group_id` -> `Group.id`
  - [x] Foreign Key `user_id` -> `User.id`
  - [x] Primary Key Komposit: (`group_id`, `user_id`)
- [x] **Entitas / Tabel `Expense`**
  - [x] Field `id`: STRING (UUID, Primary Key)
  - [x] Foreign Key `group_id` -> `Group.id`
  - [x] Foreign Key `paid_by` -> `User.id`
  - [x] Field `amount`: INTEGER (Nominal utuh)
  - [x] Field `split_type`: STRING ('EQUAL', 'EXACT', 'PERCENT')
  - [x] Field `date`: INTEGER (Timestamp)
  - [x] Field `note`: STRING
- [x] **Entitas / Tabel `ExpenseShare`**
  - [x] Field `id`: STRING (UUID, Primary Key)
  - [x] Foreign Key `expense_id` -> `Expense.id`
  - [x] Foreign Key `user_id` -> `User.id`
  - [x] Field `share_amount`: INTEGER

---

## 🗓️ Phase 2: Rencana Kerja Mingguan (Weekly Action Plan)

### 📌 Minggu 1: Setup Proyek, Data Layer & CRUD Core

- [x] **1. Project Setup**
  - [x] Setup repository Git & branch protection
  - [x] Setup linter & formatting standards
  - [x] Setup struktur folder arsitektur (*Feature-First / Clean Architecture*)
- [x] **2. Database Setup**
  - [x] Setup DB lokal (Room/SQLite/Isar/Hive) sesuai skema
  - [x] Setup skema migration strategy dasar
- [x] **3. Repository Layer & DAO**
  - [x] Implementasi DAO & Repository entitas `Group`
  - [x] Implementasi DAO & Repository entitas `User`
  - [x] Implementasi Operasi CRUD transaksi `Expense`
  - [x] Implementasi Operasi CRUD transaksi `ExpenseShare`
- [x] **4. Data Validation & Helpers**
  - [x] Buat input validator (konversi otomatis string input ke `Integer`)
  - [x] Buat fungsi helper kalkulasi *Equal Split* (penanganan sisa pembulatan sen/rupiah, contoh: Rp100.000 / 3)
- [x] **5. Deliverables Minggu 1**
  - [x] Source code repository terstruktur
  - [x] Local DB Layer selesai & Unit Test CRUD lulus

---

### 📌 Minggu 2: Engine Net Balance & Algoritma Penyederhanaan Utang (Greedy)

- [x] **1. Kalkulasi Net Balance**
  - [x] Buat modul kalkulasi balance per user dalam grup: `net_balance[user] = total_paid - total_share`
- [x] **2. Implementasi Greedy Settlement Engine ($O(n \log n)$)**
  - [x] Implementasi pemisahan kelompok **Kreditur** (`balance > 0`) dan **Debitur** (`balance < 0`)
  - [x] Setup **Max-Heap Kreditur** (berdasarkan nominal piutang)
  - [x] Setup **Max-Heap Debitur** (berdasarkan nilai mutlak `|balance|` utang)
  - [x] Implementasi Loop Algoritma Greedy:
    - [x] Ambil Kreditur terbesar (`max_creditor`) dan Debitur terbesar (`max_debtor`)
    - [x] Hitung `settle_amount = min(max_creditor.balance, max_debtor.abs_balance)`
    - [x] Buat objek transaksi rekomendasi pelunasan: `max_debtor -> max_creditor: settle_amount`
    - [x] Update saldo kedua pihak (jika sisa $> 0$, masukkan kembali ke heap)
    - [x] Ulangi loop hingga seluruh saldo net bernilai 0
- [x] **3. Unit Testing Core Logic (Wajib 100% Coverage)**
  - [x] Unit Test Kasus 1: Transaksi melingkar 3+ orang ($A \rightarrow B \rightarrow C \rightarrow A$)
  - [x] Unit Test Kasus 2: Penanganan sisa ganjil pembulatan *equal split*
  - [x] Unit Test Kasus 3: Kasus 1 orang membayar seluruh transaksi grup
- [x] **4. Deliverables Minggu 2**
  - [x] Modul `DebtSimplifierEngine` terisolasi dan *pure function* (bebas side-effect)
  - [x] Suite unit test untuk *edge cases* kalkulasi keuangan lulus 100%

---

### 📌 Minggu 3: UI/UX Implementation & Integrasi WhatsApp Share

- [x] **1. Tampilan Utama & Grup**
  - [x] UI Dashboard (Daftar Grup & Ringkasan Total Saldo)
  - [x] UI Detail Grup (Riwayat transaksi & Daftar anggota)
- [x] **2. Form Entry Transaksi Cepat (Quick-Entry Sheet)**
  - [x] UI Modal Input Pengeluaran
  - [x] Auto-formatting currency pada input nominal
  - [x] Selector Pembayar (*Paid By*)
  - [x] Selector Opsi Split (Sama Rata / Custom Nominal)
- [x] **3. Layar "Settle Up"**
  - [x] Visual Card instruksi pembayaran (contoh: *"Budi transfer Rp33.333 ke Andi"*) berdasarkan output Greedy Engine
- [x] **4. WhatsApp Summary Generator**
  - [x] Buat parser format teks otomatis (Markdown format untuk WhatsApp)
  - [x] Integrasikan dengan Native OS Share Sheet (Deep Link ke WhatsApp / Apps chat)
- [x] **5. Deliverables Minggu 3**
  - [x] Fitur MVP UI lengkap dari input transaksi -> visualisasi pelunasan -> WhatsApp share

---

### 📌 Minggu 4: Advanced Offline Features (QR Sync / Export) & Polish

- [x] **1. QR Code Offline Peer-to-Peer Sync**
  - [x] Buat fungsi serialisasi data grup & transaksi ke format JSON ringkas
  - [x] Implementasi kompresi payload JSON via `zlib`/`gzip` & konversi ke String Base64
  - [x] Implementasi UI Generator QR Code
  - [x] Implementasi UI Scanner QR Code untuk import/sinkronisasi data secara *offline*
- [x] **2. Backup & Export/Import**
  - [x] Fitur Export DB / Data Grup ke file JSON lokal
  - [x] Fitur Import data dari file JSON lokal
  - [x] Fitur Cetak PDF *summary report*
- [x] **3. Testing di Real Device & Quality Assurance**
  - [x] Audit penggunaan memori & pengujian performa UI pada perangkat berspesifikasi rendah
  - [x] Verifikasi ulang penanganan *edge-cases* dan UI *responsiveness*
- [x] **4. Deliverables Minggu 4**
  - [x] Build APK / IPA *Release Candidate* (RC)
  - [x] Dokumentasi penggunaan & alur eksekusi aplikasi

---

## ✅ Phase 3: Final Quality Control & Developer Checklist

- [ ] **Tipe Data Keuangan**: Tidak ada penggunaan variabel `double` / `float` pada kalkulasi uang; seluruhnya menggunakan `int` / `BigInt`[cite: 1].
- [ ] **Mode Offline**: Aplikasi dapat digunakan 100% pada mode *Airplane Mode* (tanpa koneksi internet)[cite: 1].
- [ ] **Zero Network Dependencies**: Tidak ada panggilan API eksternal pada fitur *core*[cite: 1].
- [ ] **Coverage Test**: Semua *unit test* untuk modul *Debt Simplification Algorithm Engine* lulus 100%[cite: 1].
