#!/usr/bin/env bash
set -u
echo "== T1: read -rt N <> <(:) pausa mesmo? =="
inicio=$SECONDS
read -rt 3 <> <(:) || :
echo "decorrido=$((SECONDS - inicio))s (esperado: ~3s se pausar, ~0s se bug)"

echo "== T2: posicionamento de _aguardar_tecla (margem com +) =="
colunas=80; len=45
echo "com +: inicio=$(( (colunas + len) / 2 )) fim=$(( (colunas + len) / 2 + len )) (estoura ${colunas} colunas?)"
echo "com -: inicio=$(( (colunas - len) / 2 )) fim=$(( (colunas - len) / 2 + len ))"

echo "== T3: (( )) || (( )) sob set -e com OpenSSH 5.x =="
bash -ec 'maior=5; menor=3
(( maior > 7 )) || (( maior == 7 && menor >= 6 ))
printf "aceitou\n"' 2>&1
echo "exit=$?"

echo "== T4: mesmo padrao dentro de \$( ) (como _ssh_aceitar_novo e chamada) =="
bash -ec 'maior=5; menor=3
v=$( (( maior > 7 )) || (( maior == 7 && menor >= 6 )); printf "no" )
echo "v=$v rc-dentro-subshell=?"' 2>&1
echo "exit=$?"

echo "== T5: chamada real de funcao com o padrao, fora de \$() =="
bash -ec '
f() {
    local maior=5 menor=3
    (( maior > 7 )) || (( maior == 7 && menor >= 6 ))
    printf "no\n"
}
r=$(f)
echo "r=$r"' 2>&1
echo "exit=$?"
