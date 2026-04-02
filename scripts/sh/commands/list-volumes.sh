#!/usr/bin/env bash
# ============================================================================
# Script: list-volumes.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Lista volúmenes Docker del proyecto.
#
# Uso:
#   ./scripts/sh/commands/list-volumes.sh
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
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

log_info "Volúmenes Docker:"
echo ""

VOLUMES=$(docker volume ls --format '{{.Name}}' 2>/dev/null || echo "")

if [[ -z "$VOLUMES" ]]; then
	log_info "  (ningún volumen encontrado)"
	exit 0
fi

VOLUME_COUNT=0
while IFS= read -r volume; do
	[[ -z "$volume" ]] && continue
	VOLUME_COUNT=$((VOLUME_COUNT + 1))

	# Obtener información del volumen
	SIZE=$(docker system df -v 2>/dev/null | \
		grep "$volume" | awk '{print $3}' || echo "desconocido")

	log_info "  • $volume ($SIZE)"
done <<< "$VOLUMES"

echo ""
log_info "Total: $VOLUME_COUNT volúmenes"
