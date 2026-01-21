#!/usr/bin/env bash
# ============================================================================
# Script: check-updates.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Verifica si hay actualizaciones disponibles para el toolbox y/o imágenes.
#
# Uso:
#   ./scripts/sh/commands/check-updates.sh [--toolbox] [--images]
#
# Parámetros:
#   --toolbox - (opcional) Verificar actualizaciones del toolbox
#   --images  - (opcional) Verificar actualizaciones de imágenes Docker
#   Si no se especifica, verifica ambos
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   TOOLBOX_ROOT - Raíz del toolbox (opcional)
#
# Retorno:
#   0 si hay actualizaciones disponibles
#   1 si no hay actualizaciones o hay errores
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

if [[ -f "$COMMON_SCRIPTS_DIR/error-handling.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/error-handling.sh"
fi

readonly CHECK_TOOLBOX="${1:-}"
readonly CHECK_IMAGES="${2:-}"

# Determinar qué verificar
# CHECK_BOTH no se usa, se usa DO_CHECK_TOOLBOX y DO_CHECK_IMAGES en su lugar
if [[ "$CHECK_TOOLBOX" == "--toolbox" ]] || [[ "$CHECK_IMAGES" == "--toolbox" ]]; then
	DO_CHECK_TOOLBOX=true
	DO_CHECK_IMAGES=false
elif [[ "$CHECK_TOOLBOX" == "--images" ]] || [[ "$CHECK_IMAGES" == "--images" ]]; then
	DO_CHECK_TOOLBOX=false
	DO_CHECK_IMAGES=true
else
	DO_CHECK_TOOLBOX=true
	DO_CHECK_IMAGES=true
fi

HAS_UPDATES=false

# Verificar actualizaciones del toolbox
if [[ "$DO_CHECK_TOOLBOX" == "true" ]]; then
	log_info "Verificando actualizaciones del toolbox..."

	TOOLBOX_ROOT="${TOOLBOX_ROOT:-$PROJECT_ROOT}"
	VERSION_FILE="$TOOLBOX_ROOT/.version"

	if [[ -f "$VERSION_FILE" ]]; then
		CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '\n' || echo "desconocida")
		log_info "  Versión actual: $CURRENT_VERSION"

		# Intentar verificar en Git si es un repo (con retry)
		if [[ -d "$TOOLBOX_ROOT/.git" ]]; then
			cd "$TOOLBOX_ROOT"
			if command -v retry_command >/dev/null 2>&1; then
				retry_command 3 git fetch origin >/dev/null 2>&1 || true
			else
				git fetch origin >/dev/null 2>&1 || true
			fi
			LATEST_TAG=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || \
				git describe --tags --abbrev=0 2>/dev/null || echo "")

			if [[ -n "$LATEST_TAG" ]] && [[ "$LATEST_TAG" != "v$CURRENT_VERSION" ]]; then
				log_success "  Actualización disponible: $LATEST_TAG"
				HAS_UPDATES=true
			else
				log_info "  Estás en la última versión"
			fi
		else
			log_warn "  No se puede verificar (no es un repo Git)"
		fi
	else
		log_warn "  Archivo .version no encontrado"
	fi
	echo ""
fi

# Verificar actualizaciones de imágenes
if [[ "$DO_CHECK_IMAGES" == "true" ]]; then
	log_info "Verificando actualizaciones de imágenes Docker..."

	ENV_FILE="$PROJECT_ROOT/.env"
	if [[ -f "$ENV_FILE" ]]; then
		# Detectar servicios desde variables *_VERSION en .env
		SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$ENV_FILE" 2>/dev/null | \
			sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr '\n' ' ' || echo "")

		if [[ -n "$SERVICES_LIST" ]]; then
			for service in $SERVICES_LIST; do
				VERSION_VAR=$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
				CURRENT_VER=$(grep -E "^${VERSION_VAR}_VERSION=" "$ENV_FILE" 2>/dev/null | \
					cut -d'=' -f2- | sed 's/^["'\'']//;s/["'\'']$//' || echo "")

				if [[ -n "$CURRENT_VER" ]]; then
					# IMAGE_NAME no se usa actualmente, reservado para uso futuro
					# IMAGE_NAME="$service"
					log_info "  $service: $CURRENT_VER"
					# Nota: Verificación real requeriría docker pull --dry-run o API de registry
					# Por ahora solo informamos
				fi
			done
			log_info "  (Ejecuta 'make update-images' para actualizar)"
		else
			log_warn "  No se encontraron servicios configurados"
		fi
	else
		log_warn "  .env no encontrado"
	fi
	echo ""
fi

if [[ "$HAS_UPDATES" == "true" ]]; then
	log_success "Hay actualizaciones disponibles"
	exit 0
else
	log_info "No hay actualizaciones disponibles o no se pudo verificar"
	exit 1
fi
