# Bugfix Design: backup.sh (8 defeitos)

## Overview

Este documento detalha como corrigir os oito defeitos identificados em `binarios/backup.sh`.
As correções são minimais e cirúrgicas: cada uma altera apenas o trecho problemático, sem
refatorar lógica adjacente, e preserva 100% do comportamento nos caminhos não-afetados pelo bug.

Restrições do projeto aplicadas a todas as correções:
- Bash 4.0+ puro; sem `declare -g`, sem `wait -n`
- Módulo carregado via `source` em escopo global
- `shellcheck -S warning` limpo após cada mudança
- `bash -n` passa; suite `testes/test_backup.sh` (35 checks) passa

---

## Glossary

- **Bug_Condition (C)**: Condição que torna a entrada inválida ou o comportamento incorreto
- **Property (P)**: Comportamento correto esperado quando C(X) é satisfeita
- **Preservation**: Comportamento atual nos caminhos em que C(X) é falsa — deve permanecer idêntico
- **`_validar_pre_backup`**: função em `backup.sh` que valida pré-requisitos e escreve o caminho da base via `printf -v`
- **`_enviar_backup_avulso`**: função de envio avulso de backup selecionado
- **`_selecionar_backup`**: função que sempre define `backup_selecionado` **e** `nome_backup` quando retorna 0
- **`_offline_valido`**: helper em `utils.sh` (carrega antes de `backup.sh`) que testa `[[ "${CFG_OFFLINE:-}" =~ ^[sn]$ ]]`
- **`_coletar_arquivos_backup`**: função que popula `_BACKUP_LISTA` e `_BACKUP_BYTES` via `find`
- **`_compactar_backup`**: função que cria o zip atômico via `xargs` + `zip`
- **`_executar_backup_arquivo`**: função que chama `_coletar_arquivos_backup` + `_compactar_backup` após `cd`
- **`_restaurar_backup_completo`**: função que extrai o zip via `unzip -o`
- **`_verificar_backups_recentes`**: função que lista backups dos últimos 2 dias
- **`rc_find`**: código de saída do primeiro `find` (com `-printf`)
- **`rc_zip`**: código de saída do `xargs … zip`

---

## Bug Details

### Bug 1 — `_validar_pre_backup`: `printf -v` antes de `[[ -d ]]`

**Localização**: `backup.sh:_validar_pre_backup`, bloco que começa após a validação de caminho
seguro (antes do comentário `# Validar se o diretorio base existe`).

**Bug Condition**:
```
FUNCTION isBugCondition_1(X)
  INPUT: X = estado do filesystem durante _validar_pre_backup
  RETURN X.printf_v_ja_escreveu = true
         AND X.validacao_d_base_ref_ainda_nao_ocorreu = true
END FUNCTION
```

**Exemplo concreto**: `_validar_pre_backup base_trabalho` é chamada quando o diretório base
existe no momento do `printf -v`, mas é removido por outro processo antes do `[[ ! -d "$_base_ref" ]]`.
O chamador recebe um caminho inválido em `base_trabalho`, mesmo que `_validar_pre_backup` retorne 1
logo em seguida, porque a escrita já ocorreu antes do `return 1`.

---

### Bug 2 — `_enviar_backup_avulso`: verifica `nome_backup` em vez de `backup_selecionado`

**Localização**: `backup.sh:_enviar_backup_avulso`, linhas após `_selecionar_backup` retornar 0.

**Bug Condition**:
```
FUNCTION isBugCondition_2(X)
  INPUT: X = chamada a _enviar_backup_avulso
  RETURN X.nome_backup_contem_valor_de_execucao_anterior = true
         AND X.backup_selecionado_definido_por_selecionar_backup = true
END FUNCTION
```

**Exemplo concreto**: se uma chamada anterior a qualquer função que popule `nome_backup` deixou
um valor residual, a checagem `[[ -z "${nome_backup:-}" ]]` retorna falso mesmo que
`_selecionar_backup` tenha falhado silenciosamente, porque `nome_backup` já tinha valor.

---

### Bug 3 — `_enviar_backup_avulso`: usa `=~ ^[sn]$` em vez de `_offline_valido`

**Localização**: `backup.sh:_enviar_backup_avulso`, bloco `if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]`.

**Bug Condition**:
```
FUNCTION isBugCondition_3(X)
  INPUT: X.CFG_OFFLINE
  RETURN X.CFG_OFFLINE NOT IN {"s", "n"}
END FUNCTION
```

