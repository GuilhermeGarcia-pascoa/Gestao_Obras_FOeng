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
const { auth } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middlewares ────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

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
  console.error('[ERROR] Erro interno:', err.stack);
  res.status(500).json({ erro: 'Erro interno do servidor' });
});

// ── Arranque do Servidor ───────────────────────────────────────────
let server;

function iniciarServidor() {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`[INFO] Servidor iniciado na porta ${PORT}`);
    console.log(`[INFO] Endereço local: http://localhost:${PORT}`);
    console.log(`[INFO] Endereço de rede: http://0.0.0.0:${PORT}`);
    console.log(`[INFO] Digite 'help' para listar os comandos disponíveis.\n`);
    
    iniciarCLI();
  });
}

// ── Interface de Linha de Comandos (CLI) ───────────────────────────
function iniciarCLI() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: 'server> '
  });

  rl.prompt();

  rl.on('line', (line) => {
    const comando = line.trim().toLowerCase();

    switch (comando) {
      case 'help':
        console.log(`
  Comandos Disponíveis:
    help    - Exibe esta lista de comandos
    ip      - Lista os endereços IPv4 da máquina
    status  - Exibe o tempo de atividade e uso de memória
    clear   - Limpa a consola
    restart - Reinicia o processo de escuta HTTP
    exit    - Encerra o servidor de forma segura
        `);
        break;

      case 'ip':
        const interfaces = os.networkInterfaces();
        console.log('\n[INFO] Endereços IPv4 detectados:');
        for (const nome in interfaces) {
          for (const net of interfaces[nome]) {
            if (net.family === 'IPv4' && !net.internal) {
              console.log(`  - ${nome}: ${net.address}`);
            }
          }
        }
        console.log('');
        break;

      case 'status':
        const ramLivre = (os.freemem() / (1024 * 1024)).toFixed(2);
        const ramTotal = (os.totalmem() / (1024 * 1024)).toFixed(2);
        const uptimeSegundos = process.uptime();
        const horas = Math.floor(uptimeSegundos / 3600);
        const minutos = Math.floor((uptimeSegundos % 3600) / 60);

        console.log(`\n[STATUS] Informações do Sistema:`);
        console.log(`  - Uptime:  ${horas}h ${minutos}m`);
        console.log(`  - Memória: ${ramLivre} MB livres de ${ramTotal} MB\n`);
        break;

      case 'clear':
        console.clear();
        break;

      case 'restart':
        console.log('\n[INFO] A reiniciar o servidor HTTP...');
        server.close(() => {
          console.log('[INFO] Ligações atuais encerradas. A iniciar novamente...');
          server = app.listen(PORT, '0.0.0.0', () => {
            console.log(`[INFO] Servidor reiniciado com sucesso na porta ${PORT}.\n`);
            rl.prompt();
          });
        });
        return; // Evita mostrar o prompt antes da conclusão do callback

      case 'exit':
      case 'quit':
        console.log('\n[INFO] A iniciar encerramento seguro (Graceful Shutdown)...');
        server.close(() => {
          console.log('[INFO] Servidor encerrado. Processo terminado.');
          process.exit(0);
        });
        return;

      case '':
        break;

      default:
        console.log(`[WARNING] Comando não reconhecido: '${comando}'. Digite 'help' para ajuda.\n`);
        break;
    }
    
    rl.prompt();
  }).on('close', () => {
    console.log('\n[INFO] Interface de comandos terminada. A encerrar processo.');
    process.exit(0);
  });
}

// Iniciar a aplicação
iniciarServidor();