# Relatório de Revisão de Lógica
## SAV - Atualiza (scripts shell)

Data: 03/06/2026
Scripts revisados: principal.sh, config.sh, utils.sh, auth.sh, arquivos.sh, programas.sh, backup.sh, vaievem.sh, setup.sh

---

# 1. Bugs confirmados ou de alto risco

## 1.1. `setup.sh`: `exit` em funções sourced mata a sessão principal
- Local: `setup.sh` (`_initial_setup`, `_edit_setup`, ramos `*` dos `case`)
- Problema:
  - `exit 1` / `exit 0` aparecem dentro de funções normalmente “sourced” pelo fluxo principal.
  - Quando `setup.sh` é carregado como módulo (e não executado diretamente), `exit` encerra o programa inteiro sem chance de tratamento.
  - Em `_edit_setup` há `exit 0` ao final, que mata o fluxo mesmo quando a edição deu certo.
- Impacto: interrupção abrupta da experiência do usuário, sem limpeza de traps/estado.
- Sugestão:
  - Trocar `exit` por `return` nas rotinas que são chamadas como funções.
  - Centralizar saída em pontos de entrada (`main` / `_encerrar_programa`).

## 1.2. `config.sh`: parser “seguro” rejeita configurações válidas com `${...}`
- Local: `_validar_config_file` (linhas com expansão `${VARIAVEL}`)
- Problema:
  - Há bloqueio literal de qualquer linha contendo `${...}`.
  - Isso invalida configurações comuns como `base=/home/${EMPRESA}` ou referências a variáveis de ambiente.
- Impacto:
  - Configurações legítimas são consideradas inseguras e impedem o boot do sistema.
- Sugestão:
  - Substituir a regra de bloqueio por uma análise sintática mais fina:
    - permitir `${...}` apenas quando se referir a nomes de variáveis conhecidas, sem comandos.

## 1.3. `programas.sh`: `cd` global dentro de rotinas
- Local: `_baixar_pacotes_vaievem` e `_processar_atualizacao_programas`
- Problema:
  - Múltiplos `cd` sem preservar/restaurar diretório anterior.
  - Qualquer interrupção ou erro deixa o processo em diretório diferente do esperado, contaminando execuções seguintes.
- Impacto:
  - Caminhos relativos subsequentes tendem a apontar para lugares errados, gerando “arquivo não encontrado” em etapas posteriores.
- Sugestão:
  - Usar `pushd/popd` ou envolver o bloco com `( cd ... && ... )`.

## 1.4. `principal.sh / config.sh`: risco de duplo `source` de `constantes.sh`
- Local:
  - `principal.sh` carrega `constantes.sh` no topo.
  - Outros módulos também fazem `. "${LIBS_DIR}/constantes.sh"`.
- Problema:
  - Redeclaração de constantes e possíveis sobrescritas.
  - Em bash, isso não para a execução por si só, mas pode mascarar inconsistências de inicialização.
- Impacto:
  - Variáveis podem assumir valores diferentes do esperado dependendo da ordem de carga.
- Sugestão:
  - Centralizar o `source` de `constantes.sh` em um único ponto (de preferência `principal.sh`).

## 1.5. `utils.sh`: função com nome errado / duplicidade de API
- Local: `_mensageb` e ausência de `_mensagec` no escopo do arquivo exibido
- Problema:
  - `auth.sh`, `programas.sh`, `backup.sh`, `vaievem.sh` chamam `_mensagec(...)`.
  - `utils.sh` exibe `_mensageb(...)` para esse papel.
  - Se `_mensagec` não estiver definida em outro módulo, o sistema falha com “command not found” em tempo de execução.
  - `_exibir_mensagem_centralizada` parece ser uma definição alternativa, mas não resolve a ausência de `_mensagec`.
- Impacto:
  - Erro silencioso de “função não existe” em fluxos interativos.
- Sugestão:
  - Unificar a nomenclatura (`_mensagec` ou `_mensageb`) e garantir que apenas um módulo define a função primitiva de mensagem.

## 1.6. `utils.sh`: funções de tela e temporização frágeis
- Local: `_aguardar`, `_exibir_mensagem_corrida`
- Problema:
  - `_aguardar` usa `read -rt` com desvio para `|| :`, o que disfarça Ctrl+C e impede interrupção limpa em fluxos críticos.
  - `_exibir_mensagem_corrida` usa `sleep 0.05` em loop de letras. Funciona como efeito visual, mas deixa execução mais lenta e sensível a interrupções.
- Impacto:
  - Usuário não consegue sair rapidamente de esperas longas.
- Sugestão:
  - Em `_aguardar`, considerar tratamento explícito de sinal (SIGINT).
  - Em fluxos com efeitos visuais, oferecer forma de pular animação.

## 1.7. `auth.sh`: dependência excessiva de funções globais externas
- Local: todo `auth.sh`
- Problema:
  - Usa `_mensagec`, `_linha`, `_log` etc., que são definidas em outros módulos.
  - Não há nenhuma verificação de pré-requisito dessas funções antes do uso.
- Impacto:
  - Se `auth.sh` for carregado fora da ordem prevista, login/cadastro quebram sem mensagem clara.
- Sugestão:
  - No início de módulos com essas dependências, adicionar checagens:
    - `command -v _mensagec >/dev/null 2>&1 || { echo "ERRO: modulo de interface nao carregado"; return 1; }`

