# Roadmap: Atualiza

**Milestone:** v1.0 — Refatoração Inicial
**Started:** 06/07/26

## Milestone Phases

### Phase 1: Extrair Funções Duplicadas para utils.sh

**Goal:** Extrair funções e blocos de código duplicados dos módulos grandes (`backup.sh`, `programas.sh`, `arquivos.sh`) para `utils.sh`, reduzindo ~400 linhas de código duplicado sem alterar comportamento externo.

**Requirements:** EXT-01, EXT-02, EXT-03, EXT-04, EXT-05, EXT-06, EXT-07

**Dependencies:** Nenhuma

**Success Criteria:**
1. `utils.sh` contém funções extraídas unificadas
2. `backup.sh`, `programas.sh`, `arquivos.sh` importam e usam as novas funções
3. Nenhuma mudança no comportamento externo (menus, fluxos, saída)
4. Sistema continua funcionando nas operações principais (backup, atualização, recuperação)

### Backlog

*(Nenhum item no backlog)*
