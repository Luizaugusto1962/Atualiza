# Implementation Plan

## Overview

Plano de implementação para os 8 bugs em `binarios/backup.sh`, seguindo o ciclo exploratório:
(1) escrever testes de condição de bug antes de qualquer correção, (2) escrever testes de
preservação, (3) aplicar as correções na ordem de menor risco (isolados primeiro, fluxo depois),
(4) validar ao fim com `bash testes/run_all.sh`.

Verificação obrigatória após cada tarefa de implementação:

```bash
bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh
```

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2"] },
    { "wave": 3, "tasks": ["3"] },
    { "wave": 4, "tasks": ["4"] },
    { "wave": 5, "tasks": ["5"] },
    { "wave": 6, "tasks": ["6"] },
    { "wave": 7, "tasks": ["7"] },
    { "wave": 8, "tasks": ["8"] },
    { "wave": 9, "tasks": ["9"] },
    { "wave": 10, "tasks": ["10"] },
    { "wave": 11, "tasks": ["11"] }
  ]
}
```

## Tasks

- [ ] 1. Escrever teste exploratório de condição de bug (antes de qualquer correção)
  - **Property 1: Bug Condition** - 8 defeitos em backup.sh
  - **CRITICAL**: Este teste DEVE FALHAR no código não-corrigido — a falha confirma que os bugs existem
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: Este teste codifica o comportamento esperado — validará cada correção quando passar
  - **GOAL**: Surfaçar contraexemplos que demonstrem a existência dos bugs
  - **Scoped PBT Approach**: Bugs determinísticos — escopo restrito aos casos concretos de cada condição
  - Adicionar cases ao `testes/test_backup.sh` (ou arquivo separado em `testes/`) com stubs mínimos:
    - **Bug 1**: grep estático em `_validar_pre_backup` para confirmar que `printf -v` ocorre antes de `[[ ! -d`
    - **Bug 2**: stub `_selecionar_backup` retornando 0 sem definir `backup_selecionado`; `nome_backup` pré-populado; verificar que a checagem atual não detecta o problema (retorna 0 erroneamente em vez de erro interno)
    - **Bug 3**: `CFG_OFFLINE="S"` com stub de `_selecionar_backup`; verificar que cai no `else` genérico em vez de chamar `_offline_erro`
    - **Bug 4**: `find` stubado para retornar 0 com saída vazia (diretório só com `.zip`/`.log`); verificar que o fallback é acionado desnecessariamente
    - **Bug 5**: verificar estaticamente que não há checagem de espaço no bloco pós-`rc_zip`
    - **Bug 6**: stub `_compactar_backup` retornando 1; verificar que `pwd` após a chamada difere do CWD inicial
    - **Bug 7**: stub `_aguardar_tecla` retornando 1; `unzip` stubado retornando 0; verificar que `_restaurar_backup_completo` retorna 1 (antes da correção)
    - **Bug 8**: `CFG_EMPRESA="Empresa SAV"` com diretório temporário contendo um `.zip` recente; verificar que `ls` falha ou lista incorretamente
  - Executar no código não-corrigido: `bash -n binarios/backup.sh && bash testes/test_backup.sh`
  - **EXPECTED OUTCOME**: Falhas nos casos Bug 1–8 (isso é correto — prova que os bugs existem)
  - Documentar os contraexemplos encontrados para entender a causa-raiz
  - Marcar a tarefa como concluída quando os testes estiverem escritos, executados e as falhas documentadas
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [ ] 2. Escrever testes de preservação (ANTES de implementar as correções)
  - **Property 2: Preservation** - Comportamento inalterado nos caminhos não-afetados pelos bugs
  - **IMPORTANT**: Seguir metodologia observation-first — observar o código não-corrigido primeiro
  - Observar: `_validar_pre_backup` com base válida retorna 0 e escreve caminho correto
  - Observar: `_enviar_backup_avulso` com `CFG_OFFLINE="s"` chama `_mover_backup_offline`
  - Observar: `_enviar_backup_avulso` com `CFG_OFFLINE="n"` pergunta confirmação e chama `_enviar_backup_rede`
  - Observar: `_coletar_arquivos_backup` com arquivos presentes e `find` com `-printf` funcional popula `_BACKUP_LISTA` e `_BACKUP_BYTES`
  - Observar: `_coletar_arquivos_backup` em ambiente sem `-printf` aciona fallback com `-print0`
  - Observar: `_compactar_backup` com lista em único lote cria zip atômico, valida integridade e renomeia
  - Observar: `_executar_backup_arquivo` com sucesso retorna 0 com zip no caminho informado
  - Observar: `_restaurar_backup_completo` com falha antes do unzip retorna 1
  - Observar: `_verificar_backups_recentes` sem backups recentes retorna 1 sem listagem
  - Escrever testes baseados em propriedades capturando esses padrões observados (complementam os 35 checks existentes)
  - Executar os testes de preservação no código não-corrigido: `bash testes/test_backup.sh`
  - **EXPECTED OUTCOME**: Testes de preservação PASSAM no código não-corrigido (confirma baseline)
  - Marcar a tarefa como concluída quando os testes estiverem escritos, executados e passando no código não-corrigido
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

- [ ] 3. Corrigir Bug 7 — `_restaurar_backup_completo`: adicionar `return 0` explícito

  - [ ] 3.1 Implementar a correção do Bug 7
    - Localizar o fim da função `_restaurar_backup_completo` em `binarios/backup.sh`
    - Adicionar `return 0` imediatamente após `_aguardar_tecla` no bloco de sucesso (após `_ok "Restauracao completa concluida"`)
    - Garantir que `return 0` vem logo depois de `_aguardar_tecla`, antes do `}` de fechamento da função
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_7(X)` onde `X.unzip_retornou_0 = true AND _aguardar_tecla_retornou_nao_zero = true`_
    - _Expected_Behavior: `_restaurar_backup_completo` retorna 0 quando unzip retorna 0, independentemente do código de saída de `_aguardar_tecla`_
    - _Preservation: `_restaurar_backup_completo` com falha antes do unzip continua retornando 1 (Requirements 3.8)_
    - _Requirements: 2.7, 3.8_

  - [ ] 3.2 Verificar que o teste exploratório do Bug 7 agora passa
    - **Property 1: Expected Behavior** - `_restaurar_backup_completo` com `_aguardar_tecla` retornando 1 retorna 0
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 7 — não escrever novo teste
    - Stub `_aguardar_tecla` retornando 1; unzip stubado retornando 0
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 7 está corrigido)
    - _Requirements: 2.7_

  - [ ] 3.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - Caminhos de erro de `_restaurar_backup_completo` inalterados
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os 35 checks continuam passando (sem regressões)

