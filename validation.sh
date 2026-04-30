#!/usr/bin/env bash
#
# validation.sh - Modulo de Validacao Centralizada
# Funcoes para validacao segura de entrada e dados
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 30/04/2026-01

# =============================================================================
# CARREGAR CONSTANTES DO SISTEMA
# =============================================================================
# Carregar constantes se disponivel
if [[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/constantes.sh" ]]; then
    # shellcheck source=constantes.sh
    . "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/constantes.sh"
fi

#---------- FUNCOES DE VALIDACAO DE ENTRADA ----------#

# Valida nome de variavel (apenas letras, numeros e underscore)
# Parametros: $1=nome_variavel
# Retorna: 0=valido 1=invalido
_validar_nome_variavel() {
    local nome="${1:-}"
    [[ -n "$nome" ]] && [[ "$nome" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

# Valida valor de configuracao (sem caracteres perigosos)
# Parametros: $1=valor
# Retorna: 0=valido 1=invalido
_validar_valor_config() {
    local valor="${1:-}"
    # Rejeitar valores com caracteres perigosos
    [[ ! "$valor" =~ [\$\`\;\|\&\<\>\(\)] ]]
}

# Valida caminho de arquivo/diretorio (sem path traversal)
# Parametros: $1=caminho
# Retorna: 0=valido 1=invalido
_validar_caminho() {
    local caminho="${1:-}"
    
    # Verificar se nao esta vazio
    [[ -n "$caminho" ]] || return 1
    
    # Rejeitar caminhos com path traversal
    [[ ! "$caminho" =~ \.\. ]] || return 1
    
    # Rejeitar caminhos absolutos suspeitos
    case "$caminho" in
        /etc/*|/usr/*|/bin/*|/sbin/*|/root/*|/home/*)
            return 1
            ;;
    esac
    
    return 0
}

# Valida nome de programa (letras maiusculas e numeros apenas)
# Parametros: $1=nome_programa
# Retorna: 0=valido 1=invalido
_validar_nome_programa() {
    local programa="${1:-}"
    [[ -n "$programa" ]] && [[ "$programa" =~ ^[A-Z0-9]+$ ]]
}

# Valida endereco IP (formato basico)
# Parametros: $1=ip
# Retorna: 0=valido 1=invalido
_validar_ip() {
    local ip="${1:-}"
    [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

# Valida porta de rede (1-65535)
# Parametros: $1=porta
# Retorna: 0=valido 1=invalido
_validar_porta() {
    local porta="${1:-}"
    [[ "$porta" =~ ^[0-9]+$ ]] && (( porta >= 1 && porta <= 65535 ))
}

# Valida nome de usuario (alfanumerico e underscore)
# Parametros: $1=usuario
# Retorna: 0=valido 1=invalido
_validar_usuario() {
    local usuario="${1:-}"
    [[ -n "$usuario" ]] && [[ "$usuario" =~ ^[A-Za-z0-9_-]+$ ]] && (( ${#usuario} <= 32 ))
}

#---------- FUNCOES DE VALIDACAO DE ARQUIVO ----------#

# Valida se arquivo existe e e legivel
# Parametros: $1=caminho_arquivo
# Retorna: 0=valido 1=invalido
_validar_arquivo_legivel() {
    local arquivo="${1:-}"
    [[ -n "$arquivo" ]] && [[ -f "$arquivo" ]] && [[ -r "$arquivo" ]]
}

# Valida se diretorio existe e e acessivel
# Parametros: $1=caminho_diretorio
# Retorna: 0=valido 1=invalido
_validar_diretorio_acessivel() {
    local dir="${1:-}"
    [[ -n "$dir" ]] && [[ -d "$dir" ]] && [[ -r "$dir" ]] && [[ -x "$dir" ]]
}

# Valida se arquivo e de propriedade do usuario atual
# Parametros: $1=caminho_arquivo
# Retorna: 0=valido 1=invalido
_validar_propriedade_arquivo() {
    local arquivo="${1:-}"
    local owner
    
    [[ -f "$arquivo" ]] || return 1
    
    if command -v stat >/dev/null 2>&1; then
        owner=$(stat -c %U "$arquivo" 2>/dev/null)
        [[ "$owner" == "$USER" ]]
    else
        # Fallback para sistemas sem stat
        [[ -O "$arquivo" ]]
    fi
}

# Valida tamanho de arquivo (nao vazio, nao muito grande)
# Parametros: $1=arquivo $2=tamanho_max_mb(opcional, padrao=100)
# Retorna: 0=valido 1=invalido
_validar_tamanho_arquivo() {
    local arquivo="${1:-}"
    local max_mb="${2:-100}"
    local tamanho_bytes max_bytes
    
    [[ -f "$arquivo" ]] || return 1
    
    tamanho_bytes=$(wc -c < "$arquivo" 2>/dev/null || echo 0)
    max_bytes=$((max_mb * 1024 * 1024))
    
    # Arquivo nao pode estar vazio nem muito grande
    (( tamanho_bytes > 0 && tamanho_bytes <= max_bytes ))
}

#---------- FUNCOES DE SANITIZACAO ----------#

# Sanitiza entrada removendo caracteres perigosos
# Parametros: $1=entrada
# Retorna: entrada sanitizada via stdout
_sanitizar_entrada() {
    local entrada="${1:-}"
    # Remove caracteres perigosos mantendo alfanumericos, espacos, pontos, hifens
    printf '%s' "$entrada" | tr -cd '[:alnum:][:space:]._-'
}

# Sanitiza nome de arquivo removendo caracteres invalidos
# Parametros: $1=nome_arquivo
# Retorna: nome sanitizado via stdout
_sanitizar_nome_arquivo() {
    local nome="${1:-}"
    # Remove caracteres invalidos para nomes de arquivo
    printf '%s' "$nome" | tr -cd '[:alnum:]._-' | cut -c1-255
}

#---------- FUNCOES DE VALIDACAO DE FORMATO ----------#

# Valida formato de data (DD-MM-YYYY)
# Parametros: $1=data
# Retorna: 0=valido 1=invalido
_validar_data() {
    local data="${1:-}"
    [[ "$data" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]
}

# Valida formato de versao (X.Y ou X.Y.Z)
# Parametros: $1=versao
# Retorna: 0=valido 1=invalido
_validar_versao() {
    local versao="${1:-}"
    [[ "$versao" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

# Valida resposta S/N
# Parametros: $1=resposta
# Retorna: 0=S 1=N 2=invalido
_validar_resposta_sn() {
    local resposta="${1:-}"
    case "${resposta,,}" in
        s|sim|y|yes) return 0 ;;
        n|nao|no) return 1 ;;
        *) return 2 ;;
    esac
}

#---------- FUNCOES DE VALIDACAO COMBINADA ----------#

# Valida configuracao completa de servidor
# Parametros: $1=ip $2=porta $3=usuario
# Retorna: 0=valido 1=invalido
_validar_config_servidor() {
    local ip="${1:-}"
    local porta="${2:-}"
    local usuario="${3:-}"
    
    _validar_ip "$ip" && _validar_porta "$porta" && _validar_usuario "$usuario"
}

# Valida entrada de menu (numero dentro do range)
# Parametros: $1=opcao $2=min $3=max
# Retorna: 0=valido 1=invalido
_validar_opcao_menu() {
    local opcao="${1:-}"
    local min="${2:-0}"
    local max="${3:-9}"
    
    [[ "$opcao" =~ ^[0-9]+$ ]] && (( opcao >= min && opcao <= max ))
}