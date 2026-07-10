# Desenvolvimento

## Stack

- **Linguagem**: Bash 4.0+
- **Plataforma**: Linux (testado em distribuições com apt, yum, dnf, pacman, zypper)
- **Sistema-alvo**: IsCOBOL / ISAM SAV

## Convenções

### Código

- `set -euo pipefail` no início de todo script
- Funções prefixadas com `_` (ex: `_login`, `_carregar_modulos`)
- Variáveis globais em MAIÚSCULAS
- Variáveis locais em minúsculas
- Comentários em português
- Retornos: `0` para sucesso, `1` para erro (nunca `exit` dentro de funções sourced)

### Módulos

Cada módulo em `binarios/` segue o padrão:

```bash
#!/usr/bin/env bash
#
# modulo.sh - Descrição
# Responsável por [responsabilidade principal]
# Padrões e regras de desenvolvimento: ver AGENTS.md
#
# SISTEMA SAV - Script de Atualização Modular
# Versão: DD/MM/AAAA-NN
# Autor: Nome

set -euo pipefail

# Verificar dependências do módulo
if ! command -v _funcao_necessaria >/dev/null 2>&1; then
    printf 'ERRO: dependência não carregada.\n' >&2
    return 1
fi
```

### Controle de Versão

Commits devem seguir mensagens descritivas em português. O arquivo `AGENTS.md` contém regras operacionais para agentes de IA que trabalham no projeto.

## Arquitetura de Módulos

Os módulos são carregados por `principal.sh` via `source` (`.`), nesta ordem:

1. `constantes.sh` — constantes do sistema
2. `config.sh` — configurações e validações
3. `utils.sh` — utilitários gerais
4. `auth.sh` — autenticação
5. `lembrete.sh` — notas
6. `vaievem.sh` — transferência remota
7. `sistema.sh` — informações do SO
8. `baixar.sh` — download
9. `arquivos.sh` — gestão de arquivos
10. `backup.sh` — backup
11. `programas.sh` — programas
12. `biblioteca.sh` — biblioteca
13. `help.sh` — ajuda
14. `menus.sh` — interface de menus

## Correções Anteriores

- Funções sourced não devem usar `exit` (substituído por `return`)
- `_criar_diretorio_seguro`: `exit 1` → `return 1`
- `_inicializar_variaveis_sistema`: tratamento de variáveis readonly
- `_configurar_comandos`: corrigido array duplicado (`$DEFAULT_ZIP` aparecia 2 vezes)
- `_mensagec` definida como alias de `_mensageb` e `_exibir_mensagem_centralizada` para compatibilidade
