#!/usr/bin/env bash
# ============================================================================
# Script: check-version-compatibility.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Valida que las versiones de servicios sean compatibles con el entorno y no
# tengan problemas conocidos. Usa base de datos de versiones para validación
# exhaustiva.
#
# Uso:
#   ./scripts/sh/commands/check-version-compatibility.sh <servicio> <version>
#   ./scripts/sh/commands/check-version-compatibility.sh <servicio> <version> [--json]
#
# Parámetros:
#   $1 - Nombre del servicio (ej: postgres, mongo, redis, mysql, nginx, node, etc.)
#   $2 - Versión a verificar (ej: "16.1", "8.0.0", "7.2.0")
#   --json - Salida en formato JSON
#
# Variables de entorno:
#   VERSION_DB_PATH - Ruta al archivo de base de datos (default: config/version-compatibility.json)
#   VERSION_CHECK_STRICT - true: falla en warnings (default: false)
#
# Retorno:
#   0 si la versión es compatible
#   1 si hay incompatibilidades conocidas o problemas críticos
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script para cargar dependencias
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
if [[ -z "${PROJECT_ROOT:-}" ]]; then
	if cd "$SCRIPT_DIR/../../.." 2>/dev/null; then
		PROJECT_ROOT="$(pwd)"
	else
		PROJECT_ROOT="$(pwd)"
	fi
fi
readonly PROJECT_ROOT

# Cargar sistema de logging
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

# Cargar módulos de versión
source "$SCRIPT_DIR/version-utils.sh"
source "$SCRIPT_DIR/version-checks.sh"

# Parsear argumentos
OUTPUT_JSON=false
for arg in "$@"; do
	case "$arg" in
		--json)
			OUTPUT_JSON=true
			;;
		*)
			;;
	esac
done

# Remover --json de argumentos para procesar servicio y versión
SERVICE="${1:-}"
NEW_VERSION="${2:-}"

if [[ -z "$SERVICE" ]] || [[ -z "$NEW_VERSION" ]]; then
	log_error "Error: Debes especificar servicio y versión"
	log_info "Uso: $0 <servicio> <version> [--json]"
	log_info "Ejemplo: $0 postgres 16.1"
	exit 1
fi

# Ruta a base de datos de versiones
readonly VERSION_DB="${VERSION_DB_PATH:-$PROJECT_ROOT/config/version-compatibility.json}"

EXIT_CODE=0
declare -a ERRORS=()
declare -a WARNINGS=()
declare -a INFO=()

# Normalizar nombre de servicio
SERVICE=$(normalize_service_name "$SERVICE")

if [[ "$OUTPUT_JSON" != "true" ]]; then
	log_info "Verificando compatibilidad de $SERVICE versión $NEW_VERSION..."
fi

# Parsear versión
VERSION_NUM=$(parse_version "$NEW_VERSION")

# Cargar información del servicio desde base de datos
if [[ -f "$VERSION_DB" ]]; then
	SERVICE_INFO=$(load_service_info "$SERVICE" "$VERSION_DB")

	if [[ -n "$SERVICE_INFO" ]]; then
		# Verificaciones exhaustivas (no fallar si retornan error)
		check_too_old "$SERVICE_INFO" "$VERSION_NUM" "$NEW_VERSION" "ERRORS" || true
		check_too_new "$SERVICE_INFO" "$VERSION_NUM" "$NEW_VERSION" "WARNINGS" || true
		check_known_issues "$SERVICE_INFO" "$NEW_VERSION" "ERRORS" "WARNINGS" || true
		check_eol "$SERVICE_INFO" "$NEW_VERSION" "ERRORS" "WARNINGS" || true
		check_requirements "$SERVICE_INFO" "$NEW_VERSION" "INFO" || true
		check_recommended "$SERVICE_INFO" "$VERSION_NUM" "$NEW_VERSION" "WARNINGS" || true
	else
		# Servicio no encontrado en base de datos, usar validación genérica
		if [[ "$OUTPUT_JSON" != "true" ]]; then
			log_info "Servicio $SERVICE no tiene validación específica en la base de datos"
			log_info "Se asume que la versión $NEW_VERSION es compatible"
		fi
	fi
