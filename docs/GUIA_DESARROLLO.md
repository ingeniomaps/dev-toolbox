# Guía de Desarrollo - Crear Nuevos Scripts

> Guía completa para crear nuevos scripts siguiendo las mejores prácticas del proyecto

## 📋 Tabla de Contenidos

1. [Estructura Básica](#estructura-básica)
2. [Uso de Helpers](#uso-de-helpers)
3. [Validación de Argumentos](#validación-de-argumentos)
4. [Manejo de Errores](#manejo-de-errores)
5. [Logging](#logging)
6. [Docker Compose](#docker-compose)
7. [Checklist de Calidad](#checklist-de-calidad)
8. [Ejemplos Completos](#ejemplos-completos)

---

## Estructura Básica

### Template Mínimo

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

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Cargar helpers comunes (OBLIGATORIO)
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
else
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

# Tu código aquí
log_info "Script ejecutándose..."

exit 0
```

### Reglas Obligatorias

1. ✅ **SIEMPRE usar `init.sh`** - Es obligatorio para todos los scripts nuevos
2. ✅ **Header completo** - Incluir descripción, uso, parámetros, variables, retorno
3. ✅ **`set -euo pipefail`** - Manejo estricto de errores
4. ✅ **`IFS=$'\n\t'`** - Separador de campos seguro
5. ✅ **Líneas ≤ 120 caracteres** - Usar continuaciones (`\`) cuando sea necesario
6. ✅ **Logging unificado** - Usar `log_info`, `log_error`, etc.

---

## Uso de Helpers

### init.sh (OBLIGATORIO)

```bash
# SIEMPRE incluir esto al inicio
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi
```

**Beneficios**:
- Inicializa `PROJECT_ROOT` correctamente
- Carga logging automáticamente
- Establece rutas consistentes

### services.sh (Si detectas servicios)

```bash
if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

# Detectar servicios
SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")

# Obtener nombre de contenedor
CONTAINER_NAME=$(get_container_name "$service")

# Verificar si está corriendo
if is_container_running "$CONTAINER_NAME"; then
	# ...
fi
```

### validation.sh (Si validas argumentos)

```bash
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos requeridos
if ! validate_required_args 2 "$0 <service> <command>" "$@"; then
	exit 1
fi

# Validar tipos
validate_port "$PORT" "PORT"
validate_file_exists "$ENV_FILE" "Archivo .env"
```

### error-handling.sh (Si necesitas cleanup/retry)

```bash
if [[ -f "$COMMON_SCRIPTS_DIR/error-handling.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/error-handling.sh"
	setup_error_trap
fi

# Registrar cleanup
cleanup_temp() {
	rm -f /tmp/temp-*
}
register_cleanup cleanup_temp

# Retry con backoff
retry_command 3 docker pull "image:tag"
```

### docker-compose.sh (Si usas docker compose)

```bash
if [[ -f "$COMMON_SCRIPTS_DIR/docker-compose.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/docker-compose.sh"
fi

DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
docker_compose_up "$PROJECT_ROOT" "docker-compose.yml" "-d"
```

---

## Validación de Argumentos

### Patrón Recomendado

```bash
# 1. Cargar validation.sh
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# 2. Validar argumentos requeridos
if ! validate_required_args 1 "$0 <service>" "$@"; then
	exit 1
fi

# 3. Validar argumentos opcionales
if [[ -n "${PORT:-}" ]]; then
	validate_port "$PORT" "PORT"
fi

# 4. Validar archivos/directorios
validate_file_exists "$ENV_FILE" "Archivo .env"
```

---

## Manejo de Errores

### Patrón Recomendado

```bash
# Opción 1: Usar error-handling.sh
source "$COMMON_SCRIPTS_DIR/error-handling.sh"
setup_error_trap

# Opción 2: Manejo manual
if ! command; then
	log_error "Comando falló"
	exit 1
fi

# Opción 3: Con retry
retry_command 3 docker pull "image:tag" || {
	log_error "No se pudo descargar imagen después de 3 intentos"
	exit 1
}
```

---

## Logging

### Niveles Disponibles

```bash
log_debug "Información detallada para depuración"
log_info "Mensaje informativo general"
log_success "Operación completada exitosamente"
log_warn "Advertencia (no crítico)"
log_error "Error (crítico)"
log_step "Paso del proceso"
log_title "Título de sección"
```

### Buenas Prácticas

- ✅ Usar `log_info` para información general
- ✅ Usar `log_success` cuando una operación se completa
- ✅ Usar `log_error` para errores que requieren atención
- ✅ Usar `log_warn` para advertencias no críticas
- ✅ Evitar `echo` directo, usar logging unificado

---

## Docker Compose

### Patrón Recomendado

```bash
source "$COMMON_SCRIPTS_DIR/docker-compose.sh"

# Detectar comando
DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)

# Usar funciones helper
docker_compose_up "$PROJECT_ROOT" "docker-compose.yml" "-d"
docker_compose_logs "$PROJECT_ROOT" "docker-compose.yml" "service"
```

---

## Checklist de Calidad

Antes de commitear un nuevo script, verifica:

- [ ] ✅ Usa `init.sh` (OBLIGATORIO)
- [ ] ✅ Header completo con documentación
- [ ] ✅ `set -euo pipefail` y `IFS=$'\n\t'`
- [ ] ✅ Todas las líneas ≤ 120 caracteres
- [ ] ✅ Usa logging unificado (`log_info`, `log_error`, etc.)
- [ ] ✅ Valida argumentos si los requiere
- [ ] ✅ Maneja errores correctamente
- [ ] ✅ Usa helpers cuando sea apropiado (`services.sh`, `validation.sh`, etc.)
- [ ] ✅ Código sin duplicación (usa helpers comunes)
- [ ] ✅ Comentarios claros donde sea necesario
- [ ] ✅ Pruebas manuales realizadas

### Verificación Automática

```bash
# Verificar sintaxis
bash -n scripts/sh/commands/tu-script.sh

# Verificar calidad de código
bash scripts/sh/utils/check-code-quality.sh
```

---

## Ejemplos Completos

### Ejemplo 1: Script Simple con Validación

```bash
#!/usr/bin/env bash
# ============================================================================
# Script: ejemplo-simple.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Script de ejemplo que valida argumentos y muestra información.
#
# Uso:
#   ./scripts/sh/commands/ejemplo-simple.sh <nombre>
#
# Parámetros:
#   $1 - Nombre a procesar (requerido)
#
# Retorno:
#   0 si exitoso
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

if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos
if ! validate_required_args 1 "$0 <nombre>" "$@"; then
	exit 1
fi

readonly NOMBRE="$1"

log_info "Procesando: $NOMBRE"
log_success "Proceso completado"

exit 0
```

### Ejemplo 2: Script con Servicios Docker

```bash
#!/usr/bin/env bash
# ============================================================================
# Script: ejemplo-servicios.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Script que lista servicios Docker.
#
# Uso:
#   ./scripts/sh/commands/ejemplo-servicios.sh
#
# Retorno:
#   0 si exitoso
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

if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Detectar servicios
SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No hay servicios configurados"
	exit 0
fi

log_info "Servicios detectados:"
for service in $SERVICES_LIST; do
	CONTAINER_NAME=$(get_container_name "$service")
	if is_container_running "$CONTAINER_NAME"; then
		log_success "$service ($CONTAINER_NAME) - corriendo"
	else
		log_warn "$service ($CONTAINER_NAME) - detenido"
	fi
done

exit 0
```

---

## 📚 Recursos Adicionales

- [Documentación de Helpers](./HELPERS.md)
- [HELPERS.md](HELPERS.md) - Documentación completa de helpers
- [ESTANDARES_OBLIGATORIOS.md](ESTANDARES_OBLIGATORIOS.md) - Estándares obligatorios
- [HELPERS.md](HELPERS.md) - Documentación de helpers

---

## ⚠️ Recordatorios Importantes

1. **OBLIGATORIO**: Todos los scripts nuevos DEBEN usar `init.sh`
2. **OBLIGATORIO**: Todas las líneas ≤ 120 caracteres
3. **OBLIGATORIO**: Usar logging unificado, no `echo` directo
4. **Recomendado**: Usar helpers comunes para evitar duplicación
5. **Recomendado**: Validar argumentos con `validation.sh`
6. **Recomendado**: Manejar errores con `error-handling.sh`

---

*Última actualización: 2025-01-27*
