#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
# SC2034/SC2154: varias variaveis daqui (LOG_TMP, PERM_DIR_SECURE,
# CFG_VERSAOCLASS, arquivo_senhas, ...) sao consumidas pelos modulos que este
# arquivo carrega com `source`, nao pelo proprio script. Sem esta diretiva a
# verificacao acusaria uso falso em 8 pontos.
set -euo pipefail
#
# testes/test_auth.sh - verificacoes isoladas de binarios/auth.sh
#
# O login e o cadastro nao tem como ser exercitados pelo menu sem TTY e sem
# senha valida. Este arquivo cobre a logica pura de autenticacao (rate
# limiting, formato de hash, gravacao de .senhas) mais o contrato entre
# cadastro.sh e _alterar_senha. Rodar direto, sem TTY:
#   bash testes/test_auth.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# utils.sh usa as cores ja no proprio source (label _aviso em utils.sh:79).
: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

# auth.sh e sourced (nunca executado) e liga o strict mode neste shell.
# shellcheck source=../binarios/utils.sh
. "${RAIZ_TESTE}/binarios/utils.sh"

falhas=0
_checar() { # _checar <descricao> <esperado> <obtido>
    if [[ "$2" == "$3" ]]; then
        printf 'ok    - %s\n' "$1"
    else
        printf 'FALHA - %s\n         esperado: [%s]\n         obtido:   [%s]\n' "$1" "$2" "$3"
        falhas=$((falhas + 1))
    fi
}

_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

# Retorna "sim"/"nao" conforme o codigo de retorno do comando recebido. Evita
# o `cmd && printf 1 || printf 0`, em que o esperado invertido passa despercebido.
_booleano() {
    if "$@" >/dev/null 2>&1; then printf 'sim'; else printf 'nao'; fi
}
_igual() { if [[ "$1" == "$2" ]]; then printf 'sim'; else printf 'nao'; fi; }

# LOG_ATU precisa existir antes do source: auth.sh chama _log ao criar
# .senhas, e _log aborta com set -e se o diretorio do log nao existir.
mkdir -p "${_TMP}/logs"
export SCRIPT_DIR="${RAIZ_TESTE}"
export CFG_DIR="${_TMP}/cfg"
export LOG_ATU="${_TMP}/logs/test_auth.log"
LOG_TMP="${_TMP}/logs/"
PERM_FILE_PRIVATE=0600 PERM_DIR_SECURE=0700

# shellcheck source=../binarios/auth.sh
. "${RAIZ_TESTE}/binarios/auth.sh"

# Silencia a tela: os fluxos testados escrevem via _exibir_mensagem_centralizada
_exibir_mensagem_centralizada() { :; }
_exibir_mensagem_centralizada_a_esquerda() { :; }
_exibir_separador_menu() { :; }
_linha() { :; }
_meia_linha() { :; }
_aguardar_tecla() { :; }

#---------- RATE LIMITING: o contador precisa DELE realmente contar ----------#
_registrar_tentativa_falha "TESTE"
_registrar_tentativa_falha "TESTE"
_registrar_tentativa_falha "TESTE"

_registros="$(grep -c '^TESTE:' "$arquivo_tentativas" || true)"
_checar "rate limit: uma unica linha por usuario" "1" "$_registros"

_contador="$(awk -F: '$1 == "TESTE" {print $2; exit}' "$arquivo_tentativas")"
_checar "rate limit: contador chega a MAX_LOGIN_ATTEMPTS" "3" "$_contador"

# Regrava: 3 falhas = bloqueio ate C_BLOQUEIO_LOGIN.
_rc=0
_verificar_bloqueio_usuario "TESTE" || _rc=$?
_checar "rate limit: usuario bloqueado apos o limite" "1" "$_rc"

# Tempo decorrido maior que o bloqueio libera o usuario (e limpa o registro).
awk -F: -v u="TESTE" 'BEGIN{OFS=":"} $1==u {print u, $2, $3-100000; next} {print}' \
    "$arquivo_tentativas" >"${_TMP}/t.tmp" && mv -f "${_TMP}/t.tmp" "$arquivo_tentativas"
_rc=0
_verificar_bloqueio_usuario "TESTE" || _rc=$?
_checar "rate limit: liberado apos C_BLOQUEIO_LOGIN" "0" "$_rc"
_checar "rate limit: registro removido ao liberar" "0" "$(grep -c '^TESTE:' "$arquivo_tentativas" || true)"

