#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: varias variaveis daqui (PERM_DIR_SECURE, DEFAULT_UNZIP, DEFAULT_TAR,
# CFG_OFFLINE, ...) sao consumidas pelos modulos que este arquivo carrega com
# `source`, nao pelo proprio script. Sem esta diretiva a verificacao acusaria
# uso falso.
set -euo pipefail
#
# testes/test_utils.sh - verificacoes isoladas de binarios/utils.sh
#
# utils.sh concentra a validacao de caminhos, a porta unica de diretorios
# (_garantir_diretorio), a validacao de entradas de pacote e a decisao do modo
# do StrictHostKeyChecking. Era o modulo sem suite: as duas suites existentes
# (test_sistema.sh e test_auth.sh) nao o tocam.
#
# Este arquivo cobre essa superficie sem TTY, sem rede e sem tocar o disco do
# sistema: tudo acontece em mktemp -d, e os diretorios "protegidos" sao
# clones em TMP — em especial SCRIPT_DIR, que NUNCA pode apontar para o repo
# de verdade (o modo "recriar" faria rm -rf nele se a protecao regredisse).
#
# Rodar direto, sem TTY:
#   bash testes/test_utils.sh
#
# Padroes e regras de desenvolvimento: ver AGENTS.md
#

RAIZ_TESTE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# utils.sh usa as cores ja no proprio source (label _aviso em utils.sh:_aviso).
: "${VERMELHO:=}" "${VERDE:=}" "${AMARELO:=}" "${AZUL:=}"
: "${ROXO:=}" "${CIANO:=}" "${BRANCO:=}" "${NORMAL:=}"

# utils.sh e sourced (nunca executado) e liga o strict mode neste shell.
# shellcheck source=../binarios/utils.sh
. "${RAIZ_TESTE}/binarios/utils.sh"

falhas=0
total=0
_checar() { # _checar <descricao> <esperado> <obtido>
    total=$((total + 1))
    if [[ "$2" == "$3" ]]; then
        printf 'ok    - %s\n' "$1"
    else
        printf 'FALHA - %s\n         esperado: [%s]\n         obtido:   [%s]\n' "$1" "$2" "$3"
        falhas=$((falhas + 1))
    fi
}

_rc() { # _rc <comando...> -> imprime o codigo de retorno
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    printf '%s' "$rc"
}

_contem() { # _contem <texto> <substring> -> sim/nao
    if [[ "$1" == *"$2"* ]]; then printf 'sim'; else printf 'nao'; fi
}

# Executa o comando no shell CORRENTE (sem subshell) e deixa o codigo em RC.
# Necesario para capturar _ULTIMO_ERRO: dentro de $( ) a atribuicao acontece
# no subshell e se perde.
_executar() { # _executar <comando...> ; resultado em RC
    RC=0
    "$@" >/dev/null 2>&1 || RC=$?
}

# Modo octal do arquivo, com fallback para stat BSD (o alvo e GNU, mas o
# harness tambem roda em maquina de desenvolvimento nao-Linux).
_modo() { # _modo <arquivo>
    local m
    m="$(stat -c '%a' "$1" 2>/dev/null || true)"
    if [[ -z "$m" ]]; then
        m="$(stat -f '%Lp' "$1" 2>/dev/null || true)"
    fi
    printf '%s' "$m"
}

_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

# ---------- ambiente: clones dos diretorios protegidos, dentro do TMP ----------#
# SCRIPT_DIR em especial NAO pode ser o repo: _garantir_diretorio "recriar"
# sobre um caminho protegido precisa RECUSAR, e o teste abaixo confirma que
# recusou. Se a protecao regredisse, o alvo do rm -rf seria o repo inteiro.
export SCRIPT_DIR="${_TMP}/script"
export CFG_DIR="${_TMP}/cfg"
export CFG_PORTALSAV="${_TMP}/portalsav"
export RAIZ="${_TMP}/raiz"
export LIBS_DIR="${_TMP}/libs"
export LOG_ATU="${_TMP}/logs/test_utils.log"
export LOG_LIMPA="${_TMP}/logs/limpa.log"
export DEFAULT_LOGS_DIR="${_TMP}/logs"
export DEFAULT_BACKUP_DIR="${_TMP}/backups"
export DEFAULT_BASEBACKUP_DIR="${_TMP}/backups"
export DEFAULT_BIBLIOTECA_DIR="${_TMP}/biblioteca"
export DEFAULT_BIBLIOTECA_ATUAL_DIR="${_TMP}/biblioteca_atual"
export DEFAULT_PROGS_DIR="${_TMP}/progs"
export DEFAULT_PROGS_ATUAL_DIR="${_TMP}/progs_atual"
export DEFAULT_ENVIA_DIR="${_TMP}/envia"

