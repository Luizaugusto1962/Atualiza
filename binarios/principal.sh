#!/usr/bin/env bash
set -euo pipefail
#
# SISTEMA SAV - Script de Atualizacao Modular
# principal.sh - Ponto de entrada e inicializacao do sistema
# Padrões e regras de desenvolvimento: ver AGENTS.md
# Versao: 14/08/2026-01
# Autor: Luiz Augusto
# Email: luizaugusto@sav.com.br
#
# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================
# Ativa tratamento rigoroso de erros
# -e: Sai imediatamente se um comando falhar
# -u: Trata variáveis não definidas como erro
# -o pipefail: Faz o pipeline retornar o status do último comando que falhou
umask 077  # Garante que arquivos criados sejam legíveis apenas pelo dono

# =============================================================================
# DIRETÓRIOS DO SCRIPT
# =============================================================================

# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

## Carregar constantes do sistema
# Diretorios dos modulos e configuracoes
LIBS_DIR="${LIBS_DIR:-${SCRIPT_DIR}/binarios}"                           # Diretorio dos modulos de biblioteca
CFG_DIR="${CFG_DIR:-${SCRIPT_DIR}/configuracoes}"                        # Diretorio de configuracoes
PERM_DIR_SECURE="${PERM_DIR_SECURE:-0755}"                               # Diretórios seguros (rwxr-xr-x)

export SCRIPT_DIR LIBS_DIR CFG_DIR PERM_DIR_SECURE

# =============================================================================
# VERSAO DO SISTEMA
# =============================================================================
declare -rx UPDATE="17/08/26-v.1"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

# Cria diretorio com permissoes seguras (funcao centralizada e melhorada)
# Parametros: $1=caminho $2=permissao(opcional, padrao=PERM_DIR_SECURE) $3=log_dir(opcional)
# Retorna: 0 se sucesso, 1 se erro
_criar_diretorio_seguro() {
    local caminho="${1:-}"
    local permissao="${2:-${PERM_DIR_SECURE}}"
    local log_dir="${3:-}"

    # Validar caminho
    if [[ -z "$caminho" ]] || [[ "$caminho" == "/" ]] || [[ "$caminho" == "//" ]]; then
        printf "ERRO: Caminho invalido ou inseguro: %s\n" "$caminho" >&2
        return 1
    fi

    # Se ja existe, verificar se e diretorio
    if [[ -e "$caminho" ]]; then
        if [[ -d "$caminho" ]]; then
            return 0
        else
            printf "Erro: Caminho existe mas nao e diretorio: %s\n" "$caminho" >&2
            return 1
        fi
    fi

    # Criar diretorio
    if mkdir -p "$caminho" 2>/dev/null; then
        # Ajustar permissoes
        if chmod "$permissao" "$caminho" 2>/dev/null; then
            # Log opcional
            if [[ -n "$log_dir" ]] && command -v _log >/dev/null 2>&1; then
                _log "Diretorio criado: $caminho (permissao: $permissao)" "$log_dir" 2>/dev/null || true
            fi
            return 0
        else
            printf "AVISO: Nao foi possivel ajustar permissao em '%s'.\n" "$caminho" >&2
            return 1
        fi
    else
        printf "Erro: Nao foi possivel criar o diretorio '%s'.\n" "$caminho" >&2
        return 1
    fi
}

# =============================================================================
# INICIALIZAÇÃO DE DIRETÓRIOS
# =============================================================================

# Lista de diretórios obrigatórios
declare -a AUX_DIRS=("${LIBS_DIR}" "${CFG_DIR}")

for dir in "${AUX_DIRS[@]}"; do
    # Verificar se a variável está definida
    if [[ -z "${dir}" ]]; then
        printf "Erro: Variavel de diretorio nao definida.\n" >&2
        _encerrar_programa 1
    fi

    # Criar diretório caso não exista com permissões seguras
    if [[ ! -d "${dir}" ]]; then
        if ! _criar_diretorio_seguro "${dir}" "${PERM_DIR_SECURE}"; then
                printf "Erro: Nao foi possivel criar o diretorio '%s'.\n" "${dir}" >&2
            _encerrar_programa 1
        fi
    fi

    # APLICAR PERMISSOES DE FORMA SEGURA: usar constante ao inves de hardcoded
    # Recursivo apenas quando necessario, e com permissao segura
    chmod "${PERM_DIR_SECURE}" "${dir}" 2>/dev/null || {
        printf "AVISO: Nao foi possivel ajustar permissao em '%s'.\n" "${dir}" >&2
        printf "Certifique-se de que o usuario atual tem permissao para acessar e modificar este diretorio.\n" >&2
        printf "Execute como root ou sudo ...\n" >&2
        _encerrar_programa 1
    }

    # Verificar se o diretório existe após criação
    [[ -d "${dir}" ]] || {
        printf "Erro: O diretorio '%s' nao foi encontrado.\n" "${dir}" >&2
        printf "Certifique-se de que os arquivos/modulos correspondentes estao instalados corretamente.\n" >&2
        _encerrar_programa 1
    }
done

# =============================================================================
# CARREGAMENTO DE MÓDULOS (ESCOPO GLOBAL)
# IMPORTANTE: o carregamento acontece aqui no escopo global, fora de funcoes.
# Os modulos usam `declare -a/-A` no topo do arquivo; se o `source` rodar dentro
# de uma funcao, essas variaveis viram locais e sao perdidas ao retornar. Usar
# `declare -g` resolveria, mas exige Bash >= 4.2 e quebra em servidores antigos
# (Ubuntu 10.04/12.04). Por isso o `source` precisa estar neste escopo.
# =============================================================================

