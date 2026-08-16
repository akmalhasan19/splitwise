# Git Workflow & Branch Protection — Debt-Splitter

> Dokumen keluaran **Phase 2 · Minggu 1 · Task 1** (Project Setup) dari
> `implementation_plan.md`. Sejalan dengan prinsip repo *offline-first*:
> riwayat & proteksi tetap dikelola Git lokal, siap dipush ke remote
> (GitHub/GitLab) kapan pun.

---

## 1. Aturan Dasar

- **Default branch**: `main` (bukan `master`).
- Seluruh perubahan kata kerja masuk via **Pull/Merge Request** — tidak ada
  commit langsung ke `main` oleh contributor non-maintainer.
- Penamaan branch:
  - `feat/<deskripsi>` — fitur baru
  - `fix/<deskripsi>` — perbaikan bug
  - `docs/<deskripsi>` — dokumentasi
  - `refactor/<deskripsi>` — perombakan kode tanpa ubah perilaku
  - `test/<deskripsi>` — penambahan/perbaikan test
- Commit message ringkas & deskriptif (gaya Imperative, mis. `feat(expenses):
  tambah equal split expense`, `test(engine): edge case sisa 1 rupiah`).

## Branch Protection (konfigurasi di remote)

Proteksi branch seperti GitHub *Protected Branches* / GitLab *Protected
Branches* memerlukan remote (hosting git). Sampai remote tersedia, aturan
berikut dijalankan **manual** oleh setiap contributor; saat repo dipush ke
remote, aktifkan di *Settings → Branches*:

1. **`main` diproteksi** — *require pull request before merging*
   (blokir push langsung). Maintainer tanpa proteksi memakai branch feat/fix.
2. **Minimal 1 approval** review sebelum merge.
3. **Required status checks lulus**:
   - `flutter analyze` — tanpa issue;
   - `flutter test` — seluruh unit test lulus;
   - `dart format lib test --set-exit-if-changed` — kode sudah ter-format.
4. **Linear history** — preferensi *rebase & merge* (hindari merge commit)
   demi riwayat bersih; selalu `git pull --rebase` sebelum push.
5. **Jangan commit artefak**: folder `build/`, `.dart_tool/`, `.idea/`
   sudah di-ignore (` .gitignore`); log/sampah lokal tidak dikomit.

## Prosedur kontribusi ini

```bash
git checkout -b feat/tambah-fitur-x
# ... edit kode ...
dart format lib test   # format
flutter analyze        # wajib bersih
flutter test           # wajib lulus
git add -A
git commit -m "feat: tambah x"
git push origin feat/tambah-fitur-x   # bila remote tersedia
```

Lalu buat Pull/Merge Request ke `main` dengan 1+ approval & status checks.

## Status saat ini

- Inisialisasi repo lokal: `git init -b main` (dilakukan task ini).
- Belum ada remote (`git remote -v` kosong) — proteksi server-side akan
  diaktifkan saat remote dibuat, mengikuti daftar di atas.