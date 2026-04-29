# Checklist de Teste - Sistema de Importação Excel

## ✅ Pré-Requisitos

- [ ] Backend Express.js a correr na porta configurada
- [ ] App Flutter compilada e a correr
- [ ] Utilizador logado com role **"gestor"** (importante!)
- [ ] Ficheiro Excel de teste com dados válidos (ver secção abaixo)

## 🧪 Testes Funcionais

### 1. Acesso ao Sistema

- [ ] Acede a uma obra (ecrã `ObraDetailScreen`)
- [ ] Verifica se botão "Importar dados de Excel" é visível (cor âmbar)
- [ ] Clica no botão — modal deve abrir
- [ ] Modal mostra:
  - [ ] Informação da obra (ex: "Obra: Minha Obra")
  - [ ] Dropdown de anos (pre-selecionado ano atual)
  - [ ] Dropdown de meses (pre-selecionado mês atual)
  - [ ] Área de seleção de ficheiro
  - [ ] Botões "Cancelar" e "Importar"

### 2. Seleção de Ficheiro

- [ ] Clica na área de ficheiro
- [ ] File picker abre (FilePicker padrão do sistema)
- [ ] Consegues navegar e selecionar um ficheiro .xlsx
- [ ] Ficheiro é listado no modal com ✅
- [ ] Consegues clicar novamente para mudar ficheiro
- [ ] Se selecionares .csv/.xls/outro, recusas com erro

### 3. Validação de Dados

- [ ] Deixa ano/mês em branco e tenta importar → erro "Preencha todos os campos"
- [ ] Deixa ficheiro em branco e tenta importar → erro "Preencha todos os campos"
- [ ] Tenta com ano inválido (ex: 1900) → validação servidor
- [ ] Tenta com mês inválido (ex: 13) → validação servidor

### 4. Importação Bem-Sucedida

**Arquivo de teste esperado:**
- Linha 1, Col G: "Minha Obra"
- Linha 7: Horas (8, 8, 8, ...)
- Linha 8: Datas (6, 7, 8, ... para dias 6-31)
- Linhas 9+: Dados de pessoas, máquinas, viaturas, gastos

**Teste:**

1. [ ] Seleciona ficheiro válido
2. [ ] Seleciona ano e mês que correspondem ao ficheiro
3. [ ] Clica "Importar"
4. [ ] Modal mostra spinner de progresso ("A importar...")
5. [ ] Após alguns segundos, exibe resultado:
   - [ ] ✅ "Importação com sucesso!"
   - [ ] Resumo (ex: "3 dias importados • 5 pessoas criadas")
   - [ ] Modal fecha-se automaticamente após ~1.5s
6. [ ] Na obra, calendário mostra novos dias com pontos
7. [ ] Ao clicar nesses dias, aparecem dados importados

### 5. Erros de Importação

**Teste: Ficheiro inválido**
- [ ] Tenta importar .csv ou ficheiro não Excel → erro "Ficheiro não é um Excel válido"

**Teste: Ficheiro corrompido**
- [ ] Tenta importar ficheiro Excel corrompido → erro "Erro ao ler o ficheiro"

**Teste: Sem dados**
- [ ] Tenta importar Excel vazio → erro "O ficheiro não contém dados para MM/YYYY"

**Teste: Sem autenticação**
- [ ] Faz logout e tenta importar → erro "Token inválido ou expirado"

**Teste: Sem permissão**
- [ ] Loga com utilizador não-gestor → erro "Apenas gestores podem importar"

### 6. Avisos e Informações Adicionais

- [ ] Se uma viatura é criada com custo_km default, aparece aviso
- [ ] Avisos são listados no modal com ⚠️
- [ ] Consegues scroll da lista de avisos se houver muitos
- [ ] Máximo 3 avisos exibidos + "+ N mais..."

### 7. Recarregar Dados

- [ ] Após importação bem-sucedida, calendário recarrega automaticamente
- [ ] Novo pull-to-refresh (swipe down) recarrega dias
- [ ] Dados aparecem no calendário com pontos nos dias
- [ ] Ao abrir dia, dados estão presentes

### 8. Cancelamento

