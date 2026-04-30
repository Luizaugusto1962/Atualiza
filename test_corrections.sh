#!/usr/bin/env bash
#
# test_corrections.sh - Testes para Validar Correções do AGENTS.md
# Verifica se as correções implementadas estão funcionando corretamente
#
# Uso: ./test_corrections.sh

set -euo pipefail

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Função para exibir resultado do teste
_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    
    ((TESTS_TOTAL++))
    
    if [[ "$result" == "PASS" ]]; then
        printf "${GREEN}✓ PASS${NC} %s\n" "$test_name"
        ((TESTS_PASSED++))
    else
        printf "${RED}✗ FAIL${NC} %s" "$test_name"
        [[ -n "$message" ]] && printf " - %s" "$message"
        printf "\n"
        ((TESTS_FAILED++))
    fi
}

# Teste 1: Verificar se constantes.sh existe e é válido
test_constantes_file() {
    local result="FAIL"
    local message=""
    
    if [[ -f "constantes.sh" ]]; then
        if bash -n "constantes.sh" 2>/dev/null; then
            if grep -q "PERM_DIR_SECURE" "constantes.sh"; then
                result="PASS"
            else
                message="Constantes não encontradas"
            fi
        else
            message="Erro de sintaxe"
        fi
    else
        message="Arquivo não encontrado"
    fi
    
    _test_result "Arquivo constantes.sh válido" "$result" "$message"
}

# Teste 2: Verificar se validation.sh existe e é válido
test_validation_file() {
    local result="FAIL"
    local message=""
    
    if [[ -f "validation.sh" ]]; then
        if bash -n "validation.sh" 2>/dev/null; then
            if grep -q "_validar_caminho" "validation.sh"; then
                result="PASS"
            else
                message="Funções de validação não encontradas"
            fi
        else
            message="Erro de sintaxe"
        fi
    else
        message="Arquivo não encontrado"
    fi
    
    _test_result "Arquivo validation.sh válido" "$result" "$message"
}

# Teste 3: Verificar se funções duplicadas foram removidas
test_no_duplicate_functions() {
    local result="PASS"
    local message=""
    
    # Verificar se _criar_diretorio foi removido do config.sh
    if grep -q "^_criar_diretorio()" config.sh 2>/dev/null; then
        result="FAIL"
        message="Função _criar_diretorio ainda existe em config.sh"
    fi
    
    _test_result "Funções duplicadas removidas" "$result" "$message"
}

# Teste 4: Verificar se carregamento de constantes está correto
test_constants_loading() {
    local result="FAIL"
    local message=""
    local files_with_constants=0
    
    # Verificar arquivos que devem carregar constantes
    local files=("principal.sh" "config.sh" "auth.sh" "utils.sh" "validation.sh")
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]] && grep -q "constantes.sh" "$file"; then
            ((files_with_constants++))
        fi
    done
    
    if (( files_with_constants >= 4 )); then
        result="PASS"
    else
        message="Apenas $files_with_constants arquivos carregam constantes"
    fi
    
    _test_result "Carregamento de constantes" "$result" "$message"
}

# Teste 5: Verificar se aliases de compatibilidade existem
test_compatibility_aliases() {
    local result="FAIL"
    local message=""
    
    if [[ -f "utils.sh" ]]; then
        if grep -q "_limpa_tela()" utils.sh && grep -q "_mensagec()" utils.sh; then
            result="PASS"
        else
            message="Aliases de compatibilidade não encontrados"
        fi
    else
        message="utils.sh não encontrado"
    fi
    
    _test_result "Aliases de compatibilidade" "$result" "$message"
}

# Teste 6: Verificar se validação de configuração foi melhorada
test_config_validation() {
    local result="FAIL"
    local message=""
    
    if [[ -f "config.sh" ]]; then
        if grep -q "_carregar_config_seguro" config.sh; then
            result="PASS"
        else
            message="Função de carregamento seguro não encontrada"
        fi
    else
        message="config.sh não encontrado"
    fi
    
    _test_result "Validação de configuração melhorada" "$result" "$message"
}

