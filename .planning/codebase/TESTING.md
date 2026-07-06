# Testing: Atualiza

**Last updated:** 2026-07-06

## Testing Approach

This project has **no automated test suite**. Testing is manual/operational:

- **Manual testing** — Users run the system in production environments
- **Dry-run validation** — `--setup` creates `.config` with validation prompts
- **SSH connectivity test** — `_validar_ssh()` performs diagnostic checks before operations
- **Space validation** — `_validar_pre_backup()` checks disk space before backup
- **Dependency check** — `_check_instalado()` / `_checar_dependencias()` verifies required tools

## Validation Mechanisms

| Mechanism | Location | What It Validates |
|---|---|---|
| Config injection scanner | `config.sh:461-479` | `.config` file safety |
| SSH diagnostics | `config.sh:validar_ssh` | Connection, auth, host key |
| Pre-backup validation | `backup.sh:validar_pre_backup` | Disk space, directories, zip availability |
| Path security | `vaievem.sh:validar_caminho_seguro` | Path traversal prevention |
| Module loader checks | `principal.sh:caminho_modulo` | File exists, readable, non-empty |
| Login attempt limit | `auth.sh:_login` | Max 3 failed attempts |
| Hash verification | `auth.sh` | SHA-256 password matching |
| Integrity check | `programas.sh:validar_integridade_backup` | Backup file integrity |

## Developer Tooling

| Tool | Purpose | Config Location |
|---|---|---|
| **Prettier** | Code formatting | `.prettierrc`, `.vscode/prettierrc.json` |
| **Lint-staged** | Pre-commit formatting | `package.json` — runs Prettier on all staged files |
| **Husky** | Git hooks | `package.json` — triggers lint-staged |
| **ShellCheck** | Bash linting | `.vscode/settings.json` — lint on save |
| **bashdb** | Debugger | `.vscode/launch.json` — 4 debug profiles |

## CI/CD

- **No CI pipeline configured** — no GitHub Actions, no CI config
- Git hooks provide pre-commit formatting only

## Coverage

- **Automated unit tests:** None
- **Integration tests:** None
- **End-to-end tests:** Manual only
- **Coverage reporting:** None

## Improvement Opportunities

- Add ShellCheck to a pre-commit hook (currently editor-only)
- Consider `bats` (Bash Automated Testing System) for unit testing
- Add smoke test for module loading (`principal.sh`)
- Add test for config validation edge cases
