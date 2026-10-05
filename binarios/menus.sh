#!/usr/bin/env bash
set -euo pipefail
#
# menus.sh - Sistema de Menus com Suporte a Ajuda
# Responsavel pela apresentacao e navegacao dos menus do sistema
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 30/09/2026
# Autor: Luiz Augusto
#

CFG_BASE_DIR="${CFG_BASE_DIR:-}"
CFG_BASE_DIR2="${CFG_BASE_DIR2:-}"
CFG_BASE_DIR3="${CFG_BASE_DIR3:-}"
CFG_VERSAOCLASS="${CFG_VERSAOCLASS:-}"

#---------- FUNCAO AUXILIAR DE LEITURA ----------#
# Funcao auxiliar para leitura de opcao com suporte a ajuda contextual
# Uso: local opcao
#      _ler_opcao_menu "contexto" opcao || continue
#
# O nome da variavel de destino e obrigatorio ($2) e atribuido com printf -v.
# Nao da para devolver a opcao no stdout: a linha de ajuda e a interface
# impressas aqui ja ocupam o stdout, e o valor viria misturado com elas.
# Exigir o nome torna explicita a dependencia — antes ela era implicita
# (a funcao escrevia em `opcao` do chamador e cada um dos 20 menus declarava
# `local opcao` so por causa disso).
#
# Em timeout/EOF chama _encerrar_programa, que encerra o processo.
# Retorna: 0 se opcao lida, 1 se foi ajuda/manual (o menu deve redesenhar)
_ler_opcao_menu() {
    local contexto="${1:-geral}"
    local destino="${2:-}"
    local lida=""

    if [[ -z "$destino" ]]; then
        _erro "Variavel de destino nao informada em _ler_opcao_menu" >&2
        return 1
    fi

    _linha "=" "${BRANCO}"
    printf '%b\n' "${AZUL}Ajuda: Digite ${AMARELO}M${AZUL} (manual) | ${AMARELO}H${AZUL} (help)|| ${AZUL}Empresa: ${BRANCO}${CFG_EMPRESA}${AZUL}| Iscobol: ${CIANO}${CFG_VERSAOCLASS}${AZUL}|"
    _linha "=" "${VERDE}"

    if ! read -r -t "${DEFAULT_READ_TIMEOUT}" -p "${AMARELO} Digite a opcao desejada -> ${NORMAL}" lida; then
        printf '\n'
        _linha "-" "${BRANCO}"
        _exibir_mensagem_centralizada "${VERMELHO}" "Estouro o tempo de espera na entrada. Saindo...${NORMAL}"
        _encerrar_programa 0
    fi

    lida=$(_trim "$lida" 2>/dev/null || printf '%s' "$lida")

    case "${lida,,}" in
        "?"|"h"|"help"|"ajuda")
            _exibir_ajuda_contextual "$contexto"
            return 1
            ;;
        "m"|"manual")
            _exibir_manual_completo
            return 1
            ;;
        "q"|"quit"|"sair"|"exit")
            _msg "Saindo do sistema..."
            _encerrar_programa 0
            ;;
    esac

    printf -v "$destino" '%s' "$lida"
    return 0
}

#---------- FUNCOES AUXILIARES DE MENU ----------#
# Exibe cabecalho padronizado para menus
# Parametros: $1=titulo_do_menu
_exibir_cabecalho_menu() {
    local titulo="${1:-Menu}"
    _linha "=" "${VERDE}"
    _exibir_mensagem_centralizada "${VERMELHO}" "${titulo}"
    _linha "=" "${BRANCO}"
    printf "\n"
}

# Exibe titulo de secao dentro do menu
# Parametros: $1=mensagem $2=cor (opcional, padrao=PURPLE)
_exibir_titulo_secao() {
    local mensagem="${1:-}"
    local cor="${2:-${ROXO}}"
    _exibir_mensagem_centralizada "${cor}" "${mensagem}"
}

# Exibe opcao de menu padronizada
# Parametros: $1=numero $2=descricao $3=cor_opcao (opcional, padrao=GREEN)
_exibir_opcao_menu() {
    local numero="${1:-}"
    local descricao="${2:-}"
    local cor_opcao="${3:-${VERDE}}"
    _exibir_mensagem_centralizada_a_esquerda "${cor_opcao}" "${numero}${NORMAL} -|: ${descricao}"
    printf "\n"
}

