# Requisitos — Verificação de Compatibilidade Linux

**Projeto:** Atualiza — Sistema SAV de Atualização Modular  
**Versão:** 1.0 — Julho/2026  
**Escopo:** Análise estática de compatibilidade dos 19 scripts Bash do sistema

---

## Contexto

O projeto Atualiza é um sistema de distribuição em Bash puro que opera em servidores Linux legados e modernos. A análise de compatibilidade precisa garantir que os scripts funcionem corretamente em Ubuntu 20.04+, Debian 11+ e RHEL 8+ sem modificações de comportamento ou falhas silenciosas.

---

## Requisitos Funcionais

### RF01 — Verificar compatibilidade Bash 4.0+

O sistema deve analisar cada script para identificar construções que exigem Bash 4.0 ou superior, incluindo:

- `declare -A` (arrays associativos) — Bash 4.0+
- `mapfile` / `readarray` — Bash 4.0+
- `${var,,}` / `${var^^}` (conversão de case) — Bash 4.0+
- `declare -g` (variável global em função) — Bash 4.2+
- `local -n` (nameref) — Bash 4.3+
- `read -t` com valor decimal — Bash 4.0+
- `printf -v` — Bash 3.1+
- `BASH_SOURCE` — Bash 3.0+
- `${!var}` (indirect expansion) — todas as versões, mas verificar uso correto
- `(( ))` e `[[ ]]` — Bash 2.0+, não POSIX

A análise deve confirmar se o shebang e as dependências são compatíveis com Bash 4.0+ alvo.

### RF02 — Verificar uso de comandos GNU específicos

O sistema deve identificar chamadas a ferramentas GNU cujo comportamento difere em outras implementações (BSD, BusyBox), assegurando que a versão GNU está disponível nos alvos:

- `stat -c "%a"` / `stat -c%s` (GNU) vs `stat -f "%Lp"` (BSD) — verificar se há fallback
- `readlink -f` — disponível no GNU coreutils; verificar ausência em ambientes mínimos
- `tput` (cols, lines, setaf, sgr0, bold, cup, clear, sgr0) — requer `ncurses`
- `timeout` — GNU coreutils
- `find` com `-print0`, `-newermt`, `-maxdepth`, `-mtime`, `-ctime`, `-delete`, `-exec … +`
- `grep -E`, `grep -q`, `grep -n`, `grep -i`, `grep -P` (Perl regex — não disponível no BusyBox)
- `sed -i` (GNU) — sem sufixo de backup funciona em GNU, requer sufixo em BSD
- `date -d` (GNU) — parsing de data por string; BSD usa `-j -f`
- `wc -c` e `wc -l`
- `sha256sum` — GNU coreutils; equivalente BSD é `shasum -a 256`
- `ssh-copy-id` — pacote `openssh-client`
- `rsync`, `wget`, `sftp`, `scp` — verificar presença esperada
- `curl` — verificado via `command -v curl` em `sistema.sh` (opcional)
- `uptime -p` — GNU coreutils; BSD/antigo: formato diferente
- `fold -s` — disponível no coreutils, verificar uso em `lembrete.sh`
- `df -k` e `du -h` — disponíveis, mas formato de saída pode variar
- `ip route get 1` — `iproute2`; sistemas muito antigos usam `ifconfig`
- `ping -c 1 -W 3` — `-W` é opção GNU; BSD usa `-t`
- `nl -w2 -s')'` — GNU/BSD, disponível nos alvos
- `awk -F:` — POSIX, sem problemas

### RF03 — Verificar padrões de segurança

O sistema deve confirmar a presença dos padrões de segurança exigidos pelo projeto:

- **RF03.1** — `set -euo pipefail` no início de cada script
- **RF03.2** — `umask 077` presente em `principal.sh` (único ponto de entrada com criação de arquivos sensíveis)
- **RF03.3** — Shebang `#!/usr/bin/env bash` (portável) ou `#!/bin/bash` (fixo) em scripts executados diretamente
- **RF03.4** — Permissão 0600 aplicada ao arquivo `.senhas` após criação/alteração
- **RF03.5** — Ausência de `source <arquivo>` sem validação prévia do conteúdo

### RF04 — Verificar fallbacks para ambientes sem tput/cores

O sistema deve identificar se existe tratamento adequado para terminais sem suporte a cores ou sem `tput`:

