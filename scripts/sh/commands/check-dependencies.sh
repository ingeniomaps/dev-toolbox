#!/usr/bin/env bash
# ============================================================================
# Script: check-dependencies.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Verifica prerrequisitos del sistema (Docker, docker-compose, herramientas opcionales).
# Usa base de datos de requisitos para verificación estricta de versiones.
#
# Uso:
#   ./scripts/sh/commands/check-dependencies.sh [--strict] [--skip-optional]
#
# Opciones:
#   --strict         - Falla si versiones < mínimas requeridas (default: warnings)
#   --skip-optional  - No verifica herramientas opcionales
#
# Variables de entorno:
#   VERBOSE - true/false para mostrar información detallada (default: true)
#   PROJECT_ROOT - Raíz del proyecto (opcional)
#   REQUIREMENTS_DB - Ruta a base de datos de requisitos (default: config/system-requirements.json)
#
# Retorno:
#   0 si todas las dependencias requeridas están instaladas y cumplen versiones
#   1 si hay errores o versiones insuficientes (si --strict)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Determinar PROJECT_ROOT antes de cargar init.sh (que puede establecerlo como readonly)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
	PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || pwd)"
fi

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	# init_script puede establecer PROJECT_ROOT como readonly, así que lo hacemos después
	if [[ -z "${PROJECT_ROOT:-}" ]]; then
		PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || pwd)"
	fi
else
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
	if [[ -z "${PROJECT_ROOT:-}" ]]; then
		PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || pwd)"
	fi
fi

# Ahora sí hacerlo readonly después de init_script
readonly PROJECT_ROOT

if [[ -f "$COMMON_SCRIPTS_DIR/docker-compose.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/docker-compose.sh"
fi

if [[ -f "$COMMON_SCRIPTS_DIR/error-handling.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/error-handling.sh"
fi

# Cargar helper de verificación de versiones
if [[ -f "$SCRIPT_DIR/../utils/verify-version.sh" ]]; then
	source "$SCRIPT_DIR/../utils/verify-version.sh"
fi

readonly VERBOSE="${VERBOSE:-true}"
STRICT_MODE=false
SKIP_OPTIONAL=false

# Parsear argumentos
for arg in "$@"; do
	case "$arg" in
		--strict)
			STRICT_MODE=true
			;;
		--skip-optional)
			SKIP_OPTIONAL=true
			;;
		*)
			;;
	esac
done

# Ruta a base de datos de requisitos
readonly REQUIREMENTS_DB="${REQUIREMENTS_DB:-$PROJECT_ROOT/config/system-requirements.json}"

EXIT_CODE=0
WARNINGS=()

# Detectar OS y verificar compatibilidad
if [[ -f "$SCRIPT_DIR/../utils/detect-os.sh" ]]; then
	source "$SCRIPT_DIR/../utils/detect-os.sh"
	detect_os
else
	OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]' 2>/dev/null || echo "unknown")
	OS_NAME="$OS_TYPE"
	# IS_WSL e IS_WINDOWS no se usan aquí, se determinan mediante is_windows_native()
	# IS_WSL=false
	# IS_WINDOWS=false
fi

# Verificar si estamos en Windows nativo
if is_windows_native; then
	log_error "Este proyecto requiere un entorno Unix (Linux, macOS, o WSL)"
	log_error "Windows nativo no es compatible directamente"
	echo ""
	log_info "💡 OPCIONES:"
	log_info ""
	log_info "1. Usar WSL (Windows Subsystem for Linux) - RECOMENDADO:"
	log_info "   - Instala WSL: wsl --install"
	log_info "   - Ejecuta los comandos dentro de WSL"
	log_info "   - Ver documentación: docs/WSL_SETUP.md"
	echo ""
	exit 1
fi

