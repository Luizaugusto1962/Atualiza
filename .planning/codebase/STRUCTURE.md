# Codebase Structure

**Analysis Date:** 2026-07-13

## Directory Layout

```
Atualiza/
├── atualiza.sh          # CLI entry point / dispatcher
├── package.json         # Node dev tooling (bats, prettier) + test scripts
├── package-lock.json    # npm lockfile (dev-only)
├── .prettierrc          # formatter config (near-empty)
├── cspell.json          # spell-check config
├── opencode.jsonc       # opencode config
├── AGENTS.md            # Agent operating rules
├── README.md            # Project overview
├── relatorio_revisao_logica.md  # Logic review report
├── binarios/            # All Bash modules (sourced by principal.sh)
├── configuracoes/       # Config, credentials, manual, helper scripts
├── tests/               # bats test suite (unit + integration + helpers + fixtures)
├── docs/                # Developer/ops documentation (Markdown)
├── node_modules/        # Dev dependencies (bats, prettier)
├── logs/                # Runtime logs (created at runtime)
├── backups/ biblioteca/ programas/ enviar/ receber/  # Runtime working dirs
└── .planning/           # GSD planning artifacts (codebase maps, etc.)
```

## Directory Purposes

**`binarios/`:**
- Purpose: Core application — every Bash module that implements features.
- Contains: `*.sh` modules (constantes, config, utils, auth, lembrete, vaievem, sistema, baixar, arquivos, backup, programas, biblioteca, help, variaveis, menus, principal, setup, cadastro).
- Key files: `principal.sh` (bootstrap), `constantes.sh` (constants/config parser).

**`configuracoes/`:**
- Purpose: Persisted configuration and credentials.
- Contains: `.config` (system config), `.senhas` (sha256 user credentials), `manual.txt` (operator manual), `indexar`, `variosarquivos`, `limpetmp` (helper scripts/config).

**`tests/`:**
- Purpose: bats test suite.
- Contains: `unit/*.bats` (auth, backup, config, constantes, help, programas, utils, vaivem, variaveis), `integration/*.bats` (atualiza, principal), `helpers/setup.bash`, `fixtures/`.

**`docs/`:**
- Purpose: Human documentation.
- Contains: `ARCHITECTURE.md`, `CONFIGURATION.md`, `DEVELOPMENT.md`, `GETTING-STARTED.md`, `TESTING.md`.

## Key File Locations

**Entry Points:**
- `atualiza.sh`: CLI dispatcher.
- `binarios/principal.sh`: bootstrap / module orchestrator.

**Configuration:**
- `configuracoes/.config`: system settings (key=value).
- `configuracoes/.senhas`: user credentials (sha256).
- `package.json`: Node dev tooling + test scripts.

**Core Logic:**
- `binarios/constantes.sh`: constants + config parser.
- `binarios/vaievem.sh`: remote sync (ssh/scp/sftp/rsync).
- `binarios/backup.sh`, `binarios/programas.sh`, `binarios/biblioteca.sh`: feature logic.

**Testing:**
- `tests/unit/`, `tests/integration/`: bats specs.
- `tests/helpers/setup.bash`: shared test setup.

## Naming Conventions

**Files:**
- Modules: lowercase descriptive names + `.sh` (e.g. `backup.sh`, `vaievem.sh`) in `binarios/`.
- Tests: `<module>.bats` mirroring module name, in `tests/unit/`.
- Hidden config: leading dot (`.config`, `.senhas`).

**Functions:**
- Internal/private helpers: leading underscore (`_carregar_modulos`, `_login`, `_validar_caminho_seguro`).
- Exported/public constants: `UPPER_SNAKE_CASE` (`CFG_DIR`, `DEFAULT_IP_SERVER`, `HASH_ALGORITHM`).

**Directories:**
- Lowercase descriptive names (`binarios`, `configuracoes`, `backups`, `biblioteca`).

## Where to Add New Code

**New Feature (a command/action):**
- Implementation: `binarios/<feature>.sh` following the module header convention (shebang, `set -euo pipefail`, `# SISTEMA SAV` block).
- Register in load order: add to `modulos` array in `binarios/principal.sh:175-191`.
- Wire into menu: `binarios/menus.sh` (`_principal`).

**New Constant / Config Key:**
- Add `export` in `binarios/constantes.sh` (with `${VAR:-default}` fallback).
- If user-facing config, document in `configuracoes/.config` parsing expectations.

**Utilities / Shared Helpers:**
- Add to `binarios/utils.sh` (logging, validation, dependency checks).

**Tests:**
- Unit: `tests/unit/<module>.bats` (mirror module name).
- Integration: `tests/integration/*.bats`.
- Shared setup: `tests/helpers/setup.bash`.
- Run: `npm test`, `npm run test:unit`, `npm run test:integration`.

**Documentation:**
- `docs/<TOPIC>.md`.

## Special Directories

**`node_modules/`:**
- Purpose: Dev dependencies (bats, prettier).
- Generated: Yes (npm install).
- Committed: No (gitignored).

**`logs/`, `backups/`, `biblioteca/`, `programas/`, `enviar/`, `receber/`:**
- Purpose: Runtime working/data directories (created by `principal.sh` if missing).
- Generated: Yes (runtime).
- Committed: No.

**`.planning/`:**
- Purpose: GSD planning + codebase map outputs.
- Generated: Yes (by mapper).
- Committed: Per repo policy.

---

*Structure analysis: 2026-07-13*
