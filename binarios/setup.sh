#!/usr/bin/env bash
#
# setup.sh - Gerencia a configuracao do sistema
# Este script gerencia a criacao e a edicao dos arquivos de configuracao
# .config, que e essencial para o funcionamento do sistema.
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# Modos de Operacao:
#   ./atualiza.sh --setup          - Configuracao inicial interativa
#   ./atualiza.sh --setup --edit   - Edicao das configuracoes existentes
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 01/06/2026-01

#---------- FUNCAO DE LOGICA DE NEGOCIO ----------#
# Variaveis globais esperadas
verclass="${verclass:-}"           # Versao do IsCobol (ex: 2018, 2020, 2023, 2024, 2025)


# =============================================================================
# CARREGAR CONSTANTES DO SISTEMA
# =============================================================================

# Carregar constantes se disponivel
_contantes() {
if [[ -f "${LIBS_DIR}/constantes.sh" ]]; then
    "." "${LIBS_DIR}/constantes.sh"
fi
}

# Variáveis globais
declare -l sistema base base2 base3 dbmaker enviabackup
declare -u empresa

# Limpar tela
_limpa_tela() {
    clear
}

# Diretorio do servidor offline
# Configuracao inicial do sistema
_initial_setup() {
    _limpa_tela
    _contantes
    
    local tracejada="#-------------------------------------------------------------------#"
    local traco="#####################################################################"

    # Header inicial
    echo "$traco"
    echo "###      ( Parametros para serem usados no atualiza.sh )          ###"
    echo "$traco"
    # Criar arquivo de configuracao
    {
        echo "$traco"
        echo "###      ( Parametros para serem usados no atualiza.sh )          ###"
        echo "$traco"
    } > .config

    # Selecionar sistema (IsCobol ou Microfocus)
    echo "Em qual sistema o SAV esta rodando?"
    echo "1) Iscobol"
    echo "2) Microfocus"
    read -n1 -rp "Escolha o sistema: " escolha
    echo

    case "$escolha" in
        1) _setup_iscobol ;;
        2) _setup_cobol ;;
        *)
            echo "Alternativa incorreta, saindo!"
            sleep 1
            return 1
            ;;
    esac

    # Configuracoes adicionais
    _setup_banco_de_dados
    _setup_diretorios
    _setup_acesso_remoto
    _setup_offline
    _setup_backup
    _setup_empresa

    # Criar atalho global (requer permissao de root)
    if [[ $EUID -eq 0 ]]; then
        cat > /usr/local/bin/atualiza <<'EOF'
cd "${SCRIPT_DIR:-SCRIPT_DIR}"
./atualiza.sh
EOF

        chmod +x /usr/local/bin/atualiza
        echo "Atalho /usr/local/bin/atualiza criado com sucesso."
    else
        echo "AVISO: Sem permissao de root. Atalho global nao criado."
        echo "Execute 'sudo ${SCRIPT_DIR}/atualiza.sh --setup' para criar o atalho."
    fi

    echo "Pronto!"
}

# Edicao de configuracoes existentes
_edit_setup() {
    local tracejada="#-------------------------------------------------------------------#"
    _contantes
    # Mover para o diretorio de configuracao
    cd "${CFG_DIR}" || {
        echo "Erro: Diretorio 'configuracoes' nao encontrado."
        return 1
    }

    # Verificar se os arquivos de configuracao existem
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        echo "Arquivos de configuracao nao encontrados. Execute o setup inicial primeiro."
        return 1
    fi
    clear 
    echo "=================================================="
    echo "Carregando parametros para edicao..."
    echo "=================================================="

    # Carregar configuracoes existentes
    "." ./.config

    # Fazer backup
    cp .config .config.bkp

    # Edicao interativa das variaveis
    _editar_variavel sistema
    _editar_variavel verclass
    _editar_variavel dbmaker
    _editar_variavel acessossh
    _editar_variavel Offline
    if [[ "${Offline}" == "n" ]]; then
        _editar_variavel enviabackup
    fi
    _editar_variavel empresa
    _editar_variavel base
    _editar_variavel base2
    _editar_variavel base3

    # Recriar arquivos de configuracao
     _recreate_config_files

    echo "Arquivo .config atualizado com sucesso!"

    # Configurar SSH se habilitado
    if [[ "${acessossh}" == "s" ]]; then
        _configure_ssh_access
    fi

    echo "$tracejada"
    read -rp "Pressione Enter para sair..."
    _limpa_tela
    return 0
}

