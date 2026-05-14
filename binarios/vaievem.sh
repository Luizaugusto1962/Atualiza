#!/usr/bin/env bash
set -euo pipefail
#
# vaievem.sh - Modulo de Operacoes de Sincronizacao
# Responsavel por operacoes de download/upload via rsync, sftp e ssh
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 11/05/2026-001
#
#---------- CONFIGURACOES DE CONEXAO ----------#
#
# Variaveis globais esperadas
CFG_ACESSO_SSH="${CFG_ACESSO_SSH:-s}"          # Acesso via SSH (s/n)
ARQUIVO_ENVIAR="${ARQUIVO_ENVIAR:-}"           # Arquivo a ser enviado (pode conter wildcard)
DIRETORIO_ORIGEM="${DIRETORIO_ORIGEM:-.}"      # Diretorio de origem para upload
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-}"         # Destino remoto para upload (ex: /caminho/destino/)
DESTINO_BIBLIOTECA="${DESTINO_BIBLIOTECA:-}"   # Diretorio de destino da biblioteca no servidor
DESTINO_SERVER="${DESTINO_SERVER:-}"           # Diretorio do servidor de atualizacao
arquivos_encontrados=()                        # Array para armazenar arquivos encontrados para envio

#---------- FUNCOES AUXILIARES (BAIXO NIVEL) ----------#

# Download via SFTP com chave SSH configurada
# Parametros: $1=arquivo_remoto $2=destino_local(opcional, padrao=.)
_download_sftp_ssh() {
    local arquivo_remoto="$1"
    local destino_local="${2:-.}"
    local nome_arquivo="${arquivo_remoto##*/}"

    if [[ -z "$arquivo_remoto" ]]; then
        _log_erro "Erro: Arquivo remoto nao especificado para SFTP SSH"
        return 1
    fi

    _log "Iniciando download SFTP com chave SSH: ${arquivo_remoto}"

    # Captura stdout e stderr para inspecionar mensagens de erro do sftp
    local sftp_output
    sftp_output=$(sftp sav_servidor <<EOF 2>&1
get "${arquivo_remoto}" "${destino_local}"
quit
EOF
    )

    local padroes_erro=(
        "no such file"
        "not found"
        "no such directory"
        "does not exist"
        "error"
        "failed"
        "failure"
        "permission denied"
        "connection refused"
        "connection timed out"
        "host key verification failed"
        "authentication failed"
        "couldn't read"
        "couldn't open"
        "transfer failed"
        "abandoned"
    )

    local IFS='|'
    local regex_erro="${padroes_erro[*]}"

    if echo "$sftp_output" | grep -qiE "$regex_erro"; then
        _log_erro "Falha no download SFTP SSH: ${arquivo_remoto}"
        _log_erro "Saida sftp: ${sftp_output}"
        return 1
    fi
    # 3ª verificacao: confirma que o arquivo existe e nao esta vazio no destino
    local arquivo_destino="${destino_local%/}/${nome_arquivo}"
    if [[ ! -f "$arquivo_destino" || ! -s "$arquivo_destino" ]]; then
        _log_erro "Falha no download SFTP SSH: arquivo ausente apos transferencia: ${arquivo_destino}"
        return 1
    fi

    _log_sucesso "Download SFTP SSH concluido: ${arquivo_remoto}"
    return 0
}

# Download via SCP com chave SSH configurada
# Parametros: $1=arquivo_remoto $2=destino_local(opcional) $3=servidor $4=porta $5=usuario
_download_scp() {
    local arquivo_remoto="$1"
    local destino_local="${2:-.}"
    local servidor="${3:-$DEFAULT_IP_SERVER}"
    local porta="${4:-$DEFAULT_SSH_PORTA}"
    local rem_user="${5:-$DEFAULT_SSH_USER}"

    if [[ -z "$arquivo_remoto" ]]; then
        _log_erro "Erro: Arquivo remoto nao especificado para SCP"
        return 1
    fi

    if [[ ! -d "$destino_local" ]]; then
        _log_erro "Erro: Diretorio de destino nao existe: ${destino_local}"
        return 1
    fi

    _log "Iniciando download SCP: ${arquivo_remoto}"

    if scp -P "$porta" "${rem_user}@${servidor}:${arquivo_remoto}" "$destino_local"; then
        # Verificar se arquivo realmente existe e nao esta vazio
        local nome_arquivo="${arquivo_remoto##*/}"
        local arquivo_destino="${destino_local%/}/${nome_arquivo}"

        if [[ -f "$arquivo_destino" && -s "$arquivo_destino" ]]; then
            _log_sucesso "Download SCP concluido: ${arquivo_remoto}"
            return 0
        else
            _log_erro "SCP retornou sucesso mas arquivo ausente ou vazio: ${arquivo_destino}"
            return 1
        fi
    else
        _log_erro "Falha no download SCP: ${arquivo_remoto}"
        return 1
    fi
}

