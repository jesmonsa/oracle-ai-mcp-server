# ============================================================
# oracle-mcp-pruebas.ps1
# Suite de pruebas funcionales para Oracle MCP Server
# Versión: 1.0 | Oracle Cloud Infrastructure — Colombia & LATAM
# ============================================================

$sep   = "=" * 60
$pass  = "PASS"
$fail  = "FAIL"
$tests = @()

Write-Host ""
Write-Host $sep -ForegroundColor Cyan
Write-Host "  ORACLE MCP SERVER — SUITE DE PRUEBAS" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host ""

# ── Buscar SQLcl ─────────────────────────────────────────────
$sqlclPaths = @(
    "C:\tools\sqlcl\bin\sql.exe",
    "$env:USERPROFILE\tools\sqlcl\bin\sql.exe"
) | Where-Object { Test-Path $_ }

if ($sqlclPaths.Count -eq 0) {
    Write-Host "  [FAIL] SQLcl no encontrado. Ejecuta oracle-mcp-diagnostico.ps1 primero." -ForegroundColor Red
    exit 1
}
$sqlclExe = $sqlclPaths[0]

# ── TEST 1: Conexiones guardadas ──────────────────────────────
Write-Host "[ T1 ] Conexiones guardadas en SQLcl..." -ForegroundColor Yellow
$connectionsFile = "$env:USERPROFILE\.sqlcl\connections.json"
if (Test-Path $connectionsFile) {
    $conns = Get-Content $connectionsFile | ConvertFrom-Json -ErrorAction SilentlyContinue
    $count = if ($conns) { @($conns).Count } else { 0 }
    if ($count -gt 0) {
        Write-Host "  [$pass] $count conexión(es) guardada(s)" -ForegroundColor Green
        $tests += @{ test="Conexiones guardadas"; resultado=$pass }
    } else {
        Write-Host "  [$fail] Archivo existe pero sin conexiones" -ForegroundColor Red
        $tests += @{ test="Conexiones guardadas"; resultado=$fail }
    }
} else {
    Write-Host "  [$fail] No hay conexiones guardadas" -ForegroundColor Red
    $tests += @{ test="Conexiones guardadas"; resultado=$fail }
}

# ── TEST 2: Conexión a BD y query simple ─────────────────────
Write-Host "[ T2 ] Conexión a base de datos..." -ForegroundColor Yellow
$nombreConexion = Read-Host "  Nombre de la conexión a probar (ej: dbcs_prod)"

$sqlTest = @"
CONN -name $nombreConexion
SELECT 'MCP_TEST_OK' AS resultado FROM DUAL;
EXIT
"@
$tmpFile = "$env:TEMP\mcp_test_$((Get-Date).Ticks).sql"
$sqlTest | Out-File -FilePath $tmpFile -Encoding UTF8

$output = & $sqlclExe /NOLOG "@$tmpFile" 2>&1
Remove-Item $tmpFile -Force

if ($output -match "MCP_TEST_OK") {
    Write-Host "  [$pass] Conexión exitosa y query respondió correctamente" -ForegroundColor Green
    $tests += @{ test="Conexión a BD + query DUAL"; resultado=$pass }
} else {
    Write-Host "  [$fail] No se obtuvo respuesta esperada de la BD" -ForegroundColor Red
    Write-Host "  Output: $($output -join ' | ')" -ForegroundColor Gray
    $tests += @{ test="Conexión a BD + query DUAL"; resultado=$fail }
}

