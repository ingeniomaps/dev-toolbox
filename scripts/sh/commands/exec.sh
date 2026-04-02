#!/usr/bin/env bash
# ============================================================================
# Script: exec.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Ejecuta un comando específico en un contenedor Docker.
#
# Uso:
#   ./scripts/sh/commands/exec.sh <servicio> <comando>
#
# Parámetros:
#   $1 - Nombre del servicio (requerido)
#   $2 - Comando a ejecutar (requerido)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#
# Retorno:
#   0 si el comando se ejecutó exitosamente
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
if ! validate_required_args 2 "$0 <servicio> <comando>" "$@"; then
	log_info "Ejemplo: $0 postgres \"psql -U user -d db -c 'SELECT 1'\""
	exit 1
fi

readonly SERVICE="$1"
shift
readonly CMD="$*"

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

log_info "Ejecutando comando en contenedor '$CONTAINER_NAME': $CMD"

# Ejecutar comando
docker exec "$CONTAINER_NAME" sh -c "$CMD"
