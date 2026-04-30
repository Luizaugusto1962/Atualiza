#!/usr/bin/env bash
set -euo pipefail
#
# menus.sh - Sistema de Menus com Suporte a Ajuda
# Responsavel pela apresentacao e navegacao dos menus do sistema
# Padroes e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 27/04/2026-01
# Autor: Luiz Augusto
#

# Variaveis globais esperadas
sistema="${sistema:-}"                    # Nome do sistema (iscobol, savatu, transpc).
cfg_dir="${cfg_dir:-${SCRIPT_DIR:-.}/cfg}"    # Diretorio de configuracoes
verclass="${verclass:-}"                  # Versao atual do sistema
#UPDATE="${UPDATE:-}"                      # Aviso de update disponivel

if [[ ! -d "${cfg_dir}" ]]; then
    mkdir -p "${cfg_dir}" || {
        printf '%s\n' "ERRO: Nao foi possivel criar o diretorio de configuracao '${cfg_dir}'."
        return 1
    }
fi
chmod "${PERM_DIR_SECURE}" "${cfg_dir}" 2>/dev/null || {
    printf '%s\n' "AVISO: Nao foi possivel ajustar permissao em '${cfg_dir}'."
}

base="${base:-}"                          # Caminho do diretorio da primeira base de dados.
base2="${base2:-}"                        # Caminho do diretorio da segunda base de dados.
base3="${base3:-}"                        # Caminho do diretorio da terceira base de dados.
dbmaker="${dbmaker:-}"                    # Caminho do diretorio da base de dados do dbmaker.
empresa="${empresa:-}"                    # Nome da empresa (usado para exibir no menu)

#---------- FUNCAO AUXILIAR DE LEITURA ----------#

# Funcao auxiliar para leitura de opcao com suporte a ajuda contextual
# Uso: _ler_opcao_menu "contexto" min_opcao max_opcao
# Retorna: 0 se opcao normal, 1 se comando de ajuda processado
_ler_opcao_menu() {
    local contexto="${1:-geral}"
    local min_opcao="${2:-0}"
    local max_opcao="${3:-9}"
    
    # Exibir linha de ajuda
    _linha "="
    printf '%b\n' "${BLUE}Ajuda: Digite ${YELLOW}M${BLUE} (manual) | ${YELLOW}H${BLUE} (help)${NORM}"
    _linha "=" "${GREEN}"
    
    # Loop de validacao com limite de tentativas
    local tentativas=0
    local max_tentativas=3
    
    while (( tentativas < max_tentativas )); do
        # Ler opcao do usuario com timeout
        if ! read -r -t "${DEFAULT_READ_TIMEOUT}" -p "${YELLOW} Digite a opcao desejada -> ${NORM}" opcao; then
            printf "\n${RED}Timeout na entrada. Saindo...${NORM}\n"
            exit 0
        fi
        
        # Sanitizar entrada
        opcao=$(_sanitizar_entrada "$opcao" 2>/dev/null || printf '%s' "$opcao")
        opcao=$(_trim "$opcao" 2>/dev/null || printf '%s' "$opcao")
        
        # Verificar comandos de ajuda
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
                printf "${GREEN}Saindo do sistema...${NORM}\n"
                exit 0
                ;;
        esac
        
        # Validar se e um numero valido
        if command -v _validar_opcao_menu >/dev/null 2>&1; then
            if _validar_opcao_menu "$opcao" "$min_opcao" "$max_opcao"; then
                return 0  # Opcao valida
            fi
        else
            # Fallback se validacao.sh nao estiver carregado
            if [[ "$opcao" =~ ^[0-9]+$ ]] && (( opcao >= min_opcao && opcao <= max_opcao )); then
                return 0
            fi
        fi
        
        # Opcao invalida
        ((tentativas++))
        printf "${RED}Opcao invalida: '%s'. " "$opcao"
        printf "Digite um numero entre %d e %d.${NORM}\n" "$min_opcao" "$max_opcao"
        
        if (( tentativas < max_tentativas )); then
            printf "${YELLOW}Tentativa %d de %d. Tente novamente.${NORM}\n" "$((tentativas + 1))" "$max_tentativas"
        fi
    done
    
    # Excedeu tentativas
    printf "${RED}Maximo de tentativas excedido. Saindo...${NORM}\n"
    exit 1
}

