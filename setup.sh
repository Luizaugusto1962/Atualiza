#!/usr/bin/env bash 
# shellcheck disable=SC1017
#versao de 13/01/2025
clear
### Cria o bat se o servidor for em modo offline ------------------

_ATUALIZA_BAT () {
    {
    cat << 'EOF'
@echo off
cls
mode con cols=60 lines=30
color 0e
set op=0  
set "line================================================"
IF EXIST *.zip (
    del /Q  *.zip
    echo %line%
    echo arquivos zip excluidos
) ELSE (
    echo %line%
    echo Diretorio sem arquivos zip
)    
:MENU
cls
echo %line% 
echo.
echo Rotina para atualizar os programas da SAV.
echo ou atualizar a biblioteca
echo Para servidor que nao tem acesso online
echo.
echo %line% 

echo    [1] - Atualizar programa 
echo    [2] - Atualizar Biblioteca
echo    [3] - Atualiza o tools
echo    [4] - Atualiza o pscp
echo    [0] - Sair     
echo.
set /p op=Selecione a opcao ... 
echo.
if %op% equ 1 goto:Modo_compilado
if %op% equ 2 goto:Biblioteca
if %op% equ 3 goto:Tools
if %op% equ 4 goto:PSCP
if %op% equ 0 goto:EOF

:OPCAO
clear
set sn=0
echo %line% 
echo Baixar mais algum programa da SAV.
echo %line% 
echo	[S]- Sim [N]- Nao     
echo.
set /p sn=Selecione a opcao ... 
echo.
if %sn% equ N goto EOF
if %sn% equ S goto Modo_compilado

:Modo_compilado
set sn=""
echo %line% 
echo Programa compilado em qual modos? :
echo %line% 
echo	[N]- Normal [D]- Debug     
echo.
set /p sn=Selecione a opcao ... 
echo.
if %sn% equ 0 goto EOF
if %sn% equ N goto NORMAL 
if %sn% equ D goto DEBUG

:NORMAL
echo.
echo %line% 
echo Informe o programa a ser baixado em "MAISCULO"
echo somente o nome do programa sem  ".zip" :
echo %line%
set prog=""
set /p prog=Nome do programa: 
if "%prog%" == "" goto MENU
call pscp -sftp -p -pw %1 -P 41122 atualiza@177.115.194.15:/u/varejo/man/%prog%%class%.zip .
goto OPCAO

:DEBUG
echo.
echo %line% 
echo Informe o programa a ser baixado em "MAISCULO"
echo somente o nome do programa sem  ".zip" :
echo %line%
set prog=""
set /p prog=Nome do programa: 
if "%prog%" == "" goto MENU
call pscp -sftp -p -pw %1 -P 41122 atualiza@177.115.194.15:/u/varejo/man/%prog%%mclass%.zip .
goto OPCAO

:Biblioteca
echo Informe qual versao vai ser baixada
echo %line%
set versao=""
set /p versao=Numero da versao: 
if "%versao%" == "" goto MENU
call pscp -sftp -p -pw %1 -P 41122 atualiza@177.115.194.15:/u/varejo/trans_pc/%SAVATU1%%versao%.zip .
call pscp -sftp -p -pw %1 -P 41122 atualiza@177.115.194.15:/u/varejo/trans_pc/%SAVATU2%%versao%.zip .
call pscp -sftp -p -pw %1 -P 41122 atualiza@177.115.194.15:/u/varejo/trans_pc/%SAVATU3%%versao%.zip .
call pscp -sftp -p -pw %1 -P 41122 atualiza@177.115.194.15:/u/varejo/trans_pc/%SAVATU4%%versao%.zip .
goto MENU

:Tools
start chrome https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip
goto MENU

:PSCP
start chrome https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe" 
goto MENU

:EOF
set sn=""
set op=""
set class=""
set mclass=""
set SAVATU1=""
set SAVATU2=""
set SAVATU3=""
set SAVATU4=""
cls

exit /b
EOF
    } >> atualiza.bat 
}

class=""                                                        
mclass=""

