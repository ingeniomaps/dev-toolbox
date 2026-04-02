#!/usr/bin/env bash
# ============================================================================
# Script: clean.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Limpieza completa: detiene contenedores, elimina volúmenes huérfanos y redes.
#
# Uso:
#   ./scripts/sh/commands/clean.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   NETWORK_NAME - Nombre de la red Docker a eliminar (opcional)
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

readonly ENV_FILE="$PROJECT_ROOT/.env"

log_warn "ADVERTENCIA: Esto eliminará contenedores, volúmenes y datos"
printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

log_step "Deteniendo servicios..."

# Detectar servicios desde variables *_VERSION en .env
if [[ -f "$ENV_FILE" ]]; then
	SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$ENV_FILE" 2>/dev/null | \
		sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr '\n' ' ' || echo "")

	for service in $SERVICES_LIST; do
		if make -C "$PROJECT_ROOT" -n "down-${service}" >/dev/null 2>&1; then
			make -C "$PROJECT_ROOT" "down-${service}" 2>/dev/null || true
		fi
	done
fi

log_step "Eliminando volúmenes huérfanos..."
docker volume prune -f >/dev/null 2>&1 || true

log_step "Limpiando redes Docker..."
if [[ -n "${NETWORK_NAME:-}" ]] && docker network ls --format '{{.Name}}' | \
	grep -q "^${NETWORK_NAME}$"; then
	docker network rm "$NETWORK_NAME" 2>/dev/null || true
fi

log_success "Limpieza completada"