# Arquivo legado com linhas duplicadas (estado deixado pela versao quebrada):
# a proxima falha tem de colapsar em uma linha so, sem contar do zero.
printf 'TESTE:1:100\nTESTE:1:100\n' >"$arquivo_tentativas"
_registrar_tentativa_falha "TESTE"
_checar "rate limit: duplicatas legadas colapsam" "1" "$(grep -c '^TESTE:' "$arquivo_tentativas" || true)"
_checar "rate limit: duplicatas legadas contam 2" "2" \
    "$(awk -F: '$1 == "TESTE" {print $2; exit}' "$arquivo_tentativas")"

# Usuario sem registro nao e bloqueado nem gera arquivo do nada.
: >"$arquivo_tentativas"
_rc=0
_verificar_bloqueio_usuario "NÃO-EXISTE" || _rc=$?
_checar "rate limit: usuario desconhecido nao bloqueia" "0" "$_rc"

# Registro corrompido: os campos vao para a aritmetica do bash. Antes havia
# "unbound variable" + set -e, que derrubava a tela de login.
printf 'CORROMPIDO:abc:xyz\n' >"$arquivo_tentativas"
_rc=0
_verificar_bloqueio_usuario 'CORROMPIDO' || _rc=$?
_checar "rate limit: registro corrompido nao bloqueia" "0" "$_rc"
_checar "rate limit: registro corrompido e descartado" "0" \
    "$(grep -c '^CORROMPIDO:' "$arquivo_tentativas" || true)"
# Timestamp invalido com contador valido: mesmo caminho.
printf 'MEIO:3:quando\n' >"$arquivo_tentativas"
_rc=0
_verificar_bloqueio_usuario 'MEIO' || _rc=$?
_checar "rate limit: timestamp invalido nao bloqueia" "0" "$_rc"

#---------- FORMATO DE HASH: salt por registro, comparacao estavel ----------#
_h1="$(_hash_senha 'segredo')"
_h2="$(_hash_senha 'segredo')"
_checar "hash: mesmo senha gera salts diferentes" "diferente" \
    "$([[ "$_h1" != "$_h2" ]] && printf 'diferente' || printf 'igual')"
_checar "hash: formato algoritmo\$salt\$hash" "3" \
    "$(awk -F'$' '{print NF}' <<<"$_h1")"

_salt="$_h1" && _salt="${_h1#*\$}" && _salt="${_salt%%\$*}"
_checar "hash: senha confere com o salt do registro" "$(_extrair_hash "$_h1")" \
    "$(_extrair_hash "$(_hash_senha 'segredo' "$_salt")")"
_checar "hash: senha errada nao confere" "nao" \
    "$(_igual "$(_extrair_hash "$_h1")" "$(_extrair_hash "$(_hash_senha 'outra' "$_salt")")")"
_checar "hash: _hash_precisa_migracao falso em registro novo" "nao" \
    "$(_booleano _hash_precisa_migracao "$_h1")"

#---------- ALGORITMO GRAVADO NO REGISTRO ----------#
# O algoritmo e campo do .senhas. Usar sempre HASH_ALGORITHM na verificacao
# trancava todos os usuarios no dia em que a constante mudasse.
_checar "algoritmo: _extrair_algoritmo le o registro" "sha256sum" \
    "$(_extrair_algoritmo "$_h1")"
_checar "algoritmo: registro legado usa o padrao atual" "sha256sum" \
    "$(_extrair_algoritmo "$(_hash_senha_simples 'segredo')")"

_h512="$(_hash_senha 'segredo' '' 'sha512sum')"
_checar "algoritmo: registro gravado com sha512sum" "sha512sum" "$(_extrair_algoritmo "$_h512")"
_checar "algoritmo: senha confere usando o algoritmo do registro" \
    "$(_extrair_hash "$_h512")" \
    "$(_extrair_hash "$(_hash_senha 'segredo' "$(_extrair_salt "$_h512")" "$(_extrair_algoritmo "$_h512")")")"
_checar "algoritmo: registro em sha512 NAO confere com o padrao sha256" "nao" \
    "$(_igual "$(_extrair_hash "$_h512")" \
        "$(_extrair_hash "$(_hash_senha 'segredo' "$(_extrair_salt "$_h512")")")")"

# Allowlist: o .senhas pertence ao usuario dono, entao o campo do algoritmo
# nao pode virar execucao de comando.
_checar "algoritmo: comando fora da allowlist recusado" "nao" \
    "$(_booleano _hash_algoritmo_permitido 'tee')"
