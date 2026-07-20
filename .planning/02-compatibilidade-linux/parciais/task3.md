# Seção 3.5 — Análise de Compatibilidade: `binarios/utils.sh`

> **Módulo:** `utils.sh` — Utilitários e Funções Auxiliares
> **Linhas analisadas:** 1–710 (arquivo completo)
> **Data:** 2026-07-20

---

## Resumo do Módulo

`utils.sh` é o módulo mais crítico do sistema: fornece funções de display, controle de fluxo, progresso de processos em background, logging e inicialização. É sourced por praticamente todos os outros módulos. Qualquer falha aqui propaga-se para o sistema inteiro.

**Distribuição dos achados:**

| Severidade | Quantidade |
|---|---|
| BLOQUEANTE | 0 |
| AVISO | 8 |
| INFO | 9 |

---

## Achados

### Grupo 1 — Funções de Display e Terminal

---

**[INFO]** Linha ~18 — BASH
> `_obter_colunas`: a sequência `if ! colunas=$(tput cols 2>/dev/null); then` captura corretamente a falha do `tput`. O fallback `${COLUMNS:-${DEFAULT_COLUMNS}}` é sólido. Padrão exemplar — nenhuma correção necessária. Documentado como INFO para referência positiva.
> **Sugestão:** sem ação. Manter como modelo para outros arquivos que fazem `$(tput cols)` sem fallback (ex: `variaveis.sh`).

---

**[INFO]** Linha ~51 — TERM
> `_meio_da_tela`: usa `tput lines 2>/dev/null || echo "${LINES:-${DEFAULT_LINES}}"`. A construção `$(tput lines 2>/dev/null || echo …)` dentro de command substitution funciona corretamente — se `tput` falha, `echo` fornece o fallback. Correto.
> **Sugestão:** sem ação. Padrão correto para `tput lines`.

---

**[INFO]** Linha ~130 — GNU
> `_exibir_mensagem_corrida`: usa `sleep 0.05` dentro do loop de digitação. GNU coreutils `sleep` aceita decimais desde a versão 8.x (Ubuntu 20.04+, RHEL 8+). OK nos alvos declarados.
> **Sugestão:** sem ação. Documentar que `sleep 0.05` requer GNU coreutils ≥ 8.x — BusyBox não suporta.

---

**[INFO]** Linha ~151 — BASH
> `_linha`: usa `printf '%*s\n' "$colunas" '' | tr ' ' "$traco"`. POSIX puro. Sem dependência de Bash. OK.
> **Sugestão:** sem ação.

---

**[INFO]** Linha ~166 — BASH
> `_meia_linha`: usa `printf -v espacos "%${largura}s" ""`. `printf -v` é extensão Bash 3.1+. OK nos alvos (Bash 4.0+). Padrão eficiente — evita subshell.
> **Sugestão:** sem ação. Registrar que `printf -v` não é POSIX; não usar em contextos que exijam `sh` puro.

---

**[AVISO]** Linha ~44 — BASH
> `_upper`: implementado como `printf '%s' "${1^^}"`. A expansão `${var^^}` converte para maiúsculas e é extensão exclusiva do **Bash 4.0**. Em Bash 3.x (presente em macOS até Catalina e sistemas legados pré-2014) a função falhará silenciosamente ou produzirá saída incorreta. Nos alvos declarados (Ubuntu 20.04+, RHEL 8+) Bash 4.x é garantido, porém o risco vale documentação.
> **Sugestão:** se futuramente houver necessidade de suporte a Bash 3.x, substituir por:
> ```bash
> printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
> ```

---

### Grupo 2 — Funções de Controle de Fluxo

---

