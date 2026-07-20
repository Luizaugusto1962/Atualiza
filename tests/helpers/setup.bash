setup_safe_env() {
    local tmpdir="/tmp/sandbox-$$"
    rm -rf "$tmpdir" 2>/dev/null || true
    mkdir -p "$tmpdir/config" "$tmpdir/logs" "$tmpdir/backups"

    local source_dir
    source_dir="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

    export CFG_DIR="$tmpdir/config"
    export SCRIPT_DIR="$tmpdir"
    export RAIZ="$tmpdir"
    export LIBS_DIR="${source_dir}/binarios"
    export DEFAULT_LOGS_DIR="$tmpdir/logs"
    export DEFAULT_BACKUP_DIR="$tmpdir/backups"
    export DEFAULT_BASEBACKUP_DIR="$tmpdir/backups/base"
    export DEFAULT_OLDS_DIR="$tmpdir/olds"
    export DEFAULT_PROGS_DIR="$tmpdir/programs"
    export DEFAULT_ENVIA_DIR="$tmpdir/enviar"
    export DEFAULT_RECEBE_DIR="$tmpdir/receber"
    export DEFAULT_BIBLIOTECA_DIR="$tmpdir/biblioteca/anterior"
    export DEFAULT_BIBLIOTECA_ATUAL_DIR="$tmpdir/biblioteca/atual"
    export DEFAULT_CONFIG_DIR="$tmpdir/config"
    export DEFAULT_LIBS_DIR="$tmpdir/binarios"
    export E_EXEC="$tmpdir/classes"
    export T_TELAS="$tmpdir/tel_isc"
    export LOG_ATU="$tmpdir/logs/atualiza.test.log"
    export LOG_LIMPA="$tmpdir/logs/limpando.test.log"
    export LOG_TMP="$tmpdir/logs/"
    export UMADATA="01-01-2026_120000"
    export VERSAO=""
    export CFG_VERSAOCLASS=""
    export CFG_EMPRESA="TESTE"
    export CFG_BASE_DIR=""
    export CFG_BASE_DIR2=""
    export CFG_BASE_DIR3=""
    export CFG_ACESSO_SSH="n"
    export CFG_OFFLINE="n"
    export CFG_CHAVE_SSH=""
    export CFG_BACKUP_PATH=""
    export compilado="class"
    export debugado="mclass"
    export SAVATU="tempSAV_IS_*_"
    export SAVATU1="tempSAV_IS_classA_"
    export SAVATU2="tempSAV_IS_classB_"
    export SAVATU3="tempSAV_IS_classC_"
    export SAVISC="$tmpdir/savisc/iscobol/bin/"
    export ISCCLIENT="iscclient"
    export JUTIL="jutil"
    export REBUILD="${SAVISC}${JUTIL}"
    export DEFAULT_ZIP="zip"
    export DEFAULT_UNZIP="unzip"
    export DEFAULT_TAR="tar"
    export DEFAULT_FIND="find"
    export DEFAULT_WHO="who"
    export NORMAL=""
    export VERMELHO=""
    export VERDE=""
    export AMARELO=""
    export AZUL=""
    export ROXO=""
    export CIANO=""
    export BRANCO=""
    export COLUNAS="80"
    export PERM_DIR_SECURE="0755"
    export PERM_FILE_PRIVATE="0600"
    export PERM_FILE_EXEC="0755"
    export HASH_ALGORITHM="sha256sum"
    export MAX_LOGIN_ATTEMPTS="3"
    export DEFAULT_READ_TIMEOUT="60"
    export DEFAULT_PRESS_TIMEOUT="15"
    export DEFAULT_SSH_PORTA="22"
    export DEFAULT_IP_SERVER="192.168.1.1"
    export DEFAULT_SSH_USER="test"
    export DEFAULT_CHAVE_SSH="$tmpdir/.ssh/id_rsa"
    export DEFAULT_CHAVE_SSH_PUB="$tmpdir/.ssh/id_rsa.pub"
    export GITHUB_UPDATE_URL="https://github.com/test/Atualiza/archive/main.zip"
    export DESTINO_SERVER="/u/varejo/man/"
    export DESTINO_BIBLIOTECA="/u/varejo/trans_pc/"
    export PERM_DIR_SECURE="0755"
    export PERM_FILE_PRIVATE="0600"
    export PERM_FILE_EXEC="0755"
    export SSH_TIMEOUT="15"
    export SSH_ALIVE_INTERVAL="30"
    export SSH_ALIVE_COUNT="3"
    export DEFAULT_COLUMNS="80"
    export DEFAULT_LINES="24"
    export ACESSO_OFF="$tmpdir/portalsav/Atualiza"
    export CFG_PORTALSAV="$tmpdir/portalsav/Atualiza"
    export SAVISC="$tmpdir/savisc/iscobol/bin/"
    export HASH_ALGORITHM="sha256sum"

    mkdir -p "$E_EXEC" "$T_TELAS" "$DEFAULT_BACKUP_DIR" "$DEFAULT_BASEBACKUP_DIR"
    mkdir -p "$DEFAULT_OLDS_DIR" "$DEFAULT_PROGS_DIR" "$DEFAULT_ENVIA_DIR"
    mkdir -p "$DEFAULT_RECEBE_DIR" "$DEFAULT_BIBLIOTECA_DIR"
    mkdir -p "$DEFAULT_BIBLIOTECA_ATUAL_DIR" "$DEFAULT_LOGS_DIR"
    mkdir -p "${HOME}/.ssh" 2>/dev/null || true
}

