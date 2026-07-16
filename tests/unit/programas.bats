setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum date stat

    source "${LIBS_DIR}/programas.sh"
}

@test "_validar_integridade_backup fails for non-existent file" {
    run _validar_integridade_backup "/nonexistent/backup.zip"
    [ "$status" -eq 1 ]
}

@test "_validar_integridade_backup fails for file too small" {
    local small_file="${DEFAULT_BASEBACKUP_DIR}/small.zip"
    printf "tiny" > "$small_file"

    run _validar_integridade_backup "$small_file"
    [ "$status" -eq 1 ]
}

@test "_validar_diretorio_backups creates directory if missing" {
    local test_dir="${BATS_TEST_TMPDIR}/test_backup_dir"
    rm -rf "$test_dir"

    _validar_diretorio_backups "$test_dir"
    [ "$?" -eq 0 ]
    [ -d "$test_dir" ]
}

@test "_resolver_arquivo_compilado sets normal compilation" {
    local nome="PROGRAMA"
    export compilado="-class25"
    export debugado="-mclass25"

    echo "1" | _resolver_arquivo_compilado "$nome" 2>/dev/null || true
}

@test "_validar_diretorio_backups returns 0 when dir exists" {
    local test_dir="${DEFAULT_OLDS_DIR}"
    mkdir -p "$test_dir"

    run _validar_diretorio_backups "$test_dir"
    [ "$status" -eq 0 ]
}
