#!/usr/bin/env bash
set -euo pipefail
#
# Funcao de saida padronizada (local, sem dependencia de modulos)
_encerrar_programa() {
    local status="${1:-0}"
    exit "$status"
}

#
# constantes.sh - Constantes do Sistema SAV
# Centraliza valores hardcoded para facilitar manutencao
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 10/07/2026-01
#
# =============================================================================
# Definir diretorio das bases extras
# =============================================================================
base2=""                     # Diretorio base secundario (vazio se nao definido)
base3=""                     # Diretorio base terciario (vazio se nao definido)

# =============================================================================
# Definir diretorio de trabalho
# =============================================================================
# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# Garantir SCRIPT_DIR com fallback seguro
# RAIZ é o diretório pai de SCRIPT_DIR
# Fallback: se SCRIPT_DIR for a raiz, RAIZ recebe o próprio SCRIPT_DIR
RAIZ="${SCRIPT_DIR%/*}"
[[ -z "$RAIZ" || "$RAIZ" == "$SCRIPT_DIR" ]] && RAIZ="${SCRIPT_DIR}"

# -----------------------------------------------------------------------------
# Carrega configuracao de forma segura sem sourcing direto
# Parametros: $1 - arquivo de configuracao
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_config_seguro() {
    local CONFIG_FILE="${1}"
    local linha key value

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        # Pular linhas vazias e comentarios
        [[ -z "$linha" ]] && continue
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue

        # Remover espacos iniciais
        linha="${linha#"${linha%%[![:space:]]*}"}"

        # Ignorar linhas apos comentario inline
        if [[ "$linha" == *'#'* ]]; then
            linha="${linha%%#*}"
        fi

        # Ignorar se a linha ficou vazia apos remover comentario
        [[ -z "$linha" ]] && continue

        # Extrair chave e valor de forma segura
        if [[ "$linha" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"

            # Remover aspas se presentes
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # Validar que o valor nao contem comandos perigosos
            if [[ "$value" =~ [\$\`\;] ]]; then
                _erro "Valor suspeito encontrado em %s, ignorando linha.\n" "$key" >&2
                continue
            fi

            # Declarar variavel de forma segura
            declare -g "$key=$value"
        fi
    done < "$CONFIG_FILE"

    return 0
}

# =============================================================================
# VALIDACAO DE VARIAVEIS ESSENCIAIS
# =============================================================================

# CFG_DIR deve ter sido definido por principal.sh antes deste sourcing
if [[ -z "${CFG_DIR:-}" ]]; then
    echo "ERRO: CFG_DIR nao esta definido. Certifique-se de carregar principal.sh primeiro." >&2
    if [[ "${BASH_SOURCE[0]:-}" != "${0:-}" ]]; then
        return 1
    fi
    _encerrar_programa 1
fi

# =============================================================================
# CARREGAR CONFIGURACOES DO ARQUIVO .config
# =============================================================================
CONFIG_FILE="${CFG_DIR}/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "AVISO: Arquivo de configuracao $CONFIG_FILE nao encontrado." >&2

    # Definir valores padrao caso o arquivo nao exista
    verclass=""
    acessossh=""
    chavessh=""
    Offline=""
    enviabackup=""
    empresa=""
    base=""
    base2=""
    base3=""

elif [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERRO: Arquivo $CONFIG_FILE sem permissao de leitura." >&2
    if [[ "${BASH_SOURCE[0]:-}" != "${0:-}" ]]; then
        return 1
    fi
    _encerrar_programa 1
else
    if command -v _carregar_config_seguro >/dev/null 2>&1; then
        _carregar_config_seguro "$CONFIG_FILE"
    else
        echo "ERRO: Parser seguro de configuracao nao disponivel. Carregamento bloqueado." >&2
        if [[ "${BASH_SOURCE[0]:-}" != "${0:-}" ]]; then
            return 1
        fi
        _encerrar_programa 1
    fi
fi


# =============================================================================
# CONFIGURACOES DIRETORIO DE BACKUP OFFLINE
# =============================================================================

CFG_PORTALSAV="${CFG_PORTALSAV:-${RAIZ}/portalsav/Atualiza}"  # Diretorio do portal de atualizacao offline

# =============================================================================
# CONFIGURACOES DO SISTEMA (variaveis do .config)
# =============================================================================
CFG_VERSAOCLASS="${CFG_VERSAOCLASS:-${verclass}}"                     # Versao da classe
CFG_EMPRESA="${CFG_EMPRESA:-${empresa}}"                        # Nome da empresa
CFG_BASE_DIR="${CFG_BASE_DIR:-${base}}"                         # Diretorio base principal
CFG_BASE_DIR2="${CFG_BASE_DIR2:-${base2}}"                      # Diretorio base secundario
CFG_BASE_DIR3="${CFG_BASE_DIR3:-${base3}}"                      # Diretorio base terciario (vazio se nao definido)
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-${enviabackup}}"            # Path para envio de backup

# Flags booleanas do sistema
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-${acessossh}}"                # Acesso SSH habilitado (s/n)
CFG_CHAVE_SSH="${CFG_CHAVE_SSH:-${chavessh}}"                   # Caminho da chave SSH privada
CFG_OFFLINE="${CFG_OFFLINE:-${Offline}}"                        # Modo offline (s/n)

# =============================================================================
# PERMISSOES DE ARQUIVO E DIRETORIO
# =============================================================================
PERM_DIR_SECURE="0755"                                          # Diretorios seguros (rwxr-xr-x)
PERM_FILE_PRIVATE="0600"                                        # Arquivos privados 600 (rw-------)
PERM_FILE_EXEC="0755"                                           # Arquivos executaveis (rwxr-xr-x)

# =============================================================================
# CONFIGURACOES DE REDE
# =============================================================================
DEFAULT_IP_SERVER="${DEFAULT_IP_SERVER:-189.55.194.179}"
GITHUB_UPDATE_URL="${GITHUB_UPDATE_URL:-https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip}"
DEFAULT_SSH_PORTA="${DEFAULT_SSH_PORTA:-41122}"
DEFAULT_SSH_USER="${DEFAULT_SSH_USER:-atualiza}"
DEFAULT_CHAVE_SSH="${DEFAULT_CHAVE_SSH:-${HOME}/.ssh/id_rsa_atualiza}"
DEFAULT_CHAVE_SSH_PUB="${DEFAULT_CHAVE_SSH_PUB:-${HOME}/.ssh/id_rsa_atualiza.pub}"
SSH_TIMEOUT="${SSH_TIMEOUT:-15}"

# =============================================================================
# CONFIGURACOES DE SEGURANCA
# =============================================================================
HASH_ALGORITHM="${HASH_ALGORITHM:-sha256sum}"
MAX_LOGIN_ATTEMPTS="${MAX_LOGIN_ATTEMPTS:-3}"

# =============================================================================
# CONFIGURACOES DE TIMEOUT
# =============================================================================
DEFAULT_READ_TIMEOUT="${DEFAULT_READ_TIMEOUT:-60}"
DEFAULT_PRESS_TIMEOUT="${DEFAULT_PRESS_TIMEOUT:-15}"
SSH_ALIVE_INTERVAL="${SSH_ALIVE_INTERVAL:-30}"
SSH_ALIVE_COUNT="${SSH_ALIVE_COUNT:-3}"

# =============================================================================
# CONFIGURACOES DE TERMINAL
# =============================================================================
DEFAULT_COLUMNS="${DEFAULT_COLUMNS:-80}"   # Largura padrao do terminal
DEFAULT_LINES="${DEFAULT_LINES:-24}"       # Altura padrao do terminal

# =============================================================================
# DIRETORIOS PADRAO
# =============================================================================
DEFAULT_CONFIG_DIR="${DEFAULT_CONFIG_DIR:-${SCRIPT_DIR}/configuracoes}"
DEFAULT_LIBS_DIR="${DEFAULT_LIBS_DIR:-${SCRIPT_DIR}/binarios}"
DEFAULT_LOGS_DIR="${DEFAULT_LOGS_DIR:-${SCRIPT_DIR}/logs}"
DEFAULT_BACKUP_DIR="${DEFAULT_BACKUP_DIR:-${SCRIPT_DIR}/backups/anterior}"
DEFAULT_BASEBACKUP_DIR="${DEFAULT_BASEBACKUP_DIR:-${SCRIPT_DIR}/backups/base}"
DEFAULT_BIBLIOTECA_ATUAL_DIR="${DEFAULT_BIBLIOTECA_ATUAL_DIR:-${SCRIPT_DIR}/biblioteca/atual}"
DEFAULT_BIBLIOTECA_DIR="${DEFAULT_BIBLIOTECA_DIR:-${SCRIPT_DIR}/biblioteca/anterior}"
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-${SCRIPT_DIR}/programas/atual}"
DEFAULT_OLDS_DIR="${DEFAULT_OLDS_DIR:-${SCRIPT_DIR}/programas/anterior}"
DEFAULT_ENVIA_DIR="${DEFAULT_ENVIA_DIR:-${SCRIPT_DIR}/enviar}"
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-${SCRIPT_DIR}/receber}"

# =============================================================================
# COMANDOS EXTERNOS PADRAO
# =============================================================================
DEFAULT_UNZIP="${DEFAULT_UNZIP:-/usr/bin/unzip}"
DEFAULT_ZIP="${DEFAULT_ZIP:-/usr/bin/zip}"
DEFAULT_TAR="${DEFAULT_TAR:-tar}"
DEFAULT_FIND="${DEFAULT_FIND:-/usr/bin/find}"
DEFAULT_WHO="${DEFAULT_WHO:-/usr/bin/who}"

# =============================================================================
# DIRETORIOS DE DESTINO
# =============================================================================
DESTINO_SERVER="${DESTINO_SERVER:-/u/varejo/man/}"
DESTINO_BIBLIOTECA="${DESTINO_BIBLIOTECA:-/u/varejo/trans_pc/}"

# =============================================================================
# SAVISC - Diretorio e utilitarios do SAVISC
# =============================================================================
SAVISC="${SAVISC:-${RAIZ}/savisc/iscobol/bin/}"
ISCCLIENT="${ISCCLIENT:-iscclient}"
JUTIL="${JUTIL:-jutil}"
REBUILD="${SAVISC}${JUTIL}"

# =============================================================================
# ACESSO OFFLINE
# =============================================================================
ACESSO_OFF="${ACESSO_OFF:-${RAIZ}/portalsav/Atualiza}"

# =============================================================================
# CONFIGURACAO DE LOGS
# =============================================================================
LOG_ATU="${LOG_ATU:-${DEFAULT_LOGS_DIR}/atualiza.$(date +"%Y-%m-%d").log}"
LOG_LIMPA="${LOG_LIMPA:-${DEFAULT_LOGS_DIR}/limpando.$(date +"%Y-%m-%d").log}"
LOG_TMP="${LOG_TMP:-${DEFAULT_LOGS_DIR}/}"

# Data atual formatada
UMADATA="${UMADATA:-$(date +"%d-%m-%Y_%H%M%S")}"

# =============================================================================
# FUNCOES AUXILIARES
# =============================================================================
VERSAO="${VERSAO:-}"                                               # Variavel que define a versao do programa.
# Arquivo de backup padrao - CORRIGIDO: com aspas
INI="${INI:-backup-${VERSAO}.zip}"

# =============================================================================
# CONFIGURACAO DE TIPO DE COMPILACAO
# =============================================================================
compilado="${compilado:-class}"  # Sufixo para arquivos compilados
debugado="${debugado:-mclass}"   # Sufixo para arquivos em depuracao

# =============================================================================
# EXPORTAR CONSTANTES
# =============================================================================
export SCRIPT_DIR RAIZ LIBS_DIR CFG_DIR
export CFG_VERSAOCLASS CFG_EMPRESA
export CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 CFG_BACKUP_PATH
export CFG_ACESSO_SSH CFG_OFFLINE CFG_CHAVE_SSH
export DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER GITHUB_UPDATE_URL DEFAULT_CHAVE_SSH DEFAULT_CHAVE_SSH_PUB SSH_TIMEOUT
export PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC
export HASH_ALGORITHM MAX_LOGIN_ATTEMPTS
export DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT
export DEFAULT_COLUMNS DEFAULT_LINES
export DEFAULT_BACKUP_DIR DEFAULT_LOGS_DIR DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR
export DEFAULT_BIBLIOTECA_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BASEBACKUP_DIR
export DEFAULT_OLDS_DIR DEFAULT_PROGS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR
export DESTINO_SERVER DESTINO_BIBLIOTECA
export DEFAULT_TAR
export SAVISC ISCCLIENT JUTIL REBUILD
export ACESSO_OFF
export LOG_ATU LOG_LIMPA LOG_TMP UMADATA INI compilado debugado
