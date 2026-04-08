const jwt = require('jsonwebtoken');

// ── Rate limiting simples em memória para login ────────────────────────────
// Sem dependências externas — funciona imediatamente
const tentativas = new Map(); // ip -> { count, bloqueadoAte }

const MAX_TENTATIVAS = 5;
const JANELA_MS      = 15 * 60 * 1000; // 15 minutos
const BLOQUEIO_MS    = 30 * 60 * 1000; // 30 minutos de bloqueio

function rateLimitLogin(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  const agora = Date.now();
  const registo = tentativas.get(ip);

  if (registo) {
    // Verifica se ainda está bloqueado
    if (registo.bloqueadoAte && agora < registo.bloqueadoAte) {
      const restam = Math.ceil((registo.bloqueadoAte - agora) / 60000);
      return res.status(429).json({
        erro: `Demasiadas tentativas. Tente novamente em ${restam} minuto(s).`
      });
    }

    // Janela expirou — reset
    if (agora - registo.inicio > JANELA_MS) {
      tentativas.delete(ip);
    }
  }

  next();
}

function registarFalhaLogin(ip) {
  const agora = Date.now();
  const registo = tentativas.get(ip) || { count: 0, inicio: agora, bloqueadoAte: null };

  // Janela expirou — reset
  if (agora - registo.inicio > JANELA_MS) {
    registo.count = 0;
    registo.inicio = agora;
    registo.bloqueadoAte = null;
  }

  registo.count += 1;

  if (registo.count >= MAX_TENTATIVAS) {
    registo.bloqueadoAte = agora + BLOQUEIO_MS;
  }

  tentativas.set(ip, registo);
}

function limparFalhasLogin(ip) {
  tentativas.delete(ip);
}

// ── Middleware JWT ─────────────────────────────────────────────────────────
function auth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) {
    return res.status(401).json({ erro: 'Token em falta' });
  }

  const partes = header.split(' ');
  if (partes.length !== 2 || partes[0] !== 'Bearer') {
    return res.status(401).json({ erro: 'Formato de token inválido' });
  }

  const token = partes[1];

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ erro: 'Sessão expirada. Faça login novamente.' });
    }
    return res.status(401).json({ erro: 'Token inválido' });
  }
}

// ── Middleware de autorização por role ─────────────────────────────────────
function soGestor(req, res, next) {
  if (!req.user || !['gestor', 'admin'].includes(req.user.role)) {
    return res.status(403).json({ erro: 'Sem permissão. É necessário ser gestor ou administrador.' });
  }
  next();
}

function soAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ erro: 'Sem permissão. É necessário ser administrador.' });
  }
  next();
}

module.exports = { auth, soGestor, soAdmin, rateLimitLogin, registarFalhaLogin, limparFalhasLogin };