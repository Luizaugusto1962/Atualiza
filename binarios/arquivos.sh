#!/usr/bin/env bash
set -euo pipefail
#
# arquivos.sh - Modulo de Gestao de Arquivos
# Responsavel por limpeza, recuperacao, transferencia e expurgo de arquivos
# Padrões e regras de desenvolvimento: ver AGENTS.md
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 22/07/2026-01
#
# Variaveis globais esperadas
CFG_BASE_DIR="${CFG_BASE_DIR:-}"                # Caminho do diretorio da primeira base de dados.
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"              # Caminho do diretorio da segunda base de dados.
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"              # Caminho do diretorio da terceira base de dados.
DEFAULT_ZIP="${DEFAULT_ZIP:-}"                  # Comando de compactacao (ex: zip)
DEFAULT_UNZIP="${DEFAULT_UNZIP:-}"              # Comando de descompactacao (ex: unzip)
#---------- FUNCOES DE LIMPEZA -----------------#

# Resolve a base de trabalho ativa para operacoes de arquivos
_selecionar_base_arquivos() {

    if [[ -n "${CFG_BASE_DIR2}" ]]; then
        if ! _menu_escolha_base; then
            # Usuario escolheu voltar (opcao 9) — retorna 1 para o chamador voltar ao menu
            return 1
        fi
    else
        base_trabalho="${RAIZ}${CFG_BASE_DIR}"
    fi

    # Validar antes de prosseguir
    if [[ -z "${base_trabalho}" ]]; then
        _erro "Diretorio de trabalho nao foi definido"
        _aguardar_tecla
        return 1
    fi

    if [[ ! -d "${base_trabalho}" ]]; then
        _erro "Diretorio ${base_trabalho} nao encontrado"
        _aguardar_tecla
        return 1
    fi

    if [[ ! -r "${base_trabalho}" ]]; then
        _erro "Sem permissao de leitura em ${base_trabalho}"
        _aguardar_tecla
        return 1
    fi

    export base_trabalho
    return 0
}

# Executa limpeza de arquivos temporarios
_executar_limpeza_temporarios() {

#    # Excluir arquivos de lista antigos para evitar confusao
#    for lista in "atualizal" "atualizaj" "atualizaj2" "atualizat" "atualizat2" ".atualizac" ".atualizac.bkp" ".atualizac.bak"; do
#        local caminho_lista="${CFG_DIR}/${lista}"
#        if [[ -f "${caminho_lista}" ]]; then
#            if rm -f "${caminho_lista}"; then
#                _log "Lista temporaria removida: ${lista}"
#            else
#                _log "AVISO: Falha ao remover lista temporaria: ${lista}"
#            fi
#        fi
#    done

    # Verificar arquivo de lista de temporarios
    local arquivo_lista="${CFG_DIR}/limpetmp"
    if [[ ! -f "${arquivo_lista}" ]]; then
        _erro "Arquivo ${arquivo_lista} nao existe no diretorio"
        _aguardar 2
        return 1
    elif [[ ! -r "${arquivo_lista}" ]]; then
        _erro "Arquivo ${arquivo_lista} sem permissao de leitura"
        _aguardar 2
        return 1
    fi

    local arquivo_lista2="${CFG_DIR}/limpetmp2"

    # Limpar temporarios antigos do backup
    find "${DEFAULT_BACKUP_DIR}" -type f -name "Temps*" -mtime +10 -delete 2>/dev/null || true

    # Processar cada base de dados configurada
    local caminho_base
    local base_dir
    for base_dir in "$CFG_BASE_DIR" "$CFG_BASE_DIR2" "$CFG_BASE_DIR3"; do
        if [[ -n "$base_dir" ]]; then
            caminho_base="${RAIZ}${base_dir}"
            if [[ -d "$caminho_base" ]]; then
                _limpar_base_especifica "$caminho_base" "$arquivo_lista"
                # Processar limpetmp2 na sequencia, se existir
                if [[ -f "${arquivo_lista2}" && -r "${arquivo_lista2}" ]]; then
                    _limpar_base_especifica "$caminho_base" "$arquivo_lista2"
                fi
            else
                _aviso "Diretorio nao existe: ${caminho_base}"
                _aguardar 2
            fi
        fi
    done
    _aguardar_tecla
}

