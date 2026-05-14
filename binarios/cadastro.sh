#!/usr/bin/env bash
#
# cadastro.sh - Programa de Cadastro de Usuario
# Permite cadastrar usuarios e senhas para o sistema SAV
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 13/05/2026-02
# Autor: Luiz Augusto
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
"." "${LIBS_DIR}/utils.sh" 2>/dev/null || { echo "Erro: utils.sh nao encontrado."; exit 1; }
"." "${LIBS_DIR}/auth.sh" 2>/dev/null || { echo "Erro: auth.sh nao encontrado."; exit 1; }

# Cores para o menu
        RED=$(tput bold)$(tput setaf 1)          # Vermelho
        GREEN=$(tput bold)$(tput setaf 2)        # Verde
        YELLOW=$(tput bold)$(tput setaf 3)       # Amarelo

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
        _mensagec "${YELLOW}" "0. Voltar"
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
            0)
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
