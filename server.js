// server.js
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const pool = require('./db'); // MySQL pool
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// ---- Frontend static files ----
const frontendPath = path.resolve(__dirname, '../frontend');

if (!fs.existsSync(frontendPath)) {
  console.error('Error: Frontend folder not found at', frontendPath);
  process.exit(1);
}

app.use(express.static(frontendPath));

// ---- API routes ----
app.get('/api/health', (req, res) => res.json({ status: 'ok' }));
app.get('/api/test', (req, res) => res.json({ message: 'Server and API are working!' }));

// Get menu
app.get('/api/menu', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM menu_with_categories');
    res.json(rows);
  } catch (err) {
    try {
      const [rows] = await pool.query(`
        SELECT mi.*, c.name_en as category_en, c.slug as category_slug
        FROM menu_items mi
        LEFT JOIN categories c ON mi.category_id = c.id
        WHERE mi.is_available = TRUE
      `);
      res.json(rows);
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'Failed to fetch menu' });
    }
  }
});

// Create order
app.post('/api/orders', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const payload = req.body;
    if (!payload?.items?.length) return res.status(400).json({ error: 'Order must include items' });

    await connection.beginTransaction();

    const orderNumber = 'ORD-' + uuidv4().split('-')[0].toUpperCase();

    const [orderRes] = await connection.query(
      `INSERT INTO orders
       (order_number, session_id, table_id, total_amount, queue_number, special_instructions)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        orderNumber,
        payload.session_id || 'S' + Date.now(),
        payload.table_id || 1,
        0,
        payload.queue_number || 'A00',
        payload.special_instructions || null
      ]
    );
    const orderId = orderRes.insertId;

    let orderTotal = 0;
    for (const it of payload.items) {
      const totalPrice = parseFloat(it.total_price ?? (it.unit_price * it.quantity));
      orderTotal += totalPrice;
      await connection.query(
        `INSERT INTO order_items
         (order_id, customer_id, menu_item_id, quantity, unit_price, total_price, spicy_level, protein_choice, special_notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderId,
          it.customer_id || null,
          it.menu_item_id,
          it.quantity || 1,
          it.unit_price,
          totalPrice,
          it.spicy_level || 0,
          it.protein_choice || 'Original',
          it.special_notes || null
        ]
      );
    }

    await connection.query('UPDATE orders SET total_amount = ? WHERE id = ?', [orderTotal, orderId]);

    await connection.commit();
    connection.release();

    res.json({ order_id: orderId, order_number: orderNumber });
  } catch (e) {
    await connection.rollback();
    connection.release();
    console.error(e);
    res.status(500).json({ error: 'Failed to create order' });
  }
});

// Active orders
app.get('/api/orders/active', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM active_orders');
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch active orders' });
  }
});

// Admin registration
app.post('/api/admin/register', async (req, res) => {
  try {
    const { username, email, password, role } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'username and password required' });
    const password_hash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [username, email || null, password_hash, role || 'staff']
    );
    res.json({ id: result.insertId, username });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to register user' });
  }
});

// Serve index.html
app.get('/', (req, res) => {
  res.sendFile(path.join(frontendPath, 'index.html'));
});

// SPA fallback
app.get('*', (req, res) => {
  const indexFile = path.join(frontendPath, 'index.html');
  if (fs.existsSync(indexFile)) {
    res.sendFile(indexFile);
  } else {
    console.error('Error: index.html not found!');
    res.status(500).send('Frontend not found');
  }
});

// ---- Start server and open browser ----
const PORT = process.env.PORT || 3000;
const openBrowser = (...args) => import('open').then(({ default: open }) => open(...args));

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
  openBrowser(`http://localhost:${PORT}`);
});
