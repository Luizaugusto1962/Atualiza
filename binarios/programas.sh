#!/usr/bin/env bash
set -euo pipefail
#
# programas.sh - Modulo de Gestao de Programas
# Responsavel pela atualizacao, instalacao e reversao de programas
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 10/07/2026-01
#

# Variaveis globais esperadas
compilado="${compilado:-class}"                 # Sufixo para arquivos compilados
debugado="${debugado:-mclass}"                  # Sufixo para arquivos em depuração
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"    # Diretorio de recebimento de arquivos
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip) 
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)
#---------- VARIaVEIS GLOBAIS DO MODULO ----------#
# Arrays para armazenar programas e arquivos
declare -g ARQUIVO_COMPILADO_ATUAL=""
declare -a PROGRAMAS_SELECIONADOS=()
declare -a ARQUIVOS_PROGRAMA=()

#---------- FUNCOES DE ATUALIZACAO ONLINE ----------#

# Atualizacao de programas via conexao online
_atualizar_programa_online() {
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then    
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            _linha
            _aviso "Parametro do servidor OFF ativo"
            _linha
            _aguardar_tecla
            return 0
        fi
    fi
    
    # Solicitar programas a serem atualizados
    _solicitar_programas_atualizacao
    
    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${AMARELO}" "Nenhum programa selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi
    
    # Baixar programas via vaievem
    if ! _baixar_programas_vaievem; then
        _erro "Falha ao baixar programas"
        _linha
        _aguardar_tecla
        return 1
    fi
    
    # Atualizar programas baixados
    if ! _processar_atualizacao_programas; then
        _erro "Falha ao processar atualizacao"
        _linha
        _aguardar_tecla
        return 1
    fi
    
    _linha
    _aguardar_tecla
}

# Atualizacao de programas via arquivos offline
_atualizar_programa_offline() {

    # Traz arquivos da pasta /portalsav/Atualiza para receber.    
    _enviabackup_para_receber || true

    # Solicitar programas a serem atualizados
    _solicitar_programas_atualizacao
    

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${AMARELO}" "Nenhum programa selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi
    
    _linha
    _mensagec "${AMARELO}" "Os programas devem estar no diretorio ${NORMAL}${DEFAULT_RECEBE_DIR}"
    _linha
    _aguardar 0
    

    # Mover arquivos do servidor offline se configurado
    if ! _mover_arquivos_offline; then
        _mensagec "${VERMELHO}" "Arquivo(s) nao encontrado(s) no diretorio offline"
        _linha
        _aguardar_tecla
        return 1
    fi
    
    # Atualizar programas
    if ! _processar_atualizacao_programas; then
        _erro "Falha ao processar atualizacao"
        _linha
        _aguardar_tecla
        return 1
    fi
    
    _linha
    _aguardar_tecla
}

# Atualizacao de programas em pacotes
_atualizar_programa_pacote() {

    # Traz arquivos da pasta /portalsav/Atualiza para receber.    
    _enviabackup_para_receber || true

    _solicitar_pacotes_atualizacao

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${AMARELO}" "Nenhum pacote selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi

    if [[ "${CFG_OFFLINE}" == "s" ]]; then
        _linha
        _mensagec "${AMARELO}" "Parametro do servidor OFF ativo"
        if ! _mover_arquivos_offline; then
            _mensagec "${VERMELHO}" "Pacote(s) nao encontrado(s) no diretorio offline"
            _linha
            _aguardar_tecla
            return 1
        fi
    else
        if ! _baixar_pacotes_vaievem; then
            _erro "Falha ao baixar pacotes"
            _linha
            _aguardar_tecla
            return 1
        fi
    fi

    if ! _processar_atualizacao_pacotes; then
        _erro "Falha ao processar atualizacao dos pacotes"
        _linha
        _aguardar_tecla
        return 1
    fi

    _linha
    _aguardar_tecla
    return 0
}

#---------- FUNCOES DE REVERSaO ----------#

