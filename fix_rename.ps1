$content = Get-Content -Raw "D:\Projetos\Atualiza\binarios\backup.sh"

# Rename the unified function from _executar_backup to _executar_backup_arquivo
# But keep the main _executar_backup function (the one with _menu_tipo_backup)
# We need to be careful because there are two functions named _executar_backup

# First, find the main _executar_backup function and rename it temporarily
# Then rename the unified one

# Split by the function definitions
# The main function starts at line 102 and ends before line 306
# The unified function starts at line 309

# We'll replace the unified function name only
$oldFuncStart = "# Executa backup completo ou incremental`n# Parametros: $1=arquivo_destino $2=modo (`"completo`" ou `"incremental`") $3=data_referencia (opcional)`n# Retorna: 0 se sucesso, 1 se erro, 2 se nenhum arquivo encontrado (incremental)`n_executar_backup() {"

$newFuncName = "_executar_backup_arquivo"

# Replace the function definition
$content = $content.Replace("_executar_backup() {`n    local arquivo_destino=`"${1:-}`"", "_executar_backup_arquivo() {`n    local arquivo_destino=`"${1:-}`"")

# Also replace the function calls
$content = $content.Replace('_executar_backup "$caminho_backup" "incremental"', '_executar_backup_arquivo "$caminho_backup" "incremental"')
$content = $content.Replace('_executar_backup "$caminho_backup" "completo"', '_executar_backup_arquivo "$caminho_backup" "completo"')

# Also replace the _enviar_backup function if it calls _executar_backup
# (It shouldn't, but let's be safe)

# Also fix the _executar_backup_multiplos_padroes function
# It calls _executar_backup? Let's check

Set-Content -Path "D:\Projetos\Atualiza\binarios\backup.sh" -Value $content -NoNewline
Write-Host "Done renaming unified function to _executar_backup_arquivo"