**Exemplo concreto**: `CFG_OFFLINE="S"` (maiúsculo, digitado no `.config`). Os quatro outros
call sites (`baixar.sh:_executar_update`, `biblioteca.sh:_atualizar_transpc`,
`biblioteca.sh:_atualizar_biblioteca_offline`, `programas.sh:_atualizar_programa_pacote`)
chamariam `_offline_erro` e retornariam. `_enviar_backup_avulso` cai no `else` com mensagem
genérica que não menciona qual é o valor inválido e não chama `_offline_erro`.

---

### Bug 4 — `_coletar_arquivos_backup`: fallback não distingue falha de lista vazia

**Localização**: `backup.sh:_coletar_arquivos_backup`, bloco após o primeiro `find`.

**Bug Condition**:
```
FUNCTION isBugCondition_4(X)
  INPUT: X = resultado do find com -printf em _coletar_arquivos_backup
  RETURN X.find_retornou_0 = true AND X.arquivos_encontrados = 0
END FUNCTION
```

**Exemplo concreto**: diretório base com apenas arquivos `*.zip` e `*.log` (todos excluídos
pelos filtros). O `find` retorna 0 com saída vazia. `[[ ! -s "$_lista_tmp" ]]` é verdadeiro
e o fallback com `-print0` é executado desnecessariamente, zerando `_BACKUP_BYTES` para todos
os arquivos.

---

### Bug 5 — `_compactar_backup`: diagnóstico "corrompido" em vez de "sem espaço" em multi-lote

**Localização**: `backup.sh:_compactar_backup`, bloco após `rc_zip=$?` do `xargs … zip`.

**Bug Condition**:
```
FUNCTION isBugCondition_5(X)
  INPUT: X = estado em _compactar_backup após rc_zip != 0
  RETURN X.disco_ficou_cheio_durante_xargs_lote_posterior = true
END FUNCTION
```

**Exemplo concreto**: base com 50 000 arquivos, checagem de espaço inicial passa (havia 2 GB),
mas outro processo consome o disco durante os lotes 2 e 3 do `xargs`. O zip falha com código
não-zero; o código atual loga apenas `"zip: codigo N, M aviso(s)"` ou reporta "corrompido",
sem diagnóstico de disco cheio.

---

### Bug 6 — `_executar_backup_arquivo`: CWD não restaurado no caminho de erro

**Localização**: `backup.sh:_executar_backup_arquivo`.

**Bug Condition**:
```
FUNCTION isBugCondition_6(X)
  INPUT: X = retorno de _compactar_backup dentro de _executar_backup_arquivo
  RETURN X.compactar_retornou_erro = true
         AND X.cwd_foi_modificado_por_diretorio_trabalho = true
END FUNCTION
```

**Exemplo concreto**: `_diretorio_trabalho` faz `cd "$base_trabalho"`. Se `_compactar_backup`
retorna 1, `_executar_backup_arquivo` retorna 1 sem restaurar o CWD. `_main` e
`_limpeza_emergencia` rodam depois com CWD errado.

---

### Bug 7 — `_restaurar_backup_completo`: retorno implícito no caminho feliz

**Localização**: `backup.sh:_restaurar_backup_completo`, fim da função após `_aguardar_tecla`.

**Bug Condition**:
```
FUNCTION isBugCondition_7(X)
  INPUT: X = resultado do unzip em _restaurar_backup_completo
  RETURN X.unzip_retornou_0 = true
         AND X.aguardar_tecla_retornou_nao_zero = true
END FUNCTION
```

**Exemplo concreto**: `_aguardar_tecla` chama `read`. Se o usuário pressiona Ctrl+C ou o
terminal fecha, `read` retorna 1 (ou 130). A função termina com esse código. `_restaurar_backup`
em `_restaurar_backup` captura o valor com `|| _resultado=$?` e propaga o falso erro.

---

### Bug 8 — `_verificar_backups_recentes`: `ls` com glob não escapado para espaços

**Localização**: `backup.sh:_verificar_backups_recentes`, linha com `ls -ltrh`.

**Bug Condition**:
```
FUNCTION isBugCondition_8(X)
  INPUT: X.CFG_EMPRESA
  RETURN X.CFG_EMPRESA contém espaço ou caractere especial de shell
END FUNCTION
```

