const router = require('express').Router();
const pool = require('../db/pool');
const { auth, soGestor } = require('../middleware/auth');

router.use(auth);

// ─── PESSOAS ──────────────────────────────────────────────────────────────────

// GET /api/equipa/pessoas
router.get('/pessoas', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM operadores ORDER BY nome');
    res.json(rows);
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// GET /api/equipa/pessoas/:id
router.get('/pessoas/:id', async (req, res) => {
  try {
    const [[row]] = await pool.query('SELECT * FROM operadores WHERE id = ?', [req.params.id]);
    if (!row) return res.status(404).json({ erro: 'Não encontrado' });
    res.json(row);
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// POST /api/equipa/pessoas
router.post('/pessoas', soGestor, async (req, res) => {
  const { nome, cargo, categoria_sindical, custo_hora, nif } = req.body;
  if (!nome) return res.status(400).json({ erro: 'Nome obrigatório' });

  try {
    const [result] = await pool.query(
      'INSERT INTO operadores (nome, cargo, categoria_sindical, custo_hora, nif) VALUES (?, ?, ?, ?, ?)',
      [nome, cargo, categoria_sindical, custo_hora, nif]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// PUT /api/equipa/pessoas/:id
router.put('/pessoas/:id', soGestor, async (req, res) => {
  const { nome, cargo, categoria_sindical, custo_hora, nif } = req.body;
  try {
    await pool.query(
      'UPDATE operadores SET nome=?, cargo=?, categoria_sindical=?, custo_hora=?, nif=? WHERE id=?',
      [nome, cargo, categoria_sindical, custo_hora, nif, req.params.id]
    );
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// DELETE /api/equipa/pessoas/:id
router.delete('/pessoas/:id', soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    // Deletar de ambas tabelas (dias e semanas para compatibilidade)
    await conn.query('DELETE FROM dia_pessoas WHERE pessoa_id = ?', [req.params.id]);
    await conn.query('DELETE FROM semana_pessoas WHERE pessoa_id = ?', [req.params.id]);
    await conn.query('UPDATE viaturas SET motorista_id = NULL WHERE motorista_id = ?', [req.params.id]);
    await conn.query('DELETE FROM operadores WHERE id = ?', [req.params.id]);
    await conn.commit();
    res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ erro: err.message });
  } finally {
    conn.release();
  }
});

// ─── MÁQUINAS ─────────────────────────────────────────────────────────────────

// GET /api/equipa/maquinas
router.get('/maquinas', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM maquinas ORDER BY nome');
    res.json(rows);
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// POST /api/equipa/maquinas
router.post('/maquinas', soGestor, async (req, res) => {
  const { nome, tipo, matricula, custo_hora, combustivel_hora } = req.body;
  if (!nome) return res.status(400).json({ erro: 'Nome obrigatório' });

  try {
    const [result] = await pool.query(
      'INSERT INTO maquinas (nome, tipo, matricula, custo_hora, combustivel_hora) VALUES (?, ?, ?, ?, ?)',
      [nome, tipo, matricula, custo_hora, combustivel_hora]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// PUT /api/equipa/maquinas/:id
router.put('/maquinas/:id', soGestor, async (req, res) => {
  const { nome, tipo, matricula, custo_hora, combustivel_hora } = req.body;
  try {
    await pool.query(
      'UPDATE maquinas SET nome=?, tipo=?, matricula=?, custo_hora=?, combustivel_hora=? WHERE id=?',
      [nome, tipo, matricula, custo_hora, combustivel_hora, req.params.id]
    );
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// DELETE /api/equipa/maquinas/:id
router.delete('/maquinas/:id', soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    // Deletar de ambas tabelas (dias e semanas para compatibilidade)
    await conn.query('DELETE FROM dia_maquinas WHERE maquina_id = ?', [req.params.id]);
    await conn.query('DELETE FROM semana_maquinas WHERE maquina_id = ?', [req.params.id]);
    await conn.query('DELETE FROM maquinas WHERE id = ?', [req.params.id]);
    await conn.commit();
    res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ erro: err.message });
  } finally {
    conn.release();
  }
});

// ─── VIATURAS ─────────────────────────────────────────────────────────────────

// GET /api/equipa/viaturas
router.get('/viaturas', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM viaturas ORDER BY modelo');
    res.json(rows);
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// POST /api/equipa/viaturas
router.post('/viaturas', soGestor, async (req, res) => {
  const { modelo, matricula, custo_km, consumo_l100km, motorista_id } = req.body;
  if (!modelo) return res.status(400).json({ erro: 'Modelo obrigatório' });

  try {
    const [result] = await pool.query(
      'INSERT INTO viaturas (modelo, matricula, custo_km, consumo_l100km, motorista_id) VALUES (?, ?, ?, ?, ?)',
      [modelo, matricula, custo_km, consumo_l100km, motorista_id]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// PUT /api/equipa/viaturas/:id
router.put('/viaturas/:id', soGestor, async (req, res) => {
  const { modelo, matricula, custo_km, consumo_l100km, motorista_id } = req.body;
  try {
    await pool.query(
      'UPDATE viaturas SET modelo=?, matricula=?, custo_km=?, consumo_l100km=?, motorista_id=? WHERE id=?',
      [modelo, matricula, custo_km, consumo_l100km, motorista_id, req.params.id]
    );
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ erro: err.message }); }
});

// DELETE /api/equipa/viaturas/:id
router.delete('/viaturas/:id', soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    // Deletar de ambas tabelas (dias e semanas para compatibilidade)
    await conn.query('DELETE FROM dia_viaturas WHERE viatura_id = ?', [req.params.id]);
    await conn.query('DELETE FROM semana_viaturas WHERE viatura_id = ?', [req.params.id]);
    await conn.query('DELETE FROM viaturas WHERE id = ?', [req.params.id]);
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
