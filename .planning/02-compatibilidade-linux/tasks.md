# Tasks — Verificação de Compatibilidade Linux

**Projeto:** Atualiza — Sistema SAV de Atualização Modular
**Spec:** 02-compatibilidade-linux
**Objetivo:** Gerar `relatorio_compatibilidade.md` com análise estática de todos os 19 scripts

---

## Task 1: Verificar atualiza.sh e principal.sh

Status: not_started
Dependencies: none
Entrega: Seção 3.1 e 3.2 do relatório com todos os achados dos dois scripts de bootstrap

### Subtask 1.1: Analisar atualiza.sh

Arquivo: `atualiza.sh` (raiz)

**O que verificar:**
- Shebang `#!/usr/bin/env bash` — presente e correto
- `set -euo pipefail` — linha 14, presente
- `export LC_ALL=C` — presente; verificar se afeta módulos sourced
- `BASH_SOURCE[0]` — linha 23; Bash 3.0+, OK
- `readonly PLIBS_DIR SCRIPT_DIR` — verificar se conflita com redefinição em módulos
- Ausência de `set -u` impacto: `${1:-}` em `case "${1:-}"` — correto
- Execução de módulos via `"${PLIBS_DIR}/setup.sh" "${@:2}"` — sem source, exec direto; OK

**Achados esperados:**
- INFO: Não tem `umask 077` — não é necessário aqui (é o dispatcher), mas documentar
- INFO: `"${PLIBS_DIR}/principal.sh"` executado sem `exec` — cria subshell; comportamento esperado

### Subtask 1.2: Analisar principal.sh

Arquivo: `binarios/principal.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `umask 077` — linha 16, presente e correto
- `BASH_SOURCE[0]` — linha 38; usado para detectar execução direta; Bash 3.0+, OK
- `declare -rx UPDATE="…"` — `-r` (readonly) + `-x` (export); Bash 2.0+, OK
- `declare -a AUX_DIRS=(…)` — array indexado; Bash 2.0+, OK
- `chmod "${PERM_DIR_SECURE}" "${dir}"` — `PERM_DIR_SECURE=0755`; chamada com `set -e` ativa; falha aborta
- `_erro "…"` — chamada antes de `utils.sh` ser carregado (linhas 232-238); `_erro` não existe ainda → abortaria com `command not found`
- `trap '_resetando' EXIT` — `_resetando` definida em `config.sh`; se carregamento falhar antes, trap chama função inexistente

**Achados esperados:**
- AVISO: Linhas 232-238 chamam `_erro` antes de qualquer módulo ser carregado; a função não existe no início da execução
- INFO: Dependência de ordem de carregamento de módulos não é explicitamente documentada no arquivo

---

## Task 2: Verificar config.sh e constantes.sh

Status: not_started
Dependencies: none
Entrega: Seção 3.3 e 3.4 do relatório

### Subtask 2.1: Analisar config.sh

Arquivo: `binarios/config.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `declare -ga REGISTRO_VARIAVEIS=()` — `-ga` = global + array indexado; Bash 4.2+ para `-g` fora de função; aqui é no nível global, então `-g` é redundante mas inofensivo
- `declare -gA REGISTRO_CATEGORIAS=()` — global + associativo; Bash 4.0+ para `-A`, Bash 4.2+ para `-g`; OK nos alvos
- `declare -g VAR_CONTADOR_REGISTRO=0` — Bash 4.2+; OK nos alvos
- Bloco `if [[ -t 1 ]] && command -v tput >/dev/null 2>&1` — fallback correto para cores
- `COLUMNS=$(tput cols)` — sem `2>/dev/null`; protegido pelo `if [[ -t 1 ]]`; OK
- `tput clear/bold/setaf` — dentro do bloco protegido; OK
- `stat -c "%a" "${ssh_key}"` com fallback `stat -f "%Lp"` — correto
- `wc -c < "$CONFIG_FILE"` — GNU/POSIX, sem nome no output; correto
- `grep -qE '[\`\;|\&<>(){}]'` — `grep -E` em todos os alvos; OK
- Traps `trap '_limpar_estado_variaveis' EXIT` e `trap '_encerrar_programa' INT TERM` no nível global do arquivo — executados durante o source; podem interferir com traps de `principal.sh`
- `_ssh_aceitar_novo()` chamada em `_validar_ssh` — mas a função está definida em `utils.sh`, não em `config.sh`; erro se `utils.sh` não foi carregado antes

**Achados esperados:**
- AVISO: `trap … EXIT` no nível global de `config.sh` sobrescreve o trap de `principal.sh` (que define `trap '_resetando' EXIT` depois)
- AVISO: `_ssh_aceitar_novo` usada em `_validar_ssh` (`config.sh`) mas definida em `utils.sh`; se a ordem de carregamento mudar, a função não existe
- INFO: `declare -gA` em nível global — `-g` é válido mas redundante fora de função
- INFO: `${CFG_VERSAOCLASS: -2}` (linha ~280) — espaço antes do `-` necessário para evitar interpretar como `:-` (default value); verificar se está correto

### Subtask 2.2: Analisar constantes.sh

