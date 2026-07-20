# Task 4 — Análise Estática: auth.sh, cadastro.sh, setup.sh

Seções 3.6, 3.7 e 3.8 do relatório de compatibilidade Linux.

---

## 3.6 `binarios/auth.sh`

**[AVISO]** Linha ~14 — SEG
> `SENHA_FILE="${CFG_DIR:-}/.senhas"` é avaliado no nível global no momento do `source`.
> Se `CFG_DIR` ainda não foi exportado pelo processo pai, `CFG_DIR:-` expande para string
> vazia e `SENHA_FILE` passa a ser `"/.senhas"` — caminho na raiz do sistema de arquivos.
> Em operação normal via `principal.sh` o `CFG_DIR` já está definido, mas ao fazer `source
> auth.sh` diretamente (ex.: em testes ou pelo próprio `cadastro.sh` invocado de forma
> isolada) o risco é real.
> **Sugestão:** avaliar sob demanda dentro de cada função que usa o arquivo, ou validar que
> `CFG_DIR` não está vazio logo após a atribuição:
> ```bash
> [[ -z "${CFG_DIR:-}" ]] && { echo "ERRO: CFG_DIR nao definido." >&2; exit 1; }
> SENHA_FILE="${CFG_DIR}/.senhas"
> ```

**[AVISO]** Linha ~17–19 — SEG
> O bloco `if [[ -f "$SENHA_FILE" ]]; then chmod "${PERM_FILE_PRIVATE}" "$SENHA_FILE" …`
> é executado no nível global durante o `source`, com `set -euo pipefail` ativo.
> Se `PERM_FILE_PRIVATE` não estiver definido (variável indefinida sob `set -u`), o script
> aborta imediatamente ao ser carregado — impedindo qualquer operação de autenticação.
> O `2>/dev/null || true` presente no `chmod` protege a falha do comando em si, mas não
> protege a expansão de `${PERM_FILE_PRIVATE}` quando a variável é indefinida.
> **Sugestão:** garantir que `PERM_FILE_PRIVATE` tenha valor padrão antes do bloco, ou
> condicioná-lo com `${PERM_FILE_PRIVATE:-0600}`:
> ```bash
> chmod "${PERM_FILE_PRIVATE:-0600}" "$SENHA_FILE" 2>/dev/null || true
> ```

**[INFO]** Linha ~22 — BASH
> `declare usuario` no nível global do arquivo (fora de qualquer função) declara a variável
> no escopo do processo corrente. Quando `auth.sh` é sourced, `usuario` torna-se global por
> herança de escopo — não porque `declare -g` foi usado. A intenção de torná-la "global de
> módulo" funciona, mas `declare` sem `-g` dentro de uma função teria escopo local. Comentário
> existente esclarece a intenção, mas pode enganar mantenedores futuros.
> **Sugestão:** adicionar comentário explícito ou usar `declare -g usuario` para deixar a
> semântica inequívoca, independentemente de onde o código seja lido.

**[INFO]** Linha ~58 — BASH / GNU
> `_hash_senha()` usa `printf '%s' "$senha" | "$algoritmo" | cut -d' ' -f1` onde
> `HASH_ALGORITHM` padrão é `sha256sum` (GNU coreutils). `sha256sum` está disponível em
> todos os alvos Linux declarados. Não há fallback para sistemas sem GNU coreutils (ex.:
> Alpine BusyBox que usa `sha256sum` com saída diferente, ou macOS sem brew).
> Como os alvos são servidores Linux com coreutils padrão, classifica-se como INFO.
> **Sugestão:** documentar a dependência de `sha256sum` em `_check_instalado` para que
> ausência seja detectada cedo (atualmente não verificada — ver achado em `utils.sh`).

**[INFO]** Linha ~36 — BASH
> `_usuario_valido()` usa `[[ "$usuario" =~ ^[A-Z0-9._-]+$ ]]` — expansão `=~` com
> `BASH_REMATCH` implícito. Correto em Bash 3.2+. O regex não é armazenado em variável
> separada; em Bash < 3.2 ou com `LC_ALL` não definido como `C`, classes de caracteres
> podem se comportar diferente.
> **Sugestão:** adicionar `export LC_ALL=C` antes das comparações com regex de caracteres
> ASCII ou usar variável para o padrão: `local re='^[A-Z0-9._-]+$'; [[ … =~ $re ]]`.