**Exemplo concreto**: `CFG_EMPRESA="Empresa SAV"`. O comando
`ls -ltrh "${DEFAULT_BASEBACKUP_DIR}"/"${padrao_empresa}"_*.zip` recebe o glob
`Empresa\ SAV_*.zip` como dois tokens pelo word-splitting, fazendo `ls` falhar ou
listar incorretamente.

---

## Expected Behavior

### Preservation Requirements

**Comportamentos que NÃO devem mudar:**

- `_validar_pre_backup` com base válida continua retornando 0 e escrevendo o caminho correto
- `_enviar_backup_avulso` com `CFG_OFFLINE="s"` continua chamando `_mover_backup_offline`
- `_enviar_backup_avulso` com `CFG_OFFLINE="n"` continua perguntando confirmação e chamando `_enviar_backup_rede`
- `_coletar_arquivos_backup` com arquivos presentes e `find` com `-printf` funcional continua populando `_BACKUP_LISTA` e `_BACKUP_BYTES`
- `_coletar_arquivos_backup` em ambiente sem `-printf` continua acionando o fallback com `-print0`
- `_compactar_backup` com lista em único lote continua criando zip atômico, validando integridade e renomeando
- `_executar_backup_arquivo` com sucesso continua retornando 0 com o zip no caminho informado
- `_restaurar_backup_completo` com falha antes do `unzip` continua retornando 1
- `_verificar_backups_recentes` sem backups recentes continua retornando 1 sem exibir listagem

**Escopo de não-impacto**: toda execução em que C(X) = false para todos os oito bugs deve
produzir saída idêntica à versão atual.

---

## Hypothesized Root Cause

1. **Bug 1 (ordem printf-v / -d)**: A validação de existência do diretório foi adicionada depois
   do `printf -v` em alguma revisão. A intenção correta era validar antes de expor o valor.

2. **Bug 2 (variável canônica)**: `_selecionar_backup` foi criada como rotina unificada depois
   que `_enviar_backup_avulso` já existia com a checagem em `nome_backup`. O chamador não foi
   atualizado para usar `backup_selecionado`, a saída canônica da rotina unificada.

3. **Bug 3 (`_offline_valido`)**: `_enviar_backup_avulso` foi escrita antes do helper
   `_offline_valido` ser padronizado nos outros módulos, ou a padronização não alcançou este
   call site.

4. **Bug 4 (fallback find)**: O fallback foi escrito para detectar "find não suporta -printf"
   via arquivo vazio, mas não capturou o código de saída do `find` para distinguir o caso "sem
   resultados" de "falha".

5. **Bug 5 (diagnóstico xargs)**: O diagnóstico foi pensado para um único `zip` direto, não para
   o padrão de múltiplos lotes do `xargs`; a checagem de espaço antes da operação não cobre
   o consumo durante lotes subsequentes.

6. **Bug 6 (CWD)**: `_executar_backup_arquivo` foi escrita sem salvar/restaurar CWD porque
   originalmente não fazia `cd` diretamente. Com a adição de `_diretorio_trabalho`, o contrato
   de restauração não foi aplicado.

7. **Bug 7 (return implícito)**: Padrão clássico de omitir `return 0` em funções que terminam
   com uma chamada de UI (`_aguardar_tecla`), assumindo que o último comando sempre retorna 0.

8. **Bug 8 (ls + glob + espaço)**: O `padrao_empresa` já é escapado por `_escapar_glob` para
   glob, mas `_escapar_glob` escapa apenas `* ? [ ]`, não espaços. O `ls` com glob expansível
   é passado como argumento único com aspas, mas word-splitting pode ocorrer dependendo de como
   o shell interpreta o padrão com espaços.

---

## Correctness Properties

Property 1: Bug Condition 1 — Escrita canônica após validação de existência

_For any_ chamada a `_validar_pre_backup` onde `_base_ref` não corresponde a um diretório
existente no momento da validação, a função corrigida SHALL retornar 1 **sem** ter escrito
nenhum valor na variável do chamador (`printf -v` não deve ocorrer antes de `[[ -d "$_base_ref" ]]`
retornar 0).

**Validates: Requirements 2.1, 3.1**

Property 2: Bug Condition 2 — Checagem da variável canônica de saída

_For any_ chamada a `_enviar_backup_avulso` após `_selecionar_backup` retornar 0, a função
corrigida SHALL verificar `backup_selecionado` (não `nome_backup`) para detectar falha silenciosa,
e prosseguir apenas se `backup_selecionado` não estiver vazio.

