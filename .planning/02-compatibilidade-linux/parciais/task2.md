# Seções 3.3 e 3.4 — Análise de Compatibilidade Linux

> **Análise estática** de `binarios/config.sh` e `binarios/constantes.sh`.
> Nenhum script foi executado. Referências de linha são aproximadas (prefixo `~`).
> Versões-alvo: Ubuntu 20.04 LTS+, Debian 11+, RHEL/CentOS 8+. Bash mínimo: 4.0.

---

## 3.3 `binarios/config.sh`

### Achados

**[AVISO]** Linha ~21-24 — BASH
> `declare -ga REGISTRO_VARIAVEIS=()`, `declare -gA REGISTRO_CATEGORIAS=()`, `declare -gA _REGISTRO_MAPA=()` e `declare -g VAR_CONTADOR_REGISTRO=0` usam o atributo `-g` no nível global do arquivo (fora de função). O flag `-g` é específico do Bash 4.2+ e é redundante fora de função — a variável já seria global neste escopo. Inofensivo nas versões-alvo, mas marca desnecessária dependência de Bash 4.2.
>
> **Sugestão:** No nível global, trocar `declare -ga` por `declare -a` e `declare -gA` por `declare -A`. Reservar `-g` apenas para declarações dentro de funções, onde é necessário.

---

**[AVISO]** Linha ~108-119 — TERM
> Dentro do bloco `if [[ -t 1 ]] && command -v tput`, as chamadas `tput bold` nas atribuições de cor não têm `2>/dev/null`, mas as chamadas de `tput setaf N` imediatamente seguintes têm. Exemplo: `VERMELHO=$(tput bold; tput setaf 1 2>/dev/null)`. Se `tput bold` falhar (terminal não suporta), o stderr vaza para o chamador e pode corromper logs.
>
> **Sugestão:** Aplicar `2>/dev/null` à subshell inteira: `VERMELHO=$(tput bold 2>/dev/null; tput setaf 1 2>/dev/null)`.

---

**[BLOQUEANTE]** Linha ~125 — BASH
> A variável `BRANCO` é definida apenas no ramo `if [[ -t 1 ]] && command -v tput` (terminal colorido). No ramo `else` (fallback de cores), `BRANCO` não é atribuída. Com `set -u` ativo em todo o sistema, qualquer uso de `$BRANCO` num terminal sem tput causará `unbound variable` e abortará a execução.
>
> **Sugestão:** Adicionar `BRANCO="\033[1;37m"` (ou `BRANCO=""`) no bloco `else`:
> ```bash
> else
>     VERMELHO="\033[0;31m"
>     ...
>     BRANCO="\033[1;37m"   # adicionar esta linha
>     NORMAL="\033[0m"
> ```

---

**[AVISO]** Linha ~120 — TERM
> `COLUMNS=$(tput cols)` está dentro do bloco protegido por `[[ -t 1 ]] && command -v tput`, o que é correto. Porém a chamada não tem `2>/dev/null`. Se `tput cols` falhar em algum terminal atípico que satisfaz `[[ -t 1 ]]` mas não suporta a capability `cols`, o stderr vazará e `COLUMNS` receberá string vazia — causando erro com `set -u` posteriormente.
>
> **Sugestão:** `COLUMNS=$(tput cols 2>/dev/null || echo 80)`.

---

**[BLOQUEANTE]** Linha ~400 — PAD
> Em `_validar_ssh`, a chamada `$(_ssh_aceitar_novo)` usa o nome `_ssh_aceitar_novo`. Conforme `AGENTS.md` e `utils.sh`, a função correta é `_ssh_aceitar_novo` (em português, padrão de nomenclatura do projeto). Se `_ssh_aceitar_novo` não existe como alias ou wrapper, a chamada falha silenciosamente retornando string vazia (StrictHostKeyChecking= vazio) ou, com `set -e`, aborta a execução.
>
> **Sugestão:** Corrigir o nome da chamada:
> ```bash
> local ssh_opts=("-o" "ConnectTimeout=${ssh_timeout}" "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)")
> ```

---

