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
##  Rotina para atualizar os programas avulsos e bibliotecas da SAV                                                               #
##  Feito por: Luiz Augusto   email luizaugusto@sav.com.br                                                              #
##  Versao do atualiza.sh                                                                                              #
UPDATE="27/01/2025"                                                                                                    #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#                   #
# Arquivos de trabalho:                                                                                                #
# "atualizac"  = Contem a configuracao referente a empresa                                                             #
# "atualizap"  = Configuracao do parametro do sistema                                                                  #
# "atualizaj"  = Lista de arquivos principais para dar rebuild.                                                        #
# "atualizat   = Lista de arquivos temporarios a ser excluidos da pasta de dados.                                      #
#               Sao zipados em /backup/Temps-dia-mes-ano-horario.zip                                                   #
# "setup.sh"   = Configurador  para criar os arquivos atualizac e atualizap                                             #
# Menus                                                                                                                #
# 1 - Atualizacao de Programas                                                                                         #
# 2 - Atualizacao de Biblioteca                                                                                        #
# 3 - Desatualizando                                                                                                   #
# 4 - Versao do Iscobol                                                                                                #
# 5 - Versao do Linux                                                                                                  #
# 6 - Ferramentas                                                                                                      #
#                                                                                                                      #
#      1 - Atualizacao de Programas                                                                                    #
#            1.1 - ON-Line                                                                                             #
#      Acessa o servidor da SAV via rsync com o usuario ATUALIZA                                                         #
#      Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                                       #
#      com o nome "Nome do programa-anterior.zip" descompacta o novo no diretorio                                      #
#      dos programa e salva o a atualizacao na pasta ?/sav/tmp/progs.                                                  #
#            1.2 - OFF-Line                                                                                            #
#      Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.                                  #
#      O processo de atualizacao e identico ao passo acima.                                                            #
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
#                                                                                                                      #
#      3 - Desatualizando                                                                                              #
#            3.1 - Voltar programa Atualizado                                                                          #
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com o nome de ("programa"-anterior.zip)             #
#      na pasta dos programas.                                                                                         #
#                                                                                                                      #
#            3.2 - Voltar antes da Biblioteca                                                                          #
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backup-versao da biblioteca".zip)        #
#      na pasta dos programas.                                                                                         #
#                                                                                                                      #
#      4 - Versao do Iscobol                                                                                           #
#            Verifica qual a versao do iscobol que esta sendo usada.                                                   #
#                                                                                                                      #
#      5 - Versao do Linux                                                                                             #
#            Verifica qual o Linux em uso.                                                                             #
#                                                                                                                      #
#      6 - Ferramentas                                                                                                 #
#           6.1 - Limpar Temporarios                                                                                   #
#               6.1.1 - Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup                      #
#                       com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                                 #
#               6.1.2 - Adiciona arquivos no "ATUALIZAT"                                                               #
#                                                                                                                      #
#           6.2 - Recuperar arquivos                                                                                   #
#               6.2.1 - Um arquivo ou Todos                                                                            #
#                   Opcao pede para informa um arquivo especifico, somente o nome sem a extensao                       #
#                   ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com as extens es,         #
#                   "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"                                                    #
#                                                                                                                      #
#               6.2.2 - Arquivos Principais                                                                            #
#                   Roda o Jtuil somente nos arquivos que estao na lista "atualizaj"                                   #
#                                                                                                                      #
#           6.3 - Backup da base de dados                                                                              #
#               6.3.1 - Faz um backup da pasta de dados  e tem a opcao de enviar para a SAV                            #
#               6.3.2 - Restaura Backup da base de dados                                                               #
#               6.3.3 - Enviar Backup selecionado                                                                      #
#                                                                                                                      #  
#           6.4 - Envia e Recebe Arquivos "Avulsos"                                                                    #
#               6.4.1 - Enviar arquivo(s)                                                                              #
#               6.4.2 - Receber arquivo(s)                                                                             #
#                                                                                                                      #
#           6.5 - Expurgador de arquivos                                                                               #
#               Excluir, zips e bkps com mais de 30 dias processado dos diretorios:                                    #
#                /backup, /olds /progs e /logs                                                                         #
#                                                                                                                      # 
#           6.7 - Parametros                                                                                           #    
#                 Variaves e caminhos necessarios para o funcionamento do atualiza.sh                                  # 
#                                                                                                                      # 
#           6.8 - Update                                                                                               #
#               Atualizacao do programa atualiza.sh                                                                    #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#

