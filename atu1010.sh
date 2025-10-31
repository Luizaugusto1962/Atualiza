#!/usr/bin/env bash
#set -euo pipefail

#
# atu2025.sh - Script para atualizar arquivos .sh e limpar arquivos antigos
# Versão: 10/10/2025-00
#

# Diretório de ferramentas
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TOOLS

# Diretórios
readonly CFG_DIR="${TOOLS}/cfg"
readonly LIB_DIR="${TOOLS}/libs"
readonly BACKUP_DIR="${backup:-${TOOLS}/backup}"
readonly ENVIA_DIR="${ENVIA:-${TOOLS}/envia}"
readonly ACESSO_OFFLINE="/u/sav/portalsav/Atualiza"

# Cores ANSI    
RED=$(tput bold)$(tput setaf 1) 
GREEN=$(tput bold)$(tput setaf 2)
YELLOW=$(tput bold)$(tput setaf 3)
NORM=$(tput sgr0)
COLUMNS=$(tput cols) 

# Funções de utilidade

# Aguarda pressionar qualquer tecla com timeout
_press() {
    printf "%s" "${YELLOW}"
    printf "%*s\n" $(((36 + COLUMNS) / 2)) "<< ... Pressione qualquer tecla para continuar ... >>"
    printf "%s" "${NORM}"
    read -rt 15 || :
    tput sgr0
}

