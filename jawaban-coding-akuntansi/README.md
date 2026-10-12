# Jawaban Coding Akuntansi

Folder ini memuat kode jawaban UTS Pengkodean dan Pemrograman, dikelompokkan berdasarkan nomor soal.

## Struktur folder

### 1. [Soal 1 - General Ledger](./soal-1-general-ledger/)
- `soal1_general_ledger.sql`: skema general ledger, tabel akun/header/detail, dan validasi keseimbangan jurnal berstatus POSTED.

### 2. [Soal 2 - Persediaan dan Concurrency](./soal-2-persediaan-dan-concurrency/)
- `soal2_trigger_persediaan.sql`: tabel transaksi persediaan dan trigger untuk memperbarui stok serta mencegah stok negatif.
- `soal2_concurrency_node.js`: contoh proses penjualan Node.js menggunakan transaksi database dan `SELECT ... FOR UPDATE`. Membutuhkan paket `pg` dan environment variable `DATABASE_URL`.

### 3. [Soal 3 - Formulir Jurnal dan Audit Trail](./soal-3-formulir-jurnal-dan-audit-trail/)
- `rancangan-formulir-entri-jurnal-dinamis.html`: purwarupa frontend formulir jurnal dinamis dengan total debit/kredit dan validasi keseimbangan. Belum terhubung ke database.
- `soal3_supabase_audit_trail.sql`: skema Supabase/PostgreSQL untuk voucher, detail, audit log, checksum SHA-256, dan perlindungan voucher POSTED.

## Catatan penggunaan

- Jalankan SQL sesuai urutan soal dan pada database uji terlebih dahulu.
- File `soal3_supabase_audit_trail.sql` menggunakan `auth.uid()`, sehingga ditujukan untuk Supabase. Konfigurasikan RLS dan hak akses sebelum penggunaan nyata.
- Trigger persediaan mengelola mutasi stok, tetapi tidak membuat jurnal GL otomatis karena skema dan pemetaan akun tidak ditentukan dalam soal.
- File HTML adalah purwarupa antarmuka browser, bukan aplikasi yang sudah tersambung ke backend.
