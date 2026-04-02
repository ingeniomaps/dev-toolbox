#!/usr/bin/env bash
# ============================================================================
# Script: rotate-logs.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Rota logs de contenedores Docker y archivos de log del sistema eliminando
# logs antiguos. Integrado con el sistema de logging de dev-toolbox.
#
# Uso:
#   ./scripts/sh/utils/rotate-logs.sh [días] [--containers-only] [--files-only]
#
# Parámetros:
#   $1 - (opcional) Días de retención (default: 30, o desde .logging-config)
#   --containers-only - Solo rotar logs de contenedores Docker
#   --files-only      - Solo rotar archivos de log del sistema
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (opcional)
#   LOG_RETENTION_DAYS - Días de retención (default: 30)
#   LOG_DIR - Directorio de logs (default: PROJECT_ROOT/logs)
#
# Retorno:
#   0 si la rotación fue exitosa
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
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

# Cargar log-file-manager para funciones de gestión de archivos
if [[ -f "$SCRIPT_DIR/log-file-manager.sh" ]]; then
	source "$SCRIPT_DIR/log-file-manager.sh"
fi

# Parsear argumentos
RETENTION_DAYS="${1:-}"
CONTAINERS_ONLY=false
FILES_ONLY=false
SERVICE_FILTER=""

for arg in "$@"; do
	case "$arg" in
		--containers-only)
			CONTAINERS_ONLY=true
			shift
			;;
		--files-only)
			FILES_ONLY=true
			shift
			;;
		--*)
			# Ignorar otros flags
			shift
			;;
		*)
			if [[ -z "$RETENTION_DAYS" ]] && [[ "$arg" =~ ^[0-9]+$ ]]; then
				RETENTION_DAYS="$arg"
			elif [[ -z "$SERVICE_FILTER" ]]; then
				SERVICE_FILTER="$arg"
			fi
			;;
	esac
done

# Obtener configuración desde log-file-manager si está disponible
if command -v get_log_config >/dev/null 2>&1; then
	get_log_config
	RETENTION_DAYS="${RETENTION_DAYS:-$LOG_RETENTION_DAYS}"
else
	RETENTION_DAYS="${RETENTION_DAYS:-${LOG_RETENTION_DAYS:-30}}"
fi

readonly RETENTION_DAYS
readonly SERVICE_FILTER

TOTAL_ROTATED=0
TOTAL_CLEANED=0

# ============================================================================
# Rotar logs de contenedores Docker
# ============================================================================
if [[ "$FILES_ONLY" != "true" ]]; then
	log_info "1. Rotando logs de contenedores Docker..."

	# Obtener contenedores
	if [[ -n "$SERVICE_FILTER" ]]; then
		CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep -E "$SERVICE_FILTER" || true)
	else
		CONTAINERS=$(docker ps -a --format '{{.Names}}' || true)
	fi

	if [[ -n "$CONTAINERS" ]]; then
		CONTAINERS_ROTATED=0
		for container in $CONTAINERS; do
			# Verificar que el contenedor existe
			if ! docker inspect "$container" >/dev/null 2>&1; then
				continue
			fi

			# Truncar logs (Docker no tiene rotación nativa, pero podemos limpiar)
			if docker logs --since "$RETENTION_DAYS days ago" "$container" >/dev/null 2>&1; then
				log_success "  Logs de $container procesados"
				CONTAINERS_ROTATED=$((CONTAINERS_ROTATED + 1))
			else
				log_warn "  No se pudieron procesar logs de $container"
			fi
		done
		TOTAL_ROTATED=$((TOTAL_ROTATED + CONTAINERS_ROTATED))
		log_info "  $CONTAINERS_ROTATED contenedores procesados"
	else
		log_warn "  No se encontraron contenedores para rotar logs"
	fi

	# Limpiar logs del sistema Docker (solo si no es solo archivos)
	if [[ "$CONTAINERS_ONLY" != "true" ]]; then
		log_info "  Limpiando logs del sistema Docker..."
		docker system prune -f --volumes >/dev/null 2>&1 || true
	fi
fi

# ============================================================================
# Rotar archivos de log del sistema
# ============================================================================
if [[ "$CONTAINERS_ONLY" != "true" ]] && command -v cleanup_old_logs >/dev/null 2>&1; then
	log_info "2. Rotando archivos de log del sistema..."

	# Obtener directorio de logs
	log_dir=$(get_log_dir)

	if [[ -d "$log_dir" ]]; then
		# Limpiar logs antiguos
		cleaned_count=$(cleanup_old_logs "$log_dir")
		TOTAL_CLEANED=$cleaned_count

		if [[ $cleaned_count -gt 0 ]]; then
			log_success "  $cleaned_count archivos de log antiguos eliminados"
		else
			log_info "  No hay logs antiguos para limpiar"
		fi

		# Rotar logs que excedan el tamaño máximo
		rotated_count=0
		while IFS= read -r log_file; do
			[[ -z "$log_file" ]] && continue
			if rotate_log_if_needed "$log_file" 2>/dev/null; then
				rotated_count=$((rotated_count + 1))
			fi
		done < <(find "$log_dir" -type f -name "*.log" -maxdepth 1 2>/dev/null || true)

		if [[ $rotated_count -gt 0 ]]; then
			log_success "  $rotated_count archivos de log rotados por tamaño"
		fi
	else
		log_warn "  Directorio de logs no encontrado: $log_dir"
	fi
fi

# ============================================================================
# Resumen
# ============================================================================
echo ""
log_separator
if [[ $TOTAL_ROTATED -gt 0 ]] || [[ $TOTAL_CLEANED -gt 0 ]]; then
	log_success "Rotación completada:"
	log_info "  • Contenedores procesados: $TOTAL_ROTATED"
	log_info "  • Archivos de log limpiados: $TOTAL_CLEANED"
else
	log_info "Rotación completada (no se encontraron logs para rotar)"
fi

if [[ "$FILES_ONLY" != "true" ]]; then
	log_info ""
	log_info "Nota: Docker no tiene rotación nativa. Considera configurar log rotation en docker-compose.yml"
fi

log_separator
