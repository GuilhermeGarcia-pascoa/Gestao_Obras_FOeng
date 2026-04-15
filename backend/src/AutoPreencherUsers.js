const crypto = require('crypto'); // módulo nativo do Node — sem instalação
const pool   = require('./db/pool');
const fs     = require('fs');

// ── Utilitário MD5 ─────────────────────────────────────────────────────────
function md5Hash(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

const users = [
  { nome: "nome",       email: "email@qualquer.com" },
  { nome: "João Silva", email: "joao.silva@qualquer.com" },
];

function gerarPassword(nome) {
  const nomeLimpo     = nome.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const primeiroNome  = nomeLimpo.split(' ')[0];
  const random        = Math.random().toString(36).slice(-4);
  return `${primeiroNome}@2026!${random}`;
}

async function run() {
  let logOutput = 'LISTA DE UTILIZADORES E PASSWORDS\n';
  logOutput    += '==========================================\n\n';

  console.log('🚀 A iniciar inserção de utilizadores...\n');

  for (const user of users) {
    const password = gerarPassword(user.nome);
    // ── Hash MD5 (síncrono, ao contrário do bcrypt que era async) ──────────
    const hash = md5Hash(password);

    try {
      await pool.query(
        'INSERT INTO utilizadores (nome, email, password_hash, role) VALUES (?, ?, ?, ?)',
        [user.nome, user.email.toLowerCase(), hash, 'utilizador']
      );

      const successMsg = `✔ ${user.email} | Password: ${password}`;
      console.log(successMsg);
      logOutput += successMsg + '\n';

    } catch (err) {
      const errorMsg = `❌ ${user.email} | ERRO: ${err.code === 'ER_DUP_ENTRY' ? 'Email já existe' : err.code}`;
      console.log(errorMsg);
      logOutput += errorMsg + '\n';
    }
  }

  try {
    fs.writeFileSync('utilizadores_pass.txt', logOutput, 'utf8');
    console.log('\n✅ Processo terminado!');
    console.log("💾 O ficheiro 'utilizadores_pass.txt' foi gerado com sucesso.");
  } catch (fsErr) {
    console.error('\n[!] Erro ao gravar o ficheiro TXT:', fsErr);
  }

  process.exit();
}

run();