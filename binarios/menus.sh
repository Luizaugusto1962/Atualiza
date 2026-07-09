#!/usr/bin/env bash
set -euo pipefail
#
# menus.sh - Sistema de Menus com Suporte a Ajuda
# Responsavel pela apresentacao e navegacao dos menus do sistema
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 08/07/2026-01
# Autor: Luiz Augusto
#

caminho="${CFG_DIR:-${SCRIPT_DIR:-.}/configuracoes}"

_criar_diretorio_seguro "${caminho}" "${PERM_DIR_SECURE}" "${LOG_ATU}" || {
    _erro "Ao criar diretorio de configuracao %s\n" "${caminho}" >&2
    return 1
}

CFG_BASE_DIR="${CFG_BASE_DIR:-}"
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"
CFG_VERSAOCLASS="${CFG_VERSAOCLASS:-}"

#---------- FUNCAO AUXILIAR DE LEITURA ----------#
# Funcao auxiliar para leitura de opcao com suporte a ajuda contextual
# Uso: _ler_opcao_menu "contexto"
# Retorna: 0 se opcao normal, 1 se comando de ajuda processado
_ler_opcao_menu() {
    local contexto="${1:-geral}"

    _linha "=" "${WHITE}"
    printf '%b\n' "${BLUE}Ajuda: Digite ${YELLOW}M${BLUE} (manual) | ${YELLOW}H${BLUE} (help)    ||    ${BLUE}Empresa: ${WHITE}${CFG_EMPRESA}${BLUE} | Iscobol: ${CYAN}${CFG_VERSAOCLASS}${BLUE} |"
    _linha "=" "${GREEN}"

    if ! read -r -t "${DEFAULT_READ_TIMEOUT}" -p "${YELLOW} Digite a opcao desejada -> ${NORM}" opcao; then
        printf '\n%s\n' "Estouro o tempo de espera na entrada. Saindo...${NORM}"
        _encerrar_programa 0
    fi

    opcao=$(_trim "$opcao" 2>/dev/null || printf '%s' "$opcao")

    case "${opcao,,}" in
        "?"|"h"|"help"|"ajuda")
            _exibir_ajuda_contextual "$contexto"
            return 1
            ;;
        "m"|"manual")
            _exibir_manual_completo
            return 1
            ;;
        "q"|"quit"|"sair"|"exit")
            printf '%s' "${GREEN}Saindo do sistema...${NORM}\n"
            exit 0
            ;;
    esac

    return 0
}

#---------- FUNCOES AUXILIARES DE MENU ----------#
# Exibe cabecalho padronizado para menus
# Parametros: $1=titulo_do_menu
_exibir_cabecalho_menu() {
    local titulo="${1:-Menu}"
    _linha "=" "${GREEN}"
    _mensagec "${RED}" "${titulo}"
    _linha "=" "${WHITE}"
    printf "\n"
}

# Exibe titulo de secao dentro do menu
# Parametros: $1=mensagem $2=cor (opcional, padrao=PURPLE)
_exibir_titulo_secao() {
    local mensagem="${1}"
    local cor="${2:-${PURPLE}}"
    _mensagec "${cor}" "${mensagem}"
}

# Exibe opcao de menu padronizada
# Parametros: $1=numero $2=descricao $3=cor_opcao (opcional, padrao=GREEN)
_exibir_opcao_menu() {
    local numero="${1}"
    local descricao="${2}"
    local cor_opcao="${3:-${GREEN}}"
    _mensageb "${cor_opcao}" "${numero}${NORM} -|: ${descricao}"
    printf "\n"
}

# Exibe separador de opcoes
_exibir_separador_menu() {
    _meia_linha "-" "${YELLOW}"
}

# Exibe rodape de menu com opcao de saida
_exibir_rodape_menu() {
    _exibir_separador_menu
    _mensageb "${WHITE}" "9${RED} -|: Menu Anterior "
}

# Processa selecao de opcao de menu com validacao
# Uso: _processar_opcao_menu "opcao" "case_variavel"
# Retorna: resultado do case ou invalido
_processar_opcao_invalida() {
    _opinvalida
    _aguardar 1
}

