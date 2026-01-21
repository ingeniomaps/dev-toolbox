#!/usr/bin/env bash
# ============================================================================
# Script: list-networks.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Lista redes Docker del proyecto.
#
# Uso:
#   ./scripts/sh/commands/list-networks.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   NETWORK_NAME - Nombre de la red principal (opcional)
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
	log_success() { echo "[SUCCESS] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

log_info "Redes Docker:"
echo ""

NETWORKS=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -v "^NETWORK$" || echo "")

if [[ -z "$NETWORKS" ]]; then
	log_info "  (ninguna red encontrada)"
	exit 0
fi

NETWORK_COUNT=0
while IFS= read -r network; do
	[[ -z "$network" ]] && continue
	NETWORK_COUNT=$((NETWORK_COUNT + 1))

	# Obtener información de la red
	DRIVER=$(docker network inspect "$network" \
		--format '{{.Driver}}' 2>/dev/null || echo "desconocido")
	SUBNET=$(docker network inspect "$network" \
		--format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "")

	# Marcar red principal si existe
	if [[ -n "${NETWORK_NAME:-}" ]] && [[ "$network" == "$NETWORK_NAME" ]]; then
		MARKER=" (principal)"
	else
		MARKER=""
	fi

	if [[ -n "$SUBNET" ]]; then
		log_info "  • $network$MARKER: $DRIVER ($SUBNET)"
	else
		log_info "  • $network$MARKER: $DRIVER"
	fi
done <<< "$NETWORKS"

echo ""
log_info "Total: $NETWORK_COUNT redes"
