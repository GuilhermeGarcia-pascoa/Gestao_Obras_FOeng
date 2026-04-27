const jwt = require('jsonwebtoken');

const tentativas = new Map();

const MAX_TENTATIVAS = 5;
const JANELA_MS = 15 * 60 * 1000;
const BLOQUEIO_MS = 30 * 60 * 1000;

const JWT_ISSUER = 'foeng-api';
const JWT_AUDIENCE = 'foeng-users';

function respostaNaoAutorizado(res) {
  return res.status(401).json({ erro: 'Nao autorizado' });
}

function rateLimitLogin(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  const agora = Date.now();
  const registo = tentativas.get(ip);

  if (registo) {
    if (registo.bloqueadoAte && agora < registo.bloqueadoAte) {
      const restam = Math.ceil((registo.bloqueadoAte - agora) / 60000);
      return res.status(429).json({
        erro: `Demasiadas tentativas. Tente novamente em ${restam} minuto(s).`,
      });
    }

    if (agora - registo.inicio > JANELA_MS) {
      tentativas.delete(ip);
    }
  }

  next();
}

function registarFalhaLogin(ip) {
  const agora = Date.now();
  const registo = tentativas.get(ip) || { count: 0, inicio: agora, bloqueadoAte: null };

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

function auth(req, res, next) {
  const header = req.headers.authorization;
  if (!header) {
    return respostaNaoAutorizado(res);
  }

  const partes = header.split(' ');
  if (partes.length !== 2 || partes[0] !== 'Bearer') {
    return respostaNaoAutorizado(res);
  }

  const token = partes[1];

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET, {
      issuer: JWT_ISSUER,
      audience: JWT_AUDIENCE,
    });
    next();
  } catch (err) {
    return respostaNaoAutorizado(res);
  }
}

function soGestor(req, res, next) {
  if (!req.user || !['gestor', 'admin'].includes(req.user.role)) {
    return res.status(403).json({ erro: 'Sem permissao' });
  }
  next();
}

function soAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ erro: 'Sem permissao' });
  }
  next();
}

module.exports = {
  auth,
  soGestor,
  soAdmin,
  rateLimitLogin,
  registarFalhaLogin,
  limparFalhasLogin,
  JWT_ISSUER,
  JWT_AUDIENCE,
};
