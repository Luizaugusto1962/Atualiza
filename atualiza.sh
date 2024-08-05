#!/bin/bash 
#                                                                                                                      #                                                               
#    ________  __      ________  ___________  _______  ___      ___       __            ________     __  ___      ___  #
#   /"       )|" \    /"       )("     _   ")/"     "||"  \    /"  |     /""\          /"       )   /""\|"  \    /"  | #
#  (:   \___/ ||  |  (:   \___/  )__/  \\__/(: ______) \   \  //   |    /    \        (:   \___/   /    \\   \  //  /  #
#   \___  \   |:  |   \___  \       \\_ /    \/    |   /\\  \/.    |   /' /\  \        \___  \    /' /\  \\\  \/. ./   #
#    __/  \\  |.  |    __/  \\      |.  |    // ___)_ |: \.        |  //  __'  \        __/  \\  //  __'  \\.    //    #
#   /" \   :) /\  |\  /" \   :)     \:  |   (:      "||.  \    /:  | /   /  \\  \      /" \   :)/   /  \\  \\\   /     #
#  (_______/ (__\_|_)(_______/       \__|    \_______)|___|\__/|___|(___/    \___)    (_______/(___/    \___)\__/      #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#
##  Rotina para atualizar programas e bibliotecas da SAV                                                               #
##  Feito por Luiz Augusto   email luizaugusto@sav.com.br                                                              #
##  Versao do atualiza.sh                                                                                              #
UPDATE="01/08/2024"                                                                                                    #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#
# Arquivos de trabalho:                                                                                                #
# "atualizac"  = Contem a configuracao referente a empresa           e                                                 #
# "atualizap"  = Configuracao do parametro do sistema                                                                  #
# "atualizaj"  = Lista de arquivos principais para dar rebuild.                                                        #
# "atualizaj2" = Lista de arquivos ATE*s E NFE*s para dar rebuild.                                                     #
# "atualizat   = Lista de arquivos temporarios a ser excluidos da pasta de dados.                                      #
#               Sao zipados em /backup/Temps-dia-mes-ano-horario.zip                                                   #
# "setup.sh"   = Configurador para criar os arquivos atualizac e atualizap                                             #
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
#      Acessa o servidor da SAV via scp com o usuario ATUALIZA                                                         #
#      Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                                       #
#      com o nome "Nome do programa-anterior.zip" descompacta o novo no diretorio                                      #
#      dos programa e salva o a atualizacao na pasta ?/sav/tmp/progs.                                                  #
#            1.2 - OFF-Line                                                                                            #
#      Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.                                  #
#      O processo de atualizacao e id ntico ao passo acima.                                                            #
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
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backcup-versao da biblioteca".zip)       #
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
#               Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup                              #
#               com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                                         #
#                                                                                                                      #
#           6.2 - Recuperar arquivos                                                                                   #
#               6.2.1 - Um arquivo ou Todos                                                                            #
#                   Opcao pede para informa um arquivo espec fico, somente o nome sem a extensao                       #
#                   ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com as extens es,         #
#                   "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"                                                    #
#                                                                                                                      #
#               6.2.2 - Arquivos Principais                                                                            #
#                   Roda o Jtuil somente nos arquivos que estao na lista "atualizaj"                                   #
#                                                                                                                      #
#           3 - Backup da base de dados                                                                                #
#               Faz um backup da pasta de dados  e tem a opcao de enviar para a SAV                                    #
#                                                                                                                      #
#           4 - Restaurar Backup da base de dados                                                                      #
#               Volta o backup feito pela opcao acima                                                                  #
#                                                                                                                      #
#           5 - Enviar Backup                                                                                          #
#               Enviar ZIP feito pela opcao 3                                                                          #
#                                                                                                                      #
#           6 - Expurgar                                                                                               #
#               Excluir, zips e bkps com mais de 30 dias processado dos diretorios:                                    #
#                /backup, /olds /progs e /logs                                                                         #
#           9 - Update                                                                                                 #
#               Atualizacao do programa atualiza.sh                                                                    #
#                                                                                                                      #
#--------------------------------------------------------------------------------------------------#
#Zerando variaves utilizadas 
resetando () {
unset -v RED GREEN YELLOW BLUE PURPLE CYAN NORM
unset -v BASE1 BASE2 BASE3 tools DIR1 OLDS PROGS BACKUP 
unset -v destino pasta base base2 base3 logs exec class telas xml
unset -v olds progs backup sistema SAVATU1 SAVATU2 SAVATU3 SAVATU4
unset -v TEMPS UMADATA DIRB ENVIABACK ENVBASE SERACESOFF
unset -v E_EXEC T_TELAS X_XML NOMEPROG NPROG OLDPROG
tput sgr0; exit 
}

#-VARIAVEIS que devem vir do atualizac ------------------------------------------------------------#
destino=""
pasta=""
base=""
base2=""
base3=""
logs=""
exec=""
class=""
telas=""
xml=""
olds=""
progs=""
backup=""
sistema=""
SAVATU1=""
SAVATU2=""
SAVATU3=""
SAVATU4=""
ENVIABACK=""
VERSAO=""
INI=""
SERACESOFF=""

#-Variaveis de cores-------------------------------------------------------------------------------#
# TERM=xterm-256color
tput sgr0
tput clear 
tput bold
tput setaf 7
RED=$(tput bold)$(tput setaf 1) 
GREEN=$(tput bold)$(tput setaf 2)
YELLOW=$(tput bold)$(tput setaf 3)
BLUE=$(tput bold)$(tput setaf 4)
PURPLE=$(tput bold)$(tput setaf 5) 
CYAN=$(tput bold)$(tput setaf 6)
NORM=$(tput bold)$(tput setaf 7)
COLUMNS=$(tput cols)

#-Conectores---------------------------------------------------------------------------------------#

#### configurar as variaveis em ambiente no arquivo abaixo:    ####
#- TESTE de CONFIGURACOES--------------------------------------------------------------------------#

[[ ! -e "atualizac" ]] && printf "ERRO. Arquivo atualizac, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizac" ]] && printf "ERRO. Arquivo atualizac, Sem acesso de leitura.\n" && exit 1

[[ ! -e "atualizap" ]] && printf "ERRO. Arquivo atualizap, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizap" ]] && printf "ERRO. Arquivo atualizap, Sem acesso de leitura.\n" && exit 1

