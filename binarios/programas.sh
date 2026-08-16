#!/usr/bin/env bash
set -euo pipefail
#
# programas.sh - Modulo de Gestao de Programas
# Responsavel pela atualizacao, instalacao e reversao de programas
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 14/08/2026-02
#

# Variaveis globais esperadas
compilado="${compilado:-class}"                 # Sufixo para arquivos compilados
debugado="${debugado:-mclass}"                  # Sufixo para arquivos em depuração
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"    # Diretorio de recebimento de arquivos
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip)
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)
#---------- VARIaVEIS GLOBAIS DO MODULO ----------#
# Arrays para armazenar programas e arquivos
declare -g arquivo_compilado_atual=""
declare -a PROGRAMAS_SELECIONADOS=()
declare -a ARQUIVOS_PROGRAMA=()

#---------- FUNCOES DE ATUALIZACAO ONLINE ----------#

# Atualizacao de programas via conexao online
_atualizar_programa_online() {
    if [[ -n "${CFG_OFFLINE:-}" && "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
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
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum programa selecionado"
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
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum programa selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Os programas devem estar no diretorio ${NORMAL}${DEFAULT_RECEBE_DIR}"
    _linha
    _aguardar 0


    # Verificar arquivos do servidor offline se configurado
    if ! _verificar_arquivos_offline; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Arquivo(s) nao encontrado(s) no diretorio offline"
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
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum pacote selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi

    if [[ -n "${CFG_OFFLINE:-}" && "${CFG_OFFLINE}" == "s" ]]; then
        _linha
        _exibir_mensagem_centralizada "${AMARELO}" "Parametro do servidor OFF ativo"
        if ! _verificar_arquivos_offline; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Pacote(s) nao encontrado(s) no diretorio offline"
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
        return 1
    fi

    shopt -s nullglob
    local backups=("${DEFAULT_OLDS_DIR}"/*-anterior.zip)
    shopt -u nullglob

    if (( ${#backups[@]} == 0 )); then
        _aviso "Nenhum backup de programa encontrado em ${DEFAULT_OLDS_DIR}"
        _aguardar_tecla
        return 1
    fi

    local programas=()
    local arquivo
    for arquivo in "${backups[@]}"; do
        # Ignorar backups rotacionados (prefixo de timestamp AAAAMMDD_HHMMSS-)
        local nome_base
        nome_base="$(basename "${arquivo}")"
        if [[ "${nome_base}" =~ ^[0-9]{8}_[0-9]{6}-.*-anterior\.zip$ ]]; then
            continue
        fi
        programas+=("${nome_base%-anterior.zip}")
    done

    if (( ${#programas[@]} == 0 )); then
        _aviso "Nenhum backup de programa atual encontrado (apenas backups rotacionados) em ${DEFAULT_OLDS_DIR}"
        _aguardar_tecla
        return 1
    fi

    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Backups disponiveis para reversao:"
    _linha

    local indice=1
    local programa
    for programa in "${programas[@]}"; do
        _exibir_mensagem_centralizada "${VERDE}" "${indice}) ${programa}"
        ((indice++)) || true
    done

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Digite o(s) numero(s) do(s) programa(s) a reverter (ex: 1 2 3) ou 0 para sair:"

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
        # ponytail: desativar glob temporariamente para evitar expansao de * e ? em ${escolha}
        set -f
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
        set +f  # ponytail: reativar glob depois do loop seguro

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
    # Loop para permitir reverter multiplos programas sem recursao
    while true; do
        if ! _selecionar_programas_reversao; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum programa foi selecionado para reversao"
            _linha
            _aguardar_tecla
            return 1
        fi

        if ! _processar_reversao_programas; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Falha ao processar reversao dos programas"
            _linha
            _aguardar_tecla
            return 1
        fi

        if ! _mensagem_conclusao_reversao; then
            return 0
        fi
    done
}

#---------- FUNCOES DE SOLICITACAO DE DADOS ----------#

# Solicita tipo de compilacao e define o nome do artefato selecionado
_resolver_arquivo_compilado() {
    local nome_item="$1"
    local tipo_compilacao

    if [[ -z "${nome_item}" ]]; then
        _erro "Nome do item vazio"
        return 1
    fi

    _exibir_mensagem_centralizada "${VERMELHO}" "Informe o tipo de compilacao (1 - Normal, 2 - Depuracao):"
    _linha

    read -rp "${AMARELO}Tipo de compilacao: ${NORMAL}" tipo_compilacao

    if [[ "$tipo_compilacao" == "1" ]]; then
        arquivo_compilado_atual="${nome_item}${compilado}.zip"
    elif [[ "$tipo_compilacao" == "2" ]]; then
        arquivo_compilado_atual="${nome_item}${debugado}.zip"
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
    local max_repeticoes="${MAX_PROGRAMAS_SELECIONADOS:-6}"
    local contador=0
    local item
    local arquivo_compilado
    local saiu_por_enter=0

    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()

    # Exibe a lista de selecionados e solicita confirmacao
    _confirmar_selecao_artefatos() {
        if (( ${#PROGRAMAS_SELECIONADOS[@]} > 0 )); then
            _exibir_mensagem_centralizada "${CIANO}" "Programas informados:"
            local indice prog arq
            for indice in "${!PROGRAMAS_SELECIONADOS[@]}"; do
                prog="${PROGRAMAS_SELECIONADOS[$indice]}"
                arq="${ARQUIVOS_PROGRAMA[$indice]}"
                if [[ "$arq" == *"${debugado}"* ]]; then
                    _exibir_mensagem_centralizada "${VERDE}" "  -> ${prog} - Depuracao"
                else
                    _exibir_mensagem_centralizada "${VERDE}" "  -> ${prog} - Normal"
                fi
            done
            _linha
            if ! _confirmar "${BRANCO} Confirma a selecao do(s) programa(s) acima?" "S"; then
                PROGRAMAS_SELECIONADOS=()
                ARQUIVOS_PROGRAMA=()
                _exibir_mensagem_centralizada "${AMARELO}" "Selecao cancelada."
                _linha
            fi
        else
            _exibir_mensagem_centralizada "${AMARELO}" "$mensagem_final"
        fi
        _linha
    }

    for ((contador = 1; contador <= max_repeticoes; contador++)); do
        _meio_da_tela
        _exibir_mensagem_centralizada "${VERMELHO}" "$mensagem_item"
        _linha

        read -rp "${AMARELO}Nome do ${rotulo_item} (ENTER para finalizar): ${NORMAL}" item
        _linha

        if [[ -z "${item}" ]]; then
            _confirmar_selecao_artefatos
            saiu_por_enter=1
            break
        fi

        if ! _validar_nome_programa "$item"; then
            _erro "Nome invalido. Use apenas letras maiusculas, numeros e underscore."
            continue
        fi

        if ! _resolver_arquivo_compilado "$item"; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Erro: Opcao invalida. Digite 1 ou 2."
            continue
        fi

        arquivo_compilado="${arquivo_compilado_atual}"
        PROGRAMAS_SELECIONADOS+=("$item")
        ARQUIVOS_PROGRAMA+=("$arquivo_compilado")

        _linha
        _exibir_mensagem_centralizada "${VERDE}" "${rotulo_item^} adicionado: ${arquivo_compilado}"
        _linha
        _aguardar_tecla

        if [[ -n "$mensagem_lista" ]]; then
            _exibir_mensagem_centralizada "${AMARELO}" "$mensagem_lista"
            local prog
            for prog in "${PROGRAMAS_SELECIONADOS[@]}"; do
                _exibir_mensagem_centralizada "${VERDE}" "  - $prog"
            done
        fi
    done

    # Se o limite foi atingido sem o usuario finalizar, confirmar a selecao acumulada
    if (( saiu_por_enter == 0 )); then
        _exibir_mensagem_centralizada "${AMARELO}" "Limite de ${max_repeticoes} ${rotulo_item}s atingido."
        _confirmar_selecao_artefatos
    fi
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
    (
        cd "${DEFAULT_RECEBE_DIR}" || {
            _erro "Erro: Diretorio ${DEFAULT_RECEBE_DIR} nao encontrado"
            _aguardar 2
            exit 1
        }
        _baixar_programas_vaievem
    )
}

#---------- FUNCOES DE PROCESSAMENTO ----------#

# Verifica se arquivos existem no diretorio de recebimento (modo offline)
# Retorna: 0 se todos encontrados, 1 se algum faltar
_verificar_arquivos_offline() {
    local erros_encontrados=0
    local arquivo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo encontrado: ${arquivo}"
        else
            _erro "Arquivo nao encontrado: ${arquivo}"
            erros_encontrados=1
        fi
        _linha
    done
    return "${erros_encontrados}"
}

# Valida pre-requisitos comuns antes de qualquer atualizacao
# Retorna: 0 se valido, 1 se erro
_validar_pre_requisitos_atualizacao() {
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

    # SEGURANCA: Garantir alinhamento entre programas e arquivos selecionados
    if (( ${#PROGRAMAS_SELECIONADOS[@]} != ${#ARQUIVOS_PROGRAMA[@]} )); then
        _erro "ERRO: Inconsistencia entre programas e arquivos selecionados"
        return 1
    fi

    # Verificar espaco em disco antes de operacoes de extracao
    if command -v _verificar_espaco_disco >/dev/null 2>&1; then
        if ! _verificar_espaco_disco "${DEFAULT_RECEBE_DIR}"; then
            _erro "ERRO: Espaco em disco insuficiente em ${DEFAULT_RECEBE_DIR}"
            return 1
        fi
    fi

    # Verificar se arquivos existem no diretorio de recebimento
    local arquivo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _erro "Arquivo nao encontrado: ${DEFAULT_RECEBE_DIR}/${arquivo}"
            return 1
        fi
    done

    return 0
}

# Processa atualizacao dos programas
_processar_atualizacao_programas() {
    # Validar pre-requisitos comuns (diretorios, backups, arquivos, espaco em disco)
    if ! _validar_pre_requisitos_atualizacao; then
        return 1
    fi

    # Criar diretorio temporario para extracao
    local dir_temp_atualizacao="${DEFAULT_RECEBE_DIR}/dir_temp_atualizacao"
    rm -rf "${dir_temp_atualizacao}" 2>/dev/null || true
    if ! _criar_diretorio_seguro "${dir_temp_atualizacao}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _erro "Falha ao criar diretorio temporario ${dir_temp_atualizacao}" >&2
        return 1
    fi

    # Mover arquivos para o diretorio temporario e acessa-lo
    local arquivo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! mv -f "${DEFAULT_RECEBE_DIR}/${arquivo}" "${dir_temp_atualizacao}/"; then
            _erro "ERRO: Falha ao mover ${arquivo} para diretorio temporario"
            rm -rf "${dir_temp_atualizacao}"
            return 1
        fi
    done

    if ! cd "${dir_temp_atualizacao}"; then
        _erro "ERRO: Falha ao acessar diretorio temporario"
        rm -rf "${dir_temp_atualizacao}"
        return 1
    fi

    local programa_indice=0

    # Criar backup dos programas antigos
    for programa_indice in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_indice]}"
        local arquivo_backup="${DEFAULT_OLDS_DIR}/${programa}-anterior.zip"
        local backup_criado=0

        # Verificar se ja existe backup e fazer rotacao com data e hora
        if [[ -f "$arquivo_backup" ]]; then
            local timestamp
            timestamp=$(date +"%Y%m%d_%H%M%S")
            if ! mv -f "$arquivo_backup" "${DEFAULT_OLDS_DIR}/${timestamp}-${programa}-anterior.zip"; then
                _erro "ERRO: Falha ao arquivar backup anterior de ${programa}"
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
        fi

        _exibir_mensagem_centralizada "${AMARELO}" "Salvando programa antigo: ${programa}"

        # Backup de arquivos .class (nome exato ou variante com underscore)
        local class_files=()
        if [[ -f "${E_EXEC}/${programa}.${EXTENSAO_CLASS}" ]]; then
            class_files+=("${E_EXEC}/${programa}.${EXTENSAO_CLASS}")
        fi
        shopt -s nullglob
        for f in "${E_EXEC}/${programa}_"*."${EXTENSAO_CLASS}"; do
            class_files+=("$f")
        done
        shopt -u nullglob
        if (( ${#class_files[@]} > 0 )); then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${class_files[@]}" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _erro "Falha ao fazer backup dos arquivos .${EXTENSAO_CLASS} de ${programa}"
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
        fi

        # Backup de arquivos .TEL (nome exato ou variante com underscore)
        local tel_files=()
        if [[ -f "${T_TELAS}/${programa}.${EXTENSAO_TELAS}" ]]; then
            tel_files+=("${T_TELAS}/${programa}.${EXTENSAO_TELAS}")
        fi
        shopt -s nullglob
        for f in "${T_TELAS}/${programa}_"*."${EXTENSAO_TELAS}"; do
            tel_files+=("$f")
        done
        shopt -u nullglob
        if (( ${#tel_files[@]} > 0 )); then
            if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${tel_files[@]}" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _erro "Falha ao fazer backup dos arquivos .${EXTENSAO_TELAS} de ${programa}"
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
        fi

        # SEGURANCA: Validar integridade do backup criado
        if (( backup_criado )); then
            if ! _validar_integridade_backup "$arquivo_backup"; then
                _erro "CRITICO: Backup criado mas invalido para ${programa}"
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
            _exibir_mensagem_centralizada "${VERDE}" "Backup validado com sucesso: ${programa}"
        else
            _aviso "Nenhum arquivo antigo (.${EXTENSAO_CLASS}/.${EXTENSAO_TELAS}) encontrado para backup de ${programa}"
        fi
    done

    _linha
    _aviso "Backup dos programas efetuado"
    _linha
    _aguardar 1

    # Descompactar e atualizar programas
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _erro "Erro ao descompactar ${arquivo}"
            rm -rf "${dir_temp_atualizacao}"
            return 1
        fi
    done

    # SEGURANCA: Validar integridade pos-extracao (cada programa deve ter gerado arquivos)
    local programa_verif
    for programa_verif in "${PROGRAMAS_SELECIONADOS[@]}"; do
        shopt -s nullglob
        local arquivos_programa=()
        for f in "${programa_verif}"*."${EXTENSAO_CLASS}"; do
            arquivos_programa+=("$f")
        done
        for f in "${programa_verif}"*."${EXTENSAO_TELAS}"; do
            arquivos_programa+=("$f")
        done
        shopt -u nullglob
        if (( ${#arquivos_programa[@]} == 0 )); then
            _erro "Nenhum arquivo extraido para ${programa_verif}. Verifique o conteudo do pacote."
            rm -rf "${dir_temp_atualizacao}"
            return 1
        fi
    done

    # Mover arquivos para diretorios corretos
    local extensao arquivos_encontrados
    for extensao in ".${EXTENSAO_CLASS}" ".${EXTENSAO_TELAS}"; do
        shopt -s nullglob
        arquivos_encontrados=(*"${extensao}")
        shopt -u nullglob

        if (( ${#arquivos_encontrados[@]} > 0 )); then
            for arquivo in "${arquivos_encontrados[@]}"; do
                if [[ "${extensao}" == ".${EXTENSAO_TELAS}" ]]; then
                    if ! mv -f "${arquivo}" "${T_TELAS}/" >>"${LOG_ATU}" 2>&1; then
                        _log_erro "Falha ao mover ${arquivo} para ${T_TELAS}/"
                        _erro "Falha ao mover ${arquivo} para ${T_TELAS}/"
                        rm -rf "${dir_temp_atualizacao}"
                        return 1
                    else
                        _exibir_mensagem_centralizada "${VERDE}" "Arquivo ${arquivo} movido com sucesso para ${T_TELAS}/"
                    fi
                else
                    if ! mv -f "${arquivo}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1; then
                        _log_erro "Falha ao mover ${arquivo} para ${E_EXEC}/"
                        _erro "Falha ao mover ${arquivo} para ${E_EXEC}/"
                        _exibir_mensagem_centralizada "${AMARELO}" "Verifique o log de atualizacao em ${LOG_ATU} para mais detalhes."
                        _exibir_mensagem_centralizada "${AMARELO}" "Use a opcao 4 de reversao para restaurar o programa anterior."
                        rm -rf "${dir_temp_atualizacao}"
                        return 1
                    else
                        _log "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                        _exibir_mensagem_centralizada "${VERDE}" "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
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
            _erro "Falha ao criar diretorio de programas ${DEFAULT_PROGS_DIR}" >&2
            rm -rf "${dir_temp_atualizacao}"
            return 1
        }
    fi
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        local backup_file="${arquivo%.zip}.bkp"
        if ! mv -f "${arquivo}" "${DEFAULT_PROGS_DIR}/${backup_file}" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao arquivar ${arquivo} em ${DEFAULT_PROGS_DIR}/${backup_file}"
            _aviso "Falha ao arquivar ${arquivo} em ${DEFAULT_PROGS_DIR}. O arquivo sera removido."
        fi
    done

    # Limpar diretorio temporario
    cd "${DEFAULT_RECEBE_DIR}" || true
    rm -rf "${dir_temp_atualizacao}"

    _exibir_mensagem_centralizada "${VERDE}" "Alterando extensao da atualizacao"
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Atualizacao concluida com sucesso!"
    return 0
}

# Processa atualizacao de pacotes
_processar_atualizacao_pacotes() {
    if [[ -z "${DEFAULT_RECEBE_DIR}" ]]; then
        _erro "DEFAULT_RECEBE_DIR nao configurado"
        return 1
    fi

    # SEGURANCA: Validar diretorio de backups
    if ! _validar_diretorio_backups; then
        _exibir_mensagem_centralizada "${VERMELHO}" "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi

    # Verificar se arquivos existem no diretorio de recebimento
    local arquivo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${DEFAULT_RECEBE_DIR}/${arquivo}" ]]; then
            _erro "Arquivo nao encontrado: ${DEFAULT_RECEBE_DIR}/${arquivo}"
            return 1
        fi
    done

    # Criar diretorio temporario para extracao
    local dir_temp_atualizacao="${DEFAULT_RECEBE_DIR}/dir_temp_atualizacao"
    rm -rf "${dir_temp_atualizacao}" 2>/dev/null || true
    if ! _criar_diretorio_seguro "${dir_temp_atualizacao}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _erro "Falha ao criar diretorio temporario ${dir_temp_atualizacao}" >&2
        return 1
    fi

    # Mover pacotes para o diretorio temporario e acessa-lo
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! mv -f "${DEFAULT_RECEBE_DIR}/${arquivo}" "${dir_temp_atualizacao}/"; then
            _erro "Falha ao mover ${arquivo} para diretorio temporario"
            rm -rf "${dir_temp_atualizacao}"
            return 1
        fi
    done

    if ! cd "${dir_temp_atualizacao}"; then
        _erro "Falha ao acessar diretorio temporario"
        rm -rf "${dir_temp_atualizacao}"
        return 1
    fi

    # Descompactar pacotes
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _erro "Erro ao descompactar ${arquivo}"
            rm -rf "${dir_temp_atualizacao}"
            return 1
        fi
    done

    # Mover arquivos .zip para .bkp em DEFAULT_PROGS_DIR
    if [[ ! -d "${DEFAULT_PROGS_DIR}" ]]; then
        _criar_diretorio_seguro "${DEFAULT_PROGS_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
            _erro "Falha ao criar diretorio de programas ${DEFAULT_PROGS_DIR}" >&2
            rm -rf "${dir_temp_atualizacao}"
            return 1
        }
    fi
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        local backup_file="${arquivo%.zip}.bkp"
        if ! mv -f "${arquivo}" "${DEFAULT_PROGS_DIR}/${backup_file}" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao arquivar pacote ${arquivo} em ${DEFAULT_PROGS_DIR}/${backup_file}"
            _aviso "Falha ao arquivar pacote ${arquivo} em ${DEFAULT_PROGS_DIR}. O arquivo sera removido."
        fi
    done

    # Processar arquivos .class e  encontrados
    local arquivo_binario nome_prog caminho_dir arquivo_backup telas_existentes tel
    while IFS= read -r -d '' arquivo_binario; do
        nome_prog="$(basename "$arquivo_binario" .class)"
        caminho_dir="$(dirname "$arquivo_binario")"
        arquivo_backup="${DEFAULT_OLDS_DIR}/${nome_prog}-anterior.zip"

        # Backup dos arquivos class antigos (nome exato ou variante com underscore)
        local arquivos_antigos
        arquivos_antigos=()
        if [[ -f "${E_EXEC}/${nome_prog}.${EXTENSAO_CLASS}" ]]; then
            arquivos_antigos+=("${E_EXEC}/${nome_prog}.${EXTENSAO_CLASS}")
        fi
        shopt -s nullglob
        for f in "${E_EXEC}/${nome_prog}_"*."${EXTENSAO_CLASS}"; do
            arquivos_antigos+=("$f")
        done
        shopt -u nullglob

        local backup_criado=0
        if (( ${#arquivos_antigos[@]} > 0 )); then
            if ! "${DEFAULT_ZIP}" -j "${arquivo_backup}" "${arquivos_antigos[@]}" >>"${LOG_ATU}" 2>&1; then
                _log_erro "Falha ao fazer backup dos arquivos de ${nome_prog}"
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
            backup_criado=1
        fi

        # Backup de arquivos .TEL se existirem (nome exato ou variante com underscore)
        telas_existentes=()
        if [[ -f "${T_TELAS}/${nome_prog}.${EXTENSAO_TELAS}" ]]; then
            telas_existentes+=("${T_TELAS}/${nome_prog}.${EXTENSAO_TELAS}")
        fi
        shopt -s nullglob
        for f in "${T_TELAS}/${nome_prog}_"*."${EXTENSAO_TELAS}"; do
            telas_existentes+=("$f")
        done
        shopt -u nullglob
        if (( ${#telas_existentes[@]} > 0 )); then
            if ! "${DEFAULT_ZIP}" -j "${arquivo_backup}" "${telas_existentes[@]}" >>"${LOG_ATU}" 2>&1; then
                _log_erro "Falha ao fazer backup das telas de ${nome_prog}"
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
            backup_criado=1
        fi

        # SEGURANCA: Validar integridade do backup apenas se ele foi criado
        # (primeira instalacao nao possui arquivos antigos para backup)
        if (( backup_criado )); then
            if ! _validar_integridade_backup "${arquivo_backup}"; then
                _erro "CRITICO: Backup invalido ou ausente para ${nome_prog}. Atualizacao abortada."
                rm -rf "${dir_temp_atualizacao}"
                return 1
            fi
        else
            _aviso "Nenhum arquivo antigo encontrado para backup de ${nome_prog} (primeira instalacao?)"
        fi

        # Mover novo arquivo
        if ! mv -f "${arquivo_binario}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao mover ${arquivo_binario} para ${E_EXEC}"
            rm -rf "${dir_temp_atualizacao}"
            return 1
        fi

        # Move TELs do mesmo diretorio extraido (nome exato ou variante com underscore)
        if [[ -d "${caminho_dir}" ]]; then
            shopt -s nullglob
            local tels=()
            if [[ -f "${caminho_dir}/${nome_prog}.${EXTENSAO_TELAS}" ]]; then
                tels+=("${caminho_dir}/${nome_prog}.${EXTENSAO_TELAS}")
            fi
            for f in "${caminho_dir}/${nome_prog}_"*."${EXTENSAO_TELAS}"; do
                tels+=("$f")
            done
            shopt -u nullglob
            for tel in "${tels[@]}"; do
                mv -f "${tel}" "${T_TELAS}/" >>"${LOG_ATU}" 2>&1
            done
        fi
    done < <("${DEFAULT_FIND}" . -type f \( -name "*.class" \) -print0)

    # Limpar diretorio temporario
    cd "${DEFAULT_RECEBE_DIR}" || true
    rm -rf "${dir_temp_atualizacao}"
}

# Processa reversao de programas
_processar_reversao_programas() {
    _criar_diretorio_seguro "${DEFAULT_RECEBE_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Erro ao criar diretorio de configuracao ${DEFAULT_RECEBE_DIR}" >&2
        return 1
    }

    local programa_indice programa arquivo_anterior
    for programa_indice in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        programa="${PROGRAMAS_SELECIONADOS[$programa_indice]}"
        arquivo_anterior="${DEFAULT_OLDS_DIR}/${programa}-anterior.zip"

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
            _exibir_mensagem_centralizada "${VERDE}" "Backup validado e preparado para reversao: ${programa}"
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
        _erro "Erro ao criar diretorio de configuracao ${caminho}" >&2
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
    # Fallback para sistemas sem stat GNU (formato -c)
    local tamanho
    tamanho=$(stat -c%s "${arquivo_backup}" 2>/dev/null || true)
    if [[ -z "${tamanho}" ]]; then
        tamanho=$(stat -f%z "${arquivo_backup}" 2>/dev/null || true)
    fi
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
        local data_modificacao data_formatada
        data_modificacao=$(stat -c %y "${E_EXEC}/${arquivo}" 2>/dev/null)
        if [[ -z "$data_modificacao" ]]; then
            # Fallback para sistemas sem stat GNU (data epoch em segundos)
            local epoch
            epoch=$(stat -f %m "${E_EXEC}/${arquivo}" 2>/dev/null)
            if [[ -n "$epoch" ]]; then
                data_modificacao=$(date -d "@${epoch}" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || true)
            fi
        fi
        if [[ -n "$data_modificacao" ]]; then
            data_formatada=$(date -d "$data_modificacao" +"%d/%m/%Y %H:%M:%S" 2>/dev/null)
            _exibir_mensagem_centralizada "${VERDE}" "Nome do programa: ${arquivo}"
            _exibir_mensagem_centralizada "${AMARELO}" "Data do programa: ${data_formatada}"
        fi
    fi
}

# Mensagem de conclusao da reversao
# Retorna: 0 para continuar revertendo, 1 para encerrar
_mensagem_conclusao_reversao() {
    _linha
    _aviso "Volta do(s) Programa(s) Concluida(s)"
    _linha
    _aguardar_tecla
    _linha
    # Perguntar se deseja reverter mais programas
    printf "\n"
    if _confirmar "Deseja reverter mais algum programa?" "N"; then
        return 0
    fi
    return 1
}
