#!/usr/bin/env bash
# ============================================================================
# Script: list-images.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Lista imágenes Docker usadas por el proyecto.
#
# Uso:
#   ./scripts/sh/commands/list-images.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
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
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

log_info "Imágenes Docker del proyecto:"
echo ""

# Obtener imágenes desde servicios configurados
if [[ -f "$ENV_FILE" ]]; then
	if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/services.sh"
	fi

	if command -v detect_services_from_env >/dev/null 2>&1; then
		SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")
	else
		SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$ENV_FILE" 2>/dev/null | \
			sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | \
			tr '_' '-' | tr '\n' ' ' || echo "")
	fi

	if [[ -n "$SERVICES_LIST" ]]; then
		IMAGE_COUNT=0
		for service in $SERVICES_LIST; do
			# Obtener versión del servicio
			if command -v get_service_version >/dev/null 2>&1; then
				VERSION=$(get_service_version "$service" "$ENV_FILE")
			else
				VERSION_VAR=$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
				VERSION=$(grep -E "^${VERSION_VAR}_VERSION=" "$ENV_FILE" 2>/dev/null | \
					cut -d'=' -f2- | sed 's/^["'\'']//;s/["'\'']$//' || echo "")
			fi

			# Construir nombre de imagen
			if [[ -n "$VERSION" ]]; then
				IMAGE_NAME="${service}:${VERSION}"
			else
				IMAGE_NAME="${service}:latest"
			fi

			# Verificar si la imagen existe
			if docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | \
				grep -q "^${IMAGE_NAME}$"; then
				SIZE=$(docker images --format '{{.Size}}' "$IMAGE_NAME" 2>/dev/null || echo "")
				log_info "  • $IMAGE_NAME ($SIZE)"
				IMAGE_COUNT=$((IMAGE_COUNT + 1))
			fi
		done

		if [[ $IMAGE_COUNT -eq 0 ]]; then
			log_info "  (ninguna imagen encontrada para servicios configurados)"
		fi
	else
		log_info "  (ningún servicio configurado)"
	fi
else
	log_warn ".env no encontrado"
fi

echo ""

# Mostrar todas las imágenes si hay muchas
ALL_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | wc -l || echo "0")
if [[ $ALL_IMAGES -gt 0 ]]; then
	log_info "Total de imágenes en sistema: $ALL_IMAGES"
fi
