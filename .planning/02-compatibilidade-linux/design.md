# Design — Verificação de Compatibilidade Linux

**Projeto:** Atualiza — Sistema SAV de Atualização Modular  
**Versão:** 1.0 — Julho/2026  

---

## Visão Geral da Abordagem

A verificação de compatibilidade é feita por **análise estática manual** dos 19 scripts Bash. O analisador lê cada arquivo, aplica um checklist de padrões por categoria e registra os achados com localização, severidade e sugestão de correção. Ao final, os achados são consolidados no arquivo `relatorio_compatibilidade.md`.

Não há execução de scripts, não há ferramentas externas de lint (ShellCheck é informativo, mas não é o executor desta análise). A análise segue a leitura humana do código com base em conhecimento das versões de Bash e GNU coreutils disponíveis nos alvos.

---

## Categorias de Verificação

### Categoria BASH — Versão e Sintaxe

Checklist aplicado a cada arquivo:

| Item | Padrão a buscar | Versão mínima | Observação |
|---|---|---|---|
| B01 | `declare -A` | Bash 4.0 | Arrays associativos |
| B02 | `mapfile` / `readarray` | Bash 4.0 | Leitura de array de stream |
| B03 | `${var,,}` / `${var^^}` | Bash 4.0 | Conversão de case inline |
| B04 | `declare -g` | Bash 4.2 | Variável global em função |
| B05 | `local -n` / `declare -n` (nameref) | Bash 4.3 | `local -n _ref="$1"` em `backup.sh` e `config.sh` |
| B06 | `read -t DECIMAL` | Bash 4.0 | `read -rt 0.05 <> <(:)` |
| B07 | `printf -v` | Bash 3.1 | `printf -v var fmt …` |
| B08 | `BASH_SOURCE` | Bash 3.0 | Usado em `atualiza.sh`, `principal.sh`, `constantes.sh`, `cadastro.sh` |
| B09 | `${!var}` indirect expansion | Bash 2.0 | Usar com cuidado em `set -u` |
| B10 | `for ((i=0; …))` | Bash 2.0 | C-style loop |
| B11 | `BASH_REMATCH` | Bash 3.2 | Usado com `=~` em `constantes.sh` |
| B12 | `shopt -s nullglob` | Bash 2.0 | Sem problemas nos alvos |
| B13 | `(( expr )) || true` | Bash 2.0 | Padrão seguro com `set -e` |
| B14 | `read -r -t … -p …` | Bash 2.0 | Sem problemas |
| B15 | `${var: -2}` (substring com espaço antes do `-`) | Bash 3.0 | Espaço é necessário para evitar ambiguidade |

### Categoria GNU — Comandos de Sistema

Checklist de ferramentas externas:

| Item | Comando | Alvo OK? | Risco |
|---|---|---|---|
| G01 | `stat -c "%a"` / `stat -c%s` | Sim (GNU) | macOS/BSD incompatível — `stat -f "%Lp"` é BSD. `config.sh` tem fallback. |
| G02 | `stat -c %y` | Sim (GNU) | Sem fallback em `programas.sh` |
| G03 | `readlink -f` | Sim (GNU coreutils) | OK em todos os alvos Linux |
| G04 | `tput cols/lines/setaf/sgr0/bold/cup/clear` | Sim (ncurses) | Requer terminal; fallback existe em `config.sh` |
| G05 | `find -print0` | Sim (GNU find) | OK nos alvos |
| G06 | `find -newermt "data"` | Sim (GNU find 4.5+) | Disponível em todos os alvos |
| G07 | `find -delete` | Sim (GNU find) | Disponível nos alvos |
| G08 | `find -exec … +` | Sim (POSIX 2008) | OK |
| G09 | `grep -P` | Sim (GNU grep) | BusyBox não tem; nos alvos padrão sim |
| G10 | `grep -n --color=always` | Sim | OK nos alvos |
| G11 | `sed -i "s/…/…/"` | Sim (GNU) | GNU não precisa de sufixo; BSD precisa |
| G12 | `date -d "string"` | Sim (GNU) | Usado em `backup.sh`; BSD usa `-j -f` |
| G13 | `sha256sum` | Sim (GNU coreutils) | OK nos alvos; macOS usa `shasum -a 256` |
| G14 | `ssh-copy-id` | Sim (openssh-client) | Disponível, mas `_check_instalado` não o verifica |
| G15 | `uptime -p` | Sim (GNU procps) | Disponível nos alvos; RHEL 7 pode não ter |
| G16 | `fold -s -w` | Sim (GNU coreutils) | OK nos alvos |
| G17 | `ip route get 1` | Sim (iproute2) | `sistema.sh` — sistemas mínimos podem usar `ifconfig` |
| G18 | `ping -c 1 -W 3` | Sim (GNU) | `-W` é GNU; BSD usa `-t` |
| G19 | `sleep 0.05` | Sim (GNU coreutils) | BusyBox não aceita decimais; nos alvos OK |
| G20 | `wc -c <` (redirecionamento) | Sim | `wc -c < arquivo` vs `wc -c arquivo` (sem nome no output) |
| G21 | `tar -rf` (append) | Sim | GNU tar; usada em `biblioteca.sh` |
| G22 | `tar -xzf … --wildcards` | Sim (GNU tar) | GNU tar aceita `--wildcards`; BSD tar não |
| G23 | `df -k` | Sim | POSIX; ok |
| G24 | `nl -w2 -s')'` | Sim | GNU/BSD; ok nos alvos |
| G25 | `rsync -avzP -e "ssh …"` | Sim | Requer rsync instalado; verificado por `_check_instalado` |

