#!/usr/bin/env bash
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 23/06/2026-01

# =============================================================================
# CONFIGURACOES DE SEGURANCA
# =============================================================================
set -o pipefail
set +u

# =============================================================================
# VARIAVEIS GLOBAIS PRIMITIVAS (fallback se nao definidas em constantes.sh)
# =============================================================================
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-}"
RAIZ="${RAIZ:-}"
CFG_DIR="${CFG_DIR:-}"
REBUILD="${REBUILD:-}"

# Arrays para registro e limpeza de variaveis
declare -ga REGISTRO_VARIAVEIS=()
declare -gA REGISTRO_CATEGORIAS=()
declare -gA _REGISTRO_MAPA=()
declare -g VAR_CONTADOR_REGISTRO=0

# Reativar set -u apos inicializacao
set -u

# =============================================================================
# SISTEMA DE REGISTRO DE VARIAVEIS
# =============================================================================

# Verifica se uma variavel ja esta registrada (O(1) via associative array)
_var_ja_registrada() {
    [[ -n "${_REGISTRO_MAPA[$1]+x}" ]]
}

# Verifica se uma variavel e readonly
_is_var_readonly() {
    local var_name="$1"
    local decl_output
    decl_output=$(declare -p "$var_name" 2>/dev/null) || return 1
    [[ "$decl_output" == *"declare -r"* ]] || [[ "$decl_output" == *"declare -ir"* ]]
}

# Registra uma variavel no sistema
_register_var() {
    local var_name="$1"
    local var_value="$2"
    local var_category="${3:-OUTROS}"

    if [[ -z "$var_name" ]]; then
        _aviso "Nome de variavel vazio, ignorando registro." >&2
        return 1
    fi

    # Pular variaveis readonly ou nao modificaveis
    if [[ "$var_name" == "UPDATE" ]] || _is_var_readonly "$var_name"; then
        return 0
    fi

    # Se ja esta registrada, atualizar valor
    if _var_ja_registrada "$var_name"; then
        declare -g "$var_name"="$var_value" 2>/dev/null || true
        return 0
    fi

    # Definir a variavel como global
    declare -g "$var_name"="$var_value" 2>/dev/null || {
        _aviso "Nao foi possivel definir variavel %s (pode ser readonly)" "$var_name" >&2
        return 0
    }

    # Registrar para limpeza posterior
    REGISTRO_VARIAVEIS+=("$var_name")
    _REGISTRO_MAPA["$var_name"]=1
    REGISTRO_CATEGORIAS["$var_category"]+=" $var_name"
    ((VAR_CONTADOR_REGISTRO++)) || true

    return 0
}

# Define multiplas variaveis de uma categoria
_define_category_vars() {
    local category="$1"
    shift
    local var_def var_name var_value

    for var_def in "$@"; do
        var_name="${var_def%%=*}"
        var_value="${var_def#*=}"
        _is_var_readonly "$var_name" && continue
        _register_var "$var_name" "$var_value" "$category"
    done
}

# =============================================================================
# INICIALIZACAO DE VARIAVEIS DO SISTEMA
# =============================================================================

