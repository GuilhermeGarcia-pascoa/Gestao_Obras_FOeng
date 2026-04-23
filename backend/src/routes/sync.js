/**
 * src/routes/sync.js
 *
 * Rotas de sincronização fo_panel → appdb
 *
 * GET  /api/sync/status   — estado e estatísticas (requer auth)
 * POST /api/sync/agora    — força sync manual (requer gestor/admin)
 */

const router = require('express').Router();
const { correrSync, estado } = require('../services/syncFoPanel');
const { auth, soGestor }     = require('../middleware/auth');

// ── GET /api/sync/status ───────────────────────────────────────────────────
// Qualquer utilizador autenticado pode ver o estado do sync
router.get('/status', auth, (req, res) => {
  const intervalo = parseInt(process.env.FOPANEL_SYNC_INTERVAL_MINUTES || '30');

  res.json({
    ultimoSync:          estado.ultimoSync,
    ultimoErro:          estado.ultimoErro,
    emExecucao:          estado.emExecucao,
    totalInseridas:      estado.totalInseridas,
    totalActualizadas:   estado.totalActualizadas,
    totalIgnoradas:      estado.totalIgnoradas,
    intervaloMinutos:    intervalo,
    proximoSync: estado.ultimoSync
      ? new Date(new Date(estado.ultimoSync).getTime() + intervalo * 60000).toISOString()
      : null,
  });
});

// ── POST /api/sync/agora ───────────────────────────────────────────────────
// Só gestores/admins podem forçar sync manual
router.post('/agora', auth, soGestor, async (req, res) => {
  try {
    const resultado = await correrSync();

    if (resultado.ignorado) {
      return res.status(409).json({ ok: false, motivo: resultado.motivo });
    }

    res.json({
      ok:         true,
      syncedAt:   estado.ultimoSync,
      inseridas:  resultado.inseridas,
      actualizadas: resultado.actualizadas,
      ignoradas:  resultado.ignoradas,
      erros:      resultado.erros,
    });
  } catch (err) {
    res.status(500).json({ ok: false, erro: err.message });
  }
});

module.exports = router;
