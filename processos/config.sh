#!/usr/bin/env bash
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 11/05/2026-02

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

# =============================================================================
# VARIÁVEIS GLOBAIS DOCUMENTADAS
# =============================================================================

# Listas para organizacao das variaveis
declare -a CORES="RED GREEN YELLOW BLUE PURPLE CYAN NORM"
declare -a ATUALIZAC="CFG_SISTEMA CFG_VERCLASS CFG_USA_DBMAKER CFG_ACESSO_SSH CFG_OFFLINE CFG_BACKUP_PATH CFG_EMPRESA VERSAOANT"
declare -a CAMINHOS_BASE="BASE1 BASE2 BASE3 SCRIPT_DIR RAIZ CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3 biblioteca bases_backup logs olds configuracoes processos envia recebe"
declare -a CAMINHOS_BASE2="INI UMADATA CFG_OFFLINE E_EXEC T_TELAS X_XML"
declare -a BIBLIOTECA_SAV="SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4"
declare -a COMANDOS="DEFAULT_ZIP DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO DEFAULT_UNZIP DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO REBUILD JUTIL ISCCLIENT ISCCLIENTT"
declare -a OUTROS="DEFAULT_SSH_PORTA DEFAULT_SSH_USER VERSAO SAVISC DEFAULT_VERSAO DEFAULT_ARQUIVO DEFAULT_PEDARQ DEFAULT_PROG DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER UPDATE JUTIL ISCCLIENT CFG_OFFLINE base_trabalho"
declare -a LOGIS="LOG LOG_ATU LOG_LIMPA LOG_TMP"

#-Variaveis de configuracao do sistema ---------------------------------------------------------#
# Variaveis de configuracao do sistema que podem ser definidas pelo usuario.
# As variaveis com o prefixo "destino" sao usadas para definir o caminho
# dos diretorios que serao usados pelo programa.

RAIZ="${RAIZ:-}"                                 # Caminho do diretorio RAIZ do programa.
CFG_DIR="${CFG_DIR:-}"                           # Caminho do diretorio de configuracao do programa.
REBUILD="${REBUILD:-}"                                   # Caminho do utilitario jutil.

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
LIB_DIR="${LIB_DIR:-}"                                      # Caminho do diretorio de bibliotecas do programa.
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                            # Caminho do diretorio da base de dados.
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"                          # Caminho do diretorio da segunda base de dados.
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"                          # Caminho do diretorio da terceira base de dados.
DEFAULT_BACKUP_DIR="${DEFAULT_BACKUP_DIR:-}"                # Diretório de backup padrão
DEFAULT_LOGS_DIR="${DEFAULT_LOGS_DIR:-}"                    # Diretório de logs padrão
DEFAULT_BIBLIOTECA_DIR="${DEFAULT_BIBLIOTECA_DIR:-}"        # Diretório de biblioteca padrão
DEFAULT_BASEBACKUP_DIR="${DEFAULT_BASEBACKUP_DIR:-}"        # Diretório de backup de base padrão
DEFAULT_OLDS_DIR="${DEFAULT_OLDS_DIR:-}"                    # Diretório de arquivos antigos padrão
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-}"                  # Diretório de programas padrão
DEFAULT_ENVIA_DIR="${SCRIPT_DIR}/enviar"                     # Diretório de envio padrão
DEFAULT_RECEBE_DIR="${SCRIPT_DIR}/receber"                   # Diretório de recebimento padrão
CFG_SISTEMA="${CFG_SISTEMA:-}"                              # Tipo de sistema que esta sendo usado (iscobol ou isam).
SAVATU="${SAVATU:-}"                                        # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU1="${SAVATU1:-}"                                      # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU2="${SAVATU2:-}"                                      # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU3="${SAVATU3:-}"                                      # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU4="${SAVATU4:-}"                                      # Caminho do diretorio da biblioteca do servidor da SAV.
CFG_VERCLASS="${CFG_VERCLASS:-}"                            # Tipo de compilacao do Iscobol.
CFG_USA_DBMAKER="${CFG_USA_DBMAKER:-}"                      # Variavel que define o tipo de banco de dados usado pelo sistema.
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-}"                      # Variavel que define o caminho para onde sera enviado o backup.
VERSAO="${VERSAO:-}"                                        # Variavel que define a versao do programa.
INI="${INI:-}"                                              # Variavel que define o caminho do arquivo de configuracao do sistema.
CFG_OFFLINE="${CFG_OFFLINE:-}"                              # Variavel que define se o sistema esta em modo offline (s/n).
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"                # Variavel que define o caminho do diretorio de recebimento offline.
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-}"                        # Variavel que define se o SSH esta habilitado (s/n).
VERSAOANT="${VERSAOANT:-}"                                  # Variavel que define a versao do programa anterior.
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"                          # Comando para descompactar arquivos.
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                              # Comando para compactar arquivos.
DEFAULT_FIND="${DEFAULT_FIND:-}"                            # Comando para buscar arquivos.
DEFAULT_WHO="${DEFAULT_WHO:-}"                              # Comando para saber quem esta logado no sistema.
DEFAULT_SSH_PORTA="${DEFAULT_SSH_PORTA:-}"                  # Variavel que define a porta a ser usada para SSH
DEFAULT_SSH_USER="${DEFAULT_SSH_USER:-}"                    # Variavel que define o usuario a ser usado para SSH
DESTINO_BIBLIOTECA="${DESTINO_BIBLIOTECA:-}"                # Variavel que define o caminho do diretorio da biblioteca do servidor da SAV.
RED="${RED:-}"                                              # Cor vermelha
GREEN="${GREEN:-}"                                          # Cor verde
YELLOW="${YELLOW:-}"                                        # Cor amarela
BLUE="${BLUE:-}"                                            # Cor azul
PURPLE="${PURPLE:-}"                                        # Cor roxa
CYAN="${CYAN:-}"                                            # Cor ciano
NORM="${NORM:-}"                                            # Cor normal
COLUMNS="${COLUMNS:-}"                                      # Numero de colunas do terminal
LOG="${LOG:-}"                                              # Variavel que define o caminho do arquivo de log.
LOG_ATU="${LOG_ATU:-}"                                      # Variavel que define o caminho do arquivo de log de atualizacao.
LOG_LIMPA="${LOG_LIMPA:-}"                                  # Variavel que define o caminho do arquivo de log de limpeza.
LOG_TMP="${LOG_TMP:-}"                                      # Variavel que define o caminho do arquivo de log temporario.
UMADATA="${UMADATA:-}"                                      # Variavel que define o caminho do arquivo de dados da UMA.
ISCCLIENT="${ISCCLIENT:-}"                                  # Variavel que define o caminho do cliente ISC.
base_trabalho="${base_trabalho:-}"                          # Variavel que define o caminho do diretorio de trabalho.

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

