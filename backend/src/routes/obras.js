const router = require('express').Router();
const pool = require('../db/pool');
const { auth, soGestor } = require('../middleware/auth');

router.use(auth);

function parseNumeroNaoNegativo(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

function validarObra(body) {
  if (!body.codigo || !String(body.codigo).trim()) return 'Código é obrigatório';
  if (!body.nome || !String(body.nome).trim()) return 'Nome é obrigatório';
  if (String(body.codigo).trim().length < 3) return 'Código demasiado curto';
  if (String(body.nome).trim().length < 3) return 'Nome demasiado curto';
  if (body.orcamento !== null && body.orcamento !== undefined && body.orcamento !== '' && parseNumeroNaoNegativo(body.orcamento) == null) {
    return 'Orçamento inválido';
  }
  return null;
}

router.get('/', async (req, res) => {
  const { estado, tipo } = req.query;
  let sql = 'SELECT * FROM obras WHERE 1=1';
  const params = [];

  if (estado) {
    sql += ' AND estado = ?';
    params.push(estado);
  }
  if (tipo) {
    sql += ' AND tipo = ?';
    params.push(tipo);
  }

  sql += ' ORDER BY criado_em DESC';

  try {
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const [[obra]] = await pool.query('SELECT * FROM obras WHERE id = ?', [req.params.id]);
    if (!obra) return res.status(404).json({ erro: 'Obra não encontrada' });
    res.json(obra);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.post('/', soGestor, async (req, res) => {
  const { codigo, nome, tipo, estado, orcamento } = req.body;
  const erro = validarObra(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    const [result] = await pool.query(
      'INSERT INTO obras (codigo, nome, tipo, estado, orcamento, criado_por) VALUES (?, ?, ?, ?, ?, ?)',
      [String(codigo).trim(), String(nome).trim(), tipo || null, estado || 'planeada', parseNumeroNaoNegativo(orcamento), req.user.id]
    );
    res.status(201).json({ id: result.insertId, codigo, nome });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Código já existe' });
    }
    res.status(500).json({ erro: err.message });
  }
});

router.put('/:id', soGestor, async (req, res) => {
  const { codigo, nome, tipo, estado, orcamento } = req.body;
  const erro = validarObra(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    const [result] = await pool.query(
      'UPDATE obras SET codigo=?, nome=?, tipo=?, estado=?, orcamento=? WHERE id=?',
      [String(codigo).trim(), String(nome).trim(), tipo, estado, parseNumeroNaoNegativo(orcamento), req.params.id]
    );

    if (result.affectedRows === 0) return res.status(404).json({ erro: 'Obra não encontrada' });
    res.json({ ok: true });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Código já existe' });
    }
    res.status(500).json({ erro: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).json({ erro: 'Sem permissão' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

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

    const [result] = await conn.query('DELETE FROM obras WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({ erro: 'Obra não encontrada' });
    }

    await conn.commit();
    res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ erro: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
