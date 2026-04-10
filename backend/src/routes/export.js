const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const pool = require('../db/pool');
const { logAction, reqMeta } = require('../utils/logger');

const EUR = '[$EUR ]#,##0.00;[Red]-[$EUR ]#,##0.00';

async function exportarExcel(req, res) {
  const { obraId } = req.params;
  try {
    const [[obra]] = await pool.query(
      `SELECT id, codigo, nome, tipo, estado, orcamento, criado_em FROM obras WHERE id = ?`,
      [obraId]
    );
    if (!obra) return res.status(404).json({ erro: 'Obra não encontrada' });

    const [dias] = await pool.query(
      `SELECT id, data, estado, faturado, valor_to, valor_combustivel, valor_estadias, valor_materiais, valor_refeicoes
       FROM dias
       WHERE obra_id = ?
         AND (
           COALESCE(faturado, 0) > 0 OR
           COALESCE(valor_to, 0) > 0 OR
           COALESCE(valor_combustivel, 0) > 0 OR
           COALESCE(valor_estadias, 0) > 0 OR
           COALESCE(valor_materiais, 0) > 0 OR
           COALESCE(valor_refeicoes, 0) > 0 OR
           EXISTS (SELECT 1 FROM dia_pessoas dp WHERE dp.dia_id = dias.id) OR
           EXISTS (SELECT 1 FROM dia_maquinas dm WHERE dm.dia_id = dias.id) OR
           EXISTS (SELECT 1 FROM dia_viaturas dv WHERE dv.dia_id = dias.id)
         )
       ORDER BY data ASC`,
      [obraId]
    );
    const [pessoas] = await pool.query(
      `SELECT dp.dia_id, dp.pessoa_id, o.nome, o.cargo, dp.horas_total, dp.custo_total, dp.custo_extra, dp.custo_hora_snapshot
       FROM dia_pessoas dp JOIN operadores o ON o.id = dp.pessoa_id
       WHERE dp.dia_id IN (SELECT id FROM dias WHERE obra_id = ?)`,
      [obraId]
    );
    const [maquinas] = await pool.query(
      `SELECT dm.dia_id, dm.maquina_id, m.nome, m.tipo, m.matricula, dm.horas_total, dm.custo_total, dm.custo_hora_snapshot
       FROM dia_maquinas dm JOIN maquinas m ON m.id = dm.maquina_id
       WHERE dm.dia_id IN (SELECT id FROM dias WHERE obra_id = ?)`,
      [obraId]
    );
    const [viaturas] = await pool.query(
      `SELECT dv.dia_id, dv.viatura_id, v.modelo, v.matricula, dv.km_total, dv.custo_total, dv.custo_km_snapshot
       FROM dia_viaturas dv JOIN viaturas v ON v.id = dv.viatura_id
       WHERE dv.dia_id IN (SELECT id FROM dias WHERE obra_id = ?)`,
      [obraId]
    );

    const wb = new ExcelJS.Workbook();
    wb.creator = 'GestaoObra';
    wb.created = new Date();
    wb.modified = new Date();

    const semanas = buildSemanas(dias, pessoas, maquinas, viaturas);
    const meta = [];
    addResumo(wb, obra, dias, pessoas, maquinas, viaturas, semanas);
    addPlaneamento(wb, obra, dias, pessoas, maquinas, viaturas);
    semanas.forEach((s) => addSemana(wb, obra, s, meta));
    addMeta(wb, obra, meta);

    const filename = `obra_${safeName(obra.codigo)}_${Date.now()}.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="\${filename}"`);
    await wb.xlsx.write(res);
    res.end();

    await logAction({
      userId:   req.user ? req.user.id : null,
      action:   'EXPORT',
      entity:   'obras',
      entityId: parseInt(obraId),
      details:  { formato: 'excel', obra_codigo: obra.codigo, obra_nome: obra.nome },
      ...reqMeta(req),
    });
  } catch (err) {
    console.error('Erro exportarExcel:', err);
    res.status(500).json({ erro: 'Erro ao gerar Excel' });
  }
}