**[AVISO]** Linha ~187 — PAD
> `_aguardar`: usa `read -rt "$tempo" <> <(:)` como substituto de `sleep`. A técnica é portável nos alvos (requer `/dev/fd`, disponível em Linux; `/dev/fd` é symlink para `/proc/self/fd` no kernel Linux 2.6+). O `<> <(:)` abre a FIFO do process substitution em modo leitura-escrita para evitar o bloqueio do `read`. Funciona em Bash 4.0+ Linux.
> **Problema concreto:** `read -t DECIMAL` requer **Bash 4.0** para aceitar valores fracionários (ex: `0.05`). Em Bash 3.x, `read -t` aceita apenas inteiros — `_aguardar 0.05` retornaria imediatamente com `read: invalid timeout specification`. Embora os alvos sejam Bash 4.0+, o fallback de erro da função (`return 1`) deixa o chamador sem espera.
> **Sugestão:** adicionar comentário explicitando a dependência:
> ```bash
> # Requer Bash 4.0+ (read -t aceita decimais) e /dev/fd (Linux 2.6+)
> ```

---

**[AVISO]** Linha ~218 — BASH
> `_confirmar`: usa `${resposta,,}` para converter a resposta para minúsculas. `${var,,}` é **Bash 4.0+** exclusivo. Se sourced em Bash 3.x, a expansão retorna a string literal sem conversão, fazendo com que respostas como "S" ou "SIM" não sejam reconhecidas em nenhuma branch do `case`.
> **Sugestão:** proteger com fallback ou documentar claramente:
> ```bash
> # ${resposta,,} requer Bash 4.0+
> resposta=$(printf '%s' "$resposta" | tr '[:upper:]' '[:lower:]')
> ```

---

**[INFO]** Linha ~197 — PAD
> `_aguardar`: a expressão regular de validação `^[0-9]+([.][0-9]+)?$` valida corretamente números inteiros e decimais com ponto. O `|| :` ao final do `read` absorve o exit code 1 (timeout expirado) intencionalmente. Padrão correto.
> **Sugestão:** sem ação. Lógica de validação adequada.

---

**[INFO]** Linha ~253 — BASH
> `_opinvalida`: usa `for ((i=0; i<${#mensagem}; i++))` — loop aritmético estilo C. Disponível desde Bash 2.0. Sem problemas nos alvos. `_aguardar 0.05` via função (não `sleep` direto) — correto.
> **Sugestão:** sem ação.

---

### Grupo 3 — `_mostrar_progresso_backup` (CRÍTICO)

---

**[AVISO]** Linha ~307 — TERM
> `printf "\033[?25l"` oculta o cursor (sequência DEC Private Mode Set). Não há verificação de suporte a VT100/xterm antes de emitir a sequência. Em emuladores de terminal não-VT100 (terminais seriais, `dumb`, `xterm-mono`) ou quando `$TERM` não está definido, a sequência ANSI é enviada literalmente para a saída, podendo aparecer como lixo na tela.
> **Sugestão:** verificar `$TERM` e `tput` antes de emitir sequências de cursor:
> ```bash
> if [[ -n "${TERM:-}" ]] && tput civis 2>/dev/null; then
>     _cursor_oculto=1
> fi
> ```
> Alternativamente: `tput civis 2>/dev/null || true` (mais portável que a sequência raw).

---

**[AVISO]** Linha ~311 — TERM
> `exec 3>&1` abre o fd 3 para forçar flush do stdout. O problema é que **fd 3 pode já estar em uso pelo processo chamador** — por exemplo, se o script foi invocado com `3>algum_arquivo` ou se outro módulo usou `exec 3>&…` sem fechar. Sobrescrever fd 3 silenciosamente redirecionaria esse fd e poderia causar perda de dados ou comportamento inesperado.
> **Sugestão:** verificar se fd 3 está livre antes de usar, ou usar um fd dinâmico:
> ```bash
> # Alocar fd dinamicamente (Bash 4.1+)
> exec {_fd_flush}>&1
> # ... usar >&${_fd_flush} no lugar de >&3
> exec {_fd_flush}>&-
> ```
> Se `exec {var}>&fd` (Bash 4.1+) for adotado, documentar como requisito mínimo de versão.

---

