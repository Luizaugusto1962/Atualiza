#!/usr/bin/env bash
set -euo pipefail
umask 077
#
#
# setup.sh - Gerencia a configuracao do sistema
# Este script gerencia a criacao e a edicao dos arquivos de configuracao
# .config, que e essencial para o funcionamento do sistema.
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# Modos de Operacao:
#   ./atualiza.sh --setup          - Configuracao inicial interativa
#   ./atualiza.sh --setup --edit   - Edicao das configuracoes existentes
#
# SISTEMA SAV - Script de Atualizacao Modular
# Versao: 11/11/2026-01
#---------- FUNCAO DE LOGICA DE NEGOCIO ----------#
# Variaveis globais esperadas
verclass="${verclass:-}"           # Versao do IsCobol (ex: 2018, 2020, 2023, 2024, 2025)

# Funcao de saida padronizada (local, sem dependencia de modulos)
_encerrar_programa() {
    local status="${1:-0}"
    exit "$status"
}

# =============================================================================
# CARREGAR CONSTANTES DO SISTEMA
# =============================================================================

# Carregar constantes se disponivel
_carregar_constantes_setup() {
if [[ -f "${LIBS_DIR}/constantes.sh" ]]; then
    "." "${LIBS_DIR}/constantes.sh"
fi
}

# Variaveis globais usadas pelas funcoes de setup
# (normalizacao de caso e feita explicitamente nas funcoes)

tracejada="#-------------------------------------------------------------------#"
traco="#####################################################################"

# Remove metacaracteres que o parser seguro do .config (_carregar_config_seguro
# / _validar_config_file) rejeita ([ ` ; | & < > ( ) { } $). Sem isso uma
# entrada digitada no setup gravava um .config invalido que bloqueava o
# carregamento do sistema inteiro na proxima execucao.
#
# O conjunto vem de uma variavel de proposito: escrito como literal dentro do
# "${valor//.../}" o Bash descarta o "\" antes de ";" "|" "&" "{" "}", e o
# conjunto efetivo perde ">", "(" e ")" — justamente os caracteres que o
# parser tambem rejeita. Com o conjunto incompleto, um nome de empresa com
# parenteses (ex: "ACME (SP)") era gravado e o sistema recusava o .config
# na execucao seguinte.
#
# "#" entra no conjunto porque o parser trata o resto da linha como comentario
# inline: sem remover, "EMPRESA#LTDA" era truncado silenciosamente para
# "EMPRESA".
_sanitizar_valor_setup() {
    local valor="${1:-}"
    local perigoso='[\`;&|<>(){}$#]'
    valor="${valor//$perigoso/}"
    printf '%s' "$valor"
}

# Le uma opcao de UM caractere do teclado sem deixar o "Enter" pendente no
# buffer de entrada.
#
# "read -n1" devolve assim que le 1 caractere e DEIXA o "\n" do Enter no
# buffer: a leitura seguinte consome esse "\n" vazio e todas as respostas
# posteriores caem no campo errado (base2 <- base, base3 <- base2, ...).
# Ler a linha inteira e usar o primeiro caractere elimina o deslocamento.
#
# Parametros: $1 = prompt, $2 = nome da variavel de destino
# Retorna: 0 se leu, 1 se a entrada acabou (EOF)
_ler_opcao() {
    local _entrada=""
    read -rp "$1" _entrada || return 1
    printf -v "$2" '%s' "${_entrada:0:1}"
}

# Aborta o setup porque a entrada acabou (EOF) no meio das perguntas.
#
# Sem isso o script seguia com valores vazios e gravava um ".config" que o
# proprio sistema recusa a carregar (Offline vazio, base vazia).
#
# O ".config" parcial e removido, MAS o conteudo anterior e restaurado do
# backup: sem isso, um setup interrompido apagava uma configuracao valida que
# o cliente ja tinha. Se nao havia configuracao anterior, o parcial e so
# removido.
_abortar_setup_parcial() {
    printf "%s\n" "Entrada encerrada antes do fim. Configuracao nao gravada." >&2
    local cfg="${CFG_DIR:-.}/.config"
    if [[ -f "${cfg}" ]]; then
        rm -f "${cfg}"
    fi
    if [[ -f "${cfg}.bkp" ]]; then
        cp "${cfg}.bkp" "${cfg}"
        printf "%s\n" "A configuracao anterior foi restaurada." >&2
    fi
    _encerrar_programa 1
}

