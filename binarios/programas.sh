#!/usr/bin/env bash
set -euo pipefail
#
# programas.sh - Modulo de Gestao de Programas
# Responsavel pela atualizacao, instalacao e reversao de programas
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 05/11/2026-01
#

# Variaveis globais esperadas
compilado="${compilado:-class}"                 # Sufixo para arquivos compilados
debugado="${debugado:-mclass}"                  # Sufixo para arquivos em depuração
CFG_PORTALSAV="${CFG_PORTALSAV:-}"    # Diretorio de recebimento de arquivos
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip)
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)
# ATU_DIR_TEMP e ATU_SUFIXO_BACKUP vem de constantes.sh (mesmo bloco do
# ARQUIVO_ZIP_ATU usado por baixar.sh) e nao sao redeclarados aqui: um default
# duplicado neste modulo voltaria a divergir da constante.
#---------- VARIaVEIS GLOBAIS DO MODULO ----------#
# Arrays para armazenar programas e arquivos
declare arquivo_compilado_atual=""
declare -a PROGRAMAS_SELECIONADOS=()
declare -a ARQUIVOS_PROGRAMA=()

# Coleta arquivos por glob SEM depender de nullglob e SEM fork.
# Sem nullglob, um glob sem match se expande para o proprio padrao (ex: "*.class"),
# entao o filtro `[[ -e "$f" ]] || continue` e o que substitui o shopt -s/u.
# Funciona nos dois estados: com nullglob ligado o glob nao produz nada; com ele
# desligado produz o literal do padrao, que o teste descarta.
#
# O padrao fica em UMA palavra (as partes do caminho vao entre aspas), igual no
# codigo anterior — assim um diretorio com espaco nao sofre word splitting.
# Nao extraia isto para um helper com `local -n`: nameref exige Bash 4.4+ e o
# modulo precisa rodar em 4.0 (Ubuntu 10.04). Ver comentario em backup.sh:_validar_pre_backup.

# Cleanup compartilhado por _processar_atualizacao_programas e
# _processar_atualizacao_pacotes: restaura cwd e remove o temporario.
# Definida uma unica vez no modulo. Usa escopo dinamico: le _cwd e
# dir_temp_atualizacao do chamador — chamar somente apos essas locais existirem.
# Nao restaura nullglob: nenhum glob deste modulo liga mais o shopt (ver nota
# acima), entao nao ha estado de shell a reverter.
_cleanupAtualizacao() {
    cd "$_cwd" || true
    # SEGURANCA: nunca remover um caminho inseguro/vazio. Se CFG_PORTALSAV
    # estiver vazio, dir_temp_atualizacao resolveria para "/dir_temp_atualizacao"
    # e o rm -rf atingiria a raiz — o guard abaixo impede isso.
    if [[ -z "${dir_temp_atualizacao:-}" ]]; then
        return 0
    fi
    if ! _validar_caminho_seguro "${dir_temp_atualizacao}"; then
        _log "AVISO: cleanup recusado para caminho inseguro: ${dir_temp_atualizacao}" || true
        return 0
    fi
    rm -rf -- "${dir_temp_atualizacao}" 2>/dev/null || true
}
#---------- FUNCOES DE ATUALIZACAO ONLINE ----------#