**[AVISO]** Linha ~332 — TERM
> `printf "\033[?25h"` (restaurar cursor) ocorre apenas no **caminho de saída normal** — após o loop e o `wait`. Se o processo for interrompido por sinal (`SIGINT`, `SIGTERM`) enquanto o loop `while kill -0` está em execução, a função termina abruptamente sem restaurar o cursor. O terminal fica com cursor oculto permanentemente até ser reiniciado.
> **Sugestão:** adicionar `trap` local para restauração do cursor:
> ```bash
> _mostrar_progresso_backup() {
>     # ...
>     trap 'printf "\033[?25h" 2>/dev/null; exec 3>&- 2>/dev/null' RETURN INT TERM
>     # ... corpo da função
> }
> ```
> O `trap … RETURN` garante execução ao sair da função por qualquer caminho.

---

**[AVISO]** Linha ~332 — TERM
> `exec 3>&-` (fecha fd 3) aparece apenas no final da função, **após** `printf "\033[?25h"`. Se a execução for interrompida por sinal antes desse ponto (durante o loop ou durante `wait`), o fd 3 não é fechado. Embora Bash feche fds ao terminar o processo, um processo de longa duração com múltiplas chamadas à função pode acumular fds abertos.
> **Sugestão:** o `trap … RETURN` proposto acima (achado anterior) também resolve este problema — incluir `exec 3>&-` no handler do trap.

---

**[AVISO]** Linha ~316 — TERM
> `printf "\r\033[K"` (CR + erase-to-end-of-line) aparece no padrão de exibição de progresso. A sequência `\033[K` é uma sequência ANSI que requer terminal compatível. Nos alvos (terminais Linux padrão), é segura. Porém, quando o script é executado com stdout redirecionado para arquivo ou pipe (`./atualiza.sh > saida.log`), a sequência ANSI é gravada literalmente no arquivo, poluindo o log.
> **Sugestão:** verificar `[[ -t 1 ]]` antes de usar sequências ANSI ou usar `tput el` com fallback:
> ```bash
> if [[ -t 1 ]]; then
>     printf "\r\033[K..."
> else
>     printf "\n..."  # fallback sem ANSI
> fi
> ```

---

**[INFO]** Linha ~325 — GNU
> `sleep 1` no loop de progresso usa inteiro — correto. Sem uso de decimais aqui.
> **Sugestão:** sem ação.

---

**[INFO]** Linha ~313 — PAD
> `printf "%s" "" >&3` — técnica de flush explícito redirecionando para o fd 3 (que aponta para stdout). A intenção é forçar o flush do buffer de stdout em sistemas onde o pipe usa buffering completo. Tecnicamente, `printf "" >&3` não force-flushes o buffer do kernel; apenas garante que o write(2) é chamado. Em Bash, stdout de um terminal é line-buffered por padrão, então em uso interativo o efeito prático é mínimo. INFO para documentação.
> **Sugestão:** comentar a intenção explicitamente no código:
> ```bash
> # Garante que o output chega ao terminal mesmo em pipe com buffering completo
> printf "%s" "" >&3
> ```

---

### Grupo 4 — Funções de Arquivo e Inicialização

---

**[INFO]** Linha ~406 — BASH
> `_limpar_arquivos_antigos`: usa `mapfile -t arquivos < <(find …)`. `mapfile` é **Bash 4.0+**. Nos alvos, OK. A técnica é preferível a `for f in $(find …)` pois trata corretamente nomes com espaços e caracteres especiais.
> **Sugestão:** sem ação. Padrão correto para Bash 4.0+.

---

**[INFO]** Linha ~424 — BASH
> `_executar_expurgador_diario`: usa `local -A configuracoes=(…)` — array associativo declarado como `local`. `local -A` requer **Bash 4.0**. OK nos alvos. A iteração `${!configuracoes[@]}` sobre chaves do array é padrão correto Bash 4.0+.
> **Sugestão:** sem ação.

---

