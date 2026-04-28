#!/usr/bin/env bash
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 24/04/2026-02

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

# =============================================================================
# VARIÁVEIS GLOBAIS DOCUMENTADAS
# =============================================================================

# Arrays para organizacao das variaveis
declare -a CORES=(RED GREEN YELLOW BLUE PURPLE CYAN NORM)
declare -a ATUALIZAC=(sistema verclass dbmaker base base2 base3 acessossh ipserver Offline enviabackup empresa VERSAOANT)
declare -a CAMINHOS_BASE=(BASE1 BASE2 BASE3 SCRIPT_DIR raiz base base2 base3 biblioteca bases_backup logs olds cfg libs envia recebe)
declare -a CAMINHOS_BASE2=(INI UMADATA acessoff E_EXEC T_TELAS X_XML)
declare -a BIBLIOTECA_SAV=(SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4)
declare -a COMANDOS=(cmd_unzip cmd_zip cmd_find cmd_who DEFAULT_UNZIP DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO jut JUTIL ISCCLIENT ISCCLIENTT)
declare -a OUTROS=(SERVER_PORTA USUARIO VERSAO SAVISC DEFAULT_VERSAO DEFAULT_ARQUIVO DEFAULT_PEDARQ DEFAULT_PROG DEFAULT_PORTA DEFAULT_USUARIO DEFAULT_ipserver UPDATE JUTIL ISCCLIENT Offline base_trabalho)
declare -a LOGIS=(LOG LOG_ATU LOG_LIMPA LOG_TMP)

#-Variaveis de configuracao do sistema ---------------------------------------------------------#
# Variaveis de configuracao do sistema que podem ser definidas pelo usuario.
# As variaveis com o prefixo "destino" sao usadas para definir o caminho
# dos diretorios que serao usados pelo programa.

raiz="${raiz:-}"                                 # Caminho do diretorio raiz do programa.
cfg_dir="${cfg_dir:-}"                           # Caminho do diretorio de configuracao do programa.
backup="${backup:-}"                             # Caminho do diretorio de backup da base.

# Criar diretorio de configuracao se especificado e nao existir
if [[ -n "${cfg_dir}" ]]; then
    if [[ ! -d "${cfg_dir}" ]]; then
        mkdir -p "${cfg_dir}" || {
            printf '%s\n' "ERRO: Nao foi possivel criar o diretorio de configuracao '${cfg_dir}'." >&2
            return 1
        }
    fi
    # PERMISSAO CORRIGIDA: 0755 e mais seguro que 0777
    chmod 0755 "${cfg_dir}" 2>/dev/null || {
        printf '%s\n' "AVISO: Nao foi possivel ajustar permissao em '${cfg_dir}'." >&2
    }
fi

