#!/usr/bin/env bash
#
# SISTEMA SAV - Script de Atualizacao Modular
# principal.sh - Ponto de entrada e inicializacao do sistema
# Padroes e regras de desenvolvimento: ver AGENTS.md
# Versao: 28/04/2026-01
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
set -euo pipefail

# =============================================================================
# VERSAO DO SISTEMA
# =============================================================================
declare -rx UPDATE="30/04/26-v.1"

# =============================================================================
# DIRETÓRIOS DO SCRIPT
# =============================================================================

# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

## Carregar constantes do sistema
# Diretorios dos modulos e configuracoes
lib_dir="${lib_dir:-${SCRIPT_DIR}/libs}"       # Diretorio dos modulos de biblioteca
cfg_dir="${cfg_dir:-${SCRIPT_DIR}/cfg}"        # Diretorio de configuracoes
export SCRIPT_DIR lib_dir cfg_dir

# =============================================================================
# CARREGAR CONSTANTES DO SISTEMA
# =============================================================================
# Carregar constantes se disponivel
if [[ -f "${lib_dir}/constantes.sh" ]]; then
    # shellcheck source=constantes.sh
    "." "${lib_dir}/constantes.sh"
fi

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

# Configurar tratamento de sinais e limpeza
_configurar_ambiente_seguro() {
    # Carregar funcoes de trap se disponivel
    if command -v _setup_traps >/dev/null 2>&1; then
        _setup_traps
    fi
    
    # Configurar umask seguro
    umask 0022
    
    # Definir variaveis de ambiente seguras
    export PATH="/usr/local/bin:/usr/bin:/bin"
    export IFS=$' \t\n'
    
    # Limitar recursos se possivel
    if command -v ulimit >/dev/null 2>&1; then
        ulimit -f 1048576  # Limite de arquivo: 1GB
        ulimit -t 3600     # Limite de CPU: 1 hora
    fi
}

# -----------------------------------------------------------------------------
# Cria um diretório com permissões seguras
# Usado antes do carregamento dos modulos (config.sh ainda nao disponivel)
# Parâmetros:
#   $1 - Caminho do diretório
#   $2 - Permissões (opcional, padrão: 0755)
# Retorna: 0 se criado/existente, 1 se erro
# -----------------------------------------------------------------------------
_criar_diretorio_seguro() {
    local caminho="${1:-}"
    local permissao="${2:-${PERM_DIR_SECURE}}"

    if [[ -z "$caminho" ]]; then
        printf "Erro: Caminho nao pode ser vazio.\n" >&2
        return 1
    fi

    if [[ -d "$caminho" ]]; then
        return 0
    fi

    if mkdir -p "$caminho" 2>/dev/null; then
        chmod "$permissao" "$caminho" 2>/dev/null || true
        return 0
    else
        printf "Erro: Nao foi possivel criar o diretorio '%s'.\n" "$caminho" >&2
        return 1
    fi
}

# =============================================================================
# INICIALIZAÇÃO DE DIRETÓRIOS
# =============================================================================

# Lista de diretórios obrigatórios
declare -a AUX_DIRS=("${lib_dir}" "${cfg_dir}")

for dir in "${AUX_DIRS[@]}"; do
    # Verificar se a variável está definida
    if [[ -z "${dir}" ]]; then
        printf "ERRO: Variavel de diretorio nao definida.\n" >&2
        return 1
    fi

    # Criar diretório caso não exista com permissões seguras
    if [[ ! -d "${dir}" ]]; then
        if ! _criar_diretorio_seguro "${dir}" "${PERM_DIR_SECURE}"; then
            printf "ERRO: Nao foi possivel criar o diretorio '%s'.\n" "${dir}" >&2
            exit 1
        fi
    fi

    # APLICAR PERMISSOES DE FORMA SEGURA: usar constante ao inves de hardcoded
    # Recursivo apenas quando necessario, e com permissao segura
    chmod "${PERM_DIR_SECURE}" "${dir}" 2>/dev/null || {
        printf "AVISO: Nao foi possivel ajustar permissao em '%s'.\n" "${dir}" >&2
    }

    # Verificar se o diretório existe após criação
    [[ -d "${dir}" ]] || {
        printf "ERRO: O diretorio '%s' nao foi encontrado.\n" "${dir}" >&2
        printf "Certifique-se de que os arquivos/modulos correspondentes estao instalados corretamente.\n" >&2
        exit 1
    }