async function exportarPdf(req, res) {
  const { dataInicio, dataFim } = req.query;
  if (!dataInicio || !dataFim) {
    return res.status(400).json({ erro: 'Parâmetros dataInicio e dataFim são obrigatórios' });
  }
  try {
    const [dias] = await pool.query(
      `SELECT d.id, d.data, d.estado, d.valor_to, d.valor_combustivel, d.valor_estadias, d.valor_materiais,
              o.codigo AS obra_codigo, o.nome AS obra_nome
       FROM dias d JOIN obras o ON o.id = d.obra_id
       WHERE d.data BETWEEN ? AND ? ORDER BY d.data ASC, o.codigo ASC`,
      [dataInicio, dataFim]
    );
    if (!dias.length) return res.status(404).json({ erro: 'Nenhum registo encontrado para o intervalo indicado' });
    const diaIds = dias.map((d) => d.id);
    const [pessoas] = await pool.query(
      `SELECT dp.dia_id, o.nome, o.cargo, dp.horas_total, dp.custo_total, dp.custo_extra
       FROM dia_pessoas dp JOIN operadores o ON o.id = dp.pessoa_id WHERE dp.dia_id IN (?)`,
      [diaIds]
    );
    const [maquinas] = await pool.query(
      `SELECT dm.dia_id, m.nome, m.tipo, dm.horas_total, dm.custo_total, dm.combustivel_total
       FROM dia_maquinas dm JOIN maquinas m ON m.id = dm.maquina_id WHERE dm.dia_id IN (?)`,
      [diaIds]
    );
    const [viaturas] = await pool.query(
      `SELECT dv.dia_id, v.modelo, v.matricula, dv.km_total, dv.custo_total
       FROM dia_viaturas dv JOIN viaturas v ON v.id = dv.viatura_id WHERE dv.dia_id IN (?)`,
      [diaIds]
    );

    const pessoasPorDia = groupBy(pessoas, 'dia_id');
    const maquinasPorDia = groupBy(maquinas, 'dia_id');
    const viaturasPorDia = groupBy(viaturas, 'dia_id');
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const filename = `relatorio_${dataInicio}_${dataFim}.pdf`;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    doc.pipe(res);

    const AZUL = '#185FA5', CINZA = '#666666', FUNDO = '#E6F1FB', BRANCO = '#FFFFFF', L = 515;
    doc.rect(40, 40, L, 60).fill(AZUL);
    doc.fillColor(BRANCO).fontSize(18).font('Helvetica-Bold').text('Relatorio Diario de Obra', 50, 58, { width: L - 20, align: 'center' });
    doc.fillColor(BRANCO).fontSize(11).font('Helvetica').text(`Periodo: ${fmtData(dataInicio)} - ${fmtData(dataFim)}`, 50, 82, { width: L - 20, align: 'center' });
    doc.moveDown(2);

    for (const dia of dias) {
      if (doc.y > 700) doc.addPage();
      const y = doc.y;
      doc.rect(40, y, L, 24).fill(FUNDO);
      doc.fillColor(AZUL).fontSize(12).font('Helvetica-Bold').text(`${fmtData(dia.data)}   |   ${dia.obra_codigo} - ${dia.obra_nome}`, 48, y + 6, { width: L - 16 });
      doc.y = y + 30;
      doc.fillColor(CINZA).fontSize(8).font('Helvetica').text(
        `T.O.: € ${n(dia.valor_to).toFixed(2)}   |   Combustivel: € ${n(dia.valor_combustivel).toFixed(2)}   |   Estadias: € ${n(dia.valor_estadias).toFixed(2)}   |   Materiais: € ${n(dia.valor_materiais).toFixed(2)}`,
        48, doc.y, { width: L - 16 }
      );
      doc.moveDown(0.5);

      const pDia = pessoasPorDia[dia.id] ?? [];
      if (pDia.length) {
        pdfSecao(doc, 'Pessoas'); pdfCabecalho(doc, ['Nome', 'Cargo', 'Horas', 'Custo'], [190, 150, 80, 80]);
        pDia.forEach((p, i) => pdfLinha(doc, [p.nome, p.cargo ?? '-', `${n(p.horas_total).toFixed(2)} h`, `€ ${n(p.custo_total).toFixed(2)}`], [190, 150, 80, 80], i));
        doc.moveDown(0.5);
      }
      const mDia = maquinasPorDia[dia.id] ?? [];
      if (mDia.length) {
        if (doc.y > 680) doc.addPage();
        pdfSecao(doc, 'Maquinas'); pdfCabecalho(doc, ['Nome', 'Tipo', 'Horas', 'Combustivel'], [190, 150, 80, 80]);
        mDia.forEach((m, i) => pdfLinha(doc, [m.nome, m.tipo ?? '-', `${n(m.horas_total).toFixed(2)} h`, `${n(m.combustivel_total).toFixed(2)} L`], [190, 150, 80, 80], i));
        doc.moveDown(0.5);
      }
      const vDia = viaturasPorDia[dia.id] ?? [];
      if (vDia.length) {
        if (doc.y > 680) doc.addPage();
        pdfSecao(doc, 'Viaturas'); pdfCabecalho(doc, ['Modelo', 'Matricula', 'Km', 'Custo'], [190, 150, 80, 80]);
        vDia.forEach((v, i) => pdfLinha(doc, [v.modelo, v.matricula ?? '-', `${n(v.km_total).toFixed(2)} km`, `€ ${n(v.custo_total).toFixed(2)}`], [190, 150, 80, 80], i));
        doc.moveDown(0.5);
      }
      doc.fillColor(CINZA).fontSize(8).font('Helvetica').text(
        `Totais -> Pessoas: ${sum(pDia, (x) => n(x.horas_total)).toFixed(2)} h  |  Maquinas: ${sum(mDia, (x) => n(x.horas_total)).toFixed(2)} h  |  Viaturas: ${sum(vDia, (x) => n(x.km_total)).toFixed(2)} km`,
        48, doc.y, { width: L - 16 }
      );
      doc.moveDown(1.2);
      doc.moveTo(40, doc.y).lineTo(555, doc.y).strokeColor('#CCCCCC').lineWidth(0.5).stroke();
      doc.moveDown(1);
    }
    doc.fillColor(CINZA).fontSize(8).font('Helvetica').text(`Gerado em ${new Date().toLocaleString('pt-PT')}`, 40, doc.y, { align: 'right', width: L });
    doc.end();

    await logAction({
      userId:   req.user ? req.user.id : null,
      action:   'EXPORT',
      entity:   'relatorio_diario',
      details:  { formato: 'pdf', dataInicio, dataFim, total_dias: dias.length },
      ...reqMeta(req),
    });
  } catch (err) {
    console.error('Erro exportarPdf:', err);
    if (!res.headersSent) res.status(500).json({ erro: 'Erro ao gerar PDF' });
  }
}

