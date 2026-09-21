#!/usr/bin/env bash
set -euo pipefail
#
# backup.sh - Modulo do Sistema de Backup
# Responsavel por backup completo, incremental e restauracao
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 19/09/2026

# Variaveis globais esperadas
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Caminho do diretorio base principal.
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"              # Caminho do diretorio da segunda base de dados.
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"              # Caminho do diretorio da terceira base de dados.
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip)
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)

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

    # Compatibilidade: local -n exige Bash 4.4+; ${!var} funciona em 4.2+
    local _base_ref="${!1}"

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
        _base_ref="${RAIZ}${CFG_BASE_DIR}"
    fi

    # Devolver valor ao chamador (nameref manual, compativel com Bash 4.2+)
    printf -v "$1" '%s' "${_base_ref}"

    # Validar se o diretorio base existe
    if [[ ! -d "${_base_ref}" ]]; then
        _erro "Diretorio base '${_base_ref}' nao existe"
        _aguardar 3
        return 1
    fi

    # Verificar se o diretorio de backup existe
    if [[ ! -d "$DEFAULT_BASEBACKUP_DIR" ]]; then
        _exibir_mensagem_centralizada "${AMARELO}" "Diretorio de backups em $DEFAULT_BASEBACKUP_DIR nao encontrado..."
        _aguardar 3
        return 1
    fi

    # Verificar espaco em disco (estimar via du -sk da base)
    local tamanho_estimado
    tamanho_estimado=$(_estimar_tamanho_backup "$_base_ref")
    local espaco_necessario=$((tamanho_estimado * 2 / 1024))
    if ! _verificar_espaco_disco "$DEFAULT_BASEBACKUP_DIR" "$espaco_necessario"; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Espaco em disco insuficiente em $DEFAULT_BASEBACKUP_DIR"
        _aguardar 3
        return 1
    fi

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
    _executar_limpeza_temporarios automatico || true

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

