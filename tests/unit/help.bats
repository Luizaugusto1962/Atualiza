setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    source "${LIBS_DIR}/help.sh"
}

@test "_verificar_manual returns 1 when manual.txt missing" {
    rm -f "${CFG_DIR}/manual.txt"

    run _verificar_manual
    [ "$status" -eq 1 ]
}

@test "_verificar_manual returns 0 when manual.txt exists" {
    printf "Test manual content\n" > "${CFG_DIR}/manual.txt"

    run _verificar_manual
    [ "$status" -eq 0 ]
}

@test "_exibir_paginado shows content if under page limit" {
    run _exibir_paginado "Hello World" 25
    [ "$output" = "Hello World" ]
}

@test "_exibir_paginado handles multiline content under limit" {
    local content
    content=$(printf "Line 1\nLine 2\nLine 3")

    run _exibir_paginado "$content" 25
    [ "${#lines[@]}" -eq 3 ]
}

@test "_ler_secao_manual returns 1 when manual.txt not found" {
    rm -f "${CFG_DIR}/manual.txt"

    run _ler_secao_manual "MENU_PRINCIPAL"
    [ "$status" -eq 1 ]
}

@test "_ler_secao_manual extracts section correctly" {
    local manual="${CFG_DIR}/manual.txt"
    {
        printf "[MENU_PRINCIPAL]\n"
        printf "Main menu content line 1\n"
        printf "Main menu content line 2\n"
        printf "\n"
        printf "[MENU_PROGRAMAS]\n"
        printf "Program menu content\n"
    } > "$manual"

    run _ler_secao_manual "MENU_PRINCIPAL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Main menu content"* ]]
}

@test "_buscar_manual returns 1 when manual.txt not found" {
    rm -f "${CFG_DIR}/manual.txt"
    run _buscar_manual
    [ "$status" -eq 1 ]
}

@test "_exibir_manual_completo returns 1 when manual.txt not found" {
    rm -f "${CFG_DIR}/manual.txt"

    run _exibir_manual_completo
    [ "$status" -eq 1 ]
}
