#!/usr/bin/env bash
#
# setup.sh - Gerencia a configuracao do sistema
# Este script gerencia a criacao e a edicao dos arquivos de configuracao
# .config, que e essencial para o funcionamento do sistema.
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# Modos de Operacao:
#   ./atualiza.sh --setup          - Configuracao inicial interativa
#   ./atualiza.sh --setup --edit   - Edicao das configuracoes existentes
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 16/04/2026-02

#---------- FUNCAO DE LOGICA DE NEGOCIO ----------#
# Variaveis globais esperadas
verclass="${verclass:-}"

# Variáveis globais
declare -l sistema base base2 base3 dbmaker enviabackup
declare -u empresa
ip_do_server="${ip_do_server:-179.94.20.40}"
# Limpar tela
_limpa_tela() {
    clear
}

# Diretorio do servidor offline
# Configuracao inicial do sistema
_initial_setup() {
    _limpa_tela

    # Constantes
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
            exit 1
            ;;
    esac

    # Configuracoes adicionais
    _setup_banco_de_dados
    _setup_diretorios
    _setup_acesso_remoto
    _setup_backup
    _setup_empresa

    # Criar atalho global
    echo "cd ${SCRIPT_DIR:-SCRIPT_DIR}" > /usr/local/bin/atualiza
    echo "./atualiza.sh" >> /usr/local/bin/atualiza
    chmod +x /usr/local/bin/atualiza

    echo "Pronto!"
}

# Edicao de configuracoes existentes
_edit_setup() {
    local tracejada="#-------------------------------------------------------------------#"

    # Mover para o diretorio de configuracao
    cd "${cfg_dir}" || {
        echo "Erro: Diretorio 'cfg' nao encontrado."
        exit 1
    }

    # Verificar se os arquivos de configuracao existem
    if [[ ! -f "${cfg_dir}/.config" ]]; then
        echo "Arquivos de configuracao nao encontrados. Execute o setup inicial primeiro."
        exit 1
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
    _editar_variavel ipserver
    _editar_variavel Offline
    _editar_variavel enviabackup
    _editar_variavel empresa
    _editar_variavel base
    _editar_variavel base2
    _editar_variavel base3

    # Recriar arquivos de configuracao
    _recreate_config_files

    echo "Arquivos .config atualizado com sucesso!"

    # Configurar SSH se habilitado
    if [[ "${acessossh}" == "s" ]]; then
        _configure_ssh_access
    fi

    echo "$tracejada"
    read -rp "Pressione Enter para sair..."
    exit 0
}

#---------- FUNcoES DE SETUP INICIAL ----------#

