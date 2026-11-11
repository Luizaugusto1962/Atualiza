#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (ARQUIVO_ZIP_ATU, ATU_DIR_TEMP, LIBS_DIR,
# DEFAULT_BACKUP_DIR, ...) sao consumidas pelos modulos que este arquivo
# carrega com `source`, nao pelo proprio script.
set -euo pipefail
#
# testes/test_baixar.sh - verificacoes isoladas de binarios/baixar.sh
#
# baixar.sh faz o self-update: baixa o pacote, faz backup dos scripts atuais,
# extrai, instala e limpa a recepcao. O ponto critico e a LIMPEZA: o topo de
# CFG_PORTALSAV e um diretorio COMPARTILHADO (recebe backup offline pendente,
# ZIP de biblioteca aguardando processamento e ZIP de reversao de programas), e
# nada ali pode ser apagado por inferencia.
#
# Rodar direto, sem TTY e sem rede:
#   bash testes/test_baixar.sh
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
export LIBS_DIR="${_TMP}/libs"
export LOG_ATU="${_TMP}/logs/test_baixar.log"
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
ARQUIVO_ZIP_ATU="atualiza.zip"
ATU_DIR_TEMP="dir_temp_atualizacao"
ATU_DIR_STAGING="dir_stage_atualizacao"
ATU_SUFIXO_BACKUP=".sh.bkp"
ATU_SUFFIXO_PARCIAL=".part"
ATU_TENTATIVAS_DOWNLOAD=3
ATU_TIMEOUT_CONEXAO=30
ATU_TIMEOUT_DOWNLOAD=300
GITHUB_UPDATE_URL="https://exemplo.invalid/atualiza.zip"

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$LIBS_DIR" \
    "$DEFAULT_LOGS_DIR" "$DEFAULT_BACKUP_DIR" "$DEFAULT_BASEBACKUP_DIR"

# shellcheck source=../binarios/baixar.sh
. "${RAIZ_TESTE}/binarios/baixar.sh"

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

# ---------- _executar_update: o roteamento pela flag offline ----------#
# Bug historico: `case "${CFG_OFFLINE:-}"` com n/s/* — "S"/"N" maiusculos
# caiam no ramo de erro. Hoje a flag e validada uma unica vez por
# _offline_valido, o mesmo criterio dos demais modulos.
FLAG_ONLINE="${_TMP}/online.flag"
FLAG_OFFLINE="${_TMP}/offline.flag"
# NENHUM stub de _atualizar_online/_atualizar_offline aqui: as funcoes reais
# sao testadas mais abaixo. Os stubs do roteamento vivem em sub-shells.

CFG_OFFLINE="x"
rm -f "$FLAG_ONLINE" "$FLAG_OFFLINE"
# Os stubs vao num SUB-SHELL: definidos no shell principal eles
# substituiriam as funcoes reais das secoes seguintes deste arquivo.
_rc=0
(
    _atualizar_online() { : >"$FLAG_ONLINE"; }
    _atualizar_offline() { : >"$FLAG_OFFLINE"; }
    _executar_update
) >/dev/null 2>&1 || _rc=$?
RC="$_rc"
_checar "update: flag invalida RECUSADA" "1" "$RC"
_checar "update: flag invalida nao foi online" "nao" \
    "$([ -f "$FLAG_ONLINE" ] && printf 'sim' || printf 'nao')"
_checar "update: flag invalida nao foi offline" "nao" \
    "$([ -f "$FLAG_OFFLINE" ] && printf 'sim' || printf 'nao')"

CFG_OFFLINE="s"
rm -f "$FLAG_ONLINE" "$FLAG_OFFLINE"
_rc=0
(
    _atualizar_online() { : >"$FLAG_ONLINE"; }
    _atualizar_offline() { : >"$FLAG_OFFLINE"; }
    _executar_update
) >/dev/null 2>&1 || _rc=$?
RC="$_rc"
_checar "update: 's' seguiu para o caminho offline" "0" "$RC"
_checar "update: 's' chamou _atualizar_offline" "sim" \
    "$([ -f "$FLAG_OFFLINE" ] && printf 'sim' || printf 'nao')"
_checar "update: 's' NAO chamou _atualizar_online" "nao" \
    "$([ -f "$FLAG_ONLINE" ] && printf 'sim' || printf 'nao')"

CFG_OFFLINE="n"
rm -f "$FLAG_ONLINE" "$FLAG_OFFLINE"
_rc=0
(
    _atualizar_online() { : >"$FLAG_ONLINE"; }
    _atualizar_offline() { : >"$FLAG_OFFLINE"; }
    _executar_update
) >/dev/null 2>&1 || _rc=$?
RC="$_rc"
_checar "update: 'n' seguiu para o caminho online" "0" "$RC"
_checar "update: 'n' chamou _atualizar_online" "sim" \
    "$([ -f "$FLAG_ONLINE" ] && printf 'sim' || printf 'nao')"

