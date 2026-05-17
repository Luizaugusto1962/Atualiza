#!/usr/bin/env bash
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 14/05/2026-01
# Autor: Luiz Augusto
#
# =============================================================================
# CONFIGURACOES DE SEGURANCA
# =============================================================================
set -o pipefail

# =============================================================================
# FUNCAO UTILITARIA: Definir variavel apenas se nao estiver definida ou vazia
# Parametros:
#   $1 - nome da variavel
#   $2 - valor padrao (opcional, vazio por padrao)
# Retorna: 0 se sucesso, 1 se falhou
# =============================================================================
_setdefault() {
    local var_name="$1"
    local var_value="${2:-}"

    # Validar nome da variavel
    if [[ -z "$var_name" ]]; then
        return 1
    fi

    # Verificar se a variavel ja esta definida (setada, mesmo que vazia com :-
    # so definimos se nao existir de forma alguma
    if ! declare -p "$var_name" &>/dev/null; then
        declare -g "$var_name=$var_value"
    fi

    return 0
}

# =============================================================================
# VARIAVEIS GLOBAIS - Definicao direta e simples
# =============================================================================

# Caminhos de diretorios do sistema
RAIZ="${RAIZ:-}"
CFG_DIR="${CFG_DIR:-}"
LIBS_DIR="${LIBS_DIR:-}"
CFG_BASE_DIR="${CFG_BASE_DIR:-}"
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"
DEFAULT_BACKUP_DIR="${DEFAULT_BACKUP_DIR:-}"
DEFAULT_LOGS_DIR="${DEFAULT_LOGS_DIR:-}"
DEFAULT_BIBLIOTECA_DIR="${DEFAULT_BIBLIOTECA_DIR:-}"
DEFAULT_BIBLIOTECA_ATUAL_DIR="${DEFAULT_BIBLIOTECA_ATUAL_DIR:-}"
DEFAULT_BASEBACKUP_DIR="${DEFAULT_BASEBACKUP_DIR:-}"
DEFAULT_OLDS_DIR="${DEFAULT_OLDS_DIR:-}"
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-}"
DEFAULT_ENVIA_DIR="${DEFAULT_ENVIA_DIR:-}"
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"
DEFAULT_CONFIG_DIR="${DEFAULT_CONFIG_DIR:-}"
DEFAULT_LIBS_DIR="${DEFAULT_LIBS_DIR:-}"

# Sistema e banco de dados
CFG_SISTEMA="${CFG_SISTEMA:-}"
CFG_VERCLASS="${CFG_VERCLASS:-}"
CFG_USA_DBMAKER="${CFG_USA_DBMAKER:-}"
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-}"
CFG_EMPRESA="${CFG_EMPRESA:-}"
CFG_OFFLINE="${CFG_OFFLINE:-}"
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-}"

# Biblioteca SAV
SAVATU="${SAVATU:-}"
SAVATU1="${SAVATU1:-}"
SAVATU2="${SAVATU2:-}"
SAVATU3="${SAVATU3:-}"
SAVATU4="${SAVATU4:-}"

# Caminhos e variaveis de trabalho
INI="${INI:-}"
UMADATA="${UMADATA:-}"
VERSAO="${VERSAO:-}"
VERSAOANT="${VERSAOANT:-}"
E_EXEC="${E_EXEC:-}"
T_TELAS="${T_TELAS:-}"
X_XML="${X_XML:-}"
BASE1="${BASE1:-}"
BASE2="${BASE2:-}"
BASE3="${BASE3:-}"
base_trabalho="${base_trabalho:-}"

# Comandos do sistema
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"
DEFAULT_ZIP="${DEFAULT_ZIP:-}"
DEFAULT_FIND="${DEFAULT_FIND:-}"
DEFAULT_WHO="${DEFAULT_WHO:-}"
REBUILD="${REBUILD:-}"
JUTIL="${JUTIL:-}"
ISCCLIENT="${ISCCLIENT:-}"
ISCCLIENTT="${ISCCLIENTT:-}"

# Configuracoes de rede
DEFAULT_SSH_PORTA="${DEFAULT_SSH_PORTA:-}"
DEFAULT_SSH_USER="${DEFAULT_SSH_USER:-}"
DEFAULT_IP_SERVER="${DEFAULT_IP_SERVER:-}"

