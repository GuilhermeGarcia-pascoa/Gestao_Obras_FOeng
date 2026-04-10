/**
 * logger.js — Sistema de auditoria em base de dados
 *
 * Regista ações de utilizadores na tabela `logs`.
 * NUNCA lança exceções — falhas de logging são silenciosas para não
 * interromper o fluxo normal da API.
 *
 * Schema esperado:
 *   CREATE TABLE logs (
 *     id         INT AUTO_INCREMENT PRIMARY KEY,
 *     user_id    INT NULL,
 *     action     VARCHAR(50)  NOT NULL,
 *     entity     VARCHAR(50)  NOT NULL,
 *     entity_id  INT NULL,
 *     details    TEXT,
 *     ip         VARCHAR(45)  NULL,
 *     method     VARCHAR(10)  NULL,
 *     url        VARCHAR(255) NULL,
 *     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
 *   );
 */

const pool = require('../db/pool');

/**
 * Regista uma ação na tabela logs.
 *
 * @param {object} opts
 * @param {number|null}  opts.userId   — ID do utilizador (null para ações anónimas)
 * @param {string}       opts.action   — Ex: 'CREATE', 'UPDATE', 'DELETE', 'LOGIN_SUCCESS'
 * @param {string}       opts.entity   — Ex: 'obras', 'auth', 'equipa'
 * @param {number|null}  [opts.entityId]  — ID do registo afetado
 * @param {object}       [opts.details]   — Dados extra (body, email tentado, etc.)
 * @param {string|null}  [opts.ip]        — IP do pedido (req.ip)
 * @param {string|null}  [opts.method]    — Método HTTP (req.method)
 * @param {string|null}  [opts.url]       — URL do pedido (req.originalUrl)
 */
async function logAction({
  userId   = null,
  action,
  entity,
  entityId = null,
  details  = {},
  ip       = null,
  method   = null,
  url      = null,
}) {
  try {
    // Sanitizar details: remover campos sensíveis antes de persistir
    const safeDetails = sanitizeDetails(details);

    await pool.query(
      `INSERT INTO logs (user_id, action, entity, entity_id, details, ip, method, url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        userId   || null,
        action,
        entity,
        entityId || null,
        JSON.stringify(safeDetails),
        ip       || null,
        method   || null,
        url      || null,
      ]
    );
  } catch (err) {
    // Logging NUNCA deve crashar a API — apenas emite aviso interno
    console.error('[LOGGER] Falha ao registar log:', err.message);
  }
}

/**
 * Remove campos sensíveis do objeto details antes de o persistir.
 * Garante que passwords e tokens nunca chegam à tabela logs.
 */
const CAMPOS_SENSIVEIS = [
  'password', 'password_hash', 'senha', 'token',
  'authorization', 'secret', 'jwt', 'hash',
];

function sanitizeDetails(obj) {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return obj;
  const limpo = { ...obj };
  for (const campo of CAMPOS_SENSIVEIS) {
    if (campo in limpo) limpo[campo] = '[REDACTED]';
  }
  return limpo;
}

/**
 * Extrai metadados do pedido Express de forma conveniente.
 * Uso: const meta = reqMeta(req);
 */
function reqMeta(req) {
  return {
    ip:     req.ip || req.connection?.remoteAddress || null,
    method: req.method || null,
    url:    req.originalUrl || null,
  };
}

module.exports = { logAction, reqMeta };