function addResumo(wb, obra, dias, pessoas, maquinas, viaturas, semanas) {
  const ws = wb.addWorksheet('Resumo');
  ws.views = [{ showGridLines: false }];
  ws.columns = [{ width: 28 }, { width: 18 }, { width: 22 }, { width: 18 }];
  ws.mergeCells('A1:D1');
  setDark(ws.getCell('A1'), `Exportacao de custos - ${obra.codigo} - ${obra.nome}`, 15);
  ws.addRow([]);
  label(ws, 'Codigo', obra.codigo);
  label(ws, 'Nome', obra.nome);
  label(ws, 'Tipo', obra.tipo ?? '-');
  label(ws, 'Estado', obra.estado ?? '-');
  label(ws, 'Orcamento', obra.orcamento != null ? Number(obra.orcamento) : null, EUR);
  label(ws, 'Criado em', fmtData(obra.criado_em));
  label(ws, 'Dias exportados', dias.length);
  label(ws, 'Semanas exportadas', semanas.length);
  ws.addRow([]);
  header(ws, ['Resumo global', 'Valor', '', '']);
  [
    ['Horas de pessoal', sum(pessoas, (x) => n(x.horas_total)), '0.00'],
    ['Custo de pessoal', sum(pessoas, (x) => n(x.custo_total) + n(x.custo_extra)), EUR],
    ['Horas de maquinas', sum(maquinas, (x) => n(x.horas_total)), '0.00'],
    ['Custo de maquinas', sum(maquinas, (x) => n(x.custo_total)), EUR],
    ['Combustivel', sum(dias, (x) => n(x.valor_combustivel)), EUR],
    ['Km de viaturas', sum(viaturas, (x) => n(x.km_total)), '0.00'],
    ['Custo de viaturas', sum(viaturas, (x) => n(x.custo_total)), EUR],
    ['Estadias', sum(dias, (x) => n(x.valor_estadias)), EUR],
    ['Materiais', sum(dias, (x) => n(x.valor_materiais)), EUR],
    ['Refeicoes', sum(dias, (x) => n(x.valor_refeicoes)), EUR],
    ['Faturado', sum(dias, (x) => n(x.faturado)), EUR],
  ].forEach(([k, v, f]) => label(ws, k, v, f));
  ws.addRow([]);
  header(ws, ['Semanas', 'Periodo', 'Dias', 'Custo']);
  semanas.forEach((s) => {
    const row = ws.addRow([s.sheetName, `${fmtData(s.start)} a ${fmtData(s.end)}`, s.days.filter((d) => d.id).length, sum(s.days, calcDirectCost)]);
    row.getCell(4).numFmt = EUR;
  });
}

function addPlaneamento(wb, obra, dias, pessoas, maquinas, viaturas) {
  const ws = wb.addWorksheet(sheet(`Planeamento ${obra.codigo}`));
  ws.views = [{ showGridLines: false, state: 'frozen', ySplit: 4, xSplit: 3 }];
  const totalCols = 3 + dias.length + 1;
  ws.columns = [
    { width: 14 },
    { width: 30 },
    { width: 18 },
    ...dias.map(() => ({ width: 8.5 })),
    { width: 12 },
  ];

  ws.mergeCells(1, 1, 1, totalCols);
  setDark(ws.getCell(1, 1), `Planeamento operacional - ${obra.codigo} - ${obra.nome}`, 15);
  ws.mergeCells(2, 1, 2, totalCols);
  ws.getCell(2, 1).value = 'Horas reais por dia, da esquerda para a direita, no estilo da folha operacional';
  ws.getCell(2, 1).alignment = { horizontal: 'center', vertical: 'middle' };
  ws.getCell(2, 1).font = { italic: true, color: { argb: 'FF666666' } };

  ws.getCell(3, 1).value = 'Secção';
  ws.getCell(3, 2).value = 'Nome';
  ws.getCell(3, 3).value = 'Base';
  dias.forEach((dia, i) => {
    ws.getCell(3, 4 + i).value = wd(pd(dia.data));
    ws.getCell(4, 4 + i).value = pd(dia.data);
    ws.getCell(4, 4 + i).numFmt = 'dd-mmm';
  });
  ws.getCell(3, 4 + dias.length).value = 'Total €';
  fillRow(ws, 3, 1, totalCols, 'FFD9D9D9', true);
  fillRow(ws, 4, 4, 3 + dias.length, 'FFF2F2F2', true);

  let row = 5;
  row = addPlaneamentoSection(ws, row, 'Responsaveis', buildTimelinePessoas(dias, pessoas, true), dias, 'horas');
  row = addPlaneamentoSection(ws, row, 'Mao de obra', buildTimelinePessoas(dias, pessoas, false), dias, 'horas');
  row = addPlaneamentoSection(ws, row, 'Maquinas', buildTimelineAtivos(dias, maquinas, 'maquina', 'horas_total', 'horas', (m) => `${m.nome}${m.matricula ? ` - ${m.matricula}` : ''}`), dias, 'horas');
  addPlaneamentoSection(ws, row, 'Viaturas', buildTimelineAtivos(dias, viaturas, 'viatura', 'km_total', 'km', (v) => `${v.modelo}${v.matricula ? ` - ${v.matricula}` : ''}`), dias, 'km');
}

