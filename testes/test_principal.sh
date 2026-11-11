#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (CFG_VERSAOCLASS, DEFAULT_LOGS_DIR, UPDATE,
# ...) sao consumidas pelos modulos que este arquivo carrega com `source`, nao
# pelo proprio script.
set -euo pipefail
#
# testes/test_principal.sh - verificacoes isoladas de binarios/principal.sh
#
# principal.sh e o ponto de entrada: define a ORDEM DE CARGA dos 15 modulos
# (MODULOS_CARREGAR) e orquestra o fluxo _main -> _inicializar_sistema ->
# _login -> _principal -> _finalizar_sistema.
#
# A ordem de carga NAO e estetica (AGENTS.md): uma chamada em TEMPO DE SOURCE
# (topo do modulo) a uma funcao de um modulo carregado depois quebra em
# runtime. Este arquivo e o "harness de carga" que o AGENTS.md exige antes de
# mexer na ordem:
#   1. extrai a ordem do FONTE (nao de uma copia hardcoded);
#   2. confere a cadeia ESTATICA (quem chama quem, em tempo de source);
#   3. carrega os 15 modulos na ordem extraida, num sandbox, e confere a
#      cadeia EMPIRICA (a cada passo, o que o modulo precisa ja existe);
#   4. exercita o fluxo do _main.
#
# Rodar direto, sem TTY:
#   bash testes/test_principal.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

falhas=0
total=0
_checar() { # _checar <descricao> <esperado> <obtido>
    total=$((total + 1))
    if [[ "$2" == "$3" ]]; then
        printf 'ok    - %s\n' "$1"
    else
        printf 'FALHA - %s\n         esperado: [%s]\n         obtido:   [%s]\n' "$1" "$2" "$3"
        falhas=$((falhas + 1))
    fi
}

_contem() { # _contem <texto> <substring> -> sim/nao
    if [[ "$1" == *"$2"* ]]; then printf 'sim'; else printf 'nao'; fi
}

_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

MODS="${RAIZ_TESTE}/binarios"

# ==========================================================================
# 1. A ORDEM DE CARGA, EXTRAIDA DO FONTE
# ==========================================================================
ORDEM=()
while IFS= read -r nome; do
    ORDEM+=("$nome")
done < <(sed -n '/declare -a MODULOS_CARREGAR=(/,/^)/p' "${MODS}/principal.sh" \
    | grep -oE '"[a-z_]+\.sh"' | tr -d '"')

_checar "ordem: 15 modulos carregados" "15" "${#ORDEM[@]}"
_checar "ordem: primeiro e constantes.sh" "constantes.sh" "${ORDEM[0]:-}"
# Regra do AGENTS.md: utils.sh e o SEGUNDO de proposito (config.sh e auth.sh
# chamam _garantir_diretorio no proprio source).
_checar "ordem: utils.sh e o segundo" "utils.sh" "${ORDEM[1]:-}"
_checar "ordem: config.sh e o terceiro" "config.sh" "${ORDEM[2]:-}"
_checar "ordem: auth.sh e o quarto" "auth.sh" "${ORDEM[3]:-}"
_checar "ordem: menus.sh e o ultimo" "menus.sh" "${ORDEM[14]:-}"

# Nenhum modulo pode vir duas vezes
_duplicados="$(printf '%s\n' "${ORDEM[@]}" | sort | uniq -d | tr '\n' ' ')"
_checar "ordem: nenhum modulo duplicado" "" "${_duplicados}"

# Todo modulo carregado tem de existir no disco
_ausentes=""
for m in "${ORDEM[@]}"; do
    [[ -f "${MODS}/${m}" ]] || _ausentes="${_ausentes}${m} "
done
_checar "ordem: todos os modulos existem" "" "$_ausentes"

# Os modulos de binarios/ que NAO entram na ordem: o entry point e os dois
# executados sob demanda (setup) ou acionados por outro modulo (cadastro).
_nao_carregados=""
for f in "${MODS}"/*.sh; do
    base="$(basename "$f")"
    _achou="nao"
    for m in "${ORDEM[@]}"; do
        [[ "$m" == "$base" ]] && _achou="sim" && break
    done
    [[ "$_achou" == "nao" ]] && _nao_carregados="${_nao_carregados}${base}"$'\n'
done
# comparacao por conjunto (a ordem do glob nao e garantida)
_esperados="cadastro.sh
principal.sh
setup.sh"
_checar "ordem: fora da carga ficam principal, cadastro e setup" \
    "$(printf '%s' "$_esperados" | sort | tr '\n' ' ')" \
    "$(printf '%s' "$_nao_carregados" | sort | tr '\n' ' ')"

# ==========================================================================
# 2. CADEIA ESTATICA: chamadas em TEMPO DE SOURCE
# ==========================================================================
# Regra: no TOPO do modulo (fora de corpo de funcao), toda chamada a funcao
# de outro modulo precisa apontar para um modulo JA CARREGADO.
#
# Reexoes aceitas pela regra do AGENTS.md:
#   - guard `command -v _foo >/dev/null && _foo` (resolucao em runtime);
#   - as 3 referencias de constantes.sh para _encerrar_programa, que estao
#     atras do `return 1` do guard "sourced vs executed" (constantes.sh nunca e
#     executado direto: o shebang e decorativo).
VIOLACOES_CONHECIDAS="constantes.sh:_encerrar_programa
constantes.sh:_encerrar_programa
constantes.sh:_encerrar_programa"

declare -A DONO=()
declare -A IDX=()
i=0
for m in "${ORDEM[@]}"; do
    IDX["$m"]="$i"
    i=$((i + 1))
    while IFS= read -r fn; do
        [[ -n "$fn" ]] || continue
        DONO["$fn"]="$m"
    done < <(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "${MODS}/${m}" | tr -d '()')
done

# Linhas de TOPO: fora de corpo de funcao. O estilo do repo indenta o corpo
# das funcoes e fecha com "}" na coluna 0.
detectar_topo() {
    awk '
        /^[[:space:]]*#/ { next }
        { sub(/[[:space:]]#.*$/, "") }
        /^[a-zA-Z_][a-zA-Z0-9_]*\(\)/ { depth++; next }
        /^\}/ { if (depth > 0) depth--; next }
        depth == 0 { print NR }
    ' "$1" | sort -n
}

violacoes_texto=""
violacoes_count=0
for m in "${ORDEM[@]}"; do
    idx_c="${IDX[$m]}"
    while IFS= read -r ln; do
        linha="$(sed -n "${ln}p" "${MODS}/${m}")"
        linha="${linha%%#*}"                       # descarta comentario
        [[ -n "${linha//[[:space:]]/}" ]] || continue
        while IFS= read -r fn; do
            [[ -n "${DONO[$fn]:-}" ]] || continue
            dono="${DONO[$fn]}"
            [[ "$dono" == "$m" ]] && continue
            idx_d="${IDX[$dono]}"
            (( idx_d > idx_c )) || continue
            ctx="$(sed -n "$((ln - 1)),${ln}p" "${MODS}/${m}")"
            if printf '%s' "$ctx" | grep -qE "command -v +${fn}\b"; then
                continue                            # guard aceito pelo AGENTS.md
            fi
            violacoes_count=$((violacoes_count + 1))
            violacoes_texto="${violacoes_texto}${m}:${fn}"$'\n'
        done < <(printf '%s' "$linha" | grep -oE '\b_[a-zA-Z0-9_]+' | sort -u)
    done < <(detectar_topo "${MODS}/${m}")
done

# Toda violacao tem de estar na lista conhecida: uma NOVA (alguem que chamou
# para tras sem guardar) e a regressao que este teste existe para pegar.
_novas=""
while IFS= read -r v; do
    [[ -n "$v" ]] || continue
    if ! printf '%s\n' "$VIOLACOES_CONHECIDAS" | grep -qxF "$v"; then
        _novas="${_novas}${v}"$'\n'
    fi
done < <(printf '%s' "$violacoes_texto")

_checar "cadeia: nenhuma referencia nova para tras em tempo de source" "" "$_novas"
_checar "cadeia: as 3 referencias conhecidas seguem no lugar" "3" "$violacoes_count"

# ==========================================================================
# 3. CADEIA EMPIRICA: carregar os 15 modulos na ordem extraida, num sandbox
# ==========================================================================
# Cada modulo e carregado isoladamente. Apos cada passo, TODAS as funcoes dos
# modulos ja carregados precisam estar definidas — e, principalmente, as
# funcoes que o modulo recem-carregado chama no proprio source.
SB="${_TMP}/sandbox"
mkdir -p "${SB}/libs" "${SB}/cfg" "${SB}/logs"
cp "${MODS}"/*.sh "${SB}/libs/"

export LIBS_DIR="${SB}/libs"
export CFG_DIR="${SB}/cfg"
export DEFAULT_LOGS_DIR="${SB}/logs"
export SCRIPT_DIR="${SB}"
export RAIZ="${SB}"
export PERM_DIR_SECURE=0755
export DEFAULT_ZIP=zip
export DEFAULT_UNZIP=unzip
export DEFAULT_TAR=tar
export DEFAULT_FIND=find
export LOG_ATU="${SB}/logs/harness.log"
export LOG_LIMPA="${SB}/logs/limpa.log"
# .config vazio: constantes.sh procuraria o arquivo em CFG_DIR
: >"${CFG_DIR}/.config"

declare -a CARREGADOS=()
falha_carga=""
for m in "${ORDEM[@]}"; do
    # shellcheck source=/dev/null
    if ! source "${SB}/libs/${m}"; then
        falha_carga="${falha_carga}${m} "
        continue
    fi
    CARREGADOS+=("$m")

    # funcoes de todos os modulos carregados ate agora
    faltando=""
    for anterior in "${CARREGADOS[@]}"; do
        while IFS= read -r fn; do
            [[ -n "$fn" ]] || continue
            if ! command -v "$fn" >/dev/null 2>&1; then
                faltando="${faltando}${anterior}:${fn} "
            fi
        done < <(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "${SB}/libs/${anterior}" | tr -d '()')
    done
    _checar "carga: apos ${m} todas as funcoes anteriores existem" "" "$faltando"
done

_checar "carga: nenhum modulo falhou ao carregar" "" "$falha_carga"
_checar "carga: os 15 modulos foram carregados" "15" "${#CARREGADOS[@]}"

# A ordem extraida do fonte e a mesma que o proprio principal.sh usa: os 15
# modulos tem de estar definidos ao final.
_nao_carregados_final=""
for m in "${ORDEM[@]}"; do
    _achou="nao"
    for c in "${CARREGADOS[@]}"; do
        [[ "$c" == "$m" ]] && _achou="sim" && break
    done
    [[ "$_achou" == "nao" ]] && _nao_carregados_final="${_nao_carregados_final}${m} "
done
_checar "carga: a ordem extraida cobre todos os modulos" "" "$_nao_carregados_final"

# Funcao representativa de cada modulo: precisa existir depois da carga
for par in "constantes.sh:_carregar_config_seguro" "utils.sh:_garantir_diretorio" \
           "config.sh:_validar_config_file" "auth.sh:_login" \
           "lembrete.sh:_escrever_nova_nota" "vaievem.sh:_usar_chave_ssh" \
           "sistema.sh:_mostrar_parametros" "baixar.sh:_executar_update" \
           "arquivos.sh:_recuperar_arquivo_individual" "backup.sh:_executar_backup" \
           "programas.sh:_validar_pre_requisitos_atualizacao" \
           "biblioteca.sh:_atualizar_biblioteca_offline" "help.sh:_ajuda_rapida" \
           "variaveis.sh:_consultar_variaveis" "menus.sh:_principal"; do
    mod="${par%%:*}"
    fn="${par##*:}"
    if command -v "$fn" >/dev/null 2>&1; then
        _checar "carga: ${mod} definiu ${fn}" "0" "0"
    else
        _checar "carga: ${mod} definiu ${fn}" "0" "1"
    fi
done

# ==========================================================================
# 4. O FLUXO DO _main
# ==========================================================================
# _main e orquestrado em principal.sh (que nao foi carregado aqui, para nao
# instalar os traps no shell do teste). O fluxo roda em SUB-SHELL, com stubs
# para _login/_principal/_validar_ssh.
#
# Os stubs sao definidos DEPOIS do source: o source carrega os 15 modulos e o
# proprio principal.sh, que definem _inicializar_sistema, _login, _principal e
# _validar_ssh — um stub colocado antes seria sobrescrito.
_fluxo() { # _fluxo <rc_inicializar> <rc_login> <rc_ssh> -> imprime o exit code
    SCEN_INIT="$1"
    SCEN_LOGIN="$2"
    SCEN_SSH="$3"
    (
        export CFG_DIR="${SB}/cfg"
        export LOG_ATU="${SB}/logs/fluxo.log"
        # shellcheck source=/dev/null
        . "${MODS}/principal.sh" >/dev/null 2>&1
        # os cenarios vem do ESCOPO (SCEN_*), nao de $1: dentro de uma funcao
        # os posicionais sao os da propria funcao, e o stub e chamado sem
        # argumentos.
        _inicializar_sistema() { return "$SCEN_INIT"; }
        _login() { return "$SCEN_LOGIN"; }
        _validar_ssh() { return "$SCEN_SSH"; }
        _principal() { : >"${SB}/menu_chegou.flag"; return 0; }
        _mostrar_boas_vindas() { :; }
        _mostrar_aviso() { :; }
        _mostrar_notas_iniciais() { :; }
        _main
    ) >/dev/null 2>&1
    printf '%s' "$?"
}

rm -f "${SB}/menu_chegou.flag"
_checar "fluxo: caminho feliz chega ao menu e sai com 0" "0" "$(_fluxo 0 0 0)"
_checar "fluxo: o menu principal foi chamado" "sim" \
    "$([ -f "${SB}/menu_chegou.flag" ] && printf 'sim' || printf 'nao')"

_checar "fluxo: inicializacao falha aborta com 1" "1" "$(_fluxo 1 0 0)"
_checar "fluxo: login falha aborta com 1" "1" "$(_fluxo 0 1 0)"
_checar "fluxo: validacao SSH falha aborta com 1" "1" "$(_fluxo 0 0 1)"

# O shell do teste nao pode herdar os traps do sistema
trap - HUP INT TERM QUIT

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
