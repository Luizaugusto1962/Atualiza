# Testes

O projeto atualmente **não possui test suite automatizado**. O sistema é validado por execução manual e verificação de comportamento.

## Checklist de Verificação Manual

### Inicialização

- [ ] `./atualiza.sh` carrega todos os módulos sem erros
- [ ] `./atualiza.sh --setup` inicia o assistente de configuração
- [ ] `./atualiza.sh --cadastro` inicia o cadastro de usuários
- [ ] Argumento inválido exibe mensagem de uso
- [ ] Terminal não interativo é rejeitado

### Configuração

- [ ] `./atualiza.sh --setup` cria `configuracoes/.config` válido
- [ ] Arquivo `.config` mal formatado é rejeitado com erro
- [ ] Command injection no `.config` é bloqueado
- [ ] Path traversal é bloqueado

### Autenticação

- [ ] Login com usuário/senha válidos funciona
- [ ] Senha incorreta é rejeitada
- [ ] 3 tentativas inválidas bloqueiam o login
- [ ] Cadastro de usuário funciona
- [ ] Alteração de senha funciona
- [ ] Usuário duplicado é rejeitado

### Menus

- [ ] Menu principal exibe todas as opções
- [ ] Submenus navegam corretamente
- [ ] Opção 9 retorna ao menu anterior
- [ ] Opção inválida exibe mensagem de erro
- [ ] Ajuda contextual (`H`) funciona
- [ ] Manual completo (`M`) funciona
- [ ] Sair (`Q`) encerra o sistema

### Arquivos

- [ ] Limpeza de temporários compacta e remove arquivos
- [ ] Expurgador remove arquivos com mais de 30 dias
- [ ] Envio de arquivos por scp/rsync
- [ ] Recebimento de arquivos

### Backup

- [ ] Backup completo da base de dados
- [ ] Backup incremental
- [ ] Restauração de backup

### Segurança

- [ ] Arquivo `.senhas` tem permissão `0600`
- [ ] Senhas armazenadas como hash (não texto plano)
- [ ] `set -euo pipefail` ativo em todos os scripts
- [ ] Path traversal bloqueado em todas as entradas

## Como Adicionar Testes

Para criar testes automatizados futuramente:

1. Estrutura sugerida: `tests/` na raiz do projeto
2. Framework: `bats` (Bash Automated Testing System)
3. Cobertura esperada: autenticação, validação de config, e fluxos de menu

```bash
# Exemplo de teste com bats
@test "login com senha correta" {
    run _login
    [ "$status" -eq 0 ]
}
```