# Exibe separador de opcoes
_exibir_separador_menu() {
    _meia_linha "-" "${AMARELO}"
}

# Exibe rodape de menu com opcao de saida
_exibir_rodape_menu() {
    _exibir_separador_menu
    _exibir_mensagem_centralizada_a_esquerda "${BRANCO}" "9${VERMELHO} -|: Menu Anterior "
}

# Processa selecao de opcao de menu com validacao
# Uso: _processar_opcao_menu "opcao" "case_variavel"
# Retorna: resultado do case ou invalido
_processar_opcao_invalida() {
    _opinvalida
    _aguardar_tecla
}

#---------- MENU PRINCIPAL ----------#
_principal() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu Principal"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Atualizar Programa(s)"
        _exibir_opcao_menu "2" "Atualizar Biblioteca"
        _exibir_opcao_menu "3" "Rotinas de Backup"
        _exibir_opcao_menu "4" "Gerenciar Arquivos"
        _exibir_opcao_menu "5" "Ferramentas"
        _exibir_opcao_menu "0" "Sistema de Ajuda"
        _exibir_rodape_menu
        printf "\n"
#        _exibir_mensagem_direita "${AZUL}" "${UPDATE:-}"

        local opcao
        if ! _ler_opcao_menu "principal" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _menu_programas ;;
            2) _menu_biblioteca ;;
            3) _menu_backup ;;
            4) _menu_arquivos ;;
            5) _menu_ferramentas ;;
            0) _menu_ajuda_principal ;;
            9)
                clear
                _encerrar_programa 0
                ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE PROGRAMAS ----------#
_menu_programas() {
    while true; do
        clear
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
        if ! _ler_opcao_menu "programas" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: atualizar_programa_online" "${LOG_LIMPA}" _atualizar_programa_online ;;
            2) _tentar_log "menu: atualizar_programa_offline" "${LOG_LIMPA}" _atualizar_programa_offline ;;
            3) _tentar_log "menu: atualizar_programa_pacote" "${LOG_LIMPA}" _atualizar_programa_pacote ;;
            4) _tentar_log "menu: reverter_programa" "${LOG_LIMPA}" _reverter_programa ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE BIBLIOTECA ----------#
_menu_biblioteca() {
    while true; do
        clear
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
            # Parser com whitelist (sistema.sh): um .versao adulterado nao
            # consegue sobrescrever PATH/HOME nem executar codigo neste shell.
            # O guard mantem o menu vivo se o modulo nao foi carregado.
            if command -v _carregar_versao_seguro >/dev/null 2>&1; then
                _carregar_versao_seguro "${CFG_DIR}/.versao" ||
                    _aviso "Falha ao carregar ${CFG_DIR}/.versao" >&2
            else
                _aviso "Modulo sistema.sh ausente: versao da biblioteca nao carregada" >&2
            fi
        fi

        if [[ -n "${VERSAOANT:-}" ]]; then
            printf "\n"
            _exibir_mensagem_direita "${AZUL}" "Versao Anterior - ${VERSAOANT}"
        fi

        local opcao
        if ! _ler_opcao_menu "biblioteca" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: atualizar_transpc" "${LOG_LIMPA}" _atualizar_transpc ;;
            2) _tentar_log "menu: atualizar_biblioteca_offline" "${LOG_LIMPA}" _atualizar_biblioteca_offline ;;
            3) _tentar_log "menu: reverter_biblioteca" "${LOG_LIMPA}" _reverter_biblioteca ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE ARQUIVOS ----------#
_menu_arquivos() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu Gerencial dos Arquivos"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Recuperar Index (Jutil)"
        _exibir_separador_menu
        _exibir_opcao_menu "2" "Arquivos Temporarios"
        _exibir_opcao_menu "3" "Expurgador de Arquivos"
        _exibir_separador_menu
        _exibir_opcao_menu "4" "Enviar & Receber Arquivos"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "arquivos" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: menu_recuperar_arquivos" "${LOG_LIMPA}" _menu_recuperar_arquivos ;;
            2) _tentar_log "menu: menu_temporarios" "${LOG_LIMPA}" _menu_temporarios ;;
            3) _tentar_log "menu: executar_expurgador" "${LOG_LIMPA}" _executar_expurgador "arquivos" ;;
            4) _tentar_log "menu: menu_transferencia_arquivos" "${LOG_LIMPA}" _menu_transferencia_arquivos ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE FERRAMENTAS ----------#
_menu_ferramentas() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu das Ferramentas"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Configuracoes"
        _exibir_opcao_menu "2" "Update"
        _exibir_opcao_menu "3" "Lembretes"
        _exibir_opcao_menu "4" "Avisos iniciais"
        _exibir_opcao_menu "5" "Logs do sistema"
        _exibir_opcao_menu "6" "Volta .sh anterior"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "ferramentas" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: menu_configs" "${LOG_LIMPA}" _menu_configs ;;
            2) _tentar_log "menu: executar_update" "${LOG_LIMPA}" _executar_update ;;
            3) _tentar_log "menu: menu_lembretes" "${LOG_LIMPA}" _menu_lembretes ;;
            4) _tentar_log "menu: menu_avisos" "${LOG_LIMPA}" _menu_avisos ;;
            5) _tentar_log "menu: menu_logs" "${LOG_LIMPA}" _menu_logs ;;
            6) _tentar_log "menu: voltar_sh_anterior" "${LOG_LIMPA}" _voltar_sh_anterior ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE TEMPORARIOS ----------#
_menu_temporarios() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu de Limpeza"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Limpeza dos Arquivos Temporarios"
        _exibir_opcao_menu "2" "Adicionar Arquivos Temporarios"
        _exibir_opcao_menu "3" "Listar os registros dos Arquivos"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "temporarios" opcao; then
            continue
        fi

        case "${opcao}" in
            # _tentar_log em vez de "|| true": o menu nao pode quebrar por uma limpeza
            # com falha, mas o erro precisa ficar registrado (ver utils.sh).
            1) _tentar_log "limpeza de temporarios (menu)" "${LOG_LIMPA}" _executar_limpeza_temporarios ;;
            2) _tentar_log "menu: adicionar_arquivo_lixo" "${LOG_LIMPA}" _adicionar_arquivo_lixo ;;
            3) _tentar_log "menu: lista_arquivos_lixo" "${LOG_LIMPA}" _lista_arquivos_lixo ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE RECUPERACAO ----------#
_menu_recuperar_arquivos() {
    while true; do
        clear
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
        if ! _ler_opcao_menu "recuperacao" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: recuperar_arquivo_especifico" "${LOG_LIMPA}" _recuperar_arquivo_especifico ;;
            2) _tentar_log "menu: recuperar_arquivos_principais" "${LOG_LIMPA}" _recuperar_arquivos_principais ;;
            3) _tentar_log "menu: executar_lista_arquivos" "${LOG_LIMPA}" _executar_lista_arquivos ;;
            4) _tentar_log "menu: editar_lista_arquivos" "${LOG_LIMPA}" _editar_lista_arquivos ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE BACKUP ----------#
_menu_backup() {
    while true; do
        clear
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
        if ! _ler_opcao_menu "backup" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: executar_backup" "${LOG_LIMPA}" _executar_backup ;;
            2) _tentar_log "menu: executar_backup_multiplos_padroes" "${LOG_LIMPA}" _executar_backup_multiplos_padroes ;;
            3) _tentar_log "menu: restaurar_backup" "${LOG_LIMPA}" _restaurar_backup ;;
            4) _tentar_log "menu: enviar_backup_avulso" "${LOG_LIMPA}" _enviar_backup_avulso ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE TRANSFERENCIA ----------#
_menu_transferencia_arquivos() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu de Enviar e Receber Arquivo(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Enviar arquivo(s)"
        _exibir_opcao_menu "2" "Receber arquivo(s)"
        _exibir_rodape_menu
        printf "\n"
        local opcao
        if ! _ler_opcao_menu "transferencia" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: enviar_arquivo_avulso" "${LOG_LIMPA}" _enviar_arquivo_avulso ;;
            2) _tentar_log "menu: receber_arquivo_avulso" "${LOG_LIMPA}" _receber_arquivo_avulso ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE CONFIGURACOES ----------#
