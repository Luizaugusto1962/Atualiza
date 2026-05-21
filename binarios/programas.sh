#!/usr/bin/env bash
#
# programas.sh - Modulo de Gestao de Programas
# Responsavel pela atualizacao, instalacao e reversao de programas
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 20/05/2026-01
#
# ===========================================================================
# PRÉ-REQUISITO: carregar APÓS constantes.sh e config.sh
# ===========================================================================

#---------- VARIaVEIS GLOBAIS DO MODULO ----------#
declare -g ARQUIVO_COMPILADO_ATUAL=""
declare -a PROGRAMAS_SELECIONADOS=()
declare -a ARQUIVOS_PROGRAMA=()

#---------- FUNCOES DE ATUALIZACAO ONLINE ----------#
_atualizar_programa_online() {
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            _linha
            _mensagec "${YELLOW}" "Parametro do servidor OFF ativo"
            _linha
            _press
            return 0
        fi
    fi
    _solicitar_programas_atualizacao
    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${YELLOW}" "Nenhum programa selecionado"
        _linha
        _press
        return 0
    fi
    _baixar_programas_vaievem
    _processar_atualizacao_programas
    _linha
    _press
}

#---------- FUNCOES DE ATUALIZACAO OFFLINE ----------#
_atualizar_programa_offline() {
    _solicitar_programas_atualizacao
    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${YELLOW}" "Nenhum programa selecionado"
        _linha
        _press
        return 0
    fi
    _linha
    _mensagec "${YELLOW}" "Os programas devem estar no diretorio ${WHITE}${DEFAULT_RECEBE_DIR}"
    _linha
    _aguardar 0
    _mover_arquivos_offline
    _processar_atualizacao_programas
    _linha
    _press
}

#---------- FUNCOES DE ATUALIZACAO PACOTES ----------#
_atualizar_programa_pacote() {
    _solicitar_pacotes_atualizacao
    if [[ "${CFG_OFFLINE}" == "s" ]]; then
        _linha
        _mensagec "${YELLOW}" "Parametro do servidor OFF ativo"
        _mover_arquivos_offline
    else
        _baixar_pacotes_vaievem
    fi
    _processar_atualizacao_pacotes
    _linha
    _press
    return 0
}