**Validates: Requirements 2.2, 3.2, 3.3, 3.10**

Property 3: Bug Condition 3 — Delegação a `_offline_valido`

_For any_ chamada a `_enviar_backup_avulso` onde `CFG_OFFLINE NOT IN {"s", "n"}`, a função
corrigida SHALL chamar `_offline_erro` e retornar 1, seguindo o mesmo comportamento dos outros
quatro call sites. Para `CFG_OFFLINE == "s"` ou `"n"`, o comportamento deve ser idêntico ao
atual.

**Validates: Requirements 2.3, 3.2, 3.3**

Property 4: Bug Condition 4 — Fallback ativado apenas por falha do `find`

_For any_ execução de `_coletar_arquivos_backup` em diretório que não contém arquivos
correspondentes aos filtros (find retorna 0, saída vazia), a função corrigida SHALL **não**
acionar o fallback com `-print0`; `_BACKUP_LISTA` ficará vazia e `_BACKUP_BYTES` em 0.

**Validates: Requirements 2.4, 3.4, 3.5**

Property 5: Bug Condition 5 — Diagnóstico de disco cheio em falha de `xargs`/`zip`

_For any_ execução de `_compactar_backup` onde `rc_zip != 0` após o `xargs`, a função
corrigida SHALL verificar o espaço disponível naquele momento e incluir o diagnóstico
"possivelmente sem espaco em disco" na mensagem de log quando o espaço estiver abaixo do
mínimo, em vez de registrar apenas o código de erro.

**Validates: Requirements 2.5, 3.6**

Property 6: Bug Condition 6 — CWD restaurado em todos os retornos de `_executar_backup_arquivo`

_For any_ execução de `_executar_backup_arquivo`, seja qual for o código de retorno de
`_compactar_backup`, a função corrigida SHALL restaurar o CWD para o valor salvo antes de
`_diretorio_trabalho`, garantindo `pwd == _cwd` em todos os caminhos de saída.

**Validates: Requirements 2.6, 3.7**

Property 7: Bug Condition 7 — Retorno 0 explícito no caminho feliz de `_restaurar_backup_completo`

_For any_ execução de `_restaurar_backup_completo` em que o `unzip` retorna 0, a função
corrigida SHALL retornar 0, independentemente do código de saída de `_aguardar_tecla`.

**Validates: Requirements 2.7, 3.8**

Property 8: Bug Condition 8 — Listagem de backups recentes independente de espaços em `CFG_EMPRESA`

_For any_ valor de `CFG_EMPRESA` (incluindo com espaços ou caracteres especiais de glob),
`_verificar_backups_recentes` corrigida SHALL exibir a listagem de backups recentes sem
erros de word-splitting ou glob expansion incorreto.

**Validates: Requirements 2.8, 3.9**

---

## Fix Implementation

### Bug 1 — Mover `printf -v` para depois de `[[ -d ]]`

**Arquivo**: `binarios/backup.sh`
**Função**: `_validar_pre_backup`

**Mudança específica**: Trocar a ordem entre o bloco `printf -v "$var_name" '%s' "${_base_ref}"`
e o bloco `[[ ! -d "${_base_ref}" ]]`. O `printf -v` deve ocorrer imediatamente **após** a
validação de existência passar, antes das validações de `DEFAULT_BASEBACKUP_DIR`.

**Antes (ordem atual):**
```bash
    # SEGURANÇA: Validar caminho da base contra traversal
    if ! _validar_caminho_seguro "$_base_ref"; then
        ...
        return 1
    fi

    # Devolver valor ao chamador (nameref manual, compativel com Bash 4.2+)
    printf -v "$var_name" '%s' "${_base_ref}"

    # Validar se o diretorio base existe
    if [[ ! -d "${_base_ref}" ]]; then
        ...
        return 1
    fi
```

**Depois (ordem correta):**
```bash
    # SEGURANÇA: Validar caminho da base contra traversal
    if ! _validar_caminho_seguro "$_base_ref"; then
        ...
        return 1
    fi

    # Validar se o diretorio base existe
    if [[ ! -d "${_base_ref}" ]]; then
        ...
        return 1
    fi

    # Devolver valor ao chamador (nameref manual, compativel com Bash 4.2+)
    # Movido para APOS a validacao de existencia: o chamador so recebe o
    # caminho depois que o diretorio foi confirmado como valido.
    printf -v "$var_name" '%s' "${_base_ref}"
```

