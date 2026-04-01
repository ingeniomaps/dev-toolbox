#!/usr/bin/env bash
# ============================================================================
# Script: docker-compose.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Helper común para interacción con Docker Compose. Proporciona funciones para
# detectar y usar docker-compose de forma consistente.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/docker-compose.sh"
#   DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
#
# Funciones:
#   get_docker_compose_cmd - Obtiene comando de docker compose (v1 o v2)
#   docker_compose_up - Ejecuta docker compose up
#   docker_compose_down - Ejecuta docker compose down
#   docker_compose_ps - Lista contenedores de docker compose
#   docker_compose_logs - Muestra logs de docker compose
#   docker_compose_exec - Ejecuta comando en contenedor
#   docker_compose_build - Construye imágenes
#   docker_compose_pull - Descarga imágenes
#
# Retorno:
#   N/A (sourced library)
# ============================================================================

# Evitar cargar múltiples veces
if [[ -n "${DOCKER_COMPOSE_LOADED:-}" ]]; then
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
	# Fallback de log_info cuando logging.sh no está disponible
	log_info() { echo "[INFO] $*"; }
fi

# ============================================================================
# Funciones de Detección
# ============================================================================

# Detecta y retorna el comando de docker compose disponible
# Retorna: "docker compose" o "docker-compose"
get_docker_compose_cmd() {
	if docker compose version >/dev/null 2>&1; then
		echo "docker compose"
	elif command -v docker-compose >/dev/null 2>&1; then
		echo "docker-compose"
	else
		log_error "Docker Compose no encontrado (ni 'docker compose' ni 'docker-compose')"
		return 1
	fi
}

# Obtiene la versión de docker compose
# Retorna: Versión o cadena vacía si no está disponible
get_docker_compose_version() {
	local cmd
	cmd=$(get_docker_compose_cmd 2>/dev/null || echo "")

	if [[ -z "$cmd" ]]; then
		echo ""
		return 1
	fi

	if [[ "$cmd" == "docker compose" ]]; then
		docker compose version --short 2>/dev/null || echo ""
	else
		docker-compose version --short 2>/dev/null || echo ""
	fi
}

# ============================================================================
# Funciones de Operaciones Comunes
# ============================================================================

# Ejecuta docker compose up
# Parámetros:
#   $1 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $2 - Archivo compose (opcional)
#   $@ - Argumentos adicionales (opcional)
docker_compose_up() {
	local project_dir="${1:-${PROJECT_ROOT:-$(pwd)}}"
	shift || true
	local compose_file="${1:-}"
	shift || true
	local extra_args=("$@")

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi
	compose_args+=("${extra_args[@]}")

	(cd "$project_dir" && $cmd up "${compose_args[@]}")
}

# Ejecuta docker compose down
# Parámetros:
#   $1 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $2 - Archivo compose (opcional)
#   $@ - Argumentos adicionales (opcional)
docker_compose_down() {
	local project_dir="${1:-${PROJECT_ROOT:-$(pwd)}}"
	shift || true
	local compose_file="${1:-}"
	shift || true
	local extra_args=("$@")

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi
	compose_args+=("${extra_args[@]}")

	(cd "$project_dir" && $cmd down "${compose_args[@]}")
}

# Lista contenedores de docker compose
# Parámetros:
#   $1 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $2 - Archivo compose (opcional)
docker_compose_ps() {
	local project_dir="${1:-${PROJECT_ROOT:-$(pwd)}}"
	shift || true
	local compose_file="${1:-}"

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi

	(cd "$project_dir" && $cmd ps "${compose_args[@]}")
}

# Muestra logs de docker compose
# Parámetros:
#   $1 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $2 - Archivo compose (opcional)
#   $@ - Servicios específicos (opcional)
docker_compose_logs() {
	local project_dir="${1:-${PROJECT_ROOT:-$(pwd)}}"
	shift || true
	local compose_file="${1:-}"
	shift || true
	local services=("$@")

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi
	compose_args+=("${services[@]}")

	(cd "$project_dir" && $cmd logs "${compose_args[@]}")
}

# Ejecuta comando en contenedor de docker compose
# Parámetros:
#   $1 - Servicio
#   $2 - Comando a ejecutar
#   $3 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $4 - Archivo compose (opcional)
docker_compose_exec() {
	local service="$1"
	local exec_cmd="$2"
	local project_dir="${3:-${PROJECT_ROOT:-$(pwd)}}"
	local compose_file="${4:-}"

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi
	compose_args+=(exec "$service" sh -c "$exec_cmd")

	(cd "$project_dir" && $cmd "${compose_args[@]}")
}

# Construye imágenes con docker compose
# Parámetros:
#   $1 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $2 - Archivo compose (opcional)
#   $@ - Argumentos adicionales (opcional)
docker_compose_build() {
	local project_dir="${1:-${PROJECT_ROOT:-$(pwd)}}"
	shift || true
	local compose_file="${1:-}"
	shift || true
	local extra_args=("$@")

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi
	compose_args+=(build "${extra_args[@]}")

	(cd "$project_dir" && $cmd "${compose_args[@]}")
}

# Descarga imágenes con docker compose
# Parámetros:
#   $1 - Directorio del proyecto (opcional, default: PROJECT_ROOT)
#   $2 - Archivo compose (opcional)
docker_compose_pull() {
	local project_dir="${1:-${PROJECT_ROOT:-$(pwd)}}"
	shift || true
	local compose_file="${1:-}"

	local cmd
	cmd=$(get_docker_compose_cmd) || return 1

	local compose_args=()
	if [[ -n "$compose_file" ]]; then
		compose_args+=(-f "$compose_file")
	fi

	(cd "$project_dir" && $cmd pull "${compose_args[@]}")
}

# Marcar como cargado
DOCKER_COMPOSE_LOADED=1
readonly DOCKER_COMPOSE_LOADED
