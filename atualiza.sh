#!/bin/bash
# set -xv
#set -e
#-----------------------------------------------------------------------------------------------------------------#
##  Rotina para atualizar programas e bibliotecas da SAV                                                          #
##  Feito por Luiz Augusto   email luizaugusto@sav.com.br                                                         #
##  Versao do atualiza.sh                                                                                         #
## UPDATE 19/01/2024                                                                                              #
#                                                                                                                 #
# INCLUIR PROCEDIMENTO PARA ATUALIZA PROGRAMA CLASS9 , VARIAVEL 9DIG 						  #
# incluir PACOTE de programas                                                                                     #
#-----------------------------------------------------------------------------------------------------------------#
# Arquivos de trabalho:                                                                                           #
# "atualizac" = Contem a configuracao de diretorios e de qual tipo de                                             #
#               sistema esta sendo utilizado pela a Empresa.                                                      #
# "atualizaj" = Lista de arquivos principais do sistema. "Usado no menu Ferramentas"                              #
# " = Lista de arquivos temporarios a ser exclu dos da pasta de dados.                                            #
#               "Usado no menu Ferramentas"                                                                       #
#                                                                                                                 #
# Menus                                                                                                           #
# 1 - Atualizacao de Programas                                                                                    #
# 2 - Atualizacao de Biblioteca                                                                                   #
# 3 - Desatualizando                                                                                              #
# 4 - Versao do Iscobol                                                                                           #
# 5 - Versao do Linux                                                                                             #
# 6 - Ferramentas                                                                                                 #
#                                                                                                                 #
#      1 - Atualizacao de Programas                                                                               #
#            1 - ON-Line                                                                                          #
#      Acessa o servidor da SAV via scp com o usuario ATUALIZA                                                    #
#      Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                                  #
#      com o nome "Nome do programa-anterior.zip" descompacta o novo no diretorio                                 #
#      dos programa e salva o a atualizacao na pasta ?/sav/tmp/progs.                                             #
#            2 - OFF-Line                                                                                         #
#      Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.                             #
#      O processo de atualizacao e id ntico ao passo acima.                                                       #
#      2 - Atualizacao de Biblioteca                                                                              #
#            1 - Atualizacao do Transpc                                                                           #
#      Atualiza a biblioteca que esta no diretorio /u/varejo/trans_pc/ do servidor da SAV.                        #
#      Faz um backup de todos os programas que esta em uso e salva na pasta ?/sav/tmp/olds                        #
#      com o nome "backup-(versao Informada).zip" descompacta os novos no diretorio                               #
#      dos programas e salva os zips da biblioteca na pasta ?/sav/tmp/biblioteca mudando a                        #
#      extensao de .zip para .bkp.                                                                                #
#            2 - Atualizacao do Savatu                                                                            #
#      Atualiza a biblioteca que esta no diretorio /home/savatu/biblioteca/temp/(diretorio                        #
#      conforme  sistema que esta sendo usado.                                                                    #
#      Mesmo procedimento acima.                                                                                  #
#            3 - Atualizacao9 OFF-Line                                                                            #
#      Atualiza a biblioteca que deve estar salva no diretorio ?/sav/tmp                                          #
#      Mesmo procedimento acima.                                                                                  #
#                                                                                                                 #
#      3 - Desatualizando                                                                                         #
#            1 - Voltar programa Atualizado                                                                       #
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com o nome de ("programa"-anterior.zip)        #
#      na pasta dos programas.                                                                                    #
#                                                                                                                 #
#            2 - Voltar antes da Biblioteca                                                                       #
#      Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backcup-versao da biblioteca".zip)  #
#      na pasta dos programas.                                                                                    #
#                                                                                                                 #
#      4 - Versao do Iscobol                                                                                      #
#            Verifica qual a versao do iscobol que esta sendo usada.                                              #
#                                                                                                                 #
#      5 - Versao do Linux                                                                                        #
#            Verifica qual o Linux em uso.                                                                        #
#                                                                                                                 #
#      6 - Ferramentas                                                                                            #
#           1 - Limpar Temporarios                                                                                #
#               Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup                         #
#               com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                                    #
#                                                                                                                 #
#           2 - Recuperar arquivos                                                                                #
#               1 - Um arquivo ou Todos                                                                           #
#                   Opcao pede para informa um arquivo espec fico, somente o nome sem a extensao                  #
#                   ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com as extens es,    #
#                   "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"                                               #
#                                                                                                                 #
#               2 - Arquivos Principais                                                                           #
#                   Roda o Jtuil somente nos arquivos que estao na lista "atualizaj"                              #
#                                                                                                                 #
#           3 - Backup da base de dados                                                                           #
#               Faz um backup da pasta de dados  e tem a opcao de enviar para a SAV                               #
#           4 - Restaurar Backup da base de dados                                                                 #
#               Volta o backup feito pela opcao acima                                                             #
#           5 - Enviar Backup                                                                                     #
#               Enviar ZIP feito pela opcao 3                                                                     #
#           6 - Expurgar                                                                                          #
#               Excluir, zips e bkps com mais de 30 dias processado                                               #
#           7 - Update                                                                                            #
#               Atualizacao do programa atualiza.sh                                                               #
#                                                                                                                 #
#                                                                                                                 #
#-----------------------------------------------------------------------------------------------------------------#

#-VARIAVEIS ------------------------------------------------------------------------------------#
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

#### configurar as variaveis em ambiente no arquivo abaixo:    ####
#- TESTE de CONFIGURACOES--------------------------------------------------------------------------#

[[ ! -e "atualizac" ]] && printf "ERRO. Arquivo atualizac, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizac" ]] && printf "ERRO. Arquivo atualizac, Sem acesso de leitura.\n" && exit 1

"." ./atualizac
#--------------------------------------------------------------------------------------------------#

#-Comandos#----------------------------------------------------------------------------------------#
cmd_unzip=""
cmd_unzip="unzip"
##
cmd_zip=""
cmd_zip="zip"
##
cmd_find=""
cmd_find="find"
##
cmd_scp=""
cmd_scp="scp"
##

#-Lista de mensagens #-----------------------------------------------------------------------------#
### Mensagens em YELLOW

M01="Compactando os arquivos Anteriores" 
#M02="Voltando a versao anterior do programa" 
M03="Volta do(s) Programa(s) Concluida(s)" 
M04="Volta do(s) Arquivo(s) Concluida" 
M05="Sistema nao e IsCOBOL" 
M06="Sera criado mais um backup para o periodo"  
#M07="Programa(s) a ser(em) atualizado(s) - ""$prog"
M08="Opcao Invalida"  
M09="O programa tem que estar no diretorio"   
#M10="O backup de nome \"""$ARQ""\"" 
#M11="Movendo arquivos Temporarios do diretorio =" "$DIR" 
M12="Arquivo(s) recuperado(s)..."
M13="De *.zip para *.bkp"
M14="Criando Backup.."
#M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
M16="Backup Concluido!"
M17="Atualizacao Completa"
M18="Arquivo(s) recuperado(s)..."
M19="ATUALIZANDO OS PROGRAMAS..."
M20="Alterando a extensao da atualizacao"
#M21="A atualizacao tem que esta no diretorio ""$TOOLS"
#M22=".. Criando o diretorio temp do backup em $DIRBACK.." 
#M23=".. Criando o diretorio dos backups em $BACKUP.."
M24=".. BACKUP do programa efetuado .." 
M25="... Voltando versao anterior ..." 
M26="... Agora, ATUALIZANDO ..." 
M27=" .. Backup Completo .." 
M28="Arquivo encontrado no diretorio" 
M29="Informe a senha do usuario do SCP"
#M30="o programas $vprog da ${NORM}${RED} ""$VVERSAO"
#M31="o programas da versao: ${NORM}${RED} ""$VVERSAO"
#M32="foi criado em ""$BACKUP"
M33="Voltando Backup anterior  ..."
#M34="O arquivo ""$VARQUIVO"
M35="Deseja voltar todos os ARQUIVOS do Backup ? (N/s):"
M36="<< ... Pressione qualquer tecla para continuar ... >>"
M37="Deseja informar mais algum programa para ser atualizado? sS/nN"
M38="Deseja continuar a atualizacao? (n/S):"
M39="Continuando a atualizacao...:"
MA1="O backup \"""$VBACKUP""\""

## Mensagens em RED

