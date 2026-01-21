#!/usr/bin/env bash
# ============================================================================
# Script: build.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Construye imágenes Docker de servicios.
#
# Uso:
#   ./scripts/sh/commands/build.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios a construir. Si no se especifica,
#        construye todos los servicios detectados desde .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   BUILD_ARGS - Argumentos adicionales para docker build (opcional)
#
# Retorno:
#   0 si todas las construcciones fueron exitosas
#   1 si alguna construcción falló
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
		log_warn "No hay servicios disponibles para construir"
		log_info "Crea un archivo .env o especifica servicios con: " \
			"make build SERVICES=\"servicio1 servicio2\""
		exit 0
	fi
fi

log_step "Construyendo imágenes Docker..."

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
		log_info "Construyendo imágenes de $service..."
		# Construir argumentos de build de forma segura
		BUILD_ARGS_SAFE="${BUILD_ARGS:-}"
		if command -v retry_command >/dev/null 2>&1; then
			if [[ -n "$BUILD_ARGS_SAFE" ]]; then
				if ! retry_command 2 bash -c "cd '$SERVICE_DIR' && $DOCKER_COMPOSE_CMD build $BUILD_ARGS_SAFE"; then
					log_error "Falló al construir $service después de 2 intentos"
					EXIT_CODE=1
				else
					log_success "$service construido correctamente"
				fi
			else
				if ! retry_command 2 bash -c "cd '$SERVICE_DIR' && $DOCKER_COMPOSE_CMD build"; then
					log_error "Falló al construir $service después de 2 intentos"
					EXIT_CODE=1
				else
					log_success "$service construido correctamente"
				fi
			fi
		else
			if [[ -n "$BUILD_ARGS_SAFE" ]]; then
				if ! (cd "$SERVICE_DIR" && $DOCKER_COMPOSE_CMD build $BUILD_ARGS_SAFE); then
					log_error "Falló al construir $service"
					EXIT_CODE=1
				else
					log_success "$service construido correctamente"
				fi
			else
				if ! (cd "$SERVICE_DIR" && $DOCKER_COMPOSE_CMD build); then
					log_error "Falló al construir $service"
					EXIT_CODE=1
				else
					log_success "$service construido correctamente"
				fi
			fi
		fi
	elif [[ -f "$SERVICE_DIR/docker/Dockerfile" ]] || \
		[[ -f "$SERVICE_DIR/Dockerfile" ]]; then
		log_info "Construyendo imagen de $service..."
		DOCKERFILE="$SERVICE_DIR/Dockerfile"
		[[ ! -f "$DOCKERFILE" ]] && DOCKERFILE="$SERVICE_DIR/docker/Dockerfile"

		if [[ -f "$DOCKERFILE" ]]; then
			# Construir argumentos de build de forma segura
			BUILD_ARGS_SAFE="${BUILD_ARGS:-}"
			if command -v retry_command >/dev/null 2>&1; then
				if [[ -n "$BUILD_ARGS_SAFE" ]]; then
					if ! retry_command 2 docker build $BUILD_ARGS_SAFE -t "$service:latest" \
						-f "$DOCKERFILE" "$SERVICE_DIR"; then
						log_error "Falló al construir $service después de 2 intentos"
						EXIT_CODE=1
					else
						log_success "$service construido correctamente"
					fi
				else
					if ! retry_command 2 docker build -t "$service:latest" \
						-f "$DOCKERFILE" "$SERVICE_DIR"; then
						log_error "Falló al construir $service después de 2 intentos"
						EXIT_CODE=1
					else
						log_success "$service construido correctamente"
					fi
				fi
			else
				if [[ -n "$BUILD_ARGS_SAFE" ]]; then
					if ! docker build $BUILD_ARGS_SAFE -t "$service:latest" \
						-f "$DOCKERFILE" "$SERVICE_DIR"; then
						log_error "Falló al construir $service"
						EXIT_CODE=1
					else
						log_success "$service construido correctamente"
					fi
				else
					if ! docker build -t "$service:latest" \
						-f "$DOCKERFILE" "$SERVICE_DIR"; then
						log_error "Falló al construir $service"
						EXIT_CODE=1
					else
						log_success "$service construido correctamente"
					fi
				fi
			fi
		else
			log_warn "No se encontró Dockerfile para $service"
		fi
	else
		log_warn "No se encontró docker-compose.yml ni Dockerfile para $service"
	fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todas las imágenes construidas correctamente"
	exit 0
else
	log_error "Algunas construcciones fallaron"
	exit 1
fi