#---------- MENU PRINCIPAL ----------#
_principal() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu Principal"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Atualizar Programa(s)"
        _exibir_opcao_menu "2" "Atualizar Biblioteca"
        _exibir_opcao_menu "3" "Gerenciar Arquivos"
        _exibir_opcao_menu "4" "Ferramentas"
        _exibir_opcao_menu "0" "Sistema de Ajuda"
        _exibir_rodape_menu
        _mensaged "${BLUE}" "${UPDATE:-}"

        local opcao
        if ! _ler_opcao_menu "principal"; then
            continue
        fi

        case "${opcao}" in
            1) _menu_programas ;;
            2) _menu_biblioteca ;;
            3) _menu_arquivos ;;
            4) _menu_ferramentas ;;
            0) _menu_ajuda_principal ;;
            9)
                _limpa_tela
                _encerrar_programa 0
                ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE PROGRAMAS ----------#
_menu_programas() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Programas"
        _exibir_titulo_secao "Escolha o tipo de Atualizacao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Programa(s) ON-Line"
        _exibir_opcao_menu "2" "Programa(s) OFF-Line"
        _exibir_opcao_menu "3" "Programa(s) em Pacote"
        _exibir_titulo_secao "Escolha Desatualizar:"
        _exibir_separador_menu
        _exibir_opcao_menu "4" "Voltar programa Atualizado"
        _exibir_rodape_menu

        if [[ -n "${CFG_VERSAOCLASS}" ]]; then
            printf "\n"
        fi

        local opcao
        if ! _ler_opcao_menu "programas"; then
            continue
        fi

        case "${opcao}" in
            1) _atualizar_programa_online || true ;;
            2) _atualizar_programa_offline || true ;;
            3) _atualizar_programa_pacote || true ;;
            4) _reverter_programa || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE BIBLIOTECA ----------#
_menu_biblioteca() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu da Biblioteca"
        _exibir_titulo_secao "Escolha o local da Biblioteca:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Atualizacao do Transpc"
        _exibir_opcao_menu "2" "Atualizacao OFF-Line"
        _exibir_titulo_secao "Escolha Desatualizar:"
        _exibir_separador_menu
        _exibir_opcao_menu "3" "Voltar o(s) Programa(s)"
        _exibir_rodape_menu

        if [[ -f "${CFG_DIR}/.versao" ]]; then
            if ! "." "${CFG_DIR}/.versao" 2>/dev/null; then
                _aviso "Falha ao carregar ${CFG_DIR}/.versao" >&2
            fi
        fi

        if [[ -n "${VERSAOANT:-}" ]]; then
            printf "\n"
            _mensaged "${BLUE}" "Versao Anterior - ${VERSAOANT}"
        fi

        local opcao
        if ! _ler_opcao_menu "biblioteca"; then
            continue
        fi

        case "${opcao}" in
            1) _atualizar_transpc || true ;;
            2) _atualizar_biblioteca_offline || true ;;
            3) _reverter_biblioteca || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE ARQUIVOS ----------#
_menu_arquivos() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu Gerencial dos Arquivos"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Rotinas de Backup"
        _exibir_opcao_menu "2" "Reconstruir Arquivos"
        _exibir_opcao_menu "3" "Enviar & Receber Arquivos"
        _exibir_separador_menu
        _exibir_opcao_menu "4" "Arquivos Temporarios"
        _exibir_opcao_menu "5" "Expurgador de Arquivos"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "arquivos"; then
            continue
        fi

        case "${opcao}" in
            1) _menu_backup || true ;;
            2) _menu_recuperar_arquivos || true ;;
            3) _menu_transferencia_arquivos || true ;;
            4) _menu_temporarios || true ;;
            5) _executar_expurgador "arquivos" || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE FERRAMENTAS ----------#
_menu_ferramentas() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu das Ferramentas"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Configuracoes"
        _exibir_opcao_menu "2" "Update"
        _exibir_opcao_menu "3" "Lembretes"
        _exibir_opcao_menu "4" "Avisos iniciais"
        _exibir_opcao_menu "5" "Logs do sistema"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "ferramentas"; then
            continue
        fi

        case "${opcao}" in
            1) _menu_configs || true ;;
            2) _executar_update || true ;;
            3) _menu_lembretes || true ;;
            4) _menu_avisos || true ;;
            5) _menu_logs || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE TEMPORARIOS ----------#
