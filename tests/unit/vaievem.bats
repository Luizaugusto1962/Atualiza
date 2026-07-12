setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    source "${LIBS_DIR}/vaievem.sh"
    export usuario="testuser"
}

@test "_validar_caminho_seguro rejects path traversal" {
    run _validar_caminho_seguro "/path/../etc/passwd"
    [ "$status" -eq 1 ]
}

@test "_validar_caminho_seguro rejects semicolon injection" {
    run _validar_caminho_seguro "/path;rm -rf /"
    [ "$status" -eq 1 ]
}

@test "_validar_caminho_seguro rejects backtick injection" {
    run _validar_caminho_seguro '/path/`whoami`'
    [ "$status" -eq 1 ]
}

@test "_validar_caminho_seguro rejects pipe injection" {
    run _validar_caminho_seguro "/path|whoami"
    [ "$status" -eq 1 ]
}

@test "_validar_caminho_seguro rejects ampersand injection" {
    run _validar_caminho_seguro "/path&whoami"
    [ "$status" -eq 1 ]
}

@test "_validar_caminho_seguro accepts safe path" {
    run _validar_caminho_seguro "/safe/path/to/file.zip"
    [ "$status" -eq 0 ]
}

@test "_validar_caminho_seguro accepts relative path" {
    run _validar_caminho_seguro "relative/path/file"
    [ "$status" -eq 0 ]
}

@test "_usar_chave_ssh returns 1 when not configured" {
    export CFG_CHAVE_SSH="n"
    run _usar_chave_ssh
    [ "$status" -eq 1 ]
}

@test "_usar_chave_ssh returns 1 when key file missing" {
    export CFG_CHAVE_SSH="s"
    export CHAVE="/nonexistent/key"
    export DEFAULT_CHAVE_SSH="/nonexistent/key"
    run _usar_chave_ssh
    [ "$status" -eq 1 ]
}

@test "_validar_caminho_seguro accepts path with underscores" {
    run _validar_caminho_seguro "/path/to/backup_file_2026.zip"
    [ "$status" -eq 0 ]
}