#M40="Versao atualizada - ""$VERSAO" 
#M41="Programa nao encontrado no diretorio" 
#M42="Programa, ""$NOMEPROG"" nao encontrado no diretorio" 
#M43="Programa ""$prog""-anterior.zip nao encontrado no diretorio." 
#M44="Nao foi encontrado o diretorio ""$exec" 
M45="Backup nao encontrado no diretorio" 
M46="Backup da Biblioteca nao encontrado no diretorio"
M47="Backup Abortado!"
M48="Atualizacao nao encontrado ou incompleta."
M49="Arquivo nao encontrado no diretorio"
#M50=""
M51="Verificando e/ou excluido arquivos com mais de 30 dias criado."
M52="Informe de qual o Backup que deseja enviar. Somente informe a data"
M53="Informe de qual o Backup que deseja voltara o(s) arquivo(s)."
#M54="Programa na versao 9 digitos nao encontrada baixar da class20"
M55="Informe versao a da Biblioteca a ser atualizada: "
M56="*+* < <- Versao a ser atualizada nao foi informada: -> > *+*"
M57="Informe somente o numeral da versao : "
M58="Voltando todos os programas."
M59="Informe o nome do programa a ser atualizado:"
M60="Faltou informou o nome do programa a ser atualizado ou esta em minusculo"
M61="Informe o nome do programa a ser desatualizado:" 
M62="Informe a ultima versao que foi feita a atualizacao da biblioteca para voltar todos os programas."
#M63="Existe um backup antigo sera excluido do Diretorio ""$BACKUP"
M64=" Informe o nome do arquivo ser recuperado OU enter para todos os arquivos:"
M65="Recuperado todos os arquivos:"
M66="Voce nao informou o nome do arquivo em minusculo"
M67="Recuperacao Isam :"
M68="Enviar backup para a SAV."
M69="Voce nao informou o nome do diretorio a ser enviado, saindo... "
M70="* * * < < Nome do Backup nao foi informada > > * * * "
M71="ERRO: Voce informou o nome do arquivo em minusculo "
M72="Informe o(s) arquivo(s) que deseja enviar."
M73="Informe o(s) arquivo(s) que deseja receber."
M74="* * * < < Nome do Arquivo nao foi informada > > * * *"
## Mensagens em cyan

M80="..Checando estrutura dos diretorios do atualiza.sh.." 
M81="..Encontrado o diretorio do sistema .." 
#M83="<< ... >>"

## Mensagens em verde

M91="Atualizar este sistema"
M92="ao termino da atualizacao sair e entrar novamente"

#-Variavel para identificar -----------------------------------------------------------------------#
VERSAO=""
if [ -z "$VERSAO" ]; then
          VERSAO=""
fi

SAVISCC="$destino""/sav/savisc/iscobol/bin/"
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

ARQUIVO=""
if [ -z "$ARQUIVO" ]; then
          ARQUIVO=""
fi

PEDARQ=""
if [ -z "$PEDARQ" ]; then
          PEDARQ=""
fi

prog=""
if [ -z "$prog" ]; then
          prog=""
fi

VVERSAO=""
if [ -z "$VVERSAO" ]; then
          VVERSAO=""
fi

TOOLS=$destino$pasta
     if [ -d "$TOOLS" ]; then
         printf " Diretorio ... ok \n"
     else
         printf " Diretorio da destino nao encotrado...  \n"
         exit
     fi
BASE=$destino$base
     if [ -d "$BASE" ]; then
         printf " Diretorio ... ok \n"
     else
         printf " Diretorio da base nao encotrado...  \n"
         exit
     fi

#-EXTENSAO QUE SERA INCLUIDA NO NOME DO PROGRAMA QUE A SER SALVO.----#
ANTERIOR="anterior"

#-Variaveis de cores-------------------------------------------------------------------------------#
export TERM=xterm-256color
tput sgr0
tput clear 
	 RED=$(tput bold)$(tput setaf 1)
	 GREEN=$(tput bold)$(tput setaf 2)
	 YELLOW=$(tput bold)$(tput setaf 3)
	 BLUE=$(tput bold)$(tput setaf 4)
      PURPLE=$(tput bold)$(tput setaf 5) 
	 CYAN=$(tput bold)$(tput setaf 6)
	 NORM=$(tput bold)$(tput setaf 7)
      BYELLOW=$(tput bold)$(tput setaf 3)$(tput blink) # amarelo piscante
COLUMNS=$(tput cols)
#-Conectores---------------------------------------------------------------------------------------#
#-Configuracao para acesso ao scp------------------------------------#
PORTA="41122"
USUARIO="atualiza"
IPSERVER="177.115.194.15"
DESTINO2SERVER="/u/varejo/man/"
DESTINO2SAVATUISC="/home/savatu/biblioteca/temp/ISCobol/sav-5.0/"
DESTINO2SAVATUMF="/home/savatu/biblioteca/temp/Isam/sav-3.1"
DESTINO2TRANSPC="/u/varejo/trans_pc/"
DESTINO2=""
if [ -z "$DESTINO2" ]; then
     DESTINO2=""
fi

#-Processo do scp----------------------------------------------------------------------------------#

_run_scp () {
      "$cmd_scp" -r -P "$PORTA" "$USUARIO"@"$IPSERVER":"$DESTINO2SERVER""$prog""$class".zip .
}

#-Processo do scp2---------------------------------------------------------------------------------#
_run_scp2 () {     # programas da biblioteca
      "$cmd_scp" -r -P "$PORTA" "$USUARIO"@"$IPSERVER":"$DESTINO2""$atu""$VERSAO".zip . 
}

#-Funcao de sleep----------------------------------------------------------------------------------#
_read_sleep () {
    # Usage: _read_sleep 1
    #        _read_sleep 0.2
     read -rt "$1" <> <(:) || :
}

