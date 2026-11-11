#!/usr/bin/env bash
#
# testes/run_all.sh - roda todas as suites de testes/ e resume o resultado
#
# Cada suite e um script isolado, sem TTY e sem rede, que faz `source` do
# modulo sob teste com stubs. Este runner apenas as executa em sequencia e
# consolida o resultado — nao substitui nenhuma delas.
#
# Uso:
#   bash testes/run_all.sh            # resumo (padrao)
#   bash testes/run_all.sh -v         # mostra a saida completa de cada suite
#   bash testes/run_all.sh -o         # mostra so as suites que falharam
#   bash testes/run_all.sh -k utils   # roda so as suites cujo nome casa com "utils"
#
# Saida: 0 se todas as suites passaram, 1 se alguma falhou.
#
# NOTA sobre `set -e`: este runner NAO usa -e de proposito — o objetivo e
# rodar TODAS as suites mesmo quando uma falha, para o relatorio mostrar o
# estado completo em vez de parar no primeiro problema.
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

set -uo pipefail

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

modo="resumo"
filtro=""

while (( $# > 0 )); do
    case "$1" in
        -v | --verbose) modo="completo" ;;
        -o | --only-failures) modo="falhas" ;;
        -k | --filter)
            shift
            filtro="${1:-}"
            ;;
        -h | --help)
            sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'Opcao desconhecida: %s (use --help)\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

# Suites do repo: uma por modulo, mais o harness de carga.
SUITES=()
while IFS= read -r s; do
    SUITES+=("$s")
done < <(find "${RAIZ_TESTE}/testes" -maxdepth 1 -name 'test_*.sh' -type f | sort)

if ((${#SUITES[@]} == 0)); then
    printf 'Nenhuma suite encontrada em %s/testes\n' "$RAIZ_TESTE" >&2
    exit 2
fi

total_ok=0
total_falhas=0
total_suites=0
suites_com_falha=0
falha_global=0
declare -a RESUMO=()
declare -a DETALHES=()

printf 'Rodando %d suite(s) de %s/testes\n\n' "${#SUITES[@]}" "$RAIZ_TESTE"

for suite in "${SUITES[@]}"; do
    nome="$(basename "$suite")"
    if [[ -n "$filtro" && "$nome" != *"$filtro"* ]]; then
        continue
    fi
    total_suites=$((total_suites + 1))

    saida="$(bash "$suite" 2>&1)"
    rc=$?

    n_ok="$(printf '%s\n' "$saida" | grep -c '^ok    - ')"
    n_falha="$(printf '%s\n' "$saida" | grep -c '^FALHA - ')"
    # suite sem o prefixo "ok    - " (as duas mais antigas): conta pelo resumo
    if ((n_ok == 0 && n_falha == 0)); then
        n_ok="$(printf '%s\n' "$saida" | grep -c '^ok *- ')"
    fi

    total_ok=$((total_ok + n_ok))
    total_falhas=$((total_falhas + n_falha))

    if ((rc == 0)); then
        status="ok"
    else
        status="FALHOU"
        suites_com_falha=$((suites_com_falha + 1))
        falha_global=1
    fi

    RESUMO+=("$(printf '%-22s exit=%-3s %-6s %3d ok  %3d falha' \
        "$nome" "$rc" "$status" "$n_ok" "$n_falha")")

    if ((n_falha > 0)); then
        while IFS= read -r linha; do
            DETALHES+=("  ${nome}: ${linha}")
        done < <(printf '%s\n' "$saida" | grep -E '^FALHA - ' | sed 's/^FALHA - //')
    fi

    case "$modo" in
        completo) printf '%s\n' "$saida" ;;
        falhas)
            if ((rc != 0)); then
                printf '%s\n' "$saida"
            fi
            ;;
    esac
done

printf '\n==================================================\n'
printf 'RESUMO POR SUITE\n'
printf '%s\n' "${RESUMO[@]}"
printf '==================================================\n'

if ((${#DETALHES[@]} > 0)); then
    printf '\nFALHAS DETALHADAS\n'
    printf '%s\n' "${DETALHES[@]}"
fi

printf '\n%d suite(s), %d verificacao(oes) ok, %d falha(s)' \
    "$total_suites" "$total_ok" "$total_falhas"
if ((suites_com_falha > 0)); then
    printf ', %d suite(s) com falha\n' "$suites_com_falha"
else
    printf '\n'
fi

exit "$falha_global"
