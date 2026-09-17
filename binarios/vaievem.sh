#!/usr/bin/env bash
set -euo pipefail
#
# vaievem.sh - Modulo de Operacoes de Sincronizacao
# Responsavel por operacoes de download/upload via rsync, sftp e ssh
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# DEPENDENCIAS DE CARGA (principal.sh): este modulo e sourced ANTES de
# programas.sh (dono de ARQUIVOS_PROGRAMA; guard proprio nas funcoes que o
# usam). Requer utils.sh (_ssh_aceitar_novo, _log*), principal.sh
# (_criar_diretorio_seguro) e constantes.sh (DEFAULT_*).
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 18/09/2026
#

CHAVE="${DEFAULT_CHAVE_SSH:-}"

# =============================================================================
# VALIDACAO DE SEGURANCA (AGENTS.md: Validate and sanitize user input)
# =============================================================================
# Valida caminhos contra path traversal e injeção de caracteres especiais
_validar_caminho_seguro() {
    local caminho="$1"
    local regex_perigoso=$'[;|&$`<>"\']'

    if [[ -z "$caminho" || "$caminho" == *"/.."* || "$caminho" == ".."* || "$caminho" =~ $regex_perigoso ]]; then
        return 1
    fi
    return 0
}

# Verifica se autenticacao por chave SSH deve ser utilizada
# Retorna 0 (true) se chave deve ser usada, 1 (false) caso contrario
_usar_chave_ssh() {
    local acessochave="${CFG_CHAVE_SSH:-}"
    local chave="${CHAVE:-}"

    # Se a variavel chavessh (configuracao do .config) for "n",
    # pular o controle de acesso a chave e continuar pedindo senha
    if [[ "${acessochave,,}" == "n" ]]; then
        return 1
    fi

    if [[ "${acessochave,,}" != "s" ]]; then
        return 1
    fi

    if [[ -z "$chave" ]]; then
        _log_erro "CFG_CHAVE_SSH configurado como 's', mas DEFAULT_CHAVE_SSH nao definido"
        return 1
    fi

    if [[ ! -f "$chave" ]]; then
        _log_erro "Arquivo de chave SSH nao encontrado: ${chave}"
        return 1
    fi

    if [[ ! -r "$chave" ]]; then
        _log_erro "Arquivo de chave SSH sem permissao de leitura: ${chave}"
        return 1
    fi
    return 0
}


# Constrói o comando scp em um array nomeado, com opções de conexão e (opcional) chave SSH.
# Uso: _montar_cmd_scp <nome_array_ref> <porta> [timeout] [alive_interval] [alive_count]
#   Os tres ultimos defaultam para SSH_TIMEOUT/SSH_ALIVE_INTERVAL/SSH_ALIVE_COUNT.
# SEGURANCA: sem eval — os valores sao validados (porta/timeout/alive numericos)
# e publicados no array via printf -v + read -a (ambos Bash 4.0+; nameref
# exigiria 4.3+). Payloads com aspas/substituicao viram string literal, nunca
# argumentos extras do scp.
_montar_cmd_scp() {
    local _cmd_ref="$1"
    local porta="${2:-}"
    local timeout="${3:-${SSH_TIMEOUT}}"
    local alive_int="${4:-${SSH_ALIVE_INTERVAL}}"
    local alive_max="${5:-${SSH_ALIVE_COUNT}}"

    # Validar entradas que viram opcoes do scp: apenas digitos
    if ! [[ "$porta" =~ ^[0-9]+$ && -n "$porta" ]] ||
       ! [[ "$timeout" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_int" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_max" =~ ^[0-9]+$ ]]; then
        _erro "Parametros invalidos para _montar_cmd_scp (porta/timeout/alive devem ser numericos)"
        return 1
    fi

    # Cache da opcao StrictHostKeyChecking (popula global; ver _ssh_aceitar_novo)
    _ssh_aceitar_novo

    local -a _opcoes_base=(
        scp
        -P "$porta"
        -o "ConnectTimeout=${timeout}"
        -o "ServerAliveInterval=${alive_int}"
        -o "ServerAliveCountMax=${alive_max}"
        -o "StrictHostKeyChecking=${_SSH_ACEITAR_NOVO}"
    )

    if _usar_chave_ssh; then
        _opcoes_base+=(-i "$CHAVE" -o "BatchMode=yes")
    fi

    # Publicar no array do chamador via serializacao com separador nao
    # imprimivel (printf -v: compativel com Bash < 4.2). O ${var?} documenta
    # que o nome do array e intencionalmente dinamico (escopo do chamador).
    local _sep=$'\x1f'
    local _serializado
    printf -v _serializado "%s${_sep}" "${_opcoes_base[@]}"
    _serializado="${_serializado%"${_sep}"}"
    IFS="${_sep}" read -r -a "${_cmd_ref?}" <<<"${_serializado}"

    return 0
}