# Limpa arquivos da base especifica
_limpar_base_especifica() {
    local caminho_base="$1"
    local arquivo_lista="$2"
    local arquivos_temp=()

    # Validar parâmetros
    if [[ -z "$caminho_base" || -z "$arquivo_lista" ]]; then
        _erro "Parametros invalidos"
        return 1
    fi

    if [[ ! -d "$caminho_base" ]]; then
        _erro "Diretorio nao existe: $caminho_base"
        return 1
    fi

    if [[ ! -f "$arquivo_lista" ]]; then
        _erro "Arquivo de lista nao existe"
        return 1
    fi

    # Ler lista de arquivos temporarios
    mapfile -t arquivos_temp < "$arquivo_lista"

    _aviso "Limpando arquivos temporarios do diretorio: ${caminho_base}"
    _aguardar 1
    _linha

    local zip_temporarios
    zip_temporarios="Temps-${UMADATA}.zip"

    local qtd_padrao
    local arquivos_zip=()

    for padrao_arquivo in "${arquivos_temp[@]}"; do
        [[ -n "$padrao_arquivo" ]] || continue

        # Coletar arquivos de uma unica vez — mesma lista usada no zip e no rm
        mapfile -t arquivos_zip < <(find "$caminho_base" -type f -iname "$padrao_arquivo" -mtime +0)
        qtd_padrao="${#arquivos_zip[@]}"

        # Nenhum arquivo encontrado para este padrao — pular
        if [[ "$qtd_padrao" -eq 0 ]]; then
            continue
        fi

        _mensagec "${VERDE}" "Processando padrao: ${AMARELO}${padrao_arquivo}${NORMAL} (${qtd_padrao} arquivo(s))"
        _aguardar 1

        # Compactar — $DEFAULT_ZIP sem aspas para suportar flags (ex: "zip -j")
        if $DEFAULT_ZIP "${DEFAULT_BACKUP_DIR}/${zip_temporarios}" "${arquivos_zip[@]}" >>"${LOG_LIMPA}" 2>&1; then
            _log "Arquivos temporarios compactados: $padrao_arquivo (${qtd_padrao} arquivo(s))" "${LOG_LIMPA}"
            # Remover usando o mesmo array ja coletado.
            if printf '%s\0' "${arquivos_zip[@]}" | xargs -0 rm -f; then
                _log "Arquivos removidos: $padrao_arquivo (${qtd_padrao} arquivo(s))" "${LOG_LIMPA}"
            else
                _log "AVISO: falha ao remover arquivos do padrao: $padrao_arquivo" "${LOG_LIMPA}"
            fi
         else
            _log "ERRO ao compactar arquivos do padrao: $padrao_arquivo" "${LOG_LIMPA}"
            _erro "  >> Ao compactar padrao: ${padrao_arquivo}"
            _aguardar 1
        fi
    done
    _linha
    _ok "Limpeza concluida"
    _linha

    return 0
}

# Adiciona arquivo à lista de limpeza
_adicionar_arquivo_lixo() {

    _limpa_tela
    _meio_da_tela
    _mensagec "${CIANO}" "Informe o nome do arquivo a ser adicionado ao limpetmp2"
    _linha

    local novo_arquivo
    read -rp "${AMARELO}Qual o arquivo -> ${NORMAL}" novo_arquivo
    _linha

    if [[ -z "$novo_arquivo" ]]; then
        _mensagec "${VERMELHO}" "Nome de arquivo nao informado"
        _aguardar_tecla
        return 1
    fi

    if [[ ! "$novo_arquivo" =~ ^[A-Za-z0-9._*-]+$ ]]; then
        _erro "Nome de arquivo invalido. Use apenas letras, numeros, pontos, hifens ou '*'."
        _aguardar_tecla
        return 1
    fi

# Bloquear wildcards globais se não for intenção
    if [[ "$novo_arquivo" == *"*"* || "$novo_arquivo" == *"?"* ]]; then
        _mensagec "${VERMELHO}" "Wildcards '*' ou '?' nao sao permitidos aqui por seguranca."
        _aguardar_tecla
        return 1
    fi

    # Adicionar arquivo à lista
    echo "$novo_arquivo" >> "${CFG_DIR}/limpetmp2"
    _mensagec "${CIANO}" "Arquivo '${novo_arquivo}' adicionado com sucesso ao 'limpetmp2'"
    _linha
    _aguardar_tecla
}

# Lista os arquivos no limpetmp e limpetmp2
_lista_arquivos_lixo() {

    _limpa_tela
    _meio_da_tela
    _mensagec "${CIANO}" "Lista de arquivos no limpetmp:"
    _linha

    if [[ -f "${CFG_DIR}/limpetmp" && -s "${CFG_DIR}/limpetmp" ]]; then
        nl -w3 -s'. ' "${CFG_DIR}/limpetmp"
    else
        _aviso "Nenhum arquivo listado no 'limpetmp'"
    fi

    _linha
    _mensagec "${CIANO}" "Lista de arquivos no limpetmp2:"
    _linha

    if [[ -f "${CFG_DIR}/limpetmp2" && -s "${CFG_DIR}/limpetmp2" ]]; then
        nl -w3 -s'. ' "${CFG_DIR}/limpetmp2"
    else
        _aviso "Nenhum arquivo listado no 'limpetmp2'"
    fi

    _linha
    _aguardar_tecla
}

