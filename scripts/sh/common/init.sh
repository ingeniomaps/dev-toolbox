#!/usr/bin/env bash
# ============================================================================
# init.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Helper común para inicialización de scripts. Proporciona funciones para
# configurar rutas, cargar logging y establecer variables comunes.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/init.sh"
#   init_script
#
# Funciones:
#   init_script - Inicializa rutas y carga logging
#   get_project_root - Obtiene PROJECT_ROOT de forma consistente
#   get_common_dir - Obtiene COMMON_SCRIPTS_DIR de forma consistente
#
# Variables exportadas:
#   SCRIPT_DIR - Directorio del script actual
#   COMMON_SCRIPTS_DIR - Directorio de scripts comunes
#   PROJECT_ROOT - Raíz del proyecto (normalizada)
# ============================================================================

# Evitar cargar múltiples veces
if [[ -n "${INIT_LOADED:-}" ]]; then
	return 0
fi

# ============================================================================
# Funciones de Inicialización
# ============================================================================

# Inicializa rutas y carga logging
init_script() {
	# Determinar directorio del script
	if [[ -z "${SCRIPT_DIR:-}" ]]; then
		_script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
		readonly SCRIPT_DIR="$_script_dir"
		unset _script_dir
	fi

	# Determinar directorio de scripts comunes
	if [[ -z "${COMMON_SCRIPTS_DIR:-}" ]]; then
		readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
	fi

	# Determinar PROJECT_ROOT de forma consistente
	if [[ -z "${PROJECT_ROOT:-}" ]]; then
		local _pr
		_pr="$(pwd)"
		readonly PROJECT_ROOT="${_pr%/}"
		unset _pr
	fi
	# Si PROJECT_ROOT ya existe (readonly o no), no re-declarar.

	# Detectar OS y mostrar advertencia si es Windows nativo
	if [[ -f "$SCRIPT_DIR/../utils/detect-os.sh" ]]; then
		source "$SCRIPT_DIR/../utils/detect-os.sh" 2>/dev/null || true
		if is_windows_native 2>/dev/null; then
			log_warn() { echo "[WARN] $*" >&2; }
			log_warn "Este script requiere un entorno Unix (Linux, macOS, o WSL)"
			log_warn "Windows nativo no es compatible. Usa WSL: docs/WSL_SETUP.md"
		fi
	fi

	# Cargar logging si está disponible
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"

		# Configurar logging a archivo si está habilitado
		if [[ -n "${LOG_FILE:-}" ]] && [[ -f "$SCRIPT_DIR/../utils/log-file-manager.sh" ]]; then
			source "$SCRIPT_DIR/../utils/log-file-manager.sh" 2>/dev/null || true

			# Setup automático de archivo de log si LOG_FILE está definido
			if command -v setup_log_file >/dev/null 2>&1; then
				local script_name
				script_name=$(basename "${BASH_SOURCE[1]:-script}" .sh)
				setup_log_file "$LOG_FILE" "$script_name" >/dev/null 2>&1 || true
			fi
		fi
	else
		# Fallback básico de logging
		log_info() { echo "[INFO] $*"; }
		log_warn() { echo "[WARN] $*" >&2; }
		log_error() { echo "[ERROR] $*" >&2; }
		log_success() { echo "[SUCCESS] $*"; }
		log_step() { echo "[STEP] $*"; }
		log_title() { echo "=== $* ==="; }

		# Intentar cargar colors si está disponible
		[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && \
			source "$COMMON_SCRIPTS_DIR/colors.sh"
	fi
}

# Obtiene PROJECT_ROOT de forma consistente
get_project_root() {
	if [[ -n "${PROJECT_ROOT:-}" ]]; then
		echo "${PROJECT_ROOT%/}"
	else
		pwd
	fi
}

# Obtiene COMMON_SCRIPTS_DIR de forma consistente
get_common_dir() {
	if [[ -n "${COMMON_SCRIPTS_DIR:-}" ]]; then
		echo "$COMMON_SCRIPTS_DIR"
	else
		local script_dir
		script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
		echo "$script_dir/../common"
	fi
}

# Marcar como cargado
INIT_LOADED=1
readonly INIT_LOADED