#---------- FUNcoES DE SETUP INICIAL ----------#

# Configuracao para IsCobol
_setup_iscobol() {
    # CORRECAO: tracejada era usada sem estar definida no escopo desta funcao
    local tracejada="#-------------------------------------------------------------------#"
    sistema="iscobol"
    echo "sistema=iscobol" >> .config
    echo "$tracejada"
    echo "Escolha a versao do Iscobol:"
    echo "1) Versao 2020"
    echo "2) Versao 2023"
    echo "3) Versao 2024"
    echo "4) Versao 2025"
    echo "5) Versao 2026"
    read -rp "Escolha a versao -> " -n1 VERSAO
    echo

    case "$VERSAO" in
        1) _2020 ;;
        2) _2023 ;;
        3) _2024 ;;
        4) _2025 ;;
        5) _2026 ;;
        *)
            echo "Alternativa incorreta, saindo!"
            sleep 1
            _limpa_tela
            return 1
            ;;
    esac

    }


# Configuracao para Micro Focus Cobol
_setup_cobol() {
    sistema="cobol"
    {
        echo "sistema=cobol"
    } >> .config
}
# Funcoes de versao do IsCobol
_2020() {
    {
        echo "verclass=2020"
    } >> .config
    verclass="2020"
}
_2023() {
    {
        echo "verclass=2023"
    } >> .config
    verclass="2023"
}
_2024() {
    {
        echo "verclass=2024"
    } >> .config
    verclass="2024"
}