# Arquivo de configuracao para a empresa
"." ./atualizac
# Arquivo de configuracao para o atualiza.sh
"." ./atualizap
#--------------------------------------------------------------------------------------------------#
# Funcao para checar se o zip esta instalado
check_zip_instalado() {
Z1="Aparentemente o programa zip nao esta instalado neste distribuicao."
     if ! command -v zip &> /dev/null; then
     printf "\n"
     printf "%*s""${RED}" ;printf "%*s\n" $(((${#Z1}+COLUMNS)/2)) "$Z1" ;printf "%*s""${NORM}"
     printf "\n"
     exit 1
     fi

Z2="Aparentemente o programa zip nao esta instalado neste distribuicao."
     if ! command -v unzip &> /dev/null; then
     printf "\n"
     printf "%*s""${RED}" ;printf "%*s\n" $(((${#Z2}+COLUMNS)/2)) "$Z2" ;printf "%*s""${NORM}"
     printf "\n"
     exit 1
     fi
}
# Checando se o zip esta na base
check_zip_instalado

#-Comandos#----------------------------------------------------------------------------------------#
DEFAULT_UNZIP="unzip"
if [ -z "$cmd_unzip" ]; then
          cmd_unzip="$DEFAULT_UNZIP"
fi

DEFAULT_ZIP="zip"
if [ -z "$cmd_zip" ]; then
          cmd_zip="$DEFAULT_ZIP"
fi

DEFAULT_FIND="find"
if [ -z "$cmd_find" ]; then
          cmd_find="$DEFAULT_FIND"
fi

DEFAULT_SCP="scp"
if [ -z "$cmd_scp" ]; then
          cmd_scp="$DEFAULT_SCP"
fi

DEFAULT_WHO="who"
if [ -z "$cmd_who" ]; then
          cmd_who="$DEFAULT_WHO"
fi

#-Lista de mensagens #-----------------------------------------------------------------------------#
### Mensagens em AMARELO
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
M17="Atualizacao Completa"
M18="Arquivo(s) recuperado(s)..."
M19="ATUALIZANDO OS PROGRAMAS..."
M20="Alterando a extensao da atualizacao"
M24=".. BACKUP do programa efetuado .." 
M25="... Voltando versao anterior ..." 
M26="... Agora, ATUALIZANDO ..." 
M27=" .. Backup Completo .." 
M28="Arquivo encontrado no diretorio" 
M29="Informe a senha do usuario do SCP"
M33="Voltando Backup anterior  ..."
M35="Deseja voltar todos os ARQUIVOS do Backup ? [N/s]:"
M36="<< ... Pressione qualquer tecla para continuar ... >>"
M37="Deseja informar mais algum programa para ser atualizado? [S/n]"
M38="Deseja continuar a atualizacao? [n/S]:"
M39="Continuando a atualizacao...:"
M40="      Deseja enviar para o servidor da SAV ? [N/s]:"
M41="         Informe para qual diretorio no servidor: "
M42="         1- Informe nome BACKUP: "
M43=" "
MA1="O backup \"""$VBACKUP""\""
MA2="         1- Informe apos qual versao da BIBLIOTECA: "
## Mensagens em VERMELHO
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
M58="Voltando todos os programas."
M59="Informe o nome do programa a ser atualizado:"
M60="Faltou informou o nome do programa a ser atualizado ou esta em minusculo"
M61="Informe o nome do programa a ser desatualizado:" 
M62="Informe a ultima versao que foi feita a atualizacao da biblioteca."
M64=" Informe o nome do arquivo ser recuperado OU enter para todos os arquivos:"
M65="Recuperado todos os arquivos:"
M66="Voce nao informou o nome do arquivo em minusculo"
M68="Enviar backup para a SAV."
M69="Voce nao informou o nome do diretorio a ser enviado, saindo... "
M70="* * * < < Nome do Backup nao foi informada > > * * * "
M71="ERRO: Voce informou o nome do arquivo em minusculo ou em branco "
M72="Informe o(s) arquivo(s) que deseja enviar."
M73="Informe o(s) arquivo(s) que deseja receber."
M74="* * * < < Nome do Arquivo nao foi informada > > * * *"

## Mensagens em cyan
M80="..Checando estrutura dos diretorios do atualiza.sh.." 
M81="..Encontrado o diretorio do sistema .." 

## Mensagens em VERDE
M91="Atualizar este sistema"
M92="ao termino da atualizacao sair e entrar novamente"

#-Centro da tela-----------------------------------------------------------------------------------#
_meiodatela () {
     printf "\033c\033[10;10H\n"
}

#-Mensagem centralizada----------------------------------------------------------------------------#
_mensagec () {
local CCC="$1"
local MXX="$2"
printf "%*s""${CCC}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
}

#-Variavel para identificar -----------------------------------------------------------------------#
##
DEFAULT_VERSAO=""
if [ -z "$VERSAO" ]; then
          VERSAO="$DEFAULT_VERSAO"
fi

SAVISCC="${destino}""/sav/savisc/iscobol/bin/"
if [ -n "$SAVISCC" ]; then
          SAVISC=$SAVISCC
fi

JUTILL="jutil"
if [ -n "$JUTILL" ]; then
          JUTIL=$JUTILL
fi

ISCCLIENTT="iscclient"
if [ -n "$ISCCLIENTT" ]; then
          ISCCLIENT=$ISCCLIENTT
fi

DEFAULT_ARQUIVO=""
if [ -z "$ARQUIVO" ]; then
          ARQUIVO="$DEFAULT_ARQUIVO"
fi

DEFAULT_PEDARQ=""
if [ -z "$PEDARQ" ]; then
          PEDARQ="$DEFAULT_PEDARQ"
fi

DEFAULT_PROG=""
if [ -z "$prog" ]; then
          prog="$DEFAULT_PROG"
fi

## Testa se as pastas do atualizac e dp atualizap estao configuradas
     if [ -n "${pasta}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "Diretorio do Tools, nao esta configurado  \n"
     exit
     fi

     if [ -n "${base}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "Diretorio da Base de dados, nao esta configurado  \n"
     exit
     fi 

     if [ -n "${exec}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "Diretorio dos programas, nao esta configurado  \n"
     exit
     fi    

     if [ -n "${telas}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "Diretorio das Telas, nao esta configurado \n"
     exit
     fi    
if [ "$sistema" = "iscobol" ]; then
     if [ -n "${xml}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "Diretorio dos Xmls do sistema, nao esta configurado  \n"
     exit
     fi 
fi     
# Verificacao de diretorio necessarios ------------------------------------------------------------#
E_EXEC=${destino}${exec}
     if [ -d "${E_EXEC}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da destino nao encontrado ""${E_EXEC}""...  \n"
     exit
     fi

T_TELAS=${destino}${telas}
     if [ -d "${T_TELAS}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da destino nao encontrado ""${T_TELAS}""...  \n"
     exit
     fi

X_XML=${destino}${xml}
     if [ -d "${X_XML}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da destino nao encontrado ""${X_XML}""...  \n"
     exit
     fi     

TOOLS=${destino}${pasta}
     if [ -d "${TOOLS}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da destino nao encontrado ""${TOOLS}""...  \n"
     exit
     fi

BASE1=${destino}${base}
     if [ -d "${BASE1}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da base nao encontrado ""${BASE1}""...  \n"
     exit
     fi

BASE2=${destino}${base2}
     if [ -d "${BASE2}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da base nao encontrado ""${BASE2}""...  \n"
     exit
     fi

BASE3=${destino}${base3}
     if [ -d "${BASE3}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     printf "%*s""Diretorio da base nao encontrado ""${BASE3}""...  \n"
     exit
     fi     

#-Configuracao para acesso ao scp------------------------------------------------------------------#
DEFAULT_PORTA="41122"
if [ -z "${PORTA}" ]; then
     PORTA="$DEFAULT_PORTA"
fi

DEFAULT_USUARIO="atualiza"
if [ -z "${USUARIO}" ]; then
     USUARIO="$DEFAULT_USUARIO"
fi

DEFAULT_IPSERVER="177.115.194.15"
if [ -z "${IPSERVER}" ]; then
     IPSERVER="$DEFAULT_IPSERVER"
fi

DEFAULT_DESTINO2=""
if [ -z "${DESTINO2}" ]; then
     DESTINO2="$DEFAULT_DESTINO2"
fi

DEFAULT_ENVIABACK=""
if [ -z "${ENVIABACK}" ]; then
     ENVIABACK="$DEFAULT_ENVIABACK"
fi
## ------- Parametro para a atualizacao --------
DESTINO2SERVER="/u/varejo/man/"
DESTINO2SAVATUISC="/home/savatu/biblioteca/temp/ISCobol/sav-5.0/"
DESTINO2SAVATUMF="/home/savatu/biblioteca/temp/Isam/sav-3.1"
DESTINO2TRANSPC="/u/varejo/trans_pc/"

#-Processo do scp----------------------------------------------------------------------------------#
_run_scp () {
     "$cmd_scp" -C -r -P "$PORTA" "$USUARIO"@"$IPSERVER":"$DESTINO2SERVER""$NOMEPROG" .
}

#-Processo do scp2---------------------------------------------------------------------------------#
_run_scp2 () {     
# programas da biblioteca
     "$cmd_scp" -C -r -P "$PORTA" "$USUARIO"@"$IPSERVER":"$DESTINO2""${atu}""$VERSAO".zip . 
}

#-Funcao de sleep----------------------------------------------------------------------------------#
_read_sleep () {
# Usage: _read_sleep 1
#        _read_sleep 0.2
     read -rt "$1" <> <(:) || :
}

#-Funcao teclar qualquer tecla---------------------------------------------------------------------#
_press () {
     printf "%*s""${YELLOW}" ;printf "%*s\n" $(((${#M36}+COLUMNS)/2)) "${M36}" ;printf "%*s""${NORM}"
     read -rt 15 || :
     tput sgr0
}

#-Escolha qual o tipo de traco---------------------------------------------------------------------#
_linha () {
     local Traco=${1:-'-'}
# quantidade de tracos por linha
     printf -v Espacos "%$(tput cols)s""" 
     linhas=${Espacos// /$Traco}
	printf "%*s\n" $(((${#linhas}+COLUMNS)/2)) "$linhas"
}

#   Opção Invalida
_opinvalida () {  
     _linha 
     _mensagec "$YELLOW" "$M08"
     _linha  
}      

#-Verificacoes de parametro e diretorios-----------------------------------------------------------#

clear
if [ -d "${E_EXEC}" ]; then
     _mensagec "$CYAN" "$M81"
else
M44="Nao foi encontrado o diretorio ""${E_EXEC}"
     _linha "*"
     _mensagec "$RED" "$M44"
     _linha "*"
     _read_sleep 2
     exit
fi

if [ -d "${T_TELAS}" ]; then
     _mensagec "$CYAN" "$M81"
else
M44="Nao foi encontrado o diretorio ""${T_TELAS}"
     _linha "*"
     _mensagec "$RED" "$M44"
     _linha "*"
     _read_sleep 2
     exit
fi

if [ "$sistema" = "iscobol" ]; then 
     if [ -d "${X_XML}" ]; then
     _mensagec "$CYAN" "$M81"
     else
     M44="Nao foi encontrado o diretorio ""${X_XML}"
     _linha "*"
     _mensagec "$RED" "$M44"
     _linha "*"
     _read_sleep 2
     exit
     fi
fi

if [ "${SERACESOFF}" != " " ]; then 
mkdir -p "${destino}${SERACESOFF}"
fi

if [ -d "${TOOLS}" ]; then
     _linha "*"
     _mensagec "$CYAN" "$M80"
     _linha "*"
          OLDS=${TOOLS}${olds}
          if [ -d "${OLDS}" ]; then
               printf " Diretorio olds ... ok \n"
          else
               mkdir -p "${OLDS}"
          fi
		PROGS=${TOOLS}${progs}
          if [ -d "${PROGS}" ]; then
               printf " Diretorio progs ... ok \n"
          else
               mkdir -p "${PROGS}"
          fi
          LOGS=${TOOLS}${logs}
          if [ -d "${LOGS}" ]; then
               printf " Diretorio logs ... ok \n"
          else
               mkdir -p "${LOGS}"
          fi
		BACKUP=${TOOLS}$backup
          if [ -d "${BACKUP}" ]; then
          printf " Diretorio backups ... ok \n"
          else
               mkdir -p "$BACKUP"
          fi
          ENVIA=${TOOLS}"/envia"
          if [ -d "${ENVIA}" ]; then
               printf " Diretorio envia ... ok \n"
          else
               mkdir -p "$ENVIA"
          fi
		RECEBE=${TOOLS}"/recebe"
          if [ -d "${RECEBE}" ]; then
               printf " Diretorio recebe ... ok \n"
          else
               mkdir -p "$RECEBE"
          fi
else
     exit
fi

#### PARAMETRO PARA O LOGS ------------------------------------------------------------------------#
LOG_ATU=${LOGS}/atualiza.$(date +"%Y-%m-%d").log
LOG_LIMPA=${LOGS}/limpando.$(date +"%Y-%m-%d").log
LOG_TMP=${LOGS}/
UMADATA=$(date +"%d-%m-%Y_%H%M%S")

clear

_principal () { 
     tput clear
	printf "\n"
#-100-mensagens do Menu Principal. ----------------------------------------------------------------#	
	M101="Menu de Opcoes""   -   Versao: ""${BLUE}""$UPDATE""${NORM}"
	M102=".. Sistema: ""$sistema"" ..  =  ..Empresa: ""$EMPRESA"" .."
	M103="Escolha a opcao:   "
	M104="1${NORM} - Atualizacao de Programas "
     M105="2${NORM} - Atualizacao de Biblioteca" 
     M106="3${NORM} - Desatualizando           "
	M111="4${NORM} - Versao do Iscobol        "
	M112="4${NORM} - Funcao nao disponivel    "
	M107="5${NORM} - Versao do Linux          "
     M108="6${NORM} - Ferramentas              "
     M109="9${NORM} - ${RED}Sair            "
     M110=" Digite a opcao desejada -> " 

	_linha "="
	_mensagec "$RED" "$M101"
	_linha
	_mensagec "$CYAN" "$M102"
	_linha "="
	_mensagec "$PURPLE" "$M103"
	printf "\n"
	_mensagec "$GREEN" "$M104"
	printf "\n"
	_mensagec "$GREEN" "$M105"
	printf "\n"
	_mensagec "$GREEN" "$M106"
	printf "\n"
          if [ "$sistema" = "iscobol" ]; then
          _mensagec "$GREEN" "$M111"
          else
          _mensagec "$GREEN" "$M112"
          fi
	printf "\n"
	_mensagec "$GREEN" "$M107"
	printf "\n"
	_mensagec "$GREEN" "$M108"
	printf "\n"
	_mensagec "$GREEN" "$M109"
     printf "\n"
     _linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO

     case $OPCAO in
          1) _atualizacao   ;;
          2) _biblioteca    ;;
          3) _desatualizado ;;
          4) _iscobol       ;;
          5) _linux         ;;
          6) _ferramentas   ;;
          9) clear ; resetando ;;
          *) clear ; _principal ;;
     esac
}

#-Procedimento da atualizacao de programas---------------------------------------------------------# 
_atualizacao () { 
     clear
###   200-mensagens do Menu Programas.
     M201="Menu de Programas"
     M202="Escolha o tipo de Atualizacao:"
     M203="1${NORM} - ${WHITE}Programa ou Pacote ON-Line    "
     M204="2${NORM} - ${WHITE}Programa ou Pacote em OFF-Line"
     M205="9${NORM} - ${RED}Menu Anterior        "
     printf "\n"
	_linha "="
	_mensagec "$RED" "$M201"
	_linha
	printf "\n"
	_mensagec "$PURPLE" "$M202"
	printf "\n"
	_mensagec "$GREEN" "$M203"
	printf "\n"
	_mensagec "$GREEN" "$M204"
	printf "\n"
	_mensagec "$GREEN" "$M205"
	printf "\n"
	_linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO
     case $OPCAO in
          1) _pacoteon ;;
          2) _pacoteoff ;;
          9) clear ; _principal ;;
          *) _principal ;;
     esac
}

_qualprograma () {
     clear
     _meiodatela
     #-Informe o nome do programa a ser atualizado:
     _mensagec "$RED" "$M59"
     _linha
     MB4="       Informe o programa em MAIUSCULO: "
     read -rp "${YELLOW}""${MB4}""${NORM}" prog
     NPROG=${prog}${class}
     NOMEPROG=${NPROG}".zip"
     OLDPROG=${prog}"-anterior.zip"
     _linha 
     while [[ "${prog}" =~ [^A-Z0-9] || -z "${prog}" ]]; do
     clear
     _meiodatela
     _mensagec "$RED" "$M60"
     _linha 
     _press
     NPROG=" "
     NOMEPROG=" "
     OLDPROG=" "
     _principal
     done
}

#-PROGRAMA E/OU ATUALIZACOES EM QUE O SERVIDOR NAO ESTA CONECTADO A REDE EXTERNA ------------------#
_servacessoff () {
if [ "${SERACESOFF}" != "" ]; then 
     SAOFF=${destino}${SERACESOFF}
     if [ -f "${SAOFF}/${NOMEPROG}" ]; then 
     mv -f -- "${SAOFF}/${NOMEPROG}" "." 
     else 
M42="A atualizacao,""$NOMEPROG"
M422=" nao foi encontrado no diretorio ""$SAOFF" 
     _linha 
     _mensagec "$RED" "$M42"
     _mensagec "$RED" "$M422"
     _linha 
     _press
     _principal       
     fi
fi
}
#-PROGRAMAS E/OU PACOTES---------------------------------------------------------------------------# 
_pacoteon () {
     _qualprograma
     #-Informe a senha do usuario do scp 
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     _run_scp
     _atupacote 
     _press 
     _principal
}

#_Pacotes em offline-------------------------------------------------------------------------------#
_pacoteoff () {
     #-O programa tem que estar no diretorio
     _qualprograma
     _linha
     _mensagec "$YELLOW" "$M09"
     _linha
     _read_sleep 1
     _servacessoff
     _atupacote
     _press
     _principal
}

_atupacote () {
if  [[ ! -f "$NOMEPROG" ]]; then
     clear
M42="Programa, ""$NOMEPROG"" nao encontrado no diretorio" 
     _linha 
     _mensagec "$RED" "$M42"
     _linha 
     _press 
     _principal
fi
if [[ -f "${OLDS}"/"$OLDPROG" ]]; then
     clear
     M43="Programa ""$OLDPROG"" encontrado no diretorio renomeando."
     _linha
     _mensagec "$CYAN" "$M43"
     _linha
     mv -f -- "${OLDS}""/""${OLDPROG}" "${OLDS}""/""$UMADATA""-""$OLDPROG" >> "$LOG_ATU"
fi

#-Descompactando o programa baixado----------------------------------------------------------------#
     "$cmd_unzip" -o "$NOMEPROG" >> "$LOG_ATU"
     _read_sleep 1
     clear

_mens_atualiza () {
     #..   BACKUP do programa sendo efetuado   ..
     _linha 
     _mensagec "$YELLOW" "$M24"
     _linha 
     _read_sleep 1
}
#-Verificando nome do arquivo com a extensao .class ou .int----------------------------------------#
     local pprog=""   
     if [ "$sistema" = "iscobol" ]; then 
          for pprog in *.class ; do
          if [ -f "${E_EXEC}"/"$pprog" ]; then
          "$cmd_zip" -m "$OLDPROG" "${E_EXEC}"/"$pprog"   
          _mens_atualiza
          fi
          mv -f -- "$pprog" "${E_EXEC}" >> "$LOG_ATU"
		done
     else 
          for pprog in *.int ; do
          if [ -f "${E_EXEC}"/"$pprog" ]; then
          "$cmd_zip" -m "$OLDPROG" "${E_EXEC}"/"$pprog"
          _mens_atualiza
          fi
          mv -f -- "$pprog" "${E_EXEC}" >> "$LOG_ATU"
          done
          _read_sleep 1
	fi
          if [[ -f "${prog}".TEL ]]; then
          for pprog in *.TEL ; do
               if [ -f "${T_TELAS}"/"$pprog" ]; then
               "$cmd_zip" -m "$OLDPROG" "${T_TELAS}"/"$pprog"
               _mens_atualiza
               fi
          mv -f -- "$pprog" "${T_TELAS}" >> "$LOG_ATU"
          done
          fi

#-Atualizando o novo programa.---------------------------------------------------------------------#
M07="Programa(s) a ser(em) atualizado(s) - ""$prog"
     _linha 
     _mensagec "$YELLOW" "$M26"
     _mensagec "$GREEN" "$M07"
     _linha 
     _read_sleep 

#-ALTERANDO A EXTENSAO DA ATUALIZACAO... De *.zip para *.bkp
     _linha 
     _mensagec "$YELLOW" "$M20"
     _mensagec "$YELLOW" "$M13"
     _linha 
     _read_sleep 

     for f in *"$NOMEPROG"; do
          mv -f -- "$f" "${f%.zip}.bkp"
     done
     _read_sleep 1
#-Atualizacao COMPLETA
     mv -f -- "$NPROG".bkp "${PROGS}"
     mv -f -- "$OLDPROG" "${OLDS}"
     _read_sleep 1
     _linha 
     _mensagec "$YELLOW" "$M17"
     _linha 

#-Escolha de multi programas-----------------------------------------------------------------------# 
#M37 Deseja informar mais algum programa para ser atualizado?
     _meiodatela
     read -rp "${YELLOW}""${M37}""${NORM}" -n1 CONT
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then
          _principal
     elif [[ "$CONT" =~ ^[Ss]$ ]]; then
          if [[ "$OPCAO" = 1 ]]; then
          _pacoteon
          else
          _pacoteoff
          fi
     _atupacote
     else
     _opinvalida	 
     _press
     _principal
     fi
_principal
}

#-Desatualizacao de programas----------------------------------------------------------------------# 
_desatualizado () { while true ; do
     clear
###-300-mensagens do Menu desatualizacao.
     M301="Menu de Desatualizacao"
     M302="Escolha o tipo de Desatualizacao:"
     M303="1${NORM} - Voltar programa Atualizado "
     M304="2${NORM} - Voltar antes da Biblioteca "
     M305="9${NORM} - ${RED}Menu Anterior     "
	printf "\n"
	_linha "="
	_mensagec "$RED" "$M301"
	_linha
	printf "\n"
	_mensagec "$PURPLE" "$M302"
	printf "\n"
	_mensagec "$GREEN" "$M303"
	printf "\n"
	_mensagec "$GREEN" "$M304"
	printf "\n"
	_mensagec "$GREEN" "$M305"
	printf "\n"
	_linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     case $OPCAO in
          1) _voltaprog ;;
          2) _voltabibli ;;
          9) clear ; _principal ;;
          *) _desatualizado ;;
     esac
     done
}

#-Procedimento da desatualizacao de programas------------------------------------------------------#
_apagadir () {
     rm -rf "${OLDS}""${destino}"
}     

_voltaprog () {
     clear
     _meiodatela
     _linha 
     _mensagec "$RED" "$M61"
     printf "\n"
     MA7="     Informe o nome do programa em maiusculo: "
     read -rp "${YELLOW}""${MA7}""${NORM}" prog
     NPROG=${prog}${class}
     NOMEPROG=$NPROG".zip"
     OLDPROG=${prog}"-anterior.zip"
     while [[ "${prog}" =~ [^A-Z0-9] || -z "${prog}" ]]; do
     _meiodatela
     _mensagec "$RED" "$M60"
     _linha 
     _press
     NPROG=" "
     NOMEPROG=" "
     OLDPROG=" "
     _principal
     done

     if [[ ! -r "${OLDS}"/"$OLDPROG" ]]; then
     clear
M43="Programa ""${prog}""-anterior.zip nao encontrado no diretorio."
     _linha 
     _mensagec "$RED" "$M43"
     _linha 
     _press
     _principal
     fi

M02="Voltando a versao anterior do programa ""${prog}"
     _linha 
     _mensagec "$YELLOW" "$M02"
     _linha 
     "$cmd_unzip" -o "${OLDS}"/"$OLDPROG" -d /  >> "$LOG_ATU"
     _read_sleep 2
     clear
#-VOLTA DE PROGRAMA CONCLUIDA
     _linha 
     _mensagec "$YELLOW" "$M03"
     _linha 
     _press
#-Escolha de multi programas-----------------------------------------------------------------------# 
#M37 Deseja informar mais algum programa para ser atualizado?
     _meiodatela
     read -rp "${YELLOW}""${M37}""${NORM}" -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then
          _principal
     elif [[ "$CONT" =~ ^[Ss]$ ]]; then
          if [[ "$OPCAO" = 1 ]]; then
          _voltaprog
          fi
     else
     _opinvalida	 
     _press
     _principal
     fi
_principal    

}

#-Procedimento da desatualizacao de programas antes da biblioteca----------------------------------# 
_voltabibli () {
     clear
     _meiodatela
     _mensagec "$RED" "$M62"
     _linha
     read -rp "${YELLOW}""${MA2}""${NORM}" VERSAO
     VVERSAO=$VERSAO".zip"
     INI="backup-"$VVERSAO
     while [[ "$VERSAO" = [0-9] || -z "$VERSAO" ]]; do 
     clear
     _meiodatela
     _mensagec "$RED" "$M56"
     _linha
     _press
     VVERSAO=""
     INI=""
     _desatualizado
     done

     if [[ ! -r "${OLDS}"/"${INI}" ]]; then
#-Backup da Biblioteca nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M46"
     _linha 
     _press
     _desatualizado
     fi
     MA3="Deseja volta todos os programas para antes da atualizacao? [N/s]:"
     printf "\n"
     read -rp "${YELLOW}""${MA3}""${NORM}" -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then
	_linha 
     _volta_progx
     elif [[ "$CONT" =~ ^[Ss]$ ]]; then
	_linha 
     _volta_geral
     else
	_opinvalida
     _press
     _desatualizado
     fi
}

#-VOLTA PROGRAMA ESPECIFICO------------------------------------------------------------------------#
_volta_progx () {
     MA4="       2- Informe o nome do programa em MAIUSCULO: "
     read -rp "${YELLOW}""${MA4}""${NORM}" Vprog

     while [[ "$Vprog" =~ [^A-Z0-9] || -z "$Vprog" ]]; do
     _meiodatela
     _mensagec "$RED" "$M71"
     _linha 
     _press
     _desatualizado
     done
     cd "${OLDS}"/ || exit
     "$cmd_unzip" -o "${INI}" -d "${OLDS}" >> "$LOG_ATU"
     _volta_progy
}

_volta_progz () {
     printf "\n"
     MA5="Deseja volta mais algum programa ? [N/s]:"
     read -rp "${YELLOW}""${MA5}""${NORM}" -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then
     _press
### limpando diretorio 
     local OLDS1="${OLDS}"/
          for pprog in {*.class,*.TEL,*.xml,*.int,*.png,*.jpg} ; do
          "$cmd_find" "${OLDS1}" -name "$pprog" -ctime +30 -exec rm -rf {} \; 
          done
     _apagadir
     _desatualizado
     fi

	local Vprog=" "
     MA6="       2- Informe o nome do programa em maiusculo: "
     if [[ "$CONT" =~ ^[Ss]$ ]]; then
     read -rp "${YELLOW}""${MA6}""${NORM}" Vprog
          if [[ "$Vprog" =~ [^A-Z0-9] || -z "$Vprog" ]]; then
          _meiodatela
          _mensagec "$RED" "$M71"
          _linha
          _press
          _desatualizado
          else
          _volta_progy
          fi
     _press
     _desatualizado
     fi
}

_volta_progy () {
     _read_sleep 1
     cd "${OLDS}" || exit 
     if [ "$sistema" = "iscobol" ]; then
          "$cmd_find" "${OLDS}" -name "$Vprog.xml" -exec mv {} "${X_XML}" \;
          "$cmd_find" "${OLDS}" -name "$Vprog.TEL" -exec mv {} "${T_TELAS}" \;
          "$cmd_find" "${OLDS}" -name "$Vprog*.class" -exec mv {} "${E_EXEC}" \;
     else
          "$cmd_find" "${OLDS}" -name "$Vprog.TEL" -exec mv {} "${T_TELAS}" \; 
          "$cmd_find" "${OLDS}" -name "$Vprog*.int" -exec mv {} "${E_EXEC}" \; 
     fi
#-VOLTA DE PROGRAMAS CONCLUIDA
     _linha 
     _mensagec "$YELLOW" "$M03"
     _linha 

M30="O(s) programa(s) ""$Vprog"" da ${NORM}${RED}""$VERSAO"
     _linha 
     _mensagec "$YELLOW" "$M25"
     _mensagec "$YELLOW" "$M30"
     _linha 
     _press
     _volta_progz
}

#-volta todos os programas da biblioteca-----------------------------------------------------------#
_volta_bibli () {
#-VOLTA DOS ARQUIVOS ANTERIORES...
     _read_sleep 1
     if [ "$sistema" = "iscobol" ]; then

     cd "${OLDS}" || exit
          for Ext in {*.class,*.png,*.jpg,*brw,*.,*.dll} ; do
          "$cmd_find" "${OLDS}" -type f \( -iname "$Ext" \) -exec mv "{}" "${E_EXEC}" \; >> "$LOG_ATU"
          done

          "$cmd_find" "${OLDS}" -type f \( -iname "*.TEL" \) -exec mv "{}" "${T_TELAS}" \; >> "$LOG_ATU"

          "$cmd_find" "${OLDS}" -type f \( -iname "*.xml" \) -exec mv "{}" "${X_XML}" \; >> "$LOG_ATU"

     cd "${TOOLS}"/ || exit
     clear
     else
     cd "${OLDS}"/ || exit
	"$cmd_find" "${OLDS}" -type f \( -iname "*.int" \) -exec mv "{}" "${E_EXEC}" \; >> "$LOG_ATU"

     "$cmd_find" "${OLDS}" -type f \( -iname "*.TEL" \) -exec mv "{}" "${T_TELAS}" \; >> "$LOG_ATU"

     cd "${TOOLS}"/ || exit
     clear
     _linha 
     _mensagec "$YELLOW" "$M03"
     _linha 

M30="O(s) programa(s) da ${NORM}${RED} ""$VERSAO"
     _linha 
     _mensagec "$YELLOW" "$M25"
     _mensagec "$YELLOW" "$M30"
     _linha 
     fi
     _press
     _apagadir 
     _principal
}

#-Volta total dos programas------------------------------------------------------------------------#
_volta_geral () { 
#-M58=Voltando todos os programas.
     _linha 
     _mensagec "$RED" "$M58"
     _linha 
M31="o programas da versao: ${NORM}${RED} ""$VERSAO"
     _linha 
     _mensagec "$YELLOW" "$M25"
     _mensagec "$YELLOW" "$M31"
     _linha 
     cd "${OLDS}"/ || exit
     "$cmd_unzip" -o "${INI}" -d "${OLDS}" >> "$LOG_ATU"
     cd "${TOOLS}" || exit
     clear
#-VOLTA DOS PROGRAMAS CONCLUIDA
     _linha 
     _mensagec "$YELLOW" "$M03"
     _linha 
     _volta_bibli
     _press
     _principal  
}

#-Rotina de Atualizacao Biblioteca-----------------------------------------------------------------#
_biblioteca () { 
     clear
     _meiodatela
     _mensagec "$RED" "$M55"
     _linha  
#-M57=Informe somente o numeral da versao :
     read -rp "${YELLOW}""${M57}""${NORM}" VERSAO 
     VVERSAO=$VERSAO".zip"
     INI="backup-"$VVERSAO
     if [ -z "$VERSAO" ]; then
#-M56=Versao a ser atualizada nao foi informada :
     printf "\n"
     _linha
     _mensagec "$RED" "$M56"
     _linha 
     _press
     VVERSAO=""
     _principal
     fi
     clear
###-400-mensagens do Menu Biblioteca.
     M401="Menu da Biblioteca"
     M402="Versao Informada - ${NORM}${YELLOW}${VERSAO}"
     M403="Escolha o local da Biblioteca:"
     M404="1${NORM} - Atualizacao do Transpc"
     M405="2${NORM} - Atualizacao do Savatu "
     M406="3${NORM} - Atualizacao OFF-Line  "
     M407="9${NORM} - ${RED}Menu Anterior"
	printf "\n"
	_linha "="
	_mensagec "$RED" "$M401"
	_linha 
	_mensagec "$RED" "$M402"
	_linha "="
	printf "\n"
	_mensagec "$PURPLE" "$M403"
	printf "\n"
	_mensagec "$GREEN" "$M404"
	printf "\n"
	_mensagec "$GREEN" "$M405"
	printf "\n"
	_mensagec "$GREEN" "$M406"
	printf "\n"
	_mensagec "$GREEN" "$M407"
	printf "\n"
	_linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     case $OPCAO in
          1) _transpc ;;
          2) _savatu ;;
          3) _salva ;;
          9) clear ; _principal ;;
          *) _biblioteca ;;
     esac
}

#-Processo de recepcao da biblioteca---------------------------------------------------------------#
_scp_biblioteca () {
	if [ "$sistema" = "iscobol" ]; then
     for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ; do
     _run_scp2
	done
     _salva
	else
     for atu in $SAVATU1 $SAVATU2 $SAVATU3 ; do	
	_run_scp2
	done 
	fi
     _salva
}

#-Atualizacao da pasta transpc---------------------------------------------------------------------#
_transpc () {
clear     
#-Informe a senha do usuario do scp
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     DESTINO2="${DESTINO2TRANSPC}"
     _scp_biblioteca
}

#-Atualizacao da pasta do savatu-------------------------------------------------------------------# 
_savatu () {
clear     
#-Informe a senha do usuario do scp 
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     if [ "$sistema" = "iscobol" ]; then 
     DESTINO2="${DESTINO2SAVATUISC}"
     _scp_biblioteca
	else 
	DESTINO2="${DESTINO2SAVATUMF}"
	_scp_biblioteca
	fi
}
# Biblioteca sava em servidor sem acesso remoto#
_servacessofff () {
atu=""    

if [ "${SERACESOFF}" != "" ]; then 
     SAOFF=${destino}${SERACESOFF}/
     M42="A atualizacao nao foi encontrado no diretorio ""$SAOFF"  
     _linha 
     _mensagec "$YELLOW" "$M21"
     _linha 
     if [ "$sistema" = "iscobol" ]; then
          for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ; do
          if  [[ ! -r $SAOFF$atu$VVERSAO ]]; then
          clear
          _linha 
          _mensagec "$RED" "$M42"
          _linha 
          _press
          clear
          _principal
          else
          mv -f -- "$SAOFF$atu$VVERSAO" "."
          fi
          done 
     _processo
#-Atualizacao nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M42"
     _linha 
     _press
     _principal
     else
          for atu in $SAVATU1 $SAVATU2 $SAVATU3 ; do
          if  [[ ! -r $SAOFF$atu$VVERSAO ]]; then
          clear
          #-Atualizacao nao encontrado no diretorio
          _linha 
          _mensagec "$RED" "$M42"
          _linha 
          _press
          clear
          _principal
          else
          mv -f -- "$SAOFF$atu$VVERSAO" "."
          fi
          done
          clear 
          _processo
M42="A atualizacao nao foi encontrado no diretorio ""$SAOFF" 
     _linha 
     _mensagec "$RED" "$M42"
     _linha 
     _press
     _principal       
     fi
fi
}

#-Atualizacao offline a biblioteca deve esta no diretorio------------------------------------------# 
_salva () {
     _servacessofff
M21="A atualizacao tem que esta no diretorio ""$TOOLS"
     _linha 
     _mensagec "$YELLOW" "$M21"
     _linha 
     if [ "$sistema" = "iscobol" ]; then
          for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ; do
          if  [[ ! -r $atu$VVERSAO ]]; then
          clear
          _linha 
          _mensagec "$RED" "$M48"
          _linha 
          _press
          clear
          _principal
          fi
          done 
     _processo
#-Atualizacao nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M48"
     _linha 
     _press
     _principal
     else
          for atu in $SAVATU1 $SAVATU2 $SAVATU3 ; do
               if  [[ ! -r $atu$VERSAO ]]; then
     clear 
#-Atualizacao nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M48"
     _linha 
     _press
     _principal
               fi
          done
	fi
     _processo
}

#-procedimento salvar os programas antes de atualizar----------------------------------------------# 
_processo () {

#-ZIPANDO OS ARQUIVOS ANTERIORES...
     _linha 
     _mensagec "$YELLOW" "$M01"
     _linha 
     
     _read_sleep 1
     if [ "$sistema" = "iscobol" ]; then
          cd "${E_EXEC}"/ || exit
          "$cmd_find" "${E_EXEC}"/ -type f \( -iname "*.class" -o -iname "*.jpg" -o -iname "*.png" -o -iname "*.brw" -o -iname "*." -o -iname "*.dll" \) -exec zip -r "${TOOLS}"/"${INI}" "{}" +;
          cd "${T_TELAS}"/ || exit
          "$cmd_find" "${T_TELAS}"/ -type f \( -iname "*.TEL" \) -exec zip -r "${TOOLS}"/"${INI}" "{}" +;
          cd "${X_XML}"/ || exit
          "$cmd_find" "${X_XML}"/ -type f \( -iname "*.xml" \) -exec zip -r "${TOOLS}"/"${INI}" "{}" +;
          cd "${TOOLS}"/ || exit
          clear
     else
          cd "${E_EXEC}"/ || exit
          "$cmd_find" "${E_EXEC}"/ -type f \( -iname "*.int" \) -exec zip -r "${TOOLS}"/"${INI}" "{}" +;
          cd "${T_TELAS}"/ || exit
          "$cmd_find" "${T_TELAS}"/ -type f \( -iname "*.TEL" \) -exec zip -r "${TOOLS}"/"${INI}" "{}" +;
     fi 

#-..BACKUP COMPLETO..
     _linha 
     _mensagec "$YELLOW" "$M27"
     _linha 
     _read_sleep 1

     if [[ ! -r "${TOOLS}"/"${INI}" ]]; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M45"
     _linha 

#-Procedimento caso nao exista o diretorio a ser atualizado----------------------------------------# 
     _read_sleep 2    
     _meiodatela
     read -rp "${YELLOW}""${M38}""${NORM}" -n1 CONT 
     printf "\n\n"
          if [[ "$CONT" =~ ^[Nn]$ ]]; then
          _principal
          elif [[ "$CONT" =~ ^[Ss]$ ]] || [[ "$CONT" == "" ]]; then
          _meiodatela
          _mensagec "$YELLOW" "$M39"
          else
          _opinvalida
          _principal
          fi 
     fi

#-Procedimento da Atualizacao de Programas---------------------------------------------------------# 
     cd "${TOOLS}" || exit
#-ATUALIZANDO OS PROGRAMAS...
     _linha 
     _mensagec "$YELLOW" "$M19"
     _linha 
     for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ; do
          printf "${GREEN}"" Atualizado ""$atu""$VVERSAO""${NORM}""%*s\n" || printf "%*s""$M48"
          "$cmd_unzip" -o "$atu""$VVERSAO" -d "${destino}" >> "$LOG_ATU"
          _read_sleep 2
          clear
     done
#-Atualizacao COMPLETA
     _linha 
     _mensagec "$YELLOW" "$M17"
     _linha 
     ####
     if [[ -r "${INI}" ]]; then
          mv -f -- "${INI}" "${OLDS}"
     else
MX3="Backup nao encontrado no diretorio."
     _linha 
     _mensagec "$RED" "$MX3"
     _linha
     ###
     sleep 30s
     fi
     for f in *_"$VERSAO".zip; do
          mv -f -- "$f" "${f%.zip}.bkp"
     done
          mv -f -- *_"$VERSAO".bkp "$BACKUP"
#-ALTERANDO A EXTENSAO DA ATUALIZACAO.../De *.zip para *.bkp/
#-Versao atualizada - $VERSAO$
M40="Versao atualizada - ""$VERSAO"
_linha 
_mensagec "$YELLOW" "$M20"
_mensagec "$YELLOW" "$M13"
_mensagec "$RED" "$M40"
_linha 
_press
_principal
}

#-Mostrar a versao do iscobol que esta sendo usada.------------------------------------------------# 
_iscobol () {
     if [ "$sistema" = "iscobol" ]; then
     clear    
	_linha 
          "$SAVISC""$ISCCLIENT" -v
     _linha 
     printf "\n\n"
     else
#-Sistema nao e IsCOBOL
     _linha 
     _mensagec "$YELLOW" "$M05"
     _linha 
     fi
_press
_principal
}

#-Mostrar a versao do Linux que esta sendo usada.--------------------------------------------------# 
_linux () {
     clear
     LX="Vamos descobrir qual S.O. / Distro voce esta executando"
     LM="A partir de algumas informacoes basicas o seu sistema, parece estar executando:"
     printf "\n\n"
     _mensagec "$GREEN" "$LX"
     _linha 
     printf "\n\n"
     _mensagec "$YELLOW" "$LM"
     _linha 
# Checando se conecta com a internet ou nao 
ping -c 1 google.com &> /dev/null && printf "${GREEN}"" Internet:""${NORM}""Conectada""%*s\n"||printf "${GREEN}"" Internet:""${NORM}""Desconectada""%*s\n"

# Checando tipo de OS
os=$(uname -o)
printf "${GREEN}""Sistema Operacional :""${NORM}""$os""%*s\n"

# Checando  OS Versao e nome 
cat < '/etc/os-release' | grep 'NAME\|VERSION' | grep -v 'VERSION_ID' | grep -v 'PRETTY_NAME' > "$LOG_TMP""osrelease"
printf "${GREEN}""OS Nome :""${NORM}""%*s\n" && cat < "$LOG_TMP""osrelease" | grep -v "VERSION" | cut -f2 -d\"
printf "${GREEN}""OS Versao :""${NORM}""%*s\n" && cat < "$LOG_TMP""osrelease" | grep -v "NAME" | cut -f2 -d\"
printf "\n"
# Checando hostname
nameservers=$(hostname)
printf "${GREEN}""Nome do Servidor :""${NORM}""$nameservers""%*s\n"
printf "\n"
# Checando Interno IP
internalip=$(ip route | grep default | awk '{print $3}')
printf "${GREEN}""IP Interno :""${NORM}""$internalip""%*s\n"
printf "\n"
# Checando Externo IP
externalip=$(curl -s ipecho.net/plain;echo)
printf "${GREEN}""IP Externo :""${NORM}""$externalip""%*s\n"

_linha 
_press 5
clear
_linha 
# Checando os usuarios logados 
_run_who () {
     "$cmd_who">"$LOG_TMP"who 
}
_run_who
printf "${GREEN}""Usuario Logado :""${NORM}""$cmd_who""%*s\n" && cat "$LOG_TMP"who 
printf "\n"
# Checando uso de memoria RAM e SWAP
free | grep -v + > "$LOG_TMP"ramcache
printf "${GREEN}""Uso de Memoria Ram :""${NORM}""%*s\n"
cat < "$LOG_TMP""ramcache" | grep -v "Swap"
printf "${GREEN}""Uso de Swap :""${NORM}""%*s\n"
cat < "$LOG_TMP""ramcache" | grep -v "Mem"
printf "\n"
# Checando uso de disco
df -h| grep 'Filesystem\|/dev/sda*' > "$LOG_TMP"diskusage
printf "${GREEN}""Espaco em Disco :""${NORM}""%*s\n" 
cat < "$LOG_TMP""diskusage"
printf "\n"
# Checando o Sistema Uptime
tecuptime=$(uptime | awk '{print $3,$4}' | cut -f1 -d,)
printf "${GREEN}""Sistema em uso Dias/(HH:MM) : ""${NORM}""$tecuptime""%*s\n"

# Unset Variables
unset tecreset os architecture kernelrelease internalip externalip nameserver loadaverage

# Removendo temporarios arquivos 
rm -f "$LOG_TMP""osrelease" "$LOG_TMP""who" "$LOG_TMP""ramcache" "$LOG_TMP""diskusage"     
_linha 
_press
_principal
}

_ferramentas () {
tput clear
printf "\n"
###-500-mensagens do Menu Ferramentas.	
     M501="Menu das Ferramentas"
     M503="1${NORM} - Temporarios                      "
     M504="2${NORM} - Recuperar Arquivos               "
     M505="3${NORM} - Rotina de Backup                 "
     M506="4${NORM} - Envia e Recebe Arquivos          "
     M507="5${NORM} - Expurgador de Arquivos           "
     M509="8${NORM} - Update                           "	
     M510="9${NORM} - ${RED}Menu Anterior           "
     _linha "="
     _mensagec "$RED" "$M501"
     _linha 
     printf "\n"
     _mensagec "$PURPLE" "$M103"
     printf "\n"
if [[ "$BANCO" = "s" ]]; then
     _mensagec "$GREEN" "$M503"
     printf "\n"
     _mensagec "$GREEN" "$M506"
     printf "\n"
     _mensagec "$GREEN" "$M507"
     printf "\n"
     _mensagec "$GREEN" "$M509"
     printf "\n"
     _mensagec "$GREEN" "$M510"
	printf "\n"
	_linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAOB
case $OPCAOB in
          1) _temps        ;;
          4) _envrecarq    ;;
          5) _expurgador   ;;          
          8) _update       ;;
          9) clear ; _principal ;;
          *) _ferramentas ;;
esac
else
	_mensagec "$GREEN" "$M503"
     printf "\n"
	_mensagec "$GREEN" "$M504"
     printf "\n"
     _mensagec "$GREEN" "$M505"
     printf "\n"
	_mensagec "$GREEN" "$M506"
     printf "\n"
     _mensagec "$GREEN" "$M507"
     printf "\n"
	_mensagec "$GREEN" "$M509"
	printf "\n"
fi
     _mensagec "$GREEN" "$M510"
     printf "\n"
     _linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO
     case $OPCAO in
          1) _temps        ;;
          2) _rebuild      ;;
          3) _menubackup   ;;
          4) _envrecarq    ;;
          5) _expurgador   ;;
          8) _update       ;;
          9) clear ; _principal ;;
          *) _ferramentas ;;
     esac
}

