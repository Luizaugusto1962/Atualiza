# Relatório de Análise Estática — Task 6
## Seções 3.12 a 3.15: arquivos.sh · backup.sh · programas.sh · biblioteca.sh

---

## 3.12 — `arquivos.sh`

### Achados

---

**[INFO]** Linha ~97 — Requisito de versão Bash (`mapfile`)
> `mapfile -t arquivos_temp < "$arquivo_lista"` requer Bash 4.0+. O projeto já documenta Bash 4.0+ como requisito mínimo, portanto é compatível com todos os alvos declarados.
> **Sugestão:** nenhuma ação necessária; registrado apenas para rastreabilidade.

---

**[INFO]** Linha ~109 — `find … -iname … -mtime +0` (GNU find)
> `-iname` para busca case-insensitive e `-mtime +0` são suportados pelo GNU find presente em todas as distribuições Linux alvo. BSD find não seria afetado pois o projeto não alega suporte a macOS/BSD.
> **Sugestão:** nenhuma ação necessária.

---

**[INFO]** Linha ~117 — `printf '%s\0' "${arquivos_zip[@]}" | xargs -0 rm -f` (POSIX-safe)
> Uso correto de null-delimiters para lidar com nomes de arquivo contendo espaços. Compatível com GNU coreutils e BusyBox modernos.
> **Sugestão:** nenhuma ação necessária.

---

**[INFO]** Linha ~337 — `find … -mtime +30 -type f -print -delete` (GNU find)
> `-print -delete` combinados imprimem cada arquivo antes de apagá-lo. GNU find garante a ordem `-print` antes de `-delete`, mas `-delete` implica `-depth`, o que pode surpreender em árvores com subdiretórios. No contexto do script os diretórios alvo são rasos (arquivos de log/backup), de modo que não há impacto prático.
> **Sugestão:** nenhuma ação necessária para os diretórios atuais; documentar se os diretórios puderem vir a conter subdiretórios.

---

**[BAIXO]** Linhas ~219 e ~252 — `shopt -s nullglob` / `shopt -u nullglob` — restauração manual
> As funções `_recuperar_todos_arquivos` e `_recuperar_arquivo_individual` ativam `nullglob` e restauram com `shopt -u nullglob` ao final do bloco `for`. Se a função retornar antecipadamente por erro (ex: `_executar_jutil` falha e a lógica mudar), `nullglob` poderia permanecer ativo para o resto da sessão.
> **Sugestão:** adotar padrão de salvamento/restauração explícito:
> ```bash
> local nullglob_ativo
> shopt -q nullglob && nullglob_ativo=1 || nullglob_ativo=0
> shopt -s nullglob
> # ... uso ...
> (( nullglob_ativo )) || shopt -u nullglob
> ```
> Alternativamente, usar `( subshell )` para isolar o efeito.

---

**[BAIXO]** Linhas ~219 e ~252 — `for arquivo in ${base_trabalho}/${extensao}` e `for arquivo in ${base_trabalho}/${padrao_arquivo}` — word splitting intencional sem aspas
> A ausência de aspas é intencional para permitir a expansão glob. Com `nullglob` ativo, um glob sem correspondência produz zero iterações, o que é o comportamento desejado. No entanto, se `base_trabalho` contiver espaços, o caminho seria dividido em tokens erroneamente.
> **Sugestão:** garantir que `base_trabalho` nunca contenha espaços (validação na entrada), ou substituir pelo padrão com array:
> ```bash
> local -a arquivos=()
> mapfile -t arquivos < <(find "$base_trabalho" -maxdepth 1 -type f -name "$extensao")
> for arquivo in "${arquivos[@]}"; do
> ```

---

**[BAIXO]** Linha ~158 — `$DEFAULT_ZIP` executado sem aspas para suportar flags (`zip -j`)
> `$DEFAULT_ZIP` pode conter flags (ex: `"zip -j"`). Executar sem aspas depende de word splitting para funcionar, o que quebra se o caminho do binário contiver espaços e é sensível à ordem dos tokens. Padrão frágil.
> **Sugestão:** separar o binário das flags em duas variáveis (`DEFAULT_ZIP_BIN` e `DEFAULT_ZIP_FLAGS`) e invocá-las como array:
> ```bash
> "${DEFAULT_ZIP_BIN}" ${DEFAULT_ZIP_FLAGS} "$destino" "${arquivos[@]}"
> ```

---

## 3.13 — `backup.sh`

### Achados

---