PERM_FILE_PRIVATE=0600
PERM_DIR_SECURE=0755
DEFAULT_UNZIP=unzip
DEFAULT_ZIP=zip
DEFAULT_TAR=tar
DEFAULT_FIND="find"

mkdir -p "$SCRIPT_DIR" "$CFG_DIR" "$CFG_PORTALSAV" "$RAIZ" "$LIBS_DIR" \
    "$DEFAULT_LOGS_DIR" "$DEFAULT_BACKUP_DIR" "$DEFAULT_BIBLIOTECA_DIR" \
    "$DEFAULT_BIBLIOTECA_ATUAL_DIR" "$DEFAULT_PROGS_DIR" "$DEFAULT_PROGS_ATUAL_DIR" \
    "$DEFAULT_ENVIA_DIR"

# Silencia a saida e captura a ultima mensagem de _erro.
_erro() { _ULTIMO_ERRO="${1:-}"; }
_aviso() { :; }
_ok() { :; }
_msg() { :; }
_exibir_mensagem_centralizada() { :; }
_exibir_mensagem_centralizada_a_esquerda() { :; }
_linha() { :; }
_meia_linha() { :; }
_aguardar_tecla() { :; }

# ---------- artefatos: ZIPs legitimos e maliciosos ----------#
_criar_zip() { # _criar_zip <arquivo> <ok|traversal|absoluto|win>
    python3 - "$1" "$2" <<'PY' || return 1
import sys, zipfile
out, kind = sys.argv[1], sys.argv[2]
names = {
    "ok":        ["programa/OK.class", "programa/OK.TEL"],
    "traversal": ["../evil.class"],
    "absoluto":  ["/etc/passwd"],
    "win":       ["C:\\evil.class"],
}
with zipfile.ZipFile(out, "w") as z:
    for n in names[kind]:
        z.writestr(n, "conteudo de teste")
PY
}

_criar_tar_malicioso() { # _criar_tar_malicioso <arquivo>
    python3 - "$1" <<'PY' || return 1
import sys, tarfile, io
with tarfile.open(sys.argv[1], "w:gz") as t:
    data = b"conteudo de teste"
    info = tarfile.TarInfo("../evil.class")
    info.size = len(data)
    t.addfile(info, io.BytesIO(data))
PY
}

ZIP_OK="${_TMP}/ok.zip"
ZIP_TRAV="${_TMP}/traversal.zip"
ZIP_ABS="${_TMP}/absoluto.zip"
ZIP_WIN="${_TMP}/win.zip"
_criar_zip "$ZIP_OK" ok
_criar_zip "$ZIP_TRAV" traversal
_criar_zip "$ZIP_ABS" absoluto
_criar_zip "$ZIP_WIN" win
TAR_TRAV="${_TMP}/traversal.tar.gz"
_criar_tar_malicioso "$TAR_TRAV"

# ---------- _validar_caminho_seguro ----------#
# Regra do AGENTS.md: nenhuma operacao de arquivo (remota ou local) pode
# passar sem passar por aqui. E a base do path traversal e da injecao de
# metacaracteres em log e linha de comando.
_checar "caminho: caminho legitimo aceito" "0" "$(_rc _validar_caminho_seguro "/savisc/programas")"
_checar "caminho: caminho relativo aceito" "0" "$(_rc _validar_caminho_seguro "programas")"
_checar "caminho: vazio recusado" "1" "$(_rc _validar_caminho_seguro "")"
_checar "caminho: raiz recusada" "1" "$(_rc _validar_caminho_seguro "/")"
_checar "caminho: raiz dupla recusada" "1" "$(_rc _validar_caminho_seguro "//")"
_checar "caminho: traversal recusado" "1" "$(_rc _validar_caminho_seguro "/tmp/../etc")"
_checar "caminho: traversal no inicio recusado" "1" "$(_rc _validar_caminho_seguro "../etc")"
_checar "caminho: traversal no meio recusado" "1" "$(_rc _validar_caminho_seguro "a/../b")"
_checar "caminho: ponto-e-ponto solto recusado" "1" "$(_rc _validar_caminho_seguro "..")"
_checar "caminho: ponto-e-ponto no fim recusado" "1" "$(_rc _validar_caminho_seguro "a/..")"
_checar "caminho: ponto-e-ponto simples aceito" "0" "$(_rc _validar_caminho_seguro "/tmp/a.b")"

