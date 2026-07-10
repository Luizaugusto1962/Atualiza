#!/usr/bin/env bash
set -euo pipefail
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 10/07/2026-02

# =============================================================================
# VARIAVEIS GLOBAIS PRIMITIVAS (fallback se nao definidas em constantes.sh)
# =============================================================================
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-}"
RAIZ="${RAIZ:-}"
CFG_DIR="${CFG_DIR:-}"
REBUILD="${REBUILD:-}"
compilado="${compilado:-}"
debugado="${debugado:-}"

# Arrays para registro e limpeza de variaveis
declare -ga REGISTRO_VARIAVEIS=()
declare -gA REGISTRO_CATEGORIAS=()
declare -gA _REGISTRO_MAPA=()
declare -g VAR_CONTADOR_REGISTRO=0

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
        VERMELHO=$(tput bold; tput setaf 1 2>/dev/null)
        VERDE=$(tput bold; tput setaf 2 2>/dev/null)
        AMARELO=$(tput bold; tput setaf 3 2>/dev/null)
        AZUL=$(tput bold; tput setaf 4 2>/dev/null)
        ROXO=$(tput bold; tput setaf 5 2>/dev/null)
        CIANO=$(tput bold; tput setaf 6 2>/dev/null)
        BRANCO=$(tput bold; tput setaf 7 2>/dev/null)
        NORMAL=$(tput sgr0 2>/dev/null)
        COLUNAS=$(tput cols)
        tput clear 2>/dev/null || true
        tput bold 2>/dev/null || true
        tput setaf 7 2>/dev/null || true
    else
        VERMELHO="\033[0;31m"
        VERDE="\033[0;32m"
        AMARELO="\033[0;33m"
        AZUL="\033[0;34m"
        ROXO="\033[0;35m"
        CIANO="\033[0;36m"
        BRANCO="\033[0;37m"
        NORMAL="\033[0m"
        COLUNAS="${COLUNAS:-80}"
    fi
    export VERMELHO VERDE AMARELO AZUL ROXO CIANO BRANCO NORMAL COLUNAS

    # Reinicializar arrays
    REGISTRO_VARIAVEIS=()
    _REGISTRO_MAPA=()

    # ATUALIZACAO
    _define_category_vars "ATUALIZACAO" \
        "CFG_VERSAOCLASS=${CFG_VERSAOCLASS:-}" \
        "CFG_ACESSO_SSH=${CFG_ACESSO_SSH:-}" \
        "CFG_OFFLINE=${CFG_OFFLINE:-}" \
        "CFG_BACKUP_PATH=${CFG_BACKUP_PATH:-}" \
        "CFG_EMPRESA=${CFG_EMPRESA:-}" \
        "VERSAOANT=${VERSAOANT:-}"

    # CAMINHOS
    _define_category_vars "CAMINHOS" \
        "SCRIPT_DIR=${SCRIPT_DIR:-}" \
        "RAIZ=${RAIZ:-}" \
        "CFG_DIR=${CFG_DIR:-}" \
        "LIBS_DIR=${LIBS_DIR:-}" \
        "CFG_BASE_DIR=${CFG_BASE_DIR:-}" \
        "CFG_BASE_DIR2=${CFG_BASE_DIR2:-}" \
        "CFG_BASE_DIR3=${CFG_BASE_DIR3:-}" \
        "DEFAULT_CONFIG_DIR=${DEFAULT_CONFIG_DIR:-}" \
        "DEFAULT_LIBS_DIR=${DEFAULT_LIBS_DIR:-}" \
        "DEFAULT_LOGS_DIR=${DEFAULT_LOGS_DIR:-}" \
        "DEFAULT_BACKUP_DIR=${DEFAULT_BACKUP_DIR:-}" \
        "DEFAULT_BASEBACKUP_DIR=${DEFAULT_BASEBACKUP_DIR:-}" \
        "DEFAULT_BIBLIOTECA_ATUAL_DIR=${DEFAULT_BIBLIOTECA_ATUAL_DIR:-}" \
        "DEFAULT_BIBLIOTECA_DIR=${DEFAULT_BIBLIOTECA_DIR:-}" \
        "DEFAULT_PROGS_DIR=${DEFAULT_PROGS_DIR:-}" \
        "DEFAULT_OLDS_DIR=${DEFAULT_OLDS_DIR:-}" \
        "DEFAULT_ENVIA_DIR=${DEFAULT_ENVIA_DIR:-}" \
        "DEFAULT_RECEBE_DIR=${DEFAULT_RECEBE_DIR:-}" \
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
        "DEFAULT_TAR=${DEFAULT_TAR:-}" \
        "DEFAULT_FIND=${DEFAULT_FIND:-}" \
        "DEFAULT_UNZIP=${DEFAULT_UNZIP:-}" \
        "REBUILD=${REBUILD:-}" \
        "JUTIL=${JUTIL:-}" \
        "ISCCLIENT=${ISCCLIENT:-}"

    # CONFIGURACOES
    _define_category_vars "CONFIGURACOES" \
        "DEFAULT_SSH_PORTA=${DEFAULT_SSH_PORTA:-}" \
        "DEFAULT_SSH_USER=${DEFAULT_SSH_USER:-}" \
        "DEFAULT_IP_SERVER=${DEFAULT_IP_SERVER:-}" \
        "DEFAULT_CHAVE_SSH=${DEFAULT_CHAVE_SSH:-}" \
        "DEFAULT_CHAVE_SSH_PUB=${DEFAULT_CHAVE_SSH_PUB:-}" \
        "SSH_TIMEOUT=${SSH_TIMEOUT:-}" \
        "DEFAULT_READ_TIMEOUT=${DEFAULT_READ_TIMEOUT:-}" \
        "DEFAULT_PRESS_TIMEOUT=${DEFAULT_PRESS_TIMEOUT:-}" \
        "CFG_CHAVE_SSH=${CFG_CHAVE_SSH:-}" \
        "DESTINO_SERVER=${DESTINO_SERVER:-}" \
        "DESTINO_BIBLIOTECA=${DESTINO_BIBLIOTECA:-}" \
        "VERSAO=${VERSAO:-}" \
        "SAVISC=${SAVISC:-}" \
        "base_trabalho=${base_trabalho:-}"

    # SEGURANCA
    _define_category_vars "SEGURANCA" \
        "PERM_DIR_SECURE=${PERM_DIR_SECURE:-}" \
        "PERM_FILE_PRIVATE=${PERM_FILE_PRIVATE:-}" \
        "PERM_FILE_EXEC=${PERM_FILE_EXEC:-}"

    # LOGS
    _define_category_vars "LOGS" \
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

