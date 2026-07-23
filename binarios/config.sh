#!/usr/bin/env bash
set -euo pipefail
#
# config.sh - Modulo de Configuracoes e Validacoes
# Responsavel por carregar configuracoes, validar sistema e definir variaveis globais
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 23/07/2026-03

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

# =============================================================================
# MAPA DECLARATIVO DE VARIAVEIS POR CATEGORIA
# =============================================================================
# Formato: _MAPA_VARIAVEIS["NOME_VARIAVEL"]="CATEGORIA"
# Valores padrao ficam em constantes.sh; aqui apenas registramos para rastreamento/limpeza.

declare -gA _MAPA_VARIAVEIS=(
    # ATUALIZACAO
    ["CFG_VERSAOCLASS"]="ATUALIZACAO"
    ["CFG_ACESSO_SSH"]="ATUALIZACAO"
    ["CFG_OFFLINE"]="ATUALIZACAO"
    ["CFG_BACKUP_PATH"]="ATUALIZACAO"
    ["CFG_EMPRESA"]="ATUALIZACAO"
    ["VERSAOANT"]="ATUALIZACAO"

    # CAMINHOS
    ["SCRIPT_DIR"]="CAMINHOS"
    ["RAIZ"]="CAMINHOS"
    ["CFG_DIR"]="CAMINHOS"
    ["LIBS_DIR"]="CAMINHOS"
    ["CFG_BASE_DIR"]="CAMINHOS"
    ["CFG_BASE_DIR2"]="CAMINHOS"
    ["CFG_BASE_DIR3"]="CAMINHOS"
    ["DEFAULT_CONFIG_DIR"]="CAMINHOS"
    ["DEFAULT_LIBS_DIR"]="CAMINHOS"
    ["DEFAULT_LOGS_DIR"]="CAMINHOS"
    ["DEFAULT_BACKUP_DIR"]="CAMINHOS"
    ["DEFAULT_BASEBACKUP_DIR"]="CAMINHOS"
    ["DEFAULT_BIBLIOTECA_ATUAL_DIR"]="CAMINHOS"
    ["DEFAULT_BIBLIOTECA_DIR"]="CAMINHOS"
    ["DEFAULT_PROGS_DIR"]="CAMINHOS"
    ["DEFAULT_OLDS_DIR"]="CAMINHOS"
    ["DEFAULT_ENVIA_DIR"]="CAMINHOS"
    ["DEFAULT_RECEBE_DIR"]="CAMINHOS"
    ["UMADATA"]="CAMINHOS"
    ["E_EXEC"]="CAMINHOS"
    ["T_TELAS"]="CAMINHOS"
    ["X_XML"]="CAMINHOS"

    # BIBLIOTECA
    ["SAVATU"]="BIBLIOTECA"
    ["SAVATU1"]="BIBLIOTECA"
    ["SAVATU2"]="BIBLIOTECA"
    ["SAVATU3"]="BIBLIOTECA"
    ["SAVATU4"]="BIBLIOTECA"

    # COMANDOS
    ["DEFAULT_ZIP"]="COMANDOS"
    ["DEFAULT_TAR"]="COMANDOS"
    ["DEFAULT_FIND"]="COMANDOS"
    ["DEFAULT_UNZIP"]="COMANDOS"
    ["REBUILD"]="COMANDOS"
    ["JUTIL"]="COMANDOS"
    ["ISCCLIENT"]="COMANDOS"

    # CONFIGURACOES
    ["DEFAULT_SSH_PORTA"]="CONFIGURACOES"
    ["DEFAULT_SSH_USER"]="CONFIGURACOES"
    ["DEFAULT_IP_SERVER"]="CONFIGURACOES"
    ["DEFAULT_CHAVE_SSH"]="CONFIGURACOES"
    ["DEFAULT_CHAVE_SSH_PUB"]="CONFIGURACOES"
    ["SSH_TIMEOUT"]="CONFIGURACOES"
    ["DEFAULT_READ_TIMEOUT"]="CONFIGURACOES"
    ["DEFAULT_PRESS_TIMEOUT"]="CONFIGURACOES"
    ["CFG_CHAVE_SSH"]="CONFIGURACOES"
    ["DESTINO_SERVER"]="CONFIGURACOES"
    ["DESTINO_BIBLIOTECA"]="CONFIGURACOES"
    ["VERSAO"]="CONFIGURACOES"
    ["SAVISC"]="CONFIGURACOES"
    ["base_trabalho"]="CONFIGURACOES"

    # SEGURANCA
    ["PERM_DIR_SECURE"]="SEGURANCA"
    ["PERM_FILE_PRIVATE"]="SEGURANCA"
    ["PERM_FILE_EXEC"]="SEGURANCA"

    # LOGS
    ["LOG_ATU"]="LOGS"
    ["LOG_LIMPA"]="LOGS"
    ["LOG_TMP"]="LOGS"
)