- [ ] 4. Corrigir Bug 2 — `_enviar_backup_avulso`: verificar `backup_selecionado` em vez de `nome_backup`

  - [ ] 4.1 Implementar a correção do Bug 2
    - Localizar em `_enviar_backup_avulso` o bloco `if [[ -z "${nome_backup:-}" ]]`
    - Substituir `nome_backup` por `backup_selecionado` na checagem
    - Atualizar a mensagem de erro para `"Erro interno: backup_selecionado nao definido apos _selecionar_backup"`
    - A lógica de downstream que usa `nome_backup` não muda (já é derivada de `backup_selecionado` em `_selecionar_backup`)
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_2(X)` onde `X.nome_backup_tem_valor_de_execucao_anterior = true AND X.backup_selecionado_definido_por_selecionar_backup = true`_
    - _Expected_Behavior: checagem usa `backup_selecionado` (variável canônica); falha silenciosa de `_selecionar_backup` é detectada_
    - _Preservation: `_enviar_backup_avulso` com seleção bem-sucedida e `CFG_OFFLINE` válido continua funcionando (Requirements 3.2, 3.3, 3.10)_
    - _Requirements: 2.2, 3.2, 3.3, 3.10_

  - [ ] 4.2 Verificar que o teste exploratório do Bug 2 agora passa
    - **Property 1: Expected Behavior** - Checagem de `backup_selecionado` detecta falha silenciosa
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 2 — não escrever novo teste
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 2 está corrigido)
    - _Requirements: 2.2_

  - [ ] 4.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - Fluxo de `_enviar_backup_avulso` com seleção válida inalterado
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 5. Corrigir Bug 3 — `_enviar_backup_avulso`: substituir acesso direto a `CFG_OFFLINE` por `_offline_valido`

  - [ ] 5.1 Implementar a correção do Bug 3
    - Localizar em `_enviar_backup_avulso` o bloco `if [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]; then ... fi`
    - Substituir pelo padrão canônico dos outros quatro call sites (`baixar.sh:_executar_update`, `biblioteca.sh:_atualizar_transpc`, `biblioteca.sh:_atualizar_biblioteca_offline`, `programas.sh:_atualizar_programa_pacote`):

      ```bash
      if ! _offline_valido; then
          _offline_erro "envio avulso de backup"
          _aguardar_tecla
          return 1
      fi

      if [[ "${CFG_OFFLINE}" == "s" ]]; then
          _mover_backup_offline "$nome_backup"
          return
      fi

      if _confirmar "Enviar backup via rede?" "S"; then
          _enviar_backup_rede "$nome_backup"
      fi
      ```

    - `_offline_valido` está em `utils.sh` (índice 2 em `MODULOS_CARREGAR`) — carrega antes de `backup.sh` (índice 10), sem dependência para frente
    - O `else` com `_aviso` genérico é removido; `_offline_erro` é mais precisa e consistente
    - `return` sem argumento após `_mover_backup_offline` preserva o código de saída da função
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_3(X)` onde `X.CFG_OFFLINE NOT IN {"s", "n"}` (ex.: `"S"`, `""`, `"sim"`)_
    - _Expected_Behavior: `_offline_valido` é chamado; `_offline_erro` é chamada e retorna 1 para valores inválidos_
    - _Preservation: `CFG_OFFLINE="s"` continua chamando `_mover_backup_offline`; `CFG_OFFLINE="n"` continua chamando `_enviar_backup_rede` (Requirements 3.2, 3.3)_
    - _Requirements: 2.3, 3.2, 3.3_

  - [ ] 5.2 Verificar que o teste exploratório do Bug 3 agora passa
    - **Property 1: Expected Behavior** - `CFG_OFFLINE="S"` chama `_offline_erro` e retorna 1
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 3 — não escrever novo teste
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 3 está corrigido)
    - _Requirements: 2.3_

  - [ ] 5.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - Comportamento de `_enviar_backup_avulso` com `CFG_OFFLINE` válido inalterado
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 6. Corrigir Bug 1 — `_validar_pre_backup`: mover `printf -v` para depois de `[[ -d "$_base_ref" ]]`

  - [ ] 6.1 Implementar a correção do Bug 1
    - Localizar em `_validar_pre_backup` os dois blocos consecutivos:
      1. `printf -v "$var_name" '%s' "${_base_ref}"` (devolver valor ao chamador)
      2. `if [[ ! -d "${_base_ref}" ]]; then ... return 1; fi` (validar existência)
    - Trocar a ordem: mover o bloco `printf -v` para imediatamente **após** o bloco `[[ ! -d ]]` passar (inserir `printf -v` após o `fi` do bloco de validação, antes das validações de `DEFAULT_BASEBACKUP_DIR`)
    - Adicionar comentário explicativo: `# Movido para APOS a validacao de existencia: o chamador so recebe o caminho depois que o diretorio foi confirmado como valido.`
    - O chamador só recebe o caminho após confirmação de que o diretório é válido
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_1(X)` onde `X.printf_v_ja_escreveu = true AND X.validacao_d_base_ref_ainda_nao_ocorreu = true`_
    - _Expected_Behavior: `printf -v` ocorre apenas após `[[ -d "$_base_ref" ]]` retornar 0; variável do chamador não recebe caminho não-validado_
    - _Preservation: `_validar_pre_backup` com base válida continua retornando 0 e escrevendo caminho correto (Requirements 3.1)_
    - _Requirements: 2.1, 3.1_

  - [ ] 6.2 Verificar que o teste exploratório do Bug 1 agora passa
    - **Property 1: Expected Behavior** - `printf -v` ocorre após `[[ -d ]]` em `_validar_pre_backup`
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 1 — não escrever novo teste
    - grep em `_validar_pre_backup` para confirmar nova ordem: `[[ ! -d` aparece ANTES de `printf -v`
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 1 está corrigido)
    - _Requirements: 2.1_

  - [ ] 6.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - `_validar_pre_backup` com base válida continua funcionando
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 7. Corrigir Bug 6 — `_executar_backup_arquivo`: salvar e restaurar CWD

  - [ ] 7.1 Implementar a correção do Bug 6
    - Localizar `_executar_backup_arquivo` em `binarios/backup.sh`
    - Adicionar `local _cwd` e `_cwd="$(pwd)"` no início da função (após as declarações de parâmetros)
    - Adicionar `cd "$_cwd" || true` no caminho de erro antes de `return 1` (após `_diretorio_trabalho` falhar)
    - Capturar o retorno de `_compactar_backup`: `local _rc_compactar=0` + `_compactar_backup "$arquivo_destino" "$modo" || _rc_compactar=$?`
    - Adicionar `cd "$_cwd" || true` antes do retorno final (cobre sucesso e todos os códigos de erro 0–3)
    - Substituir o `return` final por `return $_rc_compactar`
    - `cd "$_cwd" || true` segue o padrão do repo (proteção contra `set -e`)
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_6(X)` onde `X.compactar_retornou_erro = true AND X.cwd_foi_modificado_por_diretorio_trabalho = true`_
    - _Expected_Behavior: `pwd == _cwd` em todos os caminhos de saída de `_executar_backup_arquivo`, incluindo os de erro_
    - _Preservation: `_executar_backup_arquivo` com sucesso continua retornando 0 com zip no caminho informado (Requirements 3.7)_
    - _Requirements: 2.6, 3.7_

  - [ ] 7.2 Verificar que o teste exploratório do Bug 6 agora passa
    - **Property 1: Expected Behavior** - CWD restaurado após `_compactar_backup` retornar 1
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 6 — não escrever novo teste
    - Stub `_compactar_backup` retornando 1; verificar que `pwd` após a chamada é igual ao CWD inicial
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 6 está corrigido)
    - _Requirements: 2.6_

  - [ ] 7.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - Fluxo de sucesso de `_executar_backup_arquivo` inalterado
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 8. Corrigir Bug 4 — `_coletar_arquivos_backup`: corrigir lógica do fallback do find

  - [ ] 8.1 Implementar a correção do Bug 4
    - Localizar em `_coletar_arquivos_backup` a linha do primeiro `find` com `-printf` e o bloco de fallback
    - Adicionar `local rc_find=0` antes do `find`
    - Substituir `... || true` por `... || rc_find=$?` na linha do primeiro `find`
    - Alterar a condição do fallback: de `if [[ ! -s "$_lista_tmp" ]]; then` para `if [[ ! -s "$_lista_tmp" ]] && [[ $rc_find -ne 0 ]]; then`
    - `rc_find` declarado como `local` antes do uso — sem SC2154
    - Fallback agora é ativado APENAS quando `find` retornou erro (não suporta `-printf`), não quando não encontrou arquivos (lista vazia mas rc == 0)
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_4(X)` onde `X.find_retornou_0 = true AND X.arquivos_encontrados = 0`_
    - _Expected_Behavior: fallback não executado quando `find` retorna 0 com saída vazia; `_BACKUP_LISTA` fica vazia e `_BACKUP_BYTES` em 0_
    - _Preservation: `find` com resultados continua populando `_BACKUP_LISTA` e `_BACKUP_BYTES` (Requirements 3.4); `find` sem `-printf` continua acionando fallback com `-print0` (Requirements 3.5)_
    - _Requirements: 2.4, 3.4, 3.5_

  - [ ] 8.2 Verificar que o teste exploratório do Bug 4 agora passa
    - **Property 1: Expected Behavior** - Diretório vazio (find rc=0) não aciona fallback
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 4 — não escrever novo teste
    - `find` stubado retornando 0 com saída vazia; verificar que fallback não é acionado
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 4 está corrigido)
    - _Requirements: 2.4_

  - [ ] 8.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - Comportamento de `_coletar_arquivos_backup` com arquivos presentes inalterado
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 9. Corrigir Bug 5 — `_compactar_backup`: melhorar diagnóstico quando xargs parte em múltiplos lotes

  - [ ] 9.1 Implementar a correção do Bug 5
    - Localizar em `_compactar_backup` o bloco após `rc_zip=$?` do `xargs … zip`
    - Adicionar bloco de diagnóstico de disco cheio imediatamente após a captura de `rc_zip`, antes da validação de integridade:

      ```bash
      if [[ $rc_zip -ne 0 ]]; then
          local espaco_pos_falha
          espaco_pos_falha=$(df -kP "$_dir_destino" 2>/dev/null | awk 'NR==2 {print $4}') || espaco_pos_falha=""
          if [[ "$espaco_pos_falha" =~ ^[0-9]+$ ]] && (( espaco_pos_falha < 102400 )); then
              _log "ZIP: rc=${rc_zip} — possivelmente sem espaco em disco (disponivel: ${espaco_pos_falha}KB)" "$log_zip"
          fi
      fi
      ```

    - Limiar de 102 400 KB (100 MB): disco com menos de 100 MB após falha é forte indício de esgotamento
    - Este bloco não altera o fluxo nem os arquivos produzidos — apenas adiciona linha ao log
    - `espaco_pos_falha` declarado com `local` — sem SC2154
    - Proteger `(( espaco_pos_falha < 102400 ))` com `if [[ ... =~ ^[0-9]+$ ]] &&` para evitar aborto por `set -e`
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_5(X)` onde `X.disco_ficou_cheio_durante_xargs_lote_posterior = true`_
    - _Expected_Behavior: quando `rc_zip != 0` e espaço disponível < 100 MB, log inclui "possivelmente sem espaco em disco"_
    - _Preservation: `_compactar_backup` com lista em único lote continua criando zip atômico, validando integridade e renomeando (Requirements 3.6)_
    - _Requirements: 2.5, 3.6_

  - [ ] 9.2 Verificar que o teste exploratório do Bug 5 agora passa
    - **Property 1: Expected Behavior** - Bloco de diagnóstico de espaço presente após `rc_zip`
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 5 — não escrever novo teste
    - Verificação estática: grep em `_compactar_backup` para confirmar presença de diagnóstico de espaço pós-`rc_zip`
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 5 está corrigido)
    - _Requirements: 2.5_

  - [ ] 9.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - Fluxo de sucesso de `_compactar_backup` inalterado
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 10. Corrigir Bug 8 — `_verificar_backups_recentes`: substituir `ls` por `find`/`printf`

  - [ ] 10.1 Implementar a correção do Bug 8
    - Localizar em `_verificar_backups_recentes` o bloco com `find … -print -quit | grep -q .` e a linha `ls -ltrh`
    - Substituir o bloco completo por versão sem `ls`:

      ```bash
      local -a _backups_recentes=()
      mapfile -t _backups_recentes < <(
          find "${DEFAULT_BASEBACKUP_DIR}" -maxdepth 1 -mtime -2 \
              -name "${padrao_empresa}_*.zip" -print 2>/dev/null \
          | sort -r
      ) || true

      if (( ${#_backups_recentes[@]} > 0 )); then
          _linha
          _exibir_mensagem_centralizada "${CIANO}" "Ja existe backup recente em $DEFAULT_BASEBACKUP_DIR:"
          _linha
          local _arq
          for _arq in "${_backups_recentes[@]}"; do
              printf '%s\n' "$_arq"
          done
          _linha
          return 0
      fi
      return 1
      ```

    - `mapfile` requer Bash 4.0+ — target do projeto (ok)
    - `find -name "${padrao_empresa}_*.zip"` recebe o padrão como argumento único entre aspas — sem word-splitting independente de espaços em `CFG_EMPRESA`
    - `mapfile … || true` protege contra `set -e`
    - `(( ${#_backups_recentes[@]} > 0 ))` — proteger com `if` para evitar aborto por `set -e` quando array vazio
    - Verificar: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
    - _Bug_Condition: `isBugCondition_8(X)` onde `X.CFG_EMPRESA contém espaço ou caractere especial de shell`_
    - _Expected_Behavior: listagem de backups recentes exibida sem erros de word-splitting para qualquer valor de `CFG_EMPRESA`_
    - _Preservation: `_verificar_backups_recentes` sem backups recentes continua retornando 1 sem listagem (Requirements 3.9)_
    - _Requirements: 2.8, 3.9_

  - [ ] 10.2 Verificar que o teste exploratório do Bug 8 agora passa
    - **Property 1: Expected Behavior** - `CFG_EMPRESA="Empresa SAV"` não causa falha em `_verificar_backups_recentes`
    - **IMPORTANT**: Re-executar o MESMO teste da tarefa 1 para Bug 8 — não escrever novo teste
    - `CFG_EMPRESA="Empresa SAV"` com diretório temporário contendo um `.zip` recente; verificar que a listagem é exibida sem erro
    - **EXPECTED OUTCOME**: Teste PASSA (confirma que o bug 8 está corrigido)
    - _Requirements: 2.8_

  - [ ] 10.3 Verificar que os testes de preservação continuam passando
    - **Property 2: Preservation** - `_verificar_backups_recentes` sem backups recentes continua retornando 1
    - **IMPORTANT**: Re-executar os MESMOS testes da tarefa 2 — não escrever novos
    - `bash testes/test_backup.sh`
    - **EXPECTED OUTCOME**: Todos os checks continuam passando (sem regressões)

