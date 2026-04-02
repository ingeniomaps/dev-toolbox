#!/usr/bin/env bash
# ============================================================================
# Script: update-images.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Actualiza imágenes Docker de servicios.
#
# Uso:
#   ./scripts/sh/commands/update-images.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios a actualizar. Si no se especifica,
#        detecta desde variables *_VERSION en .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#
# Retorno:
#   0 si todas las actualizaciones fueron exitosas
#   1 si alguna actualización falló
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

if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

if [[ -f "$COMMON_SCRIPTS_DIR/error-handling.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/error-handling.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Determinar servicios: parámetros > SERVICES env > detectar desde .env
if [[ $# -gt 0 ]]; then
	SERVICES_LIST="$*"
elif [[ -n "${SERVICES:-}" ]]; then
	SERVICES_LIST="$SERVICES"
else
	# Usar helper común para detectar servicios
	if command -v detect_services_from_env >/dev/null 2>&1; then
		SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")
	else
		if [[ -f "$ENV_FILE" ]]; then
			SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$ENV_FILE" 2>/dev/null | \
				sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | \
				tr '_' '-' | tr '\n' ' ' || echo "")
		fi
	fi

	if [[ -z "$SERVICES_LIST" ]]; then
		log_warn "No hay servicios disponibles para actualizar"
		exit 0
	fi
fi

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No hay servicios disponibles para actualizar"
	exit 0
fi

log_step "Actualizando imágenes Docker..."

# Detectar comando de docker compose usando helper
if [[ -f "$COMMON_SCRIPTS_DIR/docker-compose.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/docker-compose.sh"
fi

if command -v get_docker_compose_cmd >/dev/null 2>&1; then
	DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
else
	# Fallback manual
	if docker compose version >/dev/null 2>&1; then
		DOCKER_COMPOSE_CMD="docker compose"
	elif command -v docker-compose >/dev/null 2>&1; then
		DOCKER_COMPOSE_CMD="docker-compose"
	else
		DOCKER_COMPOSE_CMD="docker compose"
	fi
fi

EXIT_CODE=0
for service in $SERVICES_LIST; do
	SERVICE_DIR="$PROJECT_ROOT/containers/$service"

	if [[ -f "$SERVICE_DIR/docker-compose.yml" ]]; then
		log_info "Actualizando imágenes de $service..."
		if command -v retry_command >/dev/null 2>&1; then
			if ! retry_command 3 bash -c "cd '$SERVICE_DIR' && $DOCKER_COMPOSE_CMD pull"; then
				log_error "Falló al actualizar $service después de 3 intentos"
				EXIT_CODE=1
			fi
		else
			if ! (cd "$SERVICE_DIR" && $DOCKER_COMPOSE_CMD pull); then
				EXIT_CODE=1
			fi
		fi
	elif [[ -f "$SERVICE_DIR/docker/docker-compose.yml" ]]; then
		log_info "Actualizando imágenes de $service..."
		if command -v retry_command >/dev/null 2>&1; then
			if ! retry_command 3 bash -c "cd '$SERVICE_DIR/docker' && $DOCKER_COMPOSE_CMD pull"; then
				log_error "Falló al actualizar $service después de 3 intentos"
				EXIT_CODE=1
			fi
		else
			if ! (cd "$SERVICE_DIR/docker" && $DOCKER_COMPOSE_CMD pull); then
				EXIT_CODE=1
			fi
		fi
	else
		log_warn "No se encontró docker-compose.yml para $service"
	fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Imágenes actualizadas"
	exit 0
else
	log_error "Algunas actualizaciones fallaron"
	exit 1
fi
