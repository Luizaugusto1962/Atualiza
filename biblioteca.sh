#!/usr/bin/env bash
#
# biblioteca.sh - Modulo de Gestao de Biblioteca
# Responsavel pela atualizacao das bibliotecas do sistema (Transpc, Savatu)
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 14/04/2026-00
#
# Variaveis globais esperadas
sistema="${sistema:-}"                 # Tipo de sistema (iscobol/mf)
cmd_zip="${cmd_zip:-}"                 # Comando de compactacao (zip)
cmd_unzip="${cmd_unzip:-}"             # Comando de descompactacao (unzip)
cmd_find="${cmd_find:-}"               # Comando de busca (find)
acessossh="${acessossh:-}"             # Acesso via SSH (s/n)
Offline="${Offline:-}"                 # Modo offline (s/n)
down_dir="${down_dir:-}"               # Diretorio de download
cfg_dir="${cfg_dir:-}"                 # Diretorio de configuracao

declare -g pids=()                     # Array global para rastrear PIDs de background

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

    for temp_file in *"${VERSAO}".zip; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file" 
            _log "Arquivo temporario removido: $temp_file"
        fi
    done
        
    # Verificar se backup parcial existe e sugerir rollback
    local ultimo_backup="${BIBLIOTECA}/backup_biblioteca_antes_da_versao-*.zip"
    if [[ -n "$(ls -A "${ultimo_backup}" 2>/dev/null)" ]]; then
        _mensagec "${YELLOW}" "Backup parcial encontrado. Considere reverter manualmente com '_reverter_biblioteca'"
    fi
    
    _log "Cleanup concluido. Saida forcada."
    _press  # Pausa para o usuario ver a mensagem
    return 1
}

# Configurar traps (SIGINT=2 para Ctrl+C, SIGTERM=15 para kill)
trap '_limpar_interrupcao INT' INT
trap '_limpar_interrupcao TERM' TERM

#---------- FUNCOES PRINCIPAIS DE ATUALIZACAO ----------#

# Atualizacao do Transpc
_atualizar_transpc() {
    _limpa_tela
    _solicitar_versao_biblioteca
    
    if [[ -z "${VERSAO}" ]]; then
        return 0
    fi

    if [[ "${Offline}" =~ ^[sn]$ ]]; then
        if [[ "${Offline}" == "s" ]]; then
            _linha
            _mensagec "${YELLOW}" "Parametro de biblioteca do servidor OFF ativo"
            _linha
            _press
            return 0
        fi
        _linha
        _mensagec "${YELLOW}" "Informe a senha para o usuario remoto:"
        _linha
        _configurar_acessos
        # Verificar espaco em disco
        if ! _verificar_espaco_disco "$E_EXEC"; then
            _mensagec "$RED" "Espaco em disco insuficiente em $E_EXEC"
            _read_sleep 3
            return 1
        fi
    fi    
    _baixar_biblioteca_sincroniza
    _salvar_atualizacao_biblioteca
}

# Atualizacao offline da biblioteca
_atualizar_biblioteca_offline() {
    _limpa_tela
       _linha
    _mensagec "${YELLOW}" "Diretorio de download: ${WHITE}${down_dir}"
     _solicitar_versao_biblioteca
    
    if [[ -z "${VERSAO}" ]]; then
        return 0
    fi

    if [[ "${Offline}" =~ ^[sn]$ ]]; then
        if [[ "${Offline}" == "s" ]]; then
            _processar_biblioteca_offline
        else
            _salvar_atualizacao_biblioteca
        fi
    fi    
}

