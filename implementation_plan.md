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

- [ ] **1. Project Setup**
  - [ ] Setup repository Git & branch protection
  - [ ] Setup linter & formatting standards
  - [ ] Setup struktur folder arsitektur (*Feature-First / Clean Architecture*)
- [ ] **2. Database Setup**
  - [ ] Setup DB lokal (Room/SQLite/Isar/Hive) sesuai skema
  - [ ] Setup skema migration strategy dasar
- [ ] **3. Repository Layer & DAO**
  - [ ] Implementasi DAO & Repository entitas `Group`
  - [ ] Implementasi DAO & Repository entitas `User`
  - [ ] Implementasi Operasi CRUD transaksi `Expense`
  - [ ] Implementasi Operasi CRUD transaksi `ExpenseShare`
- [ ] **4. Data Validation & Helpers**
  - [ ] Buat input validator (konversi otomatis string input ke `Integer`)
  - [ ] Buat fungsi helper kalkulasi *Equal Split* (penanganan sisa pembulatan sen/rupiah, contoh: Rp100.000 / 3)
- [ ] **5. Deliverables Minggu 1**
  - [ ] Source code repository terstruktur
  - [ ] Local DB Layer selesai & Unit Test CRUD lulus

---

### 📌 Minggu 2: Engine Net Balance & Algoritma Penyederhanaan Utang (Greedy)

- [ ] **1. Kalkulasi Net Balance**
  - [ ] Buat modul kalkulasi balance per user dalam grup: `net_balance[user] = total_paid - total_share`
- [ ] **2. Implementasi Greedy Settlement Engine ($O(n \log n)$)**
  - [ ] Implementasi pemisahan kelompok **Kreditur** (`balance > 0`) dan **Debitur** (`balance < 0`)
  - [ ] Setup **Max-Heap Kreditur** (berdasarkan nominal piutang)
  - [ ] Setup **Max-Heap Debitur** (berdasarkan nilai mutlak `|balance|` utang)
  - [ ] Implementasi Loop Algoritma Greedy:
    - [ ] Ambil Kreditur terbesar (`max_creditor`) dan Debitur terbesar (`max_debtor`)
    - [ ] Hitung `settle_amount = min(max_creditor.balance, max_debtor.abs_balance)`
    - [ ] Buat objek transaksi rekomendasi pelunasan: `max_debtor -> max_creditor: settle_amount`
    - [ ] Update saldo kedua pihak (jika sisa $> 0$, masukkan kembali ke heap)
    - [ ] Ulangi loop hingga seluruh saldo net bernilai 0
- [ ] **3. Unit Testing Core Logic (Wajib 100% Coverage)**
  - [ ] Unit Test Kasus 1: Transaksi melingkar 3+ orang ($A \rightarrow B \rightarrow C \rightarrow A$)
  - [ ] Unit Test Kasus 2: Penanganan sisa ganjil pembulatan *equal split*
  - [ ] Unit Test Kasus 3: Kasus 1 orang membayarkan seluruh transaksi grup
- [ ] **4. Deliverables Minggu 2**
  - [ ] Modul `DebtSimplifierEngine` terisolasi dan *pure function* (bebas side-effect)
  - [ ] Suite unit test untuk *edge cases* kalkulasi keuangan lulus 100%

---

### 📌 Minggu 3: UI/UX Implementation & Integrasi WhatsApp Share

- [ ] **1. Tampilan Utama & Grup**
  - [ ] UI Dashboard (Daftar Grup & Ringkasan Total Saldo)
  - [ ] UI Detail Grup (Riwayat transaksi & Daftar anggota)
- [ ] **2. Form Entry Transaksi Cepat (Quick-Entry Sheet)**
  - [ ] UI Modal Input Pengeluaran
  - [ ] Auto-formatting currency pada input nominal
  - [ ] Selector Pembayar (*Paid By*)
  - [ ] Selector Opsi Split (Sama Rata / Custom Nominal)
- [ ] **3. Layar "Settle Up"**
  - [ ] Visual Card instruksi pembayaran (contoh: *"Budi transfer Rp33.333 ke Andi"*) berdasarkan output Greedy Engine
- [ ] **4. WhatsApp Summary Generator**
  - [ ] Buat parser format teks otomatis (Markdown format untuk WhatsApp)
  - [ ] Integrasikan dengan Native OS Share Sheet (Deep Link ke WhatsApp / Apps chat)
- [ ] **5. Deliverables Minggu 3**
  - [ ] Fitur MVP UI lengkap dari input transaksi -> visualisasi pelunasan -> WhatsApp share

---

### 📌 Minggu 4: Advanced Offline Features (QR Sync / Export) & Polish

- [ ] **1. QR Code Offline Peer-to-Peer Sync**
  - [ ] Buat fungsi serialisasi data grup & transaksi ke format JSON ringkas
  - [ ] Implementasi kompresi payload JSON via `zlib`/`gzip` & konversi ke String Base64
  - [ ] Implementasi UI Generator QR Code
  - [ ] Implementasi UI Scanner QR Code untuk import/sinkronisasi data secara *offline*
- [ ] **2. Backup & Export/Import**
  - [ ] Fitur Export DB / Data Grup ke file JSON lokal
  - [ ] Fitur Import data dari file JSON lokal
  - [ ] Fitur Cetak PDF *summary report*
- [ ] **3. Testing di Real Device & Quality Assurance**
  - [ ] Audit penggunaan memori & pengujian performa UI pada perangkat berspesifikasi rendah
  - [ ] Verifikasi ulang penanganan *edge-cases* dan UI *responsiveness*
- [ ] **4. Deliverables Minggu 4**
  - [ ] Build APK / IPA *Release Candidate* (RC)
  - [ ] Dokumentasi penggunaan & alur eksekusi aplikasi

---

## ✅ Phase 3: Final Quality Control & Developer Checklist

- [ ] **Tipe Data Keuangan**: Tidak ada penggunaan variabel `double` / `float` pada kalkulasi uang; seluruhnya menggunakan `int` / `BigInt`[cite: 1].
- [ ] **Mode Offline**: Aplikasi dapat digunakan 100% pada mode *Airplane Mode* (tanpa koneksi internet)[cite: 1].
- [ ] **Zero Network Dependencies**: Tidak ada panggilan API eksternal pada fitur *core*[cite: 1].
- [ ] **Coverage Test**: Semua *unit test* untuk modul *Debt Simplification Algorithm Engine* lulus 100%[cite: 1].