#---------- FUNCOES DE RECUPERACAO ----------#
# Recupera arquivo especifico ou todos
_recuperar_arquivo_especifico() {
    local continuar="S"

    if ! _selecionar_base_arquivos; then
        return 0
    fi

    _limpa_tela

    # Loop para permitir múltiplas recuperações
    while [[ "${continuar}" =~ ^[Ss]$ ]]; do
        _meio_da_tela
        _mensagec "${CIANO}" "Informe o nome do arquivo a ser recuperado ou ENTER para todos:"
        _linha

        local nome_arquivo
        read -rp "${AMARELO}Nome do arquivo: ${NORMAL}" nome_arquivo
        nome_arquivo="${nome_arquivo#"${nome_arquivo%%[![:space:]]*}"}" # trim left
        nome_arquivo="${nome_arquivo%"${nome_arquivo##*[![:space:]]}"}" # trim right

        _linha "-" "${AZUL}"

        if [[ -z "$nome_arquivo" ]]; then
            # Pergunta confirmação antes de recuperar todos
            _aviso "Deseja recuperar TODOS os arquivos principais?"
            read -rp "${AMARELO}[S/N]: ${NORMAL}" confirmar_todos
            confirmar_todos=$(_trim "$confirmar_todos")
            confirmar_todos=$(_upper "$confirmar_todos")

            if [[ "$confirmar_todos" =~ ^[Ss]$ ]]; then
                # Recupera todos → executa e sai do loop
                _recuperar_todos_arquivos "$base_trabalho"
                _aviso "Todos os arquivos principais foram recuperados."
                break
            else
                _mensagec "${CIANO}" "Operacao cancelada."
                _linha
                _aguardar 2
                return 0
            fi
        else
            # Recupera arquivo específico
            _recuperar_arquivo_individual "$nome_arquivo" "$base_trabalho"
            _aviso "Arquivo(s) recuperado(s)..."
        fi
        _linha

        # Só pergunta se quer continuar se foi um arquivo específico
        _mensagec "${CIANO}" "Deseja recuperar mais arquivos?"
        read -rp "${AMARELO}[S/N]: ${NORMAL}" continuar
        continuar="${continuar#"${continuar%%[![:space:]]*}"}"
        continuar="${continuar%"${continuar##*[![:space:]]}"}"
        continuar="${continuar^^}"

        # Se vazio, assumir "N"
        [[ -z "$continuar" ]] && continuar="N"

    _limpa_tela
    done
    _ir_para_tools
}

# Recupera todos os arquivos principais
_recuperar_todos_arquivos() {
    local base_trabalho="$1"
    local -a extensoes=("${DATA_EXTENSIONS[@]:-*.dat}")
    _mensagec "${VERMELHO}" "Recuperando todos os arquivos principais..."
    _linha "-" "${AMARELO}"

    if [[ -d "$base_trabalho" ]]; then
        shopt -s nullglob
        for extensao in "${extensoes[@]}"; do
            for arquivo in ${base_trabalho}/${extensao}; do
                if [[ -L "$arquivo" ]]; then
                    _aviso "Arquivo linkado, pulando: ${arquivo##*/}"
                    _linha "-" "${VERDE}"
                elif [[ -f "$arquivo" && -s "$arquivo" ]]; then
                    _executar_jutil "$arquivo"
                else
                    _aviso "Arquivo nao encontrado ou vazio: ${arquivo##*/}"
                    _linha "-" "${VERDE}"
                fi
            done
        done
        shopt -u nullglob
    else
        _erro "Diretorio ${base_trabalho} nao existe"
        return 1
    fi
    return 0
}

# Recupera arquivo individual
_recuperar_arquivo_individual() {
    local nome_arquivo="$1"
    local base_trabalho="$2"

    # Validar nome do arquivo
    # Converter para maiusculo e remover espacos
    nome_arquivo="${nome_arquivo^^}"
    nome_arquivo="${nome_arquivo//[[:space:]]/}"

    if [[ -z "$nome_arquivo" ]]; then
        _mensagec "${VERMELHO}" "Nome de arquivo vazio apos normalizacao."
        return 1
    fi

    if [[ ! "$nome_arquivo" =~ ^[A-Z0-9._-]+$ ]]; then
        _mensagec "${VERMELHO}" "Nome de arquivo invalido. Use apenas letras, numeros, pontos e hifens."
        return 1
    fi

    local padrao_arquivo="${nome_arquivo}.*.dat"
    local arquivos_encontrados=0
    local arquivo

    shopt -s nullglob
    for arquivo in ${base_trabalho}/${padrao_arquivo}; do
        if [[ -L "$arquivo" ]]; then
            _aviso "Arquivo linkado, pulando: ${arquivo##*/}"
            _linha "-" "${VERDE}"
        elif [[ -f "$arquivo" ]]; then
            _executar_jutil "$arquivo"
            ((arquivos_encontrados++)) || true
        fi
    done
    shopt -u nullglob

    if (( arquivos_encontrados == 0 )); then
        _aviso "Nenhum arquivo encontrado para: ${nome_arquivo}"
        _linha "-" "${VERDE}"
    fi
}

# Executa recuperacao dos arquivos listados no variosarquivos
_executar_lista_arquivos() {
    local arquivo_lista="${CFG_DIR}/variosarquivos"

    if [[ ! -f "$arquivo_lista" ]]; then
        _mensagec "${VERMELHO}" "A lista de arquivo, variosarquivos nao foi encontrado em ${CFG_DIR}"
        _aguardar_tecla
        return 1
    fi

    if ! _selecionar_base_arquivos; then
        return 0
    fi

    _limpa_tela
    _linha
    _mensagec "${CIANO}" "Recuperando arquivos da lista 'variosarquivos'..."
    _linha

    local total=0

    while IFS= read -r linha || [[ -n "$linha" ]]; do
        linha="${linha#"${linha%%[![:space:]]*}"}"
        linha="${linha%"${linha##*[![:space:]]}"}"
        [[ -z "$linha" ]] && continue

        local nome_base="${linha%%.*}"
        nome_base="${nome_base^^}"
        nome_base="${nome_base//[[:space:]]/}"

        _recuperar_arquivo_individual "$nome_base" "$base_trabalho"
        ((total++)) || true
    done < "$arquivo_lista"

    _linha
    _mensagec "${VERDE}" "${total} arquivo(s) processados da lista."
    _aguardar_tecla
}

# Edita a lista de arquivos (variosarquivos): visualiza, adiciona, altera ou remove linhas
_editar_lista_arquivos() {
    local arquivo_lista="${CFG_DIR}/variosarquivos"

    if [[ ! -f "$arquivo_lista" ]]; then
        _erro "Arquivo ${arquivo_lista} nao encontrado"
        _aguardar_tecla
        return 1
    fi

    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Editar Lista de Arquivos (variosarquivos)"
        _exibir_titulo_secao " Conteudo atual:"
        _linha

        local linhas=()
        mapfile -t linhas < "$arquivo_lista"

        if [[ ${#linhas[@]} -eq 0 ]]; then
            _aviso "Lista vazia"
        else
            local idx=1
            for linha in "${linhas[@]}"; do
                [[ -n "$linha" ]] || continue
                printf '%b' "${VERDE}${idx}${NORMAL} - ${linha}\n"
                ((idx++))
            done
        fi

        _linha
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Adicionar nova entrada"
        _exibir_opcao_menu "2" "Alterar uma entrada"
        _exibir_opcao_menu "3" "Remover uma entrada"
        _exibir_opcao_menu "4" "Zerar lista (remover todas as entradas)"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "variosarquivos"; then
            continue
        fi

        case "${opcao}" in
            1)
                read -rp "${AMARELO}Nome do arquivo a adicionar: ${NORMAL}" novo
                novo=$(_trim "$novo")
                if [[ -n "$novo" ]]; then
                    echo "$novo" >> "$arquivo_lista"
                    _ok "'${novo}' adicionado a lista"
                else
                    _aviso "Nenhum nome informado"
                fi
                _aguardar 1
                ;;
            2)
                read -rp "${AMARELO}Numero da linha a alterar: ${NORMAL}" num
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#linhas[@]} )); then
                    read -rp "${AMARELO}Novo valor: ${NORMAL}" novo
                    novo=$(_trim "$novo")
                    if [[ -n "$novo" ]]; then
                        local tmp_lista=()
                        for i in "${!linhas[@]}"; do
                            if (( i + 1 == num )); then
                                tmp_lista+=("$novo")
                            else
                                tmp_lista+=("${linhas[$i]}")
                            fi
                        done
                        printf '%s\n' "${tmp_lista[@]}" > "$arquivo_lista"
                        _ok "Linha ${num} alterada"
                    else
                        _aviso "Valor vazio, operacao cancelada"
                    fi
                else
                    _aviso "Numero invalido"
                fi
                _aguardar 1
                ;;
            3)
                read -rp "${AMARELO}Numero da linha a remover: ${NORMAL}" num
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#linhas[@]} )); then
                    local tmp_lista=()
                    for i in "${!linhas[@]}"; do
                        if (( i + 1 != num )); then
                            tmp_lista+=("${linhas[$i]}")
                        fi
                    done
                    printf '%s\n' "${tmp_lista[@]}" > "$arquivo_lista"
                    _ok "Linha ${num} removida"
                else
                    _aviso "Numero invalido"
                fi
                _aguardar 1
                ;;
            4)
                _aviso "Tem certeza que deseja ZERAR toda a lista?"
                read -rp "${AMARELO}Confirma [S/N]: ${NORMAL}" conf
                conf=$(_trim "$conf")
                conf="${conf^^}"
                if [[ "$conf" == "S" ]]; then
                    rm -f "$arquivo_lista" && touch "$arquivo_lista"
                    _ok "Lista zerada com sucesso"
                else
                    _aviso "Operacao cancelada"
                fi
                _aguardar 1
                ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

# Recupera arquivos principais baseado na lista
_recuperar_arquivos_principais() {
    cd "${CFG_DIR}" || return 1

    if ! _selecionar_base_arquivos; then
        return 1
    fi

    # Usar valor padrão se base_trabalho estiver vazia
    base_trabalho="${base_trabalho:-${RAIZ}${CFG_BASE_DIR}}"
    cd "$base_trabalho" || {
        _erro "Diretorio ${base_trabalho} nao encontrado"
        return 1
    }

    # Gerar lista de arquivos atuais
    local var_ano var_ano4 lista
    var_ano=$(date +%y)
    var_ano4=$(date +%Y)

    # Criar lista temporaria
    {
        ls ATE"${var_ano}"*.dat 2>/dev/null || true
        ls NFE?"${var_ano4}".*.dat 2>/dev/null || true
    } > "${CFG_DIR}/indexar2"

    cd "${CFG_DIR}" || return 1
    _aguardar 1

    # Verificar arquivos de lista
    for lista in "indexar2" "indexar"; do
        if [[ -f "$lista" && -r "$lista" ]]; then
            _processar_lista_arquivos "$lista" "$base_trabalho"
        fi
    done

        # Limpar arquivo temporario
        [[ -f "indexar2" ]] && rm -f "indexar2"

        _mensagec "${AMARELO}" "Arquivos principais recuperados"

    _aguardar_tecla
}

# Processa lista de arquivos para recuperacao
_processar_lista_arquivos() {
    local arquivo_lista="$1"
    local base_trabalho="$2"
    local caminho_arquivo
    while IFS= read -r listando || [[ -n "$listando" ]]; do
        [[ -z "$listando" ]] && continue
        caminho_arquivo="${base_trabalho}/${listando}"
        if [[ -L "$caminho_arquivo" ]]; then
            _aviso "Arquivo linkado, pulando: ${listando}"
        else
            _executar_jutil "$caminho_arquivo"
        fi
    done < "$arquivo_lista"
}

# Executa jutil no arquivo especificado
_executar_jutil() {
    local arquivo="$1"
    if [[ -L "$arquivo" ]]; then
        _aviso "Arquivo linkado, pulando recuperacao: $(basename "$arquivo")"
        return 0
    fi
	if [[ -z "${REBUILD:-}" ]]; then
        _erro "Variavel REBUILD nao configurada. Verifique o caminho do jutil em constantes.sh"
        return 1
    fi

    local dir_arquivo base_arquivo arquivo_idx
	if [[ -x "${REBUILD}" ]]; then
        if [[ -n "$arquivo" && -e "$arquivo" && -s "$arquivo" ]]; then
            if "${REBUILD}" -rebuild "$arquivo" -a -f; then
                _log_sucesso "Rebuild executado: $(basename "$arquivo")"
                # garantir permissões máximas após o rebuild
                chmod "${PERM_FILE_EXEC}" "$arquivo" 2>/dev/null || \
                _mensagec "${AMARELO}" "Aviso: nao foi possivel alterar permissoes de $arquivo"
                # garantir permissões máximas nos arquivos .idx gerados pelo jutil

                dir_arquivo="$(dirname "$arquivo")"
                base_arquivo="$(basename "$arquivo" .dat)"
                for arquivo_idx in "${dir_arquivo}/${base_arquivo}"*.idx; do
                    if [[ -f "$arquivo_idx" ]]; then
                        chmod "${PERM_FILE_EXEC}" "$arquivo_idx" 2>/dev/null || \
                        _mensagec "${AMARELO}" "Aviso: nao foi possivel alterar permissoes de $arquivo_idx"
                    fi
                done
            else
                _erro "no rebuild: $(basename "$arquivo")"
            fi
            _linha "-" "${VERDE}"
        else
            _mensagec "${AMARELO}" "Arquivo nao encontrado ou vazio: $(basename "$arquivo" 2>/dev/null || echo "$arquivo")"
        fi
    else
        _erro "jutil nao encontrado em ${REBUILD}"
        return 1
    fi
}

#---------- FUNCOES DE TRANSFERENCIA ----------#

# Envia arquivo avulso
_enviar_arquivo_avulso() {
    _limpa_tela
    local diretorio_origem arquivo_enviar destino_remoto arquivos

    # Solicitar diretorio de origem
    _linha
    _mensagec "${AMARELO}" "1- Origem: Informe o diretorio onde esta o arquivo:"
    read -rp "${AMARELO} -> ${NORMAL}" diretorio_origem
    _linha

    if [[ -z "$diretorio_origem" ]]; then
        diretorio_origem="${DEFAULT_ENVIA_DIR:-}"
        if [[ -z "$diretorio_origem" || ! -d "$diretorio_origem" ]]; then
            _mensagec "${VERMELHO}" "Diretorio de origem nao informado ou padrao nao definido"
            _aguardar_tecla
            return 1
        fi
        _linha
        _mensagec "${AMARELO}" "Usando diretorio padrao: ${diretorio_origem}"
        # Verificar se há arquivos no diretório
        shopt -s nullglob
        arquivos=("${diretorio_origem}"/*)
        shopt -u nullglob
        if (( ${#arquivos[@]} == 0 )); then
            _mensagec "${AMARELO}" "Nenhum arquivo encontrado no diretorio"
            _aguardar_tecla
            return 1
        fi
    elif [[ ! -d "$diretorio_origem" ]]; then
        _erro "Diretorio nao encontrado: ${diretorio_origem}"
        _aguardar_tecla
        return 1
    fi

    # Solicitar nome do arquivo
    _linha
    _mensagec "${CIANO}" "Informe o arquivo que deseja enviar"
    _mensagec "${CIANO}" "Use * para enviar todas as extensoes (ex: ARQUIVO*)"
    _linha
    read -rp "${AMARELO}2- Nome do ARQUIVO: ${NORMAL}" arquivo_enviar

    if [[ -z "$arquivo_enviar" ]]; then
        _mensagec "${VERMELHO}" "Nome do arquivo nao informado"
        _aguardar_tecla
        return 1
    fi

    # Verificar se o arquivo contém wildcard (*)
    if [[ "$arquivo_enviar" == *"*"* ]]; then
        # Listar arquivos que correspondem ao padrão
        shopt -s nullglob
        local arquivos_encontrados=()
        while IFS= read -r -d '' arquivo; do
            arquivos_encontrados+=("$arquivo")
        done < <(find "${diretorio_origem}" -maxdepth 1 -type f -name "${arquivo_enviar}" -print0)
        shopt -u nullglob

        if (( ${#arquivos_encontrados[@]} == 0 )); then
            _mensagec "${AMARELO}" "Nenhum arquivo encontrado com o padrao: ${arquivo_enviar}"
            _aguardar_tecla
            return 1
        fi

        # Mostrar arquivos encontrados
        _linha
        _mensagec "${CIANO}" "Arquivos encontrados (${#arquivos_encontrados[@]}):"
        for arquivo in "${arquivos_encontrados[@]}"; do
            _mensagec "${VERDE}" "  - $(basename "$arquivo")"
        done
        _linha

        # Confirmar envio
        local confirmacao
        read -rp "${AMARELO}Deseja enviar todos esses arquivos? [S/N]: ${NORMAL}" confirmacao
        confirmacao="${confirmacao^^}"

        if [[ "$confirmacao" != "S" ]]; then
            _mensagec "${AMARELO}" "Envio cancelado pelo usuario"
            _aguardar_tecla
            return 0
        fi
    else
        # Verificação para arquivo único (sem wildcard)
        if [[ ! -e "${diretorio_origem}/${arquivo_enviar}" ]]; then
            _mensagec "${AMARELO}" "${arquivo_enviar} nao encontrado em ${diretorio_origem}"
            _aguardar_tecla
            return 1
        fi
    fi

    # Solicitar destino remoto
    printf "\n"
    _linha
    _mensagec "${AMARELO}" "3- Destino: Informe o diretorio no servidor:"
    read -rp "${AMARELO} -> ${NORMAL}" destino_remoto
    _linha

    if [[ -z "$destino_remoto" ]]; then
        _erro "Destino nao informado"
        _aguardar_tecla
        return 1
    fi

    # Enviar arquivo(s)
    _linha
    _mensagec "${AMARELO}" "Informe a senha para o usuario remoto:"
    _linha
    _enviar_arquivo_multi
 }

# Recebe arquivo avulso
_receber_arquivo_avulso() {
    _limpa_tela
    local origem_remota arquivo_receber destino_local

    # Solicitar origem remota
    _linha
    _mensagec "${AMARELO}" "1- Origem: Diretorio remoto do arquivo:"
    read -rp "${AMARELO} -> ${NORMAL}" origem_remota
    _linha

    # Solicitar nome do arquivo
    _mensagec "${VERMELHO}" "Informe o arquivo que deseja RECEBER"
    _linha
    read -rp "${AMARELO}2- Nome do ARQUIVO: ${NORMAL}" arquivo_receber

    if [[ -z "$arquivo_receber" ]]; then
        _mensagec "${VERMELHO}" "Nome do arquivo nao informado"
        _aguardar_tecla
        return 1
    fi

    # Solicitar destino local
    _linha
    _mensagec "${AMARELO}" "3- Destino: Diretorio local para receber:"
    read -rp "${AMARELO} -> ${NORMAL}" destino_local

    if [[ -z "$destino_local" ]]; then
        destino_local="${DEFAULT_RECEBE_DIR:-}"
    fi

    if [[ ! -d "$destino_local" ]]; then
        _mensagec "${VERMELHO}" "Diretorio de destino nao encontrado: ${destino_local}"
        _aguardar_tecla
        return 1
    fi

    # Receber arquivo
    _linha
    _mensagec "${AMARELO}" "Informe a senha para o usuario remoto:"
    _linha
    if _receber_scp "${origem_remota}/${arquivo_receber}" "${destino_local}/"; then
        _mensagec "${VERDE}" "Arquivo recebido com sucesso em \"${destino_local}\""
        _linha
        _aguardar 3
    else
        _erro "no recebimento do arquivo"
        _aguardar_tecla
    fi
}

#---------- FUNCOES DE EXPURGO ----------#
# Executa expurgador de arquivos antigos
_executar_expurgador() {
    _executar_expurgador_diario

    _limpa_tela

    _linha
    _mensagec "${VERMELHO}" "Verificando e excluindo arquivos com mais de 30 dias"
    _linha
    printf "\n"

    # Definir diretorios para limpeza
    local diretorios_limpeza=(
        "${DEFAULT_BACKUP_DIR}/"
        "${DEFAULT_BIBLIOTECA_DIR}/"
        "${DEFAULT_BIBLIOTECA_ATUAL_DIR}/"
        "${DEFAULT_PROGS_DIR}/"
        "${DEFAULT_ENVIA_DIR}/"
        "${DEFAULT_RECEBE_DIR}/"
        "${DEFAULT_BASEBACKUP_DIR}/"
        "${DEFAULT_OLDS_DIR}/"
        "${DEFAULT_LOGS_DIR}/"
        "${RAIZ}/portalsav/log/"
        "${RAIZ}/err_isc/"
        "${RAIZ}/savisc/viewvix/tmp/"
    )


    # Limpar arquivos antigos nos diretorios padrao
    local diretorios_zip
    for diretorio in "${diretorios_limpeza[@]}"; do
        if [[ -d "$diretorio" && "$diretorio" != "/" && "$diretorio" != "//" ]]; then
            local arquivos_removidos
            arquivos_removidos=$(find "$diretorio" -mtime +30 -type f -print -delete 2>/dev/null | wc -l)
            _mensagec "${VERDE}" "Limpando arquivos do diretorio: ${diretorio} (${arquivos_removidos} arquivos)"
        else
            _mensagec "${AMARELO}" "Diretorio nao encontrado: ${diretorio}"
        fi
    done

        diretorios_zip=(
        "${E_EXEC}/"
        "${T_TELAS}/"
    )

    # Limpar arquivos ZIP antigos especificos
    local diretorio zips_removidos
    for diretorio in "${diretorios_zip[@]}"; do
        if [[ -d "$diretorio" && "$diretorio" != "/" && "$diretorio" != "//" ]]; then
            zips_removidos=$(find "$diretorio" -name "*.zip" -type f -mtime +15 -print -delete 2>/dev/null | wc -l)
            _mensagec "${VERDE}" "Limpando arquivos .zip antigos: ${diretorio} (${zips_removidos} arquivos)"
        else
            _mensagec "${AMARELO}" "Diretorio nao encontrado: ${diretorio}"
        fi
    done

    printf "\n"
    _linha
    _aguardar_tecla
    _ir_para_tools
    return 0
}

# Lista os logs de atualizacao
_listar_logs_atualizacao() {
    local logs=()
    _limpa_tela
    _linha
    _mensagec "${AMARELO}" "Logs de Atualizacao encontrados em ${DEFAULT_LOGS_DIR}:"
    _linha

    logs=("${DEFAULT_LOGS_DIR}"/atualiza.*)
    if [[ ! -e "${logs[0]}" ]]; then
        _erro "Nenhum log de atualizacao encontrado."
        _aguardar_tecla
        return 1
    fi

    # Exibir lista numerada dos logs disponiveis
    local i=1
    local log
    for log in "${logs[@]}"; do
        _mensagec "${CIANO}" "  ${i}) $(basename "$log")"
        (( i++ ))
    done
    _linha
    _mensagec "${VERDE}" "  0) Visualizar todos"
    _linha

    local opcao log_selecionado
    read -rp "${AMARELO}Selecione o arquivo [0-$((i-1))]: ${NORMAL}" opcao

    # Validar entrada
    if [[ -z "$opcao" ]]; then
        _mensagec "${VERMELHO}" "Nenhuma opcao selecionada."
        _aguardar_tecla
        return 0
    fi

    if ! [[ "$opcao" =~ ^[0-9]+$ ]] || (( opcao < 0 || opcao >= i )); then
        _mensagec "${VERMELHO}" "Opcao invalida."
        _aguardar_tecla
        return 0
    fi

    _limpa_tela
    _linha

    if (( opcao == 0 )); then
        # Visualizar todos os logs
        _aviso "Exibindo todos os logs de atualizacao:"
        _linha
        for log in "${logs[@]}"; do
            _mensagec "${CIANO}" ">>> Arquivo: $(basename "$log")"
            _linha
            if [[ -s "$log" ]]; then
                cat "$log"
            else
                _mensagec "${VERMELHO}" "Arquivo sem dados."
            fi
            printf "\n"
            _linha
        done
    else
        # Visualizar log selecionado
        log_selecionado="${logs[$((opcao-1))]}"
        _mensagec "${AMARELO}" "Exibindo log: $(basename "$log_selecionado")"
        _linha
        if [[ -s "$log_selecionado" ]]; then
            cat "$log_selecionado"
        else
            _mensagec "${VERMELHO}" "Arquivo sem dados."
        fi
        printf "\n"
        _linha
    fi
    _mensagec "${AMARELO}" "<< Pressione ENTER para voltar >>"
    read -r
}

# Lista os logs de limpeza
_listar_logs_limpeza() {
    _limpa_tela
    _linha
    _mensagec "${AMARELO}" "Logs de Limpeza encontrados em ${DEFAULT_LOGS_DIR}:"
    _linha

    local log_selecionado log logs

    logs=("${DEFAULT_LOGS_DIR}"/limpando.*)
    if [[ ! -e "${logs[0]}" ]]; then
        _mensagec "${VERMELHO}" "Nenhum log de limpeza encontrado."
        _aguardar_tecla
        return 1
    fi

    # Exibir lista numerada dos logs disponiveis
    local i=1
    for log in "${logs[@]}"; do
        _mensagec "${CIANO}" "  ${i}) $(basename "$log")"
        (( i++ ))
    done
    _linha
    _mensagec "${VERDE}" "  0) Visualizar todos"
    _linha

    local opcao
    read -rp "${AMARELO}Selecione o arquivo [0-$((i-1))]: ${NORMAL}" opcao

    # Validar entrada
    if [[ -z "$opcao" ]]; then
        _mensagec "${VERMELHO}" "Nenhuma opcao selecionada."
        _aguardar_tecla
        return 0
    fi

    if ! [[ "$opcao" =~ ^[0-9]+$ ]] || (( opcao < 0 || opcao >= i )); then
        _mensagec "${VERMELHO}" "Opcao invalida."
        _aguardar_tecla
        return 0
    fi

    _limpa_tela
    _linha

    if (( opcao == 0 )); then
        # Visualizar todos os logs
        _mensagec "${AMARELO}" "Exibindo todos os logs de limpeza:"
        _linha
        for log in "${logs[@]}"; do
            _mensagec "${CIANO}" ">>> Arquivo: $(basename "$log")"
            _linha
            if [[ -s "$log" ]]; then
                cat "$log"
            else
                _mensagec "${VERMELHO}" "Arquivo sem dados."
            fi
            printf "\n"
            _linha
        done
    else
        # Visualizar log selecionado
        log_selecionado="${logs[$((opcao-1))]}"
        _mensagec "${AMARELO}" "Exibindo log: $(basename "$log_selecionado")"
        _linha
        if [[ -s "$log_selecionado" ]]; then
            cat "$log_selecionado"
        else
            _mensagec "${VERMELHO}" "Arquivo sem dados."
        fi
        printf "\n"
        _linha
    fi
    _mensagec "${AMARELO}" "<< Pressione ENTER para voltar >>"
    read -r
}