lib_dir="${lib_dir:-}"                           # Caminho do diretorio de bibliotecas do programa.
base="${base:-}"                                 # Caminho do diretorio da base de dados.
base2="${base2:-}"                               # Caminho do diretorio da segunda base de dados.
base3="${base3:-}"                               # Caminho do diretorio da terceira base de dados.
progs="${progs:-}"                               # Caminho do diretorio dos programas.
envia="${envia:-}"                               # Caminho do diretorio de envio.
recebe="${recebe:-}"                             # Caminho do diretorio de recebimento.
bkbase="${bkbase:-}"                             # Caminho do diretorio de backup da base.
logs="${logs:-}"                                 # Caminho do diretorio dos arquivos de log.
olds="${olds:-}"                                 # Caminho do diretorio dos arquivos de backup.
libs="${libs:-}"                                 # Caminho do diretorio das bibliotecas.
sistema="${sistema:-}"                           # Tipo de sistema que esta sendo usado (iscobol ou isam).
SAVATU="${SAVATU:-}"                             # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU1="${SAVATU1:-}"                           # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU2="${SAVATU2:-}"                           # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU3="${SAVATU3:-}"                           # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU4="${SAVATU4:-}"                           # Caminho do diretorio da biblioteca do servidor da SAV.
verclass="${verclass:-}"                         # Ano da versao
dbmaker="${dbmaker:-}"                           # Variavel que define o tipo de banco de dados usado pelo sistema.
enviabackup="${enviabackup:-}"                   # Variavel que define o caminho para onde sera enviado o backup.
VERSAO="${VERSAO:-}"                             # Variavel que define a versao do programa.
INI="${INI:-}"                                   # Variavel que define o caminho do arquivo de configuracao do sistema.
Offline="${Offline:-}"                           # Variavel que define se o sistema esta em modo offline.
down_dir="${down_dir:-}"                         # Variavel que define o caminho do diretorio do servidor off.
acessoff="${acessoff:-}"                       # Variavel que define o caminho do diretorio do servidor off.
acessossh="${acessossh:-}"                       # Variavel que define o caminho do diretorio do servidor off.
VERSAOANT="${VERSAOANT:-}"                       # Variavel que define a versao do programa anterior.
cmd_unzip="${cmd_unzip:-}"                       # Comando para descompactar arquivos.
cmd_zip="${cmd_zip:-}"                           # Comando para compactar arquivos.
cmd_find="${cmd_find:-}"                         # Comando para buscar arquivos.
cmd_who="${cmd_who:-}"                           # Comando para saber quem esta logado no sistema.
SERVER_PORTA="${SERVER_PORTA:-}"                 # Variavel que define a porta a ser usada para.
USUARIO="${USUARIO:-}"                           # Variavel que define o usuario a ser usado.
ipserver="${ipserver:-}"                         # Variavel que define o ip do servidor da SAV.
destino_biblioteca="${destino_biblioteca:-}"     # Variavel que define o caminho do diretorio da biblioteca do servidor da SAV.
RED="${RED:-}"                                   # Cor vermelha
GREEN="${GREEN:-}"                               # Cor verde
YELLOW="${YELLOW:-}"                             # Cor amarela
BLUE="${BLUE:-}"                                 # Cor azul
PURPLE="${PURPLE:-}"                             # Cor roxa
CYAN="${CYAN:-}"                                 # Cor ciano
NORM="${NORM:-}"                                 # Cor normal
COLUMNS="${COLUMNS:-}"                           # Numero de colunas do terminal
LOG="${LOG:-}"                                   # Variavel que define o caminho do arquivo de log.
LOG_ATU="${LOG_ATU:-}"                           # Variavel que define o caminho do arquivo de log de atualizacao.
LOG_LIMPA="${LOG_LIMPA:-}"                       # Variavel que define o caminho do arquivo de log de limpeza.
LOG_TMP="${LOG_TMP:-}"                           # Variavel que define o caminho do arquivo de log temporario.
UMADATA="${UMADATA:-}"                           # Variavel que define o caminho do arquivo de dados da UMA.
ISCCLIENT="${ISCCLIENT:-}"                       # Variavel que define o caminho do cliente ISC.
base_trabalho="${base_trabalho:-}"               # Variavel que define o caminho do diretorio de trabalho.

# Definir diretorios de trabalho
OLDS="${OLDS:-}"                                 # Diretorio de arquivos antigos
BIBLIOTECA="${BIBLIOTECA:-}"                     # Diretorio de biblioteca do servidor da SAV
PROGS="${PROGS:-}"                               # Diretorio de programas
LOGS="${LOGS:-}"                                 # Diretorio de logs
ENVIA="${ENVIA:-}"                               # Diretorio de envio
RECEBE="${RECEBE:-}"                             # Diretorio de recebimento
LIBS="${LIBS:-}"                                 # Diretorio de bibliotecas
BACKUP="${BACKUP:-}"                             # Diretorio de backup
BASEBACKUP="${BASEBACKUP:-}"                     # Diretorio de backup de base


# Configuracoes padrao
DEFAULT_UNZIP="${DEFAULT_UNZIP:-unzip}"          # Comando padrao para descompactar
DEFAULT_ZIP="${DEFAULT_ZIP:-zip}"                # Comando padrao para compactar
DEFAULT_FIND="${DEFAULT_FIND:-find}"             # Comando padrao para buscar arquivos
DEFAULT_WHO="${DEFAULT_WHO:-who}"                # Comando padrao para verificar usuarios
DEFAULT_PORTA="${DEFAULT_PORTA:-41122}"          # Porta padrao
DEFAULT_USUARIO="${DEFAULT_USUARIO:-atualiza}"   # Usuario padrao

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

