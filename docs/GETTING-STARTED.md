# Guia de Introdução

## Primeiros Passos

### 1. Verificar Pré-requisitos

Certifique-se de que o sistema tem os programas necessários:

```bash
which bash zip unzip rsync wget tput
```

Bash 4.0+ é obrigatório. Os demais são verificados automaticamente na inicialização.

### 2. Configuração Inicial

Execute o setup para criar o arquivo de configuração da empresa:

```bash
./atualiza.sh --setup
```

O assistente interativo irá guiá-lo através de:
- Tipo de sistema (IsCOBOL ou COBOL)
- Diretórios base
- Configurações de rede (SSH, offline)
- Caminho de backup

### 3. Primeira Execução

Após configurar, execute o sistema principal:

```bash
./atualiza.sh
```

### 4. Cadastro de Usuário

Na primeira execução, cadastre um usuário:

```bash
./atualiza.sh --cadastro
```

### 5. Login

Ao entrar no sistema com `./atualiza.sh`, faça login com o usuário cadastrado. São permitidas até 3 tentativas.

## Navegação no Sistema

O menu principal oferece:

| Opção | Função |
|-------|--------|
| `1` | Atualizar Programas |
| `2` | Atualizar Biblioteca |
| `3` | Gerenciar Arquivos |
| `4` | Ferramentas |
| `0` | Sistema de Ajuda |
| `9` | Sair |

### Comandos Especiais

Durante a navegação nos menus:
- `H` ou `?` — Ajuda contextual
- `M` — Manual completo
- `Q` — Sair do sistema

## Estrutura de Arquivos

```
atualiza/
├── atualiza.sh          ← Ponto de entrada
├── binarios/            ← Módulos do sistema
├── configuracoes/       ← Configurações e dados
│   ├── .config          ← Configuração da empresa
│   ├── .senhas          ← Hashes de senha
│   └── manual.txt       ← Manual do sistema
└── docs/                ← Documentação
```
