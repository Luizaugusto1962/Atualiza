#!/usr/bin/env bash
set -euo pipefail
#
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 05/05/2026-01
#

# Variaveis globais esperadas
CFG_DIR="${CFG_DIR:-}"                          # Caminho do diretorio de configuracao do programa.
LIB_DIR="${LIB_DIR:-}"                          # Diretorio dos modulos de biblioteca.
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (unzip).
class="${class:-}"                              # Variavel da classe.
mclass="${mclass:-}"                            # Variavel da mclass.
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Variavel do nome da base de dados principal.
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"              # Variavel do nome da segunda base de dados (opcional).
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"              # Variavel do nome da terceira base de dados (opcional).
CFG_SISTEMA="${CFG_SISTEMA:-}"                  # Variavel do sistema em uso (ex: iscobol, linux).
CFG_USA_DBMAKER="${CFG_USA_DBMAKER:-}"          # Variavel do banco de dados em uso (ex: dbase, mysql).
RAIZ="${RAIZ:-}"                                # Variavel do diretorio RAIZ do sistema.
CFG_BACKUP_PATH="${CFG_BACKUP_PATH:-}"          # Variavel do diretorio para envio de backup.
CFG_OFFLINE="${CFG_OFFLINE:-}"                  # Variavel do status de conexao (s/n).
CFG_VERCLASS="${CFG_VERCLASS:-}"                # Variavel da versao da classe.
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"    # Variavel do diretorio de download para atualizacao offline.


#---------- FUNCOES DE VERSAO ----------#
# Mostra versao do IsCOBOL
_mostrar_versao_iscobol() {
    if [[ "${CFG_SISTEMA}" == "iscobol" ]]; then
        if [[ -x "${SAVISC}${ISCCLIENT}" ]]; then
            _limpa_tela
            _linha "=" "${GREEN}"
            _mensagec "${GREEN}" "Versao do IsCobol"
            _linha "=" "${GREEN}"
            "${SAVISC}${ISCCLIENT}" -v
            _linha "=" "${GREEN}"
            printf "\n"
        else
            _linha
            _mensagec "${RED}" "Erro: ${SAVISC}${ISCCLIENT} nao encontrado ou nao executavel"
            _linha
            _read_sleep 2
        fi
    elif [[ -z "${CFG_SISTEMA}" ]]; then
        _linha
        _mensagec "${RED}" "Erro: Variavel de sistema nao configurada"
        _linha
        _read_sleep 2
    else
        _linha
        _mensagec "${YELLOW}" "Sistema nao e IsCOBOL"
        _linha
        _read_sleep 2
    fi
    _press
}

# Mostra informacoes do Linux
_mostrar_versao_linux() {
    _limpa_tela
    printf "\n"
    _mensagec "${GREEN}" "Vamos descobrir qual S.O. / Distro voce esta executando"
    _linha
    printf "\n"
    _mensagec "${YELLOW}" "A partir de algumas informacoes basicas do seu sistema, parece estar executando:"
    _linha

    # Checando se conecta com a internet ou nao
    if ping -c 1 -W 3 google.com &>/dev/null; then
        printf "${GREEN}Internet: ${NORM}Conectada${NORM}%*s\n"
    else
        printf "${GREEN}Internet: ${NORM}Desconectada${NORM}%*s\n"
    fi

    # Checando tipo de OS
    local os
    os=$(uname -o)
    printf "${GREEN}Sistema Operacional :${NORM}${os}${NORM}%*s\n"

    # Checando OS Versao e nome
    if [[ -f /etc/os-release ]]; then
        grep 'NAME\|VERSION' /etc/os-release | grep -v 'VERSION_ID\|PRETTY_NAME' >"${LOG_TMP}osrelease"
        printf "${GREEN}OS Nome :${NORM}%*s\n"
        grep -v "VERSION" "${LOG_TMP}osrelease" | cut -f2 -d\"
        printf "${GREEN}OS Versao: ${NORM}%*s\n"
        grep -v "NAME" "${LOG_TMP}osrelease" | cut -f2 -d\"
    else
        printf "${RED}""Arquivo /etc/os-release nao encontrado.${NORM}%*s\n"
    fi
    printf "\n"

    # Checando hostname
    local nameservers
    nameservers=$(hostname)
    printf "${GREEN}Nome do Servidor: ${NORM}${nameservers}${NORM}%*s\n"
    printf "\n"

    # Checando Interno IP
    local internalip
    internalip=$(ip route get 1 | awk '{print $7;exit}')
    printf "${GREEN}IP Interno: ${NORM}${internalip}${NORM}%*s\n"
    printf "\n"

    # Checando Externo IP
    local externalip="Nao disponivel"
    if [[ "${CFG_OFFLINE}" == "n" ]]; then
        if command -v curl >/dev/null 2>&1; then
            externalip=$(curl -s ipecho.net/plain || printf "Nao disponivel")
        else
            externalip="curl nao instalado"
        fi
        printf "${GREEN}IP Externo: ${NORM}${externalip}${NORM}%*s\n"
    fi

    _linha
    _press
    _limpa_tela
    _linha

    # Checando os usuarios logados
    _run_who() {
        who >"${LOG_TMP}who"
    }
    _run_who
    printf "${GREEN}Usuario Logado: ${NORM}%*s\n"
    cat "${LOG_TMP}who"
    printf "\n"

    # Checando uso de memoria RAM e SWAP
    free | grep -v + >"${LOG_TMP}ramcache"
    printf "${GREEN}Uso de Memoria Ram: ${NORM}%*s\n"
    grep -v "Swap" "${LOG_TMP}ramcache"
    printf "${GREEN}Uso de Swap: ${NORM}%*s\n"
    grep -v "Mem" "${LOG_TMP}ramcache"
    printf "\n"

    # Checando uso de disco
    df -h | grep 'Filesystem\|/dev/sda*' >"${LOG_TMP}diskusage"
    printf "${GREEN}Espaco em Disco: ${NORM}%*s\n"
    cat "${LOG_TMP}diskusage"
    printf "\n"

    # Checando o Sistema Uptime
    local tecuptime
    tecuptime=$(uptime -p | cut -d " " -f2-)
    printf "${GREEN}Sistema em uso Dias/(HH:MM): ${NORM}""${tecuptime}${NORM}%*s\n"

    # Unset Variables
    # as vars sao locais, entao unset nao e estritamente necessario, mas mantem a intencao de limpeza

    # Removendo temporarios arquivos
    rm -f "${LOG_TMP}osrelease" "${LOG_TMP}who" "${LOG_TMP}ramcache" "${LOG_TMP}diskusage"
    _linha
    _press
}

