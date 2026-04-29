#!/usr/bin/env bash
set -euo pipefail
#
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 28/04/2026-02
#
# Variaveis globais esperadas
cfg_dir="${cfg_dir:-}"      # Caminho do diretorio de configuracao do programa.
lib_dir="${lib_dir:-}"      # Diretorio dos modulos de biblioteca.
cmd_unzip="${cmd_unzip:-}"  # Comando de descompactacao (unzip).
class="${class:-}"          # Variavel da classe.
mclass="${mclass:-}"        # Variavel da mclass.
base="${base:-}"            # Variavel do nome da base principal.
base2="${base2:-}"          # Variavel do nome da segunda base (opcional).
base3="${base3:-}"          # Variavel do nome da terceira base (opcional).
sistema="${sistema:-}"      # Variavel do sistema em uso (ex: iscobol, linux).
dbmaker="${dbmaker:-}"      # Variavel do banco de dados em uso (ex: dbase, mysql).
raiz="${raiz:-}"            # Variavel do diretorio raiz do sistema.
enviabackup="${enviabackup:-}"  # Variavel do diretorio para envio de backup.
ipserver="${ipserver:-}"    # Variavel do IP do servidor.
Offline="${Offline:-}"      # Variavel do status de conexao (s/n).
verclass="${verclass:-}"    # Variavel da versao da classe.
down_dir="${down_dir:-}"    # Variavel do diretorio de download para atualizacao offline.


#---------- FUNCOES DE VERSAO ----------#
# Mostra versao do IsCOBOL
_mostrar_versao_iscobol() {
    if [[ "${sistema}" == "iscobol" ]]; then
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
    elif [[ -z "${sistema}" ]]; then
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
    if ping -c 1 google.com &>/dev/null; then
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
    if [[ "${Offline}" == "n" ]]; then
        externalip=$(curl -s ipecho.net/plain || printf "Nao disponivel")
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
    if [[ -f "${cfg_dir}/.versao" ]]; then
        "." "${cfg_dir}/.versao"
    fi
    _limpa_tela
    _linha "=" "${GREEN}"
    printf "${GREEN}Sistema e banco de dados: ${NORM}${dbmaker}${NORM}%*s\n"
    printf "${GREEN}Diretorio raiz: ${NORM}${raiz}${NORM}%*s\n"
    printf "${GREEN}Diretorio do atualiza.sh: ${NORM}${SCRIPT_DIR}${NORM}%*s\n"
    printf "${GREEN}Diretorio da base principal: ${NORM}${raiz}${base}${NORM}%*s\n"
    [[ -n "${base2}" ]] && printf "${GREEN}Diretorio da segunda base: ${NORM}${raiz}${base2}${NORM}%*s\n"
    [[ -n "${base3}" ]] && printf "${GREEN}Diretorio da terceira base: ${NORM}${raiz}${base3}${NORM}%*s\n"
    printf "${GREEN}Diretorio dos executaveis: ${NORM}${E_EXEC}${NORM}%*s\n"
    printf "${GREEN}Diretorio das telas: ${NORM}${T_TELAS}${NORM}%*s\n"
    if [[ "$sistema" == "iscobol" ]]; then
        printf "${GREEN}Diretorio dos xmls: ${NORM}${X_XML}${NORM}%*s\n"
    fi
    printf "${GREEN}Diretorio dos logs: ${NORM}${LOGS}${NORM}%*s\n"
    printf "${GREEN}Diretorio dos olds: ${NORM}${OLDS}${NORM}%*s\n"
    printf "${GREEN}Diretorio dos progs: ${NORM}${PROGS}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup: ${NORM}${BACKUP}${NORM}%*s\n"
    printf "${GREEN}Diretorio de configuracoes: ${NORM}${cfg_dir}${NORM}%*s\n"
    printf "${GREEN}Sistema em uso: ${NORM}${sistema}${NORM}%*s\n"
    printf "${GREEN}Versao em uso: ${NORM}${verclass}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 1: ${NORM}${SAVATU1}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 2: ${NORM}${SAVATU2}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 3: ${NORM}${SAVATU3}${NORM}%*s\n"
    printf "${GREEN}Biblioteca 4: ${NORM}${SAVATU4}${NORM}%*s\n"
    _linha "=" "${GREEN}"
    _press
    _limpa_tela
    _linha "=" "${GREEN}"
    printf "${GREEN}Diretorio de configuracoes em OFF: ${NORM}${down_dir}${NORM}%*s\n"
    printf "${GREEN}Diretorio para envio de backup: ${NORM}${enviabackup}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup de base: ${NORM}${BASEBACKUP}${NORM}%*s\n"
    printf "${GREEN}Diretorio do backup da biblioteca: ${NORM}${BIBLIOTECA}${NORM}%*s\n"
    printf "${GREEN}Versao da biblioteca atual: ${NORM}${VERSAOANT}${NORM}%*s\n"
    printf "${GREEN}Servidor OFF: ${NORM}${Offline}${NORM}%*s\n"
    printf "${GREEN}Variavel da classe: ${NORM}${class}${NORM}%*s\n"
    printf "${GREEN}Variavel da mclass: ${NORM}${mclass}${NORM}%*s\n"
    printf "${GREEN}Porta de conexao: ${NORM}${SERVER_PORTA}${NORM}%*s\n"
    printf "${GREEN}Usuario de conexao: ${NORM}${USUARIO}${NORM}%*s\n"
    printf "${GREEN}Servidor IP: ${NORM}${ipserver}${NORM}%*s\n"
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

