# Requirements: Atualiza

**Defined:** 06/07/26
**Core Value:** Manter sistemas IsCOBOL atualizados de forma confiável via ferramenta modular em Bash

## v1 Requirements (Completed)

### Extração de Funções Duplicadas

- [x] **EXT-01**: Extrair funções duplicadas de `backup.sh`, `programas.sh`, `arquivos.sh` para `utils.sh`
- [x] **EXT-02**: Unificar `_listar_logs_atualizacao` e `_listar_logs_limpeza` em uma função parametrizada
- [x] **EXT-03**: Extrair preâmbulo compartilhado de `_processar_atualizacao_programas` e `_processar_atualizacao_pacotes`
- [x] **EXT-04**: Unificar `_executar_backup_completo` e `_executar_backup_incremental`
- [x] **EXT-05**: Criar helpers `_validar_arquivo_existe`, `_mudar_diretorio`, `_coletar_arquivos` para eliminar código repetido inline
- [x] **EXT-06**: Unificar `_enviar_backup_servidor` e `_enviar_backup_rede`
- [x] **EXT-07**: Garantir que extração não altere comportamento externo

## v2.0 Requirements — Infraestrutura e Padronização

### Infraestrutura

- [ ] **TEST-01**: Adicionar testes automatizados com bats para módulos principais (backup, programas, arquivos)
- [ ] **CI-01**: Configurar pipeline GitHub Actions com ShellCheck para todos os módulos .sh
- [ ] **LOCK-01**: Adicionar lockfile com flock para evitar execução concorrente do sistema

### Modularização

- [ ] **MOD-01**: Extrair funções de `biblioteca.sh` para módulos menores
- [ ] **MOD-02**: Consolidar lógica SSH duplicada em `utils.sh`

### Padronização

- [ ] **STD-01**: Padronizar declaração de variáveis (`local`, `readonly`) e funções (`lower_snake_case`) em todos os módulos .sh
- [ ] **STD-02**: Unificar formatação (indentação 2 espaços, shfmt), headers e shebang (`#!/usr/bin/env bash`) em todos os módulos
- [ ] **STD-03**: Garantir `set -euo pipefail` e tratamento de erros consistente (trap, mensagens) em todos os módulos

## v2 Requirements (Deferred)

*(Nenhum — todos incluídos no v2.0)*

## Out of Scope

| Feature | Reason |
|---------|--------|
| Novas funcionalidades para usuário final | Apenas infraestrutura e padronização |
| Reescrever módulos inteiros | Apenas extrair duplicação e padronizar |
| Mudanças na interface do usuário (menus) | Refatoração interna apenas |
| Migração para outra linguagem | Bash puro é requisito do projeto |
| Testes de integração completos | Bats cobre testes unitários; integração é fase futura |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TEST-01 | Phase 2 | Planned |
| CI-01 | Phase 2 | Planned |
| LOCK-01 | Phase 2 | Planned |
| MOD-01 | Phase 3 | Pending |
| MOD-02 | Phase 3 | Pending |
| STD-01 | Phase 4 | Pending |
| STD-02 | Phase 4 | Pending |
| STD-03 | Phase 4 | Pending |

**Coverage:**
- v2.0 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0 ✓

---
*Requirements defined: 06/07/26*
*Last updated: 07/07/26 after v2.0 milestone definition*
