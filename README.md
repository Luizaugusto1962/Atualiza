# atualiza2026

Sistema modular de atualização SAV — utilitário de linha de comando para gerenciar
programas, arquivos, backups e bibliotecas do sistema **IsCOBOL / ISAM**.

---

## Uso

```bash
./atualiza.sh                  # Executa o programa principal
./atualiza.sh --setup          # Configuração inicial do sistema
./atualiza.sh --setup --edit   # Editar configurações existentes
./atualiza.sh --cadastro       # Cadastro de usuários
```

---

## Estrutura de Arquivos

| Arquivo          | Responsabilidade                                      |
|------------------|-------------------------------------------------------|
| `atualiza.sh`    | Ponto de entrada principal; roteia para módulos       |
| `principal.sh`   | Inicialização, carregamento de módulos e main loop    |
| `config.sh`      | Configurações, validações e variáveis globais         |
| `auth.sh`        | Autenticação de usuários (login / cadastro / senha)   |
| `menus.sh`       | Sistema de menus interativos                          |
| `utils.sh`       | Utilitários: formatação, log, validação, progresso    |
| `arquivos.sh`    | Limpeza, recuperação, transferência e expurgo         |
| `backup.sh`      | Backup completo, incremental e restauração            |
| `programas.sh`   | Atualização, reversão e gestão de programas           |
| `biblioteca.sh`  | Gestão de bibliotecas do sistema                      |
| `baixar.sh`      | Atualização do sistema                                |
| `sistema.sh`     | Informações do SO, versões, parâmetros                |
| `vaievem.sh`     | Transferência de arquivos via rsync/scp               |
| `lembrete.sh`    | Bloco de notas / lembretes internos                   |
| `setup.sh`       | Configuração inicial interativa                       |
| `help.sh`        | Sistema de ajuda e manual interativo                  |
| `cadastro.sh`    | Cadastro standalone de usuários                       |

---

## Pré-requisitos

- Bash 4.0+
- `zip`, `unzip`, `rsync`, `wget`
- Terminal com suporte a cores (`tput`)

---

## Configuração

O sistema usa o diretório `cfg/` para armazenar:

- `.config` — configurações da CFG_EMPRESA (gerado pelo `--setup`)
- `.senhas` — hashes de senha dos usuários (`chmod 0600`)
- `lembrete` — notas internas
- `.versao` — versão atual da biblioteca

---

## Segurança

- Senhas armazenadas como **SHA-256** (nunca em texto plano)
- Arquivo `.senhas` com permissão `0600`
- Validação do arquivo `.config` antes do carregamento (detecta comandos suspeitos)
- Modo `set -euo pipefail` em todos os scripts principais
