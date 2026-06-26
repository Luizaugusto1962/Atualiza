#!/usr/bin/env bash
set -euo pipefail
#
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 26/06/2026-01
#

# Variaveis globais esperadas
compilado="${compilado:-}"                      # Sufixo para arquivos compilados
debugado="${debugado:-}"                        # Sufixo para arquivos em depuração
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Variavel do nome da base de dados principal.

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
            _aguardar 2
        fi
    elif [[ -z "${CFG_SISTEMA}" ]]; then
        _linha
        _mensagec "${RED}" "Erro: Variavel de sistema nao configurada"
        _linha
        _aguardar 2
    else
        _linha
        _mensagec "${YELLOW}" "Sistema nao e IsCOBOL"
        _linha
        _aguardar 2
    fi
    _aguardar_tecla
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
        printf '%s\n' "${GREEN}Internet: ${NORM}Conectada${NORM}"
    else
        printf '%s\n' "${GREEN}Internet: ${NORM}Desconectada${NORM}"
    fi

    # Checando tipo de OS
    local os
    os=$(uname -o)
    printf '%s%s%s%s\n' "${GREEN}" "Sistema Operacional :" "${NORM}" "${os}${NORM}"

    # Checando OS Versao e nome
    if [[ -f /etc/os-release ]]; then
        grep 'NAME\|VERSION' /etc/os-release | grep -v 'VERSION_ID\|PRETTY_NAME' >"${LOG_TMP}osrelease"
        printf '%s' "${GREEN}OS Nome :${NORM}"
        grep -v "VERSION" "${LOG_TMP}osrelease" | cut -f2 -d\"
        printf '%s' "${GREEN}OS Versao: ${NORM}"
        grep -v "NAME" "${LOG_TMP}osrelease" | cut -f2 -d\"
    else
        printf '%s\n' "${RED}Arquivo /etc/os-release nao encontrado.${NORM}"
    fi
    printf "\n"

    # Checando hostname
    local nameservers
    nameservers=$(hostname)
    printf '%s\n' "${GREEN}Nome do Servidor: ${NORM}${nameservers}${NORM}"
    printf "\n"

    # Checando Interno IP
    local internalip
    internalip=$(ip route get 1 | awk '{print $7;exit}')
    printf '%s\n' "${GREEN}IP Interno: ${NORM}${internalip}${NORM}"
    printf "\n"

    # Checando Externo IP
    local externalip="Nao disponivel"
    if [[ "${CFG_OFFLINE}" == "n" ]]; then
        if command -v curl >/dev/null 2>&1; then
            externalip=$(curl -s ipecho.net/plain || printf "Nao disponivel")
        else
            externalip="curl nao instalado"
        fi
        printf '%s\n' "${GREEN}IP Externo: ${NORM}${externalip}${NORM}"
    fi

    _linha
    _aguardar_tecla
    _limpa_tela
    _linha

    # Checando os usuarios logados
    who >"${LOG_TMP}who"
    printf '%s\n' "${GREEN}Usuario Logado: ${NORM}"
    cat "${LOG_TMP}who"
    printf "\n"

    # Checando uso de memoria RAM e SWAP
    free | grep -v + >"${LOG_TMP}ramcache"
    printf '%s\n' "${GREEN}Uso de Memoria Ram: ${NORM}"
    grep -v "Swap" "${LOG_TMP}ramcache"
    printf '%s\n' "${GREEN}Uso de Swap: ${NORM}"
    grep -v "Mem" "${LOG_TMP}ramcache"
    printf "\n"

    # Checando uso de disco
    df -h | grep -E 'Filesystem|^/dev/' >"${LOG_TMP}diskusage"
    printf '%s\n' "${GREEN}Espaco em Disco: ${NORM}"
    cat "${LOG_TMP}diskusage"
    printf "\n"

    # Checando o Sistema Uptime
    local tecuptime
    tecuptime=$(uptime -p 2>/dev/null | cut -d " " -f2- || uptime | sed 's/.*up //' | sed 's/,.*//')
    printf '%s\n' "${GREEN}Sistema em uso Dias/(HH:MM): ${NORM}${tecuptime}${NORM}"

    # Unset Variables
    # as vars sao locais, entao unset nao e estritamente necessario, mas mantem a intencao de limpeza

    # Removendo temporarios arquivos
    rm -f "${LOG_TMP}osrelease" "${LOG_TMP}who" "${LOG_TMP}ramcache" "${LOG_TMP}diskusage"
    _linha
    _aguardar_tecla
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
    printf "${GREEN}Diretorio de receber: ${NORM}${DEFAULT_RECEBE_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio de enviar: ${NORM}${DEFAULT_ENVIA_DIR}${NORM}%*s\n"    
    printf "${GREEN}Sistema em uso: ${NORM}${CFG_SISTEMA}${NORM}%*s\n"
    printf "${GREEN}Versao do ${CFG_SISTEMA} em uso: ${NORM}${CFG_VERCLASS}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 1: ${NORM}${SAVATU1}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 2: ${NORM}${SAVATU2}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 3: ${NORM}${SAVATU3}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 4: ${NORM}${SAVATU4}${NORM}%*s\n"
    _linha "=" "${GREEN}"
    _aguardar_tecla
    _limpa_tela
    _linha "=" "${GREEN}"
    printf "${GREEN}Diretorio de configuracoes em OFF: ${NORM}${DEFAULT_RECEBE_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio para envio de backup: ${NORM}${CFG_BACKUP_PATH}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup de base: ${NORM}${DEFAULT_BASEBACKUP_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup da biblioteca: ${NORM}${DEFAULT_BIBLIOTECA_ATUAL_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup da biblioteca anterior: ${NORM}${DEFAULT_BIBLIOTECA_DIR}${NORM}%*s\n"
    printf "${GREEN}Versao da biblioteca atual: ${NORM}${VERSAOANT}${NORM}%*s\n"
    printf "${GREEN}Servidor OFF: ${NORM}${CFG_OFFLINE}${NORM}%*s\n"
    printf "${GREEN}Acessa as chaves: ${NORM}${CFG_CHAVE_SSH}${NORM}%*s\n"
    printf "${GREEN}Variavel do compilado: ${NORM}${compilado}${NORM}%*s\n"
    printf "${GREEN}Variavel do debugado: ${NORM}${debugado}${NORM}%*s\n"
    printf "${GREEN}Porta de conexao: ${NORM}${DEFAULT_SSH_PORTA}${NORM}%*s\n"
    printf "${GREEN}Usuario de conexao: ${NORM}${DEFAULT_SSH_USER}${NORM}%*s\n"
    printf "${GREEN}Servidor IP: ${NORM}${DEFAULT_IP_SERVER}${NORM}%*s\n"
    _linha "=" "${GREEN}"
    _aguardar_tecla
}


# Manutencao_setup - Delega para setup.sh --edit via atualiza.sh
#===================================================================
_manutencao_setup() {
    local atualiza="${SCRIPT_DIR}/atualiza.sh"

    if [[ ! -f "${atualiza}" ]]; then
        _mensagec "${RED}" "Erro: atualiza.sh nao encontrado em ${SCRIPT_DIR}"
        _aguardar 2
        return 1
    fi

    "${atualiza}" --setup --edit
}

