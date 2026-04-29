const router = require('express').Router();
const { z }  = require('zod');
const multer = require('multer');
const ExcelJS = require('exceljs');
const pool   = require('../db/pool');
const { auth, soGestor, soAdmin } = require('../middleware/auth');
const { logAction, reqMeta } = require('../utils/logger');

// Multer para ficheiros em memória
const upload = multer({ storage: multer.memoryStorage() });

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

// ── POST /api/obras/:id/import-excel ───────────────────────────────────────
router.post('/:id/import-excel', upload.single('file'), soGestor, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const obraId = parseInt(req.params.id);
    const { ano, mes } = req.query;

    // Validações
    if (!ano || !mes || !req.file) {
      return res.status(400).json({ erro: 'Ficheiro, ano e mês são obrigatórios' });
    }

    const anoNum = parseInt(ano);
    const mesNum = parseInt(mes);

    if (anoNum < 2020 || anoNum > 2100 || mesNum < 1 || mesNum > 12) {
      return res.status(400).json({ erro: 'Ano ou mês inválido' });
    }

    // Verifica se obra existe
    const [[obra]] = await conn.query('SELECT id FROM obras WHERE id = ?', [obraId]);
    if (!obra) {
      return res.status(404).json({ erro: 'Obra não encontrada' });
    }

    // Processa Excel
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(req.file.buffer);

    await conn.beginTransaction();

    const resumo = {
      dias_importados: 0,
      dias_atualizados: 0,
      pessoas_criadas: 0,
      maquinas_criadas: 0,
      viaturas_criadas: 0,
      erros: []
    };

    // Processa a primeira worksheet (Dias)
    const wsData = workbook.getWorksheet(1);
    if (!wsData) {
      await conn.rollback();
      return res.status(400).json({ erro: 'Ficheiro Excel inválido (sem dados)' });
    }

    // Estrutura esperada: Data, Estado, Valor T&O, Combustível, Estadias, Materiais, Refeições
    const rowsData = wsData.getRows(2, wsData.rowCount - 1) || [];

    for (const row of rowsData) {
      try {
        const data = row.getCell('A').value; // Data
        const estado = row.getCell('B').value || null;
        const valorTO = parseFloat(row.getCell('C').value) || 0;
        const combustivel = parseFloat(row.getCell('D').value) || 0;
        const estadias = parseFloat(row.getCell('E').value) || 0;
        const materiais = parseFloat(row.getCell('F').value) || 0;
        const refeicoes = parseFloat(row.getCell('G').value) || 0;

        if (!data) continue; // Salta linhas vazias

        // Trata data (pode ser Date ou string)
        let dataFormatada;
        if (data instanceof Date) {
          dataFormatada = data.toISOString().split('T')[0];
        } else {
          dataFormatada = new Date(data).toISOString().split('T')[0];
        }

        // Verifica se dia já existe
        const [[diaExistente]] = await conn.query(
          'SELECT id FROM dias WHERE obra_id = ? AND data = ?',
          [obraId, dataFormatada]
        );

        if (diaExistente) {
          // Atualiza
          await conn.query(
            `UPDATE dias 
             SET estado = ?, valor_to = ?, valor_combustivel = ?, 
                 valor_estadias = ?, valor_materiais = ?, valor_refeicoes = ?
             WHERE id = ?`,
            [estado, valorTO, combustivel, estadias, materiais, refeicoes, diaExistente.id]
          );
          resumo.dias_atualizados++;
        } else {
          // Insere novo
          const faturado = 0; // Padrão
          await conn.query(
            `INSERT INTO dias (obra_id, data, estado, faturado, valor_to, valor_combustivel, 
                               valor_estadias, valor_materiais, valor_refeicoes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [obraId, dataFormatada, estado, faturado, valorTO, combustivel, estadias, materiais, refeicoes]
          );
          resumo.dias_importados++;
        }
      } catch (err) {
        resumo.erros.push(`Erro na linha ${row.number}: ${err.message}`);
      }
    }

    // Processa pessoas (worksheet 2)
    const wsPessoas = workbook.getWorksheet(2);
    if (wsPessoas) {
      const rowsPessoas = wsPessoas.getRows(2, wsPessoas.rowCount - 1) || [];
      
      for (const row of rowsPessoas) {
        try {
          const nome = row.getCell('A').value;
          const cargo = row.getCell('B').value || null;

          if (!nome) continue;

          // Verifica se pessoa já existe
          const [[pessoaExistente]] = await conn.query(
            'SELECT id FROM operadores WHERE nome = ?',
            [nome]
          );

          if (!pessoaExistente) {
            await conn.query(
              'INSERT INTO operadores (nome, cargo) VALUES (?, ?)',
              [nome, cargo]
            );
            resumo.pessoas_criadas++;
          }
        } catch (err) {
          resumo.erros.push(`Erro na pessoa (linha ${row.number}): ${err.message}`);
        }
      }
    }

    // Processa máquinas (worksheet 3)
    const wsMaquinas = workbook.getWorksheet(3);
    if (wsMaquinas) {
      const rowsMaquinas = wsMaquinas.getRows(2, wsMaquinas.rowCount - 1) || [];
      
      for (const row of rowsMaquinas) {
        try {
          const nome = row.getCell('A').value;
          const tipo = row.getCell('B').value || null;
          const matricula = row.getCell('C').value || null;

          if (!nome) continue;

          const [[maquinaExistente]] = await conn.query(
            'SELECT id FROM maquinas WHERE nome = ?',
            [nome]
          );

          if (!maquinaExistente) {
            await conn.query(
              'INSERT INTO maquinas (nome, tipo, matricula) VALUES (?, ?, ?)',
              [nome, tipo, matricula]
            );
            resumo.maquinas_criadas++;
          }
        } catch (err) {
          resumo.erros.push(`Erro na máquina (linha ${row.number}): ${err.message}`);
        }
      }
    }

    // Processa viaturas (worksheet 4)
    const wsViaturas = workbook.getWorksheet(4);
    if (wsViaturas) {
      const rowsViaturas = wsViaturas.getRows(2, wsViaturas.rowCount - 1) || [];
      
      for (const row of rowsViaturas) {
        try {
          const modelo = row.getCell('A').value;
          const matricula = row.getCell('B').value || null;

          if (!modelo) continue;

          const [[viaturaExistente]] = await conn.query(
            'SELECT id FROM viaturas WHERE modelo = ?',
            [modelo]
          );

          if (!viaturaExistente) {
            await conn.query(
              'INSERT INTO viaturas (modelo, matricula) VALUES (?, ?)',
              [modelo, matricula]
            );
            resumo.viaturas_criadas++;
          }
        } catch (err) {
          resumo.erros.push(`Erro na viatura (linha ${row.number}): ${err.message}`);
        }
      }
    }

    await conn.commit();

    await logAction({
      userId:   req.user.id,
      action:   'IMPORT',
      entity:   'obras',
      entityId: obraId,
      details:  { ano: anoNum, mes: mesNum, ...resumo },
      ...reqMeta(req),
    });

    res.json({ 
      ok: true, 
      resumo 
    });
  } catch (err) {
    await conn.rollback();
    console.error('[IMPORT] Erro:', err);
    res.status(500).json({ erro: 'Erro ao importar ficheiro: ' + err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