#Zerando variaves utilizadas 
# resetando: Funcao que zera todas as variaveis utilizadas pelo programa, para
#            evitar que elas sejam utilizadas por outros programas.
#            Também fecha o programa atualiza.sh.
resetando () {
unset -v RED GREEN YELLOW BLUE PURPLE CYAN NORM
unset -v BASE1 BASE2 BASE3 tools DIR OLDS PROGS BACKUP 
unset -v destino pasta base base2 base3 logs exec class telas xml
unset -v olds progs backup sistema SAVATU SAVATU1 SAVATU2 SAVATU3 SAVATU4
unset -v TEMPS UMADATA DIRB ENVIABACK ENVBASE SERACESOFF
unset -v E_EXEC T_TELAS X_XML NOMEPROG CCC MXX
unset -v cmd_unzip cmd_zip cmd_find cmd_who VBACKUP ARQUIVO 
unset -v PEDARQ prog PORTA USUARIO IPSERVER DESTINO2 
tput sgr0; exit 
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
tput sgr0
# Comando para limpar a tela
tput clear 
# Comando para tornar a fonte em negrito
tput bold
# Comando para definir a cor da fonte como branco
tput setaf 7
# Variaveis de cores
RED=$(tput bold)$(tput setaf 1) # Cor vermelha
GREEN=$(tput bold)$(tput setaf 2) # Cor verde
YELLOW=$(tput bold)$(tput setaf 3) # Cor amarela
BLUE=$(tput bold)$(tput setaf 4) # Cor azul
PURPLE=$(tput bold)$(tput setaf 5)  # Cor roxa
CYAN=$(tput bold)$(tput setaf 6) # Cor ciano
NORM=$(tput bold)$(tput setaf 7) # Cor normal
COLUMNS=$(tput cols) # Numero de colunas da tela

#### configurar as variaveis em ambiente no arquivo abaixo:    ####
#- TESTE de CONFIGURACOES--------------------------------------------------------------------------#
# Checando se os arquivos de configuracao estao configurados corretamente
if [[ ! -e "atualizac" ]]; then
    printf "ERRO. Arquivo atualizac, Nao existe no diretorio, usar ./setup.sh .\n"
    exit 1
fi

if [[ ! -r "atualizac" ]]; then
    printf "ERRO. Arquivo atualizac, Sem acesso de leitura.\n"
    exit 1
fi

if [[ ! -e "atualizap" ]]; then
    printf "ERRO. Arquivo atualizap, Nao existe no diretorio, usar ./setup.sh .\n"
    exit 1
fi

if [[ ! -r "atualizap" ]]; then
    printf "ERRO. Arquivo atualizap, Sem acesso de leitura.\n"
    exit 1
fi

# Arquivo de configuracao para a empresa
if [[ -f "atualizac" ]]; then
    "." ./atualizac
else
    printf "ERRO. Arquivo atualizac, Nao existe no diretorio.\n"
    exit 1
fi

# Arquivo de configuracao para o atualiza.sh
if [[ -f "atualizap" ]]; then
    "." ./atualizap
else
    printf "ERRO. Arquivo atualizap, Nao existe no diretorio.\n"
    exit 1
fi
#--------------------------------------------------------------------------------------------------#
# Funcao para checar se o zip esta instalado
# Checa se os programas necessarios para o atualiza.sh estao instalados no sistema. 
# Se o programa nao for encontrado, exibe uma mensagem de erro e sai do programa.
_check_instalado() {
    local Z1="Aparentemente falta algum programa que nao esta instalado nesta distribuicao."

    # Informe abaixo no comando for se precisar informar mais algum programa a ser checado.
    for prog in zip unzip; do
        if ! command -v "${prog}" &> /dev/null; then
            printf "\n"
            printf "%*s""${RED}" ;printf "%*s\n" $(((${#Z1}+COLUMNS)/2)) "${Z1}" ;printf "%*s""${NORM}"
            printf "%*s""${YELLOW}" " O programa nao foi encontrado ->> " "${NORM}" "${prog}"
            printf "\n"
            exit 1
        fi
    done
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
M04="Volta do(s) Arquivo(s) Concluida"
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
M26="... Agora, ATUALIZANDO ..."
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
MA1="O backup \"""$VBACKUP""\""
MA2="         1- Informe apos qual versao da BIBLIOTECA: "

# Mensagens em VERMELHO
M45="Backup nao encontrado no diretorio ou nao foi informado os dados"
M46="Backup da Biblioteca nao encontrado no diretorio"
M47="Backup Abortado!"
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
M80="..Checando estrutura dos diretorios do atualiza.sh.."
M81="..Encontrado o diretorio do sistema .."

# Mensagens em VERDE
M91="Atualizar este sistema"
M92="ao termino da atualizacao sair e entrar novamente"

#-Centro da tela-----------------------------------------------------------------------------------#
# _meiodatela ()
# 
# Limpa a tela e posiciona o cursor no meio da tela.
# 
# O printf "\033c" limpa a tela, e o "\033[10;10H" posiciona o
# cursor na linha 10, coluna 10.
#
_meiodatela () {
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
_mensagec () {
    local CCC="${1}"
    local MXX="${2}"
    printf "%*s""${CCC}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "${MXX}" ;printf "%*s""${NORM}"
}

#-Variavel para identificar -----------------------------------------------------------------------#
## Inicializa a variável DEFAULT_VERSAO como uma string vazia
DEFAULT_VERSAO=""
# Verifica se a variável VERSAO está vazia, se sim, atribui o valor de DEFAULT_VERSAO
if [[ -z "${VERSAO}" ]]; then
     VERSAO="${DEFAULT_VERSAO}"
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

# Verificacao de diretorio necessarios -------------------------------------------------------------#
# pasta - Diretorio do Tools
if [[ -n "${pasta}" ]]; then
     _mensagec "${CYAN}" "${M81}"
else
     printf "Diretorio do Tools, nao esta configurado  \n"
     exit
fi

# base - Diretorio da Base de dados
if [[ -n "${base}" ]]; then
     _mensagec "${CYAN}" "${M81}"
else
     printf "Diretorio da Base de dados, nao esta configurado  \n"
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
E_EXEC=${destino}"/"${exec}
if [[ -n "${E_EXEC}" ]] && [[ -d "${E_EXEC}" ]]; then
     # Diretorio da destino encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da destino nao encontrado
     printf "%*s""Diretorio da destino nao encontrado ""${E_EXEC}""...  \n"
     exit
fi
T_TELAS=${destino}"/"${telas}
if [[ -n "${T_TELAS}" ]] && [[ -d "${T_TELAS}" ]]; then
     # Diretorio da destino encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da destino nao encontrado
     printf "%*s""Diretorio da destino nao encontrado ""${T_TELAS}""...  \n"
     exit
fi

X_XML=${destino}"/"${xml}
if [[ -n "${X_XML}" ]] && [[ -d "${X_XML}" ]]; then
     # Diretorio da destino encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da destino nao encontrado
     printf "%*s""Diretorio da destino nao encontrado ""${X_XML}""...  \n"
     exit
fi     

TOOLS=${destino}${pasta}
if [[ -n "${TOOLS}" ]] && [[ -d "${TOOLS}" ]]; then
     # Diretorio da destino encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da destino nao encontrado
     printf "%*s""Diretorio da destino nao encontrado ""${TOOLS}""...  \n"
     exit
fi

BASE1=${destino}${base}
if [[ -n "${BASE1}" ]] && [[ -d "${BASE1}" ]]; then
     # Diretorio da base encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da base nao encontrado
     printf "%*s""Diretorio da base nao encontrado ""${BASE1}""...  \n"
     exit
fi

BASE2=${destino}${base2}
if [[ -n "${BASE2}" ]] && [[ -d "${BASE2}" ]]; then
     # Diretorio da base encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da base nao encontrado
     printf "%*s""Diretorio da base nao encontrado ""${BASE2}""...  \n"
     exit
fi

BASE3=${destino}${base3}
if [[ -n "${BASE3}" ]] && [[ -d "${BASE3}" ]]; then
     # Diretorio da base encontrado
     _mensagec "${CYAN}" "${M81}"
else
     # Diretorio da base nao encontrado
     printf "%*s""Diretorio da base nao encontrado ""${BASE3}""...  \n"
     exit
fi     

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
DEFAULT_IPSERVER="177.115.194.15"
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
DESTINO2SAVATUISC="/home/savatu/biblioteca/temp/ISCobol/sav-5.0/"
DESTINO2SAVATUMF="/home/savatu/biblioteca/temp/Isam/sav-3.1"
DESTINO2TRANSPC="/u/varejo/trans_pc/"

# Verifica se as variáveis de ambiente foram setadas.
# As variáveis de ambiente são necessárias para que o programa funcione corretamente.
# Caso elas não estejam setadas, o programa exibe uma mensagem de erro e sai.

# DESTINO2SERVER: Caminho do servidor da SAV com os programas.
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

#-Funcao de sleep----------------------------------------------------------------------------------#
# Esta função pausa a execução por um número especificado de segundos.
# A duração é determinada pelo argumento passado para a função.
# Ele usa o comando `read` com uma opção de tempo limite para obter o efeito de suspensão.
# Exemplo de uso:
# _read_sleep 1   # Pausa por 1 segundo
# _read_sleep 0.2 # Pausas por 2 segundos
_read_sleep () {
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
_press () {
     printf "%*s""${YELLOW}" ;printf "%*s\n" $(((${#M36}+COLUMNS)/2)) "${M36}" ;printf "%*s""${NORM}"
     read -rt 15 || :
     tput sgr0
}

#-Escolha qual o tipo de traco---------------------------------------------------------------------#
# Esta função imprime uma linha de caracteres na largura do terminal.
# O caractere usado para a linha pode ser especificado como argumento; 
# caso contrário, o padrão é um hífen ('-'). A linha é centralizada com base
# na largura atual do terminal.
_linha () {
     local Traco=${1:-'-'}
# quantidade de tracos por linha
     printf -v Espacos "%$(tput cols)s""" 
     linhas=${Espacos// /$Traco}
	printf "%*s\n" $(((${#linhas}+COLUMNS)/2)) "$linhas"
}

#   Opção Invalida
#-Opcao Invalida-----------------------------------------------------------------------------#
# Esta funcao chamada quando o usuario digita uma opcao   invalida.
# Ela imprime um aviso centralizado na tela, com a cor definida como variavel global.
# A funcao e chamada sem nenhuma entrada.
_opinvalida () {  
     _linha 
     _mensagec "${YELLOW}" "${M08}"
     _linha  
}      

# Verificações de parâmetro e diretórios

clear

# Verifica se o diretório de execução existe
if [[ -d "${E_EXEC}" ]]; then
    _mensagec "${CYAN}" "${M81}"
else
    M44="Nao foi encontrado o diretorio ""${E_EXEC}"
    _linha "*"
    _mensagec "${RED}" "${M44}"
    _linha "*"
    _read_sleep 2
    exit
fi

# Verifica se o diretório de telas existe
if [[ -d "${T_TELAS}" ]]; then
    _mensagec "${CYAN}" "${M81}"
else
    M44="Nao foi encontrado o diretorio ""${T_TELAS}"
    _linha "*"
    _mensagec "${RED}" "${M44}"
    _linha "*"
    _read_sleep 2
    exit
fi

# Verifica diretórios específicos se o sistema for iscobol
if [[ "${sistema}" = "iscobol" ]]; then
    if [[ -d "${X_XML}" ]]; then
        _mensagec "${CYAN}" "${M81}"
    else
        M44="Nao foi encontrado o diretorio ""${X_XML}"
        _linha "*"
        _mensagec "${RED}" "${M44}"
        _linha "*"
        _read_sleep 2
        exit
    fi
fi

# Verifica e cria diretório SERACESOFF se necessário
if [[ -z "${SERACESOFF}" ]]; then
    if ! [[ -d "${SERACESOFF}" ]]; then 
        mkdir -p "${destino}${SERACESOFF}"
    fi
    BAT="atualiza.bat"
    if [[ -f "${BAT}" ]]; then
        mv -f -- "${BAT}" "${destino}${SERACESOFF}"
    fi
fi

# Verifica o diretório TOOLS e cria subdiretórios se necessário
if [[ -d "${TOOLS}" ]]; then
    _linha "*"
    _mensagec "${CYAN}" "${M80}"
    _linha "*"
    
    OLDS=${TOOLS}${olds}
    # Cria diretório olds se não existir
    if [[ -d "${OLDS}" ]]; then
        printf " Diretorio olds ... ok \n"
    else
        mkdir -p "${OLDS}"
    fi
    
    PROGS=${TOOLS}${progs}
    # Cria diretório progs se não existir
    if [[ -d "${PROGS}" ]]; then
        printf " Diretorio progs ... ok \n"
    else
        mkdir -p "${PROGS}"
    fi
    
    LOGS=${TOOLS}${logs}
    # Cria diretório logs se não existir
    if [[ -d "${LOGS}" ]]; then
        printf " Diretorio logs ... ok \n"
    else
        mkdir -p "${LOGS}"
    fi
    
    BACKUP=${TOOLS}$backup
    # Cria diretório backups se não existir
    if [[ -d "${BACKUP}" ]]; then
        printf " Diretorio backups ... ok \n"
    else
        mkdir -p "${BACKUP}"
    fi
    
    ENVIA=${TOOLS}"/envia"
    # Cria diretório envia se não existir
    if [[ -d "${ENVIA}" ]]; then
        printf " Diretorio envia ... ok \n"
    else
        mkdir -p "${ENVIA}"
    fi
    
    RECEBE=${TOOLS}"/recebe"
    # Cria diretório recebe se não existir
    if [[ -d "${RECEBE}" ]]; then
        printf " Diretorio recebe ... ok \n"
    else
        mkdir -p "${RECEBE}"
    fi
else
    exit
fi

#### PARAMETRO PARA O LOGS ------------------------------------------------------------------------#
# Define o nome do arquivo de log da atualizacao
# com a data de hoje no formato "ano-mes-dia".
LOG_ATU=${LOGS}/atualiza.$(date +"%Y-%m-%d").log

# Define o nome do arquivo de log da limpeza
# com a data de hoje no formato "ano-mes-dia".
LOG_LIMPA=${LOGS}/limpando.$(date +"%Y-%m-%d").log

# Define o nome do arquivo de log temporario
# sem data no nome, pois sera sobreescrito
# a cada execucao.
LOG_TMP=${LOGS}/

# Define a variavel UMADATA com a data e hora
# atual no formato "dia-mes-ano_hora_minuto_segundo".
UMADATA=$(date +"%d-%m-%Y_%H%M%S")


# Verifica se as variáveis de ambiente necessárias estão configuradas.
# Em caso negativo, exibe uma mensagem de erro e encerra a execução.

# Verifica a variável de ambiente LOG_ATU
if [[ -z "${LOG_ATU}" ]]; then
    printf "Erro: Variavel de ambiente LOG_ATU nao esta configurada.\n"
    exit 1
fi

# Verifica a variável de ambiente LOG_LIMPA
if [[ -z "${LOG_LIMPA}" ]]; then
    printf "Erro: Variavel de ambiente LOG_LIMPA nao esta configurada.\n"
    exit 1
fi

# Verifica a variável de ambiente LOG_TMP
if [[ -z "${LOG_TMP}" ]]; then
    printf "Erro: Variavel de ambiente LOG_TMP nao esta configurada.\n"
    exit 1
fi

# Verifica a variável de ambiente UMADATA
if [[ -z "${UMADATA}" ]]; then
    printf "Erro: Variavel de ambiente UMADATA nao esta configurada.\n"
    exit 1
fi

clear

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
_principal () { 
     tput clear
	printf "\n"
#-100-mensagens do Menu Principal. ----------------------------------------------------------------#	
	M101="Menu de Opcoes""   -   Versao: ""${BLUE}""${UPDATE}""${NORM}"
	M102=".. Sistema: ""${sistema}"" ..  =  ..Empresa: ""${EMPRESA}"" .."
	M103="Escolha a opcao:   "
	M104="1${NORM} - Programas                "
    M105="2${NORM} - Biblioteca               " 
	M111="3${NORM} - Versao do Iscobol        "
	M112="3${NORM} - Funcao nao disponivel    "
	M107="4${NORM} - Versao do Linux          "
    M108="5${NORM} - Ferramentas              "
    M109="9${NORM} - ${RED}Sair            "
    M110=" Digite a opcao desejada -> " 

	_linha "="
	_mensagec "${RED}" "${M101}"
	_linha
	_mensagec "${CYAN}" "${M102}"
	_linha "="
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
     _linha "="
     read -rp "${YELLOW}${M110}${NORM}" OPCAO

     case ${OPCAO} in
          1) _atualizacao   ;;
          2) _biblioteca    ;;
          3) _iscobol       ;;
          4) _linux         ;;
          5) _ferramentas   ;;
          9) clear ; resetando ;;
          *) clear ; _principal ;;
     esac
}
#-Procedimento da atualizacao de programas---------------------------------------------------------# 
### _atualizacao
# Mostra o menu de atualizacao de programas com opcoes de atualizar via ON-Line ou OFF-Line.
# Chama a funcao escolhida pelo usuario.
_atualizacao () { 
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
	_linha "="
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
	_linha "="
     read -rp "${YELLOW}${M110}${NORM}" OPCAO
     case ${OPCAO} in
          1) _pacoteon ;;
          2) _pacoteoff ;;
          3) _voltaprog ;;
          9) clear ; _principal ;;
          *) _principal ;;
     esac
}


# Esta função solicita que o usuário insira o nome de um programa em letras maiúsculas para ser atualizado.
# Ele valida a entrada para garantir que ela consista apenas em letras maiúsculas e números.
# Se a entrada for inválida, exibe uma mensagem de erro e retorna ao menu principal.
# Depois que um nome de programa válido é fornecido, ele pergunta se o programa foi compilado normalmente.
# Com base na resposta do usuário, ele constrói o nome do arquivo do programa com o sufixo de classe apropriado.
# A função define as variáveis ​​NOMEPROG para processamento posterior.

_qualprograma () {
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
        _mensagec "${RED}" "Erro: Nenhum nome de programa fornecido Saindo..."
        break
    fi
    if [[ "${programa}" == " " ]]; then
        _mensagec "${RED}" "Erro: Nenhum nome de programa fornecido Saindo..."
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
_baixarviarsync () {
  
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
_servacessoff () {
    if [[ "${SERACESOFF}" != "" ]]; then
    local SAOFF="${destino}${SERACESOFF}"

    if [[ ! -d "${SAOFF}" ]]; then
        _mensagec "${RED}" "Erro: Diretorio ${SAOFF} nao existe"
        return
    fi

     for arquivo in "${SAOFF}/""${NOMEPROG[@]}"; do
     mv -f -- "${SAOFF}/${arquivo}" "." 
     done
M42="O programa a ser atualizado, ""${NOMEPROG[*]}"
M422=" nao foi encontrado no diretorio ""${SAOFF}" 
     _linha 
     _mensagec "${RED}" "${M42}"
     _mensagec "${RED}" "${M422}"
     _linha 
     _press
     _principal       
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
_pacoteon () {
    _qualprograma
#    _baixarviascp
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
_pacoteoff () {
    if [[ -z "${SERACESOFF}" ]]; then
        _mensagec "${RED}" "Erro: SERACESOFF nao está configurado"
        return
    fi    
    _servacessoff
    
    # Solicita o nome do programa a ser atualizado
    if ! _qualprograma; then
        return
    fi

    # Exibe mensagem de atualização
    _linha
    _mensagec "${YELLOW}" "${M09}"
    _linha
    _read_sleep 1

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
        _mensagec "${RED}" "Programa(s) nao encontrado(s) no diretorio"
        _linha
        _press
        _principal
        return
    fi
    # Processa programas antigos
for  f in "${!programas[@]}"; do
        anterior="${OLDS}/${programas[f]}-anterior.zip"
        if [ -f "$anterior" ]; then
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
        if [ -f "${E_EXEC}/${programas[f]}${EXT_CLASS}" ]; then
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
        if [ -f "${E_EXEC}/${programas[f]}${EXT_INT}" ]; then
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
        if [ -f "${T_TELAS}/${programas[f]}${EXT_TEL}" ]; then
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

    # Processa de descompactar e atualizar os programas
    for arquivo in "${NOMEPROG[@]}"; do
        if [[ ! -f "${arquivo}" ]]; then
            _linha
            _mensagec "${RED}" "Erro: Arquivo de atualizacao ${arquivo} nao existe"
            _linha
            _press
            _principal
            return
        fi
        if ! "${cmd_unzip}" -o "${arquivo}" >> "${LOG_ATU}"; then
            _linha
            _mensagec "${RED}" "Erro ao descompactar ${arquivo}"
            _linha
            _press
            _principal
            return
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
                    mv -f -- "${arquivo}" "${E_EXEC}" >> "${LOG_ATU}" || {
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
 
    # _voltamaisprog: Prompt user for additional program updates.
    #
    # This function concludes the program rollback process by displaying a message and
    # optionally prompts the user if they wish to update additional programs. If the user
    # chooses to update more programs and the option is set to 1, it calls the _voltaprog
    # function. Otherwise, it returns to the main menu. If the input is invalid, an error
    # message is displayed, and the user is returned to the main menu.

_voltamaisprog () {
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
          _press
          _principal
     fi
}

#-Verifica se o programa a ser desatualizado existe no diretorio
# Se o programa nao existir no diretorio, volta ao menu principal
# _verifica_principal () - Verifica se o programa a ser desatualizado existe no diretorio
#
# Se o programa nao existir no diretorio, volta ao menu principal
#
# Opcoes:
#   Qualquer tecla - Volta ao menu principal

#-Procedimento da desatualizacao de programas------------------------------------------------------#
#-VOLTA DE PROGRAMA CONCLUIDA
# Mostra uma mensagem de inicio de desatualizacao de programa e pergunta o nome do programa a ser
# desatualizado. Se o programa nao for encontrado no diretorio, volta ao menu principal.
#
# Opcoes:
#   Qualquer tecla - Desatualiza o programa
_voltaprog () {
    # Variáveis
    MAX_REPETICOES=3
    contador=0
    NOMEPROG=()
    programas=()

    validar_nome() {
        [[ "$1" =~ ^[A-Z0-9]+$ ]]
    }

    # Loop principal
    while (( contador < MAX_REPETICOES )); do
        _meiodatela
        #-Informe o nome do programa a ser desatualizado:
        _mensagec "${RED}" "${M59}"
        _linha
        MB4="Informe o nome do programa (ENTER ou espaco para sair): "
        read -rp "${YELLOW}""${MB4}""${NORM}" programa
        _linha

        # Verifica se foi digitado ENTER ou espaço
        if [[ -z "${programa}" ]]; then
            break
        fi

        # Verifica se o nome do programa é válido
        if ! validar_nome "$programa"; then
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
        if [ -f "$anterior" ]; then
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

#-VOLTA PROGRAMA ESPECIFICO------------------------------------------------------------------------#
# _volta_progx: Volta um programa especifico para a versao anterior
# 
# Informa o nome do programa em MAIUSCULO e descompacta o arquivo
# da biblioteca anterior no diretorio TOOLS.
_volta_progx () {
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

     cd "${OLDS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
     if ! "${cmd_unzip}" -j -o "${INI}" "sav/*/""${Vprog}"".*" -d "${TOOLS}" >> "${LOG_ATU}"; then
          _meiodatela
          _mensagec "${RED}" "Erro ao descompactar ${INI} para ${TOOLS}"
          _linha 
          _press
          _principal
          return 1
     fi
     _volta_progy
}

# _volta_progz: Volta mais algum programa para a versao anterior
# 
# Pergunta se deseja volta mais algum programa e caso sim, informa o nome
# do programa em MAIUSCULO e descompacta o arquivo
# da biblioteca anterior no diretorio TOOLS.
_volta_progz () {
    printf "\n"
    MA5="Deseja voltar mais algum programa ? [N/s]:"
    read -rp "${YELLOW}${MA5}${NORM}" -n1
    printf "\n\n"
    
    local REPLY1="${REPLY,,}"
    if [[ "${REPLY1}" =~ ^[Nn]$ ]] || [[ "${REPLY1}" == "" ]]; then
        _press
        # Limpa o diretório de arquivos antigos
        local OLDS1="${OLDS}/"
        if [[ -d "${OLDS1}" ]]; then
            for pprog in {*.class,*.TEL,*.xml,*.int,*.png,*.jpg}; do
                "${cmd_find}" "${OLDS1}" -name "${pprog}" -ctime +30 -exec rm -rf {} \;
            done
        fi
        _apagadir
        _principal
        return
    fi

    if [[ "${REPLY1}" =~ ^[Ss]$ ]]; then
        MA6="       2- Informe o nome do programa em maiusculo: "
        read -rp "${YELLOW}${MA6}${NORM}" Vprog
        if [[ -z "${Vprog}" ]] || [[ "${Vprog}" =~ [^A-Z0-9] ]]; then
            _meiodatela
            _mensagec "${RED}" "${M71}"
            _linha
            _press
            _principal
        else
            _volta_progy
        fi
        _press
        _principal
    fi
}

# 
# _volta_progy
# 
# Volta de programa.
# Esta funcao e responsavel por voltar um programa.
_volta_progy () {
    _read_sleep 1

    # Check if TOOLS directory exists
    if [[ -z "${TOOLS}" ]] || ! cd "${TOOLS}" ; then
        printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n" 
        exit 1
    fi

    # Check if Vprog is set
    if [[ -z "${Vprog}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha
        _press
        _principal
        return 1
    fi

    # Handle file moving based on system type
    if [[ "${sistema}" = "iscobol" ]]; then
        "${cmd_find}" "${TOOLS}" -name "${Vprog}.xml" -exec mv {} "${X_XML}" \; || { printf "Erro ao mover arquivos XML."; return 1; }
        "${cmd_find}" "${TOOLS}" -name "${Vprog}.TEL" -exec mv {} "${T_TELAS}" \; || { printf "Erro ao mover arquivos TEL."; return 1; }
        "${cmd_find}" "${TOOLS}" -name "${Vprog}*.class" -exec mv {} "${E_EXEC}" \; || { printf "Erro ao mover arquivos CLASS."; return 1; }
    else
        "${cmd_find}" "${TOOLS}" -name "${Vprog}.TEL" -exec mv {} "${T_TELAS}" \; || { printf "Erro ao mover arquivos TEL."; return 1; }
        "${cmd_find}" "${TOOLS}" -name "${Vprog}*.int" -exec mv {} "${E_EXEC}" \; || { printf "Erro ao mover arquivos INT."; return 1; }
    fi

    # Messages and confirmation
    _linha
    _mensagec "${YELLOW}" "${M03}"
    _linha

    M30="O(s) programa(s) ""${Vprog}"" da ${NORM}${RED}""$VERSAO"
    _linha
    _mensagec "${YELLOW}" "${M25}"
    _mensagec "${YELLOW}" "${M30}"
    _linha
    _press
    _volta_progz
}

#-volta todos os programas da biblioteca-----------------------------------------------------------#
# 
# _volta_geral
# 
# Volta todos os arquivos da biblioteca.
# Esta funcao e responsavel por voltar todos os arquivos da biblioteca da SAV.
_volta_geral () {
    #-VOLTA DOS ARQUIVOS ANTERIORES...
    if [[ -z "${OLDS}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha 
        _press
        _principal
        return 1
    fi

    if [[ -z "${INI}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha 
        _press
        _principal
        return 1
    fi

    if [[ ! -d "${OLDS}" ]]; then
        _meiodatela
        _mensagec "${RED}" "${M71}"
        _linha 
        _press
        _principal
        return 1
    fi

    if ! cd "${OLDS}"; then
        _meiodatela
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${OLDS}"
        _linha
        _press
        _principal
        return 1
    fi

    if ! "${cmd_unzip}" -o "${INI}" -d "${destino}" >> "${LOG_ATU}"; then
        _meiodatela
        _mensagec "${RED}" "Erro ao descompactar ${INI} para ${destino}"
        _linha 
        _press
        _principal
        return 1
    fi

    if ! cd "${TOOLS}"; then
        _meiodatela
        _mensagec "${RED}" "Erro: Falha ao acessar o diretorio ${TOOLS}"
        _linha
        _press
        _principal
        return 1
    fi
    
    _mensagec "${YELLOW}" "${M33}"
    clear
    #-VOLTA DOS PROGRAMAS CONCLUIDA
    _linha 
    _mensagec "${YELLOW}" "${M03}"
    _linha 
    ANTVERSAO=$VERSAO
    if ! printf "VERSAOANT=""${ANTVERSAO}""%*s\n"  >> atualizac; then
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

_versao () {
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
    INI="backup-${VERSAO}.zip"
    if [[ -f "${INI}" ]]; then
        printf "\n"
        _linha
        _mensagec "${RED}" "${M56}"
        _linha 
        _press
        _principal
        return 1
    fi
}
#-Rotina de Atualizacao Biblioteca-----------------------------------------------------------------#
# 
# _biblioteca
# 
# Atualiza a biblioteca da SAV.
# Esta funcao e responsavel por atualizar a biblioteca da SAV.

_biblioteca () { 
    local OPCAO
    local INI
    VERSAO=" " # Variavel que define a versao do programa.
#    clear
   
    clear
    M401="Menu da Biblioteca"
    M402="Versao Informada - ${NORM}${YELLOW}${VERSAO}"
    M403="Anterior - ${NORM}${PURPLE}${VERSAOANT}"
    M404="Escolha o local da Biblioteca:        "
    M405="1${NORM} - Atualizacao do Transpc     "
    M406="2${NORM} - Atualizacao do Savatu      "
    M407="3${NORM} - Atualizacao OFF-Line       "
    M408="Escolha o tipo de Desatualizacao:       "
    M409="4${NORM} - Voltar antes da Biblioteca "
    M410="9${NORM} - ${RED}Menu Anterior     "

    printf "\n"
    _linha "="
    _mensagec "${RED}" "${M401}"
    _linha 
    _mensagec "${RED}" "${M402}"
    _linha 
    _mensagec "${RED}" "${M403}"
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
    _linha "="

    read -rp "${YELLOW}${M110}${NORM}" OPCAO
    case ${OPCAO} in
        1) _transpc ;;
        2) _savatu ;;
        3) _atuoff ;;
        4) _voltabibli ;;
        9) clear; _principal ;;
        *) _biblioteca ;;
    esac
}
_variaveis_atualiza () {
     ATUALIZA1="${SAVATU1}${VERSAO}.zip"
     ATUALIZA2="${SAVATU2}${VERSAO}.zip"
     ATUALIZA3="${SAVATU3}${VERSAO}.zip"
     ATUALIZA4="${SAVATU4}${VERSAO}.zip"
}
# _rsync_biblioteca - Realiza o RSYNC da biblioteca do servidor OFF.
#
# Sincroniza a biblioteca do servidor OFF com a local.
#
# Opcoes:
#   NAO TEM
#
# Variaveis:
#   USUARIO - Usuario a ser usado para acesso ao servidor via RSYNC
#   IPSERVER - IP do servidor a ser acessado via RSYNC
#   PORTA - Numero da porta a ser usada para acesso ao servidor via RSYNC
#   DESTINO2 - Caminho do diretorio remoto com a biblioteca a ser baixada
#   SAVATU - Caminho do diretorio local com a biblioteca a ser baixada
#   VERSAO - Versao do sistema que esta sendo usado
_rsync_biblioteca () {
    local source="${USUARIO}@${IPSERVER}:${DESTINO2}${SAVATU}${VERSAO}.zip"
    local destino="."

    rsync -avzP -e "ssh -p ${PORTA}" "${source}" "${destino}"
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

_acessooff () {
    local off_directory="${destino}${SERACESOFF}"
if [[ -n "${SERACESOFF}" ]]; then
#if [[ "${off_directory}" == "${destino}"]]; then
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
_transpc () {
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
_savatu () {
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

_atuoff () {
    clear
    _versao
    if [[ -z "${SERACESOFF}" ]]; then
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
_salva () {
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
_processo () {

    #-ZIPANDO OS ARQUIVOS ANTERIORES...
    _linha 
    _mensagec "${YELLOW}" "${M01}"
    _linha 
    _read_sleep 1

    if [[ "${sistema}" = "iscobol" ]]; then
        cd "${destino}/" || { _mensagec "${RED}" "Erro: Não foi possível acessar o diretório ${destino}"; exit 1; }
        
        for dir in "${exec}" "${telas}" "${xml}"; do
            _mensagec "${GREEN}" "${M14}${dir}"
            if [[ -n "${cmd_find}" && -n "${OLDS}" && -n "${INI}" ]]; then
                case "${dir}" in
                    "${exec}")
                        ext="*.class *.jpg *.png *.brw *.* *.dll"
                        ;;
                    "${telas}")
                        ext="*.TEL"
                        ;;
                    "${xml}")
                        ext="*.xml"
                        ;;
                    *)
                        _mensagec "${RED}" "Erro: Tipo de diretório desconhecido: ${dir}"
                        continue
                        ;;
                esac

                "${cmd_find}" "${dir}/" -type f \( -iname "${ext}" \) -exec zip -r -q "${OLDS}/${INI}" "{}" + || {
                    printf "Erro: Falha ao compactar arquivos no diretório ${dir}""%*s\n" 
                    continue
                }
            else
                _linha 
                _mensagec "${RED}" "${M45}"
                _linha 
                _read_sleep 2
                _principal
            fi
        done
        cd "${TOOLS}/" || { _mensagec "${RED}" "Erro: Não foi possível acessar o diretório ${TOOLS}"; exit 1; }
        clear
    else
        cd "${destino}/" || { _mensagec "${RED}" "Erro: Não foi possível acessar o diretório ${destino}"; exit 1; }
        
        for dir in "${exec}" "${telas}"; do
            _mensagec "${GREEN}" "${M14}${dir}"
            if [[ -n "${cmd_find}" && -n "${OLDS}" && -n "${INI}" ]]; then
                case "${dir}" in
                    "${exec}")
                        ext="*.int"
                        ;;
                    "${telas}")
                        ext="*.TEL"
                        ;;
                    *)
                        _mensagec "${RED}" "Erro: Tipo de diretório desconhecido: ${dir}"
                        continue
                        ;;
                esac

                "${cmd_find}" "${dir}/" -type f \( -iname "${ext}" \) -exec zip -r -q "${OLDS}/${INI}" "{}" + || {
                    _mensagec "${RED}" "Erro: Falha ao compactar arquivos no diretório ${dir}"
                    continue
                }
            else
                _linha 
                _mensagec "${RED}" "${M45}"
                _linha 
                _read_sleep 2
                _principal
            fi
        done
    fi 

    #-..BACKUP COMPLETO..
    _linha 
    _mensagec "${YELLOW}" "${M27}"
    _linha 
    _read_sleep 1

    cd "${TOOLS}" || { _mensagec "${RED}" "Erro: Não foi possível acessar o diretório ${TOOLS}"; exit 1; }
    if [[ ! -r "${OLDS}/${INI}" ]]; then
        #-Backup nao encontrado no diretorio
        _linha 
        _mensagec "${RED}" "${M45}"
        _linha 
        #-Procedimento caso nao exista o diretorio a ser atualizado----------------------------------------# 
        _read_sleep 2    
        _meiodatela
        read -rp "${YELLOW}${M38}${NORM}" -n1 
        printf "\n\n"
        if [[ -z "${REPLY}" || "${REPLY,,}" =~ ^[Nn]$ ]]; then
            _principal
        elif [[ "${REPLY,,}" =~ ^[Ss]$ ]]; then
            _meiodatela
            _mensagec "${YELLOW}" "${M39}"
        else
            _opinvalida
            _principal
        fi 
    fi
    _atubiblioteca 
}
#-Procedimento da Atualizacao de Programas---------------------------------------------------------# 
# 
# Faz a atualizacao dos programas.
# Altera a versao da atualizacao e salva no diretorio /backuup como a extensao .bkp".
_atubiblioteca () {
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
             "${cmd_unzip}" -o "${arquivo}" -d "${destino}" >> "${LOG_ATU}"
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
    M40="Versão atualizada - ${VERSAO}"
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
_voltabibli () {
     clear
     M02="Voltando a versao anterior do programa ""${prog}""..."
     _meiodatela
     _mensagec "${RED}" "${M62}"
     _linha
     read -rp "${YELLOW}""${MA2}""${NORM}" VERSAO
     INI="backup-""${VERSAO}"".zip"
     if [[ -z "${VERSAO}" ]]; then
          _meiodatela
          _mensagec "${RED}" "${M56}"
          _linha
          _press
          INI=""
          _principal
          return
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
          _press
          INI=""
          _principal
     fi
}


#-Mostrar a versao do isCobol que esta sendo usada.------------------------------------------------# 
#
# Se o sistema for IsCOBOL, ele ira mostrar a versao do isCobol.
# Se o sistema nao for IsCOBOL, ele ira mostrar uma mensagem de erro.
_iscobol () {
    if [[ "${sistema}" == "iscobol" ]]; then
        if [[ -x "${SAVISC}${ISCCLIENT}" ]]; then
            clear
            _linha
            "${SAVISC}${ISCCLIENT}" -v
            _linha
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
_linux () {
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
    if [[ -z "${SERACESOFF}" ]]; then
        externalip=$(curl -s ipecho.net/plain || printf "Nao disponivel")
        printf "${GREEN}""IP Externo :""${NORM}""${externalip}""%*s\n"
    fi

    _linha
    _press
    clear
    _linha

    # Checando os usuarios logados
    _run_who () {
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

### _ferramentas
# 
# Mostra o menu das ferramentas 
# 
_ferramentas () {
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
    M510="9${NORM} - ${RED}Menu Anterior  "
    _linha "="
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
        printf "\n\n"
        _mensagec "${GREEN}" "${M510}"
        printf "\n"
        _linha "="
        read -rp "${YELLOW}${M110}${NORM}" OPCAOB
        case ${OPCAOB} in
            1) _temps        ;;
            4) _envrecarq    ;;
            5) _expurgador   ;;          
            6) _parametros   ;;
            7) _update       ;;
            9) clear ; _principal ;;
            *) _ferramentas ;;
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
        printf "\n\n"
    fi
    _mensagec "${GREEN}" "${M510}"
    printf "\n"
    _linha "="
    read -rp "${YELLOW}${M110}${NORM}" OPCAO
    case ${OPCAO} in
        1) _temps        ;;
        2) _rebuild      ;;
        3) _menubackup   ;;
        4) _envrecarq    ;;
        5) _expurgador   ;;
        6) _parametros   ;;
        7) _update       ;;
        9) clear ; _principal ;;
        *) _ferramentas ;;
    esac
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
    "${cmd_find}" "${DIRB}" -type f -iname "${file_name}" -exec "${cmd_zip}" -m "${BACKUP}/${zip_file_name}" "{}" +
} >> "${LOG_LIMPA}"

