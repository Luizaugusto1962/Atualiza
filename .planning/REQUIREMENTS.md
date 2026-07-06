# Requirements: Atualiza

**Defined:** 06/07/26
**Core Value:** Manter sistemas IsCOBOL atualizados de forma confiável via ferramenta modular em Bash

## v1 Requirements

### Extração de Funções Duplicadas

- [ ] **EXT-01**: Extrair funções duplicadas de `backup.sh`, `programas.sh`, `arquivos.sh` para `utils.sh`
- [ ] **EXT-02**: Unificar `_listar_logs_atualizacao` e `_listar_logs_limpeza` em uma função parametrizada
- [ ] **EXT-03**: Extrair preâmbulo compartilhado de `_processar_atualizacao_programas` e `_processar_atualizacao_pacotes`
- [ ] **EXT-04**: Unificar `_executar_backup_completo` e `_executar_backup_incremental`
- [ ] **EXT-05**: Criar helpers `_validar_arquivo_existe`, `_mudar_diretorio`, `_coletar_arquivos` para eliminar código repetido inline
- [ ] **EXT-06**: Unificar `_enviar_backup_servidor` e `_enviar_backup_rede`
- [ ] **EXT-07**: Garantir que extração não altere comportamento externo

## v2 Requirements

### Infraestrutura

- **TEST-01**: Adicionar testes automatizados (bats)
- **CI-01**: Configurar pipeline CI com ShellCheck
- **LOCK-01**: Adicionar lockfile para evitar execução concorrente

### Modularização Adicional

- **MOD-01**: Extrair funções de `biblioteca.sh` para módulos menores
- **MOD-02**: Consolidar lógica SSH duplicada em `utils.sh`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Novas funcionalidades | Fora do escopo de extração — fase futura |
| Reescrever módulos inteiros | Apenas extrair duplicação, sem mudança de comportamento |
| Mudanças na interface do usuário | Refatoração interna apenas — menus inalterados |
| Migração para outra linguagem | Bash puro é requisito do projeto |
| Testes automatizados | Fase futura — v2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXT-01 | Phase 1 | Pending |
| EXT-02 | Phase 1 | Pending |
| EXT-03 | Phase 1 | Pending |
| EXT-04 | Phase 1 | Pending |
| EXT-05 | Phase 1 | Pending |
| EXT-06 | Phase 1 | Pending |
| EXT-07 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0 ✓

---
*Requirements defined: 06/07/26*
*Last updated: 06/07/26 after initial definition*
