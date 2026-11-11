#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (DEFAULT_UNZIP, DEFAULT_TAR, DEFAULT_FIND,
# SAVATU1, E_EXEC, ...) sao consumidas pelos modulos que este arquivo carrega
# com `source`, nao pelo proprio script.
set -euo pipefail
#
# testes/test_biblioteca.sh - verificacoes isoladas de binarios/biblioteca.sh
#
# biblioteca.sh extrai pacotes de biblioteca NA RAIZ (em producao, o unzip roda
# com "-d /"): e o unico ponto do sistema em que um pacote com caminho
# absoluto pode escrever fora do destino. Por isso a validacao de entradas
# (_validar_backup_entradas_seguras) e obrigatoria ANTES de qualquer
# extracao — e aqui ela e testada de verdade.
#
# ATENCAO (por que o caminho feliz de extracao NAO e exercitado):
# _reverter_biblioteca_completa/_reverter_programa_especifico_biblioteca
# extraem em "/". Se a validacao regredisse, o unzip escreveria no disco real.
# Por isso o pacote malicioso usado aqui tem a entrada ABSOLUTA
# "/tmp/atualiza_suite_sentinel.txt": se a extracao vazasse, o arquivo
# apareceria no /tmp — e o teste verifica que ele NAO aparece.
#
# Rodar direto, sem TTY:
#   bash testes/test_biblioteca.sh
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
export LOG_ATU="${_TMP}/logs/test_biblioteca.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BIBLIOTECA_DIR="${_TMP}/biblioteca"
export DEFAULT_BIBLIOTECA_ATUAL_DIR="${_TMP}/biblioteca_atual"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"
export DEFAULT_ENVIA_DIR="${_TMP}/envia"

PERM_DIR_SECURE=0755
DEFAULT_UNZIP=unzip
DEFAULT_TAR=tar
DEFAULT_FIND="find"
SAVATU1="prog"
SAVATU2="prog"
SAVATU3="prog"
VERSAO="2026"
VERSAOANT="2025"
E_EXEC="${_TMP}/raiz/sav/classes"
T_TELAS="${_TMP}/raiz/sav/tel_isc"

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$DEFAULT_LOGS_DIR" \
    "$DEFAULT_BIBLIOTECA_DIR" "$DEFAULT_BIBLIOTECA_ATUAL_DIR" "$E_EXEC" "$T_TELAS"

# shellcheck source=../binarios/biblioteca.sh
. "${RAIZ_TESTE}/binarios/biblioteca.sh"

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

# ---------- artefatos: ZIPs legitimos e maliciosos ----------#
_criar_zip() { # _criar_zip <arquivo> <ok|absoluto|traversal>
    python3 - "$1" "$2" <<'PY' || return 1
import sys, zipfile
out, kind = sys.argv[1], sys.argv[2]
names = {
    "ok":        ["sav/classes/OK.class"],
    "absoluto":  ["/tmp/atualiza_suite_sentinel.txt"],
    "traversal": ["../atualiza_suite_sentinel.txt"],
}
with zipfile.ZipFile(out, "w") as z:
    for n in names[kind]:
        z.writestr(n, "conteudo de teste")
PY
}

ZIP_OK="${_TMP}/ok.zip"
ZIP_ABS="${_TMP}/absoluto.zip"
ZIP_TRAV="${_TMP}/traversal.zip"
_criar_zip "$ZIP_OK" ok
_criar_zip "$ZIP_ABS" absoluto
_criar_zip "$ZIP_TRAV" traversal
SENTINELA="/tmp/atualiza_suite_sentinel.txt"

# ---------- _validar_versao_biblioteca ----------#
# A versao entra em nome de arquivo e no .versao: precisa ser so digitos.
_checar "versao: 2026 aceito" "0" "$(_rc _validar_versao_biblioteca "2026")"
_checar "versao: vazio recusado" "1" "$(_rc _validar_versao_biblioteca "")"
_checar "versao: com letra recusado" "1" "$(_rc _validar_versao_biblioteca "20a6")"
_checar "versao: com ponto recusado" "1" "$(_rc _validar_versao_biblioteca "2026.1")"
_checar "versao: com espaco recusado" "1" "$(_rc _validar_versao_biblioteca " 2026")"
_checar "versao: com escape recusado" "1" "$(_rc _validar_versao_biblioteca '\033[2J')"