# -----------------------------------------------------------------------------
# Cria um diretório com permissões seguras
# Parâmetros:
#   $1 - Caminho do diretório
#   $2 - Permissões (opcional, padrão: 0755)
# Retorna: 0 se criado/existente, 1 se erro
# -----------------------------------------------------------------------------
_criar_diretorio() {
    local caminho="${1}"
    local permissao="${2:-0755}"
    local log_dir="${3:-}"

    if [[ -z "$caminho" ]]; then
        printf "Erro: Caminho nao pode ser vazio.\n" >&2
        return 1
    fi

    if [[ -d "$caminho" ]]; then
        return 0
    fi

    if mkdir -p "$caminho" 2>/dev/null; then
        chmod "$permissao" "$caminho" 2>/dev/null || true
        if [[ -n "$log_dir" ]]; then
            _log "Diretorio criado: $caminho" "$log_dir" 2>/dev/null || true
        fi
        return 0
    else
        printf "Erro: Nao foi possivel criar o diretorio '%s'.\n" "$caminho" >&2
        return 1
    fi
}

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
        COLUMNS=80
    fi

    export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NORM COLUMNS
}

# -----------------------------------------------------------------------------
# Configurar comandos do sistema
# Retorna: 0 se todos os comandos existirem, 1 caso contrario
# -----------------------------------------------------------------------------
_configurar_comandos() {
    # Comando para descompactar
    if [[ -z "${cmd_unzip}" ]]; then
        cmd_unzip="${DEFAULT_UNZIP}"
    fi

    # Comando para compactar
    if [[ -z "${cmd_zip}" ]]; then
        cmd_zip="${DEFAULT_ZIP}"
    fi

    # Comando para localizar arquivos
    if [[ -z "${cmd_find}" ]]; then
        cmd_find="${DEFAULT_FIND}"
    fi

    # Comando para verificar usuarios
    if [[ -z "${cmd_who}" ]]; then
        cmd_who="${DEFAULT_WHO}"
    fi

    # Validar se os comandos existem
    local cmds=("$cmd_unzip" "$cmd_zip" "$cmd_find" "$cmd_who")
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

    # Definir diretorio de configuracao
    raiz="${SCRIPT_DIR%/*}"

    # Criar diretorio de configuracao se nao existir - usando funcao auxiliar
    _criar_diretorio "${cfg_dir}" 0755 "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${cfg_dir}" >&2
        return 1
    }

    # Diretorios de destino para diferentes tipos de biblioteca
    destino_server="${destino_server:-/u/varejo/man/}"                          # Diretorio do servidor de atualizacao
    destino_biblioteca="${destino_biblioteca:-/u/varejo/trans_pc/}"             # Diretorio de transporte PC
    export destino_server destino_biblioteca


    # Definir diretorios de trabalho
    OLDS="${OLDS:-${SCRIPT_DIR}/olds}"                         # Diretorio de arquivos antigos
    BIBLIOTECA="${BIBLIOTECA:-${SCRIPT_DIR}/biblioteca}"       # Diretorio de biblioteca do servidor da SAV
    PROGS="${PROGS:-${SCRIPT_DIR}/progs}"                      # Diretorio de programas
    LOGS="${LOGS:-${SCRIPT_DIR}/logs}"                         # Diretorio de logs
    ENVIA="${ENVIA:-${SCRIPT_DIR}/envia}"                      # Diretorio de envio
    RECEBE="${RECEBE:-${SCRIPT_DIR}/recebe}"                   # Diretorio de recebimento
    LIBS="${LIBS:-${SCRIPT_DIR}/libs}"                         # Diretorio de bibliotecas
    BACKUP="${BACKUP:-${SCRIPT_DIR}/backup}"                   # Diretorio de backup
    BASEBACKUP="${BASEBACKUP:-${SCRIPT_DIR}/bkbase}"           # Diretorio de backup de base

    # Exportar variaveis de diretorio para uso global
    export OLDS PROGS LOGS ENVIA RECEBE LIBS BACKUP BIBLIOTECA BASEBACKUP

    # Criar diretorios se nao existirem - usando funcao auxiliar com permissao segura
    local dirs=("${BIBLIOTECA}" "${BASEBACKUP}" "${OLDS}" "${PROGS}" "${LOGS}" "${ENVIA}" "${RECEBE}" "${LIBS}" "${BACKUP}")
    local dir=""
    for dir in "${dirs[@]}"; do
        _criar_diretorio "${dir}" 0755 "${LOG_ATU}" || {
            printf "Erro ao criar diretorio %s\n" "${dir}" >&2
            return 1
        }
    done
}