function addPlaneamentoSection(ws, row, title, items, dias, field) {
  if (!items.length) return row;
  ws.mergeCells(row, 1, row, 3 + dias.length + 1);
  setDark(ws.getCell(row, 1), title);
  row += 1;
  items.forEach((item) => {
    ws.getCell(row, 1).value = title;
    ws.getCell(row, 2).value = item.nome;
    ws.getCell(row, 3).value = item.baseLabel ?? item.base;
    if (item.baseLabel == null) {
      ws.getCell(row, 3).numFmt = field === 'km' ? '0.00' : EUR;
    }
    dias.forEach((dia, i) => {
      const val = item.byDay.get(dia.id);
      ws.getCell(row, 4 + i).value = val == null ? null : val;
      ws.getCell(row, 4 + i).numFmt = '0.00';
      ws.getCell(row, 4 + i).alignment = { horizontal: 'center', vertical: 'middle' };
    });
    ws.getCell(row, 4 + dias.length).value = item.totalCost ?? 0;
    ws.getCell(row, 4 + dias.length).numFmt = EUR;
    dataRow(ws, row);
    row += 1;
  });
  return row + 1;
}

function addSemana(wb, obra, s, meta) {
  const ws = wb.addWorksheet(s.sheetName);
  ws.views = [{ showGridLines: false, state: 'frozen', ySplit: 5, xSplit: 3 }];
  ws.pageSetup = { orientation: 'landscape', fitToPage: true, fitToWidth: 1, fitToHeight: 0 };
  ws.columns = [
    { width: 18, hidden: true }, { width: 14 }, { width: 32 },
    { width: 14 }, { width: 14 }, { width: 14 }, { width: 14 }, { width: 14 }, { width: 14 }, { width: 14 },
    { width: 16 }, { width: 20 },
  ];
  ws.getCell('B1').value = 'OBRA:'; ws.getCell('B1').font = { bold: true };
  ws.mergeCells('C1:L1'); ws.getCell('C1').value = `${obra.codigo} - ${obra.nome}`; ws.getCell('C1').font = { bold: true }; ws.getCell('C1').alignment = { horizontal: 'center' };
  ws.mergeCells('B2:L2'); setDark(ws.getCell('B2'), `Controlo semanal de custos - Semana ${String(s.week).padStart(2, '0')}`);
  ['Base', 'Recurso / Rubrica', '', '', '', '', '', '', '', 'Total €', 'Obs.'].forEach((v, i) => { if (v) ws.getCell(3, i + 2).value = v; });
  fillRow(ws, 3, 2, 12, 'FFD9D9D9', true);
  fillRow(ws, 4, 4, 10, 'FFF2F2F2', true);
  s.days.forEach((d, i) => {
    const col = 4 + i;
    ws.getCell(3, col).value = d.id ? d.weekday : null;
    ws.getCell(4, col).value = d.id ? d.date : null;
    ws.getCell(4, col).numFmt = 'dd-mmm';
    meta.push({ kind: 'day_column', sheet_name: s.sheetName, column_letter: colL(col), day_id: d.id ?? '', data: d.id ? iso(d.date) : '', weekday: d.weekday ?? '' });
  });

  let r = 6;
  r = addResourceBlock(ws, r, 'Responsaveis em obra', s.responsaveis, s.days, 'horas', meta, s.sheetName);
  r = addResourceBlock(ws, r, 'Mao de obra', s.maoDeObra, s.days, 'horas', meta, s.sheetName);
  r = addResourceBlock(ws, r, 'Maquinas', s.maquinas, s.days, 'horas', meta, s.sheetName);
  r = addResourceBlock(ws, r, 'Viaturas', s.viaturas, s.days, 'km', meta, s.sheetName);
  r = addSingleCostBlock(ws, r, 'Refeicoes', 'refeicoes:geral', 'Refeicoes', s.days, (d) => n(d.valor_refeicoes), meta, s.sheetName);
  addResumoCustos(ws, r, s.days, meta, s.sheetName);
}