# Constrói as opções de conexão SSH em um array nomeado (base para rsync -e).
# Uso: _montar_cmd_ssh <nome_array_ref> <porta> [timeout] [alive_interval] [alive_count]
#   Os tres ultimos defaultam para SSH_TIMEOUT/SSH_ALIVE_INTERVAL/SSH_ALIVE_COUNT.
# SEGURANCA: sem eval — os valores sao validados (porta/timeout/alive numericos)
# e publicados no array via nameref (Bash 4.3+) ou serializacao IFS (4.0-4.2).
# Centraliza a montagem hoje duplicada em _enviar_rsync e _enviar_rsync_lote.
_montar_cmd_ssh() {
    local _cmd_ref="$1"
    local porta="${2:-}"
    local timeout="${3:-${SSH_TIMEOUT}}"
    local alive_int="${4:-${SSH_ALIVE_INTERVAL}}"
    local alive_max="${5:-${SSH_ALIVE_COUNT}}"

    # Validar entradas que viram opcoes do ssh: apenas digitos
    if ! [[ "$porta" =~ ^[0-9]+$ && -n "$porta" ]] ||
       ! [[ "$timeout" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_int" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_max" =~ ^[0-9]+$ ]]; then
        _erro "Parametros invalidos para _montar_cmd_ssh (porta/timeout/alive devem ser numericos)"
        _log_erro "Parametros invalidos para _montar_cmd_ssh (porta=${porta} timeout=${timeout} alive=${alive_int}/${alive_max})"
        return 1
    fi

    # Cache da opcao StrictHostKeyChecking (popula global; ver _ssh_aceitar_novo)
    _ssh_aceitar_novo

    local -a _opcoes_ssh=(
        ssh
        -p "$porta"
        -o "ConnectTimeout=${timeout}"
        -o "ServerAliveInterval=${alive_int}"
        -o "ServerAliveCountMax=${alive_max}"
        -o "StrictHostKeyChecking=${_SSH_ACEITAR_NOVO}"
    )

    if _usar_chave_ssh; then
        _opcoes_ssh+=(-i "$CHAVE" -o "BatchMode=yes")
    fi

    # Publicar no array do chamador (mesma estrategia do _montar_cmd_scp).
    if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )); then
        # Bash 4.3+: nameref — publica o array diretamente, sem serializacao.
        local -n _ssh_ref="${_cmd_ref?}"
        _ssh_ref=("${_opcoes_ssh[@]}")
    else
        local _sep=$'\x1f'
        local _serializado
        printf -v _serializado "%s${_sep}" "${_opcoes_ssh[@]}"
        _serializado="${_serializado%"${_sep}"}"
        IFS="${_sep}" read -r -a "${_cmd_ref?}" <<<"${_serializado}"
    fi

    return 0
}