_2025() {
    {
        echo "verclass=2025"
    } >> .config
    verclass="2025"
}
_2026() {
    {
        echo "verclass=2026"
    } >> .config
    verclass="2026"
}
# Configuracoes adicionais
_setup_banco_de_dados() {
    echo "$tracejada"
    while true; do
        read -rp "Sistema em banco de dados [S/N]: " -n1 dbmaker
        echo
        if [[ "${dbmaker,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada inválida. Digite S ou N."
        fi
    done
    if [[ "${dbmaker,,}" == "s" ]]; then
        echo "dbmaker=s" >> .config
    else
        echo "dbmaker=n" >> .config
    fi
}
_setup_diretorios() {
    echo ${tracejada}
    echo "###     ( Nome de pasta no servidor )              ###"
    read -rp "Nome da pasta da base de dados principal (Ex: /dados_jisam): " base
    base="${base:-/dados_jisam}"
    echo "base=${base}" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da segunda base de dados (Opcional): " base2
    [[ -n "$base2" ]] && echo "base2=${base2}" >> .config || echo "#base2=" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da terceira base de dados (Opcional): " base3
    [[ -n "$base3" ]] && echo "base3=${base3}" >> .config || echo "#base3=" >> .config
    echo ${tracejada}
}
_setup_acesso_remoto() {
    echo "###      ( FACILITADOR DE ACESSO REMOTO )         ###"
    while true; do
        read -rp "Ativar acesso facil (SSH) [S/N]: " -n1 acessossh
        echo
        if [[ "${acessossh,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada invalida. Digite S ou N."
        fi
    done
    if [[ "${acessossh,,}" == "s" ]]; then
        echo "acessossh=s" >> .config
    else
        echo "acessossh=n" >> .config
    fi
    echo ${tracejada}
}    
_setup_offline() {    
    echo "###      ( Tipo de acesso        )         ###"
    while true; do
        read -rp "Servidor OFF [S/N]: " -n1 opt 
        echo
        if [[ "${opt,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada invalida. Digite S ou N."
        fi
    done
    if [[ "${opt,,}" == "s" ]]; then
        Offline="s"
        echo "Offline=s" >> .config
    else
        Offline="n"
        echo "Offline=n" >> .config
    fi
}
_setup_backup() {
    echo "${tracejada}"
    if [[ "${Offline,,}" == "s" ]]; then
        echo "###     ( Modo Offline Ativado )                ###"
        echo "###     Backup local sera criado na pasta do script ###"
        echo "###     O backup deve ser enviado manualmente para a SAV ###"
        echo "${tracejada}"
        
        # Define automaticamente o caminho do backup offline na memória e no arquivo
        enviabackup=""
        echo "enviabackup=" >> .config
        echo "Diretorio de backup offline sera determinado pelo sistema."
        
    else
        echo "###     ( Nome de pasta no servidor da SAV )                ###"
        echo "Informe o nome da pasta no servidor da SAV (somente o nome inicial do cliente)"
        echo "Exemplo: para o cliente 'Fulano', digite somente 'fulano'"
        echo "${tracejada}"
        
        read -rp "Nome do diretorio sem a /: " enviabackup
        
        # Monta o caminho completo esperado e salva
        enviabackup="/cliente/${enviabackup}_jisam"
        echo "enviabackup=${enviabackup}" >> .config
    fi
}

_setup_empresa() {
    echo ${tracejada}
    echo "###     ( NOME DA empresa )                   ###"
    echo "###   Nao pode conter espacos entre os nomes    ###"
    echo ${tracejada}
    read -rp "Nome da Empresa (sem espacos): " empresa
    echo "empresa=${empresa}" >> .config
    _configure_ssh_access
}


#---------- FUNCOES DE EDICAO ----------#

# Edita uma variavel de forma interativa
_editar_variavel() {
    local nome="$1"
    local valor_atual="${!nome}"
    local tracejada="#-------------------------------------------------------------------#"

    while true; do
        read -rp "Deseja alterar ${nome} (valor atual: ${valor_atual})? [s/N] " alterar
        if [[ "${alterar,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada inválida. Digite S ou N."
        fi
    done
    if [[ "${alterar,,}" == "s" ]]; then
        case "$nome" in
            "sistema")
                echo "1) IsCobol"
                echo "2) Micro Focus Cobol"
                read -rp "Opcao [1-2]: " opt
                [[ "$opt" == "1" ]] && sistema="iscobol"
                [[ "$opt" == "2" ]] && sistema="cobol"
                ;;
            "dbmaker"|"acessossh")
                while true; do
                    read -rp "Novo valor [s/n]: " opt
                    if [[ "${opt,,}" =~ ^[sn]$ ]]; then
                        [[ "${opt,,}" == "s" ]] && declare -g "$nome"="s"
                        [[ "${opt,,}" == "n" ]] && declare -g "$nome"="n"
                        break
                    else
                        echo "Entrada inválida. Digite s ou n."
                    fi
                done
                ;;
            "Offline")
                while true; do
                    read -rp "Sistema em modo Offline? [s/n]: " opt            
                    if [[ "${opt,,}" =~ ^[sn]$ ]]; then
                        [[ "${opt,,}" == "s" ]] && declare -g "Offline"="s" 
                        echo "enviabackup=" >> .config
                        [[ "${opt,,}" == "n" ]] && declare -g "Offline"="n"
                        break
                    else
                        echo "Entrada inválida. Digite s ou n."
                    fi
                done
                ;;

            *)
                read -rp "Novo valor para ${nome}: " novo_valor
                declare -g "$nome"="$novo_valor"
                ;;
        esac
    fi
    echo "$tracejada"
}

# Recria os arquivos de configuracao
_recreate_config_files() {
    local tracejada="#-------------------------------------------------------------------#"
    echo "Recriando arquivos de configuracao..."

    {
        echo "sistema=${sistema}"
        [[ -n "$verclass" ]] && echo "verclass=${verclass}"
        echo "dbmaker=${dbmaker}"
        echo "acessossh=${acessossh}"
        echo "Offline=${Offline}"
        echo "enviabackup=${enviabackup}"
        echo "empresa=${empresa}"
        echo "base=${base}"
        [[ -n "$base2" ]] && echo "base2=${base2}" || echo "#base2="
        [[ -n "$base3" ]] && echo "base3=${base3}" || echo "#base3="
    } > .config
    echo "$tracejada"
}

#---------- FUNCOES AUXILIARES ----------#
# Configura acesso SSH facilitado
#===================================================================

_configure_ssh_access() {
    local DEFAULT_IP_SERVER="${DEFAULT_IP_SERVER:-${DEFAULT_IP_SERVER}}"
    local DEFAULT_SSH_PORTA="${DEFAULT_SSH_PORTA:-${DEFAULT_SSH_PORTA}}"
    local DEFAULT_SSH_USER="${DEFAULT_SSH_USER:-${DEFAULT_SSH_USER}}"
    local SSH_DIR="${HOME}/.ssh"
    local SSH_USER="${sshuser:-$(logname 2>/dev/null || whoami)}"

if ! id "${SSH_USER}" >/dev/null 2>&1; then
    echo "Erro: usuario ${SSH_USER} nao existe."
    return 1
fi

local USER_HOME
USER_HOME="$(getent passwd "${SSH_USER}" | cut -d: -f6)"

if [[ -z "${USER_HOME}" ]]; then
    echo "Erro: nao foi possivel localizar HOME do usuario ${SSH_USER}"
    return 1
fi

    local SSH_DIR="${USER_HOME}/.ssh"
    local SSH_CONFIG_FILE="${SSH_DIR}/config"
    local CONTROL_PATH_BASE="${SSH_DIR}/control"

    # Validacao das variaveis obrigatorias
    if [[ -z "${DEFAULT_IP_SERVER}" ]]; then
        echo "Erro: Variavel DEFAULT_IP_SERVER nao foi definida."
        return 1
    fi

    # Cria os diretorios padrao
    mkdir -p "${SSH_DIR}" "${CONTROL_PATH_BASE}"
#        if [[ "$(stat -c %U "${SSH_DIR}" 2>/dev/null)" != "$(whoami)" ]]; then
        echo "Ajustando proprietario de ${SSH_DIR}..."
        sudo chown -R "$(whoami):$(id -gn)" "${SSH_DIR}"
        sudo chown -R "${SSH_USER}:${SSH_USER}" 
#        fi
        
    chmod "${PERM_DIR_SECURE}" "${SSH_DIR}" "${CONTROL_PATH_BASE}"

    # ====================== CRIA NOVO ARQUIVO ~/.ssh/config ======================
    echo "Criando novo arquivo de configuracao SSH em ${SSH_CONFIG_FILE}..."

    cat > "${SSH_CONFIG_FILE}" << EOF
# ================================================
# Configuracao SAV - Gerada automaticamente
# Data: $(date '+%d/%m/%Y %H:%M:%S')
# ================================================

Host sav_servidor
    HostName ${DEFAULT_IP_SERVER}
    Port ${DEFAULT_SSH_PORTA}
    User ${DEFAULT_SSH_USER}
    ControlMaster auto
    ControlPath ${CONTROL_PATH_BASE}/%r@%h:%p.sock 
    ControlPersist 10m
    ServerAliveInterval ${SSH_ALIVE_INTERVAL}
    ServerAliveCountMax ${SSH_ALIVE_COUNT}
    ConnectTimeout ${SSH_TIMEOUT}
EOF

    chmod "${PERM_FILE_PRIVATE}" "${SSH_CONFIG_FILE}"
    echo "Novo arquivo ~/.ssh/config criado com sucesso!"

# ============================================
if [[ ! -f "${SSH_DIR}/id_ed25519" ]]; then
    echo "Criando chave SSH para ${SSH_USER}..."

    sudo -u "${SSH_USER}" ssh-keygen \
        -t ed25519 \
        -f "${SSH_DIR}/id_ed25519" \
        -N "" \
        -C "${DEFAULT_SSH_USER}@${DEFAULT_IP_SERVER}"

    chmod 600 "${SSH_DIR}/id_ed25519"
    chmod 644 "${SSH_DIR}/id_ed25519.pub"

    echo "Chave criada com sucesso."
fi

touch "${SSH_DIR}/authorized_keys"

chown "${SSH_USER}:${SSH_USER}" \
    "${SSH_DIR}/authorized_keys"

chmod 600 "${SSH_DIR}/authorized_keys"

    # ====================== TESTE DE CONEXAO ======================
    echo
    echo "Testando conexao com o servidor SAV (${DEFAULT_IP_SERVER})..."

    if ssh -o BatchMode=yes sav_servidor exit 2>/dev/null; then
        echo "Conexao SSH estabelecida com sucesso!"
        return 0
    fi

    # Primeira conexao - modo interativo
    echo "Primeira conexao: confirme a identidade do servidor abaixo."
    echo "   (Digite 'yes' quando aparecer a mensagem de fingerprint)"
    echo

    if ssh sav_servidor exit; then
        echo "Servidor autenticado e fingerprint adicionado ao known_hosts."
        return 0
    else
        echo "Erro: nao foi possivel conectar ao servidor."
        echo "   Verifique:"
        echo "     - Porta ${DEFAULT_SSH_PORTA} liberada"
        echo "     - Usuario '${DEFAULT_SSH_USER}' existe no servidor remoto"
        echo "     - Firewall permite a conexao"
        return 1
    fi
}

#---------- PONTO DE ENTRADA PRINCIPAL ----------#

# Funcao principal que direciona para o modo correto
main() {

# Diretorio do script (compativel com chamada direta ou via atualiza.sh)
# Quando chamado diretamente de /binarios, sobe um nivel para o diretorio do atualiza.sh
    if [[ -z "${SCRIPT_DIR}" ]]; then
        _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

cd "${SCRIPT_DIR}" || return 1

# Verifica se o diretorio processos existe
    if [[ ! -d "${LIBS_DIR}" ]]; then
        echo "ERRO: Diretorio ${LIBS_DIR} nao encontrado."
        return 1
    fi

# Verifica se o diretorio configuracoes existe
    if [[ ! -d "${CFG_DIR}" ]]; then
        echo "ERRO: Diretorio ${CFG_DIR} nao encontrado."
        return 1
    fi

    # Verificar modo de operacao
    if [[ "$1" == "--edit" ]]; then
        _edit_setup
    else
        # Verificar se os arquivos de configuracao ja existem

        if [[ -f "${CFG_DIR}/.config" ]]; then
            _limpa_tela
            echo "Arquivos de configuracao ja existem."
            while true; do
                read -rp "Deseja sobrescrevê-los com a configuracao inicial? [s/N]: " choice
                if [[ "${choice,,}" =~ ^[sn]$ ]]; then
                    break
                else
                    echo "Entrada inválida. Digite S ou N."
                fi
            done
            if [[ "${choice,,}" == "s" ]]; then
			    (
                cd "${CFG_DIR}" || return 1
                _initial_setup
				)
            else
                echo "Operacao cancelada. Use './atualiza.sh --setup --edit' para modificar."
            fi
        else
            mkdir -p "${CFG_DIR}"
			(
            cd "${CFG_DIR}" || return 1
            _initial_setup
			)
        fi
    fi
    return 0
}

# Executar a funcao principal
main "$@"
