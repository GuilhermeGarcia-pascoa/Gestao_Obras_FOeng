/**
 * src/services/syncFoPanel.js
 *
 * Serviço de sincronização fo_panel → appdb (obras).
 * Busca todos os projetos com projects_types_id = OBRA_TYPE_ID
 * e insere/actualiza na tabela obras do appdb.
 *
 * Usado por:
 *   - src/routes/sync.js        (trigger manual via API)
 *   - src/index.js              (arranque automático + intervalo)
 */

const pool        = require('../db/pool');        // appdb
const poolFoPanel = require('../db/poolFoPanel'); // fo_panel

// ─── Estado global do serviço ────────────────────────────────────────────────

const estado = {
  ultimoSync:    null,   // ISO string
  ultimoErro:    null,   // mensagem de erro
  emExecucao:    false,
  totalInseridas: 0,
  totalActualizadas: 0,
  totalIgnoradas: 0,
};

// ─── Mapeamento de status fo_panel → appdb ───────────────────────────────────
// Podes ajustar conforme os valores reais da tua tabela projects_status:
//   SELECT id, name FROM fo_panel.projects_status;

function mapEstado(statusId) {
  const MAP = {
    1: 'planeada',
    2: 'em_curso',
    3: 'em_curso',
    4: 'concluida',
  };
  return MAP[statusId] ?? 'planeada';
}

// ─── Garantir colunas de sync na tabela obras ────────────────────────────────

async function garantirColunas() {
  const colunas = [
    ['fo_panel_id',        'INT DEFAULT NULL'],
    ['fo_panel_cliente',   'TEXT DEFAULT NULL'],
    ['fo_panel_synced_at', 'DATETIME DEFAULT NULL'],
  ];
  for (const [col, def] of colunas) {
    await pool.query(`ALTER TABLE obras ADD COLUMN ${col} ${def}`)
      .catch(() => {}); // ignora se a coluna já existe
  }
}

// ─── Lógica principal ────────────────────────────────────────────────────────