**[INFO]** Linha ~44 — BASH
> `_obter_hash_usuario()` usa `awk -F: -v u="$usuario" '…'` com POSIX awk — compatível.
> O bloco `END {exit !found}` retorna código de saída não zero quando o usuário não é
> encontrado, o que combina corretamente com `set -e` nos chamadores que tratam o retorno.
> Nenhuma correção necessária; registrado para clareza.

**[AVISO]** Linha ~70 — BASH
> Em `_hash_senha()`, `_upper "$(_trim "$usuario")"` (chamado em `_cadastrar_usuario` e
> `_login`) depende de `${1^^}` dentro de `_upper` — sintaxe de expansão de parâmetro
> disponível apenas em **Bash 4.0+**. Em Bash 3.x (macOS padrão, alguns sistemas legados
> mais antigos), esta construção causa erro de sintaxe.
> Os alvos declarados são Bash 4.0+, portanto é AVISO e não BLOQUEANTE.
> **Sugestão:** registrar formalmente a dependência de Bash 4.0+ no cabeçalho do módulo
> e verificar versão mínima no bootstrap (`principal.sh`).

**[INFO]** Linha ~97 — PAD
> Em `_login()`, após login bem-sucedido, `export usuario` torna a variável visível em
> subprocessos. Para um script que não cria subprocessos com `exec`, o `export` é
> desnecessário. Mais relevante: se `_login` for chamado em contexto de subshell (ex.:
> `resultado=$(_login)`), o `export usuario` no subshell não propaga para o pai.
> **Sugestão:** documentar que `usuario` deve ser consumida no mesmo processo; remover
> `export` se não há subprocessos que precisem dela, ou usar `declare -g usuario` para
> reforçar o escopo global no processo pai.

---

## 3.7 `binarios/cadastro.sh`

**[AVISO]** Linha ~26–34 — BASH
> Detecção do diretório via `BASH_SOURCE[0]` — disponível desde Bash 3.0, OK nos alvos.
> O padrão `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` é robusto.
> Contudo, a variável `_self_dir` é criada no escopo global do script e depois removida com
> `unset _self_dir`. Com `set -euo pipefail`, se `cd` ou `pwd` falharem (diretório
> deletado durante execução), o script aborta sem mensagem de erro útil.
> **Sugestão:** envolver em tratamento de erro explícito:
> ```bash
> _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
>     echo "ERRO: Nao foi possivel determinar o diretorio do script." >&2; exit 1
> }
> ```

**[AVISO]** Linha ~41–42 — SEG
> Source de `utils.sh` e `auth.sh` com o padrão `"." "${LIBS_DIR}/utils.sh" 2>/dev/null`.
> O `2>/dev/null` silencia erros de `source`, incluindo erros de sintaxe dentro dos módulos
> carregados. A mensagem de erro alternativa é genérica ("utils.sh nao encontrado") e não
> distingue entre "arquivo não existe" e "arquivo existe mas falhou ao ser carregado".
> **Sugestão:** separar as verificações:
> ```bash
> [[ -f "${LIBS_DIR}/utils.sh" ]] || { echo "Erro: utils.sh nao encontrado."; exit 1; }
> "." "${LIBS_DIR}/utils.sh" || { echo "Erro: falha ao carregar utils.sh."; exit 1; }
> ```

**[INFO]** Linha ~55 — SEG
> `export LC_ALL=C` está presente em `atualiza.sh` mas **não** é re-exportado em
> `cadastro.sh`. Quando `cadastro.sh` é invocado diretamente (`./cadastro.sh`), o `LC_ALL`
> pode não estar definido. Funções `_upper()` / `_trim()` e o regex de validação de usuário
> (`^[A-Z0-9._-]+$`) dependem de `LC_ALL=C` para comportamento ASCII previsível com `awk`
> e expansões Bash.
> **Sugestão:** adicionar `export LC_ALL=C` no início de `cadastro.sh` (após `set -euo
> pipefail`), ou documentar explicitamente que invocação direta requer `LC_ALL=C` no
> ambiente.

