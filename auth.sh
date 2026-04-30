#!/usr/bin/env bash
#
# auth.sh - Modulo de Autenticacao
# Responsavel pela autenticacao de usuarios
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 24/04/2026-02
# Autor: Luiz Augusto
#

# Variaveis globais esperadas
cfg_dir="${cfg_dir:-}"                 # Diretorio de configuracao

# Arquivo de senhas oculto
SENHA_FILE="${cfg_dir}/.senhas"

# Garantir que o arquivo de senhas tenha permissoes restritas
if [[ -f "$SENHA_FILE" ]]; then
    chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE" 2>/dev/null || true
fi

# Variavel global para armazenar o nome do usuario autenticado
declare -u usuario           # Variavel global para armazenar o nome do usuario autenticado

# Funcao para hash da senha usando algoritmo configuravel
_hash_senha() {
    local senha="$1"
    local algoritmo="${HASH_ALGORITHM:-sha256sum}"
    
    if ! command -v "$algoritmo" >/dev/null 2>&1; then
        printf "Erro: Algoritmo de hash '%s' nao encontrado.\n" "$algoritmo" >&2
        return 1
    fi
    
    printf '%s' "$senha" | "$algoritmo" | cut -d' ' -f1
}

# Funcao para cadastrar usuario
_cadastrar_usuario() {
    local usuario senha senha_confirm hash_senha

    _mensagec "${RED}" "Cadastro de Usuario"
    _meia_linha "=" "${RED}"

    read -rp "${YELLOW}Digite o nome do usuario: ${NORM}" usuario
    usuario=$(echo "$usuario" | tr '[:lower:]' '[:upper:]')
    if [[ -z "$usuario" ]]; then
        _mensagec "${RED}" "Usuario nao pode ser vazio."
        return 1
    fi

    # Verificar se usuario ja existe
    if grep -q "^${usuario}:" "$SENHA_FILE" 2>/dev/null; then
        _mensagec "${RED}" "Usuario ja existe."
        return 1
    fi

    read -rsp "${YELLOW}Digite a senha: ${NORM}" senha
    printf "\n"
    read -rsp "${YELLOW}Confirme a senha: ${NORM}" senha_confirm
    printf "\n"

    if [[ -z "$senha" ]]; then
        _mensagec "${RED}" "Senha nao pode ser vazia."
        return 1
    fi

    if [[ "$senha" != "$senha_confirm" ]]; then
        _mensagec "${RED}" "Senhas nao coincidem."
        return 1
    fi

    hash_senha=$(_hash_senha "$senha")
    printf '%s:%s\n' "${usuario}" "${hash_senha}" >> "$SENHA_FILE"

    # Restringir permissoes do arquivo de senhas (somente dono: rw)
    chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE" 2>/dev/null || {
        _mensagec "${YELLOW}" "AVISO: Nao foi possivel restringir permissoes de ${SENHA_FILE}"
        _log "AVISO: Permissoes de ${SENHA_FILE} nao alteradas"
    }

    _mensagec "${GREEN}" "Usuario cadastrado com sucesso."
}

# Funcao para login
_login() {
    local senha hash_senha stored_hash
    local tentativas=1
    local resposta
    # usuario is made global to be used in logging

    while [[ $tentativas -le 2 ]]; do
        _mensagec "${RED}" "Login no Sistema"
        _linha "=" "${GREEN}"

        read -rp "${YELLOW}Usuario: ${NORM}" usuario
        usuario=$(echo "$usuario" | tr '[:lower:]' '[:upper:]' | xargs)

        if [[ -z "$usuario" ]]; then
            _mensagec "${RED}" "Nome de usuario nao pode ser vazio."
        else
            read -rsp "${YELLOW}Senha: ${NORM}" senha
            printf "\n"

            if [[ -z "$senha" ]]; then
                _mensagec "${RED}" "Senha nao pode ser vazia."
            elif [[ ! -f "$SENHA_FILE" ]]; then
                _mensagec "${RED}" "Nenhum usuario cadastrado. Execute o programa de cadastro primeiro."
                return 1
            elif [[ ! -s "$SENHA_FILE" ]]; then
                # Verificar se o arquivo de senhas esta vazio
                _mensagec "${RED}" "ALERTA: Arquivo de senhas esta vazio. Nenhum usuario cadastrado no sistema."
                _mensagec "${YELLOW}" "Execute o programa de cadastro primeiro."
                _linha "-" "${RED}"
                return 1
            else
                stored_hash=$(grep "^${usuario}:" "$SENHA_FILE" | cut -d':' -f2)
                if [[ -z "$stored_hash" ]]; then
                    _mensagec "${RED}" "Usuario nao encontrado."
                    _linha "-" "${RED}"
                else
                    hash_senha=$(_hash_senha "$senha")
                    if [[ "$hash_senha" == "$stored_hash" ]]; then
                        _mensagec "${GREEN}" "Login bem-sucedido."
                        export usuario
                        return 0
                    else
                        _mensagec "${RED}" "Senha incorreta."
                        _linha "-" "${RED}"
                        printf "\n"
                        # _limpa_tela usuario on failure
                        unset usuario
                    fi
                fi
            fi
        fi

        if [[ $tentativas -ge 2 ]]; then
            return 1
        fi
        
        read -rp "${YELLOW}Deseja tentar novamente? (s/N): ${NORM}" resposta
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
        _mensagec "${RED}" "Voce precisa estar logado para alterar a senha."
        return 1
    fi

    _mensagec "${RED}" "Alteracao de Senha"
    _linha "=" "${RED}"

    read -rsp "${YELLOW}Digite a senha atual: ${NORM}" senha_atual
    printf "\n"

    # Verificar senha atual
    stored_hash=$(grep "^${usuario}:" "$SENHA_FILE" | cut -d':' -f2)
    if [[ -z "$stored_hash" ]]; then
        _mensagec "${RED}" "Usuario nao encontrado."
        _linha "-" "${RED}"
        return 1
    fi

    hash_atual=$(_hash_senha "$senha_atual")
    if [[ "$hash_atual" != "$stored_hash" ]]; then
        _mensagec "${RED}" "Senha atual incorreta."
        _linha "-" "${RED}"
        return 1
    fi

    read -rsp "${YELLOW}Digite a nova senha: ${NORM}" nova_senha
    printf "\n"
    read -rsp "${YELLOW}Confirme a nova senha: ${NORM}" confirm_senha
    printf "\n"

    if [[ -z "$nova_senha" ]]; then
        _mensagec "${RED}" "Nova senha nao pode ser vazia."
        return 1
    fi

    if [[ "$nova_senha" != "$confirm_senha" ]]; then
        _mensagec "${RED}" "Novas senhas nao coincidem."
        return 1
    fi

    hash_nova=$(_hash_senha "$nova_senha")

    # Atualizar a linha no arquivo usando arquivo temporario (seguro contra caracteres especiais)
    local tmp_senhas
    tmp_senhas=$(mktemp) || {
        _mensagec "${RED}" "Erro ao criar arquivo temporario para atualizacao de senha."
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
        _mensagec "${GREEN}" "Senha alterada com sucesso."
    else
        rm -f "$tmp_senhas"
        _mensagec "${RED}" "Erro ao salvar nova senha."
        return 1
    fi
}
