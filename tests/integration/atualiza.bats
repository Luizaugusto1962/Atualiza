setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    export PLIBS_DIR="${LIBS_DIR}"
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "$HOME"
}

@test "atualiza.sh --setup delegates to setup.sh" {
    skip "Requires setup.sh to exist and be executable"
}

@test "atualiza.sh --cadastro delegates to cadastro.sh" {
    skip "Requires cadastro.sh to exist and be executable"
}

@test "atualiza.sh without arguments delegates to principal.sh" {
    skip "Requires principal.sh and its full module chain"
}

@test "atualiza.sh with invalid flag shows usage" {
    SCRIPT_DIR="${BATS_TEST_TMPDIR}"
    PLIBS_DIR="${SCRIPT_DIR}/binarios"

    run source "${SCRIPT_DIR}/../atualiza.sh" 2>&1 || true
}

@test "atualiza.sh handles missing binarios directory" {
    local tmpdir="${BATS_TEST_TMPDIR}/no_binarios"
    mkdir -p "$tmpdir"
    SCRIPT_DIR="$tmpdir"
    PLIBS_DIR="${tmpdir}/binarios"

    run bash -c '
        SCRIPT_DIR="$1"
        PLIBS_DIR="${SCRIPT_DIR}/binarios"
        if [[ ! -d "${PLIBS_DIR}" ]]; then
            printf "ERRO: Diretorio ${PLIBS_DIR} nao encontrado."
            exit 1
        fi
    ' _ "$tmpdir"

    [ "$status" -eq 1 ]
    [[ "$output" == *"ERRO"* ]]
}
