#!/usr/bin/env bash
set -euo pipefail
#
# vaievem.sh - Modulo de Operacoes de Sincronizacao
# Responsavel por operacoes de download/upload via rsync, sftp e ssh
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# DEPENDENCIAS DE CARGA (principal.sh): este modulo e sourced ANTES de
# programas.sh (dono de ARQUIVOS_PROGRAMA; guard proprio nas funcoes que o
# usam). Requer utils.sh (_ssh_aceitar_novo, _log*), principal.sh
# (_criar_diretorio_seguro) e constantes.sh (DEFAULT_*).
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 30/09/2026
#

CHAVE="${DEFAULT_CHAVE_SSH:-}"

# =============================================================================
# VALIDACAO DE SEGURANCA (AGENTS.md: Validate and sanitize user input)
# =============================================================================
# Valida caminhos contra path traversal e injeção de caracteres especiais
# Rejeita tambem raiz ("/", "//"): nenhum destino legitimo do SAV e a raiz
# (paridade com _validar_diretorio_backup/_validar_diretorio_expurgavel).
# Caminhos absolutos legitimos (/savisc/...) continuam aceitos.
# Parametros: $1=caminho
# Retorna: 0=seguro 1=inseguro
_validar_caminho_seguro() {
    local caminho="${1:-}"
    local regex_perigoso=$'[;|&$`<>"\']'

    if [[ -z "$caminho" || "$caminho" == "/" || "$caminho" == "//" ]]; then
        return 1
    fi
    # Item 10: teto de tamanho. Sem ele um payload gigante atravessava todas as
    # outras verificacoes e ainda seria interpolado em log/linha de comando.
    if (( ${#caminho} > 4096 )); then
        return 1
    fi
    # Caracteres de controle (inclui \n e \r) permitiriam forjar uma linha de log
    # e quebrar entradas baseadas em linha.
    if [[ "$caminho" == *[$'\001'-$'\037'$'\177']* ]]; then
        return 1
    fi
    if [[ "$caminho" == *"/.."* || "$caminho" == ".."* || "$caminho" =~ $regex_perigoso ]]; then
        return 1
    fi
    return 0
}

# Valida o par usuario@servidor usado nas origens/destinos SSH
# (user@host:path). Complementa _validar_caminho_seguro, que cobre so o path.
# Retorna: 0=valido 1=invalido (vazio, com espaco, metacaractere ou separador)
_validar_destino_ssh() {
    local usuario="${1:-}"
    local servidor="${2:-}"
    local regex_perigoso=$'[;|&$`<>"\']'

    if [[ -z "$usuario" || -z "$servidor" ]]; then
        return 1
    fi
    # Usuario nao pode conter espacos, @ : / nem metacaracteres
    if [[ "$usuario" == *[[:space:]@:/]* || "$usuario" =~ $regex_perigoso ]]; then
        return 1
    fi
    # Servidor (hostname/IP) nao pode conter espacos, @ nem metacaracteres
    if [[ "$servidor" == *[[:space:]@]* || "$servidor" =~ $regex_perigoso ]]; then
        return 1
    fi
    return 0
}

# Valida uma origem/destino remoto completo no formato "usuario@host:caminho",
# aplicando _validar_caminho_seguro ao sufixo apos o primeiro ":".
# Retorna: 0=valido 1=invalido (sem ":" ou sufixo inseguro)
_validar_origem_remota() {
    local origem="${1:-}"

    if [[ "$origem" != *":"* ]]; then
        return 1
    fi
    _validar_caminho_seguro "${origem#*:}"
}

# Verifica se autenticacao por chave SSH deve ser utilizada
# Retorna 0 (true) se chave deve ser usada, 1 (false) caso contrario
_usar_chave_ssh() {
    local acessochave="${CFG_CHAVE_SSH:-}"
    local chave="${CHAVE:-}"

    # Se a variavel chavessh (configuracao do .config) for "n",
    # pular o controle de acesso a chave e continuar pedindo senha
    if [[ "${acessochave,,}" == "n" ]]; then
        return 1
    fi

    if [[ "${acessochave,,}" != "s" ]]; then
        return 1
    fi

    if [[ -z "$chave" ]]; then
        _log_erro "CFG_CHAVE_SSH configurado como 's', mas DEFAULT_CHAVE_SSH nao definido"
        return 1
    fi

    if [[ ! -f "$chave" ]]; then
        _log_erro "Arquivo de chave SSH nao encontrado: ${chave}"
        return 1
    fi

    if [[ ! -r "$chave" ]]; then
        _log_erro "Arquivo de chave SSH sem permissao de leitura: ${chave}"
        return 1
    fi
    return 0
}


# Constrói o comando scp em um array nomeado, com opções de conexão e (opcional) chave SSH.
# Uso: _montar_cmd_scp <nome_array_ref> <porta> [timeout] [alive_interval] [alive_count]
#   Os tres ultimos defaultam para SSH_TIMEOUT/SSH_ALIVE_INTERVAL/SSH_ALIVE_COUNT.
# SEGURANCA: sem eval — os valores sao validados (porta/timeout/alive numericos)
# e publicados no array via nameref (Bash 4.3+) ou serializacao IFS (4.0-4.2).
# Payloads com aspas/substituicao viram string literal, nunca argumentos extras.
_montar_cmd_scp() {
    local _cmd_ref="${1:-}"
    local porta="${2:-}"
    local timeout="${3:-${SSH_TIMEOUT}}"
    local alive_int="${4:-${SSH_ALIVE_INTERVAL}}"
    local alive_max="${5:-${SSH_ALIVE_COUNT}}"

    # Validar entradas que viram opcoes do scp: apenas digitos
    if ! [[ "$porta" =~ ^[0-9]+$ && -n "$porta" ]] ||
       ! [[ "$timeout" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_int" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_max" =~ ^[0-9]+$ ]]; then
        _erro "Parametros invalidos para _montar_cmd_scp (porta/timeout/alive devem ser numericos)"
        return 1
    fi

    local -a _opcoes_base=(
        scp
        -P "$porta"
        -o "ConnectTimeout=${timeout}"
        -o "ServerAliveInterval=${alive_int}"
        -o "ServerAliveCountMax=${alive_max}"
        -o "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
    )

    if _usar_chave_ssh; then
        _opcoes_base+=(-i "$CHAVE" -o "BatchMode=yes")
    fi

    # Publicar no array do chamador (mesma estrategia do _montar_cmd_ssh:
    # nameref em Bash 4.3+, serializacao IFS em 4.0-4.2). O ${var?} documenta
    # que o nome do array e intencionalmente dinamico (escopo do chamador).
    # Item 11: o nome interno do nameref tambem precisa de guarda — se o chamador
    # batesse nele, o Bash 4.3+ aborta com "circular name reference".
    if [[ "$_cmd_ref" == "_scp_ref" || -z "$_cmd_ref" ]]; then
        _erro "Nome de array invalido para _montar_cmd_scp: ${_cmd_ref:-vazio}"
        return 1
    fi
    if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )); then
        local -n _scp_ref="${_cmd_ref?}"
        _scp_ref=("${_opcoes_base[@]}")
    else
        local _sep=$'\x1f'
        local _serializado
        printf -v _serializado "%s${_sep}" "${_opcoes_base[@]}"
        _serializado="${_serializado%"${_sep}"}"
        IFS="${_sep}" read -r -a "${_cmd_ref?}" <<<"${_serializado}"
    fi

    return 0
}

# Constrói as opções de conexão SSH em um array nomeado (base para rsync -e).
# Uso: _montar_cmd_ssh <nome_array_ref> <porta> [timeout] [alive_interval] [alive_count]
#   Os tres ultimos defaultam para SSH_TIMEOUT/SSH_ALIVE_INTERVAL/SSH_ALIVE_COUNT.
# SEGURANCA: sem eval — os valores sao validados (porta/timeout/alive numericos)
# e publicados no array via nameref (Bash 4.3+) ou serializacao IFS (4.0-4.2).
# Centraliza a montagem hoje duplicada em _enviar_rsync e _enviar_rsync_lote.
_montar_cmd_ssh() {
    local _cmd_ref="${1:-}"
    local porta="${2:-}"
    local timeout="${3:-${SSH_TIMEOUT}}"
    local alive_int="${4:-${SSH_ALIVE_INTERVAL}}"
    local alive_max="${5:-${SSH_ALIVE_COUNT}}"

    # Validar entradas que viram opcoes do ssh: apenas digitos
    if ! [[ "$porta" =~ ^[0-9]+$ && -n "$porta" ]] ||
       ! [[ "$timeout" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_int" =~ ^[0-9]+$ ]] ||
       ! [[ "$alive_max" =~ ^[0-9]+$ ]]; then
        _erro "Parametros invalidos para _montar_cmd_ssh (porta/timeout/alive devem ser numericos)"
        _log_erro "Parametros invalidos para _montar_cmd_ssh (porta=${porta} timeout=${timeout} alive=${alive_int}/${alive_max})"
        return 1
    fi

    local -a _opcoes_ssh=(
        ssh
        -p "$porta"
        -o "ConnectTimeout=${timeout}"
        -o "ServerAliveInterval=${alive_int}"
        -o "ServerAliveCountMax=${alive_max}"
        -o "StrictHostKeyChecking=$(_ssh_aceitar_novo)"
    )

    if _usar_chave_ssh; then
        _opcoes_ssh+=(-i "$CHAVE" -o "BatchMode=yes")
    fi

    # Publicar no array do chamador (mesma estrategia do _montar_cmd_scp).
    # Item 11: ver a nota sobre colisao de nome do nameref em _montar_cmd_scp.
    if [[ "$_cmd_ref" == "_ssh_ref" || -z "$_cmd_ref" ]]; then
        _erro "Nome de array invalido para _montar_cmd_ssh: ${_cmd_ref:-vazio}"
        return 1
    fi
    if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )); then
        # Bash 4.3+: nameref — publica o array diretamente, sem serializacao.
        local -n _ssh_ref="${_cmd_ref?}"
        _ssh_ref=("${_opcoes_ssh[@]}")
    else
        local _sep=$'\x1f'
        local _serializado
        printf -v _serializado "%s${_sep}" "${_opcoes_ssh[@]}"
        _serializado="${_serializado%"${_sep}"}"
        IFS="${_sep}" read -r -a "${_cmd_ref?}" <<<"${_serializado}"
    fi

    return 0
}

# Protege um argumento para uso dentro de string interpretada por shell
# (caso do rsync -e). Elementos simples passam nus; os demais vao entre aspas
# simples POSIX com escape de ' embutida. Equivale ao %q para os casos reais
# (caminho de chave com espacos ou $).
# Uso: _proteger_arg_shell <texto>  (imprime o texto protegido)
_proteger_arg_shell() {
    local _texto="${1:-}"
    local _re_seguro='^[A-Za-z0-9@%_+=:,./-]+$'

    if [[ "$_texto" =~ $_re_seguro ]]; then
        printf '%s' "$_texto"
        return 0
    fi
    # Aspas simples: ' vira '\'' (fecha, escapa, reabre)
    printf "'%s'" "${_texto//\'/\'\\\'\'}"
}

# Junta um array de comando em uma unica string para o rsync -e (que exige
# string, nao array). Usa SEMPRE _proteger_arg_shell (aspas simples POSIX).
# Uso: _juntar_comando <elemento...>
#
# Antes havia dois caminhos: `printf %q` em Bash 4.4+ e aspas POSIX em 4.0-4.2.
# O caminho novo era o MENOS portavel dos dois — `%q` pode emitir $'...'
# (ANSI-C quoting), que dash/sh nao interpreta, e o rsync entrega o valor de -e
# a um shell. Em Ubuntu 10.04/12.04 o /bin/sh e dash, entao o caminho %q quebrava
# justamente onde o fallback funcionaria. Agora so existe o caminho seguro.
# SEGURANCA: sem eval/indirecao — recebe os elementos ja expandidos pelo
# chamador, que e o dono do array (evita manipulacao de nome de variavel).
_juntar_comando() {
    local -a _partes=("$@")

    if (( ${#_partes[@]} == 0 )); then
        return 1
    fi

    local _cmd_junto=""
    local _p
    for _p in "${_partes[@]}"; do
        _cmd_junto+="$(_proteger_arg_shell "$_p") "
    done
    printf '%s' "${_cmd_junto% }"
}

# Verifica se um zip tem indice central legivel (ou seja: nao esta truncado).
# Parametros: $1=caminho do zip
# Retorna: 0=indice ok 1=zip invalido/truncado
#
# Usa "unzip -Z1" (so o indice central) e nao "unzip -t". O proprio projeto ja
# registra o motivo em constantes.sh (C_BACKUP_TESTE_INTEGRIDADE) e em
# programas.sh: "-t" rele e descomprime o arquivo inteiro, enquanto o indice
# central e proporcional ao numero de entradas e nao aos dados. Como toda
# extracao deste sistema ja descomprime o payload, usar "-t" antes dela dobrava
# o I/O sem acrescentar deteccao util — e, em zip de biblioteca grande, acusava
# corrupcao em arquivo que a extracao abre sem problema.
#
# A saida do unzip vai para o log (antes era >/dev/null 2>&1 e o motivo da
# recusa ficava invisivel).
_zip_indice_valido() {
    local arquivo="${1:-}"

    if [[ -z "$arquivo" ]]; then
        _log_erro "Verificacao de zip sem caminho informado"
        return 1
    fi

    local _saida
    if ! _saida=$("${DEFAULT_UNZIP:-unzip}" -Z1 -- "$arquivo" 2>&1); then
        _log "AVISO: unzip -Z1 reprovou ${arquivo##*/}: ${_saida//$'\n'/ | }" "${LOG_ATU:-/dev/null}"
        return 1
    fi
    if [[ -z "${_saida//[[:space:]]/}" ]]; then
        _log "AVISO: ${arquivo##*/} tem indice central vazio (zip sem entradas)" "${LOG_ATU:-/dev/null}"
        return 1
    fi

    return 0
}

# Lista no log o que existe no diretorio de download, para diagnosticar um
# scp que "terminou ok" mas nao Entregou o que o codigo esperava.
# Parametros: $1=diretorio $2=padrao esperado
_listar_arquivos_baixados() {
    local dir="${1:-}"
    local padrao="${2:-*}"
    local _f _n=0

    while IFS= read -r -d '' _f; do
        _log "  presente: ${_f##*/}" "${LOG_ATU:-/dev/null}"
        ((_n++)) || true
    done < <(find "$dir" -maxdepth 1 -type f -name "${padrao}" -print0 2>/dev/null)

    if (( _n == 0 )); then
        # Nenhum casou com o padrao: mostrar o que tem la, para ver se o nome
        # real difere (ex: servidor gravou com outra classe ou outra versao).
        local _tot=0
        while IFS= read -r -d '' _f; do
            _log "  encontrado: ${_f##*/}" "${LOG_ATU:-/dev/null}"
            ((_tot++)) || true
        done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)
        _log "  (nenhum casou com '${padrao}'; ${_tot} arquivo(s) no diretorio)" "${LOG_ATU:-/dev/null}"
    fi
    return 0
}

#---------- FUNCOES AUXILIARES (BAIXO NIVEL) ----------#


# Download via SCP com chave SSH configurada
# Parametros: $1=arquivo_remoto $2=destino_local(opcional) $3=servidor $4=porta $5=usuario
_receber_scp() {
    local arquivo_remoto="${1:-}"
    local destino_local="${2:-.}"
    local servidor="${3:-$DEFAULT_IP_SERVER}"
    local porta="${4:-$DEFAULT_SSH_PORTA}"
    local usuario_remoto="${5:-$DEFAULT_SSH_USER}"

    [[ -z "$arquivo_remoto" ]] && {
        _log_erro "Arquivo remoto nao especificado para SCP"
        return 1
    }

    if ! _validar_caminho_seguro "$arquivo_remoto"; then
        _log_erro "Caminho remoto invalido: $arquivo_remoto"
        return 1
    fi

    if ! _validar_caminho_seguro "$destino_local"; then
        _log_erro "Destino local invalido: $destino_local"
        return 1
    fi

    if [[ ! -d "$destino_local" ]]; then
        _log_erro "Diretorio de destino nao existe: $destino_local"
        return 1
    fi

    _log "Iniciando download SCP: $arquivo_remoto"

    local -a cmd_scp=()
    if ! _montar_cmd_scp cmd_scp "$porta" "${SSH_TIMEOUT:-30}" "${SSH_ALIVE_INTERVAL:-15}" "${SSH_ALIVE_COUNT:-3}"; then
        _log_erro "Falha ao montar opcoes SCP para o download"
        return 1
    fi
    # Invariante: daqui em diante o array NUNCA esta vazio. Sem esta checagem
    # um array vazio seria expandido como comando e o bash tentaria executar a
    # propria origem remota — e, no alvo (Bash 4.0/4.1), expandir array vazio
    # sob `set -u` aborta o programa com "unbound variable".
    if (( ${#cmd_scp[@]} == 0 )); then
        _log_erro "Array de comandos SCP vazio apos _montar_cmd_scp (abortando)"
        return 1
    fi

    if ! _validar_destino_ssh "$usuario_remoto" "$servidor"; then
        _log_erro "Usuario/servidor SSH invalido: ${usuario_remoto}@${servidor}"
        return 1
    fi

    local origem="${usuario_remoto}@${servidor}:${arquivo_remoto}"

    if ! _validar_origem_remota "$origem"; then
        _log_erro "Origem remota invalida: $origem"
        return 1
    fi

    if ! "${cmd_scp[@]}" "$origem" "$destino_local"; then
        _log_erro "Falha no download SCP: $arquivo_remoto"
        return 1
    fi

    local nome_arquivo="${arquivo_remoto##*/}"
    local arquivo_destino="${destino_local%/}/${nome_arquivo}"

    if [[ ! -f "$arquivo_destino" ]]; then
        _log_erro "Arquivo nao encontrado apos SCP: $arquivo_destino"
        return 1
    fi

    if [[ ! -s "$arquivo_destino" ]]; then
        _log_erro "Arquivo recebido vazio: $arquivo_destino"
        rm -f -- "$arquivo_destino"
        return 1
    fi

    _log_sucesso "Download SCP concluido: $arquivo_remoto"
    return 0
}


# Upload via RSYNC
# Parametros: $1=arquivo_local $2=destino_remoto(caminho) $3=servidor $4=porta $5=usuario
# NOTA: $2 sobrescreve CFG_BACKUP_PATH para uso nesta chamada. Se omitido, usa CFG_BACKUP_PATH global.
_enviar_rsync() {
    local arquivo_local="${1:-}"
    local destino_remoto="${2:-${CFG_BACKUP_PATH:-}}"

    if [[ -z "$arquivo_local" || -z "$destino_remoto" ]]; then
        _log_erro "Parametros obrigatorios nao informados para upload RSYNC"
        return 1
    fi

    if [[ ! -f "$arquivo_local" ]]; then
        _log_erro "Arquivo local nao encontrado: ${arquivo_local}"
        return 1
    fi

    # SEGURANCA: Validar destino remoto contra injecao e traversal (interpretado pelo shell remoto)
    if ! _validar_caminho_seguro "$destino_remoto"; then
        _log_erro "Destino remoto invalido ou malicioso: ${destino_remoto}"
        return 1
    fi

    local servidor="${3:-$DEFAULT_IP_SERVER}"
    local porta="${4:-$DEFAULT_SSH_PORTA}"
    local usuario_remoto="${5:-$DEFAULT_SSH_USER}"
    _log "Iniciando upload RSYNC: ${arquivo_local}"

    if ! _validar_destino_ssh "$usuario_remoto" "$servidor"; then
        _log_erro "Usuario/servidor SSH invalido: ${usuario_remoto}@${servidor}"
        return 1
    fi

    local destino_completo="${usuario_remoto}@${servidor}:${destino_remoto}"

    if ! _validar_origem_remota "$destino_completo"; then
        _log_erro "Destino remoto invalido: ${destino_completo}"
        return 1
    fi

    # SEGURANCA: Construir opções de forma segura usando arrays
    # -rtzP (em vez de -a): nao preserva permissoes/dono/grupo, pois alguns mounts de clientes
    # (ex: SMB) rejeitam chmod com "Operation not permitted"
    local base_rsync=("rsync" "-rtzP")
    local -a ssh_cmd_parts=()
    if ! _montar_cmd_ssh ssh_cmd_parts "$porta"; then
        _log_erro "Falha ao montar opcoes SSH para upload RSYNC"
        return 1
    fi
    # Invariante: nunca expandir array de comando vazio (ver _receber_scp).
    if (( ${#ssh_cmd_parts[@]} == 0 )); then
        _log_erro "Array de comandos SSH vazio apos _montar_cmd_ssh (abortando)"
        return 1
    fi
    local cmd_ssh
    cmd_ssh="$(_juntar_comando "${ssh_cmd_parts[@]}")"

    # Executa o upload (única chamada)
    if "${base_rsync[@]}" -e "${cmd_ssh}" "$arquivo_local" "$destino_completo"; then
        _log_sucesso "Upload RSYNC concluido: ${arquivo_local}"
        return 0
    else
        _log_erro "Falha no upload RSYNC: ${arquivo_local}"
        return 1
    fi
}


# Upload em lote via RSYNC (uma unica conexao SSH para varios arquivos)
# Parametros: $1=destino_remoto(caminho) $2...=arquivos_locais
_enviar_rsync_lote() {
    local destino_remoto="${1:-}"
    shift
    local -a arquivos_locais=("$@")

    if [[ -z "$destino_remoto" || ${#arquivos_locais[@]} -eq 0 ]]; then
        _log_erro "Parametros obrigatorios nao informados para upload RSYNC em lote"
        return 1
    fi

    # `arquivo_local` era global (vazava para o chamador). Nomes genericos como
    # este colidem com o escopo dinamico do bash e com variaveis de outros modulos.
    local arquivo_local
    for arquivo_local in "${arquivos_locais[@]}"; do
        if [[ ! -f "$arquivo_local" ]]; then
            _log_erro "Arquivo local nao encontrado: ${arquivo_local}"
            return 1
        fi
    done

    # SEGURANCA: Validar destino remoto contra injecao e traversal (interpretado pelo shell remoto)
    if ! _validar_caminho_seguro "$destino_remoto"; then
        _log_erro "Destino remoto invalido ou malicioso: ${destino_remoto}"
        return 1
    fi

    # Item 8: mesmos fallbacks de _enviar_rsync. Sem `${:-}`, uma variavel
    # ausente aborta o programa sob `set -u` em vez de dar erro util.
    local servidor="${DEFAULT_IP_SERVER:-}"
    local porta="${DEFAULT_SSH_PORTA:-}"
    local usuario_remoto="${DEFAULT_SSH_USER:-}"
    _log "Iniciando upload RSYNC em lote: ${#arquivos_locais[@]} arquivo(s)"

    if ! _validar_destino_ssh "$usuario_remoto" "$servidor"; then
        _log_erro "Usuario/servidor SSH invalido: ${usuario_remoto}@${servidor}"
        return 1
    fi

    local destino_completo="${usuario_remoto}@${servidor}:${destino_remoto}"

    if ! _validar_origem_remota "$destino_completo"; then
        _log_erro "Destino remoto invalido: ${destino_completo}"
        return 1
    fi

    # SEGURANCA: Construir opções de forma segura usando arrays
    # -rtzP (em vez de -a): nao preserva permissoes/dono/grupo, pois alguns mounts de clientes
    # (ex: SMB) rejeitam chmod com "Operation not permitted"
    local base_rsync=("rsync" "-rtzP")
    local -a ssh_cmd_parts=()
    if ! _montar_cmd_ssh ssh_cmd_parts "$porta"; then
        _log_erro "Falha ao montar opcoes SSH para upload RSYNC"
        return 1
    fi
    # Invariante: nunca expandir array de comando vazio (ver _receber_scp).
    if (( ${#ssh_cmd_parts[@]} == 0 )); then
        _log_erro "Array de comandos SSH vazio apos _montar_cmd_ssh (abortando)"
        return 1
    fi
    local cmd_ssh
    cmd_ssh="$(_juntar_comando "${ssh_cmd_parts[@]}")"

    # Executa o upload de todos os arquivos em uma unica chamada (1 conexao SSH)
    if "${base_rsync[@]}" -e "${cmd_ssh}" "${arquivos_locais[@]}" "$destino_completo"; then
        _log_sucesso "Upload RSYNC em lote concluido: ${#arquivos_locais[@]} arquivo(s)"
        return 0
    else
        _log_erro "Falha no upload RSYNC em lote"
        return 1
    fi
}


#---------- FUNCOES DE DOWNLOAD (ALTO NIVEL) ----------#
# Download da biblioteca via SFTP/SCP (funcao principal)
_baixar_biblioteca_sincroniza() {

    local servidor="${1:-$DEFAULT_IP_SERVER}"
    local porta="${2:-$DEFAULT_SSH_PORTA}"
    local usuario_remoto="${3:-$DEFAULT_SSH_USER}"

    if ! _validar_destino_ssh "$usuario_remoto" "$servidor"; then
        _log_erro "Usuario/servidor SSH invalido: ${usuario_remoto}@${servidor}"
        return 1
    fi

    _log "Iniciando download da biblioteca: ${SAVATU:-}${VERSAO:-}"

    # SEGURANCA: Validar diretorio de recebimento
    if ! _validar_caminho_seguro "${CFG_PORTALSAV:-}"; then
        _log_erro "Erro: Diretorio de recebimento invalido."
        return 1
    fi

    # Garantir que o diretorio de recebimento exista (substitui o pushd:
    # nao ha mais mudanca de cwd, os downloads usam destino absoluto).
    if ! _criar_diretorio_seguro "${CFG_PORTALSAV:-}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _log_erro "Erro: Nao foi possivel acessar/criar diretorio: ${CFG_PORTALSAV:-}"
        return 1
    fi

    if _usar_chave_ssh; then
        # Item 7: ${VERSAO:-} silencioso montava "tempSAV….zip" sem a versao e o
        # download falhava com mensagem generica, longe da causa. Versao vazia
        # e erro de configuracao, nao um nome alternativo.
        if [[ -z "${VERSAO:-}" ]]; then
            _log_erro "VERSAO nao definida — nao e possivel montar o nome do zip da biblioteca"
            return 1
        fi
        local destino_biblioteca="${DESTINO_BIBLIOTECA:-}"
        if [[ -z "$destino_biblioteca" ]]; then
            _log_erro "DESTINO_BIBLIOTECA nao definida (verifique constantes.sh)"
            return 1
        fi
        local arquivo_biblioteca="${destino_biblioteca}${SAVATU:-}${VERSAO}.zip"

        # SEGURANCA: Validar caminho construido
        if ! _validar_caminho_seguro "$arquivo_biblioteca"; then
            _log_erro "Erro: Caminho da biblioteca invalido."
            return 1
        fi
        local -a cmd_scp_lib=()
        if ! _montar_cmd_scp cmd_scp_lib "$porta"; then
            _log_erro "Falha ao montar opcoes SCP para a biblioteca"
            return 1
        fi
        if (( ${#cmd_scp_lib[@]} == 0 )); then
            _log_erro "Array de comandos SCP vazio apos _montar_cmd_scp (abortando)"
            return 1
        fi
        local origem="${usuario_remoto}@${servidor}:${arquivo_biblioteca}"

        if ! _validar_origem_remota "$origem"; then
            _log_erro "Origem remota invalida: ${origem}"
            return 1
        fi

        if "${cmd_scp_lib[@]}" "$origem" "${CFG_PORTALSAV:-}/"; then
            # SAVATU contem um curinga POR DESIGN (ex: "tempSAV_IS2025_*_", em
            # config.sh: classX="IS${CFG_VERSAOCLASS}_*_"). O shell remoto do
            # scp expande esse padrao e baixa TODOS os arquivos que casam
            # (classA_, classB_, tel_isc_, xml_...), cada um gravado com o nome
            # REAL. Por isso nao existe — e nunca existiu — um arquivo local
            # chamado "tempSAV_IS2025_*_2109.zip": a checagem antiga por esse
            # nome literal falhava sempre, mesmo com o download completo.
            # Aqui resolve-se o padrao no destino e confere-se cada arquivo.
            local padrao_bib="${SAVATU:-}${VERSAO}.zip"
            local -a baixados=()
            local _arq_bib
            while IFS= read -r -d '' _arq_bib; do
                baixados+=("$_arq_bib")
            done < <(find "${CFG_PORTALSAV:-}" -maxdepth 1 -type f -name "${padrao_bib}" -print0 2>/dev/null)

            if (( ${#baixados[@]} == 0 )); then
                _log_erro "Nenhum arquivo '${padrao_bib}' encontrado em ${CFG_PORTALSAV:-} apos o download"
                _log_erro "Conteudo atual do diretorio:"
                _listar_arquivos_baixados "${CFG_PORTALSAV:-}" "${padrao_bib}"
                return 1
            fi

            for _arq_bib in "${baixados[@]}"; do
                if [[ ! -s "$_arq_bib" ]]; then
                    _log_erro "Arquivo recebido vazio: ${_arq_bib##*/}"
                    rm -f -- "$_arq_bib"
                    return 1
                fi
                # Integridade do zip. Usa "unzip -Z1" (indice central), NAO "-t":
                # o codigo do projeto ja documenta em constantes.sh/programas.sh
                # que "-t" rele e descomprime o arquivo INTEIRO, e por isso o
                # indice central e o padrao e o "-t" e modo profundo opt-in
                # (C_BACKUP_TESTE_INTEGRIDADE). Como a extracao em biblioteca.sh
                # ja descomprime tudo, o "-t" aqui dobrava o trabalho e ainda
                # assim acusava corrupcao em zip que a extracao abre bem.
                if ! _zip_indice_valido "$_arq_bib"; then
                    _log_erro "Arquivo corrompido ou download incompleto: ${_arq_bib##*/}"
                    rm -f -- "$_arq_bib"
                    return 1
                fi
            done

            _log_sucesso "Download da biblioteca concluido: ${#baixados[@]} arquivo(s) [${padrao_bib}]"
            return 0
        else
            _log_erro "Falha no download da biblioteca: ${SAVATU:-}${VERSAO:-}.zip"
            return 1
        fi
    else
        _definir_variaveis_biblioteca
        local arquivos_update
        read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"
        if [[ ${#arquivos_update[@]} -eq 0 ]]; then
            _erro "Nenhum arquivo de atualizacao encontrado"
            return 1
        fi
        # Montar origens remotas em uma unica conexao SCP (lote)
        # Cada origem deve ser um argumento separado "user@host:caminho"
        # (concatenar tudo em um unico token quebra o SCP moderno/SFTP:
        #  "protocol error: filename does not match request")
        # Itens 3 e 7: `arquivo` e `destino_bib` sao locais (evitam vazar para
        # o chamador), e `destino_bib` recebe o padrao de constantes.sh — sem
        # `${:-}` a expansao aborta o programa sob `set -u` se faltar.
        local destino_bib="${DESTINO_BIBLIOTECA:-}"
        local arquivo
        local -a origens=()
        for arquivo in "${arquivos_update[@]}"; do
            # SEGURANCA: Validar cada nome de arquivo antes do uso
            if ! _validar_caminho_seguro "$arquivo"; then
                _log_erro "Erro: Nome de arquivo de atualizacao invalido ou malicioso: ${arquivo}"
                return 1
            fi
            if ! _validar_caminho_seguro "${destino_bib}${arquivo}"; then
                _log_erro "Erro: Caminho de atualizacao invalido ou malicioso: ${destino_bib}${arquivo}"
                return 1
            fi
            origens+=("${usuario_remoto}@${servidor}:${destino_bib}${arquivo}")
        done

        local -a cmd_scp=()
        if ! _montar_cmd_scp cmd_scp "$porta"; then
            _log_erro "Falha ao montar opcoes SCP para o download em lote"
            return 1
        fi
        if (( ${#cmd_scp[@]} == 0 )); then
            _log_erro "Array de comandos SCP vazio apos _montar_cmd_scp (abortando)"
            return 1
        fi

        local origem
        for origem in "${origens[@]}"; do
            if ! _validar_origem_remota "$origem"; then
                _log_erro "Origem remota invalida: ${origem}"
                return 1
            fi
        done

        if "${cmd_scp[@]}" "${origens[@]}" "${CFG_PORTALSAV:-}/"; then
            local arquivo_baixado destino_baixado
            for arquivo_baixado in "${arquivos_update[@]}"; do
                destino_baixado="${CFG_PORTALSAV:-}/${arquivo_baixado##*/}"
                if [[ ! -f "$destino_baixado" ]]; then
                    _log_erro "Arquivo nao encontrado apos download: ${arquivo_baixado}"
                    return 1
                fi
                if [[ ! -s "$destino_baixado" ]]; then
                    _log_erro "Arquivo recebido vazio: ${arquivo_baixado}"
                    rm -f -- "$destino_baixado"
                    return 1
                fi
                # Mesmo criterio do download com chave: indice central, nao -t.
                if ! _zip_indice_valido "$destino_baixado"; then
                    _log_erro "Arquivo corrompido ou download incompleto: ${arquivo_baixado}"
                    rm -f -- "$destino_baixado"
                    return 1
                fi
            done
            _log_sucesso "Download em lote concluido: ${#arquivos_update[@]} arquivo(s)"
            return 0
        else
            _log_erro "Falha no download em lote dos arquivos de atualizacao"
            return 1
        fi
    fi
}

# Baixar programas via SFTP/SCP (download em lote: 1 conexao SCP para N arquivos)
_baixar_programas_vaievem() {
    local caminho="${1:-${CFG_PORTALSAV}}"

    # SEGURANCA: validar o diretorio de recebimento ANTES de cria-lo/usar
    if ! _validar_caminho_seguro "${caminho:-}"; then
        _erro "Diretorio de recebimento invalido: ${caminho}"
        return 1
    fi

    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }

    # Guard set -u: vaievem.sh e carregado antes de programas.sh (onde o array
    # e declarado). Em runtime o array ja existe, mas o guard protege chamadas
    # fora do bootstrap completo (ex: testes isolados de modulo).
    if [[ -z "${ARQUIVOS_PROGRAMA+x}" ]]; then
        return 0
    fi

    if (( ${#ARQUIVOS_PROGRAMA[@]} == 0 )); then
        return 0
    fi

    _linha
    _exibir_mensagem_centralizada "${AMARELO}" "Realizando sincronizacao dos arquivos..."

    local servidor="${DEFAULT_IP_SERVER}"
    local porta="${DEFAULT_SSH_PORTA}"
    local usuario_remoto="${DEFAULT_SSH_USER}"

    if ! _validar_destino_ssh "$usuario_remoto" "$servidor"; then
        _log_erro "Usuario/servidor SSH invalido: ${usuario_remoto}@${servidor}"
        return 1
    fi

    # Montar origens remotas em uma unica conexao SCP (lote)
    # Itens 3 e 7: `arquivo` e `destino_prog` locais; `destino_prog` com padrao
    # de constantes.sh (sem `${:-}` a expansao aborta sob `set -u`).
    local destino_prog="${DESTINO_SERVER:-}"
    local arquivo
    local -a origens=()
    local -a nomes_arquivos=()
    for arquivo in "${ARQUIVOS_PROGRAMA[@]}"; do
        # SEGURANCA: Validar cada nome antes do uso
        if ! _validar_caminho_seguro "$arquivo"; then
            _log_erro "Nome de arquivo de atualizacao invalido ou malicioso: ${arquivo}"
            return 1
        fi
        if ! _validar_caminho_seguro "${destino_prog}${arquivo}"; then
            _log_erro "Caminho de atualizacao invalido ou malicioso: ${destino_prog}${arquivo}"
            return 1
        fi
        _linha
        _exibir_mensagem_centralizada "${VERDE}" "Transferindo: $arquivo"
        origens+=("${usuario_remoto}@${servidor}:${destino_prog}${arquivo}")
        nomes_arquivos+=("$arquivo")
    done

    local origem_prog
    for origem_prog in "${origens[@]}"; do
        if ! _validar_origem_remota "$origem_prog"; then
            _log_erro "Origem remota invalida: ${origem_prog}"
            return 1
        fi
    done

    local -a cmd_scp=()
    if ! _montar_cmd_scp cmd_scp "$porta"; then
        _log_erro "Falha ao montar opcoes SCP para o download dos programas"
        return 1
    fi
    if (( ${#cmd_scp[@]} == 0 )); then
        _log_erro "Array de comandos SCP vazio apos _montar_cmd_scp (abortando)"
        return 1
    fi

    if ! "${cmd_scp[@]}" "${origens[@]}" "${caminho}/"; then
        _log_erro "Falha no download em lote dos programas"
        return 1
    fi

    # Integridade de cada zip recebido (existe no destino absoluto ${caminho}/)
    # Item 4: usar o BASENAME, como ja fazia _baixar_biblioteca_sincroniza. O
    # scp grava em "${caminho}/" com o basename; com o caminho completo, um
    # nome contendo "/" (permitido por _validar_caminho_seguro) apontaria para
    # um arquivo que nunca existiu e a checagem falharia com falso negativo.
    local arquivo_destino
    for arquivo in "${nomes_arquivos[@]}"; do
        arquivo_destino="${caminho%/}/${arquivo##*/}"
        if [[ ! -f "$arquivo_destino" ]]; then
            _log_erro "Arquivo nao encontrado apos download: $arquivo"
            return 1
        fi
        if [[ ! -s "$arquivo_destino" ]]; then
            _log_erro "Arquivo recebido vazio: $arquivo"
            # SEGURANCA: Usar '--' para prevenir injeção de opções no rm
            rm -f -- "$arquivo_destino"
            _aguardar 2
            return 1
        fi
        _linha
        # Mesmo criterio dos demais downloads: indice central. Este teste com
        # "-t" era pre-existente aqui, mas dobrava a descompressao do payload
        # (que a extracao em programas.sh faz logo em seguida) e nao logava o
        # motivo da recusa. Agora registra em LOG_ATU.
        if ! _zip_indice_valido "$arquivo_destino"; then
            _erro "Arquivo corrompido: $arquivo"
            # SEGURANCA: Usar '--' para prevenir injeção de opções no rm
            rm -f -- "$arquivo_destino"
            _aguardar 2
            return 1
        fi
        _exibir_mensagem_centralizada "${VERDE}" "Download concluido: $arquivo"
    done

    return 0
}

#---------- FUNCOES DE UPLOAD/ENVIO (ALTO NIVEL) ----------#

# Enviar arquivo(s) via RSYNC. Pode lidar com arquivos unicos ou multiplos usando wildcard.
# Uso: _enviar_arquivo_multi <diretorio_origem> <arquivo|padrao> [destino_remoto]
_enviar_arquivo_multi() {
    local diretorio_origem="${1:-}"
    local arquivo_enviar="${2:-}"
    local destino_remoto="${3:-${CFG_BACKUP_PATH:-}}"

    if [[ -z "$arquivo_enviar" ]]; then
        _erro "Nenhum arquivo especificado para envio"
        _aguardar 2
        return 1
    fi

    if [[ -z "$destino_remoto" ]]; then
        _erro "Destino remoto nao especificado"
        _aguardar 2
        return 1
    fi

    # Validar diretorio de origem para envio de arquivo unico
    if [[ "$arquivo_enviar" != *"*"* && -z "$diretorio_origem" ]]; then
        _erro "Diretorio de origem nao definido para envio de arquivo unico"
        _aguardar 2
        return 1
    fi

    # SEGURANCA: Validar caminhos contra traversal e injeção
    if ! _validar_caminho_seguro "${diretorio_origem:-.}" || ! _validar_caminho_seguro "${destino_remoto}"; then
        _erro "Caminhos contem caracteres invalidos ou tentativas de traversal."
        _aguardar 2
        return 1
    fi

    # Verificar se esta enviando multiplos arquivos ou apenas um
    if [[ "$arquivo_enviar" == *"*"* ]]; then
        # Item 13: o nome/curinga tambem passa por _validar_caminho_seguro. O
        # caminho de arquivo unico (abaixo) ja validava; o de curinga nao, e o
        # nome ia direto para o `find -name`. Hoje o caller em arquivos.sh
        # tambem valida, mas a funcao nao deve depender disso.
        if ! _validar_caminho_seguro "$arquivo_enviar"; then
            _erro "Padrao de arquivo invalido ou malicioso: ${arquivo_enviar}"
            _aguardar 2
            return 1
        fi
        # Localizar arquivos que correspondem ao padrao
        local -a arquivos_encontrados=()
        local arquivo_item
        while IFS= read -r -d '' arquivo_item; do
            arquivos_encontrados+=("$arquivo_item")
        done < <(find "${diretorio_origem:-.}" -maxdepth 1 -type f -name "${arquivo_enviar}" -print0 2>/dev/null)

        if (( ${#arquivos_encontrados[@]} == 0 )); then
            _erro "Nenhum arquivo encontrado para envio multiplo"
            _aguardar 2
            return 1
        fi

        # Enviar multiplos arquivos em uma unica conexao SSH (lote)
        if _enviar_rsync_lote "${destino_remoto}" "${arquivos_encontrados[@]}"; then
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo(s) enviado(s) para \"${destino_remoto}\""
            _linha
            _aguardar 3
            return 0
        fi
    else
        # Enviar arquivo unico usando _enviar_rsync
        local caminho_envio="${diretorio_origem}/${arquivo_enviar}"
        if ! _validar_caminho_seguro "$caminho_envio"; then
            _erro "Caminho local invalido ou malicioso: ${caminho_envio}"
            _aguardar 2
            return 1
        fi
        if _enviar_rsync "$caminho_envio" "${destino_remoto}"; then
            _exibir_mensagem_centralizada "${AMARELO}" "Arquivo enviado para \"${destino_remoto}\""
            _linha
            _aguardar 3
            return 0
        fi
    fi

    # Fluxo de erro comum (unico e multiplo)
    _erro "Falha no envio de arquivo(s)"
    _aguardar_tecla
    return 1
}