#-Funcao teclar qualquer tecla---------------------------------------------------------------------#
_press () {
      printf "%*s""${BYELLOW}" ;printf "%*s\n" $(((${#M36}+COLUMNS)/2)) "$M36" ;printf "%*s""${NORM}"
      read -rt 15 || :
      tput sgr0
      #clear
}

#-Escolha qual o tipo de traco---------------------------------------------------------------------#
_linha () {
      local Traco=${1:-'-'}
      printf -v Espacos "%$(tput cols)s""" # quantidade de tracos por linha
      linhas=${Espacos// /$Traco}
	 printf "%*s\n" $(((${#linhas}+COLUMNS)/2)) "$linhas"
}

#-Centro da tela-----------------------------------------------------------------------------------#
_meiodatela () {
     printf "\033c\033[10;10H\n"
}

#-Mensagem centralizada-----------------------------------------------------------------------------#
_mensagec () {

local CCC=$1
local MXX=$2

if [ "$CCC" == "RED" ]; then
     printf "%*s""${RED}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
elif [ "$CCC" == "GREEN" ]; then
    printf "%*s""${GREEN}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
elif [ "$CCC" == "YELLOW" ]; then
     printf "%*s""${YELLOW}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
elif [ "$CCC" == "CYAN" ]; then
     printf "%*s""${CYAN}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
elif [ "$CCC" == "PURPLE" ]; then
     printf "%*s""${PURPLE}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
else
     printf "%*s""${BLUE}" ;printf "%*s\n" $(((${#MXX}+COLUMNS)/2)) "$MXX" ;printf "%*s""${NORM}"
fi

}

#-Verificacoes de parametro e diretorio------------------------------------------------------------#

 clear
if [ -d "$exec" ]; then
#-Encontrado o diretorio do sistema 
     _linha "*"
     _mensagec CYAN "$M81"
     _linha "*"
     _read_sleep 1
else
M44="Nao foi encontrado o diretorio ""$exec"
     _linha "*"
     _mensagec RED "$M44"
     _linha "*"
     _read_sleep 2
     exit
fi

if [ -d "$TOOLS" ]; then
     _linha "*"
     _mensagec CYAN "$M80"
     _linha "*"
         OLDS=$TOOLS$olds
         if [ -d "$OLDS" ]; then
             printf " Diretorio olds ... ok \n"
         else
             mkdir -p "$OLDS"
         fi
		 PROGS=$TOOLS$progs
         if [ -d "$PROGS" ]; then
             printf " Diretorio progs ... ok \n"
         else
             mkdir -p "$PROGS"
         fi
	     LOGS=$TOOLS$logs
         if [ -d "$LOGS" ]; then
             printf " Diretorio logs ... ok \n"
         else
             mkdir -p "$LOGS"
         fi
		 BACKUP=$TOOLS$backup
         if [ -d "$BACKUP" ]; then
             printf " Diretorio backups ... ok \n"
         else
             mkdir -p "$BACKUP"
         fi
	     ENVIA=$TOOLS"/envia"
         if [ -d "$ENVIA" ]; then
             printf " Diretorio envia ... ok \n"
         else
             mkdir -p "$ENVIA"
         fi
		 RECEBE=$TOOLS"/recebe"
         if [ -d "$RECEBE" ]; then
             printf " Diretorio recebe ... ok \n"
         else
             mkdir -p "$RECEBE"
         fi
else
     exit
fi

#### PARAMETRO PARA O LOGS
LOG_ATU=$LOGS/atualiza.$(date +"%Y-%m-%d").log
LOG_LIMPA=$LOGS/limpando.$(date +"%Y-%m-%d").log
UMADATA=$(date +"%d-%m-%Y_%H%M%S")

clear

_principal () { 
     tput clear
	 printf "\n"
#-100-mensagens do Menu Principal.-----------------------------------------------------------------#	
	 M101="Menu de Opcoes"
	 M102=".. Sistema: ""$sistema"" .. = ..Empresa: ""$EMPRESA"" .."
	 M103="Escolha a opcao:"
	 M104="1${NORM} - Atualizacao de Programas "
      M105="2${NORM} - Atualizacao de Biblioteca" 
      M106="3${NORM} - Desatualizando           "
	 M111="4${NORM} - Versao do Iscobol        "
	 M112="4${NORM} - Funcao nao disponivel    "
	 M107="5${NORM} - Versao do Linux          "
      M108="6${NORM} - Ferramentas              "
      M109="9${NORM} - ${RED}Sair           "
      M110=" Digite a opcao desejada -> " 

	 _linha "="
	 _mensagec RED "$M101"
	 _linha
	 _mensagec BLUE "$M102"
	 _linha "="
	 _mensagec PURPLE "$M103"
	 printf "\n"
	 _mensagec GREEN "$M104"
	 printf "\n"
	 _mensagec GREEN "$M105"
	 printf "\n"
	 _mensagec GREEN "$M106"
	 printf "\n"
         if [ "$sistema" = "iscobol" ]; then
		 _mensagec GREEN "$M111"
         else
		 _mensagec GREEN "$M112"
         fi
	 printf "\n"
	 _mensagec GREEN "$M107"
	 printf "\n"
	 _mensagec GREEN "$M108"
	 printf "\n"
	 _mensagec GREEN "$M109"
	 printf "\n"
     _linha "="
     read -rp "${YELLOW}""$M110""${NORM}" OPCAO

     case $OPCAO in
         1) _atualizacao   ;;
         2) _biblioteca    ;;
         3) _desatualizado ;;
         4) _iscobol       ;;
         5) _linux         ;;
         6) _ferramentas   ;;
         9) clear; tput sgr0; exit ;;
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
     M206=" Digite o numero da OPCAO desejada -> "
     printf "\n"
	 _linha "="
	 _mensagec RED "$M201"
	 _linha
	 printf "\n"
	 _mensagec PURPLE "$M202"
	 printf "\n"
	 _mensagec GREEN "$M203"
	 printf "\n"
	 _mensagec GREEN "$M204"
	 printf "\n"
	 _mensagec GREEN "$M205"
	 printf "\n"
	 _linha "="
     read -rp "${YELLOW}""$M206""${NORM}" OPCAO
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
     _mensagec RED "$M59"
     _linha 
     read -rp "${YELLOW}""       Informe o programa em MAIUSCULO: ""${NORM}" prog
     _linha 

     while [[ "$prog" =~ [^A-Z0-9] || -z "$prog" ]]; do
     clear
     _meiodatela
     _mensagec RED "$M60"
     _linha 
     _press
     _principal
     done
}

#-PROGRAMAS E/OU PACOTES---------------------------------------------------------------------------# 
_pacoteon () {
     _qualprograma
     #-Informe a senha do usuario do scp 
     _linha 
     _mensagec YELLOW "$M29"
     _linha 
     _run_scp
     _atupacote 
     _press 
     _principal
}
#_Pacotes em offline-----------------------------#

_pacoteoff () {
     #-O programa tem que estar no diretorio
     _qualprograma
     _linha
     _mensagec YELLOW "$M09"
     _linha
     local NOMEPROG="$prog""$class".zip
     _read_sleep 1
     _atupacote
     _press
     _principal
}

_atupacote () {
    if [[ -f "$OLDS"/"$prog"-"$ANTERIOR".zip ]] ; then
     clear
M43="Programa ""$prog""-anterior.zip encontrado no diretorio renomeando."
     _linha
     _mensagec CYAN "$M43"
     _linha
     mv -f -- "$OLDS"/"$prog"-"$ANTERIOR".zip "$OLDS"/"$prog"-"$ANTERIOR"-"$UMADATA".zip  >> "$LOG_ATU"
     fi

NOMEPROG="$prog""$class".zip

     if  [[ ! -f "$NOMEPROG" ]] ; then
     clear
M42="Programa, ""$NOMEPROG"" nao encontrado no diretorio" 
     _linha 
     _mensagec RED "$M42"
     _linha 
     _press 
     _principal
     fi

#-Descompactando o programa baixado----------------------------------#
    "$cmd_unzip" -o "$prog""$class".zip >> "$LOG_ATU"
     _read_sleep 1
     clear

#-Verificando nome do arquivo com a extensao .class ou .int----------#

     if [ "$sistema" = "iscobol" ]; then 
         for pprog in *.class
         do
         "$cmd_zip" "$prog"-$ANTERIOR "$exec"/"$pprog"   
         _read_sleep 2 
         mv -f -- "$pprog" "$exec" >> "$LOG_ATU"
		 done
     else 
         for pprog in *.int
         do
          "$cmd_zip" "$prog"-$ANTERIOR "$exec"/"$pprog"
          _read_sleep 2 
         mv -f -- "$pprog" "$exec" >> "$LOG_ATU"
         done
         _read_sleep 2
	 fi
         if [[ -f "$prog".TEL ]]; then

             for pprog in *.TEL
             do
              "$cmd_zip" -r "$prog"-$ANTERIOR "$telas"/"$pprog"
               _read_sleep 2 
               mv -f -- "$pprog" "$telas" >> "$LOG_ATU"
             done
         fi
#..   BACKUP do programa efetuado   ..
     _linha 
     _mensagec YELLOW "$M24"
     _linha 
     _read_sleep 1
 #-Atualizando o novo programa.--------------------------------------#
 M07="Programa(s) a ser(em) atualizado(s) - ""$prog"
     _linha 
     _mensagec YELLOW "$M26"
     _mensagec YELLOW "$M07"
     _linha 

#-ALTERANDO A EXTENSAO DA ATUALIZACAO... De *.zip para *.bkp
     _linha 
     _mensagec YELLOW "$M20"
     _mensagec YELLOW "$M13"
     _linha 

     for f in *"$prog""$class".zip; do
         mv -f -- "$f" "${f%.zip}.bkp"
     done
     _read_sleep 1
#-Atualizacao COMPLETA
     _linha 
     _mensagec YELLOW "$M17"
     _linha 
     mv -f -- "$prog""$class".bkp "$PROGS"
     mv -f -- "$prog"-$ANTERIOR.zip "$OLDS"
     _read_sleep 1

#-Escolha de multi programas-----------------------------------------------------------------------# 

#M37 Deseja informar mais algum programa para ser atualizado?
     _meiodatela
     _mensagec YELLOW "$M37"
     read -r -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then
         _principal
     elif [[ "$CONT" =~ ^[Ss]$ ]]; then
#    source ./atualizac
         if [[ "$OPCAO" = 1 ]] ; then
         _pacoteon
         else
        _pacoteoff
        fi
     _atupacote
     else
# Opcao Invalida
     _linha 
     _mensagec YELLOW "$M08"
     _linha 
     _press
     _principal
     fi
_principal
}

#-Desatualizacao de programas----------------------------------------------------------------------# 
_desatualizado () { while true
     do
     clear
###-300-mensagens do Menu desatualizacao.
     M301="Menu de Desatualizacao"
     M302="Escolha o tipo de Desatualizacao:"
     M303="1${NORM} - Voltar programa Atualizado "
     M304="2${NORM} - Voltar antes da Biblioteca "
     M305="9${NORM} - ${RED}Menu Anterior    "
     M306=" Digite o numero da OPCAO desejada -> "
	 printf "\n"
	 _linha "="
	 _mensagec RED "$M301"
	 _linha
	 printf "\n"
	 _mensagec PURPLE "$M302"
	 printf "\n"
	 _mensagec GREEN "$M303"
	 printf "\n"
	 _mensagec GREEN "$M304"
	 printf "\n"
	 _mensagec GREEN "$M305"
	 printf "\n"
	 _linha "="
     read -rp "${YELLOW}""$M306""${NORM}" OPCAO	
     case $OPCAO in
         1) _voltaprog ;;
         2) _voltabibli ;;
         9) clear ; _principal ;;
         *) _desatualizado ;;
     esac
     done
}

#-Procedimento da desatualizacao de programas------------------------------------------------------#
_voltaprog () {
     clear
#M61
     _meiodatela
     _linha 
     _mensagec RED "$M61"
     printf "\n"
     read -rp "${YELLOW}""     Informe o nome do programa em maiusculo: ""${NORM}" prog
     while [[ "$prog" =~ [^A-Z0-9] || -z "$prog" ]]; do
     _meiodatela
     _mensagec RED "$M60"
     _linha 
     _press
     _principal
     done

     if [[ ! -r "$OLDS"/"$prog"-"$ANTERIOR".zip ]]; then
     clear
M43="Programa ""$prog""-anterior.zip nao encontrado no diretorio."
     _linha 
     _mensagec RED "$M43"
     _linha 
     _press
     _principal
     fi

M02="Voltando a versao anterior do programa ""$prog"
     _linha 
     _mensagec YELLOW "$M02"
     _linha 

     "$cmd_unzip" -o "$OLDS"/"$prog"-"$ANTERIOR".zip -d /  >> "$LOG_ATU"
     _read_sleep 2
     clear
#-VOLTA DE PROGRAMA CONCLUIDA
     _linha 
     _mensagec YELLOW "$M03"
     _linha 
     _press
     _principal
}

#-Procedimento da desatualizacao de programas antes da biblioteca----------------------------------# 
_voltabibli () {
     clear
     _meiodatela
     _mensagec RED "$M62"
     _linha
     read -rp "${YELLOW}""         1- Informe apos qual versao da BIBLIOTECA: ""${NORM}" VVERSAO
     while [[ "$VVERSAO" = [0-9] || -z "$VVERSAO" ]]; do 
     clear
     _meiodatela
     _mensagec RED "$M56"
     _linha
     _press
     _desatualizado
     done

     if [[ ! -r "$OLDS"/"$INI-$VVERSAO".zip ]]; then
#-Backup da Biblioteca nao encontrado no diretorio
     _linha 
     _mensagec RED "$M46"
     _linha 
     _press
     _desatualizado
     fi
     printf "\n"
     printf "%*s\n""${YELLOW}""Deseja volta todos os programas para antes da atualizacao? (N/s):""${NORM}"
     read -r -n1 CONT 
     printf "\n\n"

     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then
	     _linha 
         _volta_progx
     elif [[ "$CONT" =~ ^[Ss]$ ]] ; then
	     _linha 
         _volta_geral
     else
#-Opcao Invalida
     _linha 
     _mensagec YELLOW "$M08"
     _linha 
     _press
     _desatualizado
     fi
}

#-VOLTA PROGRAMA ESPECIFICO------------------------------------------------------------------------#

_volta_progx () {
     read -rp "${YELLOW}""       2- Informe o nome do programa em maiusculo: ""${NORM}" Vprog

     while [[ "$Vprog" =~ [^A-Z0-9] || -z "$Vprog" ]]; 
	 do
     _meiodatela
     _mensagec RED "$M71"
     _linha 
     _press
     _desatualizado
     done

M30="O(s) programa(s) da ${NORM}${RED} ""$VVERSAO"
     _linha
     _mensagec YELLOW "$M25"
     _mensagec YELLOW "$M30"
     _linha

     cd "$OLDS"/ || exit
     "$cmd_unzip" -j "$INI"-"$VVERSAO".zip 
     _volta_progy
}

_volta_progz () {
     printf "\n"
     printf "%*s\n""${YELLOW}""Deseja volta mais algum programa ? (N/s):""${NORM}"
     read -r -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then
     _press
### limpando diretorio 
     local OLDS1="$OLDS"/
         for pprog in {*.class,*.TEL,*.xml,*.int,*.png,*.jpg}
         do
		 "$cmd_find" "$OLDS1" -name "$pprog" -ctime +30 -exec rm -r {} \; 
         done
     _desatualizado
     fi

	 local Vprog=" "
     if [[ "$CONT" =~ ^[Ss]$ ]] ; then
     read -rp "${YELLOW}""       2- Informe o nome do programa em maiusculo: ""${NORM}" Vprog
         if [[ "$Vprog" =~ [^A-Z0-9] || -z "$Vprog" ]]; then
         _meiodatela
         _mensagec RED "$M71"
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
     if [ "$sistema" = "iscobol" ]; then
         "$cmd_find" "$OLDS" -name "$Vprog.xml" -exec mv {} "$xml" \;

         "$cmd_find" "$OLDS" -name "$Vprog.TEL" -exec mv {} "$telas" \;

         "$cmd_find" "$OLDS" -name "$Vprog*.class" -exec mv {} "$exec" \;
         clear
     else
         "$cmd_find" "$OLDS" -name "$Vprog.TEL" -exec mv {} "$telas" \; 

        "$cmd_find" "$OLDS" -name "$Vprog*.int" -exec mv {} "$exec" \; 
     fi

#-VOLTA DE PROGRAMAS CONCLUIDA
     _linha 
     _mensagec YELLOW "$M03"
     _linha 

M30="O(s) programa(s) da ${NORM}${RED} ""$VVERSAO"
     _linha 
     _mensagec YELLOW "$M25"
     _mensagec YELLOW "$M30"
     _linha 
     _press
     _volta_progz
}

#-volta todos os programas da biblioteca-----------------------------------------------------------#
_volta_bibli () {
#-VOLTA DOS ARQUIVOS ANTERIORES...
     _linha 
     _mensagec YELLOW "$M03"
     _linha 

     _read_sleep 1
     if [ "$sistema" = "iscobol" ]; then

     cd "$OLDS" || exit

	 "$cmd_find" "$OLDS" -type f \( -iname "*.class" -o -iname "*.jpg" -o -iname "*.png" -o -iname "*.brw" -o -iname "*." -o -iname "*.dll" \) -exec mv "{}" "$exec" \; >> "$LOG_ATU"

     "$cmd_find" "$OLDS" -type f \( -iname "*.TEL" \) -exec mv "{}" "$telas" \; >> "$LOG_ATU"

     cd "$xml"/ || exit
	 "$cmd_find" "$OLDS" -type f \( -iname "*.xml" \) -exec mv "{}" "$xml" \; >> "$LOG_ATU"

     cd "$TOOLS"/ || exit
     clear

     else
     cd "$OLDS"/ || exit
	 "$cmd_find" "$OLDS" -type f \( -iname "*.int" \) -exec mv "{}" "$exec" \; >> "$LOG_ATU"

     cd "$OLDS"/ || exit
	 "$cmd_find" "$OLDS" -type f \( -iname "*.TEL" \) -exec mv "{}" "$telas" \; >> "$LOG_ATU"

     cd "$TOOLS"/ || exit
     clear

M30="O(s) programa(s) da ${NORM}${RED} ""$VVERSAO"
     _linha 
     _mensagec YELLOW "$M25"
     _mensagec YELLOW "$M30"
     _linha 
     fi
     _press
     _principal
}

#-Volta total dos programas------------------------------------------------------------------------#
_volta_geral () { 
#-M58=Voltando todos os programas.
     _linha 
     _mensagec RED "$M58"
     _linha 
 
#-M31="O programas da versao:"$VVERSAO"
     _linha 
     _mensagec YELLOW "$M25"
     _mensagec YELLOW "$M31"
     _linha 

     cd "$OLDS"/ || exit
     "$cmd_unzip" -o "$INI"-"$VVERSAO".zip -d "$OLDS"
     cd "$TOOLS" || exit
     clear

#-VOLTA DOS PROGRAMAS CONCLUIDA
     _linha 
     _mensagec YELLOW "$M03"
     _linha 
     _volta_bibli
     _press
     _principal  
}

#-Rotina de Atualizacao Biblioteca-----------------------------------------------------------------#
_biblioteca () { while true
    do
    clear
 #-M55=Informe versao a ser atualizar: "
     #printf "\n\n\n"
     _meiodatela
     _mensagec RED "$M55"
     _linha  
 #-M57=Informe somente o numeral da versao :
     printf "%*s""${YELLOW}";printf "%*s\n""$M57" ;printf "%*s""${NORM}"
    read -rp "" VERSAO 

     if [ -z "$VERSAO" ]; then
 #-M56=Versao a ser atualizada nao foi informada :
     printf "\n"
     _linha
     _mensagec RED "$M56"
     _linha 
     _press
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
     M407="9${NORM} - ${RED}Menu Anterior "
     M408=" Digite o numero da OPCAO desejada -> "
	 printf "\n"
	 _linha "="
	 _mensagec RED "$M401"
	 _linha 
	 _mensagec RED "$M402"
	 _linha "="
	 printf "\n"
	 _mensagec PURPLE "$M403"
	 printf "\n"
	 _mensagec GREEN "$M404"
	 printf "\n"
	 _mensagec GREEN "$M405"
	 printf "\n"
	 _mensagec GREEN "$M406"
	 printf "\n"
	 _mensagec GREEN "$M407"
	 printf "\n"
	 _linha "="
     read -rp "${YELLOW}""$M408""${NORM}" OPCAO	
     case $OPCAO in
         1) _transpc ;;
         2) _savatu ;;
         3) _salva ;;
         9) clear ; _principal ;;
         *) _biblioteca ;;
     esac
     done
}