**shellcheck**: sem impacto (nenhuma nova construção).

---

### Bug 2 — Verificar `backup_selecionado` em vez de `nome_backup`

**Arquivo**: `binarios/backup.sh`
**Função**: `_enviar_backup_avulso`

**Mudança específica**: Substituir a checagem de `nome_backup` pela checagem de
`backup_selecionado`. Como `_selecionar_backup` sempre define **ambas** quando retorna 0
(ver `backup.sh:_selecionar_backup`, linha `nome_backup="${backup_selecionado##*/}"`),
a lógica de downstream que usa `nome_backup` não muda.

**Antes:**
```bash
    # Validar que o nome do backup foi definido
    if [[ -z "${nome_backup:-}" ]]; then
        _erro "Nome do backup nao definido"
        _aguardar_tecla
        return 1
    fi
```

**Depois:**
```bash
    # Validar que backup_selecionado foi definido pela rotina unica
    # (nome_backup e sempre derivado de backup_selecionado; checar a variavel
    # canonica detecta qualquer falha silenciosa de _selecionar_backup)
    if [[ -z "${backup_selecionado:-}" ]]; then
        _erro "Erro interno: backup_selecionado nao definido apos _selecionar_backup"
        _aguardar_tecla
        return 1
    fi
```

**shellcheck**: sem impacto.

---

### Bug 3 — Substituir bloco `CFG_OFFLINE` por `_offline_valido`

**Arquivo**: `binarios/backup.sh`
**Função**: `_enviar_backup_avulso`

**Mudança específica**: Substituir o bloco `if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then ... fi`
pelo padrão já usado pelos outros quatro call sites. O padrão canônico, copiado de
`baixar.sh:_executar_update` e `biblioteca.sh:_atualizar_transpc`:

```bash
    if ! _offline_valido; then
        _offline_erro "envio avulso de backup"
        _aguardar_tecla
        return 1
    fi

    if [[ "${CFG_OFFLINE}" == "s" ]]; then
        _mover_backup_offline "$nome_backup"
        return
    fi

    if _confirmar "Enviar backup via rede?" "S"; then
        _enviar_backup_rede "$nome_backup"
    fi
```

**Notas**:
- `_offline_valido` fica em `utils.sh` (índice 2 em `MODULOS_CARREGAR`), que carrega antes de
  `backup.sh` (índice 10) — sem dependência para frente.
- O `else` com `_aviso` genérico é removido; `_offline_erro` é mais precisa.
- `return` sem argumento após `_mover_backup_offline` é mantido (retorna o código de saída
  de `_mover_backup_offline`, consistente com o comportamento atual).
- **shellcheck**: `SC2317` não se aplica; sem novas construções.

---

### Bug 4 — Capturar `rc_find` e condicionar fallback a falha real

**Arquivo**: `binarios/backup.sh`
**Função**: `_coletar_arquivos_backup`

**Mudança específica**: Capturar o código de saída do primeiro `find` em `rc_find` e adicionar
`[[ $rc_find -ne 0 ]]` à condição do fallback.

**Antes:**
```bash
    "$_find" . "${find_args[@]}" -printf '%s\t%p\0' > "$_lista_tmp" 2>/dev/null || true

    # find sem -printf (implementacao nao-GNU): refaz a listagem sem tamanhos
    if [[ ! -s "$_lista_tmp" ]]; then
        "$_find" . "${find_args[@]}" -print0 > "$_lista_tmp" 2>/dev/null || true
    fi
```

**Depois:**
```bash
    local rc_find=0
    "$_find" . "${find_args[@]}" -printf '%s\t%p\0' > "$_lista_tmp" 2>/dev/null || rc_find=$?

    # find sem -printf (implementacao nao-GNU): refaz a listagem sem tamanhos.
    # Fallback ativado APENAS quando o find retornou erro (nao suporta -printf),
    # nao quando simplesmente nao encontrou arquivos (lista vazia mas rc == 0).
    if [[ ! -s "$_lista_tmp" ]] && [[ $rc_find -ne 0 ]]; then
        "$_find" . "${find_args[@]}" -print0 > "$_lista_tmp" 2>/dev/null || true
    fi
```

