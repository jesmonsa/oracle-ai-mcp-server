-- ============================================================
-- crear_usuario_mcp.sql
-- Crea el usuario MCP con principio de menor privilegio
-- Ejecutar como SYSDBA o usuario con privilegio CREATE USER
-- Oracle Cloud Infrastructure — Colombia & LATAM
-- ============================================================

-- PASO 1: Crear el usuario (ajustar contraseña)
CREATE USER mcp_user IDENTIFIED BY "MCP_Passw0rd#2025"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA 0 ON users;

-- PASO 2: Privilegios mínimos de sesión
GRANT CREATE SESSION TO mcp_user;

-- PASO 3: Acceso de solo lectura a los schemas necesarios
-- Reemplaza SCHEMA_NOMBRE por los schemas reales del cliente
-- Ejemplos:
--   GRANT SELECT ON ventas.facturas TO mcp_user;
--   GRANT SELECT ON hr.empleados TO mcp_user;

-- PASO 4: Acceso a la tabla de auditoría MCP
GRANT SELECT, INSERT ON DBTOOLS.DBTOOLS$MCP_LOG TO mcp_user;

-- PASO 5: (Opcional) Vistas útiles de rendimiento — solo si se necesitan
-- GRANT SELECT ON V_$SESSION TO mcp_user;

-- Verificación
SELECT username, account_status, default_tablespace
FROM dba_users
WHERE username = 'MCP_USER';

-- ============================================================
-- NOTAS DE SEGURIDAD:
-- - NO otorgar DBA, SYSDBA ni roles con privilegios altos
-- - NO dar GRANT ANY TABLE ni CREATE TABLE
-- - Revisar y ajustar los schemas según necesidad real
-- - Cambiar la contraseña antes de usar en producción
-- ============================================================
