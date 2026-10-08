#!/usr/bin/env bash
set -euo pipefail
#
# baixar.sh - Modulo de Atualizacao do Script
# Responsavel por baixa e aplica atualizacoes do sistema de atualização
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 08/10/2026-01
#
# =============================================================================
# FUNCOES DE ATUALIZACAO
# =============================================================================
# _executar_update e o ponto de entrada do menu (menus.sh, opcao 2 do menu de
# ferramentas). Delega para _atualizar_online/_atualizar_offline conforme a
# flag CFG_OFFLINE e, no caminho de sucesso, _atualizando encerra o programa
# via _encerrar_programa — chegar ate o fim desta funcao significa FALHA.
_executar_update() {
    local rc=0

    # Antes: `case "${CFG_OFFLINE:-}"` com n/s/* — o ramo * nao cobria
    # "S"/"N" maiusculos, que caiam no mesmo erro de valor invalido. A flag
    # e validada uma unica vez por _offline_valido (utils.sh), o mesmo
    # criterio usado em biblioteca.sh, programas.sh e backup.sh.
    if ! _offline_valido; then
        _offline_erro "atualizacao do sistema"
        rc=1
    elif [[ "$CFG_OFFLINE" == "s" ]]; then
        _atualizar_offline || rc=$?
    else
        _atualizar_online || rc=$?
    fi

    _aguardar_tecla
    # Propaga o rc: o menu embrulha em _tentar_log (utils.sh), mas um chamador
    # novo nao embrulhado perderia a falha no `set -e` do chamador.
    return "$rc"
}

# Valida se um diretorio pode ser alvo de operacoes de escrita/remocao (nao vazio, nao raiz, caminho seguro)
# Retorna: 0=seguro 1=inseguro
_validar_diretorio_operacao() {
    local diretorio="${1:-}"

    if [[ -z "$diretorio" || "$diretorio" == "/" || "$diretorio" == "//" ]]; then
        return 1
    fi
    _validar_caminho_seguro "$diretorio"
}

# Volta ao diretorio de trabalho anterior a extracao do ZIP. O menu segue
# rodando depois de _atualizando e nao pode herdar o cd da extracao.
# Falha aqui e silenciosa: sem diretorio anterior valido, seguir no atual e
# melhor do que abortar uma atualizacao ja concluida.
_voltar_dir_trabalho() {
    local alvo="${1:-}"

    if [[ -n "$alvo" && -d "$alvo" ]]; then
        cd -- "$alvo" 2>/dev/null || true
    fi
    return 0
}

