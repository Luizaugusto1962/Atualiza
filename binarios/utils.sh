#!/usr/bin/env bash
#
# utils.sh - Modulo de Utilitarios e Funcoes Auxiliares
# Funcoes basicas para formatacao, mensagens, validacao e controle de fluxo
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 14/05/2026-01
# Autor: Luiz Augusto
#
# NOTA: Nao configura traps — gerenciamento centralizado em principal.sh
# NOTA: Nao depende de funcoes externas que possam nao estar carregadas
#
# =============================================================================
# ARRAYS GLOBAIS PARA CONTROLE DE RECURSOS
# =============================================================================
declare -ga TEMP_FILES=()
declare -ga BACKGROUND_PIDS=()

# =============================================================================
# LIMPEZA DE RECURSOS
# =============================================================================

# Funcao de limpeza chamada na saida
# Nao configura traps — deve ser chamada pelo handler definido em principal.sh
_cleanup_on_exit() {
    local exit_code=$?

    # Matar processos em background
    if [[ ${#BACKGROUND_PIDS[@]} -gt 0 ]]; then
        local pid
        for pid in "${BACKGROUND_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done
        BACKGROUND_PIDS=()
    fi

    # Remover arquivos temporarios
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        local temp_file
        for temp_file in "${TEMP_FILES[@]}"; do
            [[ -e "$temp_file" ]] && rm -f "$temp_file" 2>/dev/null || true
        done
        TEMP_FILES=()
    fi

    return $exit_code
}

# Adicionar arquivo temporario para limpeza automatica
_add_temp_file() {
    local temp_file="${1:?Arquivo temporario obrigatorio}"
    TEMP_FILES+=("$temp_file")
}

# Adicionar PID para limpeza automatica
_add_background_pid() {
    local pid="${1:?PID obrigatorio}"
    BACKGROUND_PIDS+=("$pid")
}

# =============================================================================
# FUNCOES DE TRATAMENTO DE ERROS
# =============================================================================

# Funcao para tratar erros de forma segura
# Nao depende de _log_erro — evita cascata de falhas
_handle_error() {
    local exit_code=$?
    local line_number="${1:-$LINENO}"

    printf "ERRO: Falha na linha %d (codigo: %d)\n" "$line_number" "$exit_code" >&2

    # Tentar log se a funcao existir, sem falhar caso contrario
    if command -v _log_erro >/dev/null 2>&1; then
        _log_erro "Falha na linha $line_number (codigo: $exit_code)" 2>/dev/null || true
    fi

    _cleanup_on_exit
    exit "$exit_code"
}

# Funcao para tratar interrupcoes
_handle_interrupt() {
    printf "\nInterrupcao detectada. Limpando recursos...\n" >&2

    if command -v _log >/dev/null 2>&1; then
        _log "Interrupcao detectada pelo usuario" 2>/dev/null || true
    fi

    _cleanup_on_exit
    exit 130
}

# =============================================================================
# FUNCOES DE STRING
# =============================================================================

# Remove espacos em branco do inicio e fim de uma string
# Parametros: $1=string
# Retorna: string sem espacos nas extremidades
_trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Converte string para maiuscula
# Parametros: $1=string
# Retorna: string em maiuscula
_upper() {
    printf '%s' "${1^^}"
}

# Sanitizar entrada do usuario (remover caracteres potencialmente perigosos)
_sanitizar_entrada() {
    local entrada="$1"
    # Remove caracteres de controle exceto nova linha e tab
    entrada="${entrada//[$'\x00'-$'\x08'$'\x0b'$'\x0c'$'\x0e'-$'\x1f']}"
    printf '%s' "$entrada"
}

# =============================================================================
# FUNCOES DE TELA
# =============================================================================

# Limpar tela
_clear_screen() {
    clear 2>/dev/null || true
}

# Posiciona o cursor no meio da tela
_meio_da_tela() {
    local linhas colunas

    linhas=$(tput lines 2>/dev/null || echo "${LINES:-24}")
    colunas=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")

    tput clear 2>/dev/null || true
    tput cup $((linhas / 2)) 0 2>/dev/null || true
}

# Exibe mensagem centralizada com cor
# Parametros: $1=cor $2=mensagem
_exibir_mensagem_centralizada() {
    local cor="${1}"
    local mensagem="${2}"
    local colunas
    local tamanho_mensagem
    local margem

    # Garantir que NORM e cor estejam definidos (fallback seguro)
    : "${NORM:=}"
    : "${cor:=}"

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-80}"
    fi

    tamanho_mensagem=${#mensagem}

    if [[ "$colunas" -lt "$tamanho_mensagem" ]]; then
        printf "%s%s%s\n" "${cor}" "${mensagem}" "${NORM}"
    else
        margem=$(( (colunas - tamanho_mensagem) / 2 ))
        printf "%s%*s%s%s\n" "${cor}" "$margem" "" "${mensagem}" "${NORM}"
    fi
}

# Exibe mensagem alinhada a direita
# Parametros: $1=cor $2=mensagem
_exibir_mensagem_direita() {
    local cor="${1}"
    local mensagem="${2}"
    local largura_terminal largura_mensagem posicao_inicio

    : "${NORM:=}"

    if ! largura_terminal=$(tput cols 2>/dev/null); then
        largura_terminal="${COLUMNS:-80}"
    fi

    largura_mensagem=${#mensagem}
    posicao_inicio=$((largura_terminal - largura_mensagem))

    if [[ "$posicao_inicio" -lt 0 ]]; then
        posicao_inicio=0
    fi

    printf "%s%*s%s${NORM}\n" "${cor}" "${posicao_inicio}" "" "$mensagem"
}

# Cria linha horizontal com caractere especificado
# Parametros: $1=caractere (opcional, padrao='-') $2=cor (opcional)
_linha() {
    local traco="${1:--}"
    local cor="${2:-}"
    local colunas

    : "${NORM:=}"

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-80}"
    fi

    if [[ "$colunas" -lt 10 ]]; then
        colunas=10
    fi

    printf "%s" "${cor}"
    printf '%*s\n' "$colunas" '' | tr ' ' "$traco"
    printf "%s" "${NORM}"
}

# Cria meia linha horizontal com caractere especificado
# Parametros:
#   $1 = caractere (opcional, padrao='-')
#   $2 = cor (opcional)
#   $3 = largura em caracteres (opcional, padrao=40)
_meia_linha() {
    local traco="${1:--}"
    local cor="${2:-}"
    local largura="${3:-40}"
    local espacos linhas colunas

    : "${NORM:=}"

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-80}"
    fi

    printf -v espacos "%${largura}s" ""
    linhas="${espacos// /$traco}"
    printf "%s" "${cor}"
    printf "%*s\n" $(((colunas + largura) / 2)) "$linhas"
    printf "%s" "${NORM}"
}

# =============================================================================
# FUNCOES DE CONTROLE DE FLUXO
# =============================================================================

# Pausa a execucao por tempo especificado
# Parametros: $1=tempo_em_segundos
_aguardar() {
    local tempo="${1:-}"

    if [[ -z "$tempo" ]]; then
        printf "Erro: Nenhum argumento passado para _aguardar.\n" >&2
        return 1
    fi

    if ! [[ "$tempo" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf "Erro: Argumento invalido para _aguardar: %s\n" "$tempo" >&2
        return 1
    fi

    read -rt "$tempo" <> /dev/tty 2>/dev/null || :
}

# Aguarda pressionar qualquer tecla com timeout
# Parametros: $1=mensagem $2=timeout (opcional)
_aguardar_tecla() {
    local mensagem="${1:-... Pressione qualquer tecla para continuar ...}"
    local timeout="${2:-${DEFAULT_PRESS_TIMEOUT:-15}}"
    local colunas

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-80}"
    fi

    printf "%s" "${YELLOW:-}"
    printf "%*s\n" $(((36 + colunas) / 2)) "<< $mensagem >>"
    printf "%s" "${NORM:-}"
    read -rt "$timeout" 2>/dev/null || :
    tput sgr0 2>/dev/null || true
}

# =============================================================================
# ALIASES PARA COMPATIBILIDADE
# =============================================================================
_limpa_tela() { _clear_screen "$@"; }
_mensagec()   { _exibir_mensagem_centralizada "$@"; }
_mensaged()   { _exibir_mensagem_direita "$@"; }
_press()      { _aguardar_tecla "$@"; }

# =============================================================================
# MENSAGEM DE OPCAO INVALIDA
# =============================================================================
_opinvalida() {
    local mensagem="Opcao Invalida"
    local largura tamanho_msg espacos

    if ! largura=$(tput cols 2>/dev/null); then
        largura="${COLUMNS:-80}"
    fi
    : "${RED:=}" "${YELLOW:=}" "${NORM:=}"

    tamanho_msg=${#mensagem}
    espacos=$(( (largura - tamanho_msg) / 2 ))
    (( espacos < 0 )) && espacos=0

    _linha "-" "${YELLOW}"
    printf "%${espacos}s" ""

    local i
    for ((i = 0; i < ${#mensagem}; i++)); do
        printf "%s%s%s" "${RED}" "${mensagem:$i:1}" "${NORM}"
        _aguardar 0.05
    done
    printf "\n"
    _linha "-" "${YELLOW}"
}

# =============================================================================
# FUNCOES DE VALIDACAO
# =============================================================================

# Valida nome de programa (letras maiusculas e numeros)
# Parametros: $1=nome_programa
# Retorna: 0=valido 1=invalido
_validar_nome_programa() {
    local programa="$1"
    [[ -n "$programa" && "$programa" =~ ^[A-Z0-9]+$ ]]
}

# Valida se diretorio existe e e acessivel
# Parametros: $1=caminho_diretorio
# Retorna: 0=valido 1=invalido
_validar_diretorio() {
    local dir="$1"
    [[ -n "$dir" && -d "$dir" && -r "$dir" ]]
}

# Solicita confirmacao S/N
# Parametros: $1=mensagem $2=padrao (S/N)
# Retorna: 0=sim 1=nao
_confirmar() {
    local mensagem="$1"
    local padrao="${2:-N}"
    local opcoes resposta tentativas=0
    local max_tentativas=3

    case "$padrao" in
        [Ss]) opcoes="[S/n]" ;;
        [Nn]) opcoes="[N/s]" ;;
        *)    opcoes="[S/N]" ;;
    esac

    while (( tentativas < max_tentativas )); do
        if ! read -r -t "${DEFAULT_READ_TIMEOUT:-60}" -p "${YELLOW}${mensagem} ${opcoes}: ${NORM}" resposta; then
            _mensagec "${YELLOW}" "Entrada expirada. Usando padrao: ${padrao}"
            resposta="$padrao"
        fi

        [[ -z "$resposta" ]] && resposta="$padrao"

        case "${resposta,,}" in
            s|sim) return 0 ;;
            n|nao) return 1 ;;
            *)
                _linha "-" "${RED}"
                _mensagec "${RED}" "Resposta invalida. Use S ou N."
                _linha "-" "${RED}"
                ((tentativas++)) || true
                ;;
        esac
    done

    _mensagec "${RED}" "Maximo de tentativas excedido. Usando padrao: ${padrao}"
    case "${padrao,,}" in
        s|sim) return 0 ;;
        *)     return 1 ;;
    esac
}

