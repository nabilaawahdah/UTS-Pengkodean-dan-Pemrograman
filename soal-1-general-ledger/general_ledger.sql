-- SOAL 1.2 — GENERAL LEDGER (PostgreSQL)
-- Header-line model, constraints, and deferred balance validation.
-- Jalankan pada database kosong. Constraint balance diperiksa saat COMMIT,
-- sehingga header dan detail dapat dimasukkan dalam satu transaksi.

CREATE TABLE chart_of_accounts (
    account_id SERIAL PRIMARY KEY,
    account_code VARCHAR(20) NOT NULL UNIQUE,
    account_name VARCHAR(100) NOT NULL,
    normal_balance VARCHAR(6) NOT NULL
        CHECK (normal_balance IN ('DEBIT', 'KREDIT')),
    report_classification VARCHAR(30) NOT NULL
        CHECK (report_classification IN
          ('ASET', 'LIABILITAS', 'EKUITAS', 'PENDAPATAN', 'BEBAN'))
);

CREATE TABLE journal_headers (
    header_id SERIAL PRIMARY KEY,
    transaction_date DATE NOT NULL,
    reference_number VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    posting_status VARCHAR(10) NOT NULL DEFAULT 'DRAFT'
        CHECK (posting_status IN ('DRAFT', 'POSTED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by TEXT NOT NULL DEFAULT CURRENT_USER
);

CREATE TABLE journal_lines (
    line_id SERIAL PRIMARY KEY,
    header_id INTEGER NOT NULL,
    account_id INTEGER NOT NULL,
    debit NUMERIC(15,2) NOT NULL DEFAULT 0,
    credit NUMERIC(15,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_jl_header FOREIGN KEY (header_id)
        REFERENCES journal_headers(header_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_jl_account FOREIGN KEY (account_id)
        REFERENCES chart_of_accounts(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_debit_nonneg CHECK (debit >= 0),
    CONSTRAINT chk_credit_nonneg CHECK (credit >= 0),
    CONSTRAINT chk_not_both_zero CHECK (debit > 0 OR credit > 0),
    CONSTRAINT chk_one_side_only CHECK (NOT (debit > 0 AND credit > 0))
);

CREATE INDEX idx_journal_lines_header_id ON journal_lines(header_id);
CREATE INDEX idx_journal_lines_account_id ON journal_lines(account_id);

CREATE OR REPLACE FUNCTION check_posted_journal_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_header_id INTEGER;
    v_status VARCHAR(10);
    v_debit NUMERIC(15,2);
    v_credit NUMERIC(15,2);
    v_count BIGINT;
BEGIN
    v_header_id := COALESCE(NEW.header_id, OLD.header_id);

    SELECT posting_status INTO v_status
    FROM journal_headers
    WHERE header_id = v_header_id;

    IF NOT FOUND OR v_status <> 'POSTED' THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
      INTO v_count, v_debit, v_credit
      FROM journal_lines
     WHERE header_id = v_header_id;

    IF v_count < 2 THEN
        RAISE EXCEPTION 'Jurnal POSTED % minimal harus memiliki dua baris.', v_header_id;
    END IF;

    IF v_debit <= 0 OR v_credit <= 0 OR v_debit <> v_credit THEN
        RAISE EXCEPTION
          'Jurnal % tidak seimbang. Debit=%, Kredit=%.',
          v_header_id, v_debit, v_credit;
    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_balance_after_header
AFTER INSERT OR UPDATE OF posting_status ON journal_headers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_posted_journal_balance();

CREATE CONSTRAINT TRIGGER trg_balance_after_lines
AFTER INSERT OR UPDATE OR DELETE ON journal_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_posted_journal_balance();

-- Contoh penggunaan:
-- BEGIN;
-- INSERT INTO chart_of_accounts(account_code, account_name, normal_balance, report_classification)
-- VALUES ('1-100','Kas','DEBIT','ASET'), ('4-100','Pendapatan Jasa','KREDIT','PENDAPATAN');
-- INSERT INTO journal_headers(transaction_date, reference_number, description, posting_status)
-- VALUES (CURRENT_DATE, 'JV-001', 'Contoh jurnal', 'POSTED') RETURNING header_id;
-- -- Gunakan header_id yang dikembalikan, lalu masukkan minimal dua journal_lines
-- -- dengan total debit = total kredit.
-- COMMIT;