#!/usr/bin/env bash
# ============================================================================
# Script: test-connectivity.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Prueba conectividad entre servicios Docker.
#
# Uso:
#   ./scripts/sh/commands/test-connectivity.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios. Si no se especifica, detecta desde
#        variables *_VERSION en .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#   NETWORK_NAME - Nombre de la red Docker (opcional)
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
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
		log_error "No se pueden probar servicios sin archivo .env"
		log_info "💡 Solución: Ejecuta 'make init-env' o especifica servicios con:"
		log_info "   make test-connectivity SERVICES=\"servicio1 servicio2\""
		exit 1
	fi
fi

log_title "TESTS DE CONECTIVIDAD ENTRE SERVICIOS"

EXIT_CODE=0

# Verificar red Docker
if [[ -n "${NETWORK_NAME:-}" ]]; then
	if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
		log_success "Red Docker '${NETWORK_NAME}' existe"
	else
		log_error "Red Docker '${NETWORK_NAME}' no existe"
		log_info "Ejecuta: make network-tool"
		EXIT_CODE=1
	fi
else
	log_warn "NETWORK_NAME no definido"
fi

echo ""

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
		log_warn "No hay servicios disponibles para probar"
		exit 0
	fi
fi

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No hay servicios disponibles para probar"
	exit 0
fi

# Probar cada servicio
for service in $SERVICES_LIST; do
	log_info "Probando $service..."

	if command -v get_container_name >/dev/null 2>&1; then
		CONTAINER_NAME=$(get_container_name "$service")
	else
		if [[ -z "${SERVICE_PREFIX:-}" ]]; then
			CONTAINER_NAME="$service"
		else
			CONTAINER_NAME="${SERVICE_PREFIX}-${service}"
		fi
	fi

	if command -v is_container_running >/dev/null 2>&1; then
		IS_RUNNING=$(is_container_running "$CONTAINER_NAME")
	else
		IS_RUNNING=$(docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && echo "true" || echo "false")
	fi

	if [[ "$IS_RUNNING" == "true" ]] || \
		(docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"); then
		HEALTH=$(docker inspect --format='{{.State.Health.Status}}' \
			"$CONTAINER_NAME" 2>/dev/null || echo "no_healthcheck")

		if [[ "$HEALTH" == "healthy" ]] || [[ "$HEALTH" == "no_healthcheck" ]]; then
			STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)

			if [[ "$STATUS" == "running" ]]; then
				log_success "$service está corriendo ($STATUS)"
			else
				log_error "$service no está corriendo ($STATUS)"
				EXIT_CODE=1
			fi
		else
			log_error "$service está unhealthy ($HEALTH)"
			EXIT_CODE=1
		fi
	else
		log_warn "Contenedor $service no está corriendo"
		EXIT_CODE=1
	fi

	echo ""
done

# Verificar conectividad en red
if [[ -n "${NETWORK_NAME:-}" ]] && docker network ls --format '{{.Name}}' | \
	grep -q "^${NETWORK_NAME}$"; then
	log_info "Probando conectividad en red '${NETWORK_NAME}'..."
	NETWORK_CONTAINERS=$(docker network inspect "$NETWORK_NAME" \
		--format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")

	if [[ -n "$NETWORK_CONTAINERS" ]]; then
		log_success "Contenedores conectados: $NETWORK_CONTAINERS"
	else
		log_warn "No hay contenedores conectados a la red"
	fi
fi

echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todos los tests de conectividad pasaron"
	exit 0
else
	log_error "Algunos tests de conectividad fallaron"
	exit 1
fi