**shellcheck**: `rc_find` declarado como `local` antes do uso — sem SC2154.

---

### Bug 5 — Adicionar diagnóstico de disco cheio na falha do `xargs`/`zip`

**Arquivo**: `binarios/backup.sh`
**Função**: `_compactar_backup`

**Mudança específica**: Após capturar `rc_zip`, se `rc_zip != 0` e o arquivo temporário não
passou na validação de integridade, verificar o espaço disponível naquele momento e incluir
diagnóstico no log. A arquitetura atual (xargs em lotes, zip atômico via `.tmp`) não permite
diagnóstico perfeito — a solução mínima documentada evita o falso "corrompido".

**Adição após `|| rc_zip=$?` do xargs:**
```bash
    # Diagnostico de espaco: se o zip falhou, verificar se o disco ficou cheio
    # durante os lotes subsequentes do xargs (a checagem pre-operacao nao cobre isso).
    # Sem mudar a arquitetura, o maximo possivel e logar "possivelmente sem espaco"
    # para distinguir do caso "zip corrompido por outro motivo".
    if [[ $rc_zip -ne 0 ]]; then
        local espaco_pos_falha
        espaco_pos_falha=$(df -kP "$_dir_destino" 2>/dev/null | awk 'NR==2 {print $4}') || espaco_pos_falha=""
        if [[ "$espaco_pos_falha" =~ ^[0-9]+$ ]] && (( espaco_pos_falha < 102400 )); then
            _log "ZIP: rc=${rc_zip} — possivelmente sem espaco em disco (disponivel: ${espaco_pos_falha}KB)" "$log_zip"
        fi
    fi
```

**Notas**:
- O limiar de 102 400 KB (100 MB) é conservador: disco com menos de 100 MB após a falha
  é forte indício de esgotamento durante a operação.
- O bloco não altera o fluxo nem os arquivos produzidos — só adiciona uma linha ao log.
- **shellcheck**: `espaco_pos_falha` declarado com `local` — sem SC2154.

---

### Bug 6 — Salvar e restaurar CWD em `_executar_backup_arquivo`

**Arquivo**: `binarios/backup.sh`
**Função**: `_executar_backup_arquivo`

**Mudança específica**: Adicionar `local _cwd; _cwd="$(pwd)"` no início da função e
`cd "$_cwd" || true` em todos os pontos de retorno.

**Antes:**
```bash
_executar_backup_arquivo() {
    local arquivo_destino="${1:-}"
    local modo="${2:-}"
    local data_referencia="${3:-}"

    # Validar diretorio de trabalho
    if ! _diretorio_trabalho; then
        _erro "Falha ao acessar diretorio de trabalho"
        return 1
    fi

    _coletar_arquivos_backup "$modo" "$data_referencia"
    _compactar_backup "$arquivo_destino" "$modo"
}
```

**Depois:**
```bash
_executar_backup_arquivo() {
    local arquivo_destino="${1:-}"
    local modo="${2:-}"
    local data_referencia="${3:-}"
    local _cwd
    _cwd="$(pwd)"

    # Validar diretorio de trabalho
    if ! _diretorio_trabalho; then
        _erro "Falha ao acessar diretorio de trabalho"
        cd "$_cwd" || true
        return 1
    fi

    _coletar_arquivos_backup "$modo" "$data_referencia"
    local _rc_compactar=0
    _compactar_backup "$arquivo_destino" "$modo" || _rc_compactar=$?
    cd "$_cwd" || true
    return $_rc_compactar
}
```

**Notas**:
- `_compactar_backup` pode retornar 0, 1, 2 ou 3 — todos os códigos devem ser preservados.
- `cd "$_cwd" || true` segue o padrão do repo (proteção contra `set -e`).
- **shellcheck**: sem novas construções problemáticas.

---

### Bug 7 — `return 0` explícito após `_aguardar_tecla` em `_restaurar_backup_completo`

**Arquivo**: `binarios/backup.sh`
**Função**: `_restaurar_backup_completo`

**Mudança específica**: Adicionar `return 0` imediatamente após `_aguardar_tecla` no bloco
de sucesso (caminho `else` do `if [[ "$arquivo_backup" == *.tar.gz ]]`).

**Antes (fim da função):**
```bash
    _ok "Restauracao completa concluida"
    _aguardar_tecla
}
```

**Depois:**
```bash
    _ok "Restauracao completa concluida"
    _aguardar_tecla
    return 0
}
```

