#!/usr/bin/env bash
set -euo pipefail
#
# testes/test_sistema.sh - verificacoes isoladas de binarios/sistema.sh
#
# O repo nao tem suite de testes; este arquivo cobre apenas a logica pura que
# nao da para observar pelo menu (parser do .versao e extracao do IP interno).
# Rodar direto, sem TTY:
#   bash testes/test_sistema.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# sistema.sh e sourced (nunca executado) e liga o strict mode neste shell.
# shellcheck source=../binarios/sistema.sh
. "${RAIZ_TESTE}/binarios/sistema.sh"

falhas=0
_checar() { # _checar <descricao> <esperado> <obtido>
    if [[ "$2" == "$3" ]]; then
        printf 'ok    - %s\n' "$1"
    else
        printf 'FALHA - %s\n         esperado: [%s]\n         obtido:   [%s]\n' "$1" "$2" "$3"
        falhas=$((falhas + 1))
    fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

#---------- _carregar_versao_seguro: whitelist estrita ----------#
printf 'VERSAO=2026\nVERSAOANT="2025"\nPATH=/tmp/evil\nHOME=/tmp/evil\n' >"${tmpdir}/.versao"
printf 'VERSAO=2027' >"${tmpdir}/.versao_sem_nova_linha"

unset VERSAO VERSAOANT || true
PATH_ANTES="$PATH"
HOME_ANTES="$HOME"

_carregar_versao_seguro "${tmpdir}/.versao"
_checar "whitelist: VERSAO parseada" "2026" "${VERSAO:-}"
_checar "whitelist: VERSAOANT sem aspas" "2025" "${VERSAOANT:-}"
_checar "whitelist: PATH nao sobrescrito" "$PATH_ANTES" "$PATH"
_checar "whitelist: HOME nao sobrescrito" "$HOME_ANTES" "$HOME"

_carregar_versao_seguro "${tmpdir}/.versao_sem_nova_linha"
_checar "whitelist: arquivo sem newline final" "2027" "${VERSAO:-}"

# Guard: entrada invalida precisa retornar 1, nao abortar o shell (set -e).
rc=0
_carregar_versao_seguro "" || rc=$?
_checar "guard: argumento vazio retorna 1" "1" "$rc"

rc=0
_carregar_versao_seguro "${tmpdir}/nao_existe" || rc=$?
_checar "guard: arquivo inexistente retorna 1" "1" "$rc"

#---------- Extracao do IP interno (o campo apos "src") ----------#
_extrair_src() {
    awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
}

_checar "ip: rota com gateway" "192.168.0.10" \
    "$(printf '%s\n' '1.0.0.0 via 192.168.0.1 dev eth0 src 192.168.0.10 uid 0' | _extrair_src)"
_checar "ip: rota direta (antes devolvia 'uid')" "127.0.0.1" \
    "$(printf '%s\n' 'local 127.0.0.1 dev lo src 127.0.0.1 uid 1000' | _extrair_src)"
_checar "ip: rota sem src" "" \
    "$(printf '%s\n' 'blackhole 203.0.113.0/24 proto static' | _extrair_src)"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram\n'