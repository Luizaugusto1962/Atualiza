# AGENTS.md

This file provides guidance to the AI agent when working with code in this repository.
(Regras em pt-BR, como o resto do código.)

## Regras para Agentes AI

Utilitário CLI do sistema SAV (IsCOBOL/ISAM) em **Bash puro** (4.0+, sem frameworks).
Alvo: servidores legados (Ubuntu 10.04/12.04, OpenSSH 5.x) — **compatibilidade > elegância**.

## Execução

- `./atualiza.sh` é o único entry point; ele **executa** (nunca faz `source`) o alvo via bloco `case`: `""` → `binarios/principal.sh`, `--setup [--edit]` → `binarios/setup.sh`, `--cadastro` → `binarios/cadastro.sh`.
- `principal.sh` faz `source` dos 15 módulos em **escopo global e ordem fixa** (`MODULOS_CARREGAR`): `constantes → utils → config → auth → lembrete → vaievem → sistema → baixar → arquivos → backup → programas → biblioteca → help → variaveis → menus`.
- **`utils.sh` é o segundo de propósito** (mudou em 09/10/2026, junto com o unificado de diretório): `_configurar_diretorios` (config.sh, índice 3) e `auth.sh` (índice 4, roda no próprio `source`) chamam `_garantir_diretorio`, que vive em utils.sh (índice 2). `config.sh` não define nada de que `utils.sh` precise, então o swap é seguro — mas isso **não é óbvio**: devolver `utils.sh` para depois de `config.sh` só quebra em runtime. Antes de mexer na ordem, rode o harness de carga (carrega os 15 módulos na ordem extraída do fonte, num sandbox, e confere a cadeia).
- **`atualiza.sh` exige TTY ou pipe** (`[[ ! -t 0 && ! -p /dev/stdin ]]`) e Bash ≥ 4 → não dá para exercitar o programa em CI. Teste função isolada com `source` do módulo + stubs de `_msg/_ok/_aviso/_erro`, `_log`, `_validar_caminho_seguro` e cores (`$VERDE`, `$VERMELHO`, …). Ver `testes/test_sistema.sh` como modelo.
- `atualiza.sh` **apaga `instalador.sh`** (o comentário diz `instalar.sh`, o código apaga `instalador.sh`) se existir ao lado do script, a cada execução.
- Todo módulo tem shebang, mas módulo **roda via `source`, nunca por execução direta** — o shebang é decorativo.
- Fluxo de referência: `_main` → `_inicializar_sistema` → `_login` → `_principal` (menus) → `_finalizar_sistema`. Detalhamento por fluxo em `ARCHITECTURE.md`.

## Dependência entre módulos — "só para frente"

A ordem do `MODULOS_CARREGAR` não é estética: **uma função só pode ser chamada por um módulo que carregue depois dela** (ou resolvida em runtime com `command -v`, padrão já usado em `programas.sh:_validar_pre_requisitos_atualizacao` para `_verificar_espaco_disco`).

- Helper compartilhado entre dois módulos vai para **`utils.sh`** (posição 3), não para o "módulo dono" do domínio.
- Caso recente que ilustra: `_validar_backup_entradas_seguras` morava em `backup.sh`, mas `programas.sh` (que carrega **depois** de `backup.sh`) passou a precisar dela. Foi movida para `utils.sh` — `backup.sh:_selecionar_backup` (só o comentário que registra a saída) e `biblioteca.sh:_reverter_biblioteca_completa` / `biblioteca.sh:_reverter_programa_especifico_biblioteca` seguem funcionando sem tocar nos call sites, porque o nome não mudou. O alias `_validar_zip_entradas_seguras` foi junto.
- Antes de criar uma função nova, `grep` nos 15 módulos e decida a casa pelo **menor índice de carga** entre os consumidores, não por perde-foguete temático.
- Se o consumidor é anterior na lista, a alternativa aceita é o guard `command -v _foo >/dev/null && _foo || <fallback>` — mas ele **falha em silêncio** quando a função falta, então prefira mover a função.

## Verificação (obrigatória antes de concluir)

