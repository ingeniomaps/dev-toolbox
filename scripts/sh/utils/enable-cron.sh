#!/usr/bin/env bash
# ============================================================================
# Script: enable-cron.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Agrega entradas de crontab desde un archivo o entrada directa.
# Útil para habilitar tareas programadas de un proyecto.
#
# Uso:
#   ./scripts/sh/utils/enable-cron.sh [archivo_cron]
#   echo "0 2 * * * /path/to/script.sh" | bash enable-cron.sh
#
# Parámetros:
#   $1 - (opcional) Archivo con entradas de cron (una por línea).
#        Si no se especifica, lee desde stdin.
#
# Variables de entorno:
#   PROJECT_ROOT - Ruta del proyecto (opcional, para logging)
#
# Ejemplo:
#   # Desde archivo
#   enable-cron.sh cron/tasks.txt
#
#   # Desde stdin
#   echo "0 2 * * * /path/script.sh" | enable-cron.sh
#
# Retorno:
#   0 si se agregaron las entradas correctamente
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

if ! command -v crontab >/dev/null 2>&1; then
	log_error "crontab no está disponible"
	exit 1
fi

TMP_CRON=$(mktemp)
trap 'rm -f "$TMP_CRON"' EXIT

# Obtener crontab actual (puede estar vacío)
crontab -l 2>/dev/null > "$TMP_CRON" || true

# Leer nuevas entradas desde archivo o stdin
if [[ -n "${1:-}" ]] && [[ -f "$1" ]]; then
	NEW_ENTRIES=$(cat "$1")
	log_info "Leyendo entradas desde: $1"
else
	if [[ -t 0 ]]; then
		log_error "Se requiere archivo como argumento o entrada desde stdin"
		log_info "Uso: $0 <archivo_cron>"
		log_info "   o: echo '0 2 * * * script.sh' | $0"
		exit 1
	fi
	NEW_ENTRIES=$(cat)
fi

# Validar que hay entradas
if [[ -z "$NEW_ENTRIES" ]]; then
	log_warn "No hay entradas de cron para agregar"
	exit 0
fi

# Agregar nuevas entradas (evitar duplicados)
while IFS= read -r entry; do
	entry=$(printf '%s' "$entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	[[ -z "$entry" ]] && continue
	[[ "$entry" =~ ^# ]] && continue

	if ! grep -Fxq "$entry" "$TMP_CRON" 2>/dev/null; then
		echo "$entry" >> "$TMP_CRON"
		log_info "Agregada: $entry"
	else
		log_warn "Ya existe: $entry"
	fi
done <<< "$NEW_ENTRIES"

# Aplicar nueva crontab
crontab "$TMP_CRON"
log_success "Crontab actualizado para: $PROJECT_ROOT"
