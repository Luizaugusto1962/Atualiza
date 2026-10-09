#!/usr/bin/env bash
set -euo pipefail
#
# backup.sh - Modulo do Sistema de Backup
# Responsavel por backup completo, incremental e restauracao
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 09/10/2026-01

# Variaveis globais esperadas
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Caminho do diretorio base principal.
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"              # Caminho do diretorio da segunda base de dados.
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"              # Caminho do diretorio da terceira base de dados.
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip)
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)

# Estado interno compartilhado entre _coletar_arquivos_backup e _compactar_backup
# (globais de proposito: sem declare -g, compativel com Bash 4.0+)
_BACKUP_LISTA=()   # arquivos a compactar (relativos ao diretorio base)
_BACKUP_BYTES=0    # soma dos tamanhos em bytes dos arquivos da lista

# NOTA: trap INT/TERM registrado dentro de _executar_backup() e restaurado ao final
_limpar_backup() {
    _log "Backup interrompido. Limpando temporarios..."
    # Matar processo de backup em background se ainda estiver rodando
    if [[ -n "${BACKUP_PID:-}" ]] && kill -0 "$BACKUP_PID" 2>/dev/null; then
        kill "$BACKUP_PID" 2>/dev/null || true
        wait "$BACKUP_PID" 2>/dev/null || true
    fi
    # Remover arquivos parciais com validacao de caminho seguro
    if [[ -n "${DEFAULT_BASEBACKUP_DIR:-}" ]] && _validar_caminho_seguro "${DEFAULT_BASEBACKUP_DIR}"; then
        rm -f -- "${DEFAULT_BASEBACKUP_DIR}"/*.zip.tmp 2>/dev/null || true
        # Lista de arquivos montada por _coletar_arquivos_backup (orfa em SIGINT)
        rm -f -- "${DEFAULT_BASEBACKUP_DIR}"/.lista_backup_*.tmp 2>/dev/null || true
    fi
    # Remover zip parcial caso exista
    if [[ -n "${CAMINHO_BACKUP:-}" ]] && _validar_caminho_seguro "${CAMINHO_BACKUP}"; then
        rm -f -- "$CAMINHO_BACKUP" 2>/dev/null || true
    fi
}

# Exclui diretorios restauracao_* gerados durante o processo de restauracao
_limpar_restauracao() {
    if [[ -z "${DEFAULT_BASEBACKUP_DIR:-}" ]] || ! _validar_caminho_seguro "${DEFAULT_BASEBACKUP_DIR}"; then
        return 0
    fi
    local dir
    for dir in "${DEFAULT_BASEBACKUP_DIR}"/restauracao_*; do
        if [[ -d "$dir" ]]; then
            rm -rf -- "$dir" 2>/dev/null || true
            _log "Diretorio temporario removido: $dir" || true
        fi
    done
}

#---------- FUNCOES PRINCIPAIS DE backup ----------#
# Valida pre-requisitos comuns antes de executar qualquer backup
# Parametros: $1=base_trabalho (por referencia, sera definida pela funcao)
# Retorna: 0 se valido, 1 se erro
_validar_pre_backup() {

    local var_name="${1:-}"
    if [[ -z "$var_name" ]]; then
        _erro "Erro interno: nome da variavel nao informado em _validar_pre_backup"
        return 1
    fi
    
    # Validar que o nome da variável é um identificador bash válido
    if [[ ! "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        _erro "Erro interno: nome de variavel invalido: ${var_name}"
        return 1
    fi
    
    # Compatibilidade: local -n exige Bash 4.4+; ${!var} funciona em 4.2+
 #   local _base_ref="${!1}"
    local _base_ref="${!var_name:-}"

    # Validar comando de compactacao
    if [[ -z "$DEFAULT_ZIP" ]]; then
        _erro "Comando de compactacao nao configurado"
        _aguardar 3
        return 1
    fi

    if ! command -v "$DEFAULT_ZIP" &>/dev/null; then
        _erro "Comando '$DEFAULT_ZIP' nao disponivel no sistema"
        _aguardar 3
        return 1
    fi

    # Escolher base se necessario
    if [[ -n "${CFG_BASE_DIR2}" ]]; then
        _menu_escolha_base || return 1
        if [[ -z "${base_trabalho}" ]]; then
            _linha
            _erro "Base de trabalho nao foi selecionada"
            _linha
            _aguardar 2
            return 1
        fi
        _base_ref="${base_trabalho}"
    else
        if [[ -z "${CFG_BASE_DIR}" ]]; then
            _erro "CFG_BASE_DIR nao configurado"
            _aguardar 3
            return 1
        fi    
        _base_ref="${RAIZ}${CFG_BASE_DIR}"
    fi

    # VALIDAÇÃO: Verificar se base_ref não está vazia antes de prosseguir
    if [[ -z "$_base_ref" ]]; then
        _erro "Erro interno: base de trabalho vazia apos selecao"
        return 1
    fi
    
    # SEGURANÇA: Validar caminho da base contra traversal
    if ! _validar_caminho_seguro "$_base_ref"; then
        _erro "Caminho da base invalido ou malicioso: ${_base_ref}"
        _aguardar 3
        return 1
    fi
    
    # Devolver valor ao chamador (nameref manual, compativel com Bash 4.2+)
    printf -v "$var_name" '%s' "${_base_ref}"
    
    # Devolver valor ao chamador (nameref manual, compativel com Bash 4.2+)
#    printf -v "$1" '%s' "${_base_ref}"

    # Validar se o diretorio base existe
    if [[ ! -d "${_base_ref}" ]]; then
        _erro "Diretorio base '${_base_ref}' nao existe"
        _aguardar 3
        return 1
    fi

    # VALIDAÇÃO: Verificar DEFAULT_BASEBACKUP_DIR antes de usar
    if [[ -z "${DEFAULT_BASEBACKUP_DIR:-}" ]]; then
        _erro "DEFAULT_BASEBACKUP_DIR nao configurado"
        _aguardar 3
        return 1
    fi
    
    if ! _validar_caminho_seguro "$DEFAULT_BASEBACKUP_DIR"; then
        _erro "Diretorio de backup invalido ou malicioso: ${DEFAULT_BASEBACKUP_DIR}"
        _aguardar 3
        return 1
    fi
    
    # Verificar se o diretorio de backup existe
    if [[ ! -d "$DEFAULT_BASEBACKUP_DIR" ]]; then
        _exibir_mensagem_centralizada "${AMARELO}" "Diretorio de backups em $DEFAULT_BASEBACKUP_DIR nao encontrado..."
        _aguardar 3
        return 1
    fi

    # NOTA: a checagem de espaco em disco NAO e feita aqui de proposito.
    # Estimar aqui exigiria "du -sk" (varredura completa da base) ANTES de
    # listar os arquivos, e o resultado seria uma estimativa grosa: a base
    # muda entre a estimate e o zip (e a limpeza de temporarios roda no meio).
    # A verificacao precisa, feita sobre a lista real, esta em _compactar_backup.

    return 0
}

# Executa backup do sistema
_executar_backup() {
    local base_trabalho=""
    local ano_agora
    ano_agora=$(date +%Y)

    # Registrar trap local apenas durante o backup
    trap '_limpar_backup; trap - INT TERM' INT TERM
#    trap 'rm -f "${DEFAULT_BASEBACKUP_DIR}"/*.zip.tmp 2>/dev/null; trap - INT TERM' INT TERM

    # Validar pre-requisitos e definir base_trabalho
    if ! _validar_pre_backup base_trabalho; then
        trap '_encerrar_programa 130' INT TERM
        return 1
    fi

    # Exportar para uso em subfuncoes
    export BASE_TRABALHO="$base_trabalho"

    # Escolher tipo de backup
    _menu_tipo_backup
    if [[ -z "$tipo_backup" ]]; then
        trap '_encerrar_programa 130' INT TERM
        return 0
    fi

    # Gerar nome do arquivo
    local nome_backup nome_base_dir caminho_backup
    nome_base_dir="${base_trabalho##*/}"
    nome_backup="${CFG_EMPRESA}_${tipo_backup}_${nome_base_dir}_$(date +%Y%m%d%H%M%S).zip"
    caminho_backup="${DEFAULT_BASEBACKUP_DIR}/$nome_backup"
    export CAMINHO_BACKUP="$caminho_backup"
    export BACKUP_PID=""

    # Verificar backups recentes
    if _verificar_backups_recentes; then
        if ! _confirmar "Ja existe backup recente. Deseja continuar?" "N"; then
            trap '_encerrar_programa 130' INT TERM
            _exibir_mensagem_centralizada "$VERMELHO" "Operacao cancelada"
            _aguardar 3
            return 0
        fi
        _linha
        _exibir_mensagem_centralizada "$AMARELO" "Sera criado backup adicional"
    fi

    # Mudar para diretorio base
    if ! _diretorio_trabalho; then
        trap '_encerrar_programa 130' INT TERM
        _erro "Ao acessar diretorio de trabalho"
        _aguardar 3
        return 0
    fi
    _linha
    _exibir_mensagem_centralizada "$AMARELO" "Verificando arquivos temporarios ..."
    _linha

    # Executar limpeza de temporarios antes do backup (modo automatico: so a base do backup, sem pausas)
    # _tentar_log em vez de "|| true": o backup nao pode ser bloqueado pela
    # limpeza, mas a falha precisa ficar registrada. Ver _tentar_log (utils.sh)
    # sobre o errexit ficar suspenso em qualquer chamada tolerante a falha.
    _tentar_log "limpeza automatica de temporarios" "${LOG_LIMPA}" _executar_limpeza_temporarios automatico

    _linha
    _exibir_mensagem_centralizada "$AMARELO" "Criando Backup da pasta: ${base_trabalho}..."
    _linha
    # BACKUP_PID ja exportada como variavel global

    # === LOGICA ESPECIAL PARA backup INCREMENTAL: PEDIR ENTRADA ANTES DO & ===
    if [[ "$tipo_backup" == "incremental" ]]; then
        local mes ano data_referencia

        _linha
        _exibir_mensagem_centralizada "$AMARELO" "Digite o mes (01-12) e ano (Ex: $ano_agora) para o backup incremental:"
        _linha

        read -rp "${AMARELO}Mes (MM): ${NORMAL}" mes
        _linha
        read -rp "${AMARELO}Ano (AAAA): ${NORMAL}" ano
        _linha

        # Validar entrada
        if ! [[ "$mes" =~ ^(0[1-9]|1[0-2])$ ]] || ! [[ "$ano" =~ ^[0-9]{4}$ ]]; then
            trap '_encerrar_programa 130' INT TERM
            _erro "Mes ou ano invalido. Use formato MM (01-12) e YYYY."
            _aguardar 2
            return 0
        fi

        # Validar ano nao seja muito antigo ou futuro
        if (( 10#$ano < 1990 || 10#$ano > ano_agora )); then
            trap '_encerrar_programa 130' INT TERM
            _erro "Ano fora do intervalo valido (1990-$ano_agora)"
            _aguardar 2
            return 0
        fi

        data_referencia="${ano}-${mes}-01"
        local data_atual
        data_atual=$(date +%Y%m%d)
        local data_input
        data_input=$(date -d "$data_referencia" +%Y%m%d 2>/dev/null) || {
            trap '_encerrar_programa 130' INT TERM
            _erro "Data invalida."
            _aguardar 2
            return 0
        }

        if [[ "$data_input" -gt "$data_atual" ]]; then
            trap '_encerrar_programa 130' INT TERM
            _erro "A data nao pode ser futura."
            _aguardar 2
            return 0
        fi

        # Agora sim, executar o backup incremental em background
        _executar_backup_arquivo "$caminho_backup" "incremental" "$data_referencia" &
        BACKUP_PID=$!

    else
        # Backup completo: executa diretamente em background
        _executar_backup_arquivo "$caminho_backup" "completo" &
        BACKUP_PID=$!
    fi

    # Mostrar barra de progresso e capturar resultado (wait ja feito internamente)
    local resultado=0
    _mostrar_progresso_backup "$BACKUP_PID" "Backup em andamento"|| resultado=$?

    if [[ $resultado -eq 0 ]] && [[ -f "$caminho_backup" ]]; then
        _finalizar_backup_sucesso "$nome_backup"
    elif [[ $resultado -eq 2 ]]; then
        # Codigo 2: nenhum arquivo modificado (caso esperado para incremental)
        trap '_encerrar_programa 130' INT TERM
        _aviso "Nenhum arquivo modificado desde a data de referencia"
        _aguardar 3
        return 0
    elif [[ $resultado -eq 3 ]]; then
        # Codigo 3: zip integro, mas com arquivos que nao puderam ser lidos
        trap '_encerrar_programa 130' INT TERM
        _finalizar_backup_parcial "$nome_backup"
        if ! _confirmar "Manter o backup parcial?" "S"; then
            if rm -f -- "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}"; then
                _exibir_mensagem_centralizada "$VERMELHO" "Backup parcial excluido"
            fi
        fi
    else
        trap '_encerrar_programa 130' INT TERM
        _erro "Erro ao criar backup"
        _aguardar 3
        return 1
    fi

    # Perguntar sobre envio
    if _confirmar "Deseja enviar backup para servidor?" "N"; then
        _enviar_backup_servidor "$nome_backup"
    fi

    # Restaurar trap original ao encerrar o backup
    trap '_encerrar_programa 130' INT TERM
}

# Restaura backup do sistema
_restaurar_backup() {
    # Seleciona o backup usando a rotina unica
    if ! _selecionar_backup; then
        return 0
    fi

    trap '_limpar_restauracao; trap - INT TERM' INT TERM

    local _resultado=0

    # Prossegue com a logica de restauracao (completa ou parcial)
    if _confirmar "Deseja restaurar TODOS os arquivos do backup?" "N"; then
        _restaurar_backup_completo "$backup_selecionado" || _resultado=$?
    else
        _restaurar_arquivo_especifico "$backup_selecionado" || _resultado=$?
    fi

    _limpar_restauracao
    trap '_encerrar_programa 130' INT TERM
    return $_resultado
}

_enviar_backup_avulso() {
    # Seleciona o backup usando a rotina unica
    if ! _selecionar_backup; then
        return 0
    fi

    # Validar que o nome do backup foi definido
    if [[ -z "${nome_backup:-}" ]]; then
        _erro "Nome do backup nao definido"
        _aguardar_tecla
        return 1
    fi

    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "s" ]]; then
            _mover_backup_offline "$nome_backup"
            return
        fi

        if _confirmar "Enviar backup via rede?" "S"; then
            _enviar_backup_rede "$nome_backup"
        fi
    else
        _aviso "CFG_OFFLINE nao configurado corretamente. Nenhuma acao de envio feita."
    fi
}

