#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (CFG_BASE_DIR, DEFAULT_PROGS_DIR, REBUILD,
# DATA_EXTENSIONS, ...) sao consumidas pelos modulos que este arquivo carrega
# com `source`, nao pelo proprio script.
set -euo pipefail
#
# testes/test_arquivos.sh - verificacoes isoladas de binarios/arquivos.sh
#
# arquivos.sh cuida da limpeza da base, da recuperacao de arquivos e do
# expurgo. As funcoes cobertas aqui sao as de decisao pura e as de validacao:
# o padrao de limpeza (que varreria a base), a deteccao de link duro/simbolico
# (que decide o que NAO pode ir para o jutil) e a sanitizacao de entrada.
#
# Rodar direto, sem TTY:
#   bash testes/test_arquivos.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

# shellcheck source=../binarios/utils.sh
. "${RAIZ_TESTE}/binarios/utils.sh"

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

_executar() { # _executar <comando...> ; resultado em RC
    RC=0
    "$@" >/dev/null 2>&1 || RC=$?
}

_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

# ---------- ambiente: clones dos diretorios protegidos, dentro do TMP ----------#
export SCRIPT_DIR="${_TMP}/script"
export CFG_DIR="${_TMP}/cfg"
export CFG_PORTALSAV="${_TMP}/portalsav"
export RAIZ="${_TMP}/raiz"
export LOG_ATU="${_TMP}/logs/test_arquivos.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups_base"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"

PERM_DIR_SECURE=0755
DEFAULT_ZIP=zip
DEFAULT_UNZIP=unzip
DEFAULT_FIND="find"
CFG_BASE_DIR="/sav/base"
CFG_BASE_DIR2=""
REBUILD=""

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$DEFAULT_LOGS_DIR" \
    "$DEFAULT_BACKUP_DIR" "$DEFAULT_BASEBACKUP_DIR" "$DEFAULT_PROGS_DIR" \
    "$DEFAULT_PROGS_ATUAL_DIR" "${RAIZ}${CFG_BASE_DIR}"

# shellcheck source=../binarios/arquivos.sh
. "${RAIZ_TESTE}/binarios/arquivos.sh"

# Silencia a saida e captura a ultima mensagem de _erro.
_erro() { _ULTIMO_ERRO="${1:-}"; }
_aviso() { :; }
_ok() { :; }
_msg() { :; }
_exibir_mensagem_centralizada() { :; }
_exibir_mensagem_centralizada_a_esquerda() { :; }
_linha() { :; }
_meia_linha() { :; }
_aguardar() { :; }
_aguardar_tecla() { :; }
_menu_escolha_base() { return 1; }
clear() { :; }

# Funcoes que podem NAO existir em versoes antigas do modulo (a prova de
# discriminacao roda a suite contra o codigo antigo). Sem este fallback, o
# "command not found" aborta a suite no meio (set -e) em vez de virar uma
# verificacao falhando — o relatorio ficaria incompleto e enganoso.
for _fn in _sanitizar_entrada _validar_padrao_limpeza _validar_rebuild \
           _carregar_links_duros _eh_link _limpar_cache_eh_link _selecionar_base_arquivos; do
    if ! command -v "$_fn" >/dev/null 2>&1; then
        eval "${_fn}() { return 127; }"
    fi
done

# ---------- _sanitizar_entrada ----------#
# Mantem apenas 0x20..0x7E: remove acentos, tabs e caracteres de controle.
_checar "sanitizar: texto simples intacto" "PROGRAMA" "$(_sanitizar_entrada "PROGRAMA")"
_checar "sanitizar: espaco preservado" "DOIS PALAVRAS" "$(_sanitizar_entrada "DOIS PALAVRAS")"
_checar "sanitizar: acento removido por inteiro (nao transliterado)" "SV" "$(_sanitizar_entrada "SÁV")"
_checar "sanitizar: tab removido" "AB" "$(_sanitizar_entrada $'A\tB')"
_checar "sanitizar: quebra de linha removida" "AB" "$(_sanitizar_entrada $'A\nB')"
_checar "sanitizar: vazio intacto" "" "$(_sanitizar_entrada "")"

# ---------- _validar_padrao_limpeza: o padrao nao pode varrer a base ----------#
_checar "padrao: nome simples aceito" "0" "$(_rc _validar_padrao_limpeza "TEMP")"
_checar "padrao: extensao com ponto aceita" "0" "$(_rc _validar_padrao_limpeza "*.tmp")"
_checar "padrao: prefixo com asterisco aceito" "0" "$(_rc _validar_padrao_limpeza "TEMP*")"
_checar "padrao: sufixo com asterisco aceito" "0" "$(_rc _validar_padrao_limpeza "*_TEMP")"
_checar "padrao: espaco aceito" "0" "$(_rc _validar_padrao_limpeza "ARQ COM ESPACO")"
_checar "padrao: vazio recusado" "1" "$(_rc _validar_padrao_limpeza "")"
_checar "padrao: separador de caminho recusado" "1" "$(_rc _validar_padrao_limpeza "dir/arquivo")"
_checar "padrao: traversal recusado" "1" "$(_rc _validar_padrao_limpeza "../arquivo")"
_checar "padrao: metacaractere recusado" "1" "$(_rc _validar_padrao_limpeza "ARQ;RM")"
_checar "padrao: pipe recusado" "1" "$(_rc _validar_padrao_limpeza "ARQ|RM")"
_checar "padrao: asterisco puro recusado" "1" "$(_rc _validar_padrao_limpeza "*")"
_checar "padrao: asterisco duplo recusado" "1" "$(_rc _validar_padrao_limpeza "**")"
_checar "padrao: *.* recusado" "1" "$(_rc _validar_padrao_limpeza "*.*")"
_checar "padrao: *.*.* recusado" "1" "$(_rc _validar_padrao_limpeza "*.*.*")"
_checar "padrao: ponto recusado" "1" "$(_rc _validar_padrao_limpeza ".")"
_checar "padrao: dois pontos recusado" "1" "$(_rc _validar_padrao_limpeza "..")"

