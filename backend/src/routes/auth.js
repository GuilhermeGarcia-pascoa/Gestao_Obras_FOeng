const router  = require('express').Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { z }   = require('zod');
const pool    = require('../db/pool');
const {
  auth,
  soAdmin,
  rateLimitLogin,
  registarFalhaLogin,
  limparFalhasLogin,
  JWT_ISSUER,
  JWT_AUDIENCE,
} = require('../middleware/auth');

// ── Schemas Zod ────────────────────────────────────────────────────────────
const schemaLogin = z.object({
  email:    z.string().email('Email inválido'),
  password: z.string().min(1, 'Password obrigatória'),
});

const schemaRegistar = z.object({
  nome:     z.string().min(2, 'Nome deve ter pelo menos 2 caracteres'),
  email:    z.string().email('Email inválido'),
  password: z.string()
    .min(8, 'A password deve ter pelo menos 8 caracteres')
    .regex(/[a-zA-Z]/, 'A password deve conter pelo menos uma letra')
    .regex(/[0-9]/,    'A password deve conter pelo menos um número'),
  role: z.enum(['utilizador', 'gestor', 'admin']).optional(),
});

const schemaTema = z.object({
  tema_preferido: z.enum(['light', 'dark', 'system'], {
    errorMap: () => ({ message: 'Tema inválido. Use: light, dark ou system' }),
  }),
});

// ── POST /api/auth/login ───────────────────────────────────────────────────
router.post('/login', rateLimitLogin, async (req, res) => {
  const parsed = schemaLogin.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { email, password } = parsed.data;
  const ip = req.ip || req.connection.remoteAddress || 'unknown';

  try {
    const [rows] = await pool.query(
      'SELECT * FROM utilizadores WHERE email = ? LIMIT 1',
      [email.toLowerCase().trim()]
    );

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

    limparFalhasLogin(ip);

    const token = jwt.sign(
      { id: user.id, nome: user.nome, role: user.role },
      process.env.JWT_SECRET,
      {
        expiresIn: process.env.JWT_EXPIRES_IN || '1h',
        issuer:    JWT_ISSUER,
        audience:  JWT_AUDIENCE,
      }
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
  res.json({ success: true, mensagem: 'Sessão terminada com sucesso' });
});

// ── POST /api/auth/registar — SÓ ADMINS ────────────────────────────────────
router.post('/registar', auth, soAdmin, async (req, res) => {
  const parsed = schemaRegistar.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { nome, email, password, role } = parsed.data;

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
    console.error('[REGISTAR ERROR]', err.message);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── PUT /api/auth/prefs/tema ────────────────────────────────────────────────
router.put('/prefs/tema', auth, async (req, res) => {
  const parsed = schemaTema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { tema_preferido } = parsed.data;

  try {
    await pool.query(
      'UPDATE utilizadores SET tema_preferido = ? WHERE id = ?',
      [tema_preferido, req.user.id]
    );
    res.json({ sucesso: true, tema_preferido });
  } catch (err) {
    console.error('[TEMA ERROR]', err.message);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

module.exports = router;
