#!/usr/bin/env bash
# ============================================================================
# Script: log-file-manager.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Helper para gestionar archivos de log: rotación automática, límites de tamaño,
# limpieza de logs antiguos, y configuración centralizada.
#
# Funciones:
#   setup_log_file <ruta>           - Configura archivo de log con rotación automática
#   rotate_log_if_needed <archivo>  - Rota log si excede tamaño máximo
#   cleanup_old_logs <directorio>   - Limpia logs antiguos
#   get_log_config                  - Obtiene configuración centralizada
#
# Uso:
#   source scripts/sh/utils/log-file-manager.sh
#   setup_log_file "/ruta/al/archivo.log"
#
# Variables de entorno:
#   LOG_DIR              - Directorio base para logs (default: PROJECT_ROOT/logs)
#   LOG_MAX_SIZE         - Tamaño máximo en MB antes de rotar (default: 10)
#   LOG_RETENTION_DAYS   - Días de retención de logs (default: 30)
#   LOG_MAX_FILES        - Número máximo de archivos rotados (default: 5)
#   LOG_COMPRESS         - Comprimir logs rotados (default: false)
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configuración por defecto
LOG_DIR="${LOG_DIR:-}"
LOG_MAX_SIZE_MB="${LOG_MAX_SIZE:-10}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"
LOG_MAX_FILES="${LOG_MAX_FILES:-5}"
LOG_COMPRESS="${LOG_COMPRESS:-false}"

# Función: Obtiene el directorio de logs configurado
get_log_dir() {
	local project_root="${PROJECT_ROOT:-$(pwd)}"
	local log_dir="${LOG_DIR:-$project_root/logs}"

	# Crear directorio si no existe
	mkdir -p "$log_dir" 2>/dev/null || true

	echo "$log_dir"
}

# Función: Obtiene configuración de logging desde archivo o variables de entorno
get_log_config() {
	local project_root="${PROJECT_ROOT:-$(pwd)}"
	local config_file="$project_root/.logging-config"

	# Cargar desde archivo de configuración si existe
	if [[ -f "$config_file" ]]; then
		# Leer configuración (formato: KEY=value)
		while IFS='=' read -r key value || [[ -n "$key" ]]; do
			[[ "$key" =~ ^[[:space:]]*# ]] && continue
			[[ -z "${key// }" ]] && continue

			key=$(echo "$key" | tr -d '[:space:]')
			value=$(echo "$value" | tr -d '[:space:]' | sed "s/^[\"']//;s/[\"']$//")

			case "$key" in
				LOG_DIR)
					LOG_DIR="${value:-$LOG_DIR}"
					;;
				LOG_MAX_SIZE)
					LOG_MAX_SIZE_MB="${value:-$LOG_MAX_SIZE_MB}"
					;;
				LOG_RETENTION_DAYS)
					LOG_RETENTION_DAYS="${value:-$LOG_RETENTION_DAYS}"
					;;
				LOG_MAX_FILES)
					LOG_MAX_FILES="${value:-$LOG_MAX_FILES}"
					;;
				LOG_COMPRESS)
					LOG_COMPRESS="${value:-$LOG_COMPRESS}"
					;;
			esac
		done < "$config_file"
	fi

	# Valores por defecto desde variables de entorno si no se configuraron
	LOG_DIR="${LOG_DIR:-$(get_log_dir)}"
	LOG_MAX_SIZE_MB="${LOG_MAX_SIZE:-10}"
	LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"
	LOG_MAX_FILES="${LOG_MAX_FILES:-5}"
	LOG_COMPRESS="${LOG_COMPRESS:-false}"
}

# Función: Obtiene tamaño de archivo en MB
get_file_size_mb() {
	local file="$1"

	if [[ ! -f "$file" ]]; then
		echo "0"
		return
	fi

	# Obtener tamaño en bytes y convertir a MB
	local size_bytes
	size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
	local size_mb=$((size_bytes / 1024 / 1024))
	echo "$size_mb"
}