# Teste 7: Verificar se sistema de traps foi implementado
test_trap_system() {
    local result="FAIL"
    local message=""
    
    if [[ -f "utils.sh" ]]; then
        if grep -q "_setup_traps" utils.sh && grep -q "_cleanup_on_exit" utils.sh; then
            result="PASS"
        else
            message="Sistema de traps não encontrado"
        fi
    else
        message="utils.sh não encontrado"
    fi
    
    _test_result "Sistema de traps implementado" "$result" "$message"
}

# Teste 8: Verificar sintaxe de todos os arquivos .sh
test_syntax_all_files() {
    local result="PASS"
    local message=""
    local failed_files=()
    
    for file in *.sh; do
        [[ -f "$file" ]] || continue
        if ! bash -n "$file" 2>/dev/null; then
            failed_files+=("$file")
        fi
    done
    
    if [[ ${#failed_files[@]} -gt 0 ]]; then
        result="FAIL"
        message="Erros de sintaxe em: ${failed_files[*]}"
    fi
    
    _test_result "Sintaxe de todos os arquivos" "$result" "$message"
}

# Teste 9: Verificar se NAMING_CONVENTIONS.md foi criado
test_naming_conventions() {
    local result="FAIL"
    local message=""
    
    if [[ -f "NAMING_CONVENTIONS.md" ]]; then
        if grep -q "Convenções de Nomenclatura" "NAMING_CONVENTIONS.md"; then
            result="PASS"
        else
            message="Conteúdo inválido"
        fi
    else
        message="Arquivo não encontrado"
    fi
    
    _test_result "Documentação de nomenclatura" "$result" "$message"
}

# Teste 10: Verificar se constantes estão sendo usadas
test_constants_usage() {
    local result="FAIL"
    local message=""
    local usage_count=0
    
    # Verificar uso de algumas constantes importantes
    local constants=("PERM_DIR_SECURE" "DEFAULT_SSH_PORT" "DEFAULT_COLUMNS")
    
    for const in "${constants[@]}"; do
        if grep -r "\${$const}" *.sh >/dev/null 2>&1; then
            ((usage_count++))
        fi
    done
    
    if (( usage_count >= 2 )); then
        result="PASS"
    else
        message="Apenas $usage_count constantes sendo usadas"
    fi
    
    _test_result "Uso de constantes" "$result" "$message"
}

# Função principal
main() {
    printf "${BLUE}=== TESTE DE CORREÇÕES AGENTS.MD ===${NC}\n\n"
    
    # Executar todos os testes
    test_constantes_file
    test_validation_file
    test_no_duplicate_functions
    test_constants_loading
    test_compatibility_aliases
    test_config_validation
    test_trap_system
    test_syntax_all_files
    test_naming_conventions
    test_constants_usage
    
    # Resumo
    printf "\n${BLUE}=== RESUMO DOS TESTES ===${NC}\n"
    printf "Total de testes: %d\n" "$TESTS_TOTAL"
    printf "${GREEN}Passou: %d${NC}\n" "$TESTS_PASSED"
    printf "${RED}Falhou: %d${NC}\n" "$TESTS_FAILED"
    
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    printf "Taxa de sucesso: %d%%\n" "$success_rate"
    
    if (( TESTS_FAILED == 0 )); then
        printf "\n${GREEN}🎉 TODOS OS TESTES PASSARAM!${NC}\n"
        printf "${GREEN}As correções do AGENTS.md foram implementadas com sucesso.${NC}\n"
        exit 0
    else
        printf "\n${YELLOW}⚠️  ALGUNS TESTES FALHARAM${NC}\n"
        printf "${YELLOW}Revise as correções que falharam nos testes.${NC}\n"
        exit 1
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi