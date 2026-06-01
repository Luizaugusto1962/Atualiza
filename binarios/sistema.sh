#!/usr/bin/env bash
set -euo pipefail
#
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 01/06/2026-01
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
        printf "%sInternet: %sConectada%s\n" "${GREEN}" "${NORM}" "${NORM}"
    else
        printf "%sInternet: %sDesconectada%s\n" "${GREEN}" "${NORM}" "${NORM}"
    fi

    # Checando tipo de OS
    local os
    os=$(uname -o)
    printf "%sSistema Operacional :%s%s%s\n" "${GREEN}" "${NORM}" "${os}" "${NORM}"

    # Checando OS Versao e nome
    if [[ -f /etc/os-release ]]; then
        grep 'NAME\|VERSION' /etc/os-release | grep -v 'VERSION_ID\|PRETTY_NAME' >"${LOG_TMP}osrelease"
        printf "%sOS Nome :%s\n" "${GREEN}" "${NORM}"
        grep -v "VERSION" "${LOG_TMP}osrelease" | cut -f2 -d\"
        printf "%sOS Versao: %s\n" "${GREEN}" "${NORM}"
        grep -v "NAME" "${LOG_TMP}osrelease" | cut -f2 -d\"
    else
        printf "%sArquivo /etc/os-release nao encontrado.%s\n" "${RED}" "${NORM}"
    fi
    printf "\n"

    # Checando hostname
    local nameservers
    nameservers=$(hostname)
    printf "%sNome do Servidor: %s%s%s\n" "${GREEN}" "${NORM}" "${nameservers}" "${NORM}"
    printf "\n"

    # Checando Interno IP
    local internalip
    internalip=$(ip route get 1 | awk '{print $7;exit}')
    printf "%sIP Interno: %s%s%s\n" "${GREEN}" "${NORM}" "${internalip}" "${NORM}"
    printf "\n"

    # Checando Externo IP
    local externalip="Nao disponivel"
    if [[ "${CFG_OFFLINE}" == "n" ]]; then
        if command -v curl >/dev/null 2>&1; then
            externalip=$(curl -s ipecho.net/plain || printf "Nao disponivel")
        else
            externalip="curl nao instalado"
        fi
        printf "%sIP Externo: %s%s%s\n" "${GREEN}" "${NORM}" "${externalip}" "${NORM}"
    fi

    _linha
    _aguardar_tecla
    _limpa_tela
    _linha

    # Checando os usuarios logados
    _run_who() {
        who >"${LOG_TMP}who"
    }
    _run_who
    printf "%sUsuario Logado: %s\n" "${GREEN}" "${NORM}"
    cat "${LOG_TMP}who"
    printf "\n"

    # Checando uso de memoria RAM e SWAP
    free | grep -v + >"${LOG_TMP}ramcache"
    printf "%sUso de Memoria Ram: %s\n" "${GREEN}" "${NORM}"
    grep -v "Swap" "${LOG_TMP}ramcache"
    printf "%sUso de Swap: %s\n" "${GREEN}" "${NORM}"
    grep -v "Mem" "${LOG_TMP}ramcache"
    printf "\n"

    # Checando uso de disco
    df -h | grep 'Filesystem\|/dev/sda*' >"${LOG_TMP}diskusage"
    printf "%sEspaco em Disco: %s\n" "${GREEN}" "${NORM}"
    cat "${LOG_TMP}diskusage"
    printf "\n"

    # Checando o Sistema Uptime
    local tecuptime
    tecuptime=$(uptime -p | cut -d " " -f2-)
    # CORRECAO: substituidos todos os %*s sem argumento de largura por \n simples
    printf "%sSistema em uso Dias/(HH:MM): %s%s%s\n" "${GREEN}" "${NORM}" "${tecuptime}" "${NORM}"

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
    # CORRECAO: source sem || true com set -e ativo pode encerrar o shell se .versao retornar != 0
    if [[ -f "${CFG_DIR}/.versao" ]]; then
        "." "${CFG_DIR}/.versao" || true
    fi
    _limpa_tela
    _linha "=" "${GREEN}"
    printf "%sSistema e banco de dados: %s%s%s\n" "${GREEN}" "${NORM}" "${CFG_USA_DBMAKER}" "${NORM}"
    printf "%sDiretorio RAIZ: %s%s%s\n" "${GREEN}" "${NORM}" "${RAIZ}" "${NORM}"
    printf "%sDiretorio do atualiza.sh: %s%s%s\n" "${GREEN}" "${NORM}" "${SCRIPT_DIR}" "${NORM}"
    printf "%sDiretorio da base principal: %s%s%s%s\n" "${GREEN}" "${NORM}" "${RAIZ}" "${CFG_BASE_DIR}" "${NORM}"
    [[ -n "${CFG_BASE_DIR2}" ]] && printf "%sDiretorio da segunda base: %s%s%s%s\n" "${GREEN}" "${NORM}" "${RAIZ}" "${CFG_BASE_DIR2}" "${NORM}"
    [[ -n "${CFG_BASE_DIR3}" ]] && printf "%sDiretorio da terceira base: %s%s%s%s\n" "${GREEN}" "${NORM}" "${RAIZ}" "${CFG_BASE_DIR3}" "${NORM}"
    printf "%sDiretorio dos executaveis: %s%s%s\n" "${GREEN}" "${NORM}" "${E_EXEC}" "${NORM}"
    printf "%sDiretorio das telas: %s%s%s\n" "${GREEN}" "${NORM}" "${T_TELAS}" "${NORM}"
    if [[ "$CFG_SISTEMA" == "iscobol" ]]; then
        printf "%sDiretorio dos xmls: %s%s%s\n" "${GREEN}" "${NORM}" "${X_XML}" "${NORM}"
    fi
    printf "%sDiretorio dos logs: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_LOGS_DIR}" "${NORM}"
    printf "%sDiretorio dos olds: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_OLDS_DIR}" "${NORM}"
    printf "%sDiretorio dos progs: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_PROGS_DIR}" "${NORM}"
    printf "%sDiretorio do backup: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_BACKUP_DIR}" "${NORM}"
    printf "%sDiretorio de configuracoes: %s%s%s\n" "${GREEN}" "${NORM}" "${CFG_DIR}" "${NORM}"
    printf "%sDiretorio de receber: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_RECEBE_DIR}" "${NORM}"
    printf "%sDiretorio de enviar: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_ENVIA_DIR}" "${NORM}"
    printf "%sSistema em uso: %s%s%s\n" "${GREEN}" "${NORM}" "${CFG_SISTEMA}" "${NORM}"
    printf "%sVersao do %s em uso: %s%s%s\n" "${GREEN}" "${CFG_SISTEMA}" "${NORM}" "${CFG_VERCLASS}" "${NORM}"
    printf "%sBiblioteca 1: %s%s%s\n" "${GREEN}" "${NORM}" "${SAVATU1}" "${NORM}"
    printf "%sBiblioteca 2: %s%s%s\n" "${GREEN}" "${NORM}" "${SAVATU2}" "${NORM}"
    printf "%sBiblioteca 3: %s%s%s\n" "${GREEN}" "${NORM}" "${SAVATU3}" "${NORM}"
    printf "%sBiblioteca 4: %s%s%s\n" "${GREEN}" "${NORM}" "${SAVATU4}" "${NORM}"
    _linha "=" "${GREEN}"
    _aguardar_tecla
    _limpa_tela
    _linha "=" "${GREEN}"
    # CORRECAO: substituidos todos os printf "${VAR}texto${NORM}%*s\n" por formato seguro "%s texto %s\n"
    printf "%sDiretorio de configuracoes em OFF: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_RECEBE_DIR}" "${NORM}"
    printf "%sDiretorio para envio de backup: %s%s%s\n" "${GREEN}" "${NORM}" "${CFG_BACKUP_PATH}" "${NORM}"
    printf "%sDiretorio do backup de base: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_BASEBACKUP_DIR}" "${NORM}"
    printf "%sDiretorio do backup da biblioteca: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_BIBLIOTECA_ATUAL_DIR}" "${NORM}"
    printf "%sDiretorio do backup da biblioteca anterior: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_BIBLIOTECA_DIR}" "${NORM}"
    printf "%sVersao da biblioteca atual: %s%s%s\n" "${GREEN}" "${NORM}" "${VERSAOANT}" "${NORM}"
    printf "%sServidor OFF: %s%s%s\n" "${GREEN}" "${NORM}" "${CFG_OFFLINE}" "${NORM}"
    printf "%sVariavel do compilado: %s%s%s\n" "${GREEN}" "${NORM}" "${compilado}" "${NORM}"
    printf "%sVariavel do debugado: %s%s%s\n" "${GREEN}" "${NORM}" "${debugado}" "${NORM}"
    printf "%sPorta de conexao: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_SSH_PORTA}" "${NORM}"
    printf "%sUsuario de conexao: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_SSH_USER}" "${NORM}"
    printf "%sServidor IP: %s%s%s\n" "${GREEN}" "${NORM}" "${DEFAULT_IP_SERVER}" "${NORM}"
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