# ---------- _voltar_dir_trabalho: o cd da extracao nao pode vazar ----------#
DESTINO="${_TMP}/destino"
mkdir -p "$DESTINO"
CWD_ANTERIOR="$PWD"
cd "$DESTINO" || exit 1
_executar _voltar_dir_trabalho "$DESTINO"
_checar "cwd: voltou para o diretorio de trabalho" "$DESTINO" "$PWD"

cd "${_TMP}" || exit 1
_executar _voltar_dir_trabalho "${_TMP}/nao_existe"
_checar "cwd: destino invalido mantem o cwd" "${_TMP}" "$PWD"
cd "$CWD_ANTERIOR" || exit 1

# ---------- _coletar_backups: o backup dos scripts atuais ----------#
printf 'echo 1\n' >"${LIBS_DIR}/utils.sh"
printf 'echo 2\n' >"${LIBS_DIR}/programas.sh"
_executar _coletar_backups
# O "zip -jm" move os arquivos para dentro do ZIP (opcao -m apaga a origem),
# entao o que resta no disco e o ZIP — os .sh.bkp vao dentro dele.
_checar "backup: scripts copiados com o sufixo" "sim" \
    "$(unzip -Z1 "${DEFAULT_BACKUP_DIR}"/*_backup.zip 2>/dev/null | grep -q 'utils.sh' && printf 'sim' || printf 'nao')"
_checar "backup: ZIP de rollback gerado" "sim" \
    "$(ls "${DEFAULT_BACKUP_DIR}"/*_backup.zip >/dev/null 2>&1 && printf 'sim' || printf 'nao')"
_checar "backup: ZIP de rollback integro" "0" \
    "$(_rc unzip -t "${DEFAULT_BACKUP_DIR}"/*_backup.zip)"

LIBS_DIR_SALVO="$LIBS_DIR"
LIBS_DIR="${_TMP}/libs_inexistente"
_executar _coletar_backups
_checar "backup: diretorio de scripts ausente RECUSADO" "1" "$RC"
LIBS_DIR="$LIBS_DIR_SALVO"

# ---------- _limpar_recepcao_atualizacao: o compartilhado NAO e apagado ----------#
# Regra do AGENTS.md: CFG_PORTALSAV e diretorio compartilhado. A limpeza pode
# remover apenas os artefatos nominais da atualizacao (o ZIP, o .part, o
# temporario e o staging) — todo o resto e material de outra operacao.
mkdir -p "${CFG_PORTALSAV}/${ATU_DIR_TEMP}"
mkdir -p "${CFG_PORTALSAV}/${ATU_DIR_STAGING}"
: >"${CFG_PORTALSAV}/${ARQUIVO_ZIP_ATU}"
: >"${CFG_PORTALSAV}/${ARQUIVO_ZIP_ATU}${ATU_SUFFIXO_PARCIAL}"
: >"${CFG_PORTALSAV}/${ATU_DIR_TEMP}/resumo.txt"
: >"${CFG_PORTALSAV}/${ATU_DIR_STAGING}/extraido.sh"
: >"${CFG_PORTALSAV}/backup_offline_pendente.zip"
: >"${CFG_PORTALSAV}/biblioteca_aguardando.zip"
: >"${CFG_PORTALSAV}/reversao_programas.zip"

_executar _limpar_recepcao_atualizacao
_checar "limpeza: concluded com sucesso" "0" "$RC"
_checar "limpeza: ZIP da atualizacao removido" "nao" \
    "$([ -f "${CFG_PORTALSAV}/${ARQUIVO_ZIP_ATU}" ] && printf 'sim' || printf 'nao')"
_checar "limpeza: .part do download interrompido removido" "nao" \
    "$([ -f "${CFG_PORTALSAV}/${ARQUIVO_ZIP_ATU}${ATU_SUFFIXO_PARCIAL}" ] && printf 'sim' || printf 'nao')"
_checar "limpeza: temporario removido" "nao" \
    "$([ -d "${CFG_PORTALSAV}/${ATU_DIR_TEMP}" ] && printf 'sim' || printf 'nao')"
_checar "limpeza: staging removido" "nao" \
    "$([ -d "${CFG_PORTALSAV}/${ATU_DIR_STAGING}" ] && printf 'sim' || printf 'nao')"
_checar "limpeza: backup offline pendente PRESERVADO" "sim" \
    "$([ -f "${CFG_PORTALSAV}/backup_offline_pendente.zip" ] && printf 'sim' || printf 'nao')"
_checar "limpeza: ZIP de biblioteca PRESERVADO" "sim" \
    "$([ -f "${CFG_PORTALSAV}/biblioteca_aguardando.zip" ] && printf 'sim' || printf 'nao')"
