#!/usr/bin/env bash
#
# programas.sh - Modulo de Gestao de Programas
# Responsavel pela atualizacao, instalacao e reversao de programas
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 17/04/2026-00
#
# Variaveis globais esperadas
sistema="${sistema:-}"      # Nome do sistema (iscobol, savatu, transpc).
cmd_zip="${cmd_zip:-}"      # Comando de compactacao (zip)
cmd_unzip="${cmd_unzip:-}"  # Comando de descompactacao (unzip)
Offline="${Offline:-}"      # Modo offline (s/n)
down_dir="${down_dir:-}"    # Diretorio de download de arquivos
class="${class:-}"          # Sufixo para arquivos de classe
mclass="${mclass:-}"        # Sufixo para arquivos de classe de depuracao

#---------- VARIaVEIS GLOBAIS DO MODULO ----------#
# Arrays para armazenar programas e arquivos
declare -g ARQUIVO_COMPILADO_ATUAL=""
declare -a PROGRAMAS_SELECIONADOS=()
declare -a ARQUIVOS_PROGRAMA=()

#---------- FUNCOES DE ATUALIZACAO ONLINE ----------#

# Atualizacao de programas via conexao online
_atualizar_programa_online() {
    if [[ "${Offline}" =~ ^[sn]$ ]]; then    
        if [[ "${Offline}" == "s" ]]; then
            _linha
            _mensagec "${YELLOW}" "Parametro do servidor OFF ativo"
            _linha
            _press
            return 0
        fi
    fi    
    # Solicitar programas a serem atualizados
    _solicitar_programas_atualizacao
    
    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${YELLOW}" "Nenhum programa selecionado"
        _linha
        _press
        return 0
    fi
    
    # Baixar programas via vaievem
    _baixar_programas_vaievem
    
    # Atualizar programas baixados
    _processar_atualizacao_programas
    _linha
    _press
}

# Atualizacao de programas via arquivos offline
_atualizar_programa_offline() {

    # Solicitar programas a serem atualizados
    _solicitar_programas_atualizacao
    

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _mensagec "${YELLOW}" "Nenhum programa selecionado"
        _linha
        _press
        return 0
    fi
    
    _linha
    _mensagec "${YELLOW}" "Os programas devem estar no diretorio ${WHITE}${down_dir}"
    _linha
    _read_sleep 0
    
    # Mover arquivos do servidor offline se configurado
    _mover_arquivos_offline
    
    # Atualizar programas
    _processar_atualizacao_programas
    _linha
    _press
}

# Atualizacao de programas em pacotes
_atualizar_programa_pacote() {
        _solicitar_pacotes_atualizacao
    if [[ "${Offline}" =~ ^[sn]$ ]]; then        
        if [[ "${Offline}" == "s" ]]; then
            _linha
            _mensagec "${YELLOW}" "Parametro do servidor OFF ativo"
            _mover_arquivos_offline
        else 
            _baixar_pacotes_vaievem
        fi
    fi
        _processar_atualizacao_pacotes
        _linha
        _press
        return 0
}

#---------- FUNCOES DE REVERSaO ----------#

