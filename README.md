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
- `.versao` — versão atual do sistema
- `lembrete` — notas internas
- `limpetmp` — lista de arquivos temporários para limpeza
- `manual.txt` — manual do sistema

## Testes

Suítes isoladas por módulo, sem TTY e sem rede. Cada uma faz `source` do módulo
sob teste com stubs e conta as verificações:

```bash
bash testes/run_all.sh          # todas as suítes + resumo (517 checks)
bash testes/test_sistema.sh      # sistema.sh    — parser do .versao e IP interno
bash testes/test_auth.sh         # auth.sh       — rate limit, hash, .senhas
bash testes/test_utils.sh        # utils.sh      — caminhos, diretorios, pacotes, ssh
bash testes/test_programas.sh    # programas.sh  — portao de pacote, integridade, cleanup
bash testes/test_biblioteca.sh   # biblioteca.sh — extracao na raiz, flag offline
bash testes/test_backup.sh       # backup.sh     — pre-requisitos, espaco, lista do ZIP
bash testes/test_baixar.sh       # baixar.sh     — limpeza da recepcao, staging, download
bash testes/test_constantes.sh   # constantes.sh — parser seguro do .config
bash testes/test_config.sh       # config.sh     — scanner do .config, registro de variaveis
bash testes/test_arquivos.sh     # arquivos.sh   — padrao de limpeza, link duro, base
bash testes/test_vaievem.sh      # vaievem.sh    — destino/origem ssh, quoting, staging
bash testes/test_principal.sh    # principal.sh  — ordem de carga dos modulos, fluxo do _main
```

O `run_all.sh` aceita `-v` (saída completa), `-o` (só as suítes que falharam) e
`-k <filtro>` (só as suítes cujo nome casa com o filtro).

### Resultados dos Testes

| Suíte | Checks | Descrição |
|-------|--------|-----------|
| test_sistema.sh | 16 | Parser do `.versao`, extração do IP interno |
| test_auth.sh | 63 | Rate limiting, formato de hash, gravação de `.senhas` |
| test_utils.sh | 80 | Validação de caminhos, `_garantir_diretorio`, entradas de pacote, SSH |
| test_programas.sh | 22 | Portão de pacote inseguro, integridade de backup, cleanup |
| test_biblioteca.sh | 38 | Extração na raiz, portão de pacote inseguro, flag `Offline` |
| test_backup.sh | 35 | Pré-requisitos do backup, espaço em disco, lista do ZIP |
| test_baixar.sh | 37 | Limpeza da recepção, staging, validação de URL |
| test_constantes.sh | 38 | Parser do `.config`, chaves bloqueadas por segurança |
| test_config.sh | 45 | Scanner do `.config`, registro e limpeza de variáveis |
| test_arquivos.sh | 42 | Padrão de limpeza, detecção de link duro, base de trabalho |
| test_vaievem.sh | 52 | Destino/origem SSH, quoting POSIX de argumento, staging |
| test_principal.sh | 49 | Ordem de carga dos 15 módulos (cadeia) e fluxo do `_main` |

## Validação e Qualidade

- **Lint**: `trunk check` (shellcheck, shfmt, prettier)
- **Correção automática**: `trunk check --fix`
- **Verificações obrigatórias no commit**