_inicializar_variaveis_sistema() {
    # Cores do terminal
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        RED=$(tput bold; tput setaf 1 2>/dev/null)
        GREEN=$(tput bold; tput setaf 2 2>/dev/null)
        YELLOW=$(tput bold; tput setaf 3 2>/dev/null)
        BLUE=$(tput bold; tput setaf 4 2>/dev/null)
        PURPLE=$(tput bold; tput setaf 5 2>/dev/null)
        CYAN=$(tput bold; tput setaf 6 2>/dev/null)
        WHITE=$(tput bold; tput setaf 7 2>/dev/null)
        NORM=$(tput sgr0 2>/dev/null)
        COLUMNS=$(tput cols)
        tput clear 2>/dev/null || true
        tput bold 2>/dev/null || true
        tput setaf 7 2>/dev/null || true
    else
        RED="\033[0;31m"
        GREEN="\033[0;32m"
        YELLOW="\033[0;33m"
        BLUE="\033[0;34m"
        PURPLE="\033[0;35m"
        CYAN="\033[0;36m"
        WHITE="\033[0;37m"
        NORM="\033[0m"
        COLUMNS="${COLUMNS:-80}"
    fi
    export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NORM COLUMNS

    # Reinicializar arrays
    REGISTRO_VARIAVEIS=()
    _REGISTRO_MAPA=()

    # ATUALIZACAO
    _define_category_vars "ATUALIZACAO" \
        "CFG_SISTEMA=${CFG_SISTEMA:-}" \
        "CFG_VERCLASS=${CFG_VERCLASS:-}" \
        "CFG_USA_DBMAKER=${CFG_USA_DBMAKER:-}" \
        "CFG_ACESSO_SSH=${CFG_ACESSO_SSH:-}" \
        "CFG_OFFLINE=${CFG_OFFLINE:-}" \
        "CFG_BACKUP_PATH=${CFG_BACKUP_PATH:-}" \
        "CFG_EMPRESA=${CFG_EMPRESA:-}" \
        "VERSAOANT=${VERSAOANT:-}"

    # CAMINHOS
    _define_category_vars "CAMINHOS" \
        "BASE1=${BASE1:-}" \
        "BASE2=${BASE2:-}" \
        "BASE3=${BASE3:-}" \
        "SCRIPT_DIR=${SCRIPT_DIR:-}" \
        "RAIZ=${RAIZ:-}" \
        "CFG_BASE_DIR=${CFG_BASE_DIR:-}" \
        "CFG_BASE_DIR2=${CFG_BASE_DIR2:-}" \
        "CFG_BASE_DIR3=${CFG_BASE_DIR3:-}" \
        "INI=${INI:-}" \
        "UMADATA=${UMADATA:-}" \
        "E_EXEC=${E_EXEC:-}" \
        "T_TELAS=${T_TELAS:-}" \
        "X_XML=${X_XML:-}"

    # BIBLIOTECA
    _define_category_vars "BIBLIOTECA" \
        "SAVATU=${SAVATU:-}" \
        "SAVATU1=${SAVATU1:-}" \
        "SAVATU2=${SAVATU2:-}" \
        "SAVATU3=${SAVATU3:-}" \
        "SAVATU4=${SAVATU4:-}"

    # COMANDOS
    _define_category_vars "COMANDOS" \
        "DEFAULT_ZIP=${DEFAULT_ZIP:-}" \
        "DEFAULT_FIND=${DEFAULT_FIND:-}" \
        "DEFAULT_WHO=${DEFAULT_WHO:-}" \
        "DEFAULT_UNZIP=${DEFAULT_UNZIP:-}" \
        "REBUILD=${REBUILD:-}" \
        "JUTIL=${JUTIL:-}" \
        "ISCCLIENT=${ISCCLIENT:-}" \
        "ISCCLIENTT=${ISCCLIENTT:-}"

    # CONFIGURACOES
    _define_category_vars "CONFIGURACOES" \
        "DEFAULT_SSH_PORTA=${DEFAULT_SSH_PORTA:-}" \
        "DEFAULT_SSH_USER=${DEFAULT_SSH_USER:-}" \
        "VERSAO=${VERSAO:-}" \
        "SAVISC=${SAVISC:-}" \
        "DEFAULT_VERSAO=${DEFAULT_VERSAO:-}" \
        "DEFAULT_ARQUIVO=${DEFAULT_ARQUIVO:-}" \
        "DEFAULT_PEDARQ=${DEFAULT_PEDARQ:-}" \
        "DEFAULT_PROG=${DEFAULT_PROG:-}" \
        "DEFAULT_IP_SERVER=${DEFAULT_IP_SERVER:-}" \
        "base_trabalho=${base_trabalho:-}"

    # LOGS
    _define_category_vars "LOGS" \
        "LOG=${LOG:-}" \
        "LOG_ATU=${LOG_ATU:-}" \
        "LOG_LIMPA=${LOG_LIMPA:-}" \
        "LOG_TMP=${LOG_TMP:-}"
}

