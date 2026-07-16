#!/usr/bin/env bash
set -euo pipefail
#
# utils.sh - Modulo de Utilitarios e Funcoes Auxiliares
# Funcoes basicas para formatacao, mensagens, validacao e controle de fluxo
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 13/07/2026-02
#
# =============================================================================
# Definição de variáveis globais
# =============================================================================
RAIZ="${RAIZ:-}"                                   # Diretorio RAIZ do sistema.

# Obtem largura do terminal com fallback seguro
# Retorna: numero de colunas
_obter_colunas() {
    local colunas
    if ! colunas=$(tput cols 2>/dev/null); then
        colunas="${COLUNAS:-${DEFAULT_COLUMNS:-80}}"
    fi
    printf '%s' "$colunas"
}

# Configuracao de alertas
    _msg()   { _exibir_mensagem_centralizada "${CIANO}" "[INFORMATIVO] $1"; }
    _ok()    { _exibir_mensagem_centralizada "${VERDE}" "[OK] $1"; }
    _aviso() { _exibir_mensagem_centralizada "${AMARELO}" "[AVISO] $1"; }
    _erro()  { _exibir_mensagem_centralizada "${VERMELHO}" "[ERRO] $1"; }

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

# Funcao para limpar tela
_limpa_tela() {
    clear
}

# Posiciona o cursor no meio da tela
_meio_da_tela() {
    local linhas
    local colunas

    linhas=$(tput lines 2>/dev/null || echo "${LINES:-${DEFAULT_LINES}}")
    colunas=$(_obter_colunas)

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
    local largura_bloco="${3:-30}" # Largura do bloco (padrao 30)
    local colunas
    local margem_esquerda

    # Garantir que NORM e cor estejam definidos (fallback seguro)
    : "${NORMAL:=}"
    : "${cor:=}"

    # Obter largura do terminal
    colunas=$(_obter_colunas)

    # Calcular a margem para centralizar o BLOCO inteiro na tela
    if [[ "$colunas" -le "$largura_bloco" ]]; then
        margem_esquerda=0
    else
        margem_esquerda=$(( (colunas - largura_bloco) / 2 ))
    fi

    printf "%*s%s%-*s%s\n" \
        "$margem_esquerda" "" \
        "${cor}" \
        "$largura_bloco" "${mensagem}" \
        "${NORMAL}"
}

