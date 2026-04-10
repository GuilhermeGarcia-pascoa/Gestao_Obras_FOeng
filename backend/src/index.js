const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

// Validar variáveis de ambiente obrigatórias antes de arrancar
const varObrigatorias = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME', 'JWT_SECRET'];
for (const v of varObrigatorias) {
  if (!process.env[v]) {
    console.error(`[ERRO FATAL] Variável de ambiente obrigatória em falta: ${v}`);
    console.error('Cria o ficheiro backend/.env com base no backend/.env.example');
    process.exit(1);
  }
}

// Aviso se JWT_SECRET for fraco (desenvolvimento)
if (process.env.JWT_SECRET && process.env.JWT_SECRET.length < 32) {
  console.warn('[AVISO] JWT_SECRET é demasiado curto. Use pelo menos 32 caracteres em produção.');
}

const express    = require('express');
const cors       = require('cors');
const readline   = require('readline');
const os         = require('os');

// Middlewares de segurança e performance — instala com:
// npm install helmet compression morgan
let helmet, compression, morgan;
try { helmet      = require('helmet');      } catch (_) { helmet      = null; }
try { compression = require('compression'); } catch (_) { compression = null; }
try { morgan      = require('morgan');      } catch (_) { morgan      = null; }

const authRouter       = require('./routes/auth');
const obrasRouter      = require('./routes/obras');
const diasRouter       = require('./routes/dias');
const equipaRouter     = require('./routes/equipa');
const relatoriosRouter = require('./routes/relatorios');
const adminRouter      = require('./routes/admin');
const { exportarExcel, exportarPdf } = require('./routes/export');
const { auth, soGestor } = require('./middleware/auth');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Segurança HTTP headers ─────────────────────────────────────────────────
if (helmet) {
  app.use(helmet({
    crossOriginEmbedderPolicy: false, // Necessário para Flutter web
    contentSecurityPolicy: false,     // Ajustar se houver frontend servido pelo Express
  }));
  console.log('[INFO] Helmet ativo (headers de segurança HTTP)');
} else {
  console.warn('[AVISO] Helmet não instalado. Corre: npm install helmet');
}

// ── Compressão gzip ────────────────────────────────────────────────────────
if (compression) {
  app.use(compression());
  console.log('[INFO] Compressão gzip ativa');
} else {
  console.warn('[AVISO] Compression não instalado. Corre: npm install compression');
}

// ── Logging HTTP ───────────────────────────────────────────────────────────
if (morgan) {
  // Em produção usa 'combined', em dev usa 'dev'
  const formato = process.env.NODE_ENV === 'production' ? 'combined' : 'dev';
  app.use(morgan(formato));
} else {
  console.warn('[AVISO] Morgan não instalado. Corre: npm install morgan');
}

// ── CORS ───────────────────────────────────────────────────────────────────
const origensPermitidas = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(o => o.trim())
  : '*'; // Em produção define CORS_ORIGINS=https://teu-dominio.com

app.use(cors({
  origin: origensPermitidas,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ── Body parser ────────────────────────────────────────────────────────────
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: false }));

// ── Rotas ──────────────────────────────────────────────────────────────────
app.use('/api/auth',       authRouter);
app.use('/api/obras',      obrasRouter);
app.use('/api/dias',       diasRouter);
app.use('/api/equipa',     equipaRouter);
app.use('/api/relatorios', relatoriosRouter);
app.use('/api/admin',      adminRouter);

// ── Exportações ────────────────────────────────────────────────────────────
// ── Exportações (protegidas — requerem gestor ou admin) ────────────────────
const exportRouter = require('express').Router();
exportRouter.use(auth);
exportRouter.get('/excel/:obraId', soGestor, exportarExcel);
exportRouter.get('/pdf',           soGestor, exportarPdf);
app.use('/api/export', exportRouter);

// ── Health check ───────────────────────────────────────────────────────────
app.get('/api/health', (_, res) => {
  res.json({
    status:    'ok',
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
    env:       process.env.NODE_ENV || 'development',
  });
});

// ── 404 para rotas desconhecidas ───────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ erro: `Rota não encontrada: ${req.method} ${req.path}` });
});

