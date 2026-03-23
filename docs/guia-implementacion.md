# Guía de Implementación — Oracle MCP Server

**Versión:** 1.0 | **Fecha:** Marzo 2026 | **Audiencia:** Cloud Architects, DBAs, DevOps Engineers

---

## Tabla de contenidos

1. [Contexto y casos de uso](#1-contexto-y-casos-de-uso)
2. [Prerrequisitos](#2-prerrequisitos)
3. [Escenarios de conectividad](#3-escenarios-de-conectividad)
4. [Instalación de SQLcl](#4-instalación-de-sqlcl)
5. [Crear usuario MCP en Oracle](#5-crear-usuario-mcp-en-oracle)
6. [Configurar conexiones guardadas](#6-configurar-conexiones-guardadas)
7. [Configurar Claude Desktop](#7-configurar-claude-desktop)
8. [Validar la implementación](#8-validar-la-implementación)
9. [Auditoría y seguridad](#9-auditoría-y-seguridad)
10. [Troubleshooting](#10-troubleshooting)
11. [Hoja de ruta](#11-hoja-de-ruta)

---

## 1. Contexto y casos de uso

El **Oracle MCP Server** (Model Context Protocol) está disponible desde **SQLcl 25.2** y permite conectar Oracle Database directamente con clientes de IA como Claude Desktop o VS Code.

### Problema que resuelve

| Problema | Sin MCP | Con MCP |
|----------|---------|---------|
| Consultas ad-hoc | Requiere DBA o conocimiento SQL | Lenguaje natural |
| Tiempo de respuesta | Horas (ticket al DBA) | Segundos |
| Acceso a datos operativos | Restringido a perfiles técnicos | Cualquier usuario autorizado |
| Auditoría de consultas | Manual o inexistente | Automática en `DBTOOLS$MCP_LOG` |
| Análisis de datos | Exportar a Excel, analizar manualmente | Análisis directo con IA |

### Casos de uso típicos

- *"¿Cuántas facturas vencidas hay por cliente en los últimos 30 días?"*
- *"Muéstrame los 10 productos con mayor rotación este mes"*
- *"¿Qué usuarios han tenido más de 3 intentos fallidos de login hoy?"*
- *"Compara las ventas de este trimestre vs el anterior por región"*

---

## 2. Prerrequisitos

### Software requerido

| Componente | Versión mínima | Descarga |
|-----------|---------------|---------|
| Java JDK | 17 LTS | [oracle.com/java](https://www.oracle.com/java/technologies/downloads/) |
| SQLcl | 25.2.0+ | [oracle.com/sqldeveloper/sqlcl](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/) |
| Claude Desktop | Última versión | [claude.ai/download](https://claude.ai/download) |
| Node.js | 18+ (para MCP filesystem) | [nodejs.org](https://nodejs.org) |

### Infraestructura requerida

- Oracle Database **19c o superior** (DBCS, ExaCS, ADB o on-premise)
- Conectividad de red resuelta entre el equipo local y la base de datos
- Usuario Oracle con privilegios mínimos (ver sección 5)

### Verificaciones previas

```powershell
# Verificar Java
java -version
# Debe mostrar: openjdk version "17..." o superior

# Verificar conectividad a la BD (puerto 1521)
Test-NetConnection -ComputerName TU_HOST_BD -Port 1521
# TcpTestSucceeded: True

# Ejecutar diagnóstico completo
.\scripts\oracle-mcp-diagnostico.ps1
```

---

## 3. Escenarios de conectividad

### Escenario A — Red corporativa con FastConnect (más común en empresas)

```
PC Local ──── Red Corporativa ──── FastConnect ──── OCI VCN ──── DBCS
```

No requiere configuración adicional si el equipo ya tiene acceso a la red interna. Verificar con `Test-NetConnection`.

### Escenario B — Acceso desde casa con VPN SSL

```
PC Casa ──── VPN SSL (Cisco/GlobalProtect/etc.) ──── Red Corporativa ──── OCI
```

1. Conectarse a la VPN corporativa primero
2. Verificar conectividad: `Test-NetConnection -ComputerName HOST_BD -Port 1521`
3. Proceder con la instalación normalmente

### Escenario C — Autonomous Database (ADB) con wallet

```
PC Local ──── Internet/VPN ──── OCI ADB (mTLS con wallet)
```

Requiere descargar el wallet desde OCI Console:
1. OCI Console → Autonomous Database → tu instancia
2. **DB Connection** → **Download Wallet**
3. Descomprimir en: `C:\oracle\wallets\nombre_adb\`
4. Verificar que existan: `tnsnames.ora`, `cwallet.sso`, `sqlnet.ora`
5. Editar `sqlnet.ora` — actualizar `DIRECTORY` a la ruta absoluta:

```
WALLET_LOCATION = (SOURCE = (METHOD = file)
  (METHOD_DATA = (DIRECTORY="C:\oracle\wallets\nombre_adb")))
SSL_SERVER_DN_MATCH=yes
```

---

## 4. Instalación de SQLcl

### Windows

```powershell
# 1. Descargar SQLcl 25.2+ desde:
# https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/

# 2. Descomprimir en C:\tools\sqlcl
# Resultado esperado: C:\tools\sqlcl\bin\sql.exe

# 3. Verificar instalación
C:\tools\sqlcl\bin\sql.exe -v
# Debe mostrar: SQLcl: Release 25.2.x ...

# 4. (Opcional) Agregar al PATH del sistema
$env:PATH += ";C:\tools\sqlcl\bin"
```

### Verificación de versión mínima

```powershell
$version = (C:\tools\sqlcl\bin\sql.exe -v 2>&1) -join ""
if ($version -match "25\.[2-9]|2[6-9]\.|[3-9]\d\.") {
    Write-Host "SQLcl versión OK" -ForegroundColor Green
} else {
    Write-Host "Actualizar SQLcl a 25.2+" -ForegroundColor Red
}
```

---

## 5. Crear usuario MCP en Oracle

Ejecutar como SYSDBA o usuario con privilegio `CREATE USER`:

```sql
-- Ver: sql/crear_usuario_mcp.sql

-- Crear usuario
CREATE USER mcp_user IDENTIFIED BY "TuContraseña_Segura#2025"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA 0 ON users;

-- Privilegios mínimos
GRANT CREATE SESSION TO mcp_user;

-- Acceso de lectura a los schemas necesarios (ajustar según caso)
GRANT SELECT ON nombre_schema.nombre_tabla TO mcp_user;

-- Acceso a auditoría MCP
GRANT SELECT, INSERT ON DBTOOLS.DBTOOLS$MCP_LOG TO mcp_user;
```

> **Principio de menor privilegio:** el usuario MCP **no** debe tener rol DBA, `GRANT ANY TABLE`, ni acceso a vistas `DBA_*`. Solo debe ver los datos que el negocio requiere consultar.

---

## 6. Configurar conexiones guardadas

Las conexiones guardadas en SQLcl son la forma segura de almacenar credenciales — nunca en texto plano en el archivo de configuración.

### Opción A — Script automático (recomendado)

```powershell
.\scripts\oracle-mcp-configurar-conexiones.ps1
```

### Opción B — Manual en SQLcl

```sql
-- Para DBCS / on-premise (EZConnect)
SQL> CONN -save mi_conexion -savepwd mcp_user/MiPassword@//host:1521/ORCLPDB1

-- Para Autonomous Database (con wallet)
SQL> SET CLOUDCONFIG C:\oracle\wallets\mi_adb
SQL> CONN -save mi_adb_demo -savepwd admin/MiPassword@mi_adb_high

-- Verificar conexiones guardadas
SQL> SHOW CONNECTIONS
```

Las credenciales se almacenan de forma cifrada en: `%USERPROFILE%\.sqlcl\connections.json`

---

## 7. Configurar Claude Desktop

### Ubicación del archivo de configuración

```
%APPDATA%\Claude\claude_desktop_config.json
```

### Template de configuración

Copiar desde `config/claude_desktop_config.json` y ajustar las rutas:

```json
{
  "mcpServers": {
    "oracle-dbcs": {
      "command": "C:\\tools\\sqlcl\\bin\\sql.exe",
      "args": ["-mcp"],
      "env": {
        "TNS_ADMIN": "C:\\oracle\\network\\admin"
      }
    }
  }
}
```

> **Importante:** nunca incluir usuario/contraseña en este archivo. Las credenciales van en el Connection Store de SQLcl (paso anterior).

### Reiniciar Claude Desktop

Cerrar completamente Claude Desktop (verificar en el Task Manager que no haya procesos activos) y volver a abrir. Los servidores MCP aparecerán en el panel lateral.

---

## 8. Validar la implementación

### Diagnóstico completo

```powershell
.\scripts\oracle-mcp-diagnostico.ps1
```

Todos los checks deben mostrar `[OK]`.

### Suite de pruebas

```powershell
.\scripts\oracle-mcp-pruebas.ps1
```

### Prueba funcional en Claude Desktop

Con Claude Desktop abierto y el servidor MCP activo, probar con preguntas en lenguaje natural:

- *"Lista las tablas disponibles en el schema de ventas"*
- *"¿Cuántos registros tiene la tabla de clientes?"*
- *"Muéstrame las últimas 5 transacciones"*

---

## 9. Auditoría y seguridad

### Consultar el log de auditoría

```sql
-- Ver: sql/validar_mcp_log.sql

-- Últimas consultas ejecutadas vía MCP
SELECT
    TO_CHAR(log_time, 'DD/MM/YYYY HH24:MI:SS') AS fecha_hora,
    db_user,
    SUBSTR(sql_text, 1, 100) AS sql_ejecutado,
    status
FROM DBTOOLS.DBTOOLS$MCP_LOG
ORDER BY log_time DESC
FETCH FIRST 20 ROWS ONLY;
```

### Buenas prácticas

- Rotar la contraseña del usuario MCP cada 90 días
- Revisar `DBTOOLS$MCP_LOG` semanalmente en producción
- No compartir el `connections.json` entre equipos
- Usar nombres de conexión distintos por ambiente (dev/qa/prod)
- Activar Unified Auditing en Oracle para mayor trazabilidad

---

## 10. Troubleshooting

| Error | Causa probable | Solución |
|-------|---------------|---------|
| `Server disconnected` en Claude | SQLcl no inicia o ruta incorrecta | Verificar ruta en config, ejecutar `sql.exe -mcp` manualmente |
| `HTTP 403` al intentar conexión | Credenciales incorrectas o usuario bloqueado | Verificar usuario con `SELECT account_status FROM dba_users WHERE username='MCP_USER'` |
| `TNS:could not resolve service name` | `tnsnames.ora` mal configurado o `TNS_ADMIN` incorrecto | Verificar variable `TNS_ADMIN` y contenido de `tnsnames.ora` |
| `ORA-01017: invalid username/password` | Contraseña incorrecta en Connection Store | Recrear la conexión guardada con `CONN -save` |
| `ORA-00942: table or view does not exist` | Usuario MCP sin grants suficientes | Ejecutar `sql/grant_permisos.sql` |
| Wallet error / SSL handshake | `sqlnet.ora` con ruta de wallet desactualizada | Editar `DIRECTORY` en `sqlnet.ora` con ruta absoluta correcta |
| `java.lang.UnsupportedClassVersionError` | Java menor a 17 | Instalar Java 17+ y actualizar JAVA_HOME |
| MCP server no aparece en Claude | Claude Desktop no reiniciado | Cerrar completamente desde Task Manager y reabrir |
| `NullPointerException` al iniciar | Versión SQLcl < 25.2 | Actualizar a SQLcl 25.2+ |
| Consultas lentas o timeout | Query compleja o falta de índices | Revisar plan de ejecución, considerar vistas materializadas |

---

## 11. Hoja de ruta

Este kit cubre la implementación base. Los siguientes pasos naturales son:

| Fase | Capacidad | Tecnología |
|------|-----------|-----------|
| Fase 1 (actual) | NL → SQL sobre Oracle Database | SQLcl MCP + Claude Desktop |
| Fase 2 | Respuestas con contexto de negocio | Oracle Select AI + ADB |
| Fase 3 | Agentes autónomos sobre datos | Oracle 26ai + LangChain + OKE |
| Fase 4 | Interfaces de usuario integradas | APEX GenAI + Oracle 26ai |

---

*Documento elaborado por el equipo de Oracle Cloud Architecture — Colombia & LATAM*
*Para comentarios o mejoras: abrir un Issue en este repositorio*
