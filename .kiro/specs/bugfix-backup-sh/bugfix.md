# Bugfix Requirements Document

## Introduction

O módulo `binarios/backup.sh` do sistema SAV contém oito defeitos identificados em revisão manual
do código. Os bugs abrangem ordem incorreta de validação e escrita de variável por referência,
checagem de variável canônica errada após seleção de backup, violação da regra documentada de
`_offline_valido`, lógica de fallback de `find` que não distingue "falhou" de "sem resultados",
risco de diagnóstico enganoso quando `xargs` cria múltiplos lotes de `zip`, restauração incorreta
do CWD em caminho de erro, retorno implícito com código de saída não-zero no caminho feliz de
`_restaurar_backup_completo`, e uso de `ls` com glob que não escapa espaços no nome da empresa.

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN `_validar_pre_backup` é chamada e o diretório base existe no momento do `printf -v` mas é
    removido antes do `[[ ! -d "$_base_ref" ]]` THEN o sistema escreve o caminho inválido na
    variável do chamador antes de validar a existência do diretório, fazendo o chamador operar com
    um caminho que não foi confirmado como válido.

1.2 WHEN `_enviar_backup_avulso` é chamada após `_selecionar_backup` retornar 0 THEN o sistema
    verifica `nome_backup` (variável global que pode conter valor de execução anterior) em vez de
    `backup_selecionado` (a variável canônica de saída), tornando a checagem de segurança código
    morto e incapaz de detectar falha silenciosa de `_selecionar_backup`.

1.3 WHEN `_enviar_backup_avulso` é chamada e `CFG_OFFLINE` contém valor inválido (ex.: `"S"`
    maiúsculo, string vazia não-detectada) THEN o sistema cai no ramo `else` com aviso genérico
    "CFG_OFFLINE nao configurado corretamente", sem usar `_offline_valido` como exigido pelo
    contrato documentado em AGENTS.md, violando a regra que todos os quatro outros call sites já
    respeitam.

1.4 WHEN `_coletar_arquivos_backup` é chamada em um diretório sem arquivos que correspondam aos
    filtros (diretório vazio ou todos excluídos) THEN o sistema re-executa o `find` no fallback
    desnecessariamente, porque `[[ ! -s "$_lista_tmp" ]]` não distingue "find falhou" (arquivo
    de saída vazio por erro) de "find executou com sucesso mas não encontrou nada" (arquivo de
    saída igualmente vazio).

1.5 WHEN `_compactar_backup` é chamada com uma lista de arquivos cuja soma de argumentos excede
    ARG_MAX e `xargs` divide a operação em múltiplos lotes THEN o sistema verifica espaço em
    disco apenas antes do primeiro lote; se o espaço esgotar durante lotes subsequentes, o zip
    falha com `rc_zip != 0` e o erro é reportado como "corrompido" em vez de "sem espaço",
    dificultando o diagnóstico.

1.6 WHEN `_executar_backup_arquivo` é chamada e `_compactar_backup` retorna erro THEN o sistema
    retorna 1 sem restaurar o diretório de trabalho para `SCRIPT_DIR`, violando o contrato
    documentado em AGENTS.md de que toda função que faz `cd` deve restaurar o CWD em todos os
    caminhos de retorno, inclusive os de erro.

1.7 WHEN `_restaurar_backup_completo` conclui com sucesso (unzip retorna 0) THEN o sistema
    retorna o código de saída de `_aguardar_tecla` em vez de 0, porque a função não possui
    `return 0` explícito após a chamada a `_aguardar_tecla`, fazendo o chamador
    (`_restaurar_backup`) propagar um código de erro falso quando `read` falha ou o usuário
    pressiona Ctrl+C.

1.8 WHEN `_verificar_backups_recentes` é chamada e `CFG_EMPRESA` contém espaços THEN o sistema
    executa `ls` com um padrão glob que não escapa espaços no nome da empresa, podendo exibir
    listagem incorreta ou falhar na exibição dos backups recentes (impacto cosmético).

