#!/usr/bin/env bash
set -euo pipefail
#
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 23/07/2026-01
#

# Variaveis globais esperadas
compilado="${compilado:-}"                      # Sufixo para arquivos compilados
debugado="${debugado:-}"                        # Sufixo para arquivos em depuracao
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Variavel do nome da base de dados principal.

#---------- FUNCOES DE VERSAO ----------#
# Mostra versao do IsCOBOL
_mostrar_versao_iscobol() {
    if [[ -x "${SAVISC}${ISCCLIENT}" ]]; then
        clear
        _linha "=" "${VERDE}"
        _exibir_mensagem_centralizada "${VERDE}" "Versao do IsCobol"
        _linha "=" "${VERDE}"
        "${SAVISC}${ISCCLIENT}" -v
        _linha "=" "${VERDE}"
        printf "\n"
    else
        _linha
        _erro "${SAVISC}${ISCCLIENT} nao encontrado ou nao executavel"
        _linha
        _aguardar 2
    fi
    _aguardar_tecla
}

# Mostra informacoes do Linux
_mostrar_versao_linux() {
    clear
    printf "\n"
    _exibir_mensagem_centralizada "${VERDE}" "Vamos descobrir qual S.O. / Distro voce esta executando"
    _linha
    printf "\n"
    _exibir_mensagem_centralizada "${AMARELO}" "A partir de algumas informacoes basicas do seu sistema, parece estar executando:"
    _linha

    # Checando se conecta com a internet ou nao
    if ping -c 1 -W 3 google.com &>/dev/null; then
        printf '%s\n' "${VERDE}Internet: ${NORMAL}Conectada${NORMAL}"
    else
        printf '%s\n' "${VERDE}Internet: ${NORMAL}Desconectada${NORMAL}"
    fi

    # Checando tipo de OS
    local os
    os=$(uname -o)
    printf '%s%s%s%s\n' "${VERDE}" "Sistema Operacional :" "${NORMAL}" "${os}${NORMAL}"

    # Checando OS Versao e nome
    if [[ -f /etc/os-release ]]; then
        grep 'NAME\|VERSION' /etc/os-release | grep -v 'VERSION_ID\|PRETTY_NAME' >"${LOG_TMP}osrelease"
        printf '%s' "${VERDE}OS Nome :${NORMAL}"
        grep -v "VERSION" "${LOG_TMP}osrelease" | cut -f2 -d\"
        printf '%s' "${VERDE}OS Versao: ${NORMAL}"
        grep -v "NAME" "${LOG_TMP}osrelease" | cut -f2 -d\"
    else
        printf '%s\n' "${VERMELHO}Arquivo /etc/os-release nao encontrado.${NORMAL}"
    fi
    printf "\n"

    # Checando hostname
    local nameservers
    nameservers=$(hostname)
    printf '%s\n' "${VERDE}Nome do Servidor: ${NORMAL}${nameservers}${NORMAL}"
    printf "\n"

    # Checando Interno IP
    local internalip
    internalip=$(ip route get 1 | awk '{print $7;exit}')
    printf '%s\n' "${VERDE}IP Interno: ${NORMAL}${internalip}${NORMAL}"
    printf "\n"

    # Checando Externo IP
    local externalip="Nao disponivel"
    if [[ "${CFG_OFFLINE}" == "n" ]]; then
        if command -v curl >/dev/null 2>&1; then
            externalip=$(curl -s --max-time 5 ipecho.net/plain || printf "Nao disponivel")
        else
            externalip="curl nao instalado"
        fi
        printf '%s\n' "${VERDE}IP Externo: ${NORMAL}${externalip}${NORMAL}"
    fi

    _linha
    _aguardar_tecla
    clear
    _linha

    # Checando os usuarios logados — direto, sem arquivo temporario
    printf '%s\n' "${VERDE}Usuario Logado: ${NORMAL}"
    who
    printf "\n"

    # Checando uso de memoria RAM e SWAP — direto, sem arquivo temporario
    printf '%s\n' "${VERDE}Uso de Memoria Ram: ${NORMAL}"
    free | grep -v -E '^Swap'
    printf '%s\n' "${VERDE}Uso de Swap: ${NORMAL}"
    free | grep -E '^Swap'
    printf "\n"

    # Checando uso de disco — direto, sem arquivo temporario
    printf '%s\n' "${VERDE}Espaco em Disco: ${NORMAL}"
    df -h | grep -E 'Filesystem|^/dev/'
    printf "\n"

    # Checando o Sistema Uptime
    local tecuptime
    tecuptime=$(uptime -p 2>/dev/null | cut -d " " -f2- || uptime | sed 's/.*up //' | sed 's/,.*//')
    printf '%s\n' "${VERDE}Sistema em uso Dias/(HH:MM): ${NORMAL}${tecuptime}${NORMAL}"

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
    clear
    _linha "=" "${CIANO}"
    printf '%b\n' "${VERDE}Diretorio RAIZ: ${NORMAL}${RAIZ}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio do atualiza.sh: ${NORMAL}${SCRIPT_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio da base principal: ${NORMAL}${RAIZ}${CFG_BASE_DIR}${NORMAL}"
    [[ -n "${CFG_BASE_DIR2:-}" ]] && printf '%b\n' "${VERDE}Diretorio da segunda base: ${NORMAL}${RAIZ}${CFG_BASE_DIR2}${NORMAL}"
    [[ -n "${CFG_BASE_DIR3:-}" ]] && printf '%b\n' "${VERDE}Diretorio da terceira base: ${NORMAL}${RAIZ}${CFG_BASE_DIR3}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio dos executaveis: ${NORMAL}${E_EXEC}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio das telas: ${NORMAL}${T_TELAS}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio dos logs: ${NORMAL}${DEFAULT_LOGS_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio dos olds: ${NORMAL}${DEFAULT_OLDS_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio dos progs: ${NORMAL}${DEFAULT_PROGS_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio do backup: ${NORMAL}${DEFAULT_BACKUP_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio de configuracoes: ${NORMAL}${CFG_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio de receber: ${NORMAL}${DEFAULT_RECEBE_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio de enviar: ${NORMAL}${DEFAULT_ENVIA_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Versao em uso: ${NORMAL}${CFG_VERSAOCLASS}${NORMAL}"
    printf '%b\n' "${VERDE}Biblioteca 1: ${NORMAL}${SAVATU1}${NORMAL}"
    printf '%b\n' "${VERDE}Biblioteca 2: ${NORMAL}${SAVATU2}${NORMAL}"
    printf '%b\n' "${VERDE}Biblioteca 3: ${NORMAL}${SAVATU3}${NORMAL}"
    _linha "=" "${CIANO}"
    _aguardar_tecla
    clear
    _linha "=" "${CIANO}"
    printf '%b\n' "${VERDE}Diretorio de configuracoes em OFF: ${NORMAL}${DEFAULT_RECEBE_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio para envio de backup: ${NORMAL}${CFG_BACKUP_PATH}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio do backup de base: ${NORMAL}${DEFAULT_BASEBACKUP_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio do backup da biblioteca: ${NORMAL}${DEFAULT_BIBLIOTECA_ATUAL_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Diretorio do backup da biblioteca anterior: ${NORMAL}${DEFAULT_BIBLIOTECA_DIR}${NORMAL}"
    printf '%b\n' "${VERDE}Versao da biblioteca atual: ${NORMAL}${VERSAOANT}${NORMAL}"
    printf '%b\n' "${VERDE}Servidor OFF: ${NORMAL}${CFG_OFFLINE}${NORMAL}"
    printf '%b\n' "${VERDE}Acessa as chaves: ${NORMAL}${CFG_CHAVE_SSH}${NORMAL}"
    printf '%b\n' "${VERDE}Variavel do compilado: ${NORMAL}${compilado}${NORMAL}"
    printf '%b\n' "${VERDE}Variavel do debugado: ${NORMAL}${debugado}${NORMAL}"
    printf '%b\n' "${VERDE}Porta de conexao: ${NORMAL}${DEFAULT_SSH_PORTA}${NORMAL}"
    printf '%b\n' "${VERDE}Usuario de conexao: ${NORMAL}${DEFAULT_SSH_USER}${NORMAL}"
    printf '%b\n' "${VERDE}Servidor IP: ${NORMAL}${DEFAULT_IP_SERVER}${NORMAL}"
    _linha "=" "${CIANO}"
    _aguardar_tecla
}

# Manutencao_setup - Delega para setup.sh --edit via atualiza.sh
#===================================================================
_manutencao_setup() {
    local atualiza="${SCRIPT_DIR}/atualiza.sh"

    if [[ ! -f "${atualiza}" ]]; then
        _erro "atualiza.sh nao encontrado em ${SCRIPT_DIR}"
        _aguardar 2
        return 1
    fi

    "${atualiza}" --setup --edit

    # Recarregar configuracoes na sessao atual apos edicao
    if [[ -f "${CFG_DIR}/.config" ]] && command -v _carregar_config_seguro >/dev/null 2>&1; then
        _carregar_config_seguro "${CFG_DIR}/.config" || true
        _configurar_variaveis_sistema || true
        _exibir_mensagem_centralizada "${VERDE}" "Configuracoes recarregadas na sessao atual."
        _aguardar 2
    fi
}


