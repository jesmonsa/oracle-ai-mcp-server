# ============================================================
# oracle-mcp-configurar-conexiones.ps1
# Wizard interactivo para configurar conexiones SQLcl guardadas
# Versión: 1.0 | Oracle Cloud Infrastructure — Colombia & LATAM
# ============================================================

$sep = "=" * 60

Write-Host ""
Write-Host $sep -ForegroundColor Cyan
Write-Host "  ORACLE MCP SERVER — CONFIGURAR CONEXIONES" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host ""
Write-Host "  Este wizard guía la creación de conexiones guardadas" -ForegroundColor Gray
Write-Host "  en SQLcl, necesarias para que el MCP Server funcione." -ForegroundColor Gray
Write-Host ""

# ── Buscar SQLcl ─────────────────────────────────────────────
$sqlclPaths = @(
    "C:\tools\sqlcl\bin\sql.exe",
    "$env:USERPROFILE\tools\sqlcl\bin\sql.exe"
) | Where-Object { Test-Path $_ }

if ($sqlclPaths.Count -eq 0) {
    $custom = Read-Host "  SQLcl no encontrado en rutas predeterminadas. Ingresa la ruta completa a sql.exe"
    if (Test-Path $custom) { $sqlclPaths = @($custom) }
    else {
        Write-Host "  [FAIL] Ruta no válida. Instala SQLcl 25.2+ y vuelve a ejecutar." -ForegroundColor Red
        exit 1
    }
}
$sqlclExe = $sqlclPaths[0]
Write-Host "  [OK] SQLcl encontrado: $sqlclExe" -ForegroundColor Green
Write-Host ""

# ── Tipo de base de datos ─────────────────────────────────────
Write-Host "  Tipo de base de datos a conectar:" -ForegroundColor Yellow
Write-Host "    [1] Oracle Autonomous Database (ADB) — con wallet"
Write-Host "    [2] Oracle DBCS / on-premise — EZConnect o TNS"
Write-Host ""
$tipo = Read-Host "  Selecciona una opción (1 o 2)"

Write-Host ""

if ($tipo -eq "1") {
    # ── ADB CON WALLET ────────────────────────────────────────
    Write-Host "  Configuración para Autonomous Database" -ForegroundColor Cyan
    Write-Host ""

    $nombreConexion = Read-Host "  Nombre para guardar la conexión (ej: adb_demo)"
    $usuario        = Read-Host "  Usuario de base de datos (ej: admin)"
    $password       = Read-Host "  Contraseña" -AsSecureString
    $pwdPlain       = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                          [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    $servicioTns    = Read-Host "  Nombre de servicio TNS (ej: adbdemo_high)"
    $walletPath     = Read-Host "  Ruta del wallet (ej: C:\oracle\wallets\adb_demo)"

    if (-not (Test-Path $walletPath)) {
        Write-Host "  [WARN] La ruta del wallet no existe: $walletPath" -ForegroundColor Yellow
        Write-Host "         Descarga el wallet desde OCI Console → ADB → DB Connection" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "  Creando conexión guardada '$nombreConexion'..." -ForegroundColor Yellow

    $sqlScript = @"
SET CLOUDCONFIG $walletPath
CONN -save $nombreConexion -savepwd ${usuario}/${pwdPlain}@${servicioTns}
SHOW CONNECTIONS
EXIT
"@
    $tmpFile = "$env:TEMP\mcp_setup_$((Get-Date).Ticks).sql"
    $sqlScript | Out-File -FilePath $tmpFile -Encoding UTF8

    $env:TNS_ADMIN = $walletPath
    & $sqlclExe /NOLOG "@$tmpFile" 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Remove-Item $tmpFile -Force

} elseif ($tipo -eq "2") {
    # ── DBCS / ON-PREMISE ─────────────────────────────────────
    Write-Host "  Configuración para DBCS / On-Premise" -ForegroundColor Cyan
    Write-Host ""

    $nombreConexion = Read-Host "  Nombre para guardar la conexión (ej: dbcs_prod)"
    $usuario        = Read-Host "  Usuario de base de datos (ej: mcp_user)"
    $password       = Read-Host "  Contraseña" -AsSecureString
    $pwdPlain       = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                          [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

    Write-Host ""
    Write-Host "  Formato de conexión:" -ForegroundColor Yellow
    Write-Host "    [1] EZConnect — //host:puerto/servicio"
    Write-Host "    [2] TNS alias — nombre en tnsnames.ora"
    $formatoConn = Read-Host "  Selecciona (1 o 2)"

    if ($formatoConn -eq "1") {
        $host_db  = Read-Host "  Host o IP de la base de datos"
        $puerto   = Read-Host "  Puerto (default 1521)"
        if (-not $puerto) { $puerto = "1521" }
        $servicio = Read-Host "  Nombre de servicio (ej: ORCLPDB1)"
        $connStr  = "//${host_db}:${puerto}/${servicio}"
    } else {
        $connStr = Read-Host "  TNS alias (debe existir en tnsnames.ora)"
    }

    Write-Host ""
    Write-Host "  Creando conexión guardada '$nombreConexion'..." -ForegroundColor Yellow

    $sqlScript = @"
CONN -save $nombreConexion -savepwd ${usuario}/${pwdPlain}@${connStr}
SHOW CONNECTIONS
EXIT
"@
    $tmpFile = "$env:TEMP\mcp_setup_$((Get-Date).Ticks).sql"
    $sqlScript | Out-File -FilePath $tmpFile -Encoding UTF8

    & $sqlclExe /NOLOG "@$tmpFile" 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Remove-Item $tmpFile -Force

} else {
    Write-Host "  [FAIL] Opción no válida." -ForegroundColor Red
    exit 1
}

# ── Verificación final ────────────────────────────────────────
Write-Host ""
Write-Host $sep -ForegroundColor Cyan
Write-Host "  Verificando conexiones guardadas..." -ForegroundColor Yellow
$connectionsFile = "$env:USERPROFILE\.sqlcl\connections.json"
if (Test-Path $connectionsFile) {
    Write-Host "  [OK] Conexiones guardadas correctamente en:" -ForegroundColor Green
    Write-Host "       $connectionsFile" -ForegroundColor Gray
} else {
    Write-Host "  [WARN] No se pudo confirmar el archivo de conexiones." -ForegroundColor Yellow
    Write-Host "         Ejecuta: sql /NOLOG y luego: show connections" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Siguiente paso: ejecuta oracle-mcp-pruebas.ps1" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host ""
