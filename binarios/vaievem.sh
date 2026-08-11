#!/usr/bin/env bash
set -euo pipefail
#
# vaievem.sh - Modulo de Operacoes de Sincronizacao
# Responsavel por operacoes de download/upload via rsync, sftp e ssh
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 11/08/2026-01
#

CHAVE="${DEFAULT_CHAVE_SSH:-}"

# =============================================================================
# VALIDACAO DE SEGURANCA (AGENTS.md: Validate and sanitize user input)
# =============================================================================
# Valida caminhos contra path traversal e injeção de caracteres especiais
_validar_caminho_seguro() {
    local caminho="$1"
    local regex_perigoso=$'[;|&$`<>"\']'

    if [[ -z "$caminho" || "$caminho" == *"/.."* || "$caminho" =~ $regex_perigoso ]]; then
        return 1
    fi
    return 0
}

# Verifica se autenticacao por chave SSH deve ser utilizada
# Retorna 0 (true) se chave deve ser usada, 1 (false) caso contrario
_usar_chave_ssh() {
    local acessochave="${CFG_CHAVE_SSH:-}"
    local chave="${CHAVE:-}"

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

# Adiciona opcoes SSH de chave a um array de opcoes
# Uso: _adicionar_opcoes_chave _array_ref
_adicionar_opcoes_chave() {
    local -n _opts_ref=$1
    _opts_ref+=("-i" "$CHAVE" "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)")
}

#---------- FUNCOES AUXILIARES (BAIXO NIVEL) ----------#

# Download via SSH com chave configurada (usa SCP para melhor controle de timeout)
# Parametros: $1=arquivo_remoto $2=destino_local(opcional)
_receber_scp2() {
    local arquivo_remoto="${1:-}"
    if [[ -z "$arquivo_remoto" ]]; then
        _log_erro "Arquivo remoto nao especificado para download SSH"
        return 1
    fi

    # SEGURANCA: Validar caminho remoto contra injeção e traversal
    if ! _validar_caminho_seguro "$arquivo_remoto"; then
        _log_erro "Caminho remoto invalido ou malicioso: ${arquivo_remoto}"
        return 1
    fi

    local destino_local="${2:-.}"

    # SEGURANCA: Validar caminho de destino
    if ! _validar_caminho_seguro "$destino_local"; then
        _log_erro "Caminho de destino invalido ou malicioso: ${destino_local}"
        return 1
    fi

    local nome_arquivo="${arquivo_remoto##*/}"
    _log "Iniciando download SSH com chave: ${arquivo_remoto}"

    local servidor_ssh="${CFG_SSH_HOST:-${DEFAULT_IP_SERVER}}"
    local usuario_ssh="${DEFAULT_SSH_USER:-}"
    local porta_ssh="${DEFAULT_SSH_PORTA:-}"

    # Usar SCP em vez de SFTP para melhor controle de timeout
    local -a cmd_scp=(
        scp
        -P "$porta_ssh"
        -o "ConnectTimeout=${SSH_TIMEOUT}"
        -o "ServerAliveInterval=${SSH_ALIVE_INTERVAL}"
        -o "ServerAliveCountMax=${SSH_ALIVE_COUNT}"
        -o "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
    )

    if _usar_chave_ssh; then
        cmd_scp+=(-i "$CHAVE" -o "BatchMode=yes")
    fi

    local origem="${usuario_ssh}@${servidor_ssh}:${arquivo_remoto}"

    if ! "${cmd_scp[@]}" "$origem" "$destino_local"; then
        _log_erro "Falha no download SSH: ${arquivo_remoto}"
        return 1
    fi

    # Verificar se arquivo foi transferido
    if [[ ! -f "${destino_local}/${nome_arquivo}" ]]; then
        _log_erro "Falha no download SSH: arquivo ausente apos transferencia: ${destino_local}/${nome_arquivo}"
        return 1
    fi

    _log "Download SSH concluido: ${arquivo_remoto}"
    return 0
}

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

    local -a cmd_scp=(
        scp
        -P "$porta"
        -o ConnectTimeout=30
        -o ServerAliveInterval=15
        -o ServerAliveCountMax=3
        -o "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
    )

    if _usar_chave_ssh; then
        cmd_scp+=(
            -i "$CHAVE"
            -o BatchMode=yes
            -o "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
        )
    fi

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
        _erro "Arquivo local nao encontrado: ${arquivo_local}"
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
    local -a ssh_cmd_parts=("ssh" "-p" "${porta}" "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)")

    if _usar_chave_ssh; then
        ssh_cmd_parts+=("-i" "${CHAVE}" "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)")
    fi

    local cmd_ssh
    printf -v cmd_ssh '%s ' "${ssh_cmd_parts[@]}"
    cmd_ssh="${cmd_ssh% }"

    # Executa o upload (única chamada)
    if "${base_rsync[@]}" -e "${cmd_ssh}" "$arquivo_local" "$destino_completo"; then
        _log_sucesso "Upload RSYNC concluido: ${arquivo_local}"
         return 0
    else
        _log_erro "Falha no upload RSYNC: ${arquivo_local}"
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
    (
        cd "${DEFAULT_RECEBE_DIR:-}" || return 1

        # SEGURANCA: Validar diretorio de recebimento
        if ! _validar_caminho_seguro "${DEFAULT_RECEBE_DIR:-}"; then
            _log_erro "Erro: Diretorio de recebimento invalido."
            return 1
        fi

        if _usar_chave_ssh; then
            local arquivo_biblioteca="${DESTINO_BIBLIOTECA}${SAVATU:-}${VERSAO:-}.zip"

            # SEGURANCA: Validar caminho construído
            if ! _validar_caminho_seguro "$arquivo_biblioteca"; then
                _log_erro "Erro: Caminho da biblioteca invalido."
                return 1
            fi
            local cmd_scp_lib=(
                "scp"
                "-P" "$porta"
                "-o" "ConnectTimeout=${SSH_TIMEOUT}"
                "-o" "ServerAliveInterval=${SSH_ALIVE_INTERVAL}"
                "-o" "ServerAliveCountMax=${SSH_ALIVE_COUNT}"
                "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
            )
            if _usar_chave_ssh; then
                cmd_scp_lib+=("-i" "$CHAVE" "-o" "BatchMode=yes")
            fi
            local origem="${usuario_remoto}@${servidor}:${arquivo_biblioteca}"

            if "${cmd_scp_lib[@]}" "$origem" "."; then
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
            for arquivo in "${arquivos_update[@]}"; do
                # SEGURANCA: Validar cada nome de arquivo antes do uso
                if ! _validar_caminho_seguro "$arquivo"; then
                    _log_erro "Erro: Nome de arquivo de atualizacao invalido ou malicioso: ${arquivo}"
                    return 1
                fi

                local origem="${usuario_remoto}@${servidor}:${DESTINO_BIBLIOTECA}${arquivo}"
                local cmd_scp=(
                    "scp"
                    "-P" "$porta"
                    "-o" "ConnectTimeout=${SSH_TIMEOUT}"
                    "-o" "ServerAliveInterval=${SSH_ALIVE_INTERVAL}"
                    "-o" "ServerAliveCountMax=${SSH_ALIVE_COUNT}"
                    "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
                )

                if _usar_chave_ssh; then
                    cmd_scp+=("-i" "$CHAVE" "-o" "StrictHostKeyChecking=$(_ssh_aceitar_novo)" "-o" "BatchMode=yes")
                fi

                if "${cmd_scp[@]}" "$origem" "."; then
                    _log_sucesso "Download concluido: ${arquivo}"
                else
                    _log_erro "Falha no download: ${arquivo}"
                    return 1
                fi
            done
            return 0
        fi
    )
}