#---------- FUNCOES DE REVERSaO ----------#
_selecionar_programas_reversao() {
    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()
    if [[ ! -d "${DEFAULT_OLDS_DIR}" ]]; then
        _mensagec "${RED}" "Diretorio de backups nao encontrado: ${DEFAULT_OLDS_DIR}"
        _press
        return 0
    fi
    shopt -s nullglob
    local backups=("${DEFAULT_OLDS_DIR}"/*-anterior.zip)
    shopt -u nullglob
    if (( ${#backups[@]} == 0 )); then
        _mensagec "${YELLOW}" "Nenhum backup de programa encontrado em ${DEFAULT_OLDS_DIR}"
        _press
        return 0
    fi
    local programas=()
    for arquivo in "${backups[@]}"; do
        programas+=("$(basename "${arquivo}" "-anterior.zip")")
    done
    _linha
    _mensagec "${CYAN}" "Backups disponiveis para reversao:"
    _linha
    local idx=1
    for programa in "${programas[@]}"; do
        _mensagec "${GREEN}" "${idx}) ${programa}"
        ((idx++)) || true
    done
    _linha
    _mensagec "${YELLOW}" "Digite o(s) numero(s) do(s) programa(s) a reverter (ex: 1 2 3) ou 0 para sair:"
    local escolha
    while true; do
        read -rp "${YELLOW}Opcao -> ${NORM}" escolha
        _linha
        if [[ -z "${escolha}" || "${escolha}" == "0" ]]; then
            _mensagec "${YELLOW}" "Operacao cancelada."
            return 1
        fi
        escolha="${escolha//,/ }"
        local -a indices=()
        local invalido=0
        for token in ${escolha}; do
            if ! [[ "${token}" =~ ^[0-9]+$ ]]; then
                invalido=1
                break
            fi
            if (( token < 1 || token > ${#programas[@]} )); then
                invalido=1
                break
            fi
            indices+=("${token}")
        done
        if (( invalido )); then
            _mensagec "${RED}" "Opcao invalida. Informe numero(s) entre 1 e ${#programas[@]}."
            continue
        fi
        declare -A seen=()
        for token in "${indices[@]}"; do
            if [[ -n "${seen[$token]:-}" ]]; then continue; fi
            seen[$token]=1
            local programa_selecionado="${programas[$((token-1))]}"
            PROGRAMAS_SELECIONADOS+=("${programa_selecionado}")
            ARQUIVOS_PROGRAMA+=("${programa_selecionado}${CLASS}.zip")
        done
        break
    done
    return 0
}

_reverter_programa() {
    if _selecionar_programas_reversao; then
        _processar_reversao_programas
        _mensagem_conclusao_reversao
    else
        _mensagec "${RED}" "Nenhum programa foi selecionado para reversao"
        _linha
        _press
    fi
}

#---------- FUNCOES DE SOLICITACAO DE DADOS ----------#
_resolver_arquivo_compilado() {
    local nome_item="$1"
    local tipo_compilacao
    _mensagec "${RED}" "Informe o tipo de compilacao (1 - Normal, 2 - Depuracao):"
    _linha
    read -rp "${YELLOW}Tipo de compilacao: ${NORM}" -n1 tipo_compilacao
    printf "\n"
    if [[ "$tipo_compilacao" == "1" ]]; then
        ARQUIVO_COMPILADO_ATUAL="${nome_item}.class.zip"
    elif [[ "$tipo_compilacao" == "2" ]]; then
        ARQUIVO_COMPILADO_ATUAL="${nome_item}.mclass.zip"
    else
        return 1
    fi
}

_coletar_artefatos_atualizacao() {
    local rotulo_item="$1" mensagem_item="$2" mensagem_final="$3" mensagem_lista="$4"
    local max_repeticoes=6 contador=0 item arquivo_compilado
    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()
    for ((contador = 1; contador <= max_repeticoes; contador++)); do
        _meio_da_tela
        _mensagec "${RED}" "$mensagem_item"
        _linha
        read -rp "${YELLOW}Nome do ${rotulo_item} (ENTER para finalizar): ${NORM}" item
        _linha
        if [[ -z "${item}" ]]; then
            if (( ${#PROGRAMAS_SELECIONADOS[@]} > 0 )); then
                _mensagec "${CYAN}" "Programas informados:"
                for idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
                    local prog="${PROGRAMAS_SELECIONADOS[$idx]}"
                    local arq="${ARQUIVOS_PROGRAMA[$idx]}"
                    if [[ "$arq" == *"${MCLASS}"* ]]; then
                        _mensagec "${GREEN}" "  -> ${prog} - Depuracao"
                    else
                        _mensagec "${GREEN}" "  -> ${prog} - Normal"
                    fi
                done
                _linha
                if ! _confirmar "${WHITE} Confirma a selecao do(s) programa(s) acima?" "S"; then
                    PROGRAMAS_SELECIONADOS=()
                    ARQUIVOS_PROGRAMA=()
                    _mensagec "${YELLOW}" "Selecao cancelada."
                    _linha
                fi
            else
                _mensagec "${YELLOW}" "$mensagem_final"
            fi
            _linha
            break
        fi
        if ! _validar_nome_programa "$item"; then
            _mensagec "${RED}" "Erro: Nome invalido. Use apenas letras maiusculas e numeros."
            continue
        fi
        if ! _resolver_arquivo_compilado "$item"; then
            _mensagec "${RED}" "Erro: Opcao invalida. Digite 1 ou 2."
            continue
        fi
        arquivo_compilado="${ARQUIVO_COMPILADO_ATUAL}"
        PROGRAMAS_SELECIONADOS+=("$item")
        ARQUIVOS_PROGRAMA+=("$arquivo_compilado")
        _linha
        _mensagec "${GREEN}" "${rotulo_item^} adicionado: ${arquivo_compilado}"
        _linha
        if [[ -n "$mensagem_lista" ]]; then
            _mensagec "${YELLOW}" "$mensagem_lista"
            for prog in "${PROGRAMAS_SELECIONADOS[@]}"; do
                _mensagec "${GREEN}" "  - $prog"
            done
        fi
    done
}

_solicitar_programas_atualizacao() {
    _coletar_artefatos_atualizacao \
        "programa" \
        "Informe o nome do programa a ser atualizado:" \
        "Finalizando selecao de programas..." \
        "Programas selecionados:"
}

_solicitar_pacotes_atualizacao() {
    _coletar_artefatos_atualizacao \
        "pacote" \
        "Informe o nome do pacote:" \
        "Finalizando selecao de pacotes..." \
        "Pacotes selecionados:"
}

#---------- FUNCOES DE DOWNLOAD ----------#
_baixar_pacotes_vaievem() {
    cd "${DEFAULT_RECEBE_DIR}" || {
        _mensagec "${RED}" "Erro: Diretorio $DEFAULT_RECEBE_DIR nao encontrado"
        _aguardar 2
        return 1
    }
    _baixar_programas_vaievem
}

#---------- FUNCOES DE PROCESSAMENTO ----------#
_mover_arquivos_offline() {
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _mensagec "${GREEN}" "Arquivo encontrado: ${arquivo}"
        else
            _mensagec "${RED}" "Arquivo nao encontrado: ${arquivo}"
        fi
        _linha
    done
}

_processar_atualizacao_programas() {
    if [[ -z "${DEFAULT_RECEBE_DIR}" ]]; then
        _mensagec "${RED}" "ERRO: Diretorio $DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi
    if [[ -z "${DEFAULT_PROGS_DIR}" ]]; then
        _mensagec "${RED}" "ERRO: Diretorio $DEFAULT_PROGS_DIR nao configurado"
        return 1
    fi
    cd "${DEFAULT_RECEBE_DIR}" || return 1

    if ! _validar_diretorio_backups; then
        _mensagec "${RED}" "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi

    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${arquivo}" ]]; then
            _mensagec "${RED}" "Arquivo nao encontrado: ${arquivo}"
            return 0
        fi
    done

    for programa_idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_idx]}"
        local arquivo_backup="${DEFAULT_OLDS_DIR}/${programa}-anterior.zip"
        local backup_criado=0

        if [[ -f "$arquivo_backup" ]]; then
            if ! mv -f "$arquivo_backup" "${DEFAULT_OLDS_DIR}/${UMADATA}-${programa}-anterior.zip"; then
                _mensagec "${RED}" "ERRO: Falha ao arquivar backup anterior de ${programa}"
                return 1
            fi
        fi

        _mensagec "${YELLOW}" "Salvando programa antigo: ${programa}"
        if [[ -f "${E_EXEC}/${programa}.class" ]]; then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${E_EXEC}/${programa}"*.class >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _mensagec "${RED}" "ERRO: Falha ao fazer backup dos arquivos .class de ${programa}"
                return 1
            fi
        fi
        if [[ -f "${E_EXEC}/${programa}.int" ]]; then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${E_EXEC}/${programa}.int" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _mensagec "${RED}" "ERRO: Falha ao fazer backup dos arquivos .int de ${programa}"
                return 1
            fi
        fi
        if [[ -f "${T_TELAS}/${programa}.TEL" ]]; then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${T_TELAS}/${programa}.TEL" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _mensagec "${RED}" "ERRO: Falha ao fazer backup dos arquivos .TEL de ${programa}"
                return 1
            fi
        fi

        if (( backup_criado )); then
            if ! _validar_integridade_backup "$arquivo_backup"; then
                _mensagec "${RED}" "ERRO CRITICO: Backup criado mas invalido para ${programa}"
                return 1
            fi
            _mensagec "${GREEN}" "Backup validado com sucesso: ${programa}"
        fi
    done

    _linha
    _mensagec "${YELLOW}" "Backup dos programas efetuado"
    _linha
    _aguardar 1

    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}"; then
            _mensagec "${RED}" "Erro ao descompactar ${arquivo}"
            continue
        fi
    done

    # CORREÇÃO: Substituído compgen por glob seguro com nullglob
    for extensao in ".class" ".int" ".TEL"; do
        shopt -s nullglob
        local arquivos_encontrados=(*"${extensao}")
        shopt -u nullglob

        if (( ${#arquivos_encontrados[@]} > 0 )); then
            for arquivo in "${arquivos_encontrados[@]}"; do
                if [[ "${extensao}" == ".TEL" ]]; then
                    mv -f "${arquivo}" "${T_TELAS}/" >>"${LOG_ATU}" 2>&1
                else
                    mv -f "${arquivo}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1
                    if [[ ! -f "${E_EXEC}/${arquivo}" ]]; then
                        _log_erro "Falha ao mover ${arquivo} para ${E_EXEC}/"
                        echo "ERRO: Arquivo ${arquivo} nao encontrado no diretorio de destino" >&2
                        _mensagec "${RED}" "Arquivo ${arquivo} nao encontrado no diretorio de destino"
                        _mensagec "${YELLOW}" "Verifique o log de atualizacao em ${LOG_ATU} para mais detalhes."
                        _mensagec "${YELLOW}" "Use a opcao 4 de reversao para restaurar o programa anterior."
                    else
                        _log "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                        _mensagec "${GREEN}" "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                        _obter_data_arquivo "${arquivo}"
                    fi
                fi
            done
        fi
    done

    _linha
    _mensagec "${GREEN}" "Atualizando o(s) programa(s)..."
    _linha

    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${arquivo}" ]]; then
            local backup_file="${arquivo%.zip}.bkp"
            mv -f "${arquivo}" "${DEFAULT_PROGS_DIR}/${backup_file}"
        fi
    done
    _mensagec "${GREEN}" "Alterando extensao da atualizacao"
    _linha
    _mensagec "${YELLOW}" "Atualizacao concluida com sucesso!"
}

_processar_atualizacao_pacotes() {
    if [[ -z "${DEFAULT_RECEBE_DIR}" ]]; then
        _mensagec "${RED}" "ERRO: DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi
    cd "${DEFAULT_RECEBE_DIR}" || return 1

    if ! _validar_diretorio_backups; then
        _mensagec "${RED}" "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi

    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${arquivo}" ]]; then
            _mensagec "${RED}" "Arquivo nao encontrado: ${arquivo}"
            _aguardar 2
            return 0
        fi
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _mensagec "${RED}" "Erro ao descompactar ${arquivo}"
            _aguardar 2
            return 1
        fi
    done

    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${arquivo}" ]]; then
            local backup_file="${arquivo%.zip}.bkp"
            if ! mv -f "${arquivo}" "${DEFAULT_PROGS_DIR}/${backup_file}"; then
                _mensagec "${RED}" "ERRO: Falha ao arquivar pacote ${arquivo}"
                return 1
            fi
        fi
    done

    # CORREÇÃO: Loop seguro com -print0 e caminhos completos para mv
    while IFS= read -r -d '' classfile; do
        local progname
        progname="$(basename "$classfile" .class)"
        local dir_path
        dir_path="$(dirname "$classfile")"
        local arquivo_backup="${DEFAULT_OLDS_DIR}/${progname}-anterior.zip"

        if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then
            if ! find "${E_EXEC}" -name "${progname}*.class" -exec "${DEFAULT_ZIP}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.class"
                return 1
            fi
        else
            if ! find "${E_EXEC}" -name "${progname}*.int" -exec "${DEFAULT_ZIP}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.int"
                return 1
            fi
        fi

        if [[ -d "${T_TELAS}" ]] && find "${T_TELAS}" -maxdepth 1 -name "${progname}*.TEL" -print -quit | grep -q .; then
            if ! find "${T_TELAS}" -name "${progname}*.TEL" -exec "${DEFAULT_ZIP}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.TEL"
                return 1
            fi
        fi

        if [[ -f "${arquivo_backup}" ]]; then
            if ! _validar_integridade_backup "${arquivo_backup}"; then
                return 1
            fi
        fi

        # Move usando caminho completo retornado pelo find
        if ! mv -f "${classfile}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao mover ${classfile} para ${E_EXEC}"
            return 1
        fi

        # Move TELs do mesmo diretório extraído
        if [[ -d "${dir_path}" ]]; then
            shopt -s nullglob
            local tels=("${dir_path}/${progname}"*.TEL)
            shopt -u nullglob
            for tel in "${tels[@]}"; do
                mv -f "${tel}" "${T_TELAS}/" >>"${LOG_ATU}" 2>&1
            done
        fi
    done < <(find . -type f -name "*.class" -print0)
}

_processar_reversao_programas() {
    _criar_diretorio_seguro "${DEFAULT_RECEBE_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${DEFAULT_RECEBE_DIR}" >&2
        return 1
    }
    for programa_idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_idx]}"
        local arquivo_anterior="${DEFAULT_OLDS_DIR}/${programa}-anterior.zip"
        if [[ -f "$arquivo_anterior" ]]; then
            if ! _validar_integridade_backup "$arquivo_anterior"; then
                _mensagec "${RED}" "ERRO: Backup invalido ou corrompido para ${programa}. Reversao abortada."
                return 1
            fi
            if ! mv -f "$arquivo_anterior" "${DEFAULT_RECEBE_DIR}/${programa}${CLASS}.zip"; then
                _mensagec "${RED}" "ERRO: Falha ao preparar backup para reversao de ${programa}"
                return 1
            fi
            _mensagec "${GREEN}" "Backup validado e preparado para reversao: ${programa}"
        else
            _mensagec "${RED}" "Backup nao encontrado para: ${programa}"
            return 1
        fi
    done
    _processar_atualizacao_programas
}

#---------- FUNCOES AUXILIARES ----------#
_validar_diretorio_backups() {
    local caminho="${1:-${DEFAULT_OLDS_DIR}}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }
}

_validar_integridade_backup() {
    local arquivo_backup="$1"
    if [[ ! -f "${arquivo_backup}" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo de backup nao encontrado: ${arquivo_backup}"
        return 1
    fi
    local tamanho
    tamanho=$(stat -c%s "${arquivo_backup}" 2>/dev/null || true)
    if [[ -z "${tamanho}" || "${tamanho}" -lt 22 ]]; then
        tamanho="${tamanho:-0}"
        _mensagec "${RED}" "ERRO: Arquivo de backup corrompido (tamanho: ${tamanho} bytes): ${arquivo_backup}"
        return 1
    fi
    if ! "${DEFAULT_UNZIP}" -t "${arquivo_backup}" >/dev/null 2>&1; then
        _mensagec "${RED}" "ERRO: Arquivo de backup invalido ou corrompido: ${arquivo_backup}"
        return 1
    fi
    return 0
}

_obter_data_arquivo() {
    local arquivo="$1"
    if [[ -f "${E_EXEC}/${arquivo}" ]]; then
        local data_modificacao
        data_modificacao=$(stat -c %y "${E_EXEC}/${arquivo}" 2>/dev/null)
        if [[ -n "$data_modificacao" ]]; then
            local data_formatada
            data_formatada=$(date -d "$data_modificacao" +"%d/%m/%Y %H:%M:%S" 2>/dev/null)
            _mensagec "${GREEN}" "Nome do programa: ${arquivo}"
            _mensagec "${YELLOW}" "Data do programa: ${data_formatada}"
        fi
    fi
}

_mensagem_conclusao_reversao() {
    _linha
    _mensagec "${YELLOW}" "Volta do(s) Programa(s) Concluida(s)"
    _linha
    _press
    _linha
    printf "\n"
    if _confirmar "Deseja reverter mais algum programa?" "N"; then
        _reverter_programa
    fi
}