# Seleciona programas disponiveis para reversao (backups *-anterior.zip)
# Popula as variaveis globais PROGRAMAS_SELECIONADOS e ARQUIVOS_PROGRAMA
_selecionar_programas_reversao() {
    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()

    if [[ ! -d "${OLDS}" ]]; then
        _mensagec "${RED}" "Diretorio de backups nao encontrado: ${OLDS}"
        _press
        return 0
    fi

    shopt -s nullglob
    local backups=("${OLDS}"/*-anterior.zip)
    shopt -u nullglob

    if (( ${#backups[@]} == 0 )); then
        _mensagec "${YELLOW}" "Nenhum backup de programa encontrado em ${OLDS}"
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

        # Tratar cancelamento
        if [[ -z "${escolha}" || "${escolha}" == "0" ]]; then
            _mensagec "${YELLOW}" "Operacao cancelada."
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
            _mensagec "${RED}" "Opcao invalida. Informe numero(s) entre 1 e ${#programas[@]}."
            continue
        fi

        # Remover duplicatas mantendo a ordem
        declare -A seen=()
        for token in "${indices[@]}"; do
            if [[ -n "${seen[$token]:-}" ]]; then
                continue
            fi
            seen[$token]=1
            local programa_selecionado="${programas[$((token-1))]}"
            PROGRAMAS_SELECIONADOS+=("${programa_selecionado}")
            ARQUIVOS_PROGRAMA+=("${programa_selecionado}${class}.zip")
        done

        break
    done

    return 0
}

# Reverter programas para versao anterior
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

# Solicita tipo de compilacao e define o nome do artefato selecionado
_resolver_arquivo_compilado() {
    local nome_item="$1"
    local tipo_compilacao

    _mensagec "${RED}" "Informe o tipo de compilacao (1 - Normal, 2 - Depuracao):"
    _linha

    read -rp "${YELLOW}Tipo de compilacao: ${NORM}" -n1 tipo_compilacao
    printf "\n"

    if [ "$tipo_compilacao" = "1" ]; then
        ARQUIVO_COMPILADO_ATUAL="${nome_item}${class}.zip"
    elif [ "$tipo_compilacao" = "2" ]; then
        ARQUIVO_COMPILADO_ATUAL="${nome_item}${mclass}.zip"
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
                    if [[ "$arq" == *"${mclass}"* ]]; then
                        _mensagec "${GREEN}" "  -> ${prog} - Depuracao"
                    else
                        _mensagec "${GREEN}" "  -> ${prog} - Normal"
                    fi
                done
                _linha
                if ! _confirmar "${WHITE}"" Confirma a selecao do(s) programa(s) acima?" "S"; then
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

# Solicita programas para atualizacao
_solicitar_programas_atualizacao() {
    _coletar_artefatos_atualizacao \
        "programa" \
        "Informe o nome do programa a ser atualizado:" \
        "Finalizando selecao de programas..." \
        "Programas selecionados:"
}

# Solicita pacotes para atualizacao
_solicitar_pacotes_atualizacao() {
    _coletar_artefatos_atualizacao \
        "pacote" \
        "Informe o nome do pacote:" \
        "Finalizando selecao de pacotes..." \
        "Pacotes selecionados:"
}

#---------- FUNCOES DE DOWNLOAD ----------#


# Baixa pacotes para diretorio especifico
_baixar_pacotes_vaievem() {
    _configurar_acessos

    cd "${down_dir}" || {
        _mensagec "${RED}" "Erro: Diretorio $down_dir nao encontrado"
        _read_sleep 2
        return 1
    }

    _baixar_programas_vaievem
}

#---------- FUNCOES DE PROCESSAMENTO ----------#

# Move arquivos do servidor offline
_mover_arquivos_offline() {
    _configurar_acessos

        for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
            if [[ -f "${down_dir}/${arquivo}" ]]; then
                _mensagec "${GREEN}" "Arquivo encontrado: ${arquivo}"
            else
                _mensagec "${RED}" "Arquivo nao encontrado: ${arquivo}"
            fi
            _linha
        done
}

# Processa atualizacao dos programas
_processar_atualizacao_programas() {
    # Ir para o diretório RECEBE onde estão os arquivos baixados
    cd "${down_dir}" || return 1

    local arquivo         # Nome do arquivo
    local extensao        # Extensao do arquivo
    local backup_file     # Nome do arquivo de backup
    local programa_idx=0  # indice do programa no array

    # SEGURANCA: Validar diretorio de backups antes de qualquer operacao
    if ! _validar_diretorio_backups; then
        _mensagec "${RED}" "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi

    # Verificar se arquivos existem
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${arquivo}" ]]; then
            _mensagec "${RED}" "Arquivo nao encontrado: ${arquivo}"
            return 0
        fi
    done

    # Criar backup dos programas antigos
    for programa_idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_idx]}"
        local arquivo_backup="${OLDS}/${programa}-anterior.zip"
        local backup_criado=0
        
        # Verificar se ja existe backup e fazer rotacao com data
        if [[ -f "$arquivo_backup" ]]; then
            if ! mv -f "$arquivo_backup" "${OLDS}/${UMADATA}-${programa}-anterior.zip"; then
                _mensagec "${RED}" "ERRO: Falha ao arquivar backup anterior de ${programa}"
                return 1
            fi
        fi
        
        _mensagec "${YELLOW}" "Salvando programa antigo: ${programa}"
        
        # Backup de arquivos .class
        if [[ -f "${E_EXEC}/${programa}.class" ]]; then
            if "${cmd_zip}" -j "$arquivo_backup" "${E_EXEC}/${programa}"*.class >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _mensagec "${RED}" "ERRO: Falha ao fazer backup dos arquivos .class de ${programa}"
                return 1
            fi
        fi
        
        # Backup de arquivos .int
        if [[ -f "${E_EXEC}/${programa}.int" ]]; then
            if "${cmd_zip}" -j "$arquivo_backup" "${E_EXEC}/${programa}.int" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _mensagec "${RED}" "ERRO: Falha ao fazer backup dos arquivos .int de ${programa}"
                return 1
            fi
        fi
        
        # Backup de arquivos .TEL
        if [[ -f "${T_TELAS}/${programa}.TEL" ]]; then
            if "${cmd_zip}" -j "$arquivo_backup" "${T_TELAS}/${programa}.TEL" >> "${LOG_ATU}" 2>&1; then
                backup_criado=1
            else
                _mensagec "${RED}" "ERRO: Falha ao fazer backup dos arquivos .TEL de ${programa}"
                return 1
            fi
        fi

        # SEGURANCA: Validar integridade do backup criado
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
    _read_sleep 1

    # Descompactar e atualizar programas
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if ! "${cmd_unzip}" -o "${arquivo}" >>"${LOG_ATU}"; then
            _mensagec "${RED}" "Erro ao descompactar ${arquivo}"
            continue
        fi
    done

# Mover arquivos para diretorios corretos
    for extensao in ".class" ".int" ".TEL"; do
        if compgen -G "*${extensao}" >/dev/null; then
            for arquivo in *"${extensao}"; do
                if [[ "${extensao}" == ".TEL" ]]; then
                    mv -f "${arquivo}" "${T_TELAS}/" >>"${LOG_ATU}" 2>&1
                else
                    mv -f "${arquivo}" "${E_EXEC}/" >>"${LOG_ATU}" 2>&1
                    # Verificar se o arquivo foi movido com sucesso
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

    # Mover arquivos .zip para .bkp
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${arquivo}" ]]; then
            local backup_file="${arquivo%.zip}.bkp"
            mv -f "${arquivo}" "${PROGS}/${backup_file}"
        fi
    done

    _mensagec "${GREEN}" "Alterando extensao da atualizacao"
    _linha
    _mensagec "${YELLOW}" "Atualizacao concluida com sucesso!"
}

# Processa atualizacao de pacotes
_processar_atualizacao_pacotes() {
    # Ir para o diretório onde estão os pacotes baixados
    cd "${down_dir}" || return 1
    
    # SEGURANCA: Validar diretorio de backups
    if ! _validar_diretorio_backups; then
        _mensagec "${RED}" "OPERACAO ABORTADA: Impossivel garantir integridade de backups"
        return 1
    fi
    # Configura acessos 
    _configurar_acessos
    # Descompactar pacotes
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ ! -f "${arquivo}" ]]; then
            _mensagec "${RED}" "Arquivo nao encontrado: ${arquivo}"
            _read_sleep 2
            return 0
        fi

        if ! "${cmd_unzip}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _mensagec "${RED}" "Erro ao descompactar ${arquivo}"
            _read_sleep 2
            return 1
        fi
    done

    # Mover arquivos .zip para .bkp
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        if [[ -f "${arquivo}" ]]; then
            local backup_file="${arquivo%.zip}.bkp"
            if ! mv -f "${arquivo}" "${PROGS}/${backup_file}"; then
                _mensagec "${RED}" "ERRO: Falha ao arquivar pacote ${arquivo}"
                return 1
            fi
        fi
    done

    # Processar arquivos .class encontrados (usando redirection para evitar subshell do pipe)
    while read -r classfile; do
        local progname="${classfile##*/}" # Extrair nome do arquivo
        progname="${progname%%.class}"    # Remover extensao
        local arquivo_backup="${OLDS}/${progname}-anterior.zip"

        # Backup dos arquivos antigos
        if [[ "${sistema}" == "iscobol" ]]; then
            if ! find "${E_EXEC}" -name "${progname}*.class" -exec "${cmd_zip}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.class"
                return 1
            fi
        else
            if ! find "${E_EXEC}" -name "${progname}*.int" -exec "${cmd_zip}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.int"
                return 1
            fi
        fi

        # Backup de arquivos .TEL se existirem
        if [[ -f "${progname}.TEL" ]]; then
            if ! find "${T_TELAS}" -name "${progname}*.TEL" -exec "${cmd_zip}" -j "${arquivo_backup}" {} + 2>>"${LOG_ATU}"; then
                _log_erro "Falha ao fazer backup de ${progname}*.TEL"
                return 1
            fi
        fi

        # SEGURANCA: Validar integridade do backup antes de continuar
        if [[ -f "${arquivo_backup}" ]]; then
            if ! _validar_integridade_backup "${arquivo_backup}"; then
                return 1
            fi
        fi

        # Mover novos arquivos
        if ! mv -f "${progname}"*.class "${E_EXEC}/" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao mover ${progname}*.class para ${E_EXEC}"
            return 1
        fi
        if [[ -f "${progname}.TEL" ]]; then
            if ! mv -f "${progname}"*.TEL "${T_TELAS}/" >>"${LOG_ATU}" 2>&1; then
                _log_erro "Falha ao mover ${progname}*.TEL para ${T_TELAS}"
                return 1
            fi
        fi
    done < <(find . -type f -name "*.class")
}

