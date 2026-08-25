#!/usr/bin/env bash
set -euo pipefail
#
# baixar.sh - Modulo de Atualizacao do Script
# Responsavel por baixa e aplica atualizacoes do sistema de atualização
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 25/08/2026-01
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

# Valida se um diretorio pode ser alvo de operacoes de escrita/remocao (nao vazio, nao raiz, caminho seguro)
# Retorna: 0=seguro 1=inseguro
_validar_diretorio_operacao() {
    local diretorio="$1"

    if [[ -z "$diretorio" || "$diretorio" == "/" || "$diretorio" == "//" ]]; then
        return 1
    fi
    _validar_caminho_seguro "$diretorio"
}

# Atualizacao online via GitHub
_atualizando() {
    local arquivo_zip="atualiza.zip"
    _configurar_diretorios
    local caminho="${CFG_DIR}"
    _criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Erro ao criar diretorio de configuracao %s\n" "${caminho}" >&2
        return 1
    }

    # SEGURANCA: validar diretorio de bibliotecas antes de operar
    if ! _validar_diretorio_operacao "${LIBS_DIR}"; then
        _erro "Diretorio de bibliotecas invalido ou inseguro: ${LIBS_DIR}"
        _aguardar 2
        return 1
    fi

    # SEGURANCA: validar diretorio de backup antes de copiar arquivos
    if ! _validar_diretorio_operacao "${DEFAULT_BACKUP_DIR}"; then
        _erro "Diretorio de backup invalido ou inseguro: ${DEFAULT_BACKUP_DIR}"
        _aguardar 2
        return 1
    fi

    # Fazer backup dos arquivos atuais
    local backup_sucesso=0
    local backup_erro=0
    cd "${LIBS_DIR}" || {
        _erro "Diretorio de atualizacao nao encontrado"
        _aguardar 2
        return 1
    }

    shopt -s nullglob
    local arquivos_sh=("${LIBS_DIR}"/*.sh)
    shopt -u nullglob

    for arquivo in "${arquivos_sh[@]}"; do
        local nome_base="${arquivo##*/}"
        if cp -f "$arquivo" "${DEFAULT_BACKUP_DIR}/${nome_base}.bkp" 2>/dev/null; then
            _exibir_mensagem_centralizada "${VERDE}" "Backup do arquivo ${nome_base} feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _erro "Ao fazer backup de ${nome_base}"
            ((backup_erro++)) || true
            _aguardar 2
        fi
    done

    if [[ -n "${SCRIPT_DIR}" ]] && ! _validar_diretorio_operacao "${SCRIPT_DIR}"; then
        _erro "Diretorio do script principal invalido ou inseguro: ${SCRIPT_DIR}"
        _aguardar 2
        return 1
    fi

    if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/atualiza.sh" ]]; then
        if cp -f "${SCRIPT_DIR}/atualiza.sh" "${DEFAULT_BACKUP_DIR}/atualiza.sh.bkp"; then
            _exibir_mensagem_centralizada "${VERDE}" "Backup do arquivo atualiza.sh feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _erro "Falha ao fazer backup de atualiza.sh"
            ((backup_erro++)) || true
        fi
    fi

    if [[ $backup_erro -gt 0 ]]; then
        _erro "Falha no backup de $backup_erro arquivo(s)"
        _aguardar 2
        return 1
    elif [[ $backup_sucesso -eq 0 ]]; then
        _aviso "Nenhum arquivo foi copiado para backup"
        _aguardar 2
        return 1
    else
        _exibir_mensagem_centralizada "${VERDE}" "Backup de $backup_sucesso arquivo(s) realizado com sucesso"
        local data_zip
        data_zip=$(date +"%d%m")
        local nome_do_zip="${data_zip}_backup.zip"
        if (cd "${DEFAULT_BACKUP_DIR}" && zip -jm "${nome_do_zip}" ./*.sh.bkp >>"$LOG_ATU" 2>&1); then
            _exibir_mensagem_centralizada "${VERDE}" "Backup compactado com sucesso: ${DEFAULT_BACKUP_DIR}/${nome_do_zip}"
        else
            _aviso "Nao foi possivel compactar os arquivos de backup"
        fi
    fi

    # =========================================================================
    # CORRECAO CRITICA: Localizar origem do ZIP e preparar ambiente
    # =========================================================================
    local temp_dir="${DEFAULT_RECEBE_DIR}/dir_temp_atualizacao/"
    local origem_zip=""

    if [[ -f "${temp_dir}/${arquivo_zip}" ]]; then
        origem_zip="${temp_dir}/${arquivo_zip}"
    elif [[ -f "${DEFAULT_RECEBE_DIR}/${arquivo_zip}" ]]; then
        origem_zip="${DEFAULT_RECEBE_DIR}/${arquivo_zip}"
    else
        _erro "Arquivo ${arquivo_zip} nao encontrado para descompactacao."
        return 1
    fi

    # Acessar diretorio de trabalho para extracao segura
    cd "$(dirname "$origem_zip")" || {
        _erro "Diretorio de trabalho nao acessivel"
        return 1
    }

    # Descompactar
    if ! "${DEFAULT_UNZIP}" -o -j "$origem_zip" >>"$LOG_ATU" 2>&1; then
        _erro "Ao descompactar atualizacao"
        return 1
    fi

    #---------- INSTALAR ARQUIVOS DE CONFIGURAÇÃO ----------#
    local arquivos_instalados=0
    local arquivos_erro=0
    local -a arquivos_configuracoes=("manual.txt" "avisos" "indexar" "limpetmp" "variosarquivos")
    for configuracoes_arquivo in "${arquivos_configuracoes[@]}"; do
        if [[ ! -f "$configuracoes_arquivo" ]]; then continue; fi
        # SEGURANCA: aceitar apenas nomes simples (sem caminho/traversal)
        if [[ ! "$configuracoes_arquivo" =~ ^[A-Za-z0-9._-]+$ ]]; then
            _log "AVISO: arquivo de configuracao com nome invalido ignorado: ${configuracoes_arquivo}" "${LOG_ATU}"
            continue
        fi
        chmod +x "$configuracoes_arquivo" 2>/dev/null || true
        if mv -f "$configuracoes_arquivo" "${CFG_DIR}/"; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo $configuracoes_arquivo instalado em ${CFG_DIR}"
            ((arquivos_instalados++)) || true
        else
            ((arquivos_erro++)) || true
        fi
    done

    # .senhas tratado separadamente — permissao 0600 (privado)
    if [[ -f ".senhas" ]]; then
        chmod 600 ".senhas" 2>/dev/null || true
        if mv -f ".senhas" "${CFG_DIR}/"; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo .senhas instalado em ${CFG_DIR}"
            ((arquivos_instalados++)) || true
        else
            ((arquivos_erro++)) || true
        fi
    fi

    #---------- INSTALAR ARQUIVOS .SH ----------#
    local sh_instalados=0
    for arquivo in *.sh; do
        [[ -f "$arquivo" ]] || continue
        # SEGURANCA: aceitar apenas nomes simples de script (sem caminho/traversal)
        if [[ ! "$arquivo" =~ ^[A-Za-z0-9._-]+\.sh$ ]]; then
            _log "AVISO: script com nome invalido ignorado: ${arquivo}" "${LOG_ATU}"
            continue
        fi
        chmod +x "$arquivo" 2>/dev/null || true
        local sh_destino="${LIBS_DIR}"
        [[ "$arquivo" == "atualiza.sh" ]] && sh_destino="${SCRIPT_DIR}"
        if mv -f "$arquivo" "${sh_destino}/"; then
            _exibir_mensagem_centralizada "${VERDE}" "Instalando programa $arquivo em $sh_destino"
            ((arquivos_instalados++)) || true
            ((sh_instalados++)) || true
        else
            ((arquivos_erro++)) || true
        fi
    done

    if [[ $arquivos_erro -gt 0 ]]; then
        _erro "Falha na instalacao de $arquivos_erro arquivo(s)"
        return 1
    elif [[ $arquivos_instalados -eq 0 ]]; then
        _aviso "Nenhum arquivo foi instalado - verifique os arquivos no ZIP"
        return 1
    else
        _exibir_mensagem_centralizada "${VERDE}" "SUCESSO: $arquivos_instalados arquivo(s) instalado(s)"
    fi

    # =========================================================================
    # ROTINA DE LIMPEZA CORRIGIDA (SUBSTITUI A ANTIGA BASEADA EM cd + rm -rf ./*)
    # =========================================================================
    _exibir_mensagem_centralizada "${CIANO}" "Realizando limpeza dos arquivos de atualizacao..."

    # SEGURANCA: validar diretorios antes de qualquer remocao
    if ! _validar_diretorio_operacao "${DEFAULT_RECEBE_DIR}"; then
        _erro "Diretorio de recepcao invalido ou inseguro para limpeza: ${DEFAULT_RECEBE_DIR}"
        return 1
    fi
    if ! _validar_diretorio_operacao "${temp_dir}"; then
        _erro "Diretorio temporario invalido ou inseguro para limpeza: ${temp_dir}"
        return 1
    fi

    # 1. Remover ZIP da raiz de receber (modo online)
    if [[ -f "${DEFAULT_RECEBE_DIR}/${arquivo_zip}" ]]; then
        rm -f -- "${DEFAULT_RECEBE_DIR}/${arquivo_zip}" 2>/dev/null && _log "ZIP original removido: ${DEFAULT_RECEBE_DIR}/${arquivo_zip}"
    fi

    # 2. Remover ZIP do dir_temp_atualizacao (modo offline)
    if [[ -f "${temp_dir}/${arquivo_zip}" ]]; then
        rm -f -- "${temp_dir}/${arquivo_zip}" 2>/dev/null && _log "ZIP temporario removido: ${temp_dir}/${arquivo_zip}"
    fi

    # 3. Remover diretorio dir_temp_atualizacao completamente (contem apenas restos da extracao)
    if [[ -d "${temp_dir}" ]]; then
        rm -rf "${temp_dir}" 2>/dev/null && _log "Diretorio temporario removido: ${temp_dir}"
    fi

    # 4. Limpeza residual segura (excluir TODOS os arquivos/diretorios restantes no diretorio receber, sem remover a pasta principal)
    # Excluir todos os arquivos que ficaram no diretorio (atualiza.zip, extracao temporaria, etc.) sem remover a pasta principal
    if find "${DEFAULT_RECEBE_DIR:?}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; then
        _exibir_mensagem_centralizada "${VERDE}" "Diretorio limpo com sucesso."
    else
        _aviso "Alguns arquivos podem nao ter sido removidos."
    fi
    _linha
    _ok "Atualizacao concluida com sucesso!"
    _exibir_mensagem_centralizada "${VERDE}" "Ao terminar, entre novamente no sistema"
    _linha
    _encerrar_programa 0
}

# Restaura os scripts .sh anteriores a partir do backup feito em _atualizando
# O backup pode estar em arquivos .sh.bkp avulsos ou em um zip ddmm_backup.zip
_voltar_sh_anterior() {
    _configurar_diretorios

    # SEGURANCA: validar diretorios antes de operar
    if ! _validar_diretorio_operacao "${DEFAULT_BACKUP_DIR}"; then
        _erro "Diretorio de backup invalido ou inseguro: ${DEFAULT_BACKUP_DIR}"
        _aguardar 2
        return 1
    fi
    if ! _validar_diretorio_operacao "${LIBS_DIR}"; then
        _erro "Diretorio de bibliotecas invalido ou inseguro: ${LIBS_DIR}"
        _aguardar 2
        return 1
    fi
    if [[ -n "${SCRIPT_DIR}" ]] && ! _validar_diretorio_operacao "${SCRIPT_DIR}"; then
        _erro "Diretorio do script principal invalido ou inseguro: ${SCRIPT_DIR}"
        _aguardar 2
        return 1
    fi

    # Localizar os backups .sh.bkp (avulsos ou dentro de um zip de backup)
    local dir_restauracao="${DEFAULT_BACKUP_DIR}"
    shopt -s nullglob
    local backups_sh=("${DEFAULT_BACKUP_DIR}"/*.sh.bkp)
    shopt -u nullglob

    if (( ${#backups_sh[@]} == 0 )); then
        shopt -s nullglob
        local zips_backup=("${DEFAULT_BACKUP_DIR}"/*_backup.zip)
        shopt -u nullglob
        if (( ${#zips_backup[@]} == 0 )); then
            _erro "Nenhum backup anterior encontrado em ${DEFAULT_BACKUP_DIR}"
            _aguardar 2
            return 1
        fi

        # Unico backup: restaura automaticamente; varios backups: lista e deixa selecionar
        local zip_backup="${zips_backup[0]}"
        if (( ${#zips_backup[@]} > 1 )); then
            _linha
            _exibir_mensagem_centralizada "${CIANO}" "Backups disponiveis para restauracao:"
            _linha
            local indice_zip=1
            local zip_opcao
            for zip_opcao in "${zips_backup[@]}"; do
                _exibir_mensagem_centralizada "${VERDE}" "${indice_zip}) ${zip_opcao##*/}"
                ((indice_zip++)) || true
            done
            _linha
            _exibir_mensagem_centralizada "${AMARELO}" "Informe o numero do backup desejado ou 0 para sair:"
            local zip_escolha=""
            while true; do
                read -rp "${AMARELO}Opcao -> ${NORMAL}" zip_escolha
                _linha
                if [[ -z "${zip_escolha}" || "${zip_escolha}" == "0" ]]; then
                    _aviso "Operacao cancelada"
                    return 1
                fi
                if [[ "${zip_escolha}" =~ ^[0-9]+$ ]] \
                    && (( zip_escolha >= 1 && zip_escolha <= ${#zips_backup[@]} )); then
                    zip_backup="${zips_backup[$((zip_escolha - 1))]}"
                    break
                fi
                _erro "Opcao invalida. Informe um numero entre 1 e ${#zips_backup[@]}."
            done
        fi

        dir_restauracao="${DEFAULT_BACKUP_DIR}/dir_restaurar_sh"
        if ! _criar_diretorio_seguro "${dir_restauracao}" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
            _erro "Ao criar diretorio temporario de restauracao: ${dir_restauracao}"
            return 1
        fi
        if ! "${DEFAULT_UNZIP}" -o -j "${zip_backup}" -d "${dir_restauracao}" >>"$LOG_ATU" 2>&1; then
            _erro "Ao descompactar backup: ${zip_backup}"
            return 1
        fi
        shopt -s nullglob
        backups_sh=("${dir_restauracao}"/*.sh.bkp)
        shopt -u nullglob
    fi

    if (( ${#backups_sh[@]} == 0 )); then
        _erro "Nenhum arquivo de backup .sh.bkp encontrado para restauracao"
        _aguardar 2
        return 1
    fi

    if ! _confirmar "Restaurar ${#backups_sh[@]} script(s) do backup anterior?" "N"; then
        _aviso "Restauracao cancelada"
        _aguardar_tecla
        return 0
    fi

    local restaurados=0 erros=0 arquivo_backup nome_script destino
    for arquivo_backup in "${backups_sh[@]}"; do
        nome_script="${arquivo_backup##*/}"
        [[ "$nome_script" == *.sh.bkp ]] || continue
        nome_script="${nome_script%.bkp}"
        destino="${LIBS_DIR}"
        if [[ "$nome_script" == "atualiza.sh" && -n "${SCRIPT_DIR}" ]]; then
            destino="${SCRIPT_DIR}"
        fi
        if cp -f "$arquivo_backup" "${destino}/${nome_script}" 2>/dev/null; then
            chmod +x "${destino}/${nome_script}" 2>/dev/null || true
            _exibir_mensagem_centralizada "${VERDE}" "Restaurado ${nome_script} em ${destino}"
            ((restaurados++)) || true
        else
            _erro "Ao restaurar ${nome_script}"
            ((erros++)) || true
        fi
    done

    # Limpeza do diretorio temporario de restauracao
    if [[ "${dir_restauracao}" != "${DEFAULT_BACKUP_DIR}" && -d "${dir_restauracao}" ]]; then
        rm -rf "${dir_restauracao}" 2>/dev/null || true
    fi

    if [[ $erros -gt 0 ]]; then
        _erro "Falha na restauracao de $erros arquivo(s)"
        _aguardar 2
        return 1
    elif [[ $restaurados -eq 0 ]]; then
        _aviso "Nenhum arquivo foi restaurado"
        _aguardar 2
        return 1
    fi

    _linha
    _ok "Restauracao concluida: $restaurados script(s) restaurado(s)"
    _exibir_mensagem_centralizada "${VERDE}" "Ao terminar, entre novamente no sistema"
    _linha
    _aguardar_tecla
}

_atualizar_online() {
    local link="${GITHUB_UPDATE_URL}"
    local arquivo_zip="atualiza.zip"
    _exibir_mensagem_centralizada "${VERDE}" "Atualizando script via GitHub..."

    # SEGURANCA: permitir apenas URLs http(s) para download
    if [[ ! "${link}" =~ ^https?:// ]]; then
        _erro "URL de atualizacao invalida: ${link}"
        return 1
    fi

    # SEGURANCA: validar diretorio de download antes de usar wget
    if ! _validar_diretorio_operacao "${DEFAULT_RECEBE_DIR}"; then
        _erro "Diretorio de download invalido ou inseguro: ${DEFAULT_RECEBE_DIR}"
        return 1
    fi

    _criar_diretorio_seguro "${DEFAULT_RECEBE_DIR}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
    _erro "Ao criar diretorio de download"
    return 1
    }
    if ! wget -q -c "$link" -O "${DEFAULT_RECEBE_DIR}/${arquivo_zip}"; then
        _erro "Ao baixar arquivo de atualizacao. Verifique a conexao."
        return 1
    fi
    _atualizando
}

_atualizar_offline() {
    local temp_dir="${DEFAULT_RECEBE_DIR}/dir_temp_atualizacao/"
    local arquivo_zip="atualiza.zip"

    # SEGURANCA: validar diretorio temporario antes de operar
    if ! _validar_diretorio_operacao "${temp_dir}"; then
        _erro "Diretorio temporario invalido ou inseguro: ${temp_dir}"
        return 1
    fi

    if [[ ! -f "${temp_dir}/${arquivo_zip}" ]]; then
        _erro "Arquivo $arquivo_zip nao encontrado em $temp_dir"
        return 1
    fi
    _atualizando
}