```bash
bash -n binarios/<modulo>.sh
shellcheck -S warning binarios/<modulo>.sh   # hoje 100% limpo em todo o repo
bash testes/run_all.sh                      # TODAS as suítes + resumo (517 checks); roda sem TTY
bash testes/test_sistema.sh                  # suíte de sistema.sh (16 checks); roda sem TTY
bash testes/test_auth.sh                     # suíte de auth.sh (63 checks); roda sem TTY
bash testes/test_utils.sh                    # suíte de utils.sh (80 checks); roda sem TTY
bash testes/test_programas.sh                # suíte de programas.sh (22 checks); roda sem TTY
bash testes/test_biblioteca.sh               # suíte de biblioteca.sh (38 checks); roda sem TTY
bash testes/test_backup.sh                   # suíte de backup.sh (35 checks); roda sem TTY
bash testes/test_baixar.sh                   # suíte de baixar.sh (37 checks); roda sem TTY
bash testes/test_constantes.sh               # suíte de constantes.sh (38 checks); roda sem TTY
bash testes/test_config.sh                   # suíte de config.sh (45 checks); roda sem TTY
bash testes/test_arquivos.sh                 # suíte de arquivos.sh (42 checks); roda sem TTY
bash testes/test_vaievem.sh                  # suíte de vaievem.sh (52 checks); roda sem TTY
bash testes/test_principal.sh                # suíte de principal.sh (49 checks); roda sem TTY
```

- **Doze** suítes, todas com `set -euo pipefail` e sem TTY, todas passando. Não há runner, `bats` nem `trunk`. `shellcheck` e `shfmt` estão instalados no Windows (winget) mas o repo não os invoca em script.
- **`testes/run_all.sh` é o runner**: descobre as suítes por glob (`testes/test_*.sh`), roda todas em sequência e imprime o resumo por suíte + as falhas detalhadas; sai com 1 se alguma falhar. Opções: `-v` (saída completa), `-o` (só as que falharam), `-k <filtro>` (só as que casam com o filtro). Ele **não** usa `set -e` de propósito: o objetivo é rodar todas as suítes mesmo quando uma falha, para o relatório mostrar o estado completo.
- **Ainda não há suíte para `setup.sh`, `cadastro.sh`, `help.sh`, `lembrete.sh`, `menus.sh` e `variaveis.sh`** — os seis restantes são de apresentação, sem lógica de decisão isolável. Mudança de segurança nesses módulos ainda exige harness próprio (throwaway, fora do repo) e ele **precisa ser rodado também contra o `git show HEAD:<arquivo>`** para provar que o teste falha no código antigo — um teste que passa nos dois não é regressão.
- **`testes/test_principal.sh` é o "harness de carga" que o AGENTS.md exige antes de mexer na ordem**: ele extrai a ordem do `MODULOS_CARREGAR` **do fonte** (nunca de uma cópia hardcoded), confere a cadeia estática (chamada em tempo de source apontando para módulo já carregado) e carrega os 15 módulos na ordem extraída num sandbox, conferindo a cadeia a cada passo. Contra `fac4885^` (quando `utils.sh` ainda era o terceiro) ele acusa exatamente 3 checks: a posição de `utils.sh`, a de `config.sh` e a ausência de `_garantir_diretorio` em `utils.sh`.
- **A cadeia tem 3 referências conhecidas para trás** (`constantes.sh` → `_encerrar_programa`, de `config.sh`), todas atrás do guard "sourced vs executed" — `constantes.sh` nunca é executado direto. A suíte exige que **qualquer nova** referência para trás apareça na lista; se alguém corrigir as três, é só remover a linha da lista.
- Todas as suítes seguem o modelo de `test_sistema.sh`: `source` do módulo + stubs + contador `falhas`. Os diretórios "protegidos" usados nos testes são clones em `mktemp -d` — em especial `SCRIPT_DIR`, que **nunca** pode apontar para o repo de verdade (o modo `recriar` faria `rm -rf` nele se a proteção regredisse).
- `testes/test_utils.sh`, `testes/test_programas.sh`, `testes/test_biblioteca.sh` e `testes/test_baixar.sh` exigem `python3` para fabricar os ZIPs maliciosos (`zipfile`): a CLI `zip` recusa entrada `../`.
- **`testes/test_biblioteca.sh` não exercita o caminho feliz da extração**: `_reverter_biblioteca_completa` extrai em `/`, então o pacote malicioso do teste usa a entrada absoluta `/tmp/atualiza_suite_sentinel.txt` — se a validação regredisse, o arquivo apareceria no `/tmp` e o teste falharia. É uma troca deliberada: segurança primeiro.
- **Suíte que roda contra código antigo precisa degradar, não abortar**: as suítes definem stubs de fallback (`return 127`) para as funções que podem não existir em versões antigas do módulo. Sem isso, o `command not found` derruba a suíte no meio (set -e) e o relatório fica incompleto — veja a seção "Armadilhas de `set -e`" mais abaixo.
- **`testes/test_constantes.sh` roda o parser em sub-shell**: contra um parser antigo (sem a lista de chaves bloqueadas), a sobrescrita de `PATH`/`BASHOPTS` contaminaria o shell do teste — inclusive a própria limpeza (`rm` deixa de ser encontrado). No sub-shell o dano morre com ele.
- `package.json` declara `husky` + `lint-staged` + `prettier`, mas **não há `.husky/` instalado** e o arquivo **é JSON inválido** (dois objetos `{...}` colados — `ConvertFrom-Json` falha na linha 8). Não tente rodar `npm install`/`lint-staged`: quebra. Formatação de shell é manual: indentação de 4 espaços.
- Um módulo novo precisa ser **adicionado a `MODULOS_CARREGAR`** e ao `principal.sh`, senão o programa nem carrega.
- Ao mover uma função entre módulos, `bash -n` **não** acha erro — o erro só aparece em runtime. Confira os call sites com `grep` e rode as suítes.