#---------- MENU PRINCIPAL ----------#
# Menu principal do sistema
_principal() {
    while true; do
        _limpa_tela
        # Cabecalho
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu Principal"
        _linha
        _mensagec "${GREEN}" ".. Empresa: ${WHITE}${empresa}${GREEN} - Versao Iscobol: ${CYAN}${verclass} .."
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        # Opcoes do menu
        _mensagec "${GREEN}" "1${NORM} -|: Atualizar Programa(s) "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Atualizar Biblioteca  "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Gerenciar Arquivos    "
        printf "\n"
        _mensagec "${GREEN}" "4${NORM} -|: Ferramentas           "
        printf "\n"        
        _mensagec "${GREEN}" "0${NORM} -|: Sistema de Ajuda      "
        _meia_linha "-" "${YELLOW}"
#        printf "\n"
        _mensagec "${WHITE}" "9${RED} -|: Sair do Sistema "
        _mensaged "${BLUE}" "${UPDATE:-}"     
        
        # Usar funcao centralizada
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
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE PROGRAMAS ----------#
# Menu de atualizacao de programas
_menu_programas() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Programas"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" "Escolha o tipo de Atualizacao:"
        _meia_linha "-" "${YELLOW}" 
        _mensagec "${GREEN}" "1${NORM} -|: Programa(s) ON-Line       "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Programa(s) OFF-Line      "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Programa(s) em Pacote     "
        printf "\n"
        _mensagec "${PURPLE}" "Escolha Desatualizar:         "
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "4${NORM} -|: Voltar programa Atualizado"
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        
        if [[ -n "${verclass}" ]]; then
            printf "\n"
            _mensaged "${BLUE}" "Versao do Iscobol - ${verclass}"
        fi
        
        # Usar funcao centralizada
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
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE BIBLIOTECA ----------#
# Menu de atualizacao de biblioteca
_menu_biblioteca() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu da Biblioteca"
        _linha 
        printf "\n"
        _mensagec "${PURPLE}" "Escolha o local da Biblioteca:      "
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Atualizacao do Transpc  "
        printf "\n" 
        _mensagec "${GREEN}" "2${NORM} -|: Atualizacao OFF-Line    "
        printf "\n"
        _mensagec "${PURPLE}" "Escolha Desatualizar:               "
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "3${NORM} -|: Voltar o(s) Programa(s) "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Carregar versao anterior se disponivel
        if [[ -f "${cfg_dir}/.versao" ]]; then
            if ! "." "${cfg_dir}/.versao" 2>/dev/null; then
                printf '%s\n' "AVISO: Falha ao carregar ${cfg_dir}/.versao" >&2
            fi
        fi

        if [[ -n "${VERSAOANT}" ]]; then
            printf "\n"
            _mensaged "${BLUE}" "Versao Anterior - ${VERSAOANT}"
        fi
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "biblioteca"; then
            continue
        fi

        case "${opcao}" in
            1) _atualizar_transpc || true ;;
            2) _atualizar_biblioteca_offline || true ;;
            3) _reverter_biblioteca || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

####
#---------- MENU DE ARQUIVOS ----------#
# Menu de arquivos do sistema
_menu_arquivos() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu Gerencial dos Arquivos"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        
        # Verificar se sistema tem banco de dados
        if [[ "${dbmaker}" != "s" ]]; then
            _mensagec "${GREEN}" "1${NORM} -|: Rotinas de Backup        "
            printf "\n" 
            _mensagec "${GREEN}" "2${NORM} -|: Reconstruir Arquivos     "
            printf "\n"
        fi
        _mensagec "${GREEN}" "3${NORM} -|: Enviar & Receber Arquivos"
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "4${NORM} -|: Arquivos Temporarios     "
        printf "\n"
        _mensagec "${GREEN}" "5${NORM} -|: Expurgador de Arquivos   "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "arquivos"; then
            continue
        fi

        case "${opcao}" in
            1) 
                if [[ "${dbmaker}" = "s" ]]; then
                    _opinvalida
                    _read_sleep 1
                else
                    _menu_backup || true
                fi
                ;;
            2) 
                if [[ "${dbmaker}" = "s" ]]; then
                    _opinvalida
                    _read_sleep 1
                else
                    _menu_recuperar_arquivos || true
                fi
                ;;
            3) _menu_transferencia_arquivos || true ;;
            4) _menu_temporarios || true ;;
            5) _executar_expurgador "arquivos" || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE FERRAMENTAS ----------#
# Menu de ferramentas do sistema
_menu_ferramentas() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu das Ferramentas"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"

        # Opcoes do menu 
        _mensagec "${GREEN}" "1${NORM} -|: Configuracoes         "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Update                "
        printf "\n" 
        _mensagec "${GREEN}" "3${NORM} -|: Lembretes             "
        printf "\n"
        _mensagec "${GREEN}" "4${NORM} -|: Avisos iniciais       "
        printf "\n"
        _mensagec "${GREEN}" "5${NORM} -|: Logs do sistema       "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior  "
        printf "\n"

        # Usar funcao centralizada
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
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE TEMPORARIOS ----------#
# Menu de limpeza de arquivos temporarios
_menu_temporarios() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Limpeza"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Limpeza dos Arquivos Temporarios "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Adicionar Arquivos Temporarios   "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Listar os registros dos Arquivos "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "temporarios"; then
            continue
        fi

        case "${opcao}" in
            1) _executar_limpeza_temporarios || true ;;
            2) _adicionar_arquivo_lixo || true ;;
            3) _lista_arquivos_lixo || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE RECUPERACAO ----------#