**[INFO]** Linha ~60 — BASH
> `read -rp "Escolha uma opcao: " opcao` sem `-t` (timeout) no loop principal do menu.
> As opções `1`, `2` e `0` usam `read -rp "…" -t 5` (timeout de 5 s) mas o `read` do
> menu principal ficará bloqueado indefinidamente se não houver input. Em contexto
> automatizado ou de CI isso pode travar o processo.
> **Sugestão:** adicionar `-t 30` (ou valor configurável) ao `read` principal, com
> tratamento de timeout que redirecione para saída.

**[INFO]** Linha ~47 — PAD
> `read -rp "Pressione ENTER para continuar..." -t 5` em dois pontos do loop usa ordem
> de flags que em algumas versões antigas de Bash pode não aceitar `-t` após `-p`. A ordem
> canônica é `-r -t 5 -p "…"`. Em Bash 4.x esta ordem funciona, mas é boa prática manter
> flags antes do prompt.
> **Sugestão:** reordenar para `read -r -t 5 -p "Pressione ENTER para continuar..."`.

---

## 3.8 `binarios/setup.sh`

**[BLOQUEANTE]** Linha ~228 — SEG
> `chmod "${PERM_DIR_SECURE}" "${SSH_DIR}" "${CONTROL_PATH_BASE}"` onde
> `PERM_DIR_SECURE` é definido como `0755` nas constantes do sistema.
> O diretório `~/.ssh` **deve** ter permissão `0700` (nenhuma leitura/execução por grupo
> ou outros). O OpenSSH rejeita silenciosamente chaves privadas e ignora `~/.ssh/config`
> quando `~/.ssh` tem `o+r` ou `g+r` (permissões `0755` concedem `r-x` para group e
> others). Resultado: SSH configurado pelo script falhará na primeira conexão real sem
> mensagem clara de erro para o usuário.
> **Sugestão:** usar `0700` diretamente para `~/.ssh`, independente de `PERM_DIR_SECURE`:
> ```bash
> chmod 0700 "${SSH_DIR}"
> chmod 0755 "${CONTROL_PATH_BASE}"   # control sockets não precisam de restrição total
> ```
> Ou criar constante dedicada `PERM_DIR_SSH=0700` em `constantes.sh`.

**[AVISO]** Linha ~244 — SEG
> `ssh -o BatchMode=yes sav_servidor exit 2>/dev/null` testa a conexão sem
> `StrictHostKeyChecking`. Se o servidor ainda não está em `~/.ssh/known_hosts` (primeira
> execução), o BatchMode faz o SSH falhar silenciosamente (sem prompt de fingerprint) e
> o código cai no bloco de fallback interativo `ssh sav_servidor exit`. Esse fallback
> funciona, mas o comportamento depende do valor padrão de `StrictHostKeyChecking` do
> cliente SSH instalado — que pode ser `ask` (interativo, OK), `yes` (falha sem
> `known_hosts`, bloqueante) ou `accept-new` (aceita automaticamente, risco de
> MITM em primeira conexão).
> **Sugestão:** conforme convenção do projeto (`AGENTS.md`), usar `_ssh_aceitar_novo()`
> de `utils.sh` para a primeira conexão, garantindo comportamento consistente:
> ```bash
> if ! ssh -o BatchMode=yes sav_servidor exit 2>/dev/null; then
>     echo "Primeira conexao — adicionando fingerprint do servidor..."
>     _ssh_aceitar_novo sav_servidor
> fi
> ```

**[AVISO]** Linha ~31 — BASH
> `declare -l base base2 base3 enviabackup` e `declare -u empresa` no nível global do
> arquivo. `declare -l` (converte para minúsculas na atribuição) e `declare -u` (converte
> para maiúsculas) são extensões **Bash 4.0+**. Em Bash 3.x causam erro de sintaxe.
> Os alvos usam Bash 4.0+, então não é BLOQUEANTE, mas a dependência não está documentada.
> **Sugestão:** adicionar comentário `# Requer Bash 4.0+` junto às declarações, e verificar
> versão mínima no bootstrap do sistema.

**[AVISO]** Linha ~37–38 — PAD
> `echo "$traco"` e `echo ${tracejada}` (sem aspas em alguns pontos) usam `echo` com
> variável que começa com `#`. Se a string começar com `-`, `echo` poderia interpretar
> como flag. Embora `#` não seja `-`, a mistura de `echo` (interpreta flags) com
> `printf '%s\n'` (não interpreta) cria inconsistência. Mais importante: `echo
> ${tracejada}` sem aspas está sujeito a word splitting e glob expansion — se
> `tracejada` contiver espaços ou caracteres glob, o comportamento difere do esperado.
> **Sugestão:** usar `printf '%s\n' "${tracejada}"` de forma consistente, e sempre citar
> variáveis: `echo "${traco}"`.

