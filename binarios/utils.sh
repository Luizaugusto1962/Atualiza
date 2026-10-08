#!/usr/bin/env bash
set -euo pipefail
#
# utils.sh - Modulo de Utilitarios e Funcoes Auxiliares
# Funcoes basicas para formatacao, mensagens, validacao e controle de fluxo
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 08/10/2026-02
#
# =============================================================================
# Definição de variáveis globais
# =============================================================================
RAIZ="${RAIZ:-}"                                # Diretorio RAIZ do sistema.

# ===== CONFIGURACAO DE TERMINAL =====
# Exportar variáveis de terminal para subshells e garantir atualizações automáticas
export LINES COLUMNS
shopt -s checkwinsize 2>/dev/null || true  # Bash 4+: atualizar LINES/COLUMNS automaticamente

# Valor padrão para largura do terminal (fallback final)
DEFAULT_COLUMNS="${DEFAULT_COLUMNS:-80}"
DEFAULT_LINES="${DEFAULT_LINES:-24}"

# Inicializar COLUMNS na primeira execução se em terminal interativo
if [[ -t 1 || -t 0 ]]; then
    # Se COLUMNS não está definido, tentar obter do terminal
    if [[ -z "${COLUMNS:-}" ]] && command -v stty >/dev/null 2>&1; then
        _stty_size=$(stty size 2>/dev/null)
        # "24 80" -> LINES=24 COLUMNS=80 por split do bash (evita 2 forks de awk)
        LINES=${_stty_size%% *}
        COLUMNS=${_stty_size##* }
        export COLUMNS LINES
    fi
fi

# Garantir que COLUMNS/LINES tenham um valor válido NUMERICO.
# Este é o invariante que permite ler ${COLUMNS} direto (sem fork) em todas as
# funções de exibição abaixo. Sem o teste numérico, um COLUMNS herdado do
# ambiente (ex.: "abc") faria printf "%*s" falhar; com ele, o fallback é o mesmo
# DEFAULT_COLUMNS que _obter_colunas usava.
COLUMNS="${COLUMNS:-$DEFAULT_COLUMNS}"
[[ "$COLUMNS" =~ ^[0-9]+$ && "$COLUMNS" -gt 0 ]] || COLUMNS="$DEFAULT_COLUMNS"
LINES="${LINES:-$DEFAULT_LINES}"
[[ "$LINES" =~ ^[0-9]+$ && "$LINES" -gt 0 ]] || LINES="$DEFAULT_LINES"
export COLUMNS LINES

# =============================================================================
# Funcoes de Utilitarios Basicos
# =============================================================================
# Largura do terminal: leia ${COLUMNS} direto.
#
# As funcoes de exibicao deste modulo NAO usam mais um helper tipo
# `_obter_colunas`: aquele exigia `colunas=$(_obter_colunas)`, e cada `$()` e um
# fork de subshell (~3,5 ms) executado uma vez por linha exibida. Com
# `checkwinsize` ligado (linha 19) e o invariante numerico garantido no topo
# deste arquivo, ${COLUMNS} ja e a largura correta — ler a variavel e o custo
# zero. Nao reintroduza o helper.

# Configuracao de alertas
# Helper comum: aplica formato printf (%s/%d) quando ha argumentos extras e
# o formato usa placeholders conhecidos; senao imprime literal (evita % literais
# mal-interpretados). Strip de \n final evita linha em branco dupla.
_formatar_e_exibir() {
    local cor="${1:-}" prefixo="${2:-}" fmt="${3:-}"; shift 3
    local saida
    if (( $# > 0 )) && [[ "$fmt" =~ %[sd] ]]; then
        # shellcheck disable=SC2059  # fmt e prefixo sao formatos/ literais controlados internamente
        saida="$(printf "${prefixo}${fmt}" "$@" 2>/dev/null)" || saida="${prefixo}${fmt}"
    else
        saida="${prefixo}${fmt}"
    fi
    saida="${saida%$'\n'}"
    _exibir_mensagem_centralizada "${cor}" "${saida}"
}
    _msg()   { _formatar_e_exibir "${BRANCO}"  "[INFORMATIVO] > "  "$@"; }
    _ok()    { _formatar_e_exibir "${VERDE}"   "[OK] > "           "$@"; }
    _aviso() { _formatar_e_exibir "${AMARELO}" "[AVISO] > "        "$@"; }
    _erro()  { _formatar_e_exibir "${VERMELHO}" "[ERRO] > "        "$@"; }

# Remove espacos em branco do inicio e fim de uma string
# Parametros: $1=string
# Retorna: string sem espacos nas extremidades
_trim() {
    local var="${1:-}"
    # Remove espacos do inicio
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove espacos do fim
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Converte string para maiuscula
# Parametros: $1=string
# Retorna: string em maiuscula
_upper() {
    printf '%s' "${1^^}"
}

# Atualiza as variaveis LINES e COLUMNS baseado no terminal atual
# Chame esta funcao se o terminal for redimensionado (ex: dentro de _meio_da_tela)
_atualizar_tamanho_terminal() {
    if [[ -t 1 ]] && command -v stty >/dev/null 2>&1; then
        local tamanho
        tamanho=$(stty size 2>/dev/null)
        if [[ -n "$tamanho" ]]; then
            # "24 80" -> LINES=24 COLUMNS=80 por split do bash.
            # Media de 2 forks de awk por chamada; _meio_da_tela roda isso a cada
            # iteracao do loop de selecao de programas.
            LINES=${tamanho%% *}
            COLUMNS=${tamanho##* }
            export LINES COLUMNS
        fi
    fi
}
# Posiciona o cursor no meio da tela
_meio_da_tela() {
    _atualizar_tamanho_terminal  # Atualizar tamanho antes de usar
    tput clear 2>/dev/null || true
    tput cup $(( LINES / 2 )) 0 2>/dev/null || true
}

# Exibe mensagem centralizada alinhada a esquerda com cor
# Parametros: $1=cor $2=mensagem
_exibir_mensagem_centralizada_a_esquerda() {
    local cor="${1:-}"
    local mensagem="${2:-}"
    local largura_bloco="${3:-30}" # Largura do bloco (padrao 30)
    local colunas
    local margem_esquerda

    # Obter largura do terminal
    colunas="$COLUMNS"

    # Calcular a margem para centralizar o BLOCO inteiro na tela
    if [[ "$colunas" -le "$largura_bloco" ]]; then
        margem_esquerda=0
    else
        margem_esquerda=$(( (colunas - largura_bloco) / 2 ))
    fi

    printf "%*s%s%-*s%s\n" \
        "$margem_esquerda" "" \
        "${cor}" \
        "$largura_bloco" "${mensagem}" \
        "${NORMAL}"
}

# Exibe mensagem centralizada com cor
_exibir_mensagem_centralizada() {
    local cor="${1:-}"
    local mensagem="${2:-}"
    local colunas

    colunas="$COLUMNS"
    local tamanho_mensagem=${#mensagem}

    if [[ "$colunas" -lt "$tamanho_mensagem" ]]; then
        # Terminal muito estreito — exibir sem centralizar
        printf "%s%s%s\n" "${cor}" "${mensagem}" "${NORMAL}"
    else
        # Calcula margem esquerda para centralizar
        local margem=$(( (colunas - tamanho_mensagem) / 2 ))
        printf "%s%*s%s%s\n" "${cor}" "$margem" "" "${mensagem}" "${NORMAL}"
    fi
}

# Exibe mensagem alinhada à direita
# Parametros: $1=cor $2=mensagem
_exibir_mensagem_direita() {
    local cor="${1:-}"
    local mensagem="${2:-}"
    local largura_terminal largura_mensagem posicao_inicio

    # Obter largura do terminal com fallback seguro
    largura_terminal="$COLUMNS"

    largura_mensagem=${#mensagem}
    posicao_inicio=$((largura_terminal - largura_mensagem))

    # Garante posição mínima não negativa
    if [[ "$posicao_inicio" -lt 0 ]]; then
        posicao_inicio=0
    fi

    printf "%s%*s%s%s\n" "${cor}" "${posicao_inicio}" "" "$mensagem" "${NORMAL}"
}

_exibir_mensagem_corrida() {
    local cor="${1:-}"
    local mensagem="${2:-}"
    local largura_terminal largura_mensagem posicao_inicio
    local i

    # Obter largura do terminal com fallback seguro
    largura_terminal="$COLUMNS"

    largura_mensagem=${#mensagem}
    posicao_inicio=$(( (largura_terminal - largura_mensagem) / 2 ))

    # Garante posição mínima não negativa
    if [[ "$posicao_inicio" -lt 0 ]]; then
        posicao_inicio=0
    fi
# Imprimir espaços iniciais para centralizar
    printf "%*s" "${posicao_inicio}" ""

    # Loop para imprimir cada letra com efeito de digitação
    for ((i=0; i<${#mensagem}; i++)); do
        printf "%s%s%s" "${cor}" "${mensagem:$i:1}" "${NORMAL}"
        sleep 0.05
    done
    printf "\n"
}

# Cria linha horizontal com caractere especificado
# Parametros: $1=caractere (opcional, padrao='-') $2=cor (opcional)
_linha() {
    local traco="${1:--}"
    local cor="${2:-}"
    local colunas

    colunas="$COLUMNS"

    if [[ "$colunas" -lt 10 ]]; then
        colunas=10
    fi

    local espacos
    printf -v espacos "%${colunas}s" ''
    printf "%s%s%s\n" "${cor}" "${espacos// /$traco}" "${NORMAL}"
}


# Cria meia linha horizontal com caractere especificado
# Parametros: $1=caractere (opcional, padrao='-') $2=cor (opcional)
# Exibe linha horizontal centralizada com largura delimitada
# Parametros:
#   $1 = caractere (opcional, padrao='-')
#   $2 = cor (opcional)
#   $3 = largura em caracteres (opcional, padrao=40)
_meia_linha() {
    local traco="${1:--}"
    local cor="${2:-}"
    local largura="${3:-50}"
    local espacos linhas colunas

    colunas="$COLUMNS"

    printf -v espacos "%${largura}s" ""
    linhas=${espacos// /$traco}
    printf "%s" "${cor}"
    printf "%*s\n" $(((colunas + largura) / 2)) "$linhas"
    printf "%s" "${NORMAL}"
}


#---------- FUNcoES DE CONTROLE DE FLUXO ----------#

# Pausa a execucao por tempo especificado
# Parametros: $1=tempo_em_segundos
_aguardar() {
    local tempo="${1:-}"

    if [[ -z "$tempo" ]]; then
        _erro "Nenhum argumento passado para _aguardar." >&2
        return 1
    fi

    if ! [[ "$tempo" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        _erro "Argumento inválido para _aguardar: %s\n" "$tempo" >&2
        return 1
    fi

    # Bash 4.0/4.1: read -t so aceita inteiros — timeout fracionario falha
    # silenciosamente. Truncar para inteiro nesses casos (pausa aproximada).
    if [[ "$tempo" == *.* ]] && (( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2 )); then
        tempo="${tempo%%.*}"
        [[ -z "$tempo" || "$tempo" == "0" ]] && tempo=1
    fi

    read -rt "$tempo" <> <(:) || :
}


# Aguarda pressionar qualquer tecla com tempo_limite
_aguardar_tecla() {
    local mensagem="${1:-... Pressione qualquer tecla para continuar ...}"
    local tempo_limite="${2:-${DEFAULT_PRESS_TIMEOUT:-12}}"
    local colunas

    colunas="$COLUMNS"

    # Centralizar pela largura real da mensagem (antes usava 36 fixo)
    local msg_completa="<< $mensagem >>"
    # %*s preenche ate a largura dada: com margem=(colunas+len)/2 o preenchimento
    # liquido e (colunas-len)/2 espacos — centralizacao correta via largura do campo.
    local margem=$(( (colunas + ${#msg_completa}) / 2 ))
    if (( margem < 0 )); then margem=0; fi

    printf "%s" "${CIANO}"
    printf "%*s\n" "$margem" "$msg_completa"
    printf "%s" "${NORMAL}"
    read -rt "$tempo_limite" || :
    tput sgr0 2>/dev/null || true
}

#---------- ALIASES PARA COMPATIBILIDADE ----------#
# Manter compatibilidade com código existente durante transição
_opinvalida() {
    _linha "-" "${AMARELO:-}"
    # "Opcao Invalida" tem 14 caracteres (antes usava 18, deslocava 2 col)
    local espacos=$(( (COLUMNS - 14) / 2 ))
    if (( espacos < 0 )); then espacos=0; fi
    printf "%*s%s\n" "$espacos" "" "${VERMELHO}Opcao Invalida${NORMAL}"
    _linha "-" "${AMARELO:-}"
}

#---------- FUNCOES DE VALIDACAO ----------#

# Valida nome de programa (letras maiusculas, numeros e underscore)
# Parametros: $1=nome_programa
# Retorna: 0=valido 1=invalido
#
# NAO confundir com a validacao de nome de ARQUIVO DE DADOS em arquivos.sh
# (_recuperar_arquivo_individual, `^[A-Z0-9_-]+$`): nome de programa vira nome
# de classe/tela e nao aceita hifen, enquanto o arquivo de dados aceita. Sao
# dominios diferentes de proposito; o que importa e que ambos sejam estritos.
# Teto de 64: nome de programa IsCOBOL nao passa disso, e sem o teto um input
# gigante atravessaria a regex e viraria nome de arquivo absurdo.
_validar_nome_programa() {
    local programa="${1:-}"

    if [[ -z "$programa" || ${#programa} -gt 64 ]]; then
        return 1
    fi

    [[ "$programa" =~ ^[A-Z0-9_]+$ ]]
}

# Valida a flag de modo offline (CFG_OFFLINE, vinda de "Offline" no .config)
# Retorna: 0=valor valido ('s' ou 'n') 1=ausente ou invalido
#
# Motivo de existir: cada modulo testava essa flag por conta propria e cada um
# errava de um jeito. Com `if [[ "$CFG_OFFLINE" =~ ^[sn]$ ]]` e valor invalido
# (vazio, "S", lixo), o bloco inteiro era pulado em silencio — em
# biblioteca.sh:_atualizar_biblioteca_offline a funcao caia no fim e devolvia 0
# sem ter feito nada, e em _atualizar_transpc e programas.sh:_atualizar_programa_pacote
# o "else" cairia na descarga pela REDE. Agora o chamador decide o que fazer
# com o valor invalido (em geral: _erro + return 1).
_offline_valido() {
    [[ "${CFG_OFFLINE:-}" =~ ^[sn]$ ]]
}

# Mensagem de erro padronizada para CFG_OFFLINE invalido
# Parametros: $1=contexto (rotulo do fluxo, ex.: "atualizacao de biblioteca")
_offline_erro() {
    _erro "Valor invalido em 'offline': '${CFG_OFFLINE:-vazio}' (esperado 's' ou 'n')${1:+ - $1}"
}

# SEGURANCA: valida as entradas de um pacote (.zip ou .tar.gz) contra path
# traversal e caminho absoluto, ANTES de extrair.
# Uso: _validar_backup_entradas_seguras <arquivo>
# Retorna: 0=entradas seguras 1=entrada insegura ou arquivo ilegivel
#
# Sem esta checagem, um pacote com "../" ou "/etc/passwd" escapa do diretorio de
# extracao: em programas.sh o unzip roda dentro de dir_temp_atualizacao e um
# caminho absoluto no ZIP sobrescreve o proprio destino.
#
# Vive em utils.sh (e nao em backup.sh) porque quem precisa dela sao backup.sh,
# biblioteca.sh e programas.sh: como funcao so e resolvida em runtime, mas a
# regra de dependencia da MODULOS_CARREGAR exige apontar PARA FRENTE — utils.sh
# carrega antes dos tres, enquanto backup.sh carregaria depois de programas.sh.
_validar_backup_entradas_seguras() {
    local arquivo_backup="${1:-}"
    local lista_entradas=""

    if [[ -z "$arquivo_backup" || ! -r "$arquivo_backup" ]]; then
        return 1
    fi

    if [[ "$arquivo_backup" == *.tar.gz ]]; then
        lista_entradas=$("${DEFAULT_TAR:-tar}" -tzf "$arquivo_backup" 2>/dev/null) || return 1
    else
        # unzip -Z1 (modo zipinfo) lista os nomes sem extrair nada.
        lista_entradas=$("${DEFAULT_UNZIP:-unzip}" -Z1 "$arquivo_backup" 2>/dev/null) || return 1
    fi

    if grep -qE '(^|/)\.\.(/|$)|^/|^[A-Za-z]:[\\/]' <<<"$lista_entradas"; then
        _erro "Pacote contem entradas inseguras (path traversal ou caminho absoluto): ${arquivo_backup}"
        return 1
    fi
    return 0
}

# Compatibilidade: alias para chamadas existentes que usam o nome antigo
_validar_zip_entradas_seguras() {
    _validar_backup_entradas_seguras "$@"
}

# Solicita confirmacao S/N
# Parametros: $1=mensagem $2=padrao(S/N)
# Retorna: 0=sim 1=nao
_confirmar() {
    local mensagem="${1:-}"
    local padrao="${2:-N}"
    local opcoes
    local resposta
    local tentativas=0
    local max_tentativas=3
    local tempo_limite="${DEFAULT_READ_TIMEOUT:-60}"

    case "$padrao" in
        [Ss]) opcoes="[S/n]" ;;
        [Nn]) opcoes="[N/s]" ;;
        *) opcoes="[S/N]" ;;
    esac

    while (( tentativas < max_tentativas )); do
        if ! read -r -t "${tempo_limite}" -p "${AMARELO}${mensagem} ${opcoes}: ${NORMAL}" resposta; then
            # Timeout ou erro de leitura — usar padrao
            _exibir_mensagem_centralizada "${AMARELO}" "Entrada expirada. Usando padrao: ${padrao}"
            resposta="$padrao"
        fi

        # Se resposta vazia, usar padrao
        if [[ -z "$resposta" ]]; then
            resposta="$padrao"
        fi

        case "${resposta,,}" in
            s|sim) return 0 ;;
            n|nao) return 1 ;;
            *)
                _linha "-" "${VERMELHO}"
                _erro "Resposta invalida. Use S ou N."
                _linha "-" "${VERMELHO}"
                ((tentativas++)) || true
                ;;
        esac
    done

    _erro "Maximo de tentativas excedido. Usando padrao: ${padrao}"
    case "${padrao,,}" in
        s|sim) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# FUNCOES DE PROGRESSO
# =============================================================================
# Formata tempo decorrido em segundos para exibicao
# Parametros: $1=decorrido seconds
# Resultado: _TEMPO_FORMATADO = string formatada (ex: "2m 30s" ou "45s")
#
# ATENCAO: grava em _TEMPO_FORMATADO em vez de imprimir. Era `printf '%s'` e os
# callers faziam `$(_formatar_tempo ...)` — um fork de subshell por chamada, e
# _mostrar_progresso_backup chama isto uma vez por SEGUNDO de cada etapa com
# barra (tar, gzip, unzip...). Nao reintroduza a captura por $( ).
_TEMPO_FORMATADO=""
_formatar_tempo() {
    local decorrido="${1:-}"
    local min=$(( decorrido / 60 ))
    local seg=$(( decorrido % 60 ))
    local tempo_str=""
    if (( min > 0 )); then tempo_str="${min}m "; fi
    tempo_str+="${seg}s"
    _TEMPO_FORMATADO="$tempo_str"
}

# Exibe barra de progresso visual enquanto processo esta em andamento
# Parametros:
#   $1 = PID do processo em background
#   $2 = mensagem opcional (padrao: "Processando")
# Retorna: codigo de saida do processo
_mostrar_progresso_backup() {
    local pid="${1:-}"
    local msg="${2:-Processando}"
    local decorrido=0
    local anim_pos=0
    local texto_base="Aguarde..."
    local texto_len=${#texto_base}
    local barra=""
    local barra_format=""
    local status_processo=0

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        _aviso "PID nao informado ou processo ja terminado"
        # Processo terminou antes do inicio da barra: recolher o status real
        # via wait em vez de descartar a falha (rc=0 falso-positivo).
        local _status_antigo=0
        if [[ -n "$pid" ]]; then
            wait "$pid" 2>/dev/null && _status_antigo=0 || _status_antigo=$?
        fi
        return "$_status_antigo"
    fi

    # Ocultar cursor se suportado
    printf "\033[?25l" 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        decorrido=$((decorrido + 1))

        # Animacao: mostrar letras do texto base progressivamente e preencher com pontos
        anim_pos=$(( (decorrido - 1) % texto_len ))
        barra="${texto_base:0:anim_pos + 1}"
        local dots_needed=$((texto_len - ${#barra}))
        printf -v barra_format "%s%${dots_needed}s" "$barra" ""
        barra="${barra_format// /.}"

        # Formatar campos com tamanho fixo para que \r sobrescreva corretamente
        local msg_format tempo_format
        printf -v msg_format "%-25s" "$msg"
        _formatar_tempo "$decorrido"
        printf -v tempo_format "%8s" "$_TEMPO_FORMATADO"

        printf "\r\033[K%s[INFORMATIVO]%s %s |%s| %s" \
            "${CIANO}" "${NORMAL}" "${msg_format}" "${VERDE}${barra}${NORMAL}" "${AMARELO}${tempo_format}"

        sleep 1
    done

    # Coletar status de saida
    barra=" Concluido "
    wait "$pid" 2>/dev/null && status_processo=0 || status_processo=$?

    # Restaurar cursor
    printf "\033[?25h" 2>/dev/null || true

    # Formatar e exibir resultado final
    local msg_format tempo_format
    printf -v msg_format "%-25s" "$msg"
    _formatar_tempo "$decorrido"
    printf -v tempo_format "%8s" "$_TEMPO_FORMATADO"

    if (( status_processo == 0 )); then
        printf "\r\033[K%s[OK]%s %s |%s| %s concluido\n" \
            "${VERDE}" "${NORMAL}" "${msg_format}" "${VERDE}${barra}${NORMAL}" "${AMARELO}${tempo_format}"
    else
        barra=" Falhou "
        printf "\r\033[K%s[ERRO]%s %s |%s| %s falhou (codigo %s)\n" \
            "${VERMELHO}" "${NORMAL}" "${msg_format}" "${VERMELHO}${barra}${NORMAL}" "${AMARELO}${tempo_format}" "${status_processo}"
    fi

    return $status_processo
}

#---------- FUNCOES DE LOG ----------#

# Registra mensagem no log com timestamp
# Parametros: $1=mensagem $2=arquivo_log(opcional)
_log() {
    local mensagem="${1:-}"
    local arquivo_log="${2:-$LOG_ATU}"
    local timestamp usuario_log

    # Validação do arquivo de log
    if [[ -z "$arquivo_log" ]]; then
        # Fallback no $TMPDIR do usuario, nao em /var/log: o SAV roda como
        # usuario comum e /var/log/sav.log seria inacessivel, fazendo cada
        # chamada a _log falhar e emitir _erro em stderr. Se nem o TMPDIR
        # servir, /dev/null e sempre valido.
        arquivo_log="${TMPDIR:-/tmp}/sav.log"
        if [[ ! -d "${arquivo_log%/*}" || ! -w "${arquivo_log%/*}" ]]; then
            printf '%s\n' "$mensagem" >> /dev/null
            return 0
        fi
    fi

    # Caminho sem barra (ex: "sav.log"): log_dir seria o proprio nome —
    # validar como erro de caminho, nao de diretorio inexistente.
    if [[ "$arquivo_log" != */* ]]; then
        _erro "Caminho de log invalido (sem diretorio): %s\n" "$arquivo_log" >&2
        return 1
    fi

    # Cache da validação do diretório (evita fork de dirname + testes a cada linha)
    local log_dir="${arquivo_log%/*}"
    if [[ "${_LOG_DIR_CACHE:-}" != "$log_dir" ]]; then
        # Verifica se o diretório do log existe e é gravável
        if [[ ! -d "$log_dir" ]]; then
            _erro "Diretorio de log nao existe: %s\n" "$log_dir" >&2
            return 1
        fi

        if [[ ! -w "$log_dir" ]]; then
            _aviso "Sem permissao de escrita no diretorio de log: $log_dir"
            return 1
        fi
        _LOG_DIR_CACHE="$log_dir"
    fi

    # Timestamp sem fork em Bash 4.2+; fallback para date em 4.0/4.1
    if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )); then
        printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    else
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    usuario_log="${usuario:-SISTEMA}"

    if printf "[%s] [%s] %s\n" "$timestamp" "$usuario_log" "$mensagem" >> "$arquivo_log"; then
        return 0
    else
        _erro "Falha ao escrever no log: %s\n" "$arquivo_log" >&2
        return 1
    fi
}

# Registra erro no log
# Parametros: $1=mensagem_erro $2=arquivo_log(opcional)
_log_erro() {
    local erro="${1:-}"
    local arquivo_log="${2:-$LOG_ATU}"

    _log "ERRO: $erro" "$arquivo_log" || true
}

# Registra sucesso no log
# Parametros: $1=mensagem_sucesso $2=arquivo_log(opcional)
_log_sucesso() {
    local sucesso="${1:-}"
    local arquivo_log="${2:-$LOG_ATU}"

    _log "SUCESSO: $sucesso" "$arquivo_log" || true
}

# Executa um comando obrigatoriamente tolerante a falha, REGISTRANDO o erro.
# Parametros: $1=rotulo para o log $2=arquivo_log $3..=comando + argumentos
# Retorna: sempre 0
#
# Por que este helper existe:
#   O Bash suspende o `errexit` (`set -e`) por TODO o escopo dinamico de um
#   comando usado em lista `||` ou como condicao de `if !`. Logo tanto
#   `cmd || true` quanto `if ! cmd; then ...; fi` desabilitam o set -e DENTRO
#   da funcao chamada — nao existe forma de manter o errexit ativo nesse caso.
#   Consequencia pratica: um `|| true` no chamador esconde falhas reais da
#   cadeia inteira. Este helper troca o silencio por registro e mantem o fluxo.
#   A correcao complementar e a funcao chamada guardar os proprios comandos
#   falliveis (nao depender do errexit estar desligado dentro dela).
_tentar_log() {
    local rotulo="${1:-operacao}"
    local arquivo_log="${2:-${LOG_LIMPA:-/dev/null}}"
    shift 2 || true

    if (($# == 0)); then
        _log "AVISO: ${rotulo} — nenhum comando informado" "${arquivo_log}" || true
        return 0
    fi

    local rc=0
    "$@" || rc=$?
    if (( rc != 0 )); then
        _log "AVISO: ${rotulo} falhou (rc=${rc}) — prosseguindo" "${arquivo_log}" || true
    fi
    return 0
}

#---------- FUNCOES DE ARQUIVO ----------#

# Remove arquivos antigos de um diretorio
# Parametros: $1=diretorio $2=dias $3=padrao(opcional)
# Remove arquivos antigos de um diretorio
# Parametros: $1=diretorio $2=dias $3=padrao(opcional) $4=nao_apagar(opcional)
#   $4: lista separada por espaco de globs que NUNCA podem ser removidos.
#       Padrao "*.dat *.idx": dados e indices do SAV nao sao temporarios, mesmo
#       que o padrao $3 case com eles. O expurgo manual de arquivos.sh aplica a
#       mesma protecao; sem ela aqui o expurgo DIARIO (que roda sozinho no
#       bootstrap) era o mais agressivo dos tres.
# Retorna: 0 se ok, 1 se diretorio/dias invalidos
_limpar_arquivos_antigos() {
    local diretorio="${1:-}"
    local dias="${2:-}"
    local padrao="${3:-*}"
    local nao_apagar="${4:-*.dat *.idx}"
    local count=0

    # Validação do diretório e segurança contra limpeza na RAIZ
    if [[ ! -d "$diretorio" || "$diretorio" == "/" || "$diretorio" == "//" ]]; then
        _log_erro "Diretorio nao encontrado ou inseguro para remocao: $diretorio"
        return 1
    fi

    # Validação do número de dias
    if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
        _log_erro "Numero de dias invalido: $dias"
        return 1
    fi

    # Montar as exclusoes em array (nomes com espaco/glob preservados).
    # read -a e obrigatorio: `arr=($var)` sem aspas sofre expansao de pathname
    # e o padrao "*.dat" viraria os .dat existentes no CWD, deixando a
    # exclusao inerte e os dados serem apagados.
    local -a find_exclusoes=()
    local -a _nao_apagar=()
    read -r -a _nao_apagar <<< "$nao_apagar"
    local _excl
    for _excl in ${_nao_apagar[@]+"${_nao_apagar[@]}"}; do
        [[ -z "$_excl" ]] && continue
        find_exclusoes+=("!" -iname "$_excl")
    done

    # Conta e remove em uma unica passada (find -delete evita um fork de rm por arquivo).
    # O "|| true" e obrigatorio: utils.sh roda sob `set -euo pipefail`, e o find
    # retorna 1 quando nao consegue descer em um subdiretorio (permissao). Sem
    # isso a atribuicao falha e o errexit mata o programa inteiro. O 2>/dev/null
    # ja esconde o aviso do find; o log abaixo registra o resultado real.
    local contagem
    contagem=$("${DEFAULT_FIND:-find}" "${diretorio:-.}" -name "$padrao" -type f -mtime +"$dias" \
        ${find_exclusoes[@]+"${find_exclusoes[@]}"} -print -delete 2>/dev/null | wc -l) || true
    count="${contagem//[[:space:]]/}"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0

    if ((count > 0)); then
        _log "Remocao concluida: $count arquivos antigos removidos de $diretorio"
    else
        _log "Nenhum arquivo antigo encontrado em $diretorio"
    fi

    return 0
}

#---------- FUNCOES DE INICIALIZACAO ----------#
# Executa limpeza automatica diaria
_executar_expurgador_diario() {
    local flag_file
    local savlog="${RAIZ}/portalsav/log"
    local err_isc="${RAIZ}/err_isc"
    local viewvix="${RAIZ}/savisc/viewvix/tmp"

    # Define diretório de logs com fallback
    local logs_dir="${DEFAULT_LOGS_DIR:-}"

    # So usa o flag de controle diario se houver um diretorio de log valido
    if [[ -n "$logs_dir" && -d "$logs_dir" && -w "$logs_dir" ]]; then
        flag_file="${logs_dir}/.expurgador_$(date +%Y%m%d)"

        # Se já foi executado hoje, pular
        if [[ -f "$flag_file" ]]; then
            return 0
        fi

        # Remover flags antigas (mais de 3 dias)
        "${DEFAULT_FIND:-find}" "${logs_dir}" -name ".expurgador_*" -mtime +3 -delete 2>/dev/null || true
    fi

    # Array de pares "dias:diretorio" (nao usar array associativo: chave vazia
    # e fatal em Bash 4.0-4.3 e 5.2+, e dirs duplicados descartariam regras).
    # Pares duplicados sao inofensivos: _limpar_arquivos_antigos e idempotente.
    # 30 dias em todos: antes eram 10/15, mais agressivos que o expurgo manual
    # de arquivos.sh, e sem proteger .dat/.idx. Este daily roda sozinho no
    # bootstrap (principal.sh), ou seja, era o expurgo mais destrutivo e o
    # menos visivel dos tres. Agora usa o mesmo criterio do manual.
    local -a pares_limpeza=(
        "30:${DEFAULT_LOGS_DIR:-}"
        "30:${DEFAULT_BACKUP_DIR:-}"
        "30:${DEFAULT_BASEBACKUP_DIR:-}"
        "30:${DEFAULT_PROGS_DIR:-}"
        "30:${DEFAULT_PROGS_ATUAL_DIR:-}"
        "30:${DEFAULT_ENVIA_DIR:-}"
        "30:${CFG_PORTALSAV:-}"
        "30:${savlog}"
        "30:${err_isc}"
        "30:${viewvix}"
    )

    # Loop otimizado para limpeza. O $4 explicita a protecao de .dat/.idx
    # (tambem o default do helper) para deixar a decisao visivel aqui.
    local _par_limpeza
    for _par_limpeza in "${pares_limpeza[@]}"; do
        local _dias_limpeza="${_par_limpeza%%:*}"
        local _dir_limpeza="${_par_limpeza#*:}"
        if [[ -n "$_dir_limpeza" && -d "$_dir_limpeza" ]]; then
            _tentar_log "expurgo diario em ${_dir_limpeza}" "${LOG_LIMPA}" \
                _limpar_arquivos_antigos "$_dir_limpeza" "$_dias_limpeza" "*.*" "*.dat *.idx"
        fi
    done

    # Criar flag para hoje (somente se o diretorio de flag for valido)
    if [[ -n "${flag_file:-}" ]] && touch "$flag_file" 2>/dev/null; then
        _log "Limpeza automatica diaria executada"
    fi

    return 0
}

# Funcao para checar se os programas necessarios estao instalados
# Checa se os programas necessarios para o atualiza.sh estao instalados no sistema.
# Se algum programa nao for encontrado, exibe uma mensagem de erro e sai do programa.
# Parametros: lista de programas a verificar (padrao: zip unzip rsync wget)
_check_instalado() {
    local apps=("$@")
    if (( ${#apps[@]} == 0 )); then
        apps=(zip unzip rsync wget)
    fi

    local faltand=()
    local install_cmd=""

    # Detectar gerenciador de pacotes
    if command -v apt >/dev/null 2>&1; then
        install_cmd="sudo apt update && sudo apt install"
    elif command -v yum >/dev/null 2>&1; then
        install_cmd="sudo yum install"
    elif command -v dnf >/dev/null 2>&1; then
        install_cmd="sudo dnf install"
    elif command -v pacman >/dev/null 2>&1; then
        install_cmd="sudo pacman -S"
    elif command -v zypper >/dev/null 2>&1; then
        install_cmd="sudo zypper install"
    else
        install_cmd="Instale manualmente"
    fi

    for app in "${apps[@]}"; do
        if ! command -v "$app" >/dev/null 2>&1; then
            faltand+=("$app")
        fi
    done

    if [[ ${#faltand[@]} -gt 0 ]]; then
        _erro "Programas nao encontrados"
        _aviso "Programas ausentes: ${faltand[*]}"
        _aviso "Sugestao: ${install_cmd} ${faltand[*]}"
        _aviso "Instale os programas ausentes e tente novamente."
        return 1
    fi
}




# ---------- COMPATIBILIDADE SSH ----------
# Retorna opcao para StrictHostKeyChecking que aceita automaticamente chaves
# novas, evitando que a primeira conexao trave pedindo confirmacao interativa
# (ou falhe com "host key verification failed").
# - 'accept-new' (OpenSSH >= 7.6): aceita chave nova sem prompt.
# - 'no' em clientes antigos (RHEL 6/CentOS 6, OpenSSH 5.x) que nao reconhecem
#   'accept-new' — tambem aceita chaves novas sem interromper o fluxo.
# NUNCA escreva StrictHostKeyChecking=aceitar diretamente — chame esta funcao.
_ssh_aceitar_novo() {
    local versao
    versao="$(ssh -V 2>&1 || true)"
    if [[ "${versao}" =~ OpenSSH_([0-9]+)\.([0-9]+) ]]; then
        local maior="${BASH_REMATCH[1]}"
        local menor="${BASH_REMATCH[2]}"
        if (( maior > 7 )) || (( maior == 7 && menor >= 6 )); then
            printf 'accept-new'
            return 0
        fi
    fi
    printf 'no'
}

#---------- FUNCOES DE CHAVES SSH ----------#
#===================================================================
# _configure_ssh_com_chaves - Gerencia criacao e envio de chaves SSH
# Complementa _configure_ssh_access adicionando autenticacao por chave
#===================================================================

# -------------------------------------------------------------------------
# Contexto SSH compartilhado pelas funcoes deste bloco (globais com prefixo
# proprio para nao colidir com SERVIDOR/PORTA/USUARIO/CHAVE de outros modulos).
# -------------------------------------------------------------------------
_ssh_contexto() {
    SSH_SERV="${DEFAULT_IP_SERVER:-}"
    SSH_PORTA="${DEFAULT_SSH_PORTA:-}"
    SSH_USUARIO="${DEFAULT_SSH_USER:-}"
    SSH_CHAVE="${DEFAULT_CHAVE_SSH:-${HOME}/.ssh/id_rsa_atualiza}"
    SSH_CHAVE_PUB="${DEFAULT_CHAVE_SSH_PUB:-${HOME}/.ssh/id_rsa_atualiza.pub}"
    export SSH_SERV SSH_PORTA SSH_USUARIO SSH_CHAVE SSH_CHAVE_PUB
}

# -------------------------------------------------------------------------
# Verifica dependencias
# -------------------------------------------------------------------------
_checar_dependencias() {
    # Ajustar contexto antes de validar
    _ssh_contexto

    # Validacao das variaveis obrigatorias
    if [[ -z "${SSH_SERV}" ]]; then
        _erro "Variavel DEFAULT_IP_SERVER nao foi definida."
        return 1
    fi
    for cmd in ssh ssh-keygen ssh-copy-id; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            _erro "Comando '$cmd' nao encontrado. Instale o pacote openssh-client."
            return 1
        fi
    done
    _ok "Dependencias verificadas."
    _aviso "Verificando configuracao de chaves SSH..."
}

# -------------------------------------------------------------------------
# Garante que ~/.ssh existe com as permissoes corretas
# -------------------------------------------------------------------------
_preparar_diretorio_ssh() {
    if [[ -d "$HOME/.ssh" ]]; then
        return 0
    fi

    if ! mkdir -p "$HOME/.ssh"; then
        _erro "Nao foi possivel criar $HOME/.ssh (verifique permissao de escrita em $HOME)."
        return 1
    fi
    # 0700: padrao exigido pelo ssh para o diretorio de chaves. mkdir acima já
    # cria com o umask vigente, entao o chmod corrige sem janela de exposicao.
    if ! chmod 700 "$HOME/.ssh"; then
        _erro "Diretorio $HOME/.ssh criado, mas chmod 700 falhou."
        return 1
    fi
    _ok "Diretorio ~/.ssh criado."
    return 0
}

# -------------------------------------------------------------------------
# Verifica se a chave ja existe; pergunta se quer criar caso nao exista
# -------------------------------------------------------------------------
# Verifica se a chave ja existe; pergunta se quer criar caso nao exista
# Retorna: 0 se a chave existe (ou foi criada com sucesso), 1 se nao ha chave
_verificar_ou_criar_chave() {
    if [[ -f "$SSH_CHAVE" && -f "$SSH_CHAVE_PUB" ]]; then
        _ok "Chave SSH encontrada: $SSH_CHAVE"
        return 0
    fi

    _aviso "Chave SSH nao encontrada em $SSH_CHAVE"
    printf "\nDeseja criar uma nova chave SSH agora? [s/N] "
    local RESPOSTA=""
    # -t: timeout/EOF-guard (sem ele, stdin fechado abortava a funcao)
    read -r -t "${DEFAULT_READ_TIMEOUT:-60}" RESPOSTA || RESPOSTA=""

    case "$RESPOSTA" in
        [sS]|[sS][iI][mM])
            _msg "Gerando par de chaves RSA 4096 bits..."
            if ! ssh-keygen -t rsa -b 4096 -f "$SSH_CHAVE" -C "${SSH_USUARIO:-sav}@$(hostname)-$(date +%Y%m%d)"; then
                _erro "Falha ao criar a chave SSH em $SSH_CHAVE."
                return 1
            fi
            # Confirmar que os dois arquivos existem: ssh-keygen pode terminar
            # com rc=0 e deixar o par incompleto (ex: disco cheio no .pub).
            if [[ ! -f "$SSH_CHAVE" || ! -f "$SSH_CHAVE_PUB" ]]; then
                _erro "ssh-keygen terminou, mas o par de chaves esta incompleto em $SSH_CHAVE."
                return 1
            fi
            _ok "Chave criada com sucesso: $SSH_CHAVE"
            ;;
        *)
            _aviso "Operacao cancelada. Sem chave SSH nao e possivel conectar sem senha."
            return 1
            ;;
    esac
    return 0
}

# -------------------------------------------------------------------------
# Envia a chave publica ao servidor principal
# -------------------------------------------------------------------------
_enviar_chave_para_servidor() {
    _msg "Enviando chave publica para ${SSH_USUARIO}@${SSH_SERV}:${SSH_PORTA}..."
    _aviso "Sera solicitada a senha do usuario '${SSH_USUARIO}' no servidor (ultima vez)."

    # O proprio ssh-copy-id executa tres ssh internos antes do prompt de senha
    # (sonda da versao remota, filtro de chaves ja instaladas e a instalacao).
    # Sem repassar -o, o PRIMEIRO desses ssh para no prompt de confirmacao da
    # chave do host ("Are you sure you want to continue connecting (yes/no)?")
    # e o programa fica congelado na linha "INFO: Source of key(s)..." sem
    # avancar. Sem ConnectTimeout, um pacote descartado no caminho segura o
    # fluxo por minutos. Mesmo tratamento ja usado em _testar_conexao,
    # config.sh e vaievem.sh — nunca escreva StrictHostKeyChecking literal.
    #
    # ssh-copy-id moderno aceita -p/-o; o de OpenSSH 5.x (RHEL/CentOS 6) aceita
    # SO -i: sem -p ele cairia na porta 22 e, em firewall com DROP, travaria
    # ali tambem. Suporta -p e -o sao detectados separadamente porque nao
    # apareceram juntos na mesma versao.
    local uso_ssh_copy_id
    uso_ssh_copy_id="$(ssh-copy-id -h 2>&1 || true)"

    local -a ssh_copy_cmd=(ssh-copy-id -i "$SSH_CHAVE_PUB")
    if grep -qE '\-p' <<< "$uso_ssh_copy_id"; then
        ssh_copy_cmd+=(-p "$SSH_PORTA")
    elif [[ -n "$SSH_PORTA" ]]; then
        _erro "ssh-copy-id desta maquina nao aceita -p (OpenSSH antigo): ele cairia na porta 22 e travaria ali."
        _msg "  Envie a chave pela porta ${SSH_PORTA} direto:"
        _msg "  ssh -p ${SSH_PORTA} ${SSH_USUARIO}@${SSH_SERV} 'cat >> ~/.ssh/authorized_keys' < ${SSH_CHAVE_PUB}"
        return 0
    fi
    if grep -qE '\-o' <<< "$uso_ssh_copy_id"; then
        ssh_copy_cmd+=(-o "StrictHostKeyChecking=$(_ssh_aceitar_novo)")
        ssh_copy_cmd+=(-o "ConnectTimeout=${SSH_TIMEOUT:-15}")
    fi
    ssh_copy_cmd+=("${SSH_USUARIO}@${SSH_SERV}")

    if "${ssh_copy_cmd[@]}"; then
        _ok "Chave enviada com sucesso!"
        _ok "A partir de agora a conexao sera feita sem senha."
    else
        _erro "Falha ao enviar a chave. Verifique:"
        _msg "  - Se o servidor esta acessivel: ssh -p $SSH_PORTA ${SSH_USUARIO}@${SSH_SERV}"
        _msg "  - Se o usuario '${SSH_USUARIO}' existe no servidor"
        _msg "  - Se a senha informada esta correta"
        _aviso "Sera solicitada a senha do usuario '${SSH_USUARIO}' no servidor."
    fi
    return 0
}

# -------------------------------------------------------------------------
# Testa a conexao sem senha
# -------------------------------------------------------------------------
_testar_conexao() {
    _msg "Testando conexao sem senha..."
    if ssh -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o "StrictHostKeyChecking=$(_ssh_aceitar_novo)" \
        -i "$SSH_CHAVE" \
        -p "$SSH_PORTA" \
        "${SSH_USUARIO}@${SSH_SERV}" \
        "echo 'Conexao OK em: \$(hostname) - \$(date)'"; then
        _ok "Conexao sem senha funcionando perfeitamente!"
    else
        _erro "Conexao sem senha falhou. Verifique as permissoes no servidor:"
        _erro "  chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    fi
    return 0
}
