const router = require('express').Router();
const { z }  = require('zod');
const pool   = require('../db/pool');
const { auth, soGestor, soAdmin } = require('../middleware/auth');
const { logAction, reqMeta } = require('../utils/logger');

router.use(auth);

// ── Schemas Zod ────────────────────────────────────────────────────────────
const schemaObra = z.object({
  codigo:    z.string().min(3, 'Código deve ter pelo menos 3 caracteres'),
  nome:      z.string().min(3, 'Nome deve ter pelo menos 3 caracteres'),
  tipo:      z.string().optional().nullable(),
  estado:    z.string().optional().nullable(),
  orcamento: z.preprocess(
    (v) => (v === '' || v === null || v === undefined ? null : Number(v)),
    z.number().min(0, 'Orçamento inválido').nullable().optional()
  ),
});

function parseNumeroNaoNegativo(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

async function getObrasColumns() {
  const [rows] = await pool.query(
    `SELECT COLUMN_NAME
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'obras'`
  );
  return new Set(rows.map((row) => row.COLUMN_NAME));
}

function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value === null || value === undefined || value === '') return [];
  return [value];
}

// ── GET /api/obras ─────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const {
      estado,
      dataInicio,
      dataFim,
      orcamentoMin,
      orcamentoMax,
    } = req.query;
    const tipos = asArray(req.query.tipo)
      .map((tipo) => String(tipo).trim())
      .filter(Boolean);
    const columns = await getObrasColumns();
    let sql = 'SELECT * FROM obras WHERE 1=1';
    const params = [];

    if (estado) {
      sql += ' AND estado = ?';
      params.push(estado);
    }

    if (tipos.length) {
      sql += ` AND tipo IN (${tipos.map(() => '?').join(', ')})`;
      params.push(...tipos);
    }

    if (columns.has('data_inicio') && dataInicio) {
      sql += ' AND data_inicio >= ?';
      params.push(dataInicio);
    }

    if (columns.has('data_fim') && dataFim) {
      sql += ' AND data_fim <= ?';
      params.push(dataFim);
    }

    const min = parseNumeroNaoNegativo(orcamentoMin);
    if (min !== null) {
      sql += ' AND COALESCE(orcamento, 0) >= ?';
      params.push(min);
    }

    const max = parseNumeroNaoNegativo(orcamentoMax);
    if (max !== null) {
      sql += ' AND COALESCE(orcamento, 0) <= ?';
      params.push(max);
    }

    sql += ' ORDER BY criado_em DESC';

    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── GET /api/obras/:id ─────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    const [[obra]] = await pool.query('SELECT * FROM obras WHERE id = ?', [req.params.id]);
    if (!obra) return res.status(404).json({ erro: 'Obra não encontrada' });
    res.json(obra);
  } catch (err) {
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── POST /api/obras ────────────────────────────────────────────────────────
router.post('/', soGestor, async (req, res) => {
  const parsed = schemaObra.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { codigo, nome, tipo, estado, orcamento } = parsed.data;

  try {
    const [result] = await pool.query(
      'INSERT INTO obras (codigo, nome, tipo, estado, orcamento, criado_por) VALUES (?, ?, ?, ?, ?, ?)',
      [
        codigo.trim(),
        nome.trim(),
        tipo || null,
        estado || 'planeada',
        parseNumeroNaoNegativo(orcamento),
        req.user.id,
      ]
    );

    await logAction({
      userId:   req.user.id,
      action:   'CREATE',
      entity:   'obras',
      entityId: result.insertId,
      details:  { codigo, nome, tipo, estado, orcamento },
      ...reqMeta(req),
    });

    res.status(201).json({ id: result.insertId, codigo, nome });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Código já existe' });
    }
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── PUT /api/obras/:id ─────────────────────────────────────────────────────
router.put('/:id', soGestor, async (req, res) => {
  const parsed = schemaObra.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ erro: parsed.error.errors[0].message });
  }

  const { codigo, nome, tipo, estado, orcamento } = parsed.data;

  try {
    const [[obra]] = await pool.query('SELECT id FROM obras WHERE id = ?', [req.params.id]);
    if (!obra) return res.status(404).json({ erro: 'Obra não encontrada' });

    const [result] = await pool.query(
      'UPDATE obras SET codigo=?, nome=?, tipo=?, estado=?, orcamento=? WHERE id=?',
      [
        codigo.trim(),
        nome.trim(),
        tipo,
        estado,
        parseNumeroNaoNegativo(orcamento),
        req.params.id,
      ]
    );

    if (result.affectedRows === 0) return res.status(404).json({ erro: 'Obra não encontrada' });

    await logAction({
      userId:   req.user.id,
      action:   'UPDATE',
      entity:   'obras',
      entityId: parseInt(req.params.id),
      details:  { codigo, nome, tipo, estado, orcamento },
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Código já existe' });
    }
    res.status(500).json({ erro: 'Erro interno no servidor' });
  }
});

// ── DELETE /api/obras/:id ──────────────────────────────────────────────────
router.delete('/:id', soAdmin, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [[obra]] = await conn.query('SELECT id, codigo, nome FROM obras WHERE id = ?', [req.params.id]);
    if (!obra) {
      await conn.rollback();
      return res.status(404).json({ erro: 'Obra não encontrada' });
    }

    await conn.query(
      'DELETE dp FROM dia_pessoas dp JOIN dias d ON d.id = dp.dia_id WHERE d.obra_id = ?',
      [req.params.id]
    );
    await conn.query(
      'DELETE dm FROM dia_maquinas dm JOIN dias d ON d.id = dm.dia_id WHERE d.obra_id = ?',
      [req.params.id]
    );
    await conn.query(
      'DELETE dv FROM dia_viaturas dv JOIN dias d ON d.id = dv.dia_id WHERE d.obra_id = ?',
      [req.params.id]
    );
    await conn.query('DELETE FROM dias WHERE obra_id = ?', [req.params.id]);
    await conn.query('DELETE FROM obras WHERE id = ?', [req.params.id]);

    await conn.commit();

    await logAction({
      userId:   req.user.id,
      action:   'DELETE',
      entity:   'obras',
      entityId: parseInt(req.params.id),
      details:  { codigo: obra.codigo, nome: obra.nome },
      ...reqMeta(req),
    });

    res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ erro: 'Erro interno no servidor' });
  } finally {
    conn.release();
  }
});

module.exports = router;