# =============================================================================
# FUNCOES DE CONFIGURACAO
# =============================================================================

# Configurar comandos do sistema
_configurar_comandos() {
    local cmds=("$DEFAULT_ZIP" "$DEFAULT_UNZIP" "$DEFAULT_TAR" "$DEFAULT_FIND")
    local cmd missing=()

    for cmd in "${cmds[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        _erro "Comandos nao encontrados: " "${missing[*]}" >&2
        command -v _aguardar >/dev/null 2>&1 && _aguardar 2 2>/dev/null || true
        return 1
    fi
    return 0
}

# Configurar diretorios de trabalho
_configurar_diretorios() {
    if [[ -z "${SCRIPT_DIR}" ]] || [[ ! -d "${SCRIPT_DIR}" ]]; then
        if command -v _mensagec >/dev/null 2>&1; then
            _mensagec "${CIANO}" "Diretorio principal nao encontrado: ${SCRIPT_DIR}"
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
    E_EXEC="${E_EXEC:-${RAIZ}/classes}"
    T_TELAS="${T_TELAS:-${RAIZ}/tel_isc}"
    export E_EXEC T_TELAS
    
    local verclass_sufixo="${CFG_VERSAOCLASS: -2}"
    compilado="-class${verclass_sufixo}"
    debugado="-mclass${verclass_sufixo}"
    local classA="IS${CFG_VERSAOCLASS}_classA_"
    local classB="IS${CFG_VERSAOCLASS}_classB_"
    local classC="IS${CFG_VERSAOCLASS}_tel_isc_"
    local classX="IS${CFG_VERSAOCLASS}_*_"
    SAVATU1="tempSAV_${classA}"
    SAVATU2="tempSAV_${classB}"
    SAVATU3="tempSAV_${classC}"
    SAVATU="tempSAV_${classX}"
    export E_EXEC T_TELAS CFG_OFFLINE
    export SAVATU1 SAVATU2 SAVATU3 SAVATU4 SAVATU
}

