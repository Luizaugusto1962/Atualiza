#!/usr/bin/env bash
set -euo pipefail
#
# arquivos.sh - Modulo de Gestao de Arquivos
# Responsavel por limpeza, recuperacao, transferencia e expurgo de arquivos
# Padrões e regras de desenvolvimento: ver AGENTS.md
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 06/10/2026-02
#
# Variaveis globais esperadas
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Caminho do diretorio da primeira base de dados.
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"              # Caminho do diretorio da segunda base de dados.
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"              # Caminho do diretorio da terceira base de dados.
DEFAULT_PROGS_ATUAL_DIR="${DEFAULT_PROGS_ATUAL_DIR:-}"      # Caminho do diretorio de programas (ex: /savisc/programas/atual)
DEFAULT_PROGS_DIR="${DEFAULT_PROGS_DIR:-}"      # Caminho do diretorio de programas (ex: /savisc/programas/anterior)
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip)
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)
# Idade minima (em dias) para expurgar os diretorios do arquivo limpadir.
# Igual ao expurgo principal (+30). Ajustavel por quem opera a base.
LIM_PADIR_DIAS="${LIM_PADIR_DIAS:-30}"
[[ "$LIM_PADIR_DIAS" =~ ^[0-9]+$ ]] || LIM_PADIR_DIAS=30
# Extensoes de arquivos de dados a processar em _recuperar_todos_arquivos.
# Nao resetar aqui: um valor vindo de constantes.sh/.config precisa sobreviver
# ao source. Vazio = fallback "*.dat" dentro da funcao.
if ! declare -p DATA_EXTENSIONS >/dev/null 2>&1; then
    DATA_EXTENSIONS=()
fi

# =============================================================================
# GESTAO DE PROCESSOS EM SEGUNDO PLANO (jutil)
# =============================================================================
# Todas as rotinas de recuperacao passam por _executar_jutil, que dispara o
# jutil (REBUILD) em segundo plano e acompanha com _mostrar_progresso_backup.
declare -a PIDS_JUTIL=()                        # PIDs de jutil em segundo plano