# Verificar si estamos en WSL y mostrar información útil
if is_wsl; then
	if [[ "$VERBOSE" == "true" ]]; then
		wsl_info=$(get_wsl_info 2>/dev/null || echo "")
		if [[ -n "$wsl_info" ]]; then
			log_info "Ejecutando en: $wsl_info"
		else
			log_info "Ejecutando en WSL"
		fi
	fi
fi

# Función: Obtener versión de un comando
get_command_version() {
	local cmd="$1"
	local pattern="${2:-}"

	if ! command -v "$cmd" >/dev/null 2>&1; then
		return 1
	fi

	# Intentar obtener versión
	local version_output
	version_output=$($cmd --version 2>/dev/null || $cmd -v 2>/dev/null || echo "")

	if [[ -z "$version_output" ]]; then
		return 1
	fi

	# Extraer versión usando pattern o método por defecto
	if [[ -n "$pattern" ]]; then
		echo "$version_output" | grep -oP "$pattern" | head -1 || echo ""
	else
		# Método por defecto: buscar números de versión
		echo "$version_output" | grep -oE '[0-9]+\.[0-9]+(?:\.[0-9]+)?' | head -1 || echo ""
	fi
}

# Función: Verificar herramienta requerida
check_required_tool() {
	local tool_name="$1"
	local min_version="${2:-}"
	local recommended_version="${3:-}"
	local check_cmd="${4:-}"
	local version_pattern="${5:-}"
	local install_url="${6:-}"
	local description="${7:-}"

	if [[ -z "$check_cmd" ]]; then
		check_cmd="$tool_name"
	fi

	if ! command -v "$check_cmd" >/dev/null 2>&1; then
		log_error "$tool_name no está instalado"
		if [[ -n "$description" ]]; then
			log_info "  Descripción: $description"
		fi
		if [[ -n "$install_url" ]]; then
			if [[ "$install_url" =~ ^https?:// ]]; then
				log_info "  Instala desde: $install_url"
			else
				log_info "  Instala con: $install_url"
			fi
		fi
		return 1
	fi

	# Obtener versión actual
	local current_version
	current_version=$(get_command_version "$check_cmd" "$version_pattern" || echo "")

	if [[ -z "$current_version" ]]; then
		if [[ "$VERBOSE" == "true" ]]; then
			log_warn "$tool_name está instalado pero no se pudo determinar la versión"
		fi
		return 0  # Asumir que está OK si no podemos verificar
	fi

	# Verificar versión mínima si está especificada
	if [[ -n "$min_version" ]]; then
		if command -v verify_version >/dev/null 2>&1; then
			if ! verify_version "$current_version" "$min_version" "$recommended_version" 2>/dev/null; then
				local result=$?
				if [[ $result -eq 1 ]]; then
					# Versión < mínimo
					log_error "$tool_name $current_version < $min_version (mínimo requerido)"
					return 1
				elif [[ $result -eq 2 ]]; then
					# Versión < recomendada
					if [[ "$VERBOSE" == "true" ]]; then
						log_warn "$tool_name $current_version < $recommended_version (recomendado: >= $recommended_version)"
					fi
					WARNINGS+=("$tool_name versión $current_version es menor que la recomendada ($recommended_version)")
				fi
			else
				if [[ "$VERBOSE" == "true" ]]; then
					if [[ -n "$recommended_version" ]] && verify_version "$current_version" "$recommended_version" "" 2>/dev/null; then
						log_success "$tool_name $current_version >= $recommended_version (recomendado)"
					else
						log_success "$tool_name $current_version >= $min_version (mínimo)"
					fi
				fi
			fi
		else
			# Fallback a comparación simple
			if [[ "$VERBOSE" == "true" ]]; then
				log_info "$tool_name $current_version instalado"
			fi
		fi
	else
		if [[ "$VERBOSE" == "true" ]]; then
			log_success "$tool_name instalado"
		fi
	fi

	return 0
}

# Función: Verificar herramienta opcional
check_optional_tool() {
	local tool_name="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-}"
	local version_pattern="${4:-}"
	local fallback_message="${5:-}"
	local install_info="${6:-}"

	if [[ -z "$check_cmd" ]]; then
		check_cmd="$tool_name"
	fi

	if ! command -v "$check_cmd" >/dev/null 2>&1; then
		if [[ "$VERBOSE" == "true" ]]; then
			log_info "$tool_name no está instalado (opcional)"
			if [[ -n "$fallback_message" ]]; then
				log_info "  Nota: $fallback_message"
			fi
			if [[ -n "$install_info" ]]; then
				log_info "  Instala con: $install_info"
			fi
		fi
		return 1
	fi

	# Verificar versión si está especificada
	if [[ -n "$min_version" ]]; then
		local current_version
		current_version=$(get_command_version "$check_cmd" "$version_pattern" || echo "")

		if [[ -n "$current_version" ]]; then
			if command -v verify_version >/dev/null 2>&1; then
				if ! verify_version "$current_version" "$min_version" "" 2>/dev/null; then
					if [[ "$VERBOSE" == "true" ]]; then
						log_warn "$tool_name $current_version < $min_version (recomendado: >= $min_version)"
					fi
				else
					if [[ "$VERBOSE" == "true" ]]; then
						log_success "$tool_name $current_version instalado (opcional)"
					fi
				fi
			else
				if [[ "$VERBOSE" == "true" ]]; then
					log_success "$tool_name instalado (opcional)"
				fi
			fi
		fi
	else
		if [[ "$VERBOSE" == "true" ]]; then
			log_success "$tool_name instalado (opcional)"
		fi
	fi

	return 0
}

# Verificar Docker
if ! check_required_tool "Docker" "20.10.0" "24.0.0" "docker" "\\d+\\.\\d+(?:\\.\\d+)?" \
	"https://docs.docker.com/get-docker/" "Docker Engine o Docker Desktop"; then
	EXIT_CODE=1
fi

# Verificar que el daemon de Docker esté corriendo
if command -v docker >/dev/null 2>&1; then
	if command -v retry_command >/dev/null 2>&1; then
		if ! retry_command 3 docker ps >/dev/null 2>&1; then
			log_error "Docker daemon no está corriendo o no responde"
			log_info "Inicia Docker con: sudo systemctl start docker (Linux) o abre Docker Desktop"
			EXIT_CODE=1
		fi
	else
		if ! docker ps >/dev/null 2>&1; then
			log_error "Docker daemon no está corriendo"
			log_info "Inicia Docker con: sudo systemctl start docker (Linux) o abre Docker Desktop"
			EXIT_CODE=1
		fi
	fi
fi

# Verificar Docker Compose
if command -v get_docker_compose_cmd >/dev/null 2>&1; then
	DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
	if [[ "$VERBOSE" == "true" ]]; then
		if [[ "$DOCKER_COMPOSE_CMD" == "docker compose" ]]; then
			log_info "Usando Docker Compose V2 (docker compose)"
		else
			log_info "Usando Docker Compose V1 (docker-compose)"
		fi
	fi

	# Verificar versión según tipo
	if [[ "$DOCKER_COMPOSE_CMD" == "docker compose" ]]; then
		if ! check_required_tool "Docker Compose" "2.0.0" "" "docker" "compose\\s+v?\\K\\d+\\.\\d+(?:\\.\\d+)?" \
			"https://docs.docker.com/compose/install/" "Docker Compose V2"; then
			EXIT_CODE=1
		fi
	else
		if ! check_required_tool "Docker Compose" "1.29.0" "2.0.0" "docker-compose" "\\d+\\.\\d+(?:\\.\\d+)?" \
			"https://docs.docker.com/compose/install/" "Docker Compose V1 (considerar actualizar a V2)"; then
			EXIT_CODE=1
		fi
	fi
else
	# Fallback manual
	if docker compose version >/dev/null 2>&1; then
		if [[ "$VERBOSE" == "true" ]]; then
			log_info "Usando Docker Compose V2 (docker compose)"
		fi
		if ! check_required_tool "Docker Compose" "2.0.0" "" "docker" "compose\\s+v?\\K\\d+\\.\\d+(?:\\.\\d+)?" \
			"https://docs.docker.com/compose/install/" "Docker Compose V2"; then
			EXIT_CODE=1
		fi
	elif command -v docker-compose >/dev/null 2>&1; then
		if [[ "$VERBOSE" == "true" ]]; then
			log_info "Usando Docker Compose V1 (docker-compose)"
		fi
		if ! check_required_tool "Docker Compose" "1.29.0" "2.0.0" "docker-compose" "\\d+\\.\\d+(?:\\.\\d+)?" \
			"https://docs.docker.com/compose/install/" "Docker Compose V1 (considerar actualizar a V2)"; then
			EXIT_CODE=1
		fi
	else
		log_error "docker-compose no está instalado"
		log_info "Instala docker-compose o usa Docker Compose V2 (docker compose)"
		EXIT_CODE=1
	fi
fi

# Verificar herramientas requeridas básicas
check_required_tool "Bash" "4.0.0" "" "bash" "version\\s+(\\d+\\.\\d+)" "" "Bash shell" || EXIT_CODE=1
check_required_tool "Make" "4.0.0" "" "make" "GNU Make (\\d+\\.\\d+)" \
	"https://www.gnu.org/software/make/" "GNU Make" || EXIT_CODE=1

# Verificar herramientas opcionales (con fallbacks)
if [[ "$SKIP_OPTIONAL" != "true" ]]; then
	if [[ "$VERBOSE" == "true" ]]; then
		echo ""
		log_info "Verificando herramientas opcionales..."
	fi

	# jq (opcional, pero recomendado para funcionalidades avanzadas)
	jq_install=""
	case "$OS_NAME" in
		linux|ubuntu|debian)
			jq_install="sudo apt install jq"
			;;
		macos|darwin)
			jq_install="brew install jq"
			;;
		*)
			jq_install="https://stedolan.github.io/jq/download/"
			;;
	esac

	check_optional_tool "jq" "1.6.0" "jq" "jq-(\\d+\\.\\d+(?:\\.\\d+)?)" \
		"Algunas funcionalidades avanzadas no estarán disponibles sin jq" "$jq_install" || true

	# curl (opcional)
	curl_install=""
	case "$OS_NAME" in
		linux|ubuntu|debian)
			curl_install="sudo apt install curl"
			;;
		macos|darwin)
			curl_install="brew install curl"
			;;
		*)
			curl_install="Ver documentación del sistema"
			;;
	esac

	check_optional_tool "curl" "7.0.0" "curl" "curl (\\d+\\.\\d+(?:\\.\\d+)?)" \
		"Algunas operaciones de red pueden no funcionar sin curl" "$curl_install" || true

	# Infisical (opcional, con fallback a .env)
	check_optional_tool "Infisical" "" "infisical" "" \
		"Sin Infisical, se usarán variables de entorno desde .env" \
		"https://infisical.com/docs/cli/installation" || true
fi

# Mostrar resumen de warnings
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
	echo ""
	if [[ "$VERBOSE" == "true" ]]; then
		log_info "Advertencias:"
		for warning in "${WARNINGS[@]}"; do
			log_warn "  - $warning"
		done
	fi
fi

# Resumen final
echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todas las dependencias requeridas están instaladas"
	if [[ "$STRICT_MODE" == "true" ]] && [[ ${#WARNINGS[@]} -gt 0 ]]; then
		log_warn "Modo estricto: algunas versiones no cumplen recomendaciones"
		exit 1
	fi
	exit 0
else
	log_error "Algunas dependencias requeridas faltan o tienen versiones insuficientes"
	if [[ "$STRICT_MODE" == "true" ]]; then
		log_error "Modo estricto activado: fallando por versiones insuficientes"
		exit 1
	else
		log_info "Sugerencia: ejecuta con --strict para fallar en versiones insuficientes"
		exit 1
	fi
fi