# =============================================================================
# INICIALIZACAO DE VARIAVEIS DO SISTEMA
# =============================================================================

_inicializar_variaveis_sistema() {
    # Cores do terminal — tput com fallback seguro
    VERMELHO=$(tput bold 2>/dev/null; tput setaf 1 2>/dev/null || printf "\033[1;31m")
    VERDE=$(tput bold 2>/dev/null; tput setaf 2 2>/dev/null || printf "\033[1;32m")
    AMARELO=$(tput bold 2>/dev/null; tput setaf 3 2>/dev/null || printf "\033[1;33m")
    AZUL=$(tput bold 2>/dev/null; tput setaf 4 2>/dev/null || printf "\033[1;34m")
    ROXO=$(tput bold 2>/dev/null; tput setaf 5 2>/dev/null || printf "\033[1;35m")
    CIANO=$(tput bold 2>/dev/null; tput setaf 6 2>/dev/null || printf "\033[1;36m")
    BRANCO=$(tput bold 2>/dev/null; tput setaf 7 2>/dev/null || printf "\033[1;37m")
    NORMAL=$(tput sgr0 2>/dev/null || printf "\033[0m")
    COLUMNS=$(tput cols 2>/dev/null || printf 80)

    # Limpar tela inicial
    tput clear 2>/dev/null || true
    tput bold 2>/dev/null || true
    tput setaf 7 2>/dev/null || true
    export VERMELHO VERDE AMARELO AZUL ROXO CIANO BRANCO NORMAL COLUMNS

    # Reinicializar arrays
    REGISTRO_VARIAVEIS=()
    _REGISTRO_MAPA=()

    # Registrar todas as variaveis a partir do mapa declarativo
    local var_name var_categoria
    for var_name in "${!_MAPA_VARIAVEIS[@]}"; do
        var_categoria="${_MAPA_VARIAVEIS[$var_name]}"
        _register_var "$var_name" "${!var_name:-}" "$var_categoria"
    done
}

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
        if command -v _exibir_mensagem_centralizada >/dev/null 2>&1; then
            _exibir_mensagem_centralizada "${CIANO}" "Diretorio principal nao encontrado: ${SCRIPT_DIR}"
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
        _exibir_mensagem_centralizada "${AMARELO}" "Alerta: Variavel 'acesso_ssh' com valor desconhecido: ${CFG_ACESSO_SSH}"
        return 1
    fi

    if [[ "${CFG_ACESSO_SSH}" == "n" ]]; then
        _exibir_mensagem_centralizada "${AMARELO}" "Alerta: Acesso SSH desabilitado"
        return 0
    fi

    _exibir_mensagem_centralizada "${VERDE}" "OK: Acesso SSH habilitado"

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
        _exibir_mensagem_centralizada "${AMARELO}" "Alerta: Variavel DEFAULT_SSH_USER nao definida, usando 'root'"
        ssh_user="root"
    fi

    local ssh_opts=("-o" "ConnectTimeout=${ssh_timeout}" "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)")

    if [[ -n "${ssh_port}" ]]; then
        ssh_opts+=("-p" "${ssh_port}")
    fi

    if [[ -n "${ssh_key}" ]]; then
        if [[ -f "${ssh_key}" ]]; then
            ssh_opts+=("-i" "${ssh_key}")
        else
            _exibir_mensagem_centralizada "${AMARELO}" "Alerta: Chave SSH nao encontrada: ${ssh_key}"
        fi
    fi

    local ssh_output ssh_exit=0
    ssh_output=$(ssh "${ssh_opts[@]}" "${ssh_user}@${ssh_host}" exit 2>&1) || ssh_exit=$?

    if (( ssh_exit == 0 )); then
        _exibir_mensagem_centralizada "${VERDE}" "Conexao SSH estabelecida com sucesso para ${ssh_user}@${ssh_host}"
    else
        _exibir_mensagem_centralizada "${VERMELHO}" "Falha na conexao SSH para ${ssh_user}@${ssh_host}"
        _linha "-" "${AMARELO}"
        _exibir_mensagem_centralizada "${AMARELO}" "Comando: ssh ${ssh_opts[*]} ${ssh_user}@${ssh_host} exit"
        _linha "-" "${AMARELO}"

        if [[ "${ssh_output}" == *"Permission denied"* ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Motivo: Permissao negada (publickey,password)"
            _exibir_mensagem_centralizada "${AMARELO}" "Possiveis causas:"
            if [[ -n "${ssh_key}" ]]; then
                if [[ -f "${ssh_key}" ]]; then
                    local key_perm
                    key_perm=$(stat -c "%a" "${ssh_key}" 2>/dev/null || stat -f "%Lp" "${ssh_key}" 2>/dev/null || echo "?")
                    _exibir_mensagem_centralizada "${NORMAL}" "  - Chave usada: ${ssh_key} (perm: ${key_perm})"
                    _exibir_mensagem_centralizada "${NORMAL}" "  - A chave privada deve ter permissao 600"
                    _exibir_mensagem_centralizada "${NORMAL}" "  - Chave publica pode nao estar em /home/${ssh_user}/.ssh/authorized_keys"
                else
                    _exibir_mensagem_centralizada "${NORMAL}" "  - Chave configurada nao existe: ${ssh_key}"
                fi
            else
                _exibir_mensagem_centralizada "${NORMAL}" "  - Nenhuma chave SSH configurada em CFG_CHAVE_SSH"
                _exibir_mensagem_centralizada "${NORMAL}" "  - O SSH procura padrao em: ~/.ssh/id_{rsa,ed25519,ecdsa}"
                _exibir_mensagem_centralizada "${NORMAL}" "  - Se a chave esta em /root/.ssh/, configure:"
                _exibir_mensagem_centralizada "${NORMAL}" "    CFG_CHAVE_SSH=/root/.ssh/id_rsa_atualiza"
                _exibir_mensagem_centralizada "${NORMAL}" "    Ou copie a chave para ~/.ssh/ do usuario atual"
                _exibir_mensagem_centralizada "${NORMAL}" "    Ou execute: ssh-agent bash -c 'ssh-add /root/.ssh/id_rsa_atualiza && comando'"
            fi
            _exibir_mensagem_centralizada "${NORMAL}" "  - A chave publica pode nao estar cadastrada no servidor"
            _exibir_mensagem_centralizada "${NORMAL}" "  - Execute: ssh-copy-id -i /root/.ssh/id_rsa_atualiza.pub ${ssh_user}@${ssh_host}"
            _exibir_mensagem_centralizada "${NORMAL}" "  - Usuario '${ssh_user}' pode estar incorreto"
        elif [[ "${ssh_output}" == *"Connection refused"* ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Motivo: Conexao recusada na porta ${ssh_port}"
            _exibir_mensagem_centralizada "${AMARELO}" "Verifique se o servidor SSH esta rodando e a porta correta"
        elif [[ "${ssh_output}" == *"Connection timed out"* ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Motivo: Conexao excedeu timeout de ${ssh_timeout}s"
            _exibir_mensagem_centralizada "${AMARELO}" "Verifique se o IP '${ssh_host}' esta correto e acessivel"
        elif [[ "${ssh_output}" == *"Host key verification failed"* ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Motivo: Falha na verificacao da chave do host"
            _exibir_mensagem_centralizada "${AMARELO}" "Execute: ssh-keygen -R '${ssh_host}'"
        else
            _exibir_mensagem_centralizada "${VERMELHO}" "Erro desconhecido:"
            printf "%s\n" "${ssh_output}" >&2
        fi
        _linha "-" "${AMARELO}"
        _exibir_mensagem_centralizada "${AMARELO}" "Dica: execute 'ssh ${ssh_user}@${ssh_host}' manualmente para diagnosticar"
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

# Limpeza de emergencia — gera lista a partir do registro + cores
_limpeza_emergencia() {
    local vars_emergencia="VERMELHO VERDE AMARELO AZUL ROXO CIANO NORMAL UPDATE"

    # Adicionar variaveis registradas no mapa
    if [[ ${#_MAPA_VARIAVEIS[@]} -gt 0 ]]; then
        local var_name
        for var_name in "${!_MAPA_VARIAVEIS[@]}"; do
            vars_emergencia+=" $var_name"
        done
    fi

    local var
    for var in $vars_emergencia; do
        unset -v "$var" 2>/dev/null || true
    done
    tput sgr0 2>/dev/null || true
}

# Inicializar sistema de variaveis
_inicializar_sistema_variaveis() {
    REGISTRO_VARIAVEIS=()
    _REGISTRO_MAPA=()
    declare -A REGISTRO_CATEGORIAS=()
    VAR_CONTADOR_REGISTRO=0

    _inicializar_variaveis_sistema
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
    tput sgr0 2>/dev/null || true
    trap - EXIT INT TERM QUIT

}

# Encerrar programa com status
_encerrar_programa() {
    local status="${1:-0}"
    _finalizar_sistema
    exit "$status"
}

trap '_encerrar_programa 130' INT
trap '_encerrar_programa 143' TERM
trap '_limpeza_emergencia' QUIT

