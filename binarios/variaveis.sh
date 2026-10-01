#!/usr/bin/env bash
set -euo pipefail
#
# variaveis.sh - Modulo de consulta de variaveis/constantes do sistema SAV
## SISTEMA SAV - Script de Atualizacao Modular
# Versao: 01/10/2026
#
# Este modulo e carregado via source por principal.sh (ver MODULOS_CARREGAR).
# Ponto de entrada publico: _consultar_variaveis [filtro]
# Uso pelo menu: opcao "Consultar Variaveis" no Menu das Configuracoes.
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# NOTA: Todas as funcoes usam prefixo _var_ para evitar colisao de nomes
#       com outros modulos carregados no mesmo shell.
#

# =============================================================================
# CONFIGURACAO INICIAL (apenas se ainda nao definida por modulos anteriores)
# =============================================================================
# Evita redefinir variaveis ja estabelecidas por constantes.sh / config.sh

SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"
CONFIG_FILE="${CONFIG_FILE:-${CFG_DIR:-${SCRIPT_DIR}/configuracoes}/.config}"
# Cores vem de config.sh (tput em _inicializar_variaveis_sistema, que so chama
# tput com `[[ -t 1 ]]`). BOLD nao existe la, entao e derivado aqui com a mesma
# guarda: sem TTY (saida em pipe/log) um tput bold ainda emitiria o escape
# [1m e poluiria a listagem. O `|| true` evita que tput ausente derrube o
# source sob `set -e`.
if [[ -t 1 ]]; then
    BOLD="${BOLD:-$(tput bold 2>/dev/null || true)}"
else
    BOLD="${BOLD:-}"
fi

# =============================================================================
# DEFINICAO DE CONSTANTES POR CATEGORIA
# Estrutura usada pela listagem tabular do modulo.
# =============================================================================
# A ordem de exibicao vem de _VAR_CATEGORIAS_ORDEM (array indexado). Um
# `declare -A` sozinho itera na ordem de hash: a listagem aparecia
# embaralhada e mudava entre execucoes. As duas estruturas sao mantidas
# juntas — a ordem define a apresentacao, o mapa define o conteudo.
declare -a _VAR_CATEGORIAS_ORDEM=(
    "DIRETORIOS E CAMINHOS"
    "DIRETORIOS PADRAO"
    "CONFIGURACOES DO SISTEMA"
    "CONFIGURACOES DE REDE"
    "FLAGS BOOLEANAS"
    "ACESSO OFFLINE"
    "BASES DE DADOS"
    "SAVISC - DIRETORIO E UTILITARIOS"
    "SEGURANCA E PERMISSOES"
    "COMANDOS EXTERNOS"
    "TEMPOS E LIMITES"
    "LOGS"
    "ATUALIZACAO"
)

declare -A _VAR_CATEGORIAS=(
    ["DIRETORIOS E CAMINHOS"]="RAIZ SCRIPT_DIR LIBS_DIR CFG_DIR CONFIG_FILE"
    ["CONFIGURACOES DO SISTEMA"]="CFG_VERSAOCLASS CFG_EMPRESA"
    ["BASES DE DADOS"]="CFG_BASE_DIR CFG_BASE_DIR2 CFG_BASE_DIR3"
    ["FLAGS BOOLEANAS"]="CFG_ACESSO_SSH CFG_OFFLINE CFG_CHAVE_SSH"
    ["CONFIGURACOES DE REDE"]="DEFAULT_SSH_PORTA DEFAULT_IP_SERVER SSH_TIMEOUT"
    ["DIRETORIOS PADRAO"]="DEFAULT_CONFIG_DIR DEFAULT_LIBS_DIR DEFAULT_LOGS_DIR DEFAULT_BACKUP_DIR DEFAULT_BASEBACKUP_DIR DEFAULT_BIBLIOTECA_ATUAL_DIR DEFAULT_BIBLIOTECA_DIR DEFAULT_PROGS_ATUAL_DIR DEFAULT_PROGS_DIR DEFAULT_ENVIA_DIR CFG_PORTALSAV"
    ["SAVISC - DIRETORIO E UTILITARIOS"]="SAVISC REBUILD"
    ["ACESSO OFFLINE"]="ACESSO_OFF CFG_BACKUP_PATH"

    # Completam a listagem: sem estas, "LISTAGEM COMPLETA" mostrava 30 de 55
    # variaveis e escondia exatamente as que o usuario precisa conferir
    # (a URL de update, os comandos externos, os timeouts).
    ["SEGURANCA E PERMISSOES"]="PERM_DIR_SECURE PERM_FILE_PRIVATE PERM_FILE_EXEC PERM_FILE_CONFIG PERM_FILE_BACKUP HASH_ALGORITHM"
    ["COMANDOS EXTERNOS"]="DEFAULT_ZIP DEFAULT_UNZIP DEFAULT_TAR DEFAULT_FIND"
    ["TEMPOS E LIMITES"]="DEFAULT_READ_TIMEOUT DEFAULT_PRESS_TIMEOUT SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT MAX_LOGIN_ATTEMPTS DEFAULT_COLUMNS DEFAULT_LINES"
    ["LOGS"]="LOG_ATU LOG_LIMPA LOG_TMP"
    ["ATUALIZACAO"]="GITHUB_UPDATE_URL ARQUIVO_ZIP_ATU ATU_DIR_TEMP ATU_DIR_STAGING ATU_SUFIXO_BACKUP ATU_TENTATIVAS_DOWNLOAD"
)

