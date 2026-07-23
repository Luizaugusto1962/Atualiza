#!/usr/bin/env bash
set -euo pipefail
#
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
# Versao: 21/07/2026-01
#---------- FUNCAO DE LOGICA DE NEGOCIO ----------#
# Variaveis globais esperadas
verclass="${verclass:-}"           # Versao do IsCobol (ex: 2018, 2020, 2023, 2024, 2025)

# Funcao de saida padronizada (local, sem dependencia de modulos)
_encerrar_programa() {
    local status="${1:-0}"
    exit "$status"
}

# =============================================================================
# CARREGAR CONSTANTES DO SISTEMA
# =============================================================================

# Carregar constantes se disponivel
_carregar_constantes_setup() {
if [[ -f "${LIBS_DIR}/constantes.sh" ]]; then
    "." "${LIBS_DIR}/constantes.sh"
fi
}

# Variaveis globais usadas pelas funcoes de setup
# (normalizacao de caso e feita explicitamente nas funcoes)

tracejada="#-------------------------------------------------------------------#"
traco="#####################################################################"

# Diretorio do servidor offline
# Configuracao inicial do sistema
_initial_setup() {
    _limpa_tela
    _carregar_constantes_setup

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

    # Configuracoes adicionais
    _setup_iscobol
    _setup_diretorios
    _setup_acesso_remoto
    _setup_chave_acesso
    _setup_offline
    _setup_backup
    _setup_empresa

    # Criar atalho global (requer permissao de root)
    if [[ $EUID -eq 0 ]]; then
        printf 'cd %s\n./atualiza.sh\n' "${SCRIPT_DIR}" > /usr/local/bin/atualiza
        chmod "${PERM_FILE_EXEC:-0755}" /usr/local/bin/atualiza
        printf "%s\n" "Atalho /usr/local/bin/atualiza criado com sucesso."
    else
        printf "%s\n" "AVISO: Sem permissao de root. Atalho global nao criado."
        printf "Execute 'sudo %s/atualiza.sh --setup' para criar o atalho.\n" "${SCRIPT_DIR}"
    fi

    echo "Pronto!"
}

# Edicao de configuracoes existentes
_edit_setup() {
    local tracejada="#-------------------------------------------------------------------#"
    _carregar_constantes_setup
    # Mover para o diretorio de configuracao
    cd "${CFG_DIR}" || {
        echo "Erro: Diretorio 'configuracoes' nao encontrado."
        _encerrar_programa 1
    }

    # Verificar se os arquivos de configuracao existem
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        echo "Arquivos de configuracao nao encontrados. Execute o setup inicial primeiro."
        _encerrar_programa 1
    fi
    clear
    echo "=================================================="
    echo "Carregando parametros para edicao..."
    echo "=================================================="

    # Carregar configuracoes existentes
    if command -v _carregar_config_seguro >/dev/null 2>&1; then
        _carregar_config_seguro ./.config
    else
        echo "ERRO: Parser seguro de configuracao nao disponivel. Carregamento bloqueado." >&2
        _encerrar_programa 1
    fi

    # Fazer backup
    cp .config .config.bkp

    # Edicao interativa das variaveis
    _editar_variavel verclass
    _editar_variavel acessossh
    _editar_variavel chavessh
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
    _encerrar_programa 0
}

#---------- FUNcoES DE SETUP INICIAL ----------#