_checar "algoritmo: comando com argumento recusado" "nao" \
    "$(_booleano _hash_algoritmo_permitido 'sha256sum /tmp/x')"
_rc=0
_hash_senha 'segredo' '' 'tee' >/dev/null 2>&1 || _rc=$?
_checar "algoritmo: _hash_senha retorna 1 p/ algoritmo recusado" "1" "$_rc"

# Prova de que a recusa impede a execucao: um binario "inocuo" no PATH que
# deixaria rastro se fosse chamado como algoritmo.
mkdir -p "${_TMP}/bin"
printf '#!/bin/sh\ntouch "%s/marcador"\n' "$_TMP" >"${_TMP}/bin/evil.sh"
chmod +x "${_TMP}/bin/evil.sh"
_PATH_ANTES="$PATH"
PATH="${_TMP}/bin:${PATH}"
_hash_senha 'segredo' '' 'evil.sh' >/dev/null 2>&1 || true
_hash_senha_simples 'segredo' 'evil.sh' >/dev/null 2>&1 || true
PATH="$_PATH_ANTES"
_checar "algoritmo: binario fora da allowlist nao e executado" "nao" \
    "$([[ -e "${_TMP}/marcador" ]] && printf 'sim' || printf 'nao')"

# Legado = digest puro, sem salt e sem prefixo de algoritmo. E o formato que
# as versoes antigas gravavam, e o unico que _hash_senha nunca reproduz.
_legado="$(_hash_senha_simples 'segredo')"
_checar "legado: digest puro, sem \$" "0" "$(awk -F'$' '{print NF-1}' <<<"$_legado")"
_checar "legado: _hash_precisa_migracao verdadeiro" "sim" \
    "$(_booleano _hash_precisa_migracao "$_legado")"
_checar "legado: senha confere" "$_legado" "$(_hash_senha_simples 'segredo')"
_checar "legado: senha errada nao confere" "nao" \
    "$(_igual "$_legado" "$(_hash_senha_simples 'outra')")"
# Regressao: comparar registro legado com _hash_senha (salt aleatorio) nunca
# casava e deixava a migracao inalcancavel.
_checar "legado: _hash_senha NAO reproduz o registro legado" "nao" \
    "$(_igual "$(_hash_senha 'segredo')" "$_legado")"

#---------- .senhas: gravacao e integridade do arquivo ----------#
printf 'ALFA:%s\nBETA:%s\n' "$_h1" "$_h2" >"$arquivo_senhas"
chmod "$PERM_FILE_PRIVATE" "$arquivo_senhas"
_checar "senhas: usuario existente localizado" "$_h1" "$(_obter_hash_usuario 'ALFA')"
_checar "senhas: usuario inexistente retorna vazio" "" "$(_obter_hash_usuario 'GAMA')"
_checar "senhas: _usuario_existe verdadeiro" "sim" "$(_booleano _usuario_existe 'BETA')"
_checar "senhas: _usuario_existe falso" "nao" "$(_booleano _usuario_existe 'GAMA')"
_checar "senhas: _usuario_existe com nome vazio" "nao" "$(_booleano _usuario_existe '')"
_checar "senhas: usuario invalido rejeitado" "nao" "$(_booleano _usuario_valido 'alfa')"
_checar "senhas: usuario com dois pontos rejeitado" "nao" "$(_booleano _usuario_valido 'ALFA:X')"

# Regressao: arquivo sem newline final. O append grudava na ultima linha e o
# usuario novo nao era criado. _cadastrar_usuario e _registrar_usuario_ainda
# nao sao testados por TTY; aqui reproduzimos o append exato do modulo.
printf 'ALFA:%s' "$_h1" >"$arquivo_senhas" # sem \n final
if [[ -s "$arquivo_senhas" && -n "$(tail -c 1 -- "$arquivo_senhas")" ]]; then
    printf '\n' >>"$arquivo_senhas"
fi
printf 'GAMA:%s\n' "$_h2" >>"$arquivo_senhas"
_checar "senhas: append sem grudar na linha anterior (ALFA)" "$_h1" "$(_obter_hash_usuario 'ALFA')"
_checar "senhas: append sem grudar na linha anterior (GAMA)" "$_h2" "$(_obter_hash_usuario 'GAMA')"

# Arquivo vazio: o append nao deve inserir um \n fantasma.
: >"$arquivo_senhas"
if [[ -s "$arquivo_senhas" && -n "$(tail -c 1 -- "$arquivo_senhas")" ]]; then
    printf '\n' >>"$arquivo_senhas"
