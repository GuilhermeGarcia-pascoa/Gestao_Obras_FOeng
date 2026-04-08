// backend/src/routes/auth.js
const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db/pool');
const { auth } = require('../middleware/auth');

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ erro: 'Email e password obrigatórios' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT * FROM utilizadores WHERE email = ? LIMIT 1',
      [email]
    );

    if (rows.length === 0) {
      return res.status(401).json({ erro: 'Credenciais inválidas' });
    }

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);

    if (!ok) {
      return res.status(401).json({ erro: 'Credenciais inválidas' });
    }

    const token = jwt.sign(
      { id: user.id, nome: user.nome, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      token,
      utilizador: { 
        id: user.id, 
        nome: user.nome, 
        email: user.email, 
        role: user.role,
        tema_preferido: user.tema_preferido || 'system',
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── NOVO: GET /api/auth/me ─────────────────────────────────────
router.get('/me', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nome, email, role, tema_preferido FROM utilizadores WHERE id = ?',
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ erro: 'Utilizador não encontrado' });
    }

    const user = rows[0];

    res.json({
      success: true,
      utilizador: {
        id: user.id,
        nome: user.nome,
        email: user.email,
        role: user.role,
        tema_preferido: user.tema_preferido || 'system'
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ erro: 'Erro ao obter dados do utilizador' });
  }
});

// ── NOVO: POST /api/auth/logout ───────────────────────────────
router.post('/logout', auth, (req, res) => {
  // Por enquanto só confirmamos (futuramente podemos adicionar blacklist de tokens)
  res.json({ success: true, mensagem: 'Sessão terminada com sucesso' });
});

// POST /api/auth/registar  (só admins devem chamar isto)
router.post('/registar', async (req, res) => {
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

    res.status(201).json({ id: result.insertId, nome, email });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Email já registado' });
    }
    res.status(500).json({ erro: err.message });
  }
});

// PUT /api/auth/prefs/tema — atualizar tema do utilizador (protegido)
router.put('/prefs/tema', auth, async (req, res) => {
  const { tema_preferido } = req.body;
  const userId = req.user?.id;

  if (!userId) {
    return res.status(401).json({ erro: 'Token inválido' });
  }

  if (!tema_preferido || !['light', 'dark', 'system'].includes(tema_preferido)) {
    return res.status(400).json({ erro: 'Tema inválido' });
  }

  try {
    await pool.query(
      'UPDATE utilizadores SET tema_preferido = ? WHERE id = ?',
      [tema_preferido, userId]
    );
    res.json({ sucesso: true, tema_preferido });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;