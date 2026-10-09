#!/usr/bin/env bash
set -euo pipefail
#
# biblioteca.sh - Modulo de Gestao de Biblioteca
# Responsavel pela atualizacao das bibliotecas do sistema (Transpc, Savatu)
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 09/10/2026-01
#
declare pids=()                                     # Array global para rastrear PIDs de background
declare ATUALIZA1="" ATUALIZA2="" ATUALIZA3=""      # Variaveis de artefatos
declare LISTA_ARQUIVOS_BIBLIOTECA=""                # Lista de arquivos, separada por espaco

# Teto de programas aceitos na reversao individual. A entrada virou lista
# (espaco/virgula/ponto-e-virgula) e cada nome vira um argumento do
# --wildcards do tar: sem teto, uma linha colada viraria command line enorme.
declare MAX_PROGRAMAS_REVERTER="${MAX_PROGRAMAS_REVERTER:-20}"

# Funcao de cleanup em caso de interrupcao
_limpar_interrupcao() {
    local sinal="${1:-}"
    _log "Interrupcao detectada (sinal: $sinal). Limpando processos..."

    # Matar todos os PIDs pendentes
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            _log "Processo PID $pid interrompido"
        fi
    done
    pids=()  # Limpar array

    # Limpeza de temporarios por caminhos absolutos: nao altera o cwd ativo.
    # Os downloads ficam em CFG_PORTALSAV (nao em SCRIPT_DIR); o backup fica em
    # DEFAULT_BIBLIOTECA_DIR e nunca e apagado aqui (pode ser necessario rollback).
    if [[ -n "${VERSAO:-}" && -n "${CFG_PORTALSAV:-}" ]]; then
        while IFS= read -r -d '' arquivo_temp; do
            rm -f -- "$arquivo_temp"
            _log "Arquivo temporario removido: $arquivo_temp"
        done < <("${DEFAULT_FIND}" "${CFG_PORTALSAV}" -maxdepth 1 -type f \( -name "*${VERSAO}.zip" -o -name "*${VERSAO}.tar" -o -name "*${VERSAO}.tar.gz" \) -print0)
    fi

    # Verificar se backup desta versao existe e sugerir rollback, sem alterar nullglob.
    # Prefixo correto e "backup_" (singular); -name ".*" cobre .tar, .tar.gz e .zip.
    local -a backups_parciais=()
    if [[ -n "${VERSAO:-}" ]]; then
        while IFS= read -r -d '' arquivo_backup; do
            backups_parciais+=("$arquivo_backup")
        done < <("${DEFAULT_FIND}" "${DEFAULT_BIBLIOTECA_DIR}" -maxdepth 1 -type f -name "backup_biblioteca_antes_da_versao-${VERSAO}.*" -print0)
    fi
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

    # Antes: `if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]` sem ramo ELSE. Com a flag
    # vazia/invalida o bloco inteiro era pulado e o fluxo seguia para
    # _baixar_biblioteca_sincroniza — ou seja, uma atualizacao OFF-LINE
    # disparava descarga pela REDE e sem a checagem de espaco em disco abaixo.
    if ! _offline_valido; then
        _offline_erro "atualizacao de biblioteca"
        _aguardar_tecla
        return 1
    fi

    if [[ "${CFG_OFFLINE}" == "s" ]]; then
        _linha
        _exibir_mensagem_centralizada "${AMARELO}" "Parametro de biblioteca do servidor OFF ativo"
        _linha
        _aviso "Use a opcao 2 (Atualizacao OFF-Line) com os arquivos ja em ${CFG_PORTALSAV}."
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

    # Antes: o mesmo `if ... =~ ^[sn]$` sem ELSE. Com a flag invalida a funcao
    # chegava ao fim e devolvia 0 — sucesso sem ter feito NADA, sem mensagem.
    if ! _offline_valido; then
        _offline_erro "atualizacao off-line de biblioteca"
        _aguardar_tecla
        return 1
    fi

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
    _garantir_diretorio "${CFG_PORTALSAV}" criar "diretorio de recebimento" || return 1
    cd "$CFG_PORTALSAV" || return 1

    _definir_variaveis_biblioteca

    local -a arquivos_update
    read -ra arquivos_update <<< "$LISTA_ARQUIVOS_BIBLIOTECA"

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
    read -ra arquivos_verificar <<< "$LISTA_ARQUIVOS_BIBLIOTECA"

    for arquivo in "${arquivos_verificar[@]}"; do
        if [[ ! -r "${arquivo}" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Atualizacao nao encontrada ou incompleta: ${arquivo}"
            _linha
            _aguardar_tecla
            return 1
        fi
    done

    # SEGURANCA: validar as entradas de cada pacote ANTES de qualquer extracao.
    # Aqui a checagem e obrigatoria, e nao apenas defensiva: o unzip desta
    # atualizacao roda com "-d ${principal_local}", que em producao e "/" (RAIZ
    # termina em /sav). O UnZip nao bloqueia escape por sozinho nesse caso —
    # ele so avisa "stripped absolute path spec" e, com -d /, o "strip" equivale
    # a escrever no caminho absoluto. Verificado com UnZip 6.00: uma entrada
    # "/etc/x" no ZIP e criada em /etc/x. Ja a entrada "../" e barrada pelo
    # proprio unzip ("skipped ../ path component(s)").
    #
    # A validacao fica aqui, e nao junto do unzip, porque este e o portao UNICO
    # dos tres fluxos de atualizacao de biblioteca (online, offline e
    # _processar_biblioteca_offline chamam todos _salvar_atualizacao_biblioteca):
    # barrar antes de _processar_atualizacao_biblioteca evita compactar o
    # backup da versao atual e entrar nos diretorios de destino. Para pacote
    # legitimo nada muda — o validador e silencioso.
    for arquivo in "${arquivos_verificar[@]}"; do
        if ! _validar_backup_entradas_seguras "${CFG_PORTALSAV}/${arquivo}"; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Atualizacao abortada: pacote com entradas inseguras: ${arquivo}"
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

    # Remove SO o .tar parcial de uma execucao anterior. O .tar.gz (o backup que
    # o usuario usa para voltar) fica no disco ate o gzip sobrescrever: se a
    # compactacao falhar, a biblioteca ainda tem ponto de volta.
    rm -f -- "${arquivo_backup_tar}"

    # Compactacao de E_EXEC + T_TELAS em uma unica passada.
    #
    # ESCOPO: o backup leva SOMENTE os dois diretorios da configuracao
    # (em producao /u/sav/classes e /u/sav/tel_isc). A pasta acima deles - a
    # anterior ao /classes - tambem contem o programa, o portal de atualizacao,
    # o savisc e as demais bases; varrer a arvore inteira ali traria arquivos
    # que nao sao da biblioteca. Para incluir outra pasta da biblioteca, acrescente
    # um find nesta lista (com o filtro de extensao certo), e nao a subtree.
    #
    # (lista via stdin evita a regravacao incremental do tar -rf por lote)
    {
        {
            # find devolve 1 em "Permission denied" numa subpasta e ainda assim
            # entrega a lista util; quem decide o sucesso e o tar (logo abaixo).
            # O stderr vai para o log para nao rabiscar a barra de progresso.
            "${DEFAULT_FIND}" "${E_EXEC}/" -type f \( -iname "*.class" -o -iname "*.jpg" -o -iname "*.png" -o -iname "brw*.*" -o -iname "*." -o -iname "*.dll" \) -print0 2>>"${LOG_ATU}" || true
            "${DEFAULT_FIND}" "${T_TELAS}/" -type f -iname "*.TEL" -print0 2>>"${LOG_ATU}" || true
        } | "${DEFAULT_TAR}" --null -cf "${arquivo_backup_tar}" -T - >>"${LOG_ATU}" 2>&1
    } &
    local pid_tar_exec=$!
    pids+=("$pid_tar_exec")  # Registrar PID para trap
    if _mostrar_progresso_backup "$pid_tar_exec" "Compactando $E_EXEC e $T_TELAS"; then
        local novos=()
        for _p in "${pids[@]}"; do [[ "$_p" != "$pid_tar_exec" ]] && novos+=("$_p"); done
        pids=("${novos[@]+"${novos[@]}"}")
        ((contador++)) || true

        # Guarda: tar criado e vazio nao pode virar backup. Sem ela, um E_EXEC
        # apagado ou trocado no .config deixaria a biblioteca atual
        # sobrescrita sem nenhuma volta possivel.
        local _primeiro_membro
        _primeiro_membro=$("${DEFAULT_TAR}" -tf "${arquivo_backup_tar}" 2>>"${LOG_ATU}" | head -n 1) || true
        if [[ -z "$_primeiro_membro" ]]; then
            _erro "Backup vazio: nenhum arquivo encontrado em ${E_EXEC} nem em ${T_TELAS}"
            _aviso "Confira se E_EXEC e T_TELAS apontam para os diretorios certos no .config"
            _aguardar 2
            return 1
        fi

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
        _erro "Diretorio ${CFG_PORTALSAV:-} nao configurado"
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
    read -ra arquivos_update <<< "$LISTA_ARQUIVOS_BIBLIOTECA"
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
            if _mostrar_progresso_backup "$pid_unzip" "Descompactando ${arquivo}"; then
                _exibir_mensagem_centralizada "${VERDE}" "Descompactacao de ${arquivo} concluida com sucesso"
                ((contador++)) || true
            else
                _erro "Ao descompactar ${arquivo} - Verifique o log ${LOG_ATU}"
                _aguardar 2
                return 1
            fi
            _linha
            _aguardar 1
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
# Uso: _extrair_backup_biblioteca <arquivo_backup> <destino> [padrao ...]
#
# Aceita VARIOS padroes: a reversao individual restaura mais de um programa por
# vez e cada nome vira um argumento (--wildcards no tar, filtro de nome no
# unzip). Sem padrao, extrai o backup inteiro.
_extrair_backup_biblioteca() {
    local arquivo_backup="${1:-}"
    local destino="${2:-}"
    # Os padroes sao os argumentos a partir do terceiro; com menos de dois
    # argumentos nao ha padrao (restauracao completa).
    if (( $# >= 2 )); then
        shift 2
    else
        shift $#
    fi
    local -a padroes=("$@")

    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        if (( ${#padroes[@]} > 0 )); then
            "${DEFAULT_TAR}" -xzf "$arquivo_backup" -C "$destino" --wildcards "${padroes[@]}" >>"${LOG_ATU}" 2>&1
        else
            "${DEFAULT_TAR}" -xzf "$arquivo_backup" -C "$destino" >>"${LOG_ATU}" 2>&1
        fi
    elif (( ${#padroes[@]} > 0 )); then
        "${DEFAULT_UNZIP}" -o "$arquivo_backup" "${padroes[@]}" -d "$destino" >>"${LOG_ATU}" 2>&1
    else
        "${DEFAULT_UNZIP}" -o "$arquivo_backup" -d "$destino" >>"${LOG_ATU}" 2>&1
    fi
}

# Reverte biblioteca completa
_reverter_biblioteca_completa() {
    local arquivo_backup="${1:-}"
    if [[ ! -r "$arquivo_backup" ]]; then
        _erro "Backup nao encontrado ou ilegivel"
        return 1
    fi

    if ! _validar_backup_entradas_seguras "$arquivo_backup"; then
        _erro "Restauracao bloqueada: backup contem caminhos inseguros (path traversal ou absolutos)"
        _aguardar_tecla
        return 1
    fi

    local temp_restore="/"
    # O backup cobre os dois diretorios da configuracao (producao:
    # /u/sav/classes e /u/sav/tel_isc) e volta tudo de uma vez. Extrai na raiz
    # porque o tar remove a barra inicial do nome do membro e o caminho guardado
    # so casa com "/".
    _exibir_mensagem_centralizada "${AMARELO}" "Voltando backup anterior (TAR)..."
    _linha
    _aviso "Restaurando todos os programas de ${E_EXEC} e ${T_TELAS}"
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

# Reverte programa(s) especifico(s) da biblioteca
#
# Aceita MAIS DE UM programa na mesma volta, separados por espaco, virgula ou
# ponto e virgula ("VENDPROD VENDCAD,CLIENTES"). Todos entram em uma unica
# leitura do backup, cada nome virando um argumento do --wildcards do tar.
# Parametros: $1=arquivo_backup
_reverter_programa_especifico_biblioteca() {
    local arquivo_backup="${1:-}"
    local entrada_programas
    local temp_restore="/"

    if [[ ! -r "$arquivo_backup" ]]; then
        _erro "Backup nao encontrado ou ilegivel"
        return 1
    fi
    #SEGURANÇA CRÍTICA: Validar entradas do backup ANTES de extrair
    if ! _validar_backup_entradas_seguras "$arquivo_backup"; then
        _erro "Restauracao bloqueada: backup contem caminhos inseguros"
        _aguardar_tecla
        return 1
    fi
    # Extrai na raiz porque o backup guarda os caminhos de E_EXEC e T_TELAS
    # (producao: /u/sav/classes e /u/sav/tel_isc).
    read -rp "${AMARELO}Informe o(s) programa(s) em MAIUSCULO, separados por espaco ou virgula: ${NORMAL}" entrada_programas

    # read -a fatia por IFS SEM expansao de pathname: um "*" colado na entrada
    # nao vira a lista do diretorio de trabalho.
    local -a entradas=()
    IFS=$' \t,;' read -r -a entradas <<< "${entrada_programas}"

    local -a programas=()
    local _nome
    for _nome in ${entradas[@]+"${entradas[@]}"}; do
        _nome="${_nome^^}"
        if ! _validar_nome_programa "$_nome"; then
            _erro "Nome de programa invalido: ${_nome}. Use apenas letras maiusculas e numeros."
            _aguardar_tecla
            return 1
        fi
        programas+=("$_nome")
    done

    if (( ${#programas[@]} == 0 )); then
        _erro "Nenhum programa informado"
        _aguardar_tecla
        return 1
    fi

    if (( ${#programas[@]} > MAX_PROGRAMAS_REVERTER )); then
        _erro "Informe no maximo ${MAX_PROGRAMAS_REVERTER} programas por vez (informados: ${#programas[@]})"
        _aguardar_tecla
        return 1
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Voltando versao anterior de ${#programas[@]} programa(s) (TAR)..."
    _linha

    # Confere os nomes no indice do backup antes de extrair: o tar devolve 0
    # mesmo sem extrair nenhum membro, entao sem esta checagem um nome
    # digitado errado terminava em "Volta Concluida" sem ter restaurado nada.
    local _membros
    _membros="$(_listar_entradas_backup "$arquivo_backup")" || _membros=""

    local -a programas_ok=()
    local -a programas_ausentes=()
    for _nome in "${programas[@]}"; do
        if [[ -n "$_membros" ]] && grep -qF -- "${_nome}" <<<"${_membros}"; then
            programas_ok+=("$_nome")
        else
            programas_ausentes+=("$_nome")
        fi
    done

    if (( ${#programas_ausentes[@]} > 0 )); then
        _exibir_mensagem_centralizada "${AMARELO}" "Nao encontrado(s) no backup: ${programas_ausentes[*]}"
        _linha
    fi

    if (( ${#programas_ok[@]} == 0 )); then
        _erro "Nenhum dos programas informados existe neste backup"
        _aguardar_tecla
        return 1
    fi

    # Padroes: o nome casa em qualquer das pastas do backup (classes e telas).
    # O prefixo por barra do ZIP legado foi mantido - ele tambem casa com o
    # nome do membro gravado sem caminho.
    local -a padroes=()
    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        for _nome in "${programas_ok[@]}"; do
            padroes+=("*${_nome}*")
        done
    else
        for _nome in "${programas_ok[@]}"; do
            padroes+=("*/${_nome}*")
        done
    fi

    if ! _extrair_backup_biblioteca "$arquivo_backup" "$temp_restore" "${padroes[@]}"; then
        _erro "Ao descompactar programa(s) ${programas_ok[*]}"
        _aguardar_tecla
        return 1
    fi

    _log "Reversao de biblioteca: ${programas_ok[*]} restaurado(s) de ${arquivo_backup##*/}" "${LOG_ATU}"
    _aviso "Volta do Programa Concluida"
    _aguardar_tecla
}

#---------- FUNCOES AUXILIARES ----------#
# Lista os membros de um backup (TAR.GZ ou ZIP) sem extrair nada.
# Uso: _listar_entradas_backup <arquivo_backup>
# Retorna: 0 com a lista em stdout; 1 se o backup nao pode ser lido.
#
# utils.sh tem a variante que VALIDA as entradas
# (_validar_backup_entradas_seguras); aqui a lista volta para o chamador
# conferir se o programa pedido existe no backup antes de extrair.
_listar_entradas_backup() {
    local arquivo_backup="${1:-}"

    if [[ -z "$arquivo_backup" || ! -r "$arquivo_backup" ]]; then
        return 1
    fi

    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        "${DEFAULT_TAR}" -tzf "$arquivo_backup" 2>/dev/null
    else
        "${DEFAULT_UNZIP}" -Z1 "$arquivo_backup" 2>/dev/null
    fi
}

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
# Monta tambem LISTA_ARQUIVOS_BIBLIOTECA (nomes separados por espaco) para os
# callers fazerem `read -ra x <<< "$LISTA_ARQUIVOS_BIBLIOTECA"` sem fork.
# Antes a lista era obtida por `$(_obter_arquivos_atualizacao)`: um subshell por
# chamada (3x em biblioteca.sh + 1x em vaievem.sh) so para concatenar 3
# variaveis que ja estavam em memoria.
_definir_variaveis_biblioteca() {
    ATUALIZA1="${SAVATU1:-}${VERSAO}.zip"
    ATUALIZA2="${SAVATU2:-}${VERSAO}.zip"
    ATUALIZA3="${SAVATU3:-}${VERSAO}.zip"
    LISTA_ARQUIVOS_BIBLIOTECA="${ATUALIZA1} ${ATUALIZA2} ${ATUALIZA3}"
}
