#!/usr/bin/env bash
#
#
#versao de 07/07/2025-00

clear

# Função para editar variável com prompt
editar_variavel() {
    local nome="$1"
    local valor_atual="${!nome}"

    read -rp "Deseja alterar ${nome} (valor atual: ${valor_atual})? [s/N] " alterar
    alterar=${alterar,,}
    if [[ "$alterar" =~ ^s$ ]]; then
        read -rp "Novo valor para ${nome}: " novo_valor
        eval "$nome=\"$novo_valor\""
    fi
}

# Se os arquivos existem, carrega e pergunta se quer editar campo a campo
if [[ -f ".atualizac" && -f ".atualizap" ]]; then
    echo "=================================================="
    echo "Arquivos .atualizac e .atualizap já existem."
    echo "Carregando parâmetros para edição..."
    echo "=================================================="
    echo

    # Carrega os valores existentes
    "." ./.atualizac

    # Edita sistema
    editar_variavel sistema

    # Edita verclass e atualiza class/mclass automaticamente
    editar_variavel verclass

    if [[ -n "$verclass" ]]; then
        verclass_sufixo="${verclass: -2}" # Pega os dois últimos dígitos
        class="-class${verclass_sufixo}"
        mclass="-mclass${verclass_sufixo}"
        echo "class e mclass foram atualizados automaticamente:"
        echo "class=${class}"
        echo "mclass=${mclass}"
    else
        editar_variavel class
        editar_variavel mclass
    fi

    editar_variavel BANCO
    editar_variavel destino
    editar_variavel SERACESOFF
    editar_variavel ENVIABACK
    editar_variavel EMPRESA
    editar_variavel base
    editar_variavel base2
    editar_variavel base3

    # Recria o arquivo com os novos valores
    echo "Recriando .atualizac com os novos parâmetros..."
    {
        echo "sistema=${sistema}"
        [[ -n "$verclass" ]] && echo "verclass=${verclass}"
        [[ -n "$class" ]] && echo "class=${class}"
        [[ -n "$mclass" ]] && echo "mclass=${mclass}"
        [[ -n "$BANCO" ]] && echo "BANCO=${BANCO}"
        [[ -n "$destino" ]] && echo "destino=${destino}"
        [[ -n "$SERACESOFF" ]] && echo "SERACESOFF=${SERACESOFF}"
        [[ -n "$ENVIABACK" ]] && echo "ENVIABACK=${ENVIABACK}"
        [[ -n "$EMPRESA" ]] && echo "EMPRESA=${EMPRESA}"
        [[ -n "$base" ]] && echo "base=${base}"
        [[ -n "$base2" ]] && echo "base2=${base2}"
        [[ -n "$base3" ]] && echo "base3=${base3}"
    } >.atualizac

    echo
    echo "Arquivo .atualizac atualizado com sucesso!"
    echo

    read -rp "Deseja continuar o restante da configuração normalmente? [s/N] " continuar
    continuar=${continuar,,}
    if [[ "$continuar" =~ ^n$ || "$continuar" == "" ]]; then
        echo "Finalizando o script por escolha do usuário."
        exit 0
    fi
    echo
    echo "Continuando o processo normal..."
    sleep 1
fi

clear
### Cria o bat se o servidor for em modo offline ------------------

