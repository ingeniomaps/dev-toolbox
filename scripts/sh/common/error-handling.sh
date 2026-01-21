#!/usr/bin/env bash
# ============================================================================
# error-handling.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Helper común para manejo de errores. Proporciona funciones para manejar
# errores de forma consistente, con cleanup, retry y logging.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/error-handling.sh"
#   trap cleanup_on_exit EXIT
#
# Funciones:
#   cleanup_on_exit - Limpia recursos al salir
#   handle_error - Maneja errores con mensaje y código de salida
#   retry_command - Reintenta un comando con backoff exponencial
#   check_exit_code - Verifica código de salida y maneja errores
#   safe_exec - Ejecuta comando de forma segura con manejo de errores
#   rollback_on_error - Ejecuta rollback si hay error
# ============================================================================

# Evitar cargar múltiples veces
if [[ -n "${ERROR_HANDLING_LOADED:-}" ]]; then
	return 0
fi

# Cargar logging si está disponible
if [[ -z "${LOGGING_LOADED:-}" ]] && [[ -f "${COMMON_SCRIPTS_DIR:-}/logging.sh" ]]; then
	source "${COMMON_SCRIPTS_DIR}/logging.sh"
fi

# Fallback de logging si no está disponible
if ! command -v log_error >/dev/null 2>&1; then
	log_error() { echo "[ERROR] $*" >&2; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_info() { echo "[INFO] $*"; }
fi

# ============================================================================
# Variables Globales
# ============================================================================

# Lista de funciones de cleanup a ejecutar
CLEANUP_FUNCTIONS=()

# Código de salida del script
SCRIPT_EXIT_CODE=0

# ============================================================================
# Funciones de Cleanup
# ============================================================================

# Registra una función de cleanup
# Parámetros:
#   $1 - Función a ejecutar en cleanup
register_cleanup() {
	local cleanup_func="$1"
	CLEANUP_FUNCTIONS+=("$cleanup_func")
}

# Ejecuta todas las funciones de cleanup registradas
cleanup_on_exit() {
	local exit_code="${1:-${SCRIPT_EXIT_CODE:-0}}"

	for cleanup_func in "${CLEANUP_FUNCTIONS[@]}"; do
		if command -v "$cleanup_func" >/dev/null 2>&1; then
			"$cleanup_func" || true
		fi
	done
}

# ============================================================================
# Funciones de Manejo de Errores
# ============================================================================

# Maneja un error con mensaje y código de salida
# Parámetros:
#   $1 - Mensaje de error
#   $2 - Código de salida (default: 1)
#   $3 - Mostrar stack trace (default: false)
handle_error() {
	local error_msg="${1:-Error desconocido}"
	local exit_code="${2:-1}"
	local show_trace="${3:-false}"

	log_error "$error_msg"

	if [[ "$show_trace" == "true" ]] && [[ "${BASH_VERSION:-}" =~ ^[4-9] ]]; then
		log_info "Stack trace:"
		local frame=0
		while caller "$frame" 2>/dev/null; do
			((frame++))
		done | while read -r line func file; do
			log_info "  $file:$line in $func"
		done
	fi

	SCRIPT_EXIT_CODE=$exit_code
	cleanup_on_exit "$exit_code"
	exit "$exit_code"
}

# Verifica código de salida y maneja errores
# Parámetros:
#   $1 - Código de salida a verificar
#   $2 - Mensaje de error si falla
check_exit_code() {
	local exit_code="${1:-0}"
	local error_msg="${2:-Comando falló}"

	if [[ $exit_code -ne 0 ]]; then
		handle_error "$error_msg" "$exit_code"
	fi
}

# Ejecuta un comando de forma segura con manejo de errores
# Parámetros:
#   $@ - Comando y argumentos a ejecutar
# Retorna: Código de salida del comando
safe_exec() {
	local cmd="$1"
	shift || true
	local args=("$@")

	if ! command -v "$cmd" >/dev/null 2>&1; then
		log_error "Comando no encontrado: $cmd"
		return 1
	fi

	"$cmd" "${args[@]}"
	local exit_code=$?

	if [[ $exit_code -ne 0 ]]; then
		log_error "Comando falló: $cmd ${args[*]}"
		return $exit_code
	fi

	return 0
}

# ============================================================================
# Funciones de Retry
# ============================================================================

# Reintenta un comando con backoff exponencial
# Parámetros:
#   $1 - Número máximo de intentos
#   $2 - Comando a ejecutar
#   $@ - Argumentos del comando
# Retorna: 0 si exitoso, 1 si falla después de todos los intentos
retry_command() {
	local max_attempts="${1:-3}"
	shift || true
	local cmd="$1"
	shift || true
	local args=("$@")
	local attempt=1
	local wait_time=1

	while [[ $attempt -le $max_attempts ]]; do
		if "$cmd" "${args[@]}" >/dev/null 2>&1; then
			return 0
		fi

		if [[ $attempt -lt $max_attempts ]]; then
			log_warn "Intento $attempt/$max_attempts falló, reintentando en ${wait_time}s..."
			sleep "$wait_time"
			wait_time=$((wait_time * 2))  # Backoff exponencial
		fi

		((attempt++))
	done

	log_error "Comando falló después de $max_attempts intentos: $cmd"
	return 1
}

# ============================================================================
# Funciones de Rollback
# ============================================================================

# Ejecuta rollback si hay error
# Parámetros:
#   $1 - Función de rollback a ejecutar
#   $2 - Mensaje de rollback (opcional)
rollback_on_error() {
	local rollback_func="$1"
	local rollback_msg="${2:-Ejecutando rollback...}"

	if [[ $? -ne 0 ]]; then
		log_warn "$rollback_msg"
		if command -v "$rollback_func" >/dev/null 2>&1; then
			"$rollback_func" || true
		fi
	fi
}

# ============================================================================
# Configuración de Trap
# ============================================================================

# Configura trap para cleanup automático
setup_error_trap() {
	trap 'cleanup_on_exit $?' EXIT
	trap 'handle_error "Script interrumpido" 130' INT TERM
}

# Marcar como cargado
ERROR_HANDLING_LOADED=1
readonly ERROR_HANDLING_LOADED
