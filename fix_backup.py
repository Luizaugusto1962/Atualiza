import re

with open(r'D:\Projetos\Atualiza\binarios\backup.sh', 'r') as f:
    content = f.read()

# Find the boundaries
old_completo_start = content.find('# Executa backup completo\n')
old_incremental_end = content.find('# Muda para o diretorio de trabalho\n')

if old_completo_start == -1 or old_incremental_end == -1:
    print(f'ERROR: start={old_completo_start}, end={old_incremental_end}')
    exit(1)

new_func = '''# Executa backup completo ou incremental
# Parametros: $1=arquivo_destino $2=modo ("completo" ou "incremental") $3=data_referencia (opcional)
# Retorna: 0 se sucesso, 1 se erro, 2 se nenhum arquivo encontrado (incremental)
_executar_backup() {
    local arquivo_destino="$1"
    local modo="$2"
    local data_referencia="${3:-}"
    local -a arquivos_para_zip=()
    local arquivo_atual

    # Validar parametro
    if [[ -z "$arquivo_destino" ]]; then
        _log_erro "Caminho do backup nao foi informado"
        return 1
    fi

    # Validar diretorio de trabalho
    if ! _diretorio_trabalho; then
        _erro "Falha ao acessar diretorio de trabalho"
        return 1
    fi

    # Listar arquivos
    if [[ "$modo" == "incremental" && -n "$data_referencia" ]]; then
        while IFS= read -r -d "" arquivo_atual; do
            arquivos_para_zip+=("$arquivo_atual")
        done < <(find . -type f -newermt "$data_referencia" \
             ! -name "*.zip" ! -name "*.tar" ! -name "*.gz" ! -name "*.log" ! -name "*.tmp" ! -name "*.old" \
             -print0)
    else
        while IFS= read -r -d "" arquivo_atual; do
            arquivos_para_zip+=("$arquivo_atual")
        done < <(find . -type f \
             ! -name "*.zip" ! -name "*.tar" ! -name "*.gz" ! -name "*.log" ! -name "*.tmp" ! -name "*.old" \
             -print0)
    fi

    if ((${#arquivos_para_zip[@]} == 0)); then
        if [[ "$modo" == "incremental" ]]; then
            _msg "Nenhum arquivo modificado desde $data_referencia"
            return 2
        fi
        _aviso "Nenhum arquivo encontrado para backup"
        return 1
    fi

    # Executar compactacao — ignorar erros de arquivo em uso (lock)
    local resultado_zip=0
    "$DEFAULT_ZIP" "$arquivo_destino" "${arquivos_para_zip[@]}" >>"${LOG_ATU:-/dev/null}" 2>&1 || resultado_zip=$?

    if [[ $resultado_zip -ne 0 ]]; then
        _aviso "zip retornou erro $resultado_zip (possivel arquivo em uso), tentando forcar..."
        "$DEFAULT_ZIP" -f "$arquivo_destino" "${arquivos_para_zip[@]}" >>"${LOG_ATU:-/dev/null}" 2>&1 || resultado_zip=$?
    fi

    if [[ $resultado_zip -ne 0 ]]; then
        _aviso "Falha parcial ao criar backup (alguns arquivos podem estar em uso): $arquivo_destino"
    fi

    # Definir permissao do arquivo backup
    chmod "$PERM_FILE_BACKUP" "$arquivo_destino" 2>/dev/null || true

    # Validar backup criado
    if ! _validar_backup_criado "$arquivo_destino"; then
        return 1
    fi

    # Validar integridade do zip
    if ! _validar_integridade_backup "$arquivo_destino"; then
        _erro "Backup corrompido (falhou no teste de integridade)"
        rm -f -- "$arquivo_destino"
        return 1
    fi

    _log_sucesso "Backup ${modo} criado: $arquivo_destino"
    return 0
}

'''

new_content = content[:old_completo_start] + new_func + content[old_incremental_end:]

with open(r'D:\Projetos\Atualiza\binarios\backup.sh', 'w') as f:
    f.write(new_content)

print('Done. Replaced functions.')
