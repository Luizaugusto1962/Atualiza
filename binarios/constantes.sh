#!/usr/bin/env bash
#
# constantes.sh - Constantes do Sistema SAV
# Centraliza valores hardcoded para facilitar manutenção
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 20/05/2026-01
#

# =============================================================================
# Definir diretorio das bases extras
# =============================================================================
base2=""                     # Diretório base secundário (vazio se não definido)
base3=""                     # Diretório base terciário (vazio se não definido)

# =============================================================================
# Definir diretorio de trabalho
# =============================================================================
# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# Garantir SCRIPT_DIR com fallback seguro
RAIZ="${SCRIPT_DIR%/*}"     # Define RAIZ como o diretório pai do script atual (assumindo que o script está em /binarios)

# =============================================================================
# VALIDAÇÃO DE VARIÁVEIS ESSENCIAIS
# =============================================================================

# CFG_DIR deve ter sido definido por principal.sh antes deste sourcing
if [[ -z "${CFG_DIR:-}" ]]; then
    echo "ERRO: CFG_DIR não está definido. Certifique-se de carregar principal.sh primeiro." >&2
    if [[ "${BASH_SOURCE[0]:-}" != "${0:-}" ]]; then
        return 1
    else
        exit 1
    fi
fi

# =============================================================================
# CARREGAR CONFIGURAÇÕES DO ARQUIVO .config
# =============================================================================
CONFIG_FILE="${CFG_DIR}/.config"

# =============================================================================
# CARREGAR CONFIGURAÇÕES DO ARQUIVO .config
# =============================================================================
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "AVISO: Arquivo de configuração $CONFIG_FILE não encontrado." >&2

    # Definir valores padrão caso o arquivo não exista
    sistema=""
    verclass=""
    dbmaker=""
    acessossh=""
    Offline=""
    enviabackup=""
    empresa=""
    base=""
    base2=""
    base3=""

elif [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERRO: Arquivo $CONFIG_FILE sem permissão de leitura." >&2
    if [[ "${BASH_SOURCE[0]:-}" != "${0:-}" ]]; then
        return 1
    else
        exit 1
    fi
else
    set -a  # Exporta automaticamente variáveis criadas
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
    set +a
fi


# =============================================================================
# CONFIGURAÇÕES DIRETÓRIO DE BACKUP OFFLINE   
# =============================================================================
enviabackup="${enviabackup:-${RAIZ}/portalsav/Atualiza}"


# =============================================================================
# CONFIGURAÇÕES DO SISTEMA (variáveis do .config)   
# =============================================================================
CFG_SISTEMA="${CFG_SISTEMA:-${sistema}}"                        # Nome do sistema (ex: iscobol, linux)
CFG_VERCLASS="${CFG_VERCLASS:-${verclass}}"                     # Versão da classe
CFG_EMPRESA="${CFG_EMPRESA:-${empresa}}"                        # Nome da empresa
CFG_BASE_DIR="${CFG_BASE_DIR:-${base}}"                         # Diretório base principal
CFG_BASE_DIR2="${CFG_BASE_DIR2:-${base2}}"                      # Diretório base secundário
CFG_BASE_DIR3="${CFG_BASE_DIR3:-${base3}}"                      # Diretório base terciário (vazio se não definido)
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-${enviabackup}}"            # Path para envio de backup

# Flags booleanas do sistema
CFG_USA_DBMAKER="${CFG_USA_DBMAKER:-${dbmaker}}"                # Usa DBMaker (s/n)
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-${acessossh}}"                # Acesso SSH habilitado (s/n)
CFG_OFFLINE="${CFG_OFFLINE:-${Offline}}"                        # Modo offline (s/n)

# =============================================================================
# PERMISSÕES DE ARQUIVO E DIRETÓRIO
# =============================================================================
PERM_DIR_SECURE="0755"                                          # Diretórios seguros (rwxr-xr-x)
PERM_FILE_PRIVATE="0600"                                        # Arquivos privados (rw-------)
PERM_FILE_EXEC="0755"                                           # Arquivos executáveis (rwxr-xr-x)

