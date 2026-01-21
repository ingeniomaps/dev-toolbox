#!/usr/bin/env bash
# ============================================================================
# Script: export-metrics.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Exporta métricas de servicios a archivo (JSON o Prometheus).
#
# Uso:
#   ./scripts/sh/commands/export-metrics.sh [formato] [archivo_salida]
#
# Parámetros:
#   $1 - (opcional) Formato de salida: json, prometheus (default: json)
#   $2 - (opcional) Archivo de salida (default: metrics.json o metrics.prom)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   FORMAT - Formato de salida (json, prometheus)
#   OUTPUT - Archivo de salida
#   SERVICES - Lista de servicios separados por espacios (opcional)
#
# Retorno:
#   0 si la exportación fue exitosa
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

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly FORMAT="${1:-${FORMAT:-json}}"
readonly OUTPUT="${2:-${OUTPUT:-}}"
readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe si vamos a detectar servicios desde él
if [[ -z "${SERVICES:-}" ]] && [[ $# -eq 0 ]]; then
	if ! validate_env_file "$ENV_FILE"; then
		log_error "No se pueden exportar métricas sin archivo .env"
		log_info "💡 Solución: Ejecuta 'make init-env' o especifica servicios con:"
		log_info "   make export-metrics SERVICES=\"servicio1 servicio2\""
		exit 1
	fi
fi

# Determinar archivo de salida
if [[ -z "$OUTPUT" ]]; then
	if [[ "$FORMAT" == "prometheus" ]]; then
		OUTPUT_FILE="$PROJECT_ROOT/metrics.prom"
	else
		OUTPUT_FILE="$PROJECT_ROOT/metrics.json"
	fi
else
	OUTPUT_FILE="$OUTPUT"
fi

# Validar formato
if [[ "$FORMAT" != "json" ]] && [[ "$FORMAT" != "prometheus" ]]; then
	log_error "Formato no válido: $FORMAT (debe ser json o prometheus)"
	exit 1
fi

log_step "Exportando métricas a $FORMAT..."

# Detectar servicios
if command -v detect_services_from_env >/dev/null 2>&1; then
	SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")
elif [[ -n "${SERVICES:-}" ]]; then
	SERVICES_LIST="$SERVICES"
else
	SERVICES_LIST=""
fi

# Generar métricas
if [[ "$FORMAT" == "json" ]]; then
	{
		echo "{"
		echo "  \"timestamp\": \"$(date -Iseconds)\","
		echo "  \"services\": ["

		FIRST=true
		if [[ -n "$SERVICES_LIST" ]]; then
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
					IS_RUNNING=$(is_container_running "$CONTAINER_NAME" && echo "true" || echo "false")
				else
					IS_RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | \
						grep -q "^${CONTAINER_NAME}$" && echo "true" || echo "false")
				fi

				if [[ "$FIRST" == "false" ]]; then
					echo ","
				fi
				FIRST=false

				echo -n "    {"
				echo -n "\"name\": \"$service\","
				echo -n "\"container\": \"$CONTAINER_NAME\","
				echo -n "\"running\": $IS_RUNNING"
				echo -n "}"
			done
		fi

		echo ""
		echo "  ]"
		echo "}"
	} > "$OUTPUT_FILE"
else
	# Prometheus format
	{
		echo "# HELP container_running Container running status (1=running, 0=stopped)"
		echo "# TYPE container_running gauge"

		if [[ -n "$SERVICES_LIST" ]]; then
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
					IS_RUNNING=$(is_container_running "$CONTAINER_NAME" && echo "1" || echo "0")
				else
					IS_RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | \
						grep -q "^${CONTAINER_NAME}$" && echo "1" || echo "0")
				fi

				echo "container_running{service=\"$service\",container=\"$CONTAINER_NAME\"} $IS_RUNNING"
			done
		fi
	} > "$OUTPUT_FILE"
fi

log_success "Métricas exportadas a: $OUTPUT_FILE"
