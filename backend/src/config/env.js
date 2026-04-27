const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const variaveisObrigatorias = [
  'NODE_ENV',
  'PORT',
  'DB_HOST',
  'DB_PORT',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'JWT_SECRET',
  'CORS_ORIGINS',
];

function terminarComErro(mensagem) {
  console.error(`[ERRO FATAL] ${mensagem}`);
  process.exit(1);
}

function validarEnv() {
  const emFalta = variaveisObrigatorias.filter((nome) => {
    const valor = process.env[nome];
    return !valor || !valor.trim();
  });

  if (emFalta.length > 0) {
    console.error('[ERRO FATAL] Variaveis de ambiente obrigatorias em falta:');
    for (const nome of emFalta) {
      console.error(` - ${nome}`);
    }
    console.error('Cria o ficheiro backend/.env com base no backend/.env.example');
    process.exit(1);
  }

  if (!['production', 'development'].includes(process.env.NODE_ENV)) {
    terminarComErro('NODE_ENV invalido. Use apenas production ou development.');
  }

  const port = Number(process.env.PORT);
  const dbPort = Number(process.env.DB_PORT);

  if (!Number.isInteger(port) || port <= 0) {
    terminarComErro('PORT invalido. Use um numero inteiro positivo.');
  }

  if (!Number.isInteger(dbPort) || dbPort <= 0) {
    terminarComErro('DB_PORT invalido. Use um numero inteiro positivo.');
  }

  if (process.env.JWT_SECRET.trim().length < 64) {
    terminarComErro('JWT_SECRET demasiado curto. Use pelo menos 32 caracteres.');
  }

  const corsOrigins = process.env.CORS_ORIGINS
    .split(',')
    .map((origem) => origem.trim())
    .filter(Boolean);

  if (corsOrigins.length === 0) {
    terminarComErro('CORS_ORIGINS invalido. Define pelo menos uma origem permitida.');
  }

  return {
    isProduction: process.env.NODE_ENV === 'production',
  };
}

module.exports = {
  validarEnv,
};
