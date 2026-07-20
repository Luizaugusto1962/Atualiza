# Análise Estática — Task 5
## Seções 3.9, 3.10 e 3.11 do Relatório de Compatibilidade Linux

---

## 3.9 `binarios/vaievem.sh`

**[INFO]** Linha ~1 — PAD
> `set -euo pipefail` presente. Modo estrito ativo.

**[AVISO]** Linha ~52 — BASH
> `local -n _opts_ref=$1` usa *nameref*, recurso introduzido no Bash 4.3.
> O projeto alvo declara Bash 4.0+ como requisito mínimo; versões 4.0–4.2 não suportam `local -n` e falham com `bash: local: -n: invalid option`.
> **Sugestão:** Elevar o requisito mínimo documentado para Bash 4.3+, ou substituir o nameref por passagem de nome de array via `eval` com sanitização do nome — preferível dado o contexto de servidores legados.

**[INFO]** Linha ~96 — BASH
> `sftp … <<EOF … EOF` — heredoc como stdin do sftp é idiomático e portável em todas as versões-alvo. Nenhuma ação necessária.

**[INFO]** Linha ~221 — BASH
> `printf -v ssh_cmd '%s ' "${ssh_cmd_parts[@]}"` — `printf -v` com array expandido funciona desde Bash 3.1. Portável nos alvos.

**[AVISO]** Linha ~224 — SEG
> `rsync … -e "${ssh_cmd}"` passa a string de comando SSH como argumento único de `-e`. O `rsync` faz *word-splitting* interno nessa string para montar o comando, o que é comportamento esperado aqui, mas qualquer espaço em `CHAVE` (caminho da chave SSH com espaço) quebrará o parsing. O array `ssh_cmd_parts` é construído corretamente, mas a conversão para string descarta a separação segura entre argumentos.
> **Sugestão:** Passar o array diretamente quando possível: `rsync … "${rsync_base[@]}" -e "$(printf '%q ' "${ssh_cmd_parts[@]}")" …`, ou garantir que `DEFAULT_CHAVE_SSH` não contenha espaços via validação no `setup.sh`.

**[BLOQUEANTE]** Linha ~264 — SEG
> `read -ra arquivos_update <<< "$(_obter_arquivos_atualizacao)"` divide a saída pelo `IFS` (espaço por padrão). Se qualquer nome de arquivo retornado por `_obter_arquivos_atualizacao` contiver espaços, o array será particionado incorretamente, gerando caminhos inválidos ou requisições a arquivos inexistentes.
> **Sugestão:** Usar `mapfile -t arquivos_update < <(_obter_arquivos_atualizacao)` (requer que a função emita um arquivo por linha) ou substituir o delimitador: `IFS=$'\n' read -ra arquivos_update <<< "..."`. Garantir que `_obter_arquivos_atualizacao` emita uma linha por arquivo.

**[AVISO]** Linha ~18 — SEG
> `_validar_caminho_seguro` não rejeita caracteres `\n` (newline) nem `\0` (NUL) no caminho. Um caminho contendo newline pode enganar logs ou, em contextos de concatenação de string, criar caminhos duplos. O NUL interrompe strings C mas não Bash, porém pode causar comportamento inesperado em ferramentas externas (`sftp`, `rsync`, `scp`).
> **Sugestão:** Adicionar à regex de validação: `$'[\n\r\0]'` ou testar `[[ "$caminho" =~ $'\n' || "$caminho" =~ $'\r' ]]` antes de retornar 0.

---

## 3.10 `binarios/baixar.sh`

**[INFO]** Linha ~1 — PAD
> `set -euo pipefail` presente. Modo estrito ativo.

**[AVISO]** Linha ~120 — PAD
> `chmod 600 ".senhas"` usa literal `600` hardcoded em vez de `${PERM_FILE_PRIVATE}` definida em `constantes.sh`. Todos os outros pontos do código usam a constante. Esta é a única ocorrência inconsistente.
> **Sugestão:** Substituir por `chmod "${PERM_FILE_PRIVATE}" ".senhas"` para centralizar a política de permissão e facilitar auditorias.

**[AVISO]** Linha ~89 — BASH
> `(cd "${DEFAULT_BACKUP_DIR}" && zip -jm "${zip_nome}" ./*.sh.bkp …)` — o glob `./*.sh.bkp` em subshell é protegido por `shopt -s nullglob` **fora** da subshell (o `nullglob` foi ativado e desativado antes deste bloco para o array `arquivos_sh`, mas não está ativo dentro da subshell do `zip`). Se nenhum `.sh.bkp` existir, o glob permanece literal e o `zip` receberá `./*.sh.bkp` como argumento, falhando com código de saída não-zero.
> Na prática o bloco só é atingido após `backup_sucesso > 0`, então há ao menos um `.bkp` — porém o raciocínio depende de invariante implícita.
> **Sugestão:** Ativar `nullglob` dentro da subshell ou usar `find` para listar os arquivos: `(cd "${DEFAULT_BACKUP_DIR}" && shopt -s nullglob && zip -jm "${zip_nome}" ./*.sh.bkp …)`.

