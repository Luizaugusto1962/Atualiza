# Atualiza — Sistema SAV de Atualização Modular

## What This Is

Ferramenta de distribuição em Bash puro para gerenciar atualizações de sistemas IsCOBOL/ISAM — programas, bibliotecas, backups, recuperação de arquivos e transferências via SSH/SFTP/rsync. Usada em clientes com servidores legados e recursos limitados.

## Core Value

Manter sistemas IsCOBOL atualizados de forma confiável via ferramenta modular em Bash — distribuída para sites de clientes, funcionando mesmo em servidores antigos com ferramentas mínimas.

## Requirements

### Validated

- ✓ Autenticação com SHA-256 e sessão por terminal — existente
- ✓ Atualização de programas (online, offline, pacote) — existente
- ✓ Atualização de bibliotecas (transpc, offline, reversão) — existente
- ✓ Backup e restauração (completo, incremental, envio ao servidor) — existente
- ✓ Recuperação de arquivos via jutil — existente
- ✓ Transferência de arquivos via SFTP/SCP/rsync — existente
- ✓ Limpeza de temporários e expurgo automático — existente
- ✓ Auto-update do sistema via GitHub — existente
- ✓ Sistema de ajuda com manual paginado — existente
- ✓ Cadastro e gerenciamento de usuários — existente
- ✓ Configuração via setup interativo — existente
- ✓ Validação de .config contra command injection — existente
- ✓ Suporte SSH a servidores antigos (fallback) — existente

### Active

- [ ] **EXT-01**: Extrair funções duplicadas de `backup.sh`, `programas.sh`, `arquivos.sh` para `utils.sh`
- [ ] **EXT-02**: Unificar `_listar_logs_atualizacao` e `_listar_logs_limpeza` em uma função parametrizada
- [ ] **EXT-03**: Extrair preâmbulo compartilhado de `_processar_atualizacao_programas` e `_processar_atualizacao_pacotes`
- [ ] **EXT-04**: Unificar `_executar_backup_completo` e `_executar_backup_incremental`
- [ ] **EXT-05**: Criar helpers `_validar_arquivo_existe`, `_mudar_diretorio`, `_coletar_arquivos` para eliminar código repetido inline
- [ ] **EXT-06**: Unificar `_enviar_backup_servidor` e `_enviar_backup_rede`
- [ ] **EXT-07**: Garantir que extração não altere comportamento externo

### Out of Scope

- Novas funcionalidades (fora do escopo de extração) — fase futura
- Testes automatizados — fase futura
- Reescrever módulos inteiros — apenas extrair duplicação
- Mudanças na interface do usuário (menus) — apenas refatoração interna
- Migração para outra linguagem — Bash puro é requisito

## Context

Sistema usado em produção em múltiplos clientes com servidores IsCOBOL. Módulos grandes (`backup.sh` 953 linhas, `programas.sh` 823 linhas, `arquivos.sh` 882 linhas) contêm código duplicado que aumenta risco de regressão e dificulta manutenção. Extração deve preservar comportamento — sem mudanças visíveis ao usuário.

Código-fonte em `binarios/`, configurações em `configuracoes/`. Entry point `atualiza.sh`.

## Constraints

- **Linguagem**: Bash 4.0+ — sem dependências externas além de zip, unzip, rsync, wget, tar
- **Compatibilidade**: Deve funcionar em servidores Linux legados com ferramentas mínimas
- **Segurança**: Arquivo `.senhas` deve permanecer 0600, validação de `.config` contra injection deve ser mantida
- **Comportamento**: Extração não pode alterar fluxo, saída, ou arquivos criados/alterados
- **Acesso remoto**: SSH apenas (sem agentes ou serviços externos)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Extrair para `utils.sh` | Já existe como módulo de utilidades compartilhadas | — Pending |
| Não quebrar módulos em arquivos menores | Menor risco, extração cirúrgica apenas | — Pending |
| Preservar nomes de funções originais | Evita mudanças em cascata nos callers | — Pending |
| Priorizar candidatos por linhas economizadas | Máximo impacto com mínimo risco | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 06/07/26 after initialization*
