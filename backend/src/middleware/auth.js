const jwt = require('jsonwebtoken');

function auth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ erro: 'Token em falta' });

  const token = header.split(' ')[1];
  if (!token) return res.status(401).json({ erro: 'Token inválido' });

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    return res.status(401).json({ erro: 'Token expirado ou inválido' });
  }
}

function soGestor(req, res, next) {
  if (!['gestor', 'admin'].includes(req.user?.role)) {
    return res.status(403).json({ erro: 'Sem permissão' });
  }
  next();
}

function soAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ erro: 'Sem permissão' });
  }
  next();
}

module.exports = { auth, soGestor, soAdmin };