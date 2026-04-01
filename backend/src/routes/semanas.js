const router = require('express').Router();
const pool = require('../db/pool');
const { auth } = require('../middleware/auth');

router.use(auth);

// GET /api/semanas?obra_id=X  — lista semanas de uma obra
router.get('/', async (req, res) => {
  const { obra_id } = req.query;
  if (!obra_id) return res.status(400).json({ erro: 'obra_id obrigatório' });

  try {
    const [semanas] = await pool.query(
      'SELECT * FROM semanas WHERE obra_id = ? ORDER BY numero_semana DESC',
      [obra_id]
    );
    res.json(semanas);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// GET /api/semanas/:id  — detalhe completo de uma semana (horas + gastos)
router.get('/:id', async (req, res) => {
  try {
    const [[semana]] = await pool.query('SELECT * FROM semanas WHERE id = ?', [req.params.id]);
    if (!semana) return res.status(404).json({ erro: 'Semana não encontrada' });

    const [horasPessoas]  = await pool.query('SELECT * FROM semana_pessoas  WHERE semana_id = ?', [req.params.id]);
    const [horasMaquinas] = await pool.query('SELECT * FROM semana_maquinas WHERE semana_id = ?', [req.params.id]);
    const [horasViaturas] = await pool.query('SELECT * FROM semana_viaturas WHERE semana_id = ?', [req.params.id]);

    res.json({ semana, horasPessoas, horasMaquinas, horasViaturas });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// POST /api/semanas  — criar semana (ou buscar semana anterior para copiar)
router.post('/', async (req, res) => {
  const { obra_id, numero_semana, data_inicio, data_fim, estado } = req.body;

  if (!obra_id || !numero_semana) {
    return res.status(400).json({ erro: 'obra_id e numero_semana obrigatórios' });
  }

  try {
    const [result] = await pool.query(
      `INSERT INTO semanas (obra_id, numero_semana, data_inicio, data_fim, estado)
       VALUES (?, ?, ?, ?, ?)`,
      [obra_id, numero_semana, data_inicio, data_fim, estado || 'aberta']
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// GET /api/semanas/:id/anterior  — devolve dados da semana anterior para copiar
router.get('/:id/anterior', async (req, res) => {
  try {
    const [[atual]] = await pool.query('SELECT * FROM semanas WHERE id = ?', [req.params.id]);
    if (!atual) return res.status(404).json({ erro: 'Semana não encontrada' });

    const [[anterior]] = await pool.query(
      'SELECT * FROM semanas WHERE obra_id = ? AND numero_semana = ? LIMIT 1',
      [atual.obra_id, atual.numero_semana - 1]
    );

    if (!anterior) return res.status(404).json({ erro: 'Não existe semana anterior' });

    const [horasPessoas]  = await pool.query('SELECT * FROM semana_pessoas  WHERE semana_id = ?', [anterior.id]);
    const [horasMaquinas] = await pool.query('SELECT * FROM semana_maquinas WHERE semana_id = ?', [anterior.id]);
    const [horasViaturas] = await pool.query('SELECT * FROM semana_viaturas WHERE semana_id = ?', [anterior.id]);

    res.json({ semana: anterior, horasPessoas, horasMaquinas, horasViaturas });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// PUT /api/semanas/:id  — guardar/atualizar gastos e horas da semana
router.put('/:id', async (req, res) => {
  const { estado, faturado, horasPessoas, horasMaquinas, horasViaturas } = req.body;
  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    // Atualiza cabeçalho da semana
    await conn.query(
      'UPDATE semanas SET estado=?, faturado=? WHERE id=?',
      [estado, faturado, req.params.id]
    );

    // Limpa e reinseere registos de horas de pessoas
    if (horasPessoas) {
      await conn.query('DELETE FROM semana_pessoas WHERE semana_id = ?', [req.params.id]);
      for (const p of horasPessoas) {
        await conn.query(
          'INSERT INTO semana_pessoas (semana_id, pessoa_id, horas_total, custo_total) VALUES (?, ?, ?, ?)',
          [req.params.id, p.pessoa_id, p.horas_total, p.custo_total]
        );
      }
    }

    // Horas de máquinas
    if (horasMaquinas) {
      await conn.query('DELETE FROM semana_maquinas WHERE semana_id = ?', [req.params.id]);
      for (const m of horasMaquinas) {
        await conn.query(
          'INSERT INTO semana_maquinas (semana_id, maquina_id, horas_total, combustivel_total) VALUES (?, ?, ?, ?)',
          [req.params.id, m.maquina_id, m.horas_total, m.combustivel_total]
        );
      }
    }

    // Horas de viaturas
    if (horasViaturas) {
      await conn.query('DELETE FROM semana_viaturas WHERE semana_id = ?', [req.params.id]);
      for (const v of horasViaturas) {
        await conn.query(
          'INSERT INTO semana_viaturas (semana_id, viatura_id, km_total, custo_total) VALUES (?, ?, ?, ?)',
          [req.params.id, v.viatura_id, v.km_total, v.custo_total]
        );
      }
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
