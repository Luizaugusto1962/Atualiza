# atualiza

Sistema modular de atualização **SAV** — utilitário de linha de comando em Bash para gerenciar programas, arquivos, backups e bibliotecas do sistema **IsCOBOL / ISAM**.

## Uso

```bash
./atualiza.sh                  # Executa o programa principal
./atualiza.sh --setup          # Configuração inicial do sistema
./atualiza.sh --setup --edit   # Editar configurações existentes
./atualiza.sh --cadastro       # Cadastro de usuários
```

## Pré-requisitos

- Bash 4.0+
- `zip`, `unzip`, `rsync`, `wget`
- Terminal com suporte a cores (`tput`)

## Estrutura de Diretórios

```
atualiza/
├── atualiza.sh        # Ponto de entrada principal
├── binarios/          # Módulos do sistema (20 scripts)
├── configuracoes/     # Configurações, senhas, listas
├── docs/              # Documentação
├── AGENTS.md          # Regras para agentes de IA
└── cspell.json        # Configuração de spell checker
```

## Módulos

O sistema é composto por módulos independentes em `binarios/`:

| Módulo | Responsabilidade |
|--------|-----------------|
| `principal.sh` | Inicialização, carregamento e main loop |
| `config.sh` | Configurações, validações e variáveis globais |
| `utils.sh` | Utilitários de formatação, log, validação |
| `auth.sh` | Autenticação de usuários (login/cadastro/senha) |
| `menus.sh` | Sistema de menus interativos |
| `arquivos.sh` | Limpeza, recuperação e transferência de arquivos |
| `backup.sh` | Backup completo, incremental e restauração |
| `programas.sh` | Atualização e reversão de programas |
| `biblioteca.sh` | Gestão de bibliotecas do sistema |
| `baixar.sh` | Atualização do sistema |
| `sistema.sh` | Informações do SO, versões e parâmetros |
| `vaievem.sh` | Transferência de arquivos via rsync/scp |
| `lembrete.sh` | Bloco de notas e lembretes internos |
| `setup.sh` | Configuração inicial interativa |
| `help.sh` | Sistema de ajuda e manual interativo |
| `cadastro.sh` | Cadastro standalone de usuários |
| `constantes.sh` | Constantes do sistema |
| `variaveis.sh` | Declarações de variáveis |
| `move_dir.sh` | Organização de diretórios pós-atualização |

## Segurança

- Senhas armazenadas como **SHA-256** (nunca em texto plano)
- Arquivo `.senhas` com permissão `0600`
- Validação rigorosa do arquivo `.config` antes do carregamento
- Modo `set -euo pipefail` em todos os scripts principais
- Proteção contra path traversal em operações de arquivo

## Configuração

O diretório `configuracoes/` armazena:

- `.config` — configurações da empresa (gerado pelo `--setup`)
- `.senhas` — hashes de senha dos usuários
- `lembrete` — notas internas
- `limpetmp` — lista de arquivos temporários para limpeza
- `manual.txt` — manual do sistema
