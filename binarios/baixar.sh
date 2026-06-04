#!/usr/bin/env bash
set -euo pipefail
# baixar.sh - Modulo de Atualizacao do Script
# Responsavel por baixa e aplica atualizacoes do sistema de atualização
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 26/05/2026
#
# =============================================================================
# FUNCOES DE ATUALIZACAO
# =============================================================================
_executar_update() {
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

    shopt -s nullglob
    local arquivos_sh=("${DEFAULT_LIBS_DIR}"/*.sh)
    shopt -u nullglob

    for arquivo in "${arquivos_sh[@]}"; do
        if cp -f "$arquivo" "${DEFAULT_BACKUP_DIR}/$(basename "$arquivo").bkp" 2>/dev/null; then
            _mensagec "${GREEN}" "Backup do arquivo $(basename "$arquivo") feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _mensagec "${RED}" "Erro ao fazer backup de $(basename "$arquivo")"
            ((backup_erro++)) || true
            _aguardar 2
        fi
    done

    if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/atualiza.sh" ]]; then
        if cp -f "${SCRIPT_DIR}/atualiza.sh" "${DEFAULT_BACKUP_DIR}/atualiza.sh.bkp"; then
            _mensagec "${GREEN}" "Backup do arquivo atualiza.sh feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _mensagec "${RED}" "ERRO: Falha ao fazer backup de atualiza.sh"
            ((backup_erro++)) || true
        fi
    fi

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
        local data_zip 
        data_zip=$(date +"%d%m")
        local zip_nome="${data_zip}_backup.zip"
        if (cd "${DEFAULT_BACKUP_DIR}" && zip -jm "${zip_nome}" ./*.sh.bkp >>"$LOG_ATU" 2>&1); then
            _mensagec "${GREEN}" "Backup compactado com sucesso: ${DEFAULT_BACKUP_DIR}/${zip_nome}"
        else
            _mensagec "${YELLOW}" "Aviso: Nao foi possivel compactar os arquivos de backup"
        fi
    fi

    # =========================================================================
    # CORRECAO CRITICA: Localizar origem do ZIP e preparar ambiente
    # =========================================================================
    local temp_dir="${DEFAULT_RECEBE_DIR}/temp_update/"
    local origem_zip=""

    if [[ -f "${temp_dir}/${zipfile}" ]]; then
        origem_zip="${temp_dir}/${zipfile}"
    elif [[ -f "${DEFAULT_RECEBE_DIR}/${zipfile}" ]]; then
        origem_zip="${DEFAULT_RECEBE_DIR}/${zipfile}"
    else
        _mensagec "${RED}" "ERRO: Arquivo ${zipfile} nao encontrado para descompactacao."
        return 1
    fi

    # Acessar diretorio de trabalho para extracao segura
    cd "$(dirname "$origem_zip")" || {
        _mensagec "${RED}" "Erro: Diretorio de trabalho nao acessivel"
        return 1
    }

    # Descompactar
    if ! "${DEFAULT_UNZIP}" -o -j "$origem_zip" >>"$LOG_ATU" 2>&1; then
        _mensagec "${RED}" "Erro ao descompactar atualizacao"
        return 1
    fi

    #---------- INSTALAR ARQUIVOS DE CONFIGURAÇÃO ----------#
    local arquivos_instalados=0
    local arquivos_erro=0
    local -a configuracoes_files=("manual.txt" "avisos" "indexar" "limpetmp" ".senhas")
    for configuracoes_arquivo in "${configuracoes_files[@]}"; do
        if [[ ! -f "$configuracoes_arquivo" ]]; then continue; fi
        chmod +x "$configuracoes_arquivo" 2>/dev/null || true
        if mv -f "$configuracoes_arquivo" "${CFG_DIR}/"; then
            _mensagec "${GREEN}" "Arquivo $configuracoes_arquivo instalado em ${CFG_DIR}"
            ((arquivos_instalados++)) || true
        else
            ((arquivos_erro++)) || true
        fi
    done

    #---------- INSTALAR ARQUIVOS .SH ----------#
    local sh_instalados=0
    for arquivo in *.sh; do
        [[ -f "$arquivo" ]] || continue
        chmod +x "$arquivo" 2>/dev/null || true
        local sh_destino="${DEFAULT_LIBS_DIR}"
        [[ "$arquivo" == "atualiza.sh" ]] && sh_destino="${SCRIPT_DIR}"
        if mv -f "$arquivo" "${sh_destino}/"; then
            _mensagec "${GREEN}" "Instalado $arquivo em $sh_destino"
            ((arquivos_instalados++)) || true
            ((sh_instalados++)) || true
        else
            ((arquivos_erro++)) || true
        fi
    done

    if [[ $arquivos_erro -gt 0 ]]; then
        _mensagec "${RED}" "Falha na instalacao de $arquivos_erro arquivo(s)"
        return 1
    elif [[ $arquivos_instalados -eq 0 ]]; then
        _mensagec "${YELLOW}" "Nenhum arquivo foi instalado - verifique os arquivos no ZIP"
        return 1
    else
        _mensagec "${GREEN}" "SUCESSO: $arquivos_instalados arquivo(s) instalado(s)"
    fi

    # =========================================================================
    # ROTINA DE LIMPEZA CORRIGIDA (SUBSTITUI A ANTIGA BASEADA EM cd + rm -rf ./*)
    # =========================================================================
    _mensagec "${CYAN}" "Realizando limpeza dos arquivos de atualizacao..."

    # 1. Remover ZIP da raiz de receber (modo online)
    if [[ -f "${DEFAULT_RECEBE_DIR}/${zipfile}" ]]; then
        rm -f "${DEFAULT_RECEBE_DIR}/${zipfile}" 2>/dev/null && _log "ZIP original removido: ${DEFAULT_RECEBE_DIR}/${zipfile}"
    fi

    # 2. Remover ZIP do temp_update (modo offline)
    if [[ -f "${temp_dir}/${zipfile}" ]]; then
        rm -f "${temp_dir}/${zipfile}" 2>/dev/null && _log "ZIP temporario removido: ${temp_dir}/${zipfile}"
    fi

    # 3. Remover diretorio temp_update completamente (contem apenas restos da extracao)
    if [[ -d "${temp_dir}" ]]; then
        rm -rf "${temp_dir}" 2>/dev/null && _log "Diretorio temporario removido: ${temp_dir}"
    fi

    # 4. Limpeza residual segura (apenas arquivos nomeados como 'atualiza*' no diretorio receber)
  # Excluir TODOS os arquivos e subdiretórios (inclusive ocultos) sem remover a pasta principal
    if find "${DEFAULT_RECEBE_DIR:?}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; then
        _mensagec "${GREEN}" "Diretorio limpo com sucesso."
    else
        _mensagec "${YELLOW}" "AVISO: Alguns arquivos podem nao ter sido removidos."
    fi
    _linha
    _mensagec "${GREEN}" "Atualizacao concluida com sucesso!"
    _mensagec "${GREEN}" "Ao terminar, entre novamente no sistema"
    _linha

        # Finalizar sistema de variáveis (limpeza explícita)

    if command -v _encerrar_programa >/dev/null 2>&1; then
        _encerrar_programa
    fi
#    return 0
}

_atualizar_online() {
    local link="https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip"
    local zipfile="atualiza.zip"
    _mensagec "${GREEN}" "Atualizando script via GitHub..."
    
    mkdir -p "${DEFAULT_RECEBE_DIR}" || { _mensagec "${RED}" "Erro ao criar diretorio de download"; return 1; }
    cd "${DEFAULT_RECEBE_DIR}" || { _mensagec "${RED}" "Erro ao acessar diretorio de download"; return 1; }

    if ! wget -q -c "$link" -O "${DEFAULT_RECEBE_DIR}/${zipfile}"; then
        _mensagec "${RED}" "Erro ao baixar arquivo de atualizacao. Verifique a conexao."
        return 1
    fi
    _atualizando
}

_atualizar_offline() {
    local temp_dir="${DEFAULT_RECEBE_DIR}/temp_update/"
    local zipfile="atualiza.zip"
    
    if [[ ! -f "${temp_dir}/${zipfile}" ]]; then
        _mensagec "${RED}" "Erro: $zipfile nao encontrado em $temp_dir"
        return 1
    fi
    _atualizando
}
