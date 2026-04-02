const router = require('express').Router();
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const pool = require('../db/pool');
const { auth } = require('../middleware/auth');

router.use(auth);

// ─── EXCEL ────────────────────────────────────────────────────────────────────
router.get('/excel/:obra_id', async (req, res) => {
  try {
    const [[obra]] = await pool.query('SELECT * FROM obras WHERE id = ?', [req.params.obra_id]);
    if (!obra) return res.status(404).json({ erro: 'Obra não encontrada' });

    const [dias] = await pool.query(
      'SELECT * FROM dias WHERE obra_id = ? ORDER BY data',
      [req.params.obra_id]
    );

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'ObrasApp';
    workbook.created = new Date();

    const resumo = workbook.addWorksheet('Resumo');
    resumo.columns = [
      { header: 'Data',       key: 'data',     width: 14 },
      { header: 'Estado',     key: 'estado',   width: 12 },
      { header: 'Faturado €', key: 'faturado', width: 14 },
    ];

    resumo.getRow(1).font = { bold: true };
    resumo.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1A1A2E' } };
    resumo.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };

    let totalFaturado = 0;
    for (const d of dias) {
      resumo.addRow({
        data:     d.data ? new Date(d.data).toLocaleDateString('pt-PT') : '',
        estado:   d.estado,
        faturado: Number(d.faturado) || 0,
      });
      totalFaturado += Number(d.faturado) || 0;
    }

    const totalRow = resumo.addRow(['', 'TOTAL', totalFaturado]);
    totalRow.font = { bold: true };

    for (const dia of dias) {
      const sheet = workbook.addWorksheet(new Date(dia.data).toLocaleDateString('pt-PT'));

      sheet.addRow([`Data: ${new Date(dia.data).toLocaleDateString('pt-PT')}`, `${obra.codigo} — ${obra.nome}`]);
      sheet.getRow(1).font = { bold: true, size: 12 };
      sheet.addRow([]);

      sheet.addRow(['Pessoas', 'Horas', 'Custo €']);
      sheet.getRow(3).font = { bold: true };

      const [pessoas] = await pool.query(
        `SELECT dp.*, o.nome FROM dia_pessoas dp
         JOIN operadores o ON o.id = dp.pessoa_id
         WHERE dp.dia_id = ?`,
        [dia.id]
      );
      for (const p of pessoas) {
        sheet.addRow([p.nome, p.horas_total, Number(p.custo_total)]);
      }

      sheet.addRow([]);
      sheet.addRow(['Máquinas', 'Horas', 'Combustível €']);
      sheet.getRow(sheet.lastRow.number).font = { bold: true };

      const [maquinas] = await pool.query(
        `SELECT dm.*, m.nome FROM dia_maquinas dm
         JOIN maquinas m ON m.id = dm.maquina_id
         WHERE dm.dia_id = ?`,
        [dia.id]
      );
      for (const m of maquinas) {
        sheet.addRow([m.nome, m.horas_total, Number(m.combustivel_total)]);
      }

      sheet.columns.forEach(col => { col.width = Math.max(col.width || 10, 16); });
    }

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=obra_${obra.codigo.replace(/\//g,'_')}.xlsx`);
    await workbook.xlsx.write(res);
    res.end();
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ─── PDF ──────────────────────────────────────────────────────────────────────
router.get('/pdf/:dia_id', async (req, res) => {
  try {
    const [[dia]] = await pool.query('SELECT * FROM dias WHERE id = ?', [req.params.dia_id]);
    if (!dia) return res.status(404).json({ erro: 'Dia não encontrado' });

    const [[obra]] = await pool.query('SELECT * FROM obras WHERE id = ?', [dia.obra_id]);

    const [pessoas] = await pool.query(
      `SELECT dp.*, o.nome FROM dia_pessoas dp
       JOIN operadores o ON o.id = dp.pessoa_id
       WHERE dp.dia_id = ?`,
      [req.params.dia_id]
    );

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=dia_${new Date(dia.data).toLocaleDateString('pt-PT')}.pdf`);
    doc.pipe(res);

    doc.fontSize(18).font('Helvetica-Bold').text(`${obra.codigo} — ${new Date(dia.data).toLocaleDateString('pt-PT')}`, { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(11).font('Helvetica').text(`Obra: ${obra.nome}`, { align: 'center' });
    doc.moveDown(1.5);

    doc.fontSize(13).font('Helvetica-Bold').text('Equipa — horas trabalhadas');
    doc.moveDown(0.5);
    doc.fontSize(11).font('Helvetica');

    for (const p of pessoas) {
      doc.text(`  ${p.nome}`, { continued: true, width: 300 });
      doc.text(`${p.horas_total}h`, { continued: true, width: 80, align: 'right' });
      doc.text(`€ ${Number(p.custo_total).toFixed(2)}`, { align: 'right' });
    }

    doc.moveDown(1);
    doc.fontSize(13).font('Helvetica-Bold').text('Resumo financeiro');
    doc.moveDown(0.5);
    doc.fontSize(11).font('Helvetica');
    doc.text(`Faturado:  € ${Number(dia.faturado || 0).toFixed(2)}`);

    doc.end();
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ─── GRÁFICOS ─────────────────────────────────────────────────────────────────
// GET /api/relatorios/graficos/:obra_id?dataInicio=2024-01-01&dataFim=2024-12-31
router.get('/graficos/:obra_id', async (req, res) => {
  try {
    const obraId = req.params.obra_id;
    const { dataInicio, dataFim } = req.query;

    // Filtro de datas opcional
    let filtroData = '';
    const params = [obraId];
    if (dataInicio && dataFim) {
      filtroData = ' AND data BETWEEN ? AND ?';
      params.push(dataInicio, dataFim);
    }

    // 1. Evolução diária
    const [dias] = await pool.query(
      `SELECT id, data, faturado, valor_to, valor_combustivel, valor_estadias, valor_materiais
       FROM dias WHERE obra_id = ?${filtroData} ORDER BY data`,
      params
    );

    let acumulado = 0;
    const evolucao = dias.map(d => {
      acumulado += Number(d.faturado) || 0;
      return {
        data:      new Date(d.data).toISOString().substring(0, 10),
        faturado:  Number(d.faturado)           || 0,
        acumulado,
      };
    });

    // 2. Métricas globais de pessoas
    const [metricasPessoas] = await pool.query(
      `SELECT 
         SUM(dp.horas_total) AS total_horas,
         SUM(dp.custo_total) AS total_custo,
         COUNT(DISTINCT dp.pessoa_id) AS total_pessoas
       FROM dia_pessoas dp
       JOIN dias d ON d.id = dp.dia_id
       WHERE d.obra_id = ?${filtroData.replace(/data/g, 'd.data')}`,
      params
    );

    // 3. Métricas globais de máquinas
    const [metricasMaquinas] = await pool.query(
      `SELECT
         SUM(dm.horas_total)       AS total_horas,
         SUM(dm.combustivel_total) AS total_combustivel,
         COUNT(DISTINCT dm.maquina_id) AS total_maquinas
       FROM dia_maquinas dm
       JOIN dias d ON d.id = dm.dia_id
       WHERE d.obra_id = ?${filtroData.replace(/data/g, 'd.data')}`,
      params
    );

    // 4. Métricas globais de viaturas
    const [metricasViaturas] = await pool.query(
      `SELECT
         SUM(dv.km_total)    AS total_km,
         SUM(dv.custo_total) AS total_custo,
         COUNT(DISTINCT dv.viatura_id) AS total_viaturas
       FROM dia_viaturas dv
       JOIN dias d ON d.id = dv.dia_id
       WHERE d.obra_id = ?${filtroData.replace(/data/g, 'd.data')}`,
      params
    );

    // 5. Distribuição de custos acumulada (todos os dias do filtro)
    const totalPessoal      = Number(metricasPessoas[0]?.total_custo)       || 0;
    const totalCombustivel  = Number(metricasMaquinas[0]?.total_combustivel) || 0;
    const totalViaturas     = Number(metricasViaturas[0]?.total_custo)       || 0;
    const totalTo           = dias.reduce((s, d) => s + (Number(d.valor_to)          || 0), 0);
    const totalEstadias     = dias.reduce((s, d) => s + (Number(d.valor_estadias)    || 0), 0);
    const totalMateriais    = dias.reduce((s, d) => s + (Number(d.valor_materiais)   || 0), 0);

    const distribuicao = [
      { categoria: 'Pessoal',     valor: totalPessoal     },
      { categoria: 'Combustível', valor: totalCombustivel },
      { categoria: 'Viaturas',    valor: totalViaturas    },
      { categoria: 'M.O.',        valor: totalTo          },
      { categoria: 'Estadias',    valor: totalEstadias    },
      { categoria: 'Materiais',   valor: totalMateriais   },
    ].filter(d => d.valor > 0);

    // 6. Comparação entre obras (top 5 por faturado)
    const [comparacao] = await pool.query(
      `SELECT o.codigo, o.nome,
              COALESCE(SUM(d.faturado), 0)          AS total_faturado,
              COUNT(d.id)                            AS total_dias,
              COALESCE(SUM(d.valor_materiais), 0)   AS total_materiais
       FROM obras o
       LEFT JOIN dias d ON d.obra_id = o.id
       GROUP BY o.id, o.codigo, o.nome
       ORDER BY total_faturado DESC
       LIMIT 5`
    );

    res.json({
      evolucao,
      distribuicao,
      metricas: {
        pessoas: {
          total_horas:   Number(metricasPessoas[0]?.total_horas)    || 0,
          total_custo:   Number(metricasPessoas[0]?.total_custo)    || 0,
          total_pessoas: Number(metricasPessoas[0]?.total_pessoas)  || 0,
        },
        maquinas: {
          total_horas:        Number(metricasMaquinas[0]?.total_horas)        || 0,
          total_combustivel:  Number(metricasMaquinas[0]?.total_combustivel)  || 0,
          total_maquinas:     Number(metricasMaquinas[0]?.total_maquinas)     || 0,
        },
        viaturas: {
          total_km:      Number(metricasViaturas[0]?.total_km)      || 0,
          total_custo:   Number(metricasViaturas[0]?.total_custo)   || 0,
          total_viaturas: Number(metricasViaturas[0]?.total_viaturas) || 0,
        },
      },
      comparacao,
    });
  } catch (err) {
    console.error('Erro graficos:', err);
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;