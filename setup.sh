#!/usr/bin/env bash 
#
#
#versao de 24/03/2025

clear
### Cria o bat se o servidor for em modo offline ------------------

_ATUALIZA_BAT () {
    {
    cat << 'EOF'
mode con cols=60 lines=30
color 0e
set op=0  
set ipservidor=177.45.80.10
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
cls
set sn=0
echo %line% 
echo Baixar mais algum programa da SAV.
echo %line% 
echo	[S]- Sim [N]- Nao     
echo.
set /p sn=Selecione a opcao ... 
echo.
if /I %sn% equ N goto EOF
if /I %sn% equ S goto Modo_compilado

:Modo_compilado
set sn=""
echo %line% 
echo Programa compilado em qual modo ? :
echo %line% 
echo	[1]- Normal [2]- Debug     
echo.
set /p sn=Selecione a opcao ... 
echo.
if %sn% == 0 goto EOF
if %sn% == 1 goto NORMAL 
if %sn% == 2 goto DEBUG

:NORMAL
echo.
echo %line% 
echo Informe o programa a ser baixado em "MAISCULO"
echo somente o nome do programa sem  ".zip" :
echo %line%
set prog=""
set /p prog=Nome do programa: 
if "%prog%" == "" goto MENU
call pscp -sftp -p -pw %1 -P 41122 atualiza@%ipservidor%:/u/varejo/man/%prog%%class%.zip .
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
call pscp -sftp -p -pw %1 -P 41122 atualiza@%ipservidor%:/u/varejo/man/%prog%%mclass%.zip .
goto OPCAO

:Biblioteca
echo Informe qual versao vai ser baixada
echo %line%
set versao=""
set /p versao=Numero da versao: 
if "%versao%" == "" goto MENU
call pscp -sftp -p -pw %1 -P 41122 atualiza@%ipservidor%:/u/varejo/trans_pc/%SAVATU1%%versao%.zip .
call pscp -sftp -p -pw %1 -P 41122 atualiza@%ipservidor%:/u/varejo/trans_pc/%SAVATU2%%versao%.zip .
call pscp -sftp -p -pw %1 -P 41122 atualiza@%ipservidor%:/u/varejo/trans_pc/%SAVATU3%%versao%.zip .
call pscp -sftp -p -pw %1 -P 41122 atualiza@%ipservidor%:/u/varejo/trans_pc/%SAVATU4%%versao%.zip .
goto MENU

:Tools
start chrome https://github.com/Luizaugusto1962/Atualiza/archive/master/atualiza.zip
goto MENU

:PSCP
start chrome https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe" 
goto MENU

:EOF
set sn=""
set op=""
set class=""
set mclass=""
set SAVATU0=""
set SAVATU1=""
set SAVATU2=""
set SAVATU3=""
set SAVATU4=""
cls

exit /b
EOF
    } >> atualiza.bat 
}

complemento=""                                                        
mcomplemento=""

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
    sistema="iscobol"
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
        classA="${VERCLASS}""_*_" # Usanda esta variavel para baixar todos os zips da atualizacao.
        classB="${VERCLASS}""_classA_"
        classC="${VERCLASS}""_classB_"
        classD="${VERCLASS}""_tel_isc_"
        classE="${VERCLASS}""_xml_"
        echo "SAVATU=tempSAV_""${classA}" 
        echo "SAVATU1=tempSAV_""${classB}"
        echo "SAVATU2=tempSAV_""${classC}"
        echo "SAVATU3=tempSAV_""${classD}"
        echo "SAVATU4=tempSAV_""${classE}"
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
complemento="-class"
mcomplemento="-mclass"
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
complemento="-class20"   
mcomplemento="-mclass20"                                                      
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
complemento="-class23"                                                        
mcomplemento="-mclass23"
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
complemento="-class24"                                                        
mcomplemento="-mclass24"
VERCLASS="IS2024"  
echo "class=-class24"                                                        
echo "mclass=-mclass24"
    } >> atualizac
}


# _COBOL
#
# Define as variaveis para o Micro Focus da versao COBOL.
#
# As variaveis class e mclass recebem seus valores para a versao COBOL.
#
# A variavel sistema recebe o valor COBOL.
#
# As variaveis sao escritas no arquivo atualizac.
_COBOL () {
sistema="cobol"    
    {
complemento="-6"
mcomplemento="-m6"
echo "sistema=cobol"
echo "class=-6"
echo "mclass=-m6"
    } >> atualizac
    {
    echo "exec=sav/int" 
    echo "telas=sav/tel"
    echo "SAVATU1=tempSAVintA_"
    echo "SAVATU2=tempSAVintB_" 
    echo "SAVATU3=tempSAVtel_" 
    echo "${linha}"
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
read -rp " Informe o diretorio raiz sem o /->" -n1 DIR 
echo 
echo destino="${DIR}" >> atualizac
echo ${linha} 
declare -l OFF
echo "###          Tipo de acesso                  ###"
read -rp "Servidor OFF [S ou N] ->" -n1 OFF 
echo
if [[ "${OFF}" =~ ^[Nn]$ ]] || [[ "${OFF}" == "" ]]; then
        echo "SERACESOFF=" >> atualizac
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
    if [[ "${sistema}" = "cobol" ]]; then
    {
        echo "@echo off"
        echo "cls"
        echo "set class=""${complemento}"
        echo "set mclass=""${mcomplemento}"
        echo "set SAVATU1=tempSAVintA_"
        echo "set SAVATU2=tempSAVintB_"
        echo "set SAVATU3=tempSAVtel_"
    } > atualiza.bat
    else
    {
        echo "@echo off"
        echo "cls"
        echo "set class=""${complemento}"
        echo "set mclass=""${mcomplemento}"
        echo "set SAVATU1=tempSAV_${classA}"
        echo "set SAVATU2=tempSAV_${classB}"
        echo "set SAVATU3=tempSAV_${classC}"
        echo "set SAVATU4=tempSAV_${classD}"
    } > atualiza.bat
    fi
    # Check if the batch file was created successfully
    if [[ -f "atualiza.bat" ]]; then
        _ATUALIZA_BAT
    else
        echo "Falhou ao criar o arquivo atualiza.bat." >&2
        exit 1
    fi
fi

echo "Pronto !!!"
