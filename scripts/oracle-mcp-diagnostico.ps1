# ============================================================
# oracle-mcp-diagnostico.ps1
# Diagnóstico completo del sistema para Oracle MCP Server
# Versión: 1.0 | Oracle Cloud Infrastructure — Colombia & LATAM
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$pass  = "[OK]"
$fail  = "[FAIL]"
$warn  = "[WARN]"
$sep   = "=" * 60

Write-Host ""
Write-Host $sep -ForegroundColor Cyan
Write-Host "  ORACLE MCP SERVER — DIAGNÓSTICO DEL SISTEMA" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host ""

$resultados = @()

# ── 1. JAVA ──────────────────────────────────────────────────
Write-Host "[ 1/6 ] Verificando Java..." -ForegroundColor Yellow
$javaOut = & java -version 2>&1
if ($LASTEXITCODE -eq 0 -or $javaOut -match "version") {
    $version = ($javaOut | Select-String "version").ToString()
    $major = [int](($version -replace '.*"(\d+).*".*','$1'))
    if ($major -ge 17) {
        Write-Host "  $pass Java $major detectado" -ForegroundColor Green
        $resultados += @{ check="Java 17+"; estado="OK"; detalle=$version }
    } else {
        Write-Host "  $fail Java $major detectado — se requiere 17+" -ForegroundColor Red
        $resultados += @{ check="Java 17+"; estado="FAIL"; detalle="Versión $major instalada" }
    }
} else {
    Write-Host "  $fail Java no encontrado en PATH" -ForegroundColor Red
    $resultados += @{ check="Java 17+"; estado="FAIL"; detalle="No instalado o no en PATH" }
}

# ── 2. SQLcl ─────────────────────────────────────────────────
Write-Host "[ 2/6 ] Verificando SQLcl..." -ForegroundColor Yellow
$sqlclPaths = @(
    "C:\tools\sqlcl\bin\sql.exe",
    "$env:USERPROFILE\tools\sqlcl\bin\sql.exe",
    (Get-Command sql.exe -ErrorAction SilentlyContinue)?.Source
) | Where-Object { $_ -and (Test-Path $_) }

if ($sqlclPaths.Count -gt 0) {
    $sqlclExe = $sqlclPaths[0]
    $sqlclVer = & $sqlclExe -v 2>&1 | Select-String "Release"
    Write-Host "  $pass SQLcl encontrado: $sqlclExe" -ForegroundColor Green
    Write-Host "       $sqlclVer" -ForegroundColor Gray
    $resultados += @{ check="SQLcl 25.2+"; estado="OK"; detalle=$sqlclVer }
} else {
    Write-Host "  $fail SQLcl no encontrado" -ForegroundColor Red
    Write-Host "       Descarga: https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/" -ForegroundColor Gray
    $resultados += @{ check="SQLcl 25.2+"; estado="FAIL"; detalle="No instalado" }
}

# ── 3. CLAUDE DESKTOP ────────────────────────────────────────
Write-Host "[ 3/6 ] Verificando Claude Desktop..." -ForegroundColor Yellow
$claudeConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path $claudeConfig) {
    $configContent = Get-Content $claudeConfig | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($configContent.mcpServers) {
        $servers = $configContent.mcpServers.PSObject.Properties.Name -join ", "
        Write-Host "  $pass Configuración encontrada — Servidores: $servers" -ForegroundColor Green
        $resultados += @{ check="Claude Desktop Config"; estado="OK"; detalle="Servidores: $servers" }
    } else {
        Write-Host "  $warn Archivo existe pero sin mcpServers configurados" -ForegroundColor Yellow
        $resultados += @{ check="Claude Desktop Config"; estado="WARN"; detalle="Sin mcpServers" }
    }
} else {
    Write-Host "  $fail No se encontró $claudeConfig" -ForegroundColor Red
    Write-Host "       Copia config\claude_desktop_config.json a esa ruta" -ForegroundColor Gray
    $resultados += @{ check="Claude Desktop Config"; estado="FAIL"; detalle="Archivo no existe" }
}

