# Architecture

**Analysis Date:** 2026-07-13

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Entry Point: atualiza.sh                     │
│   Routes CLI args: (none)=principal | --setup=setup.sh | --cadastro  │
└───────────────────────────────────┬─────────────────────────────────┘
                                     │ sources
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   binarios/principal.sh  (bootstrap)                  │
│   Defines dirs, loads modules in order, _inicializar_sistema, _main   │
└───────────────────────────────────┬─────────────────────────────────┘
                                     │ sources (ordered)
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Module Layer (binarios/*.sh)                    │
│  constantes → config → utils → auth → lembrete → vaievem → sistema →  │
│  baixar → arquivos → backup → programas → biblioteca → help →         │
│  variaveis → menus                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                     │ reads / writes
                                     ▼
┌──────────────────────────┐   ┌──────────────────────────────────────┐
│ configuracoes/ (.config,  │   │ Storage: local dirs + remote SAV     │
│ .senhas, manual.txt)      │   │ server via SSH/SCP/SFTP/RSYNC        │
└──────────────────────────┘   └──────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `atualiza.sh` | CLI dispatcher; arg routing; sets `PLIBS_DIR`/`SCRIPT_DIR` | `atualiza.sh` |
| `principal.sh` | Bootstrap, module loader, system init, `_main` loop | `binarios/principal.sh` |
| `constantes.sh` | System constants, config parser, network/security defaults | `binarios/constantes.sh` |
| `config.sh` | Load/validate `.config`, SSH connectivity check (`_check_instalado`) | `binarios/config.sh` |
| `utils.sh` | Generic helpers (logging, path validation, dependency check) | `binarios/utils.sh` |
| `auth.sh` | User login, sha256 credential verification | `binarios/auth.sh` |
| `lembrete.sh` | Reminder system | `binarios/lembrete.sh` |
| `vaievem.sh` | Network sync: scp/sftp/rsync/ssh transfer functions | `binarios/vaievem.sh` |
| `sistema.sh` | System info, external IP, environment detection | `binarios/sistema.sh` |
| `baixar.sh` | Self-update download via `wget` from GitHub | `binarios/baixar.sh` |
| `arquivos.sh` | File management, zip/tar, `jutil` ISAM util | `binarios/arquivos.sh` |
| `backup.sh` | Backup creation/restore (zip) | `binarios/backup.sh` |
| `programas.sh` | Program update/revert management | `binarios/programas.sh` |
| `biblioteca.sh` | Library update/revert (tar.gz/zip) | `binarios/biblioteca.sh` |
| `help.sh` | Help system | `binarios/help.sh` |
| `variaveis.sh` | Variable/constant query | `binarios/variaveis.sh` |
| `menus.sh` | Interactive menu rendering & dispatch | `binarios/menus.sh` |
| `setup.sh` | Initial system configuration wizard | `binarios/setup.sh` |
| `cadastro.sh` | User registration | `binarios/cadastro.sh` |
| `menus.sh` | Main menu (`_principal`) | `binarios/menus.sh` |

## Pattern Overview

**Overall:** Modular monolithic Bash script — all modules are sourced (`. file`) into one process; functions are global. No subprocess isolation between modules.

**Key Characteristics:**
- Strict mode `set -euo pipefail` in every module.
- Security-first: `umask 077`, `0600`/`0700` perms, input sanitization (`_validar_caminho_seguro` rejects `;|&$`\`<>\"'` and `/..`).
- Centralized constants in `constantes.sh`; config parsed safely (rejects values containing `$\`;` — `binarios/constantes.sh:73`).
- Defensive module loading with cumulative error reporting (`_carregar_modulos`, `binarios/principal.sh:174-212`).

## Layers

**Bootstrap / Entry:**
- Purpose: arg routing + module orchestration.
- Location: `atualiza.sh`, `binarios/principal.sh`
- Depends on: all modules in `binarios/`
- Used by: operator via terminal.

**Module layer:**
- Purpose: feature implementation as sourced functions.
- Location: `binarios/*.sh`
- Contains: business logic (backup, sync, programs, library).
- Depends on: `constantes.sh` exports, external CLIs, `configuracoes/`.
- Used by: `principal.sh` (loaded in fixed order).

**Configuration / State layer:**
- Purpose: persisted config & credentials.
- Location: `configuracoes/.config`, `configuracoes/.senhas`, local working dirs.
- Depends on: filesystem.
- Used by: `constantes.sh`, `auth.sh`, `config.sh`.

## Data Flow

### Primary Request Path (interactive run)

1. Operator runs `./atualiza.sh` → routes to `binarios/principal.sh` (`atualiza.sh:64`).
2. `principal.sh` `_main` → `_inicializar_sistema` loads modules + config + `_check_instalado` (`binarios/principal.sh:220-255`).
3. `_login` authenticates from `configuracoes/.senhas` (`binarios/auth.sh`).
4. `_principal` menu renders; user selects action (`binarios/menus.sh`).
5. Selected module function runs (e.g. backup/program/library), reads/writes local dirs and optionally syncs via `binarios/vaievem.sh` to remote SAV server.
6. `trap '_resetando' EXIT` cleans temp on exit (`binarios/principal.sh:264`).

### Self-Update Flow

1. `binarios/baixar.sh` calls `wget` to fetch `main.zip` from `GITHUB_UPDATE_URL`.
2. Archive extracted into `DEFAULT_RECEBE_DIR`, applied to working dirs.

### Remote Sync Flow

1. `binarios/vaivem.sh` functions build ssh/sftp/scp/rsync command arrays with key options (`_adicionar_opcoes_chave`).
2. Transfer to `DESTINO_SERVER` / `DESTINO_BIBLIOTECA` on remote host.

**State Management:** Global shell variables/functions. Constants exported (`export` in `constantes.sh:265-281`). No persistence beyond files.

## Key Abstractions

**Module loader (`_caminho_modulo` / `_carregar_modulos`):**
- Purpose: safe dynamic sourcing with existence/readability/non-empty checks.
- Examples: `binarios/principal.sh:141-212`
- Pattern: fixed ordered array of module filenames.

**Secure config parser (`_carregar_config_seguro`):**
- Purpose: parse `.config` key=value without `eval`/sourcing; rejects dangerous values.
- Examples: `binarios/constantes.sh:41-84`
- Pattern: line-by-line read + regex validation + `declare -g`.

## Entry Points

**`atualiza.sh`:**
- Location: `atualiza.sh`
- Triggers: operator in terminal (interactive TTY required).
- Responsibilities: set dirs, route `--setup` / `--cadastro` / default.

**`binarios/principal.sh`:**
- Location: `binarios/principal.sh`
- Triggers: sourced by `atualiza.sh` (default path).
- Responsibilities: bootstrap whole system, run `_main`.

## Architectural Constraints

- **Threading:** Single process, single-threaded Bash. No parallelism within a run.
- **Global state:** All functions/vars are global after sourcing. Exported constants in `constantes.sh`. Shared mutable state in module-level arrays (e.g. `arquivos_encontrados` in `vaievem.sh:14`).
- **Circular imports:** Not possible by design — modules are leaf logic sourced once in a fixed order; no module sources another.
- **TTY requirement:** Script refuses non-interactive stdin (`atualiza.sh:20-23`).
- **Platform:** Linux/Unix only; hardcoded `/usr/bin/zip`, `/usr/bin/unzip`, `/usr/bin/find`, `/usr/bin/who` paths (`constantes.sh:214-218`).

## Anti-Patterns

### Hardcoded absolute tool paths
**What happens:** Tools referenced by absolute path (`/usr/bin/zip`) instead of `command -v` resolution.
**Why it's wrong:** Breaks on systems where tools live elsewhere (e.g. macOS Homebrew).
**Do this instead:** Resolve via `command -v` with fallback, consistent with how `tar`/`ssh` are already handled (`constantes.sh:216`).

### Optional `index.js` main in package.json
**What happens:** `package.json` declares `"main": "index.js"` but no `index.js` exists.
**Why it's wrong:** Misleading — the app is Bash, not Node.
**Do this instead:** Remove `main`/`type` or point to `atualiza.sh`; keep Node only for dev tooling.

## Error Handling

**Strategy:** `set -euo pipefail` + explicit status checks. Functions return 0/1; `_erro` prints to stderr. Module load failures accumulate and abort init.

**Patterns:**
- `if ! cmd; then _erro "..."; return 1; fi`
- `trap '_resetando' EXIT` for cleanup (`principal.sh:264`).
- Defensive config parsing rejects injection (`constantes.sh:73`).

## Cross-Cutting Concerns

**Logging:** `_log` / `_log_erro` / `_log_sucesso` writing to dated files under `logs/` (`constantes.sh:242-244`).

**Validation:** `_validar_caminho_seguro` (path traversal/special-char rejection) in `binarios/vaievem.sh:20-28`; `_carregar_config_seguro` value sanitization.

**Authentication:** Custom sha256 user auth (`auth.sh`) + SSH key auth for remote (`vaievem.sh`).

---

*Architecture analysis: 2026-07-13*
