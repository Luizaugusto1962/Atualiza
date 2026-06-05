#!/usr/bin/env bash
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 01/06/2026-01

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================
set -o pipefail  # Falhar se qualquer comando em pipe falhar

# =============================================================================
# SISTEMA DE GERENCIAMENTO DE VARIÁVEIS
# =============================================================================
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-}"

# Desativar temporariamente set -u para evitar erros durante inicialização
# Será reativado após configuração completa
set +u

# Array para registrar todas as variáveis definidas (para limpeza automática)
declare -a REGISTRO_VARIAVEIS=()
# Array para registrar categorias de variáveis
declare -A REGISTRO_CATEGORIAS=()
# Contador de variáveis registradas
declare -g VAR_CONTADOR_REGISTRO=0

# Função para garantir que os arrays existam (proteção contra unbound variable)
_garantir_arrays() {
    # Garantir que REGISTRO_VARIAVEIS existe
    if ! declare -p REGISTRO_VARIAVEIS &>/dev/null; then
        declare -ga REGISTRO_VARIAVEIS=()
    fi
    
    # Garantir que REGISTRO_CATEGORIAS existe
    if ! declare -p REGISTRO_CATEGORIAS &>/dev/null; then
        declare -gA REGISTRO_CATEGORIAS=()
    fi
    
    # Garantir que VAR_CONTADOR_REGISTRO existe
    if ! declare -p VAR_CONTADOR_REGISTRO &>/dev/null; then
        declare -g VAR_CONTADOR_REGISTRO=0
    fi
}

# Chamar garantia de arrays imediatamente
_garantir_arrays

