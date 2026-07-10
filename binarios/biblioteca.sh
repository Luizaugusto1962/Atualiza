#!/usr/bin/env bash
set -euo pipefail
#
# biblioteca.sh - Modulo de Gestao de Biblioteca
# Responsavel pela atualizacao das bibliotecas do sistema (Transpc, Savatu)
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 10/07/2026-02
#
declare -g pids=()                     # Array global para rastrear PIDs de background
declare -g ATUALIZA1="" ATUALIZA2="" ATUALIZA3=""      # Variaveis de artefatos

# Funcao de cleanup em caso de interrupcao
_limpar_interrupcao() {
    local sinal="$1"
    _log "Interrupcao detectada (sinal: $sinal). Limpando processos..."
    
    # Matar todos os PIDs pendentes
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            _log "Processo PID $pid interrompido"
        fi
    done
    pids=()  # Limpar array
    
    # Limpeza de temporarios (ex: zips parciais ou descompactados incompletos)
    _ir_para_tools

    if [[ -n "${VERSAO:-}" ]]; then
        for temp_file in *"${VERSAO}".zip *"${VERSAO}".tar *"${VERSAO}".tar.gz; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file" 
                _log "Arquivo temporario removido: $temp_file"
            fi
        done
    fi
        
    # Verificar se backup parcial existe e sugerir rollback
    shopt -s nullglob
    local backups_parciais=("${DEFAULT_BIBLIOTECA_DIR}"/backups_biblioteca_antes_da_versao-*.zip "${DEFAULT_BIBLIOTECA_DIR}"/backups_biblioteca_antes_da_versao-*.tar.gz)
    shopt -u nullglob
    if (( ${#backups_parciais[@]} > 0 )); then
        _aviso "Backup parcial encontrado. Considere reverter manualmente com '_reverter_biblioteca'"
    fi
    
    _log "Cleanup concluido. Saida forcada."
    _aguardar_tecla  # Pausa para o usuario ver a mensagem
    return 1
}

# Configurar traps (SIGINT=2 para Ctrl+C, SIGTERM=15 para kill)
trap '_limpar_interrupcao' INT
trap '_limpar_interrupcao' TERM

#---------- FUNCOES PRINCIPAIS DE ATUALIZACAO ----------#

# Atualizacao do Transpc
_atualizar_transpc() {
    _limpa_tela
    _solicitar_versao_biblioteca
    
    if [[ -z "${VERSAO}" ]]; then
        return 0
    fi

    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            _linha
            _mensagec "${AMARELO}" "Parametro de biblioteca do servidor OFF ativo"
            _linha
            _aguardar_tecla
            return 0
        fi
        _linha
        _mensagec "${AMARELO}" "Informe a senha para o usuario remoto:"
        _linha
        #_configurar_acessos
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
    _limpa_tela
       _linha
    _mensagec "${AMARELO}" "Diretorio de download: ${NORMAL}${DEFAULT_RECEBE_DIR}"
     _solicitar_versao_biblioteca
    
    if [[ -z "${VERSAO}" ]]; then
        return 0
    fi

    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            if ! _processar_biblioteca_offline; then
                _erro "Falha ao processar biblioteca offline."
                _aviso "Verifique se os arquivos estao no diretorio: ${DEFAULT_RECEBE_DIR}"
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
    _mensagec "${VERMELHO}" "Informe a versao da biblioteca para reverter:"
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

    # Tentar encontrar o backup tanto em .tar.gz quanto em .zip (para retrocompatibilidade)
    local arquivo_backup="${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${versao_reverter}.tar.gz"
    
    if [[ ! -r "${arquivo_backup}" ]]; then
        arquivo_backup="${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${versao_reverter}.zip"
    fi

    if [[ ! -r "${arquivo_backup}" ]]; then
        _mensagec "${VERMELHO}" "Backup da biblioteca nao encontrado: ${NORMAL}${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${versao_reverter}.tar.gz"
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
_processar_biblioteca_offline() {
    _criar_diretorio_seguro "${DEFAULT_RECEBE_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio %s\n" "${DEFAULT_RECEBE_DIR}" >&2
        return 1
    }
    cd "$DEFAULT_RECEBE_DIR" || return 1

    _definir_variaveis_biblioteca
  
    local -a arquivos_update
    read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"

    local arquivos_encontrados=0
    for arquivo in "${arquivos_update[@]}"; do
        if [[ -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _mensagec "${VERDE}" "Arquivo encontrado: ${arquivo}"
            _linha
            ((arquivos_encontrados++)) || true
        else
            _mensagec "${AMARELO}" "Arquivo nao encontrado: ${arquivo}"
        fi
    done

    if (( arquivos_encontrados == 0 )); then
        _mensagec "${VERMELHO}" "Nenhum arquivo de atualizacao encontrado em ${DEFAULT_RECEBE_DIR}"
        _aguardar_tecla
        return 1
    fi

    _salvar_atualizacao_biblioteca
    _aguardar 2
}

# Salva atualizacao da biblioteca
_salvar_atualizacao_biblioteca() {
    if [[ -z "${DEFAULT_RECEBE_DIR}" ]]; then
        _erro "ERRO: DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi

    cd "${DEFAULT_RECEBE_DIR}" || return 1

    _limpa_tela
    _definir_variaveis_biblioteca

    # Verificar arquivos de atualizacao
    local -a arquivos_verificar
    read -ra arquivos_verificar <<< "$(_obter_arquivos_atualizacao)"

    for arquivo in "${arquivos_verificar[@]}"; do
        if [[ ! -r "${arquivo}" ]]; then
            _mensagec "${VERMELHO}" "Atualizacao nao encontrada ou incompleta: ${arquivo}"
            _linha
            _aguardar_tecla
            return 1
        fi
    done

    _processar_atualizacao_biblioteca
}

# Processa a atualizacao da biblioteca
_processar_atualizacao_biblioteca() {
    # Registrar trap local apenas durante o processamento
    trap '_limpar_interrupcao' INT
    trap '_limpar_interrupcao' TERM
    
    local arquivo_backup_tar="${DEFAULT_BIBLIOTECA_DIR}/backup_biblioteca_antes_da_versao-${VERSAO}.tar"
    local caminho_backup_final="${arquivo_backup_tar}.gz"

    # Inicializar contadores para progresso geral (opcional, para log final)
    local contador=0
    local total_etapas=2 

    # Exibir mensagem inicial
    _linha
    _mensagec "${AMARELO}" "Iniciando compactacao dos arquivos anteriores para backup..."
    _linha
    _aguardar 1

    # Remover backup temporario se existir
    rm -f "${arquivo_backup_tar}" "${caminho_backup_final}"

    # Compactacao em E_EXEC
    {
        "${DEFAULT_FIND}" "${E_EXEC}/" -type f \( -iname "*.class" -o -iname "*.int" -o -iname "*.jpg" -o -iname "*.png" -o -iname "brw*.*" -o -iname "*." -o -iname "*.dll" \) -exec "${DEFAULT_TAR}" -rf "${arquivo_backup_tar}" {} + >>"${LOG_ATU}" 2>&1
    } &
    local pid_tar_exec=$!
    pids+=("$pid_tar_exec")  # Registrar PID para trap
    if _mostrar_progresso_backup "$pid_tar_exec" "Compactando $E_EXEC"; then
        pids=("${pids[@]/$pid_tar_exec}")  # Remover PID apos concluido
        ((contador++)) || true
        _ok "Compactacao de $E_EXEC concluida [Etapa ${contador}/${total_etapas}]"
        _linha
    else
        _erro "Falha na compactacao de $E_EXEC"
        return 1
    fi

    # Compactacao em T_TELAS
    {
        "${DEFAULT_FIND}" "${T_TELAS}/" -type f \( -iname "*.TEL" \) -exec "${DEFAULT_TAR}" -rf "${arquivo_backup_tar}" {} + >>"${LOG_ATU}" 2>&1
    } &
    local pid_tar_telas=$!
    pids+=("$pid_tar_telas")  # Registrar PID
    if _mostrar_progresso_backup "$pid_tar_telas" "Compactando $T_TELAS"; then
        ((contador++)) || true
        _mensagec "${VERDE}" "Compactacao de $T_TELAS concluida [Etapa ${contador}/${total_etapas}]"
        _linha
    else
        _mensagec "${VERMELHO}" "Falha na compactacao de $T_TELAS"
        return 1
    fi

    # Comprimir o arquivo tar final com barra de progresso
    if [[ -f "${arquivo_backup_tar}" ]]; then
        _mensagec "${AMARELO}" "Comprimindo os pacotes de backup..."
        {
            gzip -f "${arquivo_backup_tar}" >>"${LOG_ATU}" 2>&1
        } &
        local pid_gzip=$!
        pids+=("$pid_gzip")
        if _mostrar_progresso_backup "$pid_gzip" "Comprimindo os diretorios"; then
            pids=("${pids[@]/$pid_gzip}")  # Remover PID apos sucesso
        else
            _erro "Falha na compressao do arquivo de backup"
            return 1
        fi
    fi

    _ir_para_tools
    _limpa_tela
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
    # Validar diretorio de recebimento
    if [[ -z "${DEFAULT_RECEBE_DIR:-}" ]]; then
        _erro "Diretorio $DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi

    # Ir para o diretório onde estao os arquivos
    cd "${DEFAULT_RECEBE_DIR}" || return 1
    
    _definir_variaveis_biblioteca
     
    local -a arquivos_update
    read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"
    # Contar arquivos a processar
    local total_arquivos=0
    for arquivo in "${arquivos_update[@]}"; do
        [[ -n "${arquivo}" && -r "${arquivo}" ]] && { ((total_arquivos++)) || true; }
    done
    local contador=1

# Definir diretorio de configuracao usando variaveis locais
    local RAIZ_LOCAL="${RAIZ}"
    local principal_local
    principal_local="${RAIZ_LOCAL%/*}"

    # Processar cada arquivo de atualizacao
    for arquivo in "${arquivos_update[@]}"; do
        if [[ -n "${arquivo}" && -r "${arquivo}" ]]; then
            _linha
            _mensagec "${AMARELO}" "Descompactando e atualizando: ${arquivo} [Etapa ${contador}/${total_arquivos}]"
            _linha
            _mensagec "${VERDE}" "Iniciando descompactacao..."

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
                _mensagec "${VERDE}" "Descompactacao de ${arquivo} concluida com sucesso"
                ((contador++)) || true
            else
                _erro "Ao descompactar ${arquivo} - Verifique o log ${LOG_ATU}"
                _aguardar 2
                return 1
            fi
            _linha
            _aguardar 1
            _limpa_tela
        fi
    done

    # Finalizar atualizacao
    _linha
    _mensagec "${AMARELO}" "Atualizacao concluida com sucesso!"
    _linha
    
    # Ir para o diretorio de recebimento para renomear arquivos
    cd "${DEFAULT_RECEBE_DIR}" || return 1
    
    # Mover arquivos .zip para .bkp
    shopt -s nullglob
    for arquivo_zip in *_"${VERSAO}".zip; do
        mv -f "${arquivo_zip}" "${arquivo_zip%.zip}.bkp"
    done
    
    # Mover backups para diretorio
    local arquivos=(*_"${VERSAO}".bkp)
    shopt -u nullglob
    if (( ${#arquivos[@]} > 0 )); then
        mv -- "${arquivos[@]}" "${DEFAULT_BIBLIOTECA_ATUAL_DIR}" || {
        _erro "ao mover arquivos de backup."
        _aguardar 2
        return 1
        }
    else
        _mensagec "${AMARELO}" "Nenhum arquivo de backup para mover"
    fi

    # Atualizar mensagens finais
    _linha
    _mensagec "${AMARELO}" "Alterando a extensao da atualizacao"
    _mensagec "${AMARELO}" "De *.zip para *.bkp"
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
# Reverte biblioteca completa
_reverter_biblioteca_completa() {
    local arquivo_backup="$1"
    if [[ ! -r "$arquivo_backup" ]]; then
        _erro "Backup nao encontrado ou ilegivel"
        return 1
    fi

    local temp_restore="/"
    # Extrai na raiz pois o backup contem caminhos absolutos (E_EXEC, T_TELAS)

    if ! cd "${DEFAULT_BIBLIOTECA_DIR}"; then
        _erro "Falha ao acessar o diretorio ${DEFAULT_BIBLIOTECA_DIR}"
        _aguardar_tecla
        return 1
    fi

    _mensagec "${AMARELO}" "Voltando backup anterior (TAR)..."
    _linha

    # Verificar se o arquivo e tar.gz ou zip
    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        if ! tar -xzf "${arquivo_backup}" -C "${temp_restore}" >>"${LOG_ATU}" 2>&1; then
            _erro "ao descompactar ${arquivo_backup}"
            _aguardar_tecla
            return 1
        fi
    else
        if ! "${DEFAULT_UNZIP}" -o "${arquivo_backup}" -d "${temp_restore}" >>"${LOG_ATU}" 2>&1; then
            _erro "ao descompactar ${arquivo_backup}"
            _aguardar_tecla
            return 1
        fi
    fi

    _ir_para_tools
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
    
    if ! cd "${DEFAULT_BIBLIOTECA_DIR}"; then
        _erro "Falha ao acessar o diretorio ${DEFAULT_BIBLIOTECA_DIR}"
        _aguardar 2
        return 1
    fi

    read -rp "${AMARELO}Informe o nome do programa em MAIÚSCULO: ${NORMAL}" programa_reverter

    if ! _validar_nome_programa "${programa_reverter}"; then
        _erro "Nome do programa invalido. Use apenas letras maiusculas e numeros."
        _aguardar_tecla
        return 1
    fi

    _linha
    _mensagec "${AMARELO}" "Voltando versao anterior do programa ${programa_reverter} (TAR)..."
    _linha

    # Verificar se o arquivo e tar.gz ou zip
    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        # No tar, usamos wildcards para encontrar o programa
        if ! tar -xzf "${arquivo_backup}" -C "${temp_restore}" --wildcards "*${programa_reverter}*" >>"${LOG_ATU}" 2>&1; then
            _erro "Ao descompactar programa ${programa_reverter}"
            _aguardar_tecla
            return 1
        fi
    else
        local padrao="*/"
        if ! "${DEFAULT_UNZIP}" -o "${arquivo_backup}" "${padrao}${programa_reverter}*" -d "${temp_restore}" >>"${LOG_ATU}" 2>&1; then
            _erro "Ao descompactar programa ${programa_reverter}"
            _aguardar_tecla
            return 1
        fi
    fi

    _aviso "Volta do Programa Concluida"
    _aguardar_tecla
}

#---------- FUNCOES AUXILIARES ----------#

# Solicita versao da biblioteca
_solicitar_versao_biblioteca() {
    declare -g VERSAO
    _linha
    _mensagec "${AMARELO}" "Informe a versao da Biblioteca a ser atualizada:"
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