# Mata PIDs de jutil ainda ativos e esvazia o rastreador. Segura sob set -u e
# sem efeito colateral quando o array esta vazio.
_limpar_pids_jutil() {
    if [[ ${#PIDS_JUTIL[@]} -eq 0 ]]; then
        return 0
    fi

    local pid
    for pid in "${PIDS_JUTIL[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    PIDS_JUTIL=()
    return 0
}

# =============================================================================
# FUNCOES AUXILIARES
# =============================================================================

# Sanitiza entrada do usuario, removendo bytes nao-ASCII e espacos
# Parametros: $1 - entrada a ser sanitizada
# Retorna: entrada sanitizada
_sanitizar_entrada() {
    local entrada="${1:-}"
    # Via expansao pura (sem fork de tr) — equivale a tr -cd ' -~'.
    # Mantem apenas 0x20..0x7E; remove acentos, tabs e controles.
    local limpa="${entrada//[^ -~]/}"
    printf '%s' "$limpa"
}

# Cache da validacao do REBUILD (evita stat -x por arquivo no lote)
_JUTIL_PRONTO=""

# Os tres validadores que este modulo tinha (_validar_diretorio_backup,
# _validar_diretorio_trabalho e _validar_diretorio_expurgavel) foram unificados
# em _garantir_diretorio (utils.sh), junto com os de baixar.sh, programas.sh,
# backup.sh, biblioteca.sh, vaievem.sh e config.sh.
#   _validar_diretorio_backup      -> _garantir_diretorio "$dir" validar
#   _validar_diretorio_trabalho    -> _garantir_diretorio "$dir" validar_escrita
#   _validar_diretorio_expurgavel  -> _garantir_diretorio "$dir" verificar

#---------- FUNCOES DE LIMPEZA -----------------#

# Resolve a base de trabalho ativa para operacoes de arquivos
_selecionar_base_arquivos() {

    if [[ -n "${CFG_BASE_DIR2}" ]]; then
        if ! _menu_escolha_base; then
            # Usuario escolheu voltar (opcao 9) — retorna 1 para o chamador voltar ao menu
            return 1
        fi
    else
        if [[ -z "${CFG_BASE_DIR}" ]]; then
            _erro "Diretorio de base principal (CFG_BASE_DIR) nao configurado"
            _linha
            _aguardar_tecla
            return 1
        fi
        base_trabalho="${RAIZ}${CFG_BASE_DIR}"
    fi

    # Validar antes de prosseguir
    if [[ -z "${base_trabalho}" ]]; then
        _erro "Diretorio de trabalho nao foi definido"
        _linha
        _aguardar_tecla
        return 1
    fi

    # SEGURANCA: bloquear path traversal e caracteres perigosos na base de trabalho
    if ! _validar_caminho_seguro "${base_trabalho}"; then
        _erro "Caminho da base invalido ou malicioso: ${base_trabalho}"
        _linha
        _aguardar_tecla
        return 1
    fi

    if [[ ! -d "${base_trabalho}" ]]; then
        _erro "Diretorio ${base_trabalho} nao encontrado"
        _linha
        _aguardar_tecla
        return 1
    fi

    if [[ ! -r "${base_trabalho}" ]]; then
        _erro "Sem permissao de leitura em ${base_trabalho}"
        _linha
        _aguardar_tecla
        return 1
    fi

    export base_trabalho
    return 0
}

# Executa limpeza de arquivos temporarios
# Parametros: $1="automatico" (opcional) — modo silencioso usado antes do backup:
#   - limpa apenas a base informada em BASE_TRABALHO/base_trabalho (nao todas as bases)
#   - sem pausas interativas (_aguardar_tecla)
#   - erros de lista/diretorio sao apenas logged, nunca abortam o fluxo do backup
# Retorna: 0 se a limpeza rodou, 1 se pre-requisitos invalidos (modo automatico nao deve bloquear o backup)
#
# IMPORTANTE (padrao de robustez): esta funcao e chamada de forma tolerante a
# falha (_tentar_log em backup.sh/menus.sh). No Bash isso suspende o `set -e`
# por todo o escopo dinamico da chamada, logo NENHUM comando aqui pode depender
# do errexit para abortar — todos os falliveis sao guardados explicitamente
# (return 1 + log). Ver _tentar_log em utils.sh.
_executar_limpeza_temporarios() {
    local modo="${1:-}"
    local automatico=0
    [[ "${modo}" == "automatico" ]] && automatico=1

    # Verificar arquivo de lista de temporarios
    local arquivo_lista="${CFG_DIR}/limpetmp"
    if [[ ! -f "${arquivo_lista}" ]]; then
        _log "AVISO: arquivo de lista nao existe, limpeza ignorada: ${arquivo_lista}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 0
        fi
        _erro "Arquivo ${arquivo_lista} nao existe no diretorio"
        _aguardar 2
        return 1
    elif [[ ! -r "${arquivo_lista}" ]]; then
        _log "AVISO: arquivo de lista sem permissao de leitura, limpeza ignorada: ${arquivo_lista}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 0
        fi
        _erro "Arquivo ${arquivo_lista} sem permissao de leitura"
        _aguardar 2
        return 1
    fi

    local arquivo_lista2="${CFG_DIR}/limpetmp2"

    # Limpar temporarios antigos do backup (validacao unica, reaproveitada abaixo)
    local backup_ok="0"
    if _garantir_diretorio "${DEFAULT_BACKUP_DIR}" validar "diretorio de backup" silencioso; then
        backup_ok="1"
        find "${DEFAULT_BACKUP_DIR}" -maxdepth 1 -type f -name "Temps*" -mtime +10 -delete 2>/dev/null || true
    else
        if (( automatico )); then
            _log "AVISO: diretorio de backup invalido ou inseguro, limpeza antiga pulada: ${DEFAULT_BACKUP_DIR:-vazio}" "${LOG_LIMPA}"
        else
            _aviso "Diretorio de backup invalido ou inseguro para limpeza, pulando: ${DEFAULT_BACKUP_DIR:-vazio}"
            _aguardar 2
        fi
    fi

    local caminho_base
    local base_dir
    local status_geral=0
    local achou_base=0

    if (( automatico )); then
        # Modo automatico (pre-backup): limpar somente a base do backup em curso
        caminho_base="${BASE_TRABALHO:-${base_trabalho:-}}"
        if [[ -n "${caminho_base}" ]]; then
            achou_base=1
            if [[ -d "${caminho_base}" ]]; then
                _limpar_base_especifica "${caminho_base}" "${arquivo_lista}" "automatico" "${backup_ok}" || status_geral=$?
                if [[ -f "${arquivo_lista2}" && -r "${arquivo_lista2}" ]]; then
                    _limpar_base_especifica "${caminho_base}" "${arquivo_lista2}" "automatico" "${backup_ok}" || status_geral=$?
                fi
            else
                _log "AVISO: diretorio da base nao existe, limpeza ignorada: ${caminho_base}" "${LOG_LIMPA}"
            fi
        else
            _log "AVISO: base de trabalho nao definida, limpeza automatica ignorada" "${LOG_LIMPA}"
        fi
    else
        # Modo interativo (menu): percorrer todas as bases configuradas
        for base_dir in "$CFG_BASE_DIR" "$CFG_BASE_DIR2" "$CFG_BASE_DIR3"; do
            if [[ -n "${base_dir}" ]]; then
                achou_base=1
                caminho_base="${RAIZ}${base_dir}"
                if [[ -d "${caminho_base}" ]]; then
                    _limpar_base_especifica "${caminho_base}" "${arquivo_lista}" "" "${backup_ok}" || status_geral=$?
                    # Processar limpetmp2 na sequencia, se existir
                    if [[ -f "${arquivo_lista2}" && -r "${arquivo_lista2}" ]]; then
                        _limpar_base_especifica "${caminho_base}" "${arquivo_lista2}" "" "${backup_ok}" || status_geral=$?
                    fi
                else
                    _aviso "Diretorio nao existe: ${caminho_base}"
                    _linha
                    _aguardar 2
                fi
            fi
        done
    fi

    if (( ! achou_base )); then
        if (( automatico )); then
            return 0
        fi
        _aviso "Nenhuma base de dados configurada para limpeza"
        _linha
    fi

    if (( ! automatico )); then
        _aguardar_tecla
    fi

    return "$status_geral"
}

# Valida padrao de nome de arquivo usado nas listas de limpeza (limpetmp/limpetmp2)
# Retorna: 0=valido 1=invalido (vazio, com caminho, traversal ou amplo demais)
_validar_padrao_limpeza() {
    local padrao="${1:-}"

    # Rejeitar vazio, separador de caminho ou traversal
    if [[ -z "$padrao" || "$padrao" == *"/"* || "$padrao" == *".."* ]]; then
        return 1
    fi

    # Rejeitar metacaracteres de shell (; & | $ ` etc. nao tem sentido em nome
    # de arquivo). Espaco e permitido (nomes com espaco sao tratados entre
    # aspas em todos os usos); o resto segue o charset de _adicionar_arquivo_lixo.
    # (regex em variavel: '-' nao-quotado dentro de [[ =~ ]] vira operador.)
    local re_charset='^[A-Za-z0-9._* -]+$'
    if [[ ! "$padrao" =~ $re_charset ]]; then
        return 1
    fi

    # Rejeitar padroes amplos demais que varreriam toda a base
    case "$padrao" in
        '*'|'**'|'*.*'|'**.*'|'*.**'|'*.**.'|'*.*.*'|'.'|'..') return 1 ;;
    esac

    # Permitir * apenas se o padrao tiver parte literal (prefixo ou sufixo)
    # Valido: NOME*, *.tmp, NOME*.dat   Invalido: * sozinho (ja bloqueado acima)
    if [[ "$padrao" == *'*'* ]]; then
        # Deve ter ao menos um caractere literal fora do *
        local sem_asterisco="${padrao//\*/}"
        if [[ -z "$sem_asterisco" ]]; then
            return 1
        fi

        # Bloquear padroes com multiplos asteriscos que seriam muito amplos
        # (ex: *.*.* ou **.* ou *..*)
        local qtd_asteriscos="${padrao//[^*]/}"
        if [[ ${#qtd_asteriscos} -gt 1 ]]; then
            # Permitir apenas padroes como: NOME*.ext ou *.ext (1 asterisco com contexto)
            # Rejeitar: *.*.* ou **.ext ou *..*
            if [[ "$padrao" == *"*."*"*"* ]]; then
                return 1
            fi
        fi
    fi

    return 0
}

# Limpa arquivos da base especifica
# Parametros: $1=caminho_base $2=arquivo_lista $3="automatico" (opcional, modo silencioso)
#            $4="backup_ok" (opcional): "1"=backup validado pelo chamador (pula re-validacao),
#               "0"=backup invalido (compactacao sera pulada), ausente=validar aqui.
_limpar_base_especifica() {
    local caminho_base="${1:-}"
    local arquivo_lista="${2:-}"
    local modo="${3:-}"
    local backup_ok="${4:-}"
    local automatico=0
    [[ "${modo}" == "automatico" ]] && automatico=1
    local arquivos_temp=()
    local padrao_arquivo

    # Validar parâmetros
    if [[ -z "${caminho_base}" || -z "${arquivo_lista}" ]]; then
        _log "ERRO: parametros invalidos na limpeza" "${LOG_LIMPA}"
        return 1
    fi

    if ! _garantir_diretorio "${caminho_base}" validar_escrita "diretorio de trabalho" silencioso; then
        _log "ERRO: diretorio invalido ou inacessivel: ${caminho_base}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 1
        fi
        _erro "Diretorio invalido ou inacessivel: ${caminho_base}"
        return 1
    fi

    if [[ ! -f "${arquivo_lista}" ]]; then
        _log "ERRO: arquivo de lista nao existe: ${arquivo_lista}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 1
        fi
        _erro "Arquivo de lista nao existe"
        return 1
    fi

    if [[ ! -r "${arquivo_lista}" ]]; then
        _log "ERRO: arquivo de lista sem permissao de leitura: ${arquivo_lista}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 1
        fi
        _erro "Arquivo de lista sem permissao de leitura"
        return 1
    fi

    # Validar diretorio de backup (a menos que o chamador ja tenha validado)
    local backup_valido=0
    if [[ "${backup_ok}" == "1" ]]; then
        backup_valido=1
    elif [[ "${backup_ok}" == "0" ]]; then
        backup_valido=0
    else
        if _garantir_diretorio "${DEFAULT_BACKUP_DIR}" validar "diretorio de backup" silencioso; then
            backup_valido=1
        fi
    fi
    if (( ! backup_valido )); then
        _log "ERRO: diretorio de backup invalido ou inseguro para compactacao: ${DEFAULT_BACKUP_DIR:-vazio}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 1
        fi
        _erro "Diretorio de backup invalido ou inseguro para compactacao: ${DEFAULT_BACKUP_DIR:-vazio}"
        return 1
    fi

    # Ler lista de arquivos temporarios (ignora vazias e comentarios)
    # Guarda explicita: o chamador (_tentar_log) suspende o errexit dentro
    # desta funcao, entao nao se pode confiar em `set -e` para abortar aqui.
    if ! mapfile -t arquivos_temp < "${arquivo_lista}"; then
        _log "ERRO: falha ao ler a lista de temporarios: ${arquivo_lista}" "${LOG_LIMPA}"
        if (( automatico )); then
            return 1
        fi
        _erro "Falha ao ler a lista de temporarios"
        return 1
    fi

    if (( ! automatico )); then
        _aviso "Limpando arquivos temporarios do diretorio: ${caminho_base}"
        _linha
    else
        _log "Iniciando limpeza automatica em: $caminho_base" "${LOG_LIMPA}"
    fi

    local zip_temporarios
    zip_temporarios="Temps-${UMADATA}.zip"

    # Filtrar padroes validos 1x (seguranca + evita N finds para lixo)
    local -a padroes_validos=()
    local linha_limpa
    if (( ${#arquivos_temp[@]} > 0 )); then
        for padrao_arquivo in "${arquivos_temp[@]}"; do
            # trim simples sem fork
            linha_limpa="${padrao_arquivo#"${padrao_arquivo%%[![:space:]]*}"}"
            linha_limpa="${linha_limpa%"${linha_limpa##*[![:space:]]}"}"
            [[ -z "$linha_limpa" ]] && continue
            [[ "$linha_limpa" == \#* ]] && continue
            # SEGURANCA: validar padrao antes de usa-lo no find/zip/rm. Sem
            # isso, uma linha "*" no limpetmp faria o find casar com todo
            # arquivo da base e o rm -f em lote apagaria dados.
            if ! _validar_padrao_limpeza "$linha_limpa"; then
                _log "AVISO: padrao de limpeza invalido ignorado: ${linha_limpa}" "${LOG_LIMPA}"
                continue
            fi
            padroes_validos+=("$linha_limpa")
        done
    fi

    if (( ${#padroes_validos[@]} == 0 )); then
        if (( ! automatico )); then
            _linha
            _ok "Limpeza concluida (nada a processar)"
            _linha
        else
            _log "Limpeza automatica: nenhum padrao valido em ${arquivo_lista}" "${LOG_LIMPA}"
        fi
        return 0
    fi

    # 1 unico find com OR (1 passada no diretorio em vez de N)
    local -a find_args=( "(" )
    local primeiro=1 padrao
    for padrao in "${padroes_validos[@]}"; do
        if (( primeiro )); then
            primeiro=0
        else
            find_args+=( -o )
        fi
        find_args+=( -iname "$padrao" )
    done
    find_args+=( ")" )

    if (( ${#find_args[@]} < 3 )); then
        _log "ERRO: find_args invalido (${#find_args[@]} elementos)" "${LOG_LIMPA}"
        return 1
    fi

    local -a arquivos_zip_total=()
    local arquivo
    while IFS= read -r -d '' arquivo; do
        arquivos_zip_total+=("$arquivo")
    done < <(find "${caminho_base:-.}" -maxdepth 1 -type f -mtime +0 "${find_args[@]}" -print0 2>/dev/null)

    local qtd_total="${#arquivos_zip_total[@]}"
    if (( qtd_total == 0 )); then
        if (( ! automatico )); then
            _linha
            _ok "Limpeza concluida (nenhum temporario encontrado)"
            _linha
        else
            _log "Limpeza automatica: nenhum temporario em $caminho_base" "${LOG_LIMPA}"
        fi
        return 0
    fi

    # Contagem por padrao para o log (sem novo find: fnmatch case-insensitive via minusculas)
    local -A qtd_por_padrao=()
    local nome_base nome_lower padrao_lower
    for arquivo in "${arquivos_zip_total[@]}"; do
        nome_base="${arquivo##*/}"
        nome_lower="${nome_base,,}"
        for padrao in "${padroes_validos[@]}"; do
            padrao_lower="${padrao,,}"
            # shellcheck disable=SC2053 # glob intencional em $padrao_lower
            if [[ "$nome_lower" == $padrao_lower ]]; then
                qtd_por_padrao["$padrao"]=$((${qtd_por_padrao["$padrao"]:-0} + 1))
            fi
        done
    done
    for padrao in "${!qtd_por_padrao[@]}"; do
        if (( automatico )); then
            _log "Processando padrao automatico: ${padrao} (${qtd_por_padrao[$padrao]} arquivo(s))" "${LOG_LIMPA}"
        else
            _exibir_mensagem_centralizada "${VERDE}" "Processando padrao: ${AMARELO}${padrao}${NORMAL} (${qtd_por_padrao[$padrao]} arquivo(s))"
        fi
    done

    # 1 unico zip (evita reescrever o arquivo central N vezes) + 1 rm em lote
    # $DEFAULT_ZIP sem aspas para suportar flags (ex: "zip -j")
    if $DEFAULT_ZIP "${DEFAULT_BACKUP_DIR}/${zip_temporarios}" "${arquivos_zip_total[@]}" >>"${LOG_LIMPA}" 2>&1; then
        _log "Arquivos temporarios compactados em lote: ${qtd_total} arquivo(s) -> ${zip_temporarios}" "${LOG_LIMPA}"
        if rm -f -- "${arquivos_zip_total[@]}"; then
            _log "Arquivos removidos em lote: ${qtd_total} arquivo(s)" "${LOG_LIMPA}"
        else
            _log "AVISO: falha ao remover arquivos em lote (${qtd_total} arquivo(s))" "${LOG_LIMPA}"
        fi
    else
        _log "ERRO ao compactar lote (${qtd_total} arquivo(s)) em ${zip_temporarios}" "${LOG_LIMPA}"
        _erro "  >> Ao compactar lote de temporarios (${qtd_total} arquivo(s))"
        return 1
    fi

    if (( ! automatico )); then
        _linha
        _ok "Limpeza concluida (${qtd_total} arquivo(s))"
        _linha
    fi

    return 0
}

# Adiciona arquivo à lista de limpeza
_adicionar_arquivo_lixo() {

    clear
    _meio_da_tela
    _exibir_mensagem_centralizada "${CIANO}" "Informe o nome do arquivo a ser adicionado ao limpetmp2"
    _linha

    local novo_arquivo
    read -rp "${AMARELO}Qual o arquivo -> ${NORMAL}" novo_arquivo
    _linha

    novo_arquivo=$(_sanitizar_entrada "$novo_arquivo")

    if [[ -z "$novo_arquivo" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nome de arquivo nao informado"
        _aguardar_tecla
        return 1
    fi

    if [[ ! "$novo_arquivo" =~ ^[A-Za-z0-9._*-]+$ ]]; then
        _erro "Nome de arquivo invalido. Use letras, numeros, pontos, hifens e * para curinga."
        _aguardar_tecla
        return 1
    fi

    # Revalidar usando as mesmas regras da funcao de limpeza
    if ! _validar_padrao_limpeza "$novo_arquivo"; then
        _erro "Padrao invalido ou amplo demais. Use prefixo ou sufixo concreto (ex: NOME*, *.tmp)."
        _aguardar_tecla
        return 1
    fi

    # Adicionar arquivo à lista
    echo "$novo_arquivo" >> "${CFG_DIR}/limpetmp2"
    _exibir_mensagem_centralizada "${CIANO}" "Arquivo '${novo_arquivo}' adicionado com sucesso ao 'limpetmp2'"
    _linha
    _aguardar_tecla
}

# Lista os arquivos no limpetmp e limpetmp2
_lista_arquivos_lixo() {

    clear
    _meio_da_tela
    _exibir_mensagem_centralizada "${CIANO}" "Lista de arquivos no limpetmp:"
    _linha

    if [[ -f "${CFG_DIR}/limpetmp" && -s "${CFG_DIR}/limpetmp" ]]; then
        nl -w3 -s'. ' "${CFG_DIR}/limpetmp"
    else
        _aviso "Nenhum arquivo listado no 'limpetmp'"
    fi

    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Lista de arquivos no limpetmp2:"
    _linha

    if [[ -f "${CFG_DIR}/limpetmp2" && -s "${CFG_DIR}/limpetmp2" ]]; then
        nl -w3 -s'. ' "${CFG_DIR}/limpetmp2"
    else
        _aviso "Nenhum arquivo listado no 'limpetmp2'"
    fi

    _linha
    _aguardar_tecla
}

#---------- FUNCOES DE RECUPERACAO ----------#
# Recupera arquivo especifico ou todos
_recuperar_arquivo_especifico() {
    local continuar="S"
    local confirmar_todos

    if ! _selecionar_base_arquivos; then
        return 0
    fi

    clear

    # Loop para permitir múltiplas recuperações
    while [[ "${continuar}" =~ ^[Ss]$ ]]; do
        _meio_da_tela
        _exibir_mensagem_centralizada "${CIANO}" "Informe o nome do arquivo a ser recuperado ou ENTER para todos:"
        _linha

        local nome_arquivo
        read -rp "${AMARELO}Nome do arquivo: ${NORMAL}" nome_arquivo
        nome_arquivo="${nome_arquivo#"${nome_arquivo%%[![:space:]]*}"}" # trim left
        nome_arquivo="${nome_arquivo%"${nome_arquivo##*[![:space:]]}"}" # trim right

        _linha "-" "${AZUL}"

        if [[ -z "$nome_arquivo" ]]; then
            # Pergunta confirmação antes de recuperar todos
            _aviso "Deseja recuperar TODOS os arquivos principais?"
            read -rp "${AMARELO}[S/N]: ${NORMAL}" confirmar_todos
            confirmar_todos=$(_trim "$confirmar_todos")
            confirmar_todos=$(_upper "$confirmar_todos")

            if [[ "$confirmar_todos" =~ ^[Ss]$ ]]; then
                # Recupera todos → executa e sai do loop
                _recuperar_todos_arquivos "$base_trabalho"
                _aviso "Todos os arquivos principais foram recuperados."
                break
            else
                _exibir_mensagem_centralizada "${CIANO}" "Operacao cancelada."
                _linha
                _aguardar 2
                return 0
            fi
        else
            # Recupera arquivo específico
            _recuperar_arquivo_individual "$nome_arquivo" "$base_trabalho"
            _aviso "Arquivo(s) recuperado(s)..."
        fi
        _linha

        # Só pergunta se quer continuar se foi um arquivo específico
        _exibir_mensagem_centralizada "${CIANO}" "Deseja recuperar mais arquivos?"
        read -rp "${AMARELO}[S/N]: ${NORMAL}" continuar
        continuar="${continuar#"${continuar%%[![:space:]]*}"}"
        continuar="${continuar%"${continuar##*[![:space:]]}"}"
        continuar="${continuar^^}"

        # Se vazio, assumir "N"
        [[ -z "$continuar" ]] && continuar="N"

    clear
    done
    cd "${SCRIPT_DIR}" || { _erro "Ao acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2; return 1; }
}

# Recupera todos os arquivos principais
_recuperar_todos_arquivos() {
    local base_trabalho="${1:-}"
    local -a extensoes=()
# Sem extensoes configuradas = *.dat (unico). DATA_EXTENSIONS pode ser escalar
# (string) ou array. O gate usa ${#arr[@]} (seguro com array vazio) e NAO
# "${arr[@]}" direto: em Bash 4.0/4.1 (Ubuntu 10.04/12.04) expandir array vazio
# sob set -u aborta o shell. Mesma razao dos guards ${x[@]+"${x[@]}"} no PIDS_JUTIL.
local -a data_ext=()
if declare -p DATA_EXTENSIONS 2>/dev/null | grep -q 'declare -a'; then
    if (( ${#DATA_EXTENSIONS[@]} > 0 )); then
        data_ext=("${DATA_EXTENSIONS[@]}")
    fi
elif [[ -n "${DATA_EXTENSIONS:-}" ]]; then
    data_ext=("${DATA_EXTENSIONS}")
fi
    if (( ${#data_ext[@]} > 0 )); then
        # Filtrar padroes amplos/inseguros (ex: "*" varreria a base toda).
        local ext_candidata
        for ext_candidata in "${data_ext[@]}"; do
            if _validar_padrao_limpeza "$ext_candidata"; then
                extensoes+=("$ext_candidata")
            else
                _log "AVISO: extensao invalida/ampla ignorada em DATA_EXTENSIONS: ${ext_candidata}" "${LOG_ATU:-/dev/null}"
            fi
        done
        if (( ${#extensoes[@]} == 0 )); then
            _aviso "Nenhuma extensao valida em DATA_EXTENSIONS, usando padrao *.dat"
            extensoes=("*.dat")
        fi
    else
        extensoes=("*.dat")
    fi
    _exibir_mensagem_centralizada "${VERMELHO}" "Recuperando todos os arquivos principais..."
    _linha "-" "${AMARELO}"

    if ! _garantir_diretorio "$base_trabalho" validar_escrita "diretorio de trabalho" silencioso; then
        _erro "Diretorio ${base_trabalho} nao existe ou e inacessivel"
        return 1
    fi

    if (( ${#extensoes[@]} == 0 )); then
        _aviso "Nenhuma extensao configurada para recuperacao"
        return 0
    fi
    # Coleta em 1 passada no diretorio (find sem filtro + classificacao
    # case-insensitive em memoria via minusculas). Segura para nomes com
    # espacos — o glob antigo (*.dat + expansao sem aspas) perdia esses
    # arquivos em silencio.
    local arquivo
    local -a lote_todos=()
    local qtd_links=0 qtd_vazios=0 qtd_outros=0
    # _JUTIL_LOTE_OK/_JUTIL_LOTE_FALHAS sao definidos por _executar_jutil_lote;
    # o resumo usa ${var:-0} para o caso de lote vazio (funcao nao chamada).
    # 1 unica passada no diretorio: classifica alvo vs nao-alvo em memoria
    # (evita o 2o find so para contar qtd_outros).
    local nome_base nome_lower padrao_lower e_alvo ext
    while IFS= read -r -d '' arquivo; do
        nome_base="${arquivo##*/}"
        nome_lower="${nome_base,,}"
        e_alvo=0
        for ext in "${extensoes[@]}"; do
            padrao_lower="${ext,,}"
            # shellcheck disable=SC2053 # glob intencional em $padrao_lower
            if [[ "$nome_lower" == $padrao_lower ]]; then
                e_alvo=1
                break
            fi
        done
        if (( ! e_alvo )); then
            # Mesma semantica da contagem anterior: so regulares contam como
            # "nao-alvo"; links fora do padrao seguem ignorados.
            if [[ -f "$arquivo" && ! -L "$arquivo" ]]; then
                ((qtd_outros++)) || true
            fi
            continue
        fi
        if [[ -L "$arquivo" ]]; then
            _aviso "Arquivo linkado, pulando: ${arquivo##*/}"
            _linha "-" "${VERDE}"
            ((qtd_links++)) || true
        elif [[ ! -s "$arquivo" ]]; then
            _aviso "Arquivo vazio, pulando: ${arquivo##*/}"
            _linha "-" "${VERDE}"
            ((qtd_vazios++)) || true
        else
            lote_todos+=("$arquivo")
        fi
    done < <(find "$base_trabalho" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null)

    local rc=0
    if (( ${#lote_todos[@]} > 0 )); then
        _executar_jutil_lote "${lote_todos[@]}" || rc=1
    fi

    _linha "-" "${AMARELO}"
    # Resumo em termos das extensoes realmente em uso (nao assumir ".dat").
    local rotulo_ext="${extensoes[*]}"
    _exibir_mensagem_centralizada "${CIANO}" "Resumo: ${#lote_todos[@]} alvo(s) (${_JUTIL_LOTE_OK:-0} recuperado(s), ${_JUTIL_LOTE_FALHAS:-0} falha(s), ${qtd_links} link(s), ${qtd_vazios} vazio(s), ${qtd_outros} fora de '${rotulo_ext}' ignorado(s))"
    _linha "-" "${AMARELO}"
    _log "Recuperacao total em ${base_trabalho}: ${#lote_todos[@]} alvo(s), ${_JUTIL_LOTE_OK:-0} ok, ${_JUTIL_LOTE_FALHAS:-0} falhas, ${qtd_links} links, ${qtd_vazios} vazios, ${qtd_outros} fora de '${rotulo_ext}'" "${LOG_ATU:-/dev/null}"
    return "$rc"
}

# Recupera arquivo individual
_recuperar_arquivo_individual() {
    local old_nullglob
    local old_nocaseglob
    local nome_arquivo="${1:-}"
    local base_trabalho="${2:-}"

    # Validar nome do arquivo
    if ! _garantir_diretorio "$base_trabalho" validar_escrita "diretorio de trabalho" silencioso; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio de trabalho invalido."
        return 1
    fi

    # Converter para maiusculo e remover espacos
    nome_arquivo="${nome_arquivo^^}"
    nome_arquivo="${nome_arquivo//[[:space:]]/}"

    if [[ -z "$nome_arquivo" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nome de arquivo vazio apos normalizacao."
        return 1
    fi

    # Reduzir a base (texto antes do primeiro ponto), como em
    # _executar_lista_arquivos: "ABC", "ABC.dat" e "ABC.ARQ.dat" recuperam o
    # mesmo arquivo logico e suas partes (ex: ABC.dat e ABC.ARQ.dat).
    nome_arquivo="${nome_arquivo%%.*}"

    if [[ ! "$nome_arquivo" =~ ^[A-Z0-9_-]+$ ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nome de arquivo invalido. Use apenas letras, numeros, underline e hifens."
        return 1
    fi

    local padrao_arquivo
    local -a padroes_busca=()
    local arquivo
    local -A vistos=()

    local arquivos_encontrados=0

    # Montar padroes de busca sobre a base: o nome exato (arquivos sem
    # extensao), o NOME.dat direto (arquivos curtos sem extensao intermediaria)
    # e o NOME.*.dat tradicional (ex: NOME.ARQ.dat). O padrao antigo usava
    # apenas NOME.*.dat, que exige dois pontos e nunca casa com NOME.dat.
    padroes_busca=("${nome_arquivo}" "${nome_arquivo}.dat" "${nome_arquivo}.*.dat")

    # shopt -p retorna 1 com opção desligada — || true evita abortar sob set -e.
    old_nullglob=$(shopt -p nullglob) || true
    old_nocaseglob=$(shopt -p nocaseglob) || true
    # Usar nocaseglob apenas localmente para este loop
    shopt -s nullglob nocaseglob
    local -a lote_individual=()
    for padrao_arquivo in "${padroes_busca[@]}"; do
        # shellcheck disable=SC2086 # expansao de glob intencional no padrao
        for arquivo in "${base_trabalho}"/${padrao_arquivo}; do
            # Ignorar literais sem match (nullglob nao remove padrao sem metacaractere)
            [[ -e "$arquivo" || -L "$arquivo" ]] || continue
            [[ -n "${vistos[$arquivo]:-}" ]] && continue
            vistos[$arquivo]=1
            if [[ -L "$arquivo" ]]; then
                _aviso "Arquivo linkado, pulando: ${arquivo##*/}"
                _linha "-" "${VERDE}"
            elif [[ -f "$arquivo" ]]; then
                lote_individual+=("$arquivo")
                ((arquivos_encontrados++)) || true
            fi
        done
    done
    # Restaurar shell options de forma segura (sem eval).
    # shopt -p imprime "shopt -u <opt>" (desligado) ou "shopt -s <opt>" (ligado).
    if [[ "$old_nullglob" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi
    if [[ "$old_nocaseglob" == *"-u"* ]]; then
        shopt -u nocaseglob
    else
        shopt -s nocaseglob
    fi

    if (( ${#lote_individual[@]} > 0 )); then
        _executar_jutil_lote "${lote_individual[@]}" || true
    fi

    if (( arquivos_encontrados == 0 )); then
        _aviso "Nenhum arquivo encontrado para: ${nome_arquivo}"
        _linha "-" "${VERDE}"
    fi
}

# Executa recuperacao dos arquivos listados no variosarquivos
_executar_lista_arquivos() {
    local arquivo_lista="${CFG_DIR}/variosarquivos"

    if [[ ! -f "$arquivo_lista" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "A lista de arquivo, variosarquivos nao foi encontrado em ${CFG_DIR}"
        _aguardar_tecla
        return 1
    fi

    if ! _selecionar_base_arquivos; then
        return 0
    fi

    if ! _garantir_diretorio "$base_trabalho" validar_escrita "diretorio de trabalho" silencioso; then
        _erro "Diretorio de trabalho invalido: $base_trabalho"
        return 1
    fi

    clear
    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Recuperando arquivos da lista 'variosarquivos'..."
    _linha

    local total=0
    local linha
    local -A bases_lista=()
    local -a ordem_bases=()

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        linha=$(_sanitizar_entrada "$linha")
        linha="${linha#"${linha%%[![:space:]]*}"}"
        linha="${linha%"${linha##*[![:space:]]}"}"
        [[ -z "$linha" ]] && continue

        local nome_base="${linha%%.*}"
        nome_base="${nome_base^^}"
        nome_base="${nome_base//[[:space:]]/}"
        [[ -z "$nome_base" ]] && continue
        if [[ -z "${bases_lista[$nome_base]:-}" ]]; then
            bases_lista[$nome_base]=1
            ordem_bases+=("$nome_base")
            ((total++)) || true
        fi
    done < "$arquivo_lista"

    # Resolver todos os globs em 1 passada (nullglob/nocaseglob 1x) e 1 lote jutil
    if (( ${#ordem_bases[@]} > 0 )); then
        local old_nullglob old_nocaseglob
        # shopt -p retorna 1 com opcao desligada — || true evita abortar sob set -e.
        old_nullglob=$(shopt -p nullglob) || true
        old_nocaseglob=$(shopt -p nocaseglob) || true
        shopt -s nullglob nocaseglob
        local -A vistos_lista=()
        local -a lote_varios=()
        local base_nome padrao_arquivo arquivo
        for base_nome in "${ordem_bases[@]}"; do
            # Validar formato sem fork extra (mesma regra de _recuperar_arquivo_individual)
            [[ "$base_nome" =~ ^[A-Z0-9_-]+$ ]] || continue
            for padrao_arquivo in "$base_nome" "$base_nome.dat" "$base_nome.*.dat"; do
                # shellcheck disable=SC2086 # expansao de glob intencional
                for arquivo in "${base_trabalho}"/${padrao_arquivo}; do
                    [[ -e "$arquivo" || -L "$arquivo" ]] || continue
                    [[ -n "${vistos_lista[$arquivo]:-}" ]] && continue
                    vistos_lista[$arquivo]=1
                    if [[ -L "$arquivo" ]]; then
                        _aviso "Arquivo linkado, pulando: ${arquivo##*/}"
                    elif [[ -f "$arquivo" ]]; then
                        lote_varios+=("$arquivo")
                    fi
                done
            done
        done
        if [[ "$old_nullglob" == *"-u"* ]]; then
            shopt -u nullglob
        else
            shopt -s nullglob
        fi
        if [[ "$old_nocaseglob" == *"-u"* ]]; then
            shopt -u nocaseglob
        else
            shopt -s nocaseglob
        fi
        if (( ${#lote_varios[@]} > 0 )); then
            _executar_jutil_lote "${lote_varios[@]}" || true
        fi
    fi

    _linha
    _exibir_mensagem_centralizada "${VERDE}" "${total} arquivo(s) processados da lista."
    _aguardar_tecla
}

# Edita a lista de arquivos (variosarquivos): visualiza, adiciona, altera ou remove linhas
_editar_lista_arquivos() {
    local arquivo_lista="${CFG_DIR}/variosarquivos"
    local novo num conf

    if [[ ! -f "$arquivo_lista" ]]; then
        _erro "Arquivo ${arquivo_lista} nao encontrado"
        _aguardar_tecla
        return 1
    fi

    while true; do
        clear
        _exibir_cabecalho_menu "Editar Lista de Arquivos (variosarquivos)"
        _exibir_titulo_secao " Conteudo atual:"
        _linha

        local linhas=()
        mapfile -t linhas < "$arquivo_lista"

        if [[ ${#linhas[@]} -eq 0 ]]; then
            _aviso "Lista vazia"
        else
            local indice=1
            for linha in "${linhas[@]}"; do
                if [[ -z "$linha" ]]; then
                    printf '%b' "${VERDE}${indice}${NORMAL} - ${AMARELO}(linha em branco)${NORMAL}\n"
                else
                    printf '%b' "${VERDE}${indice}${NORMAL} - ${linha}\n"
                fi
                ((indice++))
            done
        fi

        _linha
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Adicionar nova entrada"
        _exibir_opcao_menu "2" "Alterar uma entrada"
        _exibir_opcao_menu "3" "Remover uma entrada"
        _exibir_opcao_menu "4" "Zerar lista (remover todas as entradas)"
        _exibir_opcao_menu "9" "Voltar ao menu anterior"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        # O destino ("opcao") e obrigatorio: sem ele _ler_opcao_menu retorna 1
        # sem ler nada e o "continue" redesenha o menu para sempre, sem nunca
        # chegar ao case. Foi o unico call site do sistema que esqueceu o arg.
        if ! _ler_opcao_menu "variosarquivos" opcao; then
            continue
        fi

        case "${opcao}" in
             1)
                 read -rp "${AMARELO}Nome do arquivo a adicionar: ${NORMAL}" novo
                 novo=$(_trim "$novo")
                 novo=$(_sanitizar_entrada "$novo")
                 if [[ -n "$novo" ]]; then
                     if [[ ! "$novo" =~ ^[A-Za-z0-9._-]+$ ]]; then
                         _aviso "Nome invalido. Use apenas letras, numeros, pontos e hifens."
                     else
                         echo "$novo" >> "$arquivo_lista"
                         _ok "'${novo}' adicionado a lista"
                     fi
                 else
                     _aviso "Nenhum nome informado"
                 fi
                 _aguardar 1
                 ;;
             2)
                 read -rp "${AMARELO}Numero da linha a alterar: ${NORMAL}" num
                 num=$(_sanitizar_entrada "$num")
                 if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#linhas[@]} )); then
                     read -rp "${AMARELO}Novo valor: ${NORMAL}" novo
                     novo=$(_trim "$novo")
                     novo=$(_sanitizar_entrada "$novo")
                     if [[ -n "$novo" ]]; then
                         if [[ ! "$novo" =~ ^[A-Za-z0-9._-]+$ ]]; then
                             _aviso "Nome invalido. Use apenas letras, numeros, pontos e hifens."
                         else
                             local tmp_lista=()
                             for i in "${!linhas[@]}"; do
                                 if (( i + 1 == num )); then
                                     tmp_lista+=("$novo")
                                 else
                                     tmp_lista+=("${linhas[$i]}")
                                 fi
                             done
                             printf '%s\n' "${tmp_lista[@]}" > "$arquivo_lista"
                             _ok "Linha ${num} alterada"
                         fi
                     else
                         _aviso "Valor vazio, operacao cancelada"
                     fi
                 else
                     _aviso "Numero invalido"
                 fi
                 _aguardar 1
                 ;;
             3)
                 read -rp "${AMARELO}Numero da linha a remover: ${NORMAL}" num
                 num=$(_sanitizar_entrada "$num")
                 if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#linhas[@]} )); then
                     local tmp_lista=()
                     for i in "${!linhas[@]}"; do
                         if (( i + 1 != num )); then
                             tmp_lista+=("${linhas[$i]}")
                         fi
                     done
                     printf '%s\n' "${tmp_lista[@]}" > "$arquivo_lista"
                     _ok "Linha ${num} removida"
                 else
                     _aviso "Numero invalido"
                 fi
                 _aguardar 1
                 ;;
             4)
                 _aviso "Tem certeza que deseja ZERAR toda a lista?"
                 read -rp "${AMARELO}Confirma [S/N]: ${NORMAL}" conf
                 conf=$(_trim "$conf")
                 conf=$(_sanitizar_entrada "$conf")
                 conf="${conf^^}"
                 if [[ "$conf" == "S" ]]; then
                     rm -f -- "$arquivo_lista" && touch "$arquivo_lista"
                     _ok "Lista zerada com sucesso"
                 else
                     _aviso "Operacao cancelada"
                 fi
                 _aguardar 1
                 ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

# Recupera arquivos principais baseado na lista
_recuperar_arquivos_principais() {
    local old_nullglob
    cd "${CFG_DIR}" || return 1

    if ! _selecionar_base_arquivos; then
        return 1
    fi

    # Usar valor padrão se base_trabalho estiver vazia
    base_trabalho="${base_trabalho:-${RAIZ}${CFG_BASE_DIR}}"
    if ! _garantir_diretorio "$base_trabalho" validar_escrita "diretorio de trabalho" silencioso; then
        _erro "Diretorio ${base_trabalho} nao encontrado ou inacessivel"
        return 1
    fi

    # Gerar lista de arquivos atuais
    local var_ano var_ano4
    var_ano=$(date +%y)
    var_ano4=$(date +%Y)

    # Criar lista temporaria (glob seguro em vez de ls — evita quebra por nomes com espacos/glob)
    # shopt -p retorna 1 com opção desligada — || true evita abortar sob set -e.
    old_nullglob=$(shopt -p nullglob) || true
    shopt -s nullglob
    {
        local arquivo_ate arquivo_nfe
        for arquivo_ate in ATE"${var_ano}"*.dat; do
            printf '%s\n' "${arquivo_ate##*/}"
        done
        for arquivo_nfe in NFE?"${var_ano4}".*.dat; do
            printf '%s\n' "${arquivo_nfe##*/}"
        done
    } > "${CFG_DIR}/indexar2"
    if [[ "$old_nullglob" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi

    _aguardar 1

    # Nao anunciar sucesso quando _processar_lista_arquivos reportou falhas.
    local rc_geral=0
    if [[ -f "${CFG_DIR}/indexar2" && -s "${CFG_DIR}/indexar2" ]]; then
        if ! _processar_lista_arquivos "${CFG_DIR}/indexar2" "$base_trabalho"; then
            rc_geral=1
        fi
    fi

    # Verificar arquivos de lista
    if [[ -f "${CFG_DIR}/indexar" && -r "${CFG_DIR}/indexar" ]]; then
        if ! _processar_lista_arquivos "${CFG_DIR}/indexar" "$base_trabalho"; then
            rc_geral=1
        fi
    fi

    # Limpar arquivo temporario
    [[ -f "${CFG_DIR}/indexar2" ]] && rm -f -- "${CFG_DIR}/indexar2"

    if (( rc_geral == 0 )); then
        _exibir_mensagem_centralizada "${AMARELO}" "Arquivos principais recuperados"
    else
        _aviso "Recuperacao concluida com falhas — consulte o log de atualizacao"
        _log "AVISO: recuperacao de arquivos principais terminou com falhas em ${base_trabalho}" "${LOG_ATU:-/dev/null}"
    fi

    _aguardar_tecla
    cd "${SCRIPT_DIR}" || { _erro "Ao acessar o diretorio %s\n" "${SCRIPT_DIR}" >&2; return 1; }
    return "$rc_geral"
}

# Processa lista de arquivos para recuperacao
_processar_lista_arquivos() {
    local arquivo_lista="${1:-}"
    local base_trabalho="${2:-}"
    local caminho_arquivo

    if ! _garantir_diretorio "$base_trabalho" validar_escrita "diretorio de trabalho" silencioso; then
        _erro "Diretorio de trabalho invalido: $base_trabalho"
        return 1
    fi

    # Coleta validada em lote (1 jutil paralelo no final em vez de N sequenciais)
    local -a lote_lista=()
    local -A vistos_lote=()
    # Contadores separados: entradas ausentes/vazias na base NAO sao falha de
    # recuperacao, sao lista desatualizada. Antes elas entravam no lote, viravam
    # "Nao recuperou" e inflavam _JUTIL_LOTE_FALHAS.
    local qtd_links=0 qtd_ausentes=0 qtd_vazios=0 qtd_invalidos=0
    local listando
    while IFS= read -r listando || [[ -n "$listando" ]]; do
        [[ -z "$listando" ]] && continue

        # SEGURANCA: aceitar apenas nomes simples de arquivo .dat (sem caminho/glob/traversal)
        if [[ "$listando" != *.dat ]]; then
            _aviso "Entrada invalida ignorada na lista (nao e .dat): ${listando}"
            ((qtd_invalidos++)) || true
            continue
        fi

        if ! _validar_padrao_limpeza "${listando%.dat}"; then
            _aviso "Entrada invalida ignorada na lista: ${listando}"
            ((qtd_invalidos++)) || true
            continue
        fi

        caminho_arquivo="${base_trabalho}/${listando}"
        if ! _validar_caminho_seguro "$caminho_arquivo"; then
            _aviso "Caminho invalido ignorado: ${caminho_arquivo}"
            ((qtd_invalidos++)) || true
            continue
        fi
        [[ -n "${vistos_lote[$caminho_arquivo]:-}" ]] && continue
        vistos_lote[$caminho_arquivo]=1

        if [[ -L "$caminho_arquivo" ]]; then
            _aviso "Arquivo linkado, pulando: ${listando}"
            ((qtd_links++)) || true
        elif [[ ! -e "$caminho_arquivo" ]]; then
            _log "Lista desatualizada: ${listando} nao existe em ${base_trabalho}" "${LOG_ATU:-/dev/null}"
            ((qtd_ausentes++)) || true
        elif [[ ! -s "$caminho_arquivo" ]]; then
            _aviso "Arquivo vazio, pulando: ${listando}"
            ((qtd_vazios++)) || true
        else
            lote_lista+=("$caminho_arquivo")
        fi
    done < "$arquivo_lista"

    if (( qtd_ausentes > 0 || qtd_links > 0 || qtd_vazios > 0 || qtd_invalidos > 0 )); then
        _log "Lista ${arquivo_lista}: ${#lote_lista[@]} p/ jutil, ${qtd_ausentes} ausente(s), ${qtd_links} link(s), ${qtd_vazios} vazio(s), ${qtd_invalidos} invalido(s)" "${LOG_ATU:-/dev/null}"
    fi

    if (( ${#lote_lista[@]} > 0 )); then
        _executar_jutil_lote "${lote_lista[@]}" || return 1
    fi
    return 0
}

# Valida REBUILD uma vez por lote (cache em _JUTIL_PRONTO)
# Retorna: 0 se pronto, 1 caso contrario
_validar_rebuild() {
    if [[ "${_JUTIL_PRONTO:-}" == "1" ]]; then
        return 0
    fi
    if [[ -z "${REBUILD:-}" || ! -x "${REBUILD}" ]]; then
        _erro "Variavel REBUILD nao configurada ou nao executavel: ${REBUILD:-vazio}. Verifique constantes.sh"
        return 1
    fi
    _JUTIL_PRONTO="1"
    return 0
}

# Lote sequencial legado: chama _executar_jutil em TODOS os itens (preserva as
# mensagens exatas, inclusive os avisos de link/vazio/inexistente) e so classifica
# o resultado depois. _executar_jutil devolve 0 tanto para sucesso quanto para
# link/vazio — sem a classificacao, _JUTIL_LOTE_OK inflaria com pulados.
# Parametros: lista de arquivos; Entrada: _JUTIL_LOTE_* ja zerados pelo chamador
# Saida: atualiza _JUTIL_LOTE_OK/_JUTIL_LOTE_FALHAS/_JUTIL_LOTE_PULADOS
# Retorna: 0 se todos ok, 1 se ao menos um falhou
_executar_jutil_lote_sequencial() {
    local arquivo rc=0
    for arquivo in "$@"; do
        if _executar_jutil "$arquivo"; then
            if [[ -L "$arquivo" || ! -e "$arquivo" || ! -s "$arquivo" ]]; then
                ((_JUTIL_LOTE_PULADOS++)) || true
            else
                ((_JUTIL_LOTE_OK++)) || true
            fi
        else
            rc=1
            ((_JUTIL_LOTE_FALHAS++)) || true
        fi
    done
    return "$rc"
}

# Executa jutil em lote com paralelismo controlado (Bash 4.0+, sem wait -n)
# Parametros: lista de arquivos (cada $1..$n um caminho)
# Comportamento: C_JUTIL_SEQUENCIAL=1 ou C_JUTIL_PARALELO<=1 cai no legado
#   sequencial via _executar_jutil_lote_sequencial (mesma saida). Caso contrario
#   dispara ate N REBUILD em paralelo, espera todos e aplica chmod em lote unico.
# saida: _JUTIL_LOTE_OK/_JUTIL_LOTE_FALHAS/_JUTIL_LOTE_PULADOS (contadores)
# Retorna: 0 se todos ok, 1 se ao menos um falhou
_executar_jutil_lote() {
    local -a lista=("$@")
    local total="${#lista[@]}"
    # Resultado do lote para o resumo do chamador (sempre definidos na saida)
    _JUTIL_LOTE_OK=0
    _JUTIL_LOTE_FALHAS=0
    _JUTIL_LOTE_PULADOS=0
    if (( total == 0 )); then
        return 0
    fi

    if ! _validar_rebuild; then
        return 1
    fi

    local paralelo="${C_JUTIL_PARALELO:-4}"
    [[ "$paralelo" =~ ^[0-9]+$ ]] || paralelo=4
    if (( paralelo < 1 )); then
        paralelo=1
    fi

    # Fallback legado: sequencial preserva saida/Mensagens exatas.
    if [[ "${C_JUTIL_SEQUENCIAL:-0}" == "1" ]] || (( paralelo <= 1 || total <= 1 )); then
        _executar_jutil_lote_sequencial "${lista[@]}"
        return "$?"
    fi

    if (( paralelo > total )); then
        paralelo="$total"
    fi

    local dir_status
    dir_status=$(mktemp -d -t jutil_lote.XXXXXX) || {
        # Fallback sem dir temporario: sequencial com os mesmos contadores do
        # caminho legado (o chamador usa _JUTIL_LOTE_OK/FALHAS no resumo).
        _executar_jutil_lote_sequencial "${lista[@]}"
        return "$?"
    }

    local mostrar="${C_JUTIL_PROGRESSO:-1}"
    if [[ "$mostrar" == "1" ]]; then
        _exibir_mensagem_centralizada "${CIANO}" "Recuperando ${total} arquivo(s) em lote (x${paralelo})..."
    fi
    _log "Iniciando lote jutil: ${total} arquivo(s), paralelismo=${paralelo}" "${LOG_ATU:-/dev/null}"

    # Ondas de ate N jobs: simples, compativel com Bash 4.0 (sem wait -n),
    # sem polling por segundo e com saida deterministica na ordem da fila.
    local -a fila=("${lista[@]}")
    local inicio=0
    local arquivo status_arquivo
    local falhas=0 concluidos=0 pulados=0
    local -a pids_onda=()
    local -a idx_onda=()

    local fim i indice
    while (( inicio < ${#fila[@]} )); do
        fim=$((inicio + paralelo))
        if (( fim > ${#fila[@]} )); then
            fim=${#fila[@]}
        fi
        pids_onda=()
        idx_onda=()
        for ((indice = inicio; indice < fim; indice++)); do
            arquivo="${fila[$indice]}"
            # Codigos de status: 0=ok, 1=falha, 2=pulado (link/vazio, ja avisado).
            # "2" mantem pulados fora de _JUTIL_LOTE_OK, que antes inflava o resumo.
            if [[ -L "$arquivo" ]]; then
                _aviso "Arquivo linkado, pulando: ${arquivo##*/}"
                printf '2' > "${dir_status}/${indice}.status"
                continue
            fi
            if [[ ! -e "$arquivo" ]]; then
                _aviso "Arquivo nao encontrado, pulando: ${arquivo##*/}"
                printf '3' > "${dir_status}/${indice}.status"
                continue
            fi
            if [[ ! -s "$arquivo" ]]; then
                _aviso "Arquivo vazio, pulando: ${arquivo##*/}"
                printf '2' > "${dir_status}/${indice}.status"
                continue
            fi
            {
                # Subshell herda REBUILD/LOG_ATU por export (constantes.sh).
                # O || rc=... e obrigatorio: o subshell herda set -e, e sem ele
                # um jutil morto por sinal (ex: OOM-killer) abortaria o subshell
                # antes do printf, perdendo o codigo real (137/143).
                rc=0
                "${REBUILD}" -rebuild "$arquivo" -a -f >>"${LOG_ATU:-/dev/null}" 2>&1 || rc=$?
                printf '%s' "$rc" > "${dir_status}/${indice}.status"
            } &
            pids_onda+=("$!")
            idx_onda+=("$indice")
            PIDS_JUTIL+=("$!")
        done
        # Esperar so a onda atual (mantem no maximo N simultaneos)
        local _wp
        for _wp in ${pids_onda[@]+"${pids_onda[@]}"}; do
            wait "$_wp" 2>/dev/null || true
        done
        inicio="$fim"
    done

    # Coletar resultados na ordem da fila (saida deterministica)
    local -a ok_lista=()
    local -a retentar=()
    for ((i = 0; i < ${#fila[@]}; i++)); do
        arquivo="${fila[$i]}"
        status_arquivo="1"
        if [[ -f "${dir_status}/${i}.status" ]]; then
            status_arquivo=$(<"${dir_status}/${i}.status")
        fi
        status_arquivo="${status_arquivo//[^0-9]/}"
        if [[ -z "$status_arquivo" ]]; then
            status_arquivo=1
        fi
        if [[ "$status_arquivo" == "0" ]]; then
            # 0 so e escrito pelo subshell apos REBUILD retornar 0 — nao ha mais
            # link/vazio mascarando sucesso (esses chegam como 2).
            _log_sucesso "Rebuild executado: ${arquivo##*/}"
            ok_lista+=("$arquivo")
            ((concluidos++)) || true
        elif [[ "$status_arquivo" == "2" ]]; then
            # Link ou vazio: ja avisado na onda, nao conta como recuperado nem falha.
            ((pulados++)) || true
        elif [[ "$status_arquivo" == "3" ]]; then
            # Ausente na base: aviso especifico, conta como falha (pedido no indice).
            ((falhas++)) || true
        elif [[ "$status_arquivo" == "137" || "$status_arquivo" == "143" ]]; then
            # SIGKILL/SIGTERM (ex: OOM-killer matou o jutil sob paralelismo).
            # Guarda para retry sequencial abaixo, que usa menos memoria.
            if [[ -e "$arquivo" ]]; then
                _aviso "jutil interrompido pelo sistema (sinal ${status_arquivo}) em: ${arquivo##*/}"
                retentar+=("$arquivo")
            fi
            ((falhas++)) || true
        else
            if [[ -e "$arquivo" ]]; then
                _erro "Nao recuperou: ${arquivo##*/}"
            fi
            ((falhas++)) || true
        fi
    done

    # Retry sequencial dos mortos por sinal: 1 jutil por vez raramente estoura
    # memoria. Se falhar de novo, orienta a reduzir o paralelismo.
    if (( ${#retentar[@]} > 0 )); then
        _aviso "Tentando novamente ${#retentar[@]} arquivo(s) de forma sequencial (menos memoria)..."
        _log "Retry sequencial apos sinal do sistema: ${#retentar[@]} arquivo(s)" "${LOG_ATU:-/dev/null}"
        local arq_retry
        for arq_retry in "${retentar[@]}"; do
            if _executar_jutil "$arq_retry"; then
                ok_lista+=("$arq_retry")
                ((concluidos++)) || true
                ((falhas--)) || true
            else
                _erro "jutil morto pelo sistema em: ${arq_retry##*/}. Memoria insuficiente? Reduza C_JUTIL_PARALELO ou use C_JUTIL_SEQUENCIAL=1"
            fi
        done
    fi

    # chmod em lote unico (1 fork em vez de N)
    if (( ${#ok_lista[@]} > 0 )); then
        chmod "${PERM_FILE_EXEC}" "${ok_lista[@]}" 2>/dev/null || {
            _aviso "Nao foi possivel alterar permissoes em lote (${#ok_lista[@]} arquivo(s))"
        }
        # Indices .idx gerados pelo jutil: 1 glob por diretorio, nao por arquivo
        local -A dirs_vistos=()
        local dir_arquivo
        for arquivo in "${ok_lista[@]}"; do
            dir_arquivo="${arquivo%/*}"
            if [[ -z "$dir_arquivo" || "$dir_arquivo" == "$arquivo" ]]; then
                dir_arquivo="."
            fi
            dirs_vistos["$dir_arquivo"]=1
        done
        local old_nullglob
        # shopt -p retorna 1 quando a opcao esta desligada — || true evita
        # abortar sob set -e (AGENTS.md: set -euo pipefail obrigatorio).
        old_nullglob=$(shopt -p nullglob) || true
        shopt -s nullglob
        for dir_arquivo in "${!dirs_vistos[@]}"; do
            # shellcheck disable=SC2206
            local idx_lista=("${dir_arquivo}"/*.idx)
            if (( ${#idx_lista[@]} > 0 )); then
                chmod "${PERM_FILE_EXEC}" "${idx_lista[@]}" 2>/dev/null || true
            fi
        done
        if [[ "$old_nullglob" == *"-u"* ]]; then
            shopt -u nullglob
        else
            shopt -s nullglob
        fi
    fi

    # Limpar PIDs do rastreador que ja terminaram (manter so ainda-ativos)
    local -a restantes=()
    local _p
    for _p in ${PIDS_JUTIL[@]+"${PIDS_JUTIL[@]}"}; do
        if kill -0 "$_p" 2>/dev/null; then
            restantes+=("$_p")
        fi
    done
    if (( ${#restantes[@]} > 0 )); then
        PIDS_JUTIL=("${restantes[@]}")
    else
        PIDS_JUTIL=()
    fi

    rm -rf -- "$dir_status" 2>/dev/null || true

    _JUTIL_LOTE_OK="$concluidos"
    _JUTIL_LOTE_FALHAS="$falhas"
    _JUTIL_LOTE_PULADOS="$pulados"
    _linha "-" "${VERDE}"
    _log "Lote jutil concluido: ${concluidos} ok, ${falhas} falha(s), ${pulados} pulado(s)" "${LOG_ATU:-/dev/null}"
    if (( falhas > 0 )); then
        return 1
    fi
    return 0
}

# Executa jutil no arquivo especificado (em segundo plano com barra de progresso)
# Todas as rotinas de recuperacao passam por aqui, logo todo jutil roda em
# segundo plano: dispara o REBUILD com & e acompanha via _mostrar_progresso_backup.
_executar_jutil() {
    local arquivo="${1:-}"
    if [[ -L "$arquivo" ]]; then
        _aviso "Arquivo linkado, pulando recuperacao: ${arquivo##*/}"
        return 0
    fi

    # Validar REBUILD (com cache)
    if ! _validar_rebuild; then
        return 1
    fi

    if [[ -z "$arquivo" || ! -e "$arquivo" ]]; then
        _exibir_mensagem_centralizada "${AMARELO}" "Arquivo nao encontrado: ${arquivo:-vazio}"
        return 1
    fi

    if [[ ! -s "$arquivo" ]]; then
        _exibir_mensagem_centralizada "${AMARELO}" "Arquivo vazio: ${arquivo##*/}"
        return 0
    fi

    local dir_arquivo base_arquivo arquivo_indice old_nullglob
    local pid_jutil resultado novos _p
    # shopt -p retorna 1 com opção desligada — || true evita abortar sob set -e.
    old_nullglob=$(shopt -p nullglob) || true
    shopt -s nullglob

    # Disparar jutil em segundo plano, com saida no log de atualizacao
    { "${REBUILD}" -rebuild "$arquivo" -a -f >>"${LOG_ATU:-/dev/null}" 2>&1; } &
    pid_jutil=$!
    PIDS_JUTIL+=("$pid_jutil")

    local resultado=0 status_jutil=0
    _mostrar_progresso_backup "$pid_jutil" "Recuperando ${arquivo##*/}" || status_jutil=$?
    if (( status_jutil == 0 )); then
        _log_sucesso "Rebuild executado: ${arquivo##*/}"
        # garantir permissões máximas após o rebuild
        if ! chmod "${PERM_FILE_EXEC}" "$arquivo" 2>/dev/null; then
            _exibir_mensagem_centralizada "${AMARELO}" "Aviso: nao foi possivel alterar permissoes de $arquivo"
        fi

        # garantir permissões máximas nos arquivos .indice gerados pelo jutil
        dir_arquivo="${arquivo%/*}"
        base_arquivo="${arquivo##*/}"
        base_arquivo="${base_arquivo%.dat}"
        for arquivo_indice in "${dir_arquivo}/${base_arquivo}"*.idx; do
            if [[ -f "$arquivo_indice" ]]; then
                if ! chmod "${PERM_FILE_EXEC}" "$arquivo_indice" 2>/dev/null; then
                    _exibir_mensagem_centralizada "${AMARELO}" "Aviso: nao foi possivel alterar permissoes de $arquivo_indice"
                fi
            fi
        done
    else
        resultado=1
        if (( status_jutil == 137 || status_jutil == 143 )); then
            _erro "jutil morto pelo sistema (sinal ${status_jutil}) em: ${arquivo##*/}. Memoria insuficiente (OOM-killer)? Feche outros processos e tente de novo"
        else
            _erro "Nao recuperou: ${arquivo##*/}"
        fi
    fi

    # Remover PID do rastreador (processo ja concluido via wait no progresso)
    novos=()
    local _p
    for _p in "${PIDS_JUTIL[@]}"; do [[ "$_p" != "$pid_jutil" ]] && novos+=("$_p"); done
    PIDS_JUTIL=("${novos[@]+"${novos[@]}"}")

    # Restaurar nullglob de forma segura (sem eval)
    if [[ "$old_nullglob" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi

    _linha "-" "${VERDE}"
    return $resultado
}

#---------- FUNCOES DE TRANSFERENCIA ----------#

# Envia arquivo avulso
_enviar_arquivo_avulso() {
    clear
    local diretorio_origem arquivo_enviar destino_remoto arquivos old_nullglob

    # Solicitar diretorio de origem
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "1- Origem: Informe o diretorio onde esta o arquivo:"
    read -rp "${AMARELO} -> ${NORMAL}" diretorio_origem
    diretorio_origem=$(_sanitizar_entrada "$diretorio_origem")
    _linha

     # SEGURANÇA CRÍTICA: Validar caminho contra path traversal
    if [[ -n "$diretorio_origem" ]] && ! _validar_caminho_seguro "$diretorio_origem"; then
        _erro "Caminho de origem invalido ou malicioso: ${diretorio_origem}"
        _aguardar_tecla
        return 1
    fi

    if [[ -z "$diretorio_origem" ]]; then
        diretorio_origem="${DEFAULT_ENVIA_DIR:-}"
        if [[ -z "$diretorio_origem" || ! -d "$diretorio_origem" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio de origem nao informado ou padrao nao definido"
            _aguardar_tecla
            return 1
        fi
        _linha
        _exibir_mensagem_centralizada "${AMARELO}" "Usando diretorio padrao: ${diretorio_origem}"
        # Verificar se há arquivos no diretório
        # shopt -p retorna 1 quando a opção está desligada — || true evita
        # abortar sob set -e (AGENTS.md: set -euo pipefail obrigatório).
        old_nullglob=$(shopt -p nullglob) || true
        shopt -s nullglob
        arquivos=("${diretorio_origem}"/*)
        # shopt -p imprime "shopt -u <opt>" (desligado) ou "shopt -s <opt>"
        # (ligado) — nunca a palavra "off".
        if [[ "$old_nullglob" == *"-u"* ]]; then
            shopt -u nullglob
        else
            shopt -s nullglob
        fi
        if (( ${#arquivos[@]} == 0 )); then
            _exibir_mensagem_centralizada "${AMARELO}" "Nenhum arquivo encontrado no diretorio"
            _aguardar_tecla
            return 1
        fi
    elif [[ ! -d "$diretorio_origem" ]]; then
        _erro "Diretorio nao encontrado: ${diretorio_origem}"
        _aguardar_tecla
        return 1
    fi

    # Solicitar nome do arquivo
    _linha
    _exibir_mensagem_centralizada "${CIANO}" "Informe o arquivo que deseja enviar"
    _exibir_mensagem_centralizada "${CIANO}" "Use * para enviar todas as extensoes (ex: ARQUIVO*)"
    _linha
    read -rp "${AMARELO}2- Nome do ARQUIVO: ${NORMAL}" arquivo_enviar
    arquivo_enviar=$(_sanitizar_entrada "$arquivo_enviar")

    if [[ -z "$arquivo_enviar" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nome do arquivo nao informado"
        _aguardar_tecla
        return 1
    fi

    # SEGURANCA: validar o caminho montado (dir + nome). _enviar_arquivo_multi
    # valida so o diretorio e o destino — sem isto, ".." no nome escaparia da
    # checagem (AGENTS.md: toda operacao de arquivo passa por
    # _validar_caminho_seguro).
    if ! _validar_caminho_seguro "${diretorio_origem}/${arquivo_enviar}"; then
        _erro "Nome de arquivo invalido ou malicioso: ${arquivo_enviar}"
        _aguardar_tecla
        return 1
    fi

    # Verificar se o arquivo contém wildcard (*)
    if [[ "$arquivo_enviar" == *"*"* ]]; then
        # Listar arquivos que correspondem ao padrão
        local arquivos_encontrados=()
        while IFS= read -r -d '' arquivo; do
            arquivos_encontrados+=("$arquivo")
        done < <(find "${diretorio_origem:-.}" -maxdepth 1 -type f -name "${arquivo_enviar}" -print0)

        if (( ${#arquivos_encontrados[@]} == 0 )); then
            _exibir_mensagem_centralizada "${AMARELO}" "Nenhum arquivo encontrado com o padrao: ${arquivo_enviar}"
            _aguardar_tecla
            return 1
        fi

        # Mostrar arquivos encontrados
        _linha
        _exibir_mensagem_centralizada "${CIANO}" "Arquivos encontrados (${#arquivos_encontrados[@]}):"
        for arquivo in "${arquivos_encontrados[@]}"; do
            _exibir_mensagem_centralizada "${VERDE}" "  - ${arquivo##*/}"
        done
        _linha

        # Confirmar envio
        local confirmacao
        read -rp "${AMARELO}Deseja enviar todos esses arquivos? [S/N]: ${NORMAL}" confirmacao
        confirmacao="${confirmacao^^}"

        if [[ "$confirmacao" != "S" ]]; then
            _exibir_mensagem_centralizada "${AMARELO}" "Envio cancelado pelo usuario"
            _aguardar_tecla
            return 0
        fi
    else
        # Verificação para arquivo único (sem wildcard)
        if [[ ! -e "${diretorio_origem}/${arquivo_enviar}" ]]; then
            _exibir_mensagem_centralizada "${AMARELO}" "${arquivo_enviar} nao encontrado em ${diretorio_origem}"
            _aguardar_tecla
            return 1
        fi
    fi

    # Solicitar destino remoto
    printf "\n"
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "3- Destino: Informe o diretorio no servidor:"
    read -rp "${AMARELO} -> ${NORMAL}" destino_remoto
    destino_remoto=$(_sanitizar_entrada "$destino_remoto")
    _linha

    if [[ -z "$destino_remoto" ]]; then
        _erro "Destino nao informado"
        _aguardar_tecla
        return 1
    fi

    # SEGURANCA: bloquear path traversal e caracteres perigosos no destino remoto
    if ! _validar_caminho_seguro "$destino_remoto"; then
        _erro "Caminho remoto invalido ou malicioso: ${destino_remoto}"
        _aguardar_tecla
        return 1
    fi

    # Enviar arquivo(s)
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "A senha do usuario remoto sera solicitada pelo ssh/rsync (sem eco)."
    _linha
    _enviar_arquivo_multi "${diretorio_origem}" "${arquivo_enviar}" "${destino_remoto}"
}

# Recebe arquivo avulso
_receber_arquivo_avulso() {
    clear
    local origem_remota arquivo_receber destino_local

    # Solicitar origem remota
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "1- Origem: Diretorio remoto do arquivo:"
    read -rp "${AMARELO} -> ${NORMAL}" origem_remota
    origem_remota=$(_sanitizar_entrada "$origem_remota")
    _linha

    # SEGURANCA: validar caminho remoto
    if [[ -z "$origem_remota" ]]; then
        _erro "Origem remota nao informada"
        _aguardar_tecla
        return 1
    fi

    if ! _validar_caminho_seguro "$origem_remota"; then
        _erro "Caminho remoto invalido ou malicioso: ${origem_remota}"
        _aguardar_tecla
        return 1
    fi

    # Solicitar nome do arquivo
    _exibir_mensagem_centralizada "${VERMELHO}" "Informe o arquivo que deseja RECEBER"
    _linha
    read -rp "${AMARELO}2- Nome do ARQUIVO: ${NORMAL}" arquivo_receber
    arquivo_receber=$(_sanitizar_entrada "$arquivo_receber")

    if [[ -z "$arquivo_receber" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nome do arquivo nao informado"
        _aguardar_tecla
        return 1
    fi

    # SEGURANCA: validar o caminho remoto montado (origem + nome). A origem
    # acima ja passou, mas ".." no nome permitiria ler fora dela — e o
    # caminho concatenado nao e revalidado por _receber_scp.
    if ! _validar_caminho_seguro "${origem_remota}/${arquivo_receber}"; then
        _erro "Nome de arquivo invalido ou malicioso: ${arquivo_receber}"
        _aguardar_tecla
        return 1
    fi

    # Solicitar destino local
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "3- Destino: Diretorio local para receber:"
    read -rp "${AMARELO} -> ${NORMAL}" destino_local
    destino_local=$(_sanitizar_entrada "$destino_local")

    if [[ -z "$destino_local" ]]; then
        destino_local="${CFG_PORTALSAV:-}"
    fi

    # SEGURANCA: bloquear path traversal e caracteres perigosos no destino
    if [[ -z "$destino_local" ]] || ! _validar_caminho_seguro "$destino_local"; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio de destino invalido ou malicioso: ${destino_local}"
        _aguardar_tecla
        return 1
    fi

    if [[ ! -d "$destino_local" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio de destino nao encontrado: ${destino_local}"
        _aguardar_tecla
        return 1
    fi

    # Receber arquivo
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "A senha do usuario remoto sera solicitada pelo scp (sem eco)."
    _linha
    if _receber_scp "${origem_remota}/${arquivo_receber}" "${destino_local}/"; then
        _exibir_mensagem_centralizada "${VERDE}" "Arquivo recebido com sucesso em \"${destino_local}\""
        _linha
        _aguardar 3
    else
        _erro "no recebimento do arquivo"
        _aguardar_tecla
    fi
}

#---------- FUNCOES DE EXPURGO ----------#

# Executa expurgador de arquivos antigos
_executar_expurgador() {
    # Esta varredura de +30 dias repete os mesmos diretorios de
    # _executar_expurgador_diario (utils.sh, bootstrap) — o que ela acrescenta
    # de exclusivo e o expurgo dos .zip em E_EXEC/T_TELAS e a lista limpadir.
    # O diario e protegido por flag diaria e nao toca nesses dois.
    local savlog="${RAIZ}/portalsav/log"
    local err_isc="${RAIZ}/err_isc"
    local viewvix="${RAIZ}/savisc/viewvix/tmp"
    clear

    _linha
    _exibir_mensagem_centralizada "${VERMELHO}" "Verificando e excluindo arquivos com mais de 30 dias"
    _linha
    printf "\n"

    # Definir diretorios para limpeza
    local diretorios_limpeza=(
        "${DEFAULT_BACKUP_DIR}/"
        "${DEFAULT_BIBLIOTECA_DIR}/"
        "${DEFAULT_BIBLIOTECA_ATUAL_DIR}/"
		"${DEFAULT_PROGS_ATUAL_DIR}/"
        "${DEFAULT_PROGS_DIR}/"
        "${DEFAULT_ENVIA_DIR}/"
        "${CFG_PORTALSAV}/"
        "${DEFAULT_BASEBACKUP_DIR}/"
        "${DEFAULT_LOGS_DIR}/"
        "${savlog}"
        "${err_isc}"
        "${viewvix}"
    )

    # Limpar arquivos antigos nos diretorios padrao (finds em paralelo, log em ordem)
    # SEGURANCA: nunca apagar arquivos de dados (.dat) nem indices (.idx)
    local dir_tmp_exp
    dir_tmp_exp=$(mktemp -d -t expurgo.XXXXXX) || dir_tmp_exp=""
    local diretorio idx
    local -a dirs_validos=()
    local -a dirs_status=() # 1=valido 0=invalido
    local -a pids_exp=()    # PIDs do expurgo (evita `wait` sem argumento esperar jobs alheios)
    local _pe
    for diretorio in "${diretorios_limpeza[@]}"; do
        if [[ -d "$diretorio" ]] && _garantir_diretorio "$diretorio" verificar "diretorio de expurgo" silencioso; then
            dirs_validos+=("$diretorio")
            dirs_status+=("1")
        else
            dirs_validos+=("$diretorio")
            dirs_status+=("0")
        fi
    done
    if [[ -n "$dir_tmp_exp" ]]; then
        pids_exp=()
        for idx in "${!dirs_validos[@]}"; do
            (( dirs_status[idx] == 1 )) || continue
            (
                diretorio="${dirs_validos[$idx]}"
                find "${diretorio:-.}" -type f -mtime +30 \
                    ! -iname "*.dat" ! -iname "*.idx" -print -delete 2>"${dir_tmp_exp}/${idx}.err" | wc -l > "${dir_tmp_exp}/${idx}.count"
            ) &
            pids_exp+=("$!")
        done
        # Espera SOMENTE os jobs deste expurgo: `wait` sem argumento bloquearia
        # tambem por PIDS_JUTIL/BACKUP_PID de rotinas anteriores.
        for _pe in ${pids_exp[@]+"${pids_exp[@]}"}; do
            wait "$_pe" 2>/dev/null || true
        done
    fi
    local arquivos_removidos contagem
    for idx in "${!dirs_validos[@]}"; do
        diretorio="${dirs_validos[$idx]}"
        if (( dirs_status[idx] == 0 )); then
            _exibir_mensagem_centralizada "${AMARELO}" "Diretorio nao encontrado ou inseguro: ${diretorio}"
            continue
        fi
        arquivos_removidos="0"
        if [[ -n "$dir_tmp_exp" && -f "${dir_tmp_exp}/${idx}.count" ]]; then
            contagem=$(<"${dir_tmp_exp}/${idx}.count")
            arquivos_removidos="${contagem//[[:space:]]/}"
            [[ -z "$arquivos_removidos" ]] && arquivos_removidos="0"
            if [[ -s "${dir_tmp_exp}/${idx}.err" ]]; then
                _log "AVISO expurgo em ${diretorio}: $(<"${dir_tmp_exp}/${idx}.err")" "${LOG_LIMPA}"
            fi
        else
            # Fallback sequencial se mktemp falhou
            arquivos_removidos=$(find "${diretorio:-.}" -type f -mtime +30 \
                ! -iname "*.dat" ! -iname "*.idx" -print -delete 2>/dev/null | wc -l)
            arquivos_removidos="${arquivos_removidos//[[:space:]]/}"
        fi
        _log "Expurgo: ${arquivos_removidos} arquivo(s) removido(s) de ${diretorio}" "${LOG_LIMPA}"
        _exibir_mensagem_centralizada "${VERDE}" "Limpando arquivos do diretorio: ${diretorio} (${arquivos_removidos} arquivos)"
    done

    local diretorios_zip=(
        "${E_EXEC}/"
        "${T_TELAS}/"
    )

    # Limpar arquivos ZIP antigos especificos (paralelo, mesma tecnica)
    local -a zips_validos=()
    local -a zips_status=()
    for diretorio in "${diretorios_zip[@]}"; do
        if [[ -d "$diretorio" ]] && _garantir_diretorio "$diretorio" verificar "diretorio de expurgo" silencioso; then
            zips_validos+=("$diretorio")
            zips_status+=("1")
        else
            zips_validos+=("$diretorio")
            zips_status+=("0")
        fi
    done
    if [[ -n "$dir_tmp_exp" ]]; then
        pids_exp=()
        for idx in "${!zips_validos[@]}"; do
            (( zips_status[idx] == 1 )) || continue
            (
                diretorio="${zips_validos[$idx]}"
                find "${diretorio:-.}" -name "*.zip" -type f -mtime +15 -print -delete 2>"${dir_tmp_exp}/z${idx}.err" | wc -l > "${dir_tmp_exp}/z${idx}.count"
            ) &
            pids_exp+=("$!")
        done
        for _pe in ${pids_exp[@]+"${pids_exp[@]}"}; do
            wait "$_pe" 2>/dev/null || true
        done
    fi
    local zips_removidos
    for idx in "${!zips_validos[@]}"; do
        diretorio="${zips_validos[$idx]}"
        if (( zips_status[idx] == 0 )); then
            _exibir_mensagem_centralizada "${AMARELO}" "Diretorio nao encontrado ou inseguro: ${diretorio}"
            continue
        fi
        zips_removidos="0"
        if [[ -n "$dir_tmp_exp" && -f "${dir_tmp_exp}/z${idx}.count" ]]; then
            contagem=$(<"${dir_tmp_exp}/z${idx}.count")
            zips_removidos="${contagem//[[:space:]]/}"
            [[ -z "$zips_removidos" ]] && zips_removidos="0"
            if [[ -s "${dir_tmp_exp}/z${idx}.err" ]]; then
                _log "AVISO expurgo ZIP em ${diretorio}: $(<"${dir_tmp_exp}/z${idx}.err")" "${LOG_LIMPA}"
            fi
        else
            zips_removidos=$(find "${diretorio:-.}" -name "*.zip" -type f -mtime +15 -print -delete 2>/dev/null | wc -l)
            zips_removidos="${zips_removidos//[[:space:]]/}"
        fi
        _log "Expurgo: ${zips_removidos} arquivo(s) .zip removido(s) de ${diretorio}" "${LOG_LIMPA}"
        _exibir_mensagem_centralizada "${VERDE}" "Limpando arquivos .zip antigos: ${diretorio} (${zips_removidos} arquivos)"
    done
    [[ -n "$dir_tmp_exp" ]] && rm -rf -- "$dir_tmp_exp" 2>/dev/null || true

    # Limpar diretorios listados no arquivo limpadir (um diretorio por linha)
    _executar_expurgador_lista_dirs

    printf "\n"
    _linha
    _aguardar_tecla
    return 0
}

# Expurgo de arquivos em diretorios listados no arquivo configuracoes/limpadir
# Cada linha valida e um caminho absoluto. Linhas em branco e comentarios (#)
# sao ignorados. Criterio: mais de 30 dias, igual ao expurgo principal — antes
# eram 7, o que apagava recem-criados sem dar chance de reenvio.
# Remove arquivos de dados (.dat) e indices (.idx) tambem — diferenca
# deliberada em relacao ao expurgo de 30 dias acima, que os preserva.
# Nao existe zip de resgate aqui: o backup diario e o unico caminho de volta,
# por isso a remocao e precedida de uma confirmacao unica e cada arquivo
# removido e registrado no log antes do -delete.
# Retorna: 0 sempre (expurgo e tolerante a falhas individuais)
_executar_expurgador_lista_dirs() {
    local arquivo_lista="${CFG_DIR:-}${CFG_DIR:+/}limpadir"

    if [[ ! -f "$arquivo_lista" ]]; then
        _log "limpadir nao existe, expurgo de diretorios extras pulado: $arquivo_lista" "${LOG_LIMPA}"
        return 0
    fi

    if [[ ! -r "$arquivo_lista" ]]; then
        _log "AVISO: limpadir sem permissao de leitura, expurgo de diretorios extras ignorado: $arquivo_lista" "${LOG_LIMPA}"
        return 0
    fi

    local linha diretorio confirmacao
    local -a dirs_limpar=()
    while IFS= read -r linha || [[ -n "$linha" ]]; do
        # trim de espacos em volta
        linha="${linha#"${linha%%[![:space:]]*}"}"
        linha="${linha%"${linha##*[![:space:]]}"}"
        # pular em branco e comentarios
        [[ -z "$linha" || "$linha" == \#* ]] && continue

        diretorio="$linha"

        if ! _garantir_diretorio "$diretorio" verificar "diretorio de expurgo" silencioso; then
            _log "AVISO: diretorio invalido ou inseguro no limpadir, ignorado: $diretorio" "${LOG_LIMPA}"
            _exibir_mensagem_centralizada "${AMARELO}" "Diretorio invalido ou inseguro: $diretorio"
            continue
        fi

        if [[ ! -d "$diretorio" ]]; then
            _log "AVISO: diretorio nao encontrado no limpadir: $diretorio" "${LOG_LIMPA}"
            _exibir_mensagem_centralizada "${AMARELO}" "Diretorio nao encontrado: $diretorio"
            continue
        fi

        dirs_limpar+=("$diretorio")
    done < "$arquivo_lista"

    if (( ${#dirs_limpar[@]} == 0 )); then
        return 0
    fi

    # Extensoes alvo do expurgo. Edite esta lista para incluir ou alterar o que
    # e excluido. Padrao "todas": apaga qualquer tipo de arquivo com mais de
    # LIM_PADIR_DIAS dias. Outro valor restringe o find aos tipos listados
    # (ponto opcional, minusculas ou maiusculas).
    # local -a extensoes_limpar=("todas")
    local -a extensoes_limpar=("txt" "xml" "err")
    # local -a extensoes_limpar=("DAT" "IDX" "bak" "log" "tmp" "jnl")
    # local -a extensoes_limpar=()   # vazio equivale a "todas"

    # Monta o filtro do find: ( -iname "*.dat" -o -iname "*.idx" ).
    # O agrupamento e obrigatorio — sem ele o -o faz o -print -delete
    # valer apenas para a ultima extensao.
    local -a filtro_ext=()
    local ext
    if (( ${#extensoes_limpar[@]} > 0 )); then
        for ext in "${extensoes_limpar[@]}"; do
            ext="${ext//[[:space:]]/}"
            [[ -z "$ext" ]] && continue
            [[ "$ext" == "todas" || "$ext" == "*" ]] && continue
            [[ "$ext" == .* ]] || ext=".${ext}"
            if (( ${#filtro_ext[@]} > 0 )); then
                filtro_ext+=(-o)
            fi
            filtro_ext+=(-iname "*${ext}")
        done
    fi
    if (( ${#filtro_ext[@]} > 0 )); then
        # Parenteses literais (sem barra): find e executado direto, sem shell
        # intermediario para remover o escape.
        filtro_ext=('(' "${filtro_ext[@]}" ')')
    fi

    # Pre-contagem por extensao: mostra o que sera apagado ANTES da
    # confirmacao. Sem isso nao ha como distinguir "filtro nao casou" de
    # "arquivo recente demais" — as duas situacoes produzem zeroremovidos.
    # Busca sem -delete: apenas conta, nao altera nada.
    local -A contagem_ext=()
    local total_apagar=0
    local nome_arq ext_chave
    for diretorio in "${dirs_limpar[@]}"; do
        while IFS= read -r nome_arq; do
            [[ -z "$nome_arq" ]] && continue
            ext_chave="${nome_arq##*/}"
            if [[ "$ext_chave" == *.* && "$ext_chave" != .* ]]; then
                ext_chave=".${ext_chave##*.}"
            else
                ext_chave="(sem-extensao)"
            fi
            ext_chave="${ext_chave,,}"
            contagem_ext["$ext_chave"]=$(( ${contagem_ext["$ext_chave"]:-0} + 1 ))
            ((total_apagar++)) || true
        done < <(find "${diretorio}" -type f -mtime "+${LIM_PADIR_DIAS}" \
            ${filtro_ext[@]+"${filtro_ext[@]}"} -print 2>/dev/null)
    done

    # Confirmacao unica: a remocao e irreversivel e inclui .dat/.idx.
    _linha
    if (( total_apagar > 0 )); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Expurgo IRREVERSIVEL (sem arquivo de resgate) de ${total_apagar} arquivo(s) com mais de ${LIM_PADIR_DIAS} dias:"
    else
        _exibir_mensagem_centralizada "${AMARELO}" "Nenhum arquivo elegivel (extensoes filtradas + mais de ${LIM_PADIR_DIAS} dias), nada sera apagado:"
    fi

    if (( ${#contagem_ext[@]} > 0 )); then
        _exibir_mensagem_centralizada "${CIANO}" "  Por extensao:"
        # mapfile + loop, nunca $(...) sem aspas: o word-split quebraria
        # qualquer chave que contenha espaco.
        local -a chaves_ext=()
        mapfile -t chaves_ext < <(printf '%s\n' "${!contagem_ext[@]}" | sort)
        local chave_ext
        for chave_ext in ${chaves_ext[@]+"${chaves_ext[@]}"}; do
            _exibir_mensagem_centralizada "${CIANO}" "    ${chave_ext} : ${contagem_ext[${chave_ext}]} arquivo(s)"
        done
    fi

    _exibir_mensagem_centralizada "${AMARELO}" "  Diretorios:"
    for diretorio in "${dirs_limpar[@]}"; do
        _exibir_mensagem_centralizada "${AMARELO}" "    - $diretorio"
    done

    if (( total_apagar == 0 )); then
        _log "Expurgo (limpadir): nenhum arquivo elegivel para remocao" "${LOG_LIMPA}"
        return 0
    fi

    read -rp "${AMARELO}Confirma o expurgo acima? [S/N]: ${NORMAL}" confirmacao
    confirmacao=$(_sanitizar_entrada "${confirmacao:-}")
    confirmacao="${confirmacao^^}"

    if [[ "$confirmacao" != "S" ]]; then
        _log "Expurgo (limpadir) cancelado pelo usuario (${total_apagar} arquivo(s) preservados)" "${LOG_LIMPA}"
        _exibir_mensagem_centralizada "${AMARELO}" "Expurgo (limpadir) cancelado — ${total_apagar} arquivo(s) preservados"
        return 0
    fi

    # Contagem no proprio shell (sem fork de wc): find -print emite o nome antes
    # do -delete do mesmo arquivo, entao o log sempre registra o que saiu.
    local arquivos_removidos arquivo_removido
    for diretorio in "${dirs_limpar[@]}"; do
        arquivos_removidos=0
        while IFS= read -r arquivo_removido; do
            _log "Expurgo (limpadir): removendo ${arquivo_removido}" "${LOG_LIMPA}"
            ((arquivos_removidos++)) || true
        done < <(find "${diretorio}" -type f -mtime "+${LIM_PADIR_DIAS}" \
            ${filtro_ext[@]+"${filtro_ext[@]}"} -print -delete 2>/dev/null)

        _log "Expurgo (limpadir): ${arquivos_removidos} arquivo(s) removido(s) de ${diretorio}" "${LOG_LIMPA}"
        _exibir_mensagem_centralizada "${VERDE}" "Limpando diretorio extra: ${diretorio} (${arquivos_removidos} arquivos)"
    done

    return 0
}

# Exibe um arquivo de log com paginacao segura (evita cat de GB no terminal)
# Parametros: $1 = caminho do log
_exibir_log_arquivo() {
    local arquivo_log="${1:-}"
    local max_linhas="${C_LOG_LINHAS:-200}"
    [[ "$max_linhas" =~ ^[0-9]+$ ]] || max_linhas=200
    if (( max_linhas < 10 )); then
        max_linhas=200
    fi
    if [[ ! -s "$arquivo_log" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Arquivo sem dados."
        return 0
    fi
    local total_linhas
    total_linhas=$(wc -l < "$arquivo_log" 2>/dev/null || echo "?")
    total_linhas="${total_linhas//[[:space:]]/}"
    # Numero de linhas sozinho nao protege: um log de 5 linhas com linhas
    # giganticas (stack trace / base64) passaria pelo cat e despejaria MBs no
    # terminal. Teto em bytes ~ 512 por linha exibida.
    local total_bytes
    total_bytes=$(wc -c < "$arquivo_log" 2>/dev/null || echo "?")
    total_bytes="${total_bytes//[[:space:]]/}"
    local teto_bytes=$(( max_linhas * 512 ))

    if [[ "$total_linhas" =~ ^[0-9]+$ ]] \
        && [[ ! "$total_bytes" =~ ^[0-9]+$ || "$total_bytes" -le "$teto_bytes" ]] \
        && (( total_linhas <= max_linhas * 2 )); then
        cat -- "$arquivo_log"
        return 0
    fi
    _aviso "Arquivo grande (${total_linhas:-?} linhas / ${total_bytes:-?} bytes). Exibindo ultimas ${max_linhas}."
    if [[ -t 1 ]] && command -v less >/dev/null 2>&1; then
        tail -n "$max_linhas" -- "$arquivo_log" | less -R
    else
        tail -n "$max_linhas" -- "$arquivo_log"
    fi
    return 0
}

# Lista e exibe logs de um tipo (atualizacao|limpeza)
# Parametros: $1 = titulo legivel (ex: "atualizacao"), $2 = prefixo do arquivo (ex: "atualiza")
_listar_logs() {
    local titulo="${1:-}"
    local prefixo="${2:-}"
    local logs=()
    local i=1
    local log
    local opcao
    local log_selecionado

    clear
    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Logs de ${titulo} encontrados em ${DEFAULT_LOGS_DIR}:"
    _linha

    # Validar se DEFAULT_LOGS_DIR esta configurado e existe
    if [[ -z "${DEFAULT_LOGS_DIR:-}" || ! -d "${DEFAULT_LOGS_DIR}" ]]; then
        _erro "Diretorio de logs nao configurado ou inexistente: ${DEFAULT_LOGS_DIR:-vazio}"
        _aguardar_tecla
        return 1
    fi

    # SEGURANCA: prefixo restrito evita glob injection (ex: "*")
    if [[ ! "$prefixo" =~ ^[A-Za-z0-9._-]+$ ]]; then
        _erro "Prefixo de log invalido: ${prefixo}"
        _aguardar_tecla
        return 1
    fi

    # Filtrar apenas arquivos validos e legiveis (find+sort: 1 passada, nomes com espaco ok)
    logs=()
    while IFS= read -r -d '' log; do
        logs+=("$log")
    done < <(find "${DEFAULT_LOGS_DIR}" -maxdepth 1 -type f -name "${prefixo}.*" -print0 2>/dev/null | sort -z)
    if [[ ${#logs[@]} -eq 0 ]]; then
        _erro "Nenhum log de ${titulo} encontrado."
        _aguardar_tecla
        return 1
    fi

    # Exibir lista numerada dos logs disponiveis
    for log in "${logs[@]}"; do
        _exibir_mensagem_centralizada "${CIANO}" "  ${i}) ${log##*/}"
        (( i++ ))
    done
    _linha
    _exibir_mensagem_centralizada "${VERDE}" "  0) Visualizar todos"
    _linha

    read -rp "${AMARELO}Selecione o arquivo [0-$((i-1))]: ${NORMAL}" opcao

    # Validar entrada
    if [[ -z "$opcao" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nenhuma opcao selecionada."
        _aguardar_tecla
        return 0
    fi

    opcao=$(_sanitizar_entrada "$opcao")
    if ! [[ "$opcao" =~ ^[0-9]+$ ]] || (( opcao < 0 || opcao >= i )); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Opcao invalida."
        _aguardar_tecla
        return 0
    fi

    clear
    _linha

    if (( opcao == 0 )); then
        # Visualizar todos os logs (paginado)
        _aviso "Exibindo todos os logs de ${titulo}:"
        _linha
        for log in "${logs[@]}"; do
            _exibir_mensagem_centralizada "${CIANO}" ">>> Arquivo: ${log##*/}"
            _linha
            _exibir_log_arquivo "$log"
            printf "\n"
            _linha
        done
    else
        # Visualizar log selecionado (paginado)
        log_selecionado="${logs[$((opcao-1))]}"
        _exibir_mensagem_centralizada "${AMARELO}" "Exibindo log: ${log_selecionado##*/}"
        _linha
        _exibir_log_arquivo "$log_selecionado"
        printf "\n"
        _linha
    fi
    _exibir_mensagem_centralizada "${AMARELO}" "<< Pressione ENTER para voltar >>"
    read -r
}

# Lista os logs de atualizacao
_listar_logs_atualizacao() {
    _listar_logs "atualizacao" "atualiza"
}

# Lista os logs de limpeza
_listar_logs_limpeza() {
    _listar_logs "limpeza" "limpando"
}
