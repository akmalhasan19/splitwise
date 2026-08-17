Informasi Ide Penambahan Fitur 'Skema V2 + UI Mode "Struk"'


Pertama, mari kita pertegas kenapa cara sekarang masih "manual"
Mode pembagian yang ada sekarang: EQUAL (rata rata) dan EXACT (nominal per orang, di quick_entry_sheet.dart). Keduanya punya masalah untuk kasus rumah makan:
- EQUAL → salah, karena tiap orang berbeda jumlah.
- EXACT → benar hasilnya, tapi tetap mengharuskan yang mencatat sudah tahu dulu "bagian si A berapa, si B berapa". Artinya beban menghitung dari struk tetap dipikul otak/mental orangnya — persis kerjaan yang kamu ilustrasikan. Aplikasi cuma jadi "kalkulator yang terpisah", itu sebabnya terasa tidak ada nilainya.
Masalah sebenarnya bukan "jumlah orang", tapi pemetaan menu → orang, lalu penjumlahan per orang.
Solusi inti: model "Item / Struk" (split berbasis pos menu)
Ubah sudut pandang dari "tentukan nominal per orang" menjadi *"catat menu apa saja, lalu setiap orang mencentang menu yang dia pesan". Aplikasi yang menghitung per orang. Ini pola yang dipakai aplikasi seperti Tricount / Splitwise.
Alur di HP (menggantikan cara manual kamu)
1. Pencatat mengetik item dari struk sekali (nama + harga + jumlah), misal:
Nasi Goreng 25.000, Sate 30.000, Es Teh 8.000×2, dst.
2. Per item, di-centang siapa yang makan item itu (boleh lebih dari satu → dibagi rata antar yang mencentang).
3. Aplikasi otomatis menghitung bagian tiap orang = jumlah semua item yang dia centang.
Selesai. Tidak ada lagi "tiap orang ingat pesan, lihat struk, jumlahin pakai kalkulator". Beban berubah dari hitung menjadi centang — dan konservasi total dijamin otomatis.
Contoh konkret (bill Rp 154.000)
Item
Nasi Goreng
Sate
Es Teh
Es Teh
Ayam Geprek
Mie Ayam
Nasi Putih
Es Jeruk
Hasil otomatis: A = Rp 48.000, B = Rp 48.000, C = Rp 58.000 (jumlah = 154.000 ✓). Satu orang bayar awal → saldo net si pembayar = 154.000 − bagiannya, dsb. Engine NetBalanceCalculator yang sudah ada tak perlu diubah (lihat bagian bawah).
Desain yang saya rekomendasikan (menempel pada arsitektur existing)
1) Perubahan skema (migrasi dbSchemaVersion 1 → 2)
- expenses.split_type tambah nilai 'ITEM'.
- Tabel baru expense_items: id, expense_id (FK→expenses.id), name, price, quantity.
- Tabel baru item_claims: expense_item_id (FK→expense_items.id), user_id (FK→users.id). Satu baris = "orang ini makan item ini". Jika suatu item punya 2+ claimant → otomatis dibagi rata di antara mereka.
⚠️ Detail penting migrasi: nilai split_type saat ini dibatasi CHECK (split_type IN ('EQUAL','EXACT','PERCENT')) di createSchemaV1Scripts. SQLite tidak bisa ALTER constraint CHECK → migrasi v2 harus recreate tabel expenses (buat tabel baru + copy data + drop lama). Sudah ada pola migrasi di AppDatabase._upgradeSchema, tinggal disambung.
2) Algoritma alokasi — ItemBillSplitter (pure function, konsisten filosofi proyek)
Untuk tiap item: perOrang = price ~/ jumlahClaimant;  sisa = price % jumlahClaimant
  → sisa didistribusikan ke sebagian claimant (pakai logika konservasi yg SAMA
    dengan SplitCalculator.equalSplit / di repo kamu).
