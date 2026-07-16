# Requirements: Atualiza

**Defined:** 2026-07-13
**Core Value:** Operators can reliably and safely update SAV programs, files, backups, and libraries — with file transfers and self-updates that never corrupt state or leak credentials.

## v1 Requirements

Requirements for the current improvement cycle. Each maps to a roadmap phase.

### Packaging & Tool Resolution

- [ ] **PKG-01**: All module-internal absolute tool paths (e.g. `/usr/bin/zip`, `/usr/bin/unzip`, `/usr/bin/find`, `/usr/bin/who`) are resolved via `command -v` with a fallback, consistent with how `tar`/`ssh` are already handled in `constantes.sh`.
- [ ] **PKG-02**: `package.json` no longer declares a non-existent `index.js` `main` entry (point `main` to `atualiza.sh` or remove it); keep Node only for dev tooling.

### Concurrency & Resilience

- [ ] **LOCK-01**: Concurrent execution of the tool is prevented via a lockfile (`flock` on a lock file, or `/var/lock/atualiza.lock`) so two instances cannot corrupt state.

### Testing Foundation

- [ ] **TEST-01**: Core modules (`constantes.sh`, `auth.sh`, `utils.sh`, `vaievem.sh`, `backup.sh`) have `bats` unit tests that run via `npm test`.
- [ ] **TEST-02**: ShellCheck lints all `.sh` files, wired into CI (or a pre-commit hook) so lint failures block merges.

### SSH Consolidation & Safety

- [ ] **SSH-01**: SSH connection setup logic duplicated across `utils.sh` and `vaievem.sh` is consolidated into a single module/function.
- [ ] **SSH-02**: SSH operations apply `ConnectTimeout` and `ServerAliveInterval` so they don't hang indefinitely on an unresponsive server.

### Update Rollback & Auth Hardening

- [ ] **RB-01**: A failed self-update (`binarios/baixar.sh`) can roll back to the previous working state.
- [ ] **SEC-01**: Login brute-force is mitigated with lockout/rate-limiting that persists beyond the session-only `MAX_LOGIN_ATTEMPTS=3`.

## v2 Requirements

Deferred to a later cycle. Tracked but not in the current roadmap.

### Maintainability

- [ ] **DOC-01**: `configuracoes/manual.txt` (2039 lines) is split into per-section Markdown files.
- [ ] **REF-01**: Large monolithic modules (`programas.sh` 823, `arquivos.sh` 882, `backup.sh` 953) are decomposed into smaller focused modules.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Web UI / HTTP API | Tool is intentionally a TTY CLI; no server component |
| Database layer | State is file-based by design |
| Rewrite in non-Bash language | Legacy IsCOBOL/SAV target requires pure Bash |
| Change remote SAV sync protocol | Must stay compatible with existing server |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PKG-01 | Phase 1 | Pending |
| PKG-02 | Phase 1 | Pending |
| LOCK-01 | Phase 1 | Pending |
| TEST-01 | Phase 2 | Pending |
| TEST-02 | Phase 2 | Pending |
| SSH-01 | Phase 3 | Pending |
| SSH-02 | Phase 3 | Pending |
| RB-01 | Phase 4 | Pending |
| SEC-01 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-13*
*Last updated: 2026-07-13 after manual init (codebase map)*