#-Processo de recepcao da biblioteca---------------------------------------------------------------#
_scp_biblioteca () {
	 if [ "$sistema" = "iscobol" ]; then
     for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ;do
     _run_scp2
	 done
     _salva
	 else
     for atu in $SAVATU1 $SAVATU2 $SAVATU3 ;do	
	 _run_scp2
	 done 
	 fi
     _salva
}

#-Atualizacao da pasta transpc---------------------------------------------------------------------#
_transpc () {

#-Informe a senha do usuario do scp
     _linha 
     _mensagec YELLOW "$M29"
     _linha 
     DESTINO2="$DESTINO2TRANSPC"
     _scp_biblioteca
}

#-Atualizacao da pasta do savatu-------------------------------------------------------------------# 
_savatu () {
#-Informe a senha do usuario do scp 
     _linha 
     _mensagec YELLOW "$M29"
     _linha 
     if [ "$sistema" = "iscobol" ]; then 
 	 DESTINO2="$DESTINO2SAVATUISC"
     _scp_biblioteca
	 else 
	 DESTINO2="$DESTINO2SAVATUMF"
	 _scp_biblioteca
	 fi
}

#-Atualizacao offline a biblioteca deve esta no diretorio------------------------------------------# 
_salva () {

M21="A atualizacao tem que esta no diretorio ""$TOOLS"
     _linha 
     _mensagec YELLOW "$M21"
     _linha 
     if [ "$sistema" = "iscobol" ]; then
         for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ;do
             if  [[ ! -r "$atu""$VERSAO"".zip" ]] ; then
            clear
#-Atualizacao nao encontrado no diretorio
     _linha 
     _mensagec RED "$M48"
     _linha 
	 _press
	 clear
     _principal
            fi
         done 
     _processo
#-Atualizacao nao encontrado no diretorio
     _linha 
     _mensagec RED "$M48"
     _linha 
     _press
     _principal
     else
         for atu in $SAVATU1 $SAVATU2 $SAVATU3 ;do
             if  [[ ! -r "$atu""$VERSAO"".zip" ]] ; then
            clear 
#-Atualizacao nao encontrado no diretorio
     _linha 
     _mensagec RED "$M48"
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
     _mensagec YELLOW "$M01"
     _linha 
     
     _read_sleep 1
     if [ "$sistema" = "iscobol" ]; then
         cd "$exec"/ || exit
         "$cmd_find" "$exec"/ -type f \( -iname "*.class" -o -iname "*.jpg" -o -iname "*.png" -o -iname "*.brw" -o -iname "*." -o -iname "*.dll" \) -exec zip -r "$TOOLS"/"$INI"-"$VERSAO" "{}" +;
         cd "$telas"/ || exit
         "$cmd_find" "$telas"/ -type f \( -iname "*.TEL" \) -exec zip -r "$TOOLS"/"$INI"-"$VERSAO" "{}" +;
         cd "$xml"/ || exit
         "$cmd_find" "$xml"/ -type f \( -iname "*.xml" \) -exec zip -r "$TOOLS"/"$INI"-"$VERSAO" "{}" +;
         cd "$TOOLS"/ || exit
         clear
     else
         cd "$exec"/ || exit
	     "$cmd_find" "$exec"/ -type f \( -iname "*.int" \) -exec zip -r "$TOOLS"/"$INI"-"$VERSAO" "{}" +;
         cd "$telas"/ || exit
	     "$cmd_find" "$telas"/ -type f \( -iname "*.TEL" \) -exec zip -r "$TOOLS"/"$INI"-"$VERSAO" "{}" +;
     fi 

#-..   BACKUP COMPLETO   ..
     _linha 
     _mensagec YELLOW "$M27"
     _linha 
     _read_sleep 1
    
     if [[ ! -r "$TOOLS"/"$INI-$VERSAO".zip ]]; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec RED "$M45"
     _linha 

#-Procedimento caso nao exista o diretorio a ser atualizado----------------------------------------# 
     _read_sleep 2    
     _meiodatela
     printf "%*s""${YELLOW}" ;"$M38"; printf "%*s""${NORM}"
     read -r -n1 CONT 
     printf "\n\n"
         if [[ "$CONT" =~ ^[Nn]$ ]] ; then
         _principal
         elif [[ "$CONT" =~ ^[Ss]$ ]] || [[ "$CONT" == "" ]]; then
         _meiodatela
         _mensagec YELLOW "$M39"
         else
#-Opcao Invalida 
         _linha 
         _mensagec YELLOW "$M08"
         _linha 
         _principal
         fi 
    fi
    
#-Procedimento da Atualizacao de Programas---------------------------------------------------------# 
     cd "$TOOLS" || exit
#-ATUALIZANDO OS PROGRAMAS...
     _linha 
     _mensagec YELLOW "$M19"
     _linha 
     for atu in $SAVATU1 $SAVATU2 $SAVATU3 $SAVATU4 ;do
	     printf "${GREEN}"" Atualizado ""$atu""$VERSAO"".zip""${NORM}""%*s\n" || printf "%*s""$M48"
         "$cmd_unzip" -o "$atu""$VERSAO".zip -d "$destino" >> "$LOG_ATU"
         _read_sleep 2
         clear
     done
#-Atualizacao COMPLETA
     _linha 
     _mensagec YELLOW "$M17"
     _linha 
     for f in *_"$VERSAO".zip; do
         mv -f -- "$f" "${f%.zip}.bkp"
     done
         mv -f -- *_"$VERSAO".bkp "$BACKUP"
         mv -f -- "$INI"-"$VERSAO".zip "$OLDS"

#-ALTERANDO A EXTENSAO DA ATUALIZACAO.../De *.zip para *.bkp/
#-Versao atualizada - $VERSAO$
M40="Versao atualizada - ""$VERSAO"
_linha 
_mensagec YELLOW "$M20"
_mensagec YELLOW "$M13"
_mensagec RED "$M40"
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
     _mensagec YELLOW "$M05"
     _linha 
     fi
_press
_principal
}

#-Mostrar a versao do Linux que esta sendo usada.--------------------------------------------------# 
_linux () {
    clear
     LX="Vamos descobrir qual SO / Distro voce esta executando"
     LM="A partir de algumas informacoes basicas o seu sistema, parece estar executando:"
     printf "\n\n"
     _mensagec GREEN "$LX"
     _linha 
     printf "\n\n"
     _mensagec YELLOW "$LM"
     _linha 

#-identificando OS
if [[ -f /etc/os-release ]]; then
    # freedesktop.org and systemd
     . /etc/os-release
     OS=$NAME
     VER=$VERSION_ID
     UPSTREAM_ID=${ID_LIKE,,}
    # Fallback to ID_LIKE if ID was not 'ubuntu' or 'debian'
     if [[ "${UPSTREAM_ID}" != "debian" ]] && [[ "${UPSTREAM_ID}" != "ubuntu" ]]; then
         UPSTREAM_ID="$(echo "${ID_LIKE,,}" | sed s/\"//g | cut -d' ' -f1)"
     fi

elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
     OS=$(lsb_release -si)
     VER=$(lsb_release -sr)
elif [[ -f /etc/lsb-release ]]; then
    #-Para algumas versões do Debian/Ubuntu sem o comando lsb_release
    . /etc/lsb-release
     OS=$DISTRIB_ID
     VER=$DISTRIB_RELEASE
elif [[ -f /etc/debian_version ]]; then
    #-Velhas distros Debian/Ubuntu/etc.
     OS=Debian
     VER=$(cat /etc/debian_version)
elif [[ -f /etc/SuSe-release ]]; then
    #-Velhas distros SuSE/etc.
     OS=SuSE
     VER=$(cat /etc/SuSe-release)
elif [[ -f /etc/redhat-release ]]; then
    #-Velhas distros Red Hat, CentOS, etc.
     OS=RedHat
     VER=$(cat /etc/redhat-release)
else
    #-Para uname, e.x. "Linux <version>", também funciona para o BSD, etc.
     OS=$(uname -s)
     VER=$(uname -r)
fi
     printf "${GREEN}          OS:${NORM}      ${CYAN} ""$OS""   ${NORM}%s\n\n"
     printf "${GREEN}          VER:${NORM}      ${CYAN} ""$VER"" ${NORM}%s\n\n"
     printf "${GREEN}          UPSTREAM_ID:${NORM} ${CYAN} ""$UPSTREAM_ID"" ${NORM}%s\n\n" 
_linha 
printf "\n"
_press
_principal
}

_ferramentas () {

clear
###-500-mensagens do Menu Ferramentas.	
     M501="Menu das Ferramentas"
     M502="Escolha a opcao:"
     M503="1${NORM} - Limpar Temporarios               "
     M512="2${NORM} - Expurgar                         "
     M513="3${NORM} - Update                           "	
     M503="1${NORM} - Limpar Temporarios               "
     M504="2${NORM} - Recuperar arquivos               "
     M505="3${NORM} - Fazer ou Restaurar Backup        "
     M506="4${NORM} - Envia e Recebe Arquivos          "
     M508="5${NORM} - Expurgar                         "
#    M507="6${NORM} - ""                    "
     M509="8${NORM} - Update                           "	
     M510="9${NORM} - ${RED}Menu Anterior          "
     M511=" Digite a opcao desejada -> "
     _linha "="
     _mensagec RED "$M501"
     _linha 
     printf "\n"
     _mensagec PURPLE "$M502"
     printf "\n"
     if [[ "$BANCO" = "s" ]]; then
     _mensagec GREEN "$M503"
     printf "\n"
     _mensagec GREEN "$M512"
     printf "\n"
     _mensagec GREEN "$M513"
     printf "\n"
     _mensagec GREEN "$M510"
	 printf "\n"
	 _linha "="
     read -rp "${YELLOW}""$M511""${NORM}" OPCAOB
         case $OPCAOB in
         1) _temps        ;;
         2) _expurgador   ;;
         3) _update       ;;
         9) clear ; _principal ;;
         *) _ferramentas ;;
         esac
	 else
	 _mensagec GREEN "$M503"
     printf "\n"
	 _mensagec GREEN "$M504"
     printf "\n"
     _mensagec GREEN "$M505"
     printf "\n"
	 _mensagec GREEN "$M506"
     printf "\n"