# Copia os scripts atuais para DEFAULT_BACKUP_DIR e compacta tudo em um ZIP.
# Rodar antes de sobrescrever qualquer modulo e o que torna _voltar_sh_anterior
# possivel; por isso, se nada foi copiado, a atualizacao NAO deve prosseguir.
# Retorna: 0=backup ok (ZIP compactado ou apenas arquivos avulsos) 1=falha
_coletar_backups() {
    local _old_nullglob
    local arquivo nome_base
    local backup_sucesso=0
    local backup_erro=0

    # Sem `cd` para LIBS_DIR: o glob abaixo ja e absoluto e o cd vazava para
    # o restante do programa.
    if [[ ! -d "${LIBS_DIR}" ]]; then
        _erro "Diretorio de atualizacao nao encontrado: ${LIBS_DIR}"
        return 1
    fi

    # Salvar/restaurar nullglob (nao alterar o estado global do shell).
    # shopt -p devolve 1 quando a opcao esta DESLIGADA — por isso o || true.
    _old_nullglob=$(shopt -p nullglob) || _old_nullglob='shopt -u nullglob'
    shopt -s nullglob
    local -a arquivos_sh=("${LIBS_DIR}"/*.sh)
    if [[ "${_old_nullglob}" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi

    for arquivo in "${arquivos_sh[@]}"; do
        nome_base="${arquivo##*/}"
        if cp -f "$arquivo" "${DEFAULT_BACKUP_DIR}/${nome_base}${ATU_SUFIXO_BACKUP}" 2>/dev/null; then
            _exibir_mensagem_centralizada "${VERDE}" "Backup do arquivo ${nome_base} feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _erro "Ao fazer backup de ${nome_base}"
            ((backup_erro++)) || true
            _aguardar 2
        fi
    done

    if [[ -n "${SCRIPT_DIR:-}" ]] && [[ -f "${SCRIPT_DIR}/atualiza.sh" ]]; then
        if cp -f "${SCRIPT_DIR}/atualiza.sh" "${DEFAULT_BACKUP_DIR}/atualiza.sh${ATU_SUFIXO_BACKUP}" 2>/dev/null; then
            _exibir_mensagem_centralizada "${VERDE}" "Backup do arquivo atualiza.sh feito com sucesso"
            ((backup_sucesso++)) || true
        else
            _erro "Falha ao fazer backup de atualiza.sh"
            ((backup_erro++)) || true
        fi
    fi

    if (( backup_erro > 0 )); then
        _erro "Falha no backup de ${backup_erro} arquivo(s)"
        return 1
    fi
    if (( backup_sucesso == 0 )); then
        _aviso "Nenhum arquivo foi copiado para backup"
        return 1
    fi

    _exibir_mensagem_centralizada "${VERDE}" "Backup de ${backup_sucesso} arquivo(s) realizado com sucesso"

    # Nome com ddmm_HHMMSS: apenas ddmm sobrescrevia o ZIP na segunda
    # atualizacao do mesmo dia e o rollback perdia o estado intermediario.
    local nome_do_zip
    nome_do_zip="$(date +"%d%m_%H%M%S")_backup.zip"
    if (cd "${DEFAULT_BACKUP_DIR}" && zip -jm "${nome_do_zip}" ./*"${ATU_SUFIXO_BACKUP}" >>"$LOG_ATU" 2>&1); then
        _exibir_mensagem_centralizada "${VERDE}" "Backup compactado com sucesso: ${DEFAULT_BACKUP_DIR}/${nome_do_zip}"
    else
        _aviso "Nao foi possivel compactar os arquivos de backup"
    fi
    return 0
}

# Remove os artefatos da atualizacao aplicada: o ZIP original, o subdiretorio
# temporario de extracao, o staging e o ".part" de download interrompido. O
# conteudo restante da recepcao (CFG_PORTALSAV) e PRESERVADO — o topo dessa
# pasta e compartilhado com backups offline, ZIPs de biblioteca e o ZIP de
# reversao de programas, e nada aqui pode inferir que esses arquivos sao
# residuo da atualizacao.
# IMPORTANTE: so chame no caminho de SUCESSO. Num caminho de erro o ZIP e a
# unica copia do pacote que o usuario tem — apagar isso impediria a retentativa
# em modo offline, que nao depende de rede.
# Retorna: 0=limpo 1=restou residuo
_limpar_recepcao_atualizacao() {
    local arquivo_zip="${ARQUIVO_ZIP_ATU}"
    local temp_dir="${CFG_PORTALSAV%/}/${ATU_DIR_TEMP}"
    local staging="${CFG_PORTALSAV%/}/${ATU_DIR_STAGING}"
    local rc=0
    local nome_derivado

    # Esta e a unica funcao que faz `rm -rf` de caminho derivado, entao ela
    # mesma valida a entrada: com ATU_DIR_STAGING vazio, "$staging" resolveria
    # para "CFG_PORTALSAV/" e o rm apagaria o diretorio de recepcao inteiro.
    # ATU_SUFFIXO_PARCIAL entra na lista porque o ".part" do download
    # interrompido e derivado do nome do ZIP (passo 4).
    for nome_derivado in "$ATU_DIR_TEMP" "$ATU_DIR_STAGING" "$ARQUIVO_ZIP_ATU" "$ATU_SUFFIXO_PARCIAL"; do
        if [[ ! "$nome_derivado" =~ ^[A-Za-z0-9._-]+$ ]]; then
            _erro "Nome invalido para limpeza da atualizacao: '${nome_derivado}'"
            return 1
        fi
    done

    # SEGURANCA: validar diretorios antes de qualquer remocao
    if ! _validar_diretorio_operacao "${CFG_PORTALSAV}"; then
        _erro "Diretorio de recepcao invalido ou inseguro para limpeza: ${CFG_PORTALSAV}"
        return 1
    fi
    if ! _validar_diretorio_operacao "${temp_dir}"; then
        _erro "Diretorio temporario invalido ou inseguro para limpeza: ${temp_dir}"
        return 1
    fi
    if ! _validar_diretorio_operacao "${staging}"; then
        _erro "Diretorio de staging invalido ou inseguro para limpeza: ${staging}"
        return 1
    fi

    # 1. ZIP na raiz de receber (modo online)
    if [[ -n "$arquivo_zip" && -f "${CFG_PORTALSAV}/${arquivo_zip}" ]] \
        && ! rm -f -- "${CFG_PORTALSAV}/${arquivo_zip}" 2>/dev/null; then
        _log "ERRO: nao foi possivel remover ${CFG_PORTALSAV}/${arquivo_zip}"
        rc=1
    fi

    # 2. ZIP do subdiretorio temporario (modo offline)
    if [[ -n "$arquivo_zip" && -f "${temp_dir}/${arquivo_zip}" ]] \
        && ! rm -f -- "${temp_dir}/${arquivo_zip}" 2>/dev/null; then
        _log "ERRO: nao foi possivel remover ${temp_dir}/${arquivo_zip}"
        rc=1
    fi

    # 3. Staging e subdiretorio temporario, por inteiro (so contem restos da
    #    extracao).
    #    A guarda contra "$dir == $CFG_PORTALSAV" e o que impede um ATU_DIR_*
    #    vazio/malformado de resolver para o proprio diretorio de recepcao e
    #   apologar tudo: e o mesmo risco de `mv -f x /` tratado em _atualizando.
    local dir_residual
    for dir_residual in "${staging%/}" "${temp_dir%/}"; do
        if [[ -z "$dir_residual" || "$dir_residual" == "/" || "$dir_residual" == "${CFG_PORTALSAV%/}" ]]; then
            _log "ERRO: recusando remover diretorio de recepcao: ${dir_residual}"
            rc=1
            continue
        fi
        if [[ -d "$dir_residual" ]] && ! rm -rf -- "$dir_residual" 2>/dev/null; then
            _log "ERRO: nao foi possivel remover ${dir_residual}"
            rc=1
        fi
    done

    # 4. Download interrompido: o "<zip>.part" de uma transmissao cortada fica
    #    no topo da recepcao. Antes era um "find -mindepth 1 -exec rm -rf {} +"
    #    que pegava esse residuo — junto com TUDO mais que estivesse ali.
    if [[ -n "$arquivo_zip" && -f "${CFG_PORTALSAV}/${arquivo_zip}${ATU_SUFFIXO_PARCIAL}" ]] \
        && ! rm -f -- "${CFG_PORTALSAV}/${arquivo_zip}${ATU_SUFFIXO_PARCIAL}" 2>/dev/null; then
        _log "ERRO: nao foi possivel remover ${CFG_PORTALSAV}/${arquivo_zip}${ATU_SUFFIXO_PARCIAL}"
        rc=1
    fi

    # O que sobrou NAO e removido: o topo da recepcao e compartilhado com
    # backups offline (_mover_backup_offline), ZIPs de biblioteca aguardando
    # processamento e o ZIP de reversao de programas (programas.sh). O "find
    # -exec rm -rf {} +" anterior apagava esses arquivos junto, sem aviso.
    # O residuo agora e registrado no log, nao destruido.
    local -a residuo=()
    while IFS= read -r -d '' item_residuo; do
        residuo+=("${item_residuo##*/}")
    done < <("${DEFAULT_FIND}" "${CFG_PORTALSAV}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    if ((${#residuo[@]} > 0)); then
        _log "AVISO: itens preservados em ${CFG_PORTALSAV} apos a atualizacao: ${residuo[*]}"
    fi

    if (( rc == 0 )); then
        _exibir_mensagem_centralizada "${VERDE}" "Diretorio limpo com sucesso."
    else
        _aviso "Alguns arquivos podem nao ter sido removidos."
    fi
    return "$rc"
}

# Seleciona um dos ZIPs de backup (*_backup.zip) e o expande em um diretorio
# temporario, para que os .sh.bkp possam ser restaurados.
# Parametros: $1=-diretorio de staging a criar e popular
# Retorna: 0=expandido  1=erro ou cancelamento
_expandir_backups_zip() {
    local staging="${1:-}"
    local _old_nullglob
    local zip_backup
    local -a zips_backup=()

    if [[ -z "$staging" ]]; then
        _erro "Diretorio de staging nao informado para a restauracao"
        return 1
    fi

    _old_nullglob=$(shopt -p nullglob) || _old_nullglob='shopt -u nullglob'
    shopt -s nullglob
    zips_backup=("${DEFAULT_BACKUP_DIR}"/*_backup.zip)
    if [[ "${_old_nullglob}" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi

    if (( ${#zips_backup[@]} == 0 )); then
        _erro "Nenhum backup anterior encontrado em ${DEFAULT_BACKUP_DIR}"
        return 1
    fi

    # Unico backup: restaura automaticamente; varios backups: lista e deixa selecionar
    zip_backup="${zips_backup[0]}"
    if (( ${#zips_backup[@]} > 1 )); then
        local indice_zip=1
        local zip_opcao
        local zip_escolha=""
        _linha
        _exibir_mensagem_centralizada "${CIANO}" "Backups disponiveis para restauracao:"
        _linha
        for zip_opcao in "${zips_backup[@]}"; do
            _exibir_mensagem_centralizada "${VERDE}" "${indice_zip}) ${zip_opcao##*/}"
            ((indice_zip++)) || true
        done
        _linha
        _exibir_mensagem_centralizada "${AMARELO}" "Informe o numero do backup desejado ou 0 para sair:"
        while true; do
            # EOF/Ctrl-D (read != 0) e tratado como cancelamento; sem o "|| ..." o
            # set -e derrubaria o sistema inteiro em vez de só o fluxo do menu.
            read -rp "${AMARELO}Opcao -> ${NORMAL}" zip_escolha || zip_escolha="0"
            _linha
            if [[ -z "$zip_escolha" || "$zip_escolha" == "0" ]]; then
                _aviso "Operacao cancelada"
                return 1
            fi
            if [[ "$zip_escolha" =~ ^[0-9]+$ ]] \
                && (( zip_escolha >= 1 && zip_escolha <= ${#zips_backup[@]} )); then
                zip_backup="${zips_backup[$((zip_escolha - 1))]}"
                break
            fi
            _erro "Opcao invalida. Informe um numero entre 1 e ${#zips_backup[@]}."
        done
    fi

    # Purga antes de criar: um run interrompido deixa o staging populado, e o unzip
    # sobrescreveria apenas os arquivos que colidem — um .sh.bkp antigo
    # remanescente seria restaurado como se fosse do backup escolhido.
    rm -rf -- "$staging" 2>/dev/null || true
    if ! _criar_diretorio_seguro "$staging" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _erro "Ao criar diretorio temporario de restauracao: ${staging}"
        return 1
    fi
    if ! "${DEFAULT_UNZIP}" -o -j "$zip_backup" -d "$staging" >>"$LOG_ATU" 2>&1; then
        _erro "Ao descompactar backup: ${zip_backup}"
        # Nao deixa o staging para tras: ele vive dentro de DEFAULT_BACKUP_DIR e
        # a proxima execucao o encontraria como lixo.
        rm -rf -- "$staging" 2>/dev/null || true
        return 1
    fi
    return 0
}

# Atualizacao online via GitHub
# Fluxo: valida diretorios -> backup -> localiza/valida/extrai o ZIP -> instala
#        configuracoes e scripts -> limpa a recepcao -> encerra o programa.
# Nao retorna no caminho de sucesso (_encerrar_programa 0). Nos caminhos de
# erro devolve 1 SEM apagar o pacote: em modo offline o ZIP e a unica copia
# que o usuario tem, e o `return 1` e lido por _executar_update.
_atualizando() {
    local _pwd_anterior="${PWD}"
    local arquivo_zip="${ARQUIVO_ZIP_ATU}"
    local temp_dir="${CFG_PORTALSAV%/}/${ATU_DIR_TEMP}"
    local staging="${CFG_PORTALSAV%/}/${ATU_DIR_STAGING}"
    local origem_zip=""
    local dir_operacao

    # Os nomes derivados de CFG_PORTALSAV so fazem sentido como NOME SIMPLES.
    # Com ATU_DIR_STAGING vazio, "$staging" resolve para "CFG_PORTALSAV/" e o
    # `rm -rf` da limpeza apagaria o diretorio de recepcao inteiro; com
    # ATU_SUFIXO_BACKUP vazio, o glob de restauracao casaria com qualquer
    # arquivo (inclusive os ZIPs) e tentaria restaura-los como scripts.
    local nome_derivado
    for nome_derivado in "$ATU_DIR_TEMP" "$ATU_DIR_STAGING" "$ARQUIVO_ZIP_ATU" "$ATU_SUFIXO_BACKUP"; do
        if [[ ! "$nome_derivado" =~ ^[A-Za-z0-9._-]+$ ]]; then
            _erro "Nome de arquivo/diretorio de atualizacao invalido: '${nome_derivado}'"
            return 1
        fi
    done

    # _configurar_diretorios cria CFG_DIR, DEFAULT_BACKUP_DIR e CFG_PORTALSAV.
    # Sem checar o retorno, um diretorio ausente ou sem permissao seria
    # alcancado pelos cp/mv adiante e a atualizacao seguiria sobre arquivos
    # que nunca foram salvos.
    if ! _configurar_diretorios; then
        _erro "Falha ao configurar os diretorios de trabalho" >&2
        return 1
    fi

    # SEGURANCA: validar TODOS os diretorios de escrita/remove antes de operar.
    # Inclui CFG_DIR (destino dos arquivos de configuracao) e CFG_PORTALSAV/
    # temp_dir (origem da extracao), que antes so eram validados na limpeza —
    # ou seja, depois de ja terem sido usados.
    for dir_operacao in "${LIBS_DIR}" "${CFG_DIR}" "${DEFAULT_BACKUP_DIR}" "${CFG_PORTALSAV}" "${temp_dir}" "${staging}"; do
        if ! _validar_diretorio_operacao "${dir_operacao}"; then
            _erro "Diretorio invalido ou inseguro: ${dir_operacao}"
            return 1
        fi
    done
    if [[ -n "${SCRIPT_DIR:-}" ]] && ! _validar_diretorio_operacao "${SCRIPT_DIR}"; then
        _erro "Diretorio do script principal invalido ou inseguro: ${SCRIPT_DIR}"
        return 1
    fi

    # ---------- 1. BACKUP DOS ARQUIVOS ATUAIS ----------
    # Enquanto _coletar_backups falha, a atualizacao para: sem backup nao ha
    # como reverter caso um modulo novo quebre o sistema.
    _coletar_backups || {
        _aguardar 2
        return 1
    }

    # =========================================================================
    # 2. LOCALIZAR E EXTRAIR O PACOTE
    # =========================================================================
    if [[ -f "${temp_dir}/${arquivo_zip}" ]]; then
        origem_zip="${temp_dir}/${arquivo_zip}"
    elif [[ -f "${CFG_PORTALSAV}/${arquivo_zip}" ]]; then
        origem_zip="${CFG_PORTALSAV}/${arquivo_zip}"
    else
        _erro "Arquivo ${arquivo_zip} nao encontrado para descompactacao."
        return 1
    fi

    # SEGURANCA: validar integridade do zip ANTES de extrair/instalar.
    # Um pacote corrompido extrairia arquivos parciais que seriam instalados
    # como se fossem validos nas etapas abaixo.
    if ! "${DEFAULT_UNZIP}" -t "$origem_zip" >>"$LOG_ATU" 2>&1; then
        _erro "Arquivo de atualizacao corrompido ou invalido: ${arquivo_zip}"
        return 1
    fi

# =========================================================================
    # 3. EXTRAIR EM STAGING E VALIDAR TUDO ANTES DE INSTALAR
    # =========================================================================
    # O staging e o que torna a instalacao segura: nada entra em
    # binarios/configuracoes antes de TODOS os scripts passarem em `bash -n`.
    # Sem ele, um modulo invalido so era descoberto DEPOIS de os anteriores
    # terem substituido os arquivos em uso, deixando o sistema meio atualizado.
    #
    # Purga antes de criar: um run interrompido (Ctrl-C, queda de energia) deixa
    # o staging com arquivos velhos, e o unzip sobrescreve so o que colide —
    # um modulo antigo remanescente passaria pela validacao e seria instalado.
    rm -rf -- "$staging" 2>/dev/null || true
    if ! _criar_diretorio_seguro "$staging" "${PERM_DIR_SECURE}" "${LOG_ATU}"; then
        _erro "Ao criar diretorio de staging da atualizacao: ${staging}"
        return 1
    fi
    if ! cd -- "$staging"; then
        _erro "Diretorio de staging nao acessivel: ${staging}"
        return 1
    fi

    if ! "${DEFAULT_UNZIP}" -o -j "$origem_zip" >>"$LOG_ATU" 2>&1; then
        _erro "Ao descompactar atualizacao"
        # Pacote preservado de proposito: e o que permite repetir a operacao.
        _log "Pacote mantido para nova tentativa: ${origem_zip}"
        _aviso "Pacote preservado em: ${origem_zip}"
        _voltar_dir_trabalho "${_pwd_anterior}"
        rm -rf -- "$staging" 2>/dev/null || true
        return 1
    fi

    #---------- VALIDACAO PREVIA DOS SCRIPTS ----------#
    # `unzip -t` valida o CRC do zip, nao a sintaxe. Um modulo truncado
    # quebraria todos os menus no proximo `source`.
    local _old_nullglob
    local scripts_invalidos=0
    local -a scripts_zip=()
    _old_nullglob=$(shopt -p nullglob) || _old_nullglob='shopt -u nullglob'
    shopt -s nullglob
    scripts_zip=(*.sh)
    if [[ "${_old_nullglob}" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi

    for arquivo in "${scripts_zip[@]}"; do
        [[ -f "$arquivo" ]] || continue
        # SEGURANCA: aceitar apenas nomes simples de script (sem caminho/traversal)
        if [[ ! "$arquivo" =~ ^[A-Za-z0-9._-]+\.sh$ ]]; then
            _log "AVISO: script com nome invalido ignorado: ${arquivo}" "${LOG_ATU}"
            continue
        fi
        if ! bash -n "$arquivo" 2>>"${LOG_ATU}"; then
            _erro "Script invalido (sintaxe bash): ${arquivo}"
            ((scripts_invalidos++)) || true
        fi
    done

    if (( scripts_invalidos > 0 )); then
        _erro "${scripts_invalidos} script(s) com sintaxe invalida - nada foi instalado"
        _aviso "O sistema continua com a versao anterior. Contate o suporte com o log ${LOG_ATU}"
        _voltar_dir_trabalho "${_pwd_anterior}"
        rm -rf -- "$staging" 2>/dev/null || true
        _aviso "Pacote preservado em: ${origem_zip}"
        return 1
    fi

    # =========================================================================
    # 4. INSTALAR
    # =========================================================================
    #---------- INSTALAR ARQUIVOS DE CONFIGURAÇÃO ----------#
    local arquivos_instalados=0
    local arquivos_erro=0
    local configuracoes_arquivo
    # 'lembrete' NAO entra aqui de proposito: e dado do usuario (lembrete.sh
    # apaga "todas as notas"), e sobrescreve-lo apagaria as notas. 'limpetmp2' e
    # 'indexar2' tambem ficam de fora: sao gerados em tempo de execucao
    # (arquivos.sh), nao distributions do sistema. O que o fluxo nao instala
    # nao e reportado: o pacote vem do repositorio inteiro (README, .gitignore,
    # docs) e listar o resto so polui a tela.
    local -a arquivos_configuracoes=("manual.txt" "avisos" "indexar" "limpetmp" "variosarquivos" "limpadir")
    for configuracoes_arquivo in "${arquivos_configuracoes[@]}"; do
        if [[ ! -f "$configuracoes_arquivo" ]]; then continue; fi
        # SEGURANCA: aceitar apenas nomes simples (sem caminho/traversal)
        if [[ ! "$configuracoes_arquivo" =~ ^[A-Za-z0-9._-]+$ ]]; then
            _log "AVISO: arquivo de configuracao com nome invalido ignorado: ${configuracoes_arquivo}" "${LOG_ATU}"
            continue
        fi
        # Dados de configuracao (listas de caminhos, texto), nao programas.
        # Antes era `chmod +x`, que alem de errado so nao fazia nada: o umask
        # 077 de principal.sh mascara os bits de `chmod +x`.
        chmod "${PERM_FILE_CONFIG}" "$configuracoes_arquivo" 2>/dev/null || true
        if mv -f "$configuracoes_arquivo" "${CFG_DIR}/"; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo $configuracoes_arquivo instalado em ${CFG_DIR}"
            ((arquivos_instalados++)) || true
        else
            _erro "Ao instalar ${configuracoes_arquivo}"
            ((arquivos_erro++)) || true
        fi
    done

    # .senhas tratado separadamente - permissao 0600 (privado)
    if [[ -f ".senhas" ]]; then
        chmod "${PERM_FILE_PRIVATE}" ".senhas" 2>/dev/null || true
        if mv -f ".senhas" "${CFG_DIR}/"; then
            _exibir_mensagem_centralizada "${VERDE}" "Arquivo .senhas instalado em ${CFG_DIR}"
            ((arquivos_instalados++)) || true
        else
            _erro "Ao instalar .senhas"
            ((arquivos_erro++)) || true
        fi
    fi

    #---------- INSTALAR ARQUIVOS .SH ----------#
    # Reaproveita a lista ja validada em `bash -n` acima: aqui so resta mover.
    local sh_destino
    for arquivo in "${scripts_zip[@]}"; do
        [[ -f "$arquivo" ]] || continue
        # SEGURANCA: aceitar apenas nomes simples de script (sem caminho/traversal)
        if [[ ! "$arquivo" =~ ^[A-Za-z0-9._-]+\.sh$ ]]; then
            _log "AVISO: script com nome invalido ignorado: ${arquivo}" "${LOG_ATU}"
            continue
        fi
        # Permissao explicita: `chmod +x` e mascarado pelo umask 077 de
        # principal.sh e deixaria atualiza.sh sem bit de execucao, quebrando
        # o proprio ./atualiza.sh apos a atualizacao.
        chmod "${PERM_FILE_EXEC}" "$arquivo" 2>/dev/null || true
        sh_destino="${LIBS_DIR}"
        if [[ "$arquivo" == "atualiza.sh" ]]; then
            # SCRIPT_DIR vazio faria sh_destino="" e o mv viraria
            # `mv -f atualiza.sh /` - sobrescrevendo o root.
            if [[ -n "${SCRIPT_DIR:-}" ]]; then
                sh_destino="${SCRIPT_DIR}"
            else
                _erro "SCRIPT_DIR vazio - atualiza.sh nao instalado (destino inseguro)"
                ((arquivos_erro++)) || true
                continue
            fi
        fi
        if mv -f "$arquivo" "${sh_destino}/"; then
            _exibir_mensagem_centralizada "${VERDE}" "Instalando programa $arquivo em $sh_destino"
            ((arquivos_instalados++)) || true
        else
            _erro "Ao instalar ${arquivo}"
            ((arquivos_erro++)) || true
        fi
    done

    if (( arquivos_erro > 0 )); then
        _erro "Falha na instalacao de ${arquivos_erro} arquivo(s)"
        _voltar_dir_trabalho "${_pwd_anterior}"
        rm -rf -- "$staging" 2>/dev/null || true
        _aviso "Pacote preservado em: ${origem_zip}"
        return 1
    elif (( arquivos_instalados == 0 )); then
        _aviso "Nenhum arquivo foi instalado - verifique os arquivos no ZIP"
        _voltar_dir_trabalho "${_pwd_anterior}"
        rm -rf -- "$staging" 2>/dev/null || true
        _aviso "Pacote preservado em: ${origem_zip}"
        return 1
    else
        _exibir_mensagem_centralizada "${VERDE}" "SUCESSO: ${arquivos_instalados} arquivo(s) instalado(s)"
    fi

    # =========================================================================
    # 5. LIMPEZA
    # =========================================================================
    _exibir_mensagem_centralizada "${CIANO}" "Realizando limpeza dos arquivos de atualizacao..."

    # A limpeza so acontece aqui: nos caminhos de erro o pacote e preservado.
    _limpar_recepcao_atualizacao || _aviso "Limpeza incompleta - verifique ${CFG_PORTALSAV}"

    # Restaurar o cwd antes de encerrar: _main/_limpeza_emergencia podem rodar
    # no encerramento e nao devem herdar o diretorio de extracao.
    _voltar_dir_trabalho "${_pwd_anterior}"

    _linha
    _ok "Atualizacao concluida com sucesso!"
    _exibir_mensagem_centralizada "${VERDE}" "Ao terminar, entre novamente no sistema"
    _linha
    _encerrar_programa 0
}

# Restaura os scripts .sh anteriores a partir do backup feito em _atualizando
# O backup pode estar em arquivos .sh.bkp avulsos ou em um zip ddmm_backup.zip
_voltar_sh_anterior() {
    if ! _configurar_diretorios; then
        _erro "Falha ao configurar os diretorios de trabalho" >&2
        return 1
    fi

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
    if [[ -n "${SCRIPT_DIR:-}" ]] && ! _validar_diretorio_operacao "${SCRIPT_DIR}"; then
        _erro "Diretorio do script principal invalido ou inseguro: ${SCRIPT_DIR}"
        _aguardar 2
        return 1
    fi

    # Com ATU_SUFIXO_BACKUP vazio o glob abaixo casaria com QUALQUER arquivo de
    # DEFAULT_BACKUP_DIR (inclusive os ZIPs) e tentaria restaura-los como
    # scripts; com ATU_DIR_RESTAURAR vazio, o `rm -rf` do staging apagaria o
    # diretorio de backup. Exigir nome simples fecha os dois.
    local nome_derivado
    for nome_derivado in "$ATU_SUFIXO_BACKUP" "$ATU_DIR_RESTAURAR"; do
        if [[ ! "$nome_derivado" =~ ^[A-Za-z0-9._-]+$ ]]; then
            _erro "Nome de backup invalido: '${nome_derivado}'"
            _aguardar 2
            return 1
        fi
    done

    # Localizar os backups .sh.bkp (avulsos ou dentro de um zip de backup)
    local dir_restauracao="${DEFAULT_BACKUP_DIR}"
    local staging="${DEFAULT_BACKUP_DIR}/${ATU_DIR_RESTAURAR}"
    local -a backups_sh=()
    local _old_nullglob
    _old_nullglob=$(shopt -p nullglob) || _old_nullglob='shopt -u nullglob'
    shopt -s nullglob
    backups_sh=("${DEFAULT_BACKUP_DIR}"/*"${ATU_SUFIXO_BACKUP}")
    if [[ "${_old_nullglob}" == *"-u"* ]]; then
        shopt -u nullglob
    else
        shopt -s nullglob
    fi

    if (( ${#backups_sh[@]} == 0 )); then
        # Sem .sh.bkp avulso: seleciona e expande um ZIP de backup. O staging
        # vive dentro de DEFAULT_BACKUP_DIR e precisa ser removido em TODOS os
        # retornos - senao a proxima execucao o encontra como lixo.
        _expandir_backups_zip "$staging" || {
            _aguardar 2
            return 1
        }
        dir_restauracao="$staging"

        shopt -s nullglob
        backups_sh=("${dir_restauracao}"/*"${ATU_SUFIXO_BACKUP}")
        if [[ "${_old_nullglob}" == *"-u"* ]]; then
            shopt -u nullglob
        else
            shopt -s nullglob
        fi
    fi

    if (( ${#backups_sh[@]} == 0 )); then
        _erro "Nenhum arquivo de backup ${ATU_SUFIXO_BACKUP} encontrado para restauracao"
        rm -rf -- "$staging" 2>/dev/null || true
        _aguardar 2
        return 1
    fi

    if ! _confirmar "Restaurar ${#backups_sh[@]} script(s) do backup anterior?" "N"; then
        _aviso "Restauracao cancelada"
        rm -rf -- "$staging" 2>/dev/null || true
        _aguardar_tecla
        return 0
    fi

    local restaurados=0 erros=0 arquivo_backup nome_script destino
    for arquivo_backup in "${backups_sh[@]}"; do
        nome_script="${arquivo_backup##*/}"
        [[ "$nome_script" == *"${ATU_SUFIXO_BACKUP}" ]] || continue
        nome_script="${nome_script%"${ATU_SUFIXO_BACKUP}"}"
        destino="${LIBS_DIR}"
        if [[ "$nome_script" == "atualiza.sh" ]]; then
            if [[ -n "${SCRIPT_DIR:-}" ]]; then
                destino="${SCRIPT_DIR}"
            else
                # Antes caia em LIBS_DIR sem aviso: atualiza.sh precisa ficar em
                # SCRIPT_DIR (e o entry point), nao junto dos modulos.
                _aviso "SCRIPT_DIR vazio - atualiza.sh restaurado em ${LIBS_DIR}"
            fi
        fi
        if cp -f "$arquivo_backup" "${destino}/${nome_script}" 2>/dev/null; then
            chmod "${PERM_FILE_EXEC}" "${destino}/${nome_script}" 2>/dev/null || true
            _exibir_mensagem_centralizada "${VERDE}" "Restaurado ${nome_script} em ${destino}"
            ((restaurados++)) || true
        else
            _erro "Ao restaurar ${nome_script}"
            ((erros++)) || true
        fi
    done

    # Limpeza do diretorio temporario de restauracao
    if [[ "${dir_restauracao}" != "${DEFAULT_BACKUP_DIR}" && -d "${dir_restauracao}" ]]; then
        rm -rf -- "${dir_restauracao}" 2>/dev/null || true
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
    local arquivo_zip="${ARQUIVO_ZIP_ATU}"
    local destino_zip="${CFG_PORTALSAV}/${arquivo_zip}"
    local destino_parcial="${destino_zip}${ATU_SUFFIXO_PARCIAL}"
    _exibir_mensagem_centralizada "${VERDE}" "Atualizando script via GitHub..."

    # SEGURANCA: permitir apenas URLs http(s) para download, sem espacos
    # (espaco quebraria a linha de comando do wget/curl)
    if [[ ! "${link}" =~ ^https?:// ]]; then
        _erro "URL de atualizacao invalida: ${link}"
        return 1
    fi
    if [[ "${link}" == *[[:space:]]* ]]; then
        _erro "URL de atualizacao invalida (contem espacos)"
        return 1
    fi

    # SEGURANCA: validar diretorio de download antes de usar wget/curl
    if ! _validar_diretorio_operacao "${CFG_PORTALSAV}"; then
        _erro "Diretorio de download invalido ou inseguro: ${CFG_PORTALSAV}"
        return 1
    fi

    _criar_diretorio_seguro "${CFG_PORTALSAV}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
        _erro "Ao criar diretorio de download"
        return 1
    }
    # wget e o padrao; curl e o fallback (servidores minimos podem nao ter wget).
    # Timeout/retry sao obrigatorios: sem eles, uma conexao pendurada segura o
    # menu indefinidamente — risco real em link legado.
    # O download vai para "<zip>.part" e so vira ZIP apos o exit 0: assim uma
    # transmissao truncada nunca aparece como atualiza.zip (o unzip -t daria
    # "corrompido", sem explicar que o problema foi a transferencia). Tambem
    # evita a combinacao '-c' + '-O' do wget 1.12 (Ubuntu 10.04), que comeca
    # o resume a partir do tamanho do arquivo local e corrompe o resultado.
    local -a cmd_download=()
    if command -v wget >/dev/null 2>&1; then
        cmd_download=(wget -q -c
            "--tries=${ATU_TENTATIVAS_DOWNLOAD}"
            "--timeout=${ATU_TIMEOUT_CONEXAO}"
            "$link" -O "$destino_parcial")
    elif command -v curl >/dev/null 2>&1; then
        cmd_download=(curl -fsSL
            "--retry=${ATU_TENTATIVAS_DOWNLOAD}"
            "--connect-timeout=${ATU_TIMEOUT_CONEXAO}"
            "--max-time=${ATU_TIMEOUT_DOWNLOAD}"
            -o "$destino_parcial" "$link")
    else
        _erro "Nem wget nem curl disponiveis para download"
        return 1
    fi
    if ! "${cmd_download[@]}"; then
        _log "ERRO: download falhou (${link})"
        _erro "Ao baixar arquivo de atualizacao. Verifique a conexao."
        rm -f -- "$destino_parcial" 2>/dev/null || true
        return 1
    fi

    # Vazio sem erro: nenhum dos dois aceitou a URL. Tratar como falha em vez
    # de seguir para o `unzip -t` com um ZIP de 0 bytes.
    if [[ ! -s "$destino_parcial" ]]; then
        _erro "Download concluido sem conteudo. Verifique a conexao."
        rm -f -- "$destino_parcial" 2>/dev/null || true
        return 1
    fi

    # Promocao atomica: o ZIP so passa a existir inteiro.
    if ! mv -f "$destino_parcial" "$destino_zip"; then
        _erro "Ao gravar o pacote baixado em ${destino_zip}"
        rm -f -- "$destino_parcial" 2>/dev/null || true
        return 1
    fi

    _atualizando
}

_atualizar_offline() {
    local temp_dir="${CFG_PORTALSAV%/}/${ATU_DIR_TEMP}"
    local arquivo_zip="${ARQUIVO_ZIP_ATU}"

    # SEGURANCA: validar diretorio temporario antes de operar
    if ! _validar_diretorio_operacao "${temp_dir}"; then
        _erro "Diretorio temporario invalido ou inseguro: ${temp_dir}"
        return 1
    fi
    if [[ ! -d "$temp_dir" ]]; then
        _erro "Diretorio temporario nao encontrado: ${temp_dir}"
        return 1
    fi
    if [[ ! -r "$temp_dir" ]]; then
        _erro "Sem permissao de leitura no diretorio temporario: ${temp_dir}"
        return 1
    fi

    # -s: arquivo vazio nao e um pacote, e o `unzip -t` rejeitaria com
    # "corrompido" sem indicar que o problema foi o transporte da copia.
    if [[ ! -s "${temp_dir}/${arquivo_zip}" ]]; then
        _erro "Arquivo ${arquivo_zip} nao encontrado ou vazio em ${temp_dir}"
        return 1
    fi
    _atualizando
}