# Configuracao para IsCobol
_setup_iscobol() {
    local VERSAO
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
            _encerrar_programa 1
            ;;
    esac

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

_setup_diretorios() {
    echo ${tracejada}
    echo "###     ( Nome de pasta no servidor )              ###"
    read -rp "Nome da pasta da base de dados principal (Ex: /dados_jisam): " base
    base="${base:-/dados_jisam}"
    base="${base,,}"  # Normalizar para minusculo
    echo "base=${base}" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da segunda base de dados (Opcional): " base2
    base2="${base2,,}"  # Normalizar para minusculo
    [[ -n "$base2" ]] && echo "base2=${base2}" >> .config || echo "#base2=" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da terceira base de dados (Opcional): " base3
    base3="${base3,,}"  # Normalizar para minusculo
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
_setup_chave_acesso() {
    echo "###      ( FACILITADOR DE CHAVE DE ACESSO REMOTO )         ###"
    while true; do
        read -rp "Permiti chaves de acesso [S/N]: " -n1 chavessh
        echo
        if [[ "${chavessh,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada invalida. Digite S ou N."
        fi
    done
    if [[ "${chavessh,,}" == "s" ]]; then
        echo "chavessh=s" >> .config
    else
        echo "chavessh=n" >> .config
    fi
    echo "${tracejada}"
}

_setup_offline() {
    local opt
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
        enviabackup="${enviabackup,,}"  # Normalizar para minusculo
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
    empresa="${empresa^^}"  # Normalizar para maiusculo
    echo "empresa=${empresa}" >> .config
    _configure_ssh_access
}


#---------- FUNCOES DE EDICAO ----------#

# Edita uma variavel de forma interativa
_editar_variavel() {
    local nome="$1"
    local valor_atual="${!nome}"
    local tracejada="#-------------------------------------------------------------------#"
    local alterar opt novo_valor

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
            "acessossh"|"chavessh"|"Offline")
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
            *)
                read -rp "Novo valor para ${nome}: " novo_valor
                # Aplicar normalizacao de caso conforme a variavel
                case "$nome" in
                    "base"|"base2"|"base3"|"enviabackup")
                        novo_valor="${novo_valor,,}"  # Normalizar para minusculo
                        ;;
                    "empresa")
                        novo_valor="${novo_valor^^}"  # Normalizar para maiusculo
                        ;;
                esac
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
        echo "verclass=${verclass}"
        echo "acessossh=${acessossh}"
        echo "chavessh=${chavessh}"
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
# _configure_ssh_access - Versão FINAL com SSH no diretório padrão ~/.ssh
#===================================================================
#===================================================================
# _configure_ssh_access - Cria novo arquivo SSH config
#===================================================================
_configure_ssh_access() {
    local ip_server="${DEFAULT_IP_SERVER}"
    local porta_ssh="${DEFAULT_SSH_PORTA}"
    local user_ssh="${DEFAULT_SSH_USER}"
    local SSH_DIR="${HOME}/.ssh"
    local SSH_CONFIG_FILE="${SSH_DIR}/config"
    local CONTROL_PATH_BASE="${SSH_DIR}/control"

    # Validacao das variaveis obrigatorias
    if [[ -z "${ip_server}" ]]; then
        echo "Erro: Variavel DEFAULT_IP_SERVER nao foi definida."
        return 1
    fi

    # Cria os diretorios padrao
    mkdir -p "${SSH_DIR}" "${CONTROL_PATH_BASE}"
    chmod "${PERM_DIR_SECURE}" "${SSH_DIR}" "${CONTROL_PATH_BASE}"

    # ====================== CRIA NOVO ARQUIVO ~/.ssh/config ======================
    echo "Criando novo arquivo de configuracao SSH em ${SSH_CONFIG_FILE}..."

    cat > "${SSH_CONFIG_FILE}" << EOF
# ================================================
# Configuracao SAV - Gerada automaticamente
# Data: $(date '+%d/%m/%Y %H:%M:%S')
# ================================================

Host sav_servidor
    HostName ${ip_server}
    Port ${porta_ssh}
    User ${user_ssh}
    ControlMaster auto
    ControlPath ${CONTROL_PATH_BASE}/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval ${SSH_ALIVE_INTERVAL}
    ServerAliveCountMax ${SSH_ALIVE_COUNT}
    ConnectTimeout ${SSH_TIMEOUT}
EOF

    chmod "${PERM_FILE_PRIVATE}" "${SSH_CONFIG_FILE}"
    echo "Novo arquivo ~/.ssh/config criado com sucesso!"

    # ====================== TESTE DE CONEXAO ======================
    echo
    echo "Testando conexao com o servidor SAV (${ip_server})..."

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
        echo "     - Porta ${porta_ssh} liberada"
        echo "     - Usuario '${user_ssh}' existe no servidor remoto"
        echo "     - Firewall permite a conexao"
        return 1
    fi
}

#---------- PONTO DE ENTRADA PRINCIPAL ----------#

# Funcao principal que direciona para o modo correto
main() {

# Diretorio do script (compativel com chamada direta ou via atualiza.sh)
# Quando chamado diretamente de /binarios, sobe um nivel para o diretorio do atualiza.sh
    if [[ -z "${SCRIPT_DIR:-}" ]]; then
        local _self_dir
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

cd "${SCRIPT_DIR}" || _encerrar_programa 1

# Verifica se o diretorio processos existe
    if [[ ! -d "${LIBS_DIR}" ]]; then
        echo "ERRO: Diretorio ${LIBS_DIR} nao encontrado."
        _encerrar_programa 1
    fi

# Verifica se o diretorio configuracoes existe
    if [[ ! -d "${CFG_DIR}" ]]; then
        echo "ERRO: Diretorio ${CFG_DIR} nao encontrado."
        _encerrar_programa 1
    fi

    # Carregar modulos necessarios
    if [[ -f "${LIBS_DIR}/utils.sh" ]]; then
        "." "${LIBS_DIR}/utils.sh"
    else
        echo "ERRO: utils.sh nao encontrado em ${LIBS_DIR}"
        _encerrar_programa 1
    fi

    # Verificar modo de operacao
    if [[ "${1:-}" == "--edit" ]]; then
        _edit_setup
    else
        # Verificar se os arquivos de configuracao ja existem

        if [[ -f "${CFG_DIR}/.config" ]]; then
            _limpa_tela
            echo "Arquivos de configuracao ja existem."
            local choice
            while true; do
                read -rp "Deseja sobrescrevê-los com a configuracao inicial? [s/N]: " choice
                if [[ "${choice,,}" =~ ^[sn]$ ]]; then
                    break
                else
                    echo "Entrada inválida. Digite S ou N."
                fi
            done
            if [[ "${choice,,}" == "s" ]]; then
                cd "${CFG_DIR}" || _encerrar_programa 1
                _initial_setup
            else
                echo "Operacao cancelada. Use './atualiza.sh --setup --edit' para modificar."
                _encerrar_programa 0
            fi
        else
            mkdir -p "${CFG_DIR}"
            cd "${CFG_DIR}" || _encerrar_programa 1
            _initial_setup
        fi
    fi
}

# Executar a funcao principal
main "$@"