# Processa reversao de programas
_processar_reversao_programas() {
    # Criar diretório RECEBE se não existir
    [[ ! -d "${down_dir}" ]] && mkdir -p "${down_dir}"
    
    for programa_idx in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        local programa="${PROGRAMAS_SELECIONADOS[$programa_idx]}"
        local arquivo_anterior="${OLDS}/${programa}-anterior.zip"
        
        if [[ -f "$arquivo_anterior" ]]; then
            # SEGURANCA: Validar integridade do backup antes de reverter
            if ! _validar_integridade_backup "$arquivo_anterior"; then
                _mensagec "${RED}" "ERRO: Backup invalido ou corrompido para ${programa}. Reversao abortada."
                return 1
            fi

            if ! mv -f "$arquivo_anterior" "${down_dir}/${programa}${class}.zip"; then
                _mensagec "${RED}" "ERRO: Falha ao preparar backup para reversao de ${programa}"
                return 1
            fi
            _mensagec "${GREEN}" "Backup validado e preparado para reversao: ${programa}"
        else
            _mensagec "${RED}" "Backup nao encontrado para: ${programa}"
            return 1
        fi
    done

    # Processar atualizacao com os arquivos revertidos
    _processar_atualizacao_programas
}

#---------- FUNCOES AUXILIARES ----------#