# =============================================================================
# CRIACAO DE DIRETORIO DE CONFIGURACAO
# =============================================================================
if [[ -n "${CFG_DIR}" ]]; then
    if [[ ! -d "${CFG_DIR}" ]]; then
        mkdir -p "${CFG_DIR}" || {
            _erro "Nao foi possivel criar o diretorio de configuracao '${CFG_DIR}'." >&2
            return 1
        }
    fi
    chmod "${PERM_DIR_SECURE}" "${CFG_DIR}" 2>/dev/null || {
        _aviso "AVISO: Nao foi possivel ajustar permissao em '${CFG_DIR}'." >&2
    }
fi

DEFAULT_LOGS_DIR="${DEFAULT_LOGS_DIR:-}"

# =============================================================================
# FUNCOES DE CONFIGURACAO
# =============================================================================

# Configurar comandos do sistema
_configurar_comandos() {
    local cmds=("$DEFAULT_ZIP" "$DEFAULT_UNZIP")
    local cmd missing=()

    for cmd in "${cmds[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        _erro "Comandos nao encontrados: %s\n" "${missing[*]}" >&2
        command -v _aguardar >/dev/null 2>&1 && _aguardar 2 2>/dev/null || true
        return 1
    fi
    return 0
}

# Configurar diretorios de trabalho
_configurar_diretorios() {
    if [[ -z "${SCRIPT_DIR}" ]] || [[ ! -d "${SCRIPT_DIR}" ]]; then
        if command -v _mensagec >/dev/null 2>&1; then
            _mensagec "${CYAN}" "Diretorio principal nao encontrado: ${SCRIPT_DIR}"
        else
            _erro "Diretorio principal nao encontrado: %s\n" "${SCRIPT_DIR}" >&2
        fi
        return 1
    fi

    _criar_diretorio_seguro "${CFG_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s\n" "${CFG_DIR}" >&2
        return 1
    }

    local dirs=("${DEFAULT_BIBLIOTECA_ATUAL_DIR}" "${DEFAULT_BIBLIOTECA_DIR}" "${DEFAULT_BASEBACKUP_DIR}" "${DEFAULT_OLDS_DIR}" "${DEFAULT_PROGS_DIR}" "${DEFAULT_LOGS_DIR}" "${DEFAULT_ENVIA_DIR}" "${DEFAULT_RECEBE_DIR}" "${DEFAULT_BACKUP_DIR}")
    local dir
    for dir in "${dirs[@]}"; do
        _criar_diretorio_seguro "${dir}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
            _erro "Ao criar diretorio %s\n" "${dir}" >&2
            return 1
        }
    done
}

# Configurar variaveis do sistema baseado no tipo de compilacao
_configurar_variaveis_sistema() {
    if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then
        E_EXEC="${E_EXEC:-${RAIZ}/classes}"
        T_TELAS="${T_TELAS:-${RAIZ}/tel_isc}"
        X_XML="${X_XML:-${RAIZ}/xml}"
        export E_EXEC T_TELAS X_XML

        local verclass_sufixo="${CFG_VERCLASS: -2}"
        compilado="-class${verclass_sufixo}"
        debugado="-mclass${verclass_sufixo}"

        local classA="IS${CFG_VERCLASS}_classA_"
        local classB="IS${CFG_VERCLASS}_classB_"
        local classC="IS${CFG_VERCLASS}_tel_isc_"
        local classD="IS${CFG_VERCLASS}_xml_"
        local classX="IS${CFG_VERCLASS}_*_"
        SAVATU1="tempSAV_${classA}"
        SAVATU2="tempSAV_${classB}"
        SAVATU3="tempSAV_${classC}"
        SAVATU4="tempSAV_${classD}"
        SAVATU="tempSAV_${classX}"
    else
        E_EXEC="${E_EXEC:-${RAIZ}/int}"
        T_TELAS="${T_TELAS:-${RAIZ}/tel}"
        compilado="${compilado:-6}"
        debugado="${debugado:-m6}"
        SAVATU1="tempSAVintA_"
        SAVATU2="tempSAVintB_"
        SAVATU3="tempSAVtel_"
        SAVATU="tempSAV????"
    fi

    BASE1="${BASE1:-${RAIZ}${CFG_BASE_DIR}}"
    BASE2="${BASE2:-${RAIZ}${CFG_BASE_DIR2}}"
    BASE3="${BASE3:-${RAIZ}${CFG_BASE_DIR3}}"
    export E_EXEC T_TELAS BASE1 BASE2 BASE3 CFG_OFFLINE
    export SAVATU1 SAVATU2 SAVATU3 SAVATU4 SAVATU
}

