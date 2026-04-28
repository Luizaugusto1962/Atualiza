#!/usr/bin/env bash
#
# help.sh - Sistema de Ajuda e Manual do Usuario
# Fornece documentacao completa e help contextual para o sistema
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 05/04/2026-01
#
# Variaveis globais esperadas
cfg_dir="${cfg_dir:-}"     # Diretorio de configuracoes

#---------- CONFIGURACOES DO SISTEMA DE AJUDA ----------#

# Arquivo de manual principal
MANUAL_FILE="${cfg_dir}/manual.txt"

# Exibe conteúdo com paginaçao automática
# Parâmetros: 
#   $1 = conteúdo para exibir
#   $2 = linhas por página (opcional, padrao: 25)
_exibir_paginado() {
    local conteudo="$1"
    local linhas_por_pagina="${2:-25}"
    local linha_atual=1
    local total_linhas
    
    # Se conteúdo vazio, lê do stdin
    if [[ -z "$conteudo" ]]; then
        conteudo=$(cat)
    fi
    
    total_linhas=$(echo "$conteudo" | wc -l)
    
    # Se conteúdo cabe em uma página, exibe direto
    if [[ $total_linhas -le $linhas_por_pagina ]]; then
        echo "$conteudo"
        return 0
    fi
    
    # Loop de paginaçao
    while [[ $linha_atual -le $total_linhas ]]; do
        # Exibe página atual
        echo "$conteudo" | sed -n "${linha_atual},$((linha_atual + linhas_por_pagina - 1))p"
        
        linha_atual=$((linha_atual + linhas_por_pagina))
        
        # Se ainda há mais conteúdo, solicita continuaçao
        if [[ $linha_atual -le $total_linhas ]]; then
            printf "\n"
            _linha "=" "${CYAN}"
            printf "%s" "${YELLOW}Pressione ENTER para continuar, 'q' para sair, 'a' para ver tudo: ${NORM}"
            read -rsn1 resposta
            
            case "${resposta,,}" in
                q)
                    echo ""
                    echo "${GREEN}Exibicao interrompida${NORM}"
                    return 0
                    ;;
                a)
                    # Exibe todo o resto sem pausa
                    echo ""
                    echo "$conteudo" | sed -n "${linha_atual},\$p"
                    return 0
                    ;;
                *)
                    # ENTER ou qualquer outra tecla continua
                    _limpa_tela
                    ;;
            esac
        fi
    done
    
    return 0
}

#---------- FUNCAO PARA LER SECAO DO MANUAL ----------#

# Lê uma seçao específica do arquivo manual.txt
# Parâmetro: $1 = nome da seçao (ex: MENU_PRINCIPAL, MENU_PROGRAMAS)
_ler_secao_manual() {
    local secao="$1"
    local conteudo=""
    local linha_inicio
    local linha_fim
    
    if [[ ! -f "$MANUAL_FILE" ]]; then
        _mensagec "${RED}" "Arquivo manual.txt nao encontrado!"
        return 1
    fi

    if [[ ! -r "$MANUAL_FILE" ]]; then
        _mensagec "${RED}" "Arquivo manual.txt sem permissao de leitura!"
        return 1
    fi

    # Encontra linha de início da seçao
    linha_inicio=$(grep -n "^\[${secao}\]$" "$MANUAL_FILE" | cut -d: -f1)
    
    if [[ -z "$linha_inicio" ]]; then
        _mensagec "${YELLOW}" "Seçao [$secao] nao encontrada no manual."
        return 1
    fi
    
    # Incrementa para pular a linha do marcador
    linha_inicio=$((linha_inicio + 1))
    
    # Encontra a proxima seçao apos a linha de início
    linha_fim=$(tail -n +${linha_inicio} "$MANUAL_FILE" | grep -n "^\[.*\]$" | head -1 | cut -d: -f1)
    
    if [[ -n "$linha_fim" ]]; then
        # Há outra seçao depois, lê até ela
        linha_fim=$((linha_inicio + linha_fim - 2))
        conteudo=$(sed -n "${linha_inicio},${linha_fim}p" "$MANUAL_FILE")
    else
        # É a última seçao, lê até o final
        conteudo=$(tail -n +${linha_inicio} "$MANUAL_FILE")
    fi
    
    echo "$conteudo"
    return 0
}

#---------- FUNCOES DE NAVEGACAO DO MANUAL ----------#

# Exibe o manual completo
_exibir_manual_completo() {
    if [[ ! -f "$MANUAL_FILE" ]]; then
        _mensagec "${RED}" "Arquivo manual.txt nao encontrado em: $MANUAL_FILE"
        _mensagec "${YELLOW}" "Crie o arquivo manual.txt no diretorio cfg/"
        _press
        return 1
    fi

    _limpa_tela
    # Reutiliza _exibir_paginado com o conteudo completo do manual
    _exibir_paginado "$(cat "$MANUAL_FILE")" 25
    return 0
}

