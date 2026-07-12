setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum _erro

    export SENHA_FILE="${CFG_DIR}/.senhas"
    printf 'ADMIN:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n' > "$SENHA_FILE"
    printf 'USER1:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8\n' >> "$SENHA_FILE"
    chmod 600 "$SENHA_FILE"

    source "${LIBS_DIR}/auth.sh"
}

@test "_usuario_valido accepts uppercase letters" {
    _usuario_valido "ADMIN"
    [ "$?" -eq 0 ]
}

@test "_usuario_valido accepts numbers" {
    _usuario_valido "USER01"
    [ "$?" -eq 0 ]
}

@test "_usuario_valido accepts dots and underscores" {
    _usuario_valido "USER.NAME_TEST"
    [ "$?" -eq 0 ]
}

@test "_usuario_valido rejects lowercase" {
    run _usuario_valido "admin"
    [ "$status" -eq 1 ]
}

@test "_usuario_valido rejects special chars" {
    run _usuario_valido "USUARIO!"
    [ "$status" -eq 1 ]
}

@test "_usuario_valido rejects empty" {
    run _usuario_valido ""
    [ "$status" -eq 1 ]
}

@test "_hash_senha produces a SHA-256 hash" {
    run _hash_senha "test123"
    [ -n "$output" ]
    [[ "$output" =~ ^[a-f0-9]{64}$ ]]
}

@test "_hash_senha returns consistent hashes for same input" {
    local h1 h2
    h1=$(_hash_senha "password")
    h2=$(_hash_senha "password")
    [ "$h1" = "$h2" ]
}

@test "_hash_senha returns different hashes for different inputs" {
    local h1 h2
    h1=$(_hash_senha "password1")
    h2=$(_hash_senha "password2")
    [ "$h1" != "$h2" ]
}

@test "_obter_hash_usuario finds existing user" {
    run _obter_hash_usuario "ADMIN"
    [ -n "$output" ]
    [[ "$output" =~ ^[a-f0-9]{64}$ ]]
}

@test "_obter_hash_usuario returns empty for non-existing user" {
    run _obter_hash_usuario "NONEXISTENT"
    [ -z "$output" ]
}

@test "_usuario_existe returns 0 for existing user" {
    run _usuario_existe "ADMIN"
    [ "$status" -eq 0 ]
}

@test "_usuario_existe returns 1 for non-existing user" {
    run _usuario_existe "NONEXISTENT"
    [ "$status" -eq 1 ]
}

@test "_usuario_existe returns 1 for empty" {
    run _usuario_existe ""
    [ "$status" -eq 1 ]
}

@test "_hash_senha fails gracefully when algorithm not found" {
    export HASH_ALGORITHM="nonexistent_algo"
    run _hash_senha "test"
    [ "$status" -eq 1 ]
}
