#!/usr/bin/env bash
set -euo pipefail
# sistema.sh - Modulo de Informacoes do Sistema
# Responsavel por informacoes do IsCOBOL, Linux, parametros e atualizacoes
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 28/04/2026-03
#

# Variaveis globais esperadas
cfg_dir="${cfg_dir:-}"      # Caminho do diretorio de configuracao do programa.
lib_dir="${lib_dir:-}"      # Diretorio dos modulos de biblioteca.
cmd_unzip="${cmd_unzip:-}"  # Comando de descompactacao (unzip).
sistema="${sistema:-}"      # Variavel do sistema em uso (ex: iscobol, linux).
Offline="${Offline:-}"      # Variavel do status de conexao (s/n).
down_dir="${down_dir:-}"    # Variavel do diretorio de download para atualizacao offline.

# Executa atualizacao do script
_executar_update() {
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

# Atualizacao online via GitHub
_atualizando() {
    local zipfile="atualiza.zip"
    
    _configurar_diretorios

    # Criar backup do arquivo atual
    if [[ ! -d "${BACKUP}" ]]; then
        mkdir -p "${BACKUP}" || {
            _mensagec "${RED}" "Erro: Nao foi possivel criar diretorio de backup"
            _read_sleep 2
            return 1
        }
        chmod "${PERM_DIR_SECURE}" "${BACKUP}"
    fi

    # Fazer backup dos arquivos atuais
    local backup_sucesso=0
    local backup_erro=0
    cd "${lib_dir}" || {
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
        if cp -f "$arquivo" "$BACKUP/$arquivo.bkp"; then
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

        if cd "${BACKUP}" && zip -jm "${zip_nome}" ./*.sh.bkp >>"$LOG_ATU" 2>&1; then
            _mensagec "${GREEN}" "Backup compactado com sucesso: ${BACKUP}/${zip_nome}"
        else
            _mensagec "${YELLOW}" "Aviso: Nao foi possivel compactar os arquivos de backup"
        fi
    fi

    # Acessar diretorio de trabalho
    cd "$RECEBE" || {
        _mensagec "${RED}" "Erro: Diretorio $RECEBE nao acessivel"
        _read_sleep 2
        return 1
    }

    # Descompactar
    if ! "${cmd_unzip}" -o -j "$zipfile" >>"$LOG_ATU" 2>&1; then
        _mensagec "${RED}" "Erro ao descompactar atualizacao"
        _mensagec "${YELLOW}" "Verifique se o atualiza.zip esta no diretorio $ENVIA"
        _read_sleep 2 
        return 1
    fi
    # Verificar e instalar arquivos
    local arquivos_instalados=0
    local arquivos_erro=0

    #---------- INSTALAR ARQUIVOS DE CONFIGURAÇÃO ----------#
    # Processa arquivos de parametros para o destino ${cfg_dir}
    local -a cfg_files=("manual.txt" "avisos" "indexar" "limpetmp" ".senhas")
    
    for cfg_arquivo in "${cfg_files[@]}"; do
        if [[ ! -f "$cfg_arquivo" ]]; then
            continue 
        fi

        # Definir permissões executáveis
        chmod +x "$cfg_arquivo" 2>/dev/null || true

        # Definir destino (cfg_dir para todos os arquivos de config)
        local cfg_target="${cfg_dir}"
        
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
            sh_target="${lib_dir}"
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
if [[ ! -d "${RECEBE}" ]]; then
    _mensagec "${RED}" "ERRO: Diretorio '${RECEBE}' nao encontrado."
    _read_sleep 2
    return 1
fi

# Mudar para o diretório RECEBE com verificação
if ! cd "${RECEBE}"; then
   _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${RECEBE}'."
    _read_sleep 2
    return 1
fi

# Confirmar que estamos no diretório correto antes de deletar
if [[ "$PWD" != "${RECEBE}" ]]; then
    _mensagec "${RED}" "ERRO: Falha na verificacao de seguranca do diretorio."
    _read_sleep 2
    return 1
fi

# Verificar se há arquivos para remover
if [[ -n "$(ls -A 2>/dev/null)" ]]; then
    _mensagec "${YELLOW}" "Limpando conteudo do diretorio: ${RECEBE}"
    
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

    return 0
}

_atualizar_online() {
# URL do arquivo zip de atualizacao no GitHub
    local link="https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip"
    local temp_dir="${RECEBE}/temp_update/"
    local zipfile="atualiza.zip"
    
    _mensagec "${GREEN}" "Atualizando script via GitHub..."

if ! cd "${RECEBE}"; then
   _mensagec "${RED}" "ERRO: Nao foi possivel acessar o diretorio '${RECEBE}'."
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
        chmod "${PERM_DIR_SECURE}" "$temp_dir" 2>/dev/null || true
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
