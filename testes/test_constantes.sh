#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (CFG_VERSAOCLASS, CFG_ACESSO_SSH,
# DEFAULT_LOGS_DIR, ...) sao consumidas pelos modulos que este arquivo carrega
# com `source`, nao pelo proprio script.
set -euo pipefail
#
# testes/test_constantes.sh - verificacoes isoladas de binarios/constantes.sh
#
# constantes.sh e o PRIMEIRO modulo da MODULOS_CARREGAR e traz o unico parser
# do arquivo .config do sistema (_carregar_config_seguro). E ele que impede
# que uma linha "PATH=/tmp/evil" ou "BASH_ENV=/tmp/evil/init.sh" no .config
# sequestre o proprio interpretador.
#
# O source de constantes.sh tem efeitos colaterais (exige CFG_DIR, carrega o
# .config se existir e define dezenas de constantes), entao o teste define o
# ambiente ANTES do source e trabalha sobre arquivos .config sinteticos.
#
# Rodar direto, sem TTY:
#   bash testes/test_constantes.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

# Ambiente minimo antes do source: CFG_DIR e obrigatorio (constantes.sh aborta
# sem ele) e nao pode existir .config, senao o source ja carregaria um.
export CFG_DIR="${_TMP}/cfg"
export SCRIPT_DIR="${_TMP}/script"
export RAIZ="${_TMP}/raiz"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups_base"
export DEFAULT_BIBLIOTECA_DIR="${_TMP}/biblioteca"
export DEFAULT_BIBLIOTECA_ATUAL_DIR="${_TMP}/biblioteca_atual"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"
export DEFAULT_ENVIA_DIR="${_TMP}/envia"
export DEFAULT_ZIP=zip
export DEFAULT_UNZIP=unzip
export DEFAULT_TAR=tar
export DEFAULT_FIND=find
mkdir -p "$CFG_DIR" "$SCRIPT_DIR" "$RAIZ" "$DEFAULT_LOGS_DIR" "$DEFAULT_BACKUP_DIR" \
    "$DEFAULT_BASEBACKUP_DIR" "$DEFAULT_BIBLIOTECA_DIR" "$DEFAULT_BIBLIOTECA_ATUAL_DIR" \
    "$DEFAULT_PROGS_DIR" "$DEFAULT_PROGS_ATUAL_DIR" "$DEFAULT_ENVIA_DIR"
# .config vazio: evita o aviso do source de constantes.sh (que procuraria o
# arquivo em CFG_DIR) sem carregar valor nenhum.
: >"${CFG_DIR}/.config"

falhas=0
total=0
_checar() { # _checar <descricao> <esperado> <obtido>
    total=$((total + 1))
    if [[ "$2" == "$3" ]]; then
        printf 'ok    - %s\n' "$1"
    else
        printf 'FALHA - %s\n         esperado: [%s]\n         obtido:   [%s]\n' "$1" "$2" "$3"
        falhas=$((falhas + 1))
    fi
}

_rc() { # _rc <comando...> -> imprime o codigo de retorno
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    printf '%s' "$rc"
}

# Chama o parser real capturando o retorno em _RC_CFG. O parser emite avisos
# em stderr (chave bloqueada, valor suspeito) — sao esperada, entao vao para
# o /dev/null.
_criar_config_seguro() { # _criar_config_seguro <arquivo>
    _RC_CFG=0
    _carregar_config_seguro "$1" 2>/dev/null || _RC_CFG=$?
}

# O parser pode NAO existir em versoes antigas do modulo (a prova de
# discriminacao roda a suite contra o codigo antigo): sem este fallback, o
# "command not found" aborta a suite no meio (set -e) em vez de virar uma
# verificacao falhando.
if ! command -v _carregar_config_seguro >/dev/null 2>&1; then
    _carregar_config_seguro() { return 127; }
fi

# shellcheck source=../binarios/constantes.sh
. "${RAIZ_TESTE}/binarios/constantes.sh"

# ---------- _carregar_config_seguro: o unico parser do .config ----------#
# 1. atribuicao simples
printf 'CFG_EMPRESA=ACME\n' >"${_TMP}/c1.config"
CFG_EMPRESA=""
_criar_config_seguro "${_TMP}/c1.config"
_checar "config: valor simples carregado" "ACME" "${CFG_EMPRESA:-}"

# 2. aspas removidas
printf 'CFG_EMPRESA="ACME"\nCFG_BASE=/sav\n' >"${_TMP}/c2.config"
CFG_EMPRESA=""
CFG_BASE=""
_criar_config_seguro "${_TMP}/c2.config"
_checar "config: aspas duplas removidas" "ACME" "${CFG_EMPRESA:-}"
_checar "config: segunda variavel carregada" "/sav" "${CFG_BASE:-}"

# 3. comentario inline e linha vazia sao ignorados
printf '# comentario\n\nCFG_EMPRESA=ACME # comentario inline\n' >"${_TMP}/c3.config"
CFG_EMPRESA=""
_criar_config_seguro "${_TMP}/c3.config"
_checar "config: comentario inline ignorado" "ACME" "${CFG_EMPRESA:-}"

