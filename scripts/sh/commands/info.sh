#!/usr/bin/env bash
# ============================================================================
# Script: info.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Muestra información completa del proyecto.
#
# Uso:
#   ./scripts/sh/commands/info.sh
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
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_title() { echo "=== $* ==="; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"
readonly VERSION_FILE="$PROJECT_ROOT/.version"

log_title "INFORMACIÓN DEL PROYECTO"
echo ""

# Versión del toolbox
log_info "Versión del Toolbox:"
if [[ -f "$VERSION_FILE" ]]; then
	VERSION=$(tr -d '\n' < "$VERSION_FILE" 2>/dev/null || echo "desconocida")
	log_info "  $VERSION"
else
	log_info "  (no disponible)"
fi
echo ""

# Servicios detectados
log_info "Servicios Configurados:"
if [[ -f "$ENV_FILE" ]]; then
	# Cargar helper de servicios si está disponible
	if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/services.sh"
	fi

	# Usar helper común para detectar servicios
	if command -v detect_services_from_env >/dev/null 2>&1; then
		SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")
	else
		# Fallback si helper no está disponible
		SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$ENV_FILE" 2>/dev/null | \
			sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | \
			tr '_' '-' | tr '\n' ' ' || echo "")
	fi

	if [[ -n "$SERVICES_LIST" ]]; then
		for service in $SERVICES_LIST; do
			# Usar helper común para obtener nombre de contenedor
			if command -v get_container_name >/dev/null 2>&1; then
				CONTAINER_NAME=$(get_container_name "$service")
			else
				if [[ -z "${SERVICE_PREFIX:-}" ]]; then
					CONTAINER_NAME="$service"
				else
					CONTAINER_NAME="${SERVICE_PREFIX}-${service}"
				fi
			fi

			# Usar helper común para verificar estado
			if command -v is_container_running >/dev/null 2>&1; then
				if is_container_running "$CONTAINER_NAME"; then
					STATUS="🟢 corriendo"
				else
					STATUS="🔴 detenido"
				fi
			else
				if docker ps --format '{{.Names}}' | \
					grep -q "^${CONTAINER_NAME}$"; then
					STATUS="🟢 corriendo"
				else
					STATUS="🔴 detenido"
				fi
			fi
			log_info "  • $service: $STATUS"
		done
	else
		log_info "  (ningún servicio detectado)"
	fi
else
	log_info "  (.env no encontrado)"
fi
echo ""

# Variables de entorno importantes
log_info "Variables de Entorno Importantes:"
if [[ -f "$ENV_FILE" ]]; then
	IMPORTANT_VARS="NETWORK_NAME SERVICE_PREFIX INFRASTRUCTURE_VERSION"
	for var in $IMPORTANT_VARS; do
		VALUE=$(grep -E "^${var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | sed 's/^["'\'']//;s/["'\'']$//' || echo "")
		if [[ -n "$VALUE" ]]; then
			log_info "  • $var: $VALUE"
		fi
	done
else
	log_info "  (.env no encontrado)"
fi
echo ""

# Redes Docker
log_info "Redes Docker:"
if [[ -n "${NETWORK_NAME:-}" ]]; then
	if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
		NETWORK_INFO=$(docker network inspect "$NETWORK_NAME" \
			--format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "")
		log_info "  • ${NETWORK_NAME}: ${NETWORK_INFO:-configurada}"
	else
		log_info "  • ${NETWORK_NAME}: no existe"
	fi
else
	log_info "  (NETWORK_NAME no definido)"
fi
echo ""

# Volúmenes
log_info "Volúmenes Docker:"
VOLUME_COUNT=$(docker volume ls -q 2>/dev/null | wc -l || echo "0")
log_info "  Total: $VOLUME_COUNT volúmenes"
if [[ $VOLUME_COUNT -gt 0 ]] && [[ $VOLUME_COUNT -le 10 ]]; then
	docker volume ls --format "  • {{.Name}}" 2>/dev/null || true
elif [[ $VOLUME_COUNT -gt 10 ]]; then
	docker volume ls --format "  • {{.Name}}" 2>/dev/null | head -10
	log_info "  ... y $((VOLUME_COUNT - 10)) más"
fi
echo ""

# Estado de Docker
log_info "Estado de Docker:"
if docker ps >/dev/null 2>&1; then
	RUNNING_COUNT=$(docker ps -q | wc -l || echo "0")
	TOTAL_COUNT=$(docker ps -aq | wc -l || echo "0")
	log_info "  Contenedores corriendo: $RUNNING_COUNT"
	log_info "  Contenedores totales: $TOTAL_COUNT"
else
	log_info "  Docker no disponible o no está corriendo"
fi