# Valida e cria diretorio de backups se nao existir
_validar_diretorio_backups() {
    if [[ ! -d "${OLDS}" ]]; then
        _mensagec "${YELLOW}" "Criando diretorio de backups: ${OLDS}"
        if ! mkdir -p "${OLDS}"; then
            _mensagec "${RED}" "ERRO CRITICO: Falha ao criar diretorio de backups ${OLDS}"
            return 1
        fi
    fi

    # Validar permissoes de escrita
    if [[ ! -w "${OLDS}" ]]; then
        _mensagec "${RED}" "ERRO CRITICO: Sem permissao de escrita em ${OLDS}"
        return 1
    fi

    return 0
}

# Valida integridade de arquivo de backup
_validar_integridade_backup() {
    local arquivo_backup="$1"

    # Verificar se arquivo existe
    if [[ ! -f "${arquivo_backup}" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo de backup nao encontrado: ${arquivo_backup}"
        return 1
    fi

    # Verificar tamanho minimo (arquivo zip deve ter pelo menos 22 bytes)
    local tamanho
    tamanho=$(stat -c%s "${arquivo_backup}" 2>/dev/null)
    if (( tamanho < 22 )); then
        _mensagec "${RED}" "ERRO: Arquivo de backup corrompido (tamanho: ${tamanho} bytes): ${arquivo_backup}"
        return 1
    fi

    # Testar integridade do arquivo zip
    if ! "${cmd_unzip}" -t "${arquivo_backup}" >/dev/null 2>&1; then
        _mensagec "${RED}" "ERRO: Arquivo de backup invalido ou corrompido: ${arquivo_backup}"
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
            _mensagec "${GREEN}" "Nome do programa: ${arquivo}"
            _mensagec "${YELLOW}" "Data do programa: ${data_formatada}"
        fi
    fi
}

# Mensagem de conclusao da reversao
_mensagem_conclusao_reversao() {
    _linha
    _mensagec "${YELLOW}" "Volta do(s) Programa(s) Concluida(s)"
    _linha
    _press
    _linha
    # Perguntar se deseja reverter mais programas
    printf "\n"
    if _confirmar "Deseja reverter mais algum programa?" "N"; then
        _reverter_programa
    fi
}
