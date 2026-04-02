#!/usr/bin/env bash
# ============================================================================
# Script: show-version.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Muestra la versión actual de la infraestructura desde .version y .env.
#
# Uso:
#   make show-version
#   ./scripts/sh/commands/show-version.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (donde está .version y .env).
#                  Make pasa $(CURDIR).
#
# Retorno:
#   0 si la versión se muestra correctamente
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

VERSION_FILE="${VERSION_FILE:-$PROJECT_ROOT/.version}"
readonly ENV_FILE="$PROJECT_ROOT/.env"

CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "1.0.0")

log_info "Versión de la infraestructura:"

if [[ -f "$VERSION_FILE" ]]; then
	log_success "Versión: $CURRENT_VERSION"
	if [[ -f "$ENV_FILE" ]]; then
		env_version=$(grep "^INFRASTRUCTURE_VERSION=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "")
		if [[ -n "$env_version" ]]; then
			log_info "En .env: $env_version"
		fi
	fi
else
	log_warn "No se encontró archivo de versión"
	log_info "Versión por defecto: 1.0.0"
fi
