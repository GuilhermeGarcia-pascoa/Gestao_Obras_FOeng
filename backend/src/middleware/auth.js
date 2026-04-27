const jwt = require('jsonwebtoken');

const JWT_ISSUER = 'foeng-api';
const JWT_AUDIENCE = 'foeng-users';

function respostaNaoAutorizado(res) {
  return res.status(401).json({ erro: 'Nao autorizado' });
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
  JWT_ISSUER,
  JWT_AUDIENCE,
};
