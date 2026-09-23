#!/usr/bin/env bash
set -euo pipefail
#
# cadastro.sh - Programa de Cadastro de Usuario
# Permite cadastrar usuarios e senhas para o sistema SAV
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 24/09/2026
#
# Uso:
#   ./atualiza.sh --cadastro  - Chamada pelo atualiza.sh (recomendado)
#   ./binarios/cadastro.sh    - Chamada direta
#
# Nota: as funcoes de cadastro/login (_cadastrar_usuario, _alterar_senha,
# _hash_senha, ...) vivem em auth.sh. Este arquivo e apenas o ponto de
# entrada standalone: resolve os diretorios, carrega os modulos necessarios
# e exibe o menu. Nao duplicar funcoes do auth.sh aqui.
#

# Funcao de saida padronizada (local, sem dependencia de modulos)
_encerrar_programa() {
    local status="${1:-0}"
    exit "$status"
}

# Diretorio do script (compativel com chamada direta ou via atualiza.sh)
# Quando chamado diretamente de /binarios, sobe um nivel para o diretorio do atualiza.sh
if [[ -z "${SCRIPT_DIR:-}" ]]; then
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

# Log standalone: auth.sh registra eventos via _log; sem LOG_ATU definido o
# destino cairia em /dev/null (apenas ruido de AVISO). Aponta para logs/.
DEFAULT_LOGS_DIR="${DEFAULT_LOGS_DIR:-${SCRIPT_DIR}/logs}"
mkdir -p "${DEFAULT_LOGS_DIR}" 2>/dev/null || true
LOG_ATU="${LOG_ATU:-${DEFAULT_LOGS_DIR}/atualiza.$(date +"%Y-%m-%d").log}"

export SCRIPT_DIR LIBS_DIR CFG_DIR DEFAULT_LOGS_DIR LOG_ATU

# Garante o diretorio de configuracao antes de carregar o auth.sh,
# que avalia arquivo_senhas="${CFG_DIR}/.senhas" no momento do source
if [[ ! -d "${CFG_DIR}" ]]; then
    mkdir -p "${CFG_DIR}" 2>/dev/null || {
        echo "Erro: nao foi possivel criar o diretorio '${CFG_DIR}'." >&2
        _encerrar_programa 1
    }
fi

# Cores com fallback vazio: no modo standalone o config.sh nao e carregado,
# e as funcoes de tela usam "${VERMELHO}" etc. Sem o default, o set -u
# abortaria na primeira expansao. Definir antes de carregar os modulos.
: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

# Carregar modulos necessarios (auth.sh traz _cadastrar_usuario/_alterar_senha)
"." "${LIBS_DIR}/utils.sh" 2>/dev/null || { echo "Erro: utils.sh nao encontrado."; _encerrar_programa 1; }
"." "${LIBS_DIR}/auth.sh" 2>/dev/null || { echo "Erro: auth.sh nao encontrado."; _encerrar_programa 1; }

# Funcao principal
main() {
    while true; do
        clear 2>/dev/null || true
        printf "\n"
        _linha "=" "${VERDE:-}"
        _exibir_mensagem_centralizada "${VERMELHO:-}" "Cadastro de Usuario - Sistema SAV"
        _linha "=" "${VERDE:-}"
        printf "\n"
        _exibir_mensagem_centralizada "${AMARELO:-}" "1. Cadastrar novo usuario"
        _exibir_mensagem_centralizada "${AMARELO:-}" "2. Alterar senha de usuario"
        _exibir_mensagem_centralizada "${AMARELO:-}" "0. Voltar"
        _linha "=" "${VERDE:-}"
        _exibir_mensagem_centralizada "${VERDE:-}" "Digite o numero da opcao desejada e pressione ENTER."
        read -rp "Escolha uma opcao: " opcao || opcao=""

        case "$opcao" in
            1)
                printf "\n"
                _cadastrar_usuario || true
                printf "\n"
                read -rp "Pressione ENTER para continuar..." -t 5 || true
                ;;
            2)
                printf "\n"
                _alterar_senha || true
                printf "\n"
                read -rp "Pressione ENTER para continuar..." -t 5 || true
                ;;
            0)
                clear 2>/dev/null || true
                printf '%s' "${NORMAL:-}"
                _encerrar_programa 0
                ;;
            *)
                _opinvalida
                _aguardar 1 || true
                ;;
        esac
    done
}

# Executar
main "$@"
