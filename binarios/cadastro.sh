#!/usr/bin/env bash
set -euo pipefail
#
# Funcao de saida padronizada (local, sem dependencia de modulos)
_encerrar_programa() {
    local status="${1:-0}"
    exit "$status"
}

#
# cadastro.sh - Programa de Cadastro de Usuario
# Permite cadastrar usuarios e senhas para o sistema SAV
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 10/07/2026-01
#
# Uso:
#   ./atualiza.sh --cadastro  - Chamada pelo atualiza.sh (recomendado)
#   ./cadastro.sh             - Chamada direta
#

# Variaveis globais esperadas
CFG_DIR="${CFG_DIR:-}"                 # Diretorio de configuracao
LIBS_DIR="${LIBS_DIR:-}"                 # Diretorio de modulos de biblioteca

# Diretorio do script (compativel com chamada direta ou via atualiza.sh)
# Quando chamado diretamente de /binarios, sobe um nivel para o diretorio do atualiza.sh
if [[ -z "${SCRIPT_DIR}" ]]; then
    _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Se estiver dentro de /binarios, o SCRIPT_DIR e o pai
    if [[ "$(basename "${_self_dir}")" == "binarios" ]]; then
        SCRIPT_DIR="$(dirname "${_self_dir}")"
    else
        SCRIPT_DIR="${_self_dir}"
    fi
    unset _self_dir
fi

# Diretorios dos modulos e configuracoes
LIBS_DIR="${LIBS_DIR:-${SCRIPT_DIR}/binarios}"
CFG_DIR="${CFG_DIR:-${SCRIPT_DIR}/configuracoes}"

# Carregar modulos necessarios
"." "${LIBS_DIR}/utils.sh" 2>/dev/null || { echo "Erro: utils.sh nao encontrado."; _encerrar_programa 1; }
"." "${LIBS_DIR}/auth.sh" 2>/dev/null || { echo "Erro: auth.sh nao encontrado."; _encerrar_programa 1; }

# Funcao principal
main() {
    while true; do
        _limpa_tela
        printf "\n"
        _linha "=" "${VERDE}"
        _mensagec "${VERMELHO}" "Cadastro de Usuario - Sistema SAV"
        _linha "=" "${VERDE}"
        printf "\n"
        _mensagec "${AMARELO}" "1. Cadastrar novo usuario"
        _mensagec "${AMARELO}" "2. Alterar senha de usuario"
        _mensagec "${AMARELO}" "0. Voltar"
        _linha "=" "${VERDE}"
        _mensagec "${VERDE}" "Digite o numero da opcao desejada e pressione ENTER."
        read -rp "Escolha uma opcao: " opcao

        case "$opcao" in
            1)
                printf "\n"
                _cadastrar_usuario
                printf "\n"
                read -rp "Pressione ENTER para continuar..." -t 5
                ;;
            2)
                printf "\n"
                _alterar_senha
                printf "\n"
                read -rp "Pressione ENTER para continuar..." -t 5
                ;;
            0)
                _limpa_tela
                printf '%s' "${NORMAL:-}"
                _encerrar_programa 0
                ;;
            *)
                _opinvalida
                _aguardar 1
                ;;
        esac
    done
}

# Executar
main "$@"
