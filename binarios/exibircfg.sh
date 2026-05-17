#!/usr/bin/env bash
#
# exibircfg.sh - Exibe todas as constantes do sistema SAV
# Saída em formato tabular
#
# Uso: ./exibircfg.sh [filtro]
#
# =============================================================================
# CONFIGURAÇÃO INICIAL
# =============================================================================

set -o pipefail

# Determinar diretório do script de forma robusta
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# =============================================================================
# VARIÁVEIS DE CONFIGURAÇÃO
# =============================================================================

# Diretórios
LIBS_DIR="${LIBS_DIR:-${SCRIPT_DIR}/binarios}"
CFG_DIR="${CFG_DIR:-${SCRIPT_DIR}/configuracoes}"
CONFIG_FILE="${CONFIG_FILE:-${CFG_DIR}/.config}"

# Cores (definidas uma vez para evitar subshells repetidos)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"
    GREEN="${BOLD}$(tput setaf 2)"
    YELLOW="${BOLD}$(tput setaf 3)"
    BLUE="${BOLD}$(tput setaf 4)"
    RED="${BOLD}$(tput setaf 1)"
    NORM="$(tput sgr0)"
else
    BOLD="" GREEN="" YELLOW="" BLUE="" RED="" NORM=""
fi

# Colunas do terminal
COLUMNS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

# =============================================================================
# DEFINIÇÃO DE CONSTANTES POR CATEGORIA
# =============================================================================
declare -A CATEGORIAS=(
    ["DIRETÓRIOS E CAMINHOS"]="RAIZ SCRIPT_DIR LIBS_DIR CFG_DIR CONFIG_FILE"
    ["CONFIGURAÇÕES DO SISTEMA"]="CFG_SISTEMA CFG_VERCLASS CFG_EMPRESA"
    ["BASES DE DADOS"]="CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3"
    ["FLAGS BOOLEANAS"]="CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE"
    ["PERMISSÕES DE ARQUIVO E DIRETÓRIO"]="PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC"
    ["CONFIGURAÇÕES DE REDE"]="DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER SSH_TIMEOUT"
    ["CONFIGURAÇÕES DE SEGURANÇA"]="HASH_ALGORITHM MAX_LOGIN_ATTEMPTS"
    ["CONFIGURAÇÕES DE TIMEOUT"]="DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT"
    ["CONFIGURAÇÕES DE TERMINAL"]="DEFAULT_COLUMNS DEFAULT_LINES"
    ["DIRETÓRIOS PADRÃO"]="DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR DEFAULT_LOGS_DIR DEFAULT_BACKUP_DIR DEFAULT_BASEBACKUP_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BIBLIOTECA_DIR DEFAULT_PROGS_DIR DEFAULT_OLDS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR"
    ["COMANDOS EXTERNOS PADRÃO"]="DEFAULT_UNZIP DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO"
    ["DIRETÓRIOS DE DESTINO"]="DESTINO_SERVER DESTINO_BIBLIOTECA"
    ["SAVISC - DIRETÓRIO E UTILITÁRIOS"]="SAVISC ISCCLIENT JUTIL REBUILD"
    ["ACESSO OFFLINE"]="ACESSO_OFF CFG_BACKUP_PATH"
    ["CONFIGURAÇÃO DE LOGS"]="LOG_ATU LOG_LIMPA LOG_TMP UMADATA"
)

# =============================================================================
# FUNÇÃO: Carregar arquivo de configuração
# =============================================================================
carregar_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]] && [[ -r "$config_file" ]]; then
        # Exporta automaticamente variáveis do arquivo
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
# FUNÇÃO: Carregar constantes do sistema
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
# FUNÇÃO: Verificar dependências
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
# FUNÇÃO: Obter valor de uma variável com fallback
# =============================================================================
obter_valor() {
    local var_name="$1"
    local valor

    # Usar eval para obter o valor da variável
    valor="${!var_name}"

    if [[ -z "$valor" ]]; then
        echo "NÃO DEFINIDO"
    else
        echo "$valor"
    fi
}

# =============================================================================
# FUNÇÃO: Exibir constantes em formato tabular
# =============================================================================
exibir_tabular() {
    local filtro="$1"

    printf "\n"
    printf "%s        CONSTANTES DO SISTEMA SAV - LISTAGEM COMPLETA           \n" "$BLUE" "$BOLD" "$NORM"
    printf "\n"

    # Exibir informações sobre o arquivo de configuração
    printf "%s%s Fonte de Configuracao:%s\n" "$GREEN" "$BOLD" "$NORM"
    if [[ -f "$CONFIG_FILE" ]] && [[ -r "$CONFIG_FILE" ]]; then
        printf "   %s Arquivo: \n" "$GREEN" "$NORM" "$CONFIG_FILE"
        printf "   %s Status: Carregado com sucesso\n" "$GREEN" "$NORM" "$CONFIG_FILE"
    else
        printf "   %s Arquivo: \n" "$YELLOW" "$NORM" "$CONFIG_FILE"
        printf "   %s Status: Não encontrado (usando valores padrão)\n" "$YELLOW" "$NORM" "$CONFIG_FILE"
    fi
    printf "\n"

    # Cabeçalho da tabela
    printf "%s%-35s%s %s\n" "$GREEN" "VARIÁVEL" "$NORM" "VALOR"
    printf "%-35s %s\n" "$(printf '%.0s-' {1..35})" "$(printf '%.0s-' {1..60})"

    # Iterar sobre as categorias
    for categoria in "${!CATEGORIAS[@]}"; do
        # Se há filtro, verificar se a categoria corresponde
        if [[ -n "$filtro" ]]; then
            # Comparação case-insensitive
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
# FUNÇÃO: Main
# =============================================================================
main() {
    local filtro="$1"

    # Verificar dependências
    if ! verificar_dependencias; then
        exit 1
    fi

    # Carregar configuração
    if ! carregar_config "$CONFIG_FILE"; then
        printf "%s[AVISO] Arquivo de configuração não encontrado em: %s%s\n" "$YELLOW" "$CONFIG_FILE" "$NORM" >&2
        printf "%s[AVISO] Usando valores padrão...%s\n\n" "$YELLOW" "$NORM" >&2
    fi

    # Carregar constantes
    if ! carregar_constantes; then
        printf "%s[AVISO] Arquivo de constantes não encontrado em: %s%s\n" "$YELLOW" "${LIBS_DIR}/constantes.sh" "$NORM" >&2
    fi

    # Exibir constantes
    exibir_tabular "$filtro"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

main "$@"