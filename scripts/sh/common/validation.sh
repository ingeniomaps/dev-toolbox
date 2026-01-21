#!/usr/bin/env bash
# ============================================================================
# validation.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Helper común para validación de argumentos y parámetros. Proporciona funciones
# para validar argumentos de línea de comandos, variables de entorno y valores.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/validation.sh"
#   validate_required_args "$@"
#
# Funciones:
#   validate_required_args - Valida argumentos requeridos
#   validate_optional_args - Valida argumentos opcionales con tipos
#   validate_env_var - Valida que una variable de entorno esté definida
#   validate_file_exists - Valida que un archivo exista
#   validate_dir_exists - Valida que un directorio exista
#   validate_number - Valida que un valor sea numérico
#   validate_port - Valida que un puerto sea válido (1-65535)
#   validate_ip - Valida que una IP sea válida (IPv4)
#   validate_email - Valida que un email sea válido
#   validate_url - Valida que una URL sea válida
# ============================================================================

# Evitar cargar múltiples veces
if [[ -n "${VALIDATION_LOADED:-}" ]]; then
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
fi

# ============================================================================
# Funciones de Validación de Argumentos
# ============================================================================

# Valida que se hayan proporcionado los argumentos requeridos
# Parámetros:
#   $1 - Número mínimo de argumentos requeridos
#   $2 - Mensaje de uso (opcional)
#   $@ - Argumentos a validar
# Retorna: 0 si válido, 1 si inválido
validate_required_args() {
	local min_args="${1:-0}"
	shift || true
	local usage_msg="${1:-}"
	shift || true
	local arg_count=$#

	if [[ $arg_count -lt $min_args ]]; then
		log_error "Argumentos insuficientes (requeridos: $min_args, proporcionados: $arg_count)"
		if [[ -n "$usage_msg" ]]; then
			log_warn "Uso: $usage_msg"
		fi
		return 1
	fi

	return 0
}

# Valida argumentos opcionales con tipos
# Parámetros:
#   $1 - Nombre del argumento
#   $2 - Valor del argumento
#   $3 - Tipo esperado (string, number, port, ip, email, url, file, dir)
# Retorna: 0 si válido, 1 si inválido
validate_optional_args() {
	local arg_name="$1"
	local arg_value="$2"
	local arg_type="${3:-string}"

	if [[ -z "$arg_value" ]]; then
		return 0  # Argumentos opcionales pueden estar vacíos
	fi

	case "$arg_type" in
		string)
			return 0
			;;
		number)
			validate_number "$arg_value" "$arg_name"
			;;
		port)
			validate_port "$arg_value" "$arg_name"
			;;
		ip)
			validate_ip "$arg_value" "$arg_name"
			;;
		email)
			validate_email "$arg_value" "$arg_name"
			;;
		url)
			validate_url "$arg_value" "$arg_name"
			;;
		file)
			validate_file_exists "$arg_value" "$arg_name"
			;;
		dir)
			validate_dir_exists "$arg_value" "$arg_name"
			;;
		*)
			log_warn "Tipo de validación desconocido: $arg_type"
			return 0
			;;
	esac
}

# ============================================================================
# Funciones de Validación de Variables de Entorno
# ============================================================================

# Valida que una variable de entorno esté definida
# Parámetros:
#   $1 - Nombre de la variable
#   $2 - Mensaje de error opcional
#   $3 - Sugerencia de solución opcional
# Retorna: 0 si está definida, 1 si no
validate_env_var() {
	local var_name="$1"
	local error_msg="${2:-Variable $var_name no está definida}"
	local suggestion="${3:-}"
	local var_value="${!var_name:-}"

	if [[ -z "$var_value" ]]; then
		log_error "$error_msg"
		if [[ -n "$suggestion" ]]; then
			log_info "💡 Sugerencia: $suggestion"
		fi
		return 1
	fi

	return 0
}