**[INFO]** Linha ~182 — PAD
> `cp .config .config.bkp` em `_edit_setup()`. A linha executa apenas dentro do bloco
> `if [[ -f "${CFG_DIR}/.config" ]]; then`, então o arquivo existe. No entanto, o
> script faz `cd "${CFG_DIR}"` antes deste ponto, então `.config` é relativo ao CWD
> atual (`$CFG_DIR`). Isso está correto por design, mas depende do `cd` anterior ter
> sido bem-sucedido. O `cd` usa `|| { echo …; _encerrar_programa 1; }`, portanto a
> proteção existe.
> **Sugestão:** nenhuma correção necessária; registrado para clareza de que o `cp` é
> relativo ao `$CFG_DIR` após o `cd`.

**[INFO]** Linha ~193 — BASH
> `declare -g "$nome"="$novo_valor"` em `_editar_variavel()`. `declare -g` dentro de
> função (Bash 4.2+) cria variável no escopo global. Correto nos alvos. Contudo,
> `declare -g` com `"$nome"="$novo_valor"` não preserva atributos `-l`/`-u` definidos
> anteriormente (ex.: `empresa` foi declarada com `-u`; após `declare -g empresa="valor"`,
> o atributo `-u` é perdido). O valor será gravado literalmente sem conversão de case.
> **Sugestão:** ao reatribuir variáveis com atributos, usar referência indireta com
> `printf -v` e preservar atributos:
> ```bash
> printf -v "$nome" '%s' "$novo_valor"
> ```
> Ou reaplique o atributo: `declare -gu empresa` / `declare -gl base` antes da atribuição.

**[AVISO]** Linha ~100 — PAD
> `_setup_iscobol()` usa `read -rp "…" -n1 VERSAO` — lê exatamente 1 caractere sem
> aguardar ENTER. Se o usuário pressionar uma tecla não prevista no `case` (ex.: espaço,
> tecla de função), o script exibe "Alternativa incorreta, saindo!" e chama
> `_encerrar_programa 1` sem dar nova chance ao usuário. Em contexto interativo isso é
> abrupto; em contexto não-interativo (pipe, redirecionamento), `-n1` pode consumir
> apenas parte de uma sequência de escape de tecla especial.
> **Sugestão:** adicionar loop `while true` com revalidação, similar ao padrão já usado
> em `_setup_acesso_remoto()` e `_setup_chave_acesso()`.

**[INFO]** Linha ~262 — SEG
> `cat > "${SSH_CONFIG_FILE}" << EOF … EOF` sobrescreve `~/.ssh/config` incondicionalmente.
> Se o usuário já tiver configurações SSH personalizadas em `~/.ssh/config` (outros hosts,
> IdentityFile, ProxyJump), elas serão perdidas sem aviso.
> **Sugestão:** fazer backup antes de sobrescrever:
> ```bash
> [[ -f "${SSH_CONFIG_FILE}" ]] && cp "${SSH_CONFIG_FILE}" "${SSH_CONFIG_FILE}.bkp.$(date +%Y%m%d%H%M%S)"
> ```
> Ou usar `Include` para adicionar configuração SAV sem sobrescrever o arquivo principal.

**[INFO]** Linha ~48 — BASH
> `_carregar_constantes_setup()` usa `"." "${LIBS_DIR}/constantes.sh"` sem verificar se
> `LIBS_DIR` está definido no momento da chamada (a função é chamada dentro de
> `_initial_setup()` e `_edit_setup()`, antes do bloco de setup de `LIBS_DIR` em `main()`
> se `setup.sh` for invocado diretamente). Em chamada via `atualiza.sh`, `LIBS_DIR` já
> está definido. Em chamada direta `./setup.sh`, `LIBS_DIR` é definido apenas dentro de
> `main()`, então quando `_carregar_constantes_setup` é chamada por `_initial_setup` (que
> é chamada por `main` após definir `LIBS_DIR`), está correto.
> **Sugestão:** nenhuma correção necessária para o fluxo atual; registrado para manutenção
> futura.
