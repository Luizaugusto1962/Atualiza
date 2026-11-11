#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (PERM_DIR_SECURE, DEFAULT_UNZIP,
# C_BACKUP_TESTE_INTEGRIDADE, EXTENSAO_CLASS, PROGRAMAS_SELECIONADOS,
# dir_temp_atualizacao, ...) sao consumidas pelos modulos que este arquivo
# carrega com `source` (ou por escopo dinamico), nao pelo proprio script.
set -euo pipefail
#
# testes/test_programas.sh - verificacoes isoladas de binarios/programas.sh
#
# programas.sh e o modulo que extrai e instala pacotes de atualizacao. A
# parte perigosa e o portao _validar_pre_requisitos_atualizacao: e ele que
# precisa barrar um pacote com entrada insegura ANTES de qualquer escrita
# (criar o temporario, backupar o programa antigo, extrair).
#
# Este arquivo cobre essa superficie sem TTY, sem rede e sem tocar o disco do
# sistema: tudo acontece em mktemp -d.
#
# Rodar direto, sem TTY:
#   bash testes/test_programas.sh
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

# Executa o comando no shell CORRENTE (sem subshell) e deixa o codigo em RC.
# Necesario para capturar _ULTIMO_ERRO: dentro de $( ) a atribuicao acontece
# no subshell e se perde.
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
export LOG_ATU="${_TMP}/logs/test_programas.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups"
export DEFAULT_BIBLIOTECA_DIR="${_TMP}/biblioteca"
export DEFAULT_BIBLIOTECA_ATUAL_DIR="${_TMP}/biblioteca_atual"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"
export DEFAULT_ENVIA_DIR="${_TMP}/envia"

PERM_FILE_PRIVATE=0600
PERM_DIR_SECURE=0755
DEFAULT_UNZIP=unzip
DEFAULT_ZIP=zip
DEFAULT_TAR=tar
C_BACKUP_TESTE_INTEGRIDADE=1
EXTENSAO_CLASS=class
EXTENSAO_TELAS=TEL

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$DEFAULT_LOGS_DIR" \
    "$DEFAULT_BACKUP_DIR" "$DEFAULT_PROGS_DIR" "$DEFAULT_PROGS_ATUAL_DIR"

# shellcheck source=../binarios/programas.sh
. "${RAIZ_TESTE}/binarios/programas.sh"

# Silencia a saida e captura a ultima mensagem de _erro.
_erro() { _ULTIMO_ERRO="${1:-}"; }
_aviso() { :; }
_ok() { :; }
_msg() { :; }
_exibir_mensagem_centralizada() { :; }
_exibir_mensagem_centralizada_a_esquerda() { :; }
_linha() { :; }
_meia_linha() { :; }
_aguardar_tecla() { :; }

# ---------- artefatos: ZIPs legitimos e maliciosos ----------#
_criar_zip() { # _criar_zip <arquivo> <ok|traversal|absoluto|win>
    python3 - "$1" "$2" <<'PY' || return 1
import sys, zipfile
out, kind = sys.argv[1], sys.argv[2]
names = {
    "ok":        ["programa/OK.class", "programa/OK.TEL"],
    "traversal": ["../evil.class"],
    "absoluto":  ["/etc/passwd"],
    "win":       ["C:\\evil.class"],
}
with zipfile.ZipFile(out, "w") as z:
    for n in names[kind]:
        z.writestr(n, "conteudo de teste")
PY
}

ZIP_OK="${_TMP}/ok.zip"
ZIP_TRAV="${_TMP}/traversal.zip"
ZIP_ABS="${_TMP}/absoluto.zip"
ZIP_WIN="${_TMP}/win.zip"
_criar_zip "$ZIP_OK" ok
_criar_zip "$ZIP_TRAV" traversal
_criar_zip "$ZIP_ABS" absoluto
_criar_zip "$ZIP_WIN" win

# ---------- _validar_pre_requisitos_atualizacao: o portao de seguranca ----------#
# Sem esta validacao, um pacote com "../" ou caminho absoluto escapa do
# diretorio de extracao e sobrescreve o proprio destino da atualizacao. Para
# um ZIP legitimo nada muda: o validador e silencioso.
cp "$ZIP_OK" "${CFG_PORTALSAV}/PROG.zip"
PROGRAMAS_SELECIONADOS=("PROG")
ARQUIVOS_PROGRAMA=("PROG.zip")
_ULTIMO_ERRO=""
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: pacote legitimo aceito" "0" "$RC"
_checar "prereq: pacote legitimo nao acusa entrada insegura" "nao" \
    "$(_contem "$_ULTIMO_ERRO" "pacote invalido")"

cp "$ZIP_TRAV" "${CFG_PORTALSAV}/MAL.zip"
PROGRAMAS_SELECIONADOS=("MAL")
ARQUIVOS_PROGRAMA=("MAL.zip")
_ULTIMO_ERRO=""
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: pacote com traversal BARRADO" "1" "$RC"
_checar "prereq: traversal barrado por entrada insegura" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "pacote invalido")"