_varrendo_arquivo () {
"$cmd_find" "$DIRB" -type f \( -iname "${line}" \) -exec zip -m "$BACKUP""/""$TEMPS-$UMADATA" "{}" +; 
} >> "$LOG_LIMPA"

_limpando () {
clear
     TEMPS="Temps"
     line_array=""
     mapfile -t line_array < "$arqs"
     for line in "${line_array[@]}"; do
     printf "${GREEN}""${line}""${NORM}%s\n"
     _varrendo_arquivo
     done 
M11="Movendo arquivos Temporarios do diretorio = ""$DIRB"
_linha 
_mensagec "$YELLOW" "$M11"
_linha
}

_temps () {
     clear
     M900="Menu de Limpeza"
	M901="1${NORM} - Limpeza dos Arquivos Temporarios"
	M902="2${NORM} - Adicionar Arquivos no ATUALIZAT "
     printf "\n"
	_linha "="
	_mensagec "$RED" "$M900"
	_linha 
	printf "\n"
	_mensagec "$PURPLE" "$M103"
	printf "\n"
	_mensagec "$GREEN" "$M901"
	printf "\n"
	_mensagec "$GREEN" "$M902"
	printf "\n"
     _linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     case $OPCAO in
          1)  _limpeza ;;
          2)  _addlixo ;;
          *) _ferramentas ;;
     esac    
}