**[MÉDIO]** Linha ~39 — `local -n _base_ref="$1"` — nameref (Bash 4.3+)
> `local -n` (nameref) foi introduzido no Bash 4.3. Distribuições com Bash 4.0–4.2 (ex: RHEL 6/7 com bash 4.1/4.2) falharão com `declare: -n: invalid option`. O projeto declara Bash 4.0+ como mínimo, criando uma lacuna real.
> **Sugestão:** verificar a versão mínima real do Bash nos clientes. Se clientes com Bash < 4.3 existirem, substituir o nameref por `eval`:
> ```bash
> # Bash 4.0-compatível
> eval "$1=\"\${base_local}\""
> ```
> Ou elevar o requisito documentado para Bash 4.3+ com verificação em `principal.sh`.

---

**[INFO]** Linha ~163 — `date -d "$data_referencia" +%Y%m%d` — GNU `date -d`
> `date -d` é extensão GNU. macOS/BSD usaria `date -j -f`. Para os alvos Linux declarados, sem impacto.
> **Sugestão:** nenhuma ação necessária nos alvos atuais; registrado para eventual porte.

---

**[INFO]** Linha ~259 — `find . -type f -newermt "$data_referencia"` — GNU find 4.5+
> `-newermt` (newer-modification-time com string de data) requer GNU find 4.5+, presente em distros Linux modernas (Ubuntu 12.04+, CentOS 7+). Sem impacto nos alvos atuais.
> **Sugestão:** nenhuma ação necessária; documentar como dependência implícita do GNU find 4.5+.

---

**[BAIXO]** Linha ~398 — `stat -c%s` — GNU stat sem fallback
> `stat -c%s` é formato GNU. BSD/macOS usa `stat -f%z`. Em servidores Linux alvos, OK. Porém, como outros módulos também usam `stat -c`, uma falha silenciosa ocorreria se o sistema usasse `busybox stat` sem suporte à flag `-c`.
> **Sugestão:** adicionar fallback mínimo:
> ```bash
> tamanho=$(stat -c%s "$arquivo" 2>/dev/null) || tamanho=$(wc -c < "$arquivo" 2>/dev/null || echo 0)
> ```

---

**[BAIXO]** Linhas ~435–448 — `for arquivo in $padrao` sem aspas com `nullglob`
> Na função `_executar_backup_multiplos_padroes`, o loop `for arquivo in $padrao` expande o padrão via word splitting intencional dentro de `shopt -s nullglob`. Comportamento idêntico ao descrito em 3.12: quebra se `padrao` contiver espaços no caminho base. Com `nullglob`, um glob sem resultado produz zero iterações — correto.
> **Sugestão:** igual à seção 3.12 — garantir que os caminhos base não contenham espaços, ou migrar para array com `find`/`mapfile`.

---

**[INFO]** Linha ~455 — `compgen -G "padrão"` — extensão Bash
> `compgen -G` testa se um glob tem correspondência sem expandir no shell atual, evitando side-effects. É extensão Bash (não POSIX), mas amplamente disponível em Bash 3.2+. Compatível com todos os alvos.
> **Sugestão:** nenhuma ação necessária.

---

**[BAIXO]** Linha ~84 — Trap `_limpar_backup` sobrescreve traps do escopo externo durante o backup
> `_executar_backup` registra `trap '_limpar_backup; trap - INT TERM' INT TERM` e restaura com `trap '_encerrar_programa 130' INT TERM` ao final. O padrão é seguro desde que `_encerrar_programa` seja sempre o handler correto no escopo externo. Se outro módulo registrar um trap diferente antes de chamar `_executar_backup`, ele será descartado silenciosamente.
> **Sugestão:** capturar o trap existente antes de sobrescrever e restaurá-lo ao final:
> ```bash
> local trap_anterior
> trap_anterior=$(trap -p INT)
> trap '_limpar_backup; eval "${trap_anterior:-}"' INT TERM
> # ...ao final:
> eval "${trap_anterior:-trap - INT}"
> ```

---

## 3.14 — `programas.sh`

### Achados

---

**[BAIXO]** Linha ~18 — `declare -g ARQUIVO_COMPILADO_ATUAL=""` — Bash 4.2+
> `declare -g` (global dentro de função) foi introduzido no Bash 4.2. Como o projeto usa `declare -g` extensivamente em outros módulos, isso implica Bash 4.2+ efetivo — mas o requisito documentado ainda diz 4.0+.
> **Sugestão:** elevar o requisito documentado para Bash 4.2+ (ou 4.3+ caso o nameref de `backup.sh` seja mantido) e adicionar verificação de versão em `principal.sh`:
> ```bash
> if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
>     echo "ERRO: Bash 4.2+ necessário" >&2; exit 1
> fi
> ```

---

**[BAIXO]** Linha ~113 — `local -A seen=()` — array associativo local (Bash 4.0+)
> Arrays associativos (`declare -A`) foram introduzidos no Bash 4.0. O uso de `local -A` (associativo local) também requer Bash 4.0+. Compatível com os alvos declarados (Bash 4.0+).
> **Sugestão:** nenhuma ação necessária além de manter o requisito Bash 4.0+ documentado.

