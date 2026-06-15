#!/usr/bin/env bash
#
# Atualiza.sh - Script de Atualizacao Modular do SISTEMA SAV
# Versao: 16/06/2026-01
# Autor: Luiz Augusto
# Os scripts de suporte devem estar no diretório binarios ao lado deste script.
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# Uso:
#   ./atualiza.sh                  - Executa o programa principal
#   ./atualiza.sh --setup          - Executa a configuracao inicial do sistema
#   ./atualiza.sh --setup --edit   - Edita as configuracoes existentes
#   ./atualiza.sh --cadastro       - Executa o cadastro de usuarios

# Configuracoes de seguranca para o script.
set -euo pipefail
export LC_ALL=C

# Verificacoes basicas
if [[ ! -t 0 && ! -p /dev/stdin ]]; then
    printf "%s\n" "Este script deve ser executado interativamente" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Diretorio do script atual

RLIBS_DIR="${SCRIPT_DIR}/libs"
# Chamar move_dir.sh para organizar diretórios após atualização
# Verificar se o diretório libs existe antes de executar
# CORRECAO: _mensagec nao esta disponivel aqui (utils.sh ainda nao foi carregado)
# Usar printf diretamente para mensagens neste ponto do script
    if [[ -d "${SCRIPT_DIR}/libs" && -f "${RLIBS_DIR}/move_dir.sh" ]]; then
        if bash "${RLIBS_DIR}/move_dir.sh"; then
            printf "%s\n" "Organizacao de diretorios concluida."
        else
            printf "%s\n" "AVISO: Falha ao organizar diretorios." >&2
        fi
    fi

# Diretorio do script SCRIPT_DIR

PLIBS_DIR="${SCRIPT_DIR}/binarios" # Diretorio das bibliotecas usadas pelo script

# Verifica se o diretorio binarios existe
if [[ ! -d "${PLIBS_DIR}" ]]; then
    printf "%s\n" "ERRO: Diretorio ${PLIBS_DIR} nao encontrado."
    exit 1
fi

export PLIBS_DIR SCRIPT_DIR
readonly PLIBS_DIR SCRIPT_DIR

# Processar argumentos
case "${1:-}" in
    --setup)
        if [[ -f "${PLIBS_DIR}/setup.sh" ]]; then
            printf "%s\n" "Carregando configurador..."
            "${PLIBS_DIR}/setup.sh" "${@:2}"
        else
            printf "%s\n" "ERRO: Arquivo ${PLIBS_DIR}/setup.sh nao encontrado."
            exit 1
        fi
        ;;
    --cadastro)
        if [[ -f "${PLIBS_DIR}/cadastro.sh" ]]; then
            printf "%s\n" "Carregando cadastro de usuarios..."
            "${PLIBS_DIR}/cadastro.sh" "${@:2}"
        else
            printf "%s\n" "ERRO: Arquivo ${PLIBS_DIR}/cadastro.sh nao encontrado."
            exit 1
        fi
        ;;
    "")
        # Verifica se o arquivo principal.sh existe
        if [[ -f "${PLIBS_DIR}/principal.sh" ]]; then
            printf "%s\n" "Carregando utilitario..."
            # Carrega o script principal
            cd "${PLIBS_DIR}" || exit 1
            "./principal.sh"
        else
            printf "%s\n" "ERRO: Arquivo ${PLIBS_DIR}/principal.sh nao encontrado."
            exit 1
        fi
        ;;
    *)
        printf "%s\n" "Uso: atualiza.sh [--setup | --cadastro]"
        exit 1
        ;;
esac