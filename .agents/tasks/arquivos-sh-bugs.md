# Relatório de Bugs — `binarios/arquivos.sh`

**Data:** 2026-11  
**Ferramenta:** leitura completa do arquivo + grep focado + `bash -n` + `shellcheck -S warning`  
**Resultado das ferramentas:** ambos passam sem erros ou avisos.

---

## Tabela de resumo

| # | Função | Severidade | Descrição em 1 linha |
|---|--------|------------|----------------------|
| 1 | `_recuperar_arquivos_principais` | **Alta** | Glob `ATE${var_ano}*.dat` é relativo ao CWD (`CFG_DIR`), não à base de dados — não casa com nenhum arquivo quando `CFG_DIR ≠ base_trabalho` |
| 2 | `_executar_jutil_lote` | **Média** | `falhas--` no retry pode levar `falhas` a `-1`, fazendo `(( falhas > 0 ))` ser falso mesmo com falha real — retorno 0 errado |
| 3 | `_executar_expurgador` | **Média** | `E_EXEC` e `T_TELAS` usados sem `:-` default; se `config.sh` não foi carregado (e portanto não exportou essas vars), `set -u` aborta o expurgador inteiro |
| 4 | `_recuperar_arquivo_especifico` | **Baixa** | `clear` está fora do bloco `while … done` (linha deslocada), então a tela não é limpa no início de cada iteração do loop, só depois da última |
| 5 | `_limpar_base_especifica` | **Baixa** | Quando `backup_ok` é passado como `"0"` (backup inválido), a função retorna 1 imediatamente em modo automático, mas registra a mensagem de erro mesmo em modo interativo — bloqueia a limpeza toda em vez de só pular a compactação e remover os arquivos sem zip |

---

## Bug 1 — `_recuperar_arquivos_principais`: glob CWD-relativo em `CFG_DIR` em vez de `base_trabalho`

### Função
`_recuperar_arquivos_principais` (linha ~1158)

### Condição de disparo
Sempre que a função é chamada normalmente: ela faz `cd "${CFG_DIR}"` no início para escrever `indexar2`, e os globs `ATE"${var_ano}"*.dat` e `NFE?"${var_ano4}".*.dat` são avaliados **no contexto desse `cd`**, ou seja, dentro do diretório de configurações (`configuracoes/`), não dentro de `base_trabalho` (a base ISAM real, ex.: `/savisc/base`).

### Comportamento atual
O glob expande sobre `CFG_DIR` (onde vivem arquivos como `.config`, `.senhas`, `limpetmp`, `indexar`). Nunca haverá arquivos `ATE*.dat` ou `NFE*.dat` lá. Com `nullglob` ativo, os loops simplesmente não produzem nada, `indexar2` fica vazio e `_processar_lista_arquivos` é chamada sem entradas. Os arquivos principais da base **não são recuperados silenciosamente** — a função retorna 0 como se tivesse funcionado.

### Comportamento esperado
O glob deveria ser executado dentro de `base_trabalho` para listar os arquivos `ATE` e `NFE` da base de dados real.

### Correção sugerida

```bash
# Dentro do bloco de geração do indexar2, o glob precisa de prefixo absoluto:
{
    local arquivo_ate arquivo_nfe
    for arquivo_ate in "${base_trabalho}"/ATE"${var_ano}"*.dat; do
        printf '%s\n' "${arquivo_ate##*/}"
    done
    for arquivo_nfe in "${base_trabalho}"/NFE?"${var_ano4}".*.dat; do
        printf '%s\n' "${arquivo_nfe##*/}"
    done
} > "${CFG_DIR}/indexar2"
```

Alternativamente, eliminar o `cd "${CFG_DIR}"` do início da função e usar caminhos absolutos em todas as operações (o que seria mais limpo e consistente com as outras funções do módulo que não fazem `cd`).

---

## Bug 2 — `_executar_jutil_lote`: `falhas--` pode produzir contador negativo

### Função
`_executar_jutil_lote`, bloco de retry sequencial (linha ~1506)

