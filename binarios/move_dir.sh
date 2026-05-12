#!/usr/bin/env bash
#
# move_dir.sh - Move arquivos de pasta e renomeia diretorios
# Versao: 11/05/2026-01
# Autor: Luiz Augusto
#

# Diretorio do script principal
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")}"
cd "${SCRIPT_DIR}" || exit 1

# Mover diretórios
if [[ -d "${SCRIPT_DIR}/libs" && -n "$(ls -A "${SCRIPT_DIR}/libs")" ]]; then
    mv "${SCRIPT_DIR}/libs" "${SCRIPT_DIR}/binarios"
    printf "%s\n" "Diretorio libs movido para binarios."
fi

if [[ -d "${SCRIPT_DIR}/cfg" && -n "$(ls -A "${SCRIPT_DIR}/cfg")" ]]; then
    mv "${SCRIPT_DIR}/cfg" "${SCRIPT_DIR}/configuracoes"
    printf "%s\n" "Diretorio cfg movido para configuracoes."
fi

declare -a AUX_DIRS=("${SCRIPT_DIR}/backup" "${SCRIPT_DIR}/envia" "${SCRIPT_DIR}/recebe" "${SCRIPT_DIR}/progs" "${SCRIPT_DIR}/olds" "${SCRIPT_DIR}/bkbase" "${SCRIPT_DIR}/biblioteca" "${SCRIPT_DIR}/logs")
for dir in "${AUX_DIRS[@]}"; do
    # Verificar se a variável está definida
    if [[ -d "${dir}" ]]; then
        rm -rf "${dir}" || {
            printf "AVISO: Nao foi possivel remover o diretorio %s\n" "${dir}" >&2
            return 1
        }
    fi
done
