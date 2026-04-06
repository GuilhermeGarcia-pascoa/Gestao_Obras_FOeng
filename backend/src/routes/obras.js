const router = require('express').Router();
const pool = require('../db/pool');
const { auth, soGestor } = require('../middleware/auth');

// Todas as rotas precisam de login
router.use(auth);

// GET /api/obras  — lista obras (com filtros opcionais)
router.get('/', async (req, res) => {
  const { estado, tipo } = req.query;
  let sql = 'SELECT * FROM obras WHERE 1=1';
  const params = [];

  if (estado) { sql += ' AND estado = ?'; params.push(estado); }
  if (tipo)   { sql += ' AND tipo = ?';   params.push(tipo); }

  sql += ' ORDER BY criado_em DESC';

  try {
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// GET /api/obras/:id  — detalhe de uma obra
router.get('/:id', async (req, res) => {
  try {
    const [[obra]] = await pool.query('SELECT * FROM obras WHERE id = ?', [req.params.id]);
    if (!obra) return res.status(404).json({ erro: 'Obra não encontrada' });
    res.json(obra);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// POST /api/obras  — criar obra
router.post('/', soGestor, async (req, res) => {
  const { codigo, nome, tipo, estado, orcamento } = req.body;

  if (!codigo || !nome) {
    return res.status(400).json({ erro: 'Código e nome são obrigatórios' });
  }

  try {
    const [result] = await pool.query(
      'INSERT INTO obras (codigo, nome, tipo, estado, orcamento, criado_por) VALUES (?, ?, ?, ?, ?, ?)',
      [codigo, nome, tipo || null, estado || 'planeada', orcamento || null, req.user.id]
    );
    res.status(201).json({ id: result.insertId, codigo, nome });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Código já existe' });
    }
    res.status(500).json({ erro: err.message });
  }
});

// PUT /api/obras/:id  — editar obra
router.put('/:id', soGestor, async (req, res) => {
  const { codigo, nome, tipo, estado, orcamento } = req.body;

  try {
    const [result] = await pool.query(
      'UPDATE obras SET codigo=?, nome=?, tipo=?, estado=?, orcamento=? WHERE id=?',
      [codigo, nome, tipo, estado, orcamento, req.params.id]
    );

    if (result.affectedRows === 0) return res.status(404).json({ erro: 'Obra não encontrada' });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// DELETE /api/obras/:id  — só admins
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