#_varrendo_arquivo () {
#       "${cmd_find}" "${DIRB}" -type f -iname "${line}" -exec zip -m "${BACKUP}/${TEMPS}-${UMADATA}" "{}" + || {
#        printf "Erro ao executar o comando zip.\n" >&2
#        return 1
#    }
# _limpando: Limpa os arquivos temporarios no diretorio "${DIRB}"
#
# O comando find e usado para encontrar todos os arquivos temporarios no diretorio "${DIRB}" e o comando zip para compactar e mover para o diretorio "${BACKUP}" com o nome "${TEMPS}-${UMADATA}".

_limpando () {
clear
     line_array=""
     mapfile -t line_array < "${arqs}"
     for file_name in "${line_array[@]}"; do
     printf "${GREEN}""Excluido todos as arquivos: ${YELLOW}${file_name}${NORM}%s\n"
     _varrendo_arquivo
     done 
M11="Movendo arquivos Temporarios do diretorio = ""${DIRB}"
_linha 
_mensagec "${YELLOW}" "${M11}"
_linha
}

# _temps: Menu de Limpeza
#
# Mostra o menu de limpeza de arquivos temporarios com opcoes de:
# - Limpar todos os arquivos temporarios no diretorio "${DIRB}".
# - Adicionar arquivos na lista "atualizat" para serem excluidos no diretorio "${DIRB}".
# - Voltar ao menu anterior.