done

# =============================================================================
# CARREGAMENTO DE MÓDULOS
# Carrega um módulo com verificação de segurança
# Parâmetros:
#   $1 - Nome do módulo (sem extensão)
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_caminho_modulo() {
    local modulo="${1}"
    local caminho="${lib_dir}/${modulo}"

    # Verificar se o arquivo existe
    if [[ ! -f "${caminho}" ]]; then
        printf "ERRO: Modulo '%s' nao encontrado em '%s'\n" "${modulo}" "${caminho}" >&2
        return 1
    fi

    # Verificar se o arquivo pode ser lido
    if [[ ! -r "${caminho}" ]]; then
        printf "ERRO: Modulo '%s' nao pode ser lido\n" "${modulo}" >&2
        return 1
    fi

    # Verificar se o arquivo não está vazio
    if [[ ! -s "${caminho}" ]]; then
        printf "ERRO: Modulo '%s' esta vazio\n" "${modulo}" >&2
        return 1
    fi

    # Carregar o módulo
    # shellcheck disable=SC1090
    if ! . "${caminho}"; then
        printf "ERRO: Falha ao carregar modulo '%s'\n" "${modulo}" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Carrega módulos com tratamento de erros acumulativo
# Retorna: 0 se todos carregados, 1 se algum falhou
_carregar_modulos() {
    local modulos=(
        "constantes.sh" # Constantes do Sistema SAV
        "utils.sh"      # Utilitarios basicos primeiro
        "validacao.sh"  # Validacao centralizada
        "config.sh"     # Configuracoes
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
        "menus.sh"      # Modulos de Menu
    )

    local modulo=""
    local erros=0

    for modulo in "${modulos[@]}"; do
        if ! _caminho_modulo "$modulo"; then
            ((erros++))
        fi
    done

    if (( erros > 0 )); then
        printf "AVISO: %d modulo(s) falharam ao carregar.\n" "$erros" >&2
        return 1
    fi
    return 0
}

# =============================================================================
# INICIALIZAÇÃO DO SISTEMA
# -----------------------------------------------------------------------------
# Inicializa o sistema carregando configurações e validando ambiente
# Retorna: 0 se sucesso, 1 se erro
# -----------------------------------------------------------------------------
_inicializar_sistema() {
    # Configurar ambiente seguro PRIMEIRO
    _configurar_ambiente_seguro
    
    # Carregar módulos do sistema
    if ! _carregar_modulos; then
        printf "ERRO: Falha ao carregar modulos.\n" >&2
        return 1
    fi

    # Carregar e validar configuracoes
    if ! _carregar_configuracoes; then
        printf "ERRO: Falha ao carregar configuracoes.\n" >&2
        return 1
    fi

    # Verificar dependências (agora retorna erro ao inves de sair)
    if ! _check_instalado; then
        printf "ERRO: Dependencias nao atendidas.\n" >&2
        return 1
    fi

    # Validar diretorios
    if ! _validar_diretorios; then
        printf "ERRO: Falha na validacao de diretorios.\n" >&2
        return 1
    fi

    # Configurar ambiente
    _configurar_ambiente

    # Executar limpeza automatica diaria
    _executar_expurgador_diario

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
        printf "ERRO: Falha na inicializacao do sistema. Saindo...\n" >&2
        exit 1
    fi

    # Autenticacao
    if ! _login; then
        printf "ERRO: Autenticacao falhou. Saindo...\n" >&2
        exit 1
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
        printf "ERRO: Menu principal nao encontrado.\n" >&2
        exit 1
    fi
}

# =============================================================================
# EXECUÇÃO DO SCRIPT
# =============================================================================

# Verificar se esta sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi
