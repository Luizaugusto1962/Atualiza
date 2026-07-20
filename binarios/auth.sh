#!/usr/bin/env bash
set -euo pipefail
#
# auth.sh - Modulo de Autenticacao
# Responsavel pela autenticacao de usuarios
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 20/07/2026-01
# Autor: Luiz Augusto
#

# Variaveis globais esperadas
CFG_DIR="${CFG_DIR:-}"                 # Diretorio de configuracao

# Arquivo de senhas oculto — avaliado sob demanda em vez de tempo de source
SENHA_FILE="${CFG_DIR:-}/.senhas"

# Garantir que o arquivo de senhas tenha permissoes restritas
if [[ -f "$SENHA_FILE" ]]; then
    chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE" 2>/dev/null || true
fi

# Variavel global para armazenar o nome do usuario autenticado
declare usuario           # Variavel global para armazenar o nome do usuario autenticado

# Validar nome de usuário (somente letras maiusculas e números)
_usuario_valido() {
    local usuario="$1"
    [[ "$usuario" =~ ^[A-Z0-9._-]+$ ]]
}

# Buscar hash do usuário no arquivo de senhas
_obter_hash_usuario() {
    local usuario="$1"
    awk -F: -v u="$usuario" '
        $1 == u {print $2; found=1; exit}
        END {exit !found}
    ' "$SENHA_FILE"
}

# Verificar se o usuario existe no arquivo de senhas
_usuario_existe() {
    local usuario="$1"
    [[ -z "$usuario" ]] && return 1
    awk -F: -v u="$usuario" '$1 == u {found=1; exit} END {exit !found}' "$SENHA_FILE" 2>/dev/null
}

# Funcao para hash da senha usando algoritmo configuravel
_hash_senha() {
    local senha="$1"
    local algoritmo="${HASH_ALGORITHM:-sha256sum}"

    if ! command -v "$algoritmo" >/dev/null 2>&1; then
        _erro "Algoritmo de hash '%s' nao encontrado.\n" "$algoritmo" >&2
        return 1
    fi

    printf '%s' "$senha" | "$algoritmo" | cut -d' ' -f1
}

# Funcao para cadastrar usuario
_cadastrar_usuario() {
    local usuario senha senha_confirm hash_senha

    _mensagec "${VERMELHO}" "Cadastro de Usuario"
    _meia_linha "=" "${VERMELHO}"

    read -rp "${AMARELO}Digite o nome do usuario: ${NORMAL}" usuario
    usuario=$(_upper "$(_trim "$usuario")")
    if [[ -z "$usuario" ]]; then
        _mensagec "${VERMELHO}" "Usuario nao pode ser vazio."
        return 1
    fi

    if ! _usuario_valido "$usuario"; then
        _mensagec "${VERMELHO}" "Usuario invalido. Use apenas letras maiusculas e numeros."
        return 1
    fi

    # Verificar se usuario ja existe
    if _obter_hash_usuario "$usuario" >/dev/null 2>&1; then
        _mensagec "${VERMELHO}" "Usuario ja existe."
        return 1
    fi

    read -rsp "${AMARELO}Digite a senha: ${NORMAL}" senha
    printf "\n"
    read -rsp "${AMARELO}Confirme a senha: ${NORMAL}" senha_confirm
    printf "\n"

    if [[ -z "$senha" ]]; then
        _mensagec "${VERMELHO}" "Senha nao pode ser vazia."
        return 1
    fi

    if [[ "$senha" != "$senha_confirm" ]]; then
        _mensagec "${VERMELHO}" "Senhas nao coincidem."
        return 1
    fi

    hash_senha=$(_hash_senha "$senha")
    printf '%s:%s\n' "${usuario}" "${hash_senha}" >> "$SENHA_FILE"

    # Restringir permissoes do arquivo de senhas (somente dono: rw)
    chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE" 2>/dev/null || {
        _mensagec "${AMARELO}" "AVISO: Nao foi possivel restringir permissoes de ${SENHA_FILE}"
        _log "AVISO: Permissoes de ${SENHA_FILE} nao alteradas"
    }

    _mensagec "${VERDE}" "Usuario cadastrado com sucesso."
}

# Mostrar tela de boas-vindas apos login bem-sucedido
_mostrar_boas_vindas() {
    local nome_usuario="$1"

    printf "\n"
    _linha "=" "${VERDE}"
    _mensagec "${AMARELO}" "Bem-vindo ao Sistema"
    _linha "=" "${VERDE}"
    printf "\n"
    _mensageb "${CIANO}" "Usuario: ${BRANCO}${nome_usuario}${NORMAL}"
    _mensageb "${CIANO}" "Empresa: ${BRANCO}${CFG_EMPRESA:-N/A}${NORMAL}"
	_mensageb "${CIANO}" "Versao Iscobol: ${BRANCO}${CFG_VERSAOCLASS}${NORMAL}"
    _mensageb "${CIANO}" "Data: ${BRANCO}$(date '+%d/%m/%Y')${NORMAL}"
    _mensageb "${CIANO}" "Hora: ${BRANCO}$(date '+%H:%M:%S')${NORMAL}"
    printf "\n"
    _linha "-" "${VERDE}"
    printf "\n"

    read -rp "${AMARELO}Pressione ENTER para continuar...${NORMAL}" -t 5 2>/dev/null || true
}

# Funcao para login
_login() {
    local senha hash_senha stored_hash
    local tentativas=1
    local resposta
    # usuario is made global to be used in logging
    local max_tentativas="${MAX_LOGIN_ATTEMPTS:-3}"
    while [[ $tentativas -le $max_tentativas ]]; do
        _mensagec "${VERMELHO}" "Login no Sistema"
        _linha "=" "${VERDE}"

        read -rp "${AMARELO}Usuario: ${NORMAL}" usuario
        usuario=$(_upper "$(_trim "$usuario")")

        if [[ -z "$usuario" ]]; then
            _mensagec "${VERMELHO}" "Nome de usuario nao pode ser vazio."
        elif ! _usuario_valido "$usuario"; then
            _mensagec "${VERMELHO}" "Usuario invalido. Use apenas letras maiusculas e numeros."
        else
            if [[ ! -f "$SENHA_FILE" ]]; then
                _mensagec "${VERMELHO}" "Nenhum usuario cadastrado. Execute o programa de cadastro primeiro."
                return 1
            elif [[ ! -s "$SENHA_FILE" ]]; then
                _mensagec "${VERMELHO}" "ALERTA: Arquivo de senhas esta vazio. Nenhum usuario cadastrado no sistema."
                _mensagec "${AMARELO}" "Execute o programa de cadastro primeiro."
                _linha "-" "${VERMELHO}"
                return 1
            elif ! _usuario_existe "$usuario"; then
                _mensagec "${VERMELHO}" "Usuario nao cadastrado no sistema."
                _linha "-" "${VERMELHO}"
            else
                read -rsp "${AMARELO}Senha: ${NORMAL}" senha
                printf "\n"

                if [[ -z "$senha" ]]; then
                    _mensagec "${VERMELHO}" "Senha nao pode ser vazia."
                else
                    stored_hash=$(_obter_hash_usuario "$usuario")
                    if [[ -z "$stored_hash" ]]; then
                        _mensagec "${VERMELHO}" "Usuario nao encontrado."
                        _linha "-" "${VERMELHO}"
                    else
                        hash_senha=$(_hash_senha "$senha")
                        if [[ "$hash_senha" == "$stored_hash" ]]; then
                            _mensagec "${VERDE}" "Login bem-sucedido."
                            export usuario
                            _mostrar_boas_vindas "$usuario"
                            return 0
                        else
                            _mensagec "${VERMELHO}" "Senha incorreta."
                            _linha "-" "${VERMELHO}"
                            printf "\n"
                            unset usuario
                        fi
                    fi
                fi
            fi
        fi

        if [[ $tentativas -ge $max_tentativas ]]; then
            return 1
        fi

        read -rp "${AMARELO}Deseja tentar novamente? (s/N): ${NORMAL}" resposta
        if [[ ! "$resposta" =~ ^[sS]$ ]]; then
            return 1
        fi
        ((tentativas++)) || true
        printf "\n"
    done
    return 1
}

# Funcao para alterar senha
_alterar_senha() {
    local senha_atual nova_senha confirm_senha hash_atual hash_nova stored_hash

    # Usar o usuario ja autenticado globalmente
    if [[ -z "$usuario" ]]; then
        _mensagec "${VERMELHO}" "Voce precisa estar logado para alterar a senha."
        return 1
    fi

    _mensagec "${VERMELHO}" "Alteracao de Senha"
    _linha "=" "${VERMELHO}"

    read -rsp "${AMARELO}Digite a senha atual: ${NORMAL}" senha_atual
    printf "\n"

    # Verificar senha atual
    stored_hash=$(_obter_hash_usuario "$usuario")
    if [[ -z "$stored_hash" ]]; then
        _mensagec "${VERMELHO}" "Usuario nao encontrado."
        _linha "-" "${VERMELHO}"
        return 1
    fi

    hash_atual=$(_hash_senha "$senha_atual")
    if [[ "$hash_atual" != "$stored_hash" ]]; then
        _mensagec "${VERMELHO}" "Senha atual incorreta."
        _linha "-" "${VERMELHO}"
        return 1
    fi

    read -rsp "${AMARELO}Digite a nova senha: ${NORMAL}" nova_senha
    printf "\n"
    read -rsp "${AMARELO}Confirme a nova senha: ${NORMAL}" confirm_senha
    printf "\n"

    if [[ -z "$nova_senha" ]]; then
        _mensagec "${VERMELHO}" "Nova senha nao pode ser vazia."
        return 1
    fi

    if [[ "$nova_senha" != "$confirm_senha" ]]; then
        _mensagec "${VERMELHO}" "Novas senhas nao coincidem."
        return 1
    fi

    hash_nova=$(_hash_senha "$nova_senha")

    # Atualizar a linha no arquivo usando arquivo temporario (seguro contra caracteres especiais)
    local tmp_senhas
    tmp_senhas=$(mktemp) || {
        _mensagec "${VERMELHO}" "Erro ao criar arquivo temporario para atualizacao de senha."
        return 1
    }
    # Reescrever o arquivo substituindo apenas a linha do usuario atual
    while IFS= read -r linha || [[ -n "$linha" ]]; do
        if [[ "$linha" == "${usuario}:"* ]]; then
            printf '%s:%s\n' "${usuario}" "${hash_nova}"
        else
            printf '%s\n' "$linha"
        fi
    done < "$SENHA_FILE" > "$tmp_senhas"

    if mv -f "$tmp_senhas" "$SENHA_FILE"; then
        chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE" 2>/dev/null || true
        _mensagec "${VERDE}" "Senha alterada com sucesso."
    else
        rm -f "$tmp_senhas"
        _mensagec "${VERMELHO}" "Erro ao salvar nova senha."
        return 1
    fi
}
