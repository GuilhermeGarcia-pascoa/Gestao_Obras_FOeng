// routes/export.js
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const pool = require('../db/pool');

// ── GET /api/export/excel/:obraId ─────────────────────────────────
async function exportarExcel(req, res) {
  const { obraId } = req.params;

  try {
    // obras: id, codigo, nome, tipo, estado, orcamento, criado_em
    const [obras] = await pool.query(
      `SELECT id, codigo, nome, tipo, estado, orcamento, criado_em
       FROM obras WHERE id = ?`,
      [obraId]
    );
    if (obras.length === 0) return res.status(404).json({ erro: 'Obra não encontrada' });
    const obra = obras[0];

    // dias: id, obra_id, data, estado, faturado, valor_to, valor_combustivel, valor_estadias, valor_materiais
    const [dias] = await pool.query(
      `SELECT id, data, estado, faturado, valor_to, valor_combustivel, valor_estadias, valor_materiais
       FROM dias WHERE obra_id = ? ORDER BY data ASC`,
      [obraId]
    );

    // dia_pessoas -> operadores
    const [pessoas] = await pool.query(
      `SELECT dp.dia_id, o.nome, o.cargo, o.categoria_sindical, dp.horas_total, dp.custo_total
       FROM dia_pessoas dp
       JOIN operadores o ON o.id = dp.pessoa_id
       WHERE dp.dia_id IN (SELECT id FROM dias WHERE obra_id = ?)`,
      [obraId]
    );

    // dia_maquinas -> maquinas
    const [maquinas] = await pool.query(
      `SELECT dm.dia_id, m.nome, m.tipo, m.matricula, dm.horas_total, dm.combustivel_total
       FROM dia_maquinas dm
       JOIN maquinas m ON m.id = dm.maquina_id
       WHERE dm.dia_id IN (SELECT id FROM dias WHERE obra_id = ?)`,
      [obraId]
    );

    // dia_viaturas -> viaturas
    const [viaturas] = await pool.query(
      `SELECT dv.dia_id, v.modelo, v.matricula, dv.km_total, dv.custo_total
       FROM dia_viaturas dv
       JOIN viaturas v ON v.id = dv.viatura_id
       WHERE dv.dia_id IN (SELECT id FROM dias WHERE obra_id = ?)`,
      [obraId]
    );

    const pessoasPorDia  = groupBy(pessoas,  'dia_id');
    const maquinasPorDia = groupBy(maquinas, 'dia_id');
    const viaturasPorDia = groupBy(viaturas, 'dia_id');

    const wb = new ExcelJS.Workbook();
    wb.creator = 'GestãoObra';
    wb.created = new Date();

    // ── Folha 1: Resumo ──────────────────────────────────────────
    const wsResumo = wb.addWorksheet('Resumo');
    wsResumo.views = [{ showGridLines: false }];

    wsResumo.mergeCells('A1:D1');
    const cellTitulo = wsResumo.getCell('A1');
    cellTitulo.value = `Obra: ${obra.codigo} — ${obra.nome}`;
    cellTitulo.font = { bold: true, size: 14, color: { argb: 'FF185FA5' } };
    cellTitulo.alignment = { horizontal: 'center' };

    wsResumo.addRow([]);
    addLabelValue(wsResumo, 'Código',     obra.codigo);
    addLabelValue(wsResumo, 'Nome',       obra.nome);
    addLabelValue(wsResumo, 'Tipo',       obra.tipo ?? '—');
    addLabelValue(wsResumo, 'Estado',     obra.estado ?? '—');
    addLabelValue(wsResumo, 'Orçamento',  obra.orcamento != null ? `€ ${Number(obra.orcamento).toFixed(2)}` : '—');
    addLabelValue(wsResumo, 'Criado em',  fmtData(obra.criado_em));
    addLabelValue(wsResumo, 'Total dias', dias.length);

    wsResumo.addRow([]);

    const totalHorasPessoas  = pessoas.reduce((s, p)  => s + (Number(p.horas_total)       || 0), 0);
    const totalCustoPessoas  = pessoas.reduce((s, p)  => s + (Number(p.custo_total)        || 0), 0);
    const totalHorasMaquinas = maquinas.reduce((s, m) => s + (Number(m.horas_total)        || 0), 0);
    const totalKmViaturas    = viaturas.reduce((s, v) => s + (Number(v.km_total)           || 0), 0);
    const totalCustoViaturas = viaturas.reduce((s, v) => s + (Number(v.custo_total)        || 0), 0);
    const totalValorTo       = dias.reduce((s, d)     => s + (Number(d.valor_to)           || 0), 0);
    const totalCombustivel   = dias.reduce((s, d)     => s + (Number(d.valor_combustivel)  || 0), 0);
    const totalEstadias      = dias.reduce((s, d)     => s + (Number(d.valor_estadias)     || 0), 0);
    const totalMateriais     = dias.reduce((s, d)     => s + (Number(d.valor_materiais)    || 0), 0);

    addHeader(wsResumo, ['Sumários Globais', '']);
    addLabelValue(wsResumo, 'Total horas pessoas',  `${totalHorasPessoas.toFixed(2)} h`);
    addLabelValue(wsResumo, 'Custo total pessoas',  `€ ${totalCustoPessoas.toFixed(2)}`);
    addLabelValue(wsResumo, 'Total horas máquinas', `${totalHorasMaquinas.toFixed(2)} h`);
    addLabelValue(wsResumo, 'Total km viaturas',    `${totalKmViaturas.toFixed(2)} km`);
    addLabelValue(wsResumo, 'Custo total viaturas', `€ ${totalCustoViaturas.toFixed(2)}`);
    addLabelValue(wsResumo, 'Valor T.O.',           `€ ${totalValorTo.toFixed(2)}`);
    addLabelValue(wsResumo, 'Combustível',          `€ ${totalCombustivel.toFixed(2)}`);
    addLabelValue(wsResumo, 'Estadias',             `€ ${totalEstadias.toFixed(2)}`);
    addLabelValue(wsResumo, 'Materiais',            `€ ${totalMateriais.toFixed(2)}`);

    wsResumo.getColumn('A').width = 24;
    wsResumo.getColumn('B').width = 30;

    // ── Folha 2: Detalhe por Dia ─────────────────────────────────
    const wsDias = wb.addWorksheet('Detalhe por Dia');
    wsDias.views = [{ showGridLines: false }];

    for (const dia of dias) {
      const rowDia = wsDias.addRow([fmtData(dia.data), `Estado: ${dia.estado ?? '—'}`]);
      rowDia.font = { bold: true, size: 12, color: { argb: 'FF185FA5' } };
      rowDia.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE6F1FB' } };
      wsDias.mergeCells(`A${rowDia.number}:F${rowDia.number}`);

      const rowValores = wsDias.addRow([
        '',
        `T.O.: € ${Number(dia.valor_to || 0).toFixed(2)}`,
        `Comb.: € ${Number(dia.valor_combustivel || 0).toFixed(2)}`,
        `Estadias: € ${Number(dia.valor_estadias || 0).toFixed(2)}`,
        `Materiais: € ${Number(dia.valor_materiais || 0).toFixed(2)}`,
        '',
      ]);
      rowValores.font = { italic: true, size: 9, color: { argb: 'FF666666' } };

      const pDia = pessoasPorDia[dia.id] ?? [];
      if (pDia.length > 0) {
        addSubHeader(wsDias, ['Pessoas', 'Nome', 'Cargo', 'Categoria', 'Horas', 'Custo']);
        pDia.forEach(p => wsDias.addRow([
          '', p.nome, p.cargo ?? '—', p.categoria_sindical ?? '—',
          `${Number(p.horas_total || 0).toFixed(2)} h`,
          `€ ${Number(p.custo_total || 0).toFixed(2)}`,
        ]));
      }

      const mDia = maquinasPorDia[dia.id] ?? [];
      if (mDia.length > 0) {
        addSubHeader(wsDias, ['Maquinas', 'Nome', 'Tipo', 'Matricula', 'Horas', 'Combustivel']);
        mDia.forEach(m => wsDias.addRow([
          '', m.nome, m.tipo ?? '—', m.matricula ?? '—',
          `${Number(m.horas_total || 0).toFixed(2)} h`,
          `${Number(m.combustivel_total || 0).toFixed(2)} L`,
        ]));
      }

      const vDia = viaturasPorDia[dia.id] ?? [];
      if (vDia.length > 0) {
        addSubHeader(wsDias, ['Viaturas', 'Modelo', 'Matricula', 'Km', 'Custo', '']);
        vDia.forEach(v => wsDias.addRow([
          '', v.modelo, v.matricula ?? '—',
          `${Number(v.km_total || 0).toFixed(2)} km`,
          `€ ${Number(v.custo_total || 0).toFixed(2)}`,
          '',
        ]));
      }

      wsDias.addRow([]);
    }

    wsDias.getColumn('A').width = 16;
    wsDias.getColumn('B').width = 22;
    wsDias.getColumn('C').width = 18;
    wsDias.getColumn('D').width = 18;
    wsDias.getColumn('E').width = 12;
    wsDias.getColumn('F').width = 14;

    // ── Folha 3: Resumo por Semana ───────────────────────────────
    // semanas: id, obra_id, numero_semana, data_inicio, data_fim, estado, faturado
    const [semanas] = await pool.query(
      `SELECT s.id, s.numero_semana, s.data_inicio, s.data_fim, s.estado, s.faturado,
              (SELECT COUNT(*) FROM semana_pessoas  sp WHERE sp.semana_id = s.id) AS total_pessoas,
              (SELECT COUNT(*) FROM semana_maquinas sm WHERE sm.semana_id = s.id) AS total_maquinas,
              (SELECT COUNT(*) FROM semana_viaturas sv WHERE sv.semana_id = s.id) AS total_viaturas
       FROM semanas s WHERE s.obra_id = ? ORDER BY s.numero_semana ASC`,
      [obraId]
    );

    if (semanas.length > 0) {
      const wsSemanas = wb.addWorksheet('Resumo por Semana');
      wsSemanas.views = [{ showGridLines: false }];
      addHeader(wsSemanas, ['Semana', 'Data Inicio', 'Data Fim', 'Estado', 'Pessoas', 'Maquinas', 'Viaturas', 'Faturado']);
      semanas.forEach(s => {
        wsSemanas.addRow([
          `Semana ${s.numero_semana}`,
          fmtData(s.data_inicio),
          fmtData(s.data_fim),
          s.estado ?? '—',
          s.total_pessoas,
          s.total_maquinas,
          s.total_viaturas,
          s.faturado != null ? `€ ${Number(s.faturado).toFixed(2)}` : '—',
        ]);
      });
      ['A','B','C','D','E','F','G','H'].forEach((col, i) => {
        wsSemanas.getColumn(col).width = [14, 14, 14, 12, 10, 12, 10, 14][i];
      });
    }

    const filename = `obra_${obra.codigo}_${Date.now()}.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    await wb.xlsx.write(res);
    res.end();

  } catch (err) {
    console.error('Erro exportarExcel:', err);
    res.status(500).json({ erro: 'Erro ao gerar Excel' });
  }
}

// ── GET /api/export/pdf?dataInicio=2024-01-01&dataFim=2024-01-31 ──
async function exportarPdf(req, res) {
  const { dataInicio, dataFim } = req.query;

  if (!dataInicio || !dataFim) {
    return res.status(400).json({ erro: 'Parâmetros dataInicio e dataFim são obrigatórios' });
  }

  try {
    const [dias] = await pool.query(
      `SELECT d.id, d.data, d.estado, d.valor_to, d.valor_combustivel, d.valor_estadias, d.valor_materiais,
              o.codigo AS obra_codigo, o.nome AS obra_nome
       FROM dias d
       JOIN obras o ON o.id = d.obra_id
       WHERE d.data BETWEEN ? AND ?
       ORDER BY d.data ASC, o.codigo ASC`,
      [dataInicio, dataFim]
    );

    if (dias.length === 0) {
      return res.status(404).json({ erro: 'Nenhum registo encontrado para o intervalo indicado' });
    }

    const diaIds = dias.map(d => d.id);

    const [pessoas] = await pool.query(
      `SELECT dp.dia_id, o.nome, o.cargo, dp.horas_total, dp.custo_total
       FROM dia_pessoas dp
       JOIN operadores o ON o.id = dp.pessoa_id
       WHERE dp.dia_id IN (?)`,
      [diaIds]
    );

    const [maquinas] = await pool.query(
      `SELECT dm.dia_id, m.nome, m.tipo, dm.horas_total, dm.combustivel_total
       FROM dia_maquinas dm
       JOIN maquinas m ON m.id = dm.maquina_id
       WHERE dm.dia_id IN (?)`,
      [diaIds]
    );

    const [viaturas] = await pool.query(
      `SELECT dv.dia_id, v.modelo, v.matricula, dv.km_total, dv.custo_total
       FROM dia_viaturas dv
       JOIN viaturas v ON v.id = dv.viatura_id
       WHERE dv.dia_id IN (?)`,
      [diaIds]
    );

    const pessoasPorDia  = groupBy(pessoas,  'dia_id');
    const maquinasPorDia = groupBy(maquinas, 'dia_id');
    const viaturasPorDia = groupBy(viaturas, 'dia_id');

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const filename = `relatorio_${dataInicio}_${dataFim}.pdf`;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    doc.pipe(res);

    const AZUL   = '#185FA5';
    const CINZA  = '#666666';
    const FUNDO  = '#E6F1FB';
    const BRANCO = '#FFFFFF';
    const LRG    = 515;

    // Cabeçalho
    doc.rect(40, 40, LRG, 60).fill(AZUL);
    doc.fillColor(BRANCO).fontSize(18).font('Helvetica-Bold')
       .text('Relatorio Diario de Obra', 50, 58, { width: LRG - 20, align: 'center' });
    doc.fillColor(BRANCO).fontSize(11).font('Helvetica')
       .text(`Periodo: ${fmtData(dataInicio)} - ${fmtData(dataFim)}`, 50, 82, { width: LRG - 20, align: 'center' });

    doc.moveDown(2);

    for (const dia of dias) {
      if (doc.y > 700) doc.addPage();

      const yDia = doc.y;
      doc.rect(40, yDia, LRG, 24).fill(FUNDO);
      doc.fillColor(AZUL).fontSize(12).font('Helvetica-Bold')
         .text(`${fmtData(dia.data)}   |   ${dia.obra_codigo} - ${dia.obra_nome}`,
               48, yDia + 6, { width: LRG - 16 });
      doc.y = yDia + 30;

      doc.fillColor(CINZA).fontSize(8).font('Helvetica')
         .text(
           `T.O.: € ${Number(dia.valor_to || 0).toFixed(2)}   |   ` +
           `Combustivel: € ${Number(dia.valor_combustivel || 0).toFixed(2)}   |   ` +
           `Estadias: € ${Number(dia.valor_estadias || 0).toFixed(2)}   |   ` +
           `Materiais: € ${Number(dia.valor_materiais || 0).toFixed(2)}`,
           48, doc.y, { width: LRG - 16 }
         );
      doc.moveDown(0.5);

      const pDia = pessoasPorDia[dia.id] ?? [];
      if (pDia.length > 0) {
        pdfSecao(doc, 'Pessoas');
        pdfCabecalho(doc, ['Nome', 'Cargo', 'Horas', 'Custo'], [190, 150, 80, 80]);
        pDia.forEach((p, i) => pdfLinha(doc,
          [p.nome, p.cargo ?? '-', `${Number(p.horas_total || 0).toFixed(2)} h`, `€ ${Number(p.custo_total || 0).toFixed(2)}`],
          [190, 150, 80, 80], i));
        doc.moveDown(0.5);
      }

      const mDia = maquinasPorDia[dia.id] ?? [];
      if (mDia.length > 0) {
        if (doc.y > 680) doc.addPage();
        pdfSecao(doc, 'Maquinas');
        pdfCabecalho(doc, ['Nome', 'Tipo', 'Horas', 'Combustivel'], [190, 150, 80, 80]);
        mDia.forEach((m, i) => pdfLinha(doc,
          [m.nome, m.tipo ?? '-', `${Number(m.horas_total || 0).toFixed(2)} h`, `${Number(m.combustivel_total || 0).toFixed(2)} L`],
          [190, 150, 80, 80], i));
        doc.moveDown(0.5);
      }

      const vDia = viaturasPorDia[dia.id] ?? [];
      if (vDia.length > 0) {
        if (doc.y > 680) doc.addPage();
        pdfSecao(doc, 'Viaturas');
        pdfCabecalho(doc, ['Modelo', 'Matricula', 'Km', 'Custo'], [190, 150, 80, 80]);
        vDia.forEach((v, i) => pdfLinha(doc,
          [v.modelo, v.matricula ?? '-', `${Number(v.km_total || 0).toFixed(2)} km`, `€ ${Number(v.custo_total || 0).toFixed(2)}`],
          [190, 150, 80, 80], i));
        doc.moveDown(0.5);
      }

      const thP = pDia.reduce((s, p) => s + (Number(p.horas_total) || 0), 0);
      const thM = mDia.reduce((s, m) => s + (Number(m.horas_total) || 0), 0);
      const tkV = vDia.reduce((s, v) => s + (Number(v.km_total)    || 0), 0);

      doc.fillColor(CINZA).fontSize(8).font('Helvetica')
         .text(`Totais -> Pessoas: ${thP.toFixed(2)} h  |  Maquinas: ${thM.toFixed(2)} h  |  Viaturas: ${tkV.toFixed(2)} km`,
               48, doc.y, { width: LRG - 16 });

      doc.moveDown(1.2);
      doc.moveTo(40, doc.y).lineTo(555, doc.y).strokeColor('#CCCCCC').lineWidth(0.5).stroke();
      doc.moveDown(1);
    }

    doc.fillColor(CINZA).fontSize(8).font('Helvetica')
       .text(`Gerado em ${new Date().toLocaleString('pt-PT')}`, 40, doc.y, { align: 'right', width: LRG });

    doc.end();

  } catch (err) {
    console.error('Erro exportarPdf:', err);
    if (!res.headersSent) res.status(500).json({ erro: 'Erro ao gerar PDF' });
  }
}

// ── Helpers Excel ─────────────────────────────────────────────────
function addLabelValue(ws, label, value) {
  const row = ws.addRow([label, value]);
  row.getCell(1).font = { bold: true, color: { argb: 'FF555555' } };
}

function addHeader(ws, cols) {
  const row = ws.addRow(cols);
  row.eachCell(cell => {
    cell.font      = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF185FA5' } };
    cell.alignment = { horizontal: 'center' };
  });
}

function addSubHeader(ws, cols) {
  const row = ws.addRow(cols);
  row.eachCell(cell => {
    cell.font = { bold: true, color: { argb: 'FF185FA5' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0F4FA' } };
  });
}

// ── Helpers PDF ───────────────────────────────────────────────────
function pdfSecao(doc, titulo) {
  doc.fillColor('#333333').fontSize(10).font('Helvetica-Bold')
     .text(titulo, 48, doc.y, { width: 500 });
  doc.moveDown(0.2);
}

function pdfCabecalho(doc, colunas, larguras) {
  const y = doc.y;
  doc.rect(48, y, 499, 16).fill('#185FA5');
  let x = 52;
  colunas.forEach((col, i) => {
    doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold')
       .text(col, x, y + 4, { width: larguras[i], lineBreak: false });
    x += larguras[i];
  });
  doc.y = y + 18;
}

function pdfLinha(doc, valores, larguras, idx) {
  const y = doc.y;
  if (idx % 2 === 1) doc.rect(48, y, 499, 15).fill('#F5F8FC');
  let x = 52;
  valores.forEach((val, i) => {
    doc.fillColor('#333333').fontSize(8).font('Helvetica')
       .text(String(val ?? '-'), x, y + 3, { width: larguras[i], lineBreak: false });
    x += larguras[i];
  });
  doc.y = y + 16;
}

// ── Helpers comuns ────────────────────────────────────────────────
function groupBy(arr, key) {
  return arr.reduce((acc, item) => {
    (acc[item[key]] = acc[item[key]] || []).push(item);
    return acc;
  }, {});
}

function fmtData(d) {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('pt-PT');
}

module.exports = { exportarExcel, exportarPdf };