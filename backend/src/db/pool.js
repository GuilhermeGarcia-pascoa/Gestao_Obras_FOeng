const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', 'env') });

const pool = mysql.createPool({
  host:     process.env.DB_HOST,
  port:     process.env.DB_PORT,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

// Testa a ligação ao arrancar
pool.getConnection()
  .then(conn => {
    console.log('✅  MySQL ligado a', process.env.DB_NAME);
    conn.release();
  })
  .catch(err => {
    console.error('❌  Erro ao ligar ao MySQL:', err.message);
    process.exit(1);
  });

module.exports = pool;