# Exibe uma secao do manual com cabecalho e aguarda tecla
# Parametros: $1=contexto (chave do menu) $2=nome_secao (chave no manual.txt)
_exibir_secao_manual() {
    local contexto="$1"
    local secao_nome="$2"
    local conteudo

    _limpa_tela
    _linha "=" "${CYAN}"
    _mensagec "${CYAN}" "AJUDA - ${contexto^^}"
    _linha "=" "${CYAN}"
    printf "\n"

    if conteudo=$(_ler_secao_manual "$secao_nome"); then
        _exibir_paginado "$conteudo" 25
    else
        _mensagec "${YELLOW}" "Ajuda para '$contexto' nao disponivel no momento."
        _mensagec "${YELLOW}" "Use 'M' para ver o manual completo."
    fi

    printf "\n"
    _linha "-" "${GREEN}"
    _mensagec "${YELLOW}" "Pressione qualquer tecla para voltar ou 'M' para manual completo"
    _linha "-" "${GREEN}"

    local resposta
    read -rsn1 resposta
    if [[ "${resposta,,}" == "m" ]]; then
        _exibir_manual_completo
    fi
}

# Exibe ajuda contextual baseada no menu atual
# Parametros: $1=contexto (principal, programas, biblioteca, etc)
_exibir_ajuda_contextual() {
    local contexto="${1:-principal}"
    local secao_nome

    case "$contexto" in
        principal)    secao_nome="MENU_PRINCIPAL" ;;
        programas)    secao_nome="MENU_PROGRAMAS" ;;
        biblioteca)   secao_nome="MENU_BIBLIOTECA" ;;
        arquivos)     secao_nome="MENU_ARQUIVOS" ;;
        ferramentas)  secao_nome="MENU_FERRAMENTAS" ;;
        temporarios)  secao_nome="MENU_TEMPORARIOS" ;;
        recuperacao)  secao_nome="MENU_RECUPERACAO" ;;
        backup)       secao_nome="MENU_BACKUP" ;;
        transferencia) secao_nome="MENU_TRANSFERENCIA" ;;
        setups)       secao_nome="MENU_SETUPS" ;;
        lembretes)    secao_nome="MENU_LEMBRETES" ;;
        aviso)        secao_nome="MENU_AVISO" ;;
        logs)         secao_nome="MENU_LOGS" ;;
        *)            secao_nome="MENU_PRINCIPAL" ;;
    esac

    _exibir_secao_manual "$contexto" "$secao_nome"
}

# Exibe menu rapido de ajuda
_ajuda_rapida() {
    _exibir_secao_manual "ajuda_rapida" "AJUDA_RAPIDA"
}

# Exibe ajuda geral do sistema
_ajuda_no_geral() {
    _exibir_secao_manual "ajuda_no_geral" "AJUDA_NO_GERAL"
}

#---------- CRIACAO DO MANUAL PADRAO ----------#

# Verifica se manual.txt existe, se nao, avisa o usuario
_verificar_manual() {
    if [[ ! -f "$MANUAL_FILE" ]]; then
        _linha "=" "${YELLOW}"
        _mensagec "${YELLOW}" "  AVISO: Arquivo manual.txt nao encontrado!"
        _linha "=" "${YELLOW}"
        printf "\n"
        _mensagec "${WHITE}" "O arquivo manual.txt deve estar em: ${CYAN}$MANUAL_FILE${NORM}"
        printf "\n"
        _mensagec "${WHITE}" "Por favor, crie o arquivo manual.txt no diretorio cfg/"
        printf "\n"
        _linha "=" "${YELLOW}"
        return 1
    fi
    return 0
}

#---------- BUSCA NO MANUAL ----------#

# Busca termo no manual
_buscar_manual() {
    local termo=""
    
    if ! _verificar_manual; then
        _press
        return 1
    fi
    
    read -rp "${YELLOW}Termo para buscar: ${NORM}" termo
    
    if [[ -z "$termo" ]]; then
        _mensagec "${RED}" "Nenhum termo informado"
        return 1
    fi
    
    _limpa_tela
    _linha "=" "${CYAN}"
    _mensagec "${CYAN}" "RESULTADOS DA BUSCA: $termo"
    _linha "=" "${CYAN}"
    printf "\n"
    
    # Buscar e destacar resultados
    if grep -in --color=always "$termo" "$MANUAL_FILE"; then
        printf "\n"
        _mensagec "${GREEN}" "Busca concluída"
    else
        _mensagec "${YELLOW}" "Nenhum resultado encontrado para: $termo"
    fi
    
    printf "\n"
    _press
}

#---------- EXPORTAR MANUAL ----------#

# Exporta manual para arquivo externo
_exportar_manual() {
    local destino="${1:-$SCRIPT_DIR/manual_sav.txt}"
    
    if ! _verificar_manual; then
        _press
        return 1
    fi
    
    if cp "$MANUAL_FILE" "$destino"; then
        _mensagec "${GREEN}" "Manual exportado para: $destino"
    else
        _mensagec "${RED}" "Erro ao exportar manual"
        _read_sleep 2
        return 0
    fi
    
    _press
}
