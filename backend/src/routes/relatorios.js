const router = require('express').Router();
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const pool = require('../db/pool');
const { auth } = require('../middleware/auth');

router.use(auth);

// ─── EXCEL ────────────────────────────────────────────────────────────────────
// GET /api/relatorios/excel/:obra_id
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

    // ── Folha Resumo ──
    const resumo = workbook.addWorksheet('Resumo');
    resumo.columns = [
      { header: 'Data',       key: 'data',     width: 14 },
      { header: 'Estado',     key: 'estado',   width: 12 },
      { header: 'Faturado €', key: 'faturado', width: 14 },
    ];

    // Estilo do cabeçalho
    resumo.getRow(1).font = { bold: true };
    resumo.getRow(1).fill = {
      type: 'pattern', pattern: 'solid',
      fgColor: { argb: 'FF1A1A2E' }
    };
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

    // Linha de total
    const totalRow = resumo.addRow(['', 'TOTAL', totalFaturado]);
    totalRow.font = { bold: true };

    // ── Folha Detalhe por dia ──
    for (const dia of dias) {
      const sheet = workbook.addWorksheet(new Date(dia.data).toLocaleDateString('pt-PT'));

      // Cabeçalho
      sheet.addRow([`Data: ${new Date(dia.data).toLocaleDateString('pt-PT')}`, `${obra.codigo} — ${obra.nome}`]);
      sheet.getRow(1).font = { bold: true, size: 12 };
      sheet.addRow([]);

      // Pessoas
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
      // Máquinas
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

    // Envia o ficheiro
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=obra_${obra.codigo.replace(/\//g,'_')}.xlsx`);

    await workbook.xlsx.write(res);
    res.end();
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ─── PDF ──────────────────────────────────────────────────────────────────────
// GET /api/relatorios/pdf/:dia_id
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

    // Cabeçalho
    doc.fontSize(18).font('Helvetica-Bold').text(`${obra.codigo} — ${new Date(dia.data).toLocaleDateString('pt-PT')}`, { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(11).font('Helvetica').text(`Obra: ${obra.nome}`, { align: 'center' });
    doc.moveDown(1.5);

    // Tabela pessoas
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

// ─── GRÁFICOS (dados JSON para o Flutter) ─────────────────────────────────────
// GET /api/relatorios/graficos/:obra_id
router.get('/graficos/:obra_id', async (req, res) => {
  try {
    const [dias] = await pool.query(
      'SELECT data, faturado FROM dias WHERE obra_id = ? ORDER BY data',
      [req.params.obra_id]
    );

    // Custo total acumulado por dia
    let acumulado = 0;
    const dadosAcumulados = dias.map(d => {
      acumulado += Number(d.faturado) || 0;
      return { 
        data: new Date(d.data).toLocaleDateString('pt-PT'), 
        faturado: Number(d.faturado) || 0, 
        acumulado 
      };
    });

    // Distribuição de custos do dia mais recente
    const ultimoDia = dias[dias.length - 1];
    let distribuicao = [];
    if (ultimoDia) {
      const [pessoas]  = await pool.query(
        'SELECT SUM(custo_total) as total FROM dia_pessoas WHERE dia_id=(SELECT id FROM dias WHERE obra_id=? ORDER BY data DESC LIMIT 1)',
        [req.params.obra_id]
      );
      const [maquinas] = await pool.query(
        'SELECT SUM(combustivel_total) as total FROM dia_maquinas WHERE dia_id=(SELECT id FROM dias WHERE obra_id=? ORDER BY data DESC LIMIT 1)',
        [req.params.obra_id]
      );
      distribuicao = [
        { categoria: 'Pessoal',     valor: Number(pessoas[0].total)  || 0 },
        { categoria: 'Combustível', valor: Number(maquinas[0].total) || 0 },
      ];
    }

    res.json({ evolucao: dadosAcumulados, distribuicao });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;