_temps () {
    clear
    M900="Menu de Limpeza"
    M901="1${NORM} - Limpeza dos Arquivos Temporarios"
    M902="2${NORM} - Adicionar Arquivos no ATUALIZAT "
    M909="9${NORM} - ${RED}Menu Anterior          "

    printf "\n"
    _linha "="
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
    _linha "="
    read -rp "${YELLOW}${M110}${NORM}" OPCAO

    case ${OPCAO} in
        1)  _limpeza ;;
        2)  _addlixo ;;
        9)  clear ; _ferramentas ;;
        *) _ferramentas ;;
    esac    
}

# _limpeza: Limpeza de arquivos temporarios
#
# Le a lista "atualizat" que contem os arquivos a serem excluidas da base do sistema.
#
# Exclui os arquivos temporarios da pasta "${DIRB}" com base na lista "atualizat".

_limpeza () {
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
    for base in $base $base2 $base3; do
        DIRB="${destino}${base}/"
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

#-Rotina de recuperar arquivos---------------------------------------------------------------------#
# _rebuild: Recupera arquivo(s) do backup.
#
# Pergunta ao usuario qual a opcao para recuperar o(s) arquivo(s):
#   1 - Um arquivo ou Todos
#   2 - Arquivos Principais
#   9 - Menu Anterior

_rebuild () { 
    if [[ -e "${TOOLS}"/"atualizaj2" ]]; then
        rm -rf "${TOOLS}"/"atualizaj2"
    fi
    clear
###-600-mensagens do Menu Rebuild.
    M601="Menu de Recuperacao de Arquivo(s)."
	M603="1${NORM} - Um arquivo ou Todos   "
	M604="2${NORM} - Arquivos Principais   "
    M605="9${NORM} - ${RED}Menu Anterior"
	printf "\n"
	_linha "="
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
     _linha "="
     read -rp "${YELLOW}${M110}${NORM}" OPCAO	
     case ${OPCAO} in
     1) _rebuild1 ;;
     2) _rebuildlista ;;
     9) clear ; _ferramentas ;;
     *) _ferramentas ;;
     esac
}



