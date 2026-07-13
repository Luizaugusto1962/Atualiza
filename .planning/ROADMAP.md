# Roadmap: Atualiza

## Overview

Atualiza is a mature, working Bash CLI, but the codebase map surfaced concrete technical debt: two anti-patterns (hardcoded tool paths, misleading `package.json` `main`), no automated tests, no concurrency guard, duplicated SSH logic, no SSH timeout, no update rollback, and session-only brute-force limits. This roadmap converts those findings into four coherent phases — starting with quick, low-risk packaging/tool-path wins, then building a test foundation, consolidating SSH, and finally adding resilience and auth hardening. Each phase preserves the existing security baseline (`umask 077`, `0600` perms, config injection defense, path validation).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4): Planned milestone work
- Decimal phases (2.1, 3.1): Urgent insertions if needed later

- [ ] **Phase 1: Empacotamento e Resolução de Ferramentas** - Fix the two documented anti-patterns and add a concurrency lockfile
- [ ] **Phase 2: Fundação de Testes** - Add `bats` unit tests and ShellCheck linting in CI
- [ ] **Phase 3: Consolidação de SSH** - Unify SSH setup and add connection timeouts
- [ ] **Phase 4: Resiliência e Segurança de Autenticação** - Self-update rollback and persistent brute-force lockout

## Phase Details

### Phase 1: Empacotamento e Resolução de Ferramentas
**Goal**: Eliminate the two documented anti-patterns (hardcoded absolute tool paths; misleading `package.json` `main`) and prevent concurrent runs from corrupting state via a lockfile.
**Depends on**: Nothing (first phase)
**Requirements**: [PKG-01, PKG-02, LOCK-01]
**Success Criteria** (what must be TRUE):
  1. No module references tools by absolute path (`/usr/bin/zip`, etc.); resolution uses `command -v` with fallback like `tar`/`ssh` already do.
  2. `package.json` no longer points `main` at a non-existent `index.js` (updated or removed), and `npm test` still works.
  3. Launching a second instance while one is running is blocked by a lockfile and reports a clear message.
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — PKG-01: Resolve tool paths via `command -v` in `constantes.sh` and harden consumer redeclarations
- [ ] 01-02-PLAN.md — PKG-02: Fix `package.json` `main`/`type` for a Bash project
- [ ] 01-03-PLAN.md — LOCK-01: Add concurrency lockfile guard in `principal.sh`

### Phase 2: Fundação de Testes
**Goal**: Establish an automated test foundation so future changes can be verified without manual testing.
**Depends on**: Phase 1
**Requirements**: [TEST-01, TEST-02]
**Success Criteria** (what must be TRUE):
  1. `npm test` runs `bats` unit tests covering `constantes.sh`, `auth.sh`, `utils.sh`, `vaievem.sh`, `backup.sh` and exits non-zero on failure.
  2. ShellCheck runs against all `.sh` files in CI (or pre-commit) and fails the build on violations.
**Plans**: TBD

Plans:
- [ ] 02-01: Add `bats` unit tests for core modules
- [ ] 02-02: Wire ShellCheck into CI / pre-commit hook

### Phase 3: Consolidação de SSH
**Goal**: Remove duplicated SSH setup and make remote operations resilient to unresponsive servers.
**Depends on**: Phase 2
**Requirements**: [SSH-01, SSH-02]
**Success Criteria** (what must be TRUE):
  1. SSH connection/key setup lives in a single module/function used by both `utils.sh` and `vaievem.sh` (no duplication).
  2. SSH transfers apply `ConnectTimeout` and `ServerAliveInterval` so they time out instead of hanging.
**Plans**: TBD

Plans:
- [ ] 03-01: Consolidate SSH setup into one module
- [ ] 03-02: Add SSH timeouts to transfer functions

### Phase 4: Resiliência e Segurança de Autenticação
**Goal**: Make self-updates safe to fail and harden login against brute-force across sessions.
**Depends on**: Phase 3
**Requirements**: [RB-01, SEC-01]
**Success Criteria** (what must be TRUE):
  1. A self-update that fails mid-apply can roll back to the previous working scripts.
  2. Repeated failed logins trigger a lockout/rate-limit that persists beyond the current session.
**Plans**: TBD

Plans:
- [ ] 04-01: Implement self-update rollback in `baixar.sh`
- [ ] 04-02: Add persistent brute-force lockout in `auth.sh`

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Empacotamento e Resolução de Ferramentas | 0/3 | Not started | - |
| 2. Fundação de Testes | 0/2 | Not started | - |
| 3. Consolidação de SSH | 0/2 | Not started | - |
| 4. Resiliência e Segurança de Autenticação | 0/2 | Not started | - |
