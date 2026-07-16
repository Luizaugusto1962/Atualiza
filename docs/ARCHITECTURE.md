# Arquitetura

## Visão Geral

O **atualiza** é um sistema modular em Bash para gerenciamento de atualizações do ambiente **IsCOBOL/ISAM SAV**. Utiliza uma arquitetura de microsscripts carregados dinamicamente em runtime.

## Fluxo de Execução

```
atualiza.sh
  └── --setup             → binarios/setup.sh
  └── --cadastro          → binarios/cadastro.sh
  └── (sem argumentos)
       └── move_dir.sh    → Organização de diretórios
       └── principal.sh   → Inicialização do sistema
            ├── constantes.sh
            ├── config.sh      → Variáveis, diretórios, comandos
            ├── utils.sh       → Utilitários
            ├── auth.sh        → Login
            ├── lembrete.sh    → Notas
            ├── vaievem.sh     → Rede
            ├── sistema.sh     → Info SO
            ├── baixar.sh      → Download
            ├── arquivos.sh    → Arquivos
            ├── backup.sh      → Backup
            ├── programas.sh   → Programas
            ├── biblioteca.sh  → Biblioteca
            ├── help.sh        → Ajuda
            └── menus.sh       → Menu principal
```

## Camadas

### 1. Entry Point (`atualiza.sh`)
Dispatcher principal. Processa argumentos da linha de comando e roteia para o módulo apropriado. Executa verificações de segurança (`set -euo pipefail`, terminal interativo).

### 2. Inicialização (`principal.sh`)
Carrega todos os módulos sequencialmente com verificação de segurança (arquivo existe, é legível, não está vazio). Inicializa sistema de variáveis, configurações e dependências.

### 3. Configuração (`config.sh`)
Gerencia um sistema de **variáveis registradas** com categorias (CORES, ATUALIZACAO, CAMINHOS, BIBLIOTECA, COMANDOS, CONFIGURACOES, LOGS). Valida arquivo `.config` com análise linha a linha.

### 4. Interface (`menus.sh`, `utils.sh`)
Menus aninhados com suporte a ajuda contextual. Utilitários de formatação de terminal (cores, centralização, barras de progresso).

### 5. Autenticação (`auth.sh`)
Login com hash SHA-256. Três tentativas máximas. Arquivo de senhas com permissão restrita.

## Sistema de Variáveis

O `config.sh` implementa um registro de variáveis com:
- **Declaração**: `_register_var nome valor [categoria]`
- **Categorias**: CORES, ATUALIZACAO, CAMINHOS, BIBLIOTECA, COMANDOS, CONFIGURACOES, LOGS
- **Limpeza**: `_limpar_estado_variaveis()` — unset automático via trap
- **Emergência**: `_limpeza_emergencia()` — lista hardcoded de fallback

## Tratamento de Erros

- `set -euo pipefail` em todos os módulos
- Funções retornam 0/1 em vez de `exit` (corrigido em versões recentes)
- Traps: EXIT, INT, TERM, HUP, QUIT
- Logs em `$DEFAULT_LOGS_DIR` com timestamp

## Segurança

- Arquivo `.config` validado contra command injection
- Path traversal bloqueado em operações de arquivo
- Senhas com hash — nunca texto plano
- Permissões `0600` para `.senhas`, `0755` para diretórios