# Funcao para escolher qual base ser  utilizada.
#
# Permite ao usuario escolher qual base ser utilizada. 
# As bases esta gravada no arquivo atualizac.
_escolhe_base () {
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
	_linha "="
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
     _linha "="
     read -rp "${YELLOW}${M110}${NORM}" OPCAO	
if [[ ! "${base3}" ]]; then
     case ${OPCAO} in
    1) 
	     _dbase1 
	     ;;
     2) 
	     _dbase2 
		 ;;
     3) 
         if [[ -n "${base3}" ]]; then
             _dbase3 
         else
             _ferramentas
         fi
         ;;
     9) 
	     clear 
	     _ferramentas 
	     ;;
     *) 
	 _ferramentas 
	 ;;
     esac    

fi    
}

# Configura BASE1 com o caminho para o banco de dados primário.
#
# Esta função define a variável BASE1 para o caminho concatenado
# composto pelas variáveis ​​`destino` e `base`, que representa
# Configura BASE1 com o caminho para o banco de dados primário.
_dbase1 () {
    if [[ -z "${destino}" || -z "${base}" ]]; then
        printf "Erro: Variaveis de ambiente destino ou base nao estao configuradas.\n"
        exit 1
    fi
    BASE1="${destino}${base}"
}

# Configura BASE2 com o caminho para o banco de dados secundário.
_dbase2 () {
    if [[ -z "${destino}" || -z "${base2}" ]]; then
        printf "Erro: Variaveis de ambiente destino ou base2 nao estao configuradas.\n"
        exit 1
    fi
    BASE1="${destino}${base2}"
}

