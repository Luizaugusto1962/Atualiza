#!/bin/bash
# shellcheck disable=SC2016
clear
linha="#-------------------------------------------------------------------#"
traco="#####################################################################"
declare -l BANCO
echo $traco
echo $traco > atualizac
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" >> atualizac
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" 
echo $traco >> atualizac
echo "###           ( USA BANCO (S/N) )                                 ###"
echo $linha
read -rp "      ( USA BANCO (S/N)  -> " -n1 BANCO 
echo
echo $linha
    if [[ "$BANCO" =~ ^[Nn]$ ]] || [[ "$BANCO" == "" ]]; then
        echo "BANCO=n" >> atualizac
    elif [[ "$CONT" =~ ^[Ss]$ ]]; then
        echo "BANCO=s" >> atualizac
    fi
declare -l DIR
echo "###              ( PASTA DO SISTEMA )         ###" 
read -rp "      Informe o diretorio raiz -> " DIR 
echo destino="/$DIR" >> atualizac
echo $linha 
declare -l OFF
echo "###          Tipo de acesso                  ###"
read -rp "Servidor em modo OFFLINE S ou N ->" -n1 OFF 
echo
if [[ "$OFF" =~ ^[Nn]$ ]] || [[ "$OFF" == "" ]]; then
        echo "#SERACESOFF=/sav/portalsav/Atualiza"  >> atualizac
elif [[ "$OFF" =~ ^[Ss]$ ]]; then
        echo "SERACESOFF=/sav/portalsav/Atualiza"  >> atualizac
fi
echo $linha 
declare -l PASTA
echo "###          ( Nome de pasta no servidor da SAV )                ###"
echo "Nome de pasta no servidor da SAV, informar somento e pasta do cliente"
echo $linha
read -rp "/cliente/" PASTA 
echo $linha 
if [[ "$PASTA" == "" ]]; then
    echo "ENVIABACK=/sav/portalsav/Atualiza"
    echo "ENVIABACK=/sav/portalsav/Atualiza" >> atualizac
else
    echo "ENVIABACK=/cliente/""$PASTA"
    echo "ENVIABACK=/cliente/""$PASTA"  >> atualizac
fi
echo $linha 
declare -u EMPR
echo "###           ( NOME DA EMPRESA )            ###"
echo $linha
read -rp "      Nome da Empresa-> " EMPR 
echo $linha 
echo EMPRESA="$EMPR"
echo EMPRESA="$EMPR" >> atualizac
echo $linha
echo "###    ( DIRETORIO DA BASE DE DADOS 1 )        ###"
echo $linha
declare -l BASE
declare -l BASE2
declare -l BASE3
read -rp "Nome de pasta da base de dados Ex: /sav/dados_? -:>" BASE 
if [[ "$BASE" == "" ]]; then
echo "Necessario pasta informar a base de dados" 
exit
else
echo "base=""$BASE"
echo "base=""$BASE" >> atualizac
fi
echo $linha
echo "###    ( DIRETORIO DA BASE DE DADOS 2 )         ###"
echo $linha
read -rp "Nome de pasta da base2, Ex: /sav/dados_? -:>" BASE2 
if [[ "$BASE2" == "" ]]; then
echo "#base2=" >> atualizac
echo "#base2="
else
echo "base2=""$BASE2" 
echo "base2=""$BASE2" >> atualizac
fi
echo $linha
echo "###    ( DIRETORIO DA BASE DE DADOS 3 )        ###"
echo $linha
read -rp "Nome de pasta da base3, Ex: /sav/dados_? -:>" BASE3
if [[ "$BASE3" == "" ]]; then
echo "#base3="
echo "#base3=" >> atualizac
else
echo "base3=""$BASE3"
echo "base3=""$BASE3" >> atualizac
fi
echo $linha
clear   

echo $traco > atualizap
{
echo "###      ( Parametros para serem usados no atualiza.sh )          ###" 
echo $traco 
echo "###            ( Diretorio de trabalho do atualizador )           ###" 
echo $linha 
echo "pasta=/sav/tools"
echo "progs=/progs" 
echo "olds=/olds" 
echo "logs=/logs" 
echo "backup=/backup" 
} >> atualizap

_ISCOBOL () {
echo $traco           
echo "###           (CONFIGURACAO PARA O SISTEMA EM ISCOBOL)           ###"
echo $traco
echo "sistema=iscobol"
echo "sistema=iscobol" >> atualizac
echo $linha
echo "Escolha a versao do Iscobol"
echo
echo "      1- Versao 2018"
echo
echo "      2- Versao 2020"
echo
echo "      3- Versao 2023"
echo
echo "      4- Versao 2024"
echo
read -rp "      Escolha a versão -> " -n1 VERSAO 
echo
case $VERSAO in
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
}

_2018 () {
echo "class=-class" >> atualizac                                                       
echo "VERCLASS=IS2018" >> atualizac       
_PARISCOBOL
}

_2020 () {
echo "class=-class20" >> atualizac                                                       
echo "VERCLASS=IS2020" >> atualizac       
_PARISCOBOL
}

_2023 () {
echo "class=-class23" >> atualizac                                                       
echo "VERCLASS=IS2023" >> atualizac  
_PARISCOBOL     
}

_2024 () {
    echo "class=-class24" >> atualizac                                                       
    echo "VERCLASS=IS2024" >> atualizac       
    _PARISCOBOL
    }

_PARISCOBOL () {
    echo "exec=/sav/classes" 
    echo "telas=/sav/tel_isc"
    echo "xml=/sav/xml" 
    classA='"$VERCLASS"'"_classA_"
    classB='"$VERCLASS"'"_classB_"
    classC='"$VERCLASS"'"_tel_isc_"
    classD='"$VERCLASS"'"_xml_"
    echo "SAVATU1=tempSAV_""$classA"
    echo "SAVATU2=tempSAV_""$classB"
    echo "SAVATU3=tempSAV_""$classC"
    echo "SAVATU4=tempSAV_""$classD"
    echo $linha 
} >> atualizap

_COBOL () { 
    {
    echo "sistema=cobol" 
    echo "class=-6" 
    } >> atualizac
    {
    echo "exec=/sav/int" 
    echo "telas=/sav/tel"
    echo "SAVATU1=tempSAVintA_"
    echo "SAVATU2=tempSAVintB_" 
    echo "SAVATU3=tempSAVtel_" 
    echo $traco
    } >> atualizap
}

echo "Qual sistema que o SAV esta rodando" 
echo $linha
echo "1) Iscobol" 
echo 
echo "2) Microfocus"
echo
read -n1 -rp "Escolha o sistema " escolha
case $escolha in
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
echo "      Pronto !!!"
