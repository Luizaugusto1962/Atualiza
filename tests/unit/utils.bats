setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum

    source "${LIBS_DIR}/utils.sh"
}

@test "_trim removes leading whitespace" {
    run _trim "  hello"
    [ "$output" = "hello" ]
}

@test "_trim removes trailing whitespace" {
    run _trim "hello  "
    [ "$output" = "hello" ]
}

@test "_trim removes both sides whitespace" {
    run _trim "  hello world  "
    [ "$output" = "hello world" ]
}

@test "_trim handles empty string" {
    run _trim ""
    [ "$output" = "" ]
}

@test "_trim handles tabs" {
    run _trim "$(printf '\t\thello\t')"
    [ "$output" = "hello" ]
}

@test "_upper converts lowercase to uppercase" {
    run _upper "hello"
    [ "$output" = "HELLO" ]
}

@test "_upper handles mixed case" {
    run _upper "Hello World"
    [ "$output" = "HELLO WORLD" ]
}

@test "_upper handles already uppercase" {
    run _upper "HELLO"
    [ "$output" = "HELLO" ]
}

@test "_upper handles numbers and special chars" {
    run _upper "abc123-def"
    [ "$output" = "ABC123-DEF" ]
}

@test "_upper handles empty string" {
    run _upper ""
    [ "$output" = "" ]
}

@test "_validar_nome_programa accepts valid uppercase letters" {
    _validar_nome_programa "PROGRAMA"
    [ "$?" -eq 0 ]
}

@test "_validar_nome_programa accepts numbers" {
    _validar_nome_programa "PROG01"
    [ "$?" -eq 0 ]
}

@test "_validar_nome_programa rejects lowercase" {
    run _validar_nome_programa "programa"
    [ "$status" -eq 1 ]
}

@test "_validar_nome_programa rejects special chars" {
    run _validar_nome_programa "PROG-RAMA"
    [ "$status" -eq 1 ]
}

@test "_validar_nome_programa rejects empty" {
    run _validar_nome_programa ""
    [ "$status" -eq 1 ]
}

@test "_formatar_tempo formats seconds only" {
    run _formatar_tempo "30"
    [ "$output" = "30s" ]
}

@test "_formatar_tempo formats minutes and seconds" {
    run _formatar_tempo "150"
    [ "$output" = "2m 30s" ]
}

@test "_formatar_tempo handles zero" {
    run _formatar_tempo "0"
    [ "$output" = "0s" ]
}

@test "_formatar_tempo handles exactly 60 seconds" {
    run _formatar_tempo "60"
    [ "$output" = "1m 0s" ]
}

@test "_ssh_aceitar_novo returns yes" {
    run _ssh_aceitar_novo
    [ "$output" = "yes" ]
}

@test "_obter_colunas returns a number" {
    run _obter_colunas
    [[ "$output" =~ ^[0-9]+$ ]]
}
