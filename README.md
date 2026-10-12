# UTS Pengkodean dan Pemrograman

## Soal 1 - General Ledger
- `general_ledger.sql`: skema general ledger dan validasi keseimbangan jurnal berstatus POSTED.

## Soal 2 - Persediaan dan Concurrency
- `trigger_persediaan.sql`: trigger transaksi persediaan untuk memperbarui stok dan mencegah stok negatif.
- `concurrency_node.js`: contoh proses penjualan Node.js menggunakan transaksi database dan `SELECT ... FOR UPDATE`. Membutuhkan paket `pg` dan environment variable `DATABASE_URL`.

## Soal 3 - Formulir Jurnal dan Audit Trail
- `rancangan-formulir-entri-jurnal-dinamis.html`: purwarupa formulir jurnal dinamis dengan total debit/kredit dan validasi keseimbangan. Belum terhubung ke database.
- `supabase_audit_trail.sql`: skema Supabase/PostgreSQL untuk voucher, detail, audit log, checksum SHA-256, dan perlindungan voucher POSTED.

## Catatan
- Jalankan SQL di database uji terlebih dahulu.
- File audit trail menggunakan `auth.uid()` dan ditujukan untuk Supabase.
- Trigger persediaan tidak membuat jurnal GL otomatis karena skema dan pemetaan akun tidak ditentukan dalam soal.
- File HTML merupakan purwarupa antarmuka, bukan aplikasi yang sudah tersambung ke backend.
