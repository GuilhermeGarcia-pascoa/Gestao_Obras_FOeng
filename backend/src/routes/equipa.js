const router = require('express').Router();
const { z } = require('zod');
const pool = require('../db/pool');
const { auth, soGestor } = require('../middleware/auth');
const { logAction, reqMeta } = require('../utils/logger');

router.use(auth);

function toDbAtivo(value) {
  return value === false || value === 0 || value === '0' ? 0 : 1;
}

function toNullableText(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function sqlEstado(tabela, campoNome, estado) {
  let sql = `SELECT * FROM ${tabela}`;
  if (estado === 'ativas') sql += ' WHERE COALESCE(ativo, 1) = 1';
  if (estado === 'inativas') sql += ' WHERE COALESCE(ativo, 1) = 0';
  sql += ` ORDER BY ${campoNome}`;
  return sql;
}

function sqlEstadoPessoas(estado) {
  let sql = `
    SELECT
      o.*,
      COALESCE(o.tipo_vinculo, 'interno') AS tipo_vinculo
    FROM operadores o
  `;
  if (estado === 'ativas') sql += ' WHERE COALESCE(o.ativo, 1) = 1';
  if (estado === 'inativas') sql += ' WHERE COALESCE(o.ativo, 1) = 0';
  sql += ' ORDER BY o.nome';
  return sql;
}

const schemaPessoa = z.object({
  nome: z.string().trim().min(1, 'Nome obrigatorio'),
  cargo: z.string().optional().nullable(),
  categoria_sindical: z.string().optional().nullable(),
  custo_hora: z.preprocess(Number, z.number().min(0, 'Custo por hora invalido')),
  pais: z.string().optional().nullable(),
  tipo_vinculo: z.preprocess(
    (value) => {
      if (value === null || value === undefined || String(value).trim() === '') return 'interno';
      return String(value).trim().toLowerCase();
    },
    z.enum(['interno', 'externo'])
  ),
  ativo: z.any().optional(),
});

const schemaMaquina = z.object({
  nome: z.string().min(1, 'Nome obrigatorio'),
  tipo: z.string().optional().nullable(),
  matricula: z.string().optional().nullable(),
  custo_hora: z.preprocess(Number, z.number().min(0, 'Custo por hora invalido')),
  combustivel_hora: z.preprocess(
    (value) => (value === null || value === undefined ? 0 : Number(value)),
    z.number().min(0, 'Combustivel por hora invalido')
  ),
  ativo: z.any().optional(),
});

const schemaViatura = z.object({
  modelo: z.string().min(1, 'Modelo obrigatorio'),
  matricula: z.string().optional().nullable(),
  custo_km: z.preprocess(Number, z.number().min(0, 'Custo por km invalido')),
  consumo_l100km: z.preprocess(
    (value) => (value === null || value === undefined ? 0 : Number(value)),
    z.number().min(0, 'Consumo invalido')
  ),
  motorista_id: z.number().int().positive().optional().nullable(),
  ativo: z.any().optional(),
});

router.get('/pessoas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstadoPessoas(estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.get('/pessoas/:id', async (req, res) => {
  try {
    const [[row]] = await pool.query(
      `SELECT
         o.*,
         COALESCE(o.tipo_vinculo, 'interno') AS tipo_vinculo
       FROM operadores o
       WHERE o.id = ?`,
      [req.params.id]
    );
    if (!row) return res.status(404).json({ erro: 'Nao encontrado' });
    res.json(row);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.post('/pessoas', soGestor, async (req, res) => {
  const parsed = schemaPessoa.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ erro: parsed.error.errors[0].message });

  const {
    nome,
    cargo,
    categoria_sindical,
    custo_hora,
    pais,
    tipo_vinculo,
    ativo,
  } = parsed.data;

  try {
    const [result] = await pool.query(
      `INSERT INTO operadores
         (nome, cargo, categoria_sindical, custo_hora, pais, tipo_vinculo, ativo)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        nome.trim(),
        toNullableText(cargo),
        toNullableText(categoria_sindical),
        Number(custo_hora),
        toNullableText(pais),
        tipo_vinculo,
        toDbAtivo(ativo),
      ]
    );

    await logAction({
      userId: req.user.id,
      action: 'CREATE',
      entity: 'operadores',
      entityId: result.insertId,
      details: {
        nome: nome.trim(),
        cargo: toNullableText(cargo),
        custo_hora,
        tipo_vinculo,
      },
      ...reqMeta(req),
    });

    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.put('/pessoas/:id', soGestor, async (req, res) => {
  const parsed = schemaPessoa.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ erro: parsed.error.errors[0].message });

  const {
    nome,
    cargo,
    categoria_sindical,
    custo_hora,
    pais,
    tipo_vinculo,
    ativo,
  } = parsed.data;

  try {
    await pool.query(
      `UPDATE operadores
       SET nome=?, cargo=?, categoria_sindical=?, custo_hora=?, pais=?, tipo_vinculo=?, ativo=?
       WHERE id=?`,
      [
        nome.trim(),
        toNullableText(cargo),
        toNullableText(categoria_sindical),
        Number(custo_hora),
        toNullableText(pais),
        tipo_vinculo,
        toDbAtivo(ativo),
        req.params.id,
      ]
    );

    await logAction({
      userId: req.user.id,
      action: 'UPDATE',
      entity: 'operadores',
      entityId: parseInt(req.params.id, 10),
      details: {
        nome: nome.trim(),
        cargo: toNullableText(cargo),
        custo_hora,
        tipo_vinculo,
        ativo,
      },
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.delete('/pessoas/:id', soGestor, async (req, res) => {
  return res.status(403).json({
    erro: 'Nao e permitido apagar trabalhadores. Marque o trabalhador como inativo para preservar os graficos e historico.',
  });
});

router.get('/maquinas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('maquinas', 'nome', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.post('/maquinas', soGestor, async (req, res) => {
  const parsed = schemaMaquina.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ erro: parsed.error.errors[0].message });

  const { nome, tipo, matricula, custo_hora, combustivel_hora, ativo } = parsed.data;

  try {
    const [result] = await pool.query(
      'INSERT INTO maquinas (nome, tipo, matricula, custo_hora, combustivel_hora, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [nome.trim(), tipo, matricula, Number(custo_hora), Number(combustivel_hora ?? 0), toDbAtivo(ativo)]
    );

    await logAction({
      userId: req.user.id,
      action: 'CREATE',
      entity: 'maquinas',
      entityId: result.insertId,
      details: { nome: nome.trim(), tipo, matricula, custo_hora },
      ...reqMeta(req),
    });

    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.put('/maquinas/:id', soGestor, async (req, res) => {
  const parsed = schemaMaquina.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ erro: parsed.error.errors[0].message });

  const { nome, tipo, matricula, custo_hora, combustivel_hora, ativo } = parsed.data;

  try {
    await pool.query(
      'UPDATE maquinas SET nome=?, tipo=?, matricula=?, custo_hora=?, combustivel_hora=?, ativo=? WHERE id=?',
      [nome.trim(), tipo, matricula, Number(custo_hora), Number(combustivel_hora ?? 0), toDbAtivo(ativo), req.params.id]
    );

    await logAction({
      userId: req.user.id,
      action: 'UPDATE',
      entity: 'maquinas',
      entityId: parseInt(req.params.id, 10),
      details: { nome: nome.trim(), tipo, matricula, custo_hora, ativo },
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.delete('/maquinas/:id', soGestor, async (req, res) => {
  return res.status(403).json({
    erro: 'Nao e permitido apagar maquinas. Marque a maquina como inativa para preservar os graficos e historico.',
  });
});

router.get('/viaturas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('viaturas', 'modelo', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.post('/viaturas', soGestor, async (req, res) => {
  const parsed = schemaViatura.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ erro: parsed.error.errors[0].message });

  const { modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo } = parsed.data;

  try {
    const [result] = await pool.query(
      'INSERT INTO viaturas (modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [modelo.trim(), matricula, Number(custo_km), Number(consumo_l100km ?? 0), motorista_id, toDbAtivo(ativo)]
    );

    await logAction({
      userId: req.user.id,
      action: 'CREATE',
      entity: 'viaturas',
      entityId: result.insertId,
      details: { modelo: modelo.trim(), matricula, custo_km },
      ...reqMeta(req),
    });

    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.put('/viaturas/:id', soGestor, async (req, res) => {
  const parsed = schemaViatura.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ erro: parsed.error.errors[0].message });

  const { modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo } = parsed.data;

  try {
    await pool.query(
      'UPDATE viaturas SET modelo=?, matricula=?, custo_km=?, consumo_l100km=?, motorista_id=?, ativo=? WHERE id=?',
      [modelo.trim(), matricula, Number(custo_km), Number(consumo_l100km ?? 0), motorista_id, toDbAtivo(ativo), req.params.id]
    );

    await logAction({
      userId: req.user.id,
      action: 'UPDATE',
      entity: 'viaturas',
      entityId: parseInt(req.params.id, 10),
      details: { modelo: modelo.trim(), matricula, custo_km, ativo },
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.delete('/viaturas/:id', soGestor, async (req, res) => {
  return res.status(403).json({
    erro: 'Nao e permitido apagar viaturas. Marque a viatura como inativa para preservar os graficos e historico.',
  });
});

module.exports = router;