**[AVISO]** Linhas finais (~último bloco global) — SEG
> O arquivo termina com três `trap` no nível global:
> ```bash
> trap '_limpar_estado_variaveis' EXIT
> trap '_encerrar_programa' INT TERM
> trap '_limpeza_emergencia' QUIT
> ```
> Esses traps são instalados durante o `source` de `config.sh` por `principal.sh`. Como `principal.sh` instala seus próprios traps de limpeza antes de carregar os módulos, os traps de `config.sh` **sobrescrevem** os traps de `principal.sh` silenciosamente. Além disso, `_configurar_limpeza_automatica()` (definida no mesmo arquivo) instala `trap '_limpar_estado_variaveis' EXIT INT TERM` — conflitando com os traps globais do arquivo que usam `_encerrar_programa` para INT/TERM.
>
> **Sugestão:** Remover os três `trap` do nível global do arquivo. A instalação de traps deve ocorrer exclusivamente via `_configurar_limpeza_automatica()`, chamada de forma controlada por `principal.sh` ou `_inicializar_sistema_variaveis()`.

---

**[AVISO]** Linha ~393 — SEG
> `trap '_encerrar_programa' INT TERM` no nível global (e em `_configurar_limpeza_automatica`) não passa código de saída ao handler. `_encerrar_programa` tem `local status="${1:-0}"`, portanto sempre sai com código 0 quando acionada por sinal. Isso mascarará saídas forçadas para o processo pai, tornando impossível distinguir término normal de interrupção por sinal.
>
> **Sugestão:** Usar convention de exit code baseado em sinal:
> ```bash
> trap '_encerrar_programa 130' INT   # 128 + 2 (SIGINT)
> trap '_encerrar_programa 143' TERM  # 128 + 15 (SIGTERM)
> ```

---

**[INFO]** Linha ~218 — BASH
> `local verclass_sufixo="${CFG_VERSAOCLASS: -2}"` — o espaço antes do `-` é **necessário e correto** para evitar ambiguidade com o operador `:-` (valor padrão). Bash 3.0+ interpreta corretamente como substring dos 2 últimos caracteres. Não é problema — registrado como documentação de intenção não óbvia.
>
> **Sugestão:** Adicionar comentário inline: `# espaço antes do - é intencional (substring, não default)`.

---

**[INFO]** Linha ~277 — GNU
> `stat -c "%a" "${ssh_key}" 2>/dev/null || stat -f "%Lp" "${ssh_key}" 2>/dev/null || echo "?"` — implementa corretamente o fallback GNU→BSD→literal. Padrão correto; registrado como confirmação positiva do checklist G01.

---

**[INFO]** Linha ~318 — GNU
> `tamanho=$(wc -c < "$CONFIG_FILE" 2>/dev/null || echo 0)` — uso de redirecionamento `<` garante que `wc -c` não inclua o nome do arquivo no output (comportamento POSIX quando não há argumento de arquivo). Correto.

---

**[INFO]** Linha ~338 — GNU
> `printf '%s\n' "$linha" | grep -qE '[\`\;|\&<>(){}]'` — `grep -E` (ERE) está disponível em todos os alvos GNU. O `|` dentro da classe de caracteres `[...]` é literal (não é alternância), o que é semanticamente correto para detectar o pipe `|` como caractere perigoso. Correto.

---

### Resumo 3.3

| Severidade | Qtd |
|---|---|
| BLOQUEANTE | 2 |
| AVISO | 5 |
| INFO | 3 |

---

## 3.4 `binarios/constantes.sh`

### Achados

**[AVISO]** Linha ~2 — PAD
> `set -euo pipefail` presente — correto. Porém o arquivo define `_encerrar_programa()` localmente (linhas ~5-8) com implementação própria (`exit "$status"`), e `config.sh` também define `_encerrar_programa()` com implementação diferente (chama `_finalizar_sistema` antes de sair). Quando ambos são sourced por `principal.sh`, a segunda definição sobrescreve silenciosamente a primeira. O resultado depende da ordem de carregamento.
>
> **Sugestão:** Renomear a versão local de `constantes.sh` para `_encerrar_programa_local()` e usá-la apenas dentro do próprio arquivo para o caso de carregamento direto, ou remover a duplicata e depender exclusivamente da versão de `config.sh` (carregado depois).

---

**[INFO]** Linha ~28 — BASH
> `BASH_SOURCE[0]` — disponível desde Bash 3.0. OK em todos os alvos.
> `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` — padrão idiomático para resolver o diretório real do script. Correto e portável nos alvos. Requer que o diretório pai exista no momento do source; em uso normal, sempre verdade.

---

