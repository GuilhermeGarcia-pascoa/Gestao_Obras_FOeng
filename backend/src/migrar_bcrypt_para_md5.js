/**
 * migrar_bcrypt_para_md5.js
 *
 * Script de migração: substitui todos os hashes bcrypt existentes
 * por um hash MD5 gerado a partir de uma password temporária.
 *
 * Estratégia:
 *   1. Para cada utilizador com hash bcrypt na BD, atribui uma password
 *      temporária (ex: PrimeiroNome@Reset2026!) e guarda o MD5 dessa password.
 *   2. Gera um ficheiro TXT com o email e a password temporária de cada utilizador.
 *   3. O utilizador faz login com a password temporária e deve alterá-la.
 *
 * Como executar:
 *   node migrar_bcrypt_para_md5.js
 */

const crypto = require('crypto');
const pool   = require('./db/pool');
const fs     = require('fs');

function md5Hash(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

/**
 * Devolve true se o hash parecer ser bcrypt (começa por $2b$ ou $2a$).
 */
function isBcrypt(hash) {
  return typeof hash === 'string' && (hash.startsWith('$2b$') || hash.startsWith('$2a$'));
}

function gerarPasswordTemporaria(nome) {
  const nomeLimpo    = nome.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const primeiroNome = nomeLimpo.split(' ')[0];
  return `${primeiroNome}@Reset2026!`;
}

async function run() {
  console.log('🔄 A iniciar migração bcrypt → MD5...\n');

  let logOutput = 'MIGRAÇÃO DE PASSWORDS — PASSWORDS TEMPORÁRIAS\n';
  logOutput    += '================================================\n\n';
  logOutput    += 'Instruções: Envie a cada utilizador o seu email e password temporária.\n';
  logOutput    += 'Peça-lhes que alterem a password após o primeiro login.\n\n';

  try {
    // Busca todos os utilizadores
    const [utilizadores] = await pool.query(
      'SELECT id, nome, email, password_hash FROM utilizadores'
    );

    let migrados = 0;
    let ignorados = 0;

    for (const user of utilizadores) {
      if (!isBcrypt(user.password_hash)) {
        // Já não tem bcrypt — ignora
        console.log(`⏭  ${user.email} — já não tem hash bcrypt, ignorado`);
        ignorados++;
        continue;
      }

      // Gera password temporária e hash MD5
      const passwordTemp = gerarPasswordTemporaria(user.nome);
      const hashMd5      = md5Hash(passwordTemp);

      await pool.query(
        'UPDATE utilizadores SET password_hash = ? WHERE id = ?',
        [hashMd5, user.id]
      );

      const linha = `✔ ${user.email} | Password temporária: ${passwordTemp}`;
      console.log(linha);
      logOutput += linha + '\n';
      migrados++;
    }

    logOutput += `\n\nTotal migrados : ${migrados}`;
    logOutput += `\nTotal ignorados: ${ignorados}`;

    fs.writeFileSync('passwords_temporarias.txt', logOutput, 'utf8');

    console.log(`\n✅ Migração concluída!`);
    console.log(`   Migrados : ${migrados}`);
    console.log(`   Ignorados: ${ignorados}`);
    console.log(`💾 Ficheiro 'passwords_temporarias.txt' gerado com as passwords temporárias.`);

  } catch (err) {
    console.error('❌ Erro durante a migração:', err.message);
  }

  process.exit();
}

run();