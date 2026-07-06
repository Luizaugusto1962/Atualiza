# Conventions: Atualiza

**Last updated:** 2026-07-06

## Code Style

- **Language:** Pure Bash — no external scripting languages
- **Shebang:** Not used in modules (sourced, not executed). Only `atualiza.sh` has shebang.
- **Strict mode:** `set -euo pipefail` at start of entry scripts
- **Umask:** `077` for secure file creation
- **Indentation:** Tabs (not spaces), consistent across all modules

## Naming Rules

| Scope | Convention | Example |
|---|---|---|
| **Internal functions** | `_snake_case()` | `_carregar_modulos()`, `_validar_ssh()` |
| **Public functions** | `_snake_case()` (all are module-internal) | — |
| **Global constants** | `UPPER_SNAKE_CASE` | `SCRIPT_DIR`, `DEFAULT_SSH_PORTA`, `MAX_LOGIN_ATTEMPTS` |
| **Variables** | lowercase or UPPERCASE depending on scope | `usuario` (global), `arquivo` (local) |
| **Language** | Brazilian Portuguese for function names, variables, comments | `_exibir_mensagem_centralizada()`, not `displayCenteredMessage` |
| **Commands** | Original English names for external tools | `zip`, `unzip`, `wget`, `rsync`, `ssh` |

## Function Conventions

- All functions in modules are prefixed with `_` (internal)
- Functions return `0` for success, `1` for failure
- `local` variables declared at function start
- `declare -gA` for associative arrays (e.g., `REGISTRO_VARIAVEIS`)

## Logging

| Level | Function | Color | Output |
|---|---|---|---|
| Info | `_msg()` | None | General messages |
| Success | `_ok()` | Green (`$VERDE`) | Operation succeeded |
| Warning | `_aviso()` | Yellow (`$AMARELO`) | Non-critical issues |
| Error | `_erro()` | Red (`$VERMELHO`) | Fatal errors |

- Log files: `logs/atualiza.YYYY-MM-DD.log` and `logs/limpando.YYYY-MM-DD.log`
- Log format via `_log()`, `_log_erro()`, `_log_sucesso()` in `utils.sh`

## Error Handling

- `set -e` stops execution on errors
- `set -u` catches undefined variables
- `set -o pipefail` catches pipeline failures
- Traps cleanup on: `EXIT`, `INT`, `TERM`, `QUIT`
- `_limpeza_emergencia()` — emergency cleanup handler
- `_limpar_estado_variaveis()` — variable state cleanup

## Security Conventions

- `.senhas` must be `0600` (checked by `utils.sh:29`)
- `.config` validated before loading — scanner rejects:
  - Lines over 200 chars
  - Characters: `` ` $ ( ) { } [ ] < > & | ; `` (config injection)
  - Command substitution patterns
- Path traversal prevention via `_validar_caminho_seguro()` (`vaievem.sh`)
- SSH host key acceptance via `_ssh_aceitar_novo()` (`utils.sh:690`) — wrapper for `StrictHostKeyChecking=accept-new`

## Module Pattern

```
#!/bin/bash (only in entry point)
set -euo pipefail

_carregar_modulos() { ... }  # Module loading
_inicializar_sistema() { ... }  # System init
_main() { ... }  # Entry

_main "$@"
```

Each module at `binarios/*.sh`:
- Provides a set of related functions
- Sources dependencies via `source` (handled by loader)
- No standalone execution
