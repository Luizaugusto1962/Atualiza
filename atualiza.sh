#!/usr/bin/env bash
#
# Atualiza.sh - Script de Atualizacao Modular do SISTEMA SAV
# Versao: 21/10/2026
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
# escolhido na tabela ALVO. Argumentos extras so passam na whitelist de cada
# alvo (--setup aceita --edit; os demais nao aceitam extras).

# Configuracoes de seguranca para o script.
set -euo pipefail
export LC_ALL=C
IFS=$' \t\n'
unset CDPATH BASH_ENV ENV
# Prefixar diretorios de sistema: um PATH envenenado nao deve vencer dirname/rm
# / find. Concatenar o PATH original preserva java/IsCOBOL em Ubuntu legado.
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:${PATH}}"
export PATH
hash -r
umask 077

# Bash 4.0+ e requerido por causa de `declare -A` (arrays associativos), usado
# na tabela de dispatch mais abaixo e tambem nos modulos em binarios/.
if (( BASH_VERSINFO[0] < 4 )); then
    printf "Erro: Bash 4.0+ requerido (versao atual: %s).\n" "${BASH_VERSION}" >&2
    exit 1
fi

# cd -P / pwd -P: caminho canonico, imune a CDPATH e a symlink no caminho.
_origem="${BASH_SOURCE[0]}"
if [[ "${_origem}" != /* ]]; then
    _origem="${PWD}/${_origem}"
fi
_dir_origem="${_origem%/*}"
[[ -n "${_dir_origem}" ]] || _dir_origem="/"
SCRIPT_DIR="$(cd -P -- "${_dir_origem}" && pwd -P)"
unset _origem _dir_origem

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

# True se others tem bit de escrita (world-writable). Nao usa -w: -w e
# verdadeiro para o dono mesmo com modo 0700.
_gravavel_por_outros() {
    [[ -n "$(find "$1" -maxdepth 0 -perm -0002 -print)" ]]
}

# WSL/9p, CIFS e NTFS reportam 0777 para tudo: abortar ali tornaria o
# programa inutil no desenvolvimento. No ext4/xfs do servidor legado a
# checagem continua obrigatoria.
_fs_ignora_modo() {
    local tipo
    tipo="$(stat -f -c '%T' "$1" 2>/dev/null || true)"
    case "${tipo}" in
        v9fs | 9p | drvfs | cifs | smb2 | fuseblk | fuse | ntfs | msdos | fat | vfat | exfat)
            return 0
            ;;
    esac
    return 1
}

# Rotina: se existir o programa instalador.sh no diretorio, exclua-o.
# Fica depois das validacoes de diretorio e de argumentos de proposito: antes
# disso, uma invocacao invalida apagava o arquivo e so depois falhava.
# Recusa symlink e arquivo de outro dono (diretorio compartilhado).
_remover_instalador_legado() {
    local legado="${SCRIPT_DIR}/instalador.sh"
    if [[ -L "${legado}" ]]; then
        printf "Aviso: instalador.sh e symlink; nao removido.\n" >&2
        return 0
    fi
    if [[ -f "${legado}" ]]; then
        if [[ ! -O "${legado}" ]]; then
            printf "Aviso: instalador.sh nao pertence a este usuario; nao removido.\n" >&2
            return 0
        fi
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
        if [[ $# -gt 1 ]]; then
            printf "ERRO: --help nao aceita argumentos extras.\n" >&2
            _uso >&2
            exit 2
        fi
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

# Whitelist de argv: --setup aceita no maximo --edit; os outros alvos, nada.
case "${CHAVE:-@padrao}" in
    --setup)
        if [[ $# -gt 2 ]] || { [[ $# -eq 2 ]] && [[ "${2}" != "--edit" ]]; }; then
            printf "ERRO: Opcao invalida para --setup: %s\n" "${2:-}" >&2
            _uso >&2
            exit 2
        fi
        ;;
    --cadastro)
        if [[ $# -ne 1 ]]; then
            printf "ERRO: --cadastro nao aceita argumentos extras.\n" >&2
            _uso >&2
            exit 2
        fi
        ;;
    *)
        if [[ $# -ne 0 ]]; then
            printf "ERRO: Opcao invalida: %s\n" "${CHAVE}" >&2
            _uso >&2
            exit 2
        fi
        ;;
esac

ALVO_SCRIPT="${LIBS_DIR}/${REGISTRO%%|*}"
ALVO_ROTULO="${REGISTRO#*|}"

# Verificacao basica: os tres alvos sao interativos (menus e leituras de tela).
# `--help` ja retornou acima e nao e afetado por esta regra.
if [[ ! -t 0 && ! -p /dev/stdin ]]; then
    printf "%s\n" "Este script deve ser executado interativamente" >&2
    exit 1
fi

# Alvo: arquivo regular, executavel, sem symlink, sem escrita para others.
if [[ -L "${ALVO_SCRIPT}" ]]; then
    printf "ERRO: Arquivo alvo nao pode ser symlink: %s.\n" "${ALVO_SCRIPT}" >&2
    exit 1
fi
if [[ ! -f "${ALVO_SCRIPT}" || ! -x "${ALVO_SCRIPT}" ]]; then
    printf "ERRO: Arquivo %s nao encontrado ou sem permissao de execucao.\n" "${ALVO_SCRIPT}" >&2
    exit 1
fi
if _gravavel_por_outros "${LIBS_DIR}" || _gravavel_por_outros "${ALVO_SCRIPT}"; then
    if _fs_ignora_modo "${LIBS_DIR}"; then
        printf "Aviso: filesystem ignora modo unix; checagem de escrita por outros omitida.\n" >&2
    else
        printf "ERRO: %s ou o alvo sao gravaveis por outros.\n" "${LIBS_DIR}" >&2
        exit 1
    fi
fi

_remover_instalador_legado

if [[ -t 1 ]]; then
    printf "%s\n" "${ALVO_ROTULO}"
fi

# exec troca este processo pelo alvo: um processo a menos, e sinal e codigo de
# saida vao direto para o programa em vez de passar por este wrapper. O alvo
# instala os proprios traps, entao nada se perde com a troca.
exec "${ALVO_SCRIPT}" "${@:2}"
