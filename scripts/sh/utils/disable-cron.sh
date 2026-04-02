#!/usr/bin/env bash
# ============================================================================
# Script: disable-cron.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Elimina todas las entradas de crontab que contienen una ruta específica.
# Útil para deshabilitar tareas programadas de un proyecto.
#
# Uso:
#   ./scripts/sh/utils/disable-cron.sh [ruta]
#   PROJECT_ROOT=/path/to/project bash disable-cron.sh
#
# Parámetros:
#   $1 - (opcional) Ruta del proyecto a filtrar. Si no se especifica, usa
#        PROJECT_ROOT o $(pwd).
#
# Variables de entorno:
#   PROJECT_ROOT - Ruta del proyecto (default: $(pwd))
#
# Retorno:
#   0 si se eliminaron entradas o no había ninguna
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
_pr="${PROJECT_ROOT:-${1:-$(pwd)}}"
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

if ! command -v crontab >/dev/null 2>&1; then
	log_error "crontab no está disponible"
	exit 1
fi

# Obtener crontab actual
TMP_CRON=$(mktemp)
trap 'rm -f "$TMP_CRON"' EXIT

if ! crontab -l 2>/dev/null > "$TMP_CRON"; then
	log_warn "No hay crontab configurado"
	exit 0
fi

# Filtrar líneas que contienen la ruta del proyecto
FILTERED=$(grep -v "$PROJECT_ROOT" "$TMP_CRON" || true)

# Comparar si hubo cambios
if [[ "$FILTERED" != "$(cat "$TMP_CRON")" ]]; then
	crontab <<< "$FILTERED"
	log_success "Entradas de cron eliminadas para: $PROJECT_ROOT"
else
	log_info "No se encontraron entradas de cron para: $PROJECT_ROOT"
fi