# Menu de recuperacao de arquivos
_menu_recuperar_arquivos() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Recuperacao de Arquivo(s)"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Um arquivo ou Todos   "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Arquivos Principais   "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "recuperacao"; then
            continue
        fi

        case "${opcao}" in
            1) _recuperar_arquivo_especifico || true ;;
            2) _recuperar_arquivos_principais || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE BACKUP ----------#
# Menu de backup do sistema
_menu_backup() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Backup(s)"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Backup da base de dados      "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Backup com Multiplos Padroes "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Restaurar base de dados      "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "4${NORM} -|: Enviar Backup                "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
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
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}


#---------- MENU DE TRANSFERENCIA ----------#
# Menu de envio e recebimento de arquivos
_menu_transferencia_arquivos() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Enviar e Receber Arquivo(s)"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Enviar arquivo(s)     "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Receber arquivo(s)    "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "transferencia"; then
            continue
        fi

        case "${opcao}" in
            1) _enviar_arquivo_avulso || true ;;
            2) _receber_arquivo_avulso || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

# Menu de setups do sistema
_menu_configs() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu das Configuracoes"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Parametros do Sistema   "
        printf "\n" 
        if [[ "${sistema}" = "iscobol" ]]; then
            _mensagec "${GREEN}" "2${NORM} -|: Versao do Iscobol       "
        else
            _mensagec "${GREEN}" "2${NORM} -|: Funcao nao disponivel   "
        fi
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Versao do Linux         "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "configs"; then
            continue
        fi

        case "${opcao}" in
            1) _menu_setups || true ;;
            2) _mostrar_versao_iscobol || true ;;
            3) _mostrar_versao_linux || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

# Menu de setups do sistema
_menu_setups() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Setup do Sistema"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Consulta de setup    "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Manutencao de setup  "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Validar configuracao "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "setups"; then
            continue
        fi

        case "${opcao}" in
            1) _mostrar_parametros || true ;;
            2) 
               _manutencao_setup || true
                # Apos a manutencao, recarregar as configuracoes
                if [[ -f "${cfg_dir}/.config" ]]; then
                    "." "${cfg_dir}/.config"
                    _mensagec "${GREEN}" "Configuracoes recarregadas com sucesso!"
                    _read_sleep 2
                fi
                ;;
            3) _validar_configuracao || true ; _press ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE LEMBRETES ----------#
# Menu de bloco de notas/lembretes
_menu_lembretes() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" " Bloco de Notas "
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Escrever nova nota    "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Visualizar nota       "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Editar nota           "
        printf "\n"
        _mensagec "${GREEN}" "4${NORM} -|: Apagar nota           "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "lembretes"; then
            continue
        fi

        case "${opcao}" in
            1) _escrever_nova_nota || true ;;
            2) 
                if [[ -f "${cfg_dir}/lembrete" ]]; then
                    _visualizar_notas_arquivo "${cfg_dir}/lembrete" || true
                else
                    _mensagec "${YELLOW}" "Arquivo de notas nao encontrado"
                    _read_sleep 1
                fi
                ;;
            3) _editar_nota_existente || true ;;
            4) _apagar_nota_existente || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

# Menu de aviso inicial
_menu_avisos() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Aviso(s)"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Gerar Aviso ao Iniciar  "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Editar Aviso Existente  "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Apagar Aviso Existente  "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "aviso"; then
            continue
        fi

        case "${opcao}" in
            1) _gerar_aviso_entrada || true ;;
            2) _editar_aviso_existente || true ;;
            3) _apagar_aviso_entrada || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

# Menu dos logs do sistema
_menu_logs() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu dos Logs"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Log de Atualizacao "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Log de Limpeza     "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior"
        printf "\n"
        
        # Usar funcao centralizada
        local opcao
        if ! _ler_opcao_menu "logs"; then
            continue
        fi

        case "${opcao}" in
            1) _listar_logs_atualizacao || true ;;
            2) _listar_logs_limpeza || true ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU PRINCIPAL DE AJUDA ----------#
