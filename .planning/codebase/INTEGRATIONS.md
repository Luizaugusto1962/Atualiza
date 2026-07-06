# Integrations: Atualiza

**Last updated:** 2026-07-06

## Remote Server

| Property | Value |
|---|---|
| **Default IP** | `189.55.194.179` |
| **SSH Port** | `41122` |
| **SSH User** | `atualiza` |
| **Connection** | SSH key-based or password via `sshpass` |
| **Config file** | `~/.ssh/config` host alias `sav_servidor` |

### Transfer Protocols

| Protocol | Direction | Module | Purpose |
|---|---|---|---|
| **SFTP** | Download | `vaievem.sh` | Library downloads, file transfers |
| **SCP** | Download | `vaievem.sh` | Fallback when SFTP unavailable |
| **rsync** | Upload | `vaievem.sh` | Sending files to server |

## GitHub

- **Update URL:** `https://github.com/Luizaugusto1962/Atualiza/archive/refs/heads/main.zip`
- **Purpose:** Self-update mechanism (online mode)
- **Download tool:** `wget`

## Offline Updates

- **Source directory:** `DEFAULT_RECEBE_DIR/temp_update/`
- **Purpose:** System updates when server has no internet access
- **Triggered by:** `--offline` flag or offline menu option

## File Formats Managed

| Format | Tool | Purpose |
|---|---|---|
| `.zip` | `zip`/`unzip` | Backup archives, update packages |
| `.tar.gz` | `tar`/`gzip` | Library version archives |
| `.class` | — | IsCOBOL compiled programs |
| `.mclass` | — | IsCOBOL debug-compiled programs |
| `.TEL` | — | IsCOBOL screen files |
| `.so` | — | IsCOBOL shared objects |
| `.dat` | `jutil` | Data files for rebuild/recovery |

## Authentication

- **Method:** SHA-256 hashed passwords stored in `.senhas`
- **File permission:** `0600` (owner read/write only)
- **Max login attempts:** 3
- **Session:** Single-user, terminal-based (no web API)

## External Tools

| Tool | Integration Point |
|---|---|
| VS Code SFTP | `sftp.json` — remote path `/u/sav/tools/` |
| bashdb | `launch.json` — 4 debug profiles |
| ShellCheck | VS Code settings — lint on save |