**[AVISO]** Linha ~456 — SEG
> `_check_instalado`: a lista padrão verifica apenas `zip unzip rsync wget`. O sistema usa outros comandos críticos que **não são verificados** por esta função:
> - `ssh`, `sftp`, `scp` — usados em `vaievem.sh` para todas as transferências remotas
> - `sha256sum` — usado em `auth.sh` para hash de senhas (ausência causa falha silenciosa na autenticação)
> - `tar`, `gzip` — usados em `biblioteca.sh` para backup/restore de bibliotecas
> - `find` — usado extensivamente em todos os módulos
> - `ssh-keygen`, `ssh-copy-id` — verificados apenas localmente em `_checar_dependencias`, não no check global
>
> A ausência de `sha256sum` é particularmente crítica: `auth.sh` pode falhar na validação de senha sem mensagem de erro clara, deixando o sistema inacessível.
> **Sugestão:** expandir a lista padrão e/ou criar verificação específica para dependências de segurança:
> ```bash
> # Lista padrão expandida
> [[ ${#apps[@]} -eq 0 ]] && apps=(zip unzip rsync wget ssh tar gzip sha256sum)
> ```

---

**[INFO]** Linha ~504 — PAD
> `_enviabackup_para_receber`: usa `while IFS= read -r -d '' arquivo; do … done < <(find … -print0)`. Padrão correto para nomes de arquivo com espaços, newlines e caracteres especiais. `-print0` + `read -d ''` é o idioma canônico.
> **Sugestão:** sem ação. Padrão exemplar.

---

**[AVISO]** Linha ~534 — SEG
> `_ssh_aceitar_novo`: retorna a string `'yes'` como valor para `StrictHostKeyChecking`. O comentário explica corretamente a motivação (compatibilidade com servidores legados que não suportam `accept-new`). Porém, `StrictHostKeyChecking=yes` tem semântica **oposta** ao esperado pelo nome da função:
> - `accept-new` (OpenSSH ≥ 7.6): aceita automaticamente fingerprints desconhecidos, mas rejeita fingerprints alterados (proteção contra MITM)
> - `yes`: rejeita qualquer host desconhecido — **bloqueia na primeira conexão**
> - `no`: aceita qualquer host sem verificação (sem proteção MITM)
>
> O nome `_ssh_aceitar_novo` sugere "aceitar novos hosts automaticamente", mas o valor retornado (`yes`) faz o oposto. O comentário indica que o valor real utilizado em produção deveria ser `no` para aceitar servidores legados, ou a função foi nomeada com base em intenção futura. O uso em `_testar_conexao` com `StrictHostKeyChecking=$(_ssh_aceitar_novo)` resulta em `StrictHostKeyChecking=yes`, que **bloqueará** na primeira conexão a um servidor novo (dependendo de `~/.ssh/known_hosts`).
> **Sugestão:** alinhar o valor retornado com a intenção documentada. Se a intenção for aceitar servidores legados sem verificação de fingerprint, o valor correto é `no`. Se a intenção for aceitar apenas novos (e rejeitar alterações), o valor correto é `accept-new` com fallback para `no` em OpenSSH < 7.6:
> ```bash
> _ssh_aceitar_novo() {
>     # Usa accept-new se disponível (OpenSSH 7.6+), senão no
>     if ssh -o StrictHostKeyChecking=accept-new -V 2>&1 | grep -q "OpenSSH"; then
>         printf 'accept-new'
>     else
>         printf 'no'
>     fi
> }
> ```
> Ou, mantendo compatibilidade máxima com servidores legados documentada explicitamente:
> ```bash
> _ssh_aceitar_novo() {
>     # ATENÇÃO: retorna 'no' — aceita qualquer fingerprint.
>     # Intencional para compatibilidade com RHEL 6 / CentOS 6 (OpenSSH < 7.6).
>     printf 'no'
> }
> ```

---

### Grupo 5 — Cabeçalho e Nível Global

---

