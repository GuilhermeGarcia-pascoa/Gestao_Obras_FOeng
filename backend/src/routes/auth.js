const router = require('express').Router();
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const pool = require('../db/pool');
const {
  auth,
  soAdmin,
  JWT_ISSUER,
  JWT_AUDIENCE,
} = require('../middleware/auth');
const { rateLimitLogin } = require('../middleware/rateLimit');
const { logAction, reqMeta } = require('../utils/logger');

function md5Hash(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

function verificarPasswordMd5(password, hashGuardado) {
  return md5Hash(password) === hashGuardado;
}

const schemaLogin = z.object({
  email: z.string().email('Email invalido'),
  password: z.string().min(1, 'Password obrigatoria'),
});

const schemaRegistar = z.object({
  nome: z.string().min(2, 'Nome deve ter pelo menos 2 caracteres'),
  email: z.string().email('Email invalido'),
  password: z.string()
    .min(8, 'A password deve ter pelo menos 8 caracteres')
    .regex(/[a-zA-Z]/, 'A password deve conter pelo menos uma letra')
    .regex(/[0-9]/, 'A password deve conter pelo menos um numero'),
  role: z.enum(['utilizador', 'gestor', 'admin']).optional(),
});

const schemaTema = z.object({
  tema_preferido: z.enum(['light', 'dark', 'system'], {
    errorMap: () => ({ message: 'Tema invalido. Use: light, dark ou system' }),
  }),
});

router.post('/login', rateLimitLogin, async (req, res) => {
  const parsed = schemaLogin.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { email, password } = parsed.data;
  const meta = reqMeta(req);

  try {
    const [rows] = await pool.query(
      'SELECT * FROM utilizadores WHERE email = ? LIMIT 1',
      [email.toLowerCase().trim()]
    );

    if (rows.length === 0) {
      await logAction({
        userId: null,
        action: 'LOGIN_FAILED',
        entity: 'auth',
        details: { email: email.toLowerCase().trim(), motivo: 'credenciais invalidas' },
        ...meta,
      });
      return res.status(401).json({ erro: 'Credenciais invalidas' });
    }

    const user = rows[0];
    const ok = verificarPasswordMd5(password, user.password_hash);

    if (!ok) {
      await logAction({
        userId: user.id,
        action: 'LOGIN_FAILED',
        entity: 'auth',
        details: { email: email.toLowerCase().trim(), motivo: 'credenciais invalidas' },
        ...meta,
      });
      return res.status(401).json({ erro: 'Credenciais invalidas' });
    }

    const token = jwt.sign(
      { id: user.id, nome: user.nome, role: user.role },
      process.env.JWT_SECRET,
      {
        expiresIn: process.env.JWT_EXPIRES_IN || '1h',
        issuer: JWT_ISSUER,
        audience: JWT_AUDIENCE,
      }
    );

    await logAction({
      userId: user.id,
      action: 'LOGIN_SUCCESS',
      entity: 'auth',
      details: { role: user.role },
      ...meta,
    });

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
    console.error('[LOGIN ERROR]', err.message);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.get('/me', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nome, email, role, tema_preferido FROM utilizadores WHERE id = ?',
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ erro: 'Utilizador nao encontrado' });
    }

    const user = rows[0];
    res.json({
      success: true,
      utilizador: {
        id: user.id,
        nome: user.nome,
        email: user.email,
        role: user.role,
        tema_preferido: user.tema_preferido || 'system',
      },
    });
  } catch (err) {
    console.error('[ME ERROR]', err.message);
    res.status(500).json({ erro: 'Erro ao obter dados do utilizador' });
  }
});

router.post('/logout', auth, async (req, res) => {
  await logAction({
    userId: req.user.id,
    action: 'LOGOUT',
    entity: 'auth',
    ...reqMeta(req),
  });
  res.json({ success: true, mensagem: 'Sessao terminada com sucesso' });
});

router.post('/registar', auth, soAdmin, async (req, res) => {
  const parsed = schemaRegistar.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { nome, email, password, role } = parsed.data;

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
      details: { nome: nome.trim(), email: email.toLowerCase().trim(), role: role || 'utilizador' },
      ...reqMeta(req),
    });

    res.status(201).json({
      id: result.insertId,
      nome: nome.trim(),
      email: email.toLowerCase().trim(),
      role: role || 'utilizador',
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Email ja registado' });
    }
    console.error('[REGISTAR ERROR]', err.message);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

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

    await logAction({
      userId: req.user.id,
      action: 'UPDATE',
      entity: 'utilizadores',
      entityId: req.user.id,
      details: { tema_preferido },
      ...reqMeta(req),
    });

    res.json({ sucesso: true, tema_preferido });
  } catch (err) {
    console.error('[TEMA ERROR]', err.message);
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

module.exports = router;