#	 _mensagec GREEN "$M507"
#     printf "\n"
	 _mensagec GREEN "$M508"
     printf "\n"
	 _mensagec GREEN "$M509"
	 printf "\n"
    fi
	 _mensagec GREEN "$M510"
	 printf "\n"
	 _linha "="
     read -rp "${YELLOW}""$M511""${NORM}" OPCAO
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
    clear
_limpando () {
      TEMPORARIOS="Temps"
      ETIQUETATEMPO="$(date +'%d-%m-%Y-%M')"

         while read -r line;
         do
         "$cmd_find" "$DIRB" -name "$line" -exec ls -l {} \;
        # sleep 1
         #printf "${GREEN}""$line""${NORM}\n"
         "$cmd_zip" -m "$BACKUP""/""$TEMPORARIOS-$ETIQUETATEMPO" "$DIRB"$line {} \; >> "$LOG_LIMPA"
         done < "$arqs"
  
M11="Movendo arquivos Temporarios do diretorio = ""$i"
 _linha 
 _mensagec YELLOW "$M11"
 _linha 

}

_temps () {

#-Le a lista "atualizat" que contem os arquivos a serem excluidas da base do sistema---------------# 
#-TESTE Arquivos ----------------------------------------------------------------------------------#
[[ ! -e "atualizat" ]] && printf "ERRO. Arquivo atualizat, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizat" ]] && printf "ERRO. Arquivo atualizat, Sem acesso de leitura.\n" && exit 1
#--------------------------------------------------------------------------------------------------#
#-Rotina para excluir arquivo temporarios----------------------------------------------------------#

  cd "$TOOLS"/ || exit
  arqs="atualizat"
             DAYS=$(find "$BACKUP" -type f -name "Temps*" -mtime 10 -exec rm -rf {} \;)
         if [[ "$DAYS" ]] ; then
               M63="Existe um backup antigo sera excluido do Diretorio ""$DIRDEST"
             _meiodatela
             _messagec RED "$M63"
         fi 

 for i in $base $base2 $base3 ;do
 DIRB="$destino""$i""/"
 _limpando
 _press
 done 
  _ferramentas

}

#-Rotina de recuperar arquivos---------------------------------------------------------------------#
_rebuild () { 
     clear
###-600-mensagens do Menu Rebuild.
      M601="Menu de Recuperacao de Arquivo(s)."
	 M602="Escolha a opcao:"
	 M603="1${NORM} - Um arquivo ou Todos   "
	 M604="2${NORM} - Arquivos Principais   "
      M605="9${NORM} - ${RED}Menu Anterior"
      M606=" Digite o numero da OPCAO desejada -> "
	 printf "\n"
	 _linha "="
	 _mensagec RED "$M601"
	 _linha 
	 printf "\n"
	 _mensagec PURPLE "$M602"
	 printf "\n"
	 _mensagec GREEN "$M603"
	 printf "\n"
	 _mensagec GREEN "$M604"
	 printf "\n"
	 _mensagec GREEN "$M605"
	 printf "\n"
	 _linha "="
      read -rp "${YELLOW}""$M606""${NORM}" OPCAO	
      case $OPCAO in
           1) _rebuild1 ;;
           2) _rebuildlista ;;
           9) clear ; _ferramentas ;;
           *) _ferramentas ;;
      esac
 
 }


#-Rotina de recuperar arquivos especifico ou todos se deixar em branco-----------------------------#
_rebuild1 () {
 if [ "$sistema" = "iscobol" ]; then
         _meiodatela
#-M64   
         printf "%*s""${RED}""$M64""${NORM}\n"
         read -rp "${YELLOW}""         Informe o nome maiusculo: ""${NORM}" PEDARQ

     if [[ -z "$PEDARQ" ]]; then
         _meiodatela
#-M65
     _mensagec RED "$M65"
     _linha 
     local jut="$SAVISC""$JUTIL"
#     cd "$BASE"/ || exit
     for i in $BASE/{*.ARQ.dat,*.DAT.dat,*.LOG.dat,*.PAN.dat}
     do
     TAMANHO=$(du "$i" | awk '{print $1}') ##- grava tamanho do arquivo em variavel
         if [[ "$TAMANHO" -gt 0 ]] ; then  ##- executa rebuild se tamanho for maior que zero
         $jut -rebuild "$i" -a -f
         fi
     done 
         cd "$TOOLS"/ || exit
     else
         while [[ "$PEDARQ" =~ [^A-Z0-9] ]]; do
         _meiodatela
         _mensagec RED "$M66"
         cd "$TOOLS"/ || exit
         _press
         _ferramentas
         done
     local ARQUIVO="$PEDARQ.???.dat"
         for i in $ARQUIVO
         do 
         $jut -rebuild "$i" -a -f
         done
     fi

#-Arquivo(s) recuperado(s)...
     _linha 
     _mensagec YELLOW "$M18"
     _linha 

cd "$TOOLS"/ || exit
else
#-m67
     _meiodatela
     _mensagec RED "$M67"
     cd "$BASE"/ || exit

     for i in $BASE/{*.ARQ,*.DAT,*.LOG,*.PAN}
     do
     TAMANHO=$(du "$i" | awk '{print $1}') #-grava tamanho do arquivo em variavel
         if [[ "$TAMANHO" -gt 0 ]]; then #-executa rebuild se tamanho for maior que zero
         rebuild -e "$i"
         else
         rebuild -d -e "$i"
         fi
     done
fi
_press
_rebuild 
}


#-Rotina de recuperar arquivos de uma Lista os arquivos estao cadatrados em "atualizaj"------------#

#-TESTE Arquivos ----------------------------------------------------------------------------------#
[[ ! -e "atualizaj" ]] && printf "ERRO. Arquivo atualizaj, Nao existe no diretorio.\n" && exit 1
[[ ! -r "atualizaj" ]] && printf "ERRO. Arquivo atualizaj, Sem acesso de leitura.\n" && exit 1
#--------------------------------------------------------------------------------------------------#

_rebuildlista () {
clear
if [ "$sistema" = "iscobol" ]; then
cd "$TOOLS"/ || exit
local arqs=""
arqs="atualizaj"
local jut="$SAVISC""$JUTIL"
while read -r line;
do
     TAMANHO=$(du "$BASE""/""$line" | awk '{print $1}') #-Grava tamanho do arquivo em variavel
     if [[ "$TAMANHO" -gt 0 ]] ; then #-Executa rebuild se tamanho for maior que zero
     $jut -rebuild "$BASE""/""$line" -a -f
     fi
done < "atualizaj"

#-Lista de Arquivo(s) recuperado(s)... 
     _linha 
     _mensagec YELLOW "$M12"
     _linha 
   
_press
else
M996="Recuperacao em desenvolvimento :"
_mensagec RED "$M996"
fi
_press
_rebuild
}

