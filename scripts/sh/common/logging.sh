#!/usr/bin/env bash
# ============================================================================
# Script: logging.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Sistema de logging con niveles, marcas de tiempo, colores, verbosidad y
# opcionalmente salida a archivo. Carga colors.sh si está en el mismo directorio.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/logging.sh"
#   # COMMON_SCRIPTS_DIR = ruta a scripts/sh/common (ej. SCRIPT_DIR/../common)
#
# Variables de configuración (opcionales, antes de source):
#   LOG_LEVEL     - Nivel mínimo: DEBUG, INFO, SUCCESS, WARN, ERROR (default: INFO)
#   VERBOSE       - true/false (default: true)
#   LOG_TIMESTAMP - true/false, marcas de tiempo (default: false)
#   LOG_FILE      - Ruta a archivo para logging (opcional)
#   LOG_INDENT    - Indentación (opcional)
#
# Funciones: log_debug, log_info, log_success, log_warn, log_error, log_note,
#   log_step, log_separator, log_title, log_cmd, log_blank, error_exit,
#   check_command, usage, log_show_config. Aliases: error, warn, success, info.
#
# NOTAS:
#   - Requiere colors.sh (se carga desde el mismo directorio si existe).
#   - Carga segura múltiples veces (LOGGING_LOADED).
#
# Retorno:
#   N/A (sourced library)
# ============================================================================

# Evitar cargar múltiples veces
if [[ -n "${LOGGING_LOADED:-}" ]]; then
	return 0
fi

# Determinar directorio del script
if [[ -z "${LOGGING_DIR:-}" ]]; then
	_logging_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	readonly LOGGING_DIR="$_logging_dir"
	unset _logging_dir
else
	readonly LOGGING_DIR
fi

# Cargar colors.sh si está disponible
if [[ -z "${COLORS_LOADED:-}" ]] && [[ -f "$LOGGING_DIR/colors.sh" ]]; then
	source "$LOGGING_DIR/colors.sh"
fi

# Cargar log-file-manager.sh si está disponible (para rotación automática)
if [[ -f "$LOGGING_DIR/../utils/log-file-manager.sh" ]]; then
	source "$LOGGING_DIR/../utils/log-file-manager.sh" 2>/dev/null || true

	# Inicializar rotación si LOG_FILE está configurado
	if [[ -n "${LOG_FILE:-}" ]] && [[ "${LOG_ROTATE_ON_INIT:-true}" == "true" ]]; then
		init_log_rotation 2>/dev/null || true
	fi
fi

# ============================================================================
# Configuración del Sistema de Logging
# ============================================================================

# Nivel de logging (DEBUG, INFO, SUCCESS, WARN, ERROR)
# Puede ser sobrescrito desde variables de entorno
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Control de verbosidad general
VERBOSE="${VERBOSE:-true}"

# Habilitar marcas de tiempo en los logs
LOG_TIMESTAMP="${LOG_TIMESTAMP:-false}"

# Archivo de log (opcional, si está definido, los logs se escriben también ahí)
LOG_FILE="${LOG_FILE:-}"

# Indentación base (puede ser modificada para logs anidados)
LOG_INDENT="${LOG_INDENT:-}"

# Configuración de rotación de logs (si está disponible)
# LOG_MAX_SIZE_MB está reservado para uso futuro en rotación de logs
# LOG_MAX_SIZE_MB="${LOG_MAX_SIZE:-10}"
LOG_ROTATE_ON_INIT="${LOG_ROTATE_ON_INIT:-true}"

# Prefijos para cada nivel
readonly LOG_PREFIX_DEBUG='[DEBUG]'
readonly LOG_PREFIX_INFO='[INFO]'
readonly LOG_PREFIX_SUCCESS='[SUCCESS]'
readonly LOG_PREFIX_WARN='[WARN]'
readonly LOG_PREFIX_ERROR='[ERROR]'
readonly LOG_PREFIX_NOTE='[NOTE]'
readonly LOG_PREFIX_STEP='[STEP]'

# Prioridades de niveles (mayor número = mayor prioridad)
# LOG_PRIORITY array no se usa actualmente (se usa case en _get_current_priority)
# declare -A LOG_PRIORITY
# LOG_PRIORITY[DEBUG]=0
# LOG_PRIORITY[INFO]=1
# LOG_PRIORITY[SUCCESS]=2
# LOG_PRIORITY[WARN]=3
# LOG_PRIORITY[ERROR]=4

# Prioridad actual basada en LOG_LEVEL (función temporal para obtener valor)
_get_current_priority() {
	local level="${LOG_LEVEL:-INFO}"
	case "$level" in
		DEBUG)   echo "0" ;;
		INFO)    echo "1" ;;
		SUCCESS) echo "2" ;;
		WARN)    echo "3" ;;
		ERROR)   echo "4" ;;
		*)       echo "1" ;;  # Default
	esac
}
LOG_CURRENT_PRIORITY=$(_get_current_priority)

