@echo off
cls
mode con cols=60 lines=30
color 0e
set op=0
set class=class23
del /Q  *.zip
set "line============================================"
echo %line% 
echo.
echo Rotina para atualizar os programas da SAV.
echo Para servidor que nao tem acesso online
echo %line% 
echo	[1]- Atualizar programa [0]- Sair     
echo.
set /p op=Selecione a opcao ... 
echo.
if %op% equ 1 goto:Atualiza
if %op% equ 0 goto:EOF

:OPCAO
set sn=0
echo %line% 
echo Baixar mais algum programa da SAV.
echo %line% 
echo	[1]- Sim [0]- Nao     
echo.
set /p sn=Selecione a opcao ... 
echo.
if %sn% equ 0 goto EOF
if %sn% equ 1 goto Atualiza

:Atualiza
echo.
echo %line% 
echo Informe o programa a ser baixado 
echo somente o nome do programa sem  ".zip" :
echo %line%
goto Programa 

:Programa
set prog=""
set /p prog=Nome do programa: 
call pscp -sftp -p -pw ATUALIZA -P 41122 atualiza@177.115.194.15:/u/varejo/man/%prog%-%class%.zip .
goto OPCAO

:EOF
exit /b
cls