# Seleciona programas disponiveis para reversao (backups *-anterior.zip)
# Popula as variaveis globais PROGRAMAS_SELECIONADOS e ARQUIVOS_PROGRAMA
_selecionar_programas_reversao() {
    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()

    if [[ ! -d "${DEFAULT_OLDS_DIR}" ]]; then
        _erro "Diretorio de backups nao encontrado: ${DEFAULT_OLDS_DIR}"
        _aguardar_tecla
        return 0
    fi

    shopt -s nullglob
    local backups=("${DEFAULT_OLDS_DIR}"/*-anterior.zip)
    shopt -u nullglob

    if (( ${#backups[@]} == 0 )); then
        _aviso "Nenhum backup de programa encontrado em ${DEFAULT_OLDS_DIR}"
        _aguardar_tecla
        return 0
    fi

    local programas=()
    for arquivo in "${backups[@]}"; do
        programas+=("$(basename "${arquivo}" "-anterior.zip")")
    done

    _linha
    _mensagec "${CIANO}" "Backups disponiveis para reversao:"
    _linha

    local idx=1
    for programa in "${programas[@]}"; do
        _mensagec "${VERDE}" "${idx}) ${programa}"
        ((idx++)) || true
    done

    _linha
    _mensagec "${AMARELO}" "Digite o(s) numero(s) do(s) programa(s) a reverter (ex: 1 2 3) ou 0 para sair:"

    local escolha
    while true; do
        read -rp "${AMARELO}Opcao -> ${NORMAL}" escolha
        _linha

        # Tratar cancelamento
        if [[ -z "${escolha}" || "${escolha}" == "0" ]]; then
            _aviso "Operacao cancelada."
            return 1
        fi

        # Permitir lista separada por espacos e virgulas
        escolha="${escolha//,/ }"

        local -a indices=()
        local invalido=0
        # Omitimos as aspas intencionalmente aqui para permitir word splitting na variavel $escolha,
        # o que permite o usuario digitar multiplos numeros separados por espaco (ex: "1 2 3").
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
            _erro "Opcao invalida. Informe numero(s) entre 1 e ${#programas[@]}."
            continue
        fi

        # Remover duplicatas mantendo a ordem
        local -A seen=()
        for token in "${indices[@]}"; do
            if [[ -n "${seen[$token]:-}" ]]; then
                continue
            fi
            seen[$token]=1
            local programa_selecionado="${programas[$((token-1))]}"
            PROGRAMAS_SELECIONADOS+=("${programa_selecionado}")
            ARQUIVOS_PROGRAMA+=("${programa_selecionado}${compilado}.zip")
        done

        break
    done

    return 0
}

# Reverter programas para versao anterior
_reverter_programa() {
    if _selecionar_programas_reversao; then
        if _processar_reversao_programas; then
            _mensagem_conclusao_reversao
        else
            _mensagec "${VERMELHO}" "Falha ao processar reversao dos programas"
            _linha
            _aguardar_tecla
        fi
    else
        _mensagec "${VERMELHO}" "Nenhum programa foi selecionado para reversao"
        _linha
        _aguardar_tecla
    fi
}

#---------- FUNCOES DE SOLICITACAO DE DADOS ----------#

# Solicita tipo de compilacao e define o nome do artefato selecionado
_resolver_arquivo_compilado() {
    local nome_item="$1"
    local tipo_compilacao

    _mensagec "${VERMELHO}" "Informe o tipo de compilacao (1 - Normal, 2 - Depuracao):"
    _linha

    read -rp "${AMARELO}Tipo de compilacao: ${NORMAL}" -n1 tipo_compilacao
    printf "\n"

    if [[ "$tipo_compilacao" == "1" ]]; then
        ARQUIVO_COMPILADO_ATUAL="${nome_item}${compilado}.zip"
    elif [[ "$tipo_compilacao" == "2" ]]; then
        ARQUIVO_COMPILADO_ATUAL="${nome_item}${debugado}.zip"
    else
        return 1
    fi
}

# Seleciona programas para atualizacao
# Parametros: $1=rotulo_item $2=mensagem_item $3=mensagem_final $4=mensagem_lista
_coletar_artefatos_atualizacao() {
    local rotulo_item="$1"
    local mensagem_item="$2"
    local mensagem_final="$3"
    local mensagem_lista="$4"
    local max_repeticoes=6
    local contador=0
    local item
    local arquivo_compilado

    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()

    for ((contador = 1; contador <= max_repeticoes; contador++)); do
        _meio_da_tela
        _mensagec "${VERMELHO}" "$mensagem_item"
        _linha

        read -rp "${AMARELO}Nome do ${rotulo_item} (ENTER para finalizar): ${NORMAL}" item
        _linha

        if [[ -z "${item}" ]]; then
            if (( ${#PROGRAMAS_SELECIONADOS[@]} > 0 )); then
                _mensagec "${CIANO}" "Programas informados:"
                for idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
                    local prog="${PROGRAMAS_SELECIONADOS[$idx]}"
                    local arq="${ARQUIVOS_PROGRAMA[$idx]}"
                    if [[ "$arq" == *"${debugado}"* ]]; then
                        _mensagec "${VERDE}" "  -> ${prog} - Depuracao"
                    else
                        _mensagec "${VERDE}" "  -> ${prog} - Normal"
                    fi
                done
                _linha
                if ! _confirmar "${BRANCO} Confirma a selecao do(s) programa(s) acima?" "S"; then
                    PROGRAMAS_SELECIONADOS=()
                    ARQUIVOS_PROGRAMA=()
                    _mensagec "${AMARELO}" "Selecao cancelada."
                    _linha
                fi
            else
                _mensagec "${AMARELO}" "$mensagem_final"
            fi
            _linha
            break
        fi

        if ! _validar_nome_programa "$item"; then
            _erro "Nome invalido. Use apenas letras maiusculas e numeros."
            continue
        fi

        if ! _resolver_arquivo_compilado "$item"; then
            _mensagec "${VERMELHO}" "Erro: Opcao invalida. Digite 1 ou 2."
            continue
        fi

        arquivo_compilado="${ARQUIVO_COMPILADO_ATUAL}"
        PROGRAMAS_SELECIONADOS+=("$item")
        ARQUIVOS_PROGRAMA+=("$arquivo_compilado")

        _linha
        _mensagec "${VERDE}" "${rotulo_item^} adicionado: ${arquivo_compilado}"
        _linha
        _aguardar_tecla

        if [[ -n "$mensagem_lista" ]]; then
            _mensagec "${AMARELO}" "$mensagem_lista"
            for prog in "${PROGRAMAS_SELECIONADOS[@]}"; do
                _mensagec "${VERDE}" "  - $prog"
            done
        fi
    done
}

# Solicita programas para atualizacao
_solicitar_programas_atualizacao() {
    _coletar_artefatos_atualizacao \
        "programa" \
        "Informe o nome do programa a ser atualizado da versao do sistema ${CFG_VERSAOCLASS}" \
        "Finalizando selecao de programas..." \
        "Programas selecionados:"
}

# Solicita pacotes para atualizacao
_solicitar_pacotes_atualizacao() {
    _coletar_artefatos_atualizacao \
        "pacote" \
        "Informe o nome do pacote da versao do sistema ${CFG_VERSAOCLASS}" \
        "Finalizando selecao de pacotes..." \
        "Pacotes selecionados:"
}

#---------- FUNCOES DE DOWNLOAD ----------#
# Baixa pacotes para diretorio especifico
_baixar_pacotes_vaievem() {
    cd "${DEFAULT_RECEBE_DIR}" || {
        _erro "Erro: Diretorio $DEFAULT_RECEBE_DIR nao encontrado"
        _aguardar 2
        return 1
    }
    _baixar_programas_vaievem
}

#---------- FUNCOES DE PROCESSAMENTO ----------#

# Move arquivos do servidor offline
_mover_arquivos_offline() {
    local todos_encontrados=0
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _mensagec "${VERDE}" "Arquivo encontrado: ${arquivo}"
        else
            _erro "Arquivo nao encontrado: ${arquivo}"
            todos_encontrados=1
        fi
        _linha
    done
    return "${todos_encontrados}"
}

# Processa atualizacao dos programas
_processar_atualizacao_programas() {
    # Validar configuracoes basicas antes de qualquer operacao
    if [[ -z "${DEFAULT_RECEBE_DIR}" ]]; then
        _erro "ERRO: DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi

    if [[ -z "${DEFAULT_PROGS_DIR}" ]]; then
        _erro "ERRO: DEFAULT_PROGS_DIR nao configurado"
        return 1
    fi

    # SEGURANCA: Validar diretorio de backups antes de qualquer operacao
    if ! _validar_diretorio_backups; then
        _erro "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi

    # Verificar se arquivos existem no diretorio de recebimento
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _erro "Arquivo nao encontrado: ${DEFAULT_RECEBE_DIR}/${arquivo}"
            return 1
        fi
    done

    # Criar diretorio temporario isolado para extracao
    local temp_update
    temp_update="${DEFAULT_RECEBE_DIR}/tmp_update_$$"
    if ! _criar_diretorio_seguro "${temp_update}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _erro "Falha ao criar diretorio temporario %s\n" "${temp_update}" >&2
        return 1
    fi

    # Mover arquivos para o diretorio temporario e acessa-lo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! mv -f "${DEFAULT_RECEBE_DIR}/${arquivo}" "${temp_update}/"; then
            _erro "ERRO: Falha ao mover ${arquivo} para diretorio temporario"
            rm -rf "${temp_update}"
            return 1
        fi
    done

    cd "${temp_update}" || {
        rm -rf "${temp_update}"
        return 1
    }

    local arquivo
    local programa_idx=0

    # Criar backup dos programas antigos
    for programa_idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_idx]}"
        local arquivo_backup="${DEFAULT_OLDS_DIR}/${programa}-anterior.zip"
        local backup_criado=0

        # Verificar se ja existe backup e fazer rotacao com data e hora
        if [[ -f "$arquivo_backup" ]]; then
            local timestamp
            timestamp=$(date +"%Y%m%d_%H%M%S")
            if ! mv -f "$arquivo_backup" "${DEFAULT_OLDS_DIR}/${timestamp}-${programa}-anterior.zip"; then
                _erro "ERRO: Falha ao arquivar backup anterior de ${programa}"
                rm -rf "${temp_update}"
                return 1
            fi
        fi

        _mensagec "${AMARELO}" "Salvando programa antigo: ${programa}"

        # Backup de arquivos .class (qualquer variante do nome)
        shopt -s nullglob
        local class_files=("${E_EXEC}/${programa}"*.class)
        shopt -u nullglob
        if (( ${#class_files[@]} > 0 )); then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${class_files[@]}" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _erro "Falha ao fazer backup dos arquivos .class de ${programa}"
                rm -rf "${temp_update}"
                return 1
            fi
        fi

        # Backup de arquivos .TEL (qualquer variante do nome)
        shopt -s nullglob
        local tel_files=("${T_TELAS}/${programa}"*.TEL)
        shopt -u nullglob
        if (( ${#tel_files[@]} > 0 )); then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${tel_files[@]}" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _erro "Falha ao fazer backup dos arquivos .TEL de ${programa}"
                rm -rf "${temp_update}"
                return 1
            fi
        fi

        # SEGURANCA: Validar integridade do backup criado
        if (( backup_criado )); then
            if ! _validar_integridade_backup "$arquivo_backup"; then
                _erro "CRITICO: Backup criado mas invalido para ${programa}"
                rm -rf "${temp_update}"
                return 1
            fi
            _mensagec "${VERDE}" "Backup validado com sucesso: ${programa}"
        fi
    done

    _linha
    _aviso "Backup dos programas efetuado"
    _linha
    _aguardar 1

    # Descompactar e atualizar programas
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _erro "ao descompactar ${arquivo}"
            rm -rf "${temp_update}"
            return 1
        fi
    done

    # Mover arquivos para diretorios corretos
    for extensao in ".class" ".int" ".TEL"; do
        shopt -s nullglob
        local arquivos_encontrados=(*"${extensao}")
        shopt -u nullglob

        if (( ${#arquivos_encontrados[@]} > 0 )); then
            for arquivo in "${arquivos_encontrados[@]}"; do
                if [[ "${extensao}" == ".TEL" ]]; then
                    if ! mv -f "${arquivo}" "${T_TELAS}/" >>"${LOG_ATU}" 2>&1; then
                        _log_erro "Falha ao mover ${arquivo} para ${T_TELAS}/"
                        _erro "Falha ao mover ${arquivo} para ${T_TELAS}/"
                    else
                        _mensagec "${VERDE}" "Arquivo ${arquivo} movido com sucesso para ${T_TELAS}/"
                    fi
                else
                    if ! mv -f "${arquivo}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1; then
                        _log_erro "Falha ao mover ${arquivo} para ${E_EXEC}/"
                        _erro "Falha ao mover ${arquivo} para ${E_EXEC}/"
                        _mensagec "${AMARELO}" "Verifique o log de atualizacao em ${LOG_ATU} para mais detalhes."
                        _mensagec "${AMARELO}" "Use a opcao 4 de reversao para restaurar o programa anterior."
                    else
                        _log "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                        _mensagec "${VERDE}" "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                        _obter_data_arquivo "${arquivo}"
                    fi
                fi
            done
        fi
    done

    _linha
    _ok "Atualizando o(s) programa(s)..."
    _linha

    # Mover arquivos .zip para .bkp em DEFAULT_PROGS_DIR
    if [[ ! -d "${DEFAULT_PROGS_DIR}" ]]; then
        _criar_diretorio_seguro "${DEFAULT_PROGS_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
            _erro "Falha ao criar diretorio de programas %s\n" "${DEFAULT_PROGS_DIR}" >&2
            rm -rf "${temp_update}"
            return 1
        }
    fi
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        local backup_file="${arquivo%.zip}.bkp"
        if ! mv -f "${arquivo}" "${DEFAULT_PROGS_DIR}/${backup_file}" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao arquivar ${arquivo} em ${DEFAULT_PROGS_DIR}/${backup_file}"
        fi
    done

    # Limpar diretorio temporario
    cd "${DEFAULT_RECEBE_DIR}" || true
    rm -rf "${temp_update}"

    _mensagec "${VERDE}" "Alterando extensao da atualizacao"
    _linha
    _mensagec "${AMARELO}" "Atualizacao concluida com sucesso!"
}

# Processa atualizacao de pacotes
_processar_atualizacao_pacotes() {
    if [[ -z "${DEFAULT_RECEBE_DIR}" ]]; then
        _erro "DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi

    # SEGURANCA: Validar diretorio de backups
    if ! _validar_diretorio_backups; then
        _mensagec "${VERMELHO}" "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi

    # Verificar se arquivos existem no diretorio de recebimento
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _erro "Arquivo nao encontrado: ${DEFAULT_RECEBE_DIR}/${arquivo}"
            return 1
        fi
    done

    # Criar diretorio temporario isolado para extracao
    local temp_update
    temp_update="${DEFAULT_RECEBE_DIR}/tmp_update_$$"
    if ! _criar_diretorio_seguro "${temp_update}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _erro "Falha ao criar diretorio temporario %s\n" "${temp_update}" >&2
        return 1
    fi

    # Mover pacotes para o diretorio temporario e acessa-lo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! mv -f "${DEFAULT_RECEBE_DIR}/${arquivo}" "${temp_update}/"; then
            _erro "Falha ao mover ${arquivo} para diretorio temporario"
            rm -rf "${temp_update}"
            return 1
        fi
    done

    cd "${temp_update}" || {
        rm -rf "${temp_update}"
        return 1
    }

    # Descompactar pacotes
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _erro "ao descompactar ${arquivo}"
            rm -rf "${temp_update}"
            return 1
        fi
    done

    # Mover arquivos .zip para .bkp em DEFAULT_PROGS_DIR
    if [[ ! -d "${DEFAULT_PROGS_DIR}" ]]; then
        _criar_diretorio_seguro "${DEFAULT_PROGS_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
            _erro "Falha ao criar diretorio de programas %s\n" "${DEFAULT_PROGS_DIR}" >&2
            rm -rf "${temp_update}"
            return 1
        }
    fi
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        local backup_file="${arquivo%.zip}.bkp"
        if ! mv -f "${arquivo}" "${DEFAULT_PROGS_DIR}/${backup_file}" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao arquivar pacote ${arquivo} em ${DEFAULT_PROGS_DIR}/${backup_file}"
        fi
    done

    # Processar arquivos .class encontrados
    while IFS= read -r -d '' classfile; do
        local progname
        progname="$(basename "$classfile" .class)"
        local dir_path
        dir_path="$(dirname "$classfile")"
        local arquivo_backup="${DEFAULT_OLDS_DIR}/${progname}-anterior.zip"

        # Backup dos arquivos class antigos
        if ! "${DEFAULT_FIND}" "${E_EXEC}" -maxdepth 1 -name "${progname}*.class" -exec "${DEFAULT_ZIP}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
            _log_erro "Falha ao fazer backup de ${progname}*.class"
            rm -rf "${temp_update}"
            return 1
        fi

        # Backup de arquivos .TEL se existirem
        shopt -s nullglob
        local tel_existing=("${T_TELAS}/${progname}"*.TEL)
        shopt -u nullglob
        if (( ${#tel_existing[@]} > 0 )); then
            if ! "${DEFAULT_FIND}" "${T_TELAS}" -maxdepth 1 -name "${progname}*.TEL" -exec "${DEFAULT_ZIP}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.TEL"
                rm -rf "${temp_update}"
                return 1
            fi
        fi

        # SEGURANCA: Validar integridade do backup antes de continuar
        if [[ -f "${arquivo_backup}" ]]; then
            if ! _validar_integridade_backup "${arquivo_backup}"; then
                rm -rf "${temp_update}"
                return 1
            fi
        fi

        # Mover novos arquivos
        if ! mv -f "${classfile}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao mover ${classfile} para ${E_EXEC}"
            rm -rf "${temp_update}"
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
    done < <("${DEFAULT_FIND}" . -type f -name "*.class" -print0)

    # Limpar diretorio temporario
    cd "${DEFAULT_RECEBE_DIR}" || true
    rm -rf "${temp_update}"
}

# Processa reversao de programas
_processar_reversao_programas() {
    _criar_diretorio_seguro "${DEFAULT_RECEBE_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s\n" "${DEFAULT_RECEBE_DIR}" >&2
        return 1
    }

    for programa_idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_idx]}"
        local arquivo_anterior="${DEFAULT_OLDS_DIR}/${programa}-anterior.zip"
        
        if [[ -f "$arquivo_anterior" ]]; then
            # SEGURANCA: Validar integridade do backup antes de reverter
            if ! _validar_integridade_backup "$arquivo_anterior"; then
                _erro "Backup invalido ou corrompido para ${programa}. Reversao abortada."
                return 1
            fi

            if ! mv -f "$arquivo_anterior" "${DEFAULT_RECEBE_DIR}/${programa}${compilado}.zip"; then
                _erro "Falha ao preparar backup para reversao de ${programa}"
                return 1
            fi
            _mensagec "${VERDE}" "Backup validado e preparado para reversao: ${programa}"
        else
            _erro "Backup nao encontrado para: ${programa}"
            return 1
        fi
    done

    # Processar atualizacao com os arquivos revertidos
    if ! _processar_atualizacao_programas; then
        _erro "Falha ao processar reversao dos programas"
        return 1
    fi
}

#---------- FUNCOES AUXILIARES ----------#

# Valida e cria diretorio de backups se nao existir
_validar_diretorio_backups() {
        local caminho="${1:-${DEFAULT_OLDS_DIR}}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }
}

# Valida integridade de arquivo de backup
_validar_integridade_backup() {
    local arquivo_backup="$1"

    # Verificar se arquivo existe
    if [[ ! -f "${arquivo_backup}" ]]; then
        _erro "Arquivo de backup nao encontrado: ${arquivo_backup}"
        return 1
    fi

    # Verificar tamanho minimo (arquivo zip deve ter pelo menos 22 bytes)
    local tamanho
    tamanho=$(stat -c%s "${arquivo_backup}" 2>/dev/null || true)
    if [[ -z "${tamanho}" || "${tamanho}" -lt 22 ]]; then
        tamanho="${tamanho:-0}"
        _erro "Arquivo de backup corrompido (tamanho: ${tamanho} bytes): ${arquivo_backup}"
        return 1
    fi

    # Testar integridade do arquivo zip
    if ! "${DEFAULT_UNZIP}" -t "${arquivo_backup}" >/dev/null 2>&1; then
        _erro "Arquivo de backup invalido ou corrompido: ${arquivo_backup}"
        return 1
    fi

    return 0
}

# Obtem data de modificacao do arquivo
_obter_data_arquivo() {
    local arquivo="$1" # Nome do arquivo
    if [[ -f "${E_EXEC}/${arquivo}" ]]; then
        local data_modificacao
        data_modificacao=$(stat -c %y "${E_EXEC}/${arquivo}" 2>/dev/null)
        if [[ -n "$data_modificacao" ]]; then
            local data_formatada
            data_formatada=$(date -d "$data_modificacao" +"%d/%m/%Y %H:%M:%S" 2>/dev/null)
            _mensagec "${VERDE}" "Nome do programa: ${arquivo}"
            _mensagec "${AMARELO}" "Data do programa: ${data_formatada}"
        fi
    fi
}

# Mensagem de conclusao da reversao
_mensagem_conclusao_reversao() {
    _linha
    _aviso "Volta do(s) Programa(s) Concluida(s)"
    _linha
    _aguardar_tecla
    _linha
    # Perguntar se deseja reverter mais programas
    printf "\n"
    if _confirmar "Deseja reverter mais algum programa?" "N"; then
        _reverter_programa
    fi
}
