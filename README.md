# 🤖 Oracle MCP Server — Kit de Implementación

[![Oracle](https://img.shields.io/badge/Oracle_Database-F80000?style=flat&logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![SQLcl](https://img.shields.io/badge/SQLcl-25.2+-blue?style=flat)](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/)
[![MCP](https://img.shields.io/badge/MCP-Model_Context_Protocol-purple?style=flat)](https://modelcontextprotocol.io/)
[![Claude](https://img.shields.io/badge/Claude_Desktop-Compatible-green?style=flat)](https://claude.ai)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=flat&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-UPL--1.0-orange?style=flat)](LICENSE)

> **Conecta Oracle Database con Claude AI usando lenguaje natural.**
> Kit completo de implementación: guía paso a paso, scripts de diagnóstico, configuración y consultas SQL de auditoría.

---

## 🎯 ¿Qué resuelve esto?

El Oracle MCP Server (disponible desde **SQLcl 25.2+**) permite que cualquier usuario autorizado consulte una base de datos Oracle usando lenguaje natural desde Claude Desktop o VS Code — sin escribir SQL, sin depender del DBA, con cada consulta auditada automáticamente en `DBTOOLS$MCP_LOG`.

**Antes:** *"Necesito al DBA para saber cuántas facturas vencidas hay"*
**Después:** *"¿Cuántas facturas tienen más de 30 días vencidas por cliente?"* → SQL generado y ejecutado automáticamente.

---

## 📁 Estructura del repositorio

```
oracle-ai-mcp-server/
│
├── README.md                          ← Este archivo
│
├── docs/
│   └── guia-implementacion.md         ← Guía completa paso a paso
│
├── config/
│   ├── claude_desktop_config.json     ← Template de configuración Claude Desktop
│   └── vscode_mcp_config.json         ← Template para VS Code
│
├── scripts/
│   ├── oracle-mcp-diagnostico.ps1     ← Diagnóstico completo del sistema
│   ├── oracle-mcp-configurar-conexiones.ps1  ← Wizard de configuración
│   ├── oracle-mcp-pruebas.ps1         ← Suite de pruebas PASS/FAIL
│   └── INSTALAR.bat                   ← Instalador automatizado
│
└── sql/
    ├── crear_usuario_mcp.sql          ← Crear usuario Oracle con menor privilegio
    ├── grant_permisos.sql             ← Grants mínimos necesarios
    └── validar_mcp_log.sql            ← Consultas de auditoría
```

---

## ⚡ Inicio rápido (15 minutos)

### Prerrequisitos
| Componente | Versión mínima | Verificar |
|-----------|---------------|-----------|
| Java | 17+ | `java -version` |
| SQLcl | 25.2+ | `sql -v` |
| Claude Desktop | Última | [claude.ai/download](https://claude.ai/download) |
| Oracle DB | 19c+ | Conectividad resuelta |

### Pasos

```powershell
# 1. Clonar el repositorio
git clone https://github.com/jesmonsa/oracle-ai-mcp-server.git
cd oracle-ai-mcp-server

# 2. Ejecutar diagnóstico del sistema
.\scripts\oracle-mcp-diagnostico.ps1

# 3. Configurar conexión a la base de datos
.\scripts\oracle-mcp-configurar-conexiones.ps1

# 4. Copiar template de configuración a Claude Desktop
copy config\claude_desktop_config.json "%APPDATA%\Claude\claude_desktop_config.json"

# 5. Reiniciar Claude Desktop y probar
```

📖 Para el paso a paso completo → [`docs/guia-implementacion.md`](docs/guia-implementacion.md)

---

## 🏗️ Arquitectura

```
┌─────────────────────┐         ┌──────────────────────────┐
│   Claude Desktop    │ ──MCP── │   SQLcl 25.2+ (MCP Srv)  │
│   (o VS Code)       │         │   sql.exe -mcp            │
└─────────────────────┘         └────────────┬─────────────┘
                                              │ JDBC / TNS
                                 ┌────────────▼─────────────┐
                                 │   Oracle Database 19c+   │
                                 │   (DBCS / ExaCS / ADB)   │
                                 └──────────────────────────┘
```

**Flujo:**
1. Usuario escribe en lenguaje natural en Claude Desktop
2. Claude genera SQL optimizado vía MCP Server (SQLcl)
3. SQLcl ejecuta el SQL contra Oracle Database
4. Resultado regresa a Claude → respuesta en lenguaje natural
5. Cada consulta queda auditada en `DBTOOLS$MCP_LOG`

---

## 🔐 Seguridad

Este kit sigue el principio de **menor privilegio**:
- El usuario MCP tiene solo `CONNECT` + grants específicos por schema
- Sin acceso a `DBA_*` ni vistas del sistema
- Auditoría completa en `DBTOOLS$MCP_LOG`
- Credenciales en Connection Store local (nunca en texto plano)

Ver → [`sql/crear_usuario_mcp.sql`](sql/crear_usuario_mcp.sql)

---

## 🗺️ Escenarios soportados

| Escenario | Soporte |
|-----------|---------|
| Oracle DBCS Enterprise Edition en OCI | ✅ Completo |
| Oracle Autonomous Database (ADB) | ✅ Con wallet |
| Oracle 19c on-premise | ✅ Con EZConnect |
| Oracle ExaCS | ✅ Completo |
| Claude Desktop (Windows) | ✅ |
| VS Code + Continue.dev | ✅ |
| Mac / Linux | 🚧 En desarrollo |

---

## 📚 Documentación adicional

- [Guía de implementación completa](docs/guia-implementacion.md)
- [Oracle SQLcl MCP — Documentación oficial](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/)
- [Model Context Protocol](https://modelcontextprotocol.io/)

---

## 👤 Autor

**Jesús Andrés Montoya**
Cloud Architect & Oracle Database Specialist — Oracle Cloud Infrastructure, Colombia & LATAM

[![GitHub](https://img.shields.io/badge/GitHub-jesmonsa-181717?style=flat&logo=github)](https://github.com/jesmonsa)

---

## 📄 Licencia

Universal Permissive License v1.0 — ver [LICENSE](LICENSE)
