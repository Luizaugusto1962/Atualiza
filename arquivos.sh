#!/usr/bin/env bash
#
# arquivos.sh - Modulo de Gestao de Arquivos
# Responsavel por limpeza, recuperacao, transferencia e expurgo de arquivos
# Padroes e regras de desenvolvimento: ver AGENTS.md
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 23/04/2026-01
#
# Variaveis globais esperadas
sistema="${sistema:-}"                    # Tipo de sistema (ex: iscobol, outros).
base="${base:-}"                          # Caminho do diretorio da segunda base de dados.
base3="${base3:-}"                        # Caminho do diretorio da terceira base de dados.
cmd_zip="${cmd_zip:-}"                    # Comando para compactacao (ex: zip).
jut="${jut:-}"                            # Caminho para o utilitario jutil.
raiz="${raiz:-}"                          # Caminho raiz do sistema.
cfg_dir="${cfg_dir:-${SCRIPT_DIR}/cfg}"    # Caminho do diretorio de configuracoes.
LOGS="${LOGS:-${SCRIPT_DIR}/logs}"         # Diretorio de logs

#---------- FUNCOES DE LIMPEZA ----------#

# Resolve a base de trabalho ativa para operacoes de arquivos
_selecionar_base_arquivos() {

    if [[ -n "${base2}" ]]; then
        if ! _menu_escolha_base; then
            # Usuario escolheu voltar (opcao 9) — retorna 1 para o chamador voltar ao menu
            return 1
        fi
    else
        base_trabalho="${raiz}${base}"
    fi

    # Validar antes de prosseguir
    if [[ -z "${base_trabalho}" ]]; then
        _mensagec "${RED}" "Erro: Diretorio de trabalho nao foi definido"
        _press
        return 1
    fi

    if [[ ! -d "${base_trabalho}" ]]; then
        _mensagec "${RED}" "Erro: Diretorio ${base_trabalho} nao encontrado"
        _press
        return 1
    fi

    if [[ ! -r "${base_trabalho}" ]]; then
        _mensagec "${RED}" "Erro: Sem permissao de leitura em ${base_trabalho}"
        _press
        return 1
    fi

    export base_trabalho
    return 0
}

