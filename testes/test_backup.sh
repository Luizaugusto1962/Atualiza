#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (DEFAULT_ZIP, DEFAULT_UNZIP, DEFAULT_FIND,
# CFG_EMPRESA, ...) sao consumidas pelos modulos que este arquivo carrega com
# `source`, nao pelo proprio script.
set -euo pipefail
#
# testes/test_backup.sh - verificacoes isoladas de binarios/backup.sh
#
# backup.sh compacta a base de dados, restaura backups e faz a rotacao. As
# funcoes cobertas aqui sao as de decisao pura e os portoes de validacao —
# as que podem ser exercitadas sem disco de producao e sem rede.
#
# Rodar direto, sem TTY:
#   bash testes/test_backup.sh
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

_contem() { # _contem <texto> <substring> -> sim/nao
    if [[ "$1" == *"$2"* ]]; then printf 'sim'; else printf 'nao'; fi
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
export LOG_ATU="${_TMP}/logs/test_backup.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups_base"
export DEFAULT_BIBLIOTECA_DIR="${_TMP}/biblioteca"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_ENVIA_DIR="${_TMP}/envia"

PERM_DIR_SECURE=0755
DEFAULT_ZIP=zip
DEFAULT_UNZIP=unzip
DEFAULT_FIND="find"
CFG_EMPRESA="ACME"
CFG_BASE_DIR="/sav/base"
CFG_BASE_DIR2=""
base_trabalho=""

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$DEFAULT_LOGS_DIR" \
    "$DEFAULT_BACKUP_DIR" "$DEFAULT_BASEBACKUP_DIR" "${RAIZ}${CFG_BASE_DIR}"

# shellcheck source=../binarios/backup.sh
. "${RAIZ_TESTE}/binarios/backup.sh"

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
_confirmar() { return 0; }
clear() { :; }

# ---------- _escapar_glob: metacaracteres viram literais ----------#
# O nome da empresa entra num padrao de glob; um "*" colado na CFG_EMPRESA
# transformaria a busca em "qualquer arquivo".
_checar "glob: nome simples intacto" "ACME" "$(_escapar_glob "ACME")"
_checar "glob: asterisco escapado" 'A\*C' "$(_escapar_glob "A*C")"
_checar "glob: interrogacao escapada" 'a\?b' "$(_escapar_glob "a?b")"
_checar "glob: colchetes escapados" 'a\[b\]c' "$(_escapar_glob "a[b]c")"
_checar "glob: vazio intacto" "" "$(_escapar_glob "")"

# ---------- _estimar_espaco_necessario_kb: razao com limites ----------#
# 1 MiB com razao 50% = 512 KB exigidos.
C_BACKUP_ESPACO_RATIO=50
_checar "espaco: 1MiB com razao 50% = 512 KB" "512" "$(_estimar_espaco_necessario_kb 1048576)"
C_BACKUP_ESPACO_RATIO=200
_checar "espaco: razao acima de 100% e limitada a 100%" "1024" "$(_estimar_espaco_necessario_kb 1048576)"
C_BACKUP_ESPACO_RATIO=5
_checar "espaco: razao abaixo de 10% e limitada a 10%" "102" "$(_estimar_espaco_necessario_kb 1048576)"
C_BACKUP_ESPACO_RATIO="invalida"
_checar "espaco: razao invalida volta ao padrao 50%" "512" "$(_estimar_espaco_necessario_kb 1048576)"
C_BACKUP_ESPACO_RATIO=50
_checar "espaco: bytes nao numericos viram 0" "0" "$(_estimar_espaco_necessario_kb "abc")"
_checar "espaco: bytes vazios viram 0" "0" "$(_estimar_espaco_necessario_kb "")"

# ---------- _verificar_espaco_disco ----------#
# A versao anterior comparava KB com bytes: a checagem era ~512x mais fraca.
_checar "espaco: limite 0 aceito" "0" "$(_rc _verificar_espaco_disco "$_TMP" 0)"
_checar "espaco: limite absurdo recusado" "1" "$(_rc _verificar_espaco_disco "$_TMP" 999999999999)"
_checar "espaco: diretorio inexistente recusado" "1" "$(_rc _verificar_espaco_disco "${_TMP}/nao_existe" 0)"

# ---------- _validar_pre_backup: o portao antes de compactar ----------#
base_trabalho=""
_executar _validar_pre_backup ""
_checar "pre-backup: nome de variavel vazio recusado" "1" "$RC"

_executar _validar_pre_backup "9invalido"
_checar "pre-backup: nome de variavel invalido recusado" "1" "$RC"

DEFAULT_ZIP=""
_executar _validar_pre_backup base_trabalho
_checar "pre-backup: comando de compactacao ausente recusado" "1" "$RC"
DEFAULT_ZIP=zip

CFG_BASE_DIR="/sav/../etc"
base_trabalho=""
_executar _validar_pre_backup base_trabalho
_checar "pre-backup: base com traversal recusada" "1" "$RC"
CFG_BASE_DIR="/sav/base"

CFG_BASE_DIR="/sav/inexistente"
base_trabalho=""
_executar _validar_pre_backup base_trabalho
_checar "pre-backup: base inexistente recusada" "1" "$RC"
CFG_BASE_DIR="/sav/base"

DEFAULT_BASEBACKUP_DIR=""
base_trabalho=""
_executar _validar_pre_backup base_trabalho
_checar "pre-backup: diretorio de backup ausente recusado" "1" "$RC"
DEFAULT_BASEBACKUP_DIR="${_TMP}/backups_base"

base_trabalho=""
_executar _validar_pre_backup base_trabalho
_checar "pre-backup: pre-requisitos validos aceitos" "0" "$RC"
_checar "pre-backup: base devolvida ao chamador" "${RAIZ}/sav/base" "$base_trabalho"

# ---------- _validar_backup_criado: backup vazio e removido ----------#
printf 'PK' >"${_TMP}/pequeno.zip"
_executar _validar_backup_criado "${_TMP}/pequeno.zip"
_checar "backup criado: arquivo pequeno recusado" "1" "$RC"
_checar "backup criado: arquivo pequeno removido" "nao" \
    "$([ -f "${_TMP}/pequeno.zip" ] && printf 'sim' || printf 'nao')"

head -c 500 /dev/zero >"${_TMP}/grande.zip"
_executar _validar_backup_criado "${_TMP}/grande.zip"
_checar "backup criado: arquivo grande aceito" "0" "$RC"
_checar "backup criado: arquivo grande preservado" "sim" \
    "$([ -f "${_TMP}/grande.zip" ] && printf 'sim' || printf 'nao')"

_executar _validar_backup_criado "${_TMP}/nao_existe.zip"
_checar "backup criado: arquivo inexistente recusado" "1" "$RC"

# ---------- _coletar_arquivos_backup: a lista que vai para o ZIP ----------#
# A varredura e feita no diretorio de trabalho (o cwd). Zip, log, tmp, old e
# gz ficam de fora; o resto entra, com o tamanho somado.
mkdir -p "${_TMP}/base"
printf 'dados' >"${_TMP}/base/arquivo.txt"
printf 'dados' >"${_TMP}/base/relatorio.log"
printf 'dados' >"${_TMP}/base/rascunho.tmp"
printf 'dados' >"${_TMP}/base/antigo.old"
printf 'dados' >"${_TMP}/base/compactado.zip"
printf 'dados' >"${_TMP}/base/compactado.tar.gz"

_cwd_salvo="$PWD"
cd "${_TMP}/base" || exit 1
_executar _coletar_arquivos_backup completo
cd "$_cwd_salvo" || exit 1

_checar "coleta: arquivo comum incluido" "sim" \
    "$(printf '%s\n' "${_BACKUP_LISTA[@]+"${_BACKUP_LISTA[@]}"}" | grep -q 'arquivo.txt' && printf 'sim' || printf 'nao')"
_checar "coleta: .log excluido" "nao" \
    "$(printf '%s\n' "${_BACKUP_LISTA[@]+"${_BACKUP_LISTA[@]}"}" | grep -q 'relatorio.log' && printf 'sim' || printf 'nao')"
_checar "coleta: .tmp excluido" "nao" \
    "$(printf '%s\n' "${_BACKUP_LISTA[@]+"${_BACKUP_LISTA[@]}"}" | grep -q 'rascunho.tmp' && printf 'sim' || printf 'nao')"
_checar "coleta: .old excluido" "nao" \
    "$(printf '%s\n' "${_BACKUP_LISTA[@]+"${_BACKUP_LISTA[@]}"}" | grep -q 'antigo.old' && printf 'sim' || printf 'nao')"
_checar "coleta: .zip excluido" "nao" \
    "$(printf '%s\n' "${_BACKUP_LISTA[@]+"${_BACKUP_LISTA[@]}"}" | grep -q 'compactado.zip' && printf 'sim' || printf 'nao')"
_checar "coleta: .tar.gz excluido" "nao" \
    "$(printf '%s\n' "${_BACKUP_LISTA[@]+"${_BACKUP_LISTA[@]}"}" | grep -q 'compactado.tar.gz' && printf 'sim' || printf 'nao')"
_checar "coleta: tamanho total somado" "sim" \
    "$([[ "${_BACKUP_BYTES:-0}" -gt 0 ]] && printf 'sim' || printf 'nao')"
_checar "coleta: lista temporaria removida" "nao" \
    "$(ls "${DEFAULT_BASEBACKUP_DIR}"/.lista_backup_*.tmp >/dev/null 2>&1 && printf 'sim' || printf 'nao')"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
