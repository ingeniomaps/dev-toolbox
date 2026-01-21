#!/usr/bin/env bash
# ============================================================================
# Script: rebuild.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Reconstruye y reinicia servicios (combina build + restart).
#
# Uso:
#   ./scripts/sh/commands/rebuild.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios a reconstruir. Si no se especifica,
#        reconstruye el servicio especificado en SERVICE
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICE - Nombre del servicio a reconstruir (requerido si no hay parámetros)
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   BUILD_ARGS - Argumentos adicionales para docker build (opcional)
#
# Retorno:
#   0 si todas las reconstrucciones fueron exitosas
#   1 si alguna reconstrucción falló
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

# Determinar servicios a reconstruir
if [[ $# -gt 0 ]]; then
	SERVICES_LIST="$*"
elif [[ -n "${SERVICES:-}" ]]; then
	SERVICES_LIST="$SERVICES"
elif [[ -n "${SERVICE:-}" ]]; then
	SERVICES_LIST="$SERVICE"
else
	log_error "Debes especificar SERVICE o pasar servicios como parámetros"
	log_info "Uso: $0 <servicio> o make rebuild SERVICE=<servicio>"
	exit 1
fi

log_step "Reconstruyendo servicios..."

EXIT_CODE=0
for service in $SERVICES_LIST; do
	log_info "Reconstruyendo $service..."

	# 1. Construir
	if ! make -C "$PROJECT_ROOT" build SERVICES="$service" \
		BUILD_ARGS="${BUILD_ARGS:-}" >/dev/null 2>&1; then
		log_error "Falló al construir $service"
		EXIT_CODE=1
		continue
	fi

	# 2. Reiniciar
	if ! make -C "$PROJECT_ROOT" restart SERVICE="$service" >/dev/null 2>&1; then
		log_error "Falló al reiniciar $service"
		EXIT_CODE=1
		continue
	fi

	log_success "$service reconstruido y reiniciado correctamente"
done

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todos los servicios reconstruidos correctamente"
	exit 0
else
	log_error "Algunas reconstrucciones fallaron"
	exit 1
fi