# Menu principal do sistema de ajuda
_menu_ajuda_principal() {
    # Verifica se manual existe ao entrar no menu
    if ! _verificar_manual; then
        _press
        return
    fi
    
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "SISTEMA DE AJUDA"
        _linha 
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${GREEN}" "1${NORM} -|: Manual Completo    "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Ajuda Rapida       "
        printf "\n"
        _mensagec "${GREEN}" "3${NORM} -|: Ajuda no Geral     "
        printf "\n"
        _mensagec "${GREEN}" "4${NORM} -|: Buscar no Manual   "
        printf "\n"
        _mensagec "${GREEN}" "5${NORM} -|: Exportar Manual    "
        printf "\n"
        _mensagec "${GREEN}" "6${NORM} -|: Ajuda por Contexto "
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        _linha "=" "${GREEN}"
        
        local opcao
        read -rp "${YELLOW}Digite a opcao desejada ->: ${NORM}" opcao

        case "${opcao}" in
            1) _exibir_manual_completo ;;
            2) _ajuda_rapida ;;
            3) _ajuda_no_geral ;;
            4) _buscar_manual ;;
            5) _exportar_manual ;;
            6) _menu_selecao_contexto ;;
            9) return ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}


# Menu para selecionar contexto de ajuda
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
    printf "%s\n" "${GREEN}5${NORM}  - Temporários"
    printf "%s\n" "${GREEN}6${NORM}  - Recuperaçao"
    printf "%s\n" "${GREEN}7${NORM}  - Backup"
    printf "%s\n" "${GREEN}8${NORM}  - Transferência"
    printf "%s\n" "${GREEN}9${NORM}  - Setups"
    printf "%s\n" "${GREEN}10${NORM} - Lembretes"
    printf "\n"
    _linha "=" "${CYAN}"
    
    local opcao
    read -rp "${YELLOW}Opçao: ${NORM}" opcao
    
    case "$opcao" in
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
        *) 
            _mensagec "${RED}" "Opcao invalida" 
            sleep 1 
            ;;
    esac
}

#---------- MENU DE ESCOLHA DE BASE ----------#
# Menu para escolher base de dados
_menu_escolha_base() {
    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Escolha a Base"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        printf "\n"
        _mensagec "${GREEN}" "1${NORM} -|: Base em ${raiz}${base}"
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Base em ${raiz}${base2}"
        printf "\n"
        
        if [[ -n "${base3}" ]]; then
            _mensagec "${GREEN}" "3${NORM} -|: Base em ${raiz}${base3}"
            printf "\n"
        fi
        
        printf "\n"
        _meia_linha "-" "${YELLOW}"
        _mensagec "${WHITE}" "9${RED} -|: Menu Anterior "
        printf "\n"
        _linha "=" "${GREEN}"

        local opcao
        read -rp "${YELLOW} Digite a opcao desejada -> ${NORM}" opcao

        case "${opcao}" in
            1) 
                if _definir_base_trabalho "base"; then
                    return 0
                fi
                ;;
            2) 
                if _definir_base_trabalho "base2"; then
                    return 0
                fi
                ;;
            3) 
                if [[ -n "${base3}" ]]; then
                    if _definir_base_trabalho "base3"; then
                        return 1
                    fi
                else
                    _opinvalida
                    _read_sleep 1
                fi
                ;;
            9) return
                ;;
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- MENU DE TIPO DE BACKUP ----------#
# Menu para escolher tipo de backup

_menu_tipo_backup() {

    while true; do
        _limpa_tela
        _linha "=" "${GREEN}"
        _mensagec "${RED}" "Menu de Tipo de Backup(s)"
        _linha
        printf "\n"
        _mensagec "${PURPLE}" " Escolha a opcao:"
        printf "\n"
        _mensagec "${GREEN}" "1${NORM} -|: Backup Completo       "
        printf "\n"
        _mensagec "${GREEN}" "2${NORM} -|: Backup Incremental    "
        printf "\n"
        _mensagec "${WHITE}" "9${NORM} -|: ${RED}Menu Anterior"
        printf "\n"
        _linha "=" "${GREEN}"

        local opcao
        read -rp "${YELLOW} Digite a opcao desejada -> ${NORM}" opcao

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
            *)
                _opinvalida
                _read_sleep 1
                ;;
        esac
    done
}

#---------- FUNcoES AUXILIARES DE MENU ----------#
# Define a base de trabalho atual
# Parametros: $1=nome_da_base (base, base2, base3)
_definir_base_trabalho() {
    local base_var="$1"
    local base_dir="${!base_var}"

    if [[ -z "${raiz}" ]] || [[ -z "${base_dir}" ]]; then
        _mensagec "${RED}" "Erro: Variaveis de configuracao nao definidas"
        _linha
        _read_sleep 2
        return 1
    fi
    
    export base_trabalho="${raiz}${base_dir}"
    
    if [[ ! -d "${base_trabalho}" ]]; then
        _mensagec "${RED}" "Erro: Diretorio ${base_trabalho} nao encontrado"
        _linha
        _read_sleep 2
        return 1
    fi
    
    _mensagec "${GREEN}" "Base de trabalho definida: ${base_trabalho}"
    return 0
}