# ============================================================================
# Funciones auxiliares internas
# ============================================================================

# Obtener marca de tiempo en formato [YYYY-MM-DD HH:MM:SS]
_get_timestamp() {
	if [[ "${LOG_TIMESTAMP}" == "true" ]]; then
		date '+[%Y-%m-%d %H:%M:%S]'
	fi
}

# Obtener prioridad de un nivel de forma segura (compatible con set -u)
_get_level_priority() {
	local level="${1:-INFO}"
	# Acceso seguro al array asociativo
	case "$level" in
		DEBUG)   echo "0" ;;
		INFO)    echo "1" ;;
		SUCCESS) echo "2" ;;
		WARN)    echo "3" ;;
		ERROR)   echo "4" ;;
		*)       echo "1" ;;  # Default
	esac
}

# Verificar si un nivel debe mostrarse
_should_log() {
	local level="$1"
	if [[ "${VERBOSE}" != "true" ]]; then
		return 1
	fi
	local level_priority
	level_priority=$(_get_level_priority "$level")
	[[ $level_priority -ge $LOG_CURRENT_PRIORITY ]]
}

# Función interna para escribir log
_write_log() {
	local prefix="$1"
	local color="$2"
	local message="$3"
	local output_stream="${4:-1}"  # 1=stdout, 2=stderr
	local timestamp
	timestamp=$(_get_timestamp)
	local output_line="${LOG_INDENT}${timestamp}${prefix} ${message}"
	local colored_output

	# Formatear con colores si están disponibles
	if [[ -n "${color:-}" ]] && [[ -n "${COLOR_RESET:-}" ]]; then
		colored_output="${color}${prefix}${COLOR_RESET} ${message}"
		output_line="${LOG_INDENT}${timestamp}${colored_output}"
	fi

	# Escribir a stdout/stderr
	if [[ $output_stream -eq 2 ]]; then
		echo -e "$output_line" >&2
	else
		echo -e "$output_line"
	fi

	# Escribir a archivo si está configurado (sin colores)
	if [[ -n "$LOG_FILE" ]]; then
		# Rotar si es necesario antes de escribir (verificación periódica)
		# Usar contador estático para no verificar en cada línea
		if [[ -z "${_LOG_LINE_COUNT:-}" ]]; then
			_LOG_LINE_COUNT=0
		fi
		_LOG_LINE_COUNT=$((_LOG_LINE_COUNT + 1))

		# Verificar rotación cada 100 líneas (para eficiencia)
		if [[ $((_LOG_LINE_COUNT % 100)) -eq 0 ]] && command -v rotate_log_if_needed >/dev/null 2>&1; then
			rotate_log_if_needed "$LOG_FILE" 2>/dev/null || true
		fi

		local file_line="${LOG_INDENT}${timestamp}${prefix} ${message}"
		# Intentar escribir, si falla crear directorio e intentar de nuevo
		if ! echo "$file_line" >> "$LOG_FILE" 2>/dev/null; then
			# Crear directorio si no existe
			local log_dir
			log_dir=$(dirname "$LOG_FILE")
			mkdir -p "$log_dir" 2>/dev/null || true
			# Intentar escribir de nuevo
			echo "$file_line" >> "$LOG_FILE" 2>/dev/null || true
		fi
	fi
}

# ============================================================================
# Funciones de Logging por Nivel
# ============================================================================

# Log DEBUG - Mensajes detallados para depuración
log_debug() {
	if _should_log "DEBUG"; then
		_write_log "$LOG_PREFIX_DEBUG" "${COLOR_BRIGHT_BLACK:-}" "${*:-}" 1
	fi
}

# Log INFO - Mensajes informativos generales
log_info() {
	if _should_log "INFO"; then
		_write_log "$LOG_PREFIX_INFO" "${COLOR_BRIGHT_BLUE:-}" "${*:-}" 1
	fi
}

# Log SUCCESS - Mensajes de éxito y operaciones completadas
log_success() {
	if _should_log "SUCCESS"; then
		_write_log "$LOG_PREFIX_SUCCESS" "${COLOR_BRIGHT_GREEN:-}" "${*:-}" 1
	fi
}

# Log WARN - Mensajes de advertencia
log_warn() {
	if [[ "${VERBOSE}" == "true" ]]; then
		_write_log "$LOG_PREFIX_WARN" "${COLOR_BRIGHT_YELLOW:-}" "${*:-}" 2
	fi
}

# Log ERROR - Mensajes de error (siempre visibles si VERBOSE=true)
log_error() {
	if [[ "${VERBOSE}" == "true" ]]; then
		_write_log "$LOG_PREFIX_ERROR" "${COLOR_BRIGHT_RED:-}" "${*:-}" 2
	fi
}