# 4. CR de arquivo CRLF nao contamin o valor
printf 'Offline=s\r\nCFG_EMPRESA=ACME\r\n' >"${_TMP}/c4.config"
CFG_EMPRESA=""
Offline=""
_criar_config_seguro "${_TMP}/c4.config"
_checar "config: CR de CRLF removido do valor" "ACME" "${CFG_EMPRESA:-}"
_checar "config: CR de CRLF removido da flag offline" "s" "${Offline:-}"

# 5. CHAVES BLOQUEADAS: sequestro do interpretador
#    Um .config com "PATH=/tmp/evil" faria todo comando externo do processo
#    resolver em /tmp/evil. A lista e por NOME, independentemente do valor.
#    A verificacao compara o valor ANTES e DEPOIS: o parser nao pode
#    sobrescrever a variavel (e a variavel do processo nao e unsetada).
#
#    O parser roda em SUB-SHELL de proposito: contra um parser antique (sem a
#    lista de bloqueio) a sobrescrita de BASHOPTS/SHELLOPTS derrubaria o shell
#    do teste no meio do relatorio. No subshell o dano morre com ele.
#
#    A assercao e "a chave NAO foi sobrescrita com o valor do ataque": e o que
#    importa para a seguranca. (Comparar o valor antes/depois nao serve para
#    IFS e SHELLOPTS: sao reconstruidos dentro do subshell.)
for chave in PATH IFS CDPATH GLOBIGNORE ENV TMPDIR TMP TEMP HOME SHELL \
             BASH_ENV BASHOPTS SHELLOPTS BASH_ARGV BASH_ARGC LD_PRELOAD \
             LD_LIBRARY_PATH LC_ALL LANG LANGUAGE PS1 PS4 HISTFILE TZ; do
    printf '%s=/tmp/evil\n' "$chave" >"${_TMP}/bloq.config"
    depois="$(_criar_config_seguro "${_TMP}/bloq.config"; printf '%s' "${!chave:-}")"
    _checar "config: chave bloqueada '${chave}' nao sobrescrita" "nao" \
        "$([[ "$depois" == "/tmp/evil" ]] && printf 'sim' || printf 'nao')"
done

# 6. Toda chave que comeca com "_" tambem e bloqueada
_privado=""
_criar_config_seguro "${_TMP}/bloq2.config"
_checar "config: chave iniciada por '_' ignorada" "" "${_privado:-}"

# 7. VALORES com metacaracteres sao descartados (silenciosamente, com aviso)
printf 'CFG_EMPRESA=ACME;rm -rf /\n' >"${_TMP}/v1.config"
CFG_EMPRESA=""
_criar_config_seguro "${_TMP}/v1.config" 2>/dev/null
_checar "config: valor com ';' descartado" "" "${CFG_EMPRESA:-}"

printf 'CFG_BASE=`id`\n' >"${_TMP}/v2.config"
CFG_BASE=""
_criar_config_seguro "${_TMP}/v2.config" 2>/dev/null
_checar "config: valor com backtick descartado" "" "${CFG_BASE:-}"

printf 'CFG_BASE=$(id)\n' >"${_TMP}/v3.config"
CFG_BASE=""
_criar_config_seguro "${_TMP}/v3.config" 2>/dev/null
_checar "config: valor com command substitution descartado" "" "${CFG_BASE:-}"

printf 'CFG_BASE=${HOME}\n' >"${_TMP}/v4.config"
CFG_BASE=""
_criar_config_seguro "${_TMP}/v4.config" 2>/dev/null
_checar "config: valor com expansao de parametro descartado" "" "${CFG_BASE:-}"

# 8. linha fora do formato de atribuicao e ignorada
printf 'isto nao e atribuicao\nCFG_EMPRESA=ACME\n' >"${_TMP}/v5.config"
CFG_EMPRESA=""
_criar_config_seguro "${_TMP}/v5.config" 2>/dev/null
_checar "config: linha sem '=' ignorada" "ACME" "${CFG_EMPRESA:-}"

# 9. arquivo inexistente nao define nada (e nao limpa o que ja existia)
CFG_EMPRESA="MANTIDO"
_RC_CFG=0
_criar_config_seguro "${_TMP}/nao_existe.config"
_checar "config: arquivo inexistente nao mexe nas variaveis" "MANTIDO" "${CFG_EMPRESA:-}"

# 10. o parser nao pode sequestrar o proprio PATH de quem o chama
#     (o parse roda em sub-shell: contra o parser antigo, que sobrescrevia o
#     PATH, a contaminacao morre com o sub-shell e nao quebra a limpeza da
#     suite)
PATH_ANTES="$PATH"
printf 'PATH=/tmp/evil\n' >"${_TMP}/v6.config"
PATH_DEPOIS="$(_criar_config_seguro "${_TMP}/v6.config"; printf '%s' "$PATH")"
_checar "config: PATH do processo intacto" "$PATH_ANTES" "$PATH_DEPOIS"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