# Valida que el archivo .env exista
# Parámetros:
#   $1 - Ruta al archivo .env (opcional, default: PROJECT_ROOT/.env)
#   $2 - Mensaje de error personalizado (opcional)
# Retorna: 0 si existe, 1 si no
validate_env_file() {
	local env_file="${1:-${PROJECT_ROOT:-$(pwd)}/.env}"
	local error_msg="${2:-}"

	if [[ ! -f "$env_file" ]]; then
		if [[ -z "$error_msg" ]]; then
			log_error "Archivo .env no encontrado: $env_file"
		else
			log_error "$error_msg"
		fi
		log_info "💡 Sugerencia: Ejecuta 'make init-env' para crear el archivo .env"
		log_info "   O crea manualmente el archivo en: $env_file"
		return 1
	fi

	return 0
}

# Valida que variables requeridas estén definidas en .env
# Parámetros:
#   $1 - Ruta al archivo .env (opcional, default: PROJECT_ROOT/.env)
#   $2 - Lista de variables requeridas separadas por espacios o comas
#   $3 - Mensaje de error personalizado (opcional)
# Retorna: 0 si todas están definidas, 1 si falta alguna
validate_env_vars_in_file() {
	local env_file="${1:-${PROJECT_ROOT:-$(pwd)}/.env}"
	local required_vars="${2:-}"
	local error_msg="${3:-}"

	# Validar que .env existe primero
	if ! validate_env_file "$env_file"; then
		return 1
	fi

	if [[ -z "$required_vars" ]]; then
		return 0  # No hay variables requeridas
	fi

	local missing_vars=""
	local IFS_OLD="$IFS"
	IFS=$' \t,'

	for var in $required_vars; do
		[[ -z "$var" ]] && continue
		if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
			missing_vars="${missing_vars} ${var}"
		fi
	done

	IFS="$IFS_OLD"

	if [[ -n "$missing_vars" ]]; then
		if [[ -z "$error_msg" ]]; then
			log_error "Variables faltantes en $env_file:${missing_vars}"
		else
			log_error "$error_msg"
		fi
		log_info "💡 Sugerencia: Agrega las variables faltantes a $env_file"
		log_info "   Ejemplo: echo 'VARIABLE=valor' >> $env_file"
		log_info "   O ejecuta 'make init-env' para crear desde plantilla"
		return 1
	fi

	return 0
}

# Valida prerrequisitos comunes (Docker, .env, etc.)
# Parámetros:
#   $1 - Lista de prerrequisitos: docker, docker-compose, env-file, env-vars
#   $2 - Variables requeridas en .env (si env-vars está en la lista)
# Retorna: 0 si todos los prerrequisitos están disponibles, 1 si falta alguno
validate_prerequisites() {
	local prerequisites="${1:-}"
	local required_vars="${2:-}"
	local env_file="${PROJECT_ROOT:-$(pwd)}/.env"
	local exit_code=0

	if [[ -z "$prerequisites" ]]; then
		return 0
	fi

	local IFS_OLD="$IFS"
	IFS=$' \t,'

	for prereq in $prerequisites; do
		case "$prereq" in
			docker)
				if ! command -v docker >/dev/null 2>&1; then
					log_error "Docker no está instalado o no está en PATH"
					log_info "💡 Sugerencia: Instala Docker desde https://docs.docker.com/get-docker/"
					exit_code=1
				fi
				;;
			docker-compose)
				if ! command -v docker-compose >/dev/null 2>&1 && \
					! docker compose version >/dev/null 2>&1; then
					log_error "Docker Compose no está instalado o no está en PATH"
					log_info "💡 Sugerencia: Instala Docker Compose desde https://docs.docker.com/compose/install/"
					exit_code=1
				fi
				;;
			env-file)
				if ! validate_env_file "$env_file"; then
					exit_code=1
				fi
				;;
			env-vars)
				if ! validate_env_vars_in_file "$env_file" "$required_vars"; then
					exit_code=1
				fi
				;;
			*)
				log_warn "Prerrequisito desconocido: $prereq"
				;;
		esac
	done

	IFS="$IFS_OLD"

	return $exit_code
}

# ============================================================================
# Funciones de Validación de Archivos y Directorios
# ============================================================================

