setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    source "${LIBS_DIR}/config.sh"
}

@test "_var_ja_registrada returns false for unregistered variable" {
    run _var_ja_registrada "UNREGISTERED"
    [ "$status" -eq 1 ]
}

@test "_var_ja_registrada returns true after registration" {
    _REGISTRO_MAPA["TEST_VAR"]=1
    _var_ja_registrada "TEST_VAR"
    [ "$?" -eq 0 ]
}

@test "_register_var stores variable in registry" {
    _register_var "MY_VAR" "my_value" "TEST"
    [ "$?" -eq 0 ]
}

@test "_register_var skips readonly variables" {
    declare -r READONLY_VAR="cant_change"
    _register_var "READONLY_VAR" "new_value" "TEST"
    [ "$?" -eq 0 ]
    [ "$READONLY_VAR" = "cant_change" ]
}

@test "_register_var rejects empty variable name" {
    run _register_var "" "value" "TEST"
    [ "$status" -eq 1 ]
}

@test "_validar_config_file rejects dangerous characters" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=value;rm -rf /\n' > "$config_file"

    run _validar_config_file "$config_file"
    [ "$status" -eq 1 ]
}

@test "_validar_config_file rejects command substitution" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=\$(whoami)\n' > "$config_file"

    run _validar_config_file "$config_file"
    [ "$status" -eq 1 ]
}

@test "_validar_config_file accepts valid config" {
    local config_file="${CFG_DIR}/.config"
    printf 'KEY=value\nANOTHER=123\n' > "$config_file"

    run _validar_config_file "$config_file"
    [ "$status" -eq 0 ]
}

@test "_validar_config_file handles empty config file" {
    local config_file="${CFG_DIR}/.config"
    printf '' > "$config_file"

    run _validar_config_file "$config_file"
    [ "$status" -eq 0 ]
}

@test "_configurar_variaveis_sistema sets E_EXEC and T_TELAS" {
    _configurar_variaveis_sistema
    [ -n "${E_EXEC:-}" ]
    [ -n "${T_TELAS:-}" ]
}

@test "_is_var_readonly detects readonly variable" {
    declare -r TEST_RO="test"
    _is_var_readonly "TEST_RO"
    [ "$?" -eq 0 ]
}

@test "_is_var_readonly returns 1 for non-readonly" {
    TEST_NORMAL="test"
    run _is_var_readonly "TEST_NORMAL"
    [ "$status" -eq 1 ]
}

@test "_validar_config_file rejects oversized config" {
    local config_file="${CFG_DIR}/.config"
    local i
    for ((i=0; i<600; i++)); do
        printf 'KEY=%-1800s\n' "value$i"
    done > "$config_file"

    run _validar_config_file "$config_file"
    [ "$status" -eq 1 ]
}
