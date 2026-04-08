const path = require('path');
require('dotenv').config({ path: path.join(__dirname, 'env') });
const express = require('express');
const cors = require('cors');
const readline = require('readline');
const os = require('os');

const authRouter = require('./routes/auth');
const obrasRouter = require('./routes/obras');
const diasRouter = require('./routes/dias');
const equipaRouter = require('./routes/equipa');
const relatoriosRouter = require('./routes/relatorios');
const adminRouter = require('./routes/admin');
const { exportarExcel, exportarPdf } = require('./routes/export');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middlewares ────────────────────────────────────────────────────
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// ── Rotas ──────────────────────────────────────────────────────────
app.use('/api/auth', authRouter);
app.use('/api/obras', obrasRouter);
app.use('/api/dias', diasRouter);
app.use('/api/equipa', equipaRouter);
app.use('/api/relatorios', relatoriosRouter);
app.use('/api/admin', adminRouter);

// ── Exportações ────────────────────────────────────────────────────
app.get('/api/export/excel/:obraId', exportarExcel);
app.get('/api/export/pdf', exportarPdf);

// ── Health check ───────────────────────────────────────────────────
app.get('/api/health', (_, res) => res.json({ status: 'ok', timestamp: new Date() }));

// ── Tratamento de erros ────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ erro: 'Erro interno do servidor' });
});

// ── Arranque do Servidor ───────────────────────────────────────────
let server;

function iniciarServidor() {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`[INFO] Servidor iniciado na porta ${PORT}`);
    console.log(`[INFO] Endereço local: http://localhost:${PORT}`);
    console.log(`[INFO] Digite 'help' para listar os comandos disponíveis.\n`);
    iniciarCLI();
  });
}

// ── CLI ────────────────────────────────────────────────────────────
function iniciarCLI() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: 'server> ' });
  rl.prompt();
  rl.on('line', (line) => {
    const comando = line.trim().toLowerCase();
    switch (comando) {
      case 'help':
        console.log(`
  Comandos:
    help    - Esta lista
    ip      - Endereços IPv4
    status  - Uptime e memória
    clear   - Limpar consola
    restart - Reiniciar servidor
    exit    - Encerrar
        `);
        break;
      case 'ip':
        const interfaces = os.networkInterfaces();
        console.log('\n[INFO] Endereços IPv4:');
        for (const nome in interfaces) {
          for (const net of interfaces[nome]) {
            if (net.family === 'IPv4' && !net.internal) console.log(`  - ${nome}: ${net.address}`);
          }
        }
        console.log('');
        break;
      case 'status':
        const ramLivre = (os.freemem() / (1024 * 1024)).toFixed(2);
        const ramTotal = (os.totalmem() / (1024 * 1024)).toFixed(2);
        const uptime = process.uptime();
        console.log(`\n[STATUS] Uptime: ${Math.floor(uptime/3600)}h ${Math.floor((uptime%3600)/60)}m  |  RAM livre: ${ramLivre}MB / ${ramTotal}MB\n`);
        break;
      case 'clear':
        console.clear();
        break;
      case 'restart':
        console.log('\n[INFO] A reiniciar...');
        server.close(() => {
          server = app.listen(PORT, '0.0.0.0', () => {
            console.log(`[INFO] Servidor reiniciado na porta ${PORT}.\n`);
            rl.prompt();
          });
        });
        return;
      case 'exit':
      case 'quit':
        console.log('\n[INFO] A encerrar...');
        server.close(() => { console.log('[INFO] Servidor encerrado.'); process.exit(0); });
        return;
      case '':
        break;
      default:
        console.log(`[WARNING] Comando não reconhecido: '${comando}'. Digite 'help'.\n`);
    }
    rl.prompt();
  }).on('close', () => { process.exit(0); });
}

iniciarServidor();