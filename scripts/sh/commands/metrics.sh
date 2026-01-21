#!/usr/bin/env bash
# ============================================================================
# Script: metrics.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Muestra métricas de servicios Docker.
#
# Uso:
#   ./scripts/sh/commands/metrics.sh [servicio1 servicio2 ...] [--skip-missing]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios. Si no se especifica, detecta desde
#        variables *_VERSION en .env
#
# Opciones:
#   --skip-missing  - Continuar con otros servicios si uno no existe o no está corriendo
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#   SKIP_MISSING - true: continuar si servicios no existen (equivalente a --skip-missing)
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores (o 0 si --skip-missing está activo)
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

# Parsear argumentos
SKIP_MISSING=false
SERVICES_ARGS=()
for arg in "$@"; do
	case "$arg" in
		--skip-missing)
			SKIP_MISSING=true
			;;
		*)
			SERVICES_ARGS+=("$arg")
			;;
	esac
done

# Verificar variable de entorno
if [[ "${SKIP_MISSING_ENV:-}" == "true" ]] || [[ "${SKIP_MISSING:-}" == "true" ]]; then
	SKIP_MISSING=true
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe si vamos a detectar servicios desde él
if [[ ${#SERVICES_ARGS[@]} -eq 0 ]] && [[ -z "${SERVICES:-}" ]]; then
	if ! validate_env_file "$ENV_FILE"; then
		log_error "No se pueden mostrar métricas sin archivo .env"
		log_info "💡 Solución: Ejecuta 'make init-env' o especifica servicios con:"
		log_info "   make metrics SERVICES=\"servicio1 servicio2\""
		exit 1
	fi
fi

log_title "MÉTRICAS DE SERVICIOS"

# Determinar servicios: parámetros > SERVICES env > detectar desde .env
if [[ ${#SERVICES_ARGS[@]} -gt 0 ]]; then
	SERVICES_LIST="${SERVICES_ARGS[*]}"
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
		log_warn "No hay servicios disponibles"
		exit 0
	fi
fi

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No hay servicios disponibles"
	exit 0
fi

# Filtrar servicios existentes y construir filtros para docker ps
FILTER_ARGS=""
VALID_SERVICES=()
EXIT_CODE=0
MISSING_COUNT=0
FOUND_COUNT=0

for service in $SERVICES_LIST; do
	# Obtener nombre del contenedor
	if command -v get_container_name >/dev/null 2>&1; then
		CONTAINER_NAME=$(get_container_name "$service")
	else
		if [[ -z "${SERVICE_PREFIX:-}" ]]; then
			CONTAINER_NAME="$service"
		else
			CONTAINER_NAME="${SERVICE_PREFIX}-${service}"
		fi
	fi

	# Verificar si el contenedor existe (corriendo o detenido)
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
		FILTER_ARGS="$FILTER_ARGS --filter name=$CONTAINER_NAME"
		VALID_SERVICES+=("$service")
		FOUND_COUNT=$((FOUND_COUNT + 1))
	else
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_warn "Servicio $service (contenedor $CONTAINER_NAME) no encontrado (omitido)"
			MISSING_COUNT=$((MISSING_COUNT + 1))
		else
			log_error "Servicio $service (contenedor $CONTAINER_NAME) no encontrado"
			log_info "💡 Sugerencia: Usa --skip-missing para continuar con otros servicios"
			EXIT_CODE=1
			MISSING_COUNT=$((MISSING_COUNT + 1))
		fi
	fi
done

if [[ $FOUND_COUNT -eq 0 ]]; then
	if [[ $MISSING_COUNT -gt 0 ]]; then
		log_error "Ningún servicio encontrado"
		if [[ "$SKIP_MISSING" != "true" ]]; then
			log_info "💡 Sugerencia: Usa --skip-missing para ver servicios disponibles"
		fi
		exit 1
	else
		log_warn "No hay servicios disponibles"
		exit 0
	fi
fi

# Obtener contenedores corriendo
RUNNING_CONTAINERS=$(docker ps $FILTER_ARGS --format "{{.Names}}" 2>/dev/null | head -10 || echo "")

if [[ -z "$RUNNING_CONTAINERS" ]]; then
	log_warn "No hay servicios corriendo"
	if [[ "$SKIP_MISSING" == "true" ]]; then
		exit 0
	else
		log_info "💡 Sugerencia: Inicia los servicios con 'make start' o usa --skip-missing"
		exit 1
	fi
fi

log_info "Uso de Recursos (CPU y Memoria):"
# Obtener nombres de contenedores en un array para evitar word splitting
mapfile -t container_names < <(docker ps $FILTER_ARGS --format "{{.Names}}" 2>/dev/null || true)
if ! docker stats --no-stream \
	--format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" \
	"${container_names[@]}" \
	2>/dev/null; then
	log_warn "No se pudieron obtener métricas de recursos"
	EXIT_CODE=1
fi

echo ""

log_info "Estado de Salud:"
HEALTHY_COUNT=0
UNHEALTHY_COUNT=0
for container in $(docker ps $FILTER_ARGS --format "{{.Names}}" 2>/dev/null); do
	HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no_healthcheck")
	STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)

	if [[ "$HEALTH" == "healthy" ]]; then
		log_success "$container: $STATUS ($HEALTH)"
		HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
	elif [[ "$HEALTH" == "no_healthcheck" ]]; then
		if [[ "$STATUS" == "running" ]]; then
			log_info "$container: $STATUS (sin healthcheck)"
			HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
		else
			log_warn "$container: $STATUS"
			UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
		fi
	else
		log_warn "$container: $STATUS ($HEALTH)"
		UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
	fi
done

echo ""

log_info "Uso de Disco (Volúmenes):"
if ! docker system df -v 2>/dev/null | grep -A 20 "VOLUME NAME" | head -15; then
	log_warn "No se pudieron obtener métricas de volúmenes"
	EXIT_CODE=1
fi

echo ""

# Resumen
if [[ $MISSING_COUNT -gt 0 ]]; then
	log_info "Resumen: $FOUND_COUNT encontrados, $MISSING_COUNT no encontrados"
fi

if [[ $UNHEALTHY_COUNT -gt 0 ]] && [[ "$SKIP_MISSING" != "true" ]]; then
	EXIT_CODE=1
fi

if [[ $EXIT_CODE -eq 0 ]] || [[ "$SKIP_MISSING" == "true" ]]; then
	exit 0
else
	exit 1
fi
