const { validarEnv } = require('./config/env');
const { isProduction } = validarEnv();

const express = require('express');
const cors = require('cors');
const readline = require('readline');
const os = require('os');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

// Routers
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

// --- CONFIGURAÇÃO DO CORS ---
const origensPermitidas = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origem) => origem.trim())
  .filter(Boolean);

const corsOptions = {
  origin(origin, callback) {
    // Permite requisições sem origin (como Apps Mobile ou Postman)
    if (!origin) return callback(null, true);

    // Verifica se o wildcard '*' está no .env OU se a origem está na lista
    const permitirTudo = origensPermitidas.includes('*');
    if (permitirTudo || origensPermitidas.includes(origin)) {
      return callback(null, true);
    }

    console.warn(`[CORS] Bloqueado: ${origin}`);
    return callback(new Error('Não permitido pela política CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};

app.set('trust proxy', 1);

// --- MIDDLEWARES GLOBAIS ---

// Segurança HTTP headers (CSP ajustado para Flutter Web)
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"], 
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'blob:'],
      // connectSrc: permite chamadas de API para qualquer lugar em dev ou apenas para o self
      connectSrc: ["'self'", "*"], 
      upgradeInsecureRequests: null, 
    },
  },
}));

console.log('[INFO] Helmet ativo (headers de seguranca HTTP)');

// Compressao gzip
app.use(compression());

// Logging HTTP
app.use(morgan(isProduction ? 'combined' : 'dev'));

// Aplicar CORS (IMPORTANTE: Antes das rotas)
app.use(cors(corsOptions));
app.options('*', cors(corsOptions)); // Trata o preflight de todas as rotas

// Body parser
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: false }));

// Rate limit global
app.use(rateLimitGlobal);

// --- ROTAS ---
app.use('/api/auth', authRouter);
app.use('/api/obras', obrasRouter);
app.use('/api/dias', diasRouter);
app.use('/api/equipa', equipaRouter);
app.use('/api/relatorios', relatoriosRouter);
app.use('/api/admin', adminRouter);
app.use('/api/sync', syncRouter);

// Exportações protegidas
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
        setTimeout(() => reject(new Error('DB healthcheck timeout')), 2000);
      }),
    ]);
    return res.json(basePayload);
  } catch (err) {
    console.error('[HEALTH]', err.message);
    return res.status(503).json({ ...basePayload, status: 'error' });
  }
});

// 404 para rotas desconhecidas
app.use((req, res) => {
  res.status(404).json({ erro: `Rota nao encontrada: ${req.method} ${req.path}` });
});

// Tratamento global de erros
app.use((err, req, res, _next) => {
  console.error('[ERRO]', err.message);
  if (!isProduction) console.error(err.stack);
  res.status(500).json({ erro: 'Erro interno do servidor' });
});

// --- ARRANQUE DO SERVIDOR ---
let server;

function iniciarServidor() {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n[INFO] Servidor iniciado na porta ${PORT}`);
    console.log(`[INFO] Ambiente: ${isProduction ? 'production' : 'development'}`);
    
    if (!isProduction) {
      console.log(`[INFO] Endereco local: http://localhost:${PORT}`);
      iniciarCLI();
    }
    iniciarSyncAutomatico();
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[ERRO] A porta ${PORT} ja esta em uso.`);
    } else {
      console.error('[ERRO] Falha ao iniciar servidor:', err.message);
    }
    process.exit(1);
  });
}

// CLI Interativo para Desenvolvimento
function iniciarCLI() {
  if (isProduction || !process.stdin.isTTY) return;

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
        console.log('\nComandos: help, ip, status, env, clear, restart, exit\n');
        break;
      case 'ip':
        const interfaces = os.networkInterfaces();
        for (const nome in interfaces) {
          for (const net of interfaces[nome]) {
            if (net.family === 'IPv4' && !net.internal) console.log(` - ${nome}: ${net.address}`);
          }
        }
        break;
      case 'status':
        console.log(`Uptime: ${process.uptime().toFixed(0)}s | RAM: ${(process.memoryUsage().rss / 1024 / 1024).toFixed(2)}MB`);
        break;
      case 'env':
        console.log(`PORT: ${PORT} | NODE_ENV: ${process.env.NODE_ENV} | CORS: ${process.env.CORS_ORIGINS}`);
        break;
      case 'clear':
        console.clear();
        break;
      case 'restart':
        server.close(() => iniciarServidor());
        return;
      case 'exit':
        process.exit(0);
        break;
    }
    rl.prompt();
  });
}

iniciarServidor();