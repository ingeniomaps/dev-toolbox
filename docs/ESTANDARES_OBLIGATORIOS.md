# Estándares Obligatorios para Scripts

> ⚠️ **IMPORTANTE**: Estos estándares son OBLIGATORIOS para todos los scripts nuevos

## 📋 Checklist Obligatorio

Todos los scripts nuevos DEBEN cumplir con estos estándares:

### 1. ✅ Usar `init.sh` (OBLIGATORIO)

**Todos los scripts nuevos DEBEN usar `init.sh` para inicialización.**

```bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# OBLIGATORIO: Cargar init.sh
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi
```

**Razón**: Garantiza inicialización consistente, carga logging automáticamente y establece `PROJECT_ROOT` correctamente.

**Verificación**: El CI/CD verifica que los scripts en `commands/` usen `init.sh`.

---

### 2. ✅ Líneas ≤ 120 caracteres (OBLIGATORIO)

**Todas las líneas DEBEN tener máximo 120 caracteres.**

```bash
# ❌ MAL (línea muy larga)
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" | grep -q "running"; then

# ✅ BIEN (usar continuaciones)
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && \
	docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" | \
	grep -q "running"; then
```

**Razón**: Mejora legibilidad, facilita code review y permite trabajar en pantallas pequeñas.

**Verificación**: El CI/CD verifica automáticamente la longitud de líneas.

---

### 3. ✅ Logging Unificado (OBLIGATORIO)

**Usar funciones de logging, NO `echo` directo.**

```bash
# ❌ MAL
echo "Procesando..."
echo "Error: algo falló" >&2

# ✅ BIEN
log_info "Procesando..."
log_error "Algo falló"
```

**Funciones disponibles**:
- `log_debug()` - Depuración
- `log_info()` - Información general
- `log_success()` - Éxito
- `log_warn()` - Advertencias
- `log_error()` - Errores
- `log_step()` - Pasos de proceso
- `log_title()` - Títulos

**Razón**: Logging consistente, colores automáticos, control de verbosidad, formato uniforme.

---

### 4. ✅ Header Completo (OBLIGATORIO)

**Todos los scripts DEBEN tener un header completo con documentación.**

```bash
#!/usr/bin/env bash
# ============================================================================
# Script: nombre-script.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Descripción breve del script.
#
# Uso:
#   ./scripts/sh/commands/nombre-script.sh [argumentos]
#
# Parámetros:
#   $1 - Descripción del primer parámetro
#   $2 - Descripción del segundo parámetro (opcional)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   VARIABLE_OPCIONAL - Descripción (opcional)
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores
# ============================================================================
```

**Razón**: Documentación inline, ayuda a entender el script sin leer el código, facilita mantenimiento.

---

### 5. ✅ Manejo Estricto de Errores (OBLIGATORIO)

**Usar `set -euo pipefail` y `IFS=$'\n\t'`.**

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

**Explicación**:
- `set -e` - Sale si cualquier comando falla
- `set -u` - Error si se usa variable no definida
- `set -o pipefail` - Retorna código de error del pipe si falla
- `IFS=$'\n\t'` - Separador de campos seguro

**Razón**: Previene errores silenciosos, detecta problemas temprano, comportamiento predecible.

---

### 6. ✅ Validar Argumentos (RECOMENDADO)

**Validar argumentos cuando el script los requiere.**

```bash
# Cargar validation.sh
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos requeridos
if ! validate_required_args 1 "$0 <service>" "$@"; then
	exit 1
fi

# Validar tipos
if [[ -n "${PORT:-}" ]]; then
	validate_port "$PORT" "PORT"
fi
```

**Razón**: Mejora UX, mensajes de error claros, previene errores en runtime.

---

## 🔍 Verificación

### Verificación Manual

```bash
# Verificar sintaxis
bash -n scripts/sh/commands/tu-script.sh

# Verificar calidad
bash scripts/sh/utils/check-code-quality.sh
```

### Verificación Automática (CI/CD)

El CI/CD verifica automáticamente:
- ✅ Sintaxis de scripts
- ✅ Longitud de líneas (≤ 120 caracteres)
- ✅ Uso de `init.sh` en scripts nuevos
- ✅ Tests de helpers

---

## 📚 Recursos

- [Guía de Desarrollo](GUIA_DESARROLLO.md) - Guía completa para crear scripts
- [Documentación de Helpers](HELPERS.md) - Referencia de helpers disponibles
- [HELPERS.md](HELPERS.md) - Documentación completa de helpers
- [GUIA_DESARROLLO.md](GUIA_DESARROLLO.md) - Guía de desarrollo

---

## ⚠️ Sanciones

Los scripts que no cumplan con estos estándares:

1. **No serán aceptados en PRs** - El CI/CD fallará
2. **Serán marcados para refactorización** - En el próximo ciclo
3. **No seguirán las mejores prácticas** - Dificultarán mantenimiento

---

---

## 🔍 Linting y Formateo

### ShellCheck

Todos los scripts deben pasar ShellCheck sin errores críticos:

```bash
# Ejecutar linting
make lint

# Aplicar correcciones automáticas (shfmt)
make lint-fix
```

**Configuración**: `.shellcheckrc` en la raíz del proyecto.

### shfmt

Todos los scripts deben estar formateados con shfmt:

```bash
# Verificar formato
make lint

# Aplicar formato automáticamente
make lint-fix
```

**Configuración**: `.shfmt.yaml` en la raíz del proyecto.

### Pre-commit Hooks

Los hooks de pre-commit verifican automáticamente:
- ShellCheck
- shfmt
- Longitud de líneas
- Sintaxis Bash

**Instalación**:
```bash
pip install pre-commit
make install-pre-commit  # O: bash scripts/sh/setup/install-pre-commit.sh
```

---

*Última actualización: 2025-01-27*