**[BLOQUEANTE]** Linha ~61 — BASH
> `declare -g "$key=$value"` dentro de `_carregar_config_seguro()` — o flag `-g` é extensão do Bash 4.2+. Os alvos mínimos declarados no spec (Ubuntu 20.04 = Bash 5.0, RHEL 8 = Bash 4.4, Debian 11 = Bash 5.1) atendem ao requisito. **No entanto**, se o projeto for eventualmente executado em RHEL 7 (Bash 4.2.46) ou CentOS 7 (Bash 4.2), o comportamento é correto. Se executado em sistemas com Bash 4.0 ou 4.1, o flag `-g` não é reconhecido e todas as variáveis carregadas de `.config` ficam confinadas ao escopo local da função — nenhuma variável do `.config` seria exportada para o ambiente global. Isso causaria falha silenciosa e completa do carregamento de configuração.
>
> **Sugestão:** Documentar explicitamente que Bash 4.2+ é requisito mínimo. Se for necessário suportar Bash 4.0/4.1, substituir `declare -g "$key=$value"` por `eval "$key=\"\$value\""` com validação rigorosa prévia do `$key` (já feita pelo regex `^([A-Za-z_][A-Za-z0-9_]*)=`).

---

**[AVISO]** Linha ~57-59 — BASH
> `BASH_REMATCH[1]` e `BASH_REMATCH[2]` usados após `[[ "$linha" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]`. `BASH_REMATCH` disponível desde Bash 3.2. OK nos alvos. Porém o segundo uso de `BASH_REMATCH[1]` (linhas ~62-65, para remoção de aspas) pode capturar o resultado de um `=~` diferente se houver qualquer teste `=~` intermediário entre o match e o acesso ao array. Análise do fluxo mostra que não há `=~` intermediário no mesmo escopo neste loop — seguro. Registrado como ponto de atenção para futura manutenção.
>
> **Sugestão:** Capturar o valor em variável local imediatamente após o match: `key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"` — já feito corretamente nas linhas ~59-60. Adicionar comentário alertando que `BASH_REMATCH` não deve ser usado após qualquer `=~` intermediário.

---

**[AVISO]** Linha ~104-119 — PAD
> O nível global do arquivo chama `_carregar_config_seguro "$CONFIG_FILE"` apenas se `command -v _carregar_config_seguro >/dev/null 2>&1` retornar verdadeiro. A função está definida **no mesmo arquivo** (linhas ~37-72), então quando `constantes.sh` é executado diretamente (não sourced), a função existe. Quando sourced por `principal.sh`, a função também existe. **Porém**, se por alguma razão o source for parcial (ex: erro com `set -e` antes da linha ~37), a função não existirá e o bloco de verificação com `command -v` fará o carregamento ser bloqueado com a mensagem de erro. Este é o comportamento correto — mas a mensagem de erro "Parser seguro não disponível" pode ser confusa, pois a causa real seria um erro de source anterior.
>
> **Sugestão:** Adicionar comentário explicando que `_carregar_config_seguro` é definida neste arquivo e a verificação via `command -v` é uma guarda de segurança contra source parcial.

---

**[AVISO]** Linha ~148-153 — GNU
> Caminhos hardcoded nos defaults:
> - `DEFAULT_UNZIP="${DEFAULT_UNZIP:-/usr/bin/unzip}"` — em sistemas RHEL 8 mínimo sem o pacote `unzip`, o arquivo não existe. O default aponta para um caminho que pode não existir, criando falsa segurança: `DEFAULT_UNZIP` sempre terá valor (não vazio), então `_configurar_comandos` em `config.sh` tentará verificar `/usr/bin/unzip` com `command -v` — que falhará corretamente. Contudo, se `command -v` retornar true para o caminho (o que não ocorre), o caminho hardcoded seria usado diretamente sem validar a presença do binário. Comportamento aceitável, mas o default não garante presença.
> - `DEFAULT_FIND="${DEFAULT_FIND:-/usr/bin/find}"` — em alguns sistemas minimalistas ou containers, `find` pode estar em `/bin/find` (symlink ou path diferente). GNU coreutils nos alvos padrão tem em `/usr/bin/find`. OK nos alvos declarados.
> - `DEFAULT_WHO="${DEFAULT_WHO:-/usr/bin/who}"` — não aparece no checklist de `_configurar_comandos` em `config.sh`; nunca é validado quanto à presença.
>
> **Sugestão:** Usar apenas o nome do comando como default (sem caminho absoluto), deixando a resolução de PATH para `command -v`:
> ```bash
> DEFAULT_UNZIP="${DEFAULT_UNZIP:-unzip}"
> DEFAULT_ZIP="${DEFAULT_ZIP:-zip}"
> DEFAULT_FIND="${DEFAULT_FIND:-find}"
> ```
> O caminho absoluto só agrega valor se PATH não for confiável — nesse caso, a validação deve ser mais rigorosa.

