#!/usr/bin/env bash
# ============================================================================
# Funciones: validate-cache.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Funciones de caché para el sistema de validación.
# ============================================================================

# Función para obtener hash de archivo .env para invalidar caché cuando cambia
get_env_hash() {
	local env_file="$1"
	if [[ -f "$env_file" ]]; then
		# Hash basado en contenido de variables relevantes
		sha256sum "$env_file" 2>/dev/null | cut -d' ' -f1 || echo "no-env"
	else
		echo "no-env"
	fi
}

# Función para verificar si un resultado está en caché y es válido
is_cached() {
	local cache_key="$1"
	local cache_dir="$2"
	local cache_file="$cache_dir/${cache_key}.cache"
	local timestamp_file="$cache_dir/${cache_key}.timestamp"
	local skip_cache="${3:-false}"
	local cache_ttl="${4:-300}"
	local env_file="${5:-}"

	if [[ "$skip_cache" == "true" ]]; then
		return 1
	fi

	if [[ ! -f "$cache_file" ]] || [[ ! -f "$timestamp_file" ]]; then
		return 1
	fi

	_cached_time=$(cat "$timestamp_file" 2>/dev/null || echo "0")
	local cached_time="$_cached_time"
	unset _cached_time
	_current_time=$(date +%s)
	local current_time="$_current_time"
	unset _current_time
	local elapsed=$((current_time - cached_time))

	# Verificar TTL
	if [[ $elapsed -gt "$cache_ttl" ]]; then
		return 1
	fi

	# Verificar que el hash de .env no haya cambiado
	if [[ -n "$env_file" ]]; then
		local cached_hash
		cached_hash=$(cat "$cache_dir/${cache_key}.hash" 2>/dev/null || echo "")
		local current_hash
		current_hash=$(get_env_hash "$env_file")
		if [[ "$cached_hash" != "$current_hash" ]]; then
			return 1
		fi
	fi

	return 0
}

# Función para guardar resultado en caché
save_cache() {
	local cache_key="$1"
	local result="$2"
	local cache_dir="$3"
	local env_file="${4:-}"
	local cache_file="$cache_dir/${cache_key}.cache"

	mkdir -p "$cache_dir"
	echo "$result" > "$cache_file"
	date +%s > "$cache_dir/${cache_key}.timestamp"
	if [[ -n "$env_file" ]]; then
		get_env_hash "$env_file" > "$cache_dir/${cache_key}.hash"
	fi
}

# Función para leer resultado del caché
read_cache() {
	local cache_key="$1"
	local cache_dir="$2"
	local cache_file="$cache_dir/${cache_key}.cache"
	cat "$cache_file" 2>/dev/null || echo ""
}
