#!/usr/bin/env bash
# ============================================================================
# Funciones: validate-checks.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Funciones de validación específicas para diferentes aspectos del proyecto.
# ============================================================================

# Función para validar .env y variables (con caché)
validate_env_and_vars() {
	local env_file="$1"
	local extra_vars="$2"
	local cache_key
	cache_key="validate-env-vars-$(echo "$extra_vars" | tr ',' '-')"
	local cache_dir="$3"
	local skip_cache="$4"
	local cache_ttl="$5"
	local exit_code_var="$6"

	if is_cached "$cache_key" "$cache_dir" "$skip_cache" "$cache_ttl" "$env_file"; then
		log_info "Usando resultado en caché para validación de .env"
		local cached_result
		cached_result=$(read_cache "$cache_key" "$cache_dir")
		if [[ "$cached_result" == "1" ]]; then
			eval "$exit_code_var=1"
		fi
		return
	fi

	local result=0

	# Verificar .env usando helper
	if ! validate_file_exists "$env_file" "Archivo .env"; then
		log_info "Ejecuta: make init-env"
		result=1
	fi

	# Verificar variables en .env: obligatorias (NETWORK_NAME) y
	# las adicionales que vengan en $extra_vars (separadas por comas).
	# NETWORK_IP es opcional — no todos los proyectos usan IPs fijas.
	if [[ -f "$env_file" ]]; then
		local MISSING_VARS=""
		local REQUIRED_VARS="NETWORK_NAME"
		# IFS=$'\n\t' quita el espacio; partir explicitamente por espacios
		for var in $(echo "$REQUIRED_VARS" | tr ' ' '\n'); do
			[[ -z "$var" ]] && continue
			if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
				MISSING_VARS="${MISSING_VARS} ${var}"
			fi
		done

		# Variables adicionales desde $extra_vars
		if [[ -n "$extra_vars" ]]; then
			while IFS= read -r v; do
				v=$(printf '%s' "$v" | tr -d ' \t')
				[[ -z "$v" ]] && continue
				if ! grep -q "^${v}=" "$env_file" 2>/dev/null; then
					MISSING_VARS="${MISSING_VARS} ${v}"
				fi
			done < <(echo "$extra_vars" | tr ',' '\n')
		fi

		if [[ -n "$MISSING_VARS" ]]; then
			log_error "Variables faltantes en $env_file:${MISSING_VARS}"
			result=1
		fi
	fi

	save_cache "$cache_key" "$result" "$cache_dir" "$env_file"
	if [[ $result -ne 0 ]]; then
		eval "$exit_code_var=1"
	fi
}

# Función para validar scripts requeridos (con caché)
validate_scripts() {
	local utils_dir="$1"
	local cache_key="validate-scripts"
	local cache_dir="$2"
	local skip_cache="$3"
	local cache_ttl="$4"
	local exit_code_var="$5"

	if is_cached "$cache_key" "$cache_dir" "$skip_cache" "$cache_ttl"; then
		log_info "Usando resultado en caché para validación de scripts"
		local cached_result
		cached_result=$(read_cache "$cache_key" "$cache_dir")
		if [[ "$cached_result" == "1" ]]; then
			eval "$exit_code_var=1"
		fi
		return
	fi

	local result=0

	# Verificar scripts requeridos (solo se reporta si falta alguno)
	for script in ensure-network.sh wait-for-service.sh; do
		if [[ ! -f "$utils_dir/$script" ]]; then
			log_error "Script $script no encontrado"
			result=1
		fi
	done

	save_cache "$cache_key" "$result" "$cache_dir"
	if [[ $result -ne 0 ]]; then
		eval "$exit_code_var=1"
	fi
}

# Función para validar prerrequisitos (con caché)
validate_dependencies() {
	local project_root="$1"
	local cache_key="validate-deps"
	local cache_dir="$2"
	local skip_cache="$3"
	local cache_ttl="$4"
	local exit_code_var="$5"

	if is_cached "$cache_key" "$cache_dir" "$skip_cache" "$cache_ttl"; then
		log_info "Usando resultado en caché para validación de prerrequisitos"
		local cached_result
		cached_result=$(read_cache "$cache_key" "$cache_dir")
		if [[ "$cached_result" == "1" ]]; then
			eval "$exit_code_var=1"
		fi
		return
	fi

	local result=0

	# Verificar prerrequisitos (solo se reporta si fallan)
	if ! make -C "$project_root" check-dependencies >/dev/null 2>&1; then
		log_error "Prerrequisitos no cumplidos"
		result=1
	fi

	save_cache "$cache_key" "$result" "$cache_dir"
	if [[ $result -ne 0 ]]; then
		eval "$exit_code_var=1"
	fi
}

