#!/usr/bin/env bash
# ============================================================================
# Script: aggregate-logs.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Muestra logs agregados de múltiples servicios.
#
# Uso:
#   ./scripts/sh/commands/aggregate-logs.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios. Si no se especifica, detecta desde
#        variables *_VERSION en .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#   LOG_LEVEL_FILTER - Filtrar logs por nivel (opcional)
#   LOG_DATE_FILTER - Filtrar logs por fecha (opcional)
#   LOG_LINES_LIMIT - Límite de líneas por servicio (default: 100, max: 10000)
#   LOG_BUFFER_SIZE - Tamaño de buffer para procesamiento (default: 8192)
#   LOG_MAX_SERVICES - Máximo número de servicios a monitorear (default: 50)
#
# Opciones:
#   --limit=N         - Límite de líneas por servicio (default: 100)
#   --buffer-size=N   - Tamaño de buffer (default: 8192)
#   --max-services=N  - Máximo número de servicios (default: 50)
#   --tail-only       - Solo mostrar últimas líneas, no seguir logs
#   --no-color        - Deshabilitar colores en logs
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

if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

if [[ -f "$COMMON_SCRIPTS_DIR/error-handling.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/error-handling.sh"
	setup_error_trap
fi

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe si vamos a detectar servicios desde él
if [[ $# -eq 0 ]] && [[ -z "${SERVICES:-}" ]]; then
	if ! validate_env_file "$ENV_FILE"; then
		log_error "No se pueden agregar logs sin archivo .env"
		log_info "💡 Solución: Ejecuta 'make init-env' o especifica servicios con:"
		log_info "   make aggregate-logs SERVICES=\"servicio1 servicio2\""
		exit 1
	fi
fi

log_info "Logs agregados de servicios"
log_info "Presiona Ctrl+C para salir"
echo ""

# Parsear opciones primero antes de determinar servicios
LOG_LIMIT="${LOG_LINES_LIMIT:-100}"
LOG_BUFFER="${LOG_BUFFER_SIZE:-8192}"
MAX_SERVICES="${LOG_MAX_SERVICES:-50}"
TAIL_ONLY=false
# NO_COLOR está reservado para uso futuro (deshabilitar colores en salida)
# NO_COLOR=false
POSITIONAL_ARGS=()

for arg in "$@"; do
	case "$arg" in
		--limit=*)
			LOG_LIMIT="${arg#*=}"
			;;
		--buffer-size=*)
			LOG_BUFFER="${arg#*=}"
			;;
		--max-services=*)
			MAX_SERVICES="${arg#*=}"
			;;
		--tail-only)
			TAIL_ONLY=true
			;;
		--no-color)
			# NO_COLOR está reservado para uso futuro
			# NO_COLOR=true
			;;
		*)
			POSITIONAL_ARGS+=("$arg")
			;;
	esac
done

# Determinar servicios: parámetros > SERVICES env > detectar desde .env
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
	SERVICES_LIST="${POSITIONAL_ARGS[*]}"
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

# Verificar que hay servicios corriendo
RUNNING_COUNT=0
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

	if command -v is_container_running >/dev/null 2>&1; then
		if is_container_running "$CONTAINER_NAME"; then
			RUNNING_COUNT=$((RUNNING_COUNT + 1))
		fi
	else
		if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
			RUNNING_COUNT=$((RUNNING_COUNT + 1))
		fi
	fi
done

if [[ $RUNNING_COUNT -eq 0 ]]; then
	log_warn "No hay servicios corriendo"
	exit 0
fi


readonly LOG_LEVEL="${LOG_LEVEL_FILTER:-}"
readonly LOG_DATE="${LOG_DATE_FILTER:-}"

# Limitar LOG_LIMIT a máximo 10000 para evitar problemas de memoria
if [[ $LOG_LIMIT -gt 10000 ]]; then
	LOG_LIMIT=10000
	log_warn "Límite de líneas reducido a 10000 para evitar problemas de memoria"
fi

# Limitar número de servicios
if [[ -n "$SERVICES_LIST" ]]; then
	SERVICES_COUNT=$(echo "$SERVICES_LIST" | wc -w)
	if [[ $SERVICES_COUNT -gt $MAX_SERVICES ]]; then
		log_warn "Se limitará el monitoreo a $MAX_SERVICES servicios (hay $SERVICES_COUNT)"
		SERVICES_LIST=$(echo "$SERVICES_LIST" | tr ' ' '\n' | head -n "$MAX_SERVICES" | tr '\n' ' ')
	fi
fi

# Función para procesar logs de un servicio
process_service_logs() {
	local service="$1"
	local container_name="$2"
	local limit="$3"

	# Función auxiliar para filtrar por nivel si es necesario
	filter_logs() {
		if [[ -n "$LOG_LEVEL" ]]; then
			grep -iE "(error|warn|info|debug|${LOG_LEVEL})" || true
		else
			cat
		fi
	}

	if [[ "$TAIL_ONLY" == "true" ]]; then
		# Solo mostrar últimas líneas, no seguir
		if [[ -n "$LOG_DATE" ]]; then
			docker logs --since "$LOG_DATE" --tail="$limit" "$container_name" 2>&1 | \
				stdbuf -oL -eL -iL "${LOG_BUFFER}" filter_logs | \
				sed "s/^/[$service] /"
		else
			docker logs --tail="$limit" "$container_name" 2>&1 | \
				stdbuf -oL -eL -iL "${LOG_BUFFER}" filter_logs | \
				sed "s/^/[$service] /"
		fi
	else
		# Seguir logs en tiempo real
		if [[ -n "$LOG_DATE" ]]; then
			docker logs --since "$LOG_DATE" --tail="$limit" -f "$container_name" 2>&1 | \
				stdbuf -oL -eL -iL "${LOG_BUFFER}" filter_logs | \
				sed "s/^/[$service] /"
		else
			docker logs -f --tail="$limit" "$container_name" 2>&1 | \
				stdbuf -oL -eL -iL "${LOG_BUFFER}" filter_logs | \
				sed "s/^/[$service] /"
		fi
	fi
}

# Iniciar logs en background para cada servicio (con límites optimizados)
SERVICE_COUNT=0
for service in $SERVICES_LIST; do
	SERVICE_COUNT=$((SERVICE_COUNT + 1))

	if [[ $SERVICE_COUNT -gt $MAX_SERVICES ]]; then
		break
	fi

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
		(docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null); then
		process_service_logs "$service" "$CONTAINER_NAME" "$LOG_LIMIT" &
	fi
done

# Cleanup: matar procesos en background al salir
cleanup_logs() {
	kill 0 2>/dev/null || true
}

if command -v register_cleanup >/dev/null 2>&1; then
	register_cleanup cleanup_logs
else
	trap cleanup_logs EXIT
fi

wait
