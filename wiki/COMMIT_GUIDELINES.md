# 📝 Convención de Commits

Este documento define los tipos de mensajes de commit aceptados para mantener una historia limpia, legible y colaborativa entre desarrolladores.

---

## ✅ Tipos de commit y su propósito

| Tipo       | Propósito                                                               | Ejemplo de commit                                         |
| ---------- | ----------------------------------------------------------------------- | --------------------------------------------------------- |
| `feat`     | Añadir una nueva funcionalidad al sistema                               | `feat: agregar autenticación con JWT`                     |
| `fix`      | Corrección de errores o bugs                                            | `fix: corregir error al guardar usuario sin email`        |
| `docs`     | Cambios en la documentación (README, comentarios, etc.)                 | `docs: actualizar guía de instalación`                    |
| `style`    | Cambios que no afectan el comportamiento del código (espacios, formato) | `style: aplicar prettier al archivo de rutas`             |
| `refactor` | Cambios que mejoran el código sin alterar su funcionalidad              | `refactor: simplificar lógica de validación`              |
| `perf`     | Mejoras de rendimiento                                                  | `perf: optimizar consulta SQL de reportes`                |
| `test`     | Agregar o modificar pruebas (unitarias, de integración)                 | `test: añadir tests para el controlador de productos`     |
| `chore`    | Tareas de mantenimiento que no afectan el código de producción          | `chore: actualizar dependencias del proyecto`             |
| `ci`       | Cambios en la configuración de integración continua                     | `ci: agregar paso de lint al pipeline`                    |
| `build`    | Cambios que afectan el sistema de compilación o dependencias            | `build: actualizar configuración de webpack`              |
| `revert`   | Reversión de un commit anterior                                         | `revert: revertir commit 9e4a1d9 por error en producción` |

---

## 📌 Estructura recomendada del commit

```
<tipo>(opcional: módulo): <mensaje breve en minúsculas>
```

### Ejemplo:

```
feat(auth): agregar endpoint de login con Google
```

---

## 🚨 Recomendaciones

- Escribir en tiempo **presente**: `agregar`, `corregir`, `actualizar`.
- Mantener el mensaje **claro y conciso**.
- Usar prefijos por módulo si aplica: `feat(api)`, `fix(docker)`, `test(database)`.
- Si el equipo trabaja internacionalmente, preferir mensajes en **inglés**.

---

## 📂 Ejemplo de convención en acción

```bash
git commit -m "fix(auth): handle empty token error"
git commit -m "docs: update environment setup guide"
git commit -m "chore: remove unused dependencies"
```