# ---------- _listar_entradas_backup ----------#
_checar "listar: zip inexistente recusado" "1" "$(_rc _listar_entradas_backup "${_TMP}/nao_existe.zip")"
_checar "listar: zip valido listado" "sim" \
    "$(_listar_entradas_backup "$ZIP_OK" | grep -q 'OK.class' && printf 'sim' || printf 'nao')"

# ---------- _reverter_biblioteca_completa: a extracao acontece na RAIZ ----------#
# O portao e _validar_backup_entradas_seguras. Com o pacote malicioso a
# funcao precisa recusar ANTES do unzip; o sentinela em /tmp prova que nada
# foi extraido.
rm -f "$SENTINELA"
_ULTIMO_ERRO=""
_executar _reverter_biblioteca_completa "$ZIP_ABS"
_checar "reversao: pacote com caminho absoluto BARRADO" "1" "$RC"
_checar "reversao: recusa menciona caminhos inseguros" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "inseguros")"
_checar "reversao: nada foi extraido (sentinela ausente)" "nao" \
    "$([ -f "$SENTINELA" ] && printf 'sim' || printf 'nao')"

rm -f "$SENTINELA"
_ULTIMO_ERRO=""
_executar _reverter_biblioteca_completa "$ZIP_TRAV"
_checar "reversao: pacote com traversal BARRADO" "1" "$RC"
_checar "reversao: nada foi extraido no traversal (sentinela ausente)" "nao" \
    "$([ -f "$SENTINELA" ] && printf 'sim' || printf 'nao')"

_executar _reverter_biblioteca_completa "${_TMP}/nao_existe.zip"
_checar "reversao: backup inexistente recusado" "1" "$RC"

# ---------- _reverter_programa_especifico_biblioteca ----------#
_ULTIMO_ERRO=""
_executar _reverter_programa_especifico_biblioteca "$ZIP_ABS"
_checar "reversao individual: pacote com caminho absoluto BARRADO" "1" "$RC"
_checar "reversao individual: recusa menciona bloqueio" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "bloqueada")"
_checar "reversao individual: nada foi extraido (sentinela ausente)" "nao" \
    "$([ -f "$SENTINELA" ] && printf 'sim' || printf 'nao')"

# ---------- _salvar_atualizacao_biblioteca: o portao unico dos 3 fluxos ----------#
# E um subshell: os efeitos dos stubs sao observados por ARQUIVO, nao por
# variavel (variavel setada dentro do subshell se perde no pai).
FLAG_PROCESSOU="${_TMP}/processou.flag"
_processar_atualizacao_biblioteca() { : >"$FLAG_PROCESSOU"; }

# 1. pacote malicioso: precisa abortar ANTES de processar
cp "$ZIP_ABS" "${CFG_PORTALSAV}/prog2026.zip"
rm -f "$FLAG_PROCESSOU"
_ULTIMO_ERRO=""
_executar _salvar_atualizacao_biblioteca
_checar "salvar: pacote com caminho absoluto ABORTADO" "1" "$RC"
_checar "salvar: aborted antes de processar a atualizacao" "nao" \
    "$([ -f "$FLAG_PROCESSOU" ] && printf 'sim' || printf 'nao')"
_checar "salvar: nada foi extraido (sentinela ausente)" "nao" \
    "$([ -f "$SENTINELA" ] && printf 'sim' || printf 'nao')"

# 2. pacote legitimo: o fluxo segue e a atualizacao e processada
cp "$ZIP_OK" "${CFG_PORTALSAV}/prog2026.zip"
rm -f "$FLAG_PROCESSOU"
_executar _salvar_atualizacao_biblioteca
_checar "salvar: pacote legitimo aceito" "0" "$RC"
_checar "salvar: atualizacao processada no caminho feliz" "sim" \
    "$([ -f "$FLAG_PROCESSOU" ] && printf 'sim' || printf 'nao')"

# 3. pacote ausente: precisa abortar
rm -f "${CFG_PORTALSAV}/prog2026.zip"
rm -f "$FLAG_PROCESSOU"
_executar _salvar_atualizacao_biblioteca
_checar "salvar: pacote ausente ABORTADO" "1" "$RC"
_checar "salvar: ausencia nao processou nada" "nao" \
    "$([ -f "$FLAG_PROCESSOU" ] && printf 'sim' || printf 'nao')"

