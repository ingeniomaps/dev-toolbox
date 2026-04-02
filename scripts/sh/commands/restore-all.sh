#!/usr/bin/env bash
# ============================================================================
# Script: restore-all.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Restaura backups de todos los servicios detectados desde variables *_VERSION
# en .env.
#
# Uso:
#   ./scripts/sh/commands/restore-all.sh [backup_path] [--skip-missing]
#
# Parámetros:
#   $1 - (opcional) Ruta del backup a restaurar
#
# Opciones:
#   --skip-missing  - Continuar con otros servicios si uno no existe o falla
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   BACKUP_PATH - Ruta del backup (si no se pasa como parámetro)
#   SKIP_MISSING - true: continuar si servicios no existen (equivalente a --skip-missing)
#
# Retorno:
#   0 si todas las restauraciones fueron exitosas
#   1 si alguna restauración falló (o 0 si --skip-missing está activo)
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
BACKUP_PATH=""
for arg in "$@"; do
	case "$arg" in
		--skip-missing)
			SKIP_MISSING=true
			;;
		*)
			if [[ -z "$BACKUP_PATH" ]] && [[ "$arg" != "--skip-missing" ]]; then
				BACKUP_PATH="$arg"
			fi
			;;
	esac
done

# Usar variable de entorno si no se pasó como parámetro
if [[ -z "$BACKUP_PATH" ]]; then
	BACKUP_PATH="${BACKUP_PATH_ENV:-}"
fi

# Verificar variable de entorno
if [[ "${SKIP_MISSING_ENV:-}" == "true" ]] || [[ "${SKIP_MISSING:-}" == "true" ]]; then
	SKIP_MISSING=true
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe
if ! validate_env_file "$ENV_FILE"; then
	exit 1
fi

log_warn "ADVERTENCIA: Esto restaurará todas las bases de datos"
printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

log_step "Restaurando todas las bases de datos..."

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
	log_warn "No se encontraron servicios con *_VERSION en .env"
	exit 0
fi

EXIT_CODE=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

for service in $SERVICES_LIST; do
	# Verificar si el servicio existe
	if ! command -v service_exists >/dev/null 2>&1 || \
		! service_exists "$service" "restore" "$PROJECT_ROOT"; then
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_warn "Servicio $service no encontrado (omitido)"
			SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
			continue
		else
			log_error "Servicio $service no encontrado"
			log_info "💡 Sugerencia: Usa --skip-missing para continuar con otros servicios"
			EXIT_CODE=1
			FAILED_COUNT=$((FAILED_COUNT + 1))
			continue
		fi
	fi

	# Verificar si el comando make está disponible
	if ! make -C "$PROJECT_ROOT" -n "restore-${service}" >/dev/null 2>&1; then
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_warn "Comando restore-${service} no disponible (omitido)"
			SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
			continue
		else
			log_warn "Comando restore-${service} no disponible"
			EXIT_CODE=1
			FAILED_COUNT=$((FAILED_COUNT + 1))
			continue
		fi
	fi

	# Verificar BACKUP_PATH
	if [[ -z "$BACKUP_PATH" ]]; then
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_warn "BACKUP_PATH no especificado para $service (omitido)"
			SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
			continue
		else
			log_error "BACKUP_PATH no especificado para $service"
			log_info "💡 Sugerencia: Especifica BACKUP_PATH o usa --skip-missing"
			EXIT_CODE=1
			FAILED_COUNT=$((FAILED_COUNT + 1))
			continue
		fi
	fi

	# Intentar restauración
	log_info "Restaurando $service..."
	if make -C "$PROJECT_ROOT" "restore-${service}" BACKUP_PATH="$BACKUP_PATH" 2>&1; then
		log_success "Restauración de $service completada"
		SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
	else
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_error "Restauración de $service falló (continuando...)"
			FAILED_COUNT=$((FAILED_COUNT + 1))
		else
			log_error "Restauración de $service falló"
			EXIT_CODE=1
			FAILED_COUNT=$((FAILED_COUNT + 1))
		fi
	fi
done

echo ""
log_info "Resumen: $SUCCESS_COUNT exitosos, $FAILED_COUNT fallidos, $SKIPPED_COUNT omitidos"

if [[ $EXIT_CODE -eq 0 ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
	log_success "Restauración completada exitosamente"
	exit 0
elif [[ "$SKIP_MISSING" == "true" ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
	log_warn "Restauración completada con algunos fallos (modo --skip-missing)"
	exit 0
else
	log_error "Algunas restauraciones fallaron"
	exit 1
fi