# Baixar programas via SFTP/SCP
_baixar_programas_vaievem() {
    local caminho="${1:-${DEFAULT_RECEBE_DIR}}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        return 0
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Realizando sincronizacao dos arquivos..."
    (
        cd "${DEFAULT_RECEBE_DIR:-}" || return 1
        for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
            _linha
            _exibir_mensagem_centralizada "${VERDE}" "Transferindo: $arquivo"
            _linha

            if _usar_chave_ssh; then
                if ! _receber_scp "${DESTINO_SERVER}${arquivo}" "."; then
                    _erro "Falha no download: $arquivo"
                    return 1
                fi
            fi

            _linha
            # Verificar se arquivo foi baixado
            if [[ ! -f "$arquivo" || ! -s "$arquivo" ]]; then
                _erro "Falha ao baixar verificar se existe no servidor: $arquivo"
                _aguardar 0
                return 1
            fi

            if ! "${DEFAULT_UNZIP:-unzip}" -t "$arquivo" >/dev/null 2>&1; then
                _erro "Arquivo corrompido: $arquivo"
                # SEGURANCA: Usar '--' para prevenir injeção de opções no rm
                rm -f "$arquivo"
                _aguardar 2
                return 1
            fi

            _exibir_mensagem_centralizada "${VERDE}" "Download concluido: $arquivo"
        done
    )
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
        shopt -s nullglob
        local -a arquivos_encontrados=()
        while IFS= read -r -d '' arquivo_item; do
            arquivos_encontrados+=("$arquivo_item")
        done < <(find "${diretorio_origem}" -maxdepth 1 -type f -name "${arquivo_enviar}" -print0)
        shopt -u nullglob

        if (( ${#arquivos_encontrados[@]} == 0 )); then
            _erro "Nenhum arquivo encontrado para envio multiplo"
            _aguardar 2
            return 1
        fi

        # Enviar multiplos arquivos usando _enviar_rsync
        local falhas_envio=0
        for arquivo_item in "${arquivos_encontrados[@]}"; do
            if ! _enviar_rsync "$arquivo_item" "${destino_remoto}"; then
                ((falhas_envio++)) || true
            fi
        done

        if (( falhas_envio == 0 )); then
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo(s) enviado(s) para \"${destino_remoto}\""
            _linha
            _aguardar 3
        else
            _erro "Falha no envio de ${falhas_envio} arquivo(s)"
            _aguardar_tecla
        fi
    else
        # Enviar arquivo unico usando _enviar_rsync
        if _enviar_rsync "${diretorio_origem}/${arquivo_enviar}" "${destino_remoto}"; then
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo enviado para \"${destino_remoto}\""
            _linha
            _aguardar 3
        else
            _erro "Falha no envio do arquivo"
            _aguardar_tecla
        fi
    fi
}