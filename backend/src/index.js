const express = require('express');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const logger = require('./utils/logger');
const { errorHandler, authErrorHandler } = require('./middleware/errorHandler');
const { handleUploadError } = require('./config/upload');

// Rotas
const authRoutes = require('./routes/auth');
const utilizadoresRoutes = require('./routes/utilizadores');
const projetosRoutes = require('./routes/projetos');
const nosRoutes = require('./routes/nos');
const camposRoutes = require('./routes/campos');
const registosRoutes = require('./routes/registos');
const utilizadorProjetoRoutes = require('./routes/utilizador_projeto');
const utilizadorNoRoutes = require('./routes/utilizador_no');
const databaseRoutes = require('./routes/database');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── CRIAR PASTA UPLOADS SE NÃO EXISTIR ────────────────────
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  logger.info(`Pasta de uploads criada: ${uploadsDir}`);
}

// ─── MIDDLEWARES ───────────────────────────────────────────

// HELMET - CSP configurado para permitir Google Fonts e Font Awesome
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "cdnjs.cloudflare.com"],
      styleSrc: ["'self'", "'unsafe-inline'", "fonts.googleapis.com", "cdnjs.cloudflare.com"],
      fontSrc: ["'self'", "fonts.gstatic.com", "cdnjs.cloudflare.com"],
      imgSrc: ["'self'", "data:", "blob:"],
      connectSrc: ["'self'"],
    },
  },
  crossOriginEmbedderPolicy: false, // Evita problemas com recursos externos
}));

app.use(compression());

// CORS - permitir o frontend (definir FRONTEND_URL no .env em produção)
app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  credentials: true,
}));

app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));

// ─── SERVIR UPLOADS COM SEGURANÇA ──────────────────────────
// Apenas servir ficheiros estáticos, sem permitir execução de scripts
app.use('/uploads', express.static('uploads', {
  dotfiles: 'deny', // Não servir ficheiros ocultos (.htaccess, .env, etc)
  index: false      // Não servir listagem de diretório
}));

// ─── ROTAS ─────────────────────────────────────────────────
app.use('/api/login', authRoutes);
app.use('/api/utilizadores', utilizadoresRoutes);
app.use('/api/projetos', projetosRoutes);
app.use('/api/nos', nosRoutes);
app.use('/api/campos', camposRoutes);
app.use('/api/registos', registosRoutes);
app.use('/api/utilizador_projeto', utilizadorProjetoRoutes);
app.use('/api/utilizador_no', utilizadorNoRoutes);
app.use('/api/database', databaseRoutes);

// ─── ROTA DE HEALTH CHECK ──────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'API is running', timestamp: new Date().toISOString() });
});

// ─── TRATAMENTO DE ERROS ───────────────────────────────────
// Primeiro, capturar erros de upload (Multer)
app.use(handleUploadError);

// Depois, autenticação
app.use(authErrorHandler);

// Finalmente, tratamento de erros geral (SEMPRE POR ÚLTIMO)
app.use(errorHandler);

// ─── ROTA 404 ──────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Rota não encontrada' });
});

// ─── INICIAR SERVIDOR ──────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  logger.success(`🚀 API rodando em http://0.0.0.0:${PORT}`);
  logger.info(`Health check: http://localhost:${PORT}/api/health`);
});