# =============================================================================
# FUNCOES DE PROGRESSO
# =============================================================================

# Exibe indicador de atividade enquanto processo esta em andamento
# Parametros:
#   $1 = PID do processo em background
#   $2 = mensagem opcional (padrao: "Processo em andamento")
# Retorna: codigo de saida do processo
_mostrar_progresso() {
    local pid="${1:-}"
    local msg="${2:-Processo em andamento}"
    local spin="/-\|"
    local i=0
    local status_proc=0

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        _mensagec "${YELLOW:-}" "Aviso: PID nao informado ou processo ja terminado"
        return 0
    fi

    : "${GREEN:=}" "${NORM:=}"

    # Ocultar cursor se suportado
    printf "\033[?25l" 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r%s[*] %s %s%s" "${GREEN}" "${msg}" "${spin:$i:1}" "${NORM}"
        sleep 1 2>/dev/null || sleep 1
    done

    # Restaurar cursor
    printf "\033[?25h" 2>/dev/null || true

    # Coletar status de saida
    wait "$pid" 2>/dev/null && status_proc=0 || status_proc=$?

    # Apagar linha de progresso
    printf "\r"
    printf "%*s\r" "${COLUMNS:-80}" ""

    # Mostrar resultado
    if [[ $status_proc -eq 0 ]]; then
        printf "%s[ok] %s concluido (status=%d)%s\n" "${GREEN}" "${msg}" "$status_proc" "${NORM}"
    else
        printf "%s[ERRO] %s falhou (status=%d)%s\n" "${RED:-}" "${msg}" "$status_proc" "${NORM}"
    fi

    return $status_proc
}