### Categoria SEG — Segurança e Boas Práticas

| Item | Padrão | Verificação |
|---|---|---|
| S01 | `set -euo pipefail` | Presente em cada arquivo? Na linha 1-5? |
| S02 | `umask 077` | Presente em `principal.sh`? |
| S03 | Shebang `#!/usr/bin/env bash` | Em scripts executados diretamente |
| S04 | Ausência de shebang em módulos (sourced) | Convenção do projeto (OK ter shebang em módulos) |
| S05 | Permissão 0600 em `.senhas` | `auth.sh`, `cadastro.sh`, `baixar.sh` |
| S06 | Validação de `.config` antes de carregar | `_validar_config_file` em `config.sh` |
| S07 | Sem `source <arquivo>` direto não validado | Módulos usam `"." arquivo` via `_caminho_modulo` |
| S08 | `export LC_ALL=C` | Presente em `atualiza.sh`; módulos sem setlocale |
| S09 | Trap de EXIT/INT/TERM/QUIT | `config.sh`, `principal.sh` |
| S10 | Variáveis entre aspas em `rm`, `mv`, `cp` | Verificar usos de `rm -rf` sem `--` |

### Categoria TERM — Terminal e Fallbacks

| Item | Padrão | Verificação |
|---|---|---|
| T01 | `tput cols` com fallback `${COLUMNS:-80}` | Verificar em `utils.sh:_obter_colunas` |
| T02 | `tput lines` com fallback `${LINES:-24}` | `utils.sh:_meio_da_tela` |
| T03 | `printf "\033[?25l"` (ocultar cursor) | Sem verificação se terminal suporta |
| T04 | `printf "\033[?25h"` (mostrar cursor) | Restauração garantida? Mesmo em erro? |
| T05 | `exec 3>&1` sem fechar | Verificar se `3>&-` ocorre em todos os caminhos |
| T06 | `\r\033[K` (apagar linha) | Dependente de terminal ANSI; sem verificação |
| T07 | `tput bold/setaf/sgr0` | Chamadas diretas vs. via variáveis globais |

### Categoria PAD — Padrões Problemáticos Específicos

| Item | Padrão | Arquivo | Observação |
|---|---|---|---|
| P01 | `read -rt "$timeout" <> <(:)` | `utils.sh:_aguardar` | Técnica de sleep portável — funciona em Bash 4.0+ Linux. `<> <(:)` requer `/dev/fd` (disponível nos alvos) |
| P02 | `kill -0 "$pid"` | `utils.sh:_mostrar_progresso_backup`, `biblioteca.sh` | OK; verificação de processo sem sinal |
| P03 | `exec 3>&1` / `exec 3>&-` | `utils.sh:_mostrar_progresso_backup` | fd 3 pode já estar em uso; sem verificação |
| P04 | `sleep 1` vs `sleep 0.05` | `utils.sh` | GNU coreutils aceita decimais; OK nos alvos |
| P05 | `for arquivo in $padrao` sem aspas | `backup.sh:_executar_backup_multiplos_padroes` | Word splitting intencional, mas pode falhar com espaços |
| P06 | `"." arquivo` (dot source) | `setup.sh`, `menus.sh` | Usado para carregar `.versao` — sem validação |
| P07 | `${BASH_REMATCH[1]}` | `constantes.sh` | OK; requer `=~` anterior |
| P08 | `compgen -G "padrão"` | `backup.sh` | Extensão Bash; OK nos alvos |
| P09 | `${!configuracoes[@]}` | `utils.sh:_executar_expurgador_diario` | Iteração sobre chaves de array associativo; OK Bash 4.0+ |
| P10 | `read -ra array <<< "$string"` | `biblioteca.sh` | `read -ra` split por IFS; OK Bash 3.2+ |