_ATUALIZA_BAT() {
    {
        cat <<'EOF'
set "ipservidor=177.45.80.10"
set "port=41122"
set "user=atualiza"
set "line================================================"
set "op=0"

:: Solicita a senha ao usuário
echo %line%
echo.
set /p senha=Digite a senha para pscp: 
if "!senha!"=="" (
    echo.
    echo Senha nao pode ser vazio.
    echo %line%
	pause
    cls
    endlocal
    exit /b
)
:: Configuração da tela
mode con cols=60 lines=30
color 0e

:: Verifica se o pscp está instalado
where pscp >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %line%
    echo ERRO: pscp nao encontrado!
    echo Instale o pscp a partir de: https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe
    echo %line%
    pause
    exit /b
)

:: Remove arquivos .zip existentes
IF EXIST *.zip (
    echo %line%
    echo Arquivos .zip encontrados no diretorio.
    set /p confirm=Deseja excluir todos os arquivos .zip? [S/N]: 
    if /I "!confirm!"=="S" (
        del /Q *.zip
        echo Arquivos zip excluidos.
    ) else (
        echo Exclusao cancelada.
    )
) ELSE (
    echo %line%
    echo Diretorio sem arquivos zip.
)

:MENU
cls
echo %line%
echo.
echo Rotina para atualizar os programas da SAV
echo ou atualizar a biblioteca
echo Para servidor que nao tem acesso online
echo.
echo %line%
echo [1] - Atualizar programa
echo [2] - Atualizar Biblioteca
echo [3] - Atualiza o tools
echo [4] - Atualiza o pscp
echo [5] - Ajuda
echo [0] - Sair
echo.
set op=invalid
set /p op=Selecione a opcao [0-5]: 
echo.

if "!op!"=="0" goto EOF
if "!op!"=="1" goto Modo_compilado
if "!op!"=="2" goto Biblioteca
if "!op!"=="3" goto Tools
if "!op!"=="4" goto PSCP
if "!op!"=="5" goto HELP
echo Opcao invalida. Tente novamente.
pause
goto MENU

:HELP
cls
echo %line%
echo Ajuda - Rotina de Atualizacao SAV
echo %line%
echo Este script atualiza programas e bibliotecas da SAV.
echo - Opcao 1: Baixa programas compilados (Normal/Debug).
echo - Opcao 2: Baixa bibliotecas por versao.
echo - Opcao 3: Abre link para baixar tools.
echo - Opcao 4: Abre link para baixar pscp.
echo - Opcao 0: Sair do script.
echo.
echo Requisitos:
echo - pscp.exe instalado.
echo - Conexao com o servidor %ipservidor%.
echo %line%
pause
goto MENU

:Modo_compilado
set sn=invalid
echo %line%
echo Programa compilado em qual modo?
echo %line%
echo [1] - Normal
echo [2] - Debug
echo [0] - Voltar
echo.
set /p sn=Selecione a opcao [0-2]: 
echo.
if "!sn!"=="0" goto MENU
if "!sn!"=="1" goto NORMAL
if "!sn!"=="2" goto DEBUG
echo Opcao invalida. Tente novamente.
pause
goto Modo_compilado

:NORMAL
echo %line%
echo Informe o programa a ser baixado em "MAISCULO"
echo Somente o nome do programa sem ".zip":
echo %line%
set prog=
set /p prog=Nome do programa: 
if "!prog!"=="" (
    echo Nome do programa nao pode ser vazio.
    pause
    goto MENU
)
:: Basic validation for program name (no special chars)
echo %prog% | findstr /R "^[A-Z0-9]" >nul
if %ERRORLEVEL% neq 0 (
    echo Nome do programa invalido. Use apenas letras maiusculas, numeros.
    pause
    goto MENU
) 
call :Baixando_programa /u/varejo/man/%prog%%class%.zip
if %ERRORLEVEL% neq 0 (
    pause
)
goto OPCAO

:DEBUG
echo %line%
echo Informe o programa a ser baixado em "MAISCULO"
echo Somente o nome do programa sem ".zip":
echo %line%
set prog=
set /p prog=Nome do programa: 
if "!prog!"=="" (
    echo Nome do programa nao pode ser vazio.
    pause
    goto MENU
)
echo %prog% | findstr /R "^[A-Z0-9_]" >nul
if %ERRORLEVEL% neq 0 (
    echo Nome do programa invalido. Use apenas letras maiusculas, numeros e _.
    pause
    goto MENU
)
call :Baixando_programa /u/varejo/man/!prog!%mclass%.zip
if %ERRORLEVEL% neq 0 (
    pause
)
goto OPCAO

:Biblioteca
set "versao="
set /p versao=Numero da versao:

:: Verifica se a versao e um numero valido
set "valid=true"
for /f "tokens=* delims=0123456789" %%a in ("%versao%") do (
    if "%%a" neq "" set "valid=false"
)

if "%valid%"=="false" (
    echo Versao invalida. Por favor, insira um numero valido.
    pause
    goto Biblioteca
)

if "%versao%"=="" goto MENU
for %%v in (%SAVATU1% %SAVATU2% %SAVATU3% %SAVATU4%) do (
    call pscp -sftp -p -pw %senha% -P 41122 atualiza@%ipservidor%:/u/varejo/trans_pc/%%v%versao%.zip .
)
if %ERRORLEVEL% neq 0 (
    pause
)
goto MENU

:Tools
start chrome https://github.com/Luizaugusto1962/Atualiza/archive/master/atualiza.zip
goto MENU

:PSCP
start chrome https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe
goto MENU

:OPCAO
cls
set sn=invalid
echo %line%
echo Baixar mais algum programa da SAV?
echo %line%
echo [S] - Sim
echo [N] - Nao
echo.
set /p sn=Selecione a opcao [S/N]: 
echo.
if /I "!sn!"=="N" goto EOF
if /I "!sn!"=="S" goto Modo_compilado
echo Opcao invalida. Tente novamente.
pause
goto OPCAO

:: Função para baixar programas
:Baixando_programa
echo Baixando %1...
pscp -sftp -p -pw %senha% -P %port% %user%@%ipservidor%:%1 . >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Download concluido: %1
) else (
    echo ERRO: Falha ao baixar %1
    exit /b 1
)
exit /b 0

