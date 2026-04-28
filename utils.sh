#!/usr/bin/env bash
#
# utils.sh - Modulo de Utilitarios e Funcoes Auxiliares  
# Funcoes basicas para formatacao, mensagens, validacao e controle de fluxo
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 24/04/2026-01

#---------- FUNCOES DE FORMATACAO DE TELA ----------#
# Variaveis globais esperadas
raiz="${raiz:-}"                                       # Diretorio raiz do sistema.
#LOGS="${LOGS:-$SCRIPT_DIR/logs}"                      # Diretorio de logs.

# Funcao para limpar tela
_limpa_tela() {
    clear
}

# Posiciona o cursor no meio da tela
_meio_da_tela() {
    local linhas
    local colunas

    linhas=$(tput lines 2>/dev/null || echo "${LINES:-24}")
    colunas=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")

    # Usar tput para posicionar o cursor — consistente com o restante do arquivo
    tput clear 2>/dev/null || true
    tput cup $((linhas / 2)) 0 2>/dev/null || true
}

# Exibe mensagem centralizada com cor
_mensagec() {
    local cor="${1}"
    local mensagem="${2}"
    local colunas

    colunas=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
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
_mensaged() {
    local cor="${1}"
    local mensagem="${2}"
    local largura_terminal largura_mensagem posicao_inicio

    # Obter largura do terminal com fallback seguro
    if ! largura_terminal=$(tput cols 2>/dev/null); then
        largura_terminal="${COLUMNS:-80}"
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
        colunas="${COLUMNS:-80}"
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
_read_sleep() {
    local tempo="${1:-}"

    if [[ -z "$tempo" ]]; then
        printf "Erro: Nenhum argumento passado para _read_sleep.\n" >&2
        return 1
    fi

    if ! [[ "$tempo" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf "Erro: Argumento inválido para _read_sleep: %s\n" "$tempo" >&2
        return 1
    fi

    read -rt "$tempo" <> <(:) || :
}


# Aguarda pressionar qualquer tecla com timeout
_press() {
    local mensagem="${1:-... Pressione qualquer tecla para continuar ...}"
    local timeout="${2:-15}"
    local colunas

    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUMNS:-80}"
    fi

    printf "%s" "${YELLOW}"
    printf "%*s\n" $(((36 + colunas) / 2)) "<< $mensagem >>"
    printf "%s" "${NORM}"
    read -rt "$timeout" || :
    tput sgr0 2>/dev/null || true
}

_opinvalida() {
    local mensagem="Opcao Invalida"
    local largura
    local tamanho_msg
    local espacos

    # Obter largura do terminal com fallback seguro
    if ! largura=$(tput cols 2>/dev/null); then
        largura="${COLUMNS:-80}"
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
        _read_sleep 0.05
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
        if ! read -r -t 30 -p "${YELLOW}${mensagem} ${opcoes}: ${NORM}" resposta; then
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

#---------- FUNcoES DE PROGRESSO ----------#

# Mostra progresso do backup com spinner animado e tempo decorrido
_mostrar_progresso_backup() {
    local pid="${1:-}"
    local delay=0.2
    local spin=( "|" "/" "-" "\\" )
    local i=0
    local elapsed=0
    local msg="Processo em andamento"
    local status_proc=0

    if [[ -z "$pid" ]]; then
        _mensagec "$YELLOW" "Aviso: PID nao informado para _mostrar_progresso_backup"
        return 0
    fi

    # Verifica se o processo ainda está ativo
    if ! kill -0 "$pid" 2>/dev/null; then
        _mensagec "$YELLOW" "Processo ja encerrou"
        return 0
    fi

    # Oculta o cursor
    tput civis 2>/dev/null || true

    # Salva posição do cursor
    tput sc 2>/dev/null || true
    printf "${YELLOW}%s... [${NORM}" "$msg"

    # Loop de animação
    while kill -0 "$pid" 2>/dev/null; do
        tput rc 2>/dev/null || true  # Restaura posição
        printf "${YELLOW}%s... [%3ds] ${NORM}${GREEN}%s${NORM}" \
            "$msg" "$elapsed" "${spin[i]}"
        i=$(( (i + 1) % ${#spin[@]} ))
        sleep "$delay"
        # Incrementa elapsed a cada 5 iterações (aproximadamente 1 segundo)
        if (( i % 5 == 0 )); then
            (( elapsed++ )) || true
        fi
    done

    # Mostra o cursor novamente
    tput cnorm 2>/dev/null || true

    # Captura o status do processo — sem propagar erro
    wait "$pid" 2>/dev/null && status_proc=0 || status_proc=$?

    if [[ "$status_proc" -eq 0 ]]; then
        printf "\r${GREEN}%s... [Concluido] ${NORM}\n" "$msg"
    else
        printf "\r${RED}%s... [Falhou] ${NORM}\n" "$msg"
    fi
    return "$status_proc"
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

    # Validação do diretório
    if [[ ! -d "$diretorio" ]]; then
        _log_erro "Diretorio nao encontrado: $diretorio"
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
    local savlog="${raiz}/portalsav/log"
    local err_isc="${raiz}/err_isc"
    local viewvix="${raiz}/savisc/viewvix/tmp"

    # Define diretório de logs com fallback
    local logs_dir="${LOGS:-/var/log/sav}"
    flag_file="${logs_dir}/.expurgador_$(date +%Y%m%d)"

    # Se já foi executado hoje, pular
    if [[ -f "$flag_file" ]]; then
        return 0
    fi

    # Remover flags antigas (mais de 3 dias)
    find "${logs_dir}" -name ".expurgador_*" -mtime +3 -delete 2>/dev/null || true

    # Array de diretórios e configurações de limpeza
    local -A configuracoes=(
        ["${LOGS:-}"]=30
        ["${BACKUP:-}"]=30
        ["${BASEBACKUP:-}"]=30
        ["${OLDS:-}"]=30
        ["${LIBS:-}"]=10
        ["${PROGS:-}"]=10
        ["${ENVIA:-}"]=10
        ["${RECEBE:-}"]=10
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