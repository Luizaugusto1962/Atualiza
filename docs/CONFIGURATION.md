# Configuração

## Arquivo de Configuração da Empresa

O sistema usa `configuracoes/.config` para armazenar parâmetros específicos da empresa. Gerado pelo comando:

```bash
./atualiza.sh --setup
```

### Formato

Arquivo texto com atribuições de variáveis no formato `VAR=valor`:

```bash
CFG_SISTEMA=iscobol
CFG_VERCLASS=64
CFG_USA_DBMAKER=n
CFG_ACESSO_SSH=n
CFG_OFFLINE=n
CFG_BACKUP_PATH=/caminho/do/backup
CFG_EMPRESA=NOME_EMPRESA
```

### Variáveis de Configuração

| Variável | Descrição | Valores |
|----------|-----------|---------|
| `CFG_SISTEMA` | Tipo de sistema | `iscobol`, `cobol` |
| `CFG_VERCLASS` | Versão do IsCOBOL | Número (ex: `64`) |
| `CFG_USA_DBMAKER` | Usa banco DBMAKER | `s`, `n` |
| `CFG_ACESSO_SSH` | Acesso via SSH | `s`, `n` |
| `CFG_OFFLINE` | Modo offline | `s`, `n` |
| `CFG_BACKUP_PATH` | Caminho do backup | Path absoluto |
| `CFG_EMPRESA` | Nome da empresa | Texto |
| `CFG_BASE_DIR` | Diretório base 1 | Path relativo |
| `CFG_BASE_DIR2` | Diretório base 2 | Path relativo |
| `CFG_BASE_DIR3` | Diretório base 3 | Path relativo |

## Segurança da Configuração

O arquivo `.config` passa por validação rigorosa antes do carregamento:

- Linhas devem ser atribuições `VAR=valor`
- Bloqueio de caracteres perigosos: `` $ ` ; | & < > ( ) { } ``
- Bloqueio de command substitution (`$()` e backticks)
- Limite de tamanho: 1 MB
- Permissão de leitura obrigatória

## Diretórios Criados pelo Sistema

O sistema cria e gerencia estes diretórios:

| Diretório | Finalidade |
|-----------|------------|
| `configuracoes/` | Configurações e senhas |
| `biblioteca/` | Biblioteca do sistema |
| `olds/` | Versões antigas |
| `logs/` | Logs de atualização e limpeza |
| `backup/` | Backups |
| `bases_backup/` | Backup de bases |
| `enviar/` | Arquivos para envio |
| `receber/` | Arquivos recebidos |

## Dependências Externas

O sistema verifica estas dependências no startup:

- `zip` — compactação
- `unzip` — descompactação
- `rsync` — transferência remota
- `wget` — download
- `tput` — cores e formatação de terminal

<!-- VERIFY: The list of package manager detection (apt, yum, dnf, pacman, zypper) covers all major Linux distributions -->

## Logs

Os logs são armazenados em `$DEFAULT_LOGS_DIR`:

- `atualiza.*` — logs de atualização
- `limpando.*` — logs de limpeza

<!-- VERIFY: Log rotation policy — confirm whether logs are automatically rotated or require manual cleanup -->