# Configuracao para IsCobol
_setup_iscobol() {
    sistema="iscobol"
    echo "sistema=iscobol" >> .config
    echo "$tracejada"
    echo "Escolha a versao do Iscobol:"
    echo "1) Versao 2018"
    echo "2) Versao 2020"
    echo "3) Versao 2023"
    echo "4) Versao 2024"
    echo "5) Versao 2025"
    read -rp "Escolha a versao -> " -n1 VERSAO
    echo

    case "$VERSAO" in
        1) _2018 ;;
        2) _2020 ;;
        3) _2023 ;;
        4) _2024 ;;
        5) _2025 ;;
        *)
            echo "Alternativa incorreta, saindo!"
            sleep 1
            exit 1
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
_2018() {
    {
        echo "verclass=2018"
    } >> .config
    verclass="2018"
}
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
    read -rp "Nome da pasta da base de dados (Ex: /dados_jisam) [/dados_jisam]: " base
    base="${base:-/dados_jisam}"
    echo "base=${base}" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da segunda base  (Opcional): " base2
    [[ -n "$base2" ]] && echo "base2=${base2}" >> .config || echo "#base2=" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da terceira base (Opcional): " base3
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
    echo "###      ( IP do servidor da SAV )         ###"
    read -rp "Informe o IP do servidor [${ip_do_server}]: " ipserver
    ipserver="${ipserver:-${ip_do_server}}"
    echo "ipserver=${ipserver}" >> .config
    echo "IP do servidor: ${ipserver}"
    echo ${tracejada}

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
    if [[ "${Offline}" == "s" ]]; then
        echo ${tracejada}
        echo "###     ( Modo Offline Ativado )                ###"
        echo "###     Backup local sera criado na pasta do script ###"
        echo "###     O backup deve ser enviado manualmente para a SAV ###"
        echo ${tracejada}
        echo "enviabackup=${acessoff}" >> .config
        return
    else
        echo ${tracejada}
        echo "###     ( Nome de pasta no servidor da SAV )                ###"
        echo "Nome de pasta no servidor da SAV, informar somento o nome do cliente"
        read -rp "(Ex: cliente/\"NOME_da_pasta_do_CLIENTE\"): " enviabackup
        echo "enviabackup=/cliente/${enviabackup}_jisam" >> .config
    fi
}
_setup_empresa() {
    echo ${tracejada}
    echo "###     ( NOME DA empresa )                   ###"
    echo "###   Nao pode conter espacos entre os nomes    ###"
    echo ${tracejada}
    read -rp "Nome da Empresa (sem espacos): " empresa
    echo "empresa=${empresa}" >> .config
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
                    read -rp "Novo valor (s/n): " opt
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
                    read -rp "Sistema em modo Offline? (s/n): " opt            
                    if [[ "${opt,,}" =~ ^[sn]$ ]]; then
                        [[ "${opt,,}" == "s" ]] && declare -g "Offline"="s"
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
        echo "ipserver=${ipserver}"
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
_configure_ssh_access() {
    local SERVER_IP="${ipserver}"
    local SERVER_PORTA="${SERVER_PORTA:-41122}"
    local SERVER_USER="${USUARIO:-atualiza}"
    local SSH_DIR="${HOME}/.ssh"
    local SSH_CONFIG_FILE="${SSH_DIR}/config"
    local CONTROL_PATH_BASE="${SSH_DIR}/control"

    # Validação das variáveis obrigatórias
    if [[ -z "${SERVER_IP}" ]]; then
        echo "Erro: Variavel 'ipserver' nao foi definida."
        return 1
    fi

    # Cria os diretórios padrão com permissões corretas
    mkdir -p "${SSH_DIR}" "${CONTROL_PATH_BASE}"
    chmod 0755 "${SSH_DIR}" "${CONTROL_PATH_BASE}"

    # ====================== CRIAÇÃO / ATUALIZAÇÃO DO ARQUIVO ~/.ssh/config ======================
    if [[ ! -f "${SSH_CONFIG_FILE}" ]] || ! grep -q "^Host sav_servidor" "${SSH_CONFIG_FILE}"; then
        cat >> "${SSH_CONFIG_FILE}" << EOF

# ================================================
# Configuração SAV - Gerada automaticamente
# ================================================
Host sav_servidor
    HostName ${SERVER_IP}
    Port ${SERVER_PORTA}
    User ${SERVER_USER}
#   StrictHostKeyChecking accept-new
    ControlMaster auto
    ControlPath ${CONTROL_PATH_BASE}/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 15
EOF
        chmod 0600 "${SSH_CONFIG_FILE}"
        echo "Configuracao SSH criada/adicionada em ~/.ssh/config"
    else
        echo " Configuracao SSH 'sav_servidor' ja existe em ~/.ssh/config"
    fi

    # ====================== TESTE DE CONEXÃO ======================
    echo
    echo "Testando conexao com o servidor SAV (${SERVER_IP})..."

    # Teste silencioso primeiro
    if ssh -o BatchMode=yes sav_servidor exit 2>/dev/null; then
        echo "Conexao SSH estabelecida com sucesso!"
        return 0
    fi

    # Primeira conexão - modo interativo
    echo "Primeira conexao: confirme a identidade do servidor abaixo."
    echo "   (Digite 'yes' quando aparecer a mensagem de fingerprint)"
    echo

    if ssh sav_servidor exit; then
        echo "Servidor autenticado e fingerprint adicionado ao known_hosts."
        return 0
    else
        echo "Erro: nao foi possivel conectar ao servidor."
        echo "   Verifique:"
        echo "     • IP correto (${SERVER_IP})"
        echo "     • Porta ${SERVER_PORTA} liberada"
        echo "     • Usuario '${SERVER_USER}' existe no servidor remoto"
        echo "     • Firewall permite a conexao"
        return 1
    fi
}


#---------- PONTO DE ENTRADA PRINCIPAL ----------#

# Funcao principal que direciona para o modo correto
main() {

# Diretorio do script (compativel com chamada direta ou via atualiza.sh)
# Quando chamado diretamente de /libs, sobe um nivel para o diretorio do atualiza.sh
    if [[ -z "${SCRIPT_DIR}" ]]; then
        _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ "$(basename "${_self_dir}")" == "libs" ]]; then
            SCRIPT_DIR="$(dirname "${_self_dir}")"
        else
            SCRIPT_DIR="${_self_dir}"
        fi
        unset _self_dir
    fi
# Definição de variáveis globais
raiz="${SCRIPT_DIR%/*}"
acessoff="${acessoff:-${raiz}/portalsav/Atualiza}"

# Diretorios dos modulos e configuracoes
lib_dir="${lib_dir:-${SCRIPT_DIR}/libs}"
cfg_dir="${cfg_dir:-${SCRIPT_DIR}/cfg}"

cd "${SCRIPT_DIR}" || exit 1

# Verifica se o diretorio libs existe
    if [[ ! -d "${lib_dir}" ]]; then
        echo "ERRO: Diretorio ${lib_dir} nao encontrado."
        exit 1
    fi

# Verifica se o diretorio cfg existe
    if [[ ! -d "${cfg_dir}" ]]; then
        echo "ERRO: Diretorio ${cfg_dir} nao encontrado."
        exit 1
    fi

    # Verificar modo de operacao
    if [[ "$1" == "--edit" ]]; then
        _edit_setup
    else
        # Verificar se os arquivos de configuracao ja existem

        if [[ -f "${cfg_dir}/.config" ]]; then  
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
                cd cfg || exit 1
                _initial_setup
            else
                echo "Operacao cancelada. Use './atualiza.sh --setup --edit' para modificar."
                exit 0
            fi
        else
            mkdir -p cfg
            cd cfg || exit 1
            _initial_setup
        fi
    fi
}

# Executar a funcao principal
main "$@"