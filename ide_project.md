## 1. Mobile Offline App "Debt-Splitter" (Splitwise Offline-First)

**Problem inti:** Pas lagi traveling bareng, camping di tempat pelosok tanpa sinyal, atau nongkrong di kafe, ribet kalau harus login akun, butuh internet, atau install app berat cuma buat catat patungan. Siapa harus transfer ke siapa berapa — dengan transaksi seminimal mungkin dan **100% berjalan offline tanpa perlu internet/backend server**?

### Algoritma (Core Engine)
1. Hitung **net balance** tiap orang = total yang dia bayar − total yang jadi tanggungannya.
2. Pisah jadi dua kelompok: **kreditur** (balance positif, harus nerima) dan **debitur** (balance negatif, harus bayar).
3. Pakai pendekatan **greedy**: cocokkan kreditur dengan saldo terbesar ke debitur dengan saldo terbesar, settle sejumlah `min(|kreditur|, |debitur|)`, ulangi sampai semua balance nol.
   - Diimplementasi efisien pakai dua **heap/priority queue** (max-heap kreditur, min-heap debitur) → O(n log n).
   - *Insight Portfolio*: Trade-off antara solusi optimal mutlak (NP-Hard / Subset Sum) vs Greedy heuristic yang praktis, cepat di mobile device, dan dipakai oleh app industri.

### Data Model (Local SQLite / Room / Hive / SwiftData)
```
User (id, name, avatar_color)
Group (id, name, default_currency, created_at)
Expense (id, group_id, paid_by, amount, split_type, date, note)
ExpenseShare (expense_id, user_id, share_amount)
```

### Yang bikin seru & tantangan Mobile Offline
- **Offline-First & Zero Auth**: Tanpa backend, tanpa pusing token JWT/login — buka app langsung sat-set buat grup & catat.
- **Local Persistence**: Menggunakan embedded local DB (misal SQLite, Room, Hive, atau Isar) dengan query cepat dan aman dari data corruption.
- **Precision & Rounding**: Split Rp100.000 ke 3 orang = 33.333,33 — pakai integer (satuan rupiah/sen) agar tidak ada floating-point rounding bug di mobile.
- **Offline Sharing Mechanism**: Gimana cara oper data patungan ke temen tanpa internet? (Generate QR code payload terkompresi / teks ringkasan rapi buat di-paste ke WhatsApp).

### Fitur
- **MVP (100% Offline)**:
  - Buka langsung pakai (No sign-up / Instant start).
  - Kelola multiple grup (misal: "Trip Bromo", "Kosan Bareng", "Makan Malam").
  - Input expense fleksibel (split sama rata / custom nominal / persen).
  - Layar **"Settle Up"**: Visualisasi ringkas siapa bayar siapa via algoritma greedy.
  - **Quick Share to WhatsApp/Chat**: Format teks rapi rincian utang dan nomor rekening yang siap dikirim langsung via aplikasi chat.
- **Stretch (Advanced Mobile & P2P)**:
  - **QR Code Peer-to-Peer Sync**: Scan QR Code antar HP buat oper seluruh data trip/grup secara offline tanpa internet.
  - **On-Device OCR / Scan Struk**: Pakai on-device ML (MLKit / Tesseract) buat ekstrak total belanja dari struk offline.
  - **Export/Import & Backup**: Export database grup ke file JSON / PDF summary report.
  - **Multi-currency support**: Cache rate mata uang lokal buat konversi pas jalan-jalan ke luar negeri.

### Rencana kerja (~3–4 minggu)
1. Minggu 1: Setup framework mobile (Flutter / React Native / Kotlin / Swift) + Local DB schema & CRUD grup/expense.
2. Minggu 2: Core Balance & Debt Simplification Algorithm Engine + Comprehensive Unit Tests (edge cases & rounding).
3. Minggu 3: UI/UX Mobile (Quick-entry sheet, visualisasi Settle Up card, WhatsApp text summary generator).
4. Minggu 4: Fitur P2P offline (QR payload sync / Export-Import JSON) + UI polish & test di real device.

---

## 2. Auto Time-Blocking Scheduler

**Problem inti:** kamu punya to-do list + jadwal yang udah fix (meeting dll), app-nya otomatis "nyuntikin" tugas ke slot kosong di kalendermu.

### Algoritma
1. Ambil semua **busy block** (meeting/acara) hari itu → **merge overlapping intervals** dulu (klasik: "merge intervals" problem).
2. Hitung slot kosong = komplemen dari busy block dalam jam kerja (misal 08.00–18.00).
3. Urutkan task berdasarkan prioritas + deadline (bisa pakai skor gabungan urgency-importance, semacam versi simpel Eisenhower matrix, atau EDF — *earliest deadline first*, konsep klasik scheduling di OS).
4. **Greedy allocation**: taruh tiap task ke slot kosong paling awal yang cukup besar (first-fit), pecah slot sisanya jadi slot kosong baru.
5. Stretch: kalau task lebih panjang dari slot manapun, pecah jadi beberapa "focus block" (misal max 90 menit per block).

### Data model
```
Task (id, title, duration_min, priority, deadline)
CalendarEvent (id, start, end, source)
ScheduleBlock (task_id, start, end, locked)
```

### Yang bikin susah
- Overlapping busy block harus di-merge dulu sebelum cari slot kosong.
- Tie-breaking kalau prioritas sama → pakai deadline terdekat duluan.
- Task yang nggak muat semua di hari itu → harus ada logika "yang mana yang dilempar ke besok".
- Kalau nyambung Google Calendar API → timezone handling (lumayan bikin pusing tapi worth it).

### Fitur
- **MVP**: input task (durasi, prioritas, deadline opsional), input busy block manual, tombol "Generate My Day" → render sebagai timeline kalender.
- **Stretch**: drag-drop manual buat "lock" block biar nggak digeser pas regenerate, integrasi Google Calendar (OAuth + sync dua arah), konsep "energi" (kerjaan berat di pagi hari, admin task siang).

### Rencana kerja (~3–4 minggu)
1. Minggu 1: schema DB + CRUD task & busy block
2. Minggu 2: fungsi merge-interval + hitung slot kosong (+ unit test)
3. Minggu 3: algoritma greedy allocation + tampilan kalender basic
4. Minggu 4: drag-drop lock + polish, mulai eksplor Google Calendar API kalau sempat