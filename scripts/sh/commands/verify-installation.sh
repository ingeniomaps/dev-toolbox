#!/usr/bin/env bash
# ============================================================================
# Script: verify-installation.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Script de verificación post-instalación.
# Verifica que todo esté correctamente configurado después de la instalación.
#
# Uso:
#   ./scripts/sh/commands/verify-installation.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si todo está correcto
#   1 si hay problemas
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

EXIT_CODE=0

log_info "Verificación post-instalación..."
echo ""

# Verificar estructura de directorios
log_info "Verificando estructura de directorios..."
readonly REQUIRED_DIRS=("containers" "scripts" "makefiles")
for dir in "${REQUIRED_DIRS[@]}"; do
	if [[ -d "$PROJECT_ROOT/$dir" ]]; then
		log_success "Directorio $dir existe"
	else
		log_error "Directorio $dir no existe"
		EXIT_CODE=1
	fi
done
echo ""

# Verificar archivos esenciales
log_info "Verificando archivos esenciales..."
readonly REQUIRED_FILES=("Makefile" ".env-template")
for file in "${REQUIRED_FILES[@]}"; do
	if [[ -f "$PROJECT_ROOT/$file" ]]; then
		log_success "Archivo $file existe"
	else
		log_error "Archivo $file no existe"
		EXIT_CODE=1
	fi
done
echo ""

# Verificar scripts esenciales
log_info "Verificando scripts esenciales..."
readonly REQUIRED_SCRIPTS=("utils/wait-for-service.sh" "utils/ensure-network.sh")
for script in "${REQUIRED_SCRIPTS[@]}"; do
	script_path="$PROJECT_ROOT/scripts/sh/$script"
	if [[ -f "$script_path" ]] && [[ -x "$script_path" ]]; then
		log_success "Script $script existe y es ejecutable"
	else
		log_error "Script $script no existe o no es ejecutable"
		EXIT_CODE=1
	fi
done
echo ""

# Verificar que el Makefile funciona
log_info "Verificando que el Makefile funciona..."
if (cd "$PROJECT_ROOT" && make -n help-toolbox >/dev/null 2>&1); then
	log_success "Makefile es válido"
else
	log_error "Makefile tiene errores de sintaxis"
	EXIT_CODE=1
fi
echo ""

# Verificar Docker
log_info "Verificando Docker..."
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
	log_success "Docker está instalado y corriendo"
else
	log_error "Docker no está instalado o no está corriendo"
	EXIT_CODE=1
fi
echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Verificación post-instalación completada exitosamente"
	exit 0
else
	log_error "Algunas verificaciones fallaron"
	exit 1
fi