_menu_configs() {
    while true; do
        clear
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
        if ! _ler_opcao_menu "configs" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: menu_setups" "${LOG_LIMPA}" _menu_setups ;;
            2) _tentar_log "menu: mostrar_versao_iscobol" "${LOG_LIMPA}" _mostrar_versao_iscobol ;;
            3) _tentar_log "menu: mostrar_versao_linux" "${LOG_LIMPA}" _mostrar_versao_linux ;;
            4) _tentar_log "menu: consultar_variaveis" "${LOG_LIMPA}" _consultar_variaveis ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE SETUPS ----------#
_menu_setups() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu de Setup do Sistema"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Consulta de setup"
        _exibir_opcao_menu "2" "Manutencao de setup"
        _exibir_opcao_menu "3" "Configurar Acesso SSH"
        _exibir_rodape_menu
        printf "\n"
        local opcao
        if ! _ler_opcao_menu "setups" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: mostrar_parametros" "${LOG_LIMPA}" _mostrar_parametros ;;
            2)
                _tentar_log "menu: manutencao_setup" "${LOG_LIMPA}" _manutencao_setup
                ;;
            3) _tentar_log "menu: menu_configurar_ssh" "${LOG_LIMPA}" _menu_configurar_ssh ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE LEMBRETES ----------#
_menu_lembretes() {
    while true; do
        clear
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
        if ! _ler_opcao_menu "lembretes" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: escrever_nova_nota" "${LOG_LIMPA}" _escrever_nova_nota ;;
            2)
                if [[ -f "${CFG_DIR}/lembrete" ]]; then
                    _tentar_log "menu: visualizar_notas" "${LOG_LIMPA}" _visualizar_notas_arquivo "${CFG_DIR}/lembrete"
                else
                    _exibir_mensagem_centralizada "${AMARELO}" "Arquivo de notas nao encontrado"
                    _aguardar 1
                fi
                ;;
            3) _tentar_log "menu: editar_nota_existente" "${LOG_LIMPA}" _editar_nota_existente ;;
            4) _tentar_log "menu: apagar_nota_existente" "${LOG_LIMPA}" _apagar_nota_existente ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE AVISOS ----------#
_menu_avisos() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu de Aviso(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Gerar Aviso ao Iniciar"
        _exibir_opcao_menu "2" "Editar Aviso Existente"
        _exibir_opcao_menu "3" "Apagar Aviso Existente"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "aviso" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: gerar_aviso_entrada" "${LOG_LIMPA}" _gerar_aviso_entrada ;;
            2) _tentar_log "menu: editar_aviso_existente" "${LOG_LIMPA}" _editar_aviso_existente ;;
            3) _tentar_log "menu: apagar_aviso_entrada" "${LOG_LIMPA}" _apagar_aviso_entrada ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE LOGS ----------#
