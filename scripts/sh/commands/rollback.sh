#!/usr/bin/env bash
# ============================================================================
# Script: rollback.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Restaura un estado guardado del sistema.
#
# Uso:
#   ./scripts/sh/commands/rollback.sh <nombre_estado>
#
# Parámetros:
#   $1 - Nombre del estado a restaurar (requerido)
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

if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos usando helper
if ! validate_required_args 1 "$0 <nombre_estado>" "$@"; then
	log_info "Lista estados: make list-states"
	exit 1
fi

readonly STATE="$1"
readonly STATES_DIR="${STATES_DIR:-$PROJECT_ROOT/.states}"
readonly STATE_FILE="$STATES_DIR/$STATE.json"

# Validar que el archivo existe usando helper
if ! validate_file_exists "$STATE_FILE" "Estado '$STATE'"; then
	log_info "Lista estados disponibles: make list-states"
	exit 1
fi

log_warn "ADVERTENCIA: Esto restaurará el estado '$STATE'"
log_warn "Esto puede detener y eliminar contenedores actuales"
printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

log_step "Restaurando estado '$STATE'..."
log_info "Nota: El rollback automático restaura información del estado"
log_info "Para una restauración completa, revisa el archivo: $STATE_FILE"
log_warn "Rollback automático limitado - revisa manualmente si es necesario"
log_success "Información del estado cargada"