# Caminhos com metacaractere: montados em variaveis para nao confundir o
# quoting do teste com o quoting do caminho testado.
P_SEMI='/tmp/a;b'
P_PIPE='/tmp/a|b'
P_AMP='/tmp/a&b'
P_DOLLAR='/tmp/a$b'
P_BACKTICK='/tmp/a`b'
P_LT='/tmp/a<b'
P_GT='/tmp/a>b'
P_SQUOTE="/tmp/a'b"
P_DQUOTE='/tmp/a"b'
_checar "caminho: metacaractere ';' recusado" "1" "$(_rc _validar_caminho_seguro "$P_SEMI")"
_checar "caminho: metacaractere '|' recusado" "1" "$(_rc _validar_caminho_seguro "$P_PIPE")"
_checar "caminho: metacaractere '&' recusado" "1" "$(_rc _validar_caminho_seguro "$P_AMP")"
_checar "caminho: metacaractere '$' recusado" "1" "$(_rc _validar_caminho_seguro "$P_DOLLAR")"
_checar 'caminho: metacaractere backtick recusado' "1" "$(_rc _validar_caminho_seguro "$P_BACKTICK")"
_checar "caminho: metacaractere '<' recusado" "1" "$(_rc _validar_caminho_seguro "$P_LT")"
_checar "caminho: metacaractere '>' recusado" "1" "$(_rc _validar_caminho_seguro "$P_GT")"
_checar "caminho: aspa simples recusada" "1" "$(_rc _validar_caminho_seguro "$P_SQUOTE")"
_checar "caminho: aspa dupla recusada" "1" "$(_rc _validar_caminho_seguro "$P_DQUOTE")"
_checar "caminho: quebra de linha recusada" "1" "$(_rc _validar_caminho_seguro "/tmp/a
b")"
_checar "caminho: Carriage Return recusado" "1" "$(_rc _validar_caminho_seguro $'/tmp/a\rb')"
_checar "caminho: tamanho acima do teto recusado" "1" \
    "$(_rc _validar_caminho_seguro "/tmp/$(head -c 5000 /dev/zero | tr '\0' 'a')")"
_checar "caminho: tamanho dentro do teto aceito" "0" \
    "$(_rc _validar_caminho_seguro "/tmp/$(head -c 100 /dev/zero | tr '\0' 'a')")"

# ---------- _diretorio_protegido ----------#
# CFG_PORTALSAV e diretorio COMPARTILHADO: recebe backup offline pendente,
# ZIP de biblioteca, ZIP de reversao e o pacote do self-update. Um rm -rf
# ali apaga material do usuario.
_checar "protegido: CFG_PORTALSAV e protegido" "0" "$(_rc _diretorio_protegido "$CFG_PORTALSAV")"
_checar "protegido: CFG_PORTALSAV com barra final e protegido" "0" \
    "$(_rc _diretorio_protegido "${CFG_PORTALSAV}/")"
_checar "protegido: RAIZ e protegida" "0" "$(_rc _diretorio_protegido "$RAIZ")"
_checar "protegido: DEFAULT_PROGS_DIR e protegido" "0" "$(_rc _diretorio_protegido "$DEFAULT_PROGS_DIR")"
_checar "protegido: diretorio comum nao e protegido" "1" "$(_rc _diretorio_protegido "${_TMP}/comum")"

# ---------- _garantir_diretorio: porta unica de diretorio do sistema ----------#
DIR_NOVO="${_TMP}/novo"
_checar "garantir: criar cria o diretorio" "0" "$(_rc _garantir_diretorio "$DIR_NOVO" criar "teste")"
_checar "garantir: diretorio existe apos criar" "sim" \
    "$([ -d "$DIR_NOVO" ] && printf 'sim' || printf 'nao')"
_checar "garantir: permissao do diretorio recem-criado" "755" "$(_modo "$DIR_NOVO")"
_checar "garantir: verificar aceita caminho inexistente" "0" \
    "$(_rc _garantir_diretorio "${_TMP}/nao_existe" verificar "teste")"
_checar "garantir: validar recusa caminho inexistente" "1" \
    "$(_rc _garantir_diretorio "${_TMP}/nao_existe" validar "teste")"