## Armadilhas de `set -e` (verificadas na prática — respeite sempre)

- Cada módulo faz `set -euo pipefail` no topo; `principal.sh` faz `umask 077`. **Dar `source` num módulo liga strict mode no shell do agente** — um teste mal escrito aborta antes de assertar, e o `abort` é silencioso: você só vê a última linha que rodou.
- **`source utils.sh` liga `set -e` no harness.** Todo comando cujo código de retorno possa ser ≠ 0 precisa estar protegido: `cmd || rc=$?`, `if ! cmd; then`, ou dentro de `if`. Sem isso, `unzip` devolvendo 1 (caminho absoluto no ZIP) aborta o script e o relatório mente que "não escreveu".
- `shopt -p <opt>` retorna **1 com a opção desligada**: capture sempre com `|| true` (`old=$(shopt -p nullglob) || true`).
- Statement avulso que pode ser falso aborta o shell: `(( x > y )) && ...`, `[[ ... ]] && ...` fora de `if`/`while`. Use `if` ou `|| true` (o repo usa `((i++)) || true` por isso).
- Restaurar `shopt -p` compara com `*"-u"*` (imprime `shopt -u`), nunca com `*"off"*`.
- `[[ "$x" =~ ^[sn]$ ]] && ACC="$x"` **dentro** de `case` em loop é seguro (o `case` protege), mas o mesmo padrão como statement avulso no topo de uma função aborta quando `$x` não casa.

## Convenções de código