# -----------------------------------------------------------------------------
# Configurar variaveis do sistema
# -----------------------------------------------------------------------------
_configurar_variaveis_sistema() {
    acessoff="${acessoff:-${raiz}/portalsav/Atualiza}"                                 # Diretorio do servidor offline

    if [[ "${sistema}" == "iscobol" ]]; then

        # Caminhos dos executaveis e dados
        E_EXEC="${E_EXEC:-${raiz}/classes}"      # Diretorio de executaveis para Iscobol
        T_TELAS="${T_TELAS:-${raiz}/tel_isc}"    # Diretorio de telas para Iscobol
        X_XML="${X_XML:-${raiz}/xml}"            # Diretorio de telas para Iscobol
        BASE1="${BASE1:-${raiz}${base}}"         # Base de dados principal para Iscobol
        BASE2="${BASE2:-${raiz}${base2}}"        # Segunda base de dados para Iscobol
        BASE3="${BASE3:-${raiz}${base3}}"        # Terceira base de dados para Iscobol
        export E_EXEC T_TELAS X_XML BASE1 BASE2 BASE3 acessoff
    else
        E_EXEC="${E_EXEC:-${raiz}/int}"
        T_TELAS="${T_TELAS:-${raiz}/tel}"
        BASE1="${BASE1:-${raiz}${base}}"
        BASE2="${BASE2:-${raiz}${base2}}"
        BASE3="${BASE3:-${raiz}${base3}}"
        export E_EXEC T_TELAS BASE1 BASE2 BASE3 acessoff
    fi
    # Configuracao do diretorio e utilitarios do SAVISC.
    SAVISC="${SAVISC:-${raiz}/savisc/iscobol/bin/}"

    # Utilitarios
    ISCCLIENT="${ISCCLIENT:-iscclient}"

    # Caminho completo do jutil
    JUTIL="${JUTIL:-jutil}"
    jut="${SAVISC}${JUTIL}"
    export SAVISC ISCCLIENT jut

    # Configurar porta e acesso
    if [[ -z "${SERVER_PORTA}" ]]; then
        SERVER_PORTA="${DEFAULT_PORTA}"
    fi

    if [[ -z "${USUARIO}" ]]; then
        USUARIO="${DEFAULT_USUARIO}"
    fi

    # Configurar logs
    LOG_ATU="${LOG_ATU:-${LOGS}/atualiza.$(date +"%Y-%m-%d").log}"
    LOG_LIMPA="${LOG_LIMPA:-${LOGS}/limpando.$(date +"%Y-%m-%d").log}"
    LOG_TMP="${LOG_TMP:-${LOGS}/}"

    # Data atual formatada - CORRIGIDO: com aspas
    UMADATA="${UMADATA:-$(date +"%d-%m-%Y_%H%M%S")}"

    # Arquivo de backup padrao - CORRIGIDO: com aspas
    INI="${INI:-backup-${VERSAO}.zip}"

    # Gerar sufixos de arquivos com base no tipo de compilacao.
    if [[ "${sistema}" = "iscobol" ]]; then
        verclass_sufixo="${verclass: -2}"
        class="-class${verclass_sufixo}"
        mclass="-mclass${verclass_sufixo}"
#   Bibliotecas Iscobol
        local classA="IS${verclass}_classA_"
        local classB="IS${verclass}_classB_"
        local classC="IS${verclass}_tel_isc_"
        local classD="IS${verclass}_xml_"
        local classX="IS${verclass}_*_"
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
# Valida o conteudo de um arquivo de configuracao
# Verifica se o arquivo contem apenas atribuicoes de variaveis simples
# Parâmetros:
#   $1 - Caminho do arquivo de configuracao
# Retorna: 0 se valido, 1 se invalido
# -----------------------------------------------------------------------------
_validar_config_file() {
    local config_file="${1}"
    local linha=""
    local num_linha=0

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    # Ler linha por linha e validar
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
            printf "AVISO: Linha %d tem formato invalido: %s\n" "$num_linha" "$linha" >&2
            return 1
        fi

        # Verificar se ha comandos potencialmente perigosos
        # Usar grep -F para buscar literais sem interpretacao de regex
        # Para buscar barra invertida literal, usar "\\"
        if printf '%s\n' "$linha" | grep -qF ';' || \
           printf '%s\n' "$linha" | grep -qF '|' || \
           printf '%s\n' "$linha" | grep -qF '&' || \
           printf '%s\n' "$linha" | grep -qF '`' || \
           printf '%s\n' "$linha" | grep -qF "\\"; then
           printf "AVISO: Linha %d pode conter comandos perigosos: %s\n" "$num_linha" "$linha" >&2
            return 1
        fi

    done < "$config_file"

    return 0
}

# -----------------------------------------------------------------------------
# Carregar arquivo de configuracao da empresa com validacao
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_carregar_config_empresa() {
    local config_file="${cfg_dir}/.config"

    # Verificar se o arquivo de configuracao existe e tem permissao de leitura
    if [[ ! -e "${config_file}" ]]; then
        printf "ERRO: Arquivo de configuracao nao existe no diretorio.\n" >&2
        printf "ATENCAO: Execute './atualiza.sh --setup' para criar as configuracoes.\n" >&2
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
        fi
        return 1
    fi

    if [[ ! -r "${config_file}" ]]; then
        printf "ERRO: Arquivo %s sem permissao de leitura.\n" "${config_file}" >&2
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
        fi
        return 1
    fi

    # Validar conteudo do arquivo antes de carregar - MEDIDA DE SEGURANCA
    if ! _validar_config_file "${config_file}"; then
        printf "ERRO: Arquivo de configuracao contem formato invalido ou comandos suspeitos.\n" >&2
        printf "AVISO: Carregamento do arquivo de configuracao bloqueado por seguranca.\n" >&2
        if command -v _read_sleep >/dev/null 2>&1; then
            _read_sleep 2 2>/dev/null || true
        fi
        return 1
    fi

    # Carregar configuracoes
    if ! "." "${config_file}"; then
        printf "ERRO: Falha ao carregar arquivo de configuracao %s.\n" "${config_file}" >&2
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Configurar acesso offline se necessario
# Retorna: 0 sempre
# -----------------------------------------------------------------------------
_configurar_acessos() {
    if [[ "${Offline}" =~ ^[sn]$ ]]; then
        if [[ "${Offline}" == "s" ]]; then
            down_dir="${acessoff}"
            if [[ ! -d "${down_dir}" ]]; then
                _criar_diretorio "${down_dir}" 0755 "${LOG_ATU}" || {
                    printf "Erro ao criar diretorio offline %s\n" "${down_dir}" >&2
                    return 1
                }
            fi
        else
            down_dir="${RECEBE}"
        fi
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

    # Carregar arquivos de configuracao
    _carregar_config_empresa || return 1

    # Configurar comandos
    _configurar_comandos || return 1

    # Configurar diretorios
    _configurar_diretorios || return 1

    # Configurar variaveis do sistema
    _configurar_variaveis_sistema

    # Configurar acesso offline
    _configurar_acessos

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
    if [[ "${sistema}" == "iscobol" ]]; then
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
    if [[ "${sistema}" == "iscobol" ]] && [[ ! -x "${jut}" ]]; then
        if command -v _mensagec >/dev/null 2>&1; then
            _mensagec "${YELLOW}" "Aviso: jutil nao encontrado em ${jut}"
        else
            printf "Aviso: jutil nao encontrado em %s\n" "${jut}" >&2
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
    if [[ ! -f "${cfg_dir}/.config" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo .config nao encontrado!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Arquivo .config encontrado"
    fi

    # Verificar variaveis essenciais
    if [[ -z "${sistema}" ]]; then
        _mensagec "${RED}" "ERRO: Variavel 'sistema' nao definida!"
        ((erros++)) || true
    elif [[ "${sistema}" != "iscobol" && "${sistema}" != "cobol" ]]; then
        _mensagec "${YELLOW}" "Alerta: Valor desconhecido para 'sistema': ${sistema}"
        ((warnings++)) || true
    else
        _mensagec "${GREEN}" "OK: Sistema definido como ${sistema}"
    fi
    
    if [[ -z "${raiz}" ]]; then
        _mensagec "${RED}" "ERRO: Variavel 'raiz' nao definida!"
        ((erros++)) || true
    else
        _mensagec "${GREEN}" "OK: Diretorio raiz definido"
    fi
    
    if [[ -z "${dbmaker}" ]]; then
        _mensagec "${YELLOW}" "Alerta: Variavel 'dbmaker' nao definida"
        ((warnings++)) || true
    else
        _mensagec "${GREEN}" "OK: Configuracao de banco de dados definida"
    fi
   
    
    # Verificar diretorios essenciais
    local dirs=("biblioteca" "olds" "logs" "cfg" "libs" "backup" "bases_backup" "envia" "recebe" "E_EXEC" "T_TELAS" "BASE1")
    for dir in "${dirs[@]}"; do
        local dir_path=""
        # Tratamento especial para E_EXEC e T_TELAS que ficam em ${raiz}
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
    if [[ "${Offline}" =~ ^[sn]$ ]]; then
        if [[ "${Offline}" == "n" ]]; then
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
