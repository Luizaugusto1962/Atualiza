# Análise Estática — Task 7
## Seções 3.16 a 3.19 do Relatório de Compatibilidade Linux

---

## 3.16 `menus.sh`

**[INFO]** Linha ~1 — PAD
> `set -euo pipefail` presente. Conformidade com o padrão do projeto.

**[BLOQUEANTE]** Linha ~13-16 — SEG/BASH
> `_criar_diretorio_seguro` é chamada no nível global durante o `source` do módulo, fora de qualquer função.
> Com `set -e` ativo, se a chamada falhar (ex.: permissão negada, `PERM_DIR_SECURE` ou `LOG_ATU` ainda não
> definidas por módulo anterior), toda a sequência `_carregar_modulos` aborta — o sistema não inicializa.
> O carregamento de módulos é ordenado (`principal.sh`), mas a janela de falha existe sempre que
> `menus.sh` for carregado antes de `constantes.sh` definir `PERM_DIR_SECURE`, ou quando o diretório
> de configurações não puder ser criado em ambiente restrito (ex.: RHEL mínimo, container).
>
> **Sugestão:** mover a chamada para dentro de uma função de inicialização (`_menus_inicializar`) invocada
> explicitamente por `_carregar_modulos`, ou proteger com `|| true` e tratar o erro sem abortar o source.

**[AVISO]** Linha ~47 — BASH
> `case "${opcao,,}"` usa expansão de caixa-baixa do Bash 4.0+. Compatível com o requisito mínimo do
> projeto (Bash 4.0), mas falha silenciosamente em Bash 3.x (macOS antigo, AIX).
>
> **Sugestão:** documentar o requisito Bash ≥ 4.0 no cabeçalho do arquivo (já consta em AGENTS.md;
> reforçar com comentário inline se desejado).

**[AVISO]** Linha ~196-200 — SEG
> Em `_menu_biblioteca`, o arquivo `${CFG_DIR}/.versao` é carregado via `"." "${CFG_DIR}/.versao"` sem
> passar pelo validador `_validar_config_file`. Qualquer conteúdo malicioso no arquivo `.versao`
> (command injection) é executado diretamente no shell corrente. O padrão do projeto exige validação
> prévia para todos os arquivos de configuração carregados via source.
>
> **Sugestão:** substituir por:
> ```bash
> if [[ -f "${CFG_DIR}/.versao" ]]; then
>     if command -v _validar_config_file >/dev/null 2>&1 && \
>        _validar_config_file "${CFG_DIR}/.versao"; then
>         "." "${CFG_DIR}/.versao" 2>/dev/null || _aviso "Falha ao carregar .versao" >&2
>     else
>         _aviso "Validação de .versao falhou; arquivo não carregado" >&2
>     fi
> fi
> ```

**[INFO]** Linha ~364 — BASH
> `${!base_var}` (indirect expansion) exige Bash 2.0+ — sem risco prático nos alvos suportados.

---

## 3.17 `help.sh`

**[INFO]** Linha ~1 — PAD
> `set -euo pipefail` presente. Conformidade com o padrão do projeto.

**[AVISO]** Linha ~183 — TERM
> `grep -in --color=always "$termo" "$MANUAL_FILE"` força sequências ANSI de cor
> independentemente de o stdout ser um terminal (`-t 1`). Em saída redirecionada para arquivo,
> pipe ou log, os códigos de escape aparecem literalmente, corrompendo o conteúdo.
>
> **Sugestão:** usar `--color=auto` (padrão do grep GNU) ou condicionar:
> ```bash
> local color_flag="--color=never"
> [[ -t 1 ]] && color_flag="--color=always"
> grep -in $color_flag "$termo" "$MANUAL_FILE"
> ```

**[INFO]** Linha ~36 — PAD
> `echo "$conteudo" | wc -l` — `echo` acrescenta um `\n` final; `wc -l` contará uma linha a
> mais se o conteúdo não terminar com newline, ou contagem correta se terminar. Na prática, para
> texto gerado internamente o impacto é mínimo (paginação pode exibir uma página extra vazia no
> limite exato), mas é uma imprecisão conhecida.
>
> **Sugestão:** usar `printf '%s\n' "$conteudo" | wc -l` ou `<<<` com `wc -l`:
> ```bash
> total_linhas=$(wc -l <<< "$conteudo")
> ```

**[INFO]** Linha ~43 e ~73 — PAD
> `echo "$conteudo" | sed -n "…p"` — mesma observação do `echo`: o newline extra pode
> fazer o `sed` processar uma linha em branco adicional no final da saída. Impacto cosmético.
>
> **Sugestão:** substituir `echo "$conteudo" |` por `sed -n "…p" <<< "$conteudo"` (herestring,
> Bash 3.0+) para evitar a linha extra e eliminar o subshell desnecessário.

**[INFO]** Linha ~86 e ~92 — PAD
> `tail -n +${linha_inicio}` e `sed -n "${inicio},${fim}p"` — sintaxe POSIX; sem restrição
> de compatibilidade nos alvos.

---

## 3.18 `lembrete.sh`

**[INFO]** Linha ~1 — PAD
> `set -euo pipefail` presente. Conformidade com o padrão do projeto.

**[INFO]** Linha ~76 e ~113 — TERM
> `tput cols 2>/dev/null || echo 80` — fallback correto; sem risco. O redirecionamento de
> stderr absorve falhas em terminais `dumb` ou sem ncurses.

