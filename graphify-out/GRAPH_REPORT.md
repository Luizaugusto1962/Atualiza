# Graph Report - Atualiza  (2026-09-03)

## Corpus Check
- 20 files · ~37,733 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 303 nodes · 631 edges · 20 communities (17 shown, 3 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c71442a2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- utils.sh
- menus.sh
- programas.sh
- arquivos.sh
- config.sh
- backup.sh
- setup.sh
- biblioteca.sh
- help.sh
- lembrete.sh
- vaievem.sh
- auth.sh
- principal.sh
- baixar.sh
- atualiza
- variaveis.sh
- sistema.sh
- cadastro.sh
- atualiza.sh
- constantes.sh

## God Nodes (most connected - your core abstractions)
1. `_ler_opcao_menu()` - 19 edges
2. `_exibir_cabecalho_menu()` - 19 edges
3. `_exibir_rodape_menu()` - 19 edges
4. `_processar_opcao_invalida()` - 19 edges
5. `_exibir_titulo_secao()` - 18 edges
6. `_exibir_opcao_menu()` - 18 edges
7. `_exibir_separador_menu()` - 17 edges
8. `_principal()` - 14 edges
9. `_menu_ferramentas()` - 13 edges
10. `_menu_arquivos()` - 12 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (20 total, 3 thin omitted)

### Community 0 - "utils.sh"
Cohesion: 0.11
Nodes (25): _aguardar(), _atualizar_tamanho_terminal(), _aviso(), _checar_dependencias(), _check_instalado(), _confirmar(), _enviar_chave_para_servidor(), _erro() (+17 more)

### Community 1 - "menus.sh"
Cohesion: 0.41
Nodes (28): _definir_base_trabalho(), _exibir_cabecalho_menu(), _exibir_opcao_menu(), _exibir_rodape_menu(), _exibir_separador_menu(), _exibir_titulo_secao(), _ler_opcao_menu(), _menu_ajuda_principal() (+20 more)

### Community 2 - "programas.sh"
Cohesion: 0.15
Nodes (26): _arquivar_zips_progs_dir(), arquivo_compilado_atual, ARQUIVOS_PROGRAMA, _atualizar_programa_offline(), _atualizar_programa_online(), _atualizar_programa_pacote(), _backup_programa_antigo(), _baixar_pacotes_vaievem() (+18 more)

### Community 3 - "arquivos.sh"
Cohesion: 0.15
Nodes (19): _executar_expurgador(), _executar_jutil(), _executar_limpeza_temporarios(), _executar_lista_arquivos(), _limpar_base_especifica(), _listar_logs(), _listar_logs_atualizacao(), _listar_logs_limpeza() (+11 more)

### Community 4 - "config.sh"
Cohesion: 0.12
Nodes (20): _carregar_config_empresa(), _carregar_configuracoes(), _configurar_comandos(), _configurar_diretorios(), _configurar_variaveis_sistema(), _encerrar_programa(), _finalizar_sistema(), _inicializar_sistema_variaveis() (+12 more)

### Community 5 - "backup.sh"
Cohesion: 0.17
Nodes (20): _diretorio_trabalho(), _enviar_backup_avulso(), _enviar_backup_rede(), _enviar_backup_servidor(), _executar_backup(), _executar_backup_completo(), _executar_backup_incremental(), _executar_backup_multiplos_padroes() (+12 more)

### Community 6 - "setup.sh"
Cohesion: 0.19
Nodes (21): _2020(), _2023(), _2024(), _2025(), _2026(), _carregar_constantes_setup(), _configure_ssh_access(), _edit_setup() (+13 more)

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
Nodes (10): _baixar_biblioteca_sincroniza(), _baixar_programas_vaievem(), _enviar_arquivo_multi(), _enviar_rsync(), _enviar_rsync_lote(), _montar_cmd_scp(), _receber_scp(), vaievem.sh script (+2 more)

### Community 11 - "auth.sh"
Cohesion: 0.31
Nodes (7): _cadastrar_usuario(), _login(), _mostrar_boas_vindas(), _obter_hash_usuario(), auth.sh script, _usuario_existe(), _usuario_valido()

### Community 12 - "principal.sh"
Cohesion: 0.31
Nodes (8): AUX_DIRS, _criar_diretorio_seguro(), ERROS_MODULOS, _inicializar_sistema(), _main(), MODULOS_CARREGAR, principal.sh script, UPDATE

### Community 13 - "baixar.sh"
Cohesion: 0.54
Nodes (7): _atualizando(), _atualizar_offline(), _atualizar_online(), _executar_update(), baixar.sh script, _validar_diretorio_operacao(), _voltar_sh_anterior()

### Community 14 - "atualiza"
Cohesion: 0.25
Nodes (7): atualiza, Configuração, Estrutura de Diretórios, Módulos, Pré-requisitos, Segurança, Uso

### Community 15 - "variaveis.sh"
Cohesion: 0.38
Nodes (5): _consultar_variaveis(), variaveis.sh script, _var_carregar_config(), _VAR_CATEGORIAS, _var_exibir_tabular()

### Community 17 - "cadastro.sh"
Cohesion: 1.00
Nodes (3): _encerrar_programa(), main(), cadastro.sh script

## Knowledge Gaps
- **38 isolated node(s):** `atualiza.sh script`, `LC_ALL`, `arquivos.sh script`, `auth.sh script`, `backup.sh script` (+33 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `atualiza.sh script`, `LC_ALL`, `arquivos.sh script` to the rest of the system?**
  _38 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `utils.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.10960960960960961 - nodes in this community are weakly interconnected._
- **Should `programas.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.1455026455026455 - nodes in this community are weakly interconnected._
- **Should `config.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.12333333333333334 - nodes in this community are weakly interconnected._