# Diretorio do servidor offline
# Configuracao inicial do sistema
_initial_setup() {
    # "clear" devolve 1 quando o TERM e ausente ou "dumb"; com "set -e" no topo
    # isso abortava o setup inteiro antes da primeira pergunta. O "|| true"
    # segue o padrao ja usado em cadastro.sh.
    clear 2>/dev/null || true
    _carregar_constantes_setup

    # Backup do .config existente antes de sobrescreve-lo: se o setup for
    # interrompido no meio, o abort restaura este backup em vez de deixar o
    # cliente sem configuracao.
    if [[ -f .config ]]; then
        cp .config .config.bkp
    fi

    # Header inicial
    echo "$traco"
    echo "###      ( Parametros para serem usados no atualiza.sh )          ###"
    echo "$traco"
    # Criar arquivo de configuracao
    {
        echo "$traco"
        echo "###      ( Parametros para serem usados no atualiza.sh )          ###"
        echo "$traco"
    } > .config

    # Configuracoes adicionais
    _setup_iscobol
    _setup_diretorios
    _setup_acesso_remoto
    _setup_chave_acesso
    _setup_offline
    _setup_backup
    _setup_empresa

    # Criar atalho global (requer permissao de root)
    if [[ $EUID -eq 0 ]]; then
        _criar_atalho_global || true
    else
        printf "%s\n" "AVISO: Sem permissao de root. Atalho global nao criado."
        printf "Execute 'sudo %s/atualiza.sh --setup' para criar o atalho.\n" "${SCRIPT_DIR}"
    fi

    echo "Pronto!"
}

# Edicao de configuracoes existentes
_edit_setup() {
    local tracejada="#-------------------------------------------------------------------#"
    _carregar_constantes_setup
    # Mover para o diretorio de configuracao
    cd "${CFG_DIR}" || {
        echo "Erro: Diretorio 'configuracoes' nao encontrado."
        _encerrar_programa 1
    }

    # Verificar se os arquivos de configuracao existem
    if [[ ! -f "${CFG_DIR}/.config" ]]; then
        echo "Arquivos de configuracao nao encontrados. Execute o setup inicial primeiro."
        _encerrar_programa 1
    fi
    # Ver o comentario em _initial_setup: "clear" pode falhar (TERM ausente)
    # e nao pode derrubar o setup sob "set -e".
    clear 2>/dev/null || true
    echo "=================================================="
    echo "Carregando parametros para edicao..."
    echo "=================================================="

    # Carregar configuracoes existentes
    if command -v _carregar_config_seguro >/dev/null 2>&1; then
        _carregar_config_seguro ./.config
    else
        echo "ERRO: Parser seguro de configuracao nao disponivel. Carregamento bloqueado." >&2
        _encerrar_programa 1
    fi

    # Fazer backup
    cp .config .config.bkp

    # Edicao interativa das variaveis
    _editar_variavel verclass
    _editar_variavel acessossh
    _editar_variavel chavessh
    _editar_variavel Offline
    if [[ "${Offline}" == "n" ]]; then
        _editar_variavel enviabackup
    fi
    _editar_variavel empresa
    _editar_variavel base
    _editar_variavel base2
    _editar_variavel base3

    # Recriar arquivos de configuracao
     _recreate_config_files

    echo "Arquivo .config atualizado com sucesso!"

    # Configurar SSH se habilitado. O "|| true" impede que uma conexao SSH
    # recusada aborte o script sob "set -e": o .config ja foi gravado e o
    # usuario so precisa ser avisado.
    if [[ "${acessossh}" == "s" ]]; then
        _configure_ssh_access || true
    fi

    echo "$tracejada"
    # O "|| true" cobre o EOF: sem entrada, o "read" devolve 1 e o "set -e"
    # abortava com codigo 1 mesmo com o .config ja gravado com sucesso.
    read -rp "Pressione Enter para sair..." || true
    _encerrar_programa 0
}

#---------- FUNcoES DE SETUP INICIAL ----------#

# Configuracao para IsCobol
_setup_iscobol() {
    local VERSAO
    echo "$tracejada"
    echo "Escolha a versao do Iscobol:"
    echo "1) Versao 2020"
    echo "2) Versao 2023"
    echo "3) Versao 2024"
    echo "4) Versao 2025"
    echo "5) Versao 2026"
    _ler_opcao "Escolha a versao -> " VERSAO || _encerrar_programa 1

    case "$VERSAO" in
        1) _2020 ;;
        2) _2023 ;;
        3) _2024 ;;
        4) _2025 ;;
        5) _2026 ;;
        *)
            echo "Alternativa incorreta, saindo!"
            sleep 1
            _encerrar_programa 1
            ;;
    esac

    }

# Funcoes de versao do IsCobol
_2020() {
    {
        echo "verclass=2020"
    } >> .config
    verclass="2020"
}
_2023() {
    {
        echo "verclass=2023"
    } >> .config
    verclass="2023"
}
_2024() {
    {
        echo "verclass=2024"
    } >> .config
    verclass="2024"
}

_2025() {
    {
        echo "verclass=2025"
    } >> .config
    verclass="2025"
}
_2026() {
    {
        echo "verclass=2026"
    } >> .config
    verclass="2026"
}
# Configuracoes adicionais

_setup_diretorios() {
    echo ${tracejada}
    echo "###     ( Nome de pasta no servidor )              ###"
    read -rp "Nome da pasta da base de dados principal (Ex: /dados_jisam): " base || _abortar_setup_parcial
    base="$(_sanitizar_valor_setup "$base")"
    base="${base:-/dados_jisam}"
    base="${base,,}"  # Normalizar para minusculo
    echo "base=${base}" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da segunda base de dados (Opcional): " base2 || _abortar_setup_parcial
    base2="$(_sanitizar_valor_setup "$base2")"
    base2="${base2,,}"  # Normalizar para minusculo
    [[ -n "$base2" ]] && echo "base2=${base2}" >> .config || echo "#base2=" >> .config
    echo ${tracejada}
    read -rp "Nome da pasta da terceira base de dados (Opcional): " base3 || _abortar_setup_parcial
    base3="$(_sanitizar_valor_setup "$base3")"
    base3="${base3,,}"  # Normalizar para minusculo
    [[ -n "$base3" ]] && echo "base3=${base3}" >> .config || echo "#base3=" >> .config
    echo ${tracejada}
}
_setup_acesso_remoto() {
    echo "###      ( FACILITADOR DE ACESSO REMOTO )         ###"
    while true; do
        _ler_opcao "Ativar acesso facil (SSH) [S/N]: " acessossh || _encerrar_programa 1
        if [[ "${acessossh,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada invalida. Digite S ou N."
        fi
    done
    if [[ "${acessossh,,}" == "s" ]]; then
        echo "acessossh=s" >> .config
    else
        echo "acessossh=n" >> .config
    fi
    echo ${tracejada}
}
_setup_chave_acesso() {
    echo "###      ( FACILITADOR DE CHAVE DE ACESSO REMOTO )         ###"
    while true; do
        _ler_opcao "Permiti chaves de acesso [S/N]: " chavessh || _encerrar_programa 1
        if [[ "${chavessh,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada invalida. Digite S ou N."
        fi
    done
    if [[ "${chavessh,,}" == "s" ]]; then
        echo "chavessh=s" >> .config
    else
        echo "chavessh=n" >> .config
    fi
    echo "${tracejada}"
}

_setup_offline() {
    local opt
    echo "###      ( Tipo de acesso        )         ###"
    while true; do
        _ler_opcao "Servidor OFF [S/N]: " opt || _encerrar_programa 1
        if [[ "${opt,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada invalida. Digite S ou N."
        fi
    done
    if [[ "${opt,,}" == "s" ]]; then
        Offline="s"
        echo "Offline=s" >> .config
    else
        Offline="n"
        echo "Offline=n" >> .config
    fi
}
_setup_backup() {
    echo "${tracejada}"
    if [[ "${Offline,,}" == "s" ]]; then
        echo "###     ( Modo Offline Ativado )                ###"
        echo "###     Backup local sera criado na pasta do script ###"
        echo "###     O backup deve ser enviado manualmente para a SAV ###"
        echo "${tracejada}"

        # Define automaticamente o caminho do backup offline na memória e no arquivo
        enviabackup=""
        echo "enviabackup=" >> .config
        echo "Diretorio de backup offline sera determinado pelo sistema."

    else
        echo "###     ( Nome de pasta no servidor da SAV )                ###"
        echo "Informe o nome da pasta no servidor da SAV (somente o nome inicial do cliente)"
        echo "Exemplo: para o cliente 'Fulano', digite somente 'fulano'"
        echo "${tracejada}"

        read -rp "Nome do diretorio sem a /: " enviabackup || _abortar_setup_parcial

        # Monta o caminho completo esperado e salva
        enviabackup="$(_sanitizar_valor_setup "$enviabackup")"
        enviabackup="${enviabackup,,}"  # Normalizar para minusculo
        enviabackup="/cliente/${enviabackup}_jisam"
        echo "enviabackup=${enviabackup}" >> .config
    fi
}

_setup_empresa() {
    echo ${tracejada}
    echo "###     ( NOME DA empresa )                   ###"
    echo "###   Nao pode conter espacos entre os nomes    ###"
    echo ${tracejada}
    read -rp "Nome da Empresa (sem espacos): " empresa || _abortar_setup_parcial
    empresa="$(_sanitizar_valor_setup "$empresa")"
    empresa="${empresa^^}"  # Normalizar para maiusculo
    echo "empresa=${empresa}" >> .config
    # Configurar o acesso SSH so quando ele foi habilitado: o "_edit_setup"
    # ja faz essa checagem, e aqui ela faltava — o setup escrevia o
    # ~/.ssh/config e testava a conexao mesmo com "acessossh=n".
    #
    # O "|| true" evita que uma conexao SSH recusada aborte o script sob
    # "set -e": o .config ja foi gravado e o usuario so precisa ser avisado.
    if [[ "${acessossh,,}" == "s" ]]; then
        _configure_ssh_access || true
    fi
}


#---------- FUNCOES DE EDICAO ----------#

# Edita uma variavel de forma interativa
_editar_variavel() {
    local nome="${1:-}"
    # Guarda: ${!nome} com nome vazio e erro fatal no bash ("invalid indirect
    # expansion") — abortaria todo o setup; tratar cedo e retornar graciosamente.
    if [[ -z "$nome" ]]; then
        echo "Erro: nome da variavel nao informado"
        return 1
    fi
    local valor_atual="${!nome}"
    local tracejada="#-------------------------------------------------------------------#"
    local alterar opt novo_valor

    while true; do
        # O "|| break" trata o EOF: sem entrada, o "read" devolve 1 e o loop
        # giraria para sempre. Sem resposta, o valor atual e preservado.
        read -rp "Deseja alterar ${nome} (valor atual: ${valor_atual})? [s/N] " alterar || break
        if [[ "${alterar,,}" =~ ^[sn]$ ]]; then
            break
        else
            echo "Entrada inválida. Digite S ou N."
        fi
    done
    if [[ "${alterar,,}" == "s" ]]; then
        case "$nome" in
            "acessossh"|"chavessh"|"Offline")
                while true; do
                    read -rp "Novo valor [s/n]: " opt || true
                    if [[ "${opt,,}" =~ ^[sn]$ ]]; then
                        [[ "${opt,,}" == "s" ]] && printf -v "$nome" '%s' "s"
                        [[ "${opt,,}" == "n" ]] && printf -v "$nome" '%s' "n"
                        break
                    else
                        echo "Entrada inválida. Digite s ou n."
                    fi
                done
                ;;
            *)
                read -rp "Novo valor para ${nome}: " novo_valor || true
                novo_valor="$(_sanitizar_valor_setup "$novo_valor")"
                # Aplicar normalizacao de caso conforme a variavel
                case "$nome" in
                    "base"|"base2"|"base3"|"enviabackup")
                        novo_valor="${novo_valor,,}"  # Normalizar para minusculo
                        ;;
                    "empresa")
                        novo_valor="${novo_valor^^}"  # Normalizar para maiusculo
                        ;;
                esac
                printf -v "$nome" '%s' "$novo_valor"
                ;;
        esac
    fi
    echo "$tracejada"
}

# Recria os arquivos de configuracao
_recreate_config_files() {
    local tracejada="#-------------------------------------------------------------------#"
    echo "Recriando arquivos de configuracao..."

    # Chaves que o setup NAO gerencia (ex: "sistema=iscobol", "dbmaker=n")
    # sao preservadas: o arquivo e reescrito do zero, e sem esta copia elas
    # sumiriam do .config do cliente a cada edicao.
    local _extras=""
    local _linha _chave
    if [[ -f .config ]]; then
        while IFS= read -r _linha || [[ -n "$_linha" ]]; do
            [[ "$_linha" =~ ^[[:space:]]*# ]] && continue
            # O "BASH_REMATCH" e sobrescrito a cada regex: a chave e extraida
            # na MESMA expressao que valida a linha.
            [[ "$_linha" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]] || continue
            _chave="${BASH_REMATCH[1]}"
            # O "continue" DENTRO de um "case" nao pula o "while": no Bash ele
            # aplica ao proprio "case". Por isso o filtro e um "if".
            case "$_chave" in
                "verclass"|"acessossh"|"chavessh"|"Offline"|"enviabackup"|"empresa"|"base"|"base2"|"base3")
                    _chave=""
                    ;;
            esac
            [[ -z "$_chave" ]] && continue
            _extras+="${_linha}"$'\n'
        done < .config
    fi

    {
        echo "verclass=${verclass}"
        echo "acessossh=${acessossh}"
        echo "chavessh=${chavessh}"
        echo "Offline=${Offline}"
        echo "enviabackup=${enviabackup}"
        echo "empresa=${empresa}"
        echo "base=${base}"
        [[ -n "$base2" ]] && echo "base2=${base2}" || echo "#base2="
        [[ -n "$base3" ]] && echo "base3=${base3}" || echo "#base3="
        [[ -n "$_extras" ]] && printf '%s' "${_extras%$'\n'}"
    } > .config
    echo "$tracejada"
}

#---------- FUNCOES AUXILIARES ----------#
# Marcadores do bloco do servidor SAV dentro do ~/.ssh/config do usuario.
# Delimitam a unica parte do arquivo que o setup reescreve: todo o resto
# (os outros hosts configurados pelo administrador) e preservado.
_SAV_SSH_INICIO="# >>> SAV (setup) >>>"
_SAV_SSH_FIM="# <<< SAV (setup) <<<"

# Cria o atalho global do programa em /usr/local/bin/atualiza.
#
# O arquivo gerado precisa de shebang: sem ele, a execucao direta falha com
# ENOEXEC (o shell so fallback para /bin/sh quando o proprio shell chama).
# O caminho vai entre aspas com %q: um SCRIPT_DIR com espaco gerava um "cd"
# invalido. Os argumentos sao repassados com "$@", senao "atualiza --setup"
# seria engolido pelo atalho.
_criar_atalho_global() {
    local destino="${1:-/usr/local/bin/atualiza}"

    # Backup do atalho anterior: sobrescrever sem copia previa impede o
    # administrador de recuperar um atalho customized.
    if [[ -f "${destino}" ]]; then
        cp -p "${destino}" "${destino}.bkp" 2>/dev/null || true
    fi

    {
        printf '#!/usr/bin/env bash\n'
        printf '# Gerado automaticamente pelo setup do SISTEMA SAV.\n'
        printf 'cd %q || exit 1\n' "${SCRIPT_DIR}"
        printf 'exec ./atualiza.sh "$@"\n'
    } > "${destino}"

    chmod "${PERM_FILE_EXEC:-0755}" "${destino}"
    printf "%s\n" "Atalho ${destino} criado com sucesso."
}

# Configura acesso SSH facilitado
#===================================================================
# _configure_ssh_access - Versão FINAL com SSH no diretório padrão ~/.ssh
#===================================================================
#===================================================================
# _configure_ssh_access - Cria novo arquivo SSH config
#===================================================================
_configure_ssh_access() {
    local ip_server="${DEFAULT_IP_SERVER}"
    local porta_ssh="${DEFAULT_SSH_PORTA}"
    local user_ssh="${DEFAULT_SSH_USER}"
    local dir_ssh="${HOME}/.ssh"
    local arquivo_confg_ssh="${dir_ssh}/config"
    local base_caminho="${dir_ssh}/control"

    # Validacao das variaveis obrigatorias
    if [[ -z "${ip_server}" ]]; then
        echo "Erro: Variavel DEFAULT_IP_SERVER nao foi definida."
        return 1
    fi

    # Cria os diretorios padrao
    mkdir -p "${dir_ssh}" "${base_caminho}"
    chmod 0700 "${dir_ssh}"           # ~/.ssh deve ser 0700 para o OpenSSH aceitar as chaves
    chmod "${PERM_DIR_SECURE}" "${base_caminho}"

    # ====================== ATUALIZA ~/.ssh/config ======================
    #
    # O ~/.ssh/config do usuario NAO e sobrescrito: as entradas existentes
    # (outros hosts, IdentityFile, ProxyJump...) sao preservadas e apenas o
    # bloco do servidor SAV e (re)escrito. Antes, o setup destruia o config
    # inteiro e a configuracao de SSH do administrador se perdia sem aviso.
    #
    # A mesclagem e feita no proprio arquivo, e nao via "Include": a diretiva
    # Include so existe no OpenSSH 5.9 (2011) e o alvo ainda roda Ubuntu 10.04
    # (OpenSSH 5.3).
    echo "Criando configuracao SSH em ${arquivo_confg_ssh}..."

    # Backup do config anterior do usuario, uma unica vez: o conteudo
    # original fica preservado em .config.sav.bak.
    if [[ -f "${arquivo_confg_ssh}" && ! -f "${arquivo_confg_ssh}.sav.bak" ]]; then
        cp -p "${arquivo_confg_ssh}" "${arquivo_confg_ssh}.sav.bak" 2>/dev/null || true
        echo "Copia do ~/.ssh/config original salva em ${arquivo_confg_ssh}.sav.bak"
    fi

    local _linha _em_bloco=0 _parte=""
    if [[ -f "${arquivo_confg_ssh}" ]]; then
        while IFS= read -r _linha || [[ -n "$_linha" ]]; do
            # Reconhece o bloco SAV de uma execucao anterior: ele e descartado
            # e reescrito abaixo, para nao duplicar o Host sav_servidor.
            if [[ "${_linha}" == "${_SAV_SSH_INICIO}" ]]; then
                _em_bloco=1
                continue
            fi
            if [[ "${_linha}" == "${_SAV_SSH_FIM}" ]]; then
                _em_bloco=0
                continue
            fi
            [[ "${_em_bloco}" -eq 1 ]] && continue
            _parte+="${_linha}"$'\n'
        done < "${arquivo_confg_ssh}"
    fi

    {
        printf '%s' "${_parte}"
        cat << EOF
${_SAV_SSH_INICIO}
# ================================================
# Configuracao SAV - Gerada automaticamente
# Data: $(date '+%d/%m/%Y %H:%M:%S')
# ================================================

Host sav_servidor
    HostName ${ip_server}
    Port ${porta_ssh}
    User ${user_ssh}
    ControlMaster auto
    ControlPath ${base_caminho}/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval ${SSH_ALIVE_INTERVAL}
    ServerAliveCountMax ${SSH_ALIVE_COUNT}
    ConnectTimeout ${SSH_TIMEOUT}
${_SAV_SSH_FIM}
EOF
    } > "${arquivo_confg_ssh}"

    chmod "${PERM_FILE_PRIVATE}" "${arquivo_confg_ssh}"
    echo "Configuracao SSH atualizada com sucesso em ${arquivo_confg_ssh}"

    # ====================== TESTE DE CONEXAO ======================
    echo
    echo "Testando conexao com o servidor SAV (${ip_server})..."

    if ssh -o BatchMode=yes sav_servidor exit 2>/dev/null; then
        echo "Conexao SSH estabelecida com sucesso!"
        return 0
    fi

    # Primeira conexao - modo interativo
    echo "Primeira conexao: confirme a identidade do servidor abaixo."
    echo "   (Digite 'yes' quando aparecer a mensagem de fingerprint)"
    echo

    if ssh sav_servidor exit; then
        echo "Servidor autenticado e fingerprint adicionado ao known_hosts."
        return 0
    else
        echo "Erro: nao foi possivel conectar ao servidor."
        echo "   Verifique:"
        echo "     - Porta ${porta_ssh} liberada"
        echo "     - Usuario '${user_ssh}' existe no servidor remoto"
        echo "     - Firewall permite a conexao"
        return 1
    fi
}

#---------- PONTO DE ENTRADA PRINCIPAL ----------#

# Funcao principal que direciona para o modo correto
main() {

# Diretorio do script (compativel com chamada direta ou via atualiza.sh)
# Quando chamado diretamente de /binarios, sobe um nivel para o diretorio do atualiza.sh
    if [[ -z "${SCRIPT_DIR:-}" ]]; then
        local _self_dir
        _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ "$(basename "${_self_dir}")" == "binarios" ]]; then
            SCRIPT_DIR="$(dirname "${_self_dir}")"
        else
            SCRIPT_DIR="${_self_dir}"
        fi
        unset _self_dir
    fi

# Diretorios dos modulos e configuracoes
LIBS_DIR="${LIBS_DIR:-${SCRIPT_DIR}/binarios}"
CFG_DIR="${CFG_DIR:-${SCRIPT_DIR}/configuracoes}"

cd "${SCRIPT_DIR}" || _encerrar_programa 1

# Verifica se o diretorio processos existe
    if [[ ! -d "${LIBS_DIR}" ]]; then
        echo "ERRO: Diretorio ${LIBS_DIR} nao encontrado."
        _encerrar_programa 1
    fi

# Verifica se o diretorio configuracoes existe
    if [[ ! -d "${CFG_DIR}" ]]; then
        echo "ERRO: Diretorio ${CFG_DIR} nao encontrado."
        _encerrar_programa 1
    fi

    # Carregar modulos necessarios
    if [[ -f "${LIBS_DIR}/utils.sh" ]]; then
        "." "${LIBS_DIR}/utils.sh"
    else
        echo "ERRO: utils.sh nao encontrado em ${LIBS_DIR}"
        _encerrar_programa 1
    fi

    # Verificar modo de operacao
    if [[ "${1:-}" == "--edit" ]]; then
        _edit_setup
    else
        # Verificar se os arquivos de configuracao ja existem

        if [[ -f "${CFG_DIR}/.config" ]]; then
            # Ver o comentario em _initial_setup: "clear" pode falhar (TERM
            # ausente) e nao pode derrubar o setup sob "set -e".
            clear 2>/dev/null || true
            echo "Arquivos de configuracao ja existem."
            local choice
            while true; do
                # O "|| break" evita o loop infinito quando a entrada acaba
                # (EOF): sem resposta, a operacao e cancelada.
                read -rp "Deseja sobrescrevê-los com a configuracao inicial? [s/N]: " choice || break
                if [[ "${choice,,}" =~ ^[sn]$ ]]; then
                    break
                else
                    echo "Entrada inválida. Digite S ou N."
                fi
            done
            if [[ "${choice,,}" == "s" ]]; then
                cd "${CFG_DIR}" || _encerrar_programa 1
                _initial_setup
            else
                echo "Operacao cancelada. Use './atualiza.sh --setup --edit' para modificar."
                _encerrar_programa 0
            fi
        else
            mkdir -p "${CFG_DIR}"
            cd "${CFG_DIR}" || _encerrar_programa 1
            _initial_setup
        fi
    fi
}

# Executar a funcao principal.
#
# O guard permite que o modulo seja "source"ado por uma suite de testes sem
# disparar o fluxo interativo (o mesmo padrao usado em constantes.sh). Quando
# executado, "$0" e o proprio script e o fluxo roda normal.
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
    main "$@"
fi