# =============================================================================
# FUNCAO: Carregar arquivo de configuracao (delegacao segura)
# =============================================================================
# Nao existe fallback por source. O `.config` e entrada de DADOS, nao codigo:
# executa-lo faria uma linha "PATH=/tmp/evil" (ou "BASH_ENV=...") no .config
# sequestrar o proprio interpretador — todo comando externo do processo passaria
# a resolver em /tmp/evil. _carregar_config_seguro (constantes.sh) bloqueia
# essas chaves por nome e rejeita valores com metacaractere; e o unico caminho
# aceito aqui.
#
# A queda do fallback antigo tambem eliminava um vazamento de estado: o
# `set -a` (allexport) que o acompanhava nao era restaurado se o source
# falhasse no meio, e todas as variaveis seguintes passavam a vazar para os
# processos filhos.
# Retorna: 0=carregado 1=arquivo ausente/ilegivel 2=parser seguro indisponivel
_var_carregar_config() {
    local config_file="${1:-}"

    if [[ -z "$config_file" || ! -f "$config_file" || ! -r "$config_file" ]]; then
        return 1
    fi

    if ! command -v _carregar_config_seguro >/dev/null 2>&1; then
        _erro "Parser seguro de configuracao indisponivel (_carregar_config_seguro)."
        _erro "Recarregando o .config seria inseguro; arquivos ja mantem os valores atuais."
        return 2
    fi

    _carregar_config_seguro "$config_file"
}