# ── 4. WALLET / TNS_ADMIN ────────────────────────────────────
Write-Host "[ 4/6 ] Verificando wallets y TNS_ADMIN..." -ForegroundColor Yellow
$tnsAdmin = $env:TNS_ADMIN
if ($tnsAdmin -and (Test-Path $tnsAdmin)) {
    $tnsnames = Test-Path "$tnsAdmin\tnsnames.ora"
    $wallet   = Test-Path "$tnsAdmin\cwallet.sso"
    if ($tnsnames) {
        Write-Host "  $pass TNS_ADMIN configurado: $tnsAdmin" -ForegroundColor Green
        Write-Host "  $pass tnsnames.ora encontrado" -ForegroundColor Green
    } else {
        Write-Host "  $warn TNS_ADMIN existe pero falta tnsnames.ora" -ForegroundColor Yellow
    }
    if ($wallet) {
        Write-Host "  $pass cwallet.sso encontrado (ADB wallet)" -ForegroundColor Green
    }
    $resultados += @{ check="TNS_ADMIN / Wallet"; estado="OK"; detalle=$tnsAdmin }
} else {
    Write-Host "  $warn TNS_ADMIN no configurado como variable de entorno" -ForegroundColor Yellow
    Write-Host "       Para ADB: configúralo en Variables de Entorno del Sistema" -ForegroundColor Gray
    $resultados += @{ check="TNS_ADMIN / Wallet"; estado="WARN"; detalle="Variable no configurada" }
}

# ── 5. CONEXIONES GUARDADAS ──────────────────────────────────
Write-Host "[ 5/6 ] Verificando conexiones guardadas SQLcl..." -ForegroundColor Yellow
$connectionsFile = "$env:USERPROFILE\.sqlcl\connections.json"
if (Test-Path $connectionsFile) {
    $conns = Get-Content $connectionsFile | ConvertFrom-Json -ErrorAction SilentlyContinue
    $count = if ($conns) { @($conns).Count } else { 0 }
    Write-Host "  $pass Conexiones guardadas: $count" -ForegroundColor Green
    $resultados += @{ check="Conexiones guardadas"; estado="OK"; detalle="$count conexión(es)" }
} else {
    Write-Host "  $fail No hay conexiones guardadas en SQLcl" -ForegroundColor Red
    Write-Host "       Ejecuta: .\oracle-mcp-configurar-conexiones.ps1" -ForegroundColor Gray
    $resultados += @{ check="Conexiones guardadas"; estado="FAIL"; detalle="Archivo no existe" }
}

# ── 6. INICIO MCP SERVER ─────────────────────────────────────
Write-Host "[ 6/6 ] Verificando inicio del MCP Server..." -ForegroundColor Yellow
if ($sqlclPaths.Count -gt 0) {
    $job = Start-Job -ScriptBlock {
        param($exe)
        & $exe -mcp 2>&1
    } -ArgumentList $sqlclPaths[0]
    Start-Sleep -Seconds 3
    $output = Receive-Job -Job $job 2>&1
    Stop-Job -Job $job
    Remove-Job -Job $job -Force

    if ($output -match "MCP" -or $output -match "Listening" -or $output -notmatch "Error") {
        Write-Host "  $pass MCP Server inicia correctamente" -ForegroundColor Green
        $resultados += @{ check="MCP Server startup"; estado="OK"; detalle="Inicia sin errores" }
    } else {
        Write-Host "  $warn No se pudo confirmar inicio limpio — revisa manualmente" -ForegroundColor Yellow
        Write-Host "       Ejecuta: sql.exe -mcp" -ForegroundColor Gray
        $resultados += @{ check="MCP Server startup"; estado="WARN"; detalle="Verificar manualmente" }
    }
} else {
    Write-Host "  $fail No se puede probar — SQLcl no encontrado" -ForegroundColor Red
    $resultados += @{ check="MCP Server startup"; estado="FAIL"; detalle="SQLcl no disponible" }
}

# ── RESUMEN ──────────────────────────────────────────────────
Write-Host ""
Write-Host $sep -ForegroundColor Cyan
Write-Host "  RESUMEN DEL DIAGNÓSTICO" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
foreach ($r in $resultados) {
    $color = switch ($r.estado) {
        "OK"   { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }
    Write-Host ("  [{0,-4}] {1,-30} {2}" -f $r.estado, $r.check, $r.detalle) -ForegroundColor $color
}
$ok   = ($resultados | Where-Object { $_.estado -eq "OK" }).Count
$fail = ($resultados | Where-Object { $_.estado -eq "FAIL" }).Count
$warn = ($resultados | Where-Object { $_.estado -eq "WARN" }).Count
Write-Host ""
Write-Host "  Resultado: $ok OK  |  $warn ADVERTENCIAS  |  $fail ERRORES" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host ""

if ($fail -eq 0) {
    Write-Host "  Sistema listo para usar Oracle MCP Server." -ForegroundColor Green
} else {
    Write-Host "  Corrige los errores antes de continuar." -ForegroundColor Red
    Write-Host "  Consulta docs\guia-implementacion.md para más detalles." -ForegroundColor Gray
}
Write-Host ""