_menubackup () { while true
    do
    clear
###-700-mensagens do Menu Backup.
     M700="Menu de Backup(s)."
     M701="Escolha a opcao:"
     M702="1${NORM} - Backup da base de dados          "
     M703="2${NORM} - Restaurar Backup da base de dados"
     M704="3${NORM} - Enviar Backup                    "
     M705="9${NORM} - ${RED}Menu Anterior          "
     M706=" Digite o numero da OPCAO desejada -> "
	 printf "\n"
	 _linha "="
	 _mensagec RED "$M700"
	 _linha 
	 printf "\n"
	 _mensagec PURPLE "$M701"
	 printf "\n"
	 _mensagec GREEN "$M702"
	 printf "\n"
	 _mensagec GREEN "$M703"
	 printf "\n"
	 _mensagec GREEN "$M704"
       printf "\n"
	 _mensagec GREEN "$M705"
       printf "\n"       
	 _linha "="
     read -rp "${YELLOW}""$M706""${NORM}" OPCAO	
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

    if [ ! -d "$BACKUP" ]; then
M23=".. Criando o diretorio dos backups em $BACKUP.."
     _linha 
     _mensagec YELLOW "$M23"
     _linha 
   
    mkdir -p "$BACKUP"
    fi
    
DAYS2=$(find "$BACKUP" -ctime -2 -name "$EMPRESA"\*zip)
    cd "$BASE" || exit
if [[ "$DAYS2" ]] ; then

M62="Ja existe um backup em ""$BACKUP"" nos ultimos dias."
    printf "\n\n"
    _linha 
    _mensagec CYAN "$M62"
    _linha   
    printf "\n" 
    printf "${YELLOW}""          Deseja continuar ? (N/s): ""${NORM}%s"
    read -r -n1 CONT 
    printf "\n"
        if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then

#-Backup Abortado!
     _linha 
     _mensagec RED "$M47"
     _linha         
    _read_sleep 3
    _ferramentas 
        elif [[ "$CONT" =~ ^[Ss]$ ]] ; then

#-Sera criado mais um backup para o periodo.
     _linha 
     _mensagec YELLOW "$M06"
     _linha 

        else
#-Opcao Invalida 
     _linha 
     _mensagec YELLOW "$M08"
     _linha 

     _ferramentas 
        fi
fi
#-Criando Backup..
     _linha 
     _mensagec YELLOW "$M14"
     _linha 
    
ARQ="$EMPRESA"_$(date +%Y%m%d%H%M).zip

#-Rotina do progresso de execução.-----------------------------------------------------------------#
_progresso () { 
  echo -n "${YELLOW}"" Favor aguardar [""${NORM}"
  while true
  do
    echo -n "${YELLOW}""#""${NORM}"
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

     echo "${CYAN}""]pronto""${NORM}"
     printf "\n"

#-O backup de nome \"""$ARQ""\" foi criado em $BACKUP$}
M10="O backup de nome ""$ARQ"
M32="foi criado em ""$BACKUP"
     _linha 
     _mensagec YELLOW "$M10"
     _mensagec YELLOW "$M32"
     _linha 
     printf "\n"

#-Backup Concluido!
     _linha 
     _mensagec YELLOW "$M16"
     _linha 

#-ENVIAR PARA A SAV OU NAO-------------------------------------------#
    printf "\n"
    clear
M10="O backup de nome \"""$ARQ""\"" 
     _linha 
     _mensagec YELLOW "$M10"
     _linha 
   
     printf "${YELLOW}""         Deseja enviar para o servidor da SAV ? (N/s):""${NORM}%s"
     read -r -n1 CONT 
     printf "\n\n"
if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then    
     _ferramentas
elif [[ "$CONT" =~ ^[Ss]$ ]] ; then
 
     _meiodatela
     _mensagec RED "$M68"
     read -rp "${YELLOW}""         Informe para qual diretorio no servidor: ""${NORM}" ENVBASE
     while [[ "$ENVBASE" =~ [0-9] || -z "$ENVBASE" ]] ;do
     _meiodatela
#-M69 Voce nao informou o nome do diretorio a enviado, saindo...   
     _mensagec RED "$M69"
 
_press    
     _ferramentas 
     done
#-Informe a senha do usuario do scp
     _linha 
     _mensagec YELLOW "$M29"
     _linha 

     "$cmd_scp" -r -P "$PORTA" "$BACKUP/$ARQ" "$USUARIO"@"$IPSERVER":/"$ENVBASE" 
M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
     _linha 
     _mensagec YELLOW "$M15"
     _linha 
     _read_sleep 3 
     _ferramentas
else
#-Opcao Invalida
     _linha 
     _mensagec YELLOW "$M08"
     _linha   
    _ferramentas 
fi
} 

#-Enviar backup avulso-----------------------------------------------------------------------------#
_backupavulso () {
    ls "$BACKUP"/"$EMPRESA"_*.zip

#-Informe de qual o Backup que deseja enviar.
     _linha 
     _mensagec RED "$M52"
     _linha      

     read -rp "${YELLOW}""         1- Informe nome BACKUP: ""${NORM}" VBACKAV
local VBACKUP="$EMPRESA"_"$VBACKAV"
     while [[ -f "$VBACKUP".zip ]] ;do 
     clear
      _meiodatela
      _mensagec RED "$M70"
      _press
_ferramentas
    done
    if [[ ! -r "$BACKUP"/"$VBACKUP".zip ]]; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec RED "$M45"
     _linha     
     _press
     _ferramentas
    fi
    printf "\n"
    clear
      _meiodatela
MA1="O backup \"""$VBACKUP""\""     
      _linha
      _mensagec YELLOW "$MA1"
      _linha 
      printf "${YELLOW}""      Deseja enviar para o servidor da SAV ? (N/s):""${NORM}%s"
      read -r -n1 CONT 
      printf "\n\n"

if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then    
     _ferramentas
elif [[ "$CONT" =~ ^[Ss]$ ]] ; then
      _meiodatela
      _mensagec RED "$M68"
      read -rp "${YELLOW}""         Informe para qual diretorio no servidor: ""${NORM}" ENVBASE
     while [[ "$ENVBASE" =~ [0-9] || -f "$ENVBASE" ]] ;do
     _meiodatela
#M69  
     _mensagec RED "$M69"
     _press    
     _ferramentas 
     done

#-Informe a senha do usuario do scp
      _linha 
      _mensagec YELLOW "$M29"
      _linha 
      "$cmd_scp" -r -P "$PORTA" "$BACKUP""/""$VBACKUP".zip "$USUARIO"@"$IPSERVER":/"$ENVBASE" 
M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
      _linha 
      _mensagec YELLOW "$M15"
      _linha 
      _read_sleep 3 
else
#   Opcao Invalida
      _linha 
      _mensagec YELLOW "$M08"
      _linha  
fi
_ferramentas   
}   
  
#-VOLTA BACKUP TOTAL OU PARCIAL--------------------------------------------------------------------#

_unbackup () {
    clear
local DIRBACK="$BACKUP"/dados

    if [ ! -d "$DIRBACK" ]; then

M22=".. Criando o diretorio temp do backup em $DIRBACK.." 
     _linha 
     _mensagec YELLOW "$M22"
     _linha 
   
    mkdir -p "$DIRBACK"
    fi
    ls -s "$BACKUP""/""$EMPRESA"_*.zip
     _linha 
     _mensagec RED "$M53"
     _linha 
     read -rp "${YELLOW}""         1- Informe somente a data do BACKUP: ""${NORM}" VBACK
local VBACKUP="$EMPRESA"_"$VBACK"
     while [[ -f "$VBACKUP".zip ]] ;do 
     clear
     _meiodatela
     _mensagec RED "$M70"
     _press
     _menubackup
     done
     if [[ ! -r "$BACKUP"/"$VBACKUP".zip ]] ; then
#-Backup nao encontrado no diretorio
     _linha 
     _mensagec RED "$M45"
     _linha 
     _press
     _menubackup
     fi
     printf "\n" 
#-"Deseja volta todos os ARQUIVOS do Backup ? (N/s):"
     _linha 
     _mensagec YELLOW "$M35"
     _linha 
     read -r -n1 CONT 
     printf "\n\n"
     if [[ "$CONT" =~ ^[Nn]$ ]] || [[ "$CONT" == "" ]] ; then

     read -rp "${YELLOW}""       2- Informe o somente nome do arquivo em maiusculo: ""${NORM}" VARQUIVO
     while [[ "$VARQUIVO" =~ [^A-Z0-9] ]]
     do
 #M71
     _mensagec RED "$M71"
     _linha 
     _press
     _menubackup
     done

#-Voltando Backup anterior  ...-#

M34="O arquivo ""$VARQUIVO"

     _linha 
     _mensagec YELLOW "$M33"
     _mensagec YELLOW "$M34"
     _linha 

     cd "$DIRBACK" || exit
     "$cmd_unzip" -o "$BACKUP""/""$VBACKUP".zip "$VARQUIVO*.*" >> "$LOG_ATU"
     _read_sleep 1

     if ls -s "$VARQUIVO"*.* >erro /dev/null 2>&1 ; then
#-Arquivo encontrado no diretorio
     _linha 
     _mensagec YELLOW "$M28"
     _linha 
   
     else
#-Arquivo nao encontrado no diretorio
     _linha 
     _mensagec YELLOW "$M49"
     _linha 
     _press 
     _menubackup  
     fi

     mv -f "$VARQUIVO"*.* "$BASE" >> "$LOG_ATU" 
     cd "$TOOLS"/ || exit
     clear
#-VOLTA DO ARQUIVO CONCLUIDA
     _linha 
     _mensagec YELLOW "$M04"
     _linha 
     _press
     _menubackup
     elif [[ "$CONT" =~ ^[Ss]$ ]] ; then
 
#---- Voltando Backup anterior  ... ----
M34="O arquivo ""$VARQUIVO"
     _linha 
     _mensagec YELLOW "$M33"
     _mensagec YELLOW "$M34"
     _linha 
   
    cd "$DIRBACK" || exit
    "$cmd_unzip" -o "$BACKUP""/""$VBACKUP".zip  >> "$LOG_ATU"
    
    mv -f -- *.* "$BASE" >> "$LOG_ATU"
 
    cd "$TOOLS"/ || exit
    clear
#-VOLTA DOS ARQUIVOS CONCLUIDA
     _linha 
     _mensagec YELLOW "$M04"
     _linha 
   
_press
    else
#-Opcao Invalida
     _linha 
     _mensagec YELLOW "$M08"
     _linha 
   
    fi
_ferramentas
}

#-Envia e receber arquivos-------------------------------------------------------------------------#
_envrecarq () { 
    clear
###-800-mensagens do Menu Envio e Retorno.
     M800="Menu de Enviar e Receber Arquivo(s)."
     M801="Escolha a opcao:"
     M802="1${NORM} - Enviar arquivo(s)     "
     M803="2${NORM} - Receber arquivo(s)    "
#     M804="3${NORM} - Enviar Avulso         "
#     M805="4${NORM} - Receber Avulso        "
     M806="9${NORM} - ${RED}Menu Anterior "
     M807=" Digite o numero da OPCAO desejada -> "
	 printf "\n"
	 _linha "="
	 _mensagec RED "$M800"
	 _linha 
	 printf "\n"
	 _mensagec PURPLE "$M801"
	 printf "\n"
	 _mensagec GREEN "$M802"
	 printf "\n"
	 _mensagec GREEN "$M803"
	 printf "\n"
#	 _mensagec GREEN "$M804"
#       printf "\n"
#	 _mensagec GREEN "$M805"
#        printf "\n"
	 _mensagec GREEN "$M806"
       printf "\n"       
	 _linha "="
     read -rp "${YELLOW}""$M807""${NORM}" OPCAO	
     case $OPCAO in
 #          1) _envia_arq       ;;
 #          2) _recebe_arq      ;;
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
 M991="1- Informe em que diretorio esta o arquivo a ser enviado :"   
      _mensagec YELLOW "$M991"  
      read -rp "${YELLOW}"" -> ""${NORM}" DIRENVIA
      _linha 
      local VERDIR=$DIRENVIA
      if [[ -d "$VERDIR" ]]; then
      printf "\n"
      else
      clear
      _meiodatela
M995="Diretorio não foi encontrado no servidor"
      _linha 
      _mensagec RED "$M995"  
      _linha 
       _press
      _envrecarq
      fi
      if [[ -z "$DIRENVIA" ]] ; then # testa variavel vazia
      local DIRENVIA=$ENVIA
           if ls -s "$DIRENVIA"/*.* ; then
#-Arquivo encontrado no diretorio
      printf "\n"
      _linha
      _mensagec YELLOW "$M28"
      _linha
           else
      M49="Arquivo nao encontrado no diretorio"
      _linha 
      _mensagec YELLOW "$M49"  
      _linha 
#      _press 
      _ferramentas  
           fi
      fi
      _linha 
      _mensagec CYAN "$M72" #Informe o arquivo(s) que deseja enviar.
      _linha      
      local EENVIA=" "
      read -rp "${YELLOW}""2- Informe nome do ARQUIVO: -> ""${NORM}" EENVIA
      if [[ -z "$EENVIA" ]] ;then 
  #   clear
      _meiodatela
      _mensagec RED "$M74"
      _press
      _envrecarq
      fi
     if [[ ! -e "$DIRENVIA""/""$EENVIA" ]];then
      _linha
       M49="$EENVIA Arquivo nao encontrado no diretorio"
      _linha 
      _mensagec YELLOW "$M49"  
      _linha 
      _press 
      _envrecarq  
      fi
      printf "\n"
      _linha 
 M992="3- Informe para qual diretorio no servidor:"   
      _mensagec YELLOW "$M992"  
      read -rp "${YELLOW}"" -> ""${NORM}" ENVBASE
      _linha 
      if [[ -z "$ENVBASE" ]] ;then
      _meiodatela
#M69  
      _mensagec RED "$M69"
      _press    
      _envrecarq 
      fi
	 
#-Informe a senha do usuario do scp
      _linha 
      _mensagec YELLOW "$M29"
      _linha 
      "$cmd_scp" -r -P "$PORTA" "$DIRENVIA"/"$EENVIA" "$USUARIO"@"$IPSERVER":"$ENVBASE" 
M15="Backup enviado para a pasta, \"""$ENVBASE""\"."
      _linha 
      _mensagec YELLOW "$M15"
      _linha 
      _read_sleep 3
      _envrecarq
}

##---recebe_avulso-------------------------------------
_recebe_avulso () {
      clear
      _linha 
 M993="1- Informe em qual diretorio esta o arquivo a ser RECEBIDO :"   
      _mensagec YELLOW "$M993"  
      read -rp "${YELLOW}"" -> ""${NORM}" RECBASE
      _linha 
      _linha 
      _mensagec RED "$M73"
      _linha      
      read -rp "${YELLOW}""    2- Informe nome do ARQUIVO: ""${NORM}" RRECEBE
      if [[ -z "$RRECEBE" ]] ;then 
      _meiodatela
      _mensagec RED "$M74"
      _press
      _envrecarq
      fi
      _linha 
       M994="3- Informe diretorio do servidor que vai receber arquivo: " 
      _mensagec YELLOW "$M994"  
     
     read -rp "${YELLOW}"" -> ""${NORM}" EDESTINO
      if [[ -z "$EDESTINO" ]] ; then # testa variavel vazia
      local EDESTINO=$RECEBE
      fi
      _linha 
      local VERDIR="$EDESTINO"
      if [[ -d "$VERDIR" ]]; then
      printf "\n"
      else
      clear
      _meiodatela
M995="Diretorio não foi encontrado no servidor"
      _linha 
      _mensagec RED "$M995"  
      _linha 
      _press
      _envrecarq
      fi
      
#-Informe a senha do usuario do scp
      _linha 
      _mensagec YELLOW "$M29"
      _linha 
      "$cmd_scp" -r -P "$PORTA" "$USUARIO"@"$IPSERVER":"$RECBASE""/""$RRECEBE" "$EDESTINO""/". 
M15="Arquivo enviado para a pasta, \"""$EDESTINO""\"."
      _linha 
      _mensagec YELLOW "$M15"
      _linha 
      _read_sleep 3
_envrecarq      
}

#-Limpando arquivos de atualizacao com mais de 30 dias --------------------------------------------#
_expurgador () {
    clear
#-Apagar Biblioteca--------------------------------------------------# 
     local DIR1="$BACKUP""/"
# Apagando todos os arquivos do diretorio #
     "$cmd_find" "$DIR1" . -type f -ctime +30 -exec rm -r {} \; >> "$LOG_LIMPA"
#     done
#-Apagar arquivos do diretorio olds----------------------------------#
     local DIR2="$OLDS""/"
     "$cmd_find" "$DIR2" -name "*.zip" -ctime +30 -exec rm -r {} \; >> "$LOG_LIMPA"

#-Apagar arquivos do diretorio progs---------------------------------#
     local DIR3="$PROGS""/"
     "$cmd_find" "$DIR3" -name "*.bkp" -ctime +30 -exec rm -r {} \; >> "$LOG_LIMPA"
    
#-Apagar arquivos do diretorio dos logs---------------------------------#
     local DIR4="$LOGS""/"
     "$cmd_find" "$DIR4" -name "*.log" -ctime +30 -exec rm -r {} \; 
     printf "\n"
#-Verificando e/ou excluido arquivos com mais de 30 dias criado.------#
     _linha 
     _mensagec RED "$M51"
     _linha 
     printf "\n\n"
cd "$TOOLS"/ || exit
#_press
_ferramentas

}

#-Atualizacao online-------------------------------------------------------------------------------#

_update () {
     clear
     printf "\n\n"
     _linha 
     _mensagec GREEN "$M91"
     _mensagec GREEN "$M92"
     _linha 
    cp atualiza.sh "$BACKUP"
    
    cd "$PROGS" || exit 
    wget -q -c https://github.com/Luizaugusto1962/Atualiza/archive/master/atualiza.zip || exit
     
#-Descompactando o programa baixado----------------------------------#

atualizagit="atualiza.zip"
     "$cmd_unzip" -o "$atualizagit" >> "$LOG_ATU"
     _read_sleep 1
     "$cmd_find" "$PROGS" -name "$atualizagit" -exec rm -r {} \; 
     cd "$PROGS"/Atualiza-main || exit
#-Atualizando somente o atualiza.sh----------------------------------#
     chmod +x "atualiza.sh"
     mv -f -- "atualiza.sh" "$TOOLS" >> "$LOG_ATU"
    
_press
exit   
}

_principal

unset RED GREEN YELLOW BLUE PURPLE CYAN NORM
unset BASE BASE2 BASE3 tools
unset destino pasta base base2 base3 logs exec class telas xml
unset olds progs backup sistema SAVATU1 SAVATU2 SAVATU3 SAVATU4
tput clear
tput sgr0
tput cup "$( tput lines )" 0
clear
