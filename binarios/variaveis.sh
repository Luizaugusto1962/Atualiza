#!/usr/bin/env bash
#
# variaveis.sh - Modulo de consulta de variaveis/constantes do sistema SAV
## SISTEMA SAV - Script de Atualizacao Modular
# Versao: 16/06/2026-01
#
# Este modulo e carregado via source por principal.sh (_carregar_modulos).
# Ponto de entrada publico: _consultar_variaveis [filtro]
# Uso pelo menu: opcao "Consultar Variaveis" no Menu das Configuracoes.
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# NOTA: Todas as funcoes usam prefixo _var_ para evitar colisao de nomes
#       com outros modulos carregados no mesmo shell.
#

# =============================================================================
# CONFIGURACAO INICIAL (apenas se ainda nao definida por modulos anteriores)
# =============================================================================
# Evita redefinir variaveis ja estabelecidas por constantes.sh / config.sh

SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"
LIBS_DIR="${LIBS_DIR:-${SCRIPT_DIR}/binarios}"
CFG_DIR="${CFG_DIR:-${SCRIPT_DIR}/configuracoes}"
CONFIG_FILE="${CONFIG_FILE:-${CFG_DIR}/.config}"

# Cores do terminal - reaproveitar se ja definidas por utils.sh/constantes.sh
if [[ -z "${BOLD:-}" ]]; then
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        BOLD="$(tput bold)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        RED="${BOLD}$(tput setaf 1)"
        NORM="$(tput sgr0)"
    else
        BOLD="" GREEN="" YELLOW="" RED="" NORM=""
    fi
fi

# Colunas do terminal
COLUMNS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

# =============================================================================
# DEFINICAO DE CONSTANTES POR CATEGORIA
# Estrutura usada pela listagem tabular do modulo.
# =============================================================================
declare -gA _VAR_CATEGORIAS=(
    ["DIRETORIOS E CAMINHOS"]="RAIZ SCRIPT_DIR LIBS_DIR CFG_DIR CONFIG_FILE"
    ["CONFIGURACOES DO SISTEMA"]="CFG_SISTEMA CFG_VERCLASS CFG_EMPRESA"
    ["BASES DE DADOS"]="CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3"
    ["FLAGS BOOLEANAS"]="CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE CFG_CHAVE_SSH"
    ["CONFIGURACOES DE REDE"]="DEFAULT_SSH_PORTA DEFAULT_IP_SERVER"
    ["DIRETORIOS PADRAO"]="DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR DEFAULT_LOGS_DIR DEFAULT_BACKUP_DIR DEFAULT_BASEBACKUP_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BIBLIOTECA_DIR DEFAULT_PROGS_DIR DEFAULT_OLDS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR"
    ["SAVISC - DIRETORIO E UTILITARIOS"]="SAVISC REBUILD"
    ["ACESSO OFFLINE"]="ACESSO_OFF CFG_BACKUP_PATH"
)

# =============================================================================
# FUNCAO: Carregar arquivo de configuracao (delegacao segura)
# =============================================================================
_var_carregar_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]] && [[ -r "$config_file" ]]; then
        # Delegar ao parser seguro do constantes.sh
        if command -v _carregar_config_seguro >/dev/null 2>&1; then
            _carregar_config_seguro "$config_file"
        else
            # Fallback apenas se config.sh/constantes.sh nao estiver carregado
            set -a; "." "$config_file"; set +a
        fi
        return $?
    fi
    return 1
}

# =============================================================================
# FUNCAO: Carregar constantes do sistema (delegacao)
# =============================================================================
_var_carregar_constantes() {
    local constantes_file="${LIBS_DIR}/constantes.sh"

    if [[ -f "$constantes_file" ]] && [[ -r "$constantes_file" ]]; then
        "." "$constantes_file"
        return $?
    fi

    return 1
}

# =============================================================================
# FUNCAO: Verificar dependencias basicas
# =============================================================================
_var_verificar_dependencias() {
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
_var_obter_valor() {
    local var_name="$1"
    local valor

    # Indirecao para obter o valor da variavel
    valor="${!var_name:-}"

    if [[ -z "$valor" ]]; then
        echo "NAO DEFINIDO"
    else
        echo "$valor"
    fi
}

# =============================================================================
# FUNCAO: Exibir constantes em formato tabular
# Parametros: $1 = filtro opcional por nome de categoria
# =============================================================================
_var_exibir_tabular() {
    local filtro="${1:-}"
    local categoria variavel valor

    printf "\n"
    printf "%s\n" "CONSTANTES DO SISTEMA SAV - LISTAGEM COMPLETA"
    printf "\n"

    # Exibir informacoes sobre o arquivo de configuracao
    printf "%s%s Fonte de Configuracao:%s\n" "$GREEN" "$BOLD" "$NORM"
    if [[ -f "$CONFIG_FILE" ]] && [[ -r "$CONFIG_FILE" ]]; then
        printf "   %s Status: Carregado com sucesso %s" "$GREEN" "$CONFIG_FILE"
    else
        printf "   %s Status: Nao encontrado (usando valores padrao) %s" "$YELLOW" "$CONFIG_FILE"
    fi
    printf "\n"

    # Cabecalho da tabela
    printf "%s%-35s%s %s\n" "$GREEN" "VARIAVEL" "$NORM" "VALOR"
    printf "%-35s %s\n" "$(printf '%.0s-' {1..35})" "$(printf '%.0s-' {1..60})"

    # Iterar sobre as categorias
    for categoria in "${!_VAR_CATEGORIAS[@]}"; do
        # Se ha filtro, verificar se a categoria corresponde (case-insensitive)
        if [[ -n "$filtro" ]]; then
            local cat_lower="${categoria,,}"
            local filtro_lower="${filtro,,}"
            if [[ ! "$cat_lower" =~ $filtro_lower ]]; then
                continue
            fi
        fi

        printf "\n%s%s[%s]%s\n" "$YELLOW" "$BOLD" "$categoria" "$NORM"

        for variavel in ${_VAR_CATEGORIAS[$categoria]}; do
            valor=$(_var_obter_valor "$variavel")
            printf "%-35s %s\n" "$variavel" "$valor"
        done
    done

    printf "\n"
}

# =============================================================================
# FUNCAO PUBLICA: Consultar variaveis (ponto de entrada do menu)
# Permite filtro opcional interativo. Retorna 0 sempre (exibicao).
# =============================================================================
_consultar_variaveis() {
    local filtro=""

    # Verificar dependencias
    if ! _var_verificar_dependencias; then
        return 1
    fi

    # Garantir config carregada (silencioso se ja estiver)
    if ! _var_carregar_config "$CONFIG_FILE"; then
        : # Config ausente nao e fatal para a consulta
    fi

    # Filtro opcional informado como argumento direto
    filtro="${1:-}"

    # Se nao veio por argumento, perguntar interativamente
    if [[ -z "$filtro" && -t 0 ]]; then
        _limpa_tela 2>/dev/null || true
        _linha "=" "${GREEN}" 2>/dev/null || true
        printf '%s\n' "${RED}Consulta de Variaveis do Sistema${NORM}"
        _linha 2>/dev/null || true
        printf '%s' "${YELLOW}Digite um filtro (ex: DIRETORIOS, REDE) ou ENTER para listar tudo: ${NORM}"
        read -r filtro
        filtro="${filtro:-}"
    fi

    _var_exibir_tabular "$filtro"

    # Aguardar tecla antes de retornar ao menu (se a funcao existir)
    if command -v _aguardar_tecla >/dev/null 2>&1; then
        _aguardar_tecla
    fi

    return 0
}