_menu_temporarios() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Limpeza"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Limpeza dos Arquivos Temporarios"
        _exibir_opcao_menu "2" "Adicionar Arquivos Temporarios"
        _exibir_opcao_menu "3" "Listar os registros dos Arquivos"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "temporarios"; then
            continue
        fi

        case "${opcao}" in
            1) _executar_limpeza_temporarios || true ;;
            2) _adicionar_arquivo_lixo || true ;;
            3) _lista_arquivos_lixo || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE RECUPERACAO ----------#
_menu_recuperar_arquivos() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Recuperacao de Arquivo(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Um arquivo ou Todos"
        _exibir_opcao_menu "2" "Arquivos Principais"
        _exibir_opcao_menu "3" "Lista de Arquivos"
        _exibir_separador_menu
        _exibir_opcao_menu "4" "Editar Lista de Arquivos"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "recuperacao"; then
            continue
        fi

        case "${opcao}" in
            1) _recuperar_arquivo_especifico || true ;;
            2) _recuperar_arquivos_principais || true ;;
            3) _executar_lista_arquivos || true ;;
            4) _editar_lista_arquivos || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE BACKUP ----------#
_menu_backup() {
        while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Backup(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Backup da base de dados"
        _exibir_opcao_menu "2" "Backup com Multiplos Padroes"
        _exibir_opcao_menu "3" "Restaurar base de dados"
        _exibir_separador_menu
        _exibir_opcao_menu "4" "Enviar Backup"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "backup"; then
            continue
        fi

        case "${opcao}" in
            1) _executar_backup || true ;;
            2) _executar_backup_multiplos_padroes || true ;;
            3) _restaurar_backup || true ;;
            4) _enviar_backup_avulso || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE TRANSFERENCIA ----------#
_menu_transferencia_arquivos() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Enviar e Receber Arquivo(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Enviar arquivo(s)"
        _exibir_opcao_menu "2" "Receber arquivo(s)"
        _exibir_rodape_menu
        printf "\n"
        local opcao
        if ! _ler_opcao_menu "transferencia"; then
            continue
        fi

        case "${opcao}" in
            1) _enviar_arquivo_avulso || true ;;
            2) _receber_arquivo_avulso || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE CONFIGURACOES ----------#
_menu_configs() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu das Configuracoes"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Parametros do Sistema"
        _exibir_opcao_menu "2" "Versao do Iscobol"
        _exibir_opcao_menu "3" "Versao do Linux"
        _exibir_opcao_menu "4" "Consultar Variaveis"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "configs"; then
            continue
        fi

        case "${opcao}" in
            1) _menu_setups || true ;;
            2) _mostrar_versao_iscobol || true ;;
            3) _mostrar_versao_linux || true ;;
            4) _consultar_variaveis || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE SETUPS ----------#
_menu_setups() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Setup do Sistema"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Consulta de setup"
        _exibir_opcao_menu "2" "Manutencao de setup"
        _exibir_opcao_menu "3" "Validar configuracao"
        _exibir_opcao_menu "4" "Configurar Acesso SSH"
        _exibir_rodape_menu
        printf "\n"
        local opcao
        if ! _ler_opcao_menu "setups"; then
            continue
        fi

        case "${opcao}" in
            1) _mostrar_parametros || true ;;
            2)
                _manutencao_setup || true
                if [[ -f "${CFG_DIR}/.config" ]]; then
                    if command -v _carregar_config_seguro >/dev/null 2>&1; then
                        _carregar_config_seguro "${CFG_DIR}/.config" || true
                    else
                        "." "${CFG_DIR}/.config" || true
                    fi
                    _mensagec "${GREEN}" "Configuracoes recarregadas com sucesso!"
                    _aguardar 2
                fi
                ;;
            3) _validar_configuracao || true ; _aguardar_tecla ;;
            4) _menu_configurar_ssh || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE LEMBRETES ----------#
