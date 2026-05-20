#!/usr/bin/env bash
set -euo pipefail
#
# utils.sh - Modulo de Utilitarios e Funcoes Auxiliares  
# Funcoes basicas para formatacao, mensagens, validacao e controle de fluxo
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 20/05/2026-01

#---------- FUNCOES DE FORMATACAO DE TELA ----------#
# Variaveis globais esperadas
RAIZ="${RAIZ:-}"                                       # Diretorio RAIZ do sistema.

#---------- FUNCOES DE STRING ----------#

# Remove espacos em branco do inicio e fim de uma string
# Parametros: $1=string
# Retorna: string sem espacos nas extremidades
_trim() {
    local var="$1"
    # Remove espacos do inicio
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove espacos do fim
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Converte string para maiuscula
# Parametros: $1=string
# Retorna: string em maiuscula
_upper() {
    printf '%s' "${1^^}"
}

#---------- FUNCOES DE SISTEMA ----------#

# Array global para arquivos temporarios (para limpeza)
declare -ga TEMP_FILES=()
declare -ga BACKGROUND_PIDS=()

# Funcao de limpeza chamada na saida
_cleanup_on_exit() {
    local exit_code=$?
    
    # Matar processos em background
    if [[ ${#BACKGROUND_PIDS[@]} -gt 0 ]]; then
        for pid in "${BACKGROUND_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # Remover arquivos temporarios
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        for temp_file in "${TEMP_FILES[@]}"; do
            [[ -e "$temp_file" ]] && rm -f "$temp_file" 2>/dev/null || true
        done
    fi
    
    return $exit_code
}

# Funcao para tratar erros
_handle_error() {
    local exit_code=$?
    local line_number="${1:-$LINENO}"
    
    printf "ERRO: Falha na linha %d (codigo: %d)\n" "$line_number" "$exit_code" >&2
    
    # Log do erro se possivel
    if command -v _log_erro >/dev/null 2>&1; then
        _log_erro "Falha na linha $line_number (codigo: $exit_code)"
    fi
    
    _cleanup_on_exit
    exit $exit_code
}

# Funcao para tratar interrupcoes
_handle_interrupt() {
    printf "\nInterrupcao detectada. Limpando recursos...\n" >&2
    
    if command -v _log >/dev/null 2>&1; then
        _log "Interrupcao detectada pelo usuario"
    fi
    
    _cleanup_on_exit
    exit 130  # Codigo padrao para SIGINT
}

# Configurar traps (deve ser chamado pelos modulos principais)
_setup_traps() {
    trap '_cleanup_on_exit' EXIT
    trap '_handle_error $LINENO' ERR
    trap '_handle_interrupt' INT TERM
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

# Funcao para limpar tela
_clear_screen() {
    clear
}

# Posiciona o cursor no meio da tela
_meio_da_tela() {
    local linhas
    local colunas

    linhas=$(tput lines 2>/dev/null || echo "${LINES:-${DEFAULT_LINES}}")
    colunas=$(tput cols 2>/dev/null || echo "${COLUMNS:-${DEFAULT_COLUMNS}}")

    # Usar tput para posicionar o cursor — consistente com o restante do arquivo
    tput clear 2>/dev/null || true
    tput cup $((linhas / 2)) 0 2>/dev/null || true
}

# Exibe mensagem centralizada com cor
# Parametros: $1=cor $2=mensagem
_mensageb() {
#_exibir_bloco_centralizado() {
    local cor="${1}"
    local mensagem="${2}"
    local largura_bloco="${3:-30}" # Largura do bloco (padrão 30)
    local colunas
    local margem_esquerda

    # Garantir que NORM e cor estejam definidos (fallback seguro)
    : "${NORM:=}"
    : "${cor:=}"

    # Obter largura do terminal
    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-${DEFAULT_COLUMNS}}"
    fi

    # Calcular a margem para centralizar o BLOCO inteiro na tela
    if [[ "$colunas" -le "$largura_bloco" ]]; then
        margem_esquerda=0
    else
        margem_esquerda=$(( (colunas - largura_bloco) / 2 ))
    fi

    # O printf faz o seguinte:
    # 1. %*s -> Imprime a margem esquerda (espaços vazios)
    # 2. %s  -> Inicia a cor
    # 3. %-*s -> Imprime a mensagem alinhada à esquerda dentro da largura do bloco
    # 4. %s  -> Reseta a cor (NORM)
    printf "%*s%s%-*s%s\n" \
        "$margem_esquerda" "" \
        "${cor}" \
        "$largura_bloco" "${mensagem}" \
        "${NORM}"
}

# Exibe mensagem centralizada com cor
_exibir_mensagem_centralizada() {
    local cor="${1}"
    local mensagem="${2}"
    local colunas

    colunas=$(tput cols 2>/dev/null || echo "${COLUMNS:-${DEFAULT_COLUMNS}}")
    local tamanho_mensagem=${#mensagem}

    if [[ "$colunas" -lt "$tamanho_mensagem" ]]; then
        # Terminal muito estreito — exibir sem centralizar
        printf "%s%s%s\n" "${cor}" "${mensagem}" "${NORM}"
    else
        # Calcula margem esquerda para centralizar
        local margem=$(( (colunas - tamanho_mensagem) / 2 ))
        printf "%s%*s%s%s\n" "${cor}" "$margem" "" "${mensagem}" "${NORM}"
    fi
}

# Exibe mensagem alinhada à direita
# Parametros: $1=cor $2=mensagem  
_exibir_mensagem_direita() {
    local cor="${1}"
    local mensagem="${2}"
    local largura_terminal largura_mensagem posicao_inicio

    # Obter largura do terminal com fallback seguro
    if ! largura_terminal=$(tput cols 2>/dev/null); then
        largura_terminal="${COLUMNS:-${DEFAULT_COLUMNS}}"
    fi

    largura_mensagem=${#mensagem}
    posicao_inicio=$((largura_terminal - largura_mensagem))

    # Garante posição mínima não negativa
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

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-${DEFAULT_COLUMNS}}"
    fi

    if [[ "$colunas" -lt 10 ]]; then
        colunas=10
    fi

    printf "%s" "${cor}"
    printf '%*s\n' "$colunas" '' | tr ' ' "$traco"
    printf "%s" "${NORM}"
}


# Cria meia linha horizontal com caractere especificado
# Parametros: $1=caractere (opcional, padrao='-') $2=cor (opcional)
# Exibe linha horizontal centralizada com largura delimitada
# Parametros:
#   $1 = caractere (opcional, padrao='-')
#   $2 = cor (opcional)
#   $3 = largura em caracteres (opcional, padrao=40)
_meia_linha() {
    local traco="${1:--}"
    local cor="${2:-}"
    local largura="${3:-40}"
    local espacos linhas colunas

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-${DEFAULT_COLUMNS}}"
    fi

    printf -v espacos "%${largura}s" ""
    linhas=${espacos// /$traco}
    printf "%s" "${cor}"
    printf "%*s\n" $(((colunas + largura) / 2)) "$linhas"
    printf "%s" "${NORM}"
}


#---------- FUNcoES DE CONTROLE DE FLUXO ----------#

# Pausa a execucao por tempo especificado
# Parametros: $1=tempo_em_segundos
_aguardar() {
    local tempo="${1:-}"

    if [[ -z "$tempo" ]]; then
        printf "Erro: Nenhum argumento passado para _aguardar.\n" >&2
        return 1
    fi

    if ! [[ "$tempo" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf "Erro: Argumento inválido para _aguardar: %s\n" "$tempo" >&2
        return 1
    fi

    read -rt "$tempo" <> <(:) || :
}


# Aguarda pressionar qualquer tecla com timeout
_aguardar_tecla() {
    local mensagem="${1:-... Pressione qualquer tecla para continuar ...}"
    local timeout="${2:-${DEFAULT_PRESS_TIMEOUT}}"
    local colunas

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-${DEFAULT_COLUMNS}}"
    fi

    printf "%s" "${YELLOW}"
    printf "%*s\n" $(((36 + colunas) / 2)) "<< $mensagem >>"
    printf "%s" "${NORM}"
    read -rt "$timeout" || :
    tput sgr0 2>/dev/null || true
}

#---------- ALIASES PARA COMPATIBILIDADE ----------#
# Manter compatibilidade com código existente durante transição

# Aliases para funções renomeadas
_limpa_tela() { _clear_screen "$@"; }
_mensagec() { _exibir_mensagem_centralizada "$@"; }
_mensaged() { _exibir_mensagem_direita "$@"; }
_press() { _aguardar_tecla "$@"; }

_opinvalida() {
    local mensagem="Opcao Invalida"
    local largura
    local tamanho_msg
    local espacos

    # Obter largura do terminal com fallback seguro
    if ! largura=$(tput cols 2>/dev/null); then
        largura="${COLUMNS:-${DEFAULT_COLUMNS}}"
    fi

    tamanho_msg=${#mensagem}
    espacos=$(( (largura - tamanho_msg) / 2 ))

    # Garantir que nao seja negativo
    if (( espacos < 0 )); then
        espacos=0
    fi

    _linha "-" "${YELLOW}"

    # Imprimir espacos iniciais para centralizar
    printf "%${espacos}s" ""

    # Loop para imprimir cada letra com efeito de digitacao
    for ((i=0; i<${#mensagem}; i++)); do
        printf "%s" "${RED}${mensagem:$i:1}${NORM}"
        _aguardar 0.05
    done
    printf "\n"
    _linha "-" "${YELLOW}"
}

#---------- FUNCOES DE VALIDACAO ----------#

# Valida nome de programa (letras maiúsculas e números)
# Parametros: $1=nome_programa
# Retorna: 0=valido 1=invalido
_validar_nome_programa() {
    local programa="$1"

    if [[ -z "$programa" ]]; then
        return 1
    fi

    [[ "$programa" =~ ^[A-Z0-9]+$ ]]
}

# Valida se diretorio existe e e acessivel
# Parametros: $1=caminho_diretorio
# Retorna: 0=valido 1=invalido
_validar_diretorio() {
    local dir="$1"

   [[ -n "$dir" && -d "$dir" && -r "$dir" ]]
}

# Solicita confirmacao S/N
# Parametros: $1=mensagem $2=padrao(S/N)
# Retorna: 0=sim 1=nao
_confirmar() {
    local mensagem="$1"
    local padrao="${2:-N}"
    local opcoes
    local resposta
    local tentativas=0
    local max_tentativas=3

    case "$padrao" in
        [Ss]) opcoes="[S/n]" ;;
        [Nn]) opcoes="[N/s]" ;;
        *) opcoes="[S/N]" ;;
    esac

    while (( tentativas < max_tentativas )); do
        if ! read -r -t "${DEFAULT_READ_TIMEOUT}" -p "${YELLOW}${mensagem} ${opcoes}: ${NORM}" resposta; then
            # Timeout ou erro de leitura — usar padrao
            _mensagec "${YELLOW}" "Entrada expirada. Usando padrao: ${padrao}"
            resposta="$padrao"
        fi

        # Se resposta vazia, usar padrao
        if [[ -z "$resposta" ]]; then
            resposta="$padrao"
        fi

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
        *) return 1 ;;
    esac
}

#---------- FUNCOES DE PROGRESSO ----------#
# Exibe progresso do backup com barra de blocos e porcentagem
# Parametros:
#   $1 = PID do processo de backup em background
#   $2 = mensagem opcional (padrao: "Backup em andamento")
# Retorna: codigo de saida do processo de backup
_mostrar_progresso_backup() {
    local pid="${1:-}"
    local msg="${2:-Backup em andamento}"
    local delay=0.5
    local status_proc=0
    local colunas inicio

    # Validações iniciais
    if [[ -z "$pid" ]]; then
        _mensagec "${YELLOW}" "Aviso: PID nao informado ou processo ja terminado"
        return 0
    fi

    # Se o processo ja terminou antes de chegarmos aqui, coletar status e sair
    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null && status_proc=0 || status_proc=$?
        return "${status_proc}"
    fi

    # Usar comandos básicos compatíveis com sistemas antigos
    colunas=$(stty size 2>/dev/null | cut -d' ' -f2 || echo 80)
    inicio=$(date +%s 2>/dev/null || echo 0)
    local barra_largura=30
    local progresso=0
    local delay=0.5
    
    # Tentar ocultar cursor (se suportado)
    printf "\033[?25l" 2>/dev/null || true

    # Loop da barra de progresso
    while kill -0 "$pid" 2>/dev/null; do
        local agora decorrido
        agora=$(date +%s 2>/dev/null || echo 0)
        
        if [[ "$inicio" != "0" && "$agora" != "0" ]]; then
            decorrido=$(( agora - inicio ))
        else
            # Fallback: usar contador simples se date não funcionar
            decorrido=$(( progresso / 2 ))
        fi
        
        # Calcular minutos e segundos
        local min=$(( decorrido / 60 ))
        local sec=$(( decorrido % 60 ))
        
        # Simular progresso baseado no tempo (ciclo de 60s para barra completa)
        progresso=$(( (decorrido % 60) * barra_largura / 60 ))
        
        # Construir barra com caracteres ASCII
        local barra=""
        local i
        for ((i=0; i<barra_largura; i++)); do
            if (( i < progresso )); then
                barra+="#"
            else
                barra+="-"
            fi
        done
        
        # Calcular porcentagem
        local porcentagem=$(( progresso * 100 / barra_largura ))

        printf "\r%s%s%s: [%s%s%s] %3d%% (%02d:%02d)     " \
            "${GREEN}" "${msg}" "${NORM}" \
            "${YELLOW}" "${barra}" "${NORM}" \
            "${porcentagem}" "${min}" "${sec}"        
    
        # Sleep compatível com sistemas antigos
        if command -v sleep >/dev/null 2>&1; then
            sleep "${delay}" 2>/dev/null || sleep 1
        else
            read -rt "${delay}" <> /dev/null 2>/dev/null || true 
 
        fi
    done

    # Restaurar cursor (se suportado)
    printf "\033[?25h" 2>/dev/null || true

    # Coletar status de saida do processo filho
    wait "$pid" 2>/dev/null && status_proc=0 || status_proc=$?

    # Apagar linha de progresso
    printf "\r"
    local i
    for ((i=0; i<colunas; i++)); do
        printf " "
    done
    printf "\r"

    # Mostrar resultado final
    if [[ "${status_proc}" -eq 0 ]]; then
        local agora_final decorrido_final min_final sec_final
        agora_final=$(date +%s 2>/dev/null || echo 0)
        if [[ "$inicio" != "0" && "$agora_final" != "0" ]]; then
            decorrido_final=$(( agora_final - inicio ))
            min_final=$(( decorrido_final / 60 ))
            sec_final=$(( decorrido_final % 60 ))
            printf "%s: [##############################] 100%% Concluido! (%02d:%02d)\n" \
                "${msg}" "${min_final}" "${sec_final}"
        else
            printf "%s: [##############################] 100%% Concluido!\n" "${msg}"
        fi
    else
        printf "%s: [##############################] Falhou (status=%d)\n" "${msg}" "${status_proc}"
    fi

    return "${status_proc}"
}

#---------- FUNCOES DE LOG ----------#

# Registra mensagem no log com timestamp
# Parametros: $1=mensagem $2=arquivo_log(opcional)
_log() {
    local mensagem="$1"
    local arquivo_log="${2:-$LOG_ATU}"
    local timestamp usuario_log

    # Validação do arquivo de log
    if [[ -z "$arquivo_log" ]]; then
        arquivo_log="/var/log/sav.log"
    fi

    # Verifica se o diretório do log existe e é gravável
    local log_dir
    log_dir=$(dirname "$arquivo_log")
    if [[ ! -d "$log_dir" ]]; then
        printf "Erro: Diretorio de log nao existe: %s\n" "$log_dir" >&2
        return 1
    fi

    if [[ ! -w "$log_dir" ]]; then
        printf "Aviso: Sem permissao de escrita no diretorio de log: %s\n" "$log_dir" >&2
        return 1
    fi

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    usuario_log="${usuario:-SISTEMA}"

    if printf "[%s] [%s] %s\n" "$timestamp" "$usuario_log" "$mensagem" >> "$arquivo_log"; then
        return 0
    else
        printf "Erro: Falha ao escrever no log: %s\n" "$arquivo_log" >&2
        return 1
    fi
}

# Registra erro no log
# Parametros: $1=mensagem_erro $2=arquivo_log(opcional)
_log_erro() {
    local erro="$1"
    local arquivo_log="${2:-$LOG_ATU}"
    
    _log "ERRO: $erro" "$arquivo_log" || true
}

# Registra sucesso no log  
# Parametros: $1=mensagem_sucesso $2=arquivo_log(opcional)
_log_sucesso() {
    local sucesso="$1"
    local arquivo_log="${2:-$LOG_ATU}"
    
    _log "SUCESSO: $sucesso" "$arquivo_log" || true
}

#---------- FUNCOES DE ARQUIVO ----------#

# Remove arquivos antigos de um diretorio
# Parametros: $1=diretorio $2=dias $3=padrao(opcional)
_limpar_arquivos_antigos() {
    local diretorio="$1"
    local dias="$2"
    local padrao="${3:-*}"
    local count=0
    local arquivos

    # Validação do diretório e segurança contra limpeza na RAIZ
    if [[ ! -d "$diretorio" || "$diretorio" == "/" || "$diretorio" == "//" ]]; then
        _log_erro "Diretorio nao encontrado ou inseguro para remocao: $diretorio"
        return 1
    fi

    # Validação do número de dias
    if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
        _log_erro "Numero de dias invalido: $dias"
        return 1
    fi

    # Monta lista de arquivos para exclusão
    mapfile -t arquivos < <(find "$diretorio" -name "$padrao" -type f -mtime +"$dias" -print 2>/dev/null)
    count=${#arquivos[@]}

    if ((count > 0)); then
        _log "Removendo $count arquivos antigos de $diretorio"
        # Remove os arquivos diretamente
        for arquivo in "${arquivos[@]}"; do
            rm -f "$arquivo" 2>/dev/null || true
        done
        _log "Remocao concluida: $count arquivos removidos"
    else
        _log "Nenhum arquivo antigo encontrado em $diretorio"
    fi

    return 0
}

#---------- FUNCOES DE INICIALIZACAO ----------#
# Executa limpeza automatica diaria
_executar_expurgador_diario() {
    local flag_file
    local savlog="${RAIZ}/portalsav/log"
    local err_isc="${RAIZ}/err_isc"
    local viewvix="${RAIZ}/savisc/viewvix/tmp"

    # Define diretório de logs com fallback
    local logs_dir="${DEFAULT_LOGS_DIR:-}"
    flag_file="${logs_dir}/.expurgador_$(date +%Y%m%d)"

    # Se já foi executado hoje, pular
    if [[ -f "$flag_file" ]]; then
        return 0
    fi

    # Remover flags antigas (mais de 3 dias)
    find "${logs_dir}" -name ".expurgador_*" -mtime +3 -delete 2>/dev/null || true

    # Array de diretórios e configurações de limpeza
    local -A configuracoes=(
        ["${DEFAULT_LOGS_DIR:-}"]=30
        ["${DEFAULT_BACKUP_DIR:-}"]=30
        ["${DEFAULT_BASEBACKUP_DIR:-}"]=30
        ["${DEFAULT_OLDS_DIR:-}"]=30
        ["${DEFAULT_PROGS_DIR:-}"]=10
        ["${DEFAULT_ENVIA_DIR:-}"]=10
        ["${DEFAULT_RECEBE_DIR:-}"]=10
    )

    # Loop otimizado para limpeza
    for dir in "${!configuracoes[@]}"; do
        if [[ -n "$dir" && -d "$dir" ]]; then
            _limpar_arquivos_antigos "$dir" "${configuracoes[$dir]}" "*.*" 2>/dev/null || true
        fi
    done

    # Limpar arquivos específicos do sistema
    _limpar_arquivos_antigos "${savlog}" 30 "*.*" 2>/dev/null || true
    _limpar_arquivos_antigos "${err_isc}" 30 "*.*" 2>/dev/null || true
    _limpar_arquivos_antigos "${viewvix}" 30 "*.*" 2>/dev/null || true

    # Criar flag para hoje
    if touch "$flag_file" 2>/dev/null; then
        _log "Limpeza automatica diaria executada"
    fi

    return 0
}

# Funcao para checar se os programas necessarios estao instalados
# Checa se os programas necessarios para o atualiza.sh estao instalados no sistema.
# Se algum programa nao for encontrado, exibe uma mensagem de erro e sai do programa.
# Parametros: lista de programas a verificar (padrao: zip unzip rsync wget)
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

    for app in "${apps[@]}"; do
        if ! command -v "$app" >/dev/null 2>&1; then
            missing+=("$app")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "\n%sERRO: Programas nao encontrados%s\n" "${RED}" "${NORM}"
        printf "%sProgramas ausentes: %s%s\n" "${YELLOW}" "${missing[*]}" "${NORM}"
        printf "%sSugestao: %s %s%s\n" "${YELLOW}" "$install_cmd" "${missing[*]}" "${NORM}"
        printf "%sInstale os programas ausentes e tente novamente.%s\n" "${YELLOW}" "${NORM}"
        return 1
    fi
}