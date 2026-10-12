# Jawaban Coding Akuntansi

Folder ini memuat kode jawaban untuk soal UTS Pengkodean dan Pemrograman.

## Daftar berkas

1. **soal1_general_ledger.sql** — skema general ledger, tabel akun/header/detail, dan validasi keseimbangan jurnal berstatus POSTED.
2. **soal2_trigger_persediaan.sql** — tabel transaksi persediaan serta trigger untuk memperbarui stok dan mencegah stok negatif.
3. **soal2_concurrency_node.js** — contoh proses penjualan Node.js menggunakan transaksi database dan `SELECT ... FOR UPDATE`. Membutuhkan paket `pg` dan environment variable `DATABASE_URL`.
4. **rancangan-formulir-entri-jurnal-dinamis.html** — demo frontend formulir jurnal dinamis dengan total debit/kredit dan validasi keseimbangan. Demo ini belum menyimpan data ke database.
5. **soal3_supabase_audit_trail.sql** — skema Supabase/PostgreSQL untuk voucher, detail, audit log, checksum SHA-256, dan perlindungan voucher POSTED.

## Catatan penggunaan

- Jalankan SQL sesuai urutan soal dan pada database uji terlebih dahulu.
- `soal3_supabase_audit_trail.sql` menggunakan `auth.uid()`, sehingga ditujukan untuk Supabase. Konfigurasikan RLS dan hak akses sebelum penggunaan nyata.
- Trigger persediaan mengelola mutasi stok, tetapi tidak membuat jurnal GL otomatis karena skema dan pemetaan akun tidak ditentukan dalam soal.
- File HTML adalah purwarupa antarmuka browser, bukan aplikasi yang sudah tersambung ke backend.