# Valida que un archivo exista
# Parámetros:
#   $1 - Ruta al archivo
#   $2 - Nombre descriptivo (opcional)
# Retorna: 0 si existe, 1 si no
validate_file_exists() {
	local file_path="$1"
	local file_name="${2:-archivo}"

	if [[ ! -f "$file_path" ]]; then
		log_error "$file_name no encontrado: $file_path"
		return 1
	fi

	return 0
}

# Valida que un directorio exista
# Parámetros:
#   $1 - Ruta al directorio
#   $2 - Nombre descriptivo (opcional)
# Retorna: 0 si existe, 1 si no
validate_dir_exists() {
	local dir_path="$1"
	local dir_name="${2:-directorio}"

	if [[ ! -d "$dir_path" ]]; then
		log_error "$dir_name no encontrado: $dir_path"
		return 1
	fi

	return 0
}

# ============================================================================
# Funciones de Validación de Tipos de Datos
# ============================================================================

# Valida que un valor sea numérico
# Parámetros:
#   $1 - Valor a validar
#   $2 - Nombre descriptivo (opcional)
# Retorna: 0 si es numérico, 1 si no
validate_number() {
	local value="$1"
	local name="${2:-valor}"

	if ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
		log_error "$name debe ser numérico: $value"
		return 1
	fi

	return 0
}

# Valida que un puerto sea válido (1-65535)
# Parámetros:
#   $1 - Puerto a validar
#   $2 - Nombre descriptivo (opcional)
# Retorna: 0 si es válido, 1 si no
validate_port() {
	local port="$1"
	local name="${2:-puerto}"

	if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
		log_error "$name debe ser un puerto válido (1-65535): $port"
		return 1
	fi

	return 0
}

# Valida que una IP sea válida (IPv4)
#
# Algoritmo de validación:
#   1. Verifica formato básico con regex: 4 grupos de 1-3 dígitos separados por puntos
#   2. Divide la IP en octetos usando IFS
#   3. Valida que cada octeto esté en el rango válido (0-255)
#
# Ejemplo:
#   validate_ip "192.168.1.1" -> válido (retorna 0)
#   validate_ip "256.1.1.1" -> inválido (octeto > 255)
#   validate_ip "192.168.1" -> inválido (solo 3 octetos)
#   validate_ip "192.168.1.1.1" -> inválido (5 octetos)
#
# Parámetros:
#   $1 - IP a validar (ej: "192.168.1.1")
#   $2 - Nombre descriptivo (opcional, default: "IP")
# Retorna: 0 si es válida, 1 si no
validate_ip() {
	local ip="$1"
	local name="${2:-IP}"

	# Validar formato básico: 4 octetos separados por puntos
	if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		log_error "$name debe ser una IPv4 válida: $ip"
		return 1
	fi

	# Validar que cada octeto esté en rango 0-255
	# Dividir IP en octetos usando IFS
	local IFS='.'
	local -a octets
	read -ra octets <<< "$ip"
	for octet in "${octets[@]}"; do
		if [[ "$octet" -lt 0 ]] || [[ "$octet" -gt 255 ]]; then
			log_error "$name tiene octetos inválidos: $ip (octeto: $octet)"
			return 1
		fi
	done

	return 0
}

# Valida que un email sea válido
# Parámetros:
#   $1 - Email a validar
#   $2 - Nombre descriptivo (opcional)
# Retorna: 0 si es válido, 1 si no
validate_email() {
	local email="$1"
	local name="${2:-email}"

	if ! [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
		log_error "$name debe ser un email válido: $email"
		return 1
	fi

	return 0
}

# Valida que una URL sea válida
# Parámetros:
#   $1 - URL a validar
#   $2 - Nombre descriptivo (opcional)
# Retorna: 0 si es válida, 1 si no
validate_url() {
	local url="$1"
	local name="${2:-URL}"

	if ! [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
		log_error "$name debe ser una URL válida: $url"
		return 1
	fi

	return 0
}

# Marcar como cargado
VALIDATION_LOADED=1
readonly VALIDATION_LOADED