---

### Expected Behavior (Correct)

2.1 WHEN `_validar_pre_backup` resolve o caminho da base de trabalho THEN o sistema SHALL validar
    a existência do diretório (`[[ -d "$_base_ref" ]]`) antes de escrever o valor na variável do
    chamador via `printf -v`, garantindo que a variável só receba um caminho confirmado como válido.

2.2 WHEN `_enviar_backup_avulso` precisa confirmar que a seleção produziu um arquivo válido THEN o
    sistema SHALL verificar `backup_selecionado` (a variável canônica de saída de `_selecionar_backup`)
    em vez de `nome_backup`, detectando corretamente qualquer falha silenciosa de `_selecionar_backup`.

2.3 WHEN `_enviar_backup_avulso` precisa decidir entre envio offline e envio pela rede THEN o
    sistema SHALL usar `_offline_valido` (de `utils.sh`) para validar `CFG_OFFLINE`, seguindo o
    mesmo padrão dos outros call sites e garantindo tratamento correto de valores inválidos.

2.4 WHEN `_coletar_arquivos_backup` executa o `find` com `-printf` THEN o sistema SHALL distinguir
    "find retornou erro" de "find executou com sucesso sem resultados", ativando o fallback apenas
    no primeiro caso e evitando a re-execução desnecessária quando o diretório está vazio.

2.5 WHEN `_compactar_backup` detecta que o zip falhou com `rc_zip != 0` após execução via `xargs`
    THEN o sistema SHALL verificar espaço disponível no momento da falha para incluir diagnóstico
    de "disco cheio" na mensagem de erro, em vez de reportar apenas "corrompido".

2.6 WHEN `_executar_backup_arquivo` retorna por qualquer caminho (sucesso ou erro) THEN o sistema
    SHALL restaurar o CWD para o valor salvo antes do `_diretorio_trabalho`, cumprindo o contrato
    documentado de restauração de CWD em todos os retornos.

2.7 WHEN `_restaurar_backup_completo` conclui a extração com sucesso THEN o sistema SHALL retornar
    0 explicitamente após `_aguardar_tecla`, garantindo que o chamador receba código de sucesso
    independentemente do código de saída de `_aguardar_tecla`.

2.8 WHEN `_verificar_backups_recentes` constrói o padrão para `ls` THEN o sistema SHALL usar o
    mesmo `padrao_empresa` já escapado por `_escapar_glob` (que escapa `* ? [ ]`) e tratar
    espaços no nome da empresa de forma que `ls` receba os argumentos corretamente.

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN `_validar_pre_backup` é chamada com `CFG_BASE_DIR2` configurado e o usuário seleciona
    uma base válida THEN o sistema SHALL CONTINUE TO definir `base_trabalho` com o caminho
    correto e retornar 0.

3.2 WHEN `_enviar_backup_avulso` é chamada após seleção bem-sucedida e `CFG_OFFLINE == "s"` THEN
    o sistema SHALL CONTINUE TO mover o backup para o diretório offline via `_mover_backup_offline`.

3.3 WHEN `_enviar_backup_avulso` é chamada após seleção bem-sucedida e `CFG_OFFLINE == "n"` THEN
    o sistema SHALL CONTINUE TO perguntar confirmação e enviar via `_enviar_backup_rede`.

3.4 WHEN `_coletar_arquivos_backup` é chamada em um diretório com arquivos e o `find` suporta
    `-printf` THEN o sistema SHALL CONTINUE TO preencher `_BACKUP_LISTA` e `_BACKUP_BYTES`
    corretamente sem acionar o fallback.

3.5 WHEN `_coletar_arquivos_backup` é chamada em ambiente onde o `find` não suporta `-printf`
    THEN o sistema SHALL CONTINUE TO acionar o fallback com `-print0` e preencher `_BACKUP_LISTA`
    com tamanhos zerados.

