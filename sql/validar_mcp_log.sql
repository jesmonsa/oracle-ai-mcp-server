-- ============================================================
-- validar_mcp_log.sql
-- Consultas de auditoría sobre DBTOOLS$MCP_LOG
-- Ejecutar como mcp_user o DBA
-- Oracle Cloud Infrastructure — Colombia & LATAM
-- ============================================================

-- 1. Total de consultas registradas
SELECT COUNT(*) AS total_consultas
FROM DBTOOLS.DBTOOLS$MCP_LOG;

-- 2. Últimas 20 consultas ejecutadas
SELECT
    TO_CHAR(log_time, 'DD/MM/YYYY HH24:MI:SS') AS fecha_hora,
    db_user                                      AS usuario,
    SUBSTR(sql_text, 1, 100)                     AS sql_ejecutado,
    elapsed_ms                                   AS tiempo_ms,
    status
FROM DBTOOLS.DBTOOLS$MCP_LOG
ORDER BY log_time DESC
FETCH FIRST 20 ROWS ONLY;

-- 3. Consultas agrupadas por usuario
SELECT
    db_user       AS usuario,
    COUNT(*)      AS total_consultas,
    AVG(elapsed_ms) AS tiempo_promedio_ms,
    MAX(log_time) AS ultima_consulta
FROM DBTOOLS.DBTOOLS$MCP_LOG
GROUP BY db_user
ORDER BY total_consultas DESC;

-- 4. Consultas con errores
SELECT
    TO_CHAR(log_time, 'DD/MM/YYYY HH24:MI:SS') AS fecha_hora,
    db_user                                      AS usuario,
    SUBSTR(sql_text, 1, 200)                     AS sql_ejecutado,
    error_message
FROM DBTOOLS.DBTOOLS$MCP_LOG
WHERE status = 'ERROR'
ORDER BY log_time DESC;

-- 5. Actividad por hora (últimas 24 horas)
SELECT
    TO_CHAR(log_time, 'HH24') AS hora,
    COUNT(*)                   AS consultas
FROM DBTOOLS.DBTOOLS$MCP_LOG
WHERE log_time >= SYSDATE - 1
GROUP BY TO_CHAR(log_time, 'HH24')
ORDER BY hora;
