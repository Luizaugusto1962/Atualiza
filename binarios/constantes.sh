#!/usr/bin/env bash
#
# constantes.sh - Constantes do Sistema SAV
# Centraliza valores hardcoded para facilitar manutenção
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 16/05/2026-01
#
# NOTA: Este arquivo DEVE ser carregado via source (. constantes.sh)
#       a partir de principal.sh. Nunca executar diretamente.
#
# DEPENDÊNCIAS AMBIENTAIS (definidas por principal.sh antes do sourcing):
#   SCRIPT_DIR  - Diretório onde este script reside
#   LIBS_DIR    - Diretório de módulos/bibliotecas
#   CFG_DIR     - Diretório de configurações
#
# =============================================================================
# IMPORTANTE: NÃO definir set -e / set -u / set -o pipefail aqui.
# Flags de segurança são responsabilidade de principal.sh.
# =============================================================================
#
# Variáveis de configuração (com fallback para valores do .config)
base2="${base2:-}"
base3="${base3:-}"
# =============================================================================
# DIRETÓRIO DO SCRIPT E RAIZ DO PROJETO
# =============================================================================

# Garantir SCRIPT_DIR com fallback seguro
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# RAIZ é o diretório pai de SCRIPT_DIR (ex.: se script está em /app/binarios, RAIZ=/app)
# NOTA: Assume-se que este arquivo está em <RAIZ>/binarios/
#       Se reorganizar o projeto, atualize esta lógica.
RAIZ="${SCRIPT_DIR%/*}"

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
# CAMINHO DO ARQUIVO DE CONFIGURAÇÃO
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
CFG_SISTEMA="${CFG_SISTEMA:-${sistema}}"
CFG_VERCLASS="${CFG_VERCLASS:-${verclass}}"
CFG_EMPRESA="${CFG_EMPRESA:-${empresa}}"
CFG_BASE_DIR="${CFG_BASE_DIR:-${base}}"
CFG_BASE_DIR2="${CFG_BASE_DIR2:-${base2}}"
CFG_BASE_DIR3="${CFG_BASE_DIR3:-${base3}}"
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-${enviabackup}}"

# Flags booleanas do sistema
CFG_USA_DBMAKER="${CFG_USA_DBMAKER:-${dbmaker}}"
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-${acessossh}}"
CFG_OFFLINE="${CFG_OFFLINE:-${Offline}}"

# =============================================================================
# PERMISSÕES DE ARQUIVO E DIRETÓRIO
# =============================================================================
PERM_DIR_SECURE="0755"    # Diretórios seguros (rwxr-xr-x)
PERM_FILE_PRIVATE="0600"  # Arquivos privados (rw-------)
PERM_FILE_EXEC="0755"     # Arquivos executáveis (rwxr-xr-x)

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
DEFAULT_UNZIP="${DEFAULT_UNZIP:-"unzip"}"
DEFAULT_ZIP="${DEFAULT_ZIP:-"zip"}"
DEFAULT_FIND="${DEFAULT_FIND:-"find"}"
DEFAULT_WHO="${DEFAULT_WHO:-"who"}"

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
# CONFIGURACAO DE TIPO DE COMPILACAO
# =============================================================================
CLASS="${CLASS:-}"                              
MCLASS="${MCLASS:-}"                            

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
export DEFAULT_BACKUP_DIR DEFAULT_LOGS_DIR DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR
export DEFAULT_BIBLIOTECA_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BASEBACKUP_DIR
export DEFAULT_OLDS_DIR DEFAULT_PROGS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR
export DESTINO_SERVER DESTINO_BIBLIOTECA
export SAVISC ISCCLIENT JUTIL REBUILD
export ACESSO_OFF
export LOG_ATU LOG_LIMPA LOG_TMP UMDATA CLASS MCLASS