**[INFO]** Linha ~85 — GNU
> `fold -s -w "$largura"` — GNU coreutils. Disponível em todas as distros-alvo (RHEL 7/8/9,
> Debian, Ubuntu). Sem risco prático.

**[AVISO]** Linha ~72 e ~149 — GNU
> `${EDITOR:-nano}` usado em `_editar_aviso_existente` e `_editar_nota_existente`.
> `nano` não faz parte da instalação mínima do RHEL 8 (`@minimal` ou `@core`); pode estar
> ausente em containers ou imagens enxutas. `vi`/`vim` é garantido em praticamente todos os
> perfis de instalação RHEL/CentOS/Debian.
>
> **Sugestão:** alterar o fallback para `vi`:
> ```bash
> ${EDITOR:-vi} "$arquivo"
> ```
> O usuário ainda pode sobrescrever definindo `$EDITOR`.

**[AVISO]** Linha ~24 — SEG
> `cat >> "$arquivo_notas"` lê de stdin sem qualquer limite de tamanho ou validação de
> conteúdo. Em uso interativo o comportamento é o esperado (Ctrl+D encerra), mas a função
> depende de stdin ser um terminal real; em chamadas não-interativas (pipe, redirecionamento,
> script automatizado) pode consumir entrada inesperada ou travar indefinidamente aguardando EOF.
>
> **Sugestão:** verificar `[[ -t 0 ]]` antes de `cat`:
> ```bash
> if [[ -t 0 ]]; then
>     cat >> "$arquivo_notas"
> else
>     _erro "Entrada não-interativa não suportada para escrita de notas"
>     return 1
> fi
> ```

---

## 3.19 `variaveis.sh`

**[INFO]** Linha ~2 e ~15 — PAD
> `set -euo pipefail` declarado **duas vezes** (linhas ~2 e ~15). Redundante porém inofensivo.
>
> **Sugestão:** remover a segunda ocorrência para clareza.

**[BLOQUEANTE]** Linha ~27 — TERM
> ```bash
> BOLD="$(tput bold)"
> ```
> Esta atribuição ocorre no **nível global**, fora de qualquer função, durante o `source` do
> módulo. Com `set -e` ativo:
> - Se `tput bold` falhar (terminal `dumb`, variável `TERM` não definida, ncurses ausente —
>   comum em sessões SSH sem pseudoterminais, containers, systemd services),
>   o processo retorna código ≠ 0 e o `set -e` **aborta imediatamente o source**.
> - Como `variaveis.sh` é carregado por `_carregar_modulos`, a falha aborta o carregamento
>   completo do sistema — o programa não inicia.
> - Não há `|| true` nem `2>/dev/null` protegendo a chamada.
>
> O padrão correto do projeto (ver `config.sh`) é guardar chamadas `tput` com verificação de
> terminal ou dentro de funções com tratamento de erro.
>
> **Sugestão:** mover para dentro de uma função ou adicionar proteção:
> ```bash
> # Opção 1 — fallback seguro no nível global
> BOLD="$(tput bold 2>/dev/null || printf '')"
>
> # Opção 2 — atribuição condicional (melhor)
> if [[ -t 1 ]]; then
>     BOLD="$(tput bold 2>/dev/null || printf '')"
> else
>     BOLD=""
> fi
> ```

**[INFO]** Linha ~18-26 — BASH
> `declare -gA _VAR_CATEGORIAS=(…)` e `${!_VAR_CATEGORIAS[@]}` requerem Bash 4.0+.
> Compatível com o requisito mínimo do projeto.

**[AVISO]** Linha ~49-52 — SEG
> Fallback em `_var_carregar_config`:
> ```bash
> set -a; "." "$config_file"; set +a
> ```
> Exporta **todas** as variáveis do arquivo de configuração para o ambiente do processo sem
> passar pelo validador `_validar_config_file`. Se `_carregar_config_seguro` não estiver
> disponível (ordem de carregamento incorreta ou módulo ausente), qualquer variável com
> nome válido no `.config` é exportada, incluindo potenciais sobreescritas de variáveis
> sensíveis do sistema (`PATH`, `IFS`, `LD_PRELOAD`).
>
> **Sugestão:** o fallback não deve executar `set -a`. Se `_carregar_config_seguro` não
> estiver disponível, registrar aviso e retornar 1 sem carregar:
> ```bash
> else
>     _aviso "Dependência _carregar_config_seguro não disponível; config não carregado." >&2
>     return 1
> fi
> ```

---

## Resumo por Severidade — Seções 3.16 a 3.19

| Severidade   | Total | Arquivos                              |
|--------------|-------|---------------------------------------|
| BLOQUEANTE   | 2     | `menus.sh` (L13), `variaveis.sh` (L27)|
| AVISO        | 5     | `menus.sh` (L47, L196), `help.sh` (L183), `lembrete.sh` (L72, L24), `variaveis.sh` (L49) |
| INFO         | 8     | `menus.sh` (L1, L364), `help.sh` (L1, L36, L43, L86), `lembrete.sh` (L1, L76, L85), `variaveis.sh` (L2, L18) |

> **Nota:** os dois achados BLOQUEANTES (`_criar_diretorio_seguro` em nível global em `menus.sh`
> e `tput bold` em nível global em `variaveis.sh`) compartilham a mesma raiz: código com
> efeitos colaterais executado durante `source`, incompatível com `set -e`. Ambos devem ser
> corrigidos antes de qualquer deploy em ambiente restrito.
