#!/usr/bin/env bash
# ============================================================================
# Script: verify-version.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Verifica que una versión cumple con los requisitos mínimos.
#
# Uso:
#   verify_version <version_actual> <version_minima> [version_recomendada]
#
# Retorno:
#   0 si la versión cumple con los requisitos
#   1 si la versión es menor que el mínimo
#   2 si la versión es menor que la recomendada (pero >= mínimo)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Función: Parsear versión a número comparable (X.Y.Z -> XYYYZZZ)
parse_version_number() {
	local version="$1"

	# Limpiar versión (remover prefijos como "v", sufijos como "-alpha")
	version=$(echo "$version" | sed 's/^v//;s/-.*//;s/[^0-9.]//g')

	# Extraer partes
	local parts
	IFS='.' read -ra parts <<< "$version"
	local major="${parts[0]:-0}"
	local minor="${parts[1]:-0}"
	local patch="${parts[2]:-0}"

	# Retornar como número para comparación (ej: 20.10.5 -> 20010005)
	echo "$((major * 10000 + minor * 100 + patch))"
}

# Función: Comparar versiones
# Retorna: 0 si v1 >= v2, 1 si v1 < v2
compare_versions() {
	_v1_num=$(parse_version_number "$1")
	local v1_num="$_v1_num"
	unset _v1_num
	_v2_num=$(parse_version_number "$2")
	local v2_num="$_v2_num"
	unset _v2_num

	if [[ $v1_num -ge $v2_num ]]; then
		return 0  # v1 >= v2
	else
		return 1  # v1 < v2
	fi
}

# Función principal
verify_version() {
	local current_version="$1"
	local min_version="$2"
	local recommended_version="${3:-}"

	if [[ -z "$current_version" ]] || [[ -z "$min_version" ]]; then
		return 1
	fi

	# Verificar versión mínima
	if ! compare_versions "$current_version" "$min_version"; then
		return 1  # Versión < mínimo
	fi

	# Si hay versión recomendada, verificar
	if [[ -n "$recommended_version" ]]; then
		if ! compare_versions "$current_version" "$recommended_version"; then
			return 2  # Versión >= mínimo pero < recomendada
		fi
	fi

	return 0  # Versión cumple todos los requisitos
}

# Si se ejecuta directamente, usar como función de línea de comandos
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	if [[ $# -lt 2 ]]; then
		echo "Uso: $0 <version_actual> <version_minima> [version_recomendada]"
		exit 1
	fi

	verify_version "$1" "$2" "${3:-}"
	exit $?
fi
