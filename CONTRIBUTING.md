# Guía de Contribución

> Guía completa para contribuir a dev-toolbox

¡Gracias por tu interés en contribuir a dev-toolbox! Esta guía te ayudará a entender cómo contribuir de manera efectiva.

---

## 📋 Tabla de Contenidos

- [Código de Conducta](#código-de-conducta)
- [Cómo Contribuir](#cómo-contribuir)
- [Estándares de Código](#estándares-de-código)
- [Proceso de Pull Request](#proceso-de-pull-request)
- [Estructura de Commits](#estructura-de-commits)
- [Agregar Nuevos Comandos](#agregar-nuevos-comandos)
- [Agregar Nuevos Scripts](#agregar-nuevos-scripts)
- [Tests Requeridos](#tests-requeridos)
- [Checklist para PRs](#checklist-para-prs)

---

## 🤝 Código de Conducta

Al contribuir, aceptas mantener un ambiente respetuoso y colaborativo. Sé amable, constructivo y profesional en todas las interacciones.

---

## 🚀 Cómo Contribuir

### 1. Fork y Clone

```bash
# Fork el repositorio en GitHub
# Luego clona tu fork
git clone https://github.com/tu-usuario/dev-toolbox.git
cd dev-toolbox
```

### 2. Crear Rama

```bash
# Crear una rama para tu contribución
git checkout -b feat/mi-nueva-funcionalidad
# o
git checkout -b fix/correccion-de-bug
```

### 3. Hacer Cambios

Sigue los estándares de código descritos en esta guía.

### 4. Commit y Push

```bash
# Hacer commit siguiendo la estructura de commits
git commit -m "feat: agregar nuevo comando para limpiar logs"

# Push a tu fork
git push origin feat/mi-nueva-funcionalidad
```

### 5. Crear Pull Request

Abre un Pull Request en GitHub con una descripción clara de los cambios.

---

## 📝 Estándares de Código

### Estándares para Scripts Bash

Todos los scripts Bash **DEBEN** cumplir con estos estándares obligatorios:

#### 1. Header Completo (OBLIGATORIO)

```bash
#!/usr/bin/env bash
# ============================================================================
# Script: nombre-script.sh
# Ubicación: scripts/sh/commands/ (o utils/, setup/, backup/)
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

#### 2. Manejo Estricto de Errores (OBLIGATORIO)

```bash
set -euo pipefail
IFS=$'\n\t'
```

**Explicación**:
- `set -e` - Sale si cualquier comando falla
- `set -u` - Error si se usa variable no definida
- `set -o pipefail` - Retorna código de error del pipe si falla
- `IFS=$'\n\t'` - Separador de campos seguro

#### 3. Usar `init.sh` (OBLIGATORIO)

```bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# OBLIGATORIO: Cargar init.sh
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi
```

#### 4. Líneas ≤ 120 Caracteres (OBLIGATORIO)

```bash
# ❌ MAL (línea muy larga)
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" | grep -q "running"; then

# ✅ BIEN (usar continuaciones)
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && \
	docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" | \
	grep -q "running"; then
```

#### 5. Logging Unificado (OBLIGATORIO)

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

#### 6. Validar Argumentos (RECOMENDADO)

```bash
# Cargar validation.sh
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos requeridos
if ! validate_required_args 1 "$0 <service>" "$@"; then
	exit 1
fi
```

#### 7. Variables Readonly

```bash
# ✅ BIEN
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# ❌ MAL (variables mutables sin necesidad)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### Estándares para Makefiles

#### 1. Header con Documentación

```makefile
# ============================================================================
# Nombre del Makefile
# ============================================================================
# Descripción breve del propósito del Makefile.
#
# Uso:
#   make comando
#
# Variables:
#   VARIABLE - Descripción (opcional, default: valor)
# ============================================================================
```

#### 2. Variables al Inicio

```makefile
# Variables del Makefile
PROJECT_ROOT := $(CURDIR)
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts/sh/commands

# Variables opcionales con valores por defecto
SERVICE ?= postgres
FORCE ?= false
```

#### 3. .PHONY Declarado

```makefile
.PHONY: comando1 comando2 comando3
```

#### 4. Comentarios con Categorías para help-toolbox

```makefile
comando: ## Descripción del comando [categoria]
	@bash $(SCRIPTS_DIR)/script.sh
```

**Categorías disponibles**:
- `main` - Comandos principales
- `validation` - Validación de configuración
- `security` - Gestión de seguridad
- `load` - Infisical y herramientas
- `tool` - Gestión de versiones
- `monitoring` - Monitoreo y métricas
- `backup` - Backups y restauraciones
- `ci-cd` - Integración CI/CD

#### 5. Uso de Variables Consistentes

```makefile
# ✅ BIEN
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts/sh/commands
@bash $(SCRIPTS_DIR)/script.sh

# ❌ MAL (rutas hardcodeadas)
@bash scripts/sh/commands/script.sh
```

#### 6. Manejo de Errores

```makefile
comando:
	@if [ ! -f "$(SCRIPT)" ]; then \
		$(call LOG_ERROR, "Script no encontrado"); \
		exit 1; \
	fi
	@bash $(SCRIPT)
```

#### 7. Líneas ≤ 120 Caracteres

```makefile
# ❌ MAL (línea muy larga)
comando: ## Descripción muy larga que excede los 120 caracteres y hace difícil leer el código [categoria]

# ✅ BIEN (usar continuaciones)
comando: ## Descripción del comando [categoria]
	@bash $(SCRIPTS_DIR)/script.sh $(if $(SERVICE),$(SERVICE),)
```

### Verificación de Estándares

```bash
# Verificar sintaxis de scripts
bash -n scripts/sh/commands/tu-script.sh

# Verificar calidad de código
bash scripts/sh/utils/check-code-quality.sh

# Verificar sintaxis de Makefiles
make -n comando
```

---

## 🔄 Proceso de Pull Request

### Antes de Crear el PR

1. **Asegúrate de que tu código cumple los estándares**
   ```bash
   bash scripts/sh/utils/check-code-quality.sh
   ```

2. **Ejecuta los tests**
   ```bash
   bash scripts/sh/tests/test-init.sh
   bash scripts/sh/tests/test-services.sh
   ```

3. **Verifica que el CI/CD pase**
   - El PR debe pasar todas las verificaciones automáticas

4. **Actualiza la documentación si es necesario**
   - README.md
   - docs/HELPERS.md (si agregas helpers)
   - docs/GUIA_DESARROLLO.md (si cambias patrones)

### Crear el PR

1. **Título descriptivo**
   ```
   feat: agregar comando para limpiar logs antiguos
   fix: corregir validación de puertos en check-ports
   docs: actualizar guía de integración
   ```

2. **Descripción completa**
   ```markdown
   ## Descripción
   Agrega un nuevo comando `clean-logs` que elimina logs antiguos.

   ## Cambios
   - Nuevo script: scripts/sh/commands/clean-logs.sh
   - Nuevo target en makefiles/main/monitoring.mk
   - Tests agregados

   ## Testing
   - [x] Tests unitarios pasan
   - [x] Verificación de calidad pasa
   - [x] Probado manualmente

   ## Checklist
   - [x] Código sigue estándares
   - [x] Documentación actualizada
   - [x] Tests agregados
   ```

3. **Referencias**
   - Si resuelve un issue, menciona: `Fixes #123`
   - Si relaciona con otro PR: `Relates to #456`

### Revisión del PR

1. **El CI/CD debe pasar**
   - Sintaxis de scripts
   - Longitud de líneas
   - Uso de `init.sh`
   - Tests

2. **Revisión de código**
   - Un mantenedor revisará el código
   - Puede solicitar cambios

3. **Aprobar cambios**
   - Una vez aprobado, se hará merge

---

## 📝 Estructura de Commits

Seguimos la convención de commits definida en [wiki/COMMIT_GUIDELINES.md](wiki/COMMIT_GUIDELINES.md).

### Formato

```
<tipo>(opcional: módulo): <mensaje breve en minúsculas>
```

### Tipos de Commit

| Tipo       | Propósito                                                               | Ejemplo                                    |
| ---------- | ----------------------------------------------------------------------- | ------------------------------------------ |
| `feat`     | Añadir una nueva funcionalidad                                         | `feat: agregar comando clean-logs`         |
| `fix`      | Corrección de errores o bugs                                            | `fix: corregir validación de puertos`      |
| `docs`     | Cambios en la documentación                                             | `docs: actualizar guía de integración`     |
| `style`    | Cambios que no afectan el comportamiento (espacios, formato)           | `style: aplicar formato a Makefile`        |
| `refactor` | Cambios que mejoran el código sin alterar funcionalidad                 | `refactor: simplificar lógica de backup`   |
| `perf`     | Mejoras de rendimiento                                                  | `perf: optimizar detección de servicios`   |
| `test`     | Agregar o modificar pruebas                                             | `test: agregar tests para validation.sh`   |
| `chore`    | Tareas de mantenimiento                                                 | `chore: actualizar dependencias`           |
| `ci`       | Cambios en la configuración de CI/CD                                   | `ci: agregar verificación de sintaxis`    |
| `build`    | Cambios que afectan el sistema de compilación                           | `build: actualizar versión`                |
| `revert`   | Reversión de un commit anterior                                         | `revert: revertir commit 9e4a1d9`          |

### Ejemplos

```bash
# Funcionalidad nueva
git commit -m "feat: agregar comando para exportar métricas"

# Corrección de bug
git commit -m "fix(validation): corregir validación de IPs IPv6"

# Documentación
git commit -m "docs: actualizar README con nuevos comandos"

# Refactorización
git commit -m "refactor(services): simplificar detección de servicios"

# Tests
git commit -m "test: agregar tests para error-handling.sh"
```

### Recomendaciones

- ✅ Escribir en tiempo **presente**: `agregar`, `corregir`, `actualizar`
- ✅ Mantener el mensaje **claro y conciso**
- ✅ Usar prefijos por módulo si aplica: `feat(backup)`, `fix(validation)`
- ✅ Mensajes en **español** (o inglés si el equipo lo prefiere)

---

## ➕ Agregar Nuevos Comandos

Un comando en dev-toolbox consiste en:
1. Un script Bash en `scripts/sh/commands/`
2. Un target en el Makefile correspondiente en `makefiles/main/`

### Paso 1: Crear el Script

```bash
# Crear el script
touch scripts/sh/commands/mi-comando.sh
chmod +x scripts/sh/commands/mi-comando.sh
```

Usa el template de la [Guía de Desarrollo](docs/GUIA_DESARROLLO.md).

### Paso 2: Implementar la Lógica

```bash
#!/usr/bin/env bash
# ============================================================================
# Script: mi-comando.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Descripción del comando.
#
# Uso:
#   ./scripts/sh/commands/mi-comando.sh [argumentos]
#
# Parámetros:
#   $1 - Descripción del parámetro
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Cargar helpers (OBLIGATORIO)
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi

# Tu lógica aquí
log_info "Ejecutando mi-comando..."
```

### Paso 3: Agregar Target al Makefile

Identifica el Makefile apropiado según la categoría:

- `services.mk` - Gestión de servicios
- `backup.mk` - Backups y restauraciones
- `validation.mk` - Validación
- `monitoring.mk` - Monitoreo
- `security.mk` - Seguridad
- `setup.mk` - Configuración

**Ejemplo en `makefiles/main/monitoring.mk`**:

```makefile
# ============================================================================
# Monitoreo y Métricas
# ============================================================================

.PHONY: mi-comando

mi-comando: ## Descripción del comando [monitoring]
	@bash $(TOOLBOX_ROOT)scripts/sh/commands/mi-comando.sh
```

### Paso 4: Verificar que Aparece en help-toolbox

```bash
make help-toolbox | grep mi-comando
```

### Paso 5: Probar el Comando

```bash
# Probar directamente
bash scripts/sh/commands/mi-comando.sh

# Probar vía Make
make mi-comando
```

### Ejemplo Completo: Comando `clean-logs`

**1. Script** (`scripts/sh/commands/clean-logs.sh`):
```bash
#!/usr/bin/env bash
# ============================================================================
# Script: clean-logs.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Elimina logs antiguos del sistema.
#
# Uso:
#   ./scripts/sh/commands/clean-logs.sh [días]
#
# Parámetros:
#   $1 - Días de antigüedad (default: 30)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi

DAYS="${1:-30}"

log_step "Limpiando logs antiguos (más de $DAYS días)..."

# Lógica de limpieza
find "$PROJECT_ROOT" -name "*.log" -type f -mtime +$DAYS -delete

log_success "Logs limpiados correctamente"
```

**2. Makefile** (`makefiles/main/monitoring.mk`):
```makefile
clean-logs: ## Elimina logs antiguos (default: 30 días) [monitoring]
	@DAYS="$(DAYS)" bash $(TOOLBOX_ROOT)scripts/sh/commands/clean-logs.sh $(DAYS)
```

**3. Uso**:
```bash
make clean-logs          # Elimina logs > 30 días
make clean-logs DAYS=7   # Elimina logs > 7 días
```

---

## 📜 Agregar Nuevos Scripts

Los scripts pueden ir en diferentes directorios según su propósito:

- `scripts/sh/commands/` - Comandos directos (usados por Makefiles)
- `scripts/sh/utils/` - Utilidades auxiliares
- `scripts/sh/setup/` - Scripts de configuración
- `scripts/sh/backup/` - Scripts de backup/restauración
- `scripts/sh/common/` - Helpers compartidos (requiere aprobación especial)

### Proceso

1. **Identificar ubicación correcta**
   - ¿Es un comando directo? → `commands/`
   - ¿Es una utilidad? → `utils/`
   - ¿Es de configuración? → `setup/`

2. **Crear el script siguiendo estándares**
   - Ver [Estándares de Código](#estándares-de-código)

3. **Usar helpers apropiados**
   - `init.sh` (OBLIGATORIO)
   - `services.sh` (si detecta servicios)
   - `validation.sh` (si valida argumentos)
   - `error-handling.sh` (si necesita cleanup/retry)
   - `docker-compose.sh` (si interactúa con Docker Compose)

4. **Agregar tests si es apropiado**
   - Ver [Tests Requeridos](#tests-requeridos)

5. **Documentar en docs/HELPERS.md** (solo si es helper común)

### Ejemplo: Script de Utilidad

**Script** (`scripts/sh/utils/wait-for-port.sh`):
```bash
#!/usr/bin/env bash
# ============================================================================
# Script: wait-for-port.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Espera a que un puerto esté disponible.
#
# Uso:
#   ./scripts/sh/utils/wait-for-port.sh <host> <port> [timeout]
#
# Parámetros:
#   $1 - Host (default: localhost)
#   $2 - Puerto (requerido)
#   $3 - Timeout en segundos (default: 30)
#
# Retorno:
#   0 si el puerto está disponible
#   1 si timeout o error
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi

if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos
if ! validate_required_args 1 "$0 <host> <port> [timeout]" "$@"; then
	exit 1
fi

HOST="${1:-localhost}"
PORT="$2"
TIMEOUT="${3:-30}"

validate_port "$PORT" "PORT"

log_info "Esperando puerto $PORT en $HOST (timeout: ${TIMEOUT}s)..."

# Lógica de espera
for i in $(seq 1 $TIMEOUT); do
	if nc -z "$HOST" "$PORT" 2>/dev/null; then
		log_success "Puerto $PORT disponible"
		exit 0
	fi
	sleep 1
done

log_error "Timeout esperando puerto $PORT"
exit 1
```

---

## 🧪 Tests Requeridos

### Cuándo Agregar Tests

- ✅ **Helpers comunes** (`scripts/sh/common/`) - Tests obligatorios
- ✅ **Comandos críticos** - Tests recomendados
- ✅ **Utilidades complejas** - Tests recomendados
- ⚠️ **Scripts simples** - Tests opcionales

### Estructura de Tests

Los tests van en `scripts/sh/tests/` y siguen este formato:

```bash
#!/usr/bin/env bash
# ============================================================================
# Test: test-mi-helper.sh
# Ubicación: scripts/sh/tests/
# ============================================================================
# Tests para mi-helper.sh
#
# Uso:
#   bash scripts/sh/tests/test-mi-helper.sh
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_DIR="$TEST_DIR/../common"

# Contador de tests
TESTS_PASSED=0
TESTS_FAILED=0

# Función de test
test_function() {
	local test_name="$1"
	local expected="$2"
	local actual="$3"
	
	if [[ "$expected" == "$actual" ]]; then
		echo "✅ PASS: $test_name"
		((TESTS_PASSED++))
		return 0
	else
		echo "❌ FAIL: $test_name"
		echo "   Expected: $expected"
		echo "   Actual: $actual"
		((TESTS_FAILED++))
		return 1
	fi
}

# Cargar helper a testear
source "$COMMON_DIR/mi-helper.sh"

# Tests
echo "🧪 Ejecutando tests para mi-helper.sh..."
echo ""

# Test 1
test_function "test_1" "expected_value" "$(mi_function "input")"

# Test 2
test_function "test_2" "expected_value" "$(mi_function "input2")"

# Resumen
echo ""
echo "=========================================="
echo "Tests pasados: $TESTS_PASSED"
echo "Tests fallidos: $TESTS_FAILED"
echo "=========================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
	exit 0
else
	exit 1
fi
```

### Ejemplo: Test para Helper

**Helper** (`scripts/sh/common/mi-helper.sh`):
```bash
mi_function() {
	local input="$1"
	echo "processed: $input"
}
```

**Test** (`scripts/sh/tests/test-mi-helper.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_DIR="$TEST_DIR/../common"

source "$COMMON_DIR/mi-helper.sh"

# Test
result=$(mi_function "test")
expected="processed: test"

if [[ "$result" == "$expected" ]]; then
	echo "✅ PASS: mi_function procesa input correctamente"
	exit 0
else
	echo "❌ FAIL: mi_function"
	echo "   Expected: $expected"
	echo "   Actual: $result"
	exit 1
fi
```

### Ejecutar Tests

```bash
# Test individual
bash scripts/sh/tests/test-mi-helper.sh

# Todos los tests
for test in scripts/sh/tests/test-*.sh; do
	bash "$test"
done
```

### Tests en CI/CD

Los tests se ejecutan automáticamente en CI/CD. Asegúrate de que:

1. El test tenga permisos de ejecución: `chmod +x scripts/sh/tests/test-*.sh`
2. El test retorne código de salida correcto (0 = éxito, 1 = fallo)
3. El test no dependa de servicios externos (o use mocks)

---

## ✅ Checklist para PRs

Antes de crear un PR, verifica:

### Código

- [ ] Scripts siguen estándares obligatorios
- [ ] Makefiles siguen estándares
- [ ] Líneas ≤ 120 caracteres
- [ ] Usa `init.sh` (si es script nuevo)
- [ ] Usa logging unificado (no `echo`)
- [ ] Header completo en scripts
- [ ] Variables `readonly` donde corresponde
- [ ] Validación de argumentos cuando aplica

### Funcionalidad

- [ ] El código funciona correctamente
- [ ] Probado manualmente
- [ ] No rompe funcionalidad existente
- [ ] Maneja errores correctamente

### Tests

- [ ] Tests agregados (si aplica)
- [ ] Tests pasan localmente
- [ ] Tests no dependen de servicios externos

### Documentación

- [ ] README.md actualizado (si agrega comandos)
- [ ] docs/HELPERS.md actualizado (si agrega helpers)
- [ ] Comentarios en código cuando es necesario

### Git

- [ ] Commits siguen estructura correcta
- [ ] Mensajes de commit claros
- [ ] PR tiene descripción completa
- [ ] Referencias a issues (si aplica)

### CI/CD

- [ ] CI/CD pasa todas las verificaciones
- [ ] No hay warnings del linter
- [ ] Sintaxis correcta

---

## 📚 Recursos

- [Guía de Desarrollo](docs/GUIA_DESARROLLO.md) - Crear nuevos scripts
- [Estándares Obligatorios](docs/ESTANDARES_OBLIGATORIOS.md) - Estándares de calidad
- [Documentación de Helpers](docs/HELPERS.md) - Referencia de helpers
- [Guía de Integración](docs/INTEGRATION_GUIDE.md) - Integrar dev-toolbox
- [Convención de Commits](wiki/COMMIT_GUIDELINES.md) - Estructura de commits

---

## ❓ Preguntas Frecuentes

### ¿Puedo agregar un helper común?

Los helpers comunes requieren aprobación especial. Abre un issue primero para discutir la necesidad.

### ¿Qué pasa si mi PR no pasa CI/CD?

Revisa los logs del CI/CD y corrige los problemas. Los errores más comunes:
- Líneas > 120 caracteres
- Scripts sin `init.sh`
- Sintaxis incorrecta

### ¿Cómo sé si mi código sigue los estándares?

Ejecuta:
```bash
bash scripts/sh/utils/check-code-quality.sh
```

### ¿Necesito tests para todo?

No, pero son obligatorios para helpers comunes y recomendados para comandos críticos.

---

## 🎉 ¡Gracias!

Tu contribución hace que dev-toolbox sea mejor para todos. ¡Gracias por tu tiempo y esfuerzo!

---

*Última actualización: 2025-01-27*
