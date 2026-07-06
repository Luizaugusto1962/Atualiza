# Concerns: Atualiza

**Last updated:** 2026-07-06

## Technical Debt

| Issue | Location | Severity | Notes |
|---|---|---|---|
| Large monolithic modules | `programas.sh` (823 lines), `arquivos.sh` (882 lines), `backup.sh` (953 lines) | Medium | Hard to maintain, high cognitive load |
| No automated tests | Entire codebase | High | Regression risk with every change |
| Hardcoded server/IP | `constantes.sh:DEFAULT_IP_SERVER=189.55.194.179` | Low | Configuration-bound, but IP is hardcoded |
| Mixed Portuguese/English | Some variable names | Low | Convention requires Portuguese, but occasional English names exist |
| Duplicate SSH logic | `utils.sh` and `vaievem.sh` | Medium | SSH connection setup appears in multiple places |
| No version pinning for deps | `package.json` uses `^` ranges | Low | Dev dependencies only, low risk |

## Security

| Issue | Severity | Details |
|---|---|---|
| **Password hash in repo** | Low | `.senhas` with SHA-256 hashes is committed. Hashes are one-way, but salts are not used. |
| **No brute-force protection** | Medium | `MAX_LOGIN_ATTEMPTS=3` is session-only. No rate limiting or lockout. |
| **SSH key in repo** | Medium | Key generation is supported, but key files must not be committed. `.gitignore` handles `*.pub` but not private keys. |
| **Config injection defense** | Good | `_validar_config_file()` blocks dangerous patterns — one of the strongest security measures |
| **Permission enforcement** | Good | `umask 077`, `.senhas` permission checked at startup |

## Performance

| Concern | Severity | Details |
|---|---|---|
| `find` + `zip` for backups | Medium | `_executar_backup_completo()` uses `find` piped to `zip -@`. Large directories could be slow. |
| No parallel operations | Low | Single-threaded by design (sync operations for safety) |
| Progress bar with `pv` not used | Low | `_mostrar_progresso_backup()` uses custom progress, not `pv` |

## Reliability

| Concern | Severity | Details |
|---|---|---|
| No rollback for system update | Medium | `_atualizando()` backups scripts but failure mid-update could leave inconsistent state |
| Single point of failure (GitHub) | Medium | Self-update depends on GitHub availability |
| No lockfile for concurrent execution | Medium | Running two instances could corrupt state |
| No network timeout for SSH | Low | SSH operations could hang if server unresponsive |

## Maintainability

| Concern | Severity | Details |
|---|---|---|
| **No automated tests** | High | Cannot verify changes without manual testing |
| Manual.txt is a single 2039-line file | Medium | Hard to search, maintain; should be split |
| `.config` format is custom | Low | Self-documenting via setup wizard, but no formal schema |
| Hardcoded terminal colors | Low | `tput` used, but some ANSI escape sequences are hardcoded in `config.sh` |

## Compatibility

| Concern | Severity | Details |
|---|---|---|
| Target environment is legacy IsCOBOL | Medium | Must support old systems with limited tools |
| SSH fallback for old servers | Addressed | `_ssh_aceitar_novo()` handles legacy host key behavior |
| UTF-8 / locale assumptions | Low | No explicit locale handling |

## Recommendations

1. **Add automated tests** — Start with `bats` for unit-testing individual functions
2. **Add ShellCheck to CI** — Lint all `.sh` files on commit
3. **Add lockfile** — Prevent concurrent execution (`/var/lock/` or `flock`)
4. **Split manual.txt** — Break into separate markdown files per section
5. **Extract SSH logic** — Consolidate all SSH operations into `utils.sh`
6. **Add update rollback** — Ensure failed self-update can revert to previous state
7. **Add timeout to SSH** — Use `ConnectTimeout` and `ServerAliveInterval`