# =============================================================================
# FUNCAO: Obter valor de uma variavel com fallback
# =============================================================================
# Valida o nome antes da indirecao: "${!nome_var}" com nome vazio ou contendo
# espaco emite "invalid variable name" do proprio bash e devolve 1, o que sob
# `set -e` abortaria a listagem inteira.
# Distingue "definida mas vazia" de "nao definida" — ${!var:-} tratava as duas
# como ausentes, e um .config com "CFG_VERSAOCLASS=" legitimamente vazio
# aparecia como NAO DEFINIDO, mandando o usuario procurar o que ja estava la.
# Retorna: sempre 0 (e uma funcao de exibicao, nao de fluxo)
_var_obter_valor() {
    local nome_var="${1:-}"
    local valor

    if [[ ! "$nome_var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        printf '%s\n' "INVALIDO"
        return 0
    fi

    # +_ (nao :-) so expande se a variavel EXISTE, mesmo vazia.
    if [[ -z "${!nome_var+_}" ]]; then
        printf '%s\n' "NAO DEFINIDO"
        return 0
    fi

    valor="${!nome_var}"
    if [[ -z "$valor" ]]; then
        printf '%s\n' "(vazio)"
    else
        printf '%s\n' "$valor"
    fi
    return 0
}

# =============================================================================
# FUNCAO: Exibir constantes em formato tabular
# Parametros: $1 = filtro opcional por nome de categoria
# =============================================================================
_var_exibir_tabular() {
    local filtro="${1:-}"
    local categoria variavel valor
    local -a nomes_var=()
    local categorias_exibidas=0
    local filtro_minusculo="${filtro,,}"

    # Sem tput (ou com terminal estreito) o %*s do cabecalho pode falhar.
    local largura_var=35
    local largura_valor=60
    if (( COLUMNS > largura_var + largura_valor + 2 )); then
        largura_valor=$(( COLUMNS - largura_var - 1 ))
    fi

    printf "\n"
    printf "%s\n" "CONSTANTES DO SISTEMA SAV - LISTAGEM COMPLETA"
    printf "\n"

    # Exibir informacoes sobre o arquivo de configuracao
    printf "%s%s Fonte de Configuracao:%s\n" "$VERDE" "$BOLD" "$NORMAL"
    if [[ -f "$CONFIG_FILE" ]] && [[ -r "$CONFIG_FILE" ]]; then
        printf "   %s Status: Carregado com sucesso %s%s\n" "${VERDE}" "$CONFIG_FILE" "${NORMAL}"
    else
        printf "   %s Status: Nao encontrado (usando valores padrao) %s%s\n" "${AMARELO}" "$CONFIG_FILE" "${NORMAL}"
    fi
    printf "\n"

    # Cabecalho da tabela
    printf "%s%-*s%s %s\n" "${VERDE}" "$largura_var" "VARIAVEL" "${NORMAL}" "VALOR"
    printf "%-*s %s\n" "$largura_var" "$(printf '%*s' "$largura_var" '' | tr ' ' '-')" \
        "$(printf '%*s' "$largura_valor" '' | tr ' ' '-')"

    # Itera pela ordem declarada, nao pela ordem de hash do array assoc.
    for categoria in "${_VAR_CATEGORIAS_ORDEM[@]}"; do
        # Se ha filtro, verificar se a categoria corresponde (case-insensitive)
        if [[ -n "$filtro_minusculo" ]]; then
            if [[ ! "${categoria,,}" =~ $filtro_minusculo ]]; then
                continue
            fi
        fi

        printf "\n%s%s[%s]%s\n" "$AMARELO" "$BOLD" "$categoria" "$NORMAL"
        (( categorias_exibidas++ )) || true

        # `read -ra` em vez de `for v in ${...}`: sem aspas, o word splitting
        # funciona por acidente E o globbing fica habilitado — um nome com "*"
        # casaria com arquivos do diretorio atual.
        read -ra nomes_var <<< "${_VAR_CATEGORIAS[$categoria]:-}"
        for variavel in "${nomes_var[@]}"; do
            [[ -n "$variavel" ]] || continue
            valor=$(_var_obter_valor "$variavel")
            printf "%-*s %s\n" "$largura_var" "$variavel" "$valor"
        done
    done

    # Filtro que nao casa nenhuma categoria deixava cabecalho + tabela vazia,
    # sem nenhuma pista do motivo.
    if (( categorias_exibidas == 0 )); then
        printf "\n%s[Nenhuma categoria corresponde ao filtro '%s']%s\n" "$AMARELO" "$filtro" "$NORMAL"
        printf "%sUse 'listar' para ver todas as categorias.%s\n" "$AMARELO" "$NORMAL"
    fi

    printf "\n"
}

# =============================================================================
# FUNCAO PUBLICA: Consultar variaveis (ponto de entrada do menu)
# Permite filtro opcional interativo. Retorna 0 sempre (exibicao).
# =============================================================================
_consultar_variaveis() {
    local filtro=""
    local rc_config=0

    # Recarrega o .config para refletir edicoes feitas durante a sessao.
    # Falha aqui nao e fatal: as variaveis do shell ja tem os valores atuais.
    # O codigo 2 (parser seguro ausente) e o unico que merece aviso — sem ele
    # o .config NAO foi lido e o usuario precisa saber.
    # `|| rc_config=$?` em vez de `if ! ...; then rc_config=$?`: dentro de
    # `if !` o $? ja vem invertido (0) e o caso 2 nunca seria detectado.
    rc_config=0
    _var_carregar_config "$CONFIG_FILE" || rc_config=$?
    if (( rc_config == 2 )); then
        _aguardar_tecla
    fi

    # Filtro opcional informado como argumento direto
    filtro="${1:-}"

    # Se nao veio por argumento, perguntar interativamente
    if [[ -z "$filtro" && -t 0 ]]; then
        clear 2>/dev/null || true
        _linha "=" "${VERDE}" 2>/dev/null || true
        printf '%s\n' "${VERMELHO}Consulta de Variaveis do Sistema${NORMAL}"
        _linha 2>/dev/null || true
        printf '%s' "${AMARELO}Digite um filtro (ex: DIRETORIOS, REDE) ou ENTER para listar tudo: ${NORMAL}"
        # -t evita travar o menu indefinidamente sem entrada; o codebase ja usa
        # DEFAULT_READ_TIMEOUT em utils.sh (_confirmar).
        if ! read -r -t "${DEFAULT_READ_TIMEOUT:-60}" filtro; then
            _linha 2>/dev/null || true
            _aviso "Entrada expirada. Listando todas as categorias."
            filtro=""
        fi
        filtro="${filtro:-}"
    fi

    _var_exibir_tabular "$filtro"

    # Aguardar tecla antes de retornar ao menu (se a funcao existir)
    if command -v _aguardar_tecla >/dev/null 2>&1; then
        _aguardar_tecla
    fi

    return 0
}
