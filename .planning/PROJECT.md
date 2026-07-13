# Atualiza

## What This Is

Atualiza is a modular Bash command-line utility for managing updates of a **SAV** system — it handles programs, files, backups, and libraries for an **IsCOBOL/ISAM** environment. It runs interactively on operator workstations and a SAV server, syncing files to a remote SAV server via SSH/SCP/SFTP/RSYNC and self-updating from GitHub. The application is pure modular Bash (`binarios/*.sh` sourced into a single process), with file-based config (`.config`/`.senhas`), SHA-256 user auth, security-first path/input validation, and a `bats` test suite. Targets Linux/Unix with Bash 4+ and external Unix utilities (`zip`, `unzip`, `tar`, `rsync`, `wget`, `ssh`).

## Core Value

Operators can reliably and safely update SAV programs, files, backups, and libraries — with file transfers and self-updates that never corrupt state or leak credentials.

## Requirements

### Validated

<!-- Inferred from existing code — what the codebase already does and is relied upon. -->

- [x] **CORE-01**: Operator runs `./atualiza.sh` to open the main interactive menu — *Validated (existing)*
- [x] **CORE-02**: System authenticates users via SHA-256 credentials in `configuracoes/.senhas` — *Validated (existing)*
- [x] **CORE-03**: Files sync to remote SAV server via SSH/SCP/SFTP/RSYNC (`binarios/vaievem.sh`) — *Validated (existing)*
- [x] **CORE-04**: System performs full/incremental backup and restore (`binarios/backup.sh`) — *Validated (existing)*
- [x] **CORE-05**: System self-updates by downloading `main.zip` from GitHub (`binarios/baixar.sh`) — *Validated (existing)*
- [x] **CORE-06**: Config is parsed safely from `configuracoes/.config` without `eval` — *Validated (existing)*
- [x] **CORE-07**: Path traversal / injection in file ops is blocked (`_validar_caminho_seguro`) — *Validated (existing)*

### Active

<!-- Goals for the work being planned now. -->

- [ ] **PKG-01**: All module-internal absolute tool paths use `command -v` resolution with fallback (not hardcoded `/usr/bin/...`)
- [ ] **PKG-02**: `package.json` no longer declares a non-existent `index.js` `main` (points to `atualiza.sh` or removed)
- [ ] **LOCK-01**: Concurrent execution is prevented by a lockfile (`flock`/`/var/lock`)
- [ ] **TEST-01**: Core modules have `bats` unit tests runnable via `npm test`
- [ ] **TEST-02**: ShellCheck lints all `.sh` files (CI or pre-commit)
- [ ] **SSH-01**: SSH connection setup is consolidated into a single module (no duplication in `utils.sh` + `vaievem.sh`)
- [ ] **SSH-02**: SSH operations use `ConnectTimeout` / `ServerAliveInterval`
- [ ] **RB-01**: A failed self-update can roll back to the previous state
- [ ] **SEC-01**: Login brute-force is mitigated with lockout/rate-limiting beyond the session-only 3-attempt limit

### Out of Scope

- **Web UI / HTTP API** — the tool is intentionally a TTY CLI; no server component.
- **Database layer** — state is file-based by design; no SQL/NoSQL planned.
- **Rewriting in another language** — staying pure Bash is a hard constraint (legacy IsCOBOL servers).
- **Changing the remote SAV server protocol** — sync semantics must remain compatible.

## Context

- Brownfield codebase mapped via `/gsd-map-codebase --fast` (2026-07-13): `STACK.md`, `INTEGRATIONS.md`, `ARCHITECTURE.md`, `STRUCTURE.md`.
- Prior full map (2026-07-06) flagged concerns in `CONCERNS.md` and `TESTING.md`: no automated tests (High), large monolithic modules, duplicate SSH logic, no lockfile, no SSH timeout, no update rollback, brute-force only session-limited.
- `ARCHITECTURE.md` documents two concrete anti-patterns: hardcoded absolute tool paths (`/usr/bin/zip`, etc.) and a misleading `package.json` `main: index.js`.
- Config already enforces `umask 077`, `0600` perms, config injection defense, and path validation — strong security baseline to preserve.

## Constraints

- **Tech stack**: Pure Bash 4+, no application framework. External CLIs (`zip`, `unzip`, `tar`, `rsync`, `wget`, `ssh`) are required at runtime.
- **Compatibility**: Must run on legacy IsCOBOL/SAV servers with limited tooling — avoid features those environments lack.
- **TTY**: Script requires interactive TTY for the main flow (keep non-interactive paths minimal).
- **Security**: Credentials stay file-based and hashed; never introduce plaintext secrets or `.env`.
- **Testing**: Node only for dev tooling (`bats`, `prettier`); no build step for the Bash app.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Stay pure Bash (no rewrite) | Legacy SAV/IsCOBOL target environment | ✓ Good |
| `gsd-sdk init` skipped — scaffolded manually | No LLM backend (API key) available for the SDK CLI | — Pending |
| Phase 1 = packaging/tool-path + lockfile quick wins | Concrete, low-risk anti-patterns from the map | — Pending |

---
*Last updated: 2026-07-13 after codebase map + manual init*