**Notas**:
- Mudança de uma linha. O `return 0` garante que o código de saída de `_aguardar_tecla`
  (que pode ser 1 ou 130 em Ctrl+C) não vaze para o chamador.
- **shellcheck**: sem impacto.

---

### Bug 8 — Substituir `ls` por `printf`/loop em `_verificar_backups_recentes`

**Arquivo**: `binarios/backup.sh`
**Função**: `_verificar_backups_recentes`

**Mudança específica**: Substituir `ls -ltrh ... *.zip` por uma listagem com `find` (já
presente na função para a checagem de `mtime`) seguida de exibição com `printf`. Usar
`find` com `-printf` para listar os arquivos encontrados nos últimos 2 dias e exibi-los
linha a linha, evitando glob com word-splitting.

**Antes:**
```bash
    if find "${DEFAULT_BASEBACKUP_DIR}" -maxdepth 1 -mtime -2 -name "${padrao_empresa}_*.zip" -print -quit | grep -q .; then
        _linha
        _exibir_mensagem_centralizada "${CIANO}" "Ja existe backup recente em $DEFAULT_BASEBACKUP_DIR:"
        _linha
        ls -ltrh "${DEFAULT_BASEBACKUP_DIR}"/"${padrao_empresa}"_*.zip 2>/dev/null
        _linha
        return 0
    fi
    return 1
```

**Depois:**
```bash
    local -a _backups_recentes=()
    mapfile -t _backups_recentes < <(
        find "${DEFAULT_BASEBACKUP_DIR}" -maxdepth 1 -mtime -2 \
            -name "${padrao_empresa}_*.zip" -print 2>/dev/null \
        | sort -r
    ) || true

    if (( ${#_backups_recentes[@]} > 0 )); then
        _linha
        _exibir_mensagem_centralizada "${CIANO}" "Ja existe backup recente em $DEFAULT_BASEBACKUP_DIR:"
        _linha
        local _arq
        for _arq in "${_backups_recentes[@]}"; do
            printf '%s\n' "$_arq"
        done
        _linha
        return 0
    fi
    return 1
```

**Notas**:
- `mapfile` requer Bash 4.0+ (target do projeto — ok).
- `find` com `-name "${padrao_empresa}_*.zip"` já usa o valor escapado por `_escapar_glob`
  (que escapa `* ? [ ]`). Para espaços no nome, `find -name` recebe o padrão como argumento
  único entre aspas duplas — sem word-splitting.
- A saída de `ls -ltrh` era usada apenas para exibir; `printf '%s\n'` preserva a legibilidade
  sem depender do formato de `ls`.
- **shellcheck**: `mapfile` aceita `|| true` para compatibilidade com `set -e`.

---

## Testing Strategy

### Validation Approach

Cada bug segue o ciclo: (a) **exploratório** — rodar o teste **antes** da correção para
confirmar que o bug é reproduzível; (b) **fix checking** — verificar que o comportamento
correto ocorre após a correção; (c) **preservation checking** — verificar que os caminhos
não-afetados pelo bug continuam idênticos.

A suite existente `testes/test_backup.sh` (35 checks) é o ponto de ancoragem: deve passar
100% antes **e** depois de cada correção.

---

### Exploratory Bug Condition Checking

**Objetivo**: confirmar (ou refutar) cada hipótese de root cause com código real antes de
implementar a correção.

**Plano por bug**:

1. **Bug 1**: `source` de `backup.sh` com stub de `_validar_caminho_seguro` retornando 0;
   passar um `_base_ref` que aponta para diretório existente, remover o diretório entre
   o `printf -v` e o `[[ -d ]]` via `rmdir` em subshell não é reproduzível de forma
   determinística em teste isolado — testar estaticamente: grep na função para confirmar
   que `printf -v` aparece antes de `[[ ! -d`.

2. **Bug 2**: chamar `_enviar_backup_avulso` com `nome_backup` pré-populado e
   `_selecionar_backup` stubada para retornar 0 sem definir `backup_selecionado`; verificar
   que a checagem atual **não** detecta o problema (retorna 0 erroneamente).

3. **Bug 3**: chamar `_enviar_backup_avulso` com `CFG_OFFLINE="S"` e stub de
   `_selecionar_backup`; verificar que cai no `else` em vez de chamar `_offline_erro`.