- [ ] 11. Checkpoint — Garantir que todos os testes passam

  - Executar verificação completa: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh`
  - Executar suite completa: `bash testes/run_all.sh`
  - **EXPECTED OUTCOME**: 517 checks (ou mais, se novos testes foram adicionados), 0 falhas
  - Confirmar que `shellcheck -S warning binarios/backup.sh` está 100% limpo (zero avisos)
  - Verificar que todos os 8 bugs foram corrigidos consultando a lista de condições do design.md
  - Se algum teste falhar, perguntar ao usuário antes de prosseguir

## Notes

- **Ordem das correções**: menor risco primeiro (Bug 7 → Bug 2 → Bug 3 → Bug 1 → Bug 6 → Bug 4 → Bug 5 → Bug 8). Bugs isolados e de uma linha antes dos que tocam fluxo.
- **Verificação por tarefa**: `bash -n binarios/backup.sh && shellcheck -S warning binarios/backup.sh && bash testes/test_backup.sh` após cada subtarefa de implementação.
- **Verificação final**: `bash testes/run_all.sh` deve reportar 517 checks (ou mais), 0 falhas.
- **shellcheck**: 100% limpo antes e depois de cada correção. Proteger `(( expr ))` com `if` para evitar aborto por `set -e`.
- **CWD**: toda função que faz `cd` restaura com `cd "$_cwd" || true` em todos os caminhos de retorno (Bug 6).
- **`_offline_valido`**: único ponto de validação de `CFG_OFFLINE`; `_enviar_backup_avulso` era o único call site faltante (Bug 3).
- **`mapfile`**: requer Bash 4.0+, target do projeto — ok (Bug 8).
