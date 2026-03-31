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

    const [semanas] = await pool.query(
      'SELECT * FROM semanas WHERE obra_id = ? ORDER BY numero_semana',
      [req.params.obra_id]
    );

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'ObrasApp';
    workbook.created = new Date();

    // ── Folha Resumo ──
    const resumo = workbook.addWorksheet('Resumo');
    resumo.columns = [
      { header: 'Semana',     key: 'semana',   width: 10 },
      { header: 'Início',     key: 'inicio',   width: 14 },
      { header: 'Fim',        key: 'fim',       width: 14 },
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
    for (const s of semanas) {
      resumo.addRow({
        semana:   `S${s.numero_semana}`,
        inicio:   s.data_inicio ? new Date(s.data_inicio).toLocaleDateString('pt-PT') : '',
        fim:      s.data_fim    ? new Date(s.data_fim).toLocaleDateString('pt-PT')    : '',
        estado:   s.estado,
        faturado: Number(s.faturado) || 0,
      });
      totalFaturado += Number(s.faturado) || 0;
    }

    // Linha de total
    const totalRow = resumo.addRow(['', '', '', 'TOTAL', totalFaturado]);
    totalRow.font = { bold: true };

    // ── Folha Detalhe por semana ──
    for (const semana of semanas) {
      const sheet = workbook.addWorksheet(`S${semana.numero_semana}`);

      // Horas pessoas
      sheet.addRow([`Semana ${semana.numero_semana}`, `${obra.codigo} — ${obra.nome}`]);
      sheet.getRow(1).font = { bold: true, size: 12 };
      sheet.addRow([]);

      sheet.addRow(['Pessoas', 'Horas', 'Custo €']);
      sheet.getRow(3).font = { bold: true };

      const [pessoas] = await pool.query(
        `SELECT sp.*, o.nome FROM semana_pessoas sp
         JOIN operadores o ON o.id = sp.pessoa_id
         WHERE sp.semana_id = ?`,
        [semana.id]
      );
      for (const p of pessoas) {
        sheet.addRow([p.nome, p.horas_total, Number(p.custo_total)]);
      }

      sheet.addRow([]);
      sheet.addRow(['Máquinas', 'Horas', 'Combustível €']);
      sheet.getRow(sheet.lastRow.number).font = { bold: true };

      const [maquinas] = await pool.query(
        `SELECT sm.*, m.nome FROM semana_maquinas sm
         JOIN maquinas m ON m.id = sm.maquina_id
         WHERE sm.semana_id = ?`,
        [semana.id]
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
// GET /api/relatorios/pdf/:semana_id
router.get('/pdf/:semana_id', async (req, res) => {
  try {
    const [[semana]] = await pool.query('SELECT * FROM semanas WHERE id = ?', [req.params.semana_id]);
    if (!semana) return res.status(404).json({ erro: 'Semana não encontrada' });

    const [[obra]] = await pool.query('SELECT * FROM obras WHERE id = ?', [semana.obra_id]);

    const [pessoas] = await pool.query(
      `SELECT sp.*, o.nome FROM semana_pessoas sp
       JOIN operadores o ON o.id = sp.pessoa_id
       WHERE sp.semana_id = ?`,
      [req.params.semana_id]
    );

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=semana_${semana.numero_semana}.pdf`);
    doc.pipe(res);

    // Cabeçalho
    doc.fontSize(18).font('Helvetica-Bold').text(`${obra.codigo} — Semana ${semana.numero_semana}`, { align: 'center' });
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
    doc.text(`Faturado:  € ${Number(semana.faturado || 0).toFixed(2)}`);

    doc.end();
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

// ─── GRÁFICOS (dados JSON para o Flutter) ─────────────────────────────────────
// GET /api/relatorios/graficos/:obra_id
router.get('/graficos/:obra_id', async (req, res) => {
  try {
    const [semanas] = await pool.query(
      'SELECT numero_semana, faturado FROM semanas WHERE obra_id = ? ORDER BY numero_semana',
      [req.params.obra_id]
    );

    // Custo total acumulado por semana
    let acumulado = 0;
    const dadosAcumulados = semanas.map(s => {
      acumulado += Number(s.faturado) || 0;
      return { semana: `S${s.numero_semana}`, faturado: Number(s.faturado) || 0, acumulado };
    });

    // Distribuição de custos da semana mais recente
    const ultimaSemana = semanas[semanas.length - 1];
    let distribuicao = [];
    if (ultimaSemana) {
      const [pessoas]  = await pool.query(
        'SELECT SUM(custo_total) as total FROM semana_pessoas  WHERE semana_id=(SELECT id FROM semanas WHERE obra_id=? ORDER BY numero_semana DESC LIMIT 1)',
        [req.params.obra_id]
      );
      const [maquinas] = await pool.query(
        'SELECT SUM(combustivel_total) as total FROM semana_maquinas WHERE semana_id=(SELECT id FROM semanas WHERE obra_id=? ORDER BY numero_semana DESC LIMIT 1)',
        [req.params.obra_id]
      );
      distribuicao = [
        { categoria: 'Pessoal',    valor: Number(pessoas[0].total)  || 0 },
        { categoria: 'Combustível', valor: Number(maquinas[0].total) || 0 },
      ];
    }

    res.json({ evolucao: dadosAcumulados, distribuicao });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

module.exports = router;