fi
printf 'DELTA:%s\n' "$_h2" >>"$arquivo_senhas"
_checar "senhas: arquivo vazio nao ganha linha em branco" "1" "$(wc -l <"$arquivo_senhas")"

# Permissao do arquivo de senhas
printf 'ALFA:%s\n' "$_h1" >"$arquivo_senhas"
chmod "$PERM_FILE_PRIVATE" "$arquivo_senhas"
_checar "senhas: .senhas com permissao privada" "600" "$(stat -c '%a' "$arquivo_senhas")"

#---------- _alterar_senha: alvo explicito (fluxo --cadastro) ----------#
usuario=""
_rc=0
_alterar_senha </dev/null || _rc=$?
_checar "alterar_senha: sem alvo e sem login retorna 1" "1" "$_rc"

# Nome invalido e rejeitado antes de pedir senha
_rc=0
_alterar_senha 'alfa' </dev/null || _rc=$?
_checar "alterar_senha: usuario invalido rejeitado" "1" "$_rc"

# Alvo valido chega ate a senha atual (aqui aborta por stdin fechada) e nao
# pode falhar antes disso nem gravar nada.
printf 'ALFA:%s\n' "$_h1" >"$arquivo_senhas"
cp "$arquivo_senhas" "${_TMP}/antes.txt"
_rc=0
_alterar_senha 'ALFA' </dev/null || _rc=$?
_checar "alterar_senha: senha errada nao altera o registro" "1" "$_rc"
_checar "alterar_senha: arquivo intacto apos recusa" \
    "$(cat "${_TMP}/antes.txt")" "$(cat "$arquivo_senhas")"

# Fluxo logado continua funcionando sem parametro (compatibilidade)
usuario="ALFA"
_rc=0
_alterar_senha </dev/null || _rc=$?
_checar "alterar_senha: usa global usuario quando logado" "1" "$_rc"
usuario=""

# O global nao pode ser sobrescrito pelo alvo informado
printf 'BETA:%s\n' "$_h2" >"$arquivo_senhas"
usuario="ALFA"
_rc=0
_alterar_senha 'BETA' </dev/null || _rc=$?
_checar "alterar_senha: nao altera o global usuario" "ALFA" "$usuario"
usuario=""

#---------- _login: fluxo completo (integracao) ----------#
# _login roda em subshell quando a entrada vem de pipe, entao o que importa
# aqui e o codigo de retorno e o que foi gravado em disco — nunca o global.
clear() { :; } # evita sequencias de escape no terminal de quem roda o teste
CFG_VERSAOCLASS="TESTE"
CFG_EMPRESA="SAV"
UPDATE="24/09/26"
MAX_LOGIN_ATTEMPTS=1 # uma tentativa por rodada: nao abre o prompt "deseja tentar"

_rodar_login() { # _rodar_login <entrada com \n> -> codigo de retorno de _login
    local rc=0
    printf '%b' "$1" | _login >/dev/null 2>&1 || rc=$?
    printf '%s' "$rc"
}

printf 'TESTE:%s\nLEGADO:%s\n' "$(_hash_senha 'segredo')" "$(_hash_senha_simples 'segredo')" \
    >"$arquivo_senhas"
chmod "$PERM_FILE_PRIVATE" "$arquivo_senhas"
rm -f "$arquivo_tentativas"
usuario=""

_checar "login: usuario com hash+salt entra" "0" "$(_rodar_login 'TESTE\nsegredo\n')"
_checar "login: senha errada recusa" "1" "$(_rodar_login 'TESTE\nerrada\n')"
_checar "login: falha gera exatamente 1 registro" "1" "$(grep -c '^TESTE:' "$arquivo_tentativas" || true)"
_checar "login: usuario inexistente recusa" "1" "$(_rodar_login 'FANTASMA\nsegredo\n')"

# Registro legado: precisa autenticar E ser reescrito com salt.
rm -f "$arquivo_tentativas"
_checar "login: hash legado autentica" "0" "$(_rodar_login 'LEGADO\nsegredo\nnova1\nnova1\n')"
_checar "login: legado migrado para formato com salt" "sim" \
    "$(_booleano _hash_tem_salt "$(_obter_hash_usuario 'LEGADO')")"
_checar "login: senha nova vale apos a migracao" "0" "$(_rodar_login 'LEGADO\nnova1\n')"
_checar "login: senha antiga deixa de valer" "1" "$(_rodar_login 'LEGADO\nsegredo\n')"