_limpeza () {
cd "${TOOLS}"/ || exit
#-Le a lista "atualizat" que contem os arquivos a serem excluidas da base do sistema---------------# 
#-TESTE Arquivos ----------------------------------------------------------------------------------#
[[ ! -e "atualizat" ]] && printf "ERRO. Arquivo atualizat, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizat" ]] && printf "ERRO. Arquivo atualizat, Sem acesso de leitura.\n" && exit 1
#--------------------------------------------------------------------------------------------------#
#-Rotina para excluir arquivo temporarios----------------------------------------------------------#
local arqs=""
arqs="atualizat"
DAYS=$(find "$BACKUP" -type f -name "Temps*" -mtime 10 -exec rm -rf {} \;)
     if [[ "$DAYS" ]]; then
     M63="Existe um backup antigo sera excluido do Diretorio ""$DIRDEST"
     _meiodatela
     _messagec RED "$M63"
     fi 
     for i in $base $base2 $base3 ; do
     DIRB="${destino}""${i}""/"
     _limpando
     _press
     done 
_ferramentas
}

_addlixo() {
clear
M8A="Informe o nome do arquivo a ser adicionado ao atualizat"
     _meiodatela
     _mensagec "$CYAN" "$M8A" 
     _linha  
     M8B="         Qual o arquivo ->: "
     read -rp "${YELLOW}""${M8B}""${NORM}" ADDARQ
     _linha
          if [[ "$ADDARQ" = "" ]]; then
          _meiodatela
          _mensagec "$RED" "$M66"
          _linha
          cd "${TOOLS}"/ || exit
          _press
          _temps
          fi
          local ARQUIVO="$ADDARQ"
          echo "$ARQUIVO" >> atualizat        
_temps
}     