**[INFO]** Linha ~1 — SEG
> Shebang `#!/usr/bin/env bash` presente. `set -euo pipefail` na linha 2. Correto para módulo que pode ser executado diretamente. Conforme convenções do projeto.
> **Sugestão:** sem ação.

---

**[INFO]** Linha ~14 — SEG
> `RAIZ="${RAIZ:-}"` — inicialização defensiva com fallback para string vazia. Evita erro `unbound variable` com `set -u`. Correto.
> **Sugestão:** sem ação.

---

## Tabela Consolidada — `utils.sh`

| Linha | Função | Categoria | Severidade | Descrição curta |
|---|---|---|---|---|
| ~44 | `_upper` | BASH | AVISO | `${1^^}` requer Bash 4.0 |
| ~187 | `_aguardar` | PAD | AVISO | `read -t DECIMAL` requer Bash 4.0; documentar dependência |
| ~218 | `_confirmar` | BASH | AVISO | `${resposta,,}` requer Bash 4.0 |
| ~307 | `_mostrar_progresso_backup` | TERM | AVISO | `\033[?25l` sem verificação de suporte VT100 |
| ~311 | `_mostrar_progresso_backup` | TERM | AVISO | `exec 3>&1` pode colidir com fd 3 já em uso pelo chamador |
| ~332 | `_mostrar_progresso_backup` | TERM | AVISO | `\033[?25h` e `exec 3>&-` ausentes em caminhos de erro/sinal |
| ~316 | `_mostrar_progresso_backup` | TERM | AVISO | `\r\033[K` emite ANSI mesmo com stdout redirecionado |
| ~456 | `_check_instalado` | SEG | AVISO | Lista padrão incompleta: `ssh`, `sha256sum`, `tar`, `gzip` ausentes |
| ~534 | `_ssh_aceitar_novo` | SEG | AVISO | Retorna `'yes'` (bloqueia novos hosts); nome implica comportamento oposto |
| ~18 | `_obter_colunas` | TERM | INFO | Fallback correto — padrão exemplar |
| ~51 | `_meio_da_tela` | TERM | INFO | Fallback correto para `tput lines` |
| ~130 | `_exibir_mensagem_corrida` | GNU | INFO | `sleep 0.05` requer GNU coreutils ≥ 8.x |
| ~166 | `_meia_linha` | BASH | INFO | `printf -v` requer Bash 3.1+ (não POSIX sh) |
| ~197 | `_aguardar` | PAD | INFO | Lógica de validação do tempo correta |
| ~253 | `_opinvalida` | BASH | INFO | C-style loop OK em Bash 2.0+ |
| ~325 | `_mostrar_progresso_backup` | GNU | INFO | `sleep 1` correto (inteiro) |
| ~313 | `_mostrar_progresso_backup` | PAD | INFO | Flush via `>&3` — documentar intenção no código |
| ~406 | `_limpar_arquivos_antigos` | BASH | INFO | `mapfile` requer Bash 4.0 — padrão correto |
| ~504 | `_enviabackup_para_receber` | PAD | INFO | `-print0` + `read -d ''` — padrão exemplar |

---

## Prioridade de Correção

1. **`_ssh_aceitar_novo` (linha ~534)** — ambiguidade semântica entre nome e valor retornado pode causar comportamento inesperado em produção. Revisar com stakeholders o comportamento desejado antes de corrigir.
2. **`_mostrar_progresso_backup` (linhas ~307–345)** — três problemas relacionados de restauração de estado de terminal: cursor, fd 3 e ANSI em não-terminal. Corrigíveis com um único `trap … RETURN` + `[[ -t 1 ]]`.
3. **`_check_instalado` (linha ~456)** — lista incompleta de dependências. Correção simples e de alto impacto, especialmente para `sha256sum` (auth) e `ssh` (transferências).
4. **`_upper` e `_confirmar`** — Bash 4.0 já é o mínimo declarado nos alvos; documentar como requisito mínimo é suficiente.
