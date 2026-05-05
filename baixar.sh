#!/usr/bin/env bash
set -euo pipefail
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 05/05/2026-03
#

# Variaveis globais esperadas
CFG_DIR="${CFG_DIR:-}"      # Caminho do diretorio de configuracao do programa.
LIB_DIR="${LIB_DIR:-}"      # Diretorio dos modulos de biblioteca.
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"  # Comando de descompactacao (unzip).
CFG_SISTEMA="${CFG_SISTEMA:-}"      # Variavel do sistema em uso (ex: iscobol, linux).
CFG_OFFLINE="${CFG_OFFLINE:-}"      # Variavel do status de conexao (s/n).
DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"    # Variavel do diretorio de download para atualizacao offline.

# Executa atualizacao do script
_executar_update() {
    _configurar_acessos
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "n" ]]; then
            _atualizar_online
        else
            _atualizar_offline
        fi
    fi    
    _press
}

# Atualizacao online via GitHub
_atualizando() {
    local zipfile="atualiza.zip"
    
    _configurar_diretorios

    # Criar backup do arquivo atual
    if [[ ! -d "${DEFAULT_BACKUP_DIR}" ]]; then
        mkdir -p "${DEFAULT_BACKUP_DIR}" || {
            _mensagec "${RED}" "Erro: Nao foi possivel criar diretorio de backup"
            _read_sleep 2
            return 1
        }
        chmod "${PERM_DIR_SECURE}" "${DEFAULT_BACKUP_DIR}"
    fi

    # Fazer backup dos arquivos atuais
    local backup_sucesso=0
    local backup_erro=0
    cd "${LIB_DIR}" || {
        _mensagec "${RED}" "Erro: Diretorio de atualizacao nao encontrado"
        _read_sleep 2
        return 1
    }
    # Processar todos os arquivos .sh para backup
    for arquivo in *.sh; do
        # Verificar se o arquivo existe
        [[ -f "$arquivo" ]] || continue
        if [[ ! -f "$arquivo" ]]; then
           _mensagec "${YELLOW}" "Aviso: Nenhum arquivo .sh encontrado para backup"
           _read_sleep 2
           return 1
         fi

        # Copiar o arquivo para o diretorio de backup
        if cp -f "$arquivo" "$DEFAULT_BACKUP_DIR/$arquivo.bkp"; then
            _mensagec "${GREEN}" "Backup do arquivo $arquivo feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _mensagec "${RED}" "Erro ao fazer backup de $arquivo"
            ((backup_erro++)) || true
            _read_sleep 2
        fi
    done

    # Verificar se houve erros no backup
    if [[ $backup_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha no backup de $backup_erro arquivo(s)"
        _read_sleep 2
        return 1
    elif [[ $backup_sucesso -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi copiado para backup"
        _read_sleep 2
        return 1
    else
        _mensagec "${GREEN}" "Backup de $backup_sucesso arquivo(s) realizado com sucesso"
         
         # Compactar arquivos .bkp com nome baseado na data atual (DDMM_backup.zip)
        local data_zip
        data_zip=$(date +"%d%m")
        local zip_nome="${data_zip}_backup.zip"

        if cd "${DEFAULT_BACKUP_DIR}" && zip -jm "${zip_nome}" ./*.sh.bkp >>"$LOG_ATU" 2>&1; then
            _mensagec "${GREEN}" "Backup compactado com sucesso: ${DEFAULT_BACKUP_DIR}/${zip_nome}"
        else
            _mensagec "${YELLOW}" "Aviso: Nao foi possivel compactar os arquivos de backup"
        fi
    fi

    # Acessar diretorio de trabalho
    cd "$DEFAULT_RECEBE_DIR" || {
        _mensagec "${RED}" "Erro: Diretorio $DEFAULT_RECEBE_DIR nao acessivel"
        _read_sleep 2
        return 1
    }

    # Descompactar
    if ! "${DEFAULT_UNZIP}" -o -j "$zipfile" >>"$LOG_ATU" 2>&1; then
        _mensagec "${RED}" "Erro ao descompactar atualizacao"
        _mensagec "${YELLOW}" "Verifique se o atualiza.zip esta no diretorio $DEFAULT_ENVIA_DIR"
        _read_sleep 2 
        return 1
    fi
    # Verificar e instalar arquivos
    local arquivos_instalados=0
    local arquivos_erro=0

    #---------- INSTALAR ARQUIVOS DE CONFIGURAÇÃO ----------#
    # Processa arquivos de parametros para o destino ${CFG_DIR}
    local -a cfg_files=("manual.txt" "avisos" "indexar" "limpetmp" ".senhas")
    
    for cfg_arquivo in "${cfg_files[@]}"; do
        if [[ ! -f "$cfg_arquivo" ]]; then
            continue 
        fi

        # Definir permissões executáveis
        chmod +x "$cfg_arquivo" 2>/dev/null || true

        # Definir destino (CFG_DIR para todos os arquivos de config)
        local cfg_target="${CFG_DIR}"
        
        # Criar destino se não existir
        if ! mkdir -p "$cfg_target" 2>/dev/null; then
            _mensagec "${RED}" "Erro ao criar diretorio de destino: $cfg_target"
            ((arquivos_erro++)) || true
            chmod "${PERM_DIR_SECURE}" "$cfg_target" 2>/dev/null || true
            continue
        fi

        # Mover arquivo para destino
        if mv -f "$cfg_arquivo" "$cfg_target/$cfg_arquivo"; then
            _mensagec "${GREEN}" "Arquivo $cfg_arquivo instalado em $cfg_target"
            ((arquivos_instalados++)) || true
             
        else
            _mensagec "${RED}" "ERRO:Falha ao instalar $cfg_arquivo"
            ((arquivos_erro++)) || true
        fi
    done

    #---------- INSTALAR ARQUIVOS .SH ----------#
    # Processa todos os arquivos .sh encontrados
    local sh_instalados=0

    for arquivo in *.sh; do
        # Verificar se o arquivo existe
        if [[ ! -f "$arquivo" ]]; then
            continue  
        fi

        # Definir permissões executáveis
        chmod +x "$arquivo" || {
            _mensagec "${RED}" "Aviso: falha ao definir permissao em $arquivo"
        }

        # Determinar destino baseado no nome do arquivo
        local sh_target
        if [[ "$arquivo" == "atualiza.sh" ]]; then
            sh_target="${SCRIPT_DIR}"
        else
            sh_target="${LIB_DIR}"
        fi

        # Criar destino se não existir
        if ! mkdir -p "$sh_target" 2>/dev/null; then
            _mensagec "${RED}" "Erro ao criar diretorio: $sh_target"
            ((arquivos_erro++)) || true
            chmod "${PERM_DIR_SECURE}" "$sh_target" 2>/dev/null || true
            continue

        fi

        # Mover arquivo para destino
        if mv -f "$arquivo" "$sh_target/"; then
            _mensagec "${GREEN}" "Instalado $arquivo em $sh_target"
            ((arquivos_instalados++)) || true
            ((sh_instalados++)) || true
        else
            _mensagec "${RED}" "ERRO: Falha ao instalar $arquivo"
            ((arquivos_erro++)) || true
        fi
    done

    # Relatório final de instalação
    if [[ $sh_instalados -eq 0 ]]; then
        _mensagec "${YELLOW}" "Aviso: Nenhum arquivo .sh foi instalado"
    fi

    #---------- VALIDACAO FINAL ----------#
    # Verificar resultado da instalação
    if [[ $arquivos_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha na instalacao de $arquivos_erro arquivo(s)"
        return 1
    elif [[ $arquivos_instalados -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi instalado - verifique os arquivos no ZIP"
        return 1
    else
        _mensagec "${GREEN}" "SUCESSO: $arquivos_instalados arquivo(s) instalado(s)"
    fi

    # Limpar diretorio de trabalho
    # Verificar se o diretório RECEBE existe
    if [[ ! -d "${DEFAULT_RECEBE_DIR}" ]]; then
        _mensagec "${RED}" "ERRO: Diretorio '${DEFAULT_RECEBE_DIR}' nao encontrado."
        _read_sleep 2
        return 1
    fi
    
    # Mudar para o diretório RECEBE com verificação
    if ! cd "${DEFAULT_RECEBE_DIR}"; then
       _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${DEFAULT_RECEBE_DIR}'."
        _read_sleep 2
        return 1
    fi
    
    # Confirmar que estamos no diretório correto antes de deletar
    if [[ "$PWD" != "${DEFAULT_RECEBE_DIR}" ]]; then
        _mensagec "${RED}" "ERRO: Falha na verificacao de seguranca do diretorio."
        _read_sleep 2
        return 1
    fi
    
    # Verificar se há arquivos para remover
    if [[ -n "$(ls -A 2>/dev/null)" ]]; then
        _mensagec "${YELLOW}" "Limpando conteudo do diretorio: ${DEFAULT_RECEBE_DIR}"
        
        # Remover apenas o conteúdo, não o próprio diretório
        if rm -rf ./* ./.[!.]* 2>/dev/null; then
            _mensagec "${GREEN}" "Diretorio limpo com sucesso."
        else
            _mensagec "${YELLOW}" "AVISO: Alguns arquivos podem nao ter sido removidos."
        fi
    else
        _mensagec "${GREEN}" "Diretorio ja esta vazio."
    fi
    _linha
    _mensagec "${GREEN}" "Atualizacao concluida com sucesso!"
    _mensagec "${GREEN}" "Ao terminar, entre novamente no sistema"
    _linha
    exit 1
#    return 0
}

_atualizar_online() {
# URL do arquivo zip de atualizacao no GitHub
    local link="https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip"
    local temp_dir="${DEFAULT_RECEBE_DIR}/temp_update/"
    local zipfile="atualiza.zip"
    
    _mensagec "${GREEN}" "Atualizando script via GitHub..."

if ! cd "${DEFAULT_RECEBE_DIR}"; then
   _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${DEFAULT_RECEBE_DIR}'."
    _read_sleep 2
    return 1
fi
    # Criar e acessar diretorio temporario
    mkdir -p "$temp_dir" || {
        _mensagec "${RED}" "Erro: Nao foi possivel criar o diretorio temporario $temp_dir."
        _read_sleep 2
        chmod "${PERM_DIR_SECURE}" "$temp_dir" 2>/dev/null || true
        return 1
    }

    # Baixar arquivo
    if ! wget -q -c --timeout=30 "$link" -O "$zipfile"; then
        _mensagec "${RED}" "Erro ao baixar arquivo de atualizacao"
        _mensagec "${YELLOW}" "Verifique sua conexao com a internet e tente novamente"
        _read_sleep 2
        return 1
    fi
    _atualizando
}

# Atualizacao offline via arquivo local
_atualizar_offline() {
    local temp_dir="${DEFAULT_RECEBE_DIR}/temp_update/"
    local zipfile="atualiza.zip"

    # Verificar se o arquivo zip existe
    if [[ ! -f "${DEFAULT_RECEBE_DIR}/${zipfile}" ]]; then
        _mensagec "${RED}" "Erro: $zipfile nao encontrado em $DEFAULT_RECEBE_DIR"
        _mensagec "${YELLOW}" "Certifique-se de que o arquivo $zipfile esteja presente no diretorio $DEFAULT_RECEBE_DIR"
        _read_sleep 2
        return 1
    fi
    # Criar e acessar diretorio temporario
    mkdir -p "$temp_dir" || {
        _mensagec "${RED}" "Erro: Nao foi possivel criar o diretorio temporario $temp_dir."
        _read_sleep 2
        chmod "${PERM_DIR_SECURE}" "$temp_dir" 2>/dev/null || true
        return 1
    }

    mv "${DEFAULT_RECEBE_DIR}/${zipfile}" "${DEFAULT_RECEBE_DIR}" || {
        _mensagec "${RED}" "Erro: Nao foi possivel mover $zipfile para $DEFAULT_RECEBE_DIR"
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