#-Rotina de recuperar arquivos---------------------------------------------------------------------#
_rebuild () { 
     rm -rf "${TOOLS}""/""atualizaj2"    
     clear
###-600-mensagens do Menu Rebuild.
     M601="Menu de Recuperacao de Arquivo(s)."
	M603="1${NORM} - Um arquivo ou Todos   "
	M604="2${NORM} - Arquivos Principais   "
     M605="9${NORM} - ${RED}Menu Anterior"
	printf "\n"
	_linha "="
	_mensagec "$RED" "$M601"
	_linha 
	printf "\n"
	_mensagec "$PURPLE" "$M103"
	printf "\n"
	_mensagec "$GREEN" "$M603"
	printf "\n"
	_mensagec "$GREEN" "$M604"
	printf "\n"
     _mensagec "$GREEN" "$M605"
     printf "\n"
     _linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     case $OPCAO in
          1) _rebuild1 ;;
          2) _rebuildlista ;;
          9) clear ; _ferramentas ;;
          *) _ferramentas ;;
     esac
}

_escolhe_base () {
     clear
###-600-mensagens do Menu Rebuild.
     M900="Escolha a Base"
	M901="1${NORM} - Base em ${destino}${base}"
	M902="2${NORM} - Base em ${destino}${base2}"
     if [ ! "${base3}" ]; then
          M903=""
     else
          M903="3${NORM} - Base em ${destino}${base3}"
	fi
     printf "\n"
	_linha "="
	_mensagec "$RED" "$M900"
	_linha 
	printf "\n"
	_mensagec "$PURPLE" "$M103"
	printf "\n"
	_mensagec "$GREEN" "$M901"
	printf "\n"
	_mensagec "$GREEN" "$M902"
	printf "\n"
     _mensagec "$GREEN" "$M903"
     printf "\n"
     _linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     if [ ! "$base3" ]; then
     case $OPCAO in
          1)  _dbase1 ;;
          2)  _dbase2 ;;
          *) _ferramentas ;;
     esac    
     else
     case $OPCAO in
          1)  _dbase1 ;;
          2)  _dbase2 ;;
          3)  _dbase3 ;;
          *) _ferramentas ;;
     esac
     fi    
}