# Reverter biblioteca para versao anterior
_reverter_biblioteca() {
    _meio_da_tela
    _mensagec "${RED}" "Informe a versao da biblioteca para reverter:"
    _linha
    
    local versao_reverter
    read -rp "${YELLOW}Versao a reverter: ${NORM}" versao_reverter
    _linha

    if [[ -z "${versao_reverter}" ]]; then
        _mensagec "${RED}" "Versao nao informada"
        _linha
        _press
        return 0
    fi

    local arquivo_backup="${BIBLIOTECA}/backup_biblioteca_antes_da_versao-${versao_reverter}.zip"

    if [[ ! -r "${arquivo_backup}" ]]; then
        _mensagec "${RED}" "Backup da biblioteca nao encontrado: ${WHITE}${arquivo_backup}"
        _linha
        _press
        return 0
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
    _configurar_acessos
    cd "$down_dir" || return 1

    _definir_variaveis_biblioteca
  
    local -a arquivos_update
    read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"

    for arquivo in "${arquivos_update[@]}"; do
        if [[ -f "${down_dir}/${arquivo}" ]]; then
            _mensagec "${GREEN}" "Arquivo encontrado: ${arquivo}"
            _linha
        else
            _mensagec "${YELLOW}" "Arquivo nao encontrado: ${arquivo}"
        fi
    done
    _salvar_atualizacao_biblioteca
    _read_sleep 2
}

# Salva atualizacao da biblioteca
_salvar_atualizacao_biblioteca() {
    cd "${down_dir}" || return 1

    _limpa_tela
    _definir_variaveis_biblioteca

    # Verificar arquivos de atualizacao
    local -a arquivos_verificar
    read -ra arquivos_verificar <<< "$(_obter_arquivos_atualizacao)"

    for arquivo in "${arquivos_verificar[@]}"; do
        if [[ ! -r "${arquivo}" ]]; then
            _mensagec "${RED}" "Atualizacao nao encontrada ou incompleta: ${arquivo}"
            _linha
            _press
            return 1
        fi
    done

    _processar_atualizacao_biblioteca
}

