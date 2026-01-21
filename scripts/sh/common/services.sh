#!/usr/bin/env bash
# ============================================================================
# services.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Helper común para detección y gestión de servicios. Proporciona funciones
# para detectar servicios desde .env y obtener información de contenedores.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/services.sh"
#   SERVICES_LIST=$(detect_services_from_env "$PROJECT_ROOT/.env")
#
# Funciones:
#   detect_services_from_env - Detecta servicios desde variables *_VERSION
#   get_container_name - Obtiene nombre de contenedor con prefijo
#   is_container_running - Verifica si un contenedor está corriendo
#   get_service_version - Obtiene versión de un servicio desde .env
#   service_exists - Verifica si un servicio existe (contenedor o comando make)
# ============================================================================

# Evitar cargar múltiples veces
if [[ -n "${SERVICES_LOADED:-}" ]]; then
	return 0
fi

# ============================================================================
# Funciones de Detección de Servicios
# ============================================================================

# Detecta servicios desde variables *_VERSION en .env
#
# Algoritmo:
#   1. Busca líneas que coincidan con el patrón ^[A-Z_]+_VERSION=
#   2. Extrae el nombre de la variable (antes de _VERSION)
#   3. Convierte a minúsculas y reemplaza _ por - para obtener nombre de servicio
#   4. Retorna lista separada por espacios
#
# Ejemplo:
#   .env contiene: POSTGRES_VERSION=15-alpine
#   Resultado: "postgres"
#
#   .env contiene:
#     POSTGRES_VERSION=15-alpine
#     MONGO_DB_VERSION=7.0
#   Resultado: "postgres mongo-db"
#
# Parámetros:
#   $1 - Ruta al archivo .env (default: $PROJECT_ROOT/.env)
# Retorna: Lista de servicios separados por espacios
detect_services_from_env() {
	local env_file="${1:-${PROJECT_ROOT:-$(pwd)}/.env}"

	if [[ ! -f "$env_file" ]]; then
		echo ""
		return 0
	fi

	# Buscar variables *_VERSION y extraer nombres de servicios
	grep -E '^[A-Z_]+_VERSION=' "$env_file" 2>/dev/null | \
		sed 's/_VERSION=.*//' | \
		tr '[:upper:]' '[:lower:]' | \
		tr '_' '-' | \
		tr '\n' ' ' || echo ""
}

# Obtiene nombre de contenedor con prefijo si está definido
# Parámetros:
#   $1 - Nombre del servicio
#   $2 - Prefijo opcional (default: $SERVICE_PREFIX)
# Retorna: Nombre del contenedor
get_container_name() {
	local service="$1"
	local prefix="${2:-${SERVICE_PREFIX:-}}"

	if [[ -z "$prefix" ]]; then
		echo "$service"
	else
		echo "${prefix}-${service}"
	fi
}

# Verifica si un contenedor está corriendo
# Parámetros:
#   $1 - Nombre del contenedor
# Retorna: 0 si está corriendo, 1 si no
is_container_running() {
	local container_name="$1"

	if [[ -z "$container_name" ]]; then
		return 1
	fi

	docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# Obtiene versión de un servicio desde .env
#
# Algoritmo:
#   1. Convierte nombre de servicio (ej: "postgres") a formato de variable
#      (ej: "POSTGRES") - mayúsculas y guiones a guiones bajos
#   2. Busca variable ${SERVICE}_VERSION en .env
#   3. Extrae el valor y elimina comillas si las tiene
#
# Ejemplo:
#   get_service_version "postgres" -> busca POSTGRES_VERSION
#   get_service_version "mongo-db" -> busca MONGO_DB_VERSION
#
#   .env contiene: POSTGRES_VERSION="15-alpine"
#   Resultado: "15-alpine" (sin comillas)
#
# Parámetros:
#   $1 - Nombre del servicio (ej: "postgres", "mongo-db")
#   $2 - Ruta al archivo .env (default: $PROJECT_ROOT/.env)
# Retorna: Versión del servicio o cadena vacía
get_service_version() {
	local service="$1"
	local env_file="${2:-${PROJECT_ROOT:-$(pwd)}/.env}"

	if [[ ! -f "$env_file" ]] || [[ -z "$service" ]]; then
		echo ""
		return 0
	fi

	# Convertir nombre de servicio a variable de entorno
	# Ejemplo: "postgres" -> "POSTGRES", "mongo-db" -> "MONGO_DB"
	local version_var
	version_var=$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

	# Buscar y extraer valor, eliminando comillas
	grep -E "^${version_var}_VERSION=" "$env_file" 2>/dev/null | \
		cut -d'=' -f2- | \
		sed 's/^["'\'']//;s/["'\'']$//' || echo ""
}

# Verifica si un servicio existe (tiene contenedor o comando make disponible)
#
# Algoritmo de verificación (en orden de prioridad):
#   1. Verifica si existe un contenedor Docker con el nombre del servicio
#      (corriendo o detenido)
#   2. Si se proporciona command_type, verifica si existe comando make
#      (ej: make backup-postgres, make restore-mongo)
#   3. Verifica si el servicio está definido en .env con variable *_VERSION
#
# Ejemplo:
#   service_exists "postgres" -> verifica contenedor "postgres" o "prefix-postgres"
#   service_exists "postgres" "backup" -> además verifica make backup-postgres
#   service_exists "mongo" -> verifica contenedor y variable MONGO_VERSION en .env
#
# Parámetros:
#   $1 - Nombre del servicio (ej: "postgres", "mongo-db")
#   $2 - Tipo de comando a verificar (backup, restore, up, etc.) (opcional)
#   $3 - PROJECT_ROOT para verificar comandos make (opcional)
# Retorna: 0 si existe, 1 si no
service_exists() {
	local service="$1"
	local command_type="${2:-}"
	local project_root="${3:-${PROJECT_ROOT:-$(pwd)}}"

	if [[ -z "$service" ]]; then
		return 1
	fi

	# Verificar si tiene contenedor (corriendo o detenido)
	local container_name
	container_name=$(get_container_name "$service")
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
		return 0
	fi

	# Verificar si tiene comando make disponible
	# Ejemplo: make backup-postgres, make restore-mongo
	if [[ -n "$command_type" ]] && [[ -f "$project_root/Makefile" ]] || \
		[[ -f "$project_root/makefiles/main/services.mk" ]]; then
		if make -C "$project_root" -n "${command_type}-${service}" >/dev/null 2>&1; then
			return 0
		fi
	fi

	# Verificar si está en .env con variable *_VERSION
	local env_file="${PROJECT_ROOT:-$(pwd)}/.env"
	if [[ -f "$env_file" ]]; then
		local version_var
		version_var=$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
		if grep -qE "^${version_var}_VERSION=" "$env_file" 2>/dev/null; then
			return 0
		fi
	fi

	return 1
}

# Marcar como cargado
SERVICES_LOADED=1
readonly SERVICES_LOADED
