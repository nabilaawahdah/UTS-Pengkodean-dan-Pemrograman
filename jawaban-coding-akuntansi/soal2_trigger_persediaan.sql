-- SOAL 2.1 — OTOMATISASI MUTASI PERSEDIAAN (PostgreSQL)
-- Mengikuti struktur tabel yang diberikan pada naskah soal.
-- Catatan: belum membuat jurnal GL karena tabel akun/jurnal dan pemetaan akun
-- tidak disediakan pada soal. Trigger ini mengelola stok secara atomik.

CREATE TABLE IF NOT EXISTS inventory_items (
    item_id VARCHAR(10) PRIMARY KEY,
    item_name VARCHAR(100),
    stock_qty INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    unit_cost NUMERIC(15,2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE IF NOT EXISTS inventory_transactions (
    trx_id SERIAL PRIMARY KEY,
    item_id VARCHAR(10) NOT NULL REFERENCES inventory_items(item_id) ON DELETE RESTRICT,
    trx_type VARCHAR(10) NOT NULL CHECK (trx_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT')),
    qty INT NOT NULL,
    trx_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION trg_update_stock_and_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock INT;
    v_new_stock INT;
BEGIN
    IF NEW.trx_type IN ('PURCHASE', 'SALE') THEN
        IF NEW.qty IS NULL OR NEW.qty <= 0 THEN
            RAISE EXCEPTION 'Qty untuk PURCHASE dan SALE harus lebih dari 0.';
        END IF;
    ELSIF NEW.trx_type = 'ADJUSTMENT' THEN
        IF NEW.qty IS NULL OR NEW.qty = 0 THEN
            RAISE EXCEPTION 'Qty ADJUSTMENT tidak boleh 0.';
        END IF;
    ELSE
        RAISE EXCEPTION 'Jenis transaksi tidak valid: %', NEW.trx_type;
    END IF;

    SELECT stock_qty
      INTO v_current_stock
      FROM inventory_items
     WHERE item_id = NEW.item_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item % tidak ditemukan.', NEW.item_id;
    END IF;

    CASE NEW.trx_type
        WHEN 'PURCHASE' THEN v_new_stock := v_current_stock + NEW.qty;
        WHEN 'SALE' THEN v_new_stock := v_current_stock - NEW.qty;
        WHEN 'ADJUSTMENT' THEN v_new_stock := v_current_stock + NEW.qty;
    END CASE;

    IF v_new_stock < 0 THEN
        RAISE EXCEPTION
          'Stok tidak mencukupi untuk item %. Stok tersedia: %, perubahan qty: %.',
          NEW.item_id, v_current_stock, NEW.qty;
    END IF;

    UPDATE inventory_items
       SET stock_qty = v_new_stock
     WHERE item_id = NEW.item_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_stock_and_journal ON inventory_transactions;
CREATE TRIGGER trg_update_stock_and_journal
AFTER INSERT ON inventory_transactions
FOR EACH ROW EXECUTE FUNCTION trg_update_stock_and_journal();

CREATE INDEX IF NOT EXISTS idx_inventory_transactions_item_date
    ON inventory_transactions(item_id, trx_date);

-- Uji cepat:
-- INSERT INTO inventory_items(item_id, item_name, stock_qty, unit_cost)
-- VALUES ('BRG-001', 'Buku', 1, 10000);
-- INSERT INTO inventory_transactions(item_id, trx_type, qty)
-- VALUES ('BRG-001', 'SALE', 1); -- berhasil, stok menjadi 0
-- INSERT INTO inventory_transactions(item_id, trx_type, qty)
-- VALUES ('BRG-001', 'SALE', 1); -- error, transaksi dibatalkan