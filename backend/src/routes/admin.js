const router = require('express').Router();
const crypto = require('crypto');
const pool = require('../db/pool');
const { auth, soAdmin } = require('../middleware/auth');
const { logAction, reqMeta } = require('../utils/logger');

// Todas as rotas requerem login de admin
router.use(auth, soAdmin);

function responderErroAdmin(res, err) {
  console.error('[ADMIN]', err.message);

  if (err.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ erro: 'Registo duplicado' });
  }

  return res.status(500).json({ erro: 'Erro interno no servidor' });
}

/**
 * Devolve o hash MD5 de uma string (32 chars hexadecimais).
 * NOTA: MD5 e inseguro para passwords. Mantido por compatibilidade.
 *
 * @param {string} password
 * @returns {string}
 */
function md5Hash(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

function validarPassword(password) {
  if (!password || password.length < 8) return 'A password deve ter pelo menos 8 caracteres';
  if (!/[a-zA-Z]/.test(password)) return 'A password deve conter pelo menos uma letra';
  if (!/[0-9]/.test(password)) return 'A password deve conter pelo menos um numero';
  return null;
}

router.get('/utilizadores', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nome, email, role FROM utilizadores ORDER BY nome'
    );
    res.json(rows);
  } catch (err) {
    return responderErroAdmin(res, err);
  }
});

router.post('/utilizadores', async (req, res) => {
  const { nome, email, password, role } = req.body;

  if (!nome || !email || !password) {
    return res.status(400).json({ erro: 'Nome, email e password obrigatorios' });
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ erro: 'Formato de email invalido' });
  }

  const erroPassword = validarPassword(password);
  if (erroPassword) return res.status(400).json({ erro: erroPassword });

  const rolesPermitidos = ['utilizador', 'gestor', 'admin'];
  if (role && !rolesPermitidos.includes(role)) {
    return res.status(400).json({ erro: 'Role invalido' });
  }

  try {
    const hash = md5Hash(password);

    const [result] = await pool.query(
      'INSERT INTO utilizadores (nome, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [nome.trim(), email.toLowerCase().trim(), hash, role || 'utilizador']
    );

    await logAction({
      userId: req.user.id,
      action: 'CREATE',
      entity: 'utilizadores',
      entityId: result.insertId,
      details: {
        nome: nome.trim(),
        email: email.toLowerCase().trim(),
        role: role || 'utilizador',
        criado_por_admin: true,
      },
      ...reqMeta(req),
    });

    res.status(201).json({
      id: result.insertId,
      nome: nome.trim(),
      email: email.toLowerCase().trim(),
      role: role || 'utilizador',
    });
  } catch (err) {
    return responderErroAdmin(res, err);
  }
});

router.put('/utilizadores/:id/senha', async (req, res) => {
  const { password } = req.body;

  if (!password) return res.status(400).json({ erro: 'Password obrigatoria' });

  const erroPassword = validarPassword(password);
  if (erroPassword) return res.status(400).json({ erro: erroPassword });

  try {
    const hash = md5Hash(password);

    const [result] = await pool.query(
      'UPDATE utilizadores SET password_hash = ? WHERE id = ?',
      [hash, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ erro: 'Utilizador nao encontrado' });
    }

    await logAction({
      userId: req.user.id,
      action: 'UPDATE',
      entity: 'utilizadores',
      entityId: parseInt(req.params.id, 10),
      details: { campo: 'password', alterado_por_admin: true },
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    return responderErroAdmin(res, err);
  }
});

router.delete('/utilizadores/:id', async (req, res) => {
  if (parseInt(req.params.id, 10) === req.user?.id) {
    return res.status(403).json({ erro: 'Nao podes apagar a tua propria conta' });
  }

  try {
    const [[alvo]] = await pool.query(
      'SELECT id, nome, email, role FROM utilizadores WHERE id = ?',
      [req.params.id]
    );

    const [result] = await pool.query(
      'DELETE FROM utilizadores WHERE id = ?',
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ erro: 'Utilizador nao encontrado' });
    }

    await logAction({
      userId: req.user.id,
      action: 'DELETE',
      entity: 'utilizadores',
      entityId: parseInt(req.params.id, 10),
      details: alvo ? { nome: alvo.nome, email: alvo.email, role: alvo.role } : {},
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    return responderErroAdmin(res, err);
  }
});

router.get('/logs', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit ?? 200, 10), 500);
    const offset = parseInt(req.query.offset ?? 0, 10);

    const [rows] = await pool.query(
      `SELECT
         l.id,
         l.user_id,
         u.nome AS user_nome,
         l.action,
         l.entity,
         l.entity_id,
         l.details,
         l.ip,
         l.method,
         l.url,
         l.created_at
       FROM logs l
       LEFT JOIN utilizadores u ON l.user_id = u.id
       ORDER BY l.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    res.json(rows);
  } catch (err) {
    return responderErroAdmin(res, err);
  }
});

module.exports = router;
