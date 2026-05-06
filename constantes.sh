#!/usr/bin/env bash
#
# constantes.sh - Constantes do Sistema SAV
# Centraliza valores hardcoded para facilitar manutenção
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 05/05/2026-01
#
set -euo pipefail
#


base2=""                     # Diretório base secundário (vazio se não definido)
base3=""                     # Diretório base terciário (vazio se não definido)

# =============================================================================
# Definir diretorio de trabalho
# =============================================================================
RAIZ="${SCRIPT_DIR%/*}"     # Define RAIZ como o diretório pai do script atual (assumindo que o script está em /libs)

# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# =============================================================================
# CARREGAR CONFIGURAÇÕES DO ARQUIVO .config
# =============================================================================
CONFIG_FILE="${CFG_DIR}/.config"

# Carregar variáveis do arquivo de configuração se existir
if [[ -f "$CONFIG_FILE" ]]; then
    # Carrega o arquivo .config e exporta as variáveis
    set -a  # Automaticamente exporta variáveis criadas
    "." "$CONFIG_FILE"
    set +a  # Desativa exportação automática

else
    echo "AVISO: Arquivo de configuração $CONFIG_FILE não encontrado."
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
    
fi

# =============================================================================
# CONFIGURAÇÕES DIRETÓRIO DE BACKUP OFFLINE   
# =============================================================================
enviabackup="${enviabackup:-${RAIZ}/portalsav/Atualiza}"


# =============================================================================
# CONFIGURAÇÕES DO SISTEMA (variáveis do .config)   
# =============================================================================
CFG_SISTEMA="${CFG_SISTEMA:-${sistema}}"                 # Nome do sistema (ex: iscobol, linux)
CFG_VERCLASS="${CFG_VERCLASS:-${verclass}}"              # Versão da classe
CFG_EMPRESA="${CFG_EMPRESA:-${empresa}}"                 # Nome da empresa
CFG_BASE_DIR="${CFG_BASE_DIR:-${base}}"                  # Diretório base principal
CFG_BASE_DIR2="${CFG_BASE_DIR2:-${base2}}"               # Diretório base secundário
CFG_BASE_DIR3="${CFG_BASE_DIR3:-${base3}}"               # Diretório base terciário (vazio se não definido)
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-${enviabackup}}"     # Path para envio de backup

# Flags booleanas do sistema
CFG_USA_DBMAKER="${CFG_USA_DBMAKER:-${dbmaker}}"         # Usa DBMaker (s/n)
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-${acessossh}}"         # Acesso SSH habilitado (s/n)
CFG_OFFLINE="${CFG_OFFLINE:-${Offline}}"                 # Modo offline (s/n)

# =============================================================================
# PERMISSÕES DE ARQUIVO E DIRETÓRIO
# =============================================================================
PERM_DIR_SECURE="0755"                                   # Diretórios seguros (rwxr-xr-x)
PERM_FILE_PRIVATE="0600"                                 # Arquivos privados (rw-------)
PERM_FILE_EXEC="0755"                                    # Arquivos executáveis (rwxr-xr-x)

# =============================================================================
# CONFIGURAÇÕES DE REDE
# =============================================================================
DEFAULT_SSH_PORTA="41122"                                # Porta SSH padrão
DEFAULT_SSH_USER="atualiza"                              # Usuário SSH padrão
DEFAULT_IP_SERVER="179.94.20.40"                         # IP do servidor padrão
SSH_TIMEOUT="15"                                         # Timeout de conexão SSH

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================
HASH_ALGORITHM="sha256sum"                               # Algoritmo de hash para senhas
MAX_LOGIN_ATTEMPTS="3"                                   # Máximo de tentativas de login

# =============================================================================
# CONFIGURAÇÕES DE TIMEOUT
# =============================================================================
DEFAULT_READ_TIMEOUT="30"                                # Timeout padrão para leitura de entrada
DEFAULT_PRESS_TIMEOUT="15"                               # Timeout padrão para pressionar tecla
SSH_ALIVE_INTERVAL="30"                                  # Intervalo SSH keep-alive
SSH_ALIVE_COUNT="3"                                      # Máximo de tentativas SSH keep-alive

# =============================================================================
# CONFIGURAÇÕES DE TERMINAL
# =============================================================================
DEFAULT_COLUMNS="80"                                     # Largura padrão do terminal
DEFAULT_LINES="24"                                       # Altura padrão do terminal