tput() {
    case "${1:-}" in
        cols) echo 80 ;;
        lines) echo 24 ;;
        *) return 0 ;;
    esac
}

sha256sum() {
    local input
    input=$(cat)
    printf '%s  -\n' "$(printf '%s' "$input" | openssl dgst -sha256 2>/dev/null | cut -d' ' -f2 || echo "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")"
}

command() {
    case "${1:-}" in
        -v)
            case "$2" in
                tput|sha256sum|find|df|stat|date|who|curl|apt|yum|dnf|pacman|zypper|zip|unzip|tar|basename|dirname)
                    return 0 ;;
            esac
            builtin command "$@" 2>/dev/null && return 0 || return 1
            ;;
        *) builtin command "$@" ;;
    esac
}

find() {
    if [[ "$*" == *" -ctime -2"* ]]; then
        return 1
    fi
    /usr/bin/find "$@" 2>/dev/null || return 0
}

df() {
    printf "Filesystem\n/dev/sda1 10485760 5242880 5242880 50%% /\n"
}

stat() {
    if [[ "$1" == "-c%s" ]]; then
        echo "1024"
    elif [[ "$1" == "-c%a" ]]; then
        echo "600"
    else
        echo "$(date)"
    fi
}

date() {
    if [[ "$1" == +* ]]; then
        printf "20260101"
    elif [[ "$1" == "-d" ]]; then
        if [[ "$3" == +* ]]; then
            printf "20260101"
        fi
        printf "2026-01-01"
    else
        printf "2026-01-01"
    fi
}

who() { printf "testuser  pts/0  2026-01-01 08:00\n"; }

_encerrar_programa() { return "${1:-0}"; }

_aguardar() { :; }
_aguardar_tecla() { :; }
_erro() { printf "ERRO: %s\n" "$*" >&2; }
_aviso() { printf "AVISO: %s\n" "$*" >&2; }
_ok() { printf "OK: %s\n" "$*"; }
_msg() { printf "MSG: %s\n" "$*"; }
_mensagec() { printf "%s\n" "${2:-}"; }
_exibir_mensagem_centralizada() { printf "%s\n" "${2:-}"; }
_linha() { :; }
_meia_linha() { :; }
_limpa_tela() { :; }
_meio_da_tela() { :; }
_opinvalida() { :; }
_log() { :; }
_log_erro() { :; }
_log_sucesso() { :; }
_ssh_aceitar_novo() { printf 'yes'; }
_criar_diretorio_seguro() { mkdir -p "$1" 2>/dev/null || true; }
_validar_caminho_seguro() { return 0; }
_usar_chave_ssh() { return 1; }
_confirmar() { return 0; }
_nl() { printf '\n'; }
