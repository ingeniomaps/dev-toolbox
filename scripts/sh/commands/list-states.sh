#!/usr/bin/env bash
# ============================================================================
# Script: list-states.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Lista todos los estados guardados para rollback.
#
# Uso:
#   ./scripts/sh/commands/list-states.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   STATES_DIR - Directorio donde se guardan los estados (default: .states)
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
	log_warn() { echo "[WARN] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

readonly STATES_DIR="${STATES_DIR:-$PROJECT_ROOT/.states}"

log_info "Estados guardados:"
echo ""

if [[ -d "$STATES_DIR" ]] && [[ -n "$(ls -A "$STATES_DIR" 2>/dev/null)" ]]; then
	for state_file in "$STATES_DIR"/*.json; do
		[[ ! -f "$state_file" ]] && continue

		STATE_NAME=$(basename "$state_file" .json)
		TIMESTAMP=$(grep -o '"timestamp": "[^"]*"' "$state_file" 2>/dev/null | \
			cut -d'"' -f4 || echo "desconocido")
		log_info "• $STATE_NAME - $TIMESTAMP"
	done | sort -r
else
	log_warn "(ningún estado guardado)"
	log_info "Guarda un estado con: make save-state"
fi

echo ""