:EOF
:: Limpando variaveis
set sn=
set op=
set class=
set mclass=

set SAVATU1=
set SAVATU2=
set SAVATU3=
set SAVATU4=
set prog=
set versao=
set ipservidor=
set port=
set user=
set line=
set pwd=
cls
endlocal
exit /b
EOF
    } >>atualiza.bat
}

complemento=""
mcomplemento=""

linha="#-------------------------------------------------------------------#"
traco="#####################################################################"
###
echo ${traco}
echo ${traco} >.atualizac
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" >>.atualizac
echo "###      ( Parametros para serem usados no atualiza.sh )          ###"
echo ${traco} >>.atualizac
echo ${traco} >.atualizap
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" >>.atualizap
echo ${traco} >>.atualizap
_ISCOBOL() {
    sistema="iscobol"
    echo ${traco}
    echo "###           (CONFIGURACAO PARA O SISTEMA EM ISCOBOL)           ###"
    echo ${traco}
    echo "sistema=iscobol"
    echo "sistema=iscobol" >>.atualizac
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
    *)
        echo
        echo Alternativas incorretas, saindo!
        sleep 1
        exit
        ;;
    esac
    {
        echo "exec=sav/classes"
        echo "telas=sav/tel_isc"
        echo "xml=sav/xml"
        classA="IS${VERCLASS}""_*_" # Usanda esta variavel para baixar todos os zips da atualizacao.
        classB="IS${VERCLASS}""_classA_"
        classC="IS${VERCLASS}""_classB_"
        classD="IS${VERCLASS}""_tel_isc_"
        classE="IS${VERCLASS}""_xml_"
        echo "SAVATU=tempSAV_""${classA}"
        echo "SAVATU1=tempSAV_""${classB}"
        echo "SAVATU2=tempSAV_""${classC}"
        echo "SAVATU3=tempSAV_""${classD}"
        echo "SAVATU4=tempSAV_""${classE}"
    } >>.atualizap
}

# _2018
#
# Define as variaveis para o Iscobol da versao 2018.
#
# As variaveis class e mclass recebem seus valores para a versao 2018.
#
# A variavel VERCLASS recebe o valor 2018.
#
# As variaveis sao escritas no arquivo .atualizac.
_2018() {
    {
        complemento="-class"
        mcomplemento="-mclass"
        VERCLASS="2018"
        echo "verclass=${VERCLASS}"
        echo "class=-class"
        echo "mclass=-mclass"
    } >>.atualizac
}

# _2020
#
# Define as variaveis para o Iscobol da versao 2020.
#
# As variaveis class e mclass recebem seus valores para a versao 2020.
#
# A variavel VERCLASS recebe o valor 2020.
#
# As variaveis sao escritas no arquivo .atualizac.
_2020() {
    {
        complemento="-class20"
        mcomplemento="-mclass20"
        VERCLASS="2020"
        echo "verclass=${VERCLASS}"
        echo "class=-class20"
        echo "mclass=-mclass20"
    } >>.atualizac
}

# _2023
#
# Define as variaveis para o Iscobol da versao 2023.
#
# As variaveis class e mclass recebem seus valores para a versao 2023.
#
# A variavel VERCLASS recebe o valor 2023.
#
# As variaveis sao escritas no arquivo .atualizac.
_2023() {
    {
        complemento="-class23"
        mcomplemento="-mclass23"
        VERCLASS="2023"
        echo "verclass=${VERCLASS}"
        echo "class=-class23"
        echo "mclass=-mclass23"
    } >>.atualizac
}

# _2024
#
# Define as variaveis para o Iscobol da versao 2024.
#
# As variaveis class e mclass recebem seus valores para a versao 2024.
#
# A variavel VERCLASS recebe o valor 2024.
#
# As variaveis sao escritas no arquivo .atualizac.
_2024() {
    {
        complemento="-class24"
        mcomplemento="-mclass24"
        VERCLASS="2024"
        echo "verclass=${VERCLASS}"
        echo "class=-class24"
        echo "mclass=-mclass24"
    } >>.atualizac
}

