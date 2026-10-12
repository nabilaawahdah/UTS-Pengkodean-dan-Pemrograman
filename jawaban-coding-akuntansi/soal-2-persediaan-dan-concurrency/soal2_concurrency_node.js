// SOAL 2.2 — contoh Node.js + Express/pg untuk penjualan aman.
// npm install pg
// Atur DATABASE_URL pada environment. Trigger soal 2 tetap menjadi validasi akhir.

const { Pool } = require("pg");
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function processSale(itemId, qty) {
  if (!Number.isInteger(qty) || qty <= 0) {
    throw new Error("Qty penjualan harus bilangan bulat positif.");
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const result = await client.query(
      `SELECT stock_qty
         FROM inventory_items
        WHERE item_id = $1
        FOR UPDATE`,
      [itemId]
    );

    if (result.rowCount === 0) throw new Error("Item tidak ditemukan.");
    if (result.rows[0].stock_qty < qty) throw new Error("Stok tidak mencukupi.");

    const trx = await client.query(
      `INSERT INTO inventory_transactions(item_id, trx_type, qty)
       VALUES ($1, 'SALE', $2)
       RETURNING trx_id, trx_date`,
      [itemId, qty]
    );

    await client.query("COMMIT");
    return { success: true, transaction: trx.rows[0] };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { processSale };