# Validar acesso SSH
_validar_ssh() {
    if [[ "${CFG_ACESSO_SSH}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_ACESSO_SSH}" == "s" ]]; then
            _mensagec "${GREEN}" "OK: Acesso SSH habilitado"
            if ssh -o BatchMode=yes sav_servidor exit 2>/dev/null; then
                _mensagec "${GREEN}" "Conexao SSH estabelecida com sucesso!"
            else
                _mensagec "${RED}" "Conexao SSH estabelecida sem sucesso!"
            fi
            _linha "=" "${GREEN}"
        else
            _mensagec "${YELLOW}" "Alerta: Acesso SSH desabilitado"
        fi
    else
        _mensagec "${YELLOW}" "Alerta: Variavel 'acesso_ssh' com valor desconhecido: ${CFG_ACESSO_SSH}"
    fi
}

# Validar conteudo do arquivo de configuracao (seguranca)
_validar_config_file() {
    local CONFIG_FILE="${1}"
    local linha num_linha=0 erros=0

    if [[ ! -f "$CONFIG_FILE" ]]; then
        _erro "Arquivo de configuracao nao encontrado: %s\n" "$CONFIG_FILE" >&2
        return 1
    fi

    if [[ ! -r "$CONFIG_FILE" ]]; then
        _erro "Arquivo de configuracao sem permissao de leitura: %s\n" "$CONFIG_FILE" >&2
        return 1
    fi

    local tamanho
    tamanho=$(wc -c < "$CONFIG_FILE" 2>/dev/null || echo 0)
    if (( tamanho > 1048576 )); then
        _erro "Arquivo de configuracao muito grande: %d bytes\n" "$tamanho" >&2
        return 1
    fi

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        ((num_linha++))

        # Pular linhas vazias e comentarios
        [[ -z "$linha" ]] && continue
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue

        # Remover espacos iniciais
        linha="${linha#"${linha%%[![:space:]]*}"}"

        # Remover comentarios inline
        [[ "$linha" == *'#'* ]] && linha="${linha%%#*}"
        [[ -z "$linha" ]] && continue

        # Validar formato de atribuicao
        if ! [[ "$linha" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            _erro "Linha %d tem formato invalido: %s\n" "$num_linha" "$linha" >&2
            return 1
        fi

        # Verificar caracteres perigosos
        if printf '%s\n' "$linha" | grep -qE '[\`\;|\&<>(){}]'; then
            _erro "Linha %d contem caracteres perigosos: %s\n" "$num_linha" "$linha" >&2
            return 1
        fi

        # Verificar command substitution
        if [[ "$linha" =~ \$\( ]] || [[ "$linha" =~ \` ]]; then
            _erro "Linha %d contem command substitution: %s\n" "$num_linha" "$linha" >&2
            ((erros++))
            continue
        fi

        # Verificar expansao de variavel suspeita
        if [[ "$linha" =~ \$\{.*\} ]]; then
            _erro "Linha %d contem expansao de variavel suspeita: %s\n" "$num_linha" "$linha" >&2
            ((erros++))
            continue
        fi

    done < "$CONFIG_FILE"

    if (( erros > 0 )); then
        _erro "Arquivo de configuracao contem %d erro(s). Carregamento bloqueado.\n" "$erros" >&2
        return 1
    fi
    return 0
}

# Carregar arquivo de configuracao da empresa
_carregar_config_empresa() {
    local CONFIG_FILE="${CFG_DIR}/.config"

    if [[ ! -e "${CONFIG_FILE}" ]]; then
        _erro "Arquivo de configuracao nao existe no diretorio.\n" >&2
        _aviso "ATENCAO: Execute './atualiza.sh --setup' para criar as configuracoes.\n" >&2
        command -v _aguardar >/dev/null 2>&1 && _aguardar 2 2>/dev/null || true
        return 1
    fi

    if [[ ! -r "${CONFIG_FILE}" ]]; then
        _erro "Arquivo %s sem permissao de leitura.\n" "${CONFIG_FILE}" >&2
        command -v _aguardar >/dev/null 2>&1 && _aguardar 2 2>/dev/null || true
        return 1
    fi

    if ! _validar_config_file "${CONFIG_FILE}"; then
        _erro "Arquivo de configuracao contem formato invalido ou comandos suspeitos.\n" >&2
        _aviso "Carregamento do arquivo de configuracao bloqueado por seguranca.\n" >&2
        command -v _aguardar >/dev/null 2>&1 && _aguardar 2 2>/dev/null || true
        return 1
    fi

    if ! _carregar_config_seguro "${CONFIG_FILE}"; then
        _erro "Falha ao carregar arquivo de configuracao %s.\n" "${CONFIG_FILE}" >&2
        return 1
    fi
    return 0
}

# Funcao principal de carregamento de configuracoes
_carregar_configuracoes() {
    if ! cd "${SCRIPT_DIR}"; then
        _erro "Nao foi possivel acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2
        return 1
    fi

    _carregar_config_empresa || return 1
    _configurar_comandos || return 1
    _configurar_diretorios || return 1
    _configurar_variaveis_sistema
}

# Configurar ambiente final
_configurar_ambiente() {
    if [[ "${CFG_SISTEMA}" == "iscobol" ]] && [[ ! -x "${REBUILD}" ]]; then
        if command -v _mensagec >/dev/null 2>&1; then
            _mensagec "${YELLOW}" "Aviso: jutil nao encontrado em ${REBUILD}"
        else
            _aviso "jutil nao encontrado em %s\n" "${REBUILD}" >&2
        fi
    fi
}

# =============================================================================
# VALIDACAO DE CONFIGURACAO
# =============================================================================

_validar_configuracao() {
    _limpa_tela
    _linha "=" "${GREEN}"
    _mensagec "${RED}" "Validacao de Configuracao"
    _linha

    local erros=0 warnings=0

    # Arquivo de configuracao
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo .config nao encontrado!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Arquivo .config encontrado"
    fi

    # Variaveis essenciais
    if [[ -z "${CFG_SISTEMA}" ]]; then
        _mensagec "${RED}" "ERRO: Variavel 'sistema' nao definida!"
        ((erros++)) || true
    elif [[ "${CFG_SISTEMA}" != "iscobol" && "${CFG_SISTEMA}" != "cobol" ]]; then
        _mensagec "${YELLOW}" "Alerta: Valor desconhecido para 'sistema': ${CFG_SISTEMA}"
        ((warnings++)) || true
    else
        _mensagec "${GREEN}" "OK: Sistema definido como ${CFG_SISTEMA}"
    fi

    if [[ -z "${RAIZ}" ]]; then
        _mensagec "${RED}" "ERRO: Variavel 'RAIZ' nao definida!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Diretorio RAIZ definido"
    fi

    # Variaveis opcionais
    local vars_opcionais=("CFG_USA_DBMAKER" "CFG_ACESSO_SSH" "CFG_OFFLINE" "CFG_CHAVE_SSH")
    local var
    for var in "${vars_opcionais[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            _mensagec "${YELLOW}" "Alerta: Variavel '${var}' nao definida"
            ((warnings++)) || true
        else
            _mensagec "${GREEN}" "OK: Configuracao ${var} definida"
        fi
    done

    # Diretorios essenciais
    local dirs=("biblioteca" "olds" "logs" "configuracoes" "binarios" "backup" "bases_backup" "enviar" "receber" "E_EXEC" "T_TELAS" "BASE1")
    local dir dir_path
    for dir in "${dirs[@]}"; do
        if [[ "$dir" == "E_EXEC" ]] || [[ "$dir" == "T_TELAS" ]] || [[ "$dir" == "BASE1" ]]; then
            dir_path="${!dir:-}"
        else
            dir_path="${SCRIPT_DIR}${!dir:-}"
        fi

        if [[ ! -d "${dir_path}" ]]; then
            _mensagec "${YELLOW}" "Alerta: Diretorio ${dir} nao encontrado: ${dir_path}"
            ((warnings++)) || true
        fi
    done

    # Modo offline
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "n" ]]; then
            _mensagec "${NORM}" "INFO: Servidor em modo On ..."
        else
            _mensagec "${GREEN}" "INFO: Servidor em modo Off ..."
        fi
    fi

    # Resumo
    _linha
    printf "\n"
    _mensagec "${CYAN}" "Resumo:"
    _mensagec "${RED}" "Erros: ${erros}"
    _mensagec "${YELLOW}" "Avisos: ${warnings}"

    if (( erros == 0 )); then
        _mensagec "${GREEN}" "Configuracao valida!"
    else
        _mensagec "${RED}" "Configuracao com erros!"
    fi
    _linha
}

# Navegar para o diretorio de ferramentas
_ir_para_tools() {
    if ! cd "${SCRIPT_DIR}"; then
        _erro "Ao acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2
        return 1
    fi
    return 0
}

# =============================================================================
# SISTEMA DE LIMPEZA DE VARIAVEIS
# =============================================================================

# Limpar variaveis registradas
_limpar_estado_variaveis() {
    if [[ ${#REGISTRO_VARIAVEIS[@]} -eq 0 ]]; then
        return 0
    fi

    local var var_count=0
    for var in "${REGISTRO_VARIAVEIS[@]}"; do
        if [[ -n "${!var+x}" ]]; then
            unset -v "$var" 2>/dev/null || true
            ((var_count++)) || true
        fi
    done

    # Limpar arrays
    REGISTRO_VARIAVEIS=()
    _REGISTRO_MAPA=()
    REGISTRO_CATEGORIAS=()
    unset -v VAR_CONTADOR_REGISTRO 2>/dev/null || true

    tput sgr0 2>/dev/null || true
    return 0
}

# Limpeza de emergencia (sem dependencias de arrays)
_limpeza_emergencia() {
    local emergency_vars="RED GREEN YELLOW BLUE PURPLE CYAN NORM"
    emergency_vars+=" CFG_SISTEMA CFG_VERCLASS CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE"
    emergency_vars+=" CFG_BACKUP_PATH CFG_EMPRESA VERSAOANT BASE1 BASE2 BASE3 SCRIPT_DIR"
    emergency_vars+=" RAIZ CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 INI UMADATA E_EXEC"
    emergency_vars+=" T_TELAS X_XML SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4 DEFAULT_ZIP"
    emergency_vars+=" DEFAULT_FIND DEFAULT_WHO DEFAULT_UNZIP REBUILD JUTIL ISCCLIENT"
    emergency_vars+=" ISCCLIENTT DEFAULT_SSH_PORTA DEFAULT_SSH_USER VERSAO SAVISC"
    emergency_vars+=" DEFAULT_VERSAO DEFAULT_ARQUIVO DEFAULT_PEDARQ DEFAULT_PROG"
    emergency_vars+=" DEFAULT_IP_SERVER UPDATE base_trabalho LOG LOG_ATU LOG_LIMPA LOG_TMP"

    local var
    for var in $emergency_vars; do
        unset -v "$var" 2>/dev/null || true
    done
    tput sgr0 2>/dev/null || true
}

# Configurar limpeza automatica ao sair
_configurar_limpeza_automatica() {
    trap '_limpar_estado_variaveis' EXIT INT TERM
    trap '_limpeza_emergencia' QUIT
}

# Inicializar sistema de variaveis
_inicializar_sistema_variaveis() {
    REGISTRO_VARIAVEIS=()
    _REGISTRO_MAPA=()
    declare -A REGISTRO_CATEGORIAS=()
    VAR_CONTADOR_REGISTRO=0

    _inicializar_variaveis_sistema
    _configurar_limpeza_automatica
    _register_var "SISTEMA_VARIAVEIS_INICIALIZADO" "true" "SISTEMA"
}

# Resetar estado do sistema
_resetando() {
    _limpar_estado_variaveis
    return 0
}

# Finalizar o sistema
_finalizar_sistema() {
    _limpar_estado_variaveis
    trap - EXIT INT TERM QUIT
    tput sgr0 2>/dev/null || true
}

# Encerrar programa com status
_encerrar_programa() {
    local status="${1:-0}"
    _finalizar_sistema
    exit "$status"
}

trap '_limpar_estado_variaveis' EXIT
trap '_encerrar_programa' INT TERM
trap '_limpeza_emergencia' QUIT

