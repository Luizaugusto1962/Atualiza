#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (DEFAULT_CHAVE_SSH, CFG_CHAVE_SSH, SSH_TIMEOUT,
# ...) sao consumidas pelos modulos que este arquivo carrega com `source`, nao
# pelo proprio script.
set -euo pipefail
#
# testes/test_vaievem.sh - verificacoes isoladas de binarios/vaievem.sh
#
# vaievem.sh monta os comandos de scp/ssh/rsync contra o servidor SAV. A
# superficie de seguranca aqui e a VALIDACAO do que vira opcao de comando:
# usuario/servidor, origem remota, porta/timeout e a protecao de argumento de
# shell (o rsync entrega o valor de -e para um /bin/sh, que no alvo e dash).
#
# Nenhuma conexao de rede e aberta: os testes cobrem so as decisoes.
#
# Rodar direto, sem TTY:
#   bash testes/test_vaievem.sh
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
export LOG_ATU="${_TMP}/logs/test_vaievem.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups_base"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"

PERM_DIR_SECURE=0755
DEFAULT_UNZIP=unzip
DEFAULT_ZIP=zip
DEFAULT_TAR=tar
DEFAULT_FIND="find"
DEFAULT_CHAVE_SSH=""
DEFAULT_IP_SERVER="192.168.0.10"
DEFAULT_SSH_PORTA="22"
DEFAULT_SSH_USER="sav"
SSH_TIMEOUT=15
SSH_ALIVE_INTERVAL=30
SSH_ALIVE_COUNT=3
CFG_CHAVE_SSH="n"

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$DEFAULT_LOGS_DIR" \
    "$DEFAULT_BACKUP_DIR" "$DEFAULT_BASEBACKUP_DIR" "$DEFAULT_PROGS_DIR" \
    "$DEFAULT_PROGS_ATUAL_DIR"

# shellcheck source=../binarios/vaievem.sh
. "${RAIZ_TESTE}/binarios/vaievem.sh"

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
clear() { :; }

# Funcoes que podem NAO existir em versoes antigas do modulo (a prova de
# discriminacao roda a suite contra o codigo antigo): sem este fallback, o
# "command not found" aborta a suite no meio (set -e) em vez de virar uma
# verificacao falhando.
for _fn in _validar_destino_ssh _validar_origem_remota _usar_chave_ssh \
           _proteger_arg_shell _juntar_comando _montar_cmd_scp _montar_cmd_ssh \
           _zip_indice_valido; do
    if ! command -v "$_fn" >/dev/null 2>&1; then
        eval "${_fn}() { return 127; }"
    fi
done

# ---------- _validar_destino_ssh: usuario e servidor ----------#
_checar "destino: par valido aceito" "0" "$(_rc _validar_destino_ssh "sav" "192.168.0.10")"
_checar "destino: hostname aceito" "0" "$(_rc _validar_destino_ssh "sav" "servidor.local")"
_checar "destino: usuario vazio recusado" "1" "$(_rc _validar_destino_ssh "" "192.168.0.10")"
_checar "destino: servidor vazio recusado" "1" "$(_rc _validar_destino_ssh "sav" "")"
_checar "destino: usuario com espaco recusado" "1" "$(_rc _validar_destino_ssh "sa v" "192.168.0.10")"
_checar "destino: usuario com '@' recusado" "1" "$(_rc _validar_destino_ssh "sa@v" "192.168.0.10")"
_checar "destino: usuario com ':' recusado" "1" "$(_rc _validar_destino_ssh "sa:v" "192.168.0.10")"
_checar "destino: usuario com '/' recusado" "1" "$(_rc _validar_destino_ssh "sa/v" "192.168.0.10")"
_checar "destino: usuario com metacaractere recusado" "1" "$(_rc _validar_destino_ssh "sa;v" "192.168.0.10")"
_checar "destino: servidor com '@' recusado" "1" "$(_rc _validar_destino_ssh "sav" "host@extra")"
_checar "destino: servidor com espaco recusado" "1" "$(_rc _validar_destino_ssh "sav" "host name")"
_checar "destino: servidor com metacaractere recusado" "1" "$(_rc _validar_destino_ssh "sav" 'host|cmd')"

# ---------- _validar_origem_remota: "usuario@host:caminho" ----------#
_checar "origem: caminho valido aceito" "0" "$(_rc _validar_origem_remota "sav@192.168.0.10:/u/sav/classes")"
_checar "origem: sem ':' recusada" "1" "$(_rc _validar_origem_remota "sav@192.168.0.10")"
_checar "origem: caminho com traversal recusado" "1" "$(_rc _validar_origem_remota "sav@host:/u/../etc")"
# Caminho absoluto e LEGITIMO no remoto: os caminhos do SAV sao absolutos
# (/u/sav/classes). _validar_caminho_seguro so barra traversal e metacaracteres.
_checar "origem: caminho absoluto ACEITO (caminho do SAV e absoluto)" "0" \
    "$(_rc _validar_origem_remota "sav@host:/etc/passwd")"
_checar "origem: caminho com metacaractere recusado" "1" "$(_rc _validar_origem_remota "sav@host:/u/sav;rm")"
_checar "origem: vazia recusada" "1" "$(_rc _validar_origem_remota "")"

# ---------- _usar_chave_ssh: a decisao de usar chave ----------#
CHAVE=""
CFG_CHAVE_SSH="n"
_checar "chave: flag 'n' nao usa chave" "1" "$(_rc _usar_chave_ssh)"