# Função para verificar se uma variável já está registrada
_var_ja_registrada() {
    local var_name="$1"
    local var
    
    # Garantir que o array existe
    _garantir_arrays
    
    # Verificar se o array existe e não está vazio
    if declare -p REGISTRO_VARIAVEIS &>/dev/null && [[ ${#REGISTRO_VARIAVEIS[@]} -gt 0 ]]; then
        for var in "${REGISTRO_VARIAVEIS[@]}"; do
            [[ "$var" == "$var_name" ]] && return 0
        done
    fi
    return 1
}

# Reativar set -u após inicialização (exceto para arrays gerenciados)
# Para variáveis de array, usar verificações explícitas
set -u

# Função para registrar uma variável no sistema
_register_var() {
    local var_name="$1"
    local var_value="$2"
    local var_category="${3:-OUTROS}"
    
    # Garantir arrays
    _garantir_arrays
    
    # Validar nome da variável
    if [[ -z "$var_name" ]]; then
        printf 'AVISO: Nome de variavel vazio, ignorando registro.\n' >&2
        return 1
    fi
    
    # Pular variáveis que não devem ser modificadas (readonly do principal.sh)
    # UPDATE é definida como readonly em principal.sh
    if [[ "$var_name" == "UPDATE" ]]; then
        return 0
    fi
    
    # Verificar se a variável já é readonly (não pode ser modificada)
    if [[ -o readonly && -v "$var_name" ]]; then
        # Variável é readonly, não tentar modificar
        return 0
    fi
    
    # Tentar verificar se é readonly dinamicamente
    # Verificar se a variável existe e não pode ser modificada
    if declare -p "$var_name" 2>/dev/null | grep -q 'declare -r'; then
        # Variável é readonly, não tentar modificar
        return 0
    fi
    
    # Verificar se já está registrada (evitar duplicatas)
    if _var_ja_registrada "$var_name"; then
        # Atualizar valor existente (somente se não for readonly)
        declare -g "$var_name"="$var_value" 2>/dev/null || true
        return 0
    fi
    
    # Definir a variável como global
    declare -g "$var_name"="$var_value" 2>/dev/null || {
        # Se falhou, pode ser readonly, ignorar
        printf 'AVISO: Nao foi possivel definir variavel %s (pode ser readonly).\n' "$var_name" >&2
        return 0
    }
    
    # Registrar para limpeza posterior
    REGISTRO_VARIAVEIS+=("$var_name")
    
    # Registrar categoria
    if [[ -n "${REGISTRO_CATEGORIAS[$var_category]+x}" ]]; then
        REGISTRO_CATEGORIAS["$var_category"]+=" $var_name"
    else
        REGISTRO_CATEGORIAS["$var_category"]="$var_name"
    fi
    
    # Incrementar contador
    ((VAR_CONTADOR_REGISTRO++)) || true
    
    return 0
}

# Função para registrar múltiplas variáveis de uma só vez
_register_vars_batch() {
    local var_category="${1:-OUTROS}"
    shift
    local var_def var_name var_value
    
    for var_def in "$@"; do
        var_name="${var_def%%=*}"
        var_value="${var_def#*=}"
        _register_var "$var_name" "$var_value" "$var_category"
    done
}

# Função para obter todas as variáveis de uma categoria
_get_vars_by_category() {
    local category="$1"
    echo "${REGISTRO_CATEGORIAS[$category]:-}"
}

# Função para verificar se uma variável é readonly
_is_var_readonly() {
    local var_name="$1"
    
    # Verificar usando declare -p
    local decl_output
    decl_output=$(declare -p "$var_name" 2>/dev/null)
    
    # Se o comando falhou, a variável não existe
    if [[ -z "$decl_output" ]]; then
        return 1
    fi
    
    # Verificar se contém declare -r (readonly) ou declare -rx (readonly + export)
    if [[ "$decl_output" == *"declare -r"* ]] || [[ "$decl_output" == *"declare -ir"* ]]; then
        return 0
    fi
    
    return 1
}

# Função para definir múltiplas variáveis de uma categoria
_define_category_vars() {
    local category="$1"
    shift
    local var_def
    
    for var_def in "$@"; do
        local var_name="${var_def%%=*}"
        local var_value="${var_def#*=}"
        
        # Pular variáveis readonly que já existem no ambiente
        if _is_var_readonly "$var_name"; then
            continue
        fi
        
        _register_var "$var_name" "$var_value" "$category"
    done
}

# =============================================================================
# DEFINIÇÕES DE VARIÁVEIS POR CATEGORIA
# =============================================================================

# Função para inicializar todas as variáveis do sistema
_inicializar_variaveis_sistema() {
    # Limpar registros anteriores
    REGISTRO_VARIAVEIS=()
    
    # CATEGORIA: CORES DO TERMINAL
    #_define_category_vars "CORES" \
        if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"    # Vermelho
        GREEN="${BOLD}$(tput setaf 2)"  # Verde
        YELLOW="${BOLD}$(tput setaf 3)" # Amarelo
        BLUE="${BOLD}$(tput setaf 4)"   # Azul
        PURPLE="${BOLD}$(tput setaf 5)" # Roxo
        CYAN="${BOLD}$(tput setaf 6)"   # Ciano
        WHITE="${BOLD}$(tput setaf 7)"  # Branco
        NORM="$(tput sgr0)"             # Normal (reset)
        COLUMNS=$(tput cols)                                # Numero de colunas do terminal

        # Limpar tela inicial
        tput clear 2>/dev/null || true
        tput bold 2>/dev/null || true
        tput setaf 7 2>/dev/null || true
    else
        # Terminal sem suporte a cores
        RED="\033[0;31m"
        GREEN="\033[0;32m"
        YELLOW="\033[0;33m"
        BLUE="\033[0;34m"
        PURPLE="\033[0;35m"
        CYAN="\033[0;36m"
        WHITE="\033[0;37m"
        NORM="\033[0m"
        COLUMNS=${COLUMNS:-80}
    fi
    export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NORM COLUMNS

    # CATEGORIA: CONFIGURAÇÕES DE ATUALIZAÇÃO
    _define_category_vars "ATUALIZACAO" \
        "CFG_SISTEMA=${CFG_SISTEMA:-}" \
        "CFG_VERCLASS=${CFG_VERCLASS:-}" \
        "CFG_USA_DBMAKER=${CFG_USA_DBMAKER:-}" \
        "CFG_ACESSO_SSH=${CFG_ACESSO_SSH:-}" \
        "CFG_OFFLINE=${CFG_OFFLINE:-}" \
        "CFG_BACKUP_PATH=${CFG_BACKUP_PATH:-}" \
        "CFG_EMPRESA=${CFG_EMPRESA:-}" \
        "VERSAOANT=${VERSAOANT:-}"
    
    # CATEGORIA: CAMINHOS E DIRETÓRIOS
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
    
    # CATEGORIA: BIBLIOTECA SAV
    _define_category_vars "BIBLIOTECA" \
        "SAVATU=${SAVATU:-}" \
        "SAVATU1=${SAVATU1:-}" \
        "SAVATU2=${SAVATU2:-}" \
        "SAVATU3=${SAVATU3:-}" \
        "SAVATU4=${SAVATU4:-}"
    
    # CATEGORIA: COMANDOS DO SISTEMA
    _define_category_vars "COMANDOS" \
        "DEFAULT_ZIP=${DEFAULT_ZIP:-}" \
        "DEFAULT_FIND=${DEFAULT_FIND:-}" \
        "DEFAULT_WHO=${DEFAULT_WHO:-}" \
        "DEFAULT_UNZIP=${DEFAULT_UNZIP:-}" \
        "REBUILD=${REBUILD:-}" \
        "JUTIL=${JUTIL:-}" \
        "ISCCLIENT=${ISCCLIENT:-}" \
        "ISCCLIENTT=${ISCCLIENTT:-}"
    
    # CATEGORIA: CONFIGURAÇÕES DIVERSAS
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
    # NOTA: UPDATE é definida como readonly em principal.sh e não deve ser modificada
    
    # CATEGORIA: LOGS
    _define_category_vars "LOGS" \
        "LOG=${LOG:-}" \
        "LOG_ATU=${LOG_ATU:-}" \
        "LOG_LIMPA=${LOG_LIMPA:-}" \
        "LOG_TMP=${LOG_TMP:-}"
}

#-Variaveis de configuracao do sistema ---------------------------------------------------------#
# Variaveis de configuracao do sistema que podem ser definidas pelo usuario.
# As variaveis com o prefixo "destino" sao usadas para definir o caminho
# dos diretorios que serao usados pelo programa.

RAIZ="${RAIZ:-}"                                 # Caminho do diretorio RAIZ do programa.
CFG_DIR="${CFG_DIR:-}"                           # Caminho do diretorio de configuracao do programa.
REBUILD="${REBUILD:-}"                           # Caminho do utilitario jutil.

# Criar diretorio de configuracao se especificado e nao existir
if [[ -n "${CFG_DIR}" ]]; then
    if [[ ! -d "${CFG_DIR}" ]]; then
        mkdir -p "${CFG_DIR}" || {
            printf '%s\n' "ERRO: Nao foi possivel criar o diretorio de configuracao '${CFG_DIR}'." >&2
            return 1
        }
    fi
    # PERMISSAO CORRIGIDA: usar constante ao inves de hardcoded
    chmod "${PERM_DIR_SECURE}" "${CFG_DIR}" 2>/dev/null || {
        printf '%s\n' "AVISO: Nao foi possivel ajustar permissao em '${CFG_DIR}'." >&2
    }
fi

# =============================================================================
# Variaveis de configuracao do sistema que podem ser definidas pelo usuario.
# =============================================================================
DEFAULT_LOGS_DIR="${DEFAULT_LOGS_DIR:-}"                           # Diretório de logs padrão

# -----------------------------------------------------------------------------
# Configurar comandos do sistema
# Retorna: 0 se todos os comandos existirem, 1 caso contrario
# -----------------------------------------------------------------------------
_configurar_comandos() {

    # Validar se os comandos existem
    # CORRECAO: era ("$DEFAULT_ZIP" "$DEFAULT_ZIP") — duplicado; corrigido para incluir DEFAULT_UNZIP
    local cmds=("$DEFAULT_ZIP" "$DEFAULT_UNZIP")
    local cmd=""
    local missing=()

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

    # Criar diretorio de configuracao se nao existir - usando funcao centralizada
    local caminho="${CFG_DIR}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }


    # Criar diretorios se nao existirem - usando funcao centralizada
    local dirs=("${DEFAULT_BIBLIOTECA_ATUAL_DIR}" "${DEFAULT_BIBLIOTECA_DIR}" "${DEFAULT_BASEBACKUP_DIR}" "${DEFAULT_OLDS_DIR}" "${DEFAULT_PROGS_DIR}" "${DEFAULT_LOGS_DIR}" "${DEFAULT_ENVIA_DIR}" "${DEFAULT_RECEBE_DIR}" "${DEFAULT_BACKUP_DIR}")
    local dir=""
    for dir in "${dirs[@]}"; do
        _criar_diretorio_seguro "${dir}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
            printf "Erro ao criar diretorio %s\n" "${dir}" >&2
            return 1
        }
    done
}

# -----------------------------------------------------------------------------
# Configurar variaveis do sistema
# -----------------------------------------------------------------------------
_configurar_variaveis_sistema() {
#    CFG_OFFLINE="${CFG_OFFLINE:-${RAIZ}/portalsav/Atualiza}"                                 # Diretorio do servidor offline

    if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then

        # Caminhos dos executaveis e dados
        E_EXEC="${E_EXEC:-${RAIZ}/classes}"      # Diretorio de executaveis para Iscobol
        T_TELAS="${T_TELAS:-${RAIZ}/tel_isc}"    # Diretorio de telas para Iscobol
        X_XML="${X_XML:-${RAIZ}/xml}"            # Diretorio de xmls para Iscobol
        BASE1="${BASE1:-${RAIZ}${CFG_BASE_DIR}}"         # Base de dados principal
        BASE2="${BASE2:-${RAIZ}${CFG_BASE_DIR2}}"        # Segunda base de dados
        BASE3="${BASE3:-${RAIZ}${CFG_BASE_DIR3}}"        # Terceira base de dados
        export E_EXEC T_TELAS X_XML BASE1 BASE2 BASE3 CFG_OFFLINE
    else
        E_EXEC="${E_EXEC:-${RAIZ}/int}"
        T_TELAS="${T_TELAS:-${RAIZ}/tel}"
        BASE1="${BASE1:-${RAIZ}${CFG_BASE_DIR}}"
        BASE2="${BASE2:-${RAIZ}${CFG_BASE_DIR2}}"
        BASE3="${BASE3:-${RAIZ}${CFG_BASE_DIR3}}"
        export E_EXEC T_TELAS BASE1 BASE2 BASE3 CFG_OFFLINE
    fi

    # Gerar sufixos de arquivos com base no tipo de compilacao.
    if [[ "${CFG_SISTEMA}" = "iscobol" ]]; then
        verclass_sufixo="${CFG_VERCLASS: -2}"
        compilado="-class${verclass_sufixo}"
        debugado="-mclass${verclass_sufixo}"
#   Bibliotecas Iscobol
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
        compilado="-${compilado:-6}"
        debugado="-${debugado:-m6}"
#   Bibliotecas Isam
        SAVATU1="tempSAVintA_"
        SAVATU2="tempSAVintB_"
        SAVATU3="tempSAVtel_"
        SAVATU="tempSAV????_"
    fi
    export SAVATU1 SAVATU2 SAVATU3 SAVATU4 SAVATU
}

# -----------------------------------------------------------------------------
# Valida o conteudo de um arquivo de configuracao de forma RIGOROSA
# Verifica se o arquivo contem apenas atribuicoes de variaveis simples
# Parâmetros:
#   $1 - Caminho do arquivo de configuracao
# Retorna: 0 se valido, 1 se invalido
# -----------------------------------------------------------------------------
_validar_config_file() {
    local CONFIG_FILE="${1}"
    local linha=""
    local num_linha=0
    local erros=0

    if [[ ! -f "$CONFIG_FILE" ]]; then
        printf "ERRO: Arquivo de configuracao nao encontrado: %s\n" "$CONFIG_FILE" >&2
        return 1
    fi

    # Verificar permissoes do arquivo
    if [[ ! -r "$CONFIG_FILE" ]]; then
        printf "ERRO: Arquivo de configuracao sem permissao de leitura: %s\n" "$CONFIG_FILE" >&2
        return 1
    fi

    # Verificar se arquivo nao e muito grande (limite: 1MB)
    local tamanho
    tamanho=$(wc -c < "$CONFIG_FILE" 2>/dev/null || echo 0)
    if (( tamanho > 1048576 )); then
        printf "ERRO: Arquivo de configuracao muito grande: %d bytes\n" "$tamanho" >&2
        return 1
    fi

    # Ler linha por linha e validar RIGOROSAMENTE
    while IFS= read -r linha || [[ -n "$linha" ]]; do
        ((num_linha++))

        # Pular linhas vazias e comentarios
        [[ -z "$linha" ]] && continue
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue

        # Pular espacos iniciais para analise
        linha="${linha#"${linha%%[![:space:]]*}"}"

        # Ignorar linhas apos comentario inline
        if [[ "$linha" == *'#'* ]]; then
            linha="${linha%%#*}"
        fi

        # Ignorar se a linha ficou vazia apos remover comentario
        [[ -z "$linha" ]] && continue

        # Validar que e uma atribuicao de variavel simples
        # Formato esperado: VARIAVEL="valor" ou VARIAVEL='valor' ou VARIAVEL=valor
        if ! [[ "$linha" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            printf "ERRO: Linha %d tem formato invalido: %s\n" "$num_linha" "$linha" >&2
            ((erros++))
            return 1
        fi

        # Verificar se ha comandos potencialmente perigosos
        # Lista expandida de caracteres perigosos
        if printf '%s\n' "$linha" | grep -qE '[\$\`\;|\&<>(){}]'; then
            printf "ERRO: Linha %d contem caracteres perigosos: %s\n" "$num_linha" "$linha" >&2
            ((erros++))
            return 1
        fi

        # Verificar se ha tentativas de command substitution
        if [[ "$linha" =~ \$\( ]] || [[ "$linha" =~ \` ]]; then
            printf "ERRO: Linha %d contem command substitution: %s\n" "$num_linha" "$linha" >&2
            ((erros++))
            continue
        fi

        # Verificar se ha tentativas de expansao de variavel suspeita
        if [[ "$linha" =~ \$\{.*\} ]]; then
            printf "ERRO: Linha %d contem expansao de variavel suspeita: %s\n" "$num_linha" "$linha" >&2
            ((erros++))
            continue
        fi

    done < "$CONFIG_FILE"

    if (( erros > 0 )); then
        printf "ERRO: Arquivo de configuracao contem %d erro(s). Carregamento bloqueado.\n" "$erros" >&2
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Carregar arquivo de configuracao da empresa com validacao SEGURA
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_config_empresa() {
    local CONFIG_FILE="${CFG_DIR}/.config"

    # Verificar se o arquivo de configuracao existe e tem permissao de leitura
    if [[ ! -e "${CONFIG_FILE}" ]]; then
        printf "ERRO: Arquivo de configuracao nao existe no diretorio.\n" >&2
        printf "ATENCAO: Execute './atualiza.sh --setup' para criar as configuracoes.\n" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    if [[ ! -r "${CONFIG_FILE}" ]]; then
        printf "ERRO: Arquivo %s sem permissao de leitura.\n" "${CONFIG_FILE}" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    # Validar conteudo do arquivo antes de carregar - MEDIDA DE SEGURANCA
    if ! _validar_config_file "${CONFIG_FILE}"; then
        printf "ERRO: Arquivo de configuracao contem formato invalido ou comandos suspeitos.\n" >&2
        printf "AVISO: Carregamento do arquivo de configuracao bloqueado por seguranca.\n" >&2
        if command -v _aguardar >/dev/null 2>&1; then
            _aguardar 2 2>/dev/null || true
        fi
        return 1
    fi

    # Carregar configuracoes de forma SEGURA (sem sourcing direto)
    if ! _carregar_config_seguro "${CONFIG_FILE}"; then
        printf "ERRO: Falha ao carregar arquivo de configuracao %s.\n" "${CONFIG_FILE}" >&2
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

    # Carregar arquivos de configuracao
    _carregar_config_empresa || return 1

    # Configurar comandos
    _configurar_comandos || return 1

    # Configurar diretorios
    _configurar_diretorios || return 1

    # Configurar variaveis do sistema
    _configurar_variaveis_sistema

}

# -----------------------------------------------------------------------------
# Funcao para validar diretorios essenciais
# Retorna: 0 se todos validos, 1 se algum invalido
# -----------------------------------------------------------------------------
_validar_diretorios() {
    local erros=0

    # Funcao auxiliar para verificar diretorio
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

    # Verificar diretorios essenciais
    _verifica_diretorio "${E_EXEC}" || ((erros++))
    _verifica_diretorio "${T_TELAS}" || ((erros++))
    _verifica_diretorio "${BASE1}" || ((erros++))

    # Verificar XML apenas se for IsCOBOL
    if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then
        _verifica_diretorio "${X_XML}" || ((erros++))
    fi

    # Verificar bases adicionais se configuradas
    if [[ -n "${BASE2}" ]]; then
        _verifica_diretorio "${BASE2}" || ((erros++))
    fi

    if [[ -n "${BASE3}" ]]; then
        _verifica_diretorio "${BASE3}" || ((erros++))
    fi

    return $erros
}

# -----------------------------------------------------------------------------
# Configurar ambiente final
# Retorna: 0 sempre
# -----------------------------------------------------------------------------
_configurar_ambiente() {
    # Verificar se o jutil existe para sistemas IsCOBOL
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
# Funcao para validar a configuracao atual do sistema
_validar_configuracao() {
    _limpa_tela
    _linha "=" "${GREEN}"
    _mensagec "${RED}" "Validacao de Configuracao"
    _linha
    
    local erros=0
    local warnings=0
    
    # Verificar arquivos de configuracao
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo .config nao encontrado!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Arquivo .config encontrado"
    fi

    # Verificar variaveis essenciais
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
    
    if [[ -z "${CFG_USA_DBMAKER}" ]]; then
        _mensagec "${YELLOW}" "Alerta: Variavel 'CFG_USA_DBMAKER' nao definida"
        ((warnings++)) || true
    else
        _mensagec "${GREEN}" "OK: Configuracao de banco de dados definida"
    fi
   
    
    # Verificar diretorios essenciais
    local dirs=("biblioteca" "olds" "logs" "configuracoes" "binarios" "backup" "bases_backup" "enviar" "receber" "E_EXEC" "T_TELAS" "BASE1")
    for dir in "${dirs[@]}"; do
        local dir_path=""
        # Tratamento especial para E_EXEC e T_TELAS que ficam em ${RAIZ}
        if [[ "$dir" == "E_EXEC" ]] || [[ "$dir" == "T_TELAS" ]] || [[ "$dir" == "BASE1" ]]; then
            dir_path="${!dir:-}"
        else
            # Para outros diretorios, usar o caminho padrao
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

    # Resumo sempre visivel, independente da configuracao de Offline
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
# SISTEMA DE LIMPEZA DE VARIÁVEIS
# =============================================================================

# Função para verificar se uma variável existe
_var_existe() {
    local var_name="$1"
    [[ -n "${!var_name+x}" ]]
}

# Função melhorada para limpar variáveis registradas
_limpar_estado_variaveis() {
    local var_count=0
    local var

    # Verificar se o array REGISTRO_VARIAVEIS realmente existe (seguro com set -u)
    # Usar declare -p é a forma confiável: ${array[*]+x} pode falhar se o array
    # nunca foi declarado como array indexado no contexto atual.
    if ! declare -p REGISTRO_VARIAVEIS &>/dev/null; then
        # Array não existe, apenas resetar terminal e sair
        tput sgr0 2>/dev/null || true
        return 0
    fi

    # Fazer cópia segura do array para evitar problemas durante iteração
    local vars_copy=()
    if [[ ${#REGISTRO_VARIAVEIS[@]} -gt 0 ]]; then
        vars_copy=("${REGISTRO_VARIAVEIS[@]}")
    fi

    for var in "${vars_copy[@]:-}"; do
        # Ignorar entradas vazias
        [[ -z "$var" ]] && continue
        # Verificar se a variável ainda existe
        if [[ -n "${!var+x}" ]]; then
            unset -v "$var" 2>/dev/null || true
            ((var_count++)) || true
        fi
    done

    # Limpar array de registro
    REGISTRO_VARIAVEIS=()

    # Limpar arrays de categorias (verificação segura com declare -p)
    if declare -p REGISTRO_CATEGORIAS &>/dev/null; then
        unset REGISTRO_CATEGORIAS 2>/dev/null || true
        declare -A REGISTRO_CATEGORIAS=()
    fi

    # Limpar contador
    unset -v VAR_CONTADOR_REGISTRO 2>/dev/null || true

    # Resetar terminal
    tput sgr0 2>/dev/null || true

    return 0
}

# Função para limpar variáveis de uma categoria específica
_limpar_categoria() {
    local category="$1"
    local vars=""
    local var

    # Verificar existência de REGISTRO_CATEGORIAS de forma segura (set -u compatível)
    if ! declare -p REGISTRO_CATEGORIAS &>/dev/null; then
        return 0
    fi

    vars="${REGISTRO_CATEGORIAS[$category]:-}"

    if [[ -z "$vars" ]]; then
        return 0
    fi

    for var in $vars; do
        if [[ -n "${!var+x}" ]]; then
            unset -v "$var" 2>/dev/null || true
        fi
    done

    # Remover categoria do registro
    unset "REGISTRO_CATEGORIAS[$category]"
}

# Função para limpeza de emergência (sem dependências)
_limpeza_emergencia() {
    # Lista hardcoded para casos extremos
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

# Função para configurar limpeza automática ao sair
_configurar_limpeza_automatica() {
    # Configurar trap para limpeza ao sair
    trap '_limpar_estado_variaveis' EXIT
    trap '_limpar_estado_variaveis' INT
    trap '_limpar_estado_variaveis' TERM
    
    # Registrar função de limpeza de emergência para SIGKILL (não capturável, mas boa prática)
    trap '_limpeza_emergencia' QUIT
}

# Função principal de inicialização do sistema de variáveis
_inicializar_sistema_variaveis() {
    # Reinicializar arrays para garantir estado limpo
    REGISTRO_VARIAVEIS=()
    declare -A REGISTRO_CATEGORIAS=()
    VAR_CONTADOR_REGISTRO=0
    
    # Inicializar todas as variáveis
    _inicializar_variaveis_sistema
    
    # Configurar limpeza automática
    _configurar_limpeza_automatica
    
    # Marcar sistema como inicializado
    _register_var "SISTEMA_VARIAVEIS_INICIALIZADO" "true" "SISTEMA"
}

# Função para obter estatísticas do registro de variáveis
_status_registro_variaveis() {
    local categoria="${1:-}"
    
    if [[ -n "$categoria" ]]; then
        local vars="${REGISTRO_CATEGORIAS[$categoria]:-}"
        local count=0
        for _ in $vars; do ((count++)); done
        printf '%s: %d variaveis\n' "$categoria" "$count"
    else
        printf 'Total de variaveis registradas: %d\n' "${VAR_CONTADOR_REGISTRO:-0}"
        printf 'Total de categorias: %d\n' "${#REGISTRO_CATEGORIAS[@]}"
        printf '\nCategorias registradas:\n'
        local cat
        for cat in "${!REGISTRO_CATEGORIAS[@]}"; do
            printf '  - %s\n' "$cat"
        done
    fi
}

# -----------------------------------------------------------------------------
# Funcao para resetar variaveis (cleanup) - VERSÃO LEGADA (mantida para compatibilidade)
# -----------------------------------------------------------------------------
_limpar_estado_variaveis_legado() {
    # Versão legada mantida para compatibilidade
    # Usar _limpar_estado_variaveis() para a nova implementação
    
    # Lista de variáveis para limpar (sem usar arrays)
    local vars_cores="RED GREEN YELLOW BLUE PURPLE CYAN NORM"
    local vars_atualizac="CFG_SISTEMA CFG_VERCLASS CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE CFG_BACKUP_PATH CFG_EMPRESA VERSAOANT"
    local vars_caminhos="BASE1 BASE2 BASE3 SCRIPT_DIR RAIZ CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 biblioteca bases_backup logs olds configuracoes binarios envia recebe"
    local vars_caminhos2="INI UMADATA CFG_OFFLINE E_EXEC T_TELAS X_XML"
    local vars_biblioteca="SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4"
    local vars_comandos="DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO DEFAULT_UNZIP REBUILD JUTIL ISCCLIENT ISCCLIENTT"
    local vars_outros="DEFAULT_SSH_PORTA DEFAULT_SSH_USER VERSAO SAVISC DEFAULT_VERSAO DEFAULT_ARQUIVO DEFAULT_PEDARQ DEFAULT_PROG DEFAULT_IP_SERVER UPDATE CFG_OFFLINE base_trabalho"
    local vars_logs="LOG LOG_ATU LOG_LIMPA LOG_TMP"
    
    # Função auxiliar para limpar variáveis
    _unset_vars() {
        local var
        for var in $1; do
            unset -v "$var" 2>/dev/null || true
        done
    }
    
    # Limpar todas as categorias
    _unset_vars "$vars_cores"
    _unset_vars "$vars_atualizac"
    _unset_vars "$vars_caminhos"
    _unset_vars "$vars_caminhos2"
    _unset_vars "$vars_biblioteca"
    _unset_vars "$vars_comandos"
    _unset_vars "$vars_outros"
    _unset_vars "$vars_logs"

    tput sgr0 2>/dev/null || true
}
# -----------------------------------------------------------------------------
# Resetar estado do sistema
# -----------------------------------------------------------------------------
_resetando() {
    # Usar o novo sistema de limpeza se disponível
    if [[ "${SISTEMA_VARIAVEIS_INICIALIZADO:-}" == "true" ]]; then
        _limpar_estado_variaveis
    else
        # Fallback para versão legada
        _limpar_estado_variaveis_legado
    fi
    return 0
}

# Função para finalizar o sistema (chamada ao sair do programa principal)
_finalizar_sistema() {
    # Limpar todas as variáveis registradas
    _limpar_estado_variaveis
    
    # Remover traps
    trap - EXIT INT TERM QUIT
    
    # Resetar terminal final
    tput sgr0 2>/dev/null || true
    
    # Mensagem de finalização (opcional)
    # printf '[%s] Sistema finalizado e variaveis limpas.\n' "$(date '+%Y-%m-%d %H:%M:%S')" >&2
}

# -----------------------------------------------------------------------------
# Encerrar programa com status
# Parâmetros:
#   $1 - Status de saída (opcional, padrão: 0)
# -----------------------------------------------------------------------------
_encerrar_programa() {
    local status="${1:-0}"
    _finalizar_sistema
    exit "$status"
}

# NOTA: Os traps abaixo sao registrados aqui pois config.sh e sourced antes de principal.sh
# definir seus proprios traps em _main(). Os traps de _main() sobrescrevem estes ao ser chamados.
# Isso garante limpeza mesmo se o carregamento falhar antes de _main() ser executada.
trap '_encerrar_programa' EXIT INT TERM
trap '_limpeza_emergencia' QUIT