# Validar acesso SSH
_validar_ssh() {
    if [[ ! "${CFG_ACESSO_SSH}" =~ ^[sn]$ ]]; then
        _mensagec "${AMARELO}" "Alerta: Variavel 'acesso_ssh' com valor desconhecido: ${CFG_ACESSO_SSH}"
        return 1
    fi

    if [[ "${CFG_ACESSO_SSH}" == "n" ]]; then
        _mensagec "${AMARELO}" "Alerta: Acesso SSH desabilitado"
        return 0
    fi

    _mensagec "${VERDE}" "OK: Acesso SSH habilitado"

    local ssh_host="${DEFAULT_IP_SERVER}"
    local ssh_user="${DEFAULT_SSH_USER}"
    local ssh_port="${DEFAULT_SSH_PORTA:-22}"
    local ssh_key="${DEFAULT_CHAVE_SSH:-}"
    local ssh_timeout="${SSH_TIMEOUT:-10}"

    if [[ -z "${ssh_host}" ]]; then
        _erro "Variavel DEFAULT_IP_SERVER nao definida"
        return 1
    fi

    if [[ -z "${ssh_user}" ]]; then
        _mensagec "${AMARELO}" "Alerta: Variavel DEFAULT_SSH_USER nao definida, usando 'root'"
        ssh_user="root"
    fi

    local ssh_opts=("-o" "ConnectTimeout=${ssh_timeout}" "-o" "StrictHostKeyChecking=$(_ssh_accept_new)")

    if [[ -n "${ssh_port}" ]]; then
        ssh_opts+=("-p" "${ssh_port}")
    fi

    if [[ -n "${ssh_key}" ]]; then
        if [[ -f "${ssh_key}" ]]; then
            ssh_opts+=("-i" "${ssh_key}")
        else
            _mensagec "${AMARELO}" "Alerta: Chave SSH nao encontrada: ${ssh_key}"
        fi
    fi

    local ssh_output ssh_exit=0
    ssh_output=$(ssh "${ssh_opts[@]}" "${ssh_user}@${ssh_host}" exit 2>&1) || ssh_exit=$?

    if (( ssh_exit == 0 )); then
        _mensagec "${VERDE}" "Conexao SSH estabelecida com sucesso para ${ssh_user}@${ssh_host}"
    else
        _mensagec "${VERMELHO}" "Falha na conexao SSH para ${ssh_user}@${ssh_host}"
        _linha "-" "${AMARELO}"
        _mensagec "${AMARELO}" "Comando: ssh ${ssh_opts[*]} ${ssh_user}@${ssh_host} exit"
        _linha "-" "${AMARELO}"

        if [[ "${ssh_output}" == *"Permission denied"* ]]; then
            _mensagec "${VERMELHO}" "Motivo: Permissao negada (publickey,password)"
            _mensagec "${AMARELO}" "Possiveis causas:"
            if [[ -n "${ssh_key}" ]]; then
                if [[ -f "${ssh_key}" ]]; then
                    local key_perm
                    key_perm=$(stat -c "%a" "${ssh_key}" 2>/dev/null || stat -f "%Lp" "${ssh_key}" 2>/dev/null || echo "?")
                    _mensagec "${NORMAL}" "  - Chave usada: ${ssh_key} (perm: ${key_perm})"
                    _mensagec "${NORMAL}" "  - A chave privada deve ter permissao 600"
                    _mensagec "${NORMAL}" "  - Chave publica pode nao estar em /home/${ssh_user}/.ssh/authorized_keys"
                else
                    _mensagec "${NORMAL}" "  - Chave configurada nao existe: ${ssh_key}"
                fi
            else
                _mensagec "${NORMAL}" "  - Nenhuma chave SSH configurada em CFG_CHAVE_SSH"
                _mensagec "${NORMAL}" "  - O SSH procura padrao em: ~/.ssh/id_{rsa,ed25519,ecdsa}"
                _mensagec "${NORMAL}" "  - Se a chave esta em /root/.ssh/, configure:"
                _mensagec "${NORMAL}" "    CFG_CHAVE_SSH=/root/.ssh/id_rsa_atualiza"
                _mensagec "${NORMAL}" "    Ou copie a chave para ~/.ssh/ do usuario atual"
                _mensagec "${NORMAL}" "    Ou execute: ssh-agent bash -c 'ssh-add /root/.ssh/id_rsa_atualiza && comando'"
            fi
            _mensagec "${NORMAL}" "  - A chave publica pode nao estar cadastrada no servidor"
            _mensagec "${NORMAL}" "  - Execute: ssh-copy-id -i /root/.ssh/id_rsa_atualiza.pub ${ssh_user}@${ssh_host}"
            _mensagec "${NORMAL}" "  - Usuario '${ssh_user}' pode estar incorreto"
        elif [[ "${ssh_output}" == *"Connection refused"* ]]; then
            _mensagec "${VERMELHO}" "Motivo: Conexao recusada na porta ${ssh_port}"
            _mensagec "${AMARELO}" "Verifique se o servidor SSH esta rodando e a porta correta"
        elif [[ "${ssh_output}" == *"Connection timed out"* ]]; then
            _mensagec "${VERMELHO}" "Motivo: Conexao excedeu timeout de ${ssh_timeout}s"
            _mensagec "${AMARELO}" "Verifique se o IP '${ssh_host}' esta correto e acessivel"
        elif [[ "${ssh_output}" == *"Host key verification failed"* ]]; then
            _mensagec "${VERMELHO}" "Motivo: Falha na verificacao da chave do host"
            _mensagec "${AMARELO}" "Execute: ssh-keygen -R '${ssh_host}'"
        else
            _mensagec "${VERMELHO}" "Erro desconhecido:"
            printf "%s\n" "${ssh_output}" >&2
        fi
        _linha "-" "${AMARELO}"
        _mensagec "${AMARELO}" "Dica: execute 'ssh ${ssh_user}@${ssh_host}' manualmente para diagnosticar"
    fi
    _linha "=" "${VERDE}"
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

    # Arquivo deve ser de tamanho seguro (<= 1MB)
    local tamanho
    tamanho=$(wc -c < "$CONFIG_FILE" 2>/dev/null || echo 0)
    if (( tamanho > 1048576 )); then
        _erro "Arquivo de configuracao muito grande: %d bytes (maximo 1MB)\n" "$tamanho" >&2
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
    _configurar_comandos     || return 1
    _configurar_diretorios   || return 1
    _configurar_variaveis_sistema
}