// ── Tratamento de erros global ─────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error('[ERRO]', err.message);
  if (process.env.NODE_ENV !== 'production') {
    console.error(err.stack);
  }
  res.status(500).json({ erro: 'Erro interno do servidor' });
});

// ── Arranque ───────────────────────────────────────────────────────────────
let server;

function iniciarServidor() {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n[INFO] Servidor iniciado na porta ${PORT}`);
    console.log(`[INFO] Ambiente: ${process.env.NODE_ENV || 'development'}`);
    console.log(`[INFO] Endereço local: http://localhost:${PORT}`);
    console.log(`[INFO] Digite 'help' para listar os comandos disponíveis.\n`);
    iniciarCLI();
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[ERRO] A porta ${PORT} já está em uso. Escolhe outra em .env (PORT=3001)`);
    } else {
      console.error('[ERRO] Falha ao iniciar servidor:', err.message);
    }
    process.exit(1);
  });
}

// ── CLI interativo ─────────────────────────────────────────────────────────
function iniciarCLI() {
  // Não iniciar CLI se não houver terminal interativo (ex: PM2, Docker)
  if (!process.stdin.isTTY) return;

  const rl = readline.createInterface({
    input:  process.stdin,
    output: process.stdout,
    prompt: 'server> ',
  });

  rl.prompt();

  rl.on('line', (line) => {
    const cmd = line.trim().toLowerCase();
    switch (cmd) {
      case 'help':
        console.log(`
  Comandos disponíveis:
    help    — Esta lista
    ip      — Endereços IPv4 da máquina
    status  — Uptime e memória
    env     — Variáveis de ambiente carregadas (sem valores sensíveis)
    clear   — Limpar consola
    restart — Reiniciar servidor
    exit    — Encerrar
        `);
        break;

      case 'ip': {
        const interfaces = os.networkInterfaces();
        console.log('\n[INFO] Endereços IPv4:');
        for (const nome in interfaces) {
          for (const net of interfaces[nome]) {
            if (net.family === 'IPv4' && !net.internal) {
              console.log(`  - ${nome}: ${net.address}`);
            }
          }
        }
        console.log('');
        break;
      }

      case 'status': {
        const ramLivre  = (os.freemem()  / (1024 * 1024)).toFixed(2);
        const ramTotal  = (os.totalmem() / (1024 * 1024)).toFixed(2);
        const uptime    = process.uptime();
        const horas     = Math.floor(uptime / 3600);
        const minutos   = Math.floor((uptime % 3600) / 60);
        const segundos  = Math.floor(uptime % 60);
        console.log(`\n[STATUS] Uptime: ${horas}h ${minutos}m ${segundos}s  |  RAM livre: ${ramLivre}MB / ${ramTotal}MB\n`);
        break;
      }

      case 'env':
        console.log('\n[ENV] Variáveis carregadas:');
        console.log(`  DB_HOST   = ${process.env.DB_HOST   || '(não definido)'}`);
        console.log(`  DB_NAME   = ${process.env.DB_NAME   || '(não definido)'}`);
        console.log(`  DB_PORT   = ${process.env.DB_PORT   || '3306'}`);
        console.log(`  PORT      = ${process.env.PORT      || '3000'}`);
        console.log(`  NODE_ENV  = ${process.env.NODE_ENV  || 'development'}`);
        console.log(`  JWT_SECRET= ${'*'.repeat(Math.min((process.env.JWT_SECRET || '').length, 8))} (oculto)\n`);
        break;

      case 'clear':
        console.clear();
        break;

      case 'restart':
        console.log('\n[INFO] A reiniciar servidor...');
        server.close(() => {
          server = app.listen(PORT, '0.0.0.0', () => {
            console.log(`[INFO] Servidor reiniciado na porta ${PORT}.\n`);
            rl.prompt();
          });
        });
        return;

      case 'exit':
      case 'quit':
        console.log('\n[INFO] A encerrar servidor...');
        server.close(() => {
          console.log('[INFO] Servidor encerrado.');
          process.exit(0);
        });
        return;

      case '':
        break;

      default:
        console.log(`[AVISO] Comando não reconhecido: '${cmd}'. Digite 'help'.\n`);
    }

    rl.prompt();
  });

  rl.on('close', () => process.exit(0));
}

iniciarServidor();