# Exibe mensagem centralizada com cor
_exibir_mensagem_centralizada() {
    local cor="${1}"
    local mensagem="${2}"
    local colunas

    colunas=$(_obter_colunas)
    local tamanho_mensagem=${#mensagem}

    if [[ "$colunas" -lt "$tamanho_mensagem" ]]; then
        # Terminal muito estreito — exibir sem centralizar
        printf "%s%s%s\n" "${cor}" "${mensagem}" "${NORMAL}"
    else
        # Calcula margem esquerda para centralizar
        local margem=$(( (colunas - tamanho_mensagem) / 2 ))
        printf "%s%*s%s%s\n" "${cor}" "$margem" "" "${mensagem}" "${NORMAL}"
    fi
}

# Exibe mensagem alinhada à direita
# Parametros: $1=cor $2=mensagem
_exibir_mensagem_direita() {
    local cor="${1}"
    local mensagem="${2}"
    local largura_terminal largura_mensagem posicao_inicio

    # Obter largura do terminal com fallback seguro
    largura_terminal=$(_obter_colunas)

    largura_mensagem=${#mensagem}
    posicao_inicio=$((largura_terminal - largura_mensagem))

    # Garante posição mínima não negativa
    if [[ "$posicao_inicio" -lt 0 ]]; then
        posicao_inicio=0
    fi

    printf "%s%*s%s${NORMAL}\n" "${cor}" "${posicao_inicio}" "" "$mensagem"
}

_exibir_mensagem_corrida() {
    local cor="${1}"
    local mensagem="${2}"
    local largura_terminal largura_mensagem posicao_inicio

    # Obter largura do terminal com fallback seguro
    largura_terminal=$(_obter_colunas)

    largura_mensagem=${#mensagem}
    posicao_inicio=$(( (largura_terminal - largura_mensagem) / 2 ))

    # Garante posição mínima não negativa
    if [[ "$posicao_inicio" -lt 0 ]]; then
        posicao_inicio=0
    fi
# Imprimir espaços iniciais para centralizar
    printf "%${posicao_inicio}s" ""

    # Loop para imprimir cada letra com efeito de digitação
    for ((i=0; i<${#mensagem}; i++)); do
        printf "%s%s%s" "${cor}" "${mensagem:$i:1}" "${NORMAL}"
        sleep 0.05
    done
    printf "\n"
}

# Cria linha horizontal com caractere especificado
# Parametros: $1=caractere (opcional, padrao='-') $2=cor (opcional)
_linha() {
    local traco="${1:--}"
    local cor="${2:-}"
    local colunas

    colunas=$(_obter_colunas)

    if [[ "$colunas" -lt 10 ]]; then
        colunas=10
    fi

    printf "%s" "${cor}"
    printf '%*s\n' "$colunas" '' | tr ' ' "$traco"
    printf "%s" "${NORMAL}"
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

    colunas=$(_obter_colunas)

    printf -v espacos "%${largura}s" ""
    linhas=${espacos// /$traco}
    printf "%s" "${cor}"
    printf "%*s\n" $(((colunas + largura) / 2)) "$linhas"
    printf "%s" "${NORMAL}"
}


#---------- FUNcoES DE CONTROLE DE FLUXO ----------#

# Pausa a execucao por tempo especificado
# Parametros: $1=tempo_em_segundos
_aguardar() {
    local tempo="${1:-}"

    if [[ -z "$tempo" ]]; then
        _erro "Nenhum argumento passado para _aguardar.\n" >&2
        return 1
    fi

    if ! [[ "$tempo" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        _erro "Argumento inválido para _aguardar: %s\n" "$tempo" >&2
        return 1
    fi

    read -rt "$tempo" <> <(:) || :
}


# Aguarda pressionar qualquer tecla com timeout
_aguardar_tecla() {
    local mensagem="${1:-... Pressione qualquer tecla para continuar ...}"
    local timeout="${2:-${DEFAULT_PRESS_TIMEOUT}}"
    local colunas

    colunas=$(_obter_colunas)

    printf "%s" "${AMARELO}"
    printf "%*s\n" $(((36 + colunas) / 2)) "<< $mensagem >>"
    printf "%s" "${NORMAL}"
    read -rt "$timeout" || :
    tput sgr0 2>/dev/null || true
}

#---------- ALIASES PARA COMPATIBILIDADE ----------#
# Manter compatibilidade com código existente durante transição

# Aliases para funcoes renomeadas
_mensagec() { _exibir_mensagem_centralizada "$@"; }
_mensaged() { _exibir_mensagem_direita "$@"; }
_mensagex() { _exibir_mensagem_corrida "$@"; }

_opinvalida() {
    local mensagem="Opcao Invalida"
    local largura
    local tamanho_msg
    local espacos

    # Obter largura do terminal com fallback seguro
    largura=$(_obter_colunas)

    tamanho_msg=${#mensagem}
    espacos=$(( (largura - tamanho_msg) / 2 ))

    # Garantir que nao seja negativo
    if (( espacos < 0 )); then
        espacos=0
    fi

    _linha "-" "${AMARELO}"

    # Imprimir espacos iniciais para centralizar
    printf "%${espacos}s" ""

    # Loop para imprimir cada letra com efeito de digitacao
    for ((i=0; i<${#mensagem}; i++)); do
        printf "%s" "${VERMELHO}${mensagem:$i:1}${NORMAL}"
        _aguardar 0.05
    done
    printf "\n"
    _linha "-" "${AMARELO}"
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
    local timeout="${DEFAULT_READ_TIMEOUT:-60}"

    case "$padrao" in
        [Ss]) opcoes="[S/n]" ;;
        [Nn]) opcoes="[N/s]" ;;
        *) opcoes="[S/N]" ;;
    esac

    while (( tentativas < max_tentativas )); do
        if ! read -r -t "${timeout}" -p "${AMARELO}${mensagem} ${opcoes}: ${NORMAL}" resposta; then
            # Timeout ou erro de leitura — usar padrao
            _mensagec "${AMARELO}" "Entrada expirada. Usando padrao: ${padrao}"
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
                _linha "-" "${VERMELHO}"
                _erro "Resposta invalida. Use S ou N."
                _linha "-" "${VERMELHO}"
                ((tentativas++)) || true
                ;;
        esac
    done

    _erro "Maximo de tentativas excedido. Usando padrao: ${padrao}"
    case "${padrao,,}" in
        s|sim) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# FUNCOES DE PROGRESSO
# =============================================================================
# Formata tempo decorrido em segundos para exibicao
# Parametros: $1=elapsed seconds
# Retorna: string formatada (ex: "2m 30s" ou "45s")
_formatar_tempo() {
    local elapsed="$1"
    local min=$(( elapsed / 60 ))
    local seg=$(( elapsed % 60 ))
    local tempo_str=""
    (( min > 0 )) && tempo_str="${min}m "
    tempo_str+="${seg}s"
    printf '%s' "$tempo_str"
}

# Exibe barra de progresso visual enquanto processo esta em andamento
# Parametros:
#   $1 = PID do processo em background
#   $2 = mensagem opcional (padrao: "Processando")
# Retorna: codigo de saida do processo
_mostrar_progresso_backup() {
    local pid="${1:-}"
    local msg="${2:-Processando}"
    local elapsed=0
    local anim_pos=0
    local texto_base="Aguarde..."
    local texto_len=${#texto_base}
    local barra=""
    local barra_format=""
    local status_proc=0

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        _aviso "Aviso: PID nao informado ou processo ja terminado"
        return 0
    fi

    : "${VERDE:=}" "${VERMELHO:-}" "${CIANO:=}" "${NORMAL:=}"

    # Ocultar cursor se suportado
    printf "\033[?25l" 2>/dev/null || true

    # Forcar sync do output para evitar buffering
    exec 3>&1

    while kill -0 "$pid" 2>/dev/null; do
        elapsed=$((elapsed + 1))

        # Animacao: mostrar letras do texto base progressivamente e preencher com pontos
        anim_pos=$(( (elapsed - 1) % texto_len ))
        barra="${texto_base:0:anim_pos + 1}"
        local dots_needed=$((texto_len - ${#barra}))
        printf -v barra_format "%s%${dots_needed}s" "$barra" ""
        barra="${barra_format// /.}"

        # Formatar campos com tamanho fixo para que \r sobrescreva corretamente
        local msg_format tempo_format
        printf -v msg_format "%-25s" "$msg"
        printf -v tempo_format "%8s" "$(_formatar_tempo "$elapsed")"

        printf "\r\033[K%s[INFO]%s %s |%s| %s" \
            "${CIANO}" "${NORMAL}" "${msg_format}" "${VERDE}${barra}${NORMAL}" "${AMARELO}${tempo_format}"
        printf "%s" "" >&3

        sleep 1 2>/dev/null || sleep 1
    done

    # Coletar status de saida
    barra=" Concluido "
    wait "$pid" 2>/dev/null && status_proc=0 || status_proc=$?

    # Restaurar cursor
    printf "\033[?25h" 2>/dev/null || true

    # Formatar e exibir resultado final
    local msg_format tempo_format
    printf -v msg_format "%-25s" "$msg"
    printf -v tempo_format "%8s" "$(_formatar_tempo "$elapsed")"

    printf "\r\033[K%s[ok]%s %s |%s| %s concluido\n" \
        "${VERDE}" "${NORMAL}" "${msg_format}" "${VERDE}${barra}${NORMAL}" "${AMARELO}${tempo_format}"

    exec 3>&-

    return $status_proc
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
        _erro "Diretorio de log nao existe: %s\n" "$log_dir" >&2
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
        _erro "Falha ao escrever no log: %s\n" "$arquivo_log" >&2
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
        _erro "Programas nao encontrados"
        _aviso "Programas ausentes: ${missing[*]}"
        _aviso "Sugestao: ${install_cmd} ${missing[*]}"
        _aviso "Instale os programas ausentes e tente novamente."
        return 1
    fi
}

_enviabackup_para_receber() {
    local source_dir="${CFG_PORTALSAV}"
    local dest_dir="${DEFAULT_RECEBE_DIR}"
    local arquivo
    local arquivos_copiados=0
    local arquivos_erro=0

    # Validar diretórios de origem e destino
    if [[ ! -d "${source_dir}" ]]; then
        _aviso "Diretorio de origem nao existe: ${source_dir}"
        return 1
    fi

    if [[ ! -d "${dest_dir}" ]]; then
        _erro "Diretorio de destino nao existe: ${dest_dir}"
        return 2
    fi

    if [[ ! -w "${dest_dir}" ]]; then
        _erro "Sem permissao de escrita em: ${dest_dir}"
        return 3
    fi

    _linha
    _mensagec "${AMARELO}" "Processando arquivos de backup: ${source_dir} → ${dest_dir}"
    _linha

    # Iterar sobre arquivos .zip com tratamento seguro
    while IFS= read -r -d '' arquivo; do
        local nome_arquivo
        nome_arquivo="$(basename "${arquivo}")"

        # Verificar se o arquivo já existe no destino
        if [[ -e "${dest_dir}/${nome_arquivo}" ]]; then
            _aviso "Arquivo ja existe (sobrescrevendo): ${nome_arquivo}"
        fi

        # Tentar mover o arquivo
        if mv -f "${arquivo}" "${dest_dir}/" >> "${LOG_ATU}" 2>&1; then
            _ok "Arquivo movido: ${nome_arquivo}"
            ((arquivos_copiados++))
        else
            _erro "Erro ao mover: ${nome_arquivo}"
            ((arquivos_erro++))
        fi
    done < <(find "${source_dir}" -maxdepth 1 -type f -name "*.zip" -print0)

    # Resumo da operação
    _linha
    if (( arquivos_copiados == 0 && arquivos_erro == 0 )); then
        _aviso "Nenhum arquivo .zip encontrado em ${source_dir}"
    else
        _mensagec "${VERDE}" "Operacao concluida: ${arquivos_copiados} arquivo(s) movido(s)"
        if (( arquivos_erro > 0 )); then
            _erro "Atencao: ${arquivos_erro} arquivo(s) com erro"
        fi
    fi
    _linha

    # Retornar código apropriado
    return $((arquivos_erro > 0 ? 1 : 0))
}


# ---------- COMPATIBILIDADE SSH ----------
# Retorna opcao compativel para StrictHostKeyChecking.
# Usamos 'yes' porque servers antigos (RHEL 6, CentOS 6) nao suportam 'accept-new'.
# yes funciona em qualquer versao do SSH desde o OpenSSH 3.8.
# NUNCA escreva StrictHostKeyChecking=aceitar diretamente — chame esta funcao.
_ssh_accept_new() {
    printf 'yes'
}

#---------- FUNCOES DE CHAVES SSH ----------#
#===================================================================
# _configure_ssh_com_chaves - Gerencia criacao e envio de chaves SSH
# Complementa _configure_ssh_access adicionando autenticacao por chave
#===================================================================

# -------------------------------------------------------------------------
# Verifica dependencias
# -------------------------------------------------------------------------
_checar_dependencias() {
    SERVIDOR="${DEFAULT_IP_SERVER:-}"
    PORTA="${DEFAULT_SSH_PORTA:-}"
    USUARIO="${DEFAULT_SSH_USER:-}"
    CHAVE="${DEFAULT_CHAVE_SSH:-${HOME}/.ssh/id_rsa}"
    CHAVE_PUB="${DEFAULT_CHAVE_SSH_PUB:-${HOME}/.ssh/id_rsa.pub}"

    # Validacao das variaveis obrigatorias
    if [[ -z "${SERVIDOR}" ]]; then
        _erro "Variavel DEFAULT_IP_SERVER nao foi definida."
        return 1
    fi
    for cmd in ssh ssh-keygen ssh-copy-id; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            _erro "Comando '$cmd' nao encontrado. Instale o pacote openssh-client."
            return 1
        fi
    done
    _ok "Dependencias verificadas."
    _aviso "Verificando configuracao de chaves SSH..."
}

# -------------------------------------------------------------------------
# Garante que ~/.ssh existe com as permissoes corretas
# -------------------------------------------------------------------------
_preparar_diretorio_ssh() {
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod "${PERM_DIR_SECURE}" "$HOME/.ssh"
        _ok "Diretorio ~/.ssh criado."
    fi
}

# -------------------------------------------------------------------------
# Verifica se a chave ja existe; pergunta se quer criar caso nao exista
# -------------------------------------------------------------------------
_verificar_ou_criar_chave() {
    if [ -f "$CHAVE" ] && [ -f "$CHAVE_PUB" ]; then
        _ok "Chave SSH encontrada: $CHAVE"
        return 0
    fi

    _aviso "Chave SSH nao encontrada em $CHAVE"
    printf "\nDeseja criar uma nova chave SSH agora? [s/N] "
    read -r RESPOSTA

    case "$RESPOSTA" in
        [sS]|[sS][iI][mM])
            _msg "Gerando par de chaves RSA 4096 bits..."
            if ssh-keygen -t rsa -b 4096 -f "$CHAVE" -C "${USUARIO}@$(hostname)-$(date +%Y%m%d)"; then
                _ok "Chave criada com sucesso: $CHAVE"
            else
                _erro "Falha ao criar a chave SSH."
            fi
            ;;
        *)
            _aviso "Operacao cancelada. Sem chave SSH nao e possivel conectar sem senha."
            ;;
    esac
}

# -------------------------------------------------------------------------
# Envia a chave publica ao servidor principal
# -------------------------------------------------------------------------
_enviar_chave_para_servidor() {
    _msg "Enviando chave publica para ${USUARIO}@${SERVIDOR}:${PORTA}..."
    _aviso "Sera solicitada a senha do usuario '${USUARIO}' no servidor (ultima vez)."

    if ssh-copy-id -i "$CHAVE_PUB" -p "$PORTA" "${USUARIO}@${SERVIDOR}"; then
        _ok "Chave enviada com sucesso!"
        _ok "A partir de agora a conexao sera feita sem senha."
    else
        _erro "Falha ao enviar a chave. Verifique:"
        _msg "  - Se o servidor esta acessivel: ssh -p $PORTA ${USUARIO}@${SERVIDOR}"
        _msg "  - Se o usuario '${USUARIO}' existe no servidor"
        _msg "  - Se a senha informada esta correta"
        _aviso "Sera solicitada a senha do usuario '${USUARIO}' no servidor."
    fi
}

# -------------------------------------------------------------------------
# Testa a conexao sem senha
# -------------------------------------------------------------------------
_testar_conexao() {
    _msg "Testando conexao sem senha..."
    if ssh -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o "StrictHostKeyChecking=$(_ssh_accept_new)" \
        -i "$CHAVE" \
        -p "$PORTA" \
        "${USUARIO}@${SERVIDOR}" \
        "echo 'Conexao OK em: \$(hostname) - \$(date)'"; then
        _ok "Conexao sem senha funcionando perfeitamente!"
    else
        _erro "Conexao sem senha falhou. Verifique as permissoes no servidor:"
        _erro "  chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    fi
}