# Executa limpeza de arquivos temporarios
_executar_limpeza_temporarios() {

    # Excluir arquivos de lista antigos para evitar confusao
    for lista in "atualizal" "atualizaj" "atualizaj2" "atualizat" "atualizat2" ".atualizac" ".atualizac.bkp" ".atualizac.bak"; do
        local caminho_lista="${cfg_dir}/${lista}"
        if [[ -f "${caminho_lista}" ]]; then
            if rm -f "${caminho_lista}"; then
                _log "Lista temporaria removida: ${lista}"
            else
                _log "AVISO: Falha ao remover lista temporaria: ${lista}"
            fi
        fi
    done

    # Verificar arquivo de lista de temporarios
    local arquivo_lista="${cfg_dir}/limpetmp"
    if [[ ! -f "${arquivo_lista}" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo ${arquivo_lista} nao existe no diretorio"
        _read_sleep 2
        return 1
    elif [[ ! -r "${arquivo_lista}" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo ${arquivo_lista} sem permissao de leitura"
        _read_sleep 2
        return 1
    fi

    local arquivo_lista2="${cfg_dir}/limpetmp2"

    # Limpar temporarios antigos do backup
    find "${BACKUP}" -type f -name "Temps*" -mtime +10 -delete 2>/dev/null || true

    # Processar cada base de dados configurada
    for base_dir in "$base" "$base2" "$base3"; do
        if [[ -n "$base_dir" ]]; then
            local caminho_base="${raiz}${base_dir}"
            if [[ -d "$caminho_base" ]]; then
                _limpar_base_especifica "$caminho_base" "$arquivo_lista"
                # Processar limpetmp2 na sequencia, se existir
                if [[ -f "${arquivo_lista2}" && -r "${arquivo_lista2}" ]]; then
                    _limpar_base_especifica "$caminho_base" "$arquivo_lista2"
                fi
            else
                _mensagec "${YELLOW}" "Diretorio nao existe: ${caminho_base}"
                _read_sleep 2
            fi
        fi
    done
    _press
}

# Limpa arquivos da base especifica 
_limpar_base_especifica() {
    local caminho_base="$1"
    local arquivo_lista="$2"
    local arquivos_temp=()
    
    # Validar parâmetros
    if [[ -z "$caminho_base" || -z "$arquivo_lista" ]]; then
        _mensagec "${RED}" "ERRO: Parametros invalidos"
        return 1  
    fi
    
    if [[ ! -d "$caminho_base" ]]; then
        _mensagec "${RED}" "ERRO: Diretorio nao existe: $caminho_base"
        return 1  
    fi
    
    if [[ ! -f "$arquivo_lista" ]]; then
        _mensagec "${RED}" "ERRO: Arquivo de lista nao existe"
        return 1  
    fi
    
    # Ler lista de arquivos temporarios
    mapfile -t arquivos_temp < "$arquivo_lista"
    
    _mensagec "${YELLOW}" "Limpando arquivos temporarios do diretorio: ${caminho_base}"
    _read_sleep 1
    _linha
    
    local zip_temporarios
    zip_temporarios="Temps-${UMADATA}.zip"

    for padrao_arquivo in "${arquivos_temp[@]}"; do
        [[ -n "$padrao_arquivo" ]] || continue

        # Coletar arquivos de uma unica vez — mesma lista usada no zip e no rm
        local arquivos_zip=()
        mapfile -t arquivos_zip < <(find "$caminho_base" -type f -iname "$padrao_arquivo")
        local qtd_padrao="${#arquivos_zip[@]}"

        # Nenhum arquivo encontrado para este padrao — pular
        if [[ "$qtd_padrao" -eq 0 ]]; then
            continue
        fi

        _mensagec "${GREEN}" "Processando padrao: ${YELLOW}${padrao_arquivo}${NORM} (${qtd_padrao} arquivo(s))"
        _read_sleep 1
        
        # Compactar — $cmd_zip sem aspas para suportar flags (ex: "zip -j")
        if $cmd_zip "${BACKUP}/${zip_temporarios}" "${arquivos_zip[@]}" >>"${LOG_LIMPA}" 2>&1; then
            _log "Arquivos temporarios compactados: $padrao_arquivo (${qtd_padrao} arquivo(s))" "${LOG_LIMPA}"
            # Remover usando o mesmo array ja coletado.
            if printf '%s\0' "${arquivos_zip[@]}" | xargs -0 rm -f; then
                _log "Arquivos removidos: $padrao_arquivo (${qtd_padrao} arquivo(s))" "${LOG_LIMPA}"
            else
                _log "AVISO: falha ao remover arquivos do padrao: $padrao_arquivo" "${LOG_LIMPA}"
            fi
         else
            _log "ERRO ao compactar arquivos do padrao: $padrao_arquivo" "${LOG_LIMPA}"
            _mensagec "${RED}" "  >> ERRO ao compactar padrao: ${padrao_arquivo}"
            _read_sleep 1
        fi
    done
    _linha
    _mensagec "${GREEN}" "Limpeza concluida"
    return 0
}

# Adiciona arquivo à lista de limpeza
_adicionar_arquivo_lixo() {
    
    _limpa_tela
    _meio_da_tela
    _mensagec "${CYAN}" "Informe o nome do arquivo a ser adicionado ao limpetmp2"
    _linha
    
    local novo_arquivo
    read -rp "${YELLOW}Qual o arquivo -> ${NORM}" novo_arquivo
    _linha

    if [[ -z "$novo_arquivo" ]]; then
        _mensagec "${RED}" "Nome de arquivo nao informado"
        _press
        return 1
    fi

    # Adicionar arquivo à lista
    echo "$novo_arquivo" >> "${cfg_dir}/limpetmp2"
    _mensagec "${CYAN}" "Arquivo '${novo_arquivo}' adicionado com sucesso ao 'limpetmp2'"
    _linha
    
    _press
}

# Lista os arquivos no limpetmp e limpetmp2
_lista_arquivos_lixo() {
    
    _limpa_tela
    _meio_da_tela
    _mensagec "${CYAN}" "Lista de arquivos no limpetmp:"
    _linha

    if [[ -f "${cfg_dir}/limpetmp" && -s "${cfg_dir}/limpetmp" ]]; then
        nl -w3 -s'. ' "${cfg_dir}/limpetmp"
    else
        _mensagec "${YELLOW}" "Nenhum arquivo listado no 'limpetmp'"
    fi

    _linha
    _mensagec "${CYAN}" "Lista de arquivos no limpetmp2:"
    _linha

    if [[ -f "${cfg_dir}/limpetmp2" && -s "${cfg_dir}/limpetmp2" ]]; then
        nl -w3 -s'. ' "${cfg_dir}/limpetmp2"
    else
        _mensagec "${YELLOW}" "Nenhum arquivo listado no 'limpetmp2'"
    fi

    _linha
    _press
}

#---------- FUNCOES DE RECUPERACAO ----------#
# Recupera arquivo especifico ou todos
_recuperar_arquivo_especifico() {
    local continuar="S"

    if ! _selecionar_base_arquivos; then
        return 0
    fi

    _limpa_tela
    if [[ "${sistema}" != "iscobol" ]]; then
        _mensagec "${RED}" "Recuperacao em desenvolvimento para este sistema"
        _press
        return 1
    fi

    # Loop para permitir múltiplas recuperações
    while [[ "${continuar}" =~ ^[Ss]$ ]]; do
        _meio_da_tela
        _mensagec "${CYAN}" "Informe o nome do arquivo a ser recuperado ou ENTER para todos:"
        _linha
        
        local nome_arquivo
        read -rp "${YELLOW}Nome do arquivo: ${NORM}" nome_arquivo
        nome_arquivo=$(echo "$nome_arquivo" | xargs) # Remove espacos extras

        _linha "-" "${BLUE}"
        
        if [[ -z "$nome_arquivo" ]]; then
            # Pergunta confirmação antes de recuperar todos
            _mensagec "${YELLOW}" "Deseja recuperar TODOS os arquivos principais?"
            read -rp "${YELLOW}[S/N]: ${NORM}" confirmar_todos
            confirmar_todos=$(echo "$confirmar_todos" | xargs | tr '[:lower:]' '[:upper:]')
            
            if [[ "$confirmar_todos" =~ ^[Ss]$ ]]; then
                # Recupera todos → executa e sai do loop
                _recuperar_todos_arquivos "$base_trabalho"
                _mensagec "${YELLOW}" "Todos os arquivos principais foram recuperados."
                break
            else
                _mensagec "${CYAN}" "Operacao cancelada."
                _linha
                _read_sleep 2 
                return 0
            fi   
        else
            # Recupera arquivo específico
            _recuperar_arquivo_individual "$nome_arquivo" "$base_trabalho"
            _mensagec "${YELLOW}" "Arquivo(s) recuperado(s)..."
        fi
        _linha
        
        # Só pergunta se quer continuar se foi um arquivo específico
        _mensagec "${CYAN}" "Deseja recuperar mais arquivos?"
        read -rp "${YELLOW}[S/N]: ${NORM}" continuar
        continuar=$(echo "$continuar" | xargs | tr '[:lower:]' '[:upper:]')
        
        # Se vazio, assumir "N"
        [[ -z "$continuar" ]] && continuar="N"
    
    _limpa_tela
    done
    _ir_para_tools
}

# Recupera todos os arquivos principais
_recuperar_todos_arquivos() {
    local base_trabalho="$1"
    local -a extensoes=('*.ARQ.dat' '*.DAT.dat' '*.LOG.dat' '*.PAN.dat')
    _mensagec "${RED}" "Recuperando todos os arquivos principais..."
    _linha "-" "${YELLOW}"
    
    if [[ -d "$base_trabalho" ]]; then
        shopt -s nullglob
        for extensao in "${extensoes[@]}"; do
            for arquivo in ${base_trabalho}/${extensao}; do
                if [[ -f "$arquivo" && -s "$arquivo" ]]; then
                    _executar_jutil "$arquivo"
                else
                    _mensagec "${YELLOW}" "Arquivo nao encontrado ou vazio: ${arquivo##*/}"
                    _linha "-" "${GREEN}"
                fi
            done
        done
        shopt -u nullglob
    else
        _mensagec "${RED}" "Erro: Diretorio ${base_trabalho} nao existe"
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
    nome_arquivo=$(echo "$nome_arquivo" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')

    if [[ -z "$nome_arquivo" ]]; then
        _mensagec "${RED}" "Nome de arquivo vazio apos normalizacao."
        return 1
    fi

    if [[ ! "$nome_arquivo" =~ ^[A-Z0-9._-]+$ ]]; then
        _mensagec "${RED}" "Nome de arquivo invalido. Use apenas letras, numeros, pontos e hifens."
        return 1
    fi
    
    local padrao_arquivo="${nome_arquivo}.*.dat"
    local arquivos_encontrados=0
    
    shopt -s nullglob
    for arquivo in ${base_trabalho}/${padrao_arquivo}; do
        if [[ -f "$arquivo" ]]; then
            _executar_jutil "$arquivo"
            ((arquivos_encontrados++)) || true
        fi
    done
    shopt -u nullglob
    
    if (( arquivos_encontrados == 0 )); then
        _mensagec "${YELLOW}" "Nenhum arquivo encontrado para: ${nome_arquivo}"
        _linha "-" "${GREEN}"
    fi
}

# Recupera arquivos principais baseado na lista
_recuperar_arquivos_principais() {
    cd "${cfg_dir}" || return 1
    
    if ! _selecionar_base_arquivos; then
        return 1
    fi
    
    if [[ "${sistema}" = "iscobol" ]]; then
        # Usar valor padrão se base_trabalho estiver vazia
        base_trabalho="${base_trabalho:-${raiz}${base}}"
        cd "$base_trabalho" || {
            _mensagec "${RED}" "Erro: Diretorio ${base_trabalho} nao encontrado"
            return 1
        }
        
        # Gerar lista de arquivos atuais
        local var_ano var_ano4
        var_ano=$(date +%y)
        var_ano4=$(date +%Y)
        
        # Criar lista temporaria
        {
            ls ATE"${var_ano}"*.dat 2>/dev/null || true
            ls NFE?"${var_ano4}".*.dat 2>/dev/null || true
        } > "${cfg_dir}/indexar2"
        
        cd "${cfg_dir}" || return 1
        _read_sleep 1
        
        # Verificar arquivos de lista
        for lista in "indexar2" "indexar"; do
            if [[ -f "$lista" && -r "$lista" ]]; then
                _processar_lista_arquivos "$lista" "$base_trabalho"
            fi
        done
        
        # Limpar arquivo temporario
        [[ -f "indexar2" ]] && rm -f "indexar2"
        
        _mensagec "${YELLOW}" "Arquivos principais recuperados"
    else
        _mensagec "${RED}" "Recuperacao nao disponivel para este sistema"
    fi
    _press
}

# Processa lista de arquivos para recuperacao
_processar_lista_arquivos() {
    local arquivo_lista="$1"
    local base_trabalho="$2"
    
    while IFS= read -r listando || [[ -n "$listando" ]]; do
        [[ -z "$listando" ]] && continue
        local caminho_arquivo="${base_trabalho}/${listando}"
        _executar_jutil "$caminho_arquivo"
    done < "$arquivo_lista"
}

# Executa jutil no arquivo especificado
_executar_jutil() {
    local arquivo="$1"
    if [[ -x "${jut}" ]]; then    
        if [[ -n "$arquivo" && -e "$arquivo" && -s "$arquivo" ]]; then
            if "${jut}" -rebuild "$arquivo" -a -f; then
                _log_sucesso "Rebuild executado: $(basename "$arquivo")"
                # garantir permissões máximas após o rebuild
                chmod 0755 "$arquivo" 2>/dev/null || \
                _mensagec "${YELLOW}" "Aviso: nao foi possivel alterar permissoes de $arquivo"
                # garantir permissões máximas nos arquivos .idx gerados pelo jutil
                local dir_arquivo base_arquivo arquivo_idx
                dir_arquivo="$(dirname "$arquivo")"
                base_arquivo="$(basename "$arquivo" .dat)"
                for arquivo_idx in "${dir_arquivo}/${base_arquivo}"*.idx; do
                    if [[ -f "$arquivo_idx" ]]; then
                        chmod 0755 "$arquivo_idx" 2>/dev/null || \
                        _mensagec "${YELLOW}" "Aviso: nao foi possivel alterar permissoes de $arquivo_idx"
                    fi
                done
            else
                _mensagec "${RED}" "Erro no rebuild: $(basename "$arquivo")"
            fi
            _linha "-" "${GREEN}"

        else
            _mensagec "${YELLOW}" "Arquivo nao encontrado ou vazio: $(basename "$arquivo" 2>/dev/null || echo "$arquivo")"
        fi
    else
        _mensagec "${RED}" "Erro: jutil nao encontrado em ${jut}"
        return 1
    fi    
}

#---------- FUNCOES DE TRANSFERENCIA ----------#

# Envia arquivo avulso
_enviar_arquivo_avulso() {
    _limpa_tela
    local dir_origem arquivo_enviar destino_remoto
    
    # Solicitar diretorio de origem
    _linha
    _mensagec "${YELLOW}" "1- Origem: Informe o diretorio onde esta o arquivo:"
    read -rp "${YELLOW} -> ${NORM}" dir_origem
    _linha
    
    if [[ -z "$dir_origem" ]]; then
        dir_origem="${ENVIA:-}"
        if [[ -z "$dir_origem" || ! -d "$dir_origem" ]]; then
            _mensagec "${RED}" "Diretorio de origem nao informado ou padrao nao definido"
            _press
            return 1
        fi
        _linha
        _mensagec "${YELLOW}" "Usando diretorio padrao: ${dir_origem}"
        # Verificar se há arquivos no diretório
        shopt -s nullglob
        local arquivos=("${dir_origem}"/*)
        shopt -u nullglob
        if (( ${#arquivos[@]} == 0 )); then
            _mensagec "${YELLOW}" "Nenhum arquivo encontrado no diretorio"
            _press
            return 1
        fi
    elif [[ ! -d "$dir_origem" ]]; then
        _mensagec "${RED}" "Diretorio nao encontrado: ${dir_origem}"
        _press
        return 1
    fi
    
    # Solicitar nome do arquivo
    _linha
    _mensagec "${CYAN}" "Informe o arquivo que deseja enviar"
    _mensagec "${CYAN}" "Use * para enviar todas as extensoes (ex: ARQUIVO*)"
    _linha
    read -rp "${YELLOW}2- Nome do ARQUIVO: ${NORM}" arquivo_enviar
    
    if [[ -z "$arquivo_enviar" ]]; then
        _mensagec "${RED}" "Nome do arquivo nao informado"
        _press
        return 1
    fi
    
    # Verificar se o arquivo contém wildcard (*)
    if [[ "$arquivo_enviar" == *"*"* ]]; then
        # Listar arquivos que correspondem ao padrão
        shopt -s nullglob
        local arquivos_encontrados=()
        while IFS= read -r -d '' arquivo; do
            arquivos_encontrados+=("$arquivo")
        done < <(find "${dir_origem}" -maxdepth 1 -type f -name "${arquivo_enviar}" -print0)
        shopt -u nullglob
        
        if (( ${#arquivos_encontrados[@]} == 0 )); then
            _mensagec "${YELLOW}" "Nenhum arquivo encontrado com o padrao: ${arquivo_enviar}"
            _press
            return 1
        fi
        
        # Mostrar arquivos encontrados
        _linha
        _mensagec "${CYAN}" "Arquivos encontrados (${#arquivos_encontrados[@]}):"
        for arquivo in "${arquivos_encontrados[@]}"; do
            _mensagec "${GREEN}" "  - $(basename "$arquivo")"
        done
        _linha
        
        # Confirmar envio
        local confirmacao
        read -rp "${YELLOW}Deseja enviar todos esses arquivos? [S/N]: ${NORM}" confirmacao
        confirmacao=$(echo "$confirmacao" | tr '[:lower:]' '[:upper:]')
        
        if [[ "$confirmacao" != "S" ]]; then
            _mensagec "${YELLOW}" "Envio cancelado pelo usuario"
            _press
            return 0
        fi
    else
        # Verificação para arquivo único (sem wildcard)
        if [[ ! -e "${dir_origem}/${arquivo_enviar}" ]]; then
            _mensagec "${YELLOW}" "${arquivo_enviar} nao encontrado em ${dir_origem}"
            _press
            return 1
        fi
    fi
    
    # Solicitar destino remoto
    printf "\n"
    _linha
    _mensagec "${YELLOW}" "3- Destino: Informe o diretorio no servidor:"
    read -rp "${YELLOW} -> ${NORM}" destino_remoto
    _linha
    
    if [[ -z "$destino_remoto" ]]; then
        _mensagec "${RED}" "Destino nao informado"
        _press
        return 1
    fi
    
    # Enviar arquivo(s)
    _linha
    _mensagec "${YELLOW}" "Informe a senha para o usuario remoto:"
    _linha
    _enviar_arquivo_multi
 }

# Recebe arquivo avulso
_receber_arquivo_avulso() {
    _limpa_tela
    local origem_remota arquivo_receber destino_local
    
    # Solicitar origem remota
    _linha
    _mensagec "${YELLOW}" "1- Origem: Diretorio remoto do arquivo:"
    read -rp "${YELLOW} -> ${NORM}" origem_remota
    _linha
    
    # Solicitar nome do arquivo
    _mensagec "${RED}" "Informe o arquivo que deseja RECEBER"
    _linha
    read -rp "${YELLOW}2- Nome do ARQUIVO: ${NORM}" arquivo_receber
    
    if [[ -z "$arquivo_receber" ]]; then
        _mensagec "${RED}" "Nome do arquivo nao informado"
        _press
        return 1
    fi
    
    # Solicitar destino local
    _linha
    _mensagec "${YELLOW}" "3- Destino: Diretorio local para receber:"
    read -rp "${YELLOW} -> ${NORM}" destino_local
    
    if [[ -z "$destino_local" ]]; then
        destino_local="${down_dir:-}"
    fi
    
    if [[ ! -d "$destino_local" ]]; then
        _mensagec "${RED}" "Diretorio de destino nao encontrado: ${destino_local}"
        _press
        return 1
    fi
    
    # Receber arquivo
    _linha
    _mensagec "${YELLOW}" "Informe a senha para o usuario remoto:"
    _linha
    if _download_scp "${origem_remota}/${arquivo_receber}" "${destino_local}/"; then
        _mensagec "${GREEN}" "Arquivo recebido com sucesso em \"${destino_local}\""
        _linha
        _read_sleep 3
    else
        _mensagec "${RED}" "Erro no recebimento do arquivo"
        _press
    fi
}

#---------- FUNCOES DE EXPURGO ----------#
# Executa expurgador de arquivos antigos
_executar_expurgador() {
    _executar_expurgador_diario

    local origem="${1:-principal}"
    _limpa_tela
    
    _linha
    _mensagec "${RED}" "Verificando e excluindo arquivos com mais de 30 dias"
    _linha
    printf "\n"
    
    # Definir diretorios para limpeza
    local diretorios_limpeza=(
        "${BACKUP}/"
        "${BIBLIOTECA}/"
        "${ENVIA}/"
        "${RECEBE}/"
        "${BASEBACKUP}/"
        "${OLDS}/"
        "${PROGS}/"
        "${LOGS}/"
        "${raiz}/portalsav/log/"
        "${raiz}/err_isc/"
        "${raiz}/savisc/viewvix/tmp/"
    )
   
   
    # Limpar arquivos antigos nos diretorios padrao
    for diretorio in "${diretorios_limpeza[@]}"; do
        if [[ -d "$diretorio" ]]; then
            local arquivos_removidos
            arquivos_removidos=$(find "$diretorio" -mtime +30 -type f -delete -print 2>/dev/null | wc -l)
            _mensagec "${GREEN}" "Limpando arquivos do diretorio: ${diretorio} (${arquivos_removidos} arquivos)"
        else
            _mensagec "${YELLOW}" "Diretorio nao encontrado: ${diretorio}"
        fi
    done

    local diretorios_zip=(
        "${E_EXEC}/"
        "${T_TELAS}/"
    )

    # Limpar arquivos ZIP antigos especificos
    for diretorio in "${diretorios_zip[@]}"; do
        if [[ -d "$diretorio" ]]; then
            local zips_removidos
            zips_removidos=$(find "$diretorio" -name "*.zip" -type f -mtime +15 -delete -print 2>/dev/null | wc -l)
            _mensagec "${GREEN}" "Limpando arquivos .zip antigos: ${diretorio} (${zips_removidos} arquivos)"
        else
            _mensagec "${YELLOW}" "Diretorio nao encontrado: ${diretorio}"
        fi
    done
    
    printf "\n"
    _linha
    _press
    _ir_para_tools
    
    # Retornar ao menu baseado na origem
    if [[ "$origem" == "arquivos" ]]; then
        return 0
    else
        _menu_arquivos
    fi
}

# Lista os logs de atualizacao
_listar_logs_atualizacao() {
    _limpa_tela
    _linha
    _mensagec "${YELLOW}" "Logs de Atualizacao encontrados em ${LOGS}:"
    _linha
    
    local logs=("${LOGS}"/atualiza.*)
    if [[ ! -e "${logs[0]}" ]]; then
        _mensagec "${RED}" "Nenhum log de atualizacao encontrado."
        _press
        return 1
    fi

    # Exibir lista numerada dos logs disponiveis
    local i=1
    for log in "${logs[@]}"; do
        _mensagec "${CYAN}" "  ${i}) $(basename "$log")"
        (( i++ ))
    done
    _linha
    _mensagec "${GREEN}" "  0) Visualizar todos"
    _linha

    local opcao
    read -rp "${YELLOW}Selecione o arquivo [0-$((i-1))]: ${NORM}" opcao

    # Validar entrada
    if [[ -z "$opcao" ]]; then
        _mensagec "${RED}" "Nenhuma opcao selecionada."
        _press
        return 0
    fi

    if ! [[ "$opcao" =~ ^[0-9]+$ ]] || (( opcao < 0 || opcao >= i )); then
        _mensagec "${RED}" "Opcao invalida."
        _press
        return 0
    fi

    _limpa_tela
    _linha

    if (( opcao == 0 )); then
        # Visualizar todos os logs
        _mensagec "${YELLOW}" "Exibindo todos os logs de atualizacao:"
        _linha
        for log in "${logs[@]}"; do
            _mensagec "${CYAN}" ">>> Arquivo: $(basename "$log")"
            _linha
            if [[ -s "$log" ]]; then
                cat "$log"
            else
                _mensagec "${RED}" "Arquivo sem dados."
            fi
            printf "\n"
            _linha
        done
    else
        # Visualizar log selecionado
        local log_selecionado="${logs[$((opcao-1))]}"
        _mensagec "${YELLOW}" "Exibindo log: $(basename "$log_selecionado")"
        _linha
        if [[ -s "$log_selecionado" ]]; then
            cat "$log_selecionado"
        else
            _mensagec "${RED}" "Arquivo sem dados."
        fi
        printf "\n"
        _linha
    fi
    _mensagec "${YELLOW}" "<< Pressione ENTER para voltar >>"
    read -r
} 

# Lista os logs de limpeza 
_listar_logs_limpeza() {
    _limpa_tela
    _linha
    _mensagec "${YELLOW}" "Logs de Limpeza encontrados em ${LOGS}:"
    _linha
    
    local logs=("${LOGS}"/limpando.*)
    if [[ ! -e "${logs[0]}" ]]; then
        _mensagec "${RED}" "Nenhum log de limpeza encontrado."
        _press
        return 1
    fi

    # Exibir lista numerada dos logs disponiveis
    local i=1
    for log in "${logs[@]}"; do
        _mensagec "${CYAN}" "  ${i}) $(basename "$log")"
        (( i++ ))
    done
    _linha
    _mensagec "${GREEN}" "  0) Visualizar todos"
    _linha

    local opcao
    read -rp "${YELLOW}Selecione o arquivo [0-$((i-1))]: ${NORM}" opcao

    # Validar entrada
    if [[ -z "$opcao" ]]; then
        _mensagec "${RED}" "Nenhuma opcao selecionada."
        _press
        return 0
    fi

    if ! [[ "$opcao" =~ ^[0-9]+$ ]] || (( opcao < 0 || opcao >= i )); then
        _mensagec "${RED}" "Opcao invalida."
        _press
        return 0
    fi

    _limpa_tela
    _linha

    if (( opcao == 0 )); then
        # Visualizar todos os logs
        _mensagec "${YELLOW}" "Exibindo todos os logs de limpeza:"
        _linha
        for log in "${logs[@]}"; do
            _mensagec "${CYAN}" ">>> Arquivo: $(basename "$log")"
            _linha
            if [[ -s "$log" ]]; then
                cat "$log"
            else
                _mensagec "${RED}" "Arquivo sem dados."
            fi
            printf "\n"
            _linha
        done
    else
        # Visualizar log selecionado
        local log_selecionado="${logs[$((opcao-1))]}"
        _mensagec "${YELLOW}" "Exibindo log: $(basename "$log_selecionado")"
        _linha
        if [[ -s "$log_selecionado" ]]; then
            cat "$log_selecionado"
        else
            _mensagec "${RED}" "Arquivo sem dados."
        fi
        printf "\n"
        _linha
    fi
    _mensagec "${YELLOW}" "<< Pressione ENTER para voltar >>"
    read -r
}