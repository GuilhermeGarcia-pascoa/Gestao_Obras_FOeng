const express = require('express');
const pool = require('../db/pool');
const { auth } = require('../middleware/auth');

const router = express.Router();
router.use(auth);

// ── GET /api/dias/anteriores?obra_id=X&mes=YYYY-MM
router.get('/anteriores', async (req, res) => {
  const { obra_id, mes } = req.query;
  if (!obra_id || !mes) return res.status(400).json({ erro: 'obra_id e mes obrigatórios' });
  try {
    const [rows] = await pool.query(
      "SELECT DATE_FORMAT(data, '%Y-%m-%d') as data, faturado FROM dias WHERE obra_id = ? AND DATE_FORMAT(data, '%Y-%m') = ? ORDER BY data",
      [obra_id, mes]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ── GET /api/dias/lista?obra_id=X
// Lista todos os dias com dados de uma obra (para o picker "copiar de dia")
router.get('/lista', async (req, res) => {
  const { obra_id } = req.query;
  if (!obra_id) return res.status(400).json({ erro: 'obra_id obrigatório' });
  try {
    const [rows] = await pool.query(
      "SELECT id, DATE_FORMAT(data, '%Y-%m-%d') as data, faturado FROM dias WHERE obra_id = ? ORDER BY data DESC",
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
// Devolve dados do dia com registo mais recente antes deste (para copiar)
router.get('/:id/anterior', async (req, res) => {
  try {
    const [[atual]] = await pool.query('SELECT * FROM dias WHERE id = ?', [req.params.id]);
    if (!atual) return res.status(404).json({ erro: 'Dia não encontrado' });
    const [[anterior]] = await pool.query(
      'SELECT * FROM dias WHERE obra_id = ? AND data < ? ORDER BY data DESC LIMIT 1',
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
// Copia dados de um dia específico escolhido pelo utilizador
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
// Guarda/atualiza os dados de um dia (inclui custo_extra por pessoa e refeições)
router.put('/:id', async (req, res) => {
  const { estado, faturado, horasPessoas, horasMaquinas, horasViaturas, gastos } = req.body;
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

    // Pessoas — guarda custo_extra por pessoa (custo variável no dia)
    if (horasPessoas !== undefined) {
      await conn.query('DELETE FROM dia_pessoas WHERE dia_id = ?', [req.params.id]);
      for (const p of horasPessoas || []) {
        await conn.query(
          'INSERT INTO dia_pessoas (dia_id, pessoa_id, horas_total, custo_total, custo_extra) VALUES (?, ?, ?, ?, ?)',
          [req.params.id, p.pessoa_id, p.horas_total, p.custo_total, p.custo_extra ?? 0]
        );
      }
    }

    // Máquinas
    if (horasMaquinas !== undefined) {
      await conn.query('DELETE FROM dia_maquinas WHERE dia_id = ?', [req.params.id]);
      for (const m of horasMaquinas || []) {
        await conn.query(
          'INSERT INTO dia_maquinas (dia_id, maquina_id, horas_total, combustivel_total) VALUES (?, ?, ?, ?)',
          [req.params.id, m.maquina_id, m.horas_total, m.combustivel_total]
        );
      }
    }

    // Viaturas
    if (horasViaturas !== undefined) {
      await conn.query('DELETE FROM dia_viaturas WHERE dia_id = ?', [req.params.id]);
      for (const v of horasViaturas || []) {
        await conn.query(
          'INSERT INTO dia_viaturas (dia_id, viatura_id, km_total, custo_total) VALUES (?, ?, ?, ?)',
          [req.params.id, v.viatura_id, v.km_total, v.custo_total]
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