# ---------- _atualizar_biblioteca_offline: a flag offline ----------#
# Bug historico: `if [[ "$CFG_OFFLINE" =~ ^[sn]$ ]]` sem ELSE deixava a
# funcao chegar ao fim e devolver 0 SEM TER FEITO NADA.
FLAG_OFFLINE="${_TMP}/offline.flag"
FLAG_SALVAR="${_TMP}/salvar.flag"
_processar_biblioteca_offline() { : >"$FLAG_OFFLINE"; }
_salvar_atualizacao_biblioteca() { : >"$FLAG_SALVAR"; }
_solicitar_versao_biblioteca() { VERSAO="${VERSAO_TESTE:-2026}"; }

CFG_OFFLINE="x"
rm -f "$FLAG_OFFLINE" "$FLAG_SALVAR"
_executar _atualizar_biblioteca_offline
_checar "offline biblioteca: valor invalido RECUSADO" "1" "$RC"
_checar "offline biblioteca: valor invalido nao processou nada" "nao" \
    "$([ -f "$FLAG_OFFLINE" ] && printf 'sim' || printf 'nao')"

CFG_OFFLINE="s"
rm -f "$FLAG_OFFLINE" "$FLAG_SALVAR"
_executar _atualizar_biblioteca_offline
_checar "offline biblioteca: 's' processa o pacote offline" "0" "$RC"
_checar "offline biblioteca: 's' chamou o processamento offline" "sim" \
    "$([ -f "$FLAG_OFFLINE" ] && printf 'sim' || printf 'nao')"

CFG_OFFLINE="n"
rm -f "$FLAG_OFFLINE" "$FLAG_SALVAR"
_executar _atualizar_biblioteca_offline
_checar "offline biblioteca: 'n' salvou a atualizacao" "0" "$RC"
_checar "offline biblioteca: 'n' chamou _salvar_atualizacao_biblioteca" "sim" \
    "$([ -f "$FLAG_SALVAR" ] && printf 'sim' || printf 'nao')"

# ---------- _atualizar_transpc: valor invalido nao pode cair na REDE ----------#
# Bug historico: com a flag invalida, o `if` sem ELSE era pulado e o fluxo
# seguia para _baixar_biblioteca_sincroniza — atualizacao OFF-LINE disparando
# descarga pela REDE.
FLAG_REDE="${_TMP}/rede.flag"
_baixar_biblioteca_sincroniza() { : >"$FLAG_REDE"; }
_verificar_espaco_disco() { return 0; }

CFG_OFFLINE="x"
rm -f "$FLAG_REDE"
_executar _atualizar_transpc
_checar "transpc: valor invalido RECUSADO" "1" "$RC"
_checar "transpc: valor invalido NAO baixou pela rede" "nao" \
    "$([ -f "$FLAG_REDE" ] && printf 'sim' || printf 'nao')"

CFG_OFFLINE="s"
rm -f "$FLAG_REDE"
_executar _atualizar_transpc
_checar "transpc: 's' orienta usar a opcao offline" "0" "$RC"
_checar "transpc: 's' NAO baixou pela rede" "nao" \
    "$([ -f "$FLAG_REDE" ] && printf 'sim' || printf 'nao')"

VERSAO_TESTE="abc"
_executar _atualizar_transpc
_checar "transpc: versao nao numerica RECUSADA" "1" "$RC"
VERSAO_TESTE="2026"

# ---------- _limpar_interrupcao: so remove o residuo da versao ----------#
VERSAO="2026"
: >"${CFG_PORTALSAV}/prog2026.zip"
: >"${CFG_PORTALSAV}/outro2025.zip"
: >"${CFG_PORTALSAV}/material_do_usuario.txt"
_executar _limpar_interrupcao INT
_checar "cleanup: temporario da versao removido" "nao" \
    "$([ -f "${CFG_PORTALSAV}/prog2026.zip" ] && printf 'sim' || printf 'nao')"
_checar "cleanup: temporario de outra versao preservado" "sim" \
    "$([ -f "${CFG_PORTALSAV}/outro2025.zip" ] && printf 'sim' || printf 'nao')"
_checar "cleanup: material do usuario preservado" "sim" \
    "$([ -f "${CFG_PORTALSAV}/material_do_usuario.txt" ] && printf 'sim' || printf 'nao')"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