---

## Abordagem de Análise por Script

Para cada script, a análise segue este fluxo:

1. **Cabeçalho** — verificar shebang, `set -euo pipefail`, `umask` se aplicável
2. **Declarações** — identificar `declare -A`, `declare -g`, `declare -n`, arrays globais
3. **Funções** — varrer corpo de cada função aplicando checklists B, G, S, T, P
4. **Linhas de topo** — código executado no nível global do arquivo (fora de funções)
5. **Saída** — lista de achados com: arquivo, linha aproximada, categoria, severidade, descrição, sugestão

---

## Formato de Saída — `relatorio_compatibilidade.md`

O relatório final terá a seguinte estrutura:

```
# Relatório de Compatibilidade Linux — Atualiza SAV

## 1. Sumário Executivo
   - Total de achados por severidade (tabela)
   - Scripts sem problemas
   - Principais riscos identificados

## 2. Tabela Consolidada
   | Arquivo | Linha | Categoria | Severidade | Descrição |
   Ordenada por: BLOQUEANTE > AVISO > INFO, depois por arquivo

## 3. Análise por Arquivo (seção para cada script)
   ### 3.1 atualiza.sh
   ### 3.2 principal.sh
   … etc.
   Para cada: lista de achados com localização, descrição e sugestão de correção

## 4. Análise por Categoria
   ### 4.1 Bash — Versão e Sintaxe
   ### 4.2 GNU — Comandos de Sistema
   ### 4.3 Segurança
   ### 4.4 Terminal e Fallbacks
   ### 4.5 Padrões Problemáticos

## 5. Recomendações Gerais
   - Prioridade de correção
   - Verificações a adicionar ao sistema de build/CI
   - Scripts candidatos a ShellCheck
```

---

## Achados Conhecidos (Identificados Durante o Design)

Estes achados foram encontrados durante a leitura dos scripts para elaborar este spec e devem ser confirmados e detalhados durante a execução das tasks:

### Achados Confirmados — Alta Relevância

**`utils.sh` — `_mostrar_progresso_backup` (linhas ~320-380)**
- `exec 3>&1` abre fd 3, mas `exec 3>&-` só ocorre nos caminhos de sucesso e de cursor restaurado. Se `kill -0 "$pid"` falhar de forma inesperada, o fd 3 pode vazar.
- `printf "\033[?25l"` oculta cursor sem verificar se o terminal suporta modo VT100. Em terminais seriais ou `xterm-mono`, pode gerar caracteres na tela.
- `printf "\033[?25h"` aparece apenas no caminho normal; erro no `wait` pode deixar cursor oculto.

**`utils.sh` — `_aguardar` (linha ~195)**
- `read -rt "$tempo" <> <(:)` — técnica de sleep portável usando process substitution com fd de leitura-escrita. Requer `/dev/fd` (disponível em todos os alvos). Funciona em Bash 4.0+ Linux. É INFO (boa prática documentar).

**`config.sh` — `_validar_ssh` (linha ~235)**
- `stat -c "%a" "${ssh_key}"` usa `stat` GNU com fallback `stat -f "%Lp"` BSD — fallback correto e presente.

**`programas.sh` — `_obter_data_arquivo` (linha ~490)**
- `stat -c %y` sem fallback. Em sistemas sem GNU `stat`, falha silenciosa por `2>/dev/null`.
- `date -d "$data_modificacao"` sem fallback. Se a string retornada por `stat` tiver fuso horário, `date -d` pode falhar em RHEL 8 com timezone não padrão.

**`backup.sh` — `_executar_backup_incremental` (linha ~155)**
- `date -d "$data_referencia" >/dev/null 2>&1` valida a data corretamente (GNU `date -d`). OK nos alvos.
- `find . -type f -newermt "$data_referencia"` — `newermt` requer GNU find 4.5+. Ubuntu 20.04 tem `find 4.7.0`. OK.