# Log NOTE - Notas y mensajes neutrales
log_note() {
	if _should_log "INFO"; then
		_write_log "$LOG_PREFIX_NOTE" "${COLOR_BRIGHT_WHITE:-}" "${*:-}" 1
	fi
}

# Log STEP - Pasos y secciones (formato especial)
log_step() {
	if _should_log "INFO"; then
		_write_log "$LOG_PREFIX_STEP" "${COLOR_BRIGHT_CYAN:-}" "${*:-}" 1
	fi
}

# ============================================================================
# Funciones de Formato Especial
# ============================================================================

# Separador visual para secciones
log_separator() {
	if [[ "${VERBOSE}" == "true" ]]; then
		local separator
		separator=$(printf '=%.0s' {1..80})
		if [[ -n "${COLOR_BRIGHT_BLACK:-}" ]]; then
			echo -e "${COLOR_BRIGHT_BLACK}${separator}${COLOR_RESET}"
		else
			echo "$separator"
		fi
	fi
}

# Título de sección
log_title() {
	local title="${*:-Sección}"
	if [[ "${VERBOSE}" == "true" ]]; then
		local separator
		separator=$(printf '=%.0s' {1..80})
		echo ""
		if [[ -n "${COLOR_BRIGHT_CYAN:-}" ]]; then
			echo -e "${COLOR_BRIGHT_CYAN}${separator}${COLOR_RESET}"
			echo -e "${COLOR_BRIGHT_CYAN}${LOG_PREFIX_STEP} ${COLOR_BRIGHT_WHITE:-}${title}${COLOR_RESET}"
			echo -e "${COLOR_BRIGHT_CYAN}${separator}${COLOR_RESET}"
		else
			echo "$separator"
			echo "${LOG_PREFIX_STEP} ${title}"
			echo "$separator"
		fi
		echo ""
	fi
}

# Mensaje con formato de comando ejecutándose
log_cmd() {
	local cmd="${*:-}"
	if _should_log "INFO"; then
		local output="${LOG_INDENT}> $cmd"
		if [[ -n "${COLOR_CYAN:-}" ]]; then
			echo -e "${COLOR_BRIGHT_BLACK:-}> ${COLOR_CYAN}${cmd}${COLOR_RESET}"
		else
			echo "$output"
		fi
	fi
}

# Mensaje vacío (línea en blanco)
log_blank() {
	if [[ "${VERBOSE}" == "true" ]]; then
		echo ""
	fi
}

# ============================================================================
# Funciones de Utilidad y Error Handling
# ============================================================================

# Mostrar error y salir
error_exit() {
	local message="${1:-Error desconocido}"
	local exit_code="${2:-1}"
	log_error "$message"
	exit "$exit_code"
}

# Validar que un comando existe
check_command() {
	local cmd="${1:-}"
	if [[ -z "$cmd" ]]; then
		error_exit "check_command: se requiere el nombre del comando"
	fi

	if ! command -v "$cmd" >/dev/null 2>&1; then
		error_exit "Comando '$cmd' no encontrado. Por favor, instálalo primero."
	fi
}

# Mostrar uso de un script
usage() {
	# script_name no se usa actualmente en esta función
	# local script_name="${1:-script}"
	local usage_text="${2:-}"
	local examples="${3:-}"

	log_error "Uso incorrecto"

	if [[ -n "$usage_text" ]]; then
		log_info "Uso: ${usage_text}"
	fi

	if [[ -n "$examples" ]]; then
		log_info "Ejemplos:"
		local indented="  ${examples//$'\n'/$'\n'  }"
		echo "$indented" >&2
	fi
}

# ============================================================================
# Aliases para Compatibilidad
# ============================================================================

# Aliases compatibles con funciones comunes de error-handling
error() { log_error "$@"; }
warn() { log_warn "$@"; }
success() { log_success "$@"; }
# Alias de log_info para compatibilidad
info() { log_info "$@"; }

# ============================================================================
# Mostrar Configuración del Logger
# ============================================================================

log_show_config() {
	log_info "=== Configuración del Sistema de Logging ==="
	log_info "  Nivel de Log:    ${LOG_LEVEL}"
	log_info "  Verboso:         ${VERBOSE}"
	log_info "  Marcas de tiempo: ${LOG_TIMESTAMP}"
	log_info "  Prioridad Actual: ${LOG_CURRENT_PRIORITY}"
	[[ -n "$LOG_FILE" ]] && log_info "  Archivo de Log:   ${LOG_FILE}"
}

# Marcar como cargado (no exportar: los hijos deben cargar de nuevo para tener las funciones)
LOGGING_LOADED=1
readonly LOGGING_LOADED