# Configura BASE3 com o caminho para o banco de dados terciário.
_dbase3 () {
    if [[ -z "${destino}" || -z "${base3}" ]]; then
        printf "Erro: Variaveis de ambiente destino ou base3 nao estao configuradas.\n"
        exit 1
    fi
    BASE1="${destino}${base3}"
}

#-Rotina de recuperar arquivos especifico ou todos se deixar em branco-----------------------------#
##- Rotina para rodar o jutil
# Reconstrói um arquivo específico com jutil.
#
# _jutill irá verificar se o arquivo existe e se tem tamanho maior que zero. 
# Se ambas as condições forem atendidas, ele executará o comando jutil com o
# -rebuild opção no arquivo.

_jutill () {
    if [[ -n "${arquivo}" ]] && [[ -e "${arquivo}" ]] && [[ -s "${arquivo}" ]]; then
        if [[ -x "${jut}" ]]; then
            if ! "${jut}" -rebuild "${arquivo}" -a -f; then
                _mensagec "${RED}" "Erro: Falha ao reconstruir o arquivo ${arquivo}."
                return 1
            fi
            _linha
        else
            _mensagec "${RED}" "Erro: Jutil nao encontrado."
            return 1
        fi
    else
        _mensagec "${YELLOW}" "Erro: Arquivo ${arquivo} nao encontrado ou está vazio."
        return 1
    fi
}

_rebuild1 () {
    local base_to_use
    if [[ -n "${base2}" ]]; then
        _escolhe_base
        base_to_use="${BASE1}"
    else
        base_to_use="${destino}${base}"
    fi

    clear
    if [[ "${sistema}" = "iscobol" ]]; then
        _meiodatela
        _mensagec "${CYAN}" "${M64}"
        _linha
        read -rp "${YELLOW}Informe o nome do arquivo: ${NORM}" arquivo

        _linha
        if [[ -z "${arquivo}" ]]; then
            _meiodatela
            _mensagec "${RED}" "${M65}"
            _linha
            if [[ -d "${base_to_use}" ]]; then
                local -a files=("${base_to_use}"/{*.ARQ.dat,*.DAT.dat,*.LOG.dat,*.PAN.dat})
                for arquivo in "${files[@]}"; do
                    if [[ -f "${arquivo}" ]] && [[ -s "${arquivo}" ]]; then
                        _jutill "${arquivo}"
                    else
                        _mensagec "${YELLOW}" "Erro: Arquivo ${arquivo} nao encontrado ou esta vazio."
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
                fi
                _linha
            done
        fi
        _linha
        _mensagec "${YELLOW}" "${M18}"
        _linha

        cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    else
        _meiodatela
        M996="Recuperacao em desenvolvimento :"
        _mensagec "${RED}" "${M996}"
    fi
    _press
    _rebuild
}


#-Rotina de recuperar arquivos de uma Lista os arquivos estao cadatrados em "atualizaj"------------#

#-Arquivos para rebuild ---------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
# Recupera arquivos das listas "atualizaj" e "atualizaj2".
#
# Esta função reconstrói os arquivos listados em "atualizaj" e "atualizaj2",
# se o sistema estiver configurado como "iscobol". Ela primeiro verifica e
# opcionalmente seleciona um diretório base. Em seguida, gera o "atualizaj2"
# arquivo com padrões específicos. Ela lê cada linha de "atualizaj" e
# "atualizaj2", reconstruindo cada arquivo encontrado usando a função _jutill.
#
# Dependências:
# - A função requer acesso aos arquivos "atualizaj" e "atualizaj2",
# e usa a função _jutil para processar cada arquivo.
#
# Pré-condições:
# - O sistema deverá estar configurado como "iscobol".
# - O arquivo "atualizaj" deve existir e ser legível.
#
# Pós-condições:
# - Os arquivos listados em "atualizaj" e "atualizaj2" são processados.
#
# Tratamento de erros:
# - Sai com uma mensagem de erro se "atualizaj2" não puder ser acessado.
_rebuildlista () {
    cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    if [[ "${base2}" ]]; then
        _escolhe_base
    fi
    if [[ "${sistema}" = "iscobol" ]]; then
        cd "${BASE1}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }  
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
        while read -r line; do
            if [[ -z "${line}" ]]; then
                _meiodatela
                _mensagec "${RED}" "Nao foi encontrado o arquivo ${line}"
                _linha
            else
                arquivo="${BASE1}""/""${line}"
                if [[ ! -e "${arquivo}" ]]; then
                    _meiodatela
                    _mensagec "${RED}" "Nao foi encontrado o arquivo ${arquivo}"
                    _linha
                else
                    _jutill   
                fi
            fi
        done < atualizaj
# Trabalhando lista do arquivo "atualizaj2" #
        while read -r line; do
            if [[ -z "${line}" ]]; then
                _meiodatela
                _mensagec "${RED}" "Nao foi encontrado o arquivo ""${line}"
                _linha
            else
                arquivo="${BASE1}""/""${line}"
                if [[ ! -e "${arquivo}" ]]; then
                    _meiodatela
                    _mensagec "${RED}" "Nao foi encontrado o arquivo ""${arquivo}"
                    _linha
                else
                    _jutill   
                fi
            fi
        done < atualizaj2
    #-Lista de Arquivo(s) recuperado(s)... 
        _linha 
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

# _menubackup () - Menu de Backup(s).
#
# Mostra opcoes:
# 1 - Faz backup da base de dados.
# 2 - Restaura backup da base de dados.
# 3 - Envia backup.
# 9 - Volta ao menu anterior.
_menubackup () { while true ; do
     clear
###-700-mensagens do Menu Backup.
     M700="Menu de Backup(s)."
     M702="1${NORM} - Backup da base de dados          "
     M703="2${NORM} - Restaurar Backup da base de dados"
     M704="3${NORM} - Enviar Backup                    "
     M705="9${NORM} - ${RED}Menu Anterior           "
	printf "\n"
	_linha "="
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
	_linha "="
     read -rp "${YELLOW}${M110}${NORM}" OPCAO	
     case ${OPCAO} in
     1) _backup       ;;
     2) _unbackup     ;;
     3) _backupavulso ;;
     9) clear ; _ferramentas ;;
     *) _ferramentas ;;
     esac
     done
}

#-Rotina de backup com opcao de envio da a SAV-----------------------------------------------------#
#      1 - Faz backup da base de dados.
#      2 - Restaura backup da base de dados.
#      3 - Envia backup.
#      9 - Volta ao menu anterior.
#
_backup () {
    clear
    if [[ -n "${base2}" ]]; then
        _escolhe_base
    fi

    if [[ ! -d "${BACKUP}" ]]; then
        M23=".. Criando o diretorio do backup em ${BACKUP}.."
        _linha
        _mensagec "${YELLOW}" "${M23}"
        _linha
        mkdir -p "${BACKUP}"
    fi

    DAYS2=$(find "${BACKUP}" -ctime -2 -name "${EMPRESA}"\*zip)
    cd "${BASE1}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    if [[ -n "${DAYS2}" ]]; then
        M62="Ja existe um backup em ${BACKUP} nos ultimos dias."
        clear
        _linha
        _mensagec "${CYAN}" "${M62}"
        _linha
        printf "\n"
        MB1="          Deseja continuar ? [N/s]: "
        read -rp "${YELLOW}${MB1}${NORM}" -n1
        printf "\n"
        case "${REPLY,,}" in
            [Nn]|"") 
                _linha
                _mensagec "${RED}" "${M47}"
                _linha
                _read_sleep 3
                _ferramentas
                return ;;
            [Ss])
                _linha
                _mensagec "${YELLOW}" "${M06}"
                _linha ;;
            *)
                _opinvalida
                _ferramentas
                return ;;
        esac
    fi

    clear
    _linha
    _mensagec "${YELLOW}" "${M14}"
    _linha
    local ARQ=""
    ARQ="${EMPRESA}"_$(date +%Y%m%d%H%M).zip
