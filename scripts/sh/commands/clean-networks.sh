#!/usr/bin/env bash
# ============================================================================
# Script: clean-networks.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Elimina redes Docker no usadas.
#
# Uso:
#   ./scripts/sh/commands/clean-networks.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   NETWORK_NAME - Nombre de la red principal (no se eliminará si está definida)
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

log_warn "ADVERTENCIA: Esto eliminará redes Docker no usadas"
if [[ -n "${NETWORK_NAME:-}" ]]; then
	log_info "La red '${NETWORK_NAME}' no se eliminará si está en uso"
fi

printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

log_step "Limpiando redes Docker no usadas..."

# Eliminar redes no usadas (excepto las predeterminadas de Docker)
if docker network prune -f >/dev/null 2>&1; then
	log_success "Redes no usadas eliminadas"
else
	log_error "Falló al eliminar redes"
	exit 1
fi

log_success "Limpieza de redes completada"