# Executa backup completo ou incremental (funcoes auxiliares)
# Parametros: $1=arquivo_destino $2=modo ("completo" ou "incremental") $3=data_referencia (opcional)
# Retorna: 0 se sucesso, 1 se erro, 2 se nenhum arquivo encontrado (incremental)
_executar_backup_arquivo() {
    local arquivo_destino="${1:-}"
    local modo="${2:-}"
    local data_referencia="${3:-}"
    local -a arquivos_para_zip=()
    local arquivo_atual

    # Validar parametro
    if [[ -z "$arquivo_destino" ]]; then
        _log_erro "Caminho do backup nao foi informado"
        return 1
    fi

    # Validar diretorio de trabalho
    if ! _diretorio_trabalho; then
        _erro "Falha ao acessar diretorio de trabalho"
        return 1
    fi

    # Listar arquivos
    if [[ "$modo" == "incremental" && -n "$data_referencia" ]]; then
        while IFS= read -r -d "" arquivo_atual; do
            arquivos_para_zip+=("$arquivo_atual")
        done < <(find . -type f -newermt "$data_referencia" \
             ! -name "*.zip" ! -name "*.tar" ! -name "*.gz" ! -name "*.log" ! -name "*.tmp" ! -name "*.old" \
             -print0)
    else
        while IFS= read -r -d "" arquivo_atual; do
            arquivos_para_zip+=("$arquivo_atual")
        done < <(find . -type f \
             ! -name "*.zip" ! -name "*.tar" ! -name "*.gz" ! -name "*.log" ! -name "*.tmp" ! -name "*.old" \
             -print0)
    fi

    if ((${#arquivos_para_zip[@]} == 0)); then
        if [[ "$modo" == "incremental" ]]; then
            _msg "Nenhum arquivo modificado desde $data_referencia"
            return 2
        fi
        _aviso "Nenhum arquivo encontrado para backup"
        return 1
    fi

    # Executar compactacao — ignorar erros de arquivo em uso (lock)
    local resultado_zip=0
    "$DEFAULT_ZIP" "$arquivo_destino" "${arquivos_para_zip[@]}" >>"${LOG_ATU:-/dev/null}" 2>&1 || resultado_zip=$?

    if [[ $resultado_zip -ne 0 ]]; then
        _aviso "zip retornou erro $resultado_zip (possivel arquivo em uso), tentando forcar..."
        "$DEFAULT_ZIP" -f "$arquivo_destino" "${arquivos_para_zip[@]}" >>"${LOG_ATU:-/dev/null}" 2>&1 || resultado_zip=$?
    fi

    if [[ $resultado_zip -ne 0 ]]; then
        _aviso "Falha parcial ao criar backup (alguns arquivos podem estar em uso): $arquivo_destino"
    fi

    # Definir permissao do arquivo backup
    chmod "$PERM_FILE_BACKUP" "$arquivo_destino" 2>/dev/null || true

    # Validar backup criado
    if ! _validar_backup_criado "$arquivo_destino"; then
        return 1
    fi

    # Validar integridade do zip
    if ! _validar_integridade_backup "$arquivo_destino"; then
        _erro "Backup corrompido (falhou no teste de integridade)"
        rm -f -- "$arquivo_destino"
        return 1
    fi

    _log_sucesso "Backup ${modo} criado: $arquivo_destino"
    return 0
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
# SEGURANCA: Valida entradas de backup (.zip ou .tar.gz) contra path traversal
# Uso: _validar_backup_entradas_seguras <arquivo_backup>
_validar_backup_entradas_seguras() {
    local arquivo_backup="${1:-}"
    local lista_entradas=""

    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        lista_entradas=$("${DEFAULT_TAR:-tar}" -tzf "$arquivo_backup" 2>/dev/null) || return 1
    else
        lista_entradas=$("${DEFAULT_UNZIP:-unzip}" -Z1 "$arquivo_backup" 2>/dev/null) || return 1
    fi

    if grep -qE '(^|/)\.\.(/|$)|^/|^[A-Za-z]:[\\/]' <<<"$lista_entradas"; then
        _erro "Backup contem entradas inseguras (path traversal)."
        return 1
    fi
    return 0
}

# Compatibilidade: alias para chamadas existentes que usam o nome antigo
_validar_zip_entradas_seguras() {
    _validar_backup_entradas_seguras "$@"
}

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

    if ! mkdir -p "$backup_dir" 2>/dev/null; then
        _aviso "Nao foi possivel criar diretorio de rotacao: $backup_dir"
        return 1
    fi

    # Copiar arquivos existentes para backup de rotacao (nao move, para nao perder referencias)
    local arquivo
    find "$base_origem" -maxdepth 1 -type f -print0 2>/dev/null | while IFS= read -r -d '' arquivo; do
        local nome_arquivo
        nome_arquivo="${arquivo##*/}"
        if [[ -n "$nome_arquivo" ]]; then
            cp -p "$arquivo" "${backup_dir}/${nome_arquivo}.orig" 2>/dev/null || true
        fi
    done

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
    _enviar_backup "$1" "servidor"
}

# Envia backup via rede (wrapper)
_enviar_backup_rede() {
    _enviar_backup "$1" "rede"
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

    # SEGURANCA: Validar diretorio de destino contra path traversal e injecao
    if ! _validar_caminho_seguro "${CFG_PORTALSAV}"; then
        _erro "Diretorio offline invalido ou malicioso: ${CFG_PORTALSAV}"
        _aguardar_tecla
        return 1
    fi

    local caminho="${CFG_PORTALSAV}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s" "${caminho}"
        return 1
    }

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
_verificar_espaco_disco() {
    local diretorio="${1:-}" espaco_minimo="${2:-1048576}"
    local espaco_disponivel
    espaco_disponivel=$(df -kP "$diretorio" 2>/dev/null | awk 'NR==2 {print $4}')
    [[ -n "$espaco_disponivel" ]] && (( espaco_disponivel >= espaco_minimo ))
}

# Estima espaco em disco necessario para backup completo
# Usa du -sk da base para estimar tamanho do backup
_estimar_tamanho_backup() {
    local base="${1:-}"
    local tamanho_kb
    tamanho_kb=$(du -sk "$base" 2>/dev/null | awk '{print $1}')
    echo "${tamanho_kb:-0}"
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
    _executar_limpeza_temporarios automatico || true

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

    # Executar compactação com os arquivos especificados — ignorar erros de arquivo em uso
    resultado_zip_multi=0
    "$DEFAULT_ZIP" "$caminho_backup" "${arquivos_encontrados[@]}" >>"${LOG_ATU:-/dev/null}" 2>&1 || resultado_zip_multi=$?

    if [[ $resultado_zip_multi -ne 0 ]]; then
        _aviso "zip multiplos retornou erro $resultado_zip_multi (possivel arquivo em uso), tentando forcar..."
        "$DEFAULT_ZIP" -r -f "$caminho_backup" "${arquivos_encontrados[@]}" >>"${LOG_ATU:-/dev/null}" 2>&1 || resultado_zip_multi=$?
    fi

    if [[ $resultado_zip_multi -ne 0 ]]; then
        _aviso "Falha parcial ao criar backup multiplos (alguns arquivos podem estar em uso): $caminho_backup"
    fi

    # Definir permissao do arquivo backup
    chmod "$PERM_FILE_BACKUP" "$caminho_backup" 2>/dev/null || true

    # Verificar se o backup foi criado
    if [[ ! -f "$caminho_backup" ]]; then
        _erro "Backup nao foi criado"
        _aguardar 3
        return 1
    fi

    # Validar integridade
    if ! _validar_integridade_backup "$caminho_backup"; then
        _erro "CRITICO: Backup criado mas invalido (corrompido)"
        rm -f -- "$caminho_backup"
        _aguardar 3
        return 1
    fi

    # Finalizar com sucesso
    _finalizar_backup_sucesso "$nome_backup"


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