Arquivo: `binarios/constantes.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `BASH_SOURCE[0]` — linhas ~80 e ~85; Bash 3.0+, OK
- `BASH_REMATCH[1]` e `BASH_REMATCH[2]` — linhas ~57-59; Bash 3.2+, OK
- `declare -g "$key=$value"` — Bash 4.2+; dentro de `_carregar_config_seguro`; OK nos alvos
- `LOG_ATU="…$(date +"%Y-%m-%d")…"` e `UMADATA="$(date +"%d-%m-%Y_%H%M%S")"` — chamadas no nível global; `date +"%Y-%m-%d"` é POSIX; OK
- `declare -l base base2 base3 enviabackup` (em `setup.sh`) vs constantes — verificar uso em `constantes.sh`
- `DEFAULT_UNZIP="${DEFAULT_UNZIP:-/usr/bin/unzip}"` — hardcoded `/usr/bin/unzip`; pode não existir em RHEL 8 mínimo sem `unzip` instalado; AVISO documentar
- `DEFAULT_ZIP="${DEFAULT_ZIP:-/usr/bin/zip}"` — mesma situação
- `DEFAULT_FIND="${DEFAULT_FIND:-/usr/bin/find}"` — caminho absoluto; OK em todos os alvos GNU
- `_carregar_config_seguro` definida localmente em `constantes.sh` e também esperada de outro módulo — verificar duplicidade

**Achados esperados:**
- INFO: `DEFAULT_UNZIP` e `DEFAULT_ZIP` com caminhos hardcoded `/usr/bin/` — em RHEL 8, pacotes opcionais podem estar em `/usr/bin/` mas não instalados por padrão; `_check_instalado` mitiga, mas verificar
- INFO: `_carregar_config_seguro` definida em `constantes.sh` e chamada por outros módulos — se `constantes.sh` for carregado depois, a função não existe quando outros tentam chamá-la; verificar ordem de carregamento

---

## Task 3: Verificar utils.sh

Status: not_started
Dependencies: none
Entrega: Seção 3.5 do relatório — utils.sh é o módulo mais crítico e extenso

### Subtask 3.1: Analisar funções de display e terminal

**O que verificar:**
- `_obter_colunas`: `tput cols 2>/dev/null` com fallback `${COLUMNS:-${DEFAULT_COLUMNS}}` — correto
- `_meio_da_tela`: `tput lines 2>/dev/null || echo "${LINES:-${DEFAULT_LINES}}"` — correto
- `_exibir_mensagem_corrida`: `sleep 0.05` — GNU coreutils aceita decimais; BusyBox não; OK nos alvos
- `_linha`: `printf '%*s\n' "$colunas" '' | tr ' ' "$traco"` — POSIX; OK
- `_meia_linha`: `printf -v espacos "%${largura}s" ""` — `printf -v` é Bash 3.1+; OK
- `${var^^}` em `_upper` — Bash 4.0+; OK nos alvos

### Subtask 3.2: Analisar funções de controle de fluxo

**O que verificar:**
- `_aguardar`: `read -rt "$tempo" <> <(:)` — process substitution `<(:)` cria FIFO; `<>` abre leitura+escrita; técnica funciona em Bash 4.0+ Linux com `/dev/fd`; sem problema nos alvos
  - Verificar: `$tempo` pode ser decimal (ex: `0.05`); `read -t` com decimal é Bash 4.0+; OK
- `_confirmar`: `read -r -t "${timeout}" -p "…" resposta` — OK; `${resposta,,}` para lowercase é Bash 4.0+
- `_opinvalida`: `for ((i=0; i<…; i++))` — C-style loop Bash 2.0+; OK; `sleep` via `_aguardar 0.05`

### Subtask 3.3: Analisar funções de progresso (CRÍTICO)

**O que verificar:**
- `_mostrar_progresso_backup` — função mais complexa; verificar detalhadamente:
  - `printf "\033[?25l"` — escape VT100 para ocultar cursor; sem verificação de suporte
  - `exec 3>&1` — abre fd 3; verificar se fd 3 já pode estar em uso
  - `printf "%s" "" >&3` — força flush via fd duplicado; técnica válida
  - `sleep 1` — inteiro; OK
  - `printf "\033[?25h"` — restaura cursor; apenas no bloco de restauração; se `kill -0 "$pid"` falhar fora do loop, cursor pode ficar oculto
  - `exec 3>&-` — fecha fd 3; presente no caminho de saída normal
  - `wait "$pid"` — correto para capturar exit code do background process
  - `printf "\r\033[K"` — ANSI: CR + apagar linha; dependente de terminal ANSI

**Achados esperados:**
- AVISO: `exec 3>&1` sem verificar se fd 3 já está aberto — se o chamador já usa fd 3, será sobrescrito
- AVISO: `printf "\033[?25h"` não está em trap de cleanup; se processo morrer durante o loop, cursor fica oculto
- INFO: `printf "\033[?25l/h"` sem verificar `tput civis/cnorm` disponível
- INFO: `\r\033[K` funciona apenas em terminais ANSI/VT100; em terminals dumb, gera lixo

### Subtask 3.4: Analisar funções de arquivo e inicialização

**O que verificar:**
- `_limpar_arquivos_antigos`: `mapfile -t arquivos < <(find …)` — Bash 4.0+; OK
- `_executar_expurgador_diario`: `local -A configuracoes=(…)` — `-A` em `local` é Bash 4.0+; OK
  - `for dir in "${!configuracoes[@]}"` — iteração sobre chaves de array associativo; Bash 4.0+; OK
- `_check_instalado`: verificar se `apt/yum/dnf/pacman/zypper` são detectados corretamente
- `_enviabackup_para_receber`: `find … -print0 … IFS= read -r -d ''` — padrão correto para nomes com espaços
- `_ssh_aceitar_novo`: retorna `'yes'`; documentar que isto aceita qualquer host na primeira conexão
- `_checar_dependencias`: verifica `ssh ssh-keygen ssh-copy-id` — correto

**Achados esperados:**
- INFO: `_check_instalado` não verifica `sha256sum`, `tar`, `gzip`, `ssh`, `sftp`, `scp`
- INFO: `_ssh_aceitar_novo` retorna `yes` (aceita qualquer fingerprint) — comportamento documentado em AGENTS.md como intencional para servidores legados; registrar para auditoria

---

## Task 4: Verificar auth.sh, cadastro.sh, setup.sh

Status: not_started
Dependencies: none
Entrega: Seções 3.6, 3.7 e 3.8 do relatório

### Subtask 4.1: Analisar auth.sh

Arquivo: `binarios/auth.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `SENHA_FILE="${CFG_DIR:-}/.senhas"` — avaliado no tempo de source; se `CFG_DIR` for vazio, `SENHA_FILE` será `/.senhas` (raiz!) — BLOQUEANTE
- `chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE"` — executado no nível global do arquivo se `.senhas` existir; com `set -e`, se falhar (ex: sem permissão), aborta o carregamento do módulo inteiro
- `declare usuario` — sem `-g`; em Bash 4.2+, `declare` dentro de função cria local, mas aqui é no nível global; OK
- `read -rsp "…" senha` — `-s` (silent) é Bash builtin; OK em todos os alvos
- `_upper "$(_trim "$usuario")"` — `${1^^}` em `_upper`; Bash 4.0+; OK
- `printf '%s' "$senha" | "$algoritmo" | cut -d' ' -f1` — pipe com `sha256sum`; OK
- `awk -F: -v u="$usuario" '…'` — POSIX awk; OK
- `mktemp` para arquivo temporário — POSIX; OK
- `chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE"` após alteração de senha — correto

**Achados esperados:**
- BLOQUEANTE: `SENHA_FILE="${CFG_DIR:-}/.senhas"` — se `CFG_DIR` não estiver definido quando `auth.sh` for sourced, resulta em `/.senhas` (diretório raiz)
- AVISO: `chmod … "$SENHA_FILE"` no nível global com `set -e` — falha no chmod aborta o módulo
- INFO: `declare usuario` sem `declare -g` — é global por estar no nível do arquivo, mas a intenção não é clara; melhor `declare -g usuario`

### Subtask 4.2: Analisar cadastro.sh

Arquivo: `binarios/cadastro.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `BASH_SOURCE[0]` — para detectar diretório; Bash 3.0+, OK
- `"." "${LIBS_DIR}/utils.sh"` — source sem validação prévia de existência/leitura; `|| { echo "…"; _encerrar_programa 1; }` — OK, tem tratamento
- `"." "${LIBS_DIR}/auth.sh"` — mesma situação; OK
- `read -rp "…" -t 5` — timeout 5 (inteiro); OK
- Ausência de `export LC_ALL=C` — pode afetar `awk` e `read` com caracteres especiais

**Achados esperados:**
- INFO: Sem `export LC_ALL=C`; pode causar comportamento inesperado com nomes de usuário contendo acentos (embora a validação `^[A-Z0-9._-]+$` os bloqueie)

### Subtask 4.3: Analisar setup.sh

Arquivo: `binarios/setup.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `declare -l base base2 base3 enviabackup` — Bash 4.0+; `-l` converte para lowercase na atribuição; OK
- `declare -u empresa` — Bash 4.0+; `-u` converte para uppercase; OK
- `"." "${LIBS_DIR}/utils.sh"` — source seguro com tratamento; OK
- `ssh -o BatchMode=yes sav_servidor exit` — sem `StrictHostKeyChecking`; usa config gerado no mesmo script; pode falhar em primeira execução se `~/.ssh/config` ainda não existir
- `mkdir -p "${SSH_DIR}" "${CONTROL_PATH_BASE}"` seguido de `chmod "${PERM_DIR_SECURE}" "${SSH_DIR}"` — `PERM_DIR_SECURE=0755`; `~/.ssh` deve ser `0700` ou `0711` para que o cliente SSH aceite; com `0755` (other+read), SSH cliente pode recusar as chaves
- `cat > "${SSH_CONFIG_FILE}" << EOF` — heredoc; OK; cria `~/.ssh/config` com `chmod "${PERM_FILE_PRIVATE}"` depois; correto
- `read -rp "…" -n1 VERSAO` — lê um caractere; OK
- `echo "${tracejada}"` vs `printf '%s\n' "${tracejada}"` — echo com strings que comecem com `-` pode interpretar flags; usar `printf`; INFO
- `cp .config .config.bkp` — sem verificar se `.config` existe antes (mas o bloco `if` externo garante); OK

**Achados esperados:**
- BLOQUEANTE: `chmod "${PERM_DIR_SECURE}" "${SSH_DIR}"` define `~/.ssh` como `0755`; OpenSSH rejeita chaves quando `~/.ssh` tem permissão `other+read` em algumas configurações. Deve ser `0700`.
- INFO: `echo "${tracejada}"` — preferir `printf '%s\n'` para evitar interpretação de flags
- INFO: `declare -l`/`declare -u` são Bash 4.0+; documentar dependência

---

## Task 5: Verificar vaievem.sh, baixar.sh, sistema.sh

Status: not_started
Dependencies: none
Entrega: Seções 3.9, 3.10 e 3.11 do relatório

### Subtask 5.1: Analisar vaievem.sh

Arquivo: `binarios/vaievem.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `local -n _opts_ref=$1` em `_adicionar_opcoes_chave` — nameref; Bash 4.3+; OK nos alvos (Bash ≥ 4.4)
- `sftp … <<EOF` — heredoc para sftp; OK
- `echo "$sftp_output" | grep -qiE "$regex_erro"` — `grep -iE`; GNU grep; OK nos alvos
- `printf -v ssh_cmd '%s ' "${ssh_cmd_parts[@]}"` — `printf -v` com array; Bash 3.1+; OK
- `rsync -avzP -e "${ssh_cmd}"` — construção de opção `-e` com string; pode falhar se `ssh_cmd` tiver espaços não esperados (é gerada por `printf -v`; verificar se está correto)
- `read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"` — `read -ra` Bash 3.2+; OK; mas divide por IFS (espaço por padrão); se nomes de arquivo tiverem espaços, quebra
- `_validar_caminho_seguro` — regex `[;|&$\`<>"']`; não valida `\n` (newline) nem `\0` — INFO

**Achados esperados:**
- AVISO: `local -n` (nameref) requer Bash 4.3+; RHEL 8 tem Bash 4.4.20, OK, mas documentar como limite inferior
- AVISO: `read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"` — divide por espaço; se ATUALIZA1/2/3 contiverem espaços, os nomes serão partidos incorretamente
- INFO: `rsync … -e "${ssh_cmd}"` onde `ssh_cmd` inclui opções com espaços — funcionará pois rsync trata `-e` como string de comando shell; OK, mas documentar

### Subtask 5.2: Analisar baixar.sh

Arquivo: `binarios/baixar.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `wget -q -c "$link" -O …` — GNU wget; disponível nos alvos; `-c` (continue) e `-q` (quiet); OK
- `chmod +x "$arquivo"` — sem verificar se arquivo existe antes; protegido por `[[ -f "$arquivo" ]] || continue`; OK
- `chmod 600 ".senhas"` — hardcoded `600` em vez de `${PERM_FILE_PRIVATE}`; inconsistência com o padrão do projeto
- `(cd "${DEFAULT_BACKUP_DIR}" && zip -jm "${zip_nome}" ./*.sh.bkp …)` — glob `./*.sh.bkp` em subshell; com `set -e` na subshell, se não encontrar arquivos, `zip` retorna erro e a subshell falha; porém `|| true` ou tratamento está ausente
- `find "${DEFAULT_RECEBE_DIR:?}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +` — uso de `${var:?}` correto para guard; `-exec rm -rf {} +` remove tudo; OK por design, mas é irreversível
- `"${DEFAULT_UNZIP}" -o -j "$origem_zip"` — flag `-j` (junk paths) extrai sem estrutura de diretórios; intencional; OK

**Achados esperados:**
- AVISO: `chmod 600 ".senhas"` hardcoded em vez de `${PERM_FILE_PRIVATE}`; se a constante mudar, esta linha fica desatualizada
- AVISO: `(cd … && zip -jm … ./*.sh.bkp …)` — se glob `*.sh.bkp` não expandir (diretório vazio), `zip` recebe argumento literal e pode falhar; sem tratamento de erro explícito nesta subexpressão

### Subtask 5.3: Analisar sistema.sh

Arquivo: `binarios/sistema.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `ping -c 1 -W 3 google.com` — `-W` (timeout em segundos) é opção GNU; BSD usa `-t`; OK nos alvos Linux
- `uname -o` — `-o` (OS) disponível no GNU; BSD usa `-s`; OK nos alvos Linux
- `grep 'NAME\|VERSION' /etc/os-release` — GNU grep com `\|` (alternativa BRE); portável
- `ip route get 1 | awk '{print $7;exit}'` — `iproute2`; disponível nos alvos; RHEL 8 mínimo pode não ter se instalação foi stripped
- `curl -s ipecho.net/plain` — verificado via `command -v curl`; OK
- `uptime -p` — GNU procps; disponível em Ubuntu/Debian; RHEL 8: disponível em `procps-ng`; OK
- `free | grep -v +` — GNU `free`; filtra linha de buffers/cache; formato mudou entre versões; pode dar resultado vazio em `free` moderno (que não tem a linha `+`)
- `cat "${LOG_TMP}who"` — `LOG_TMP` é diretório (tem `/` no final por definição); resulta em `cat "/path/to/logs/who"` — OK se `LOG_TMP` terminar em `/`
- `who > "${LOG_TMP}who"` — cria arquivo `who` no diretório de logs; sem cleanup explícito exceto `rm -f …` no final; OK
- `df -h | grep -E 'Filesystem|^/dev/'` — GNU df com `-h`; OK nos alvos; `grep -E` disponível
- `sed 's/.*up //' | sed 's/,.*//'` — fallback para `uptime` antigo; dois seds encadeados; OK

**Achados esperados:**
- AVISO: `free | grep -v +` — o sinal `+` era usado na linha `+/- buffers/cache` do `free` antigo (pré-3.3); versões modernas (Ubuntu 20.04+, RHEL 8+) não têm essa linha; `grep -v +` não filtra nada útil e pode retornar todas as linhas; comportamento diferente mas não quebra
- INFO: `ip route get 1 | awk '{print $7;exit}'` — campo `$7` assume formato específico do `ip route`; pode variar se há múltiplas rotas ou em configurações incomuns
- INFO: `ping -c 1 -W 3` — se o host não tiver conectividade, `ping` retorna não-zero; com `&>/dev/null` o erro é descartado; OK por design

---

## Task 6: Verificar arquivos.sh, backup.sh, programas.sh, biblioteca.sh

Status: not_started
Dependencies: none
Entrega: Seções 3.12, 3.13, 3.14 e 3.15 do relatório

### Subtask 6.1: Analisar arquivos.sh

Arquivo: `binarios/arquivos.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `mapfile -t arquivos_temp < "$arquivo_lista"` — Bash 4.0+; OK
- `mapfile -t linhas < "$arquivo_lista"` — em `_editar_lista_arquivos`; Bash 4.0+; OK
- `find "$caminho_base" -type f -iname "$padrao_arquivo" -mtime +0` — `-iname` GNU find; OK; `-mtime +0` significa "modificado há mais de 0 dias" = hoje não; OK
- `printf '%s\0' "${arquivos_zip[@]}" | xargs -0 rm -f` — `xargs -0` com null delimiter; GNU/POSIX; OK
- `find "$diretorio" -mtime +30 -type f -print -delete` — encadeamento `-print -delete`; GNU find; OK
- `ls ATE"${var_ano}"*.dat 2>/dev/null || true` — glob com variável; com `set -e`, `ls` sem match retorna erro; `|| true` mitiga; OK
- `for arquivo in ${base_trabalho}/${padrao_arquivo}` — sem aspas em glob; intencional para expansão de padrão
- `shopt -s nullglob` / `shopt -u nullglob` — correto; usado consistentemente com restauração

**Achados esperados:**
- INFO: `$DEFAULT_ZIP` em `$DEFAULT_ZIP "${DEFAULT_BACKUP_DIR}/…" "${arquivos_zip[@]}"` — `$DEFAULT_ZIP` sem aspas intencional para suportar flags (ex: `"zip -j"`); comentário no código menciona isso, mas é frágil se o valor contiver espaços em outros contextos
- INFO: `find "$diretorio" -mtime +30 … -print -delete` — combinação `-print -delete` conta arquivos pelo output, mas o count depende de `wc -l` que conta linhas; arquivos com newline no nome quebrariam a contagem (improvável em prática)

### Subtask 6.2: Analisar backup.sh

Arquivo: `binarios/backup.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `local -n _base_ref="$1"` em `_validar_pre_backup` — nameref; Bash 4.3+; OK nos alvos (Bash ≥ 4.4)
- `date -d "$data_referencia" +%Y%m%d 2>/dev/null` — GNU `date -d`; OK nos alvos
- `find . -type f -newermt "$data_referencia"` — GNU find; OK nos alvos
- `shopt -s nullglob … shopt -u nullglob` — correto, com restauração imediata
- `mapfile -t arquivos_backup < <(printf '%s\n' … | sort -r)` — Bash 4.0+; OK
- `wc -c < "$arquivo_destino"` — sem nome no output; correto
- `stat -c%s "${arquivo_backup}"` em `_validar_integridade_backup` — GNU stat; sem fallback
- `for arquivo in $padrao` sem aspas em `_executar_backup_multiplos_padroes` — word splitting intencional para glob; com `shopt -s nullglob` ativo; OK
- `"${DEFAULT_UNZIP}" -t "$arquivo_backup"` — integridade via `-t`; OK
- `df -k "$diretorio" | awk 'NR==2 {print $4}'` — POSIX df; OK

**Achados esperados:**
- AVISO: `local -n` (nameref) requer Bash 4.3+; documentar como `backup.sh` tem o requisito mais alto de Bash do projeto
- AVISO: `stat -c%s "${arquivo_backup}"` sem fallback — se `stat` GNU não disponível (improvável nos alvos), falha silenciosa por `|| true`
- INFO: `for arquivo in $padrao` — word splitting intencional mas sem documentação de que `shopt -s nullglob` está ativo naquele ponto

### Subtask 6.3: Analisar programas.sh

Arquivo: `binarios/programas.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `declare -g ARQUIVO_COMPILADO_ATUAL=""` — Bash 4.2+; OK
- `declare -a PROGRAMAS_SELECIONADOS=()` e `declare -a ARQUIVOS_PROGRAMA=()` — nível global; OK
- `local -A seen=()` em `_selecionar_programas_reversao` — associativo local; Bash 4.0+; OK
- `stat -c%s "${arquivo_backup}"` em `_validar_integridade_backup` — GNU stat; sem fallback para BSD
- `stat -c %y "${E_EXEC}/${arquivo}"` em `_obter_data_arquivo` — GNU stat; sem fallback
- `date -d "$data_modificacao" +…` — GNU `date -d`; OK nos alvos; sem fallback
- `for classfile … done < <("${DEFAULT_FIND}" . -type f -name "*.class" -print0)` — process substitution com `-print0`; Bash 3.1+ + GNU find; OK
- `IFS= read -r -d '' classfile` — leitura com null delimiter; correto para nomes com espaços

**Achados esperados:**
- AVISO: `stat -c %y` e `date -d` sem fallback em `_obter_data_arquivo` — falha silenciosa se GNU stat não estiver disponível (improvável nos alvos, mas documentar)
- INFO: `declare -g ARQUIVO_COMPILADO_ATUAL` em nível global — variável de estado global para passagem de resultado entre funções; pode ter problemas com reentrância (segunda chamada antes da primeira terminar)

### Subtask 6.4: Analisar biblioteca.sh

Arquivo: `binarios/biblioteca.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `declare -g pids=()` — global array para PIDs; Bash 4.2+; OK
- `"${DEFAULT_FIND}" … -exec "${DEFAULT_TAR}" -rf "${arquivo_backup_tar}" {} +` — GNU tar com `-rf` (append); OK
- `gzip -f "${arquivo_backup_tar}"` — GNU gzip; disponível em todos os alvos; OK
- `tar -xzf "${arquivo_backup}" -C "/"` — extração na raiz do sistema; `temp_restore="/"` — intencional pois o backup contém caminhos absolutos; AVISO de segurança
- `tar -xzf … --wildcards "*${programa_reverter}*"` — GNU tar; `--wildcards` não é POSIX tar; BSD tar não suporta; OK nos alvos Linux
- `sed -i "s/^VERSAOANT=.*/VERSAOANT=${VERSAO}/" "${CFG_DIR}/.versao"` — GNU `sed -i` sem sufixo; OK nos alvos Linux; BSD precisa de `sed -i ''`
- `read -ra arquivos_update <<< "…"` — divide por IFS; se VERSAO contiver espaços, problema; VERSAO é número simples; OK
- Trap `trap '_limpar_interrupcao' INT` / `TERM` registrado no nível global durante source — interfere com traps de `principal.sh`

**Achados esperados:**
- BLOQUEANTE (segurança, não compatibilidade): `tar -xzf … -C "/"` extrai na raiz do sistema; se o backup estiver corrompido ou malicioso, pode sobrescrever arquivos de sistema; documentar como risco de segurança intencional por design
- AVISO: `sed -i "s/…"` GNU sem sufixo — macOS/BSD requerem `sed -i ''`; OK nos alvos Linux, mas documentar para portabilidade futura
- AVISO: `--wildcards` em `tar` — GNU tar apenas; OK nos alvos
- AVISO: Trap no nível global do arquivo sobrescreve traps registrados por módulos anteriores
- INFO: `gzip -f` sem verificação se o arquivo tar foi criado com sucesso — se o tar falhou silenciosamente, gzip pode retornar 0 em arquivo vazio

---

## Task 7: Verificar menus.sh, help.sh, lembrete.sh, variaveis.sh

Status: not_started
Dependencies: none
Entrega: Seções 3.16, 3.17, 3.18 e 3.19 do relatório

### Subtask 7.1: Analisar menus.sh

Arquivo: `binarios/menus.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- Código de nível global: `caminho="${CFG_DIR:-…}"` e `_criar_diretorio_seguro "${caminho}" …` executado durante o source
  - Se `_criar_diretorio_seguro` falhar, `return 1` aborta o source de `menus.sh`
  - Com `set -e` ativo no shell pai, isso abortaria `principal.sh` inteiro
- `read -r -t "${DEFAULT_READ_TIMEOUT}"` em `_ler_opcao_menu` — timeout como inteiro/decimal; `DEFAULT_READ_TIMEOUT=60`; OK
- `${opcao,,}` — Bash 4.0+; OK
- `"." "${CFG_DIR}/.versao"` em `_menu_biblioteca` — source de arquivo sem validação de segurança; o arquivo `.versao` contém apenas `VERSAOANT=…`; sem validação como `_validar_config_file`
- `_encerrar_programa 0` chamada dentro de menu — termina o processo; OK por design
- `_definir_base_trabalho` usa `${!base_var}` (indirect expansion) — Bash 2.0+; OK

**Achados esperados:**
- AVISO: Código executável no nível global do arquivo (não em função) — `_criar_diretorio_seguro` chamada durante source; se falhar, todo o carregamento de módulos falha
- AVISO: `"." "${CFG_DIR}/.versao"` sem validação de segurança — `.versao` não passa por `_validar_config_file`; risco menor pois o arquivo tem conteúdo simples, mas inconsistente com o padrão de segurança do projeto

### Subtask 7.2: Analisar help.sh

Arquivo: `binarios/help.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `grep -n "^\[${secao}\]$" "$MANUAL_FILE" | cut -d: -f1` — GNU grep; OK; `cut -d:` POSIX; OK
- `tail -n +${linha_inicio}` — POSIX; OK
- `sed -n "${linha_inicio},${linha_fim}p"` — POSIX sed; OK
- `grep -in --color=always "$termo" "$MANUAL_FILE"` — `--color=always` pode gerar escapes ANSI que interferem com outras funções de display; sem verificação se terminal suporta cores
- `read -rsn1 resposta` em `_exibir_paginado` — `-n1` lê um caractere; OK
- `echo "$conteudo" | wc -l` — conta linhas; `echo` com variável pode adicionar newline extra; melhor `printf '%s\n' "$conteudo" | wc -l`; INFO
- `echo "$conteudo" | sed -n "…p"` — mesma situação; `echo` vs `printf`

**Achados esperados:**
- INFO: `grep -in --color=always` — força cores ANSI mesmo em contextos sem terminal; melhor `--color=auto`
- INFO: `echo "$conteudo" | wc -l` — `echo` adiciona newline ao final do conteúdo; pode contar uma linha a mais se `$conteudo` já terminar com newline

### Subtask 7.3: Analisar lembrete.sh

Arquivo: `binarios/lembrete.sh`

**O que verificar:**
- `set -euo pipefail` — linha 2, presente
- `tput cols 2>/dev/null || echo 80` — correto, com fallback; OK
- `fold -s -w "$largura"` — GNU coreutils `fold`; disponível nos alvos; OK
- `${EDITOR:-nano}` — variável de ambiente `EDITOR`; `nano` como fallback; OK; `nano` pode não estar instalado em RHEL mínimo
- `wc -c < "$arquivo_notas"` — sem nome no output; correto
- `cat >> "$arquivo_notas"` — leitura de stdin via `cat`; finalizado por Ctrl+D; OK em terminal interativo; não funciona em contexto não-interativo
- `grep -q '[^[:space:]]' "$arquivo_msg"` — POSIX character class; OK

**Achados esperados:**
- INFO: `${EDITOR:-nano}` — `nano` como fallback; RHEL 8 mínimo pode não ter `nano`; alternativa mais portável seria `${EDITOR:-vi}`
- INFO: `cat >> "$arquivo_notas"` para entrada de usuário — dependente de terminal interativo; sem validação de que `stdin` está disponível

### Subtask 7.4: Analisar variaveis.sh

Arquivo: `binarios/variaveis.sh`

**O que verificar:**
- `set -euo pipefail` — declarado **duas vezes**: linha 2 e linha ~35; redundante mas inofensivo
- `BOLD="$(tput bold)"` — chamado no nível global, sem verificação de terminal ou disponibilidade de `tput`; com `set -e`, se `tput bold` falhar (terminal sem suporte), o source do arquivo abortará
- `declare -gA _VAR_CATEGORIAS=(…)` — Bash 4.0+ (array associativo); OK nos alvos
- `${!_VAR_CATEGORIAS[@]}` — iteração sobre chaves; Bash 4.0+; OK
- `${!var_name:-}` — indirect expansion com default; OK; mas com `set -u` ativo, variáveis indefinidas geram erro se não houver `:-`
- `set -a; "." "$config_file"; set +a` — fallback de carregamento de config; `set -a` exporta todas as variáveis; perigoso se `.config` contém variáveis que não devem ser exportadas; OK pois `_validar_config_file` filtra anteriormente

**Achados esperados:**
- BLOQUEANTE: `BOLD="$(tput bold)"` no nível global — se `tput` não suportar `bold` (terminal `dumb` ou sem `ncurses`), retorna não-zero com `set -e` ativo, abortando o source do módulo e o carregamento inteiro do sistema
- AVISO: `set -euo pipefail` duplicado — sem impacto funcional, mas indica copy-paste; INFO
- INFO: `set -a; "." "$config_file"; set +a` — fallback perigoso que exporta todas as variáveis do config para o ambiente; no flow normal não é atingido pois `_carregar_config_seguro` é usado antes

---

## Task 8: Consolidar relatório final

Status: not_started
Dependencies: Tasks 1, 2, 3, 4, 5, 6, 7 (todos os achados devem estar coletados)
Entrega: Arquivo `relatorio_compatibilidade.md` em `.planning/02-compatibilidade-linux/`

### Subtask 8.1: Agregação e deduplicação dos achados

Consolidar todos os achados das Tasks 1 a 7 em uma única lista deduplicada. Para cada achado, garantir que esteja formatado com:

- **Arquivo**: nome do script
- **Linha**: linha aproximada no arquivo
- **Categoria**: BASH | GNU | SEG | TERM | PAD
- **Severidade**: BLOQUEANTE | AVISO | INFO
- **Descrição**: o que foi encontrado, com contexto
- **Sugestão**: correção concreta e aplicável

### Subtask 8.2: Sumário executivo

Produzir:
- Contagem de achados por severidade (tabela 3 linhas)
- Lista de scripts sem problemas identificados
- Parágrafo de avaliação geral: o código é robusto para os alvos declarados, com poucos bloqueantes que merecem atenção imediata

### Subtask 8.3: Tabela consolidada

Gerar tabela Markdown ordenada por severidade (BLOQUEANTE → AVISO → INFO) e depois por arquivo. Colunas:

```
| Arquivo | Linha | Cat. | Severidade | Descrição resumida |
```

### Subtask 8.4: Análise por arquivo

Uma seção `### 3.N — nome.sh` para cada script, com:
- Status geral (Ex: "Nenhum bloqueante encontrado")
- Lista de achados específicos do arquivo com: linha, descrição completa e sugestão de correção

### Subtask 8.5: Análise por categoria

Seção com os achados agrupados por categoria:

- **BASH** — construções específicas de versão
- **GNU** — dependências de ferramentas GNU
- **SEG** — padrões de segurança
- **TERM** — terminal e fallbacks
- **PAD** — padrões problemáticos

### Subtask 8.6: Recomendações gerais

Seção final com recomendações priorizadas para o projeto:

1. **Correções imediatas (BLOQUEANTES)**:
   - `variaveis.sh`: mover `BOLD="$(tput bold)"` para dentro de função com guarda `[[ -t 1 ]]`
   - `auth.sh`: proteger `SENHA_FILE` contra `CFG_DIR` vazio com `${CFG_DIR:?…}/.senhas`
   - `setup.sh`: corrigir `chmod "${PERM_DIR_SECURE}" "${SSH_DIR}"` para `chmod 0700 "${SSH_DIR}"`
   - `biblioteca.sh`: documentar e auditar extração `tar -C "/"` (risco de segurança, não compatibilidade)
   - `principal.sh`: garantir que `_erro` exista antes de ser chamada nas linhas de inicialização

2. **Melhorias recomendadas (AVISOS)**:
   - Adicionar `|| true` ou substituição de `tput` em `variaveis.sh` linha global
   - Documentar dependência de Bash 4.3+ para `local -n` em `backup.sh` e `vaievem.sh`
   - Adicionar `ssh`, `tar`, `gzip`, `sha256sum` à verificação de dependências em `_check_instalado`
   - Corrigir `chmod "${PERM_DIR_SECURE}" "${SSH_DIR}"` para `0700`
   - Validar `.versao` com `_validar_config_file` antes do source em `menus.sh` e `sistema.sh`

3. **Melhorias opcionais (INFO)**:
   - Substituir `echo` por `printf '%s\n'` em `setup.sh` e `help.sh` para consistência
   - Substituir `${EDITOR:-nano}` por `${EDITOR:-vi}` em `lembrete.sh` para ambientes mínimos
   - Adicionar `grep --color=auto` em `help.sh` para evitar escapes ANSI fora de terminal
   - Documentar `_ssh_aceitar_novo` retornando `yes` como decisão intencional de design
   - Executar ShellCheck em todos os scripts e integrar ao pipeline de CI

4. **Verificação de disponibilidade de pacotes**:
   Nos alvos Ubuntu 20.04+, Debian 11+, RHEL 8+, os seguintes pacotes devem estar instalados:
   - `zip`, `unzip` — não são padrão em instalações mínimas de servidor RHEL
   - `rsync`, `wget` — disponíveis mas podem precisar instalação manual
   - `openssh-client` — para `ssh-copy-id`, `sftp`, `scp`
   - `ncurses-bin` (Debian/Ubuntu) / `ncurses` (RHEL) — para `tput`
   - `iproute2` — para `ip route`

---

## Resumo das Tasks

| Task | Escopo | Scripts | Prioridade |
|---|---|---|---|
| Task 1 | Bootstrap | `atualiza.sh`, `principal.sh` | Alta |
| Task 2 | Core config | `config.sh`, `constantes.sh` | Alta |
| Task 3 | Utilitários | `utils.sh` | Alta (mais extenso) |
| Task 4 | Auth/Setup | `auth.sh`, `cadastro.sh`, `setup.sh` | Alta |
| Task 5 | Rede/Baixar/Sistema | `vaievem.sh`, `baixar.sh`, `sistema.sh` | Média |
| Task 6 | Operações de arquivo | `arquivos.sh`, `backup.sh`, `programas.sh`, `biblioteca.sh` | Média |
| Task 7 | UI e consultas | `menus.sh`, `help.sh`, `lembrete.sh`, `variaveis.sh` | Média |
| Task 8 | Consolidação | Todos | Baixa (depende de todas) |

**Estimativa de achados esperados:**
- BLOQUEANTES: ~5
- AVISOS: ~15-20
- INFOs: ~20-25

**Saída esperada:**
- Arquivo: `.planning/02-compatibilidade-linux/relatorio_compatibilidade.md`
- Formato: Markdown com tabelas, seções por arquivo e por categoria
- Linguagem: Português (pt-br)