#---------- FUNCOES DE EXECUCAO DE BACKUP ----------#
# Valida se o backup foi criado corretamente
_validar_backup_criado() {
    local arquivo_destino="${1:-}"

    # Validar se o backup foi criado e tamanho mínimo
    if [[ ! -f "$arquivo_destino" ]] || (( $(wc -c < "$arquivo_destino" 2>/dev/null || echo 0) < 100 )); then
        _log_erro "Backup criado mas vazio ou muito pequeno: $arquivo_destino"
        rm -f -- "$arquivo_destino"
        return 1
    fi

    return 0
}

# Monta a lista de arquivos a compactar em UMA UNICA passada do find,
# acumulando tambem o tamanho total em bytes (usado na checagem de espaco).
# Antes eram duas operacoes separadas: "du -sk" (varredura completa) + "find"
# (outra varredura completa) + a leitura em bash.
# Parametros: $1=modo ("completo"|"incremental"|"multiplos") $2=data_referencia (opcional)
# Saida: _BACKUP_LISTA (array) e _BACKUP_BYTES
_coletar_arquivos_backup() {
    local modo="${1:-completo}"
    local data_referencia="${2:-}"
    local _find="${DEFAULT_FIND:-find}"

    _BACKUP_LISTA=()
    _BACKUP_BYTES=0

    # Um unico vetor de exclusoes, compartilhado por completo e incremental,
    # para os dois modos nao poderem divergir. "*.tmp" tambem exclui o proprio
    # zip em gravacao (.zip.tmp) e a lista temporaria (.lista_backup_*.tmp).
    local -a find_args=(
        -type f
        ! -name "*.zip" ! -name "*.tar" ! -name "*.gz"
        ! -name "*.log" ! -name "*.tmp" ! -name "*.old"
    )
    if [[ "$modo" == "incremental" && -n "$data_referencia" ]]; then
        find_args=( -newermt "$data_referencia" "${find_args[@]}" )
    fi

    # SEGUROCAO: se o diretorio de backup estiver dentro da base, o zip em
    # gravacao entraria na propria lista e cresceria durante a compactacao.
    local _dir_backup
    _dir_backup="${DEFAULT_BASEBACKUP_DIR:-}/"
    if [[ "$_dir_backup" == "$(pwd)/"* ]]; then
        local _rel
        _rel=".${_dir_backup#"$(pwd)"}"
        find_args=( \( -path "$_rel" -o -path "${_rel}*" \) -prune -o "${find_args[@]}" )
    fi

    # A lista vai para arquivo (nao pode ir para $( ) porque $( ) remove NUL)
    local _lista_tmp="${DEFAULT_BASEBACKUP_DIR}/.lista_backup_$$.tmp"
    "$_find" . "${find_args[@]}" -printf '%s\t%p\0' > "$_lista_tmp" 2>/dev/null || true

    # find sem -printf (implementacao nao-GNU): refaz a listagem sem tamanhos
    if [[ ! -s "$_lista_tmp" ]]; then
        "$_find" . "${find_args[@]}" -print0 > "$_lista_tmp" 2>/dev/null || true
    fi

    local _registro _tam _nome
    while IFS= read -r -d '' _registro; do
        if [[ "$_registro" == *$'\t'* ]]; then
            # Registro no formato "bytes<TAB>caminho"
            _tam="${_registro%%$'\t'*}"
            _nome="${_registro#*$'\t'}"
        else
            _tam=0
            _nome="$_registro"
        fi
        if [[ ! "$_tam" =~ ^[0-9]+$ ]]; then
            _tam=0
        fi
        _BACKUP_LISTA+=("$_nome")
        _BACKUP_BYTES=$(( _BACKUP_BYTES + _tam ))
    done < "$_lista_tmp"

    rm -f -- "$_lista_tmp" 2>/dev/null || true
}

