#!/usr/bin/env bash
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

#---------- FUNCOES DE ATUALIZACAO DOS PROGRAMAS----------#

# Executa atualizacao do script
_executar_update() {
    local temp_dir="${RECEBE}/temp_update/"
    local zipfile="atualiza.zip"
 
    _configurar_acessos
    if [[ "${Offline}" =~ ^[sn]$ ]]; then
        if [[ "${Offline}" == "n" ]]; then
            _atualizar_online
        else
            _atualizar_offline
        fi
    fi    
    _press
}

# Faz backup dos scripts atuais antes de atualizar
_fazer_backup_scripts() {
    local backup_sucesso=0
    local backup_erro=0

    cd "${lib_dir}" || {
        _mensagec "${RED}" "Erro: Diretorio de atualizacao nao encontrado"
        _read_sleep 2
        return 1
    }

    for arquivo in *.sh; do
        [[ -f "$arquivo" ]] || continue
        if cp -f "$arquivo" "$BACKUP/$arquivo.bkp"; then
            _mensagec "${GREEN}" "Backup do arquivo $arquivo feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _mensagec "${RED}" "Erro ao fazer backup de $arquivo"
            ((backup_erro++)) || true
            _read_sleep 2
        fi
    done

    if [[ $backup_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha no backup de $backup_erro arquivo(s)"
        _read_sleep 2
        return 1
    elif [[ $backup_sucesso -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi copiado para backup"
        _read_sleep 2
        return 1
    fi

    _mensagec "${GREEN}" "Backup de $backup_sucesso arquivo(s) realizado com sucesso"

    local data_zip zip_nome
    data_zip=$(date +"%d%m")
    zip_nome="${data_zip}_backup.zip"

    if cd "${BACKUP}" && zip -jm "${zip_nome}" ./*.sh.bkp >>"$LOG_ATU" 2>&1; then
        _mensagec "${GREEN}" "Backup compactado com sucesso: ${BACKUP}/${zip_nome}"
    else
        _mensagec "${YELLOW}" "Aviso: Nao foi possivel compactar os arquivos de backup"
    fi

    return 0
}

# Instala os arquivos descompactados nos diretorios corretos
_instalar_arquivos_atualizacao() {
    local arquivos_instalados=0
    local arquivos_erro=0
    local sh_instalados=0

    # Instalar arquivos de configuracao
    local -a cfg_files=("manual.txt" "avisos" "indexar" "limpetmp" ".senhas")
    for cfg_arquivo in "${cfg_files[@]}"; do
        [[ -f "$cfg_arquivo" ]] || continue
        chmod +x "$cfg_arquivo" 2>/dev/null || true
        local cfg_target="${cfg_dir}"
        if ! mkdir -p "$cfg_target" 2>/dev/null; then
            _mensagec "${RED}" "Erro ao criar diretorio de destino: $cfg_target"
            ((arquivos_erro++)) || true
            continue
        fi
        if mv -f "$cfg_arquivo" "$cfg_target/$cfg_arquivo"; then
            _mensagec "${GREEN}" "Arquivo $cfg_arquivo instalado em $cfg_target"
            ((arquivos_instalados++)) || true
        else
            _mensagec "${RED}" "ERRO: Falha ao instalar $cfg_arquivo"
            ((arquivos_erro++)) || true
        fi
    done

    # Instalar arquivos .sh
    for arquivo in *.sh; do
        [[ -f "$arquivo" ]] || continue
        chmod +x "$arquivo" || {
            _mensagec "${RED}" "Aviso: falha ao definir permissao em $arquivo"
        }
        local sh_target
        if [[ "$arquivo" == "atualiza.sh" ]]; then
            sh_target="${SCRIPT_DIR}"
        else
            sh_target="${lib_dir}"
        fi
        if ! mkdir -p "$sh_target" 2>/dev/null; then
            _mensagec "${RED}" "Erro ao criar diretorio: $sh_target"
            ((arquivos_erro++)) || true
            continue
        fi
        if mv -f "$arquivo" "$sh_target/"; then
            _mensagec "${GREEN}" "Instalado $arquivo em $sh_target"
            ((arquivos_instalados++)) || true
            ((sh_instalados++)) || true
        else
            _mensagec "${RED}" "ERRO: Falha ao instalar $arquivo"
            ((arquivos_erro++)) || true
        fi
    done

    [[ $sh_instalados -eq 0 ]] && _mensagec "${YELLOW}" "Aviso: Nenhum arquivo .sh foi instalado"

    if [[ $arquivos_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha na instalacao de $arquivos_erro arquivo(s)"
        return 1
    elif [[ $arquivos_instalados -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi instalado - verifique os arquivos no ZIP"
        return 1
    fi

    _mensagec "${GREEN}" "SUCESSO: $arquivos_instalados arquivo(s) instalado(s)"
    return 0
}

# Limpa o diretorio RECEBE apos a atualizacao
_limpar_diretorio_recebe() {
    if [[ ! -d "${RECEBE}" ]]; then
        _mensagec "${RED}" "ERRO: Diretorio '${RECEBE}' nao encontrado."
        _read_sleep 2
        return 1
    fi

    if ! cd "${RECEBE}"; then
        _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${RECEBE}'."
        _read_sleep 2
        return 1
    fi

    if [[ "$(pwd)" != "${RECEBE}" ]]; then
        _mensagec "${RED}" "ERRO: Falha na verificacao de seguranca do diretorio."
        _read_sleep 2
        return 1
    fi

    if [[ -n "$(ls -A 2>/dev/null)" ]]; then
        _mensagec "${YELLOW}" "Limpando conteudo do diretorio: ${RECEBE}"
        if rm -rf ./* ./.[!.]* 2>/dev/null; then
            _mensagec "${GREEN}" "Diretorio limpo com sucesso."
        else
            _mensagec "${YELLOW}" "AVISO: Alguns arquivos podem nao ter sido removidos."
        fi
    else
        _mensagec "${GREEN}" "Diretorio ja esta vazio."
    fi
    return 0
}

# Atualizacao online via GitHub — orquestra backup, descompactacao e instalacao
_atualizando() {
    local zipfile="atualiza.zip"

    _configurar_diretorios

    # Criar diretorio de backup se necessario
    if [[ ! -d "${BACKUP}" ]]; then
        mkdir -p "${BACKUP}" || {
            _mensagec "${RED}" "Erro: Nao foi possivel criar diretorio de backup"
            _read_sleep 2
            return 1
        }
        chmod 0755 "${BACKUP}"
    fi

    # Fazer backup dos scripts atuais
    if ! _fazer_backup_scripts; then
        return 1
    fi

    # Acessar diretorio de trabalho e descompactar
    cd "$RECEBE" || {
        _mensagec "${RED}" "Erro: Diretorio $RECEBE nao acessivel"
        _read_sleep 2
        return 1
    }

    if ! "${cmd_unzip}" -o -j "$zipfile" >>"$LOG_ATU" 2>&1; then
        _mensagec "${RED}" "Erro ao descompactar atualizacao"
        _mensagec "${YELLOW}" "Verifique se o atualiza.zip esta no diretorio $ENVIA"
        _read_sleep 2
        return 1
    fi

    # Instalar arquivos
    if ! _instalar_arquivos_atualizacao; then
        return 1
    fi

    # Limpar diretorio de trabalho
    _limpar_diretorio_recebe || true

    _linha
    _mensagec "${GREEN}" "Atualizacao concluida com sucesso!"
    _mensagec "${GREEN}" "Ao terminar, entre novamente no sistema"
    _linha

    return 0
}
# Atualizacao de programas via conexao online
_atualizar_online() {
    local link="https://github.com/Luizaugusto1962/atualizar2026/archive/master/atualiza.zip"
    local zipfile="atualiza.zip"

    _mensagec "${GREEN}" "Atualizando script via GitHub..."
    if ! cd "${RECEBE}"; then
        _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${RECEBE}'."
        _read_sleep 2
        return 1
    fi

    # Baixar arquivo diretamente no diretorio RECEBE
    if ! wget -q -c "$link" -O "$zipfile"; then
        _mensagec "${RED}" "Erro ao baixar arquivo de atualizacao"
        _mensagec "${YELLOW}" "Verifique sua conexao com a internet e tente novamente"
        _read_sleep 2
        return 1
    fi
    _atualizando
}

# Atualizacao offline via arquivo local
_atualizar_offline() {
    local temp_dir="${RECEBE}/temp_update/"
    local zipfile="atualiza.zip"

    # Verificar se o arquivo zip existe
    if [[ ! -f "${down_dir}/${zipfile}" ]]; then
        _mensagec "${RED}" "Erro: $zipfile nao encontrado em $down_dir"
        _mensagec "${YELLOW}" "Certifique-se de que o arquivo $zipfile esteja presente no diretorio $down_dir"
        _read_sleep 2
        return 1
    fi
    # Criar e acessar diretorio temporario
    mkdir -p "$temp_dir" || {
        _mensagec "${RED}" "Erro: Nao foi possivel criar o diretorio temporario $temp_dir."
        _read_sleep 2
        chmod 0755 "$temp_dir" 2>/dev/null || true
        return 1
    }

    mv "${down_dir}/${zipfile}" "${RECEBE}" || {
        _mensagec "${RED}" "Erro: Nao foi possivel mover $zipfile para $RECEBE"
        _read_sleep 2
        return 1
    }

        # Acessar diretorio offline
    cd "$temp_dir" || {
        _mensagec "${RED}" "Erro: Diretorio temporario, $temp_dir nao acessivel"
        _read_sleep 2
        return 1
    }
    _atualizando
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