---

**[INFO]** Linha ~170-173 — GNU
> `LOG_ATU="${LOG_ATU:-${DEFAULT_LOGS_DIR}/atualiza.$(date +"%Y-%m-%d").log}"` — `date +"%Y-%m-%d"` é POSIX e funciona em todos os alvos. A expansão ocorre no nível global do arquivo no momento do source, portanto a data é fixada na hora do carregamento de `constantes.sh`, não na hora de cada escrita de log. Isso é o comportamento esperado (nome de arquivo fixo por dia), mas significa que um processo que roda à meia-noite muda de arquivo de log no carregamento seguinte (correto) e não no meio da execução (sem problema para processos de curta duração).

---

**[AVISO]** Linha ~87-101 — SEG
> O bloco de carregamento do `.config` testa `[[ ! -f "$CONFIG_FILE" ]]` e define valores padrão vazios. No entanto, ao definir `verclass=""`, `acessossh=""`, etc., essas variáveis ficam com string vazia. Mais abaixo (linhas ~122-132), as variáveis CFG_* são atribuídas via `${CFG_VERSAOCLASS:-${verclass}}` — se `CFG_VERSAOCLASS` não estiver definida E `verclass` for vazia, `CFG_VERSAOCLASS` ficará vazia. Com `set -u` ativo, o uso subsequente de `${CFG_VERSAOCLASS: -2}` em `config.sh` (que exige valor não-vazio para fazer sentido) não causará erro de `unbound variable` (a variável existe, está vazia), mas produzirá `verclass_sufixo=""` — e `compilado="-class"` em vez de um sufixo como `-class26`. O sistema continuaria sem erro imediato, mas com valores funcionalmente incorretos.
>
> **Sugestão:** Adicionar validação explícita após o carregamento:
> ```bash
> [[ -z "${CFG_VERSAOCLASS:-}" ]] && {
>     echo "ERRO: CFG_VERSAOCLASS não definida após carregamento de .config" >&2
>     return 1
> }
> ```

---

**[INFO]** Linha ~83-86 — PAD
> `[[ -z "${CFG_DIR:-}" ]]` como guarda de carregamento — uso correto do `:-` para compatibilidade com `set -u`. A guarda previne o carregamento quando `principal.sh` não inicializou `CFG_DIR`. Padrão correto; registrado como confirmação positiva.

---

**[INFO]** Linha ~28 — PAD
> `SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"` — resolve o diretório dois níveis acima de `BASH_SOURCE[0]` (ou seja, o diretório pai do diretório `binarios/`). A lógica é `dirname` do `pwd` do `dirname` do arquivo fonte. Correto para a estrutura do projeto (`binarios/constantes.sh` → `Atualiza/`). O `cd` intermediário garante resolução de symlinks. Funciona em Bash 3.0+.

---

### Resumo 3.4

| Severidade | Qtd |
|---|---|
| BLOQUEANTE | 1 |
| AVISO | 5 |
| INFO | 4 |

---

## Sumário das Seções 3.3 + 3.4

| Arquivo | BLOQUEANTE | AVISO | INFO | Total |
|---|---|---|---|---|
| `config.sh` | 2 | 5 | 3 | 10 |
| `constantes.sh` | 1 | 5 | 4 | 10 |
| **Total** | **3** | **10** | **7** | **20** |

### Principais riscos identificados

1. **`config.sh` L~125** `BRANCO` indefinida no fallback — `unbound variable` fatal com `set -u`.
2. **`config.sh` L~400** `_ssh_aceitar_novo` vs `_ssh_aceitar_novo` — chamada de função inexistente em `_validar_ssh`.
3. **`constantes.sh` L~61** `declare -g` requer Bash 4.2+ — falha silenciosa e completa do carregamento de `.config` em Bash 4.0/4.1.
4. **`config.sh` linhas finais** traps globais sobrescrevem traps de `principal.sh` — comportamento de cleanup imprevisível.
