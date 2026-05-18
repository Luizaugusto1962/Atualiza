#!/usr/bin/env bash
#
# variaveis.sh - Exibe todas as constantes do sistema SAV
## SISTEMA SAV - Script de Atualizacao Modular
# Versao: 16/05/2026-01
# Uso: ./variaveis.sh [filtro]
#
# =============================================================================
# CONFIGURACAO INICIAL
# =============================================================================

set -o pipefail

# Determinar diretorio do script de forma robusta
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# =============================================================================
# VARIAVEIS DE CONFIGURACAO
# =============================================================================

# Diretorios
LIBS_DIR="${LIBS_DIR:-${SCRIPT_DIR}/binarios}"
CFG_DIR="${CFG_DIR:-${SCRIPT_DIR}/configuracoes}"
CONFIG_FILE="${CONFIG_FILE:-${CFG_DIR}/.config}"

# Cores (definidas uma vez para evitar subshells repetidos)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"
    GREEN="${BOLD}$(tput setaf 2)"
    YELLOW="${BOLD}$(tput setaf 3)"
    RED="${BOLD}$(tput setaf 1)"
    NORM="$(tput sgr0)"
else
    BOLD="" GREEN="" YELLOW="" RED="" NORM=""
fi

# Colunas do terminal
COLUMNS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

# =============================================================================
# DEFINICAO DE CONSTANTES POR CATEGORIA
# =============================================================================
declare -A CATEGORIAS=(
    ["DIRETORIOS E CAMINHOS"]="RAIZ SCRIPT_DIR LIBS_DIR CFG_DIR CONFIG_FILE"
    ["CONFIGURACOES DO SISTEMA"]="CFG_SISTEMA CFG_VERCLASS CFG_EMPRESA"
    ["BASES DE DADOS"]="CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3"
    ["FLAGS BOOLEANAS"]="CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE"
    ["PERMISSOES DE ARQUIVO E DIRETORIO"]="PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC"
    ["CONFIGURACOES DE REDE"]="DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER SSH_TIMEOUT"
    ["CONFIGURACOES DE SEGURANCA"]="HASH_ALGORITHM MAX_LOGIN_ATTEMPTS"
    ["CONFIGURACOES DE TIMEOUT"]="DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT"
    ["CONFIGURACOES DE TERMINAL"]="DEFAULT_COLUMNS DEFAULT_LINES"
    ["DIRETORIOS PADRAO"]="DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR DEFAULT_LOGS_DIR DEFAULT_BACKUP_DIR DEFAULT_BASEBACKUP_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BIBLIOTECA_DIR DEFAULT_PROGS_DIR DEFAULT_OLDS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR"
    ["COMANDOS EXTERNOS PADRAO"]="DEFAULT_UNZIP DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO"
    ["DIRETORIOS DE DESTINO"]="DESTINO_SERVER DESTINO_BIBLIOTECA"
    ["SAVISC - DIRETORIO E UTILITARIOS"]="SAVISC ISCCLIENT JUTIL REBUILD"
    ["ACESSO OFFLINE"]="ACESSO_OFF CFG_BACKUP_PATH"
    ["CONFIGURACAO DE LOGS"]="LOG_ATU LOG_LIMPA LOG_TMP UMADATA"
)

# =============================================================================
# FUNCAO: Carregar arquivo de configuracao
# =============================================================================
carregar_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]] && [[ -r "$config_file" ]]; then
        # Exporta automaticamente variaveis do arquivo
        set -a
        # shellcheck source=/dev/null
        . "$config_file"
        local status=$?
        set +a

        return $status
    fi

    return 1
}

# =============================================================================
# FUNCAO: Carregar constantes do sistema
# =============================================================================
carregar_constantes() {
    local constantes_file="${LIBS_DIR}/constantes.sh"

    if [[ -f "$constantes_file" ]] && [[ -r "$constantes_file" ]]; then
        # shellcheck source=/dev/null
        . "$constantes_file"
        return $?
    fi

    return 1
}