_checar "garantir: validar_escrita recusa caminho inexistente" "1" \
    "$(_rc _garantir_diretorio "${_TMP}/nao_existe" validar_escrita "teste")"
_checar "garantir: modo desconhecido recusado" "1" \
    "$(_rc _garantir_diretorio "${_TMP}/modo_x" "xyz" "teste")"
_checar "garantir: caminho vazio recusado" "1" "$(_rc _garantir_diretorio "" criar "teste")"
_checar "garantir: caminho com traversal recusado" "1" \
    "$(_rc _garantir_diretorio "${_TMP}/../tmp_x" criar "teste")"
_checar "garantir: caminho com traversal nao foi criado" "nao" \
    "$([ -d "/tmp_x" ] && printf 'sim' || printf 'nao')"

# recriar em diretorio PROTEGIDO: recusa e nao apaga nada
touch "${CFG_PORTALSAV}/sentinela.txt"
_ULTIMO_ERRO=""
_executar _garantir_diretorio "$CFG_PORTALSAV" recriar "teste"
_checar "garantir: recriar recusa diretorio compartilhado" "1" "$RC"
_checar "garantir: recusa do compartilhado e por diretorio protegido" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "compartilhado")"
_checar "garantir: recriar protegido NAO apagou o conteudo" "sim" \
    "$([ -f "${CFG_PORTALSAV}/sentinela.txt" ] && printf 'sim' || printf 'nao')"

# recriar em area de operacao: aceita e purga
mkdir -p "${_TMP}/recriar"
touch "${_TMP}/recriar/velho.txt"
_checar "garantir: recriar aceita area de operacao" "0" \
    "$(_rc _garantir_diretorio "${_TMP}/recriar" recriar "teste")"
_checar "garantir: recriar purga o conteudo antigo" "nao" \
    "$([ -f "${_TMP}/recriar/velho.txt" ] && printf 'sim' || printf 'nao')"
_checar "garantir: recriar deixa o diretorio em pe" "sim" \
    "$([ -d "${_TMP}/recriar" ] && printf 'sim' || printf 'nao')"

# recriar onde o caminho e um ARQUIVO: recusa e preserva o arquivo
touch "${_TMP}/arquivo.txt"
_checar "garantir: recriar recusa caminho que e arquivo" "1" \
    "$(_rc _garantir_diretorio "${_TMP}/arquivo.txt" recriar "teste")"
_checar "garantir: arquivo preservado apos recusa" "sim" \
    "$([ -f "${_TMP}/arquivo.txt" ] && printf 'sim' || printf 'nao')"

# criar em diretorio PRE-EXISTENTE nao re-permissona (ponto de montagem)
mkdir -p "${_TMP}/exist"
chmod 0770 "${_TMP}/exist"
_checar "garantir: criar em diretorio existente tem sucesso" "0" \
    "$(_rc _garantir_diretorio "${_TMP}/exist" criar "teste")"
_checar "garantir: criar NAO re-permissona diretorio pre-existente" "770" \
    "$(_modo "${_TMP}/exist")"

# ---------- _validar_backup_entradas_seguras ----------#
# Portao antes de QUALQUER extracao: sem isso, um pacote com "../" ou caminho
# absoluto escapa do diretorio de extracao.
_checar "pacote: zip legitimo aceito" "0" "$(_rc _validar_backup_entradas_seguras "$ZIP_OK")"
_ULTIMO_ERRO=""
_executar _validar_backup_entradas_seguras "$ZIP_TRAV"
_checar "pacote: zip com traversal recusado" "1" "$RC"
_checar "pacote: recusa por entrada insegura (motivo)" "sim" \
    "$(_contem "$_ULTIMO_ERRO" "entradas inseguras")"
_checar "pacote: zip com caminho absoluto recusado" "1" "$(_rc _validar_backup_entradas_seguras "$ZIP_ABS")"
_checar "pacote: zip com caminho windows recusado" "1" "$(_rc _validar_backup_entradas_seguras "$ZIP_WIN")"
_checar "pacote: tar.gz com traversal recusado" "1" "$(_rc _validar_backup_entradas_seguras "$TAR_TRAV")"
_checar "pacote: arquivo inexistente recusado" "1" \
    "$(_rc _validar_backup_entradas_seguras "${_TMP}/nao_existe.zip")"
_checar "pacote: argumento vazio recusado" "1" "$(_rc _validar_backup_entradas_seguras "")"
_checar "pacote: alias _validar_zip_entradas_seguras barra traversal" "1" \
    "$(_rc _validar_zip_entradas_seguras "$ZIP_TRAV")"