# Destinos
DESTINO_BIBLIOTECA="${DESTINO_BIBLIOTECA:-}"
DESTINO_SERVER="${DESTINO_SERVER:-}"
SAVISC="${SAVISC:-}"

# Cores do terminal (serao definidas corretamente por _definir_cores)
RED="${RED:-}"
GREEN="${GREEN:-}"
YELLOW="${YELLOW:-}"
BLUE="${BLUE:-}"
PURPLE="${PURPLE:-}"
CYAN="${CYAN:-}"
NORM="${NORM:-}"
WHITE="${WHITE:-}"
COLUMNS="${COLUMNS:-}"

# Logs
LOG="${LOG:-}"
LOG_ATU="${LOG_ATU:-}"
LOG_LIMPA="${LOG_LIMPA:-}"
LOG_TMP="${LOG_TMP:-}"

# Arquivo de backup padrao
INI="${INI:-backup-${VERSAO}.zip}"

# =============================================================================
# FUNCOES DE CONFIGURACAO
# =============================================================================

# -----------------------------------------------------------------------------
# Funcao para definir cores do terminal
# -----------------------------------------------------------------------------
_definir_cores() {
    # Verificar se o terminal suporta cores
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        RED=$(tput bold; tput setaf 1 2>/dev/null)
        GREEN=$(tput bold; tput setaf 2 2>/dev/null)
        YELLOW=$(tput bold; tput setaf 3 2>/dev/null)
        BLUE=$(tput bold; tput setaf 4 2>/dev/null)
        PURPLE=$(tput bold; tput setaf 5 2>/dev/null)
        CYAN=$(tput bold; tput setaf 6 2>/dev/null)
        WHITE=$(tput bold; tput setaf 7 2>/dev/null)
        NORM=$(tput sgr0 2>/dev/null)
        COLUMNS=$(tput cols 2>/dev/null || echo "${DEFAULT_COLUMNS:-80}")

        # Limpar tela inicial
        tput clear 2>/dev/null || true
        tput bold 2>/dev/null || true
        tput setaf 7 2>/dev/null || true
    else
        # Terminal sem suporte a cores
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        PURPLE=""
        CYAN=""
        WHITE=""
        NORM=""
        COLUMNS="${DEFAULT_COLUMNS:-80}"
    fi

    export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NORM COLUMNS
}

