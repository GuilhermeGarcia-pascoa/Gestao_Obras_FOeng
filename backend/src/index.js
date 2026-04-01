const path = require('path');
require('dotenv').config({ path: path.join(__dirname, 'env') });
const express = require('express');
const cors    = require('cors');

const authRouter      = require('./routes/auth');
const obrasRouter     = require('./routes/obras');
const semanasRouter   = require('./routes/semanas');
const equipaRouter    = require('./routes/equipa');
const relatoriosRouter = require('./routes/relatorios');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middlewares ────────────────────────────────────────────────────────────────
app.use(cors());                          // Permite pedidos do Flutter (mobile + web)
app.use(express.json());                  // Parse de JSON no body

// ── Rotas ─────────────────────────────────────────────────────────────────────
app.use('/api/auth',       authRouter);
app.use('/api/obras',      obrasRouter);
app.use('/api/semanas',    semanasRouter);
app.use('/api/equipa',     equipaRouter);
app.use('/api/relatorios', relatoriosRouter);

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/api/health', (_, res) => res.json({ status: 'ok', timestamp: new Date() }));

// ── Tratamento de erros ───────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ erro: 'Erro interno do servidor' });
});

// ── Arranque ──────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀  Servidor a correr em http://localhost:${PORT}`);
});
