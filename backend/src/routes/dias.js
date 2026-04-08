const express = require('express');
const pool = require('../db/pool');
const { auth } = require('../middleware/auth');

const router = express.Router();
router.use(auth);

const DIA_COM_DADOS_SQL = `
(
  COALESCE(faturado, 0) > 0 OR
  COALESCE(valor_to, 0) > 0 OR
  COALESCE(valor_combustivel, 0) > 0 OR
  COALESCE(valor_estadias, 0) > 0 OR
  COALESCE(valor_materiais, 0) > 0 OR
  COALESCE(valor_refeicoes, 0) > 0 OR
  EXISTS (SELECT 1 FROM dia_pessoas dp WHERE dp.dia_id = dias.id) OR
  EXISTS (SELECT 1 FROM dia_maquinas dm WHERE dm.dia_id = dias.id) OR
  EXISTS (SELECT 1 FROM dia_viaturas dv WHERE dv.dia_id = dias.id)
)`;

function numeroNaoNegativo(value) {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

function numeroEntre(value, min, max) {
  const n = Number(value);
  return Number.isFinite(n) && n >= min && n <= max ? n : null;
}

function validarDia(payload) {
  if (numeroNaoNegativo(payload.faturado ?? 0) == null) return 'Faturado inválido';

  const gastos = payload.gastos ?? {};
  const camposGasto = [
    ['valor_to', 'Mão de obra'],
    ['valor_combustivel', 'Combustível'],
    ['valor_estadias', 'Estadias'],
    ['valor_materiais', 'Materiais'],
    ['valor_refeicoes', 'Refeições'],
  ];

  for (const [campo, label] of camposGasto) {
    if (numeroNaoNegativo(gastos[campo] ?? 0) == null) return `${label} inválido`;
  }

  for (const p of payload.horasPessoas || []) {
    if (!p.pessoa_id) return 'Pessoa inválida';
    if (numeroEntre(p.horas_total, 0, 24) == null) return 'Horas de pessoa têm de estar entre 0 e 24';
    if (numeroNaoNegativo(p.custo_total ?? 0) == null) return 'Custo total de pessoa inválido';
    if (numeroNaoNegativo(p.custo_extra ?? 0) == null) return 'Custo extra de pessoa inválido';
    if (p.custo_hora_override != null && numeroNaoNegativo(p.custo_hora_override) == null) return 'Custo/hora personalizado inválido';
    if (numeroNaoNegativo(p.custo_hora_snapshot ?? 0) == null) return 'Snapshot de custo/hora inválido';
  }

  for (const m of payload.horasMaquinas || []) {
    if (!m.maquina_id) return 'Máquina inválida';
    if (numeroEntre(m.horas_total, 0, 24) == null) return 'Horas de máquina têm de estar entre 0 e 24';
    if (numeroNaoNegativo(m.custo_total ?? 0) == null) return 'Custo total de máquina inválido';
    if (numeroNaoNegativo(m.combustivel_total ?? 0) == null) return 'Combustível total de máquina inválido';
    if (numeroNaoNegativo(m.custo_hora_snapshot ?? 0) == null) return 'Snapshot de custo/hora da máquina inválido';
    if (numeroNaoNegativo(m.combustivel_hora_snapshot ?? 0) == null) return 'Snapshot de combustível/hora inválido';
  }

  for (const v of payload.horasViaturas || []) {
    if (!v.viatura_id) return 'Viatura inválida';
    if (numeroEntre(v.km_total, 0, 2000) == null) return 'Quilómetros da viatura têm de estar entre 0 e 2000';
    if (numeroNaoNegativo(v.custo_total ?? 0) == null) return 'Custo total da viatura inválido';
    if (numeroNaoNegativo(v.custo_km_snapshot ?? 0) == null) return 'Snapshot de custo/km inválido';
  }

  return null;
}

// ── GET /api/dias/anteriores?obra_id=X&mes=YYYY-MM
router.get('/anteriores', async (req, res) => {
  const { obra_id, mes } = req.query;
  if (!obra_id || !mes) return res.status(400).json({ erro: 'obra_id e mes obrigatórios' });
  try {
    const [rows] = await pool.query(
      `SELECT DATE_FORMAT(data, '%Y-%m-%d') as data, faturado
       FROM dias
       WHERE obra_id = ? AND DATE_FORMAT(data, '%Y-%m') = ? AND ${DIA_COM_DADOS_SQL}
       ORDER BY data`,
      [obra_id, mes]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── GET /api/dias/lista?obra_id=X
router.get('/lista', async (req, res) => {
  const { obra_id } = req.query;
  if (!obra_id) return res.status(400).json({ erro: 'obra_id obrigatório' });
  try {
    const [rows] = await pool.query(
      `SELECT id, DATE_FORMAT(data, '%Y-%m-%d') as data, faturado
       FROM dias
       WHERE obra_id = ? AND ${DIA_COM_DADOS_SQL}
       ORDER BY data DESC`,
      [obra_id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── GET /api/dias/por-data?obra_id=X&data=YYYY-MM-DD
router.get('/por-data', async (req, res) => {
  const { obra_id, data } = req.query;
  if (!obra_id || !data) return res.status(400).json({ erro: 'obra_id e data obrigatórios' });
  try {
    let [[dia]] = await pool.query(
      'SELECT * FROM dias WHERE obra_id = ? AND data = ? LIMIT 1',
      [obra_id, data]
    );
    if (!dia) {
      const [result] = await pool.query(
        'INSERT INTO dias (obra_id, data, estado, faturado) VALUES (?, ?, "aberta", 0)',
        [obra_id, data]
      );
      [[dia]] = await pool.query('SELECT * FROM dias WHERE id = ?', [result.insertId]);
    }
    const [horasPessoas]  = await pool.query('SELECT * FROM dia_pessoas  WHERE dia_id = ?', [dia.id]);
    const [horasMaquinas] = await pool.query('SELECT * FROM dia_maquinas WHERE dia_id = ?', [dia.id]);
    const [horasViaturas] = await pool.query('SELECT * FROM dia_viaturas WHERE dia_id = ?', [dia.id]);
    res.json({ dia, horasPessoas, horasMaquinas, horasViaturas });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── GET /api/dias/:id
router.get('/:id', async (req, res) => {
  try {
    const [[dia]] = await pool.query('SELECT * FROM dias WHERE id = ?', [req.params.id]);
    if (!dia) return res.status(404).json({ erro: 'Dia não encontrado' });
    const [horasPessoas]  = await pool.query('SELECT * FROM dia_pessoas  WHERE dia_id = ?', [dia.id]);
    const [horasMaquinas] = await pool.query('SELECT * FROM dia_maquinas WHERE dia_id = ?', [dia.id]);
    const [horasViaturas] = await pool.query('SELECT * FROM dia_viaturas WHERE dia_id = ?', [dia.id]);
    res.json({ dia, horasPessoas, horasMaquinas, horasViaturas });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── GET /api/dias/:id/anterior
router.get('/:id/anterior', async (req, res) => {
  try {
    const [[atual]] = await pool.query('SELECT * FROM dias WHERE id = ?', [req.params.id]);
    if (!atual) return res.status(404).json({ erro: 'Dia não encontrado' });
    const [[anterior]] = await pool.query(
      `SELECT *
       FROM dias
       WHERE obra_id = ? AND data < ? AND ${DIA_COM_DADOS_SQL}
       ORDER BY data DESC
       LIMIT 1`,
      [atual.obra_id, atual.data]
    );
    if (!anterior) return res.status(404).json({ erro: 'Não existe dia anterior com dados' });

    const [horasPessoas]  = await pool.query('SELECT * FROM dia_pessoas  WHERE dia_id = ?', [anterior.id]);
    const [horasMaquinas] = await pool.query('SELECT * FROM dia_maquinas WHERE dia_id = ?', [anterior.id]);
    const [horasViaturas] = await pool.query('SELECT * FROM dia_viaturas WHERE dia_id = ?', [anterior.id]);

    res.json({
      horasPessoas,
      horasMaquinas,
      horasViaturas,
      gastos: {
        valor_to:          anterior.valor_to          || 0,
        valor_combustivel: anterior.valor_combustivel || 0,
        valor_estadias:    anterior.valor_estadias    || 0,
        valor_materiais:   anterior.valor_materiais   || 0,
        valor_refeicoes:   anterior.valor_refeicoes   || 0,
      }
    });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── GET /api/dias/:id/copiar-de?fonte_id=Y
router.get('/:id/copiar-de', async (req, res) => {
  const { fonte_id } = req.query;
  if (!fonte_id) return res.status(400).json({ erro: 'fonte_id obrigatório' });
  try {
    const [[fonte]] = await pool.query('SELECT * FROM dias WHERE id = ?', [fonte_id]);
    if (!fonte) return res.status(404).json({ erro: 'Dia fonte não encontrado' });

    const [horasPessoas]  = await pool.query('SELECT * FROM dia_pessoas  WHERE dia_id = ?', [fonte_id]);
    const [horasMaquinas] = await pool.query('SELECT * FROM dia_maquinas WHERE dia_id = ?', [fonte_id]);
    const [horasViaturas] = await pool.query('SELECT * FROM dia_viaturas WHERE dia_id = ?', [fonte_id]);

    res.json({
      horasPessoas,
      horasMaquinas,
      horasViaturas,
      gastos: {
        valor_to:          fonte.valor_to          || 0,
        valor_combustivel: fonte.valor_combustivel || 0,
        valor_estadias:    fonte.valor_estadias    || 0,
        valor_materiais:   fonte.valor_materiais   || 0,
        valor_refeicoes:   fonte.valor_refeicoes   || 0,
      }
    });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── PUT /api/dias/:id
router.put('/:id', async (req, res) => {
  const { estado, faturado, horasPessoas, horasMaquinas, horasViaturas, gastos } = req.body;
  const erro = validarDia(req.body);
  if (erro) return res.status(400).json({ erro });
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query(
      `UPDATE dias SET
         estado = ?, faturado = ?,
         valor_to = ?, valor_combustivel = ?, valor_estadias = ?,
         valor_materiais = ?, valor_refeicoes = ?
       WHERE id = ?`,
      [
        estado,
        faturado,
        gastos?.valor_to          ?? 0,
        gastos?.valor_combustivel ?? 0,
        gastos?.valor_estadias    ?? 0,
        gastos?.valor_materiais   ?? 0,
        gastos?.valor_refeicoes   ?? 0,
        req.params.id
      ]
    );

    // Pessoas — guarda custo_extra e custo_hora_override por pessoa
    if (horasPessoas !== undefined) {
      await conn.query('DELETE FROM dia_pessoas WHERE dia_id = ?', [req.params.id]);
      for (const p of horasPessoas || []) {
        await conn.query(
          `INSERT INTO dia_pessoas
             (dia_id, pessoa_id, horas_total, custo_total, custo_extra, custo_hora_override, custo_hora_snapshot)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            req.params.id,
            p.pessoa_id,
            p.horas_total,
            p.custo_total,
            p.custo_extra ?? 0,
            p.custo_hora_override ?? null,
            p.custo_hora_snapshot ?? p.custo_hora_override ?? null,
          ]
        );
      }
    }

    // Máquinas
    if (horasMaquinas !== undefined) {
      await conn.query('DELETE FROM dia_maquinas WHERE dia_id = ?', [req.params.id]);
      for (const m of horasMaquinas || []) {
        await conn.query(
          `INSERT INTO dia_maquinas
             (dia_id, maquina_id, horas_total, custo_total, combustivel_total, custo_hora_snapshot, combustivel_hora_snapshot)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [req.params.id, m.maquina_id, m.horas_total, m.custo_total ?? 0, m.combustivel_total ?? 0, m.custo_hora_snapshot ?? null, m.combustivel_hora_snapshot ?? null]
        );
      }
    }

    // Viaturas
    if (horasViaturas !== undefined) {
      await conn.query('DELETE FROM dia_viaturas WHERE dia_id = ?', [req.params.id]);
      for (const v of horasViaturas || []) {
        await conn.query(
          'INSERT INTO dia_viaturas (dia_id, viatura_id, km_total, custo_total, custo_km_snapshot) VALUES (?, ?, ?, ?, ?)',
          [req.params.id, v.viatura_id, v.km_total, v.custo_total, v.custo_km_snapshot ?? null]
        );
      }
    }

    await conn.commit();
    res.json({ mensagem: 'Dia guardado com sucesso' });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ erro: err.message });
  } finally {
    conn.release();
  }
});

// ── DELETE /api/dias/:id
router.delete('/:id', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query('DELETE FROM dia_pessoas  WHERE dia_id = ?', [req.params.id]);
    await conn.query('DELETE FROM dia_maquinas WHERE dia_id = ?', [req.params.id]);
    await conn.query('DELETE FROM dia_viaturas WHERE dia_id = ?', [req.params.id]);
    const [result] = await conn.query('DELETE FROM dias WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({ erro: 'Dia não encontrado' });
    }
    await conn.commit();
    res.json({ mensagem: 'Dia eliminado com sucesso' });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ erro: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