- **pt-BR sem acentos** em código, comentários e mensagens ao usuário. A esmagadora maioria é sem acento — siga a maioria, não as exceções.
- Funções e variáveis em pt-br; funções com prefixo `_`. Globais em `UPPER_SNAKE_CASE`; nunca hardcodar o que já existe em `constantes.sh` (`C_JUTIL_PARALELO`, `C_LOG_LINHAS`, `DEFAULT_ZIP`, `REBUILD`, `PERM_FILE_PRIVATE`, `PERM_DIR_SECURE`, e todo o bloco `ARQUIVO_ZIP_ATU`/`ATU_DIR_TEMP`/`ATU_DIR_STAGING`/`ATU_SUFFIXO_PARCIAL`).
- **Sem `declare -g`** (Bash ≥ 4.2) e **sem `wait -n`** (≥ 4.3). `declare -A` pode (4.0+). `source` de módulo tem que ser em escopo global — dentro de função, `declare -a/-A` fica local e se perde.
- Estado: registre a variável em `REGISTRO_VARIAVEIS` (`config.sh`) para que `_limpar_estado_variaveis` a limpe; caches internos (`_LOG_DIR_CACHE`, `_JUTIL_PRONTO`) entram na higiene do `unset -v` em `config.sh:_limpar_estado_variaveis`, não no registro.
- **CWD importa**: o sistema assume `PWD == SCRIPT_DIR` (`_carregar_configuracoes` faz `cd "${SCRIPT_DIR}"` porque módulos gravam caminhos relativos). Função que faz `cd` tem que salvar `local _cwd; _cwd="$(pwd)"` e restaurar em **todos** os retornos, inclusive os de erro — `_main`/`_limpeza_emergencia` rodam depois.
- **Nome de local vinda de constante**: se a constante pode mudar, a local tem que ler dela (`"${CFG_PORTALSAV}/${ATU_DIR_TEMP}"`), não repetir o literal. Exemplo do erro corrigido: `programas.sh` tinha `"${CFG_PORTALSAV}/dir_temp_atualizacao"` hardcoded, igual ao default de `ATU_DIR_TEMP` — se a constante mudasse, a limpeza de `baixar.sh` pararia de pegar o diretório.
- Paralelismo em lote: padrão "ondas de N jobs + `wait $pid`" (`arquivos.sh:_executar_jutil_lote`), nunca polling `sleep 1` por arquivo; flag de fallback sequencial quando a operação não for reentrante.
- Toda mudança de módulo mexe no header `# Versao: DD/MM/AAAA[-NN]` — o histórico de commits do autor combina bump de versão com a alteração.
- **Referência entre módulos por NOME, nunca por número de linha.** Cite `arquivo.sh:_funcao` (ex.: `utils.sh:_offline_valido`) — é estável. `arquivo.sh:NNN` deriva a cada edição: em 2026-10 as referências de `utils.sh` estavam 5 a 205 linhas fora do alvo, sem erro visível. Quando o alvo não é uma função, cite o texto pesquisável (ex.: `comment "Largura do terminal" no topo de utils.sh`). Mesmo critério já adotado no item "Restrição e exceção" mais abaixo.

## `.config` — regras que surpreendem (`constantes.sh:_carregar_config_seguro`)