CFG_CHAVE_SSH="x"
CHAVE=""
_checar "chave: flag invalida nao usa chave" "1" "$(_rc _usar_chave_ssh)"

CFG_CHAVE_SSH="s"
CHAVE=""
_checar "chave: flag 's' sem chave definida nao usa chave" "1" "$(_rc _usar_chave_ssh)"

CHAVE="${_TMP}/chave_inexistente"
_checar "chave: arquivo inexistente nao usa chave" "1" "$(_rc _usar_chave_ssh)"

CHAVE="${_TMP}/chave"
printf 'chave\n' >"$CHAVE"
chmod 600 "$CHAVE"
_checar "chave: arquivo legivel usa chave" "0" "$(_rc _usar_chave_ssh)"

chmod 000 "$CHAVE"
chmod 600 "$CHAVE"

# ---------- _proteger_arg_shell: aspas simples POSIX ----------#
# O rsync entrega o valor de -e para um /bin/sh (dash no alvo). A protecao
# precisa devolver o MESMO texto quando o shell reinterpreta.
_checar "proteger: texto seguro intacto" "abc-123" "$(_proteger_arg_shell "abc-123")"
_checar "proteger: texto com espaco protegido" "'a b'" "$(_proteger_arg_shell "a b")"
_checar "proteger: aspa simples escapada" "'a'\\''b'" "$(_proteger_arg_shell "a'b")"
_checar "proteger: comando protegido" "'rm -rf /'" "$(_proteger_arg_shell "rm -rf /")"
_checar "proteger: substituicao protegida" "'\$(id)'" "$(_proteger_arg_shell '$(id)')"

# o round-trip: o shell reinterpreta e devolve o texto original
_protegido_testes=("a b" "a'b" 'rm -rf /' '$(id)' '`id`' 'x;y' 'a*b')
for valor in "${_protegido_testes[@]}"; do
    protegido="$(_proteger_arg_shell "$valor")"
    voltou="$(eval "printf '%s' $protegido")"
    _checar "proteger: round-trip preserva '${valor}'" "$valor" "$voltou"
done

# ---------- _juntar_comando: a string do -e do rsync ----------#
_checar "juntar: comando simples" "ssh -p 22" "$(_juntar_comando "ssh" "-p" "22")"
_checar "juntar: argumento com espaco protegido" "ssh 'a b'" "$(_juntar_comando "ssh" "a b")"
_checar "juntar: comando com metacaractere protegido" "'rm -rf /'" "$(_juntar_comando "rm -rf /")"
_checar "juntar: sem elementos RECUSA" "1" "$(_rc _juntar_comando)"

# ---------- _montar_cmd_scp: as opcoes numericas ----------#
# A versao do OpenSSH e fixada para o valor do servidor legado (5.9): assim o
# StrictHostKeyChecking sai deterministicamente e o teste nao depende do ssh da
# maquina de desenvolvimento.
_SSH_VERSAO_CACHE="OpenSSH_5.9"
unset _SSH_ACEITAR_NOVO

declare -a CMD_SCP=()
_executar _montar_cmd_scp CMD_SCP 22 15 30 3
_checar "scp: parametros validos aceitos" "0" "$RC"
_checar "scp: comando e scp" "scp" "${CMD_SCP[0]:-}"
_checar "scp: porta publicada" "22" "${CMD_SCP[2]:-}"
_checar "scp: StrictHostKeyChecking vem do helper" "no" \
    "$(printf '%s\n' "${CMD_SCP[@]+"${CMD_SCP[@]}"}" | grep -o 'StrictHostKeyChecking=[a-z-]*' | head -n 1 | cut -d= -f2)"

declare -a CMD_SCP=()
_executar _montar_cmd_scp CMD_SCP "22;rm -rf /" 15 30 3
_checar "scp: porta nao numerica RECUSADA" "1" "$RC"

declare -a CMD_SCP=()
_executar _montar_cmd_scp CMD_SCP 22 "abc" 30 3
_checar "scp: timeout nao numerico RECUSADO" "1" "$RC"

declare -a CMD_SCP=()
_executar _montar_cmd_scp CMD_SCP 22 15 "x" 3
_checar "scp: alive interval nao numerico RECUSADO" "1" "$RC"

declare -a CMD_SCP=()
_executar _montar_cmd_scp "_scp_ref" 22 15 30 3
_checar "scp: nome de array invalido RECUSADO" "1" "$RC"

declare -a CMD_SCP=()
_executar _montar_cmd_scp "" 22 15 30 3
_checar "scp: nome de array vazio RECUSADO" "1" "$RC"

# ---------- _zip_indice_valido: o indice central do ZIP ----------#
_criar_zip_ok() {
    python3 - "$1" <<'PY' || return 1
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("programa/OK.class", "conteudo")
PY
}

ZIP_OK="${_TMP}/ok.zip"
_criar_zip_ok "$ZIP_OK"
_executar _zip_indice_valido "$ZIP_OK"
_checar "zip: indice valido aceito" "0" "$RC"

_executar _zip_indice_valido "${_TMP}/nao_existe.zip"
_checar "zip: arquivo inexistente RECUSADO" "1" "$RC"

printf 'PK' >"${_TMP}/corrompido.zip"
_executar _zip_indice_valido "${_TMP}/corrompido.zip"
_checar "zip: arquivo corrompido RECUSADO" "1" "$RC"

_executar _zip_indice_valido ""
_checar "zip: caminho vazio RECUSADO" "1" "$RC"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
