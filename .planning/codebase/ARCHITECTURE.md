# Architecture: Atualiza

**Last updated:** 2026-07-06

## System Pattern

Modular monolith — a single Bash process that loads components at startup. The system follows a **loader → modules → menu** pattern:

1. **Loader** (`atualiza.sh`) — argument parser, delegates to entry point
2. **Initializer** (`principal.sh`) — loads modules in order, initializes state
3. **Modules** (`binarios/*.sh`) — self-contained libraries providing function-based APIs
4. **Menu** (`menus.sh`) — interactive user interface dispatching to modules

## Module Loading Order

```
principal.sh: _carregar_modulos()
  └─ 1. constantes.sh     — System-wide constants and defaults
  └─ 2. config.sh         — Config validation, variable registration
  └─ 3. utils.sh          — Shared utilities (logging, display, SSH)
  └─ 4. auth.sh           — User authentication
  └─ 5. lembrete.sh       — Notes and reminders
  └─ 6. vaievem.sh        — Network transfers (SFTP/SCP/rsync)
  └─ 7. sistema.sh        — System information
  └─ 8. baixar.sh         — Self-update mechanism
  └─ 9. arquivos.sh       — File recovery and cleanup
  └─10. backup.sh         — Backup/restore operations
  └─11. programas.sh      — Program update/revert
  └─12. biblioteca.sh     — Library update/revert
  └─13. help.sh           — Help system
  └─14. variaveis.sh      — Variable query/display
  └─15. menus.sh          — Menu system (loaded last, depends on all above)
```

## Data Flow

```
User (terminal)
  │
  ▼
atualiza.sh ──► principal.sh ──► _carregar_modulos() ──► source each module
                                        │
                                        ▼
                                  _inicializar_sistema()
                                        │
                                        ├─ Carrega configurações (.config)
                                        ├─ Verifica dependências (zip, rsync, etc.)
                                        ├─ Executa expurgador diário
                                        ├─ Valida conexão SSH
                                        │
                                        ▼
                                  _login() ←── auth.sh
                                        │
                                        ▼
                                  _principal() ←── menus.sh
                                        │
                                        ├─ Programas  ──► programas.sh
                                        ├─ Biblioteca ──► biblioteca.sh
                                        ├─ Arquivos   ──► arquivos.sh
                                        ├─ Ferramentas ──► sistema.sh / baixar.sh
                                        └─ Ajuda      ──► help.sh
```

## Layer Architecture

| Layer | Responsibility | Key Files |
|---|---|---|
| **Entry** | CLI argument routing | `atualiza.sh` |
| **Bootstrap** | Module loading, initialization | `principal.sh` |
| **Constants** | Fixed values, defaults | `constantes.sh` |
| **Config** | Validation, variable registry | `config.sh` |
| **Utilities** | Logging, display, SSH helpers | `utils.sh` |
| **Auth** | Login, password management | `auth.sh` |
| **Domain** | Business operations (programs, backup, files) | `programas.sh`, `backup.sh`, `arquivos.sh`, `biblioteca.sh` |
| **Network** | SFTP/SCP/rsync transfers | `vaievem.sh` |
| **UI** | Interactive menus | `menus.sh` |
| **Help** | Documentation system | `help.sh` |

## Key Abstractions

- **`_carregar_modulos()`** — ordered module loader with existence/readability checks (`principal.sh:145-190`)
- **`REGISTRO_VARIAVEIS`** — associative array tracking all defined variables (`config.sh:25-27`)
- **`_validar_config_file()`** — security validator preventing command injection in `.config` (`config.sh:461-479`)
- **`_ssh_aceitar_novo()`** — SSH host key acceptance compatible with legacy servers (`utils.sh:690`)
- **`_processar_atualizacao_programas()`** — full update pipeline: backup → extract → move → verify

## Security Architecture

- **Defense in depth:**
  1. `set -euo pipefail` — fail fast on errors
  2. `umask 077` — secure file creation
  3. `.senhas` permission `0600` — owner-only access
  4. `.config` injection scanner — rejects dangerous patterns
  5. Path validation — `_validar_caminho_seguro()` against traversal
  6. Variable registry — `_limpar_estado_variaveis()` on cleanup
  7. Temp file handling — `_limpeza_emergencia()` trap on signals

## Process Model

- Single-threaded synchronous execution
- Background process tracking via `pids[]` array in `biblioteca.sh` for interrupt handling
- Traps: `EXIT`, `INT`, `TERM`, `QUIT` for cleanup
