const router = require('express').Router();
const bcrypt = require('bcryptjs');
const pool = require('../db/pool');
const { auth, soAdmin } = require('../middleware/auth');

router.use(auth, soAdmin);

// GET /api/admin/utilizadores
router.get('/utilizadores', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, nome, email, role FROM utilizadores ORDER BY nome');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// POST /api/admin/utilizadores
router.post('/utilizadores', async (req, res) => {
  const { nome, email, password, role } = req.body;

  if (!nome || !email || !password) {
    return res.status(400).json({ erro: 'Nome, email e password obrigatórios' });
  }

  try {
    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO utilizadores (nome, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [nome, email, hash, role || 'utilizador']
    );

    res.status(201).json({ id: result.insertId, nome, email, role: role || 'utilizador' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Email já registado' });
    }
    res.status(500).json({ erro: err.message });
  }
});

// PUT /api/admin/utilizadores/:id/senha
router.put('/utilizadores/:id/senha', async (req, res) => {
  const { password } = req.body;

  if (!password) {
    return res.status(400).json({ erro: 'Password obrigatória' });
  }

  try {
    const hash = await bcrypt.hash(password, 10);
    await pool.query(
      'UPDATE utilizadores SET password_hash = ? WHERE id = ?',
      [hash, req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// DELETE /api/admin/utilizadores/:id
router.delete('/utilizadores/:id', async (req, res) => {
  try {
    // Não permitir apagar a si próprio
    if (parseInt(req.params.id) === req.user?.id) {
      return res.status(403).json({ erro: 'Não podes apagar-te a ti próprio' });
    }

    await pool.query('DELETE FROM utilizadores WHERE id = ?', [req.params.id]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;