# ---------- _validar_rebuild: o executavel do jutil ----------#
_JUTIL_PRONTO=""
REBUILD=""
_executar _validar_rebuild
_checar "rebuild: sem executavel RECUSADO" "1" "$RC"
_checar "rebuild: cache nao foi poisoning" "" "${_JUTIL_PRONTO:-}"

REBUILD="${_TMP}/nao_executavel"
: >"$REBUILD"
chmod 644 "$REBUILD"
_executar _validar_rebuild
_checar "rebuild: arquivo nao executavel RECUSADO" "1" "$RC"

REBUILD="${_TMP}/executavel"
printf '#!/bin/sh\nexit 0\n' >"$REBUILD"
chmod 755 "$REBUILD"
_executar _validar_rebuild
_checar "rebuild: executavel ACEITO" "0" "$RC"
_checar "rebuild: cache armado" "1" "${_JUTIL_PRONTO:-}"
_executar _validar_rebuild
_checar "rebuild: segunda chamada usa o cache" "0" "$RC"

# ---------- _carregar_links_duros e _eh_link ----------#
# Link duro (ln SEM -s) e um inode comum: `test -L` nao o ve, e o jutil
# reescreveria o mesmo inode dos dois nomes. O mapa de links duros e o que
# separa os dois casos.
DIR_LINKS="${_TMP}/links"
mkdir -p "$DIR_LINKS"
printf 'comum\n' >"${DIR_LINKS}/comum.txt"
printf 'duro\n' >"${DIR_LINKS}/original.txt"
ln "${DIR_LINKS}/original.txt" "${DIR_LINKS}/duro.txt" 2>/dev/null || true
ln -s "${DIR_LINKS}/comum.txt" "${DIR_LINKS}/simbolico.txt" 2>/dev/null || true

_LINKS_DUROS=()
_LINKS_DUROS_DIR=""
# Protected: o fallback para funcao ausente devolve 127, e uma chamada solta
# com set -e abortaria a suite no meio do relatorio.
_limpar_cache_eh_link || true
_executar _carregar_links_duros "$DIR_LINKS"
_checar "links: mapa carregado" "0" "$RC"
_checar "links: hard link no mapa" "sim" \
    "$([ -n "${_LINKS_DUROS[${DIR_LINKS}/duro.txt]:-}" ] && printf 'sim' || printf 'nao')"
_checar "links: arquivo comum fora do mapa" "nao" \
    "$([ -n "${_LINKS_DUROS[${DIR_LINKS}/comum.txt]:-}" ] && printf 'sim' || printf 'nao')"

_checar "links: hard link detectado" "0" "$(_rc _eh_link "${DIR_LINKS}/duro.txt")"
_checar "links: link simbolico detectado" "0" "$(_rc _eh_link "${DIR_LINKS}/simbolico.txt")"
_checar "links: arquivo comum NAO e link" "1" "$(_rc _eh_link "${DIR_LINKS}/comum.txt")"
_checar "links: caminho vazio nao e link" "1" "$(_rc _eh_link "")"
_checar "links: caminho inexistente nao e link" "1" "$(_rc _eh_link "${DIR_LINKS}/nao_existe.txt")"

# fora do diretorio mapeado: o fallback de stat decide
_limpar_cache_eh_link || true
_LINKS_DUROS_DIR=""
_checar "links: hard link detectado fora do mapa (fallback stat)" "0" \
    "$(_rc _eh_link "${DIR_LINKS}/duro.txt")"

# ---------- _selecionar_base_arquivos: a base nao pode ser maliciosa ----------#
base_trabalho=""
_executar _selecionar_base_arquivos
_checar "base: base valida aceita" "0" "$RC"
_checar "base: base resolvida" "${RAIZ}/sav/base" "$base_trabalho"

CFG_BASE_DIR="/sav/../etc"
base_trabalho=""
_executar _selecionar_base_arquivos
_checar "base: base com traversal RECUSADA" "1" "$RC"
CFG_BASE_DIR="/sav/base"

CFG_BASE_DIR="/sav/inexistente"
base_trabalho=""
_executar _selecionar_base_arquivos
_checar "base: base inexistente RECUSADA" "1" "$RC"
CFG_BASE_DIR="/sav/base"

CFG_BASE_DIR=""
base_trabalho=""
_executar _selecionar_base_arquivos
_checar "base: base nao configurada RECUSADA" "1" "$RC"
CFG_BASE_DIR="/sav/base"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
