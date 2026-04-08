const router  = require('express').Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const pool    = require('../db/pool');
const { auth, soAdmin, rateLimitLogin, registarFalhaLogin, limparFalhasLogin } = require('../middleware/auth');

// ── Validação de password ──────────────────────────────────────────────────
// Mínimo 8 chars, pelo menos 1 letra e 1 número
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
  return null; // null = válida
}

// ── POST /api/auth/login ───────────────────────────────────────────────────
router.post('/login', rateLimitLogin, async (req, res) => {
  const { email, password } = req.body;
  const ip = req.ip || req.connection.remoteAddress || 'unknown';

  if (!email || !password) {
    return res.status(400).json({ erro: 'Email e password obrigatórios' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT * FROM utilizadores WHERE email = ? LIMIT 1',
      [email.toLowerCase().trim()]
    );

    // Resposta genérica para não revelar se o email existe
    if (rows.length === 0) {
      registarFalhaLogin(ip);
      return res.status(401).json({ erro: 'Credenciais inválidas' });
    }

    const user = rows[0];
    const ok   = await bcrypt.compare(password, user.password_hash);

    if (!ok) {
      registarFalhaLogin(ip);
      return res.status(401).json({ erro: 'Credenciais inválidas' });
    }

    // Login bem sucedido — limpar tentativas falhadas
    limparFalhasLogin(ip);

    const token = jwt.sign(
      { id: user.id, nome: user.nome, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      token,
      utilizador: {
        id:             user.id,
        nome:           user.nome,
        email:          user.email,
        role:           user.role,
        tema_preferido: user.tema_preferido || 'system',
      },
    });
  } catch (err) {
    console.error('[LOGIN ERROR]', err.message);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── GET /api/auth/me ───────────────────────────────────────────────────────
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
        id:             user.id,
        nome:           user.nome,
        email:          user.email,
        role:           user.role,
        tema_preferido: user.tema_preferido || 'system',
      },
    });
  } catch (err) {
    console.error('[ME ERROR]', err.message);
    res.status(500).json({ erro: 'Erro ao obter dados do utilizador' });
  }
});

// ── POST /api/auth/logout ──────────────────────────────────────────────────
router.post('/logout', auth, (req, res) => {
  // JWT é stateless — o token expira naturalmente
  // O cliente deve apagar o token localmente
  res.json({ success: true, mensagem: 'Sessão terminada com sucesso' });
});

// ── POST /api/auth/registar — SÓ ADMINS ────────────────────────────────────
// Protegido: requer token de admin válido
router.post('/registar', auth, soAdmin, async (req, res) => {
  const { nome, email, password, role } = req.body;

  if (!nome || !email || !password) {
    return res.status(400).json({ erro: 'Nome, email e password obrigatórios' });
  }

  // Validar formato de email
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
    const hash = await bcrypt.hash(password, 12); // 12 rounds (mais seguro que 10)
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
    console.error('[REGISTAR ERROR]', err.message);
    res.status(500).json({ erro: err.message });
  }
});

// ── PUT /api/auth/prefs/tema ────────────────────────────────────────────────
router.put('/prefs/tema', auth, async (req, res) => {
  const { tema_preferido } = req.body;

  if (!tema_preferido || !['light', 'dark', 'system'].includes(tema_preferido)) {
    return res.status(400).json({ erro: 'Tema inválido. Use: light, dark ou system' });
  }

  try {
    await pool.query(
      'UPDATE utilizadores SET tema_preferido = ? WHERE id = ?',
      [tema_preferido, req.user.id]
    );
    res.json({ sucesso: true, tema_preferido });
  } catch (err) {
    console.error('[TEMA ERROR]', err.message);
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;