declare -a MODULOS_CARREGAR=(
    "constantes.sh" # Constantes do Sistema SAV
    "config.sh"     # Configuracoes
    "utils.sh"      # Utilitarios basicos primeiro
    "auth.sh"       # Autenticacao
    "lembrete.sh"   # Sistema de lembretes
    "vaievem.sh"    # Operacoes de rede
    "sistema.sh"    # Informacoes do sistema
    "baixar.sh"     # Funcionalidades de download
    "arquivos.sh"   # Gestao de arquivos
    "backup.sh"     # Sistema de backup
    "programas.sh"  # Gestao de programas
    "biblioteca.sh" # Gestao de biblioteca
    "help.sh"       # Sistema de ajuda
    "variaveis.sh"  # Consulta de variaveis/constantes
    "menus.sh"      # Modulos de Menu
)

declare -a ERROS_MODULOS=()

for _modulo in "${MODULOS_CARREGAR[@]}"; do
    _modulo_caminho="${LIBS_DIR}/${_modulo}"

    # Verificar se o arquivo existe
    if [[ ! -f "${_modulo_caminho}" ]]; then
        printf "ERRO: Modulo '%s' nao encontrado em '%s'\n" "${_modulo}" "${LIBS_DIR}" >&2
        ERROS_MODULOS+=("${_modulo}")
        continue
    fi

    # Verificar se o arquivo pode ser lido
    if [[ ! -r "${_modulo_caminho}" ]]; then
        printf "ERRO: Modulo '%s' nao pode ser lido\n" "${_modulo}" >&2
        ERROS_MODULOS+=("${_modulo}")
        continue
    fi

    # Verificar se o arquivo não está vazio
    if [[ ! -s "${_modulo_caminho}" ]]; then
        printf "ERRO: Modulo '%s' esta vazio\n" "${_modulo}" >&2
        ERROS_MODULOS+=("${_modulo}")
        continue
    fi

    # Carregar o módulo (source em escopo global)
    if ! source "${_modulo_caminho}"; then
        printf "ERRO: Falha ao carregar modulo '%s'\n" "${_modulo}" >&2
        ERROS_MODULOS+=("${_modulo}")
        continue
    fi
done

unset _modulo _modulo_caminho

if (( ${#ERROS_MODULOS[@]} > 0 )); then
    printf "ERRO: %d modulo(s) falharam ao carregar.\n" "${#ERROS_MODULOS[@]}" >&2
    for _m in "${ERROS_MODULOS[@]}"; do
        printf "  - %s\n" "${_m}" >&2
    done
    unset MODULOS_CARREGAR ERROS_MODULOS
    exit 1
fi

unset MODULOS_CARREGAR ERROS_MODULOS

# =============================================================================
# INICIALIZAÇÃO DO SISTEMA
# -----------------------------------------------------------------------------
# Inicializa o sistema carregando configurações e validando ambiente
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_inicializar_sistema() {

    # Modulos ja foram carregados no escopo global (ver CARREGAMENTO DE MODULOS)

    # Inicializar sistema de gerenciamento de variáveis
    if command -v _inicializar_sistema_variaveis >/dev/null 2>&1; then
        _inicializar_sistema_variaveis
    fi

    # Carregar e validar configuracoes
    if ! _carregar_configuracoes; then
        _erro "Falha ao carregar configuracoes." >&2
        return 1
    fi

    # Verificar dependências (agora retorna erro ao inves de sair)
    if ! _check_instalado; then
        _erro "Dependencias nao atendidas." >&2
        return 1
    fi

     # Configurar ambiente
    _configurar_ambiente

    # Executar limpeza automatica diaria
    _executar_expurgador_diario

    # Configura acesso SSH se necessario
    _validar_ssh

    return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================
# Função principal do programa
# -----------------------------------------------------------------------------
_main() {
    # Tratamento de sinais para limpeza
    trap '_resetando' EXIT
    trap '_encerrar_programa 130' INT TERM
    trap '_encerrar_programa 1' HUP

    # Inicializar sistema
    if ! _inicializar_sistema; then
        _erro "Falha na inicializacao do sistema. Saindo..." >&2
        _encerrar_programa 1
    fi

    # Autenticacao
    if ! _login; then
        _erro "Autenticacao falhou. Saindo..." >&2
        _encerrar_programa 1
    fi

    # Mostrar mensagem de entrada (se existe) e opcao para excluir
    if command -v _mostrar_aviso >/dev/null 2>&1; then
        _mostrar_aviso
    fi

    # Mostrar notas se existirem
    if command -v _mostrar_notas_iniciais >/dev/null 2>&1; then
        _mostrar_notas_iniciais
    fi

    # Executar menu principal
    if command -v _principal >/dev/null 2>&1; then
        _principal
    else
        _erro "Menu principal nao encontrado." >&2
        _encerrar_programa 1
    fi

    # Finalizar sistema de variáveis (limpeza explícita)
    if command -v _finalizar_sistema >/dev/null 2>&1; then
        _finalizar_sistema
    fi
}

# =============================================================================
# EXECUÇÃO DO SCRIPT
# =============================================================================

# Verificar se esta sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi
