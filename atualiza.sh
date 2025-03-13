#!/usr/bin/env bash 
#set -uo pipefail
#                                                                                                                      #
#    ________  __      ________  ___________  _______  ___      ___       __            ________     __  ___      ___  #
#   /"       )|" \    /"       )("     _   ")/"     "||"  \    /"  |     /""\          /"       )   /""\|"  \    /"  | #
#  (:   \___/ ||  |  (:   \___/  )__/  \\__/(: ______) \   \  //   |    /    \        (:   \___/   /    \\   \  //  /  #
#   \___  \   |:  |   \___  \       \\_ /    \/    |   /\\  \/.    |   /' /\  \        \___  \    /' /\  \\\  \/. ./   #
#    __/  \\  |.  |    __/  \\      |.  |    // ___)_ |: \.        |  //  __'  \        __/  \\  //  __'  \\.    //    #
#   /" \   :) /\  |\  /" \   :)     \:  |   (:      "||.  \    /:  | /   /  \\  \      /" \   :)/   /  \\  \\\   /     #
#  (_______/ (__\_|_)(_______/       \__|    \_______)|___|\__/|___|(___/    \___)    (_______/(___/    \___)\__/      #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#                   #
##  Rotina para atualizar os programas avulsos e bibliotecas da SAV                                                    #
##  Feito por: Luiz Augusto   email luizaugusto@sav.com.br                                                             #
##  Versao do atualiza.sh                                                                                              #
UPDATE="13/03/2025-00"                                                                                                 #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#                   #
# Arquivos de trabalho:                                                                                                #
# "atualizac"  = Contem a configuracao referente a empresa                                                             #
# "atualizap"  = Configuracao do parametro do sistema                                                                  #
# "atualizaj"  = Lista de arquivos principais para dar rebuild.                                                        #
# "atualizat   = Lista de arquivos temporarios a ser excluidos da pasta de dados.                                      #
#               Sao zipados em /backup/Temps-dia-mes-ano-horario.zip                                                   #
# "setup.sh"   = Configurador  para criar os arquivos atualizac e atualizap                                            #
# Menus                                                                                                                #
# 1 - Atualizacao de Programas                                                                                         #
# 2 - Atualizacao de Biblioteca                                                                                        #
# 3- Versao do Iscobol                                                                                                 #
# 4- Versao do Linux                                                                                                   #
# 5- Ferramentas                                                                                                       #
#                                                                                                                      #
#      1 - Atualizacao de Programas                                                                                    #
#            1.1 - ON-Line                                                                                             #
#      Acessa o servidor da SAV via rsync com o usuario ATUALIZA                                                       #
#      Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                                       #
#      com o nome "Nome do programa-anterior.zip" descompacta o novo no diretorio                                      #
#      dos programa e salva o a atualizacao na pasta ?/sav/tmp/progs.                                                  #
#            1.2 - OFF-Line                                                                                            #
#      Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.                                  #
#      O processo de atualizacao e identico ao passo acima.                                                            #
#            1.3  Voltar programa Atualizado                                                                           #
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com o nome de ("programa"-anterior.zip)             #
#      na pasta dos programas.                                                                                         #
#                                                                                                                      #
#      2 - Atualizacao de Biblioteca                                                                                   #
#            2.1 - Atualizacao do Transpc                                                                              #
#      Atualiza a biblioteca que esta no diretorio /u/varejo/trans_pc/ do servidor da SAV.                             #
#      Faz um backup de todos os programas que esta em uso e salva na pasta ?/sav/tmp/olds                             #
#      com o nome "backup-(versao Informada).zip" descompacta os novos no diretorio                                    #
#      dos programas e salva os zips da biblioteca na pasta ?/sav/tmp/biblioteca mudando a                             #
#      extensao de .zip para .bkp.                                                                                     #
#            2.2 - Atualizacao do Savatu                                                                               #
#      Atualiza a biblioteca que esta no diretorio /home/savatu/biblioteca/temp/(diretorio                             #
#      conforme  sistema que esta sendo usado.                                                                         #
#      Mesmo procedimento acima.                                                                                       #
#            2.3 - Atualizacao9 OFF-Line                                                                               #
#      Atualiza a biblioteca que deve estar salva no diretorio ?/sav/tmp                                               #
#      Mesmo procedimento acima.                                                                                       #
#            2.4 - Voltar antes da Biblioteca                                                                          #
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backup-versao da biblioteca".zip)        #
#      na pasta dos programas.                                                                                         #
#                                                                                                                      #
#      3 - Versao do Iscobol                                                                                           #
#            Verifica qual a versao do iscobol que esta sendo usada.                                                   #
#                                                                                                                      #
#      4 - Versao do Linux                                                                                             #
#            Verifica qual o Linux em uso.                                                                             #
#                                                                                                                      #
#      5 - Ferramentas                                                                                                 #
#           5.1 - Limpar Temporarios                                                                                   #
#               5.1.1 - Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup                      #
#                       com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                                 #
#               5.1.2 - Adiciona arquivos no "ATUALIZAT"                                                               #
#                                                                                                                      #
#           5.2 - Recuperar arquivos                                                                                   #
#               5.2.1 - Um arquivo ou Todos                                                                            #
#                   Opcao pede para informa um arquivo especifico, somente o nome sem a extensao                       #
#                   ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com as extens es,         #
#                   "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"                                                    #
#                                                                                                                      #
#               5.2.2 - Arquivos Principais                                                                            #
#                   Roda o Jtuil somente nos arquivos que estao na lista "atualizaj"                                   #
#                                                                                                                      #
#           5.3 - Backup da base de dados                                                                              #
#               5.3.1 - Faz um backup da pasta de dados  e tem a opcao de enviar para a SAV                            #
#               5.3.2 - Restaura Backup da base de dados                                                               #
#               5.3.3 - Enviar Backup selecionado                                                                      #
#                                                                                                                      #
#           5.4 - Envia e Recebe Arquivos "Avulsos"                                                                    #
#               5.4.1 - Enviar arquivo(s)                                                                              #
#               5.4.2 - Receber arquivo(s)                                                                             #
#                                                                                                                      #
#           5.5 - Expurgador de arquivos                                                                               #
#               Excluir, zips e bkps com mais de 30 dias processado dos diretorios:                                    #
#                /backup, /olds /progs e /logs                                                                         #
#                                                                                                                      #
#           5.6 - Parametros                                                                                           #
#                 Variaves e caminhos necessarios para o funcionamento do atualiza.sh                                  #
#                                                                                                                      #
#           5.7 - Update                                                                                               #
#               Atualizacao do programa atualiza.sh                                                                    #
#                                                                                                                      #
#           5.8 - Lembretes                                                                                            #
#                                                                                                                      #
#----------------------------------------------------------------------------------------------------------------------#

#Zerando variaves utilizadas 
# resetando: Funcao que zera todas as variaveis utilizadas pelo programa, para
#            evitar que elas sejam utilizadas por outros programas.
#            Também fecha o programa atualiza.sh.
_resetando() {
# Arrays para agrupar variáveis
declare -a cores=(RED GREEN YELLOW BLUE PURPLE CYAN NORM)
declare -a caminhos_base=(BASE1 BASE2 BASE3 tools DIR OLDS PROGS BACKUP destino pasta base base2 base3 logs exec class telas xml olds progs backup sistema TEMPS UMADATA DIRB ENVIABACK ENVBASE SERACESOFF E_EXEC T_TELAS X_XML)
declare -a biblioteca=(SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4)
declare -a comandos=(cmd_unzip cmd_zip cmd_find cmd_who)
declare -a outros=(NOMEPROG PEDARQ prog PORTA USUARIO IPSERVER DESTINO2 VBACKUP ARQUIVO VERSAO ARQUIVO2 VERSAOANT INI SAVISC DEFAULT_UNZIP DEFAULT_ZIP DEFAULT_FIND DEFAULT_WHO DEFAULT_VERSAO VERSAO DEFAULT_ARQUIVO DEFAULT_PEDARQ DEFAULT_PROG DEFAULT_PORTA DEFAULT_USUARIO DEFAULT_IPSERVER DEFAULT_DESTINO2 UPDATE DEFAULT_PEDARQ jut JUTIL ISCCLIENT ISCCLIENTT SAVISCC)

# Remove as variáveis nos arrays
unset -v "${cores[@]}"
unset -v "${caminhos_base[@]}"
unset -v "${biblioteca[@]}"
unset -v "${comandos[@]}"
unset -v "${outros[@]}"
tput sgr0; exit 1

}
#-VARIAVEIS do sistema ----------------------------------------------------------------------------#
#-Variaveis de configuracao do sistema ---------------------------------------------------------#
# Variaveis de configuracao do sistema que podem ser definidas pelo usuario.
# As variaveis com o prefixo "destino" sao usadas para definir o caminho
# dos diretorios que serao usados pelo programa.
destino="${destino:-}" # Caminho do diretorio raiz do programa.
pasta="${pasta:-}" # Caminho do diretorio onde estao os executaveis.
base="${base:-}" # Caminho do diretorio da base de dados.
base2="${base2:-}" # Caminho do diretorio da segunda base de dados.
base3="${base3:-}" # Caminho do diretorio da terceira base de dados.
logs="${logs:-}" # Caminho do diretorio dos arquivos de log.
exec="${exec:-}" # Caminho do diretorio dos executaveis.
class="${class:-}" # Caminho do diretorio das classes.
mclass="${mclass:-}" # Caminho do diretorio das classes da mclasse.
telas="${telas:-}" # Caminho do diretorio das telas.
xml="${xml:-}" # Caminho do diretorio dos arquivos xml.
olds="${olds:-}" # Caminho do diretorio dos arquivos de backup.
progs="${progs:-}" # Caminho do diretorio dos programas.
backup="${backup:-}" # Caminho do diretorio de backup.
sistema="${sistema:-}" # Tipo de sistema que esta sendo usado (iscobol ou isam).
SAVATU="${SAVATU:-}" # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU1="${SAVATU1:-}" # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU2="${SAVATU2:-}" # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU3="${SAVATU3:-}" # Caminho do diretorio da biblioteca do servidor da SAV.
SAVATU4="${SAVATU4:-}" # Caminho do diretorio da biblioteca do servidor da SAV.
ENVIABACK="${ENVIABACK:-}" # Variavel que define o caminho para onde sera enviado o backup.
VERSAO="${VERSAO:-}" # Variavel que define a versao do programa.
INI="${INI:-}" # Variavel que define o caminho do arquivo de configuracao do sistema.
SERACESOFF="${SERACESOFF:-}" # Variavel que define o caminho do diretorio do servidor off.
VERSAOANT="${VERSAOANT:-}" # Variavel que define a versao do programa anterior.
cmd_unzip="${cmd_unzip:-}" # Comando para descompactar arquivos.
cmd_zip="${cmd_zip:-}" # Comando para compactar arquivos.
cmd_find="${cmd_find:-}" # Comando para buscar arquivos.
cmd_who="${cmd_who:-}" # Comando para saber quem esta logado no sistema.
VBACKUP="${VBACKUP:-}" # Variavel que define se sera realizado backup.
ARQUIVO="${ARQUIVO:-}" # Variavel que define o nome do arquivo a ser baixado.
PEDARQ="${PEDARQ:-}" # Variavel que define se sera realizado o pedido de arquivos.
prog="${prog:-}" # Variavel que define o nome do programa a ser baixado.
PORTA="${PORTA:-}" # Variavel que define a porta a ser usada para rsync.
USUARIO="${USUARIO:-}" # Variavel que define o usuario a ser usado para rsync.
IPSERVER="${IPSERVER:-}" # Variavel que define o ip do servidor da SAV.
DESTINO2="${DESTINO2:-}" # Variavel que define o caminho do diretorio da biblioteca do servidor da SAV.

#-Variaveis de cores-------------------------------------------------------------------------------#
# TERM=xterm-256color
# Comando para resetar cores
tput sgr0 # Comando para limpar a tela
tput clear # Comando para tornar a fonte em negrito
tput bold # Comando para definir a cor da fonte como branco
tput setaf 7 # Variaveis de cores

RED=$(tput bold)$(tput setaf 1) # Cor vermelha
GREEN=$(tput bold)$(tput setaf 2) # Cor verde
YELLOW=$(tput bold)$(tput setaf 3) # Cor amarela
BLUE=$(tput bold)$(tput setaf 4) # Cor azul
PURPLE=$(tput bold)$(tput setaf 5)  # Cor roxa
CYAN=$(tput bold)$(tput setaf 6) # Cor ciano
NORM=$(tput bold)$(tput setaf 7) # Cor normal
COLUMNS=$(tput cols) # Numero de colunas da tela
#--------------------------------------------------------------------------------------------------#
# Funcao para checar se o zip esta instalado
# Checa se os programas necessarios para o atualiza.sh estao instalados no sistema. 
# Se o programa nao for encontrado, exibe uma mensagem de erro e sai do programa.
_check_instalado() {
#####
local app
local missing=""
    for app in zip unzip rsync wget; do
        if ! command -v "$app" &>/dev/null; then
            missing="$missing $app"
            printf "\n"
            printf "%*s""${RED}" ;printf "%*s\n" $(((${#Z1}+COLUMNS)/2)) "${Z1}" ;printf "%*s""${NORM}"
            printf "%*s""${YELLOW}" " O programa nao foi encontrado ->> " "${NORM}" "${app}"
            printf "\n"
            case "$prog" in
                zip|unzip) echo "  Sugestao: Instale o zip unzip." ;;
                rsync)     echo "  Sugestao: Instale o rsync." ;;
                wget)      echo "  Sugestao: Instale o wget." ;;
            esac
        fi
    done
    if [ -n "$missing" ]; then
        _mensagec "${YELLOW}" "Instale os programas ausentes ($missing) e tente novamente."
        exit 1
    fi
}

# Checando se o zip esta na base
_check_instalado

#-Comandos#----------------------------------------------------------------------------------------#
# Checando se os comandos estao disponiveis
# Caso o comando nao esteja disponivel, sera utilizado o valor padrao
# Caso o valor padrao nao esteja configurado, exibe uma mensagem de erro e sai do programa.

# Comando para descompactar arquivos .zip
DEFAULT_UNZIP="unzip"
if [[ -z "${cmd_unzip}" ]]; then
    if [[ -n "${DEFAULT_UNZIP}" ]]; then
        cmd_unzip="${DEFAULT_UNZIP}"
    else
        printf "Erro: Variavel de ambiente cmd_unzip nao esta configurada.\n"
        exit 1
    fi
fi

# Comando para compactar arquivos em .zip
DEFAULT_ZIP="zip"
if [[ -z "${cmd_zip}" ]]; then
    if [[ -n "${DEFAULT_ZIP}" ]]; then
        cmd_zip="${DEFAULT_ZIP}"
    else
        printf "Erro: Variavel de ambiente cmd_zip nao esta configurada.\n"
        exit 1
    fi
fi

# Comando para localizar arquivos
DEFAULT_FIND="find"
if [[ -z "${cmd_find}" ]]; then
    if [[ -n "${DEFAULT_FIND}" ]]; then
        cmd_find="${DEFAULT_FIND}"
    else
        printf "Erro: Variavel de ambiente cmd_find nao esta configurada.\n"
        exit 1
    fi
fi
# Comando para verificar de usuario 
DEFAULT_WHO="who"
if [[ -z "${cmd_who}" ]]; then
    if [[ -n "${DEFAULT_WHO}" ]]; then
        cmd_who="${DEFAULT_WHO}"
    else
        printf "Erro: Variavel de ambiente cmd_who nao esta configurada.\n"
        exit 1
    fi
fi

#-Lista de mensagens #-----------------------------------------------------------------------------#
### Mensagens em AMARELO
# Mensagens em AMARELO
M01="Compactando os arquivos Anteriores"
M03="Volta do(s) Programa(s) Concluida(s)"
#M04="Volta do(s) Arquivo(s) Concluida"
M05="Sistema nao e IsCOBOL"
M06="Sera criado mais um backup para o periodo"
M08="Opcao Invalida"
M09="O programa tem que estar no diretorio"
M12="Arquivo(s) recuperado(s)..."
M13="De *.zip para *.bkp"
M14="Criando Backup.."
M16="Backup Concluido!"
M17="Atualizacao Completa com sucesso!"
M18="Arquivo(s) recuperado(s)..."
M20="Alterando a extensao da atualizacao"
M24=".. BACKUP do programa efetuado .."
M25="... Voltando versao anterior ..."
M26="... Agora, ATUALIZANDO os programas ..."
M27=" .. Backup Completo .."
M28="Arquivo encontrado no diretorio"
M29="Informe a senha para o usuario do rsync:"
M33="Voltando Backup anterior  ..."
M35="Deseja voltar todos os ARQUIVOS do Backup ? [N/s]:"
M36="<< ... Pressione qualquer tecla para continuar ... >>"
M37="Deseja informar mais algum programa para ser atualizado? [S/n]"
M38="Deseja continuar a atualizacao? [n/S]:"
M39="Continuando a atualizacao...:"
M40="      Deseja enviar para o servidor da SAV ? [N/s]:"
M41="         Informe para qual diretorio no servidor: "
M42="         1- Informe nome BACKUP: "
#M43=" "
M44="Acesso externo do servidor em modo OFF"
M45="Alterando a extensao da atualizacao"
M46="De *-anterior.zip para *.zip"
# MA1="O backup \"""$VBACKUP""\""
MA2="         1- Informe apos qual versao da BIBLIOTECA: "

# Mensagens em VERMELHO
M45="Backup nao encontrado no diretorio ou nao foi informado os dados"
M46="Backup da Biblioteca nao encontrado no diretorio"
#M47="Backup Abortado!"
M48="Atualizacao nao encontrado ou incompleta."
M49="Arquivo nao encontrado no diretorio"
M51="Verificando e/ou excluido arquivos com mais de 30 dias criado."
M52="Informe de qual o Backup que deseja enviar. Somente informe a data"
M53="Informe de qual o Backup que deseja voltara o(s) arquivo(s)."
M55="Informe versao a da Biblioteca a ser atualizada: "
M56="*+* < <- Versao a ser atualizada nao foi informada: -> > *+*"
M57="Informe somente o numeral da versao : "
M59="Informe o nome do programa a ser atualizado:"
#M60="Faltou informou o nome do programa a ser atualizado ou esta em minusculo"
#M61="Informe o nome do programa a ser desatualizado:"
M62="Informe a ultima versao que foi feita a atualizacao da biblioteca."
M64=" Informe o nome do arquivo ser recuperado OU enter para todos os arquivos:"
M65="Recuperado todos os arquivos:"
M66="Voce nao informou o nome do arquivo em minusculo"
M68="Enviar backup para a SAV."
M69="Voce nao informou o nome do diretorio a ser enviado, saindo..."
M70="* * * < < Nome do Backup nao foi informada > > * * *"
M71="ERRO: Voce informou o nome do arquivo em minusculo ou em branco "
M72="Informe o(s) arquivo(s) que deseja enviar."
M73="Informe o(s) arquivo(s) que deseja receber."
M74="* * * < < Nome do Arquivo nao foi informada > > * * *"
M75="Informe o tipo de compilacao (1 - Normal, 2 - Depuracao): "

# Mensagens em CYAN
M81="..Encontrado o diretorio do sistema .."

# Mensagens em VERDE
M91="Atualizacao concluida com sucesso!"
M92="ao termino da atualizacao entrar novamente"
M93"Atualização offline concluída!"
#-Centro da tela-----------------------------------------------------------------------------------#
# _meiodatela ()
# 
# Limpa a tela e posiciona o cursor no meio da tela.
# 
# O printf "\033c" limpa a tela, e o "\033[10;10H" posiciona o
# cursor na linha 10, coluna 10.
#
_meiodatela() {
    printf "\033c\033[10;10H\n"
}

#-Mensagem centralizada----------------------------------------------------------------------------#
# _mensagec (string, string)
# 
# Exibe uma mensagem centralizada na tela, com a cor de fundo e o texto
# informados como par metro.
# 
# Par metros:
#   $1   - Cor a ser usada como fundo, no formato ANSI. Ex.: "\033[32m"
#   $2   - Texto a ser exibido na tela.

_mensagec() {
    local CCC="${1}"
    local MXX="${2}"
    printf "%*s""${CCC}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "${MXX}" ;printf "%*s""${NORM}"
}

# _mensaged (string, string)
# 
# Exibe uma mensagem alinhada à direita na tela, com a cor de fundo e o texto
# informados como par metro.
# 
# Par metros:
#   $1   - Cor a ser usada como fundo, no formato ANSI. Ex.: "\033[32m"
#   $2   - Texto a ser exibido na tela.
_mensaged() {
local COR="${1}"
local mensagem="${2}"
# Obtém a largura do terminal
largura_terminal=$(tput cols)
# Calcula a posição inicial para imprimir a mensagem à direita
largura_mensagem=${#mensagem}
posicao_inicio=$((largura_terminal - largura_mensagem))

# Imprime a mensagem alinhada à direita
printf "%*s""${COR}" ;printf "%${posicao_inicio}s%s\n" "" "$mensagem" ;printf "%*s""${NORM}"
}
#-Funcao de sleep----------------------------------------------------------------------------------#
# Esta função pausa a execução por um número especificado de segundos.
# A duração é determinada pelo argumento passado para a função.
# Ele usa o comando `read` com uma opção de tempo limite para obter o efeito de suspensão.
# Exemplo de uso:
# _read_sleep 1   # Pausa por 1 segundo
# _read_sleep 0.2 # Pausas por 2 segundos
_read_sleep() {
# Usage: _read_sleep 1
#        _read_sleep 0.2
    if [[ -z "${1}" ]]; then
        printf "Erro: Nenhum argumento foi passado para a fun o _read_sleep.\n"
        return 1
    fi

    if ! [[ "${1}" =~ ^[0-9.]+$ ]]; then
        printf "Erro: O argumento passado para a fun o _read_sleep nao e um numero.\n"
        return 1
    fi

    read -rt "${1}" <> <(:) || :
}

#-Funcao teclar qualquer tecla---------------------------------------------------------------------#
#-Exibe um aviso centralizado para pressionar qualquer tecla e aguarda por 15 segundos para o
#-usuario pressionar uma tecla. Ap s o tempo limite expirar, limpa a tela e volta para o menu
#-principal.
_press() {
    printf "%*s""${YELLOW}" ;printf "%*s\n" $(((${#M36}+COLUMNS)/2)) "${M36}" ;printf "%*s""${NORM}"
    read -rt 15 || :
    tput sgr0
}

#-Escolha qual o tipo de traco---------------------------------------------------------------------#
# Esta função imprime uma linha de caracteres na largura do terminal.
# O caractere usado para a linha pode ser especificado como argumento; 
# caso contrário, o padrão é um hífen ('-'). A linha é centralizada com base
# na largura atual do terminal.
_linha() {
    local Traco=${1:-'-'}
    local CCC="${2}"
# quantidade de tracos por linha
    printf -v Espacos "%$(tput cols)s""" 
    linhas=${Espacos// /$Traco}
	printf "%*s""${CCC}" ;printf "%*s\n" $(((${#linhas}+COLUMNS)/2)) "$linhas" ;printf "%*s""${NORM}"
}

#   Opção Invalida
#-Opcao Invalida-----------------------------------------------------------------------------#
# Esta funcao chamada quando o usuario digita uma opcao   invalida.
# Ela imprime um aviso centralizado na tela, com a cor definida como variavel global.
# A funcao e chamada sem nenhuma entrada.
_opinvalida() {  
    _linha 
    _mensagec "${RED}" "${M08}"
    _linha  
}      

#-Variavel para identificar -----------------------------------------------------------------------#
## Inicializa a variável DEFAULT_VERSAO como uma string vazia
DEFAULT_VERSAO=""
# Verifica se a variável VERSAO está vazia, se sim, atribui o valor de DEFAULT_VERSAO
if [[ -z "${VERSAO}" ]]; then
    VERSAO="${DEFAULT_VERSAO}"
fi

#### configurar as variaveis em ambiente no arquivo abaixo:    ####
#- TESTE de CONFIGURACOES--------------------------------------------------------------------------#
# Checando se os arquivos de configuracao estao configurados corretamente
if [[ ! -e "atualizac" ]]; then
    M58="ERRO. Arquivo atualizac, Nao existe no diretorio, usar ./setup.sh, ou não esta na pasta TOOLS."
    _linha 
    _mensagec "${RED}" "${M58}"
    _linha 
    exit 1
fi

if [[ ! -r "atualizac" ]]; then
    printf "ERRO. Arquivo atualizac, Sem acesso de leitura.\n"
    exit 1
fi
# Arquivo de configuracao para a empresa
if [[ -f "atualizac" ]]; then
    "." ./atualizac
else
    printf "ERRO. Arquivo atualizac, Nao existe no diretorio.\n"
    exit 1
fi


if [[ ! -e "atualizap" ]]; then
    M58="ERRO. Arquivo atualizap, Nao existe no diretorio, usar ./setup.sh, ou não esta na pasta TOOLS."
    _linha 
    _mensagec "${RED}" "${M58}"
    _linha     
    exit 1
fi

if [[ ! -r "atualizap" ]]; then
    printf "ERRO. Arquivo atualizap, Sem acesso de leitura.\n"
    exit 1
fi
# Arquivo de configuracao para o atualiza.sh
if [[ -f "atualizap" ]]; then
    "." ./atualizap
else
    printf "ERRO. Arquivo atualizap, Nao existe no diretorio.\n"
    exit 1
fi
cd ..
raiz="/"
destino="${raiz}${destino}"

TOOLS="${destino}${pasta}"
if [[ -n "${TOOLS}" ]] && [[ -d "${TOOLS}" ]]; then
    # Diretorio da destino encontrado
    _mensagec "${CYAN}" "${M81}"
cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }  

    OLDS="${TOOLS}${olds}"
    # Cria diretório olds se não existir
    if [[ ! -d "${OLDS}" ]]; then
        mkdir -p "${OLDS}" || { printf "Erro ao criar %s" "${OLDS}"; exit 1; }
    fi
    PROGS="${TOOLS}/progs"
    # Cria diretório progs se não existir
    if [[ ! -d "${PROGS}" ]]; then
        mkdir -p "${PROGS}"
    fi
    
    LOGS="${TOOLS}/logs"
    # Cria diretório logs se não existir
    if [[ ! -d "${LOGS}" ]]; then
        mkdir -p "${LOGS}"
    fi
    
    BACKUP="${TOOLS}/backup"
    # Cria diretório backups se não existir
    if [[ ! -d "${BACKUP}" ]]; then
        mkdir -p "${BACKUP}"
    fi
    
    ENVIA="${TOOLS}/envia"
    # Cria diretório envia se não existir
    if [[ ! -d "${ENVIA}" ]]; then
        mkdir -p "${ENVIA}"
    fi
    
    RECEBE="${TOOLS}/recebe"
    # Cria diretório recebe se não existir
    if [[ ! -d "${RECEBE}" ]]; then
        mkdir -p "${RECEBE}"
    fi
else
    M44="Nao foi encontrado o diretorio ""${TOOLS}"
    _linha "*"
    _mensagec "${RED}" "${M44}"
    _linha "*"
    _read_sleep 2
    exit
fi



# Define o caminho padrão para SAVISCC usando a variável destino
SAVISCC="${destino}/sav/savisc/iscobol/bin/"
# Se SAVISCC não estiver vazia, atribui seu valor para SAVISC
if [[ -n "${SAVISCC}" ]]; then
    SAVISC="${SAVISCC}"
fi

# Inicializa a variável JUTILL com o valor "jutil"
JUTILL="jutil"
# Se JUTILL não estiver vazia, atribui seu valor para JUTIL
if [[ -n "${JUTILL}" ]]; then
    JUTIL="${JUTILL}"
fi

# Inicializa a variável ISCCLIENTT com o valor "iscclient"
ISCCLIENTT="iscclient"
# Se ISCCLIENTT não estiver vazia, atribui seu valor para ISCCLIENT
if [[ -n "${ISCCLIENTT}" ]]; then
    ISCCLIENT="${ISCCLIENTT}"
fi
# DEFAULT_ARQUIVO - Variavel para armazenar o nome do arquivo de backup
DEFAULT_ARQUIVO=""
if [[ -z "${ARQUIVO}" ]]; then
    ARQUIVO="${DEFAULT_ARQUIVO}"
fi

# DEFAULT_PEDARQ - Variavel para armazenar o nome do arquivo de backup dos pedidos
DEFAULT_PEDARQ=""
if [[ -z "${PEDARQ}" ]]; then
    PEDARQ="${DEFAULT_PEDARQ}"
fi

# DEFAULT_PROG - Variavel para armazenar o nome do programa a ser atualizado
DEFAULT_PROG=""
if [[ -z "${prog}" ]]; then
    prog="${DEFAULT_PROG}"
fi

# pasta - Diretorio do Tools
if [[ -n "${pasta}" ]]; then
    _mensagec "${CYAN}" "${M81}"
else
    M80="Diretorio do Tools, nao esta configurado"
    _linha
    _mensagec "${RED}" "${M80}"
    _linha
    exit
fi

# base - Diretorio da Base de dados principal
if [[ -n "${base}" ]]; then
    _mensagec "${CYAN}" "${M81}"
else
    M80="Diretorio da Base de dados, nao esta configurado ou nao esta na pasta correta"
    _linha
    _mensagec "${RED}" "${M80}"
    _linha
    exit
fi 

# exec - Diretorio dos programas
if [[ -n "${exec}" ]]; then
    _mensagec "${CYAN}" "${M81}"
else
    printf "Diretorio dos programas, nao esta configurado  \n"
    exit
fi    

# telas - Diretorio das Telas
if [[ -n "${telas}" ]]; then
    _mensagec "${CYAN}" "${M81}"
else
    printf "Diretorio das Telas, nao esta configurado \n"
    exit
fi    

# Verificacao do sistema, para verificar o diretorio dos Xmls -------------------------------#
# xml - Diretorio dos Xmls do sistema
if [[ "${sistema}" = "iscobol" ]]; then
    if [[ -n "${xml}" ]]; then
    _mensagec "${CYAN}" "${M81}"
    else
    printf "Diretorio dos Xmls do sistema, nao esta configurado  \n"
    exit
    fi 
fi     

# Verificacao de diretorio necessarios para a execucao do programa
# -----------------------------------------------------------------#
# Verifica se os diretorios necessarios para a execucao do programa
# estao configurados corretamente.
# -----------------------------------------------------------------#

# Verificações de parâmetro e diretórios
E_EXEC="${destino}/${exec}"
if [[ -n "${E_EXEC}" ]] && [[ -d "${E_EXEC}" ]]; then
    # Diretorio da destino encontrado
    _mensagec "${CYAN}" "${M81}"
else
    # Diretorio da destino nao encontrado
        M44="Nao foi encontrado o diretorio ""${E_EXEC}"
    _linha "*"
    _mensagec "${RED}" "${M44}"
    _linha "*"
    _read_sleep 2
    exit
    fi
T_TELAS="${destino}/${telas}"
if [[ -n "${T_TELAS}" ]] && [[ -d "${T_TELAS}" ]]; then
    # Diretorio da destino encontrado
    _mensagec "${CYAN}" "${M81}"
else
    # Diretorio da destino nao encontrado
    M44="Nao foi encontrado o diretorio ""${T_TELAS}"
    _linha "*"
    _mensagec "${RED}" "${M44}"
    _linha "*"
    _read_sleep 2
    exit
fi
X_XML="${destino}/${xml}"
if [[ -n "${X_XML}" ]] && [[ -d "${X_XML}" ]]; then
    # Diretorio da destino encontrado
    _mensagec "${CYAN}" "${M81}"
else
    # Diretorio da destino nao encontrado
    printf "%*s""Diretorio da destino nao encontrado ""${X_XML}""...  \n"
    exit
fi     

BASE1="${destino}${base}"
if [[ -n "${BASE1}" ]] && [[ -d "${BASE1}" ]]; then
    # Diretorio da base encontrado
    _mensagec "${CYAN}" "${M81}"
else
    # Diretorio da base nao encontrado
    printf "%*s""Diretorio da base nao encontrado ""${BASE1}""...  \n"
    exit
fi

BASE2="${destino}${base2}"
if [[ -n "${BASE2}" ]] && [[ -d "${BASE2}" ]]; then
    # Diretorio da base encontrado
    _mensagec "${CYAN}" "${M81}"
else
    # Diretorio da base nao encontrado
    printf "%*s""Diretorio da base nao encontrado ""${BASE2}""...  \n"
    exit
fi

BASE3="${destino}${base3}"
if [[ -n "${BASE3}" ]] && [[ -d "${BASE3}" ]]; then
    # Diretorio da base encontrado
    _mensagec "${CYAN}" "${M81}"
else
    # Diretorio da base nao encontrado
    printf "%*s""Diretorio da base nao encontrado ""${BASE3}""...  \n"
    exit
fi     

# Verifica diretórios específicos se o sistema for iscobol
if [[ "${sistema}" == "iscobol" ]]; then
    if [[ ! -d "${X_XML}" ]]; then
        M44="Nao foi encontrado o diretorio ""${X_XML}"
        _linha "*"
        _mensagec "${RED}" "${M44}"
        _linha "*"
        _read_sleep 2
        exit
    fi
fi

# Variavel para armazenar o nome do arquivo de backup
INI="backup-""${VERSAO}"".zip"

# Verificacao do Jutil
# Jutil - Programa para fazer rebuild nas bases de dados
jut="$SAVISC""$JUTIL"


#-Configuracao para acesso ao rsync------------------------------------------------------------------#
# Variaveis de configuracao para acesso ao servidor via rsync
# PORTA - Porta a ser usada para acesso ao servidor via rsync
# USUARIO - Usuario a ser usado para acesso ao servidor via rsync
# IPSERVER - IP do servidor a ser acessado via rsync

# Valor padrao para a porta
DEFAULT_PORTA="41122"
# Verifica se a variavel de ambiente PORTA foi setada
if [[ -z "${PORTA}" ]]; then
    # Se a variavel de ambiente nao foi setada, utiliza o valor padrao
    if [[ -n "${DEFAULT_PORTA}" ]]; then
        PORTA="${DEFAULT_PORTA}"
    else
        # Se a variavel de ambiente nao foi setada e nao tem valor padrao, exibe uma mensagem de erro e sai do programa
        printf "Erro: Variavel de ambiente PORTA nao esta configurada.\n"
        exit 1
    fi
fi

# Valor padrao para o usuario
DEFAULT_USUARIO="atualiza"
# Verifica se a variavel de ambiente USUARIO foi setada
if [[ -z "${USUARIO}" ]]; then
    # Se a variavel de ambiente nao foi setada, utiliza o valor padrao
    if [[ -n "${DEFAULT_USUARIO}" ]]; then
        USUARIO="${DEFAULT_USUARIO}"
    else
        # Se a variavel de ambiente nao foi setada e nao tem valor padrao, exibe uma mensagem de erro e sai do programa
        printf "Erro: Variavel de ambiente USUARIO nao esta configurada.\n"
        exit 1
    fi
fi

# Valor padrao para o ip do servidor
DEFAULT_IPSERVER="179.212.243.48"
# Verifica se a variavel de ambiente IPSERVER foi setada
if [[ -z "${IPSERVER}" ]]; then
    # Se a variavel de ambiente nao foi setada, utiliza o valor padrao
    if [[ -n "${DEFAULT_IPSERVER}" ]]; then
        IPSERVER="${DEFAULT_IPSERVER}"
    else
        # Se a variavel de ambiente nao foi setada e nao tem valor padrao, exibe uma mensagem de erro e sai do programa
        printf "Erro: Variavel de ambiente IPSERVER nao esta configurada.\n"
        exit 1
    fi
fi

# Valor padrao para o caminho do diretorio de destino
DEFAULT_DESTINO2=""
# Verifica se a variavel de ambiente DESTINO2 foi setada
if [[ -z "${DESTINO2}" ]]; then
    # Se a variavel de ambiente nao foi setada, utiliza o valor padrao
    DESTINO2="${DEFAULT_DESTINO2}"
fi

# Valor padrao para o caminho do diretorio de destino dos backups
DEFAULT_ENVIABACK=""
# Verifica se a variavel de ambiente ENVIABACK foi setada
if [[ -z "${ENVIABACK}" ]]; then
    # Se a variavel de ambiente nao foi setada, utiliza o valor padrao
    if [[ -n "${DEFAULT_ENVIABACK}" ]]; then
        ENVIABACK="${DEFAULT_ENVIABACK}"
    else
        # Se a variavel de ambiente nao foi setada e nao tem valor padrao, exibe uma mensagem de erro e sai do programa
        printf "Erro: Variavel de ambiente ENVIABACK nao esta configurada.\n"
        exit 1
    fi
fi
## ------- Parametro para a atualizacao de biblioteca ----------------------------
# Variáveis para armazenar os caminhos de destino dos programas/biblioteca
# que serão baixados via rsync.
DESTINO2SERVER="/u/varejo/man/"  # Caminho do servidor da SAV com os programas.
DESTINO2SAVATUISC="/home/savatu/biblioteca/temp/ISCobol/sav-5.0/"  # Caminho do diretorio de destino dos programas ISCobol.
DESTINO2SAVATUMF="/home/savatu/biblioteca/temp/Isam/sav-3.1"  # Caminho do diretorio de destino dos programas Isam.
DESTINO2TRANSPC="/u/varejo/trans_pc/"  # Caminho do diretorio de destino dos programas da pasta trans_pc.

# Verifica se as variáveis de ambiente foram setadas.
# As variáveis de ambiente são necessárias para que o programa funcione corretamente.
# Caso elas não estejam setadas, o programa exibe uma mensagem de erro e sai.
# Utilizado para baixar os programas via rsync.
if [[ -z "${DESTINO2SERVER}" ]]; then
    printf "Erro: Variavel de ambiente DESTINO2SERVER nao esta configurada.\n"
    exit 1
fi

# DESTINO2SAVATUISC: Caminho do diretorio de destino dos programas ISCobol.
# Utilizado para baixar os programas ISCobol via rsync.
if [[ -z "${DESTINO2SAVATUISC}" ]]; then
    printf "Erro: Variavel de ambiente DESTINO2SAVATUISC nao esta configurada.\n"
    exit 1
fi

# DESTINO2SAVATUMF: Caminho do diretorio de destino dos programas Isam.
# Utilizado para baixar os programas Isam via rsync.
if [[ -z "${DESTINO2SAVATUMF}" ]]; then
    printf "Erro: Variavel de ambiente DESTINO2SAVATUMF nao esta configurada.\n"
    exit 1
fi

# DESTINO2TRANSPC: Caminho do diretorio de destino dos programas de transpote.
# Utilizado para baixar os programas de transpote via rsync.
if [[ -z "${DESTINO2TRANSPC}" ]]; then
    printf "Erro: Variavel de ambiente DESTINO2TRANSPC nao esta configurada.\n"
    exit 1
fi

# Verifica se o sistema e em modo offline, se sim cria diretório SERACESOFF se necessário
if [[ -n "${SERACESOFF}" ]]; then
    if ! [[ -d "${SERACESOFF}" ]]; then 
        mkdir -p "${destino}${SERACESOFF}"
    fi
        if [[ ! -d "${destino}${SERACESOFF}" ]]; then
        printf "Erro ao criar diretório %s\n" "${destino}${SERACESOFF}"
        exit 1
        fi
    _read_sleep 0,30
    BAT="atualiza.bat"
    if [[ -f "${TOOLS}/${BAT}" ]]; then
        mv -f -- "${BAT}" "${destino}${SERACESOFF}"
    fi
fi

#### PARAMETRO PARA O LOGS #
# Define o nome do arquivo de log da atualizacao
# com a data de hoje no formato "ano-mes-dia".
LOG_ATU=${LOGS}/atualiza.$(date +"%Y-%m-%d").log
# Verifica a variável de ambiente LOG_ATU
if [[ -z "${LOG_ATU}" ]]; then
    printf "Erro: Variavel de ambiente LOG_ATU nao esta configurada.\n"
    exit 1
fi
# Define o nome do arquivo de log da limpeza
# com a data de hoje no formato "ano-mes-dia".
LOG_LIMPA=${LOGS}/limpando.$(date +"%Y-%m-%d").log
# Verifica a variável de ambiente LOG_LIMPA
if [[ -z "${LOG_LIMPA}" ]]; then
    printf "Erro: Variavel de ambiente LOG_LIMPA nao esta configurada.\n"
    exit 1
fi
# Define o nome do arquivo de log temporario
# sem data no nome, pois sera sobreescrito
# a cada execucao.
LOG_TMP=${LOGS}/
# Verifica a variável de ambiente LOG_TMP
if [[ -z "${LOG_TMP}" ]]; then
    printf "Erro: Variavel de ambiente LOG_TMP nao esta configurada.\n"
    exit 1
fi

# Define a variavel UMADATA com a data e hora
# atual no formato "dia-mes-ano_hora_minuto_segundo".
UMADATA=$(date +"%d-%m-%Y_%H%M%S")
# Verifica a variável de ambiente UMADATA
if [[ -z "${UMADATA}" ]]; then
    printf "Erro: Variavel de ambiente UMADATA nao esta configurada.\n"
    exit 1
fi

# Visualiza as notas de vers o do programa no formato de uma moldura com bordas
# e centraliza o texto para facilitar a leitura.
_visualizar_notas() {
clear    
NOTA="atualizal"
# Verifica se o arquivo existe e é legível
if [ ! -f "$NOTA" ] || [ ! -r "$NOTA" ]; then
    ML1="Erro: Arquivo $NOTA não existe ou não pode ser lido"
    _linha
    _mensagec "${RED}" "${ML1}"
    _linha  
    _press
    _linha 
else
LARGURA=0
# Calcula a largura máxima do conteúdo
LARGURA=$(awk 'length > max {max = length} END {print max}' "$NOTA")
# Adiciona espaço extra para a moldura
LARGURA_TOTAL=$((LARGURA + 3))

# Função para criar linha horizontal da moldura
_criar_linha() {
    printf "+-"
    for ((i=1; i<=LARGURA_TOTAL-2; i++)); do
        printf "="
    done
    printf "%s\n" "-+"  
}

# Imprime a moldura superior
_criar_linha

# Lê o arquivo linha por linha e adiciona bordas laterais
while IFS= read -r linha || [ -n "$linha" ]; do
    # Calcula padding para centralizar o texto
    TAMANHO_LINHA=${#linha}
    ESPACOS=$((LARGURA - TAMANHO_LINHA + 2))
    
    # Imprime borda esquerda, texto e borda direita
    printf "| %s" "$linha"
    # Adiciona espaços para completar a linha
    for ((i=1; i<=ESPACOS; i++)); do
        printf " "
    done
    printf "|\n"
done < "$NOTA"

# Imprime a moldura inferior
_criar_linha
printf "\n"
_press
fi
}
# Verifica se o arquivo "atualizal" existe e é legível e se contém dados e mostras a anotacao.
NOTA="atualizal"
if [[ -f "${NOTA}" ]]; then
    if [[ -s "${NOTA}" ]]; then
        _visualizar_notas
    fi
fi

clear

# Esta função solicita que o usuário insira o nome de um programa em letras maiúsculas para ser atualizado.
# Ele valida a entrada para garantir que ela consista apenas em letras maiúsculas e números.
# Se a entrada for inválida, exibe uma mensagem de erro e retorna ao menu principal.
# Depois que um nome de programa válido é fornecido, ele pergunta se o programa foi compilado normalmente.
# Com base na resposta do usuário, ele constrói o nome do arquivo do programa com o sufixo de classe apropriado.
# A função define as variáveis ​​NOMEPROG para processamento posterior.
_qualprograma() {
# Variáveis
MAX_REPETICOES=3
contador=0
#resultados=()
NOMEPROG=()
programas=()

# Função para validar nome do programa
validar_nome() {
     local programa="$1"
    [[ -n "$programa" && "$programa" =~ ^[A-Z0-9]+$ ]]   
    [[ "$1" =~ ^[A-Z0-9]+$ ]]
}

# Loop principal
while (( contador < MAX_REPETICOES )); do
     _meiodatela
     #-Informe o nome do programa a ser atualizado:
     _mensagec "${RED}" "${M59}"
     _linha
     MB4="Informe o nome do programa (ENTER ou espaco para sair): "
     read -rp "${YELLOW}""${MB4}""${NORM}" programa
     _linha
    
    # Verifica se foi digitado ENTER ou espaço
    if [[ -z "${programa}" ]]; then
        _mensagec "${RED}" "Erro: Nenhum nome de programa fornecido Saindo ou Continuando..."
        break
    fi
    if [[ "${programa}" == " " ]]; then
        _mensagec "${RED}" "Erro: Nenhum nome de programa fornecido Saindo ou Continuando..."
        break
    fi
    # Verifica se o nome do programa é válido
    if ! validar_nome "$programa"; then
        _mensagec "${RED}" "Erro: O nome do programa deve conter apenas letras maiusculas e numeros (ex.: ABC123)."
        continue
    fi

    # Solicita o tipo de compilação
     _mensagec "${RED}" "${M75}"
     _linha  

     read -rp "${YELLOW}${M75}${NORM}" -n1 tipo_compilacao  
     printf "\n"
    if [[ "$tipo_compilacao" == "1" ]]; then
        compila=${programa}${class}".zip"
    elif [[ "$tipo_compilacao" == "2" ]]; then
        compila=${programa}${mclass}".zip"
    else
        _mensagec "${RED}" "Erro: Opcao de compilacao invalida Digite 1 ou 2."
        continue
    fi
    # Armazena o resultado
    programas+=("$programa") 
    NOMEPROG+=("$compila")
#   
    _linha
    _mensagec "${GREEN}" "Compilacao adicionada: ${NOMEPROG[*]}"
    ((contador++))
    _linha
#done
# Lista os programas armazenados
_mensagec "${YELLOW}" "Lista de programas a serem baixados:"
    for progr in "${NOMEPROG[@]}"; do
        _mensagec "${GREEN}" "$progr"
    done
done
}


# _baixarviarsync - Realiza o RSYNC dos arquivos de compilacao
#
# Exibe os resultados finais se houver e realiza o RSYNC dos arquivos
# de compilacao, transferindo-os do servidor remoto para o local.
#
# Opcoes:
#   NAO TEM
#
# Variaveis:
#   NOMEPROG - Array de strings com os nomes dos arquivos a serem baixados
#   DESTINO2SERVER - Caminho do servidor remoto com os arquivos a serem baixados
#   PORTA - Numero da porta a ser usada para acesso ao servidor via RSYNC
#   USUARIO - Usuario a ser usado para acesso ao servidor via RSYNC
#   IPSERVER - IP do servidor a ser acessado via RSYNC
_baixarviarsync() {
    # Exibe os resultados finais se houver
    if (( ${#NOMEPROG[@]} > 0 )); then
        _mensagec "${YELLOW}" "Resultados armazenados:"
        _linha
        _mensagec "${GREEN}" "${NOMEPROG[@]}"

        # Realiza o RSYNC
        _linha
        _mensagec "${YELLOW}" "Realizando RSYNC dos arquivos..."
        for arquivo in "${NOMEPROG[@]}"; do
            _linha
            _mensagec "${GREEN}" "Transferindo: $arquivo"
            _linha
            _mensagec "${YELLOW}" "${M29}"
            _linha  
            rsync -avzP -e "ssh -p $PORTA" "$USUARIO"@"${IPSERVER}":"${DESTINO2SERVER}""${arquivo}" .
        done
    else
        _mensagec "${RED}" "Nenhum valor armazenado."
        _mensagec "${GREEN}" "Processo finalizado."
    fi
}

    # _servacessoff - Move arquivos do diretorio SERACESOFF para o diretorio atual
    #
    # Move os arquivos do diretorio SERACESOFF para o diretorio atual.
    #
    # Opcoes:
    #   NAO TEM
    #
    # Variaveis:
    #   SERACESOFF - Caminho do diretorio SERACESOFF
    #   destino - Caminho do diretorio raiz
_servacessoff() {
if [[ "${SERACESOFF}" != "" ]]; then
    local SAOFF="${destino}${SERACESOFF}"
    if [[ ! -d "${SAOFF}" ]]; then
        _mensagec "${RED}" "Erro: Diretorio ${SAOFF} nao existe"
        return
    fi
    for arquivo in "${NOMEPROG[@]}"; do
    if [[ -f "${SAOFF}/${arquivo}" ]]; then
        mv -f -- "${SAOFF}/${arquivo}" "." 
    else
    M42="Aviso: Arquivo %s não encontrado.\n" "$arquivo"
    _linha 
    _mensagec "${RED}" "${M42}"
    _linha 
    _press
    _principal
    fi 
    done
fi
}

    # _pacoteon: Realiza a atualização de um programa em um ambiente online.
    #
    # Este método:
    # - Solicita o nome do programa a ser atualizado utilizando o método _qualprograma.
    # - Exibe uma mensagem indicando que a atualização está em andamento.
    # - Realiza o download do pacote via RSYNC.
    # - Atualiza o pacote chamando o método _atupacote.
    # - Aguarda um pressionamento de tecla e retorna ao menu principal.
    #
    # Se ocorrer qualquer erro durante o processo, uma mensagem de erro é exibida,
    # e o usuário é retornado ao menu principal.
_pacoteon() {
    _qualprograma
    _baixarviarsync
    _linha 
    _atupacote
    _press 
    _principal
}

    # _pacoteoff: Realiza a atualização de um programa em um ambiente offline.
    #
    # Este método:
    # - Verifica se o diretório SERACESOFF existe e está configurado.
    # - Move os arquivos do diretório SERACESOFF para o diretório atual.
    # - Solicita o nome do programa a ser atualizado utilizando o método _qualprograma.
    # - Exibe uma mensagem indicando que a atualização está em andamento.
    # - Atualiza o pacote chamando o método _atupacote.
    # - Aguarda um pressionamento de tecla e retorna ao menu principal.
    #
    # Se ocorrer qualquer erro durante o processo, uma mensagem de erro é exibida,
    # e o usuário é retornado ao menu principal.
_pacoteoff() {
    # Solicita o nome do programa a ser atualizado
    if ! _qualprograma; then
        return
    fi
     _linha
     _mensagec "${YELLOW}" "${M09}"
     _linha
     _read_sleep 1
     _servacessoff

    # Atualiza o pacote
    if ! _atupacote; then
        _mensagec "${RED}" "Erro: Falha ao atualizar o pacote."
        _linha
        _press
        _principal
        return
    fi

    # Aguarda pressionamento de tecla e retorna ao menu principal
    _press
    _principal
}

# Obtém a data e hora de modificação do arquivo novo
    # Exibe a data e hora de modificação do arquivo novo
    #
    # Exibe uma mensagem com o nome do arquivo e a data e hora de modificação
    # do arquivo novo.
    #
    # Argumentos:
    #   Nenhum
    #
    # Retorno:
    #   Nenhum
_data_do_arquivo() {
    local novo_arquivo="${arquivo}"
    local data_modificacao
    data_modificacao=$(stat -c %y "${E_EXEC}/${novo_arquivo}")
    local data_formatada
    data_formatada=$(date -d "$data_modificacao" +"%d/%m/%Y %H:%M:%S")
    _mensagec "${GREEN}" "Nome do programa: ${novo_arquivo}"
    _mensagec "${YELLOW}" "Data do programa: ${data_formatada}"
    _linha
}
    # Atualiza os pacotes de programa.
    #
    # Essa função processa os arquivos de atualização de programas,
    # descompactando e atualizando os arquivos de programa antigos.
    # Os arquivos de programa antigos são salvos no diretório de backup
    # (OLDS) com o nome do arquivo seguido de "-anterior.zip".
    # A função também move os arquivos .class, .int e .TEL para os
    # diretórios E_EXEC e T_TELAS, respectivamente.
    # Caso ocorra algum erro, uma mensagem de erro é exibida e o
    # usuário é retornado ao menu principal.
_atupacote() {
    local arquivo
    local extensao
    local backup_file

    # Verifica se o programa existe
    if (( ${#NOMEPROG[@]} == 0 )) || [[ ! -f "${NOMEPROG[0]}" ]]; then
        _linha
        _mensagec "${RED}" "Um deste(s) programa(s) ${NOMEPROG[*]} nao encontrado(s) no diretorio"
        _linha
        _press
        _principal
    fi
# Processa programas antigos
for  f in "${!programas[@]}"; do
        anterior="${OLDS}/${programas[f]}-anterior.zip"
        if [[ -f "$anterior" ]]; then
            # Verifica se o arquivo de backup já existe
            mv -f -- "${anterior}" "${OLDS}/${UMADATA}-${programas[f]}-anterior.zip" >> "${LOG_ATU}" ||{
                M49="Erro: Falha ao renomear o arquivo ${anterior}"
                _linha
                _mensagec "${RED}" "${M49}"
                _linha
                _press
                _principal
                return
            }    
        fi
        _mensagec "${YELLOW}" "Salvando programa antigo: ${programas[f]}"
        EXT_CLASS=".class"
         # Processa arquivos .class
        if [[ -f "${E_EXEC}/${programas[f]}${EXT_CLASS}" ]]; then
            if ! "${cmd_zip}" -m -j "${anterior}" "${E_EXEC}/${programas[f]}"*"${EXT_CLASS}"; then
                _linha
                _mensagec "${RED}" "Erro ao criar backup do arquivo ${programas[f]}${EXT_CLASS}"
                _linha
                _press
                _principal
                return
            fi
        fi
        # Processa arquivos .int
        EXT_INT=".int"
        if [[ -f "${E_EXEC}/${programas[f]}${EXT_INT}" ]]; then
            if ! "${cmd_zip}" -m -j "${anterior}" "${E_EXEC}/${programas[f]}${EXT_INT}"; then
                _linha
                _mensagec "${RED}" "Erro ao criar backup do arquivo ${programas[f]}${EXT_INT}"
                _linha
                _press
                _principal
                return
            fi
        fi
        # Processa arquivos .TEL
        EXT_TEL=".TEL"
        if [[ -f "${T_TELAS}/${programas[f]}${EXT_TEL}" ]]; then
            if ! "${cmd_zip}" -m -j "${anterior}" "${T_TELAS}/${programas[f]}${EXT_TEL}"; then
                _linha
                _mensagec "${RED}" "Erro ao criar backup do arquivo ${programas[f]}${EXT_TEL}"
                _linha
                _press
                _principal
                return
            fi
        fi
done
    _linha 
    _mensagec "${YELLOW}" "${M24}"
    _linha 
    _read_sleep 1      
    #fi      

    # Processa de descompactar e atualizar os programas
    for arquivo in "${NOMEPROG[@]}"; do
        if [[ ! -f "${arquivo}" ]]; then
            _linha
            _mensagec "${RED}" "Erro: Arquivo de atualizacao ${arquivo} nao existe"
            _linha
            _press
        fi
        if ! "${cmd_unzip}" -o "${arquivo}" >> "${LOG_ATU}"; then
            _linha
            _mensagec "${RED}" "Erro ao descompactar ${arquivo}"
            _linha
            _press
        fi
    done

    # Salvando arquivos .class, .int, .TEL
    for extensao in ".class" ".int" ".TEL"; do
        if compgen -G "*${extensao}" > /dev/null; then
            for arquivo in *"${extensao}"; do
                if [[ "${extensao}" == ".TEL" ]]; then
                    mv -f -- "${arquivo}" "${T_TELAS}" >> "${LOG_ATU}" || {
                        _mensagec "${RED}" "Erro ao mover ${arquivo}"
                        return
                    }
                else
                    mv -f -- "${arquivo}" "${E_EXEC}" >> "${LOG_ATU}"
                        _data_do_arquivo || {
                        _mensagec "${RED}" "Erro ao mover ${arquivo}"
                        return
                    }
                fi
            done
        fi
    done
    _mensagec "${GREEN}" "${M26}"
    _linha
    


    # Altera extensões e move arquivos para o diretório PROGS
    for arquivo in "${NOMEPROG[@]}"; do
        if [[ -f "${arquivo}" ]]; then
            backup_file="${arquivo%.zip}.bkp"
            if ! mv -f -- "${arquivo}" "${PROGS}/${backup_file}"; then
                _linha
                _mensagec "${RED}" "Erro ao renomear ${arquivo} para ${backup_file}"
                _linha
                _press
                _principal
                return
            fi
        fi
        _mensagec "${GREEN}" "${M20}"
        _linha
    done

    # Mensagem de conclusão
    _linha
    _mensagec "${YELLOW}" "${M17}"
    _linha
}
####-- Inicio da funcao de voltar programas --   
# _voltamaisprog: Prompt user for additional program updates.
    #
    # This function concludes the program rollback process by displaying a message and
    # optionally prompts the user if they wish to update additional programs. If the user
    # chooses to update more programs and the option is set to 1, it calls the _voltaprog
    # function. Otherwise, it returns to the main menu. If the input is invalid, an error
    # message is displayed, and the user is returned to the main menu.

_voltamaisprog() {
#-VOLTA DE PROGRAMA CONCLUIDA
    _linha 
    _mensagec "${YELLOW}" "${M03}"
    _mensagec "${GREEN}" "${M02}"
    _linha 
    _press

#-Escolha de multi programas-----------------------------------------------------------------------# 
#M37 Deseja informar mais algum programa para ser atualizado?
    _meiodatela
    read -rp "${YELLOW}""${M37}""${NORM}" -n1  REPLY
    printf "\n\n"
    if [[ -z "${REPLY}" ]]; then
            _principal
    elif [[ "${REPLY,,}" =~ ^[Nn]$ ]]; then
            _principal
    elif [[ "${REPLY,,}" =~ ^[Ss]$ ]]; then
        if [[ "${OPCAO}" = 1 ]]; then
            _voltaprog
        else
            _principal
        fi
    else
        _opinvalida
        _read_sleep 1          	 
        _press
        _principal
    fi
}

#-Procedimento da desatualizacao de programas------------------------------------------------------#
#-VOLTA DE PROGRAMA CONCLUIDA
# Mostra uma mensagem de inicio de desatualizacao de programa e pergunta o nome do programa a ser
# desatualizado. Se o programa nao for encontrado no diretorio, volta ao menu principal.
#
# Opcoes:
#   Qualquer tecla - Desatualiza o programa
_voltaprog() {
    # Variáveis
    MAX_REPETICOES=3
    contador=0
    NOMEPROG=()
    programas=()

    _validar_nome2() {
        [[ "$1" =~ ^[A-Z0-9]+$ ]]
    }

    # Loop principal
    while (( contador < MAX_REPETICOES )); do
        _meiodatela
        #-Informe o nome do programa a ser desatualizado:
        _mensagec "${RED}" "${M59}"
        _linha
        MB4="Informe o nome do programa (ENTER ou espaco para sair): "
        while [[ -z "${programa}" ]]; do
        read -rp "${YELLOW}""${MB4}""${NORM}" programa
        _linha
        if [[ -z "${programa}" ]]; then
            _mensagec "${RED}" "Erro: Nenhum nome de programa fornecido Saindo da selecao de programas..."
            return 

        fi
        done

        # Verifica se o nome do programa é válido
        if ! _validar_nome2 "$programa"; then
            _mensagec "${RED}" "Erro: O nome do programa deve conter apenas letras maiusculas e numeros (ex.: ABC123)."
            continue
        fi
        _linha  
        compila=${programa}${class}".zip"
        
        # Armazena o resultado
        programas+=("$programa") 
        NOMEPROG+=("$compila")
        ((contador++))
    done

    # Exibe os resultados finais se houver
    if (( ${#NOMEPROG[@]} > 0 )); then
        _mensagec "${YELLOW}" "Resultados armazenados:"
        _linha
        _mensagec "${GREEN}" "${NOMEPROG[@]}"

        for arquivo in "${NOMEPROG[@]}"; do
            _linha
            _mensagec "${GREEN}" "Verificando arquivo: $arquivo"
        done
    else
        _mensagec "${RED}" "Nenhum programa armazenado."
        _mensagec "${GREEN}" "Processo finalizado."
    fi

    # Processa programas antigos
    for f in "${!programas[@]}"; do
        anterior="${OLDS}/${programas[f]}-anterior.zip"
        if [[ -f "$anterior" ]]; then
            mv -f -- "${anterior}" "${TOOLS}/${programas[f]}${class}.zip" >> "${LOG_ATU}" || {
                M49="Erro: Falha ao renomear o arquivo ${anterior}.zip"
                _linha
                _mensagec "${RED}" "${M49}"
                _linha
                _press
                _principal
                return
            }
        fi
    done

    if ! cd "${TOOLS}/"; then
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${TOOLS}."
        _principal
        return
    fi
    _atupacote
    _voltamaisprog
}


    # _volta_progy: Realiza a volta de um programa para uma versao anterior.
    #
    # Este método:
    # - Verifica se a variável Vprog está vazia, se sim, volta ao menu principal.
    # - Move os arquivos do diretório ${TOOLS} para os diretórios respectivos
    #   dependendo do tipo de sistema.
    # - Exibe uma mensagem de fim de processo e volta ao menu principal.
    #
    # Se ocorrer qualquer erro durante o processo, uma mensagem de erro é exibida,
    # e o usuário é retornado ao menu principal.
_volta_progy() {
    _read_sleep 1

    # Validação da variável Vprog
    if [[ -z "${Vprog}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha
        _press
        _principal
        return 1
    fi

    # Função auxiliar para mover arquivos
    move_files() {
        local pattern="$1"
        local dest="$2"
        local type="$3"
        
        if ! "${cmd_find}" "${TOOLS}" -name "${pattern}" -exec mv {} "${dest}" \; 2>/dev/null; then
            printf "Erro ao mover arquivos %s.\n" "${type}"
            return 1
        fi
        return 0
    }

#-VOLTA PROGRAMA ESPECIFICO------------------------------------------------------------------------#
# _volta_progx: Volta um programa especifico para a versao anterior
# 
# Informa o nome do programa em MAIUSCULO e descompacta o arquivo
# da biblioteca anterior no diretorio TOOLS.
_volta_progx() {
    MA4="       2- Informe o nome do programa em MAIUSCULO: "
    read -rp "${YELLOW}""${MA4}""${NORM}" Vprog

    if [[ -z "${Vprog}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha 
        _press
        _principal
        return 1
    fi

    if [[ ! "${Vprog}" =~ [A-Z0-9] ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha 
        _press
        _principal
        return 1
    fi

    # Processamento baseado no tipo de sistema
    local move_status=0
    if [[ "${sistema}" = "iscobol" ]]; then
        move_files "${Vprog}.xml" "${X_XML}" || move_status=1
        move_files "${Vprog}.TEL" "${T_TELAS}" || move_status=1
        move_files "${Vprog}*.class" "${E_EXEC}" || move_status=1
    else
        move_files "${Vprog}.TEL" "${T_TELAS}" || move_status=1
        move_files "${Vprog}*.int" "${E_EXEC}" || move_status=1
    fi

    # Verifica se houve erro nos movimentos
    if [[ ${move_status} -ne 0 ]]; then
        return 1
    fi

    # Exibição das mensagens finais
    _linha
    _mensagec "${YELLOW}" "${M03}"
    _linha

    local M30="O(s) programa(s) '${Vprog}' da ${NORM}${RED}${VERSAO}"
    _linha
    _mensagec "${YELLOW}" "${M25}"
    _mensagec "${YELLOW}" "${M30}"
    _linha
    _press
    _volta_progx
}


# Função para extrair arquivos e tratar erros

cd "${OLDS}" || { printf "Erro ao acessar o diretório %s.\n" "${OLDS}"; exit 1; }

# Verifica se o arquivo de entrada existe antes de tentar descompactar
if [ ! -f "${INI}" ]; then
    printf "Erro: Arquivo %s não encontrado.\n" "${INI}"
    exit 1
fi

extrair_arquivos() {
    local padrao="$1"

    if ! "${cmd_unzip}" -j -o "${INI}" "${padrao}" -d "${TOOLS}" >> "${LOG_ATU}"; then
        _meiodatela
        _mensagec "${RED}" "Erro ao descompactar ${INI} para ${TOOLS}"
        _linha
        _press
        _principal
        return 1
    fi
}

# Executa a extração dos dois conjuntos de arquivos
extrair_arquivos "${destino}/${exec}/${Vprog}"*.*
extrair_arquivos "${destino}/${telas}/${Vprog}".*

# Retorna ao programa principal
_volta_progy

}

#-volta todos os programas da biblioteca-----------------------------------------------------------#
# 
# _volta_geral
# 
# Volta todos os arquivos da biblioteca.
# Esta funcao e responsavel por voltar todos os arquivos da biblioteca da SAV.
_volta_geral() {
    #-VOLTA DOS ARQUIVOS ANTERIORES...
    _error_exit() {
        local msg="$1"
        _meiodatela
        _mensagec "${RED}" "$msg"
        _linha
        _press
        _principal
        return 1
    }

    # Validate inputs
    [[ -z "${OLDS}" ]] && _error_exit "${M71}"
    [[ -z "${INI}" ]] && _error_exit "${M71}"
    [[ ! -d "${OLDS}" ]] && _error_exit "${M71}"

    if ! cd "${OLDS}"; then
        _meiodatela
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${OLDS}"
        _linha
        _press
        _principal
        return 1
    fi
local raiz="/"
    if ! "${cmd_unzip}" -o "${INI}" -d "${raiz}" >> "${LOG_ATU}"; then
        _meiodatela
        _mensagec "${RED}" "Erro ao descompactar ${INI} para ${raiz}"
        _linha 
        _press
        _principal
        return 1
    fi

    if ! cd "${TOOLS}" 2>/dev/null; then
        _meiodatela
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${TOOLS}"
        _linha
        _press
        _principal
        return 1
    fi

    # Sucesso
    _mensagec "${YELLOW}" "${M33}"
    clear
    #-VOLTA DOS PROGRAMAS CONCLUIDA
    _linha 
    _mensagec "${YELLOW}" "${M03}"
    _linha 
    
    # Atualização do arquivo de versão
    ANTVERSAO=$VERSAO
    if ! printf "VERSAOANT=%s\n" "${ANTVERSAO}" >> atualizac; then
        _meiodatela
        _mensagec "${RED}" "Erro ao gravar arquivo de versao atualizada"
        _linha 
        _press
        _principal
        return 1
    fi

    _press
    _principal
}

_versao() {
    _linha 
    _mensagec "${YELLOW}" "${M55}"
    _linha
    printf "\n"
    read -rp "${GREEN}${M57}${NORM}" VERSAO
    if [[ -z "${VERSAO}" ]]; then
        printf "\n"
        _linha
        _mensagec "${RED}" "${M56}"
        _linha 
        _press
        _principal
        return 1
    fi
}    

_variaveis_atualiza() {
    ATUALIZA1="${SAVATU1}${VERSAO}.zip"
    ATUALIZA2="${SAVATU2}${VERSAO}.zip"
    ATUALIZA3="${SAVATU3}${VERSAO}.zip"
    ATUALIZA4="${SAVATU4}${VERSAO}.zip"
}

# _rsync_biblioteca - Realiza o RSYNC da biblioteca
#
# RSYNC the library from the OFF server and save the zip file to the local destination.
#
# Parameters:
#   NAO TEM
#
# Variables:
#   USUARIO - Usuario a ser usado para acesso ao servidor via RSYNC
#   IPSERVER - IP do servidor a ser acessado via RSYNC
#   PORTA - Numero da porta a ser usada para acesso ao servidor via RSYNC
#   DESTINO2 - Caminho do servidor remoto com a biblioteca a ser baixada
#   SAVATU - Caminho do diretorio da biblioteca no servidor remoto
#   VERSAO - Versao do programa a ser baixado
#   destino - Caminho do diretorio local onde o arquivo sera salvo
_rsync_biblioteca() {
    local src="${USUARIO}@${IPSERVER}:${DESTINO2}${SAVATU}${VERSAO}.zip"
    local dst="."
    rsync -avzP -e "ssh -p ${PORTA}" "${src}" "${dst}"
    _salva
}

# Acessa o menu de biblioteca no servidor OFF.
# Esta funcao e responsavel por acessar o menu de biblioteca no servidor OFF.
# _acessooff: Access the OFF server's library and move update files to tools directory.
#
# This function checks if the directory for the OFF server's library (SAOFF) exists.
# If it does not exist, it displays an error message and returns 1. If the directory
# exists, it attempts to move update files from the SAOFF directory to the TOOLS directory.
# The update files are determined based on the system type (iscobol or another system).
# If any file move operation fails, an error message is displayed and the function returns 1.
# If successful, messages indicating the progress of the operation are displayed.
#
# Globals:
#   destino     - Base directory for the current operation.
#   SERACESOFF  - Directory containing the OFF server's files.
#   sistema     - Indicates the system type (e.g., iscobol).
#   TOOLS       - Directory where tools are stored.
#   ATUALIZA1   - Update file path for first update.
#   ATUALIZA2   - Update file path for second update.
#   ATUALIZA3   - Update file path for third update.
#   ATUALIZA4   - Update file path for fourth update (used if system is iscobol).
#
# Returns:
#   0 on success
#   1 on error

_acessooff() {
    local off_directory="${destino}${SERACESOFF}"
if [[ -n "${SERACESOFF}" ]]; then
        _mensagec "${YELLOW}" "Acessando biblioteca do servidor OFF..."
        _linha
        _variaveis_atualiza
    local -a update_files

    if [[ "${sistema}" == "iscobol" ]]; then
        update_files=( "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}" "${ATUALIZA4}" )
    else
        update_files=( "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}" )
    fi

    for file in "${update_files[@]}"; do
        if [[ -f "${off_directory}/${file}" ]]; then
            if ! mv -f -- "${off_directory}/${file}" "${TOOLS}"; then
                _mensagec "${RED}" "Erro ao mover arquivo ${file}"
                return 1
            fi
            _mensagec "${GREEN}" "Movendo biblioteca...${file}"
            _linha
        fi
    done

    _read_sleep 2
    _salva
fi    

}

#-Atualizacao da pasta transpc---------------------------------------------------------------------#
#-Atualiza a pasta transpc
# 
# _transpc
# 
# Atualiza a pasta transpc.
# Esta funcao e responsavel por atualizar a pasta transpc.
_transpc() {
    clear
    _versao 
    if [[ -z "${DESTINO2TRANSPC}" ]]; then
        _linha
        _mensagec "${RED}" "Erro: DESTINO2TRANSPC nao foi definido"
        _press
        exit 1
    fi

    if [[ -n "${SERACESOFF}" ]]; then
        _linha
            _mensagec "${YELLOW}" "Parametro de biblioteca do servidor OFF, ativo"
        _linha
        _press
        _biblioteca
    fi

    _linha
    _mensagec "${YELLOW}" "${M29}"
    _linha

    DESTINO2="${DESTINO2TRANSPC}"

    if [[ -z "${DESTINO2}" ]]; then
        _mensagec "${RED}" "Erro: DESTINO2 nao foi definido"
        exit 1
    fi
    _rsync_biblioteca
}

#-Atualizacao da pasta do savatu-------------------------------------------------------------------# 
# 
# _savatu
# 
# Atualiza a pasta do savatu.
# Esta funcao e responsavel por atualizar a pasta do savatu.
_savatu() {
    clear
    _versao
    if [[ -z "${DESTINO2SAVATUISC}" ]]; then
        _mensagec "${RED}" "Erro: DESTINO2SAVATUISC nao foi definido"
        _press
        exit 1
    fi

    if [[ -z "${DESTINO2SAVATUMF}" ]]; then
        _linha
        _mensagec "${RED}" "Erro: DESTINO2SAVATUMF nao foi definido"
        exit 1
    fi
    if [[ -n "${SERACESOFF}" ]]; then
        _linha
            _mensagec "${YELLOW}" "Parametro de biblioteca do servidor OFF, ativo"
        _linha
        _press
        _biblioteca
    fi
    _linha
    _mensagec "${YELLOW}" "${M29}"
    _linha
    if [[ "${sistema}" = "iscobol" ]]; then
        DESTINO2="${DESTINO2SAVATUISC}"
    else
        DESTINO2="${DESTINO2SAVATUMF}"
    fi
    
    if [[ -z "${DESTINO2}" ]]; then
        _mensagec "${RED}" "Erro: DESTINO2 nao foi definido"
        exit 1
    fi
    _rsync_biblioteca
}

#
# _atuoff
#
# Esta função é responsável por realizar a operação de atualização offline.
# Ela limpa a tela, chama a função _versao para verificar a versão atual,
# e se a variável SERACESOFF estiver definida, acessa o servidor OFF para
# realizar a atualização. Por fim, salva a atualização chamando a função _salva.
#
# Variáveis globais:
#   SERACESOFF - Indica se o servidor OFF está configurado para atualização.
#   TOOLS      - Diretório onde os arquivos de ferramentas são armazenados.
#
# Retorna:
#   Nenhum valor de retorno. Chama outras funções para realizar operações.
#

_atuoff() {
    clear
    _versao
    if [[ -n "${SERACESOFF}" ]]; then
        _acessooff
    fi  
    _salva
}

# _salva
#
# Salva a atualizacao no diretorio tools.
#
# Esta funcao e responsavel por salvar a atualizacao no diretorio tools.
# Ela verifica se o diretorio tools existe e tem permissao de leitura.
# Se o diretorio tools nao existe ou nao tem permissao de leitura,
# a funcao exibe uma mensagem de erro e sai.
# Se o diretorio tools existe e tem permissao de leitura,
# a funcao exibe uma mensagem informando que a atualizacao sera salva
# e chama a funcao _processo para processar a atualizacao.
_salva() {
    clear
    _variaveis_atualiza

    M21="A atualizacao tem que esta no diretorio ""${TOOLS}"
    _linha 
    _mensagec "${YELLOW}" "${M21}"
    _linha 

    if [[ -z "${sistema}" ]]; then
        _mensagec "${RED}" "Erro: Variavel 'sistema' nao foi definida"
        exit 1
    fi

    if [[ "${sistema}" = "iscobol" ]]; then
        local -a atualizas=( "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}" "${ATUALIZA4}" )
    else
        local -a atualizas=( "${ATUALIZA1}" "${ATUALIZA2}" "${ATUALIZA3}" )
    fi

    for atu in "${atualizas[@]}"; do
        if [[ -z "${atu}" ]]; then
            _mensagec "${RED}" "Erro: Variavel 'atu' nao foi definida"
            exit 1
        fi
        if [[ ! -r "${atu}" ]]; then
            clear
            _linha 
            _mensagec "${RED}" "${M48}"
            _linha 
            _press
            clear
            _principal
            return 1
        fi
    done

    _processo
}

# _processo: Função que faz o backup dos arquivos antigos e
#            chama a função _atubiblioteca para atualizar os arquivos.

_processo() {
    local INI="backup-${VERSAO}.zip"
    local backup_path="${OLDS}/${INI}"

#INI="backup-${VERSAO}.zip"
    #-ZIPANDO OS ARQUIVOS ANTERIORES...
    _linha 
    _mensagec "${YELLOW}" "${M01}"
    _linha 
    _read_sleep 1

    if [ "$sistema" = "iscobol" ]; then

        cd "$E_EXEC"/ || exit
        "$cmd_find" "$E_EXEC"/ -type f \( -iname "*.class" -o -iname "*.jpg" -o -iname "*.png" -o -iname "brw*.*" -o -iname "*." -o -iname "*.dll" \) -exec zip -r -q "${backup_path}" "{}" + ; 
        cd "$T_TELAS"/ || exit
        "$cmd_find" "$T_TELAS"/ -type f \( -iname "*.TEL" \) -exec zip -r -q "${backup_path}" "{}" + ;
        cd "$X_XML"/ || exit
        "$cmd_find" "$X_XML"/ -type f \( -iname "*.xml" \) -exec zip -r -q "${backup_path}" "{}" + ;
    else
        cd "$E_EXEC"/ || exit
        "$cmd_find" "$E_EXEC"/ -type f \( -iname "*.int" \) -exec zip -r -q "${backup_path}" "{}" + ;
        cd "$T_TELAS"/ || exit
        "$cmd_find" "$T_TELAS"/ -type f \( -iname "*.TEL" \) -exec zip -r -q "${backup_path}" "{}" + ;

    fi 
    cd "$TOOLS"/ || exit
    clear
    _linha 
    _mensagec "${YELLOW}" "${M27}"
    _linha 
    _read_sleep 1

    cd "${TOOLS}" || { _mensagec "${RED}" "Erro: Nao foi possivel acessar o diretorio ${TOOLS}"; exit 1; }
    if [[ ! -r "${backup_path}" ]]; then
        #-Backup nao encontrado no diretorio
        _linha 
        _mensagec "${RED}" "${M45}"
        _linha 
        #-Procedimento caso nao exista o diretorio a ser atualizado----------------------------------------# 
        _read_sleep 2    
        _meiodatela
        read -rp "${YELLOW}${M38}${NORM}" -n1 reply
        printf "\n\n"

       case "${reply,,}" in
            "" | "n")
                _principal
                ;;
            "s")
                _meiodatela
                _mensagec "${YELLOW}" "${M39}"
                ;;
            *)
                _opinvalida
                _read_sleep 1
                _principal
                ;;
        esac
    fi
    _atubiblioteca 
}
#-Procedimento da Atualizacao de Programas---------------------------------------------------------# 
# 
# Faz a atualizacao dos programas.
# Altera a versao da atualizacao e salva no diretorio /backuup como a extensao .bkp".
_atubiblioteca() {
    # Atualização de Programas

    cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    _variaveis_atualiza
    # Atualizando os programas
    for arquivo in ${ATUALIZA1} ${ATUALIZA2} ${ATUALIZA3} ${ATUALIZA4}; do
        if [[ -n "${arquivo}" && -r "${arquivo}" ]]; then
            _linha
            _mensagec "${YELLOW}" "${M26}"
            _linha
            if _mensagec "${GREEN}" "${arquivo}"; then
            "${cmd_unzip}" -o "${arquivo}" -d "/${destino}" >> "${LOG_ATU}"
            else
                _mensagec "${RED}" "${M48}"
            fi
            _linha
            _read_sleep 2
            clear
        else
            _mensagec "${RED}" "Erro: Arquivo ${arquivo}${VERSAO} nao encontrado ou nao legível."
        fi
    done

    # Atualização completa
    _linha
    _mensagec "${YELLOW}" "${M17}"
    _linha

    for arquivo_zip in *_"${VERSAO}".zip; do
        if [[ -f "${arquivo_zip}" ]]; then
            mv -f -- "${arquivo_zip}" "${arquivo_zip%.zip}.bkp" || _mensagec "${RED}" "Erro ao mover ${arquivo_zip} para ${arquivo_zip%.zip}.bkp"
        else
            _mensagec "${RED}" "Arquivo ${arquivo_zip} nao encontrado."
        fi
    done
    mv -f -- *_"${VERSAO}".bkp "${BACKUP}" || _mensagec "${RED}" "Erro ao mover backups para ${BACKUP}"

    # Alterando a extensão da atualização de .zip para .bkp
    M40="Versao atualizada - ${VERSAO}"
    _linha
    _mensagec "${YELLOW}" "${M20}"
    _mensagec "${YELLOW}" "${M13}"
    _mensagec "${RED}" "${M40}"
    _linha
    _press

    VERSAO_ANTERIOR=$VERSAO
    printf "VERSAOANT=${VERSAO_ANTERIOR}""%*s\n"  >> atualizac || _mensagec "${RED}" "Erro ao atualizar o arquivo de configuracao."
    _principal
}

#-Procedimento da desatualizacao de programas antes da biblioteca----------------------------------# 
# Esta função trata do processo de reversão do sistema para o estado anterior à atualização da biblioteca.
# Ele solicita ao usuário a versão do backup a ser restaurada e verifica a existência do
# arquivo de backup no diretório especificado. Se o backup não for encontrado, ele retorna ao menu anterior.
# O usuário é questionado se deseja restaurar todos os programas para o estado anterior à atualização. Baseado em
# resposta do usuário, ele restaura programas específicos ou todos os programas para suas versões anteriores.
_voltabibli() {
#    clear
    M02="Voltando a versao anterior do programa ""${prog}""..."
    _meiodatela
    _mensagec "${RED}" "${M62}"
    _linha
    read -rp "${YELLOW}""${MA2}""${NORM}" VERSAO

    if [[ -z "${VERSAO}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M56}"
        _linha
        _press
        INI=""
        _principal
        return
    else
        INI="backup-${VERSAO}.zip" 
    fi

    if [[ ! -r "${OLDS}"/"${INI}" ]]; then
        # -Backup da Biblioteca nao encontrado no diretorio
        _linha 
        _mensagec "${RED}" "${M46}"
        _linha 
        _press
        INI=""
        _principal
        return
    fi
    MA3="Deseja volta todos os programas para antes da atualizacao? [N/s]:"
    printf "\n"
    read -rp "${YELLOW}${MA3}${NORM}" -n1 
    printf "\n\n"
    if [[ "${REPLY,,}" =~ ^[Nn]$ ]] || [[ "${REPLY,,}" == "" ]]; then
        _linha 
        _volta_progx
    elif [[ "${REPLY,,}" =~ ^[Ss]$ ]]; then
        _linha 
        _volta_geral
    else
        _opinvalida
        _read_sleep 1
        _press
        INI=""
        _principal
    fi
}
#-Rotina de Atualizacao Biblioteca-----------------------------------------------------------------#
# 
# _biblioteca
# 
# Atualiza a biblioteca da SAV.
# Esta funcao e responsavel por atualizar a biblioteca da SAV.

_biblioteca() { 
    local OPCAO
#    local INI
    VERSAO=" " # Variavel que define a versao do programa.
    clear
    M401="Menu da Biblioteca"
    M403="Versao Anterior - ${NORM}${PURPLE}${VERSAOANT}"
    M404="Escolha o local da Biblioteca:        "
    M405="1${NORM} - Atualizacao do Transpc     "
    M406="2${NORM} - Atualizacao do Savatu      "
    M407="3${NORM} - Atualizacao OFF-Line       "
    M408="Escolha o tipo de Desatualizacao:       "
    M409="4${NORM} - Voltar antes da Biblioteca "
    M410="9${NORM} - ${RED}Menu Anterior     "

    printf "\n"
    _linha "=" "${GREEN}"
    _mensagec "${RED}" "${M401}"
#    _linha 
#    _mensagec "${BLUE}" "${M403}"
    _linha "="
    printf "\n"
    _mensagec "${PURPLE}" "${M404}"
    printf "\n"
    _mensagec "${GREEN}" "${M405}"
    printf "\n"
    _mensagec "${GREEN}" "${M406}"
    printf "\n"
    _mensagec "${GREEN}" "${M407}"
    printf "\n\n"
    _mensagec "${PURPLE}" "${M408}"
    printf "\n"
    _mensagec "${GREEN}" "${M409}"
    printf "\n\n"
    _mensagec "${GREEN}" "${M410}"
    printf "\n"
    if [[ -n "${VERSAOANT}" ]]; then
        printf "\n"
        _mensaged "${BLUE}" "${M403}"
    fi
#    _mensaged "${BLUE}" "${M403}"
    _linha "=" "${GREEN}"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO
    case ${OPCAO} in
        1) _transpc ;;
        2) _savatu ;;
        3) _atuoff ;;
        4) _voltabibli ;;
        9) clear; _principal ;;
        *) _opinvalida 
            _read_sleep 1 
            _biblioteca ;;
    esac
}


#-Procedimento da atualizacao de programas---------------------------------------------------------# 
### _atualizacao
# Mostra o menu de atualizacao de programas com opcoes de atualizar via ON-Line ou OFF-Line.
# Chama a funcao escolhida pelo usuario.
_atualizacao() { 
    clear
###   200-mensagens do Menu Programas.
    M201="Menu de Programas "
    M202="Escolha o tipo de Acao:"
    M203="1${NORM} - Programa ou Pacote ON-Line    "
    M204="2${NORM} - Programa ou Pacote em OFF-Line"
    M205="Escolha o tipo de Desatualizacao:         "
    M206="3${NORM} - Voltar programa Atualizado    "
    M209="9${NORM} - ${RED}Menu Anterior        "
    printf "\n"
	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M201}"
	_linha
	printf "\n"
	_mensagec "${PURPLE}" "${M202}"
	printf "\n"
	_mensagec "${GREEN}" "${M203}"
	printf "\n"
	_mensagec "${GREEN}" "${M204}"
	printf "\n\n"
	_mensagec "${PURPLE}" "${M205}"
	printf "\n"
	_mensagec "${GREEN}" "${M206}"
	printf "\n\n"
	_mensagec "${GREEN}" "${M209}"
	printf "\n"        
	_linha "=" "${GREEN}"
    read -rp "${YELLOW}${M110}${NORM}" OPCAO
    case ${OPCAO} in
        1) _pacoteon ;;
        2) _pacoteoff ;;
        3) _voltaprog ;;
        9) clear ; _principal ;;
        *) _opinvalida 
            _read_sleep 1 
            _principal ;;
    esac
}


#-Mostrar a versao do isCobol que esta sendo usada.------------------------------------------------# 
#
# Se o sistema for IsCOBOL, ele ira mostrar a versao do isCobol.
# Se o sistema nao for IsCOBOL, ele ira mostrar uma mensagem de erro.
_iscobol() {
    if [[ "${sistema}" == "iscobol" ]]; then
        if [[ -x "${SAVISC}${ISCCLIENT}" ]]; then
            clear
            _linha "=" "${GREEN}"
            _mensagec "${GREEN}" "Versao do IsCobol"
            _linha "=" "${GREEN}"
            "${SAVISC}${ISCCLIENT}" -v
            _linha "=" "${GREEN}"
            printf "\n\n"
        else
            _linha
            _mensagec "${RED}" "Erro: ${SAVISC}${ISCCLIENT} nao encontrado ou nao executavel."
            _linha
        fi
    elif [[ -z "${sistema}" ]]; then
        # -Variavel de sistema nao configurada
        _linha
        _mensagec "${RED}" "Erro: Variavel de sistema nao configurada."
        _linha
    else
        # -Sistema nao e IsCOBOL
        _linha
        _mensagec "${YELLOW}" "${M05}"
        _linha
    fi
    _press
    _principal
}

#-Mostrar a versao do Linux que esta sendo usada.--------------------------------------------------# 
#-Mostra informacoes sobre o sistema, como:
#
#   - tipo de OS
#   - versao do OS
#   - nome do servidor
#   - IP interno
#   - IP externo
#   - usuarios logados
#   - uso de memoria RAM e SWAP
#   - uso de disco
#   - tempo de uptime do sistema
_linux() {
    clear
    LX="Vamos descobrir qual S.O. / Distro voce esta executando"
    LM="A partir de algumas informacoes basicas o seu sistema, parece estar executando:"
    printf "\n\n"
    _mensagec "${GREEN}" "${LX}"
    _linha
    printf "\n\n"
    _mensagec "${YELLOW}""${LM}"
    _linha

    # Checando se conecta com a internet ou nao
    if ping -c 1 google.com &> /dev/null; then
        printf "${GREEN}"" Internet:""${NORM}""Conectada""%*s\n"
    else
        printf "${GREEN}"" Internet:""${NORM}""Desconectada""%*s\n"
    fi

    # Checando tipo de OS
    os=$(uname -o)
    printf "${GREEN}""Sistema Operacional :""${NORM}""${os}""%*s\n"

    # Checando OS Versao e nome
    if [[ -f /etc/os-release ]]; then
        grep 'NAME\|VERSION' /etc/os-release | grep -v 'VERSION_ID\|PRETTY_NAME' > "${LOG_TMP}osrelease"
        printf "${GREEN}""OS Nome :""${NORM}""%*s\n"
        grep -v "VERSION" "${LOG_TMP}osrelease" | cut -f2 -d\"
        printf "${GREEN}""OS Versao :""${NORM}""%*s\n"
        grep -v "NAME" "${LOG_TMP}osrelease" | cut -f2 -d\"
    else
        printf "${RED}""Arquivo /etc/os-release nao encontrado.""%*s\n"
    fi
    printf "\n"

    # Checando hostname
    nameservers=$(hostname)
    printf "${GREEN}""Nome do Servidor :""${NORM}""${nameservers}""%*s\n"
    printf "\n"

    # Checando Interno IP
    internalip=$(ip route get 1 | awk '{print $7;exit}')
    printf "${GREEN}""IP Interno :""${NORM}""${internalip}""%*s\n"
    printf "\n"

    # Checando Externo IP
    if [[ -n "${SERACESOFF}" ]]; then
        externalip=$(curl -s ipecho.net/plain || printf "Nao disponivel")
        printf "${GREEN}""IP Externo :""${NORM}""${externalip}""%*s\n"
    fi

    _linha
    _press
    clear
    _linha

    # Checando os usuarios logados
    _run_who() {
        "${cmd_who}" > "${LOG_TMP}who"
    }
    _run_who
    printf "${GREEN}""Usuario Logado :""${NORM}""%*s\n"
    cat "${LOG_TMP}who"
    printf "\n"

    # Checando uso de memoria RAM e SWAP
    free | grep -v + > "${LOG_TMP}ramcache"
    printf "${GREEN}""Uso de Memoria Ram :""${NORM}""%*s\n"
    grep -v "Swap" "${LOG_TMP}ramcache"
    printf "${GREEN}""Uso de Swap :""${NORM}""%*s\n"
    grep -v "Mem" "${LOG_TMP}ramcache"
    printf "\n"

    # Checando uso de disco
    df -h | grep 'Filesystem\|/dev/sda*' > "${LOG_TMP}diskusage"
    printf "${GREEN}""Espaco em Disco :""${NORM}""%*s\n"
    cat "${LOG_TMP}diskusage"
    printf "\n"

    # Checando o Sistema Uptime
    tecuptime=$(uptime -p | cut -d " " -f2-)
    printf "${GREEN}""Sistema em uso Dias/(HH:MM) : ""${NORM}""${tecuptime}""%*s\n"

    # Unset Variables
    unset os internalip externalip nameservers tecuptime

    # Removendo temporarios arquivos
    rm -f "${LOG_TMP}osrelease" "${LOG_TMP}who" "${LOG_TMP}ramcache" "${LOG_TMP}diskusage"
    _linha
    _press
    _principal
}


# _varrendo_arquivo: compacta arquivos temporarios no diretorio "${DIRB}" que contenham o nome "${line}" e move para o diretorio "${BACKUP}" com o nome "${TEMPS}-${UMADATA}"
# 
# O comando find e usado para encontrar todos os arquivos temporarios no diretorio "${DIRB}" que contenham o nome "${line}" e o comando zip para compactar e mover para o diretorio "${BACKUP}" com o nome "${TEMPS}-${UMADATA}".
# 
# Parametros:
#   line: nome do arquivo temporario a ser compactado
# 
# Exemplo:
#   _varrendo_arquivo
_varrendo_arquivo() {
    local zip_file_name="Temps-${UMADATA}"
    "${cmd_find}" "${DIRB}" -type f -iname "${file_name}" -exec "${cmd_zip}" -m "${BACKUP}/${zip_file_name}" "{}" + >> "${LOG_LIMPA}" 
}

# _limpando: Exclui todos os arquivos temporarios no diretorio "${DIRB}" com base na lista "atualizat".
#
# O comando find e usado para encontrar todos os arquivos temporarios no diretorio "${DIRB}" que contenham o nome "${file_name}" e o comando rm para exclui-los.
#
# Parametros:
#   NAO TEM
#
# Exemplo:
#   _limpando
_limpando() {
clear
    line_array=""
    if [[ ! -r "${arqs}" ]]; then
        printf "%sErro: Nao foi possivel ler ${arqs}\n" >&2
        return 1
    fi
    mapfile -t line_array < "${arqs}"
    for file_name in "${line_array[@]}"; do
        if [[ -n "${file_name}" ]]; then
            printf "${GREEN}""Excluido todos as arquivos: ${YELLOW}${file_name}${NORM}%s\n"
            _varrendo_arquivo "${DIRB}" "${file_name}"
            fi
    done 
M11="Movendo arquivos Temporarios do diretorio = ""${DIRB}"
_linha 
_mensagec "${YELLOW}" "${M11}"
_linha
}

# _limpeza: Limpeza de arquivos temporarios
#
# Le a lista "atualizat" que contem os arquivos a serem excluidas da base do sistema.
#
# Exclui os arquivos temporarios da pasta "${DIRB}" com base na lista "atualizat".

_limpeza() {
    cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }

    #-Le a lista "atualizat" que contem os arquivos a serem excluidas da base do sistema---------------# 
    #-TESTE Arquivos ----------------------------------------------------------------------------------#
    local atualizat_file="atualizat"
    if [[ ! -e "${atualizat_file}" ]]; then
        printf "ERRO. Arquivo \"${atualizat_file}\", Nao existe no diretorio.%*s\n" >&2
        exit 1
    elif [[ ! -r "${atualizat_file}" ]]; then
        printf "ERRO. Arquivo \"${atualizat_file}\", Sem acesso de leitura.%*s\n" >&2
        exit 1
    fi

#-Rotina para excluir arquivo temporarios----------------------------------------------------------#
    local arqs=""
    arqs="${atualizat_file}"
    TEMPS=$(find "${BACKUP}" -type f -name "Temps*" -mtime +10 -exec rm -rf {} \;) 2>/dev/null
    if [[ -n "${TEMPS}" ]]; then
        local M63="Existe um backup antigo sera excluido do Diretorio ""${DIRDEST}"
        _meiodatela
        _messagec RED "${M63}"
    fi
    for dir_bases in $base $base2 $base3; do
        local DIRB="${destino}${dir_bases}/"
        if [[ -d "${DIRB}" ]]; then
            _limpando
            _press
        else
            printf "ERRO: Diretorio \"%s\" nao existe.\n" "${DIRB}" >&2
        fi
    done
# Chamando ferramentas auxiliares
    _ferramentas
}

# _addlixo: Adiciona um arquivo na lista "atualizat".
#
# Pergunta ao usuario o nome do arquivo a ser adicionado na lista "atualizat".
# Se o usuario nao informar o arquivo, sai da rotina.

_addlixo() {
    clear
    M8A="Informe o nome do arquivo a ser adicionado ao atualizat"
    _meiodatela
    _mensagec "${CYAN}" "${M8A}"
    _linha
    M8B="         Qual o arquivo ->: "
    read -rp "${YELLOW}${M8B}${NORM}" ADDARQ
    _linha

    if [[ -z "${ADDARQ}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M66}"
        _linha
        cd "${TOOLS}"/ || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
        _press
        _temps
        return
    fi
    # Adicionando o arquivo à lista "atualizat"
    echo "${ADDARQ}" >> atualizat
    _mensagec "${CYAN}" "Arquivo '${ADDARQ}' adicionado com sucesso ao 'atualizat'."
    _linha

    # Chamando funções auxiliares
    _temps
}

# _temps: Menu de Limpeza
#
# Mostra o menu de limpeza de arquivos temporarios com opcoes de:
# - Limpar todos os arquivos temporarios no diretorio "${DIRB}".
# - Adicionar arquivos na lista "atualizat" para serem excluidos no diretorio "${DIRB}".
# - Voltar ao menu anterior.

_temps() {
    clear
    M900="Menu de Limpeza"
    M901="1${NORM} - Limpeza dos Arquivos Temporarios"
    M902="2${NORM} - Adicionar Arquivos no ATUALIZAT "
    M909="9${NORM} - ${RED}Menu Anterior          "

    printf "\n"
    _linha "=" "${GREEN}"
    _mensagec "${RED}" "${M900}"
    _linha 
    printf "\n"
    _mensagec "${PURPLE}" "${M103}"
    printf "\n"
    _mensagec "${GREEN}" "${M901}"
    printf "\n"
    _mensagec "${GREEN}" "${M902}"
    printf "\n\n"
    _mensagec "${GREEN}" "${M909}"
    printf "\n"
    _linha "=" "${GREEN}"
    read -rp "${YELLOW}${M110}${NORM}" OPCAO

    case ${OPCAO} in
        1)  _limpeza ;;
        2)  _addlixo ;;
        9)  clear ; _ferramentas ;;
        *) _opinvalida 
           _read_sleep 1 
           _ferramentas ;;
    esac    
}
# Funcao para escolher qual base ser  utilizada.
#
# Permite ao usuario escolher qual base ser utilizada. 
# As bases esta gravada no arquivo atualizac.
_escolhe_base() {
    clear
###-600-mensagens do Menu Rebuild.
    M900="Escolha a Base"
	M901="1${NORM} - Base em ${destino}${base}"
	M902="2${NORM} - Base em ${destino}${base2}"
if [[ ! "${base3}" ]]; then
        M903=""
else
        M903="3${NORM} - Base em ${destino}${base3}"
fi
    M909="9${NORM} - ${RED}Menu Anterior "
    printf "\n"
	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M900}"
	_linha 
	printf "\n"
	_mensagec "${PURPLE}" "${M103}"
	printf "\n"
	_mensagec "${GREEN}" "${M901}"
	printf "\n"
	_mensagec "${GREEN}" "${M902}"
	printf "\n"
    _mensagec "${GREEN}" "${M903}"
    printf "\n\n"
    _mensagec "${GREEN}" "${M909}"
    printf "\n"
    _linha "=" "${GREEN}"
    read -rp "${YELLOW}${M110}${NORM}" OPCAO	

    case ${OPCAO} in
        1) _set_base_diretorio "base" ;;
        2) _set_base_diretorio "base2" ;;
        3) _set_base_diretorio "base3" ;;
        9) clear 
	       _ferramentas ;;
        *) _opinvalida 
           _read_sleep 1 
	       _ferramentas ;;
    esac

}

#-Rotina de recuperar arquivos especifico ou todos se deixar em branco-----------------------------#
##- Rotina para rodar o jutil
# Reconstrói um arquivo específico com jutil.
#
# _jutill irá verificar se o arquivo existe e se tem tamanho maior que zero. 
# Se ambas as condições forem atendidas, ele executará o comando jutil com o
# -rebuild opção no arquivo.
_jutill() {
    if [[ -n "${arquivo}" ]] && [[ -e "${arquivo}" ]] && [[ -s "${arquivo}" ]]; then
        if [[ -x "${jut}" ]]; then
            if ! "${jut}" -rebuild "${arquivo}" -a -f; then
                _mensagec "${RED}" "Erro: Falha ao reconstruir o arquivo ${arquivo}."
                _linha "-" "${RED}"
                return 1
            fi
            _linha "-" "${GREEN}"
        else
            _mensagec "${RED}" "Erro: Jutil nao encontrado."
            return 1
        fi
    else
        _mensagec "${YELLOW}" "Erro: Arquivo ${arquivo} nao encontrado ou está vazio."
        return 1
    fi
}

_set_base_diretorio() {
    local base_var="$1"  # base, base2, or base3
    local base_dir="${!base_var}" # Get the value of the variable dynamically

    if [[ -z "${destino}" ]]; then
        _mensagec "${RED}" "Erro: Variavel de ambiente destino nao esta configurada."
        _linha "-" "${RED}"
        _read_sleep 2
        _ferramentas
        return 1
    fi
    if [[ -z "${base_dir}" ]]; then
        _mensagec "${RED}" "Erro: Variavel de ambiente ${base_var} nao esta configurada."
        _linha "-" "${RED}"
        _read_sleep 2
        _ferramentas
        return 1
    fi
    BASE1="${destino}${base_dir}"
}

# _rebuilall: Rotina para reconstruir um arquivo especifico com jutil ou todos os arquivos.
#
# Se o nome do arquivo for deixado em branco, ele irá reconstruir todos os arquivos na pasta
# "${destino}${base}" com as extens es *.ARQ.dat, *.DAT.dat, *.LOG.dat e *.PAN.dat.
#
# Se o nome do arquivo for informado, ele irá reconstruir somente o arquivo com o nome informado
# e as extens es *.ARQ.dat, *.DAT.dat, *.LOG.dat e *.PAN.dat.
#
# A rotina irá verificar se o arquivo existe e se tem tamanho maior que zero.
# Se ambas as condi es forem atendidas, ele executar  o comando jutil com a op o -rebuild
# no arquivo.
_rebuildall() {
    local base_to_use

    # Determina a base a ser usada
    if [[ -n "${base2}" ]]; then
        _escolhe_base
        base_to_use="${BASE1}"
    fi

    clear
    if [[ "${sistema}" != "iscobol" ]]; then
        _meiodatela
        M996="Recuperacao em desenvolvimento :"
        _mensagec "${RED}" "${M996}"
        _press
        _rebuild1
        return
    fi
    # Solicita o nome do arquivo
        _meiodatela
        _mensagec "${CYAN}" "${M64}"
        _linha
        read -rp "${YELLOW}Informe o nome do arquivo: ${NORM}" arquivo

        _linha "-" "${BLUE}"
        if [[ -z "${arquivo}" ]]; then
            _meiodatela
            _mensagec "${RED}" "${M65}"
            _linha "-" "${YELLOW}"
            if [[ -d "${base_to_use}" ]]; then
                local -a files=("${base_to_use}"/{*.ARQ.dat,*.DAT.dat,*.LOG.dat,*.PAN.dat})
                for arquivo in "${files[@]}"; do
                    if [[ -f "${arquivo}" ]] && [[ -s "${arquivo}" ]]; then
                        _jutill "${arquivo}"
                    else
                        _mensagec "${YELLOW}" "Erro: Arquivo ${arquivo} nao encontrado ou esta vazio."
                        _linha
                    fi
                done
            else
                _mensagec "${RED}" "Erro: Diretorio ${base_to_use} Nao existe."
            fi
        else
            while [[ "${arquivo}" =~ [^A-Z0-9] || -z "${arquivo}" ]]; do
                _meiodatela
                _mensagec "${RED}" "${M66}"
                cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
                _press
                _ferramentas
            done
            local arquivo_com_extensao="${arquivo}.???.dat"
            for arquivo in "${base_to_use}"/${arquivo_com_extensao}; do
                if [[ -f "${arquivo}" ]]; then
                    "${jut}" -rebuild "${arquivo}" -a -f
                else
                    _mensagec "${YELLOW}" "Erro: Arquivo ${arquivo} nao encontrado."
                    _linha
                fi
                _linha "-" "${GREEN}"
            done
        fi
        _linha "-" "${YELLOW}"
        _mensagec "${YELLOW}" "${M18}"
        _linha

        cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    
    _press
    _rebuild
}

# _rebuildlista: Rotina de recuperacao de arquivos especificos 
#                com base em uma lista "atualizaj2" que esta no
#                diretorio "${TOOLS}".
# 
# Com base na lista "atualizaj2" ele ira reconstruir os arquivos
# ATE*.dat e NFE*.dat na pasta "${BASE1}".
# 
# Se o arquivo "atualizaj2" nao existir, sera gerado com base
# nos arquivos ATE*.dat e NFE*.dat na pasta "${BASE1}".
# 
# Se o arquivo "atualizaj2" nao for encontrado, sera exibido
# um erro e o programa sera encerrado.
# 
# Parametros:
#   Nenhum.
_rebuildlista() {
    local arquivo var_ano var_ano4

    cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    # Escolhe a base, se necessário
    if [[ "${base2}" ]]; then
        _escolhe_base
    fi
    if [[ "${sistema}" = "iscobol" ]]; then
        cd "${BASE1}" || { printf "Erro: Diretorio ${BASE1} nao encontrado.""%*s\n"; exit 1; }  
        #-Rotina para gerar o arquivos atualizaj2 adicionando os arquivos abaixo---------------------------#
        var_ano=$(date +%y)
        var_ano4=$(date +%Y)
        ls ATE"${var_ano}"*.dat > "${TOOLS}""/""atualizaj2"
        ls NFE?"${var_ano4}".*.dat >> "${TOOLS}""/""atualizaj2"
        _read_sleep 1
        cd "-" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
        #-Arquivos Ates e NFEs ----------------------------------------------------------------------------#
        if [[ ! -e "atualizaj2" ]]; then
            printf "ERRO. Arquivo atualizaj2, Nao existe no diretorio.\n" >&2
            exit 1
        fi
        
        if [[ ! -r "atualizaj2" ]]; then
            printf "ERRO. Arquivo atualizaj2, Sem acesso de leitura.\n" >&2
            exit 1
        fi
#--------------------------------------------------------------------------------------------------#
# Trabalhando lista do arquivo "atualizaj" #
        while read -r line || [[ -n "${line}" ]]; do
            if [[ -z "${line}" ]]; then
                _meiodatela
                _mensagec "${RED}" "Nao foi encontrado o arquivo ${line}"
                _linha
            else
                arquivo="${BASE1}""/""${line}"
                if [[ -e "${arquivo}" ]]; then
                   _jutill
                else
                    _meiodatela
                    _mensagec "${RED}" "Nao foi encontrado o arquivo ${arquivo}"
                    _linha
                       
                fi
            fi
        done < atualizaj
# Trabalhando lista do arquivo "atualizaj2" #
        while read -r line; do
            if [[ -z "${line}" ]]; then
                arquivo="${BASE1}""/""${line}"
                if [[ ! -e "${arquivo}" ]]; then
                    _jutill 
                else
                    se                    
                    _meiodatela
                    _mensagec "${RED}" "Nao foi encontrado o arquivo ""${arquivo}"
                    _linha
                fi
            fi
        done < atualizaj2
    #-Lista de Arquivo(s) recuperado(s)... 
        _linha "-" "${YELLOW}"
        _mensagec "${YELLOW}" "${M12}"
        _linha 
    #     _press
    else
        _meiodatela
        #M996="Recuperacao para este sistema nao disponivel:"
        _mensagec "${RED}" "${M996}"
    fi
    _press
    _rebuild
}


#-Rotina de recuperar arquivos---------------------------------------------------------------------#
# _rebuild: Recupera arquivo(s) do backup.
#
# Pergunta ao usuario qual a opcao para recuperar o(s) arquivo(s):
#   1 - Um arquivo ou Todos
#   2 - Arquivos Principais
#   9 - Menu Anterior

_rebuild() { 
    if [[ -e "${TOOLS}"/"atualizaj2" ]]; then
        rm -rf "${TOOLS}"/"atualizaj2" || {
        _mensagec "${RED}" "Error: falha ao remover o arquivo ${TOOLS}/atualizaj2."
        return 1
        }   
    fi

    clear

###-600-mensagens do Menu Rebuild.
    M601="Menu de Recuperacao de Arquivo(s)."
	M603="1${NORM} - Um arquivo ou Todos   "
	M604="2${NORM} - Arquivos Principais   "
    M605="9${NORM} - ${RED}Menu Anterior"
#Display Menu    
	printf "\n"
	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M601}"
	_linha 
	printf "\n"
	_mensagec "${PURPLE}" "${M103}"
	printf "\n"
	_mensagec "${GREEN}" "${M603}"
	printf "\n"
	_mensagec "${GREEN}" "${M604}"
	printf "\n\n"
    _mensagec "${GREEN}" "${M605}"
    printf "\n"
    _linha "=" "${GREEN}"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO	

    case ${OPCAO} in
    1) _rebuildall ;;
    2) _rebuildlista ;;
    9) clear ; _ferramentas ;;
    *) _opinvalida 
        _read_sleep 1 
        _ferramentas ;;
    esac
}


    #----------------------------------------------------------------------------------------------
    # _backup
    #----------------------------------------------------------------------------------------------
    #
    # Realiza o backup da pasta de dados para o diretório de backup com o nome
    # "Empresa_YYYYMMDDHHMM.zip". Verifica se o backup recente (últimos 2 dias) existe e
    # informa ao usuário caso exista. Após o backup, remove arquivos temporários e
    # compacta novamente o backup para enviar ao servidor da SAV.
    #
_backup() { # funcionando
    # Limpa a tela
    clear
    
    # Verifica se base2 está definida e chama função de escolha
    [ -n "$base2" ] && _escolhe_base
    
    # Cria diretório de backup se não existir
    if [ ! -d "$BACKUP" ]; then
        M23="Criando o diretorio dos backups em $BACKUP..."
        _linha && _mensagec "$YELLOW" "$M23" && _linha
        mkdir -p "$BACKUP" || {
            _mensagec "$RED" "Erro ao criar diretorio de backup"
            return 1
        }
    fi
    
    # Define nome do arquivo de backup com timestamp
    local backup_file
    backup_file="${EMPRESA}_$(date +%Y%m%d%H%M).zip"
    local backup_path="$BACKUP/$backup_file"

    # Verifica backups recentes (últimos 2 dias)
    if find "$BACKUP" -maxdepth 1 -ctime -2 -name "${EMPRESA}*zip" -print -quit | grep -q .; then
        M62="Ja existe um backup recente em $BACKUP."
        _linha && _mensagec "$CYAN" "$M62" && _linha
        ls -ltrh "${BACKUP}"/"${EMPRESA}"_*.zip
        _linha
        # Prompt de confirmação mais robusto
#        while true; do
        read -r -p "${YELLOW}Deseja continuar? (N/s): ${NORM}" answer
            case "${answer,,}" in
                n|"") 
                    _linha && _mensagec "$RED" "$M47" &&  _linha && _read_sleep 3 && _ferramentas && return ;;
                s)
                    _linha &&  _mensagec "$YELLOW" "$M06" && _linha ;;
                *)
                    _opinvalida && return ;;
            esac
    fi
    
    # Muda para diretório base com verificação
    cd "$BASE1" || {
        _mensagec "$RED" "Erro: Nao foi possivel acessar $BASE1"
        return 1
    }
    _linha && _mensagec "$YELLOW" "$M14" && _linha
    
    # Função de progresso simplificada
    _show_progress() {
        local chars=("#" "-" "*" "+")
        local i=0
        echo -n "${YELLOW}Aguarde [${NORM}"
        while kill -0 "$1" 2>/dev/null; do
		    printf "%s${GREEN}${chars[$((i++ % 4))]}${NORM}"
#            i=$((i+1))
            sleep 3
        done
    }
    
    # Executa backup com tratamento de erro
    {
        "$cmd_zip" -u "$backup_path" ./*.* -x ./*.zip ./*.tar ./*tar.gz >/dev/null 2>&1
    } & backup_pid=$!
    
    # Inicia progresso em background
    _show_progress $backup_pid &
    progress_pid=$!
    
    # Aguarda backup completar e verifica status
    if wait $backup_pid; then
        kill $progress_pid 2>/dev/null
        wait $progress_pid 2>/dev/null
        echo "${YELLOW}] Concluido${NORM}"
        
        M10="O backup $backup_file"
        M32="foi criado em $BACKUP"
        _linha
        _mensagec "$YELLOW" "$M10"
        _mensagec "$YELLOW" "$M32"
        _linha
    else
        kill $progress_pid 2>/dev/null
        wait $progress_pid 2>/dev/null
        printf "%s${RED}] Falha no backup${NORM}"
        _mensagec "$RED" "Erro ao criar o backup"
        return 1
    fi
    
    _linha && _mensagec "$YELLOW" "$M16" && _linha
    _send_and_manage_backup "$backup_file"
}    
# Função complementar para envio e gerenciamento do backup
_send_and_manage_backup() {
    local backup_file="$1"  # Recebe o nome do arquivo de backup como parâmetro
    
    # Mensagem inicial
    MA116="Backup sera enviado para o diretario: ${ENVIABACK:-"nao especificado"}"
    _mensagec "${YELLOW}" "${MA116}"
    _linha
        # Confirmação de envio simplificada
    read -r -p "${YELLOW}${M40:-"Deseja enviar o backup? (S/n): "}${NORM}" answer
    case "${answer,,}" in
        [Nn]|"")
            _ferramentas && return ;;
        [Ss]) ;;
        *) _opinvalida && _ferramentas && return ;;
    esac
            # Se SERACESOFF está definido, move localmente
            if [ -n "${SERACESOFF}" ]; then
                local dest_dir="${destino}${SERACESOFF}"
                mkdir -p "${dest_dir}" || {
                    _mensagec "${RED}" "Erro ao criar diretorio ${dest_dir}"
                    return 1
                }
                if mv -f "${BACKUP}/${backup_file}" "${dest_dir}"; then
                    MA11="Backup enviado para o diretorio: ${dest_dir}"
                    _linha
                    _mensagec "${YELLOW}" "${MA11}"
                    _linha
                    _press
                    _ferramentas
                    return
                else
                    _mensagec "${RED}" "Erro ao mover o backup para ${dest_dir}"
                    return 1
                fi
            fi
            
            # Determina o destino remoto
            local remote_dest
            remote_dest="${ENVIABACK}:-"
            if [ -z "${ENVIABACK}" ]; then 
                _meiodatela
                _mensagec "${RED}" "${M68}"

                read -r -p "${YELLOW}${M41}${NORM}"remote_dest
                # Validação simples: não aceita vazio
                until [ -n "$remote_dest" ]; do
                _meiodatela 
                _mensagec "$RED" "$M69" 
                read -r -p "Digite o diretorio remoto: " remote_dest
                done
            fi
            
            # Envia backup via rsync
            _linha && _mensagec "${YELLOW}" "${M29}" && _linha
            if rsync -avzP -e "ssh -p ${PORTA}" "${BACKUP}/${backup_file}" "${USUARIO}@${IPSERVER}:/${remote_dest}"; then
                M15="Backup enviado para a pasta \"${remote_dest}\"."
                _linha
                _mensagec "${YELLOW}" "${M15}"
                _linha
                _read_sleep 3
            else
                _mensagec "${RED}" "Erro ao enviar backup para ${remote_dest}"
                return 1
            fi 
    # Gerenciamento do backup local        
     read -r -p "${YELLOW}Mantem o backup local? (S/n): ${NORM}" keep
     if [[ "${keep,,}" =~ ^[n]$ ]]; then  # Apenas "n" ou "N" remove
        if rm -f "${BACKUP}/${backup_file}"; then
            M170="Backup local excluido"
            _linha && _mensagec "${YELLOW}" "${M170}" && _linha && _press
        else
            _mensagec "${RED}" "Erro ao excluir backup local"
        fi
     fi
    _ferramentas
}

#-Enviar backup avulso-----------------------------------------------------------------------------#
#
# Envia backup avulso para o servidor da SAV.
#
# Opcao   1 - Envia o backup para o servidor da SAV.
# Opcao   2 - Envia o backup para o diretorio especificado na variavel
#          de ambiente SERACESOFF.
#
# As opcoes sao:
#    1 - Envia o backup para o servidor da SAV.
#    2 - Envia o backup para o diretorio especificado na variavel
#       de ambiente SERACESOFF.
_backupavulso() {
    local VBACKAV VBACKUP REPLY ENVBASE SAOFF

    while true; do
        clear 
        _linha
        ls -lhs "${BACKUP}/${EMPRESA}"_*.zip 2>/dev/null || _mensagec "${RED}" "Nenhum backup encontrado em ${BACKUP}"
        _linha 
        _mensagec "${RED}" "${M52}"  # "Selecione um backup para enviar"
        _linha      
        read -rp "${YELLOW}${M42} (ou digite'sair' para cancelar): ${NORM}" VBACKAV

        # Verifica se o usuário quer sair
        if [[ "${VBACKAV,,}" == "sair" ]]; then
            _linha
            _mensagec "${YELLOW}" "Operacao cancelada."
            _linha
            _press
            _ferramentas
            return
        fi

        # Valida se VBACKAV está vazio
        if [[ -z "${VBACKAV}" ]]; then
            clear
            _meiodatela
            _mensagec "${RED}" "${M70}"  # "Erro: campo não pode estar vazio"
            _linha
            _press
            continue
        fi

        VBACKUP="${EMPRESA}_${VBACKAV}.zip"
        
        # Verifica se o arquivo existe
        if [[ ! -f "${BACKUP}/${VBACKUP}" ]]; then
            clear
            _meiodatela
            _mensagec "${RED}" "${M45}"  # "Backup não encontrado"
            _press
            continue
        fi

        # Se chegou aqui, o backup é válido
        break
    done

    clear && _meiodatela && _linha && _mensagec "${YELLOW}" "O backup \"${VBACKUP}\" foi selecionado."

    # Move o backup localmente se SERACESOFF estiver definido
    if [[ -n "${SERACESOFF}" ]]; then
        SAOFF="${destino}${SERACESOFF}"
        if mv -f "${BACKUP}/${VBACKUP}" "${SAOFF}" 2>/dev/null; then
            _linha 
            _mensagec "${YELLOW}" "Backup enviado para o diretorio: ${SAOFF}"
            _linha && _press && _ferramentas && return
        else
            _mensagec "${RED}" "Erro ao mover o backup para ${SAOFF}"
            _press && _ferramentas && return
        fi
    fi

    # Pergunta se o usuário quer enviar o backup remotamente
    _linha 
    read -rp "${YELLOW}${M40}${NORM} (S/N): " -n1 REPLY
    printf "\n\n"
    case "${REPLY,,}" in
        n|"") 
            _mensagec "${YELLOW}" "Operacao concluida sem envio remoto." 
            _linha && _press
            _ferramentas
            ;;
        s) 
            if [[ -n "${ENVIABACK}" ]]; then
                ENVBASE="${ENVIABACK}"
            else
                _meiodatela
                _mensagec "${RED}" "${M68}"  # "Digite o caminho de destino"
                _linha
                read -rp "${YELLOW}${M41}${NORM}: " ENVBASE
                while [[ "${ENVBASE}" =~ [0-9] || -f "${ENVBASE}" ]]; do
                    _meiodatela
                    _mensagec "${RED}" "${M69}"  # "Caminho inválido"
                    _press    
                    read -rp "${YELLOW}${M41}${NORM}: " ENVBASE
                done
            fi

            _linha 
            _mensagec "${YELLOW}" "${M29}"  # "Enviando backup via rsync..."
            _linha 
            if [[ -n "${IPSERVER}" && -n "${PORTA}" && -n "${USUARIO}" ]]; then
                if rsync -avzP -e "ssh -p ${PORTA}" "${BACKUP}/${VBACKUP}" "${USUARIO}@${IPSERVER}:${ENVBASE}" 2>/dev/null; then
                    _mensagec "${YELLOW}" "Backup enviado para \"${ENVBASE}\" no servidor ${IPSERVER}."
                    _linha 
                    _read_sleep 3 
                    _ferramentas
                else
                    _mensagec "${RED}" "Erro ao enviar o backup via rsync."
                    _press
                    _ferramentas
                fi
            else
                _meiodatela
                _mensagec "${RED}" "${M71}"  # "Detalhes do servidor (IP/Porta/Usuário) ausentes"
                _press    
                _ferramentas
            fi
            ;;
        *)
            _opinvalida
            _read_sleep 1
            _press
            _ferramentas   
            ;;
    esac
}

#-VOLTA BACKUP TOTAL OU PARCIAL--------------------------------------------------------------------#
# Esta função trata do processo de restauração de um backup anterior do sistema.
# Ele solicita ao usuário a data do backup para restaurar e verifica a existência do
# arquivo de backup no diretório especificado. Se o backup não for encontrado, ele retorna ao menu anterior.
# O usuário é questionado se deseja restaurar todos os arquivos para o estado anterior à atualização. Baseado em
# resposta do usuário, ele restaura arquivos específicos ou todos os arquivos para suas versões anteriores.
_unbackup() {
    local DIRBACK="${BACKUP}"  # Define um padrão se BACKUP não estiver setado

    # Verifica se BACKUP e EMPRESA estão definidos
    if [[ -z "${BACKUP}" || -z "${EMPRESA}" ]]; then
        _mensagec "${RED}" "Variaveis BACKUP ou EMPRESA nao definidas"
        _press
        return 1
    fi

    # Cria diretório de backup se não existir
    if [[ ! -d "${DIRBACK}" ]]; then
        _mensagec "${YELLOW}" "Criando diretorio temporario em ${DIRBACK}..."
        mkdir -p "${DIRBACK}" || {
            _mensagec "${RED}" "Falha ao criar diretorio ${DIRBACK}"
            _press
            return 1
        }
    fi

    # Lista backups disponíveis
    if ! ls -lh "${DIRBACK}""/""${EMPRESA}"_*zip 2>/dev/null; then
        _mensagec "${RED}" "Nenhum backup encontrado para ${EMPRESA}"
    fi
    _linha
    _mensagec "${RED}" "${M53}"
    _linha

    # Solicita data do backup
    local VBACK=""
    read -rp "${YELLOW}1- Informe somente a data do BACKUP: ${NORM}" VBACK
    [[ -z "${VBACK}" ]] && {
        _mensagec "${RED}" "${M70}"
        _press
        _menubackup
        return 1
    }
    local VBACKUP="${EMPRESA}_${VBACK}.zip"
    local backup_path="${DIRBACK}/${VBACKUP}"

    # Verifica se o backup existe e é legível
    if [[ ! -f "${backup_path}" || ! -r "${backup_path}" ]]; then
        _mensagec "${RED}" "Backup ${VBACKUP} nao encontrado ou nao legivel"
        _press
        _menubackup
        return 1
    fi

    # Pergunta sobre restauração completa
    _linha
    read -rp "${YELLOW}${M35}${NORM}" -n1 REPLY
    printf "\n\n"

    case "${REPLY,,}" in
        n|"")
            # Restauração de arquivo específico
            local VARQUIVO=""
            _linha
            read -rp "${YELLOW}2- Informe o nome do arquivo (maiusculo, sem a extensao): ${NORM}" VARQUIVO
            _linha

            # Valida nome do arquivo
            if [[ ! "${VARQUIVO}" =~ ^[A-Z0-9]+$ || -z "${VARQUIVO}" ]]; then
                _mensagec "${RED}" "${M71}" && _linha && _press
                _menubackup
                return 1
            fi

            _linha
            _mensagec "${YELLOW}" "Restaurando arquivo ${VARQUIVO}..."
            _linha
            if ! "${cmd_unzip:-unzip}" -o "${backup_path}" "${VARQUIVO}*.*" -d "${BASE1}" >> "${LOG_ATU}" 2>>"${LOG_ATU}"; then
                _mensagec "${YELLOW}" "Erro ao extrair ${VARQUIVO}"
                _linha &&  _press
                _menubackup
                return 1
            fi

            if ls "${BASE1}/${VARQUIVO}"*.* >/dev/null 2>&1; then
                _mensagec "${GREEN}" "Arquivo ${VARQUIVO} restaurado com sucesso"
            else
                _mensagec "${YELLOW}" "Arquivo ${VARQUIVO} nao encontrado apos restauracao"
                _linha && _press
                _menubackup
                return 1
            fi
            ;;

        s)
            # Restauração completa
            _linha
            _mensagec "${YELLOW}" "Restaurando todos os arquivos do backup..."
            _linha
            if ! "${cmd_unzip:-unzip}" -o "${backup_path}" -d "${BASE1}" >> "${LOG_ATU}" 2>>"${LOG_ATU}"; then
                _mensagec "${RED}" "Erro ao restaurar backup completo"
                _linha && _press
                _menubackup
                return 1
            fi
            _mensagec "${GREEN}" "Restauracao completa concluida"
            _linha
            ;;

        *)
            _mensagec "${RED}" "Opcao invalida"
            _linha && _press
            return 1
            ;;
    esac

    _press
    _menubackup
    _ferramentas
}

_menubackup() { 
while true ; do
clear

###-700-mensagens do Menu Backup.
    M700="Menu de Backup(s).         "
    M702="1${NORM} - Backup da base de dados          "
    M703="2${NORM} - Restaurar Backup da base de dados"
    M704="3${NORM} - Enviar Backup                    "
    M705="9${NORM} - ${RED}Menu Anterior           "

    # Display Menu
	printf "\n"
	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M700}"
	_linha 
	printf "\n"
	_mensagec "${PURPLE}" "${M103}"
	printf "\n"
	_mensagec "${GREEN}" "${M702}"
	printf "\n"
	_mensagec "${GREEN}" "${M703}"
	printf "\n"
	_mensagec "${GREEN}" "${M704}"
    printf "\n\n"
	_mensagec "${GREEN}" "${M705}"
    printf "\n"       
	_linha "=" "${GREEN}"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO	

    # Processar opcao
    case ${OPCAO} in
    1) _backup       ;;
    2) _unbackup     ;;
    3) _backupavulso ;;
    9) clear; _ferramentas; return ;;
     *) _opinvalida 
        _read_sleep 1  
        _menubackup ;;
    esac
done
}

###---_envia_avulso-------------------------------------------------------------
##  Funcao para Enviar um arquivo avulso.
##  Chama as funcoes _envia_avulso() e _recebe_avulso() para o envio e recebimento de arquivos.
##  Opcoes:
##  1 - Envia arquivo(s)
##  2 - Recebe arquivo(s)
##  9 - Menu Anterior
##-----------------------------------------------------------------------------------------------
_envia_avulso() {
    clear
    printf "\n\n\n"
### Pedir diretorio origem do arquivo    
    _linha 
M991="1- Origem: Informe em que diretorio esta o arquivo a ser enviado :"   
    _mensagec "${YELLOW}" "${M991}"  
    read -rp "${YELLOW}"" -> ""${NORM}" DIRENVIA
    _linha 
if [[ -d "${DIRENVIA}" ]]; then
    printf "\n"
else
    clear
    _meiodatela
M995="Diretorio nao foi encontrado no servidor"
    _linha 
    _mensagec "${RED}" "${M995}"  
    _linha 
    _press
    _envrecarq
fi
if [[ -z "${DIRENVIA}" ]]; then # testa variavel vazia
    local DIRENVIA=${ENVIA}
    if ls -s "${DIRENVIA}"/*.* ; then
#-Arquivo encontrado no diretorio
    printf "\n"
    _linha
    _mensagec "${YELLOW}" "${M28}"
    _linha
    else
M49="Arquivo nao encontrado no diretorio"
    _linha 
    _mensagec "${YELLOW}" "${M49}"  
    _linha 
#      _press 
    _ferramentas  
    fi
fi
    _linha 
    _mensagec "${CYAN}" "${M72}" #Informe o arquivo(s) que deseja enviar.
    _linha 
    MB3="2- Informe nome do ARQUIVO: -> "     
    local EENVIA=" "
    read -rp "${YELLOW}${MB3}${NORM}" EENVIA
if [[ -z "${EENVIA}" ]]; then 
#   clear
    _meiodatela
    _mensagec "${RED}" "${M74}"
    _linha
    _press
    _envrecarq
fi
if [[ ! -e "${DIRENVIA}""/""${EENVIA}" ]]; then
    _linha
M49="$EENVIA Arquivo nao encontrado no diretorio"
    _linha 
    _mensagec "${YELLOW}" "${M49}"  
    _linha 
    _press 
    _envrecarq  
fi
    printf "\n"
    _linha 
M992="3- Destino: Informe para qual diretorio no servidor:"   
    _mensagec "${YELLOW}""${M992}"  
    read -rp "${YELLOW}"" -> ""${NORM}" ENVBASE
    _linha 
if [[ -z "${ENVBASE}" ]]; then
    _meiodatela
#M69  
    _mensagec "${RED}" "${M69}"
    _press    
    _envrecarq 
fi
#-Informe a senha do usuario do rsync
    _linha 
    _mensagec "${YELLOW}" "${M29}"
    _linha 
    rsync -avzP -e "ssh -p ${PORTA}" "${DIRENVIA}"/"${EENVIA}" "${USUARIO}"@"${IPSERVER}":"${ENVBASE}" 
M15="Backup enviado para a pasta, \"""${ENVBASE}""\"."
    _linha 
    _mensagec "${YELLOW}" "${M15}"
    _linha 
    _read_sleep 3
    _envrecarq
}
##---recebe_avulso-------------------------------------
# _recebe_avulso()
# 
# Recebe um arquivo avulso via rsync do servidor da SAV.
# 
# - Informe a origem, nome do arquivo e o destino do arquivo.
# - O usuario do rsync sera o mesmo do usuario do atualiza.sh.
# - O diretorio do arquivo recebido sera o mesmo do diretorio do atualiza.sh.
_recebe_avulso() {
    clear
    _linha 
M993="1- Origem: Informe em qual diretorio esta o arquivo a ser RECEBIDO :"   
    _mensagec "${YELLOW}""${M993}"  
    read -rp "${YELLOW}"" -> ""${NORM}" RECBASE
    _linha 
    _linha 
    _mensagec "${RED}" "${M73}"
    _linha
    MB2="    2- Informe nome do ARQUIVO: "      
    read -rp "${YELLOW}${MB2}${NORM}" RRECEBE
if [[ -z "${RRECEBE}" ]]; then 
    _meiodatela
    _mensagec "${RED}" "${M74}"
    _linha
    _press
    _envrecarq
fi
    _linha 
M994="3- Destino:Informe diretorio do servidor que vai receber arquivo: " 
    _mensagec "${YELLOW}""${M994}"  
    read -rp "${YELLOW}"" -> ""${NORM}" EDESTINO
if [[ -z "${EDESTINO}" ]]; then # testa variavel vazia
local EDESTINO=${RECEBE}
fi
    _linha 
    local VERDIR="${EDESTINO}"
if [[ -d "${VERDIR}" ]]; then
    printf "\n"
else
    clear
    _meiodatela
M995="Diretorio nao foi encontrado no servidor"
    _linha 
    _mensagec "${RED}" "${M995}"
    _linha 
    _press
    _envrecarq
fi

#-Informe a senha do usuario do rsync
    _linha 
    _mensagec "${YELLOW}" "${M29}"
    _linha 
    rsync -avzP -e "ssh -p ${PORTA}" "${USUARIO}"@"${IPSERVER}":"${RECBASE}""/""${RRECEBE}" "${EDESTINO}""/". 
M15="Arquivo enviado para a pasta, \"""${EDESTINO}""\"."
    _linha 
    _mensagec "${YELLOW}" "${M15}"
    _linha 
    _read_sleep 3
_envrecarq      
}


###-Funcao _envrecarq---------------------------------------------------------------
##  Menu de Envio e Retorno de Arquivos.
##  Chama as funcoes _envia_avulso() e _recebe_avulso() para o envio e recebimento de arquivos.
##  Opcoes:
##  1 - Envia arquivo(s)
##  2 - Recebe arquivo(s)
##  9 - Menu Anterior
##-----------------------------------------------------------------------------------------------
_envrecarq() { 
clear
###-800-mensagens do Menu Envio e Retorno.
    M800="Menu de Enviar e Receber Arquivo(s)."
    M802="1${NORM} - Enviar arquivo(s)     "
    M803="2${NORM} - Receber arquivo(s)    "
    M806="9${NORM} - ${RED}Menu Anterior"
	
    printf "\n"
	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M800}"
	_linha 
	printf "\n"
	_mensagec "${PURPLE}" "${M103}"
	printf "\n"
	_mensagec "${GREEN}" "${M802}"
	printf "\n"
	_mensagec "${GREEN}" "${M803}"
	printf "\n\n"
	_mensagec "${GREEN}" "${M806}"
    printf "\n"       
	_linha "=" "${GREEN}"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO	
    
    case ${OPCAO} in
    1) _envia_avulso    ;;
    2) _recebe_avulso   ;;
    9) clear ; _ferramentas ;;
     *) _opinvalida 
        _read_sleep 1  
        _envrecarq ;;
    esac
}

########################################################
# Limpando arquivos de atualizacao com mais de 30 dias #
########################################################
# _expurgador ()
# Limpa arquivos de atualizacao com mais de 30 dias na pasta de backup.
# Apaga todos os arquivos do diretorio backup, olds, progs e logs.
# Apaga arquivos do diretorio do /portalsav/log e /err_isc/.
_expurgador() {
clear
#-Apagar Biblioteca--------------------------------------------------# 
#-Verificando e/ou excluido arquivos com mais de 30 dias criado.------#
    _linha 
    _mensagec "${RED}" "${M51}"
    _linha 
#     _read_sleep 3
    printf "\n\n"
# Apagando todos os arquivos do diretorio backup#
MDIR="Limpando os arquivos do diretorio: "
    local DIR1="${BACKUP}""/"
    local DIR2="${OLDS}""/"
    local DIR3="${PROGS}""/"
    local DIR4="${LOGS}""/"
SAVLOG="$destino""/sav/portalsav/log" 
    local DIR5="${SAVLOG}""/"
ERR_ISC="$destino""/sav/err_isc" 
    local DIR6="${ERR_ISC}""/"
VIEWVIX="$destino""/sav/savisc/viewvix/tmp"
    local DIR7="${VIEWVIX}""/"
    for ARQS in $DIR1 $DIR2 $DIR3 $DIR4 $DIR5 $DIR6 $DIR7; do
        if [[ -d "${ARQS}" ]]; then
            "${cmd_find}" "${ARQS}" -mtime +30 -type f -delete 
            _mensagec "${GREEN}" "${MDIR}${ARQS}"
        else
            _mensagec "${YELLOW}" "${MDIR}${ARQS}""n: diretorio nao encontrado"
        fi
    done
printf "\n\n"     
_press
cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
_ferramentas
}

#-Atualizacao online-------------------------------------------------------------------------------#
# _update ()
# 
# Atualiza o atualiza.sh via Github, sempre que o programa for executado.
# 
# Baixa o atualiza.sh do Github, descompacta o arquivo, copia o programa
# descompactado para o diretorio do atualiza.sh, remove o diretorio
# descompactado e remove o arquivo descompactado.
# 
# O programa sempre sera atualizado via internet, caso o servidor tenha
# acesso a rede.

_update_online() {
    local link="https://github.com/Luizaugusto1962/Atualiza/archive/master/atualiza.zip"
    local zipfile="atualiza.zip"
    
    _mensagec "${GREEN}" "Atualizando o script via GitHub..."
    cp -f atualiza.sh "${BACKUP}/atualiza.sh.bak" || {
        _mensagec "${RED}" "Erro ao criar backup do atualiza.sh."
        return 1
    }
    
    cd "$PROGS" || { _mensagec "${RED}" "Erro: Diretorio $PROGS nao acessivel."; return 1; }
    wget -q -c "$link" -O "$zipfile" || {
        _mensagec "${RED}" "Erro ao baixar $zipfile."
        return 1
    }
    
    "$cmd_unzip" -o "$zipfile" -d . >> "$LOG_ATU" 2>&1 || {
        _mensagec "${RED}" "Erro ao descompactar $zipfile."
        return 1
    }
    
    rm -f "$zipfile"
    cd "Atualiza-main" || { _mensagec "${RED}" "Erro: Diretorio Atualiza-main nao encontrado."; return 1; }
    for file in atualiza.sh setup.sh; do
        [ -f "$file" ] || { _mensagec "${RED}" "Erro: $file nao encontrado."; return 1; }
        chmod +x "$file"
        mv -f "$file" "$TOOLS" || { _mensagec "${RED}" "Erro ao mover $file."; return 1; }
    done
    
    cd "$PROGS" && rm -rf Atualiza-main
    _linha
    _mensagec "${GREEN}" "${M91}"
    _mensagec "${GREEN}" "${M92}"
    _linha
    exit 0
}

# _update_offline: Atualiza o script via um arquivo zip baixado previamente.
#
# Esta funcao e responsavel por atualizar o script via um arquivo zip baixado
# previamente. Ela extrai o conteudo do arquivo zip e move os arquivos para o
# diretorio $TOOLS. Se o arquivo zip nao for encontrado, uma mensagem de erro
# e exibida e a funcao retorna 1.
#
# Variaveis globais:
#   destino     - Caminho do diretorio onde o arquivo zip esta localizado.
#   SERACESOFF  - Caminho do diretorio do servidor off.
#   TOOLS       - Caminho do diretorio onde os arquivos devem ser movidos.
#   LOG_ATU     - Caminho do arquivo de log da atualizacao.
#
# Retorna:
#   0 em caso de sucesso.
#   1 em caso de erro.
_update_offline() {
    local zipfile="atualiza.zip"
    local dir="$destino$SERACESOFF"
    
    cd "$dir" || { _mensagec "${RED}" "Erro: Diretorio $dir nao acessivel."; return 1; }
    [ -f "$zipfile" ] || { _mensagec "${RED}" "Erro: $zipfile nao encontrado em $dir."; return 1; }
    
    "$cmd_unzip" -o "$zipfile" >> "$LOG_ATU" 2>&1 || {
        _mensagec "${RED}" "Erro ao descompactar $zipfile."
        return 1
    }
    
    rm -f "$zipfile"
    for file in atualiza.sh setup.sh; do
        [ -f "$file" ] || { _mensagec "${RED}" "Erro: $file nao encontrado."; return 1; }
        chmod +x "$file"
        mv -f "$file" "$TOOLS" || { _mensagec "${RED}" "Erro ao mover $file."; return 1; }
    done
    _linha
    _mensagec "${GREEN}" "${M93}"
    _linha
}

_update() {
    if [ -z "$SERACESOFF" ]; then
        _update_online
    else
        _update_offline
    fi
    _press
    _principal
}

# Mostra os parametros do sistema que estao configurados.
# Mostra o diretorio raiz do sistema, o diretorio do atualiza.sh, o diretorio
# da base principal, o diretorio da segunda base, o diretorio da terceira base,
# o diretorio do executavel, o diretorio das telas, o diretorio dos xmls, o
# diretorio dos logs, o diretorio dos olds, o diretorio dos progs, o diretorio
# do backup e qual o sistema em uso.
# Mostra tambem a biblioteca que esta sendo usada, o diretorio para onde enviar
# o backup, o diretorio Servidor OFF, a versao anterior da Biblioteca, a
# variavel da classe e a variavel da mclasse.
_parametros() {
clear
_linha "=" "${GREEN}"
printf "${GREEN}""Sistema e banco de dados: ""${NORM}""${BANCO}""%*s\n"     
printf "${GREEN}""O diretorio raiz e: ""${NORM}""${destino}""%*s\n"
printf "${GREEN}""O diretorio do atualiza.sh: ""${NORM}""${destino}""${pasta}""%*s\n"
printf "${GREEN}""O diretorio da base Principal : ""${NORM}""${destino}""${base}""%*s\n"
printf "${GREEN}""O diretorio da Segunda base: ""${NORM}""${destino}""${base2}""%*s\n"
printf "${GREEN}""O diretorio da Terceira base: ""${NORM}""${destino}""${base3}""%*s\n"
printf "${GREEN}""O diretorio do executavies: ""${NORM}""${destino}""/""${exec}""%*s\n"
printf "${GREEN}""O diretorio das telas: ""${NORM}""${destino}""/""${telas}""%*s\n"
printf "${GREEN}""O diretorio dos xmls: ""${NORM}""${destino}""/""${xml}""%*s\n"
printf "${GREEN}""O diretorio dos logs: ""${NORM}""${destino}""${pasta}""${logs}""%*s\n"
printf "${GREEN}""O diretorio dos olds: ""${NORM}""${destino}""${pasta}""${olds}""%*s\n"
printf "${GREEN}""O diretorio dos progs: ""${NORM}""${destino}""${pasta}""${progs}""%*s\n"
printf "${GREEN}""O diretorio do backup: ""${NORM}""${destino}""${pasta}""${backup}""%*s\n"
printf "${GREEN}""Qual o sistem em uso: ""${NORM}""${sistema}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 1: ""${NORM}""${SAVATU1}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 2: ""${NORM}""${SAVATU2}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 3: ""${NORM}""${SAVATU3}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 4: ""${NORM}""${SAVATU4}""%*s\n"
_linha "=" "${GREEN}"
_press
clear
_linha  "=" "${GREEN}"
printf "${GREEN}""O diretorio para onde enviar o backup: ""${NORM}""${ENVIABACK}""%*s\n"
printf "${GREEN}""O diretorio Servidor OFF: ""${NORM}""${SERACESOFF}""%*s\n"
printf "${GREEN}""Versao anterior da Biblioteca: ""${NORM}""${VERSAOANT}""%*s\n"
printf "${GREEN}""Variavel da classe: ""${NORM}""${class}""%*s\n"
printf "${GREEN}""Variavel da mclasse: ""${NORM}""${mclass}""%*s\n"
_linha  "=" "${GREEN}"
_press
_ferramentas
}

# Função para escrever uma nova nota.
_escrever_nota() {
    clear
    _linha
    _mensagec "${YELLOW}" "Digite sua nota (pressione Ctrl+D para finalizar):"
    _linha

    # Ler a entrada e adiciona ao arquivo.
    cat >> "$FILE"
    _linha    
    _mensagec "${YELLOW}" "Nota gravada com sucesso!"
    sleep 2
}


# Função para editar as notas utilizando um editor de texto.
_editar_nota() {
    clear
    if [[ -f "$FILE" ]]; then
        # Abre o arquivo no editor padrão definido na variável EDITOR ou no nano, se não houver.
        if ! ${EDITOR:-nano} "$FILE"; then
            _mensagec "${RED}" "Erro ao abrir o editor!"
            return 1
        fi
    else
        _mensagec "${YELLOW}" "Nenhuma nota encontrada para editar!"
        sleep 2
    fi
}

# Função para excluir uma nota específica.
_excluir_nota() {
    if [[ ! -f "${FILE}" ]]; then
        _mensagec "${YELLOW}" "Nenhuma nota encontrada para excluir!"
        sleep 2
        return
    fi
    "${cmd_find}" "${TOOLS}" -name "${FILE}" -exec rm -rf {} \; || { printf "Erro ao mover arquivos."; return 1; }
    _mensagec "${RED}" "Nota excluida com sucesso!"
    sleep 2
}

_lembretes() {
clear
# Nome do arquivo onde as notas serão salvas.
local FILE="atualizal"
# Loop principal do menu.
while true; do
clear 
###-800-mensagens do Menu Bloco de anotacao.
    M800=" Bloco de Notas  " 
    M802="1${NORM} - Escrever nova nota   "
    M803="2${NORM} - Visualizar nota      "
    M804="3${NORM} - Editar nota          "
    M805="4${NORM} - Apagar nota          "
    M806="9${NORM} - ${RED}Menu Anterior"

	printf "\n"
	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M800}"
	_linha 
	printf "\n"
	_mensagec "${PURPLE}" "${M103}"
	printf "\n"
	_mensagec "${GREEN}" "${M802}"
	printf "\n"
	_mensagec "${GREEN}" "${M803}"
	printf "\n"
	_mensagec "${GREEN}" "${M804}"
    printf "\n"
	_mensagec "${GREEN}" "${M805}"
	printf "\n\n"    
	_mensagec "${GREEN}" "${M806}"
    printf "\n"       
	_linha "=" "${GREEN}"
    
    read -rp "${YELLOW}${M110}${NORM}" OPCAO	
    
    case ${OPCAO} in
        1) _escrever_nota ;;
        2) _visualizar_notas ;;
        3) _editar_nota ;;
        4) _excluir_nota ;;     
        9) clear ; _ferramentas ;;
        *) _opinvalida 
            _read_sleep 1  
            _lembretes ;;    
    esac
done
}

### _ferramentas
# 
# Mostra o menu das ferramentas 
# 
_ferramentas() {
    tput clear
    printf "\n"
    ###-500-mensagens do Menu Ferramentas.
    M501="Menu das Ferramentas"
    M503="1${NORM} - Temporarios             "
    M504="2${NORM} - Recuperar Arquivos      "
    M505="3${NORM} - Rotina de Backup        "
    M506="4${NORM} - Envia e Recebe Arquivos "
    M507="5${NORM} - Expurgador de Arquivos  "
    M508="6${NORM} - Parametros              "
    M509="7${NORM} - Update                  "
    M510="8${NORM} - Lembretes               "	
    M511="9${NORM} - ${RED}Menu Anterior  "

    _linha "=" "${GREEN}"
    _mensagec "${RED}" "${M501}"
    _linha 
    printf "\n"
    _mensagec "${PURPLE}" "${M103}"
    printf "\n"
    if [[ "${BANCO}" = "s" ]]; then
        _mensagec "${GREEN}" "${M503}"
        printf "\n"
        _mensagec "${GREEN}" "${M506}"
        printf "\n"
        _mensagec "${GREEN}" "${M507}"
        printf "\n"
        _mensagec "${GREEN}" "${M508}"
        printf "\n"
        _mensagec "${GREEN}" "${M509}"
        printf "\n"
        _mensagec "${GREEN}" "${M510}"
        printf "\n\n"
        _mensagec "${GREEN}" "${M511}"
        printf "\n"
        _linha "=" "${GREEN}"

        read -rp "${YELLOW}${M110}${NORM}" OPCAOB

        case ${OPCAOB} in
            1) _temps       ;;
            4) _envrecarq   ;;
            5) _expurgador  ;;
            6) _parametros  ;;
            7) _update      ;;
            8) _lembretes   ;;
            9) clear ; _principal ;;
            *) _opinvalida 
                _read_sleep 1  
                _ferramentas ;;
        esac
    else
        _mensagec "${GREEN}" "${M503}"
        printf "\n"
        _mensagec "${GREEN}" "${M504}"
        printf "\n"
        _mensagec "${GREEN}" "${M505}"
        printf "\n"
        _mensagec "${GREEN}" "${M506}"
        printf "\n"
        _mensagec "${GREEN}" "${M507}"
        printf "\n"
        _mensagec "${GREEN}" "${M508}"
        printf "\n"
        _mensagec "${GREEN}" "${M509}"
        printf "\n"
        _mensagec "${GREEN}" "${M510}"
        printf "\n\n"
    fi
    _mensagec "${GREEN}" "${M511}"
    printf "\n"
    _linha "=" "${GREEN}"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO

    case ${OPCAO} in
        1)  _temps        ;;
        2)  _rebuild      ;;
        3)  _menubackup   ;;
        4)  _envrecarq    ;;
        5)  _expurgador   ;;
        6)  _parametros   ;;
        7)  _update       ;;
        8)  _lembretes    ;;
        9)  clear  
            _principal ;;
        *)  _opinvalida 
            _read_sleep 1  
            _ferramentas ;;
    esac
}

# _principal () - Funcao principal do programa
# Mostra o menu principal com as opcoes de atualizacao de programas, biblioteca, desatualizando,
# versao do iscobol, versao do linux e ferramentas. Chama a funcao escolhida pelo usuario.
# 
# Opcoes:
# 1 - Atualizacao de Programas
# 2 - Atualizacao de Biblioteca
# 3 - Desatualizando
# 4 - Versao do Iscobol
# 5 - Versao do Linux
# 6 - Ferramentas
# 9 - Sair
_principal() { 
tput clear
printf "\n"
#-100-mensagens do Menu Principal. ----------------------------------------------------------------#	
	M101="Menu Principal"
	M1102=".. Empresa: ${EMPRESA} .."
    M102=".. Sistema: ${sistema} .."
    M103="Escolha a opcao:                "
	M104="1${NORM} - Programas                "
    M105="2${NORM} - Biblioteca               " 
	M111="3${NORM} - Versao do Iscobol        "
	M112="3${NORM} - Funcao nao disponivel    "
	M107="4${NORM} - Versao do Linux          "
    M108="5${NORM} - Ferramentas              "
    M109="9${NORM} - ${RED}Sair            "
    M110=" Digite a opcao desejada -> " 

	_linha "=" "${GREEN}"
	_mensagec "${RED}" "${M101}"
	_linha
    _mensagec "${WHITE}" "${M1102}"
    _linha
	_mensagec "${CYAN}" "${M102}"
    _linha 
	_mensagec "${PURPLE}" "${M103}"
	printf "\n"
	_mensagec "${GREEN}" "${M104}"
	printf "\n"
	_mensagec "${GREEN}" "${M105}"
	printf "\n"
        if [[ "${sistema}" = "iscobol" ]]; then
        _mensagec "${GREEN}" "${M111}"
        else
        _mensagec "${GREEN}" "${M112}"
        fi
	printf "\n"
	_mensagec "${GREEN}" "${M107}"
	printf "\n"
	_mensagec "${GREEN}" "${M108}"
	printf "\n\n"
	_mensagec "${GREEN}" "${M109}"
    printf "\n"
    _mensaged "${BLUE}" "${UPDATE}"
    _linha "=" "${GREEN}"

    read -rp "${YELLOW}${M110}${NORM}" OPCAO

    case ${OPCAO} in
        1) _atualizacao   ;;
        2) _biblioteca    ;;
        3) _iscobol       ;;
        4) _linux         ;;
        5) _ferramentas   ;;
        9) clear ; _resetando ;;
        *) _opinvalida 
            _read_sleep 1  
            _principal ;;
    esac
}

_principal

tput clear
tput sgr0
tput cup "$( tput lines )" 0
clear
