# Graph Report - Atualiza  (2026-07-10)

## Corpus Check
- 27 files · ~38,044 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 353 nodes · 667 edges · 27 communities (25 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `946e48c4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- utils.sh
- menus.sh
- config.sh
- programas.sh
- backup.sh
- setup.sh
- arquivos.sh
- biblioteca.sh
- help.sh
- lembrete.sh
- vaievem.sh
- principal.sh
- auth.sh
- Architecture: Atualiza
- Concerns: Atualiza
- Conventions: Atualiza
- Integrations: Atualiza
- variaveis.sh
- Stack: Atualiza
- Testing: Atualiza
- atualiza2026
- baixar.sh
- sistema.sh
- Structure: Atualiza
- cadastro.sh
- constantes.sh
- atualiza.sh

## God Nodes (most connected - your core abstractions)
1. `_ler_opcao_menu()` - 19 edges
2. `_exibir_cabecalho_menu()` - 19 edges
3. `_exibir_rodape_menu()` - 19 edges
4. `_processar_opcao_invalida()` - 19 edges
5. `_exibir_titulo_secao()` - 18 edges
6. `_exibir_opcao_menu()` - 18 edges
7. `_exibir_separador_menu()` - 17 edges
8. `_principal()` - 13 edges
9. `_menu_arquivos()` - 13 edges
10. `_menu_ferramentas()` - 13 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (27 total, 2 thin omitted)

### Community 0 - "utils.sh"
Cohesion: 0.11
Nodes (28): _aguardar(), _aviso(), _checar_dependencias(), _check_instalado(), _confirmar(), _enviabackup_para_receber(), _enviar_chave_para_servidor(), _erro() (+20 more)

### Community 1 - "menus.sh"
Cohesion: 0.41
Nodes (28): _definir_base_trabalho(), _exibir_cabecalho_menu(), _exibir_opcao_menu(), _exibir_rodape_menu(), _exibir_separador_menu(), _exibir_titulo_secao(), _ler_opcao_menu(), _menu_ajuda_principal() (+20 more)

### Community 2 - "config.sh"
Cohesion: 0.11
Nodes (22): _carregar_config_empresa(), _carregar_configuracoes(), _configurar_comandos(), _configurar_diretorios(), _configurar_limpeza_automatica(), _configurar_variaveis_sistema(), _define_category_vars(), _encerrar_programa() (+14 more)

### Community 3 - "programas.sh"
Cohesion: 0.17
Nodes (22): ARQUIVO_COMPILADO_ATUAL, ARQUIVOS_PROGRAMA, _atualizar_programa_offline(), _atualizar_programa_online(), _atualizar_programa_pacote(), _baixar_pacotes_vaievem(), _coletar_artefatos_atualizacao(), _mensagem_conclusao_reversao() (+14 more)

### Community 4 - "backup.sh"
Cohesion: 0.20
Nodes (20): _diretorio_trabalho(), _enviar_backup_avulso(), _enviar_backup_rede(), _enviar_backup_servidor(), _executar_backup(), _executar_backup_completo(), _executar_backup_incremental(), _executar_backup_multiplos_padroes() (+12 more)

### Community 5 - "setup.sh"
Cohesion: 0.19
Nodes (21): _2020(), _2023(), _2024(), _2025(), _2026(), _carregar_constantes_setup(), _configure_ssh_access(), _edit_setup() (+13 more)

### Community 6 - "arquivos.sh"
Cohesion: 0.16
Nodes (11): _executar_jutil(), _executar_limpeza_temporarios(), _executar_lista_arquivos(), _limpar_base_especifica(), _processar_lista_arquivos(), _recuperar_arquivo_especifico(), _recuperar_arquivo_individual(), _recuperar_arquivos_principais() (+3 more)

### Community 7 - "biblioteca.sh"
Cohesion: 0.18
Nodes (16): ATUALIZA1, ATUALIZA2, ATUALIZA3, _atualizar_biblioteca_offline(), _atualizar_transpc(), _definir_variaveis_biblioteca(), _executar_atualizacao_biblioteca(), pids (+8 more)

### Community 8 - "help.sh"
Cohesion: 0.29
Nodes (10): _ajuda_no_geral(), _ajuda_rapida(), _buscar_manual(), _exibir_ajuda_contextual(), _exibir_manual_completo(), _exibir_paginado(), _exibir_secao_manual(), _exportar_manual() (+2 more)

### Community 9 - "lembrete.sh"
Cohesion: 0.21
Nodes (6): _apagar_arquivo_configuracoes(), _apagar_aviso_entrada(), _apagar_nota_existente(), _mostrar_notas_iniciais(), lembrete.sh script, _visualizar_notas_arquivo()

### Community 10 - "vaievem.sh"
Cohesion: 0.44
Nodes (10): _adicionar_opcoes_chave(), _baixar_biblioteca_sincroniza(), _baixar_programas_vaievem(), _enviar_arquivo_multi(), _enviar_rsync(), _receber_scp(), _receber_sftp_ssh(), vaievem.sh script (+2 more)

### Community 11 - "principal.sh"
Cohesion: 0.36
Nodes (9): AUX_DIRS, _caminho_modulo(), _carregar_modulos(), _criar_diretorio_seguro(), _encerrar_programa(), _inicializar_sistema(), _main(), principal.sh script (+1 more)

### Community 12 - "auth.sh"
Cohesion: 0.33
Nodes (6): _cadastrar_usuario(), _login(), _obter_hash_usuario(), auth.sh script, _usuario_existe(), _usuario_valido()

### Community 13 - "Architecture: Atualiza"
Cohesion: 0.22
Nodes (8): Architecture: Atualiza, Data Flow, Key Abstractions, Layer Architecture, Module Loading Order, Process Model, Security Architecture, System Pattern

### Community 14 - "Concerns: Atualiza"
Cohesion: 0.22
Nodes (8): Compatibility, Concerns: Atualiza, Maintainability, Performance, Recommendations, Reliability, Security, Technical Debt

### Community 15 - "Conventions: Atualiza"
Cohesion: 0.22
Nodes (8): Code Style, Conventions: Atualiza, Error Handling, Function Conventions, Logging, Module Pattern, Naming Rules, Security Conventions

### Community 16 - "Integrations: Atualiza"
Cohesion: 0.22
Nodes (8): Authentication, External Tools, File Formats Managed, GitHub, Integrations: Atualiza, Offline Updates, Remote Server, Transfer Protocols

### Community 17 - "variaveis.sh"
Cohesion: 0.36
Nodes (6): _consultar_variaveis(), variaveis.sh script, _var_carregar_config(), _VAR_CATEGORIAS, _var_exibir_tabular(), _var_verificar_dependencias()

### Community 18 - "Stack: Atualiza"
Cohesion: 0.25
Nodes (7): Configuration, Dependencies, Dev Dependencies, IsCOBOL Integration, Language & Runtime, Project Structure, Stack: Atualiza

### Community 19 - "Testing: Atualiza"
Cohesion: 0.25
Nodes (7): CI/CD, Coverage, Developer Tooling, Improvement Opportunities, Testing Approach, Testing: Atualiza, Validation Mechanisms

### Community 20 - "atualiza2026"
Cohesion: 0.29
Nodes (6): atualiza2026, Configuração, Estrutura de Arquivos, Pré-requisitos, Segurança, Uso

### Community 21 - "baixar.sh"
Cohesion: 0.60
Nodes (5): _atualizando(), _atualizar_offline(), _atualizar_online(), _executar_update(), baixar.sh script

### Community 23 - "Structure: Atualiza"
Cohesion: 0.33
Nodes (5): Change History, Directory Layout, Key File Locations, Naming Conventions, Structure: Atualiza

### Community 24 - "cadastro.sh"
Cohesion: 1.00
Nodes (3): _encerrar_programa(), main(), cadastro.sh script

### Community 25 - "constantes.sh"
Cohesion: 0.83
Nodes (3): _carregar_config_seguro(), _encerrar_programa(), constantes.sh script

## Knowledge Gaps
- **77 isolated node(s):** `atualiza.sh script`, `LC_ALL`, `arquivos.sh script`, `auth.sh script`, `backup.sh script` (+72 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `atualiza.sh script`, `LC_ALL`, `arquivos.sh script` to the rest of the system?**
  _77 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `utils.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.10512820512820513 - nodes in this community are weakly interconnected._
- **Should `config.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.11375661375661375 - nodes in this community are weakly interconnected._