_checar "pacote: alias _validar_zip_entradas_seguras aceita zip legitimo" "0" \
    "$(_rc _validar_zip_entradas_seguras "$ZIP_OK")"

# ---------- _offline_valido: a flag nunca pode ser testada direto ----------#
# O bug historico era duplo: `if [[ "$CFG_OFFLINE" =~ ^[sn]$ ]]` sem `else`
# deixava a funcao retornar 0 sem fazer nada, e com `else` o valor invalido
# caia no ramo de descarga pela REDE.
CFG_OFFLINE="s"
_checar "offline: 's' aceito" "0" "$(_rc _offline_valido)"
CFG_OFFLINE="n"
_checar "offline: 'n' aceito" "0" "$(_rc _offline_valido)"
CFG_OFFLINE=""
_checar "offline: vazio recusado" "1" "$(_rc _offline_valido)"
CFG_OFFLINE="S"
_checar "offline: 'S' maiusculo recusado" "1" "$(_rc _offline_valido)"
CFG_OFFLINE="x"
_checar "offline: valor invalido recusado" "1" "$(_rc _offline_valido)"
unset CFG_OFFLINE
_checar "offline: ausente recusado" "1" "$(_rc _offline_valido)"

# ---------- _validar_nome_programa ----------#
_checar "nome: PROGRAMA aceito" "0" "$(_rc _validar_nome_programa "PROGRAMA")"
_checar "nome: com underscore aceito" "0" "$(_rc _validar_nome_programa "PROG_1")"
_checar "nome: minuscula recusada" "1" "$(_rc _validar_nome_programa "prog")"
_checar "nome: hifen recusado" "1" "$(_rc _validar_nome_programa "PROG-1")"
_checar "nome: ponto recusado" "1" "$(_rc _validar_nome_programa "PROG.1")"
_checar "nome: vazio recusado" "1" "$(_rc _validar_nome_programa "")"
_checar "nome: acima de 64 caracteres recusado" "1" \
    "$(_rc _validar_nome_programa "A$(printf 'B%.0s' $(seq 1 64))")"

# ---------- _log ----------#
_log "linha de teste do harness"
_checar "log: mensagem gravada no arquivo" "sim" \
    "$(grep -q 'linha de teste do harness' "$LOG_ATU" && printf 'sim' || printf 'nao')"
_checar "log: caminho sem diretorio recusado" "1" "$(_rc _log "x" "arquivo_sem_dir.log")"

# ---------- _ssh_aceitar_novo ----------#
# OpenSSH >= 7.6 aceita "accept-new"; abaixo disso (Ubuntu 10.04/12.04, o
# alvo real) so aceita "no". O valor nunca pode ser escrito literal no
# comando ssh, e a funcao precisa sobreviver a cache limpado: config.sh
# (_limpar_estado_variaveis) faz `unset -v _SSH_ACEITAR_NOVO`, e uma leitura
# sem default em `set -u` aborta o shell.
_SSH_VERSAO_CACHE="OpenSSH_7.6"
_checar "ssh: OpenSSH 7.6 usa accept-new" "accept-new" "$(_ssh_aceitar_novo)"
_SSH_VERSAO_CACHE="OpenSSH_9.6"
_checar "ssh: OpenSSH 9.6 usa accept-new" "accept-new" "$(_ssh_aceitar_novo)"
_SSH_VERSAO_CACHE="OpenSSH_5.9"
_checar "ssh: OpenSSH 5.9 usa no" "no" "$(_ssh_aceitar_novo)"
_SSH_VERSAO_CACHE="OpenSSH_7.4"
_checar "ssh: OpenSSH 7.4 usa no" "no" "$(_ssh_aceitar_novo)"
_SSH_VERSAO_CACHE="desconhecido"
_checar "ssh: versao nao parseada usa no" "no" "$(_ssh_aceitar_novo)"
unset _SSH_VERSAO_CACHE
unset _SSH_ACEITAR_NOVO
_SSH_VERSAO_CACHE="OpenSSH_5.9"
_checar "ssh: resultado cacheado reaproveitado" "no" "$(_ssh_aceitar_novo)"

printf '\n'
if ((falhas > 0)); then
    printf '%s verificacao(oes) falharam\n' "$falhas"
    exit 1
fi
printf 'Todas as verificacoes passaram (%s verificacoes)\n' "$total"