linha="#-------------------------------------------------------------------#"
traco="#####################################################################"
###
echo ${traco}
echo ${traco} > atualizac
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" >> atualizac
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" 
echo ${traco} >> atualizac
echo ${traco} > atualizap
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" >> atualizap
echo ${traco} >> atualizap
_ISCOBOL () {
    echo ${traco}           
    echo "###           (CONFIGURACAO PARA O SISTEMA EM ISCOBOL)           ###"
    echo ${traco}
    echo "sistema=iscobol"
    echo "sistema=iscobol" >> atualizac
    echo ${linha}
    echo "Escolha a versao do Iscobol"
    echo
    echo "1- Versao 2018"
    echo
    echo "2- Versao 2020"
    echo
    echo "3- Versao 2023"
    echo
    echo "4- Versao 2024"
    echo
    read -rp "Escolha a versão -> " -n1 VERSAO 
    echo
    case ${VERSAO} in
        1) _2018 ;;
        2) _2020 ;;
        3) _2023 ;;
        4) _2024 ;;
        *) echo
            echo Alternativas incorretas, saindo!
            sleep 1
            exit
            ;;
    esac
    {
        echo "exec=sav/classes" 
        echo "telas=sav/tel_isc"
        echo "xml=sav/xml" 
        classA="${VERCLASS}""_classA_"
        classB="${VERCLASS}""_classB_"
        classC="${VERCLASS}""_tel_isc_"
        classD="${VERCLASS}""_xml_"
        echo "SAVATU1=tempSAV_""${classA}"
        echo "SAVATU2=tempSAV_""${classB}"
        echo "SAVATU3=tempSAV_""${classC}"
        echo "SAVATU4=tempSAV_""${classD}"
    } >> atualizap
}

# _2018
#
# Define as variaveis para o Iscobol da versao 2018.
#
# As variaveis class e mclass recebem seus valores para a versao 2018.
#
# A variavel VERCLASS recebe o valor IS2018.
#
# As variaveis sao escritas no arquivo atualizac.
_2018 () {
    {
class="-class"
mclass="-mclass"
VERCLASS="IS2018"        
echo "class=-class"
echo "mclass=-mclass"
    } >> atualizac
} 

# _2020
#
# Define as variaveis para o Iscobol da versao 2020.
#
# As variaveis class e mclass recebem seus valores para a versao 2020.
#
# A variavel VERCLASS recebe o valor IS2020.
#
# As variaveis sao escritas no arquivo atualizac.
_2020 () {
    {
class="-class20"   
mclass="-mclass20"                                                      
VERCLASS="IS2020"
echo "class=-class20"   
echo "mclass=-mclass20"                                                      
    } >> atualizac      
}

# _2023
#
# Define as variaveis para o Iscobol da versao 2023.
#
# As variaveis class e mclass recebem seus valores para a versao 2023.
#
# A variavel VERCLASS recebe o valor IS2023.
#
# As variaveis sao escritas no arquivo atualizac.
_2023 () {
    {
class="-class23"                                                        
mclass="-mclass23"
VERCLASS="IS2023"  
echo "class=-class23"                                                        
echo "mclass=-mclass23"
    } >> atualizac
}

# _2024
#
# Define as variaveis para o Iscobol da versao 2024.
#
# As variaveis class e mclass recebem seus valores para a versao 2024.
#
# A variavel VERCLASS recebe o valor IS2024.
#
# As variaveis sao escritas no arquivo atualizac.
_2024 () {
    {
class="-class24"                                                        
mclass="-mclass24"
VERCLASS="IS2024"  
echo "class=-class24"                                                        
echo "mclass=-mclass24"
    } >> atualizac
}

# _COBOL
#
# Define as variaveis para o COBOL.
#
# As variaveis class e sistema recebem seus valores para o COBOL.
#
# As variaveis sao escritas no arquivo atualizac.
#
# A variavel exec recebe o valor sav/int.
#
# A variavel telas recebe o valor sav/tel.
#
# A variavel SAVATU1 recebe o valor tempSAVintA_.
#
# A variavel SAVATU2 recebe o valor tempSAVintB_.
#
# A variavel SAVATU3 recebe o valor tempSAVtel_.
_COBOL () {
    {
        echo "sistema=cobol"
        echo "class=-6"
    } >> atualizac
    {
    echo "exec=sav/int" 
    echo "telas=sav/tel"
    echo "SAVATU1=tempSAVintA_"
    echo "SAVATU2=tempSAVintB_" 
    echo "SAVATU3=tempSAVtel_" 
    echo ${linha}
    } >> atualizap
}

echo "  Em qual sistema que o SAV esta rodando " 
echo "1) Iscobol" 
echo 
echo "2) Microfocus"
echo
read -n1 -rp "Escolha o sistema " escolha
case ${escolha} in
    1) echo ") Iscobol" ; _ISCOBOL 
    ;;
    2) echo ") Microfocus" ; _COBOL 
    ;;
    *)  echo
		echo Alternativas incorretas, saindo!
		sleep 1
		exit
	;;