### Condição de disparo
Arquivo recebe sinal 137 (SIGKILL) ou 143 (SIGTERM) durante a onda paralela:
1. `((falhas++))` é executado na coleta de resultados.
2. O arquivo vai para `retentar[]`.
3. O retry chama `_executar_jutil "$arq_retry"`. Se `_executar_jutil` retornar 0, `((falhas--))` é executado.
4. Se mais de um arquivo está em `retentar[]` **e todos têm sucesso no retry**, `falhas` decrementa para 0 — correto.
5. Porém, se `retentar[]` tiver 2 arquivos, ambos recuperados com sucesso, mas `falhas` só tinha 1 (p.ex., por haver exatamente 1 sinal + 0 falhas reais), `falhas` vai a `-1`.
6. `(( falhas > 0 ))` é falso para `-1` → a função retorna **0** (sucesso) mesmo tendo falhado registrar a contagem de forma consistente.

**Impacto concreto:** o chamador (`_recuperar_todos_arquivos`, `_processar_lista_arquivos`) não recebe erro. `_JUTIL_LOTE_FALHAS` fica em valor negativo, corrompendo o resumo exibido ao usuário ("−1 falha(s)").

**Nota:** o cenário exige que um arquivo morto por sinal esteja ausente do FS no momento do retry (branch `if [[ -e "$arquivo" ]]` na coleta não o adiciona a `retentar[]` nesse caso) — então na prática só entra em `retentar[]` se o arquivo existe. Ainda assim, a aritmética não tem proteção contra underflow.

### Correção sugerida

```bash
# Substituir:
((falhas--)) || true
# Por (protege contra underflow):
if (( falhas > 0 )); then ((falhas--)) || true; fi
```

---

## Bug 3 — `_executar_expurgador`: `E_EXEC` e `T_TELAS` sem valor padrão sob `set -u`

### Função
`_executar_expurgador` (linha ~1986)

### Condição de disparo
`E_EXEC` e `T_TELAS` são definidas e exportadas em `config.sh:_carregar_configuracoes` (linha ~292–294 de `config.sh`). Se por qualquer razão `_carregar_configuracoes` não for chamada antes (módulo carregado fora do fluxo normal, teste isolado, chamada direta de `_executar_expurgador` em harness), as variáveis não existem. Com `set -u` ativo (herdado do `source` do módulo), a expansão `"${E_EXEC}/"` aborta o shell com `unbound variable`.

```bash
local diretorios_zip=(
    "${E_EXEC}/"    # ← aborta se E_EXEC não estiver definida
    "${T_TELAS}/"
)
```

### Comportamento atual
O shell aborta na construção do array `diretorios_zip`, antes de qualquer `find`. O expurgador inteiro falha silenciosamente do ponto de vista do usuário (retorno não-zero não propagado ao menu).

### Comportamento esperado
Se `E_EXEC`/`T_TELAS` não estiverem definidas, o expurgador deve pular esses diretórios com log de aviso, como já faz para diretórios inexistentes.

### Correção sugerida

```bash
local diretorios_zip=(
    "${E_EXEC:-}/"
    "${T_TELAS:-}/"
)
# As verificações subsequentes -d já filtram strings vazias/inválidas,
# mas adicionar guard explícito para vazio é mais claro:
for diretorio in "${diretorios_zip[@]}"; do
    if [[ -z "${diretorio%/}" ]]; then
        continue   # E_EXEC/T_TELAS não configurados
    fi
    ...
done
```

---

## Bug 4 — `_recuperar_arquivo_especifico`: `clear` fora do loop

### Função
`_recuperar_arquivo_especifico` (linha ~715–718)

### Condição de disparo
Sempre que o usuário confirma "S" para recuperar mais arquivos — ou seja, em qualquer segunda iteração do loop.

### Comportamento atual
O `clear` está **depois** do `done` mas **antes** de fechar o bloco — na verdade está deslocado para fora do `while`: aparece entre o `[[ -z "$continuar" ]] && continuar="N"` e o `done`, mas com indentação errada que torna isso ambíguo visualmente. A leitura do fonte confirma que o `clear` está **dentro** do loop, mas **depois** de todo o processamento da iteração e da pergunta "continuar?". Isso faz a tela ser limpa ao *final* da iteração (após o `read`), não no *início*, de modo que o cabeçalho da próxima pergunta surge sobre a tela vazia já sem o contexto anterior — comportamento não crítico, mas inconsistente com o `clear` no início do loop que a função pretendia ter (há um `clear` antes do `while` para a primeira iteração, mas não para as subsequentes via esse código).