_menu_lembretes() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Bloco de Notas"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Escrever nova nota"
        _exibir_opcao_menu "2" "Visualizar nota"
        _exibir_opcao_menu "3" "Editar nota"
        _exibir_opcao_menu "4" "Apagar nota"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "lembretes"; then
            continue
        fi

        case "${opcao}" in
            1) _escrever_nova_nota || true ;;
            2)
                if [[ -f "${CFG_DIR}/lembrete" ]]; then
                    _visualizar_notas_arquivo "${CFG_DIR}/lembrete" || true
                else
                    _mensagec "${YELLOW}" "Arquivo de notas nao encontrado"
                    _aguardar 1
                fi
                ;;
            3) _editar_nota_existente || true ;;
            4) _apagar_nota_existente || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE AVISOS ----------#
_menu_avisos() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Aviso(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Gerar Aviso ao Iniciar"
        _exibir_opcao_menu "2" "Editar Aviso Existente"
        _exibir_opcao_menu "3" "Apagar Aviso Existente"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "aviso"; then
            continue
        fi

        case "${opcao}" in
            1) _gerar_aviso_entrada || true ;;
            2) _editar_aviso_existente || true ;;
            3) _apagar_aviso_entrada || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE LOGS ----------#
_menu_logs() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu dos Logs"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Log de Atualizacao"
        _exibir_opcao_menu "2" "Log de Limpeza"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "logs"; then
            continue
        fi

        case "${opcao}" in
            1) _listar_logs_atualizacao || true ;;
            2) _listar_logs_limpeza || true ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU PRINCIPAL DE AJUDA ----------#
_menu_ajuda_principal() {
    if ! _verificar_manual; then
        _aguardar_tecla
        return
    fi

    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "SISTEMA DE AJUDA"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Manual Completo"
        _exibir_opcao_menu "2" "Ajuda Rapida"
        _exibir_opcao_menu "3" "Ajuda no Geral"
        _exibir_opcao_menu "4" "Buscar no Manual"
        _exibir_opcao_menu "5" "Exportar Manual"
        _exibir_opcao_menu "6" "Ajuda por Contexto"
        _exibir_rodape_menu
        _linha "=" "${GREEN}"

        local opcao
        if ! _ler_opcao_menu "ajuda"; then
            continue
        fi

        case "${opcao}" in
            1) _exibir_manual_completo ;;
            2) _ajuda_rapida ;;
            3) _ajuda_no_geral ;;
            4) _buscar_manual ;;
            5) _exportar_manual ;;
            6) _menu_selecao_contexto ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE SELECAO DE CONTEXTO ----------#
_menu_selecao_contexto() {
    _limpa_tela
    _linha "=" "${CYAN}"
    _mensagec "${CYAN}" "SELECIONE O CONTEXTO"
    _linha "=" "${CYAN}"

    printf "\n"
    printf "%s\n" "${GREEN}1${NORM}  - Menu Principal"
    printf "%s\n" "${GREEN}2${NORM}  - Programas"
    printf "%s\n" "${GREEN}3${NORM}  - Biblioteca"
    printf "%s\n" "${GREEN}4${NORM}  - Ferramentas"
    printf "%s\n" "${GREEN}5${NORM}  - Temporarios"
    printf "%s\n" "${GREEN}6${NORM}  - Recuperacao"
    printf "%s\n" "${GREEN}7${NORM}  - Backup"
    printf "%s\n" "${GREEN}8${NORM}  - Transferencia"
    printf "%s\n" "${GREEN}9${NORM}  - Setups"
    printf "%s\n" "${GREEN}10${NORM} - Lembretes"
    printf "\n"
    _linha "=" "${CYAN}"

    local opcao
    if ! _ler_opcao_menu "contexto"; then
        return
    fi

    case "${opcao}" in
        1) _exibir_ajuda_contextual "principal" ;;
        2) _exibir_ajuda_contextual "programas" ;;
        3) _exibir_ajuda_contextual "biblioteca" ;;
        4) _exibir_ajuda_contextual "ferramentas" ;;
        5) _exibir_ajuda_contextual "temporarios" ;;
        6) _exibir_ajuda_contextual "recuperacao" ;;
        7) _exibir_ajuda_contextual "backup" ;;
        8) _exibir_ajuda_contextual "transferencia" ;;
        9) _exibir_ajuda_contextual "setups" ;;
        10) _exibir_ajuda_contextual "lembretes" ;;
        *) _processar_opcao_invalida ;;
    esac
}