**`biblioteca.sh` — `_reverter_biblioteca_completa` e `_reverter_programa_especifico_biblioteca`**
- `tar -xzf "${arquivo_backup}" -C "/" --wildcards "*${programa_reverter}*"` — `--wildcards` é extensão GNU tar. BSD tar não aceita. OK nos alvos Linux, mas é INFO registrar.

**`setup.sh` — `_configure_ssh_access` (linha ~205)**
- `ssh -o BatchMode=yes sav_servidor exit` sem `StrictHostKeyChecking` — pode bloquear em primeira conexão. Comportamento depende de `~/.ssh/config` gerado no mesmo script (OK por design).
- `mkdir -p "${SSH_DIR}" "${CONTROL_PATH_BASE}"` seguido de `chmod "${PERM_DIR_SECURE}"` — `PERM_DIR_SECURE` é `0755`, mas `~/.ssh` deve ser `0700`. Potencial falha de segurança SSH (cliente rejeitará conexão se `~/.ssh` tiver `o+r`).

**`variaveis.sh` — nível global (linha ~35)**
- `BOLD="$(tput bold)"` chamado no nível global do arquivo (fora de função), sem verificação de `tput` disponível e sem `-t 1`. Se o script for sourced em contexto não-interativo (ex: pipe), `tput` pode falhar.

**`lembrete.sh` — `_mostrar_aviso` e `_visualizar_notas_arquivo`**
- `tput cols 2>/dev/null || echo 80` — correto, com fallback. OK.

**`setup.sh` — `declare -l base base2 base3 enviabackup` e `declare -u empresa` (linhas ~30-31)**
- `declare -l` (lowercase ao atribuir) e `declare -u` (uppercase ao atribuir) são extensões Bash 4.0+. OK nos alvos, mas é Bash-específico — INFO registrar.

**`config.sh` — `_inicializar_sistema_variaveis`**
- `COLUMNS=$(tput cols)` sem `2>/dev/null` em ambiente não-interativo pode gerar erro. O bloco `if [[ -t 1 ]]` protege, mas apenas para stdout. Se sourced com stderr redirecionado, pode falhar.

**`menus.sh` — Código no nível global (linha ~12)**
- `_criar_diretorio_seguro "${caminho}" …` é chamado no nível global durante o source. Se `CFG_DIR` não estiver definido, `caminho` pode ser vazio e a função retorna erro, abortando o carregamento do módulo com `set -e`.

**`principal.sh` — `set -euo pipefail` vs `set -euo pipefail` em módulos**
- Cada módulo tem seu próprio `set -euo pipefail`. Ao serem sourced por `principal.sh` (que já tem `set -e`), o `set` do módulo é redundante mas inofensivo. OK.

**`atualiza.sh`**
- Não tem `set -u` — tem apenas `set -euo pipefail`. OK (completo).
- `export LC_ALL=C` — boa prática, presente.
- `readonly PLIBS_DIR SCRIPT_DIR` — correto.

### Achados Confirmados — `_check_instalado` incompleto

`utils.sh:_check_instalado` verifica `zip unzip rsync wget` por padrão, mas não verifica:
- `ssh`, `sftp`, `scp` (usados em `vaievem.sh`)
- `sha256sum` (usado em `auth.sh` via `HASH_ALGORITHM`)
- `tar`, `gzip` (usados em `biblioteca.sh`)
- `find` (usado extensivamente)
- `ssh-keygen`, `ssh-copy-id` (verificados em `utils.sh:_checar_dependencias`, mas apenas quando a função é chamada)

---

## Critérios de Severidade

```
BLOQUEANTE — Impede execução ou causa falha de dados:
  - Sintaxe Bash não disponível na versão alvo
  - Comando GNU não disponível nos alvos sem alternativa
  - Falha de segurança que quebra execução (ex: .senhas sem 0600 em fluxo crítico)
  - Race condition ou perda de dados confirmada

AVISO — Funciona na maioria dos casos, mas pode falhar em cenários específicos:
  - Comportamento diferente entre distribuições alvo
  - Falta de fallback para condição esperada
  - Padrão depreciado ou propenso a erros silenciosos
  - Potencial problema de segurança que não quebra execução

INFO — Melhoria de robustez, documentação ou clareza:
  - Boa prática não seguida
  - Dependência implícita não documentada
  - Alternativa mais portável disponível
  - Comportamento correto mas não óbvio
```