_menu_logs() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu dos Logs"
        _exibir_titulo_secao " Escolha a opcao:"
        _exibir_separador_menu
        _exibir_opcao_menu "1" "Log de Atualizacao"
        _exibir_opcao_menu "2" "Log de Limpeza"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "logs" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: listar_logs_atualizacao" "${LOG_LIMPA}" _listar_logs_atualizacao ;;
            2) _tentar_log "menu: listar_logs_limpeza" "${LOG_LIMPA}" _listar_logs_limpeza ;;
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
        clear
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
        printf "\n"
        local opcao
        if ! _ler_opcao_menu "ajuda" opcao; then
            continue
        fi

        case "${opcao}" in
            1) _tentar_log "menu: exibir_manual_completo" "${LOG_LIMPA}" _exibir_manual_completo ;;
            2) _tentar_log "menu: ajuda_rapida" "${LOG_LIMPA}" _ajuda_rapida ;;
            3) _tentar_log "menu: ajuda_no_geral" "${LOG_LIMPA}" _ajuda_no_geral ;;
            4) _tentar_log "menu: buscar_manual" "${LOG_LIMPA}" _buscar_manual ;;
            5) _tentar_log "menu: exportar_manual" "${LOG_LIMPA}" _exportar_manual ;;
            6) _tentar_log "menu: menu_selecao_contexto" "${LOG_LIMPA}" _menu_selecao_contexto ;;
            9) return ;;
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE SELECAO DE CONTEXTO ----------#
_menu_selecao_contexto() {
    clear
    _linha "=" "${CIANO}"
    _exibir_mensagem_centralizada "${CIANO}" "SELECIONE O CONTEXTO"
    _linha "=" "${CIANO}"

    printf "\n"
    printf "%s\n" "${VERDE}1${NORMAL}  - Menu Principal"
    printf "%s\n" "${VERDE}2${NORMAL}  - Programas"
    printf "%s\n" "${VERDE}3${NORMAL}  - Biblioteca"
    printf "%s\n" "${VERDE}4${NORMAL}  - Ferramentas"
    printf "%s\n" "${VERDE}5${NORMAL}  - Temporarios"
    printf "%s\n" "${VERDE}6${NORMAL}  - Recuperacao"
    printf "%s\n" "${VERDE}7${NORMAL}  - Backup"
    printf "%s\n" "${VERDE}8${NORMAL}  - Transferencia"
    printf "%s\n" "${VERDE}9${NORMAL}  - Setups"
    printf "%s\n" "${VERDE}10${NORMAL} - Lembretes"
    printf "\n"
    _linha "=" "${CIANO}"

    local opcao
    if ! _ler_opcao_menu "contexto" opcao; then
        return
    fi

    case "${opcao}" in
        1) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "principal" ;;
        2) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "programas" ;;
        3) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "biblioteca" ;;
        4) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "ferramentas" ;;
        5) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "temporarios" ;;
        6) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "recuperacao" ;;
        7) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "backup" ;;
        8) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "transferencia" ;;
        9) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "setups" ;;
        10) _tentar_log "menu: exibir_ajuda_contextual" "${LOG_LIMPA}" _exibir_ajuda_contextual "lembretes" ;;
        *) _processar_opcao_invalida ;;
    esac
}

#---------- MENU DE ESCOLHA DE BASE ----------#
_menu_escolha_base() {
    while true; do
        clear
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
        if ! _ler_opcao_menu "base" opcao; then
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
            9) return 1 ;; # Sair: retorna erro para o chamador abandonar a operacao sem mensagem de base nao selecionada
            *) _processar_opcao_invalida ;;
        esac
    done
}

#---------- MENU DE TIPO DE BACKUP ----------#
_menu_tipo_backup() {
    while true; do
        clear
        _exibir_cabecalho_menu "Menu de Tipo de Backup(s)"
        _exibir_titulo_secao " Escolha a opcao:"
        printf "\n"
        _exibir_opcao_menu "1" "Backup Completo"
        _exibir_opcao_menu "2" "Backup Incremental"
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "tipobackup" opcao; then
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
    local base_var="${1:-}"
    # Guarda: ${!base_var} com nome vazio e erro fatal no bash ("invalid
    # indirect expansion") — tratar antes da indirecao.
    if [[ -z "$base_var" ]]; then
        _erro "Erro: base de trabalho nao informada"
        _linha
        _aguardar 2
        return 1
    fi
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

    _exibir_mensagem_centralizada "${VERDE}" "Base de trabalho definida: ${base_trabalho}"
    return 0
}

#---------- MENU DE CONFIGURACAO DE SSH ----------#
_menu_configurar_ssh() {
    clear
    _exibir_cabecalho_menu "Configuracao de Acesso SSH sem Senha"
    _exibir_mensagem_centralizada "${VERDE}" "Servidor: ${DEFAULT_IP_SERVER}: ${DEFAULT_SSH_PORTA}"
    _linha
    printf "\n"

    _checar_dependencias
    if ! _preparar_diretorio_ssh; then
        _aviso "Configuracao de chave abortada: diretorio ~/.ssh indisponivel."
        _aguardar_tecla
        return 1
    fi
    if ! _verificar_ou_criar_chave; then
        _aviso "Sem chave SSH valida, a conexao sem senha nao podera ser configurada."
        _aguardar_tecla
        return 1
    fi

    local ENVIAR
    read -rp "${AMARELO} Deseja enviar a chave publica para o servidor principal agora? [s/N]  ${NORMAL}" ENVIAR

    case "${ENVIAR}" in
        [sS]|[sS][iI][mM])
            _enviar_chave_para_servidor
            ;;
        *)
            _linha
            _exibir_mensagem_centralizada "${AMARELO}" "Envio cancelado. Para enviar manualmente, execute:"
            _exibir_mensagem_centralizada "${AMARELO}" "  ssh-copy-id -i ${DEFAULT_CHAVE_SSH_PUB} -p ${DEFAULT_SSH_PORTA} ${DEFAULT_SSH_USER}@${DEFAULT_IP_SERVER}"
            ;;
    esac

    local TESTAR
    read -rp "${AMARELO} Deseja testar a conexao agora? [s/N]  ${NORMAL}" TESTAR

    case "${TESTAR}" in
        [sS]|[sS][iI][mM])
            _testar_conexao
            ;;
    esac

    _exibir_mensagem_centralizada "${VERDE}" "Configuracao concluida."
    _aguardar_tecla
    return 0
}

#---------- MENU DE ESCOLHA DE BASE DE RESTAURACAO ----------#
# Menu para escolha da base de destino na restauracao
# Verifica se base2 e/ou base3 estao configuradas no .config
# Se apenas base1 existir, usa automaticamente sem perguntar
# Define variavel global BASE_RESTAURACAO e retorna: 0 se selecionado, 1 se cancelado
_menu_escolha_base_restauracao() {
    BASE_RESTAURACAO=""
    export BASE_RESTAURACAO
    local -a bases_disponiveis=()
    local -a bases_nomes=()

    # Sempre incluir base principal
    bases_disponiveis+=("${RAIZ}${CFG_BASE_DIR}")
    bases_nomes+=("Principal: ${RAIZ}${CFG_BASE_DIR}")

    # Incluir base2 se configurada
    if [[ -n "${CFG_BASE_DIR2}" ]]; then
        bases_disponiveis+=("${RAIZ}${CFG_BASE_DIR2}")
        bases_nomes+=("Segunda: ${RAIZ}${CFG_BASE_DIR2}")
    fi

    # Incluir base3 se configurada
    if [[ -n "${CFG_BASE_DIR3}" ]]; then
        bases_disponiveis+=("${RAIZ}${CFG_BASE_DIR3}")
        bases_nomes+=("Terceira: ${RAIZ}${CFG_BASE_DIR3}")
    fi

    # Se so existe uma base, usar automaticamente
    if [[ ${#bases_disponiveis[@]} -eq 1 ]]; then
        BASE_RESTAURACAO="${bases_disponiveis[0]}"
        export BASE_RESTAURACAO
        return 0
    fi

    # Mostrar menu de selecao
    while true; do
        clear
        _exibir_cabecalho_menu "Escolha a Base de Destino"
        _exibir_titulo_secao " Selecione o diretorio para restauracao:"
        printf "\n"

        local i
        for i in "${!bases_nomes[@]}"; do
            _exibir_opcao_menu "$((i + 1))" "${bases_nomes[$i]}"
        done
        _exibir_rodape_menu
        printf "\n"

        local opcao
        if ! _ler_opcao_menu "baserestauracao" opcao; then
            continue
        fi

        case "${opcao}" in
            9)
                _aviso "Operacao cancelada."
                return 1
                ;;
            *)
                if [[ ! "$opcao" =~ ^[0-9]+$ ]]; then
                    _processar_opcao_invalida
                    continue
                fi

                # 10#: sem isso "$((010 - 1))" e lido como OCTAL e "010"
                # selecionaria o 8o item em vez do 10o.
                local indice=$((10#$opcao - 1))
                if (( indice >= 0 && indice < ${#bases_disponiveis[@]} )); then
                    local base_escolhida="${bases_disponiveis[$indice]}"
                    if [[ -d "$base_escolhida" ]]; then
                        BASE_RESTAURACAO="$base_escolhida"
                        export BASE_RESTAURACAO
                        return 0
                    else
                        _erro "Diretorio ${base_escolhida} nao encontrado"
                        _aguardar 2
                    fi
                else
                    _processar_opcao_invalida
                fi
                ;;
        esac
    done
}