# Upload via RSYNC
# Parametros: $1=arquivo_local $2=CFG_BACKUP_PATH $3=servidor $4=porta $5=usuario
_upload_rsync() {
    local arquivo_local="$1"
    local CFG_BACKUP_PATH="$2"
    local servidor="${3:-$DEFAULT_IP_SERVER}"
    local porta="${4:-$DEFAULT_SSH_PORTA}"
    local rem_user="${5:-$DEFAULT_SSH_USER}"

    if [[ -z "$arquivo_local" || -z "$CFG_BACKUP_PATH" ]]; then
        _log_erro "Erro: Parametros obrigatorios nao informados para upload RSYNC"
        return 1
    fi

    if [[ ! -f "$arquivo_local" ]]; then
        _mensagec "${RED}" "Erro: Arquivo local nao encontrado: ${arquivo_local}"
        return 1
    fi

    _log "Iniciando upload RSYNC: ${arquivo_local}"

    local destino_completo="${rem_user}@${servidor}:${CFG_BACKUP_PATH}"

    if rsync -avzP -e "ssh -p ${porta}" "$arquivo_local" "$destino_completo"; then
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
    _log "Iniciando download da biblioteca: ${SAVATU:-}${VERSAO:-}"

    # Usar subshell para nao alterar o diretorio do chamador
    (
        cd "${DEFAULT_RECEBE_DIR:-}" || return 1

        if [[ "${CFG_ACESSO_SSH}" == "s" ]]; then
            local src="${DEFAULT_SSH_USER}@${DEFAULT_IP_SERVER}:${DESTINO_BIBLIOTECA}${SAVATU:-}${VERSAO:-}.zip"

            if sftp -P "$DEFAULT_SSH_PORTA" "${src}" "."; then
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
                _mensagec "${RED}" "Erro: Nenhum arquivo de atualizacao encontrado"
                return 1
            fi

            for arquivo in "${arquivos_update[@]}"; do
                local src="${DEFAULT_SSH_USER}@${DEFAULT_IP_SERVER}:${DESTINO_BIBLIOTECA}${arquivo}"

                if scp -P "$DEFAULT_SSH_PORTA" "${src}" "."; then
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
        printf "Erro ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }
    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        return 0
    fi

    _linha
    _mensagec "${YELLOW}" "Realizando sincronizacao dos arquivos..."

    # Usar subshell para nao alterar o diretorio do chamador
    (
        cd "${DEFAULT_RECEBE_DIR:-}" || return 1

        for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
            _linha
            _mensagec "${GREEN}" "Transferindo: $arquivo"
            _linha

            if [[ "${CFG_ACESSO_SSH}" == "s" ]]; then
                _mensagec "${YELLOW}" "Informe a senha para o usuario remoto:"

                if ! _download_sftp_ssh "${DESTINO_SERVER}${arquivo}" "."; then
                    _mensagec "${RED}" "Falha no download: $arquivo"
                    return 0
                fi
            else
                if ! _download_scp "${DESTINO_SERVER}${arquivo}" "."; then
                    _mensagec "${RED}" "Falha no download: $arquivo"
                    return 0
                fi
            fi

            _linha

            # Verificar se arquivo foi baixado
            if [[ ! -f "$arquivo" || ! -s "$arquivo" ]]; then
                _mensagec "${RED}" "ERRO: Falha ao baixar verificar se existe no servidor: $arquivo"
                _aguardar 0
                return 0 
            fi

            if ! "${DEFAULT_UNZIP:-unzip}" -t "$arquivo" >/dev/null 2>&1; then
                _mensagec "${RED}" "ERRO: Arquivo corrompido: $arquivo"
                rm -f "$arquivo"
                _aguardar 2
                return 0
            fi

            _mensagec "${GREEN}" "Download concluido: $arquivo"
        done
    )
}

#---------- FUNCOES DE UPLOAD/ENVIO (ALTO NIVEL) ----------#

# Enviar arquivo(s) via RSYNC. Pode lidar com arquivos unicos ou multiplos usando wildcard.
_enviar_arquivo_multi() {
    # Validar variaveis globais necessarias
    if [[ -z "$ARQUIVO_ENVIAR" ]]; then
        _mensagec "${RED}" "Erro: Nenhum arquivo especificado para envio"
        _aguardar 2
        return 0
    fi

    if [[ -z "${CFG_BACKUP_PATH:-}" ]]; then
        _mensagec "${RED}" "Erro: Destino remoto nao especificado"
        _aguardar 2
        return 0
    fi

    # Verificar se esta enviando multiplos arquivos ou apenas um
    if [[ "$ARQUIVO_ENVIAR" == *"*"* ]]; then
        # Enviar multiplos arquivos usando _upload_rsync
        local falhas_envio=0
        for arquivo_item in "${arquivos_encontrados[@]}"; do
            if ! _upload_rsync "$arquivo_item" "${CFG_BACKUP_PATH}"; then
                ((falhas_envio++)) || true
            fi
        done
        if (( falhas_envio == 0 )); then
            _mensagec "${YELLOW}" "Arquivo(s) enviado(s) para \"${CFG_BACKUP_PATH}\""
            _linha
            _aguardar 3
        else
            _mensagec "${RED}" "Erro no envio de ${falhas_envio} arquivo(s)"
            _press
        fi
    else
        # Enviar arquivo unico usando _upload_rsync
        if _upload_rsync "${DIRETORIO_ORIGEM}/${ARQUIVO_ENVIAR}" "${CFG_BACKUP_PATH}"; then
            _mensagec "${YELLOW}" "Arquivo enviado para \"${CFG_BACKUP_PATH}\""
            _linha
            _aguardar 3
        else
            _mensagec "${RED}" "Erro no envio do arquivo"
            _press
        fi
    fi
}