# Configurar ambiente final
_configurar_ambiente() {
    if [[ ! -x "${REBUILD}" ]]; then
        _aviso "Aviso: jutil nao encontrado em ${REBUILD}"
    fi
}

# =============================================================================
# VALIDACAO DE CONFIGURACAO
# =============================================================================

_validar_configuracao() {
    _limpa_tela
    _linha "=" "${VERDE}"
    _mensagec "${VERMELHO}" "Validacao de Configuracao"
    _linha

    local erros=0 warnings=0

    # Arquivo de configuracao
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        _erro "Arquivo .config nao encontrado!"
        ((erros++)) || true
    else
        _mensagec "${VERDE}" "OK: Arquivo .config encontrado"
    fi

    # Variaveis essenciais
    if [[ -z "${RAIZ}" ]]; then
        _erro "Variavel 'RAIZ' nao definida!"
        ((erros++)) || true
    else
        _mensagec "${VERDE}" "OK: Diretorio RAIZ definido"
    fi

    # Variaveis opcionais
    local vars_opcionais=("CFG_ACESSO_SSH" "CFG_OFFLINE" "CFG_CHAVE_SSH")
    local var
    for var in "${vars_opcionais[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            _mensagec "${AMARELO}" "Alerta: Variavel '${var}' nao definida"
            ((warnings++)) || true
        else
            _mensagec "${VERDE}" "OK: Configuracao ${var} definida"
        fi
    done

    # Diretorios essenciais
    local -A _mapa_dirs=(
        [biblioteca]="DEFAULT_BIBLIOTECA_DIR"
        [olds]="DEFAULT_OLDS_DIR"
        [logs]="DEFAULT_LOGS_DIR"
        [configuracoes]="CFG_DIR"
        [binarios]="LIBS_DIR"
        [backup]="DEFAULT_BACKUP_DIR"
        [bases_backup]="DEFAULT_BASEBACKUP_DIR"
        [enviar]="DEFAULT_ENVIA_DIR"
        [receber]="DEFAULT_RECEBE_DIR"
        [E_EXEC]="E_EXEC"
        [T_TELAS]="T_TELAS"
    )
    local dir dir_path var_name
    local dirs_order=("biblioteca" "olds" "logs" "configuracoes" "binarios" "backup" "bases_backup" "enviar" "receber" "E_EXEC" "T_TELAS")
    for dir in "${dirs_order[@]}"; do
        var_name="${_mapa_dirs[$dir]}"
        if [[ "$dir" == "E_EXEC" ]] || [[ "$dir" == "T_TELAS" ]]; then
            dir_path="${!var_name:-}"
        else
            dir_path="${SCRIPT_DIR}${!var_name:-}"
        fi

        if [[ ! -d "${dir_path}" ]]; then
            _mensagec "${AMARELO}" "Alerta: Diretorio ${dir} nao encontrado: ${dir_path}"
            ((warnings++)) || true
        fi
    done

    # Modo offline
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "n" ]]; then
            _mensagec "${NORMAL}" "INFO: Servidor em modo On ..."
        else
            _mensagec "${VERDE}" "INFO: Servidor em modo Off ..."
        fi
    fi

    # Resumo
    _linha
    printf "\n"
    _msg "Resumo:"
    _erro "Erros: ${erros}"
    _aviso "Avisos: ${warnings}"

    if (( erros == 0 )); then
        _mensagec "${VERDE}" "Configuracao valida!"
    else
        _mensagec "${VERMELHO}" "Configuracao com erros!"
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
    local emergency_vars="VERMELHO VERDE AMARELO AZUL ROXO CIANO NORMAL"
    emergency_vars+=" CFG_VERSAOCLASS CFG_ACESSO_SSH CFG_OFFLINE"
    emergency_vars+=" CFG_BACKUP_PATH CFG_EMPRESA VERSAOANT SCRIPT_DIR"
    emergency_vars+=" RAIZ CFG_DIR LIBS_DIR CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3"
    emergency_vars+=" DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR DEFAULT_LOGS_DIR"
    emergency_vars+=" DEFAULT_BACKUP_DIR DEFAULT_BASEBACKUP_DIR"
    emergency_vars+=" DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BIBLIOTECA_DIR"
    emergency_vars+=" DEFAULT_PROGS_DIR DEFAULT_OLDS_DIR DEFAULT_ENVIA_DIR DEFAULT_RECEBE_DIR"
    emergency_vars+=" UMADATA E_EXEC T_TELAS X_XML"
    emergency_vars+=" SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4"
    emergency_vars+=" DEFAULT_ZIP DEFAULT_TAR DEFAULT_FIND DEFAULT_UNZIP"
    emergency_vars+=" REBUILD JUTIL ISCCLIENT"
    emergency_vars+=" DEFAULT_SSH_PORTA DEFAULT_SSH_USER DEFAULT_IP_SERVER"
    emergency_vars+=" DEFAULT_CHAVE_SSH DEFAULT_CHAVE_SSH_PUB SSH_TIMEOUT"
    emergency_vars+=" DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT"
    emergency_vars+=" CFG_CHAVE_SSH DESTINO_SERVER DESTINO_BIBLIOTECA"
    emergency_vars+=" VERSAO SAVISC base_trabalho"
    emergency_vars+=" PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC"
    emergency_vars+=" UPDATE LOG_ATU LOG_LIMPA LOG_TMP"

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