_dbase1 () {
     BASE1="${destino}""${base}"
}

_dbase2 () {
     BASE1="${destino}""${base2}"  
}

_dbase3 () {
     BASE1="${destino}""${base3}" 
}

#-Rotina de recuperar arquivos especifico ou todos se deixar em branco-----------------------------#
##- Rotina para rodar o jutil
jut="$SAVISC""$JUTIL"
_jutill () {
if [[ -s "$linee" ]]; then      
     if [[ -e "$linee" ]]; then 
     $jut -rebuild "$linee" -a -f
     _linha
     fi
fi
} 

_rebuild1 () {
if [ "$base2" ]; then
     _escolhe_base
fi
clear
if [ "$sistema" = "iscobol" ]; then          
     _meiodatela
     _mensagec "$CYAN" "$M64" 
     _linha  
     declare -u PEDARQ
     MA8="         Informe o nome maiusculo: "
     read -rp "${YELLOW}""${MA8}""${NORM}" PEDARQ

     _linha
     if [[ -z "$PEDARQ" ]]; then
     _meiodatela
#-M65
     _mensagec "$RED" "$M65"
     _linha 
          for linee in "$BASE1"/{*.ARQ.dat,*.DAT.dat,*.LOG.dat,*.PAN.dat} ; do
          _jutill
          done

     else
          while [[ "$PEDARQ" =~ [^A-Z0-9] ]]; do
          _meiodatela
          _mensagec "$RED" "$M66"
          cd "${TOOLS}"/ || exit
          _press
          _ferramentas
          done
          local ARQUIVO="$PEDARQ.???.dat"
          for line in $ARQUIVO; do
          $jut -rebuild "${BASE1}""/""$line" -a -f
          _linha  
          done
     fi
#-Arquivo(s) recuperado(s)...
     _linha 
     _mensagec "$YELLOW" "$M18"
     _linha 

cd "${TOOLS}"/ || exit
else
     _meiodatela
     M996="Recuperacao em desenvolvimento :"
     _mensagec "$RED" "$M996"
fi
_press
_rebuild
}

#-Rotina de recuperar arquivos de uma Lista os arquivos estao cadatrados em "atualizaj"------------#
cd "${TOOLS}"/ || exit
#-Arquivos para rebuild ---------------------------------------------------------------------------#
[[ ! -e "atualizaj" ]] && printf "ERRO. Arquivo atualizaj, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizaj" ]] && printf "ERRO. Arquivo atualizaj, Sem acesso de leitura.\n" && exit 1
#--------------------------------------------------------------------------------------------------#
_rebuildlista () {
clear
if [ "${base2}" ]; then
     _escolhe_base
fi
if [ "$sistema" = "iscobol" ]; then
cd "${BASE1}"/ || exit
#-Rotina para gerar o arquivos atualizaj2 adicionando os arquivos abaixo---------------------------#
ls ATE202*.*.dat > "${TOOLS}""/""atualizaj2"
ls NFE?202*.*.dat >> "${TOOLS}""/""atualizaj2"
sleep 1
cd "-" || exit
#-Arquivos Ates e NFEs ----------------------------------------------------------------------------#
[[ ! -e "atualizaj2" ]] && printf "ERRO. Arquivo atualizaj, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizaj2" ]] && printf "ERRO. Arquivo atualizaj, Sem acesso de leitura.\n" && exit 1
#--------------------------------------------------------------------------------------------------#
# Trabalhando lista do arquivo "atualizaj" #
while read -r line; do
linee="${BASE1}""/""$line"
_jutill   
done < atualizaj
# Trabalhando lista do arquivo "atualizaj2" #
while read -r line; do
linee="${BASE1}""/""$line"
_jutill   
done < atualizaj2
#-Lista de Arquivo(s) recuperado(s)... 
     _linha 
     _mensagec "$YELLOW" "$M12"
     _linha 