# =============================================================================
# FUNCOES DE LOG
# =============================================================================

# Registra mensagem no log com timestamp
# Parametros: $1=mensagem $2=arquivo_log (opcional)
_log() {
    local mensagem="$1"
    local arquivo_log="${2:-${LOG_ATU:-}}"
    local timestamp usuario_log log_dir

    # Fallback se arquivo de log nao definido
    if [[ -z "$arquivo_log" ]]; then
        arquivo_log="/var/log/sav.log"
    fi

    log_dir=$(dirname "$arquivo_log")

    # Silenciosamente ignorar se diretorio nao existe
    [[ -d "$log_dir" ]] || return 0
    [[ -w "$log_dir" ]] || return 0

    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "sem-data")
    usuario_log="${usuario:-SISTEMA}"

    printf "[%s] [%s] %s\n" "$timestamp" "$usuario_log" "$mensagem" >> "$arquivo_log" 2>/dev/null || true
}

# Registra erro no log
# Parametros: $1=mensagem_erro $2=arquivo_log (opcional)
_log_erro() {
    _log "ERRO: $1" "${2:-}"
}

# Registra sucesso no log
# Parametros: $1=mensagem_sucesso $2=arquivo_log (opcional)
_log_sucesso() {
    _log "SUCESSO: $1" "${2:-}"
}

