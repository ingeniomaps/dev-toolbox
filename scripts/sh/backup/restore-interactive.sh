#!/usr/bin/env bash
# ============================================================================
# Script: restore-interactive.sh
# Ubicación: scripts/sh/backup/
# ============================================================================
# Restauración guiada interactiva de backups.
#
# Uso:
#   ./scripts/sh/backup/restore-interactive.sh [servicio]
#
# Parámetros:
#   $1 - (opcional) Servicio a restaurar (mongo, postgres, redis, etc.)
#        Si no se especifica, lista servicios disponibles.
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si la restauración fue exitosa
#   1 si hubo errores o se canceló
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

SERVICE="${1:-}"

if [[ -z "$SERVICE" ]]; then
	log_error "Debes especificar el servicio"
	log_info "Uso: $0 <servicio>"

	# Obtener servicios disponibles dinámicamente desde containers/
	if [[ -d "$PROJECT_ROOT/containers" ]]; then
		AVAILABLE_SERVICES=$(find "$PROJECT_ROOT/containers" \
			-mindepth 1 -maxdepth 1 -type d \
			-not -name common \
			-exec basename {} \; | sort | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
		if [[ -n "$AVAILABLE_SERVICES" ]]; then
			log_info "Servicios disponibles: $AVAILABLE_SERVICES"
		fi
	fi
	exit 1
fi

log_step "RESTAURACIÓN GUIADA - $SERVICE"

# Buscar backups disponibles
BACKUP_DIRS=(
	"$PROJECT_ROOT/backups"
	"$PROJECT_ROOT/containers/$SERVICE/backups"
	"$PROJECT_ROOT/containers/$SERVICE/scripts/backups"
)

BACKUPS_FOUND=()

for dir in "${BACKUP_DIRS[@]}"; do
	if [[ -d "$dir" ]]; then
		while IFS= read -r backup; do
			[[ -n "$backup" ]] && BACKUPS_FOUND+=("$backup")
		done < <(find "$dir" \
			\( -type d -name "*${SERVICE}*" -o -type f -name "*${SERVICE}*" \) \
			2>/dev/null | head -20)
	fi
done

if [[ ${#BACKUPS_FOUND[@]} -eq 0 ]]; then
	log_warn "No se encontraron backups para $SERVICE"
	log_info "Backups buscados en:"
	for dir in "${BACKUP_DIRS[@]}"; do
		echo "  - $dir"
	done
	exit 1
fi

log_info "Backups disponibles para $SERVICE:"
echo ""

# Mostrar backups con números
declare -a BACKUP_OPTIONS
INDEX=1
for backup in "${BACKUPS_FOUND[@]}"; do
	backup_name=$(basename "$backup")
	backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || echo "desconocido")
	backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "?")
	echo "  [$INDEX] $backup_name"
	echo "       Fecha: $backup_date | Tamaño: $backup_size"
	BACKUP_OPTIONS[INDEX]="$backup"
	INDEX=$((INDEX + 1))
done

echo ""
log_info "Selecciona el backup a restaurar (1-$((INDEX-1))) o 'q' para cancelar:"
read -r SELECTION

if [[ "$SELECTION" == "q" ]] || [[ "$SELECTION" == "Q" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || \
	[[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -ge $INDEX ]]; then
	log_error "Selección inválida"
	exit 1
fi

SELECTED_BACKUP="${BACKUP_OPTIONS[SELECTION]}"

log_warn "ADVERTENCIA: Esto restaurará el backup seleccionado"
log_warn "Los datos actuales pueden ser sobrescritos"
echo ""
log_info "Backup seleccionado: $(basename "$SELECTED_BACKUP")"
printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

# Ejecutar restauración según el servicio
log_info "Restaurando backup..."
BACKUP_NAME=$(basename "$SELECTED_BACKUP")

if make -n "restore-${SERVICE}" BACKUP_PATH="$BACKUP_NAME" >/dev/null 2>&1; then
	if make "restore-${SERVICE}" BACKUP_PATH="$BACKUP_NAME"; then
		log_success "Backup restaurado exitosamente"
	else
		log_error "Error al restaurar backup"
		exit 1
	fi
else
	log_error "Comando restore-${SERVICE} no disponible"
	exit 1
fi