function addResourceBlock(ws, row, title, items, days, field, meta, sheet) {
  if (!items.length) return row;
  section(ws, row, title); meta.push({ kind: 'section', sheet_name: sheet, row_number: row, descricao: title }); row += 1;
  items.forEach((item) => {
    ws.getCell(row, 1).value = `${item.kind}:${item.id}`;
    ws.getCell(row, 2).value = item.baseLabel ?? item.base;
    if (item.baseLabel == null) ws.getCell(row, 2).numFmt = EUR;
    ws.getCell(row, 3).value = item.label; ws.getCell(row, 12).value = item.note;
    days.forEach((d, i) => { ws.getCell(row, 4 + i).value = d.id ? (item.byDay.get(d.id)?.[field] ?? null) : null; ws.getCell(row, 4 + i).numFmt = '0.00'; });
    ws.getCell(row, 11).value = item.totalCost ?? 0; ws.getCell(row, 11).numFmt = EUR;
    dataRow(ws, row);
    meta.push({ kind: 'resource_row', sheet_name: sheet, row_number: row, row_key: ws.getCell(row, 1).value, resource_type: item.kind, resource_id: item.id, descricao: item.label });
    row += 1;
  });
  return row + 1;
}

function addSingleCostBlock(ws, row, title, key, labelText, days, getter, meta, sheet) {
  section(ws, row, title); meta.push({ kind: 'section', sheet_name: sheet, row_number: row, descricao: title }); row += 1;
  ws.getCell(row, 1).value = key; ws.getCell(row, 3).value = labelText; ws.getCell(row, 12).value = 'custo';
  days.forEach((d, i) => { ws.getCell(row, 4 + i).value = d.id ? getter(d) : null; ws.getCell(row, 4 + i).numFmt = EUR; });
  ws.getCell(row, 11).value = { formula: `SUM(D${row}:J${row})` }; ws.getCell(row, 11).numFmt = EUR;
  dataRow(ws, row);
  meta.push({ kind: 'resource_row', sheet_name: sheet, row_number: row, row_key: key, resource_type: 'refeicoes', resource_id: 'geral', descricao: labelText });
  return row + 2;
}

function addResumoCustos(ws, row, days, meta, sheet) {
  const defs = [
    ['custo_mo', 'Custo MO', (d) => sum(d.pessoas, (x) => n(x.custo_total) + n(x.custo_extra))],
    ['maquinas', 'Maquinas', (d) => sum(d.maquinas, (x) => n(x.custo_total))],
    ['combustivel', 'Combustivel', (d) => n(d.valor_combustivel)],
    ['viaturas', 'Carros / viaturas', (d) => sum(d.viaturas, (x) => n(x.custo_total))],
    ['estadias', 'Estadias', (d) => n(d.valor_estadias)],
    ['materiais', 'Materiais', (d) => n(d.valor_materiais)],
    ['refeicoes', 'Almocos / refeicoes', (d) => n(d.valor_refeicoes)],
    ['faturado', 'Faturado', (d) => n(d.faturado)],
  ];
  section(ws, row, 'Resumo de custos'); meta.push({ kind: 'section', sheet_name: sheet, row_number: row, descricao: 'Resumo de custos' }); row += 1;
  const pos = {};
  defs.forEach(([key, labelText, getter]) => {
    pos[key] = row; ws.getCell(row, 1).value = `resumo:${key}`; ws.getCell(row, 3).value = labelText; ws.getCell(row, 12).value = key === 'faturado' ? 'receita' : 'custo';
    days.forEach((d, i) => { ws.getCell(row, 4 + i).value = d.id ? getter(d) : null; ws.getCell(row, 4 + i).numFmt = EUR; });
    ws.getCell(row, 11).value = { formula: `SUM(D${row}:J${row})` }; ws.getCell(row, 11).numFmt = EUR;
    dataRow(ws, row); meta.push({ kind: 'summary_row', sheet_name: sheet, row_number: row, row_key: `resumo:${key}`, descricao: labelText }); row += 1;
  });
  section(ws, row, 'Sumatorio de custos'); meta.push({ kind: 'section', sheet_name: sheet, row_number: row, descricao: 'Sumatorio de custos' }); row += 1;
  row = formulaRow(ws, row, 'sumario:total', 'Total custo direto', ['custo_mo', 'maquinas', 'combustivel', 'viaturas', 'estadias', 'materiais', 'refeicoes'].map((k) => pos[k]), meta, sheet);
  row = formulaRow(ws, row, 'sumario:mais10', 'Total + 10%', [row - 1], meta, sheet, '*1.1');
  formulaResultado(ws, row, pos.faturado, row - 2, meta, sheet);
}

