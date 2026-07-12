setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    rm -f "${CFG_DIR}/.config" 2>/dev/null || true
    source "${LIBS_DIR}/constantes.sh"
}

@test "_carregar_config_seguro parses valid key=value line" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=value\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ "$status" -eq 0 ]
}

@test "_carregar_config_seguro skips comments" {
    local config_file="${CFG_DIR}/.config"
    printf '# comment\nKEY=value\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ "$status" -eq 0 ]
}

@test "_carregar_config_seguro skips empty lines" {
    local config_file="${CFG_DIR}/.config"
    printf '\n\nKEY=value\n\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ "$status" -eq 0 ]
}

@test "_carregar_config_seguro strips double quotes from values" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY="value"\n' > "$config_file"

    _carregar_config_seguro "$config_file"
    [ "${KEY:-}" = "value" ]
}

@test "_carregar_config_seguro strips single quotes from values" {
    local config_file="${CFG_DIR}/.config"
    printf "KEY='value'\n" > "$config_file"

    _carregar_config_seguro "$config_file"
    [ "${KEY:-}" = "value" ]
}

@test "_carregar_config_seguro strips inline comments" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=value # inline comment\n' > "$config_file"

    _carregar_config_seguro "$config_file"
    [ "${KEY:-}" = "value" ]
}

@test "_carregar_config_seguro rejects dollar sign injection" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=\$dangerous\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ -z "${KEY:-}" ]
}

@test "_carregar_config_seguro rejects backtick injection" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=\x60whoami\x60\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ -z "${KEY:-}" ]
}

@test "_carregar_config_seguro rejects semicolon injection" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=value;rm -rf /\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ -z "${KEY:-}" ]
}

@test "_carregar_config_seguro handles values with equals signs" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=base64data==\n' > "$config_file"

    _carregar_config_seguro "$config_file"
    [ "${KEY:-}" = "base64data==" ]
}

@test "_carregar_config_seguro returns 1 for invalid config format" {
    local config_file="${CFG_DIR}/.config"
    printf 'invalid line without equals\n' > "$config_file"

    run _carregar_config_seguro "$config_file"
    [ "$status" -eq 0 ]
    [ -z "${invalid:-}" ]
}