- [ ] Abre modal
- [ ] Clica "Cancelar" → modal fecha sem fazer nada
- [ ] Abre modal novamente → estado é reset

### 9. Múltiplas Importações

- [ ] Importa dados de mês 1
- [ ] Importa dados de mês 2
- [ ] Verifica que dados de ambos os meses estão presentes
- [ ] Não houve duplicação
- [ ] Se reimportou o mesmo mês, dados foram atualizados (não duplicados)

## 🔍 Testes de UI/UX

### Layout

- [ ] Modal é responsivo (não sai do ecrã em mobile)
- [ ] Campos de dropdown têm tamanho adequado
- [ ] Área de ficheiro é clicável e visível
- [ ] Botões têm tamanho apropriado

### Cores e Ícones

- [ ] Botão de importação é cor âmbar (diferente dos outros)
- [ ] Ícone de upload está presente
- [ ] Ícone de sucesso é ✅ (verde)
- [ ] Ícone de erro é ❌ (vermelho)
- [ ] Spinners de progresso rodam corretamente

### Acessibilidade

- [ ] Elementos são clicáveis (não muito pequenos)
- [ ] Texto é legível (contraste adequado)
- [ ] Mensagens de erro são claras e úteis

## 📊 Testes de Dados

### Integridade

- [ ] Dias importados têm datas corretas
- [ ] Pessoas têm nomes, horas e custos corretos
- [ ] Máquinas têm nomes e horas corretos
- [ ] Viaturas têm nomes e KM corretos
- [ ] Valores monetários estão corretos (não há rounding errado)

### Banco de Dados

- [ ] Verifica na DB que foram inseridos/atualizados registos
- [ ] Pessoas novas têm tipo_vinculo correto (interno/externo)
- [ ] Máquinas novas têm custo_hora_snapshot preenchido
- [ ] Viaturas novas têm custo_km_snapshot preenchido

### Log de Ações

- [ ] Backend registou a importação no log
- [ ] Log contém: utilizador, ficheiro, ano, mês, estatísticas

## 🔗 Integração com Resto da App

- [ ] Dados importados aparecem em gráficos
- [ ] Dados aparecem em relatórios
- [ ] Dados podem ser exportados novamente em Excel
- [ ] Dados podem ser editados manualmente após importação

## 📱 Testes em Diferentes Plataformas

### Android

- [ ] [ ] App compila sem erros
- [ ] [ ] File picker funciona (abre diálogo nativo)
- [ ] [ ] Importação é bem-sucedida
- [ ] [ ] Dados persistem após fechar/reabrir app

### iOS

- [ ] [ ] App compila sem erros
- [ ] [ ] File picker funciona
- [ ] [ ] Importação é bem-sucedida

### Web

- [ ] [ ] App compila para web sem erros
- [ ] [ ] File picker funciona (utiliza input type=file)
- [ ] [ ] Importação é bem-sucedida

## 🚨 Testes de Stress

- [ ] Tenta importar ficheiro muito grande (15+ MB)
- [ ] Tenta importar ficheiro com muitos dias (100+)
- [ ] Tenta importar repetidamente sem aguardar
- [ ] App não trava ou fica sem resposta

## 📝 Testes de Documentação

- [ ] Documentação é clara e completa
- [ ] Exemplos funcionam quando copiados
- [ ] Endpoints estão corretamente documentados
- [ ] Erros comuns estão cobertos em Troubleshooting

---

## 🏁 Checklist Final

Antes de fazer deploy:

- [ ] Todos os testes funcionais passaram
- [ ] Nenhum erro no console do Flutter
- [ ] Nenhum erro no log do backend
- [ ] Dados aparecem corretamente em todas as vistas
- [ ] Documentação está completa e atualizada
- [ ] Código está formatado (dart format)
- [ ] Nenhuma variável não-utilizada
- [ ] Nenhum hardcode de IDs/URLs
- [ ] Segurança: autenticação e autorização validadas

---

**Status do Teste:** [ ] Não iniciado | [ ] Em progresso | [ ] Completo | [ ] Completo com Problemas

**Data:** ___________

**Responsável:** ___________

**Notas:** 
