#!/usr/bin/env bash
#
# Atualiza.sh - Script de Atualizacao Modular do SISTEMA SAV
# Versao: 14/10/2026
# Autor: Luiz Augusto
# Os scripts de suporte devem estar no diretório binarios ao lado deste script.
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# Uso:
#   ./atualiza.sh                  - Executa o programa principal
#   ./atualiza.sh --setup          - Executa a configuracao inicial do sistema
#   ./atualiza.sh --setup --edit   - Edita as configuracoes existentes
#   ./atualiza.sh --cadastro       - Executa o cadastro de usuarios
#   ./atualiza.sh --help           - Exibe esta ajuda
#
# Este arquivo e somente o entry point: ele executa (nunca faz source) o alvo
# escolhido na tabela ALVO, repassando os argumentos restantes intactos.

# Configuracoes de seguranca para o script.
set -euo pipefail
export LC_ALL=C

# Bash 4.0+ e requerido por causa de `declare -A` (arrays associativos), usado
# na tabela de dispatch mais abaixo e tambem nos modulos em binarios/.
if (( BASH_VERSINFO[0] < 4 )); then
    printf "Erro: Bash 4.0+ requerido (versao atual: %s).\n" "${BASH_VERSION}" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Diretorio do script atual

# Diretorio das bibliotecas usadas pelo script. O nome e LIBS_DIR - e nao
# PLIBS_DIR - porque e o que principal.sh, cadastro.sh, setup.sh e o restante do
# sistema esperam; antes este script exportava um nome que ninguem lia.
LIBS_DIR="${SCRIPT_DIR}/binarios"

export SCRIPT_DIR LIBS_DIR
readonly SCRIPT_DIR LIBS_DIR

# Verifica se o diretorio binarios existe
if [[ ! -d "${LIBS_DIR}" ]]; then
    printf "ERRO: Diretorio %s nao encontrado.\n" "${LIBS_DIR}" >&2
    exit 1
fi

# Exibe o uso do programa.
_uso() {
    printf "%s\n" "Uso: atualiza.sh [--setup [--edit] | --cadastro | --help]"
    printf "\n"
    printf "%s\n" "  (sem argumento)   Executa o programa principal"
    printf "%s\n" "  --setup           Executa a configuracao inicial do sistema"
    printf "%s\n" "  --setup --edit    Edita as configuracoes existentes"
    printf "%s\n" "  --cadastro        Executa o cadastro de usuarios"
    printf "%s\n" "  --help            Exibe esta ajuda"
}

# Rotina: se existir o programa instalador.sh no diretorio, exclua-o.
# Fica depois das validacoes de diretorio e de argumentos de proposito: antes
# disso, uma invocacao invalida apagava o arquivo e so depois falhava.
_remover_instalador_legado() {
    local legado="${SCRIPT_DIR}/instalador.sh"
    if [[ -f "${legado}" ]]; then
        rm -f "${legado}"
        printf "Aviso: instalador.sh legado removido em %s.\n" "${legado}"
    fi
}

# Processar argumentos. A tabela ALVO mapeia a opcao para o par
# "<script em binarios>|<mensagem de carregamento>"; o `case` cobre apenas as
# opcoes que nao tem alvo. A execucao vem depois das verificacoes, para que
# nada seja apagado ou criado antes de a chamada ter sido considerada valida.
#
# "@padrao" e o sentinela da invocacao sem argumento: array associativo nao
# aceita chave vazia (bash responde "bad array subscript"), e o prefixo "@"
# nao colide com opcao real, que comeca com "--".
declare -A ALVO=(
    ["@padrao"]="principal.sh|Carregando utilitario..."
    ["--setup"]="setup.sh|Carregando configurador..."
    ["--cadastro"]="cadastro.sh|Carregando cadastro de usuarios..."
)

CHAVE="${1:-}"

case "${CHAVE}" in
    -h | --help)
        _uso
        exit 0
        ;;
esac

# O ":-" interno faz a invocacao sem argumento cair no sentinela; o ":-"
# externo e obrigatorio, porque chave ausente em array associativo aborta o
# script sob set -u. Juntas as duas formas tambem neutralizam entrada do
# usuario como "]" ou "$(id)", que retornam vazio em vez de expandir.
REGISTRO="${ALVO[${CHAVE:-@padrao}]:-}"

if [[ -z "${REGISTRO}" ]]; then
    printf "ERRO: Opcao invalida: %s\n" "${CHAVE}" >&2
    _uso >&2
    exit 2
fi

ALVO_SCRIPT="${LIBS_DIR}/${REGISTRO%%|*}"
ALVO_ROTULO="${REGISTRO#*|}"

# Verificacao basica: os tres alvos sao interativos (menus e leituras de tela).
# `--help` ja retornou acima e nao e afetado por esta regra.
if [[ ! -t 0 && ! -p /dev/stdin ]]; then
    printf "%s\n" "Este script deve ser executado interativamente" >&2
    exit 1
fi

# Verifica se o arquivo alvo existe
if [[ ! -f "${ALVO_SCRIPT}" ]]; then
    printf "ERRO: Arquivo %s nao encontrado.\n" "${ALVO_SCRIPT}" >&2
    exit 1
fi

_remover_instalador_legado

printf "%s\n" "${ALVO_ROTULO}"

# exec troca este processo pelo alvo: um processo a menos, e sinal e codigo de
# saida vao direto para o programa em vez de passar por este wrapper. O alvo
# instala os proprios traps, entao nada se perde com a troca.
exec "${ALVO_SCRIPT}" "${@:2}"