---

**[BAIXO]** Linha ~467 — `stat -c%s "${arquivo_backup}"` e linha ~486 `stat -c %y` — GNU stat sem fallback
> Ambas as chamadas a `stat` usam formato GNU sem fallback. `stat -c%s` retorna o tamanho em bytes; `stat -c %y` retorna a data de modificação. Em sistemas com apenas BusyBox stat (embarcados/containers mínimos), estas flags podem não ser suportadas e retornar string vazia, fazendo a validação de tamanho aceitar arquivos inválidos silenciosamente (a variável `tamanho` fica vazia, e a comparação `-lt 22` com string vazia falha de forma não-intuitiva).
> **Sugestão:** adicionar fallback de `wc -c` para tamanho e verificação de retorno:
> ```bash
> tamanho=$(stat -c%s "$arquivo_backup" 2>/dev/null) \
>   || tamanho=$(wc -c < "$arquivo_backup" 2>/dev/null) \
>   || tamanho=0
> ```

---

**[BAIXO]** Linha ~490 — `date -d "$data_modificacao"` — GNU date sem fallback
> Mesma situação de `backup.sh`: `date -d` é extensão GNU. Em sistemas Linux alvo, OK. Falha silenciosa em ambientes com BusyBox date (ex: containers Alpine).
> **Sugestão:** envolver em verificação de retorno:
> ```bash
> data_formatada=$(date -d "$data_modificacao" +"%d/%m/%Y %H:%M:%S" 2>/dev/null) \
>   || data_formatada="$data_modificacao"
> ```

---

**[INFO]** Linha ~543 — `IFS= read -r -d '' classfile` — null delimiter
> Uso correto do delimitador nulo para processar saída do `find -print0`, evitando quebra em nomes de arquivo com espaços ou newlines. Compatível com Bash 3.2+.
> **Sugestão:** nenhuma ação necessária.

---

## 3.15 — `biblioteca.sh`

### Achados

---

**[BAIXO]** Linha ~8 — `declare -g pids=()` — Bash 4.2+
> `declare -g` em nível global de arquivo funciona em Bash 4.2+. Mesma situação do módulo `programas.sh` — implica requisito efetivo de Bash 4.2+.
> **Sugestão:** consolidar a verificação de versão conforme sugerido em 3.14.

---

**[INFO]** Linhas ~160 e ~169 — `tar -rf … {} +` — GNU tar append
> `tar -rf` (append) com `-exec … {} +` é suportado pelo GNU tar em todas as distros Linux alvo. BSD tar não suporta append em modo `-r`, mas os alvos são Linux.
> **Sugestão:** nenhuma ação necessária nos alvos atuais.

---

**[MÉDIO]** Linha ~183 — `gzip -f "${arquivo_backup_tar}"` sem verificar se `tar` criou o arquivo
> O bloco de compressão com `gzip` é executado somente se `[[ -f "${arquivo_backup_tar}" ]]`, o que é correto. Porém, o `tar -rf` nas etapas anteriores é executado em background com `&` e aguardado via `_mostrar_progresso_backup`. Se o processo tar falhar mas `_mostrar_progresso_backup` retornar 0 por engano (ex: race condition ou falha silenciosa do `wait`), `gzip` poderia operar em um `.tar` vazio ou parcial sem detecção de erro.
> **Sugestão:** validar explicitamente o tamanho mínimo do `.tar` antes de comprimir:
> ```bash
> if [[ -f "${arquivo_backup_tar}" ]] && (( $(wc -c < "${arquivo_backup_tar}") > 512 )); then
>     gzip -f "${arquivo_backup_tar}" ...
> else
>     _erro "Arquivo tar vazio ou ausente; compressão abortada"
>     return 1
> fi
> ```

---