# Processa a atualizacao da biblioteca
_processar_atualizacao_biblioteca() {
    local arquivo_backup="backup_biblioteca_antes_da_versao-${VERSAO}.zip"
    local caminho_backup="${BIBLIOTECA}/${arquivo_backup}"

    # Inicializar contadores para progresso geral (opcional, para log final)
    local contador=0
    local total_etapas=2 # Para sistemas nao-iscobol
    if [[ "$sistema" = "iscobol" ]]; then
        total_etapas=3 # Para iscobol inclui XML
    fi

    # Exibir mensagem inicial
    _linha
    _mensagec "${YELLOW}" "Iniciando compactacao dos arquivos anteriores para backup..."
    _linha
    _read_sleep 1

    # Compactacao em E_EXEC
    cd "$E_EXEC" || return 1
    {
        "$cmd_find" "$E_EXEC"/ -type f \( -iname "*.class" -o -iname "*.int" -o -iname "*.jpg" -o -iname "*.png" -o -iname "brw*.*" -o -iname "*." -o -iname "*.dll" \) -exec "$cmd_zip" -r -q "${caminho_backup}" {} + >>"${LOG_ATU}" 2>&1
    } &
    local pid_zip_exec=$!
    pids+=("$pid_zip_exec")  # Registrar PID para trap
    _mostrar_progresso_backup "$pid_zip_exec"
    if wait "$pid_zip_exec"; then
        pids=("${pids[@]/$pid_zip_exec}")  # Remover PID apos concluido
        ((contador++)) || true
        _mensagec "${GREEN}" "Compactacao de $E_EXEC concluida [Etapa ${contador}/${total_etapas}]"
        _linha
    else
        _mensagec "${RED}" "Falha na compactacao de $E_EXEC"
        return 1
    fi

    # Compactacao em T_TELAS
    cd "$T_TELAS" || return 1
    {
        "$cmd_find" "$T_TELAS"/ -type f \( -iname "*.TEL" \) -exec "$cmd_zip" -r -q "${caminho_backup}" {} + >>"${LOG_ATU}" 2>&1
    } &
    local pid_zip_telas=$!
    pids+=("$pid_zip_telas")  # Registrar PID
    _mostrar_progresso_backup "$pid_zip_telas"
    if wait "$pid_zip_telas"; then
        ((contador++)) || true
        _mensagec "${GREEN}" "Compactacao de $T_TELAS concluida [Etapa ${contador}/${total_etapas}]"
        _linha
    else
        _mensagec "${RED}" "Falha na compactacao de $T_TELAS"
        return 1
    fi

    # Compactacao em X_XML (apenas para IsCOBOL)
    if [[ "$sistema" == "iscobol" ]]; then
        cd "$X_XML" || return 1
        {
            "$cmd_find" "$X_XML"/ -type f \( -iname "*.xml" \) -exec "$cmd_zip" -r -q "${caminho_backup}" {} + >>"${LOG_ATU}" 2>&1
        } &
        local pid_zip_xml=$!
        pids+=("$pid_zip_xml")  # Registrar PID
        _mostrar_progresso_backup "$pid_zip_xml"
        if wait "$pid_zip_xml"; then
            ((contador++)) || true
            _mensagec "${GREEN}" "Compactacao de $X_XML concluida [Etapa ${contador}/${total_etapas}]"
            _linha
        else
            _mensagec "${RED}" "Falha na compactacao de $X_XML"
            return 1
        fi
    fi
    _ir_para_tools
    _limpa_tela
    _linha
    _mensagec "${YELLOW}" "Backup Completo"
    _linha
    _read_sleep 1

    # Verificar se backup foi criado
    if [[ ! -r "${caminho_backup}" ]]; then
        _linha
        _mensagec "${RED}" "Backup nao encontrado no diretorio ou dados nao informados"
        _linha
        _read_sleep 2
        
        if _confirmar "Deseja continuar a atualizacao?" "S"; then
            _mensagec "${YELLOW}" "Continuando a atualizacao..."
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
    # Ir para o diretório envia onde estão os arquivos
    cd "${down_dir:-}" || return 1
    
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
    local raiz_local
    raiz_local="${SCRIPT_DIR%/*}"
    local principal_local
    principal_local="$(dirname "$raiz_local")"

    # Processar cada arquivo de atualizacao
    for arquivo in "${arquivos_update[@]}"; do
        if [[ -n "${arquivo}" && -r "${arquivo}" ]]; then
            _linha
            _mensagec "${YELLOW}" "Descompactando e atualizando: ${arquivo} [Etapa ${contador}/${total_arquivos}]"
            _linha
            _mensagec "${GREEN}" "Iniciando descompactacao..."

            # Descompactar arquivo em background
            {
            "${cmd_unzip}" -o "${arquivo}" -d "${principal_local}" >>"${LOG_ATU}" 2>&1
            } &
            local pid_unzip=$!
            pids+=("$pid_unzip")  # Registrar PID para trap
            _mostrar_progresso_backup "$pid_unzip"
            if wait "$pid_unzip"; then
                _mensagec "${GREEN}" "Descompactacao de ${arquivo} concluida com sucesso"
                ((contador++)) || true
            else
                _mensagec "${RED}" "Erro na descompactacao de ${arquivo} - Verifique o log ${LOG_ATU}"
                _read_sleep 2
                return 1
            fi
            _linha
            _read_sleep 1
            _limpa_tela
        fi
    done

    # Finalizar atualizacao
    _linha
    _mensagec "${YELLOW}" "Atualizacao concluida com sucesso!"
    _linha
    
    # Ir para o diretório envia para renomear os arquivos
    cd "${down_dir:-}" || return 1
    
    # Mover arquivos .zip para .bkp
    for arquivo_zip in *_"${VERSAO}".zip; do
        if [[ -f "${arquivo_zip}" ]]; then
            mv -f "${arquivo_zip}" "${arquivo_zip%.zip}.bkp"
        fi
    done
    
    # Mover backups para diretorio
    local arquivos=(*_"${VERSAO}".bkp)
    if (( ${#arquivos[@]} )); then
        mv -- "${arquivos[@]}" "${OLDS}" || {
        _mensagec "${YELLOW}" "Erro ao mover arquivos de backup."
        _read_sleep 2
        return 1
        }
    else
        _mensagec "${YELLOW}" "Nenhum arquivo de backup para mover"
    fi

    # Atualizar mensagens finais
    _linha
    _mensagec "${YELLOW}" "Alterando a extensao da atualizacao"
    _mensagec "${YELLOW}" "De *.zip para *.bkp"
    _mensagec "${RED}" "Versao atualizada - ${VERSAO}"
    _linha

    # Salvar versao anterior (substituir se existir, adicionar se nao existir)
    if grep -q "^VERSAOANT=" "${cfg_dir}/.versao" 2>/dev/null; then
        # Substituir linha existente
        sed -i "s/^VERSAOANT=.*/VERSAOANT=${VERSAO}/" "${cfg_dir}/.versao"
    else
        # Adicionar nova linha
        if ! printf "VERSAOANT=%s\n" "${VERSAO}" >> "${cfg_dir}/.versao"; then
            _mensagec "${RED}" "Erro ao gravar arquivo de versao atualizada"
            _press
            return 1
        fi
    fi

    pids=()  # Limpar PIDs apos sucesso
    _press
}

#---------- FUNCOES DE REVERSAO ----------#
# Reverte biblioteca completa
_reverter_biblioteca_completa() {
    local arquivo_backup="$1"
    local raiz="/"

    if ! cd "${BIBLIOTECA}"; then
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${BIBLIOTECA}"
        _press
        return 1
    fi

    if ! "${cmd_unzip}" -o "${arquivo_backup}" -d "${raiz}" >>"${LOG_ATU}"; then
        _mensagec "${RED}" "Erro ao descompactar ${arquivo_backup}"
        _press
        return 1
    fi
    _ir_para_tools
    _mensagec "${YELLOW}" "Voltando backup anterior..."
    _linha
    _mensagec "${YELLOW}" "Volta de todos os Programas Concluida"
    _linha
    _press
}

# Reverte programa especifico da biblioteca
_reverter_programa_especifico_biblioteca() {
    local arquivo_backup="$1"
    local programa_reverter

    if ! cd "${BIBLIOTECA}"; then
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${BIBLIOTECA}"
        _read_sleep 2
        return 1
    fi

    read -rp "${YELLOW}Informe o nome do programa em MAIÚSCULO: ${NORM}" programa_reverter

    if [[ -z "${programa_reverter}" || ! "${programa_reverter}" =~ ^[A-Z0-9]+$ ]]; then
        _mensagec "${RED}" "Nome do programa invalido"
        _press
        return 1
    fi

    _linha
    _mensagec "${YELLOW}" "Voltando versao anterior do programa ${programa_reverter}"
    _linha

    local padrao="*/"
    if ! "${cmd_unzip}" -o "${arquivo_backup}" "${padrao}${programa_reverter}*" -d "/" >>"${LOG_ATU}"; then
        _mensagec "${RED}" "Erro: Ao descompactar programa ${programa_reverter}"
        _press
        return 1
    fi

    _mensagec "${YELLOW}" "Volta do Programa Concluida"
    _press
}

#---------- FUNcoES AUXILIARES ----------#

# Solicita versao da biblioteca
_solicitar_versao_biblioteca() {
    _linha
    _mensagec "${YELLOW}" "Informe versao a da Biblioteca a ser atualizada:"
    _linha
    printf "\n"
    read -rp "${GREEN}Informe somente o numeral da versao: ${NORM}" VERSAO
    
    if [[ -z "${VERSAO}" ]]; then
        printf "\n"
        _linha
        _mensagec "${RED}" "Versao a ser atualizada nao foi informada"
        _linha
        _press
        return 0
    fi
    
    return 0
}

# Define variaveis da biblioteca baseado na versao
_definir_variaveis_biblioteca() {
    ATUALIZA1="${SAVATU1}${VERSAO}.zip"
    ATUALIZA2="${SAVATU2}${VERSAO}.zip"
    ATUALIZA3="${SAVATU3}${VERSAO}.zip"
    ATUALIZA4="${SAVATU4}${VERSAO}.zip"
}

_obter_arquivos_atualizacao() {
    if [[ "${sistema}" == "iscobol" ]]; then
        echo "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}" "${ATUALIZA4}"
    else
        echo "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}" 
    fi
}

