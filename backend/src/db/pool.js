const mysql = require('mysql2/promise');
const path  = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const pool = mysql.createPool({
  host:              process.env.DB_HOST     || 'localhost',
  port:              parseInt(process.env.DB_PORT || '3306'),
  user:              process.env.DB_USER,
  password:          process.env.DB_PASSWORD,
  database:          process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit:   10,
  queueLimit:        0,
  // Reconexão automática se a ligação cair
  enableKeepAlive:   true,
  keepAliveInitialDelay: 0,
  // Charset explícito para suporte a caracteres especiais (português)
  charset:           'utf8mb4',
});

// ── Teste de ligação ao arrancar ────────────────────────────────────────────
pool.getConnection()
  .then(conn => {
    console.log(`✅  MySQL ligado a ${process.env.DB_HOST}/${process.env.DB_NAME}`);
    conn.release();
  })
  .catch(err => {
    console.error('❌  Erro ao ligar ao MySQL:', err.message);
    console.error('    Verifica as credenciais em backend/.env');
    process.exit(1);
  });

module.exports = pool;