async function correrSync() {
  if (estado.emExecucao) {
    return { ignorado: true, motivo: 'Sync já em curso' };
  }

  estado.emExecucao = true;
  const stats = { inseridas: 0, actualizadas: 0, ignoradas: 0, erros: [] };

  try {
    await garantirColunas();

    const obraTypeId = parseInt(process.env.FOPANEL_OBRA_TYPE_ID || '3');

    // 1. Buscar obras na fo_panel
    const [projetos] = await poolFoPanel.query(`
      SELECT
        p.id,
        p.name,
        p.ccusto,
        p.cliente,
        p.valor_estimado,
        p.projects_status_id,
        p.in_trash
      FROM projects p
      WHERE p.projects_types_id = ?
        AND (p.in_trash IS NULL OR p.in_trash = 0)
      ORDER BY p.id
    `, [obraTypeId]);

    console.log(`[SYNC] ${projetos.length} obras encontradas na fo_panel`);

    // 2. Buscar obras existentes no appdb que vieram da fo_panel
    const [existentes] = await pool.query(
      'SELECT id, fo_panel_id, codigo, nome, estado, orcamento FROM obras WHERE fo_panel_id IS NOT NULL'
    );
    const mapaExistentes = new Map(existentes.map(r => [r.fo_panel_id, r]));

    // 3. Processar cada projeto
    for (const proj of projetos) {
      try {
        const codigo    = (proj.ccusto || '').trim() || `FO-${proj.id}`;
        const nome      = (proj.name   || '').trim();
        const orcamento = proj.valor_estimado ? parseFloat(proj.valor_estimado) : null;
        const estadoVal = mapEstado(proj.projects_status_id);
        const cliente   = (proj.cliente || '').trim() || null;
        const syncedAt  = new Date().toISOString().slice(0, 19).replace('T', ' ');

        const existente = mapaExistentes.get(proj.id);

        if (existente) {
          // Verificar se há alterações
          const mudou =
            existente.nome   !== nome     ||
            existente.estado !== estadoVal ||
            String(existente.orcamento ?? '') !== String(orcamento ?? '');

          if (mudou) {
            await pool.query(`
              UPDATE obras
              SET nome = ?, codigo = ?, estado = ?, orcamento = ?,
                  fo_panel_cliente = ?, fo_panel_synced_at = ?
              WHERE fo_panel_id = ?
            `, [nome, codigo, estadoVal, orcamento, cliente, syncedAt, proj.id]);
            stats.actualizadas++;
          } else {
            stats.ignoradas++;
          }

        } else {
          // Ver se já existe obra com o mesmo código (criada manualmente)
          const [[porCodigo]] = await pool.query(
            'SELECT id FROM obras WHERE codigo = ? AND fo_panel_id IS NULL LIMIT 1',
            [codigo]
          );

          if (porCodigo) {
            // Ligar registo manual existente ao fo_panel
            await pool.query(`
              UPDATE obras
              SET fo_panel_id = ?, nome = ?, estado = ?, orcamento = ?,
                  fo_panel_cliente = ?, fo_panel_synced_at = ?
              WHERE id = ?
            `, [proj.id, nome, estadoVal, orcamento, cliente, syncedAt, porCodigo.id]);
            stats.actualizadas++;
            console.log(`[SYNC] Ligada obra existente: [${codigo}] ${nome}`);
          } else {
            // Inserir nova
            await pool.query(`
              INSERT INTO obras
                (codigo, nome, tipo, estado, orcamento, fo_panel_id, fo_panel_cliente, fo_panel_synced_at)
              VALUES (?, ?, 'fo_panel', ?, ?, ?, ?, ?)
            `, [codigo, nome, estadoVal, orcamento, proj.id, cliente, syncedAt]);
            stats.inseridas++;
            console.log(`[SYNC] Nova obra: [${codigo}] ${nome}`);
          }
        }

      } catch (erroLinha) {
        stats.erros.push({ fo_panel_id: proj.id, erro: erroLinha.message });
        console.error(`[SYNC] Erro na obra fo_panel_id=${proj.id}:`, erroLinha.message);
      }
    }

    // Actualizar estado global
    estado.ultimoSync        = new Date().toISOString();
    estado.ultimoErro        = null;
    estado.totalInseridas   += stats.inseridas;
    estado.totalActualizadas += stats.actualizadas;
    estado.totalIgnoradas   += stats.ignoradas;

    console.log(`[SYNC] Concluído — ${stats.inseridas} inseridas, ${stats.actualizadas} actualizadas, ${stats.ignoradas} sem alterações`);
    if (stats.erros.length) console.warn(`[SYNC] ${stats.erros.length} erros`);

    return stats;

  } catch (err) {
    estado.ultimoErro = err.message;
    console.error('[SYNC] Erro geral:', err.message);
    throw err;
  } finally {
    estado.emExecucao = false;
  }
}

// ─── Arranque com intervalo automático ───────────────────────────────────────

function iniciarSyncAutomatico() {
  const intervaloMinutos = parseInt(process.env.FOPANEL_SYNC_INTERVAL_MINUTES || '30');

  // Primeira sync 5 segundos após o servidor arrancar (para não bloquear o boot)
  setTimeout(() => {
    console.log('[SYNC] A executar primeira sincronização...');
    correrSync().catch(err => console.error('[SYNC] Erro no sync inicial:', err.message));
  }, 5000);

  // Sync periódico
  setInterval(() => {
    console.log('[SYNC] Sync automático...');
    correrSync().catch(err => console.error('[SYNC] Erro no sync automático:', err.message));
  }, intervaloMinutos * 60 * 1000);

  console.log(`[SYNC] Sincronização automática configurada (intervalo: ${intervaloMinutos} min)`);
}

module.exports = { correrSync, iniciarSyncAutomatico, estado };