**[CRÍTICO/SEG]** Linhas ~252 e ~289 — `tar -xzf … -C "/"` — extração na raiz do sistema
> As funções `_reverter_biblioteca_completa` e `_reverter_programa_especifico_biblioteca` definem `temp_restore="/"` e extraem o backup diretamente em `/`:
> ```bash
> tar -xzf "${arquivo_backup}" -C "/" ...
> ```
> O argumento nos comentários é que "o backup contém caminhos absolutos". Isso significa que um arquivo `.tar.gz` corrompido, adulterado ou produzido incorretamente pode sobrescrever **qualquer arquivo do sistema operacional**, incluindo binários em `/bin`, `/lib`, `/usr`, arquivos de configuração em `/etc`, ou o próprio `bash`. Não há validação de conteúdo do archive antes da extração, nem lista de caminhos permitidos.
> **Sugestão (curto prazo):** adicionar validação do conteúdo antes de extrair — listar entradas do archive e verificar que todos os caminhos estão dentro dos diretórios esperados (`E_EXEC` e `T_TELAS`):
> ```bash
> # Validar que nenhuma entrada aponta para fora dos diretórios permitidos
> while IFS= read -r entrada; do
>     if [[ "$entrada" != "${E_EXEC}/"* && "$entrada" != "${T_TELAS}/"* ]]; then
>         _erro "CRÍTICO: Archive contém caminho não permitido: $entrada"
>         return 1
>     fi
> done < <(tar -tzf "${arquivo_backup}" 2>/dev/null)
> tar -xzf "${arquivo_backup}" -C "/" ...
> ```
> **Sugestão (longo prazo):** redesenhar o backup para usar caminhos relativos dentro do `.tar.gz` e extrair em `E_EXEC`/`T_TELAS` diretamente, eliminando a necessidade de `C "/"`.

---

**[BAIXO]** Linha ~292 — `tar -xzf … --wildcards` — GNU tar apenas
> `--wildcards` é extensão GNU tar; BSD tar usa `-s` ou não suporta o equivalente. Para os alvos Linux declarados, sem impacto.
> **Sugestão:** nenhuma ação necessária nos alvos; registrado para eventual porte.

---

**[INFO]** Linha ~347 — `sed -i "s/…"` — GNU sed sem sufixo de backup
> GNU sed aceita `sed -i` sem sufixo (edição in-place sem backup). BSD sed exige `sed -i ''`. Para alvos Linux, sem impacto.
> **Sugestão:** nenhuma ação necessária nos alvos; registrado para eventual porte.

---

**[MÉDIO]** Linhas ~28–29 — `trap '_limpar_interrupcao' INT` / `trap '_limpar_interrupcao' TERM` no nível global do arquivo
> Os dois traps são registrados no escopo global do módulo (fora de qualquer função), executados no momento em que o arquivo é `source`-ado. Isso sobrescreve silenciosamente qualquer trap INT/TERM registrado anteriormente por `principal.sh` ou outros módulos. O handler `_limpar_interrupcao` recebe um argumento `$1` com o nome do sinal, porém a sintaxe usada não passa o sinal — a função recebe `$1` vazio, resultando em "sinal: " no log.
> Adicionalmente, ao final de `_executar_atualizacao_biblioteca`, os traps são restaurados para `_encerrar_programa 130`, o que é o comportamento esperado — mas somente se o fluxo atingir aquela linha. Um `return 1` antecipado deixa os traps do módulo ativos.
> **Sugestão:** mover o registro dos traps para dentro de `_processar_atualizacao_biblioteca` (onde o trabalho crítico ocorre), garantir restauração em todas as saídas via `trap … RETURN` ou estrutura `finally` com subshell, e corrigir a passagem do nome do sinal:
> ```bash
> trap '_limpar_interrupcao INT'  INT
> trap '_limpar_interrupcao TERM' TERM
> ```

---

## Resumo de Severidades

| Seção | Script | Severidade | Quantidade |
|---|---|---|---|
| 3.12 | `arquivos.sh` | CRÍTICO | 0 |
| 3.12 | `arquivos.sh` | MÉDIO | 0 |
| 3.12 | `arquivos.sh` | BAIXO | 3 |
| 3.12 | `arquivos.sh` | INFO | 3 |
| 3.13 | `backup.sh` | MÉDIO | 1 (`local -n` / nameref Bash 4.3+) |
| 3.13 | `backup.sh` | BAIXO | 3 |
| 3.13 | `backup.sh` | INFO | 3 |
| 3.14 | `programas.sh` | MÉDIO | 0 |
| 3.14 | `programas.sh` | BAIXO | 3 |
| 3.14 | `programas.sh` | INFO | 2 |
| 3.15 | `biblioteca.sh` | **CRÍTICO/SEG** | **1** (`tar -xzf -C "/"`) |
| 3.15 | `biblioteca.sh` | MÉDIO | 2 |
| 3.15 | `biblioteca.sh` | BAIXO | 2 |
| 3.15 | `biblioteca.sh` | INFO | 2 |

### Itens que exigem ação imediata

1. **[CRÍTICO/SEG] `biblioteca.sh` ~L252/L289** — extração `tar -C "/"` sem validação de caminhos. Risco de sobrescrita de arquivos de sistema.
2. **[MÉDIO] `backup.sh` ~L39** — `local -n` requer Bash 4.3+; o requisito documentado (4.0+) está desatualizado.
3. **[MÉDIO] `biblioteca.sh` ~L28–29** — traps globais sobrescrevem handlers de módulos anteriores; nome do sinal não é passado ao handler.