_myself () {
     kill $!
    }
    echo -n "${YELLOW}"" Favor aguardar [""${NORM}"
    while true; do
        echo -n "${GREEN}""#""${NORM}"
        _read_sleep 5
    done &
    trap _myself SIGTERM

    _dobackup () {
        "${cmd_zip}" "${BACKUP}/${ARQ}" ./*.* -x ./*.zip ./*.tar ./*tar.gz >/dev/null 2>&1
    }

    _dobackup
    echo "${YELLOW}""] pronto.""${NORM}"
    printf "\n"
    _myself

    M10="O backup de nome :${ARQ}"
    M32="foi criado em ${BACKUP}"
    _linha
    _mensagec "${YELLOW}" "${M10}"
    _mensagec "${YELLOW}" "${M32}"
    _linha
    printf "\n"

    _linha
    _mensagec "${YELLOW}" "${M16}"
    _linha
    read -rp "${YELLOW}${M40}${NORM}" -n1
    printf "\n\n"

    case "${REPLY,,}" in
        [Nn]|"")
            _ferramentas
            return ;;
        [Ss])
            if [[ -z "${SERACESOFF}" ]]; then
                SAOFF=${destino}${SERACESOFF}
                mv -f -- "${BACKUP}/${VBACKUP}" "${SAOFF}"
                MA11="Backup enviado para o diretorio:"
                _linha
                _mensagec "${YELLOW}" "${MA11}"
                _linha
                _press
                _ferramentas
            fi
            if [[ -n "${ENVIABACK}" ]]; then
                ENVBASE="${ENVIABACK}"
            else
                _meiodatela
                _mensagec "${RED}" "${M68}"
                read -rp "${YELLOW}${M41}${NORM}" ENVBASE
                while [[ "${ENVBASE}" =~ [0-9] || -z "${ENVBASE}" ]]; do
                    _meiodatela
                    _mensagec "${RED}" "${M69}"
                    _press
                    _ferramentas
                done
            fi
            _linha
            _mensagec "${YELLOW}" "${M29}"
            _linha
            rsync -avzP -e "ssh -p ${PORTA}" "${BACKUP}/${ARQ}" "${USUARIO}@${IPSERVER}:/${ENVBASE}"
 #           scp -r -P "${PORTA}" "${BACKUP}/${ARQ}" "${USUARIO}@${IPSERVER}:/${ENVBASE}"
            M15="Backup enviado para a pasta, \"""${ENVBASE}""\"."
            _linha
            _mensagec "${YELLOW}" "${M15}"
            _linha
            _read_sleep 3 ;;
        *)
            _opinvalida
            _ferramentas
            return ;;
    esac

    M16="Mantem o backup ? [S/n]"
    _linha
    read -rp "${YELLOW}${M16}${NORM}" -n1
    printf "\n\n"

    if [[ "${REPLY,,}" =~ ^[Nn]$ ]] || [[ "${REPLY,,}" == "" ]]; then
        rm -f -- "${BACKUP}/${ARQ}"
        MA17="Backup excluido:"
        _linha
        _mensagec "${YELLOW}" "${MA17}"
        _linha
        _press
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
_backupavulso () {
     clear 
     ls "${BACKUP}"/"${EMPRESA}"_*.zip
#-Informe de qual o Backup que deseja enviar.
     _linha 
     _mensagec "${RED}" "${M52}"
     _linha      
     read -rp "${YELLOW}${M42}${NORM}" VBACKAV
     local VBACKUP="${EMPRESA}"_"${VBACKAV}".zip
while [[ -f "${VBACKUP}" || -z "${VBACKUP}" ]] ; do 
     clear
     _meiodatela
     _mensagec "${RED}" "${M70}"
     _press
     _ferramentas
done
if [[ ! -r "${BACKUP}"/"${VBACKUP}" ]]; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec "${RED}" "${M45}"
     _linha     
     _press
     _ferramentas
fi
     printf "\n"
     clear
     _meiodatela
MA1="O backup \"""${VBACKUP}""\""     
     _linha
     _mensagec "${YELLOW}" "${MA1}"
     _linha 

if [[ -z "${SERACESOFF}" ]]; then 
          SAOFF=${destino}${SERACESOFF}
          mv -f -- "${BACKUP}"/"${VBACKUP}" "${SAOFF}"
MA11="Backup enviado para o diretorio:"   
     _linha
     _mensagec "${YELLOW}" "${MA11}"
     _linha 
          _press    
     _ferramentas 
fi

     _linha 
     read -rp "${YELLOW}${M40}${NORM}" -n1 
     printf "\n\n"
if [[ "${REPLY,,}" =~ ^[Nn]$ ]] || [[ "${REPLY,,}" == "" ]]; then    
     _ferramentas
elif [[ "${REPLY,,}" =~ ^[Ss]$ ]]; then
     if [[ "${ENVIABACK}" != "" ]]; then
     ENVBASE="${ENVIABACK}"
     else
     _meiodatela
     _mensagec "${RED}" "${M68}"
     _linha
     read -rp "${YELLOW}${M41}${NORM}" ENVBASE
     while [[ "${ENVBASE}" =~ [0-9] || -f "${ENVBASE}" ]] ; do
     _meiodatela
     _mensagec "${RED}" "${M69}"
     _press    
     _ferramentas 
     done
     fi
#-Informe a senha do usuario do rsync
     _linha 
     _mensagec "${YELLOW}""${M29}"
     _linha 
     if [[ -n "${IPSERVER}" && -n "${PORTA}" ]]; then
       rsync -avzP -e "ssh -p ${PORTA}" "${BACKUP}""/""${VBACKUP}" "${USUARIO}"@"${IPSERVER}":/"${ENVBASE}" 
     M15="Backup enviado para a pasta, \"""${ENVBASE}""\"."
     _linha 
     _mensagec "${YELLOW}" "${M15}"
     _linha 
     _read_sleep 3 
     else
     _meiodatela
     _mensagec "${RED}" "${M71}"
     _press    
     _ferramentas
     fi
else
     _opinvalida
     _ferramentas   
fi	 
}   

#-VOLTA BACKUP TOTAL OU PARCIAL--------------------------------------------------------------------#
# Esta função trata do processo de restauração de um backup anterior do sistema.
# Ele solicita ao usuário a data do backup para restaurar e verifica a existência do
# arquivo de backup no diretório especificado. Se o backup não for encontrado, ele retorna ao menu anterior.
# O usuário é questionado se deseja restaurar todos os arquivos para o estado anterior à atualização. Baseado em
# resposta do usuário, ele restaura arquivos específicos ou todos os arquivos para suas versões anteriores.
_unbackup () {
local DIRBACK="${BACKUP}"/dados
local VBACKUP="${EMPRESA}"_"${VBACK}"".zip"

if [[ ! -d "${DIRBACK}" ]]; then
    M22=".. Criando o diretorio temp do backup em ${DIRBACK}.." 
    _linha 
    _mensagec "${YELLOW}" "${M22}"
    _linha 
    mkdir -p "${DIRBACK}"
fi

ls -s "${BACKUP}""/""${EMPRESA}"_*.zip
_linha 
_mensagec "${RED}" "${M53}"
_linha
MA9="         1- Informe somente a data do BACKUP: " 
read -rp "${YELLOW}${MA9}${NORM}" VBACK
while [[ -f "${VBACKUP}" || -z "${VBACKUP}" ]]; do 
    clear
    _meiodatela
    _mensagec "${RED}" "${M70}"
    _press
    _menubackup
done

if [[ ! -r "${BACKUP}"/"${VBACKUP}" ]]; then
    #-"Backup nao encontrado no diretorio"
    _linha 
    _mensagec "${RED}" "${M45}"
    _linha 
    _press
    _menubackup
fi

printf "\n" 
#"Deseja volta todos os ARQUIVOS do Backup ? [N/s]:"
_linha 
read -rp "${YELLOW}${M35}${NORM}" -n1 
printf "\n\n"

if [[ "${REPLY,,}" =~ ^[Nn]$ ]] || [[ "${REPLY,,}" == "" ]]; then
    MB1="       2- Informe o somente nome do arquivo em maiusculo: "
    read -rp "${YELLOW}${MB1}${NORM}" VARQUIVO
    while [[ "${VARQUIVO}" =~ [^A-Z0-9] || -z "${VARQUIVO}" ]] ; do
        _mensagec "${RED}" "${M71}"
        _linha 
        _press
        _menubackup
    done

    #-"Voltando Backup anterior  ...-#
    M34="O arquivo ""${VARQUIVO}"
    _linha 
    _mensagec "${YELLOW}" "${M33}"
    _mensagec "${YELLOW}" "${M34}"
    _linha 
    cd "${DIRBACK}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    "${cmd_unzip}" -o "${BACKUP}""/""${VBACKUP}" "${VARQUIVO}*.*" >> "${LOG_ATU}"
    _read_sleep 1
    if ls -s "${VARQUIVO}"*.* >erro /dev/null 2>&1 ; then
        #-"Arquivo encontrado no diretorio"
        _linha 
        _mensagec "${YELLOW}" "${M28}"
        _linha 
    else
        #-"Arquivo nao encontrado no diretorio"
        _linha 
        _mensagec "${YELLOW}" "${M49}"
        _linha 
        _press 
        _menubackup  
    fi
    mv -f "${VARQUIVO}"*.* "${BASE1}" >> "${LOG_ATU}" 
    cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    clear
    #-"VOLTA DO ARQUIVO CONCLUIDA"
    _linha 
    _mensagec "${YELLOW}" "${M04}"
    _linha 
    _press
    _menubackup
elif [[ "${REPLY,,}" =~ ^[Ss]$ ]]; then

    #---- Voltando Backup anterior  ... ----
    M34="O arquivo ""${VARQUIVO}"
    _linha 
    _mensagec "${YELLOW}" "${M33}"
    _mensagec "${YELLOW}" "${M34}"
    _linha 
    cd "${DIRBACK}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    "${cmd_unzip}" -o "${BACKUP}""/""${VBACKUP}" >> "${LOG_ATU}"
    mv -f -- *.* "${BASE1}" >> "${LOG_ATU}"
    cd "${TOOLS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
    clear
    #-"VOLTA DOS ARQUIVOS CONCLUIDA"
    _linha 
    _mensagec "${YELLOW}" "${M04}"
    _linha 
    _press
else
    _opinvalida
fi
_ferramentas
}

#-Envia e receber arquivos-------------------------------------------------------------------------#
###-Funcao _envrecarq---------------------------------------------------------------
##  Menu de Envio e Retorno de Arquivos.
##  Chama as funcoes _envia_avulso() e _recebe_avulso() para o envio e recebimento de arquivos.
##  Opcoes:
##  1 - Envia arquivo(s)
##  2 - Recebe arquivo(s)
##  9 - Menu Anterior
##-----------------------------------------------------------------------------------------------
_envrecarq () { 
     clear
###-800-mensagens do Menu Envio e Retorno.
     M800="Menu de Enviar e Receber Arquivo(s)."
     M802="1${NORM} - Enviar arquivo(s)     "
     M803="2${NORM} - Receber arquivo(s)    "
     M806="9${NORM} - ${RED}Menu Anterior"
	printf "\n"
	_linha "="
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
	_linha "="
     read -rp "${YELLOW}${M110}${NORM}" OPCAO	
     case ${OPCAO} in
     1) _envia_avulso    ;;
     2) _recebe_avulso   ;;
     9) clear ; _ferramentas ;;
     *) _ferramentas ;;
     esac
}

###---_envia_avulso-------------------------------------------------------------
##  Funcao para Enviar um arquivo avulso.
##  Chama as funcoes _envia_avulso() e _recebe_avulso() para o envio e recebimento de arquivos.
##  Opcoes:
##  1 - Envia arquivo(s)
##  2 - Recebe arquivo(s)
##  9 - Menu Anterior
##-----------------------------------------------------------------------------------------------
_envia_avulso () {
     clear
     printf "\n\n\n"
### Pedir diretorio origem do arquivo    
     _linha 
M991="1- Origem: Informe em que diretorio esta o arquivo a ser enviado :"   
     _mensagec "${YELLOW}" "${M991}"  
     read -rp "${YELLOW}"" -> ""${NORM}" DIRENVIA
     _linha 
     local VERDIR=${DIRENVIA}
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
_recebe_avulso () {
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

########################################################
# Limpando arquivos de atualizacao com mais de 30 dias #
########################################################
# _expurgador ()
# Limpa arquivos de atualizacao com mais de 30 dias na pasta de backup.
# Apaga todos os arquivos do diretorio backup, olds, progs e logs.
# Apaga arquivos do diretorio do /portalsav/log e /err_isc/.
_expurgador () {
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
     for ARQS in $DIR1 $DIR2 $DIR3 $DIR4 $DIR5 $DIR6; do
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
_update () {
local SAOFF="${destino}${SERACESOFF}"
if [[ -z "${SERACESOFF}" ]]; then 
     link="https://github.com/Luizaugusto1962/Atualiza/archive/master/atualiza.zip"
     clear
     printf "\n\n"
     _linha 
     _mensagec "${GREEN}" "${M91}"
     _mensagec "${GREEN}" "${M92}"
     _linha 
     cp -rfv atualiza.sh "${BACKUP}" &> /dev/null
     cd "${PROGS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
     wget -q -c "${link}" || exit

#-Descompactando o programa baixado----------------------------------#
DEFAULT_ATUALIZAGIT="atualiza.zip"
    if [[ -z "${atualizagit}" ]]; then
         atualizagit="${DEFAULT_ATUALIZAGIT}"
    fi
     "${cmd_unzip}" -o "${atualizagit}" >> "${LOG_ATU}"
     _read_sleep 1
     "${cmd_find}" "${PROGS}" -name "${atualizagit}" -type f -delete 
     cd "${PROGS}"/Atualiza-main || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
     #-Atualizando somente o atualiza.sh----------------------------------#
     if [[ -f "atualiza.sh" && -f "setup.sh" ]]; then
         chmod +x "setup.sh" "atualiza.sh"
         mv -f -- "atualiza.sh" "${TOOLS}" >> "${LOG_ATU}"
         mv -f -- "setup.sh" "${TOOLS}" >> "${LOG_ATU}"
         cd "${PROGS}" || { printf "Erro: Diretorio ${TOOLS} nao encontrado.""%*s\n"; exit 1; }
         rm -rf "${PROGS}"/Atualiza-main
         exit 1
     else
         _mensagec "${RED}" "Erro: Arquivos atualiza.sh e setup.sh, nao encontrados na pasta ${PROGS}/Atualiza-main"
         exit 1
     fi
else
    for pacoteoff in "atualiza.sh" "setup.sh" "atualizaj" "atualizat"; do
        if [[ -f "${SAOFF}/${pacoteoff}" ]]; then
            mv -f -- "${SAOFF}/${pacoteoff}" "${TOOLS}" >> "${LOG_ATU}"
            chmod 777 "$pacoteoff"  
        else
            _mensagec "${RED}" "Erro: Arquivo ${pacoteoff} nao encontrado na pasta ${SAOFF}"
        fi
    done
    chmod +x "*.sh"
fi
}

#_parametros ()
# Mostra os parametros de configuracao do sistema, base de dados, diretorios
# do atualiza.sh, base principal, segunda base, terceira base, executaveis,
# telas, xmls, logs, olds, progs, backup, sistema em uso, bibliotecas
# sendo usadas, variaveis da classe e da mclasse, e o diretorio para onde
# enviar o backup, e o diretorio do servidor OFF.
_parametros () {
     clear
     _linha
printf "${GREEN}""Sistema e banco de dados: ""${NORM}""${BANCO}""%*s\n"     
printf "${GREEN}""O diretorio raiz e: ""${NORM}""${destino}""%*s\n"
printf "${GREEN}""O diretorio do atualiza.sh: ""${NORM}""${destino}""${pasta}""%*s\n"
printf "${GREEN}""O diretorio da base Principal : ""${NORM}""${destino}""${base}""%*s\n"
printf "${GREEN}""O diretorio da Segunda base: ""${NORM}""${destino}""${base2}""%*s\n"
printf "${GREEN}""O diretorio da Terceira base: ""${NORM}""${destino}""${base3}""%*s\n"
printf "${GREEN}""O diretorio do executavies: ""${NORM}""${destino}""/""${exec}""%*s\n"
printf "${GREEN}""O diretorio das telas: ""${NORM}""${destino}""/""${telas}""%*s\n"
printf "${GREEN}""O diretorio dos xmls: ""${NORM}""${destino}""/""${xml}""%*s\n"
printf "${GREEN}""O diretorio dos logs: ""${NORM}""${destino}""${logs}""%*s\n"
printf "${GREEN}""O diretorio dos olds: ""${NORM}""${destino}""${pasta}""${olds}""%*s\n"
printf "${GREEN}""O diretorio dos progs: ""${NORM}""${destino}""${pasta}""${progs}""%*s\n"
printf "${GREEN}""O diretorio do backup: ""${NORM}""${destino}""${pasta}""${backup}""%*s\n"
printf "${GREEN}""Qual o sistem em uso: ""${NORM}""${sistema}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 1: ""${NORM}""${SAVATU1}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 2: ""${NORM}""${SAVATU2}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 3: ""${NORM}""${SAVATU3}""%*s\n"
printf "${GREEN}""Biblioteca sendo usada 4: ""${NORM}""${SAVATU4}""%*s\n"
_linha
_press
clear
_linha
printf "${GREEN}""O diretorio para onde enviar o backup: ""${NORM}""${ENVIABACK}""%*s\n"
printf "${GREEN}""O diretorio Servidor OFF: ""${NORM}""${SERACESOFF}""%*s\n"
printf "${GREEN}""Versao anterior da Biblioteca: ""${NORM}""${VERSAOANT}""%*s\n"
printf "${GREEN}""Variavel da classe: ""${NORM}""${class}""%*s\n"
printf "${GREEN}""Variavel da mclasse: ""${NORM}""${mclass}""%*s\n"
_linha
_press
_ferramentas
}

_principal

tput clear
tput sgr0
tput cup "$( tput lines )" 0
clear
