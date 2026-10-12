-- SOAL 3.2 — Supabase/PostgreSQL audit trail dan immutability
-- Jalankan setelah membuat extension pgcrypto. Ini contoh skema backend minimal.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS cash_vouchers (
    voucher_id BIGSERIAL PRIMARY KEY,
    voucher_no TEXT NOT NULL UNIQUE,
    transaction_date DATE NOT NULL,
    payee TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT'
      CHECK (status IN ('DRAFT','APPROVED','POSTED')),
    created_by UUID NOT NULL DEFAULT auth.uid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    posted_by UUID,
    posted_at TIMESTAMPTZ,
    hash_checksum TEXT,
    reversal_of BIGINT REFERENCES cash_vouchers(voucher_id) ON DELETE RESTRICT,
    CHECK (reversal_of IS NULL OR reversal_of <> voucher_id)
);

CREATE TABLE IF NOT EXISTS cash_voucher_lines (
    line_id BIGSERIAL PRIMARY KEY,
    voucher_id BIGINT NOT NULL REFERENCES cash_vouchers(voucher_id) ON DELETE RESTRICT,
    account_code TEXT NOT NULL,
    account_name TEXT NOT NULL,
    line_description TEXT,
    debit NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
);

CREATE TABLE IF NOT EXISTS audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    voucher_id BIGINT,
    action TEXT NOT NULL,
    actor UUID DEFAULT auth.uid(),
    action_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    details JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE OR REPLACE FUNCTION protect_posted_voucher()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.status = 'POSTED' THEN
            RAISE EXCEPTION 'Voucher POSTED tidak boleh dihapus; buat jurnal pembalik.';
        END IF;
        INSERT INTO audit_logs(voucher_id, action, details)
        VALUES (OLD.voucher_id, 'DELETE_DRAFT',
                jsonb_build_object('voucher_no', OLD.voucher_no));
        RETURN OLD;
    END IF;

    IF OLD.status = 'POSTED' THEN
        RAISE EXCEPTION 'Voucher POSTED tidak boleh diubah; buat jurnal pembalik.';
    END IF;

    IF NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'created_by dan created_at tidak boleh diubah.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_posted_voucher ON cash_vouchers;
CREATE TRIGGER trg_protect_posted_voucher
BEFORE UPDATE OR DELETE ON cash_vouchers
FOR EACH ROW EXECUTE FUNCTION protect_posted_voucher();

CREATE OR REPLACE FUNCTION protect_posted_voucher_lines()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_id BIGINT;
    v_status TEXT;
BEGIN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.voucher_id ELSE NEW.voucher_id END;
    SELECT status INTO v_status FROM cash_vouchers WHERE voucher_id = v_id;
    IF v_status = 'POSTED' THEN
        RAISE EXCEPTION 'Detail voucher POSTED tidak boleh diubah/dihapus.';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_posted_lines ON cash_voucher_lines;
CREATE TRIGGER trg_protect_posted_lines
BEFORE INSERT OR UPDATE OR DELETE ON cash_voucher_lines
FOR EACH ROW EXECUTE FUNCTION protect_posted_voucher_lines();

CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Audit log bersifat append-only.';
END;
$$;
DROP TRIGGER IF EXISTS trg_audit_log_immutable ON audit_logs;
CREATE TRIGGER trg_audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();

CREATE OR REPLACE FUNCTION validate_and_stamp_posted_voucher()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_count BIGINT;
    v_debit NUMERIC(15,2);
    v_credit NUMERIC(15,2);
    v_payload TEXT;
BEGIN
    IF NEW.status = 'POSTED' AND OLD.status IS DISTINCT FROM 'POSTED' THEN
        SELECT COUNT(*), COALESCE(SUM(debit),0), COALESCE(SUM(credit),0)
          INTO v_count, v_debit, v_credit
          FROM cash_voucher_lines WHERE voucher_id = NEW.voucher_id;

        IF v_count < 2 OR v_debit <= 0 OR v_debit <> v_credit THEN
            RAISE EXCEPTION 'Voucher harus memiliki minimal dua baris dan total debit = kredit.';
        END IF;

        NEW.posted_by := auth.uid();
        NEW.posted_at := now();

        SELECT jsonb_build_object(
          'voucher_id', NEW.voucher_id,
          'voucher_no', NEW.voucher_no,
          'transaction_date', NEW.transaction_date,
          'payee', NEW.payee,
          'description', NEW.description,
          'lines', COALESCE(jsonb_agg(jsonb_build_object(
             'account_code', l.account_code,
             'account_name', l.account_name,
             'line_description', l.line_description,
             'debit', l.debit,
             'credit', l.credit
          ) ORDER BY l.line_id), '[]'::jsonb)
        )::text
        INTO v_payload
        FROM cash_voucher_lines l
        WHERE l.voucher_id = NEW.voucher_id;

        NEW.hash_checksum := encode(digest(v_payload, 'sha256'), 'hex');
        INSERT INTO audit_logs(voucher_id, action, details)
        VALUES (NEW.voucher_id, 'POST_VOUCHER',
          jsonb_build_object('debit_total', v_debit, 'credit_total', v_credit,
                             'hash_checksum', NEW.hash_checksum));
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_stamp_posted ON cash_vouchers;
CREATE TRIGGER trg_validate_stamp_posted
BEFORE UPDATE OF status ON cash_vouchers
FOR EACH ROW EXECUTE FUNCTION validate_and_stamp_posted_voucher();

CREATE OR REPLACE FUNCTION log_voucher_creation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO audit_logs(voucher_id, action, details)
  VALUES (NEW.voucher_id, 'CREATE_VOUCHER',
          jsonb_build_object('voucher_no', NEW.voucher_no, 'status', NEW.status));
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_log_voucher_creation ON cash_vouchers;
CREATE TRIGGER trg_log_voucher_creation
AFTER INSERT ON cash_vouchers
FOR EACH ROW EXECUTE FUNCTION log_voucher_creation();

-- Penting:
-- 1) RLS/GRANT harus dikonfigurasi agar pengguna aplikasi tidak dapat memanipulasi
--    audit_logs atau melewati alur otorisasi. Jangan pernah mengekspos service_role key.
-- 2) auth.uid() tersedia di Supabase. Pada PostgreSQL biasa, ganti dengan mekanisme user ID.
-- 3) hash_checksum adalah checksum data saat posting; verifikasi ulang perlu menghitung ulang
--    payload yang sama dan membandingkan hasilnya.
-- 4) Jurnal pembalik dibuat sebagai voucher BARU dengan reversal_of = voucher_id asli,
--    dan setiap nilai debit/kredit pada baris pembalik ditukar. Voucher asli tetap utuh.