#---------- FUNCOES DE PARAMETROS ----------#

# Mostra parametros do sistema
_mostrar_parametros() {
    # Carregar versao antes de exibir
    if [[ -f "${CFG_DIR}/.versao" ]]; then
        "." "${CFG_DIR}/.versao"
    fi
    _limpa_tela
    _linha "=" "${GREEN}"
    printf "${GREEN}Sistema e banco de dados: ${NORM}${CFG_USA_DBMAKER}${NORM}%*s\n"
    printf "${GREEN}Diretorio RAIZ: ${NORM}${RAIZ}${NORM}%*s\n"
    printf "${GREEN}Diretorio do atualiza.sh: ${NORM}${SCRIPT_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio da base principal: ${NORM}${RAIZ}${CFG_BASE_DIR}${NORM}%*s\n"
    [[ -n "${CFG_BASE_DIR2}" ]] && printf "${GREEN}Diretorio da segunda base: ${NORM}${RAIZ}${CFG_BASE_DIR2}${NORM}%*s\n"
    [[ -n "${CFG_BASE_DIR3}" ]] && printf "${GREEN}Diretorio da terceira base: ${NORM}${RAIZ}${CFG_BASE_DIR3}${NORM}%*s\n"
    printf "${GREEN}Diretorio dos executaveis: ${NORM}${E_EXEC}${NORM}%*s\n"
    printf "${GREEN}Diretorio das telas: ${NORM}${T_TELAS}${NORM}%*s\n"
    if [[ "$CFG_SISTEMA" == "iscobol" ]]; then
        printf "${GREEN}Diretorio dos xmls: ${NORM}${X_XML}${NORM}%*s\n"
    fi
    printf "${GREEN}Diretorio dos logs: ${NORM}${DEFAULT_LOGS_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio dos olds: ${NORM}${DEFAULT_OLDS_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio dos progs: ${NORM}${DEFAULT_PROGS_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup: ${NORM}${DEFAULT_BACKUP_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio de configuracoes: ${NORM}${CFG_DIR}${NORM}%*s\n"
    printf "${GREEN}Sistema em uso: ${NORM}${CFG_SISTEMA}${NORM}%*s\n"
    printf "${GREEN}Versao do ${CFG_SISTEMA} em uso: ${NORM}${CFG_VERCLASS}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 1: ${NORM}${SAVATU1}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 2: ${NORM}${SAVATU2}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 3: ${NORM}${SAVATU3}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 4: ${NORM}${SAVATU4}${NORM}%*s\n"
    _linha "=" "${GREEN}"
    _press
    _limpa_tela
    _linha "=" "${GREEN}"
    printf "${GREEN}Diretorio de configuracoes em OFF: ${NORM}${DEFAULT_RECEBE_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio para envio de backup: ${NORM}${CFG_BACKUP_PATH}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup de base: ${NORM}${DEFAULT_BASEBACKUP_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup da biblioteca: ${NORM}${DEFAULT_BIBLIOTECA_DIR}${NORM}%*s\n"
    printf "${GREEN}Versao da biblioteca atual: ${NORM}${VERSAOANT}${NORM}%*s\n"
    printf "${GREEN}Servidor OFF: ${NORM}${CFG_OFFLINE}${NORM}%*s\n"
    printf "${GREEN}Variavel da classe: ${NORM}${class}${NORM}%*s\n"
    printf "${GREEN}Variavel da mclass: ${NORM}${mclass}${NORM}%*s\n"
    printf "${GREEN}Porta de conexao: ${NORM}${DEFAULT_SSH_PORTA}${NORM}%*s\n"
    printf "${GREEN}Usuario de conexao: ${NORM}${DEFAULT_SSH_USER}${NORM}%*s\n"
    printf "${GREEN}Servidor IP: ${NORM}${DEFAULT_IP_SERVER}${NORM}%*s\n"
    _linha "=" "${GREEN}"
    _press
}


# Manutencao_setup - Delega para setup.sh --edit via atualiza.sh
#===================================================================
_manutencao_setup() {
    local atualiza="${SCRIPT_DIR}/atualiza.sh"

    if [[ ! -f "${atualiza}" ]]; then
        _mensagec "${RED}" "Erro: atualiza.sh nao encontrado em ${SCRIPT_DIR}"
        _read_sleep 2
        return 1
    fi

    "${atualiza}" --setup --edit
}