# -----------------------------------------------------------------------------
# Funcao para definir cores do terminal
# -----------------------------------------------------------------------------
_definir_cores() {
    # Verificar se o terminal suporta cores
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        RED=$(tput bold; tput setaf 1 2>/dev/null)          # Vermelho
        GREEN=$(tput bold; tput setaf 2 2>/dev/null)        # Verde
        YELLOW=$(tput bold; tput setaf 3 2>/dev/null)       # Amarelo
        BLUE=$(tput bold; tput setaf 4 2>/dev/null)         # Azul
        PURPLE=$(tput bold; tput setaf 5 2>/dev/null)       # Roxo
        CYAN=$(tput bold; tput setaf 6 2>/dev/null)         # Ciano
        WHITE=$(tput bold; tput setaf 7 2>/dev/null)        # Branco
        NORM=$(tput sgr0 2>/dev/null)                       # Normal
        COLUMNS=$(tput cols)                                # Numero de colunas do terminal

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
        COLUMNS=${DEFAULT_COLUMNS}
    fi

    export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NORM COLUMNS
}

# -----------------------------------------------------------------------------
# Configurar comandos do sistema
# Retorna: 0 se todos os comandos existirem, 1 caso contrario
# -----------------------------------------------------------------------------
_configurar_comandos() {

    # Validar se os comandos existem
    local cmds=("$DEFAULT_ZIP" "$DEFAULT_ZIP" "$DEFAULT_FIND" "$DEFAULT_WHO")
    local cmd=""
    local missing=()

    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "Erro: Comandos nao encontrados: %s\n" "${missing[*]}" >&2
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
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
    _criar_diretorio_seguro "${CFG_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${CFG_DIR}" >&2
        return 1
    }


    # Criar diretorios se nao existirem - usando funcao centralizada
    local dirs=("${DEFAULT_BIBLIOTECA_DIR}" "${DEFAULT_BASEBACKUP_DIR}" "${DEFAULT_OLDS_DIR}" "${DEFAULT_PROGS_DIR}" "${DEFAULT_LOGS_DIR}" "${DEFAULT_ENVIA_DIR}" "${DEFAULT_RECEBE_DIR}" "${DEFAULT_BACKUP_DIR}")
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

    # Configurar logs
    LOG_ATU="${LOG_ATU:-${DEFAULT_LOGS_DIR}/atualiza.$(date +"%Y-%m-%d").log}"
    LOG_LIMPA="${LOG_LIMPA:-${DEFAULT_LOGS_DIR}/limpando.$(date +"%Y-%m-%d").log}"
    LOG_TMP="${LOG_TMP:-${DEFAULT_LOGS_DIR}/}"

    # Data atual formatada - CORRIGIDO: com aspas
    UMADATA="${UMADATA:-$(date +"%d-%m-%Y_%H%M%S")}"

    # Arquivo de backup padrao - CORRIGIDO: com aspas
    INI="${INI:-backup-${VERSAO}.zip}"

    # Gerar sufixos de arquivos com base no tipo de compilacao.
    if [[ "${CFG_SISTEMA}" = "iscobol" ]]; then
        verclass_sufixo="${CFG_VERCLASS: -2}"
        class="-class${verclass_sufixo}"
        mclass="-mclass${verclass_sufixo}"
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
        class="-${class:-6}"
        mclass="-${mclass:-m6}"
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
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
        fi
        return 1
    fi

    if [[ ! -r "${CONFIG_FILE}" ]]; then
        printf "ERRO: Arquivo %s sem permissao de leitura.\n" "${CONFIG_FILE}" >&2
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
        fi
        return 1
    fi

    # Validar conteudo do arquivo antes de carregar - MEDIDA DE SEGURANCA
    if ! _validar_config_file "${CONFIG_FILE}"; then
        printf "ERRO: Arquivo de configuracao contem formato invalido ou comandos suspeitos.\n" >&2
        printf "AVISO: Carregamento do arquivo de configuracao bloqueado por seguranca.\n" >&2
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
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
# Carrega configuracao de forma segura sem sourcing direto
# Parametros: $1 - arquivo de configuracao
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_config_seguro() {
    local CONFIG_FILE="${1}"
    local linha key value

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        # Pular linhas vazias e comentarios
        [[ -z "$linha" ]] && continue
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue

        # Remover espacos iniciais
        linha="${linha#"${linha%%[![:space:]]*}"}"
        
        # Ignorar linhas apos comentario inline
        if [[ "$linha" == *'#'* ]]; then
            linha="${linha%%#*}"
        fi

        # Ignorar se a linha ficou vazia apos remover comentario
        [[ -z "$linha" ]] && continue

        # Extrair chave e valor de forma segura
        if [[ "$linha" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            
            # Remover aspas se presentes
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            # Validar que o valor nao contem comandos perigosos
            if [[ "$value" =~ [\$\`\;] ]]; then
                printf "AVISO: Valor suspeito ignorado para %s: %s\n" "$key" "$value" >&2
                continue
            fi
            
            # Declarar variavel de forma segura
            declare -g "$key=$value"
        fi
    done < "$CONFIG_FILE"

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

    # Carregar arquivos de configuracao
    _carregar_config_empresa || return 1

    # Configurar comandos
    _configurar_comandos || return 1

    # Configurar diretorios
    _configurar_diretorios || return 1

    # Configurar variaveis do sistema
    _configurar_variaveis_sistema

    # Configurar acesso offline
    #_configurar_acessos

    # Verificar e remover diretorio .ssh se existir
    _verificar_remover_ssh
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
    local dirs=("biblioteca" "olds" "logs" "configuracoes" "processos" "backup" "bases_backup" "envia" "recebe" "E_EXEC" "T_TELAS" "BASE1")
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
# Verificar e remover diretorio .ssh dentro de SCRIPT_DIR se existir
# Retorna: 0 sempre
# -----------------------------------------------------------------------------
_verificar_remover_ssh() {
    if [[ -z "${SCRIPT_DIR:-}" ]]; then
        return 1
    fi
    local ssh_dir="${SCRIPT_DIR}/.ssh"
    if [[ -d "${ssh_dir}" ]]; then
        rm -rf "${ssh_dir}" || {
            printf "AVISO: Nao foi possivel remover o diretorio %s\n" "${ssh_dir}" >&2
            return 1
        }
    fi
    return 0
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

# -----------------------------------------------------------------------------
# Funcao para resetar variaveis (cleanup)
# -----------------------------------------------------------------------------
_limpar_estado_variaveis() {
    unset -v "${CORES[@]}" 2>/dev/null || true
    unset -v "${ATUALIZAC[@]}" 2>/dev/null || true
    unset -v "${CAMINHOS_BASE[@]}" 2>/dev/null || true
    unset -v "${CAMINHOS_BASE2[@]}" 2>/dev/null || true
    unset -v "${BIBLIOTECA_SAV[@]}" 2>/dev/null || true
    unset -v "${COMANDOS[@]}" 2>/dev/null || true
    unset -v "${OUTROS[@]}" 2>/dev/null || true
    unset -v "${LOGIS[@]}" 2>/dev/null || true

    tput sgr0 2>/dev/null || true
}
# -----------------------------------------------------------------------------
# Resetar estado do sistema
# -----------------------------------------------------------------------------
_resetando() {
    _limpar_estado_variaveis
    return 0
}

# -----------------------------------------------------------------------------
# Encerrar programa com status
# Parâmetros:
#   $1 - Status de saída (opcional, padrão: 0)
# -----------------------------------------------------------------------------
_encerrar_programa() {
    local status="${1:-0}"
    _limpar_estado_variaveis
    exit "$status"
}
