#!/usr/bin/env bash
set -euo pipefail
cd /tmp/testlimp

# stubs das funcoes de interface/log usadas pela rotina
_linha(){ :; }
_ok(){ echo "OK: $*"; }
_erro(){ echo "ERRO: $*" >&2; }
_log(){ echo "LOG: $*"; }
_exibir_mensagem_centralizada(){ echo "MSG: $3"; }

source ./stubs.sh
source ./func.sh

echo "=== execucao ==="
_limpar_base_especifica "$PWD/base" "$PWD/lista.txt" "" ""
rc=$?

echo "rc=$rc"
echo "=== restantes em base/ ==="
ls -1 base/
echo "=== zip criado ==="
ls -1 backup/ 2>/dev/null || echo "(nenhum)"
