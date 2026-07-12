setup_file() {
    load '../helpers/setup.bash'
    setup_safe_env
}

setup() {
    load '../helpers/setup.bash'
    setup_safe_env
    export -f tput sha256sum date stat find
    export LOG_ATU="${DEFAULT_LOGS_DIR}/atualiza.test.log"

    source "${LIBS_DIR}/backup.sh"
}

@test "_validar_backup_criado fails for non-existent file" {
    run _validar_backup_criado "/nonexistent/backup.zip"
    [ "$status" -eq 1 ]
}

@test "_validar_backup_criado fails for very small file" {
    local small_file="${DEFAULT_BASEBACKUP_DIR}/small.zip"
    printf "tiny" > "$small_file"

    run _validar_backup_criado "$small_file"
    [ "$status" -eq 1 ]
}

@test "_validar_backup_criado passes for valid zip file" {
    local valid_file="${DEFAULT_BASEBACKUP_DIR}/valid.zip"
    # Must be >= 100 bytes to pass _validar_backup_criado size check
    printf 'PK\x03\x04%.0s' {1..50} > "$valid_file"

    chmod 644 "$valid_file"

    if command -v zip >/dev/null 2>&1; then
        run _validar_backup_criado "$valid_file"
        [ "$status" -eq 0 ]
    else
        skip "zip command not available"
    fi
}

@test "_verificar_backups_recentes returns 1 when no recent backups" {
    run _verificar_backups_recentes
    [ "$status" -eq 1 ]
}

@test "_verificar_backups_recentes returns 0 when recent backup exists" {
    local recent_file="${DEFAULT_BASEBACKUP_DIR}/${CFG_EMPRESA}_test_backup.zip"
    printf "content" > "$recent_file"

    find() {
        if [[ "$*" == *" -ctime -2"* ]]; then
            printf "%s\n" "$recent_file"
            return 0
        fi
        return 1
    }
    export -f find

    run _verificar_backups_recentes
    [ "$status" -eq 0 ]
}
