#!/usr/bin/env bash
set -euo pipefail
#
# auth.sh - Modulo de Autenticacao
# Responsavel pela autenticacao de usuarios
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 24/09/2026
# Autor: Luiz Augusto
#
# =============================================================================
# MELHORIAS DE SEGURANÇA APLICADAS:
# - Hash de senha com salt aleatório (proteção contra rainbow tables)
# - Formato do hash: algoritmo$salt$hash (ex: sha256sum$a1b2c3...$hashvalue)
# - Rate limiting: bloqueio temporário após múltiplas tentativas falhas
# - Limpeza segura de arquivos temporários via trap
# - Migração automática de hashes legados (sem salt)
# - Criação automática do arquivo .senhas se não existir
# =============================================================================
#
# Arquivo de senhas oculto — avaliado sob demanda em vez de tempo de source
arquivo_senhas="${CFG_DIR:-}/.senhas"
# Arquivo de controle de tentativas de login (rate limiting)
arquivo_tentativas="${CFG_DIR:-}/.tentativas_login"

# CORREÇÃO CRÍTICA: Garantir que o arquivo .senhas existe antes de operar
# Se não existir, criar com permissões restritas
if [[ -n "${CFG_DIR:-}" ]]; then
    # Criar diretório de configuração se não existir
    if [[ ! -d "${CFG_DIR}" ]]; then
        if ! mkdir -p "${CFG_DIR}" 2>/dev/null; then
            _erro "Não foi possível criar diretório de configuração: ${CFG_DIR}" >&2
        else
            chmod "${PERM_DIR_SECURE:-0700}" "${CFG_DIR}" 2>/dev/null || true
            _log "Diretório de configuração criado: ${CFG_DIR}" "${LOG_ATU:-/dev/null}"
        fi
    fi
    
    # Criar arquivo de senhas se não existir
    if [[ ! -f "$arquivo_senhas" ]]; then
        if touch "$arquivo_senhas" 2>/dev/null; then
            chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_senhas" 2>/dev/null || true
            _log "Arquivo de senhas criado: ${arquivo_senhas}" "${LOG_ATU:-/dev/null}"
        else
            _erro "Não foi possível criar arquivo de senhas: ${arquivo_senhas}" >&2
        fi
    else
        # Garantir que o arquivo de senhas tenha permissões restritas
        chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_senhas" 2>/dev/null || true
    fi
fi

# 🔒 CORREÇÃO: Inicializar variável com valor vazio para evitar "unbound variable" com set -u
declare usuario=""

# =============================================================================
# FUNÇÕES AUXILIARES DE VALIDAÇÃO
# =============================================================================

# Validar nome de usuário (somente letras maiusculas e números)
_usuario_valido() {
    local usuario="${1:-}"
    [[ "$usuario" =~ ^[A-Z0-9._-]+$ ]]
}

# CORREÇÃO: Verificar se o arquivo de senhas existe e é legível
_verificar_arquivo_senhas() {
    if [[ ! -f "$arquivo_senhas" ]]; then
        return 1
    fi
    if [[ ! -r "$arquivo_senhas" ]]; then
        return 1
    fi
    return 0
}

# Buscar hash do usuário no arquivo de senhas
_obter_hash_usuario() {
    local usuario="${1:-}"
    # 🔒 CORREÇÃO: Verificar se arquivo existe antes de ler
    if ! _verificar_arquivo_senhas; then
        return 1
    fi
    awk -F: -v u="$usuario" '
    $1 == u {print $2; encontrado=1; exit}
    END {exit !encontrado}
    ' "$arquivo_senhas" 2>/dev/null
}

# Verificar se o usuario existe no arquivo de senhas
_usuario_existe() {
    local usuario="${1:-}"
    [[ -z "$usuario" ]] && return 1
    # CORREÇÃO: Verificar se arquivo existe antes de ler
    if ! _verificar_arquivo_senhas; then
        return 1
    fi
    awk -F: -v u="$usuario" '$1 == u {encontrado=1; exit} END {exit !encontrado}' "$arquivo_senhas" 2>/dev/null
}

