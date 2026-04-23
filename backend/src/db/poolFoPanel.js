const mysql = require('mysql2/promise');
const path  = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const poolFoPanel = mysql.createPool({
  host:               process.env.FOPANEL_HOST     || process.env.DB_HOST,
  port:               parseInt(process.env.FOPANEL_PORT || '3306'),
  user:               process.env.FOPANEL_USER     || process.env.DB_USER,
  password:           process.env.FOPANEL_PASSWORD || process.env.DB_PASSWORD,
  database:           'fo_panel',
  waitForConnections: true,
  connectionLimit:    5,
  queueLimit:         0,
  enableKeepAlive:    true,
  keepAliveInitialDelay: 0,
  charset:            'utf8mb4',
});

// Teste de ligação ao arrancar
poolFoPanel.getConnection()
  .then(conn => {
    console.log(`✅  MySQL ligado a ${process.env.FOPANEL_HOST || process.env.DB_HOST}/fo_panel (sync)`);
    conn.release();
  })
  .catch(err => {
    // Aviso mas não mata o servidor — fo_panel pode estar indisponível temporariamente
    console.warn('⚠️   Não foi possível ligar ao fo_panel (sync):', err.message);
  });

module.exports = poolFoPanel;
