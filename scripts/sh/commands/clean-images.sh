#!/usr/bin/env bash
# ============================================================================
# Script: clean-images.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Elimina imágenes Docker no usadas.
#
# Uso:
#   ./scripts/sh/commands/clean-images.sh [--dangling]
#
# Parámetros:
#   --dangling - (opcional) Solo eliminar imágenes dangling (sin tag)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si la limpieza fue exitosa
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

readonly CLEAN_DANGLING="${1:-}"

if [[ "$CLEAN_DANGLING" == "--dangling" ]]; then
	log_info "Eliminando solo imágenes dangling (sin tag)..."
else
	log_warn "ADVERTENCIA: Esto eliminará todas las imágenes no usadas"
	printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
	read -r CONFIRM

	if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
		log_info "Operación cancelada"
		exit 0
	fi
fi

log_step "Limpiando imágenes Docker..."

if [[ "$CLEAN_DANGLING" == "--dangling" ]]; then
	if docker image prune -f >/dev/null 2>&1; then
		log_success "Imágenes dangling eliminadas"
	else
		log_error "Falló al eliminar imágenes dangling"
		exit 1
	fi
else
	if docker image prune -af >/dev/null 2>&1; then
		log_success "Imágenes no usadas eliminadas"
	else
		log_error "Falló al eliminar imágenes"
		exit 1
	fi
fi

log_success "Limpieza de imágenes completada"