# Junta um array de comando em uma unica string para o rsync -e (que exige
# string, nao array). Em Bash 4.4+ usa printf %q para proteger cada argumento
# (caminho de chave com espacos deixa de quebrar); em versoes antigas mantem
# o join simples anterior.
# SEGURANCA: sem eval/indirecao — recebe os elementos ja expandidos pelo
# chamador, que e o dono do array (evita manipulacao de nome de variavel).
# Uso: _juntar_comando <elemento...>
_juntar_comando() {
    local -a _partes=("$@")

    if (( ${#_partes[@]} == 0 )); then
        return 1
    fi

    local _cmd_junto=""
    if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
        printf -v _cmd_junto '%q ' "${_partes[@]}"
    else
        printf -v _cmd_junto '%s ' "${_partes[@]}"
    fi
    printf '%s' "${_cmd_junto% }"
}

#---------- FUNCOES AUXILIARES (BAIXO NIVEL) ----------#


# Download via SCP com chave SSH configurada
# Parametros: $1=arquivo_remoto $2=destino_local(opcional) $3=servidor $4=porta $5=usuario
_receber_scp() {
    local arquivo_remoto="${1:-}"
    local destino_local="${2:-.}"
    local servidor="${3:-$DEFAULT_IP_SERVER}"
    local porta="${4:-$DEFAULT_SSH_PORTA}"
    local usuario_remoto="${5:-$DEFAULT_SSH_USER}"

    [[ -z "$arquivo_remoto" ]] && {
        _log_erro "Arquivo remoto nao especificado para SCP"
        return 1
    }

    if ! _validar_caminho_seguro "$arquivo_remoto"; then
        _log_erro "Caminho remoto invalido: $arquivo_remoto"
        return 1
    fi

    if ! _validar_caminho_seguro "$destino_local"; then
        _log_erro "Destino local invalido: $destino_local"
        return 1
    fi

    if [[ ! -d "$destino_local" ]]; then
        _log_erro "Diretorio de destino nao existe: $destino_local"
        return 1
    fi

    _log "Iniciando download SCP: $arquivo_remoto"

    local -a cmd_scp=()
    _montar_cmd_scp cmd_scp "$porta" 30 15 3

    local origem="${usuario_remoto}@${servidor}:${arquivo_remoto}"

    if ! "${cmd_scp[@]}" "$origem" "$destino_local"; then
        _log_erro "Falha no download SCP: $arquivo_remoto"
        return 1
    fi

    local nome_arquivo="${arquivo_remoto##*/}"
    local arquivo_destino="${destino_local%/}/${nome_arquivo}"

    if [[ ! -f "$arquivo_destino" ]]; then
        _log_erro "Arquivo nao encontrado apos SCP: $arquivo_destino"
        return 1
    fi

    if [[ ! -s "$arquivo_destino" ]]; then
        _log_erro "Arquivo recebido vazio: $arquivo_destino"
        rm -f -- "$arquivo_destino"
        return 1
    fi

    _log_sucesso "Download SCP concluido: $arquivo_remoto"
    return 0
}


# Upload via RSYNC
# Parametros: $1=arquivo_local $2=destino_remoto(caminho) $3=servidor $4=porta $5=usuario
# NOTA: $2 sobrescreve CFG_BACKUP_PATH para uso nesta chamada. Se omitido, usa CFG_BACKUP_PATH global.
_enviar_rsync() {
    local arquivo_local="${1:-}"
    local destino_remoto="${2:-${CFG_BACKUP_PATH:-}}"

    if [[ -z "$arquivo_local" || -z "$destino_remoto" ]]; then
        _log_erro "Parametros obrigatorios nao informados para upload RSYNC"
        return 1
    fi

    if [[ ! -f "$arquivo_local" ]]; then
        _log_erro "Arquivo local nao encontrado: ${arquivo_local}"
        return 1
    fi

    # SEGURANCA: Validar destino remoto contra injecao e traversal (interpretado pelo shell remoto)
    if ! _validar_caminho_seguro "$destino_remoto"; then
        _log_erro "Destino remoto invalido ou malicioso: ${destino_remoto}"
        return 1
    fi

    local servidor="${3:-$DEFAULT_IP_SERVER}"
    local porta="${4:-$DEFAULT_SSH_PORTA}"
    local usuario_remoto="${5:-$DEFAULT_SSH_USER}"
    _log "Iniciando upload RSYNC: ${arquivo_local}"
    local destino_completo="${usuario_remoto}@${servidor}:${destino_remoto}"

    # SEGURANCA: Construir opções de forma segura usando arrays
    # -rtzP (em vez de -a): nao preserva permissoes/dono/grupo, pois alguns mounts de clientes
    # (ex: SMB) rejeitam chmod com "Operation not permitted"
    local base_rsync=("rsync" "-rtzP")
    local -a ssh_cmd_parts=()
    if ! _montar_cmd_ssh ssh_cmd_parts "$porta"; then
        _log_erro "Falha ao montar opcoes SSH para upload RSYNC"
        return 1
    fi
    local cmd_ssh
    cmd_ssh="$(_juntar_comando "${ssh_cmd_parts[@]}")"

    # Executa o upload (única chamada)
    if "${base_rsync[@]}" -e "${cmd_ssh}" "$arquivo_local" "$destino_completo"; then
        _log_sucesso "Upload RSYNC concluido: ${arquivo_local}"
         return 0
    else
        _log_erro "Falha no upload RSYNC: ${arquivo_local}"
        return 1
    fi
}


# Upload em lote via RSYNC (uma unica conexao SSH para varios arquivos)
# Parametros: $1=destino_remoto(caminho) $2...=arquivos_locais
_enviar_rsync_lote() {
    local destino_remoto="${1:-}"
    shift
    local -a arquivos_locais=("$@")

    if [[ -z "$destino_remoto" || ${#arquivos_locais[@]} -eq 0 ]]; then
        _log_erro "Parametros obrigatorios nao informados para upload RSYNC em lote"
        return 1
    fi

    for arquivo_local in "${arquivos_locais[@]}"; do
        if [[ ! -f "$arquivo_local" ]]; then
            _log_erro "Arquivo local nao encontrado: ${arquivo_local}"
            return 1
        fi
    done

    # SEGURANCA: Validar destino remoto contra injecao e traversal (interpretado pelo shell remoto)
    if ! _validar_caminho_seguro "$destino_remoto"; then
        _log_erro "Destino remoto invalido ou malicioso: ${destino_remoto}"
        return 1
    fi

    local servidor="$DEFAULT_IP_SERVER"
    local porta="$DEFAULT_SSH_PORTA"
    local usuario_remoto="$DEFAULT_SSH_USER"
    _log "Iniciando upload RSYNC em lote: ${#arquivos_locais[@]} arquivo(s)"
    local destino_completo="${usuario_remoto}@${servidor}:${destino_remoto}"

    # SEGURANCA: Construir opções de forma segura usando arrays
    # -rtzP (em vez de -a): nao preserva permissoes/dono/grupo, pois alguns mounts de clientes
    # (ex: SMB) rejeitam chmod com "Operation not permitted"
    local base_rsync=("rsync" "-rtzP")
    local -a ssh_cmd_parts=()
    if ! _montar_cmd_ssh ssh_cmd_parts "$porta"; then
        _log_erro "Falha ao montar opcoes SSH para upload RSYNC"
        return 1
    fi
    local cmd_ssh
    cmd_ssh="$(_juntar_comando "${ssh_cmd_parts[@]}")"

    # Executa o upload de todos os arquivos em uma unica chamada (1 conexao SSH)
    if "${base_rsync[@]}" -e "${cmd_ssh}" "${arquivos_locais[@]}" "$destino_completo"; then
        _log_sucesso "Upload RSYNC em lote concluido: ${#arquivos_locais[@]} arquivo(s)"
        return 0
    else
        _log_erro "Falha no upload RSYNC em lote"
        return 1
    fi
}


#---------- FUNCOES DE DOWNLOAD (ALTO NIVEL) ----------#
# Download da biblioteca via SFTP/SCP (funcao principal)
_baixar_biblioteca_sincroniza() {

    local servidor="${1:-$DEFAULT_IP_SERVER}"
    local porta="${2:-$DEFAULT_SSH_PORTA}"
    local usuario_remoto="${3:-$DEFAULT_SSH_USER}"

    _log "Iniciando download da biblioteca: ${SAVATU:-}${VERSAO:-}"

    # SEGURANCA: Validar diretorio de recebimento
    if ! _validar_caminho_seguro "${CFG_PORTALSAV:-}"; then
        _log_erro "Erro: Diretorio de recebimento invalido."
        return 1
    fi

    # Garantir que o diretorio de recebimento exista (substitui o pushd:
    # nao ha mais mudanca de cwd, os downloads usam destino absoluto).
    if ! _criar_diretorio_seguro "${CFG_PORTALSAV:-}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _log_erro "Erro: Nao foi possivel acessar/criar diretorio: ${CFG_PORTALSAV:-}"
        return 1
    fi

    if _usar_chave_ssh; then
        local arquivo_biblioteca="${DESTINO_BIBLIOTECA}${SAVATU:-}${VERSAO:-}.zip"

        # SEGURANCA: Validar caminho construido
        if ! _validar_caminho_seguro "$arquivo_biblioteca"; then
            _log_erro "Erro: Caminho da biblioteca invalido."
            return 1
        fi
        local -a cmd_scp_lib=()
        _montar_cmd_scp cmd_scp_lib "$porta"
        local origem="${usuario_remoto}@${servidor}:${arquivo_biblioteca}"

        if "${cmd_scp_lib[@]}" "$origem" "${CFG_PORTALSAV:-}/"; then
            _log_sucesso "Download da biblioteca concluido: ${SAVATU:-}${VERSAO:-}.zip"
            return 0
        else
            _log_erro "Falha no download da biblioteca: ${SAVATU:-}${VERSAO:-}.zip"
            return 1
        fi
    else
        _definir_variaveis_biblioteca
        local arquivos_update
        read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"
        if [[ ${#arquivos_update[@]} -eq 0 ]]; then
            _erro "Nenhum arquivo de atualizacao encontrado"
            return 1
        fi
        # Montar origens remotas em uma unica conexao SCP (lote)
        # Cada origem deve ser um argumento separado "user@host:caminho"
        # (concatenar tudo em um unico token quebra o SCP moderno/SFTP:
        #  "protocol error: filename does not match request")
        local -a origens=()
        for arquivo in "${arquivos_update[@]}"; do
            # SEGURANCA: Validar cada nome de arquivo antes do uso
            if ! _validar_caminho_seguro "$arquivo"; then
                _log_erro "Erro: Nome de arquivo de atualizacao invalido ou malicioso: ${arquivo}"
                return 1
            fi
            if ! _validar_caminho_seguro "${DESTINO_BIBLIOTECA}${arquivo}"; then
                _log_erro "Erro: Caminho de atualizacao invalido ou malicioso: ${DESTINO_BIBLIOTECA}${arquivo}"
                return 1
            fi
            origens+=("${usuario_remoto}@${servidor}:${DESTINO_BIBLIOTECA}${arquivo}")
        done

        local -a cmd_scp=()
        _montar_cmd_scp cmd_scp "$porta"

        if "${cmd_scp[@]}" "${origens[@]}" "${CFG_PORTALSAV:-}/"; then
            _log_sucesso "Download em lote concluido: ${#arquivos_update[@]} arquivo(s)"
            return 0
        else
            _log_erro "Falha no download em lote dos arquivos de atualizacao"
            return 1
        fi
    fi
}

# Baixar programas via SFTP/SCP (download em lote: 1 conexao SCP para N arquivos)
_baixar_programas_vaievem() {
    local caminho="${1:-${CFG_PORTALSAV}}"

    # SEGURANCA: validar o diretorio de recebimento ANTES de cria-lo/usar
    if ! _validar_caminho_seguro "${caminho:-}"; then
        _erro "Diretorio de recebimento invalido: ${caminho}"
        return 1
    fi

    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }

    # Guard set -u: vaievem.sh e carregado antes de programas.sh (onde o array
    # e declarado). Em runtime o array ja existe, mas o guard protege chamadas
    # fora do bootstrap completo (ex: testes isolados de modulo).
    if [[ -z "${ARQUIVOS_PROGRAMA+x}" ]]; then
        return 0
    fi

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        return 0
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Realizando sincronizacao dos arquivos..."

    local servidor="${DEFAULT_IP_SERVER}"
    local porta="${DEFAULT_SSH_PORTA}"
    local usuario_remoto="${DEFAULT_SSH_USER}"

    # Montar origens remotas em uma unica conexao SCP (lote)
    local -a origens=()
    local -a nomes_arquivos=()
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        # SEGURANCA: Validar cada nome antes do uso
        if ! _validar_caminho_seguro "$arquivo"; then
            _log_erro "Nome de arquivo de atualizacao invalido ou malicioso: ${arquivo}"
            return 1
        fi
        if ! _validar_caminho_seguro "${DESTINO_SERVER}${arquivo}"; then
            _log_erro "Caminho de atualizacao invalido ou malicioso: ${DESTINO_SERVER}${arquivo}"
            return 1
        fi
        _linha
        _exibir_mensagem_centralizada "${VERDE}" "Transferindo: $arquivo"
        origens+=("${usuario_remoto}@${servidor}:${DESTINO_SERVER}${arquivo}")
        nomes_arquivos+=("$arquivo")
    done

    local -a cmd_scp=()
    _montar_cmd_scp cmd_scp "$porta"

    if ! "${cmd_scp[@]}" "${origens[@]}" "${caminho}/"; then
        _log_erro "Falha no download em lote dos programas"
        return 1
    fi

    # Integridade de cada zip recebido (existe no destino absoluto ${caminho}/)
    local arquivo_destino
    for arquivo in "${nomes_arquivos[@]}"; do
        arquivo_destino="${caminho%/}/${arquivo}"
        if [[ ! -f "$arquivo_destino" ]]; then
            _log_erro "Arquivo nao encontrado apos download: $arquivo"
            return 1
        fi
        if [[ ! -s "$arquivo_destino" ]]; then
            _log_erro "Arquivo recebido vazio: $arquivo"
            # SEGURANCA: Usar '--' para prevenir injeção de opções no rm
            rm -f -- "$arquivo_destino"
            _aguardar 2
            return 1
        fi
        _linha
        if ! "${DEFAULT_UNZIP:-unzip}" -t "$arquivo_destino" >/dev/null 2>&1; then
            _erro "Arquivo corrompido: $arquivo"
            # SEGURANCA: Usar '--' para prevenir injeção de opções no rm
            rm -f -- "$arquivo_destino"
            _aguardar 2
            return 1
        fi
        _exibir_mensagem_centralizada "${VERDE}" "Download concluido: $arquivo"
    done

    return 0
}

#---------- FUNCOES DE UPLOAD/ENVIO (ALTO NIVEL) ----------#

# Enviar arquivo(s) via RSYNC. Pode lidar com arquivos unicos ou multiplos usando wildcard.
# Uso: _enviar_arquivo_multi <diretorio_origem> <arquivo|padrao> [destino_remoto]
_enviar_arquivo_multi() {
    local diretorio_origem="${1:-}"
    local arquivo_enviar="${2:-}"
    local destino_remoto="${3:-${CFG_BACKUP_PATH:-}}"

    if [[ -z "$arquivo_enviar" ]]; then
        _erro "Nenhum arquivo especificado para envio"
        _aguardar 2
        return 1
    fi

    if [[ -z "$destino_remoto" ]]; then
        _erro "Destino remoto nao especificado"
        _aguardar 2
        return 1
    fi

    # Validar diretorio de origem para envio de arquivo unico
    if [[ "$arquivo_enviar" != *"*"* && -z "$diretorio_origem" ]]; then
        _erro "Diretorio de origem nao definido para envio de arquivo unico"
        _aguardar 2
        return 1
    fi

    # SEGURANCA: Validar caminhos contra traversal e injeção
    if ! _validar_caminho_seguro "${diretorio_origem:-.}" || ! _validar_caminho_seguro "${destino_remoto}"; then
        _erro "Caminhos contem caracteres invalidos ou tentativas de traversal."
        _aguardar 2
        return 1
    fi

    # Verificar se esta enviando multiplos arquivos ou apenas um
    if [[ "$arquivo_enviar" == *"*"* ]]; then
        # Localizar arquivos que correspondem ao padrao
        local -a arquivos_encontrados=()
        while IFS= read -r -d '' arquivo_item; do
            arquivos_encontrados+=("$arquivo_item")
        done < <(find "${diretorio_origem:-.}" -maxdepth 1 -type f -name "${arquivo_enviar}" -print0)

        if (( ${#arquivos_encontrados[@]} == 0 )); then
            _erro "Nenhum arquivo encontrado para envio multiplo"
            _aguardar 2
            return 1
        fi

        # Enviar multiplos arquivos em uma unica conexao SSH (lote)
        if _enviar_rsync_lote "${destino_remoto}" "${arquivos_encontrados[@]}"; then
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo(s) enviado(s) para \"${destino_remoto}\""
            _linha
            _aguardar 3
            return 0
        fi
    else
        # Enviar arquivo unico usando _enviar_rsync
        if _enviar_rsync "${diretorio_origem}/${arquivo_enviar}" "${destino_remoto}"; then
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo enviado para \"${destino_remoto}\""
            _linha
            _aguardar 3
            return 0
        fi
    fi

    # Fluxo de erro comum (unico e multiplo)
    _erro "Falha no envio de arquivo(s)"
    _aguardar_tecla
    return 1
}
