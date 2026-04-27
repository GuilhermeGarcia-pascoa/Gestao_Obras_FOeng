const rateLimit = require('express-rate-limit');

const rateLimitGlobal = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { erro: 'Demasiadas requests. Tente novamente mais tarde.' },
});

const rateLimitLogin = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: { erro: 'Demasiadas tentativas de login. Tente novamente mais tarde.' },
});

module.exports = {
  rateLimitGlobal,
  rateLimitLogin,
};
