#!/usr/bin/env bash
# ============================================================================
# Script: list-services.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Lista todos los servicios detectados desde variables *_VERSION en .env.
#
# Uso:
#   ./scripts/sh/commands/list-services.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#
# Retorno:
#   0 si la operación fue exitosa
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
	# Fallback si init.sh no está disponible
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

log_info "Servicios configurados:"
echo ""

# Validar que .env existe
if ! validate_env_file "$ENV_FILE"; then
	log_warn "No se pueden listar servicios sin archivo .env"
	log_info "💡 Sugerencia: Ejecuta 'make init-env' para crear el archivo .env"
	exit 0
fi

# Usar helper común para detectar servicios
SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No se encontraron servicios con *_VERSION en .env"
	exit 0
fi

for service in $SERVICES_LIST; do
	# Usar helper común para obtener nombre de contenedor
	CONTAINER_NAME=$(get_container_name "$service")

	# Usar helper común para obtener versión
	VERSION=$(get_service_version "$service" "$ENV_FILE")

	# Usar helper común para verificar estado
	if is_container_running "$CONTAINER_NAME"; then
		STATUS="🟢 corriendo"
	else
		STATUS="🔴 detenido"
	fi

	log_info "  • $service (v${VERSION:-desconocida}): $STATUS"
done

echo ""
