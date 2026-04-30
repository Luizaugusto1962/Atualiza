#!/usr/bin/env bash
#
# constantes.sh - Constantes do Sistema SAV
# Centraliza valores hardcoded para facilitar manutenção
# Padrões e regras de desenvolvimento: ver AGENTS.md

# =============================================================================
# PERMISSÕES DE ARQUIVO E DIRETÓRIO
# =============================================================================
readonly PERM_DIR_SECURE="0755"        # Diretórios seguros (rwxr-xr-x)
readonly PERM_FILE_PRIVATE="0600"      # Arquivos privados (rw-------)
readonly PERM_FILE_EXEC="0755"         # Arquivos executáveis (rwxr-xr-x)

# =============================================================================
# CONFIGURAÇÕES DE REDE
# =============================================================================
readonly DEFAULT_SSH_PORT="41122"          # Porta SSH padrão
readonly DEFAULT_SSH_USER="atualiza"       # Usuário SSH padrão
readonly DEFAULT_IP_SERVER="179.94.20.40"  # IP do servidor padrão
readonly SSH_TIMEOUT="15"                  # Timeout de conexão SSH

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================
readonly HASH_ALGORITHM="sha256sum"    # Algoritmo de hash para senhas
readonly MAX_LOGIN_ATTEMPTS="3"        # Máximo de tentativas de login

# =============================================================================
# CONFIGURAÇÕES DE TIMEOUT
# =============================================================================
readonly DEFAULT_READ_TIMEOUT="30"     # Timeout padrão para leitura de entrada
readonly DEFAULT_PRESS_TIMEOUT="15"    # Timeout padrão para pressionar tecla
readonly SSH_ALIVE_INTERVAL="30"       # Intervalo SSH keep-alive
readonly SSH_ALIVE_COUNT="3"           # Máximo de tentativas SSH keep-alive

# =============================================================================
# CONFIGURAÇÕES DE TERMINAL
# =============================================================================
readonly DEFAULT_COLUMNS="80"          # Largura padrão do terminal
readonly DEFAULT_LINES="24"            # Altura padrão do terminal

# =============================================================================
# EXTENSÕES DE ARQUIVO
# =============================================================================
readonly -a DATA_EXTENSIONS=('*.ARQ.dat' '*.DAT.dat' '*.LOG.dat' '*.PAN.dat')
readonly -a BACKUP_EXTENSIONS=('*.zip' '*.tar' '*.tar.gz')

# =============================================================================
# DIRETÓRIOS PADRÃO
# =============================================================================
readonly DEFAULT_BACKUP_DIR="backup"
readonly DEFAULT_LOGS_DIR="logs"
readonly DEFAULT_CONFIG_DIR="cfg"
readonly DEFAULT_LIBS_DIR="libs"

# =============================================================================
# EXPORTAR CONSTANTES
# =============================================================================
export PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC
export DEFAULT_SSH_PORT DEFAULT_SSH_USER DEFAULT_IP_SERVER SSH_TIMEOUT
export HASH_ALGORITHM MAX_LOGIN_ATTEMPTS
export DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT
export DEFAULT_COLUMNS DEFAULT_LINES
export DATA_EXTENSIONS BACKUP_EXTENSIONS
export DEFAULT_BACKUP_DIR DEFAULT_LOGS_DIR DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR