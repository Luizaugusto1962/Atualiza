#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (CFG_VERSAOCLASS, CFG_ACESSO_SSH,
# DEFAULT_LOGS_DIR, E_EXEC, T_TELAS, ...) sao consumidas pelos modulos que este
# arquivo carrega com `source`, nao pelo proprio script.
set -euo pipefail
#
# testes/test_config.sh - verificacoes isoladas de binarios/config.sh
#
# config.sh carrega e valida o .config da empresa, configura os diretorios de
# trabalho e mantem o registro de variaveis que precisa ser limpo no fim da
# sessao. O scanner _validar_config_file e a primeira barreira do .config
# (constantes.sh tem a segunda, o parser).
#
# config.sh registra traps de HUP/INT/TERM/QUIT no proprio source — o teste os
# restaura no fim para nao deixar o shell do agente com handlers do sistema.
#
# Rodar direto, sem TTY:
#   bash testes/test_config.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

# shellcheck source=../binarios/utils.sh
. "${RAIZ_TESTE}/binarios/utils.sh"

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

_rc() { # _rc <comando...> -> imprime o codigo de retorno
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    printf '%s' "$rc"
}

_executar() { # _executar <comando...> ; resultado em RC
    RC=0
    "$@" >/dev/null 2>&1 || RC=$?
}

_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

# ---------- ambiente: clones dos diretorios protegidos, dentro do TMP ----------#
export SCRIPT_DIR="${_TMP}/script"
export CFG_DIR="${_TMP}/cfg"
export CFG_PORTALSAV="${_TMP}/portalsav"
export RAIZ="${_TMP}/raiz"
export LOG_ATU="${_TMP}/logs/test_config.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups_base"
export DEFAULT_BIBLIOTECA_DIR="${_TMP}/biblioteca"
export DEFAULT_BIBLIOTECA_ATUAL_DIR="${_TMP}/biblioteca_atual"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"
export DEFAULT_ENVIA_DIR="${_TMP}/envia"

PERM_DIR_SECURE=0755
DEFAULT_ZIP=zip
DEFAULT_UNZIP=unzip
DEFAULT_FIND="find"
CFG_VERSAOCLASS="01"
CFG_ACESSO_SSH="n"

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$DEFAULT_LOGS_DIR" \
    "$DEFAULT_BACKUP_DIR" "$DEFAULT_BASEBACKUP_DIR" "$DEFAULT_BIBLIOTECA_DIR" \
    "$DEFAULT_BIBLIOTECA_ATUAL_DIR" "$DEFAULT_PROGS_DIR" "$DEFAULT_PROGS_ATUAL_DIR" \
    "$DEFAULT_ENVIA_DIR"

# shellcheck source=../binarios/config.sh
. "${RAIZ_TESTE}/binarios/config.sh"

# Silencia a saida e captura a ultima mensagem de _erro.
_erro() { _ULTIMO_ERRO="${1:-}"; }
_aviso() { :; }
_ok() { :; }
_msg() { :; }
_exibir_mensagem_centralizada() { :; }
_exibir_mensagem_centralizada_a_esquerda() { :; }
_linha() { :; }
_meia_linha() { :; }
_aguardar() { :; }
_aguardar_tecla() { :; }
clear() { :; }

# Funcoes que podem NAO existir em versoes antigas do modulo (a prova de
# discriminacao roda a suite contra o codigo antigo): sem este fallback, o
# "command not found" aborta a suite no meio (set -e) em vez de virar uma
# verificacao falhando.
for _fn in _validar_config_file _var_ja_registrada _is_var_readonly _register_var \
           _configurar_diretorios _configurar_variaveis_sistema _validar_ssh \
           _limpar_estado_variaveis; do
    if ! command -v "$_fn" >/dev/null 2>&1; then
        eval "${_fn}() { return 127; }"
    fi
done

# ---------- _validar_config_file: a barreira do .config ----------#
# Regras do AGENTS.md: chave nova no .config nao pode comecar com "_" nem
# conter [ ` ; | & < > ( ) { } $ no valor.
_executar _validar_config_file "${_TMP}/nao_existe.config"
_checar "config: arquivo inexistente recusado" "1" "$RC"

printf 'CFG_EMPRESA=ACME\n' >"${_TMP}/ok.config"
_executar _validar_config_file "${_TMP}/ok.config"
_checar "config: arquivo valido aceito" "0" "$RC"

printf '# comentario\n\nCFG_EMPRESA=ACME\nCFG_BASE=/sav\n' >"${_TMP}/coment.config"
_executar _validar_config_file "${_TMP}/coment.config"
_checar "config: comentarios e linhas vazias aceitos" "0" "$RC"

printf 'CFG_EMPRESA=ACME\r\nCFG_BASE=/sav\r\n' >"${_TMP}/crlf.config"
_executar _validar_config_file "${_TMP}/crlf.config"
_checar "config: arquivo CRLF aceito" "0" "$RC"

printf 'CFG_EMPRESA = ACME\n' >"${_TMP}/espaco.config"
_executar _validar_config_file "${_TMP}/espaco.config"
# O identificador precisa estar COLADO no "=" (regex ^[A-Za-z_][A-Za-z0-9_]*=).
# O parser de constantes.sh usa a mesma regra, entao as duas passagens nao
# discordam: a linha e ignorada por ambas.
_checar "config: espaco antes do '=' RECUSADO" "1" "$RC"

# formato invalido (sem '=')
printf 'isto nao e atribuicao\n' >"${_TMP}/formato.config"
_executar _validar_config_file "${_TMP}/formato.config"
_checar "config: linha sem '=' recusada" "1" "$RC"

# caracteres perigosos no valor — conjunto documentado no AGENTS.md:
# [ ` ; | & < > ( ) { } $
for perigoso in ';' '|' '&' '$' '`' '<' '>' '(' ')' '{' '}'; do
    printf 'CFG_EMPRESA=ACME%s\n' "$perigoso" >"${_TMP}/perig.config"
    _executar _validar_config_file "${_TMP}/perig.config"
    _checar "config: valor com '${perigoso}' recusado" "1" "$RC"
done

# Aspas NAO fazem parte do conjunto bloqueado do .config (o valor so e
# atribuido com printf -v, nunca re-interpretado pelo shell). Este teste fixa
# a fronteira do contrato, que difere do conjunto mais amplo de
# utils.sh:_validar_caminho_seguro (que cobre caminho, nao valor de config).
printf 'CFG_EMPRESA=ACME"\n' >"${_TMP}/aspas.config"
_executar _validar_config_file "${_TMP}/aspas.config"
_checar "config: aspas duplas nao estao no conjunto bloqueado" "0" "$RC"

# arquivo acima de 1MB
head -c 1100000 /dev/zero | tr '\0' 'a' >"${_TMP}/grande.config"
_executar _validar_config_file "${_TMP}/grande.config"
_checar "config: arquivo acima de 1MB recusado" "1" "$RC"

# arquivo sem permissao de leitura
printf 'CFG_EMPRESA=ACME\n' >"${_TMP}/sem_leitura.config"
chmod 000 "${_TMP}/sem_leitura.config"
_executar _validar_config_file "${_TMP}/sem_leitura.config"
_checar "config: arquivo sem leitura recusado" "1" "$RC"
chmod 644 "${_TMP}/sem_leitura.config"

# ---------- _var_ja_registrada / _is_var_readonly / _register_var ----------#
_checar "registro: variavel desconhecida nao esta registrada" "1" \
    "$(_rc _var_ja_registrada "VAR_TESTE_NAO_EXISTE")"
_checar "registro: nome vazio nao esta registrado" "1" "$(_rc _var_ja_registrada "")"

VAR_TESTE="valor"
_executar _register_var "VAR_TESTE" "valor"
_checar "registro: variavel registrada" "0" "$(_rc _var_ja_registrada "VAR_TESTE")"
_checar "registro: valor definido" "valor" "$VAR_TESTE"

_executar _register_var "VAR_TESTE" "novo_valor"
_checar "registro: re-registro atualiza o valor" "novo_valor" "$VAR_TESTE"

_executar _register_var ""
_checar "registro: nome vazio recusado" "1" "$RC"

# variavel readonly nao pode ser alterada pelo registro
declare -r VAR_READONLY="fixo"
_checar "registro: variavel readonly detectada" "0" "$(_rc _is_var_readonly "VAR_READONLY")"
_checar "registro: variavel normal nao e readonly" "1" "$(_rc _is_var_readonly "VAR_TESTE")"
_executar _register_var "VAR_READONLY" "outro"
_checar "registro: readonly preservou o valor" "fixo" "$VAR_READONLY"

# ---------- _configurar_diretorios ----------#
# Cria os diretorios de trabalho via _garantir_diretorio (porta unica).
rm -rf "${DEFAULT_LOGS_DIR}"
_executar _configurar_diretorios
_checar "diretorios: criacao concluida" "0" "$RC"
_checar "diretorios: log criado" "sim" \
    "$([ -d "$DEFAULT_LOGS_DIR" ] && printf 'sim' || printf 'nao')"
_checar "diretorios: recepcao criada" "sim" \
    "$([ -d "$CFG_PORTALSAV" ] && printf 'sim' || printf 'nao')"

SCRIPT_DIR_SALVO="$SCRIPT_DIR"
SCRIPT_DIR="${_TMP}/script_inexistente"
_executar _configurar_diretorios
_checar "diretorios: SCRIPT_DIR inexistente recusado" "1" "$RC"
SCRIPT_DIR="$SCRIPT_DIR_SALVO"

# ---------- _configurar_variaveis_sistema ----------#
# Deriva E_EXEC/T_TELAS e os nomes SAVATU a partir de RAIZ e CFG_VERSAOCLASS.
E_EXEC=""
T_TELAS=""
SAVATU1=""
SAVATU2=""
SAVATU3=""
SAVATU=""
_executar _configurar_variaveis_sistema
_checar "variaveis: E_EXEC derivado" "${RAIZ}/classes" "${E_EXEC:-}"
_checar "variaveis: T_TELAS derivado" "${RAIZ}/tel_isc" "${T_TELAS:-}"
_checar "variaveis: compilado derivado" "-class01" "${compilado:-}"
_checar "variaveis: debugado derivado" "-mclass01" "${debugado:-}"
_checar "variaveis: SAVATU1 derivado" "tempSAV_IS01_classA_" "${SAVATU1:-}"
_checar "variaveis: SAVATU derivado" "tempSAV_IS01_*_" "${SAVATU:-}"

# ---------- _validar_ssh: so o caminho "n" (o "s" abriria conexao real) ----------#
CFG_ACESSO_SSH="x"
_executar _validar_ssh
_checar "ssh: valor desconhecido recusado" "1" "$RC"

CFG_ACESSO_SSH="n"
_executar _validar_ssh
_checar "ssh: acesso desabilitado aceito" "0" "$RC"

# ---------- _limpar_estado_variaveis: a higiene de fim de sessao ----------#
# As variaveis registradas e os caches internos somem; o resto permanece.
VAR_TESTE="valor"
_LOG_DIR_CACHE="${_TMP}/cache"
_JUTIL_PRONTO="1"
_executar _limpar_estado_variaveis
_checar "limpeza: variavel registrada removida" "" "${VAR_TESTE:-}"
_checar "limpeza: cache de log removido" "" "${_LOG_DIR_CACHE:-}"
_checar "limpeza: cache jutil removido" "" "${_JUTIL_PRONTO:-}"
_checar "limpeza: registro esvaziado" "0" "${#REGISTRO_VARIAVEIS[@]}"

# o shell do agente nao pode herdar os traps do sistema
trap - HUP INT TERM QUIT

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