# =============================================================================
# CONFIGURAÇÕES DE REDE
# =============================================================================
DEFAULT_SSH_PORTA="${DEFAULT_SSH_PORTA:-41122}"
DEFAULT_SSH_USER="${DEFAULT_SSH_USER:-atualiza}"
DEFAULT_IP_SERVER="${DEFAULT_IP_SERVER:-179.94.20.40}"
SSH_TIMEOUT="${SSH_TIMEOUT:-15}"

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================
HASH_ALGORITHM="${HASH_ALGORITHM:-sha256sum}"
MAX_LOGIN_ATTEMPTS="${MAX_LOGIN_ATTEMPTS:-3}"

# =============================================================================
# CONFIGURAÇÕES DE TIMEOUT
# =============================================================================
DEFAULT_READ_TIMEOUT="${DEFAULT_READ_TIMEOUT:-60}"
DEFAULT_PRESS_TIMEOUT="${DEFAULT_PRESS_TIMEOUT:-15}"
SSH_ALIVE_INTERVAL="${SSH_ALIVE_INTERVAL:-30}"
SSH_ALIVE_COUNT="${SSH_ALIVE_COUNT:-3}"

# =============================================================================
# CONFIGURAÇÕES DE TERMINAL
# =============================================================================
DEFAULT_COLUMNS="${DEFAULT_COLUMNS:-80}"   # Largura padrão do terminal
DEFAULT_LINES="${DEFAULT_LINES:-24}"       # Altura padrão do terminal

# =============================================================================
# DIRETÓRIOS PADRÃO
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
# COMANDOS EXTERNOS PADRÃO
# =============================================================================
DEFAULT_UNZIP="${DEFAULT_UNZIP:-unzip}"
DEFAULT_ZIP="${DEFAULT_ZIP:-zip}"
DEFAULT_FIND="${DEFAULT_FIND:-find}"
DEFAULT_WHO="${DEFAULT_WHO:-who}"
DEFAULT_TAR="${DEFAULT_TAR:-tar}"
# =============================================================================
# DIRETÓRIOS DE DESTINO
# =============================================================================
DESTINO_SERVER="${DESTINO_SERVER:-/u/varejo/man/}"
DESTINO_BIBLIOTECA="${DESTINO_BIBLIOTECA:-/u/varejo/trans_pc/}"

# =============================================================================
# SAVISC - Diretório e utilitários do SAVISC
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
# CONFIGURAÇÃO DE LOGS
# =============================================================================
LOG_ATU="${LOG_ATU:-${DEFAULT_LOGS_DIR}/atualiza.$(date +"%Y-%m-%d").log}"
LOG_LIMPA="${LOG_LIMPA:-${DEFAULT_LOGS_DIR}/limpando.$(date +"%Y-%m-%d").log}"
LOG_TMP="${LOG_TMP:-${DEFAULT_LOGS_DIR}/}"

# Data atual formatada
UMADATA="${UMADATA:-$(date +"%d-%m-%Y_%H%M%S")}"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================
VERSAO="${VERSAO:-}"                                               # Variavel que define a versao do programa.
# Arquivo de backup padrao - CORRIGIDO: com aspas
INI="${INI:-backup-${VERSAO}.zip}"

# =============================================================================
# CONFIGURACAO DE TIPO DE COMPILACAO
# =============================================================================
#class="${class:-}"          # Sufixo para arquivos de classe
#mclass="${mclass:-}"        # Sufixo para arquivos de classe de depuracao                           
compilado="${compilado:-class}"  # Sufixo para arquivos compilados
debugado="{debugado:-mclass}"     # Sufixo para arquivos em depuração
# =============================================================================
# EXPORTAR CONSTANTES
# =============================================================================
export SCRIPT_DIR RAIZ LIBS_DIR CFG_DIR
export CFG_SISTEMA CFG_VERCLASS CFG_EMPRESA
export CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 CFG_BACKUP_PATH
export CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE
export PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC
export DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER SSH_TIMEOUT
export HASH_ALGORITHM MAX_LOGIN_ATTEMPTS
export DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT
export DEFAULT_COLUMNS DEFAULT_LINES
export DEFAULT_BACKUP_DIR DEFAULT_LOGS_DIR DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR DEFAULT_TAR
export DEFAULT_BIBLIOTECA_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BASEBACKUP_DIR
export DEFAULT_OLDS_DIR DEFAULT_PROGS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR
export DESTINO_SERVER DESTINO_BIBLIOTECA
export SAVISC ISCCLIENT JUTIL REBUILD
export ACESSO_OFF
export LOG_ATU LOG_LIMPA LOG_TMP UMDATA INI class mclass compilado debugado 
