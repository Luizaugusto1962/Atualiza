# Technology Stack

**Analysis Date:** 2026-07-13

## Languages

**Primary:**
- Bash (shell script) — Entire application logic. Entry point `atualiza.sh`, modules in `binarios/*.sh`. Uses `set -euo pipefail`, `declare -a`/`declare -g`, parameter expansion, `[[ ... ]]` tests.
- Used everywhere: `atualiza.sh`, `binarios/*.sh`, `configuracoes/*` (limpetmp, indexar scripts), `tests/helpers/setup.bash`.

**Secondary:**
- Node.js / JavaScript — Only for dev tooling (test runner + formatter). Declared in `package.json` with `"type": "commonjs"`, `"main": "index.js"` (no `index.js` present in the repo — placeholder only).

## Runtime

**Environment:**
- GNU Bash (Linux/Unix). Script enforces interactive TTY (`atualiza.sh:20-23`) and `LC_ALL=C`.
- External Unix utilities required at runtime: `zip`, `unzip`, `tar`, `sha256sum`/`md5sum`, `ssh`, `scp`, `sftp`, `rsync`, `wget`, `curl`.
- `iscclient` / `jutil` — IsCOBOL/ISAM tooling from `${RAIZ}/savisc/iscobol/bin/` (`binarios/constantes.sh:229-232`).

**Package Manager:**
- npm (Node) — used only for dev dependencies (`bats`, `prettier`).
- Lockfile: `package-lock.json` present (1146 bytes — minimal, dev-only).

## Frameworks

**Core:**
- None (no application framework). Pure modular Bash sourced via `.` (dot) into a single process.

**Testing:**
- `bats` ^1.13.0 — Bash Automated Testing System (`package.json` scripts: `test`, `test:unit`, `test:integration`).
- `prettier` ^3.9.5 — formatter (`devDependencies`).

**Build/Dev:**
- npm scripts only:
  - `npm test` → `npx bats -r tests/`
  - `npm run test:unit` → `npx bats -r tests/unit`
  - `npm run test:integration` → `npx bats -r tests/integration`
- No build/compile step for the Bash application itself.

## Key Dependencies

**Critical (external CLIs shelled out to):**
- `zip` / `unzip` — archive creation/extraction (`binarios/constantes.sh:214-215`, `binarios/backup.sh`, `binarios/arquivos.sh`).
- `tar` — newer backup/restore pipeline (`binarios/biblioteca.sh`, `binarios/constantes.sh:216`).
- `ssh` / `scp` / `sftp` / `rsync` — remote sync to SAV server (`binarios/vaievem.sh`, `binarios/config.sh`).
- `wget` — self-update download from GitHub (`binarios/baixar.sh:211`).
- `sha256sum` — password hashing / integrity (`binarios/auth.sh`, `binarios/constantes.sh:179`).
- `iscclient` / `jutil` — IsCOBOL ISAM compile/util helpers (`binarios/constantes.sh:230-232`, `binarios/arquivos.sh:589-621`).

**Infrastructure:**
- None beyond the SAV remote server and GitHub. No databases, queues, or cloud SDKs.

## Configuration

**Environment:**
- Configuration is file-based, NOT environment variables. Primary config: `configuracoes/.config` (key=value, parsed by `_carregar_config_seguro` in `binarios/constantes.sh:41-84`).
- Credentials: `configuracoes/.senhas` — username:sha256 pairs (`binarios/auth.sh`).
- Sensitive files use `umask 077` and `0600` permission constants (`binarios/constantes.sh:162`).
- Overridable constants exposed via env vars with `${VAR:-default}` fallbacks (e.g. `CFG_DIR`, `LIBS_DIR`, `DEFAULT_IP_SERVER`).

**Build:**
- No build config. Only `package.json`, `.prettierrc`, `cspell.json`, `opencode.jsonc` at root.
- `.prettierrc` present (4 bytes — near-empty, default prettier settings).

## Platform Requirements

**Development:**
- Linux/Unix with Bash 4+. Node.js + npm only to run the bats test suite.
- External tools `zip unzip rsync wget` verified by `_check_instalado` (`binarios/utils.sh:585-588`).

**Production:**
- Target: a SAV/IsCOBOL server environment. Remote server `DEFAULT_IP_SERVER=189.55.194.179`, port `41122`, user `atualiza`, SSH key at `~/.ssh/id_rsa_atualiza`.
- Deploy is via Git/GitHub (`git+https://github.com/Luizaugusto1962/Atualiza.git`); self-update downloads `main.zip` from GitHub (`binarios/constantes.sh:169`).

---

*Stack analysis: 2026-07-13*