#---------- MENU DE ESCOLHA DE BASE ----------#
_menu_escolha_base() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Escolha a Base"
        _exibir_titulo_secao " Escolha a opcao:"
        printf "\n"
        _exibir_opcao_menu "1" "Base em ${RAIZ}${CFG_BASE_DIR}"
        _exibir_opcao_menu "2" "Base em ${RAIZ}${CFG_BASE_DIR2}"

        if [[ -n "${CFG_BASE_DIR3}" ]]; then
            _exibir_opcao_menu "3" "Base em ${RAIZ}${CFG_BASE_DIR3}"
        fi
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "base"; then
            continue
        fi

        case "${opcao}" in
            1)
                if _definir_base_trabalho "CFG_BASE_DIR"; then
                    return 0
                fi
                ;;
            2)
                if _definir_base_trabalho "CFG_BASE_DIR2"; then
                    return 0
                fi
                ;;
            3)
                if [[ -n "${CFG_BASE_DIR3}" ]]; then
                    if _definir_base_trabalho "CFG_BASE_DIR3"; then
                        return 0
                    fi
                else
                    _processar_opcao_invalida
                fi
                ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE TIPO DE BACKUP ----------#
_menu_tipo_backup() {
    while true; do
        _limpa_tela
        _exibir_cabecalho_menu "Menu de Tipo de Backup(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        printf "\n"
        _exibir_opcao_menu "1" "Backup Completo"
        _exibir_opcao_menu "2" "Backup Incremental"
        _exibir_rodape_menu
        printf "\n"
#        _linha "=" "${GREEN}"

        local opcao
        if ! _ler_opcao_menu "tipobackup"; then
            continue
        fi

        case "${opcao}" in
            1)
                tipo_backup="completo"
                export tipo_backup
                return 0
                ;;
            2)
                tipo_backup="incremental"
                export tipo_backup
                return 0
                ;;
            9)
                tipo_backup=""
                export tipo_backup
                return 1
                ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- FUNCOES AUXILIARES ----------#
# Define a base de trabalho atual
# Parametros: $1=nome_da_base (CFG_BASE_DIR, CFG_BASE_DIR2, CFG_BASE_DIR3)
_definir_base_trabalho() {
    local base_var="$1"
    local base_dir="${!base_var}"

    if [[ -z "${RAIZ}" ]] || [[ -z "${base_dir}" ]]; then
        _erro "Erro: Variaveis de configuracao nao definidas"
        _linha
        _aguardar 2
        return 1
    fi

    export base_trabalho="${RAIZ}${base_dir}"

    if [[ ! -d "${base_trabalho}" ]]; then
        _erro "Erro: Diretorio ${base_trabalho} nao encontrado"
        _linha
        _aguardar 2
        return 1
    fi

    _mensagec "${GREEN}" "Base de trabalho definida: ${base_trabalho}"
    return 0
}

#---------- MENU DE CONFIGURACAO DE SSH ----------#
_menu_configurar_ssh() {
    _limpa_tela
    _exibir_cabecalho_menu "Configuracao de Acesso SSH sem Senha"
    _mensagec "${GREEN}" "Servidor: ${DEFAULT_IP_SERVER}: ${DEFAULT_SSH_PORTA}"
    _linha
    printf "\n"

    _checar_dependencias
    _preparar_diretorio_ssh
    _verificar_ou_criar_chave

    local ENVIAR
    read -rp "${YELLOW} Deseja enviar a chave publica para o servidor principal agora? [s/N]  ${NORM}" ENVIAR

    case "${ENVIAR}" in
        [sS]|[sS][iI][mM])
            _enviar_chave_para_servidor
            ;;
        *)
            _linha
            _mensagec "${YELLOW}" "Envio cancelado. Para enviar manualmente, execute:"
            _mensagec "${YELLOW}" "  ssh-copy-id -i ${DEFAULT_CHAVE_SSH_PUB} -p ${DEFAULT_SSH_PORTA}@${DEFAULT_IP_SERVER}"
            ;;
    esac

    local TESTAR
    read -rp "${YELLOW} Deseja testar a conexao agora? [s/N]  ${NORM}" TESTAR

    case "${TESTAR}" in
        [sS]|[sS][iI][mM])
            _testar_conexao
            ;;
    esac

    _mensagec "${GREEN}" "Configuracao concluida."
    _aguardar_tecla
    return 0
}