- `_carregar_config_seguro` (`constantes.sh`) é o **único** parser do `.config` e roda `printf -v "$chave"`. Ele **descarta** (não aborta) linhas cuja chave case `re_chave_bloqueada`: `PATH`, `IFS`, `HOME`, `LANG`, `TZ`, `BASH_*`, `LD_*`, `LC_*`, … e **toda chave começando com `_`**.
- Valores com `` [ ` ; | & < > ( ) { } $ `` são rejeitados. Logo: **chave nova em `.config` não pode começar com `_` nem conter esses caracteres no valor** — e o mesmo conjunto é revalidado por `_validar_config_file` (`config.sh:_validar_config_file`), que roda **antes** do parser, com limite de 1 MB.
- Registro de variável nova = tocar `constantes.sh` (default), o writer em `setup.sh` e a exibição em `variaveis.sh`.
- Flag booleana em `.config` **não** pode ser testada direto. `CFG_OFFLINE` vem de `Offline` e o valor é `s`/`n`; use sempre `_offline_valido` (`utils.sh:_offline_valido`) e a mensagem `_offline_erro`. Ver abaixo.

## Segurança (não contornar)

- `.senhas` é `0600` via `PERM_FILE_PRIVATE` (`auth.sh`); hash no formato `algoritmo$salt$hash`. Nunca afrouxar.
- Toda operação de arquivo (remoto ou local) passa por `_validar_caminho_seguro` — que saiu de `vaievem.sh` e foi para `utils.sh` em 09/10/2026 (mesma regra de casa do menor índice de carga).
- **Diretório novo ou validado passa, obrigatoriamente, por `_garantir_diretorio <caminho> <modo> <rotulo> [silencioso]`** (`utils.sh`). É porta única: substituiu `_criar_diretorio_seguro` (principal.sh), `_validar_diretorio_backups` (programas.sh), `_validar_diretorio_operacao` (baixar.sh), `_validar_diretorio_backup`/`_validar_diretorio_trabalho`/`_validar_diretorio_expurgavel` (arquivos.sh) e os `mkdir -p` inline de `auth.sh`/`backup.sh`. Modos: `verificar` (só caminho, pode não existir), `validar`, `validar_escrita`, `criar`, `recriar`. **Não reintroduza `mkdir -p` solto** — o único inline que resta é o bootstrap de `principal.sh`, que roda antes dos módulos. Dois contratos: `criar` **não** re-permissona diretório pré-existente (ponto de montagem/volume de outro dono), e `recriar` **recusa** qualquer caminho protegido por `_diretorio_protegido` (`CFG_PORTALSAV`, `CFG_DIR`, `RAIZ`, `DEFAULT_*`…), barra final incluída.
- **SSH:** nunca escreva `StrictHostKeyChecking=...` literal — use `_ssh_aceitar_novo()` (`utils.sh:_ssh_aceitar_novo`). Mantenha o fallback senha/sem chave (servidor antigo é o caso real).
- **Antes de extrair qualquer pacote, valide as entradas:** `_validar_backup_entradas_seguras` (`utils.sh:_validar_backup_entradas_seguras`, alias `_validar_zip_entradas_seguras`). Ela lista os membros com `unzip -Z1` / `tar -tzf` e rejeita `../`, caminho absoluto e `C:\`. Medido com o binário do alvo — a tabela está em `ARCHITECTURE.md` §5. Resumo: **`unzip -d /` efraca o sandbox**, `unzip -o` sem `-d` não, `tar` recusa `..`. Já é usado em `biblioteca.sh:_reverter_biblioteca_completa` / `biblioteca.sh:_reverter_programa_especifico_biblioteca` (reversão), `biblioteca.sh:_salvar_atualizacao_biblioteca` (portão do update) e `programas.sh:_validar_pre_requisitos_atualizacao` (portão de programas e pacotes). Falta nos outros pontos de extração que ainda existam.
- **`CFG_PORTALSAV` é diretório compartilhado**, não área de rascunho de uma operação. Recebe backup offline pendente de envio (`backup.sh:_mover_backup_offline`), ZIP de biblioteca aguardando processamento (`vaievem.sh`, `biblioteca.sh`), ZIP de reversão de programas (`programas.sh`) e o pacote do self-update. **Nunca `rm -rf`/`find -exec rm` no topo dele.** A regra agora é aplicada por código, não por disciplina: `_diretorio_protegido` (`utils.sh`) lista os diretórios compartilhados e o modo `recriar` de `_garantir_diretorio` se recusa a purgar qualquer um deles. O que sobrar de uma operação vai para o log (`_log`), não para o lixo. A limpeza do self-update remove só artefatos nominais: o ZIP, `$ATU_DIR_TEMP`, `$ATU_DIR_STAGING` e o `<zip>$ATU_SUFFIXO_PARCIAL` de download interrompido.
- **`printf '%b'` interpreta escapes.** Valor lido de arquivo de configuração nunca pode ser impresso com `%b`: um `.versao` com `VERSAOANT="\033[2J"` sobrevive ao strip de aspas e limpa a tela. Use `%s`, e valide o formato na origem.
- Restrição de comportamento: `_processar_atualizacao_programas` (`programas.sh`) **não pode alterar fluxo, saída ou arquivos** criados/alterados. **Exceção documentada e já aplicada:** a validação de entradas de pacote foi adicionada em `_validar_pre_requisitos_atualizacao` (commit `029be9b`) — para ZIP legítimo o fluxo, a saída e os arquivos são idênticos (o validador é silencioso); ZIP com `../`/absoluto agora aborta antes de qualquer escrita, quando antes escrevia fora do temporário. Se essa exceção for ampliada, registre-a aqui e na seção "Restrição e exceção" de `ARCHITECTURE.md` (busque por `Restrição e exceção`, não por número de linha — a numeração muda a cada edição).

## Flags e arquivos de estado

- **`CFG_OFFLINE` (`.config` → `Offline`)**: validar com `_offline_valido`, nunca com `[[ "$CFG_OFFLINE" =~ ^[sn]$ ]]` seguido de `if` sem `else`. O bug histórico era duplo: o `if` sem `else` deixava a função retornar 0 **sem fazer nada** (`biblioteca.sh:_atualizar_biblioteca_offline`), e em menus com `else` o valor inválido caía no ramo de **descarga pela rede** (`_atualizar_transpc`, `programas.sh:_atualizar_programa_pacote`). Quatro call sites usam o helper hoje: `baixar.sh:_executar_update`, `biblioteca.sh:_atualizar_transpc`, `biblioteca.sh:_atualizar_biblioteca_offline`, `programas.sh:_atualizar_programa_pacote`. `backup.sh:_enviar_backup_avulso` mantém o `else` com `_aviso` (ali não agir é o certo). `programas.sh:_atualizar_programa_online` mantém `== "s"` cru: ali cair no online é a intenção do menu.
- **`configuracoes/.versao`** (`sistema.sh:_carregar_versao_seguro`): whitelist estrita de chaves (`VERSAO`/`VERSAOANT`) **e** validação `^[0-9]+$` do valor. `VERSAO` só alimenta nome de arquivo (`biblioteca.sh`), então o formato não pode ser livre.

## Estado do repo (o que não acreditar)

- **`AGENTS.md` é o único dos três documentos de regra que está no `.gitignore`** (linha 4). `ARCHITECTURE.md` e `CLAUDE.md` **são versionados** (e `CLAUDE.md` nem está listado no `.gitignore`) — editar os dois aparece em `git status` e entra no histórico; editar este arquivo, não.
- Também ignorados: `*.json` (exceto `.vscode/sftp.json`, que é rastreado), `*.zip`, `*.py` (exceto `fix_backup.py`, rastreado), `docs/`, `.claude/`, `.planning/`. `.gitignore` não afeta arquivo já rastreado — é por isso que `fix_backup.py` e `.vscode/sftp.json` estão no índice apesar das regras.
- Tooling novo na raiz (config do prettier, do shellcheck) não entra no repo sem `git add -f`.
- `configuracoes/.config` e `configuracoes/.versao` são de runtime: **não** estão no `.gitignore` e **não** estão versionados (`git ls-files configuracoes/` mostra só `.senhas`, `indexar`, `lembrete`, `limpetmp`, `manual.txt`, `variosarquivos`). Rodar `--setup` localmente os cria como untracked — não commite. `configuracoes/.senhas`, ao contrário, **está versionado**.
- **Só 55 arquivos são rastreados** (`git ls-files | wc -l`), e alguns são entulho já commitado (`A.dat`, `OK1.dat`, `fix_backup.ps1`, `fix_backup.py`, `fix_rename.ps1`, `graphify-out/`). Confirme com `git ls-files` antes de assumir que algo está versionado.
- **A regra `testes/` do `.gitignore` foi removida em 11/11/2026**: até lá, qualquer suíte nova em `testes/` nascia **ignorada** e só entrava no repo com `git add -f` (foi assim que `test_utils.sh`, `test_programas.sh`, `test_biblioteca.sh`, `test_backup.sh` e `test_baixar.sh` entraram). Agora `git add` normal funciona — mas confira com `git check-ignore -v testes/<arquivo>` se voltar a aparecer na lista.
- `opencode_ori.json` (ignorado) tem uma **API key em texto puro**; nunca copie essa chave para outro lugar.
- `.vscode/sftp.json` é rastreado e carrega `host`, `username`, `remotePath` do servidor de deploy. Não tem senha, mas é dado de infraestrutura — não edite à toa.
- `README.md` está parcialmente desatualizado: lista `move_dir.sh` (removido), um diretório `docs/` (inexistente) e diz "20 scripts" em `binarios/` (são **18** arquivos `.sh`, dos quais 15 entram no `MODULOS_CARREGAR`). A seção **Testes** foi corrigida em 11/11/2026 (as sete suítes reais: `test_sistema.sh`, `test_auth.sh`, `test_utils.sh`, `test_programas.sh`, `test_biblioteca.sh`, `test_backup.sh`, `test_baixar.sh`). O resto do README ainda não é fonte confiável — confie em `binarios/`, `principal.sh` e `ARCHITECTURE.md`.
- `ARCHITECTURE.md` é o mapa por fluxo/módulo e remete para cá na restrição de `_processar_atualizacao_programas` — mantenha os dois coerentes.
- `.planning/` (PROJECT.md / ROADMAP.md / STATE.md, ignorados pelo git) descreve o sistema com precisão: produção madura, sem fases de construção.

## Ambiente Windows (onde o agente roda)

- O repo fica em `D:\Projetos\Atualiza`. O shell do agente é **Git Bash** (`C:\Program Files\Git\bin\bash.exe`, Bash 5.x), com paths Windows (`D:/Projetos/...`). `bash -n`, `git` e as suítes funcionam direto. Só use WSL quando precisar de Bash do Linux: `wsl bash -lc 'cd /mnt/d/Projetos/Atualiza && bash testes/test_sistema.sh'`.
- Se um passo precisar de **PowerShell** (ex.: `wsl` ausente do Git Bash, scripts `.ps1` do repo): `$var` dentro do argumento de `wsl bash -lc '...'` é interpolado pelo PowerShell mesmo com aspas simples, glob não expande para executável nativo (`shellcheck -S warning @files`), e heredoc `<<'EOF'` é rejeitado — use `git commit -F <arquivo>`.
- `shellcheck` roda **nativo no Windows** (winget 0.11.0, 100% limpo no repo) e aceita paths do Windows direto; **não há `shellcheck` no WSL**. Não instale toolchain Linux para isso.
- WSL hoje tem `bash` 5.3, `zip`/`unzip` e `clear` — verifique com `command -v` em vez de assumir que faltam. Para criar entrada `../` ou `/` num ZIP, use `python3 -c "import zipfile"` (a CLI `zip` recusa).
- O alvo de deploy (Ubuntu 10.04/12.04, OpenSSH 5.x) **não é esta máquina** — não teste SSH/conectividade real aqui.

## O que evitar

- Reescrever módulo inteiro; remover `_limpeza_emergencia`/`_limpar_estado_variaveis` ou os traps de `EXIT`/`INT`/`TERM`/`HUP`/`QUIT`; ignorar o fallback SSH; reintroduzir helper de coluna (`${COLUMNS}` é lido direto de propósito — comment "Largura do terminal" no topo de `utils.sh`).
- Confiar em suposição sobre o comportamento de `unzip`/`tar` sem medir com o binário. Já erramos duas vezes: "caminho absoluto no ZIP sobrescreve o destino" (falso sem `-d /`) e "`../` escapa" (falso — o `unzip` barra). Meça com um ZIP real e um alvo fora do sandbox.
- Declarar conclusões sobre o ambiente sem executar primeiro: houve caso de afirmar que `zip`/`unzip` faltavam no WSL e que o `sudo` exigia senha, quando ambos já estavam resolvidos.

<!-- gitnexus:start -->
## GitNexus (indice stale — use com cautela)

`gitnexus://repo/Atualiza/processes` e `clusters` retornam **vazio** neste repo, e a contagem
("80 symbols / 71 relationships / 0 execution flows") desmente o proprio codigo. **Nao use o grafo
para fluxo de execucao** — use `ARCHITECTURE.md`. As regras "impact antes de editar" e
"detect_changes antes de commitar" so valem com o indice fresco:
`node .gitnexus/run.cjs analyze --index-only`.

<!-- gitnexus:end -->