cp "$ZIP_ABS" "${CFG_PORTALSAV}/ABS.zip"
PROGRAMAS_SELECIONADOS=("ABS")
ARQUIVOS_PROGRAMA=("ABS.zip")
_ULTIMO_ERRO=""
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: pacote com caminho absoluto BARRADO" "1" "$RC"
_checar "prereq: caminho absoluto barrado por entrada insegura" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "pacote invalido")"

cp "$ZIP_WIN" "${CFG_PORTALSAV}/WIN.zip"
PROGRAMAS_SELECIONADOS=("WIN")
ARQUIVOS_PROGRAMA=("WIN.zip")
_ULTIMO_ERRO=""
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: pacote com caminho windows BARRADO" "1" "$RC"
_checar "prereq: caminho windows barrado por entrada insegura" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "pacote invalido")"

PROGRAMAS_SELECIONADOS=("FALTA")
ARQUIVOS_PROGRAMA=("FALTA.zip")
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: arquivo ausente barrado" "1" "$RC"

PROGRAMAS_SELECIONADOS=("A" "B")
ARQUIVOS_PROGRAMA=("PROG.zip")
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: inconsistencia entre arrays barrada" "1" "$RC"

CFG_PORTALSAV_SALVO="$CFG_PORTALSAV"
CFG_PORTALSAV=""
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: CFG_PORTALSAV vazio barrado" "1" "$RC"
CFG_PORTALSAV="$CFG_PORTALSAV_SALVO"

# caminho paralelo (>=2 arquivos): o malicioso no meio da onda tem de barrar
cp "$ZIP_OK" "${CFG_PORTALSAV}/OK2.zip"
cp "$ZIP_TRAV" "${CFG_PORTALSAV}/MAL2.zip"
PROGRAMAS_SELECIONADOS=("OK2" "MAL2")
ARQUIVOS_PROGRAMA=("OK2.zip" "MAL2.zip")
_ULTIMO_ERRO=""
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: pacote malicioso barrado no caminho paralelo" "1" "$RC"
_checar "prereq: caminho paralelo barrado por entrada insegura" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "pacote invalido")"

cp "$ZIP_OK" "${CFG_PORTALSAV}/OK3.zip"
cp "$ZIP_OK" "${CFG_PORTALSAV}/OK4.zip"
PROGRAMAS_SELECIONADOS=("OK3" "OK4")
ARQUIVOS_PROGRAMA=("OK3.zip" "OK4.zip")
_executar _validar_pre_requisitos_atualizacao
_checar "prereq: pacotes legitimos aceitos no caminho paralelo" "0" "$RC"

# ---------- _validar_integridade_backup ----------#
printf 'PK' >"${_TMP}/pequeno.zip"
head -c 200 /dev/zero >"${_TMP}/corrompido.zip"
_checar "integridade: arquivo inexistente recusado" "1" \
    "$(_rc _validar_integridade_backup "${_TMP}/nao_existe.zip")"
_checar "integridade: zip abaixo de 22 bytes recusado" "1" \
    "$(_rc _validar_integridade_backup "${_TMP}/pequeno.zip")"
_checar "integridade: arquivo corrompido recusado" "1" \
    "$(_rc _validar_integridade_backup "${_TMP}/corrompido.zip")"
_checar "integridade: zip valido aceito" "0" "$(_rc _validar_integridade_backup "$ZIP_OK")"
_checar "integridade: pular_tamanho ignora o tamanho" "1" \
    "$(_rc _validar_integridade_backup "${_TMP}/pequeno.zip" 1)"
_checar "integridade: pular_tamanho ainda confere o zip" "0" \
    "$(_rc _validar_integridade_backup "$ZIP_OK" 1)"

# ---------- _cleanupAtualizacao ----------#
# A limpeza usa escopo dinamico: le _cwd e dir_temp_atualizacao do chamador.
# Um caminho inseguro nao pode virar rm -rf na raiz.
mkdir -p "${_TMP}/cleanup_alvo"
touch "${_TMP}/cleanup_alvo/mantem.txt"
_cwd="$PWD"
dir_temp_atualizacao="${_TMP}/cleanup_alvo/.."
_cleanupAtualizacao
_checar "cleanup: caminho inseguro nao apaga nada" "sim" \
    "$([ -f "${_TMP}/cleanup_alvo/mantem.txt" ] && printf 'sim' || printf 'nao')"

mkdir -p "${_TMP}/cleanup_ok"
_cwd="$PWD"
dir_temp_atualizacao="${_TMP}/cleanup_ok"
_cleanupAtualizacao
_checar "cleanup: caminho seguro e removido" "nao" \
    "$([ -d "${_TMP}/cleanup_ok" ] && printf 'sim' || printf 'nao')"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
