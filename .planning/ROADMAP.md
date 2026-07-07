# Roadmap: Atualiza

## v1.0 — Refatoração Inicial

**Milestone:** v1.0 — Refatoração Inicial
**Started:** 06/07/26
**Status:** ✅ Complete

### Phase 1: Extrair Funções Duplicadas para utils.sh

**Goal:** Extrair funções e blocos de código duplicados dos módulos grandes (`backup.sh`, `programas.sh`, `arquivos.sh`) para `utils.sh`, reduzindo ~400 linhas de código duplicado sem alterar comportamento externo.

**Requirements:** EXT-01, EXT-02, EXT-03, EXT-04, EXT-05, EXT-06, EXT-07

**Dependencies:** Nenhuma

**Success Criteria:**
1. `utils.sh` contém funções extraídas unificadas
2. `backup.sh`, `programas.sh`, `arquivos.sh` importam e usam as novas funções
3. Nenhuma mudança no comportamento externo (menus, fluxos, saída)
4. Sistema continua funcionando nas operações principais (backup, atualização, recuperação)

---

## v2.0 — Infraestrutura e Padronização

**Milestone:** v2.0 — Infraestrutura e Padronização
**Started:** 07/07/26

### Phase 2: Infraestrutura (Testes, CI, Lockfile)

**Goal:** Estabelecer infraestrutura de qualidade: testes automatizados com bats, pipeline CI com ShellCheck, e lockfile para evitar execução concorrente.

**Requirements:** TEST-01, CI-01, LOCK-01

**Dependencies:** Nenhuma

**Success Criteria:**
1. `bats` executável localmente e via script npm/vendorizado
2. Testes bats para pelo menos 3 funções críticas de `backup.sh` ou `programas.sh`
3. GitHub Action `.github/workflows/shellcheck.yml` executando em todo push/PR
4. ShellCheck passa com severidade `warning` em todos os módulos
5. Lockfile com `flock` implementado no entry point `atualiza.sh`

### Phase 3: Modularização (biblioteca.sh e SSH)

**Goal:** Extrair funções de `biblioteca.sh` para módulos menores e consolidar lógica SSH duplicada em `utils.sh`, seguindo o padrão estabelecido no v1.0.

**Requirements:** MOD-01, MOD-02

**Dependencies:** Phase 1 (utils.sh como alvo de extração)

**Success Criteria:**
1. Funções de `biblioteca.sh` reorganizadas em módulos menores e coesos
2. Lógica SSH (conexão, autenticação, fallback) consolidada em `utils.sh`
3. Nenhuma mudança no comportamento externo
4. Redução de linhas totais em `biblioteca.sh`

### Phase 4: Padronização de Todos os Módulos .sh

**Goal:** Aplicar convenções consistentes em todos os 18 módulos .sh: `set -euo pipefail`, `lower_snake_case`, indentação 2 espaços, shebang portável, tratamento de erros uniforme.

**Requirements:** STD-01, STD-02, STD-03

**Dependencies:** Phase 3 (modularização concluída antes da padronização final)

**Success Criteria:**
1. Todos os módulos usam `#!/usr/bin/env bash` e `set -euo pipefail`
2. Todas as variáveis têm escopo explícito (`local`/`readonly`)
3. Formatação consistente (shfmt --indent 2) em todos os arquivos
4. Funções seguem `lower_snake_case` sem `function` keyword
5. Tratamento de erros com `trap` e mensagens via `_erro()`/`_msg()`
6. 0 warnings do ShellCheck em todos os módulos

### Backlog

*(Nenhum item no backlog)*
