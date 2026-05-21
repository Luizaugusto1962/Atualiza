#!/usr/bin/env bash
set -euo pipefail
# baixar.sh - Modulo de Atualizacao do Script
# Responsavel por baixa e aplica atualizacoes do sistema de atualização
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 20/05/2026-03
#

# Variaveis globais esperadas

#CFG_DIR="${CFG_DIR:-}"                          # Caminho do diretorio de configuracao do programa.
#LIBS_DIR="${LIBS_DIR:-}"                          # Diretorio dos modulos de biblioteca.
#DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (unzip).
#CFG_SISTEMA="${CFG_SISTEMA:-}"                  # Variavel do sistema em uso (ex: iscobol, linux).
#CFG_OFFLINE="${CFG_OFFLINE:-}"                  # Variavel do status de conexao (s/n).
#DEFAULT_RECEBE_DIR="${DEFAULT_RECEBE_DIR:-}"    # Variavel do diretorio de download para atualizacao offline.

# Executa atualizacao do script
_executar_update() {
    #_configurar_acessos
    if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then
        if [[ "${CFG_OFFLINE}" == "n" ]]; then
            _atualizar_online
        else
            _atualizar_offline
        fi
    fi    
    _aguardar_tecla
}

# Atualizacao online via GitHub
_atualizando() {
    local zipfile="atualiza.zip"

    _configurar_diretorios

	local caminho="${CFG_DIR}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }

    # Fazer backup dos arquivos atuais
    local backup_sucesso=0
    local backup_erro=0
    cd "${LIBS_DIR}" || {
        _mensagec "${RED}" "Erro: Diretorio de atualizacao nao encontrado"
        _aguardar 2
        return 1
    }
    # Processar todos os arquivos .sh para backup
    for arquivo in *.sh; do
        # Verificar se o arquivo existe
        [[ -f "$arquivo" ]] || continue
        if [[ ! -f "$arquivo" ]]; then
           _mensagec "${YELLOW}" "Aviso: Nenhum arquivo .sh encontrado para backup"
           _aguardar 2
           return 1
         fi

        # Copiar o arquivo para o diretorio de backup
        if cp -f "$arquivo" "$DEFAULT_BACKUP_DIR/$arquivo.bkp"; then
            _mensagec "${GREEN}" "Backup do arquivo $arquivo feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _mensagec "${RED}" "Erro ao fazer backup de $arquivo"
            ((backup_erro++)) || true
            _aguardar 2
        fi
    done

    # Copiar arquivo atualiza.sh do SCRIPT_DIR para backup
    if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/atualiza.sh" ]]; then
        if cp -f "${SCRIPT_DIR}/atualiza.sh" "${DEFAULT_BACKUP_DIR}/atualiza.sh.bkp"; then
            _mensagec "${GREEN}" "Backup do arquivo atualiza.sh feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _mensagec "${RED}" "ERRO: Falha ao fazer backup de atualiza.sh"
            ((backup_erro++)) || true
        fi
    fi

    # Verificar se houve erros no backup
    if [[ $backup_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha no backup de $backup_erro arquivo(s)"
        _aguardar 2
        return 1
    elif [[ $backup_sucesso -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi copiado para backup"
        _aguardar 2
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
local temp_dir="${DEFAULT_RECEBE_DIR}/temp_update/"
    # Acessar diretorio de trabalho
    cd "${temp_dir}" || {
        _mensagec "${RED}" "Erro: Diretorio $temp_dir nao acessivel"
        _aguardar 2
        return 1
    }

    # Descompactar
    if ! "${DEFAULT_UNZIP}" -o -j "$zipfile" >>"$LOG_ATU" 2>&1; then
        _mensagec "${RED}" "Erro ao descompactar atualizacao"
        _mensagec "${YELLOW}" "Verifique se o atualiza.zip esta no diretorio $temp_dir e se o comando de descompactacao esta configurado corretamente"
        _aguardar 2 
        return 1
    fi
    # Verificar e instalar arquivos
    local arquivos_instalados=0
    local arquivos_erro=0

    #---------- INSTALAR ARQUIVOS DE CONFIGURAÇÃO ----------#
    # Processa arquivos de parametros para o destino ${CFG_DIR}
    local -a configuracoes_files=("manual.txt" "avisos" "indexar" "limpetmp" ".senhas")
    
    for configuracoes_arquivo in "${configuracoes_files[@]}"; do
        if [[ ! -f "$configuracoes_arquivo" ]]; then
            continue 
        fi

        # Definir permissões executáveis
        chmod +x "$configuracoes_arquivo" 2>/dev/null || true

        # Definir destino (CFG_DIR para todos os arquivos de config)

	    local caminho="${CFG_DIR}"
        # Criar destino se não existir
        if ! mkdir -p "$caminho" 2>/dev/null; then
            _mensagec "${RED}" "Erro ao criar diretorio de destino: $caminho"
            ((arquivos_erro++)) || true
            chmod "${PERM_DIR_SECURE}" "$caminho" 2>/dev/null || true
            continue
        fi

        # Mover arquivo para destino
        if mv -f "$configuracoes_arquivo" "$caminho/$configuracoes_arquivo"; then
            _mensagec "${GREEN}" "Arquivo $configuracoes_arquivo instalado em $caminho"
            ((arquivos_instalados++)) || true
             
        else
            _mensagec "${RED}" "ERRO:Falha ao instalar $configuracoes_arquivo"
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
        local sh_destino
        if [[ "$arquivo" == "atualiza.sh" ]]; then
            sh_destino="${SCRIPT_DIR}"
        else
            sh_destino="${LIBS_DIR}"
        fi

        # Mover arquivo para destino
        if mv -f "$arquivo" "$sh_destino/"; then
            _mensagec "${GREEN}" "Instalado $arquivo em $sh_destino"
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
        _aguardar 2
        return 1
    fi
    
    # Mudar para o diretório RECEBE com verificação
    if ! cd "${DEFAULT_RECEBE_DIR}"; then
       _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${DEFAULT_RECEBE_DIR}'."
        _aguardar 2
        return 1
    fi
    
    # Confirmar que estamos no diretório correto antes de deletar
    if [[ "$PWD" != "${DEFAULT_RECEBE_DIR}" ]]; then
        _mensagec "${RED}" "ERRO: Falha na verificacao de seguranca do diretorio."
        _aguardar 2
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
    _aguardar 2
    return 1
fi

    # Criar e acessar diretorio temporario
    mkdir -p "$temp_dir" || {
        _mensagec "${RED}" "Erro: Nao foi possivel criar o diretorio temporario $temp_dir."
        _aguardar 2
        chmod "${PERM_DIR_SECURE}" "$temp_dir" 2>/dev/null || true
        return 1
    }

    cd "${temp_dir}" || {
        _mensagec "${RED}" "Erro: Diretorio de trabalho $temp_dir nao acessivel"
        _aguardar 2
        return 1
    }

    # Baixar arquivo
    if ! wget -q -c "$link" -O "$zipfile"; then
        _mensagec "${RED}" "Erro ao baixar arquivo de atualizacao"
        _mensagec "${YELLOW}" "Verifique sua conexao com a internet e tente novamente"
        _aguardar 2
        return 1
    fi
       _atualizando
}

# Atualizacao offline via arquivo local
_atualizar_offline() {
    local temp_dir="${DEFAULT_RECEBE_DIR}/temp_update/"
    local zipfile="atualiza.zip"

    # Verificar se o arquivo zip existe
    if [[ ! -f "${temp_dir}/${zipfile}" ]]; then
        _mensagec "${RED}" "Erro: $zipfile nao encontrado em $temp_dir"
        _mensagec "${YELLOW}" "Certifique-se de que o arquivo $zipfile esteja presente no diretorio $temp_dir"
        _aguardar 2
        return 1
    fi

    _criar_diretorio_seguro "${temp_dir}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        printf "Erro ao criar diretorio de configuracao %s\n" "${temp_dir}" >&2
        return 1
    }

    mv "${temp_dir}/${zipfile}" "${temp_dir}" || {
        _mensagec "${RED}" "Erro: Nao foi possivel mover $zipfile para $temp_dir"
        _aguardar 2
        return 1
    }

        # Acessar diretorio offline
    cd "$temp_dir" || {
        _mensagec "${RED}" "Erro: Diretorio temporario, $temp_dir nao acessivel"
        _aguardar 2
        return 1
    }
    _atualizando
}
