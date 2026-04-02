#!/usr/bin/env bash
# ============================================================================
# Script: env-edit.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Abre .env en el editor por defecto del sistema.
#
# Uso:
#   ./scripts/sh/commands/env-edit.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   EDITOR - Editor a usar (default: $EDITOR o vi)
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

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe
if ! validate_env_file "$ENV_FILE"; then
	exit 1
fi

# Determinar editor
EDITOR_CMD="${EDITOR:-${VISUAL:-}}"
if [[ -z "$EDITOR_CMD" ]]; then
	# Intentar detectar editor común
	if command -v code >/dev/null 2>&1; then
		EDITOR_CMD="code"
	elif command -v nano >/dev/null 2>&1; then
		EDITOR_CMD="nano"
	elif command -v vim >/dev/null 2>&1; then
		EDITOR_CMD="vim"
	else
		EDITOR_CMD="vi"
	fi
fi

log_info "Abriendo $ENV_FILE con $EDITOR_CMD..."

# Abrir editor
exec "$EDITOR_CMD" "$ENV_FILE"
