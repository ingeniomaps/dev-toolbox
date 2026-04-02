#!/usr/bin/env bash
# ============================================================================
# Script: save-state.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Guarda el estado actual del sistema para rollback.
#
# Uso:
#   ./scripts/sh/commands/save-state.sh [nombre_estado]
#
# Parámetros:
#   $1 - (opcional) Nombre personalizado para el estado
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   STATES_DIR - Directorio donde se guardan los estados (default: .states)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#   NETWORK_NAME - Nombre de la red Docker (opcional)
#
# Retorno:
#   0 si el estado se guardó exitosamente
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

readonly STATE_NAME_CUSTOM="${1:-}"
readonly STATES_DIR="${STATES_DIR:-$PROJECT_ROOT/.states}"

log_step "Guardando estado del sistema..."

mkdir -p "$STATES_DIR"

if [[ -n "$STATE_NAME_CUSTOM" ]]; then
	STATE_NAME="$STATE_NAME_CUSTOM"
else
	STATE_NAME=$(date +%Y%m%d_%H%M%S)
fi

readonly STATE_FILE="$STATES_DIR/$STATE_NAME.json"

log_info "Guardando en: $STATE_FILE"

# Detectar servicios desde variables *_VERSION en .env
SERVICES_LIST=""
if [[ -f "$PROJECT_ROOT/.env" ]]; then
	SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$PROJECT_ROOT/.env" 2>/dev/null | \
		sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr '\n' ' ' || echo "")
fi

# Generar JSON del estado
{
	echo "{"
	echo "  \"timestamp\": \"$(date -Iseconds)\","
	echo "  \"state_name\": \"$STATE_NAME\","
	echo "  \"containers\": ["

	FIRST=true
	if [[ -n "$SERVICES_LIST" ]]; then
		for service in $SERVICES_LIST; do
			if [[ -z "${SERVICE_PREFIX:-}" ]]; then
				CONTAINER_NAME="$service"
			else
				CONTAINER_NAME="${SERVICE_PREFIX}-${service}"
			fi

			if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
				if [[ "$FIRST" == "false" ]]; then
					echo ","
				fi
				FIRST=false
				echo -n "    {"
				echo -n "\"name\": \"${CONTAINER_NAME}\","
				IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "")
				echo -n "\"image\": \"${IMAGE}\","
				STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "")
				echo -n "\"status\": \"${STATUS}\","
				CREATED=$(docker inspect --format='{{.Created}}' "$CONTAINER_NAME" 2>/dev/null || echo "")
				echo -n "\"created\": \"${CREATED}\""
				echo -n "}"
			fi
		done
	fi
	echo ""
	echo "  ],"
	echo "  \"volumes\": ["

	FIRST=true
	while IFS= read -r volume; do
		[[ -z "$volume" ]] && continue
		if [[ "$FIRST" == "false" ]]; then
			echo ","
		fi
		FIRST=false
		echo -n "    \"$volume\""
	done < <(docker volume ls --format '{{.Name}}' 2>/dev/null || true)

	echo ""
	echo "  ],"
	echo "  \"networks\": ["

	FIRST=true
	if [[ -n "${NETWORK_NAME:-}" ]]; then
		while IFS= read -r network; do
			[[ -z "$network" ]] && continue
			if ! echo "$network" | grep -qE "${NETWORK_NAME}"; then
				continue
			fi
			if [[ "$FIRST" == "false" ]]; then
				echo ","
			fi
			FIRST=false
			echo -n "    \"$network\""
		done < <(docker network ls --format '{{.Name}}' 2>/dev/null || true)
	fi

	echo ""
	echo "  ]"
	echo "}"
} > "$STATE_FILE"

log_success "Estado guardado en $STATE_FILE"
log_info "Para restaurar: make rollback STATE=$STATE_NAME"