# Función para validar IPs (con caché)
validate_ips() {
	local env_file="$1"
	local commands_dir="$2"
	local cache_dir="$3"
	local skip_cache="$4"
	local cache_ttl="$5"

	local cache_key
	cache_key="validate-ips-$(get_env_hash "$env_file" | head -c 8)"

	if is_cached "$cache_key" "$cache_dir" "$skip_cache" "$cache_ttl" "$env_file"; then
		log_info "Usando resultado en caché para validación de IPs"
		return
	fi

	# Validar IPs solo si .env define variables _IP o NETWORK_IP.
	# Variables _HOST se omiten (pueden ser hostnames).
	if [[ -f "$env_file" ]] && [[ -f "$commands_dir/validate-ips.sh" ]] && \
		grep -qE "(_IP=|NETWORK_IP=)" "$env_file" 2>/dev/null; then
		bash "$commands_dir/validate-ips.sh" "$env_file" || true
	fi

	save_cache "$cache_key" "0" "$cache_dir" "$env_file"
}

# Función para validar puertos (con caché)
validate_ports() {
	local ports_str="${1:-}"
	local commands_dir="$2"
	local cache_dir="$3"
	local skip_cache="$4"
	local cache_ttl="$5"

	if [[ -z "$ports_str" ]]; then
		return
	fi
	local ports_hash
	ports_hash=$(echo "$ports_str" | sha256sum 2>/dev/null | head -c 8 || echo "none")
	local cache_key="validate-ports-${ports_hash}"

	if is_cached "$cache_key" "$cache_dir" "$skip_cache" "$cache_ttl"; then
		log_info "Usando resultado en caché para validación de puertos"
		return
	fi

	# Verificar puertos solo si PORTS está definido (desde Make: make validate PORTS="5432 80").
	# Se muestra qué puertos están en uso; si PORTS está vacío, no se ejecuta.
	if [[ -n "$ports_str" ]] && [[ -f "$commands_dir/check-ports.sh" ]]; then
		local -a _ports_arr=()
		IFS=' ' read -ra _ports_arr <<< "$(echo "$ports_str" | tr ',' ' ')"
		bash "$commands_dir/check-ports.sh" "${_ports_arr[@]}" || true
	fi

	save_cache "$cache_key" "0" "$cache_dir"
}

# Función para validar versiones (con caché y paralelización opcional)
validate_versions() {
	local env_file="$1"
	local commands_dir="$2"
	local cache_dir="$3"
	local skip_cache="$4"
	local cache_ttl="$5"
	local parallel="$6"

	local cache_key
	cache_key="validate-versions-$(get_env_hash "$env_file" | head -c 8)"

	if is_cached "$cache_key" "$cache_dir" "$skip_cache" "$cache_ttl" "$env_file"; then
		log_info "Usando resultado en caché para validación de versiones"
		return
	fi

	# Verificar versiones de servicios (buscar todas las variables *_VERSION en .env)
	if [[ -f "$commands_dir/check-version-compatibility.sh" ]] && [[ -f "$env_file" ]]; then
		local pids=()
		local max_jobs=1

		if [[ "$parallel" == "true" ]]; then
			max_jobs=$(nproc 2>/dev/null || echo 4)
		fi

		# Extraer nombres de servicios desde variables *_VERSION en .env
		while IFS='=' read -r line; do
			# Limitar jobs paralelos
			while [[ ${#pids[@]} -ge $max_jobs ]]; do
				for pid in "${pids[@]}"; do
					if ! kill -0 "$pid" 2>/dev/null; then
						wait "$pid" 2>/dev/null || true
						pids=("${pids[@]/$pid}")
					fi
				done
				sleep 0.1
			done

			# Extraer nombre del servicio desde FOO_VERSION=valor -> foo
			if [[ "$line" =~ ^([A-Z_]+)_VERSION=(.*)$ ]]; then
				local service_var="${BASH_REMATCH[1]}"
				local version="${BASH_REMATCH[2]}"
				local service
				service=$(echo "$service_var" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
				version=$(echo "$version" | sed 's/^["'\'']//;s/["'\'']$//')

				if [[ -n "$version" ]] && [[ -n "$service" ]]; then
					if [[ "$parallel" == "true" ]]; then
						(
							if ! bash "$commands_dir/check-version-compatibility.sh" \
								"$service" "$version" >/dev/null 2>&1; then
								log_warn "Version de $service puede tener problemas: $version"
							fi
						) &
						pids+=($!)
					else
						if ! bash "$commands_dir/check-version-compatibility.sh" \
							"$service" "$version" >/dev/null 2>&1; then
							log_warn "Version de $service puede tener problemas: $version"
						fi
					fi
				fi
			fi
		done < <(grep -E '^[A-Z_]+_VERSION=' "$env_file" 2>/dev/null || true)

		# Esperar a que terminen todos los jobs
		for pid in "${pids[@]}"; do
			wait "$pid" 2>/dev/null || true
		done
	fi

	save_cache "$cache_key" "0" "$cache_dir" "$env_file"
}
