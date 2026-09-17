#!/usr/bin/env bash
set -euo pipefail
#
# biblioteca.sh - Modulo de Gestao de Biblioteca
# Responsavel pela atualizacao das bibliotecas do sistema (Transpc, Savatu)
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 18/09/2026
#
declare pids=()                     # Array global para rastrear PIDs de background
declare ATUALIZA1="" ATUALIZA2="" ATUALIZA3=""      # Variaveis de artefatos

# Funcao de cleanup em caso de interrupcao
_limpar_interrupcao() {
    local sinal="$1"
    _log "Interrupcao detectada (sinal: $sinal). Limpando processos..."

    # Matar todos os PIDs pendentes (guarda: array pode estar vazio em
    # Bash 4.0-4.3, onde "${arr[@]}" com set -e abortaria o proprio trap)
    if (( ${#pids[@]} > 0 )); then
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                _log "Processo PID $pid interrompido"
            fi
        done
    fi
    pids=()  # Limpar array

    # Limpeza de temporarios por caminhos absolutos: nao altera o cwd ativo.
    if [[ -n "${VERSAO:-}" ]]; then
        while IFS= read -r -d '' arquivo_temp; do
            rm -f -- "$arquivo_temp"
            _log "Arquivo temporario removido: $arquivo_temp"
        done < <("${DEFAULT_FIND}" "${SCRIPT_DIR}" -maxdepth 1 -type f \( -name "*${VERSAO}.zip" -o -name "*${VERSAO}.tar" -o -name "*${VERSAO}.tar.gz" \) -print0)
    fi

    # Verificar se backup parcial existe e sugerir rollback, sem alterar nullglob.
    local -a backups_parciais=()
    while IFS= read -r -d '' arquivo_backup; do
        backups_parciais+=("$arquivo_backup")
    done < <("${DEFAULT_FIND}" "${DEFAULT_BIBLIOTECA_DIR}" -maxdepth 1 -type f \( -name "backups_biblioteca_antes_da_versao-*.zip" -o -name "backups_biblioteca_antes_da_versao-*.tar.gz" \) -print0)
    if (( ${#backups_parciais[@]} > 0 )); then
        _aviso "Backup parcial encontrado. Considere reverter manualmente com '_reverter_biblioteca'"
    fi

    _log "Cleanup concluido. Saida forcada."
    _aguardar_tecla  # Pausa para o usuario ver a mensagem
    return 1
}

#---------- FUNCOES PRINCIPAIS DE ATUALIZACAO ----------#

# Atualizacao do Transpc
_atualizar_transpc() {
    clear
    _solicitar_versao_biblioteca

    if [[ -z "${VERSAO}" ]]; then
        return 0
    fi

    if ! _validar_versao_biblioteca "${VERSAO}"; then
        _erro "Versao invalida. Informe somente numeros."
        _aguardar_tecla
        return 1
    fi

    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            _linha
            _exibir_mensagem_centralizada "${AMARELO}" "Parametro de biblioteca do servidor OFF ativo"
            _linha
            _aguardar_tecla
            return 0
        fi
        _linha
        _exibir_mensagem_centralizada "${AMARELO}" "Informe a senha para o usuario remoto:"
        _linha
        # Verificar espaco em disco
        if ! _verificar_espaco_disco "$E_EXEC"; then
            _erro "Espaco em disco insuficiente em $E_EXEC"
            _aguardar 3
            return 1
        fi
    fi
    if ! _baixar_biblioteca_sincroniza; then
        _erro "Falha ao baixar biblioteca do servidor."
        _aviso "Verifique se a versao ${VERSAO} esta disponivel no servidor."
        _linha "-" "${VERMELHO}"
        _aguardar_tecla
        return 1
    fi
    if ! _salvar_atualizacao_biblioteca; then
        _erro "Falha ao salvar atualizacao da biblioteca."
        _aguardar_tecla
        return 1
    fi
}

# Atualizacao offline da biblioteca
_atualizar_biblioteca_offline() {
    clear
       _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Diretorio de download: ${NORMAL}${CFG_PORTALSAV}"
     _solicitar_versao_biblioteca

    if [[ -z "${VERSAO}" ]]; then
        return 0
    fi

    if ! _validar_versao_biblioteca "${VERSAO}"; then
        _erro "Versao invalida. Informe somente numeros."
        _aguardar_tecla
        return 1
    fi

    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            if ! _processar_biblioteca_offline; then
                _erro "Falha ao processar biblioteca offline."
                _aviso "Verifique se os arquivos estao no diretorio: ${CFG_PORTALSAV}"
                _linha "-" "${VERMELHO}"
                _aguardar_tecla
                return 1
            fi
        else
            if ! _salvar_atualizacao_biblioteca; then
                _erro "Falha ao salvar atualizacao da biblioteca."
                _aguardar_tecla
                return 1
            fi
        fi
    fi
}

# Reverter biblioteca para versao anterior
_reverter_biblioteca() {
    _meio_da_tela
    _exibir_mensagem_centralizada "${VERMELHO}" "Informe a versao da biblioteca para reverter:"
    _linha

    local versao_reverter
    read -rp "${AMARELO}Versao a reverter: ${NORMAL}" versao_reverter
    _linha

    if [[ -z "${versao_reverter}" ]]; then
        _erro "Versao nao informada"
        _linha
        _aguardar_tecla
        return 1
    fi

    if ! _validar_versao_biblioteca "${versao_reverter}"; then
        _erro "Versao invalida. Informe somente numeros."
        _linha
        _aguardar_tecla
        return 1
    fi

    # Tentar encontrar o backup tanto em .tar.gz quanto em .zip (para retrocompatibilidade)
    local arquivo_backup="${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${versao_reverter}.tar.gz"

    if [[ ! -r "${arquivo_backup}" ]]; then
        arquivo_backup="${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${versao_reverter}.zip"
    fi

    if [[ ! -r "${arquivo_backup}" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Backup da biblioteca nao encontrado: ${NORMAL}${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${versao_reverter}.tar.gz"
        _linha
        _aguardar_tecla
        return 1
    fi

    # Perguntar se e reversao completa ou especifica
    if _confirmar "Reverter todos os programas da biblioteca?" "N"; then
        _reverter_biblioteca_completa "${arquivo_backup}"
    else
        _reverter_programa_especifico_biblioteca "${arquivo_backup}"
    fi
}

#---------- FUNCOES DE PROCESSAMENTO ----------#
# Processa biblioteca offline
# Executa em subshell para preservar o diretorio do chamador.
_processar_biblioteca_offline() (
    _criar_diretorio_seguro "${CFG_PORTALSAV}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio %s\n" "${CFG_PORTALSAV}" >&2
        return 1
    }
    cd "$CFG_PORTALSAV" || return 1

    _definir_variaveis_biblioteca

    local -a arquivos_update
    read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"

    local arquivos_encontrados=0
    for arquivo in "${arquivos_update[@]}"; do
        if [[ -f "${CFG_PORTALSAV}/${arquivo}" ]]; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo encontrado: ${arquivo}"
            _linha
            ((arquivos_encontrados++)) || true
        else
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo nao encontrado: ${arquivo}"
        fi
    done

    if (( arquivos_encontrados == 0 )); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum arquivo de atualizacao encontrado em ${CFG_PORTALSAV}"
        _aguardar_tecla
        return 1
    fi

    _salvar_atualizacao_biblioteca
    _aguardar 2
)

# Salva atualizacao da biblioteca
# Executa em subshell para preservar o diretorio do chamador.
_salvar_atualizacao_biblioteca() (
    if [[ -z "${CFG_PORTALSAV}" ]]; then
        _erro "ERRO: CFG_PORTALSAV nao configurado"
        return 1
    fi

    cd "${CFG_PORTALSAV}" || return 1

    clear
    _definir_variaveis_biblioteca

    # Verificar arquivos de atualizacao
    local -a arquivos_verificar
    read -ra arquivos_verificar <<< "$(_obter_arquivos_atualizacao)"

    for arquivo in "${arquivos_verificar[@]}"; do
        if [[ ! -r "${arquivo}" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Atualizacao nao encontrada ou incompleta: ${arquivo}"
            _linha
            _aguardar_tecla
            return 1
        fi
    done

    _processar_atualizacao_biblioteca
)

# Processa a atualizacao da biblioteca
_processar_atualizacao_biblioteca() {
    # Registrar trap local apenas durante o processamento
    trap '_limpar_interrupcao' INT
    trap '_limpar_interrupcao' TERM

    local arquivo_backup_tar="${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${VERSAO}.tar"
    local caminho_backup_final="${arquivo_backup_tar}.gz"

    # Contador de etapas concluidas (para log final)
    local contador=0

    # Exibir mensagem inicial
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Iniciando compactacao dos arquivos anteriores para backup..."
    _linha
    _aguardar 1

    # Remover backup temporario se existir
    rm -f -- "${arquivo_backup_tar}" "${caminho_backup_final}"

    # Compactacao de E_EXEC + T_TELAS em uma unica passada
    # (lista via stdin evita a regravacao incremental do tar -rf por lote)
    {
        {
            "${DEFAULT_FIND}" "${E_EXEC}/" -type f \( -iname "*.class" -o -iname "*.jpg" -o -iname "*.png" -o -iname "brw*.*" -o -iname "*." -o -iname "*.dll" \) -print0
            "${DEFAULT_FIND}" "${T_TELAS}/" -type f -iname "*.TEL" -print0
        } | "${DEFAULT_TAR}" --null -cf "${arquivo_backup_tar}" -T - >>"${LOG_ATU}" 2>&1
    } &
    local pid_tar_exec=$!
    pids+=("$pid_tar_exec")  # Registrar PID para trap
    if _mostrar_progresso_backup "$pid_tar_exec" "Compactando $E_EXEC e $T_TELAS"; then
        local novos=()
        for _p in "${pids[@]}"; do [[ "$_p" != "$pid_tar_exec" ]] && novos+=("$_p"); done
        pids=("${novos[@]+"${novos[@]}"}")
        ((contador++)) || true
        _ok "Compactacao de $E_EXEC e $T_TELAS concluida"
        _linha
    else
        _erro "Falha na compactacao da biblioteca"
        return 1
    fi

    # Comprimir o arquivo tar final com barra de progresso
    if [[ -f "${arquivo_backup_tar}" ]]; then
        _exibir_mensagem_centralizada "${AMARELO}" "Comprimindo os pacotes de backup..."
        {
            gzip -f "${arquivo_backup_tar}" >>"${LOG_ATU}" 2>&1
        } &
        local pid_gzip=$!
        pids+=("$pid_gzip")
        if _mostrar_progresso_backup "$pid_gzip" "Comprimindo os diretorios"; then
            local novos2=()
            for _p in "${pids[@]}"; do [[ "$_p" != "$pid_gzip" ]] && novos2+=("$_p"); done
            pids=("${novos2[@]+"${novos2[@]}"}")
        else
            _erro "Falha na compressao do arquivo de backup"
            return 1
        fi
    fi

    cd "${SCRIPT_DIR}" || { _erro "Ao acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2; return 1; }
    clear
    _linha
    _aviso "Backup Completo (Formato TAR.GZ)"
    _linha
    _aguardar 1

    # Verificar se backup foi criado
    if [[ ! -r "${caminho_backup_final}" ]]; then
        _linha
        _aviso "Backup nao encontrado no diretorio ou dados nao informados"
        _linha
        _aguardar 2

        if _confirmar "Deseja continuar a atualizacao?" "S"; then
            _aviso "Continuando a atualizacao..."
        else
            pids=()  # Limpar PIDs se saindo
            return 1
        fi
    fi

    pids=()  # Limpar PIDs apos sucesso
    _executar_atualizacao_biblioteca
}

# Executa a atualizacao da biblioteca
_executar_atualizacao_biblioteca() {
    # Validar diretorio de recebimento e a versao antes de montar arquivos ou atualizar .versao.
    if [[ -z "${CFG_PORTALSAV:-}" ]]; then
        _erro "Diretorio $CFG_PORTALSAV nao configurado"
        return 1
    fi
    if ! _validar_versao_biblioteca "${VERSAO:-}"; then
        _erro "Versao invalida. Informe somente numeros."
        return 1
    fi

    # Ir para o diretório onde estao os arquivos
    cd "${CFG_PORTALSAV}" || return 1

    _definir_variaveis_biblioteca

    local -a arquivos_update
    read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"
    # Contar arquivos a processar
    local total_arquivos=0
    for arquivo in "${arquivos_update[@]}"; do
        [[ -n "${arquivo}" && -r "${arquivo}" ]] && { ((total_arquivos++)) || true; }
    done
    local contador=1

    # Definir diretorio de destino para descompactacao
    # O zip contem caminhos relativos como sav/classes/ e sav/tel_isc/
    # Extrair na raiz do filesystem para que os caminhos se resolvam corretamente
    local principal_local
    principal_local="${RAIZ%/*}"
    [[ -z "$principal_local" ]] && principal_local="/"

    # Processar cada arquivo de atualizacao
    for arquivo in "${arquivos_update[@]}"; do
        if [[ -n "${arquivo}" && -r "${arquivo}" ]]; then
            _linha
            _exibir_mensagem_centralizada "${AMARELO}" "Descompactando e atualizando: ${arquivo} [Etapa ${contador}/${total_arquivos}]"
            _linha
            _exibir_mensagem_centralizada "${VERDE}" "Iniciando descompactacao..."

            # Descompactar arquivo em background
            # Nota: Mantemos unzip aqui pois os arquivos de atualizacao recebidos ainda podem ser .zip
            # A alteracao para tar foi solicitada especificamente para as rotinas de backup/reversao
            {
            "${DEFAULT_UNZIP}" -o "${arquivo}" -d "${principal_local}" >>"${LOG_ATU}" 2>&1
            } &
            local pid_unzip=$!
            pids+=("$pid_unzip")  # Registrar PID para trap
            _mostrar_progresso_backup "$pid_unzip" "Descompactando ${arquivo}"
            if wait "$pid_unzip"; then
                _exibir_mensagem_centralizada "${VERDE}" "Descompactacao de ${arquivo} concluida com sucesso"
                ((contador++)) || true
            else
                _erro "Ao descompactar ${arquivo} - Verifique o log ${LOG_ATU}"
                _aguardar 2
                return 1
            fi
            _linha
            # Nota: o atraso artificial de 1s por arquivo foi removido — a
            # barra de progresso ja usa tick de 0.3s (utils.sh), e a semantica
            # de abortar na primeira falha foi preservada.
            clear
        fi
    done

    # Finalizar atualizacao
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Atualizacao concluida com sucesso!"
    _linha

    # Ir para o diretorio de recebimento para renomear arquivos
    cd "${CFG_PORTALSAV}" || return 1

    # Mover arquivos .zip para .bkp e coletar os backups sem alterar nullglob.
    local -a arquivos=()
    while IFS= read -r -d '' arquivo_zip; do
        mv -f -- "$arquivo_zip" "${arquivo_zip%.zip}.bkp"
        arquivos+=("${arquivo_zip%.zip}.bkp")
    done < <("${DEFAULT_FIND}" "${CFG_PORTALSAV}" -maxdepth 1 -type f -name "*_${VERSAO}.zip" -print0)

    # Mover backups para diretorio
    if (( ${#arquivos[@]} > 0 )); then
        mv -- "${arquivos[@]}" "${DEFAULT_BIBLIOTECA_ATUAL_DIR}" || {
        _erro "ao mover arquivos de backup."
        _aguardar 2
        return 1
        }
    else
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum arquivo de backup para mover"
    fi

    # Atualizar mensagens finais
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Alterando a extensao da atualizacao"
    _exibir_mensagem_centralizada "${AMARELO}" "De *.zip para *.bkp"
    _aviso "Versao atualizada - ${VERSAO}"
    _linha

    # Salvar versao anterior (substituir se existir, adicionar se nao existir)
    if grep -q "^VERSAOANT=" "${CFG_DIR}/.versao" 2>/dev/null; then
        # Substituir linha existente
        sed -i "s/^VERSAOANT=.*/VERSAOANT=${VERSAO}/" "${CFG_DIR}/.versao"
    else
        # Adicionar nova linha
        if ! printf "VERSAOANT=%s\n" "${VERSAO}" >> "${CFG_DIR}/.versao"; then
            _erro "Ao gravar arquivo de versao atualizada"
            _aguardar_tecla
            return 1
        fi
    fi

    pids=()  # Limpar PIDs apos sucesso
    _aguardar_tecla

    # Restaurar trap original ao encerrar o processamento
    trap '_encerrar_programa 130' INT TERM
}

#---------- FUNCOES DE REVERSAO ----------#
# Extrai backup completo ou seletivo na raiz, preservando suporte TAR.GZ e ZIP.
# Uso: _extrair_backup_biblioteca <arquivo_backup> <destino> [padrao]
_extrair_backup_biblioteca() {
    local arquivo_backup="$1"
    local destino="$2"
    local padrao="${3:-}"

    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        if [[ -n "$padrao" ]]; then
            "${DEFAULT_TAR}" -xzf "$arquivo_backup" -C "$destino" --wildcards "$padrao" >>"${LOG_ATU}" 2>&1
        else
            "${DEFAULT_TAR}" -xzf "$arquivo_backup" -C "$destino" >>"${LOG_ATU}" 2>&1
        fi
    elif [[ -n "$padrao" ]]; then
        "${DEFAULT_UNZIP}" -o "$arquivo_backup" "$padrao" -d "$destino" >>"${LOG_ATU}" 2>&1
    else
        "${DEFAULT_UNZIP}" -o "$arquivo_backup" -d "$destino" >>"${LOG_ATU}" 2>&1
    fi
}

# Reverte biblioteca completa
_reverter_biblioteca_completa() {
    local arquivo_backup="$1"
    if [[ ! -r "$arquivo_backup" ]]; then
        _erro "Backup nao encontrado ou ilegivel"
        return 1
    fi

    local temp_restore="/"
    # Extrai na raiz pois o backup contem caminhos absolutos (E_EXEC, T_TELAS)

    _exibir_mensagem_centralizada "${AMARELO}" "Voltando backup anterior (TAR)..."
    _linha

    if ! _extrair_backup_biblioteca "$arquivo_backup" "$temp_restore"; then
        _erro "ao descompactar ${arquivo_backup}"
        _aguardar_tecla
        return 1
    fi

    _aviso "Volta de todos os Programas Concluida"
    _linha
    _aguardar_tecla
}

# Reverte programa especifico da biblioteca
_reverter_programa_especifico_biblioteca() {
    local arquivo_backup="$1"
    local programa_reverter
    local temp_restore="/"
    # Extrai na raiz pois o backup contem caminhos absolutos (E_EXEC, T_TELAS)

    read -rp "${AMARELO}Informe o nome do programa em MAIÚSCULO: ${NORMAL}" programa_reverter

    if ! _validar_nome_programa "${programa_reverter}"; then
        _erro "Nome do programa invalido. Use apenas letras maiusculas e numeros."
        _aguardar_tecla
        return 1
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Voltando versao anterior do programa ${programa_reverter} (TAR)..."
    _linha

    local padrao
    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        padrao="*${programa_reverter}*"
    else
        padrao="*/${programa_reverter}*"
    fi

    if ! _extrair_backup_biblioteca "$arquivo_backup" "$temp_restore" "$padrao"; then
        _erro "Ao descompactar programa ${programa_reverter}"
        _aguardar_tecla
        return 1
    fi

    _aviso "Volta do Programa Concluida"
    _aguardar_tecla
}

#---------- FUNCOES AUXILIARES ----------#
# Valida versao numerica antes de usa-la em nomes de arquivos, caminhos ou .versao.
# Retorna 0 para uma sequencia nao vazia de digitos; 1 nos demais casos.
_validar_versao_biblioteca() {
    local versao="${1:-}"
    [[ "$versao" =~ ^[0-9]+$ ]]
}

# Solicita versao da biblioteca
_solicitar_versao_biblioteca() {
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Informe a versao da Biblioteca a ser atualizada:"
    _linha
    printf "\n"
    read -rp "${VERDE}Informe somente o numeral da versao: ${NORMAL}" VERSAO

    if [[ -z "${VERSAO}" ]]; then
        printf "\n"
        _linha
        _erro "Versao a ser atualizada nao foi informada"
        _linha
        _aguardar_tecla
        return 0
    fi
    return 0
}

# Define variaveis da biblioteca baseado na versao
_definir_variaveis_biblioteca() {
    ATUALIZA1="${SAVATU1:-}${VERSAO}.zip"
    ATUALIZA2="${SAVATU2:-}${VERSAO}.zip"
    ATUALIZA3="${SAVATU3:-}${VERSAO}.zip"
}

_obter_arquivos_atualizacao() {
    printf "%s %s %s" "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}"
}