else
	# Base de datos no disponible, usar validación básica legacy
	if [[ "$OUTPUT_JSON" != "true" ]]; then
		log_warn "Base de datos de versiones no encontrada: $VERSION_DB"
		log_info "Usando validación básica (legacy)"
	fi

	# Validación básica legacy (mantener compatibilidad)
	case "$SERVICE" in
		postgres|postgresql)
			MAJOR_VERSION=$(get_major "$NEW_VERSION")
			if [[ "$MAJOR_VERSION" -lt 14 ]]; then
				WARNINGS+=("PostgreSQL $NEW_VERSION puede tener problemas. Se recomienda >= 14")
			fi
			;;
		mongo|mongodb)
			MAJOR_VERSION=$(get_major "$NEW_VERSION")
			if [[ "$MAJOR_VERSION" -lt 6 ]]; then
				WARNINGS+=("MongoDB $NEW_VERSION puede tener problemas. Se recomienda >= 6")
			fi
			;;
		redis)
			MAJOR_VERSION=$(get_major "$NEW_VERSION")
			if [[ "$MAJOR_VERSION" -lt 6 ]]; then
				WARNINGS+=("Redis $NEW_VERSION puede tener problemas. Se recomienda >= 6")
			fi
			;;
	esac
fi

# Determinar código de salida
if [[ ${#ERRORS[@]} -gt 0 ]]; then
	EXIT_CODE=1
elif [[ ${#WARNINGS[@]} -gt 0 ]] && [[ "${VERSION_CHECK_STRICT:-false}" == "true" ]]; then
	EXIT_CODE=1
fi

# Mostrar resultados
if [[ "$OUTPUT_JSON" == "true" ]]; then
	# Salida JSON
	if check_jq; then
		{
			echo "{"
			echo "  \"service\": \"$SERVICE\","
			echo "  \"version\": \"$NEW_VERSION\","
			echo "  \"compatible\": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false"),"
			if [[ ${#ERRORS[@]} -gt 0 ]]; then
				echo "  \"errors\": $(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .),"
			else
				echo "  \"errors\": [],"
			fi
			if [[ ${#WARNINGS[@]} -gt 0 ]]; then
				echo "  \"warnings\": $(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .),"
			else
				echo "  \"warnings\": [],"
			fi
			if [[ ${#INFO[@]} -gt 0 ]]; then
				echo "  \"info\": $(printf '%s\n' "${INFO[@]}" | jq -R . | jq -s .)"
			else
				echo "  \"info\": []"
			fi
			echo "}"
		} 2>/dev/null || echo "{\"error\": \"Failed to generate JSON output\"}"
	else
		# Fallback sin jq
		echo "{"
		echo "  \"service\": \"$SERVICE\","
		echo "  \"version\": \"$NEW_VERSION\","
		echo "  \"compatible\": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false"),"
		echo "  \"error\": \"jq not available for JSON output\""
		echo "}"
	fi
else
	# Salida legible
	if [[ ${#INFO[@]} -gt 0 ]]; then
		for msg in "${INFO[@]}"; do
			log_info "$msg"
		done
	fi

	if [[ ${#ERRORS[@]} -gt 0 ]]; then
		for msg in "${ERRORS[@]}"; do
			log_error "$msg"
		done
	fi

	if [[ ${#WARNINGS[@]} -gt 0 ]]; then
		for msg in "${WARNINGS[@]}"; do
			log_warn "$msg"
		done
	fi

	if [[ $EXIT_CODE -eq 0 ]]; then
		if [[ ${#ERRORS[@]} -eq 0 ]] && [[ ${#WARNINGS[@]} -eq 0 ]]; then
			log_success "Versión $NEW_VERSION de $SERVICE es compatible"
		else
			log_success "Versión $NEW_VERSION de $SERVICE es compatible (con advertencias)"
		fi
	else
		log_error "Versión $NEW_VERSION de $SERVICE tiene problemas de compatibilidad"
	fi
fi

exit $EXIT_CODE