---

# 2. Riscos importantes, por módulo

## 2.1. `principal.sh`
- Força `umask 000`, deixando arquivos criados com permissões muito abertas por padrão.
- A verificação `if [[ -f ... ]]; then . ...; fi` de `constantes.sh` não garante que o arquivo está legível; pode avançar sem aviso quando o arquivo existe mas é ilegível.

## 2.2. `config.sh`
- `_configurar_variaveis_sistema` usa variáveis que às vezes vêm do `.config`, às vezes do ambiente, sem distinção clara.
- Em `_validar_configuracao`, usa `${!dir}` ("E_EXEC", "T_TELAS", "BASE1") que são nomes internos; se essas variáveis estiverem vazias, os caminhos resultantes são imprevisíveis.

## 2.3. `arquivos.sh`
- Chama `_ir_para_tools()` no fim de `_recuperar_arquivo_especifico`, mas essa função de navegação não foi revisada em escopo completo.
- Limpeza usa `find ... -mtime +1` combinada com `-delete` e zip paralelo; erro de regex/pattern pode causar expurgo de arquivos errados se `limpetmp` estiver mal formatado.
- A variável `base_trabalho` é `export` em `_selecionar_base_arquivos`, deixando-a vazar para o ambiente global do processo.

## 2.4. `programas.sh`
- Em `_processar_atualizacao_programas`, o bloco de `mv` das extensões assume que `_PROGS_DIR` e `E_EXEC/T_TELAS` estão válidos.
  - Se algum diretório estiver vazio, `mv` pode silenciosamente mover para `.` ou falhar.
- A lógica de reversão apóia-se em backups nomeados como `-anterior.zip` e na existência mínima do zip; backup parcial ou renomeado manualmente pode invalidar a reversão.
- A variável `compilado` pode estar vazia se `config.sh` não tiver inicializado tudo, levando a nomes de arquivo inesperados.

## 2.5. `backup.sh`
- Usa `stat -c%s` para tamanho de arquivo: funciona em GNU/Linux, mas não no macOS.
- Em `_executar_backup_completo` e `_executar_backup_incremental`, o `tar -czf` é feito em background sem tratamento rigoroso de PID/zombie além do `wait` implícito.
- `DEFAULT_TAR` é referenciado, mas não está claro onde e como é inicializado; ausência causa falha silenciosa no backup.
- O backup incremental usa `find -newermt "$data_referencia"` que pode não existir em shells/versões antigas de `find`.

## 2.6. `vaievem.sh`
- `_download_sftp_ssh` valida caminhos, mas `CFG_SSH_HOST` pode permanecer como `sav_servidor` padrão indefinidamente; se o usuário nunca configurou `.ssh/config`, a consistência do fluxo pode falhar.
- Em SFTP, o comando `sftp ... .` pode falhar por causa de wildcard/expansão local do `.` em lugar de destino literal esperado.
- A validação de erro do SFTP compara frases genéricas (`error`, `failed`) e pode perder erros mais específicos ou ter falsos positivos.
- `_upload_rsync` permite sobrescrever `CFG_BACKUP_PATH` por parâmetro: útil, mas cria dois significados para o mesmo nome, o que facilita uso enganoso.

## 2.7. `auth.sh`
- Senhas são lidas com `read -rsp`; ausência de trimming de entradas pode levar a comparação de hash mal sucedida por espaços em branco invisíveis.
- O arquivo `.senhas` pode crescer sem rotação; não há gestão de reaproveitamento de espaço ou migração de antigos usuários inativos.
- A função `_alterar_senha` assume que o usuário atual corresponde ao arquivo de senhas carregado; se houver perda de sincronia, pode atualizar usuário errado por coincidência de nome.

## 2.8. `setup.sh`
- `declare -l sistema base base2 base3 dbmaker enviabackup` e `declare -u empresa` alteram o comportamento de maiúsculas/minúsculas no escopo atual e podem causar colisões com variáveis já existentes.
- `_configure_ssh_access` usa `ssh -o BatchMode=yes`; se a chave não existir ainda, a falha é mascarada e o fluxo cai para modo interativo `ssh sav_servidor exit`. Nada garante que o usuário conclua esse passo.
- Criação de `/usr/local/bin/atualiza` se sobrescreve sem backup de link/atalho anterior.

---

# 3. Resumo de ações recomendadas

1. Remover `exit` de funções sourced em `setup.sh`, converter para `return` com código de erro codificado.
2. Padronizar nome da função de mensagem central (`_mensagec`) e remover nomes alternativos.
3. Eliminar `cd` globais em fluxos operacionais; preferir escopo local (`pushd/popd` ou subshell).
4. Revisar regra de bloqueio de `${...}` no parser de configuração, permitindo expressões legítimas.
5. Centralizar `source` de `constantes.sh` em `principal.sh` apenas.
6. Adicionar checagens de pré-requisitos no topo de `auth.sh`, `setup.sh` e demais módulos dependentes.
7. Tratar `DEFAULT_TAR`, `DEFAULT_ZIP`, `DEFAULT_UNZIP` como obrigatórios ou fornecer fallbacks robustos.
8. Documentar ordem de inicialização exigida e checá-la no boot do sistema.