function formulaRow(ws, row, key, labelText, refs, meta, sheet, suffix = '') {
  ws.getCell(row, 1).value = key; ws.getCell(row, 3).value = labelText; ws.getCell(row, 12).value = 'calculado';
  for (let c = 4; c <= 10; c++) {
    const refsSafe = refs.map((r) => `N(${colL(c)}${r})`);
    const f = refsSafe.join('+') || '0';
    ws.getCell(row, c).value = { formula: suffix ? `(${f})${suffix}` : f };
    ws.getCell(row, c).numFmt = EUR;
  }
  ws.getCell(row, 11).value = { formula: `SUM(D${row}:J${row})` }; ws.getCell(row, 11).numFmt = EUR; dataRow(ws, row, true);
  meta.push({ kind: 'summary_row', sheet_name: sheet, row_number: row, row_key: key, descricao: labelText });
  return row + 1;
}

function formulaResultado(ws, row, faturadoRow, totalRow, meta, sheet) {
  ws.getCell(row, 1).value = 'sumario:resultado'; ws.getCell(row, 3).value = 'Resultado'; ws.getCell(row, 12).value = 'calculado';
  for (let c = 4; c <= 10; c++) {
    ws.getCell(row, c).value = { formula: `N(${colL(c)}${faturadoRow})-N(${colL(c)}${totalRow})` };
    ws.getCell(row, c).numFmt = EUR;
  }
  ws.getCell(row, 11).value = { formula: `SUM(D${row}:J${row})` }; ws.getCell(row, 11).numFmt = EUR; dataRow(ws, row, true);
  meta.push({ kind: 'summary_row', sheet_name: sheet, row_number: row, row_key: 'sumario:resultado', descricao: 'Resultado' });
}

function addMeta(wb, obra, meta) {
  const ws = wb.addWorksheet('_meta_export'); ws.state = 'veryHidden';
  ws.columns = [
    { header: 'kind', key: 'kind', width: 18 }, { header: 'sheet_name', key: 'sheet_name', width: 24 }, { header: 'row_number', key: 'row_number', width: 12 },
    { header: 'row_key', key: 'row_key', width: 24 }, { header: 'resource_type', key: 'resource_type', width: 18 }, { header: 'resource_id', key: 'resource_id', width: 14 },
    { header: 'descricao', key: 'descricao', width: 30 }, { header: 'column_letter', key: 'column_letter', width: 12 }, { header: 'day_id', key: 'day_id', width: 12 },
    { header: 'data', key: 'data', width: 14 }, { header: 'weekday', key: 'weekday', width: 14 }, { header: 'obra_id', key: 'obra_id', width: 10 }, { header: 'obra_codigo', key: 'obra_codigo', width: 20 },
  ];
  ws.getRow(1).font = { bold: true };
  meta.forEach((m) => ws.addRow({ ...m, obra_id: obra.id, obra_codigo: obra.codigo }));
}

function buildSemanas(dias, pessoas, maquinas, viaturas) {
  const ppd = groupBy(pessoas, 'dia_id'), mpd = groupBy(maquinas, 'dia_id'), vpd = groupBy(viaturas, 'dia_id');
  const map = new Map();
  dias.forEach((dia) => {
    const date = pd(dia.data), info = isoWeek(date);
    if (!map.has(info.key)) {
      map.set(info.key, { week: info.week, start: info.start, end: addD(info.start, 6), days: Array.from({ length: 7 }, (_, i) => ({ date: addD(info.start, i), weekday: wd(addD(info.start, i)), id: null, faturado: 0, valor_to: 0, valor_combustivel: 0, valor_estadias: 0, valor_materiais: 0, valor_refeicoes: 0, pessoas: [], maquinas: [], viaturas: [] })) });
    }
    const s = map.get(info.key), idx = diff(info.start, date);
    s.days[idx] = { ...s.days[idx], ...dia, date, weekday: wd(date), pessoas: ppd[dia.id] ?? [], maquinas: mpd[dia.id] ?? [], viaturas: vpd[dia.id] ?? [] };
  });
  return [...map.values()].sort((a, b) => a.start - b.start).map((s) => ({
    ...s,
    sheetName: sheet(`Semana ${String(s.week).padStart(2, '0')} ${iso(s.start)}`),
    responsaveis: aggPessoas(s.days, true),
    maoDeObra: aggPessoas(s.days, false),
    maquinas: aggAtivos(s.days, 'maquinas', 'maquina', 'horas_total', 'custo_total', 'custo_hora_snapshot', (x) => `${x.nome}${x.matricula ? ` - ${x.matricula}` : ''}`, (x) => x.tipo ?? '', 'horas'),
    viaturas: aggAtivos(s.days, 'viaturas', 'viatura', 'km_total', 'custo_total', 'custo_km_snapshot', (x) => `${x.modelo}${x.matricula ? ` - ${x.matricula}` : ''}`, () => '', 'km'),
  }));
}

