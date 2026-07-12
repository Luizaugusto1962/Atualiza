setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum
}

@test "_criar_diretorio_seguro creates directory with correct permissions" {
    local test_dir="${BATS_TEST_TMPDIR}/new_dir"
    rm -rf "$test_dir"

    source "${LIBS_DIR}/principal.sh"

    _criar_diretorio_seguro "$test_dir" "0755"
    [ "$?" -eq 0 ]
    [ -d "$test_dir" ]
}

@test "_criar_diretorio_seguro rejects root path" {
    source "${LIBS_DIR}/principal.sh"

    run _criar_diretorio_seguro "/" "0755"
    [ "$status" -eq 1 ]
}

@test "_criar_diretorio_seguro rejects empty path" {
    source "${LIBS_DIR}/principal.sh"

    run _criar_diretorio_seguro "" "0755"
    [ "$status" -eq 1 ]
}

@test "_criar_diretorio_seguro returns 0 if directory already exists" {
    local test_dir="${BATS_TEST_TMPDIR}/existing_dir"
    mkdir -p "$test_dir"

    source "${LIBS_DIR}/principal.sh"

    _criar_diretorio_seguro "$test_dir" "0755"
    [ "$?" -eq 0 ]
}

@test "_caminho_modulo returns 1 for non-existent module" {
    source "${LIBS_DIR}/principal.sh"

    run _caminho_modulo "nonexistent_module.sh"
    [ "$status" -eq 1 ]
}

@test "_caminho_modulo returns 1 for empty module file" {
    local empty_file="${LIBS_DIR}/empty.sh"
    printf "" > "$empty_file"

    source "${LIBS_DIR}/principal.sh"

    run _caminho_modulo "empty.sh"
    [ "$status" -eq 1 ]
}

@test "_caminho_modulo returns 1 for unreadable module" {
    if [[ "$(id -u)" == "0" ]]; then
        local no_perm_file="${LIBS_DIR}/noperm.sh"
        printf "echo test" > "$no_perm_file"
        chmod 000 "$no_perm_file"

        source "${LIBS_DIR}/principal.sh"

        run _caminho_modulo "noperm.sh"
        [ "$status" -eq 1 ]

        chmod 644 "$no_perm_file"
    else
        skip "Cannot test unreadable file without root"
    fi
}

@test "_caminho_modulo loads valid module" {
    local valid_file="${LIBS_DIR}/test_mod.sh"
    printf 'echo "loaded"' > "$valid_file"

    source "${LIBS_DIR}/principal.sh"

    run _caminho_modulo "test_mod.sh"
    [ "$status" -eq 0 ]
}
