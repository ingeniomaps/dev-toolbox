#!/usr/bin/env bash
# ============================================================================
# Script: wait-for-service.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Espera a que un contenedor Docker pase su healthcheck.
#
# Uso:
#   ./scripts/sh/utils/wait-for-service.sh <contenedor> [segundos]
#
# Parámetros:
#   $1 - Nombre del contenedor (requerido)
#   $2 - Tiempo máximo en segundos (opcional, default: 60)
#
# Retorno:
#   0 si el servicio está saludable
#   1 si se agota el tiempo o hay error
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

if [[ -f "$COMMON_SCRIPTS_DIR/error-handling.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/error-handling.sh"
fi

readonly CONTAINER_NAME="${1:-}"
readonly MAX_WAIT="${2:-60}"

# Validar parámetros usando helper
if ! validate_required_args 1 "$0 <container-name> [max-wait-seconds]" "$CONTAINER_NAME"; then
	exit 1
fi

if ! validate_optional_args "MAX_WAIT" "$MAX_WAIT" "number"; then
	log_error "El tiempo máximo de espera debe ser un número positivo"
	exit 1
fi

if [[ "$MAX_WAIT" -le 0 ]]; then
	log_error "El tiempo máximo de espera debe ser mayor que 0"
	exit 1
fi

log_info "Esperando que el servicio '$CONTAINER_NAME' esté saludable..."

# Esperar un momento inicial para que el contenedor tenga tiempo de iniciar
# Esto es especialmente importante cuando se ejecuta justo después de
# docker compose up -d
sleep 2

_start_time=$(date +%s)
readonly start_time="$_start_time"
unset _start_time
readonly SLEEP_INTERVAL=2

# Calcular tiempo transcurrido desde el inicio
get_elapsed_time() {
	echo $(($(date +%s) - start_time))
}

elapsed=0

while [[ $elapsed -lt $MAX_WAIT ]]; do
	# Verificar si el contenedor existe (buscando en contenedores corriendo
	# y detenidos)
	if ! docker ps -a --format '{{.Names}}' 2>/dev/null | \
		grep -q "^${CONTAINER_NAME}$"; then
		log_warn "Contenedor '$CONTAINER_NAME' no encontrado. Esperando..."
		sleep "$SLEEP_INTERVAL"
		elapsed=$(get_elapsed_time)
		continue
	fi

	# Verificar el estado del contenedor primero
	container_status=$(docker inspect --format='{{.State.Status}}' \
		"$CONTAINER_NAME" 2>/dev/null || echo "none")

	if [[ "$container_status" != "running" ]]; then
		log_warn "Contenedor '$CONTAINER_NAME' está en estado" \
			"'$container_status'. Esperando..."
		sleep "$SLEEP_INTERVAL"
		elapsed=$(get_elapsed_time)
		continue
	fi

	# Verificar el estado del healthcheck
	health_status=$(docker inspect --format='{{.State.Health.Status}}' \
		"$CONTAINER_NAME" 2>/dev/null || echo "none")

	# Limpiar espacios en blanco que puedan venir del comando
	health_status=$(echo "$health_status" | tr -d '[:space:]')

	case "$health_status" in
		"healthy")
			log_success "Servicio '$CONTAINER_NAME' está saludable"
			exit 0
			;;
		"unhealthy")
			log_warn "Servicio '$CONTAINER_NAME' está marcado como no saludable"
			;;
		"starting")
			# El healthcheck aún no ha comenzado o está en proceso -
			# continuar esperando
			;;
		"none"|"")
			# No hay healthcheck configurado, verificar si el contenedor
			# está corriendo
			if [[ "$container_status" == "running" ]]; then
				log_warn "Contenedor '$CONTAINER_NAME' está corriendo pero" \
					"sin healthcheck configurado"
				log_info "Asumiendo que el servicio está listo..."
				exit 0
			fi
			;;
		*)
			# Estado desconocido - mostrar para debugging
			log_warn "Estado de salud desconocido: '$health_status'" \
				"(contenedor: $container_status). Esperando..."
			;;
	esac

	sleep "$SLEEP_INTERVAL"
	elapsed=$(get_elapsed_time)
done

log_error "Tiempo de espera agotado. El servicio '$CONTAINER_NAME' no está" \
	"saludable después de ${MAX_WAIT}s"
exit 1