esac 
clear
declare -l BANCO
echo ${traco}
echo "###           ( Banco de Dados )                               ###"
read -rp " ( Sistema em banco de dados [S/N]  ->" -n1 BANCO 
echo
echo ${linha}
    if [[ "${BANCO}" =~ ^[Nn]$ ]] || [[ "${BANCO}" == "" ]]; then
        echo "BANCO=n" >> atualizac
    else [[ "${BANCO}" =~ ^[Ss]$ ]];
        echo "BANCO=s" >> atualizac
    fi
declare -l DIR
echo "###              ( PASTA DO SISTEMA )         ###" 
read -rp " Informe o diretorio raiz ->" -n1 DIR 
echo 
echo destino="/${DIR}" >> atualizac
echo ${linha} 
declare -l OFF
echo "###          Tipo de acesso                  ###"
read -rp "Servidor OFF [S ou N] ->" -n1 OFF 
echo
if [[ "${OFF}" =~ ^[Nn]$ ]] || [[ "${OFF}" == "" ]]; then
        echo "SERACESOFF="""  >> atualizac
elif [[ "${OFF}" =~ ^[Ss]$ ]]; then
        echo "SERACESOFF=/sav/portalsav/Atualiza"  >> atualizac
fi
echo ${linha} 
declare -l PASTA
echo "###          ( Nome de pasta no servidor da SAV )                ###"
echo "Nome de pasta no servidor da SAV, informar somento e pasta do cliente"
read -rp "/cliente/" PASTA 
echo 
if [[ "${PASTA}" == "" ]]; then
    if [[ "${OFF}" =~ ^[Nn]$ ]] || [[ "${OFF}" == "" ]]; then
        echo "ENVIABACK="""
        echo "ENVIABACK=""" >> atualizac
    else
    echo "ENVIABACK=/sav/portalsav/Atualiza"
    echo "ENVIABACK=/sav/portalsav/Atualiza" >> atualizac
    fi
else
    echo "ENVIABACK=cliente/""${PASTA}"
    echo "ENVIABACK=cliente/""${PASTA}"  >> atualizac
fi
echo ${linha} 
declare -u EMPR
echo "###           ( NOME DA EMPRESA )            ###"
echo ${linha}
read -rp "Nome da Empresa-> " EMPR 
echo 
echo EMPRESA="${EMPR}"
echo EMPRESA="${EMPR}" >> atualizac
echo ${linha}
echo "###    ( DIRETORIO DA BASE DE DADOS )        ###"
echo ${linha}
declare -l BASE
declare -l BASE2
declare -l BASE3
read -rp "Nome de pasta da base, Ex: sav/dados_? -:> " BASE 
if [[ "${BASE}" == "" ]]; then
echo "Necessario pasta informar a base de dados" 
exit
else
echo "base=/""${BASE}" >> atualizac
echo "base=/""${BASE}" 
fi

echo ${linha}
read -rp "Nome de pasta da base2, Ex: sav/dados_? -:> " BASE2 
if [[ "${BASE2}" == "" ]]; then
echo "#base2=" >> atualizac
echo "#base2="
else
echo "base2=/""${BASE2}" >> atualizac
echo "base2=/""${BASE2}"
fi
echo ${linha}

read -rp "Nome de pasta da base3, Ex: sav/dados_? -:> " BASE3
if [[ "${BASE3}" == "" ]]; then
echo "#base3=" >> atualizac
echo "#base3="
else
echo "base3=/""${BASE3}" >> atualizac
echo "base3=/""${BASE3}"
fi
echo ${linha}
echo ${linha} >> atualizac
clear   

{
echo "pasta=/sav/tools"
echo "progs=/progs" 
echo "olds=/olds" 
echo "logs=/logs" 
echo "backup=/backup" 
echo ${linha}
} >> atualizap

if [[ "${OFF}" =~ ^[Ss]$ ]]; then
    {
        echo "@echo off"
        echo "set class=\"${class}\""
        echo "set mclass=\"${mclass}\""
        echo "set SAVATU1=tempSAV_\"${classA}\""
        echo "set SAVATU2=tempSAV_\"${classB}\""
        echo "set SAVATU3=tempSAV_\"${classC}\""
        echo "set SAVATU4=tempSAV_\"${classD}\""
    } > atualiza.bat
    
    # Check if the batch file was created successfully
    if [[ -f "atualiza.bat" ]]; then
        _ATUALIZA_BAT
    else
        echo "Falhou ao criar o arquivo atualiza.bat." >&2
        exit 1
    fi
fi

echo "Pronto !!!"