# =============================================================================
# FUNÇÕES DE HASH COM SALT (SEGURANÇA CRÍTICA)
# =============================================================================

# Funcao para hash da senha com salt usando algoritmo configuravel
# Formato de saida: $algoritmo$salt$hash (compativel com verificacao)
# Parametros:
#   $1 - senha a ser hasheada
#   $2 - salt existente (opcional, para verificar senha armazenada)
# Retorna: string no formato "algoritmo$salt$hash"
_hash_senha() {
    local senha="${1:-}"
    local salt_existente="${2:-}"
    local algoritmo="${HASH_ALGORITHM:-sha256sum}"
    
    if ! command -v "$algoritmo" >/dev/null 2>&1; then
        _erro "Algoritmo de hash '%s' nao encontrado." "$algoritmo" >&2
        return 1
    fi
    
    local salt
    if [[ -n "$salt_existente" ]]; then
        salt="$salt_existente"
    else
        if [[ -r /dev/urandom ]]; then
            salt=$(od -An -tx1 -N8 /dev/urandom 2>/dev/null | tr -d ' \n')
        else
            salt=$(printf '%04x%04x%04x%04x' "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM")
        fi
        salt="${salt:0:16}"
        if [[ ${#salt} -lt 16 ]]; then
            salt=$(printf '%016x' "$RANDOM$RANDOM$RANDOM$RANDOM")
        fi
    fi
    
    local hash
    hash=$(printf '%s%s' "$salt" "$senha" | "$algoritmo" | cut -d' ' -f1)
    
    printf '%s$%s$%s' "$algoritmo" "$salt" "$hash"
}

# Extrai o salt de um hash armazenado (formato: algoritmo$salt$hash)
_extrair_salt() {
    local hash_completo="${1:-}"
    if [[ "$hash_completo" != *'$'*'$'* ]]; then
        printf ''
        return 0
    fi
    printf '%s' "$hash_completo" | cut -d'$' -f2
}

# Extrai apenas o hash (sem salt) de um hash armazenado
_extrair_hash() {
    local hash_completo="${1:-}"
    if [[ "$hash_completo" != *'$'*'$'* ]]; then
        printf '%s' "$hash_completo"
        return 0
    fi
    printf '%s' "$hash_completo" | cut -d'$' -f3
}

# Extrai o algoritmo de um hash armazenado
_extrair_algoritmo() {
    local hash_completo="${1:-}"
    if [[ "$hash_completo" != *'$'*'$'* ]]; then
        printf '%s' "${HASH_ALGORITHM:-sha256sum}"
        return 0
    fi
    printf '%s' "$hash_completo" | cut -d'$' -f1
}

# Verifica se um hash está no formato novo (com salt)
_hash_tem_salt() {
    local hash_completo="${1:-}"
    [[ "$hash_completo" == *'$'*'$'* ]]
}

# =============================================================================
# RATE LIMITING - PROTEÇÃO CONTRA BRUTE FORCE
# =============================================================================

# Verifica se o usuário está bloqueado por excesso de tentativas
_verificar_bloqueio_usuario() {
    local usuario="${1:-}"
    local tempo_bloqueio="${C_BLOQUEIO_LOGIN:-300}"
    
    [[ -z "$usuario" ]] && return 0
    [[ ! -f "$arquivo_tentativas" ]] && return 0
    
    local linha
    linha=$(awk -F: -v u="$usuario" '$1 == u {print $2 "|" $3; exit}' "$arquivo_tentativas" 2>/dev/null) || true
    [[ -z "$linha" ]] && return 0
    
    local tentativas timestamp_bloqueio
    tentativas="${linha%%|*}"
    timestamp_bloqueio="${linha##*|}"
    
    local max_tentativas="${MAX_LOGIN_ATTEMPTS:-3}"
    
    if (( tentativas >= max_tentativas )); then
        local agora
        agora=$(date +%s)
        local tempo_decorrido=$((agora - timestamp_bloqueio))
        
        if (( tempo_decorrido < tempo_bloqueio )); then
            local tempo_restante=$((tempo_bloqueio - tempo_decorrido))
            local minutos=$((tempo_restante / 60))
            local segundos=$((tempo_restante % 60))
            _exibir_mensagem_centralizada "${VERMELHO}" "Usuario bloqueado por excesso de tentativas."
            _exibir_mensagem_centralizada "${AMARELO}" "Tente novamente em ${minutos}m ${segundos}s"
            return 1
        else
            _remover_registro_tentativas "$usuario"
            return 0
        fi
    fi
    
    return 0
}

# Registra tentativa de login falha
_registrar_tentativa_falha() {
    local usuario="${1:-}"
    local max_tentativas="${MAX_LOGIN_ATTEMPTS:-3}"
    
    [[ -z "$usuario" ]] && return 0
    
    if [[ ! -f "$arquivo_tentativas" ]]; then
        touch "$arquivo_tentativas" 2>/dev/null || return 0
        chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_tentativas" 2>/dev/null || true
    fi
    
    local agora
    agora=$(date +%s)
    
    if awk -F: -v u="$usuario" '$1 == u {exit 0} END {exit 1}' "$arquivo_tentativas" 2>/dev/null; then
        local tmp_tent
        tmp_tent=$(mktemp) || return 0
        trap 'rm -f -- "$tmp_tent"' RETURN
        
        awk -F: -v u="$usuario" -v agora="$agora" -v max="$max_tentativas" '
        BEGIN { OFS=":" }
        $1 == u {
            tentativas = $2 + 1
            if (tentativas >= max) {
                print $1, tentativas, agora
            } else {
                print $1, tentativas, $3
            }
            next
        }
        { print }
        ' "$arquivo_tentativas" > "$tmp_tent"
        
        mv -f "$tmp_tent" "$arquivo_tentativas" 2>/dev/null || rm -f -- "$tmp_tent"
        trap - RETURN
    else
        printf '%s:%s:%s\n' "$usuario" "1" "$agora" >> "$arquivo_tentativas" 2>/dev/null || true
    fi
    
    chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_tentativas" 2>/dev/null || true
}

# Remove registro de tentativas do usuário
_remover_registro_tentativas() {
    local usuario="${1:-}"
    [[ -z "$usuario" ]] && return 0
    [[ ! -f "$arquivo_tentativas" ]] && return 0
    
    local tmp_tent
    tmp_tent=$(mktemp) || return 0
    trap 'rm -f -- "$tmp_tent"' RETURN
    
    awk -F: -v u="$usuario" '$1 != u' "$arquivo_tentativas" > "$tmp_tent"
    mv -f "$tmp_tent" "$arquivo_tentativas" 2>/dev/null || rm -f -- "$tmp_tent"
    trap - RETURN
}

# =============================================================================
# MIGRAÇÃO DE HASHES LEGADOS
# =============================================================================

# Verifica se o hash precisa de migração
_hash_precisa_migracao() {
    local hash_completo="${1:-}"
    [[ -n "$hash_completo" ]] && ! _hash_tem_salt "$hash_completo"
}

# Força reset de senha para hashes legados
_forcar_reset_senha_legado() {
    local usuario="${1:-}"
    _exibir_mensagem_centralizada "${AMARELO}" "Sua senha precisa ser atualizada por motivos de seguranca."
    _exibir_mensagem_centralizada "${CIANO}" "Por favor, defina uma nova senha."
    _linha
    
    local nova_senha confirm_senha hash_nova
    
    while true; do
        read -rsp "${AMARELO}Digite a nova senha: ${NORMAL}" nova_senha
        printf "\n"
        read -rsp "${AMARELO}Confirme a nova senha: ${NORMAL}" confirm_senha
        printf "\n"
        
        if [[ -z "$nova_senha" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Senha nao pode ser vazia."
            continue
        fi
        
        if [[ "$nova_senha" != "$confirm_senha" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Senhas nao coincidem."
            continue
        fi
        
        hash_nova=$(_hash_senha "$nova_senha") || return 1
        
        local tmp_senhas
        tmp_senhas=$(mktemp) || {
            _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao criar arquivo temporario."
            return 1
        }
        trap 'rm -f -- "$tmp_senhas"' RETURN
        
        while IFS= read -r linha || [[ -n "$linha" ]]; do
            if [[ "$linha" == "${usuario}:"* ]]; then
                printf '%s:%s\n' "${usuario}" "${hash_nova}"
            else
                printf '%s\n' "$linha"
            fi
        done < "$arquivo_senhas" > "$tmp_senhas"
        
        if mv -f "$tmp_senhas" "$arquivo_senhas"; then
            chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_senhas" 2>/dev/null || true
            trap - RETURN
            _exibir_mensagem_centralizada "${VERDE}" "Senha atualizada com sucesso!"
            _log "Hash migrado para formato com salt: ${usuario}" "${LOG_ATU:-/dev/null}"
            return 0
        else
            rm -f -- "$tmp_senhas"
            trap - RETURN
            _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao salvar nova senha."
            return 1
        fi
    done
}

# =============================================================================
# FUNÇÕES DE CADASTRO E LOGIN
# =============================================================================

# Funcao para cadastrar usuario
_cadastrar_usuario() {
    local usuario senha senha_confirm resumo_senha
    
    # CORREÇÃO: Verificar se o arquivo de senhas existe, criar se necessário
    if [[ ! -f "$arquivo_senhas" ]]; then
        if [[ -n "${CFG_DIR:-}" && -d "${CFG_DIR}" ]]; then
            touch "$arquivo_senhas" 2>/dev/null || {
                _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao criar arquivo de senhas: ${arquivo_senhas}"
                return 1
            }
            chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_senhas" 2>/dev/null || true
            _log "Arquivo de senhas criado: ${arquivo_senhas}" "${LOG_ATU:-/dev/null}"
        else
            _exibir_mensagem_centralizada "${VERMELHO}" "Diretorio de configuracao nao existe: ${CFG_DIR:-vazio}"
            return 1
        fi
    fi
    
    _exibir_mensagem_centralizada "${VERMELHO}" "Cadastro de Usuario"
    _meia_linha "=" "${VERMELHO}"
    read -rp "${AMARELO}Digite o nome do usuario: ${NORMAL}" usuario
    usuario=$(_upper "$(_trim "$usuario")")
    if [[ -z "$usuario" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Usuario nao pode ser vazio."
        return 1
    fi
    if ! _usuario_valido "$usuario"; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Usuario invalido. Use apenas letras maiusculas e numeros."
        return 1
    fi
    # Verificar se usuario ja existe
    if _obter_hash_usuario "$usuario" >/dev/null 2>&1; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Usuario ja existe."
        return 1
    fi
    read -rsp "${AMARELO}Digite a senha: ${NORMAL}" senha
    printf "\n"
    read -rsp "${AMARELO}Confirme a senha: ${NORMAL}" senha_confirm
    printf "\n"
    if [[ -z "$senha" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Senha nao pode ser vazia."
        return 1
    fi
    if [[ "$senha" != "$senha_confirm" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Senhas nao coincidem."
        return 1
    fi
    resumo_senha=$(_hash_senha "$senha") || {
        _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao processar senha."
        return 1
    }
    printf '%s:%s\n' "${usuario}" "${resumo_senha}" >> "$arquivo_senhas"
    chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_senhas" 2>/dev/null || {
        _exibir_mensagem_centralizada "${AMARELO}" "AVISO: Nao foi possivel restringir permissoes de ${arquivo_senhas}"
        _log "AVISO: Permissoes de ${arquivo_senhas} nao alteradas"
    }
    _exibir_mensagem_centralizada "${VERDE}" "Usuario cadastrado com sucesso."
    _log "Usuario cadastrado: ${usuario}" "${LOG_ATU:-/dev/null}"
}

# Mostrar tela de boas-vindas apos login bem-sucedido
_mostrar_boas_vindas() {
    local nome_usuario="${1:-}"
    local arquivo_ultimo_acesso="${CFG_DIR}/.ultimo_acesso"
    local usuario_anterior=""
    local data_hora_anterior=""
    if [[ -f "$arquivo_ultimo_acesso" ]]; then
        IFS='|' read -r usuario_anterior data_hora_anterior < "$arquivo_ultimo_acesso"
    fi
    printf "\n"
    _linha "=" "${VERDE}"
    printf "\n"
    _exibir_mensagem_centralizada "${AMARELO}" "Bem-vindo ao Sistema"
    _exibir_separador_menu
    printf "\n"
    _exibir_mensagem_centralizada_a_esquerda "${CIANO}" "Usuario: ${BRANCO}${nome_usuario}${NORMAL}"
    _exibir_mensagem_centralizada_a_esquerda "${CIANO}" "Empresa: ${BRANCO}${CFG_EMPRESA:-N/A}${NORMAL}"
    _exibir_mensagem_centralizada_a_esquerda "${CIANO}" "Versao Iscobol: ${BRANCO}${CFG_VERSAOCLASS}${NORMAL}"
    _exibir_mensagem_centralizada_a_esquerda "${CIANO}" "Versao Atualizacao: ${BRANCO}${UPDATE:-N/A}${NORMAL}"
    _exibir_separador_menu
    if [[ -n "$usuario_anterior" && -n "$data_hora_anterior" ]]; then
        _exibir_mensagem_centralizada_a_esquerda "${CIANO}" "Ultimo Acesso: ${BRANCO}${usuario_anterior} - ${data_hora_anterior}${NORMAL}"
    else
        _exibir_mensagem_centralizada_a_esquerda "${CIANO}" "Ultimo Acesso: ${BRANCO}Primeiro acesso${NORMAL}"
    fi
    _exibir_separador_menu
    printf "\n"
    read -rp "${AMARELO}Pressione ENTER para continuar...${NORMAL}" -t 5 2>/dev/null || true
}

# Funcao para login com rate limiting e migração automática de hashes
_login() {
    local senha resumo_senha hash_armazenado
    local tentativas=1
    local resposta
    local max_tentativas="${MAX_LOGIN_ATTEMPTS:-3}"
    # CORREÇÃO: Resetar variável global no início do login
    usuario=""
    
    # CORREÇÃO: Verificar se o arquivo de senhas existe
    if [[ ! -f "$arquivo_senhas" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nenhum usuario cadastrado. Execute o programa de cadastro primeiro."
        return 1
    fi
    
    if [[ ! -s "$arquivo_senhas" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "ALERTA: Arquivo de senhas esta vazio. Nenhum usuario cadastrado no sistema."
        _exibir_mensagem_centralizada "${AMARELO}" "Execute o programa de cadastro primeiro."
        _linha "-" "${VERMELHO}"
        return 1
    fi
    
    while [[ $tentativas -le $max_tentativas ]]; do
        _exibir_mensagem_centralizada "${VERMELHO}" "Login no Sistema"
        _linha "=" "${VERDE}"
        read -rp "${AMARELO}Usuario: ${NORMAL}" usuario
        usuario=$(_upper "$(_trim "$usuario")")
        if [[ -z "$usuario" ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Nome de usuario nao pode ser vazio."
        elif ! _usuario_valido "$usuario"; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Usuario invalido. Use apenas letras maiusculas e numeros."
        else
            # SEGURANÇA: Verificar bloqueio por rate limiting
            if ! _verificar_bloqueio_usuario "$usuario"; then
                _aguardar_tecla
                return 1
            fi
            
            if ! _usuario_existe "$usuario"; then
                _exibir_mensagem_centralizada "${VERMELHO}" "Usuario nao cadastrado no sistema."
            else
                read -rsp "${AMARELO}Senha: ${NORMAL}" senha
                printf "\n"
                if [[ -z "$senha" ]]; then
                    _exibir_mensagem_centralizada "${VERMELHO}" "Senha nao pode ser vazia."
                else
                    hash_armazenado=$(_obter_hash_usuario "$usuario")
                    if [[ -z "$hash_armazenado" ]]; then
                        _exibir_mensagem_centralizada "${VERMELHO}" "Usuario nao encontrado."
                    else
                        # SEGURANÇA: Verificar formato do hash e migrar se necessário
                        if _hash_precisa_migracao "$hash_armazenado"; then
                            _exibir_mensagem_centralizada "${AMARELO}" "Migracao de seguranca necessaria..."
                            _log "Migracao de hash legado iniciada: ${usuario}" "${LOG_ATU:-/dev/null}"
                            resumo_senha=$(_hash_senha "$senha")
                            if [[ "$resumo_senha" == "$hash_armazenado" ]]; then
                                clear
                                _linha "=" "${VERDE}"
                                _exibir_mensagem_centralizada "${VERDE}" "Login bem-sucedido (migracao pendente)."
                                export usuario
                                _forcar_reset_senha_legado "$usuario" || {
                                    usuario=""
                                    return 1
                                }
                                _mostrar_boas_vindas "$usuario"
                                _remover_registro_tentativas "$usuario"
                                return 0
                            else
                                _exibir_mensagem_centralizada "${VERMELHO}" "Senha incorreta."
                                # CORREÇÃO: Guardar nome antes de limpar para registrar tentativa
                                local usuario_falha="$usuario"
                                usuario=""
                                _registrar_tentativa_falha "$usuario_falha"
                            fi
                        else
                            # SEGURANÇA: Hash com salt - extrair salt e recalcular
                            local salt_armazenado hash_esperado
                            salt_armazenado=$(_extrair_salt "$hash_armazenado")
                            hash_esperado=$(_extrair_hash "$hash_armazenado")
                            
                            resumo_senha=$(_hash_senha "$senha" "$salt_armazenado")
                            local hash_calculado
                            hash_calculado=$(_extrair_hash "$resumo_senha")
                            
                            if [[ "$hash_calculado" == "$hash_esperado" ]]; then
                                clear
                                _linha "=" "${VERDE}"
                                _exibir_mensagem_centralizada "${VERDE}" "Login bem-sucedido."
                                export usuario
                                _mostrar_boas_vindas "$usuario"
                                _remover_registro_tentativas "$usuario"
                                return 0
                            else
                                _exibir_mensagem_centralizada "${VERMELHO}" "Senha incorreta."
                                # CORREÇÃO: Guardar nome antes de limpar para registrar tentativa
                                local usuario_falha="$usuario"
                                usuario=""
                                _registrar_tentativa_falha "$usuario_falha"
                            fi
                        fi
                    fi
                fi
            fi
        fi
        if [[ $tentativas -ge $max_tentativas ]]; then
            _exibir_mensagem_centralizada "${VERMELHO}" "Numero maximo de tentativas atingido."
            _log "Bloqueio por excesso de tentativas: ${usuario:-desconhecido}" "${LOG_ATU:-/dev/null}"
            return 1
        fi
        _linha "-" "${VERDE}"
        read -rp "${AMARELO}Deseja tentar novamente? (s/N): ${NORMAL}" resposta
        if [[ ! "$resposta" =~ ^[sS]$ ]]; then
            return 1
        fi
        ((tentativas++)) || true
        printf "\n"
    done
    return 1
}

# Funcao para alterar senha com hash salt e limpeza segura
_alterar_senha() {
    local senha_atual nova_senha confirm_senha hash_atual hash_nova hash_armazenado
    # CORREÇÃO: Usar ${usuario:-} para evitar unbound variable
    if [[ -z "${usuario:-}" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Voce precisa estar logado para alterar a senha."
        return 1
    fi
    
    # CORREÇÃO: Verificar se o arquivo de senhas existe
    if [[ ! -f "$arquivo_senhas" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Arquivo de senhas nao encontrado."
        return 1
    fi
    
    _exibir_mensagem_centralizada "${VERMELHO}" "Alteracao de Senha"
    _linha "=" "${VERMELHO}"
    read -rsp "${AMARELO}Digite a senha atual: ${NORMAL}" senha_atual
    printf "\n"
    hash_armazenado=$(_obter_hash_usuario "$usuario")
    if [[ -z "$hash_armazenado" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Usuario nao encontrado."
        _linha "-" "${VERMELHO}"
        return 1
    fi
    
    local senha_correta=0
    if _hash_tem_salt "$hash_armazenado"; then
        local salt_armazenado hash_esperado
        salt_armazenado=$(_extrair_salt "$hash_armazenado")
        hash_esperado=$(_extrair_hash "$hash_armazenado")
        
        local hash_atual_completo hash_atual_calculado
        hash_atual_completo=$(_hash_senha "$senha_atual" "$salt_armazenado")
        hash_atual_calculado=$(_extrair_hash "$hash_atual_completo")
        
        if [[ "$hash_atual_calculado" == "$hash_esperado" ]]; then
            senha_correta=1
        fi
    else
        hash_atual=$(_hash_senha "$senha_atual")
        if [[ "$hash_atual" == "$hash_armazenado" ]]; then
            senha_correta=1
        fi
    fi
    
    if (( senha_correta == 0 )); then
        _exibir_mensagem_centralizada "${VERMELHO}" "Senha atual incorreta."
        _linha "-" "${VERMELHO}"
        return 1
    fi
    
    read -rsp "${AMARELO}Digite a nova senha: ${NORMAL}" nova_senha
    printf "\n"
    read -rsp "${AMARELO}Confirme a nova senha: ${NORMAL}" confirm_senha
    printf "\n"
    if [[ -z "$nova_senha" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Nova senha nao pode ser vazia."
        return 1
    fi
    if [[ "$nova_senha" != "$confirm_senha" ]]; then
        _exibir_mensagem_centralizada "${VERMELHO}" "Novas senhas nao coincidem."
        return 1
    fi
    hash_nova=$(_hash_senha "$nova_senha") || {
        _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao processar nova senha."
        return 1
    }
    
    local tmp_senhas
    tmp_senhas=$(mktemp) || {
        _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao criar arquivo temporario para atualizacao de senha."
        return 1
    }
    trap 'rm -f -- "$tmp_senhas"' RETURN
    
    while IFS= read -r linha || [[ -n "$linha" ]]; do
        if [[ "$linha" == "${usuario}:"* ]]; then
            printf '%s:%s\n' "${usuario}" "${hash_nova}"
        else
            printf '%s\n' "$linha"
        fi
    done < "$arquivo_senhas" > "$tmp_senhas"
    
    if mv -f "$tmp_senhas" "$arquivo_senhas"; then
        chmod "${PERM_FILE_PRIVATE:-0600}" "$arquivo_senhas" 2>/dev/null || true
        trap - RETURN
        _exibir_mensagem_centralizada "${VERDE}" "Senha alterada com sucesso."
        _log "Senha alterada: ${usuario}" "${LOG_ATU:-/dev/null}"
    else
        rm -f -- "$tmp_senhas"
        trap - RETURN
        _exibir_mensagem_centralizada "${VERMELHO}" "Erro ao salvar nova senha."
        return 1
    fi
}