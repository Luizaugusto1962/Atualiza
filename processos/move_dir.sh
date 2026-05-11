#!/usr/bin/env bash
#
# move_dir.sh - Move arquivos de pasta e renomeia diretorios
# Versao: 11/05/2026-01
# Autor: Luiz Augusto
#

set -euo pipefail
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"

# Mover diretórios
if [[ -d "${SCRIPT_DIR}/libs" ]]; then
    mv "${SCRIPT_DIR}/libs" "${SCRIPT_DIR}/processos"
    printf "%s\n" "Diretorio libs movido para processos."
fi
if [[ -d "${SCRIPT_DIR}/cfg" ]]; then
    mv "${SCRIPT_DIR}/cfg" "${SCRIPT_DIR}/configuracoes"
    printf "%s\n" "Diretorio cfg movido para configuracoes."
fi

if [[ -d "${SCRIPT_DIR}/progs" ]]; then
    mv "${SCRIPT_DIR}/progs" "${SCRIPT_DIR}/savprogramas"
    printf "%s\n" "Diretorio progs movido para programas."
fi

if [[ -d "${SCRIPT_DIR}/backup" ]]; then
    mv "${SCRIPT_DIR}/backup" "${SCRIPT_DIR}/backups"
    printf "%s\n" "Diretorio backup movido para backups."
fi

if [[ -d "${SCRIPT_DIR}/bkbase" ]]; then
    mv "${SCRIPT_DIR}/bkbase" "${SCRIPT_DIR}/basebackup"
    printf "%s\n" "Diretorio bkbase movido para basebackup."
fi

if [[ -d "${SCRIPT_DIR}/olds" ]]; then
    mv "${SCRIPT_DIR}/olds" "${SCRIPT_DIR}/backprogramas"
    printf "%s\n" "Diretorio olds movido para backprogramas."
fi
if [[ -d "${SCRIPT_DIR}/envia" ]]; then
    mv "${SCRIPT_DIR}/envia" "${SCRIPT_DIR}/enviar"
    printf "%s\n" "Diretorio envia movido para enviar."
fi

if [[ -d "${SCRIPT_DIR}/recebe" ]]; then
    mv "${SCRIPT_DIR}/recebe" "${SCRIPT_DIR}/receber"
    printf "%s\n" "Diretorio recebe movido para receber."
fi

printf "%s\n" "Movimento concluido."