function aggPessoas(days, resp) {
  const map = new Map();
  days.forEach((d) => (d.pessoas || []).forEach((p) => {
    if (responsavel(p.cargo) !== resp) return;
    const id = p.pessoa_id ?? p.nome;
    if (!map.has(id)) map.set(id, { kind: resp ? 'responsavel' : 'pessoa', id, label: p.nome, note: p.cargo ?? '', base: rate(p.custo_hora_snapshot, n(p.custo_total) + n(p.custo_extra), p.horas_total), totalCost: 0, rates: new Set(), byDay: new Map() });
    const item = map.get(id);
    const currentRate = rate(p.custo_hora_snapshot, n(p.custo_total) + n(p.custo_extra), p.horas_total);
    if (currentRate != null) item.rates.add(Number(currentRate).toFixed(2));
    item.totalCost += n(p.custo_total) + n(p.custo_extra);
    item.byDay.set(d.id, { horas: n(p.horas_total), custo: n(p.custo_total) + n(p.custo_extra) });
  }));
  return [...map.values()].map((item) => ({
    ...item,
    baseLabel: item.rates.size > 1 ? 'Variável' : null,
    note: item.rates.size > 1 ? `${item.note ? `${item.note} · ` : ''}taxa variável` : item.note,
  })).sort((a, b) => a.label.localeCompare(b.label, 'pt'));
}

function aggAtivos(days, bucket, kind, qtyField, costField, snapField, labelFn, noteFn, outField) {
  const map = new Map();
  days.forEach((d) => (d[bucket] || []).forEach((x) => {
    const id = x[`${kind}_id`] ?? labelFn(x);
    if (!map.has(id)) map.set(id, { kind, id, label: labelFn(x), note: noteFn(x), base: rate(x[snapField], x[costField], x[qtyField]), totalCost: 0, rates: new Set(), byDay: new Map() });
    const item = map.get(id);
    const currentRate = rate(x[snapField], x[costField], x[qtyField]);
    if (currentRate != null) item.rates.add(Number(currentRate).toFixed(2));
    item.totalCost += n(x[costField]);
    item.byDay.set(d.id, { [outField]: n(x[qtyField]), custo: n(x[costField]) });
  }));
  return [...map.values()].map((item) => ({
    ...item,
    baseLabel: item.rates.size > 1 ? 'Variável' : null,
    note: item.rates.size > 1 ? `${item.note ? `${item.note} · ` : ''}taxa variável` : item.note,
  })).sort((a, b) => a.label.localeCompare(b.label, 'pt'));
}

function buildTimelinePessoas(dias, pessoas, resp) {
  const diaMap = new Map(dias.map((d) => [d.id, d]));
  const map = new Map();
  pessoas.forEach((p) => {
    if (!diaMap.has(p.dia_id) || responsavel(p.cargo) !== resp) return;
    const id = p.pessoa_id ?? p.nome;
    if (!map.has(id)) {
      map.set(id, {
        nome: p.nome,
        base: rate(p.custo_hora_snapshot, n(p.custo_total) + n(p.custo_extra), p.horas_total),
        totalCost: 0,
        rates: new Set(),
        byDay: new Map(),
      });
    }
    const item = map.get(id);
    const currentRate = rate(p.custo_hora_snapshot, n(p.custo_total) + n(p.custo_extra), p.horas_total);
    if (currentRate != null) item.rates.add(Number(currentRate).toFixed(2));
    item.totalCost += n(p.custo_total) + n(p.custo_extra);
    item.byDay.set(p.dia_id, n(p.horas_total));
  });
  return [...map.values()].map((item) => ({
    ...item,
    baseLabel: item.rates.size > 1 ? 'Variável' : null,
  })).sort((a, b) => a.nome.localeCompare(b.nome, 'pt'));
}

function buildTimelineAtivos(dias, ativos, kind, qtyField, outField, labelFn) {
  const diaMap = new Map(dias.map((d) => [d.id, d]));
  const map = new Map();
  ativos.forEach((a) => {
    if (!diaMap.has(a.dia_id)) return;
    const id = a[`${kind}_id`] ?? labelFn(a);
    if (!map.has(id)) map.set(id, { nome: labelFn(a), base: null, totalCost: 0, byDay: new Map() });
    const item = map.get(id);
    item.totalCost += n(a.custo_total);
    item.byDay.set(a.dia_id, n(a[qtyField]));
  });
  return [...map.values()].sort((a, b) => a.nome.localeCompare(b.nome, 'pt'));
}