3.6 WHEN `_compactar_backup` é chamada com lista que cabe em um único lote de `xargs` THEN o
    sistema SHALL CONTINUE TO criar o zip atômico via arquivo `.tmp`, validar integridade e
    renomear para o destino final.

3.7 WHEN `_executar_backup_arquivo` conclui com sucesso THEN o sistema SHALL CONTINUE TO retornar
    0 e o zip estará no caminho informado.

3.8 WHEN `_restaurar_backup_completo` falha em qualquer etapa anterior ao unzip THEN o sistema
    SHALL CONTINUE TO retornar 1 após `_aguardar_tecla`.

3.9 WHEN `_verificar_backups_recentes` não encontra backups nos últimos 2 dias THEN o sistema
    SHALL CONTINUE TO retornar 1 sem exibir listagem.

3.10 WHEN `_selecionar_backup` é chamada e o usuário escolhe um arquivo THEN o sistema SHALL
     CONTINUE TO definir tanto `backup_selecionado` quanto `nome_backup` antes de retornar 0.

---

### Bug Condition Summary (pseudocódigo)

```pascal
// BUG 1 — ordem printf-v antes de -d
FUNCTION isBugCondition_1(X)
  INPUT: X = estado do filesystem durante _validar_pre_backup
  RETURN X.diretorio_removido_apos_printf_v = true
END FUNCTION
// Propriedade: printf -v só ocorre APÓS [[ -d "$_base_ref" ]] retornar 0

// BUG 2 — variável canônica errada
FUNCTION isBugCondition_2(X)
  INPUT: X = chamada a _enviar_backup_avulso
  RETURN X.nome_backup_tem_valor_de_execucao_anterior = true
         AND X.backup_selecionado_definido_corretamente = true
END FUNCTION
// Propriedade: checagem usa backup_selecionado, não nome_backup

// BUG 3 — CFG_OFFLINE sem _offline_valido
FUNCTION isBugCondition_3(X)
  INPUT: X.CFG_OFFLINE
  RETURN X.CFG_OFFLINE NOT IN {"s", "n"}  // ex.: "S", "", "sim"
END FUNCTION
// Propriedade: _offline_valido é chamado em vez de [[ "${CFG_OFFLINE}" =~ ^[sn]$ ]]

// BUG 4 — fallback find não distingue falha de vazio
FUNCTION isBugCondition_4(X)
  INPUT: X = resultado do find com -printf
  RETURN find_retornou_0 = true AND X.arquivos_encontrados = 0
END FUNCTION
// Propriedade: fallback ativado apenas quando find retornou != 0

// BUG 5 — diagnóstico enganoso em multi-lote
FUNCTION isBugCondition_5(X)
  INPUT: X = estado em _compactar_backup após rc_zip != 0
  RETURN X.disco_ficou_cheio_durante_xargs = true
END FUNCTION
// Propriedade: mensagem de erro inclui diagnóstico de espaço quando rc_zip != 0

// BUG 6 — CWD não restaurado em erro
FUNCTION isBugCondition_6(X)
  INPUT: X = retorno de _compactar_backup dentro de _executar_backup_arquivo
  RETURN X.compactar_retornou_erro = true
END FUNCTION
// Propriedade: CWD == SCRIPT_DIR em todos os caminhos de retorno

// BUG 7 — return implícito em caminho feliz
FUNCTION isBugCondition_7(X)
  INPUT: X = resultado do unzip em _restaurar_backup_completo
  RETURN X.unzip_retornou_0 = true AND _aguardar_tecla_retornou_nao_zero = true
END FUNCTION
// Propriedade: _restaurar_backup_completo retorna 0 quando unzip retorna 0

// BUG 8 — ls com espaço em CFG_EMPRESA
FUNCTION isBugCondition_8(X)
  INPUT: X.CFG_EMPRESA
  RETURN X.CFG_EMPRESA contém espaço
END FUNCTION
// Propriedade: ls exibe listagem correta independentemente de espaços em CFG_EMPRESA
```