# Función: Rota un archivo de log si excede el tamaño máximo
rotate_log_if_needed() {
	local log_file="$1"

	if [[ -z "$log_file" ]]; then
		return 1
	fi

	# Cargar configuración
	get_log_config

	# Si el archivo no existe o está vacío, no hacer nada
	if [[ ! -f "$log_file" ]]; then
		return 0
	fi

	local current_size_mb
	current_size_mb=$(get_file_size_mb "$log_file")

	# Si no excede el tamaño máximo, no rotar
	if [[ $current_size_mb -lt $LOG_MAX_SIZE_MB ]]; then
		return 0
	fi

	# Rotar archivo
	local log_dir
	log_dir=$(dirname "$log_file")
	local log_base
	log_base=$(basename "$log_file")
	local timestamp
	timestamp=$(date +%Y%m%d_%H%M%S)
	local rotated_file="${log_dir}/${log_base}.${timestamp}"

	# Mover archivo actual
	mv "$log_file" "$rotated_file" 2>/dev/null || return 1

	# Comprimir si está habilitado
	if [[ "$LOG_COMPRESS" == "true" ]] && command -v gzip >/dev/null 2>&1; then
		gzip "$rotated_file" 2>/dev/null || true
		rotated_file="${rotated_file}.gz"
	fi

	# Limpiar archivos rotados antiguos (mantener solo LOG_MAX_FILES)
	local log_pattern="${log_dir}/${log_base}.*"
	local rotated_count=0

	# Contar archivos rotados y eliminar los más antiguos
	while IFS= read -r rotated; do
		[[ -z "$rotated" ]] && continue
		rotated_count=$((rotated_count + 1))

		# Si excede el máximo, eliminar el más antiguo
		if [[ $rotated_count -gt $LOG_MAX_FILES ]]; then
			# Encontrar el archivo más antiguo
			local oldest
			oldest=$(find "$(dirname "$log_pattern")" \
				-name "$(basename "$log_pattern")" -type f \
				-printf '%T@ %p\n' 2>/dev/null \
				| sort -n | head -1 | cut -d' ' -f2-)
			if [[ -n "$oldest" ]] && [[ -f "$oldest" ]]; then
				rm -f "$oldest" 2>/dev/null || true
			fi
		fi
	done < <(find "$(dirname "$log_pattern")" \
		-name "$(basename "$log_pattern")" -type f \
		-printf '%T@ %p\n' 2>/dev/null \
		| sort -rn | head -$((LOG_MAX_FILES + 1)) \
		| cut -d' ' -f2- || true)

	return 0
}

# Función: Configura un archivo de log con rotación automática
setup_log_file() {
	local log_file="${1:-}"
	local script_name="${2:-script}"

	if [[ -z "$log_file" ]]; then
		# Usar nombre de script por defecto
		local log_dir
		log_dir=$(get_log_dir)
		log_file="${log_dir}/${script_name}.log"
	fi

	# Cargar configuración
	get_log_config

	# Crear directorio si no existe
	local log_dir
	log_dir=$(dirname "$log_file")
	mkdir -p "$log_dir" 2>/dev/null || true

	# Rotar si es necesario antes de configurar
	rotate_log_if_needed "$log_file" 2>/dev/null || true

	# Exportar LOG_FILE para que logging.sh lo use
	export LOG_FILE="$log_file"

	echo "$log_file"
}

# Función: Limpia logs antiguos de un directorio
cleanup_old_logs() {
	local log_dir="${1:-}"

	if [[ -z "$log_dir" ]]; then
		log_dir=$(get_log_dir)
	fi

	if [[ ! -d "$log_dir" ]]; then
		return 0
	fi

	# Cargar configuración
	get_log_config

	# Calcular fecha límite
	local cutoff_date
	cutoff_date=$(date -d "$LOG_RETENTION_DAYS days ago" +%s 2>/dev/null || \
		date -v-"${LOG_RETENTION_DAYS}"d +%s 2>/dev/null || echo "0")

	local deleted_count=0

	# Buscar archivos de log antiguos
	while IFS= read -r log_file; do
		[[ -z "$log_file" ]] && continue
		[[ ! -f "$log_file" ]] && continue

		# Obtener fecha de modificación
		local file_date
		file_date=$(stat -f%m "$log_file" 2>/dev/null || \
			stat -c%Y "$log_file" 2>/dev/null || echo "0")

		# Si es más antiguo que el límite, eliminar
		if [[ $file_date -lt $cutoff_date ]] && [[ $cutoff_date -gt 0 ]]; then
			if rm -f "$log_file" 2>/dev/null; then
				deleted_count=$((deleted_count + 1))
			fi
		fi
	done < <(find "$log_dir" -type f \( -name "*.log" -o -name "*.log.*" -o -name "*.log.gz" \) 2>/dev/null || true)

	echo "$deleted_count"
}

# Función: Verifica y rota logs al inicio de un script
init_log_rotation() {
	local log_file="${LOG_FILE:-}"

	if [[ -z "$log_file" ]]; then
		return 0
	fi

	# Rotar si es necesario
	rotate_log_if_needed "$log_file" 2>/dev/null || true
}

# Función: Crea archivo de configuración de ejemplo
create_log_config_example() {
	local project_root="${PROJECT_ROOT:-$(pwd)}"
	local config_file="$project_root/.logging-config.example"

	cat > "$config_file" <<'EOF'
# Configuración de Logging para dev-toolbox
# Copia este archivo a .logging-config y personaliza según necesites

# Directorio base para logs (relativo a PROJECT_ROOT o absoluto)
LOG_DIR=logs

# Tamaño máximo de archivo de log en MB antes de rotar
LOG_MAX_SIZE=10

# Días de retención de logs antiguos
LOG_RETENTION_DAYS=30

# Número máximo de archivos rotados a mantener
LOG_MAX_FILES=5

# Comprimir logs rotados (true/false)
LOG_COMPRESS=false
EOF

	echo "$config_file"
}
