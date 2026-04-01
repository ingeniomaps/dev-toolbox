#!/usr/bin/env bash
# ============================================================================
# Script: source_scripts.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Función para cargar de forma segura todos los scripts `.sh` de un directorio.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/source_scripts.sh"
#   source_scripts "utils"
#   source_scripts "." "true"  # recursivo
#
# Parámetros:
#   $1 - (opcional) Directorio que contiene los scripts (default: '.')
#   $2 - (opcional) Si es "true", busca en subdirectorios (default: 'false')
#
# Descripción:
#   - Localiza todos los archivos con extensión `.sh` dentro del directorio
#     especificado.
#   - Valida que el directorio de entrada exista antes de proceder.
#   - Carga cada script encontrado en el entorno de shell actual.
#
# Retorno:
#   0 si se cargaron scripts o no había ninguno
#   1 si el directorio no existe
# ============================================================================

source_scripts() {
	local directory="${1:-.}"
	local recursive="${2:-false}"

	# Principio de "Fail-Fast": valida que el directorio exista.
	if [[ ! -d "$directory" ]]; then
		echo "Error: El directorio '$directory' no existe." >&2
		return 1
	fi

	local find_args=()
	if [[ "$recursive" != "true" ]]; then
		find_args+=("-maxdepth" "1")
	fi

	# Usar `mapfile` con delimitador NUL (`-d ''`) y `find -print0` es el
	# método más robusto para manejar CUALQUIER nombre de archivo.
	local -a scripts
	mapfile -d '' -t scripts < <(find "$directory" "${find_args[@]}" -type f -name "*.sh" -print0)

	if [[ ${#scripts[@]} -eq 0 ]]; then
		return 0
	fi

	for script in "${scripts[@]}"; do
		if [[ -f "$script" ]]; then
			# shellcheck disable=SC1090
			# ShellCheck no puede seguir rutas dinámicas; esta función carga scripts dinámicamente
			source "$script"
		fi
	done
}
