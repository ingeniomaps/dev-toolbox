#!/usr/bin/env bash
# ============================================================================
# Funciones: version-utils.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Funciones utilitarias para trabajar con versiones de servicios.
# ============================================================================

# Función: Normalizar nombre de servicio (aliases)
normalize_service_name() {
	local service="$1"

	# Normalizar a minúsculas
	service=$(echo "$service" | tr '[:upper:]' '[:lower:]')

	# Aplicar aliases comunes
	case "$service" in
		postgresql) echo "postgres" ;;
		mongodb) echo "mongo" ;;
		*) echo "$service" ;;
	esac
}

# Función: Parsear versión a formato comparable (X.Y.Z)
parse_version() {
	local version="$1"

	# Remover sufijos comunes (-alpine, -slim, etc.)
	version=$(echo "$version" | sed 's/-[a-z].*//')

	# Extraer números de versión (ej: "16.1" -> "16.1.0", "8.0.0" -> "8.0.0")
	local parts
	IFS='.' read -ra parts <<< "$version"
	local major="${parts[0]:-0}"
	local minor="${parts[1]:-0}"
	local patch="${parts[2]:-0}"

	# Retornar como número para comparación (ej: 1601000 para 16.1.0)
	echo "$((major * 10000 + minor * 100 + patch))"
}

# Función: Comparar versiones (retorna: 0 si v1 < v2, 1 si v1 >= v2)
compare_versions() {
	local v1=$1
	local v2=$2

	if [[ $v1 -lt $v2 ]]; then
		return 0  # v1 < v2
	else
		return 1  # v1 >= v2
	fi
}

# Función: Obtener versión mayor (X.Y)
get_major_minor() {
	local version="$1"
	version=$(echo "$version" | sed 's/-[a-z].*//')
	local parts
	IFS='.' read -ra parts <<< "$version"
	local major="${parts[0]:-0}"
	local minor="${parts[1]:-0}"
	echo "${major}.${minor}"
}

# Función: Obtener versión mayor solo (X)
get_major() {
	local version="$1"
	version=$(echo "$version" | sed 's/-[a-z].*//')
	echo "$version" | cut -d'.' -f1
}

# Función: Verificar si jq está disponible
check_jq() {
	if ! command -v jq >/dev/null 2>&1; then
		log_warn "jq no está disponible, usando validación básica"
		return 1
	fi
	return 0
}

# Función: Cargar información del servicio desde base de datos
load_service_info() {
	local service="$1"
	local db_file="$2"

	if [[ ! -f "$db_file" ]]; then
		return 1
	fi

	if ! check_jq; then
		return 1
	fi

	# Cargar información del servicio
	local service_info
	service_info=$(jq -r ".services.${service} // empty" "$db_file" 2>/dev/null || echo "")

	if [[ -z "$service_info" ]] || [[ "$service_info" == "null" ]]; then
		return 1
	fi

	echo "$service_info"
}
