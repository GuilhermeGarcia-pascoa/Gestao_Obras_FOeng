const { validarEnv } = require('./config/env');

const { isProduction } = validarEnv();

const express = require('express');
const cors = require('cors');
const readline = require('readline');
const os = require('os');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

const authRouter = require('./routes/auth');
const obrasRouter = require('./routes/obras');
const diasRouter = require('./routes/dias');
const equipaRouter = require('./routes/equipa');
const relatoriosRouter = require('./routes/relatorios');
const adminRouter = require('./routes/admin');
const syncRouter = require('./routes/sync');
const { exportarExcel, exportarPdf } = require('./routes/export');
const { auth, soGestor } = require('./middleware/auth');
const { rateLimitGlobal } = require('./middleware/rateLimit');
const { iniciarSyncAutomatico } = require('./services/syncFoPanel');
const pool = require('./db/pool');

const app = express();
const PORT = process.env.PORT || 3000;

const origensPermitidas = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origem) => origem.trim())
  .filter(Boolean);

const corsOptions = {
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true);
    }

    if (origensPermitidas.includes(origin)) {
      return callback(null, true);
    }

    return callback(null, false);
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

app.set('trust proxy', 1);

// Seguranca HTTP headers
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'blob:'],
      connectSrc: ["'self'"],
    },
  },
}));
console.log('[INFO] Helmet ativo (headers de seguranca HTTP)');

// Compressao gzip
app.use(compression());
console.log('[INFO] Compressao gzip ativa');

// Logging HTTP
app.use(morgan(isProduction ? 'combined' : 'dev'));

// CORS
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

// Body parser
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: false }));

// Rate limit global
app.use(rateLimitGlobal);

// Rotas
app.use('/api/auth', authRouter);
app.use('/api/obras', obrasRouter);
app.use('/api/dias', diasRouter);
app.use('/api/equipa', equipaRouter);
app.use('/api/relatorios', relatoriosRouter);
app.use('/api/admin', adminRouter);
app.use('/api/sync', syncRouter);

// Exportacoes protegidas
const exportRouter = require('express').Router();
exportRouter.use(auth);
exportRouter.get('/excel/:obraId', soGestor, exportarExcel);
exportRouter.get('/pdf', soGestor, exportarPdf);
app.use('/api/export', exportRouter);

// Health check
app.get('/api/health', async (_, res) => {
  const basePayload = {
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    version: process.env.npm_package_version || null,
  };

  try {
    await Promise.race([
      pool.query('SELECT 1'),
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error('DB healthcheck timeout')), 100);
      }),
    ]);

    return res.json(basePayload);
  } catch (err) {
    console.error('[HEALTH]', err.message);
    return res.status(503).json({
      ...basePayload,
      status: 'error',
    });
  }
});

// 404 para rotas desconhecidas
app.use((req, res) => {
  res.status(404).json({ erro: `Rota nao encontrada: ${req.method} ${req.path}` });
});

// Tratamento global de erros
app.use((err, req, res, _next) => {
  console.error('[ERRO]', err.message);
  if (!isProduction) {
    console.error(err.stack);
  }
  res.status(500).json({ erro: 'Erro interno do servidor' });
});

// Arranque
let server;

function iniciarServidor() {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n[INFO] Servidor iniciado na porta ${PORT}`);
    console.log(`[INFO] Ambiente: ${isProduction ? 'production' : 'development'}`);
    if (!isProduction) {
      console.log(`[INFO] Endereco local: http://localhost:${PORT}`);
      console.log("[INFO] Digite 'help' para listar os comandos disponiveis.\n");
      iniciarCLI();
    }
    iniciarSyncAutomatico();
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[ERRO] A porta ${PORT} ja esta em uso. Escolhe outra em .env (PORT=3001)`);
    } else {
      console.error('[ERRO] Falha ao iniciar servidor:', err.message);
    }
    process.exit(1);
  });
}

// CLI interativo
function iniciarCLI() {
  if (isProduction) return;

  // Nao iniciar CLI se nao houver terminal interativo (ex: PM2, Docker)
  if (!process.stdin.isTTY) return;

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: 'server> ',
  });

  rl.prompt();

  rl.on('line', (line) => {
    const cmd = line.trim().toLowerCase();
    switch (cmd) {
      case 'help':
        console.log(`
  Comandos disponiveis:
    help    - Esta lista
    ip      - Enderecos IPv4 da maquina
    status  - Uptime e memoria
    env     - Variaveis de ambiente carregadas (sem valores sensiveis)
    clear   - Limpar consola
    restart - Reiniciar servidor
    exit    - Encerrar
        `);
        break;

      case 'ip': {
        const interfaces = os.networkInterfaces();
        console.log('\n[INFO] Enderecos IPv4:');
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
        const ramLivre = (os.freemem() / (1024 * 1024)).toFixed(2);
        const ramTotal = (os.totalmem() / (1024 * 1024)).toFixed(2);
        const uptime = process.uptime();
        const horas = Math.floor(uptime / 3600);
        const minutos = Math.floor((uptime % 3600) / 60);
        const segundos = Math.floor(uptime % 60);
        console.log(`\n[STATUS] Uptime: ${horas}h ${minutos}m ${segundos}s  |  RAM livre: ${ramLivre}MB / ${ramTotal}MB\n`);
        break;
      }

      case 'env':
        console.log('\n[ENV] Variaveis carregadas:');
        console.log(`  DB_HOST      = ${process.env.DB_HOST || '(nao definido)'}`);
        console.log(`  DB_NAME      = ${process.env.DB_NAME || '(nao definido)'}`);
        console.log(`  DB_PORT      = ${process.env.DB_PORT || '3306'}`);
        console.log(`  PORT         = ${process.env.PORT || '3000'}`);
        console.log(`  NODE_ENV     = ${isProduction ? 'production' : 'development'}`);
        console.log(`  CORS_ORIGINS = ${process.env.CORS_ORIGINS || '(nao definido)'}`);
        console.log(`  FOPANEL_HOST = ${process.env.FOPANEL_HOST || '(nao definido)'}`);
        console.log(`  JWT_SECRET   = ${'*'.repeat(Math.min((process.env.JWT_SECRET || '').length, 8))} (oculto)\n`);
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
        console.log(`[AVISO] Comando nao reconhecido: '${cmd}'. Digite 'help'.\n`);
    }

    rl.prompt();
  });

  rl.on('close', () => process.exit(0));
}

iniciarServidor();