# Apos 3 falhas seguidas o bloqueio precisa valer. Aqui MAX_LOGIN_ATTEMPTS=3:
# com 1 o usuario ja entrava bloqueado na primeira falha e o contador nunca
# passaria de 1. As duas primeiras rodadas respondem "n" no "deseja tentar".
MAX_LOGIN_ATTEMPTS=3
rm -f "$arquivo_tentativas"
_rodar_login 'TESTE\nerra1\nn\n' >/dev/null
_rodar_login 'TESTE\nerra2\nn\n' >/dev/null
_rodar_login 'TESTE\nerra3\n' >/dev/null
_checar "login: contador chegou ao limite" "3" \
    "$(awk -F: '$1 == "TESTE" {print $2; exit}' "$arquivo_tentativas")"
_checar "login: senha correta e recusada enquanto bloqueado" "1" \
    "$(_rodar_login 'TESTE\nsegredo\n')"
MAX_LOGIN_ATTEMPTS=1

# _login precisa nao derrubar o shell quando o arquivo de senhas sumiu
mv -f "$arquivo_senhas" "${_TMP}/guard.txt"
_checar "login: .senhas ausente recusa sem abortar" "1" "$(_rodar_login 'TESTE\nsegredo\n')"
mv -f "${_TMP}/guard.txt" "$arquivo_senhas"

# Registro gravado com outro algoritmo precisa continuar valendo (o _login
# tem de usar o algoritmo do registro, nao HASH_ALGORITHM).
printf 'ALGO:%s\n' "$(_hash_senha 'segredo' '' 'sha512sum')" >"$arquivo_senhas"
chmod "$PERM_FILE_PRIVATE" "$arquivo_senhas"
rm -f "$arquivo_tentativas"
MAX_LOGIN_ATTEMPTS=1
_checar "login: registro em sha512sum autentica com HASH_ALGORITHM=sha256sum" "0" \
    "$(_rodar_login 'ALGO\nsegredo\n')"

# Reset de senha legado nao pode girar para sempre quando o stdin acaba: o
# `read` falha, a senha fica vazia e o while repetia indefinidamente.
printf 'LEGADO2:%s\n' "$(_hash_senha_simples 'segredo')" >"$arquivo_senhas"
rm -f "${_TMP}/reset.txt"
# `|| _rc2=$?` antes do printf: com set -e o subshell abortaria no retorno 1
# da funcao e o arquivo-sinal nunca seria escrito (viraria falso timeout).
( _rc2=0
  _forcar_reset_senha_legado 'LEGADO2' </dev/null >/dev/null 2>&1 || _rc2=$?
  printf '%s' "$_rc2" >"${_TMP}/reset.txt" ) &
_pid=$!
_esperou=0
while [[ ! -s "${_TMP}/reset.txt" ]] && (( _esperou < 50 )); do
    sleep 0.1
    _esperou=$((_esperou + 1))
done
if (( _esperou >= 50 )); then
    kill -9 "$_pid" 2>/dev/null || true
    _checar "reset legado: nao gira indefinidamente com stdin fechada" "1" "TIMEOUT"
else
    _checar "reset legado: nao gira indefinidamente com stdin fechada" "1" \
        "$(cat "${_TMP}/reset.txt")"
fi
wait "$_pid" 2>/dev/null || true
_checar "reset legado: registro intacto apos stdin fechada" \
    "$(_hash_senha_simples 'segredo')" "$(_obter_hash_usuario 'LEGADO2')"

# Esgotar as tentativas tambem precisa encerrar, sem mexer no registro.
printf 'LEGADO3:%s\n' "$(_hash_senha_simples 'segredo')" >"$arquivo_senhas"
MAX_LOGIN_ATTEMPTS=2
_rc=0
printf 'senha\noutra\n' | _forcar_reset_senha_legado 'LEGADO3' >/dev/null 2>&1 || _rc=$?
_checar "reset legado: tentativas divergentes encerram com erro" "1" "$_rc"
_checar "reset legado: registro intacto apos divergencia" \
    "$(_hash_senha_simples 'segredo')" "$(_obter_hash_usuario 'LEGADO3')"
MAX_LOGIN_ATTEMPTS=1

printf '\n'
if (( falhas == 0 )); then
    printf 'Todas as verificacoes passaram\n'
else
    printf '%d verificacao(oes) falharam\n' "$falhas"
fi
exit $(( falhas > 0 ? 1 : 0 ))