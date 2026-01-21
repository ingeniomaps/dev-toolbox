#!/usr/bin/env bash
# ============================================================================
# Script: shell.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Abre shell interactivo en un contenedor Docker.
#
# Uso:
#   ./scripts/sh/commands/shell.sh <servicio> [shell_cmd]
#
# Parámetros:
#   $1 - Nombre del servicio (requerido)
#   $2 - (opcional) Comando shell a usar (default: /bin/bash o /bin/sh)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#
# Retorno:
#   0 si el shell se abrió exitosamente
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Cargar helpers comunes
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

if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

# Validar argumentos usando helper
if ! validate_required_args 1 "$0 <servicio> [shell_cmd]" "$@"; then
	log_info "Ejemplo: $0 postgres /bin/bash"
	exit 1
fi

readonly SERVICE="$1"
readonly SHELL_CMD="${2:-}"

# Determinar nombre del contenedor usando helper
if command -v get_container_name >/dev/null 2>&1; then
	CONTAINER_NAME=$(get_container_name "$SERVICE")
else
	if [[ -z "${SERVICE_PREFIX:-}" ]]; then
		CONTAINER_NAME="$SERVICE"
	else
		CONTAINER_NAME="${SERVICE_PREFIX}-${SERVICE}"
	fi
fi

# Verificar que el contenedor existe y está corriendo usando helper
if command -v is_container_running >/dev/null 2>&1; then
	if ! is_container_running "$CONTAINER_NAME"; then
		log_error "Contenedor '$CONTAINER_NAME' no está corriendo"
		log_info "Lista contenedores corriendo: docker ps"
		exit 1
	fi
else
	if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
		log_error "Contenedor '$CONTAINER_NAME' no está corriendo"
		log_info "Lista contenedores corriendo: docker ps"
		exit 1
	fi
fi

# Determinar shell a usar
if [[ -n "$SHELL_CMD" ]]; then
	USE_SHELL="$SHELL_CMD"
else
	# Intentar detectar shell disponible
	if docker exec "$CONTAINER_NAME" test -f /bin/bash 2>/dev/null; then
		USE_SHELL="/bin/bash"
	elif docker exec "$CONTAINER_NAME" test -f /bin/sh 2>/dev/null; then
		USE_SHELL="/bin/sh"
	else
		log_error "No se pudo determinar shell disponible en el contenedor"
		log_info "Especifica manualmente: make shell SERVICE=$SERVICE SHELL=/bin/sh"
		exit 1
	fi
fi

log_info "Abriendo shell en contenedor '$CONTAINER_NAME' (usando $USE_SHELL)"
log_info "Escribe 'exit' para salir"

# Ejecutar shell interactivo
exec docker exec -it "$CONTAINER_NAME" "$USE_SHELL"
