# Structure: Atualiza

**Last updated:** 2026-07-06

## Directory Layout

```
D:\Projetos\Atualiza\
├── atualiza.sh               # Entry point — CLI argument router
├── AGENTS.md                 # AI development rules
├── package.json              # Dev dependency manifest
├── opencode.json             # OpenCode provider config (NaraRouter)
├── opencode.jsonc            # OpenCode model config (Claude Sonnet 4.5)
├── README.md                 # Project documentation
├── cspell.json               # Spell check config
├── .prettierrc               # Formatter config
├── .gitignore                # Git ignore rules
├── .gitattributes            # Git attributes
│
├── binarios/                 # Executable modules (source)
│   ├── constantes.sh         # System constants and defaults
│   ├── config.sh             # Config validation, variable registration
│   ├── utils.sh              # Shared utilities
│   ├── auth.sh               # Authentication
│   ├── principal.sh          # Module loader and initializer
│   ├── menus.sh              # Interactive menu system
│   ├── programas.sh          # Program updates/reversions
│   ├── biblioteca.sh         # Library updates/reversions
│   ├── arquivos.sh           # File recovery and cleanup
│   ├── backup.sh             # Backup/restore operations
│   ├── vaievem.sh            # Network transfers (SFTP/SCP/rsync)
│   ├── sistema.sh            # System information
│   ├── baixar.sh             # Self-update mechanism
│   ├── lembrete.sh           # Notes and reminders
│   ├── help.sh               # Help system
│   ├── variaveis.sh          # Variable query/display
│   ├── setup.sh              # Initial setup and config editing
│   ├── cadastro.sh           # Standalone user registration
│   └── binarios03072.zip     # Archived previous version
│
├── configuracoes/            # Runtime configuration
│   ├── .senhas               # SHA-256 password hashes (0600)
│   ├── indexar               # Data file index for rebuild
│   ├── limpetmp              # Temp file cleanup patterns
│   ├── manual.txt            # Full system manual (2039 lines)
│   └── variosarquivos        # Specific file list for recovery
│
├── .vscode/                  # IDE configuration
│   ├── settings.json         # Editor settings
│   ├── launch.json           # Debug profiles (bashdb)
│   ├── sftp.json             # Remote connection config
│   ├── .eslintrc.json        # ESLint config
│   ├── .prettierignore       # Formatter ignore
│   └── prettierrc.json       # Formatter options
│
└── .planning/                # GSD planning artifacts
    └── codebase/             # Codebase mapping documents
```

## Key File Locations

| Purpose | Path |
|---|---|
| Entry point | `atualiza.sh` |
| Bootstrap | `binarios/principal.sh` |
| Constants | `binarios/constantes.sh` |
| Config system | `binarios/config.sh` |
| Utilities | `binarios/utils.sh` |
| Auth system | `binarios/auth.sh` |
| Menu system | `binarios/menus.sh` |
| Program updates | `binarios/programas.sh` |
| Library updates | `binarios/biblioteca.sh` |
| File operations | `binarios/arquivos.sh` |
| Backup system | `binarios/backup.sh` |
| Network transfers | `binarios/vaievem.sh` |
| Self-update | `binarios/baixar.sh` |
| Help system | `binarios/help.sh` |
| Setup wizard | `binarios/setup.sh` |
| User registration | `binarios/cadastro.sh` |

## Naming Conventions

- **Files:** Lowercase with `.sh` extension for executables
- **Internal functions:** `_function_name()` (underscore-prefixed)
- **Entry functions:** `function_name()` (no underscore)
- **Globals:** UPPERCASE (`SCRIPT_DIR`, `RAIZ`, `CFG_PORTALSAV`)
- **Module pattern:** Each `.sh` provides function-based API, sources dependencies

## Change History

- Current version: `01/07/26-v.1` (defined in `principal.sh:25`)
- Archived: `binarios03072.zip` contains previous module versions
