const router = require('express').Router();
const { z }  = require('zod');
const pool   = require('../db/pool');
const { auth, soGestor } = require('../middleware/auth');

router.use(auth);

// ── Helpers ────────────────────────────────────────────────────────────────
function toDbAtivo(value) {
  return value === false || value === 0 || value === '0' ? 0 : 1;
}

// ── Schemas Zod ────────────────────────────────────────────────────────────
const schemaPessoa = z.object({
  nome:                z.string().min(1, 'Nome obrigatório'),
  cargo:               z.string().optional().nullable(),
  categoria_sindical:  z.string().optional().nullable(),
  custo_hora:          z.preprocess(Number, z.number().min(0, 'Custo por hora inválido')),
  pais:                z.string().optional().nullable(),
  ativo:               z.any().optional(),
});

const schemaMaquina = z.object({
  nome:              z.string().min(1, 'Nome obrigatório'),
  tipo:              z.string().optional().nullable(),
  matricula:         z.string().optional().nullable(),
  custo_hora:        z.preprocess(Number, z.number().min(0, 'Custo por hora inválido')),
  combustivel_hora:  z.preprocess(
    (v) => (v === null || v === undefined ? 0 : Number(v)),
    z.number().min(0, 'Combustível por hora inválido')
  ),
  ativo: z.any().optional(),
});

const schemaViatura = z.object({
  modelo:          z.string().min(1, 'Modelo obrigatório'),
  matricula:       z.string().optional().nullable(),
  custo_km:        z.preprocess(Number, z.number().min(0, 'Custo por km inválido')),
  consumo_l100km:  z.preprocess(
    (v) => (v === null || v === undefined ? 0 : Number(v)),
    z.number().min(0, 'Consumo inválido')
  ),
  motorista_id: z.number().int().positive().optional().nullable(),
  ativo: z.any().optional(),
});

// ── SQL helper ─────────────────────────────────────────────────────────────
function sqlEstado(tabela, campoNome, estado) {
  let sql = `SELECT * FROM ${tabela}`;

  if (estado === 'ativas') {
    sql += ' WHERE COALESCE(ativo, 1) = 1';
  } else if (estado === 'inativas') {
    sql += ' WHERE COALESCE(ativo, 1) = 0';
  }

  sql += ` ORDER BY ${campoNome}`;
  return sql;
}

// ═══════════════════════════════════════════════════════════════════════════
// PESSOAS
// ═══════════════════════════════════════════════════════════════════════════

router.get('/pessoas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('operadores', 'nome', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.get('/pessoas/:id', async (req, res) => {
  try {
    const [[row]] = await pool.query('SELECT * FROM operadores WHERE id = ?', [req.params.id]);
    if (!row) return res.status(404).json({ erro: 'Não encontrado' });
    res.json(row);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// POST — requires soGestor (was missing before)
router.post('/pessoas', soGestor, async (req, res) => {
  const parsed = schemaPessoa.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { nome, cargo, categoria_sindical, custo_hora, pais, ativo } = parsed.data;

  try {
    const [result] = await pool.query(
      'INSERT INTO operadores (nome, cargo, categoria_sindical, custo_hora, pais, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [nome.trim(), cargo, categoria_sindical, Number(custo_hora), pais || null, toDbAtivo(ativo)]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.put('/pessoas/:id', soGestor, async (req, res) => {
  const parsed = schemaPessoa.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { nome, cargo, categoria_sindical, custo_hora, pais, ativo } = parsed.data;

  try {
    await pool.query(
      'UPDATE operadores SET nome=?, cargo=?, categoria_sindical=?, custo_hora=?, pais=?, ativo=? WHERE id=?',
      [nome.trim(), cargo, categoria_sindical, Number(custo_hora), pais || null, toDbAtivo(ativo), req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.delete('/pessoas/:id', soGestor, async (req, res) => {
  return res.status(403).json({
    erro: 'Não é permitido apagar trabalhadores. Marque o trabalhador como inativo para preservar os gráficos e histórico.',
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MÁQUINAS
// ═══════════════════════════════════════════════════════════════════════════

router.get('/maquinas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('maquinas', 'nome', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// POST — requires soGestor (was missing before)
router.post('/maquinas', soGestor, async (req, res) => {
  const parsed = schemaMaquina.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { nome, tipo, matricula, custo_hora, combustivel_hora, ativo } = parsed.data;

  try {
    const [result] = await pool.query(
      'INSERT INTO maquinas (nome, tipo, matricula, custo_hora, combustivel_hora, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [nome.trim(), tipo, matricula, Number(custo_hora), Number(combustivel_hora ?? 0), toDbAtivo(ativo)]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.put('/maquinas/:id', soGestor, async (req, res) => {
  const parsed = schemaMaquina.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { nome, tipo, matricula, custo_hora, combustivel_hora, ativo } = parsed.data;

  try {
    await pool.query(
      'UPDATE maquinas SET nome=?, tipo=?, matricula=?, custo_hora=?, combustivel_hora=?, ativo=? WHERE id=?',
      [nome.trim(), tipo, matricula, Number(custo_hora), Number(combustivel_hora ?? 0), toDbAtivo(ativo), req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.delete('/maquinas/:id', soGestor, async (req, res) => {
  return res.status(403).json({
    erro: 'Não é permitido apagar máquinas. Marque a máquina como inativa para preservar os gráficos e histórico.',
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// VIATURAS
// ═══════════════════════════════════════════════════════════════════════════

router.get('/viaturas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('viaturas', 'modelo', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// POST — requires soGestor (was missing before)
router.post('/viaturas', soGestor, async (req, res) => {
  const parsed = schemaViatura.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo } = parsed.data;

  try {
    const [result] = await pool.query(
      'INSERT INTO viaturas (modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [modelo.trim(), matricula, Number(custo_km), Number(consumo_l100km ?? 0), motorista_id, toDbAtivo(ativo)]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.put('/viaturas/:id', soGestor, async (req, res) => {
  const parsed = schemaViatura.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo } = parsed.data;

  try {
    await pool.query(
      'UPDATE viaturas SET modelo=?, matricula=?, custo_km=?, consumo_l100km=?, motorista_id=?, ativo=? WHERE id=?',
      [modelo.trim(), matricula, Number(custo_km), Number(consumo_l100km ?? 0), motorista_id, toDbAtivo(ativo), req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

router.delete('/viaturas/:id', soGestor, async (req, res) => {
  return res.status(403).json({
    erro: 'Não é permitido apagar viaturas. Marque a viatura como inativa para preservar os gráficos e histórico.',
  });
});

module.exports = router;
