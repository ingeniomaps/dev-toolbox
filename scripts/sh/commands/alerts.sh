#!/usr/bin/env bash
# ============================================================================
# Script: alerts.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Verifica estado de servicios y muestra alertas.
#
# Uso:
#   ./scripts/sh/commands/alerts.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios. Si no se especifica, detecta desde
#        variables *_VERSION en .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#
# Retorno:
#   0 si no hay alertas
#   1 si hay alertas
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

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe si vamos a detectar servicios desde él
if [[ $# -eq 0 ]] && [[ -z "${SERVICES:-}" ]]; then
	if ! validate_env_file "$ENV_FILE"; then
		log_error "No se pueden verificar alertas sin archivo .env"
		log_info "💡 Solución: Ejecuta 'make init-env' o especifica servicios con:"
		log_info "   make alerts SERVICES=\"servicio1 servicio2\""
		exit 1
	fi
fi

log_title "ALERTAS DEL SISTEMA"

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
		log_warn "No hay servicios disponibles para verificar"
		exit 0
	fi
fi

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No hay servicios disponibles para verificar"
	exit 0
fi

ALERT_COUNT=0
for service in $SERVICES_LIST; do
	if command -v get_container_name >/dev/null 2>&1; then
		CONTAINER_NAME=$(get_container_name "$service")
	else
		if [[ -z "${SERVICE_PREFIX:-}" ]]; then
			CONTAINER_NAME="$service"
		else
			CONTAINER_NAME="${SERVICE_PREFIX}-${service}"
		fi
	fi

	if ! command -v is_container_running >/dev/null 2>&1 || \
		! is_container_running "$CONTAINER_NAME"; then
		log_error "ALERTA: $CONTAINER_NAME no está corriendo"
		ALERT_COUNT=$((ALERT_COUNT + 1))
	else
		HEALTH=$(docker inspect --format='{{.State.Health.Status}}' \
			"$CONTAINER_NAME" 2>/dev/null || echo "no_healthcheck")

		if [[ "$HEALTH" == "unhealthy" ]]; then
			log_error "ALERTA: $CONTAINER_NAME está unhealthy"
			ALERT_COUNT=$((ALERT_COUNT + 1))
		fi
	fi
done

if [[ $ALERT_COUNT -eq 0 ]]; then
	log_success "No hay alertas - todos los servicios están saludables"
	exit 0
else
	echo ""
	log_error "Total de alertas: $ALERT_COUNT"
	exit 1
fi