# _COBOL
#
# Define as variaveis para o Micro Focus da versao COBOL.
#
# As variaveis class e mclass recebem seus valores para a versao COBOL.
#
# A variavel sistema recebe o valor COBOL.
#
# As variaveis sao escritas no arquivo .atualizac.
_COBOL() {
    sistema="cobol"
    {
        complemento="-6"
        mcomplemento="-m6"
        echo "sistema=cobol"
        echo "class=-6"
        echo "mclass=-m6"
    } >>.atualizac
    {
        echo "exec=sav/int"
        echo "telas=sav/tel"
        echo "SAVATU1=tempSAVintA_"
        echo "SAVATU2=tempSAVintB_"
        echo "SAVATU3=tempSAVtel_"
        echo "${linha}"
    } >>.atualizap
}

echo "  Em qual sistema que o SAV esta rodando "
echo "1) Iscobol"
echo
echo "2) Microfocus"
echo
read -n1 -rp "Escolha o sistema " escolha
case ${escolha} in
1)
    echo ") Iscobol"
    _ISCOBOL
    ;;
2)
    echo ") Microfocus"
    _COBOL
    ;;
*)
    echo
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
    echo "BANCO=n" >>.atualizac
else
    [[ "${BANCO}" =~ ^[Ss]$ ]]
    echo "BANCO=s" >>.atualizac
fi
declare -l DIR
echo "###              ( PASTA DO SISTEMA )         ###"
read -rp " Informe o diretorio raiz sem o /->" -n1 DIR
echo
echo destino="${DIR}" >>.atualizac
echo ${linha}
declare -l OFF
echo "###          Tipo de acesso                  ###"
read -rp "Servidor OFF [S ou N] ->" -n1 OFF
echo
if [[ "${OFF}" =~ ^[Nn]$ ]] || [[ "${OFF}" == "" ]]; then
    echo "SERACESOFF=" >>.atualizac
elif [[ "${OFF}" =~ ^[Ss]$ ]]; then
    echo "SERACESOFF=/sav/portalsav/Atualiza" >>.atualizac
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
        echo "ENVIABACK=""" >>.atualizac
    else
        echo "ENVIABACK=/sav/portalsav/Atualiza"
        echo "ENVIABACK=/sav/portalsav/Atualiza" >>.atualizac
    fi
else
    echo "ENVIABACK=cliente/""${PASTA}"
    echo "ENVIABACK=cliente/""${PASTA}" >>.atualizac
fi
echo ${linha}
declare -u EMPR
echo "###           ( NOME DA EMPRESA )            ###"
echo "###   Nao pode ter espacos entre os nomes    ###"
echo ${linha}
read -rp "Nome da Empresa-> " EMPR
echo
echo EMPRESA="${EMPR}"
echo EMPRESA="${EMPR}" >>.atualizac
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
    echo "base=/""${BASE}" >>.atualizac
    echo "base=/""${BASE}"
fi

echo ${linha}
read -rp "Nome de pasta da base2, Ex: sav/dados_? -:> " BASE2
if [[ "${BASE2}" == "" ]]; then
    echo "#base2=" >>.atualizac
    echo "#base2="
else
    echo "base2=/""${BASE2}" >>.atualizac
    echo "base2=/""${BASE2}"
fi
echo ${linha}

read -rp "Nome de pasta da base3, Ex: sav/dados_? -:> " BASE3
if [[ "${BASE3}" == "" ]]; then
    echo "#base3=" >>.atualizac
    echo "#base3="
else
    echo "base3=/""${BASE3}" >>.atualizac
    echo "base3=/""${BASE3}"
fi
echo ${linha}
echo ${linha} >>.atualizac
clear

{
    echo "pasta=/sav/tools"
    echo "progs=/progs"
    echo "olds=/olds"
    echo "logs=/logs"
    echo "backup=/backup"
    echo ${linha}
} >>.atualizap

if [[ "${OFF}" =~ ^[Ss]$ ]]; then
    if [[ "${sistema}" = "cobol" ]]; then
        {
            echo "@echo off"
            echo "cls"
            echo "setlocal EnableDelayedExpansion"
            echo
            echo ":: Configuracoes"
            echo "set class=""${complemento}"
            echo "set mclass=""${mcomplemento}"
            echo "set SAVATU1=tempSAVintA_"
            echo "set SAVATU2=tempSAVintB_"
            echo "set SAVATU3=tempSAVtel_"
        } >atualiza.bat
    else
        {
            echo "@echo off"
            echo "cls"
            echo "setlocal EnableDelayedExpansion"
            echo
            echo ":: Configuracoes"
            echo "set class=""${complemento}"
            echo "set mclass=""${mcomplemento}"
            echo "set SAVATU1=tempSAV_${classB}"
            echo "set SAVATU2=tempSAV_${classC}"
            echo "set SAVATU3=tempSAV_${classD}"
            echo "set SAVATU4=tempSAV_${classE}"
        } >atualiza.bat
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
