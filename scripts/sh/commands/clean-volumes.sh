#!/usr/bin/env bash
# ============================================================================
# Script: clean-volumes.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Elimina volúmenes Docker específicos o todos los no usados.
#
# Uso:
#   ./scripts/sh/commands/clean-volumes.sh [vol1 vol2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de volúmenes a eliminar. Si no se especifica,
#        elimina todos los volúmenes no usados
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   VOLUMES - Lista de volúmenes separados por espacios (opcional)
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

readonly VOLUMES_LIST="${*:-${VOLUMES:-}}"

log_warn "ADVERTENCIA: Esto eliminará volúmenes Docker"
if [[ -n "$VOLUMES_LIST" ]]; then
	log_info "Volúmenes a eliminar: $VOLUMES_LIST"
else
	log_info "Se eliminarán todos los volúmenes no usados"
fi

printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

if [[ -n "$VOLUMES_LIST" ]]; then
	# Eliminar volúmenes específicos
	log_step "Eliminando volúmenes específicos..."
	for volume in $VOLUMES_LIST; do
		if docker volume inspect "$volume" >/dev/null 2>&1; then
			log_info "Eliminando volumen: $volume"
			if docker volume rm "$volume" >/dev/null 2>&1; then
				log_success "Volumen $volume eliminado"
			else
				log_warn "No se pudo eliminar volumen $volume (puede estar en uso)"
			fi
		else
			log_warn "Volumen $volume no existe"
		fi
	done
else
	# Eliminar todos los volúmenes no usados
	log_step "Eliminando volúmenes no usados..."
	if docker volume prune -f >/dev/null 2>&1; then
		log_success "Volúmenes no usados eliminados"
	else
		log_error "Falló al eliminar volúmenes"
		exit 1
	fi
fi

log_success "Limpieza de volúmenes completada"