_checar "limpeza: ZIP de reversao PRESERVADO" "sim" \
    "$([ -f "${CFG_PORTALSAV}/reversao_programas.zip" ] && printf 'sim' || printf 'nao')"

# Nome derivado malformado: com ATU_DIR_STAGING vazio, "$staging" resolveria
# para o proprio CFG_PORTALSAV e o rm apagaria a recepcao inteira.
ATU_DIR_STAGING_SALVO="$ATU_DIR_STAGING"
: >"${CFG_PORTALSAV}/material_do_usuario.txt"
ATU_DIR_STAGING="../"
_executar _limpar_recepcao_atualizacao
_checar "limpeza: nome derivado malformado RECUSADO" "1" "$RC"
_checar "limpeza: material do usuario preservado apos recusa" "sim" \
    "$([ -f "${CFG_PORTALSAV}/material_do_usuario.txt" ] && printf 'sim' || printf 'nao')"
ATU_DIR_STAGING="$ATU_DIR_STAGING_SALVO"

# ---------- _expandir_backups_zip: o staging so recebe backup seguro ----------#
_criar_zip() { # _criar_zip <arquivo> <ok|absoluto>
    python3 - "$1" "$2" <<'PY' || return 1
import sys, zipfile
out, kind = sys.argv[1], sys.argv[2]
names = {
    "ok":       ["utils.sh.bkp"],
    "absoluto": ["/tmp/atualiza_suite_sentinel.txt"],
}
with zipfile.ZipFile(out, "w") as z:
    for n in names[kind]:
        z.writestr(n, "conteudo de teste")
PY
}

STAGING="${_TMP}/staging"
# O teste de _coletar_backups acima deixou um *_backup.zip em DEFAULT_BACKUP_DIR;
# _expandir_backups_zip procuraria nele. A pasta e limpa para o caso "sem backup".
rm -f "${DEFAULT_BACKUP_DIR}"/*_backup.zip
_executar _expandir_backups_zip "$STAGING"
_checar "staging: sem backup anterior RECUSADO" "1" "$RC"

_criar_zip "${DEFAULT_BACKUP_DIR}/0101_backup.zip" absoluto
rm -f /tmp/atualiza_suite_sentinel.txt
_ULTIMO_ERRO=""
_executar _expandir_backups_zip "$STAGING"
_checar "staging: backup com caminho absoluto RECUSADO" "1" "$RC"
_checar "staging: recusa menciona entradas inseguras" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "inseguras")"
_checar "staging: nada foi extraido (sentinela ausente)" "nao" \
    "$([ -f "/tmp/atualiza_suite_sentinel.txt" ] && printf 'sim' || printf 'nao')"

rm -f "${DEFAULT_BACKUP_DIR}"/*_backup.zip
_criar_zip "${DEFAULT_BACKUP_DIR}/0101_backup.zip" ok
_executar _expandir_backups_zip "$STAGING"
_checar "staging: backup legitimo expandido" "0" "$RC"
_checar "staging: conteudo extraido no staging" "sim" \
    "$([ -f "${STAGING}/utils.sh.bkp" ] && printf 'sim' || printf 'nao')"

# ---------- _atualizar_online: a URL e validada ANTES da rede ----------#
GITHUB_UPDATE_URL="ftp://exemplo.invalid/pacote.zip"
_executar _atualizar_online
_checar "online: URL fora de http(s) RECUSADA" "1" "$RC"

GITHUB_UPDATE_URL="https://exemplo.invalid/ pacote.zip"
_executar _atualizar_online
_checar "online: URL com espaco RECUSADA" "1" "$RC"

GITHUB_UPDATE_URL="https://exemplo.invalid/pacote.zip"

# ---------- _atualizar_offline: sem pacote nao ha atualizacao ----------#
FLAG_ATUALIZANDO="${_TMP}/atualizando.flag"
_atualizando() { : >"$FLAG_ATUALIZANDO"; }

rm -f "$FLAG_ATUALIZANDO"
_executar _atualizar_offline
_checar "offline: pacote ausente RECUSADO" "1" "$RC"
_checar "offline: pacote ausente nao instalou nada" "nao" \
    "$([ -f "$FLAG_ATUALIZANDO" ] && printf 'sim' || printf 'nao')"

: >"${CFG_PORTALSAV}/${ARQUIVO_ZIP_ATU}"
rm -f "$FLAG_ATUALIZANDO"
_executar _atualizar_offline
_checar "offline: pacote vazio RECUSADO" "1" "$RC"

printf 'PK\003\004conteudo' >"${CFG_PORTALSAV}/${ARQUIVO_ZIP_ATU}"
rm -f "$FLAG_ATUALIZANDO"
_executar _atualizar_offline
_checar "offline: pacote presente seguiu para a instalacao" "0" "$RC"
_checar "offline: instalacao foi executada" "sim" \
    "$([ -f "$FLAG_ATUALIZANDO" ] && printf 'sim' || printf 'nao')"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