# Compacta _BACKUP_LISTA em um zip, de forma atomica e em uma unica passada.
# Parametros: $1=arquivo_final (.zip) $2=modo (usado nas mensagens)
# Retorna: 0 sucesso integral, 1 erro, 2 nada para compactar (incremental),
#          3 parcial (zip integro, mas com arquivos que ficaram de fora)
_compactar_backup() {
    local arquivo_final="${1:-}"
    local modo="${2:-completo}"

    # Validar parametro
    if [[ -z "$arquivo_final" ]]; then
        _log_erro "Caminho do backup nao foi informado"
        return 1
    fi

    if ((${#_BACKUP_LISTA[@]} == 0)); then
        if [[ "$modo" == "incremental" ]]; then
            _msg "Nenhum arquivo modificado desde a data de referencia"
            return 2
        fi
        _aviso "Nenhum arquivo encontrado para backup"
        return 1
    fi

    # Destino gravavel: checado ANTES do "> $log_parcial", senao o redirecionamento
    # falha com erro cru do bash ("No such file or directory") no lugar de uma
    # mensagem do sistema, e o usuario nao sabe o que aconteceu
    local _dir_destino="${arquivo_final%/*}"
    if [[ "$_dir_destino" == "$arquivo_final" ]]; then
        _dir_destino="."
    fi
    if ! _validar_caminho_seguro "$_dir_destino" || [[ ! -d "$_dir_destino" ]]; then
        _erro "Diretorio de destino do backup invalido ou inexistente: ${_dir_destino}"
        return 1
    fi
    if [[ ! -w "$_dir_destino" ]]; then
        _erro "Sem permissao de escrita no diretorio de destino: ${_dir_destino}"
        return 1
    fi

    # Checagem de espaco sobre a lista real (nao sobre um "du -sk" da base),
    # medida no disco onde o zip sera gravado
    local necessario_kb
    necessario_kb=$(_estimar_espaco_necessario_kb "$_BACKUP_BYTES")
    if ! _verificar_espaco_disco "$_dir_destino" "$necessario_kb"; then
        _erro "Espaco em disco insuficiente em $_dir_destino"
        _erro "Necessario ~${necessario_kb}KB para ${#_BACKUP_LISTA[@]} arquivo(s)"
        return 1
    fi

    # Gravacao atomica: compactar em .tmp e renomear so depois de validar.
    # Zip interrompido/corrompido nunca aparece como backup restauravel.
    local arquivo_tmp="${arquivo_final}.tmp"
    rm -f -- "$arquivo_tmp" 2>/dev/null || true

    # Nivel de compressao (C_ZIP_NIVEL): 1 = rapido, 6/9 = menor arquivo.
    # -q silencia o "adding:" por arquivo (log massivo em bases grandes);
    # -X nao grava campos extras de uid/gid: menor e mais rapido.
    local nivel="${C_ZIP_NIVEL:-1}"
    if [[ ! "$nivel" =~ ^[0-9]$ ]]; then
        nivel=1
    fi
    local -a zip_flags=( -q -X "-${nivel}" )

    local log_zip="${LOG_ATU:-/dev/null}"
    local log_parcial="${arquivo_tmp}.log"
    local rc_zip=0
    # xargs em vez de "${arr[@]}" direto: respeita ARG_MAX (a versao anterior
    # quebrava com "Argument list too long" em bases com muitos arquivos) e
    # repete o zip em lotesautomaticos quando a lista nao cabe no argv.
    printf '%s\0' "${_BACKUP_LISTA[@]}" \
        | xargs -0 -r "$DEFAULT_ZIP" "${zip_flags[@]}" "$arquivo_tmp" > "$log_parcial" 2>&1 || rc_zip=$?

    # Saida do zip vai para o log de verdade; aqui so a contagem de linhas
    local qtd_erro=0
    if [[ -s "$log_parcial" ]]; then
        qtd_erro=$(wc -l < "$log_parcial" 2>/dev/null) || qtd_erro=0
        cat "$log_parcial" >> "$log_zip" 2>/dev/null || true
    fi
    rm -f -- "$log_parcial" 2>/dev/null || true

    # Definir permissao do arquivo backup
    chmod "$PERM_FILE_BACKUP" "$arquivo_tmp" 2>/dev/null || true

    # Validar backup criado
    if ! _validar_backup_criado "$arquivo_tmp"; then
        return 1
    fi

    # Validar integridade do zip (o tamanho ja foi conferido acima)
    if ! _validar_integridade_backup "$arquivo_tmp" 1; then
        _erro "Backup corrompido (falhou no teste de integridade)"
        rm -f -- "$arquivo_tmp"
        return 1
    fi

    # Conference final: entradas no zip x arquivos pretendidos. Detecta
    # QUALQUER arquivo que ficou de fora (em uso, removido, sem permissao) e
    # nao depende do texto do zip, que -q suprime (o aviso "name not matched"
    # nao aparece com -q e o zip ainda devolve 0). Uma unica leitura do indice
    # central: proporcional ao numero de entradas, nao aos dados.
    # (Em modo raso de integridade, "unzip -Z1" e executado duas vezes: uma
    # aqui e outra na validacao. Custo desprezivel diante da compactacao.)
    local entradas_zip=0
    entradas_zip=$("${DEFAULT_UNZIP}" -Z1 "$arquivo_tmp" 2>/dev/null | wc -l | tr -d ' ') || entradas_zip=0
    local qtd_omitidos=$(( ${#_BACKUP_LISTA[@]} - entradas_zip ))

    # Se algo faltou, identificar quais (comm exige as duas listas ordenadas;
    # o zip grava o nome sem o "./" que o find devolve)
    local -a _omitidos=()
    if (( qtd_omitidos > 0 )); then
        local _f
        local -a _queridos=()
        for _f in "${_BACKUP_LISTA[@]}"; do
            _queridos+=( "${_f#./}" )
        done
        mapfile -t _omitidos < <(
            comm -23 \
                <(printf '%s\n' "${_queridos[@]}" | LC_ALL=C sort) \
                <("${DEFAULT_UNZIP}" -Z1 "$arquivo_tmp" 2>/dev/null | LC_ALL=C sort) 2>/dev/null
        ) || true
    fi

    if ! mv -f -- "$arquivo_tmp" "$arquivo_final"; then
        _erro "Falha ao gravar o backup em ${arquivo_final}"
        rm -f -- "$arquivo_tmp" 2>/dev/null || true
        return 1
    fi

    # Zip integro, porem com arquivos que nao entraram (tipico de ISAM com o
    # sistema em uso). O backup e aproveitavel, mas nao completo: avisar em
    # vez de reportar sucesso silencioso, como fazia a versao anterior.
    if (( qtd_omitidos > 0 )); then
        _aviso "zip: ${qtd_omitidos} de ${#_BACKUP_LISTA[@]} arquivo(s) nao entraram no backup"
        local _i
        for ((_i = 0; _i < ${#_omitidos[@]} && _i < 5; _i++)); do
            _exibir_mensagem_centralizada "${AMARELO}" "  omitido: ${_omitidos[$_i]}"
        done
        if (( ${#_omitidos[@]} > 5 )); then
            _log "ZIP: ${#_omitidos[@]} arquivo(s) omitido(s) no total" "$log_zip"
        fi
        _log_sucesso "Backup ${modo} criado (PARCIAL): $arquivo_final"
        return 3
    fi

    # Avisos do zip que NAO implicaram arquivo faltando: arquivo completo
    if (( qtd_erro > 0 || rc_zip != 0 )); then
        _log "ZIP: codigo ${rc_zip}, ${qtd_erro} aviso(s) no log; nenhum arquivo faltando" "$log_zip"
    fi

    _log_sucesso "Backup ${modo} criado: $arquivo_final"
    return 0
}

# Executa backup completo ou incremental (funcoes auxiliares)
# Parametros: $1=arquivo_destino $2=modo ("completo" ou "incremental") $3=data_referencia (opcional)
# Retorna: 0 sucesso, 1 erro, 2 se nenhum arquivo encontrado (incremental),
#          3 se parcial (arquivos em uso ficaram de fora)
_executar_backup_arquivo() {
    local arquivo_destino="${1:-}"
    local modo="${2:-}"
    local data_referencia="${3:-}"

    # Validar diretorio de trabalho
    if ! _diretorio_trabalho; then
        _erro "Falha ao acessar diretorio de trabalho"
        return 1
    fi

    _coletar_arquivos_backup "$modo" "$data_referencia"
    _compactar_backup "$arquivo_destino" "$modo"
}
# Muda para o diretorio de trabalho
# Retorna: 0 se sucesso, 1 se erro
_diretorio_trabalho() {
    local base_trabalho="${BASE_TRABALHO:-${RAIZ}${CFG_BASE_DIR}}"

    if [[ ! -d "$base_trabalho" ]]; then
        _erro "Diretorio ${base_trabalho} nao encontrado"
        return 1
    fi

    cd "$base_trabalho" || {
        _erro "Nao foi possivel acessar ${base_trabalho}"
        return 1
    }

    return 0
}

#---------- ROTINA UNICA DE SELECAO DE BACKUP ----------#
# Escapa metacaracteres de glob (* ? [ ]) para uso literal em padroes de busca
_escapar_glob() {
    local valor="${1:-}"
    printf '%s' "$valor" | sed 's/[][?*]/\\&/g'
}

# Função centralizada para listar e selecionar backups
# Define as variaveis globais: backup_selecionado e nome_backup
_selecionar_backup() {
    local arquivos_backup=()
    local padrao_empresa
    padrao_empresa=$(_escapar_glob "$CFG_EMPRESA")

    # Carrega todos os .zip disponiveis
    shopt -s nullglob
    arquivos_backup=("${DEFAULT_BASEBACKUP_DIR}"/"${padrao_empresa}"_*.zip)
    shopt -u nullglob  # Restaurar imediatamente para nao afetar outros globos

    if ((${#arquivos_backup[@]} == 0)); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum backup (${CFG_EMPRESA}_*.zip) encontrado"
        _aguardar_tecla
        return 1  # Sinaliza ausencia de backups para o chamador
    fi

    # Ordenar o array em ordem reversa para corresponder à exibicao
    mapfile -t arquivos_backup < <(printf '%s\n' "${arquivos_backup[@]}" | sort -r)

    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Backups disponiveis (${#arquivos_backup[@]}):"
    _linha

    # Mostra lista numerada
    printf '%s\n' "${arquivos_backup[@]}" | nl -w2 -s') '
    _linha

    if ((${#arquivos_backup[@]} == 1)); then
        local nome_unico="${arquivos_backup[0]##*/}"
        if _confirmar "Usar o unico backup encontrado? ${CIANO}${nome_unico}${AMARELO}" "S"; then
            backup_selecionado="${arquivos_backup[0]}"
        else
            _linha
            _aviso "Operacao cancelada."
            _linha
            _aguardar 2
            return 1
        fi
    else
        # Escolha interativa com cancelar explicito (0)
        printf "%b\n" "${CIANO}Escolha o numero do backup (ou 0 para cancelar):${NORMAL}"
        printf "%b\n" "${AMARELO}0) Cancelar${NORMAL}"
        printf "\n"

        while true; do
            read -rp "${AMARELO}Opcao -> ${NORMAL}" REPLY
            echo ""

            if [[ "$REPLY" == "0" || -z "$REPLY" ]]; then
                _aviso "Operacao cancelada."
                return 1
            fi

            if [[ ! "$REPLY" =~ ^[0-9]+$ ]]; then
                _exibir_mensagem_centralizada "${VERMELHO}" "Digite apenas o numero."
                continue
            fi

            # Agora o indice corresponde corretamente à lista exibida
            local indice
            indice=$((REPLY - 1))
            if (( indice >= 0 && indice < ${#arquivos_backup[@]} )); then
                backup_selecionado="${arquivos_backup[$indice]}"
                break
            else
                _erro "Numero invalido. Use 1 a ${#arquivos_backup[@]} ou 0 para cancelar."
            fi
        done
    fi

    # Define o nome do backup selecionado (variavel global)
    nome_backup="${backup_selecionado##*/}"
    _exibir_mensagem_centralizada "${VERDE}" "Selecionado: $nome_backup"
    _linha

    return 0
}

#---------- FUNCOES DE RESTAURACAO ----------#
# A validacao de entradas do pacote (_validar_backup_entradas_seguras e o alias
# _validar_zip_entradas_seguras) foi movida para utils.sh: quem precisa dela
# tambem e programas.sh, que carrega DEPOIS deste modulo, e a regra de
# dependencia da MODULOS_CARREGAR exige apontar para frente. Ver utils.sh.

# Resolve o diretorio base de destino a partir do nome do arquivo de backup
# Formato do nome: ${CFG_EMPRESA}_${tipo}_${base_dir}_${data}.zip
# Retorna: 0 se encontrou base, 1 se fallback para CFG_BASE_DIR
_resolver_base_restauracao() {
    local arquivo_backup="${1:-}"
    local nome_arquivo resto sufixo base_dir_name base_var base

    nome_arquivo="${arquivo_backup##*/}"
    resto="${nome_arquivo#"${CFG_EMPRESA}_"}"
    sufixo="${resto##*_}"
    sufixo="${sufixo%.zip}"
    base_dir_name="${resto%_"${sufixo}"}"
    base_dir_name="${base_dir_name#*_}"

    for base_var in "CFG_BASE_DIR" "CFG_BASE_DIR2" "CFG_BASE_DIR3"; do
        base="${!base_var}"
        if [[ -n "$base" && "${base##*/}" == "${base_dir_name}" ]]; then
            printf '%s\n' "${RAIZ}${base}"
            return 0
        fi
    done

    printf '%s\n' "${RAIZ}${CFG_BASE_DIR}"
    return 1
}

# Rotaciona arquivos existentes na base antes de sobrescrever (backup de seguranca)
_rotacionar_arquivos_base() {
    local base_origem="${1:-}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${DEFAULT_BASEBACKUP_DIR}/restauracao_${timestamp}"

    if [[ ! -d "$base_origem" ]]; then
        return 0
    fi

    if ! _garantir_diretorio "$backup_dir" criar "diretorio de rotacao"; then
        return 1
    fi

    # Copiar arquivos existentes para backup de rotacao (nao move, para nao perder referencias)
    # Em lote: um processo a cada 200 arquivos em vez de um "cp" por arquivo
    # As aspas simples sao obrigatorias: o "$1"/"${arquivo##*/}" precisam ser
    # expandidos pelo sh filho, nao pelo shell pai (SC2016 nao se aplica aqui).
    # shellcheck disable=SC2016
    find "$base_origem" -maxdepth 1 -type f -print0 2>/dev/null \
        | xargs -0 -r -n 200 sh -c '
            d="$1"
            shift
            for arquivo do
                cp -p "$arquivo" "$d/${arquivo##*/}.orig" 2>/dev/null || true
            done
        ' sh "$backup_dir" 2>/dev/null || true

    _log_sucesso "Backup de seguranca criado em: $backup_dir"
    return 0
}

# Restaura backup completo
_restaurar_backup_completo() {
    local arquivo_backup="${1:-}"
    local base_trabalho

    # Solicitar escolha da base de destino (mostra menu se base2/base3 configuradas)
    if ! _menu_escolha_base_restauracao; then
        _exibir_mensagem_centralizada "$VERMELHO" "Restauracao cancelada pelo usuario"
        _aguardar_tecla
        return 1
    fi
    base_trabalho="${BASE_RESTAURACAO}"

    if [[ ! -f "$arquivo_backup" ]]; then
        _erro "Arquivo de backup nao encontrado"
        _aguardar_tecla
        return 1
    fi

    # Rotacionar arquivos existentes antes de sobrescrever
    if ! _rotacionar_arquivos_base "$base_trabalho"; then
        if ! _confirmar "Continuar mesmo sem backup de rotacao?" "N"; then
            _exibir_mensagem_centralizada "$VERMELHO" "Restauracao cancelada pelo usuario"
            _aguardar_tecla
            return 1
        fi
    fi

    # SEGURANCA: Bloquear restauracao se o backup contiver caminhos inseguros
    if ! _validar_zip_entradas_seguras "$arquivo_backup"; then
        _erro "Restauracao bloqueada: backup contem caminhos inseguros"
        _aguardar_tecla
        return 1
    fi

    _linha
    _aviso "Restaurando todos os arquivos..."
    _linha

    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        if ! "${DEFAULT_TAR:-tar}" -xzf "$arquivo_backup" -C "${base_trabalho}" >>"${LOG_ATU:-/dev/null}" 2>&1; then
            _erro "Erro na restauracao completa (tar.gz)"
            _aguardar_tecla
            return 1
        fi
    else
        if ! "${DEFAULT_UNZIP:-unzip}" -o "$arquivo_backup" -d "${base_trabalho}" >>"${LOG_ATU:-/dev/null}" 2>&1; then
            _erro "Erro na restauracao completa"
            _aguardar_tecla
            return 1
        fi
    fi

    _ok "Restauracao completa concluida"
    _aguardar_tecla
}

# Restaura(s) arquivo(s) especifico(s)
_restaurar_arquivo_especifico() {
    local arquivo_backup="${1:-}"
    local nome_arquivo
    local base_trabalho

    # Solicitar escolha da base de destino (mostra menu se base2/base3 configuradas)
    if ! _menu_escolha_base_restauracao; then
        _exibir_mensagem_centralizada "$VERMELHO" "Restauracao cancelada pelo usuario"
        _aguardar_tecla
        return 1
    fi
    base_trabalho="${BASE_RESTAURACAO}"

    if [[ ! -f "$arquivo_backup" ]]; then
        _erro "Arquivo de backup nao encontrado"
        _aguardar_tecla
        return 1
    fi

    # Rotacionar arquivos existentes antes de sobrescrever
    if ! _rotacionar_arquivos_base "$base_trabalho"; then
        if ! _confirmar "Continuar mesmo sem backup de rotacao?" "N"; then
            _exibir_mensagem_centralizada "$VERMELHO" "Restauracao cancelada pelo usuario"
            _aguardar_tecla
            return 1
        fi
    fi

    # SEGURANCA: Bloquear restauracao se o backup contiver caminhos inseguros
    if ! _validar_zip_entradas_seguras "$arquivo_backup"; then
        _erro "Restauracao bloqueada: backup contem caminhos inseguros"
        _aguardar_tecla
        return 1
    fi

    while true; do
        read -rp "${AMARELO}Nome do arquivo (maiusculo, sem extensao): ${NORMAL}" nome_arquivo

        if [[ -z "$nome_arquivo" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Nome nao informado"
            _aguardar_tecla
            _linha
            # Pergunta se deseja continuar mesmo após erro
            if ! _confirmar "Deseja restaurar mais arquivos?" "N"; then
                return 0  # Sai da funcao se nao quiser continuar
            fi
            continue  # Volta ao loop para novo nome
        fi

        if [[ ! "$nome_arquivo" =~ ^[A-Z0-9]+$ ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Nome de arquivo invalido"
            _aguardar_tecla
            _linha
            # Pergunta se deseja continuar mesmo após erro
            if ! _confirmar "Deseja restaurar mais arquivos?" "N"; then
                return 0  # Sai da funcao se nao quiser continuar
            fi
            continue  # Volta ao loop para novo nome
        fi

        _linha
        _aviso "Restaurando ${nome_arquivo}..."
        _linha

        local extrair_ok=0
        if [[ "$arquivo_backup" == *.tar.gz ]]; then
            if "${DEFAULT_TAR:-tar}" -xzf "$arquivo_backup" -C "${base_trabalho}" --wildcards "*${nome_arquivo}*" >>"${LOG_ATU:-/dev/null}" 2>&1; then
                extrair_ok=1
            fi
        else
            if "${DEFAULT_UNZIP:-unzip}" -o "$arquivo_backup" "${nome_arquivo}*.*" -d "${base_trabalho}" >>"${LOG_ATU:-/dev/null}" 2>&1; then
                extrair_ok=1
            fi
        fi
        if [[ $extrair_ok -eq 0 ]]; then
            _erro "Ao extrair ${nome_arquivo}"
            _aguardar_tecla
        else
            if ls "${base_trabalho}/${nome_arquivo}"*.* >/dev/null 2>&1; then
                _exibir_mensagem_centralizada "${VERDE}" "Arquivo ${nome_arquivo} restaurado com sucesso"
            else
                _exibir_mensagem_centralizada "${AMARELO}" "Arquivo ${nome_arquivo} nao encontrado apos restauracao"
            fi
            _aguardar_tecla
        fi
        _linha
        # Pergunta se deseja continuar (apenas após uma tentativa de restauracao)
        if ! _confirmar "Deseja restaurar mais arquivos?" "N"; then
            _exibir_mensagem_centralizada "${VERDE}" "Restauracoes finalizadas."
            return 0  # Sai da funcao com sucesso
        fi
    done
}

#---------- FUNCOES DE ENVIO ----------#
# Envia backup para servidor ou rede (unificado)
# Parametros: $1=nome_backup $2=tipo ("servidor" ou "rede")
_enviar_backup() {
    local nome_backup="${1:-}"
    local tipo="${2:-servidor}"
    local DESTINO_REMOTO

    # Validar se arquivo existe
    if [[ ! -f "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}" ]]; then
        _erro "Arquivo de backup nao encontrado"
        _aguardar 3
        return 1
    fi

    # Determinar destino
    if [[ -n "${CFG_BACKUP_PATH}" ]]; then
        DESTINO_REMOTO="${CFG_BACKUP_PATH}"
    elif [[ "$tipo" == "servidor" ]]; then
        read -rp "${AMARELO}Diretorio de destino no servidor: ${NORMAL}" DESTINO_REMOTO
        while [[ -z "$DESTINO_REMOTO" ]]; do
            _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio nao pode estar vazio"
            read -rp "${AMARELO}Diretorio de destino: ${NORMAL}" DESTINO_REMOTO
        done
    else
        read -rp "${AMARELO}Diretorio remoto: ${NORMAL}" DESTINO_REMOTO
        while [[ -z "$DESTINO_REMOTO" ]]; do
            _erro "Diretorio nao informado"
            read -rp "${AMARELO}Diretorio remoto: ${NORMAL}" DESTINO_REMOTO
        done
    fi

    # SEGURANCA: Validar destino remoto contra injeção e traversal
    if ! _validar_caminho_seguro "${DESTINO_REMOTO}"; then
        _erro "Diretorio de destino invalido ou malicioso"
        _aguardar 3
        return 1
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Enviando backup via vaievem..."
    _linha

    if _enviar_rsync "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}" "${DESTINO_REMOTO}"; then
        _linha
        if [[ "$tipo" == "servidor" ]]; then
            _exibir_mensagem_centralizada "${VERDE}" "Backup enviado com sucesso para \"${DESTINO_REMOTO}\""
            _linha

            # Perguntar sobre manter backup local
            if _confirmar "Manter backup local?" "S"; then
                _exibir_mensagem_centralizada "${AMARELO}" "Backup local mantido"
                _aguardar 2
            else
                if rm -f -- "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}"; then
                    _exibir_mensagem_centralizada "${AMARELO}" "Backup local excluido"
                    _aguardar 2
                else
                    _erro "ao excluir backup local"
                    _aguardar 2
                fi
            fi
        else
            _exibir_mensagem_centralizada "${VERDE}" "Backup enviado para \"${DESTINO_REMOTO}\" no servidor ${DEFAULT_IP_SERVER}"
            _aguardar 3
        fi
    else
        _linha
        if [[ "$tipo" == "servidor" ]]; then
            _erro "Erro ao enviar backup"
        else
            _erro "Ao enviar backup via o vaievem"
        fi
        _aguardar 3
        return 1
    fi
}

# Envia backup para servidor (wrapper)
_enviar_backup_servidor() {
    _enviar_backup "${1:-}" "servidor"
}

# Envia backup via rede (wrapper)
_enviar_backup_rede() {
    _enviar_backup "${1:-}" "rede"
}

# Move backup para diretorio offline
_mover_backup_offline() {
    local nome_backup="${1:-}"

    # Validar se arquivo existe
    if [[ ! -f "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}" ]]; then
        _erro "Arquivo de backup nao encontrado"
        _aguardar_tecla
        return 1
    fi

    _linha
    _aviso "Movendo backup para diretorio offline..."
    _linha

    if [[ -z "${CFG_PORTALSAV}" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio offline nao configurado"
        _aguardar_tecla
        return 1
    fi

    # SEGURANCA: Validar diretorio de destino contra path traversal e injecao,
# garantindo que ele exista antes de mover o backup para la.
    if ! _garantir_diretorio "${CFG_PORTALSAV}" criar "diretorio offline"; then
        _aguardar_tecla
        return 1
    fi

    if mv -f -- "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}" "$CFG_PORTALSAV"; then
        _exibir_mensagem_centralizada "${VERDE}" "Backup movido para: ${CFG_PORTALSAV}"
        _aguardar_tecla
    else
        _erro "Ao mover backup"
        _aguardar_tecla
        return 1
    fi
}

#---------- FUNCOES AUXILIARES ----------#
# Verifica espaco livre no disco. ATENCAO: as duas pontas estao em KB.
# Parametros: $1=diretorio $2=espaco_minimo_kb (padrao 1048576 = 1GB)
# A versao anterior comparava KB (df -kP) com um valor em bytes, o que tornava
# a checagem ~512x mais fraca que a pretendida e so falhava em disco quase vazio.
_verificar_espaco_disco() {
    local diretorio="${1:-}" espaco_minimo_kb="${2:-1048576}"
    if [[ ! "$espaco_minimo_kb" =~ ^[0-9]+$ ]]; then
        espaco_minimo_kb=1048576
    fi
    local espaco_disponivel
    espaco_disponivel=$(df -kP "$diretorio" 2>/dev/null | awk 'NR==2 {print $4}') || espaco_disponivel=""
    if [[ ! "$espaco_disponivel" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    (( espaco_disponivel >= espaco_minimo_kb ))
}

# Espaco necessario em KB para compactar uma lista de arquivos
# Parametros: $1=bytes (soma dos tamanhos da lista)
# Retorna: KB a exigir como espaco livre (C_BACKUP_ESPACO_RATIO % dos dados)
_estimar_espaco_necessario_kb() {
    local bytes="${1:-0}"
    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        bytes=0
    fi
    local ratio="${C_BACKUP_ESPACO_RATIO:-50}"
    if [[ ! "$ratio" =~ ^[0-9]+$ ]]; then
        ratio=50
    fi
    # Limites: 10% (nunca aceitar disco no limite) e 100% (pior caso: sem compressao)
    if (( ratio > 100 )); then
        ratio=100
    fi
    if (( ratio < 10 )); then
        ratio=10
    fi
    echo $(( bytes * ratio / 100 / 1024 ))
}

# Verifica backups recentes (ultimos 2 dias)
_verificar_backups_recentes() {
    local padrao_empresa
    padrao_empresa=$(_escapar_glob "$CFG_EMPRESA")

    if find "${DEFAULT_BASEBACKUP_DIR}" -maxdepth 1 -mtime -2 -name "${padrao_empresa}_*.zip" -print -quit | grep -q .; then
        _linha
        _exibir_mensagem_centralizada "${CIANO}" "Ja existe backup recente em $DEFAULT_BASEBACKUP_DIR:"
        _linha
        ls -ltrh "${DEFAULT_BASEBACKUP_DIR}"/"${padrao_empresa}"_*.zip 2>/dev/null
        _linha
        return 0
    fi
    return 1
}

# Executa backup com múltiplos padrões de arquivos
_executar_backup_multiplos_padroes() {
    local base_trabalho=""
    local ano_agora
    ano_agora=$(date +%Y)

    # Validar pre-requisitos e definir base_trabalho
    if ! _validar_pre_backup base_trabalho; then
        return 1
    fi

    export BASE_TRABALHO="$base_trabalho"

    _linha
    _exibir_mensagem_centralizada "${CIANO}" "BACKUP COM MULTIPLOS PADROES"
    _linha

    # Verificar e mudar para o diretorio de trabalho antes de solicitar os padroes
    if ! _diretorio_trabalho; then
        _erro "Ao acessar diretorio de trabalho"
        _aguardar 3
        return 1
    fi

    # Executar limpeza de temporarios antes do backup (modo automatico: so a base do backup, sem pausas)
    # _tentar_log em vez de "|| true": o backup nao pode ser bloqueado pela
    # limpeza, mas a falha precisa ficar registrada. Ver _tentar_log (utils.sh).
    _tentar_log "limpeza automatica de temporarios" "${LOG_LIMPA}" _executar_limpeza_temporarios automatico

    # Solicitar padrões de arquivos
    local padroes=()
    local padrao_entrada
    local contador=1

    _exibir_mensagem_centralizada "${AMARELO}" "Informe os arquivos que deseja fazer backup."
    _exibir_mensagem_centralizada "${AMARELO}" "Digite um por linha. Digite [vazio] para finalizar."
    _linha

    while true; do
        read -rp "${CIANO}Arquivo $contador: ${NORMAL}" padrao_entrada
        if [[ -z "$padrao_entrada" ]]; then
            if (( contador == 1 )); then
                _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum arquivo foi informado!"
                _aguardar 2
                return 0
            fi
            break
        fi

        # Verificar se o arquivo existe e expandir para incluir todos com mesmo nome e extensao
        # Suporta extensao simples (nome.dat) e dupla (nome.dat.idx)
        local nome_base extensao padrao_expandido
        # Remover extensoes: se tiver extensao dupla (ex: .dat.idx), remove as duas
        if [[ "${padrao_entrada}" =~ ^(.+)(\.[^.]+\.[^.]+)$ ]]; then
            nome_base="${BASH_REMATCH[1]}"
            extensao="${BASH_REMATCH[2]}"
        elif [[ "${padrao_entrada}" =~ ^(.+)(\.[^.]+)$ ]]; then
            nome_base="${BASH_REMATCH[1]}"
            extensao="${BASH_REMATCH[2]}"
        else
            nome_base="${padrao_entrada}"
            extensao=""
        fi

        if [[ -n "${extensao}" ]]; then
            padrao_expandido="${nome_base}*${extensao}"
        else
            padrao_expandido="${nome_base}*"
        fi

        if [[ ! -f "${padrao_entrada}" ]] && compgen -G "${padrao_expandido}" > /dev/null 2>&1; then
            _aviso "Arquivo(s), '${padrao_expandido}' incluido(s)."
            padrao_entrada="${padrao_expandido}"
            padroes+=("$padrao_entrada")
        elif [[ ! -f "${padrao_entrada}" ]]; then
            _aviso "Arquivo '${padrao_entrada}' nao encontrado no Diretorio base '$base_trabalho'"
        else
            padroes+=("$padrao_entrada")
        fi
        contador=$((contador + 1))
    done

    if (( ${#padroes[@]} == 0 )); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum arquivo foi adicionado"
        _aguardar 2
        return 0
    fi

    local arquivos_encontrados=()
    local padrao qtd_encontrados arquivo

    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Procurando arquivos..."
    _linha

    for padrao in "${padroes[@]}"; do
        qtd_encontrados=0
        # Buscar arquivos usando compgen para preservar espaços nos nomes
        local arquivos_glob
        mapfile -t arquivos_glob < <(compgen -G "$padrao")
        for arquivo in "${arquivos_glob[@]}"; do
            if [[ -f "$arquivo" ]]; then
                arquivos_encontrados+=("$arquivo")
                qtd_encontrados=$((qtd_encontrados + 1))
            fi
        done

        if (( qtd_encontrados == 0 )); then
            _aviso "Arquivo '$padrao' - nenhum arquivo encontrado"
        else
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo '$padrao' - $qtd_encontrados arquivo(s) encontrado(s)"
        fi
    done

    _linha

    # Verifica se algum arquivo foi encontrado
    if (( ${#arquivos_encontrados[@]} == 0 )); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum arquivo encontrado para os padroes informados!"
        _aguardar 3
        return 0
    fi

    # Exibir lista de arquivos que serao feitos backup
    _exibir_mensagem_centralizada "${CIANO}" "Total de arquivos para backup: ${#arquivos_encontrados[@]}"
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Arquivos a fazer backup:"
    printf '%s\n' "${arquivos_encontrados[@]}" | nl -w2 -s') '
    _linha

    # Confirmar antes de continuar
    if ! _confirmar "Deseja continuar com o backup destes arquivos?" "S"; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Operacao cancelada"
        _aguardar 2
        return 0
    fi

    _linha

    # Gerar nome do arquivo
    local nome_backup nome_base_dir resultado_zip_multi caminho_backup
    nome_base_dir="${base_trabalho##*/}"
    nome_backup="${CFG_EMPRESA}_multiplos_${nome_base_dir}_$(date +%Y%m%d%H%M%S).zip"
    caminho_backup="${DEFAULT_BASEBACKUP_DIR}/${nome_backup}"
    _aviso "Criando backup com multiplos padroes..."
    _linha

    # Entregar a lista selecionada ao compactador compartilhado (gravacao
    # atomica .tmp, lote via xargs, nivel de compressao e checagem de espaco).
    # O tamanho sai de um unico "du -ck" (a lista e pequena e escolhida a mao).
    _BACKUP_LISTA=("${arquivos_encontrados[@]}")
    local _kb_total=0
    _kb_total=$(du -ck -- "${_BACKUP_LISTA[@]}" 2>/dev/null | awk 'END {print $1}') || _kb_total=0
    if [[ ! "$_kb_total" =~ ^[0-9]+$ ]]; then
        _kb_total=0
    fi
    _BACKUP_BYTES=$(( _kb_total * 1024 ))

    resultado_zip_multi=0
    _compactar_backup "$caminho_backup" "multiplos" || resultado_zip_multi=$?

    if [[ $resultado_zip_multi -eq 0 ]]; then
        _finalizar_backup_sucesso "$nome_backup"
    elif [[ $resultado_zip_multi -eq 3 ]]; then
        _finalizar_backup_parcial "$nome_backup"
    else
        _erro "Backup nao foi criado"
        _aguardar 3
        return 1
    fi

    _linha

    # Perguntar sobre envio
    if _confirmar "Deseja enviar backup para servidor?" "N"; then
        _enviar_backup_servidor "$nome_backup"
    fi
}

# Finaliza backup com sucesso
_finalizar_backup_sucesso() {
    local nome_backup="${1:-}"
    local tamanho_backup

    if [[ -f "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}" ]]; then
        tamanho_backup=$(du -h "${DEFAULT_BASEBACKUP_DIR}/${nome_backup}" | cut -f1)
        _linha
        _ok "Backup Concluido!"
        _linha
        _exibir_mensagem_centralizada "$AMARELO" "Arquivo: $nome_backup"
        _exibir_mensagem_centralizada "$AMARELO" "Local: ${DEFAULT_BASEBACKUP_DIR}"
        _exibir_mensagem_centralizada "$AMARELO" "Tamanho: ${tamanho_backup}"
        _linha
    else
        _exibir_mensagem_centralizada "$AMARELO" "O backup $nome_backup foi criado em ${DEFAULT_BASEBACKUP_DIR}"
        _linha
        _exibir_mensagem_centralizada "$AMARELO" "Backup Concluido!"
        _linha
    fi
}

# Finaliza um backup PARCIAL: zip integro e utilizavel, porem com arquivos que
# nao puderam ser lidos (normal em ISAM com o sistema em uso). A versao antiga
# reportava "Backup Concluido!" sem avisar dos arquivos que faltaram.
_finalizar_backup_parcial() {
    local nome_backup="${1:-}"

    _finalizar_backup_sucesso "$nome_backup"
    _exibir_mensagem_centralizada "${VERMELHO}" "ATENCAO: backup PARCIAL - alguns arquivos estavam em uso e ficaram de fora"
    _exibir_mensagem_centralizada "${AMARELO}" "Arquivos omitidos estao listados em ${LOG_ATU:-log do sistema}"
    _linha
}