# =============================================================================
# FUNCOES DE ARQUIVO
# =============================================================================

# Remove arquivos antigos de um diretorio
# Parametros: $1=diretorio $2=dias $3=padrao (opcional, default=*)
# Retorna: 0=sucesso 1=erro
_limpar_arquivos_antigos() {
    local diretorio="$1"
    local dias="$2"
    local padrao="${3:-*}"
    local count=0

    # Validacao de seguranca contra limpeza acidental
    if [[ ! -d "$diretorio" || "$diretorio" == "/" || "$diretorio" == "//" ]]; then
        _log_erro "Diretorio nao encontrado ou inseguro para remocao: $diretorio"
        return 1
    fi

    if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
        _log_erro "Numero de dias invalido: $dias"
        return 1
    fi

    local arquivos
    mapfile -t arquivos < <(find "$diretorio" -maxdepth 1 -name "$padrao" -type f -mtime +"$dias" -print 2>/dev/null)
    count=${#arquivos[@]}

    if (( count > 0 )); then
        _log "Removendo $count arquivo(s) antigo(s) de $diretorio"
        local arquivo
        for arquivo in "${arquivos[@]}"; do
            rm -f "$arquivo" 2>/dev/null || true
        done
        _log "Remocao concluida: $count arquivo(s) removido(s)"
    else
        _log "Nenhum arquivo antigo encontrado em $diretorio"
    fi

    return 0
}

# =============================================================================
# LIMPEZA AUTOMATICA DIARIA
# =============================================================================

# Executa expurgo automatico de arquivos antigos
# Usa flag file para garantir execucao unica por dia
_executar_expurgador_diario() {
    local flag_file
    local savlog="${RAIZ:-}/portalsav/log"
    local err_isc="${RAIZ:-}/err_isc"
    local viewvix="${RAIZ:-}/savisc/viewvix/tmp"

    # Define diretório de logs com fallback
    local logs_dir="${DEFAULT_LOGS_DIR:-}"
    flag_file="${logs_dir}/.expurgador_$(date +%Y%m%d)"

    # Se ja executou hoje, pular
    [[ -f "$flag_file" ]] && return 0

    # Remover flags antigas (mais de 3 dias)
    [[ -d "$logs_dir" ]] && find "$logs_dir" -name ".expurgador_*" -mtime +3 -delete 2>/dev/null || true

    # Configuracoes de limpeza: diretorio => dias de retencao
    _expurgar_dir() {
        local dir="$1"
        local dias="$2"
        [[ -n "$dir" && -d "$dir" ]] && _limpar_arquivos_antigos "$dir" "$dias" "*.*" 2>/dev/null || true
    }

    _expurgar_dir "${logs_dir}"                        30
    _expurgar_dir "${DEFAULT_BACKUP_DIR:-}"            30
    _expurgar_dir "${DEFAULT_BASEBACKUP_DIR:-}"        30
    _expurgar_dir "${DEFAULT_OLDS_DIR:-}"              30
    _expurgar_dir "${DEFAULT_PROGS_DIR:-}"             30
    _expurgar_dir "${DEFAULT_ENVIA_DIR:-}"             30
    _expurgar_dir "${DEFAULT_RECEBE_DIR:-}"            30
    _expurgar_dir "${savlog}"                          30
    _expurgar_dir "${DEFAULT_LOGS_DIR:-}"              30
    _expurgar_dir "${DEFAULT_BIBLIOTECA_ATUAL_DIR:-}"  30
    _expurgar_dir "${DEFAULT_BIBLIOTECA_DIR:-}"        30
    _expurgar_dir "${err_isc}"                         30
    _expurgar_dir "${viewvix}"                         30
 
    # Criar flag para hoje
    if touch "$flag_file" 2>/dev/null; then
        _log "Limpeza automatica diaria executada"
    fi

    return 0
}

# =============================================================================
# VERIFICACAO DE DEPENDENCIAS
# =============================================================================

# Verifica se os programas necessarios estao instalados
# Parametros: lista de programas a verificar (padrao: zip unzip rsync wget)
# Retorna: 0 se todos encontrados, 1 se algum ausente
_check_instalado() {
    local apps=("$@")
    [[ ${#apps[@]} -eq 0 ]] && apps=(zip unzip rsync wget)

    local missing=()
    local install_cmd=""

    # Detectar gerenciador de pacotes
    if command -v apt >/dev/null 2>&1; then
        install_cmd="sudo apt update && sudo apt install"
    elif command -v yum >/dev/null 2>&1; then
        install_cmd="sudo yum install"
    elif command -v dnf >/dev/null 2>&1; then
        install_cmd="sudo dnf install"
    elif command -v pacman >/dev/null 2>&1; then
        install_cmd="sudo pacman -S"
    elif command -v zypper >/dev/null 2>&1; then
        install_cmd="sudo zypper install"
    else
        install_cmd="Instale manualmente"
    fi

    local app
    for app in "${apps[@]}"; do
        if ! command -v "$app" >/dev/null 2>&1; then
            missing+=("$app")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "\n%sERRO: Programas nao encontrados%s\n" "${RED:-}" "${NORM:-}"
        printf "%sProgramas ausentes: %s%s\n" "${YELLOW:-}" "${missing[*]}" "${NORM:-}"
        printf "%sSugestao: %s %s%s\n" "${YELLOW:-}" "$install_cmd" "${missing[*]}" "${NORM:-}"
        printf "%sInstale os programas ausentes e tente novamente.%s\n" "${YELLOW:-}" "${NORM:-}"
        return 1
    fi

    return 0
}