#     _press
else
_meiodatela
#M996="Recuperacao para este sistema nao disponivel:"
_mensagec "$RED" "$M996"
fi
_press
_rebuild
}

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
	_mensagec "$RED" "$M700"
	_linha 
	printf "\n"
	_mensagec "$PURPLE" "$M103"
	printf "\n"
	_mensagec "$GREEN" "$M702"
	printf "\n"
	_mensagec "$GREEN" "$M703"
	printf "\n"
	_mensagec "$GREEN" "$M704"
     printf "\n"
	_mensagec "$GREEN" "$M705"
     printf "\n"       
	_linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     case $OPCAO in
          1) _backup       ;;
          2) _unbackup     ;;
          3) _backupavulso ;;
          9) clear ; _ferramentas ;;
          *) _ferramentas ;;
     esac
     done
}

#-Rotina de backup com opcao de envio da a SAV-----------------------------------------------------#
_backup () {
clear
if [ "${base2}" ]; then
     _escolhe_base
fi
     if [ ! -d "${BACKUP}" ]; then
M23=".. Criando o diretorio do backup em ${BACKUP}.."
     _linha 
     _mensagec "$YELLOW" "$M23"
     _linha 
     mkdir -p "$BACKUP"
     fi
DAYS2=$(find "${BACKUP}" -ctime -2 -name "$EMPRESA"\*zip)
     cd "${BASE1}" || exit
if [[ "$DAYS2" ]]; then

M62="Ja existe um backup em ""${BACKUP}"" nos ultimos dias."
     printf "\n\n"
     _linha 
     _mensagec "$CYAN" "$M62"
     _linha   
     printf "\n" 
MB1="          Deseja continuar ? [N/s]: "     
     read -rp "${YELLOW}""${MB1}""${NORM}" -n1 CONT 
     printf "\n"
          if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then
#-Backup Abortado!
          _linha 
          _mensagec "$RED" "$M47"
          _linha         
          _read_sleep 3
          _ferramentas 
          elif [[ "$CONT" =~ ^[Ss]$ ]]; then
#-Sera criado mais um backup para o periodo.
          _linha 
          _mensagec "$YELLOW" "$M06"
          _linha 
          else
          _opinvalida
          _ferramentas
          fi
fi
#-Criando Backup..
     _linha 
     _mensagec "$YELLOW" "$M14"
     _linha 
local ARQ=""
ARQ="$EMPRESA"_$(date +%Y%m%d%H%M).zip

#-Rotina do progresso de execução.-----------------------------------------------------------------#
_progresso () { 
     echo -n "${YELLOW}"" Favor aguardar [""${NORM}"
     while true ; do
     echo -n "${GREEN}""=""${NORM}"
     _read_sleep 5
     done
}

_dobackup () {
     #-Backup 
     "$cmd_zip" "$BACKUP"/"$ARQ" ./*.* -x ./*.zip ./*.tar ./*tar.gz >/dev/null 2>&1
}

#-Inicia em background-----------------------------------------------------------------------------#
_progresso &
#-Save o progresso () PID
#-Você precisa usar o PID para matar a função
MYSELF=$!
#-Start backup
#-Transfere o controle para o dobackup()
_dobackup

#- Matar progresso
kill $MYSELF >/dev/null 2>&1

     echo "${YELLOW}""]pronto""${NORM}"
     printf "\n"

#-O backup de nome \"""$ARQ""\" foi criado em $BACKUP$}
M10="O backup de nome :"$ARQ
M32="foi criado em "$BACKUP
     _linha 
     _mensagec "$YELLOW" "$M10"
     _mensagec "$YELLOW" "$M32"
     _linha 
     printf "\n"
#-Backup Concluido!
     _linha 
     _mensagec "$YELLOW" "$M16"
     _linha 
     read -rp "${YELLOW}""${M40}""${NORM}" -n1 CONT 
     printf "\n\n"
if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then    
     _ferramentas
elif [[ "$CONT" =~ ^[Ss]$ ]]; then
     if [ "${SERACESOFF}" != "" ]; then 
          SAOFF=${destino}${SERACESOFF}
          mv -f -- "$BACKUP"/"$VBACKUP" "$SAOFF"
 MA11="Backup enviado para o diretorio:"   
     _linha
     _mensagec "$YELLOW" "$MA11"
     _linha 
     _press    
     _ferramentas 
     fi
     if [ "$ENVIABACK" != "" ]; then
          ENVBASE="$ENVIABACK"
     else
     _meiodatela
     _mensagec "$RED" "$M68"
     read -rp "${YELLOW}""${M41}""${NORM}" ENVBASE
     while [[ "$ENVBASE" =~ [0-9] || -z "$ENVBASE" ]] ; do
     _meiodatela
#-M69 Voce nao informou o nome do diretorio a enviado, saindo...   
     _mensagec "$RED" "$M69"
     _press    
     _ferramentas 
     done
     fi
#-Informe a senha do usuario do scp
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     "$cmd_scp" -r -P "$PORTA" "$BACKUP/$ARQ" "$USUARIO"@"$IPSERVER":/"$ENVBASE" 
M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
     _linha 
     _mensagec "$YELLOW" "$M15"
     _linha 
     _read_sleep 3 
     _ferramentas
else
     _opinvalida
     _ferramentas 
fi
} 

#-Enviar backup avulso-----------------------------------------------------------------------------#
_backupavulso () {
     clear 
     ls "$BACKUP"/"$EMPRESA"_*.zip
#-Informe de qual o Backup que deseja enviar.
     _linha 
     _mensagec "$RED" "$M52"
     _linha      
     read -rp "${YELLOW}""${M42}""${NORM}" VBACKAV
     local VBACKUP="$EMPRESA"_"$VBACKAV".zip
     while [[ -f "$VBACKUP" ]] ; do 
     clear
     _meiodatela
     _mensagec "$RED" "$M70"
     _press
     _ferramentas
     done
     if [[ ! -r "$BACKUP"/"$VBACKUP" ]]; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M45"
     _linha     
     _press
     _ferramentas
     fi
     printf "\n"
     clear
     _meiodatela
MA1="O backup \"""$VBACKUP""\""     
     _linha
     _mensagec "$YELLOW" "$MA1"
     _linha 

if [[ "${SERACESOFF}" != "" ]]; then 
          SAOFF=${destino}${SERACESOFF}
          mv -f -- "$BACKUP"/"$VBACKUP" "$SAOFF"
MA11="Backup enviado para o diretorio:"   
     _linha
     _mensagec "$YELLOW" "$MA11"
     _linha 
          _press    
     _ferramentas 
fi

     _linha 
     read -rp "${YELLOW}""${M40}""${NORM}" -n1 CONT 
     printf "\n\n"

if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then    
     _ferramentas
elif [[ "$CONT" =~ ^[Ss]$ ]]; then
     if [[ "$ENVIABACK" != "" ]]; then
     ENVBASE="$ENVIABACK"
     else
     _meiodatela
     _mensagec "$RED" "$M68"
     _linha
     read -rp "${YELLOW}""${M41}""${NORM}" ENVBASE
     while [[ "$ENVBASE" =~ [0-9] || -f "$ENVBASE" ]] ; do
     _meiodatela
     _mensagec "$RED" "$M69"
     _press    
     _ferramentas 
     done
     fi
#-Informe a senha do usuario do scp
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     "$cmd_scp" -r -P "$PORTA" "$BACKUP""/""$VBACKUP" "$USUARIO"@"$IPSERVER":/"$ENVBASE" 
M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
     _linha 
     _mensagec "$YELLOW" "$M15"
     _linha 
     _read_sleep 3 
else
     _opinvalida
     _ferramentas   
fi	 
}   

#-VOLTA BACKUP TOTAL OU PARCIAL--------------------------------------------------------------------#
_unbackup () {
clear
if [ "${base2}" ]; then
     _escolhe_base
fi

local DIRBACK="$BACKUP"/dados

     if [ ! -d "${DIRBACK}" ]; then
M22=".. Criando o diretorio temp do backup em ${DIRBACK}.." 
     _linha 
     _mensagec "$YELLOW" "$M22"
     _linha 
     mkdir -p "$DIRBACK"
     fi
     ls -s "$BACKUP""/""$EMPRESA"_*.zip
     _linha 
     _mensagec "$RED" "$M53"
     _linha
     MA9="         1- Informe somente a data do BACKUP: " 
     read -rp "${YELLOW}""${MA9}""${NORM}" VBACK
     local VBACKUP="$EMPRESA"_"$VBACK"".zip"
     while [[ -f "$VBACKUP" ]]; do 
     clear
     _meiodatela
     _mensagec "$RED" "$M70"
     _press
     _menubackup
     done
     if [[ ! -r "$BACKUP"/"$VBACKUP" ]]; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec "$RED" "$M45"
     _linha 
     _press
     _menubackup
     fi
     printf "\n" 
#-"Deseja volta todos os ARQUIVOS do Backup ? [N/s]:"
     _linha 
     read -rp "${YELLOW}""${M35}""${NORM}" -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]]; then
     MB1="       2- Informe o somente nome do arquivo em maiusculo: "
     read -rp "${YELLOW}""${MB1}""${NORM}" VARQUIVO
     while [[ "$VARQUIVO" =~ [^A-Z0-9] || -z "$VARQUIVO" ]] ; do
     _mensagec "$RED" "$M71"
     _linha 
     _press
     _menubackup
     done

#-Voltando Backup anterior  ...-#
M34="O arquivo ""$VARQUIVO"
     _linha 
     _mensagec "$YELLOW" "$M33"
     _mensagec "$YELLOW" "$M34"
     _linha 
     cd "$DIRBACK" || exit
     "$cmd_unzip" -o "$BACKUP""/""$VBACKUP" "$VARQUIVO*.*" >> "$LOG_ATU"
     _read_sleep 1
     if ls -s "$VARQUIVO"*.* >erro /dev/null 2>&1 ; then
#-Arquivo encontrado no diretorio
     _linha 
     _mensagec "$YELLOW" "$M28"
     _linha 
     else
#-Arquivo nao encontrado no diretorio
     _linha 
     _mensagec "$YELLOW" "$M49"
     _linha 
     _press 
     _menubackup  
     fi
     mv -f "$VARQUIVO"*.* "${BASE1}" >> "$LOG_ATU" 
     cd "${TOOLS}"/ || exit
     clear
#-VOLTA DO ARQUIVO CONCLUIDA
     _linha 
     _mensagec "$YELLOW" "$M04"
     _linha 
     _press
     _menubackup
     elif [[ "$CONT" =~ ^[Ss]$ ]]; then

#---- Voltando Backup anterior  ... ----
M34="O arquivo ""$VARQUIVO"
     _linha 
     _mensagec "$YELLOW" "$M33"
     _mensagec "$YELLOW" "$M34"
     _linha 
     cd "$DIRBACK" || exit
     "$cmd_unzip" -o "$BACKUP""/""$VBACKUP" >> "$LOG_ATU"
     mv -f -- *.* "${BASE1}" >> "$LOG_ATU"
     cd "${TOOLS}"/ || exit
     clear
#-VOLTA DOS ARQUIVOS CONCLUIDA
     _linha 
     _mensagec "$YELLOW" "$M04"
     _linha 
     _press
     else
	_opinvalida
     fi
_ferramentas
}

#-Envia e receber arquivos-------------------------------------------------------------------------#
_envrecarq () { 
     clear
###-800-mensagens do Menu Envio e Retorno.
     M800="Menu de Enviar e Receber Arquivo(s)."
     M802="1${NORM} - Enviar arquivo(s)      "
     M803="2${NORM} - Receber arquivo(s)     "
     M806="9${NORM} - ${RED}Menu Anterior "
	printf "\n"
	_linha "="
	_mensagec "$RED" "$M800"
	_linha 
	printf "\n"
	_mensagec "$PURPLE" "$M103"
	printf "\n"
	_mensagec "$GREEN" "$M802"
	printf "\n"
	_mensagec "$GREEN" "$M803"
	printf "\n"
	_mensagec "$GREEN" "$M806"
     printf "\n"       
	_linha "="
     read -rp "${YELLOW}""${M110}""${NORM}" OPCAO	
     case $OPCAO in
          1) _envia_avulso    ;;
          2) _recebe_avulso   ;;
          9) clear ; _ferramentas ;;
          *) _ferramentas ;;
     esac
}

###---envia_avulso-------------
_envia_avulso () {
     clear
     printf "\n\n\n"
### Pedir diretorio origem do arquivo    
     _linha 
M991="1- Origem: Informe em que diretorio esta o arquivo a ser enviado :"   
     _mensagec "$YELLOW" "$M991"  
     read -rp "${YELLOW}"" -> ""${NORM}" DIRENVIA
     _linha 
     local VERDIR=$DIRENVIA
     if [[ -d "${VERDIR}" ]]; then
     printf "\n"
     else
     clear
     _meiodatela
M995="Diretorio nao foi encontrado no servidor"
     _linha 
     _mensagec "$RED" "$M995"  
     _linha 
     _press
     _envrecarq
     fi
     if [[ -z "${DIRENVIA}" ]]; then # testa variavel vazia
     local DIRENVIA=$ENVIA
          if ls -s "$DIRENVIA"/*.* ; then
#-Arquivo encontrado no diretorio
          printf "\n"
          _linha
          _mensagec "$YELLOW" "$M28"
          _linha
          else
M49="Arquivo nao encontrado no diretorio"
     _linha 
     _mensagec "$YELLOW" "$M49"  
     _linha 
#      _press 
     _ferramentas  
          fi
     fi
     _linha 
     _mensagec "$CYAN" "$M72" #Informe o arquivo(s) que deseja enviar.
     _linha 
     MB3="2- Informe nome do ARQUIVO: -> "     
     local EENVIA=" "
     read -rp "${YELLOW}""${MB3}""${NORM}" EENVIA
     if [[ -z "${EENVIA}" ]]; then 
#   clear
     _meiodatela
     _mensagec "$RED" "$M74"
     _linha
     _press
     _envrecarq
     fi
     if [[ ! -e "$DIRENVIA""/""$EENVIA" ]]; then
     _linha
M49="$EENVIA Arquivo nao encontrado no diretorio"
     _linha 
     _mensagec "$YELLOW" "$M49"  
     _linha 
     _press 
     _envrecarq  
     fi
     printf "\n"
     _linha 
M992="3- Destino: Informe para qual diretorio no servidor:"   
     _mensagec "$YELLOW" "$M992"  
     read -rp "${YELLOW}"" -> ""${NORM}" ENVBASE
     _linha 
     if [[ -z "${ENVBASE}" ]]; then
     _meiodatela
#M69  
     _mensagec "$RED" "$M69"
     _press    
     _envrecarq 
     fi
#-Informe a senha do usuario do scp
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     "$cmd_scp" -r -P "$PORTA" "$DIRENVIA"/"$EENVIA" "$USUARIO"@"$IPSERVER":"$ENVBASE" 
M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
     _linha 
     _mensagec "$YELLOW" "$M15"
     _linha 
     _read_sleep 3
     _envrecarq
}

##---recebe_avulso-------------------------------------
_recebe_avulso () {
     clear
     _linha 
M993="1- Origem: Informe em qual diretorio esta o arquivo a ser RECEBIDO :"   
     _mensagec "$YELLOW" "$M993"  
     read -rp "${YELLOW}"" -> ""${NORM}" RECBASE
     _linha 
     _linha 
     _mensagec "$RED" "$M73"
     _linha
     MB2="    2- Informe nome do ARQUIVO: "      
     read -rp "${YELLOW}""${MB2}""${NORM}" RRECEBE
     if [[ -z "${RRECEBE}" ]]; then 
     _meiodatela
     _mensagec "$RED" "$M74"
     _linha
     _press
     _envrecarq
     fi
     _linha 
M994="3- Destino:Informe diretorio do servidor que vai receber arquivo: " 
     _mensagec "$YELLOW" "$M994"  
     read -rp "${YELLOW}"" -> ""${NORM}" EDESTINO
     if [[ -z "${EDESTINO}" ]]; then # testa variavel vazia
     local EDESTINO=$RECEBE
     fi
     _linha 
     local VERDIR="$EDESTINO"
     if [[ -d "${VERDIR}" ]]; then
     printf "\n"
     else
     clear
     _meiodatela
M995="Diretorio nao foi encontrado no servidor"
     _linha 
     _mensagec "$RED" "$M995"  
     _linha 
     _press
     _envrecarq
     fi

#-Informe a senha do usuario do scp
     _linha 
     _mensagec "$YELLOW" "$M29"
     _linha 
     "$cmd_scp" -r -P "$PORTA" "$USUARIO"@"$IPSERVER":"$RECBASE""/""$RRECEBE" "$EDESTINO""/". 
M15="Arquivo enviado para a pasta, \"""$EDESTINO""\"."
     _linha 
     _mensagec "$YELLOW" "$M15"
     _linha 
     _read_sleep 3
_envrecarq      
}

########################################################
# Limpando arquivos de atualizacao com mais de 30 dias #
########################################################
_expurgador () {
clear
#-Apagar Biblioteca--------------------------------------------------# 
#-Verificando e/ou excluido arquivos com mais de 30 dias criado.------#
     _linha 
     _mensagec "$RED" "$M51"
     _linha 
     sleep 3s
     printf "\n\n"
# Apagando todos os arquivos do diretorio backup#
     local DIR1="${BACKUP}""/"
     for arq in $DIR1{*.zip,*.bkp,*.sh} ; do
     "$cmd_find" "$arq" -mtime +30 -type f -delete 
     done    
# Apagar arquivos do diretorio olds----------------------------------#
     local DIR2="${OLDS}""/"
     for arq in $DIR2 ; do
     "$cmd_find" "$arq"* -mtime +30 -type f -delete 
     done
#-Apagar arquivos do diretorio progs---------------------------------#
     local DIR3="${PROGS}""/"
     for arq in $DIR3 ; do
     "$cmd_find" "$arq"* -mtime +30 -type f -delete 
     done
#-Apagar arquivos do diretorio dos logs---------------------------------#
     local DIR4="${LOGS}""/"
     for arq in $DIR4 ; do
     "$cmd_find" "$arq"* -mtime +30 -type f -delete 
     done
cd "${TOOLS}"/ || exit
_ferramentas
}

#-Atualizacao online-------------------------------------------------------------------------------#
_update () {
     clear
     printf "\n\n"
     _linha 
     _mensagec "$GREEN" "$M91"
     _mensagec "$GREEN" "$M92"
     _linha 
     cp -rfv atualiza.sh "$BACKUP"
     cd "${PROGS}" || exit 
     wget -q -c https://github.com/Luizaugusto1962/Atualiza/archive/master/atualiza.zip || exit
     
#-Descompactando o programa baixado----------------------------------#
DEFAULT_ATUALIZAGIT="atualiza.zip"
if [ -z "$atualizagit" ]; then
     atualizagit="$DEFAULT_ATUALIZAGIT"
fi
#atualizagit="atualiza.zip"
     "$cmd_unzip" -o "$atualizagit" >> "$LOG_ATU"
     _read_sleep 1
     "$cmd_find" "${PROGS}" -name "$atualizagit" -type f -delete 
     cd "${PROGS}"/Atualiza-main || exit
#-Atualizando somente o atualiza.sh----------------------------------#
     chmod +x "atualiza.sh"
     chmod +x "setup.sh"
     mv -f -- "atualiza.sh" "${TOOLS}" >> "$LOG_ATU"
     mv -f -- "setup.sh" "${TOOLS}" >> "$LOG_ATU"
     cd "${PROGS}" || exit
     rm -rf "${PROGS}"/Atualiza-main
_press
exit   
}

_principal

tput clear
tput sgr0
tput cup "$( tput lines )" 0
clear
