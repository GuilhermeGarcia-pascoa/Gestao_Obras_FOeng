const jwt = require('jsonwebtoken');

// Middleware que protege rotas — adiciona req.user se o token for válido
function auth(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ erro: 'Token em falta ou inválido' });
  }

  const token = header.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { id, nome, role }
    next();
  } catch {
    return res.status(401).json({ erro: 'Token expirado ou inválido' });
  }
}

// Middleware extra — só deixa passar admins/gestores
function soGestor(req, res, next) {
  if (req.user?.role !== 'admin' && req.user?.role !== 'gestor') {
    return res.status(403).json({ erro: 'Sem permissão' });
  }
  next();
}

module.exports = { auth, soGestor };