function label(ws, k, v, fmt) { const r = ws.addRow([k, v]); r.getCell(1).font = { bold: true, color: { argb: 'FF555555' } }; if (fmt) r.getCell(2).numFmt = fmt; }
function header(ws, cols) { const r = ws.addRow(cols); r.eachCell((c) => { c.font = { bold: true, color: { argb: 'FFFFFFFF' } }; c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF185FA5' } }; c.alignment = { horizontal: 'center' }; }); }
function setDark(cell, text, size = 12) { cell.value = text; cell.font = { bold: true, size, color: { argb: 'FFFFFFFF' } }; cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF3F3F3F' } }; cell.alignment = { horizontal: 'center', vertical: 'middle' }; cell.border = { top: { style: 'thin', color: { argb: 'FF808080' } }, bottom: { style: 'thin', color: { argb: 'FF808080' } } }; }
function section(ws, row, title) { ws.mergeCells(`B${row}:C${row}`); setDark(ws.getCell(`B${row}`), title); for (let c = 4; c <= 12; c++) { ws.getCell(row, c).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF3F3F3F' } }; ws.getCell(row, c).border = { top: { style: 'thin', color: { argb: 'FF808080' } }, bottom: { style: 'thin', color: { argb: 'FF808080' } } }; } }
function fillRow(ws, row, a, b, color, bold = false) { for (let c = a; c <= b; c++) { const cell = ws.getCell(row, c); cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: color } }; cell.alignment = { horizontal: 'center', vertical: 'middle' }; if (bold) cell.font = { ...(cell.font || {}), bold: true }; cell.border = { top: { style: 'thin', color: { argb: 'FFBFBFBF' } }, bottom: { style: 'thin', color: { argb: 'FFBFBFBF' } } }; } }
function dataRow(ws, row, emph = false) { ws.getRow(row).eachCell((cell, c) => { cell.alignment = { vertical: 'middle', horizontal: c >= 4 && c <= 11 ? 'center' : 'left' }; cell.border = { bottom: { style: 'hair', color: { argb: 'FFD9D9D9' } } }; if (emph) { cell.font = { ...(cell.font || {}), bold: true }; if (c >= 3) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF2F2F2' } }; } }); }
function pdfSecao(doc, titulo) { doc.fillColor('#333333').fontSize(10).font('Helvetica-Bold').text(titulo, 48, doc.y, { width: 500 }); doc.moveDown(0.2); }
function pdfCabecalho(doc, cols, widths) { const y = doc.y; doc.rect(48, y, 499, 16).fill('#185FA5'); let x = 52; cols.forEach((col, i) => { doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold').text(col, x, y + 4, { width: widths[i], lineBreak: false }); x += widths[i]; }); doc.y = y + 18; }
function pdfLinha(doc, vals, widths, idx) { const y = doc.y; if (idx % 2 === 1) doc.rect(48, y, 499, 15).fill('#F5F8FC'); let x = 52; vals.forEach((val, i) => { doc.fillColor('#333333').fontSize(8).font('Helvetica').text(String(val ?? '-'), x, y + 3, { width: widths[i], lineBreak: false }); x += widths[i]; }); doc.y = y + 16; }
function groupBy(arr, key) { return arr.reduce((a, x) => ((a[x[key]] = a[x[key]] || []).push(x), a), {}); }
function n(v) { return Number(v) || 0; }
function sum(arr, fn) { return (arr || []).reduce((s, x) => s + (fn(x) || 0), 0); }
function pd(v) {
  if (v instanceof Date) {
    return new Date(v.getUTCFullYear(), v.getUTCMonth(), v.getUTCDate(), 12, 0, 0);
  }
  const [y, m, d] = String(v).slice(0, 10).split('-').map(Number);
  return new Date(y, (m || 1) - 1, d || 1, 12, 0, 0);
}
function fmtData(v) { return v ? pd(v).toLocaleDateString('pt-PT') : '-'; }
function isoWeek(date) { const t = new Date(date.getFullYear(), date.getMonth(), date.getDate()); const dn = (t.getDay() + 6) % 7; t.setDate(t.getDate() - dn + 3); const y = t.getFullYear(); const f = new Date(y, 0, 4); const fd = (f.getDay() + 6) % 7; f.setDate(f.getDate() - fd + 3); const week = 1 + Math.round((t - f) / 604800000); const start = addD(date, -((date.getDay() + 6) % 7)); return { key: `${y}-W${String(week).padStart(2, '0')}`, week, start }; }
function addD(d, nDays) { const r = new Date(d); r.setDate(r.getDate() + nDays); return r; }
function diff(a, b) { return Math.round((pd(b) - pd(a)) / 86400000); }
function wd(d) { return new Intl.DateTimeFormat('pt-PT', { weekday: 'short' }).format(d).replace('.', '').replace(/^\w/, (c) => c.toUpperCase()); }
function iso(d) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; }
function colL(c) { let s = ''; while (c > 0) { const m = (c - 1) % 26; s = String.fromCharCode(65 + m) + s; c = Math.floor((c - m) / 26); } return s; }
function rate(snap, total, qty) { const s = Number(snap); if (Number.isFinite(s) && s > 0) return s; const q = n(qty), t = n(total); return q > 0 ? t / q : null; }
function responsavel(cargo) { return /(encarreg|engenh|chef|respons|diret|supervis|coord)/i.test(String(cargo || '')); }
function calcDirectCost(d) { return sum(d.pessoas, (x) => n(x.custo_total) + n(x.custo_extra)) + sum(d.maquinas, (x) => n(x.custo_total)) + n(d.valor_combustivel) + sum(d.viaturas, (x) => n(x.custo_total)) + n(d.valor_estadias) + n(d.valor_materiais) + n(d.valor_refeicoes); }
function sheet(v) { return String(v).replace(/[\\/*?:[\]]/g, ' ').slice(0, 31); }
function safeName(v) { return String(v || 'obra').replace(/[^\w.-]+/g, '_'); }

module.exports = { exportarExcel, exportarPdf };