Lalu share tiap user = sum(item yang dia centang) → ExpenseShare.
Karena tiap item dibagi penuh ke claimant-nya, sum(share) == sum(harga item × qty) == expense.amount dijamin — dan validasi yang sudah ada di ExpenseRepository._validateInputs (sumShares == amount, semua penerima anggota grup) tetap berlaku tanpa diubah. Anda tinggal pakai expense_shares sebagai single source of truth balance.
3) Lapisan "penyimpan data menu" (opsional, makin menekan ketikan)
Buat tabel kecil menu_dictionary(name, last_price, updated_at) lokal (per grup atau global). Saat kamu mengetik "Nasi Goreng" dan sudah pernah dicatat, harga terakhir auto-terisi. Offline-first tetap, hanya SQLite lokal.
4) Perluasan payload sync (QR/JSON)
Bump GroupSyncPayload.currentSchemaVersion ke 2, tambah array it (items) + cl (claims) per expense. Penerima versi lama sudah di-guard menolak v > 1. Saat import, best practice: jangan simpan expense_shares dari remote, tapi re-derive dari item+claims via ItemBillSplitter — sehingga konservasi selalu konsisten dan satu sumber kebenaran.
Yang TIDAK perlu diubah (nilai tambah arsitektur ini)
Karena expense_shares tetap satu-satunya input engine:
- NetBalanceCalculator, DebtSimplifierEngine (greedy), tampilan hijau/merah di _MemberChip → tanpa perubahan.
- QR sync, export/import JSON, PDF, WhatsApp share → hanya perlu serialisasi item/claims (poin 4), logika inti utuh.
Ini kuncinya: item & claims adalah generator upstream; balance & settlement tetap berjalan di atas expense_shares. Lapisan baru tidak merusak lapisan yang sudah dirilis.
Bonus (opsional, fase lanjutan)
- OCR on-device untuk memindai struk (mis. google_mlkit_text_recognition, jalan offline) → langsung mengisi daftar item, tinggal centang siapa makan apa. Kompromi: nambah ukuran APK & dependency; cocok sebagai enhancement setelah fitur inti landas.
- "Saran sama-rata per item" default centang "semua orang" untuk item yang terasa patungan — mempercepat input.
Alur keputusan singkat
Opsi
Item split + claims (rekomendasi)
Minimal (item 1 pemilik)
Saya sarankan opsi claims — selisihnya kecil dan justru paling mirip perilaku nyata di rumah makan (orang sering berbagi lauk).


File baru:
- C:\Users\user\splitwise\lib\core\money\item_bill_splitter.dart — ItemBillSplitter + model ItemBillLine (pure function).
- C:\Users\user\splitwise\test\core\money\item_bill_splitter_test.dart — 16 unit test.
Validasi:
 	Hasil
flutter test test/core/money/item_bill_splitter_test.dart	✅ 16 lulus
dart analyze (2 file)	✅ No issues found!
Apa yang dimodelkan
class ItemBillLine {
  final String id;                 // identitas unik baris
  final MoneyAmount unitPrice;     // harga per unit (integer, tanpa double)
  final int quantity;              // jumlah unit (>= 1)
  final List<String> claimantIds;  // siapa yang makan item ini (boleh 1+)
}
Kontrak algoritma (allocate):
- Nominal tiap baris unitPrice × quantity dibagi sama rata ke claimant-nya.
- Sisa pembulatan per baris didistribusikan → konservasi uang sum(share) == totalOf(lines) dijamin (reuse teknik yang sama dengan SplitCalculator).
- Claimant di-sort lexicographic → hasil deterministik (tidak bergantung urutan centang UI).
- totalOf(...) = total bill, dan validasi input korup (claimant kosong/duplikat, quantity 0, harga negatif) melempar ArgumentError.
Test yang dicakup: item solo, item dibagi 2/3 (dengan sisa pembulatan), bill multi-item quantity, contoh rumah makan Rp 154.000 (A=48.000, B=48.000, C=58.000), brute-force konservasi (0–200 rupiah × qty 1–4 × 1–5 orang), determinisme, akumulasi multi-baris, dan input tidak valid.
Catatan desain (penting untuk lanjutan)
ItemBillSplitter murni pure function dan tidak bergantung pada DB/models — hanya memakai SplitCalculator + MoneyAmount. Ini membuatnya mudah di-unit test, dan jadi jembatan bersih menuju schema v2: expense_shares akan di-generate dari expense_items + item_claims lewat ItemBillSplitter.allocate, sehingga engine balance/greedy/QR/PDF/WhatsApp tetap tak berubah (semua tetap membaca expense_shares).
Langkah berikut yang kamu sebutkan: skema v2 (expenses + nilai 'ITEM', tabel expense_items & item_claims, bump dbSchemaVersion 1→2, migrate CHECK constraint via recreate) lalu UI mode "Struk".