**[INFO]** Linha ~176 — SEG
> `find "${DEFAULT_RECEBE_DIR:?}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +` — uso correto de `${var:?}` impede execução com variável vazia. A operação é irreversível, mas intencional (limpeza pós-instalação). Documentada no código. Nenhuma ação necessária.

**[INFO]** Linha ~204 — GNU
> `wget -q -c "$link" -O …` — GNU wget; adequado para os alvos Linux declarados. BSD/macOS não têm `wget` por padrão, mas o projeto não é alvo dessas plataformas. Nenhuma ação necessária.

---

## 3.11 `binarios/sistema.sh`

**[INFO]** Linha ~1 — PAD
> `set -euo pipefail` presente. Modo estrito ativo.

**[INFO]** Linha ~37 — GNU
> `ping -c 1 -W 3 google.com` — `-W` (timeout em segundos) é opção GNU/Linux. BSD usa `-t`. Adequado para os alvos Linux declarados. Nenhuma ação necessária.

**[INFO]** Linha ~43 — GNU
> `uname -o` retorna `GNU/Linux`. BSD retornaria erro (`illegal option`). Adequado para os alvos Linux. Nenhuma ação necessária.

**[AVISO]** Linha ~58 — GNU
> `ip route get 1 | awk '{print $7;exit}'` — assume que o campo 7 é sempre o IP local. O formato da saída de `ip route get 1` varia entre versões do `iproute2`: em kernels mais recentes ou com roteamento via `ECMP`, a linha pode incluir campo `uid` ou outros atributos antes do IP, deslocando o índice. Em algumas distribuições a saída é `1.0.0.0 via <gw> dev <iface> src <IP> uid <uid>` onde o IP fica em `$7`, mas em outras pode estar em posição diferente.
> **Sugestão:** Extrair pelo rótulo `src` em vez de posição: `ip route get 1 | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}'`. Isso é robusto a variações de formato.

**[BLOQUEANTE]** Linha ~78 — GNU
> `free | grep -v +` — a linha `+/- buffers/cache` (que existia no `free` do `procps` antigo, até ~2.x) **não existe** em `procps-ng` ≥ 3.3.0, presente em Ubuntu 16.04+, Debian 9+, RHEL 7+, e todos os alvos modernos declarados no projeto. Nessas versões, `grep -v +` não filtra nada útil — o `+` não aparece em nenhuma linha, então o arquivo `${LOG_TMP}ramcache` conterá todas as linhas de `free`, incluindo o cabeçalho. O `grep -v "Swap"` e `grep -v "Mem"` subsequentes funcionarão, mas a intenção original de excluir a linha de cache duplicada perdeu o efeito e pode confundir usuários em sistemas legados onde a linha ainda existe.
> Mais criticamente: se executado em sistema **com** a linha antiga (procps 2.x, RHEL 6, CentOS 6), o comportamento é diferente do sistema moderno — a exibição de RAM mostrará a memória "livre real" em vez da memória total.
> **Sugestão:** Remover `grep -v +` inteiramente (já não tem efeito em alvos modernos) e documentar o comportamento esperado. Se compatibilidade com procps antigo for necessária, usar `free -m | awk 'NR==2{print}'` para selecionar a linha `Mem:` diretamente, que é estável em ambas as versões.

**[AVISO]** Linha ~93 — GNU
> `uptime -p` (formato legível, ex.: `up 2 hours, 30 minutes`) é específico do GNU procps; sistemas com BusyBox ou procps antigo não suportam o flag `-p`. O código já tem fallback: `uptime | sed 's/.*up //' | sed 's/,.*//'`. O `2>/dev/null` na chamada principal garante que a falha seja silenciosa e o fallback ative via `||`. Comportamento correto, mas vale documentar que o fallback é o caminho esperado em alvos legados.
> **Sugestão:** Inverter a ordem: tentar o formato portável (`uptime` sem `-p`) primeiro, e usar `-p` como apresentação aprimorada quando disponível.

**[INFO]** Linha ~85 — GNU
> `df -h | grep -E 'Filesystem|^/dev/'` — filtra cabeçalho e dispositivos reais em `/dev/`. Portável em coreutils GNU e BusyBox. Nenhuma ação necessária.