# Exibe mensagem centralizada colorida
# Parâmetros: $1=cor $2=mensagem
_mensagec() {
    local color="${1}"
    local message="${2}"
    printf "%s%*s%s\n" "${color}" $(((${#message} + $(tput cols)) / 2)) "${message}" "${NORM}"
}

# Função de log para mensagens consistentes
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Verifica e cria diretório se não existir
_create_dir_if_not_exists() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        log "Diretório ${dir} não encontrado. Criando..."
        mkdir -p "${dir}"
        log "Diretório ${dir} criado com sucesso."
    fi
}

# Funções principais

# Inicializa os diretórios necessários
_init_directories() {
    # Mudar para o diretório de trabalho
    cd "${TOOLS}" || { log "Erro ao mudar para o diretório ${TOOLS}."; exit 1; }
    
    # Criar diretórios necessários
    _create_dir_if_not_exists "${CFG_DIR}"
    _create_dir_if_not_exists "${LIB_DIR}"
}

# Limpa arquivos temporários e backups antigos
_cleanup_files() {
    # Excluir arquivo .atualizap se existir
    if [[ -f ".atualizap" ]]; then
        log "Excluindo .atualizap..."
        rm -f .atualizap
        log "Arquivo .atualizap excluído com sucesso."
    else
        log "Arquivo .atualizap não encontrado. Nenhuma ação adicional necessária."
    fi

    # Excluir arquivos .atualiza*.bak existentes
    log "Excluindo arquivos .atualiza*.bak..."
    rm -f .atualiza*.bak
    log "Arquivos .atualiza*.bak excluídos."

    # Excluir arquivos .expurgador* existentes
    log "Excluindo arquivos .expurgador*..."
    rm -f .expurgador*
    log "Arquivos .expurgador excluídos."
}

# Move arquivos de configuração para o diretório cfg
_move_config_files() {
    # Verificar e mover arquivo .atualizap se existir
    if [[ -f ".atualizac" ]]; then
        log "Movendo .atualizac..."
        mv -f .atualizac   "${CFG_DIR}/.atualizac"
        log "Arquivo .atualizac movido com sucesso."
    else
        log "Arquivo .atualizac não encontrado. Nenhuma ação adicional necessária."
    fi

    # Verificar e mover arquivos atualiza? se existirem
    for arquivo in atualiza?; do
        if [[ -f "${arquivo}" ]]; then
            log "Movendo ${arquivo} para ${CFG_DIR}/${arquivo}"
            mv "${arquivo}" "${CFG_DIR}/${arquivo}"
            log "Arquivo ${arquivo} movido para ${CFG_DIR} com sucesso."
        fi
    done
}

#---------- FUNÇÕES DE ATUALIZAÇÃO ----------#

# Função principal de atualização
# Parâmetros: $1=link/caminho $2=zipfile $3=temp_dir
_atualizando() {
    local link="$1"
    local zipfile="$2"
    local temp_dir="$3"
    local is_online="$4"
    
    _mensagec "${GREEN}" "Atualizando script..."
    
    # Criar backup do arquivo atual
    _create_dir_if_not_exists "$BACKUP_DIR"
    
    # Fazer backup dos arquivos atuais
    local backup_sucesso=0
    local backup_erro=0
    
    cd "${TOOLS}" || {
        _mensagec "${RED}" "Erro: Diretório de atualização não encontrado"
        return 1
    }
    
    # Processar todos os arquivos .sh para backup
    for arquivo in *.sh; do
        # Verificar se o arquivo existe
        if [[ ! -f "$arquivo" ]]; then
            _mensagec "${YELLOW}" "Aviso: Nenhum arquivo .sh encontrado para backup"
            break
        fi

        # Copiar o arquivo para o diretório de backup
        if mv -f "$arquivo" "${BACKUP_DIR}/.$arquivo.bak"; then
            _mensagec "${GREEN}" "Backup do arquivo $arquivo feito com sucesso"
            ((backup_sucesso++))
        else
            _mensagec "${RED}" "Erro ao fazer backup de $arquivo"
            ((backup_erro++))
        fi
    done

    # Verificar se houve erros no backup
    if [[ $backup_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha no backup de $backup_erro arquivo(s)"
        return 1
    elif [[ $backup_sucesso -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi copiado para backup"
        return 1
    else
        _mensagec "${GREEN}" "Backup de $backup_sucesso arquivo(s) realizado com sucesso"
    fi

    # Acessar diretório de trabalho temporário
    cd "$temp_dir" || {
        _mensagec "${RED}" "Erro: Diretório $temp_dir não acessível"
        return 1
    }

    # Baixar arquivo (somente se online)
    if [[ "$is_online" == "true" ]]; then
        if ! wget -q -c "$link"; then
            _mensagec "${RED}" "Erro ao baixar arquivo de atualização"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Verificar se o arquivo zip existe
    if [[ ! -f "$zipfile" ]]; then
        _mensagec "${RED}" "Erro: Arquivo $zipfile não encontrado"
         rm -rf "$temp_dir"
        return 1
    fi
    
    # Descompactar
    if ! unzip -o -j "$zipfile"; then
        _mensagec "${RED}" "Erro ao descompactar atualização"
         rm -rf "$temp_dir"
        return 1
    fi

    # Verificar se há arquivos .sh após descompactação
    local sh_files=(*.sh)
    if [[ ! -f "${sh_files[0]}" ]]; then
        _mensagec "${RED}" "Erro: Nenhum arquivo .sh encontrado no arquivo descompactado"
         rm -rf "$temp_dir"
        return 1
    fi

    # Verificar e instalar arquivos
    local arquivos_instalados=0
    local arquivos_erro=0

    # Processar todos os arquivos .sh encontrados
    for arquivo in *.sh; do
        # Verificar se o arquivo existe
        if [[ ! -f "$arquivo" ]]; then
            continue
        fi
        
        # Dar permissão de execução
        chmod +x "$arquivo"

        # Determinar destino
        if [[ "$arquivo" == "atualiza.sh" ]]; then
            target="${TOOLS}"
        else
            target="${LIB_DIR}"
        fi
        
        # Mover o arquivo para o diretório de destino
        if mv -f "$arquivo" "$target"; then
             _mensagec "${GREEN}" "Arquivo $arquivo instalado com sucesso"
            ((arquivos_instalados++))
        else
            _mensagec "${RED}" "Erro ao instalar $arquivo"
            ((arquivos_erro++))
        fi
    done

    # Limpeza do diretório temporário
    cd "${TOOLS}" || true
    rm -rf "$temp_dir"

    # Verificar se houve erros na instalação
    if [[ $arquivos_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha na instalação de $arquivos_erro arquivo(s)"
        return 1
    elif [[ $arquivos_instalados -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi instalado"
        return 1
    else
        _mensagec "${GREEN}" "Instalados $arquivos_instalados arquivo(s) com sucesso"
    fi

    _mensagec "${GREEN}" "Atualização concluída com sucesso!"
    _mensagec "${GREEN}" "Ao terminar, entre novamente no sistema"
    return 0
}

# Atualização online via GitHub
_atualizar_online() {
    local link="https://github.com/Luizaugusto1962/Atualiza2025/archive/master.zip"
    local zipfile="master.zip"
    local temp_dir="${ENVIA_DIR}/temp_update"
    
    # Criar e acessar diretório temporário
    mkdir -p "$temp_dir" || {
        _mensagec "${RED}" "Erro: Não foi possível criar o diretório temporário $temp_dir."
        log "Erro: Não foi possível criar o diretório temporário $temp_dir."
        return 1
    }
    
    _atualizando "$link" "$zipfile" "$temp_dir" "true"
    return $?
}

# Atualização offline via arquivo local
_atualizar_offline() {
    local temp_dir="${ENVIA_DIR}/temp_update"
    local dir_offline="${ACESSO_OFFLINE}"
    local zipfile="atualiza.zip"

    # Criar diretório temporário
    mkdir -p "$temp_dir" || {
        _mensagec "${RED}" "Erro: Não foi possível criar o diretório temporário $temp_dir."
        return 1
    }

    # Acessar diretório offline
    cd "$dir_offline" || {
        _mensagec "${RED}" "Erro: Diretório offline $dir_offline não acessível"
        rm -rf "$temp_dir"
        return 1
    }

    # Verificar se o arquivo zip existe
    if [[ ! -f "$zipfile" ]]; then
        _mensagec "${RED}" "Erro: $zipfile não encontrado em $dir_offline"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Copiar arquivo para diretório temporário
    if ! cp "${zipfile}" "${temp_dir}/"; then
        _mensagec "${RED}" "Erro: Não foi possível copiar $zipfile para $temp_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    _atualizando "" "$zipfile" "$temp_dir" "false"
    return $?
}

# Executa atualização do script
_executar_update() {
    local retorno=0
#---------- FUNÇÕES DE ATUALIZAÇÃO ----------#
    # Menu de seleção      
    M700="Menu de Tipo de Atualizacao."
    M701="1${NORM} - On-line"
    M702="2${NORM} - Off-line"
    M705="9${NORM} - ${RED}Sair "
    M103=" Escolha a opcao:"
    M110=" Digite a opcao desejada ->"

	# Display Menu
    printf "\n"
    _mensagec "${RED}" "${M700}"
    printf "\n"
    _mensagec "${YELLOW}" "${M103}"
    printf "\n"
    _mensagec "${GREEN}" "${M701}"
    printf "\n"
    _mensagec "${GREEN}" "${M702}"
    printf "\n\n"
    _mensagec "${GREEN}" "${M705}"
    printf "\n"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO

    # Processar opcao
    case ${OPCAO} in
    1) _atualizar_online 
        retorno=$?
    ;;
    2) _atualizar_offline
        retorno=$?
    ;;
    9)
        exit 1
        ;;
    *)
        echo "Opcao Invalida"
        ;;
    esac
    _press
	return $retorno
}

# Função principal
main() {
    _init_directories
    _cleanup_files
    _move_config_files
    
    if _executar_update; then
        log "Rotina concluída com sucesso."
        exit 0
    else
        log "Rotina concluída com erros."
        exit 1
    fi
}

# Executar função principal
main "$@"