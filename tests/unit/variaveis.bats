setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    source "${LIBS_DIR}/variaveis.sh"
}

@test "_var_obter_valor returns NAO DEFINIDO for unset variable" {
    run _var_obter_valor "NONEXISTENT_VAR"
    [ "$output" = "NAO DEFINIDO" ]
}

@test "_var_obter_valor returns value for set variable" {
    export TEST_VAR="hello"
    run _var_obter_valor "TEST_VAR"
    [ "$output" = "hello" ]
}

@test "_var_verificar_dependencias returns 0 when all deps available" {
    run _var_verificar_dependencias
    [ "$status" -eq 0 ]
}

@test "_var_carregar_config returns 0 when config file exists" {
    printf 'KEY=value\n' > "${CFG_DIR}/.config"
    run _var_carregar_config "${CFG_DIR}/.config"
    [ "$status" -eq 0 ]
}

@test "_var_carregar_config returns 1 when config file missing" {
    run _var_carregar_config "/nonexistent/.config"
    [ "$status" -eq 1 ]
}