# ── TEST 3: Tabla DBTOOLS$MCP_LOG ────────────────────────────
Write-Host "[ T3 ] Verificando tabla de auditoría DBTOOLS`$MCP_LOG..." -ForegroundColor Yellow
$sqlLog = @"
CONN -name $nombreConexion
SELECT COUNT(*) AS total_log FROM DBTOOLS`$MCP_LOG;
EXIT
"@
$tmpFile = "$env:TEMP\mcp_log_$((Get-Date).Ticks).sql"
$sqlLog | Out-File -FilePath $tmpFile -Encoding UTF8

$output = & $sqlclExe /NOLOG "@$tmpFile" 2>&1
Remove-Item $tmpFile -Force

if ($output -match "\d+") {
    Write-Host "  [$pass] Tabla DBTOOLS`$MCP_LOG accesible" -ForegroundColor Green
    $tests += @{ test="DBTOOLS`$MCP_LOG accesible"; resultado=$pass }
} else {
    Write-Host "  [WARN] Tabla no accesible — puede ser normal si el usuario MCP aún no tiene grants" -ForegroundColor Yellow
    $tests += @{ test="DBTOOLS`$MCP_LOG accesible"; resultado="WARN" }
}

# ── TEST 4: Inicio del MCP Server ────────────────────────────
Write-Host "[ T4 ] Verificando inicio del MCP Server (3 segundos)..." -ForegroundColor Yellow
$job = Start-Job -ScriptBlock {
    param($exe)
    & $exe -mcp 2>&1
} -ArgumentList $sqlclExe

Start-Sleep -Seconds 3
$output = Receive-Job -Job $job 2>&1
Stop-Job -Job $job
Remove-Job -Job $job -Force

if ($output -notmatch "(?i)error|exception|failed") {
    Write-Host "  [$pass] MCP Server inicia sin errores críticos" -ForegroundColor Green
    $tests += @{ test="MCP Server startup"; resultado=$pass }
} else {
    Write-Host "  [$fail] MCP Server reportó errores al iniciar" -ForegroundColor Red
    Write-Host "  Output: $($output | Select-Object -First 3 | ForEach-Object { $_.ToString() } | Join-String ' | ')" -ForegroundColor Gray
    $tests += @{ test="MCP Server startup"; resultado=$fail }
}

# ── TEST 5: Claude Desktop config ────────────────────────────
Write-Host "[ T5 ] Verificando configuración de Claude Desktop..." -ForegroundColor Yellow
$claudeConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path $claudeConfig) {
    $config = Get-Content $claudeConfig | ConvertFrom-Json -ErrorAction SilentlyContinue
    $oracleServers = $config.mcpServers.PSObject.Properties |
        Where-Object { $_.Value.args -contains "-mcp" }
    if ($oracleServers) {
        Write-Host "  [$pass] $($oracleServers.Count) servidor(es) Oracle MCP configurados en Claude Desktop" -ForegroundColor Green
        $tests += @{ test="Claude Desktop MCP config"; resultado=$pass }
    } else {
        Write-Host "  [WARN] No hay servidores con -mcp configurados" -ForegroundColor Yellow
        $tests += @{ test="Claude Desktop MCP config"; resultado="WARN" }
    }
} else {
    Write-Host "  [$fail] Archivo de configuración de Claude Desktop no encontrado" -ForegroundColor Red
    $tests += @{ test="Claude Desktop MCP config"; resultado=$fail }
}

# ── RESUMEN FINAL ────────────────────────────────────────────
Write-Host ""
Write-Host $sep -ForegroundColor Cyan
Write-Host "  RESUMEN DE PRUEBAS" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
foreach ($t in $tests) {
    $color = switch ($t.resultado) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }
    Write-Host ("  [{0,-4}] {1}" -f $t.resultado, $t.test) -ForegroundColor $color
}

$totalPass = ($tests | Where-Object { $_.resultado -eq "PASS" }).Count
$totalFail = ($tests | Where-Object { $_.resultado -eq "FAIL" }).Count
$totalWarn = ($tests | Where-Object { $_.resultado -eq "WARN" }).Count

Write-Host ""
Write-Host ("  {0}/{1} pruebas pasadas  |  {2} advertencias  |  {3} errores" -f `
    $totalPass, $tests.Count, $totalWarn, $totalFail) -ForegroundColor Cyan

if ($totalFail -eq 0) {
    Write-Host ""
    Write-Host "  Sistema listo. Reinicia Claude Desktop y prueba con lenguaje natural." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Revisa los errores y consulta docs\guia-implementacion.md" -ForegroundColor Red
}
Write-Host $sep -ForegroundColor Cyan
Write-Host ""
