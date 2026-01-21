#!/usr/bin/env bash
# ============================================================================
# Script: prune.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Limpieza inteligente de recursos Docker no usados.
#
# Uso:
#   ./scripts/sh/commands/prune.sh [--all]
#
# Parámetros:
#   --all - (opcional) Limpieza completa (más agresiva)
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
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	log_step() { echo "[STEP] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

readonly PRUNE_ALL="${1:-}"

if [[ "$PRUNE_ALL" == "--all" ]]; then
	log_warn "ADVERTENCIA: Esto eliminará TODOS los recursos no usados"
	log_warn "Incluye contenedores detenidos, imágenes no usadas, volúmenes y redes"
else
	log_info "Limpieza de recursos no usados (segura)"
	log_info "Usa --all para limpieza completa"
fi

printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

# Limpiar contenedores detenidos
log_step "Limpiando contenedores detenidos..."
docker container prune -f >/dev/null 2>&1 || true

# Limpiar imágenes no usadas
if [[ "$PRUNE_ALL" == "--all" ]]; then
	log_step "Limpiando imágenes no usadas..."
	docker image prune -af >/dev/null 2>&1 || true
else
	log_step "Limpiando imágenes dangling..."
	docker image prune -f >/dev/null 2>&1 || true
fi

# Limpiar volúmenes huérfanos
log_step "Limpiando volúmenes huérfanos..."
docker volume prune -f >/dev/null 2>&1 || true

# Limpiar redes no usadas
log_step "Limpiando redes no usadas..."
docker network prune -f >/dev/null 2>&1 || true

# Limpieza del sistema (solo con --all)
if [[ "$PRUNE_ALL" == "--all" ]]; then
	log_step "Limpieza completa del sistema..."
	docker system prune -af --volumes >/dev/null 2>&1 || true
fi

log_success "Limpieza completada"