# =============================================================================
# FUNCAO: Verificar dependencias
# =============================================================================
verificar_dependencias() {
    local deps=("printf" "basename" "dirname" "cd" "pwd")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "%s[ERRO] Dependencias faltando: %s%s\n" "$RED" "${missing[*]}" "$NORM" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# FUNCAO: Obter valor de uma variavel com fallback
# =============================================================================
obter_valor() {
    local var_name="$1"
    local valor

    # Usar eval para obter o valor da variavel
    valor="${!var_name}"

    if [[ -z "$valor" ]]; then
        echo "NAO DEFINIDO"
    else
        echo "$valor"
    fi
}

# =============================================================================
# FUNCAO: Exibir constantes em formato tabular
# =============================================================================
exibir_tabular() {
    local filtro="$1"

    printf "\n"
    printf "%s\n" "CONSTANTES DO SISTEMA SAV - LISTAGEM COMPLETA"
    printf "\n"

    # Exibir informacoes sobre o arquivo de configuracao
    printf "%s%s Fonte de Configuracao:%s\n" "$GREEN" "$BOLD" "$NORM"
    if [[ -f "$CONFIG_FILE" ]] && [[ -r "$CONFIG_FILE" ]]; then
        printf "   %s Arquivo: \n" "$GREEN" "$NORM" "$CONFIG_FILE"
        printf "   %s Status: Carregado com sucesso\n" "$GREEN" "$NORM" "$CONFIG_FILE"
    else
        printf "   %s Arquivo: \n" "$YELLOW" "$NORM" "$CONFIG_FILE"
        printf "   %s Status: Nao encontrado (usando valores padrao)\n" "$YELLOW" "$NORM" "$CONFIG_FILE"
    fi
    printf "\n"

    # Cabecalho da tabela
    printf "%s%-35s%s %s\n" "$GREEN" "VARIAVEL" "$NORM" "VALOR"
    printf "%-35s %s\n" "$(printf '%.0s-' {1..35})" "$(printf '%.0s-' {1..60})"

    # Iterar sobre as categorias
    for categoria in "${!CATEGORIAS[@]}"; do
        # Se ha filtro, verificar se a categoria corresponde
        if [[ -n "$filtro" ]]; then
            # Comparacao case-insensitive
            local cat_lower="${categoria,,}"
            local filtro_lower="${filtro,,}"
            if [[ ! "$cat_lower" =~ $filtro_lower ]]; then
                continue
            fi
        fi

        printf "\n%s%s[%s]%s\n" "$YELLOW" "$BOLD" "$categoria" "$NORM"

        # shellcheck disable=SC2086
        for variavel in ${CATEGORIAS[$categoria]}; do
            local valor
            valor=$(obter_valor "$variavel")
            printf "%-35s %s\n" "$variavel" "$valor"
        done
    done

    printf "\n"
}

# =============================================================================
# FUNCAO: Main
# =============================================================================
main() {

    local filtro="$1"

    # Verificar dependencias
    if ! verificar_dependencias; then
        exit 1
    fi

    # Carregar configuracao
    if ! carregar_config "$CONFIG_FILE"; then
        printf "%s[AVISO] Arquivo de configuracao nao encontrado em: %s%s\n" "$YELLOW" "$CONFIG_FILE" "$NORM" >&2
        printf "%s[AVISO] Usando valores padrao...%s\n\n" "$YELLOW" "$NORM" >&2
    fi

    # Carregar constantes
    if ! carregar_constantes; then
        printf "%s[AVISO] Arquivo de constantes nao encontrado em: %s%s\n" "$YELLOW" "${LIBS_DIR}/constantes.sh" "$NORM" >&2
    fi

    # Exibir constantes
    exibir_tabular "$filtro"
}

# =============================================================================
# EXECUCAO
# =============================================================================

main "$@"