4. **Bug 4**: chamar `_coletar_arquivos_backup` em diretório temporário com apenas um
   arquivo `.zip` (excluído pelos filtros); verificar que `_BACKUP_LISTA` fica vazia mas o
   fallback é acionado (segunda chamada ao `find`).

5. **Bug 5**: verificar estaticamente que não há checagem de espaço no bloco pós-`rc_zip`.
   Teste em runtime seria acionar falta de espaço controlada — fora do escopo de CI.

6. **Bug 6**: chamar `_executar_backup_arquivo` com stub de `_compactar_backup` retornando 1;
   verificar que `pwd` após a chamada difere de `SCRIPT_DIR` (antes da correção).

7. **Bug 7**: chamar `_restaurar_backup_completo` com stub de `_aguardar_tecla` retornando 1;
   verificar que a função retorna 1 (antes da correção).

8. **Bug 8**: chamar `_verificar_backups_recentes` com `CFG_EMPRESA="Empresa SAV"` e
   `DEFAULT_BASEBACKUP_DIR` apontando para diretório temporário com um `.zip` recente;
   verificar que `ls` falha ou lista incorretamente (antes da correção).

---

### Fix Checking

```
FOR ALL bug IN {1..8}:
  FOR ALL input WHERE isBugCondition_N(input) DO
    result := fixed_function(input)
    ASSERT expectedBehavior_N(result)
  END FOR
END FOR
```

Casos concretos:

| Bug | Entrada (C(X)) | Comportamento esperado (P) |
|-----|----------------|---------------------------|
| 1 | `_base_ref` aponta para diretório removido | `printf -v` não ocorre; retorna 1 |
| 2 | `backup_selecionado` vazio, `nome_backup` populado | erro "Erro interno" + return 1 |
| 3 | `CFG_OFFLINE="S"` | `_offline_erro` chamada + return 1 |
| 4 | Diretório vazio (find rc=0, lista vazia) | fallback não executado; `_BACKUP_LISTA` vazia |
| 5 | `rc_zip != 0`, disco com < 100 MB | log inclui "possivelmente sem espaco" |
| 6 | `_compactar_backup` retorna 1 | CWD == `_cwd` após retorno |
| 7 | `unzip` retorna 0, `_aguardar_tecla` retorna 1 | função retorna 0 |
| 8 | `CFG_EMPRESA="Empresa SAV"` | listagem exibida sem erro de word-splitting |

---

### Preservation Checking

```
FOR ALL bug IN {1..8}:
  FOR ALL input WHERE NOT isBugCondition_N(input) DO
    ASSERT original_function(input) == fixed_function(input)
  END FOR
END FOR
```

A suite `testes/test_backup.sh` cobre os caminhos felizes existentes. Após cada correção:

1. `bash -n binarios/backup.sh` deve passar
2. `shellcheck -S warning binarios/backup.sh` deve passar (100% limpo)
3. `bash testes/run_all.sh` deve reportar 0 falhas

---

### Unit Tests

- Bug 1: verificar estaticamente (grep) que `printf -v` ocorre após `[[ ! -d`
- Bug 2: stub `_selecionar_backup` retornando 0 sem definir `backup_selecionado`; assert erro interno
- Bug 3: `CFG_OFFLINE="S"` → assert `_offline_erro` foi chamada (via spy/stub)
- Bug 4: `find` stubado para retornar 0 com saída vazia; assert fallback não executado
- Bug 6: `_compactar_backup` stubado retornando 1; assert `pwd` restaurado
- Bug 7: `_aguardar_tecla` stubada retornando 1; assert função retorna 0
- Bug 8: `CFG_EMPRESA` com espaço; assert listagem não falha com `set -e`

### Property-Based Tests

- Bug 3: `CFG_OFFLINE` gerado aleatoriamente fora de `{"s","n"}` → sempre chama `_offline_erro`
- Bug 4: diretório gerado com N arquivos todos excluídos pelos filtros (N ∈ {0..50}) → `_BACKUP_LISTA` sempre vazia, fallback nunca acionado quando rc=0
- Bug 6: código de retorno de `_compactar_backup` ∈ {0,1,2,3} → CWD sempre restaurado

### Integration Tests

- Fluxo completo de backup completo (suite existente `test_backup.sh`) deve passar após todos os 8 fixes
- `bash testes/run_all.sh` sem flags deve reportar 517 checks (ou mais, se novos testes forem adicionados), 0 falhas