# -----------------------------------------------------------------------------
# Configurar comandos do sistema
# Retorna: 0 se todos os comandos existirem, 1 caso contrario
# -----------------------------------------------------------------------------
_configurar_comandos() {
    local cmds=()
    local cmd=""
    local missing=()

    # Construir lista de comandos a verificar
    for cmd in "$DEFAULT_ZIP" "$DEFAULT_FIND" "$DEFAULT_WHO"; do
        [[ -n "$cmd" ]] && cmds+=("$cmd")
    done

    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "Erro: Comandos nao encontrados: %s\n" "${missing[*]}" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Configurar diretorios de trabalho e variaveis globais.
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_configurar_diretorios() {
    # Verificar diretorio principal
    if [[ -z "${SCRIPT_DIR}" ]] || [[ ! -d "${SCRIPT_DIR}" ]]; then
        if command -v _mensagec >/dev/null 2>&1; then
            _mensagec "${CYAN}" "Diretorio principal nao encontrado: ${SCRIPT_DIR}"
        else
            printf "Erro: Diretorio principal nao encontrado: %s\n" "${SCRIPT_DIR}" >&2
        fi
        return 1
    fi

    # Criar diretorio de configuracao se nao existir
    if [[ -n "${CFG_DIR}" ]]; then
        if [[ ! -d "${CFG_DIR}" ]]; then
            if command -v _criar_diretorio_seguro >/dev/null 2>&1; then
                _criar_diretorio_seguro "${CFG_DIR}" "${PERM_DIR_SECURE:-0755}" "${LOG_ATU}" || {
                    printf "Erro ao criar diretorio de configuracao %s\n" "${CFG_DIR}" >&2
                    return 1
                }
            else
                mkdir -p "${CFG_DIR}" || {
                    printf "Erro: Nao foi possivel criar diretorio de configuracao '%s'\n" "${CFG_DIR}" >&2
                    return 1
                }
                chmod "${PERM_DIR_SECURE:-0755}" "${CFG_DIR}" 2>/dev/null || true
            fi
        fi
    fi

    # Criar demais diretorios se nao existirem
    local dirs=()
    [[ -n "${DEFAULT_BIBLIOTECA_ATUAL_DIR}" ]] && dirs+=("${DEFAULT_BIBLIOTECA_ATUAL_DIR}")
    [[ -n "${DEFAULT_BIBLIOTECA_DIR}" ]]       && dirs+=("${DEFAULT_BIBLIOTECA_DIR}")
    [[ -n "${DEFAULT_BASEBACKUP_DIR}" ]]       && dirs+=("${DEFAULT_BASEBACKUP_DIR}")
    [[ -n "${DEFAULT_OLDS_DIR}" ]]             && dirs+=("${DEFAULT_OLDS_DIR}")
    [[ -n "${DEFAULT_PROGS_DIR}" ]]            && dirs+=("${DEFAULT_PROGS_DIR}")
    [[ -n "${DEFAULT_LOGS_DIR}" ]]             && dirs+=("${DEFAULT_LOGS_DIR}")
    [[ -n "${DEFAULT_ENVIA_DIR}" ]]            && dirs+=("${DEFAULT_ENVIA_DIR}")
    [[ -n "${DEFAULT_RECEBE_DIR}" ]]           && dirs+=("${DEFAULT_RECEBE_DIR}")
    [[ -n "${DEFAULT_BACKUP_DIR}" ]]           && dirs+=("${DEFAULT_BACKUP_DIR}")

    local dir=""
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if command -v _criar_diretorio_seguro >/dev/null 2>&1; then
                _criar_diretorio_seguro "$dir" "${PERM_DIR_SECURE:-0755}" "${LOG_ATU}" || {
                    printf "Erro ao criar diretorio %s\n" "$dir" >&2
                    return 1
                }
            else
                mkdir -p "$dir" || {
                    printf "Erro ao criar diretorio %s\n" "$dir" >&2
                    return 1
                }
            fi
        fi
    done

    return 0
}

# -----------------------------------------------------------------------------
# Configurar variaveis do sistema conforme o tipo de sistema
# -----------------------------------------------------------------------------
_configurar_variaveis_sistema() {
    if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then
        # Caminhos dos executaveis e dados para IsCOBOL
        E_EXEC="${E_EXEC:-${RAIZ}/CLASS}"
        T_TELAS="${T_TELAS:-${RAIZ}/tel_isc}"
        X_XML="${X_XML:-${RAIZ}/xml}"
        BASE1="${BASE1:-${RAIZ}${CFG_BASE_DIR}}"
        BASE2="${BASE2:-${RAIZ}${CFG_BASE_DIR2}}"
        BASE3="${BASE3:-${RAIZ}${CFG_BASE_DIR3}}"

        # Gerar sufixos de arquivos com base no tipo de compilacao
        verCLASS_sufixo="${CFG_VERCLASS: -2}"
        CLASS="-CLASS${verCLASS_sufixo}"
        MCLASS="-MCLASS${verCLASS_sufixo}"

        SAVATU1="tempSAV_IS${CFG_VERCLASS}_CLASSA_"
        SAVATU2="tempSAV_IS${CFG_VERCLASS}_CLASSB_"
        SAVATU3="tempSAV_IS${CFG_VERCLASS}_tel_isc_"
        SAVATU4="tempSAV_IS${CFG_VERCLASS}_xml_"
        SAVATU="tempSAV_IS${CFG_VERCLASS}_*_"
    else
        # Padrao para IsAM / outros
        E_EXEC="${E_EXEC:-${RAIZ}/int}"
        T_TELAS="${T_TELAS:-${RAIZ}/tel}"
        BASE1="${BASE1:-${RAIZ}${CFG_BASE_DIR}}"
        BASE2="${BASE2:-${RAIZ}${CFG_BASE_DIR2}}"
        BASE3="${BASE3:-${RAIZ}${CFG_BASE_DIR3}}"

        CLASS="-${CLASS:-6}"
        MCLASS="-${MCLASS:-m6}"

        SAVATU1="tempSAVintA_"
        SAVATU2="tempSAVintB_"
        SAVATU3="tempSAVtel_"
        SAVATU="tempSAV????_"
    fi

    export E_EXEC T_TELAS X_XML BASE1 BASE2 BASE3 CFG_OFFLINE
    export SAVATU1 SAVATU2 SAVATU3 SAVATU4 SAVATU CLASS MCLASS
}

# -----------------------------------------------------------------------------
# Validar conteudo de um arquivo de configuracao de forma rigorosa
# Verifica se o arquivo contem apenas atribuicoes de variaveis simples
# Parametros:
#   $1 - Caminho do arquivo de configuracao
# Retorna: 0 se valido, 1 se invalido
# -----------------------------------------------------------------------------
_validar_config_file() {
    local config_file="$1"
    local linha=""
    local num_linha=0
    local erros=0

    if [[ ! -f "$config_file" ]]; then
        printf "ERRO: Arquivo de configuracao nao encontrado: %s\n" "$config_file" >&2
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        printf "ERRO: Arquivo de configuracao sem permissao de leitura: %s\n" "$config_file" >&2
        return 1
    fi

    # Verificar tamanho do arquivo (limite: 1MB)
    local tamanho
    tamanho=$(wc -c < "$config_file" 2>/dev/null || echo 0)
    if (( tamanho > 1048576 )); then
        printf "ERRO: Arquivo de configuracao muito grande: %d bytes\n" "$tamanho" >&2
        return 1
    fi

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        ((num_linha++)) || true

        # Pular linhas vazias e comentarios
        [[ -z "${linha// /}" ]] && continue
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue

        # Remover espacos iniciais
        linha="${linha#"${linha%%[![:space:]]*}"}"

        # Ignorar comentario inline
        if [[ "$linha" == *'#'* ]]; then
            linha="${linha%%#*}"
        fi

        [[ -z "${linha// /}" ]] && continue

        # Validar formato: VARIAVEL=valor
        if ! [[ "$linha" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            printf "ERRO: Linha %d formato invalido: %s\n" "$num_linha" "$linha" >&2
            ((erros++)) || true
            continue
        fi

        # Verificar caracteres perigosos
        if printf '%s\n' "$linha" | grep -qE '[\$\`\;|\&<>(){}]'; then
            printf "ERRO: Linha %d contem caracteres perigosos: %s\n" "$num_linha" "$linha" >&2
            ((erros++)) || true
            continue
        fi

        # Verificar command substitution
        if [[ "$linha" =~ \$\( ]] || [[ "$linha" =~ \` ]]; then
            printf "ERRO: Linha %d contem command substitution: %s\n" "$num_linha" "$linha" >&2
            ((erros++)) || true
            continue
        fi

        # Verificar expansao de variavel suspeita
        if [[ "$linha" =~ \$\{.*\} ]]; then
            printf "ERRO: Linha %d contem expansao de variavel suspeita: %s\n" "$num_linha" "$linha" >&2
            ((erros++)) || true
            continue
        fi
    done < "$config_file"

    if (( erros > 0 )); then
        printf "ERRO: Arquivo de configuracao contem %d erro(s). Carregamento bloqueado.\n" "$erros" >&2
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Carregar configuracao de forma segura, sem sourcing direto
# Parametros:
#   $1 - Caminho do arquivo de configuracao
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_config_seguro() {
    local config_file="$1"
    local linha key value

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        [[ -z "$linha" ]] && continue
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue

        linha="${linha#"${linha%%[![:space:]]*}"}"

        if [[ "$linha" == *'#'* ]]; then
            linha="${linha%%#*}"
        fi

        [[ -z "$linha" ]] && continue

        if [[ "$linha" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"

            # Remover aspas se presentes
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # Validar valor
            if [[ "$value" =~ [\$\`\;] ]]; then
                printf "AVISO: Valor suspeito ignorado para %s: %s\n" "$key" "$value" >&2
                continue
            fi

            declare -g "$key=$value"
        fi
    done < "$config_file"

    return 0
}

# -----------------------------------------------------------------------------
# Carregar arquivo de configuracao da empresa com validacao segura
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_config_empresa() {
    local config_file="${CFG_DIR}/.config"

    if [[ ! -e "${config_file}" ]]; then
        printf "AVISO: Arquivo de configuracao nao encontrado: %s\n" "${config_file}" >&2
        printf "ATENCAO: Execute './atualiza.sh --setup' para criar as configuracoes.\n" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    if [[ ! -r "${config_file}" ]]; then
        printf "ERRO: Arquivo %s sem permissao de leitura.\n" "${config_file}" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    # Validar conteudo antes de carregar
    if ! _validar_config_file "${config_file}"; then
        printf "ERRO: Arquivo de configuracao contem formato invalido ou comandos suspeitos.\n" >&2
        printf "AVISO: Carregamento do arquivo de configuracao bloqueado por seguranca.\n" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    if ! _carregar_config_seguro "${config_file}"; then
        printf "ERRO: Falha ao carregar arquivo de configuracao %s.\n" "${config_file}" >&2
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Funcao principal de carregamento de configuracoes
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_configuracoes() {
    # Mudar para diretorio do script
    if ! cd "${SCRIPT_DIR}"; then
        printf "Erro: Nao foi possivel acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2
        return 1
    fi

    # Definir cores
    _definir_cores

    # Carregar arquivo de configuracao da empresa
    _carregar_config_empresa || return 1

    # Configurar comandos
    _configurar_comandos || return 1

    # Configurar diretorios
    _configurar_diretorios || return 1

    # Configurar variaveis do sistema
    _configurar_variaveis_sistema

    return 0
}

# -----------------------------------------------------------------------------
# Funcao para validar diretorios essenciais
# Retorna: 0 se todos validos, 1 se algum invalido
# -----------------------------------------------------------------------------
_validar_diretorios() {
    local erros=0

    _verifica_diretorio() {
        local caminho="$1"

        if [[ -z "${caminho}" ]] || [[ ! -d "${caminho}" ]]; then
            if command -v _mensagec >/dev/null 2>&1; then
                _mensagec "${CYAN}" "Diretorio nao encontrado: ${caminho}"
            else
                printf "Erro: Diretorio nao encontrado: %s\n" "${caminho}" >&2
            fi
            return 1
        fi
        return 0
    }

    _verifica_diretorio "${E_EXEC}" || ((erros++)) || true
    _verifica_diretorio "${T_TELAS}" || ((erros++)) || true
    _verifica_diretorio "${BASE1}" || ((erros++)) || true

    if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then
        _verifica_diretorio "${X_XML}" || ((erros++)) || true
    fi

    if [[ -n "${BASE2}" ]]; then
        _verifica_diretorio "${BASE2}" || ((erros++)) || true
    fi

    if [[ -n "${BASE3}" ]]; then
        _verifica_diretorio "${BASE3}" || ((erros++)) || true
    fi

    return $erros
}

# -----------------------------------------------------------------------------
# Configurar ambiente final
# Retorna: 0 sempre
# -----------------------------------------------------------------------------
_configurar_ambiente() {
    if [[ "${CFG_SISTEMA}" == "iscobol" ]] && [[ ! -x "${REBUILD}" ]]; then
        if command -v _mensagec >/dev/null 2>&1; then
            _mensagec "${YELLOW}" "Aviso: jutil nao encontrado em ${REBUILD}"
        else
            printf "Aviso: jutil nao encontrado em %s\n" "${REBUILD}" >&2
        fi
    fi
}

# -----------------------------------------------------------------------------
# Funcao para validar a configuracao atual do sistema
# Retorna: 0 se configuracao valida, 1 se ha erros
# -----------------------------------------------------------------------------
_validar_configuracao() {
    if command -v _limpa_tela >/dev/null 2>&1; then
        _limpa_tela
    fi
    if command -v _linha >/dev/null 2>&1; then
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Validacao de Configuracao"
        _linha
    fi

    local erros=0
    local warnings=0

    # Verificar arquivo .config
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo .config nao encontrado!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Arquivo .config encontrado"
    fi

    # Verificar sistema
    if [[ -z "${CFG_SISTEMA}" ]]; then
        _mensagec "${RED}" "ERRO: Variavel 'sistema' nao definida!"
        ((erros++)) || true
    elif [[ "${CFG_SISTEMA}" != "iscobol" && "${CFG_SISTEMA}" != "cobol" ]]; then
        _mensagec "${YELLOW}" "Alerta: Valor desconhecido para 'sistema': ${CFG_SISTEMA}"
        ((warnings++)) || true
    else
        _mensagec "${GREEN}" "OK: Sistema definido como ${CFG_SISTEMA}"
    fi

    # Verificar RAIZ
    if [[ -z "${RAIZ}" ]]; then
        _mensagec "${RED}" "ERRO: Variavel 'RAIZ' nao definida!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Diretorio RAIZ definido"
    fi

    # Verificar banco de dados
    if [[ -z "${CFG_USA_DBMAKER}" ]]; then
        _mensagec "${YELLOW}" "Alerta: Variavel 'CFG_USA_DBMAKER' nao definida"
        ((warnings++)) || true
    else
        _mensagec "${GREEN}" "OK: Configuracao de banco de dados definida"
    fi

    # Verificar diretorios essenciais
    local dirs=("biblioteca" "olds" "logs" "configuracoes" "binarios" "backup" "bases_backup" "enviar" "receber" "E_EXEC" "T_TELAS" "BASE1")
    local dir dir_path
    for dir in "${dirs[@]}"; do
        if [[ "$dir" == "E_EXEC" || "$dir" == "T_TELAS" || "$dir" == "BASE1" ]]; then
            dir_path="${!dir:-}"
        else
            dir_path="${SCRIPT_DIR}${!dir:-}"
        fi

        if [[ ! -d "${dir_path}" ]]; then
            _mensagec "${YELLOW}" "Alerta: Diretorio ${dir} nao encontrado: ${dir_path}"
            ((warnings++)) || true
        fi
    done

    # Verificar modo offline
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "n" ]]; then
            _mensagec "${WHITE}" "INFO: Servidor em modo On ..."
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

    return $erros
}

# -----------------------------------------------------------------------------
# Navegar para o diretorio de ferramentas
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_ir_para_tools() {
    if ! cd "${SCRIPT_DIR}"; then
        printf "Erro ao acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2
        return 1
    fi
    return 0
}

# =============================================================================
# LIMPEZA DE VARIAVEIS
# =============================================================================

# -----------------------------------------------------------------------------
# Lista consolidada de variaveis do sistema para limpeza
# -----------------------------------------------------------------------------
_SAV_VAR_LIST() {
    cat <<'VARS'
RED GREEN YELLOW BLUE PURPLE CYAN NORM WHITE
CFG_SISTEMA CFG_VERCLASS CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE CFG_BACKUP_PATH CFG_EMPRESA
VERSAOANT BASE1 BASE2 BASE3 SCRIPT_DIR RAIZ
CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 CFG_DIR
INI UMADATA E_EXEC T_TELAS X_XML
SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4
DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO DEFAULT_UNZIP REBUILD JUTIL ISCCLIENT ISCCLIENTT
DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_VERSAO DEFAULT_ARQUIVO DEFAULT_PEDARQ DEFAULT_PROG DEFAULT_IP_SERVER
DESTINO_BIBLIOTECA DESTINO_SERVER SAVISC base_trabalho
LIBS_DIR LOG LOG_ATU LOG_LIMPA LOG_TMP
UPDATE
VARS
}

# -----------------------------------------------------------------------------
# Limpar variaveis registradas
# -----------------------------------------------------------------------------
_limpar_estado_variaveis() {
    local var
    while IFS= read -r var; do
        # Pular linhas vazias
        [[ -z "$var" ]] && continue
        unset -v "$var" 2>/dev/null || true
    done < <(_SAV_VAR_LIST)

    # Resetar terminal
    tput sgr0 2>/dev/null || true
    return 0
}

# -----------------------------------------------------------------------------
# Resetar estado do sistema (usado pelo trap em principal.sh)
# -----------------------------------------------------------------------------
_resetando() {
    _limpar_estado_variaveis
    return 0
}

# -----------------------------------------------------------------------------
# Encerrar programa com status
# Parametros:
#   $1 - Status de saida (opcional, padrao: 0)
# -----------------------------------------------------------------------------
_encerrar_programa() {
    local status="${1:-0}"
    _limpar_estado_variaveis
    exit "$status"
}
