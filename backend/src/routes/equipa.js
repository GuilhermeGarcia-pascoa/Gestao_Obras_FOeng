const router = require('express').Router();
const pool = require('../db/pool');
const { auth, soGestor } = require('../middleware/auth');

router.use(auth);

function toDbAtivo(value) {
  return value === false || value === 0 || value === '0' ? 0 : 1;
}

function parseNumeroNaoNegativo(value) {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

function validarTextoObrigatorio(value, campo) {
  return value && String(value).trim() ? null : `${campo} obrigatório`;
}

function validarPessoa(body) {
  const erroNome = validarTextoObrigatorio(body.nome, 'Nome');
  if (erroNome) return erroNome;
  if (parseNumeroNaoNegativo(body.custo_hora) == null) return 'Custo por hora inválido';
  return null;
}

function validarMaquina(body) {
  const erroNome = validarTextoObrigatorio(body.nome, 'Nome');
  if (erroNome) return erroNome;
  if (parseNumeroNaoNegativo(body.custo_hora) == null) return 'Custo por hora inválido';
  if (parseNumeroNaoNegativo(body.combustivel_hora ?? 0) == null) return 'Combustível por hora inválido';
  return null;
}

function validarViatura(body) {
  const erroModelo = validarTextoObrigatorio(body.modelo, 'Modelo');
  if (erroModelo) return erroModelo;
  if (parseNumeroNaoNegativo(body.custo_km) == null) return 'Custo por km inválido';
  if (parseNumeroNaoNegativo(body.consumo_l100km ?? 0) == null) return 'Consumo inválido';
  return null;
}

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

router.get('/pessoas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('operadores', 'nome', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.get('/pessoas/:id', async (req, res) => {
  try {
    const [[row]] = await pool.query('SELECT * FROM operadores WHERE id = ?', [req.params.id]);
    if (!row) return res.status(404).json({ erro: 'Não encontrado' });
    res.json(row);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.post('/pessoas', async (req, res) => {
  const { nome, cargo, categoria_sindical, custo_hora, pais, ativo } = req.body;
  const erro = validarPessoa(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    const [result] = await pool.query(
      'INSERT INTO operadores (nome, cargo, categoria_sindical, custo_hora, pais, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [String(nome).trim(), cargo, categoria_sindical, Number(custo_hora), pais || null, toDbAtivo(ativo)]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.put('/pessoas/:id', soGestor, async (req, res) => {
  const { nome, cargo, categoria_sindical, custo_hora, pais, ativo } = req.body;
  const erro = validarPessoa(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    await pool.query(
      'UPDATE operadores SET nome=?, cargo=?, categoria_sindical=?, custo_hora=?, pais=?, ativo=? WHERE id=?',
      [String(nome).trim(), cargo, categoria_sindical, Number(custo_hora), pais || null, toDbAtivo(ativo), req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.delete('/pessoas/:id', soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
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

router.get('/maquinas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('maquinas', 'nome', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.post('/maquinas', async (req, res) => {
  const { nome, tipo, matricula, custo_hora, combustivel_hora, ativo } = req.body;
  const erro = validarMaquina(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    const [result] = await pool.query(
      'INSERT INTO maquinas (nome, tipo, matricula, custo_hora, combustivel_hora, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [String(nome).trim(), tipo, matricula, Number(custo_hora), Number(combustivel_hora ?? 0), toDbAtivo(ativo)]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.put('/maquinas/:id', soGestor, async (req, res) => {
  const { nome, tipo, matricula, custo_hora, combustivel_hora, ativo } = req.body;
  const erro = validarMaquina(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    await pool.query(
      'UPDATE maquinas SET nome=?, tipo=?, matricula=?, custo_hora=?, combustivel_hora=?, ativo=? WHERE id=?',
      [String(nome).trim(), tipo, matricula, Number(custo_hora), Number(combustivel_hora ?? 0), toDbAtivo(ativo), req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.delete('/maquinas/:id', soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
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

router.get('/viaturas', async (req, res) => {
  try {
    const { estado = 'ativas' } = req.query;
    const [rows] = await pool.query(sqlEstado('viaturas', 'modelo', estado));
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.post('/viaturas', async (req, res) => {
  const { modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo } = req.body;
  const erro = validarViatura(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    const [result] = await pool.query(
      'INSERT INTO viaturas (modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo) VALUES (?, ?, ?, ?, ?, ?)',
      [String(modelo).trim(), matricula, Number(custo_km), Number(consumo_l100km ?? 0), motorista_id, toDbAtivo(ativo)]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.put('/viaturas/:id', soGestor, async (req, res) => {
  const { modelo, matricula, custo_km, consumo_l100km, motorista_id, ativo } = req.body;
  const erro = validarViatura(req.body);
  if (erro) return res.status(400).json({ erro });

  try {
    await pool.query(
      'UPDATE viaturas SET modelo=?, matricula=?, custo_km=?, consumo_l100km=?, motorista_id=?, ativo=? WHERE id=?',
      [String(modelo).trim(), matricula, Number(custo_km), Number(consumo_l100km ?? 0), motorista_id, toDbAtivo(ativo), req.params.id]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

router.delete('/viaturas/:id', soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
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
