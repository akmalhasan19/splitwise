/// Presisi Keuangan — konfigurasi tipe data uang (Phase 1, Task 1).
///
/// Debt-Splitter **melarang** penggunaan `double`/`float` untuk nominal uang.
/// Seluruh uang direpresentasikan sebagai bilangan bulat (`int`) dalam satuan
/// Rupiah penuh — unit terkecil IDR = Rp1 ("integer money" / "minor units").
///
/// Aturan (lihat `docs/architecture.md` §Presisi Keuangan):
/// 1. Tipe field `amount` & `share_amount` di skema DB adalah `INTEGER`.
/// 2. Pembagian/split memakai operator integer `~/` (floor) dan `%` (sisa),
///    bukan `.round()` dari `double`.
/// 3. Jumlah seluruh `share_amount` harus selalu sama dengan `amount`
///    (konservasi total) — dijamin unit test.
///
/// Contoh: "Rp100.000" = `100000`, bukan `100000.0`.
typedef MoneyAmount = int;