- **RF04.1** — Verificar se `config.sh` tem bloco `else` para `tput` indisponível (já presente: `\033[0;3Xm`)
- **RF04.2** — Verificar se `tput cols/lines` tem fallback para `${COLUMNS:-80}` / `${LINES:-24}`
- **RF04.3** — Identificar chamadas diretas a `tput` fora do bloco de inicialização (sem verificação de disponibilidade)
- **RF04.4** — Verificar uso de escapes ANSI brutos (`\033[?25l`, `\033[?25h`, `\033[K`, `\r\033`) fora do contexto de terminal

### RF05 — Gerar relatório priorizado por severidade

O sistema deve produzir o arquivo `relatorio_compatibilidade.md` com:

- **RF05.1** — Sumário executivo com contagem por severidade
- **RF05.2** — Tabela consolidada de todos os problemas (arquivo, linha aprox., categoria, severidade, descrição)
- **RF05.3** — Seção de problemas por arquivo (cada um dos 19 scripts)
- **RF05.4** — Seção de problemas por categoria (Bash, GNU, Segurança, Fallback, Padrões)
- **RF05.5** — Sugestão de correção para cada problema identificado
- **RF05.6** — Recomendações gerais para o projeto

Severidades:
- **BLOQUEANTE** — impede execução no alvo ou causa comportamento incorreto certo
- **AVISO** — pode funcionar mas comportamento difere de distribuição para distribuição
- **INFO** — melhoria de robustez, boa prática, não afeta execução

### RF06 — Verificar cada script individualmente

O sistema deve analisar de forma independente cada um dos 19 scripts:

1. `atualiza.sh` (raiz)
2. `binarios/principal.sh`
3. `binarios/constantes.sh`
4. `binarios/config.sh`
5. `binarios/utils.sh`
6. `binarios/auth.sh`
7. `binarios/cadastro.sh`
8. `binarios/setup.sh`
9. `binarios/vaievem.sh`
10. `binarios/baixar.sh`
11. `binarios/sistema.sh`
12. `binarios/arquivos.sh`
13. `binarios/backup.sh`
14. `binarios/programas.sh`
15. `binarios/biblioteca.sh`
16. `binarios/menus.sh`
17. `binarios/help.sh`
18. `binarios/lembrete.sh`
19. `binarios/variaveis.sh`

---

## Requisitos Não Funcionais

### RNF01 — Análise estática sem executar os scripts

A verificação deve ser realizada exclusivamente por leitura e inspeção do código-fonte. Nenhum script deve ser executado durante a análise. As linhas de problema devem ser identificadas com numeração aproximada (margem de ±2 linhas é aceitável dado o volume).

### RNF02 — Alvos de compatibilidade definidos

A análise deve ter como referência exclusivamente as seguintes distribuições:

| Distribuição | Versão mínima | Bash padrão | Observações |
|---|---|---|---|
| Ubuntu | 20.04 LTS (Focal) | 5.0.17 | GNU coreutils 8.30, ncurses 6.2 |
| Ubuntu | 22.04 LTS (Jammy) | 5.1.16 | GNU coreutils 8.32 |
| Debian | 11 (Bullseye) | 5.1.4 | GNU coreutils 8.32 |
| Debian | 12 (Bookworm) | 5.2.15 | GNU coreutils 9.1 |
| RHEL/Rocky/AlmaLinux | 8 | 4.4.20 | GNU coreutils 8.30 |
| RHEL/Rocky/AlmaLinux | 9 | 5.1.8 | GNU coreutils 8.32 |

> **Nota:** Todos os alvos têm Bash ≥ 4.4. Bash 4.0 é o mínimo declarado no projeto, mas os alvos reais já são 4.4+. A análise deve sinalizar quando uma construção exige ≥ 4.3 (ex: `local -n`) pois RHEL 7 (legado não suportado) tem Bash 4.2.

### RNF03 — Relatório legível e acionável

O relatório deve ser escrito em português (pt-br), com linguagem técnica precisa e sugestões de correção concretas e aplicáveis, não genéricas.

### RNF04 — Reprodutibilidade

Os achados devem ser verificáveis por qualquer desenvolvedor que leia o código-fonte dos mesmos scripts. Nenhum achado pode depender de execução em tempo real.
