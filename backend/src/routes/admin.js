const router  = require('express').Router();
const bcrypt  = require('bcryptjs');
const pool    = require('../db/pool');
const { auth, soAdmin } = require('../middleware/auth');

// Todas as rotas requerem login de admin
router.use(auth, soAdmin);

// ── Validação de password ──────────────────────────────────────────────────
function validarPassword(password) {
  if (!password || password.length < 8) {
    return 'A password deve ter pelo menos 8 caracteres';
  }
  if (!/[a-zA-Z]/.test(password)) {
    return 'A password deve conter pelo menos uma letra';
  }
  if (!/[0-9]/.test(password)) {
    return 'A password deve conter pelo menos um número';
  }
  return null;
}

// ── GET /api/admin/utilizadores ────────────────────────────────────────────
router.get('/utilizadores', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nome, email, role FROM utilizadores ORDER BY nome'
    );
    res.json(rows);
  } catch (err) {
    console.error('[ADMIN GET UTILIZADORES]', err.message);
    res.status(500).json({ erro: err.message });
  }
});

// ── POST /api/admin/utilizadores ───────────────────────────────────────────
router.post('/utilizadores', async (req, res) => {
  const { nome, email, password, role } = req.body;

  if (!nome || !email || !password) {
    return res.status(400).json({ erro: 'Nome, email e password obrigatórios' });
  }

  // Validar email
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ erro: 'Formato de email inválido' });
  }

  // Validar password
  const erroPassword = validarPassword(password);
  if (erroPassword) {
    return res.status(400).json({ erro: erroPassword });
  }

  // Validar role
  const rolesPermitidos = ['utilizador', 'gestor', 'admin'];
  if (role && !rolesPermitidos.includes(role)) {
    return res.status(400).json({ erro: 'Role inválido' });
  }

  try {
    const hash = await bcrypt.hash(password, 12);
    const [result] = await pool.query(
      'INSERT INTO utilizadores (nome, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [nome.trim(), email.toLowerCase().trim(), hash, role || 'utilizador']
    );

    res.status(201).json({
      id:    result.insertId,
      nome:  nome.trim(),
      email: email.toLowerCase().trim(),
      role:  role || 'utilizador',
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Email já registado' });
    }
    console.error('[ADMIN CRIAR UTILIZADOR]', err.message);
    res.status(500).json({ erro: err.message });
  }
});

// ── PUT /api/admin/utilizadores/:id/senha ──────────────────────────────────
router.put('/utilizadores/:id/senha', async (req, res) => {
  const { password } = req.body;

  if (!password) {
    return res.status(400).json({ erro: 'Password obrigatória' });
  }

  const erroPassword = validarPassword(password);
  if (erroPassword) {
    return res.status(400).json({ erro: erroPassword });
  }

  try {
    const hash = await bcrypt.hash(password, 12);
    const [result] = await pool.query(
      'UPDATE utilizadores SET password_hash = ? WHERE id = ?',
      [hash, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ erro: 'Utilizador não encontrado' });
    }

    res.json({ ok: true });
  } catch (err) {
    console.error('[ADMIN SENHA]', err.message);
    res.status(500).json({ erro: err.message });
  }
});

// ── DELETE /api/admin/utilizadores/:id ─────────────────────────────────────
router.delete('/utilizadores/:id', async (req, res) => {
  // Não permitir apagar a si próprio
  if (parseInt(req.params.id) === req.user?.id) {
    return res.status(403).json({ erro: 'Não podes apagar a tua própria conta' });
  }

  try {
    const [result] = await pool.query(
      'DELETE FROM utilizadores WHERE id = ?',
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ erro: 'Utilizador não encontrado' });
    }

    res.json({ ok: true });
  } catch (err) {
    console.error('[ADMIN DELETE UTILIZADOR]', err.message);
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;