# Atualizacao de programas via conexao online
_atualizar_programa_online() {
    if [[ "${CFG_OFFLINE}" == "s" ]]; then
        _linha
        _aviso "Parametro do servidor OFF ativo"
        _linha
        _aviso "Use a opcao 2 (Programa(s) OFF-Line) para instalar do diretorio local."
        _linha
        _aguardar_tecla
        return 0
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

    # Solicitar programas a serem atualizados
    _solicitar_programas_atualizacao


    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum programa selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi

    # Verificar arquivos no diretorio de recebimento (off-line)
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

    _solicitar_pacotes_atualizacao

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum pacote selecionado"
        _linha
        _aguardar_tecla
        return 0
    fi

    # Antes: `[[ -n "${CFG_OFFLINE:-}" && "${CFG_OFFLINE}" == "s" ]]`. Com a
    # flag vazia, "S" maiusculo ou lixo, o teste falhava e o fluxo caia no
    # ELSE — _baixar_pacotes_vaievem, isto e, descarga pela REDE num menu que
    # o usuario usaria justamente por estar OFF-LINE. Agora o valor invalido
    # aborta com mensagem, como nos demais modulos (_offline_valido, utils.sh).
    if ! _offline_valido; then
        _offline_erro "atualizacao de pacotes"
        _linha
        _aguardar_tecla
        return 1
    fi

    if [[ "$CFG_OFFLINE" == "s" ]]; then
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

# Seleciona programas disponiveis para reversao (todos os .zip de DEFAULT_PROGS_DIR)
# Popula as variaveis globais PROGRAMAS_SELECIONADOS e ARQUIVOS_PROGRAMA
# ARQUIVOS_PROGRAMA sai daqui com o nome real do .zip selecionado em DEFAULT_PROGS_DIR;
# _processar_reversao_programas reescreve para o nome de destino em CFG_PORTALSAV.
_selecionar_programas_reversao() {
    PROGRAMAS_SELECIONADOS=()
    ARQUIVOS_PROGRAMA=()

    if [[ ! -d "${DEFAULT_PROGS_DIR}" ]]; then
        _erro "Diretorio de backups nao encontrado: ${DEFAULT_PROGS_DIR}"
        _aguardar_tecla
        return 1
    fi

    local backups=()
    local bkp
    for bkp in "${DEFAULT_PROGS_DIR}"/*.zip; do
        [[ -e "$bkp" ]] || continue
        backups+=("$bkp")
    done

    if (( ${#backups[@]} == 0 )); then
        _aviso "Nenhum backup de programa encontrado em ${DEFAULT_PROGS_DIR}"
        _aguardar_tecla
        return 1
    fi

    local programas=()
    local arquivos_fonte=()
    local arquivo
    for arquivo in "${backups[@]}"; do
        local nome_base nome_programa
        nome_base="${arquivo##*/}"
        if [[ "${nome_base}" == *-anterior.zip ]]; then
            nome_programa="${nome_base%-anterior.zip}"
        else
            nome_programa="${nome_base%.zip}"
        fi
        # Backup rotacionado tem prefixo de timestamp AAAAMMDD_HHMMSS-:
        # o programa e o que vem depois do prefixo (ex.: 20260921_001613-ADEB11 -> ADEB11),
        # pois e esse o prefixo dos .class/.TEL dentro do zip.
        if [[ "${nome_programa}" =~ ^[0-9]{8}_[0-9]{6}-(.+)$ ]]; then
            nome_programa="${BASH_REMATCH[1]}"
        fi
        if [[ -z "${nome_programa}" ]]; then
            continue
        fi
        # SEGURANCA: o nome derivado vira nome de arquivo de destino
        # (CFG_PORTALSAV/${programa}${compilado}.zip). Rejeitar qualquer
        # coisa que nao seja nome de programa valido (barra, "..", etc.) para
        # evitar escrita fora do diretorio de recebimento.
        if ! _validar_nome_programa "${nome_programa}"; then
            _log_erro "Backup ignorado (nome de programa invalido): ${nome_base}"
            continue
        fi
        programas+=("${nome_programa}")
        arquivos_fonte+=("${nome_base}")
    done

    if (( ${#programas[@]} == 0 )); then
        _aviso "Nenhum backup de programa encontrado em ${DEFAULT_PROGS_DIR}"
        _aguardar_tecla
        return 1
    fi

    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Backups disponiveis para reversao:"
    _linha

    local indice=1
    local programa
    for programa in "${!programas[@]}"; do
        _exibir_mensagem_centralizada "${VERDE}" "$((indice))) ${programas[$programa]} [${arquivos_fonte[$programa]}]"
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
        # Desativar glob temporariamente para evitar expansao de * e ? em ${escolha},
        # restaurando o estado anterior ao final (set +f cego alteraria o shell).
        # Estado guardado via $- (zero fork): "f" em $- = noglob ativo; evita
        # o fork de "$(shopt -p noglob)". Bash 4.0+ suporta $-.
        local _old_noglob=0
        case "$-" in
            *f*) _old_noglob=1 ;;
        esac
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
        if (( _old_noglob )); then
            set -f
        else
            set +f
        fi

        if (( invalido )); then
            _erro "Opcao invalida. Informe numero(s) entre 1 e ${#programas[@]}."
            continue
        fi

        # Remover duplicatas mantendo a ordem
        local -A seen=()
        local -a programas_tmp=()
        local -a arquivos_tmp=()
        for token in "${indices[@]}"; do
            if [[ -n "${seen[$token]:-}" ]]; then
                continue
            fi
            seen[$token]=1
            programas_tmp+=("${programas[$((token-1))]}")
            arquivos_tmp+=("${arquivos_fonte[$((token-1))]}")
        done

        if (( ${#programas_tmp[@]} == 0 )); then
            _erro "Opcao invalida. Informe numero(s) entre 1 e ${#programas[@]}."
            continue
        fi

        # O mesmo programa nao pode ser revertido de dois backups diferentes
        # de uma so vez (o destino em CFG_PORTALSAV seria o mesmo arquivo).
        local -A seen_prog=()
        local duplicado=""
        local item
        for item in "${programas_tmp[@]}"; do
            if [[ -n "${seen_prog[$item]:-}" ]]; then
                duplicado="${item}"
                break
            fi
            seen_prog[$item]=1
        done
        if [[ -n "${duplicado}" ]]; then
            _erro "Programa ${duplicado} selecionado mais de uma vez (backups diferentes). Selecione apenas um backup por programa."
            continue
        fi

        PROGRAMAS_SELECIONADOS=("${programas_tmp[@]}")
        ARQUIVOS_PROGRAMA=("${arquivos_tmp[@]}")

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
    local nome_item="${1:-}"
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
# Parametros: $1=rotulo_item $2=mensagem_item $3=mensagem_final
_coletar_artefatos_atualizacao() {
    local rotulo_item="${1:-}"
    local mensagem_item="${2:-}"
    local mensagem_final="${3:-}"
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
        "Finalizando selecao de programas..."
}

# Solicita pacotes para atualizacao
_solicitar_pacotes_atualizacao() {
    _coletar_artefatos_atualizacao \
        "pacote" \
        "Informe o nome do pacote da versao do sistema ${CFG_VERSAOCLASS}" \
        "Finalizando selecao de pacotes..."
}

#---------- FUNCOES DE DOWNLOAD ----------#
# Baixa pacotes para diretorio especifico
_baixar_pacotes_vaievem() {
    _baixar_programas_vaievem
}

#---------- FUNCOES DE PROCESSAMENTO ----------#

# Verifica se arquivos existem no diretorio de recebimento (modo offline)
# Retorna: 0 se todos encontrados, 1 se algum faltar
_verificar_arquivos_offline() {
    local arquivo
    local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}")
    local _encontrados=0
    for arquivo in "${_arquivos_prog[@]}"; do
        if [[ -f "${CFG_PORTALSAV}/${arquivo}" ]]; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo encontrado: ${arquivo}"
        else
            _aviso "Arquivo nao encontrado: ${arquivo}"
        fi
        _linha
    done
    for arquivo in "${_arquivos_prog[@]}"; do
        [[ -f "${CFG_PORTALSAV}/${arquivo}" ]] && ((_encontrados++)) || true
    done
    if (( _encontrados == 0 )); then
        return 1
    fi
    return 0
}

# Valida pre-requisitos comuns antes de qualquer atualizacao
# Retorna: 0 se valido, 1 se erro
_validar_pre_requisitos_atualizacao() {
    if [[ -z "${CFG_PORTALSAV}" ]]; then
        _erro "ERRO: CFG_PORTALSAV nao configurado"
        return 1
    fi

    if [[ -z "${DEFAULT_PROGS_ATUAL_DIR}" ]]; then
        _erro "ERRO: DEFAULT_PROGS_ATUAL_DIR nao configurado"
        return 1
    fi

    # SEGURANCA: Validar diretorio de backups antes de qualquer operacao
    if ! _garantir_diretorio "${DEFAULT_PROGS_DIR}" criar "diretorio de backups"; then
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
        if ! _verificar_espaco_disco "${CFG_PORTALSAV}"; then
            _erro "ERRO: Espaco em disco insuficiente em ${CFG_PORTALSAV}"
            return 1
        fi
    fi

    # Verificar se arquivos existem no diretorio de recebimento
    # Loop unico: existencia + validacao de entradas no mesmo turno (antes
    # eram 2 varreduras). Cada _validar_backup_entradas_seguras e 1 processo
    # externo (unzip -Z1 + grep), entao o custo dominante e externo, nao loop.
    local arquivo
    local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
        if [[ ! -f "${CFG_PORTALSAV}/${arquivo}" ]]; then
            _erro "Arquivo nao encontrado: ${CFG_PORTALSAV}/${arquivo}"
            return 1
        fi
    done

    # SEGURANCA: validar as entradas do pacote antes de QUALQUER extracao.
    # O unzip roda dentro de dir_temp_atualizacao, mas um caminho absoluto
    # dentro do ZIP (ou um "../") escapa desse diretorio — o pacote ia
    # sobrescrever o proprio destino da atualizacao. A checagem fica aqui, e
    # nao junto do unzip, porque este ponto e anterior a criacao do
    # temporario, ao backup dos programas antigos e a qualquer escrita: um
    # pacote malicioso nem chega a tocar o disco.
    # Para um ZIP legitimo nada muda: o validador e silencioso e o fluxo segue
    # igual. biblioteca.sh faz a mesma coisa desde _validar_backup_entradas_seguras
    # (utils.sh), antes de extrair.
    if (( ${#_arquivos_prog[@]} <= 1 )); then
        local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
            if ! _validar_backup_entradas_seguras "${CFG_PORTALSAV}/${arquivo}"; then
                _erro "OPERACAO ABORTADA: pacote invalido em ${CFG_PORTALSAV}/${arquivo}"
                return 1
            fi
        done
    else
        # Ondas de ate N jobs (padrao de arquivos.sh:_executar_jutil_lote):
        # Bash 4.0+ sem wait -n, espera so a onda atual via "wait $pid".
        # O resultado volta via arquivo de status; qualquer falha aborta
        # antes de extrair, igual ao sequencial (a saida do validador e o
        # erro, nao a ordem dos testes).
        local paralelo=4
        [[ "${PRE_REQUISITO_PARALELO:-}" =~ ^[0-9]+$ ]] && paralelo="${PRE_REQUISITO_PARALELO}"
        if (( paralelo < 1 )); then
            paralelo=1
        fi
        if (( paralelo > ${#_arquivos_prog[@]} )); then
            paralelo="${#_arquivos_prog[@]}"
        fi
        local dir_status
        dir_status=$(_expurgador_status_dir)
        if [[ -z "$dir_status" ]]; then
            local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
                if ! _validar_backup_entradas_seguras "${CFG_PORTALSAV}/${arquivo}"; then
                    _erro "OPERACAO ABORTADA: pacote invalido em ${CFG_PORTALSAV}/${arquivo}"
                    return 1
                fi
            done
        else
            local inicio=0 fim indice arquivo_val pids_onda rc_val
            local -a pids_onda=()
            local falhou=0 arquivo_falha=""
            while (( inicio < ${#_arquivos_prog[@]} && falhou == 0 )); do
                fim=$((inicio + paralelo))
                if (( fim > ${#_arquivos_prog[@]} )); then
                    fim="${#_arquivos_prog[@]}"
                fi
                pids_onda=()
                for ((indice = inicio; indice < fim; indice++)); do
                    arquivo_val="${_arquivos_prog[$indice]}"
                    (
                        _validar_backup_entradas_seguras "${CFG_PORTALSAV}/${arquivo_val}" >/dev/null 2>&1
                        printf '%s' "$?" > "${dir_status}/${indice}.status"
                    ) &
                    pids_onda+=("$!")
                done
                for pids_onda in ${pids_onda[@]+"${pids_onda[@]}"}; do
                    wait "$pids_onda" 2>/dev/null || true
                done
                for ((indice = inicio; indice < fim; indice++)); do
                    rc_val=1
                    if [[ -f "${dir_status}/${indice}.status" ]]; then
                        rc_val=$(<"${dir_status}/${indice}.status")
                    fi
                    rc_val="${rc_val//[^0-9]/}"
                    if [[ -z "$rc_val" || "$rc_val" != "0" ]]; then
                        arquivo_falha="${_arquivos_prog[$indice]}"
                        falhou=1
                        break
                    fi
                done
                inicio="$fim"
            done
            rm -rf -- "$dir_status" 2>/dev/null || true
            if (( falhou )); then
                _erro "OPERACAO ABORTADA: pacote invalido em ${CFG_PORTALSAV}/${arquivo_falha}"
                return 1
            fi
        fi
    fi

    return 0
}

# Processa atualizacao dos programas
_processar_atualizacao_programas() {
    # Continuar caso um dos programas informados nao exista (arquivo nao
    # baixado/disponivel): manter apenas os que possuem arquivo em
    # CFG_PORTALSAV e prosseguir com a atualizacao do que foi baixado.
    local -a _progs_disponiveis=() _arqs_disponiveis=()
    local _idx_prog _arq_prog
    for _idx_prog in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        _arq_prog="${ARQUIVOS_PROGRAMA[$_idx_prog]}"
        if [[ -f "${CFG_PORTALSAV}/${_arq_prog}" ]]; then
            _progs_disponiveis+=("${PROGRAMAS_SELECIONADOS[$_idx_prog]}")
            _arqs_disponiveis+=("${_arq_prog}")
        else
            _aviso "Programa nao encontrado (arquivo ausente): ${_arq_prog}"
        fi
    done
    if (( ${#_progs_disponiveis[@]} > 0 )); then
        PROGRAMAS_SELECIONADOS=("${_progs_disponiveis[@]}")
        ARQUIVOS_PROGRAMA=("${_arqs_disponiveis[@]}")
    else
        PROGRAMAS_SELECIONADOS=()
        ARQUIVOS_PROGRAMA=()
    fi

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        _aviso "Nenhum programa disponivel para atualizacao"
        return 1
    fi

    # Validar pre-requisitos comuns (diretorios, backups, arquivos, espaco em disco)
    if ! _validar_pre_requisitos_atualizacao; then
        return 1
    fi

    # Salvar cwd para restaurar em todas as saidas (evitar cwd em dir temporario removido)
    local _cwd
    _cwd="$PWD"

    # Cleanup via _cleanupAtualizacao (definida no nivel do modulo)

    # Criar diretorio temporario para extracao
    # O nome vem de ATU_DIR_TEMP (constantes.sh), o mesmo que baixar.sh usa
    # na limpeza da recepcao: o literal "dir_temp_atualizacao" duplicava o
    # default da constante e, se a constante mudasse, a limpeza do passo 3
    # passaria a ignorar este diretorio. O nome da local continua sendo
    # dir_temp_atualizacao porque _cleanupAtualizacao a le por escopo dinamico.
    local dir_temp_atualizacao="${CFG_PORTALSAV}/${ATU_DIR_TEMP}"
    # "recriar" purga antes: um run interrompido deixa o temporario populado e o
    # unzip sobrescreveria so o que colide, reaproveitando um artefato velho.
    if ! _garantir_diretorio "${dir_temp_atualizacao}" recriar "diretorio temporario"; then
        _erro "Falha ao criar diretorio temporario ${dir_temp_atualizacao}" >&2
        _cleanupAtualizacao
        return 1
    fi

    # Mover arquivos para o diretorio temporario e acessa-lo
    local arquivo
    local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
        if ! mv -f "${CFG_PORTALSAV}/${arquivo}" "${dir_temp_atualizacao}/"; then
            _erro "ERRO: Falha ao mover ${arquivo} para diretorio temporario"
            _cleanupAtualizacao
            return 1
        fi
    done

    if ! cd "${dir_temp_atualizacao}"; then
        _erro "ERRO: Falha ao acessar diretorio temporario"
        _cleanupAtualizacao
        return 1
    fi

    local programa_indice

    # Criar backup dos programas antigos (helper compartilhado com pacotes)
    for programa_indice in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        if ! _backup_programa_antigo "${PROGRAMAS_SELECIONADOS[$programa_indice]}"; then
            _cleanupAtualizacao
            return 1
        fi
    done

    _linha
    _aviso "Backup dos programas efetuado"
    _linha
    _aguardar 1

    # Descompactar e atualizar programas
    local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _erro "Erro ao descompactar ${arquivo}"
            _cleanupAtualizacao
            return 1
        fi
    done

    # SEGURANCA: Validar integridade pos-extracao (cada programa deve ter gerado arquivos)
    local programa_verif
    for programa_verif in "${PROGRAMAS_SELECIONADOS[@]}"; do
        local arquivos_programa=()
        local f_verif
        for f_verif in "${programa_verif}"*."${EXTENSAO_CLASS}" \
                       "${programa_verif}"*."${EXTENSAO_TELAS}"; do
            [[ -e "$f_verif" ]] || continue
            arquivos_programa+=("$f_verif")
        done

        if (( ${#arquivos_programa[@]} == 0 )); then
            _aviso "Nenhum arquivo extraido para ${programa_verif}. Programa ignorado."
            continue
        fi
    done

    # Mover arquivos para diretorios corretos (helper compartilhado com pacotes)
    if ! _mover_arquivos_extraidos; then
        _cleanupAtualizacao
        return 1
    fi

    _linha
    _ok "Atualizando o(s) programa(s)..."
    _linha

    # Arquivar .zip como .bkp em DEFAULT_PROGS_ATUAL_DIR (helper compartilhado com pacotes)
    if ! _arquivar_zips_progs_dir; then
        _cleanupAtualizacao
        return 1
    fi

    # Limpar diretorio temporario e restaurar estado
    _cleanupAtualizacao

    _exibir_mensagem_centralizada "${VERDE}" "Alterando extensao da atualizacao"
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Atualizacao concluida com sucesso!"
    return 0
}

# Processa atualizacao de pacotes
_processar_atualizacao_pacotes() {
    # #3: validacao comum de pre-requisitos (diretorios, backups, arquivos, espaco)
    if ! _validar_pre_requisitos_atualizacao; then
        return 1
    fi

    # #1: salvar cwd para restaurar ao final (evitar vazamento de diretorio)
    local _cwd
    _cwd="$PWD"

    # Cleanup via _cleanupAtualizacao (definida no nivel do modulo)

    # Criar diretorio temporario para extracao isolada
    # Ver _processar_atualizacao_programas: o nome vem de ATU_DIR_TEMP, e nao
    # de um literal repetido.
    local dir_temp_atualizacao="${CFG_PORTALSAV}/${ATU_DIR_TEMP}"
    # "recriar" purga antes: um run interrompido deixa o temporario populado e o
    # unzip sobrescreveria so o que colide, reaproveitando um artefato velho.
    if ! _garantir_diretorio "${dir_temp_atualizacao}" recriar "diretorio temporario"; then
        _erro "Falha ao criar diretorio temporario ${dir_temp_atualizacao}" >&2
        _cleanupAtualizacao
        return 1
    fi

    # Mover pacotes para o diretorio temporario
    local arquivo
    local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
        if ! mv -f "${CFG_PORTALSAV}/${arquivo}" "${dir_temp_atualizacao}/"; then
            _erro "ERRO: Falha ao mover ${arquivo} para diretorio temporario"
            _cleanupAtualizacao
            return 1
        fi
    done

    # Acessar diretorio temporario
    if ! cd "${dir_temp_atualizacao}"; then
        _erro "ERRO: Falha ao acessar diretorio temporario"
        _cleanupAtualizacao
        return 1
    fi

    # Descompactar pacotes no diretorio isolado
    for arquivo in "${_arquivos_prog[@]}"; do
        if ! "${DEFAULT_UNZIP}" -o "${arquivo}" >>"${LOG_ATU}" 2>&1; then
            _erro "Erro ao descompactar ${arquivo}"
            _cleanupAtualizacao
            return 1
        fi
    done

    # SEGURANCA: Validar integridade pos-extracao (cada pacote deve ter gerado arquivos)
    local arquivo_zip lista_arquivos nome_arquivo rc_pacote
    for arquivo_zip in "${_arquivos_prog[@]}"; do
        if [[ ! -f "${arquivo_zip}" ]]; then
            _erro "Pacote nao encontrado apos extracao: ${arquivo_zip}"
            _cleanupAtualizacao
            return 1
        fi

        # Listar conteudo do pacote e verificar se ha arquivos.
        # "unzip -Z1" e a listagem machine-readable (um nome por linha): o
        # "unzip -l | awk" usado antes pegava so a ultima coluna, e um nome de
        # arquivo com espaco ("MEU PROGRAMA.class") virava "PROGRAMA.class" —
        # a checagem de existencia abaixo falhava e abortava um pacote valido.
        # Filtro em puro bash (loop while-read + padrao) substitui o "awk":
        # sem fork externo por zip. O pipeline roda em condicao de "if"
        # (suprime o set -e) e PIPESTATUS[0] diferencia lister ilegivel.
        lista_arquivos=""
        if "${DEFAULT_UNZIP}" -Z1 "${arquivo_zip}" 2>/dev/null | while IFS= read -r nome_arquivo; do
            if [[ "$nome_arquivo" == *.${EXTENSAO_CLASS} || "$nome_arquivo" == *.${EXTENSAO_TELAS} ]]; then
                printf '%s\n' "$nome_arquivo"
            fi
        done > /tmp/.sav_pacote.$$ 2>/dev/null; then
            rc_pacote=0
        else
            rc_pacote=1
        fi
        if [[ -f /tmp/.sav_pacote.$$ ]]; then
            lista_arquivos=$(cat /tmp/.sav_pacote.$$ 2>/dev/null) || lista_arquivos=""
            rm -f /tmp/.sav_pacote.$$ 2>/dev/null || true
        fi
        if (( rc_pacote != 0 )); then
            _erro "Pacote ${arquivo_zip} nao contem arquivos .class ou .TEL validos"
            _cleanupAtualizacao
            return 1
        fi
        if [[ -z "${lista_arquivos}" ]]; then
            _erro "Pacote ${arquivo_zip} nao contem arquivos .class ou .TEL validos"
            _cleanupAtualizacao
            return 1
        fi

        # Verificar se os arquivos listados existem apos extracao
        while IFS= read -r nome_arquivo; do
            if [[ ! -f "${nome_arquivo}" ]]; then
                _erro "Arquivo ${nome_arquivo} extraido do pacote ${arquivo_zip} nao encontrado"
                _cleanupAtualizacao
                return 1
            fi
        done <<< "${lista_arquivos}"
    done

    # Extrair nomes dos programas dos arquivos descompactados e fazer backup dos antigos
    local -A programas_encontrados=()
    local nome_base programa
    local f_pacote
    for f_pacote in *."${EXTENSAO_CLASS}" *."${EXTENSAO_TELAS}"; do
        [[ -e "$f_pacote" ]] || continue
        nome_base="${f_pacote%%.*}"
        programas_encontrados["$nome_base"]=1
    done

    if (( ${#programas_encontrados[@]} == 0 )); then
        _erro "Nenhum arquivo .${EXTENSAO_CLASS}/.${EXTENSAO_TELAS} encontrado nos pacotes"
        _cleanupAtualizacao
        return 1
    fi

    _linha
    _aviso "Programas encontrados nos pacotes:"
    for programa in "${!programas_encontrados[@]}"; do
        _exibir_mensagem_centralizada "${VERDE}" "  - ${programa}"
    done
    _linha

    # Backup dos programas antigos (preserva arquivos atuais em E_EXEC/T_TELAS)
    for programa in "${!programas_encontrados[@]}"; do
        if ! _backup_programa_antigo "${programa}"; then
            _cleanupAtualizacao
            return 1
        fi
    done

    _linha
    _aviso "Backup dos programas efetuado"
    _linha
    _aguardar 1

    # Mover arquivos para diretorios corretos (helper compartilhado com programas)
    if ! _mover_arquivos_extraidos; then
        _cleanupAtualizacao
        return 1
    fi

    _linha
    _ok "Atualizando o(s) programa(s)..."
    _linha

    # Arquivar .zip como .bkp em DEFAULT_PROGS_ATUAL_DIR (helper compartilhado com programas)
    if ! _arquivar_zips_progs_dir; then
        _cleanupAtualizacao
        return 1
    fi

    # Limpar diretorio temporario e restaurar estado
    _cleanupAtualizacao

    _exibir_mensagem_centralizada "${VERDE}" "Alterando extensao da atualizacao"
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Atualizacao concluida com sucesso!"
}

# Processa reversao de programas
_processar_reversao_programas() {
    _garantir_diretorio "${CFG_PORTALSAV}" criar "diretorio de recebimento" || return 1

    local programa_indice programa arquivo_origem arquivo_anterior arquivo_destino
    for programa_indice in "${!PROGRAMAS_SELECIONADOS[@]}"; do
        programa="${PROGRAMAS_SELECIONADOS[$programa_indice]}"
        arquivo_origem="${ARQUIVOS_PROGRAMA[$programa_indice]}"
        arquivo_anterior="${DEFAULT_PROGS_DIR}/${arquivo_origem}"
        arquivo_destino="${CFG_PORTALSAV}/${programa}${compilado}.zip"

        if [[ -f "$arquivo_anterior" ]]; then
            # SEGURANCA: Validar integridade do backup antes de reverter
            # Teste completo (3o parametro=1) independe de C_BACKUP_TESTE_INTEGRIDADE:
            # reverter sobre zip nao validado nao pode depender de otimizacao do backup
            if ! _validar_integridade_backup "$arquivo_anterior" 0 1; then
                _erro "Backup invalido ou corrompido para ${programa}. Reversao abortada."
                return 1
            fi

            if ! mv -f "$arquivo_anterior" "${arquivo_destino}"; then
                _erro "Falha ao preparar backup para reversao de ${programa}"
                return 1
            fi
            # Sem "$" no indice: ARQUIVOS_PROGRAMA e' array indexada (declare -a) e
            # programa_indice e' numerico, entao o subindice e' contexto aritmetico
            # (SC2004). Em array associativa o "$" seria obrigatorio.
            ARQUIVOS_PROGRAMA[programa_indice]="${programa}${compilado}.zip"
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

# Valida integridade de arquivo de backup
# Parametros: $1=arquivo_backup
#            $2=pular_tamanho (1=nao checar tamanho; use apos _validar_backup_criado)
#            $3=teste_profundo (0=somente indice central do zip; 1=unzip -t completo.
#               Default = C_BACKUP_TESTE_INTEGRIDADE)
# O indice central (unzip -Z1) e proporcional ao numero de entradas e nao aos
# dados: detecta zip truncado/invalido sem reler o conteudo. unzip -t relê e
# descomprime o arquivo inteiro (CRC de tudo), praticamente dobrando o tempo.
_validar_integridade_backup() {
    local arquivo_backup="${1:-}"
    local pular_tamanho="${2:-0}"
    local teste_profundo="${3:-${C_BACKUP_TESTE_INTEGRIDADE:-1}}"

    # Verificar se arquivo existe
    if [[ ! -f "${arquivo_backup}" ]]; then
        _erro "Arquivo de backup nao encontrado: ${arquivo_backup}"
        return 1
    fi

    # Verificar tamanho minimo (arquivo zip deve ter pelo menos 22 bytes)
    # Fallback para sistemas sem stat GNU (formato -c)
    if [[ "$pular_tamanho" != "1" ]]; then
        local tamanho
        tamanho=$(stat -c%s "${arquivo_backup}" 2>/dev/null || true)
        if [[ -z "$tamanho" ]]; then
            tamanho=$(stat -f%z "${arquivo_backup}" 2>/dev/null || true)
        fi
        if [[ -z "$tamanho" ]]; then
            tamanho=0
        fi
        # Comparacao so com valor numerico: "stat -f" em GNU pode devolver lixo
        if [[ ! "$tamanho" =~ ^[0-9]+$ ]] || (( tamanho < 22 )); then
            _erro "Arquivo de backup corrompido (tamanho: ${tamanho} bytes): ${arquivo_backup}"
            return 1
        fi
    fi

    if [[ "$teste_profundo" == "0" ]]; then
        # So o indice central: rapido, mas nao confere CRC do conteudo
        if ! "${DEFAULT_UNZIP}" -Z1 "${arquivo_backup}" >/dev/null 2>&1; then
            _erro "Arquivo de backup invalido ou corrompido: ${arquivo_backup}"
            return 1
        fi
    elif ! "${DEFAULT_UNZIP}" -t "${arquivo_backup}" >/dev/null 2>&1; then
        # Testar integridade do arquivo zip (rele e descomprime tudo)
        _erro "Arquivo de backup invalido ou corrompido: ${arquivo_backup}"
        return 1
    fi

    return 0
}

# Faz backup dos arquivos atuais (.class/.TEL) de um programa, com rotacao e validacao
# Reutilizado por _processar_atualizacao_programas e _processar_atualizacao_pacotes
# Parametros: $1=programa
# Retorna: 0 sucesso, 1 falha
_backup_programa_antigo() {
    local programa="${1:-}"
    local arquivo_backup="${DEFAULT_PROGS_DIR}/${programa}-anterior.zip"
    local backup_criado=0

    # Rotacionar backup existente
    if [[ -f "$arquivo_backup" ]]; then
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        if ! mv -f "$arquivo_backup" "${DEFAULT_PROGS_DIR}/${timestamp}-${programa}-anterior.zip"; then
            _erro "ERRO: Falha ao arquivar backup anterior de ${programa}"
            return 1
        fi
    fi

    _exibir_mensagem_centralizada "${AMARELO}" "Salvando programa antigo: ${programa}"

    # Coletar .class e .TEL (programa e seus complementos) num lote unico:
    # um so "zip" para todos (antes 2 invocacoes por programa, 1 por
    # extensao, cada uma reabrindo o zip e pagando 1 fork/exec a mais).
    local arquivos_backup=()
    local f_class
    for f_class in "${E_EXEC}/${programa}"*."${EXTENSAO_CLASS}"; do
        [[ -e "$f_class" ]] || continue
        arquivos_backup+=("$f_class")
    done
    local f_tel
    for f_tel in "${T_TELAS}/${programa}"*."${EXTENSAO_TELAS}"; do
        [[ -e "$f_tel" ]] || continue
        arquivos_backup+=("$f_tel")
    done

    if (( ${#arquivos_backup[@]} > 0 )); then
        if "${DEFAULT_ZIP}" -j "$arquivo_backup" "${arquivos_backup[@]}" >> "${LOG_ATU}" 2>&1; then
            backup_criado=1
        else
            _erro "Falha ao fazer backup dos arquivos de ${programa}"
            return 1
        fi
    fi

    # Validar integridade do backup criado
    if (( backup_criado )); then
        # Teste completo (3o parametro=1) independe de C_BACKUP_TESTE_INTEGRIDADE
        if ! _validar_integridade_backup "$arquivo_backup" 0 1; then
            _erro "CRITICO: Backup criado mas invalido para ${programa}"
            return 1
        fi
        _exibir_mensagem_centralizada "${VERDE}" "Backup validado com sucesso: ${programa}"
    else
        _aviso "Nenhum arquivo antigo (.${EXTENSAO_CLASS}/.${EXTENSAO_TELAS}) encontrado para backup de ${programa}"
    fi

    return 0
}

# Move arquivos extraidos (no cwd atual) para T_TELAS/E_EXEC por extensao
# Reutilizado por _processar_atualizacao_programas e _processar_atualizacao_pacotes
# Retorna: 0 sucesso, 1 falha (erro ja exibido e logado)
# Otimizacao: 1 "mv" por extensao com todo o lote (antes 1 por arquivo) e
# 1 lista de datas via _obter_datas_arquivos, sem trocar os arquivos em disco;
# a saida por arquivo e idade sao preservadas para nao mudar fluxo/saida.
_mover_arquivos_extraidos() {
    local extensao
    for extensao in ".${EXTENSAO_CLASS}" ".${EXTENSAO_TELAS}"; do
        local -a arquivos_encontrados=()
        local f_extraido
        for f_extraido in *"${extensao}"; do
            [[ -e "$f_extraido" ]] || continue
            arquivos_encontrados+=("$f_extraido")
        done

        if (( ${#arquivos_encontrados[@]} > 0 )); then
            local destino="${E_EXEC}/"
            if [[ "${extensao}" == ".${EXTENSAO_TELAS}" ]]; then
                destino="${T_TELAS}/"
            fi
            if ! mv -f "${arquivos_encontrados[@]}" "${destino}" >>"${LOG_ATU}" 2>&1; then
                if [[ "${extensao}" == ".${EXTENSAO_TELAS}" ]]; then
                    _log_erro "Falha ao mover arquivos para ${T_TELAS}/"
                    _erro "Falha ao mover arquivos para ${T_TELAS}/"
                    return 1
                else
                    _log_erro "Falha ao mover arquivos para ${E_EXEC}/"
                    _erro "Falha ao mover arquivos para ${E_EXEC}/"
                    _exibir_mensagem_centralizada "${AMARELO}" "Verifique o log de atualizacao em ${LOG_ATU} para mais detalhes."
                    _exibir_mensagem_centralizada "${AMARELO}" "Use a opcao 4 de reversao para restaurar o programa anterior."
                    return 1
                fi
            fi
            local arquivo
            for arquivo in "${arquivos_encontrados[@]}"; do
                if [[ "${extensao}" == ".${EXTENSAO_TELAS}" ]]; then
                    _exibir_mensagem_centralizada "${VERDE}" "Arquivo ${arquivo} movido com sucesso para ${T_TELAS}/"
                else
                    _log "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                    _exibir_mensagem_centralizada "${VERDE}" "Arquivo ${arquivo} movido com sucesso para ${E_EXEC}/"
                fi
            done
            if [[ "${extensao}" != ".${EXTENSAO_TELAS}" ]]; then
                _obter_datas_arquivos "${arquivos_encontrados[@]}"
            fi
        fi
    done
    return 0
}

# Arquiva os .zip selecionados como .bkp em DEFAULT_PROGS_ATUAL_DIR
# Reutilizado por _processar_atualizacao_programas e _processar_atualizacao_pacotes
# Retorna: 0 sucesso, 1 falha (apenas se o diretorio nao puder ser criado)
_arquivar_zips_progs_dir() {
    _garantir_diretorio "${DEFAULT_PROGS_ATUAL_DIR}" criar "diretorio de programas" || return 1
    local arquivo
    local -a _arquivos_prog=("${ARQUIVOS_PROGRAMA[@]}"); for arquivo in "${_arquivos_prog[@]}"; do
        local backup_file="${arquivo%.zip}.bkp"
        if ! mv -f "${arquivo}" "${DEFAULT_PROGS_ATUAL_DIR}/${backup_file}" >>"${LOG_ATU}" 2>&1; then
            _log_erro "Falha ao arquivar ${arquivo} em ${DEFAULT_PROGS_ATUAL_DIR}/${backup_file}"
            _aviso "Falha ao arquivar ${arquivo} em ${DEFAULT_PROGS_ATUAL_DIR}. O arquivo sera removido."
        fi
    done
    return 0
}

# Obtem data de modificacao do arquivo
_obter_data_arquivo() {
    local arquivo="${1:-}" # Nome do arquivo
    if [[ -f "${E_EXEC}/${arquivo}" ]]; then
        # Inicializadas vazias: se AMBOS os "stat" falharem (corrida em que o
        # arquivo some entre o "-f" e o stat, ou stat sem "-c"), data_formatada
        # nunca era atribuida e o [[ -n "$data_formatada" ]] abaixo disparava
        # "unbound variable" sob set -u, abortando o programa inteiro.
        local data_modificacao="" data_formatada=""
        data_modificacao=$(stat -c %y "${E_EXEC}/${arquivo}" 2>/dev/null)
        if [[ -n "$data_modificacao" ]]; then
            # Reformatacao "AAAA-MM-DD HH:MM:SS..." -> "DD/MM/AAAA HH:MM:SS" via substring (sem fork de date)
            data_formatada="${data_modificacao:8:2}/${data_modificacao:5:2}/${data_modificacao:0:4} ${data_modificacao:11:8}"
        else
            # Fallback para sistemas sem stat GNU (data epoch em segundos)
            local epoch
            epoch=$(stat -f %m "${E_EXEC}/${arquivo}" 2>/dev/null)
            if [[ -n "$epoch" ]]; then
                data_formatada=$(date -d "@${epoch}" +"%d/%m/%Y %H:%M:%S" 2>/dev/null || true)
            fi
        fi
        if [[ -n "$data_formatada" ]]; then
            _exibir_mensagem_centralizada "${VERDE}" "Nome do programa: ${arquivo}"
            _exibir_mensagem_centralizada "${AMARELO}" "Data do programa: ${data_formatada}"
        fi
    fi
}

# Obtem datas de varios arquivos com 1 "stat" para o lote (GNU) em vez de
# 1 fork por arquivo. Mantem o fallback por arquivo para BSD/sstat.
_obter_datas_arquivos() {
    local -a _arquivos=("$@")
    if (( ${#_arquivos[@]} == 0 )); then
        return 0
    fi
    local -a caminhos=()
    local _arq
    for _arq in "${_arquivos[@]}"; do
        if [[ -f "${E_EXEC}/${_arq}" ]]; then
            caminhos+=("${E_EXEC}/${_arq}")
        fi
    done
    if (( ${#caminhos[@]} == 0 )); then
        return 0
    fi
    local linha data_modificacao data_formatada epoch nome_lote data_lote
    local -a linhas=()
    mapfile -t linhas < <(stat -c '%n|%y' "${caminhos[@]}" 2>/dev/null) || linhas=()
    if (( ${#linhas[@]} > 0 )); then
        for linha in "${linhas[@]}"; do
            nome_lote="${linha%%|*}"
            data_modificacao="${linha#*|}"
            data_formatada="${data_modificacao:8:2}/${data_modificacao:5:2}/${data_modificacao:0:4} ${data_modificacao:11:8}"
            if [[ -n "$data_formatada" ]]; then
                _exibir_mensagem_centralizada "${VERDE}" "Nome do programa: ${nome_lote##*/}"
                _exibir_mensagem_centralizada "${AMARELO}" "Data do programa: ${data_formatada}"
            fi
        done
        return 0
    fi
    # Fallback BSD: 1 stat por arquivo (igual ao legado por arquivo).
    for _arq in "${_arquivos[@]}"; do
        epoch=$(stat -f %m "${E_EXEC}/${_arq}" 2>/dev/null) || epoch=""
        if [[ -n "$epoch" ]]; then
            data_lote=$(date -d "@${epoch}" +"%d/%m/%Y %H:%M:%S" 2>/dev/null || true)
            if [[ -n "$data_lote" ]]; then
                _exibir_mensagem_centralizada "${VERDE}" "Nome do programa: ${_arq}"
                _exibir_mensagem_centralizada "${AMARELO}" "Data do programa: ${data_lote}"
            fi
        fi
    done
    return 0
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
