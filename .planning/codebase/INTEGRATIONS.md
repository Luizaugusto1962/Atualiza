# External Integrations

**Analysis Date:** 2026-07-13

## APIs & External Services

**Remote SAV server (file sync target):**
- Host: `DEFAULT_IP_SERVER` (default `189.55.194.179`), port `DEFAULT_SSH_PORTA` (default `41122`), user `DEFAULT_SSH_USER` (default `atualiza`).
- Auth: SSH key (`DEFAULT_CHAVE_SSH` = `~/.ssh/id_rsa_atualiza`); optional password auth via `CFG_CHAVE_SSH=s/n` toggle.
- Transports used: `scp`, `sftp`, `rsync`, `ssh` — implemented in `binarios/vaievem.sh`.
- Defined in `binarios/constantes.sh:168-174,223-224`.

**GitHub (self-update source):**
- Self-update downloads `https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip` via `wget` (`binarios/baixar.sh:211`, `binarios/constantes.sh:169`).
- Repository: `git+https://github.com/Luizaugusto1962/Atualiza.git` (`package.json`).

**External IP lookup (diagnostic only):**
- `curl -s ipecho.net/plain` in `binarios/sistema.sh:86-87` (best-effort, non-critical).

## Data Storage

**Databases:**
- None (no SQL/NoSQL). State is file-based on local disk and remote SSH targets.

**File Storage:**
- Local working dirs defined as constants in `binarios/constantes.sh:199-209`:
  - `backups/anterior`, `backups/base`, `biblioteca/atual`, `biblioteca/anterior`, `programas/atual`, `programas/anterior`, `enviar`, `receber`, `logs`.
- Remote destinations:
  - `DESTINO_SERVER=/u/varejo/man/`
  - `DESTINO_BIBLIOTECA=/u/varejo/trans_pc/`
  - Offline portal: `${RAIZ}/portalsav/Atualiza` (`ACESSO_OFF`, `CFG_PORTALSAV`).

**Caching:**
- None explicit. Daily cleanup via `_executar_expurgador_diario` (`binarios/principal.sh:249`); `configuracoes/limpetmp` script.

## Authentication & Identity

**Auth Provider:**
- Custom, local. Credentials stored in `configuracoes/.senhas` as `USERNAME:sha256hash` lines (`binarios/auth.sh`).
- Login flow: `_login` in `binarios/auth.sh`; max attempts `MAX_LOGIN_ATTEMPTS=3`; hash algorithm `HASH_ALGORITHM=sha256sum`.
- Remote server access uses SSH key-based auth (`binarios/vaievem.sh:_usar_chave_ssh`, `_adicionar_opcoes_chave`).

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry/Datadog). Errors logged to rotating log files.

**Logs:**
- Daily log files under `${SCRIPT_DIR}/logs`:
  - `atualiza.YYYY-MM-DD.log` (`LOG_ATU`)
  - `limpando.YYYY-MM-DD.log` (`LOG_LIMPA`)
  - `LOG_TMP` temp dir.
- Defined in `binarios/constantes.sh:242-244`. Logger helpers: `_log`, `_log_erro`, `_log_sucesso` in `binarios/vaievem.sh`.

## CI/CD & Deployment

**Hosting:**
- Not hosted as a service. Distributed as a Git repo / GitHub zip; run locally on operator workstations and the SAV server.

**CI Pipeline:**
- None configured (no GitHub Actions / workflows present).

## Environment Configuration

**Required config files:**
- `configuracoes/.config` — key=value system config (verclass, empresa, base, base2, base3, enviabackup, acessossh, chavessh, Offline).
- `configuracoes/.senhas` — user credentials (sha256).
- `configuracoes/manual.txt` — operator manual (52910 bytes).
- `configuracoes/indexar`, `configuracoes/variosarquivos`, `configuracoes/limpetmp` — helper scripts/config.

**Secrets location:**
- `configuracoes/.senhas` (hashed passwords) and `~/.ssh/id_rsa_atualiza` (SSH private key). No `.env` files used.

## Webhooks & Callbacks

**Incoming:** None.

**Outgoing:** None (no HTTP API server). Only outbound `wget`/`curl`/`ssh`/`scp`/`sftp`/`rsync` file transfers.

---

*Integration audit: 2026-07-13*