**Impacto:** cosmético; não há perda de dados nem falha funcional.

### Correção sugerida

Mover o `clear` para o início do corpo do `while`, imediatamente após a linha `while [[ "${continuar}" =~ ^[Ss]$ ]]; do`:

```bash
while [[ "${continuar}" =~ ^[Ss]$ ]]; do
    clear          # ← aqui, não antes do done
    _meio_da_tela
    ...
done
```

---

## Bug 5 — `_limpar_base_especifica`: compactação bloqueante quando backup inválido

### Função
`_limpar_base_especifica` (linha ~386)

### Condição de disparo
`backup_ok="0"` (passado explicitamente pelo chamador quando o diretório de backup não passou na validação). Isso acontece quando `DEFAULT_BACKUP_DIR` não existe ou falha em `_garantir_diretorio`.

### Comportamento atual
Quando `backup_ok == "0"`, a função **retorna 1 imediatamente** (modo automático) ou exibe erro e retorna 1 (modo interativo) — antes mesmo de tentar limpar qualquer arquivo. Isso significa que a limpeza dos arquivos temporários **não ocorre** só porque o backup está indisponível.

### Comportamento esperado
A indisponibilidade do backup deveria impedir apenas a **compactação** (o zip de resgate), mas os arquivos temporários ainda deveriam ser removidos (ou pelo menos a ausência de backup comunicada como aviso, não erro fatal). O próprio comentário do parâmetro diz "backup_ok: backup inválido → compactação será pulada", mas o código retorna antes de qualquer remoção.

**Impacto:** em modo automático (pré-backup), quando o diretório de backup está ausente ou com problema, a limpeza de temporários nunca roda — potencialmente deixando disco cheio, o que pode impedir o próprio backup que se seguiria.

### Correção sugerida

```bash
# Em vez de retornar 1 quando backup_ok=0, prosseguir sem zip:
if (( ! backup_valido )); then
    _log "AVISO: backup indisponivel, temporarios serao removidos SEM compactacao" "${LOG_LIMPA}"
    # (manter o fluxo; pular só o zip mais abaixo)
fi
# ... ao chegar no ponto de zip:
if (( backup_valido )); then
    if $DEFAULT_ZIP "${DEFAULT_BACKUP_DIR}/${zip_temporarios}" "${arquivos_zip_total[@]}" >>"${LOG_LIMPA}" 2>&1; then
        ...
    else
        return 1
    fi
fi
# Em qualquer caso, remover os arquivos:
rm -f -- "${arquivos_zip_total[@]}"
```

---

## Verificação de ferramentas

```
bash -n binarios/arquivos.sh      → sem erros
shellcheck -S warning binarios/arquivos.sh → sem avisos (exit 0)
```

Nenhum dos bugs acima é detectável por análise estática: todos envolvem semântica de runtime (glob CWD-relativo, aritmética de contador, variável indefinida sob condição de ambiente, posicionamento de statement).

---

## O que foi inspecionado mas está correto

- Todas as funções que fazem `cd` restauram CWD em todos os retornos (incluindo erros): `_recuperar_arquivos_principais` e `_recuperar_arquivo_especifico` têm os `cd "${SCRIPT_DIR}"` corretos nos paths de saída conhecidos.
- `shopt -p` capturado com `|| true` em todos os pontos.
- `(( expr ))` como statement protegidos com `|| true`.
- Guards `${array[@]+"${array[@]}"}` para arrays potencialmente vazios sob `set -u`.
- `_validar_padrao_limpeza` antes de qualquer `find`/`rm` sobre a base.
- `_validar_caminho_seguro` sobre entradas do usuário.
- `_garantir_diretorio` substituindo todos os `mkdir -p` soltos.
- `_carregar_links_duros` + `_eh_link` cobrindo tanto links simbólicos quanto duros.
- Paralelismo por ondas sem `wait -n` (compatível com Bash 4.0).
- `%s` em vez de `%b` ao exibir conteúdo de arquivo.