# =============================================================================
# EXTENSÕES DE ARQUIVO
# =============================================================================
DATA_EXTENSIONS=('*.ARQ.dat' '*.DAT.dat' '*.LOG.dat' '*.PAN.dat')
BACKUP_EXTENSIONS=('*.zip' '*.tar' '*.tar.gz')

# =============================================================================
# DIRETÓRIOS PADRÃO
# =============================================================================
DEFAULT_CONFIG_DIR="${CFG_DIR}"                          # Diretório de configuração padrão
DEFAULT_LIBS_DIR="${LIB_DIR}"                            # Diretório de bibliotecas padrão  
DEFAULT_BACKUP_DIR="${SCRIPT_DIR}/backup"                # Diretório de backup padrão
DEFAULT_LOGS_DIR="${SCRIPT_DIR}/logs"                    # Diretório de logs padrão
DEFAULT_BIBLIOTECA_DIR="${SCRIPT_DIR}/biblioteca"        # Diretório de biblioteca padrão
DEFAULT_BASEBACKUP_DIR="${SCRIPT_DIR}/bkbase"            # Diretório de backup de base padrão
DEFAULT_OLDS_DIR="${SCRIPT_DIR}/olds"                    # Diretório de arquivos antigos padrão
DEFAULT_PROGS_DIR="${SCRIPT_DIR}/progs"                  # Diretório de programas padrão
DEFAULT_ENVIA_DIR="${SCRIPT_DIR}/envia"                  # Diretório de envio padrão
DEFAULT_RECEBE_DIR="${SCRIPT_DIR}/recebe"                # Diretório de recebimento padrão

# =============================================================================
# Configurações padrão para comandos externos
# Configuracoes padrao
# =============================================================================
DEFAULT_UNZIP="${DEFAULT_UNZIP:-unzip}"                  # Comando padrao para descompactar
DEFAULT_ZIP="${DEFAULT_ZIP:-zip}"                        # Comando padrao para compactar
DEFAULT_FIND="${DEFAULT_FIND:-find}"                     # Comando padrao para buscar arquivos
DEFAULT_WHO="${DEFAULT_WHO:-who}"                        # Comando padrao para verificar usuarios

# =============================================================================
# Diretorios de destino para diferentes tipos de biblioteca
# =============================================================================
DESTINO_SERVER="/u/varejo/man/"                          # Diretorio do servidor de atualizacao
DESTINO_BIBLIOTECA="/u/varejo/trans_pc/"                 # Diretorio de transporte PC

# =============================================================================
    # Configuracao do diretorio e utilitarios do SAVISC.
# =============================================================================    
SAVISC="${RAIZ}/savisc/iscobol/bin/"                    # Caminho do diretório de instalação do SAVISC

# Utilitarios
ISCCLIENT="iscclient"                                   # Utilitário de comunicação com o servidor ISC

# Caminho completo do jutil
JUTIL="${JUTIL:-jutil}"                                 # Se JUTIL não estiver definido, assume que está no PATH
REBUILD="${SAVISC}${JUTIL}"                             # Caminho completo do rebuild 
  
acessoff="${acessoff:-${RAIZ}/portalsav/Atualiza}"      # Caminho do portal de atualização (usado para verificar acesso offline) 

# =============================================================================
# EXPORTAR CONSTANTES
# =============================================================================
export SCRIPT_DIR LIB_DIR CFG_DIR
export CFG_SISTEMA CFG_VERCLASS CFG_EMPRESA
export CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 CFG_BACKUP_PATH
export CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE
export PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC
export DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER SSH_TIMEOUT
export HASH_ALGORITHM MAX_LOGIN_ATTEMPTS
export DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT
export DEFAULT_COLUMNS DEFAULT_LINES
export DATA_EXTENSIONS BACKUP_EXTENSIONS
export DEFAULT_BACKUP_DIR DEFAULT_LOGS_DIR DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR
export DEFAULT_BIBLIOTECA_DIR DEFAULT_BASEBACKUP_DIR DEFAULT_OLDS_DIR DEFAULT_PROGS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR
export DESTINO_SERVER DESTINO_BIBLIOTECA
export SAVISC ISCCLIENT JUTIL REBUILD
