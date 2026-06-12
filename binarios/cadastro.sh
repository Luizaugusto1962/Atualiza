#!/usr/bin/env bash
#
# cadastro.sh - Programa de Cadastro de Usuario
# Permite cadastrar usuarios e senhas para o sistema SAV
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 12/06/2026-01
# Autor: Luiz Augusto
#
# Uso:
#   ./atualiza.sh --cadastro  - Chamada pelo atualiza.sh (recomendado)
#   ./cadastro.sh             - Chamada direta
#
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

# Carregar constantes do sistema
if [[ -f "${LIBS_DIR}/constantes.sh" ]]; then
    "." "${LIBS_DIR}/constantes.sh"
fi

# Carregar modulos necessarios
"." "${LIBS_DIR}/config.sh" 2>/dev/null || { echo "Erro: config.sh nao encontrado."; exit 1; }
"." "${LIBS_DIR}/utils.sh" 2>/dev/null || { echo "Erro: utils.sh nao encontrado."; exit 1; }
"." "${LIBS_DIR}/auth.sh" 2>/dev/null || { echo "Erro: auth.sh nao encontrado."; exit 1; }

# Cores (definidas uma vez para evitar subshells repetidos)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"
    GREEN="${BOLD}$(tput setaf 2)"
    YELLOW="${BOLD}$(tput setaf 3)"
    RED="${BOLD}$(tput setaf 1)"
else
    BOLD="" GREEN="" YELLOW="" RED="" 
fi
# Funcao principal
main() {
    while true; do
        _limpa_tela
        printf "\n"
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Cadastro de Usuario - Sistema SAV"
        _linha "=" "${GREEN}"
        printf "\n"
        _mensagec "${YELLOW}" "1. Cadastrar novo usuario"
        _mensagec "${YELLOW}" "2. Alterar senha de usuario"
        _mensagec "${YELLOW}" "9. Sair"
        _linha "=" "${GREEN}"
        _mensagec "${GREEN}" "Digite o numero da opcao desejada e pressione ENTER." 
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
            9)
                _limpa_tela
                tput sgr0
                exit 0
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
